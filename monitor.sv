class monitor #(parameter width = 16);
  virtual fifo_if #(.width(width)) vif; // interfaz virtual para leer señales del DUT sin manejarlas

  mailbox #(trans_fifo #(width)) drv_mon_mbx;  // recibe del driver la transacción que acaba de aplicarse
  mailbox #(trans_fifo #(width)) mon_chkr_mbx; // envía al checker la transacción con dato_pop ya capturado

  task run();
    $display("[%0t]  Monitor: inicializado", $time);
    forever begin
      trans_fifo #(.width(width)) transaction;

      // el monitor no genera nada por cuenta propia; espera a que el driver
      // confirme que ya aplicó la transacción al DUT antes de muestrear
      drv_mon_mbx.get(transaction);

      #1; // pequeño delta para asegurar que las señales del DUT ya se estabilizaron

      case (transaction.tipo)

        lectura: begin
          // se verifica que pop haya estado activo antes de tomar dato_out;
          // si el driver no llegó a hacer pop (por ejemplo por un retardo), no hay dato válido
          if (vif.pop)
            transaction.dato_pop = vif.dato_out;
          else
            transaction.dato_pop = '0;
          transaction.print("Monitor: lectura observada");
        end

        escritura: begin
          // en escritura no sale ningún dato por dato_out, no hay nada que muestrear
          transaction.print("Monitor: escritura observada");
        end

        lectura_escritura: begin
          // igual que en lectura simple: se muestrea dato_out solo si pop estuvo activo.
          // el push ocurre en el mismo ciclo pero no requiere muestreo adicional
          if (vif.pop)
            transaction.dato_pop = vif.dato_out;
          else
            transaction.dato_pop = '0;
          transaction.print("Monitor: lectura y escritura observada");
        end

        reset: begin
          // el reset no produce dato_out, solo se reenvía la transacción para que
          // el checker pueda vaciar su fifo emulada
          transaction.print("Monitor: reset observado");
        end

        default: begin
          $display("[%0t] Monitor ERROR: tipo de transacción inválido", $time);
          $finish;
        end

      endcase

      // se reenvía la misma transacción al checker, ahora con dato_pop completado.
      // el checker usará ese valor para compararlo contra su modelo de referencia
      mon_chkr_mbx.put(transaction);

    end // forever
  endtask
endclass
