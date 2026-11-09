
`timescale 1ns/1ps
`default_nettype none

module sync_fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer FIFO_DEPTH = 16,

    parameter integer PTR_WIDTH = 4,
    parameter integer COUNT_WIDTH = 5
)(
    input wire clk,
    input wire rst_n,       // Synchronous, active-low reset

    input wire wr_en,
    input wire [DATA_WIDTH-1:0] din,

    input wire rd_en,

    output wire [DATA_WIDTH-1:0] dout,
    output wire full,
    output wire empty,

    output reg [COUNT_WIDTH-1:0] count
);

     
    // FIFO MEMORY
     

    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

     
    // READ AND WRITE POINTERS
     

    reg [PTR_WIDTH-1:0] wr_ptr;
    reg [PTR_WIDTH-1:0] rd_ptr;

     
    // FIFO CONTROL
     

    wire write_accept;
    wire read_accept;

    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);

    assign write_accept = wr_en && !full;
    assign read_accept  = rd_en && !empty;

     
    // FIRST WORD FALL THROUGH (FWFT)
  

    assign dout = empty ? {DATA_WIDTH{1'b0}} : mem[rd_ptr];

    
    // FIFO SEQUENTIAL LOGIC
    

    always @(posedge clk) begin

        if (!rst_n) begin

            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;

        end
        else begin

            // WRITE OPERATION
            if (write_accept) begin

                mem[wr_ptr] <= din;

                if (wr_ptr == FIFO_DEPTH-1)
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1'b1;

            end

            // READ OPERATION
            if (read_accept) begin

                if (rd_ptr == FIFO_DEPTH-1)
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1'b1;

            end

            // OCCUPANCY COUNTER
            case ({write_accept, read_accept})

                2'b10:
                    count <= count + 1'b1;

                2'b01:
                    count <= count - 1'b1;

                // Simultaneous read/write or no operation
                2'b00, 2'b11:
                    count <= count;

            endcase

        end

    end

endmodule

`default_nettype wire
