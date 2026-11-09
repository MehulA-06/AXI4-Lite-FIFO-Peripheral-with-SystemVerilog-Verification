
`timescale 1ns / 1ps

module axi_fifo_peripheral #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer FIFO_DEPTH = 16
)(
    input  wire                    s_axi_aclk,
    input  wire                    s_axi_aresetn,

    // AXI WRITE ADDRESS
    input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire [2:0]              s_axi_awprot,
    input  wire                    s_axi_awvalid,
    output wire                    s_axi_awready,

    // AXI WRITE DATA
    input  wire [DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                    s_axi_wvalid,
    output wire                    s_axi_wready,

    // AXI WRITE RESPONSE
    output wire [1:0]              s_axi_bresp,
    output wire                    s_axi_bvalid,
    input  wire                    s_axi_bready,

    // AXI READ ADDRESS
    input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire [2:0]              s_axi_arprot,
    input  wire                    s_axi_arvalid,
    output wire                    s_axi_arready,

    // AXI READ DATA
    output wire [DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]              s_axi_rresp,
    output wire                    s_axi_rvalid,
    input  wire                    s_axi_rready,

    // TX STREAM: FIFO -> consumer
    output wire [DATA_WIDTH-1:0]   tx_data,
    output wire                    tx_valid,
    input  wire                    tx_ready,

    // RX STREAM: producer -> FIFO
    input  wire [DATA_WIDTH-1:0]   rx_data,
    input  wire                    rx_valid,
    output wire                    rx_ready
);

    localparam integer COUNT_WIDTH = 5;

    // Register map
    localparam [ADDR_WIDTH-1:0] REG_TX_DATA = 32'h0000_0000;
    localparam [ADDR_WIDTH-1:0] REG_RX_DATA = 32'h0000_0004;
    localparam [ADDR_WIDTH-1:0] REG_STATUS  = 32'h0000_0008;
    localparam [ADDR_WIDTH-1:0] REG_CONTROL = 32'h0000_000C;
    localparam [ADDR_WIDTH-1:0] REG_COUNTS  = 32'h0000_0010;

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;
    localparam [1:0] RESP_DECERR = 2'b11;

    // FIFO SIGNALS
   

    wire [DATA_WIDTH-1:0] tx_fifo_dout;
    wire [DATA_WIDTH-1:0] rx_fifo_dout;

    wire tx_fifo_full, tx_fifo_empty;
    wire rx_fifo_full, rx_fifo_empty;

    wire [COUNT_WIDTH-1:0] tx_fifo_count;
    wire [COUNT_WIDTH-1:0] rx_fifo_count;

    reg tx_fifo_wr_en;
    reg [DATA_WIDTH-1:0] tx_fifo_din;
    wire tx_fifo_rd_en;

    wire rx_fifo_wr_en;
    reg rx_fifo_rd_en;

    reg peripheral_enable;

    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) tx_fifo_inst (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .wr_en(tx_fifo_wr_en),
        .din(tx_fifo_din),
        .rd_en(tx_fifo_rd_en),
        .dout(tx_fifo_dout),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty),
        .count(tx_fifo_count)
    );
    sync_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) rx_fifo_inst (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .wr_en(rx_fifo_wr_en),
        .din(rx_data),
        .rd_en(rx_fifo_rd_en),
        .dout(rx_fifo_dout),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty),
        .count(rx_fifo_count)
    );

    assign tx_data = tx_fifo_dout;
    assign tx_valid = peripheral_enable && !tx_fifo_empty;
    assign tx_fifo_rd_en = tx_valid && tx_ready;

    assign rx_ready = peripheral_enable && !rx_fifo_full;
    assign rx_fifo_wr_en = rx_valid && rx_ready;

    // WRITE CHANNEL

    localparam [2:0] W_IDLE     = 3'd0;
    localparam [2:0] W_COLLECT  = 3'd1;
    localparam [2:0] W_EXECUTE  = 3'd2;
    localparam [2:0] W_COMMIT   = 3'd3;
    localparam [2:0] W_RESPONSE = 3'd4;

    reg [2:0] write_state;

    reg aw_pending;
    reg w_pending;

    reg [ADDR_WIDTH-1:0] awaddr_reg;
    reg [DATA_WIDTH-1:0] wdata_reg;
    reg [DATA_WIDTH/8-1:0] wstrb_reg;

    reg bvalid_reg;
    reg [1:0] bresp_reg;


    wire aw_handshake = s_axi_awvalid && s_axi_awready;
    wire w_handshake  = s_axi_wvalid  && s_axi_wready;

    assign s_axi_awready =
        (write_state == W_COLLECT) && !aw_pending;

    assign s_axi_wready =
        (write_state == W_COLLECT) && !w_pending;

    assign s_axi_bvalid = bvalid_reg;
    assign s_axi_bresp  = bresp_reg;

    always @(*) begin
        tx_fifo_wr_en = 1'b0;
        tx_fifo_din   = wdata_reg;

        if ((write_state == W_COMMIT))
            tx_fifo_wr_en = 1'b1;
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            write_state       <= W_IDLE;
            aw_pending        <= 1'b0;
            w_pending         <= 1'b0;
            awaddr_reg        <= 0;
            wdata_reg         <= 0;
            wstrb_reg         <= 0;
            bvalid_reg        <= 1'b0;
            bresp_reg         <= RESP_OKAY;
            peripheral_enable <= 1'b0;
            
        end
        else begin
            case (write_state)

                W_IDLE: begin
                    write_state <= W_COLLECT;
                end

                W_COLLECT: begin
                    if (aw_handshake) begin
                        awaddr_reg <= s_axi_awaddr;
                        aw_pending <= 1'b1;
                    end

                    if (w_handshake) begin
                        wdata_reg <= s_axi_wdata;
                        wstrb_reg <= s_axi_wstrb;
                        w_pending <= 1'b1;
                    end

                    if ((aw_pending || aw_handshake) &&
                        (w_pending  || w_handshake)) begin
                        write_state <= W_EXECUTE;
                    end
                end

                W_EXECUTE: begin
                    bresp_reg <= RESP_OKAY;
                
                    if (wstrb_reg != {(DATA_WIDTH/8){1'b1}}) begin
                        bresp_reg <= RESP_SLVERR;
                        write_state <= W_RESPONSE;
                    end
                    else begin
                        case (awaddr_reg)
                
                            REG_TX_DATA: begin
                                if (!peripheral_enable || tx_fifo_full) begin
                                    bresp_reg <= RESP_SLVERR;
                                    write_state <= W_RESPONSE;
                                end
                                else begin
                                    write_state <= W_COMMIT;
                                end
                            end
                
                            REG_CONTROL: begin
                                peripheral_enable <= wdata_reg[0];
                                write_state <= W_RESPONSE;
                            end
                
                            default: begin
                                bresp_reg <= RESP_DECERR;
                                write_state <= W_RESPONSE;
                            end
                
                        endcase
                    end
                end
                
                W_COMMIT: begin
                    bresp_reg <= RESP_OKAY;
                    write_state <= W_RESPONSE;
                end

                W_RESPONSE: begin
                    bvalid_reg <= 1'b1;

                    if (bvalid_reg && s_axi_bready) begin
                        bvalid_reg <= 1'b0;
                        aw_pending <= 1'b0;
                        w_pending <= 1'b0;
                        write_state <= W_COLLECT;
                    end
                end

                default: begin
                    write_state <= W_IDLE;
                end

            endcase
        end
    end

    // READ CHANNEL


    localparam [1:0] R_IDLE     = 2'd0;
    localparam [1:0] R_EXECUTE  = 2'd1;
    localparam [1:0] R_RESPONSE = 2'd2;

    reg [1:0] read_state;

    reg [ADDR_WIDTH-1:0] araddr_reg;
    reg [DATA_WIDTH-1:0] rdata_reg;
    reg [1:0] rresp_reg;
    reg rvalid_reg;

    wire ar_handshake = s_axi_arvalid && s_axi_arready;

    assign s_axi_arready = (read_state == R_IDLE);

    assign s_axi_rdata  = rdata_reg;
    assign s_axi_rresp  = rresp_reg;
    assign s_axi_rvalid = rvalid_reg;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            read_state    <= R_IDLE;
            araddr_reg    <= 0;
            rdata_reg     <= 0;
            rresp_reg     <= RESP_OKAY;
            rvalid_reg    <= 1'b0;
            rx_fifo_rd_en <= 1'b0;
        end
        else begin
            rx_fifo_rd_en <= 1'b0;

            case (read_state)

                R_IDLE: begin
                    if (ar_handshake) begin
                        araddr_reg <= s_axi_araddr;
                        read_state <= R_EXECUTE;
                    end
                end

                R_EXECUTE: begin
                    rdata_reg <= 0;
                    rresp_reg <= RESP_OKAY;

                    case (araddr_reg)

                        REG_TX_DATA: begin
                            rresp_reg <= RESP_SLVERR;
                        end

                        REG_RX_DATA: begin
                            if (!peripheral_enable || rx_fifo_empty) begin
                                rresp_reg <= RESP_SLVERR;
                            end
                            else begin
                                rdata_reg <= rx_fifo_dout;
                                rx_fifo_rd_en <= 1'b1;
                            end
                        end

                        REG_STATUS: begin
                            rdata_reg[0] <= tx_fifo_empty;
                            rdata_reg[1] <= tx_fifo_full;
                            rdata_reg[2] <= rx_fifo_empty;
                            rdata_reg[3] <= rx_fifo_full;
                            rdata_reg[4] <= peripheral_enable;
                        end

                        REG_CONTROL: begin
                            rdata_reg[0] <= peripheral_enable;
                        end

                        REG_COUNTS: begin
                            rdata_reg[COUNT_WIDTH-1:0] <= tx_fifo_count;
                            rdata_reg[16 +: COUNT_WIDTH] <= rx_fifo_count;
                        end

                        default: begin
                            rresp_reg <= RESP_DECERR;
                        end

                    endcase

                    rvalid_reg <= 1'b1;
                    read_state <= R_RESPONSE;
                end

                R_RESPONSE: begin
                    if (rvalid_reg && s_axi_rready) begin
                        rvalid_reg <= 1'b0;
                        read_state <= R_IDLE;
                    end
                end

                default: begin
                    read_state <= R_IDLE;
                end

            endcase
        end
    end

endmodule
