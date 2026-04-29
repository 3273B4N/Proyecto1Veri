///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ambiente: este módulo es el encargado de conectar todos los elementos del ambiente para que puedan ser usados por el test //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class ambiente #(parameter width =16, parameter depth = 8);
  // Declaración de los componentes del ambiente
  driver #(.width(width)) driver_inst;
  monitor #(.width(width)) monitor_inst;   // el monitor observa el bus sin manejarlo, de ahí que solo necesite width
  checker_c #(.width(width),.depth(depth)) checker_inst;
  score_board #(.width(width)) scoreboard_inst;
  agent #(.width(width),.depth(depth)) agent_inst;
  
  // Declaración de la interface que conecta el DUT 
  virtual fifo_if  #(.width(width)) _if;
  // declaracion de los mailboxes parametrizados
  mailbox #(trans_fifo #(width)) agnt_drv_mbx;
  mailbox #(trans_fifo #(width)) drv_mon_mbx;    // lleva las transacciones del driver al monitor para que sepa qué se aplicó
  mailbox #(trans_fifo #(width)) mon_chkr_mbx;   // lleva lo que el monitor observó en el bus hacia el checker
  mailbox #(trans_sb   #(width)) chkr_sb_mbx;
  mailbox #(instrucciones_agente) test_agent_mbx;
  mailbox #(solicitud_sb)         test_sb_mbx;

  function new();
    // Instanciación de los mailboxes
    drv_mon_mbx    = new();   // canal driver → monitor
    mon_chkr_mbx   = new();   // canal monitor → checker
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
    monitor_inst.vif            = _if;            // el monitor necesita la interfaz para leer las señales del DUT
    monitor_inst.drv_mon_mbx    = drv_mon_mbx;    // recibe del driver lo que se estimuló
    monitor_inst.mon_chkr_mbx   = mon_chkr_mbx;  // envía al checker lo que observó en la interfaz
    checker_inst.drv_chkr_mbx   = mon_chkr_mbx;  // el checker recibe directamente la salida del monitor
    checker_inst.chkr_sb_mbx    = chkr_sb_mbx;
    scoreboard_inst.chkr_sb_mbx = chkr_sb_mbx;
    scoreboard_inst.test_sb_mbx = test_sb_mbx;
    agent_inst.test_agent_mbx   = test_agent_mbx;
    agent_inst.agnt_drv_mbx     = agnt_drv_mbx;
  endfunction

  virtual task run();
    $display("[%g]  El ambiente fue inicializado",$time);
    if (_if == null) begin
      $fatal("[%0t] Ambiente ERROR: virtual interface _if no fue conectada", $time);
    end
    // Reafirma el enlace de la interfaz justo antes de arrancar los componentes.
    driver_inst.vif  = _if;
    monitor_inst.vif = _if;   // se reasigna aquí también porque en el new() _if todavía es null
    fork
      driver_inst.run();
      monitor_inst.run();     // corre en paralelo con los demás, escuchando el bus pasivamente
      checker_inst.run();
      scoreboard_inst.run();
      agent_inst.run();
    join_none
  endtask 
endclass
