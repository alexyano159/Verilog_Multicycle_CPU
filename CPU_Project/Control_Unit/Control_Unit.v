module Control_Unit(
    //inputs
    input clk,
    input reset,
    input [31:0] instruction,
    input zero_flag,
    input negative_flag,
    input overflow_flag, // needed for signed comparisons: (rs1 < rs2) == N ^ V after rs1 - rs2
    //outputs
    output reg [4:0] AluControl,
    output reg AluSrc, // select ALU source (register or immediate)
    output reg MemtoReg, // select data to write to register (ALU result or memory data)
    output reg RegDst, // select destination register
    output reg RegWrite, // enable register write
    output reg MemRead, // indicate memory read operation
    output reg MemWrite, // indicate memory write operation
    output reg Jump,
    output reg Branch, // indicate a branch instruction
    output reg branch_taken, // indicate if branch condition is met
    output reg [3:0] current_state 
);
    localparam FETCH= 4'b0000,
               DECODE= 4'b0001,
               EXECUTE= 4'b0010,
               MEMORY= 4'b0011,
               WRITEBACK= 4'b0100;
    reg [3:0] next_state;
    wire [4:0] opcode;
    assign opcode = instruction[31:27];

    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= FETCH;
        else
            current_state <= next_state;
    end

    always @(*) begin 
        // Default values
        next_state = current_state;
        AluSrc   = 1'b0;
        MemtoReg = 1'b0;
        RegDst   = 1'b0;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        RegWrite = 1'b0;
        AluControl    = 5'b00000;
        Jump     = 1'b0;
        Branch   = 1'b0;
        branch_taken = 1'b0;

        case (current_state)
            FETCH: begin
                next_state = DECODE;
                AluSrc     = 1'b0;
                MemtoReg   = 1'b0;
                RegDst     = 1'b0;
                RegWrite   = 1'b0;
                MemRead    = 1'b0; // instruction fetch uses the separate ROM, not the data memory
                MemWrite   = 1'b0;
            end

            DECODE: begin
                next_state = EXECUTE;
                AluSrc     = 1'b0;
                MemtoReg   = 1'b0;
                RegDst     = 1'b0;
                RegWrite   = 1'b0;
                MemRead    = 1'b0;
                MemWrite   = 1'b0;
            end

            EXECUTE: begin
                case (opcode)
                    5'b00000: begin // ADD
                        next_state = WRITEBACK;
                        AluControl      = 5'b00000;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b00001: begin // SUB
                        next_state = WRITEBACK;
                        AluControl      = 5'b00001;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b00010: begin // AND
                        next_state = WRITEBACK;
                        AluControl      = 5'b00010;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b00011: begin // OR
                        next_state = WRITEBACK;
                        AluControl      = 5'b00011;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b00100: begin // XOR
                        next_state = WRITEBACK;
                        AluControl      = 5'b00100;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b00101: begin // NOR
                        next_state = WRITEBACK;
                        AluControl      = 5'b00101;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b00110: begin // SLT
                        next_state = WRITEBACK;
                        AluControl      = 5'b00110;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b00111: begin // SLL
                        next_state = WRITEBACK;
                        AluControl      = 5'b00111;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01000: begin // SRL
                        next_state = WRITEBACK;
                        AluControl      = 5'b01000;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01001: begin // NOT
                        next_state = WRITEBACK;
                        AluControl      = 5'b01001;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01010: begin // INC
                        next_state = WRITEBACK;
                        AluControl      = 5'b01010;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01011: begin // DEC
                        next_state = WRITEBACK;
                        AluControl      = 5'b01011;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01100: begin // ROL
                        next_state = WRITEBACK;
                        AluControl      = 5'b01100;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01101: begin // ROR
                        next_state = WRITEBACK;
                        AluControl      = 5'b01101;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01110: begin // Pass B
                        next_state = WRITEBACK;
                        AluControl      = 5'b01110;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b01111: begin // Pass A
                        next_state = WRITEBACK;
                        AluControl      = 5'b01111;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b1;
                        RegWrite   = 1'b1;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    // LOAD/STORE in EXECUTE: the effective address (rs1 + imm,
                    // from the address adder in CPU_Top) is captured in the MAR
                    // at the end of this cycle. No memory access and no register
                    // write happen yet -- the MAR still holds the previous
                    // address during this cycle.
                    5'b10000: begin // LOAD
                        next_state = MEMORY;
                        AluSrc     = 1'b1;
                        MemtoReg   = 1'b1;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b10001: begin // STORE
                        next_state = MEMORY;
                        AluSrc     = 1'b1;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b10010: begin // JUMP
                        next_state = FETCH;
                        Jump       = 1'b1;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    // Branches: the ALU computes rs1 - rs2 (SUB), and the condition
                    // is read from its flags. Signed less-than is N ^ V (negative
                    // XOR overflow), which stays correct when the subtraction
                    // overflows; equality is Z.
                    5'b10011: begin // Branch if equal (BEQ)
                        next_state = FETCH;
                        AluControl = 5'b00001; // SUB
                        Branch     = 1'b1;
                        branch_taken = zero_flag;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b10100: begin // Branch if not equal (BNE)
                        next_state = FETCH;
                        AluControl = 5'b00001; // SUB
                        Branch=1'b1;
                        branch_taken = !zero_flag;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                    5'b10101: begin //Branch if less than (BLT)
                        next_state=FETCH;
                        AluControl = 5'b00001; // SUB
                        Branch=1'b1;
                        branch_taken = negative_flag ^ overflow_flag;                    // rs1 <  rs2
                        AluSrc=1'b0;
                        MemtoReg=1'b0;
                        RegDst=1'b0;
                        RegWrite=1'b0;
                        MemRead=1'b0;
                        MemWrite=1'b0;
                    end
                    5'b10110: begin // Branch if greater than (BGT)
                        next_state=FETCH;
                        AluControl = 5'b00001; // SUB
                        Branch=1'b1;
                        branch_taken = ~(negative_flag ^ overflow_flag) & ~zero_flag;    // rs1 >  rs2
                        AluSrc=1'b0;
                        MemtoReg=1'b0;
                        RegDst=1'b0;
                        RegWrite=1'b0;
                        MemRead=1'b0;
                        MemWrite=1'b0;
                    end
                    5'b10111: begin // Branch if greater than or equal (BGE)
                        next_state=FETCH;
                        AluControl = 5'b00001; // SUB
                        Branch=1'b1;
                        branch_taken = ~(negative_flag ^ overflow_flag);                 // rs1 >= rs2
                        AluSrc=1'b0;
                        MemtoReg=1'b0;
                        RegDst=1'b0;
                        RegWrite=1'b0;
                        MemRead=1'b0;
                        MemWrite=1'b0;
                    end
                    5'b11000: begin // Branch if less than or equal (BLE)
                        next_state=FETCH;
                        AluControl = 5'b00001; // SUB
                        Branch=1'b1;
                        branch_taken = (negative_flag ^ overflow_flag) | zero_flag;      // rs1 <= rs2
                        AluSrc=1'b0;
                        MemtoReg=1'b0;
                        RegDst=1'b0;
                        RegWrite=1'b0;
                        MemRead=1'b0;
                        MemWrite=1'b0;
                    end
                    default: begin // NOP or undefined opcode
                        next_state = FETCH;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                endcase
            end

            MEMORY: begin
                case (opcode)
                    5'b10000: begin // LOAD
                        next_state = WRITEBACK;
                        AluSrc     = 1'b1; // Select immediate value for ALU
                        MemtoReg   = 1'b1;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0; // the MDR captures the data at the end of this cycle; rd is written in WRITEBACK
                        MemRead    = 1'b1; // read MEM[MAR] into the MDR
                        MemWrite   = 1'b0;
                    end
                    5'b10001: begin // STORE
                        next_state = FETCH;
                        AluSrc     = 1'b1; // Select immediate value for ALU
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b1; // Enable memory write
                    end
                    default: begin
                        next_state = FETCH;
                        AluSrc     = 1'b0;
                        MemtoReg   = 1'b0;
                        RegDst     = 1'b0;
                        RegWrite   = 1'b0;
                        MemRead    = 1'b0;
                        MemWrite   = 1'b0;
                    end
                endcase
            end

            WRITEBACK: begin
                next_state = FETCH;
                case (opcode)
                    5'b10000: begin // LOAD
                        AluSrc   = 1'b1;
                        MemtoReg = 1'b1;
                        RegDst   = 1'b0;
                        RegWrite = 1'b1;
                    end
                    // No write back for STORE

                    default:begin
                        AluSrc   = 1'b0;
                        MemtoReg = 1'b0;
                        RegDst   = 1'b0;
                        RegWrite = 1'b0;
                    end
                endcase
                MemRead  = 1'b0;
                MemWrite = 1'b0;
            end
        endcase
    end
endmodule
