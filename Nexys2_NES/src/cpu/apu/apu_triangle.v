module apu_triangle_gen2(
		input  wire      clk,
		input  wire      rst,
		input  wire      triangle_en,   // enable (via $4015)
		input  wire      cpu_clk,  		// 1 clk pulse on every cpu cycle
		input  wire      l_pulse,       // 1 clk pulse for every length counter decrement
		input  wire      e_pulse,       // 1 clk pulse for every env gen update
		input  wire[1:0] a_in,          // control register addr (i.e. $400C - $400F)
		input  wire[7:0] from_cpu,      // control register write value
		input  wire      wren,          // enable control register write
		output wire[3:0] triangle_out,  // triangle channel output
		output wire      active_out);   // triangle channel active (length counter > 0)

	reg[10:0] timer_period;
	reg[10:0] timer_count;
	wire timer_pulse;
	
	reg linear_counter_halt;
	reg[7:0] linear_counter_ctrl;
	reg[6:0] linear_counter_val;
	
	reg length_counter_halt;
	wire length_wren;
	wire length_counter_ao;
	
	reg[4:0] seq;
	wire[3:0] seq_out;
		
	assign timer_pulse = cpu_clk && (timer_count == 11'h000);
	assign length_wren = wren && (a_in == 2'b11);
	assign seq_out = (seq[4]) ? seq[3:0] : ~seq[3:0];
		
	always @(posedge clk)
	begin
		if(rst)
		begin
			timer_period <= 11'h000;
			linear_counter_halt <= 1'b0;
			linear_counter_ctrl <= 8'h00;
			linear_counter_val  <= 7'h00;
			length_counter_halt <= 1'b0;
			seq <= 5'h0;
		end
		else 
		begin
			//timer
			if(cpu_clk)
			begin
				if(timer_count != 11'h000)
					timer_count <= (timer_count - 11'h001);
				else
					timer_count <= timer_period;
			end
			
			if(wren && (a_in == 2'b10))
				timer_period[7:0] <= from_cpu;
			if(wren && (a_in == 2'b11))
				timer_period[10:8] <= from_cpu[2:0];
				
			//linear counter
			if (wren && (a_in == 2'b00))
				linear_counter_ctrl <= from_cpu;
				
			if (e_pulse && linear_counter_halt)
				linear_counter_val <= linear_counter_ctrl[6:0];
			else if (e_pulse && (linear_counter_val != 7'h00))
				linear_counter_val <= (linear_counter_val - 7'h01);
				
			if (wren && (a_in == 2'b11))
				linear_counter_halt <= 1'b1;
			else if (e_pulse & ~linear_counter_ctrl[7])
				linear_counter_halt <= 1'b0;
			
			//length counter
			if (wren && (a_in == 2'b00))
				length_counter_halt <= from_cpu[7];
				
			//sequencer
			if (active_out && timer_pulse)
				seq <= (seq + 5'h01);		
		end
	end

	apu_length_counter_gen2 length_counter(
			.clk(clk),
			.rst(rst),
			.length_en(triangle_en),
			.length_halt(length_counter_halt),
			.l_pulse(l_pulse),
			.from_cpu(from_cpu[7:3]),
			.length_wren(length_wren),
			.active_out(length_counter_ao));
			
	assign active_out   = (|linear_counter_val) && length_counter_ao;
	assign triangle_out = seq_out;
	
endmodule