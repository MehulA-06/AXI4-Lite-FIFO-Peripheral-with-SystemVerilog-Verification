`timescale 1ns / 1ps

module axi_scoreboard(
    input wire clk,
    input wire rst_n,

    input axi_fifo_pkg::axi_write_mbx_t write_mbx,
    input axi_fifo_pkg::axi_read_mbx_t  read_mbx,
    input axi_fifo_pkg::stream_mbx_t    tx_mbx,
    input axi_fifo_pkg::stream_mbx_t    rx_mbx
);

    import axi_fifo_pkg::*;

    localparam [ADDR_WIDTH-1:0] REG_TX_DATA = 32'h0000_0000;
    localparam [ADDR_WIDTH-1:0] REG_RX_DATA = 32'h0000_0004;

    // Expected and observed transaction queues
    logic [DATA_WIDTH-1:0] tx_expected[$];
    logic [DATA_WIDTH-1:0] tx_actual[$];

    logic [DATA_WIDTH-1:0] rx_expected[$];
    logic [DATA_WIDTH-1:0] rx_actual[$];

    axi_write_txn_t write_txn;
    axi_read_txn_t  read_txn;
    stream_txn_t    stream_txn;

    logic [DATA_WIDTH-1:0] expected_data;
    logic [DATA_WIDTH-1:0] actual_data;

    integer pass_count;
    integer error_count;
    integer write_processed = 0;
    integer read_processed = 0;
    integer tx_processed = 0;
    integer rx_processed = 0;
    
    
    task automatic wait_for_drain(
        input integer exp_writes,
        input integer exp_reads,
        input integer exp_tx,
        input integer exp_rx
    );
        integer cycles;
        begin
            cycles = 0;
    
            while (
                (write_processed < exp_writes ||
                 read_processed  < exp_reads  ||
                 tx_processed    < exp_tx     ||
                 rx_processed    < exp_rx)
                && cycles < 1000
            ) begin
                @(posedge clk);
                cycles++;
            end
    
            if (cycles >= 1000)
                $fatal(1, "Scoreboard drain timeout");
    
            if (error_count != 0)
                $fatal(1, "Scoreboard failures: %0d", error_count);
    
            if (tx_expected.size() != 0 ||
                rx_expected.size() != 0)
                $fatal(1, "Unmatched transactions remain");
    
            report();
        end
    endtask

    // Compare whenever both expected and actual TX data exist
    task automatic compare_tx;
        begin
            while ((tx_expected.size() != 0) &&
                   (tx_actual.size() != 0)) begin

                expected_data = tx_expected.pop_front();
                actual_data   = tx_actual.pop_front();

                if (actual_data !== expected_data) begin
                    error_count++;
                    $error("[SCOREBOARD] TX MISMATCH Expected=%h Actual=%h",
                           expected_data, actual_data);
                end
                else begin
                    pass_count++;
                    $display("[SCOREBOARD] TX PASS: %h", actual_data);
                end
            end
        end
    endtask

    // Compare whenever both expected and actual RX data exist
    task automatic compare_rx;
        begin
            while ((rx_expected.size() != 0) &&
                   (rx_actual.size() != 0)) begin

                expected_data = rx_expected.pop_front();
                actual_data   = rx_actual.pop_front();

                if (actual_data !== expected_data) begin
                    error_count++;
                    $error("[SCOREBOARD] RX MISMATCH Expected=%h Actual=%h",
                           expected_data, actual_data);
                end
                else begin
                    pass_count++;
                    $display("[SCOREBOARD] RX PASS: %h", actual_data);
                end
            end
        end
    endtask

    // Initialize scoreboard
    initial begin
        pass_count  = 0;
        error_count = 0;
          write_processed = 0;
          read_processed  = 0;
          tx_processed    = 0;
          rx_processed    = 0;
    end

    // AXI write responses: successful TX writes become expected data
    initial begin
        forever begin
            write_mbx.get(write_txn);
            write_processed++;

            if ((write_txn.addr == REG_TX_DATA) &&
                (write_txn.resp == RESP_OKAY)) begin

                tx_expected.push_back(write_txn.data);
                compare_tx();
            end
        end
    end

    // Actual TX stream transfers
    initial begin
        forever begin
            tx_mbx.get(stream_txn);
            tx_processed++;

            tx_actual.push_back(stream_txn.data);
            compare_tx();
        end
    end

    // Accepted RX stream inputs become expected RX data
    initial begin
        forever begin
            rx_mbx.get(stream_txn);
            rx_processed++;

            rx_expected.push_back(stream_txn.data);
            compare_rx();
        end
    end

    // Successful AXI reads from RX_DATA are compared
    initial begin
        forever begin
            read_mbx.get(read_txn);
             read_processed++;

            if ((read_txn.addr == REG_RX_DATA) &&
                (read_txn.resp == RESP_OKAY)) begin

                rx_actual.push_back(read_txn.data);
                compare_rx();
            end
        end
    end

    // Final report
    task automatic report;
        begin
            $display("\n========== SCOREBOARD REPORT ==========");
            $display("Passed comparisons : %0d", pass_count);
            $display("Failed comparisons : %0d", error_count);
            $display("Pending TX expected: %0d", tx_expected.size());
            $display("Pending TX actual  : %0d", tx_actual.size());
            $display("Pending RX expected: %0d", rx_expected.size());
            $display("Pending RX actual  : %0d", rx_actual.size());

            if ((error_count == 0) &&
                (tx_expected.size() == 0) &&
                (tx_actual.size() == 0) &&
                (rx_expected.size() == 0) &&
                (rx_actual.size() == 0))
                $display("SCOREBOARD: PASS");
            else
                $display("SCOREBOARD: FAIL");

            $display("=======================================\n");
        end
    endtask

task automatic wait_for_drain(
    input integer expected_writes,
    input integer expected_reads,
    input integer expected_tx,
    input integer expected_rx
);
    integer cycles;

    begin
        cycles = 0;

        while (
            (write_processed < expected_writes ||
             read_processed  < expected_reads  ||
             tx_processed    < expected_tx     ||
             rx_processed    < expected_rx)
            && cycles < 1000
        ) begin
            @(posedge clk);
            cycles++;
        end

        if (cycles >= 1000)
            $error("[SCOREBOARD] Timeout waiting for mailbox drain");

        if (write_mbx.num() != 0 ||
            read_mbx.num()  != 0 ||
            tx_mbx.num()    != 0 ||
            rx_mbx.num()    != 0)
            $error("[SCOREBOARD] Mailboxes not empty after drain");

        report();
    end
endtask

endmodule
