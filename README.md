# AXI4-Lite FIFO Peripheral | RTL Design & Verification

A parameterized AXI4-Lite slave peripheral integrating independent 32-bit TX and RX synchronous FIFOs, developed using Verilog and SystemVerilog. The project covers RTL architecture, AXI protocol handling, self-checking functional verification, and FPGA synthesis and implementation targeting the Xilinx Zynq-7000 ZedBoard.

---

## 1. Project Overview

This project implements a memory-mapped FIFO peripheral that enables an AXI4-Lite master to exchange data with external streaming interfaces.

The peripheral consists of two independent 16-entry synchronous FIFOs:

- **TX FIFO:** Accepts data through AXI4-Lite write transactions and transfers it to an external consumer through a streaming interface.
- **RX FIFO:** Accepts incoming streaming data and makes it available to the AXI4-Lite master through memory-mapped read transactions.

The design incorporates independent AXI write-address and write-data handshakes, response generation, FIFO backpressure, status monitoring, and error handling.

The RTL was verified using a self-checking SystemVerilog testbench and implemented for the Xilinx Zynq-7000 XC7Z020 FPGA.

## 2. Architecture

```text
                 AXI4-Lite Master
                        |
              +---------------------+
              |  AXI4-Lite Slave    |
              |                     |
              | AW | W | B | AR | R |
              +----------+----------+
                         |
              +---------------------+
              | Address / Register  |
              | Decoder & Controller|
              +----------+----------+
                         |
                +--------+--------+
                |                 |
          +-----------+     +-----------+
          |  TX FIFO  |     |  RX FIFO  |
          | 32 x 16   |     | 32 x 16   |
          +-----+-----+     +-----+-----+
                |                 ^
                v                 |
          TX Stream Output   RX Stream Input
          VALID / READY      VALID / READY
```

### Main Design Components

| Component | Description |
|---|---|
| AXI4-Lite Slave | Handles memory-mapped read and write transactions |
| Address Decoder | Decodes control, data and status register accesses |
| TX FIFO | Buffers outgoing data |
| RX FIFO | Buffers incoming data |
| FIFO Controller | Manages read/write operations and FIFO status |
| FPGA Wrapper | Connects the peripheral to the ZedBoard clock, reset and LEDs |

## 3. Key Features

### RTL Design

- Parameterized synchronous FIFO architecture.
- Two independent 32-bit, 16-entry TX/RX FIFOs.
- First-Word Fall-Through (FWFT) read behavior.
- Circular read and write pointers with explicit wraparound.
- Occupancy counter with full and empty detection.
- Simultaneous FIFO read/write support.
- Synchronous active-low FIFO reset.
- AXI4-Lite read and write channel handling.
- Independent AW and W channel handshakes.
- Write and read response generation.
- FIFO backpressure handling.
- Memory-mapped control and status registers.
- Invalid-address and FIFO error handling.

### FIFO Configuration

| Parameter | Value |
|---|---:|
| Data Width | 32 bits |
| FIFO Depth | 16 entries |
| Capacity per FIFO | 512 bits |
| Total FIFO Capacity | 1024 bits |
| Number of FIFOs | 2 |
| FIFO Type | Synchronous |
| Read Architecture | FWFT |
| Reset | Synchronous, Active-Low |

## 4. Memory-Mapped Register Interface

The peripheral exposes the following register map:

| Address | Register | Function |
|---|---|---|
| `0x00` | TX_DATA | Write data into TX FIFO |
| `0x04` | RX_DATA | Read data from RX FIFO |
| `0x08` | STATUS | Read FIFO status flags |
| `0x0C` | CONTROL | Peripheral control and enable |
| `0x10` | COUNTS | Read FIFO occupancy information |

## 5. Verification Methodology

A self-checking SystemVerilog testbench was developed to verify functional correctness, AXI protocol behavior, FIFO operation and data integrity.

### 5.1 Directed Verification

The testbench covers the following scenarios:

1. Peripheral disabled write rejection.
2. Peripheral enable operation.
3. Independent AW and W channel handshakes.
4. TX FIFO stream transfer.
5. TX FIFO stress and ordering.
6. TX FIFO empty condition.
7. Partial write strobe rejection.
8. RX stream-to-AXI read round trip.
9. RX FIFO empty read rejection.
10. Unmapped address handling.
11. TX FIFO full rejection.
12. TX FIFO status and occupancy checks.
13. RX FIFO full backpressure.
14. RX FIFO status and occupancy checks.
15. RX backpressure and recovery.
16. Reset during FIFO operation.
17. FIFO pointer wraparound.

### 5.2 Reference Scoreboard

A reference scoreboard was implemented to compare expected and observed TX/RX stream data.

Final reported results:

| Metric | Result |
|---|---:|
| TX words checked | 8 |
| RX words checked | 8 |
| Data mismatches | 0 |
| Scoreboard status | PASS |

### 5.3 Procedural Protocol Checker

