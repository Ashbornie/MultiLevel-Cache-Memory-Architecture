`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.07.2025 19:20:03
// Design Name: 
// Module Name: L1_L2_Cache_System
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

module L1_L2_Cache_System (
  input clk, reset,
  input cpu_req, cpu_write,
  input [31:0] cpu_addr,
  input [31:0] cpu_write_data,
  output wire [31:0] cpu_read_data, // Data read by the CPU
  output wire L1_hit, L1_miss,       // L1 hit/miss status
  output wire L2_hit, L2_miss,       // L2 hit/miss status
  output wire [31:0] L1_hit_count,
  output wire [31:0] L1_miss_count,
  output wire [31:0] L2_hit_count,
  output wire [31:0] L2_miss_count,

  // Interface to Main Memory (originates from L2)
  output wire mem_req_to_main,
  output wire mem_write_to_main,
  output wire [31:0] mem_addr_to_main,
  output wire [31:0] mem_write_data_to_main, // 32-bit block to main memory
  input [31:0] mem_read_data_from_main      // 32-bit block from main memory
);

  // Wires for L1 to L2 interface
  wire L1_to_L2_req;        // L1's request to L2 (asserted on L1 miss or write-through)
  wire L1_to_L2_write;      // L1's write signal to L2
  wire [31:0] L1_to_L2_addr;       // Address L1 sends to L2
  wire [31:0] L1_to_L2_write_data; // Data L1 sends to L2 (32-bit word)

  // Wire for L2 to L1 interface (L2's cpu_read_data becomes L1's mem_read_data)
  wire [31:0] L2_to_L1_read_data; // 32-bit block L2 provides to L1

  // Instantiate L1 Cache (Direct Mapped)
  direct_mapped_L1 L1_Cache (
    .clk(clk),
    .reset(reset),
    .cpu_req(cpu_req),             // CPU request to L1
    .cpu_write(cpu_write),         // CPU write signal to L1
    .cpu_addr(cpu_addr),           // CPU address to L1
    .cpu_write_data(cpu_write_data), // CPU write data to L1
    .hit(L1_hit),                  // L1 hit status
    .miss(L1_miss),                // L1 miss status
    .cpu_read_data(cpu_read_data), // Final data read by CPU from L1
    .mem_req(L1_to_L2_req),        // L1 requests to L2
    .mem_write(L1_to_L2_write),    // L1 writes to L2
    .mem_addr(L1_to_L2_addr),      // Address L1 sends to L2
    .mem_write_data(L1_to_L2_write_data), // Data L1 sends to L2
    .mem_read_data(L2_to_L1_read_data),   // Data L1 receives from L2
    .hit_count(L1_hit_count),
    .miss_count(L1_miss_count)
  );

  // Wires for L2 to Main Memory interface
  wire L2_to_Main_req;        // L2's request to Main Memory
  wire L2_to_Main_write;      // L2's write signal to Main Memory
  wire [31:0] L2_to_Main_addr;       // Address L2 sends to Main Memory
  wire [31:0] L2_to_Main_write_data; // Data L2 sends to Main Memory (32-bit block)

  // Instantiate L2 Cache (Set Associative)
  set_associative_fifo L2_Cache (
    .clk(clk),
    .reset(reset),
    .cpu_req(L1_to_L2_req),        // L2 is requested by L1
    .cpu_write(L1_to_L2_write),    // L2 performs write as requested by L1
    .cpu_addr(L1_to_L2_addr),      // Address L2 receives from L1
    .cpu_write_data(L1_to_L2_write_data), // Data L2 receives from L1
    .cpu_read_data(L2_to_L1_read_data),   // Data L2 provides back to L1
    .hit1(), .hit2(), .hit3(), .hit4(), // Internal hit signals, not exposed
    .HIT(L2_hit),                  // L2 overall hit status
    .MISS(L2_miss),                // L2 overall miss status
    .mem_req(L2_to_Main_req),      // L2 requests to Main Memory
    .mem_write(L2_to_Main_write),  // L2 writes to Main Memory
    .mem_addr(L2_to_Main_addr),    // Address L2 sends to Main Memory
    .mem_write_data(L2_to_Main_write_data), // Data L2 sends to Main Memory
    .mem_read_data(mem_read_data_from_main), // Data L2 receives from Main Memory
    .fifo_counter_out(),           // Internal FIFO counter, not exposed
    .hit_count(L2_hit_count),
    .miss_count(L2_miss_count)
  );

  // Connect L2's memory interface to the main memory ports of this top module
  assign mem_req_to_main = L2_to_Main_req;
  assign mem_write_to_main = L2_to_Main_write;
  assign mem_addr_to_main = L2_to_Main_addr;
  assign mem_write_data_to_main = L2_to_Main_write_data;

endmodule
