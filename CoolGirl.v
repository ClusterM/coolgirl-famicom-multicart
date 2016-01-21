module CoolGirl #	(
		parameter USE_VRC2 = 1,				// mappers #21, #22, #23, #25
		parameter USE_VRC2a = 1,
		parameter USE_VRC4_INTERRUPTS = 1,
		parameter USE_TAITO = 0,			// mappers #33 & #48
		parameter USE_SUNSOFT = 0, 		// mapper #69
		parameter USE_MAPPER_78 = 1,		// mapper #78
		parameter USE_COLOR_DREAMS = 1,	// mapper #11
		parameter USE_GxROM = 1,			// mapper #66
		parameter USE_CHEETAHMEN2 = 1, 	// mapper #228
		parameter USE_FIRE_HAWK = 1		// for Fire Hawk only
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
	output ppu_ciram_ce,
		
	output irq
);
	reg [26:14] cpu_base;
	reg [18:14] cpu_mask;
	reg [17:13] chr_mask;
	reg [1:0] sram_page;
	reg [4:0] mapper;
	reg [2:0] flags;
	reg sram_enabled;
	reg chr_write_enabled;
	reg prg_write_enabled;
	reg [1:0] mirroring;
	reg map_rom_on_6000;
	reg lockout;

	reg [18:13] cpu_addr_mapped;
	reg [17:10] ppu_addr_mapped;
	
	// some common registers for all mappers
	reg [7:0] r0;
	reg [7:0] r1;
	reg [7:0] r2;
	reg [7:0] r3;
	reg [7:0] r4;
	reg [7:0] r5;
	reg [7:0] r6;
	reg [7:0] r7;
	reg [7:0] r8;
	reg [7:0] r9;
	reg [7:0] r10;
	reg [7:0] r11;
	reg [7:0] r12;
	reg [7:0] r13;
	reg [7:0] r14;

	reg [7:0] irq_scanline_counter;
	reg [2:0] a12_low_time;
	reg irq_scanline_reload;
	reg irq_scanline_reload_clear;
	reg irq_scanline_enabled;
	reg irq_scanline_value;
	reg irq_scanline_ready;	
	reg irq_scanline_out;
	reg irq_cpu_out;		
	
	assign cpu_addr_out[26:13] = ((romsel == 0) || (cpu_addr_in[14] & cpu_addr_in[13] & m2 & map_rom_on_6000)) ? // when ROMSEL is low of $6000-$7FFF accessed with map_rom_on_6000 on
		{cpu_base[26:14] | (cpu_addr_mapped[18:14] & ~cpu_mask[18:14]), cpu_addr_mapped[13]} : sram_page[1:0];
	assign ppu_addr_out[17:10] = {ppu_addr_mapped[17:13] & ~chr_mask[17:13], ppu_addr_mapped[12:10]};

	assign flash_we = cpu_rw_in | romsel | ~prg_write_enabled;
	assign flash_oe = ~cpu_rw_in | ~(~romsel | (cpu_addr_in[14] & cpu_addr_in[13] & m2 & map_rom_on_6000));
	assign sram_ce = !(cpu_addr_in[14] & cpu_addr_in[13] & m2 & romsel & sram_enabled & ~map_rom_on_6000);
	assign sram_we = cpu_rw_in;
	assign sram_oe = ~cpu_rw_in;
	assign ppu_rd_out = ppu_rd_in | ppu_addr_in[13];
	assign ppu_wr_out = ppu_wr_in | ppu_addr_in[13] | ~chr_write_enabled;
	assign irq = !(irq_scanline_out || irq_cpu_out) ? 1'bZ : 1'b0;
	// mirroring
	assign ppu_ciram_a10 = !mirroring[1] ? (!mirroring[0] ? ppu_addr_in[10] : ppu_addr_in[11]) : mirroring[0]; // vertical / horizontal, 1Sa, 1Sb
	assign ppu_ciram_ce = 1'bZ; // for backward compatibility	
	
	// for MMC1
	/*
	r0 - load register
	r1 - control
	r2 - chr0_bank
	r3 - chr1_bank
	r4 - prg_bank
	*/
	// for MMC3
	/*
	r8[2:0] - bank_select
	r8[3] - PRG mode
	r8[4] - CHR mode
	r8[5] - mirroring
	r8[7:6] - RAM protect
	r9 - IRQ latch
	*/
	// for VRC
	wire vrc_2b_hi = cpu_addr_in[1] | cpu_addr_in[3] | cpu_addr_in[5] | cpu_addr_in[7];
	wire vrc_2b_low = cpu_addr_in[0] | cpu_addr_in[2] | cpu_addr_in[4] | cpu_addr_in[6];
	/*
	r8[4:0] - PRG0 bank 
	r9[4:0] - PRG1 bank 
	r0 - CHR0
	r1 - CHR1
	r2 - CHR2
	r3 - CHR3
	r4 - CHR4
	r5 - CHR5
	r6 - CHR6
	r7 - CHR7
	r10 - IRQ latch
	r11[2:0] - IRQ control
	r11[4:3] - prescaler counter
	r12 - IRQ value
	r13 - IRQ prescaler value
	*/
	// for mapper #228 - Cheetahmen II :)
	/*
	r0[5:0] - CHR bank
	r1[0] - PRG mode
	r2[4:0] - PRG bank
	r3[1:0] - PRG chip... unused by Cheetahmen II
	r4[0] - mirroring
	*/
	// for mapper #69 - Sunsoft FME-7
	/*
	r14 - command register
	r0 - CHR bank 0
	r1 - CHR bank 1
	r2 - CHR bank 2
	r3 - CHR bank 3
	r4 - CHR bank 4
	r5 - CHR bank 5
	r6 - CHR bank 6
	r7 - CHR bank 7
	r8 - PRG bank 0
	r9 - PRG bank 1
	r10 - PRG bank 2
	r11 - PRG bank 3
	r9[7:6] - mirroring
	r10[7:6] - IRQ control
	r12 - IRQ low
	r13 - IRQ high
	*/	
	
	always @ (negedge m2)
	begin
		if (cpu_rw_in == 0) // write
		begin
			if (romsel == 1) // $0000-$7FFF
			begin
				if ((cpu_addr_in[14:12] == 3'b101) && (lockout == 0)) // $5000-5FFF & lockout is off
				begin
					if (cpu_addr_in[2:0] == 3'b000) // $5xx0
						cpu_base[26:22] = cpu_data_in[4:0]; // CPU base address A26-A22
					if (cpu_addr_in[2:0] == 3'b001) // $5xx1
						cpu_base[21:14] = cpu_data_in[7:0]; // CPU base address A21-A14
					if (cpu_addr_in[2:0] == 3'b010) // $5xx2
						cpu_mask[18:14] = cpu_data_in[4:0]; // CPU mask A18-A14
					if (cpu_addr_in[2:0] == 3'b011) // $5xx3
						r0[7:0] = cpu_data_in[7:0];			// direct r0 access for mapper #0 CHR bank
					if (cpu_addr_in[2:0] == 3'b100) // $5xx4
						chr_mask[17:13] = cpu_data_in[4:0];	// CHR mask A17-A13
					if (cpu_addr_in[2:0] == 3'b101) // $5xx5
						{r1[4:0], sram_page} = cpu_data_in[7:0]; // direct r1 access, current SRAM page 0-3
					if (cpu_addr_in[2:0] == 3'b110) // $5xx6
						{flags[2:0], mapper[4:0]} = cpu_data_in[7:0];	// some flags, mapper
					if (cpu_addr_in[2:0] == 3'b111) // $5xx7
						// some other parameters
						{lockout, mirroring[1:0], prg_write_enabled, chr_write_enabled, sram_enabled} = {cpu_data_in[7], cpu_data_in[4:0]};
				end
			end else begin // $8000-$FFFF
				// Mapper #2 - UxROM
				if (mapper == 5'b00001)
				begin
					if (!USE_FIRE_HAWK || !flags[0])
					begin
						r1 = cpu_data_in;
					end else begin // CodeMasters, blah. Mirroring control only used by Fire Hawk
						if (cpu_addr_in[14:12] == 3'b001)
							mirroring[1:0] = {1'b1, cpu_data_in[4]};
						else
							r1 = cpu_data_in[3:0];
					end
				end
				// Mapper #3 - CNROM
				if (mapper == 5'b00010)
				begin
					r0 = cpu_data_in;
				end
				// Mapper #78 - Holy Diver 
				if (USE_MAPPER_78 && mapper == 5'b00011)
				begin
					r0 = cpu_data_in[7:4];
					r1 = cpu_data_in[2:0];
					mirroring = {1'b0, ~cpu_data_in[3]};
				end
				// Mapper #7 - AxROM
				if (mapper == 5'b01000)
				begin
					r1[4:0] = cpu_data_in[4:0];
					mirroring = {1'b1, cpu_data_in[4]};
				end	
				// Mapper #228 - Cheetahmen II
				if (USE_CHEETAHMEN2 && mapper == 5'b01001)
				begin
					r0[5:0] = {cpu_addr_in[3:0], cpu_data_in[1:0]};	// CHR bank
					r1[4:0] = {1'b0, cpu_addr_in[10:7]};				// PRG bank
					mirroring = {1'b0, cpu_addr_in[13]};				// mirroring
				end
				// Mapper #11 - ColorDreams
				if (USE_COLOR_DREAMS && mapper == 5'b01010)
				begin
					r1[4:0] = cpu_data_in[1:0];
					r0[4:0] = cpu_data_in[7:4];					
				end	
				// Mapper #66 - GxROM
				if (USE_GxROM && mapper == 5'b01011)
				begin
					r0[4:0] = cpu_data_in[1:0];
					r1[4:0] = cpu_data_in[5:4];					
				end	

				// Mapper #1 - MMC1
				if (mapper[4:2] == 3'b100)
				begin
					if (cpu_data_in[7] == 1) // reset
					begin
						r0[5:0] = 6'b100000;
						r1[3:2] = 2'b11;
					end else begin				
						r0[5:0] = {cpu_data_in[0], r0[5:1]};
						if (r0[0] == 1)
						begin
							case (cpu_addr_in[14:13])
								2'b00: {r1[4:2], mirroring} = r0[5:1] ^ 2'b10; // $8000- $9FFF
								2'b01: r2[4:0] = r0[5:1]; // $A000- $BFFF
								2'b10: r3[4:0] = r0[5:1]; // $C000- $DFFF
								2'b11: r4[4:0] = r0[5:1]; // $E000- $FFFF
							endcase
							r0[5:0] = 6'b100000;
						end
					end					
				end

				// Mapper #4 - MMC3/MMC6
				if (mapper == 5'b10100)
				begin
					case ({cpu_addr_in[14:13], cpu_addr_in[0]})
						3'b000: {r8[4], r8[3], r8[2:0]} = {cpu_data_in[7], cpu_data_in[6], cpu_data_in[2:0]};// $8000-$9FFE, even
						3'b001: begin // $8001-$9FFF, odd
							case (r8[2:0])
								3'b000: r0 = cpu_data_in;
								3'b001: r1 = cpu_data_in;
								3'b010: r2 = cpu_data_in;
								3'b011: r3 = cpu_data_in;
								3'b100: r4 = cpu_data_in;
								3'b101: r5 = cpu_data_in;
								3'b110: r6 = cpu_data_in;
								3'b111: r7 = cpu_data_in;
							endcase
						end
						3'b010: mirroring = cpu_data_in[0]; //r8[5] = cpu_data_in[0]; // $A000-$BFFE, even
						3'b011: r8[7:6] = cpu_data_in[7:6]; // $A001-$BFFF, odd
						3'b100: r9 = cpu_data_in; // $C000-$DFFE, even (IRQ latch)
						3'b101: irq_scanline_reload = 1; // $C001-$DFFF, odd
						3'b110: irq_scanline_enabled = 0; // $E000-$FFFE, even
						3'b111: irq_scanline_enabled = 1; // $E001-$FFFF, odd
					endcase					
				end

				// Mapper #33 + #48 - Taito
				if (USE_TAITO && (mapper[4:1] == 5'b1011))
				begin
					r8[3] = 0;
					r8[4] = 0;
					case ({cpu_addr_in[14:13], cpu_addr_in[1:0]})
						4'b0000: begin
							if (!mapper[0]) // #33
							begin
								r6 = {2'b00, cpu_data_in[5:0]}; // $8000, PRG Reg 0 (8k @ $8000)
								mirroring = cpu_data_in[6];
							end else begin // #48
								r6 = cpu_data_in; // $8000, PRG Reg 0 (8k @ $8000)
							end
						end
						4'b0001: r7 = cpu_data_in; // $8001, PRG Reg 1 (8k @ $A000)
						4'b0010: r0 = {cpu_data_in[6:0], 1'b0};  // $8002, CHR Reg 0 (2k @ $0000)
						4'b0011: r1 = {cpu_data_in[6:0], 1'b0};  // $8003, CHR Reg 1 (2k @ $0800)
						4'b0100: r2 = cpu_data_in;	// $A000, CHR Reg 2 (1k @ $1000)
						4'b0101: r3 = cpu_data_in; // $A001, CHR Reg 2 (1k @ $1400)
						4'b0110: r4 = cpu_data_in; // $A002, CHR Reg 2 (1k @ $1800)
						4'b0111: r5 = cpu_data_in; // $A003, CHR Reg 2 (1k @ $1C00)
						4'b1000: r9 = cpu_data_in; // $C000, IRQ latch
						4'b1001: irq_scanline_reload = 1; // $C001, IRQ reload
						4'b1010: irq_scanline_enabled = 1; // $C002, IRQ enable
						4'b1011: irq_scanline_enabled = 0; // $C003, IRQ disable & ack
						4'b1100: if (mapper[0]) mirroring = cpu_data_in[6];	// $E000, mirroring, for mapper #48
					endcase
				end
				
				// Mapper #23 - VRC2/4
				if (USE_VRC2 && mapper == 5'b11000)
				begin
					// flags[0] to shift lines
					case ({cpu_addr_in[14:12], flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low}) 
						5'b00000, // $8000
						5'b00001, // $8001
						5'b00010, // $8002
						5'b00011: r8[4:0] = cpu_data_in[4:0];  // $8003, PRG0
						5'b00100, // $9000
						5'b00101, // $9001
						5'b00110, // $9002
						5'b00111: mirroring = cpu_data_in[1:0];  // $A003, mirroring
						5'b01000, // $A000
						5'b01001, // $A001
						5'b01010, // $A002
						5'b01011: r9[4:0] = cpu_data_in[4:0];  // $A003, PRG1
						5'b01100: r0[3:0] = cpu_data_in[3:0];  // $B000, CHR0 low						
						5'b01101: r0[7:4] = cpu_data_in[3:0];  // $B001, CHR0 hi
						5'b01110: r1[3:0] = cpu_data_in[3:0];  // $B002, CHR1 low						
						5'b01111: r1[7:4] = cpu_data_in[3:0];  // $B003, CHR1 hi
						5'b10000: r2[3:0] = cpu_data_in[3:0];  // $C000, CHR2 low						
						5'b10001: r2[7:4] = cpu_data_in[3:0];  // $C001, CHR2 hi
						5'b10010: r3[3:0] = cpu_data_in[3:0];  // $C002, CHR3 low						
						5'b10011: r3[7:4] = cpu_data_in[3:0];  // $C003, CHR3 hi
						5'b10100: r4[3:0] = cpu_data_in[3:0];  // $D000, CHR4 low						
						5'b10101: r4[7:4] = cpu_data_in[3:0];  // $D001, CHR4 hi
						5'b10110: r5[3:0] = cpu_data_in[3:0];  // $D002, CHR5 low						
						5'b10111: r5[7:4] = cpu_data_in[3:0];  // $D003, CHR5 hi
						5'b11000: r6[3:0] = cpu_data_in[3:0];  // $E000, CHR6 low
						5'b11001: r6[7:4] = cpu_data_in[3:0];  // $E001, CHR6 hi
						5'b11010: r7[3:0] = cpu_data_in[3:0];  // $E002, CHR7 low
						5'b11011: r7[7:4] = cpu_data_in[3:0];  // $E003, CHR7 hi
					endcase					
					if (USE_VRC4_INTERRUPTS)
					begin
						case ({cpu_addr_in[14:12], flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low}) 
							5'b11100: r10[3:0] = cpu_data_in[3:0];  // IRQ latch low
							5'b11101: r10[7:4] = cpu_data_in[3:0];  // IRQ latch hi
							5'b11110: begin // IRQ control
								irq_cpu_out = 0; // ack
								r11[2:0] = cpu_data_in[2:0]; // mode, enabled, enabled after ack
								if (r11[1]) begin // if E is set
									r11[4:3] = 2'b00; // reset prescaler
									r13 = 0;
									r12 = r10;			// reload with latch
								end
							end
							5'b11111: begin // IRQ ack
								irq_cpu_out = 0;
								r11[1] = r11[0];							
							end
						endcase
					end
				end

				if (USE_SUNSOFT && mapper == 5'b11001)
				begin
					if (cpu_addr_in[14:13] == 2'b00) r14[3:0] = cpu_data_in[3:0];
					if (cpu_addr_in[14:13] == 2'b01)
					begin
						case (r14[3:0])
							4'b0000: r0 = cpu_data_in; // CHR0
							4'b0001: r1 = cpu_data_in; // CHR1
							4'b0010: r2 = cpu_data_in; // CHR2
							4'b0011: r3 = cpu_data_in; // CHR3
							4'b0100: r4 = cpu_data_in; // CHR4
							4'b0101: r5 = cpu_data_in; // CHR5
							4'b0110: r6 = cpu_data_in; // CHR6
							4'b0111: r7 = cpu_data_in; // CHR7
							4'b1000: {sram_enabled, map_rom_on_6000, r8[5:0]} = {cpu_data_in[7], ~cpu_data_in[6], cpu_data_in[5:0]}; // PRG0
							4'b1001: r9[5:0] = cpu_data_in[5:0]; // PRG1
							4'b1010: r10[5:0] = cpu_data_in[5:0]; // PRG2
							4'b1011: r11[5:0] = cpu_data_in[5:0]; // PRG3
							4'b1100: mirroring[1:0] = cpu_data_in[1:0]; // mirroring
							4'b1101: begin
								r10[7:6] = {cpu_data_in[7], cpu_data_in[0]}; // IRQ control
								irq_cpu_out = 0; // ack
							end
							4'b1110: r12 = cpu_data_in; // IRQ low
							4'b1111: r13 = cpu_data_in; // IRQ high
						endcase
					end						
				end
			end // romsel
		end // write
		
		// some IRQ stuff
		if (irq_scanline_reload_clear)
			irq_scanline_reload = 0;
		
		// IRQ for VRC4
		if (USE_VRC2 && USE_VRC4_INTERRUPTS && mapper == 5'b11000 && r11[1])
		begin
			if (r11[2]) // cycle mode
			begin
				r12 = r12 + 1; // just count IRQ value
				if (r12 == 0)
				begin
					irq_cpu_out = 1;
					r12 = r10;
				end
			end else begin // scanline mode
				r13 = r13 + 1; // count prescaller
				if ((r11[4] == 0 && r13 == 114) || (r11[4] == 1 && r13 == 113)) // 114, 114, 113
				begin
					r12 = r12 + 1;
					r13 = 0;
					r11[4:3] = r11[4:3]+1;
					if (r11[4:3] == 2'b11) r11[4:3] =  2'b00;
					if (r12 == 0)
					begin
						irq_cpu_out = 1;
						r12 = r10;
					end
				end
			end
		end
		
		// IRQ for Sunsoft FME-7
		if (USE_SUNSOFT && mapper == 5'b11001 && r10[7])
		begin
			if ({r13, r12} == 0 && r10[6]) irq_cpu_out = 1;
			{r13, r12} = {r13, r12} - 1;
		end
	end

	always @ (*)
	begin
		if (mapper[4] == 0) // simple mappers
		begin
			if (mapper[3] == 1'b0) // UxROM-like (1*0x4000 + 1*0x2000): UxROM, CodeMasters, 78, CNROM
			// r0[4:0] - 4k CHR bank
			// r1 - PRG bank
			begin
				cpu_addr_mapped = {(cpu_addr_in[14] ? 5'b11111 : r1[4:0]), cpu_addr_in[13]};
			end
			if (mapper[3] == 1'b1) // AxROM-like (1*0x8000 + 1*0x2000): NROM, AxROM, Cheetahmen, Color Dreams, GxROM, etc.
			// r0[4:0] - 8k CHR bank
			// r1 - PRG bank
			begin
				cpu_addr_mapped = {r1, cpu_addr_in[14:13]};
			end
			ppu_addr_mapped = {r0[4:0], ppu_addr_in[12:10]};
		end
		// Mapper #1 - MMC1
		if (mapper[4:2] == 3'b100)
		begin
			if (romsel == 0) // accessing $8000-$FFFF
			begin
				case (r1[3:2])			
					2'b00,
					2'b01: cpu_addr_mapped = {r4[3:1], cpu_addr_in[14:13]}; // 32KB bank mode
					2'b10: if (cpu_addr_in[14] == 0) // $8000-$BFFF
							cpu_addr_mapped = cpu_addr_in[13]; // fixed to the first bank
						else // $C000-$FFFF
							cpu_addr_mapped = {r4[3:0], cpu_addr_in[13]};  // 16KB bank selected
					2'b11: if (cpu_addr_in[14] == 0) // $8000-$BFFF
							cpu_addr_mapped = {r4[3:0], cpu_addr_in[13]};  // 16KB bank selected
						else // $C000-$FFFF
							cpu_addr_mapped = {4'b1111, cpu_addr_in[13]};	// fixed to the last bank
				endcase
			end
			case (r1[4])
				0: ppu_addr_mapped = {r2[4:1], ppu_addr_in[12:10]}; // 8KB bank mode
				1: if (ppu_addr_in[12] == 0) // 4KB bank mode
						ppu_addr_mapped = {r2[4:0], ppu_addr_in[11:10]}; // first bank
					else
						ppu_addr_mapped = {r3[4:0], ppu_addr_in[11:10]}; // second bank
			endcase		
		end		
		
		// MMC3 based mappers
		// Mapper #4 - MMC3/MMC6 (00100)
		// Mapper #33 - Taito    (10100)
		// Mapper #48 - Taito    (10101)
		if (mapper[4:2] == 3'b101)
		begin
			case ({cpu_addr_in[14:13], r8[3]})
				3'b000: cpu_addr_mapped = r6[5:0];
				3'b001: cpu_addr_mapped = 6'b111110;
				3'b010,
				3'b011: cpu_addr_mapped = r7[5:0];
				3'b100: cpu_addr_mapped = 6'b111110;
				3'b101: cpu_addr_mapped = r6[5:0];
				default: cpu_addr_mapped = 6'b111111;
			endcase
			if (ppu_addr_in[12] == r8[4])	
			begin
				case (ppu_addr_in[11])
					1'b0: ppu_addr_mapped = {r0[7:1], ppu_addr_in[10]};
					1'b1: ppu_addr_mapped = {r1[7:1], ppu_addr_in[10]};
				endcase				
			end else begin
				case (ppu_addr_in[11:10])
					2'b00: ppu_addr_mapped = r2;
					2'b01: ppu_addr_mapped = r3;
					2'b10: ppu_addr_mapped = r4;
					2'b11: ppu_addr_mapped = r5;
				endcase
			end
		end
	
		// PPU 8*0x400 mappers
		if ((USE_VRC2 || USE_SUNSOFT) && mapper[4:2] == 3'b110)
		begin
			// Mapper #23 - VRC2b
			if (USE_VRC2 && mapper[1:0] == 2'b00)
			begin
				cpu_addr_mapped = cpu_addr_in[14] ? {5'b11111, cpu_addr_in[13]} : {1'b0, !cpu_addr_in[13] ? r8[4:0] : r9[4:0]};
			end
			
			// Mapper #69
			if (USE_SUNSOFT && mapper[1:0] == 2'b01)
			begin
				case ({~romsel, cpu_addr_in[14:13]})
					3'b011: cpu_addr_mapped = r8[5:0]; // $6000 - $7FFF
					3'b100: cpu_addr_mapped = r9[5:0]; // $8000 - $9FFF
					3'b101: cpu_addr_mapped = r10[5:0]; // $A000 - $BFFF
					3'b110: cpu_addr_mapped = r11[5:0]; // $C000 - $DFFF
					3'b111: cpu_addr_mapped = 6'b111111; // $E000 - $FFFF
				endcase
			end
			
			if (!flags[1] || !USE_VRC2 || !USE_VRC2a) // on VRC2a the low bit is ignored
			begin
				case (ppu_addr_in[12:10])
					3'b000: ppu_addr_mapped = r0;
					3'b001: ppu_addr_mapped = r1;
					3'b010: ppu_addr_mapped = r2;
					3'b011: ppu_addr_mapped = r3;
					3'b100: ppu_addr_mapped = r4;
					3'b101: ppu_addr_mapped = r5;
					3'b110: ppu_addr_mapped = r6;
					3'b111: ppu_addr_mapped = r7;
				endcase
			end else begin
				case (ppu_addr_in[12:10])
					3'b000: ppu_addr_mapped = {1'b0, r0[7:1]};
					3'b001: ppu_addr_mapped = {1'b0, r1[7:1]};
					3'b010: ppu_addr_mapped = {1'b0, r2[7:1]};
					3'b011: ppu_addr_mapped = {1'b0, r3[7:1]};
					3'b100: ppu_addr_mapped = {1'b0, r4[7:1]};
					3'b101: ppu_addr_mapped = {1'b0, r5[7:1]};
					3'b110: ppu_addr_mapped = {1'b0, r6[7:1]};
					3'b111: ppu_addr_mapped = {1'b0, r7[7:1]};
				endcase
			end
		end
	end

	// reenable IRQ only when PPU A12 is low
	always @ (*)
	begin
		if (!irq_scanline_enabled)
		begin
			irq_scanline_ready = 0;
			irq_scanline_out = 0;
		end else if (irq_scanline_enabled && !irq_scanline_value)
			irq_scanline_ready = 1;
		else if (irq_scanline_ready && irq_scanline_value)
			irq_scanline_out = 1;
	end
	
	// IRQ counter
	always @ (posedge ppu_addr_in[12])
	begin
		if (a12_low_time == 3)
		begin
			//irq_scanline_counter_last = irq_scanline_counter;
			if ((irq_scanline_reload && !irq_scanline_reload_clear) || (irq_scanline_counter == 0))
			begin
				irq_scanline_counter = r9;
				if (irq_scanline_reload) irq_scanline_reload_clear = 1;
			end else
				irq_scanline_counter = irq_scanline_counter-1;
			if (irq_scanline_counter == 0 && irq_scanline_enabled)
				irq_scanline_value = 1;
			else
				irq_scanline_value = 0;
		end
		if (!irq_scanline_reload) irq_scanline_reload_clear = 0;		
	end
	
	// A12 must be low for 3 rises of M2
	always @ (posedge m2, posedge ppu_addr_in[12])
	begin
		if (ppu_addr_in[12])
			a12_low_time = 0;
		else if (a12_low_time < 3)
			a12_low_time = a12_low_time + 1;
	end
	
endmodule
