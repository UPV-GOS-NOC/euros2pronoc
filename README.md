# osNoC: Open-Source Network-on-Chip

This is the main repository of the on-chip interconnect solution developed
by some members of the Group of Parallel Architectures (GAP) of the Universitat
Politecnica de Valencia (UPV).

The NoC has been designed to be integrated as a set of modules embedded
and distributed over a 2D mesh tile-based logical design architecture.
The size of the 2D mesh can be configured at design time.

In this architecture, all the communication among tiles is carried out through the network.
A tile is an abstraction entity that encapsulates one or more IPs of a SoC
and provides a common access interface to them.
The main components of every tile are the on-chip network switch, the Network Interface (NI),
and a placeholder (a.k.a. UNIT), which is used to implement the
desired Intellectual Property (IP) or Processing Element (PE).

Next, the main features supported currently in the NoC are summarized as follows:
- Scalable on-chip architecture.
- Support for virtual Networks and virtual channels.
- Deadlock guaranteed by hardware.
- Flow control to prevent data looses.
- Broadcast and point-to-point communication primitives.
- Traffic isolation.
- Quality of Service.
- High throughput with 5-stage pipeline router.

# Quick Start

```
$ cd /home/<user>/
$ git clone ... osNoC.git
$ mkdir /home/<user>/vivado
$ cd /home/<user>/vivado
$ /path/to/vivado/vivado
```
In the TCL console of the Vivado IDE:

```
> set argv [list --repo_dir /home/<user>/osNoC]
> set argc 2
> source /home/<user>/osNoC/vivado/2022.2/scripts/generate_vivado_project_for_network_onc_chip_testbench.tcl
```

The script will generate a Vivado project configured with a Design Under Verification (DUV)
top that builds a system composed of eight tiles arranged in a 4x2 mesh topology. Each tile
contains an AXI-Stream Manager Verification IP Core (M\_AXIS\_VIP), an AXI-Stream Subordinate
Verification IP Core (S\_AXIS\_VIP), a Single Unit Network Interface (SUNI) and a on-chip network switch.

This design serves two purposes. First, to enable the verification for the NoC and, second, provide
a design example to facilitate the creation of other designs.

To facilitate the verification, the project is also configured with a full SystemVerilog simulation environment
based-on SystemVerilog Verification approach. See [NoC Verification Environment](sim/network_on_chip/README.md) for more information.

It is recommend to run this script outside the repository folder to avoid the creation of the Vivado
project folder structure in the working tree directory of the repo.

# LICENSE

The osNoC project is available under the conditions of the MIT license.

