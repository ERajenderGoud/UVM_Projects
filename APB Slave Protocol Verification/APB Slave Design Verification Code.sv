interface apb_if #(parameter ADDR_WIDTH = 8,parameter DATA_WIDTH = 8,parameter WAIT_STATES = 2)(input logic PCLK);
  
  logic					 PRESETn;
  logic 				 PSEL;
  logic 				 PENABLE;
  logic                  PWRITE;
  logic [ADDR_WIDTH-1:0] PADDR;
  logic [DATA_WIDTH-1:0] PWDATA;
  
  logic [DATA_WIDTH-1:0] PRDATA;
  logic					 PREADY;
  logic					 PSLVERR;
  
  clocking drv_cb @(posedge PCLK);
    input PRDATA,PREADY,PSLVERR;
    output PSEL,PENABLE,PWRITE,PADDR,PWDATA,PRESETn;
  endclocking
  
  clocking mon_cb @(posedge PCLK);
    input PSEL,PENABLE,PWRITE,PADDR,PWDATA,PRDATA,PREADY,PSLVERR;
  endclocking
  
endinterface

class apb_txn extends uvm_sequence_item;

  logic PSEL;
  logic PENABLE;
  rand logic PWRITE;
  rand logic [ADDR_WIDTH-1:0] PADDR;
  rand logic [DATA_WIDTH-1:0] PWDATA;
  
  logic [DATA_WIDTH-1:0] PRDATA;
  logic PREADY;
  logic PSLVERR;
  
  `uvm_object_utils_begin(apb_txn)
    `uvm_field_int(PSEL,	UVM_ALL_ON)
  	`uvm_field_int(PENABLE,	UVM_ALL_ON)
  	`uvm_field_int(PWRITE,	UVM_ALL_ON)
  	`uvm_field_int(PADDR,	UVM_ALL_ON)
  	`uvm_field_int(PWDATA,	UVM_ALL_ON)
  	`uvm_field_int(PRDATA,	UVM_ALL_ON)
    `uvm_field_int(PREADY,	UVM_ALL_ON)
    `uvm_field_int(PSLVERR,	UVM_ALL_ON)
  `uvm_object_utils_end
  
  function new(string name = "apb_txn");
    super.new(name);
  endfunction

endclass

class apb_seq extends uvm_sequence #(apb_txn);
  
  `uvm_object_utils(apb_seq)
  
  function new(string name = "apb_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    
    apb_txn txn;
    
    //Valid Address Test
    repeat (20) begin
      
      txn = apb_txn::type_id::create("txn");
      `uvm_info(get_type_name(), "Task Body Called for Valid Address Test", UVM_LOW)
      start_item(txn);
      
      if (!txn.randomize() with  {PADDR inside {8'h00, 8'h04, 8'h08, 8'h0C};}) begin
        `uvm_error(get_type_name(), "Randomization Failed for valid address")
      end
      
      finish_item(txn);
      
    end
    
    //Invalid Address Test
    repeat (20) begin
      
      txn = apb_txn::type_id::create("txn");
      `uvm_info(get_type_name(), "Task Body Called for Invalid Address Test", UVM_LOW)
      start_item(txn);
      
      if (!txn.randomize() with { PADDR != 8'h00; PADDR != 8'h04; PADDR != 8'h08; PADDR != 8'h0C; }) begin
        `uvm_error(get_type_name(), "Randomization Failed for Invalid Address Test")
      end
      
      finish_item(txn);
      
    end
    
    //Normal Random Test
    repeat (50) begin
      
      txn = apb_txn::type_id::create("txn");
      `uvm_info(get_type_name(), "Task Body Called for Normal Random Test", UVM_LOW)
      start_item(txn);
      
      if (!txn.randomize()) begin
        `uvm_error(get_type_name(), "Randomization Failed for Normal Random Test")
      end
      
      finish_item(txn);
      
    end
    
  endtask
  
endclass

class apb_sequencer extends uvm_sequencer #(apb_txn);
  
  `uvm_component_utils(apb_sequencer)
  
  function new(string name = "sequencer" ,uvm_component parent);
    super.new(name,parent);
  endfunction
  
endclass

