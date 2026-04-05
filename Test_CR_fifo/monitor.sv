class monitor #(parameter width =16);
    virtual fifo_if #(.width(width))vif;
    trans_fifo_mbx mon_chkr_mbx; // por aqui yo le paso cosas al checker
    bit push_prev;               // aqui guardo el push del ciclo pasado
    bit pop_prev;                // aqui guardo el pop del ciclo pasado
    bit rst_prev;                // aqui guardo el rst del ciclo pasado
    
    task run();
        bit push_evt; // aqui marco cuando push hace flanco de subida
        bit pop_evt;  // aqui marco cuando pop hace flanco de subida
        bit rst_evt;  // aqui marco cuando rst hace flanco de subida

        $display("[%g]  El monitor fue inicializado",$time);
        // yo arranco todo en 0 para empezar limpio
        push_prev = 0;
        pop_prev = 0;
        rst_prev = 0;
        forever begin
            trans_fifo #(.width(width)) transaction;
            @(posedge vif.clk);

            // aqui convierto nivel a evento por flanco, asi no cuento doble.
            push_evt = (vif.push && !push_prev);
            pop_evt  = (vif.pop  && !pop_prev);
            rst_evt  = (vif.rst  && !rst_prev);

            // si detecto reset, lo reporto de una vez
            if(rst_evt) begin
                transaction = new();
                transaction.tipo = reset;
                transaction.tiempo = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de reset ejecutada");
            end

            // si me llegan push y pop juntos en el mismo ciclo
            else if(push_evt && pop_evt) begin
                // primero mando lectura
                transaction = new();
                transaction.tipo = lectura;
                transaction.dato = vif.dato_out;
                transaction.tiempo = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de lectura ejecutada");

                // luego mando escritura
                transaction = new();
                transaction.tipo = escritura;
                transaction.dato = vif.dato_in;
                transaction.tiempo = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de escritura ejecutada");
            end

            // si solo veo pop, reporto lectura
            else if(pop_evt) begin
                transaction = new();
                transaction.tipo = lectura;
                transaction.dato = vif.dato_out;
                transaction.tiempo = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de lectura ejecutada");
            end

            // si solo veo push, reporto escritura
            else if(push_evt) begin
                transaction = new();
                transaction.tipo = escritura;
                transaction.dato = vif.dato_in;
                transaction.tiempo = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de escritura ejecutada");
            end

            // aqui guardo el estado actual para compararlo en el siguiente clk
            push_prev = vif.push;
            pop_prev = vif.pop;
            rst_prev = vif.rst;
        end
    endtask
endclass