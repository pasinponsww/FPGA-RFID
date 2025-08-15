// proto_rx.sv
// Parses frames: [0xAA][TYPE][LEN][PAYLOAD...LEN][CHK = sum(TYPE+LEN+PAYLOAD) mod 256]
// Produces pkt_ready pulse and exposes type/len/payload as a packed bus.
`timescale 1ns/1ps
module proto_rx #(
    parameter integer MAX_LEN = 32
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] rx_data,
    input  wire       rx_valid,
    output reg  [7:0] pkt_type,
    output reg  [7:0] pkt_len,
    output reg        pkt_ready,
    output reg        pkt_bad,
    output reg  [8*MAX_LEN-1:0] payload_bus   // reg: assigned in always
);
    localparam [2:0] S_WAIT = 3'd0,
                     S_TYPE = 3'd1,
                     S_LEN  = 3'd2,
                     S_PAY  = 3'd3,
                     S_CHK  = 3'd4;

    localparam [7:0] SOF = 8'hAA;

    reg [2:0] state;
    reg [7:0] sum;
    reg [7:0] idx;

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= S_WAIT;
            pkt_ready  <= 1'b0;
            pkt_bad    <= 1'b0;
            sum        <= 8'd0;
            idx        <= 8'd0;
            pkt_type   <= 8'd0;
            pkt_len    <= 8'd0;
            payload_bus<= {8*MAX_LEN{1'b0}};   // clear payload on reset
        end else begin
            pkt_ready <= 1'b0;
            pkt_bad   <= 1'b0;
            if (rx_valid) begin
                case (state)
                    S_WAIT: begin
                        if (rx_data == SOF) begin
                            state <= S_TYPE;
                        end
                    end

                    S_TYPE: begin
                        pkt_type <= rx_data;
                        sum      <= rx_data;
                        state    <= S_LEN;
                    end

                    S_LEN: begin
                        pkt_len <= rx_data;
                        sum     <= sum + rx_data;
                        if (rx_data == 8'd0 || rx_data > MAX_LEN) begin
                            // invalid length → drop
                            pkt_bad <= 1'b1;
                            state   <= S_WAIT;
                        end else begin
                            idx         <= 8'd0;
                            payload_bus <= {8*MAX_LEN{1'b0}}; // clear before fill
                            state       <= S_PAY;
                        end
                    end

                    S_PAY: begin
                        // store byte at index idx (MSB-first packing)
                        payload_bus[8*(MAX_LEN-1-idx) +: 8] <= rx_data;
                        sum <= sum + rx_data;
                        idx <= idx + 1'b1;
                        if (idx + 1 == pkt_len) begin
                            state <= S_CHK;
                        end
                    end

                    S_CHK: begin
                        if (sum == rx_data) begin
                            pkt_ready <= 1'b1;
                        end else begin
                            pkt_bad   <= 1'b1;
                        end
                        state <= S_WAIT;
                    end
                endcase
            end
        end
    end
endmodule
