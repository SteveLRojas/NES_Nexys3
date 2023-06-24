`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:38:39 06/24/2023 
// Design Name: 
// Module Name:    testbench_cart 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module testbench_cart();

	reg clk_sys;
	reg rst;

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
	
	PLL0 PLL_inst(.CLK_100(clk_sys), .CLK_50(clk_50), .CLK_25(clk_25));
	
	wire cpu_rst;
	reg[14:0] prg_a_in;
	wire[7:0] cart_prg_dout;
	reg[13:0] chr_a_in;
	wire[7:0] cart_chr_dout;
	
	cart_03 cart_inst(
		.clk_sys(clk_25),	// system clock signal
		.clk_mem(clk_50),
		.rst(rst),
		.rst_out(cpu_rst),
		// PRG ROM interface:
		.prg_nce_in(1'b0),
		.prg_a_in(prg_a_in),
		.prg_r_nw_in(1'b1),
		.prg_d_in(8'h00),
		.prg_d_out(cart_prg_dout),
		// CHR RAM interface:
		.chr_a_in(chr_a_in),
		.chr_r_nw_in(1'b1),
		.chr_d_in(8'h00),
		.chr_d_out(cart_chr_dout),
		.ciram_nce_out(),
		.ciram_a10_out(),
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
	
	flash_model flash_model_i(
		.clk(clk_50),
		.flash_address(shared_a[14:0]),
		.flash_ce_n(flash_ce_n),
		.flash_oe_n(shared_oe_n),
		.flash_we_n(shared_we_n),
		.flash_data(shared_d)
	);
	
	always
	begin: CLOCK_GENERATION
		#5 clk_sys = ~clk_sys;
	end

	initial begin: CLOCK_INITIALIZATION
		clk_sys = 0;
	end
	
	reg[7:0] count_chr;
	reg[7:0] count_prg;
	always @(posedge clk_50)
	begin
		if(rst)
		begin
			count_chr <= 8'h00;
			count_prg <= 8'h00;
		end
		else
		begin
			if(count_chr == 8'd12)
			begin
				count_chr <= 8'h00;
				chr_a_in <= chr_a_in + 14'h0001;
			end
			else
			begin
				count_chr <= count_chr + 8'h01;
			end
			
			if(count_prg == 8'd40)
			begin
				count_prg <= 8'h00;
				prg_a_in <= prg_a_in + 15'h0001;
			end
			else
			begin
				count_prg <= count_prg + 8'h01;
			end
		end
	end
	
	initial
	begin: TEST_VECTORS
		//initial conditions
		rst = 1'b0;
		prg_a_in = 15'h0000;
		chr_a_in = 14'h0000;
		count_chr = 8'h00;
		count_prg = 8'h00;
		
		#40 rst = 1'b1;	//reset system
		#40 rst = 1'b0;	//release reset
	end

endmodule
