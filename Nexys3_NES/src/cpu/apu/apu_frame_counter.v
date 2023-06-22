module apu_frame_counter_gen2(
		input  wire clk,
		input  wire rst,
		input  wire apu_clk_pulse,	// 1 clk pulse on every apu cycle
		input  wire[1:0] to_apu,	// mode ([0] = IRQ inhibit, [1] = sequence mode)
		input  wire mode_wren,
		output reg e_pulse,	// envelope and linear counter pulse (~240 Hz)
		output reg l_pulse,	// length counter and sweep pulse (~120 Hz)
		output reg f_pulse);	// frame pulse (~60Hz, should drive IRQ)

	reg[14:0] apu_cycle_count;
	reg mode;
	reg mode_write_flag;
	reg mode_write;
	reg irq_inhibit;
	reg prev_mode_wren;
	reg[1:0] to_apu_hold;

	always @(posedge clk)
	begin
		e_pulse <= 1'b0;
		l_pulse <= 1'b0;
		f_pulse <= 1'b0;
		if(rst)
		begin
			apu_cycle_count <= 15'h0000;
			mode <= 1'b0;
			irq_inhibit <= 1'b1;
			prev_mode_wren <= 1'b0;
			mode_write <= 1'b0;
			mode_write_flag <= 1'b0;
		end
		else
		begin
			prev_mode_wren <= mode_wren;
			if(mode_wren & ~prev_mode_wren)
				mode_write_flag <= 1'b1;
			if(mode_wren)
				to_apu_hold <= to_apu;
			if(apu_clk_pulse)
			begin
				mode_write <= 1'b0;
				if(mode_write_flag)
				begin
					mode_write_flag <= 1'b0;
					mode_write <= 1'b1;
				end
				
				apu_cycle_count <= apu_cycle_count + 15'h0001;
				if(apu_cycle_count == 15'd18640 || (!mode && apu_cycle_count == 15'd14914))
					apu_cycle_count <= 15'h0000;
					
				if((apu_cycle_count == 15'd3728) || (apu_cycle_count == 15'd11185))
					e_pulse <= 1'b1;
				if(apu_cycle_count == 15'h7456)
				begin
					e_pulse <= 1'b1;
					l_pulse <= 1'b1;
				end
				if(!mode && apu_cycle_count == 15'd14914)
				begin
					e_pulse <= 1'b1;
					l_pulse <= 1'b1;
					f_pulse <= ~irq_inhibit;
				end
				if(apu_cycle_count == 18640)
				begin
					e_pulse <= mode;
					l_pulse <= mode;
				end
				
				if(mode_write)
				begin
					mode <= to_apu_hold[1];
					irq_inhibit <= to_apu_hold[0];
					apu_cycle_count <= 15'd18640;
				end
			end
		end
	end

endmodule