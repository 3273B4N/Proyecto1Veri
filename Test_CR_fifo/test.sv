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
  int ret_spec_cfg;
  int tpo_spec_cfg;
  bit [width-1:0] dto_spec_cfg;
  int tiempo_limite_cfg;
  int tiempo_cierre_cfg;
   
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

    // Configuración obligatoria por plusargs
    if(!$value$plusargs("NumeroTransacciones=%d", num_transacciones_cfg)) begin
      $fatal("Test ERROR: Falta plusarg obligatorio +NumeroTransacciones=<N>");
    end
    ambiente_inst.agent_inst.num_transacciones = num_transacciones_cfg;

    if(!$value$plusargs("MaxRetardo=%d", max_retardo_cfg)) begin
      $fatal("Test ERROR: Falta plusarg obligatorio +MaxRetardo=<N>");
    end
    ambiente_inst.agent_inst.max_retardo = max_retardo_cfg;

    if(!$value$plusargs("TiempoLimite=%d", tiempo_limite_cfg)) begin
      $fatal("Test ERROR: Falta plusarg obligatorio +TiempoLimite=<N>");
    end

    if(!$value$plusargs("TiempoCierre=%d", tiempo_cierre_cfg)) begin
      $fatal("Test ERROR: Falta plusarg obligatorio +TiempoCierre=<N>");
    end

    //Casos principales
    run_llenado = $test$plusargs("run_llenado");
    run_aleatorio = $test$plusargs("run_aleatorio");
    run_especifico = $test$plusargs("run_especifico");
    run_secuencia = $test$plusargs("run_secuencia");

    if(run_especifico) begin
      if(!$value$plusargs("RetardoEspecifico=%d", ret_spec_cfg)) begin
        $fatal("Test ERROR: +run_especifico requiere +RetardoEspecifico=<N>");
      end

      if(!$value$plusargs("TipoEspecifico=%d", tpo_spec_cfg)) begin
        $fatal("Test ERROR: +run_especifico requiere +TipoEspecifico=<0..3>");
      end

      if((tpo_spec_cfg < lectura) || (tpo_spec_cfg > reset)) begin
        $fatal("Test ERROR: +TipoEspecifico fuera de rango. Use 0=lectura, 1=escritura, 2=lectura_escritura, 3=reset");
      end

      if(!$value$plusargs("DatoEspecifico=%h", dto_spec_cfg)) begin
        $fatal("Test ERROR: +run_especifico requiere +DatoEspecifico=<HEX>");
      end
    end

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
      ambiente_inst.agent_inst.ret_spec = ret_spec_cfg;
      ambiente_inst.agent_inst.tpo_spec = tipo_trans'(tpo_spec_cfg);
      ambiente_inst.agent_inst.dto_spec = dto_spec_cfg;
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
      $fatal("[%g]  Test ERROR: No se seleccionó ningún caso principal. Use +run_llenado, +run_aleatorio, +run_especifico o +run_secuencia",$time);
    end

    #(tiempo_limite_cfg)
    $display("[%g]  Test: Se alcanza el tiempo límite de la prueba",$time);
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);
    #(tiempo_cierre_cfg)
    $finish;
  endtask
endclass
