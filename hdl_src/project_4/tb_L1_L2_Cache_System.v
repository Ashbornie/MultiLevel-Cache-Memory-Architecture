`timescale 1ns / 1ps
module tb_L1_L2_Cache_System;

  // Clock and Reset signals
  reg clk;
  reg reset;

  // CPU Interface signals
  reg cpu_req;
  reg cpu_write;
  reg [31:0] cpu_addr;
  reg [31:0] cpu_write_data;
  wire [31:0] cpu_read_data;
  wire L1_hit, L1_miss;
  wire L2_hit, L2_miss;
  wire [31:0] L1_hit_count;
  wire [31:0] L1_miss_count;
  wire [31:0] L2_hit_count;
  wire [31:0] L2_miss_count;

  // Main Memory Interface signals (now dummy)
  wire mem_req_to_main;
  wire mem_write_to_main;
  wire [31:0] mem_addr_to_main;
  wire [31:0] mem_write_data_to_main;
  reg [31:0] mem_read_data_from_main; // Dummy data provided to L2

  // File handle for logging
  integer logfile;

  // Instantiate the L1-L2 Cache System
  L1_L2_Cache_System dut (
    .clk(clk),
    .reset(reset),
    .cpu_req(cpu_req),
    .cpu_write(cpu_write),
    .cpu_addr(cpu_addr),
    .cpu_write_data(cpu_write_data),
    .cpu_read_data(cpu_read_data),
    .L1_hit(L1_hit),
    .L1_miss(L1_miss),
    .L2_hit(L2_hit),
    .L2_miss(L2_miss),
    .L1_hit_count(L1_hit_count),
    .L1_miss_count(L1_miss_count),
    .L2_hit_count(L2_hit_count),
    .L2_miss_count(L2_miss_count),
    .mem_req_to_main(mem_req_to_main),
    .mem_write_to_main(mem_write_to_main),
    .mem_addr_to_main(mem_addr_to_main),
    .mem_write_data_to_main(mem_write_data_to_main),
    .mem_read_data_from_main(mem_read_data_from_main)
  );

  // Clock Generation
  always #5 clk = ~clk; // 10ns period (100 MHz)

  // Dummy Main Memory Logic
  // This block provides dummy data for reads and acknowledges writes.
  // It still simulates a 1-cycle latency for memory access.
  always @(posedge clk) begin
    if (mem_req_to_main) begin
      if (mem_write_to_main) begin
        // For a write request, simply acknowledge it.
      end else begin
        // For a read request, provide dummy data based on the requested address.
        mem_read_data_from_main <= mem_addr_to_main + 32'hA0000000; // Dummy data: address + a constant
      end
    end
  end

  // File logging setup
  initial begin
    logfile = $fopen("cache_metrics_l1l2.txt", "w"); // Changed filename for clarity
    if (!logfile) $display("Failed to open log file");
  end

  // Log metrics on each positive clock edge when a CPU request is active
  always @(posedge clk) begin
    if (cpu_req) begin // Only log when a CPU request is active
      $fwrite(logfile, "Time: %0t | Addr: 0x%08h | Write: %0d | WriteData: 0x%08h | ReadData: 0x%08h ",
                $time, cpu_addr, cpu_write, cpu_write_data, cpu_read_data);

      $fwrite(logfile, "| L1_Hit: %0d | L1_Miss: %0d | L1_HitCount: %0d | L1_MissCount: %0d | L1_HitRate: %f ",
                L1_hit, L1_miss, L1_hit_count, L1_miss_count,
                (L1_hit_count + L1_miss_count) ? (L1_hit_count * 1.0 / (L1_hit_count + L1_miss_count)) : 0);

      $fwrite(logfile, "| L2_Hit: %0d | L2_Miss: %0d | L2_HitCount: %0d | L2_MissCount: %0d | L2_HitRate: %f\n",
                L2_hit, L2_miss, L2_hit_count, L2_miss_count,
                (L2_hit_count + L2_miss_count) ? (L2_hit_count * 1.0 / (L2_hit_count + L2_miss_count)) : 0);
    end
  end


  // Test Sequence
  initial begin
    // Initialize signals
    clk = 0;
    reset = 1;
    cpu_req = 0;
    cpu_write = 0;
    cpu_addr = 0;
    cpu_write_data = 0;
    mem_read_data_from_main = 0;

    #10 reset = 0; // De-assert reset after 10ns (at 10ns)

    // --- Test Scenario 1: L1 Read Miss, L2 Read Miss (Fetch from Dummy Memory) ---
    // Address 0x0000_0000. Caches are empty.
    // Expected latency: 5 clock cycles for data to reach CPU_read_data
    // Data valid at 60ns.
    #10; // Advance to 20ns (start of Cycle 1 for first request)
    cpu_addr = 32'h0000_0000; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req after one cycle (at 30ns)

    #40; // Wait for 4 more cycles for data to propagate (total 5 cycles from cpu_req assertion)


    // --- Test Scenario 2: L1 Read Hit ---
    // Read the same address 0x0000_0000. Should be an L1 hit.
    // Expected latency: 1 clock cycle for data to reach CPU_read_data
    // Data valid at 80ns.
    #10; // Advance to 70ns
    cpu_addr = 32'h0000_0000; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req (at 80ns)

    #0; // Data should be available in the same cycle (80ns) after L1 processes


    // --- Test Scenario 3: L1 Read Miss, L2 Read Hit ---
    // Access an address 0x0000_0100. L1 will miss, L2 should hit.
    // Expected latency: 3 clock cycles for data to reach CPU_read_data
    // Data valid at 110ns.
    #10; // Advance to 90ns
    cpu_addr = 32'h0000_0100; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req (at 100ns)

    #20; // Wait for 2 more cycles for data to propagate (total 3 cycles from cpu_req assertion)


    // --- Test Scenario 4: CPU Write Hit (L1 and L2) ---
    // Write 0xDEADBEEF to 0x0000_0000. Should be L1 hit, L2 hit, write-through to dummy main memory.
    // Expected latency: 3 clock cycles for write to reach Dummy Main Memory.
    #10; // Advance to 120ns
    cpu_addr = 32'h0000_0000; cpu_write_data = 32'hDEADBEEF; cpu_req = 1; cpu_write = 1;
    #10 cpu_req = 0; // De-assert cpu_req (at 130ns)

    #20; // Wait for 2 more cycles for write to propagate to Dummy Main Memory (total 3 cycles)


    // --- Test Scenario 5: CPU Write Miss (L1 and L2) ---
    // Write 0xCAFEF00D to a new address 0x0000_0200. Should be L1 miss, L2 miss, write-through.
    // Expected latency: 3 clock cycles for write to reach Dummy Main Memory.
    #10; // Advance to 160ns
    cpu_addr = 32'h0000_0200; cpu_write_data = 32'hCAFEF00D; cpu_req = 1; cpu_write = 1;
    #10 cpu_req = 0; // De-assert cpu_req (at 170ns)

    #20; // Wait for 2 more cycles


    // --- Test Scenario 6: Demonstrate FIFO Replacement in L2 ---
    // Fill up an L2 set (index 0x00) to force replacement.
    // Addresses: 0x0000_0000, 0x0000_0400, 0x0000_0800, 0x0000_0C00 (all map to L2 index 0x00, different tags)

    // Access 0x0000_0000 (already in L1/L2 from earlier, should hit L1)
    #10; // Advance to 200ns
    cpu_addr = 32'h0000_0000; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req (at 210ns)
    #0; // Data should be available immediately


    // Access 0x0000_0400 (L1 miss, L2 miss, will go into way 1 of L2 set 0x00)
    #10; // Advance to 220ns
    cpu_addr = 32'h0000_0400; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req (at 230ns)
    #40; // Wait for 4 more cycles for data to propagate


    // Access 0x0000_0800 (L1 miss, L2 miss, will go into way 2 of L2 set 0x00)
    #10; // Advance to 270ns
    cpu_addr = 32'h0000_0800; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req (at 280ns)
    #40; // Wait for 4 more cycles


    // Access 0x0000_0C00 (L1 miss, L2 miss, will go into way 3 of L2 set 0x00)
    #10; // Advance to 320ns
    cpu_addr = 32'h0000_0C00; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req (at 330ns)
    #40; // Wait for 4 more cycles


    // Now, access 0x0000_0000 again. It was the first in, should be replaced by FIFO.
    // This should cause an L1 miss, then an L2 miss, as it's evicted from L2.
    #10; // Advance to 370ns
    cpu_addr = 32'h0000_0000; cpu_req = 1; cpu_write = 0;
    #10 cpu_req = 0; // De-assert cpu_req (at 380ns)
    #40; // Wait for 4 more cycles

    // End simulation
    #50 $finish;
  end

  // Monitor signals for debugging (kept for detailed waveform analysis)
  // Removed from here as per request.
  // initial begin
  //   $monitor("Time=%0t | CPU_Req=%b, CPU_Write=%b, CPU_Addr=0x%h, CPU_Write_Data=0x%h | CPU_Read_Data=0x%h | L1_Hit=%b, L1_Miss=%b | L2_Hit=%b, L2_Miss=%b | MEM_Req=%b, MEM_Write=%b, MEM_Addr=0x%h, MEM_Write_Data=0x%h",
  //            $time, cpu_req, cpu_write, cpu_addr, cpu_write_data, cpu_read_data, L1_hit, L1_miss, L2_hit, L2_miss, mem_req_to_main, mem_write_to_main, mem_addr_to_main, mem_write_data_to_main);
  // end

endmodule

