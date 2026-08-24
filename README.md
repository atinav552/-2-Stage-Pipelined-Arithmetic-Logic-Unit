# 2-Stage Pipelined Arithmetic Logic Unit (ALU)

## Overview
A 2-stage pipelined Arithmetic Logic Unit (ALU) written in standard Verilog-2001. This module is designed for continuous-throughput CPU datapaths, capable of accepting a new arithmetic or logical operation every clock cycle.

To maintain data coherency without utilizing pipeline stalls, the design implements an internal data forwarding (bypass) network. This network dynamically resolves Read-After-Write (RAW) data hazards by routing in-flight data from the Write-Back stage directly into the Execute stage multiplexers.

## Architecture Highlights
* **Pipeline Structure:** Divided into Execute (EX) and Write-Back (WB) stages utilizing isolated pipeline registers.
* **Data Forwarding Logic:** Hardware multiplexers detect matching source and destination addresses across pipeline stages, bypassing the register file to feed computed results directly into the ALU.
* **Synchronous Flush:** Incorporates a hardware flush signal to squash in-flight operations during control flow changes or branch mispredictions.
* **Valid Bit Tracking:** Uses `input_valid` and `wb_valid` handshaking to track data flow and handle pipeline bubbles.

## Verification
The repository includes a Verilog testbench (`alu_tb.v`) that executes the following hardware tests:
1. **Throughput:** Verifies back-to-back execution of independent operations.
2. **RAW Hazard Resolution:** Issues dependent instructions sequentially to verify the data forwarding network triggers correctly without stalling.
3. **Dependency Chains:** Tests cascaded dependencies (e.g., R1 -> R2 -> R3) across consecutive clock cycles.
4. **Pipeline Flush:** Asserts the flush signal to verify that in-flight data is correctly invalidated.

## Simulation Instructions
The RTL and testbench can be compiled and visualized using standard open-source tools.
