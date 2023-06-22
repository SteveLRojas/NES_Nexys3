module NES_DragonBoard(
		input  wire clk,		// 50MHz system clock signal
		input wire[3:0] button,
		output wire[3:0] led,

		input wire jp_data1,
		input wire jp_data2,
		output wire jp_clk1,
		output wire jp_clk2,
		output wire jp_latch1,
		output wire jp_latch2,
		
		//Hex display
		output wire[3:0] seg_sel,
		output wire[7:0] hex_out,
		
		output wire VGA_HSYNC,			// vga hsync signal
		output wire VGA_VSYNC,			// vga vsync signal
		output wire[1:0] VGA_RED,		// vga red signal
		output wire[1:0] VGA_GREEN,	// vga green signal
		output wire [1:0] VGA_BLUE,	// vga blue signal

		output wire       AUDIO,		// pwm output audio channel
		//Flash and PSRAM interface
		output wire[22:0] shared_a,
		inout wire[15:0] shared_d,
		output wire shared_oe_n,
		output wire shared_we_n,
		output wire flash_ce_n,
		output wire flash_reset_n,
		input wire flash_sts,
		output wire psram_ce_n,
		output wire psram_adv_n,
		output wire psram_cre,
		output wire psram_clk,
		output wire psram_lb_n,
		output wire psram_ub_n
	);

//#############################################################################
	wire clk_25;
	wire clk_50;
	wire rst;
	wire[3:0] button_d;
	wire jp_latch;
	
	reg jp_data1_s;
	reg jp_data2_s;
	
	assign jp_latch1 = ~jp_latch;
	assign jp_latch2 = ~jp_latch;
	
	PLL0 PLL_inst(.CLKIN_IN(clk), .CLKDV_OUT(clk_25), .CLKIN_IBUFG_OUT(), .CLK0_OUT(clk_50));

	always @(posedge clk_25)
	begin
		 jp_data1_s <= jp_data1;
		 jp_data2_s <= jp_data2;
	end

	button_debounce debounce_inst(.clk(clk_25), .button_in(button), .rst(rst), .button_out(button_d));
//#############################################################################

//#############################################################################
//
// RP2A03: Main processing chip including CPU, APU, joypad control, and sprite DMA control.
//
	wire [ 7:0] to_cpu;
	wire        rp2a03_nnmi;
	wire [ 7:0] from_cpu;
	wire [15:0] rp2a03_a;
	wire        rp2a03_r_nw;
	wire cpu_reset;
	assign led[3] = ~cpu_reset;

	rp2a03 rp2a03_blk(
		 .clk_in(clk_25),
		 .rst_in(cpu_reset | button_d[0]),
		 .rdy_in(~button_d[1]),
		 .d_in(to_cpu),
		 .nnmi_in(rp2a03_nnmi),
		 .d_out(from_cpu),
		 .a_out(rp2a03_a),
		 .r_nw_out(rp2a03_r_nw),
		 .jp_data1_in(jp_data1_s),
		 .jp_data2_in(jp_data2_s),
		 .jp1_clk(jp_clk1),
		 .jp2_clk(jp_clk2),
		 .jp_latch(jp_latch),
		 .audio_out(AUDIO),
		 .debug()
	);
//#############################################################################

