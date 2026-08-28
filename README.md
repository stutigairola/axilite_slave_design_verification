# AXI4-Lite Slave Memory Controller & SystemVerilog Layered Verification

## Overview
This repository contains a synthesizable **AXI4-Lite Slave Peripheral and Memory Controller** implemented in Verilog alongside an object-oriented **SystemVerilog Layered Verification Framework**. The slave IP features an internal 128x32-bit memory array and executes single-beat control-plane read and write operations with full handshaking and address boundary error responses (`OKAY` and `DECERR`).

---

## Architecture & Protocol Details

### 1. RTL Design (`design.sv`)
* **Interface Channels:** Implements standard AXI4-Lite read/write address, data, and response signals.
* **Internal Storage:** Integrates a 128-word x 32-bit memory array (`mem[0:127]`).
* **Handshake FSM:** Manages independent read and write channels using a state machine (`idle`, `send_waddr_ack`, `send_wdata_ack`, `send_wr_resp`, `send_raddr_ack`, `gen_data`, `send_rdata`, etc.).
* **Response Generation:** Evaluates address validity to return `2'b00` (`OKAY`) for valid memory access or `2'b11` (`DECERR`) for out-of-bounds requests.

### 2. Layered Testbench Architecture (`testbench.sv`)
The verification framework is built using object-oriented SystemVerilog classes:
* **Interface (`axi_if`):** Bundles all physical protocol signals to connect the testbench directly to the RTL module.
* **Transaction:** Encapsulates randomizable stimulus (`op`, `awaddr`, `wdata`, `araddr`) constrained to valid memory addresses (`< 128`).
* **Generator:** Dynamically creates randomized transactions, pushes them into a mailbox, and handles event synchronization (`sconext`).
* **Driver:** Converts high-level transactions into cycle-accurate pin-level AXI4-Lite valid/ready handshake sequences for read and write operations.
* **Monitor:** Passively captures completed transaction handshakes on the interface bus and forwards sampled data to the Scoreboard.
* **Scoreboard:** Uses an internal shadow memory array (`data[128]`) as a reference model to check read/write data integrity and log match/mismatch status in real-time.
* **Top Module (`tb`):** Instantiates the DUT, drives clock/reset generation, configures class connections, and dumps VCD waveforms (`dump.vcd`).

---

## Repository Structure

```text
├── rtl/
│   └── design.sv       # AXI4-Lite Slave Memory Controller RTL
├── tb/
│   └── testbench.sv    # SystemVerilog Interface & Layered Testbench Classes
└── README.md           # Project Documentation
