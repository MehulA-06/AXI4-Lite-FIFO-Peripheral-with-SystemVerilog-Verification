`timescale 1ns / 1ps

module tb_axi_fifo;

    localparam integer ADDR_WIDTH = 32;
    localparam integer DATA_WIDTH = 32;
    localparam integer FIFO_DEPTH = 16;

    localparam [31:0] REG_TX_DATA = 32'h00;
    localparam [31:0] REG_RX_DATA = 32'h04;
    localparam [31:0] REG_STATUS  = 32'h08;
    localparam [31:0] REG_CONTROL = 32'h0C;
    localparam [31:0] REG_COUNTS  = 32'h10;

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_SLVERR = 2'b10;
    localparam [1:0] RESP_DECERR = 2'b11;

    reg clk, resetn;

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
    reg         tx_ready;

    reg [31:0] rx_data;
    reg        rx_valid;
    wire       rx_ready;

    integer errors;
    integer i;

    reg [1:0] response;
    reg [31:0] read_data;
    reg [31:0] stream_data;

    integer scoreboard_tx_checks;
    integer scoreboard_rx_checks;

      
    // CLOCK
      

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

      
    // DUT
      

    axi_fifo_peripheral #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) dut (
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

      
    // PROTOCOL CHECKER
      

    axi_fifo_protocol_checker #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) protocol_checker (
        .clk(clk),
        .resetn(resetn),

        .awaddr(awaddr),
        .awvalid(awvalid),
        .awready(awready),

        .wdata(wdata),
        .wstrb(wstrb),
        .wvalid(wvalid),
        .wready(wready),

        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .araddr(araddr),
        .arvalid(arvalid),
        .arready(arready),

        .rdata(rdata),
        .rresp(rresp),
        .rvalid(rvalid),
        .rready(rready),

        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),

        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .rx_ready(rx_ready)
    );

      
    // FUNCTIONAL COVERAGE
      

    axi_coverage #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) coverage_checker (
        .clk(clk),
        .resetn(resetn),

        .awaddr(awaddr),
        .awvalid(awvalid),
        .awready(awready),

        .wvalid(wvalid),
        .wready(wready),

        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .araddr(araddr),
        .arvalid(arvalid),
        .arready(arready),

        .rdata(rdata),
        .rresp(rresp),
        .rvalid(rvalid),
        .rready(rready),

        .tx_valid(tx_valid),
        .tx_ready(tx_ready),

        .rx_valid(rx_valid),
        .rx_ready(rx_ready)
    );

      
    // RESET
      

    task automatic reset_dut;
        begin
            resetn = 1'b0;

            awaddr = 0;
            awprot = 0;
            awvalid = 0;

            wdata = 0;
            wstrb = 0;
            wvalid = 0;

            bready = 0;

            araddr = 0;
            arprot = 0;
            arvalid = 0;

            rready = 0;

            tx_ready = 0;

            rx_data = 0;
            rx_valid = 0;

            repeat (5) @(posedge clk);

            @(negedge clk);
            resetn = 1'b1;

            repeat (2) @(posedge clk);
        end
    endtask

      
    // SEND WRITE ADDRESS
      

    task automatic send_aw;
        input [31:0] addr;
        input integer delay_cycles;

        integer timeout;
        integer done;

        begin
            repeat (delay_cycles)
                @(negedge clk);

            @(negedge clk);

            awaddr = addr;
            awprot = 0;
            awvalid = 1;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (awvalid && awready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for AW handshake");
            end

            @(negedge clk);
            awvalid = 0;
        end
    endtask

      
    // SEND WRITE DATA
      

    task automatic send_w;
        input [31:0] data;
        input [3:0] strb;
        input integer delay_cycles;

        integer timeout;
        integer done;

        begin
            repeat (delay_cycles)
                @(negedge clk);

            @(negedge clk);

            wdata = data;
            wstrb = strb;
            wvalid = 1;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (wvalid && wready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for W handshake");
            end

            @(negedge clk);
            wvalid = 0;
        end
    endtask

      
    // COMPLETE AXI WRITE
      

    task automatic axi_write;
        input [31:0] addr;
        input [31:0] data;
        input [3:0] strb;
        input integer aw_delay;
        input integer w_delay;
        output [1:0] resp;

        integer timeout;
        integer done;

        begin
            resp = RESP_OKAY;

            fork
                send_aw(addr, aw_delay);
                send_w(data, strb, w_delay);
            join

            @(negedge clk);
            bready = 1;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (bvalid && bready) begin
                    resp = bresp;
                    done = 1;
                end

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for B response");
            end

            @(negedge clk);
            bready = 0;
        end
    endtask

      
    // COMPLETE AXI READ
      

    task automatic axi_read;
        input [31:0] addr;
        output [31:0] data;
        output [1:0] resp;

        integer timeout;
        integer done;

        begin
            @(negedge clk);

            araddr = addr;
            arprot = 0;
            arvalid = 1;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (arvalid && arready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for AR handshake");
            end

            @(negedge clk);

            arvalid = 0;
            rready = 1;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (rvalid && rready) begin
                    data = rdata;
                    resp = rresp;
                    done = 1;
                end

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for R response");
            end

            @(negedge clk);
            rready = 0;
        end
    endtask

      
    // RX STREAM PRODUCER
      

    task automatic send_rx;
        input [31:0] data;

        integer timeout;
        integer done;

        begin
            @(negedge clk);

            rx_data = data;
            rx_valid = 1;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (rx_valid && rx_ready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for RX handshake");
            end

            @(negedge clk);

            rx_valid = 0;
            rx_data = 0;
        end
    endtask

      
    // TX STREAM CONSUMER
      

    task automatic receive_tx;
        output [31:0] data;
        input integer ready_delay;

        integer timeout;
        integer done;

        begin
            @(negedge clk);
            tx_ready = 0;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (tx_valid)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for TX_VALID");
            end

            repeat (ready_delay)
                @(negedge clk);

            @(negedge clk);
            tx_ready = 1;

            timeout = 0;
            done = 0;

            while (done == 0) begin
                @(posedge clk);

                if (tx_valid && tx_ready) begin
                    data = tx_data;
                    done = 1;
                end

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Timeout waiting for TX handshake");
            end

            @(negedge clk);
            tx_ready = 0;
        end
    endtask

      
    // TX FIFO STRESS TEST
      

    task automatic tx_stress_test;

        integer j;

        reg [31:0] expected_data;
        reg [31:0] received_data;

        reg [1:0] local_resp;

        begin
            $display("\n[TEST] TX FIFO stress and ordering");

            @(negedge clk);
            tx_ready = 0;

            for (j = 0; j < 10; j = j + 1) begin

                expected_data = 32'hA500_0000 + j;

                axi_write(
                    REG_TX_DATA,
                    expected_data,
                    4'hF,
                    0,
                    0,
                    local_resp
                );

                if (local_resp !== RESP_OKAY)
                    $fatal(1,
                        "TX stress write failed at %0d, BRESP=%b",
                        j, local_resp);
            end

            for (j = 0; j < 10; j = j + 1) begin

                receive_tx(received_data, 2);

                expected_data = 32'hA500_0000 + j;

                if (received_data !== expected_data)
                    $fatal(1,
                        "TX order mismatch at %0d: got %h expected %h",
                        j, received_data, expected_data);
            end

            $display("[PASS] TX FIFO stress and ordering");
        end
    endtask

      
    // TX FIFO EMPTY TEST
      

    task automatic tx_empty_test;

        integer timeout;

        reg [31:0] status_data;
        reg [1:0] status_resp;

        begin
            timeout = 0;

            while (dut.tx_fifo_empty !== 1'b1) begin

                @(posedge clk);

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "TX FIFO did not become empty");
            end

            repeat (2) @(posedge clk);

            if (tx_valid !== 1'b0)
                $fatal(1, "TX_VALID high while TX FIFO empty");

            // Read public status register.
            axi_read(REG_STATUS, status_data, status_resp);

            if ((status_resp !== RESP_OKAY) ||
                (status_data[0] !== 1'b1))
                $fatal(1,
                    "TX empty status not asserted: RRESP=%b RDATA=%h",
                    status_resp, status_data);

            $display("[PASS] TX FIFO empty condition and status observation");
        end
    endtask

      
    // TX/RX REFERENCE SCOREBOARD
      

    task automatic run_scoreboard_test;

        integer k;

        reg [31:0] tx_expected [0:7];
        reg [31:0] rx_expected [0:7];

        reg [31:0] actual_data;
        reg [1:0] local_resp;

        begin
            $display("\n[TEST] TX/RX reference scoreboard");

            // TX scoreboard.
            tx_ready = 0;

            for (k = 0; k < 8; k = k + 1) begin

                tx_expected[k] = 32'hC100_0000 + k;

                axi_write(
                    REG_TX_DATA,
                    tx_expected[k],
                    4'hF,
                    k % 3,
                    (7-k) % 3,
                    local_resp
                );

                if (local_resp !== RESP_OKAY)
                    $fatal(1,
                        "Scoreboard TX write %0d failed: BRESP=%b",
                        k, local_resp);
            end

            for (k = 0; k < 8; k = k + 1) begin

                receive_tx(actual_data, k % 4);

                if (actual_data !== tx_expected[k])
                    $fatal(1,
                        "TX scoreboard mismatch at %0d: got=%h expected=%h",
                        k, actual_data, tx_expected[k]);

                scoreboard_tx_checks =
                    scoreboard_tx_checks + 1;
            end

            // RX scoreboard.
            for (k = 0; k < 8; k = k + 1) begin

                rx_expected[k] = 32'hD200_0000 + k;

                send_rx(rx_expected[k]);
            end

            for (k = 0; k < 8; k = k + 1) begin

                axi_read(
                    REG_RX_DATA,
                    actual_data,
                    local_resp
                );

                if (local_resp !== RESP_OKAY)
                    $fatal(1,
                        "Scoreboard RX read %0d failed: RRESP=%b",
                        k, local_resp);

                if (actual_data !== rx_expected[k])
                    $fatal(1,
                        "RX scoreboard mismatch at %0d: got=%h expected=%h",
                        k, actual_data, rx_expected[k]);

                scoreboard_rx_checks =
                    scoreboard_rx_checks + 1;
            end

            $display("[PASS] TX/RX reference scoreboard");
        end
    endtask

      
    // RX FIFO BACKPRESSURE TEST
      

    task automatic rx_backpressure_test;

        reg [31:0] popped_data;
        reg [1:0] local_resp;

        integer timeout;
        integer done;

        begin
            $display("\n[TEST] RX FIFO backpressure and recovery");

            if (rx_ready !== 1'b0)
                $fatal(1, "RX FIFO is not full before backpressure test");

            @(negedge clk);

            rx_data = 32'hDEAD_BEEF;
            rx_valid = 1;

            repeat (3) begin

                @(posedge clk);

                if (rx_ready !== 1'b0)
                    $fatal(1, "RX_READY asserted while FIFO full");

                if (rx_data !== 32'hDEAD_BEEF)
                    $fatal(1, "RX data changed while stalled");
            end

            axi_read(
                REG_RX_DATA,
                popped_data,
                local_resp
            );

            if (local_resp !== RESP_OKAY)
                $fatal(1, "RX read failed during backpressure release");

            timeout = 0;
            done = 0;

            while (done == 0) begin

                @(posedge clk);

                if (rx_valid && rx_ready)
                    done = 1;

                timeout = timeout + 1;

                if (timeout >= 100)
                    $fatal(1, "Pending RX word not accepted");
            end

            @(negedge clk);

            rx_valid = 0;
            rx_data = 0;

            $display("[PASS] RX FIFO backpressure and recovery");
        end
    endtask

  
// RESET DURING FIFO OPERATION
  

task automatic reset_during_fifo_test;

    reg [31:0] local_data;
    reg [1:0] local_resp;

    begin
        $display("\n[TEST] Reset during FIFO operation");

        // Start from a known state.
        reset_dut();

        // Enable peripheral.
        axi_write(REG_CONTROL, 32'h1, 4'hF,
                  0, 0, local_resp);

        if (local_resp !== RESP_OKAY)
            $fatal(1, "Peripheral enable failed");

        // Put data into TX FIFO.
        axi_write(REG_TX_DATA, 32'hFACE_1234,
                  4'hF, 0, 0, local_resp);

        if (local_resp !== RESP_OKAY)
            $fatal(1, "TX write before reset failed");

        if (dut.tx_fifo_empty !== 1'b0)
            $fatal(1, "TX FIFO did not become non-empty");

        // Reset while TX contains data.
        reset_dut();

        if (dut.tx_fifo_empty !== 1'b1)
            $fatal(1, "TX FIFO not empty after reset");

        // Enable again.
        axi_write(REG_CONTROL, 32'h1, 4'hF,
                  0, 0, local_resp);

        if (local_resp !== RESP_OKAY)
            $fatal(1, "Peripheral re-enable failed");

        // Put data into RX FIFO.
        send_rx(32'hABCD_5678);

        // Reset while RX contains data.
        reset_dut();

        // Verify that the previous RX data was flushed.
        axi_read(REG_RX_DATA, local_data, local_resp);

        if (local_resp !== RESP_SLVERR)
            $fatal(1, "RX FIFO not empty after reset");

        $display("[PASS] Reset during FIFO operation");

        // Restore enabled state for subsequent tests.
        axi_write(REG_CONTROL, 32'h1, 4'hF,
                  0, 0, local_resp);

        if (local_resp !== RESP_OKAY)
            $fatal(1, "Peripheral re-enable after reset failed");

    end
endtask

  
// FIFO POINTER WRAPAROUND TEST
  

task automatic fifo_wraparound_test;

    integer round_num;
    integer j;

    reg [31:0] expected_data;
    reg [31:0] actual_data;
    reg [1:0] local_resp;

    begin
        $display("\n[TEST] FIFO pointer wraparound");

        
        // TX FIFO
      

        tx_ready = 0;

        for (round_num = 0; round_num < 5;
             round_num = round_num + 1) begin

            // Fill TX FIFO.
            for (j = 0; j < FIFO_DEPTH; j = j + 1) begin

                expected_data =
                    32'hE100_0000 +
                    (round_num * FIFO_DEPTH) + j;

                axi_write(
                    REG_TX_DATA,
                    expected_data,
                    4'hF,
                    0,
                    0,
                    local_resp
                );

                if (local_resp !== RESP_OKAY)
                    $fatal(1,
                        "TX wrap write failed: round=%0d index=%0d",
                        round_num, j);
            end

            // Drain and verify ordering.
            for (j = 0; j < FIFO_DEPTH; j = j + 1) begin

                receive_tx(actual_data, 0);

                expected_data =
                    32'hE100_0000 +
                    (round_num * FIFO_DEPTH) + j;

                if (actual_data !== expected_data)
                    $fatal(1,
                        "TX wrap mismatch: round=%0d index=%0d",
                        round_num, j);
            end
        end

        
        // RX FIFO
       

        for (round_num = 0; round_num < 5;
             round_num = round_num + 1) begin

            // Fill RX FIFO.
            for (j = 0; j < FIFO_DEPTH; j = j + 1) begin

                expected_data =
                    32'hE200_0000 +
                    (round_num * FIFO_DEPTH) + j;

                send_rx(expected_data);
            end

            // Drain and verify ordering.
            for (j = 0; j < FIFO_DEPTH; j = j + 1) begin

                axi_read(
                    REG_RX_DATA,
                    actual_data,
                    local_resp
                );

                expected_data =
                    32'hE200_0000 +
                    (round_num * FIFO_DEPTH) + j;

                if (local_resp !== RESP_OKAY)
                    $fatal(1,
                        "RX wrap read failed: round=%0d index=%0d",
                        round_num, j);

                if (actual_data !== expected_data)
                    $fatal(1,
                        "RX wrap mismatch: round=%0d index=%0d",
                        round_num, j);
            end
        end

        $display("[PASS] FIFO pointer wraparound");

    end
endtask



      
    // MAIN TEST SEQUENCE
      

    initial begin

    
        errors = 0;

        response = RESP_OKAY;
        read_data = 0;
        stream_data = 0;

        scoreboard_tx_checks = 0;
        scoreboard_rx_checks = 0;

        $display("\n========================================");
        $display(" AXI4-LITE FIFO PERIPHERAL TEST START");
        $display("========================================\n");

        reset_dut();

        // 1. TX write while disabled.
        axi_write(
            REG_TX_DATA,
            32'h1111_AAAA,
            4'hF,
            0,
            0,
            response
        );

        if (response !== RESP_SLVERR) begin
            $error("Disabled TX write: expected SLVERR, got %b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] Disabled TX write returns SLVERR");

        // 2. Enable peripheral.
        axi_write(
            REG_CONTROL,
            32'h1,
            4'hF,
            0,
            2,
            response
        );

        if (response !== RESP_OKAY) begin
            $error("Enable write failed, BRESP=%b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] Peripheral enabled");

        // 3. AW and W arrive at different times.
        axi_write(
            REG_TX_DATA,
            32'h1234_ABCD,
            4'hF,
            0,
            4,
            response
        );

        if (response !== RESP_OKAY) begin
            $error("Independent AW/W write failed, BRESP=%b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] AW and W accepted at different times");

        // 4. TX stream transfer with backpressure.
        receive_tx(stream_data, 3);

        if (stream_data !== 32'h1234_ABCD) begin
            $error("TX data mismatch: got %h", stream_data);
            errors = errors + 1;
        end
        else
            $display("[PASS] TX FIFO stream transfer");

        tx_stress_test();

        tx_empty_test();

        // 5. Partial strobe rejected.
        axi_write(
            REG_TX_DATA,
            32'hFFFF_0000,
            4'b0011,
            0,
            0,
            response
        );

        if (response !== RESP_SLVERR) begin
            $error("Partial strobe: expected SLVERR, got %b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] Partial TX strobe rejected");

        // 6. RX stream to AXI read round trip.
        send_rx(32'hCAFE_BABE);

        axi_read(
            REG_RX_DATA,
            read_data,
            response
        );

        if ((response !== RESP_OKAY) ||
            (read_data !== 32'hCAFE_BABE)) begin

            $error(
                "RX round trip failed: RRESP=%b RDATA=%h",
                response, read_data
            );

            errors = errors + 1;
        end
        else
            $display("[PASS] RX stream to AXI read round trip");

        // 7. Empty RX read.
        axi_read(
            REG_RX_DATA,
            read_data,
            response
        );

        if (response !== RESP_SLVERR) begin
            $error("Empty RX read: expected SLVERR, got %b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] RX empty read returns SLVERR");

        // 7A. TX/RX reference scoreboard.
        run_scoreboard_test();

        // 8. Unmapped write.
        axi_write(
            32'h20,
            32'h1234,
            4'hF,
            0,
            0,
            response
        );

        if (response !== RESP_DECERR) begin
            $error("Unmapped write: expected DECERR, got %b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] Unmapped write returns DECERR");

        // 9. Fill TX FIFO and verify full rejection.
        for (i = 0; i < FIFO_DEPTH; i = i + 1) begin

            axi_write(
                REG_TX_DATA,
                32'hA000_0000 + i,
                4'hF,
                0,
                0,
                response
            );

            if (response !== RESP_OKAY) begin
                $error(
                    "TX FIFO fill failed at index %0d, BRESP=%b",
                    i, response
                );

                errors = errors + 1;
            end
        end

        axi_write(
            REG_TX_DATA,
            32'hDEAD_BEEF,
            4'hF,
            0,
            0,
            response
        );

        if (response !== RESP_SLVERR) begin
            $error("TX full write: expected SLVERR, got %b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] TX FIFO full rejection");

        // 10. TX full status and occupancy.
        axi_read(
            REG_STATUS,
            read_data,
            response
        );

        if ((response !== RESP_OKAY) ||
            (read_data[1] !== 1'b1)) begin

            $error(
                "TX full status incorrect: RRESP=%b RDATA=%h",
                response, read_data
            );

            errors = errors + 1;
        end
        else
            $display("[PASS] TX full status register");

        axi_read(
            REG_COUNTS,
            read_data,
            response
        );

        if ((response !== RESP_OKAY) ||
            (read_data[4:0] !== FIFO_DEPTH)) begin

            $error(
                "TX occupancy incorrect: RRESP=%b RDATA=%h",
                response, read_data
            );

            errors = errors + 1;
        end
        else
            $display("[PASS] TX occupancy count");

        // 11. Fill RX FIFO.
        for (i = 0; i < FIFO_DEPTH; i = i + 1)
            send_rx(32'hB000_0000 + i);

        @(negedge clk);

        if (rx_ready !== 1'b0) begin
            $error("RX_READY should be low when RX FIFO full");
            errors = errors + 1;
        end
        else
            $display("[PASS] RX FIFO full backpressure");

        // 12. RX full status and occupancy.
        axi_read(
            REG_STATUS,
            read_data,
            response
        );

        if ((response !== RESP_OKAY) ||
            (read_data[3] !== 1'b1)) begin

            $error(
                "RX full status incorrect: RRESP=%b RDATA=%h",
                response, read_data
            );

            errors = errors + 1;
        end
        else
            $display("[PASS] RX full status register");

        axi_read(
            REG_COUNTS,
            read_data,
            response
        );

        if ((response !== RESP_OKAY) ||
            (read_data[20:16] !== FIFO_DEPTH)) begin

            $error(
                "RX occupancy incorrect: RRESP=%b RDATA=%h",
                response, read_data
            );

            errors = errors + 1;
        end
        else
            $display("[PASS] RX occupancy count");

        // 13. Pending RX data must be held until a FIFO slot opens.
        rx_backpressure_test();

        // 14. Unmapped read.
        axi_read(
            32'h20,
            read_data,
            response
        );

        if (response !== RESP_DECERR) begin
            $error("Unmapped read: expected DECERR, got %b", response);
            errors = errors + 1;
        end
        else
            $display("[PASS] Unmapped read returns DECERR");


// 15. Reset during FIFO operation.
reset_during_fifo_test();

// 16. FIFO pointer wraparound.
fifo_wraparound_test();

          
        // FINAL REPORT
          

        $display("\n========================================");

        if (errors == 0)
            $display(" ALL DIRECTED TESTS PASSED");
        else
            $display(" DIRECTED TESTS FAILED: %0d errors", errors);

        $display("========================================\n");

        repeat (2) @(posedge clk);

        $display("\n===== REFERENCE SCOREBOARD REPORT =====");

        $display("TX words checked : %0d", scoreboard_tx_checks);
        $display("RX words checked : %0d", scoreboard_rx_checks);

        if ((scoreboard_tx_checks == 8) &&
            (scoreboard_rx_checks == 8)) begin

            $display("REFERENCE SCOREBOARD: PASS");
        end
        else begin

            $display("REFERENCE SCOREBOARD: FAIL");
            errors = errors + 1;
        end

        $display("=======================================\n");

        protocol_checker.report();

        coverage_checker.report();

        $display("\n========================================");
        $display("          VERIFICATION COMPLETE");
        $display("========================================");

        if (errors != 0)
            $fatal(1, "Testbench completed with %0d errors", errors);

        $finish;
    end

    // Global timeout.
    initial begin
        #200000;
        $fatal(1, "GLOBAL TESTBENCH TIMEOUT");
    end

endmodule