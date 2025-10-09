`timescale 1ns / 1ps

/* ==========================================================================
    FULL NTT AND iNTT CONVERSION MODULE FOR N = 8
    OUTPUT VECTOR = INPUT VECTOR
==========================================================================*/
module FULL_NTT_iNTT(
    input wire[11:0] coeffs [7:0], //INPUT COEFFICIENTS
    input wire clk, r, valid_in, //CLOCK, RESET AND VALID INPUT BIT
    
    output wire valid_out, //VALID OUTPUT BIT
    output wire[11:0] coeffs_out [7:0] //OUTPUT COEFFICIENTS
    );
    //NTT OUTPUT WIRES, ALSO iNTT INPUTS
    wire NTT_valid_out;
    wire[11:0] NTT_coeffs_out [7:0];
    
    Full_NTT NTT (
        .coeffs(coeffs),
        .clk(clk),
        .r(r),
        .valid_in(valid_in),
        .valid_out(NTT_valid_out),
        .coeffs_out(NTT_coeffs_out)
    );
    
    Full_iNTT iNTT (
        .coeffs(NTT_coeffs_out),
        .clk(clk),
        .r(r),
        .valid_in(NTT_valid_out),
        .valid_out(valid_out),
        .coeffs_out(coeffs_out)
    );
    
endmodule
