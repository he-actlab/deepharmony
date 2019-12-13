`timescale 1ns/1ps
module fp_fusion_unit #(
  parameter integer  PMIN                         = 2, // Minimum possible precision
  parameter integer  ACT_PMAX                     = 8, // Max precision for activations (or gradients)
  parameter integer  ACT_EXP_WIDTH                = 5, // Width of exponent for activations (or gradients)
  parameter integer  WGT_PMAX                     = 8, // Max precision for weights

  parameter integer  NUM_MULT                     = (ACT_PMAX / PMIN),
  parameter integer  MODE_WIDTH                   = $clog2(NUM_MULT),

  parameter integer  FUSION_INPUT_WIDTH           = NUM_MULT * PMIN, // Input width for A
  parameter integer  NUM_FUSION_UNIT              = WGT_PMAX / PMIN, // Input width for A

  parameter integer  ACT_IN_WIDTH                 = NUM_FUSION_UNIT * FUSION_INPUT_WIDTH, // Input width for A
  parameter integer  ACT_EXP_IN_WIDTH             = NUM_FUSION_UNIT * ACT_EXP_WIDTH, // Exponent width for B
  parameter integer  WGT_IN_WIDTH                 = NUM_FUSION_UNIT * FUSION_INPUT_WIDTH, // Input width for B

  parameter integer  RESULT_WIDTH                 = ACT_PMAX + PMIN, // Input width for B

  parameter integer  FP_FXP_WIDTH                 = 16,
  parameter integer  FP_EXP_WIDTH                 = ACT_EXP_WIDTH,
  parameter integer  FP_WIDTH                     = FP_FXP_WIDTH + FP_EXP_WIDTH + 1,

  // Not currently supported
  parameter          ACT_SUPPORTS_32              = "TRUE",
  parameter          ACT_SUPPORTS_16              = "TRUE",
  parameter          ACT_SUPPORTS_8               = "TRUE",
  parameter          ACT_SUPPORTS_4               = "TRUE",
  parameter          ACT_SUPPORTS_2               = "TRUE",
  parameter          ACT_SUPPORTS_1               = "TRUE",
  parameter          WGT_SUPPORTS_32              = "TRUE",
  parameter          WGT_SUPPORTS_16              = "TRUE",
  parameter          WGT_SUPPORTS_8               = "TRUE",
  parameter          WGT_SUPPORTS_4               = "TRUE",
  parameter          WGT_SUPPORTS_2               = "TRUE",
  parameter          WGT_SUPPORTS_1               = "TRUE",
  parameter          ACT_SIGNED                   = 1,
  parameter          WGT_SIGNED                   = 1
)
(
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire  [ MODE_WIDTH           -1 : 0 ]        mode,
  input  wire  [ ACT_IN_WIDTH         -1 : 0 ]        act_fxp,
  input  wire  [ WGT_IN_WIDTH         -1 : 0 ]        wgt_fxp,
  input  wire  [ ACT_EXP_IN_WIDTH     -1 : 0 ]        act_exp,
  output wire  [ FP_WIDTH             -1 : 0 ]        result
);

  localparam          FUSION_OUTPUT_WIDTH          = FP_WIDTH * NUM_FUSION_UNIT;
  wire [ FUSION_OUTPUT_WIDTH  -1 : 0 ]        fusion_output;

genvar i;
generate
for (i=0; i<NUM_FUSION_UNIT; i=i+1)
begin: FUSION_UNIT_INST

  wire [ RESULT_WIDTH         -1 : 0 ]        mult_out;
  wire [ FP_WIDTH             -1 : 0 ]        fp_out;
  wire [ 2                    -1 : 0 ]        prev_level_mode;

  wire [ FUSION_INPUT_WIDTH   -1 : 0 ]        _act_fxp;
  wire [ FP_EXP_WIDTH         -1 : 0 ]        _act_exp;
  wire [ FUSION_INPUT_WIDTH   -1 : 0 ]        _wgt_fxp;

  assign _act_fxp = act_fxp[i*FUSION_INPUT_WIDTH+:FUSION_INPUT_WIDTH];
  assign _act_exp = act_exp[i*FP_EXP_WIDTH+:FP_EXP_WIDTH];
  assign _wgt_fxp = wgt_fxp[i*FUSION_INPUT_WIDTH+:FUSION_INPUT_WIDTH];

  assign prev_level_mode = 2'b0;
  assign fusion_output[i*FP_WIDTH+:FP_WIDTH] = fp_out;

  fusion_unit #(
    .ACT_PMAX                       ( ACT_PMAX                       ),  // Precision at current level
    .WGT_PMAX                       ( PMIN                           ),  // Precision at current level
    .PMIN                           ( PMIN                           ),  // Lowest precision
    .TOP_MODULE                     ( 1                              ),  // top or not
    .ACT_SIGNED                     ( ACT_SIGNED                     ),
    .WGT_SIGNED                     ( WGT_SIGNED                     ),
    .ACT_SUPPORTS_32                ( ACT_SUPPORTS_32                ),
    .ACT_SUPPORTS_16                ( ACT_SUPPORTS_16                ),
    .ACT_SUPPORTS_8                 ( ACT_SUPPORTS_8                 ),
    .ACT_SUPPORTS_4                 ( ACT_SUPPORTS_4                 ),
    .ACT_SUPPORTS_2                 ( ACT_SUPPORTS_2                 ),
    .ACT_SUPPORTS_1                 ( ACT_SUPPORTS_1                 ),
    .WGT_SUPPORTS_32                ( WGT_SUPPORTS_32                ),
    .WGT_SUPPORTS_16                ( WGT_SUPPORTS_16                ),
    .WGT_SUPPORTS_8                 ( WGT_SUPPORTS_8                 ),
    .WGT_SUPPORTS_4                 ( WGT_SUPPORTS_4                 ),
    .WGT_SUPPORTS_2                 ( WGT_SUPPORTS_2                 ),
    .WGT_SUPPORTS_1                 ( WGT_SUPPORTS_1                 )
  ) mult_inst (
    .clk                            ( clk                            ),  // input
    .reset                          ( reset                          ),  // input
    .prev_level_mode                ( prev_level_mode                ),  // input
    .mode                           ( mode                           ),  // input
    .a                              ( _act_fxp                       ),  // input
    .b                              ( _wgt_fxp                       ),  // input
    .out                            ( mult_out                       )   // output
  );

  fp_normalize #(
    .FXP_WIDTH                      ( RESULT_WIDTH                   ),
    .FP_FXP_WIDTH                   ( FP_FXP_WIDTH                   ),
    .FP_EXP_WIDTH                   ( FP_EXP_WIDTH                   ),
    .EXP_OUT_WIDTH                  ( FP_EXP_WIDTH                   )
  ) add_norm (
    .fxp_in                         ( mult_out                       ),
    .exp_in                         ( _act_exp                       ),
    .fp_out                         ( fp_out                         )
  );

end
endgenerate

  localparam integer  ADD_TREE_LEVELS              = $clog2(NUM_FUSION_UNIT);

  fp_adder_tree #(
    .FXP_WIDTH                      ( FP_FXP_WIDTH                   ),
    .EXP_WIDTH                      ( FP_EXP_WIDTH                   ),
    .LOG2_N                         ( ADD_TREE_LEVELS                )
  ) add_tree (
    .data_in                        ( fusion_output                  ),
    .data_out                       ( result                         )
  );

//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_fp_fusion_unit
  initial begin
    $dumpfile("fp_fusion_unit.vcd");
    $dumpvars(0, fp_fusion_unit);
end
`endif

endmodule
