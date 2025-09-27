// uart_tx.v
// -----------------------------------------------------------------------------
// Simple UART transmitter (8N1).
// -----------------------------------------------------------------------------

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        tx_busy
);

    parameter BAUD_DIV = 5208; // for 9600 baud @ 50 MHz

    reg [12:0] baud_cnt;
    reg [3:0]  bit_idx;
    reg [9:0]  shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx       <= 1'b1;
            tx_busy  <= 1'b0;
            baud_cnt <= 0;
            bit_idx  <= 0;
            shift_reg<= 0;
        end else begin
            if (tx_start && !tx_busy) begin
                // load start(0), data, stop(1)
                shift_reg <= {1'b1, tx_data, 1'b0};
                tx_busy   <= 1'b1;
                baud_cnt  <= 0;
                bit_idx   <= 0;
            end else if (tx_busy) begin
                if (baud_cnt == BAUD_DIV-1) begin
                    baud_cnt <= 0;
                    tx       <= shift_reg[bit_idx];
                    bit_idx  <= bit_idx + 1;
                    if (bit_idx == 9) begin
                        tx_busy <= 1'b0;
                        tx      <= 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end
        end
    end
endmodule
