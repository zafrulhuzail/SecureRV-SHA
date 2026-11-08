module register_file (
    input logic clk, write_enable,
    input logic [4:0] rs1, rs2, rd,
    input logic [31:0] write_data,
    output logic [31:0] a, b
);
    logic [31:0] regs [1:31];
    assign a = rs1 == 0 ? 32'b0 : regs[rs1];
    assign b = rs2 == 0 ? 32'b0 : regs[rs2];
    always_ff @(posedge clk)
        if (write_enable && rd != 0) regs[rd] <= write_data;
endmodule
