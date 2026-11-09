`timescale 1ns/1ps

module tb_sync_fifo;
    localparam integer DATA_WIDTH = 32;
    localparam integer FIFO_DEPTH = 16;
    localparam integer COUNT_WIDTH = $clog2(FIFO_DEPTH+1);

    reg clk, rst_n, wr_en, rd_en;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;
    wire full, empty;
    wire [COUNT_WIDTH-1:0] count;

    reg [DATA_WIDTH-1:0] model_q[$];
    reg [DATA_WIDTH-1:0] expected;
    integer errors = 0;
    integer i, choice;

    sync_fifo #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .din(din),
        .rd_en(rd_en), .dout(dout), .full(full), .empty(empty), .count(count)
    );

    initial begin clk = 0; forever #5 clk = ~clk; end

    task automatic check_model;
        begin
            #1;
            if (count !== model_q.size()) begin
                $error("count DUT=%0d model=%0d", count, model_q.size()); errors++;
            end
            if (empty !== (model_q.size()==0)) begin $error("empty flag mismatch"); errors++; end
            if (full !== (model_q.size()==FIFO_DEPTH)) begin $error("full flag mismatch"); errors++; end
            if (model_q.size()!=0 && dout !== model_q[0]) begin
                $error("FWFT mismatch DUT=%h model=%h", dout, model_q[0]); errors++;
            end
            if (model_q.size()==0 && dout !== 32'h0) begin $error("empty dout not zero"); errors++; end
        end
    endtask

    task automatic push(input reg [31:0] value);
        reg accepted;
        begin
            @(negedge clk); din=value; wr_en=1; rd_en=0; accepted=!full;
            @(posedge clk); if (accepted) model_q.push_back(value);
            check_model();
            @(negedge clk); wr_en=0;
        end
    endtask

    task automatic pop;
        reg accepted;
        begin
            @(negedge clk); wr_en=0; rd_en=1; accepted=!empty;
            if (accepted) begin
                expected=model_q[0]; #1;
                if (dout !== expected) begin $error("pre-pop FWFT data mismatch"); errors++; end
            end
            @(posedge clk); if (accepted) expected=model_q.pop_front();
            check_model();
            @(negedge clk); rd_en=0;
        end
    endtask

    task automatic simultaneous(input reg [31:0] value);
        reg ra, wa;
        begin
            @(negedge clk); din=value; wr_en=1; rd_en=1; ra=!empty; wa=!full;
            if (ra) begin expected=model_q[0]; #1; if (dout!==expected) begin $error("simultaneous head mismatch"); errors++; end end
            @(posedge clk);
            if (ra) expected=model_q.pop_front();
            if (wa) model_q.push_back(value);
            check_model();
            @(negedge clk); wr_en=0; rd_en=0;
        end
    endtask

    initial begin
        rst_n=0; wr_en=0; rd_en=0; din=0; expected=0; model_q.delete();
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n=1; check_model();

        $display("[FIFO] single word and FWFT");
        push(32'h1111_0001); pop();

        $display("[FIFO] ordered multiword operations");
        push(32'hA000_0001); push(32'hA000_0002); push(32'hA000_0003);
        pop(); pop(); pop();

        $display("[FIFO] fill, overflow rejection, drain, underflow rejection");
        for (i=0;i<FIFO_DEPTH;i=i+1) push(32'hF000_0000+i);
        if (!full) begin $error("FIFO failed to assert full"); errors++; end
        push(32'hDEAD_BEEF); // conservative policy rejects write while full
        for (i=0;i<FIFO_DEPTH;i=i+1) pop();
        pop(); // empty read is rejected

        $display("[FIFO] pointer wraparound");
        for (i=0;i<12;i=i+1) push(32'hB000_0000+i);
        for (i=0;i<9;i=i+1) pop();
        for (i=0;i<12;i=i+1) push(32'hC000_0000+i);
        while (model_q.size()!=0) pop();

        $display("[FIFO] simultaneous read/write");
        push(32'h1234_5678); push(32'h8765_4321);
        simultaneous(32'hFACE_CAFE);
        while (model_q.size()!=0) pop();

        $display("[FIFO] randomized operations");
        for (i=0;i<200;i=i+1) begin
            choice=$urandom_range(0,2);
            case (choice)
                0: push($urandom);
                1: pop();
                2: simultaneous($urandom);
            endcase
        end
        while (model_q.size()!=0) pop();

        if (errors==0) $display("[FIFO] PASS");
        else $fatal(1,"[FIFO] FAIL: %0d errors",errors);
        $finish;
    end
endmodule
