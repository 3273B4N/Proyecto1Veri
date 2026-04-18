class generator #(parameter width = 16, parameter depth = 8);
  trans_fifo_mbx gen_agnt_mbx;         // mailbox para enviar transacciones al agente
  comando_test_gen_mbx test_gen_mbx;   // mailbox para recibir instrucciones del test
  int num_transacciones;               // cuantas transacciones se generan en los casos que usan loop
  int min_retardo;                     // retardo minimo que puede tener una transaccion
  int max_retardo;                     // retardo maximo que puede tener una transaccion
  int ret_spec;                        // retardo que se usa cuando la transaccion es especifica
  tipo_trans tpo_spec;                 // tipo de transaccion especifica (lectura, escritura, etc)
  bit [width-1:0] dto_spec;           // dato que se usa en la transaccion especifica
  instrucciones_agente instruccion;    // guarda la instruccion que llega del test
  trans_fifo #(.width(width)) transaccion; // objeto de transaccion

  // constructor, se inicializan los valores por defecto de los parametros de control
  function new;
    num_transacciones = 2;   // por defecto se generan 2 transacciones
    min_retardo = 1;         // retardo minimo de 1 ciclo
    max_retardo = 10;        // retardo maximo de 10 ciclos
    ret_spec = 1;            // la transaccion especifica arranca con retardo de 1
    tpo_spec = lectura;      // por defecto la transaccion especifica es una lectura
    dto_spec = '0;           // el dato por defecto es todo ceros
  endfunction

  // si el retardo que llega es negativo lo fuerza a 0, sino lo regresa tal cual
  function automatic int obtener_retardo(input int base);
    if(base < 0) begin
      return 0;  // no tiene sentido un retardo negativo
    end
    return base;
  endfunction

  // calcula el nivel medio del FIFO, si es muy pequeño retorna 1 para no quedarse en 0
  function automatic int nivel_medio_fifo();
    if(depth <= 2) begin
      return 1;  // para FIFOs muy pequeños se usa 1 como minimo util
    end
    return depth/2;  // division entera, la mitad de la profundidad
  endfunction

  // calcula el nivel alto del FIFO, un slot antes de llenarse
  function automatic int nivel_alto_fifo();
    if(depth <= 2) begin
      return 1;  // mismo caso borde que nivel_medio
    end
    return depth-1;  // casi lleno pero sin overflow
  endfunction

  // genera uno de 4 patrones de dato segun el indice: 0x0000, 0x5555, 0xAAAA, 0xFFFF
  function automatic bit [width-1:0] patron_dato(input int indice);
    bit [width-1:0] valor;
    valor = '0;
    case(indice % 4)  // el modulo 4 hace que los patrones ciclen: 0,1,2,3,0,1,2,3...
      0: valor = '0;  // 0x0000 o sea que todos los bits en 0
      1: begin
        // 0x5555 son bits pares en 1, impares en 0
        // se recorre bit a bit y se ponen en 1 los que estan en posicion par (0,2,4...)
        for(int i = 0; i < width; i++) begin
          if((i % 4 == 0) || (i % 4 == 2)) begin
            valor[i] = 1'b1;
          end
        end
      end
      2: begin
        // 0xAAAA son bits impares en 1, pares en 0, complemento del patron anterior
        // se recorre bit a bit y se ponen en 1 los que estan en posicion impar (1,3,5...)
        for(int i = 0; i < width; i++) begin
          if((i % 4 == 1) || (i % 4 == 3)) begin
            valor[i] = 1'b1;
          end
        end
      end
      default: valor = '1;  // 0xFFFF son todos los bits en 1
    endcase
    return valor;
  endfunction

  // crea una transaccion con tipo y dato fijos, el retardo se valida antes de asignarlo
  task automatic enviar_transaccion_dirigida(
    input tipo_trans tipo_local,
    input bit [width-1:0] dato_local,
    input int retardo_local
  );
    trans_fifo #(.width(width)) local_transaccion;
    local_transaccion = new();                                    // se instancia el objeto
    local_transaccion.min_retardo = min_retardo;                  // se heredan los limites del generador
    local_transaccion.max_retardo = max_retardo;
    local_transaccion.tipo = tipo_local;                          // se asigna el tipo que llego por parametro
    local_transaccion.dato = dato_local;                          // se asigna el dato que llego por parametro
    local_transaccion.retardo = obtener_retardo(retardo_local);   // retardo antes de asignarlo
    local_transaccion.print("Generador: transaccion creada");     // se imprime para debug
    gen_agnt_mbx.put(local_transaccion);                          // se manda al agente
  endtask

  // crea una transaccion con valores aleatorios, opcionalmente fuerza el tipo
  task automatic enviar_transaccion_aleatoria(input bit forzar_tipo, input tipo_trans tipo_forzado);
    trans_fifo #(.width(width)) local_transaccion;
    local_transaccion = new();
    local_transaccion.min_retardo = min_retardo;  // limites de retardo para la randomizacion
    local_transaccion.max_retardo = max_retardo;
    local_transaccion.randomize();                // se aleatorizan todos los campos del objeto
    if(forzar_tipo) begin
      local_transaccion.tipo = tipo_forzado;      // si se pidio forzar tipo, se sobreescribe despues de randomizar
    end
    local_transaccion.print("Generador: transaccion creada");
    gen_agnt_mbx.put(local_transaccion);          // se manda al agente
  endtask

  // envia 'cantidad' escrituras aleatorias, sirve para llenar el FIFO antes de un caso de prueba
  task automatic llenar_fifo_aleatorio(input int cantidad);
    for(int i = 0; i < cantidad; i++) begin
      enviar_transaccion_aleatoria(1, escritura);  // fuerza escritura, dato aleatorio
    end
  endtask

  // envia 'cantidad' lecturas con retardo fijo, sirve para vaciar el FIFO al final de un caso
  task automatic vaciar_fifo(input int cantidad, input int retardo_local);
    for(int i = 0; i < cantidad; i++) begin
      enviar_transaccion_dirigida(lectura, '0, retardo_local);  // dato no importa en lectura
    end
  endtask

  // llena el FIFO a cierto nivel, hace push y pop simultaneos, luego lo vacia
  task automatic correr_push_pop_simultaneo(input int nivel_inicial, input int repeticiones);
    llenar_fifo_aleatorio(nivel_inicial);  // se pre-carga el FIFO al nivel pedido
    for(int i = 0; i < repeticiones; i++) begin
      // se hace lectura_escritura simultanea con patron de datos y retardo variable
      enviar_transaccion_dirigida(lectura_escritura, patron_dato(i), i % (max_retardo + 1));
    end
    vaciar_fifo(nivel_inicial, 1);  // se deja el FIFO limpio al terminar
  endtask

  // llena el FIFO a cierto nivel y luego manda un reset
  task automatic correr_reset_en_nivel(input int nivel_inicial);
    llenar_fifo_aleatorio(nivel_inicial);          // se llena al nivel pedido
    enviar_transaccion_dirigida(reset, '0, 1);     // se manda el reset con retardo minimo
  endtask

  // tarea principal, espera instrucciones del test y ejecuta la secuencia correspondiente
  task run;
    $display("[%g]  El Generador fue inicializado",$time);
    forever begin
      test_gen_mbx.get(instruccion);  // se bloquea hasta que el test mande una instruccion
      $display("[%g]  Generador: se recibe instruccion",$time);
      case(instruccion)

        // llena con escrituras aleatorias y luego hace el mismo numero de lecturas
        llenado_aleatorio: begin
          for(int i = 0; i < num_transacciones; i++) begin
            enviar_transaccion_aleatoria(1, escritura);
          end
          for(int i = 0; i < num_transacciones; i++) begin
            enviar_transaccion_aleatoria(1, lectura);
          end
        end

        // una sola transaccion completamente aleatoria, tipo incluido
        trans_aleatoria: begin
          enviar_transaccion_aleatoria(0, lectura);  // el segundo parametro no importa porque forzar_tipo=0
        end

        // manda exactamente la transaccion que el test configuró en tpo_spec, dto_spec, ret_spec
        trans_especifica: begin
          enviar_transaccion_dirigida(tpo_spec, dto_spec, ret_spec);
        end

        // secuencia de transacciones completamente aleatorias, tipo y dato al azar
        sec_trans_aleatorias: begin
          for(int i = 0; i < num_transacciones; i++) begin
            enviar_transaccion_aleatoria(0, lectura);  // forzar_tipo=0 asi que el tipo es aleatorio
          end
        end

        // mezcla aleatoria de resets, escrituras, lecturas y operaciones simultaneas
        eventos_reset_aleatorios: begin
          for(int i = 0; i < num_transacciones; i++) begin
            case($urandom_range(0, 4))  // se elige al azar que tipo de transaccion va
              0: enviar_transaccion_dirigida(reset, '0, i % (max_retardo + 1));  // reset con retardo variable
              1: enviar_transaccion_aleatoria(1, escritura);
              2: enviar_transaccion_aleatoria(1, lectura);
              3: enviar_transaccion_aleatoria(1, lectura_escritura);
              default: enviar_transaccion_aleatoria(0, lectura);  // transaccion totalmente aleatoria
            endcase
          end
        end

        // escribe todos los patrones de datos posibles y luego vacia el FIFO
        patron_max_alternancia: begin
          for(int i = 0; i < depth; i++) begin
            enviar_transaccion_dirigida(escritura, patron_dato(i), i % (max_retardo + 1));
          end
          vaciar_fifo(depth, 1);  // se dejan todas las posiciones vacias al final
        end

        // llena el FIFO completo y mete una escritura extra para provocar overflow
        provocar_overflow: begin
          llenar_fifo_aleatorio(depth);                              // FIFO lleno
          enviar_transaccion_dirigida(escritura, patron_dato(depth), 1);  // una escritura mas = overflow
          vaciar_fifo(depth, 1);                                     // se limpia al terminar
        end

        // intenta leer de un FIFO vacio o casi vacio para provocar underflow
        provocar_underflow: begin
          vaciar_fifo((depth < 2) ? 2 : depth/2, 1);  // si el FIFO es muy pequeño se usan 2 lecturas minimo
        end

        // push y pop simultaneo con FIFO casi vacio (nivel 1)
        push_pop_simultaneo_bajo: begin
          correr_push_pop_simultaneo(1, 2);  // nivel inicial 1, solo 2 repeticiones
        end

        // push y pop simultaneo con FIFO a la mitad
        push_pop_simultaneo_medio: begin
          correr_push_pop_simultaneo(nivel_medio_fifo(), nivel_medio_fifo());
        end

        // push y pop simultaneo con FIFO casi lleno
        push_pop_simultaneo_alto: begin
          correr_push_pop_simultaneo(nivel_alto_fifo(), nivel_medio_fifo());
        end

        // reset cuando el FIFO esta completamente vacio
        reset_fifo_vacia: begin
          enviar_transaccion_dirigida(reset, '0, 1);
        end

        // reset cuando el FIFO esta a la mitad
        reset_fifo_media: begin
          correr_reset_en_nivel(nivel_medio_fifo());
        end

        // reset cuando el FIFO esta completamente lleno
        reset_fifo_llena: begin
          correr_reset_en_nivel(depth);
        end

        default: begin
          $display("[%g] Generador Error: instruccion no valida", $time);
          $finish;
        end
      endcase
    end
  endtask
endclass