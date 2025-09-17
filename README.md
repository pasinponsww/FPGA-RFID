# ESP32 ↔ FPGA UART (SystemVerilog Package)

**Author:** Pasinpon (Bex) Sawetrattanathumrong  
**License:** MIT License © 2025 Bex Sawetrattanathumrong

This repository provides the **FPGA-side SystemVerilog modules** to communicate with an ESP32 over a reliable UART protocol. It
includes authentication, framed messaging, and a simple top-level design ready to drop into your project.

---

## Protocol

**Frame format:**  
[0xAA][TYPE][LEN][PAYLOAD...][CHK]

Where:  
- `CHK = (TYPE + LEN + ΣPAYLOAD) mod 256`

**Frame Types:**  
- **0x10** — UID (ESP32 → FPGA)  
  - `LEN = 4`  
  - Payload = UID (MSB first)  
- **0x21** — Authentication result (FPGA → ESP32)  
  - `LEN = 1`  
  - Payload = `0x01` (grant) or `0x00` (deny)

**Startup behavior:**  
- On reset, FPGA waits for a **UART BREAK** (ESP32 TX held low).  
- After the line returns high, the FPGA transmits a raw **0xA5** byte as a READY signal.

---

## Modules

- **`uart_baud_gen.sv`** — Baud-rate tick generator (bit + 16× oversample)
- **`uart_rx.sv`** — UART receiver (8N1, 16× oversampling)
- **`uart_tx.sv`** — UART transmitter (8N1)
- **`proto_rx.sv`** — Parses incoming frames from ESP32
- **`tx_frame.sv`** — Constructs and transmits reply frames
- **`auth_lut.sv`** — Simple allow-list of authorized UIDs (edit parameters)
- **`fpga_top.sv`** — Top-level design  
  - Parameters:
    - `CLK_FREQ_HZ` — your FPGA clock (default 50 MHz)
    - `BAUD` — UART baud rate (default 115200)
    - `BREAK_BITS` — duration of BREAK signal (default 12 bit-times)
    - `STARTUP_QUIET_MS` — enforced idle period after reset

---

## Authentication Flow

1. ESP32 sends UID frame:  
   `[AA][10][04][UID3][UID2][UID1][UID0][CHK]`
2. FPGA parses UID in `proto_rx.sv`.
3. `auth_lut.sv` checks against allowed list.  
   - Match → `allowed = 1`  
   - No match → `allowed = 0`
4. FPGA replies via `tx_frame.sv`:  
   `[AA][21][01][allowed][CHK]`
   - Example (grant): `AA 21 01 01 23`
   - Example (deny):  `AA 21 01 00 22`

---

## Pinout / Constraints

Edit one of the included constraint files for your board:  
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
2. Set your board’s clock in `fpga_top.sv` (`CLK_FREQ_HZ`).
3. (Optional) Edit `auth_lut.sv` to configure allowed UIDs.
4. Build and program the FPGA.
5. On ESP32:
   - Send a **BREAK** (TX low ≥ `BREAK_BITS`) and then release the line; the FPGA replies with `0xA5`.
   - Send a UID frame → FPGA replies with authentication result.

---

## Timing

- **Baud rate:** 115200 (configurable)
- **RX oversampling:** 16×
- **BREAK detection:** `BREAK_BITS` (default: 12 bit-times)

---

## Notes

- UART idles **high** — ESP32 UART must be **non-inverted**.
- Always connect FPGA and ESP32 **common ground**.
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
