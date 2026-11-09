`timescale 1ns / 1ps

module stream_monitor(
    axi_fifo_if.MONITOR vif,
    input axi_fifo_pkg::stream_mbx_t tx_mbx,
    input axi_fifo_pkg::stream_mbx_t rx_mbx
);

    import axi_fifo_pkg::*;

    stream_txn_t tx_txn;
    stream_txn_t rx_txn;

    integer tx_transfer_count;
    integer rx_transfer_count;
    integer tx_stall_count;
    integer rx_stall_count;
    integer tx_empty_count;

    reg tx_stalled;
    reg rx_stalled;

    reg [DATA_WIDTH-1:0] tx_stalled_data;
    reg [DATA_WIDTH-1:0] rx_stalled_data;

    initial begin
        tx_transfer_count = 0;
        rx_transfer_count = 0;
        tx_stall_count = 0;
        rx_stall_count = 0;
        tx_empty_count = 0;

        tx_stalled = 0;
        rx_stalled = 0;
    end

    always @(posedge vif.s_axi_aclk) begin

        if (!vif.s_axi_aresetn) begin

            tx_transfer_count <= 0;
            rx_transfer_count <= 0;
            tx_stall_count <= 0;
            rx_stall_count <= 0;
            tx_empty_count <= 0;

            tx_stalled <= 0;
            rx_stalled <= 0;

            tx_stalled_data <= '0;
            rx_stalled_data <= '0;

        end
        else begin

            // TX STREAM TRANSFER
            if (vif.tx_valid && vif.tx_ready) begin

                tx_txn.data = vif.tx_data;
                tx_mbx.put(tx_txn);

                tx_transfer_count <= tx_transfer_count + 1;

                $display("[STREAM MON][TX] DATA=%h",
                         tx_txn.data);
            end

            // TX BACKPRESSURE
            if (vif.tx_valid && !vif.tx_ready) begin

                tx_stall_count <= tx_stall_count + 1;
                tx_stalled <= 1;
                tx_stalled_data <= vif.tx_data;

            end
            else begin
                tx_stalled <= 0;
            end

            // TX EMPTY OBSERVATION
            if (vif.tx_fifo_empty)
                tx_empty_count <= tx_empty_count + 1;

            // RX STREAM TRANSFER
            if (vif.rx_valid && vif.rx_ready) begin

                rx_txn.data = vif.rx_data;
                rx_mbx.put(rx_txn);

                rx_transfer_count <= rx_transfer_count + 1;

                $display("[STREAM MON][RX] DATA=%h",
                         rx_txn.data);
            end

            // RX BACKPRESSURE
            if (vif.rx_valid && !vif.rx_ready) begin

                rx_stall_count <= rx_stall_count + 1;
                rx_stalled <= 1;
                rx_stalled_data <= vif.rx_data;

            end
            else begin
                rx_stalled <= 0;
            end

            // STABILITY CHECKS
            if (tx_stalled) begin
                if (!vif.tx_valid ||
                    vif.tx_data !== tx_stalled_data)
                    $error("[STREAM MON] TX data changed during stall");
            end

            if (rx_stalled) begin
                if (!vif.rx_valid ||
                    vif.rx_data !== rx_stalled_data)
                    $error("[STREAM MON] RX data changed during stall");
            end

        end
    end

endmodule
