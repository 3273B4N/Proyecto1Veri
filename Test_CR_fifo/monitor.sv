///////////////////////////////////////////////////////////////////////////////
// monitor.sv
// Monitor: Observa pasivamente la interfaz del DUT y captura el resultado
// real de cada transacción (especialmente dato_out en lecturas).
// Luego envía la transacción completada al checker.
///////////////////////////////////////////////////////////////////////////////
class monitor #(parameter width = 16);
  virtual fifo_if #(.width(width)) vif;

  trans_fifo_mbx drv_mon_mbx;   // Recibe transacciones despachadas por el driver
  trans_fifo_mbx mon_chkr_mbx;  // Envía transacciones observadas al checker

  task run();
    $display("[%0t]  Monitor: inicializado", $time);

    forever begin
      trans_fifo #(.width(width)) transaction;

      // Espera a que el driver haya lanzado una transacción
      drv_mon_mbx.get(transaction);

      #1; 

      case (transaction.tipo)

        lectura: begin
          // El dato de lectura ya fue muestreado por el driver en el instante de lanzamiento.
          transaction.print("Monitor: lectura observada");
        end

        escritura: begin
          // No hay dato de salida que capturar en escritura
          transaction.print("Monitor: escritura observada");
        end

        lectura_escritura: begin
          // Para simultánea, se conserva la muestra tomada por el driver.
          transaction.print("Monitor: lectura y escritura observada");
        end

        reset: begin
          transaction.print("Monitor: reset observado");
        end

        default: begin
          $display("[%0t] Monitor ERROR: tipo de transacción inválido", $time);
          $finish;
        end

      endcase

      // Reenvía al checker con información completa
      mon_chkr_mbx.put(transaction);

    end // forever
  endtask

endclass