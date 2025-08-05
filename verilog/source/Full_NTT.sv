//NTT MODULE FOR N = 8
module Full_NTT(
        input wire[11:0] coeffs [7:0], //INPUT COEFFICIENTS
        input wire clk, r, valid_in, //CLOCK, RESET AND VALID INPUT BIT
        
        output wire valid_out, //VALID OUTPUT BIT
        output wire[11:0] coeffs_out [7:0] //OUTPUT COEFFICIENTS
    );
    //ZETA = 630, OMEGA = 749 > USED FOR TWIDDLE FACTORS
    //STAGE 1; DISTANCE 4; TWIDDLES 0, 2, 1, 3 = 1, 1729, 749, 40
    wire[11:0] u_1_1, v_1_1;
    localparam inverse = 0;
    
    Butterfly_unit #(.twiddle(1)) B_1_1 (
        .IN_1(coeffs[0]),
        .IN_2(coeffs[4]),
        .clk(clk),
        .r(r),
        .valid_in(valid_in),
        .valid_out(B_2_1.valid_in),
        .U_OUT(u_1_1),
        .V_OUT(v_1_1),
        .inverse(inverse)
    );
    
    wire[11:0] u_1_2, v_1_2;
    
    Butterfly_unit #(.twiddle(1729)) B_1_2 (
        .IN_1(coeffs[1]),
        .IN_2(coeffs[5]),
        .clk(clk),
        .r(r),
        .valid_in(valid_in),
        .valid_out(B_2_2.valid_in),
        .U_OUT(u_1_2),
        .V_OUT(v_1_2),
        .inverse(inverse)
    );
    
    wire[11:0] u_1_3, v_1_3;
    
    Butterfly_unit #(.twiddle(749)) B_1_3 (
        .IN_1(coeffs[2]),
        .IN_2(coeffs[6]),
        .clk(clk),
        .r(r),
        .valid_in(valid_in),
        .valid_out(B_2_3.valid_in),
        .U_OUT(u_1_3),
        .V_OUT(v_1_3),
        .inverse(inverse)
    );
    
    wire[11:0] u_1_4, v_1_4;
    
    Butterfly_unit #(.twiddle(40)) B_1_4 (
        .IN_1(coeffs[3]),
        .IN_2(coeffs[7]),
        .clk(clk),
        .r(r),
        .valid_in(valid_in),
        .valid_out(B_2_4.valid_in),
        .U_OUT(u_1_4),
        .V_OUT(v_1_4),
        .inverse(inverse)
    );

    //STAGE 2; DISTANCE 2; TWIDDLES 0, 1 = 1, 749
    wire[11:0] u_2_1, v_2_1;
    
    Butterfly_unit #(.twiddle(1)) B_2_1 (
        .IN_1(u_1_1), // INDEX 0
        .IN_2(u_1_3), // INDEX 2
        .clk(clk),
        .r(r),
        .valid_in(B_1_1.valid_out),
        .valid_out(B_3_1.valid_in),
        .U_OUT(u_2_1),
        .V_OUT(v_2_1),
        .inverse(inverse)
    );
    
    wire[11:0] u_2_2, v_2_2;
    
    Butterfly_unit #(.twiddle(749)) B_2_2 (
        .IN_1(u_1_2), //INDEX 1
        .IN_2(u_1_4), //INDEX 3
        .clk(clk),
        .r(r),
        .valid_in(B_1_2.valid_out),
        .valid_out(B_3_2.valid_in),
        .U_OUT(u_2_2),
        .V_OUT(v_2_2),
        .inverse(inverse)
    );
    
    wire[11:0] u_2_3, v_2_3;
    
    Butterfly_unit #(.twiddle(1)) B_2_3 (
        .IN_1(v_1_1), //INDEX 4
        .IN_2(v_1_3), //INDEX 6
        .clk(clk),
        .r(r),
        .valid_in(B_1_3.valid_out),
        .valid_out(B_3_3.valid_in),
        .U_OUT(u_2_3),
        .V_OUT(v_2_3),
        .inverse(inverse)
    );
    
    wire[11:0] u_2_4, v_2_4;
    
    Butterfly_unit #(.twiddle(749)) B_2_4 (
        .IN_1(v_1_2), //INDEX 5
        .IN_2(v_1_4), //INDEX 7
        .clk(clk),
        .r(r),
        .valid_in(B_1_4.valid_out),
        .valid_out(B_3_4.valid_in),
        .U_OUT(u_2_4),
        .V_OUT(v_2_4),
        .inverse(inverse)
    );
    
    //STAGE 3; DISTANCE 1; TWIDDLES 0 = 1
    wire[11:0] u_3_1, v_3_1;
    wire valid_out_1;
    
    Butterfly_unit #(.twiddle(1)) B_3_1 (
        .IN_1(u_2_1), //INDEX 0
        .IN_2(u_2_2), //INDEX 1
        .clk(clk),
        .r(r),
        .valid_in(B_2_1.valid_out),
        .valid_out(valid_out_1),
        .U_OUT(u_3_1),
        .V_OUT(v_3_1),
        .inverse(inverse)
    );
    
    wire[11:0] u_3_2, v_3_2;
    wire valid_out_2;
    
    Butterfly_unit #(.twiddle(1)) B_3_2 (
        .IN_1(v_2_1), //INDEX 2
        .IN_2(v_2_2), //INDEX 3
        .clk(clk),
        .r(r),
        .valid_in(B_2_2.valid_out),
        .valid_out(valid_out_2),
        .U_OUT(u_3_2),
        .V_OUT(v_3_2),
        .inverse(inverse)
    );
    
    wire[11:0] u_3_3, v_3_3;
    wire valid_out_3;
    
    Butterfly_unit #(.twiddle(1)) B_3_3 (
        .IN_1(u_2_3), //INDEX 4
        .IN_2(u_2_4), //INDEX 5
        .clk(clk),
        .r(r),
        .valid_in(B_2_3.valid_out),
        .valid_out(valid_out_3),
        .U_OUT(u_3_3),
        .V_OUT(v_3_3),
        .inverse(inverse)
    );
    
    wire[11:0] u_3_4, v_3_4;
    wire valid_out_4;
    
    Butterfly_unit #(.twiddle(1)) B_3_4 (
        .IN_1(v_2_3), //INDEX 6
        .IN_2(v_2_4), //INDEX 7
        .clk(clk),
        .r(r),
        .valid_in(B_2_4.valid_out),
        .valid_out(valid_out_4),
        .U_OUT(u_3_4),
        .V_OUT(v_3_4),
        .inverse(inverse)
    );
    
    assign coeffs_out[0] = u_3_1;
    assign coeffs_out[1] = v_3_1;
    assign coeffs_out[2] = u_3_2;
    assign coeffs_out[3] = v_3_2;
    assign coeffs_out[4] = u_3_3;
    assign coeffs_out[5] = v_3_3;
    assign coeffs_out[6] = u_3_4;
    assign coeffs_out[7] = v_3_4;

    assign valid_out = valid_out_1 & valid_out_2 & valid_out_3 & valid_out_4;      
endmodule