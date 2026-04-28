///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ambiente: este módulo es el encargado de conectar todos los elementos del ambiente para que puedan ser usados por el test //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ambiente #(parameter width =16, parameter depth = 8);
  // Declaración de los componentes del ambiente
  driver #(.width(width)) driver_inst;
  monitor #(.width(width)) monitor_inst;
  checker_c #(.width(width),.depth(depth)) checker_inst;
  score_board #(.width(width)) scoreboard_inst;
  agent #(.width(width),.depth(depth)) agent_inst;
  
  // Declaración de la interface que conecta el DUT 
  virtual fifo_if  #(.width(width)) _if;

  //declaración de los mailboxes
 // trans_fifo_mbx agnt_drv_mbx;           //mailbox del agente al driver
  //trans_fifo_mbx drv_mon_mbx;            //mailbox del driver al monitor
 // trans_fifo_mbx mon_chkr_mbx;           //mailbox del monitor al checker
  //trans_sb_mbx chkr_sb_mbx;              //mailbox del checker al scoreboard
  //comando_test_sb_mbx test_sb_mbx;       //mailbox del test al scoreboard
 // comando_test_agent_mbx test_agent_mbx; //mailbox del test al agente

 // mailboxes parametrizados
  mailbox #(trans_fifo #(width)) agnt_drv_mbx;
  mailbox #(trans_fifo #(width)) drv_mon_mbx;
  mailbox #(trans_fifo #(width)) mon_chkr_mbx;
  mailbox #(trans_sb   #(width)) chkr_sb_mbx;
  mailbox #(instrucciones_agente) test_agent_mbx;
  mailbox #(solicitud_sb)         test_sb_mbx;

  function new();
    // Instanciación de los mailboxes
    drv_mon_mbx    = new();
    mon_chkr_mbx   = new();
    agnt_drv_mbx   = new();
    chkr_sb_mbx    = new();
    test_sb_mbx    = new();
    test_agent_mbx = new();

    // instanciación de los componentes del ambiente
    driver_inst     = new();
    monitor_inst    = new();
    checker_inst    = new();
    scoreboard_inst = new();
    agent_inst      = new();
    // conexion de las interfaces y mailboxes en el ambiente
    driver_inst.vif             = _if;
    driver_inst.drv_mon_mbx     = drv_mon_mbx;
    driver_inst.agnt_drv_mbx    = agnt_drv_mbx;
    monitor_inst.vif            = _if;
    monitor_inst.drv_mon_mbx    = drv_mon_mbx;
    monitor_inst.mon_chkr_mbx   = mon_chkr_mbx;
    checker_inst.drv_chkr_mbx   = mon_chkr_mbx;
    checker_inst.chkr_sb_mbx    = chkr_sb_mbx;
    scoreboard_inst.chkr_sb_mbx = chkr_sb_mbx;
    scoreboard_inst.test_sb_mbx = test_sb_mbx;
    agent_inst.test_agent_mbx   = test_agent_mbx;
    agent_inst.agnt_drv_mbx = agnt_drv_mbx;
  endfunction

  virtual task run();
    $display("[%g]  El ambiente fue inicializado",$time);

    if (_if == null) begin
      $fatal("[%0t] Ambiente ERROR: virtual interface _if no fue conectada", $time);
    end

    // Reafirma el enlace de la interfaz justo antes de arrancar los componentes.
    driver_inst.vif  = _if;
    monitor_inst.vif = _if;

    fork
      driver_inst.run();
      monitor_inst.run();
      checker_inst.run();
      scoreboard_inst.run();
      agent_inst.run();
    join_none
  endtask 
endclass
