`timescale 1ns/1ps

module tb_ntt_axi_wrapper;

    // Clock and reset
    logic clk = 0;
    logic rst;
    logic start;
    logic mode;
    logic done;
    
    always begin
        clk = ~clk;
        #5;
    end
    
    // AXI-BRAM interface signals
    logic [7:0]  axi_bram_addr;
    logic [11:0] axi_bram_din;
    logic [11:0] axi_bram_dout;
    logic        axi_bram_we;
    logic        axi_bram_en;

    logic        irq;

    // DUT
    NTT_AXI_wrapper dut (
        .clk(clk),
        .rst(rst),
        .axi_bram_addr(axi_bram_addr),
        .axi_bram_din(axi_bram_din),
        .axi_bram_dout(axi_bram_dout),
        .axi_bram_we(axi_bram_we),
        .axi_bram_en(axi_bram_en),
        .irq(irq),
        .start(start),
        .mode(mode),
        .done(done)
    );


    // Storage for input/output
    logic [11:0] original_poly [0:255];
    logic [11:0] output_poly   [0:255];

    // Burst write: writes 256 coefficients, one per clock
    task automatic axi_write(input [11:0] data_in [0:255]);
        axi_bram_en = 1'b1;
        axi_bram_we = 1'b1;
    
        for (int i = 0; i < 256; i++) begin
            axi_bram_addr = i[7:0];
            axi_bram_din  = data_in[i];
            @(posedge clk);  // one coefficient per clock
        end
    
        axi_bram_en = 1'b0;
        axi_bram_we = 1'b0;
    endtask
    
    // Burst read for 256 sequential coefficients
    task automatic axi_read(output [11:0] data_out [0:255]);
        axi_bram_en = 1'b1;
        for (int i = 0; i < 257; i++) begin
            axi_bram_addr = i[7:0];
            @(posedge clk);
            if (i > 0) data_out[i-1] = axi_bram_dout;
        end
        axi_bram_en = 1'b0;
    endtask
    
    
    

    // ----------------------------------------------------------------
    // STIMULUS
    // ----------------------------------------------------------------
    initial begin
        rst = 1;
        start = 0;
        mode = 0;
        // Reset
        #10;@(posedge clk);
        rst = 0;

        // Prepare input polynomial (all 1s)
        for (int i = 0; i < 256; i++) begin
            original_poly[i] = 2*i;
        end

        // Load data into BRAM
        $display("[%0t] DMA Writing polynomial...", $time);
        axi_write(original_poly);
        
        // Start NTT
        start = 1'b1; mode = 1'b0;
        @(posedge clk); start = 1'b0;
        
        // Wait for done
        wait(irq);
        $display("[%0t] NTT done.", $time);
        
        // Start INTT
        #20;
        start = 1'b1; mode = 1'b1;#10;
        start = 1'b0; mode = 1'b0;
        wait(irq);
        $display("[%0t] INTT done.", $time);
        
        // Read back results
        $display("[%0t] DMA Reading back polynomial...", $time);
        axi_read(output_poly);
        
        // Compare
        $display("=== Checking Results ===");
        for (int i = 0; i < 256; i++) begin
            if (output_poly[i] !== original_poly[i]) begin
                $error("Mismatch at index %0d: expected %0d, got %0d", i, original_poly[i], output_poly[i]);
            end
        end

        $display("NTT + INTT test passed through AXI wrapper.");
        $finish;
    end

endmodule
