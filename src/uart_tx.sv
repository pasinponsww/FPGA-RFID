`timescale 1ns/1ps
// UART Transmitter, 8N1, LSB-first
module uart_tx
#( parameter CLKS_PER_BIT = 234 )
(
  input        i_Clock,
  input        i_Tx_DV,           // strobe: load i_Tx_Byte and start
  input  [7:0] i_Tx_Byte,
  output reg   o_Tx_Active = 1'b0,
  output reg   o_Tx_Serial = 1'b1, // idle high
  output reg   o_Tx_Done   = 1'b0
);

  localparam s_IDLE         = 3'd0;
  localparam s_TX_START_BIT = 3'd1;
  localparam s_TX_DATA_BITS = 3'd2;
  localparam s_TX_STOP_BIT  = 3'd3;
  localparam s_CLEANUP      = 3'd4;

  reg [2:0]  r_SM_Main     = s_IDLE;
  reg [15:0] r_Clock_Count = 16'd0;
  reg [2:0]  r_Bit_Index   = 3'd0; // 8 bits
  reg [7:0]  r_Tx_Data     = 8'h00;

  always @(posedge i_Clock) begin
    o_Tx_Done <= 1'b0;

    case (r_SM_Main)
      s_IDLE: begin
        o_Tx_Serial  <= 1'b1;
        o_Tx_Active  <= 1'b0;
        r_Clock_Count<= 16'd0;
        r_Bit_Index  <= 3'd0;

        if (i_Tx_DV) begin
          r_Tx_Data  <= i_Tx_Byte;
          o_Tx_Active<= 1'b1;
          r_SM_Main  <= s_TX_START_BIT;
        end
      end

      s_TX_START_BIT: begin
        o_Tx_Serial <= 1'b0; // start bit
        if (r_Clock_Count == CLKS_PER_BIT-1) begin
          r_Clock_Count <= 16'd0;
          r_SM_Main     <= s_TX_DATA_BITS;
        end else
          r_Clock_Count <= r_Clock_Count + 16'd1;
      end

      s_TX_DATA_BITS: begin
        o_Tx_Serial <= r_Tx_Data[r_Bit_Index];
        if (r_Clock_Count == CLKS_PER_BIT-1) begin
          r_Clock_Count <= 16'd0;
          if (r_Bit_Index < 3'd7)
            r_Bit_Index <= r_Bit_Index + 3'd1;
          else begin
            r_Bit_Index <= 3'd0;
            r_SM_Main   <= s_TX_STOP_BIT;
          end
        end else
          r_Clock_Count <= r_Clock_Count + 16'd1;
      end

      s_TX_STOP_BIT: begin
        o_Tx_Serial <= 1'b1; // stop bit
        if (r_Clock_Count == CLKS_PER_BIT-1) begin
          r_Clock_Count <= 16'd0;
          o_Tx_Done     <= 1'b1;
          o_Tx_Active   <= 1'b0;
          r_SM_Main     <= s_CLEANUP;
        end else
          r_Clock_Count <= r_Clock_Count + 16'd1;
      end

      s_CLEANUP: begin
        r_SM_Main <= s_IDLE;
      end

      default: r_SM_Main <= s_IDLE;
    endcase
  end
endmodule
