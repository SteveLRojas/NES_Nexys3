module flash_model(
		input wire clk,
		input wire[14:0] flash_address,
		input wire flash_ce_n,
		input wire flash_oe_n,
		input wire flash_we_n,
		inout wire[15:0] flash_data
	);
	
	wire[15:0] bram_dout;
	wire bram_wren;
	
	assign flash_data = (~flash_ce_n & ~flash_oe_n & flash_we_n) ? bram_dout : 16'hZZZZ;
	assign bram_wren = ~flash_ce_n & ~flash_we_n;
	
	RAM_32K_word RAM_32K_word_i(
		.clka(clk),
		.wea(bram_wren),
		.addra(flash_address),
		.dina(flash_data),
		.douta(bram_dout)
	);
	
endmodule