//#############################################################################
//
// PPU: picture processing unit block.
//
	wire [ 2:0] ppu_ri_sel;     // ppu register interface reg select
	wire        ppu_ri_ncs;     // ppu register interface enable
	wire        ppu_ri_r_nw;    // ppu register interface read/write select
	wire [ 7:0] ppu_ri_dout;    // ppu register interface data output

	wire [13:0] ppu_vram_a;     // ppu video ram address bus
	wire        ppu_vram_wr;    // ppu video ram read/write select
	wire [ 7:0] ppu_vram_din;   // ppu video ram data bus (input)
	wire [ 7:0] ppu_vram_dout;  // ppu video ram data bus (output)


	// PPU snoops the CPU address bus for register reads/writes.  Addresses 0x2000-0x2007
	// are mapped to the PPU register space, with every 8 bytes mirrored through 0x3FFF.
	assign ppu_ri_sel  = rp2a03_a[2:0];
	assign ppu_ri_ncs = ~(rp2a03_a[15:13] == 3'b001);
	assign ppu_ri_r_nw = rp2a03_r_nw;

	PPU_gen2 ppu_inst(
		 .debug_in(~button_d[3:2]),
		 .debug_out(led[2:0]),
		 .clk_in(clk_25),
		 .rst_in(rst),
		 .ri_sel_in(ppu_ri_sel),
		 .ri_ncs_in(ppu_ri_ncs),
		 .ri_r_nw_in(ppu_ri_r_nw),
		 .ri_d_in(from_cpu),
		 .vram_d_in(ppu_vram_din),
		 .hsync_out(VGA_HSYNC),
		 .vsync_out(VGA_VSYNC),
		 .r_out(VGA_RED),
		 .g_out(VGA_GREEN),
		 .b_out(VGA_BLUE),
		 .ri_d_out(ppu_ri_dout),
		 .nvbl_out(rp2a03_nnmi),
		 .vram_a_out(ppu_vram_a),
		 .vram_d_out(ppu_vram_dout),
		 .vram_wr_out(ppu_vram_wr)
	);
//#############################################################################

//#############################################################################
//
// CART: cartridge emulator
//
	wire        cart_prg_nce;
	wire [ 7:0] cart_prg_dout;
	wire [ 7:0] cart_chr_dout;
	wire        cart_ciram_nce;
	wire        cart_ciram_a10;

	assign cart_prg_nce = ~rp2a03_a[15];
	
	cart cart_blk(
	  .clk_in(clk_25),
	  .prg_nce_in(cart_prg_nce),
	  .prg_a_in(rp2a03_a[14:0]),
	  .prg_r_nw_in(rp2a03_r_nw),
	  .prg_d_in(rp2a03_dout),
	  .prg_d_out(cart_prg_dout),
	  .chr_a_in(ppu_vram_a),
	  .chr_r_nw_in(~ppu_vram_wr),
	  .chr_d_in(ppu_vram_dout),
	  .chr_d_out(cart_chr_dout),
	  .ciram_nce_out(cart_ciram_nce),
	  .ciram_a10_out(cart_ciram_a10)
	);
	assign shared_oe_n = 1'b1;
	assign shared_we_n = 1'b1;
	assign flash_ce_n = 1'b1;
	assign flash_reset_n = 1'b1;
	assign psram_ce_n = 1'b1;
	assign psram_adv_n = 1'b1;
	assign psram_cre = 1'b0;
	assign psram_lb_n = 1'b1;
	assign psram_ub_n = 1'b1;
	assign shared_a = 23'h000000;
	assign psram_clk = 1'b0;

	/*cart_02 cart_inst(
		.clk_sys(clk_25),	// system clock signal
		.clk_mem(clk_50),
		.rst(rst),
		.rst_out(cpu_reset),
		// PRG ROM interface:
		.prg_nce_in(cart_prg_nce),
		.prg_a_in(rp2a03_a[14:0]),
		.prg_r_nw_in(rp2a03_r_nw),
		.prg_d_in(from_cpu),
		.prg_d_out(cart_prg_dout),
		// CHR RAM interface:
		.chr_a_in(ppu_vram_a),
		.chr_r_nw_in(~ppu_vram_wr),
		.chr_d_in(ppu_vram_dout),
		.chr_d_out(cart_chr_dout),
		.ciram_nce_out(cart_ciram_nce),
		.ciram_a10_out(cart_ciram_a10),
		//Flash and PSRAM interface
		.shared_a(shared_a),
		.shared_d(shared_d),
		.shared_oe_n(shared_oe_n),
		.shared_we_n(shared_we_n),
		.flash_ce_n(flash_ce_n),
		.flash_reset_n(flash_reset_n),
		.flash_sts(flash_sts),
		.psram_ce_n(psram_ce_n),
		.psram_adv_n(psram_adv_n),
		.psram_cre(psram_cre),
		.psram_clk(psram_clk),
		.psram_lb_n(psram_lb_n),
		.psram_ub_n(psram_ub_n)
	);*/
//#############################################################################

//#############################################################################
//
// VRAM: internal video ram
//
	wire [10:0] vram_a;
	wire [7:0] vram_dout;
	assign vram_a = { cart_ciram_a10, ppu_vram_a[9:0] };

	vram vram_inst(
		.clka(clk_25),
		.ena(~cart_ciram_nce),
		.wea(ppu_vram_wr),
		.addra(vram_a),
		.dina(ppu_vram_dout),
		.douta(vram_dout));
//#############################################################################

//#############################################################################
//
// WRAM: internal work ram
//
	wire       wram_en;
	wire [7:0] wram_dout;
	assign wram_en = (rp2a03_a[15:13] == 0);

	wram wram_inst(
		.clka(clk_25),
		.ena(wram_en),
		.wea(~rp2a03_r_nw),
		.addra(rp2a03_a[10:0]),
		.dina(from_cpu),
		.douta(wram_dout));
//#############################################################################

//#############################################################################
	assign to_cpu = cart_prg_dout | (wram_dout & {8{wram_en}}) | ppu_ri_dout;
	assign ppu_vram_din = cart_chr_dout | (vram_dout & {8{~cart_ciram_nce}});
//#############################################################################

//#############################################################################
	reg[15:0] pulse_count;
	reg prev_sts;
	
	always @(posedge clk_50 or posedge rst)
	begin
		if(rst)
		begin
			pulse_count <= 16'h0000;
			prev_sts <= 1'b0;
		end
		else
		begin
			prev_sts <= flash_sts;
			if(prev_sts & ~flash_sts)
			begin
				pulse_count <= pulse_count + 16'h0001;
			end
		end
	end
	
	Nexys2_hex_driver hex_inst(
			.clk(clk_25),
			.seg0(pulse_count[3:0]),
			.seg1(pulse_count[7:4]),
			.seg2(pulse_count[11:8]),
			.seg3(pulse_count[15:12]),
			.dp(button_d),
			.seg_sel(seg_sel),
			.hex_out(hex_out));
//#############################################################################

endmodule
