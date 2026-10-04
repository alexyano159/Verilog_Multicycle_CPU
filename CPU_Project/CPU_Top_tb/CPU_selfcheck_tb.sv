// -----------------------------------------------------------------------
// Self-checking top-level testbench for the multicycle CPU.
//
// A directed program that exercises every instruction class -- all 16
// ALU operations, LOAD/STORE, JUMP, and all six branches in both the
// taken and the not-taken direction, including a signed compare whose
// subtraction overflows -- is loaded into the instruction
// ROM. The same program is executed by an instruction-level reference
// model (an ISA simulator written in this file), and at the end the
// CPU's 32 registers and all 256 data-memory words are compared against
// the model. Comparing the whole data memory, not only the words the
// program stores to, also catches stray writes.
//
// Branch outcomes are made observable through two counters: every taken
// branch skips a "poison" instruction that increments R30, and every
// not-taken branch falls through to an instruction that increments R31.
// A correct CPU finishes with R30 = 0 and R31 = 7.
//
// ISA conventions used by the model (see InstructionSet/InstructionsSet):
//   - branch taken : PC = (address of branch) + 4 + sext(imm) * 4
//   - JUMP         : PC = imm * 4   (imm is a word index)
//   - SLT, BLT/BGT/BGE/BLE : signed comparison; SLT writes 1 or 0
//   - R0 is hardwired to zero
//
// The program ends with a JUMP to itself ("halt"). The TB stops once the
// halt instruction has executed a few times, or after a cycle watchdog.
// Requires SystemVerilog compilation: vlog -sv
// -----------------------------------------------------------------------
module CPU_selfcheck_tb;

    localparam int DATA_WIDTH  = 32;
    localparam int ADDR_WIDTH  = 8;
    localparam int MEM_WORDS   = 256;
    localparam int MAX_CYCLES  = 5000;

    // Opcodes (InstructionSet/InstructionsSet).
    localparam logic [4:0] ADD  = 5'b00000, SUB  = 5'b00001, AND_ = 5'b00010,
                           OR_  = 5'b00011, XOR_ = 5'b00100, NOR_ = 5'b00101,
                           SLT  = 5'b00110, SLL  = 5'b00111, SRL  = 5'b01000,
                           NOT_ = 5'b01001, INC  = 5'b01010, DEC  = 5'b01011,
                           ROL  = 5'b01100, ROR  = 5'b01101, PASSB = 5'b01110,
                           PASSA = 5'b01111, LOAD = 5'b10000, STORE = 5'b10001,
                           JUMP = 5'b10010, BEQ  = 5'b10011, BNE  = 5'b10100,
                           BLT  = 5'b10101, BGT  = 5'b10110, BGE  = 5'b10111,
                           BLE  = 5'b11000;

    // -------------------------------------------------------------------
    // DUT and memories, wired as in CPU_Top_tb.
    // -------------------------------------------------------------------
    logic                  clk = 1'b0;
    logic                  reset;
    logic [DATA_WIDTH-1:0] instruction_data, read_data, write_data;
    logic [ADDR_WIDTH-1:0] instruction_address, data_address;
    logic                  write_enable;

    always #5 clk = ~clk;

    CPU_Top #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) cpu (
        .clk                 (clk),
        .reset               (reset),
        .instruction_data    (instruction_data),
        .read_data           (read_data),
        .instruction_address (instruction_address),
        .data_address        (data_address),
        .write_data          (write_data),
        .write_enable        (write_enable)
    );

    Instruction_Memory #(.DATA_WIDTH(DATA_WIDTH), .MEM_DEPTH(MEM_WORDS), .ADDR_WIDTH(ADDR_WIDTH)) inst_mem (
        .Address     (instruction_address),
        .Instruction (instruction_data)
    );

    Data_Memory #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) data_mem (
        .clk        (clk),
        .Address    (data_address),
        .Write_Data (write_data),
        .Mem_Write  (write_enable),
        .Mem_Read   (1'b1),
        .Read_Data  (read_data)
    );

    // -------------------------------------------------------------------
    // Program construction.
    // -------------------------------------------------------------------
    logic [31:0] prog     [MEM_WORDS];   // instruction words, by word address
    logic [31:0] mem_init [MEM_WORDS];   // initial data-memory contents
    int          pc_w;                   // next word address to emit
    logic [31:0] halt_word;

    function automatic logic [31:0] enc(input logic [4:0] op, input int rd, input int rs1,
                                        input int rs2, input int imm);
        return {op, 5'(rd), 5'(rs1), 5'(rs2), 12'(imm)};
    endfunction

    function automatic void emit(input logic [31:0] word);
        prog[pc_w] = word;
        pc_w++;
    endfunction

    task automatic build_program();
        int loop_top, jump_src;

        foreach (prog[i])     prog[i]     = '0;   // opcode 00000 rd=0: ADD R0 (no effect)
        foreach (mem_init[i]) mem_init[i] = '0;
        pc_w = 0;

        // Operands, placed in data memory (registers reset to 0 and the
        // ISA has no immediate ALU forms, so values arrive via LOAD).
        mem_init[0] = 32'h1234_5678;
        mem_init[1] = 32'd5;
        mem_init[2] = 32'hFFFF_FFFD;          // -3
        mem_init[3] = 32'h8000_0001;
        mem_init[4] = 32'h0F0F_00FF;
        mem_init[5] = 32'd3;                  // loop bound

        // 1. Loads.
        emit(enc(LOAD, 1, 0, 0, 0));          // R1 = 0x12345678
        emit(enc(LOAD, 2, 0, 0, 1));          // R2 = 5
        emit(enc(LOAD, 3, 0, 0, 2));          // R3 = -3
        emit(enc(LOAD, 4, 0, 0, 3));          // R4 = 0x80000001
        emit(enc(LOAD, 5, 0, 0, 4));          // R5 = 0x0F0F00FF

        // 2. All 16 ALU operations.
        emit(enc(ADD,   6, 1, 2, 0));         // R6  = R1 + R2
        emit(enc(SUB,   7, 2, 3, 0));         // R7  = R2 - R3 = 8
        emit(enc(AND_,  8, 1, 5, 0));
        emit(enc(OR_,   9, 1, 5, 0));
        emit(enc(XOR_, 10, 1, 4, 0));
        emit(enc(NOR_, 11, 2, 3, 0));
        emit(enc(SLT,  12, 3, 2, 0));         // -3 < 5  -> 1
        emit(enc(SLT,  13, 2, 3, 0));         //  5 < -3 -> 0
        emit(enc(SLL,  14, 4, 0, 0));
        emit(enc(SRL,  15, 4, 0, 0));
        emit(enc(NOT_, 16, 1, 0, 0));
        emit(enc(INC,  17, 2, 0, 0));
        emit(enc(DEC,  18, 0, 0, 0));         // R0 - 1 = 0xFFFFFFFF
        emit(enc(ROL,  19, 4, 0, 0));
        emit(enc(ROR,  20, 4, 0, 0));
        emit(enc(PASSB, 21, 0, 5, 0));        // R21 = R5
        emit(enc(PASSA, 22, 1, 0, 0));        // R22 = R1
        emit(enc(ADD,   0, 1, 2, 0));         // write to R0 must be ignored

        // 3. Stores and a load-back.
        emit(enc(STORE, 0, 2, 6, 10));        // MEM[R2 + 10] = MEM[15] = R6
        emit(enc(STORE, 0, 0, 7, 20));        // MEM[20] = R7
        emit(enc(LOAD, 23, 2, 0, 10));        // R23 = MEM[15]  (== R6)

        // 4. Every branch, taken (skips an R30 poison) and not taken
        //    (falls through to an R31 increment). imm = 1 skips one word.
        emit(enc(BEQ, 0,  6, 23, 1)); emit(enc(INC, 30, 30, 0, 0));   // taken
        emit(enc(BEQ, 0,  2,  3, 1)); emit(enc(INC, 31, 31, 0, 0));   // not taken
        emit(enc(BNE, 0,  2,  3, 1)); emit(enc(INC, 30, 30, 0, 0));   // taken
        emit(enc(BNE, 0,  6, 23, 1)); emit(enc(INC, 31, 31, 0, 0));   // not taken
        emit(enc(BLT, 0,  3,  2, 1)); emit(enc(INC, 30, 30, 0, 0));   // -3 < 5: taken
        emit(enc(BLT, 0,  2,  3, 1)); emit(enc(INC, 31, 31, 0, 0));   // not taken
        emit(enc(BGT, 0,  2,  3, 1)); emit(enc(INC, 30, 30, 0, 0));   // 5 > -3: taken
        emit(enc(BGT, 0,  2,  2, 1)); emit(enc(INC, 31, 31, 0, 0));   // equal: not taken
        emit(enc(BGE, 0,  2,  2, 1)); emit(enc(INC, 30, 30, 0, 0));   // equal: taken
        emit(enc(BGE, 0,  3,  2, 1)); emit(enc(INC, 31, 31, 0, 0));   // not taken
        emit(enc(BLE, 0,  2,  2, 1)); emit(enc(INC, 30, 30, 0, 0));   // equal: taken
        emit(enc(BLE, 0,  2,  3, 1)); emit(enc(INC, 31, 31, 0, 0));   // not taken
        // Signed compare where rs1 - rs2 overflows: 0x80000001 - 5 =
        // 0x7FFFFFFC looks positive (N = 0) although rs1 < rs2; only
        // N ^ V gives the right answer.
        emit(enc(BLT, 0,  4,  2, 1)); emit(enc(INC, 30, 30, 0, 0));   // taken
        emit(enc(BGT, 0,  4,  2, 1)); emit(enc(INC, 31, 31, 0, 0));   // not taken

        // 5. Backward branch: count R26 up to 3.
        emit(enc(LOAD, 27, 0, 0, 5));         // R27 = 3
        loop_top = pc_w;
        emit(enc(INC, 26, 26, 0, 0));
        emit(enc(BLT, 0, 26, 27, -2));        // back to loop_top while R26 < 3

        // 6. Forward JUMP over a poison, store the not-taken count, halt.
        jump_src = pc_w;
        emit(enc(JUMP, 0, 0, 0, jump_src + 2));
        emit(enc(INC, 30, 30, 0, 0));         // poison: must be skipped
        emit(enc(STORE, 0, 0, 31, 30));       // MEM[30] = R31
        halt_word = enc(JUMP, 0, 0, 0, pc_w); // jump to itself
        emit(halt_word);
    endtask

    // -------------------------------------------------------------------
    // Reference model: executes the program one instruction at a time
    // according to the ISA, on plain arrays.
    // -------------------------------------------------------------------
    logic [31:0] m_reg [32];
    logic [31:0] m_mem [MEM_WORDS];
    int          m_steps;

    task automatic run_model();
        int          pc;               // byte address
        logic [31:0] ir, a, b, r, sext_imm;
        logic [4:0]  op;
        int          rd, rs1, rs2;
        logic        taken;

        foreach (m_reg[i]) m_reg[i] = '0;
        foreach (m_mem[i]) m_mem[i] = mem_init[i];
        pc      = 0;
        m_steps = 0;

        while (m_steps < 2000) begin
            ir = prog[(pc >> 2) % MEM_WORDS];
            if (ir == halt_word) break;
            m_steps++;

            op       = ir[31:27];
            rd       = ir[26:22];
            rs1      = ir[21:17];
            rs2      = ir[16:12];
            sext_imm = {{20{ir[11]}}, ir[11:0]};
            a        = m_reg[rs1];
            b        = m_reg[rs2];
            taken    = 1'b0;

            case (op)
                ADD:   r = a + b;
                SUB:   r = a - b;
                AND_:  r = a & b;
                OR_:   r = a | b;
                XOR_:  r = a ^ b;
                NOR_:  r = ~(a | b);
                SLT:   r = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                SLL:   r = a << 1;
                SRL:   r = a >> 1;
                NOT_:  r = ~a;
                INC:   r = a + 1;
                DEC:   r = a - 1;
                ROL:   r = {a[30:0], a[31]};
                ROR:   r = {a[0], a[31:1]};
                PASSB: r = b;
                PASSA: r = a;
                LOAD:  r = m_mem[(a + sext_imm) % MEM_WORDS];
                STORE: m_mem[(a + sext_imm) % MEM_WORDS] = b;
                BEQ:   taken = (a == b);
                BNE:   taken = (a != b);
                BLT:   taken = ($signed(a) <  $signed(b));
                BGT:   taken = ($signed(a) >  $signed(b));
                BGE:   taken = ($signed(a) >= $signed(b));
                BLE:   taken = ($signed(a) <= $signed(b));
                default: ;   // undefined opcode: no operation
            endcase

            // Register write for ALU operations and LOAD; R0 stays zero.
            if ((op <= PASSA || op == LOAD) && rd != 0)
                m_reg[rd] = r;

            // Next PC.
            if (op == JUMP)
                pc = int'(ir[11:0]) * 4;
            else if (taken)
                pc = pc + 4 + int'($signed(sext_imm)) * 4;
            else
                pc = pc + 4;
        end
    endtask

    // -------------------------------------------------------------------
    // Test sequence.
    // -------------------------------------------------------------------
    int unsigned errors = 0;
    int unsigned halt_seen = 0;
    int unsigned cycles = 0;

    initial begin
        build_program();
        run_model();

        // Install the program and the data after the memories' own
        // initial blocks have run (time 0), and before reset is released.
        reset = 1'b1;
        #1;
        foreach (prog[i])     inst_mem.memory[i] = prog[i];
        foreach (mem_init[i]) data_mem.memory[i] = mem_init[i];
        #19;
        reset = 1'b0;

        // Run until the halt instruction has been executed three times
        // (it is fetched over and over), or until the watchdog expires.
        while (halt_seen < 3 && cycles < MAX_CYCLES) begin
            @(posedge clk);
            cycles++;
            if (cpu.ir == halt_word && cpu.current_state == 4'b0010)   // EXECUTE
                halt_seen++;
        end
        repeat (2) @(posedge clk);

        if (halt_seen < 3) begin
            $display("[FAIL] halt not reached within %0d cycles (PC = 0x%08h) -- control flow went wrong",
                     MAX_CYCLES, cpu.pc_current);
            errors++;
        end

        // Final state: all 32 registers and all 256 data-memory words.
        for (int i = 0; i < 32; i++) begin
            if (cpu.reg_file.registers[i] !== m_reg[i]) begin
                $display("[FAIL] R%0d = 0x%08h, expected 0x%08h",
                         i, cpu.reg_file.registers[i], m_reg[i]);
                errors++;
            end
        end
        for (int i = 0; i < MEM_WORDS; i++) begin
            if (data_mem.memory[i] !== m_mem[i]) begin
                $display("[FAIL] MEM[%0d] = 0x%08h, expected 0x%08h",
                         i, data_mem.memory[i], m_mem[i]);
                errors++;
            end
        end

        $display("---------------------------------------------------------------");
        $display("Program: %0d instructions executed by the reference model; CPU ran %0d cycles",
                 m_steps, cycles);
        $display("Branch counters: R30 (taken-branch poison, expect 0) = %0d, R31 (not-taken, expect 7) = %0d",
                 cpu.reg_file.registers[30], cpu.reg_file.registers[31]);
        if (errors == 0)
            $display("[PASS] CPU final state matches the reference model (32 registers, %0d memory words)", MEM_WORDS);
        else
            $display("[FAIL] %0d mismatches against the reference model", errors);
        $finish;
    end

endmodule
