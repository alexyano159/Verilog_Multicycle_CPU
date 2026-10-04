module Cpu_Alu #(
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] A,// Operand A
    input [DATA_WIDTH-1:0] B,// Operand B
    input [4:0] ALU_Sel,//operation Select
    output reg [DATA_WIDTH-1:0] ALU_Out,// ALU Result
    output reg CarryOut, Zero, Overflow, Negative // Status Flags
);

    always @(*) begin
        CarryOut = 0;
        Zero = 0;
        Overflow = 0;
        Negative = 0;
        case (ALU_Sel)
            5'b00000: {CarryOut, ALU_Out} = A + B; // Addition
            5'b00001: {CarryOut, ALU_Out} = A - B; // Subtraction
            5'b00010: ALU_Out = A & B; // AND
            5'b00011: ALU_Out = A | B; // OR
            5'b00100: ALU_Out = A ^ B; // XOR
            5'b00101: ALU_Out = ~(A | B); // NOR
            5'b00110: ALU_Out = ($signed(A) < $signed(B)) ? {{(DATA_WIDTH-1){1'b0}}, 1'b1} : {DATA_WIDTH{1'b0}}; // Set on less than-SLT (signed): 1 or 0
            5'b00111: begin
                CarryOut = A[DATA_WIDTH-1];
                ALU_Out = A << 1; // Shift left logical-SLL
            end
            5'b01000: begin
                CarryOut = A[0];
                ALU_Out = A >> 1; // Shift right logical-SRL
            end
            5'b01001: ALU_Out = ~A; // NOT
            5'b01010: ALU_Out = A + 1; // Increment
            5'b01011: ALU_Out = A - 1; // Decrement
            5'b01100: begin
                CarryOut = A[DATA_WIDTH-1];
                ALU_Out = {A[DATA_WIDTH-2:0], A[DATA_WIDTH-1]}; // Rotate left-ROL
            end
            5'b01101: begin
                CarryOut = A[0];
                ALU_Out = {A[0], A[DATA_WIDTH-1:1]}; // Rotate right-ROR
            end
            5'b01110: ALU_Out = B; // Pass-through B
            5'b01111: ALU_Out = A; // Pass-through A
            // 5'b10000: LOAD operation handled in memory stage
            // 5'b10001: STORE operation handled in memory stage
            // 5'b10010: JUMP operation handled in control unit 
            // 5'b10011: BEQ operation handled in control unit
            // 5'b10100: BNE operation handled in control unit
            // 5'b10101: BLT operation handled in control unit
            // 5'b10110: BGT operation handled in control unit
            // 5'b10111: BGE operation handled in control unit
            // 5'b11000: BLE operation handled in control unit
            
            default: ALU_Out = 32'b0;
        endcase
        Zero = (ALU_Out == 32'b0);
        Negative = ALU_Out[31];
        if (ALU_Sel == 5'b00000)
            Overflow = (A[DATA_WIDTH-1] == B[DATA_WIDTH-1]) && (ALU_Out[DATA_WIDTH-1] != A[DATA_WIDTH-1]);
        else if (ALU_Sel == 5'b00001)
            Overflow = (A[DATA_WIDTH-1] != B[DATA_WIDTH-1]) && (ALU_Out[DATA_WIDTH-1] != A[DATA_WIDTH-1]);
        else if (ALU_Sel == 5'b01010)
            Overflow = (A == {1'b0, {(DATA_WIDTH-1){1'b1}}}); // INC overflows at the largest positive value (0x7FFFFFFF)
        else if (ALU_Sel == 5'b01011)
            Overflow = (A == {1'b1, {(DATA_WIDTH-1){1'b0}}}); // DEC overflows at the most negative value (0x80000000)
    end

endmodule