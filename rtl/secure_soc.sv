module secure_soc #(
    parameter integer ACCEL = 0
)(
    input logic clk, reset,
    output logic valid,
    output logic [31:0] addr, wdata,
    output logic [3:0] wstrb,
    input logic ready, error,
    input logic [31:0] rdata,
    output logic trapped, busy,
    output logic [31:0] pc
);
    logic cpu_valid, cpu_ready, cpu_error;
    logic [31:0] cpu_rdata, sha_rdata;
    wire sha_sel = (ACCEL != 0) && addr[31:7] == 25'h0200000;
    wire sha_access_ok = addr[1:0] == 0 && (wstrb == 0 || wstrb == 4'hf);

    cpu core(clk, reset, cpu_valid, addr, wdata, wstrb, cpu_ready, cpu_error,
             cpu_rdata, trapped, pc);

    assign valid = cpu_valid && !sha_sel;
    assign cpu_ready = sha_sel ? cpu_valid : ready;
    assign cpu_error = sha_sel ? !sha_access_ok : error;
    assign cpu_rdata = sha_sel ? sha_rdata : rdata;

    generate
        if (ACCEL != 0) begin : gen_sha
            sha256_mmio peripheral(clk, reset,
                cpu_valid && sha_sel && sha_access_ok && wstrb != 0,
                addr[6:0], wdata, sha_rdata, busy);
        end else begin : gen_baseline
            assign sha_rdata = 0;
            assign busy = 0;
        end
    endgenerate
endmodule
