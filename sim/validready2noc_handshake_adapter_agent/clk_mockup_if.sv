// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file clk_mockup_if.sv
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date Feb 05th, 2024
//
// @title Clk mockup interface
//
// For DUVs that do not have a clock, let us create a mock clock
// used in the testbench to synchronize when values are driven and when
// values are sampled. Typically combinational logic is used between
// sequential elements like FF in a real circuit. So, let us assume
// that inputs to the DUV is provided at some posedge clock. But because
// the design does not have clock in its input, we will keep this clock
// in a separate interface that is available only to testbench components
interface clk_mockup_if(input clk, rst);

endinterface
