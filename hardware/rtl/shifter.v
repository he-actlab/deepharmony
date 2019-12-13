//
// Shifter
// Implements: out = in << shift // Combinational Logic Only
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module shifter #(
  parameter integer IN_WIDTH      = 8,
  parameter integer OUT_WIDTH     = 16,
  parameter integer SHIFT_WIDTH   = $clog2(OUT_WIDTH),
  parameter integer SHIFT_AMOUNT  = 1
) (
  input  wire signed [ IN_WIDTH    -1 : 0 ] in,
  input  wire        [ SHIFT_WIDTH -1 : 0 ] shift,
  output wire signed [ OUT_WIDTH   -1 : 0 ] out
);

  assign out = in <<< (shift * SHIFT_AMOUNT);

endmodule
