`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2025 14:22:41
// Design Name: 
// Module Name: tb_Mod_add_sub
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

module tb_Mod_add_sub;

    // Inputs
    reg [11:0] A, B;

    // Outputs
    wire [11:0] add_C;
    wire [11:0] sub_C;

    // Instantiate the modular addition module
    Mod_add add_mod (
        .A(A),
        .B(B),
        .C(add_C)
    );

    // Instantiate the modular subtraction module
    Mod_sub sub_mod (
        .A(A),
        .B(B),
        .C(sub_C)
    );

    initial begin
        // Test 1
        A = 12'd1000; B = 12'd1500; #10;

        // Test 2
        A = 12'd2000; B = 12'd1800; #10;

        // Test 3
        A = 12'd3320; B = 12'd20;   #10;

        // Test 4
        A = 12'd400;  B = 12'd800;  #10;

        // Test 5
        A = 12'd3328; B = 12'd1;    #10;
        
        //$random
        $finish;
    end
endmodule
