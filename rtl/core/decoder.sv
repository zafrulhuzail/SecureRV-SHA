module decoder (
    input logic [31:0] insn,
    output logic [31:0] imm,
    output logic [3:0] alu_op,
    output logic legal
);
    wire [6:0] opcode = insn[6:0];
    wire [2:0] funct = insn[14:12];
    wire [6:0] high = insn[31:25];

    always_comb begin
        imm = {{20{insn[31]}}, insn[31:20]};
        alu_op = 0;
        legal = 1;
        case (opcode)
            7'h37, 7'h17: imm = {insn[31:12], 12'b0};
            7'h6f: imm = {{11{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};
            7'h67: legal = funct == 0;
            7'h63: begin
                imm = {{19{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
                legal = funct != 2 && funct != 3;
            end
            7'h03: legal = funct < 3 || funct == 4 || funct == 5;
            7'h23: begin
                imm = {{20{insn[31]}}, insn[31:25], insn[11:7]};
                legal = funct < 3;
            end
            7'h13, 7'h33: begin
                case (funct)
                    0: alu_op = opcode == 7'h33 && high == 7'h20 ? 4'd1 : 4'd0;
                    1: alu_op = 5;
                    2: alu_op = 7;
                    3: alu_op = 8;
                    4: alu_op = 4;
                    5: alu_op = high == 7'h20 ? 4'd9 : 4'd6;
                    6: alu_op = 3;
                    7: alu_op = 2;
                    default: legal = 0;
                endcase
                if (opcode == 7'h33 || funct == 1 || funct == 5)
                    legal = high == 0 ||
                            (high == 7'h20 && (funct == 5 || (opcode == 7'h33 && funct == 0)));
            end
            7'h0f: legal = funct == 0; // FENCE on the ordered, single-request bus.
            default: legal = 0;
        endcase
    end
endmodule
