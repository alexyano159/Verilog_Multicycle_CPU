module CPU_Top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
) (
    input clk,
    input reset,// Active-high reset
    // Interfaces to Instruction Memory and Data Memory
    input [DATA_WIDTH-1:0] instruction_data,// Instruction from ROM
    input [DATA_WIDTH-1:0] read_data,// Data from RAM
    output [ADDR_WIDTH-1:0] instruction_address,// Address to ROM
    output [ADDR_WIDTH-1:0] data_address,// Address to RAM
    output [DATA_WIDTH-1:0] write_data,// Data to RAM
    output write_enable// RAM Write Enable

    // Debugging Outputs(for waveform viewing)
   `ifdef DEBUG
    , output reg_write_enable // RegWrite signal from CU
    , output reg_read_enable  
    , output [DATA_WIDTH-1:0] alu_result_debug
    , output [DATA_WIDTH-1:0] pc_current_debug
    , output [DATA_WIDTH-1:0] reg_data1_debug
    , output [DATA_WIDTH-1:0] reg_data2_debug
    , output [DATA_WIDTH-1:0] pc_debug
    , output [DATA_WIDTH-1:0] mdr_debug
    , output [DATA_WIDTH-1:0] ir_debug
    , output [ADDR_WIDTH-1:0] mar_debug
    , output [DATA_WIDTH-1:0] b_debug
    , output [DATA_WIDTH-1:0] a_debug
    , output [4:0] AluControl_debug
    , output AluSrc_debug
    , output MemtoReg_debug
    , output RegDst_debug
    , output RegWrite_debug
    , output MemRead_debug
    , output MemWrite_debug
    , output Jump_debug
    , output Branch_debug
`endif
);
// Internal signals and wiring
wire [DATA_WIDTH-1:0] alu_A, alu_B, write_back, address_bus, pc_next, pc_current;
wire [DATA_WIDTH-1:0] jump_target, branch_target;
wire [DATA_WIDTH-1:0] reg_data1, reg_data2, mdr, ir, immediate;
wire [ADDR_WIDTH-1:0] mar;
wire [4:0] rs1_addr, rs2_addr, rd_addr;
wire ir_load, pc_inc, pc_load, mar_load, mdr_load;
wire [DATA_WIDTH-1:0] alu_result;
wire alu_carry, alu_zero, alu_overflow, alu_negative;
wire [4:0] AluControl;
wire AluSrc, MemtoReg, RegDst, RegWrite, MemRead, MemWrite, Jump, Branch, branch_taken;
wire [3:0] current_state;

// Instantiate components

// ALU
Cpu_Alu #(.DATA_WIDTH(DATA_WIDTH)) alu (
    .A(alu_A),
    .B(alu_B),
    .ALU_Sel(AluControl),
    .ALU_Out(alu_result),
    .CarryOut(alu_carry),
    .Zero(alu_zero),
    .Overflow(alu_overflow),
    .Negative(alu_negative)
);

// Register File
Register_File #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(5)) reg_file (
    .clk(clk),
    .reset(reset),
    .write_en(RegWrite),
    .read_reg1(rs1_addr),
    .read_reg2(rs2_addr),
    .write_reg(rd_addr),
    .write_data(write_back),
    .read_data1(reg_data1),
    .read_data2(reg_data2)
);

// Instruction Register
Instruction_Register #(.DATA_WIDTH(DATA_WIDTH)) ir_reg (
    .clk(clk),
    .reset(reset),
    .load(ir_load),
    .data_in(instruction_data),
    .instruction(ir)
);

// Program Counter
Program_Counter #(.DATA_WIDTH(DATA_WIDTH)) pc_reg (
    .clk(clk),
    .reset(reset),
    .increment(pc_inc),
    .load(pc_load),
    .pc_in(pc_next),
    .pc_out(pc_current)
);

// Memory Address Register
Memory_Address_Register #(.ADDR_WIDTH(ADDR_WIDTH)) mar_reg (
    .clk(clk),
    .reset(reset),
    .load(mar_load),
    .address_in(address_bus[ADDR_WIDTH-1:0]),
    .address_out(mar)
);

