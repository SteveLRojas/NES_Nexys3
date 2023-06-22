module apu_gen2(
		input wire clk,
		input wire cpu_clk,
		input wire rst,						// reset signal
		input wire[15:0] a_in,				// addr input bus
		input wire[7:0] from_cpu,			// data input bus
		input wire r_nw,						// read/write select
		input wire dma_ack,					// DMA Acknowledge
		input wire[7:0] from_mem,			// Data from memory via DMA request
		output wire dma_req,				// DMA Request
		output wire[14:0] dma_address, 	// Address of DMA request (next sample for DMC)
		output wire audio_out,				// pwm audio output
		output wire[7:0] to_cpu,			// data output bus
		output wire irq);
	
	// Shared
	reg apu_clk_div;
	wire apu_clk;
	
	wire e_pulse;
	wire l_pulse;
	wire f_pulse;
		
	wire read_status;
	wire write_status;
	reg frame_interrupt;
	wire frame_counter_mode_wr;
	

	// Pulse 1
	reg pulse1_en;
	wire[3:0] pulse1_out;
	wire pulse1_active;
	wire pulse1_wr;
	
	// Pulse 2 
	reg pulse2_en;
	wire[3:0] pulse2_out;
	wire pulse2_active;
	wire pulse2_wr;
	
	// Triangle
	reg triangle_en;
	wire[3:0] triangle_out;
	wire triangle_active;
	wire triangle_wr;
	
	// Noise
	reg noise_en;
	wire[3:0] noise_out;
	wire noise_active;
	wire noise_wr;
	
	// DMC
	wire dmc_interrupt;
	wire [6:0] dmc_out;
	wire dmc_active;
	wire dmc_wr;
	
	assign apu_clk = cpu_clk & ~apu_clk_div;
	assign frame_counter_mode_wr = ~r_nw && (a_in == 16'h4017);
	assign read_status = r_nw & (a_in == 16'h4015);
	assign write_status = ~r_nw & (a_in == 16'h4015);
	
	assign pulse1_wr 		= ~r_nw & (a_in[15:2] == 14'h1000);		//01 0000 0000 0000
	assign pulse2_wr 		= ~r_nw & (a_in[15:2] == 14'h1001);		//01 0000 0000 0001
	assign triangle_wr 	= ~r_nw & (a_in[15:2] == 14'h1002);		//01 0000 0000 0010
	assign noise_wr 		= ~r_nw & (a_in[15:2] == 14'h1003);		//01 0000 0000 0011
	assign dmc_wr			= ~r_nw & (a_in[15:2] == 14'h1004);		//01 0000 0000 0100
	
	always @(posedge clk)
	begin
		if(rst)
		begin
			pulse1_en 	<= 1'b0;
			pulse2_en 	<= 1'b0;
			triangle_en <= 1'b0;
			noise_en 	<= 1'b0;
			apu_clk_div <= 1'b0;
			frame_interrupt <= 1'b0;
		end
		else
		begin
			if(cpu_clk)
				apu_clk_div <= ~apu_clk_div;
			
			if(write_status)
			begin
				pulse1_en	<= from_cpu[0];
				pulse2_en 	<= from_cpu[1];
				triangle_en <= from_cpu[2];
				noise_en 	<= from_cpu[3];
			end
			
			if((frame_counter_mode_wr & from_cpu[6]) || (read_status & cpu_clk))	//write one to frame interrupt or read status
				frame_interrupt <= 1'b0;
			if(f_pulse)
				frame_interrupt <= 1'b1;
		
		end
	end
	
	apu_frame_counter_gen2 apu_frame_counter_inst(
			.clk(clk),
			.rst(rst),
			.apu_clk_pulse(apu_clk),
			.to_apu(from_cpu[7:6]),
			.mode_wren(frame_counter_mode_wr),
			.e_pulse(e_pulse),
			.l_pulse(l_pulse),
			.f_pulse(f_pulse));
			
	apu_pulse_1 apu_pulse_1_inst(
			.clk(clk),
			.rst(rst),
			.pulse_en(pulse1_en),
			.apu_clk(apu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(pulse1_wr),
			.pulse_out(pulse1_out),
			.active_out(pulse1_active));
			
	apu_pulse_2 apu_pulse_2_inst(
			.clk(clk),
			.rst(rst),
			.pulse_en(pulse2_en),
			.apu_clk(apu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(pulse2_wr),
			.pulse_out(pulse2_out),
			.active_out(pulse2_active));
			
	apu_triangle_gen2 apu_triangle_inst(
			.clk(clk),
			.rst(rst),
			.triangle_en(triangle_en),
			.cpu_clk(cpu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(triangle_wr),
			.triangle_out(triangle_out),
			.active_out(triangle_active));
			
	apu_noise_gen2 apu_noise_inst(
			.clk(clk),
			.rst(rst),
			.noise_en(noise_en),
			.apu_clk(apu_clk),
			.l_pulse(l_pulse),
			.e_pulse(e_pulse),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.wren(noise_wr),
			.noise_out(noise_out),
			.active_out(noise_active));
	
	apu_dmc dmc_inst(
			.clk(clk),
			.apu_clk(apu_clk),
			.cpu_clk(cpu_clk),
			.rst(rst),
			.a_in(a_in[1:0]),
			.from_cpu(from_cpu),
			.ri_wren(dmc_wr),
			.status_wren(write_status),
			.dma_req(dma_req),
			.dma_ack(dma_ack),
			.dma_address(dma_address),
			.from_mem(from_mem),
			.dmc_irq(dmc_interrupt),
			.dmc_out(dmc_out),
			.dmc_active(dmc_active));
//	assign dma_req = 1'b0;
//	assign dma_address = 15'h4000;
//	assign dmc_interrupt = 1'b0;
//	assign dmc_out = 7'h00;
//	assign dmc_active = 1'b0;
	  
	apu_mixer_gen2 apu_mixer_inst(
			.clk(clk),
			.from_dmc(dmc_out),
			.from_pulse1(pulse1_out),
			.from_pulse2(pulse2_out),
			.from_triangle(triangle_out),
			.from_noise(noise_out),
			.audio_out(audio_out));

			
	assign to_cpu = {{8{read_status}} & {dmc_interrupt, frame_interrupt, 1'b0, dmc_active, noise_active, triangle_active, pulse2_active, pulse1_active}};
	assign irq = frame_interrupt | dmc_interrupt;
	
endmodule
	