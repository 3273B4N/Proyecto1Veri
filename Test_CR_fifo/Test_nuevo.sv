///////////////////////////////////////////////////////////////////////////////
// TEST_NUEVO
// aqui yo junto varios tests de la FIFO usando herencia.
// la idea es correr casos puntuales sin estar tocando todo el bench.
//
// plusargs que yo puedo usar:
//   +TEST=<nombre>       elijo que test correr desde test_bench.sv
//   +NUM_TRANS=<N>       fuerzo la cantidad de transacciones
//   +MAX_RETARDO=<N>     fuerzo el retardo maximo
///////////////////////////////////////////////////////////////////////////////

class test_base #(parameter width = 16, parameter depth = 8);

  ambiente #(.depth(depth), .width(width)) ambiente_inst;
  virtual fifo_if #(.width(width)) vif;

  // estos mailbox los conecto al ambiente
  comando_test_sb_mbx    test_sb_mbx;
  comando_test_agent_mbx test_agent_mbx;

  // estos parametros arrancan random, pero los puedo fijar con plusargs.
  rand int retardo;
  rand int num_transacciones;

  constraint retardo_c           { retardo           inside {[1:10]};  }
  constraint num_transacciones_c { num_transacciones inside {[2:20]};  }

  // constructor base.
  function new(virtual fifo_if #(.width(width)) _if);
    this.vif       = _if;
    test_sb_mbx    = new();
    test_agent_mbx = new();

    ambiente_inst  = new();

    // aqui paso la interfaz al ambiente y de ahi la agarran driver/monitor.
    ambiente_inst._if = _if;

    // aqui reemplazo mailboxes internos para mandar comandos directo.
    ambiente_inst.test_sb_mbx                 = test_sb_mbx;
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;
    ambiente_inst.test_agent_mbx              = test_agent_mbx;
    ambiente_inst.agent_inst.test_agent_mbx   = test_agent_mbx;

    // valores por defecto para no arrancar en cero.
    ambiente_inst.agent_inst.num_transacciones     = 10;
    ambiente_inst.agent_inst.max_retardo           = 4;
    ambiente_inst.agent_inst.generator_inst = new();
  endfunction

  // si vienen plusargs, se respetan y desactivo el constraint de ese campo.
  function void aplicar_plusargs();
    int val;
    if ($value$plusargs("NUM_TRANS=%d", val)) begin
      num_transacciones_c.constraint_mode(0); // desactiva constraint
      num_transacciones = val;
      $display("[%0t] Plusarg: NUM_TRANS=%0d (constraint desactivado)", $time, val);
    end
    if ($value$plusargs("MAX_RETARDO=%d", val)) begin
      retardo_c.constraint_mode(0);           // desactiva constraint
      retardo = val;
      $display("[%0t] Plusarg: MAX_RETARDO=%0d (constraint desactivado)", $time, val);
    end
  endfunction

  // aqui corro el ambiente, mando instruccion y al final pido reporte.
  protected task ejecutar(instrucciones_agente instr_agente);
    instrucciones_agente ia;
    solicitud_sb         orden_sb;

    // aqui le paso al agente los parametros finales de este test.
    ambiente_inst.agent_inst.num_transacciones     = num_transacciones;
    ambiente_inst.agent_inst.max_retardo           = retardo;

    fork
      ambiente_inst.run();
    join_none

    ia = instr_agente;
    test_agent_mbx.put(ia);
    $display("[%0t]  %s: instrucción '%s' enviada | num_trans=%0d max_ret=%0d",
             $time, get_nombre(), ia.name(), num_transacciones, retardo);

    // aqui espero un rato para que termine el trafico.
    #(num_transacciones * retardo * 10 + 500);

    // aqui pido metricas al scoreboard.
    orden_sb = retardo_promedio;
    test_sb_mbx.put(orden_sb);
    orden_sb = reporte;
    test_sb_mbx.put(orden_sb);
    #20;
    $finish;
  endtask

  virtual function string get_nombre();
    return "test_base";
  endfunction

  // run por defecto: yo corro llenado_aleatorio.
  virtual task run;
    $display("[%0t]  El Test base (llenado_aleatorio) fue inicializado", $time);
    this.randomize();
    aplicar_plusargs();
    ejecutar(llenado_aleatorio);
  endtask

endclass


// este es un caso simple: una transaccion aleatoria.
class test_trans_aleatoria #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_trans_aleatoria"; endfunction
  virtual task run;
    $display("[%0t]  El Test de transacción aleatoria fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_aleatoria);
  endtask
endclass


// este es dirigido: transaccion especifica con dato/retardo definidos.
class test_trans_especifica #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  int        ret_spec = 3;
  tipo_trans tpo_spec = escritura;
  bit [width-1:0] dto_spec = {(width/4){4'h5}};

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_trans_especifica"; endfunction
  virtual task run;
    $display("[%0t]  El Test de transacción específica fue inicializado", $time);
    this.randomize(); aplicar_plusargs();
    ambiente_inst.agent_inst.ret_spec     = ret_spec;
    ambiente_inst.agent_inst.tpo_spec     = tpo_spec;
    ambiente_inst.agent_inst.dto_spec     = dto_spec;
    ejecutar(trans_especifica);
  endtask
endclass


// aqui pruebo push y pop al mismo tiempo.
class test_trans_lectura_escritura #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_trans_lectura_escritura"; endfunction
  virtual task run;
    $display("[%0t]  El Test de lectura/escritura simultánea fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_lectura_escritura);
  endtask
endclass


// aqui pruebo patron 0/5/A/F para alternancia de datos.
class test_intercalado #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_intercalado"; endfunction
  virtual task run;
    $display("[%0t]  El Test de llenado intercalado (0/5/A/F) fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_pattern_0_5_A_F);
  endtask
endclass


// aqui pruebo overflow.
class test_overflow #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_overflow"; endfunction
  virtual task run;
    $display("[%0t]  El Test de overflow fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_overflow);
  endtask
endclass


// aqui pruebo underflow.
class test_underflow #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_underflow"; endfunction
  virtual task run;
    $display("[%0t]  El Test de underflow fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_underflow);
  endtask
endclass


// aqui pruebo pop/push con ocupacion baja.
class test_pop_push_bajo #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  constraint num_transacciones_c { num_transacciones inside {[2:4]}; }

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_pop_push_bajo"; endfunction
  virtual task run;
    $display("[%0t]  El Test de pop/push bajo fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_poppush_bajo);
  endtask
endclass


// aqui pruebo pop/push con ocupacion media.
class test_pop_push_medio #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  constraint num_transacciones_c { num_transacciones inside {[4:6]}; }

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_pop_push_medio"; endfunction
  virtual task run;
    $display("[%0t]  El Test de pop/push medio fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_poppush_medio);
  endtask
endclass


// aqui pruebo pop/push con ocupacion alta.
class test_pop_push_alto #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  constraint num_transacciones_c { num_transacciones inside {[6:10]}; }

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_pop_push_alto"; endfunction
  virtual task run;
    $display("[%0t]  El Test de pop/push alto fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(trans_poppush_alto);
  endtask
endclass


// aqui meto reset con la fifo llena.
class test_reset_full #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_reset_full"; endfunction
  virtual task run;
    $display("[%0t]  El Test de reset con FIFO llena fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(reset_full_aleatorio);
  endtask
endclass


// aqui meto reset con la fifo vacia.
class test_reset_empty #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_reset_empty"; endfunction
  virtual task run;
    $display("[%0t]  El Test de reset con FIFO vacía fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(reset_empty_aleatorio);
  endtask
endclass


// aqui meto reset con la fifo a la mitad.
class test_reset_half #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_reset_half"; endfunction
  virtual task run;
    $display("[%0t]  El Test de reset con FIFO a la mitad fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(reset_half_aleatorio);
  endtask
endclass


// aqui corro una secuencia aleatoria general.
class test_secuencia_aleatoria #(parameter width = 16, parameter depth = 8)
  extends test_base #(.width(width), .depth(depth));

  function new(virtual fifo_if #(.width(width)) _if);
    super.new(_if);
  endfunction
  virtual function string get_nombre(); return "test_secuencia_aleatoria"; endfunction
  virtual task run;
    $display("[%0t]  El Test de secuencia aleatoria fue inicializado", $time);
    this.randomize(); aplicar_plusargs(); ejecutar(sec_trans_aleatorias);
  endtask
endclass