// Memory Data Register
Memory_Data_Register #(.DATA_WIDTH(DATA_WIDTH)) mdr_reg (
    .clk(clk),
    .reset(reset),
    .data_in(read_data),
    .write_enable(mdr_load),
    .data_out(mdr)
);

// Control Unit
Control_Unit cu (
    .clk(clk),
    .reset(reset),
    .instruction(ir),
    .zero_flag(alu_zero),
    .negative_flag(alu_negative),
    .overflow_flag(alu_overflow),
    .AluControl(AluControl),
    .AluSrc(AluSrc),
    .MemtoReg(MemtoReg),
    .RegDst(RegDst),
    .RegWrite(RegWrite),
    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .Jump(Jump),
    .Branch(Branch),
    .branch_taken(branch_taken),
    .current_state(current_state)
);
// Assign outputs to memory interfaces
assign rd_addr = ir[26:22];   // according to instruction format
assign rs1_addr = ir[21:17]; // according to instruction format
assign rs2_addr = ir[16:12]; // according to instruction format
assign immediate = {{20{ir[11]}}, ir[11:0]}; // Sign-extended immediate
// JUMP: PC = imm * 4 (imm is the target's word index in the instruction memory).
assign jump_target = {{(DATA_WIDTH-14){1'b0}}, ir[11:0], 2'b00};
// Branch: target = (address of the branch) + 4 + imm * 4. The PC was already
// incremented in DECODE, so in EXECUTE pc_current is (address of the branch) + 4.
assign branch_target = pc_current + (immediate << 2);
assign alu_A = reg_data1;// Always from register
assign alu_B = AluSrc ? immediate : reg_data2;// From register or immediate
assign write_back = MemtoReg ? mdr : alu_result;// From memory or ALU
assign address_bus = reg_data1 + immediate; // Effective address for LOAD/STORE: rs1 + sign-extended imm
// Next PC logic
assign pc_next = Jump ? jump_target :
                 (Branch && branch_taken) ? branch_target :
                 pc_current + 4;
assign instruction_address=pc_current[9:2];// Address to Instruction Memory
assign data_address=mar[7:0];// Address to RAM from MAR
assign write_data=reg_data2;// Data to write to RAM from register
assign write_enable=MemWrite;// RAM Write Enable
// Control signals for registers
assign ir_load = current_state == 4'b0000; // Load IR in FETCH state
assign pc_inc = current_state == 4'b0001; // PC increment in DECODE state
assign pc_load = Jump || (Branch && branch_taken); // Load PC on jump or taken branch
// The MAR captures the effective address at the end of EXECUTE, so it is
// stable for the whole MEMORY cycle, when the data memory is read or written.
// (Loading it together with the access itself would let the first cycle of
// the access use the previous, stale address.)
assign mar_load = current_state == 4'b0010; // EXECUTE
assign mdr_load = MemRead; // Load MDR on memory read
// Debugging outputs
`ifdef DEBUG
assign pc_current_debug   = pc_current;
assign reg_data1_debug    = reg_data1;
assign reg_data2_debug    = reg_data2;
assign alu_result_debug   = alu_result;
assign mdr_debug          = mdr;
assign ir_debug           = ir;
assign mar_debug          = mar;
assign reg_write_enable   = RegWrite;
assign reg_read_enable    = MemRead; // data-memory read strobe (MDR load)
assign pc_debug           = pc_current;
assign b_debug            = alu_B;
assign a_debug            = alu_A;
assign AluControl_debug   = AluControl;
assign AluSrc_debug       = AluSrc;
assign MemtoReg_debug     = MemtoReg;
assign RegDst_debug       = RegDst;
assign RegWrite_debug     = RegWrite;
assign MemRead_debug      = MemRead;
assign MemWrite_debug     = MemWrite;
assign Jump_debug         = Jump;
assign Branch_debug       = Branch;
`endif

endmodule
