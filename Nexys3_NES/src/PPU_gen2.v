`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Steve L Rojas
// 
// Create Date: 02/10/2020 04:13:41 AM
// Design Name: X2C02-G2
// Module Name: PPU_gen2
// Project Name: FPGA_NES
// Target Devices: Xilinx Spartan 6 or Intel/Altera Cyclone IV
// Tool Versions: Vivado 2019.1
// Description: Implementation of the NES PPU with VGA output
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Based on Brian Bennett's PPU implementation
// 
//////////////////////////////////////////////////////////////////////////////////
//PPU video timing description:
//The PPU draws frames with 341 pixels per line, and a total of 262 scanlines. This is the same as the MC6847.
//Out of the 341 pixels in each line, 256 of them are visible on the screen. Once again this is the same as for the MC6847.
//Out of the 262 lines in each frame, 240 are in the active area. This is considerably higher than the 192 active lines of the MC6847.
//In addition to the 240 active lines, an extra dummy line is rendered before the first visible line.

//Implementation details:
//PPU module will be implemented as a 640 * 480 VGA controller with 2/5 scaling on Y axis and 1/2 scaling on X axis.

module PPU_gen2
(
    input wire[1:0] debug_in,
    input  wire        clk_in,        // 25MHz pixel clock signal
    input  wire        rst_in,        // reset signal
    input  wire [ 2:0] ri_sel_in,     // register interface reg select
    input  wire        ri_ncs_in,     // register interface enable
    input  wire        ri_r_nw_in,    // register interface read/write select
    input  wire [ 7:0] ri_d_in,       // register interface data in
    input  wire [ 7:0] vram_d_in,     // video memory data bus (input)
    output wire[2:0] debug_out,
    output reg        hsync_out,     // vga hsync signal
    output reg        vsync_out,     // vga vsync signal
    output wire [ 1:0] r_out,         // vga red signal
    output wire [ 1:0] g_out,         // vga green signal
    output wire [ 1:0] b_out,         // vga blue signal
    output wire [ 7:0] ri_d_out,      // register interface data out
    output wire        nvbl_out,      // /VBL (low during vertical blank)
    output wire [13:0] vram_a_out,    // video memory address bus
    output reg [ 7:0] vram_d_out,    // video memory data bus (output)
    output reg        vram_wr_out    // video memory read/write select
);
reg horiz_advance;

// PPU register interface
reg ri_address_inc; //high to increment address by ri
reg next_ri_address_inc;
reg ri_address_update, next_ri_address_update;  //high to update address by ri
reg ri_inc_sel, next_ri_inc_sel;     //select address increment ammount. high for line increment
reg ri_v_name, next_ri_v_name;
reg[4:0] ri_v_tile, next_ri_v_tile;
reg[2:0] ri_v_fine, next_ri_v_fine; //these are used to update v counters by ri
reg ri_h_name, next_ri_h_name;
reg[2:0] ri_h_fine, next_ri_h_fine;
reg[4:0] ri_h_tile, next_ri_h_tile; //these are used to update h counters by ri
reg ri_background_select, next_ri_background_select;  //selects the the pattern table for the background
reg[7:0] ri_cpu_data_out, next_ri_cpu_data_out; //ri output data register
reg ri_sprite_height, next_ri_sprite_height;    //select sprite height. low for 8 line, high for 16
reg ri_sprite_select, next_ri_sprite_select;    //selects the pattern table for sprites
reg ri_vblank, next_ri_vblank;  //vertical blank flag
reg ri_byte_sel, next_ri_byte_sel;  //high or low byte flag for writes to 2005 and 2006
reg[7:0] ri_read_buf, next_ri_read_buf;    //register for buffered reads
reg ri_read_buf_update, next_ri_read_buf_update;    //high to update the read buffer
reg[7:0] ri_oam_address, next_ri_oam_address;   //OAM address for RI access
reg ri_prev_ncs;    //prev ri_ncs_in state for edge detection
reg ri_prev_vblank; //prev vblank state for edge detection
reg[7:0] ri_oam_d;  //data from ri to OAM
reg ri_oam_wr;  //write enable for OAM

reg ri_bg_enable, next_ri_bg_enable;   //enables drawing the background
reg ri_spr_enable, next_ri_spr_enable;  //enables drawing sprites
reg ri_bg_clip_enable, next_ri_bg_clip_enable; //blanks left side 8 pixels for background
reg ri_spr_clip_enable, next_ri_spr_clip_enable;    //blanks left side 8 pixels for sprites
reg ri_nmi_enable, next_ri_nmi_enable;  //enables nmi during vertical blank
reg ri_pram_wr; //write enable for palette ram

wire vblank;    //active high vblank driven by VGA timing logic
wire ri_spr0_hit;
wire ri_spr_overflow;
wire[7:0] ri_oam_q;
wire[7:0] ri_pram_q;

assign debug_out = {ri_spr0_hit, ri_spr_enable, ri_bg_enable};

always @(posedge clk_in or posedge rst_in)
begin
    if (rst_in)
    begin
        ri_v_fine <= 3'h0;
        ri_v_tile <= 5'h00;
        ri_v_name <= 1'h0;
        ri_h_fine <= 3'h0;
        ri_h_tile <= 5'h00;
        ri_h_name <= 1'h0;
        ri_background_select <= 1'h0;
        ri_cpu_data_out <= 8'h00;
        ri_address_update <= 1'h0;
        ri_nmi_enable <= 1'h0;
        ri_sprite_height <= 1'h0;
        ri_sprite_select <= 1'h0;
        ri_inc_sel <= 1'h0;
        ri_spr_enable <= 1'h0;
        ri_bg_enable <= 1'h0;
        ri_spr_clip_enable <= 1'h0;
        ri_bg_clip_enable <= 1'h0;
        ri_vblank <= 1'h0;
        ri_byte_sel <= 1'h0;
        ri_read_buf <= 8'h00;
        ri_read_buf_update <= 1'h0;
        ri_oam_address <= 8'h00;
        ri_prev_ncs <= 1'h1;
        ri_prev_vblank <= 1'h0;
        ri_address_inc <= 1'b0;
    end
    else if(horiz_advance)
    begin
        ri_v_fine            <= next_ri_v_fine;
        ri_v_tile            <= next_ri_v_tile;
        ri_v_name             <= next_ri_v_name;
        ri_h_fine            <= next_ri_h_fine;
        ri_h_tile           <= next_ri_h_tile;
        ri_h_name             <= next_ri_h_name;
        ri_background_select             <= next_ri_background_select;
        ri_cpu_data_out     <= next_ri_cpu_data_out;
        ri_address_update <= next_ri_address_update;
        ri_nmi_enable       <= next_ri_nmi_enable;
        ri_sprite_height         <= next_ri_sprite_height;
        ri_sprite_select    <= next_ri_sprite_select;
        ri_inc_sel     <= next_ri_inc_sel;
        ri_spr_enable        <= next_ri_spr_enable;
        ri_bg_enable         <= next_ri_bg_enable;
        ri_spr_clip_enable   <= next_ri_spr_clip_enable;
        ri_bg_clip_enable    <= next_ri_bg_clip_enable;
        ri_vblank        <= next_ri_vblank;
        ri_byte_sel      <= next_ri_byte_sel;
        ri_read_buf        <= next_ri_read_buf;
        ri_read_buf_update        <= next_ri_read_buf_update;
        ri_oam_address     <= next_ri_oam_address;
        ri_prev_ncs        <= ri_ncs_in;
        ri_prev_vblank     <= vblank;
        ri_address_inc <= next_ri_address_inc;
    end
end

always @(*)
begin
    //default signals to their current value
    next_ri_v_fine = ri_v_fine;
    next_ri_v_tile          = ri_v_tile;
    next_ri_v_name           = ri_v_name;
    next_ri_h_fine          = ri_h_fine;
    next_ri_h_tile          = ri_h_tile;
    next_ri_h_name           = ri_h_name;
    next_ri_background_select           = ri_background_select;
    next_ri_cpu_data_out   = ri_cpu_data_out;
    next_ri_nmi_enable     = ri_nmi_enable;
    next_ri_sprite_height       = ri_sprite_height;
    next_ri_sprite_select  = ri_sprite_select;
    next_ri_inc_sel   = ri_inc_sel;
    next_ri_spr_enable      = ri_spr_enable;
    next_ri_bg_enable       = ri_bg_enable;
    next_ri_spr_clip_enable = ri_spr_clip_enable;
    next_ri_bg_clip_enable  = ri_bg_clip_enable;
    next_ri_byte_sel    = ri_byte_sel;
    next_ri_oam_address   = ri_oam_address;

    vram_wr_out = 1'b0;
    vram_d_out  = 8'h00;
    ri_pram_wr = 1'b0;
    next_ri_address_inc = 1'b0;
    ri_oam_d  = 8'h00;
    ri_oam_wr = 1'b0;
    next_ri_read_buf_update = 1'b0;
    next_ri_address_update = 1'b0;

    next_ri_read_buf = (ri_read_buf_update) ? vram_d_in : ri_read_buf;

    // Set the vblank status bit on a rising vblank edge.  Clear it if vblank is false.  Can also be cleared by reading 0x2002.
    if(~ri_prev_vblank & vblank)
        next_ri_vblank = 1'b1;
    else if(~vblank)
        next_ri_vblank = 1'b0;
    else
        next_ri_vblank = ri_vblank;

    // Only evaluate RI reads/writes on /CS falling edges.  This prevents executing the same
    // command multiple times because the CPU runs at a slower clock rate than the PPU.
    if (ri_prev_ncs & ~ri_ncs_in)
    begin
        if (ri_r_nw_in)
        begin
            // External register read.
            case (ri_sel_in)
					3'h2:  // 0x2002 PPUSTATUS
					begin
						 next_ri_cpu_data_out = {ri_vblank, ri_spr0_hit, ri_spr_overflow, 5'b00000};
						 next_ri_byte_sel = 1'b0;
						 next_ri_vblank = 1'b0;
					end
					3'h4:  // 0x2004 OAMDATA
					begin
						 next_ri_cpu_data_out = ri_oam_q;
					end
					3'h7:  // 0x2007 PPUDATA
					begin
						 next_ri_cpu_data_out  = (vram_a_out[13:8] == 6'h3F) ? ri_pram_q : ri_read_buf;
						 next_ri_read_buf_update = 1'b1;
						 next_ri_address_inc = 1'b1;
					end
					default: ;
            endcase
        end
        else
        begin
            // External register write.
            case (ri_sel_in)
					3'h0:  // 0x2000
					begin
						 next_ri_nmi_enable = ri_d_in[7];
						 next_ri_sprite_height = ri_d_in[5];
						 next_ri_background_select = ri_d_in[4];
						 next_ri_sprite_select = ri_d_in[3];
						 next_ri_inc_sel  = ri_d_in[2];
						 next_ri_v_name = ri_d_in[1];
						 next_ri_h_name = ri_d_in[0];
					end
					3'h1:  // 0x2001
					begin
						 next_ri_spr_enable = ri_d_in[4];
						 next_ri_bg_enable = ri_d_in[3];
						 next_ri_spr_clip_enable = ~ri_d_in[2];
						 next_ri_bg_clip_enable = ~ri_d_in[1];
					end
					3'h3:  // 0x2003
					begin
						 next_ri_oam_address = ri_d_in;
					end
					3'h4:  // 0x2004
					begin
						 ri_oam_d = ri_d_in;
						 ri_oam_wr = 1'b1;
						 next_ri_oam_address = ri_oam_address + 8'h01;
					end
					3'h5:  // 0x2005
					begin
						 next_ri_byte_sel = ~ri_byte_sel;
						 if (~ri_byte_sel)
						 begin
							  // First write.
							  next_ri_h_fine = ri_d_in[2:0];
							  next_ri_h_tile = ri_d_in[7:3];
						 end
						 else
						 begin
							  // Second write.
							  next_ri_v_fine = ri_d_in[2:0];
							  next_ri_v_tile = ri_d_in[7:3];
						 end
					end
					3'h6:  // 0x2006
					begin
						 next_ri_byte_sel = ~ri_byte_sel;
						 if (~ri_byte_sel)
						 begin
							  // First write.
							  next_ri_v_fine = {1'b0, ri_d_in[5:4]};
							  next_ri_v_name = ri_d_in[3];
							  next_ri_h_name = ri_d_in[2];
							  next_ri_v_tile[4:3] = ri_d_in[1:0];
						 end
						 else
						 begin
							  // Second write.
							  next_ri_v_tile[2:0] = ri_d_in[7:5];
							  next_ri_h_tile = ri_d_in[4:0];
							  next_ri_address_update = 1'b1;
						 end
					end
					3'h7:  // 0x2007
					begin
						 if (vram_a_out[13:8] == 6'h3F)
							  ri_pram_wr = 1'b1;
						 else
							  vram_wr_out = 1'b1;
						 vram_d_out = ri_d_in;
						 next_ri_address_inc = 1'b1;
					end
					default: ;
            endcase
        end
    end
end
assign ri_d_out = (~ri_ncs_in & ri_r_nw_in) ? ri_cpu_data_out : 8'h00;

//### VGA timing logic
reg[9:0] vesa_col, next_vesa_col;	//0 to 799 horizontal position in physical display
reg[9:0] vesa_line, next_vesa_line;	//0 to 524 vertical position in physical siplay
reg active_rows, next_active_rows;
reg prev_active_rows;
reg active_render_area, next_active_render_area;
reg active_draw_area, next_active_draw_area;
reg HSYNC, next_HSYNC, VSYNC, next_VSYNC;
reg[7:0] NES_col, next_NES_col;
reg[7:0] NES_row, next_NES_row;
reg[2:0] horiz_scaler;
reg vert_scaler, next_vert_scaler;


always @(posedge clk_in)
begin
	if(rst_in)
	begin
		vesa_col <= 0;
		vesa_line <= 0;
		active_rows <= 0;
		active_render_area <= 0;
		active_draw_area <= 0;
		horiz_scaler <= 0;
	end
	else
	begin
		vesa_col <= next_vesa_col;
		vesa_line <= next_vesa_line;
		active_rows <= next_active_rows;
		active_render_area <= next_active_render_area;
		active_draw_area <= next_active_draw_area;
		if(horiz_scaler == 3'b100)
			horiz_scaler <= 3'b000;
		else
			horiz_scaler <= horiz_scaler + 3'b001;
	end
	HSYNC <= next_HSYNC;
	VSYNC <= next_VSYNC;
end

always @(*)
begin
// virtual advance logic
	horiz_advance = (horiz_scaler == 3'b000) | (horiz_scaler == 3'b010);
// line and pixel counters
	if(vesa_col == 10'd799)
		next_vesa_col = 10'h00;
	else
		next_vesa_col = vesa_col + 10'h01;
	if(vesa_col == 10'd799)
	begin
		if(vesa_line == 10'd524)
			next_vesa_line = 10'h00;
		else
			next_vesa_line = vesa_line + 10'h01;
	end
	else
		next_vesa_line = vesa_line;
// HSYNC and VSYNC logic
	if(vesa_col <= 10'd751 && vesa_col >= 10'd656)
		next_HSYNC = 1'b0;
	else
		next_HSYNC = 1'b1;
	if(vesa_line == 10'd491 || vesa_line == 10'd492)
		next_VSYNC = 1'b0;
	else
		next_VSYNC = 1'b1;
// active area logic
	if(vesa_line == 10'h00)
		next_active_rows = 1'b1;
	else if(vesa_line == 10'd480)
		next_active_rows = 1'b0;
	else
		next_active_rows = active_rows;
		
	if(active_rows && vesa_col == 10'd799)
		next_active_draw_area = 1'b1;
	else if(vesa_col == 10'd639)
		next_active_draw_area = 1'b0;	//active area is in rows 1 to 480
	else
		next_active_draw_area = active_draw_area;
		
	if(active_rows && vesa_col == 10'd777)
	   next_active_render_area = 1'b1;
	else if(vesa_col == 10'd637)
	   next_active_render_area = 1'b0;
    else
        next_active_render_area = active_render_area;
end

//virtual horizontal clock logic
always @(posedge clk_in)
begin
	if(rst_in)
	begin
		NES_col <= 0;
		NES_row <= 0;
		vert_scaler <= 0;
		prev_active_rows <= 1'b0;
	end
	else if(horiz_advance)
	begin
		NES_col <= next_NES_col;
		NES_row <= next_NES_row;
		vert_scaler <= next_vert_scaler;
		prev_active_rows <= active_rows;
	end
end

assign vblank = ~(active_rows | active_draw_area);   //need to check active area because active rows goes low at the start of the last active row
assign nvbl_out = ~(ri_vblank & ri_nmi_enable);

//virtual row and column logic
always @(*)
begin
	if(active_render_area)
	begin
		next_NES_col = NES_col + 8'd01;
		if(NES_col == 8'd255)
		begin
			next_vert_scaler = ~vert_scaler;
			if(vert_scaler)
			begin
				if(NES_row == 8'd239)
					next_NES_row = 8'h00;
				else
					next_NES_row = NES_row + 8'h01;
			end
			else
			begin
				next_NES_row = NES_row;
			end
		end
		else
		begin
			next_NES_row = NES_row;
			next_vert_scaler = vert_scaler;
		end
	end
	else if(active_rows)
	begin
		next_NES_col = 8'h00;
		next_NES_row = NES_row;
		next_vert_scaler = vert_scaler;
	end
	else
	begin
		next_NES_col = 8'h00;
		next_NES_row = 8'h00;
		next_vert_scaler = 1'b0;
	end
end

//### Background rendering logic
reg v_name, next_v_name;    //vertical name table counter
reg h_name, next_h_name;    //horizontal name table counter
reg[4:0] v_tile, next_v_tile;   //vertical tile index (in name table)
reg[4:0] h_tile, next_h_tile;   //horizontal tile index (in name table)
reg[2:0] v_fine, next_v_fine;   //fine vertical counter
reg[7:0] picture_address, next_picture_address; // tile index in pattern memory
reg[1:0] tile_attribute, next_tile_attribute;   //selects palette for tile
//reg[1:0] tile_attribute_hold;   //used to align with pattern_data1
reg[7:0] pattern_data0, next_pattern_data0;     //data from least significant bit plane of pattern table
//reg[7:0] pattern_data0_hold;    //used to align with pattern_data1
//reg[7:0] pattern_data1, next_pattern_data1;     //data from most significant bit plane of pattern table
reg[8:0] bg_shift3, next_bg_shift3;     //shift register for bit 3 of background palette index
reg[8:0] bg_shift2, next_bg_shift2;     //shift register for bit 2 of background palette index
reg[15:0] bg_shift1, next_bg_shift1;    //shift register for bit 1 of background palette index
reg[15:0] bg_shift0, next_bg_shift0;    //shift_register for bit 0 of background palette index
reg[13:0] bg_vram_a;

always @(posedge clk_in or posedge rst_in)
begin
    if (rst_in)
    begin
        v_fine <= 3'h0;
        v_tile <= 5'h00;
        v_name <= 1'h0;
        h_tile <= 5'h00;
        h_name <= 1'h0;
        picture_address <= 8'h00;
        tile_attribute <= 2'h0;
        pattern_data0 <= 8'h00;
        //pattern_data1 <= 8'h00;
        bg_shift3 <= 9'h000;
        bg_shift2 <= 9'h000;
        bg_shift1 <= 16'h0000;
        bg_shift0 <= 16'h0000;
    end
    else if(horiz_advance)
    begin
        v_fine <= next_v_fine;
        v_tile <= next_v_tile;
        v_name <= next_v_name;
        h_tile <= next_h_tile;
        h_name <= next_h_name;
        picture_address <= next_picture_address;
        tile_attribute <= next_tile_attribute;
        pattern_data0 <= next_pattern_data0;
        //pattern_data1 <= next_pattern_data1;
        bg_shift3 <= next_bg_shift3;
        bg_shift2 <= next_bg_shift2;
        bg_shift1 <= next_bg_shift1;
        bg_shift0 <= next_bg_shift0;
    end
end

reg update_v_count; //high to update v counters from ri
reg update_h_count; //high to update h counters from ri
reg inc_v_count;    //high to increment v counters to next line
reg inc_h_count;    //high to increment h counters to next pixel

//compute next counter values
always @(*)
begin
    next_v_fine = v_fine;
    next_v_name = v_name;
    next_h_name  = h_name;
    next_v_tile = v_tile;
    next_h_tile = h_tile;

    if(ri_address_inc)
    begin
        if(ri_inc_sel)
            {next_v_fine, next_v_name, next_h_name, next_v_tile} = {v_fine, v_name, h_name, v_tile} + 10'h001;
        else
            {next_v_fine, next_v_name, next_h_name, next_v_tile, next_h_tile} = {v_fine, v_name, h_name, v_tile, h_tile} + 15'h0001;
    end
    else
    begin
        if(inc_v_count)
        begin
            if(v_fine == 3'b111 && v_tile == 5'b11101)
            begin
                next_v_name = ~v_name;
                next_v_tile = 5'h00;
                next_v_fine = 3'h0;
            end
            else
            begin
                //{next_v_name, next_v_tile, next_v_fine} = {v_name, v_tile, v_fine} + 9'h001;
					 {next_v_tile, next_v_fine} = {v_tile, v_fine} + 8'h01;
            end
        end
        if(inc_h_count)
        begin
            {next_h_name, next_h_tile} = {h_name, h_tile} + 6'h01;
        end
        if(update_v_count || ri_address_update)
        begin
            next_v_name  = ri_v_name;
            next_v_tile = ri_v_tile;
            next_v_fine = ri_v_fine;
        end
        if(update_h_count || ri_address_update)
        begin
            next_h_name  = ri_h_name;
            next_h_tile = ri_h_tile;
        end
    end
end

always @(*)
begin
    next_picture_address = picture_address;
    next_tile_attribute = tile_attribute;
    next_pattern_data0 = pattern_data0;
    next_bg_shift3 = bg_shift3;
    next_bg_shift2 = bg_shift2;
    next_bg_shift1 = bg_shift1;
    next_bg_shift0 = bg_shift0;

    update_v_count = 1'b0;
    inc_v_count = 1'b0;
    update_h_count = 1'b0;
    inc_h_count = 1'b0;
    
    bg_vram_a = {v_fine[1:0], v_name, h_name, v_tile, h_tile};
    
    if(ri_bg_enable && active_rows && ~prev_active_rows)
    begin
        update_h_count = 1'b1;
        update_v_count = 1'b1;
    end
    
    if(ri_bg_enable && active_render_area)
    begin
        if(NES_col == 8'd255)   //reached end of row
        begin
            update_h_count = 1'b1;

            if(vert_scaler)    //changing to new row
            begin
                if(NES_row == 8'd239)  //finishing last row
                    update_v_count = 1'b1;
                else
                    inc_v_count = 1'b1;
            end
        end
        else if(NES_col[2:0] == 3'h7)
        begin
            inc_h_count         = 1'b1;
        end

        next_bg_shift3 = {bg_shift3[8], bg_shift3[8:1]};
        next_bg_shift2 = {bg_shift2[8], bg_shift2[8:1]};
        next_bg_shift1 = {1'b0, bg_shift1[15:1]};
        next_bg_shift0 = {1'b0, bg_shift0[15:1]};

        if(NES_col[2:0] == 3'h7)
        begin
            next_bg_shift3[8]  = tile_attribute[1];
            next_bg_shift2[8]  = tile_attribute[0];

            next_bg_shift1[15] = vram_d_in[0];
            next_bg_shift1[14] = vram_d_in[1];
            next_bg_shift1[13] = vram_d_in[2];
            next_bg_shift1[12] = vram_d_in[3];
            next_bg_shift1[11] = vram_d_in[4];
            next_bg_shift1[10] = vram_d_in[5];
            next_bg_shift1[9] = vram_d_in[6];
            next_bg_shift1[8] = vram_d_in[7];

            next_bg_shift0[15] = pattern_data0[0];
            next_bg_shift0[14] = pattern_data0[1];
            next_bg_shift0[13] = pattern_data0[2];
            next_bg_shift0[12] = pattern_data0[3];
            next_bg_shift0[11] = pattern_data0[4];
            next_bg_shift0[10] = pattern_data0[5];
            next_bg_shift0[9] = pattern_data0[6];
            next_bg_shift0[8] = pattern_data0[7];
        end
          
        //output PPU address and latch in data
        case (NES_col[2:0])
        3'd0:
            bg_vram_a = {2'b10, v_name, h_name, v_tile, h_tile};
        3'd1:
        begin
            bg_vram_a = {2'b10, v_name, h_name, v_tile, h_tile};
            next_picture_address = vram_d_in;
        end
        3'd2:
            bg_vram_a = {2'b10, v_name, h_name, 4'b1111, v_tile[4:2], h_tile[4:2]};
        3'd3:
        begin
            bg_vram_a = {2'b10, v_name, h_name, 4'b1111, v_tile[4:2], h_tile[4:2]};
            next_tile_attribute = vram_d_in >> {v_tile[1], h_tile[1], 1'b0};
        end
        3'd4:
            bg_vram_a = {1'b0, ri_background_select, picture_address, 1'b0, v_fine};
        3'd5:
        begin
            bg_vram_a = {1'b0, ri_background_select, picture_address, 1'b0, v_fine};
            next_pattern_data0 = vram_d_in;
        end
        3'd6:
            bg_vram_a = {1'b0, ri_background_select, picture_address, 1'b1, v_fine};
        3'd7:
        begin
            bg_vram_a = {1'b0, ri_background_select, picture_address, 1'b1, v_fine};
            //next_pattern_data1 = vram_d_in;
        end
        endcase
    end
end

wire clip;
wire clip_area;
wire[3:0] bg_palette_index;
assign clip_area = (NES_col < 8'd16) & (|NES_col[7:3]); //pixels are actually drawn 8 cycles after NES_col and we want to block the first 8
assign clip = ri_bg_clip_enable && clip_area;
assign bg_palette_index = (~clip & ri_bg_enable & debug_in[0]) ? {bg_shift3[ri_h_fine], bg_shift2[ri_h_fine], bg_shift1[ri_h_fine], bg_shift0[ri_h_fine]} : 4'h0;

//Sprite rendering logic

//OAM memory
wire[7:0] OAM_a;
wire[7:0] OAM_d;
wire[7:0] OAM_q;
wire OAM_wren;
reg[7:0] m_OAM[255:0];
reg[7:0] OAM_a_hold;

always @(posedge clk_in)
begin
    OAM_a_hold <= OAM_a;
    if(OAM_wren)
    begin
        m_OAM[OAM_a] <= OAM_d;
    end
end
assign OAM_q = m_OAM[OAM_a_hold];

//Secondary OAM
wire[4:0] sec_OAM_a;
wire[7:0] sec_OAM_d;
reg[7:0] sec_OAM_q;
wire sec_OAM_wren;
reg[7:0] m_sec_OAM[31:0];

always @(posedge clk_in)
begin
    if(sec_OAM_wren)
    begin
        m_sec_OAM[sec_OAM_a] <= sec_OAM_d;
    end
    sec_OAM_q <= m_sec_OAM[sec_OAM_a];
end

//Sprite rendering FSM
reg[3:0] state;

localparam[3:0]
        S_IDLE = 4'h0,
        S_CLEAR = 4'h1,
        S_EVALUATE = 4'h2,
        S_EVALUATE_NOP = 4'h3,
        S_LOAD_NOP = 4'h4,
        S_LOAD_REGS = 4'h5,
        S_FETCH_NOP = 4'h6,
        S_FETCH_PATTERN_LOW = 4'h7,
        S_FETCH_PATTERN_HIGH = 4'h8;

reg[7:0] OAM_address;
reg[5:0] sec_OAM_address;
reg gate_sec_OAM;
reg sec_OAM_write;
reg[12:0] spr_vram_a;

reg[15:0] spr_shift_low[7:0];    //shift registers for low bits of pattern data
reg[15:0] spr_shift_high[7:0];   //shift registers for high bits of pattern data
reg[5:0] spr_attribute[7:0];    //sprite attributes for the 8 sprites in current line
reg[7:0] spr_col[7:0];          //X position of sprites in current line
reg[3:0] spr_row;
reg spr_v_invert;
reg spr_h_invert;
//reg spr_active[7:0];    //indicates that the sprite is currently being drawn
reg spr_primary_exists; //indicates that the first sprite found was the primary sprite
reg sprite_overflow;

wire[8:0] spr_y_compare;
wire spr_in_range;

//assign spr_y_compare = NES_row - OAM_q;
assign spr_y_compare = NES_row + ~OAM_q + {7'h0, vert_scaler};
assign sec_OAM_d = ((sec_OAM_address[1:0] == 2'b00) ? spr_y_compare : OAM_q) | {8{~gate_sec_OAM}};  //hack to store relative Y position
assign spr_in_range = (~|spr_y_compare[8:4]) & (~spr_y_compare[3] | ri_sprite_height);
assign sec_OAM_wren = sec_OAM_write;
assign sec_OAM_a = sec_OAM_address[4:0];
assign OAM_a = (vblank | ~ri_spr_enable) ? ri_oam_address : OAM_address;
assign OAM_wren = (vblank | ~ri_spr_enable) ? ri_oam_wr : 1'b0;
assign OAM_d = ri_oam_d;
assign ri_oam_q = OAM_q;
assign ri_spr_overflow = sprite_overflow;

always @(posedge clk_in)
begin
    if(rst_in)
    begin
        state <= S_IDLE;
    end
    else
    begin
        if(active_rows && ~prev_active_rows)
            sprite_overflow <= 1'b0;
        if(active_render_area & (|NES_row[7:0]))
        begin
            if(horiz_advance)
            begin
                spr_col[0] <= (|spr_col[0]) ? (spr_col[0] - 8'h01) : spr_col[0];
                spr_col[1] <= (|spr_col[1]) ? (spr_col[1] - 8'h01) : spr_col[1];
                spr_col[2] <= (|spr_col[2]) ? (spr_col[2] - 8'h01) : spr_col[2];
                spr_col[3] <= (|spr_col[3]) ? (spr_col[3] - 8'h01) : spr_col[3];
                spr_col[4] <= (|spr_col[4]) ? (spr_col[4] - 8'h01) : spr_col[4];
                spr_col[5] <= (|spr_col[5]) ? (spr_col[5] - 8'h01) : spr_col[5];
                spr_col[6] <= (|spr_col[6]) ? (spr_col[6] - 8'h01) : spr_col[6];
                spr_col[7] <= (|spr_col[7]) ? (spr_col[7] - 8'h01) : spr_col[7];
            
                spr_shift_low[0] <= ~(|spr_col[0]) ? ({1'b0, spr_shift_low[0][15:1]}) : spr_shift_low[0];
                spr_shift_low[1] <= ~(|spr_col[1]) ? ({1'b0, spr_shift_low[1][15:1]}) : spr_shift_low[1];
                spr_shift_low[2] <= ~(|spr_col[2]) ? ({1'b0, spr_shift_low[2][15:1]}) : spr_shift_low[2];
                spr_shift_low[3] <= ~(|spr_col[3]) ? ({1'b0, spr_shift_low[3][15:1]}) : spr_shift_low[3];
                spr_shift_low[4] <= ~(|spr_col[4]) ? ({1'b0, spr_shift_low[4][15:1]}) : spr_shift_low[4];
                spr_shift_low[5] <= ~(|spr_col[5]) ? ({1'b0, spr_shift_low[5][15:1]}) : spr_shift_low[5];
                spr_shift_low[6] <= ~(|spr_col[6]) ? ({1'b0, spr_shift_low[6][15:1]}) : spr_shift_low[6];
                spr_shift_low[7] <= ~(|spr_col[7]) ? ({1'b0, spr_shift_low[7][15:1]}) : spr_shift_low[7];
                
                spr_shift_high[0] <= ~(|spr_col[0]) ? ({1'b0, spr_shift_high[0][15:1]}) : spr_shift_high[0];
                spr_shift_high[1] <= ~(|spr_col[1]) ? ({1'b0, spr_shift_high[1][15:1]}) : spr_shift_high[1];
                spr_shift_high[2] <= ~(|spr_col[2]) ? ({1'b0, spr_shift_high[2][15:1]}) : spr_shift_high[2];
                spr_shift_high[3] <= ~(|spr_col[3]) ? ({1'b0, spr_shift_high[3][15:1]}) : spr_shift_high[3];
                spr_shift_high[4] <= ~(|spr_col[4]) ? ({1'b0, spr_shift_high[4][15:1]}) : spr_shift_high[4];
                spr_shift_high[5] <= ~(|spr_col[5]) ? ({1'b0, spr_shift_high[5][15:1]}) : spr_shift_high[5];
                spr_shift_high[6] <= ~(|spr_col[6]) ? ({1'b0, spr_shift_high[6][15:1]}) : spr_shift_high[6];
                spr_shift_high[7] <= ~(|spr_col[7]) ? ({1'b0, spr_shift_high[7][15:1]}) : spr_shift_high[7];
            end
        end
        else
        begin
            spr_shift_low[0][7:0] <= 8'h00;
            spr_shift_low[1][7:0] <= 8'h00;
            spr_shift_low[2][7:0] <= 8'h00;
            spr_shift_low[3][7:0] <= 8'h00;
            spr_shift_low[4][7:0] <= 8'h00;
            spr_shift_low[5][7:0] <= 8'h00;
            spr_shift_low[6][7:0] <= 8'h00;
            spr_shift_low[7][7:0] <= 8'h00;
            
            spr_shift_high[0][7:0] <= 8'h00;
            spr_shift_high[1][7:0] <= 8'h00;
            spr_shift_high[2][7:0] <= 8'h00;
            spr_shift_high[3][7:0] <= 8'h00;
            spr_shift_high[4][7:0] <= 8'h00;
            spr_shift_high[5][7:0] <= 8'h00;
            spr_shift_high[6][7:0] <= 8'h00;
            spr_shift_high[7][7:0] <= 8'h00;
        end
        //state machine logic
        case(state)
            S_IDLE:
            begin
                OAM_address <= 8'h00;
                sec_OAM_address <= 6'h00;
                gate_sec_OAM <= 1'b0;
                sec_OAM_write <= 1'b0;
                if(active_render_area & ri_spr_enable)
                begin
                    sec_OAM_write <= 1'b1;
                    state <= S_CLEAR;
                end
            end
            S_CLEAR:
            begin
                sec_OAM_address[4:0] <= sec_OAM_address[4:0] + 5'h01;
                if(&sec_OAM_address[4:0])
                begin
                    gate_sec_OAM <= 1'b1;
                    state <= S_EVALUATE;
                end
            end
            S_EVALUATE:
            begin
                sec_OAM_write <= 1'b0;
                state <= S_EVALUATE_NOP;
                if(spr_in_range | (|sec_OAM_address[1:0]))   //start to copy or currently copying
                begin
                    OAM_address <= OAM_address + 8'h01;
                    sec_OAM_address <= sec_OAM_address[4:0] + 5'h01;
                    if(~(|sec_OAM_address[5:2]))
                        spr_primary_exists <= 1'b1;
                end
                else    //no match. check the next sprite
                begin
                    OAM_address <= OAM_address + 8'h04;
                    if(~(|sec_OAM_address[5:2]))
                        spr_primary_exists <= 1'b0;
                end
                if(sec_OAM_address[5] && spr_in_range)
                begin
                    sec_OAM_address <= 6'h00;
                    sprite_overflow <= 1'b1;
                    state <= S_LOAD_NOP;
                end
            end
            S_EVALUATE_NOP:
            begin
                sec_OAM_write <= ~sec_OAM_address[5];   //do not enable write is sec_OAM is full
                state <= S_EVALUATE;
                if(OAM_address == 8'h00)    //done checking all OAM entries
                begin
                    sec_OAM_write <= 1'b0;
                    sec_OAM_address <= 6'h00;
                    state <= S_LOAD_NOP;
                end
            end
            S_LOAD_NOP:
            begin
                if(~active_render_area)   //the states that follow need access to vram, which is busy in the render area
                    state <= S_LOAD_REGS;
            end
            S_LOAD_REGS:
            begin
                case(sec_OAM_address[1:0])
                    2'b00:
                    begin
                        sec_OAM_address <= sec_OAM_address + 5'h01;
                        spr_row <= sec_OAM_q[3:0];  //Y position above current line
                        state <= S_LOAD_NOP;
                    end
                    2'b01:
                    begin
                        sec_OAM_address <= sec_OAM_address + 5'h01;
                        if(ri_sprite_height)
                            spr_vram_a[12:5] <= {sec_OAM_q[0], sec_OAM_q[7:1]};
                        else
                            spr_vram_a[12:4] <= {ri_sprite_select, sec_OAM_q[7:0]}; //Tile ID
                        state <= S_LOAD_NOP;
                    end
                    2'b10:
                    begin
                        sec_OAM_address <= sec_OAM_address + 5'h01;
                        spr_attribute[sec_OAM_address[4:2]] <= sec_OAM_q[5:0];   //Attribute byte
                        spr_v_invert <= sec_OAM_q[7];   //these are duplicates of bits in spr_attribute. They are used to avoid decoding logic.
                        spr_h_invert <= sec_OAM_q[6];
                        state <= S_LOAD_NOP;
                    end
                    2'b11:
                    begin
                        spr_col[sec_OAM_address[4:2]] <= sec_OAM_q; //X position
                        if(ri_sprite_height)
                            spr_vram_a[4] <= spr_v_invert ^ spr_row[3];
                        spr_vram_a[2:0] <= {3{spr_v_invert}} ^ spr_row[2:0];  //Y position above current line
                        state <= S_FETCH_NOP;
                    end
                endcase
            end
            S_FETCH_NOP:
            begin
                spr_vram_a[3] <= 1'b0;
                if(horiz_advance)
                    state <= S_FETCH_PATTERN_LOW;
            end
            S_FETCH_PATTERN_LOW:
            begin
                if(horiz_advance)
                begin
                    spr_vram_a[3] <= 1'b1;
                    if(spr_h_invert)
                        spr_shift_low[sec_OAM_address[4:2]][15:8] <= vram_d_in[7:0];
                    else
                    begin
                        spr_shift_low[sec_OAM_address[4:2]][15] <= vram_d_in[0];
                        spr_shift_low[sec_OAM_address[4:2]][14] <= vram_d_in[1];
                        spr_shift_low[sec_OAM_address[4:2]][13] <= vram_d_in[2];
                        spr_shift_low[sec_OAM_address[4:2]][12] <= vram_d_in[3];
                        spr_shift_low[sec_OAM_address[4:2]][11] <= vram_d_in[4];
                        spr_shift_low[sec_OAM_address[4:2]][10] <= vram_d_in[5];
                        spr_shift_low[sec_OAM_address[4:2]][9] <= vram_d_in[6];
                        spr_shift_low[sec_OAM_address[4:2]][8] <= vram_d_in[7];
                    end
                    //spr_shift_low[sec_OAM_address[4:2]][15:8] <= spr_h_invert ? vram_d_in[7:0] : vram_d_in[0:7];
                    state <= S_FETCH_PATTERN_HIGH;
                end
            end
            S_FETCH_PATTERN_HIGH:
            begin
                if(horiz_advance)
                begin
                    sec_OAM_address <= sec_OAM_address + 5'h01;
                    if(spr_h_invert)
                        spr_shift_high[sec_OAM_address[4:2]][15:8] <= vram_d_in[7:0];
                    else
                    begin
                        spr_shift_high[sec_OAM_address[4:2]][15] <= vram_d_in[0];
                        spr_shift_high[sec_OAM_address[4:2]][14] <= vram_d_in[1];
                        spr_shift_high[sec_OAM_address[4:2]][13] <= vram_d_in[2];
                        spr_shift_high[sec_OAM_address[4:2]][12] <= vram_d_in[3];
                        spr_shift_high[sec_OAM_address[4:2]][11] <= vram_d_in[4];
                        spr_shift_high[sec_OAM_address[4:2]][10] <= vram_d_in[5];
                        spr_shift_high[sec_OAM_address[4:2]][9] <= vram_d_in[6];
                        spr_shift_high[sec_OAM_address[4:2]][8] <= vram_d_in[7];
                    end
                    //spr_shift_high[sec_OAM_address[4:2]][15:8] <= spr_h_invert ? vram_d_in[7:0] : vram_d_in[0:7];
                    if(&sec_OAM_address[4:2])
                        state <= S_IDLE;
                    else
                        state <= S_LOAD_NOP;
                end
            end
        endcase
    end
end

reg[3:0] spr_palette_index;
reg spr_priority;
reg spr_primary;
always @(ri_spr_enable, debug_in[1], ri_spr_clip_enable, clip_area, spr_primary_exists,
		spr_shift_high[0], spr_shift_high[1], spr_shift_high[2], spr_shift_high[3],
		spr_shift_high[4], spr_shift_high[5], spr_shift_high[6], spr_shift_high[7],
		spr_shift_low[0], spr_shift_low[1], spr_shift_low[2], spr_shift_low[3],
		spr_shift_low[4], spr_shift_low[5], spr_shift_low[6], spr_shift_low[7],
		spr_attribute[0], spr_attribute[1], spr_attribute[2], spr_attribute[3],
		spr_attribute[4], spr_attribute[5], spr_attribute[6], spr_attribute[7])	//needed for the stupid ISE synthesis tool..
begin
    if(!(ri_spr_enable & debug_in[1]) || (ri_spr_clip_enable & clip_area))
    begin
        spr_palette_index = 4'h0;
        spr_priority = 1'b0;
        spr_primary = 1'b0;
    end
    else if(spr_shift_high[0][0] | spr_shift_low[0][0])
    begin
        spr_palette_index = {spr_attribute[0][1:0], spr_shift_high[0][0], spr_shift_low[0][0]};
        spr_priority = spr_attribute[0][5];
        spr_primary = spr_primary_exists;
    end
    else if(spr_shift_high[1][0] | spr_shift_low[1][0])
    begin
        spr_palette_index = {spr_attribute[1][1:0], spr_shift_high[1][0], spr_shift_low[1][0]};
        spr_priority = spr_attribute[1][5];
        spr_primary = 1'b0;
    end
    else if(spr_shift_high[2][0] | spr_shift_low[2][0])
    begin
        spr_palette_index = {spr_attribute[2][1:0], spr_shift_high[2][0], spr_shift_low[2][0]};
        spr_priority = spr_attribute[2][5];
        spr_primary = 1'b0;
    end
    else if(spr_shift_high[3][0] | spr_shift_low[3][0])
    begin
        spr_palette_index = {spr_attribute[3][1:0], spr_shift_high[3][0], spr_shift_low[3][0]};
        spr_priority = spr_attribute[3][5];
        spr_primary = 1'b0;
    end
    else if(spr_shift_high[4][0] | spr_shift_low[4][0])
    begin
        spr_palette_index = {spr_attribute[4][1:0], spr_shift_high[4][0], spr_shift_low[4][0]};
        spr_priority = spr_attribute[4][5];
        spr_primary = 1'b0;
    end
    else if(spr_shift_high[5][0] | spr_shift_low[5][0])
    begin
        spr_palette_index = {spr_attribute[5][1:0], spr_shift_high[5][0], spr_shift_low[5][0]};
        spr_priority = spr_attribute[5][5];
        spr_primary = 1'b0;
    end
    else if(spr_shift_high[6][0] | spr_shift_low[6][0])
    begin
        spr_palette_index = {spr_attribute[6][1:0], spr_shift_high[6][0], spr_shift_low[6][0]};
        spr_priority = spr_attribute[6][5];
        spr_primary = 1'b0;
    end
    else if(spr_shift_high[7][0] | spr_shift_low[7][0])
    begin
        spr_palette_index = {spr_attribute[7][1:0], spr_shift_high[7][0], spr_shift_low[7][0]};
        spr_priority = spr_attribute[7][5];
        spr_primary = 1'b0;
    end
    else
    begin
        spr_palette_index = 4'h0;
        spr_priority = 1'b0;
        spr_primary = 1'b0;
    end
end

//
// Palette memory
//
reg[5:0] palette_ram [31:0];  // internal palette RAM.  32 entries, 6-bits per entry.
reg[4:0] pram_a_hold;   //read address
wire[5:0] pram_q;
wire[4:0] pram_a;   //internal address from spr, bg, or ri
wire[4:0] pram_address; //address from bg or spr

assign pram_a = (vblank | ~(ri_spr_enable | ri_bg_enable)) ? ((vram_a_out[4:0] & 5'h03) ? (vram_a_out[4:0]) : (vram_a_out[4:0] & 5'h0f)) : (pram_address);

initial
begin
    palette_ram[5'h00] = 6'h09;
    palette_ram[5'h01] = 6'h01;
    palette_ram[5'h02] = 6'h00;
    palette_ram[5'h03] = 6'h01;
    palette_ram[5'h04] = 6'h00;
    palette_ram[5'h05] = 6'h02;
    palette_ram[5'h06] = 6'h02;
    palette_ram[5'h07] = 6'h0d;
    palette_ram[5'h08] = 6'h08;
    palette_ram[5'h09] = 6'h10;
    palette_ram[5'h0a] = 6'h08;
    palette_ram[5'h0b] = 6'h24;
    palette_ram[5'h0c] = 6'h00;
    palette_ram[5'h0d] = 6'h00;
    palette_ram[5'h0e] = 6'h04;
    palette_ram[5'h0f] = 6'h2c;
	 palette_ram[5'h10] = 6'h00;
    palette_ram[5'h11] = 6'h01;
    palette_ram[5'h12] = 6'h34;
    palette_ram[5'h13] = 6'h03;
	 palette_ram[5'h14] = 6'h00;
    palette_ram[5'h15] = 6'h04;
    palette_ram[5'h16] = 6'h00;
    palette_ram[5'h17] = 6'h14;
	 palette_ram[5'h18] = 6'h00;
    palette_ram[5'h19] = 6'h3a;
    palette_ram[5'h1a] = 6'h00;
    palette_ram[5'h1b] = 6'h02;
	 palette_ram[5'h1c] = 6'h00;
    palette_ram[5'h1d] = 6'h20;
    palette_ram[5'h1e] = 6'h2c;
    palette_ram[5'h1f] = 6'h08;
end

always @(posedge clk_in)
begin
    pram_a_hold <= pram_a;
    if(ri_pram_wr)
        palette_ram[pram_a] <= vram_d_out[5:0];
end
assign pram_q = palette_ram[pram_a_hold];
assign ri_pram_q = {2'b00, pram_q};

//
// Multiplexer.  Final system palette index derivation.
//
reg[5:0] rgb_reg;
reg[5:0] rgb_buf;
reg spr0_hit;
wire spr_foreground;
wire spr_trans;
wire bg_trans;

assign spr_foreground  = ~spr_priority;
assign spr_trans       = ~(|spr_palette_index[1:0]);
assign bg_trans        = ~(|bg_palette_index[1:0]);
assign ri_spr0_hit = spr0_hit;

always @(posedge clk_in)
begin
    if (rst_in)
        spr0_hit <= 1'b0;
    else
    begin
        if(active_rows & ~prev_active_rows)
            spr0_hit <= 1'b0;
        else if(spr_primary && !spr_trans && !bg_trans)
            spr0_hit <= 1'b1;
    end
end

assign pram_address = ((spr_foreground || bg_trans) && !spr_trans) ? {1'b1, spr_palette_index} : (!bg_trans) ? {1'b0, bg_palette_index} : 5'h00;

always @(posedge clk_in)
begin
//    case (pram_q)
//        6'h00:  rgb_reg <= { 3'h3, 3'h3, 2'h1 };
//        6'h01:  rgb_reg <= { 3'h1, 3'h0, 2'h2 };
//        6'h02:  rgb_reg <= { 3'h0, 3'h0, 2'h2 };
//        6'h03:  rgb_reg <= { 3'h2, 3'h0, 2'h2 };
//        6'h04:  rgb_reg <= { 3'h4, 3'h0, 2'h1 };
//        6'h05:  rgb_reg <= { 3'h5, 3'h0, 2'h0 };
//        6'h06:  rgb_reg <= { 3'h5, 3'h0, 2'h0 };
//        6'h07:  rgb_reg <= { 3'h3, 3'h0, 2'h0 };
//        6'h08:  rgb_reg <= { 3'h2, 3'h1, 2'h0 };
//        6'h09:  rgb_reg <= { 3'h0, 3'h2, 2'h0 };
//        6'h0a:  rgb_reg <= { 3'h0, 3'h2, 2'h0 };
//        6'h0b:  rgb_reg <= { 3'h0, 3'h1, 2'h0 };
//        6'h0c:  rgb_reg <= { 3'h0, 3'h1, 2'h1 };
//        6'h0d:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h0e:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h0f:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        
//        6'h10:  rgb_reg <= { 3'h5, 3'h5, 2'h2 };
//        6'h11:  rgb_reg <= { 3'h0, 3'h3, 2'h3 };
//        6'h12:  rgb_reg <= { 3'h1, 3'h1, 2'h3 };
//        6'h13:  rgb_reg <= { 3'h4, 3'h0, 2'h3 };
//        6'h14:  rgb_reg <= { 3'h5, 3'h0, 2'h2 };
//        6'h15:  rgb_reg <= { 3'h7, 3'h0, 2'h1 };
//        6'h16:  rgb_reg <= { 3'h6, 3'h1, 2'h0 };
//        6'h17:  rgb_reg <= { 3'h6, 3'h2, 2'h0 };
//        6'h18:  rgb_reg <= { 3'h4, 3'h3, 2'h0 };
//        6'h19:  rgb_reg <= { 3'h0, 3'h4, 2'h0 };
//        6'h1a:  rgb_reg <= { 3'h0, 3'h5, 2'h0 };
//        6'h1b:  rgb_reg <= { 3'h0, 3'h4, 2'h0 };
//        6'h1c:  rgb_reg <= { 3'h0, 3'h4, 2'h2 };
//        6'h1d:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h1e:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h1f:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        
//        6'h20:  rgb_reg <= { 3'h7, 3'h7, 2'h3 };
//        6'h21:  rgb_reg <= { 3'h1, 3'h5, 2'h3 };
//        6'h22:  rgb_reg <= { 3'h2, 3'h4, 2'h3 };
//        6'h23:  rgb_reg <= { 3'h5, 3'h4, 2'h3 };
//        6'h24:  rgb_reg <= { 3'h7, 3'h3, 2'h3 };
//        6'h25:  rgb_reg <= { 3'h7, 3'h3, 2'h2 };
//        6'h26:  rgb_reg <= { 3'h7, 3'h3, 2'h1 };
//        6'h27:  rgb_reg <= { 3'h7, 3'h4, 2'h0 };
//        6'h28:  rgb_reg <= { 3'h7, 3'h5, 2'h0 };
//        6'h29:  rgb_reg <= { 3'h4, 3'h6, 2'h0 };
//        6'h2a:  rgb_reg <= { 3'h2, 3'h6, 2'h1 };
//        6'h2b:  rgb_reg <= { 3'h2, 3'h7, 2'h2 };
//        6'h2c:  rgb_reg <= { 3'h0, 3'h7, 2'h3 };
//        6'h2d:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h2e:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h2f:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        
//        6'h30:  rgb_reg <= { 3'h7, 3'h7, 2'h3 };
//        6'h31:  rgb_reg <= { 3'h5, 3'h7, 2'h3 };
//        6'h32:  rgb_reg <= { 3'h6, 3'h6, 2'h3 };
//        6'h33:  rgb_reg <= { 3'h6, 3'h6, 2'h3 };
//        6'h34:  rgb_reg <= { 3'h7, 3'h6, 2'h3 };
//        6'h35:  rgb_reg <= { 3'h7, 3'h6, 2'h3 };
//        6'h36:  rgb_reg <= { 3'h7, 3'h5, 2'h2 };
//        6'h37:  rgb_reg <= { 3'h7, 3'h6, 2'h2 };
//        6'h38:  rgb_reg <= { 3'h7, 3'h7, 2'h2 };
//        6'h39:  rgb_reg <= { 3'h7, 3'h7, 2'h2 };
//        6'h3a:  rgb_reg <= { 3'h5, 3'h7, 2'h2 };
//        6'h3b:  rgb_reg <= { 3'h5, 3'h7, 2'h3 };
//        6'h3c:  rgb_reg <= { 3'h4, 3'h7, 2'h3 };
//        6'h3d:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h3e:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//        6'h3f:  rgb_reg <= { 3'h0, 3'h0, 2'h0 };
//    endcase
	 case (pram_q)
        6'h00:  rgb_reg <= 6'o25;
        6'h01:  rgb_reg <= 6'o02;
        6'h02:  rgb_reg <= 6'o03;
        6'h03:  rgb_reg <= 6'o22;
        6'h04:  rgb_reg <= 6'o41;
        6'h05:  rgb_reg <= 6'o42;
        6'h06:  rgb_reg <= 6'o44;
        6'h07:  rgb_reg <= 6'o45;
		  
        6'h08:  rgb_reg <= 6'o24;
        6'h09:  rgb_reg <= 6'o04;
        6'h0a:  rgb_reg <= 6'o10;
        6'h0b:  rgb_reg <= 6'o10;
        6'h0c:  rgb_reg <= 6'o05;
        6'h0d:  rgb_reg <= 6'o00;
        6'h0e:  rgb_reg <= 6'o00;
        6'h0f:  rgb_reg <= 6'o00;
        
        6'h10:  rgb_reg <= 6'o52;
        6'h11:  rgb_reg <= 6'o13;
        6'h12:  rgb_reg <= 6'o07;
        6'h13:  rgb_reg <= 6'o23;
        6'h14:  rgb_reg <= 6'o43;
        6'h15:  rgb_reg <= 6'o62;
        6'h16:  rgb_reg <= 6'o60;
        6'h17:  rgb_reg <= 6'o64;
		  
        6'h18:  rgb_reg <= 6'o44;
        6'h19:  rgb_reg <= 6'o30;
        6'h1a:  rgb_reg <= 6'o10;
        6'h1b:  rgb_reg <= 6'o11;
        6'h1c:  rgb_reg <= 6'o12;
        6'h1d:  rgb_reg <= 6'o00;
        6'h1e:  rgb_reg <= 6'o00;
        6'h1f:  rgb_reg <= 6'o00;
        
        6'h20:  rgb_reg <= 6'o77;
        6'h21:  rgb_reg <= 6'o37;
        6'h22:  rgb_reg <= 6'o33;
        6'h23:  rgb_reg <= 6'o67;
        6'h24:  rgb_reg <= 6'o63;
        6'h25:  rgb_reg <= 6'o73;
        6'h26:  rgb_reg <= 6'o70;
        6'h27:  rgb_reg <= 6'o71;
		  
        6'h28:  rgb_reg <= 6'o74;
        6'h29:  rgb_reg <= 6'o54;
        6'h2a:  rgb_reg <= 6'o14;
        6'h2b:  rgb_reg <= 6'o37;
        6'h2c:  rgb_reg <= 6'o17;
        6'h2d:  rgb_reg <= 6'o25;
        6'h2e:  rgb_reg <= 6'o00;
        6'h2f:  rgb_reg <= 6'o00;
        
        6'h30:  rgb_reg <= 6'o77;
        6'h31:  rgb_reg <= 6'o57;
        6'h32:  rgb_reg <= 6'o53;
        6'h33:  rgb_reg <= 6'o66;
        6'h34:  rgb_reg <= 6'o46;
        6'h35:  rgb_reg <= 6'o72;
        6'h36:  rgb_reg <= 6'o74;
        6'h37:  rgb_reg <= 6'o75;
		  
        6'h38:  rgb_reg <= 6'o76;
        6'h39:  rgb_reg <= 6'o55;
        6'h3a:  rgb_reg <= 6'o35;
        6'h3b:  rgb_reg <= 6'o37;
        6'h3c:  rgb_reg <= 6'o57;
        6'h3d:  rgb_reg <= 6'o52;
        6'h3e:  rgb_reg <= 6'o00;
        6'h3f:  rgb_reg <= 6'o00;
    endcase
    if(~active_draw_area | (~ri_spr_enable & ~ri_bg_enable))
		  rgb_buf <= 6'h00;
    else
        rgb_buf <= rgb_reg;
    hsync_out <= HSYNC;
    vsync_out <= VSYNC;
end

assign { r_out, g_out, b_out } = rgb_buf;
assign vram_a_out  = (ri_spr_enable && ~active_render_area && ~vblank) ? spr_vram_a : bg_vram_a;

endmodule
