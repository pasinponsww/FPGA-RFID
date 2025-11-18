# ESP32 ↔ FPGA UART (SystemVerilog)

Lightweight SystemVerilog modules for UART communication between an ESP32 and an FPGA. 
Includes framing, authentication, and a clean top-level design.

## Features
- UART transmit and receive modules
- Framed message handling
- Simple authentication lookup
- Drop-in top module

## Modules
- uart_baud_gen.sv
- uart_rx.sv
- uart_tx.sv
- proto_rx.sv
- tx_frame.sv
- auth_lut.sv
- fpga_top.sv

## Overview
1. ESP32 sends a framed message
2. FPGA parses the frame
3. Authentication module checks the UID
4. FPGA sends a response frame back

## Wiring
- ESP32 TX → FPGA RX
- ESP32 RX ← FPGA TX
- Common ground required

## Quick Start
1. Add all .sv files to your FPGA project
2. Set your FPGA clock in the top module
3. Adjust authentication entries if needed
4. Build and program the FPGA
5. Send a framed message from the ESP32 to test