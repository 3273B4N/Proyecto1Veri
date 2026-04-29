//////////////////////////////////////////////////////////////////////////////////////////////////
// Agente/Generador: Este bloque se encarga de generar las secuencias de eventos para el driver //
// En este ejemplo se generarán 2 tipos de secuencias:                                          //
//    llenado_vaciado: En esta se genera un número parametrizable de tarnsacciones de lecturas  //
//                     y escrituras para llenar y vaciar la fifo.                               //
//    Aleatoria: En esta se generarán transacciones totalmente aleatorias                       //
//    Específica: en este tipo se generan trasacciones semi específicas para casos esquina      // 
//////////////////////////////////////////////////////////////////////////////////////////////////

class agent #(parameter width = 16, parameter depth = 8);

  // Mailbox hacia el driver (por aquí se envían las transacciones)
  mailbox #(trans_fifo #(width)) agnt_drv_mbx;
  
  // Mailbox desde el test (de aquí vienen las instrucciones)
  comando_test_agent_mbx test_agent_mbx;
  
  // Variables de control
  int num_transacciones; // cantidad de transacciones a generar
  int max_retardo;       // retardo máximo permitido
  int ret_spec;          // retardo específico (modo dirigido)
  tipo_trans tpo_spec;   // tipo de transacción específica
  bit [width-1:0] dto_spec; // dato específico
  
  instrucciones_agente instruccion; // instrucción actual
  trans_fifo #(.width(width)) transaccion; // objeto transacción
  
  // Flags de configuración (activados con plusargs)
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
  
  // Modelo interno del nivel de la FIFO (lleva la cuenta local)
  int nivel_model;
  
  // Constructor (valores iniciales)
  function new;
    num_transacciones = 2; // por defecto genera 2
    max_retardo = 10;      // retardo máximo por defecto
    nivel_model = 0;       // inicia en vacío
  endfunction

    // Actualiza el nivel interno según la transacción generada
  function void actualizar_nivel_model(trans_fifo #(.width(width)) t);
    case (t.tipo)
      escritura: begin // si es escritura aumenta nivel
        if (nivel_model < depth)
          nivel_model++;
      end
      lectura: begin // si es lectura disminuye nivel
        if (nivel_model > 0)
          nivel_model--;
      end
      lectura_escritura: begin // caso simultáneo
        // si está vacía y se permite underflow, se considera que entra un dato
        if (nivel_model == 0 && t.habilitar_underflow)
          nivel_model++;
      end
      reset: begin // reset limpia todo
        nivel_model = 0;
      end
    endcase
    // saturación para no salirse de rango
    if (nivel_model < 0) nivel_model = 0;
    if (nivel_model > depth) nivel_model = depth;
  endfunction

    // Copia toda la configuración actual a la transacción
  function void apply_cfg_to_transaction(ref trans_fifo #(.width(width)) t);
    t.depth_cfg = depth; // profundidad de la FIFO
    t.habilitar_overflow = habilitar_overflow;
    t.habilitar_underflow = habilitar_underflow;
    t.habilitar_patron = habilitar_patron;
    t.habilitar_push_pop = habilitar_push_pop;
    t.habilitar_reset_random = habilitar_reset_random;
    t.habilitar_fifo_full = habilitar_fifo_full;
    t.habilitar_fifo_empty = habilitar_fifo_empty;
    t.habilitar_fifo_mid = habilitar_fifo_mid;
    t.habilitar_reset_full = habilitar_reset_full;
    t.habilitar_reset_empty = habilitar_reset_empty;
    t.habilitar_reset_mid = habilitar_reset_mid;
  endfunction

  // Task principal (se ejecuta durante toda la simulación)
  task run;
    $display("[%g] El Agente fue inicializado",$time); // mensaje inicial
    nivel_model = 0; // inicia en vacío
    forever begin // loop infinito
      #1 // pequeño delay
      if(test_agent_mbx.num() > 0) begin // si hay instrucciones
        $display("[%g] Agente: se recibe instruccion",$time);
        test_agent_mbx.get(instruccion); // se lee la instrucción
        case(instruccion)
  
          // llena la FIFO y luego la vacía
          llenado_aleatorio: begin
            // escrituras
            for(int i = 0; i < num_transacciones; i++) begin
              transaccion = new; // crea objeto
              transaccion.max_retardo = max_retardo; // asigna retardo
              apply_cfg_to_transaction(transaccion); // aplica config
              if(!transaccion.randomize() with {
                // mantiene coherencia con el modelo
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
                tipo == escritura; // fuerza escritura
              })
                $fatal("Error randomizando escritura");
              transaccion.print("Agente: transacción creada"); // debug
              agnt_drv_mbx.put(transaccion); // envía al driver
              actualizar_nivel_model(transaccion); // actualiza modelo
            end
            // lecturas
            for(int i = 0; i < num_transacciones; i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              apply_cfg_to_transaction(transaccion);
              if(!transaccion.randomize() with {
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
                tipo == lectura; // fuerza lectura
              })
                $fatal("Error randomizando lectura");
              transaccion.print("Agente: transacción creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
            end
          end
  
          // una transacción aleatoria
          trans_aleatoria: begin
            transaccion = new;
            transaccion.max_retardo = max_retardo;
            apply_cfg_to_transaction(transaccion);
            // evita conflicto si está vacía y no hay underflow
            if (habilitar_push_pop && !habilitar_underflow && (nivel_model == 0)) begin
              transaccion.habilitar_push_pop = 0; // desactiva simultáneo
              if(!transaccion.randomize() with {
                tipo == escritura; // siembra con escritura
              })
                $fatal("Error siembra");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
              continue; // pasa a siguiente iteración
            end
            if(!transaccion.randomize() with {
              if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                nivel_fifo == nivel_model;
            })
              $fatal("Error random");
            transaccion.print("Agente: transacción creada");
            agnt_drv_mbx.put(transaccion);
            actualizar_nivel_model(transaccion);
          end
  
          // transacciones dirigidas
          trans_especifica: begin
            for(int i = 0; i < num_transacciones; i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              apply_cfg_to_transaction(transaccion);
              // evita leer en vacío sin underflow
              if (((tpo_spec == lectura_escritura) || (tpo_spec == lectura)) && !habilitar_underflow && (nivel_model == 0)) begin
                transaccion.habilitar_push_pop = 0;
                if(!transaccion.randomize() with { tipo == escritura; })
                  $fatal("Error siembra");
                agnt_drv_mbx.put(transaccion);
                actualizar_nivel_model(transaccion);
                transaccion = new; // nueva transacción real
                apply_cfg_to_transaction(transaccion);
              end
              if(!transaccion.randomize() with {
                tipo == tpo_spec;   // tipo definido
                dato == dto_spec;  // dato definido
                retardo == ret_spec; // retardo definido
              })
                $fatal("Error específica");
              transaccion.print("Agente: transacción creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
            end
          end
  
          // varias transacciones aleatorias seguidas
          sec_trans_aleatorias: begin
            for(int i = 0; i < num_transacciones; i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              apply_cfg_to_transaction(transaccion);
              // mismo caso de protección
              if (habilitar_push_pop && !habilitar_underflow && (nivel_model == 0)) begin
                transaccion.habilitar_push_pop = 0;
                if(!transaccion.randomize() with { tipo == escritura; })
                  $fatal("Error siembra");
                agnt_drv_mbx.put(transaccion);
                actualizar_nivel_model(transaccion);
                continue;
              end
              if(!transaccion.randomize())
                $fatal("Error random");
              transaccion.print("Agente: transacción creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
            end
          end
        endcase
      end
    end
  endtask
  endclass
