`timescale 1ns/1ps
module fp_fxp_mul #(
  parameter integer FXP_WIDTH       = 4,
  parameter integer FP_WIDTH        = 32,
  parameter integer FP_FRAC_WIDTH   = 23,
  parameter integer FP_EXP_WIDTH    = FP_WIDTH - FP_FRAC_WIDTH - 1
) (
  input  wire                        clk,
  input  wire                        reset,
  input  wire                        a_bit,
  input  wire                        a_sign,
  input  wire [ 4           -1 : 0 ] a_exp,
  input  wire [ FP_WIDTH    -1 : 0 ] b,
  input  wire                        b_zero,
  output wire [ FP_WIDTH    -1 : 0 ] result
);

  wire                          b_s;
  wire [FP_EXP_WIDTH  -1 : 0 ]  b_exp;
  wire [FP_FRAC_WIDTH -1 : 0 ]  b_frac;

  assign {b_s, b_exp, b_frac} = b;

  wire is_zero = ~a_bit || b_zero;

  reg  [FP_EXP_WIDTH  -1 : 0 ] res_exp;
  reg  [FP_FRAC_WIDTH -1 : 0 ] res_frac;
  reg                          res_sign;

  always @(*)
  begin
    if (is_zero) begin
      res_frac = 0;
      res_exp  = 0;
    end
    else begin
      res_frac = b_frac;
      res_exp  = b_exp + a_exp;
    end
  end

  always @(*)
  begin
    res_sign = b_s ^ a_sign;
  end

  assign result = {res_sign, res_exp, res_frac};

`ifdef COCOTB_TOPLEVEL_fp_fxp_mul
  initial begin
    $dumpfile("fp_fxp_mul.vcd");
    $dumpvars(0, fp_fxp_mul);
  end
`endif

endmodule
