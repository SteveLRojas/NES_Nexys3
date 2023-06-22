module apu_mixer_gen2(
		input wire clk,
		input wire[6:0] from_dmc,
		input wire[3:0] from_pulse1,    // pulse 0 channel input
		input wire[3:0] from_pulse2,    // pulse 1 channel input
		input wire[3:0] from_triangle,  // triangle channel input
		input wire[3:0] from_noise,     // noise channel input
		output reg audio_out);     // mixed audio output

	//pulse multiplier (for pulse 1 + pulse 2): 2.243592 (144/64)
	//triangle multiplier: 2.5389585 (162/64)
	//noise multiplier: 1.473849 (94/64)
	//DMC multiplier: 0.9994725 (1/1)
	
	reg[6:0] dmc_hold;
	reg[3:0] pulse1_hold, pulse2_hold;
	reg[3:0] triangle_hold;
	reg[3:0] noise_hold;
	
	reg[4:0] combined_pulse;
	
	wire[15:0] pulse_result;
	wire[15:0] triangle_result;
	wire[15:0] noise_result;
	
	reg[6:0] scaled_pulse;
	reg[5:0] scaled_triangle;
	reg[4:0] scaled_noise;
	
	reg[7:0] pulse_triangle;
	reg[7:0] pulse_triangle_noise;
	reg[8:0] combined_sample;
	
	reg[7:0] pwm_counter;
	
	multiplier pulse_scaler(.a({3'h0, combined_pulse}), .b(8'd144), .p(pulse_result));
	multiplier traingle_scaler(.a({4'h0, triangle_hold}), .b(8'd162), .p(triangle_result));
	multiplier noise_scaler(.a({4'h0, noise_hold}), .b(8'd94), .p(noise_result));
	
	initial
	begin
		pwm_counter = 8'h00;
	end
	
	always @(posedge clk)
	begin
		dmc_hold <= from_dmc;
		pulse1_hold <= from_pulse1;
		pulse2_hold <= from_pulse2;
		triangle_hold <= from_triangle;
		noise_hold <= from_noise;
		
		combined_pulse <= pulse1_hold + pulse2_hold;
		
		scaled_pulse <= pulse_result[12:6];
		scaled_triangle <= triangle_result[11:6];
		scaled_noise <= noise_result[10:6];
		
		pulse_triangle <= scaled_pulse + scaled_triangle;
		pulse_triangle_noise <= pulse_triangle[6:0] + scaled_noise;
		combined_sample <= pulse_triangle_noise[6:0] + dmc_hold;
		
		pwm_counter <= pwm_counter + 8'h01;
		audio_out <= (combined_sample[7:0] > pwm_counter);
	end

endmodule