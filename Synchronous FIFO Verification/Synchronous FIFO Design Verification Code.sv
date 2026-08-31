interface fifo_if #(parameter DATA_WIDTH = 8,parameter DEPTH = 16)(input logic clk);
  
  logic					 reset;
  logic 				 wr_en;
  logic 				 rd_en;
  logic [DATA_WIDTH-1:0] wr_data;
  logic [DATA_WIDTH-1:0] rd_data;
  logic					 full;
  logic					 empty;
  
  clocking drv_cb @(posedge clk);
    input rd_data,full,empty;
    output wr_en,rd_en,wr_data,reset;
  endclocking
  
  clocking mon_cb @(posedge clk);
    input wr_en,rd_en,wr_data,rd_data,full,empty,reset;
  endclocking
  
endinterface

class fifo_txn extends uvm_sequence_item;
  
  bit reset;
  rand logic wr_en;
  rand logic rd_en;
  rand logic [DATA_WIDTH-1:0] wr_data;
  
  logic [DATA_WIDTH-1:0] rd_data;
  logic full;
  logic empty;
  
  `uvm_object_utils_begin(fifo_txn)
    `uvm_field_int(reset,   UVM_ALL_ON)
  	`uvm_field_int(wr_en,   UVM_ALL_ON)
  	`uvm_field_int(rd_en,   UVM_ALL_ON)
  	`uvm_field_int(wr_data, UVM_ALL_ON)
  	`uvm_field_int(rd_data, UVM_ALL_ON)
  	`uvm_field_int(full,    UVM_ALL_ON)
  	`uvm_field_int(empty,   UVM_ALL_ON)
  `uvm_object_utils_end
  
  function new(string name = "fifo_txn");
    super.new(name);
  endfunction

endclass

class fifo_seq extends uvm_sequence #(fifo_txn);
  
  `uvm_object_utils(fifo_seq)
  
  function new(string name = "fifo_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    
    fifo_txn txn;
    
    //force wr_en
    repeat (20) begin
      txn = fifo_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with { wr_en == 1; rd_en == 0; }) begin
        `uvm_error(get_type_name(), "Randomization Failed")
      end
      finish_item(txn);
    end
    
    //reset
    txn = fifo_txn::type_id::create("txn");
    start_item(txn);
    txn.reset = 1; txn.wr_en = 0; txn.rd_en = 0;
    finish_item(txn);

    //release reset
    txn = fifo_txn::type_id::create("txn");
    start_item(txn);
    txn.reset = 0; txn.wr_en = 0; txn.rd_en = 0;
    finish_item(txn);

    //force read
    repeat (20) begin
      txn = fifo_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize() with { wr_en == 0; rd_en == 1; }) begin
        `uvm_error(get_type_name(), "Randomization Failed")
      end
      finish_item(txn);
    end

    //normal randomization
    repeat (30) begin
      txn = fifo_txn::type_id::create("txn");
      start_item(txn);
      if (!txn.randomize()) begin
        `uvm_error(get_type_name(), "Randomization Failed")
      end
      finish_item(txn);
    end
  endtask
  
endclass

class fifo_sequencer extends uvm_sequencer #(fifo_txn);
  
  `uvm_component_utils(fifo_sequencer)
  
  function new(string name = "sequencer" ,uvm_component parent);
    super.new(name,parent);
  endfunction
  
endclass

class fifo_driver extends uvm_driver #(fifo_txn);
  
  `uvm_component_utils(fifo_driver)
  virtual fifo_if vif;
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual fifo_if)::get(this,"","vif",vif)) begin
      `uvm_fatal(get_type_name(),"virtual interface not set for driver") end
    
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    @(negedge vif.clk);
    
    forever begin
      seq_item_port.get_next_item(req);
      @(negedge vif.clk);
      
      vif.reset   <= req.reset;
      vif.wr_en   <= req.wr_en & !vif.full;
      vif.rd_en   <= req.rd_en & !vif.empty;
      vif.wr_data <= (req.wr_en & !vif.full) ? req.wr_data : '0;
      
      seq_item_port.item_done();
    
    end
  endtask
  
