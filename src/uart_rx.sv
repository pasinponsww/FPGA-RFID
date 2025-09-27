// uart_rx.v
// -----------------------------------------------------------------------------
// Simple UART receiver (8N1).
// -----------------------------------------------------------------------------

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg [7:0]  rx_data,
    output reg        rx_ready
);

    parameter BAUD_DIV = 5208; // for 9600 baud @ 50 MHz

    reg [12:0] baud_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  shift_reg;
    reg        busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt <= 0;
            bit_idx  <= 0;
            busy     <= 0;
            rx_ready <= 0;
            rx_data  <= 0;
        end else begin
            rx_ready <= 0;
            if (!busy && !rx) begin
                // start bit detected
                busy     <= 1;
                baud_cnt <= BAUD_DIV/2;
                bit_idx  <= 0;
            end else if (busy) begin
                if (baud_cnt == BAUD_DIV-1) begin
                    baud_cnt <= 0;
                    if (bit_idx < 8) begin
                        shift_reg[bit_idx] <= rx;
                        bit_idx <= bit_idx + 1;
                    end else begin
                        rx_data  <= shift_reg;
                        rx_ready <= 1;
                        busy     <= 0;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end
        end
    end
endmodule
