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
module spatial_low_prec_mult #(
  parameter integer PRECISION                     = 8,                                   // Precision at current level
  parameter integer L_PRECISION                   = 2,                                    // Lowest precision
  parameter integer TOP_MODULE                    = 1,                                    // 1: top or 0: not
  parameter integer IN_WIDTH                      = (PRECISION/L_PRECISION) * PRECISION,  // Input width at current level
  parameter integer NUM_MULT                      = IN_WIDTH / L_PRECISION,               // Number of multipliers to instantiate
  parameter integer MULT_OUT_WIDTH                = (L_PRECISION * 2 + 2),                // Output width of each multiplier
  parameter integer A_WIDTH                       = IN_WIDTH,                             // A's width at current level
  parameter integer B_WIDTH                       = IN_WIDTH,                             // B's width at current level
  parameter integer OUT_WIDTH                     = MULT_OUT_WIDTH * NUM_MULT,            // Output width at current level
  parameter integer NUM_LEVELS                    = $clog2(PRECISION/L_PRECISION),        // Number of levels in the spatial multiplier. 8:4:2:1 mult has 3 levels
  parameter integer MODE_WIDTH                    = 2 * NUM_LEVELS,                       // Mode width. Every level needs 2 bits
  parameter integer HALF_PRECISION                = PRECISION / 2                         // Half of current level's precision
) (
  input  wire        [ 2              -1 : 0 ]    prev_level_mode,
  input  wire        [ MODE_WIDTH     -1 : 0 ]    mode,
  input  wire        [ A_WIDTH        -1 : 0 ]    a,
  input  wire        [ B_WIDTH        -1 : 0 ]    b,
  output wire        [ OUT_WIDTH      -1 : 0 ]    out
);

//=========================================
// Half Precision Multipliers
//=========================================

  genvar i;
  generate

    if (PRECISION == L_PRECISION)
    begin: FULL_PRECISION // Full Precision

      wire a_mode, b_mode;
      wire signed [ IN_WIDTH+1     -1 : 0 ] a_signed;
      wire signed [ IN_WIDTH+1     -1 : 0 ] b_signed;
      wire signed [ OUT_WIDTH      -1 : 0 ] out_signed;

      assign {a_mode, b_mode} = prev_level_mode;
      assign a_signed = {a_mode && a[IN_WIDTH-1], a};
      assign b_signed = {b_mode && b[IN_WIDTH-1], b};

      assign out_signed = a_signed * b_signed;
      assign out = out_signed;

    end // FULL_PRECISION

    else
    begin: LP_MULT_INST

      localparam integer LP_MULT_IN_W = IN_WIDTH / 4;

      wire [ LP_MULT_IN_W - 1 : 0 ] a_0;
      wire [ LP_MULT_IN_W - 1 : 0 ] a_1;
      wire [ LP_MULT_IN_W - 1 : 0 ] a_2;
      wire [ LP_MULT_IN_W - 1 : 0 ] a_3;

      wire [ LP_MULT_IN_W - 1 : 0 ] b_0;
      wire [ LP_MULT_IN_W - 1 : 0 ] b_1;
      wire [ LP_MULT_IN_W - 1 : 0 ] b_2;
      wire [ LP_MULT_IN_W - 1 : 0 ] b_3;

      assign {a_3, a_2, a_1, a_0} = a;
      assign {b_3, b_2, b_1, b_0} = b;

      // Sign mode
      // Required when A_SIGN_EXTEND == 1 or B_SIGN_EXTEND == 1
      // This means that the sign for the MSB bits of an input depend on the higher level mode, instead of the current level mode
      wire [2-1:0] higher_level_mode;
      if (TOP_MODULE == 1)
        assign higher_level_mode = 2'b11;
      else
        assign higher_level_mode = prev_level_mode;

      // Partial Products
      localparam integer LOWER_MULT_WIDTH = MULT_OUT_WIDTH * (NUM_MULT / 4);
      wire signed [ LOWER_MULT_WIDTH -1 : 0 ] pp_0;
      wire signed [ LOWER_MULT_WIDTH -1 : 0 ] pp_1;
      wire signed [ LOWER_MULT_WIDTH -1 : 0 ] pp_2;
      wire signed [ LOWER_MULT_WIDTH -1 : 0 ] pp_3;

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

      wire [2-1:0] m0_sign_mode;
      wire [2-1:0] m1_sign_mode;
      wire [2-1:0] m2_sign_mode;
      wire [2-1:0] m3_sign_mode;

      wire [1:0] curr_level_mode = mode[MODE_WIDTH-1:MODE_WIDTH-2];

      assign m0_sign_mode = curr_level_mode;
      assign m1_sign_mode = {higher_level_mode[1], curr_level_mode[0]};
      assign m2_sign_mode = {curr_level_mode[1], higher_level_mode[0]};
      assign m3_sign_mode = higher_level_mode;

      spatial_low_prec_mult #(HALF_PRECISION, L_PRECISION, 0) m0 (m0_sign_mode, lower_level_mode, a_0, b_0, pp_0);
      spatial_low_prec_mult #(HALF_PRECISION, L_PRECISION, 0) m1 (m1_sign_mode, lower_level_mode, a_1, b_1, pp_1);
      spatial_low_prec_mult #(HALF_PRECISION, L_PRECISION, 0) m2 (m2_sign_mode, lower_level_mode, a_2, b_2, pp_2);
      spatial_low_prec_mult #(HALF_PRECISION, L_PRECISION, 0) m3 (m3_sign_mode, lower_level_mode, a_3, b_3, pp_3);

      assign out = {pp_3, pp_2, pp_1, pp_0};

    end // LP_MULT_INST

  endgenerate
//=========================================

endmodule
