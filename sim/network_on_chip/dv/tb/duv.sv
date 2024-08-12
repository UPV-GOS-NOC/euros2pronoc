// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file duv.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date March 08th, 2024 (Initial version)
// @date July 29th, 2024 (Major update)
//
// @title Design for NoC Verification
//
// The design is composed of several tiles allocated
// in a 2D grid layout. The grid and the number of tiles
// depend on module configuration parameters. 
//
// There is an AXI-Stream Manager VIP core, 
// an AXI-Stream Manager VIP core, a Single Unit
// Network Interface and a NoC Switch in each tile.
//
// The AXI-Stream Manager and subordinate VIP core mimic the tile PE
// and, here, it is used basically for injecting 
// AXI-Stream frames into the on-chip network through
// the NI. 
//
// The simulation environment will configure one of
// the AXI-Stream Manager VIP cores to act as a
// NoC Controller and reconfigure routing algorithm
// of network switches at runtime.
//
// In addition, the simulation environment will enable either the
// AXIS Manager or AXIS subordinate VIP core per tile.
//

`timescale 1ns/1ns

module duv #(
  parameter integer AXIStreamTDataWidth = 0,
  parameter integer AXIStreamTIdWidth   = 0,
  parameter integer AXIStreamTDestWidth = 0,

  // Size of the 2D Mesh topology, given by the 
  // number of nodes in dimension X and Y respectively
  // The Tile address are assigned from left to right and
  // top to bottom
  parameter  integer Mesh2DTopologyDimensionX = 0,
  parameter  integer Mesh2DTopologyDimensionY = 0,
  localparam integer NumberOfTiles = Mesh2DTopologyDimensionX * Mesh2DTopologyDimensionY,  

  // NoC parameters
  parameter integer NetworkSwitchAddressIdWidth    = 0, 
  parameter integer NetworkFlitWidth               = 0,
  parameter integer NetworkFlitTypeWidth           = 0,
  parameter integer NetworkBroadcastWidth          = 0,
  parameter integer NetworkNumberOfVirtualNetworks = 0,
  parameter integer NetworkNumberOfVirtualChannels = 0,
  parameter integer NetworkVirtualNetworkIdWidth   = 0, 
  parameter integer NetworkVirtualChannelIdWidth   = 0

) (
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

  // Size of the compound network signal 
  localparam integer NetworkDataWidth = NetworkFlitWidth +
                                        NetworkFlitTypeWidth +
                                        NetworkBroadcastWidth +
                                        NetworkVirtualChannelIdWidth;
  
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
  wire [NUMBEROF_SWITCH_PORTS*NetworkDataWidth-1:0]               tile2tile_network_data[0:NumberOfTiles-1][0:1];
  wire [NUMBEROF_SWITCH_PORTS-1:0]                                tile2tile_network_valid[0:NumberOfTiles-1][0:1];
  wire [NUMBEROF_SWITCH_PORTS*NetworkNumberOfVirtualChannels-1:0] tile2tile_network_go[0:NumberOfTiles-1][0:1];




  // Instance tiles
  generate
    for (genvar i = 0; i < NumberOfTiles; i = i+1) begin : tile
      // TODO Depending on the location of the tile in the 2D-mesh topology 
      // it will have a different number of ports to connect tiles among them
      //
      // For now, we will keep every router with four ports (NEWS)
      localparam SWITCH_NUMBEROF_PORTS = 4;
      
      axis_vip_tile #(
        .NetworkSwitchAddressId     (i),
        .NetworkSwitchAddressIdWidth(NetworkSwitchAddressIdWidth),
        .NetworkSwitchNumberOfPorts (SWITCH_NUMBEROF_PORTS),
        .MeshTopologyDimensionX     (Mesh2DTopologyDimensionX),
        .MeshTopologyDimensionY     (Mesh2DTopologyDimensionY),

        .NetworkIfFlitWidth              (NetworkFlitWidth),
        .NetworkIfFlitTypeWidth          (NetworkFlitTypeWidth),
        .NetworkIfBroadcastWidth         (NetworkBroadcastWidth),
        .NetworkIfVirtualNetworkIdWidth  (NetworkVirtualNetworkIdWidth),
        .NetworkIfVirtualChannelIdWidth  (NetworkVirtualChannelIdWidth),
        .NetworkIfNumberOfVirtualChannels(NetworkNumberOfVirtualChannels),
        .NetworkIfNumberOfVirtualNetworks(NetworkNumberOfVirtualNetworks),
         
        .AxiStreamTargetIfEnable    (1),
        .AxiStreamTargetIfTDataWidth(AXIStreamTDataWidth),
        .AxiStreamTargetIfTIdWidth  (AXIStreamTIdWidth),
        .AxiStreamTargetIfTDestWidth(AXIStreamTDestWidth),

        .AxiStreamInitiatorIfEnable    (1),
        .AxiStreamInitiatorIfTDataWidth(AXIStreamTDataWidth),
        .AxiStreamInitiatorIfTIdWidth  (AXIStreamTIdWidth),
        .AxiStreamInitiatorIfTDestWidth(AXIStreamTDestWidth)
       ) axis_vip_inst (
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
        .network_go_o   (tile2tile_network_go[i][OUT][SWITCH_NUMBEROF_PORTS*NetworkNumberOfVirtualChannels-1:0]),
        .network_data_i (tile2tile_network_data[i][IN][SWITCH_NUMBEROF_PORTS*NetworkDataWidth-1:0]),
        .network_valid_o(tile2tile_network_valid[i][OUT][SWITCH_NUMBEROF_PORTS-1:0]),
        .network_go_i   (tile2tile_network_go[i][IN][SWITCH_NUMBEROF_PORTS*NetworkNumberOfVirtualChannels-1:0]),
        .network_data_o (tile2tile_network_data[i][OUT][SWITCH_NUMBEROF_PORTS*NetworkDataWidth-1:0])
      );
    end : tile
  endgenerate
  
  // Interconnect tiles following a 2D-mesh topology
  generate
  
    `define CONNECT_TILE_TO_TILE(REF_TILE, REF_PORT, TARGET_TILE, TARGET_PORT) \
        localparam integer OFFSETOF_TARGET_PORT = get_2dmesh_switch_port(TARGET_TILE, \
            TARGET_PORT, Mesh2DTopologyDimensionX, Mesh2DTopologyDimensionY); \
        localparam integer OFFSETOF_REF_PORT = get_2dmesh_switch_port(REF_TILE,\
            REF_PORT, Mesh2DTopologyDimensionX, Mesh2DTopologyDimensionY); \
        assign tile2tile_network_valid[TARGET_TILE][IN][OFFSETOF_TARGET_PORT] = tile2tile_network_valid[REF_TILE][OUT][OFFSETOF_REF_PORT]; \
        assign tile2tile_network_go[TARGET_TILE][IN][OFFSETOF_TARGET_PORT*NetworkNumberOfVirtualChannels +: NetworkNumberOfVirtualChannels] = \
            tile2tile_network_go[REF_TILE][OUT][OFFSETOF_REF_PORT*NetworkNumberOfVirtualChannels +: NetworkNumberOfVirtualChannels]; \
        assign tile2tile_network_data[TARGET_TILE][IN][OFFSETOF_TARGET_PORT*NetworkDataWidth +: NetworkDataWidth] = \
            tile2tile_network_data[REF_TILE][OUT][OFFSETOF_REF_PORT*NetworkDataWidth +: NetworkDataWidth];
         
    for (genvar tile_id = 0; 
                tile_id < (Mesh2DTopologyDimensionX * Mesh2DTopologyDimensionY);
                tile_id = tile_id + 1) begin : tile2tile_connectivity
      
      // South to North connections
      if (tile_id < (Mesh2DTopologyDimensionY - 1) * Mesh2DTopologyDimensionX) begin : south2north
        // It is not the last row
        `CONNECT_TILE_TO_TILE(tile_id, SOUTH, tile_id + Mesh2DTopologyDimensionX, NORTH)
      end
      
      // North to South connections
      if (tile_id >= Mesh2DTopologyDimensionX) begin : north2south
        // It is not the first row
        `CONNECT_TILE_TO_TILE(tile_id, NORTH, tile_id - Mesh2DTopologyDimensionX, SOUTH)
      end
     
      // East to west connections
      if (tile_id % Mesh2DTopologyDimensionX != Mesh2DTopologyDimensionX - 1) begin : east2west
        // it is not the last column
        `CONNECT_TILE_TO_TILE(tile_id, EAST, tile_id + 1, WEST)
      end
    
      // West to East connections
      if (tile_id % Mesh2DTopologyDimensionX != 0) begin : west2east
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
