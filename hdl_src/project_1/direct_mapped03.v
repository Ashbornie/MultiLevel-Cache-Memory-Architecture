`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2025 21:57:54
// Design Name: 
// Module Name: direct_mapped03
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


module direct_mapped03(
  input  clk, reset,
  input  cpu_req, cpu_write,
  input  [31:0] cpu_addr,
  input  [31:0] cpu_write_data,
  output reg hit, miss,
  output reg [31:0] cpu_read_data,
  output reg mem_req, mem_write,
  output reg [31:0] mem_addr,
  output reg [31:0] mem_write_data,
  input  [127:0] mem_read_data,
  output reg [31:0] hit_count,
  output reg [31:0] miss_count
);

reg [127:0] cache_Memory [1023:0];
reg [17:0] tag_memory [1023:0];
reg valid_memory [1023:0];

wire [17:0] tag = cpu_addr[31:14];
wire [9:0] index = cpu_addr[13:4];
wire [3:0] byte_offset = cpu_addr[3:0];

wire [17:0] current_tag = tag_memory[index];
wire current_valid = valid_memory[index];
wire cache_hit = current_valid && (current_tag == tag);

integer i;

always @(posedge clk or posedge reset) begin
  if (reset) begin
    for (i = 0; i < 1024; i = i + 1) begin
      tag_memory[i] <= 18'b0;
      valid_memory[i] <= 1'b0;
      cache_Memory[i] <= 128'b0;
    end
    hit <= 0;
    miss <= 0;
    cpu_read_data <= 0;
    mem_req <= 0;
    mem_write <= 0;
    mem_addr <= 0;
    mem_write_data <= 0;
    hit_count <= 0;
    miss_count <= 0;
  end else if (cpu_req) begin
    hit <= cache_hit;
    miss <= !cache_hit;
    cpu_read_data <= 0;
    mem_req <= 0;
    mem_write <= 0;

    if (cache_hit) begin
      hit_count <= hit_count + 1;
      if (!cpu_write) begin
        case (byte_offset[3:2])
          2'b00: cpu_read_data <= cache_Memory[index][31:0];
          2'b01: cpu_read_data <= cache_Memory[index][63:32];
          2'b10: cpu_read_data <= cache_Memory[index][95:64];
          2'b11: cpu_read_data <= cache_Memory[index][127:96];
        endcase
      end else begin
        case (byte_offset[3:2])
          2'b00: cache_Memory[index][31:0] <= cpu_write_data;
          2'b01: cache_Memory[index][63:32] <= cpu_write_data;
          2'b10: cache_Memory[index][95:64] <= cpu_write_data;
          2'b11: cache_Memory[index][127:96] <= cpu_write_data;
        endcase
        mem_req <= 1'b1;
        mem_write <= 1'b1;
        mem_addr <= cpu_addr;
        mem_write_data <= cpu_write_data;
      end
    end else begin
      miss_count <= miss_count + 1;
      mem_req <= 1'b1;
      mem_write <= cpu_write;
      if (!cpu_write) begin
        mem_addr <= {tag, index, 4'b0000};
        cache_Memory[index] <= mem_read_data;
        tag_memory[index] <= tag;
        valid_memory[index] <= 1'b1;
        case (byte_offset[3:2])
          2'b00: cpu_read_data <= mem_read_data[31:0];
          2'b01: cpu_read_data <= mem_read_data[63:32];
          2'b10: cpu_read_data <= mem_read_data[95:64];
          2'b11: cpu_read_data <= mem_read_data[127:96];
        endcase
      end
    end
  end
end

endmodule
