//
// Signed multiplier
// Implements: out = in_0 * in_1 // Combinational Logic Only
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module mult_signed_unsigned #(
  parameter integer IN_0_WIDTH        = 2,
  parameter integer IN_1_WIDTH        = 2,
  parameter integer OUT_WIDTH         = IN_0_WIDTH + IN_1_WIDTH + 1
) (
  input  wire        [ IN_0_WIDTH -1 : 0 ]    in_0,
  input  wire        [ IN_1_WIDTH -1 : 0 ]    in_1,
  input  wire        [ 2          -1 : 0 ]    sign_mode,
  output wire        [ OUT_WIDTH  -1 : 0 ]    out
);

  reg [ OUT_WIDTH -1 : 0 ] _out;

  always @(*)
  begin: SIGNED_UNSIGNED_MULT
    case (sign_mode)
      0: _out = $unsigned( $unsigned(in_0) * $unsigned(in_1) );
      1: _out =   $signed(   $signed(in_0) * $unsigned(in_1) );
      2: _out =   $signed( $unsigned(in_0) *   $signed(in_1) );
      3: _out =   $signed(   $signed(in_0) *   $signed(in_1) );
    endcase
  end

  assign out = _out;

endmodule
