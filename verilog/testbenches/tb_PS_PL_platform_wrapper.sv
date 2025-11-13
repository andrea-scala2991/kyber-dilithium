// =============================================================================
// NTT System Verification Testbench (INTERRUPT-DRIVEN CDMA FLOW)
//
// Models the control sequence of a PS (CPU) configuring an AXI CDMA block
// to move data between DDR and the NTT IP's local BRAM space in an interrupt-
// driven fashion, simulating the wait time for hardware IRQ flags.
// =============================================================================
`timescale 1ns / 1ps

module tb_PS_PL_platform_wrapper();

    // --- 1. Clock, Reset, and UUT Signals ---
    reg tb_ACLK;       // PS clock
    reg tb_ARESETn;    // PS reset
    wire temp_clk;
    wire temp_rstn;

    localparam period = 10; // 100MHz (10ns period)
    //localparam C_SYNC_DELAY_CYCLES = 20; // 160 ns synchronization delay

    always begin
        tb_ACLK = 1'b0; #(period/2.0);
        tb_ACLK = 1'b1; #(period/2.0);
    end

    assign temp_clk  = tb_ACLK;
    assign temp_rstn = tb_ARESETn;

    // AXI-Lite transaction variables used by the embedded functions
    reg [31:0] read_data;
    reg [31:0] read_addr;
    reg resp;
    reg [31:0] addr;
    reg [31:0] data;

    // --- 2. System Constants and Register Addresses (From Address Map) ---

    // NTT IP AXI-Lite (Control Interface)
    localparam C_NTT_CTRL_BASE = 32'h43c0_0000;
    localparam C_NTT_CTRL_OFFSET = 32'h00;             // REG_CONTROL (Start/Mode)
    localparam C_NTT_STATUS_OFFSET = 32'h04;        // REG_STATUS (busy/error)
    localparam CTRL_START_MASK = 32'h1;
    localparam CTRL_MODE_MASK = 32'h2;                  // 1 = INTT, 0 = NTT

    // NTT IP AXI-Full (Data Interface - assumes it's mapped 4K after Control)
    localparam C_NTT_DATA_BASE = 32'h7600_0000;  // Target address for CDMA

    // AXI CDMA Register Offsets (Standard Xilinx Map)
    localparam C_CDMA_BASE = 32'h7e20_0000;
    localparam C_CDMA_CR = C_CDMA_BASE + 32'h00;  // Control Register
    localparam C_CDMA_SR = C_CDMA_BASE + 32'h04;  // Status Register
    localparam C_CDMA_SA = C_CDMA_BASE + 32'h18;  // Source Address
    localparam C_CDMA_DA = C_CDMA_BASE + 32'h20;  // Destination Address
    localparam C_CDMA_BTT = C_CDMA_BASE + 32'h28; // Bytes To Transfer

    // CDMA Status Register Masks for polling and IRQ clearing
    localparam CDMA_SR_IOC_IRQ_MASK = 32'h00001000; // IOC Interrupt (Completion)
    localparam CDMA_SR_DMASLAVE_ERR_MASK = 32'h00002000; // Error Mask
    localparam CDMA_SR_ALL_IRQ_MASK = 32'h0000F000; // All IRQ flags (for clearing)
    localparam CDMA_CR_RESET_MASK   = 32'h00000004; // Reset bit (Bit 2)

    //PS IRQ lines
    localparam NTT_IRQ_MASK      = 4'b0000;
    localparam CDMA_IRQ_MASK  = 4'b0001;

    reg[15:0] IRQ_status = '0;
    
    // Data Transfer Parameters
    localparam C_NTT_SIZE = 256;
    localparam C_WORD_SIZE_BYTES = 4; // 32 bit words by AXI standard
    localparam C_TRANSFER_LEN_BYTES = C_NTT_SIZE * C_WORD_SIZE_BYTES; // 1024 Bytes
    localparam C_DDR_BUFFER_ADDR = 32'h0a00_0000; // PS memory address

    
    // UUT Instantiation (Black Box)
    PS_PL_platform_wrapper UUT (
        // ... DDR and FIXED_IO ports from user template ...
        .DDR_addr(),
        .DDR_ba(),
        .DDR_cas_n(),
        .DDR_ck_n(),
        .DDR_ck_p(),
        .DDR_cke(),
        .DDR_cs_n(),
        .DDR_dm(),
        .DDR_dq(),
        .DDR_dqs_n(),
        .DDR_dqs_p(),
        .DDR_odt(),
        .DDR_ras_n(),
        .DDR_reset_n(),
        .DDR_we_n(),
        .FIXED_IO_ddr_vrn(),
        .FIXED_IO_ddr_vrp(),
        .FIXED_IO_mio(),
        .FIXED_IO_ps_clk(temp_clk),
        .FIXED_IO_ps_porb(temp_rstn),
        .FIXED_IO_ps_srstb(temp_rstn)
    );

    task CDMA_reset();
        bit [31:0] status;
        $display("[%0t] PS: Executing CDMA Software Reset.", $time);

        // 1. Assert Reset bit (Bit 2) in CR
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_CR, 4, CDMA_CR_RESET_MASK, resp);

        // Wait for 10 clocks for reset to complete
        repeat (10) @(posedge tb_ACLK);

        // 2. De-assert Reset and re-enable IRQs (Set CR back to its desired operational state)
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_CR, 4, CDMA_SR_IOC_IRQ_MASK, resp);

        // 3. Clear Status Register (clear any remaining flags)
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_SR, 4, CDMA_SR_ALL_IRQ_MASK, resp);

        // 4. Read SR to confirm reset state (Idle/Halted)
        UUT.PS_PL_platform_i.processing_system7_0.inst.read_data(C_CDMA_SR, 4, status, resp);
        $display("[%0t] PS: CDMA Reset complete. New Status Register=0x%h. Ready for transfer.", $time, status);
    endtask

    
    // --- 3. High-Level Task to Model the C Function 'run_NTT' ---
    task NTT_run(input int mode);
        bit [31:0] ctrl_val;
        bit [31:0] status;
        string mode_str = (mode == 1) ? "iNTT" : "NTT";
        
        CDMA_reset();
        
        $display("\n-------------------------------------------------------");
        $display("[%0t] PS: Starting full INTERRUPT-DRIVEN %s sequence (Mode=%0d).", $time, mode_str, mode);
        // =====================================================================
        // PHASE 1: START DMA WRITE (DDR -> IP) & WAIT FOR CDMA IRQ
        // =====================================================================

        // 2a. Set Source Address (SA) to DDR
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_SA, 4, C_DDR_BUFFER_ADDR, resp);
        // 2b. Set Destination Address (DA) to NTT IP BRAM
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_DA, 4, C_NTT_DATA_BASE, resp);

        // 2c. Write Bytes to Transfer (BTT) - This register write STARTS the transfer
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_BTT, 4, C_TRANSFER_LEN_BYTES, resp);
        $display("[%0t] PS: CDMA (DDR->IP) Triggered (SA=0x%h, DA=0x%h) for %0d Bytes.", $time, C_DDR_BUFFER_ADDR, C_NTT_DATA_BASE, C_TRANSFER_LEN_BYTES);

        // 2d. Wait for CDMA IOC Interrupt
        $display("[%0t] PS: CPU enters wait loop for CDMA (DDR->IP) IRQ...", $time);
        UUT.PS_PL_platform_i.processing_system7_0.inst.wait_interrupt(CDMA_IRQ_MASK, IRQ_status);
        
        // 2e. Service IRQ: Read Status, Check for error, Clear flags
        UUT.PS_PL_platform_i.processing_system7_0.inst.read_data(C_CDMA_SR, 4, status, resp);
        if ((status & CDMA_SR_DMASLAVE_ERR_MASK) != 0) begin
            $display("[%0t] PS: CDMA (DDR->IP) Transfer FAILED with error (Status=0x%h). Halting test.", $time, status);
            $stop;
        end
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_SR, 4, CDMA_SR_ALL_IRQ_MASK, resp);
        $display("[%0t] PS: CDMA (DDR->IP) IRQ received and acknowledged. Data is loaded into BRAM.", $time);


        // =====================================================================
        // PHASE 2: START NTT OPERATION & WAIT FOR IP IRQ
        // =====================================================================

        // 3a. Start NTT IP
        ctrl_val = CTRL_START_MASK | (mode ? CTRL_MODE_MASK : 0);
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_NTT_CTRL_BASE + C_NTT_CTRL_OFFSET, 4, ctrl_val, resp);
        $display("[%0t] PS: NTT IP triggered (Ctrl Reg=0x%h).", $time, ctrl_val);
        //clear values
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_NTT_CTRL_BASE + C_NTT_CTRL_OFFSET, 4, '0, resp);

        // 3b. Wait for NTT IP Done Interrupt 
        $display("[%0t] PS: CPU enters wait loop for NTT Done IRQ...", $time);
        UUT.PS_PL_platform_i.processing_system7_0.inst.wait_interrupt(NTT_IRQ_MASK, IRQ_status);
       
        // Clear NTT IP Control Register (Acts as acknowledge)
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_NTT_CTRL_BASE + C_NTT_STATUS_OFFSET, 4, 32'h1, resp);
        $display("[%0t] PS: NTT Done IRQ received and acknowledged. Result is ready in BRAM.", $time);
        
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_NTT_CTRL_BASE + C_NTT_STATUS_OFFSET, 4, 32'h0, resp);
        
        // =====================================================================
        // PHASE 3: START DMA READ (IP -> DDR) & WAIT FOR FINAL IRQ
        // =====================================================================

        // 4a. Set Source Address (SA) to NTT IP BRAM
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_SA, 4, C_NTT_DATA_BASE, resp);
        // 4b. Set Destination Address (DA) to DDR
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_DA, 4, C_DDR_BUFFER_ADDR, resp);

        // 4c. Write Bytes to Transfer (BTT) - This register write STARTS the final transfer
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_BTT, 4, C_TRANSFER_LEN_BYTES, resp);
        $display("[%0t] PS: CDMA (IP->DDR) Triggered (SA=0x%h, DA=0x%h) for %0d Bytes.", $time, C_NTT_DATA_BASE, C_DDR_BUFFER_ADDR, C_TRANSFER_LEN_BYTES);

        // 4d. Wait for CDMA IOC Interrupt (Simulated)
        $display("[%0t] PS: CPU enters wait loop for final CDMA (IP->DDR) IRQ...", $time);
        UUT.PS_PL_platform_i.processing_system7_0.inst.wait_interrupt(CDMA_IRQ_MASK, IRQ_status);
        
        // 4e. Service IRQ: Read Status, Check for error, Clear flags
        UUT.PS_PL_platform_i.processing_system7_0.inst.read_data(C_CDMA_SR, 4, status, resp);
        if ((status & CDMA_SR_DMASLAVE_ERR_MASK) != 0) begin
            $display("!!! [%0t] PS: Final CDMA (IP->DDR) Transfer FAILED with error (Status=0x%h). Halting test.", $time, status);
            $stop;
        end
        UUT.PS_PL_platform_i.processing_system7_0.inst.write_data(C_CDMA_SR, 4, CDMA_SR_ALL_IRQ_MASK, resp);
        $display("[%0t] PS: Final CDMA (IP->DDR) IRQ received and acknowledged. Data is in DDR.", $time);
        
        // ---------------------------------------------------------------------
        // C Code Step 5: Xil_DCacheInvalidateRange (MODELED)
        // ---------------------------------------------------------------------
        $display("[%0t] PS: Modeling Data Cache Invalidate (post-CDMA).", $time);

        $display("[%0t] PS: %s sequence finished.", $time, mode_str);
        $display("-------------------------------------------------------");
    endtask


    // --- 4. Main Test Sequence (Modeling C program's main function) ---
    initial begin
        // Apply reset
        tb_ARESETn = 1'b0; #(20*period);

        // Release reset
        tb_ARESETn = 1'b1; #(10*period);
        $display("-------------------------------------------------------");
        $display("[%0t] SYSTEM RESET RELEASED.", $time);
        $display("-------------------------------------------------------");

        // Reset the PL 
        UUT.PS_PL_platform_i.processing_system7_0.inst.fpga_soft_reset(32'h1);
        UUT.PS_PL_platform_i.processing_system7_0.inst.fpga_soft_reset(32'h0);
        #(100*period);
        $display("[%0t] PS: PL Soft Reset sequence complete.", $time);


        // ---------------------------------------------------------------------
        // C Code Step 1: Initialize Data in DDR & Cache Flush (MODELED)
        // ---------------------------------------------------------------------
        $display("[%0t] PS: Initializing input data in DDR (0x%h). Modeling write_burst and Cache Flush...", $time, C_DDR_BUFFER_ADDR);
        // Initialise DDR with all ones
        UUT.PS_PL_platform_i.processing_system7_0.inst.pre_load_mem_from_file("DDR_init.mem", C_DDR_BUFFER_ADDR,  C_TRANSFER_LEN_BYTES);
                
        // =====================================================================
        // TEST 1: Forward NTT Control Flow
        // =====================================================================
        NTT_run(0); // 0 for NTT

       // UUT.PS_PL_platform_i.processing_system7_0.inst.read_to_file("NTT_RESULT.mem",C_DDR_BUFFER_ADDR, C_TRANSFER_LEN_BYTES,resp);
        // =====================================================================
        // TEST 2: Inverse NTT Control Flow
        // =====================================================================
        NTT_run(1); // 1 for iNTT

        $display("-------------------------------------------------------");
        $display("[%0t] TEST BENCH SEQUENCE FINISHED.", $time);
        $display("-------------------------------------------------------");

        $stop;
    end

endmodule
