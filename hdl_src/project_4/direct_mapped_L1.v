`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.07.2025 19:19:09
// Design Name: 
// Module Name: direct_mapped_L1
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

module direct_mapped_L1(
  input  clk, reset,
  input  cpu_req, cpu_write,
  input  [31:0] cpu_addr,
  input  [31:0] cpu_write_data,
  output reg hit, miss,
  output reg [31:0] cpu_read_data,
  output reg mem_req, mem_write,
  output reg [31:0] mem_addr,       // Block-aligned address for L2/Main Memory
  output reg [31:0] mem_write_data, // 32-bit block data to L2/Main Memory
  input  [31:0] mem_read_data,      // 32-bit block data from L2/Main Memory
  output reg [31:0] hit_count,
  output reg [31:0] miss_count
);

  // Cache configuration for L1:
  // Block Size: 32 bits (4 bytes)
  // Number of Lines: 256 (2^8)
  // Total Cache Size: 256 lines * 4 bytes/line = 1024 bytes = 1 KB

  reg [31:0] cache_Memory [255:0]; // 256 lines, each storing a 32-bit block
  reg [21:0] tag_memory [255:0];   // 22-bit tag for each line
  reg valid_memory [255:0];        // Valid bit for each line

  // Address decomposition (matching L2's scheme and 32-bit block size)
  // cpu_addr[1:0]   : byte_offset (2 bits for 4-byte block)
  // cpu_addr[9:2]   : index (8 bits for 256 lines/sets)
  // cpu_addr[31:10] : tag (22 bits)
  wire [21:0] tag = cpu_addr[31:10];
  wire [7:0] index = cpu_addr[9:2];

  wire [21:0] current_tag = tag_memory[index];
  wire current_valid = valid_memory[index];
  wire cache_hit = current_valid && (current_tag == tag);

  integer i; // Loop variable for reset

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      // Initialize all cache lines, tags, and valid bits
      for (i = 0; i < 256; i = i + 1) begin
        tag_memory[i] <= 22'b0;
        valid_memory[i] <= 1'b0;
        cache_Memory[i] <= 32'b0;
      end
      // Initialize output signals and counters
      hit <= 0;
      miss <= 0;
      cpu_read_data <= 0; // Initialized to 0 here on reset
      mem_req <= 0;
      mem_write <= 0;
      mem_addr <= 0;
      mem_write_data <= 0;
      hit_count <= 0;
      miss_count <= 0;
    end else begin // Not reset
      // Default de-assertion for control signals
      hit <= 0;
      miss <= 0;
      mem_req <= 0;
      mem_write <= 0;

      if (cpu_req) begin // Only respond if CPU requests
        hit <= cache_hit;
        miss <= !cache_hit;

        if (cache_hit) begin // Cache Hit
          hit_count <= hit_count + 1; // Increment hit counter
          if (!cpu_write) begin // Read Hit
            // Read the 32-bit data directly from the cache line
            cpu_read_data <= cache_Memory[index]; // Assign cpu_read_data here
          end else begin // Write Hit (Write-Through Policy)
            // Update the cache line with the new data
            cache_Memory[index] <= cpu_write_data;
            // Propagate the write to the next level (L2/Main Memory)
            mem_req <= 1'b1;
            mem_write <= 1'b1;
            mem_addr <= cpu_addr;       // Send the original CPU address
            mem_write_data <= cpu_write_data; // Send the 32-bit write data
          end
        end else begin // Cache Miss
          miss_count <= miss_count + 1; // Increment miss counter
          mem_req <= 1'b1;              // Request data from the next level (L2/Main Memory)
          // For a miss, the address sent to the next level is the block-aligned address
          mem_addr <= {tag, index, 2'b00}; // Clear byte offset bits to get block address

          if (cpu_write) begin // Write Miss (Write-Through with Allocate-on-Write)
            mem_write <= 1'b1;             // Indicate a write operation to next level
            mem_write_data <= cpu_write_data; // Send the 32-bit write data
            // Allocate the block in the cache and write the data
            cache_Memory[index] <= cpu_write_data;
            tag_memory[index] <= tag;
            valid_memory[index] <= 1'b1;
          end else begin // Read Miss
            mem_write <= 0; // Not a write operation for the next level
            // On a read miss, fetch the entire 32-bit block from the next level
            // and store it in the cache.
            cache_Memory[index] <= mem_read_data; // Store the fetched 32-bit block
            tag_memory[index] <= tag;             // Update tag
            valid_memory[index] <= 1'b1;          // Set valid bit
            cpu_read_data <= mem_read_data;       // Provide the fetched data to the CPU
          end
        end
      end
      // No 'else' block for cpu_req == 0 to clear cpu_read_data.
      // This allows cpu_read_data to hold its last value.
    end
  end
endmodule
