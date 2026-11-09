
`timescale 1ns / 1ps

module axi_monitor(
    axi_fifo_if.MONITOR vif,

    input axi_fifo_pkg::axi_write_mbx_t write_mbx,
    input axi_fifo_pkg::axi_read_mbx_t  read_mbx
);

    import axi_fifo_pkg::*;

    logic aw_seen;
    logic w_seen;
    logic ar_seen;

    logic [ADDR_WIDTH-1:0] captured_awaddr;
    logic [DATA_WIDTH-1:0] captured_wdata;
    logic [STRB_WIDTH-1:0] captured_wstrb;
    logic [ADDR_WIDTH-1:0] captured_araddr;

    axi_write_txn_t write_txn;
    axi_read_txn_t  read_txn;

    // Monitor process
    initial begin

        aw_seen = 0;
        w_seen  = 0;
        ar_seen = 0;

        captured_awaddr = '0;
        captured_wdata  = '0;
        captured_wstrb  = '0;
        captured_araddr = '0;

        forever begin

            @(vif.mon_cb);

            if (!vif.mon_cb.s_axi_aresetn) begin

                aw_seen = 0;
                w_seen  = 0;
                ar_seen = 0;

                captured_awaddr = '0;
                captured_wdata  = '0;
                captured_wstrb  = '0;
                captured_araddr = '0;

            end

            else begin

                    
                // WRITE ADDRESS HANDSHAKE
                    

                if (vif.mon_cb.s_axi_awvalid &&
                    vif.mon_cb.s_axi_awready) begin

                    captured_awaddr =
                        vif.mon_cb.s_axi_awaddr;

                    aw_seen = 1;

                end

                    
                // WRITE DATA HANDSHAKE
                    

                if (vif.mon_cb.s_axi_wvalid &&
                    vif.mon_cb.s_axi_wready) begin

                    captured_wdata =
                        vif.mon_cb.s_axi_wdata;

                    captured_wstrb =
                        vif.mon_cb.s_axi_wstrb;

                    w_seen = 1;

                end

                    
                // WRITE RESPONSE HANDSHAKE
                    

                if (vif.mon_cb.s_axi_bvalid &&
                    vif.mon_cb.s_axi_bready) begin

                    if (aw_seen && w_seen) begin

                        write_txn.addr = captured_awaddr;
                        write_txn.data = captured_wdata;
                        write_txn.strb = captured_wstrb;

                        write_txn.resp =
                            axi_resp_t'(vif.mon_cb.s_axi_bresp);

                        write_mbx.put(write_txn);

                        $display(
                            "[AXI MON][WRITE] ADDR=%h DATA=%h STRB=%h RESP=%b",
                            write_txn.addr,
                            write_txn.data,
                            write_txn.strb,
                            write_txn.resp
                        );

                    end

                    else begin
                        $error(
                            "[AXI MON] B response without captured AW and W"
                        );
                    end

                    aw_seen = 0;
                    w_seen  = 0;

                end

                    
                // READ ADDRESS HANDSHAKE
                    

                if (vif.mon_cb.s_axi_arvalid &&
                    vif.mon_cb.s_axi_arready) begin

                    captured_araddr =
                        vif.mon_cb.s_axi_araddr;

                    ar_seen = 1;

                end

                    
                // READ RESPONSE HANDSHAKE
                    

                if (vif.mon_cb.s_axi_rvalid &&
                    vif.mon_cb.s_axi_rready) begin

                    if (ar_seen) begin

                        read_txn.addr = captured_araddr;
                        read_txn.data = vif.mon_cb.s_axi_rdata;

                        read_txn.resp =
                            axi_resp_t'(vif.mon_cb.s_axi_rresp);

                        read_mbx.put(read_txn);

                        $display(
                            "[AXI MON][READ] ADDR=%h DATA=%h RESP=%b",
                            read_txn.addr,
                            read_txn.data,
                            read_txn.resp
                        );

                    end

                    else begin
                        $error(
                            "[AXI MON] R response without captured AR"
                        );
                    end

                    ar_seen = 0;

                end

            end
        end
    end

endmodule
