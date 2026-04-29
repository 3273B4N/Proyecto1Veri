//////////////////////////////////////////////////////////////////////////////////////////////////
// Agente/Generador: Este bloque se encarga de generar las secuencias de eventos para el driver //
// En este ejemplo se generarán 2 tipos de secuencias:                                          //
//    llenado_vaciado: En esta se genera un número parametrizable de tarnsacciones de lecturas  //
//                     y escrituras para llenar y vaciar la fifo.                               //
//    Aleatoria: En esta se generarán transacciones totalmente aleatorias                       //
//    Específica: en este tipo se generan trasacciones semi específicas para casos esquina      // 
//////////////////////////////////////////////////////////////////////////////////////////////////

class agent #(parameter width = 16, parameter depth = 8);
  mailbox #(trans_fifo #(width)) agnt_drv_mbx; // canal de comunicación hacia el driver, tipado con la transacción parametrizada
  comando_test_agent_mbx test_agent_mbx;        // mailbox para recibir instrucciones desde el test
  int num_transacciones;                        // cuántas transacciones se generan por instrucción
  int max_retardo;                              // retardo máximo permitido entre transacciones
  int ret_spec;                                 // retardo fijo para transacciones específicas
  tipo_trans tpo_spec;                          // tipo de transacción para el modo específico
  bit [width-1:0] dto_spec;                     // dato a usar en transacciones específicas
  instrucciones_agente instruccion;             // instrucción recibida desde el test
  trans_fifo #(.width(width)) transaccion;      // objeto de transacción que se genera y envía

  // flags que habilitan condiciones de borde según los plusargs recibidos en simulación
  bit habilitar_overflow;
  bit habilitar_underflow;
  bit habilitar_patron;
  bit habilitar_push_pop;
  bit habilitar_reset_random;

  // controlan en qué estado de la fifo puede generarse cada transacción
  bit habilitar_fifo_full;
  bit habilitar_fifo_empty;
  bit habilitar_fifo_mid;

  // condiciones de reset según el nivel de la fifo
  bit habilitar_reset_full;
  bit habilitar_reset_empty;
  bit habilitar_reset_mid;
  int nivel_model;  // nivel interno del modelo de la fifo, usado para guiar la randomización
   
  function new;
    num_transacciones = 2;  // valor por defecto
    max_retardo = 10;       // valor por defecto
    nivel_model = 0;        // la fifo arranca vacía
  endfunction

  // actualiza el nivel del modelo de la fifo después de cada transacción generada.
  // esto permite que el agente sepa en qué estado está la fifo para randomizar correctamente.
  // no se actualiza con transacciones del monitor para no introducir latencia en la generación.
  function void actualizar_nivel_model(trans_fifo #(.width(width)) t);
    case (t.tipo)
      escritura: begin
        if (nivel_model < depth)
          nivel_model++;       // solo se incrementa si hay espacio
      end

      lectura: begin
        if (nivel_model > 0)
          nivel_model--;       // solo se decrementa si hay datos
      end

      lectura_escritura: begin
        // cuando ocurre una operación simultánea con la fifo vacía y underflow habilitado,
        // igual se cuenta la escritura aunque el dato leído sea inválido
        if (nivel_model == 0 && t.habilitar_underflow)
          nivel_model++;
      end

      reset: begin
        nivel_model = 0;       // el reset deja la fifo vacía
      end
    endcase

    // clamp para evitar que el modelo se salga del rango válido
    if (nivel_model < 0)
      nivel_model = 0;
    if (nivel_model > depth)
      nivel_model = depth;
  endfunction


  // aplica la configuración global del agente a una transacción antes de randomizarla.
  // centraliza la asignación para no repetir este bloque en cada caso del run.
  function void apply_cfg_to_transaction(ref trans_fifo #(.width(width)) t);
    t.depth_cfg = depth;  // le indica a la transacción la profundidad de la fifo

    // se copian todos los flags al objeto de transacción para que sus constraints los vean
    t.habilitar_overflow = habilitar_overflow;
    t.habilitar_underflow = habilitar_underflow;
    t.habilitar_patron = habilitar_patron;
    t.habilitar_push_pop = habilitar_push_pop;
    t.habilitar_reset_random = habilitar_reset_random;

    t.habilitar_fifo_full  = habilitar_fifo_full;
    t.habilitar_fifo_empty = habilitar_fifo_empty;
    t.habilitar_fifo_mid   = habilitar_fifo_mid;

    t.habilitar_reset_full  = habilitar_reset_full;
    t.habilitar_reset_empty = habilitar_reset_empty;
    t.habilitar_reset_mid   = habilitar_reset_mid;
  endfunction

  task run;
    $display("[%g]  El Agente fue inicializado",$time);
    nivel_model = 0;
    forever begin
      #1  // pequeño delta para no bloquear la simulación
      if(test_agent_mbx.num() > 0)begin   // solo actúa si hay una instrucción pendiente
        $display("[%g]  Agente: se recibe instruccion",$time);
        test_agent_mbx.get(instruccion);
        case(instruccion)
          
          // genera num_transacciones escrituras seguidas de num_transacciones lecturas
          llenado_aleatorio: begin
            for(int i = 0; i < num_transacciones;i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              apply_cfg_to_transaction(transaccion);

              // fuerza solo escrituras; si no hay flags de nivel activos, el nivel debe coincidir con el modelo
              if(!transaccion.randomize() with {
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
                tipo == escritura;
              })
                $fatal("[%g] Agente ERROR: no se pudo randomizar la transacción de llenado de escrituras", $time);

              transaccion.print("Agente: transacción creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
            end
            for(int i=0; i<num_transacciones;i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              apply_cfg_to_transaction(transaccion);

              // ahora solo lecturas para vaciar lo que se llenó arriba
              if(!transaccion.randomize() with {
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
                tipo == lectura;
              })
                $fatal("[%g] Agente ERROR: no se pudo randomizar la transacción de llenado de lecturas", $time);

              transaccion.print("Agente: transacción creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
            end
          end

          // genera una sola transacción completamente aleatoria
          trans_aleatoria: begin
            transaccion = new;
            transaccion.max_retardo = max_retardo;
            apply_cfg_to_transaction(transaccion);

            // si push_pop está activo pero underflow no, hacer lectura con la fifo vacía
            // causaría una contradicción de constraints. Se inyecta una escritura de siembra primero.
            if (habilitar_push_pop && !habilitar_underflow && (nivel_model == 0)) begin
              transaccion.habilitar_push_pop = 0;  // deshabilita temporalmente push_pop para la siembra
              if(!transaccion.randomize() with {
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
                tipo == escritura;
              })
                $fatal("[%g] Agente ERROR: no se pudo randomizar la escritura de siembra", $time);

              transaccion.print("Agente: transacción de siembra creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
              continue;  // vuelve al inicio del forever para esperar la siguiente instrucción
            end

            // randomización libre, solo se ancla el nivel si no hay flags de nivel activos
            if(!transaccion.randomize() with {
              if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                nivel_fifo == nivel_model;
            })
              $fatal("[%g] Agente ERROR: no se pudo randomizar la transacción aleatoria", $time);

            transaccion.print("Agente: transacción creada");
            agnt_drv_mbx.put(transaccion);
            actualizar_nivel_model(transaccion);
          end

          // genera num_transacciones del tipo, dato y retardo indicados
          trans_especifica: begin
            for(int i=0; i<num_transacciones; i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              apply_cfg_to_transaction(transaccion);

              // si el tipo pedido es lectura o simultánea y la fifo está vacía sin underflow habilitado,
              // se inyecta una escritura de "siembra" para evitar la contradicción de constraints
              if (((tpo_spec == lectura_escritura) || (tpo_spec == lectura)) && !habilitar_underflow && (nivel_model == 0)) begin
                transaccion.habilitar_push_pop = 0;
                if(!transaccion.randomize() with {
                  if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                    nivel_fifo == nivel_model;
                  tipo == escritura;
                })
                  $fatal("[%g] Agente ERROR: no se pudo randomizar la escritura", $time);

                transaccion.print("Agente: transacción de siembra creada");
                agnt_drv_mbx.put(transaccion);
                actualizar_nivel_model(transaccion);

                // se crea un nuevo objeto para la transacción específica real
                transaccion = new;
                transaccion.max_retardo = max_retardo;
                apply_cfg_to_transaction(transaccion);
              end

              // se fijan tipo, dato y retardo según la configuración recibida del test
              if(!transaccion.randomize() with {
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
                tipo == tpo_spec;
                dato == dto_spec;
                retardo == ret_spec;
              })
                $fatal("[%g] Agente ERROR: no se pudo randomizar la transacción específica", $time);

              transaccion.print("Agente: transacción creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
            end
          end

          // genera una secuencia de num_transacciones transacciones aleatorias en serie
          sec_trans_aleatorias: begin
            for(int i=0; i<num_transacciones;i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              apply_cfg_to_transaction(transaccion);

              // mismo manejo de siembra que en trans_aleatoria: si push_pop activo,
              // underflow inactivo y fifo vacía, se mete una escritura antes de continuar
              if (habilitar_push_pop && !habilitar_underflow && (nivel_model == 0)) begin
                transaccion.habilitar_push_pop = 0;
                if(!transaccion.randomize() with {
                  if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                    nivel_fifo == nivel_model;
                  tipo == escritura;
                })
                  $fatal("[%g] Agente ERROR: no se pudo randomizar la escritura", $time);

                transaccion.print("Agente: transacción de siembra creada");
                agnt_drv_mbx.put(transaccion);
                actualizar_nivel_model(transaccion);
                continue;  // sigue con la siguiente iteración del for
              end

              // transacción aleatoria normal dentro de la secuencia
              if(!transaccion.randomize() with {
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
              })
                $fatal("[%g] Agente ERROR: no se pudo randomizar la transacción aleatoria", $time);
            
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
