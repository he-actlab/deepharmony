`timescale 1ns/1ps
module fp_normalize #(
  parameter integer  FXP_WIDTH                    = 4,
  parameter integer  FP_FXP_WIDTH                 = 4,
  parameter integer  FP_EXP_WIDTH                 = 5,
  parameter integer  EXP_OUT_WIDTH                = FP_EXP_WIDTH + 1,
  parameter integer  FP_WIDTH                     = FP_FXP_WIDTH + EXP_OUT_WIDTH + 1
) (
  input  wire  [ FXP_WIDTH            -1 : 0 ]        fxp_in,
  input  wire  [ FP_EXP_WIDTH         -1 : 0 ]        exp_in,
  output wire  [ FP_WIDTH             -1 : 0 ]        fp_out
);

  localparam integer  SHIFT_WIDTH                  = $clog2(FP_FXP_WIDTH);

  wire                                        sign;
  wire [ FP_FXP_WIDTH         -1 : 0 ]        magnitude_in;

  wire [ FP_FXP_WIDTH         -1 : 0 ]        magnitude_out;
  wire signed [ EXP_OUT_WIDTH        -1 : 0 ]        exp_out;

  reg  [ SHIFT_WIDTH          -1 : 0 ]        shift;
  reg                                         shift_detect;

  assign sign      = fxp_in[FXP_WIDTH-1];
  assign magnitude_in = sign ? -fxp_in : fxp_in;

integer i;
generate
always @(magnitude_in)
begin
  shift = 0;
  shift_detect = 1'b0;
  for (i=FP_FXP_WIDTH-1; i>-1; i=i-1)
  begin
    if (shift_detect == 0 && magnitude_in[i] == 1'b1) begin
        shift = FP_FXP_WIDTH-i-1;
        shift_detect = 1'b1;
    end
  end
end
endgenerate

assign magnitude_out = magnitude_in << shift;
assign exp_out = exp_in - shift - (FP_FXP_WIDTH - FXP_WIDTH); // assuming the exp_in will not be 0

assign fp_out = {sign, exp_out, magnitude_out};

//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_fp_normalize
  initial begin
    $dumpfile("fp_normalize.vcd");
    $dumpvars(0, fp_normalize);
end
`endif

endmodule
