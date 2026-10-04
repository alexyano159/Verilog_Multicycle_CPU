module Instruction_Memory #(
    parameter DATA_WIDTH = 32,
    parameter MEM_DEPTH = 256,
    parameter ADDR_WIDTH = 8
)(
    input [ADDR_WIDTH-1:0] Address, 
    output [DATA_WIDTH-1:0] Instruction
);
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1]; // 256 x 32 bits memory
    integer i;
    initial begin
        // opcode[31:27] | rd[26:22] | rs1[21:17] | rs2[16:12] | immediate/padding[11:0]
        memory[0]  = {5'b00000, 5'd1, 5'd2, 5'd3, 12'b0};   // ADD R1 = R2 + R3
        memory[1]  = {5'b00001, 5'd2, 5'd1, 5'd3, 12'b0};   // SUB R2 = R1 - R3
        memory[2]  = {5'b00010, 5'd3, 5'd0, 5'd1, 12'b0};   // AND R3 = R0 & R1
        memory[3]  = {5'b00011, 5'd4, 5'd2, 5'd1, 12'b0};   // OR R4 = R2 | R1
        memory[4]  = {5'b00100, 5'd5, 5'd3, 5'd4, 12'b0};   // XOR R5 = R3 ^ R4
        memory[5]  = {5'b00101, 5'd1, 5'd5, 5'd3, 12'b0};   // NOR R1 = ~(R5 | R3)
        memory[6]  = {5'b00110, 5'd2, 5'd1, 5'd3, 12'b0};   // SLT R2 = (R1 < R3)
        memory[7]  = {5'b00111, 5'd3, 5'd2, 5'd0, 12'd1};   // SLL R3 = R2 << 1 (shift amount is fixed at 1)
        memory[8]  = {5'b01000, 5'd4, 5'd3, 5'd0, 12'd1};   // SRL R4 = R3 >> 1
        memory[9]  = {5'b01001, 5'd5, 5'd0, 5'd0, 12'b0};   // NOT R5 = ~R0
        memory[10] = {5'b01010, 5'd1, 5'd1, 5'd0, 12'd1};   // INC R1 = R1 + 1
        memory[11] = {5'b01011, 5'd2, 5'd2, 5'd0, 12'd1};   // DEC R2 = R2 - 1
        memory[12] = {5'b01100, 5'd3, 5'd3, 5'd0, 12'd1};   // ROL R3 = ROL(R3,1)
        memory[13] = {5'b01101, 5'd4, 5'd4, 5'd0, 12'd1};   // ROR R4 = ROR(R4,1)
        memory[14] = {5'b01110, 5'd1, 5'd0, 5'd0, 12'b0};   // PASS B → R1 = R0
        memory[15] = {5'b01111, 5'd2, 5'd2, 5'd0, 12'b0};   // PASS A → R2 = R2
        // Register-register forms with a non-zero imm field. The ISA has no
        // immediate ALU operations: the imm field is ignored and rs2 = R0 is used.
        memory[16] = {5'b00000, 5'd6, 5'd6, 5'd0, 12'd10};  // ADD R6 = R6 + R0 (imm ignored)
        memory[17] = {5'b00001, 5'd7, 5'd7, 5'd0, -12'd5};  // SUB R7 = R7 - R0 (imm ignored)
        memory[18] = {5'b00010, 5'd8, 5'd8, 5'd0, 12'h0F0}; // AND R8 = R8 & R0 (imm ignored)
        memory[19] = {5'b00011, 5'd9, 5'd9, 5'd0, 12'h00F}; // OR R9 = R9 | R0 (imm ignored)
        memory[20] = {5'b00100, 5'd10, 5'd10, 5'd0, 12'hFF0}; // XOR R10 = R10 ^ R0 (imm ignored)
        memory[21] = {5'b00101, 5'd11, 5'd11, 5'd0, 12'hF0F}; // NOR R11 = ~(R11 | R0) (imm ignored)
        memory[22] = {5'b00110, 5'd12, 5'd12, 5'd0, 12'd100}; // SLT R12 = (R12 < R0) (imm ignored)
        
        // Memory operations: LOAD and STORE
        memory[23] = {5'b10000, 5'd1, 5'd0, 5'd0, 12'd50};   // LOAD R1 = MEM[R0 + 50]
        memory[24] = {5'b10001, 5'd0, 5'd0, 5'd2, 12'd60};   // STORE MEM[R0 + 60] = R2
        memory[25] = {5'b10000, 5'd3, 5'd1, 5'd0, 12'd4};    // LOAD R3 = MEM[R1 + 4]
        memory[26] = {5'b10001, 5'd0, 5'd2, 5'd4, 12'd8};    // STORE MEM[R2 + 8] = R4

        // Control flow. JUMP: PC = imm * 4 (word imm). Branches: if taken,
        // PC = (address of branch) + 4 + imm * 4, i.e. imm words past the next instruction.
        memory[27] = {5'b10010, 5'd0, 5'd0, 5'd0, 12'd35};   // JUMP to word 35 (skips the branches below)
        memory[28] = {5'b10011, 5'd0, 5'd2, 5'd3, 12'd40};   // BEQ if R2 == R3, skip 40 words ahead
        memory[29] = {5'b10100, 5'd0, 5'd4, 5'd5, 12'd45};   // BNE if R4 != R5, skip 45 words ahead
        memory[30] = {5'b10101, 5'd0, 5'd6, 5'd7, 12'd50};   // BLT if R6 < R7, skip 50 words ahead
        memory[31] = {5'b10110, 5'd0, 5'd8, 5'd9, 12'd55};   // BGT if R8 > R9, skip 55 words ahead
        memory[32] = {5'b10111, 5'd0, 5'd10,5'd11,12'd60};   // BGE if R10 >= R11, skip 60 words ahead
        memory[33] = {5'b11000, 5'd0, 5'd12,5'd13,12'd65};   // BLE if R12 <= R13, skip 65 words ahead

        // Fill remaining with NOP
        for (i = 34; i < MEM_DEPTH; i = i + 1)
            memory[i] = {DATA_WIDTH{1'b0}}; // NOP
    end
    assign Instruction = memory[Address]; 
endmodule
