module CoolGirl # (
		parameter USE_MAPPER_009_010 = 1,			// mapper #9 - MMC2, #10 - MMC4
		parameter USE_MAPPER_011 = 1,					// mapper #11 - Color Dreams
		parameter USE_MAPPER_018 = 1,					// mapper #18
		parameter USE_MAPPER_021_022_023_025 = 1,	// mappers #21, #22, #23, #25 - VRC2, VRC4
		parameter USE_MAPPER_022 = 1,					// mapper #22 - VRC2a (shifted CHR lines)
		parameter USE_VRC4_INTERRUPTS = 1,			// for VRC4
		parameter USE_MAPPER_032 = 1,					// mapper #32 - IREM-G101
		parameter USE_MAPPER_033_048 = 1,			// mappers #33 & #48 - Taito
		parameter USE_MAPPER_048_INTERRUPTS = 1,	// mapper #48 - Taito
		parameter USE_MAPPER_066 = 1,					// mapper #66 - GxROM
		parameter USE_MAPPER_069 = 1, 				// mapper #69 - Sunsoft
		parameter USE_MAPPER_071 = 1,					// mapper #71 (for Fire Hawk only)
		parameter USE_MAPPER_078 = 1,					// mapper #78 - Holy Diver
		parameter USE_MAPPER_087 = 1,					// mapper #87
		parameter USE_MAPPER_090 = 1,					// mapper #90 - JY, for Aladdin only
		parameter USE_MAPPER_093 = 1,					// mapper #93
		parameter USE_MAPPER_097 = 1,					// mapper #97 - IREM TAMS1
		parameter USE_MAPPER_118 = 1,					// mapper #118 - TxSROM
		parameter USE_MAPPER_163 = 1,					// mapper #163
		parameter USE_MAPPER_189 = 1,					// mapper #189
		parameter USE_MAPPER_228 = 1 					// mapper #228 - Cheetahmen II only
	)
	(
	input	m2,
	input romsel,
	input cpu_rw_in,
	input [14:0] cpu_addr_in,
	inout [7:0] cpu_data_in,
	output [26:13] cpu_addr_out,
	output [14:13] sram_addr_out,
	output flash_we,
	output flash_oe,
	output flash_ce,
	output sram_ce,
	output sram_we,
	output sram_oe,
		
	input ppu_rd_in,
	input ppu_wr_in,
	input [13:0] ppu_addr_in,
	output [17:10] ppu_addr_out,
	output ppu_rd_out,
	output ppu_wr_out,
	output ppu_ciram_a10,
	input ppu_not_a13,
	output ppu_ciram_ce,
		
	output irq
);
	reg [7:0] new_dendy_init = 8'b11111111;
	reg new_dendy = 0;
	
	assign cpu_addr_out[26:13] = {cpu_base[26:14] | (cpu_addr_mapped[20:14] & ~prg_mask[20:14]), cpu_addr_mapped[13]};
	assign sram_addr_out[14:13] = sram_page[1:0];
	assign ppu_addr_out[17:10] = {ppu_addr_mapped[17:13] & ~chr_mask[17:13], ppu_addr_mapped[12:10]};

	assign cpu_data_in = cpu_data_out_enabled ? cpu_data_out : 8'bZZZZZZZZ;	
	wire flash_ce_w = ~(~romsel | (m2 & map_rom_on_6000 & cpu_addr_in[14] & cpu_addr_in[13]));
	assign flash_ce = flash_ce_w
		| cpu_data_out_enabled;
	assign flash_oe = (~cpu_rw_in | flash_ce_w) 
		& ~cpu_data_out_enabled; // to switch data direction
	assign flash_we = cpu_rw_in | flash_ce_w | ~prg_write_enabled;
	wire sram_ce_w = ~(cpu_addr_in[14] & cpu_addr_in[13] & m2 & romsel & sram_enabled & ~map_rom_on_6000);
	assign sram_ce = sram_ce_w;
	assign sram_we = cpu_rw_in | sram_ce_w;
	assign sram_oe = ~cpu_rw_in | sram_ce_w | cpu_data_out_enabled;
	assign ppu_rd_out = ppu_rd_in | ppu_addr_in[13];
	assign ppu_wr_out = ppu_wr_in | ppu_addr_in[13] | ~chr_write_enabled;
	assign ppu_ciram_ce = 1'bZ; // ppu_not_a13;

	always @ (posedge m2)
	begin
		if (new_dendy_init != 0)
			new_dendy_init = new_dendy_init - 1'b1;
	end
	
	always @ (negedge ppu_rd_in)
	begin
		if (new_dendy_init == 0 && (ppu_addr_in[13] != ~ppu_not_a13))
			new_dendy = 1;
	end
	
`include "mappers.vh"
	
endmodule


