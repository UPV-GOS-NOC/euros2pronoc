// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//   
// @file tb_fifo_type_1_async_fc_native.sv
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date March 6th, 2024
//
// @title Testbench for Asynchronous Clock Fifo module
//
//  This module defines several tests to validate control signals behaviour when fifo is full/empty and to check data correctness (read after write)
//
//  
//   This module is based on the testbech file async_fifo_unit_test.sv for the async fifo module described in 
//     <Asynchronous dual clock FIFO: https://github.com/dpretet/async_fifo> 
//
// TODO: Add more cases for different rd/wr clock frequency relation
//       Automate frequency changes in tb
//

`include "svut_h.sv"
`timescale 1 ns / 1 ps

module tb_fifo_type_1_fc_native;

  `SVUT_SETUP

  integer i = 0;
  integer j = 0;
  integer num_writes;
  integer num_reads;
  integer num_writes_max;
  integer num_reads_max;
  integer ts_1;
  integer ts_2;

  
  // tested clk freq pairs rd/wr
  // {2,3} {2,5} {19,5}
  parameter ClockReadHalfPeriod = 19; // read domain clock half period in ticks set by timescale parameter value in this source file
  parameter ClockWriteHalfPeriod = 5; // write domain clock half period in ticks set by timescale parameter value in this source file
  parameter DataWidth = 32;  
  parameter AddressWidth = 3;
  parameter FirstWordFallThrough = "true";
  parameter SynchStages = 2;

  reg                  wclk;
  reg                  wrst;
  reg                  winc;
  reg  [DataWidth-1:0] wdata;
  wire                 wfull;
  wire                 awfull;
  reg                  rclk;
  reg                  rrst;
  reg                  rinc;
  wire [DataWidth-1:0] rdata;
  wire                 rempty;
  wire                 arempty;
  reg  [DataWidth-1:0] wdata_array [0:31];
  reg  [DataWidth-1:0] rdata_array [0:31];

  fifo_type_1_async #(
    .DataWidth (DataWidth),
    .AddressWidth (AddressWidth),
    .SynchStages (SynchStages),
    .FirstWordFallThrough (FirstWordFallThrough)
  ) dut (
    .wr_clk   (wclk),
    .wr_rst   (wrst),
    .wr_req   (winc),
    .wr_data  (wdata),
    .wr_full  (wfull),
    //.wr_almost_full (awfull),
    .rd_clk   (rclk),
    .rd_rst   (rrst),
    .rd_req   (rinc),
    .rd_data  (rdata),
    .rd_empty (rempty)
    //.rd_almost_empty (arempty)
  );

  //create clocks 
  initial wclk = 1'b0;
  always #5 wclk <= ~wclk;
  initial rclk = 1'b0;
  always #3 rclk <= ~rclk;
   
  initial begin
    $dumpvars(0, tb_fifo_type_1_fc_native);
  end
  
  integer wr_timestamp = 0;
  always @(posedge wclk) begin
    wr_timestamp <= wr_timestamp + 1;
  end
  integer rd_timestamp = 0;
  always @(posedge rclk) begin
    rd_timestamp <= rd_timestamp + 1;
  end
  
  task setup(msg="Setup testcase");
  begin
    wrst = 1'b1;
    winc = 1'b0;
    wdata = 0;
    rrst = 1'b1;
    rinc = 1'b0;
    #100;
    wrst = 0;
    rrst = 0;
    #50;
    @(posedge wclk);
    
  end
  endtask

  task teardown(msg="Tearing down");
  begin
    #50;
  end
  endtask

  `TEST_SUITE("ASYNCFIFO")

  `UNIT_TEST("IDLE")
    `FAIL_IF(wfull);
    `FAIL_IF(!rempty);
  `UNIT_TEST_END

  `UNIT_TEST("SINGLE_WRITE_THEN_READ")
 
    @(posedge wclk)
    winc = 1;
    wdata = 32'hA;

    @(posedge wclk)
    winc = 0;

    @(posedge rclk)
    wait (rempty == 1'b0);
    rinc = 1;

    @(negedge rclk)
    `FAIL_IF_NOT_EQUAL(rdata, 32'hA);
    @(negedge rclk)
    rinc = 0;

  `UNIT_TEST_END

  `UNIT_TEST("MULTIPLE_WRITE_AND_READ")

    for (i=0; i<6; i=i+1) begin
      @(negedge wclk);
        winc = 1;
        wdata = i;
    end
    @(negedge wclk);
    winc = 0;

    #100;

    @(posedge rclk);

    rinc = 1;
    for (i=0; i<6; i=i+1) begin
      @(posedge rclk);
       `FAIL_IF_NOT_EQUAL(rdata, i);
    end

  `UNIT_TEST_END

  `UNIT_TEST("TEST_FULL_FLAG")

    winc = 1;

    for (i=0; i<2**AddressWidth; i=i+1) begin
      @(negedge wclk)
        wdata = i;
    end

    @(negedge wclk);
    winc = 0;

    @(posedge wclk)
    `FAIL_IF_NOT_EQUAL(wfull, 1);

  `UNIT_TEST_END

  `UNIT_TEST("TEST_EMPTY_FLAG")

    `FAIL_IF_NOT_EQUAL(rempty, 1);

    for (i=0; i<2**AddressWidth; i=i+1) begin
      @(posedge wclk)
        winc = 1;
        wdata = i;
    end

    `FAIL_IF_NOT_EQUAL(rempty, 0);

  `UNIT_TEST_END
  
  `UNIT_TEST("TEST_FILL_AND_FLUSH_DATA")
    $display ("UnitTest_FillAndFlush ");

    `FAIL_IF_NOT_EQUAL(rempty, 1);
    
    $display ("Write data until fifo triggers full flag");  

    for (i = 0; i < 2**AddressWidth; i++) begin
      @(negedge wclk);
      `FAIL_IF_NOT_EQUAL(wfull, 0);
      winc = 1;
      wdata = 'haaaa_0000 + i;
      wdata_array[i] = wdata;
      $display("  %2d request to write word to fifo addr[%2d]: %08h", i, i, wdata_array[i]);
      //i = i + 1;
    end
    @(negedge wclk)
    winc = 0;
    
    //// wait a few cycles
    for (j = 0; j < 5; j++) begin
      @(posedge wclk);
    end
    $display ("Wrote %2d values", i);
    if(wfull) begin
      $display ("FIFO full flag detected");
    end

    // last value requested to write will not be written, since we requested to write to the memory but the full flag was already triggered
    // fifo will only contain 2**AddressWidth values
    //$display ("Wrote %2d values", i);
    `FAIL_IF_NOT_EQUAL(wfull, 1);
    wait(rempty == 0);
    $display ("Read data as many values as written");
    for (j = 0; (j < (2**AddressWidth)) ; j++) begin

      //wait(rempty == 0);
      @(negedge rclk);
      ts_1 = rd_timestamp;
      $display("\n");
      $display("  %0t  ts_1 = %2d  j = %2d", $realtime, ts_1, j);
      if (rempty == 0) begin
        rdata_array[j]  = rdata;
        rinc = 1;
        $display("  %0t  %2d read word from fifo addr[%2d]: %08h",$realtime, j, j, rdata_array[j]);
      end else begin
         $display("  %0t  %2d NOT read word from fifo addr[%2d]: %08h, EMPTY FIFO  flag detected", $realtime, j, j, rdata_array[j]);
        rinc = 0;
        //continue;
      end 
      @(posedge rclk);
      rinc = 0;
       
    end
    
    @(negedge rclk)
    rinc = 0;
    $display ("Read %2d values", j);
    
    @(posedge rclk);
    `FAIL_IF_NOT_EQUAL(rempty, 1);

  `UNIT_TEST_END


`TEST_SUITE_END

endmodule
