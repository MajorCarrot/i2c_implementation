
`include "i2c_master.v"
`include "clk_divider.v"
`include "i2c_slave_model.v"

`timescale 1 ns / 1 ps

module i2c_master_test;

    reg r_ref_clk;
    reg r_reset;
    reg r_clk_reset;
    reg r_start;
    reg r_rw;
    reg [6:0] r_addr;
    reg [7:0] r_data;

    wire [7:0] w_data;

    wire w_i2c_clk;
    wire io_i2c_scl;
    wire io_i2c_sda;
    wire w_data_en;
    wire w_ready;

    assign w_data = (~w_data_en) ? r_data : 8'bz;

    clk_divider #(.SCALER(1000)) cd1(
        .iw_ref_clk(r_ref_clk),
        .iw_reset(r_clk_reset),
        .or_i2c_clk(w_i2c_clk)
    );

    // Master
    i2c_master master (
        .iw_reset(r_reset),
        .iw_clk(w_i2c_clk),
        .iw_addr(r_addr),
        .iw_start(r_start),
        .iw_rw(r_rw),

        .io_data(w_data),
        .io_i2c_scl(io_i2c_scl),
        .io_i2c_sda(io_i2c_sda),

        .ow_data_en(w_data_en),
        .ow_ready(w_ready)
    );

    // Slave 1
    i2c_slave slave1 (
        .sda(io_i2c_sda),
        .scl(io_i2c_scl),
        .iw_reset(r_reset)
    );


    // Slave 2
    i2c_slave #(.SLAVE_ADDRESS(7'h30), .STORED_DATA(8'hb1)) slave2 (
        .sda(io_i2c_sda),
        .scl(io_i2c_scl),
        .iw_reset(r_reset)
    );


    // generate input clock
    initial begin
        r_ref_clk <= 1'b0;        
    end

    always #5 r_ref_clk = ~r_ref_clk;

    initial begin
        $dumpfile("i2c_master_test.vcd");
        $dumpvars(0, i2c_master_test);

        r_reset     <= 1'b1;
        r_clk_reset <= 1'b1;
        r_addr      <= 7'h50;
        r_start     <= 1'b0;
        r_rw        <= 1'b1;

        #100 r_clk_reset <= 1'b0; r_start <= 1'b1;

        #50000 r_reset <= 1'b0;

        // Read from slave1
        #10000 r_start <= 1'b0;

        #250000

        // Write to slave1
        #1000
        r_data  <= 8'haa;
        r_start <= 1'b1;
        r_rw    <= 1'b0;

        #10000 r_start <= 1'b0;

        #250000

        // Read from slave2
        #1000
        r_start <= 1'b1;
        r_rw    <= 1'b1;
        r_addr  <= 7'h30;

        #10000 r_start <= 1'b0;

        #250000

        // Write to slave2
        #1000
        r_start <= 1'b1;
        r_rw    <= 1'b0;
        r_addr  <= 7'h30;

        #10000 r_start <= 1'b0;

        #250000

        // Read from non-existant slave
        #1000
        r_start <= 1'b1;
        r_rw    <= 1'b1;
        r_addr  <= 7'h13;

        #10000 r_start <= 1'b0;

        #250000

        // Write to non-existant slave
        #1000
        r_start <= 1'b1;
        r_rw    <= 1'b0;
        r_addr  <= 7'h13;

        #10000 r_start <= 1'b0;

        #250000

        $finish;
    end

endmodule