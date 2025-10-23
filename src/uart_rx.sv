`timescale 1ns/1ps
// UART Receiver, 8N1, LSB-first
module uart_rx
#( parameter CLKS_PER_BIT = 87 )
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
  reg [2:0]  r_Bit_Index   = 3'd0; // 8 bits
  reg [2:0]  r_SM_Main     = s_IDLE;

  // Double-flop to avoid metastability
  always @(posedge i_Clock) begin
    r_Rx_Data_R <= i_Rx_Serial;
    r_Rx_Data   <= r_Rx_Data_R;
  end

  always @(posedge i_Clock) begin
    case (r_SM_Main)
      s_IDLE: begin
        o_Rx_DV       <= 1'b0;
        r_Clock_Count <= 0;
        r_Bit_Index   <= 0;

        if (r_Rx_Data == 1'b0) // start bit
          r_SM_Main <= s_RX_START_BIT;
      end

      // sample middle of start bit
      s_RX_START_BIT: begin
        if (r_Clock_Count == (CLKS_PER_BIT-1)/2) begin
          if (r_Rx_Data == 1'b0) begin
            r_Clock_Count <= 0;
            r_SM_Main     <= s_RX_DATA_BITS;
          end else begin
            r_SM_Main <= s_IDLE; // false start
          end
        end else begin
          r_Clock_Count <= r_Clock_Count + 1;
        end
      end

      s_RX_DATA_BITS: begin
        if (r_Clock_Count == CLKS_PER_BIT-1) begin
          r_Clock_Count            <= 0;
          o_Rx_Byte[r_Bit_Index]   <= r_Rx_Data; // LSB first
          if (r_Bit_Index < 3'd7) begin
            r_Bit_Index <= r_Bit_Index + 1;
          end else begin
            r_Bit_Index <= 0;
            r_SM_Main   <= s_RX_STOP_BIT;
          end
        end else begin
          r_Clock_Count <= r_Clock_Count + 1;
        end
      end

      s_RX_STOP_BIT: begin
        if (r_Clock_Count == CLKS_PER_BIT-1) begin
          o_Rx_DV       <= 1'b1;   // one-cycle data valid
          r_Clock_Count <= 0;
          r_SM_Main     <= s_CLEANUP;
        end else begin
          r_Clock_Count <= r_Clock_Count + 1;
        end
      end

      s_CLEANUP: begin
        r_SM_Main <= s_IDLE;
        o_Rx_DV   <= 1'b0;
      end

      default: r_SM_Main <= s_IDLE;
    endcase
  end
endmodule
