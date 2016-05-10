module CoolGirl # (
		parameter USE_VRC2 = 0,					// mappers #21, #22, #23, #25
		parameter USE_VRC2a = 0,				// mapper #22
		parameter USE_VRC4_INTERRUPTS = 0,	// for VRC4
		parameter USE_TAITO = 0,				// mappers #33 & #48
		parameter USE_TAITO_INTERRUPTS = 0,	// mapper #48
		parameter USE_SUNSOFT = 0, 			// mapper #69
		parameter USE_MAPPER_78 = 0,			// mapper #78 - Holy Diver
		parameter USE_COLOR_DREAMS = 0,		// mapper #11
		parameter USE_GxROM = 0,				// mapper #66
		parameter USE_CHEETAHMEN2 = 0, 		// mapper #228
		parameter USE_FIRE_HAWK = 0,			// for Fire Hawk only (mapper #71)
		parameter USE_TxSROM = 0,				// mapper #118
		parameter USE_IREM_TAMS1 = 0,			// mapper #97
		parameter USE_IREM_G101 = 0,			// mapper #32
		parameter USE_MAPPER_87 = 0,			// mapper #87
		parameter USE_MMC2 = 0,					// mapper #9
		parameter USE_MMC4 = 0,					// mapper #10
		parameter USE_MAPPER_093 = 0,			// mapper #093
		parameter USE_MAPPER_189 = 0			// mapper #189
	)
	(
	input	m2,
	input romsel,
	input cpu_rw_in,
	input [14:0] cpu_addr_in,
	input [7:0] cpu_data_in,
	output [26:13] cpu_addr_out,
	output flash_we,
	output flash_oe,
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
	//output ppu_ciram_ce,
		
	output irq
);
	reg [26:14] cpu_base = 0;
	reg [18:14] cpu_mask = 0;
	reg [17:13] chr_mask = 0;
	reg [2:0] prg_mode = 0;
	reg map_rom_on_6000 = 0;
	reg [5:0] prg_bank_6000 = 0;
	reg [5:0] prg_bank_a = 0;
	reg [5:0] prg_bank_b = 6'b111101;
	reg [5:0] prg_bank_c = 6'b111110;
	reg [5:0] prg_bank_d = 6'b111111;
	reg [2:0] chr_mode = 0;
	reg [7:0] chr_bank_a = 0;
	reg [7:0] chr_bank_b = 1;
	reg [7:0] chr_bank_c = 2;
	reg [7:0] chr_bank_d = 3;
	reg [7:0] chr_bank_e = 4;
	reg [7:0] chr_bank_f = 5;
	reg [7:0] chr_bank_g = 6;
	reg [7:0] chr_bank_h = 7;
	reg [4:0] mapper = 0;
	reg [2:0] flags = 0;
	reg sram_enabled = 0;
	reg [1:0] sram_page = 0;
	reg chr_write_enabled = 0;
	reg prg_write_enabled = 0;
	reg [1:0] mirroring = 0;
	reg lockout = 0;
	
	// some common registers for all mappers
	reg [7:0] r0 = 0;

	assign cpu_addr_out[26:15] = {cpu_base[26:15] | (cpu_addr_mapped[18:15] & ~cpu_mask[18:15])};
	assign cpu_addr_out[14:13] = (~sram_enabled | map_rom_on_6000 | ~romsel | ~m2) ?
		{cpu_base[14] | (cpu_addr_mapped[14] & ~cpu_mask[14]), cpu_addr_mapped[13]} 
		: sram_page[1:0];
	assign ppu_addr_out[17:10] = {ppu_addr_mapped[17:13] & ~chr_mask[17:13], ppu_addr_mapped[12:10]};

	assign flash_we = cpu_rw_in | romsel | ~prg_write_enabled;
	assign flash_oe = ~(cpu_rw_in & m2 & (~romsel | (map_rom_on_6000 & cpu_addr_in[14] & cpu_addr_in[13])));
	wire sram_ce_w = ~(cpu_addr_in[14] & cpu_addr_in[13] & m2 & romsel & sram_enabled & ~map_rom_on_6000);
	assign sram_ce = sram_ce_w;
	assign sram_we = cpu_rw_in | sram_ce_w;
	assign sram_oe = ~cpu_rw_in | sram_ce_w;
	assign ppu_rd_out = ppu_rd_in | ppu_addr_in[13];
	assign ppu_wr_out = ppu_wr_in | ppu_addr_in[13] | ~chr_write_enabled;
	assign irq = (irq_scanline_out | irq_cpu_out) ? 1'b0 : 1'bZ;
	//assign ppu_ciram_ce = 1'bZ; // for backward compatibility	

	// for scanline-based interrupts
	reg [7:0] irq_scanline_counter = 0;
	reg [1:0] a12_low_time = 0;
	reg irq_scanline_reload = 0;
	reg [7:0] irq_scanline_latch = 0;
	reg irq_scanline_reload_clear = 0;
	reg irq_scanline_enabled = 0;
	reg irq_scanline_value = 0;
	reg irq_scanline_ready = 0;
	reg irq_scanline_out = 0;
	
	// for CPU interrupts
	reg [15:0] irq_cpu_value = 0;
	reg irq_cpu_out = 0;
	reg [2:0] irq_cpu_control = 0;
	reg [7:0] vrc4_irq_latch = 0;
	reg [6:0] vrc4_irq_prescaler = 0;
	reg [1:0] vrc4_irq_prescaler_counter = 0;
	// for VRC
	wire vrc_2b_hi = cpu_addr_in[1] | cpu_addr_in[3] | cpu_addr_in[5] | cpu_addr_in[7];
	wire vrc_2b_low = cpu_addr_in[0] | cpu_addr_in[2] | cpu_addr_in[4] | cpu_addr_in[6];
	// for MMC2/MMC4
	reg ppu_latch0 = 0;
	reg ppu_latch1 = 0;
	
	reg writed;
	
	assign ppu_ciram_a10 = (USE_TxSROM & (mapper == 5'b10100) & flags[0]) ? ppu_addr_mapped[17] :
		(mirroring[1] ? mirroring[0] : (mirroring[0] ? ppu_addr_in[11] : ppu_addr_in[10])); // vertical / horizontal, 1Sa, 1Sb			
	
	wire [18:13] cpu_addr_mapped = (map_rom_on_6000 & romsel & m2) ? prg_bank_6000 :
	(
		prg_mode[2] ? (
			prg_mode[1] ? (
				// 11x - 0x8000(A)
				{prg_bank_a[5:2], cpu_addr_in[14:13]}
			) : ( // prg_mode[1]
				prg_mode[0] ? (
					// 101 - 0x2000(C)+0x2000(B)+0x2000(A)+0x2000(D)
					cpu_addr_in[14] ? (cpu_addr_in[13] ? prg_bank_d : prg_bank_a) : (cpu_addr_in[13] ? prg_bank_b : prg_bank_c)
				) : ( // prg_mode[0]
					// 100 - 0x2000(A)+0x2000(B)+0x2000(C)+0x2000(D)
					cpu_addr_in[14] ? (cpu_addr_in[13] ? prg_bank_d : prg_bank_c) : (cpu_addr_in[13] ? prg_bank_b : prg_bank_a)
				)
			)
		) : ( // prg_mode[2]
			prg_mode[0] ? (
				// 0x1 - 0x4000(C) + 0x4000 (A)
				{cpu_addr_in[14] ? prg_bank_a[5:1] : prg_bank_c[5:1], cpu_addr_in[13]}
			) : ( // prg_mode[0]
				// 0x0 - 0x4000(A) + 0x4000 (С)
				{cpu_addr_in[14] ? 5'b11111 : prg_bank_a[5:1], cpu_addr_in[13]}
			)
		)
	);
	
	wire [17:10] ppu_addr_mapped = chr_mode[2] ? (
		chr_mode[1] ? (
			chr_mode[0] ? ( 
				// 111 - 0x400(A)+0x400(B)+0x400(C)+0x400(D)+0x400(E)+0x400(F)+0x400(G)+0x400(H)
				ppu_addr_in[12] ? 
					(ppu_addr_in[11] ? (ppu_addr_in[10] ? chr_bank_h : chr_bank_g) : 
					(ppu_addr_in[10] ? chr_bank_f : chr_bank_e)) : (ppu_addr_in[11] ? (ppu_addr_in[10] ? chr_bank_d : chr_bank_c) : (ppu_addr_in[10] ? chr_bank_b : chr_bank_a))
			) : ( // chr_mode[0]
				// 110 - 0x800(A)+0x800(C)+0x800(E)+0x800(G)
				{ppu_addr_in[12] ? 
					(ppu_addr_in[11] ? chr_bank_g[7:1] : chr_bank_e[7:1]) : 
					(ppu_addr_in[11] ? chr_bank_c[7:1] : chr_bank_a[7:1]), ppu_addr_in[10]}
			)
		) : ( // chr_mode[1]
			// 100 - 0x1000(A) + 0x1000(E)
			// 101 - 0x1000(A/B) + 0x1000(E/F) - MMC2 и MMC4
			{ppu_addr_in[12] ? 
				(((USE_MMC2|USE_MMC4)&chr_mode[0]&ppu_latch1) ? chr_bank_f[7:2] : chr_bank_e[7:2]) : 
				(((USE_MMC2|USE_MMC4)&chr_mode[0]&ppu_latch0) ? chr_bank_b[7:2] : chr_bank_a[7:2]),
			ppu_addr_in[11:10]}
		)
	) : ( // chr_mode[2]
		chr_mode[1] ? (
			// 010 - 0x800(A)+0x800(C)+0x400(E)+0x400(F)+0x400(G)+0x400(H) 
			// 011 - 0x400(E)+0x400(F)+0x400(G)+0x400(H)+0x800(A)+0x800(С)
			(ppu_addr_in[12]^chr_mode[0]) ? 
				(ppu_addr_in[11] ?
					(ppu_addr_in[10] ? chr_bank_h : chr_bank_g) : 
					(ppu_addr_in[10] ? chr_bank_f : chr_bank_e)
				) : (
					ppu_addr_in[11] ? {chr_bank_c[7:1],ppu_addr_in[10]} : {chr_bank_a[7:1],ppu_addr_in[10]}
				)
		) : ( // chr_mode[1]
			// 00x - 0x2000(A)
			{chr_bank_a[7:3], ppu_addr_in[12:10]}
		)
	);	
	
`include "mappers.vh"
	
endmodule
