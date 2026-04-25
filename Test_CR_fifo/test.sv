///////////////////////////////////
// Módulo para correr la prueba  //
//////////////////////////////////
class test #(parameter width = 16, parameter depth =8); 
  
  comando_test_sb_mbx    test_sb_mbx;
  comando_test_agent_mbx test_agent_mbx;

  parameter num_transacciones = depth;
  parameter max_retardo = 4;
  solicitud_sb orden;
  instrucciones_agente instr_agent;
  solicitud_sb instr_sb;

  // Variables de configuracion para plusargs
  bit run_llenado;
  bit run_aleatorio;
  bit run_especifico;
  bit run_secuencia;

  bit habilitar_overflow;
  bit habilitar_underflow;
  bit habilitar_patron;
  bit habilitar_push_pop;
  bit habilitar_reset_random;

  bit habilitar_fifo_full;
  bit habilitar_fifo_empty;
  bit habilitar_fifo_mid;

  bit habilitar_reset_full;
  bit habilitar_reset_empty;
  bit habilitar_reset_mid;

  int num_transacciones_cfg;
  int max_retardo_cfg;
   
 // Definición del ambiente de la prueba
  ambiente #(.depth(depth),.width(width)) ambiente_inst;
 // Definición de la interface a la que se conectará el DUT
  virtual fifo_if  #(.width(width)) _if;

  //definción de las condiciones iniciales del test
  function new; 
    // instaciación de los mailboxes
    test_sb_mbx  = new();
    test_agent_mbx = new();
    // Definición y conexión del dirver
    ambiente_inst = new();
    ambiente_inst._if = _if;    
    ambiente_inst.test_sb_mbx = test_sb_mbx;
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;
    ambiente_inst.test_agent_mbx = test_agent_mbx;
    ambiente_inst.agent_inst.test_agent_mbx = test_agent_mbx;

    ambiente_inst.agent_inst.num_transacciones = num_transacciones;
    ambiente_inst.agent_inst.max_retardo = max_retardo;

    // Configuración por plusargs
    if($value$plusargs("NumeroTransacciones=%d", num_transacciones_cfg)) begin
      ambiente_inst.agent_inst.num_transacciones = num_transacciones_cfg;
    end

    if($value$plusargs("MaxRetardo=%d", max_retardo_cfg)) begin
      ambiente_inst.agent_inst.max_retardo = max_retardo_cfg;
    end

    //Casos principales
    run_llenado = $test$plusargs("run_llenado");
    run_aleatorio = $test$plusargs("run_aleatorio");
    run_especifico = $test$plusargs("run_especifico");
    run_secuencia = $test$plusargs("run_secuencia");

    // Casos esquina
    habilitar_overflow = $test$plusargs("habilitar_overflow");
    habilitar_underflow = $test$plusargs("habilitar_underflow");
    habilitar_patron = $test$plusargs("habilitar_patron");
    habilitar_push_pop = $test$plusargs("habilitar_push_pop");
    habilitar_reset_random = $test$plusargs("habilitar_reset_random");

    habilitar_fifo_full  = $test$plusargs("habilitar_fifo_full");
    habilitar_fifo_empty = $test$plusargs("habilitar_fifo_empty");
    habilitar_fifo_mid   = $test$plusargs("habilitar_fifo_mid");

    habilitar_reset_full  = $test$plusargs("habilitar_reset_full");
    habilitar_reset_empty = $test$plusargs("habilitar_reset_empty");
    habilitar_reset_mid   = $test$plusargs("habilitar_reset_mid");

    //Pasar flags al agente/generador
    ambiente_inst.agent_inst.habilitar_overflow = habilitar_overflow;
    ambiente_inst.agent_inst.habilitar_underflow = habilitar_underflow;
    ambiente_inst.agent_inst.habilitar_patron = habilitar_patron;
    ambiente_inst.agent_inst.habilitar_push_pop = habilitar_push_pop;
    ambiente_inst.agent_inst.habilitar_reset_random = habilitar_reset_random;

    ambiente_inst.agent_inst.habilitar_fifo_full  = habilitar_fifo_full;
    ambiente_inst.agent_inst.habilitar_fifo_empty = habilitar_fifo_empty;
    ambiente_inst.agent_inst.habilitar_fifo_mid   = habilitar_fifo_mid;

    ambiente_inst.agent_inst.habilitar_reset_full  = habilitar_reset_full;
    ambiente_inst.agent_inst.habilitar_reset_empty = habilitar_reset_empty;
    ambiente_inst.agent_inst.habilitar_reset_mid   = habilitar_reset_mid;

  endfunction


  task run;
    $display("[%g]  El Test fue inicializado",$time);
    fork
      ambiente_inst.run();
    join_none
    
    if(run_llenado) begin
      instr_agent = llenado_aleatorio;
      test_agent_mbx.put(instr_agent);
      $display("[%g]  Test: Enviada la primera instruccion al agente llenado aleatorio con num_transacciones %g",$time,ambiente_inst.agent_inst.num_transacciones);
    end

    if(run_aleatorio) begin
      instr_agent = trans_aleatoria;
      test_agent_mbx.put(instr_agent);
      $display("[%g]  Test: Enviada la segunda instruccion al agente transaccion_aleatoria",$time);
    end

    if(run_especifico) begin
      ambiente_inst.agent_inst.ret_spec = 3;
      ambiente_inst.agent_inst.tpo_spec = escritura;
      ambiente_inst.agent_inst.dto_spec = {width/4{4'h5}};
      instr_agent = trans_especifica;
      test_agent_mbx.put(instr_agent);
      $display("[%g]  Test: Enviada la tercera instruccion al agente transaccion_específica",$time);
    end 
    
    if(run_secuencia) begin
      instr_agent = sec_trans_aleatorias;
      test_agent_mbx.put(instr_agent);
      $display("[%g]  Test: Enviada la cuarta instruccion al agente secuencia %g de transaccion_aleatoria",$time,ambiente_inst.agent_inst.num_transacciones);
    end 

    if(!(run_llenado || run_aleatorio || run_especifico || run_secuencia)) begin
      $display("[%g]  Test: No se seleccionó ningún caso principal, enviando secuencia por defecto de transacciones aleatorias",$time);
      instr_agent = trans_aleatoria;
      test_agent_mbx.put(instr_agent);
    end

    #10000
    $display("[%g]  Test: Se alcanza el tiempo límite de la prueba",$time);
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);
    #20
    $finish;
  endtask
endclass
