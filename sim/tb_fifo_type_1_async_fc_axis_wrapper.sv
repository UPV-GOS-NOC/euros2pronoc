// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file fifo_type_1_async_axis_wrapper.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 13th, 2024
//
// @title Testbench for Asynchronous Clock Fifo module AXI stream wrapper
//
//  This module defines several tests to validate control signals behaviour when fifo is full/empty and to check data correctness (read after write)
//

`include "svut_h.sv"
`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE 1

module tb_fifo_type_1_async_fc_axis_wrapper;

  `SVUT_SETUP

  // variables 
  integer i = 0;
  integer j = 0;
  integer num_writes;
  integer num_reads;
  integer num_writes_max;
  integer num_reads_max;
  integer ts_1;
  integer ts_2;
  integer values_wr;
  integer values_rd;
  integer loop_var_wr;
  integer loop_var_rd;
  integer gen_low_avail_cycles;
  integer sink_low_avail_cycles;

  
  // tested clk freq pairs rd/wr
  // {2,3} {2,5} {19,5}
  parameter ClockReadHalfPeriod = 19; // read domain clock half period in ticks set by timescale parameter value in this source file
  parameter ClockWriteHalfPeriod = 5; // write domain clock half period in ticks set by timescale parameter value in this source file
  parameter DataWidth    = 32;  
  parameter TidWidth     =  8;
  parameter TdestWidth   =  8;
  //parameter FifoDepth   =  16;
  parameter AddressWidth = 3;
  parameter FirstWordFallThrough = "true";
  parameter SynchStages = 2;
  parameter FifoDepth = 2**AddressWidth;
  
  localparam STDataWidth = DataWidth;
  localparam MTDataWidth = DataWidth;
  localparam DownSizeRatio = STDataWidth / MTDataWidth;
  integer record_tgen_tdata_index;
  reg  [STDataWidth-1:0] record_tgen_tdata_arr[2*FifoDepth-1:0];
  
  integer record_sink_tdata_index;
  integer record_sink_tdata_byte_index;
  reg  [STDataWidth-1:0] record_sink_tdata_curr;
  reg  [STDataWidth-1:0] record_sink_tdata_arr[2*FifoDepth-1:0];
  
  reg                  wclk;
  reg                  wrst;
  reg                  rclk;
  reg                  rrst;
  wire [DataWidth-1:0] rdata;
  reg  [DataWidth-1:0] wdata_array [0:31];
  reg  [DataWidth-1:0] rdata_array [0:31];


  reg tb_ena_gen;
  reg tb_ena_sink;

  
  // wires connecting traffic source to system (axi to native adapter)
  wire                  tg_axis_arstn  = !wrst;
  wire [TidWidth-1:0]   tg_axis_tid;
  wire [TdestWidth-1:0] tg_axis_tdest;
  wire [DataWidth-1:0]  tg_axis_tdata;
  wire                  tg_axis_tvalid;
  wire                  tg_axis_tlast;
  wire                  tg_axis_tready;
  
  // wires connecting NATIVE to AXI adapter to  AXI traffic sink
  wire                  sink_arstn  = !rrst;
  wire [TidWidth-1:0]   sink_tid;
  wire [TdestWidth-1:0] sink_tdest;
  wire [DataWidth-1:0]  sink_tdata;
  wire                  sink_tvalid;
  wire                  sink_tlast;
  wire                  sink_tready;

  wire [DataWidth-1:0] tb_tdata_out;
  wire                 tb_tdata_valid;


  // --------------------------------------------------------------------------
  // Modules instantitation
  axis_traffic_gen #(
    .TDataWidth (DataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  ) atg_i(
    .tb_ena          (tb_ena_gen),
    
    .m_axis_aclk     (wclk),  // Input: clock signal of slave domain
    .m_axis_arstn    (tg_axis_arstn),   // Input: reset signal of slave main
    .m_axis_tid      (tg_axis_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest    (tg_axis_tdest),     // Output: routing information for the data stream. Destination.
    .m_axis_tdata    (tg_axis_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tvalid   (tg_axis_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tlast    (tg_axis_tlast),     // Output: indicates the boundary of a packet
    .m_axis_tready   (tg_axis_tready)   // Input: indicates that the next module can accept data
  );
  
fifo_type_1_async_axis_wrapper #(
    .TDataWidth (DataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth),
    .SynchStages (SynchStages),
    .FifoDepth (FifoDepth),
    .FirstWordFallThrough (FirstWordFallThrough)
    ) dut(
    // slave axi interface
    .s_axis_aclk      (wclk),    // Input: clock signal
    .s_axis_arstn     (tg_axis_arstn),   // Input: reset signal, active low
    .s_axis_tid      (tg_axis_tid),     // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (tg_axis_tdest),   // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (tg_axis_tdata),   // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (tg_axis_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (tg_axis_tlast),               // Input: indicates the boundary of a packet
    .s_axis_tready   (tg_axis_tready),  // Output: indicates that this module can accept data
    //master interface
    .m_axis_aclk     (rclk),            // Input: clock signal
    .m_axis_arstn    (sink_arstn),   // Input: reset signal, active low
    .m_axis_tid      (sink_tid),     // Output: Data Stream Idenfitifier 
    .m_axis_tdest    (sink_tdest),   // Output: routing information for the data stream. Destination.
    .m_axis_tdata    (sink_tdata),   // Output: primary payload. Data to cross the interface
    .m_axis_tvalid   (sink_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_axis_tlast    (sink_tlast),   // Output indicates the boundary of a packet
    .m_axis_tready   (sink_tready)   // Input: indicates that the module can accept data
    );

  
  axis_traffic_sink #(
    .TDataWidth (DataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  ) ats_i (
    .tb_ena          (tb_ena_sink), // module enable signal from testbench
    .tb_tdata        (tb_tdata_out),
    .tb_tvalid       (tb_tdata_valid),
    
    .s_axis_aclk     (rclk),           // Input: clock signal of slave domain
    .s_axis_arstn    (sink_arstn),   // Input: reset signal of slave main
    .s_axis_tid      (sink_tid),     // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (sink_tdest),   // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (sink_tdata),   // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (sink_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (sink_tlast),   // Input: indicates the boundary of a packet
    .s_axis_tready   (sink_tready)   // Output: indicates that this module can accept data
  );
  
  
  //create clocks 
  initial wclk = 1'b0;
  always #5 wclk <= ~wclk;
  initial rclk = 1'b0;
  always #3 rclk <= ~rclk;
   
  initial begin
    $dumpvars(0, tb_fifo_type_1_async_fc_axis_wrapper);
  end
  
  integer wr_timestamp = 0;
  always @(posedge wclk) begin
    wr_timestamp <= wr_timestamp + 1;
  end
  integer rd_timestamp = 0;
  always @(posedge rclk) begin
    rd_timestamp <= rd_timestamp + 1;
  end
    // record generated data
  always @(posedge wclk) begin
    if(!tg_axis_arstn) begin
      record_tgen_tdata_index = 0;
    end else begin
      if (tg_axis_tvalid) begin
        if (tg_axis_tready) begin
          `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
           $display("@tb_fifo_type_1_async_fc_axis_wrapper  record data in = 0x%08h ", tg_axis_tdata);
          `endif
          record_tgen_tdata_arr[record_tgen_tdata_index] = tg_axis_tdata;
          record_tgen_tdata_index = record_tgen_tdata_index + 1;
        end
      end
    end
  end
  
  // record out data
  always @(posedge rclk) begin
    if(!sink_arstn) begin
      record_sink_tdata_index = 0;
      record_sink_tdata_byte_index = 0;
    end else begin
      if (sink_tvalid) begin
        if (sink_tready) begin
          `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
          if (DownSizeRatio != 1) begin
            $display("@tb_fifo_type_1_async_fc_axis_wrapper  record byte %2d out [%2d:%2d] = 0x%02h ", record_sink_tdata_byte_index, 
                      record_sink_tdata_byte_index*MTDataWidth + MTDataWidth - 1, record_sink_tdata_byte_index*MTDataWidth, 
                      tb_tdata_out);
          end
          `endif

          //record_sink_tdata_curr[record_sink_tdata_byte_index*MTDataWidth +: MTDataWidth] = tb_tdata_out;
          record_sink_tdata_curr[record_sink_tdata_byte_index*MTDataWidth +: MTDataWidth] = sink_tdata;
          if (record_sink_tdata_byte_index == 0) begin          
            record_sink_tdata_arr[record_sink_tdata_index] = record_sink_tdata_curr;
            `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
            $display("@tb_fifo_type_1_async_fc_axis_wrapper  record data out[%2d] = 0x%08h ", record_sink_tdata_index, record_sink_tdata_curr);
            `endif
            record_sink_tdata_byte_index = DownSizeRatio - 1;
            record_sink_tdata_index = record_sink_tdata_index + 1;
          end else begin
            record_sink_tdata_byte_index = record_sink_tdata_byte_index - 1;
          end
        end
      end
    end
  end  

  
  task setup(msg="Setup testcase");
  begin
    wrst = 1'b1;
    rrst = 1'b1;
    tb_ena_gen = 1'b0;
    tb_ena_sink = 1'b0;
    gen_low_avail_cycles = 0;
    sink_low_avail_cycles = 0;
    record_tgen_tdata_index = 0;
    record_sink_tdata_index = 0;
    record_sink_tdata_byte_index = DownSizeRatio - 1;
    
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

  `TEST_SUITE("ASYNC_FIFO_AXIS_WRAPPER")

    `UNIT_TEST("T_SINGLE_WRITE_READ")
    @(posedge wclk)
    `FAIL_IF_NOT_EQUAL(tg_axis_tready, 0, "AXI fifo wrapper NOT ready upon test start");
    if (tg_axis_tready != 1) begin
      $display("@wr_ts  %3d  tg_axis_tready = %d", wr_timestamp, tg_axis_tready);
    end
    
    // write single value to fifo
    @(posedge wclk);
    tb_ena_gen = 1;
    // the axis to native module requires tb-enable to be active for 2 cycles to start writing into the fifo
    // so let's keep it up for other cycle before setting the flag to zero.
    @(posedge wclk)
    @(posedge wclk)
    tb_ena_gen = 0;
    
    // wait for fifo to trigger data valid flag
    @(posedge rclk);
    wait (sink_tvalid == 1'b1);
    
    // read the value
    @(posedge rclk);
    tb_ena_sink = 1;
    @(posedge rclk);
    @(posedge rclk);
    @(posedge rclk);
    @(posedge rclk);
    @(posedge rclk);
    @(posedge rclk);
    
    @(posedge rclk);
    tb_ena_sink = 0;
    
    `FAIL_IF_NOT_EQUAL(sink_tvalid, 0, "FIFO not empty detected");
    
  `UNIT_TEST_END

  `UNIT_TEST("T_FILL_FLUSH")

    // will attempt to generate twice values the capacity of the fifo,
    // but it will only write FifoDepth + 1 (axis_to_native internal value)
    loop_var_wr = (2 * FifoDepth)  + 1; 
        
    // NOTICE, due to the behaviour of the axis_2_native module, 
    // IT requires the source keeping the valid signal at least 2 consecutive cycles
    // for it to process the data  
    @(posedge wclk);
    tb_ena_gen = 1;
    @(posedge wclk);
    for (i = 0; i < loop_var_wr; i++) begin
      @(posedge wclk);
      // do nothing, this is to iterate 
    end
    
    // let's stop the generator 
    @(posedge wclk)
    tb_ena_gen = 0;
    
    // let's check whether the fifo is full
    @(posedge wclk)
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("@wr_ts  %3d  wrote %2d  wfull = %d", wr_timestamp, record_tgen_tdata_index, wfull);
    `endif    
    
    // Let's enable the traffic sink  
    //  enable traffic sink
    @(posedge rclk);
    tb_ena_sink = 1;
    
    // wait for fifo to lower the empty flag, then the sink will trigger the valid data available
    @(posedge rclk);
    wait (tb_tdata_valid == 1'b1);
  
    //let's drain the dada from the fifo, will attempt to read more values 
    loop_var_rd = loop_var_wr  * DownSizeRatio;
    for (i = 0; i < loop_var_rd; i++) begin
      @(posedge rclk);
      // let's do nothing
    end    

    //Let's stop the traffic sink
    @(posedge rclk);
    tb_ena_sink = 0;    
    
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("@rd_ts  %3d  read %2d  empty = %d", rd_timestamp, record_sink_tdata_index, rempty);
    `endif
    
    // let's check the tb read and wrote the same amount of words    
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_index, record_sink_tdata_index, "UNEXPECTED number of words read by the sink");
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    if (record_tgen_tdata_index != record_sink_tdata_index) begin
      $display("@tb_top: wrote %2d values read %2d values", record_tgen_tdata_index, record_sink_tdata_index);
    end
    `endif
    
    j = (record_tgen_tdata_index < record_sink_tdata_index) ? record_tgen_tdata_index : record_sink_tdata_index;
    
    for (i = 0; i < j; i++) begin
      if (record_tgen_tdata_arr[i] != record_sink_tdata_arr[i]) begin
        $display ("DATA mismatch 0x%08h != 0x%08h", record_tgen_tdata_arr[i], record_sink_tdata_arr[i]);
      end
    `FAIL_IF_NOT_EQUAL(record_tgen_tdata_arr[i], record_sink_tdata_arr[i], "GENERATED/RECEIVED data mismatch");
    end

  `UNIT_TEST_END


`TEST_SUITE_END

endmodule
