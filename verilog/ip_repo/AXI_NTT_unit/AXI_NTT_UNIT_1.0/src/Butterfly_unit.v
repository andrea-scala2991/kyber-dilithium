`timescale 1ns / 1ps

module Butterfly_unit (
    IN_1,IN_2, //12-BIT INPUTS
    twiddle, //TWIDDLE FACTOR
    clk,r, //CLOCK AND RESET FOR MULTIPLIER AND FLIP FLOPS
    inverse,valid_in, valid_out, //PIPELINE CONTROL SIGNALS FOR MULTIPLIER AND BIT FOR INTT
    
    U_OUT,V_OUT // 12-BIT OUTPUTS    
    );
    
    input wire clk, r;
    input wire[11:0] IN_1, IN_2, twiddle;
    input wire valid_in, inverse;
    
    output wire valid_out;
    
    // Pipeline inverse flag to stay in sync
    reg [2:0] inverse_pipe;
    wire transition = inverse_pipe[1] != inverse_pipe[2];
    
    always @(posedge clk or posedge r) begin
        if (r)
            inverse_pipe <= 3'b000;
        else
            inverse_pipe <= {inverse_pipe[1:0], inverse};
    end
    wire inverse_synced = inverse_pipe[2];
    
    wire[11:0] U, V;
    
    //PIPELINE IN_1 TO SYNC WITH MULTIPLIER OUTPUT
    wire[11:0] IN_1_pipelined;
    reg[11:0] delay_pipe [0:2];

    always @(posedge clk, posedge r) begin
        if (r) begin
            delay_pipe[0] <= 0;
            delay_pipe[1] <= 0;
            delay_pipe[2] <= 0;
        end
        else begin
            delay_pipe[0] <= IN_1;
            delay_pipe[1] <= delay_pipe[0];
            delay_pipe[2] <= delay_pipe[1];
        end
    end
    
    assign IN_1_pipelined = delay_pipe[2];
    //DECIDE INPUT BASED ON INVERSE CONTROL SIGNAL
    wire[11:0] IN_1_final;
    assign IN_1_final = inverse_synced ? IN_1 : IN_1_pipelined; //DIRECT INPUT IF INTT
    
    
    wire[11:0] mul_in; //MULTIPLIER INPUT
    assign mul_in = inverse_synced ? sub.C : IN_2;
    
    wire[11:0] mul_out;//MULTIPLIER OUTPUT
    // Instantiate the modular multiplication module
    Mod_mul mul (
        .valid_in(valid_in),
        .valid_out(valid_out),
        .clk(clk),
        .r(r),
        .A(mul_in),
        .B(twiddle),
        .OUT(mul_out)
    );
    
    // Instantiate the modular addition module
    //ADDER INPUT 
    wire[11:0] add_sub_in;
    assign add_sub_in = inverse_synced ? IN_2 : mul_out;
    
    Mod_add add (
        .A(IN_1_final),
        .B(add_sub_in),
        .C(U)
    );

    // Instantiate the modular subtraction module
    Mod_sub sub (
        .A(IN_1_final),
        .B(add_sub_in),
        .C(V)
    );
    //FINAL OUTPUTS
    output wire[11:0] U_OUT, V_OUT;
    
    //conditional right shift for odd numbers (normal right shift outputs wrong results)
    wire[11:0] U_shift;
    
    //check if U is odd
    assign U_shift = U[0] ? ((11'd1664) + ((U + 1'b1) >> 1'b1)) : U >> 1'b1;
    
    // Delay adder output (U) in iNTT mode to match multiplier latency
    reg [11:0] U_pipe [0:2];
    always @(posedge clk or posedge r) begin
        if (r) begin
            U_pipe[0] <= 0;
            U_pipe[1] <= 0;
            U_pipe[2] <= 0;
        end
        else begin
            U_pipe[0] <= U_shift;
            U_pipe[1] <= U_pipe[0];
            U_pipe[2] <= U_pipe[1];
        end
    end
    
    assign U_OUT = inverse_synced ? (U_pipe[2]) : U;
    
    //conditional right shift for odd numbers (normal right shift outputs wrong results)
    wire[11:0] V_shift;
    
    //check if U is odd
    assign V_shift = mul_out[0] ? ((11'd1664) + ((mul_out + 1'b1) >> 1'b1)) : mul_out >> 1'b1;
    
    assign V_OUT = inverse_synced ? (V_shift) : V;

endmodule
