// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file noc_output_handshake_adapter.v 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 26th, 2024
//
// Adapter from Avail/Valid NoC handshake to Valid/Ready
// standar handshake.
//
// It takes into account that the NoC handshake last upto two
// cycles to deassert valid when available is deasserted.
// This is because the downstream module deasserts valid when
// it realizes available is deasserted and this condition happens
// one cycle after deassertion of available and then it takes and
// additional cycle to deassert valid.

`timescale 1ns / 1ps

module noc_outport_handshake_adapter #(
  parameter DataWidth = 0
) (
  input wire                  clk,
  input wire                  rst,
  // signals from NoC Local module interface to noc_outport_handshake_adapter
  input wire [DataWidth-1:0]  data_i,
  input wire                  data_valid_i,
  output reg                  avail_o,
  // signals from noc_outport_handshake_adapter to 
  //   RTL standard ready/valid interface (e.g. Xilinx native FIFO)
  output reg [DataWidth-1:0]  data_o,
  output reg                  data_valid_o,
  input  wire                 full_i
);

  //  fsm_state_e state, next_state;
  localparam IDLE  = 2'b00;
  localparam MEM1  = 2'b01;
  localparam MEM2  = 2'b10;
  reg [1:0] state;
  reg [1:0] next_state;


  // Memory to store the valid data that could come when
  // NoC avail is deasserted
  reg [DataWidth-1:0] data_i_buff[0:1];
  reg                 buff1_en;
  reg                 buff2_en;  
  
  // these are combinational paths
  reg                 data_valid_from_mux;
  reg [DataWidth-1:0] data_from_mux;
  reg                 handshake_complete;
  
  wire output_reg_busy;
  
  assign output_reg_busy = (data_valid_o == 1) && (handshake_complete == 0);

  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always @(*) begin
    next_state = IDLE;

    case (state)
      IDLE: begin
        if ((data_valid_i == 1) && (output_reg_busy == 1)) begin
          next_state = MEM1;
        end
      end

      MEM1: begin
        if ((data_valid_i == 1) && (handshake_complete == 0)) begin
          next_state = MEM2;
        end
        
        if ((data_valid_i == 1) && (handshake_complete == 1)) begin
          next_state = MEM1;
        end                
        
        if ((data_valid_i == 0) && (handshake_complete == 0)) begin
          next_state = MEM1;
        end
      end
      
      MEM2: begin
        // In this state, data_valid_i must be deasserted already
        if (handshake_complete == 0) begin
          next_state = MEM2;
        end
        
        if (handshake_complete == 1) begin
          next_state = MEM1;
        end
      end
    endcase
  end

  // It cannot be ~full_i because of in Valid/Ready handshake ready could be
  // asserted only when valid is asserted, but
  // in the network handshake valid cannot be asserted
  // upto avail_o is asserted, so the ejector would not receive valids
  // from network if the other end (Valid/Ready handshake) 
  // waits for valid before asserting ready since avail_o = ~full_i
  // means propagate ready.
  always @(*) begin
    avail_o = (data_valid_o == 1'b0);
  end
  
  // Buffer enablers
  always @(*) begin
    buff1_en = ((state == IDLE) && (data_valid_i == 1'b1) && (output_reg_busy == 1)) ||
               ((state == MEM1) && (data_valid_i == 1'b1) && (handshake_complete == 1));
    buff2_en = ((state == MEM1) && (data_valid_i == 1'b1) && (handshake_complete == 0));
  end
  
  always @(*) begin
    handshake_complete = (full_i == 1'b0) && (data_valid_o == 1'b1);
  end
  
  // FIFO mode
  always @(posedge clk) begin
    if (rst) begin
    end else if ((buff1_en == 1) || (buff2_en == 1)) begin 
      data_i_buff[0] <= data_i;
    end
  end
  always @(posedge clk) begin
    if (rst) begin
    end else if (buff2_en == 1) begin
      data_i_buff[1] <= data_i_buff[0];        
    end
  end
    
  
  // Mux to select what goes to the data Valid/Ready interface
  //  Select==0: data coming from input
  //  Select==1: data coming from internal memory 1
  //  Select==2; data coming from internal memory 2
  always @(*) begin
    data_valid_from_mux = data_valid_i;
    data_from_mux = data_i;
    
    if (state == MEM1) begin
      data_valid_from_mux = 1;
      data_from_mux       = data_i_buff[0];
    end
    
    if (state == MEM2) begin
      data_valid_from_mux = 1;
      data_from_mux       = data_i_buff[1];
    end    
  end
  
  // Output data Valid/Ready interface
  always @(posedge clk) begin
    if (rst) begin
      data_valid_o <= 0;
   end else if ((handshake_complete) || (data_valid_o == 1'b0)) begin
      data_valid_o <= data_valid_from_mux;
      data_o       <= data_from_mux;
    end
  end
  
endmodule
