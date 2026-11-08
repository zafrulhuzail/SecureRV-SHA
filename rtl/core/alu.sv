module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  op,
    output logic [31:0] result
);
    // Internal operation selectors. Instruction decoding belongs upstream.
    always_comb begin
        case (op)
            4'd0: result = a + b;  // ADD
            4'd1: result = a - b;  // SUB
            4'd2: result = a & b;  // AND
            4'd3: result = a | b;  // OR
            4'd4: result = a ^ b;  // XOR
            4'd5: result = a << b[4:0];  // SLL
            4'd6: result = a >> b[4:0];  // SRL
            4'd7: result = {31'b0, $signed(a) < $signed(b)};  // SLT
            4'd8: result = {31'b0, a < b};  // SLTU
            default: result = 32'b0;
        endcase
    end
endmodule
