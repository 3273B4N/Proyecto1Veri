class monitor #(parameter width =16);
  virtual fifo_if #(.width(width)) vif;  // interfaz virtual, conecta el monitor con las señales del DUT
  trans_fifo_mbx mon_chkr_mbx;          // mailbox de salida hacia el checker

  // variables para guardar el estado de las señales
  bit push_prev;
  bit pop_prev;
  bit rst_prev;

  bit reset_inicial_filtrado;  // bandera para ignorar el reset que ocurre al arrancar la simulacion

  task run();
    trans_fifo #(.width(width)) transaction;  // objeto donde se guarda lo que se observo
    $display("[%g]  El monitor fue inicializado",$time);

    // se inicializan los estados previos en 0
    push_prev = 0;
    pop_prev = 0;
    rst_prev = 0;
    reset_inicial_filtrado = 0; 

    forever begin
      @(posedge vif.clk);  // el monitor muestrea en cada flanco de subida del reloj

      // deteccion de flanco de subida en rst
      if(vif.rst && !rst_prev) begin
        if(($time == 0) && !reset_inicial_filtrado) begin
          reset_inicial_filtrado = 1;
          $display("[%g] Monitor: Reset inicial filtrado", $time);
        end else begin
          transaction = new();
          transaction.tipo = reset;
          transaction.tiempo = $time;
          mon_chkr_mbx.put(transaction);
          transaction.print("Monitor: Reset observado");
        end
      end

      // push y pop activos al mismo tiempo en el mismo ciclo
      if(vif.push && !push_prev && vif.pop && !pop_prev) begin
        $display("[%g] Monitor: Lectura y Escritura observadas en el mismo ciclo", $time);

        // se reporta primero la escritura con el dato que entro al FIFO
        transaction = new();
        transaction.tipo = escritura;
        transaction.dato = vif.dato_in;
        transaction.tiempo = $time;
        mon_chkr_mbx.put(transaction);
        transaction.print("Monitor: Escritura observada");

        // luego se reporta la lectura con el dato que salio del FIFO ese mismo ciclo
        transaction = new();
        transaction.tipo = lectura;
        transaction.dato = vif.dato_out;
        transaction.tiempo = $time;
        mon_chkr_mbx.put(transaction);
        transaction.print("Monitor: Lectura observada");

      end else begin
        // push, escritura al FIFO
        if(vif.push && !push_prev) begin
          transaction = new();
          transaction.tipo = escritura;
          transaction.dato = vif.dato_in;  // se captura el dato que el DUT esta recibiendo
          transaction.tiempo = $time;
          mon_chkr_mbx.put(transaction);
          transaction.print("Monitor: Escritura observada");
        end

        //pop, lectura del FIFO
        if(vif.pop && !pop_prev) begin
          transaction = new();
          transaction.tipo = lectura;
          transaction.dato = vif.dato_out;  // se captura el dato que el DUT esta sacando
          transaction.tiempo = $time;
          mon_chkr_mbx.put(transaction);
          transaction.print("Monitor: Lectura observada");
        end
      end

      // se actualizan los estados previos al final del ciclo
      push_prev = vif.push;
      pop_prev = vif.pop;
      rst_prev = vif.rst;
    end
  endtask
endclass
