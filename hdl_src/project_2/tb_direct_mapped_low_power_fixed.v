`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2025 11:39:14
// Design Name: 
// Module Name: tb_direct_mapped_low_power_fixed
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

module tb_direct_mapped_low_power_fixed;

  reg clk = 0;
  reg reset = 1;
  reg cpu_req, cpu_write;
  reg [31:0] cpu_addr;
  reg [31:0] cpu_write_data;
  wire [31:0] cpu_read_data;
  wire hit, miss;
  wire mem_req, mem_write;
  wire [31:0] mem_addr, mem_write_data;
  wire [1:0] accessed_bank;
  reg [127:0] mem_read_data;

  // Instantiate your module
  direct_mapped_low_power_fixed dut (
    .clk(clk),
    .reset(reset),
    .cpu_req(cpu_req),
    .cpu_write(cpu_write),
    .cpu_addr(cpu_addr),
    .cpu_write_data(cpu_write_data),
    .cpu_read_data(cpu_read_data),
    .hit(hit),
    .miss(miss),
    .accessed_bank(accessed_bank),
    .mem_req(mem_req),
    .mem_write(mem_write),
    .mem_addr(mem_addr),
    .mem_write_data(mem_write_data),
    .mem_read_data(mem_read_data)
  );

  // Clock generation
  always #5 clk = ~clk;

  initial begin
    $dumpfile("cache_test.vcd");
    $dumpvars(0, tb_direct_mapped_low_power_fixed);

    // 1. Reset
    reset = 1; cpu_req = 0;
    #20;
    reset = 0;

    // 2. First access - READ MISS
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 0;
    cpu_addr = 32'h0000_0050;  // Block aligned
    mem_read_data = 128'hDEADBEEF_CAFEBABE_12345678_90ABCDEF;
    @(negedge clk);
    cpu_req = 0;

    // 3. Second access - READ HIT
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 0;
    cpu_addr = 32'h0000_0050;
    @(negedge clk);
    cpu_req = 0;

    // 4. Third access - WRITE HIT
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 1;
    cpu_addr = 32'h0000_0050;
    cpu_write_data = 32'hAAAA_BBBB;
    @(negedge clk);
    cpu_req = 0;

    // 5. Fourth access - WRITE MISS
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 1;
    cpu_addr = 32'h0000_00A0; // New block
    cpu_write_data = 32'hCCCC_DDDD;
    mem_read_data = 128'h11112222_33334444_55556666_77778888; // For cache fill
    @(negedge clk);
    cpu_req = 0;

    // 6. Fifth access - READ HIT
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 0;
    cpu_addr = 32'h0000_00A0;
    @(negedge clk);
    cpu_req = 0;
    
    // 7. Access bank 1
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 0;
    cpu_addr = 32'h0000_0150; // bank_sel = 2'b01
    mem_read_data = 128'hAAAAAAAA_BBBBBBBB_CCCCCCCC_DDDDDDDD;
    @(negedge clk);
    cpu_req = 0;

    // 8. Access bank 2
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 0;
    cpu_addr = 32'h0000_0250; // bank_sel = 2'b10
    mem_read_data = 128'h11111111_22222222_33333333_44444444;
    @(negedge clk);
    cpu_req = 0;

    // 9. Access bank 3
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 0;
    cpu_addr = 32'h0000_0350; // bank_sel = 2'b11
    mem_read_data = 128'h99999999_88888888_77777777_66666666;
    @(negedge clk);
    cpu_req = 0;
    
        // 8. Access bank 2
    @(negedge clk);
    cpu_req = 1;
    cpu_write = 0;
    cpu_addr = 32'h0000_0250; // bank_sel = 2'b10
    mem_read_data = 128'h11111111_22222222_33333333_44444444;
    @(negedge clk);
    cpu_req = 0;

    #50;
    $finish;
  end

endmodule

