////////////////////////////////////////////////////////////////////////////////////////////////////
// Checker: aqui yo verifico que el DUT se comporte como espero //
////////////////////////////////////////////////////////////////////////////////////////////////////

class checker_c #(parameter width=16, parameter depth =8);
  trans_fifo #(.width(width)) transaccion; // aqui guardo la transaccion que me llega
  trans_fifo #(.width(width)) auxiliar; // aqui uso un auxiliar para leer de la fifo emulada
  trans_sb   #(.width(width)) to_sb; // esta transaccion la uso para reportar al scoreboard
  trans_fifo  emul_fifo[$]; // esta cola es mi fifo de referencia (golden)
  trans_fifo_mbx mon_chkr_mbx; // por aqui recibo del monitor
  trans_sb_mbx  chkr_sb_mbx; // por aqui reporto al scoreboard
  int contador_auxiliar; 

  function new();
    this.emul_fifo = {};
    this.contador_auxiliar = 0;
  endfunction 

  task run;
   $display("[%g]  El checker fue inicializado",$time);
   to_sb = new();
   forever begin
     to_sb = new();
     mon_chkr_mbx.get(transaccion);
     transaccion.print("Checker: Se recibe trasacción desde el monitor");
     to_sb.clean();
     case(transaccion.tipo)
       lectura: begin
         if(0 !== emul_fifo.size()) begin // aqui reviso que la fifo de referencia no este vacia
           auxiliar = emul_fifo.pop_front();
           if(transaccion.dato == auxiliar.dato) begin
             to_sb.dato_enviado = auxiliar.dato;
             to_sb.tiempo_push = auxiliar.tiempo;
             to_sb.tiempo_pop = transaccion.tiempo;
             to_sb.completado = 1;
             to_sb.calc_latencia();
             to_sb.print("Checker:Transaccion Completada");
             chkr_sb_mbx.put(to_sb);
           end else begin
             transaccion.print("Checker: Error el dato de la transacción no calza con el esperado");
            $display("Dato_leido= %h, Dato_Esperado = %h",transaccion.dato,auxiliar.dato);
            $finish; 
           end
         end else begin // si esta vacia, para mi esto cuenta como underflow
             to_sb.tiempo_pop = transaccion.tiempo;
             to_sb.underflow = 1;
             to_sb.print("Checker: Underflow");
             chkr_sb_mbx.put(to_sb);
         end
       end
       escritura: begin
         if(emul_fifo.size() == depth)begin // si esta llena y me escriben, marco overflow
           auxiliar = emul_fifo.pop_front();
           to_sb.dato_enviado = auxiliar.dato;
           to_sb.tiempo_push = auxiliar.tiempo;
           to_sb.overflow = 1;
           to_sb.print("Checker: Overflow");
           chkr_sb_mbx.put(to_sb);
           emul_fifo.push_back(transaccion);
         end else begin  // si no esta llena, solo guardo el dato en mi fifo simulada
           transaccion.print("Checker: Escritura");
           emul_fifo.push_back(transaccion);
         end
       end
      lectura_escritura: begin
        
       end
       reset: begin // si llega reset, yo vacio mi fifo y reporto lo que se pierde
         contador_auxiliar = emul_fifo.size();
         for(int i =0; i<contador_auxiliar; i++)begin
           auxiliar = emul_fifo.pop_front();
           to_sb.clean();
           to_sb.dato_enviado = auxiliar.dato;
           to_sb.tiempo_push = auxiliar.tiempo;
           to_sb.reset = 1;
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