class apb_driver extends uvm_driver #(apb_txn);
  
  `uvm_component_utils(apb_driver)
  virtual apb_if vif;
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual apb_if)::get(this,"","vif",vif)) begin
      `uvm_fatal(get_type_name(),"virtual interface not set for driver") end
    
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      send_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  
  task send_to_dut (apb_txn req);
    
    //SETUP PHASE (PSEL=1, PENABLE=0)
    @(vif.drv_cb);
    vif.drv_cb.PRESETn 	<= 1;
    vif.drv_cb.PSEL 	<= 1;
    vif.drv_cb.PENABLE 	<= 0;
    vif.drv_cb.PWRITE 	<= req.PWRITE;
    vif.drv_cb.PADDR 	<= req.PADDR;
    vif.drv_cb.PWDATA 	<= req.PWDATA;
    
    //ACCESS PHASE (PSEL=1, PENABLE=1)
    @(vif.drv_cb);
    vif.drv_cb.PENABLE 	<= 1;
    
    wait(vif.drv_cb.PREADY);
    vif.drv_cb.PSEL		<= 0;
    vif.drv_cb.PENABLE 	<= 0;
    
    `uvm_info(get_type_name(),$sformatf("APB %s transfer completed: PADDR=0x%0h, DATA=0x%0h",(req.PWRITE ? "WRITE" : "READ"),req.PADDR,(req.PWRITE ? req.PWDATA : vif.drv_cb.PRDATA)),UVM_MEDIUM)
    
  endtask
  
endclass

class apb_monitor extends uvm_monitor #(apb_txn);
  
  `uvm_component_utils(apb_monitor)
  
  apb_txn txn;
  virtual apb_if vif;
  uvm_analysis_port #(apb_txn) ap;
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
    ap = new("ap",this);
  endfunction
  
  virtual function void build_phase (uvm_phase phase);
    
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual apb_if)::get(this,"","vif",vif)) begin
      `uvm_fatal(get_type_name(),"virtual interface is not set for monitor")
    end
  
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    forever begin
      get_from_dut();
    end
  endtask
  
  task get_from_dut();
    
    @(vif.mon_cb);
    if (vif.mon_cb.PSEL && vif.mon_cb.PENABLE && vif.mon_cb.PREADY) begin
      
      txn = apb_txn::type_id::create("txn");
      
      txn.PSEL    = vif.mon_cb.PSEL;
      txn.PENABLE = vif.mon_cb.PENABLE;
      txn.PREADY  = vif.mon_cb.PREADY;
      txn.PADDR   = vif.mon_cb.PADDR;
      txn.PWRITE  = vif.mon_cb.PWRITE;
      txn.PRDATA  = vif.mon_cb.PRDATA;
      txn.PSLVERR = vif.mon_cb.PSLVERR;

      if (vif.mon_cb.PWRITE) begin
        
        txn.PWDATA = vif.mon_cb.PWDATA;
        
        `uvm_info(get_type_name(), $sformatf("Captured WRITE to PADDR=0x%0h PWDATA=0x%0h ", txn.PADDR, txn.PWDATA), UVM_MEDIUM)
      
      end
      
      else begin
      
      txn.PRDATA = vif.mon_cb.PRDATA;
        `uvm_info(get_type_name(), $sformatf("Captured READ from PADDR=0x%0h PRDATA=0x%0h", txn.PADDR, txn.PRDATA), UVM_MEDIUM)
      
      end
      ap.write(txn);
    end
  endtask
  
endclass

class apb_agent extends uvm_agent;
  
  `uvm_component_utils(apb_agent)
  
  apb_sequencer sqr;
  apb_driver drv;
  apb_monitor mon;
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon",this);
    if(get_is_active() == UVM_ACTIVE) begin
      sqr = apb_sequencer::type_id::create("sqr",this);
      drv = apb_driver::type_id::create("drv",this);
    end
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
  
endclass

class apb_ref_model;

  localparam [7:0] ADDR_CTRL    = 8'h00;
  localparam [7:0] ADDR_STATUS  = 8'h04;
  localparam [7:0] ADDR_DATA    = 8'h08;
  localparam [7:0] ADDR_VERSION = 8'h0C;

  reg [7:0] ctrl_reg;
  reg [7:0] data_reg;
  reg [7:0] status_reg;

  function new();
    ctrl_reg   = 8'h00;
    data_reg   = 8'h00;
    status_reg = 8'h00;
  endfunction


  function void predict(
    input  [ADDR_WIDTH-1:0] addr,
    input        write,
    input  [DATA_WIDTH-1:0] wdata,

    output reg [DATA_WIDTH-1:0] rdata,
    output reg       slverr
  );
    
    rdata  = 8'h00;
    slverr = 1'b0;
    
    case (addr)

      ADDR_CTRL: begin

        if (write)
          ctrl_reg = wdata;
        else
          rdata = ctrl_reg;

      end


      ADDR_STATUS: begin

        if (write)
          slverr = 1'b1;
        else
          rdata = status_reg;

      end


      ADDR_DATA: begin

        if (write)
          data_reg = wdata;
        else
          rdata = data_reg;

      end


      ADDR_VERSION: begin

        if (write)
          slverr = 1'b1;
        else
          rdata = 8'h01;

      end


      default: begin

        rdata  = 8'h00;
        slverr = 1'b1;

      end

    endcase

  endfunction

