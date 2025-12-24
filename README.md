# FPGA-RFID
A SystemVerilog-based RFID authentication system for FPGA implementation with UART communication protocol for ESP32 integration.

## Overview
This project implements a complete RFGA-side RFID access control system using SystemVerilog. It handles UART communication with an ESP32 microcontroller, processes RFID UIDs, performs authentication lookups, and sends approval/denial responses back to the ESP32.

## Features
- **UART Communication**: Full-duplex UART TX/RX modules with configurable baud rate
- **Framed Protocol**: Custom protocol with magic bytes, CRC8 validation, and structured frames
- **UID Authentication**: In-FPGA lookup table for storing and validating RFID UIDs
- **Dynamic UID Management**: Add new UIDs, check for duplicates, and handle memory constraints
- **Low-Latency Response**: Hardware-based authentication for fast access control decisions
- **Configurable Parameters**: Clock frequency, baud rate, timeout settings, and UID storage capacity

## Hardware Requirements
- FPGA Development Board (Gowin FPGA recommended)
- ESP32 Development Board (for RFID reading)
- UART connection between ESP32 and FPGA
- Common ground connection
- Power supply (3.3V or 5V depending on board specifications)

## Software Requirements

### Toolchain
- **Gowin EDA** - FPGA synthesis and programming tool
  - Gowin IDE or Gowin Programmer
  - SystemVerilog support
- **UART Terminal** (for debugging)
  - PuTTY, Tera Term, or similar

### Dependencies
- SystemVerilog-compatible synthesis tool
- UART interface on target FPGA

## Project Structure
```
FPGA-RFID/
├── src/
│   ├── fpga_top.sv        # Top-level module with system integration
│   ├── uart_rx.sv         # UART receiver (8N1, LSB-first)
│   ├── uart_tx.sv         # UART transmitter (8N1, LSB-first)
│   ├── auth_lut.sv        # Authentication lookup table for UID validation
│   ├── proto_rx.sv        # Protocol receiver with frame parsing
│   └── tx_frame.sv        # Frame transmitter with CRC generation
└── README.md              # This file
```

## Module Descriptions

### `fpga_top.sv`
Top-level module that: 
- Instantiates UART TX/RX modules
- Manages power-on reset (POR)
- Interfaces with authentication lookup table
- Handles protocol state machine
- Configurable clock frequency and baud rate

**Key Parameters:**
- `CLK_HZ`: System clock frequency (default: 27 MHz)
- `BAUD_RATE`: UART baud rate (default: 115200)
- `UID_MAX`: Maximum number of stored UIDs (default: 4)
- `UID_LEN`: Length of each UID in bytes (default: 4)

### `uart_rx.sv` & `uart_tx.sv`
Standard 8N1 UART implementation:
- LSB-first transmission
- Configurable `CLKS_PER_BIT` parameter
- Ready/Done signaling
- Double-registered input for metastability protection (RX)

### `auth_lut.sv`
Authentication lookup table supporting:
- **CMD_CHECK_UID (0x10)**: Validate if UID is authorized
- **CMD_ADD_UID (0x11)**: Add new UID to memory
- Duplicate detection
- Memory full detection
- Configurable UID storage capacity

## Configuration

### Pin Assignment
Configure your FPGA pin constraints file (`.cst` for Gowin) with:
```
IO_LOC "uart_rx" <RX_PIN>;
IO_LOC "uart_tx" <TX_PIN>;
IO_LOC "clk" <CLOCK_PIN>;
IO_LOC "fpga_wake" <WAKE_PIN>;
```

### Parameter Customization
Edit `fpga_top.sv` to adjust:
```systemverilog
parameter integer CLK_HZ = 27000000;    // Match your FPGA clock
parameter integer BAUD_RATE = 115200;   // Match ESP32 baud rate
parameter integer UID_MAX = 4;          // Max authorized UIDs
parameter integer UID_LEN = 4;          // Bytes per UID
```

## Build Instructions

### Using Gowin IDE

1. **Create New Project**
   ```
   File → New → FPGA Design Project
   ```

2. **Add Source Files**
   - Add all `.sv` files from `src/` directory
   - Set `fpga_top.sv` as the top module

3. **Set Device**
   - Select your Gowin FPGA part number
   - Configure device settings

4. **Synthesize**
   ```
   Project → Run Synthesis
   ```

5. **Place & Route**
   ```
   Project → Run Place & Route
   ```

6. **Program FPGA**
   ```
   Project → Configuration → Program Device
   ```

### Using Command Line (Gowin)
```bash
# Synthesize
gw_sh -tcl synthesis.tcl

# Place and route
gw_sh -tcl pnr.tcl

# Generate bitstream
gw_sh -tcl bitstream.tcl

# Program device
programmer_cli --device <device> --cable <cable> --file <bitstream. fs>
```

## Communication Protocol

### Frame Structure
```
[MAGIC_BYTE] [CMD] [UID_LEN] [UID_BYTES... ] [CRC8]
```

- **MAGIC_BYTE**: Frame start delimiter (default: 0xA5)
- **CMD**: Command byte
  - `0x10`: Check UID authentication
  - `0x11`: Add new UID
- **UID_LEN**: Number of UID bytes (1-16)
- **UID_BYTES**:  Actual UID data
- **CRC8**:  Checksum using polynomial 0x07

### Response Codes
- `0x01`: UID Approved/Added Successfully
- `0x00`: UID Denied/Error
- `0x52`: Ready signal

## Usage

1. **Power on FPGA** and wait for power-on reset completion
2. **Connect ESP32** via UART (TX→RX, RX→TX, GND→GND)
3. **ESP32 sends** framed RFID UID data
4. **FPGA processes** the frame and checks authentication
5. **FPGA responds** with approval/denial byte
6. **ESP32 displays** result on LCD or serial monitor

## Integration with ESP32

This FPGA project is designed to work with an ESP32-based RFID reader system. Check out the companion ESP32 project for the complete access control solution: 

👉 **[ESP32-RFID by joe3925](https://github.com/joe3925/ESP32-RFID)** - ESP32 code with PN532 NFC reader, LCD display, and FPGA communication

## Wiring Diagram
```
ESP32 (TX2) ──────► FPGA (uart_rx)
ESP32 (RX2) ◄────── FPGA (uart_tx)
ESP32 (GND) ──────── FPGA (GND)
```

## Troubleshooting

### No UART Communication
- Verify baud rate matches on both sides
- Check TX/RX connections (crossover:  TX→RX)
- Confirm common ground connection
- Verify FPGA clock frequency parameter

### Authentication Always Fails
- Check UID_LEN parameter matches actual UID length
- Verify CRC8 calculation on ESP32 side
- Use logic analyzer to inspect UART frames
- Check that UIDs have been added to lookup table

### Synthesis Errors
- Ensure all `.sv` files are included
- Verify SystemVerilog support is enabled
- Check for parameter compatibility with your FPGA

## Authors
- **pasinponsww** - FPGA implementation
- **joe3925** - ESP32 integration

## License
This project is open source.  Feel free to use and modify. 

## Related Projects
- [ESP32-RFID](https://github.com/joe3925/ESP32-RFID) - ESP32 RFID reader with FPGA communication