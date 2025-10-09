`timescale 1ns / 1ps

module tb_NTT_Controller;

    localparam int N = 4;
    localparam int LATENCY = 3;
    localparam int ADDR_WIDTH = $clog2(N);
    localparam int DATA_WIDTH = 12;

    localparam int TWIDDLE_COUNT = N;
    //TWIDDLES FOR N = 8
    /*localparam logic [DATA_WIDTH-1:0] twiddle_rom [0:TWIDDLE_COUNT-1] =
        '{12'd1, 12'd1729, 12'd749, 12'd40, 12'd1, 12'd1600, 12'd3289, 12'd2580};*/
    
    //TWIDDLES FOR N = 4
    localparam logic [DATA_WIDTH-1:0] twiddle_rom [0:TWIDDLE_COUNT-1] =
        '{12'd1, 12'd1600, 12'd1, 12'd1729};

    logic clk, rst, enable, mode, done;

    // BRAM bank 0
    logic [ADDR_WIDTH-1:0] bram0_addr_a, bram0_addr_b;
    logic bram0_we_a, bram0_we_b;
    logic [DATA_WIDTH-1:0] bram0_dout_a, bram0_dout_b;
    logic [DATA_WIDTH-1:0] bram0_din_a, bram0_din_b;

    // BRAM bank 1
    logic [ADDR_WIDTH-1:0] bram1_addr_a, bram1_addr_b;
    logic bram1_we_a, bram1_we_b;
    logic [DATA_WIDTH-1:0] bram1_dout_a, bram1_dout_b;
    logic [DATA_WIDTH-1:0] bram1_din_a, bram1_din_b;

    // ROM
    logic [ADDR_WIDTH-1:0] rom_addr;
    logic [DATA_WIDTH-1:0] rom_dout;

    // Butterfly
    logic [DATA_WIDTH-1:0] butterfly_in1, butterfly_in2;
    logic [DATA_WIDTH-1:0] butterfly_twiddle;
    logic butterfly_inverse;
    logic valid_in, valid_out;
    logic [DATA_WIDTH-1:0] butterfly_u, butterfly_v;

    // DUT
    NTT_Controller #(
        .N(N),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LATENCY(LATENCY)
    ) dut (
        .*
    );

    // Butterfly
    Butterfly_unit butterfly (
        .IN_1(butterfly_in1),
        .IN_2(butterfly_in2),
        .twiddle(butterfly_twiddle),
        .clk(clk),
        .r(rst),
        .inverse(butterfly_inverse),
        .valid_in(valid_in),
        .valid_out(valid_out),
        .U_OUT(butterfly_u),
        .V_OUT(butterfly_v)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    // BRAM emulation: two separate memories (ping-pong banks)
    logic [DATA_WIDTH-1:0] mem0 [0:N-1];
    logic [DATA_WIDTH-1:0] mem1 [0:N-1];

    initial begin
        for (int i=0; i<N; i++) begin
            mem0[i] = i * 2;  // initial data in bank0
            mem1[i] = '0;
        end
    end

    // Synchronous dual-port behavior for both banks
    //  WRITE-FIRST
    always_ff @(posedge clk) begin
        // READS: synchronous  
        bram0_dout_a <= mem0[bram0_addr_a];
        bram0_dout_b <= mem0[bram0_addr_b];
        bram1_dout_a <= mem1[bram1_addr_a];
        bram1_dout_b <= mem1[bram1_addr_b];
    end
    
    always_comb begin
        if (bram0_we_a) mem0[bram0_addr_a] = bram0_din_a;
        if (bram0_we_b) mem0[bram0_addr_b] = bram0_din_b;
        if (bram1_we_a) mem1[bram1_addr_a] = bram1_din_a;
        if (bram1_we_b) mem1[bram1_addr_b] = bram1_din_b;
    end
    

    // ROM model (1-cycle synchronous read delay)
    always_ff @(posedge clk) begin    
        if (rom_addr < TWIDDLE_COUNT)
            rom_dout <= twiddle_rom[rom_addr];
        else
            rom_dout <= '0;
    end

    integer timeout;
    initial begin
        rst = 1; enable = 0; mode = 0;
        #20 rst = 0;

        $display("\n--- Initial MEM0 ---");
        for (int i=0;i<N;i++) $display("%0d: %0d",i,mem0[i]);

        @(posedge clk); enable = 1;
        @(posedge clk); enable = 0;

        timeout = 1000;
        while (!done && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end

        //INTT
        #50;
    
        @(posedge clk); enable = 1; mode = 1;
        @(posedge clk); enable = 0; mode = 0;

        timeout = 1000;
        while (!done && timeout > 0) begin
            @(posedge clk);
            timeout--;
        end
        
        $display("\n--- MEM0 ---");
        for (int i=0;i<N;i++) $display("%0d: %0d",i,mem0[i]);
        $display("\n--- MEM1 ---");
        for (int i=0;i<N;i++) $display("%0d: %0d",i,mem1[i]);

        $finish;
    end
endmodule
