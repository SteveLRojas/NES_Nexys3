module rp2a03_dma(
		input wire clk,
		input wire cpu_clk,
		input wire rst,
		input wire spr_trig,		// Sprite DMA trigger
		input wire dmc_trig,		// DMC DMA trigger
		input wire cpu_r_nw,		// CPU is in a read cycle
		input wire[7:0] from_cpu,		// Data written by CPU
		input wire[7:0] from_ram,		// Data read from RAM
		input wire[15:0] dmc_dma_addr,		// DMC DMA Address
		output reg[15:0] a_out,		// Address to access
		output reg dma_active,		// DMA controller wants bus control
		output reg cpu_ready,		// low to pause CPU
		output reg dma_r_nw,		// 1 = read, 0 = write
		output wire[7:0] to_ram,		// Value to write to RAM
		output reg dmc_ack);		// ACK the DMC DMA

	//enum logic[2:0] {S_READY, S_SPR_READ, S_SPR_WRITE, S_DMC_WAIT, S_DMC_READ, S_DMC_READ_INT, S_DONE} state;
	reg[2:0] state;
	localparam S_READY = 0;
	localparam S_SPR_READ = 1;
	localparam S_SPR_WRITE = 2;
	localparam S_DMC_WAIT = 3;
	localparam S_DMC_READ = 4;
	localparam S_DMC_READ_INT = 5;
	localparam S_DONE = 6;
	
	reg[15:0] spr_address;
	reg[7:0] spr_data;
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			state <= S_READY;
		end
		else
		begin
			//slow logic to set states
			if(cpu_clk)
			begin
				case(state)
					S_READY:
					begin
						if(spr_trig)
							state <= S_SPR_READ;
						if(dmc_trig)
							state <= S_DMC_WAIT;
						spr_address[15:8] <= from_cpu;
						spr_address[7:0] <= 8'h00;
					end
					S_SPR_READ:
					begin
						state <= S_SPR_WRITE;
					end
					S_SPR_WRITE:
					begin
						if(dmc_trig)
						begin
							if(&spr_address[7:0])
								state <= S_DMC_READ;
							else
								state <= S_DMC_READ_INT;
						end
						else
						begin
							if(&spr_address[7:0])
								state <= S_DONE;
							else
								state <= S_SPR_READ;
						end
						spr_address[7:0] <= spr_address[7:0] + 8'h01;
					end
					S_DMC_WAIT:
					begin
						if(cpu_r_nw)
							state <= S_DMC_READ;
					end
					S_DMC_READ:
					begin
						state <= S_DONE;
					end
					S_DMC_READ_INT:
					begin
						state <= S_SPR_READ;
					end
					S_DONE:
					begin
						if(cpu_r_nw)
							state <= S_READY;
					end
					default: ;
				endcase
			end
			//fast logic to set outputs
			case(state)
				S_READY:
				begin
					a_out <= 16'hxxxx;
					dma_active <= 1'b0;
					cpu_ready <= 1'b1;
					dma_r_nw <= 1'b1;
					dmc_ack <= 1'b0;
				end
				S_SPR_READ:
				begin
					a_out <= spr_address;
					dma_active <= 1'b1;
					cpu_ready <= 1'b0;
					dma_r_nw <= 1'b1;
					dmc_ack <= 1'b0;
					spr_data <= from_ram;
				end
				S_SPR_WRITE:
				begin
					a_out <= 16'h2004;
					dma_active <= 1'b1;
					cpu_ready <= 1'b0;
					dma_r_nw <= 1'b0;
					dmc_ack <= 1'b0;
				end
				S_DMC_WAIT:
				begin
					a_out <= 16'hxxxx;
					dma_active <= 1'b0;
					cpu_ready <= 1'b0;
					dma_r_nw <= 1'b1;
					dmc_ack <= 1'b0;
				end
				S_DMC_READ, S_DMC_READ_INT:
				begin
					a_out <= dmc_dma_addr;
					dma_active <= 1'b1;
					cpu_ready <= 1'b0;
					dma_r_nw <= 1'b1;
					dmc_ack <= 1'b1;
				end
				S_DONE:
				begin
					a_out <= 16'hxxxx;
					dma_active <= 1'b0;
					cpu_ready <= 1'b1;
					dma_r_nw <= 1'b1;
					dmc_ack <= 1'b0;
				end
				default: ;
			endcase
		end
	end
	
	assign to_ram = spr_data;

endmodule