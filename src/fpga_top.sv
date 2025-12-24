`timescale 1ns/1ps

module fpga_top #(
    parameter integer CLK_HZ            = 27000000,
    parameter integer BAUD_RATE         = 115200,
    parameter integer READY_TIMEOUT_MS  = 10,
    parameter integer RESP_TIMEOUT_MS   = 50,
    parameter [7:0]   MAGIC_BYTE        = 8'hA5,
    parameter [7:0]   READY_BYTE        = 8'h52,
    parameter [7:0]   CRC8_POLY         = 8'h07,
    parameter integer UID_MAX           = 4,
    parameter integer UID_LEN           = 4
)(
    input  wire clk,
    input  wire rst_n,
    input  wire fpga_wake,
    input  wire uart_rx,
    output wire uart_tx
);

    localparam integer CLKS_PER_BIT = (CLK_HZ + (BAUD_RATE/2)) / BAUD_RATE;

    wire [7:0] rx_data;
    wire       rx_ready;
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .i_Clock     (clk),
        .i_Rx_Serial (uart_rx),
        .o_Rx_DV     (rx_ready),
        .o_Rx_Byte   (rx_data)
    );

    reg  [7:0] reply_byte;
    reg        reply_send;
    wire       tx_busy;
    wire       tx_done;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .i_Clock     (clk),
        .i_Tx_DV     (reply_send),
        .i_Tx_Byte   (reply_byte),
        .o_Tx_Active (tx_busy),
        .o_Tx_Serial (uart_tx),
        .o_Tx_Done   (tx_done)
    );

    // ---- auth LUT hookup
    reg  [7:0]          lut_cmd;
    reg                 lut_valid;
    reg  [8*16-1:0]     uid_bytes_flat;
    reg  [7:0]          uid_len_reg;

    wire uid_allowed;
    wire uid_added_ok;
    wire uid_duplicate;
    wire uid_full;

    auth_lut #(
        .UID_MAX(UID_MAX),
        .UID_LEN(UID_LEN)
    ) u_lut (
        .clk            (clk),
        .rst_n          (rst_n),
        .cmd            (lut_cmd),
        .valid          (lut_valid),
        .uid_bytes_flat (uid_bytes_flat),
        .uid_len        (uid_len_reg),
        .uid_allowed    (uid_allowed),
        .uid_added_ok   (uid_added_ok),
        .uid_duplicate  (uid_duplicate),
        .uid_full       (uid_full)
    );

    // ---- FSM
    localparam [3:0]
        ST_IDLE          = 4'd0,
        ST_SEND_READY    = 4'd1,
        ST_WAIT_READY_TX = 4'd2,
        ST_RX_MAGIC      = 4'd3,
        ST_RX_CMD        = 4'd4,
        ST_RX_LEN        = 4'd5,
        ST_RX_PAYLOAD    = 4'd6,
        ST_RX_CRC        = 4'd7,
        ST_LUT_ISSUE     = 4'd8,
        ST_LUT_CAPTURE   = 4'd9,
        ST_SEND_RESULT   = 4'd10,
        ST_WAIT_RESULT_TX= 4'd11,
        ST_WAIT_WAKE_HI  = 4'd12;

    reg [3:0] state;

    reg [7:0] cmd_reg;
    reg [7:0] len_reg;
    reg [7:0] payload_left;
    reg [7:0] payload_idx;

    reg [7:0] crc_reg;
    reg [7:0] crc_next;
    integer   bi;

    localparam integer MS_CYCLES          = (CLK_HZ/1000);
    localparam integer READY_TIMEOUT_CYC  = (READY_TIMEOUT_MS * MS_CYCLES);
    localparam integer RESP_TIMEOUT_CYC   = (RESP_TIMEOUT_MS  * MS_CYCLES);

    reg [31:0] tmo_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            reply_byte     <= 8'h00;
            reply_send     <= 1'b0;

            lut_cmd        <= 8'h00;
            lut_valid      <= 1'b0;
            uid_bytes_flat <= {8*16{1'b0}};
            uid_len_reg    <= 8'h00;

            cmd_reg        <= 8'h00;
            len_reg        <= 8'h00;
            payload_left   <= 8'h00;
            payload_idx    <= 8'h00;

            crc_reg        <= 8'h00;
            tmo_cnt        <= 32'd0;
        end else begin
            reply_send <= 1'b0;
            lut_valid  <= 1'b0;

            if (rx_ready)
                tmo_cnt <= 32'd0;
            else if (state != ST_IDLE)
                tmo_cnt <= tmo_cnt + 32'd1;
            else
                tmo_cnt <= 32'd0;

            if (state != ST_IDLE && fpga_wake) begin
                state <= ST_IDLE;
            end else begin
                case (state)
                    ST_IDLE: begin
                        if (!fpga_wake) begin
                            state      <= ST_SEND_READY;
                            tmo_cnt    <= 32'd0;
                        end
                    end

                    ST_SEND_READY: begin
                        if (!tx_busy) begin
                            reply_byte <= READY_BYTE;
                            reply_send <= 1'b1;
                            state      <= ST_WAIT_READY_TX;
                        end else if (tmo_cnt >= READY_TIMEOUT_CYC) begin
                            state <= ST_WAIT_WAKE_HI;
                        end
                    end

                    ST_WAIT_READY_TX: begin
                        if (tx_done) begin
                            state          <= ST_RX_MAGIC;
                            uid_bytes_flat <= {8*16{1'b0}};
                            crc_reg        <= 8'h00;
                            cmd_reg        <= 8'h00;
                            len_reg        <= 8'h00;
                            payload_left   <= 8'h00;
                            payload_idx    <= 8'h00;
                        end else if (tmo_cnt >= READY_TIMEOUT_CYC) begin
                            state <= ST_WAIT_WAKE_HI;
                        end
                    end

                    ST_RX_MAGIC: begin
                        if (rx_ready) begin
                            if (rx_data == MAGIC_BYTE) begin
                                crc_reg <= 8'h00;
                                state   <= ST_RX_CMD;
                            end
                        end else if (tmo_cnt >= RESP_TIMEOUT_CYC) begin
                            state <= ST_WAIT_WAKE_HI;
                        end
                    end

                    ST_RX_CMD: begin
                        if (rx_ready) begin
                            cmd_reg <= rx_data;

                            crc_next = (crc_reg ^ rx_data);
                            for (bi = 0; bi < 8; bi = bi + 1) begin
                                if (crc_next[7])
                                    crc_next = {crc_next[6:0], 1'b0} ^ CRC8_POLY;
                                else
                                    crc_next = {crc_next[6:0], 1'b0};
                            end
                            crc_reg <= crc_next;

                            state <= ST_RX_LEN;
                        end else if (tmo_cnt >= RESP_TIMEOUT_CYC) begin
                            state <= ST_SEND_RESULT;
                            reply_byte <= 8'hEF;
                        end
                    end

                    ST_RX_LEN: begin
                        if (rx_ready) begin
                            len_reg      <= rx_data;
                            uid_len_reg  <= rx_data;
                            payload_left <= rx_data;
                            payload_idx  <= 8'd0;
                            uid_bytes_flat <= {8*16{1'b0}};

                            crc_next = (crc_reg ^ rx_data);
                            for (bi = 0; bi < 8; bi = bi + 1) begin
                                if (crc_next[7])
                                    crc_next = {crc_next[6:0], 1'b0} ^ CRC8_POLY;
                                else
                                    crc_next = {crc_next[6:0], 1'b0};
                            end
                            crc_reg <= crc_next;

                            if (rx_data == 8'd0)
                                state <= ST_RX_CRC;
                            else
                                state <= ST_RX_PAYLOAD;
                        end else if (tmo_cnt >= RESP_TIMEOUT_CYC) begin
                            state <= ST_SEND_RESULT;
                            reply_byte <= 8'hEF;
                        end
                    end

                    ST_RX_PAYLOAD: begin
                        if (rx_ready) begin
                            if (payload_idx < 8'd16) begin
                                uid_bytes_flat[payload_idx*8 +: 8] <= rx_data;
                            end

                            crc_next = (crc_reg ^ rx_data);
                            for (bi = 0; bi < 8; bi = bi + 1) begin
                                if (crc_next[7])
                                    crc_next = {crc_next[6:0], 1'b0} ^ CRC8_POLY;
                                else
                                    crc_next = {crc_next[6:0], 1'b0};
                            end
                            crc_reg <= crc_next;

                            payload_idx  <= payload_idx + 8'd1;
                            payload_left <= payload_left - 8'd1;

                            if (payload_left == 8'd1)
                                state <= ST_RX_CRC;
                        end else if (tmo_cnt >= RESP_TIMEOUT_CYC) begin
                            state <= ST_SEND_RESULT;
                            reply_byte <= 8'hEF;
                        end
                    end

                    ST_RX_CRC: begin
                        if (rx_ready) begin
                            if (rx_data == crc_reg) begin
                                lut_cmd   <= cmd_reg;
                                lut_valid <= 1'b1;
                                state     <= ST_LUT_CAPTURE;
                            end else begin
                                reply_byte <= 8'hEF;
                                state      <= ST_SEND_RESULT;
                            end
                        end else if (tmo_cnt >= RESP_TIMEOUT_CYC) begin
                            state <= ST_SEND_RESULT;
                            reply_byte <= 8'hEF;
                        end
                    end

                    ST_LUT_CAPTURE: begin
                        if (cmd_reg == 8'h10) begin
                            reply_byte <= uid_allowed ? 8'h01 : 8'h00;
                        end else if (cmd_reg == 8'h11) begin
                            if (uid_added_ok)
                                reply_byte <= 8'h02;
                            else if (uid_duplicate)
                                reply_byte <= 8'hEE;
                            else if (uid_full)
                                reply_byte <= 8'hEF;
                            else
                                reply_byte <= 8'hEF;
                        end else begin
                            reply_byte <= 8'hEF;
                        end
                        state <= ST_SEND_RESULT;
                    end

                    ST_SEND_RESULT: begin
                        if (!tx_busy) begin
                            reply_send <= 1'b1;
                            state      <= ST_WAIT_RESULT_TX;
                        end else if (tmo_cnt >= RESP_TIMEOUT_CYC) begin
                            state <= ST_WAIT_WAKE_HI;
                        end
                    end

                    ST_WAIT_RESULT_TX: begin
                        if (tx_done) begin
                            state <= ST_WAIT_WAKE_HI;
                        end else if (tmo_cnt >= RESP_TIMEOUT_CYC) begin
                            state <= ST_WAIT_WAKE_HI;
                        end
                    end

                    ST_WAIT_WAKE_HI: begin
                        if (fpga_wake)
                            state <= ST_IDLE;
                    end

                    default: begin
                        state <= ST_IDLE;
                    end
                endcase
            end
        end
    end

endmodule
