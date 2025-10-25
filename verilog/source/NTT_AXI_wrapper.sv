`timescale 1ns / 1ps

module NTT_AXI_wrapper (
    input   logic        clk,
    input   logic        rst,
    input   logic        start,
    input   logic        mode,
    output  logic        done,
    
    // AXI4 (DMA) - simple read/write ports for coefficients
    input  logic [7:0]  axi_bram_addr,
    input  logic [11:0] axi_bram_din,
    output logic [11:0] axi_bram_dout,
    input  logic        axi_bram_we,
    input  logic        axi_bram_en,

    output logic        irq  // interrupt to PS when done
);

    // ------------------------------------------------------------------------
    // BRAM interface signals
    // ------------------------------------------------------------------------
    logic [7:0] ctrl_bram0_addr_a, ctrl_bram0_addr_b;
    logic ctrl_bram0_we_a, ctrl_bram0_we_b;
    logic [11:0] ctrl_bram0_din_a, ctrl_bram0_din_b;
    logic [11:0] ctrl_bram0_dout_a, ctrl_bram0_dout_b;

    logic [7:0] ctrl_bram1_addr_a, ctrl_bram1_addr_b;
    logic ctrl_bram1_we_a, ctrl_bram1_we_b;
    logic [11:0] ctrl_bram1_din_a, ctrl_bram1_din_b;
    logic [11:0] ctrl_bram1_dout_a, ctrl_bram1_dout_b;

    // ------------------------------------------------------------------------
    // BRAM port muxing between DMA and Controller
    //  - Port A: used by AXI DMA for read/write
    //  - Port B: always used by the NTT controller
    // ------------------------------------------------------------------------

    // For simplicity, we'll only give AXI access to BRAM0
    wire [7:0]  bram0_addr_a;
    wire [11:0] bram0_din_a;
    wire        bram0_we_a;
    
    assign bram0_addr_a = axi_bram_en ? axi_bram_addr : ctrl_bram0_addr_a;
    assign bram0_din_a  = axi_bram_en ? axi_bram_din  : ctrl_bram0_din_a;
    assign bram0_we_a  = axi_bram_en ? axi_bram_we   : ctrl_bram0_we_a;
    assign axi_bram_dout = ctrl_bram0_dout_a;

    // ------------------------------------------------------------------------
    // BRAM instantiation (two ping-pong memories)
    // ------------------------------------------------------------------------
    BRAM_256x12 bram0 (
        .clk(clk),
        
        .en_a(1'b1),
        .we_a(bram0_we_a),
        .addr_a(bram0_addr_a),
        .din_a(bram0_din_a),
        .dout_a(ctrl_bram0_dout_a),

        .en_b(1'b1),
        .we_b(ctrl_bram0_we_b),
        .addr_b(ctrl_bram0_addr_b),
        .din_b(ctrl_bram0_din_b),
        .dout_b(ctrl_bram0_dout_b)
    );

    BRAM_256x12 bram1 (
        .clk(clk),
        
        .en_a(1'b1),
        .we_a(ctrl_bram1_we_a),
        .addr_a(ctrl_bram1_addr_a),
        .din_a(ctrl_bram1_din_a),
        .dout_a(ctrl_bram1_dout_a),

        .en_b(1'b1),
        .we_b(ctrl_bram1_we_b),
        .addr_b(ctrl_bram1_addr_b),
        .din_b(ctrl_bram1_din_b),
        .dout_b(ctrl_bram1_dout_b)
    );

    // ------------------------------------------------------------------------
    // Twiddle ROM
    // ------------------------------------------------------------------------
    logic [7:0]  rom_addr;
    logic [11:0] rom_dout;

    twiddle_ROM twiddle_rom (
        .clk(clk),
        .addr(rom_addr),
        .dout(rom_dout)
    );

    // ------------------------------------------------------------------------
    // Butterfly Unit
    // ------------------------------------------------------------------------
    logic [11:0] butterfly_in1, butterfly_in2;
    logic [11:0] butterfly_twiddle;
    logic butterfly_inverse;
    logic valid_in, valid_out;
    logic [11:0] butterfly_u, butterfly_v;

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

    // ------------------------------------------------------------------------
    // NTT Controller
    // ------------------------------------------------------------------------
    NTT_Controller #(
        .N(256),
        .ADDR_WIDTH(8),
        .DATA_WIDTH(12),
        .LATENCY(3)
    ) controller (
        .clk(clk),
        .rst(rst),
        .enable(start),
        .mode(mode),
        .done(done),

        // BRAM 0
        .bram0_addr_a(ctrl_bram0_addr_a),
        .bram0_addr_b(ctrl_bram0_addr_b),
        .bram0_we_a(ctrl_bram0_we_a),
        .bram0_we_b(ctrl_bram0_we_b),
        .bram0_dout_a(ctrl_bram0_dout_a),
        .bram0_dout_b(ctrl_bram0_dout_b),
        .bram0_din_a(ctrl_bram0_din_a),
        .bram0_din_b(ctrl_bram0_din_b),

        // BRAM 1
        .bram1_addr_a(ctrl_bram1_addr_a),
        .bram1_addr_b(ctrl_bram1_addr_b),
        .bram1_we_a(ctrl_bram1_we_a),
        .bram1_we_b(ctrl_bram1_we_b),
        .bram1_dout_a(ctrl_bram1_dout_a),
        .bram1_dout_b(ctrl_bram1_dout_b),
        .bram1_din_a(ctrl_bram1_din_a),
        .bram1_din_b(ctrl_bram1_din_b),

        // ROM
        .rom_addr(rom_addr),
        .rom_dout(rom_dout),

        // Butterfly interface
        .butterfly_in1(butterfly_in1),
        .butterfly_in2(butterfly_in2),
        .butterfly_twiddle(butterfly_twiddle),
        .butterfly_inverse(butterfly_inverse),
        .valid_in(valid_in),
        .valid_out(valid_out),
        .butterfly_u(butterfly_u),
        .butterfly_v(butterfly_v)
    );

    assign irq = done;

endmodule
