`timescale 1ns / 1ps

module stream_driver(axi_fifo_if.TB vif);
    import axi_fifo_pkg::*;

    integer timeout;

         
    // INITIALIZE STREAM SIGNALS
         
    task automatic initialize_stream();
        begin
            vif.drv_cb.rx_data  <= '0;
            vif.drv_cb.rx_valid <= 1'b0;
            vif.drv_cb.tx_ready <= 1'b0;
        end
    endtask


         
    // SEND ONE RX STREAM BEAT
         
    task automatic send_rx(
        input logic [DATA_WIDTH-1:0] data,
        input integer gap_cycles
    );
        begin
            // Insert optional gap before sending
            repeat (gap_cycles)
                @(vif.drv_cb);

            // Present data and assert VALID
            vif.drv_cb.rx_data  <= data;
            vif.drv_cb.rx_valid <= 1'b1;

            timeout = 0;

            // Hold VALID and DATA until READY
            do begin
                @(vif.drv_cb);
                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for RX_READY");

            end while (!vif.drv_cb.rx_ready);

            // Handshake completed
            vif.drv_cb.rx_valid <= 1'b0;
            vif.drv_cb.rx_data  <= '0;

        end
    endtask


         
    // CONTROL TX BACKPRESSURE
         
    task automatic set_tx_ready(
        input logic ready_value,
        input integer duration
    );
        begin
            vif.drv_cb.tx_ready <= ready_value;

            repeat (duration)
                @(vif.drv_cb);

        end
    endtask


         
    // SEND MULTIPLE RX BEATS
         
    task automatic send_rx_burst(
        input integer number_of_beats,
        input integer gap_cycles
    );
        logic [DATA_WIDTH-1:0] data;
        integer i;

        begin
            for (i = 0; i < number_of_beats; i = i + 1) begin

                data = 32'h1000_0000 + i;

                send_rx(data, gap_cycles);

            end
        end
    endtask


         
    // APPLY TX BACKPRESSURE PATTERN
         
    task automatic apply_tx_backpressure(
        input integer ready_cycles,
        input integer stall_cycles
    );
        begin
            // Consumer accepts data
            set_tx_ready(1'b1, ready_cycles);

            // Consumer temporarily stops accepting data
            set_tx_ready(1'b0, stall_cycles);

        end
    endtask

endmodule