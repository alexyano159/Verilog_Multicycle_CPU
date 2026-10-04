# Multicycle Verilog CPU

A 32-bit multicycle CPU with a custom 25-instruction ISA, written in
Verilog. It includes a self-checking top-level testbench that runs a
program against an instruction-level reference model. This was my first
digital-design project, built to learn datapath and control design.

## Architecture

```
            ┌──────────────┐   ┌────┐
            │ Instruction  ├──►│ IR ├───────────► Control Unit (FSM)
 PC ───────►│ memory (ROM) │   └─┬──┘                  │ control signals
            └──────────────┘     │ rd / rs1 / rs2 / imm ▼
                                 ▼
                         ┌───────────────┐  A   ┌─────┐
                         │ Register file ├─────►│     │
                         │   32 x 32     │  B   │ ALU ├──► result → register file; flags (Z N V C) → control unit
                         └───────────────┘─────►│     │
                                 │              └─────┘
                     rs1 + imm   ▼
                              ┌─────┐       ┌─────────────┐      ┌─────┐
                              │ MAR ├──────►│ Data memory ├─────►│ MDR ├──► register file
                              └─────┘       │    (RAM)    │      └─────┘
                                            └─────────────┘
```

- **Harvard memories:** separate 256 × 32-bit instruction ROM and data RAM.
- **Register file:** 32 × 32-bit, two asynchronous read ports, one synchronous write port, asynchronous active-high reset. R0 is hardwired to zero.
- **Internal registers:** PC (byte address, +4 per instruction), IR (current instruction), MAR (data address) and MDR (data read from memory). They hold values *between* the cycles of one instruction, which is what makes the design multicycle.
- **ALU:** 16 operations, with zero, negative, overflow and carry flags. Branches use it to compute `rs1 − rs2`.

### Multicycle control

The control unit is a 5-state FSM. Each instruction class uses only the
states it needs:

| State | What happens |
|---|---|
| FETCH | IR ← instruction at PC |
| DECODE | PC ← PC + 4; register operands are read |
| EXECUTE | ALU operation and register write (ALU ops), branch/jump decision (PC load), or address calculation (MAR ← rs1 + imm) |
| MEMORY | LOAD: MDR ← MEM[MAR] · STORE: MEM[MAR] ← rs2 |
| WRITEBACK | LOAD: rd ← MDR |

| Instruction class | Cycles | States |
|---|---|---|
| JUMP, branches | 3 | FETCH → DECODE → EXECUTE |
| ALU operations | 4 | FETCH → DECODE → EXECUTE → WRITEBACK (idle) |
| STORE | 4 | FETCH → DECODE → EXECUTE → MEMORY |
| LOAD | 5 | FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK |

## Instruction set

25 instructions in one 32-bit format:
`opcode[31:27] | rd[26:22] | rs1[21:17] | rs2[16:12] | imm[11:0]`.
They cover 16 ALU operations, LOAD/STORE, JUMP and six signed/equality
branches. See
[`CPU_Project/InstructionSet/InstructionSet.md`](CPU_Project/InstructionSet/InstructionSet.md)
for the full table and the exact branch, jump and addressing rules.

## Verification

| Testbench | What it does | Checking |
|---|---|---|
| `CPU_Top_tb/CPU_selfcheck_tb.sv` | Runs a 61-instruction program (56 of them execute; the rest are skipped by taken branches) covering all 16 ALU ops, LOAD/STORE, JUMP and all six branches (taken and not taken, including a signed compare whose subtraction overflows). An ISA reference model executes the same program. | **Self-checking:** compares all 32 registers and all 256 data-memory words with the model, then prints PASS/FAIL |
| `Instruction_Memory_tb` | Reads back the ROM contents | Self-checking (compares each word with its expected value) |
| `alu_tb`, `Control_Unit_tb`, `Data_Memory_tb`, `RegisterFile_tb`, `Program_Counter_tb`, `Instruction_Register_tb`, `Memory_Address_Register_tb`, `Memory_Data_Register_tb` | Directed unit tests of each module | Print/waveform-based: the output is checked by inspection |
| `CPU_Top_tb` | Runs the demo program in the ROM and prints the CPU state every cycle (stops at time 700, after about 10 instructions) | Print/waveform-based |

The waveforms and transcripts in `CPU_Project/Waveforms+transcripts/`
were captured from the original version of the design (see Revision 2
below) and are kept for reference.

### Running the self-checking test (Questa / ModelSim)

```sh
vlib work
vlog CPU_Project/*/*.v
vlog -sv CPU_Project/CPU_Top_tb/CPU_selfcheck_tb.sv
vsim -c CPU_selfcheck_tb -do "run -all; quit -f"
```

Expected output:

```
# Program: 56 instructions executed by the reference model; CPU ran 222 cycles
# Branch counters: R30 (taken-branch poison, expect 0) = 0, R31 (not-taken, expect 7) = 7
# [PASS] CPU final state matches the reference model (32 registers, 256 memory words)
```

The RTL and the unit testbenches are plain Verilog-2001. Only
`CPU_selfcheck_tb.sv` needs SystemVerilog (`vlog -sv`).

## Repository layout

```
CPU_Project/
  CPU_Top/             CPU_Top.v               top level: datapath wiring, PC/branch/jump logic
  Control_Unit/        Control_Unit.v          5-state FSM, control signals
  ALU/                 alu_module.v            ALU (module Cpu_Alu)
  RegisterFile/        Register_File.v
  Program_Counter/     Program_Counter.v
  Instruction_Register/, Memory_Address_Register/, Memory_Data_Register/
  Instruction_Memory/  Instruction_Memory.v    ROM with a demo program
  Data_Memory/         Data_memory.v           RAM
  *_tb/                testbenches (one folder per module)
  InstructionSet/      InstructionSet.md       ISA specification
  Cpu_clk_sdc/         CPU_Top.sdc             clock constraint (17.5 ns period)
  RTL_Views/           RTL schematics of the original version (PNG)
  Waveforms+transcripts/  simulation captures of the original version
```

## Revision 2: self-checking test and bug fixes

The original version was verified only by reading waveforms and printed
output. In Revision 2 I added the self-checking testbench above. Run on
the original RTL, it reported 7 mismatches. Together with a review of the
RTL against the ISA, this led to these fixes:

| Bug | Cause | Fix |
|---|---|---|
| Branches compared `rs1 + rs2` instead of `rs1 − rs2` | The control unit never selected SUB for branches, so the ALU stayed on its default (ADD) | Branches select SUB; signed conditions use `N ^ V` |
| Taken branches landed one instruction too far | The PC had already been incremented in DECODE, and the target added +4 again | Target = branch + 4 + imm × 4 |
| A STORE also wrote to a stale address | MemWrite was asserted in EXECUTE, while the MAR still held the previous address | The MAR loads at the end of EXECUTE; the write happens only in MEMORY |
| A LOAD wrote stale data to rd before the real value | RegWrite was asserted in EXECUTE and MEMORY as well | rd is written only in WRITEBACK |
| JUMP target did not match the spec | MIPS-style 26-bit target field | PC = imm × 4 |
| SLT returned `0xFFFFFFFF` | Result encoding | Returns 1 |
| Smaller issues | INC overflow flag, a wrong opcode in the ALU testbench, one declaration that needed SystemVerilog, misleading comments | Fixed |

## About

Built as a learning project. I used GitHub Copilot as an assistant for
the original version, and Claude (an AI assistant) for the Revision 2
verification and fixes.
