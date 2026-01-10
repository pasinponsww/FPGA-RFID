# FPGA-RFID Project

This project implements an FPGA-based RFID system. All source files are located in the `src/` directory.

## Directory Structure

```
src/
  auth_lut.sv        # Authentication lookup table module
  constrait.cst      # Constraints file for FPGA synthesis
  fpga_top.sv        # Top-level module for the FPGA design
  uart_rx.sv         # UART receiver module
  uart_tx.sv         # UART transmitter module
```

## Quick Start

1. **Clone the repository:**
   ```sh
   git clone <repo-url>
   cd FPGA-RFID
   ```
2. **Open the `src/` directory** in your FPGA development environment.
3. **Synthesize and program** the design using your preferred FPGA toolchain, referencing `src/constrait.cst` for constraints.

## File Descriptions

- **auth_lut.sv**: Implements the authentication lookup table for RFID tags.
- **constrait.cst**: Contains pin and timing constraints for the FPGA board.
- **fpga_top.sv**: The top-level module that integrates all submodules.
- **uart_rx.sv**: UART receiver logic for serial communication.
- **uart_tx.sv**: UART transmitter logic for serial communication.

## Usage

- Modify or extend the modules in `src/` as needed for your application.
- Ensure your FPGA board matches the constraints in `src/constrait.cst`.

