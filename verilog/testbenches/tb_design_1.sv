`timescale 1ns/1ps

module tb_design_1;

    // ------------------------------------------------------------------------
    // Clock / reset / control
    // ------------------------------------------------------------------------
    logic clk = 0;
    logic rst = 1;
    logic enable = 0;
    logic mode = 0;  // 0 = NTT, 1 = INTT
    logic done;

    // DUT instance (block design wrapper)
    design_1_wrapper dut (
        .clk    (clk),
        .rst  (rst),
        .enable (enable),
        .mode   (mode),
        .done   (done)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Test stimulus
    // ------------------------------------------------------------------------
    localparam int N = 256;
    localparam int DATA_WIDTH = 12;

    int errcnt = 0;

    initial begin : stimulus
        // ------------------- RESET -------------------
        #10;
        rst = 0;
        #10;


        // ------------------- RUN NTT -------------------
        $display("[%0t] Starting NTT...", $time);
        mode = '0;    // NTT
        enable = '1;
        @(posedge clk);
        enable = '0;

        wait(done == '1);
        $display("[%0t] NTT done.", $time);


        // ------------------- RUN INTT -------------------
        $display("[%0t] Starting INTT...", $time);
        #20;
        mode = '1;    // INTT
        enable = '1;
        #10;
        @(posedge clk);
        enable = '0;
        mode = '0;

        wait(done == '1);#50;
        $display("[%0t] INTT done.", $time);

        
        // CHECK RESULTS AFTER INTT
        $display("[%0t] Checking BRAM contents after INTT...", $time);
        for (int i = 0; i < N; i++) begin
            logic [DATA_WIDTH-1:0] value;
            // hierarchical reference to the BRAM's internal memory
            value = tb_design_1.dut.design_1_i.coeff_BRAM0.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[i];
            if (value !== 12'd1) begin
                $error("Mismatch at index %0d: expected 1, got %0d", i, value);
                errcnt++;
            end
        end

        $display("[%0t] BRAM content check completed.", $time);


        $finish;
    end

endmodule
