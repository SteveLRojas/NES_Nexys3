//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    20:30:26 06/22/2019 
// Design Name: cart
// Module Name:    cart_03
// Project Name: FPGA_NES
// Target Devices: XC6SLX9
// Tool versions: 
// Description: Mapper 03 for NES
//
// Dependencies: None
//
// Revision: 
// Revision 0.01 - File Created
// Revision 0.02 - Adapted file for Nexys3
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module cart_03(
		input wire clk_sys,				// system clock signal
		input wire clk_mem,
		input wire rst,
		output wire rst_out,
		// PRG-ROM interface.
		input wire prg_nce_in,			// prg-rom chip enable (active low)
		input wire[14:0] prg_a_in,		// prg-rom address
		input wire prg_r_nw_in,			// prg-rom read/write select
		input wire[7:0] prg_d_in,		// prg-rom data in
		output wire[7:0] prg_d_out,		// prg-rom data out
		// CHR ROM interface
		input wire[7:0] chr_d_in,
		output wire[7:0] chr_d_out,
		input wire[13:0] chr_a_in,
		input wire chr_r_nw_in,			// chr-rom read/write select
		output wire ciram_nce_out,
		output wire ciram_a10_out,
		//Flash and PSRAM interface
		output wire[22:0] shared_a,
		inout wire[15:0] shared_d,
		output wire shared_oe_n,
		output wire shared_we_n,
		output wire flash_ce_n,
		output wire flash_reset_n,
		output wire psram_ce_n,
		output wire shared_adv_n,
		output wire psram_cre,
		output wire shared_clk,
		output wire psram_lb_n,
		output wire psram_ub_n
	);

	reg reset_hold;
	reg init_req;
	reg [1:0] page;
	reg[7:0] chrrom_dout;
	reg[7:0] prgrom_dout;
	
	//wire chrram_we;
	wire[14:0] prg_mem_address;
	wire[14:0] chr_mem_address;
	wire[14:0] mem_address;
	wire[7:0] mem_dout;
	wire prg_addr_change;
	wire chr_addr_change;
	wire mem_ready;
	wire mem_req;
	wire mem_busy;
	wire req_type;
	
	reg[14:0] prev_prg_mem_address;
	reg[14:0] prev_chr_mem_address;
	reg mem_active;
	reg req_type_ff;
	reg addr_odd;
	
	assign ciram_a10_out = chr_a_in[11];	//A10 for vertical mirroring, A11 for horizontal
	assign ciram_nce_out = ~chr_a_in[13];
	assign prg_d_out = prgrom_dout & {8{~prg_nce_in}};
	assign chr_d_out = chrrom_dout & {8{ciram_nce_out}};
	assign rst_out = reset_hold;
	//assign chrram_we = ~chr_a_in[13] & ~chr_r_nw_in;
	
	assign prg_mem_address = prg_a_in;
	assign chr_mem_address = {page, chr_a_in[12:0]};
	assign prg_addr_change = prg_mem_address != prev_prg_mem_address;
	assign chr_addr_change = chr_mem_address != prev_chr_mem_address;
	assign mem_req = init_req | prg_addr_change | chr_addr_change;
	assign mem_busy = mem_active & ~mem_ready;
	assign req_type = chr_addr_change & ~(init_req | prg_addr_change);
	assign mem_address = req_type ? chr_mem_address : prg_mem_address;
	
	initial
	begin
		 page = 2'b00;
		 reset_hold = 1'b1;
		 init_req = 1'b1;
	end
	
	always @(posedge clk_sys or posedge rst)
	begin
		if(rst)
			page <= 2'b00;
		else if((~prg_r_nw_in) & (~prg_nce_in))   //register enabled by write to rom space
			page <= prg_d_in[1:0];
	end
	
	always @(posedge clk_mem or posedge rst)
	begin
		if(rst)
		begin
			reset_hold <= 1'b1;
			init_req <= 1'b1;
			chrrom_dout <= 8'h00;
			prgrom_dout <= 8'h00;
			prev_prg_mem_address <= 15'h0000;
			prev_chr_mem_address <= 15'h0000;
			mem_active <= 1'b0;
			req_type_ff <= 1'b0;
			addr_odd <= 1'b0;			
		end
		else
		begin
			if(mem_ready)
				reset_hold <= 1'b0;
			init_req <= 1'b0;
			mem_active <= mem_req | (mem_active & ~mem_ready);

			if(mem_req & ~mem_busy)
			begin
				if(req_type)
					prev_chr_mem_address <= chr_mem_address;
				else
					prev_prg_mem_address <= prg_mem_address;
				req_type_ff <= req_type;
				addr_odd <= mem_address[0];
			end

			if(mem_ready)
			begin
				if(req_type_ff)
					chrrom_dout <= mem_dout;
				else
					prgrom_dout <= mem_dout;
			end
		end
	end

	//ROM_PRG_03 PRG_03_inst(.clka(clk_in), .addra(prg_a_in), .douta(prgrom_dout));
	//ROM_CHR_03 CHR_03_inst(.clka(clk_in), .addra({page, chr_a_in[12:0]}), .douta(chrrom_dout));
	
	wire[15:0] from_flash;
	assign mem_dout = addr_odd ? from_flash[15:8] : from_flash[7:0];
	Nexys3_memory_controller memory_controller_inst(
		.clk(clk_mem),
		.rst(rst),
		//Port 1 (Flash)
		.p1_address({8'h00, req_type, mem_address[14:1]}),
		.p1_to_mem(16'h0000),
		.p1_from_mem(from_flash),
		.p1_req(mem_req & ~mem_busy),
		.p1_wren(1'b0),
		.p1_ready(mem_ready),
		//Port 2 (PSRAM)
		.p2_address(23'h000000),
		.p2_to_mem(16'h0000),
		.p2_from_mem(),
		.p2_req(1'b0),
		.p2_wren(1'b0),
		.p2_ready(),
		//Flash and PSRAM interface
		.shared_a(shared_a),
		.shared_d(shared_d),
		.shared_oe_n(shared_oe_n),
		.shared_we_n(shared_we_n),
		.flash_ce_n(flash_ce_n),
		.flash_reset_n(flash_reset_n),
		.psram_ce_n(psram_ce_n),
		.shared_adv_n(shared_adv_n),
		.psram_cre(psram_cre),
		.shared_clk(shared_clk),
		.psram_lb_n(psram_lb_n),
		.psram_ub_n(psram_ub_n)
	);
endmodule
