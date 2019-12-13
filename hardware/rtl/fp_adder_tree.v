`timescale 1ns/1ps
module fp_adder_tree #(
  parameter integer  FXP_WIDTH                    = 4,
  parameter integer  EXP_WIDTH                    = 6,
  parameter integer  FP_WIDTH                     = FXP_WIDTH + EXP_WIDTH + 1,
  parameter integer  LOG2_N                       = 1,                          // Log_2(Num of inputs)
  parameter integer  IN_WIDTH                     = (1<<LOG2_N)*FP_WIDTH,       // Input Width = 2 * Data Width
  parameter integer  OUT_WIDTH                    = FP_WIDTH,                   // Output Width
  parameter integer  TOP_MODULE                   = 1                           // Output Width
) (
  input  wire  [ IN_WIDTH             -1 : 0 ]        data_in,
  output wire  [ OUT_WIDTH            -1 : 0 ]        data_out
);

genvar ii, jj;
generate
if (LOG2_N == 0)
begin
  assign data_out = data_in;
end
else
begin

  localparam integer IN_LOW_WIDTH  = IN_WIDTH / 2; // Input at lower level has half width

  wire [ IN_LOW_WIDTH         -1 : 0 ]        in_0;
  wire [ IN_LOW_WIDTH         -1 : 0 ]        in_1;
  wire [ OUT_WIDTH            -1 : 0 ]        out_0;
  wire [ OUT_WIDTH            -1 : 0 ]        out_1;

  assign in_0 = data_in[0+:IN_LOW_WIDTH];
  assign in_1 = data_in[IN_LOW_WIDTH+:IN_LOW_WIDTH];

  fp_adder_tree #(
    .FXP_WIDTH                      ( FXP_WIDTH                      ),
    .EXP_WIDTH                      ( EXP_WIDTH                      ),
    .TOP_MODULE                     ( 0                              ),
    .LOG2_N                         ( LOG2_N -1                      )
  ) tree_0 (
    .data_in                        ( in_0                           ),
    .data_out                       ( out_0                          )
  );

  fp_adder_tree #(
    .FXP_WIDTH                      ( FXP_WIDTH                      ),
    .EXP_WIDTH                      ( EXP_WIDTH                      ),
    .TOP_MODULE                     ( 0                              ),
    .LOG2_N                         ( LOG2_N -1                      )
  ) tree_1 (
    .data_in                        ( in_1                           ),
    .data_out                       ( out_1                          )
  );

  fp_custom_adder #(
    .FXP_WIDTH                      ( FXP_WIDTH                      ),
    .EXP_WIDTH                      ( EXP_WIDTH                      )
  ) fp_add (
    .a_fp                           ( out_0                          ),
    .b_fp                           ( out_1                          ),
    .sum                            ( data_out                       )
  );
end
endgenerate
//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_signed_adder_tree
if (TOP_MODULE == 1)
begin
  initial begin
    $dumpfile("signed_adder_tree.vcd");
    $dumpvars(0, signed_adder_tree);
  end
end
`endif

endmodule
