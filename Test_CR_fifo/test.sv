class test #(parameter width = 16, parameter depth = 8);

  comando_test_sb_mbx  test_sb_mbx;   // para mandarle ordenes al scoreboard, solo para hacer reportes de estadísticas de las pruebas 
  comando_test_gen_mbx test_gen_mbx;  // para mandarle escenarios al generador

  // variables de control general de la prueba
  int tiempo_prueba;  // cuanto tiempo maximo puede durar la simulacion antes de forzar el fin

  // variables donde se guardan los plusargs que llegan por linea de comandos
  int    plus_num_transacciones;  // cantidad de transacciones a generar
  int    plus_min_retardo;        // retardo minimo entre transacciones
  int    plus_max_retardo;        // retardo maximo entre transacciones
  int    plus_ret_spec;           // retardo para la transaccion especifica
  int    plus_dato_spec;          // dato para la transaccion especifica
  string plus_tipo_spec;          // tipo de transaccion especifica en texto
  string plus_escenario;          // nombre del escenario a correr en texto

  bit run_all;           // si esta en 1 se corren todos los escenarios
  bit escenario_valido;  // si esta en 1 significa que se recibio un escenario valido por plusarg
  instrucciones_agente escenario_plusarg;  

  // parametros fijos de configuracion por defecto
  parameter num_transacciones = depth;
  parameter min_retardo       = 1;
  parameter max_retardo       = 4;

  // objetos para mandar ordenes al scoreboard y al generador
  solicitud_sb         orden;
  instrucciones_agente instr_agent;
  solicitud_sb         instr_sb;

  // instancia del ambiente completo que contiene generador, agente, driver, monitor, checker y scoreboard
  ambiente #(.depth(depth), .width(width)) ambiente_inst;

  // interfaz virtual para conectar el test con las señales del DUT
  virtual fifo_if #(.width(width)) _if;

  // constructor, conecta todos los bloques del ambiente y define los valores iniciales
  function new;
    // se crean los mailboxes que comunican el test con el resto del ambiente
    test_sb_mbx  = new();
    test_gen_mbx = new();

    // se instancia el ambiente y se conectan sus mailboxes con los del test
    ambiente_inst = new();
    ambiente_inst._if             = _if;
    ambiente_inst.test_sb_mbx     = test_sb_mbx;
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;
    ambiente_inst.test_gen_mbx    = test_gen_mbx;
    ambiente_inst.generator_inst.test_gen_mbx = test_gen_mbx;

    // se configuran los parametros del generador con los valores por defecto
    ambiente_inst.generator_inst.num_transacciones = num_transacciones;
    ambiente_inst.generator_inst.min_retardo       = min_retardo;
    ambiente_inst.generator_inst.max_retardo       = max_retardo;

    // el tiempo maximo de prueba se calcula en base al depth y el retardo maximo
    tiempo_prueba = depth * max_retardo * 2000;

    run_all          = 1;  // por defecto se corren todos los escenarios
    escenario_valido = 0;  // todavia no se ha leido ningun escenario por plusarg
  endfunction

  // convierte un string de tipo de transaccion al enum correspondiente
  // regresa 1 si la conversion fue exitosa, 0 si el string no es valido
  function automatic bit convertir_tipo_plusarg(input string tipo_str, output tipo_trans tipo_out);
    if(tipo_str == "lectura")          begin tipo_out = lectura;          return 1; end
    if(tipo_str == "escritura")        begin tipo_out = escritura;        return 1; end
    if(tipo_str == "lectura_escritura")begin tipo_out = lectura_escritura;return 1; end
    if(tipo_str == "reset")            begin tipo_out = reset;            return 1; end
    return 0;  // el string no coincidio con ningun tipo conocido
  endfunction

  // convierte un string de nombre de escenario al enum correspondiente
  // regresa 1 si la conversion fue exitosa, 0 si el string no es valido
  function automatic bit convertir_escenario_plusarg(input string escenario_str, output instrucciones_agente escenario_out);
    if(escenario_str == "llenado_aleatorio")        begin escenario_out = llenado_aleatorio;        return 1; end
    if(escenario_str == "trans_aleatoria")          begin escenario_out = trans_aleatoria;          return 1; end
    if(escenario_str == "trans_especifica")         begin escenario_out = trans_especifica;         return 1; end
    if(escenario_str == "sec_trans_aleatorias")     begin escenario_out = sec_trans_aleatorias;     return 1; end
    if(escenario_str == "eventos_reset_aleatorios") begin escenario_out = eventos_reset_aleatorios; return 1; end
    if(escenario_str == "patron_max_alternancia")   begin escenario_out = patron_max_alternancia;   return 1; end
    if(escenario_str == "provocar_overflow")        begin escenario_out = provocar_overflow;        return 1; end
    if(escenario_str == "provocar_underflow")       begin escenario_out = provocar_underflow;       return 1; end
    if(escenario_str == "push_pop_simultaneo_bajo") begin escenario_out = push_pop_simultaneo_bajo; return 1; end
    if(escenario_str == "push_pop_simultaneo_medio")begin escenario_out = push_pop_simultaneo_medio;return 1; end
    if(escenario_str == "push_pop_simultaneo_alto") begin escenario_out = push_pop_simultaneo_alto; return 1; end
    if(escenario_str == "reset_fifo_vacia")         begin escenario_out = reset_fifo_vacia;         return 1; end
    if(escenario_str == "reset_fifo_media")         begin escenario_out = reset_fifo_media;         return 1; end
    if(escenario_str == "reset_fifo_llena")         begin escenario_out = reset_fifo_llena;         return 1; end
    return 0;  // el string no coincidio con ningun escenario conocido
  endfunction

  // lee todos los parametros que pueden llegar por linea de comandos al correr la simulacion
  task automatic leer_plusargs();
    tipo_trans tipo_plusarg;

    // RUN_ALL=0 desactiva la ejecucion de todos los escenarios
    if($value$plusargs("RUN_ALL=%d", plus_num_transacciones)) begin
      run_all = (plus_num_transacciones != 0);
    end

    // NUM_TRANS permite cambiar cuantas transacciones genera el generador en cada escenario
    if($value$plusargs("NUM_TRANS=%d", plus_num_transacciones)) begin
      if(plus_num_transacciones > 0) begin
        ambiente_inst.generator_inst.num_transacciones = plus_num_transacciones;
      end
    end

    // MIN_RETARDO y MAX_RETARDO controlan el rango de retardos aleatorios
    if($value$plusargs("MIN_RETARDO=%d", plus_min_retardo)) begin
      if(plus_min_retardo >= 0) begin
        ambiente_inst.generator_inst.min_retardo = plus_min_retardo;
      end
    end

    if($value$plusargs("MAX_RETARDO=%d", plus_max_retardo)) begin
      // el maximo no puede ser menor que el minimo
      if(plus_max_retardo >= ambiente_inst.generator_inst.min_retardo) begin
        ambiente_inst.generator_inst.max_retardo = plus_max_retardo;
      end
    end

    // RET_SPEC es el retardo fijo para la transaccion especifica
    if($value$plusargs("RET_SPEC=%d", plus_ret_spec)) begin
      if(plus_ret_spec >= 0) begin
        ambiente_inst.generator_inst.ret_spec = plus_ret_spec;
      end
    end

    // DATO_SPEC es el dato fijo para la transaccion especifica, se recorta al ancho del bus
    if($value$plusargs("DATO_SPEC=%h", plus_dato_spec)) begin
      ambiente_inst.generator_inst.dto_spec = plus_dato_spec[width-1:0];
    end

    // TIPO_SPEC es el tipo de transaccion especifica, se convierte de string a enum
    if($value$plusargs("TIPO_SPEC=%s", plus_tipo_spec)) begin
      if(convertir_tipo_plusarg(plus_tipo_spec, tipo_plusarg)) begin
        ambiente_inst.generator_inst.tpo_spec = tipo_plusarg;
      end else begin
        $display("[%g] Test Error: TIPO_SPEC invalido: %s", $time, plus_tipo_spec);
        $finish;
      end
    end

    // ESCENARIO permite elegir un solo escenario especifico para correr
    // si se usa este plusarg se desactiva run_all automaticamente
    if($value$plusargs("ESCENARIO=%s", plus_escenario)) begin
      if(convertir_escenario_plusarg(plus_escenario, escenario_plusarg)) begin
        escenario_valido = 1;
        run_all = 0;  // si se elige un escenario especifico, no se corren todos
      end else begin
        $display("[%g] Test Error: ESCENARIO invalido: %s", $time, plus_escenario);
        $finish;
      end
    end

    // si max quedo menor que min es un error de configuracion
    if(ambiente_inst.generator_inst.max_retardo < ambiente_inst.generator_inst.min_retardo) begin
      $display("[%g] Test Error: MAX_RETARDO no puede ser menor que MIN_RETARDO", $time);
      $finish;
    end

    // se recalcula el tiempo maximo con los nuevos valores de retardo
    tiempo_prueba = depth * (ambiente_inst.generator_inst.max_retardo + 1) * 2000;

    // se imprime la configuracion seleccionada para prueba
    $display("[%g] Test: Configuracion plusargs num_trans=%0d min_ret=%0d max_ret=%0d ret_spec=%0d tipo_spec=%s dato_spec=0x%h run_all=%0d",
             $time,
             ambiente_inst.generator_inst.num_transacciones,
             ambiente_inst.generator_inst.min_retardo,
             ambiente_inst.generator_inst.max_retardo,
             ambiente_inst.generator_inst.ret_spec,
             ambiente_inst.generator_inst.tpo_spec.name(),
             ambiente_inst.generator_inst.dto_spec,
             run_all);

    if(escenario_valido) begin
      $display("[%g] Test: Escenario seleccionado por plusarg = %s", $time, plus_escenario);
    end
  endtask

  // corre el escenario que se selecciono por plusarg
  task automatic correr_escenario_plusarg();
    case(escenario_plusarg)
      llenado_aleatorio:        correr_escenario(llenado_aleatorio,        "Escenario comun: llenado aleatorio");
      trans_aleatoria:          correr_escenario(trans_aleatoria,          "Escenario comun: transaccion aleatoria");
      trans_especifica:         correr_escenario(trans_especifica,         "Escenario comun: transaccion especifica");
      sec_trans_aleatorias:     correr_escenario(sec_trans_aleatorias,     "Escenario comun: secuencia de transacciones aleatorias");
      eventos_reset_aleatorios: correr_escenario(eventos_reset_aleatorios, "Escenario comun: eventos de reset aleatorios");
      patron_max_alternancia:   correr_escenario(patron_max_alternancia,   "Caso de esquina: patron 0-5-A-F con maxima alternancia");
      provocar_overflow:        correr_escenario(provocar_overflow,        "Caso de esquina: overflow");
      provocar_underflow:       correr_escenario(provocar_underflow,       "Caso de esquina: underflow");
      push_pop_simultaneo_bajo: correr_escenario(push_pop_simultaneo_bajo, "Caso de esquina: push-pop simultaneo en nivel bajo");
      push_pop_simultaneo_medio:correr_escenario(push_pop_simultaneo_medio,"Caso de esquina: push-pop simultaneo en nivel medio");
      push_pop_simultaneo_alto: correr_escenario(push_pop_simultaneo_alto, "Caso de esquina: push-pop simultaneo en nivel alto");
      reset_fifo_vacia:         correr_escenario(reset_fifo_vacia,         "Caso de esquina: reset con fifo vacia");
      reset_fifo_media:         correr_escenario(reset_fifo_media,         "Caso de esquina: reset con fifo a la mitad");
      reset_fifo_llena:         correr_escenario(reset_fifo_llena,         "Caso de esquina: reset con fifo llena");
      default: begin
        $display("[%g] Test Error: escenario seleccionado no valido", $time);
        $finish;
      end
    endcase
  endtask

  // manda un escenario al generador y muestra en consola que escenario se esta corriendo
  task automatic correr_escenario(input instrucciones_agente escenario, input string descripcion);
    test_gen_mbx.put(escenario);  // se le dice al generador que escenario ejecutar
    $display("[%g]  Test: %s", $time, descripcion);
  endtask

  // espera a que todos los mailboxes esten vacios y las señales del DUT esten inactivas
  // sirve para saber cuando el ambiente termino de procesar todo antes de finalizar
  task automatic esperar_fin_actividad();
    int ciclos_estables;

    ciclos_estables = 0;
    while(ciclos_estables < 10) begin
      @(posedge _if.clk);
      // se revisa que no haya nada en vuelo en ningun mailbox y que el DUT este quieto
      if((ambiente_inst.gen_agnt_mbx.num() == 0) &&
         (ambiente_inst.agnt_drv_mbx.num() == 0) &&
         (ambiente_inst.agnt_sb_mbx.num() == 0) &&
         (ambiente_inst.sb_chkr_mbx.num() == 0) &&
         (ambiente_inst.mon_chkr_mbx.num() == 0) &&
         (ambiente_inst.chkr_sb_mbx.num() == 0) &&
         !_if.push && !_if.pop && !_if.rst) begin
        ciclos_estables++;  // un ciclo mas sin actividad
      end else begin
        ciclos_estables = 0;  // hubo actividad, se reinicia el contador
      end
      // se necesitan 10 ciclos consecutivos sin actividad para confirmar que termino
    end
  endtask

  // tarea principal del test, arranca el ambiente y lanza los escenarios
  task run;
    $display("[%g]  El Test fue inicializado",$time);

    // se arranca el ambiente en paralelo con fork..join_none para que no bloquee
    fork
      ambiente_inst.run();
    join_none

    // se leen los plusargs para configurar la prueba
    leer_plusargs();

    // si no se recibieron estos plusargs se usan valores por defecto razonables
    if(!($value$plusargs("RET_SPEC=%d",  plus_ret_spec)))  ambiente_inst.generator_inst.ret_spec  = 3;
    if(!($value$plusargs("TIPO_SPEC=%s", plus_tipo_spec))) ambiente_inst.generator_inst.tpo_spec  = escritura;
    if(!($value$plusargs("DATO_SPEC=%h", plus_dato_spec))) ambiente_inst.generator_inst.dto_spec  = ambiente_inst.generator_inst.patron_dato(1);  // patron 0x5555

    if(run_all) begin
      // se corren todos los escenarios en orden
      correr_escenario(llenado_aleatorio,        "Escenario comun: llenado aleatorio");
      correr_escenario(trans_aleatoria,          "Escenario comun: transaccion aleatoria");
      correr_escenario(trans_especifica,         "Escenario comun: transaccion especifica");
      correr_escenario(sec_trans_aleatorias,     "Escenario comun: secuencia de transacciones aleatorias");
      correr_escenario(eventos_reset_aleatorios, "Escenario comun: eventos de reset aleatorios");
      correr_escenario(patron_max_alternancia,   "Caso de esquina: patron 0-5-A-F con maxima alternancia");
      correr_escenario(provocar_overflow,        "Caso de esquina: overflow");
      correr_escenario(provocar_underflow,       "Caso de esquina: underflow");
      correr_escenario(push_pop_simultaneo_bajo, "Caso de esquina: push-pop simultaneo en nivel bajo");
      correr_escenario(push_pop_simultaneo_medio,"Caso de esquina: push-pop simultaneo en nivel medio");
      correr_escenario(push_pop_simultaneo_alto, "Caso de esquina: push-pop simultaneo en nivel alto");
      correr_escenario(reset_fifo_vacia,         "Caso de esquina: reset con fifo vacia");
      correr_escenario(reset_fifo_media,         "Caso de esquina: reset con fifo a la mitad");
      correr_escenario(reset_fifo_llena,         "Caso de esquina: reset con fifo llena");
    end else if(escenario_valido) begin
      // se corre solo el escenario que se pidio por plusarg
      correr_escenario_plusarg();
    end else begin
      // caso por defecto si no se pidio nada especifico: se corren todos igual que run_all
      correr_escenario(llenado_aleatorio,        "Escenario comun: llenado aleatorio");
      correr_escenario(trans_aleatoria,          "Escenario comun: transaccion aleatoria");
      correr_escenario(trans_especifica,         "Escenario comun: transaccion especifica");
      correr_escenario(sec_trans_aleatorias,     "Escenario comun: secuencia de transacciones aleatorias");
      correr_escenario(eventos_reset_aleatorios, "Escenario comun: eventos de reset aleatorios");
      correr_escenario(patron_max_alternancia,   "Caso de esquina: patron 0-5-A-F con maxima alternancia");
      correr_escenario(provocar_overflow,        "Caso de esquina: overflow");
      correr_escenario(provocar_underflow,       "Caso de esquina: underflow");
      correr_escenario(push_pop_simultaneo_bajo, "Caso de esquina: push-pop simultaneo en nivel bajo");
      correr_escenario(push_pop_simultaneo_medio,"Caso de esquina: push-pop simultaneo en nivel medio");
      correr_escenario(push_pop_simultaneo_alto, "Caso de esquina: push-pop simultaneo en nivel alto");
      correr_escenario(reset_fifo_vacia,         "Caso de esquina: reset con fifo vacia");
      correr_escenario(reset_fifo_media,         "Caso de esquina: reset con fifo a la mitad");
      correr_escenario(reset_fifo_llena,         "Caso de esquina: reset con fifo llena");
    end

    // se espera a que el ambiente termine o a que se acabe el tiempo limite
    // lo que pase primero gana gracias al fork..join_any
    fork
      begin
        esperar_fin_actividad();
        $display("[%g]  Test: La actividad del ambiente finalizo", $time);
      end
      begin
        #(tiempo_prueba);  // temporizador de seguridad para que la simulacion no corra para siempre
        $display("[%g]  Test: Se alcanza el tiempo límite de la prueba",$time);
      end
    join_any
    disable fork;  // se cancela el hilo que no termino primero

    // se le pide al scoreboard que calcule y reporte los resultados finales
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);  // primero que calcule la latencia promedio
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);  // luego que imprima el reporte final
    #20                          // se espera un poco para que el scoreboard alcance a imprimir
    $finish;                     // se termina la simulacion
  endtask
endclass