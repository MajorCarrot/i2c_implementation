
`include "i2c_master.v"

`timescale 1 ns / 1 ps

module i2c_master_test;

    // inputs
    reg iw_clk;
    reg iw_reset;

    // outputs
    wire io_i2c_scl;
    wire io_i2c_sda;

    i2c_master uut (
        .iw_reset(iw_reset),
        .iw_clk(iw_clk),
        .io_i2c_scl(io_i2c_scl),
        .io_i2c_sda(io_i2c_sda)
    );

    // generate input clock
    initial begin
        iw_clk <= 1'b0;        
    end

    always #1 iw_clk = ~iw_clk;

    initial begin
        $dumpfile("i2c_master_test.vcd");
        $dumpvars(0, i2c_master_test);

        iw_reset <= 1'b1;

        #10 iw_reset <= 1'b0;

        #500

        $finish;
    end

endmodule