module apu_envelope_generator_gen2(
		input wire clk,
		input wire rst,
		input wire clk_en,	// 1 clk pulse for every env gen update
		input wire[5:0] from_cpu,	// envelope value (e.g., via $4000)
		input wire env_wren,	// envelope value write
		input wire env_restart,	// envelope restart
		output wire[3:0] env_out);	// output volume
		
	reg[5:0] from_cpu_hold;
	reg[3:0] count;
	reg start_flag;
	reg[3:0] divider;
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			from_cpu_hold <= 6'h00;
			count <= 4'h0;
			start_flag <= 1'b0;
		end
		else
		begin
			if(env_wren)
				from_cpu_hold <= from_cpu;
			
			// When the divider outputs a clock, one of two actions occurs: If the counter is non-zero, it
			// is decremented, otherwise if the loop flag is set, the counter is loaded with 15.
			//if(divider_pulse_out)
			if(clk_en && divider == 4'h0)
			begin
				//TODO:divider reload
				divider <= from_cpu_hold[3:0];
				if(count != 4'h0)
					count <= count - 4'h1;
				else if(from_cpu_hold[5])
					count <= 4'hf;
			end
			
			// When clocked by the frame counter, one of two actions occurs: if the start flag is clear,
			// the divider is clocked, otherwise the start flag is cleared, the counter is loaded with 15,
			// and the divider's period is immediately reloaded.
			if(clk_en)
			begin
				if(start_flag == 1'b0)
				begin
					//TODO: clock divider
					divider <= divider - 4'h1;
				end
				else
				begin
					start_flag <= 1'b0;
					count <= 4'hf;
				end
			end
			
			if(env_restart)
			begin
				start_flag <= 1'b1;
			end
		end
	end
	
	// The envelope unit's volume output depends on the constant volume flag: if set, the envelope
	// parameter directly sets the volume, otherwise the counter's value is the current volume.
	assign env_out = (from_cpu_hold[4]) ? from_cpu_hold[3:0] : count;
endmodule