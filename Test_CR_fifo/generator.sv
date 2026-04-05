class generator #(parameter width = 16, parameter depth = 8);

	// Esta funcion la uso para no repetir comparaciones a cada rato.

	local function int max_int(int a, int b);
		return (a > b) ? a : b;
	endfunction

	// Esta es mi tarea base:
	// aqui armo una transaccion, le pongo tipo/retardo/dato y la mando al driver.
	local task automatic push_trans(
		trans_fifo_mbx agnt_drv_mbx,
		tipo_trans tipo,
		int max_retardo,
		bit [width-1:0] dato = '0,
		bit usar_dato = 0,
		int retardo_fijo = -1
	);
		trans_fifo #(.width(width)) transaccion;

		// aqui creo la transaccion y le pongo parametros base.
		transaccion = new;
		transaccion.max_retardo = max_retardo;

		// si me pasan retardo fijo lo uso; si no, la randomizo.
		if(retardo_fijo > 0) begin
			transaccion.retardo = retardo_fijo;
		end else begin
			transaccion.randomize();
		end

		// aqui defino el tipo de operacion.
		transaccion.tipo = tipo;

		if(usar_dato) begin
			transaccion.dato = dato;
		end

		// imprimo para debug y la mando al mailbox del driver.
		transaccion.print("Generador: transacción creada");
		agnt_drv_mbx.put(transaccion);
	endtask

	// con esto prelleno la fifo mandando solo escrituras.
	local task automatic prellenar_fifo(trans_fifo_mbx agnt_drv_mbx, int cantidad, int max_retardo);
		for(int i = 0; i < cantidad; i++) begin
			push_trans(agnt_drv_mbx, escritura, max_retardo);
		end
	endtask

	// aqui saco el patron 0,5,A,F para alternar datos.
	local function bit [width-1:0] patron_0_5_A_F(int idx);
		case(idx % 4)
			0: return {width/4{4'h0}};
			1: return {width/4{4'h5}};
			2: return {width/4{4'hA}};
			default: return {width/4{4'hF}};
		endcase
	endfunction

	// este es el caso comun: primero lleno y luego vacio.
	task gen_llenado_aleatorio(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		// primero meto escrituras.
		for(int i = 0; i < num_transacciones; i++) begin
			push_trans(agnt_drv_mbx, escritura, max_retardo);
		end

		// despues meto lecturas.
		for(int i = 0; i < num_transacciones; i++) begin
			push_trans(agnt_drv_mbx, lectura, max_retardo);
		end
	endtask

	// aqui genero una sola transaccion random.
	task gen_trans_aleatoria(trans_fifo_mbx agnt_drv_mbx, int max_retardo);
		trans_fifo #(.width(width)) transaccion;

		transaccion = new;
		transaccion.max_retardo = max_retardo;
		transaccion.randomize();
		transaccion.print("Generador: transacción creada");
		agnt_drv_mbx.put(transaccion);
	endtask

	// aqui genero una transaccion especifica (tipo, dato y retardo definidos).
	task gen_trans_especifica(
		trans_fifo_mbx agnt_drv_mbx,
		tipo_trans tpo_spec,
		bit [width-1:0] dto_spec,
		int ret_spec
	);
		push_trans(agnt_drv_mbx, tpo_spec, max_int(max_int(ret_spec + 1, 2), 10), dto_spec, 1, max_int(ret_spec, 1));
	endtask

	// aqui saco una secuencia de N transacciones random.
	task gen_sec_trans_aleatorias(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		for(int i = 0; i < num_transacciones; i++) begin
			gen_trans_aleatoria(agnt_drv_mbx, max_retardo);
		end
	endtask

	// aqui genero lectura y escritura al mismo tiempo.
	task gen_trans_lectura_escritura(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		for(int i = 0; i < num_transacciones; i++) begin
			push_trans(agnt_drv_mbx, lectura_escritura, max_retardo);
		end
	endtask

	// aqui meto escrituras con el patron 0/5/A/F.
	task gen_trans_pattern_0_5_A_F(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		for(int i = 0; i < num_transacciones; i++) begin
			push_trans(agnt_drv_mbx, escritura, max_retardo, patron_0_5_A_F(i), 1);
		end
	endtask

	// aqui fuerzo overflow escribiendo de mas.
	task gen_trans_overflow(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		int total_escrituras;
		total_escrituras = depth + max_int(2, num_transacciones/2);
		for(int i = 0; i < total_escrituras; i++) begin
			push_trans(agnt_drv_mbx, escritura, max_retardo);
		end
	endtask

	// aqui fuerzo underflow leyendo cuando ya no hay datos.
	task gen_trans_underflow(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		for(int i = 0; i < max_int(2, num_transacciones); i++) begin
			push_trans(agnt_drv_mbx, lectura, max_retardo);
		end
	endtask

	// aqui pruebo pop/push con ocupacion baja.
	task gen_trans_poppush_bajo(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		prellenar_fifo(agnt_drv_mbx, max_int(1, depth/4), max_retardo);
		for(int i = 0; i < max_int(2, num_transacciones); i++) begin
			push_trans(agnt_drv_mbx, lectura_escritura, max_retardo);
		end
	endtask

	// aqui pruebo pop/push con ocupacion media.
	task gen_trans_poppush_medio(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		prellenar_fifo(agnt_drv_mbx, max_int(1, depth/2), max_retardo);
		for(int i = 0; i < max_int(2, num_transacciones); i++) begin
			push_trans(agnt_drv_mbx, lectura_escritura, max_retardo);
		end
	endtask

	// aqui pruebo pop/push con ocupacion alta.
	task gen_trans_poppush_alto(trans_fifo_mbx agnt_drv_mbx, int num_transacciones, int max_retardo);
		prellenar_fifo(agnt_drv_mbx, max_int(1, (3*depth)/4), max_retardo);
		for(int i = 0; i < max_int(2, num_transacciones); i++) begin
			push_trans(agnt_drv_mbx, lectura_escritura, max_retardo);
		end
	endtask

	// aqui lleno la fifo y luego meto reset.
	task gen_reset_full_aleatorio(trans_fifo_mbx agnt_drv_mbx, int max_retardo);
		prellenar_fifo(agnt_drv_mbx, depth, max_retardo);
		push_trans(agnt_drv_mbx, reset, max_retardo);
	endtask

	// aqui meto reset con la fifo vacia.
	task gen_reset_empty_aleatorio(trans_fifo_mbx agnt_drv_mbx, int max_retardo);
		push_trans(agnt_drv_mbx, reset, max_retardo);
	endtask

	// aqui dejo la fifo a la mitad y luego meto reset.
	task gen_reset_half_aleatorio(trans_fifo_mbx agnt_drv_mbx, int max_retardo);
		prellenar_fifo(agnt_drv_mbx, max_int(1, depth/2), max_retardo);
		push_trans(agnt_drv_mbx, reset, max_retardo);
	endtask

endclass