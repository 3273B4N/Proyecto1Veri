////////////////////////////////////////////////////////////////////////////////////////////////////
// Checker/scoreboard: este objeto es responsable de verificar que el comportamiento del DUT sea el esperado //
////////////////////////////////////////////////////////////////////////////////////////////////////

class checker_c #(parameter width=16, parameter depth =8);
  trans_fifo #(.width(width)) transaccion; // transacción recibida desde el monitor
  trans_fifo #(.width(width)) auxiliar;    // se usa para extraer y comparar datos de la fifo emulada
  trans_sb   #(.width(width)) to_sb;       // empaqueta el resultado para enviarlo al scoreboard
  trans_fifo #(width) emul_fifo[$];        // cola que actúa como modelo de referencia (golden) de la fifo
  mailbox #(trans_fifo #(width)) drv_chkr_mbx; // recibe las transacciones observadas por el monitor
  mailbox #(trans_sb   #(width)) chkr_sb_mbx;  // envía los resultados verificados al scoreboard
  int contador_auxiliar; 

  function new();
    this.emul_fifo = {};       // la fifo emulada arranca vacía
    this.contador_auxiliar = 0;
  endfunction 

  task run;
    $display("[%g]  El checker fue inicializado",$time);
    to_sb = new();
    forever begin
      to_sb = new();
      drv_chkr_mbx.get(transaccion);  // bloquea hasta recibir una transacción del monitor
      transaccion.print("Checker: Se recibe trasacción desde el driver");
      to_sb.clean();
      case(transaccion.tipo)

        lectura: begin
          if(0 !== emul_fifo.size()) begin // la fifo tiene datos, lectura válida
            auxiliar = emul_fifo.pop_front();
            if(transaccion.dato_pop == auxiliar.dato) begin // el dato leído del DUT coincide con el modelo
              to_sb.dato_enviado = auxiliar.dato;
              to_sb.tiempo_push  = auxiliar.tiempo;
              to_sb.tiempo_pop   = transaccion.tiempo;
              to_sb.completado   = 1;
              to_sb.calc_latencia();
              to_sb.print("Checker:Transaccion Completada");
              chkr_sb_mbx.put(to_sb);
            end else begin // el dato no coincide, el DUT tiene un error
              transaccion.print("Checker: Error el dato de la transacción no calza con el esperado");
              $display("Dato_leido= %h, Dato_Esperado = %h",transaccion.dato_pop,auxiliar.dato);
              $finish; 
            end
          end else begin // fifo vacía, la lectura genera underflow
            to_sb.tiempo_pop = transaccion.tiempo;
            to_sb.underflow  = 1;
            to_sb.print("Checker: Underflow");
            chkr_sb_mbx.put(to_sb);
          end
        end

        // operación simultánea de lectura y escritura en el mismo ciclo.
        // el orden de operaciones importa: primero se verifica y extrae el dato más antiguo (pop),
        // y luego se inserta el dato nuevo (push). esto refleja el comportamiento real del DUT
        // donde ambas operaciones ocurren en el mismo flanco de reloj.
        lectura_escritura: begin
          if(0 !== emul_fifo.size()) begin // hay datos disponibles para leer
            auxiliar = emul_fifo.pop_front(); // se saca el dato más antiguo para comparar
            if(transaccion.dato_pop == auxiliar.dato) begin // el dato leído coincide con el modelo
              to_sb.dato_enviado = auxiliar.dato;
              to_sb.tiempo_push  = auxiliar.tiempo;
              to_sb.tiempo_pop   = transaccion.tiempo;
              to_sb.completado   = 1;
              to_sb.calc_latencia();
              to_sb.print("Checker: Lectura en transaccion simultanea completada");
              chkr_sb_mbx.put(to_sb);
            end else begin // el dato leído no coincide, error en el DUT
              transaccion.print("Checker: Error en lectura de transaccion simultanea");
              $display("Dato_leido= %h, Dato_Esperado = %h",transaccion.dato_pop,auxiliar.dato);
              $finish;
            end
          end else begin
            // fifo vacía al momento de la operación simultánea: la lectura genera underflow
            // pero la escritura igual se procesa después de este bloque, el dato entra a la fifo
            to_sb.tiempo_pop = transaccion.tiempo;
            to_sb.underflow  = 1;
            to_sb.print("Checker: Underflow en transaccion simultanea");
            chkr_sb_mbx.put(to_sb);
          end
          // el push siempre ocurre independientemente de si hubo underflow o no.
          // esto es consistente con el agente: en lectura_escritura con underflow,
          // igual se incrementa nivel_model porque la escritura sí se efectúa.
          emul_fifo.push_back(transaccion);
        end

        escritura: begin
          if(emul_fifo.size() == depth) begin // fifo llena, la escritura genera overflow
            // se desecha el dato más antiguo y se reporta el overflow al scoreboard
            auxiliar = emul_fifo.pop_front();
            to_sb.dato_enviado = auxiliar.dato;
            to_sb.tiempo_push  = auxiliar.tiempo;
            to_sb.overflow     = 1;
            to_sb.print("Checker: Overflow");
            chkr_sb_mbx.put(to_sb);
            emul_fifo.push_back(transaccion); // el dato nuevo entra igual, desplazando al más antiguo
          end else begin // hay espacio, escritura normal
            transaccion.print("Checker: Escritura");
            emul_fifo.push_back(transaccion);
          end
        end

        reset: begin
          // se vacía la fifo emulada y cada dato perdido se reporta al scoreboard con la flag de reset
          contador_auxiliar = emul_fifo.size();
          for(int i = 0; i < contador_auxiliar; i++) begin
            auxiliar = emul_fifo.pop_front();
            to_sb.clean();
            to_sb.dato_enviado = auxiliar.dato;
            to_sb.tiempo_push  = auxiliar.tiempo;
            to_sb.reset        = 1;
            to_sb.print("Checker: Reset");
            chkr_sb_mbx.put(to_sb);
          end
        end

        default: begin
          $display("[%g] Checker Error: la transacción recibida no tiene tipo valido",$time);
          $finish;
        end

      endcase    
    end 
  endtask
endclass
