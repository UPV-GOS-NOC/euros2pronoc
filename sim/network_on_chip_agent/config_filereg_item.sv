// SPDX-FileCopyrightText: (c) 2024  Parallel Architectures Group (GAP) <carherlu@upv.edu.es>
// SPDX-License-Identifier: MIT
//
//
// @file config_filereg_item.sv 
// @author Rafael Tornero (ratorga@disca.upv.es)
// @date July 23th, 2024
//
// @title Configuration FileReg transaction item
//
// A FileReg transaction is composed of the following members:
// - Module Address
// - Command
// - Register Address
// - Value or Payload
//
// Using these members a data message compatible with the
// filereg interface can be build as follows:
//   {command, Register Address, Value}

class config_filereg_item #(
  int ModuleAddressSize = 0,

  int CommandFieldSize         = 0,
  int RegisterAddressFieldSize = 0,
  int PayloadFieldSize         = 0,

  int NumberOfModules    = 0,
  int NumberOfRegisters  = 0,
  int NumberOfCommands   = 0,

  // Size of the message composed of the concatenation
  // of some member fields
  int MessageSize = 0
);

  `define CONFIG_FILE_REG_ITEM_INSTANCE_PARAM #(.ModuleAddressSize(ModuleAddressSize), .CommandFieldSize(CommandFieldSize), .RegisterAddressFieldSize(RegisterAddressFieldSize), .PayloadFieldSize(PayloadFieldSize), .NumberOfModules(NumberOfModules), .NumberOfRegisters(NumberOfRegisters), .NumberOfCommands(NumberOfCommands), .MessageSize(MessageSize)) 
 
  rand bit valid;
  rand bit ready;
  
  // Stores the destination of the transaction
  rand bit [ModuleAddressSize-1:0] module_address;

  rand  bit [CommandFieldSize-1:0]         command;
  randc bit [RegisterAddressFieldSize-1:0] register_address;
  rand  bit [PayloadFieldSize-1:0]         value;

  function new(input bit [ModuleAddressSize-1:0] module_address = 0,
               input bit [CommandFieldSize-1:0] command = 0, 
               input bit [RegisterAddressFieldSize-1:0] register_address = 0, 
               input bit [PayloadFieldSize-1:0] value  = 0);
    this.module_address = module_address;
    this.command = command;
    this.register_address = register_address;
    this.value   = value;
    this.valid = 0;
    this.ready = 0;
  endfunction

  function void display(string str = "");
    $display("[T=%0t] %s config_filereg_item --> %0s",
             $time, str, toString());
  endfunction

  function string toString();
    string str;
    $sformat(str, "valid=%b, ready=%b, destination=%0d, command=%0x, address=%0x, value=%0x", 
      valid, ready, module_address, command, register_address, value);
    return str;
  endfunction

  function int compare(ref config_filereg_item `CONFIG_FILE_REG_ITEM_INSTANCE_PARAM item);
    if ((this.module_address == item.get_destination()) &&
      (this.command == item.get_command()) &&
      (this.register_address == item.get_register_address()) &&
      (this.value == item.get_value())) begin
      return 0;
    end

    return 1;
  endfunction
  
  function int compare_response(ref config_filereg_item `CONFIG_FILE_REG_ITEM_INSTANCE_PARAM item);
    if (this.value == item.get_value()) begin
      return 0;
    end

    return 1;
  endfunction  

  function bit[ModuleAddressSize-1:0] get_destination();
    return module_address;
  endfunction

  function bit [CommandFieldSize-1:0] get_command();
    return command;
  endfunction

  function bit [RegisterAddressFieldSize-1:0] get_register_address();
    return register_address;
  endfunction

  function bit [PayloadFieldSize-1:0] get_value();
    return value;
  endfunction

  function bit [MessageSize-1:0] get_message();
    return {command, register_address, value};
  endfunction

  function void set_message(input bit [MessageSize-1:0] message);
    this.command = message[(PayloadFieldSize + RegisterAddressFieldSize) +: CommandFieldSize];
    this.register_address = message[PayloadFieldSize +: RegisterAddressFieldSize];
    this.value   = message[PayloadFieldSize-1:0];
  endfunction
  
  function void set_response_message(input bit [MessageSize-1:0] message);
    // Do not take into account VRFC 10-3705 Warning, since this method must be
    // used only for response_config_filereg_t
    this.module_address = message[PayloadFieldSize +: ModuleAddressSize];
    this.value   = message[PayloadFieldSize-1:0];
    this.command = 0;
    this.register_address = 0;
  endfunction  

  function bit [31:0] get_message_word(input int numberof_word);
    bit [MessageSize-1:0] message = 0;
    bit [63:0] extended_message = 0;

    message = this.get_message();
    extended_message = {{(64-MessageSize){1'b0}}, message};

    if (numberof_word < 2) begin
      return extended_message[numberof_word*32 +: 32];
    end else begin
      return extended_message[31:0];
    end
  endfunction
  
  function void get_data_message_word(input int numberof_word, inout logic [7:0] data[3:0]);
    bit [31:0] message = this.get_message_word(numberof_word);
        
    for (int i = 0; i < 4; i++) begin
      data[i] = message[i*8 +: 8];
    end
  endfunction

  constraint command_write_c { 
    command == 1; 
  }

  constraint register_address_high_limit_c {
    register_address < NumberOfRegisters;
  }

  constraint register_address_low_limit_c {
    register_address > 0;
  }

  constraint module_address_highlimit_c {
    module_address < NumberOfModules;
  }
  
  constraint module_address_low_limit_c {
    module_address > 0;
  }

endclass
