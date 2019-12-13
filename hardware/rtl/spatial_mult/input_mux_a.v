//
// Spatial Multiplier: Input Mux
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module input_mux_a #(
  parameter integer PRECISION                     = 8,                                   // Precision at current level
  parameter integer L_PRECISION                   = 2,                                    // Lowest precision
  parameter integer TOP_MODULE                    = 1,                                    // 1: top or 0: not
  parameter integer DATA_WIDTH                    = (PRECISION/L_PRECISION) * PRECISION,  // Input width at current level
  parameter integer HALF_PRECISION                = PRECISION / 2                         // Half of current level's precision
) (
  input  wire        [ DATA_WIDTH     -1 : 0 ]    a_in,
  output wire        [ DATA_WIDTH     -1 : 0 ]    a_out
);


genvar ii, jj, kk;
generate

//=========================================
// Generate FULL/HALF precision multilpier
//=========================================
  if (PRECISION == L_PRECISION)
  begin: FULL_PRECISION
    assign a_out = a_in;
  end // FULL_PRECISION

  else
  begin: LP_MULT_INST

    //=========================================
    // Operand Select
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

    localparam integer LP_MULT_IN_W = DATA_WIDTH / 4;

    wire [ LP_MULT_IN_W - 1 : 0 ] a_0;
    wire [ LP_MULT_IN_W - 1 : 0 ] a_1;
    wire [ LP_MULT_IN_W - 1 : 0 ] a_2;
    wire [ LP_MULT_IN_W - 1 : 0 ] a_3;

    localparam integer II_MAX = PRECISION/(L_PRECISION*2);
    localparam integer JJ_MAX = PRECISION/(L_PRECISION*2); 

    for (ii=0; ii<II_MAX; ii=ii+1)
    begin: LOOP_II
      for (jj=0; jj<JJ_MAX; jj=jj+1)
      begin: LOOP_JJ
        for (kk=0; kk<L_PRECISION; kk=kk+1)
        begin: LOOP_KK
          assign a_0[kk+L_PRECISION*(jj+ii*JJ_MAX)] = a_in[kk+L_PRECISION*((jj + 0     )+(ii + 0     )*JJ_MAX*2)];
          assign a_1[kk+L_PRECISION*(jj+ii*JJ_MAX)] = a_in[kk+L_PRECISION*((jj + JJ_MAX)+(ii + 0     )*JJ_MAX*2)];
          assign a_2[kk+L_PRECISION*(jj+ii*JJ_MAX)] = a_in[kk+L_PRECISION*((jj + 0     )+(ii + II_MAX)*JJ_MAX*2)];
          assign a_3[kk+L_PRECISION*(jj+ii*JJ_MAX)] = a_in[kk+L_PRECISION*((jj + JJ_MAX)+(ii + II_MAX)*JJ_MAX*2)];
        end
      end
    end

    // Mux'd output from lower level
    wire [ LP_MULT_IN_W - 1 : 0 ] a_0_out;
    wire [ LP_MULT_IN_W - 1 : 0 ] a_1_out;
    wire [ LP_MULT_IN_W - 1 : 0 ] a_2_out;
    wire [ LP_MULT_IN_W - 1 : 0 ] a_3_out;

    input_mux_a #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_3 (
      .a_in                         ( a_3                       ),
      .a_out                        ( a_3_out                   )
    );

    input_mux_a #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_2 (
      .a_in                         ( a_2                       ),
      .a_out                        ( a_2_out                   )
    );

    input_mux_a #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_1 (
      .a_in                         ( a_1                       ),
      .a_out                        ( a_1_out                   )
    );

    input_mux_a #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_0 (
      .a_in                         ( a_0                       ),
      .a_out                        ( a_0_out                   )
    );

    assign a_out = {a_3_out, a_2_out, a_1_out, a_0_out};

  end // LP_MULT_INST
endgenerate

endmodule
