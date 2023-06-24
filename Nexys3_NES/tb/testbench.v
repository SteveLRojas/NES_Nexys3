`timescale 1ns/100ps
module Testbench();

	//External signals
	//reg CLK_100MHZ;      // 100MHz system clock signal
	reg CLK_50MHZ;
	reg reset;
	reg[3:0] button;
	//reg CPU_reset_ext;   // reset push button
	//reg SYS_reset_ext;   // console reset
	//reg[3:0] debug;      // switches
	reg NES_JOYPAD_DATA1;  // joypad 1 input signal
	reg NES_JOYPAD_DATA2;  // joypad 2 input signal
	wire VGA_HSYNC;        // vga hsync signal
	wire VGA_VSYNC;         // vga vsync signal
	wire[1:0] VGA_RED;      // vga red signal
	wire[1:0] VGA_GREEN;    // vga green signal
	wire[1:0] VGA_BLUE;     // vga blue signal
	wire NES_JOYPAD_CLK;    // joypad output clk signal
	wire NES_JOYPAD_LATCH;  // joypad output latch signal
	wire AUDIO;             // pwm output audio channel

	//Flash and SRAM signals
	wire[22:0] shared_a;
	wire[15:0] shared_d;
	wire shared_oe_n;
	wire shared_we_n;
	wire flash_ce_n;
	wire flash_reset_n;
	wire psram_ce_n;
	wire shared_adv_n;
	wire psram_cre;
	wire shared_clk;
	wire psram_lb_n;
	wire psram_ub_n;

	//Internal NES signals
	wire clk_25;
	//wire clk_100;

	wire [ 7:0] rp2a03_din;
	wire        rp2a03_nnmi;
	wire [ 7:0] rp2a03_dout;
	wire [15:0] rp2a03_a;
	wire        rp2a03_r_nw;

	wire [ 2:0] ppu_ri_sel;     // ppu register interface reg select
	wire        ppu_ri_ncs;     // ppu register interface enable
	wire        ppu_ri_r_nw;    // ppu register interface read/write select
	wire [ 7:0] ppu_ri_din;     // ppu register interface data input
	wire [ 7:0] ppu_ri_dout;    // ppu register interface data output

	wire [13:0] ppu_vram_a;     // ppu video ram address bus
	wire        ppu_vram_wr;    // ppu video ram read/write select
	wire [ 7:0] ppu_vram_din;   // ppu video ram data bus (input)
	wire [ 7:0] ppu_vram_dout;  // ppu video ram data bus (output)

	//RP2A03 Internal Signals
	wire sprdma_active;

	//PPU Internal Signals
	wire[7:0] NES_col;
	wire[7:0] NES_row;
	wire active_rows;
	wire active_render_area;
	wire active_draw_area;
	wire vert_scaler;
	wire horiz_advance;
	wire vblank;
	wire ri_bg_enable;
	wire ri_spr_enable;

	NES_Nexys3 nes_inst
	(
		.clk(CLK_50MHZ),		// 50MHz system clock signal
		.button(button & {4{reset}}),
		.sw(2'b00),
		.led(),

		.jp_data1(NES_JOYPAD_DATA1),
		.jp_data2(NES_JOYPAD_DATA2),
		.jp_clk1(NES_JOYPAD_CLK),
		.jp_clk2(),
		.jp_latch1(NES_JOYPAD_LATCH),
		.jp_latch2(),

		.VGA_HSYNC(VGA_HSYNC),			// vga hsync signal
		.VGA_VSYNC(VGA_VSYNC),			// vga vsync signal
		.VGA_RED(VGA_RED),		// vga red signal
		.VGA_GREEN(VGA_GREEN),	// vga green signal
		.VGA_BLUE(VGA_BLUE),	// vga blue signal

		.audio_pwm(AUDIO),		// pwm output audio channel

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
	
	flash_model flash_model_i(
		.clk(CLK_50MHZ),
		.flash_address(shared_a[14:0]),
		.flash_ce_n(flash_ce_n),
		.flash_oe_n(shared_oe_n),
		.flash_we_n(shared_we_n),
		.flash_data(shared_d)
	);

	assign clk_25 = nes_inst.clk_25;

	assign rp2a03_din = nes_inst.rp2a03_din;
	assign rp2a03_nnmi = nes_inst.rp2a03_nnmi;
	assign rp2a03_dout = nes_inst.rp2a03_dout;
	assign rp2a03_a = nes_inst.rp2a03_a;
	assign rp2a03_r_nw = nes_inst.rp2a03_r_nw;

	assign ppu_ri_sel = nes_inst.ppu_ri_sel;
	assign ppu_ri_ncs = nes_inst.ppu_ri_ncs;
	assign ppu_ri_r_nw = nes_inst.ppu_ri_r_nw;
	assign ppu_ri_din = nes_inst.ppu_ri_din;
	assign ppu_ri_dout = nes_inst.ppu_ri_dout;

	assign ppu_vram_a = nes_inst.ppu_vram_a;
	assign ppu_vram_wr = nes_inst.ppu_vram_wr;
	assign ppu_vram_din = nes_inst.ppu_vram_din;
	assign ppu_vram_dout = nes_inst.ppu_vram_dout;

	assign sprdma_active = nes_inst.rp2a03_blk.sprdma_active;

	assign NES_col = nes_inst.ppu_blk.NES_col;
	assign NES_row = nes_inst.ppu_blk.NES_row;
	assign active_rows = nes_inst.ppu_blk.active_rows;
	assign active_render_area = nes_inst.ppu_blk.active_render_area;
	assign active_draw_area = nes_inst.ppu_blk.active_draw_area;
	assign vert_scaler = nes_inst.ppu_blk.vert_scaler;
	assign horiz_advance = nes_inst.ppu_blk.horiz_advance;
	assign vblank = nes_inst.ppu_blk.vblank;
	assign ri_bg_enable = nes_inst.ppu_blk.ri_bg_enable;
	assign ri_spr_enable = nes_inst.ppu_blk.ri_spr_enable;

	always begin: CLOCK_GENERATION
		#10 CLK_50MHZ = ~ CLK_50MHZ;
	end

	initial begin: CLOCK_INITIALIZATION
		CLK_50MHZ = 0;
	end

	initial begin: TEST_VECTORS
	//initial conditions
	reset = 1'b1;
	button = 4'b1111;
	NES_JOYPAD_DATA1 = 1'b1;
	NES_JOYPAD_DATA2 = 1'b1;

	#210 reset <= 1'b0;	//reset system
	#80 reset <= 1'b1;	//release reset

	end
endmodule
