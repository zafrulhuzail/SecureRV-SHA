module cpu (
    input logic clk, reset,
    output logic valid,
    output logic [31:0] addr, wdata,
    output logic [3:0] wstrb,
    input logic ready, error,
    input logic [31:0] rdata,
    output logic trapped,
    output logic [31:0] pc
);
    typedef enum logic [1:0] {FETCH, EXECUTE, MEMORY, TRAP} state_t;
    state_t state;
    logic [31:0] insn, imm, a, b, alu_result, rhs, result, next_pc;
    logic [31:0] effective, mem_addr, mem_wdata, load_word;
    logic [3:0] alu_op, mem_mask, byte_mask;
    logic legal, write_enable, writes_rd, take_branch, misaligned;
    wire [6:0] opcode = insn[6:0];
    wire [2:0] funct = insn[14:12];
    wire load = opcode == 7'h03;
    wire store = opcode == 7'h23;

    decoder decode(insn, imm, alu_op, legal);
    register_file rf(clk, write_enable, insn[19:15], insn[24:20], insn[11:7], result, a, b);
    assign rhs = opcode == 7'h13 ? imm : b;
    alu arithmetic(a, rhs, alu_op, alu_result);
    assign effective = a + imm;
    assign trapped = state == TRAP;
    assign valid = !reset && (state == FETCH || state == MEMORY);
    assign addr = state == FETCH ? pc : mem_addr;
    assign wstrb = state == MEMORY ? mem_mask : 4'b0;
    assign wdata = mem_wdata;
    assign load_word = rdata >> {mem_addr[1:0], 3'b0};
    assign byte_mask = (funct == 0 ? 4'b0001 : funct == 1 ? 4'b0011 : 4'b1111) << effective[1:0];
    assign misaligned = (funct[1:0] == 1 && effective[0]) ||
                        (funct[1:0] == 2 && effective[1:0] != 0);

    always_comb begin
        case (funct)
            0: take_branch = a == b;
            1: take_branch = a != b;
            4: take_branch = $signed(a) < $signed(b);
            5: take_branch = $signed(a) >= $signed(b);
            6: take_branch = a < b;
            7: take_branch = a >= b;
            default: take_branch = 0;
        endcase
        next_pc = pc + 4;
        writes_rd = 1;
        result = alu_op == 9 ? $unsigned($signed(a) >>> rhs[4:0]) : alu_result;
        case (opcode)
            7'h37: result = imm;
            7'h17: result = pc + imm;
            7'h6f: begin
                result = pc + 4;
                next_pc = pc + imm;
            end
            7'h67: begin
                result = pc + 4;
                next_pc = effective & 32'hffff_fffe;
            end
            7'h63: begin
                writes_rd = 0;
                if (take_branch) next_pc = pc + imm;
            end
            7'h03: begin
                case (funct)
                    0: result = {{24{load_word[7]}}, load_word[7:0]};
                    1: result = {{16{load_word[15]}}, load_word[15:0]};
                    4: result = {24'b0, load_word[7:0]};
                    5: result = {16'b0, load_word[15:0]};
                    default: result = load_word;
                endcase
            end
            7'h23, 7'h0f: writes_rd = 0;
            default: begin end
        endcase
    end

    assign write_enable = !reset && (
        (state == EXECUTE && legal && writes_rd && !load && next_pc[1:0] == 0) ||
        (state == MEMORY && load && ready && !error));

    always_ff @(posedge clk) begin
        if (reset) begin
            pc <= 0;
            state <= FETCH;
        end else begin
            case (state)
                FETCH: if (ready) begin
                    insn <= rdata;
                    state <= error ? TRAP : EXECUTE;
                end
                EXECUTE: begin
                    if (!legal || next_pc[1:0] != 0 || ((load || store) && misaligned))
                        state <= TRAP;
                    else if (load || store) begin
                        mem_addr <= effective;
                        mem_mask <= store ? byte_mask : 4'b0;
                        mem_wdata <= b << {effective[1:0], 3'b0};
                        state <= MEMORY;
                    end else begin
                        pc <= next_pc;
                        state <= FETCH;
                    end
                end
                MEMORY: if (ready) begin
                    state <= error ? TRAP : FETCH;
                    if (!error) pc <= pc + 4;
                end
                TRAP: begin end
                default: state <= TRAP;
            endcase
        end
    end
endmodule
