// uart_tx.v
// Simple 8N1 UART transmitter.
// Use baud 'tick_bit' (one pulse per bit). LSB first. Idle high.
`timescale 1ns/1ps
module uart_tx(
    input  wire clk,
    input  wire rst,
    input  wire [7:0] data_in,
    input  wire       data_strobe, // pulse to start sending data_in
    input  wire       tick_bit,    // 1 pulse per bit time from baud gen
    output reg        tx,          // serial out
    output reg        busy
);
    localparam [2:0] T_IDLE = 3'd0,
                     T_START= 3'd1,
                     T_BITS = 3'd2,
                     T_STOP = 3'd3;

    reg [2:0] state;
    reg [2:0] bit_idx;
    reg [7:0] shifter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= T_IDLE;
            tx <= 1'b1; // idle high
            busy <= 1'b0;
            bit_idx <= 3'd0;
            shifter <= 8'd0;
        end else begin
            if (state == T_IDLE) begin
                if (data_strobe) begin
                    busy <= 1'b1;
                    shifter <= data_in;
                    bit_idx <= 3'd0;
                    state <= T_START;
                    tx <= 1'b0; // start bit
                end
            end else if (tick_bit) begin
                case (state)
                    T_START: begin
                        state <= T_BITS;
                        tx <= shifter[0];
                    end
                    T_BITS: begin
                        shifter <= {1'b0, shifter[7:1]};
                        if (bit_idx == 3'd7) begin
                            state <= T_STOP;
                            tx <= 1'b1; // stop bit
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                            tx <= shifter[1];
                        end
                    end
                    T_STOP: begin
                        state <= T_IDLE;
                        busy <= 1'b0;
                        tx <= 1'b1; // idle
                    end
                endcase
            end
        end
    end
endmodule
