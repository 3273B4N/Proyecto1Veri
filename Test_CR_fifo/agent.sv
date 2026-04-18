class agent #(parameter width = 16, parameter depth = 8);
  trans_fifo_mbx gen_agnt_mbx;           // Mailbox del generador al agente
  trans_fifo_mbx agnt_drv_mbx;           // Mailbox del agente al driver
  trans_fifo_mbx agnt_sb_mbx;            // Mailbox del agente al scoreboard
  trans_fifo #(.width(width)) transaccion;

  task run;
    $display("[%g]  El Agente fue inicializado",$time);
    forever begin
      gen_agnt_mbx.get(transaccion);
      transaccion.print("Agente: transaccion recibida del generador");
      agnt_drv_mbx.put(transaccion);
      transaccion.print("Agente: transaccion enviada al driver");
      agnt_sb_mbx.put(transaccion);
      transaccion.print("Agente: transaccion enviada al scoreboard");
    end
  endtask
endclass
