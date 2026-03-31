///////////////////////////////////
// Módulo para correr la prueba  //
///////////////////////////////////
//Tipos de pruebas que hay 
typedef enum {GEN_ALEATORIO, LLENADO_INTERCALADO, RESET_RANDOM_FULL,RESET_RANDOM_EMPTY,RESET_RANDOM_HALF, OVERFLOW, UNDERFLOW, POP_PUSH} tipo_prueba_t;
// esta clase se usará para enviar instrucciones mediante un solo mailbox al generador
class instruccion_test;
    tipo_prueba_t tipo;
    int num_trans;
    int ret_max;
endclass
typedef enum {llenado_aleatorio,trans_aleatoria,trans_especifica,sec_trans_aleatorias} instrucciones_agente;

class test_base #(parameter width = 16, parameter depth =8); 
 // el test no debe conocer la estructura interna del ambiente, asi que se cortara comunicacion en el scoreboard
 // Definición del ambiente de la prueba
  ambiente #(.depth(depth),.width(width)) ambiente_inst;
 // Definición de la interface a la que se conectará el DUT
  virtual fifo_if  #(.width(width)) vif;
// se ponen aca pq el test decide la escala de la prueba, los demas datos se deben  generar en el generador
  rand int retardo; // retardo aleatorio entre eventos
  rand int num_transacciones; // cantidad de transacciones a generar
//este test base aleatorizará eventos de reset, eventos de lectura y escritura, tiempos de espera entre eventos, datos de entrada, cantidad de eventos, tamaño de profundidad de la fifo y tamaño de palabra, esto con el fin de generar una gran cantidad de escenarios de prueba y así validar el correcto funcionamiento del DUT en diferentes situaciones. del paquete de la fifo
// posteriormente se haran hijos para probrar casos de esquina 

  //definción de las condiciones iniciales del test
  function new(virtual fifo_if  #(.width(width)) _if); 
    this.vif=_if;
    ambiente_inst = new(vif); // se deja que el ambiente haga sus propias conexiones, el test no debe saber de conecciones internas
  endfunction
  // constraints de los parametros 
  constraint retardo_c {retardo inside {[1:10]};}
  constraint num_transacciones_c {num_transacciones inside {[10:100]};}

  virtual task run;
    $display("[%g]  El Test por defecto fue inicializado",$time);
    // se genera el retardo y numero de transacciones maximo aleatorimente
    this.randomize();
    
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba
    instruccion_test instr= new();
    instr.tipo = GEN_ALEATORIO;
    instr.num_trans = this.num_transacciones;
    instr.ret_max = this.retardo;
  
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none

      // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente 
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    $display("[%g]  Test por defecto: Enviada la instrucción de prueba al ambiente con %0d transacciones y retardo máximo de %0d",$time, instr.num_trans, instr.ret_max);
    // Esto se debe ejecutar dentro del ambiente, la prueba espera a que el ambiente termine de ejecutar la prueba solicitada, y termina la prueba
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;

    endtask


 endclass

 class test_intercalado extends test_base; // este test maneja el caso de llenado intercalando 
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer un llenado intercalado
  virtual  task run;
    $display("[%g]  El Test de llenado intercalado fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer un llenado intercalado, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = LLENADO_INTERCALADO;
    instr.num_trans = this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;

    endtask

 endclass

 class test_reset_random_full extends test_base; // este test maneja el caso de eventos de reset aleatorios
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer eventos de reset aleatorios
 virtual task run;
    $display("[%g]  El Test de reset aleatorio fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer eventos de reset aleatorios, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = RESET_RANDOM_FULL;
    instr.num_trans=this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente   
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;
    endtask

    endclass

     class test_reset_random_empty extends test_base; // este test maneja el caso de eventos de reset aleatorios
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer eventos de reset aleatorios
 virtual task run;
    $display("[%g]  El Test de reset aleatorio fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer eventos de reset aleatorios, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = RESET_RANDOM_EMPTY;
    instr.num_trans=this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente   
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;
    endtask

    endclass

     class test_reset_random_half extends test_base; // este test maneja el caso de eventos de reset aleatorios
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer eventos de reset aleatorios
 virtual task run;
    $display("[%g]  El Test de reset aleatorio fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer eventos de reset aleatorios, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = RESET_RANDOM_HALF;
    instr.num_trans=this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente   
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;
    endtask

    endclass
  
    
    class test_overflow extends test_base; // este test maneja el caso de eventos de reset aleatorios
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer eventos de reset aleatorios
 virtual task run;
    $display("[%g]  El Test de reset aleatorio fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer eventos de reset aleatorios, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = OVERFLOW;
    instr.num_trans=this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente   
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;
    endtask

    endclass

    class test_underflow extends test_base; // este test maneja el caso de eventos de reset aleatorios
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer eventos de reset aleatorios
 virtual task run;
    $display("[%g]  El Test de reset aleatorio fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer eventos de reset aleatorios, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = UNDERFLOW;
    instr.num_trans=this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente   
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;
    endtask

    endclass

    class test_pop_push extends test_base; // este test maneja el caso de eventos de reset aleatorios
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer eventos de reset aleatorios
 virtual task run;
    $display("[%g]  El Test de reset aleatorio fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer eventos de reset aleatorios, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = POP_PUSH;
    instr.num_trans=this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente   
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;
    endtask

    endclass

       class test_pop_push extends test_base; // este test maneja el caso de eventos de reset aleatorios
  function new(virtual fifo_if  #(.width(width)) _if);
    super.new(_if);
  endfunction
    // aca se sobreescribe el run para enviar la instruccion al generador de que se quiere hacer eventos de reset aleatorios
 virtual task run;
    $display("[%g]  El Test de reset aleatorio fue inicializado",$time);
    // se pasa la configuracion al ambiente (generador), con la cantidad de transacciones, el retardo maximo y el caso de prueba 0s 5s As y Fs
    instruccion_test instr= new();
    this.randomize();
    // aca se mantienen los mismos parametros de retardo y numero de transacciones aleatorios, pero se le indica al generador que se quiere hacer eventos de reset aleatorios, se puede cambiar el retardo y numero de transacciones si se desea
    instr.tipo = POP_PUSH;
    instr.num_trans=this.num_transacciones;
    instr.ret_max=this.retardo;
    // se ejecuta el ambiente
    fork
      ambiente_inst.run();
    join_none
        // se envia el paquete de ocnfiguracion mediante un mailbox al generador del ambiente   
    ambiente_inst.test_gen_mbx.put(instr); // implementar el mailbox en el ambiente y la conexión al generador
    // aca se espera lo mismo que en el test base
    wait(ambiente_inst.scoreboard_inst.test_terminado);
    $finish;
    endtask

    endclass
    