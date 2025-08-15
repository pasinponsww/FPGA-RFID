// uart_rx.v
// Simple 8N1 UART receiver with 16x oversampling.
// Idle high. LSB-first. Produces 1-cycle data_valid pulse with data_out.
`timescale 1ns/1ps
module uart_rx #(
    parameter integer OVERSAMPLE = 16
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,            // serial input (idle high)
    input  wire tick_x16,      // oversampling tick from baud gen
    output reg  [7:0] data_out,
    output reg         data_valid,
    output reg         framing_err
);
    localparam [2:0] S_IDLE  = 3'd0,
                     S_START = 3'd1,
                     S_DATA  = 3'd2,
                     S_STOP  = 3'd3;

    reg [2:0] state;
    reg [3:0] sample_cnt; // 0..15
    reg [2:0] bit_idx;    // 0..7
    reg [7:0] shifter;
    reg       rx_sync1, rx_sync2;

    // Double-flop synchronize
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            sample_cnt <= 4'd0;
            bit_idx <= 3'd0;
            shifter <= 8'd0;
            data_out <= 8'd0;
            data_valid <= 1'b0;
            framing_err <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            framing_err <= 1'b0;
            if (tick_x16) begin
                case (state)
                    S_IDLE: begin
                        if (~rx_sync2) begin // start bit detected (line went low)
                            state <= S_START;
                            sample_cnt <= 4'd0;
                        end
                    end
                    S_START: begin
                        sample_cnt <= sample_cnt + 1'b1;
                        if (sample_cnt == (OVERSAMPLE/2 - 1)) begin
                            // Mid of start bit
                            if (~rx_sync2) begin
                                state <= S_DATA;
                                sample_cnt <= 4'd0;
                                bit_idx <= 3'd0;
                            end else begin
                                // False start, go back idle
                                state <= S_IDLE;
                            end
                        end
                    end
                    S_DATA: begin
                        sample_cnt <= sample_cnt + 1'b1;
                        if (sample_cnt == OVERSAMPLE-1) begin
                            sample_cnt <= 4'd0;
                            // Sample in the middle of the bit (since we reset at end of previous)
                            shifter <= {rx_sync2, shifter[7:1]}; // LSB first
                            if (bit_idx == 3'd7) begin
                                state <= S_STOP;
                            end
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end
                    S_STOP: begin
                        sample_cnt <= sample_cnt + 1'b1;
                        if (sample_cnt == OVERSAMPLE-1) begin
                            // Stop bit should be high
                            if (rx_sync2) begin
                                data_out <= shifter;
                                data_valid <= 1'b1;
                            end else begin
                                framing_err <= 1'b1;
                            end
                            state <= S_IDLE;
                        end
                    end
                endcase
            end
        end
    end
endmodule
