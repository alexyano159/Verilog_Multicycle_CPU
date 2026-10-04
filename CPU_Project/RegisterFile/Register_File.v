module Register_File #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5 
)(

    input clk,
    input reset, // asynchronous, active-high
    input write_en,
    input [ADDR_WIDTH-1:0] read_reg1,// 5 bits to address 32 registers
    input [ADDR_WIDTH-1:0] read_reg2,
    input [ADDR_WIDTH-1:0] write_reg,
    input [DATA_WIDTH-1:0] write_data, // 32 bits data input
    output [DATA_WIDTH-1:0] read_data1, // 32 bits data output
    output [DATA_WIDTH-1:0] read_data2 // 32 bits data output
);

    reg [DATA_WIDTH-1:0] registers [0:(1<<ADDR_WIDTH)-1]; // 32 registers of DATA_WIDTH bits each R0-R31

    // Asynchronous read
    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];

    // Synchronous write
    integer i; // reset loop index (module scope: Verilog-2001 forbids declarations in an unnamed block)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all registers to 0
            for (i = 0; i < (1<<ADDR_WIDTH); i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (write_en && write_reg != {ADDR_WIDTH{1'b0}}) begin
            // Write data to the specified register (except register 0)
            registers[write_reg] <= write_data;
        end
    end

endmodule
