module sha256_mmio (
    input logic clk, reset, write_enable,
    input logic [6:0] offset,
    input logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic busy
);
    localparam logic [255:0] IV = 256'h5be0cd19_1f83d9ab_9b05688c_510e527f_a54ff53a_3c6ef372_bb67ae85_6a09e667;
    logic [31:0] schedule [0:15];
    logic [255:0] digest, working, next_working;
    logic [5:0] round;
    logic [31:0] a, b, c, d, e, f, g, h, t1, t2, word;

    function automatic [31:0] constant(input logic [5:0] index);
        case (index)
            6'd0: constant = 32'h428a2f98;
            6'd1: constant = 32'h71374491;
            6'd2: constant = 32'hb5c0fbcf;
            6'd3: constant = 32'he9b5dba5;
            6'd4: constant = 32'h3956c25b;
            6'd5: constant = 32'h59f111f1;
            6'd6: constant = 32'h923f82a4;
            6'd7: constant = 32'hab1c5ed5;
            6'd8: constant = 32'hd807aa98;
            6'd9: constant = 32'h12835b01;
            6'd10: constant = 32'h243185be;
            6'd11: constant = 32'h550c7dc3;
            6'd12: constant = 32'h72be5d74;
            6'd13: constant = 32'h80deb1fe;
            6'd14: constant = 32'h9bdc06a7;
            6'd15: constant = 32'hc19bf174;
            6'd16: constant = 32'he49b69c1;
            6'd17: constant = 32'hefbe4786;
            6'd18: constant = 32'h0fc19dc6;
            6'd19: constant = 32'h240ca1cc;
            6'd20: constant = 32'h2de92c6f;
            6'd21: constant = 32'h4a7484aa;
            6'd22: constant = 32'h5cb0a9dc;
            6'd23: constant = 32'h76f988da;
            6'd24: constant = 32'h983e5152;
            6'd25: constant = 32'ha831c66d;
            6'd26: constant = 32'hb00327c8;
            6'd27: constant = 32'hbf597fc7;
            6'd28: constant = 32'hc6e00bf3;
            6'd29: constant = 32'hd5a79147;
            6'd30: constant = 32'h06ca6351;
            6'd31: constant = 32'h14292967;
            6'd32: constant = 32'h27b70a85;
            6'd33: constant = 32'h2e1b2138;
            6'd34: constant = 32'h4d2c6dfc;
            6'd35: constant = 32'h53380d13;
            6'd36: constant = 32'h650a7354;
            6'd37: constant = 32'h766a0abb;
            6'd38: constant = 32'h81c2c92e;
            6'd39: constant = 32'h92722c85;
            6'd40: constant = 32'ha2bfe8a1;
            6'd41: constant = 32'ha81a664b;
            6'd42: constant = 32'hc24b8b70;
            6'd43: constant = 32'hc76c51a3;
            6'd44: constant = 32'hd192e819;
            6'd45: constant = 32'hd6990624;
            6'd46: constant = 32'hf40e3585;
            6'd47: constant = 32'h106aa070;
            6'd48: constant = 32'h19a4c116;
            6'd49: constant = 32'h1e376c08;
            6'd50: constant = 32'h2748774c;
            6'd51: constant = 32'h34b0bcb5;
            6'd52: constant = 32'h391c0cb3;
            6'd53: constant = 32'h4ed8aa4a;
            6'd54: constant = 32'h5b9cca4f;
            6'd55: constant = 32'h682e6ff3;
            6'd56: constant = 32'h748f82ee;
            6'd57: constant = 32'h78a5636f;
            6'd58: constant = 32'h84c87814;
            6'd59: constant = 32'h8cc70208;
            6'd60: constant = 32'h90befffa;
            6'd61: constant = 32'ha4506ceb;
            6'd62: constant = 32'hbef9a3f7;
            6'd63: constant = 32'hc67178f2;
            default: constant = 0;
        endcase
    endfunction

    function automatic [31:0] ror(input logic [31:0] x, input integer n);
        ror = (x >> n) | (x << (32 - n));
    endfunction
    function automatic [31:0] small0(input logic [31:0] x);
        small0 = ror(x, 7) ^ ror(x, 18) ^ (x >> 3);
    endfunction
    function automatic [31:0] small1(input logic [31:0] x);
        small1 = ror(x, 17) ^ ror(x, 19) ^ (x >> 10);
    endfunction

    assign {h,g,f,e,d,c,b,a} = working;
    assign word = schedule[0];
    assign t1 = h + (ror(e,6) ^ ror(e,11) ^ ror(e,25)) +
                ((e & f) ^ (~e & g)) + constant(round) + word;
    assign t2 = (ror(a,2) ^ ror(a,13) ^ ror(a,22)) + ((a & b) ^ (a & c) ^ (b & c));
    assign next_working = {g,f,e,d+t1,c,b,a,t1+t2};

    always_comb begin
        rdata = 0;
        if (offset == 0) rdata = {31'b0, busy};
        else if (offset >= 7'h60) rdata = digest[32 * offset[4:2] +: 32];
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            digest <= IV;
            busy <= 0;
            round <= 0;
        end else if (busy) begin
            for (int i = 0; i < 15; i++) schedule[i] <= schedule[i+1];
            schedule[15] <= small1(schedule[14]) + schedule[9] + small0(schedule[1]) + word;
            working <= next_working;
            round <= round + 1'b1;
            if (round == 63) begin
                for (int i = 0; i < 8; i++)
                    digest[32*i +: 32] <= digest[32*i +: 32] + next_working[32*i +: 32];
                busy <= 0;
            end
        end else if (write_enable) begin
            if (offset == 0) begin
                case (wdata)
                    1: digest <= IV;
                    2: begin
                        working <= digest;
                        round <= 0;
                        busy <= 1;
                    end
                    default: begin end
                endcase
            end else if (offset >= 7'h20 && offset < 7'h60) begin
                schedule[4'(offset[6:2] - 5'd8)] <= wdata;
            end
        end
    end
endmodule
