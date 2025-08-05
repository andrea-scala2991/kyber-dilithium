//iNTT MODULE FOR N = 8, DECIMATION IN FREQUENCY
module Full_iNTT(
        input wire[11:0] coeffs [7:0], //INPUT COEFFICIENTS
        input wire clk, r, valid_in, //CLOCK, RESET AND VALID INPUT BIT
        
        output wire valid_out, //VALID OUTPUT BIT
        output wire[11:0] coeffs_out [7:0] //OUTPUT COEFFICIENTS
    );
    //ZETA = 630, OMEGA_INV = 3289 > USED FOR TWIDDLE FACTORS
    
    localparam inverse = 1;
    //STAGE 1; DISTANCE 1; TWIDDLES 0 = 1
    wire valid_s1_out1, valid_s1_out2, valid_s1_out3, valid_s1_out4;
    wire [11:0] u_1_1, v_1_1, u_1_2, v_1_2, u_1_3, v_1_3, u_1_4, v_1_4;

    Butterfly_unit #(.twiddle(1)) B_1_1 (.IN_1(coeffs[0]), .IN_2(coeffs[1]), .clk(clk), .r(r),
        .valid_in(valid_in), .valid_out(valid_s1_out1), .U_OUT(u_1_1), .V_OUT(v_1_1), .inverse(inverse));
        
    Butterfly_unit #(.twiddle(1)) B_1_2 (.IN_1(coeffs[2]), .IN_2(coeffs[3]), .clk(clk), .r(r),
        .valid_in(valid_in), .valid_out(valid_s1_out2), .U_OUT(u_1_2), .V_OUT(v_1_2), .inverse(inverse));
    
    Butterfly_unit #(.twiddle(1)) B_1_3 (.IN_1(coeffs[4]), .IN_2(coeffs[5]), .clk(clk), .r(r),
        .valid_in(valid_in), .valid_out(valid_s1_out3), .U_OUT(u_1_3), .V_OUT(v_1_3), .inverse(inverse));
    
    Butterfly_unit #(.twiddle(1)) B_1_4 (.IN_1(coeffs[6]), .IN_2(coeffs[7]), .clk(clk), .r(r),
        .valid_in(valid_in), .valid_out(valid_s1_out4), .U_OUT(u_1_4), .V_OUT(v_1_4), .inverse(inverse));
    
    //STAGE 2; DISTANCE 2; TWIDDLES 0, 1 = 1, 3289
    wire valid_s2_out1, valid_s2_out2, valid_s2_out3, valid_s2_out4;
    wire [11:0] u_2_1, v_2_1, u_2_2, v_2_2, u_2_3, v_2_3, u_2_4, v_2_4;

    Butterfly_unit #(.twiddle(1))     B_2_1 (.IN_1(u_1_1), .IN_2(u_1_2), .clk(clk), .r(r),
        .valid_in(valid_s1_out1), .valid_out(valid_s2_out1), .U_OUT(u_2_1), .V_OUT(v_2_1), .inverse(inverse));

    Butterfly_unit #(.twiddle(3289))  B_2_2 (.IN_1(v_1_1), .IN_2(v_1_2), .clk(clk), .r(r),
        .valid_in(valid_s1_out2), .valid_out(valid_s2_out2), .U_OUT(u_2_2), .V_OUT(v_2_2), .inverse(inverse));

    Butterfly_unit #(.twiddle(1))     B_2_3 (.IN_1(u_1_3), .IN_2(u_1_4), .clk(clk), .r(r),
        .valid_in(valid_s1_out3), .valid_out(valid_s2_out3), .U_OUT(u_2_3), .V_OUT(v_2_3), .inverse(inverse));

    Butterfly_unit #(.twiddle(3289))  B_2_4 (.IN_1(v_1_3), .IN_2(v_1_4), .clk(clk), .r(r),
        .valid_in(valid_s1_out4), .valid_out(valid_s2_out4), .U_OUT(u_2_4), .V_OUT(v_2_4), .inverse(inverse));

    //STAGE 3; DISTANCE 4; TWIDDLES 0, 1, 2, 3 = 1, 3289, 1600, 2580
    wire valid_s3_out1, valid_s3_out2, valid_s3_out3, valid_s3_out4;
    wire [11:0] u_3_1, v_3_1, u_3_2, v_3_2, u_3_3, v_3_3, u_3_4, v_3_4;

    Butterfly_unit #(.twiddle(1))     B_3_1 (.IN_1(u_2_1), .IN_2(u_2_3), .clk(clk), .r(r),
        .valid_in(valid_s2_out1), .valid_out(valid_s3_out1), .U_OUT(u_3_1), .V_OUT(v_3_1), .inverse(inverse));

    Butterfly_unit #(.twiddle(1600))  B_3_2 (.IN_1(u_2_2), .IN_2(u_2_4), .clk(clk), .r(r),
        .valid_in(valid_s2_out2), .valid_out(valid_s3_out2), .U_OUT(u_3_2), .V_OUT(v_3_2), .inverse(inverse));

    Butterfly_unit #(.twiddle(3289))  B_3_3 (.IN_1(v_2_1), .IN_2(v_2_3), .clk(clk), .r(r),
        .valid_in(valid_s2_out3), .valid_out(valid_s3_out3), .U_OUT(u_3_3), .V_OUT(v_3_3), .inverse(inverse));

    Butterfly_unit #(.twiddle(2580))  B_3_4 (.IN_1(v_2_2), .IN_2(v_2_4), .clk(clk), .r(r),
        .valid_in(valid_s2_out4), .valid_out(valid_s3_out4), .U_OUT(u_3_4), .V_OUT(v_3_4), .inverse(inverse));
    
    assign coeffs_out[0] = u_3_1 >> 3;
    assign coeffs_out[1] = u_3_2 >> 3;
    assign coeffs_out[2] = u_3_3 >> 3;
    assign coeffs_out[3] = u_3_4 >> 3;
    assign coeffs_out[4] = v_3_1 >> 3;
    assign coeffs_out[5] = v_3_2 >> 3;
    assign coeffs_out[6] = v_3_3 >> 3;
    assign coeffs_out[7] = v_3_4 >> 3;

    assign valid_out = valid_s3_out1 & valid_s3_out2 & valid_s3_out3 & valid_s3_out4;      
endmodule