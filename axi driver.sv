
`timescale 1ns / 1ps

module axi_driver(axi_fifo_if.TB vif);

    import axi_fifo_pkg::*;
    import random_transaction_pkg::*;

       
    // 1. SEND WRITE ADDRESS
       

    task automatic send_aw(
        input logic [ADDR_WIDTH-1:0] addr,
        input integer delay_cycles
    );

        integer timeout;
        integer done;

        begin
            repeat (delay_cycles)
                @(negedge vif.s_axi_aclk);

            @(negedge vif.s_axi_aclk);

            vif.s_axi_awaddr  <= addr;
            vif.s_axi_awprot  <= 3'b000;
            vif.s_axi_awvalid <= 1'b1;

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.s_axi_awvalid && vif.s_axi_awready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for AWREADY");

            end

            @(negedge vif.s_axi_aclk);
            vif.s_axi_awvalid <= 1'b0;

        end

    endtask


       
    // 2. SEND WRITE DATA
       

    task automatic send_w(
        input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strb,
        input integer delay_cycles
    );

        integer timeout;
        integer done;

        begin
            repeat (delay_cycles)
                @(negedge vif.s_axi_aclk);

            @(negedge vif.s_axi_aclk);

            vif.s_axi_wdata  <= data;
            vif.s_axi_wstrb  <= strb;
            vif.s_axi_wvalid <= 1'b1;

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.s_axi_wvalid && vif.s_axi_wready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for WREADY");

            end

            @(negedge vif.s_axi_aclk);
            vif.s_axi_wvalid <= 1'b0;

        end

    endtask


       
    // 3. COMPLETE AXI WRITE
       

    task automatic axi_write(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strb,
        input integer aw_delay,
        input integer w_delay,
        output logic [1:0] response
    );

        integer timeout;
        integer done;

        begin

            fork
                send_aw(addr, aw_delay);
                send_w(data, strb, w_delay);
            join

            @(negedge vif.s_axi_aclk);
            vif.s_axi_bready <= 1'b1;

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.s_axi_bvalid && vif.s_axi_bready) begin
                    response = vif.s_axi_bresp;
                    done = 1;
                end

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for BVALID");

            end

            @(negedge vif.s_axi_aclk);
            vif.s_axi_bready <= 1'b0;

        end

    endtask


       
    // 4. COMPLETE AXI READ
       

    task automatic axi_read(
        input logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data,
        output logic [1:0] response
    );

        integer timeout;
        integer done;

        begin

            @(negedge vif.s_axi_aclk);

            vif.s_axi_araddr  <= addr;
            vif.s_axi_arprot  <= 3'b000;
            vif.s_axi_arvalid <= 1'b1;

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.s_axi_arvalid && vif.s_axi_arready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for ARREADY");

            end

            @(negedge vif.s_axi_aclk);

            vif.s_axi_arvalid <= 1'b0;
            vif.s_axi_rready  <= 1'b1;

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.s_axi_rvalid && vif.s_axi_rready) begin
                    data = vif.s_axi_rdata;
                    response = vif.s_axi_rresp;
                    done = 1;
                end

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for RVALID");

            end

            @(negedge vif.s_axi_aclk);
            vif.s_axi_rready <= 1'b0;

        end

    endtask


       
    // 5. RX STREAM PRODUCER
    // TESTBENCH -> DUT
       

    task automatic send_rx(
        input logic [DATA_WIDTH-1:0] data
    );

        integer timeout;
        integer done;

        begin

            @(negedge vif.s_axi_aclk);

            vif.rx_data  <= data;
            vif.rx_valid <= 1'b1;

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.rx_valid && vif.rx_ready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for RX_READY");

            end

            @(negedge vif.s_axi_aclk);
            vif.rx_valid <= 1'b0;

        end

    endtask


       
    // 6. TX STREAM CONSUMER
    // DUT -> TESTBENCH
       

    task automatic receive_tx(
        output logic [DATA_WIDTH-1:0] data,
        input integer ready_delay
    );

        integer timeout;
        integer done;

        begin

            @(negedge vif.s_axi_aclk);
            vif.tx_ready <= 1'b0;

            // Wait until DUT produces valid TX data
            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.tx_valid)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for TX_VALID");

            end

            // Introduce backpressure
            repeat (ready_delay)
                @(negedge vif.s_axi_aclk);

            vif.tx_ready <= 1'b1;

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge vif.s_axi_aclk);

                if (vif.tx_valid && vif.tx_ready) begin
                    data = vif.tx_data;
                    done = 1;
                end

                timeout = timeout + 1;

                if (timeout >= 1000)
                    $fatal(1, "Timeout waiting for TX transfer");

            end

            @(negedge vif.s_axi_aclk);
            vif.tx_ready <= 1'b0;

        end

    endtask


       
    // 7. RANDOM AXI TRANSACTIONS
       

    task automatic run_random_transactions(
        input integer num_transactions
    );

        random_transaction txn;

        logic [1:0] response;
        logic [DATA_WIDTH-1:0] read_data;

        integer i;

        begin

            txn = new();

            for (i = 0; i < num_transactions; i = i + 1) begin

                if (!txn.randomize())
                    $fatal(1, "Transaction randomization failed");

                $display("[RANDOM] Transaction %0d", i);

                axi_write(
                    txn.addr,
                    txn.data,
                    txn.strb,
                    txn.delay_aw,
                    txn.delay_w,
                    response
                );

                axi_read(
                    txn.addr,
                    read_data,
                    response
                );

            end

        end

    endtask


       
    // 8. INITIALIZE DRIVER OUTPUTS
    // Call initialize() once from the testbench.
    // Reset itself is controlled by the top testbench.
       

    task automatic initialize();

        begin

            vif.s_axi_awaddr  = '0;
            vif.s_axi_awprot  = '0;
            vif.s_axi_awvalid = 1'b0;

            vif.s_axi_wdata   = '0;
            vif.s_axi_wstrb   = '0;
            vif.s_axi_wvalid  = 1'b0;

            vif.s_axi_bready  = 1'b0;

            vif.s_axi_araddr  = '0;
            vif.s_axi_arprot  = '0;
            vif.s_axi_arvalid = 1'b0;

            vif.s_axi_rready  = 1'b0;

            vif.tx_ready      = 1'b0;

            vif.rx_data       = '0;
            vif.rx_valid      = 1'b0;

        end

    endtask

endmodule
