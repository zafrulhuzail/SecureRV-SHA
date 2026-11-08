module tb_sha256;
    logic clk = 0, reset = 1, we = 0, busy;
    logic [6:0] offset = 0;
    logic [31:0] wdata = 0, rdata;
    always #5 clk = !clk;
    sha256_mmio dut(clk, reset, we, offset, wdata, rdata, busy);

    task automatic write_word(input logic [6:0] address, input logic [31:0] value);
        @(negedge clk);
        offset = address;
        wdata = value;
        we = 1;
        @(negedge clk);
        we = 0;
    endtask

    task automatic check_empty;
        logic [255:0] result;
        write_word(0, 1);
        for (int i = 0; i < 16; ++i)
            write_word(7'(32 + i*4), i == 0 ? 32'h80000000 : 32'b0);
        write_word(0, 2);
        for (int i = 0; i < 64; ++i) begin
            assert (busy) else $fatal(1, "Early completion at round %0d", i);
            @(negedge clk);
        end
        assert (!busy) else $fatal(1, "Late completion");
        for (int i = 0; i < 8; ++i) begin
            offset = 7'(96 + i*4);
            #1;
            result[255-i*32 -: 32] = rdata;
        end
        assert (result == 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855)
            else $fatal(1, "Empty digest mismatch: %h", result);
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 0;
        check_empty();
        write_word(0, 2);
        assert (busy) else $fatal(1, "Start rejected");
        reset = 1;
        @(negedge clk);
        assert (!busy) else $fatal(1, "Reset failed to abort block");
        reset = 0;
        offset = 7'h60;
        #1;
        assert (rdata == 32'h6a09e667) else $fatal(1, "Reset did not restore IV");
        check_empty();
        $display("PASS SHA-256 unit");
        $finish;
    end
endmodule
