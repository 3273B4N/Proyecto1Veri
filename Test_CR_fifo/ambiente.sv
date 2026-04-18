///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ambiente: este módulo es el encargado de conectar todos los elementos del ambiente para que puedan ser usados por el test //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ambiente #(parameter width =16, parameter depth = 8);
  // Declaración de los componentes del ambiente
  generator #(.width(width),.depth(depth)) generator_inst;
  driver #(.width(width)) driver_inst;
  monitor #(.width(width)) monitor_inst;
  checker_c #(.width(width),.depth(depth)) checker_inst;
  score_board #(.width(width)) scoreboard_inst;
  agent #(.width(width),.depth(depth)) agent_inst;
  
  // Declaración de la interface que conecta el DUT 
  virtual fifo_if  #(.width(width)) _if;

  //declaración de los mailboxes
  trans_fifo_mbx agnt_drv_mbx;           //mailbox del agente al driver
  trans_fifo_mbx gen_agnt_mbx;           //mailbox del generador al agente
  trans_fifo_mbx agnt_sb_mbx;            //mailbox del agente al scoreboard
  trans_fifo_mbx mon_chkr_mbx;           //mailbox del monitor al checker
  trans_fifo_mbx sb_chkr_mbx;            //mailbox del scoreboard al checker
  trans_sb_mbx chkr_sb_mbx;              //mailbox del checker al scoreboard
  comando_test_sb_mbx test_sb_mbx;       //mailbox del test al scoreboard
  comando_test_gen_mbx test_gen_mbx;     //mailbox del test al generador

  function new();
    // Instanciación de los mailboxes
    mon_chkr_mbx   = new();
    agnt_drv_mbx   = new();
    gen_agnt_mbx   = new();
    agnt_sb_mbx    = new();
    sb_chkr_mbx    = new();
    chkr_sb_mbx    = new();
    test_sb_mbx    = new();
    test_gen_mbx   = new();

    // instanciación de los componentes del ambiente
    generator_inst  = new();
    driver_inst     = new();
    monitor_inst    = new();
    checker_inst    = new();
    scoreboard_inst = new();
    agent_inst      = new();
    // conexion de las interfaces y mailboxes en el ambiente
    driver_inst.vif             = _if;
    monitor_inst.vif            = _if;
    driver_inst.agnt_drv_mbx    = agnt_drv_mbx;
    generator_inst.test_gen_mbx = test_gen_mbx;
    generator_inst.gen_agnt_mbx = gen_agnt_mbx;
    scoreboard_inst.agnt_sb_mbx = agnt_sb_mbx;
    scoreboard_inst.sb_chkr_mbx = sb_chkr_mbx;
    monitor_inst.mon_chkr_mbx   = mon_chkr_mbx;
    checker_inst.mon_chkr_mbx   = mon_chkr_mbx;
    checker_inst.sb_chkr_mbx    = sb_chkr_mbx;
    checker_inst.chkr_sb_mbx    = chkr_sb_mbx;
    scoreboard_inst.chkr_sb_mbx = chkr_sb_mbx;
    scoreboard_inst.test_sb_mbx = test_sb_mbx;
    agent_inst.gen_agnt_mbx     = gen_agnt_mbx;
    agent_inst.agnt_drv_mbx     = agnt_drv_mbx;
    agent_inst.agnt_sb_mbx      = agnt_sb_mbx;
  endfunction

  virtual task run();
    $display("[%g]  El ambiente fue inicializado",$time);
    fork
      generator_inst.run();
      driver_inst.run();
      monitor_inst.run();
      checker_inst.run();
      scoreboard_inst.run();
      agent_inst.run();
    join_none
  endtask 
endclass
