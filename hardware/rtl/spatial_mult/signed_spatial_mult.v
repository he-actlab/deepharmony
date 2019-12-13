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

module signed_spatial_mult #(
  parameter integer PRECISION                     = 8,                                   // Precision at current level
  parameter integer L_PRECISION                   = 2,                                    // Lowest precision
  parameter integer TOP_MODULE                    = 1,                                    // 1: top or 0: not
  parameter integer IN_WIDTH                      = (PRECISION/L_PRECISION) * PRECISION,  // Input width at current level
  parameter integer NUM_LP_MULT                   = IN_WIDTH / L_PRECISION,               // Number of multipliers to instantiate
  parameter integer MULT_OUT_WIDTH                = (L_PRECISION * 2) + 2,                // Output width of each multiplier
  parameter integer A_WIDTH                       = IN_WIDTH,                             // A's width at current level
  parameter integer B_WIDTH                       = IN_WIDTH,                             // B's width at current level
  parameter integer OUT_WIDTH                     = PRECISION * 2 + 2,                        // Output width at current level
  parameter integer NUM_LEVELS                    = $clog2(PRECISION/L_PRECISION),        // Number of levels in the spatial multiplier. 8:4:2:1 mult has 3 levels
  parameter integer MODE_WIDTH                    = 2 * NUM_LEVELS,                       // Mode width. Every level needs 2 bits
  parameter integer HALF_PRECISION                = PRECISION / 2                         // Half of current level's precision
) (
  input                                           clk,
  input                                           reset,
  input  wire        [ 2              -1 : 0 ]    prev_level_mode,
  input  wire        [ MODE_WIDTH     -1 : 0 ]    mode,
  input  wire        [ A_WIDTH        -1 : 0 ]    a,
  input  wire        [ B_WIDTH        -1 : 0 ]    b,
  output wire        [ OUT_WIDTH      -1 : 0 ]    out
);


//=========================================
// Step 1: Input Muxes
//=========================================
  wire [ IN_WIDTH   -1 : 0 ] a_muxed;
  wire [ IN_WIDTH   -1 : 0 ] b_muxed;
  input_mux_a #(PRECISION, L_PRECISION, TOP_MODULE) imux_a (a, a_muxed);
  input_mux_b #(PRECISION, L_PRECISION, TOP_MODULE) imux_b (b, b_muxed);
//=========================================

//=========================================
// Step 2: Multiplier
//=========================================
  localparam integer LP_MULT_OUT_WIDTH = NUM_LP_MULT * MULT_OUT_WIDTH;
  wire [ LP_MULT_OUT_WIDTH -1 : 0 ] lp_mult_out;
  spatial_low_prec_mult #(PRECISION, L_PRECISION, TOP_MODULE) lp_mult (2'b11, mode, a_muxed, b_muxed, lp_mult_out);
//=========================================

//=========================================
// Step 3: Shift-Add
//=========================================
  spatial_mult_shift_add #(PRECISION, L_PRECISION, TOP_MODULE) sad (mode, lp_mult_out, out);
//=========================================

//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_signed_spatial_mult
if (TOP_MODULE == 1)
begin
  initial begin
    $dumpfile("signed_spatial_mult.vcd");
    $dumpvars(0, signed_spatial_mult);
  end
end
`endif

endmodule
