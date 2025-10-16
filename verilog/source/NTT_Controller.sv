`timescale 1ns / 1ps

module NTT_Controller #(
    parameter int N = 256,
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
    output logic [ADDR_WIDTH-1:0]   rom_addr,
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
    typedef enum logic [2:0] { IDLE, INTT_WAIT, PIPELINE, FLUSH, DONE } state_t;
    state_t state, next_state;

    // -------------------- Loop Counters (Sequential Registers) --------------------
    logic [LOGN-1:0] stage;
    logic [LOGN-1:0] j;
    logic [LOGN-1:0] start;
    
    // Next-state combinational signals (Driven only by the always_comb block)
    logic [LOGN-1:0] stage_next;
    logic [LOGN-1:0] j_next;
    logic [LOGN-1:0] start_next;
    // ---------------------------------------------------------------------------

    // Ping-pong bank select: 0 => read bank0, write bank1; 1 => read bank1, write bank0
    logic src_bank;

    logic mode_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst || state == DONE)
            mode_reg <= '0;
        else           
            mode_reg <= enable ? mode : mode_reg;
    end

    // address math
    logic [LOGN-1:0] len;
    
    always_comb begin
        if(state == PIPELINE) 
            len  = mode_reg ? (1'b1 << (stage)) : (N >> (stage + 1'b1));
        else
            len = '0;
    end

    logic [ADDR_WIDTH-1:0] addr_a_reg, addr_b_reg;
    always_comb begin
        addr_a_reg = start + j;
        addr_b_reg = start + j + len;
    end

    // ROM address selection
    always_comb begin
        if (mode_reg == 1'b0) begin
            // NTT twiddle address
            rom_addr = j << stage;
        end else begin
            // INTT twiddle address
            rom_addr = (N >> 1) + (j << (LOGN - stage - 1));
        end
    end
    

    logic stage_pending;
    logic stage_pending_next;

    // -------------------- per-bank write-address FIFOs (no change) --------------------
    // fifo0_* used when reading from bank0 (write into bank1)
    // fifo1_* used when reading from bank1 (write into bank0)
    logic [ADDR_WIDTH-1:0] fifo0_a [0:LATENCY];
    logic [ADDR_WIDTH-1:0] fifo0_b [0:LATENCY];
    logic [ADDR_WIDTH-1:0] fifo1_a [0:LATENCY];
    logic [ADDR_WIDTH-1:0] fifo1_b [0:LATENCY];


    // FIFO for src_bank = 0
    always_ff @(posedge clk, posedge rst) begin
        integer ii;
        if (rst || state == DONE) begin
            for (ii = 0; ii <= LATENCY; ii++) begin
                fifo0_a[ii] <= '0;
                fifo0_b[ii] <= '0;
            end
        end
        else if ((state == PIPELINE || state == FLUSH) && (src_bank == 1'b0)) begin
            for (ii = LATENCY; ii > 0; ii--) begin
                fifo0_a[ii] <= fifo0_a[ii-1];
                fifo0_b[ii] <= fifo0_b[ii-1];
            end
            fifo0_a[0] <= addr_a_reg;
            fifo0_b[0] <= addr_b_reg;
        end else begin           
            // Explicitly hold value to prevent synthesis confusion when bank 1 is inactive
            for (ii = 0; ii <= LATENCY; ii++) begin
                fifo0_a[ii] <= fifo0_a[ii];
                fifo0_b[ii] <= fifo0_b[ii];
            end
        end
    end

    // FIFO for src_bank = 1
    always_ff @(posedge clk, posedge rst) begin
        integer ii;
        if (rst || state == DONE) begin
            for (ii = 0; ii <= LATENCY; ii++) begin
                fifo1_a[ii] <= '0;
                fifo1_b[ii] <= '0;
            end
        end
        else if ((state == PIPELINE || state == FLUSH) && (src_bank == 1'b1)) begin
            for (ii = LATENCY; ii > 0; ii--) begin
                fifo1_a[ii] <= fifo1_a[ii-1];
                fifo1_b[ii] <= fifo1_b[ii-1];
            end
            fifo1_a[0] <= addr_a_reg;
            fifo1_b[0] <= addr_b_reg;
        end else begin           
            // Explicitly hold value to prevent synthesis confusion when bank 0 is inactive
            for (ii = 0; ii <= LATENCY; ii++) begin
                fifo1_a[ii] <= fifo1_a[ii];
                fifo1_b[ii] <= fifo1_b[ii];
            end
        end
    end

    // -------------------- issued / completed counters (no change) --------------------
    logic [11:0] issued_count;
    logic [11:0] completed_count;

    always_ff @(posedge clk, posedge rst) begin
        if (rst || state == DONE) begin
            issued_count    <= '0;
            completed_count <= '0;
        end else begin
            // Note: stage_pending is used here, calculated below.
            if ((state == PIPELINE) && (!stage_pending))
                issued_count <= issued_count + 1'b1;
            if (valid_out)
                completed_count <= completed_count + 1'b1;
        end
    end

    wire butterflies_in_flight = (completed_count < issued_count);


    //DELAY COUNTER FOR INTT INITIALISATION (no change)
    logic [1:0] intt_delay_cnt;
    
    always_ff @(posedge clk, posedge rst) begin
        if (rst || state == DONE) begin
            intt_delay_cnt <= '0;
        end else if (state == INTT_WAIT) begin
                if (intt_delay_cnt < 2'd1)
                    intt_delay_cnt <= intt_delay_cnt + 1'b1;
        end else begin
            intt_delay_cnt <= '0;
        end
    end
    
    // -------------------- FSM seq / next (no change) --------------------
    always_ff @(posedge clk, posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (enable) begin
                    if (mode == 1'b1)
                        next_state = INTT_WAIT;   // new state for pipeline warm-up
                    else
                        next_state = PIPELINE;
                end
            end
    
            INTT_WAIT: begin
                    if (intt_delay_cnt == 1'b1)
                        next_state = PIPELINE;
                    else
                        next_state = INTT_WAIT;
            end
    
            PIPELINE: begin
                // Logic updated to use current values of stage/start/j
                if ((stage == MAX_STAGE) && (start == (N - 2*len)) && (j == len - 1'b1))
                    next_state = FLUSH;
            end
    
            FLUSH: if (!valid_out && !butterflies_in_flight) next_state = DONE;
           
            DONE:  next_state = IDLE;
        endcase
    end

    localparam int BANKCNT_W = (LATENCY <= 1) ? 1 : $clog2(LATENCY+1);
    logic [BANKCNT_W-1:0] bank_swap_cnt;
        

    // -------------------- COUNTER NEXT-STATE CALCULATION (COMBINATIONAL) --------------------
    // The inner-defaults from the last attempt have been removed, as they caused
    // a conflict with the top-level defaults. We now rely on explicit coverage
    // within the loop logic to avoid falling back to the top-level default implicitly.
    always_comb begin
        // Default: Hold current value (active in all FSM states except when a branch below overrides it)
        stage_next = stage;
        j_next     = j;
        start_next = start;
        stage_pending_next = stage_pending; // Default for stage_pending

        // A. STAGE TRANSITION (Highest Priority Reset)
        if (bank_swap_cnt == 1) begin
            stage_next = stage + 1'b1;
            start_next = '0;
            j_next     = '0;
            stage_pending_next = '0;
        end
        
        // B. MAIN PIPELINE LOOP ADVANCE
        else if (state == PIPELINE && !stage_pending) begin
            
            if (j == len - 1'b1) begin // End of J loop?
                j_next = '0; // J resets
                if (start == (N - 2*len)) begin // End of START loop?
                    // Stage complete, signal pending swap delay
                    stage_pending_next = 1'b1; 
                    start_next = start; // Explicitly hold start
                end else begin
                    // Increment start for the next block
                    start_next = start + (len << 1'b1);
                    // j_next is already set to '0' from the outer 'if' block
                end
            end else begin
                // Normal J increment
                j_next = j + 1'b1;
                // Explicitly hold start
                start_next = start; 
            end
        end
    end

    // -------------------- Stage/Loop Counters SEQUENTIAL UPDATE (Single Driver) --------------------
    always_ff @(posedge clk, posedge rst) begin
        if (rst || state == DONE) begin // Synchronous Reset
            stage <= '0;
            j     <= '0;
            start <= '0;
            stage_pending <= '0;
        end else begin
            // The next state logic is derived from the single always_comb block above.
            stage <= stage_next;
            j     <= j_next;
            start <= start_next;
            
            // Update stage_pending
            stage_pending <= stage_pending_next;
        end
    end

    // -------------------- bank-swap delay counter (Refactored) --------------------
   

    always_ff @(posedge clk, posedge rst) begin
        if (rst || state == DONE) begin
            bank_swap_cnt <= '0;
            src_bank <= 1'b0;
        end else begin
            if (stage_pending && (bank_swap_cnt == '0)) begin
                bank_swap_cnt <= LATENCY[$clog2(LATENCY+1)-1:0];
                src_bank <= src_bank; // explicitly hold
            end else if (bank_swap_cnt != '0) begin
                if (bank_swap_cnt == 1) begin
                    // The register resets for j/start/stage are handled by the main counter block now
                    src_bank <= ~src_bank; // Only bank swap remains here
                    bank_swap_cnt <= '0;
                end else begin
                    bank_swap_cnt <= bank_swap_cnt - 1'b1;
                end
            end
        end
    end

    // -------------------- butterfly I/O routing (no change) --------------------
    assign butterfly_inverse = mode_reg;
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

    // -------------------- BRAM port address & write logic (no change) --------------------
    always_comb begin
        // defaults
        bram0_addr_a = '0; bram0_addr_b = '0;
        bram1_addr_a = '0; bram1_addr_b = '0;
        bram0_we_a   = '0; bram0_we_b = '0;
        bram1_we_a   = '0; bram1_we_b = '0;
        bram0_din_a  = '0; bram0_din_b = '0;
        bram1_din_a  = '0; bram1_din_b = '0;

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

    // valid_in sequential logic (no change)
    logic valid_in_next;
    
    always_comb begin
        if ((state == PIPELINE) && (!stage_pending))
            valid_in_next = 1'b1;
        else 
            valid_in_next = 1'b0;
    end

    always_ff @(posedge clk, posedge rst) begin
        if (rst) valid_in <= 1'b0;
        else valid_in <= valid_in_next;
    end

    assign done = (state == DONE);

endmodule
