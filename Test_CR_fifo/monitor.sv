class monitor #(parameter width =16);
    virtual fifo_if #(.width(width))vif;
    trans_fifo_mbx drv_chkr_mbx;
    
    task run_monitor();
        $display("[%g]  El monitor fue inicializado",$time);
        forever begin
            trans_fifo #(.width(width)) transaction;
            @(posedge vif.clk);
            if(vif.pop) begin
                transaction = new();
                transaction.tipo = lectura;
                transaction.dato = vif.dato_out;
                transcation.tiempo = $time;
                drv_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de lectura ejecutada");
            end
            if(vif.push) begin
                transaction = new();
                transaction.tipo = escritura;
                transaction.dato = vif.dato_out;
                transcation.tiempo = $time;
                drv_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de escritura ejecutada");
            end
            if(vif.push & vif.pop) begin
                transaction = new();
                transaction.tipo = escritura_lectura;
                transaction.dato = vif.dato_out;
                transcation.tiempo = $time;
                drv_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de lectura/escritura ejecutada");
            end
            if(vif.rst) begin
                transaction = new();
                transaction.tipo = reset;
                transcation.tiempo = $time;
                drv_chkr_mbx.put(transaction);
                transaction.print("Monitor: Transaccion de reset ejecutada");
            end
        end
    endtask
endclass