//
// Spatial: Shift-Add design
//
// Mode 0: 2K x 2K
// Mode 1: 2K x 1K
// Mode 2: 1K x 2K
// Mode 3: 1K x 1K
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module spatial_mult_shift_add #(
  parameter integer PRECISION       = 8, // Precision at current level
  parameter integer L_PRECISION     = 2, // Lowest precision
  parameter integer TOP_MODULE      = 1, // 1: top or 0: not
  parameter integer VEC_SIZE        = 1, // Size of the vector for dot product

  parameter integer MULT_OUT_WIDTH  = (L_PRECISION * 2) + 2, // Output width of each multiplier
  parameter integer NUM_LP_MULT     = (PRECISION / L_PRECISION) * (PRECISION / L_PRECISION), // Number of multipliers to instantiate
  parameter integer IN_WIDTH        = NUM_LP_MULT * (MULT_OUT_WIDTH + $clog2(VEC_SIZE)), // Input width of shift-add unit

  parameter integer OUT_WIDTH       = (PRECISION * 2) + 2 + $clog2(VEC_SIZE), // Output width at current level

  parameter integer NUM_LEVELS      = $clog2(PRECISION/L_PRECISION), // Number of levels in the spatial multiplier. 8:4:2:1 mult has 3 levels
  parameter integer MODE_WIDTH      = 2 * NUM_LEVELS, // Mode width. Every level needs 2 bits
  parameter integer HALF_PRECISION  = PRECISION / 2 // Half of current level's precision
) (
  input  wire        [ MODE_WIDTH     -1 : 0 ]    mode,
  input  wire        [ IN_WIDTH       -1 : 0 ]    in,
  output wire        [ OUT_WIDTH      -1 : 0 ]    out
);


genvar ii, jj, kk;
generate

  if (PRECISION == L_PRECISION)
  begin: FULL_PRECISION
    assign out = in;
  end // FULL_PRECISION

//=========================================
// Step 2: Shift
// Mode:
//  0: 2Kx2K
//  1: 2KxK
//  2: Kx2K
//  3: KxK
//=========================================

  else
  begin: LP_MULT_INST

    localparam integer LOWER_MULT_WIDTH = IN_WIDTH / 4;

    wire        [ LOWER_MULT_WIDTH -1 : 0 ] l_pp_0;
    wire        [ LOWER_MULT_WIDTH -1 : 0 ] l_pp_1;
    wire        [ LOWER_MULT_WIDTH -1 : 0 ] l_pp_2;
    wire        [ LOWER_MULT_WIDTH -1 : 0 ] l_pp_3;

    assign {l_pp_3, l_pp_2, l_pp_1, l_pp_0} = in;

    localparam integer LOWER_SAD_WIDTH = PRECISION + 2 + $clog2(VEC_SIZE);
    wire signed [ LOWER_SAD_WIDTH -1 : 0 ] pp_0;
    wire signed [ LOWER_SAD_WIDTH -1 : 0 ] pp_1;
    wire signed [ LOWER_SAD_WIDTH -1 : 0 ] pp_2;
    wire signed [ LOWER_SAD_WIDTH -1 : 0 ] pp_3;

    // lower_level_mode gets sent to the lower levels of mult
    wire [MODE_WIDTH-3:0] lower_level_mode;

    if (PRECISION == L_PRECISION*2)
    begin: LAST_LEVEL
      assign lower_level_mode = 'b0;
    end
    else
    begin: NEXT_LEVEL
      assign lower_level_mode = mode[MODE_WIDTH-3:0];
    end

    wire [1:0] curr_level_mode = mode[MODE_WIDTH-1:MODE_WIDTH-2];

    spatial_mult_shift_add #(.PRECISION (HALF_PRECISION), .L_PRECISION (L_PRECISION), .IN_WIDTH (LOWER_MULT_WIDTH), .VEC_SIZE (VEC_SIZE))
      sad_0 (lower_level_mode, l_pp_0, pp_0);
    spatial_mult_shift_add #(.PRECISION (HALF_PRECISION), .L_PRECISION (L_PRECISION), .IN_WIDTH (LOWER_MULT_WIDTH), .VEC_SIZE (VEC_SIZE))
      sad_1 (lower_level_mode, l_pp_1, pp_1);
    spatial_mult_shift_add #(.PRECISION (HALF_PRECISION), .L_PRECISION (L_PRECISION), .IN_WIDTH (LOWER_MULT_WIDTH), .VEC_SIZE (VEC_SIZE))
      sad_2 (lower_level_mode, l_pp_2, pp_2);
    spatial_mult_shift_add #(.PRECISION (HALF_PRECISION), .L_PRECISION (L_PRECISION), .IN_WIDTH (LOWER_MULT_WIDTH), .VEC_SIZE (VEC_SIZE))
      sad_3 (lower_level_mode, l_pp_3, pp_3);

    wire signed [OUT_WIDTH-1:0] spp_0;
    wire signed [OUT_WIDTH-1:0] spp_1;
    wire signed [OUT_WIDTH-1:0] spp_2;
    wire signed [OUT_WIDTH-1:0] spp_3;

    reg [1:0] s_0;
    reg [1:0] s_1;
    reg [1:0] s_2;
    reg [1:0] s_3;

    // Shift amounts
    always @(*) begin
      case (curr_level_mode)
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
    assign spp_0 = pp_0 <<< (s_0 * HALF_PRECISION);
    assign spp_1 = pp_1 <<< (s_1 * HALF_PRECISION);
    assign spp_2 = pp_2 <<< (s_2 * HALF_PRECISION);
    assign spp_3 = pp_3 <<< (s_3 * HALF_PRECISION);
//=========================================

//=========================================
// Step 3: ADD
// out = spp_0 + spp_1 + spp_2 + spp_3
//=========================================
    assign out = spp_0 + spp_1 + spp_2 + spp_3;
//=========================================
  end // LP_MULT_INST
endgenerate
endmodule
