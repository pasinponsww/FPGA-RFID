// uart_baud_gen.v
// Generates baud-rate ticks for UART TX and 16x oversampling ticks for UART RX.
`timescale 1ns/1ps
module uart_baud_gen #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer BAUD        = 115200,
    parameter integer OVERSAMPLE  = 16
)(
    input  wire clk,
    input  wire rst,
    output reg  tick_x16,   // 1-clock pulse at BAUD*OVERSAMPLE
    output reg  tick_bit    // 1-clock pulse at BAUD (one per bit)
);
    // Divisors (rounded)
    localparam integer DIV_X16 = (CLK_FREQ_HZ + (BAUD*OVERSAMPLE)/2) / (BAUD*OVERSAMPLE);
    localparam integer DIV_BIT = (CLK_FREQ_HZ + BAUD/2) / BAUD;

    // Counters
    reg [$clog2(DIV_X16):0] cnt_x16;
    reg [$clog2(DIV_BIT):0] cnt_bit;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt_x16 <= 0; tick_x16 <= 1'b0;
            cnt_bit <= 0; tick_bit <= 1'b0;
        end else begin
            // x16 tick
            if (cnt_x16 == DIV_X16-1) begin
                cnt_x16 <= 0;
                tick_x16 <= 1'b1;
            end else begin
                cnt_x16 <= cnt_x16 + 1'b1;
                tick_x16 <= 1'b0;
            end
            // bit tick
            if (cnt_bit == DIV_BIT-1) begin
                cnt_bit <= 0;
                tick_bit <= 1'b1;
            end else begin
                cnt_bit <= cnt_bit + 1'b1;
                tick_bit <= 1'b0;
            end
        end
    end
endmodule
