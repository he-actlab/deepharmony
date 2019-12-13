//
// Spatial: Low Precision Multiply-Accumulate
//
// Mode 0: 2K x 2K
// Mode 1: 2K x 1K
// Mode 2: 1K x 2K
// Mode 3: 1K x 1K
//
// Hardik Sharma
// (hsharma@gatech.edu)
`timescale 1ns/1ps
module fusion_symmetric_2_1 #(
  parameter integer  TOP_MODULE                   = 1,  // Top or not
  parameter integer  ACT_WIDTH                    = 4,  // Input width at current level
  parameter integer  WGT_WIDTH                    = 4,  // Input width at current level
  parameter integer  OUT_WIDTH                    = 5   // Output width at current level
) (
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire  [ 2                    -1 : 0 ]        sign_mode,
  input  wire  [ 2                    -1 : 0 ]        mode,
  input  wire  [ ACT_WIDTH            -1 : 0 ]        a,
  input  wire  [ WGT_WIDTH            -1 : 0 ]        b,
  output wire  [ OUT_WIDTH            -1 : 0 ]        out
);

wire a_sign, b_sign;
assign {a_sign, b_sign} = {~sign_mode[1] && ~mode[1], ~sign_mode[0] && ~mode[0]};

wire a_0, a_1, a_2, a_3;
wire b_0, b_1, b_2, b_3;

assign {a_3, a_2, a_1, a_0} = a;
assign {b_3, b_2, b_1, b_0} = b;

  wire                                        out_0;
  wire                                        out_1;
  wire                                        out_2;
  wire                                        out_3;

assign out_0 = a_0 & b_0;
assign out_1 = a_1 & b_1;
assign out_2 = a_2 & b_2;
assign out_3 = a_3 & b_3;

wire signed [2-1:0] pp_0;
wire signed [2-1:0] pp_1;
wire signed [2-1:0] pp_2;
wire signed [2-1:0] pp_3;

assign pp_0 = {1'b0, out_0};
assign pp_1 = {a_sign && out_1, out_1};
assign pp_2 = {b_sign && out_2, out_2};
assign pp_3 = {(a_sign ^ b_sign) && out_3, out_3};

wire signed [OUT_WIDTH-1:0] spp_0;
wire signed [OUT_WIDTH-1:0] spp_1;
wire signed [OUT_WIDTH-1:0] spp_2;
wire signed [OUT_WIDTH-1:0] spp_3;

  reg  [ 1                       : 0 ]        s_0;
  reg  [ 1                       : 0 ]        s_1;
  reg  [ 1                       : 0 ]        s_2;
  reg  [ 1                       : 0 ]        s_3;

// Shift amounts
always @(*) begin
  case (mode)
    0: begin
      s_0 = 2'd0;
      s_1 = 2'd1;
      s_2 = 2'd1;
      s_3 = 2'd2;
    end
    1: begin
      s_0 = 2'd0;
      s_1 = 2'd1;
      s_2 = 2'd0;
      s_3 = 2'd1;
    end
    2: begin
      s_0 = 2'd0;
      s_1 = 2'd0;
      s_2 = 2'd1;
      s_3 = 2'd1;
    end
    3: begin
      s_0 = 2'd0;
      s_1 = 2'd0;
      s_2 = 2'd0;
      s_3 = 2'd0;
    end
  endcase
end

// generate shifted partial products
assign spp_0 = pp_0 <<< s_0;
assign spp_1 = pp_1 <<< s_1;
assign spp_2 = pp_2 <<< s_2;
assign spp_3 = pp_3 <<< s_3;
//=========================================

//=========================================
// Step 3: ADD
// out = spp_0 + spp_1 + spp_2 + spp_3
//=========================================
assign out = spp_0 + spp_1 + spp_2 + spp_3;
//=========================================

endmodule
