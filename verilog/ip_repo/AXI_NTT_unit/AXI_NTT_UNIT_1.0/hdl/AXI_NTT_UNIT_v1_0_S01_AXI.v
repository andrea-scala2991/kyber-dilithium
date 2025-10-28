`timescale 1 ns / 1 ps

    module AXI_NTT_UNIT_v1_0_S01_AXI #
    (
        // Users to add parameters here

        // User parameters ends
        // Do not modify the parameters beyond this line

        // Width of ID for for write address, write data, read address and read data
        parameter integer C_S_AXI_ID_WIDTH    = 1,
        // Width of S_AXI data bus
        parameter integer C_S_AXI_DATA_WIDTH    = 32,
        // Width of S_AXI address bus
        parameter integer C_S_AXI_ADDR_WIDTH    = 10,
        // Width of optional user defined signal in write address channel
        parameter integer C_S_AXI_AWUSER_WIDTH    = 0,
        // Width of optional user defined signal in read address channel
        parameter integer C_S_AXI_ARUSER_WIDTH    = 0,
        // Width of optional user defined signal in write data channel
        parameter integer C_S_AXI_WUSER_WIDTH    = 0,
        // Width of optional user defined signal in read data channel
        parameter integer C_S_AXI_RUSER_WIDTH    = 0,
        // Width of optional user defined signal in write response channel
        parameter integer C_S_AXI_BUSER_WIDTH    = 0
    )
    (
        // Users to add ports here
        // BRAM Interface Ports for Top-Level Connection
        output reg [C_S_AXI_ADDR_WIDTH-1:0] data_bram_addr_o,
        output reg [11:0] data_bram_din_o,
        input wire [11:0] data_bram_dout_i, // Read data from BRAM to AXI Slave handler
        output reg data_bram_we_o,
        output reg data_bram_en_o,

        // User ports ends
        // Do not modify the ports beyond this line

        // Global Clock Signal
        input wire  S_AXI_ACLK,
        // Global Reset Signal. This Signal is Active LOW
        input wire  S_AXI_ARESETN,
        // Write Address ID
        input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_AWID,
        // Write address
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        input wire [7 : 0] S_AXI_AWLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        input wire [2 : 0] S_AXI_AWSIZE,
        // Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
        input wire [1 : 0] S_AXI_AWBURST,
        // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
        input wire  S_AXI_AWLOCK,
        // Memory type. This signal indicates how transactions
    // are required to progress through a system.
        input wire [3 : 0] S_AXI_AWCACHE,
        // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
        input wire [2 : 0] S_AXI_AWPROT,
        // Quality of Service, QoS identifier sent for each
    // write transaction.
        input wire [3 : 0] S_AXI_AWQOS,
        // Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
        input wire [3 : 0] S_AXI_AWREGION,
        // Optional User-defined signal in the write address channel.
        input wire [C_S_AXI_AWUSER_WIDTH-1 : 0] S_AXI_AWUSER,
        // Write address valid. This signal indicates that
    // the channel is signaling valid write address and
    // control information.
        input wire  S_AXI_AWVALID,
        // Write address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
        output wire  S_AXI_AWREADY,
        // Write Data
        input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
        // Write strobes. This signal indicates which byte
    // lanes hold valid data. There is one write strobe
    // bit for each eight bits of the write data bus.
        input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
        // Write last. This signal indicates the last transfer
    // in a write burst.
        input wire  S_AXI_WLAST,
        // Optional User-defined signal in the write data channel.
        input wire [C_S_AXI_WUSER_WIDTH-1 : 0] S_AXI_WUSER,
        // Write valid. This signal indicates that valid write
    // data and strobes are available.
        input wire  S_AXI_WVALID,
        // Write ready. This signal indicates that the slave
    // can accept the write data.
        output wire  S_AXI_WREADY,
        // Response ID tag. This signal is the ID tag of the
    // write response.
        output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_BID,
        // Write response. This signal indicates the status
    // of the write transaction.
        output wire [1 : 0] S_AXI_BRESP,
        // Optional User-defined signal in the write response channel.
        output wire [C_S_AXI_BUSER_WIDTH-1 : 0] S_AXI_BUSER,
        // Write response valid. This signal indicates that the
    // channel is signaling a valid write response.
        output wire  S_AXI_BVALID,
        // Response ready. This signal indicates that the master
    // can accept a write response.
        input wire  S_AXI_BREADY,
        // Read address ID. This signal is the identification
    // tag for the read address group of signals.
        input wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_ARID,
        // Read address. This signal indicates the initial
    // address of a read burst transaction.
        input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        input wire [7 : 0] S_AXI_ARLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        input wire [2 : 0] S_AXI_ARSIZE,
        // Burst type. The burst type and the size information, 
    // determine how the address for each transfer within the burst is calculated.
        input wire [1 : 0] S_AXI_ARBURST,
        // Lock type. Provides additional information about the
    // atomic characteristics of the transfer.
        input wire  S_AXI_ARLOCK,
        // Memory type. This signal indicates how transactions
    // are required to progress through a system.
        input wire [3 : 0] S_AXI_ARCACHE,
        // Protection type. This signal indicates the privilege
    // and security level of the transaction, and whether
    // the transaction is a data access or an instruction access.
        input wire [2 : 0] S_AXI_ARPROT,
        // Quality of Service, QoS identifier sent for each
    // read transaction.
        input wire [3 : 0] S_AXI_ARQOS,
        // Region identifier. Permits a single physical interface
    // on a slave to be used for multiple logical interfaces.
        input wire [3 : 0] S_AXI_ARREGION,
        // Optional User-defined signal in the read address channel.
        input wire [C_S_AXI_ARUSER_WIDTH-1 : 0] S_AXI_ARUSER,
        // Write address valid. This signal indicates that
    // the channel is signaling valid read address and
    // control information.
        input wire  S_AXI_ARVALID,
        // Read address ready. This signal indicates that
    // the slave is ready to accept an address and associated
    // control signals.
        output wire  S_AXI_ARREADY,
        // Read ID tag. This signal is the identification tag
    // for the read data group of signals generated by the slave.
        output wire [C_S_AXI_ID_WIDTH-1 : 0] S_AXI_RID,
        // Read Data
        output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
        // Read response. This signal indicates the status of
    // the read transfer.
        output wire [1 : 0] S_AXI_RRESP,
        // Read last. This signal indicates the last transfer
    // in a read burst.
        output wire  S_AXI_RLAST,
        // Optional User-defined signal in the read address channel.
        output wire [C_S_AXI_RUSER_WIDTH-1 : 0] S_AXI_RUSER,
        // Read valid. This signal indicates that the channel
    // is signaling the required read data.
        output wire  S_AXI_RVALID,
        // Read ready. This signal indicates that the master can
    // accept the read data and response information.
        input wire  S_AXI_RREADY
    );

    // AXI4FULL signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]       axi_awaddr;
    reg      axi_awready;
    reg      axi_wready;
    reg [1 : 0]      axi_bresp;
    reg [C_S_AXI_BUSER_WIDTH-1 : 0]      axi_buser;
    reg      axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]       axi_araddr;
    reg      axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0]       axi_rdata;
    reg [1 : 0]      axi_rresp;
    reg      axi_rlast;
    reg [C_S_AXI_RUSER_WIDTH-1 : 0]      axi_ruser;
    reg      axi_rvalid;
    // aw_wrap_en determines wrap boundary and enables wrapping
    wire aw_wrap_en;
    // ar_wrap_en determines wrap boundary and enables wrapping
    wire ar_wrap_en;
    // aw_wrap_size is the size of the write transfer, the
    // write address wraps to a lower address if upper address
    // limit is reached
    wire [31:0]  aw_wrap_size ; 
    // ar_wrap_size is the size of the read transfer, the
    // read address wraps to a lower address if upper address
    // limit is reached
    wire [31:0]  ar_wrap_size ; 
    // The axi_awv_awr_flag flag marks the presence of write address valid
    reg axi_awv_awr_flag;
    //The axi_arv_arr_flag flag marks the presence of read address valid
    reg axi_arv_arr_flag; 
    // The axi_awlen_cntr internal write address counter to keep track of beats in a burst transaction
    reg [7:0] axi_awlen_cntr;
    //The axi_arlen_cntr internal read address counter to keep track of beats in a burst transaction
    reg [7:0] axi_arlen_cntr;
    reg [1:0] axi_arburst;
    reg [1:0] axi_awburst;
    reg [7:0] axi_arlen;
    reg [7:0] axi_awlen;
    //local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
    //ADDR_LSB is used for addressing 32/64 bit registers/memories
    //ADDR_LSB = 2 for 32 bits (n downto 2) 
    //ADDR_LSB = 3 for 42 bits (n downto 3)

    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32)+ 1;
    
    // I/O Connections assignments

    assign S_AXI_AWREADY     = axi_awready;
    assign S_AXI_WREADY      = axi_wready;
    assign S_AXI_BRESP       = axi_bresp;
    assign S_AXI_BUSER       = axi_buser;
    assign S_AXI_BVALID      = axi_bvalid;
    assign S_AXI_ARREADY     = axi_arready;
    assign S_AXI_RDATA       = axi_rdata; // RDATA is now driven by axi_rdata
    assign S_AXI_RRESP       = axi_rresp;
    assign S_AXI_RLAST       = axi_rlast;
    assign S_AXI_RUSER       = axi_ruser;
    assign S_AXI_RVALID      = axi_rvalid;
    assign S_AXI_BID = S_AXI_AWID;
    assign S_AXI_RID = S_AXI_ARID;
    assign  aw_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (axi_awlen)); 
    assign  ar_wrap_size = (C_S_AXI_DATA_WIDTH/8 * (axi_arlen)); 
    assign  aw_wrap_en = ((axi_awaddr & aw_wrap_size) == aw_wrap_size)? 1'b1: 1'b0;
    assign  ar_wrap_en = ((axi_araddr & ar_wrap_size) == ar_wrap_size)? 1'b1: 1'b0;

    // Implement axi_awready generation

    // axi_awready is asserted for one S_AXI_ACLK clock cycle when both
    // S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
    // de-asserted when reset is low.

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_awready <= 1'b0;
            axi_awv_awr_flag <= 1'b0;
        end 
        else
        begin 
            if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag)
            begin
                // slave is ready to accept an address and
                // associated control signals
                axi_awready <= 1'b1;
                axi_awv_awr_flag  <= 1'b1; 
                // used for generation of bresp() and bvalid
            end
            else if (S_AXI_WLAST && axi_wready)            
            // preparing to accept next address after current write burst tx completion
            begin
                axi_awv_awr_flag  <= 1'b0;
            end
            else             
            begin
                axi_awready <= 1'b0;
            end
        end 
    end         
    // Implement axi_awaddr latching (Write address and counter)

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_awaddr <= 0;
            axi_awlen_cntr <= 0;
            axi_awburst <= 0;
            axi_awlen <= 0;
        end 
        else
        begin 
            if (~axi_awready && S_AXI_AWVALID && ~axi_awv_awr_flag)
            begin
                // address latching 
                axi_awaddr <= S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH - 1:0];  
                axi_awburst <= S_AXI_AWBURST; 
                axi_awlen <= S_AXI_AWLEN;      
                // start address of transfer
                axi_awlen_cntr <= 0;
            end   
            else if((axi_awlen_cntr <= axi_awlen) && axi_wready && S_AXI_WVALID)        
            begin
                axi_awlen_cntr <= axi_awlen_cntr + 1;

                case (axi_awburst)
                    2'b00: // fixed burst
                    // The write address for all the beats in the transaction are fixed
                    begin
                        axi_awaddr <= axi_awaddr;          
                    end   
                    2'b01: //incremental burst
                    // The write address for all the beats in the transaction are increments by awsize
                    begin
                        axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                        //awaddr aligned to 4 byte boundary
                        axi_awaddr[ADDR_LSB-1:0]   <= {ADDR_LSB{1'b0}};    
                    end   
                    2'b10: //Wrapping burst
                    // The write address wraps when the address reaches wrap boundary 
                    if (aw_wrap_en)
                    begin
                        axi_awaddr <= (axi_awaddr - aw_wrap_size); 
                    end
                    else 
                    begin
                        axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                        axi_awaddr[ADDR_LSB-1:0]   <= {ADDR_LSB{1'b0}}; 
                    end             
                    default: //reserved (incremental burst for example)
                    begin
                        axi_awaddr <= axi_awaddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    end
                endcase            
            end
        end 
    end         
    // Implement axi_wready generation

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_wready <= 1'b0;
        end 
        else
        begin 
            if ( ~axi_wready && S_AXI_WVALID && axi_awv_awr_flag)
            begin
                // slave can accept the write data
                axi_wready <= 1'b1;
            end
            else if (S_AXI_WLAST && axi_wready)
            begin
                axi_wready <= 1'b0;
            end
        end 
    end         
    // Implement write response logic generation

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_bvalid <= 0;
            axi_bresp <= 2'b0;
            axi_buser <= 0;
        end 
        else
        begin 
            if (axi_awv_awr_flag && axi_wready && S_AXI_WVALID && ~axi_bvalid && S_AXI_WLAST )
            begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0; 
                // 'OKAY' response 
            end           
            else
            begin
                if (S_AXI_BREADY && axi_bvalid) 
                begin
                    axi_bvalid <= 1'b0; 
                end 
            end
        end
    end   
    // Implement axi_arready generation

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_arready <= 1'b0;
            axi_arv_arr_flag <= 1'b0;
        end 
        else
        begin 
            if (~axi_arready && S_AXI_ARVALID && ~axi_awv_awr_flag && ~axi_arv_arr_flag)
            begin
                axi_arready <= 1'b1;
                axi_arv_arr_flag <= 1'b1;
            end
            // A burst ends when RLAST is asserted AND the data is accepted.
            else if (axi_rlast && axi_rvalid && S_AXI_RREADY)
            begin
                axi_arv_arr_flag  <= 1'b0;
            end
            else             
            begin
                axi_arready <= 1'b0;
            end
        end 
    end         
    // Implement axi_araddr latching (Read address, counter, and RLAST)
    // RLAST generation is explicitly controlled here based on axi_arlen_cntr.

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_araddr <= 0;
            axi_arlen_cntr <= 0;
            axi_arburst <= 0;
            axi_arlen <= 0;
            axi_rlast <= 1'b0;
            axi_ruser <= 0;
        end 
        else
        begin 
            if (~axi_arready && S_AXI_ARVALID && ~axi_arv_arr_flag)
            begin
                // Address latching (Start of burst)
                axi_araddr <= S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH - 1:0]; 
                axi_arburst <= S_AXI_ARBURST; 
                axi_arlen <= S_AXI_ARLEN;      
                // Counter tracks the beat index (0 to ARlen)
                axi_arlen_cntr <= 0;
                axi_rlast <= 1'b0; // Start with RLAST low
            end   
            // A read beat is accepted by the master (valid handshake)
            else if(axi_rvalid && S_AXI_RREADY)        
            begin
                // Check if the transfer just completed was the last one (0-indexed count)
                if (axi_arlen_cntr == axi_arlen && ~axi_rlast)
                begin
                    // This is the last beat, RLAST must be high
                    axi_rlast <= 1'b1;
                end
                else
                begin
                    // Not the last beat, continue the burst
                    axi_rlast <= 1'b0;
                    axi_arlen_cntr <= axi_arlen_cntr + 1; // Increment counter

                    // Address update logic
                    case (axi_arburst)
                        2'b00: begin axi_araddr <= axi_araddr; end // fixed burst
                        2'b01: //incremental burst
                        begin
                            axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                            axi_araddr[ADDR_LSB-1:0]   <= {ADDR_LSB{1'b0}};    
                        end   
                        2'b10: //Wrapping burst
                        if (ar_wrap_en) 
                        begin
                            axi_araddr <= (axi_araddr - ar_wrap_size); 
                        end
                        else 
                        begin
                            axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                            axi_araddr[ADDR_LSB-1:0]   <= {ADDR_LSB{1'b0}};    
                        end             
                        default: begin axi_araddr <= axi_araddr[C_S_AXI_ADDR_WIDTH - 1:ADDR_LSB]+1; end
                    endcase            
                end
            end
            // If RLAST was asserted and accepted, clear it for the next transaction
            else if (axi_rlast && axi_rvalid && S_AXI_RREADY)    
            begin
                axi_rlast <= 1'b0;
            end          
        end 
    end         
    // Implement axi_rvalid generation
    reg axi_rvalid1; 

    always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_rvalid <= 0;
        end else begin
            axi_rvalid <= axi_rvalid1;
        end
        
    end

    always @( posedge S_AXI_ACLK )
    begin
        if ( S_AXI_ARESETN == 1'b0 )
        begin
            axi_rvalid1 <= 0;
            axi_rresp  <= 0;
        end 
        else
        begin 
            // If address is latched and RVALID is low, assert RVALID (assuming single-cycle data latency)
            if (axi_arv_arr_flag && ~axi_rvalid1)
            begin
                axi_rvalid1 <= 1'b1;
                axi_rresp  <= 2'b0; 
                // 'OKAY' response
            end   
            // Deassert RVALID when the master accepts the data
            else if (axi_rvalid1 && S_AXI_RREADY)
            begin
                //axi_rvalid <= 1'b0;
                axi_rvalid1 <= 1'b0;
            end          
        end
    end   
    
    // ------------------------------------------
    // -- User Logic: BRAM Interface Mapping
    // ------------------------------------------

    // Combinational block to drive axi_rdata
    // This takes the data from the BRAM and zero-pads it to the AXI data width.
    always @(*)
    begin
        // Default to the BRAM output for all cycles where RDATA could be relevant
        // Since the BRAM output is read combinatorially, we use it directly.
        // The BRAM is assumed to be single-cycle access.
        axi_rdata = {{(C_S_AXI_DATA_WIDTH - 12){1'b0}}, data_bram_dout_i};
    end

    // Sequential block to control BRAM access (Address, Enable, Write Enable, Data In)
    always @(posedge S_AXI_ACLK)
    begin
        if (S_AXI_ARESETN == 1'b0)
        begin
            data_bram_addr_o <= 0;
            data_bram_din_o <= 12'b0;
            data_bram_we_o <= 1'b0;
            data_bram_en_o <= 1'b0;
        end
        else
        begin
            // BRAM Enable: Active whenever a burst is ongoing
            data_bram_en_o <= axi_awv_awr_flag | axi_arv_arr_flag;

            // BRAM Write Logic (Higher Priority)
            if (axi_awv_awr_flag && axi_wready && S_AXI_WVALID)
            begin
                // Writing data (WVALID & WREADY handshake)
                data_bram_we_o <= 1'b1;
                data_bram_din_o <= S_AXI_WDATA[11:0]; // Store lower 12 bits
                data_bram_addr_o <= axi_awaddr;        // Use the current write address
            end
            // BRAM Read Logic
            else if (axi_arv_arr_flag)
            begin
                // Reading data (Read burst is active)
                data_bram_we_o <= 1'b0;
                data_bram_addr_o <= (axi_araddr);        // Use the current read address
            end
            else
            begin
                data_bram_we_o <= 1'b0;
            end
        end
    end

    // User logic ends

    endmodule