endclass

class apb_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(apb_scoreboard)

  uvm_analysis_imp #(apb_txn, apb_scoreboard) imp;

  apb_ref_model ref_model;

  function new(string name, uvm_component parent);
    
    super.new(name, parent);
    imp = new("imp", this);
    ref_model = new();

  endfunction
  
  function void write(apb_txn tr);

    reg [DATA_WIDTH-1:0] expected_rdata;
    reg expected_slverr;

    ref_model.predict(tr.PADDR,tr.PWRITE,tr.PWDATA,expected_rdata,expected_slverr);

    if (!tr.PWRITE) begin
      
      if (tr.PRDATA !== expected_rdata) begin
        `uvm_error(get_type_name(),$sformatf("PRDATA Mismatch: Actual=%h Expected=%h",tr.PRDATA, expected_rdata)) end
      else begin
        `uvm_info(get_type_name(),$sformatf("PRDATA Match: Actual=%h Expected=%h",tr.PRDATA, expected_rdata),UVM_NONE) end
      
    end
    
    if (tr.PSLVERR !== expected_slverr) begin
      `uvm_error(get_type_name(),$sformatf("PSLVERR Mismatch: Actual=%b Expected=%b",tr.PSLVERR, expected_slverr)) end
    else begin
      `uvm_info(get_type_name(),$sformatf("PSLVERR Match: Actual=%b Expected=%b \n",tr.PSLVERR, expected_slverr),UVM_NONE) end
    

  endfunction

endclass

