class driver #(parameter width = 16);
  virtual fifo_if #(.width(width)) vif;  // interfaz virtual, por aqui se manejan las señales del DUT
  trans_fifo_mbx agnt_drv_mbx;          // mailbox de entrada, aqui llegan las transacciones del agente
  int espera;                            // contador para medir cuantos ciclos se ha esperado

  task run();
    $display("[%g]  El driver fue inicializado",$time);

    // se aplica reset al arrancar para dejar el DUT en estado conocido
    vif.rst = 1;
    @(posedge vif.clk);  // se espera un ciclo con reset activo
    vif.rst = 0;         // se suelta el reset, el DUT ya puede operar

    forever begin
      trans_fifo #(.width(width)) transaction;

      // se dejan todas las señales en inactivo mientras se espera la siguiente transaccion
      vif.push    = 0;
      vif.rst     = 0;
      vif.pop     = 0;
      vif.dato_in = 0;

      $display("[%g] el Driver espera por una transacción",$time);
      espera = 0;
      @(posedge vif.clk);             // se espera un ciclo antes de pedir la siguiente transaccion
      agnt_drv_mbx.get(transaction);  // se bloquea hasta que el agente mande algo
      transaction.print("Driver: Transaccion recibida");
      $display("Transacciones pendientes en el mbx agnt_drv = %g", agnt_drv_mbx.num());

      vif.dato_in = transaction.dato;  // se pone el dato en la interfaz desde ya, aunque push no este activo

      // se espera el retardo indicado en la transaccion antes de aplicar el estimulo
      // esto permite simular distancia temporal entre transacciones
      while(espera < transaction.retardo) begin
        @(posedge vif.clk);
        espera = espera + 1;
        vif.dato_in = transaction.dato;  // se mantiene el dato estable durante la espera
      end

      @(negedge vif.clk);  // se cambian las señales en flanco de bajada para que el DUT las muestree en el siguiente flanco de subida

      case(transaction.tipo)

        // lectura: se activa pop un ciclo y luego se suelta
        lectura: begin
          vif.pop = 1;
          transaction.print("Driver: Transaccion ejecutada");
          @(negedge vif.clk);
          vif.pop = 0;
        end

        // escritura: se activa push un ciclo y luego se suelta
        escritura: begin
          vif.push = 1;
          transaction.print("Driver: Transaccion ejecutada");
          @(negedge vif.clk);
          vif.push = 0;
        end

        // reset: se activa rst un ciclo y luego se suelta
        reset: begin
          vif.rst = 1;
          transaction.print("Driver: Transaccion ejecutada");
          @(negedge vif.clk);
          vif.rst = 0;
        end

        // lectura y escritura al mismo tiempo, push y pop activos en el mismo ciclo
        lectura_escritura: begin
          vif.push = 1;
          vif.pop  = 1;
          transaction.print("Driver: Transaccion ejecutada");
          @(negedge vif.clk);
          vif.push = 0;
          vif.pop  = 0;
        end

        default: begin
          $display("[%g] Driver Error: la transacción recibida no tiene tipo valido",$time);
          $finish;
        end

      endcase

      @(negedge vif.clk);  //espera un ciclo extra al final antes de procesar la siguiente transaccion
    end
  endtask
endclass