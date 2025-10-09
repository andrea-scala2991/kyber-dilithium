`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2025 17:18:15
// Design Name: 
// Module Name: tb_Mod_mul
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


module tb_Mod_mul;

    // Inputs
    reg [11:0] A, B;
    reg clk, r;
    reg valid_in;
    // Output
    wire valid_out;
    wire [11:0] OUT;

    // Instantiate the modular multiplication module
    Mod_mul mul (
        .valid_in(valid_in),
        .valid_out(valid_out),
        .clk(clk),
        .r(r),
        .A(A),
        .B(B),
        .OUT(OUT)
    );

    //VIEW INTERNAL SIGNALS
    wire[23:0] c;
    assign c = mul.c;
    
    wire[23:0] c_reg;
    assign c_reg = mul.c_reg;

    wire[23:0] c_stage2;
    assign c_stage2 = mul.c_stage2;
    
    wire[23:0] c_stage3;
    assign c_stage3 = mul.c_stage3;

    
    wire signed[2:0] correct;
    assign correct = mul.correct;
    
    wire[23:0] m_hat;
    assign m_hat = mul.m_hat;
    
    wire[23:0] m;
    assign m = mul.m;

    wire[23:0] m_reg;
    assign m_reg = mul.m_reg;
    
    wire[23:0] q_mul_m;
    assign q_mul_m = mul.q_mul_m;

    wire[23:0] q_mul_m_reg;
    assign q_mul_m_reg = mul.q_mul_m_reg;

    wire[23:0] x;
    assign x = mul.x;

    localparam clock_period = 10; //10 nanoseconds
    // Clock generation:
    always
    begin
        clk=1'b0; #(clock_period/2.0);
        clk=1'b1; #(clock_period/2.0);
    end
    


    initial begin
        A = 12'd0; B = 12'd0;
        r = 1;#10; valid_in = 1'b0; r = 0;#10;
        // Test 1
        valid_in = 1'b1;
        A = 12'd0; B = 12'd0; #10;

        // Test 2
        A = 12'd1000; B = 12'd3; #10;

        // Test 3
        A = 12'd1000; B = 12'd1000;   #10;

        // Test 4
        A = 12'd3320;  B = 12'd3320;  #10;

        // Test 5
        A = 12'd3328;  B = 12'd3328;  #10;

        // Test 6
        A = 12'd3328; B = 12'd1;#10;
        
        // Test 7
        A = 12'd79; B = 12'd1729;#10;
        
        // TEST 8
        A = 12'd730; B = 12'd749;#10;
        
        A = 12'd2581; B = 12'd1;#10;
        
        A = 12'd7; B = 12'd1729;#10;
        
        A = 12'd9; B = 12'd1729;#10;
        
        A = 12'd3328; B = 12'd1729;#10; 
        valid_in = 1'b0;
        #50;
        
        $finish;
    end

endmodule
