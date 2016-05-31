	reg [26:14] cpu_base = 0;
	reg [20:14] prg_mask = 7'b1111000;
	reg [17:13] chr_mask = 0;
	reg [2:0] prg_mode = 0;
	reg map_rom_on_6000 = 0;
	reg [7:0] prg_bank_6000 = 0;
	reg [7:0] prg_bank_a = 0;
	reg [7:0] prg_bank_b = 6'b111101;
	reg [7:0] prg_bank_c = 6'b111110;
	reg [7:0] prg_bank_d = 6'b111111;
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
	reg [7:0] r1 = 0;
	reg [7:0] r2 = 0;
	reg [7:0] r3 = 0;
	reg [7:0] r4 = 0;
	reg [7:0] r5 = 0;
	
	reg [7:0] mul1;
	reg [7:0] mul2;
	wire [15:0] mul = mul1*mul2;
	
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
	reg [7:0] scanline = 0;
	reg [9:0] ppu_rd_hi_time = 0;
	reg new_screen = 0;
	reg new_screen_clear = 0;
	
	// for CPU interrupts
	reg [15:0] irq_cpu_value = 0;
	reg irq_cpu_out = 0;
	reg [3:0] irq_cpu_control = 0;
	reg [15:0] irq_cpu_latch = 0;
	reg [6:0] vrc4_irq_prescaler = 0;
	reg [1:0] vrc4_irq_prescaler_counter = 0;

	// for MMC2/MMC4
	reg ppu_latch0 = 0;
	reg ppu_latch1 = 0;
	reg ppu_mapper_163_latch = 0;
	
	reg writed;

	wire cpu_data_out_enabled;
	wire [7:0] cpu_data_out;
	assign {cpu_data_out_enabled, cpu_data_out} = 
		(m2 & romsel & cpu_rw_in) ?
		(
			((mapper == 0) && (cpu_addr_in[14:12] == 3'b101)) ? {8'b10000000, new_dendy} :
			(USE_MAPPER_163 && (mapper == 5'b00110) && ({cpu_addr_in[14:12],cpu_addr_in[10:8]} == 6'b101001)) ? 
					{1'b1, r2 | r0 | r1 | ~r3} :
			(USE_MAPPER_163 && (mapper == 5'b00110) && ({cpu_addr_in[14:12],cpu_addr_in[10:8]} == 6'b101101)) ? 
					{1'b1, r5[0] ? r2 : r1} :
			//(USE_MAPPER_090_MUL && (mapper == 5'b01101) && (cpu_addr_in[14:0] == 15'h5800)) ? {1'b1, mul[7:0]} :
			//(USE_MAPPER_090_MUL && (mapper == 5'b01101) && (cpu_addr_in[14:0] == 15'h5801)) ? {1'b1, mul[15:8]} :
			9'b000000000
		): 9'b000000000;
		
	assign ppu_ciram_a10 = (USE_MAPPER_118 & (mapper == 5'b10100) & flags[0]) ? ppu_addr_mapped[17] :
		(mirroring[1] ? mirroring[0] : (mirroring[0] ? ppu_addr_in[11] : ppu_addr_in[10])); // vertical / horizontal, 1Sa, 1Sb			

	wire [20:13] cpu_addr_mapped = (map_rom_on_6000 & romsel & m2) ? prg_bank_6000 :
	(
		prg_mode[2] ? (
			prg_mode[1] ? (				
				prg_mode[0] ? (
					// 111 - 0x8000(A)
					{prg_bank_a[7:2], cpu_addr_in[14:13]}
				) : (
					// 110 - 0x8000(B)
					{prg_bank_b[7:2], cpu_addr_in[14:13]}
				)
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
				{cpu_addr_in[14] ? prg_bank_a[7:1] : prg_bank_c[7:1], cpu_addr_in[13]}
			) : ( // prg_mode[0]
				// 0x0 - 0x4000(A) + 0x4000 (С)
				{cpu_addr_in[14] ? prg_bank_c[7:1] : prg_bank_a[7:1], cpu_addr_in[13]}
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
				(((USE_MAPPER_009_010) && chr_mode[0] && ppu_latch1) ? chr_bank_f[7:2] : chr_bank_e[7:2]) : 
				(((USE_MAPPER_009_010) && chr_mode[0] && ppu_latch0) ? chr_bank_b[7:2] : chr_bank_a[7:2]),
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
			(USE_MAPPER_163 && chr_mode[0]) ? (
				// 001 - Mapper #163 special
				{ppu_mapper_163_latch, ppu_addr_in[11:10]}
			) : (
				// 000 - 0x2000(A)
				{chr_bank_a[7:3], ppu_addr_in[12:10]}
			)
		)
	);
	
	assign irq = (irq_scanline_out | irq_cpu_out) ? 1'b0 : 1'bZ;

	/*
	reg romsel_alt = 1;
	reg romsel_alt_clean = 0;
	
	always @ (*)
	begin
		if (~romsel)
			romsel_alt = 0;
		else if (romsel_alt_clean)
			romsel_alt = 1;
	end
	*/
	
	// for VRC
	wire vrc_2b_hi = cpu_addr_in[1] | cpu_addr_in[3] | cpu_addr_in[5] | cpu_addr_in[7];
	wire vrc_2b_low = cpu_addr_in[0] | cpu_addr_in[2] | cpu_addr_in[4] | cpu_addr_in[6];
	
	always @ (negedge m2)
	begin
		if (cpu_rw_in == 1) // read
		begin
			writed = 0;
		// block two writes in a row (RMW) for games like Snow Bros. and Bill & Ted's Excellent Adventure
		// also you can remove this check and just patch those games, lol
		end else if (cpu_rw_in == 0 && !writed) // write
		begin
			writed = 1;
			if (romsel /*& romsel_alt*/) // $0000-$7FFF
			begin
				if ((cpu_addr_in[14:12] == 3'b101) && (lockout == 0)) // $5000-5FFF & lockout is off
				begin
					case (cpu_addr_in[2:0])
						3'b000: // $5xx0
							{cpu_base[26:22]} = cpu_data_in[4:0];						// CPU base address A26-A22
						3'b001: // $5xx1
							cpu_base[21:14] = cpu_data_in[7:0]; 						// CPU base address A21-A14
						3'b010: // $5xx2
							prg_mask[20:14] = cpu_data_in[6:0]; 						// CPU mask A18-A14
						3'b011: // $5xx3
							{prg_mode[2:0], chr_bank_a[7:3]} = cpu_data_in[7:0];	// PRG mode, direct chr_bank_a access
						3'b100: // $5xx4
							{chr_mode[2:0], chr_mask[17:13]} = cpu_data_in[7:0];	// CHR mode, CHR mask A17-A13
						3'b101: // $5xx5
							{prg_bank_a[5:1], sram_page[1:0]} = cpu_data_in[6:0]; // direct prg_bank_a access, current SRAM page 0-3
						3'b110: // $5xx6
							{flags[2:0], mapper[4:0]} = cpu_data_in[7:0];			// some flags, mapper
						3'b111: // $5xx7														
							// some other parameters						
							{lockout, mirroring[1:0], prg_write_enabled, chr_write_enabled, sram_enabled} = {cpu_data_in[7], cpu_data_in[4:0]};
					endcase
				end
				
				// Mapper #163				
				if (USE_MAPPER_163 && mapper == 5'b00110)
				begin
					if (cpu_addr_in[14:0] == 15'h5101)
					begin
						if ((r4 != 0) && (cpu_data_in == 0))
							r5[0] = ~r5[0];
						r4 = cpu_data_in;					
					end else if ((cpu_addr_in[14:0] == 15'h5100) && (cpu_data_in == 6))
					begin
						prg_mode[0] = 0;
						prg_bank_b = 4'b1100;
					end else if (cpu_addr_in[14:12] == 3'b101) begin
						case (cpu_addr_in[9:8])
							2'b10: begin
									prg_mode[0] = 1;
									prg_bank_a[7:6] = cpu_data_in[1:0];
									r0 = cpu_data_in;
								end
							2'b00: begin
									prg_mode[0] = 1;
									prg_bank_a[5:2] = cpu_data_in[3:0];
									chr_mode[0] = cpu_data_in[7];
									r1 = cpu_data_in;
								end
							2'b11: r2 = cpu_data_in;
							2'b01: r3 = cpu_data_in;
						endcase
					end					
				end
				
				// Mapper #87
				if (USE_MAPPER_087 && mapper == 5'b01100)
				begin
					if (cpu_addr_in[14] & cpu_addr_in[13]) // $6000-$7FFF
					begin
						chr_bank_a[4:3] = {cpu_data_in[0], cpu_data_in[1]};
					end
				end
				
				// Mapper #90 - JY
				/*
				if (USE_MAPPER_090_MUL && mapper == 5'b01101)
				begin
					if (cpu_addr_in[14:0] == 15'h5800)
						mul1 = cpu_data_in;
					if (cpu_addr_in[14:0] == 15'h5801)
						mul2 = cpu_data_in;
				end
				*/
				
				// Mapper #189
				// It's MMC3 with flag1
				if (USE_MAPPER_189 & flags[1] & (mapper == 5'b10100))
				begin
					if (cpu_addr_in[14:0] >= 15'h4120) // $4120-$7FFF
					begin
						prg_bank_a[5:2] = cpu_data_in[3:0] | cpu_data_in[7:4];
					end
				end				
				
				
				// temp/test
				/*
				if (mapper == 5'b11111)
				begin
					if (cpu_addr_in[14:0] == 15'h4025)
					begin
						mirroring = {1'b0, cpu_data_in[3]};
					end
				end
				*/
			end else begin // $8000-$FFFF
				// temp/test
				/*
				if (mapper == 5'b11111)
				begin
					prg_bank_6000 = cpu_data_in[4:1] + 4;
					map_rom_on_6000 = 1;
				end
				*/
				
				// Mapper #2 - UxROM
				// flag0 - mapper #71 - for Fire Hawk only.
				// other mapper-#71 games are UxROM
				if (mapper == 5'b00001)
				begin
					if (!USE_MAPPER_071 | ~flags[0] | (cpu_addr_in[14:12] != 3'b001))
					begin
						prg_bank_a[5:1] = cpu_data_in[4:0];
					end else begin // CodeMasters, blah. Mirroring control used only by Fire Hawk
						mirroring[1:0] = {1'b1, cpu_data_in[4]};
					end
				end
				
				// Mapper #3 - CNROM
				if (mapper == 5'b00010)
				begin
					chr_bank_a[7:3] = cpu_data_in[4:0];
				end
				
				// Mapper #78 - Holy Diver 
				if (USE_MAPPER_078 && mapper == 5'b00011)
				begin
					prg_bank_a[3:1] = cpu_data_in[2:0];
					chr_bank_a[6:3] = cpu_data_in[7:4];
					mirroring = {1'b0, ~cpu_data_in[3]};
				end

				// Mapper #97 - Irem's TAM-S1
				if (USE_MAPPER_097 && mapper == 5'b00100)
				begin
					prg_bank_a[4:1] = cpu_data_in[3:0];
					mirroring = cpu_data_in[7:6] ^ {~cpu_data_in[6], 1'b0};
				end
				
				// Mapper #93 - Sunsoft-2
				if (USE_MAPPER_093 && mapper == 5'b00101)
				begin
					prg_bank_a[3:1] = {cpu_data_in[6:4]};
					chr_write_enabled = cpu_data_in[0];
				end
				
				// Mapper #18 - Sunsoft-2
				if (USE_MAPPER_018 && mapper == 5'b00111)
				begin
					case ({cpu_addr_in[14:12], cpu_addr_in[1:0]})
						5'b00000: prg_bank_a[3:0] = cpu_data_in[3:0]; // $8000
						5'b00001: prg_bank_a[7:4] = cpu_data_in[3:0]; // $8001
						5'b00010: prg_bank_b[3:0] = cpu_data_in[3:0]; // $8002
						5'b00011: prg_bank_b[7:4] = cpu_data_in[3:0]; // $8003
						5'b00100: prg_bank_c[3:0] = cpu_data_in[3:0]; // $9000
						5'b00101: prg_bank_c[7:4] = cpu_data_in[3:0]; // $9001
						5'b00110: ; // $9002
						5'b00111: ; // $9003
						5'b01000: chr_bank_a[3:0] = cpu_data_in[3:0]; // $A000
						5'b01001: chr_bank_a[7:4] = cpu_data_in[3:0]; // $A001
						5'b01010: chr_bank_b[3:0] = cpu_data_in[3:0]; // $A002
						5'b01011: chr_bank_b[7:4] = cpu_data_in[3:0]; // $A003
						5'b01100: chr_bank_c[3:0] = cpu_data_in[3:0]; // $B000
						5'b01101: chr_bank_c[7:4] = cpu_data_in[3:0]; // $B001
						5'b01110: chr_bank_d[3:0] = cpu_data_in[3:0]; // $B002
						5'b01111: chr_bank_d[7:4] = cpu_data_in[3:0]; // $B003
						5'b10000: chr_bank_e[3:0] = cpu_data_in[3:0]; // $C000
						5'b10001: chr_bank_e[7:4] = cpu_data_in[3:0]; // $C001
						5'b10010: chr_bank_f[3:0] = cpu_data_in[3:0]; // $C002
						5'b10011: chr_bank_f[7:4] = cpu_data_in[3:0]; // $C003
						5'b10100: chr_bank_g[3:0] = cpu_data_in[3:0]; // $D000
						5'b10101: chr_bank_g[7:4] = cpu_data_in[3:0]; // $D001
						5'b10110: chr_bank_h[3:0] = cpu_data_in[3:0]; // $D002
						5'b10111: chr_bank_h[7:4] = cpu_data_in[3:0]; // $D003
						5'b11000: irq_cpu_latch[3:0] = cpu_data_in[3:0]; // $E000
						5'b11001: irq_cpu_latch[7:4] = cpu_data_in[3:0]; // $E001
						5'b11010: irq_cpu_latch[11:8] = cpu_data_in[3:0]; // $E002
						5'b11011: irq_cpu_latch[15:12] = cpu_data_in[3:0]; // $E003
						5'b11100: begin // $F000
								irq_cpu_value[15:0] = irq_cpu_latch[15:0];
								irq_cpu_out = 0;
							end
						5'b11101: begin // $F001
								irq_cpu_control[3:0] = cpu_data_in[3:0];
								irq_cpu_out = 0;
							end
						5'b11110: mirroring = cpu_data_in[1:0] ^ {1'b0, ~cpu_data_in[1]}; // $F002
						5'b11111: ; // $F003 - sound
					endcase
				end

				// Mapper #7 - AxROM
				if (mapper == 5'b01000)
				begin
					prg_bank_a[5:2] = cpu_data_in[3:0];
					mirroring = {1'b1, cpu_data_in[4]};
				end
				
				// Mapper #228 - Cheetahmen II				
				if (USE_MAPPER_228 && mapper == 5'b01001)
				begin
					prg_bank_a[5:2] = cpu_addr_in[10:7];
					chr_bank_a[7:3] = {/*cpu_addr_in[3]*/cpu_addr_in[2:0], cpu_data_in[1:0]}; // only 256k, sorry
					mirroring = {1'b0, cpu_addr_in[13]};
				end
				
				// Mapper #11 - ColorDreams
				if (USE_MAPPER_011 && mapper == 5'b01010)
				begin
					prg_bank_a[3:2] = cpu_data_in[1:0];
					chr_bank_a[6:3] = cpu_data_in[7:4];
				end
				
				// Mapper #66 - GxROM
				if (USE_MAPPER_066 && mapper == 5'b01011)
				begin
					prg_bank_a[3:2] = cpu_data_in[5:4];
					chr_bank_a[4:3] = cpu_data_in[1:0];					
				end
				
				// Mapper #90 - JY
				if (USE_MAPPER_090 && mapper == 5'b01101)
				begin
					if (cpu_addr_in[14:12] == 3'b000) // $800x
					begin
						case (cpu_addr_in[1:0])
							2'b00: prg_bank_a = cpu_data_in;
							2'b01: prg_bank_b = cpu_data_in;
							2'b10: prg_bank_c = cpu_data_in;
							2'b11: prg_bank_d = cpu_data_in;
						endcase
					end
					if (cpu_addr_in[14:12] == 3'b001) // $900x
					begin
						case (cpu_addr_in[2:0])
							3'b000: chr_bank_a = cpu_data_in;
							3'b001: chr_bank_b = cpu_data_in;
							3'b010: chr_bank_c = cpu_data_in;
							3'b011: chr_bank_d = cpu_data_in;
							3'b100: chr_bank_e = cpu_data_in;
							3'b101: chr_bank_f = cpu_data_in;
							3'b110: chr_bank_g = cpu_data_in;
							3'b111: chr_bank_h = cpu_data_in;
						endcase
					end
					if ({cpu_addr_in[14:12], cpu_addr_in[1:0]} == 5'b10101) // $D001
						mirroring = cpu_data_in[1:0];
					/*
					if (USE_MAPPER_090_INTERRUPTS && cpu_addr_in[14:12] == 3'b100) // $C00x
					begin
						case (cpu_addr_in[2:0])
							3'b000: irq_scanline_enabled = cpu_data_in[0];
							3'b001: ;
							3'b010: irq_scanline_enabled = 0;
							3'b011: irq_scanline_enabled = 1;
							3'b100: ;
							3'b101: begin
									irq_scanline_latch = cpu_data_in ^ r0;
									irq_scanline_reload = 1;
								end
							3'b110: r0 = cpu_data_in;
							3'b111: ;								
						endcase
					end
					*/
				end
				
				// Mapper #1 - MMC1
				/*
				r0 - load register
				flag0 - 16KB of WRAM (SOROM)
				*/
				if (mapper[4:0] == 5'b10000)
				begin
					if (cpu_data_in[7] == 1) // reset
					begin
						r0[5:0] = 6'b100000;
						prg_mode = 3'b000;	// 0x4000 (A) + fixed last (C)
						prg_bank_c[4:0] = 5'b11110;
					end else begin				
						r0[5:0] = {cpu_data_in[0], r0[5:1]};
						if (r0[0] == 1)
						begin
							case (cpu_addr_in[14:13])
								2'b00: begin // $8000-$9FFF
									if (r0[4:3] == 2'b11)
									begin
										prg_mode = 3'b000;	// 0x4000 (A) + fixed last (C)
										prg_bank_c[4:0] = 5'b11110;
									end else if (r0[4:3] == 2'b10)
									begin
										prg_mode = 3'b001;	// fixed first (C) + 0x4000 (A)
										prg_bank_c[4:0] = 5'b00000;
									end else							
										prg_mode = 3'b111;	// 0x8000 (A)
									if (r0[5])
										chr_mode = 3'b100;
									else
										chr_mode = 3'b000;
									mirroring[1:0] = r0[2:1] ^ 2'b10;
								end
								2'b01: begin // $A000-$BFFF
									chr_bank_a[6:2] = r0[5:1];
									prg_bank_a[5] = r0[5]; // for SUROM, 512k PRG support
									prg_bank_c[5] = r0[5]; // for SUROM, 512k PRG support
								end
								2'b10: chr_bank_e[6:2] = r0[5:1]; // $C000-$DFFF
								2'b11: begin
									prg_bank_a[4:1] = r0[4:1]; // $E000-$FFFF
									sram_enabled = ~r0[5];
								end
							endcase
							r0[5:0] = 6'b100000;
							if (flags[0]) // 16KB of WRAM
							begin
								if (chr_mode[2])
									sram_page = {1'b1, ~chr_bank_a[6]}; // page #2 is battery backed
								else
									sram_page = {1'b1, ~chr_bank_a[5]}; // wtf? ripped off from fce ultra source code and it works
							end
							// 32KB of WRAM is not supported yet (who cares)
						end
					end
				end
				
				// Mapper #9 and #10 - MMC2 and MMC4
				// flag0 - 0=MMC2, 1=MMC4
				if ((USE_MAPPER_009_010 | USE_MAPPER_009_010) && mapper[4:0] == 5'b10001)
				begin
					case (cpu_addr_in[14:12])
						3'b010: if (~flags[0]) // $A000-$AFFF
										prg_bank_a[3:0] = cpu_data_in[3:0];
									else
										prg_bank_a[4:1] = cpu_data_in[3:0];
						3'b011: chr_bank_a[6:2] = cpu_data_in[4:0]; // $B000-$BFFF
						3'b100: chr_bank_b[6:2] = cpu_data_in[4:0]; // $C000-$CFFF
						3'b101: chr_bank_e[6:2] = cpu_data_in[4:0]; // $D000-$DFFF
						3'b110: chr_bank_f[6:2] = cpu_data_in[4:0]; // $E000-$EFFF
						3'b111: mirroring = {1'b0, cpu_data_in[0]}; // $F000-$FFFF
					endcase
				end
				
				// Mapper #4 - MMC3/MMC6
				/*
				r8[2:0] - bank_select
				flag0 - TxSROM
				flag1 - mapper #189
				*/				
				if (mapper == 5'b10100)
				begin
					case ({cpu_addr_in[14:13], cpu_addr_in[0]})
						3'b000: begin // $8000-$9FFE, even
							r0[2:0] = cpu_data_in[2:0];
							if (!USE_MAPPER_189 | ~flags[1])
							begin
								if (cpu_data_in[6])
									prg_mode = 3'b101;
								else
									prg_mode = 3'b100;
							end
							if (cpu_data_in[7])
								chr_mode = 3'b011;
							else
								chr_mode = 3'b010;
						end
						3'b001: begin // $8001-$9FFF, odd
							case (r0[2:0])
								3'b000: chr_bank_a = cpu_data_in;
								3'b001: chr_bank_c = cpu_data_in;
								3'b010: chr_bank_e = cpu_data_in;
								3'b011: chr_bank_f = cpu_data_in;
								3'b100: chr_bank_g = cpu_data_in;
								3'b101: chr_bank_h = cpu_data_in;
								3'b110: if (!USE_MAPPER_189 | ~flags[1]) prg_bank_a[5:0] = cpu_data_in[5:0];
								3'b111: if (!USE_MAPPER_189 | ~flags[1]) prg_bank_b[5:0] = cpu_data_in[5:0];
							endcase
						end
						3'b010: mirroring = cpu_data_in[1:0]; // $A000-$BFFE, even (mirroring)
						3'b100: irq_scanline_latch = cpu_data_in; // $C000-$DFFE, even (IRQ latch)
						3'b101: irq_scanline_reload = 1; // $C001-$DFFF, odd
						3'b110: irq_scanline_enabled = 0; // $E000-$FFFE, even
						3'b111: irq_scanline_enabled = 1; // $E001-$FFFF, odd						
					endcase
				end

				// Mappers #33 + #48 - Taito
				// flag0=0 - #33, flag0=1 - #48
				if (USE_MAPPER_033_048 && (mapper[4:0] == 5'b10110))
				begin
					case ({cpu_addr_in[14:13], cpu_addr_in[1:0]})
						4'b0000: begin
							prg_bank_a[5:0] = cpu_data_in[5:0]; // $8000, PRG Reg 0 (8k @ $8000)
							if (~flags[0]) // #33
								mirroring = cpu_data_in[6];
						end
						4'b0001: prg_bank_b[5:0] = cpu_data_in[5:0]; // $8001, PRG Reg 1 (8k @ $A000)
						4'b0010: chr_bank_a = {cpu_data_in[6:0], 1'b0};  // $8002, CHR Reg 0 (2k @ $0000)
						4'b0011: chr_bank_c = {cpu_data_in[6:0], 1'b0};  // $8003, CHR Reg 1 (2k @ $0800)
						4'b0100: chr_bank_e = cpu_data_in;	// $A000, CHR Reg 2 (1k @ $1000)
						4'b0101: chr_bank_f = cpu_data_in; // $A001, CHR Reg 2 (1k @ $1400)
						4'b0110: chr_bank_g = cpu_data_in; // $A002, CHR Reg 2 (1k @ $1800)
						4'b0111: chr_bank_h = cpu_data_in; // $A003, CHR Reg 2 (1k @ $1C00)
						4'b1100: if (flags[0]) mirroring = {1'b0, cpu_data_in[6]};	// $E000, mirroring, for mapper #48
					endcase
					if (USE_MAPPER_048_INTERRUPTS)
					begin
						case ({cpu_addr_in[14:13], cpu_addr_in[1:0]})
							4'b1000: irq_scanline_latch = ~cpu_data_in; // $C000, IRQ latch
							4'b1001: irq_scanline_reload = 1; // $C001, IRQ reload
							4'b1010: irq_scanline_enabled = 1; // $C002, IRQ enable
							4'b1011: irq_scanline_enabled = 0; // $C003, IRQ disable & ack
						endcase
					end
				end
				
				// Mapper #23 - VRC2/4
				/*
				flag0 - switches A0 and A1 lines. 0=A0,A1 like VRC2b (mapper #23), 1=A1,A0 like VRC2a(#22), VRC2c(#25)
				flag1 - divides CHR bank select by two (mapper #22, VRC2a)
				*/
				if (USE_MAPPER_021_022_023_025 && mapper == 5'b11000)
				begin
					case ({cpu_addr_in[14:12], flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low})
						5'b00000,
						5'b00001,
						5'b00010,
						5'b00011: prg_bank_a[4:0] = cpu_data_in[4:0];  // $8000-$8003, PRG0
						5'b00100,
						5'b00101: if (cpu_data_in != 8'b11111111) mirroring = cpu_data_in[1:0]; // $9000-$9001, mirroring
						5'b00110,
						5'b00111: prg_mode[0] = cpu_data_in[1]; // $9002-$9004, PRG swap
						5'b01000,
						5'b01001,
						5'b01010,
						5'b01011: prg_bank_b[4:0] = cpu_data_in[4:0];  // $A000-$A003, PRG1
					endcase
					// flags[0] to shift lines
					if (!USE_MAPPER_022 | ~flags[1])
					begin
						case ({cpu_addr_in[14:12], flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low})
							5'b01100: chr_bank_a[3:0] = cpu_data_in[3:0];  // $B000, CHR0 low
							5'b01101: chr_bank_a[7:4] = cpu_data_in[3:0];  // $B001, CHR0 hi
							5'b01110: chr_bank_b[3:0] = cpu_data_in[3:0];  // $B002, CHR1 low
							5'b01111: chr_bank_b[7:4] = cpu_data_in[3:0];  // $B003, CHR1 hi
							5'b10000: chr_bank_c[3:0] = cpu_data_in[3:0];  // $C000, CHR2 low
							5'b10001: chr_bank_c[7:4] = cpu_data_in[3:0];  // $C001, CHR2 hi
							5'b10010: chr_bank_d[3:0] = cpu_data_in[3:0];  // $C002, CHR3 low
							5'b10011: chr_bank_d[7:4] = cpu_data_in[3:0];  // $C003, CHR3 hi
							5'b10100: chr_bank_e[3:0] = cpu_data_in[3:0];  // $D000, CHR4 low
							5'b10101: chr_bank_e[7:4] = cpu_data_in[3:0];  // $D001, CHR4 hi
							5'b10110: chr_bank_f[3:0] = cpu_data_in[3:0];  // $D002, CHR5 low
							5'b10111: chr_bank_f[7:4] = cpu_data_in[3:0];  // $D003, CHR5 hi
							5'b11000: chr_bank_g[3:0] = cpu_data_in[3:0];  // $E000, CHR6 low
							5'b11001: chr_bank_g[7:4] = cpu_data_in[3:0];  // $E001, CHR6 hi
							5'b11010: chr_bank_h[3:0] = cpu_data_in[3:0];  // $E002, CHR7 low
							5'b11011: chr_bank_h[7:4] = cpu_data_in[3:0];  // $E003, CHR7 hi
						endcase
					end else begin
						case ({cpu_addr_in[14:12], flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low})
							// VRC2a
							5'b01100: chr_bank_a[2:0] = cpu_data_in[3:1];  // $B000, CHR0 low
							5'b01101: chr_bank_a[7:3] = {1'b0, cpu_data_in[3:0]};  // $B001, CHR0 hi
							5'b01110: chr_bank_b[2:0] = cpu_data_in[3:1];  // $B002, CHR1 low
							5'b01111: chr_bank_b[7:3] = {1'b0, cpu_data_in[3:0]};  // $B003, CHR1 hi
							5'b10000: chr_bank_c[2:0] = cpu_data_in[3:1];  // $C000, CHR2 low
							5'b10001: chr_bank_c[7:3] = {1'b0, cpu_data_in[3:0]};  // $C001, CHR2 hi
							5'b10010: chr_bank_d[2:0] = cpu_data_in[3:1];  // $C002, CHR3 low
							5'b10011: chr_bank_d[7:3] = {1'b0, cpu_data_in[3:0]};  // $C003, CHR3 hi
							5'b10100: chr_bank_e[2:0] = cpu_data_in[3:1];  // $D000, CHR4 low
							5'b10101: chr_bank_e[7:3] = {1'b0, cpu_data_in[3:0]};  // $D001, CHR4 hi
							5'b10110: chr_bank_f[2:0] = cpu_data_in[3:1];  // $D002, CHR5 low
							5'b10111: chr_bank_f[7:3] = {1'b0, cpu_data_in[3:0]};  // $D003, CHR5 hi
							5'b11000: chr_bank_g[2:0] = cpu_data_in[3:1];  // $E000, CHR6 low
							5'b11001: chr_bank_g[7:3] = {1'b0, cpu_data_in[3:0]};  // $E001, CHR6 hi
							5'b11010: chr_bank_h[2:0] = cpu_data_in[3:1];  // $E002, CHR7 low
							5'b11011: chr_bank_h[7:3] = {1'b0, cpu_data_in[3:0]};  // $E003, CHR7 hi
						endcase
					end
						
					if (USE_VRC4_INTERRUPTS)
					begin
						if (cpu_addr_in[14:12] == 3'b111)
						begin
							case ({flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low}) 
								2'b00: irq_cpu_latch[3:0] = cpu_data_in[3:0];  // IRQ latch low
								2'b01: irq_cpu_latch[7:4] = cpu_data_in[3:0];  // IRQ latch hi
								2'b10: begin // IRQ control
									irq_cpu_out = 0; // ack
									irq_cpu_control[2:0] = cpu_data_in[2:0]; // mode, enabled, enabled after ack
									if (irq_cpu_control[1]) begin // if E is set
										vrc4_irq_prescaler_counter = 2'b00; // reset prescaler
										vrc4_irq_prescaler = 0;
										irq_cpu_value[7:0] = irq_cpu_latch[7:0]; // reload with latch
									end
								end
								2'b11: begin // IRQ ack
									irq_cpu_out = 0;
									irq_cpu_control[1] = irq_cpu_control[0];							
								end
							endcase
						end
					end
				end

				// Mapper #69 - Sunsoft FME-7
				/*
				r0 - command register
				*/				
				if (USE_MAPPER_069 && mapper == 5'b11001)
				begin
					if (cpu_addr_in[14:13] == 2'b00) r0[3:0] = cpu_data_in[3:0];
					if (cpu_addr_in[14:13] == 2'b01)
					begin
						case (r0[3:0])
							4'b0000: chr_bank_a = cpu_data_in; // CHR0
							4'b0001: chr_bank_b = cpu_data_in; // CHR1
							4'b0010: chr_bank_c = cpu_data_in; // CHR2
							4'b0011: chr_bank_d = cpu_data_in; // CHR3
							4'b0100: chr_bank_e = cpu_data_in; // CHR4
							4'b0101: chr_bank_f = cpu_data_in; // CHR5
							4'b0110: chr_bank_g = cpu_data_in; // CHR6
							4'b0111: chr_bank_h = cpu_data_in; // CHR7
							4'b1000: {sram_enabled, map_rom_on_6000, prg_bank_6000[5:0]} = {cpu_data_in[7], ~cpu_data_in[6], cpu_data_in[5:0]}; // PRG0
							4'b1001: prg_bank_a[5:0] = cpu_data_in[5:0]; // PRG1
							4'b1010: prg_bank_b[5:0] = cpu_data_in[5:0]; // PRG2
							4'b1011: prg_bank_c[5:0] = cpu_data_in[5:0]; // PRG3
							4'b1100: mirroring[1:0] = cpu_data_in[1:0]; // mirroring
							4'b1101: begin
								irq_cpu_control[1:0] = {cpu_data_in[7], cpu_data_in[0]}; // IRQ control
								irq_cpu_out = 0; // ack
							end
							4'b1110: irq_cpu_value[7:0] = cpu_data_in; // IRQ low
							4'b1111: irq_cpu_value[15:8] = cpu_data_in; // IRQ high
						endcase
					end						
				end
				
				// Mapper #32 - IREM G-101
				if (USE_MAPPER_032 && mapper == 5'b11010)
				begin
					case (cpu_addr_in[13:12])
						2'b00: prg_bank_a[5:0] = cpu_data_in[5:0]; // PRG0
						2'b01: {prg_mode[0], mirroring} = {cpu_data_in[1], 1'b0, cpu_data_in[0]}; // PRG mode, mirroring
						2'b10: prg_bank_b[5:0] = cpu_data_in[5:0]; // PRG1
						2'b11: begin
							case (cpu_addr_in[2:0]) // CHR regs
								3'b000: chr_bank_a = cpu_data_in;
								3'b001: chr_bank_b = cpu_data_in;
								3'b010: chr_bank_c = cpu_data_in;
								3'b011: chr_bank_d = cpu_data_in;
								3'b100: chr_bank_e = cpu_data_in;
								3'b101: chr_bank_f = cpu_data_in;
								3'b110: chr_bank_g = cpu_data_in;
								3'b111: chr_bank_h = cpu_data_in;
							endcase
						end
					endcase
				end
			end // romsel
		end // write
		
		// some IRQ stuff
		if (irq_scanline_reload_clear)
			irq_scanline_reload = 0;
		
		// IRQ for VRC4
		if (USE_MAPPER_021_022_023_025 & USE_VRC4_INTERRUPTS & (mapper == 5'b11000) & (irq_cpu_control[1]))
		begin
			// Cycle mode without prescaler is not used by any games? It's missed in fceux source code.
			if (irq_cpu_control[2]) // cycle mode
			begin
				irq_cpu_value[7:0] = irq_cpu_value[7:0] + 1'b1; // just count IRQ value
				if (irq_cpu_value[7:0] == 0)
				begin
					irq_cpu_out = 1;
					irq_cpu_value[7:0] = irq_cpu_latch[7:0];
				end
			end else begin // scanline mode
				vrc4_irq_prescaler = vrc4_irq_prescaler + 1'b1; // count prescaler
				if ((vrc4_irq_prescaler_counter[1] == 0 && vrc4_irq_prescaler == 114) || (vrc4_irq_prescaler_counter[1] == 1 && vrc4_irq_prescaler == 113)) // 114, 114, 113
				begin
					irq_cpu_value[7:0] = irq_cpu_value[7:0] + 1'b1;
					vrc4_irq_prescaler = 0;
					vrc4_irq_prescaler_counter = vrc4_irq_prescaler_counter + 1'b1;
					if (vrc4_irq_prescaler_counter == 2'b11) vrc4_irq_prescaler_counter =  2'b00;
					if (irq_cpu_value[7:0] == 0)
					begin
						irq_cpu_out = 1;
						irq_cpu_value[7:0] = irq_cpu_latch[7:0];
					end
				end
			end
		end

		// IRQ for Sunsoft FME-7
		if (USE_MAPPER_069 & (mapper == 5'b11001) & (irq_cpu_control[1]))
		begin
			if ((irq_cpu_value[15:0] == 0) & irq_cpu_control[0]) irq_cpu_out = 1;
			irq_cpu_value[15:0] = irq_cpu_value[15:0] - 1'b1;
		end
		
		// Mapper #18 - Sunsoft-2
		if (USE_MAPPER_018 && mapper == 5'b00111)
		begin
			if (irq_cpu_control[0])
			begin
				if (irq_cpu_control[3])
				begin
					if (irq_cpu_value[3:0] == 0) irq_cpu_out = 1;
					irq_cpu_value[3:0] = irq_cpu_value[3:0] - 1'b1;
				end else if (irq_cpu_control[2]) begin
					if (irq_cpu_value[7:0] == 0) irq_cpu_out = 1;
					irq_cpu_value[7:0] = irq_cpu_value[7:0] - 1'b1;
				end else if (irq_cpu_control[1]) begin
					if (irq_cpu_value[11:0] == 0) irq_cpu_out = 1;
					irq_cpu_value[11:0] = irq_cpu_value[11:0] - 1'b1;
				end else begin
					if (irq_cpu_value[15:0] == 0) irq_cpu_out = 1;
					irq_cpu_value[15:0] = irq_cpu_value[15:0] - 1'b1;
				end
			end
		end

		/*
		if (~romsel_alt)
			romsel_alt_clean = 1;
		else
			romsel_alt_clean = 0;
		*/
	end

	// Fire scanline IRQ if counter is zero
	// BUT doesn't fire it when it's zero end reenabled
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
			if ((irq_scanline_reload && !irq_scanline_reload_clear) || (irq_scanline_counter == 0))
			begin
				irq_scanline_counter = irq_scanline_latch;
				if (irq_scanline_reload) irq_scanline_reload_clear = 1;
			end else
				irq_scanline_counter = irq_scanline_counter - 1'b1;
			if (irq_scanline_counter == 0 && irq_scanline_enabled)
				irq_scanline_value = 1;
			else
				irq_scanline_value = 0;
		end
		if (!irq_scanline_reload) irq_scanline_reload_clear = 0;		

		// Scanline counter for mapper #163
		if (USE_MAPPER_163)
		begin
			if (new_screen & ~new_screen_clear)
			begin
				scanline = 0;			
				new_screen_clear = 1;
			end else if (a12_low_time >= 3)
			begin
				if (~new_screen && new_screen_clear) new_screen_clear = 0;
				scanline = scanline + 1'b1;
				if (scanline == 240)
					ppu_mapper_163_latch = 0;
				if (scanline == 128)
					ppu_mapper_163_latch = 1;
			end
		end
	end
	
	// A12 must be low for 3 rises of M2
	always @ (posedge m2, posedge ppu_addr_in[12])
	begin
		if (ppu_addr_in[12])
			a12_low_time = 0;
		else if (a12_low_time < 3)
			a12_low_time = a12_low_time + 1'b1;
	end
	
	// V-blank detector	
	always @ (negedge m2, negedge ppu_rd_in)
	begin
		if (~ppu_rd_in)
		begin
			ppu_rd_hi_time = 0;
			if (new_screen_clear) new_screen = 0;
		end else if (ppu_rd_hi_time < 9'b111111111)
		begin
			ppu_rd_hi_time = ppu_rd_hi_time + 1'b1;
		end else new_screen = 1;
	end

	// for MMC2/MMC4
	always @ (negedge ppu_rd_in)
	begin
		if (USE_MAPPER_009_010)
		begin
			if (ppu_addr_in[13:3] == 11'b00111111011) ppu_latch0 = 0;
			if (ppu_addr_in[13:3] == 11'b00111111101) ppu_latch0 = 1;
			if (ppu_addr_in[13:3] == 11'b01111111011) ppu_latch1 = 0;
			if (ppu_addr_in[13:3] == 11'b01111111101) ppu_latch1 = 1;
		end
	end

	