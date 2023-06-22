module cart
(
  input  wire        clk_in,           // system clock signal

  // PRG-ROM interface.
  input  wire        prg_nce_in,       // prg-rom chip enable (active low)
  input  wire [14:0] prg_a_in,         // prg-rom address
  input  wire        prg_r_nw_in,      // prg-rom read/write select
  input  wire [ 7:0] prg_d_in,         // prg-rom data in
  output wire [ 7:0] prg_d_out,        // prg-rom data out

  // CHR-ROM interface.
  input  wire [13:0] chr_a_in,         // chr-rom address
  input  wire        chr_r_nw_in,      // chr-rom read/write select
  input  wire [ 7:0] chr_d_in,         // chr-rom data in
  output wire [ 7:0] chr_d_out,        // chr-rom data out
  output wire        ciram_nce_out,    // vram chip enable (active low)
  output wire        ciram_a10_out     // vram a10 value (controls mirroring)
);
wire [7:0]  prgrom_bram_dout;
wire [7:0] chrrom_pat_bram_dout;
assign prg_d_out = prgrom_bram_dout & {8{~prg_nce_in}};
assign chr_d_out = chrrom_pat_bram_dout & {8{ciram_nce_out}};
assign ciram_nce_out = ~chr_a_in[13];
assign ciram_a10_out = chr_a_in[11];	//A10 for vertical mirroring, A11 for horizontal

//PRG_32_ROM PRG_inst(.clka(clk_in), .addra(prg_a_in), .douta(prgrom_bram_dout));
PRG_16_ROM PRG_inst(.clka(clk_in), .addra(prg_a_in[13:0]), .douta(prgrom_bram_dout));

CHR_8_ROM CHR_inst(.clka(clk_in), .addra(chr_a_in[12:0]), .douta(chrrom_pat_bram_dout));

endmodule
