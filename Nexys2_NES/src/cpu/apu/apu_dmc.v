module apu_dmc(
		input wire clk,
		input wire apu_clk,
		input wire cpu_clk,
		input wire rst,
		
		input wire[1:0] a_in,
		input wire[7:0] from_cpu,
		input wire ri_wren,
		input wire status_wren,
		
		output wire dma_req,
		input wire dma_ack,
		output reg[14:0] dma_address,	//bit 15 always 1
		input wire[7:0] from_mem,
		output reg dmc_irq,
		
		output reg[6:0] dmc_out,
		output wire dmc_active);		

	reg[7:0] shift;
	reg[7:0] buffer;
	reg[2:0] bits_remaining;
	reg[7:0] timer;
	reg[3:0] rate;
	wire timer_pulse;
	reg[11:0] bytes_remaining;
	reg buffer_valid;
	reg shift_valid;
	
	reg dmc_enable;
	reg irq_enable;
	reg loop_flag;
	reg[7:0] ri_sample_address;
	reg[7:0] ri_sample_len;

	assign timer_pulse = apu_clk & (timer[7:1] == 7'h00);	//timer counts down to 1
	assign dma_req = dmc_enable & ~buffer_valid;
	assign dmc_active = dmc_enable;
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			bits_remaining <= 3'h0;
			dmc_out <= 7'h00;
			dmc_enable <= 1'b0;
			irq_enable <= 1'b0;
			buffer_valid <= 1'b0;
			shift_valid <= 1'b0;
		end
		else
		begin
			//timer
			if(apu_clk)
			begin
				timer <= timer - 8'h01;
				if(timer[7:1] == 7'h00)
				begin
					case(rate)
						4'h0: timer <= 214;
						4'h1: timer <= 190;
						4'h2: timer <= 170;
						4'h3: timer <= 160;
						4'h4: timer <= 143;
						4'h5: timer <= 127;
						4'h6: timer <= 113;
						4'h7: timer <= 107;
						4'h8: timer <= 95;
						4'h9: timer <= 80;
						4'hA: timer <= 71;
						4'hB: timer <= 64;
						4'hC: timer <= 53;
						4'hD: timer <= 42;
						4'hE: timer <= 36;
						4'hF: timer <= 27;
					endcase
				end
			end
			
			//bits remaining
			if(timer_pulse)
				bits_remaining <= bits_remaining - 3'h1;
				
			//ri
			dmc_irq <= dmc_irq & irq_enable;
			if(ri_wren)
			begin
				case(a_in)
					2'b00:
					begin
						irq_enable <= from_cpu[7];
						loop_flag <= from_cpu[6];
						rate <= from_cpu[3:0];
					end
					2'b01:
					begin
						dmc_out <= from_cpu[6:0];
					end
					2'b10:
					begin
						ri_sample_address <= from_cpu[7:0];
					end
					2'b11:
					begin
						ri_sample_len <= from_cpu[7:0];
					end
				endcase
			end
			if(status_wren)
			begin
				dmc_irq <= 1'b0;
				dmc_enable <= from_cpu[4];
				if(from_cpu[4] & ~dmc_enable)	//restart DMC only if previously disabled.
				begin
					dma_address <= {1'b1, ri_sample_address, 6'h00};
					bytes_remaining <= {ri_sample_len, 4'h0};
				end
			end
			
			//output unit
			if(timer_pulse)
			begin
				shift <= {1'b0, shift[7:1]};
				if(bits_remaining == 3'h0)
				begin
					shift_valid <= buffer_valid;
					shift <= buffer;
					buffer_valid <= 1'b0;
				end
				if(shift_valid)
				begin
					case(shift[0])
						1'b0:
						begin
							if(|dmc_out[6:1])
								dmc_out[6:1] <= dmc_out[6:1] - 6'h01;
						end
						1'b1:
						begin
							if(~(&dmc_out[6:1]))
								dmc_out[6:1] <= dmc_out[6:1] + 6'h01;
						end
					endcase
				end
			end
			
			//DMA
			if(dma_ack & cpu_clk)
			begin
				dma_address <= dma_address + 15'h0001;
				bytes_remaining <= bytes_remaining - 12'h001;
				buffer_valid <= 1'b1;
				buffer <= from_mem;
				if(bytes_remaining == 12'h000)
				begin
					dma_address <= {1'b1, ri_sample_address, 6'h00};
					bytes_remaining <= {ri_sample_len, 4'h0};
					dmc_enable <= loop_flag;
					if(!loop_flag)
						dmc_irq <= irq_enable;
				end
			end
		end
	end

endmodule