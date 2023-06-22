module apu_pulse_1(
		input wire clk,
		input wire rst,
		input wire pulse_en,               // enable (via $4015)
		input wire apu_clk,  // 1 clk pulse on every cpu cycle
		input wire l_pulse,         // 1 clk pulse for every length counter decrement
		input wire e_pulse,         // 1 clk pulse for every env gen update
		input wire[1:0] a_in,                // control register addr (i.e. $4000 - $4003)
		input wire[7:0] from_cpu,            // control register write value
		input wire wren,              // enable control register write
		output wire[3:0] pulse_out,   // pulse channel output
		output wire active_out);      // pulse channel active (length counter > 0)

	//
	// Envelope
	//
	wire envelope_generator_wr;
	wire envelope_generator_restart;
	wire[3:0] envelope_generator_out;

	apu_envelope_generator_gen2 envelope_generator_inst(
		.clk(clk),
		.rst(rst),
		.clk_en(e_pulse),
		.from_cpu(from_cpu[5:0]),
		.env_wren(envelope_generator_wr),
		.env_restart(envelope_generator_restart),
		.env_out(envelope_generator_out));

	assign envelope_generator_wr      = wren && (a_in == 2'b00);
	assign envelope_generator_restart = wren && (a_in == 2'b11);
	
	reg[10:0] timer_period;
	reg[10:0] timer_count;
	wire timer_pulse;
	
	reg[1:0] duty;
	reg[2:0] sequencer_cnt;
	reg seq_bit;
	
	reg sweep_reload;
	reg[7:0] from_cpu_hold;
	reg[2:0] sweep_count;
	wire sweep_pulse;
	reg sweep_silence;
	reg[11:0] sweep_target_period;
	
	reg length_counter_halt;
	wire length_counter_wr;
	wire length_counter_en;
	
	assign timer_pulse = apu_clk & (timer_count == 11'h000);
	assign sweep_pulse = l_pulse & (sweep_count == 3'h0);
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			timer_period <= 11'h000;
			timer_count <= 11'h000;
			duty <= 2'h0;
			sequencer_cnt <= 3'h0;
			sweep_reload <= 1'b0;
			from_cpu_hold <= 8'h00;
			length_counter_halt <= 1'b0;
		end
		else
		begin
			//timer
			if(apu_clk)
			begin
				if(timer_count)
					timer_count <= timer_count - 11'h001;
				else
					timer_count <= timer_period;
			end
			
			//sequencer
			if(wren && (a_in == 2'b00))
				duty <= from_cpu[7:6];

			if(timer_pulse)
				sequencer_cnt <= sequencer_cnt - 3'h1;
				
			//sweep
			if(wren && (a_in == 2'b01))
			begin
				from_cpu_hold <= from_cpu;
				sweep_reload <= 1'b1;
			end
			else if(l_pulse)
			begin
				sweep_reload <= 1'b0;
			end
			
			if(l_pulse)
			begin
				sweep_count <= sweep_count - 3'h1;
				if(sweep_reload || (sweep_count == 3'h0))
					sweep_count <= from_cpu_hold[6:4];
			end
			
			if(wren && (a_in == 2'b10))
				timer_period[7:0] <= from_cpu;
			if(wren && (a_in == 2'b11))
				timer_period[10:8] <= from_cpu[2:0];
			
			if(sweep_pulse && from_cpu_hold[7] && !sweep_silence && (from_cpu_hold[2:0] != 3'h0))
				timer_period <= sweep_target_period[10:0];
				
			//length counter
			if(wren && (a_in == 2'b00))
				length_counter_halt <= from_cpu[5];
		end
	end
	
	always @(*)
	begin
		//sequencer
		case(duty)
			2'h0: seq_bit = &sequencer_cnt[2:0];
			2'h1: seq_bit = &sequencer_cnt[2:1];
			2'h2: seq_bit = sequencer_cnt[2];
			2'h3: seq_bit = ~&sequencer_cnt[2:1];
		endcase
		
		//sweep
		if(~from_cpu_hold[3])
			sweep_target_period = timer_period + (timer_period >> from_cpu_hold[2:0]);
		else
			sweep_target_period = timer_period + ~(timer_period >> from_cpu_hold[2:0]);
			
		sweep_silence = (timer_period[10:3] == 8'h00) || sweep_target_period[11];
	end
	
//	apu_length_counter length_counter(
//		.clk_in(clk),
//		.rst_in(rst),
//		.en_in(pulse_en),
//		.halt_in(length_counter_halt),
//		.length_pulse_in(l_pulse),
//		.length_in(from_cpu[7:3]),
//		.length_wr_in(length_counter_wr),
//		.en_out(length_counter_en));
	apu_length_counter_gen2 length_counter_inst(
		.clk(clk),
		.rst(rst),
		.length_en(pulse_en),
		.length_halt(length_counter_halt),
		.l_pulse(l_pulse),
		.from_cpu(from_cpu[7:3]),
		.length_wren(length_counter_wr),
		.active_out(length_counter_en));
		
	assign length_counter_wr = wren && (a_in == 2'b11);
	assign pulse_out = {4{seq_bit & length_counter_en & ~sweep_silence}} & envelope_generator_out;
	assign active_out = length_counter_en;
endmodule

module apu_pulse_2(
		input wire clk,
		input wire rst,
		input wire pulse_en,               // enable (via $4015)
		input wire apu_clk,  // 1 clk pulse on every cpu cycle
		input wire l_pulse,         // 1 clk pulse for every length counter decrement
		input wire e_pulse,         // 1 clk pulse for every env gen update
		input wire[1:0] a_in,                // control register addr (i.e. $4000 - $4003)
		input wire[7:0] from_cpu,            // control register write value
		input wire wren,              // enable control register write
		output wire[3:0] pulse_out,   // pulse channel output
		output wire active_out);      // pulse channel active (length counter > 0)

	//
	// Envelope
	//
	wire envelope_generator_wr;
	wire envelope_generator_restart;
	wire[3:0] envelope_generator_out;

	apu_envelope_generator_gen2 envelope_generator_inst(
		.clk(clk),
		.rst(rst),
		.clk_en(e_pulse),
		.from_cpu(from_cpu[5:0]),
		.env_wren(envelope_generator_wr),
		.env_restart(envelope_generator_restart),
		.env_out(envelope_generator_out));

	assign envelope_generator_wr      = wren && (a_in == 2'b00);
	assign envelope_generator_restart = wren && (a_in == 2'b11);
	
	reg[10:0] timer_period;
	reg[10:0] timer_count;
	wire timer_pulse;
	
	reg[1:0] duty;
	reg[2:0] sequencer_cnt;
	reg seq_bit;
	
	reg sweep_reload;
	reg[7:0] from_cpu_hold;
	reg[2:0] sweep_count;
	wire sweep_pulse;
	reg sweep_silence;
	reg[11:0] sweep_target_period;
	
	reg length_counter_halt;
	wire length_counter_wr;
	wire length_counter_en;
	
	assign timer_pulse = apu_clk & (timer_count == 11'h000);
	assign sweep_pulse = l_pulse & (sweep_count == 3'h0);
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			timer_period <= 11'h000;
			timer_count <= 11'h000;
			duty <= 2'h0;
			sequencer_cnt <= 3'h0;
			sweep_reload <= 1'b0;
			from_cpu_hold <= 8'h00;
			length_counter_halt <= 1'b0;
		end
		else
		begin
			//timer
			if(apu_clk)
			begin
				if(timer_count)
					timer_count <= timer_count - 11'h001;
				else
					timer_count <= timer_period;
			end
			
			//sequencer
			if(wren && (a_in == 2'b00))
				duty <= from_cpu[7:6];

			if(timer_pulse)
				sequencer_cnt <= sequencer_cnt - 3'h1;
				
			//sweep
			if(wren && (a_in == 2'b01))
			begin
				from_cpu_hold <= from_cpu;
				sweep_reload <= 1'b1;
			end
			else if(l_pulse)
			begin
				sweep_reload <= 1'b0;
			end
			
			if(l_pulse)
			begin
				sweep_count <= sweep_count - 3'h1;
				if(sweep_reload || (sweep_count == 3'h0))
					sweep_count <= from_cpu_hold[6:4];
			end
			
			if(wren && (a_in == 2'b10))
				timer_period[7:0] <= from_cpu;
			if(wren && (a_in == 2'b11))
				timer_period[10:8] <= from_cpu[2:0];
			
			if(sweep_pulse && from_cpu_hold[7] && !sweep_silence && (from_cpu_hold[2:0] != 3'h0))
				timer_period <= sweep_target_period[10:0];
				
			//length counter
			if(wren && (a_in == 2'b00))
				length_counter_halt <= from_cpu[5];
		end
	end
	
	always @(*)
	begin
		//sequencer
		case(duty)
			2'h0: seq_bit = &sequencer_cnt[2:0];
			2'h1: seq_bit = &sequencer_cnt[2:1];
			2'h2: seq_bit = sequencer_cnt[2];
			2'h3: seq_bit = ~&sequencer_cnt[2:1];
		endcase
		
		//sweep
		if(~from_cpu_hold[3])
			sweep_target_period = timer_period + (timer_period >> from_cpu_hold[2:0]);
		else
			sweep_target_period = timer_period + ~(timer_period >> from_cpu_hold[2:0]) + 1'b1;
			
		sweep_silence = (timer_period[10:3] == 8'h00) || sweep_target_period[11];
	end
	
//	apu_length_counter length_counter(
//		.clk_in(clk),
//		.rst_in(rst),
//		.en_in(pulse_en),
//		.halt_in(length_counter_halt),
//		.length_pulse_in(l_pulse),
//		.length_in(from_cpu[7:3]),
//		.length_wr_in(length_counter_wr),
//		.en_out(length_counter_en));
	apu_length_counter_gen2 length_counter_inst(
		.clk(clk),
		.rst(rst),
		.length_en(pulse_en),
		.length_halt(length_counter_halt),
		.l_pulse(l_pulse),
		.from_cpu(from_cpu[7:3]),
		.length_wren(length_counter_wr),
		.active_out(length_counter_en));
		
	assign length_counter_wr = wren && (a_in == 2'b11);
	assign pulse_out = {4{seq_bit & length_counter_en & ~sweep_silence}} & envelope_generator_out;
	assign active_out = length_counter_en;
endmodule