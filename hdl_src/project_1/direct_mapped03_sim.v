`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.06.2025 21:59:03
// Design Name: 
// Module Name: direct_mapped03_sim
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


`timescale 1ns / 1ps
module direct_mapped03_sim;

  reg clk = 0;
  reg reset = 0;
  reg cpu_req = 0;
  reg cpu_write = 0;
  reg [31:0] cpu_addr = 0;
  reg [31:0] cpu_write_data = 0;
  wire hit;
  wire miss;
  wire [31:0] cpu_read_data;
  wire mem_req;
  wire mem_write;
  wire [31:0] mem_addr;
  wire [31:0] mem_write_data;
  reg [127:0] mem_read_data;
  wire [31:0] hit_count;
  wire [31:0] miss_count;

  integer logfile;

  direct_mapped03 uut (
    .clk(clk), .reset(reset), .cpu_req(cpu_req), .cpu_write(cpu_write),
    .cpu_addr(cpu_addr), .cpu_write_data(cpu_write_data),
    .hit(hit), .miss(miss), .cpu_read_data(cpu_read_data),
    .mem_req(mem_req), .mem_write(mem_write),
    .mem_addr(mem_addr), .mem_write_data(mem_write_data),
    .mem_read_data(mem_read_data),
    .hit_count(hit_count), .miss_count(miss_count)
  );

  always #5 clk = ~clk;

  initial begin
    logfile = $fopen("cache_metrics.txt", "w");
    if (!logfile) $display("Failed to open log file");
  end

  always @(posedge clk) begin
    $fwrite(logfile, "Time: %0t | Addr: 0x%08h | Write: %0d | WriteData: 0x%08h | ReadData: 0x%08h | Hit: %0d | Miss: %0d | HitCount: %0d | MissCount: %0d | HitRate: %f\n",
            $time, cpu_addr, cpu_write, cpu_write_data, cpu_read_data,
            hit, miss, hit_count, miss_count,
            (hit_count + miss_count) ? (hit_count * 1.0 / (hit_count + miss_count)) : 0);
  end

  task perform_read;
    input [31:0] addr;
    input [127:0] mock_data;
    begin
      cpu_write = 0;
      cpu_addr = addr;
      mem_read_data = mock_data;
      cpu_req = 1; #10;
      cpu_req = 0; #10;
    end
  endtask

  task perform_write;
    input [31:0] addr;
    input [31:0] data;
    begin
      cpu_write = 1;
      cpu_addr = addr;
      cpu_write_data = data;
      cpu_req = 1; #10;
      cpu_req = 0;
      cpu_write = 0; #10;
    end
  endtask

  initial begin
    reset = 1; #10; reset = 0; #10;

    perform_read(32'h0000_0040, 128'h11111111_22222222_33333333_44444444); // miss
    perform_read(32'h0000_0040, 128'h00000000); // hit
    perform_write(32'h0000_0040, 32'hAABBCCDD); // hit

    perform_read(32'h0000_0140, 128'h55555555_66666666_77777777_88888888); // miss
    perform_read(32'h0000_0140, 128'h00000000); // hit
    perform_write(32'h0000_0140, 32'hFACEFACE); // hit

    perform_read(32'h0000_0200, 128'h99999999_AAAAAAAA_BBBBBBBB_CCCCCCCC); // miss
    perform_read(32'h0000_0040, 128'h00000000); // hit
    perform_read(32'h0000_0300, 128'hDDDDDDDD_EEEEEEEE_FFFFFFFF_00000000); // miss
    perform_read(32'h0000_0140, 128'h00000000); // hit

    perform_read(32'h0000_0400, 128'h12341234_56785678_9ABC9ABC_DEF0DEF0); // miss
    perform_read(32'h0000_0400, 128'h00000000); // hit
    perform_write(32'h0000_0400, 32'hDEADBEEF); // hit

    perform_read(32'h0000_0500, 128'h01010101_02020202_03030303_04040404); // miss
    perform_read(32'h0000_0600, 128'h11111111_12121212_13131313_14141414); // miss
    perform_read(32'h0000_0500, 128'h00000000); // hit
    perform_read(32'h0000_0040, 128'h00000000); // hit
    perform_write(32'h0000_0040, 32'hDEEDBEEF); // hit

    #20;
    $fclose(logfile);
    $finish;
  end

endmodule
