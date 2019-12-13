module fp32_fxp_mul #(
  parameter integer  FXP_WIDTH                        = 32
) (
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire  [ 32                   -1 : 0 ]        a,
  input  wire  [ FXP_WIDTH            -1 : 0 ]        b,
  output wire  [ 32                   -1 : 0 ]        result
);

  wire signed [31:0] a_extended = $signed(a);
  wire [31:0] dequantized_a;
  
  fxp_to_fp32 dequantize(.clk(clk), .a(a), .result(dequantized_a));  
  fp32_mul mul (.clk(clk), .a(dequantized_a), .b(b), .result(result));

endmodule