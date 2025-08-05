`timescale 1ns / 1ps

module tb_Full_iNTT;
    reg clk, r, valid_in;
    reg [11:0] coeffs[7:0];
    wire valid_out;
    wire [11:0] coeffs_out[7:0];

    // Instantiate the Full_NTT module
    Full_iNTT dut (
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
        r = 0;#100;
        valid_in = 1;

        // Load input vector from original [1 2 3 4 5 6 7 8]
        coeffs[0] = 12'd1971;       
        coeffs[1] = 12'd1875;
        coeffs[2] = 12'd2148;
        coeffs[3] = 12'd688;
        coeffs[4] = 12'd704;
        coeffs[5] = 12'd2124;
        coeffs[6] = 12'd1847;
        coeffs[7] = 12'd1967;
        
        #10;
        valid_in = 0;

        #100;
        // Load input vector from original [10 20 30 40 50 60 70 80]
        valid_in = 1;
        
        coeffs[0] = 12'd3065;  
        coeffs[1] = 12'd2105;
        coeffs[2] = 12'd1506; 
        coeffs[3] = 12'd222; 
        coeffs[4] = 12'd382;
        coeffs[5] = 12'd1266;
        coeffs[6] = 12'd1825; 
        coeffs[7] = 12'd3025;
        #100;
        
        $finish;
    end
endmodule

