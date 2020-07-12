// I2C Slave Model

module i2c_slave(scl, sda, iw_reset);

    // inputs and outputs
    inout scl; // serial clock line
    inout sda; // serial data  line

    input iw_reset; // synchronous active HIGH reset
    
    // address of slave
    parameter SLAVE_ADDRESS = 7'h50;
    parameter STORED_DATA   = 8'h42;

    // FSM state definitions
    localparam CHECK_ADDRESS = 0;
    localparam ACK_ADDRESS   = 1;
    localparam READ          = 2;
    localparam ACK_READ      = 3;
    localparam WRITE         = 4;
    localparam ACK_WRITE     = 5;

    // registers
    reg [7:0] r_stored_data      = 8'b01000101; // Data stored by slave
    reg [7:0] r_received_data    = 0;           // Data received from SDA line
    reg [7:0] r_received_address = 0;           // Address received from SDA line
    reg [3:0] r_counter          = 7;           // To keep track of number of bits sent/received
    reg [3:0] r_state            = 0;           // Current state of FSM
    reg       r_start            = 0;           // 1 if r_start condition detected
    reg       r_sda_ctrl         = 0;           // 1 if slave has control of SDA line (happens in READ state), else 0
    reg       r_sda              = 0;           // Used when slave has control of SDA line

    // assign statements
    assign sda = (r_sda_ctrl == 1)? r_sda : 1'bz; // If slave does not have control, set to high impedance

    // START and STOP condition check always blocks

    // START condition check
    always @(negedge sda) begin
        
        if((scl == 1) && (r_start == 0)) begin
            r_counter  <= 7;
            r_sda_ctrl <= 0;
            r_sda      <= 0;
            r_start    <= 1;
            r_state    <= CHECK_ADDRESS;
        end

    end

    // STOP condition check
    always @(posedge sda) begin

        if((scl == 1) && (r_start == 1)) begin
            r_counter  <= 7;
            r_sda_ctrl <= 0;
            r_sda      <= 0;
            r_start    <= 0;
            r_state    <= CHECK_ADDRESS;
        end

    end

    // Finite State Machine

    // for positive cycle of SCL line - data reading
    always @(posedge scl) begin
        if (iw_reset == 1) begin
            r_counter  <= 7;
            r_sda_ctrl <= 0;
            r_sda      <= 0;
            r_start    <= 0;
            r_state    <= CHECK_ADDRESS;
        end

        else if (r_start == 1) begin // FSM is active only if START condition was satisfied and iw_reset is LOW
            case(r_state)

                CHECK_ADDRESS: begin // check address
                    r_received_address[r_counter] <= sda; // store 8 SDA bits (1 at each posedge scl) in received address register

                    if(r_counter == 0) begin // After 8 bits, go to ACK_ADDRESS state
                        r_state <= ACK_ADDRESS;
                    end

                    else begin // if counter is not 0, reduce by 1 and proceed with next bit
                        r_counter <= r_counter - 1;
                    end
                end

                ACK_READ: begin // read ACK sent by master, when master reads from slave
                    if(r_sda_ctrl == 0) begin
                        if(sda == 0) begin // ACK - continue sending data to SDA line
                            r_state   <= READ;
                            r_counter <= 7;
                        end

                        else begin // NACK - wait for stop command, release SDA line
                            r_sda_ctrl <= 0;
                            r_sda      <= 0;
                            r_start    <= 0;
                        end
                    end
                end

                WRITE: begin // master writes to slave
                    if(r_sda_ctrl == 0) begin
                        r_received_data[r_counter] <= sda; // receive data from SDA line

                        if(r_counter == 0) begin // after 8 bits, store data and send ACK to master 
                            r_stored_data <= r_received_data;
                            r_state       <= ACK_WRITE;
                        end

                        else begin // if counter not 0, reduce by 1 and proceed with next bit
                            r_counter <= r_counter - 1;
                        end
                    end
                end

            endcase
        end
    end

    // for negative cycle of SCL line - data writing
    always @(negedge scl) begin
        if(r_start == 1) begin
            case(r_state)

                ACK_ADDRESS: begin // send ACK to master if address matches, else send NACK
                    if(r_received_address[7:1] == SLAVE_ADDRESS) begin // address matches - send ACK
                        r_sda_ctrl <= 1;
                        r_sda      <= 0;
                        r_counter  <= 7;

                        if(r_received_address[0] == 0) begin // if R/W is 0, master will write to slave
                            r_state <= WRITE;
                        end

                        else if(r_received_address[0] == 1) begin // if R/W is 1, master will read from slave
                            r_state       <= READ;
                            r_stored_data <= STORED_DATA;
                        end

                        else begin // invalid R/W bit case - release SDA
                            r_start    <= 0;
                            r_sda_ctrl <= 0;
                            r_sda      <= 0;
                        end
                    end

                    else begin // address does not match - send NACK by releasing SDA
                        r_sda_ctrl <= 0;
                    end
                end

                READ: begin // master reads from slave
                    r_sda_ctrl <= 1; // control SDA to send data
                    r_sda      <= r_stored_data[r_counter]; // send data

                    if(r_counter == 0) begin // after sending 8 bits, read ACK bit sent by master
                        r_state <= ACK_READ;
                    end

                    else begin // if counter not 0, reduce by 1 and proceed with next bit
                        r_counter <= r_counter - 1;
                    end
                end

                ACK_READ: begin // read ACK bit sent by master, when master reads data from slave
                    r_sda_ctrl <= 0; // release SDA line to listen to ACK bit sent by master
                    r_sda      <= 0;
                end

                WRITE: begin // master writes to slave
                    r_sda_ctrl <= 0; // release SDA to read data from master
                    r_sda      <= 0;
                end

                ACK_WRITE: begin // send ACK bit to master after storing 
                    if(r_sda_ctrl == 0) begin
                        r_sda_ctrl <= 1; // assume control of SDA line to send ACK
                        r_sda      <= 0;
                    end

                    else begin // after sending ACK, release SDA and resume write operation
                        r_counter  <= 7;
                        r_sda_ctrl <= 0;
                        r_sda      <= 0;
                        r_state    <= WRITE;
                    end
                end

            endcase
        end
    end

endmodule