A separate protocol checker monitors AXI channel and streaming signal stability during stalled transactions.

It checks:

- AW address stability.
- W data and strobe stability.
- B response stability.
- AR address stability.
- R data and response stability.
- TX stream stability.
- RX stream stability.

**Simulation result: 0 reported protocol violations.**

### 5.4 Functional Coverage

The functional coverage monitor tracks:

- AXI AW and W handshakes.
- Simultaneous AW/W acceptance.
- AXI write and read response types.
- TX and RX stream transfers.
- TX and RX backpressure cycles.
- FIFO status observations.

Final extended regression results:

| Metric | Count |
|---|---:|
| AW handshakes | 81 |
| W handshakes | 81 |
| Simultaneous AW/W | 81 |
| Successful write responses | 81 |
| Successful read responses | 80 |
| Read SLVERR responses | 1 |
| TX stream transfers | 80 |
| RX stream transfers | 80 |

The final regression also passed the directed FIFO reset and pointer-wraparound tests.

## 6. SystemVerilog Assertions (SVA)

An experimental assertion module, `axi_fifo_sva.sv`, was developed to check temporal protocol properties.

The planned assertions cover:

- AW address and protection stability during stalls.
- W data and strobe stability during stalls.
- B response stability until acceptance.
- AR address and protection stability during stalls.
- R data and response stability until acceptance.
- TX stream stability under backpressure.
- RX stream stability under backpressure.

### Simulator Limitation

The project was developed and simulated using **Xilinx Vivado 2016.2 XSim**.

During simulation, the tool reported that SystemVerilog property declarations and concurrent assertion statements were unsupported and ignored.

Consequently, successful SVA execution could not be established using the available simulator version.

The SVA module is retained as an experimental verification component. Execution using a simulator with suitable concurrent SVA support remains a planned extension.

The completed regression relies on the procedural protocol checker, which reported zero protocol violations.

**SVA execution is not claimed as a completed verification result.**

## 7. FPGA Synthesis and Implementation

### Target Hardware

| Parameter | Configuration |
|---|---|
| Development Board | Digilent ZedBoard |
| FPGA Family | Xilinx Zynq-7000 |
| FPGA Device | XC7Z020CLG484-1 |
| Clock Constraint | 100 MHz |
| Clock Period | 10 ns |
| FPGA Tool | Xilinx Vivado 2016.2 |

A dedicated FPGA top-level wrapper was developed to connect the FIFO peripheral internally and expose the required board-level clock, reset and LED interfaces.

### 7.1 Post-Implementation Resource Utilization

| Resource | Used | Available | Utilization |
|---|---:|---:|---:|
| LUT | 124 | 53,200 | 0.23% |
| LUTRAM | 16 | 17,400 | 0.09% |
| Flip-Flops | 90 | 106,400 | 0.08% |
| I/O | 10 | 200 | 5.00% |
| BUFG | 1 | 32 | 3.13% |

### 7.2 Post-Implementation Timing

| Timing Parameter | Result |
|---|---:|
| Clock Constraint | 100 MHz |
| Worst Negative Slack (WNS) | +5.469 ns |
| Total Negative Slack (TNS) | 0.000 ns |
| Worst Hold Slack (WHS) | +0.090 ns |
| Total Hold Slack (THS) | 0.000 ns |
| Worst Pulse Width Slack | +3.750 ns |
| Failing Setup Endpoints | 0 |
| Failing Hold Endpoints | 0 |

All user-specified timing constraints were met in the post-implementation timing report.

### 7.3 Power Estimation

| Parameter | Result |
|---|---:|
| Total On-Chip Power | 0.127 W |
| Dynamic Power | 0.004 W |
| Device Static Power | 0.123 W |
| Junction Temperature | 26.5 °C |
| Estimation Confidence | Medium |


## 8. Tools and Technologies

- Verilog HDL
- SystemVerilog
- AXI4-Lite Protocol
- RTL Design
- Synchronous FIFO Design
- SystemVerilog Testbench
- Reference Scoreboard
- Procedural Protocol Checking
- SystemVerilog Assertions (Experimental)
- Functional Coverage
- Xilinx Vivado 2016.2
- Xilinx Zynq-7000 FPGA


## 10. Future Improvements

- Execute concurrent SVA properties using a compatible simulator.
- Expand assertion-based and functional coverage.
- Add constrained-random stress testing.
- Extend reference-model checking.
- Explore Block RAM inference and alternative FIFO memory architectures.
- Evaluate timing and power under more representative switching activity.
- Perform physical ZedBoard hardware validation.

## 11. Project Outcome

This project demonstrates practical experience in:

- AXI4-Lite slave peripheral architecture.
- Parameterized synchronous FIFO design.
- Verilog RTL implementation.
- SystemVerilog functional verification.
- Reference-based data integrity checking.
- Protocol monitoring and functional coverage.
- FPGA synthesis, implementation and timing analysis.

It provides an end-to-end digital design workflow spanning RTL development, functional verification and FPGA implementation.