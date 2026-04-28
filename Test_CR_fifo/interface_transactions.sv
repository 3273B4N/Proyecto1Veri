//////////////////////////////////////////////////////////////
// Definición del tipo de transacciones posibles en la fifo //
//////////////////////////////////////////////////////////////

typedef enum { lectura, escritura, lectura_escritura, reset} tipo_trans;

/////////////////////////////////////////////////////////////////////////////////////////
//Transacción: este objeto representa las transacciones que entran y salen de la fifo. //
/////////////////////////////////////////////////////////////////////////////////////////
class trans_fifo #(parameter width = 16);
  rand int retardo; // tiempo de retardo en ciclos de reloj que se debe esperar antes de ejecutar la transacción
  rand bit[width-1:0] dato; // este es el dato de la transacción
  bit [width-1:0] dato_pop; // dato observado en salida para lecturas
  int tiempo; //Representa el tiempo  de la simulación en el que se ejecutó la transacción 
  rand tipo_trans tipo; // lectura, escritura, lectura_escritura, reset
  int max_retardo;
  rand int nivel_fifo;
  int depth_cfg;
 
  bit habilitar_overflow;
  bit habilitar_underflow;
  bit habilitar_patron;
  bit habilitar_push_pop;
  bit habilitar_reset_random;

  bit habilitar_fifo_full;
  bit habilitar_fifo_empty;
  bit habilitar_fifo_mid;

  bit habilitar_reset_full;
  bit habilitar_reset_empty;
  bit habilitar_reset_mid;


  constraint c_order {
    //prioridad para evitar conflictos entre constraints: se resuelve primero 
    //el nivel_fifo para luego resolver el tipo de transacción acorde al nivel resultante.
    solve nivel_fifo before tipo;
  }


  constraint const_retardo {
    // se estable un maximo retardo
    retardo > 0;
    retardo < max_retardo;
  }


  constraint const_dato {
    //patrones de alternancia
    if (habilitar_patron) {
      dato inside {
        {width/4{4'h0}},
        {width/4{4'hF}},
        {width/4{4'hA}},
        {width/4{4'h5}}
      };
    }
  }

  constraint const_rango_llenado {
    nivel_fifo >= 0;
    nivel_fifo <= depth_cfg;
  }


  constraint const_estado_dirigido {
    // nivel lleno
    if (habilitar_fifo_full)
      nivel_fifo == depth_cfg;

    // nivel vacio
    else if (habilitar_fifo_empty)
      nivel_fifo == 0;

    // nivel medio 
    else if (habilitar_fifo_mid)
      nivel_fifo == (depth_cfg >> 1);
  }

  constraint const_dinamico_llenado {
    // Si no se habilita underflow, en vacio no se permite pop
    if (!habilitar_underflow && nivel_fifo == 0)
      tipo inside {escritura, reset};

    // si no se habilita overflow, en lleno no se permiten 
    if (!habilitar_overflow && nivel_fifo == depth_cfg)
      tipo inside {lectura, lectura_escritura, reset};
  }

  constraint const_tipo {

    // reset dirigido a nivel lleno
    if (habilitar_reset_full && nivel_fifo == depth_cfg)
      tipo == reset;
    // reset dirigido a nivel vacio
    else if (habilitar_reset_empty && nivel_fifo == 0)
      tipo == reset;
    // reset dirigido a nivel medio
    else if (habilitar_reset_mid && nivel_fifo == (depth_cfg >> 1))
      tipo == reset;

    // reset aleatorio
    else if (habilitar_reset_random)
      tipo dist {reset:=10, lectura:=40, escritura:=40, lectura_escritura:=10};

    // push y pop al mismo tiempo 
    else if (habilitar_push_pop)
      tipo == lectura_escritura;

    // caso overflow
    else if (habilitar_overflow && nivel_fifo == depth_cfg)
      tipo == escritura;

    // caso underflow
    else if (habilitar_underflow && nivel_fifo == 0)
      tipo == lectura;

    // caso por defecto
    else
      tipo dist {lectura:=40, escritura:=40, lectura_escritura:=20};
  }


  function new(int ret =0,bit[width-1:0] dto=0,int tmp = 0, tipo_trans tpo = lectura, int mx_rtrd = 10);
    this.retardo = ret;
    this.dato = dto;
    this.dato_pop = 0;
    this.tiempo = tmp;
    this.tipo = tpo;
    this.max_retardo = mx_rtrd;
    this.nivel_fifo = 0;
    this.depth_cfg = 8;
  endfunction
  
  function clean;
    this.retardo = 0;
    this.dato = 0;
    this.dato_pop = 0;
    this.tiempo = 0;
    this.tipo = lectura;
    this.nivel_fifo = 0;
    this.depth_cfg = 8;
    
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
  logic rst;
  logic pndng;
  logic full;
  logic push;
  logic pop;
  logic [width-1:0] dato_in; 
  logic [width-1:0] dato_out;

  endinterface


////////////////////////////////////////////////////
// Objeto de transacción usado en el scroreboard  //
////////////////////////////////////////////////////

class trans_sb #(parameter width=16);
  bit [width-1:0] dato_enviado;
  int tiempo_push;
  int tiempo_pop;
  bit completado;
  bit overflow;
  bit underflow;
  bit reset;
  int latencia;
  
  function clean();
    this.dato_enviado = 0;
    this.tiempo_push = 0;
    this.tiempo_pop = 0;
    this.completado = 0;
    this.overflow = 0;
    this.underflow = 0;
    this.reset = 0;
    this.latencia = 0;
  endfunction

  task calc_latencia;
    this.latencia = this.tiempo_pop - this.tiempo_push;
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
// Definición de estructura para generar comandos hacia el scroreboard //
/////////////////////////////////////////////////////////////////////////
typedef enum {retardo_promedio,reporte} solicitud_sb;

/////////////////////////////////////////////////////////////////////////
// Definición de estructura para generar comandos hacia el agente      //
/////////////////////////////////////////////////////////////////////////
typedef enum {llenado_aleatorio,trans_aleatoria,trans_especifica,sec_trans_aleatorias} instrucciones_agente;

///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
//typedef mailbox #(trans_fifo) trans_fifo_mbx; se borra esta linea porque no se pueden parametrizar tipos definidos

///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
//typedef mailbox #(trans_sb) trans_sb_mbx; lo mismo pasa con esta

///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
typedef mailbox #(solicitud_sb) comando_test_sb_mbx;

///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
typedef mailbox #(instrucciones_agente) comando_test_agent_mbx;
