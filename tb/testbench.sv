interface axi_if;
 logic clk,resetn;
 logic awvalid,awready;
 logic arvalid,arready;
 logic wvalid,wready;
 logic bready,bvalid;
 logic rvalid,rready;
 logic[31:0] awaddr,araddr,wdata,rdata;
 logic[1:0] bresp,rresp;
endinterface

class transaction;
 rand bit op;
 rand bit[31:0] awaddr;
 rand bit[31:0] wdata;
 rand bit[31:0] araddr;
 bit[31:0] rdata;
 bit[1:0] bresp;
 bit[1:0] rresp;
 constraint valid_addr_range{awaddr < 128; araddr < 128;}
 constraint vaid_data_range{wdata < 100;}
endclass

class generator;
 transaction tr;
 mailbox#(transaction) mbxgd;
 event done;
 event sconext;
 int count=0;
 function new(mailbox #(transaction)mbxgd);
   this.mbxgd=mbxgd;
 endfunction
 task run();
   for (int i=0;i<count;i++)begin
     tr=new();
     assert(tr.randomize())else $error("RANDOMIZATION FAILED");
     $display("[GEN] :op %0b awaddr %0d wdata %0d araddr %0d",tr.op,tr.awaddr,tr.wdata,tr.araddr);
     mbxgd.put(tr);
     @(sconext);
   end
   ->done;
 endtask 
endclass

class driver;
 virtual axi_if vif;
 transaction tr;
 mailbox #(transaction) mbxgd;
 function new(mailbox #(transaction) mbxgd);
   this.mbxgd=mbxgd;
 endfunction
 task reset();
   vif.resetn<=1'b0;
   vif.awvalid<=1'b0;
   vif.awaddr<=0;
   vif.wvalid<=0;
   vif.wdata<=0;
   vif.bready<=0;
   vif.arvalid<=1'b0;
   vif.araddr<=0;
   vif.rready<=0;
   repeat(5)@(posedge vif.clk);
   vif.resetn<=1'b1;
   $display("---------[DRV]:RESET DONE--------");
 endtask
 task write_data(input transaction tr);
   $display("[DRV]:OP %0b awaddr %0d wdata %0d",tr.op,tr.awaddr,tr.wdata);
   vif.awvalid<=1'b1;
   vif.awaddr<=tr.awaddr;
   @(posedge vif.clk);
   while(!vif.awready) @(posedge vif.clk);
   vif.awvalid<=1'b0;
   vif.wvalid<=1'b1;
   vif.wdata<=tr.wdata;
   @(posedge vif.clk);
   while(!vif.wready) @(posedge vif.clk);
   vif.wvalid<=1'b0;
   vif.bready<=1'b1;
   @(posedge vif.clk);
   while(!vif.bvalid) @(posedge vif.clk);
   vif.bready<=1'b0;
 endtask
 task read_data(transaction tr);
   $display("[DRV] op %0b araddr %0d",tr.op,tr.araddr);
   vif.arvalid<=1'b1;
   vif.araddr<=tr.araddr;
   @(posedge vif.clk);
   while(!vif.arready) @(posedge vif.clk);
   vif.arvalid<=1'b0;
   vif.rready<=1'b1;
   @(posedge vif.clk);
   while(!vif.rvalid) @(posedge vif.clk);
   vif.rready<=1'b0;
 endtask
 task run();
   forever begin       
     mbxgd.get(tr);
     @(posedge vif.clk); 
     if(tr.op == 1'b1) 
       write_data(tr);    
     else
       read_data(tr);    
   end
 endtask
endclass

class monitor;
 virtual axi_if vif; 
 transaction tr;
 mailbox #(transaction) mbxms;
 function new(mailbox #(transaction) mbxms);
   this.mbxms = mbxms;
 endfunction
 task run();
   forever begin
     @(posedge vif.clk);
     if(vif.awvalid && vif.awready) begin
       tr = new();
       tr.op = 1'b1;
       tr.awaddr = vif.awaddr;
       @(posedge vif.clk);
       while(!(vif.wvalid && vif.wready)) @(posedge vif.clk);
       tr.wdata = vif.wdata;
       while(!(vif.bvalid && vif.bready)) @(posedge vif.clk);
       tr.bresp = vif.bresp;
       $display("[MON] : OP : %0b awaddr : %0d wdata : %0d bresp:%0d",tr.op, tr.awaddr, tr.wdata, tr.bresp);
       mbxms.put(tr); 
     end
     else if(vif.arvalid && vif.arready) begin
       tr = new();
       tr.op = 1'b0;
       tr.araddr = vif.araddr;
       @(posedge vif.clk);
       while(!(vif.rvalid && vif.rready)) @(posedge vif.clk);
       tr.rdata = vif.rdata;
       tr.rresp = vif.rresp;
       $display("[MON] : OP : %0b araddr : %0d rdata : %0d rresp:%0d",tr.op, tr.araddr, tr.rdata, tr.rresp);
       mbxms.put(tr); 
     end
   end 
 endtask
endclass

class scoreboard;
 transaction tr;
 event sconext;
 mailbox #(transaction) mbxms;
 bit [31:0] temp;
 bit [31:0] data[128] = '{default:0};
 function new( mailbox #(transaction) mbxms);
   this.mbxms = mbxms;
 endfunction
 task run();
   forever begin 
     mbxms.get(tr);
     if(tr.op == 1) begin
       $display("[SCO] : OP : %0b awaddr : %0d wdata : %0d bresp : %0d",tr.op, tr.awaddr, tr.wdata, tr.bresp);
       if(tr.bresp == 3)
         $display("[SCO] : DEC ERROR");  
       else begin
         data[tr.awaddr] = tr.wdata;
         $display("[SCO] : DATA STORED ADDR :%0d and DATA :%0d", tr.awaddr, tr.wdata);
       end
     end
     else begin
       $display("[SCO] : OP : %0b araddr : %0d rdata : %0d rresp : %0d",tr.op, tr.araddr, tr.rdata, tr.rresp);
       temp = data[tr.araddr];
       if(tr.rresp == 3)
         $display("[SCO] : DEC ERROR");
       else if (tr.rresp == 0 && tr.rdata == temp)
         $display("[SCO] : DATA MATCHED");
       else
         $display("[SCO] : DATA MISMATCHED");
     end
     $display("----------------------------------------------------");
     ->sconext;
   end
 endtask
endclass

module tb;
 monitor mon; 
 generator gen;
 driver drv;
 scoreboard sco;
 event nextgm;
 mailbox #(transaction) mbxgd, mbxms;
 axi_if vif();
 axilite_s dut (vif.clk, vif.resetn, vif.awvalid, vif.awready, vif.awaddr, vif.wvalid, vif.wready, vif.wdata, vif.bvalid, vif.bready, vif.bresp , vif.arvalid, vif.arready, vif.araddr, vif.rvalid, vif.rready, vif.rdata, vif.rresp);
 initial begin
   vif.clk <= 0;
   vif.resetn <= 0;
 end
 always #5 vif.clk <= ~vif.clk;
 initial begin
   mbxgd = new();
   mbxms = new();
   gen = new(mbxgd);
   drv = new(mbxgd);
   mon = new(mbxms);
   sco = new(mbxms);
   gen.count = 10;
   drv.vif = vif;
   mon.vif = vif;
   gen.sconext = nextgm;
   sco.sconext = nextgm;
 end
 initial begin
   drv.reset();
   fork
     gen.run();
     drv.run();
     mon.run();
     sco.run();
   join_any  
   wait(gen.done.triggered);
   #100;
   $finish;
 end
 initial begin
   $dumpfile("dump.vcd");
   $dumpvars;   
 end
endmodule
