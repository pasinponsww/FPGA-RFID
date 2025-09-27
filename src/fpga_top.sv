// fpga_top.v
// -----------------------------------------------------------------------------
// Top-level: Handles commands from ESP32, checks/updates UID LUT, 
// and sends back a 1-byte reply.
// -----------------------------------------------------------------------------

module fpga_top (
    input  wire clk,        // system clock
    input  wire rst_n,      // active-low reset
    input  wire uart_rx,    // UART RX from ESP32
    output wire uart_tx     // UART TX to ESP32
);

    // Command bytes
    localparam CMD_CHECK_UID = 8'hA1;
    localparam CMD_ADD_UID   = 8'hB2;

    // Internal signals
    wire [7:0] rx_data;
    wire       rx_ready;
    reg  [7:0] reply_byte;
    reg        reply_send;

    // UART RX
    uart_rx u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(uart_rx),
        .rx_data(rx_data),
        .rx_ready(rx_ready)
    );

    // UART TX
    wire tx_busy;
    uart_tx u_tx (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(reply_send),
        .tx_data(reply_byte),
        .tx(uart_tx),
        .tx_busy(tx_busy)
    );

    // UID LUT
    wire uid_allowed;
    wire uid_added_ok;
    wire uid_duplicate;
    wire uid_full;

    auth_lut u_lut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd(rx_data),
        .valid(rx_ready),
        .uid_allowed(uid_allowed),
        .uid_added_ok(uid_added_ok),
        .uid_duplicate(uid_duplicate),
        .uid_full(uid_full)
    );

    // Reply logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reply_byte <= 8'h00;
            reply_send <= 1'b0;
        end else begin
            reply_send <= 1'b0; // default
            if (rx_ready && !tx_busy) begin
                case (rx_data)
                    CMD_CHECK_UID: begin
                        reply_byte <= (uid_allowed) ? 8'h01 : 8'h00;
                        reply_send <= 1'b1;
                    end
                    CMD_ADD_UID: begin
                        if (uid_added_ok)
                            reply_byte <= 8'h02;  // added
                        else if (uid_duplicate)
                            reply_byte <= 8'hEE;  // duplicate
                        else if (uid_full)
                            reply_byte <= 8'hEF;  // full/error
                        reply_send <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule
