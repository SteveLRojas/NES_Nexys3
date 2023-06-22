//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    22:02:26 02/12/2022 
// Design Name: mapper 71
// Module Name: cart_71 
// Project Name: NES_DragonBoard_V10
// Target Devices: EP4CE6E22C8N
// Tool versions: Quartus 18.1
// Description: Mapper 71 for NES
//
// Dependencies: eeprom.sv, I2C_phy.sv, SDRAM_SP8_I.sv, CHR_RAM.v
//
// Revision: 0.01
// Revision 0.01 - File Created
// Additional Comments: Based on cart_02
//
//////////////////////////////////////////////////////////////////////////////////
module cart_71(
		input logic clk_sys,	// system clock signal
		input logic clk_sdram,
		input logic rst,
		output logic rst_out,
		// PRG-ROM interface:
		input logic       prg_nce_in,      // prg-rom chip enable (active low)
		input logic[14:0] prg_a_in,        // prg-rom address
		input logic       prg_r_nw_in,     // prg-rom read/write select
		input logic[7:0] prg_d_in,         // prg-rom data in
		output logic[7:0] prg_d_out,       // prg-rom data out
		input logic[7:0] chr_d_in,
		output logic[7:0] chr_d_out,
		input logic[13:0] chr_a_in,
		input logic       chr_r_nw_in,     // chr-rom read/write select
		output logic ciram_nce_out,
		output logic ciram_a10_out,
		// SDRAM interface:
		output wire sdram_cke,
		output wire sdram_cs_n,
		output wire sdram_wre_n,
		output wire sdram_cas_n,
		output wire sdram_ras_n,
		output wire[10:0] sdram_a,
		output wire sdram_ba,
		output wire sdram_dqm,
		inout wire[7:0] sdram_dq,
		// I2C interface:
		inout wire i2c_sda,
		inout wire i2c_scl);
  
wire [7:0] chrram_dout;
wire[7:0] prgrom_dout;
wire chrram_we;

wire[20:0] mem_address;
wire mem_ready;
wire mem_req;
wire init_req;
wire init_ready;
wire[20:0] init_address;
wire[7:0] init_data;

reg[2:0] page;
reg reset_hold;
reg[20:0] prev_mem_address;
reg mirroring;

assign ciram_a10_out = mirroring;	//A10 for vertical mirroring, A11 for horizontal, mirroring for mapper controlled 1 screen
assign ciram_nce_out = ~chr_a_in[13];
assign prg_d_out = prgrom_dout & {8{~prg_nce_in}};
assign chr_d_out = chrram_dout & {8{ciram_nce_out}};
assign chrram_we = ~chr_a_in[13] & ~chr_r_nw_in;

assign mem_address = {4'h0, ({3{prg_a_in[14]}} | page), prg_a_in[13:0]};
assign mem_req = (mem_address != prev_mem_address);
assign rst_out = reset_hold;

initial
begin
    page = 3'b111;
	 mirroring = 1'b0;
	 reset_hold = 1'b1;
end

always @(posedge clk_sys)
begin
	if((~prg_r_nw_in) & (~prg_nce_in) & prg_a_in[14])   //register enabled by write to rom space at address C000 - FFFF
		page <= prg_d_in[2:0];
	if(~prg_r_nw_in & ~prg_nce_in & ~(|prg_a_in[14:13]))	//8000 - 9FFF
		mirroring <= prg_d_in[4];
end

always @(posedge clk_sdram)
begin
	if(rst)
	begin
		reset_hold <= 1'b1;
		prev_mem_address <= 21'h0F;
	end
	else
	begin
		if(mem_ready)
			reset_hold <= 1'b0;
		prev_mem_address <= mem_address;
	end
end

//ROM_02 ROM_inst(.clka(clk_in), .addra({({3{prg_a_in[14]}} | page), prg_a_in[13:0]}), .douta(prgrom_dout));
//CHR_RAM CHR_inst(.clka(clk_in), .addra(chr_a_in[12:0]), .wea(chrram_we), .dina(chr_d_in), .douta(chrram_dout));

SDRAM_SP8_I SDRAM_inst(
		.clk(clk_sdram),
		.rst(rst),
		
		.mem_address(mem_address),
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
		.init_stop(21'h1FFFF),
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
		
CHR_RAM CHR_inst(.address(chr_a_in[12:0]), .clock(clk_sys), .data(chr_d_in), .wren(chrram_we), .q(chrram_dout));

endmodule
