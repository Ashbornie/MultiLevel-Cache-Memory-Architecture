`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.07.2025 19:19:37
// Design Name: 
// Module Name: set_associative_fifo
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

module set_associative_fifo(
  input clk, reset,
  input cpu_req, cpu_write,
  input [31:0] cpu_addr,
  input [31:0] cpu_write_data,
  output reg [31:0] cpu_read_data,
  output reg hit1, hit2, hit3, hit4,
  output reg HIT, MISS,
  output reg mem_req, mem_write,
  output reg [31:0] mem_addr,
  output reg [31:0] mem_write_data,
  input [31:0] mem_read_data,
  // --- ADDED THESE OUTPUT PORTS ---
  output reg [1:0] fifo_counter_out,
  output reg [31:0] hit_count,
  output reg [31:0] miss_count
);

  // Cache configuration for L2:
  // Block Size: 32 bits (4 bytes)
  // Number of Sets: 256 (2^8)
  // Number of Ways: 4
  // Total Cache Size: 4 ways * 256 sets * 4 bytes/line = 4096 bytes = 4 KB

  reg valid1[0:255], valid2[0:255], valid3[0:255], valid4[0:255]; // Valid bits for each way and set
  reg [21:0] tag1[0:255], tag2[0:255], tag3[0:255], tag4[0:255]; // Tags for each way and set
  reg [31:0] data1[0:255], data2[0:255], data3[0:255], data4[0:255]; // Data for each way and set (32-bit blocks)
  reg [1:0] fifo_counter[0:255]; // FIFO replacement counter for each set

  // Combinational signals based on current cpu_addr (from L1)
  // cpu_addr[1:0]   : byte_offset (2 bits for 4-byte block)
  // cpu_addr[9:2]   : index (8 bits for 256 sets)
  // cpu_addr[31:10] : tag (22 bits)
  wire [21:0] tag = cpu_addr[31:10];
  wire [7:0] index = cpu_addr[9:2];

  // Combinational hit checks for each way
  wire cache_hit1_comb = (valid1[index] == 1'b1) && (tag1[index] == tag);
  wire cache_hit2_comb = (valid2[index] == 1'b1) && (tag2[index] == tag);
  wire cache_hit3_comb = (valid3[index] == 1'b1) && (tag3[index] == tag);
  wire cache_hit4_comb = (valid4[index] == 1'b1) && (tag4[index] == tag);

  // Overall combinatorial hit
  wire cache_hit_comb = cache_hit1_comb || cache_hit2_comb || cache_hit3_comb || cache_hit4_comb;

  integer i; // Loop variable for reset

  always @(posedge clk or posedge reset) begin
    if(reset) begin
      // Initialize all cache memories, tags, valid bits, and FIFO counters
      for(i = 0; i < 256; i = i + 1) begin
        valid1[i] <= 0; valid2[i] <= 0; valid3[i] <= 0; valid4[i] <= 0;
        tag1[i] <= 0; tag2[i] <= 0; tag3[i] <= 0; tag4[i] <= 0;
        data1[i] <= 0; data2[i] <= 0; data3[i] <= 0; data4[i] <= 0;
        fifo_counter[i] <= 0;
      end
      // Initialize output signals and counters
      hit1 <= 0; hit2 <= 0; hit3 <= 0; hit4 <= 0; HIT <= 0; MISS <= 0;
      mem_req <= 0; mem_write <= 0;
      mem_addr <= 0; mem_write_data <= 0;
      cpu_read_data <= 0; // Initialized to 0 here on reset
      hit_count <= 0;
      miss_count <= 0;
      fifo_counter_out <= 0;
    end
    else begin // Not reset
      // Default de-assertion for single-cycle control signals
      hit1 <= 0; hit2 <= 0; hit3 <= 0; hit4 <= 0; HIT <= 0; MISS <= 0;
      mem_req <= 0;
      mem_write <= 0;

      if(cpu_req) begin // Only respond if CPU (L1) requests
        hit1 <= cache_hit1_comb;
        hit2 <= cache_hit2_comb;
        hit3 <= cache_hit3_comb;
        hit4 <= cache_hit4_comb;
        HIT <= cache_hit_comb;     // Overall L2 hit status
        MISS <= ~cache_hit_comb; // Overall L2 miss status

        if(cache_hit_comb) begin // L2 Hit
          hit_count <= hit_count + 1; // Increment L2 hit counter

          if(!cpu_write) begin // Read Hit
            // Read the 32-bit data from the appropriate way
            if(cache_hit1_comb) cpu_read_data <= data1[index];
            else if(cache_hit2_comb) cpu_read_data <= data2[index];
            else if(cache_hit3_comb) cpu_read_data <= data3[index];
            else if(cache_hit4_comb) cpu_read_data <= data4[index];
          end else begin // Write Hit (Write-Through Policy)
            mem_req <= 1; // Request write to main memory
            mem_write <= 1;
            mem_addr <= cpu_addr; // Original CPU address for main memory
            mem_write_data <= cpu_write_data; // Data to write to main memory

            // Update the cache line in the appropriate way
            if(cache_hit1_comb) data1[index] <= cpu_write_data;
            else if(cache_hit2_comb) data2[index] <= cpu_write_data;
            else if(cache_hit3_comb) data3[index] <= cpu_write_data;
            else if(cache_hit4_comb) data4[index] <= cpu_write_data;
          end
        end else begin // L2 Miss
          miss_count <= miss_count + 1; // Increment L2 miss counter
          mem_req <= 1;                 // Request data from main memory
          mem_addr <= cpu_addr;         // Send original CPU address to main memory

          if(cpu_write) begin // Write Miss (Write-Through with Allocate-on-Write)
            mem_write <= 1;
            mem_write_data <= cpu_write_data; // Data to write to main memory
            // Allocate the block in the cache using FIFO replacement
            case(fifo_counter[index])
              2'd0: begin data1[index] <= cpu_write_data; tag1[index] <= tag; valid1[index] <= 1; end
              2'd1: begin data2[index] <= cpu_write_data; tag2[index] <= tag; valid2[index] <= 1; end
              2'd2: begin data3[index] <= cpu_write_data; tag3[index] <= tag; valid3[index] <= 1; end
              2'd3: begin data4[index] <= cpu_write_data; tag4[index] <= tag; valid4[index] <= 1; end
            endcase
          end else begin // Read Miss
            // On a read miss, fetch the block from main memory
            cpu_read_data <= mem_read_data; // Provide the fetched data to L1
            // Store the fetched block in the cache using FIFO replacement
            case(fifo_counter[index])
              2'd0: begin data1[index] <= mem_read_data; tag1[index] <= tag; valid1[index] <= 1; end
              2'd1: begin data2[index] <= mem_read_data; tag2[index] <= tag; valid2[index] <= 1; end
              2'd2: begin data3[index] <= mem_read_data; tag3[index] <= tag; valid3[index] <= 1; end
              2'd3: begin data4[index] <= mem_read_data; tag4[index] <= tag; valid4[index] <= 1; end
            endcase
          end
          // Update FIFO counter for replacement
          fifo_counter[index] <= (fifo_counter[index] == 3) ? 0 : fifo_counter[index] + 1;
        end
      end
      // No 'else' block for cpu_req == 0 to clear cpu_read_data.
      // This allows cpu_read_data to hold its last value.
      fifo_counter_out <= fifo_counter[index];
    end
  end
endmodule
