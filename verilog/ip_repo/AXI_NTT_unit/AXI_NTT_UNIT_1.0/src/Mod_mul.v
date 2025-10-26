`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.07.2025 13:46:33
// Design Name: 
// Module Name: Mod_mul
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

//3 STAGE PIPELINED BARRET-LIKE MULTIPLY
module Mod_mul(
        clk, r,     //CLOCK, RESET
        A,B,        //12-BIT INPUTS
        valid_in,   //PIPELINE CONTROL SIGNAL
        
        valid_out,  //PIPELINE CONTROL SIGNAL
        OUT         //12-BIT OUTPUT
    );
    input wire clk, r;
    input wire[11:0] A,B;
    input wire valid_in;
    
    output wire valid_out;
    output wire[11:0] OUT;
 
    
    localparam q = 3329; //KYBER module
    
    // MULTIPLY A*B
    wire[23:0] c;
    assign c = A*B;
    
    //STAGE 1 PIPELINE INPUT
    reg[23:0] c_reg;
    always @(posedge clk, posedge r) begin
        if (r == 1'b1)
            c_reg <= 23'b0;
        else
            c_reg <= c;
    end
    
    //SHIFT REGISTER FOR VALID DATA OUTPUT SIGNAL
    reg [2:0] valid_pipe;
    assign valid_out = valid_pipe[2]; // output is delayed 3 cycles

    always @(posedge clk, posedge r) begin
        if (r == 1'b1)
            valid_pipe <= 3'b000;
        else
            valid_pipe <= {valid_pipe[1:0], valid_in};
    end

    
    //STEP 1: CALCULATE m_hat = ceil(c/q) = c/3329 = c/4096(1+1/4-1/64-1/256) ~ (c >> 12) + (c >> 14) - (c >> 18) - (c >> 20)
    wire[23:0] m_hat;
    assign m_hat = (c_reg >> 12) + (c_reg >> 14) - ((c_reg >> 18) + (c_reg >> 20));
    
    //CORRECTION FACTOR DUE TO LOSS OF INFORMATION FROM SHIFTING
    //STEP 2:correct = round((c[11:9] + c[13:11] - c[17:15] - c[19:17]) >> 3) = ((c[11:9] + c[13:11] - c[17:15] - c[19:17] + 4) >> 3)
    // Extract fields as signed (4-bit is sufficient for 3-bit fields)
    wire[2:0] a11_9   = c_reg[11:9];
    wire[2:0] a13_11  = c_reg[13:11];
    wire[2:0] a17_15  = c_reg[17:15];
    wire[2:0] a19_17  = c_reg[19:17];
    
    
    // Compute raw correction
    wire[4:0] correct_raw = (a11_9 + a13_11 - a17_15 - a19_17);
    wire signed[4:0] correct_raw_signed = correct_raw;
    // True signed rounding to nearest
    wire signed [5:0] biased;
    assign biased = (correct_raw_signed >= 0) ? 
                    (correct_raw_signed + 4) : (correct_raw_signed - 4);
    
    // Perform logic shift right (acts as unsigned division by 8)
    wire signed[2:0] abs_shifted;
    assign abs_shifted = (biased > -8 && biased < 0) ? 0 :
                         (biased <= -8 && biased > -16) ? -1 :
                         (biased <= -16) ? -2 : biased >> 3;
    
    // Now manually restore sign
    wire signed [2:0] correct;
    assign correct = abs_shifted;
    
    /*wire signed[4:0] correct_temp;
    assign correct_temp = (correct_raw >= 0) ?
                     ((correct_raw + 6'sd4)) :
                     ((correct_raw - 6'sd4));
    
    wire signed[1:0] correct_temp_shift = correct_temp[4:3];
    
    wire signed[1:0] correct = correct_raw[4:3];
    assign correct = (correct_temp > 1)  ? 2'sd1 :
                     (correct_temp < -1) ? -2'sd1 :
                        correct_temp;*/
    
    //STEP 3: m = m_hat + correct
    wire[23:0] m;
    //assign m = (m_hat === 0) ? $signed(m_hat) : $signed(m_hat) + correct;
    assign m = $signed(m_hat) + correct;
    
    //STAGE 2 PIPELINE INPUT
    reg[23:0] c_stage2;
    reg[23:0] m_reg;
    always @(posedge clk, posedge r) begin
        if (r == 1'b1) begin
            m_reg <= 23'b0;
            c_stage2 <= 23'b0;
        end
        else begin
            m_reg <= m;
            c_stage2 <= c_reg;
        end
    end
    
    //STEP 4: x = c - (q * m)
    //MULTIPLY q * m
    //q = 3329 = 2^11 + 2^10 + 2^8 + 1
    //HENCE q * m = m * (2^11 + 2^10 + 2^8 + 1) = (m << 11) + (m << 10) + (m << 8) + m
    wire[23:0] q_mul_m;
    assign q_mul_m = (m_reg << 11) + (m_reg << 10) + (m_reg << 8) + m_reg;
    
    //STAGE 3 PIPELINE INPUT
    reg[23:0] c_stage3;
    reg[23:0] q_mul_m_reg;
    
    always @(posedge clk, posedge r) begin
        if (r == 1'b1) begin
            q_mul_m_reg <= 23'b0;
            c_stage3 <= 0;
        end
        else begin
            q_mul_m_reg <= q_mul_m;
            c_stage3 <= c_stage2;
        end
    end
    
    //FINISH STEP 4
    wire signed[12:0] x;
    assign x = c_stage3 - q_mul_m_reg;
    
    //STEP 5: if x < 0 then x = x + q
    assign OUT = x[12] ? x[11:0] + q : x[11:0]; 
endmodule
