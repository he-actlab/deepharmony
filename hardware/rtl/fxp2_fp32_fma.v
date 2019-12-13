module fxp2_fp32_fma (
  input clk,
  input [1:0] a,
  input [31:0] b,
  input [31:0] c,
  output [31:0] result
);

  wire [31:0] a_fp32;

  fxp2_to_fp32 dequantize (.a(a), .result(a_fp32));
  fp32_fma fma (.clk(clk), .a(a_fp32), .b(b), .c(c), .result(result));

endmodule
