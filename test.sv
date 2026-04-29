///////////////////////////////////
// Módulo para correr la prueba  //
//////////////////////////////////
class test #(parameter width = 16, parameter depth = 8); 
  
  comando_test_sb_mbx    test_sb_mbx;    // canal para enviar órdenes al scoreboard
  comando_test_agent_mbx test_agent_mbx; // canal para enviar instrucciones al agente

  parameter num_transacciones = depth;
  parameter max_retardo = 4;
  solicitud_sb orden;
  instrucciones_agente instr_agent; // instrucción que se pone en el mailbox del agente
  solicitud_sb instr_sb;            // instrucción que se pone en el mailbox del scoreboard

  // flags que se leen desde la línea de comandos con plusargs;
  // cada uno habilita un modo de generación o condición de borde distinto
  bit run_llenado;    // +run_llenado:    genera escrituras seguidas de lecturas
  bit run_aleatorio;  // +run_aleatorio:  genera una transacción completamente aleatoria
  bit run_especifico; // +run_especifico: genera transacciones con tipo, dato y retardo fijos
  bit run_secuencia;  // +run_secuencia:  genera una secuencia de N transacciones aleatorias

  // condiciones de borde; se leen como flags booleanos desde la línea de comandos
  bit habilitar_overflow;       // +habilitar_overflow:       permite escrituras con fifo llena
  bit habilitar_underflow;      // +habilitar_underflow:      permite lecturas con fifo vacía
  bit habilitar_patron;         // +habilitar_patron:         restringe datos a patrones de alternancia
  bit habilitar_push_pop;       // +habilitar_push_pop:       fuerza operaciones simultáneas
  bit habilitar_reset_random;   // +habilitar_reset_random:   mezcla resets aleatorios en la secuencia

  // fuerzan el nivel de la fifo antes de generar cada transacción
  bit habilitar_fifo_full;   // +habilitar_fifo_full:  nivel == depth
  bit habilitar_fifo_empty;  // +habilitar_fifo_empty: nivel == 0
  bit habilitar_fifo_mid;    // +habilitar_fifo_mid:   nivel == depth/2

  // disparan un reset solo cuando el nivel coincide con el estado indicado
  bit habilitar_reset_full;   // +habilitar_reset_full:  reset cuando fifo llena
  bit habilitar_reset_empty;  // +habilitar_reset_empty: reset cuando fifo vacía
  bit habilitar_reset_mid;    // +habilitar_reset_mid:   reset cuando fifo a la mitad

  // parámetros numéricos que llegan con valor desde la línea de comandos
  int num_transacciones_cfg;   // +NumeroTransacciones=<N>: cuántas transacciones por instrucción
  int max_retardo_cfg;         // +MaxRetardo=<N>:          cota superior del retardo entre transacciones
  int ret_spec_cfg;            // +RetardoEspecifico=<N>:   retardo fijo para modo específico
  int tpo_spec_cfg;            // +TipoEspecifico=<0..3>:   tipo fijo (0=lectura,1=escritura,2=simultánea,3=reset)
  bit [width-1:0] dto_spec_cfg; // +DatoEspecifico=<HEX>:  dato fijo para modo específico
  int tiempo_limite_cfg;       // +TiempoLimite=<N>:        ciclos hasta pedir reporte y terminar
  int tiempo_cierre_cfg;       // +TiempoCierre=<N>:        ciclos adicionales para que el scoreboard imprima antes del finish
   
  ambiente #(.depth(depth),.width(width)) ambiente_inst;
  virtual fifo_if #(.width(width)) _if;

  function new; 
    // instanciación de mailboxes y ambiente
    test_sb_mbx    = new();
    test_agent_mbx = new();
    ambiente_inst  = new();

    // conexión de mailboxes del test hacia el ambiente y sus componentes internos
    ambiente_inst._if                           = _if;    
    ambiente_inst.test_sb_mbx                   = test_sb_mbx;
    ambiente_inst.scoreboard_inst.test_sb_mbx   = test_sb_mbx;
    ambiente_inst.test_agent_mbx                = test_agent_mbx;
    ambiente_inst.agent_inst.test_agent_mbx     = test_agent_mbx;

    // plusargs obligatorios: si alguno falta la simulación termina con fatal.
    // se usan $value$plusargs porque necesitan leer un valor numérico, no solo detectar presencia.

    // cantidad de transacciones que el agente genera por instrucción
    if(!$value$plusargs("NumeroTransacciones=%d", num_transacciones_cfg))
      $fatal("Test ERROR: Falta plusarg obligatorio +NumeroTransacciones=<N>");
    ambiente_inst.agent_inst.num_transacciones = num_transacciones_cfg;

    // retardo máximo entre transacciones, limita el constraint const_retardo de la transacción
    if(!$value$plusargs("MaxRetardo=%d", max_retardo_cfg))
      $fatal("Test ERROR: Falta plusarg obligatorio +MaxRetardo=<N>");
    ambiente_inst.agent_inst.max_retardo = max_retardo_cfg;

    // duración total de la prueba en unidades de simulación antes de pedir el reporte
    if(!$value$plusargs("TiempoLimite=%d", tiempo_limite_cfg))
      $fatal("Test ERROR: Falta plusarg obligatorio +TiempoLimite=<N>");

    // tiempo adicional tras el límite para que el scoreboard termine de imprimir
    if(!$value$plusargs("TiempoCierre=%d", tiempo_cierre_cfg))
      $fatal("Test ERROR: Falta plusarg obligatorio +TiempoCierre=<N>");

    // plusargs de casos principales: se detectan con $test$plusargs porque son flags de presencia,
    // no llevan valor numérico asociado
    run_llenado   = $test$plusargs("run_llenado");
    run_aleatorio = $test$plusargs("run_aleatorio");
    run_especifico = $test$plusargs("run_especifico");
    run_secuencia = $test$plusargs("run_secuencia");

    // si se pide modo específico, se necesitan tres plusargs adicionales con valor.
    // se validan juntos porque los tres son indispensables para que la transacción tenga sentido.
    if(run_especifico) begin

      // retardo fijo que se asignará directamente al campo retardo de la transacción
      if(!$value$plusargs("RetardoEspecifico=%d", ret_spec_cfg))
        $fatal("Test ERROR: +run_especifico requiere +RetardoEspecifico=<N>");

      // tipo como entero; se castea a tipo_trans al pasarlo al agente
      if(!$value$plusargs("TipoEspecifico=%d", tpo_spec_cfg))
        $fatal("Test ERROR: +run_especifico requiere +TipoEspecifico=<0..3>");

      // validación del rango antes del cast para detectar valores inválidos temprano
      if((tpo_spec_cfg < lectura) || (tpo_spec_cfg > reset))
        $fatal("Test ERROR: +TipoEspecifico fuera de rango. Use 0=lectura, 1=escritura, 2=lectura_escritura, 3=reset");

      // dato en hexadecimal; el formato %h permite escribir directamente el valor sin conversión
      if(!$value$plusargs("DatoEspecifico=%h", dto_spec_cfg))
        $fatal("Test ERROR: +run_especifico requiere +DatoEspecifico=<HEX>");
    end

    // plusargs de condiciones de borde, todos son flags de presencia, sin valor asociado.
    // se leen con $test$plusargs y se almacenan como bits para pasarlos al agente.
    habilitar_overflow     = $test$plusargs("habilitar_overflow");
    habilitar_underflow    = $test$plusargs("habilitar_underflow");
    habilitar_patron       = $test$plusargs("habilitar_patron");
    habilitar_push_pop     = $test$plusargs("habilitar_push_pop");
    habilitar_reset_random = $test$plusargs("habilitar_reset_random");

    habilitar_fifo_full  = $test$plusargs("habilitar_fifo_full");
    habilitar_fifo_empty = $test$plusargs("habilitar_fifo_empty");
    habilitar_fifo_mid   = $test$plusargs("habilitar_fifo_mid");

    habilitar_reset_full  = $test$plusargs("habilitar_reset_full");
    habilitar_reset_empty = $test$plusargs("habilitar_reset_empty");
    habilitar_reset_mid   = $test$plusargs("habilitar_reset_mid");

    // se copian todos los flags al agente para que sus constraints los vean al randomizar
    ambiente_inst.agent_inst.habilitar_overflow     = habilitar_overflow;
    ambiente_inst.agent_inst.habilitar_underflow    = habilitar_underflow;
    ambiente_inst.agent_inst.habilitar_patron       = habilitar_patron;
    ambiente_inst.agent_inst.habilitar_push_pop     = habilitar_push_pop;
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
      ambiente_inst.run(); // arranca todos los componentes del ambiente en paralelo
    join_none              // no bloquea; el test sigue enviando instrucciones inmediatamente
    
    // cada bloque if pone una instrucción en el mailbox del agente;
    // pueden activarse varios a la vez si se pasan múltiples plusargs en la misma corrida

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
      // se pasan los tres parámetros específicos al agente justo antes de enviar la instrucción
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

    // si no se activó ningún caso principal la prueba no tiene sentido, se termina de inmediato
    if(!(run_llenado || run_aleatorio || run_especifico || run_secuencia))
      $fatal("[%g]  Test ERROR: No se seleccionó ningún caso principal. Use +run_llenado, +run_aleatorio, +run_especifico o +run_secuencia",$time);

    // se espera el tiempo límite y luego se le pide al scoreboard el reporte final
    #(tiempo_limite_cfg)
    $display("[%g]  Test: Se alcanza el tiempo límite de la prueba",$time);
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb); // primero calcula el retardo promedio
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb); // luego imprime el reporte completo

    // se espera el tiempo de cierre para que el scoreboard termine de procesar antes del finish
    #(tiempo_cierre_cfg)
    $finish;
  endtask
endclass
