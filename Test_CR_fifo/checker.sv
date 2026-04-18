class checker_c #(parameter width=16, parameter depth=8);
  trans_fifo #(.width(width)) transaccion_esperada;  // lo que el scoreboard dice que deberia pasar
  trans_fifo #(.width(width)) transaccion_observada; // lo que el monitor vio que paso en el DUT
  trans_fifo #(.width(width)) auxiliar;              // objeto de apoyo para operaciones internas
  trans_sb   #(.width(width)) to_sb;                 // objeto que se manda al scoreboard con el resultado

  trans_fifo_mbx mon_chkr_mbx;  // mailbox de entrada: trae lo que observo el monitor
  trans_fifo_mbx sb_chkr_mbx;   // mailbox de entrada: trae lo que espera el scoreboard
  trans_sb_mbx   chkr_sb_mbx;   // mailbox de salida: manda resultados de vuelta al scoreboard


  bit [width-1:0] modelo_mem[depth];  // guarda los datos que deberian estar en el FIFO
  int             tiempo_mem[depth];  // guarda el tiempo en que cada dato fue escrito
  bit             valido_mem[depth];  // indica si cada slot del modelo tiene un dato valido

  // punteros de escritura y lectura
  int wr_ptr;
  int rd_ptr;
  int contador_auxiliar;  // contador de apoyo para uso general

  // convierte el puntero (que puede ser mayor que depth) al indice real del arreglo
  // ejemplo: si depth=8 y ptr=9, regresa 1
  function automatic int indice_ptr(input int ptr);
    return ptr % depth;
  endfunction

  // mueve el puntero al siguiente slot, cuando llega al final del doble rango regresa a 0
  // el doble rango (2*depth) es el truco para saber si el FIFO esta lleno o vacio
  function automatic int siguiente_ptr(input int ptr);
    return (ptr + 1) % (2 * depth);
  endfunction

  // el FIFO esta vacio si los dos punteros estan en la misma posicion
  // si nunca se escribio nada, ambos arrancan en 0 y son iguales
  function automatic bit fifo_vacia();
    return (wr_ptr == rd_ptr);
  endfunction

  // el FIFO esta lleno si los punteros apuntan al mismo slot del arreglo
  // pero uno esta en la primera mitad del rango y el otro en la segunda
  // ejemplo con depth=8: wr_ptr=8 y rd_ptr=0 apuntan ambos al slot 0, pero wr dio la vuelta
  function automatic bit fifo_llena();
    return ((wr_ptr / depth) != (rd_ptr / depth)) && ((wr_ptr % depth) == (rd_ptr % depth));
  endfunction

  // cuenta cuantos datos hay en el FIFO restando los punteros
  // si wr esta adelante de rd es resta directa, si rd dio la vuelta hay que compensar
  function automatic int elementos_pendientes();
    if(wr_ptr >= rd_ptr) begin
      return wr_ptr - rd_ptr;  // caso normal
    end
    return (2 * depth) - rd_ptr + wr_ptr;  // caso donde rd dio la vuelta y wr no
  endfunction

  // recorre todos los slots y revisa si al menos uno tiene un dato guardado
  function automatic bit hay_pendientes_validos();
    for(int i = 0; i < depth; i++) begin
      if(valido_mem[i]) begin
        return 1;  // encontro un slot con dato, no hace falta seguir buscando
      end
    end
    return 0;  // todos los slots estaban vacios
  endfunction

  // tarea para limpiar el modelo, se llama al inicio y cada vez que se detecta un reset
  task automatic limpiar_estado();
    for(int i = 0; i < depth; i++) begin
      modelo_mem[i] = '0;  // dato en cero
      tiempo_mem[i] = 0;   // tiempo en cero
      valido_mem[i] = 0;   // slot marcado como vacio
    end
    wr_ptr = 0;  // ambos punteros regresan al inicio
    rd_ptr = 0;
  endtask

  // cuando el DUT recibe un reset, los datos que estaban en el FIFO se pierden
  // esta tarea le avisa al scoreboard cuales datos se perdieron y luego limpia el modelo
  task automatic reportar_reset_pendientes(input string tag);
    int ptr_exploracion;
    int indice_actual;

    ptr_exploracion = rd_ptr;  // se empieza desde el dato mas antiguo (donde estaba la lectura)
    for(int i = 0; i < depth; i++) begin
      indice_actual = indice_ptr(ptr_exploracion);  // se convierte el puntero a indice real
      if(valido_mem[indice_actual]) begin
        // este slot tenia un dato que nunca se leyo antes del reset, se le reporta al scoreboard
        to_sb = new();
        to_sb.clean();
        to_sb.dato_enviado = modelo_mem[indice_actual];  // el dato que se perdio
        to_sb.tiempo_push = tiempo_mem[indice_actual];   // cuando fue escrito
        to_sb.reset = 1;                                  // se marca como perdido por reset
        to_sb.print(tag);
        chkr_sb_mbx.put(to_sb);
      end
      ptr_exploracion = siguiente_ptr(ptr_exploracion);  // se avanza al siguiente slot
    end
    limpiar_estado();  // ya se reportaron todos, ahora si se limpia
  endtask

  // espera que el monitor mande una transaccion que no sea reset
  // si llega un reset en medio, lo maneja internamente y sigue esperando
  task automatic recibir_observada(output trans_fifo #(.width(width)) transaccion_local);
    forever begin
      mon_chkr_mbx.get(transaccion_local);  // se bloquea hasta que el monitor mande algo
      transaccion_local.print("Checker: Se recibe transacción observada desde el monitor");
      if(transaccion_local.tipo == reset) begin
        // llego un reset cuando no se esperaba, se procesan los pendientes y se sigue esperando
        if(hay_pendientes_validos()) begin
          reportar_reset_pendientes("Checker: Reset observado sin comando esperado pendiente");
        end else begin
          limpiar_estado();  // no habia nada guardado, solo se limpia
        end
        // el forever hace que el loop continue y se espere la siguiente transaccion
      end else begin
        break;  // llego algo que no es reset, se sale y se regresa esa transaccion
      end
    end
  endtask

  // verifica que la escritura que hizo el DUT coincida con lo que se esperaba
  task automatic procesar_escritura_esperada(input trans_fifo #(.width(width)) esperada);
    int indice_escritura;
    bit slot_ocupado;

    recibir_observada(transaccion_observada);  // se espera que el monitor confirme que vio la escritura

    // si el monitor vio otra cosa que no sea escritura, el DUT hizo algo incorrecto
    if(transaccion_observada.tipo != escritura) begin
      $display("[%g] Checker Error: se esperaba una escritura y se observo %s", $time, transaccion_observada.tipo);
      $finish;
    end

    // el dato que entro al DUT tiene que ser el mismo que se le mando
    if(transaccion_observada.dato != esperada.dato) begin
      $display("[%g] Checker Error: dato de escritura observado %h diferente al esperado %h", $time, transaccion_observada.dato, esperada.dato);
      $finish;
    end

    indice_escritura = indice_ptr(wr_ptr);     // slot donde deberia ir este dato
    slot_ocupado = valido_mem[indice_escritura]; // ese slot ya tenia algo?

    // si el slot ya tenia un dato significa que se lleno el FIFO y se esta pisando un dato viejo
    if(slot_ocupado) begin
      to_sb = new();
      to_sb.clean();
      to_sb.dato_enviado = modelo_mem[indice_escritura];  // el dato que se va a pisar
      to_sb.tiempo_push = tiempo_mem[indice_escritura];
      to_sb.overflow = 1;  // se le avisa al scoreboard que hubo overflow
      to_sb.print("Checker: Overflow");
      chkr_sb_mbx.put(to_sb);
    end

    // se guarda el nuevo dato en el modelo
    modelo_mem[indice_escritura] = esperada.dato;
    tiempo_mem[indice_escritura] = transaccion_observada.tiempo;  // se anota cuando se escribio
    valido_mem[indice_escritura] = 1;       // se marca el slot como ocupado
    wr_ptr = siguiente_ptr(wr_ptr);         // se mueve el puntero de escritura al siguiente slot
    esperada.tiempo = transaccion_observada.tiempo;
    esperada.print("Checker: Escritura validada");
  endtask

  // verifica que la lectura que hizo el DUT saque el dato correcto
  task automatic procesar_lectura_esperada();
    int indice_lectura;
    bit lectura_valida;

    recibir_observada(transaccion_observada);  // se espera que el monitor confirme que vio la lectura

    // si el monitor vio otra cosa, el DUT no hizo la lectura que debia
    if(transaccion_observada.tipo != lectura) begin
      $display("[%g] Checker Error: se esperaba una lectura y se observo %s", $time, transaccion_observada.tipo);
      $finish;
    end

    indice_lectura = indice_ptr(rd_ptr);       // slot del que deberia salir el dato
    lectura_valida = valido_mem[indice_lectura]; // ese slot tiene un dato guardado?

    if(lectura_valida) begin
      // si habia dato, se verifica que el DUT haya sacado exactamente ese dato
      if(transaccion_observada.dato == modelo_mem[indice_lectura]) begin
        // el dato es correcto, se le reporta al scoreboard como transaccion exitosa
        to_sb = new();
        to_sb.clean();
        to_sb.dato_enviado = modelo_mem[indice_lectura];
        to_sb.tiempo_push = tiempo_mem[indice_lectura];
        to_sb.tiempo_pop = transaccion_observada.tiempo;
        to_sb.completado = 1;
        to_sb.calc_latencia();  // cuanto tiempo paso entre que se escribio y se leyo
        to_sb.print("Checker: Transaccion Completada");
        chkr_sb_mbx.put(to_sb);
      end else begin
        // el DUT saco un dato que no era el que tocaba, error grave
        $display("[%g] Checker Error: dato leido %h diferente al esperado %h", $time, transaccion_observada.dato, modelo_mem[indice_lectura]);
        $finish;
      end
      valido_mem[indice_lectura] = 0;  // el slot ya se leyo, se marca como libre
    end else begin
      // se intento leer pero el slot estaba vacio, eso es un underflow
      to_sb = new();
      to_sb.clean();
      to_sb.tiempo_pop = transaccion_observada.tiempo;
      to_sb.underflow = 1;
      to_sb.print("Checker: Underflow");
      chkr_sb_mbx.put(to_sb);
    end
    rd_ptr = siguiente_ptr(rd_ptr);  // se mueve el puntero de lectura siempre, haya o no dato
  endtask

  // verifica que el reset que hizo el DUT coincida con lo que se esperaba
  task automatic procesar_reset_esperado();
    mon_chkr_mbx.get(transaccion_observada);  // se espera directamente del monitor, sin filtro
    transaccion_observada.print("Checker: Se recibe transacción observada desde el monitor");

    // si el monitor no vio un reset, el DUT no hizo lo que se le pidio
    if(transaccion_observada.tipo != reset) begin
      $display("[%g] Checker Error: se esperaba reset y se observo %s", $time, transaccion_observada.tipo);
      $finish;
    end
    reportar_reset_pendientes("Checker: Reset");  // se reportan los datos perdidos por el reset
  endtask

  // verifica una operacion donde el DUT hace lectura y escritura al mismo tiempo en el mismo ciclo
  task automatic procesar_lectura_escritura_esperada(input trans_fifo #(.width(width)) esperada);
    trans_fifo #(.width(width)) observada_escritura;  // lo que el monitor vio entrar
    trans_fifo #(.width(width)) observada_lectura;    // lo que el monitor vio salir
    int indice_lectura;
    int indice_escritura;
    bit lectura_valida;
    bit slot_escritura_ocupado;
    bit reportar_overflow;
    bit escritura_permanece_valida;
    bit [width-1:0] dato_leido_esperado;
    int tiempo_lectura_esperado;

    // se leen los estados actuales antes de modificar nada en el modelo
    indice_lectura = indice_ptr(rd_ptr);
    indice_escritura = indice_ptr(wr_ptr);
    lectura_valida = valido_mem[indice_lectura];         // habia dato para leer?
    slot_escritura_ocupado = valido_mem[indice_escritura]; // el slot donde se va a escribir ya tenia algo?

    // hay overflow si el slot de escritura estaba ocupado
    // excepcion: si escritura y lectura caen en el mismo slot y ese slot tenia dato,
    // la lectura lo libera primero asi que no es overflow real
    reportar_overflow = slot_escritura_ocupado && !((indice_escritura == indice_lectura) && lectura_valida);

    // se guarda lo que se espera leer antes de que el modelo cambie
    dato_leido_esperado = modelo_mem[indice_lectura];
    tiempo_lectura_esperado = tiempo_mem[indice_lectura];

    // el monitor reporta la escritura primero
    recibir_observada(observada_escritura);
    if(observada_escritura.tipo != escritura) begin
      $display("[%g] Checker Error: se esperaba una escritura en lectura_escritura y se observo %s", $time, observada_escritura.tipo);
      $finish;
    end
    // el dato que entro tiene que ser el que se le mando al DUT
    if(observada_escritura.dato != esperada.dato) begin
      $display("[%g] Checker Error: dato de escritura observado %h diferente al esperado %h en lectura_escritura", $time, observada_escritura.dato, esperada.dato);
      $finish;
    end

    // luego el monitor reporta la lectura
    recibir_observada(observada_lectura);
    if(observada_lectura.tipo != lectura) begin
      $display("[%g] Checker Error: se esperaba una lectura en lectura_escritura y se observo %s", $time, observada_lectura.tipo);
      $finish;
    end

    // si hubo overflow se reporta antes de continuar
    if(reportar_overflow) begin
      to_sb = new();
      to_sb.clean();
      to_sb.dato_enviado = modelo_mem[indice_escritura];  // el dato que se iba a pisar
      to_sb.tiempo_push = tiempo_mem[indice_escritura];
      to_sb.overflow = 1;
      to_sb.print("Checker: Overflow en lectura_escritura");
      chkr_sb_mbx.put(to_sb);
    end

    if(lectura_valida) begin
      // habia dato para leer, se verifica que el DUT haya sacado el correcto
      if(observada_lectura.dato == dato_leido_esperado) begin
        to_sb = new();
        to_sb.clean();
        to_sb.dato_enviado = dato_leido_esperado;
        to_sb.tiempo_push = tiempo_lectura_esperado;
        to_sb.tiempo_pop = observada_lectura.tiempo;
        to_sb.completado = 1;
        to_sb.calc_latencia();  // cuanto tiempo paso el dato en el FIFO
        to_sb.print("Checker: Transaccion Completada lectura_escritura");
        chkr_sb_mbx.put(to_sb);
      end else begin
        $display("[%g] Checker Error: dato leido %h diferente al esperado %h en lectura_escritura", $time, observada_lectura.dato, dato_leido_esperado);
        $finish;
      end
      valido_mem[indice_lectura] = 0;  // se libera el slot que se acabo de leer
    end else begin
      // el slot de lectura estaba vacio, underflow
      to_sb = new();
      to_sb.clean();
      to_sb.tiempo_pop = observada_lectura.tiempo;
      to_sb.underflow = 1;
      to_sb.print("Checker: Underflow en lectura_escritura");
      chkr_sb_mbx.put(to_sb);
    end

    // ahora si se actualiza el modelo con el dato nuevo que entro
    modelo_mem[indice_escritura] = esperada.dato;
    tiempo_mem[indice_escritura] = observada_escritura.tiempo;

    // caso especial: si escritura y lectura cayeron en el mismo slot
    // el slot queda valido solo si antes tenia dato (la escritura reemplaza al dato leido)
    // si cayeron en slots distintos la escritura siempre queda valida
    if(indice_escritura == indice_lectura) begin
      escritura_permanece_valida = lectura_valida;
    end else begin
      escritura_permanece_valida = 1;
    end
    valido_mem[indice_escritura] = escritura_permanece_valida;

    // se avanzan los dos punteros porque hubo tanto escritura como lectura
    wr_ptr = siguiente_ptr(wr_ptr);
    rd_ptr = siguiente_ptr(rd_ptr);
    esperada.tiempo = observada_escritura.tiempo;
    esperada.print("Checker: Escritura validada en lectura_escritura");
  endtask

  // tarea principal del checker, espera lo que dice el scoreboard y lo compara con lo que vio el monitor
  task run;
    $display("[%g]  El checker fue inicializado",$time);
    to_sb = new();
    forever begin
      to_sb = new();
      sb_chkr_mbx.get(transaccion_esperada);  // se bloquea hasta que el scoreboard mande una transaccion
      transaccion_esperada.print("Checker: Se recibe transacción esperada desde el scoreboard");
      case(transaccion_esperada.tipo)
        escritura: begin
          procesar_escritura_esperada(transaccion_esperada);
        end
        lectura: begin
          procesar_lectura_esperada();
        end
        lectura_escritura: begin
          procesar_lectura_escritura_esperada(transaccion_esperada);
        end
        reset: begin
          procesar_reset_esperado();
        end
        default: begin
          $display("[%g] Checker Error: la transacción esperada no tiene tipo valido",$time);
          $finish;
        end
      endcase
    end
  endtask
endclass