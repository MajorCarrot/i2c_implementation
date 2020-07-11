// clk_divider.v

`timescale 1 ns / 1 ps

module clk_divider (
    input wire iw_ref_clk, // Reference clock
    input wire iw_reset,   // Synchronous reset
    output reg or_i2c_clk  // i2c_clk @ 100 kHz
);
    parameter SCALER = 1000;

    reg [9:0] r_count = 0; // 10 bit up-counter

    always @(posedge iw_ref_clk) begin
        if (iw_reset) begin
            r_count <= 0; // Reset to 0 since up-counter
            or_i2c_clk <= 1'b0;
        end else begin
            if (r_count == SCALER / 2) begin // Clock will be scaled by SCALER
                or_i2c_clk <= ~or_i2c_clk;
                r_count <= 0;
            end else begin
                r_count <= r_count + 1;
            end
        end
    end
endmodule