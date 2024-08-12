# Vivado Folder

This folder contains Xilinx IP, source code, scripts an other files
that depend on Xilinx Vivado and (probably) the
Vivado version that was used for generating some of the files found in this directory.

The folder is structured per Vivado Version.

Foreach Vivado version, the user can find the next folders:

- scripts
- ip
- sim (optional)
- rtl (optional)

Although other scripts could be hosted in the script folder,
it normally contains a TCL file for generating
a Vivado project configured with a simulation environment to verify
a feature or provide an example for a specific design.

The ip folder contains IP files used for a particular Vivado project.

In sim and rtl, the user can find Vivado dependent source files. These files include
Vivado specific primitives that they do not make sense for other third vendor EDA tools.
Files in this location are imported to the local folders of the XPR project generated with the TCL
generate_vivado_project_xxx.tcl file found in scripts directory.

Notice that anychange carried out with the Vivado IDE to the files held in
sim and rtl directories will not be reflected
in the original repository file, as they are imported to the local folders of the XPR project.

Nevertheless, the files in sim and rtl directories should not be modified unless some bug in them
are found.

