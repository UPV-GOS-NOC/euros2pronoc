// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file network_instance.svh
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 24th, 2024
//
// This file is intented to be included in
// an heterogeneous tile-based design, 
// where there exist different set of tiles
// interconnected through a common network.
//
// The idea is to facilitate reuse and maintenance.
//
// It is not intended to be used in standalone mode.


// They FileRegXXXIfYYY parameters follow CamelCase convention because they can turn into parameters in the future
// FileReg Initiator interface configuration. 0 to disable the interface and 1 to enable it.
localparam integer FileRegInitiatorIfEnable = 0;

// FileReg Initiator interface configuration. Size (in bits) of the TData port
localparam integer FileRegInitiatorIfTDataWidth = 32 + NetworkSwitchAddressIdWidth;

// FileReg Target interface configuration. 0 to disable the interface and 1 to enable it. 
localparam integer FileRegTargetIfEnable = 1;

// FileReg Target interface configuration. Size (in bits) of the TData port
localparam integer FileRegTargetIfTDataWidth = 39;   


// Indexes in the signals network array (network_xxx)
localparam integer NI2ROUTER = 0;
localparam integer ROUTER2NI = 1;

// Indexes in multidemensional arrays that requires notion of in and out signals
localparam integer IN  = 0;
localparam integer OUT = 1;

// indexes for the second dimension in switch_xxx multidemensional array
localparam integer NORTH = 3;
localparam integer EAST  = 2;
localparam integer WEST  = 1;
localparam integer SOUTH = 0;

// Let's use Constant convention here since both Constant and Parameters are mixed here
localparam integer NETWORK_FLIT_LSB = 0;
localparam integer NETWORK_FLIT_MSB = NETWORK_FLIT_LSB + NetworkIfFlitWidth - 1;
localparam integer NETWORK_FLIT_TYPE_LSB = NETWORK_FLIT_MSB + 1;
localparam integer NETWORK_FLIT_TYPE_MSB = NETWORK_FLIT_TYPE_LSB + NetworkIfFlitTypeWidth - 1;
localparam integer NETWORK_BROADCAST_LSB = NETWORK_FLIT_TYPE_MSB + 1;
localparam integer NETWORK_BROADCAST_MSB = NETWORK_BROADCAST_LSB + NetworkIfBroadcastWidth - 1;
localparam integer NETWORK_VIRTUAL_CHANNEL_ID_LSB = NETWORK_BROADCAST_MSB + 1;
localparam integer NETWORK_VIRTUAL_CHANNEL_ID_MSB = NETWORK_VIRTUAL_CHANNEL_ID_LSB + NetworkIfVirtualChannelIdWidth - 1;

`define SWITCH_FLIT_RANGE               NETWORK_FLIT_MSB:NETWORK_FLIT_LSB
`define SWITCH_FLIT_TYPE_RANGE          NETWORK_FLIT_TYPE_MSB:NETWORK_FLIT_TYPE_LSB
`define SWITCH_BROADCAST_RANGE          NETWORK_BROADCAST_MSB:NETWORK_BROADCAST_LSB
`define SWITCH_VIRTUAL_CHANNEL_ID_RANGE NETWORK_VIRTUAL_CHANNEL_ID_MSB:NETWORK_VIRTUAL_CHANNEL_ID_LSB


// Network signals between NI and Network Switch
wire                                      network_valid[0:1];
wire [NetworkIfFlitWidth-1:0]             network_flit[0:1];
wire [NetworkIfFlitTypeWidth-1:0]         network_flit_type[0:1];
wire [NetworkIfBroadcastWidth-1:0]        network_broadcast[0:1];
wire [NetworkIfVirtualNetworkIdWidth-1:0] network_virtual_network_id;
wire [NetworkIfVirtualChannelIdWidth-1:0] network_virtual_channel_id;
wire [NetworkIfNumberOfVirtualChannels-1:0] network_virtual_channel_ready;
wire [NetworkIfNumberOfVirtualNetworks-1:0] network_virtual_network_ready;

// Network signals to drive tiles among them through input and ouputs of the switches
// Multidemensional array:
//  First dimension: In/out. Second dimension: Port. Third dimension: Data-bit signal
wire [NetworkIfDataWidth-1:0]               switch_data[0:1][0:3];
wire                                        switch_valid[0:1][0:3];
wire [NetworkIfNumberOfVirtualChannels-1:0] switch_go[0:1][0:3];

