// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class usb20_seq extends usb20_base_seq;
   `uvm_object_utils(usb20_seq)
  
   `uvm_object_new

    usb20_item bp;
	  token_pkt tp;
	  data_pkt dp;
	  handshake_pkt hp; 


  virtual task body();
     `uvm_info(`gfn, $sformatf("starting usb20 seq"), UVM_HIGH)
     $display (" Test_Point1 "); 
   
     tp = token_pkt::type_id::create("tp"); 
		 assert(tp.randomize());
     bp = tp;
     start_item(tp);
     finish_item(tp);
  endtask


endclass