endclass

class fifo_monitor extends uvm_monitor #(fifo_txn);
  
  `uvm_component_utils(fifo_monitor)
  
  virtual fifo_if vif;
  uvm_analysis_port #(fifo_txn) ap;
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
    ap = new("ap",this);
  endfunction
  
  virtual function void build_phase (uvm_phase phase);
    
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual fifo_if)::get(this,"","vif",vif)) begin
      `uvm_fatal(get_type_name(),"virtual interface is not set for monitor")
    end
  
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    fifo_txn txn;
    super.run_phase(phase);
    
    forever begin
      
      @(vif.mon_cb);
      txn = fifo_txn::type_id::create("txn");
      
      txn.reset = vif.mon_cb.reset;
      txn.wr_en = vif.mon_cb.wr_en;
      txn.rd_en = vif.mon_cb.rd_en;
      txn.wr_data = vif.mon_cb.wr_data;
      
      txn.rd_data = vif.mon_cb.rd_data;
      txn.full = vif.mon_cb.full;
      txn.empty = vif.mon_cb.empty;
      
      ap.write(txn);
      
      `uvm_info(get_type_name(),$sformatf("reset=%0d | wr_en=%0d rd_en=%0d | wr_data=%0d rd_data=%0d | full=%0d empty=%0d \n",txn.reset,txn.wr_en,txn.rd_en,txn.wr_data,txn.rd_data,txn.full,txn.empty),UVM_NONE)
    
    end
  endtask
  
endclass

class fifo_agent extends uvm_agent;
  
  `uvm_component_utils(fifo_agent)
  
  fifo_sequencer sqr;
  fifo_driver drv;
  fifo_monitor mon;
  
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = fifo_monitor::type_id::create("mon",this);
    if(get_is_active() == UVM_ACTIVE) begin
      sqr = fifo_sequencer::type_id::create("sqr",this);
      drv = fifo_driver::type_id::create("drv",this);
    end
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
  
endclass

class fifo_ref_model;

  bit [DATA_WIDTH-1:0] mem_queue[$];

  bit [DATA_WIDTH-1:0] expected_data;
  bit expected_full;
  bit expected_empty;

  function new();

    mem_queue.delete();

    expected_data  = '0;
    expected_full  = '0;
    expected_empty = '1;

  endfunction


  function void update(fifo_txn txn);

    if (txn.reset) begin

      mem_queue.delete();

      expected_data  = '0;
      expected_full  = '0;
      expected_empty = '1;

      return;

    end


    // WRITE
    if (txn.wr_en && !expected_full) begin
      mem_queue.push_back(txn.wr_data);
    end


    // READ
    if (txn.rd_en && !expected_empty) begin
      expected_data = mem_queue.pop_front();
    end


    // Update status
    expected_empty = (mem_queue.size() == 0);
    expected_full  = (mem_queue.size() == DEPTH);

  endfunction

endclass

