//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Scoreboard: Este objeto se encarga de llevar un estado del comportamiento de la prueba y es capa de generar reportes //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class score_board #(parameter width=16);
  mailbox #(trans_sb #(width)) chkr_sb_mbx; // se decalara parametricamente
  comando_test_sb_mbx test_sb_mbx;
  trans_fifo #(.width(width)) transaccion_esperada;
  trans_sb #(.width(width))transaccion_entrante; 

  trans_sb #(width) scoreboard[$]; // esta es la estructura dinámica que maneja el scoreboard  declarada parametricamente
  trans_sb #(width) auxiliar_array[$]; // estructura auxiliar usada para explorar el scoreboard declarada parametricamente
  trans_sb #(width) auxiliar_trans;
  shortreal retardo_promedio;
  solicitud_sb orden;
  int tamano_sb = 0;
  int transacciones_completadas =0;
  int retardo_total = 0;
  
  task run;
    $display("[%g] El Score Board fue inicializado",$time);
    forever begin
      #5
      if(agnt_sb_mbx.num()>0)begin
        agnt_sb_mbx.get(transaccion_esperada);
        transaccion_esperada.print("Score Board: transaccion esperada recibida desde el agente");
        sb_chkr_mbx.put(transaccion_esperada);
      end

      if(chkr_sb_mbx.num()>0)begin
        chkr_sb_mbx.get(transaccion_entrante);
        transaccion_entrante.print("Score Board: transacción recibida desde el checker");
        if(transaccion_entrante.completado) begin
          retardo_total = retardo_total + transaccion_entrante.latencia;
          transacciones_completadas++;
        end
        scoreboard.push_back(transaccion_entrante);
      end else begin
        if(test_sb_mbx.num()>0)begin
          test_sb_mbx.get(orden);
          case(orden)
            retardo_promedio: begin
              $display("Score Board: Recibida Orden Retardo_Promedio");
              // se calcula el retardo promedio a partir de las transacciones completadas. 
              //Si no hay transacciones completadas, se reporta un promedio de 0 y se 
              //indica que el promedio no es aplicable.
              if (transacciones_completadas > 0) begin
                // Fuerza division real para evitar truncamiento entero.
                retardo_promedio = shortreal'(retardo_total) / shortreal'(transacciones_completadas);
                $display("[%g] Score board: el retardo promedio es: %0.3f", $time, retardo_promedio);
              end else begin
                retardo_promedio = 0.0;
                $display("[%g] Score board: no hay transacciones completadas; promedio N/A", $time);
              end
            end
            $display("[%g] Score board: el retardo promedio es: %0.3f", $time, retardo_promedio);
          end
          reporte: begin
            $display("Score Board: Recibida Orden Reporte");
            tamano_sb = this.scoreboard.size();
            for(int i=0;i<tamano_sb;i++) begin
              auxiliar_trans = scoreboard.pop_front;
              auxiliar_trans.print("SB_Report:");
              auxiliar_array.push_back(auxiliar_trans);
            end
            scoreboard = auxiliar_array;
          end
        endcase
      end
    end
  endtask
  
endclass
