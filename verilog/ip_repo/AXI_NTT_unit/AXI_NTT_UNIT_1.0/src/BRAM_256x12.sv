`timescale 1ns / 1ps

module BRAM_256x12 (
    input  logic clk,

    // Port A
    input  logic [7:0] addr_a,
    input  logic [11:0] din_a,
    output logic [11:0] dout_a,
    input  logic we_a,
    input  logic en_a,

    // Port B
    input  logic [7:0] addr_b,
    input  logic [11:0] din_b,
    output logic [11:0] dout_b,
    input  logic we_b,
    input  logic en_b
);

    // ------------------------------------------------------------------------
    // Memory declaration - Vivado will infer block RAM from this
    // ------------------------------------------------------------------------
    logic [11:0] mem [0:255];

    // Port A (Read/Write)
    always_ff @(posedge clk) begin
        if (en_a) begin
            if (we_a)
                mem[addr_a] <= din_a;
            dout_a <= mem[addr_a];
        end
    end

    // Port B (Read/Write)
    always_ff @(posedge clk) begin
        if (en_b) begin
            if (we_b)
                mem[addr_b] <= din_b;
            dout_b <= mem[addr_b];
        end
    end

endmodule
