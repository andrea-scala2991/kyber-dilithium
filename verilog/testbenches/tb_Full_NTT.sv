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

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Stimulus
    initial begin
        $dumpfile("full_ntt.vcd");  // For GTKWave or other VCD viewers
        $dumpvars(0, tb_Full_NTT);

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

        #100;
                // Load input vector [1 2 3 4 5 6 7 8]
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

