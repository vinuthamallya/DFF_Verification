module dff ( dff_if dif);
  always @(posedge dif.clk) begin
    if(dif.rst==1)
    dif.dout <= 0 ;
  else 
    dif.dout <= dif.din ;
  end
endmodule 


  interface dff_if;
    logic din;
    logic dout;
    logic rst;
    logic clk;
  endinterface