class fifo_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(fifo_scoreboard)

  uvm_analysis_imp #(fifo_txn, fifo_scoreboard) imp;

  fifo_ref_model ref_model;


  function new(string name, uvm_component parent);
    
    super.new(name, parent);
    imp = new("imp", this);
    ref_model = new();

  endfunction
  
  function void print_queue();
    string q_str;
    q_str = "";
    
    foreach (ref_model.mem_queue[i]) begin
      q_str = {q_str, $sformatf("%0d ", ref_model.mem_queue[i])};
    end
    
    `uvm_info(get_type_name(), $sformatf("QUEUE [size=%0d] : [ %s]", ref_model.mem_queue.size(), q_str), UVM_NONE)
  
  endfunction

  
  bit pending_check;
  bit [DATA_WIDTH-1:0] pending_expected;
  
  function void write(fifo_txn txn);
    
    if (txn.reset) begin
      
      ref_model.update(txn);
      pending_check = 0;
      
      `uvm_info("FIFO_SCB", "RESET detected", UVM_NONE)
      return;
    
    end
    
    
    if (txn.empty !== ref_model.expected_empty) begin
      
      `uvm_error("FIFO_SCB",$sformatf("EMPTY MISMATCH: expected=%0b actual=%0b",ref_model.expected_empty,txn.empty))
    
    end
    
    if (txn.full !== ref_model.expected_full) begin
      
      `uvm_error("FIFO_SCB",$sformatf("FULL MISMATCH: expected=%0b actual=%0b",ref_model.expected_full,txn.full))
    
    end
    
    
    if (pending_check) begin
      
      if (txn.rd_data !== pending_expected) begin
        
        `uvm_error(get_type_name(),$sformatf("DATA MISMATCH: expected=%0d actual=%0d",ref_model.expected_data,txn.rd_data))
      
      end
      
      else begin
        
        `uvm_info(get_type_name(),$sformatf("DATA MATCH: expected=%0d actual=%0d",ref_model.expected_data,txn.rd_data),UVM_NONE)
      
      end
      
      pending_check = 0;
    
    end
    
    if (txn.rd_en && !txn.empty) begin
      
      pending_expected = ref_model.mem_queue[0];
      pending_check = 1;
    
    end
    
    ref_model.update(txn);
    
    print_queue();
endfunction

endclass

class fifo_coverage extends uvm_subscriber #(fifo_txn);
  
  `uvm_component_utils(fifo_coverage)
  
  fifo_txn txn;
  
  covergroup cg;
    
    cp_wr_en: coverpoint txn.wr_en { bins write ={1};
                                    bins no_write={0};
                                   }
    cp_rd_en: coverpoint txn.rd_en { bins read ={1};
                                    bins no_read={0};
                                   }
    cp_full: coverpoint txn.full { bins full ={1};
                                    bins no_full={0};
                                   }
    cp_empty: coverpoint txn.empty { bins empty ={1};
                                    bins no_empty={0};
                                   }
    
    cx_wr_full: cross cp_wr_en, cp_full {
      ignore_bins ig_full = binsof(cp_wr_en.write) && binsof(cp_full.full);
    }
    
    cx_rd_empty: cross cp_rd_en, cp_empty {
      ignore_bins ig_empty = binsof(cp_rd_en.read) && binsof(cp_empty.empty);
    }
    
  endgroup
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
    cg = new();
  endfunction
  
  virtual function void write (fifo_txn tr);
    txn = tr;
    cg.sample();
  endfunction
  
 virtual function void report_phase(uvm_phase phase);
  super.report_phase(phase);
   `uvm_info(get_type_name(),$sformatf("Overall Coverage : %.2f%% \n",cg.get_coverage()),UVM_LOW)

  `uvm_info(get_type_name(),$sformatf("cp_wr_en coverage: %.2f%%", cg.cp_wr_en.get_coverage()),UVM_LOW)
  `uvm_info(get_type_name(),$sformatf("cp_rd_en coverage: %.2f%%", cg.cp_rd_en.get_coverage()),UVM_LOW)
  `uvm_info(get_type_name(),$sformatf("cp_full coverage: %.2f%%", cg.cp_full.get_coverage()),UVM_LOW)
  `uvm_info(get_type_name(),$sformatf("cp_empty coverage: %.2f%%", cg.cp_empty.get_coverage()),UVM_LOW)
  `uvm_info(get_type_name(),$sformatf("cross wr_full coverage: %.2f%%", cg.cx_wr_full.get_coverage()),UVM_LOW)
  `uvm_info(get_type_name(),$sformatf("cross rd_empty coverage: %.2f%%", cg.cx_rd_empty.get_coverage()),UVM_LOW)
