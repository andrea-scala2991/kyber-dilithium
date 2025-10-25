`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2025 13:48:52
// Design Name: 
// Module Name: Mod_add
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


module Mod_add(
        A,B,
        C
    );
    
    input wire[11:0] A,B;
    output wire[11:0] C;
    
    localparam q = 3329; //KYBER module
    
    
    wire is_bigger;
    wire[12:0] sum  = A + B;
    wire[11:0] diff = sum - q;
    
    assign is_bigger = sum >= q;
    
    assign C = (is_bigger) ? diff : sum[11:0];
    
endmodule
