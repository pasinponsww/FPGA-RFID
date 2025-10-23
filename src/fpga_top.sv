`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Top-level: Parses full ESP32 frame, checks/updates UID LUT,
// and sends back a 1-byte reply.
// -----------------------------------------------------------------------------

module fpga_top (
    input  wire clk,        // system clock
    input  wire rst_n,      // active-low reset
    input  wire uart_rx,    // UART RX from ESP32
    output wire uart_tx     // UART TX to ESP32
);

    // ---- Protocol constants
    localparam FRAME_MAGIC   = 8'hA5;
    localparam CMD_CHECK_UID = 8'h10;
    localparam CMD_ADD_UID   = 8'h11;

    // ---- UART timing (115200 baud)
    // For 50 MHz clock use 434; for 10 MHz use 87.
    localparam integer CLKS_PER_BIT = 434;  // <<< adjust if your clk != 50 MHz

    // ---- UART RX
    wire [7:0] rx_data;
    wire       rx_ready;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .i_Clock    (clk),
        .i_Rx_Serial(uart_rx),
        .o_Rx_DV    (rx_ready),
        .o_Rx_Byte  (rx_data)
    );

    // ---- UART TX
    reg  [7:0] reply_byte;
    reg        reply_send;
    wire       tx_busy;
    wire       tx_done;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .i_Clock    (clk),
        .i_Tx_DV    (reply_send),
        .i_Tx_Byte  (reply_byte),
        .o_Tx_Active(tx_busy),
        .o_Tx_Serial(uart_tx),
        .o_Tx_Done  (tx_done)
    );

    // ---- UID LUT signals (dummy for now)
    reg        cmd_valid;
    reg  [7:0] cmd_code;
    reg  [7:0] uid_mem [0:15];
    reg  [7:0] uid_len;

    wire uid_allowed;
    wire uid_added_ok;
    wire uid_duplicate;
    wire uid_full;

    auth_lut u_lut (
        .clk          (clk),
        .rst_n        (rst_n),
        .cmd          (cmd_code),
        .valid        (cmd_valid),
        .uid_allowed  (uid_allowed),
        .uid_added_ok (uid_added_ok),
        .uid_duplicate(uid_duplicate),
        .uid_full     (uid_full)
    );

    // ---- Frame parser FSM
    localparam S_IDLE     = 3'd0;
    localparam S_CMD      = 3'd1;
    localparam S_LEN      = 3'd2;
    localparam S_PAYLOAD  = 3'd3;
    localparam S_CRC      = 3'd4;
    localparam S_EVAL     = 3'd5;
    localparam S_DECIDE   = 3'd6;   // <<< NEW: one-cycle delay for LUT outputs
    // we'll reuse the transmit wait using S_IDLE entry with reply_send pulse

    reg [2:0] state;

    reg [7:0] crc_calc, crc_recv;
    reg [7:0] payload_count;

    // Simple XOR CRC placeholder
    function [7:0] crc8_simple;
        input [7:0] acc;
        input [7:0] d;
        begin
            crc8_simple = acc ^ d;
        end
    endfunction

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            reply_byte    <= 8'h00;
            reply_send    <= 1'b0;
            cmd_valid     <= 1'b0;
            cmd_code      <= 8'h00;
            uid_len       <= 8'h00;
            payload_count <= 8'h00;
            crc_calc      <= 8'h00;
            crc_recv      <= 8'h00;
            for (i=0; i<16; i=i+1) uid_mem[i] <= 8'h00;
        end else begin
            // default deasserts
            reply_send <= 1'b0;
            cmd_valid  <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (rx_ready && rx_data == FRAME_MAGIC) begin
                        crc_calc      <= 8'h00;
                        payload_count <= 8'h00;
                        state         <= S_CMD;
                    end
                end

                S_CMD: begin
                    if (rx_ready) begin
                        cmd_code <= rx_data;
                        crc_calc <= crc8_simple(crc_calc, rx_data);
                        state    <= S_LEN;
                    end
                end

                S_LEN: begin
                    if (rx_ready) begin
                        uid_len  <= rx_data;
                        crc_calc <= crc8_simple(crc_calc, rx_data);
                        payload_count <= 8'h00;
                        if (rx_data == 8'h00)
                            state <= S_CRC;
                        else
                            state <= S_PAYLOAD;
                    end
                end

                S_PAYLOAD: begin
                    if (rx_ready) begin
                        uid_mem[payload_count] <= rx_data;
                        crc_calc               <= crc8_simple(crc_calc, rx_data);
                        payload_count          <= payload_count + 1'b1;
                        if (payload_count + 1'b1 == uid_len)
                            state <= S_CRC;
                    end
                end

                S_CRC: begin
                    if (rx_ready) begin
                        crc_recv <= rx_data;
                        state    <= S_EVAL;
                    end
                end

                S_EVAL: begin
                    if (crc_recv == crc_calc) begin
                        // Kick the LUT, but DON'T read outputs yet
                        cmd_valid <= 1'b1;
                        state     <= S_DECIDE;  // <<< wait one clock
                    end else begin
                        reply_byte <= 8'hFE; // CRC error
                        // send immediately
                        if (!tx_busy) begin
                            reply_send <= 1'b1;
                            state      <= S_IDLE;
                        end
                    end
                end

                // NEW stage: LUT outputs (uid_allowed, uid_added_ok, etc.) are valid now
                S_DECIDE: begin
                    case (cmd_code)
                        CMD_CHECK_UID: reply_byte <= (uid_allowed) ? 8'h01 : 8'h00;
                        CMD_ADD_UID:   reply_byte <= (uid_added_ok) ? 8'h02 :
                                                     (uid_duplicate) ? 8'hEE :
                                                     (uid_full)      ? 8'hEF : 8'hEF;
                        default:       reply_byte <= 8'hFF;
                    endcase
                    // arm TX when free
                    if (!tx_busy) begin
                        reply_send <= 1'b1; // 1-cycle strobe
                        state      <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
