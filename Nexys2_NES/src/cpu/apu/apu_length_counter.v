module apu_length_counter_gen2(
		input wire clk,
		input wire rst,
		input wire length_en,		// enable signal (from $4015)
		input wire length_halt,	// disable length decrement
		input wire l_pulse,			// length pulse from frame counter
		input wire[4:0] from_cpu,	// new length value
		input wire length_wren,	// update length to length_in
		output wire active_out);	// length counter is non-0
		
	reg[7:0] length;
	
	always @(posedge clk)
	begin
		if(rst | ~length_en)
		begin
			length <= 8'h00;
		end
		else
		begin
			if(length_wren)
			begin
				case ({from_cpu[4], from_cpu[0]})
					2'b11, 2'b01:
					begin
						length <= {3'h0, from_cpu[4:1], 1'b0} | {{7{~(|from_cpu[4:1])}}, 1'b0};
					end
					2'b10:
					begin
						case (from_cpu[3:1])
							3'b111: length <= 8'd32;
							3'b110: length <= 8'd16;
							3'b101: length <= 8'd72;
							3'b100: length <= 8'd192;
							3'b011: length <= 8'd96;
							3'b010: length <= 8'd48;
							3'b001: length <= 8'd24;
							3'b000: length <= 8'd12;
						endcase
					end
					2'b00:
					begin
						case (from_cpu[3:1])
							3'b111: length <= 8'd26;
							3'b110: length <= 8'd14;
							3'b101: length <= 8'd60;
							3'b100: length <= 8'd160;
							3'b011: length <= 8'd80;
							3'b010: length <= 8'd40;
							3'b001: length <= 8'd20;
							3'b000: length <= 8'd10;
						endcase
					end
				endcase
			end
			else if(l_pulse & ~length_halt & (|length))
			begin
				length <= length - 8'h01;
			end
		end
	end

	assign active_out = |length;
		
endmodule