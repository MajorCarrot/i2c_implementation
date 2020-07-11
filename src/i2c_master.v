// i2c_master.v

module i2c_master(
    inout wire io_i2c_sda,
    inout wire io_i2c_scl, // Clock for the comm
    input wire iw_reset,   // Synchronous reset
    input wire iw_clk      // Clock driving the master
);

    // i2c specs: Both SCL and SDA are pulled up
    pullup (io_i2c_sda);
    pullup (io_i2c_scl);

    reg r_i2c_sda; // registered version of inout io_i2c_sda

    assign io_i2c_sda = r_i2c_sda; // Continuous assignment

    reg [7:0] r_data;        // data read/written
    reg [6:0] r_addr;        // Address of the slave
    reg [7:0] r_state;       // Register to store current state
    reg [7:0] r_count;       // To count the number of bits transmitted
    reg [7:0] r_send_data;   // Data to send (addr/data)
    reg r_rw;                // Read or Write data?
    reg r_i2c_scl_en = 1'b0; // Enable signal for clock

    assign io_i2c_scl = r_i2c_scl_en ? ~iw_clk: 1;

    // Gray code assignment to states
    localparam IDLE     = 0; // idle (ready to work)
    localparam START    = 1; // start transaction
    localparam W_ADDR   = 2; // write slave addr
    localparam R_ACK_WA = 3; // read ack
    localparam W_DATA   = 4; // write data
    localparam R_ACK_WD = 5; // read ack for write
    localparam R_DATA   = 6; // read data
    localparam W_ACK_RD = 7; // write ack for read
    localparam STOP     = 8; // stop transaction

    /*
        ### Write data ####
        -> send START condn
        -> Addr (7-bit) + 1 bit r/w (set to 0)
        -> Wait for ACK
        -> Write data (8-bit)
        -> Wait for ACK
        -> STOP

        ### Read data ####
        -> send START condn
        -> Addr (7-bit) + 1 bit r/w (set to 0)
        -> Wait for ACK
        -> Read data (8-bit)
        -> Send NACK
        -> STOP
    */

    // Generate io_i2c_scl
    always @(posedge iw_clk) begin
        if (iw_reset == 1) begin
            r_i2c_scl_en <= 1'b0;
        end else begin
            if ((r_state == IDLE) || (r_state == START) || (r_state == STOP)) begin
                r_i2c_scl_en <= 1'b0;
            end else begin
                r_i2c_scl_en <= 1'b1;
            end
        end
    end

    // FSM
    always @(posedge iw_clk) begin

        if (iw_reset == 1) begin // reset condn
            r_state     <= 8'b00000000;
            r_count     <= 8'd0;
            r_addr      <= 7'h50;
            r_i2c_sda   <= 1'b1;            // Pull it to zero
            r_rw        <= 1'b0;            // We are writing data
            r_send_data <= {r_addr, r_rw};  // data to send is addr+rw
            r_data      <= 8'haa;           // Send data 0xaa
        end else begin // not reset condn
            case (r_state)
                IDLE: begin // idle
                    r_i2c_sda <= 1;
                    r_state <= START;
                end // end idle

                START: begin // begin start
                    r_i2c_sda <= 0;
                    r_state <= W_ADDR;
                    r_count <= 7;
                end // end start

                W_ADDR: begin // begin write address
                    r_i2c_sda <= r_send_data[r_count]; // write the addr+rw

                    if (r_count == 0) begin
                        r_state <= R_ACK_WA; // If done wait for ack
                    end else begin
                        r_count <= r_count - 1; // Continue counting (For loop in units of clk)
                    end
                end // end write address

                R_ACK_WA: begin // begin read ack for write address
                    // Need to update to check for ack
                    r_count <= 7;
                    if (r_rw) begin
                        r_state <= R_DATA;
                    end else begin
                        r_state     <= W_DATA;
                        r_send_data <= r_data;
                    end
                end // end read ack for write address

                W_DATA: begin // begin write data
                    r_i2c_sda <= r_send_data[r_count];
                    if (r_count == 0) r_state <= R_ACK_WD;
                    else r_count <= r_count - 1;
                end // end write data

                R_ACK_WD: begin // begin read ack for write data
                    // Need to update to check for ack
                    r_state <= STOP;
                end // end read ack for write data

                STOP: begin // begin stop
                    r_i2c_sda <= 1'b1;
                    r_state   <= IDLE;
                end // end stop
            endcase
        end
    end
endmodule
