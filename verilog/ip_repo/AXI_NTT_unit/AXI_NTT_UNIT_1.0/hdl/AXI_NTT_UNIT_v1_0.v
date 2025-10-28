`timescale 1 ns / 1 ps

// =============================================================================
// AXI_NTT_UNIT_v1_0: Top-level wrapper for the NTT core with dual AXI Slave
// S00_AXI: AXI-Lite for Control/Status (connected to PS)
// S01_AXI: AXI-Full for Data Transfer (connected to AXI CDMA/Interconnect)
// =============================================================================

module AXI_NTT_UNIT_v1_0 #
(
    // Parameter definitions (kept as original)
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 4,

    parameter integer C_S01_AXI_ID_WIDTH = 1,
    parameter integer C_S01_AXI_DATA_WIDTH = 32,
    parameter integer C_S01_AXI_ADDR_WIDTH = 10, // 1024 bytes = 2^10
    parameter integer C_S01_AXI_AWUSER_WIDTH = 0,
    parameter integer C_S01_AXI_ARUSER_WIDTH = 0,
    parameter integer C_S01_AXI_WUSER_WIDTH = 0,
    parameter integer C_S01_AXI_RUSER_WIDTH = 0,
    parameter integer C_S01_AXI_BUSER_WIDTH = 0
)
(
    // AXI Lite Clock and Reset (Used as main clock for Core)
    input wire s00_axi_aclk,
    input wire s00_axi_aresetn,

    // Ports of Axi Slave Bus Interface S00_AXI (Control)
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input wire [2 : 0] s00_axi_awprot,
    input wire s00_axi_awvalid,
    output wire s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire s00_axi_wvalid,
    output wire s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire s00_axi_bvalid,
    input wire s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input wire [2 : 0] s00_axi_arprot,
    input wire s00_axi_arvalid,
    output wire s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire s00_axi_rvalid,
    input wire s00_axi_rready,

    // Ports of Axi Slave Bus Interface S01_AXI (Data)
    // S01_AXI uses the same clock/reset as S00_AXI for simplicity
    input wire s01_axi_aclk,
    input wire s01_axi_aresetn,
    input wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_awid,
    input wire [C_S01_AXI_ADDR_WIDTH-1 : 0] s01_axi_awaddr,
    input wire [7 : 0] s01_axi_awlen,
    input wire [2 : 0] s01_axi_awsize,
    input wire [1 : 0] s01_axi_awburst,
    input wire s01_axi_awlock,
    input wire [3 : 0] s01_axi_awcache,
    input wire [2 : 0] s01_axi_awprot,
    input wire [3 : 0] s01_axi_awqos,
    input wire [3 : 0] s01_axi_awregion,
    input wire [C_S01_AXI_AWUSER_WIDTH-1 : 0] s01_axi_awuser,
    input wire s01_axi_awvalid,
    output wire s01_axi_awready,
    input wire [C_S01_AXI_DATA_WIDTH-1 : 0] s01_axi_wdata,
    input wire [(C_S01_AXI_DATA_WIDTH/8)-1 : 0] s01_axi_wstrb,
    input wire s01_axi_wlast,
    input wire [C_S01_AXI_WUSER_WIDTH-1 : 0] s01_axi_wuser,
    input wire s01_axi_wvalid,
    output wire s01_axi_wready,
    output wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_bid,
    output wire [1 : 0] s01_axi_bresp,
    output wire [C_S01_AXI_BUSER_WIDTH-1 : 0] s01_axi_buser,
    output wire s01_axi_bvalid,
    input wire s01_axi_bready,
    input wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_arid,
    input wire [C_S01_AXI_ADDR_WIDTH-1 : 0] s01_axi_araddr,
    input wire [7 : 0] s01_axi_arlen,
    input wire [2 : 0] s01_axi_arsize,
    input wire [1 : 0] s01_axi_arburst,
    input wire s01_axi_arlock,
    input wire [3 : 0] s01_axi_arcache,
    input wire [2 : 0] s01_axi_arprot,
    input wire [3 : 0] s01_axi_arqos,
    input wire [3 : 0] s01_axi_arregion,
    input wire [C_S01_AXI_ARUSER_WIDTH-1 : 0] s01_axi_aruser,
    input wire s01_axi_arvalid,
    output wire s01_axi_arready,
    output wire [C_S01_AXI_ID_WIDTH-1 : 0] s01_axi_rid,
    output wire [C_S01_AXI_DATA_WIDTH-1 : 0] s01_axi_rdata,
    output wire [1 : 0] s01_axi_rresp,
    output wire s01_axi_rlast,
    output wire [C_S01_AXI_RUSER_WIDTH-1 : 0] s01_axi_ruser,
    output wire s01_axi_rvalid,
    input wire s01_axi_rready,
    
    output wire irq
);

    // --- Intermediate Signals for AXI-Lite (S00_AXI) Control/Status ---
    // Signals driven by the core's control logic
    wire core_start_i;
    wire core_mode_i;
    wire core_done_o;
    wire core_irq_o;
    
    // Signals provided by S00_AXI_inst for the user logic to connect
    // Outputs to the NTT Core (Control Signals)
    wire ntt_start_o;   // Bit 0 of slv_reg0: Start the operation (typically edge-triggered in core)
    wire ntt_mode_o;    // Bit 1 of slv_reg0: 0=NTT, 1=iNTT

    // Inputs from the NTT Core (Status Signals)
    wire ntt_busy_i;      // NTT operation is running (for slv_reg1[1])
    wire ntt_error_i;     // Error status (for slv_reg1[2])

    // Map control signals from the AXI-Lite registers (slv_reg0_o driven by AXI module)
    // Assumption: slv_reg0[0] is START, slv_reg0[1] is MODE
    assign core_start_i = ntt_start_o;
    assign core_mode_i  = ntt_mode_o;
    
    // Map status signals back to the AXI-Lite registers (slv_reg1_i is input to AXI module)
    assign irq = core_done_o;


    // --- Intermediate Signals for AXI-Full (S01_AXI) BRAM Access ---
    // CORRECTED: These are now declared as 'wire' as they are simply connecting two modules.
    // Signals driven by S01_AXI (outputs)
    wire [C_S01_AXI_ADDR_WIDTH-1:0] data_bram_addr_o; // Address from AXI handler to Core/BRAM
    wire [11:0] data_bram_din_o; // Data to write from AXI handler to Core/BRAM
    wire data_bram_we_o;         // Write Enable from AXI handler to Core/BRAM
    wire data_bram_en_o;         // Enable from AXI handler to Core/BRAM

    // Signal driven by NTT_CORE/BRAM (input to S01_AXI)
    wire [11:0] data_bram_dout_i; // Read data from Core/BRAM back to AXI handler


// Instantiation of Axi Slave Bus Interface S00_AXI (Control)
AXI_NTT_UNIT_v1_0_S00_AXI # ( 
    .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
) AXI_NTT_UNIT_v1_0_S00_AXI_inst (
    .S_AXI_ACLK(s00_axi_aclk),
    .S_AXI_ARESETN(s00_axi_aresetn),
    .S_AXI_AWADDR(s00_axi_awaddr),
    .S_AXI_AWPROT(s00_axi_awprot),
    .S_AXI_AWVALID(s00_axi_awvalid),
    .S_AXI_AWREADY(s00_axi_awready),
    .S_AXI_WDATA(s00_axi_wdata),
    .S_AXI_WSTRB(s00_axi_wstrb),
    .S_AXI_WVALID(s00_axi_wvalid),
    .S_AXI_WREADY(s00_axi_wready),
    .S_AXI_BRESP(s00_axi_bresp),
    .S_AXI_BVALID(s00_axi_bvalid),
    .S_AXI_BREADY(s00_axi_bready),
    .S_AXI_ARADDR(s00_axi_araddr),
    .S_AXI_ARPROT(s00_axi_arprot),
    .S_AXI_ARVALID(s00_axi_arvalid),
    .S_AXI_ARREADY(s00_axi_arready),
    .S_AXI_RDATA(s00_axi_rdata),
    .S_AXI_RRESP(s00_axi_rresp),
    .S_AXI_RVALID(s00_axi_rvalid),
    .S_AXI_RREADY(s00_axi_rready),
    
    // User logic connections (Control/Status)
    .ntt_start_o(ntt_start_o),
    .ntt_mode_o(ntt_mode_o),
    .ntt_busy_i(ntt_busy_i),
    .ntt_error_i(ntt_error_i)
);


// Instantiation of Axi Bus Interface S01_AXI (Data)
AXI_NTT_UNIT_v1_0_S01_AXI # ( 
    .C_S_AXI_ID_WIDTH(C_S01_AXI_ID_WIDTH),
    .C_S_AXI_DATA_WIDTH(C_S01_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_S01_AXI_ADDR_WIDTH),
    .C_S_AXI_AWUSER_WIDTH(C_S01_AXI_AWUSER_WIDTH),
    .C_S_AXI_ARUSER_WIDTH(C_S01_AXI_ARUSER_WIDTH),
    .C_S_AXI_WUSER_WIDTH(C_S01_AXI_WUSER_WIDTH),
    .C_S_AXI_RUSER_WIDTH(C_S01_AXI_RUSER_WIDTH),
    .C_S_AXI_BUSER_WIDTH(C_S01_AXI_BUSER_WIDTH)
) AXI_NTT_UNIT_v1_0_S01_AXI_inst (
    .S_AXI_ACLK(s01_axi_aclk),
    .S_AXI_ARESETN(s01_axi_aresetn),
    .S_AXI_AWID(s01_axi_awid),
    .S_AXI_AWADDR(s01_axi_awaddr),
    .S_AXI_AWLEN(s01_axi_awlen),
    .S_AXI_AWSIZE(s01_axi_awsize),
    .S_AXI_AWBURST(s01_axi_awburst),
    .S_AXI_AWLOCK(s01_axi_awlock),
    .S_AXI_AWCACHE(s01_axi_arcache),
    .S_AXI_AWPROT(s01_axi_awprot),
    .S_AXI_AWQOS(s01_axi_awqos),
    .S_AXI_AWREGION(s01_axi_awregion),
    .S_AXI_AWUSER(s01_axi_awuser),
    .S_AXI_AWVALID(s01_axi_awvalid),
    .S_AXI_AWREADY(s01_axi_awready),
    .S_AXI_WDATA(s01_axi_wdata),
    .S_AXI_WSTRB(s01_axi_wstrb),
    .S_AXI_WVALID(s01_axi_wvalid),
    .S_AXI_WREADY(s01_axi_wready),
    .S_AXI_WLAST(s01_axi_wlast),
    .S_AXI_WUSER(s01_axi_wuser),
    .S_AXI_BID(s01_axi_bid),
    .S_AXI_BRESP(s01_axi_bresp),
    .S_AXI_BUSER(s01_axi_buser),
    .S_AXI_BVALID(s01_axi_bvalid),
    .S_AXI_BREADY(s01_axi_bready),
    .S_AXI_ARID(s01_axi_arid),
    .S_AXI_ARADDR(s01_axi_araddr),
    .S_AXI_ARLEN(s01_axi_arlen),
    .S_AXI_ARSIZE(s01_axi_arsize),
    .S_AXI_ARBURST(s01_axi_arburst),
    .S_AXI_ARLOCK(s01_axi_arlock),
    .S_AXI_ARCACHE(s01_axi_arcache),
    .S_AXI_ARPROT(s01_axi_arprot),
    .S_AXI_ARQOS(s01_axi_arqos),
    .S_AXI_ARREGION(s01_axi_arregion),
    .S_AXI_ARUSER(s01_axi_aruser),
    .S_AXI_ARVALID(s01_axi_arvalid),
    .S_AXI_ARREADY(s01_axi_arready),
    .S_AXI_RID(s01_axi_rid),
    .S_AXI_RDATA(s01_axi_rdata),
    .S_AXI_RRESP(s01_axi_rresp),
    .S_AXI_RLAST(s01_axi_rlast),
    .S_AXI_RUSER(s01_axi_ruser),
    .S_AXI_RVALID(s01_axi_rvalid),
    .S_AXI_RREADY(s01_axi_rready),
    
    // User logic connections (BRAM-like interface)
    .data_bram_addr_o(data_bram_addr_o),
    .data_bram_din_o(data_bram_din_o),
    .data_bram_dout_i(data_bram_dout_i), // S01_AXI reads data from this signal
    .data_bram_we_o(data_bram_we_o),
    .data_bram_en_o(data_bram_en_o)
);

// =====================================================================
// USER LOGIC: Instantiation of the NTT Core
// The Core must provide the BRAM functionality, receiving commands from
// the S01_AXI handler and signaling done/IRQ.
// =====================================================================
wire  [7:0] ntt_core_axi_bram_addr;
assign ntt_core_axi_bram_addr = (data_bram_addr_o >> 2);


// Note: Renamed to NTT_CORE for clarity in the top-level AXI wrapper.
NTT_AXI_wrapper NTT_CORE (
    // Clock and Reset
    .clk(s00_axi_aclk),
    .rst(~s00_axi_aresetn), // Use inverted reset if core is active-high
    
    // Control Signals (from S00_AXI Lite)
    .start(core_start_i),
    .mode(core_mode_i),
    .done(core_done_o),
    .irq(core_irq_o),
    
    // Data Signals (from S01_AXI Full, connected to BRAM access)
    // The core must now drive the read data (dout) and use the others as inputs.
    .axi_bram_addr(ntt_core_axi_bram_addr), // Input to Core
    .axi_bram_din(data_bram_din_o),   // Input to Core
    .axi_bram_dout(data_bram_dout_i), // Output from Core (BRAM read data)
    .axi_bram_we(data_bram_we_o),     // Input to Core
    .axi_bram_en(data_bram_en_o)      // Input to Core
);

endmodule
