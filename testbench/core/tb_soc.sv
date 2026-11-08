module tb_soc #(
    parameter int ACCEL = 0
);
    logic clk = 0, reset = 1;
    always #5 clk = !clk;
    logic valid, ready, error, trapped, busy;
    logic [31:0] addr, wdata, rdata, pc;
    logic [3:0] wstrb;
    logic [7:0] ram [0:131071];
    logic [31:0] digest [0:7];
    wire [16:0] base = {addr[16:2], 2'b0};
    wire ram_sel = addr < 32'h20000;
    wire host_sel = addr[31:6] == 26'h0800000;
    wire full_word = wstrb == 4'hf && addr[1:0] == 0;
    int unsigned cycle = 0, start_cycle, elapsed, length;
    int unsigned rounds = 0, transfers = 0, init_writes = 0, poll_reads = 0;
    int unsigned latched_rounds, latched_transfers, latched_init, latched_poll;
    bit measuring = 0;
    string image;
    logic [31:0] expected_trap_pc;
    bit expect_trap;

    secure_soc #(.ACCEL(ACCEL)) dut(clk, reset, valid, addr, wdata, wstrb,
                                    ready, error, rdata, trapped, busy, pc);

    assign ready = valid;
    assign error = valid && !(ram_sel || (host_sel && full_word));
    assign rdata = ram_sel ? {ram[base+3], ram[base+2], ram[base+1], ram[base]} : 32'b0;

    initial begin
        if (!$value$plusargs("image=%s", image)) $fatal(1, "Missing +image");
        expect_trap = $value$plusargs("trap_pc=%h", expected_trap_pc);
        foreach (ram[i]) ram[i] = 0;
        $readmemh(image, ram);
        if ($test$plusargs("trace")) begin
            $dumpfile("soc.vcd");
            $dumpvars(1, tb_soc);
        end
        repeat (3) @(negedge clk);
        reset = 0;
    end

    always @(posedge clk) begin
        if (!reset) begin
            cycle <= cycle + 1;
            if (cycle >= 10000000) $fatal(1, "Cycle limit reached at pc=%h", pc);
            if (trapped) begin
                if (expect_trap) begin
                    assert (pc == expected_trap_pc) else $fatal(1, "Unexpected trap PC %h", pc);
                    $display("PASS expected trap pc=%08h", pc);
                    $finish;
                end else begin
                    $fatal(1, "CPU trapped at pc=%h", pc);
                end
            end
            if (measuring && busy) rounds <= rounds + 1;
            if (dut.cpu_valid && dut.sha_sel && dut.sha_access_ok && measuring) begin
                if (addr[6:0] != 0) transfers <= transfers + 1;
                else if (wstrb == 0) poll_reads <= poll_reads + 1;
                else if (wdata == 1) init_writes <= init_writes + 1;
            end
            if (valid && !error) begin
                if (ram_sel) begin
                    for (int i = 0; i < 4; i++)
                        if (wstrb[i]) ram[base+17'(i)] <= wdata[i*8 +: 8];
                end else if (host_sel) begin
                    case (addr[5:0])
                        0: begin
                            if (wdata != 0 || expect_trap)
                                $fatal(1, "Unexpected firmware exit status %h", wdata);
                            $display("PASS firmware");
                            $finish;
                        end
                        4: begin
                            length <= wdata;
                            start_cycle <= cycle;
                            measuring <= 1;
                            rounds <= 0;
                            transfers <= 0;
                            init_writes <= 0;
                            poll_reads <= 0;
                        end
                        8: begin
                            elapsed <= cycle - start_cycle;
                            measuring <= 0;
                            latched_rounds <= rounds;
                            latched_transfers <= transfers;
                            latched_init <= init_writes;
                            latched_poll <= poll_reads;
                        end
                        12: $display("RESULT %0d %0d %0d %0d %0d %0d %08h%08h%08h%08h%08h%08h%08h%08h",
                                     length, elapsed, latched_rounds, latched_transfers,
                                     latched_init, latched_poll, digest[0], digest[1], digest[2],
                                     digest[3], digest[4], digest[5], digest[6], digest[7]);
                        default: if (addr[5:0] >= 32) digest[addr[4:2]] <= wdata;
                    endcase
                end
            end
        end
    end
endmodule
