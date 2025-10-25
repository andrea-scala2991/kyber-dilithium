`timescale 1ns / 1ps

module tb_Full_NTT;
    reg clk, r, valid_in;
    reg [11:0] coeffs[7:0];
    wire valid_out;
    wire [11:0] coeffs_out[7:0];

    // Instantiate the Full_NTT module
    Full_NTT dut (
        .coeffs(coeffs),
        .clk(clk),
        .r(r),
        .valid_in(valid_in),
        .valid_out(valid_out),
        .coeffs_out(coeffs_out)
    );

    // Clock
    localparam clock_period = 10;
    always
    begin
        clk=1'b0; #(clock_period/2.0);
        clk=1'b1; #(clock_period/2.0);
    end

    // Stimulus
    initial begin

        r = 1;
        valid_in = 0;
        #10;
        r = 0;
        valid_in = 1;

        // Load input vector [1 2 3 4 5 6 7 8]
        coeffs[0] = 12'd1;
        coeffs[1] = 12'd2;
        coeffs[2] = 12'd3;
        coeffs[3] = 12'd4;
        coeffs[4] = 12'd5;
        coeffs[5] = 12'd6;
        coeffs[6] = 12'd7;
        coeffs[7] = 12'd8;
        
        #10;
        valid_in = 0;

        #100;
        // Load input vector [10 20 30 40 50 60 70 80]
        valid_in = 1;
        
        coeffs[0] = 12'd10;
        coeffs[1] = 12'd20;
        coeffs[2] = 12'd30;
        coeffs[3] = 12'd40;
        coeffs[4] = 12'd50;
        coeffs[5] = 12'd60;
        coeffs[6] = 12'd70;
        coeffs[7] = 12'd80;
        #100;
        
        $finish;
    end
endmodule

