module Cpu_Alu_tb;
    parameter DATA_WIDTH = 32;
    reg  signed [DATA_WIDTH-1:0] A;
    reg  signed [DATA_WIDTH-1:0] B;
    reg  [4:0] ALU_Sel;
    wire signed [DATA_WIDTH-1:0] ALU_Out;
    wire CarryOut, Zero, Overflow, Negative;

    integer i;

    Cpu_Alu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) alu (
        .A(A),
        .B(B),
        .ALU_Sel(ALU_Sel),
        .ALU_Out(ALU_Out),
        .CarryOut(CarryOut),
        .Zero(Zero),
        .Overflow(Overflow),
        .Negative(Negative)
    );
    // Random tests
    initial begin
        $display("----- RANDOM TESTS -----");
        for (i = 0; i < 16; i = i + 1) begin
            ALU_Sel = i[4:0];
            A = $random;
            B = $random;
            #5;
            $display("Sel=%b | A=%0d, B=%0d => Out=%0d | Carry=%b, Zero=%b, Overflow=%b, Neg=%b",
                     ALU_Sel, A, B, ALU_Out, CarryOut, Zero, Overflow, Negative);
        end
    end

    // Directed tests
    initial begin
        #100; 
        $display("\n DIRECTED TESTS");

        // ADD: max positive + 1 => overflow
        A = 32'h7FFFFFFF; B = 32'd1; ALU_Sel = 5'b00000; #5;
        $display("ADD: 0x7FFFFFFF+1 => Out=0x%0h, Overflow=%b (expected Overflow=1)", ALU_Out, Overflow);

        // SUB: 0 - 1 = -1
        A = 32'd0; B = 32'd1; ALU_Sel = 5'b00001; #5;
        $display("SUB: 0-1 => Out=%0d (expected -1)", ALU_Out);

        // AND
        A = 32'hFFFFFFFF; B = 32'h00000001; ALU_Sel = 5'b00010; #5;
        $display("AND: 0xFFFFFFFF & 0x00000001 => Out=0x%0h (expected 0x1)", ALU_Out);

        // OR
        A = 32'h80000000; B = 32'h00000001; ALU_Sel = 5'b00011; #5;
        $display("OR: 0x80000000 | 0x1 => Out=0x%0h (expected 0x80000001)", ALU_Out);

        // XOR
        A = 32'hAAAAAAAA; B = 32'h55555555; ALU_Sel = 5'b00100; #5;
        $display("XOR: 0xAAAAAAAA ^ 0x55555555 => Out=0x%0h (expected 0xFFFFFFFF)", ALU_Out);

        // SLT: (5 < 10) => 1
        A = 32'd5; B = 32'd10; ALU_Sel = 5'b00110; #5;
        $display("SLT: 5<10 => Out=%0d (expected 1)", ALU_Out);

        // Shift left: 0x80000001 << 1 = 0x00000002, CarryOut=1
        A = 32'h80000001; B = 0; ALU_Sel = 5'b00111; #5;
        $display("SLL: 0x80000001<<1 => Out=0x%0h, Carry=%b (expected 0x00000002, Carry=1)", ALU_Out, CarryOut);

        // Rotate right: 0x00000001 => 0x80000000, Carry=1
        A = 32'h00000001; B = 0; ALU_Sel = 5'b01101; #5; // ROR opcode
        $display("ROR: 0x1 => Out=0x%0h, Carry=%b (expected 0x80000000, Carry=1)", ALU_Out, CarryOut);

        $finish;
    end

endmodule
