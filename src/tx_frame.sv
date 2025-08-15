// tx_frame.v
// Emits a frame: [0xAA][TYPE][LEN][PAYLOAD...][CHK]
`timescale 1ns/1ps
module tx_frame #(
    parameter integer MAX_LEN = 32
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       start,          // pulse to begin sending this frame
    input  wire [7:0] type_byte,
    input  wire [7:0] len_byte,
    input  wire [8*MAX_LEN-1:0] payload_bus,  
    // UART
    input  wire       tx_busy,
    output reg  [7:0] tx_data,
    output reg        tx_strobe,
    output reg        busy
);
    localparam [2:0] T_IDLE = 3'd0,
                     T_SOF  = 3'd1,
                     T_TYPE = 3'd2,
                     T_LEN  = 3'd3,
                     T_PAY  = 3'd4,
                     T_CHK  = 3'd5,
                     T_END  = 3'd6;

    localparam [7:0] SOF = 8'hAA;
    reg [2:0] state;
    reg [7:0] idx;
    reg [7:0] sum;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= T_IDLE; idx <= 8'd0; sum <= 8'd0; busy <= 1'b0;
            tx_strobe <= 1'b0; tx_data <= 8'd0;
        end else begin
            tx_strobe <= 1'b0;
            case (state)
                T_IDLE: begin
                    if (start) begin
                        busy <= 1'b1;
                        sum <= 8'd0;
                        idx <= 8'd0;
                        state <= T_SOF;
                    end
                end
                T_SOF:  if (!tx_busy) begin tx_data <= SOF; tx_strobe <= 1'b1; state <= T_TYPE; end
                T_TYPE: if (!tx_busy) begin tx_data <= type_byte; tx_strobe <= 1'b1; sum <= type_byte; state <= T_LEN; end
                T_LEN:  if (!tx_busy) begin tx_data <= len_byte;  tx_strobe <= 1'b1; sum <= sum + len_byte; state <= (len_byte==0)?T_CHK:T_PAY; end
                T_PAY:  if (!tx_busy) begin
                            tx_data <= payload_bus[idx]; tx_strobe <= 1'b1; sum <= sum + payload_bus[idx];
                            idx <= idx + 1'b1;
                            if (idx + 1 == len_byte) state <= T_CHK;
                        end
                T_CHK:  if (!tx_busy) begin tx_data <= sum; tx_strobe <= 1'b1; state <= T_END; end
                T_END:  if (!tx_busy) begin busy <= 1'b0; state <= T_IDLE; end
            endcase
        end
    end
endmodule
