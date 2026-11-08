module tb_alu;
    logic [31:0] a, b, result;
    logic [3:0] op;
    int unsigned checks = 0;

    alu dut (.a(a), .b(b), .op(op), .result(result));

    task automatic check(
        input logic [3:0] selector,
        input logic [31:0] lhs, rhs, expected
    );
        op = selector;
        a = lhs;
        b = rhs;
        #1;
        assert (result === expected)
            else $fatal(1, "op=%0d a=%08h b=%08h expected=%08h got=%08h",
                        selector, lhs, rhs, expected, result);
        checks++;
    endtask

    initial begin
        if ($test$plusargs("trace")) begin
            $dumpfile("alu.vcd");
            $dumpvars(0, tb_alu);
        end

        // ADD
        check(4'd0, 32'h00000001, 32'h00000002, 32'h00000003);
        check(4'd0, 32'hffffffff, 32'h00000001, 32'h00000000);
        check(4'd0, 32'h7fffffff, 32'h00000001, 32'h80000000);
        check(4'd0, 32'h80000000, 32'h80000000, 32'h00000000);
        check(4'd0, 32'h00000000, 32'h00000000, 32'h00000000);
        // SUB
        check(4'd1, 32'h00000005, 32'h00000002, 32'h00000003);
        check(4'd1, 32'h00000000, 32'h00000001, 32'hffffffff);
        check(4'd1, 32'h80000000, 32'h00000001, 32'h7fffffff);
        check(4'd1, 32'hdeadbeef, 32'hdeadbeef, 32'h00000000);
        // AND
        check(4'd2, 32'ha5a5a5a5, 32'h0ff00ff0, 32'h05a005a0);
        // OR
        check(4'd3, 32'ha5a5a5a5, 32'h0ff00ff0, 32'haff5aff5);
        // XOR
        check(4'd4, 32'ha5a5a5a5, 32'h0ff00ff0, 32'haa55aa55);
        check(4'd4, 32'hffffffff, 32'hffffffff, 32'h00000000);
        // SLL
        check(4'd5, 32'h80000001, 32'h00000000, 32'h80000001);
        check(4'd5, 32'h80000001, 32'h00000001, 32'h00000002);
        check(4'd5, 32'h00000001, 32'h0000001f, 32'h80000000);
        check(4'd5, 32'h00000001, 32'h00000020, 32'h00000001);
        check(4'd5, 32'h00000001, 32'hffffffff, 32'h80000000);
        // SRL
        check(4'd6, 32'h80000001, 32'h00000000, 32'h80000001);
        check(4'd6, 32'h80000001, 32'h00000001, 32'h40000000);
        check(4'd6, 32'h80000000, 32'h0000001f, 32'h00000001);
        check(4'd6, 32'h80000000, 32'h00000020, 32'h80000000);
        check(4'd6, 32'h80000000, 32'hffffffff, 32'h00000001);
        // SLT
        check(4'd7, 32'h80000000, 32'h7fffffff, 32'h00000001);
        check(4'd7, 32'h7fffffff, 32'h80000000, 32'h00000000);
        check(4'd7, 32'hfffffffe, 32'hffffffff, 32'h00000001);
        check(4'd7, 32'hffffffff, 32'hffffffff, 32'h00000000);
        check(4'd7, 32'h00000001, 32'h00000002, 32'h00000001);
        // SLTU
        check(4'd8, 32'h80000000, 32'h7fffffff, 32'h00000000);
        check(4'd8, 32'h7fffffff, 32'h80000000, 32'h00000001);
        check(4'd8, 32'h00000000, 32'hffffffff, 32'h00000001);
        check(4'd8, 32'hffffffff, 32'h00000000, 32'h00000000);
        check(4'd8, 32'hffffffff, 32'hffffffff, 32'h00000000);

        // Every unassigned selector returns zero with nonzero operands.
        for (int selector = 9; selector < 16; selector++) begin
            check(4'(selector), 32'hffff_ffff, 32'hffff_ffff, 32'b0);
        end

        $display("PASS: %0d ALU checks", checks);
        $finish;
    end
endmodule
