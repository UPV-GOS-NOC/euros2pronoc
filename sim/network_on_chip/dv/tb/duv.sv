// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file duv.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 08th, 2024
//
// @title Design to verify the NoC
//
// The design is composed of several tiles layout
// in a 2D grid. Each tile contains an AXI VIP 
// (Manager or subordinate), a Single Unit
// Network Interface and a NoC Router
//

`timescale 1ns/1ns


module duv (
  // clocks and resets
  input clk_s_axis_i,
  input clk_m_axis_i,
  input clk_network_i,
  input clk_upsizer_i,
  input clk_downsizer_i,

  input rst_s_axis_ni,
  input rst_m_axis_ni,
  input rst_network_i,
  input rst_upsizer_i,
  input rst_downsizer_i
);

  `include "common_functions.vh"

//
// Gets the number of bits required to encode a value
//
// Params:
//  value, the value to encode
//
// Returns:
//  The number of bits required to encode value input param
//
function integer bitsize(integer value);
  begin
    if (value <= 1)
      bitsize = 1;
    else
      bitsize = Log2(value);
  end
endfunction

  localparam integer AXISTREAM_TDATA_WIDTH = 32;
  localparam integer AXISTREAM_TID_WIDTH   = 5;
  localparam integer AXISTREAM_TDEST_WIDTH = 11;
  
  localparam integer M_AXIS_TILE               = 2;
  localparam integer MESH_TOPOLOGY_DIMENSION_X = 4;
  localparam integer MESH_TOPOLOGY_DIMENSION_Y = 2;
  localparam integer NUMBEROF_NODES            = MESH_TOPOLOGY_DIMENSION_X * MESH_TOPOLOGY_DIMENSION_Y;


  localparam integer NETWORK_FLIT_WIDTH                = 64;
  localparam integer NETWORK_FLIT_TYPE_WIDTH           = 2;
  localparam integer NETWORK_BROADCAST_WIDTH           = 1;
  localparam integer NETWORK_NUMBEROF_VIRTUAL_NETWORKS = 3;
  localparam integer NETWORK_NUMBEROF_VIRTUAL_CHANNELS = 3;
  localparam integer NETWORK_VIRTUAL_NETWORK_ID_WIDTH  = bitsize(NETWORK_NUMBEROF_VIRTUAL_NETWORKS);
  localparam integer NETWORK_VIRTUAL_CHANNEL_ID_WIDTH  = bitsize(NETWORK_NUMBEROF_VIRTUAL_CHANNELS);
  localparam integer NETWORK_DATA_WIDTH = NETWORK_FLIT_WIDTH +
                                          NETWORK_FLIT_TYPE_WIDTH +
                                          NETWORK_BROADCAST_WIDTH +
                                          NETWORK_VIRTUAL_CHANNEL_ID_WIDTH;
  
  localparam integer NUMBEROF_SWITCH_PORTS = 4;
  
  // constants to index multidimensional arrays, providing in/out signal meaning
  localparam integer IN = 0;
  localparam integer OUT = 1;
  
  // indexes for the second dimension in switch_xxx multidemensional array
  localparam integer NORTH = 3;
  localparam integer EAST  = 2;
  localparam integer WEST  = 1;
  localparam integer SOUTH = 0;  
  
  // Drive connections among tiles using multidimensional arrays
  // First dimension: tiles or nodes in the topology
  // Second dimension: input and output signals (use IN and OUT constants to index this dimension)
  // Third dimension: data and control signals
  wire [NUMBEROF_SWITCH_PORTS*NETWORK_DATA_WIDTH-1:0]                tile2tile_network_data[0:NUMBEROF_NODES-1][0:1];
  wire [NUMBEROF_SWITCH_PORTS-1:0]                                   tile2tile_network_valid[0:NUMBEROF_NODES-1][0:1];
  wire [NUMBEROF_SWITCH_PORTS*NETWORK_NUMBEROF_VIRTUAL_CHANNELS-1:0] tile2tile_network_go[0:NUMBEROF_NODES-1][0:1];




  // Instance tiles
  generate
    for (genvar i = 0; i < NUMBEROF_NODES; i = i+1) begin : tile
      // Depending on the location of the tile in the 2D-mesh topology 
      // it will have a different number of ports to connect tiles among them
      localparam SWITCH_NUMBEROF_PORTS = 4;
      
      if (i == M_AXIS_TILE) begin : m_axis
      axis_vip_tile #(
        .NetworkSwitchAddressId     (i),
        .NetworkSwitchAddressIdWidth(11),
        .NetworkSwitchNumberOfPorts (SWITCH_NUMBEROF_PORTS),
        .MeshTopologyDimensionX     (MESH_TOPOLOGY_DIMENSION_X),
        .MeshTopologyDimensionY     (MESH_TOPOLOGY_DIMENSION_Y),

        .NetworkIfFlitWidth              (NETWORK_FLIT_WIDTH),
        .NetworkIfFlitTypeWidth          (NETWORK_FLIT_TYPE_WIDTH),
        .NetworkIfBroadcastWidth         (NETWORK_BROADCAST_WIDTH),
        .NetworkIfVirtualNetworkIdWidth  (NETWORK_VIRTUAL_NETWORK_ID_WIDTH),
        .NetworkIfVirtualChannelIdWidth  (NETWORK_VIRTUAL_CHANNEL_ID_WIDTH),
        .NetworkIfNumberOfVirtualChannels(NETWORK_NUMBEROF_VIRTUAL_CHANNELS),
        .NetworkIfNumberOfVirtualNetworks(NETWORK_NUMBEROF_VIRTUAL_NETWORKS),
       
        .AxiStreamTargetIfEnable    (0),
        .AxiStreamTargetIfTDataWidth(1),
        .AxiStreamTargetIfTIdWidth  (1),
        .AxiStreamTargetIfTDestWidth(1),

        .AxiStreamInitiatorIfEnable    (1),
        .AxiStreamInitiatorIfTDataWidth(AXISTREAM_TDATA_WIDTH),
        .AxiStreamInitiatorIfTIdWidth  (AXISTREAM_TID_WIDTH),
        .AxiStreamInitiatorIfTDestWidth(AXISTREAM_TDEST_WIDTH)
       ) vip_inst (
        // CLKs AND RESETs
        .clk_s_axis_i   (clk_s_axis_i),
        .clk_m_axis_i   (clk_m_axis_i),
        .clk_network_i  (clk_network_i),
        .clk_upsizer_i  (clk_upsizer_i),
        .clk_downsizer_i(clk_downsizer_i),

        .rst_s_axis_ni  (rst_s_axis_ni),
        .rst_m_axis_ni  (rst_m_axis_ni),
        .rst_network_i  (rst_network_i),
        .rst_upsizer_i  (rst_upsizer_i),
        .rst_downsizer_i(rst_downsizer_i),

        .network_valid_i(tile2tile_network_valid[i][IN][SWITCH_NUMBEROF_PORTS-1:0]),
        .network_go_o   (tile2tile_network_go[i][OUT][SWITCH_NUMBEROF_PORTS*NETWORK_NUMBEROF_VIRTUAL_CHANNELS-1:0]),
        .network_data_i (tile2tile_network_data[i][IN][SWITCH_NUMBEROF_PORTS*NETWORK_DATA_WIDTH-1:0]),
        .network_valid_o(tile2tile_network_valid[i][OUT][SWITCH_NUMBEROF_PORTS-1:0]),
        .network_go_i   (tile2tile_network_go[i][IN][SWITCH_NUMBEROF_PORTS*NETWORK_NUMBEROF_VIRTUAL_CHANNELS-1:0]),
        .network_data_o (tile2tile_network_data[i][OUT][SWITCH_NUMBEROF_PORTS*NETWORK_DATA_WIDTH-1:0])
      );
      end else begin : s_axis
      axis_vip_tile #(
        .NetworkSwitchAddressId     (i),
        .NetworkSwitchAddressIdWidth(11),
        .NetworkSwitchNumberOfPorts (SWITCH_NUMBEROF_PORTS),
        .MeshTopologyDimensionX     (MESH_TOPOLOGY_DIMENSION_X),
        .MeshTopologyDimensionY     (MESH_TOPOLOGY_DIMENSION_Y),
        
        .NetworkIfFlitWidth              (NETWORK_FLIT_WIDTH),
        .NetworkIfFlitTypeWidth          (NETWORK_FLIT_TYPE_WIDTH),
        .NetworkIfBroadcastWidth         (NETWORK_BROADCAST_WIDTH),
        .NetworkIfVirtualNetworkIdWidth  (NETWORK_VIRTUAL_NETWORK_ID_WIDTH),
        .NetworkIfVirtualChannelIdWidth  (NETWORK_VIRTUAL_CHANNEL_ID_WIDTH),
        .NetworkIfNumberOfVirtualChannels(NETWORK_NUMBEROF_VIRTUAL_CHANNELS),
        .NetworkIfNumberOfVirtualNetworks(NETWORK_NUMBEROF_VIRTUAL_NETWORKS),
       
        .AxiStreamTargetIfEnable    (1),
        .AxiStreamTargetIfTDataWidth(AXISTREAM_TDATA_WIDTH),
        .AxiStreamTargetIfTIdWidth  (AXISTREAM_TID_WIDTH),
        .AxiStreamTargetIfTDestWidth(AXISTREAM_TDEST_WIDTH),

        .AxiStreamInitiatorIfEnable    (0),
        .AxiStreamInitiatorIfTDataWidth(1),
        .AxiStreamInitiatorIfTIdWidth  (1),
        .AxiStreamInitiatorIfTDestWidth(1)
      ) vip_inst (
        // CLKs AND RESETS
        .clk_s_axis_i   (clk_s_axis_i),
        .clk_m_axis_i   (clk_m_axis_i),
        .clk_network_i  (clk_network_i),
        .clk_upsizer_i  (clk_upsizer_i),
        .clk_downsizer_i(clk_downsizer_i),

        .rst_s_axis_ni  (rst_s_axis_ni),
        .rst_m_axis_ni  (rst_m_axis_ni),
        .rst_network_i  (rst_network_i),
        .rst_upsizer_i  (rst_upsizer_i),
        .rst_downsizer_i(rst_downsizer_i),

        .network_valid_i(tile2tile_network_valid[i][IN][SWITCH_NUMBEROF_PORTS-1:0]),
        .network_go_o   (tile2tile_network_go[i][OUT][SWITCH_NUMBEROF_PORTS*NETWORK_NUMBEROF_VIRTUAL_CHANNELS-1:0]),
        .network_data_i (tile2tile_network_data[i][IN][SWITCH_NUMBEROF_PORTS*NETWORK_DATA_WIDTH-1:0]),
        .network_valid_o(tile2tile_network_valid[i][OUT][SWITCH_NUMBEROF_PORTS-1:0]),
        .network_go_i   (tile2tile_network_go[i][IN][SWITCH_NUMBEROF_PORTS*NETWORK_NUMBEROF_VIRTUAL_CHANNELS-1:0]),
        .network_data_o (tile2tile_network_data[i][OUT][SWITCH_NUMBEROF_PORTS*NETWORK_DATA_WIDTH-1:0])
      );
      end
    end
  endgenerate
  
  // Interconnect tiles following a 2D-mesh topology
  generate
  
    `define CONNECT_TILE_TO_TILE(REF_TILE, REF_PORT, TARGET_TILE, TARGET_PORT) \
        localparam integer OFFSETOF_TARGET_PORT = get_2dmesh_switch_port(TARGET_TILE, \
            TARGET_PORT, MESH_TOPOLOGY_DIMENSION_X, MESH_TOPOLOGY_DIMENSION_Y); \
        localparam integer OFFSETOF_REF_PORT = get_2dmesh_switch_port(REF_TILE,\
            REF_PORT, MESH_TOPOLOGY_DIMENSION_X, MESH_TOPOLOGY_DIMENSION_Y); \
        assign tile2tile_network_valid[TARGET_TILE][IN][OFFSETOF_TARGET_PORT] = tile2tile_network_valid[REF_TILE][OUT][OFFSETOF_REF_PORT]; \
        assign tile2tile_network_go[TARGET_TILE][IN][OFFSETOF_TARGET_PORT*NETWORK_NUMBEROF_VIRTUAL_CHANNELS +: NETWORK_NUMBEROF_VIRTUAL_CHANNELS] = \
            tile2tile_network_go[REF_TILE][OUT][OFFSETOF_REF_PORT*NETWORK_NUMBEROF_VIRTUAL_CHANNELS +: NETWORK_NUMBEROF_VIRTUAL_CHANNELS]; \
        assign tile2tile_network_data[TARGET_TILE][IN][OFFSETOF_TARGET_PORT*NETWORK_DATA_WIDTH +: NETWORK_DATA_WIDTH] = \
            tile2tile_network_data[REF_TILE][OUT][OFFSETOF_REF_PORT*NETWORK_DATA_WIDTH +: NETWORK_DATA_WIDTH];
         
    for (genvar tile_id = 0; 
                tile_id < (MESH_TOPOLOGY_DIMENSION_X * MESH_TOPOLOGY_DIMENSION_Y);
                tile_id = tile_id + 1) begin : tile2tile_connectivity
      
      // South to North connections
      if (tile_id < (MESH_TOPOLOGY_DIMENSION_Y - 1) * MESH_TOPOLOGY_DIMENSION_X) begin : south2north
        // It is not the last row
        `CONNECT_TILE_TO_TILE(tile_id, SOUTH, tile_id + MESH_TOPOLOGY_DIMENSION_X, NORTH)
      end
      
      // North to South connections
      if (tile_id >= MESH_TOPOLOGY_DIMENSION_X) begin : north2south
        // It is not the first row
        `CONNECT_TILE_TO_TILE(tile_id, NORTH, tile_id - MESH_TOPOLOGY_DIMENSION_X, SOUTH)
      end
     
      // East to west connections
      if (tile_id % MESH_TOPOLOGY_DIMENSION_X != MESH_TOPOLOGY_DIMENSION_X - 1) begin : east2west
        // it is not the last column
        `CONNECT_TILE_TO_TILE(tile_id, EAST, tile_id + 1, WEST)
      end
    
      // West to East connections
      if (tile_id % MESH_TOPOLOGY_DIMENSION_X != 0) begin : west2east
        // it is not the first column
        `CONNECT_TILE_TO_TILE(tile_id, WEST, tile_id - 1, EAST)
      end
    end
  endgenerate

  // Maps the original port to the corresponding offset in a packed vector
  // by taking into account that the 2dmesh switch has four ports (NEWS format),
  // North port equals to index 3
  // East port equals to index 2
  // West port equals to index 1
  // South port equals to index 0
  // Every index corresponds to an offset in a packed vector
  // but each tile only exposes the ports that are currently connected.
  // It means that if a tile does not connect in a given direction to another tile
  // (p.e. tiles in the first row of a 2D-mesh do not connect their north port),
  // then the upper ports are shifted to the right to avoid unassigned signals in vectors
  function integer get_2dmesh_switch_port(input integer switch_id, 
                                          input integer port, 
                                          input integer dimx, 
                                          input integer dimy); 
    begin
      get_2dmesh_switch_port = port;
      if (switch_id < dimx) begin : first_row
        if (switch_id == 0) begin : first
          case (port)
            0: get_2dmesh_switch_port = 0;
            2: get_2dmesh_switch_port = 1;
            default: get_2dmesh_switch_port = 2;
          endcase
        end else if (switch_id == dimx - 1) begin : last
          case (port)
            0: get_2dmesh_switch_port = 0;
            1: get_2dmesh_switch_port = 1;
            default: get_2dmesh_switch_port = 2;
          endcase
        end else begin : middle
          get_2dmesh_switch_port = port;
        end
      end else if (switch_id / dimx == dimy - 1) begin : last_row
        if (switch_id % dimx == 0) begin : first
          case (port)
            2: get_2dmesh_switch_port = 0;
            3: get_2dmesh_switch_port = 1;
            default: get_2dmesh_switch_port = 2;
          endcase
        end else if (switch_id == dimx * dimy - 1) begin : last
          case (port)
            1: get_2dmesh_switch_port = 0;
            3: get_2dmesh_switch_port = 1;
            default: get_2dmesh_switch_port = 2;
          endcase
        end else begin : middle
          get_2dmesh_switch_port = port - 1;
        end
      end else if (switch_id % dimx == 0) begin : first_column
        // but no corner cases, they are treated as part of first and last row
        case (port)
          0: get_2dmesh_switch_port = 0;
          2: get_2dmesh_switch_port = 1;
          3: get_2dmesh_switch_port = 2;
          default: get_2dmesh_switch_port = 3;
        endcase
      end else if (switch_id % dimx == dimx - 1) begin : last_column
        // but no corner cases, they are treated as part of first and last row
        case (port)
          0: get_2dmesh_switch_port = 0;
          1: get_2dmesh_switch_port = 1;
          3: get_2dmesh_switch_port = 2;
          default: get_2dmesh_switch_port = 3;
        endcase
      end
    end
  endfunction
  
endmodule
