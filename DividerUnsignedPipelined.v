`timescale 1ns / 1ps
// -------------------------------------------------------------------------
// MAIN MODULE: DIVIDER 8 STAGES PIPELINE
// -------------------------------------------------------------------------
module DividerUnsignedPipelined (
    input  wire        clk, 
    input  wire        rst,
    input  wire        stall,  
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);

    wire [31:0] chain_dividend  [0:8];
    wire [31:0] chain_remainder [0:8];
    wire [31:0] chain_quotient  [0:8];
    wire [31:0] chain_divisor   [0:8];

    assign chain_dividend[0]  = i_dividend;
    assign chain_divisor[0]   = i_divisor;
    assign chain_remainder[0] = 32'd0;
    assign chain_quotient[0]  = 32'd0;

    genvar k;
    generate
        for (k = 0; k < 8; k = k + 1) begin : PIPELINE_STAGES
            DividerStage stage_inst (
                .clk      (clk),
                .rst      (rst),
                .stall    (stall),
                
                .i_div    (chain_dividend[k]),
                .i_rem    (chain_remainder[k]),
                .i_quo    (chain_quotient[k]),
                .i_dvs    (chain_divisor[k]),
            
                .o_div    (chain_dividend[k+1]),
                .o_rem    (chain_remainder[k+1]),
                .o_quo    (chain_quotient[k+1]),
                .o_dvs    (chain_divisor[k+1])
            );
        end
    endgenerate
    assign o_quotient  = chain_quotient[8];
    assign o_remainder = chain_remainder[8];

endmodule

// -------------------------------------------------------------------------
//  1 STAGE PIPELINE (Including 4 Iterations + 1 Register)
// -------------------------------------------------------------------------
module DividerStage (
    input  wire        clk, rst, stall,
    input  wire [31:0] i_div, i_rem, i_quo, i_dvs,
    output reg  [31:0] o_div, o_rem, o_quo, o_dvs
);
    wire [31:0] t_div [0:4];
    wire [31:0] t_rem [0:4];
    wire [31:0] t_quo [0:4];

    assign t_div[0] = i_div;
    assign t_rem[0] = i_rem;
    assign t_quo[0] = i_quo;
    genvar m;
    generate
        for (m = 0; m < 4; m = m + 1) begin : CLUSTER_4_ITERS
            divu_1iter unit (
                .i_dividend (t_div[m]),
                .i_divisor  (i_dvs),        
                .i_remainder(t_rem[m]),
                .i_quotient (t_quo[m]),
                
                .o_dividend (t_div[m+1]),
                .o_remainder(t_rem[m+1]),
                .o_quotient (t_quo[m+1])
            );
        end
    endgenerate

    
    always @(posedge clk) begin
        if (rst) begin
            o_div <= 32'd0;
            o_rem <= 32'd0;
            o_quo <= 32'd0;
            o_dvs <= 32'd0; 
        end else if (!stall) begin 
            o_div <= t_div[4];
            o_rem <= t_rem[4];
            o_quo <= t_quo[4];
            o_dvs <= i_dvs; 
        end
    end

endmodule

// -------------------------------------------------------------------------
//  1 ITERATION 
// -------------------------------------------------------------------------
module divu_1iter (
   input  wire [31:0] i_dividend,
   input  wire [31:0] i_divisor,
   input  wire [31:0] i_remainder,
   input  wire [31:0] i_quotient,
   output wire [31:0] o_dividend,
   output wire [31:0] o_remainder,
   output wire [31:0] o_quotient       
);

    wire [32:0] remainder_next;
    assign remainder_next = {i_remainder[30:0], i_dividend[31], 1'b0} >> 1; 

    wire [32:0] rem_shifted_safe;
    assign rem_shifted_safe = {1'b0, i_remainder} << 1;
    
    wire [32:0] rem_with_bit;
    assign rem_with_bit = rem_shifted_safe | {32'd0, i_dividend[31]};


    wire [32:0] diff;
    assign diff = rem_with_bit - {1'b0, i_divisor};

    
    wire condition;
    assign condition = (rem_with_bit >= {1'b0, i_divisor});

    
    assign o_remainder = condition ? diff[31:0] : rem_with_bit[31:0];
    assign o_quotient  = (i_quotient << 1) | {31'b0, condition};
    assign o_dividend  = i_dividend << 1;

endmodule