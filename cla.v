`timescale 1ns / 1ps
module gp1(input wire a, b,
           output wire g, p);
    assign g = a & b;
    assign p = a | b; 
endmodule

module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);
    assign pout = &pin;
    assign gout = gin[3] | (pin[3] & gin[2]) | (pin[3] & pin[2] & gin[1]) | (pin[3] & pin[2] & pin[1] & gin[0]);
    assign cout[0] = gin[0] | (pin[0] & cin);
    assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
    assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0]) | (pin[2] & pin[1] & pin[0] & cin);

endmodule

module gp8(input wire [7:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [6:0] cout);

    wire g_low, p_low;   
    wire g_high, p_high; 
    wire c_mid;         
    wire [2:0] c_low_internal;
    wire [2:0] c_high_internal;

    gp4 low_nibble (
        .gin(gin[3:0]), 
        .pin(pin[3:0]), 
        .cin(cin),
        .gout(g_low), 
        .pout(p_low), 
        .cout(c_low_internal)
    );

    assign c_mid = g_low | (p_low & cin);
    gp4 high_nibble (
        .gin(gin[7:4]), 
        .pin(pin[7:4]), 
        .cin(c_mid), 
        .gout(g_high), 
        .pout(p_high), 
        .cout(c_high_internal)
    );

    assign pout = p_high & p_low;
    assign gout = g_high | (p_high & g_low);
    assign cout = {c_high_internal, c_mid, c_low_internal};

endmodule

module cla
  (input wire [31:0]  a, b,
   input wire         cin,
   output wire [31:0] sum);

    wire [31:0] g_bits;    
    wire [31:0] p_bits;    
    wire [7:0]  g_groups;  
    wire [7:0]  p_groups;  
    wire [6:0]  c_groups;  
    
    
    wire [31:0] carry_full; 
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : gp1_gen
            gp1 bit_level (
                .a(a[i]), 
                .b(b[i]), 
                .g(g_bits[i]), 
                .p(p_bits[i])
            );
        end
    endgenerate

    wire g_super, p_super; 
    gp8 central_lookahead (
        .gin(g_groups), 
        .pin(p_groups), 
        .cin(cin),          
        .gout(g_super), 
        .pout(p_super), 
        .cout(c_groups)     
    );
    
    wire [2:0] internal_couts [7:0]; 
    generate
        for (i = 0; i < 8; i = i + 1) begin : gp4_groups
            wire cin_group;
            assign cin_group = (i == 0) ? cin : c_groups[i-1];

            gp4 group_level (
                .gin(g_bits[4*i+3 : 4*i]), 
                .pin(p_bits[4*i+3 : 4*i]), 
                .cin(cin_group), 
                .gout(g_groups[i]), 
                .pout(p_groups[i]), 
                .cout(internal_couts[i])
            );
            wire [3:0] c_local;
            assign c_local = {internal_couts[i], cin_group};
            assign sum[4*i]   = a[4*i]   ^ b[4*i]   ^ c_local[0];
            assign sum[4*i+1] = a[4*i+1] ^ b[4*i+1] ^ c_local[1];
            assign sum[4*i+2] = a[4*i+2] ^ b[4*i+2] ^ c_local[2];
            assign sum[4*i+3] = a[4*i+3] ^ b[4*i+3] ^ c_local[3];
        end
    endgenerate

endmodule