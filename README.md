# ESP32 ↔ FPGA UART (SystemVerilog Package)

**Author:** Pasinpon (Bex) Sawetrattanathumrong  
**License:** MIT License © 2025 Bex Sawetrattanathumrong  

This repository contains the **FPGA-side SystemVerilog modules** required to communicate with an ESP32 over a reliable UART protocol. It includes a top-level design and all supporting modules.  

---

## Protocol

**Frame format:**  
[0xAA][TYPE][LEN][PAYLOAD...][CHK]

Where:  
- `CHK = (TYPE + LEN + ΣPAYLOAD) mod 256`

**Defined Frame Types:**  
- `0x10` — UID (ESP32 → FPGA)  
  - `LEN = 4`  
  - Payload = UID (MSB first)  
- `0x21` — Authentication result (FPGA → ESP32)  
  - `LEN = 1`  
  - Payload = `0x01` (grant) or `0x00` (deny)  

**Startup behavior:**  
- On reset, FPGA waits for a **UART BREAK** (TX held low).  
- Once detected, FPGA replies with a raw `0x52` (`'R'` = READY).  

---

## Modules

- **`uart_baud_gen.sv`** — Baud-rate tick generator (bit + 16× oversample)  
- **`uart_rx.sv`** — UART receiver (8N1, 16× oversampling)  
- **`uart_tx.sv`** — UART transmitter (8N1)  
- **`proto_rx.sv`** — Packet/frame parser  
- **`tx_frame.sv`** — Frame builder and transmitter  
- **`auth_lut.sv`** — Authentication lookup table for UID allow-list (edit params)  
- **`fpga_top.sv`** — Top-level design  
  - Parameters: `CLK_FREQ_HZ`, `BAUD`, `BREAK_BITS`, `STARTUP_QUIET_MS`  
  - Handles BREAK detection, READY byte, and auth responses  

---

## Pinout / Constraints

Use the included example constraint files for your board:  
- **Gowin:** `constraints/tang_nano_example.cst`  
- **Xilinx:** `constraints/generic_xdc_example.xdc`  

**Connections:**  

ESP32 TX → FPGA uart_rx
ESP32 RX ← FPGA uart_tx
GND ↔ GND


Electrical:  
- IO Standard = **LVCMOS33**  
- No pull resistors required  

---

## Quick Start

1. Add all `*.sv` files and a constraint file to your FPGA project.  
2. Set your board’s clock frequency in `fpga_top.sv` (`CLK_FREQ_HZ`).  
3. (Optional) Edit `auth_lut.sv` to define allowed UIDs.  
4. Build + program the FPGA.  
5. On ESP32:  
   - Hold TX low briefly (BREAK) → FPGA responds with `0x52 (R)`  
   - Send a UID frame → FPGA replies with auth result frame.  

---

## Timing

- **Baud rate:** 115200 (default, configurable)  
- **RX oversampling:** 16×  
- **BREAK length:** Configurable via `BREAK_BITS` (default: 12 bit-times)  

---

## Notes

- UART idles **high** — ESP32 UART must be **non-inverted**.  
- Ensure **common ground** between FPGA and ESP32.  
- Update `CLK_FREQ_HZ` if your FPGA clock ≠ 50 MHz (e.g., 27 MHz Tang Nano).  

---

## License

MIT License © 2025 Bex Sawetrattanathumrong  

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
