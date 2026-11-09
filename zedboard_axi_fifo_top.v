
`timescale 1ns / 1ps
`default_nettype none

module zedboard_axi_fifo_top (
    input  wire       clk,
    input  wire       btnc,
    output wire [7:0] led
);


    localparam [31:0] REG_TX_DATA = 32'h00000000;
    localparam [31:0] REG_RX_DATA = 32'h00000004;
    localparam [31:0] REG_CONTROL = 32'h0000000C;

    localparam [1:0] RESP_OKAY = 2'b00;


    reg [1:0] reset_pipe;

    always @(posedge clk or posedge btnc) begin
        if (btnc)
            reset_pipe <= 2'b00;
        else
            reset_pipe <= {reset_pipe[0], 1'b1};
    end

    wire resetn = reset_pipe[1];


    reg [31:0] awaddr;
    reg [2:0]  awprot;
    reg        awvalid;
    wire       awready;

    reg [31:0] wdata;
    reg [3:0]  wstrb;
    reg        wvalid;
    wire       wready;

    wire [1:0] bresp;
    wire       bvalid;
    reg        bready;

    reg [31:0] araddr;
    reg [2:0]  arprot;
    reg        arvalid;
    wire       arready;

    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;


    wire [31:0] tx_data;
    wire        tx_valid;
    wire        tx_ready;

    reg  [31:0] rx_data;
    reg         rx_valid;
    wire        rx_ready;

    assign tx_ready = 1'b1;

    axi_fifo_peripheral #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .FIFO_DEPTH(16)
    ) fifo_peripheral_inst (

        .s_axi_aclk(clk),
        .s_axi_aresetn(resetn),

        .s_axi_awaddr(awaddr),
        .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),

        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),

        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),

        .s_axi_araddr(araddr),
        .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),

        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),

        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),

        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_ready(rx_ready)
    );

    localparam [3:0]
        ST_IDLE       = 4'd0,
        ST_ENABLE     = 4'd1,
        ST_TX_START   = 4'd2,
        ST_TX_NEXT    = 4'd3,
        ST_WR_SEND    = 4'd4,
        ST_WR_RESP    = 4'd5,
        ST_RX_SEND    = 4'd6,
        ST_RX_WAIT    = 4'd7,
        ST_RD_START   = 4'd8,
        ST_RD_ADDR    = 4'd9,
        ST_RD_DATA    = 4'd10,
        ST_DONE       = 4'd11;

    reg [3:0] state;
    reg [3:0] after_write;

    reg [2:0] tx_index;
    reg [2:0] rx_index;
    reg [2:0] read_index;

    reg [31:0] expected_rx;

    reg done;
    reg error_flag;

    reg [7:0] tx_transfer_count;


    assign led[0] = done;
    assign led[1] = error_flag;
    assign led[2] = tx_valid;
    assign led[3] = rx_ready;
    assign led[7:4] = read_index;

    always @(posedge clk) begin

        if (!resetn) begin

            state <= ST_IDLE;
            after_write <= ST_IDLE;

            awaddr <= 0;
            awprot <= 0;
            awvalid <= 0;

            wdata <= 0;
            wstrb <= 4'hF;
            wvalid <= 0;

            bready <= 0;

            araddr <= 0;
            arprot <= 0;
            arvalid <= 0;

            rready <= 0;

            rx_data <= 0;
            rx_valid <= 0;

            tx_index <= 0;
            rx_index <= 0;
            read_index <= 0;

            expected_rx <= 0;

            done <= 0;
            error_flag <= 0;
            tx_transfer_count <= 0;

        end
        else begin

            if (tx_valid && tx_ready)
                tx_transfer_count <= tx_transfer_count + 1'b1;

            case (state)


                ST_IDLE: begin
                    state <= ST_ENABLE;
                end

                ST_ENABLE: begin

                    awaddr <= REG_CONTROL;
                    awprot <= 0;
                    awvalid <= 1;

                    wdata <= 32'h00000001;
                    wstrb <= 4'hF;
                    wvalid <= 1;

                    bready <= 0;

                    after_write <= ST_TX_START;

                    state <= ST_WR_SEND;

                end

                ST_TX_START: begin

                    if (tx_index < 4) begin

                        awaddr <= REG_TX_DATA;
                        awprot <= 0;
                        awvalid <= 1;

                        wdata <= 32'hA5000000 + tx_index;
                        wstrb <= 4'hF;
                        wvalid <= 1;

                        bready <= 0;

                        after_write <= ST_TX_NEXT;

                        state <= ST_WR_SEND;

                    end
                    else begin
                        rx_index <= 0;
                        state <= ST_RX_SEND;
                    end

                end

                ST_TX_NEXT: begin

                    tx_index <= tx_index + 1'b1;
                    state <= ST_TX_START;

                end

                ST_WR_SEND: begin

                    if (awvalid && awready)
                        awvalid <= 0;

                    if (wvalid && wready)
                        wvalid <= 0;

                    if ((!awvalid || awready) &&
                        (!wvalid || wready)) begin

                        state <= ST_WR_RESP;

                    end

                end

                ST_WR_RESP: begin

                    bready <= 1;

                    if (bvalid && bready) begin

                        bready <= 0;

                        if (bresp != RESP_OKAY)
                            error_flag <= 1;

                        state <= after_write;

                    end

                end

                ST_RX_SEND: begin

                    rx_data <= 32'hB6000000 + rx_index;
                    rx_valid <= 1;

                    state <= ST_RX_WAIT;

                end

                ST_RX_WAIT: begin

                    if (rx_valid && rx_ready) begin

                        rx_valid <= 0;

                        if (rx_index == 3) begin

                            read_index <= 0;
                            state <= ST_RD_START;

                        end
                        else begin

                            rx_index <= rx_index + 1'b1;
                            state <= ST_RX_SEND;

                        end

                    end

                end

                ST_RD_START: begin

                    araddr <= REG_RX_DATA;
                    arprot <= 0;
                    arvalid <= 1;

                    rready <= 0;

                    state <= ST_RD_ADDR;

                end

                ST_RD_ADDR: begin

                    if (arvalid && arready) begin

                        arvalid <= 0;
                        rready <= 1;

                        state <= ST_RD_DATA;

                    end

                end

                ST_RD_DATA: begin

                    if (rvalid && rready) begin

                        rready <= 0;

                        expected_rx = 32'hB6000000 + read_index;

                        if (rresp != RESP_OKAY ||
                            rdata != expected_rx) begin

                            error_flag <= 1;

                        end

                        if (read_index == 3) begin

                            state <= ST_DONE;

                        end
                        else begin

                            read_index <= read_index + 1'b1;
                            state <= ST_RD_START;

                        end

                    end

                end


                ST_DONE: begin

                    done <= 1;

                end

                default: begin

                    state <= ST_IDLE;
                    error_flag <= 1;

                end

            endcase

        end

    end

endmodule

`default_nettype wire
