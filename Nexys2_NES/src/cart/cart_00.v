//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    14:34:26 02/13/2022 
// Design Name: cart
// Module Name:    cart_00 
// Project Name: FPGA_NES
// Target Devices: EP4CE6E22C8N
// Tool versions: 
// Description: Mapper 00 for NES
//
// Dependencies: eeprom.sv, I2C_phy.sv, SDRAM_SP8_I.sv, CHR_RAM.v
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module cart_00(
		input 	logic clk_sys,	// system clock signal
		input 	logic clk_sdram,
		input 	logic rst,
		output 	logic rst_out,
		
		// PRG-ROM interface:
		input 	logic       prg_nce_in,      // prg-rom chip enable (active low)
		input 	logic[14:0] prg_a_in,        // prg-rom address
		input 	logic       prg_r_nw_in,     // prg-rom read/write select
		input 	logic[7:0] 	prg_d_in,        // prg-rom data in
		output 	logic[7:0] 	prg_d_out,       // prg-rom data out
		input 	logic[7:0] 	chr_d_in,
		output	logic[7:0] 	chr_d_out,
		input		logic[13:0] chr_a_in,
		input		logic       chr_r_nw_in,     // chr-rom read/write select
		output 	logic ciram_nce_out,
		output 	logic ciram_a10_out,
		
		// SDRAM interface:
		output 	wire sdram_cke,
		output 	wire sdram_cs_n,
		output 	wire sdram_wre_n,
		output 	wire sdram_cas_n,
		output 	wire sdram_ras_n,
		output 	wire[10:0] sdram_a,
		output 	wire sdram_ba,
		output 	wire sdram_dqm,
		inout 	wire[7:0] sdram_dq,
		
		// I2C interface:
		inout wire i2c_sda,
		inout wire i2c_scl);
		
	wire [7:0] prgrom_dout;
	wire [7:0] chrrom_pat_bram_dout;
	
	wire[14:0] prev_prg_a_in;
	wire mem_req;
	wire mem_ready;

	wire init_req;
	wire init_ready;
	wire[20:0] init_address;
	wire[7:0] init_data;
	
	assign prg_d_out = prgrom_dout & {8{~prg_nce_in}};
	assign chr_d_out = chrrom_pat_bram_dout & {8{ciram_nce_out}};
	assign ciram_nce_out = ~chr_a_in[13];
	assign ciram_a10_out = chr_a_in[10];	//A10 for vertical mirroring, A11 for horizontal
	
	assign mem_req = (prg_a_in != prev_prg_a_in);
	
	initial
	begin
		rst_out = 1'b1;
	end
	
	always @(posedge clk_sdram)
	begin
		if(rst)
		begin
			rst_out <= 1'b1;
			prev_prg_a_in <= 15'h0F;
		end
		else
		begin
			if(mem_ready)
				rst_out <= 1'b0;
			prev_prg_a_in <= prg_a_in;
		end
	end

SDRAM_SP8_I SDRAM_inst(
		.clk(clk_sdram),
		.rst(rst),
		
		.mem_address({6'h00, prg_a_in}),
		.to_mem(8'h00),
		.from_mem(prgrom_dout),
		.mem_req(mem_req),
		.mem_wren(1'b0),
		.mem_ready(mem_ready),
		
		.sdram_cke(sdram_cke),
		.sdram_cs_n(sdram_cs_n),
		.sdram_wre_n(sdram_wre_n),
		.sdram_cas_n(sdram_cas_n),
		.sdram_ras_n(sdram_ras_n),
		.sdram_a(sdram_a),
		.sdram_ba(sdram_ba),
		.sdram_dqm(sdram_dqm),
		.sdram_dq(sdram_dq),
		
		.init_req(init_req),
		.init_ready(init_ready),
		.init_stop(21'h07FFF),
		.init_address(init_address),
		.init_data(init_data));
		
I2C_EEPROM EEPROM_inst(
		.clk(clk_sdram),
		.rst(rst),
		.read_req(init_req),
		.address(init_address[16:0]),
		.ready(init_ready),
		.data(init_data),
		.i2c_sda(i2c_sda),
		.i2c_scl(i2c_scl));

CHR_8_ROM CHR_inst(.address(chr_a_in[12:0]), .clock(clk_sys), .q(chrrom_pat_bram_dout));

endmodule
