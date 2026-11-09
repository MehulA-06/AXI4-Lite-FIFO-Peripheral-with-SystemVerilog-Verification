
`timescale 1ns / 1ps

module axi_random_test;

    import axi_fifo_pkg::*;

    // Random transaction fields
    class random_transaction;
        rand bit [31:0] addr;
        rand bit [31:0] data;
        rand bit [3:0]  strb;
        rand bit [3:0]  delay_aw;
        rand bit [3:0]  delay_w;
        rand bit [3:0]  delay_ready;

        constraint address_c {
            addr inside {
                32'h0000_0000,
                32'h0000_0004,
                32'h0000_0008,
                32'h0000_000C,
                32'h0000_0010
            };
        }

        constraint delay_c {
            delay_aw inside {[0:8]};
            delay_w inside {[0:8]};
            delay_ready inside {[0:8]};
        }

        constraint strobe_c {
            strb dist {
                4'b1111 := 70,
                [4'b0001:4'b1110] := 30
            };
        }
    endclass

endmodule
