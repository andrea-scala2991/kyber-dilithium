`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2025 13:48:52
// Design Name: 
// Module Name: Mod_sub
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Mod_sub(
        A,B,
        C
    );
    
    input wire[11:0] A,B;
    output wire[11:0] C;
    
    localparam q = 3329; //KYBER module
    
    
    wire is_bigger;
    wire signed[12:0] diff  = A - B;
    wire[11:0] sum = diff + q;
    
    assign is_smaller = diff < 0;
    
    assign C = (is_smaller) ? sum[11:0] : diff;
endmodule