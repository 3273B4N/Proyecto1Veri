class agent #(parameter width = 16, parameter depth = 8);
  trans_fifo_mbx agnt_drv_mbx;           // por aqui yo mando transacciones al driver
  comando_test_agent_mbx test_agent_mbx; // por aqui me llegan ordenes desde el test
  int num_transacciones;                 // cuantas transacciones quiero generar en escenarios secuenciales
  int max_retardo;                       // tope de retardo cuando uso aleatoriedad
  int ret_spec;                          // retardo fijo para la transaccion especifica
  tipo_trans tpo_spec; 
  bit [width-1:0] dto_spec;
  instrucciones_agente instruccion;      // aqui guardo la ultima instruccion que leo
  generator #(.width(width), .depth(depth)) generator_inst;
   
  function new;
    num_transacciones = 2;
    max_retardo = 10;
    generator_inst = new();
  endfunction

  task run;
    $display("[%g]  El Agente fue inicializado",$time);
    forever begin
      #1
      if(test_agent_mbx.num() > 0)begin
        $display("[%g]  Agente: se recibe instruccion",$time);
        test_agent_mbx.get(instruccion);
        case(instruccion)
          // en esta instruccion yo lleno y luego vacio: N escrituras y N lecturas
          llenado_aleatorio: begin
            generator_inst.gen_llenado_aleatorio(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui solo genero una transaccion random
          trans_aleatoria: begin
            generator_inst.gen_trans_aleatoria(agnt_drv_mbx, max_retardo);
          end

          // aqui genero una transaccion dirigida con tipo, dato y retardo que yo ya tengo configurados
          trans_especifica: begin
            generator_inst.gen_trans_especifica(agnt_drv_mbx, tpo_spec, dto_spec, ret_spec);
          end

          // aqui mando una secuencia de varias transacciones aleatorias
          sec_trans_aleatorias: begin
            generator_inst.gen_sec_trans_aleatorias(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui pruebo push y pop al mismo tiempo
          trans_lectura_escritura: begin
            generator_inst.gen_trans_lectura_escritura(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui fuerzo el patron 0,5,A,F para alternar datos fuerte
          trans_pattern_0_5_A_F: begin
            generator_inst.gen_trans_pattern_0_5_A_F(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui meto mas escrituras de las que aguanta la fifo para provocar overflow
          trans_overflow: begin
            generator_inst.gen_trans_overflow(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui meto lecturas de mas para provocar underflow
          trans_underflow: begin
            generator_inst.gen_trans_underflow(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui pruebo pop/push con ocupacion baja 
          trans_poppush_bajo: begin
            generator_inst.gen_trans_poppush_bajo(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui pruebo pop/push con ocupacion media 
          trans_poppush_medio: begin
            generator_inst.gen_trans_poppush_medio(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui pruebo pop/push con ocupacion alta 
          trans_poppush_alto: begin
            generator_inst.gen_trans_poppush_alto(agnt_drv_mbx, num_transacciones, max_retardo);
          end

          // aqui primero lleno fifo y luego meto reset
          reset_full_aleatorio: begin
            generator_inst.gen_reset_full_aleatorio(agnt_drv_mbx, max_retardo);
          end

          // aqui meto reset con la fifo vacia
          reset_empty_aleatorio: begin
            generator_inst.gen_reset_empty_aleatorio(agnt_drv_mbx, max_retardo);
          end

          // aqui dejo la fifo a media carga y luego meto reset
          reset_half_aleatorio: begin
            generator_inst.gen_reset_half_aleatorio(agnt_drv_mbx, max_retardo);
          end

          default: begin
            $display("[%g] Agente Error: instrucción no soportada", $time);
            $finish;
          end
        endcase
      end
    end
  endtask
endclass
