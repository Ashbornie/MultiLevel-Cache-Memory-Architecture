`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2025 11:37:56
// Design Name: 
// Module Name: direct_mapped_low_power_fixed
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module direct_mapped_low_power_fixed (
    input  clk, reset,
    input  cpu_req, cpu_write,
    input  [31:0] cpu_addr,
    input  [31:0] cpu_write_data,

    output reg hit, miss,
    output reg [31:0] cpu_read_data,
    
    output reg [1:0] accessed_bank,

    output reg mem_req, mem_write,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_write_data,
    input  [127:0] mem_read_data
);

reg [127:0] cache_Memory [3:0][15:0];
reg [25:0] tag_memory   [3:0][15:0];
reg        valid_memory [3:0][15:0];

wire [25:0] tag         = cpu_addr[31:6];
wire [5:0]  index_full  = cpu_addr[9:4];
wire [1:0]  bank_sel    = index_full[5:4];
wire [3:0]  bank_index  = index_full[3:0];
wire [3:0]  byte_offset = cpu_addr[3:0];

wire [25:0] current_tag   = tag_memory[bank_sel][bank_index];
wire        current_valid = valid_memory[bank_sel][bank_index];
wire        cache_hit     = current_valid && (current_tag == tag);

// Now include *write miss* as well (write-allocate)
wire memory_write_enable = cpu_req && (
    (cpu_write && cache_hit) ||          // write hit
    (!cpu_write && !cache_hit) ||        // read miss
    (cpu_write && !cache_hit)            // write miss â†’ bring data into cache (write-allocate)
);

integer i, j;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                cache_Memory[i][j] <= 128'b0;
                tag_memory[i][j]   <= 26'b0;
                valid_memory[i][j] <= 1'b0;
                
            end
    end else if (memory_write_enable) begin
        if (cpu_write && cache_hit) begin
            case (byte_offset[3:2])
                2'b00: cache_Memory[bank_sel][bank_index][31:0]   <= cpu_write_data;
                2'b01: cache_Memory[bank_sel][bank_index][63:32]  <= cpu_write_data;
                2'b10: cache_Memory[bank_sel][bank_index][95:64]  <= cpu_write_data;
                2'b11: cache_Memory[bank_sel][bank_index][127:96] <= cpu_write_data;
            endcase
        end else begin
            // For read miss or write miss - bring in block from memory
            cache_Memory[bank_sel][bank_index] <= mem_read_data;
            tag_memory[bank_sel][bank_index]   <= tag;
            valid_memory[bank_sel][bank_index] <= 1'b1;

            // On write miss, also overwrite specific word after bringing in block
            if (cpu_write) begin
                case (byte_offset[3:2])
                    2'b00: cache_Memory[bank_sel][bank_index][31:0]   <= cpu_write_data;
                    2'b01: cache_Memory[bank_sel][bank_index][63:32]  <= cpu_write_data;
                    2'b10: cache_Memory[bank_sel][bank_index][95:64]  <= cpu_write_data;
                    2'b11: cache_Memory[bank_sel][bank_index][127:96] <= cpu_write_data;
                endcase
            end
        end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        hit <= 0;
        miss <= 0;
        mem_req <= 0;
        mem_write <= 0;
        mem_addr <= 0;
        mem_write_data <= 0;
        cpu_read_data <= 0;
        accessed_bank <= 0; // <-- Reset bank info
    end else if (cpu_req) begin
        accessed_bank <= bank_sel;
        hit <= cache_hit;
        miss <= !cache_hit;

        mem_req <= 0;
        mem_write <= 0;
        cpu_read_data <= 0;

        if (cache_hit) begin
            if (!cpu_write) begin
                case (byte_offset[3:2])
                    2'b00: cpu_read_data <= cache_Memory[bank_sel][bank_index][31:0];
                    2'b01: cpu_read_data <= cache_Memory[bank_sel][bank_index][63:32];
                    2'b10: cpu_read_data <= cache_Memory[bank_sel][bank_index][95:64];
                    2'b11: cpu_read_data <= cache_Memory[bank_sel][bank_index][127:96];
                endcase
            end else begin
                mem_req <= 1;
                mem_write <= 1;
                mem_addr <= cpu_addr;
                mem_write_data <= cpu_write_data;
            end
        end else begin
            mem_req <= 1;
            mem_write <= cpu_write;
            if (!cpu_write) begin
                mem_addr <= {tag, index_full, 4'b0000}; // block address
                case (byte_offset[3:2])
                    2'b00: cpu_read_data <= mem_read_data[31:0];
                    2'b01: cpu_read_data <= mem_read_data[63:32];
                    2'b10: cpu_read_data <= mem_read_data[95:64];
                    2'b11: cpu_read_data <= mem_read_data[127:96];
                endcase
            end else begin
                mem_addr <= cpu_addr;
                mem_write_data <= cpu_write_data;
            end
        end
    end
end

endmodule