class apb_env extends uvm_env;
  
  `uvm_component_utils(apb_env)
  
  apb_agent agent;
  apb_scoreboard scb;
  apb_coverage cov;
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = apb_agent::type_id::create("agent",this);
    scb = apb_scoreboard::type_id::create("scb",this);
    cov = apb_coverage::type_id::create("cov",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scb.imp);
    agent.mon.ap.connect(cov.analysis_export);
  endfunction
  
endclass

class apb_coverage extends uvm_subscriber #(apb_txn);
  
  `uvm_component_utils(apb_coverage)

  apb_txn txn;

  covergroup cg;
    
    cp_PWRITE: coverpoint txn.PWRITE { bins write = {1};
                                      bins read  = {0};
                                     }

    cp_PSLVERR: coverpoint txn.PSLVERR { bins error    = {1};
                                        bins no_error = {0};
                                       }

    cp_PADDR: coverpoint txn.PADDR { bins CTRL    = {8'h00};
                                    bins STATUS  = {8'h04};
                                    bins DATA    = {8'h08};
                                    bins VERSION = {8'h0C};
                                   }
    
    cp_PRDATA: coverpoint txn.PRDATA { bins ZERO  = {8'h00};
                                      bins ONE   = {8'h01};
                                     }
    
    addr_rw : cross cp_PADDR, cp_PWRITE;
    rw_err : cross cp_PWRITE, cp_PSLVERR;    
    
    addr_err : cross cp_PADDR, cp_PSLVERR { 
      ignore_bins ctrl_error = binsof(cp_PADDR.CTRL) && binsof(cp_PSLVERR.error); 
      ignore_bins data_error = binsof(cp_PADDR.DATA) && binsof(cp_PSLVERR.error); 
    }
  
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  virtual function void write(apb_txn tr);
    txn = tr;
    cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), $sformatf("Overall Coverage			  : %.2f%% \n", cg.get_coverage()), UVM_LOW)
    
    `uvm_info(get_type_name(), $sformatf("cp_PWRITE coverage		  : %.2f%%", cg.cp_PWRITE.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("cp_PSLVERR coverage		  : %.2f%%", cg.cp_PSLVERR.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("cp_PADDR coverage			  : %.2f%%", cg.cp_PADDR.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("cp_PRDATA coverage		  : %.2f%%", cg.cp_PRDATA.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("cross addr_rw	coverage	: %.2f%%", cg.addr_rw.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("cross rw_err coverage		: %.2f%%", cg.rw_err.get_coverage()), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("cross addr_err coverage	: %.2f%%", cg.addr_err.get_coverage()), UVM_LOW)
  endfunction

endclass

module apb_assertions #(parameter ADDR_WIDTH = 8,parameter DATA_WIDTH = 8,parameter WAIT_STATES = 2)(
  input logic                  PCLK,
  input logic                  PRESETn,
  
  input logic                  PSEL,
  input logic                  PENABLE,
  input logic				   PWRITE,
  input logic [ADDR_WIDTH-1:0] PADDR,
  input logic [DATA_WIDTH-1:0] PWDATA,
  
  input logic [DATA_WIDTH-1:0] PRDATA,
  input logic                  PREADY,
  input logic                  PSLVERR 
);
  
  //when SETUP |=> (next stage) ACCESS
  property p1;
    @(posedge PCLK) 
    disable iff (!PRESETn)
    (PSEL && !PENABLE) |=> (PSEL && PENABLE);
  endproperty
  
  a1:assert property(p1)
    else 
      $error("APB ASSERTION FAILED: SETUP not followed by ACCESS");
    
  
  //When PENABLE |-> PSEL;
  property p2;
    @(posedge PCLK)
    disable iff (!PRESETn)
    PENABLE |-> PSEL;
  endproperty
    
  a2: assert property(p2)
    else 
      $error("APB ASSERTION FAILED: PENABLE asserted without PSEL");
      
  //When PREADY |-> (PSEL && PENABLE)
  property p3;
    @(posedge PCLK) 
    disable iff (!PRESETn)
    PREADY |-> (PSEL && PENABLE);
  endproperty
    
  a3: assert property(p3)
    else 
      $error("APB ASSERTION FAILED: PREADY asserted outside ACCESS phase");
    
  //When PSLVERR |-> PREADY;
  property p4;
    @(posedge PCLK) 
    disable iff (!PRESETn)
    PSLVERR |-> PREADY;
  endproperty

  a4: assert property(p4)
    else 
      $error("APB ASSERTION FAILED: PSLVERR asserted without PREADY");

  //When STATUS write must generate error
  property p5;
    @(posedge PCLK) 
    disable iff (!PRESETn)
    (PSEL && PENABLE && PREADY && PWRITE && PADDR == 8'h04) |-> PSLVERR;
  endproperty

  a5:assert property(p5)
    else 
      $error("APB ASSERTION FAILED: STATUS write did not generate PSLVERR");
    
  //When VERSION read must return 1
  property p6;
    @(posedge PCLK) 
    disable iff (!PRESETn)
    (PSEL && PENABLE && PREADY && !PWRITE && PADDR == 8'h0C) |-> (PRDATA == 8'h01);
  endproperty

  a6:assert property(p6)
    else 
      $error("APB ASSERTION FAILED: VERSION read incorrect");
    
endmodule

class apb_test extends uvm_test;
  
  `uvm_component_utils(apb_test)
  
  apb_env env;
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_env::type_id::create("env",this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    apb_seq seq = apb_seq::type_id::create("seq");
    super.run_phase(phase);
    
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    phase.drop_objection(this);
  endtask
  
endclass




package apb_pkg;

  parameter int ADDR_WIDTH = 8;
  parameter int DATA_WIDTH = 8;
  parameter WAIT_STATES = 2;

endpackage

`include "uvm_macros.svh"
import uvm_pkg::*;
import apb_pkg::*;
  
`include "interface.sv"
`include "transaction.sv"
`include "sequence.sv"
`include "sequencer.sv"
`include "driver.sv"
`include "monitor.sv"
`include "agent.sv"
`include "ref.sv"
`include "scoreboard.sv"
`include "coverage.sv"
`include "environment.sv"
`include "assertion.sv"
`include "test.sv"

module tb;
  
  logic PCLK;
  
  apb_if aif(PCLK);
  
  apb_slave dut(.PCLK(PCLK),.PRESETn(aif.PRESETn),.PSEL(aif.PSEL),.PENABLE(aif.PENABLE),.PWRITE(aif.PWRITE),.PADDR(aif.PADDR),.PWDATA(aif.PWDATA),.PRDATA(aif.PRDATA),.PREADY(aif.PREADY),.PSLVERR(aif.PSLVERR));
  
  apb_assertions a_dut (.PCLK(PCLK),.PRESETn(aif.PRESETn),.PSEL(aif.PSEL),.PENABLE(aif.PENABLE),.PWRITE(aif.PWRITE),.PADDR(aif.PADDR),.PWDATA(aif.PWDATA),.PRDATA(aif.PRDATA),.PREADY(aif.PREADY),.PSLVERR(aif.PSLVERR));
  
  initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK;
  end
  
  initial begin
    uvm_config_db #(virtual apb_if)::set(null,"*","vif",aif);
  end
  
  initial begin
    aif.PRESETn = 0;
    
    aif.PSEL    = 0;
    aif.PENABLE = 0;
    aif.PWRITE  = 0;
    aif.PADDR   = 0;
    aif.PWDATA  = 0;
    
    @(posedge aif.PCLK);
    aif.PRESETn = 1;
  
  end
  
  initial begin
    run_test("apb_test");
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
  
endmodule
