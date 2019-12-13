`timescale 1ns/1ps
module fp_custom_adder #(
  parameter integer  FXP_WIDTH                    = 12,
  parameter integer  EXP_WIDTH                    = 5,
  parameter integer  FP_WIDTH                     = FXP_WIDTH + EXP_WIDTH + 1
) (
  input  wire  [ FP_WIDTH             -1 : 0 ]        a_fp,
  input  wire  [ FP_WIDTH             -1 : 0 ]        b_fp,
  output wire  [ FP_WIDTH             -1 : 0 ]        sum
);

  wire [ FXP_WIDTH            -1 : 0 ]        a_fxp;
  wire [ EXP_WIDTH            -1 : 0 ]        a_exp;
  wire                                        a_sign;

  wire [ FXP_WIDTH            -1 : 0 ]        b_fxp;
  wire [ EXP_WIDTH            -1 : 0 ]        b_exp;
  wire                                        b_sign;

  wire [ FXP_WIDTH            -1 : 0 ]        max_fxp;
  wire signed [ FXP_WIDTH               : 0 ]        max_2s;
  wire [ EXP_WIDTH            -1 : 0 ]        max_exp;
  wire                                        max_sign;

  wire [ FXP_WIDTH            -1 : 0 ]        min_fxp;
  wire signed [ FXP_WIDTH               : 0 ]        min_2s;
  wire [ EXP_WIDTH            -1 : 0 ]        min_exp;
  wire                                        min_sign;
  wire signed [ FXP_WIDTH               : 0 ]        min_shifted_2s;

  wire                                        under_over_flow;
  wire signed [ FXP_WIDTH            +1 : 0 ]        sum_value;
  wire [ FXP_WIDTH               : 0 ]        sum_mag;
  wire [ FXP_WIDTH            -1 : 0 ]        sum_mag_shifter;
  wire [ FXP_WIDTH            -1 : 0 ]        sum_fxp;
  wire [ EXP_WIDTH            -1 : 0 ]        sum_exp;
  wire                                        sum_sign;

  wire                                        a_gt_b;

  wire                                        add_sub;

  assign {a_sign, a_exp, a_fxp} = a_fp;
  assign {b_sign, b_exp, b_fxp} = b_fp;

  assign a_gt_b = a_exp > b_exp;

  assign max_fxp = a_gt_b ? a_fxp : b_fxp;
  assign max_2s = max_sign ? -max_fxp : max_fxp;
  assign min_fxp = a_gt_b ? b_fxp : a_fxp;
  assign min_2s = min_sign ? -min_fxp : min_fxp;
  assign max_exp = a_gt_b ? a_exp : b_exp;
  assign min_exp = a_gt_b ? b_exp : a_exp;
  assign max_sign = a_gt_b ? a_sign : b_sign;
  assign min_sign = a_gt_b ? b_sign : a_sign;

  dsp_subunit #(.FXP_WIDTH(FXP_WIDTH), .EXP_WIDTH(EXP_WIDTH))
  dsp_adder (.max_2s(max_2s), .min_2s(min_2s), .max_exp(max_exp), .min_exp(min_exp), .sum_sign(sum_sign), .sum_mag(sum_mag));

  // assign min_shifted_2s = min_2s >>> (max_exp - min_exp);
  // assign sum_value = max_2s + min_shifted_2s;

  // assign sum_sign = sum_value[FXP_WIDTH+1];
  // assign sum_mag = sum_sign ? -sum_value : sum_value;

  assign under_over_flow = sum_mag[FXP_WIDTH];
  assign sum_exp = max_exp + under_over_flow;
  assign sum_mag_shifter = sum_mag >> under_over_flow;
  assign sum_fxp = sum_sign ? -(sum_mag_shifter) : sum_mag_shifter;

fp_normalize_sm #(
    .FXP_WIDTH                      ( FXP_WIDTH                      ),
    .EXP_WIDTH                      ( EXP_WIDTH                      ),
    .EXP_OUT_WIDTH                  ( EXP_WIDTH                      )
) add_norm (
    .sign                           ( sum_sign                       ),
    .fxp_in                         ( sum_mag_shifter                ),
    .exp_in                         ( sum_exp                        ),
    .fp_out                         ( sum                            )
);

  //assign sum = {sum_sign, sum_exp, sum_fxp};

//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_fp_custom_adder
  initial begin
    $dumpfile("fp_custom_adder.vcd");
    $dumpvars(0, fp_custom_adder);
end
`endif

endmodule

/* Author: Hardik Sharma
 * Email: hsharma@gatech.edu
*/
`timescale 1ns/1ps
(* use_dsp = "yes" *)
module dsp_subunit #(
  parameter integer  FXP_WIDTH                    = 8,
  parameter integer  EXP_WIDTH                    = 5
) (
  input  wire  [ FXP_WIDTH            -1 : 0 ]        max_2s,
  input  wire  [ EXP_WIDTH            -1 : 0 ]        max_exp,
  input  wire  [ FXP_WIDTH            -1 : 0 ]        min_2s,
  input  wire  [ EXP_WIDTH            -1 : 0 ]        min_exp,
  output wire  [ FXP_WIDTH               : 0 ]        sum_mag,
  output wire                                         sum_sign
);
  wire signed [ FXP_WIDTH            +1 : 0 ]        sum_value;
  wire signed [ FXP_WIDTH               : 0 ]        min_shifted_2s;

  assign min_shifted_2s = min_2s >>> (max_exp - min_exp);
  assign sum_value = max_2s + min_shifted_2s;
  assign sum_sign = sum_value[FXP_WIDTH+1];
  assign sum_mag = sum_sign ? -sum_value : sum_value;

endmodule // dsp_subunit

