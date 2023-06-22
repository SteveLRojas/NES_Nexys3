//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Esteban Looser-Rojas
// 
// Create Date:    20:30:26 06/22/2019 
// Design Name: cart
// Module Name:    cart_02 
// Project Name: FPGA_NES
// Target Devices: XC6SLX9
// Tool versions: 
// Description: Mapper 02 for NES
//
// Dependencies: None
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module cart_03
(
  input  wire        clk_in,           // system clock signal

  // PRG-ROM interface.
  input  wire        prg_nce_in,       // prg-rom chip enable (active low)
  input  wire [14:0] prg_a_in,         // prg-rom address
  input  wire        prg_r_nw_in,      // prg-rom read/write select
  input  wire [ 7:0] prg_d_in,         // prg-rom data in
  output wire [ 7:0] prg_d_out,        // prg-rom data out
  input wire [7:0] chr_d_in,
  output wire [7:0] chr_d_out,
  input wire [13:0] chr_a_in,
  input  wire        chr_r_nw_in,      // chr-rom read/write select
  output wire ciram_nce_out,
  output wire ciram_a10_out
);
wire [7:0] chrrom_pat_bram_dout, prgrom_bram_dout;
wire chrrom_pat_bram_we;
assign ciram_a10_out = chr_a_in[11];    //horizontal mirroring
assign ciram_nce_out = ~chr_a_in[13];
assign chr_d_out = (ciram_nce_out) ? chrrom_pat_bram_dout : 8'h00;
assign prg_d_out = (~prg_nce_in) ? prgrom_bram_dout : 8'h00;
assign chrrom_pat_bram_we = (ciram_nce_out) ? ~chr_r_nw_in : 1'b0;
reg [1:0] page;
initial
begin
    page = 2'b00;
end
always @(posedge clk_in)
begin
	if((~prg_r_nw_in)&(~prg_nce_in))   //register enabled by write to rom space
	page <= prg_d_in[1:0];
end

ROM_PRG_03 PRG_03_inst(.clka(clk_in), .addra(prg_a_in), .douta(prgrom_bram_dout));
ROM_CHR_03 CHR_03_inst(.clka(clk_in), .addra({page, chr_a_in[12:0]}), .douta(chrrom_pat_bram_dout));
endmodule
