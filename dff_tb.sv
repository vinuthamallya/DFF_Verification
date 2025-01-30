class transaction ;
  randc bit din;
  bit dout;
  
  function transaction copy();
    copy = new();
    copy.din = this.din;
    copy.dout = this.dout;
  endfunction
  
  function void display(input string tag );
    $display("[%s] : Din = %0b , Dout = %0b ", tag , din , dout );
  endfunction
  
endclass

class generator ;
  transaction t_h;
  mailbox #(transaction) gen_mbxdr; // to send data to DR
  mailbox #(transaction) gen_mbxsb; // to send data to SB
  event sconext ; // to sense the completion of scoreboard work
  event done; // triggered once requested number of stimuli are applied
  int count ; // stimulus count 
  
  function new(mailbox #(transaction) gen_mbxdr , mailbox #(transaction) gen_mbxsb );
    this.gen_mbxdr = gen_mbxdr;
    this.gen_mbxsb = gen_mbxsb;
    t_h = new();
  endfunction 
  
  task run();
    repeat(count) begin
      for(int i = 0 ; i<10 ; i++)
        assert(t_h.randomize());
      gen_mbxdr.put(t_h);
      gen_mbxsb.put(t_h);
      t_h.display("GEN");
      $display("Data sent to driver");
      @(sconext);
    end
    -> done;
  endtask
  
endclass 


class driver ;
  virtual dff_if vif;
  mailbox #(transaction) mbxdr;
  transaction data;
  
  function new(mailbox #(transaction) mbxdr);
    this.mbxdr = mbxdr;
  endfunction
  
  task reset();
    vif.rst <= 1;
    repeat(5) @(posedge vif.clk)
    vif.rst <= 0;
    @(posedge vif.clk)
    $display("[DRV] : Reset done");
  endtask
             
             
  task run;
    forever begin 
      mbxdr.get(data);
      vif.din <= data.din;
      @(posedge vif.clk)
      data.display("DRV");
      vif.din <= 1'b0;
      @(posedge vif.clk);          
    end
  endtask
  
 endclass
             
class monitor;
  virtual dff_if vif;
  mailbox #(transaction) mbxsb2;
  transaction data;
  
  function new(mailbox #(transaction) mbxsb2);
    this.mbxsb2 = mbxsb2;
  endfunction
  
  task run();
    data = new();
    forever begin
      repeat(2) @(posedge vif.clk)
      data.dout = vif.dout;
      mbxsb2.put(data);
      data.display("MON");
    end
  endtask
  
endclass
            
class scoreboard;
  mailbox #(transaction) gen_mbxsb;
  mailbox #(transaction) mon_mbxsb;
  transaction data_gen; // to recieve data from generator
  transaction data_mon; // to recieve data from monitor
   event sconext;  // to notify generator that we have completed process of comparing.
  
  function new (mailbox #(transaction) gen_mbxsb , mailbox #(transaction) mon_mbxsb);
    this.gen_mbxsb = gen_mbxsb;
    this.mon_mbxsb = mon_mbxsb;
  endfunction
  
  /*task compare(input transaction data);
    if(data.rst == 0 */
  
  task run();
    forever begin
      mon_mbxsb.get(data_mon);
      gen_mbxsb.get(data_gen);
      data_mon.display("SB");
      data_gen.display("REF_GEN");
      if(data_mon.dout==data_gen.din) 
        $display("DATA MATCHED");
        else
        $display("DATA MISMATCHED");
        $display("--------------------------------");
        -> sconext;
    end
  endtask
endclass
  
  class environment;
    
    generator gen_h;
    driver drv_h;
    monitor mon_h;
    scoreboard sb_h;
    
    mailbox #(transaction) gen_mbx_drv;
    mailbox #(transaction) gen_mbx_sb;
    mailbox #(transaction) mon_mbx;
    
    virtual dff_if vif;
    event next;
    
    function new(virtual dff_if vif);
      
      gen_mbx_drv=new();
      gen_mbx_sb=new();
      mon_mbx=new();
      
      gen_h = new(gen_mbx_drv ,gen_mbx_sb);
      drv_h = new(gen_mbx_drv);
      mon_h = new(mon_mbx);
      sb_h = new(gen_mbx_sb , mon_mbx);
      
      this.vif = vif;
      drv_h.vif = this.vif ;
      mon_h.vif = this.vif ;
      
      gen_h.sconext = this.next;
      sb_h.sconext = this.next;
      
    endfunction 
      
    
    task pre_test();
      drv_h.reset();
    endtask
    
    task test();
     fork
       gen_h.run();
       drv_h.run();
       mon_h.run();
       sb_h.run();
     join_any
    endtask
    
    task post_test();
      wait(gen_h.done.triggered);
      $finish;
    endtask
    
    task run();
      pre_test();
      test();
      post_test();
    endtask
    
  endclass
  
  module tb;
    
    dff_if vif();
    dff dut (vif);
    
    initial begin 
      vif.clk <= 0;
    end
    
    always #10 vif.clk <= ~vif.clk ;
    
    environment env_h;
    
    initial begin
      env_h = new(vif);
      env_h.gen_h.count = 30;
      env_h.run();
    end
    
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end
    
  endmodule 
