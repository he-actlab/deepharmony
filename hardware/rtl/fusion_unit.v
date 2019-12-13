//
// Spatial: Low Precision Multiply-Accumulate
//
// Mode 0: 2K x 2K
// Mode 1: 2K x 1K
// Mode 2: 1K x 2K
// Mode 3: 1K x 1K
//
// Hardik Sharma
// (hsharma@gatech.edu)
`timescale 1ns/1ps
module fusion_unit #(

  parameter integer  ACT_PMAX                     = 8,
  parameter integer  WGT_PMAX                     = 8,

  parameter integer  PMAX                         = ACT_PMAX > WGT_PMAX ? ACT_PMAX : WGT_PMAX,
  parameter integer  PMIN                         = 2,

  parameter integer  TOP_MODULE                   = 1,                                    // 1: top or 0: not top

  parameter integer  ACT_SIGN_EXTEND              = 0,                                    // 1: extend or 0: not
  parameter integer  WGT_SIGN_EXTEND              = 0,                                    // 1: extend or 0: not

  // TODO: Implement signed fuse
  parameter integer  ACT_SIGNED                   = 0,
  parameter integer  WGT_SIGNED                   = 1,

  parameter integer  ACT_SUPPORTS_32              = "FALSE",
  parameter integer  ACT_SUPPORTS_16              = "FALSE",
  parameter integer  ACT_SUPPORTS_8               = "TRUE",
  parameter integer  ACT_SUPPORTS_4               = "TRUE",
  parameter integer  ACT_SUPPORTS_2               = "TRUE",
  parameter integer  ACT_SUPPORTS_1               = "FALSE",

  parameter integer  WGT_SUPPORTS_32              = "FALSE",
  parameter integer  WGT_SUPPORTS_16              = "FALSE",
  parameter integer  WGT_SUPPORTS_8               = "TRUE",
  parameter integer  WGT_SUPPORTS_4               = "TRUE",
  parameter integer  WGT_SUPPORTS_2               = "TRUE",
  parameter integer  WGT_SUPPORTS_1               = "FALSE",

  parameter integer  NUM_MULT                     = (ACT_PMAX / PMIN) * (WGT_PMAX / PMIN),
  parameter integer  MODE_WIDTH                   = $clog2(NUM_MULT),

  parameter integer  ACT_WIDTH                    = NUM_MULT * PMIN,  // Input width at current level
  parameter integer  WGT_WIDTH                    = NUM_MULT * PMIN,  // Input width at current level
  parameter integer  OUT_WIDTH                    = ACT_PMAX + WGT_PMAX + ACT_SIGN_EXTEND + WGT_SIGN_EXTEND                         // Output width at current level
) (
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire  [ 2                    -1 : 0 ]        prev_level_mode,
  input  wire  [ MODE_WIDTH           -1 : 0 ]        mode,
  input  wire  [ ACT_WIDTH            -1 : 0 ]        a,
  input  wire  [ WGT_WIDTH            -1 : 0 ]        b,
  output wire  [ OUT_WIDTH            -1 : 0 ]        out
);


genvar ii, jj, kk;
generate

    // Sign mode
    // Required when ACT_SIGN_EXTEND == 1 or WGT_SIGN_EXTEND == 1
    // This means that the sign for the MSB bits of an input depend on the higher level mode, instead of the current level mode
  wire [ 2                    -1 : 0 ]        higher_level_mode;
    if (TOP_MODULE == 1)
      assign higher_level_mode = 2'b0;
    else
      assign higher_level_mode = prev_level_mode;


  localparam integer  A_SIGNED_WIDTH               = ACT_WIDTH + ACT_SIGN_EXTEND;
  localparam integer  B_SIGNED_WIDTH               = WGT_WIDTH + WGT_SIGN_EXTEND;

    wire signed [ A_SIGNED_WIDTH -1 : 0 ] a_signed;
    wire signed [ B_SIGNED_WIDTH -1 : 0 ] b_signed;
    wire signed [ OUT_WIDTH      -1 : 0 ] out_signed;

    wire a_sign, b_sign;
    assign {a_sign, b_sign} = prev_level_mode;
    assign a_signed = {a_sign && a[ACT_WIDTH-1], a};
    assign b_signed = {b_sign && b[WGT_WIDTH-1], b};

//=========================================
// Generate FULL/HALF precision multilpier
//=========================================
  if (PMAX == PMIN)
  begin: FULL_PRECISION // Full Precision
    assign out_signed = a_signed * b_signed;
    assign out = out_signed;
  end

  else if (ACT_PMAX == WGT_PMAX)
  begin: SYMMETRIC_FUSION

  wire  act_prec_supported  = PMAX == 32 ? ACT_SUPPORTS_32 == "TRUE" :
                                            PMAX == 16 ? ACT_SUPPORTS_16 == "TRUE" :
                                            PMAX == 8  ? ACT_SUPPORTS_8 == "TRUE" :
                                            PMAX == 4  ? ACT_SUPPORTS_4 == "TRUE" :
                                            PMAX == 2  ? ACT_SUPPORTS_2 == "TRUE" : ACT_SUPPORTS_1 == "TRUE";
  wire  wgt_prec_supported  = PMAX == 32 ? WGT_SUPPORTS_32 == "TRUE" :
                                            PMAX == 16 ? WGT_SUPPORTS_16 == "TRUE" :
                                            PMAX == 8  ? WGT_SUPPORTS_8 == "TRUE" :
                                            PMAX == 4  ? WGT_SUPPORTS_4 == "TRUE" :
                                            PMAX == 2  ? WGT_SUPPORTS_2 == "TRUE" : ACT_SUPPORTS_1 == "TRUE";

    wire [1:0] curr_level_mode = {mode[MODE_WIDTH-1] || (~act_prec_supported && prev_level_mode[1]), mode[MODE_WIDTH-2] || (~wgt_prec_supported && prev_level_mode[0])};

//=========================================
// Step 1: Operand Select
//
// -------------
// | a_3 | a_2 |
// -------------
// | a_1 | a_0 |
// -------------
// Transpose required at Top Level for B
// -------------
// | b_3 | b_2 |
// -------------
// | b_1 | b_0 |
// -------------
//
//=========================================

  localparam integer  LP_MULT_A_W                  = ACT_WIDTH / 4;
  localparam integer  LP_MULT_B_W                  = WGT_WIDTH / 4;

  wire [ LP_MULT_A_W          -1 : 0 ]        a_0;
  wire [ LP_MULT_A_W          -1 : 0 ]        a_1;
  wire [ LP_MULT_A_W          -1 : 0 ]        a_2;
  wire [ LP_MULT_A_W          -1 : 0 ]        a_3;

  wire [ LP_MULT_B_W          -1 : 0 ]        b_0;
  wire [ LP_MULT_B_W          -1 : 0 ]        b_1;
  wire [ LP_MULT_B_W          -1 : 0 ]        b_2;
  wire [ LP_MULT_B_W          -1 : 0 ]        b_3;

  localparam integer  W_II_MAX                     = PMAX/(PMIN*2);
  localparam integer  W_JJ_MAX                     = PMAX/(PMIN*2);

    if (TOP_MODULE == 1)
    begin: B_TRANSPOSE
      for (ii=0; ii<W_II_MAX; ii=ii+1)
      begin: LOOP_II
        for (jj=0; jj<W_JJ_MAX; jj=jj+1)
        begin: LOOP_JJ
          for (kk=0; kk<PMIN; kk=kk+1)
          begin: LOOP_KK
            assign b_0[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((ii + 0       )+(jj + 0       )*W_JJ_MAX*2)];
            assign b_1[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((ii + 0       )+(jj + W_II_MAX)*W_JJ_MAX*2)];
            assign b_2[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((ii + W_JJ_MAX)+(jj + 0       )*W_JJ_MAX*2)];
            assign b_3[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((ii + W_JJ_MAX)+(jj + W_II_MAX)*W_JJ_MAX*2)];
          end
        end
      end
    end else
    begin
      for (ii=0; ii<W_II_MAX; ii=ii+1)
      begin: LOOP_II
        for (jj=0; jj<W_JJ_MAX; jj=jj+1)
        begin: LOOP_JJ
          for (kk=0; kk<PMIN; kk=kk+1)
          begin: LOOP_KK
            assign b_0[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((jj + 0       )+(ii + 0       )*W_JJ_MAX*2)];
            assign b_1[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((jj + W_JJ_MAX)+(ii + 0       )*W_JJ_MAX*2)];
            assign b_2[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((jj + 0       )+(ii + W_II_MAX)*W_JJ_MAX*2)];
            assign b_3[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((jj + W_JJ_MAX)+(ii + W_II_MAX)*W_JJ_MAX*2)];
          end
        end
      end
    end

  localparam integer  A_II_MAX                     = PMAX/(PMIN*2);
  localparam integer  A_JJ_MAX                     = PMAX/(PMIN*2);


    for (ii=0; ii<A_II_MAX; ii=ii+1)
    begin: LOOP_II
      for (jj=0; jj<A_JJ_MAX; jj=jj+1)
      begin: LOOP_JJ
        for (kk=0; kk<PMIN; kk=kk+1)
        begin: LOOP_KK
          assign a_0[kk+PMIN*(jj+ii*A_JJ_MAX)] = a[kk+PMIN*((jj + 0       )+(ii + 0       )*A_JJ_MAX*2)];
          assign a_1[kk+PMIN*(jj+ii*A_JJ_MAX)] = a[kk+PMIN*((jj + A_JJ_MAX)+(ii + 0       )*A_JJ_MAX*2)];
          assign a_2[kk+PMIN*(jj+ii*A_JJ_MAX)] = a[kk+PMIN*((jj + 0       )+(ii + A_II_MAX)*A_JJ_MAX*2)];
          assign a_3[kk+PMIN*(jj+ii*A_JJ_MAX)] = a[kk+PMIN*((jj + A_JJ_MAX)+(ii + A_II_MAX)*A_JJ_MAX*2)];
        end
      end
    end

//=========================================
// Half Precision Multipliers
//=========================================

    if (PMAX == 2)
    begin
      wire [2-1:0] sign_mode;
      wire [2-1:0] mode;
      wire  act_sign_extend = ACT_SIGN_EXTEND;
      wire  wgt_sign_extend = WGT_SIGN_EXTEND;
      assign sign_mode = {~higher_level_mode[1] && act_sign_extend, ~higher_level_mode[0] && wgt_sign_extend};
      assign mode = curr_level_mode;
      wire [5-1:0] _out;
      wire [3:0] _a;
      wire [3:0] _b;
      assign _a = {a_3, a_2, a_1, a_0};
      assign _b = {b_3, b_2, b_1, b_0};
      fusion_symmetric_2_1 #(.TOP_MODULE(1)) m0 (clk, reset, sign_mode, mode, _a, _b, _out);
      assign out = $signed(_out);
    end
    else begin
      // Partial Products
      wire signed [ PMAX + 1               + 1               -1 : 0 ] pp_0;
      wire signed [ PMAX + ACT_SIGN_EXTEND + 1               -1 : 0 ] pp_1;
      wire signed [ PMAX + 1               + WGT_SIGN_EXTEND -1 : 0 ] pp_2;
      wire signed [ PMAX + ACT_SIGN_EXTEND + WGT_SIGN_EXTEND -1 : 0 ] pp_3;

      wire [MODE_WIDTH-3:0] lower_level_mode;
      if (PMAX == PMIN * 2)
      begin: LAST_LEVEL
        assign lower_level_mode = 'b0;
      end
      else
      begin: NEXT_LEVEL
        assign lower_level_mode = mode[MODE_WIDTH-3:0];
      end

      wire [ 2                    -1 : 0 ]        m0_sign_mode;
      wire [ 2                    -1 : 0 ]        m1_sign_mode;
      wire [ 2                    -1 : 0 ]        m2_sign_mode;
      wire [ 2                    -1 : 0 ]        m3_sign_mode;

      assign m0_sign_mode = curr_level_mode;
      assign m1_sign_mode = {higher_level_mode[1], curr_level_mode[0]};
      assign m2_sign_mode = {curr_level_mode[1], higher_level_mode[0]};
      assign m3_sign_mode = higher_level_mode;

      localparam          HALF_PRECISION               = PMAX / 2;

      fusion_unit #(
        .ACT_PMAX                       ( HALF_PRECISION                 ),
        .WGT_PMAX                       ( HALF_PRECISION                 ),
        .PMIN                           ( PMIN                           ),
        .TOP_MODULE                     ( 0                              ),
        .ACT_SIGN_EXTEND                ( 1                              ),
        .WGT_SIGN_EXTEND                ( 1                              )) m0 (clk, reset, m0_sign_mode, lower_level_mode, a_0, b_0, pp_0);
      fusion_unit #(
        .ACT_PMAX                       ( HALF_PRECISION                 ),
        .WGT_PMAX                       ( HALF_PRECISION                 ),
        .PMIN                           ( PMIN                           ),
        .TOP_MODULE                     ( 0                              ),
        .ACT_SIGN_EXTEND                ( ACT_SIGN_EXTEND                ),
        .WGT_SIGN_EXTEND                ( 1                              )) m1 (clk, reset, m1_sign_mode, lower_level_mode, a_1, b_1, pp_1);
      fusion_unit #(
        .ACT_PMAX                       ( HALF_PRECISION                 ),
        .WGT_PMAX                       ( HALF_PRECISION                 ),
        .PMIN                           ( PMIN                           ),
        .TOP_MODULE                     ( 0                              ),
        .ACT_SIGN_EXTEND                ( 1                              ),
        .WGT_SIGN_EXTEND                ( WGT_SIGN_EXTEND                )) m2 (clk, reset, m2_sign_mode, lower_level_mode, a_2, b_2, pp_2);
      fusion_unit #(
        .ACT_PMAX                       ( HALF_PRECISION                 ),
        .WGT_PMAX                       ( HALF_PRECISION                 ),
        .PMIN                           ( PMIN                           ),
        .TOP_MODULE                     ( 0                              ),
        .ACT_SIGN_EXTEND                ( ACT_SIGN_EXTEND                ),
        .WGT_SIGN_EXTEND                ( WGT_SIGN_EXTEND                )) m3 (clk, reset, m3_sign_mode, lower_level_mode, a_3, b_3, pp_3);
//=========================================

//=========================================
// Step 2: Shift
// Mode:
//  0: PMAX   x PMAX
//  1: PMAX   x PMAX/2
//  2: PMAX/2 x PMAX
//  3: PMAX/2 x PMAX/2
//=========================================
    wire signed [OUT_WIDTH-1:0] spp_0;
    wire signed [OUT_WIDTH-1:0] spp_1;
    wire signed [OUT_WIDTH-1:0] spp_2;
    wire signed [OUT_WIDTH-1:0] spp_3;

  reg  [ 1                       : 0 ]        s_0;
  reg  [ 1                       : 0 ]        s_1;
  reg  [ 1                       : 0 ]        s_2;
  reg  [ 1                       : 0 ]        s_3;

    // Shift amounts
    always @(*) begin
      case (curr_level_mode)
        0: begin
          s_0 = 2'd0;
          s_1 = 2'd1;
          s_2 = 2'd1;
          s_3 = 2'd2;
        end
        1: begin
          s_0 = 2'd0;
          s_1 = 2'd1;
          s_2 = 2'd0;
          s_3 = 2'd1;
        end
        2: begin
          s_0 = 2'd0;
          s_1 = 2'd0;
          s_2 = 2'd1;
          s_3 = 2'd1;
        end
        3: begin
          s_0 = 2'd0;
          s_1 = 2'd0;
          s_2 = 2'd0;
          s_3 = 2'd0;
        end
      endcase
    end

    // generate shifted partial products
    assign spp_0 = pp_0 <<< (s_0 * HALF_PRECISION);
    assign spp_1 = pp_1 <<< (s_1 * HALF_PRECISION);
    assign spp_2 = pp_2 <<< (s_2 * HALF_PRECISION);
    assign spp_3 = pp_3 <<< (s_3 * HALF_PRECISION);
//=========================================

//=========================================
// Step 3: ADD
// out = spp_0 + spp_1 + spp_2 + spp_3
//=========================================
    assign out = spp_0 + spp_1 + spp_2 + spp_3;
//=========================================
    end
  end // Half Precision End


  else // (ACT_PMAX > WGT_PMAX)
  begin: ASYMMETRIC_FUSION

  wire  act_prec_supported  = PMAX == 32 ? ACT_SUPPORTS_32 == "TRUE" :
                                            PMAX == 16 ? ACT_SUPPORTS_16 == "TRUE" :
                                            PMAX == 8  ? ACT_SUPPORTS_8 == "TRUE" :
                                            PMAX == 4  ? ACT_SUPPORTS_4 == "TRUE" :
                                            PMAX == 2  ? ACT_SUPPORTS_2 == "TRUE" : ACT_SUPPORTS_1 == "TRUE";
    //wire curr_level_mode = {mode[MODE_WIDTH-1] || ~act_prec_supported};
    wire curr_level_mode = {mode[MODE_WIDTH-1] || (~act_prec_supported && prev_level_mode[1])};

//=========================================
// Step 1: Operand Select
//
// -------------
// | a_3 | a_2 |
// -------------
// | a_1 | a_0 |
// -------------
// Transpose required at Top Level for B
// -------------
// | b_3 | b_2 |
// -------------
// | b_1 | b_0 |
// -------------
//
//=========================================

  localparam integer  LP_MULT_A_W                  = ACT_WIDTH / 2;
  localparam integer  LP_MULT_B_W                  = WGT_WIDTH / 2;

  wire [ LP_MULT_A_W          -1 : 0 ]        a_0;
  wire [ LP_MULT_A_W          -1 : 0 ]        a_1;

  wire [ LP_MULT_B_W          -1 : 0 ]        b_0;
  wire [ LP_MULT_B_W          -1 : 0 ]        b_1;

  localparam integer  W_II_MAX                     = ACT_PMAX/(PMIN*2);
  localparam integer  W_JJ_MAX                     = WGT_PMAX/(PMIN*1);

    if (TOP_MODULE == 1)
    begin: B_TRANSPOSE
      for (ii=0; ii<W_II_MAX; ii=ii+1)
      begin: LOOP_II
        for (jj=0; jj<W_JJ_MAX; jj=jj+1)
        begin: LOOP_JJ
          for (kk=0; kk<PMIN; kk=kk+1)
          begin: LOOP_KK
            assign b_0[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((ii + 0       )+(jj + 0       )*W_II_MAX)];
            assign b_1[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((ii + 0       )+(jj + W_JJ_MAX)*W_II_MAX)];
          end
        end
      end
    end else
    begin
      for (ii=0; ii<W_II_MAX; ii=ii+1)
      begin: LOOP_II
        for (jj=0; jj<W_JJ_MAX; jj=jj+1)
        begin: LOOP_JJ
          for (kk=0; kk<PMIN; kk=kk+1)
          begin: LOOP_KK
            assign b_0[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((jj + 0       )+(ii + 0       )*W_JJ_MAX)];
            assign b_1[kk+PMIN*(jj+ii*W_JJ_MAX)] = b[kk+PMIN*((jj + W_JJ_MAX)+(ii + 0       )*W_JJ_MAX)];
          end
        end
      end
    end

  localparam integer  A_II_MAX                     = ACT_PMAX/(PMIN*2);
  localparam integer  A_JJ_MAX                     = WGT_PMAX/(PMIN*1);


    for (ii=0; ii<A_II_MAX; ii=ii+1)
    begin: LOOP_II
      for (jj=0; jj<A_JJ_MAX; jj=jj+1)
      begin: LOOP_JJ
        for (kk=0; kk<PMIN; kk=kk+1)
        begin: LOOP_KK
          assign a_0[kk+PMIN*(jj+ii*A_JJ_MAX)] = a[kk+PMIN*((jj + 0       )+(ii + 0       )*A_JJ_MAX)];
          assign a_1[kk+PMIN*(jj+ii*A_JJ_MAX)] = a[kk+PMIN*((jj + 0       )+(ii + A_II_MAX)*A_JJ_MAX)];
        end
      end
    end

//=========================================
// Half Precision Multipliers
//=========================================

    // Partial Products
    wire signed [ HALF_PRECISION + WGT_PMAX + 1               + WGT_SIGN_EXTEND  -1 : 0 ] pp_0;
    wire signed [ HALF_PRECISION + WGT_PMAX + ACT_SIGN_EXTEND + WGT_SIGN_EXTEND  -1 : 0 ] pp_1;

    wire [MODE_WIDTH-2:0] lower_level_mode;
    if (PMAX == PMIN * 2)
    begin: LAST_LEVEL
      assign lower_level_mode = 'b0;
    end
    else
    begin: NEXT_LEVEL
      assign lower_level_mode = mode[MODE_WIDTH-2:0];
    end

  wire [ 2                    -1 : 0 ]        m0_sign_mode;
  wire [ 2                    -1 : 0 ]        m1_sign_mode;

    assign m0_sign_mode = {curr_level_mode, curr_level_mode};
    assign m1_sign_mode = {higher_level_mode[0], curr_level_mode};

  localparam          HALF_PRECISION               = PMAX / 2;

    fusion_unit #(
    .ACT_PMAX                       ( HALF_PRECISION                 ),
    .WGT_PMAX                       ( WGT_PMAX                       ),
    .PMIN                           ( PMIN                           ),
    .TOP_MODULE                     ( 0                              ),
    .ACT_SIGN_EXTEND                ( 1                              ),
    .WGT_SIGN_EXTEND                ( WGT_SIGN_EXTEND                )) m0 (clk, reset, m0_sign_mode, lower_level_mode, a_0, b_0, pp_0);
    fusion_unit #(
    .ACT_PMAX                       ( HALF_PRECISION                 ),
    .WGT_PMAX                       ( WGT_PMAX                       ),
    .PMIN                           ( PMIN                           ),
    .TOP_MODULE                     ( 0                              ),
    .ACT_SIGN_EXTEND                ( ACT_SIGN_EXTEND                ),
    .WGT_SIGN_EXTEND                ( WGT_SIGN_EXTEND                )) m1 (clk, reset, m1_sign_mode, lower_level_mode, a_1, b_1, pp_1);
//=========================================

//=========================================
// Step 2: Shift
// Mode:
//  0: PMAX   x PMAX
//  1: PMAX   x PMAX/2
//  2: PMAX/2 x PMAX
//  3: PMAX/2 x PMAX/2
//=========================================
    wire signed [OUT_WIDTH-1:0] spp_0;
    wire signed [OUT_WIDTH-1:0] spp_1;

  reg  [ 1                       : 0 ]        s_0;
  reg  [ 1                       : 0 ]        s_1;

    // Shift amounts
    always @(*) begin
      case (curr_level_mode)
        0: begin
          s_0 = 2'd0;
          s_1 = 2'd1;
        end
        1: begin
          s_0 = 2'd0;
          s_1 = 2'd0;
        end
      endcase
    end

    // generate shifted partial products
    assign spp_0 = pp_0 <<< (s_0 * HALF_PRECISION);
    assign spp_1 = pp_1 <<< (s_1 * HALF_PRECISION);
//=========================================

//=========================================
// Step 3: ADD
// out = spp_0 + spp_1
//=========================================
    assign out = spp_0 + spp_1;
//=========================================
  end // Half Precision End












  endgenerate

//=========================================
// Debugging: COCOTB VCD
//=========================================
`ifdef COCOTB_TOPLEVEL_fusion_unit
if (TOP_MODULE == 1)
begin
  initial begin
    $dumpfile("fusion_unit.vcd");
    $dumpvars(0, fusion_unit);
  end
end
`endif

endmodule
