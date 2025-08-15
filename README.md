# ESP32 ↔ FPGA UART (Verilog-only) Package

**Author:** Pasinpon (Bex) Sawetrattanathumrong  
**License:** MIT License © 2025 Bex Sawetrattanathumrong

This package contains everything required on the **FPGA side** to communicate over a simple, reliable UART protocol with an ESP32.

---

## Protocol

Frame format:  
[0xAA][TYPE][LEN][PAYLOAD...][CHK]

Where:  
- `CHK = (TYPE + LEN + ΣPAYLOAD) mod 256`

**Frame Types:**  
- `TYPE = 0x10` — UID (ESP32 → FPGA), `LEN = 4`, payload = UID **MSB first**  
- `TYPE = 0x21` — Auth result (FPGA → ESP32), `LEN = 1`, payload = `0x01` (grant) or `0x00` (deny)  

---

## Modules

- `uart_baud_gen.v` — Generates baud-rate ticks (bit and 16× oversample)  
- `uart_rx.v` — 8N1 UART receiver (16× oversampling)  
- `uart_tx.v` — 8N1 UART transmitter  
- `proto_rx.v` — Parses incoming packets  
- `tx_frame.v` — Constructs and sends packets  
- `auth_lut.v` — Simple allow-list for authorized UIDs (edit parameters to set your list)  
- `fpga_top.v` — Top-level integration; set `CLK_FREQ_HZ` to your board’s frequency  

---

## Pinout / Constraints

Edit one of the included constraint files for your board:  
- **Gowin:** `constraints/tang_nano_example.cst`  
- **Xilinx:** `constraints/generic_xdc_example.xdc`  

I/O Standard: **LVCMOS33** for UART TX/RX and LEDs

**Connections:**  
ESP32.TX → FPGA.uart_rx
ESP32.RX ← FPGA.uart_tx
GND ↔ GND

---

## Quick Start

1. Add all `src/*.v` files and your chosen constraint file to your FPGA project.  
2. Set `CLK_FREQ_HZ` in `fpga_top.v` (default: 50 MHz).  
3. (Optional) Edit `auth_lut.v` to add your allowed UIDs.  
4. Build and program the FPGA.  
5. On ESP32, send a UID frame — FPGA LEDs will indicate **allow/deny** and respond with `TYPE = 0x21`.  

---

## Timing

- **Default baud rate:** 115200 (change in `fpga_top.v` if needed)  
- **Oversampling:** 16× in RX for improved reliability  

---

## Notes

- UART idles **high** — ensure ESP32 UART is **not inverted**.  
- Keep wires short and ensure a **common ground**.  
- If your board uses a non-50 MHz clock (e.g., 27 MHz), update `CLK_FREQ_HZ`.  

---

## License

MIT License  
Copyright © 2025 Bex Sawetrattanathumrong

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

**THE SOFTWARE IS PROVIDED “AS IS”**, WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
OR OTHER DEALINGS IN THE SOFTWARE.
