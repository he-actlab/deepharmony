module fp16_fxp8_mul #(
  parameter integer  FXP_WIDTH                        = 8
) (
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire  [ 16                   -1 : 0 ]        a,
  input  wire  [ FXP_WIDTH            -1 : 0 ]        b,
  output wire  [ 16                   -1 : 0 ]        result
);

  wire signed [7:0] a_extended = $signed(a);
  wire [15:0] dequantized_a;
  
  fxp8_to_fp16 dequantize(.clk(clk), .a(a), .result(dequantized_a));  
  fp16_mul mul (.clk(clk), .a(dequantized_a), .b(b), .result(result));

endmodule