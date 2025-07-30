`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.07.2025 14:54:55
// Design Name: 
// Module Name: Butterfly_unit
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


module Butterfly_unit #(parameter twiddle = 1)(
    IN_1,IN_2, //12-BIT INPUTS
    clk,r, //CLOCK AND RESET FOR MULTIPLIER AND FLIP FLOPS
    valid_in, valid_out, //PIPELINE CONTROL SIGNALS FOR MULTIPLIER
    
    U,V // 12-BIT OUTPUTS    
    );
    
    input wire clk, r;
    input wire[11:0] IN_1, IN_2;
    input wire valid_in;
    
    output wire valid_out;
    output wire[11:0] U, V;
    
    //PIPELINE IN_1 TO SYNC WITH MULTIPLIER OUTPUT
    wire[11:0] IN_1_pipelined;
    reg[11:0] delay_pipe [0:2];

    always @(posedge clk, posedge r) begin
        if (r) begin
            delay_pipe[0] <= 0;
            delay_pipe[1] <= 0;
            delay_pipe[2] <= 0;
        end
        else if (valid_in) begin
            delay_pipe[0] <= IN_1;
            delay_pipe[1] <= delay_pipe[0];
            delay_pipe[2] <= delay_pipe[1];
        end
    end
    
    assign IN_1_pipelined = delay_pipe[2];
    
    
    wire[11:0] mul_out;//MULTIPLIER OUTPUT
    // Instantiate the modular multiplication module
    Mod_mul mul (
        .valid_in(valid_in),
        .valid_out(valid_out),
        .clk(clk),
        .r(r),
        .A(IN_2),
        .B(twiddle),
        .OUT(mul_out)
    );
    
    // Instantiate the modular addition module
    Mod_add add (
        .A(IN_1_pipelined),
        .B(mul_out),
        .C(U)
    );

    // Instantiate the modular subtraction module
    Mod_sub sub (
        .A(IN_1_pipelined),
        .B(mul_out),
        .C(V)
    );

endmodule
