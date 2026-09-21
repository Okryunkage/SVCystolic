<h1 align="center">SVC Lab Neural Processing Project</h1>

<p align="center">
  Neural-network accelerators, RTL designs, and FPGA implementations
</p>

---

## Overview

This repository contains neural-network models, RTL implementations, hardware
accelerators, and FPGA projects developed by the **SVC Lab**.

The project includes systolic-array architectures, UART communication modules,
ring oscillator–based true random number generators, and neural-network
accelerators intended for simulation and FPGA implementation.

## Repository Structure

```text
.
├── systolic/   # Proposed systolic-array design
├── uart/       # UART modules for FPGA testing
├── RO-TRNG/    # Ring oscillator–based true random number generator
├── NNmodel/    # Neural-network models and RTL implementations
└── FPGA/       # FPGA projects, constraints, and implementation files
```

| Directory | Description |
|---|---|
| `systolic/` | Proposed systolic-array architecture and related design files |
| `uart/` | UART modules used to test the proposed designs on FPGA hardware |
| `RO-TRNG/` | Ring Oscillator–based True Random Number Generator design |
| `NNmodel/` | Neural-network models, parameter export tools, and RTL implementations |
| `FPGA/` | FPGA project files, constraints, synthesis, and implementation resources |

## Requirements

### Simulation and synthesis tools

- [Icarus Verilog](https://steveicarus.github.io/iverilog/)
- [Verilator](https://www.veripool.org/verilator/)
- [Yosys](https://yosyshq.net/yosys/)
- [AMD Vivado Design Suite](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado.html)

> [!NOTE]
> AMD Vivado is required for FPGA synthesis, implementation, bitstream
> generation, and on-board testing.

## FPGA Platforms

### Nexys A7-100T

| Property | Value |
|---|---|
| FPGA family | AMD Artix-7 |
| Device | `XC7A100T-1CSG324` |
| Development environment | AMD Vivado Design Suite |

### AXKU062

| Property | Value |
|---|---|
| FPGA family | AMD Kintex UltraScale |
| Device | `XCKU060-2FFVA1156I` |
| Development environment | AMD Vivado Design Suite |

## Simulation

The RTL can be simulated with Icarus Verilog or Verilator. Individual modules
may provide their own testbenches and run scripts.

Example:

```bash
chmod +x run.sh
./run.sh
```

> [!WARNING]
> Simulation-only memory models must not be added to the Vivado synthesis
> source set. Use the corresponding XPM primitives for FPGA implementation.

## Author

**Siyeol Lee**  
Department of Intelligent Semiconductor
Incheon National University
