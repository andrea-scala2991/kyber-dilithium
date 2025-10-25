`timescale 1ns / 1ps

module tb_FULL_NTT_iNTT;
    `include "file_tasks.vh"
    
    // Internal signals
    reg clk, r, valid_in;
    reg [11:0] coeffs [7:0];
    wire [11:0] coeffs_out [7:0];
    wire valid_out;

    // Instantiate DUT
    FULL_NTT_iNTT dut (
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

    integer file, i, j, k, status, error_count = 0;
    // Delay buffer for inputs
    reg [11:0] input_buffer [20:0][7:0]; // buffer up to 21 vectors    
    
    initial begin
        //generate_input_vectors(); TOGGLE IF THERE'S NO FILE
        
        // Reset sequence
        r = 1; valid_in = 0;
        #10;
        r = 0;
        
        /*for (i = 3328; i > 3228; i--) begin
            valid_in = 1;
            for (j = 0; j < 8; j++) begin
                coeffs[j] = i[11:0];
            end
            #10;valid_in = 0;
        end
        
        #400;valid_in = 0;*/
        
        // Open test file
        file = $fopen("ntt_test_vectors.csv", "r");
        if (file == 0) begin
            $display("ERROR: Could not open test vector file.");
            $finish;
        end

        
        while (!$feof(file)) begin
            // Apply inputs
            @(posedge clk);
            // Read a full row (vector of 8)
            read_next_vector(file, coeffs, status);
            
            if (status == 0) begin
                $display("ERROR: COULD NOT READ LINE");
                $finish;
            end
            #10;         
            valid_in = 1;    
            //shift FIFO registers            
            for (j = 20; j >= 0; j = j - 1) begin
                if (j === 0) begin
                    for (k = 0; k < 8; k = k + 1)
                    input_buffer[0][k] = coeffs[k];
                end
                else begin
                
                    for (k = 0; k < 8; k = k + 1)
                        input_buffer[j][k] = input_buffer[j - 1][k]; 
                end
            end
            
            // Compare output after the delay
            if (valid_out) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (coeffs_out[j] !== input_buffer[17][j]) begin
                        $display("ERROR at t=%0t: output[%0d] = %0d, expected = %0d",
                                  $time, j, coeffs_out[j], input_buffer[0][j]);
                        error_count++;
                    end
                end
            end
            
            
                        
            #5;valid_in = 0;
            //shift FIFO registers            
            for (j = 20; j >= 0; j = j - 1) begin
                if (j === 0) begin
                    for (k = 0; k < 8; k = k + 1)
                    input_buffer[0][k] = coeffs[k];
                end
                else begin
                
                    for (k = 0; k < 8; k = k + 1)
                        input_buffer[j][k] = input_buffer[j - 1][k]; 
                end
            end
            
            
        end

        $finish;
    end
endmodule