endfunction
  
endclass

class fifo_env extends uvm_env;
  
  `uvm_component_utils(fifo_env)
  
  fifo_agent agent;
  fifo_scoreboard scb;
  fifo_coverage cov;
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = fifo_agent::type_id::create("agent",this);
    scb = fifo_scoreboard::type_id::create("scb",this);
    cov = fifo_coverage::type_id::create("cov",this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(scb.imp);
    agent.mon.ap.connect(cov.analysis_export);
  endfunction
  
endclass

module fifo_assertions #(parameter DATA_WIDTH = 8,parameter DEPTH = 16)(
  input logic                  clk,
  input logic                  reset,
  
  input logic                  wr_en,
  input logic                  rd_en,
  input logic [DATA_WIDTH-1:0] wr_data,
  
  input logic [DATA_WIDTH-1:0] rd_data,
  input logic                  full,
  input logic                  empty 
);
  
  
  //when full |-> no write
  property p1;
    @(posedge clk)
    disable iff (reset)
    full |-> !wr_en;
  endproperty
  
  a1:assert property (p1)
    else
      $error("FIFO ASSERTION FAILED: wr_en is HIGH while FIFO is FULL");
    
    
    //when empty |-> no read
  property p2;
    @(posedge clk)
    disable iff (reset)
    empty |-> !rd_en;
  endproperty
    
  a2:assert property (p2)
    else
      $error("FIFO ASSERTION FAILED: rd_en is HIGH while FIFO is EMPTY");
    
    
  //when !(full && empty) at same time
  property p3;
    @(posedge clk)
    disable iff (reset)
    !(full && empty);
  endproperty
    
  a3:assert property (p3)
    else
      $error("FIFO ASSERTION FAILED: FULL and EMPTY are both HIGH");
      
      
  //After reset, FIFO must become EMPTY
  property p4;
    @(posedge clk)
    reset |=> empty;
  endproperty
    
  a4:assert property (p4)
    else
      $error("FIFO ASSERTION FAILED: FIFO did not become EMPTY after reset");


  //After reset, rd_data must become 0
  property p5;
    @(posedge clk)
    reset |=> (rd_data == '0);
  endproperty
          
  a5:assert property (p5)
    else
      $error("FIFO ASSERTION FAILED: rd_data was not cleared by reset");

endmodule

class fifo_test extends uvm_test;
  
  `uvm_component_utils(fifo_test)
  
  fifo_env env;
  
  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fifo_env::type_id::create("env",this);
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    fifo_seq seq = fifo_seq::type_id::create("seq");
    super.run_phase(phase);
    
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    phase.drop_objection(this);
  endtask
  
endclass



package fifo_pkg;

  parameter int DATA_WIDTH = 8;
  parameter int DEPTH      = 16;

endpackage

`include "uvm_macros.svh"
import uvm_pkg::*;
import fifo_pkg::*;
  
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
  
  logic clk;
  
  fifo_if aif(clk);
  
  sync_fifo dut(.clk(clk),.reset(aif.reset),.wr_en(aif.wr_en),.rd_en(aif.rd_en),.wr_data(aif.wr_data),.rd_data(aif.rd_data),.full(aif.full),.empty(aif.empty));
  
  fifo_assertions a_dut (.clk(clk),.reset(aif.reset),.wr_en(aif.wr_en),.rd_en(aif.rd_en),.wr_data(aif.wr_data),.rd_data(aif.rd_data),.full(aif.full),.empty(aif.empty));
  
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  initial begin
    uvm_config_db #(virtual fifo_if)::set(null,"*","vif",aif);
  end
  
  initial begin
    aif.reset   = 1'b1;
    aif.wr_en   = 1'b0;
    aif.rd_en   = 1'b0;
    aif.wr_data = '0;
  end
  
  initial begin
    run_test("fifo_test");
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars();
  end
  
endmodule