// AXI-Stream (Target) interface for PE connection
wire                                   s_axis_tvalid;
wire                                   s_axis_tready;
wire [AxiStreamTargetIfTDataWidth-1:0] s_axis_tdata;
wire                                   s_axis_tlast;
wire [AxiStreamTargetIfTIdWidth-1:0]   s_axis_tid;
wire [AxiStreamTargetIfTDestWidth-1:0] s_axis_tdest;

// AXI-Stream (Initiator) interface for PE connection
wire [AxiStreamInitiatorIfTDataWidth-1:0] m_axis_tdata;
wire                                      m_axis_tvalid;
wire                                      m_axis_tready;
wire                                      m_axis_tlast;
wire [AxiStreamInitiatorIfTIdWidth-1:0]   m_axis_tid;
wire [AxiStreamInitiatorIfTDestWidth-1:0] m_axis_tdest; 

single_unit_network_interface #(
  .NetworkIfAddressId              (NetworkSwitchAddressId),
  .NetworkIfFlitWidth              (NetworkIfFlitWidth),
  .NetworkIfFlitTypeWidth          (NetworkIfFlitTypeWidth),
  .NetworkIfBroadcastWidth         (NetworkIfBroadcastWidth),
  .NetworkIfVirtualChannelIdWidth  (NetworkIfVirtualChannelIdWidth),
  .NetworkIfVirtualNetworkIdWidth  (NetworkIfVirtualNetworkIdWidth),
  .NetworkIfNumberOfVirtualChannels(NetworkIfNumberOfVirtualChannels),
  .NetworkIfNumberOfVirtualNetworks(NetworkIfNumberOfVirtualNetworks),

  .AxiStreamTargetIfEnable    (AxiStreamInitiatorIfEnable),
  .AxiStreamTargetIfTDataWidth(AxiStreamInitiatorIfTDataWidth),
  .AxiStreamTargetIfTIdWidth  (AxiStreamInitiatorIfTIdWidth),
  .AxiStreamTargetIfTDestWidth(AxiStreamInitiatorIfTDestWidth),
  
  .AxiStreamInitiatorIfEnable    (AxiStreamTargetIfEnable),
  .AxiStreamInitiatorIfTDataWidth(AxiStreamTargetIfTDataWidth),
  .AxiStreamInitiatorIfTIdWidth  (AxiStreamTargetIfTIdWidth),
  .AxiStreamInitiatorIfTDestWidth(AxiStreamTargetIfTDestWidth),

  .FileRegInitiatorIfEnable    (FileRegTargetIfEnable),
  .FileRegInitiatorIfTDataWidth(FileRegTargetIfTDataWidth),

  .FileRegTargetIfEnable    (FileRegInitiatorIfEnable),
  .FileRegTargetIfTDataWidth(FileRegInitiatorIfTDataWidth)
) network_interface_inst (
  .clk_s_axis_i   (clk_m_axis_i),
  .clk_m_axis_i   (clk_s_axis_i),
  .clk_network_i  (clk_network_i),
  .clk_upsizer_i  (clk_upsizer_i),
  .clk_downsizer_i(clk_downsizer_i),

  .rst_s_axis_ni  (rst_m_axis_ni),
  .rst_m_axis_ni  (rst_s_axis_ni),
  .rst_network_i  (rst_network_i),
  .rst_upsizer_i  (rst_upsizer_i),
  .rst_downsizer_i(rst_downsizer_i),

  // Configuration and monitoring file register access interface
  .filereg_s_tvalid_i(m_filereg_if.valid),
  .filereg_s_tready_o(m_filereg_if.ready),
  .filereg_s_tdata_i (m_filereg_if.data),
  .filereg_s_tlast_i (m_filereg_if.last),
  //
  .filereg_m_tvalid_o(s_filereg_if.valid),
  .filereg_m_tready_i(s_filereg_if.ready),
  .filereg_m_tdata_o (s_filereg_if.data),
  .filereg_m_tlast_o (s_filereg_if.last),

  .s_axis_tvalid_i(m_axis_tvalid),
  .s_axis_tready_o(m_axis_tready),
  .s_axis_tdata_i (m_axis_tdata),
  .s_axis_tlast_i (m_axis_tlast),
  .s_axis_tid_i   (m_axis_tid),
  .s_axis_tdest_i (m_axis_tdest),

  .m_axis_tvalid_o(s_axis_tvalid),
  .m_axis_tready_i(s_axis_tready),
  .m_axis_tdata_o (s_axis_tdata),
  .m_axis_tlast_o (s_axis_tlast),
  .m_axis_tid_o   (s_axis_tid),
  .m_axis_tdest_o (s_axis_tdest),
 
  .network_valid_o             (network_valid[NI2ROUTER]),
  .network_ready_i             (network_virtual_channel_ready),
  .network_flit_o              (network_flit[NI2ROUTER]),
  .network_flit_type_o         (network_flit_type[NI2ROUTER]),
  .network_broadcast_o         (network_broadcast[NI2ROUTER]),
  .network_virtual_channel_id_o(network_virtual_channel_id),
  .network_valid_i             (network_valid[ROUTER2NI]),
  .network_ready_o             (network_virtual_network_ready),
  .network_flit_i              (network_flit[ROUTER2NI]),
  .network_flit_type_i         (network_flit_type[ROUTER2NI]), 
  .network_broadcast_i         (network_broadcast[ROUTER2NI]),
  .network_virtual_network_id_i(network_virtual_network_id)    
);

