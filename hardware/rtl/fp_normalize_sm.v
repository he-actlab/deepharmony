`timescale 1ns/1ps
module fp_normalize_sm #(
  parameter integer  FXP_WIDTH                    = 4,
  parameter integer  EXP_WIDTH                    = 5,
  parameter integer  EXP_OUT_WIDTH                = EXP_WIDTH + 1,
  parameter integer  FP_WIDTH                     = FXP_WIDTH + EXP_OUT_WIDTH + 1
) (
  input  wire                                         sign,
  input  wire  [ FXP_WIDTH            -1 : 0 ]        fxp_in,
  input  wire  [ EXP_WIDTH            -1 : 0 ]        exp_in,
  output wire  [ FP_WIDTH             -1 : 0 ]        fp_out
);

  localparam integer  SHIFT_WIDTH                  = $clog2(FXP_WIDTH);

  wire [ FXP_WIDTH            -1 : 0 ]        magnitude_in;

  wire [ FXP_WIDTH            -1 : 0 ]        magnitude_out;
  wire signed [ EXP_OUT_WIDTH        -1 : 0 ]        exp_out;

  reg  [ SHIFT_WIDTH          -1 : 0 ]        shift;
  reg                                         shift_detect;

  assign magnitude_in = fxp_in;

integer i;
generate
always @(magnitude_in)
begin
  shift = 0;
  shift_detect = 1'b0;
  for (i=FXP_WIDTH-1; i>-1; i=i-1)
  begin
    if (shift_detect == 0 && magnitude_in[i] == 1'b1) begin
        shift = FXP_WIDTH-i-1;
        shift_detect = 1'b1;
    end
  end
end
endgenerate

assign magnitude_out = magnitude_in << shift;
assign exp_out = exp_in - shift; // assuming the exp_in will not be 0

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
