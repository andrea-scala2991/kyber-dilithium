`timescale 1ns / 1ps

module tb_Butterfly_unit;

    // Parameters
    localparam q = 3329;
    localparam twiddle = 2; // example zeta

    // DUT Signals
    reg clk, r, valid_in, inverse;
    reg[11:0] IN_1, IN_2;
    wire[11:0] U, V;
    wire valid_out;

    // Expected results (delayed)
    wire[11:0] in1_pipe [0:2];
    reg[11:0] in2_pipe [0:2];

    reg[11:0] expected_u, expected_v;
    integer error_count = 0;
    integer i;

    // Instantiate DUT
    Butterfly_unit #(.twiddle(twiddle)) dut (
        .IN_1(IN_1),
        .IN_2(IN_2),
        .clk(clk),
        .r(r),
        .valid_in(valid_in),
        .valid_out(valid_out),
        .inverse(inverse),
        .U_OUT(U),
        .V_OUT(V)
    );
    assign in1_pipe[0]= dut.delay_pipe[0];
    assign in1_pipe[1]= dut.delay_pipe[1];
    assign in1_pipe[2]= dut.delay_pipe[2];
    
    // Clock
    localparam clock_period = 10;
    always
    begin
        clk=1'b0; #(clock_period/2.0);
        clk=1'b1; #(clock_period/2.0);
    end
    
    //MODULAR ARITHMETIC FUNCTIONS    
    function [11:0] mod_add(input [11:0] a, input [11:0] b);
        mod_add = (a + b) % q;
    endfunction
    
    function [11:0] mod_sub(input [11:0] a, input [11:0] b);
        reg signed [13:0] temp;
        begin
            temp = a - b;
            mod_sub = (temp % q + q) % q;
        end
    endfunction
    
    function [11:0] mod_mul(input [11:0] a, input [11:0] b);
        mod_mul = (a * b) % q;
    endfunction
    

    // Simulation
    initial begin
        clk = 0;
        r = 1;
        valid_in = 0;
        IN_1 <= 0;
        IN_2 <= 0;
        inverse = 0;
        #2;
        r = 0;
        valid_in <= 1;
        expected_u <= 0;
        expected_v <= 0;
       
        for (i = 0; i < 500; i = i + 1) begin
            @(posedge clk);
            IN_1 <= $urandom % q;
            IN_2 <= $urandom % q;
            valid_in <= 1;

            in2_pipe[0] <= IN_2;
            in2_pipe[1] <= in2_pipe[0];
            in2_pipe[2] <= in2_pipe[1];
            
            expected_u <= 0;
            expected_v <= 0;
                        
            if (valid_out & !(dut.inverse_pipe[2])) begin
                // Compute expected results
                expected_u <= mod_add(in1_pipe[1], mod_mul(twiddle, in2_pipe[1]));
                expected_v <= mod_sub(in1_pipe[1], mod_mul(twiddle, in2_pipe[1]));
    
                if (U !== expected_u || V !== expected_v) begin
                    $display("ERROR at test %0d:", i - 3);
                    $display("  IN_1 = %d, IN_2 = %d", in1_pipe[2], in2_pipe[2]);
                    $display("  U = %d (expected %d)", U, expected_u);
                    $display("  V = %d (expected %d)", V, expected_v);
                    error_count = error_count + 1;
                end
            end
            else begin 
                if (valid_out & (dut.inverse_pipe[3])) begin
                    expected_u <= mod_add(in1_pipe[1], in2_pipe[2]);
                    expected_v <= mod_mul(twiddle, mod_sub(in1_pipe[1], in2_pipe[1]));
        
                    if (U !== expected_u || V !== expected_v) begin
                        $display("ERROR at test %0d:", i - 3);
                        $display("  IN_1 = %d, IN_2 = %d", in1_pipe[2], in2_pipe[2]);
                        $display("  U = %d (expected %d)", U, expected_u);
                        $display("  V = %d (expected %d)", V, expected_v);
                        error_count = error_count + 1;
                    end
                end
            end     

        end
        
        #10;
        inverse <= 1;
        valid_in <= 0;#40;
        for (i = 500; i < 1000; i = i + 1) begin
            @(posedge clk);
            IN_1 <= $urandom % q;
            IN_2 <= $urandom % q;
            valid_in <= 1;

            in2_pipe[0] <= IN_2;
            in2_pipe[1] <= in2_pipe[0];
            in2_pipe[2] <= in2_pipe[1];
            
                        
            if (!(dut.inverse_pipe[2])) begin
                // Compute expected results
                expected_u <= mod_add(in1_pipe[1], mod_mul(twiddle, in2_pipe[1]));
                expected_v <= mod_sub(in1_pipe[1], mod_mul(twiddle, in2_pipe[1]));
    
                if (valid_out & (U !== expected_u || V !== expected_v)) begin
                    $display("ERROR at test %0d:", i - 3);
                    $display("  IN_1 = %d, IN_2 = %d", in1_pipe[2], in2_pipe[2]);
                    $display("  U = %d (expected %d)", U, expected_u);
                    $display("  V = %d (expected %d)", V, expected_v);
                    error_count = error_count + 1;
                end
            end
            else begin
                if ((dut.inverse_pipe[2])) begin
                    expected_u <= (mod_add(in1_pipe[1], in2_pipe[1]));
                    expected_v <= (mod_mul(twiddle, mod_sub(in1_pipe[1], in2_pipe[1])));
        
                    if (valid_out & (U !== expected_u || V !== expected_v)) begin
                        $display("ERROR at test %0d:", i - 3);
                        $display("  IN_1 = %d, IN_2 = %d", in1_pipe[2], in2_pipe[2]);
                        $display("  U = %d (expected %d)", U, expected_u);
                        $display("  V = %d (expected %d)", V, expected_v);
                        error_count = error_count + 1;
                    end
                end
            end
            
        end
        
        
        $display("Simulation completed. Total errors: %0d", error_count);
        $finish;
    end

endmodule