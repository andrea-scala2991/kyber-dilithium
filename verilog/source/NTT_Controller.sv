`timescale 1ns / 1ps

module NTT_Controller #(
    parameter int N = 1 << 8,
    parameter int ADDR_WIDTH  = $clog2(N),
    parameter int DATA_WIDTH  = 12,
    parameter int LATENCY     = 3
)(
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic mode,  // 0 = NTT, 1 = INTT
    output logic done,

    // BRAM BANK 0
    output logic [ADDR_WIDTH-1:0] bram0_addr_a,
    output logic [ADDR_WIDTH-1:0] bram0_addr_b,
    output logic                  bram0_we_a,
    output logic                  bram0_we_b,
    input  logic [DATA_WIDTH-1:0] bram0_dout_a,
    input  logic [DATA_WIDTH-1:0] bram0_dout_b,
    output logic [DATA_WIDTH-1:0] bram0_din_a,
    output logic [DATA_WIDTH-1:0] bram0_din_b,

    // BRAM BANK 1
    output logic [ADDR_WIDTH-1:0] bram1_addr_a,
    output logic [ADDR_WIDTH-1:0] bram1_addr_b,
    output logic                  bram1_we_a,
    output logic                  bram1_we_b,
    input  logic [DATA_WIDTH-1:0] bram1_dout_a,
    input  logic [DATA_WIDTH-1:0] bram1_dout_b,
    output logic [DATA_WIDTH-1:0] bram1_din_a,
    output logic [DATA_WIDTH-1:0] bram1_din_b,

    // Twiddle ROM
    output logic [ADDR_WIDTH:0]   rom_addr,
    input  logic [DATA_WIDTH-1:0] rom_dout,

    // Butterfly interface
    output logic [DATA_WIDTH-1:0] butterfly_in1,
    output logic [DATA_WIDTH-1:0] butterfly_in2,
    output logic [DATA_WIDTH-1:0] butterfly_twiddle,
    output logic                  butterfly_inverse,
    output logic                  valid_in,
    input  logic                  valid_out,
    input  logic [DATA_WIDTH-1:0] butterfly_u,
    input  logic [DATA_WIDTH-1:0] butterfly_v
);

    // Derived params
    localparam int LOGN      = $clog2(N);
    localparam int MAX_STAGE = LOGN - 1;

    // FSM
    typedef enum logic [1:0] { IDLE, PIPELINE, FLUSH, DONE } state_t;
    state_t state, next_state;

    // Loop counters
    logic [LOGN-1:0] stage;
    logic [LOGN-1:0] j;
    logic [LOGN-1:0] start;

    // Ping-pong bank select: 0 => read bank0, write bank1; 1 => read bank1, write bank0
    logic src_bank;

    // address math
    logic [LOGN-1:0] len;
    logic [LOGN-1:0] step;
    assign len  = N >> (stage + 1);
    assign step = 1 << stage;

    logic [ADDR_WIDTH-1:0] addr_a_reg, addr_b_reg;
    always_comb begin
        addr_a_reg = start + j;
        addr_b_reg = start + j + len;
    end

    // ROM address selection
    always_comb begin
        rom_addr = (mode == 1'b0) ? (j << stage) : (N - 1) + (j << stage);
    end

    logic stage_pending;

    // -------------------- per-bank write-address FIFOs --------------------
    // fifo0_* used when reading from bank0 (write into bank1)
    // fifo1_* used when reading from bank1 (write into bank0)
    logic [ADDR_WIDTH-1:0] fifo0_a [0:LATENCY];
    logic [ADDR_WIDTH-1:0] fifo0_b [0:LATENCY];
    logic [ADDR_WIDTH-1:0] fifo1_a [0:LATENCY];
    logic [ADDR_WIDTH-1:0] fifo1_b [0:LATENCY];

    integer ii;

    // FIFO for src_bank = 0
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (ii = 0; ii <= LATENCY; ii++) begin
                fifo0_a[ii] <= '0;
                fifo0_b[ii] <= '0;
            end
        end
        else if ((state == PIPELINE || state == FLUSH) /*&& (!stage_pending)*/ && (src_bank == 1'b0)) begin
            for (ii = LATENCY; ii > 0; ii--) begin
                fifo0_a[ii] <= fifo0_a[ii-1];
                fifo0_b[ii] <= fifo0_b[ii-1];
            end
            fifo0_a[0] <= addr_a_reg;
            fifo0_b[0] <= addr_b_reg;
        end
    end

    // FIFO for src_bank = 1
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (ii = 0; ii <= LATENCY; ii++) begin
                fifo1_a[ii] <= '0;
                fifo1_b[ii] <= '0;
            end
        end else if ((state == PIPELINE || state == FLUSH) /*&& (!stage_pending)*/ && (src_bank == 1'b1)) begin
            for (ii = LATENCY; ii > 0; ii--) begin
                fifo1_a[ii] <= fifo1_a[ii-1];
                fifo1_b[ii] <= fifo1_b[ii-1];
            end
            fifo1_a[0] <= addr_a_reg;
            fifo1_b[0] <= addr_b_reg;
        end
    end

    // -------------------- issued / completed counters --------------------
    logic [31:0] issued_count;
    logic [31:0] completed_count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            issued_count    <= '0;
            completed_count <= '0;
        end else begin
            if ((state == PIPELINE) && (!stage_pending)) issued_count <= issued_count + 1;
            if (valid_out)                               completed_count <= completed_count + 1;
        end
    end

    wire butterflies_in_flight = (completed_count < issued_count);

    // -------------------- FSM seq / next --------------------
    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: if (enable) next_state = PIPELINE;
            PIPELINE: begin
                if ((stage == MAX_STAGE) && (start == (N - 2*len)) && (j == len - 1))
                    next_state = FLUSH;
            end
            FLUSH: if (!valid_out && !butterflies_in_flight) next_state = DONE;
            DONE:  next_state = IDLE;
        endcase
    end

    // -------------------- stage progression & stage_pending --------------------


    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            stage <= '0;
            j     <= '0;
            start <= '0;
            stage_pending <= 1'b0;
        end else begin
            if (state == PIPELINE) begin
                if (!stage_pending) begin
                    if (j == len - 1) begin
                        j <= '0;
                        if (start == (N - 2*len)) begin
                            stage_pending <= 1'b1;
                        end else begin
                            start <= start + (2*len);
                        end
                    end else begin
                        j <= j + 1;
                    end
                end else begin
                    j <= j + 1;
                end                
            end
        end
    end

    // -------------------- bank-swap delay counter --------------------
    localparam int BANKCNT_W = (LATENCY <= 1) ? 1 : $clog2(LATENCY+1);
    logic [BANKCNT_W-1:0] bank_swap_cnt;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            bank_swap_cnt <= '0;
            src_bank <= 1'b0;
        end else begin
            if (stage_pending && (bank_swap_cnt == '0)) begin
                bank_swap_cnt <= LATENCY[$clog2(LATENCY+1)-1:0];
            end else if (bank_swap_cnt != '0) begin
                if (bank_swap_cnt == 1) begin
                    src_bank <= ~src_bank;
                    stage <= stage + 1;
                    start <= '0;
                    j     <= '0;
                    stage_pending <= 1'b0;
                    bank_swap_cnt <= '0;
                end else begin
                    bank_swap_cnt <= bank_swap_cnt - 1;
                end
            end
        end
    end

    // -------------------- butterfly I/O routing --------------------
    assign butterfly_inverse = mode;
    assign butterfly_twiddle = rom_dout;

    always_comb begin
        if (src_bank == 1'b0) begin
            butterfly_in1 = bram0_dout_a;
            butterfly_in2 = bram0_dout_b;
        end else begin
            butterfly_in1 = bram1_dout_a;
            butterfly_in2 = bram1_dout_b;
        end
    end

    // -------------------- BRAM port address & write logic --------------------
    always_comb begin
        // defaults
        bram0_addr_a = '0; bram0_addr_b = '0;
        bram1_addr_a = '0; bram1_addr_b = '0;
        bram0_we_a   = 1'b0; bram0_we_b   = 1'b0;
        bram1_we_a   = 1'b0; bram1_we_b   = 1'b0;
        bram0_din_a  = '0;  bram0_din_b  = '0;
        bram1_din_a  = '0;  bram1_din_b  = '0;

        if (src_bank == 1'b0) begin
            // read from bank0
            bram0_addr_a = addr_a_reg;
            bram0_addr_b = addr_b_reg;
            // write into bank1 using fifo0 tail
            bram1_addr_a = fifo0_a[LATENCY];
            bram1_addr_b = fifo0_b[LATENCY];
            bram1_din_a  = butterfly_u;
            bram1_din_b  = butterfly_v;
            bram1_we_a   = valid_out && butterflies_in_flight;
            bram1_we_b   = valid_out && butterflies_in_flight;
        end else begin
            // read from bank1
            bram1_addr_a = addr_a_reg;
            bram1_addr_b = addr_b_reg;
            // write into bank0 using fifo1 tail
            bram0_addr_a = fifo1_a[LATENCY];
            bram0_addr_b = fifo1_b[LATENCY];
            bram0_din_a  = butterfly_u;
            bram0_din_b  = butterfly_v;
            bram0_we_a   = valid_out && butterflies_in_flight;
            bram0_we_b   = valid_out && butterflies_in_flight;
        end
    end

    // valid_in asserted during PIPELINE and not stage_pending
    always_ff @(posedge clk or posedge rst) begin
        if (rst) valid_in <= 1'b0;
        else if ((state == PIPELINE) && (!stage_pending)) valid_in <= 1'b1;
        else valid_in <= 1'b0;
    end

    assign done = (state == DONE);

endmodule
