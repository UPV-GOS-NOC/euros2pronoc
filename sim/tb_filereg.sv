// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
// 
//
// @file axis_data_downsizer.v
// @author: J. Martinez (jomarm10@gap.upv.es)
// @date: May 6th, 2024
//
// @title Testbench for Logic Based Distributed Routing (LBDR) algorithm for 3D (cube) NoCs
//
//  Work in Progress
//  Currently used to check whether calculated positions are correct
//

`define TDATA_INITIAL_VALUE 32'h0000_0000
`define TDATA_INCR 32'h0101_0101
`define ENTRY_ID_INITIAL_VALUE 4'd4
`define ENTRY_ID_INCR 4'd1

`define DEBUG_DISPLAY_TB_FILEREG_ENABLE 1
`define DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE 1

`include "svut_h.sv"
`include "net_common.h"
`include "routing_algorithm_lbdr_2d.h"
`include "routing_algorithm_xy.h"
`include "filereg.h"


module tb_filereg;

  // --------------------------------------------------------------------------
  // Functions Definition
  function integer num_bits;
    input integer value;
    begin
      num_bits = 0;
      for (num_bits = 0; value > 0; num_bits = num_bits+1) begin
        value = value >> 1;
      end
    end
  endfunction
  
  `SVUT_SETUP

  // --------------------------------------------------------------------------
  // Testbench Configuration Parameters
  
  // clocks and resets
  localparam ClockHalfPeriod = 5; // write domain clock half period in ticks set by timescale parameter value in this source file
  
  // NoC configuration Parameters
  localparam NumberOfColumns = 4;  // X dim
  localparam NumberOfRows    = 3;     // y dim
  localparam NumberOfNodes = NumberOfColumns * NumberOfRows;
  localparam NodeIdWidth   = num_bits(NumberOfNodes);
 
  localparam NumberOfRowsWidth    = num_bits(NumberOfRows - 1);
  localparam NumberOfColumnsWidth = num_bits(NumberOfColumns - 1);

  // LBDR 3D parameters
  localparam NumberOfOutputPorts = 5; // NEWS-Local
  localparam NumberOfVNs         = 3;
  localparam LBDRNumberOfRoutingBits = 8;
  localparam LBDRNumberOfConnectivityBits = 4;
  localparam [`AXIS_DIRECTION_WIDTH-1:0] NodeIdIncreaseXAxis = `DIRECTION_EAST;   //! Node ID increment direction in X axis  Supported values: EASTWARDS WESTWARDS
  localparam [`AXIS_DIRECTION_WIDTH-1:0] NodeIdIncreaseYAxis = `DIRECTION_SOUTH;  //! Node ID increment direction in Y axis. Supported values: NORTHWARDS SOUTHW
  localparam LBDRNumberOfBits    = LBDRNumberOfRoutingBits + LBDRNumberOfConnectivityBits;
  localparam LBDRBitsPortWidth   = LBDRNumberOfBits * NumberOfVNs; // {(NUM_VNs){ROUTING_BITS, CONNECTIVITY_BITS}}


  // this is the source node for the routing algorithm
  // The NodeId is a parameter set at the initialization of the module, so cannot be modified during the tests
  // x=1, y=1,
  localparam NodeIdX = 1;
  localparam NodeIdY = 1;
  localparam [NodeIdWidth-1:0] NodeId = (NodeIdX + NodeIdY*NumberOfColumns);
  //localparam NodeIdOffsetXAxis = (NodeIdIncreaseXAxis == `DIRECTION_EAST) ? NodeIdX : (NumberOfColumns - 1 - NodeIdX);
  //localparam NodeIdOffsetYAxis = (NodeIdIncreaseYAxis == `DIRECTION_NORTH)?(NodeIdY*NumberOfColumns) : (NumberOfRows - 1 - NodeIdY) * NumberOfColumns;  
  //localparam [NodeIdWidth-1:0] NodeId = NodeIdOffsetYAxis + NodeIdOffsetXAxis;



  localparam FileRegCommandIdWidth = num_bits(`FILEREG_NUMBER_OF_COMMANDS - 1); // Number of bits required to encode the command code. The module currently supports 2 commands: Read and Write
  localparam FileRegDepth          = `FILEREG_NUMBER_OF_ENTRIES;
  localparam FileRegEntryIdWidth   = num_bits(FileRegDepth-1);
  localparam FileRegEntryWidth     = `FILEREG_ENTRY_WIDTH;  // Size in bits for each entry of the Register File (paylad in tdata input port)

  localparam OperationTDataWidth    = FileRegCommandIdWidth + FileRegEntryIdWidth + FileRegEntryWidth;
  localparam SourceIdWidth          = NodeIdWidth;
  localparam RegisterReadWidth      = SourceIdWidth + FileRegEntryWidth;
  // Registers and wires
  // clocks and resets 
  reg  clk;
  reg  rst;
  reg  rst_test;
  wire rst_gen;
  assign rst_gen = rst | rst_test;
  
  reg  operation_enable; // testbench operation enable register, to handle FileReg writing in testbench
  reg  read_reg_enable;
  
  reg                            operation_tvalid = 1'b0;
  wire [OperationTDataWidth-1:0] operation_tdata;
  reg                            operation_tlast = 1'b1;
  wire                           operation_tready;
  
  reg                          register_tready = 1'b1;
  wire                         register_tvalid;
  wire [RegisterReadWidth-1:0] register_tdata;
  wire                         register_tlast;
  
  wire [LBDRBitsPortWidth-1:0] lbdr_bits_bus;
  wire [LBDRNumberOfBits-1:0]  lbdr_bits_per_vn [NumberOfVNs-1:0];

  genvar gen_it_i;
  generate begin: lbdr_bits_per_vn_linkage
    for (gen_it_i = 0; gen_it_i < NumberOfVNs; gen_it_i = gen_it_i + 1) begin
      assign lbdr_bits_per_vn[gen_it_i] = lbdr_bits_bus[LBDRNumberOfBits * gen_it_i +: LBDRNumberOfBits];
    end
  end
  endgenerate

  filereg #(
    .NodeId          (NodeId),
    .NodeIdWidth     (NodeIdWidth),
    .NodesInXDimension (NumberOfColumns),
    .NodesInYDimension (NumberOfRows), 
    .DimensionXWidth   (NumberOfColumnsWidth),
    .DimensionYWidth   (NumberOfRowsWidth),
    .NodeIdIncreaseXAxis (NodeIdIncreaseXAxis),
    .NodeIdIncreaseYAxis (NodeIdIncreaseYAxis),
    .LBDRNumberOfBits    (LBDRNumberOfBits),
    .NumberOfPorts       (NumberOfOutputPorts),
    .NumberOfVNs         (NumberOfVNs)
  ) filereg_inst (
   .clk_i  (clk),
   .rst_i  (rst),
   //
   .filereg_m_tvalid_i (operation_tvalid),
   .filereg_m_tdata_i  (operation_tdata),
   .filereg_m_tlast_i  (operation_tlast),    //! port available but signal is not processed (safely ignored)
   .filereg_m_tready_o (operation_tready),   //! module can accpet requests
   //
   .filereg_s_tready_i (register_tready),
   .filereg_s_tvalid_o (register_tvalid),
   .filereg_s_tdata_o  (register_tdata),     //! register data and destination id to return the register data
   .filereg_s_tlast_o  (register_tlast),      //! always active, this module expects single frame streams 
   //
   .lbdr_bits_bus_o (lbdr_bits_bus)   //! lbdr configuration bits. All bits of all VNs
  );


  localparam current_data_lsb      = 0;
  localparam current_data_msb      = current_data_lsb + FileRegEntryWidth - 1;
  localparam current_entry_id_lsb  = current_data_msb + 1;
  localparam current_entry_id_msb  = current_entry_id_lsb + FileRegEntryIdWidth - 1;
  localparam current_operation_lsb = current_entry_id_msb + 1;
  localparam current_operation_msb = current_operation_lsb + FileRegCommandIdWidth - 1;
  
  reg [FileRegCommandIdWidth-1:0] operation_command_r;
  reg [FileRegEntryIdWidth-1:0]   operation_entry_id_r;
  reg [FileRegEntryWidth-1:0]     operation_data_r;

  assign operation_tdata[current_operation_msb:current_operation_lsb] = operation_command_r;
  assign operation_tdata[current_entry_id_msb:current_entry_id_lsb]   = operation_entry_id_r;
  assign operation_tdata[current_data_msb:current_data_lsb]           = operation_data_r;
  
  reg operation_values_forced;
  reg [FileRegEntryIdWidth-1:0]   operation_entry_id_forced;
  reg [FileRegEntryWidth-1:0]     operation_data_forced;
  
  always @(posedge clk) begin
    if (rst_gen) begin
      operation_tvalid <= 1'b0;
      operation_data_r  <= `TDATA_INITIAL_VALUE;
      operation_entry_id_r <= `ENTRY_ID_INITIAL_VALUE;
      //operation_command_r  <= `FILEREG_COMMAND_WRITE;
      `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
      $display("@axis_traffic_gen  on reset, prepare Initial value  0x%08h", `TDATA_INITIAL_VALUE);
      `endif
    end else begin
      `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
      $display("@axis_traffic_gen  operation_enable = %d   operation_tready = %d", operation_enable, operation_tready );
      `endif
      if (operation_enable == 1'b1) begin
        `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
        $display("@axis_traffic_gen  toperation_enable is set, checking m_axis_tready ");
        `endif
        operation_tvalid <= 1'b1;
        if (operation_tready == 1'b1) begin
          `ifdef DEBUG_DISPLAY_TRAFFIC_GEN_ENABLE
          $display("@axis_traffic_gen  FileReg ready, update data value  0x%08h -->> 0x%08h", operation_tdata, 
              {operation_tdata[current_operation_msb:current_operation_lsb],
              {operation_tdata[current_entry_id_msb:current_entry_id_lsb] + `ENTRY_ID_INCR},
              {operation_tdata[current_data_msb:current_data_lsb] + `TDATA_INCR}}
              );
          `endif
          if (operation_values_forced) begin
            operation_data_r  <= operation_data_forced;
            operation_entry_id_r <= operation_entry_id_forced;
          end else begin
            operation_data_r  <= operation_data_r + `TDATA_INCR;
            operation_entry_id_r <= operation_entry_id_r + `ENTRY_ID_INCR;
          end
        end else begin
          // next module did not read data, keep old value
        end
      end else begin
        operation_tvalid <= 1'b0;
      end
    end
  end  



  // Testbench loops and tasks
  initial clk = 1'b0;
  always #(ClockHalfPeriod) clk = ~clk;

  task setup(string msg="Setup testcase");
  begin 
    rst = 1'b1;
    rst_test = 1'b0;
    operation_enable = 1'b0;
    register_tready = 1'b0;  // disable read enable of tb 
    operation_command_r  <= `FILEREG_COMMAND_WRITE;
    operation_values_forced <= 1'b0;
  
    // exit reset status
    #(6 * ClockHalfPeriod);
    @(posedge clk);
    rst = 1'b0;

    // end of initialization task
    #(2 * ClockHalfPeriod);
    @(posedge clk);
    
  end
  endtask
  
  task teardown(msg="Tearing down");
  begin
     #(2 * ClockHalfPeriod);
  end
  endtask
  
  // 
  // Testbench 
  integer i;
  reg [8*32-1:0] unit_test_message;
  
  `TEST_SUITE("TESTBENCH FILREG")

  `UNIT_TEST("AFTER RESET STATUS")
    $display("WIP. Debugging after reset status");
    
    @(posedge clk)
    operation_enable <= 1'b0;

    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
   
  `UNIT_TEST_END


  `UNIT_TEST("WRITE REGISTERS")
    @(posedge clk)
    operation_command_r  <= `FILEREG_COMMAND_WRITE;
    
    @(posedge clk)
    operation_enable <= 1'b1;
    
    for (i = 5; i < `FILEREG_NUMBER_OF_ENTRIES; i++) begin
      @(posedge clk);
      operation_enable = 1'b1;
      @(posedge clk);
      operation_enable = 1'b0;
      @(posedge clk);
      operation_enable = 1'b0;       
    end
    
    //// extra cycle: debugging
    //@(posedge clk);
    //operation_enable = 1'b0;
    
    // stop writting request
    @(posedge clk);
    operation_enable = 1'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
   
  `UNIT_TEST_END



  `UNIT_TEST("WRITE THEN READ REGISTERS")
    // run registers writing logic
    @(posedge clk)
    `ifdef DEBUG_DISPLAY_TB_FILEREG_ENABLE
    $display("@UT write->read  set command to write");
    `endif
    unit_test_message = "WRITE";
    operation_command_r  <= `FILEREG_COMMAND_WRITE;
    @(posedge clk)
    @(posedge clk)
    @(posedge clk)
    unit_test_message = "enable";
    operation_enable <= 1'b1;
    for (i = 5; i < `FILEREG_NUMBER_OF_ENTRIES; i++) begin
      @(posedge clk);
      operation_enable = 1'b1;
      @(posedge clk);
      operation_enable = 1'b0;
      @(posedge clk);
      operation_enable = 1'b0;       
    end
    // stop writing logic
    @(posedge clk);
    unit_test_message = "stop";
    operation_enable = 1'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
   
    // run read registers logic
    `ifdef DEBUG_DISPLAY_TB_FILEREG_ENABLE
    $display("");
    $display("");
    $display("@UT write->read  RUN READ LOGIC");
    `endif
    @(posedge clk)
    $display("");
    $display("@UT write->read  reset command generator starts");
    unit_test_message = "reset operation logic";
    rst_test = 1'b1;
    @(posedge clk)
    @(posedge clk)
    @(posedge clk)
    $display("");
    $display("@UT write->read  reset command generator ends");
    unit_test_message = "reset end";
    rst_test = 1'b0;
    
    // enable reading capability from tb to filereg 
    register_tready = 1'b1;
    @(posedge clk)
    
    
    @(posedge clk)
    $display("");
    $display("@UT write->read  set operation command: READ");
    unit_test_message = "READ";
    operation_command_r  <= `FILEREG_COMMAND_READ;
    @(posedge clk)
    @(posedge clk)
    
    @(posedge clk)
    $display("");
    $display("@UT write->read  enable command generator");
    unit_test_message = "enable";
    operation_enable <= 1'b1;
    for (i = 0; i < `FILEREG_NUMBER_OF_ENTRIES; i++) begin
      @(posedge clk);
      operation_enable = 1'b1;
      @(posedge clk);
      operation_enable = 1'b0;
      @(posedge clk);
      operation_enable = 1'b0;       
    end
   // stop read logic
   @(posedge clk);
   $display("");
   $display("@UT write->read  stop command generator");
   unit_test_message = "stop";
   operation_enable = 1'b0;
   @(posedge clk);
   @(posedge clk);
   @(posedge clk);
   $display("");
   $display("@UT write->read  end of unit test");
   @(posedge clk)
  `UNIT_TEST_END


  `UNIT_TEST("WRITE and READ and block reads INTELEAVED")
  
    // Reading capability from tb to filereg is off upon reset 
    //register_tready = 1'b0;
    
    
    // run registers writing logic
    @(posedge clk)
    `ifdef DEBUG_DISPLAY_TB_FILEREG_ENABLE
    $display("@UT write->read  set command to write");
    `endif
    unit_test_message = "WRITE";
    operation_command_r  <= `FILEREG_COMMAND_WRITE;
    @(posedge clk)
    @(posedge clk)
    @(posedge clk)
    unit_test_message = "enable";
    operation_enable <= 1'b1;
    for (i = 5; i < `FILEREG_NUMBER_OF_ENTRIES; i++) begin
      @(posedge clk);
      operation_enable = 1'b1;
      @(posedge clk);
      operation_enable = 1'b0;
      @(posedge clk);
      operation_enable = 1'b0;       
    end
    // stop writing logic
    @(posedge clk);
    unit_test_message = "stop";
    operation_enable = 1'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    
    // trigger read of one single register, output is still blocked, so the value will be stored in output register
    // thn rewrite that register
    // to finally read all regs and check values
    @(posedge clk)
    $display("");
    $display("@UT write->read  enable command generator for just one cycle to read register");
    
    @(posedge clk)
    $display("");
    $display("@UT write->read  set operation command: READ  FORCED VALUES");
    unit_test_message = "READ";
    operation_command_r  <= `FILEREG_COMMAND_READ;
    operation_data_forced = 32'h1122_3344;
    operation_entry_id_forced = 4'ha;  // read register #10 ->a
    operation_values_forced = 1'b1;
    @(posedge clk)
    unit_test_message = "enable";
    operation_enable = 1'b1;
    @(posedge clk)
    $display("@UT write->read  stop command generator");
    unit_test_message = "stop";
    operation_values_forced = 1'b0;
    operation_enable = 1'b0; 
    @(posedge clk);
    
 
    // rewrite all registers
    `ifdef DEBUG_DISPLAY_TB_FILEREG_ENABLE
    $display("");
    $display("");
    $display("@UT write->read  RUN WRITE LOGIC");
    `endif
    
    @(posedge clk)
    $display("");
    $display("@UT write->read  reset command generator starts");
    unit_test_message = "reset operation logic";
    rst_test = 1'b1;
    @(posedge clk)
    @(posedge clk)
    @(posedge clk)
    $display("");
    $display("@UT write->read  reset command generator ends");
    unit_test_message = "reset end";
    rst_test = 1'b0;
    @(posedge clk)
    
     @(posedge clk)
    $display("");
    $display("@UT write->read  set operation command: WRITE");
    unit_test_message = "WRITE";
    operation_command_r  <= `FILEREG_COMMAND_WRITE;
    operation_data_forced = 32'hfaba_0001;
    operation_entry_id_forced = 4'h0;  // read register #10 ->a
    operation_values_forced = 1'b1;
    @(posedge clk)
    @(posedge clk)   
    @(posedge clk)
    $display("");
    $display("@UT write->read  enable command generator");
    unit_test_message = "enable";
    operation_enable <= 1'b1;
    for (i = 0; i < `FILEREG_NUMBER_OF_ENTRIES; i++) begin
      @(posedge clk);
      operation_enable = 1'b1;
      operation_data_forced = i;
      operation_entry_id_forced = i;  // read register #10 ->a
      @(posedge clk);
      operation_enable = 1'b0;
      @(posedge clk);
      operation_enable = 1'b0;       
    end
     // stop write logic
    @(posedge clk);
    $display("");
    $display("@UT write->read  stop command generator");
    unit_test_message = "stop";
    operation_enable = 1'b0;
    operation_values_forced = 1'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
   
    // Register entry now has a differnt value, but output keeps the value of the entry when request was performed 
    
    // enable read logic and read data
    // First value to leave the module will be the old entry value
    register_tready = 1'b1;
    @(posedge clk);
    @(posedge clk);
    
    // let's read the complete filereg content
    
    @(posedge clk)
    $display("");
    $display("@UT write->read  set operation command: READ");
    unit_test_message = "READ";
    operation_command_r  <= `FILEREG_COMMAND_READ;
    @(posedge clk)
    @(posedge clk)
    
    @(posedge clk)
    $display("");
    $display("@UT write->read  enable command generator");
    unit_test_message = "enable";
    operation_enable <= 1'b1;
    for (i = 0; i < `FILEREG_NUMBER_OF_ENTRIES; i++) begin
      @(posedge clk);
      operation_enable = 1'b1;
      @(posedge clk);
      operation_enable = 1'b0;
      @(posedge clk);
      operation_enable = 1'b0;       
    end
   // stop read logic
   @(posedge clk);
   $display("");
   $display("@UT write->read  stop command generator");
   unit_test_message = "stop";
   operation_enable = 1'b0;
   @(posedge clk);
   @(posedge clk);
   @(posedge clk);
   $display("");
   $display("@UT write->read  end of unit test");
   @(posedge clk)



   // end of test
   $display("");
   $display("@UT write->read  end of unit test");
   @(posedge clk)
  `UNIT_TEST_END


  `TEST_SUITE_END
endmodule