// 2D-mesh Switch
// TODO change for 3D-mesh
SWITCH_VC #(
  .ID(NetworkSwitchAddressId),

  .GLBL_DIMX       (MeshTopologyDimensionX),
  .GLBL_DIMY       (MeshTopologyDimensionY),
  .GLBL_N_NxT      (1), // Not used
  .GLBL_N_Nodes    (0), // Not used
  .GLBL_DIMX_w     (MeshTopologyDimensionXWidth),
  .GLBL_DIMY_w     (MeshTopologyDimensionYWidth),
  .GLBL_N_NxT_w    (1), // Not used
  .GLBL_N_Nodes_w  (1), // Not used 
  .GLBL_SWITCH_ID_w(NetworkSwitchAddressIdWidth),

  .NUM_VN(NetworkIfNumberOfVirtualNetworks),
  .NUM_VC(1),

  .FLIT_TYPE_SIZE(NetworkIfFlitTypeWidth),
  .BROADCAST_SIZE(1),
  .FLIT_SIZE     (NetworkIfFlitWidth),
  .PHIT_SIZE_L   (NetworkIfFlitWidth),
  .PHIT_SIZE_N   (NetworkIfFlitWidth),
  .PHIT_SIZE_E   (NetworkIfFlitWidth),
  .PHIT_SIZE_W   (NetworkIfFlitWidth),
  .PHIT_SIZE_S   (NetworkIfFlitWidth),

  .IB_QUEUE_SIZE    (8),
  .IB_SG_UPPER_THOLD(5),
  .IB_SG_LOWER_THOLD(4),

  .DATA_NET_FLIT_DST_UNIT_ID_MSB(63),
  .DATA_NET_FLIT_DST_UNIT_ID_LSB(53),
  
  .ENABLE_VN_WEIGHTS_SUPPORT("no"),
  .VN_WEIGHT_VECTOR_w       (20) 
) router_inst (
  .clk  (clk_network_i),
  .rst_p(rst_network_i),

  .WeightsVector_in(20'b0), // TODO

  .FlitFromE (switch_data[IN][EAST][`SWITCH_FLIT_RANGE]),
  .FlitFromN (switch_data[IN][NORTH][`SWITCH_FLIT_RANGE]),
  .FlitFromNI(network_flit[NI2ROUTER]),
  .FlitFromS (switch_data[IN][SOUTH][`SWITCH_FLIT_RANGE]),
  .FlitFromW (switch_data[IN][WEST][`SWITCH_FLIT_RANGE]),

  .FlitTypeFromE (switch_data[IN][EAST][`SWITCH_FLIT_TYPE_RANGE]),
  .FlitTypeFromN (switch_data[IN][NORTH][`SWITCH_FLIT_TYPE_RANGE]),
  .FlitTypeFromNI(network_flit_type[NI2ROUTER]),
  .FlitTypeFromS (switch_data[IN][SOUTH][`SWITCH_FLIT_TYPE_RANGE]),
  .FlitTypeFromW (switch_data[IN][WEST][`SWITCH_FLIT_TYPE_RANGE]),

  .BroadcastFlitFromE (switch_data[IN][EAST][`SWITCH_BROADCAST_RANGE]),
  .BroadcastFlitFromN (switch_data[IN][NORTH][`SWITCH_BROADCAST_RANGE]),
  .BroadcastFlitFromNI(network_broadcast[NI2ROUTER]),
  .BroadcastFlitFromS (switch_data[IN][SOUTH][`SWITCH_BROADCAST_RANGE]),
  .BroadcastFlitFromW (switch_data[IN][WEST][`SWITCH_BROADCAST_RANGE]),

  .VC_FromE (switch_data[IN][EAST][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),
  .VC_FromN (switch_data[IN][NORTH][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),
  .VC_FromNI(network_virtual_channel_id),
  .VC_FromS (switch_data[IN][SOUTH][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),
  .VC_FromW (switch_data[IN][WEST][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),

  .GoBitFromE (switch_go[IN][EAST]),
  .GoBitFromN (switch_go[IN][NORTH]),
  .GoBitFromNI(network_virtual_network_ready),
  .GoBitFromS (switch_go[IN][SOUTH]),
  .GoBitFromW (switch_go[IN][WEST]),

  .ValidBitFromE (switch_valid[IN][EAST]),
  .ValidBitFromN (switch_valid[IN][NORTH]),
  .ValidBitFromNI(network_valid[NI2ROUTER]),
  .ValidBitFromS (switch_valid[IN][SOUTH]),
  .ValidBitFromW (switch_valid[IN][WEST]),

  .FlitToE (switch_data[OUT][EAST][`SWITCH_FLIT_RANGE]),
  .FlitToN (switch_data[OUT][NORTH][`SWITCH_FLIT_RANGE]),
  .FlitToNI(network_flit[ROUTER2NI]),
  .FlitToS (switch_data[OUT][SOUTH][`SWITCH_FLIT_RANGE]),
  .FlitToW (switch_data[OUT][WEST][`SWITCH_FLIT_RANGE]),

  .FlitTypeToE (switch_data[OUT][EAST][`SWITCH_FLIT_TYPE_RANGE]),
  .FlitTypeToN (switch_data[OUT][NORTH][`SWITCH_FLIT_TYPE_RANGE]),
  .FlitTypeToNI(network_flit_type[ROUTER2NI]),
  .FlitTypeToS (switch_data[OUT][SOUTH][`SWITCH_FLIT_TYPE_RANGE]),
  .FlitTypeToW (switch_data[OUT][WEST][`SWITCH_FLIT_TYPE_RANGE]),

  .BroadcastFlitToE (switch_data[OUT][EAST][`SWITCH_BROADCAST_RANGE]),
  .BroadcastFlitToN (switch_data[OUT][NORTH][`SWITCH_BROADCAST_RANGE]),
  .BroadcastFlitToNI(network_broadcast[ROUTER2NI]),
  .BroadcastFlitToS (switch_data[OUT][SOUTH][`SWITCH_BROADCAST_RANGE]),
  .BroadcastFlitToW (switch_data[OUT][WEST][`SWITCH_BROADCAST_RANGE]),

  .VC_ToE (switch_data[OUT][EAST][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),
  .VC_ToN (switch_data[OUT][NORTH][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),
  .VN_ToNI(network_virtual_network_id),
  .VC_ToS (switch_data[OUT][SOUTH][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),
  .VC_ToW (switch_data[OUT][WEST][`SWITCH_VIRTUAL_CHANNEL_ID_RANGE]),
  
  .GoBitToE (switch_go[OUT][EAST]),
  .GoBitToN (switch_go[OUT][NORTH]),
  .GoBitToNI(network_virtual_channel_ready),
  .GoBitToS (switch_go[OUT][SOUTH]),
  .GoBitToW (switch_go[OUT][WEST]),

  .ValidBitToE (switch_valid[OUT][EAST]),
  .ValidBitToN (switch_valid[OUT][NORTH]),
  .ValidBitToNI(network_valid[ROUTER2NI]),
  .ValidBitToS (switch_valid[OUT][SOUTH]),
  .ValidBitToW (switch_valid[OUT][WEST]),
  
  // Configuration and monitoring file register access interface
  // filereg_m is filereg_s and filereg_s is filereg_m actually
  .filereg_m_tvalid_i(s_filereg_if.valid),
  .filereg_m_tdata_i (s_filereg_if.data),
  .filereg_m_tlast_i (s_filereg_if.last),
  .filereg_m_tready_o(s_filereg_if.ready),
  //
  .filereg_s_tready_i(m_filereg_if.ready),
  .filereg_s_tvalid_o(m_filereg_if.valid),
  .filereg_s_tdata_o (m_filereg_if.data),
  .filereg_s_tlast_o (m_filereg_if.last)
);

//// Connect the input/output ports of the tile with the Switch (Router)
generate
  localparam integer OFFSETOF_SOUTH_PORT = get_2dmesh_switch_port(NetworkSwitchAddressId, 
      SOUTH, MeshTopologyDimensionX, MeshTopologyDimensionY);
  localparam integer OFFSETOF_WEST_PORT  = get_2dmesh_switch_port(NetworkSwitchAddressId, 
      WEST,  MeshTopologyDimensionX, MeshTopologyDimensionY);
  localparam integer OFFSETOF_EAST_PORT  = get_2dmesh_switch_port(NetworkSwitchAddressId,
      EAST,  MeshTopologyDimensionX, MeshTopologyDimensionY);
  localparam integer OFFSETOF_NORTH_PORT = get_2dmesh_switch_port(NetworkSwitchAddressId,
      NORTH, MeshTopologyDimensionX, MeshTopologyDimensionY);

  `define TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_PORT, ORIGINAL_PORT) \
    assign network_valid_o[OFFSETOF_PORT]  = switch_valid[OUT][ORIGINAL_PORT]; \
    assign network_go_o[OFFSETOF_PORT*NetworkIfNumberOfVirtualChannels +: NetworkIfNumberOfVirtualChannels] \
                                           = switch_go[OUT][ORIGINAL_PORT]; \
    assign network_data_o[OFFSETOF_PORT*NetworkIfDataWidth +: NetworkIfDataWidth] \
                                           = switch_data[OUT][ORIGINAL_PORT]; \
    assign switch_valid[IN][ORIGINAL_PORT] = network_valid_i[OFFSETOF_PORT]; \
    assign switch_go[IN][ORIGINAL_PORT]    = network_go_i[OFFSETOF_PORT*NetworkIfNumberOfVirtualChannels +: NetworkIfNumberOfVirtualChannels]; \
    assign switch_data[IN][ORIGINAL_PORT]  = network_data_i[OFFSETOF_PORT*NetworkIfDataWidth +: NetworkIfDataWidth];

  if (NetworkSwitchAddressId < MeshTopologyDimensionX) begin : first_row
    if (NetworkSwitchAddressId == 0) begin : first
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_EAST_PORT, EAST)    
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_SOUTH_PORT, SOUTH)
    end else if (NetworkSwitchAddressId == MeshTopologyDimensionX - 1) begin : last
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_WEST_PORT, WEST)    
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_SOUTH_PORT, SOUTH)
    end else begin : middle
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_EAST_PORT, EAST)
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_WEST_PORT, WEST)         
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_SOUTH_PORT, SOUTH)
    end
  end else if (NetworkSwitchAddressId / MeshTopologyDimensionX == MeshTopologyDimensionY - 1) begin : last_row
    if (NetworkSwitchAddressId % MeshTopologyDimensionX == 0) begin : fisrt
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_NORTH_PORT, NORTH)
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_EAST_PORT, EAST)    
    end else if (NetworkSwitchAddressId == MeshTopologyDimensionX * MeshTopologyDimensionY - 1) begin : last
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_NORTH_PORT, NORTH)
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_WEST_PORT, WEST)      
    end else begin : middle
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_NORTH_PORT, NORTH)
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_EAST_PORT, EAST)      
      `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_WEST_PORT, WEST)      
    end
  end else if (NetworkSwitchAddressId % MeshTopologyDimensionX == 0) begin : first_column
    // but no corner cases, they are treated as part of first and last row
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_NORTH_PORT, NORTH)
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_EAST_PORT, EAST)       
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_SOUTH_PORT, SOUTH)
  end else if (NetworkSwitchAddressId % MeshTopologyDimensionX == MeshTopologyDimensionX - 1) begin : last_column
    // but no corner cases, they are treated as part of first and last row
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_NORTH_PORT, NORTH)
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_WEST_PORT, WEST)       
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_SOUTH_PORT, SOUTH)  
  end else begin : middle_rows_and_columns
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_NORTH_PORT, NORTH)
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_EAST_PORT, EAST)    
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_WEST_PORT, WEST)       
    `TILE_CONNECT_MODULE_PORTS_AND_SWITCH_PORTS(OFFSETOF_SOUTH_PORT, SOUTH)  
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
function integer get_2dmesh_switch_port(input integer switch_id, input integer port, input integer dimx, input integer dimy); 
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

  

