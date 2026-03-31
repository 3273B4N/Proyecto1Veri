`timescale 1ns/1ps
`include "fifo.sv"
`include "interface_transactions.sv"
`include "driver.sv"
`include "checker.sv"
`include "score_board.sv"
`include "agent.sv"
`include "ambiente.sv"
`include "Test_nuevo.sv" // LISTO

///////////////////////////////////
// Módulo para correr la prueba  //
///////////////////////////////////
module test_bench; 
  reg clk;
  // estos parametros se deben randomizar pero no se como xd
   parameter width = 16;
   parameter depth = 8;
  test_base #(.depth(depth),.width(width)) t0;
  // este va a ser el parametro que me indique el tipo de prueba a ejecutar
  string nombre_test;
  fifo_if  #(.width(width)) _if(.clk(clk));
  always #5 clk = ~clk;

//  fifo_flops #(.depth(depth),.bits(width)) uut(
//    .Din(_if.dato_in),
//    .Dout(_if.dato_out),
//    .push(_if.push),
//    .pop(_if.pop),
//    .clk(_if.clk),
//    .full(_if.full),
//    .pndng(_if.pndng),
//    .rst(_if.rst)
//  );


    fifo_generic #(.Depth(depth),.DataWidth(width)) uut(
    .writeData(_if.dato_in),
    .readData(_if.dato_out),
    .writeEn(_if.push),
    .readEn(_if.pop),
    .clk(_if.clk),
    .full(_if.full),
    .pndng(_if.pndng),
    .rst(_if.rst)
  );
  // aca se van a pedir los plusargs para configurar la prueba, segun la prueba se va a instanciar un hijo de la clase padre 
  initial begin
    clk = 0;
    // se lee el nombre de la prueba a ejecutar 
    if (!$value$plusargs("TEST=%s", nombre_test)) begin
        nombre_test = "base"; // Test por defecto si no se pone nada
    end

    // Selección dinámica del objeto segun la prueba
    case(nombre_test)
      "base":        t0 = new(_if); 
      "intercalado": begin
                       test_intercalado #(.depth(depth), .width(width)) t_int;
                       t_int = new(_if);
                       t0 = t_int; 
                     end
      "reset":       begin
                       test_reset_random #(.depth(depth), .width(width)) t_rst;
                       t_rst = new(_if);
                       t0 = t_rst;
                     end
      "overflow":    begin
                       test_overflow #(.depth(depth), .width(width)) t_ovf;
                       t_ovf = new(_if);
                       t0 = t_ovf;
                     end
      "underflow":   begin
                       test_underflow #(.depth(depth), .width(width)) t_uf;
                        t_uf = new(_if);
                        t0 = t_uf;
                      end
      "pop_push":    begin
                       test_pop_push #(.depth(depth), .width(width)) t_pp;
                       t_pp = new(_if);
                       t0 = t_pp;
                      end
      "reset_empty": begin 
                       test_reset_random_empty #(.depth(depth), .width(width)) t_rste;
                       t_rste = new(_if);
                       t0 = t_rste;
                      end  
      "reset_full": begin   
                       test_reset_random_full #(.depth(depth), .width(width)) t_rstf;
                       t_rstf = new(_if);
                       t0 = t_rstf;
                      end
                      
      "reset_half": begin   
                       test_reset_random_half #(.depth(depth), .width(width)) t_rsth;
                       t_rsth = new(_if);
                       t0 = t_rsth;
                      end

      default:       t0 = new(_if);
    endcase

    fork
      t0.run();
    join_none
  end
 
  always@(posedge clk) begin
    if ($time > 100000)begin
      $display("Test_bench: Tiempo límite de prueba en el test_bench alcanzado");
      $finish;
    end
  end
endmodule
