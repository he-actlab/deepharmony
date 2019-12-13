//
// Spatial Multiplier: Input Mux
//
// Hardik Sharma
// (hsharma@gatech.edu)

`timescale 1ns/1ps
module input_mux_b #(
  parameter integer PRECISION                     = 8,                                   // Precision at current level
  parameter integer L_PRECISION                   = 2,                                    // Lowest precision
  parameter integer TOP_MODULE                    = 1,                                    // 1: top or 0: not
  parameter integer DATA_WIDTH                    = (PRECISION/L_PRECISION) * PRECISION,  // Input width at current level
  parameter integer HALF_PRECISION                = PRECISION / 2                         // Half of current level's precision
) (
  input  wire        [ DATA_WIDTH     -1 : 0 ]    b_in,
  output wire        [ DATA_WIDTH     -1 : 0 ]    b_out
);


genvar ii, jj, kk;
generate

//=========================================
// Generate FULL/HALF precision multilpier
//=========================================
  if (PRECISION == L_PRECISION)
  begin: FULL_PRECISION
    assign b_out = b_in;
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

    wire [ LP_MULT_IN_W - 1 : 0 ] b_0;
    wire [ LP_MULT_IN_W - 1 : 0 ] b_1;
    wire [ LP_MULT_IN_W - 1 : 0 ] b_2;
    wire [ LP_MULT_IN_W - 1 : 0 ] b_3;

    localparam integer II_MAX = PRECISION/(L_PRECISION*2);
    localparam integer JJ_MAX = PRECISION/(L_PRECISION*2); 

    if (TOP_MODULE == 1)
    begin: B_TRANSPOSE
      for (ii=0; ii<II_MAX; ii=ii+1)
      begin: LOOP_II
        for (jj=0; jj<JJ_MAX; jj=jj+1)
        begin: LOOP_JJ
          for (kk=0; kk<L_PRECISION; kk=kk+1)
          begin: LOOP_KK
            assign b_0[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((ii + 0     )+(jj + 0     )*JJ_MAX*2)];
            assign b_1[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((ii + 0     )+(jj + II_MAX)*JJ_MAX*2)];
            assign b_2[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((ii + JJ_MAX)+(jj + 0     )*JJ_MAX*2)];
            assign b_3[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((ii + JJ_MAX)+(jj + II_MAX)*JJ_MAX*2)];
          end
        end
      end
    end else
    begin
      for (ii=0; ii<II_MAX; ii=ii+1)
      begin: LOOP_II
        for (jj=0; jj<JJ_MAX; jj=jj+1)
        begin: LOOP_JJ
          for (kk=0; kk<L_PRECISION; kk=kk+1)
          begin: LOOP_KK
            assign b_0[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((jj + 0     )+(ii + 0     )*JJ_MAX*2)];
            assign b_1[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((jj + JJ_MAX)+(ii + 0     )*JJ_MAX*2)];
            assign b_2[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((jj + 0     )+(ii + II_MAX)*JJ_MAX*2)];
            assign b_3[kk+L_PRECISION*(jj+ii*JJ_MAX)] = b_in[kk+L_PRECISION*((jj + JJ_MAX)+(ii + II_MAX)*JJ_MAX*2)];
          end
        end
      end
    end

    // Mux'd output from lower level
    wire [ LP_MULT_IN_W - 1 : 0 ] b_0_out;
    wire [ LP_MULT_IN_W - 1 : 0 ] b_1_out;
    wire [ LP_MULT_IN_W - 1 : 0 ] b_2_out;
    wire [ LP_MULT_IN_W - 1 : 0 ] b_3_out;


    input_mux_b #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_3 (
      .b_in                         ( b_3                       ),
      .b_out                        ( b_3_out                   )
    );

    input_mux_b #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_2 (
      .b_in                         ( b_2                       ),
      .b_out                        ( b_2_out                   )
    );

    input_mux_b #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_1 (
      .b_in                         ( b_1                       ),
      .b_out                        ( b_1_out                   )
    );

    input_mux_b #(
      .PRECISION                    ( HALF_PRECISION            ),  // Precision at current level
      .L_PRECISION                  ( L_PRECISION               ),  // Lowest precision
      .TOP_MODULE                   ( 0                         )   // 1: top or 0: not
    ) mux_0 (
      .b_in                         ( b_0                       ),
      .b_out                        ( b_0_out                   )
    );

    assign b_out = {b_3_out, b_2_out, b_1_out, b_0_out};

  end // LP_MULT_INST
endgenerate

endmodule
