# Custom CPU Instruction Set

## 1. Instruction Format

Every instruction is one 32-bit word with a single format:

```
 31     27 26    22 21    17 16    12 11                 0
┌─────────┬────────┬────────┬────────┬────────────────────┐
│ opcode  │   rd   │  rs1   │  rs2   │        imm         │
│ 5 bits  │ 5 bits │ 5 bits │ 5 bits │      12 bits       │
└─────────┴────────┴────────┴────────┴────────────────────┘
```

| Field   | Bits    | Description |
|---------|---------|-------------|
| opcode  | [31:27] | Operation type |
| rd      | [26:22] | Destination register |
| rs1     | [21:17] | Source register 1 |
| rs2     | [16:12] | Source register 2 |
| imm     | [11:0]  | Immediate, **sign-extended** to 32 bits. Used only by LOAD, STORE, JUMP and branches. |

## 2. Machine Model

- **Registers:** 32 × 32-bit (R0–R31). **R0 always reads 0**; writes to it are ignored.
- **Memories:** separate instruction and data memories (Harvard), each 256 × 32-bit words.
- **PC:** a byte address that advances by 4 per instruction. The instruction memory is indexed by `PC[9:2]`.
- **Data addresses** are word indices: `rs1 + imm`, truncated to 8 bits.
- **Undefined opcodes** (11001–11111) execute as no-operations.

## 3. Opcode Table

| Opcode | Mnemonic | Operation | Notes |
|--------|----------|-----------|-------|
| 00000 | ADD   | rd = rs1 + rs2 | |
| 00001 | SUB   | rd = rs1 − rs2 | |
| 00010 | AND   | rd = rs1 & rs2 | |
| 00011 | OR    | rd = rs1 \| rs2 | |
| 00100 | XOR   | rd = rs1 ^ rs2 | |
| 00101 | NOR   | rd = ~(rs1 \| rs2) | |
| 00110 | SLT   | rd = (rs1 < rs2) ? 1 : 0 | **signed** comparison |
| 00111 | SLL   | rd = rs1 << 1 | shift amount is fixed at 1 |
| 01000 | SRL   | rd = rs1 >> 1 | logical; fixed at 1 |
| 01001 | NOT   | rd = ~rs1 | |
| 01010 | INC   | rd = rs1 + 1 | |
| 01011 | DEC   | rd = rs1 − 1 | |
| 01100 | ROL   | rd = rotate left rs1 by 1 | |
| 01101 | ROR   | rd = rotate right rs1 by 1 | |
| 01110 | PASSB | rd = rs2 | |
| 01111 | PASSA | rd = rs1 | |
| 10000 | LOAD  | rd = MEM[rs1 + imm] | word address |
| 10001 | STORE | MEM[rs1 + imm] = rs2 | word address |
| 10010 | JUMP  | PC = imm × 4 | imm is the target's word index |
| 10011 | BEQ   | if (rs1 == rs2) branch | |
| 10100 | BNE   | if (rs1 != rs2) branch | |
| 10101 | BLT   | if (rs1 < rs2) branch | signed |
| 10110 | BGT   | if (rs1 > rs2) branch | signed |
| 10111 | BGE   | if (rs1 >= rs2) branch | signed |
| 11000 | BLE   | if (rs1 <= rs2) branch | signed |

There are **no immediate ALU forms**: ALU operations always use rs1
and rs2, and their imm field is ignored.

## 4. Branch Target

A taken branch jumps to:

```
PC = (address of the branch) + 4 + imm × 4
```

so `imm` counts words from the **next** instruction: `imm = 1` skips one
instruction, and `imm = -2` jumps back to the instruction before the
branch. A branch that is not taken continues with the next instruction.

## 5. How Branches Are Evaluated

The ALU computes `rs1 − rs2`, and the condition is read from its flags
(Z = zero, N = negative, V = signed overflow):

| Branch | Condition |
|--------|-----------|
| BEQ | Z |
| BNE | !Z |
| BLT | N ^ V |
| BGE | !(N ^ V) |
| BGT | !(N ^ V) & !Z |
| BLE | (N ^ V) \| Z |

`N ^ V` is the signed "less than" test. Using N alone would give the
wrong answer when the subtraction overflows, for example
`0x80000001 − 5`.
