module tb_core_units;
    logic clk = 0, we = 0, legal;
    logic [4:0] rs1 = 0, rs2 = 0, rd = 0;
    logic [31:0] wdata = 0, a, b, insn, imm;
    logic [3:0] alu_op;
    register_file rf(clk, we, rs1, rs2, rd, wdata, a, b);
    decoder dec(insn, imm, alu_op, legal);

    task automatic write_register(input logic [4:0] index, input logic [31:0] value);
        rd = index;
        wdata = value;
        #1;
        clk = 1;
        #1;
        clk = 0;
    endtask

    task automatic decode_check(
        input logic [31:0] instruction, immediate,
        input logic [3:0] selector,
        input logic expected_legal
    );
        insn = instruction;
        #1;
        assert (legal == expected_legal && (!legal || (imm == immediate && alu_op == selector)))
            else $fatal(1, "Decode mismatch for %h", instruction);
    endtask

    initial begin
        we = 1;
        write_register(0, 32'hfeedface);
        for (int i = 1; i < 32; ++i) write_register(5'(i), 32'hba5e0000 | 32'(i));
        we = 0;
        write_register(31, 0);
        for (int i = 1; i < 32; ++i) begin
            rs1 = 5'(i);
            rs2 = 5'(32-i);
            #1;
            assert (a == (32'hba5e0000 | 32'(i)) && b == (32'hba5e0000 | 32'(32-i)))
                else $fatal(1, "Register read mismatch at %0d", i);
        end
        rs1 = 0;
        rs2 = 0;
        #1;
        assert (a == 0 && b == 0) else $fatal(1, "x0 changed");

        decode_check(32'hfff10093, 32'hffffffff, 0, 1); // addi x1,x2,-1
        decode_check(32'h41f15093, 32'h0000041f, 9, 1); // srai x1,x2,31
        decode_check(32'hfe112e23, 32'hfffffffc, 0, 1); // sw x1,-4(x2)
        decode_check(32'hfe000ee3, 32'hfffffffc, 0, 1); // beq x0,x0,-4
        decode_check(32'hffdff0ef, 32'hfffffffc, 0, 1); // jal x1,-4
        decode_check(32'h800000b7, 32'h80000000, 0, 1); // lui x1,0x80000
        decode_check(32'h021100b3, 0, 0, 0); // mul outside RV32I
        decode_check(32'h02011093, 0, 0, 0); // reserved SLLI encoding
        decode_check(32'h00003083, 0, 0, 0); // reserved load width
        decode_check(32'h00002063, 0, 0, 0); // reserved branch condition
        $display("PASS register file and decoder");
        $finish;
    end
endmodule
