`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.06.2025 19:46:21
// Design Name: 
// Module Name: set_associative_fifo_tb
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
module set_associative_fifo_tb;

  reg clk = 0, reset = 1;
  reg cpu_req = 0, cpu_write = 0;
  reg [31:0] cpu_addr = 0;
  reg [31:0] cpu_write_data = 32'hABCD1234;
  reg [31:0] mem_read_data;

  wire [31:0] cpu_read_data;
  wire hit1, hit2, hit3, hit4, HIT, MISS;
  wire mem_req, mem_write;
  wire [31:0] mem_addr, mem_write_data;
  wire [1:0] fifo_counter_out;
  wire [31:0] hit_count, miss_count;

  integer logfile;

  set_associative_fifo uut (
    .clk(clk), .reset(reset),
    .cpu_req(cpu_req), .cpu_write(cpu_write),
    .cpu_addr(cpu_addr), .cpu_write_data(cpu_write_data),
    .cpu_read_data(cpu_read_data),
    .hit1(hit1), .hit2(hit2), .hit3(hit3), .hit4(hit4),
    .HIT(HIT), .MISS(MISS),
    .mem_req(mem_req), .mem_write(mem_write),
    .mem_addr(mem_addr), .mem_write_data(mem_write_data),
    .mem_read_data(mem_read_data),
    .fifo_counter_out(fifo_counter_out),
    .hit_count(hit_count), .miss_count(miss_count)
  );

  always #5 clk = ~clk;
    
 initial begin
    logfile = $fopen("cache_metrics_FIFO.txt", "w");
    if (!logfile) $display("Failed to open log file");
    
  end

  always @(posedge clk) begin
    $fwrite(logfile, "Time: %0t | Addr: 0x%08h | Write: %0d | WriteData: 0x%08h | ReadData: 0x%08h | Hit: %0d | Miss: %0d | HitCount: %0d | MissCount: %0d | HitRate: %f\n",
            $time, cpu_addr, cpu_write, cpu_write_data, cpu_read_data,
            HIT, MISS, hit_count, miss_count,
            (hit_count + miss_count) ? (hit_count * 1.0 / (hit_count + miss_count)) : 0);
  end

  task access(input [31:0] addr, input write_en, input [31:0] mem_data_on_miss, input [31:0] wdata);
    begin
      cpu_addr = addr;
      cpu_write = write_en;
      mem_read_data = mem_data_on_miss;
      cpu_write_data = wdata;

      cpu_req = 1;
      @(posedge clk); #1;
      cpu_req = 0;

      @(posedge clk);

    //  $display("Time: %0t | Addr: %08h | W:%b | CPU_RD_DATA: %08h | HIT=%b MISS=%b | FIFO=%0d | HitCount=%0d MissCount=%0d",
               //$time, addr, write_en, cpu_read_data, HIT, MISS, fifo_counter_out, hit_count, miss_count);
    end
  endtask

  initial begin
  
    

    #10 reset = 0;

    $display("\n--- Test 1: Filling Cache with Read Misses ---");
    // Index 1 (0x04)
    //                                         addr      write_en   mem_data_on_miss   wdata
    access(32'h00000004, 0, 32'hC001C001, 32'h0); // Miss, loads C001C001 into way 0 for index 1
    #5;
    access(32'h00000404, 0, 32'hC002C002, 32'h0); // Miss, loads C002C002 into way 1 for index 1
    #5;
    access(32'h00000804, 0, 32'hC003C003, 32'h0); // Miss, loads C003C003 into way 2 for index 1
    #5;
    access(32'h00000C04, 0, 32'hC004C004, 32'h0); // Miss, loads C004C004 into way 3 for index 1
    #5;

    $display("\n--- Test 2: Verifying Hits for index 1 ---");
    // These should now be hits, and cpu_read_data should come from cache
    // mem_data_on_miss is irrelevant for hits, but still needs to be provided.
    //                                         addr      write_en   mem_data_on_miss   wdata
    access(32'h00000004, 0, 32'hDEADBEEF, 32'h0); // Hit (way 0), expect C001C001
    #5;
    access(32'h00000404, 0, 32'hDEADBEEF, 32'h0); // Hit (way 1), expect C002C002
    #5;
    access(32'h00000804, 0, 32'hDEADBEEF, 32'h0); // Hit (way 2), expect C003C003
    #5;
    access(32'h00000C04, 0, 32'hDEADBEEF, 32'h0); // Hit (way 3), expect C004C004
    #5;

    $display("\n--- Test 3: FIFO Replacement for index 1 ---");
    // Next access for index 1 should replace way 0 (0x00000004's data)
    //                                         addr      write_en   mem_data_on_miss   wdata
    access(32'h00001004, 0, 32'h00000001, 32'h0); // Miss, loads REPLACE001 into way 0 (replaces 0x00000004)
    #5;

    $display("\n--- Test 4: Accessing Replaced Address (Should be Miss) ---");
    //                                         addr      write_en   mem_data_on_miss   wdata
    access(32'h00000004, 0, 32'h00000004, 32'h0); // Miss (was replaced), loads NEWDATA004 into way 1 (replaces 0x00000404)
    #5;

    $display("\n--- Test 5: Write Hit ---");
    // Write to 0x00000804 (which contains C003C003)
    //                                         addr      write_en   mem_data_on_miss   wdata
    access(32'h00000804, 1, 32'h0, 32'h33333333); // Write Hit. Cache and mem_data updated.
    #5;
    access(32'h00000804, 0, 32'h0, 32'h0); // Read back. Should be Hit, expect UPDATE3333
    #5;

    $display("\n--- Test 6: Write Miss ---");
    // Write to a new address (index 0, tag different)
    // Cache line will be populated with cpu_write_data
    //                                         addr      write_en   mem_data_on_miss    wdata
    access(32'h00000000, 1, 32'h0, 32'hAAAAAAAA); // Write Miss. mem_data_on_miss is irrelevant for write.
    #5;
    access(32'h00000000, 0, 32'h0, 32'h0); // Read back. Should be Hit, expect WRITEMISS_DATA
    #5;


    $display("\nSimulation Finished.");
    $fclose(logfile);
    $finish;
  end

  //always @(posedge clk) begin
   // $fwrite(logfile, "%0t,%0h,%0d,%0h,%0d,%0d,%0d,%0d,%0d\n",
     // $time, cpu_addr, cpu_write, cpu_read_data, HIT, MISS, fifo_counter_out, hit_count, miss_count
  //  );
 // end

endmodule