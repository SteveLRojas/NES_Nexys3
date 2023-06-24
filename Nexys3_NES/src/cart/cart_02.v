//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    20:30:26 06/22/2019 
// Design Name: cart
// Module Name:    cart_02 
// Project Name: FPGA_NES
// Target Devices: EP4CE6E22C8N
// Tool versions: ISE 14.7
// Description: Mapper 02 for NES
//
// Dependencies: Nexys3_memory_controller
//
// Revision: 
// Revision 0.01 - File Created
// Revision 0.02 - Adapted file for Nexys3
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module cart_02(
		input wire clk_sys,				// system clock signal
		input wire clk_mem,
		input wire rst,
		output wire rst_out,
		// PRG-ROM interface:
		input wire prg_nce_in,			// prg-rom chip enable (active low)
		input wire[14:0] prg_a_in,		// prg-rom address
		input wire prg_r_nw_in,			// prg-rom read/write select
		input wire[7:0] prg_d_in,		// prg-rom data in
		output wire[7:0] prg_d_out,		// prg-rom data out
		// CHR RAM interface
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
  
	wire [7:0] chrram_dout;
	wire[7:0] prgrom_dout;
	wire chrram_we;

	wire[16:0] mem_address;
	wire mem_ready;
	wire mem_req;

	reg[2:0] page;
	reg reset_hold;
	reg[16:0] prev_mem_address;
	reg init_req;

	assign ciram_a10_out = chr_a_in[10];	//A10 for vertical mirroring, A11 for horizontal
	assign ciram_nce_out = ~chr_a_in[13];
	assign prg_d_out = prgrom_dout & {8{~prg_nce_in}};
	assign chr_d_out = chrram_dout & {8{ciram_nce_out}};
	assign chrram_we = ~chr_a_in[13] & ~chr_r_nw_in;

	assign mem_address = {({3{prg_a_in[14]}} | page), prg_a_in[13:0]};
	assign mem_req = init_req | (mem_address[16:1] != prev_mem_address[16:1]);
	assign rst_out = reset_hold;

	initial
	begin
		 page = 3'b111;
		 reset_hold = 1'b1;
		 init_req = 1'b1;
	end

	always @(posedge clk_sys)
	begin
		if((~prg_r_nw_in) & (~prg_nce_in))   //register enabled by write to rom space
			page <= prg_d_in[2:0];
	end

	always @(posedge clk_mem)
	begin
		if(rst)
		begin
			reset_hold <= 1'b1;
			prev_mem_address <= 17'h0F;
			init_req <= 1'b1;
		end
		else
		begin
			if(mem_ready)
				reset_hold <= 1'b0;
			prev_mem_address <= mem_address;
			init_req <= 1'b0;
		end
	end

	//ROM_02 ROM_inst(.clka(clk_in), .addra({({3{prg_a_in[14]}} | page), prg_a_in[13:0]}), .douta(prgrom_dout));
	CHR_RAM CHR_inst(.clka(clk_sys), .addra(chr_a_in[12:0]), .wea(chrram_we), .dina(chr_d_in), .douta(chrram_dout));
	
	wire[15:0] from_flash;
	assign prgrom_dout = mem_address[0] ? from_flash[15:8] : from_flash[7:0];
	Nexys3_memory_controller memory_controller_inst(
		.clk(clk_mem),
		.rst(rst),
		//Port 1 (Flash)
		.p1_address({7'h00, mem_address[16:1]}),
		.p1_to_mem(16'h0000),
		.p1_from_mem(from_flash),
		.p1_req(mem_req),
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
