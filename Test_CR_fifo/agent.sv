//////////////////////////////////////////////////////////////////////////////////////////////////
// Agente/Generador: Este bloque se encarga de generar las secuencias de eventos para el driver //
// En este ejemplo se generarán 2 tipos de secuencias:                                          //
//    llenado_vaciado: En esta se genera un número parametrizable de tarnsacciones de lecturas  //
//                     y escrituras para llenar y vaciar la fifo.                               //
//    Aleatoria: En esta se generarán transacciones totalmente aleatorias                       //
//    Específica: en este tipo se generan trasacciones semi específicas para casos esquina      // 
//////////////////////////////////////////////////////////////////////////////////////////////////

class agent #(parameter width = 16, parameter depth = 8);
  //trans_fifo_mbx agnt_drv_mbx;  
  mailbox #(trans_fifo #(width)) agnt_drv_mbx; // se declara parametricamente         
  comando_test_agent_mbx test_agent_mbx; 
  int num_transacciones;                 
  int max_retardo;                       
  int ret_spec;                          
  tipo_trans tpo_spec; 
  bit [width-1:0] dto_spec;
  instrucciones_agente instruccion;      
  trans_fifo #(.width(width)) transaccion;

  //banderas para los plusargs
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
  int nivel_model;
   
  function new;
    num_transacciones = 2;
    max_retardo = 10;
    nivel_model = 0;
  endfunction

  // esta función actualiza el nivel del modelo de la fifo para que el agente pueda 
  // generar transacciones acordes al estado del mismo. Se actualiza con cada 
  // transacción generada por el agente, sin embargo, no se actualiza con las transacciones que vienen 
  //  del monitor para evitar retrasos en la generación.
  function void actualizar_nivel_model(trans_fifo #(.width(width)) t);
    case (t.tipo)
      escritura: begin
        if (nivel_model < depth)
          nivel_model++;
      end

      lectura: begin
        if (nivel_model > 0)
          nivel_model--;
      end

      lectura_escritura: begin
        // Modelo alineado al checker, en vacio y simultanea se reporta underflow
        // pero se agrega la escritura a la referencia.
        if (nivel_model == 0 && t.habilitar_underflow)
          nivel_model++;
      end

      reset: begin
        nivel_model = 0;
      end
    endcase

    if (nivel_model < 0)
      nivel_model = 0;
    if (nivel_model > depth)
      nivel_model = depth;
  endfunction


  // esta funcion se encarga de aplicar la configuración de generación a cada transacción para 
  //evitar repetir el mismo bloque de código en cada caso de generación.
  function void apply_cfg_to_transaction(ref trans_fifo #(.width(width)) t);
    t.depth_cfg = depth;

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
      #1
      if(test_agent_mbx.num() > 0)begin
        $display("[%g]  Agente: se recibe instruccion",$time);
        test_agent_mbx.get(instruccion);
        case(instruccion)
          
          llenado_aleatorio: begin
            for(int i = 0; i < num_transacciones;i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;

              apply_cfg_to_transaction(transaccion);


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

          trans_aleatoria: begin
            transaccion = new;
            transaccion.max_retardo = max_retardo;

            apply_cfg_to_transaction(transaccion);

            // Si push+pop esta habilitado pero underflow no, arrancar en vacio
            // genera una contradiccion de constraints. En ese caso, la unica
            // transaccion valida para este comando es una escritura de siembra.
            if (habilitar_push_pop && !habilitar_underflow && (nivel_model == 0)) begin
              transaccion.habilitar_push_pop = 0;
              if(!transaccion.randomize() with {
                if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                  nivel_fifo == nivel_model;
                tipo == escritura;
              })
                $fatal("[%g] Agente ERROR: no se pudo randomizar la escritura de siembra", $time);

              transaccion.print("Agente: transacción de siembra creada");
              agnt_drv_mbx.put(transaccion);
              actualizar_nivel_model(transaccion);
              continue;
            end

            if(!transaccion.randomize() with {
              if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                nivel_fifo == nivel_model;
            })
              $fatal("[%g] Agente ERROR: no se pudo randomizar la transacción aleatoria", $time);

            transaccion.print("Agente: transacción creada");
            agnt_drv_mbx.put(transaccion);
            actualizar_nivel_model(transaccion);
          end

          trans_especifica: begin
            transaccion = new;
            transaccion.max_retardo = max_retardo;

            apply_cfg_to_transaction(transaccion);

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

          sec_trans_aleatorias: begin
            for(int i=0; i<num_transacciones;i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;

              apply_cfg_to_transaction(transaccion);

              // Si push+pop esta habilitado pero underflow no, arrancar en vacio
              // genera una contradiccion de constraints. Se inyecta una sola
              // escritura de siembra y luego continúan las simultáneas.
              if (habilitar_push_pop && !habilitar_underflow && (nivel_model == 0)) begin
                transaccion.habilitar_push_pop = 0;
                if(!transaccion.randomize() with {
                  if (!(habilitar_fifo_full || habilitar_fifo_empty || habilitar_fifo_mid))
                    nivel_fifo == nivel_model;
                  tipo == escritura;
                })
                  $fatal("[%g] Agente ERROR: no se pudo randomizar la escritura de siembra", $time);

                transaccion.print("Agente: transacción de siembra creada");
                agnt_drv_mbx.put(transaccion);
                actualizar_nivel_model(transaccion);
                continue;
              end

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