//////////////////////////////////////////////////////////////
// Definición del tipo de transacciones posibles en la fifo //
//////////////////////////////////////////////////////////////

typedef enum { lectura, escritura, lectura_escritura, reset} tipo_trans;

/////////////////////////////////////////////////////////////////////////////////////////
//Transacción: este objeto representa las transacciones que entran y salen de la fifo. //
/////////////////////////////////////////////////////////////////////////////////////////
class trans_fifo #(parameter width = 16);
  rand int retardo;          // ciclos de espera antes de ejecutar la transacción, se randomiza dentro de [1, max_retardo)
  rand bit[width-1:0] dato;  // dato a escribir en la fifo, randomizable y afectado por const_dato si habilitar_patron está activo
  bit [width-1:0] dato_pop;  // dato observado en la salida del DUT durante una lectura, no se randomiza porque lo pone el monitor
  int tiempo;                // timestamp de simulación en que se ejecutó la transacción
  rand tipo_trans tipo;      // tipo de operación; su valor final depende del nivel_fifo y los flags habilitados
  int max_retardo;           // cota superior para el constraint de retardo
  rand int nivel_fifo;       // nivel actual de la fifo al momento de generar la transacción; guía los constraints de tipo
  int depth_cfg;             // profundidad real de la fifo, se copia desde el agente para que los constraints conozcan el límite
 
  // flags que llegan desde el agente según los plusargs del test;
  // cada uno habilita o deshabilita ramas dentro de los constraints
  bit habilitar_overflow;       // permite generar escrituras con la fifo llena
  bit habilitar_underflow;      // permite generar lecturas con la fifo vacía
  bit habilitar_patron;         // restringe el dato a patrones fijos de alternancia de bits
  bit habilitar_push_pop;       // fuerza operaciones simultáneas lectura_escritura
  bit habilitar_reset_random;   // mezcla resets aleatorios en la distribución de tipos

  // fuerzan el nivel_fifo a un valor específico antes de resolver el tipo
  bit habilitar_fifo_full;   // nivel == depth_cfg
  bit habilitar_fifo_empty;  // nivel == 0
  bit habilitar_fifo_mid;    // nivel == depth_cfg / 2

  // fuerzan reset solo cuando el nivel coincide con el estado indicado
  bit habilitar_reset_full;   // reset dirigido cuando la fifo está llena
  bit habilitar_reset_empty;  // reset dirigido cuando la fifo está vacía
  bit habilitar_reset_mid;    // reset dirigido cuando la fifo está a la mitad


  constraint c_order {
    // nivel_fifo se resuelve primero porque los constraints de tipo dependen de su valor.
    // sin este solve, el solver podría elegir un tipo incompatible con el nivel resultante.
    solve nivel_fifo before tipo;
  }


  constraint const_retardo {
    retardo > 0;           // retardo mínimo de 1 ciclo para que el driver siempre espere algo
    retardo < max_retardo; // cota superior configurable desde el agente
  }


  constraint const_dato {
    // cuando habilitar_patron está activo, el dato queda restringido a cuatro patrones
    // de alternancia de nibbles: todo ceros, todo unos, 1010... y 0101...
    // esto sirve para detectar errores de escritura relacionados con bits adyacentes.
    if (habilitar_patron) {
      dato inside {
        {width/4{4'h0}},  // 0000...0000
        {width/4{4'hF}},  // 1111...1111
        {width/4{4'hA}},  // 1010...1010
        {width/4{4'h5}}   // 0101...0101
      };
    }
  }

  constraint const_rango_llenado {
    // nivel_fifo siempre debe estar dentro del rango físico de la fifo.
    // estos límites son el piso para todos los demás constraints que usan nivel_fifo.
    nivel_fifo >= 0;
    nivel_fifo <= depth_cfg;
  }


  constraint const_estado_dirigido {
    // fuerza nivel_fifo a un valor fijo según el flag activo.
    // solo uno puede estar activo a la vez; el if-else garantiza prioridad.
    if (habilitar_fifo_full)
      nivel_fifo == depth_cfg;       // fifo completamente llena

    else if (habilitar_fifo_empty)
      nivel_fifo == 0;               // fifo completamente vacía

    else if (habilitar_fifo_mid)
      nivel_fifo == (depth_cfg >> 1); // exactamente la mitad, shift en lugar de división para evitar punto flotante
  }

  constraint const_dinamico_llenado {
    // protege contra combinaciones tipo/nivel que causarían comportamiento indefinido
    // cuando las condiciones de borde no están habilitadas explícitamente.

    // sin underflow habilitado, no se puede hacer pop con la fifo vacía
    if (!habilitar_underflow && nivel_fifo == 0)
      tipo inside {escritura, reset};

    // sin overflow habilitado, no se puede hacer push con la fifo llena
    if (!habilitar_overflow && nivel_fifo == depth_cfg)
      tipo inside {lectura, lectura_escritura, reset};
  }

  constraint const_tipo {
    // jerarquía de prioridad explícita para determinar qué tipo se genera.
    // los casos dirigidos de reset van primero porque son los más restrictivos.

    // resets dirigidos según el nivel, solo disparan si el nivel coincide exactamente
    if (habilitar_reset_full && nivel_fifo == depth_cfg)
      tipo == reset;

    else if (habilitar_reset_empty && nivel_fifo == 0)
      tipo == reset;

    else if (habilitar_reset_mid && nivel_fifo == (depth_cfg >> 1))
      tipo == reset;

    // reset con distribución aleatoria, aparece el 10% del tiempo,
    // el resto se reparte equitativamente entre lecturas y escrituras
    else if (habilitar_reset_random)
      tipo dist {reset:=10, lectura:=40, escritura:=40, lectura_escritura:=10};

    // fuerza operación simultánea en todos los ciclos, útil para estresar la lógica push+pop
    else if (habilitar_push_pop)
      tipo == lectura_escritura;

    // casos de borde explícitos: si el nivel está en el extremo y el flag está activo,
    // se fuerza el tipo que provoca el comportamiento de borde
    else if (habilitar_overflow && nivel_fifo == depth_cfg)
      tipo == escritura;

    else if (habilitar_underflow && nivel_fifo == 0)
      tipo == lectura;

    // distribución por defecto sin flags activos: ligera preferencia por lecturas y escrituras
    // sobre operaciones simultáneas para no saturar el modelo en condiciones normales
    else
      tipo dist {lectura:=40, escritura:=40, lectura_escritura:=20};
  }


  function new(int ret =0,bit[width-1:0] dto=0,int tmp = 0, tipo_trans tpo = lectura, int mx_rtrd = 10);
    this.retardo   = ret;
    this.dato      = dto;
    this.dato_pop  = 0;
    this.tiempo    = tmp;
    this.tipo      = tpo;
    this.max_retardo = mx_rtrd;
    this.nivel_fifo  = 0;
    this.depth_cfg   = 8;
  endfunction
  
  function clean;
    this.retardo   = 0;
    this.dato      = 0;
    this.dato_pop  = 0;
    this.tiempo    = 0;
    this.tipo      = lectura;
    this.nivel_fifo  = 0;
    this.depth_cfg   = 8;
  endfunction
    
  function void print(string tag = "");
    $display("[%g] %s Tiempo=%g Tipo=%s Retardo=%g dato=0x%h dato_pop=0x%h",$time,tag,tiempo,this.tipo,this.retardo,this.dato,this.dato_pop);
  endfunction
endclass


////////////////////////////////////////////////////////////////
// Interface: Esta es la interface que se conecta con la FIFO //
////////////////////////////////////////////////////////////////

interface fifo_if #(parameter width =16) (
  input clk
);
  logic rst;                    // reset activo del DUT
  logic pndng;                  // indica que hay datos pendientes en la fifo
  logic full;                   // fifo llena
  logic push;                   // señal de escritura
  logic pop;                    // señal de lectura
  logic [width-1:0] dato_in;    // dato que entra al DUT en una escritura
  logic [width-1:0] dato_out;   // dato que sale del DUT en una lectura

endinterface


////////////////////////////////////////////////////
// Objeto de transacción usado en el scoreboard   //
////////////////////////////////////////////////////

class trans_sb #(parameter width=16);
  bit [width-1:0] dato_enviado; // dato que se escribió en la fifo y ahora se verifica
  int tiempo_push;              // ciclo en que se hizo el push
  int tiempo_pop;               // ciclo en que se hizo el pop
  bit completado;               // indica que el dato fue leído correctamente
  bit overflow;                 // se perdió un dato por fifo llena
  bit underflow;                // se intentó leer con la fifo vacía
  bit reset;                    // el dato fue descartado por un reset
  int latencia;                 // diferencia entre tiempo_pop y tiempo_push en ciclos
  
  function clean();
    this.dato_enviado = 0;
    this.tiempo_push  = 0;
    this.tiempo_pop   = 0;
    this.completado   = 0;
    this.overflow     = 0;
    this.underflow    = 0;
    this.reset        = 0;
    this.latencia     = 0;
  endfunction

  task calc_latencia;
    this.latencia = this.tiempo_pop - this.tiempo_push; // cuántos ciclos vivió el dato en la fifo
  endtask
  
  function print (string tag);
    $display("[%g] %s dato=%h,t_push=%g,t_pop=%g,cmplt=%g,ovrflw=%g,undrflw=%g,rst=%g,ltncy=%g", 
             $time,
             tag, 
             this.dato_enviado, 
             this.tiempo_push,
             this.tiempo_pop,
             this.completado,
             this.overflow,
             this.underflow,
             this.reset,
             this.latencia);
  endfunction
endclass

/////////////////////////////////////////////////////////////////////////
// Definición de estructura para generar comandos hacia el scoreboard  //
/////////////////////////////////////////////////////////////////////////
typedef enum {retardo_promedio, reporte} solicitud_sb;

/////////////////////////////////////////////////////////////////////////
// Definición de estructura para generar comandos hacia el agente      //
/////////////////////////////////////////////////////////////////////////
typedef enum {llenado_aleatorio, trans_aleatoria, trans_especifica, sec_trans_aleatorias} instrucciones_agente;

// los mailboxes parametrizados con trans_fifo y trans_sb no se pueden typedef porque
// SystemVerilog no permite parametrizar tipos definidos con typedef mailbox #(tipo_parametrizado)
//typedef mailbox #(trans_fifo) trans_fifo_mbx;
//typedef mailbox #(trans_sb)   trans_sb_mbx;

typedef mailbox #(solicitud_sb)        comando_test_sb_mbx;    // canal test → scoreboard
typedef mailbox #(instrucciones_agente) comando_test_agent_mbx; // canal test → agente
