`timescale 1ns/1ps
// UART Receiver, 8N1, LSB-first
module uart_rx
#( parameter CLKS_PER_BIT = 234 )
(
  input        i_Clock,
  input        i_Rx_Serial,
  output reg   o_Rx_DV = 1'b0,
  output reg [7:0] o_Rx_Byte = 8'h00
);

  localparam s_IDLE         = 3'd0;
  localparam s_RX_START_BIT = 3'd1;
  localparam s_RX_DATA_BITS = 3'd2;
  localparam s_RX_STOP_BIT  = 3'd3;
  localparam s_CLEANUP      = 3'd4;

  reg r_Rx_Data_R = 1'b1;
  reg r_Rx_Data   = 1'b1;

  reg [15:0] r_Clock_Count = 16'd0;
  reg [2:0]  r_Bit_Index   = 3'd0;
  reg [2:0]  r_SM_Main     = s_IDLE;

  always @(posedge i_Clock) begin
    r_Rx_Data_R <= i_Rx_Serial;
  /*
   * UART Receiver (uart_rx)
   * ----------------------
   * 8N1, LSB-first UART receiver module.
   *
   * Parameters:
   *   CLKS_PER_BIT: Number of clock cycles per UART bit (baud rate control)
   *
   * Inputs:
   *   i_Clock    : System clock
   *   i_Rx_Serial: UART RX line
   *
   * Outputs:
   *   o_Rx_DV    : Data valid pulse (1 cycle)
   *   o_Rx_Byte  : Received byte
   */
    r_Rx_Data   <= r_Rx_Data_R;
  end

  always @(posedge i_Clock) begin
    case (r_SM_Main)
      s_IDLE: begin
        o_Rx_DV       <= 1'b0;
        r_Clock_Count <= 0;
        r_Bit_Index   <= 0;
        if (r_Rx_Data == 1'b0)
          r_SM_Main <= s_RX_START_BIT;
      end

      s_RX_START_BIT: begin
        if (r_Clock_Count == ((CLKS_PER_BIT-1)/2)[15:0]) begin
          if (r_Rx_Data == 1'b0) begin
            r_Clock_Count <= 0;
            r_SM_Main     <= s_RX_DATA_BITS;
          end else
            r_SM_Main <= s_IDLE;
        end else
          r_Clock_Count <= r_Clock_Count + 1;
      end

      s_RX_DATA_BITS: begin
        if (r_Clock_Count == (CLKS_PER_BIT-1)[15:0]) begin
          r_Clock_Count          <= 0;
          o_Rx_Byte[r_Bit_Index] <= r_Rx_Data;
          if (r_Bit_Index < 3'd7)
            r_Bit_Index <= r_Bit_Index + 1;
          else begin
            r_Bit_Index <= 0;
            r_SM_Main   <= s_RX_STOP_BIT;
          end
        end else
          r_Clock_Count <= r_Clock_Count + 1;
      end

      s_RX_STOP_BIT: begin
        if (r_Clock_Count == (CLKS_PER_BIT-1)[15:0]) begin
          o_Rx_DV       <= 1'b1;
          r_Clock_Count <= 0;
          r_SM_Main     <= s_CLEANUP;
        end else
          r_Clock_Count <= r_Clock_Count + 1;
      end

      s_CLEANUP: begin
        r_SM_Main <= s_IDLE;
        o_Rx_DV   <= 1'b0;
      end

      default: r_SM_Main <= s_IDLE;
    endcase
  end
endmodule
