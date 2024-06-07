// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_2_native_fifo.v
// @author J. Martinez (jomarm10@gap.upv.es)
// @date March 11th, 2024
//
// @title Testbench for FIFO handshake adapters: AXI4-S to Native and Native 2 AXI-S
//
//  This module defines several tests to validate the handshake adapters for the fifo_type_1_async module 
//  to allow using this fifo in an AXI4 Stream pipleline 
//

`include "svut_h.sv"
`timescale 1 ns / 1 ps

//`define  DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE 1

module tb_fifo_type_1_async_fc_axis;

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
  //reg                  winc;
  //reg  [DataWidth-1:0] wdata;
  wire                 wfull;
  wire                 awfull;
  reg                  rclk;
  reg                  rrst;
  //reg                  rinc;
  wire [DataWidth-1:0] rdata;
  wire                 rempty;
  wire                 arempty;
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
  
  // wires connecting AXI streams source with AXI to NATIVE adapter
  wire [TidWidth-1:0]   a2n_tid;
  wire [TdestWidth-1:0] a2n_tdest;
  wire [DataWidth-1:0]  a2n_tdata;
  wire                  a2n_tvalid;
  wire                  a2n_tlast;
  wire                  a2n_tready = !wfull;
  
  // wires connecting Native flow control FIFO to AXI adapter
  wire [TidWidth-1:0]   n2a_tid;     // Input: Data Stream Idenfitifier 
  wire [TdestWidth-1:0] n2a_tdest;   // Input: routing information for the data stream. Destination.
  wire [DataWidth-1:0]  n2a_tdata;   // Input: primary payload. Data to cross the interface
  wire                  n2a_tvalid;  // Input: indicates that the transmitter is driving a valid transfer
  wire                  n2a_tlast;   // Input: indicates the boundary of a packet
  wire                  n2a_tready;  // Output:  indicates that the module can accept data
  
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
  
  axis_2_native_fifo #(
    .STDataWidth  (DataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  )
  a2nf_i(
    // slave axi interface
    .aclk            (wclk),            // Input: clock signal
    .arstn           (tg_axis_arstn),   // Input: reset signal, active low
     //
    .s_axis_tid      (tg_axis_tid),     // Input: Data Stream Idenfitifier 
    .s_axis_tdest    (tg_axis_tdest),   // Input: routing information for the data stream. Destination.
    .s_axis_tdata    (tg_axis_tdata),   // Input: primary payload. Data to cross the interface
    .s_axis_tvalid   (tg_axis_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_axis_tlast    (tg_axis_tlast),               // Input: indicates the boundary of a packet
    .s_axis_tready   (tg_axis_tready),  // Output: indicates that this module can accept data
    // native interface
    .m_native_tid    (a2n_tid),      
    .m_native_tdest  (a2n_tdest),   // Output: routing information for the data stream. Destination.
    .m_native_tdata  (a2n_tdata),   // Output: primary payload. Data to cross the interface
    .m_native_tvalid (a2n_tvalid),  // Output: indicates that the transmitter is driving a valid transfer
    .m_native_tlast  (a2n_tlast),   // Output: indicates the boundary of a packet
    .m_native_tready (a2n_tready)
  );
  
  
  fifo_type_1_async #(
    .DataWidth (DataWidth),
    .AddressWidth (AddressWidth),
    .SynchStages (SynchStages),
    .FirstWordFallThrough (FirstWordFallThrough)
  ) dut (
    .wr_clk   (wclk),
    .wr_rst   (wrst),
    .wr_req   (a2n_tvalid),
    .wr_data  (a2n_tdata),
    .wr_full  (wfull),
    //.wr_almost_full (awfull),
    .rd_clk   (rclk),
    .rd_rst   (rrst),
    .rd_req   (n2a_tready),
    .rd_data  (n2a_tdata),
    .rd_empty (rempty)
    //.rd_almost_empty (arempty)
  );
  
  assign n2a_tvalid = !rempty;
  
  native_fifo_2_axi #(
    .STDataWidth (DataWidth),
    .TidWidth (TidWidth),
    .TdestWidth (TdestWidth)
  ) nf2a_i(
    // slave axi interface
    .aclk            (rclk),            // Input: clock signal
    .arstn           (sink_arstn),   // Input: reset signal, active low
     // Data input from native flow control FIFO
    .s_native_tid    (n2a_tid),     // Input: Data Stream Idenfitifier 
    .s_native_tdest  (nta_tdest),   // Input: routing information for the data stream. Destination.
    .s_native_tdata  (n2a_tdata),   // Input: primary payload. Data to cross the interface
    .s_native_tvalid (n2a_tvalid),  // Input: indicates that the transmitter is driving a valid transfer
    .s_native_tlast  (n2a_tlast),   // Input: indicates the boundary of a packet
    .s_native_tready (n2a_tready),  // Output:  indicates that the module can accept data
    // next module with (reduced subset) AXI interface  
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
    $dumpvars(0, tb_fifo_type_1_async_fc_axis);
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
           $display("@tb_axis_data_downsizer  record data in = 0x%08h ", tg_axis_tdata);
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
            $display("@tb_axis_data_downsizer  record byte %2d out [%2d:%2d] = 0x%02h ", record_sink_tdata_byte_index, 
                      record_sink_tdata_byte_index*MTDataWidth + MTDataWidth - 1, record_sink_tdata_byte_index*MTDataWidth, 
                      tb_tdata_out);
          end
          `endif

          //record_sink_tdata_curr[record_sink_tdata_byte_index*MTDataWidth +: MTDataWidth] = tb_tdata_out;
          record_sink_tdata_curr[record_sink_tdata_byte_index*MTDataWidth +: MTDataWidth] = sink_tdata;
          if (record_sink_tdata_byte_index == 0) begin          
            record_sink_tdata_arr[record_sink_tdata_index] = record_sink_tdata_curr;
            `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
            $display("@tb_axis_data_downsizer  record data out[%2d] = 0x%08h ", record_sink_tdata_index, record_sink_tdata_curr);
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

  `TEST_SUITE("ASYNCFIFO")

  `UNIT_TEST("IDLE")
    `FAIL_IF(wfull);
    `FAIL_IF(!rempty);
  `UNIT_TEST_END
  

  `UNIT_TEST("T_SINGLE_WRITE_READ")
    @(posedge wclk)
    `FAIL_IF_NOT_EQUAL(wfull, 0, "wfull flag was detected upon test start");
    if (wfull != 1) begin
      $display("@wr_ts  %3d  wfull = %d", wr_timestamp, wfull);
    end
    
    // write single value to fifo
    @(posedge wclk);
    tb_ena_gen = 1;
    // the axis to native module requires tb-enable to be active for 2 cycles to start writing into the fifo
    // so let's keep it up for other cycle before setting the flag to zero.
    @(posedge wclk)
    @(posedge wclk)
    tb_ena_gen = 0;
    
    // wait for fifo to lower the empty flag 
    @(posedge rclk);
    wait (rempty == 1'b0);
    
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
    
    `FAIL_IF_NOT_EQUAL(rempty, 1, "FIFO not empty detected");
    
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
    `FAIL_IF_NOT_EQUAL(wfull, 1, "wfull flag NOT detected");
        
    
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
    `FAIL_IF_NOT_EQUAL(rempty, 1, "FIFO not empty detected");
    
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

  `UNIT_TEST("T_FFFF")
 
    // First round fill-flush   
    while (!wfull) begin
      @(negedge wclk);
      tb_ena_gen = 1;
    end

    @(negedge wclk);
     tb_ena_gen = 0;

    @(posedge wclk)
    `FAIL_IF_NOT_EQUAL(wfull, 1, "wfull flag was not detected enabled");
    if (wfull != 1) begin
      $display("@wr_ts  %3d  wfull = %d", wr_timestamp, wfull);
    end
    
    while (!rempty) begin
      @(negedge rclk)
         tb_ena_sink = 1;
    end

    @(posedge rclk);
    @(negedge rclk);
    @(posedge rclk);
    
    @(negedge rclk);
    tb_ena_sink = 0;    
    
    @(posedge rclk);
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("@rd_ts  %3d  read %2d  empty = %d", rd_timestamp, record_sink_tdata_index, rempty);
    `endif
    `FAIL_IF_NOT_EQUAL(rempty, 1, "FIFO not empty detected");
    
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
 
   // let's reset the indices to track testbench data again
   @(posedge wclk);
   record_tgen_tdata_index = 0;
   
   @(posedge rclk);
   record_sink_tdata_index = 0;
 
   // Second round fill-flush
    while (!wfull) begin
      @(negedge wclk)
         tb_ena_gen = 1;
    end

    @(negedge wclk);
     tb_ena_gen = 0;

    @(posedge wclk)
    `FAIL_IF_NOT_EQUAL(wfull, 1, "wfull flag was not detected enabled");
    if (wfull != 1) begin
      $display("@wr_ts  %3d  wfull = %d", wr_timestamp, wfull);
    end
    
    while (!rempty) begin
      @(negedge rclk)
         tb_ena_sink = 1;
    end

    @(negedge rclk);
     tb_ena_sink = 0;    
       
    @(posedge rclk);
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("@rd_ts  %3d  read %2d  empty = %d", rd_timestamp, record_sink_tdata_index, rempty);
    `endif
    `FAIL_IF_NOT_EQUAL(rempty, 1, "FIFO not empty detected");
    
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

    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("@wr_ts  %3d  single write", wr_timestamp);
    `endif
    
    // system requires to keep the enable signal for two cycles at least 
    @(posedge wclk);
    tb_ena_gen = 1;
    @(posedge wclk);
    @(posedge wclk);
    tb_ena_gen = 0;
    // let's skip some cycles to let the empty signal be updated due to the synch stages delay
    @(posedge wclk);
    @(posedge wclk);
    @(posedge wclk);
    @(posedge wclk);
    
    @(posedge rclk);
    `ifdef DEBUG_DISPLAY_TOP_TESTBENCH_ENABLE
    $display("@rd_ts  %3d  read %2d  empty = %d", rd_timestamp, record_sink_tdata_index, rempty);
    `endif
    `FAIL_IF_NOT_EQUAL(rempty, 0, "FIFO empty detected");

  `UNIT_TEST_END
  
`TEST_SUITE_END

endmodule
