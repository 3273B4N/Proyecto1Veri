///////////////////////////////////////////////////////////////////////////////
// driver.sv
// Driver: Traduce transacciones del agente en estímulos sobre la interfaz
// del DUT. No observa salidas (eso lo hace el monitor).
// CAMBIOS respecto al original:
//   - Separado del monitor: ya NO lee dato_out ni envía al checker.
//   - Soporta el tipo 'simultaneo' (push y pop en el mismo ciclo).
//   - Envía la transacción ejecutada al monitor mediante drv_mon_mbx.
///////////////////////////////////////////////////////////////////////////////
class driver #(parameter width = 16);
  virtual fifo_if #(.width(width)) vif;

  trans_fifo_mbx agnt_drv_mbx;  // Recibe transacciones del agente
  trans_fifo_mbx drv_mon_mbx;   // Envía transacciones ejecutadas al monitor

  int espera;

  task run();
    $display("[%0t]  Driver: inicializado", $time);
    // Reset inicial de dos ciclos
    vif.rst    = 1;
    vif.push   = 0;
    vif.pop    = 0;
    vif.dato_in = 0;
    @(posedge vif.clk);
    @(posedge vif.clk);
    vif.rst = 0;

    forever begin
      trans_fifo #(.width(width)) transaction;

      // Pone las señales en reposo al inicio de cada ciclo
      @(posedge vif.clk);
      vif.push    = 0;
      vif.pop     = 0;
      vif.rst     = 0;
      vif.dato_in = 0;

      $display("[%0t] Driver: esperando transacción (mbx=%0d pendientes)",
               $time, agnt_drv_mbx.num());
      agnt_drv_mbx.get(transaction);
      transaction.print("Driver: transacción recibida");

      // Aplica retardo solicitado por la transacción
      espera = 0;
      while (espera < transaction.retardo) begin
        @(posedge vif.clk);
        espera++;
      end

      // Aplica la transacción sobre la interfaz
      case (transaction.tipo)

        escritura: begin
          vif.dato_in          = transaction.dato;
          vif.push             = 1;
          transaction.tiempo   = $time;
          transaction.print("Driver: escritura aplicada");
        end

        lectura: begin
          vif.pop              = 1;
          transaction.tiempo   = $time;
          transaction.print("Driver: lectura aplicada");
        end

        lectura_escritura: begin
          // Push y pop en el mismo ciclo de reloj
          vif.dato_in          = transaction.dato;
          vif.push             = 1;
          vif.pop              = 1;
          transaction.tiempo   = $time;
          transaction.print("Driver: push+pop simultáneo aplicado");
        end

        reset: begin
          vif.rst              = 1;
          transaction.tiempo   = $time;
          transaction.print("Driver: reset aplicado");
        end

        default: begin
          $display("[%0t] Driver ERROR: tipo de transacción inválido", $time);
          $finish;
        end

      endcase

      // Notifica al monitor que la transacción fue lanzada
      drv_mon_mbx.put(transaction);

    end // forever
  endtask

endclass