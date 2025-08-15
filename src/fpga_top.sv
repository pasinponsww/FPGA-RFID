// fpga_top.v  (Verilog-2001 compatible)
// UART with simple packet protocol + auth LUT reply
// Packets: [TYPE][LEN][PAYLOAD...][CHK], CHK = ~(xor of previous bytes)
// TYPE 0x10 (LEN=4) = UID MSB..LSB  (ESP32 → FPGA)
// Reply: TYPE 0x21, LEN=1, payload=0x01 allow / 0x00 deny (FPGA → ESP32)

`timescale 1ns/1ps

module fpga_top
#(
    parameter integer CLK_FREQ_HZ = 50000000, // FPGA clock frequency
    parameter integer BAUD        = 115200    // UART baud rate
)
(
    input  wire clk,
    input  wire rst,
    input  wire uart_rx,
    output wire uart_tx
);


    // Baud generator
    wire tick_x16, tick_bit;

    uart_baud_gen #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD(BAUD),
        .OVERSAMPLE(16)
    ) baud_i (
        .clk(clk),
        .rst(rst),
        .tick_x16(tick_x16), // 16× baud for RX oversampling
        .tick_bit(tick_bit)  // 1× baud for TX
    );

    // UART RX/TX
    // Receiver
    wire [7:0] rxd;       // received byte
    wire       rxv;       // data-valid strobe (1 cycle)
    wire       frame_err; // framing error (unused here)

    uart_rx #(.OVERSAMPLE(16)) urx_i (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .tick_x16(tick_x16),
        .data_out(rxd),
        .data_valid(rxv),
        .framing_err(frame_err)
    );

    // Transmitter
    wire [7:0] txd;    // byte to send
    wire       tx_stb; // strobe to send byte
    wire       tx_busy;

    uart_tx utx_i (
        .clk(clk),
        .rst(rst),
        .data_in(txd),
        .data_strobe(tx_stb),
        .tick_bit(tick_bit),
        .tx(uart_tx),
        .busy(tx_busy)
    );

    // Protocol RX (type/len/payload)
    wire [7:0] pkt_type;  // packet type
    wire [7:0] pkt_len;   // payload length
    wire       pkt_ready; // full packet received
    wire       pkt_bad;   // checksum/format error

    // Packed payload bus from proto_rx (32 bytes max = 256 bits)
    wire [8*32-1:0] payload_bus;

    proto_rx #(.MAX_LEN(32)) prx_i (
        .clk(clk),
        .rst(rst),
        .rx_data(rxd),
        .rx_valid(rxv),
        .pkt_type(pkt_type),
        .pkt_len(pkt_len),
        .pkt_ready(pkt_ready),
        .pkt_bad(pkt_bad),
        .payload_bus(payload_bus)
    );

    // Authentication logic
    localparam [7:0] TYPE_UID  = 8'h10;
    localparam [7:0] TYPE_AUTH = 8'h21;

    reg  [31:0] uid_reg;
    wire        allowed;

    auth_lut #(
        .UID0(32'hDEADBEEF),
        .UID1(32'hA1B2C3D4),
        .UID2(32'hCAFEBABE),
        .UID3(32'h00000000)
    ) auth_i (
        .uid(uid_reg),
        .allowed(allowed)
    );


    // TX Frame builder (packed bus)
    reg        tx_start;            // 1-cycle start pulse
    reg  [7:0] tx_type;
    reg  [7:0] tx_len;
    reg  [8*32-1:0] tx_payload_bus; // only byte 0 used

    tx_frame #(.MAX_LEN(32)) tfrm_i (
        .clk(clk),
        .rst(rst),
        .start(tx_start),
        .type_byte(tx_type),
        .len_byte(tx_len),
        .payload_bus(tx_payload_bus),
        .tx_busy(tx_busy),
        .tx_data(txd),
        .tx_strobe(tx_stb),
        .busy()
    );

    // Control FSM: RX UID → check → TX AUTH result
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            uid_reg   <= 32'd0;
            tx_start  <= 1'b0;
            tx_type   <= 8'd0;
            tx_len    <= 8'd0;
            // clear TX payload byte 0 (bits 255:248)
            tx_payload_bus[8*32-1:8*31] <= 8'd0;
        end else begin
            tx_start <= 1'b0; // one-cycle pulse when sending

            if (pkt_ready && (pkt_type == TYPE_UID) && (pkt_len == 8'd4) && !tx_busy) begin
                // UID bytes MSB..LSB from packed payload bus (MSB-first packing)
                uid_reg <= {
                    payload_bus[8*32-1:8*31], // byte 0 (MSB)   bits 255:248
                    payload_bus[8*31-1:8*30], // byte 1         bits 247:240
                    payload_bus[8*30-1:8*29], // byte 2         bits 239:232
                    payload_bus[8*29-1:8*28]  // byte 3 (LSB)   bits 231:224
                };

                // Build AUTH result frame
                tx_type <= TYPE_AUTH;
                tx_len  <= 8'd1;

                // Put allow/deny into TX payload byte 0 (bits 255:248)
                tx_payload_bus[8*32-1:8*31] <= (allowed ? 8'h01 : 8'h00);

                // Kick off TX frame
                tx_start <= 1'b1;
            end
        end
    end

endmodule
