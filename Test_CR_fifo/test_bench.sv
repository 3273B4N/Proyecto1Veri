`timescale 1ns/1ps
`include "fifo.sv"
`include "interface_transactions.sv"
`include "driver.sv"
`include "checker.sv"
`include "monitor.sv"
`include "score_board.sv"
`include "generator.sv"
`include "agent.sv"
`include "ambiente.sv"
`include "test_nuevo.sv"

///////////////////////////////////
// Módulo para correr la prueba  //
///////////////////////////////////
module test_bench; 
  reg clk;
  parameter width = 16;
  parameter depth = 8;
  test_base #(.depth(depth),.width(width)) t0;
  string test_name;

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

  initial begin
    clk = 0;

    if(!$value$plusargs("TEST=%s", test_name)) begin
      test_name = "test_base";
    end

    case(test_name)
      "test_base": t0 = test_base #(.depth(depth),.width(width))::new(_if);
      "test_trans_aleatoria": t0 = test_trans_aleatoria #(.depth(depth),.width(width))::new(_if);
      "test_trans_especifica": t0 = test_trans_especifica #(.depth(depth),.width(width))::new(_if);
      "test_trans_lectura_escritura": t0 = test_trans_lectura_escritura #(.depth(depth),.width(width))::new(_if);
      "test_intercalado": t0 = test_intercalado #(.depth(depth),.width(width))::new(_if);
      "test_overflow": t0 = test_overflow #(.depth(depth),.width(width))::new(_if);
      "test_underflow": t0 = test_underflow #(.depth(depth),.width(width))::new(_if);
      "test_pop_push_bajo": t0 = test_pop_push_bajo #(.depth(depth),.width(width))::new(_if);
      "test_pop_push_medio": t0 = test_pop_push_medio #(.depth(depth),.width(width))::new(_if);
      "test_pop_push_alto": t0 = test_pop_push_alto #(.depth(depth),.width(width))::new(_if);
      "test_reset_full": t0 = test_reset_full #(.depth(depth),.width(width))::new(_if);
      "test_reset_empty": t0 = test_reset_empty #(.depth(depth),.width(width))::new(_if);
      "test_reset_half": t0 = test_reset_half #(.depth(depth),.width(width))::new(_if);
      "test_secuencia_aleatoria": t0 = test_secuencia_aleatoria #(.depth(depth),.width(width))::new(_if);
      default: begin
        $display("Test_bench Error: TEST=%s no existe", test_name);
        $finish;
      end
    endcase

    $display("Test_bench: Ejecutando %s", test_name);
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
