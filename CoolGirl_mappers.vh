reg [26:14] prg_base = 0;
reg [20:14] prg_mask = 7'b1111000;
reg [18:13] chr_mask = 0;
reg [2:0] prg_mode = 0;
reg map_rom_on_6000 = 0;
reg [7:0] prg_bank_6000 = 0;
reg [7:0] prg_bank_a = 0;
reg [7:0] prg_bank_b = 1;
reg [7:0] prg_bank_c = 8'b11111110;
reg [7:0] prg_bank_d = 8'b11111111;
reg [2:0] chr_mode = 0;
reg [8:0] chr_bank_a = 0;
reg [8:0] chr_bank_b = 1;
reg [8:0] chr_bank_c = 2;
reg [8:0] chr_bank_d = 3;
reg [8:0] chr_bank_e = 4;
reg [8:0] chr_bank_f = 5;
reg [8:0] chr_bank_g = 6;
reg [8:0] chr_bank_h = 7;
reg [5:0] mapper = 0;
reg [2:0] flags = 0;
reg sram_enabled = 0;
reg [1:0] sram_page = 0;
reg chr_write_enabled = 0;
reg prg_write_enabled = 0;
reg [1:0] mirroring = 0;
reg four_screen = 0;
reg lockout = 0;  

// Multiplier
reg [7:0] mul1 = 0;
reg [7:0] mul2 = 0;
wire [15:0] mul = mul1*mul2;

// IRQ stuff
assign irq = (
   mmc3_irq_out | 
   mmc5_irq_out | 
   mapper18_irq_out | 
   mapper65_irq_out | 
   vrc4_irq_out | 
   vrc3_irq_out | 
   mapper69_irq_out | 
   mapper42_irq_out | 
   mapper90_irq_out) ? 1'b0 : 1'bZ;
// for MMC3 scanline-based interrupts, counts A12 rises after long A12 falls
reg mmc3_irq_enabled = 0;           // register to enable/disable counter
reg [7:0] mmc3_irq_latch = 0;       // stores counter reload latch value
reg [7:0] mmc3_irq_counter = 0;     // counter itself (downcounting)
reg [1:0] a12_low_time = 0;         // counts how long A12 is low
reg mmc3_irq_reload = 0;            // flag to reload counter from latch
reg mmc3_irq_reload_clear = 0;      // flag to clear reload flag
reg mmc3_irq_ready = 0;             // stores 1 when IRQ is ready (enabled and non-zero)
reg mmc3_irq_out = 0;               // stores 1 when IRQ is triggered
// scanline counter, counts dummy PPU reads, detects v-blank automatically
reg [3:0] ppu_rd_hi_time = 0;       // counts how long there is no reads from PPU to detect v-blank
reg [1:0] ppu_nt_read_count;        // nametable read counter
reg [7:0] scanline = 0;             // current scanline
reg new_screen = 0;                 // stores 1 when v-blank detected ("in frame" flag)
reg new_screen_clear = 0;           // flag to clear new_screen flag
// for MMC5 scanline-based interrupts, counts dummy PPU reads
reg mmc5_irq_enabled = 0;           // register to enable/disable counter
reg [7:0] mmc5_irq_line = 0;        // scanline on which IRQ will be triggered
reg mmc5_irq_ack = 0;               // flag to acknowledge IRQ
reg mmc5_irq_out = 0;               // stores 1 when IRQ is triggered
// for mapper #18
reg [15:0] mapper18_irq_value = 0;  // counter itself (downcounting)
reg [3:0] mapper18_irq_control = 0; // IRQ settings
reg [15:0] mapper18_irq_latch = 0;  // stores counter reload latch value
reg mapper18_irq_out = 0;
// for mapper #65
reg mapper65_irq_enabled = 0;       // register to enable/disable IRQ
reg [15:0] mapper65_irq_value = 0;  // counter itself (downcounting)
reg [15:0] mapper65_irq_latch = 0;  // stores counter reload latch value 
reg mapper65_irq_out = 0;
// for Sunsoft FME-7
reg mapper69_irq_enabled = 0;           // register to enable/disable IRQ
reg mapper69_counter_enabled = 0;       // register to enable/disable counter
reg [15:0] mapper69_irq_value = 0;      // counter itself (downcounting)
reg mapper69_irq_out = 0;               // stores 1 when IRQ is triggered
// for VRC4 CPU-based interrupts
reg [7:0] vrc4_irq_value = 0;   // counter itself (upcounting)
reg [2:0] vrc4_irq_control = 0; // IRQ settings
reg [7:0] vrc4_irq_latch = 0;   // stores counter reload latch value
reg [6:0] vrc4_irq_prescaler = 0;   // prescaler counter for VRC4
reg [1:0] vrc4_irq_prescaler_counter = 0; // prescaler cicles counter for VRC4
reg vrc4_irq_out = 0;           // stores 1 when IRQ is triggered
// for VRC3 CPU-based interrupts
reg [15:0] vrc3_irq_value = 0;  // counter itself (upcounting)
reg [3:0] vrc3_irq_control = 0; // IRQ settings
reg [15:0] vrc3_irq_latch = 0;  // stores counter reload latch value
reg vrc3_irq_out = 0;           // stores 1 when IRQ is triggered
// for mapper #42 (only Baby Mario)
reg mapper42_irq_enabled = 0;       // register to enable/disable counter
reg [14:0] mapper42_irq_value = 0;  // counter itself (upcounting)
wire mapper42_irq_out = mapper42_irq_value[14] & mapper42_irq_value[13];
// for mapper #90, unfiltered PPU A12 counter
reg mapper90_irq_enabled = 0;       // register to enable/disable counter
reg [7:0] mapper90_xor;             // XOR register (is not used actually)
reg [10:0] mapper90_irq_latch = 0;   // stores counter reload latch value
reg [10:0] mapper90_irq_counter = 0; // counter itself (downcounting)
reg mapper90_irq_reload = 0;        // flag to reload counter and prescaler from latch
reg mapper90_irq_reload_clear = 0;  // flag to clear reload flag
reg mapper90_irq_pending = 0;       // flag of pending IRQ
reg mapper90_irq_out = 0;           // stores 1 when IRQ is triggered
reg mapper90_irq_out_clear = 0;     // flag to clear pending flag

// Mapper specific stuff
// for MMC2/MMC4
reg ppu_latch0 = 0;
reg ppu_latch1 = 0;
// for MMC1
reg [5:0] mmc1_load_register = 0;
// for MMC3
reg [2:0] mmc3_internal = 0;
// for mapper #69
reg [3:0] mapper69_internal = 0;
// for mapper #112
reg [2:0] mapper112_internal = 0;
// for mapper #163
reg mapper_163_latch = 0;
reg [7:0] mapper163_r0 = 0;
reg [7:0] mapper163_r1 = 0;
reg [7:0] mapper163_r2 = 0;
reg [7:0] mapper163_r3 = 0;
reg [7:0] mapper163_r4 = 0;
reg [7:0] mapper163_r5 = 0;
// to block two writes in a row 
reg writed;

wire cpu_data_out_enabled;
wire [7:0] cpu_data_out;
assign {cpu_data_out_enabled, cpu_data_out} = 
   (m2 & romsel & cpu_rw_in) ?
   (
      ((mapper == 0) && (cpu_addr_in[14:12] == 3'b101)) ? {8'b10000000, new_dendy} : // $5000 - $5FFF - new dendy flag
      (ENABLE_MAPPER_163 && (mapper == 6'b000110) && ({cpu_addr_in[14:12],cpu_addr_in[10:8]} == 6'b101001)) ? 
            {1'b1, mapper163_r2 | mapper163_r0 | mapper163_r1 | ~mapper163_r3} :
      (ENABLE_MAPPER_163 && (mapper == 6'b000110) && ({cpu_addr_in[14:12],cpu_addr_in[10:8]} == 6'b101101)) ? 
            {1'b1, mapper163_r5[0] ? mapper163_r2 : mapper163_r1} :
      (ENABLE_MAPPER_005 && (mapper == 6'b001111) && (cpu_addr_in[14:0] == 15'h5204)) ?
            {1'b1, mmc5_irq_out, ~new_screen, 6'b000000} :
      (ENABLE_MAPPER_036 && mapper == 6'b011101 && {cpu_addr_in[14:13], cpu_addr_in[8]} == 3'b101) ? // Need by Strike Wolf, being simplified mapper, this cart still uses some TCX mapper features andrely on it
            {1'b1, 2'b00, prg_bank_a[3:2], 4'b00} :
      (ENABLE_MAPPER_090_MULTIPLIER && (mapper == 6'b001101) && (cpu_addr_in[14:0] == 15'h5800)) ? {1'b1, mul[7:0]} :
      (ENABLE_MAPPER_090_MULTIPLIER && (mapper == 6'b001101) && (cpu_addr_in[14:0] == 15'h5801)) ? {1'b1, mul[15:8]} :
      9'b000000000
   ): 9'b000000000;
   
// Mirroring: 00=vertical, 01=horizontal, 10=1Sa, 11=1Sb
assign ppu_ciram_a10 = (ENABLE_MAPPER_118 & (mapper == 6'b010100) & flags[0]) ? chr_addr_mapped[17] :
   (mirroring[1] ? mirroring[0] : (mirroring[0] ? ppu_addr_in[11] : ppu_addr_in[10]));

wire [20:13] prg_addr_mapped = (map_rom_on_6000 & romsel & m2) ? prg_bank_6000 :
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

wire [18:10] chr_addr_mapped = chr_mode[2] ? (
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
         (((ENABLE_MAPPER_009_010) && chr_mode[0] && ppu_latch1) ? chr_bank_f[7:2] : chr_bank_e[7:2]) : 
         (((ENABLE_MAPPER_009_010) && chr_mode[0] && ppu_latch0) ? chr_bank_b[7:2] : chr_bank_a[7:2]),
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
      (ENABLE_MAPPER_163 && chr_mode[0]) ? (
         // 001 - Mapper #163 special
         {mapper_163_latch, ppu_addr_in[11:10]}
      ) : (
         // 000 - 0x2000(A)
         {chr_bank_a[7:3], ppu_addr_in[12:10]}
      )
   )
);

// for VRC
wire vrc_2b_hi = cpu_addr_in[1] | cpu_addr_in[3] | cpu_addr_in[5] | cpu_addr_in[7];
wire vrc_2b_low = cpu_addr_in[0] | cpu_addr_in[2] | cpu_addr_in[4] | cpu_addr_in[6];

always @ (negedge m2)
begin    
   // for MMC3
   if (mmc3_irq_reload_clear)
      mmc3_irq_reload = 0;

   // IRQ for VRC4
   if (ENABLE_MAPPER_021_022_023_025 & ENABLE_VRC4_INTERRUPTS & (vrc4_irq_control[1]))
   begin
      reg carry;
      // Cycle mode without prescaler is not used by any games? It's missed in fceux source code.
      /*
      if (vrc4_irq_control[2]) // cycle mode
      begin
         {carry, vrc4_irq_value[7:0]} = vrc4_irq_value[7:0] + 1'b1; // just count IRQ value
         if (carry)
         begin
            vrc4_irq_out = 1;
            vrc4_irq_value[7:0] = vrc4_irq_latch[7:0];
         end
      end else
      */
      begin // scanline mode
         vrc4_irq_prescaler = vrc4_irq_prescaler + 1'b1; // count prescaler
         if ((vrc4_irq_prescaler_counter[1] == 0 && vrc4_irq_prescaler == 114) 
            || (vrc4_irq_prescaler_counter[1] == 1 && vrc4_irq_prescaler == 113)) // 114, 114, 113
         begin
            vrc4_irq_prescaler = 0;
            vrc4_irq_prescaler_counter = vrc4_irq_prescaler_counter + 1'b1;
            if (vrc4_irq_prescaler_counter == 2'b11) vrc4_irq_prescaler_counter =  2'b00;
            {carry, vrc4_irq_value[7:0]} = vrc4_irq_value[7:0] + 1'b1;
            if (carry)
            begin
               vrc4_irq_out = 1;
               vrc4_irq_value[7:0] = vrc4_irq_latch[7:0];
            end
         end
      end
   end
   
   // IRQ for VRC3
   if (ENABLE_MAPPER_073 & (vrc3_irq_control[1]))
   begin
      if (vrc3_irq_control[2])
      begin // 8-bit mode
         vrc3_irq_value[7:0] = vrc3_irq_value[7:0] + 1'b1;
         if (vrc3_irq_value[7:0] == 0)
         begin
            vrc3_irq_out = 1;
            vrc3_irq_value[7:0] = vrc3_irq_latch[7:0];
         end
      end else begin // 16-bit mode
         vrc3_irq_value[15:0] = vrc3_irq_value[15:0] + 1'b1;
         if (vrc3_irq_value[15:0] == 0)
         begin
            vrc3_irq_out = 1;
            vrc3_irq_value[15:0] = vrc3_irq_latch[15:0];
         end
      end
   end      

   // IRQ for Sunsoft FME-7
   if (ENABLE_MAPPER_069 & mapper69_counter_enabled)
   begin
      reg carry;
      {carry, mapper69_irq_value[15:0]} = {1'b0, mapper69_irq_value[15:0]} - 1'b1;
      if (mapper69_irq_enabled && carry) mapper69_irq_out = 1;
   end      
   
   // Mapper #18 - Sunsoft-2
   if (ENABLE_MAPPER_018)
   begin
      if (mapper18_irq_control[0])
      begin
         reg carry;
         {carry, mapper18_irq_value[3:0]} = mapper18_irq_value[3:0] - 1'b1;
         if (mapper18_irq_control[3] == 1'b0)
            {carry, mapper18_irq_value[7:4]} = mapper18_irq_value[7:4] - carry;
         if (mapper18_irq_control[3:2] == 2'b00)
            {carry, mapper18_irq_value[11:8]} = mapper18_irq_value[11:8] - carry;
         if (mapper18_irq_control[3:1] == 3'b000)
            {carry, mapper18_irq_value[15:12]} = mapper18_irq_value[15:12] - carry;
         mapper18_irq_out = mapper18_irq_out | carry;
      end
   end
   
   // Mapper #65 - Irem's H3001
   if (ENABLE_MAPPER_065)
   begin
      if (mapper65_irq_enabled)
      begin
         if (mapper65_irq_value[15:0] != 0)
         begin
            mapper65_irq_value[15:0] = mapper65_irq_value[15:0] - 1'b1;
            if (mapper65_irq_value[15:0] == 0) mapper65_irq_out = 1;
         end
      end
   end      

   // IRQ for mapper #42
   if (ENABLE_MAPPER_042 & ENABLE_MAPPER_042_INTERRUPTS & mapper42_irq_enabled)
   begin
      mapper42_irq_value[14:0] = mapper42_irq_value[14:0] + 1'b1;
   end

   // for mapper #90
   if (mapper90_irq_pending & !mapper90_irq_out_clear)
   begin
      mapper90_irq_out = 1;
      mapper90_irq_out_clear = 1;
   end else if (!mapper90_irq_pending) begin
      mapper90_irq_out_clear = 0;
   end
   if (mapper90_irq_reload_clear)
      mapper90_irq_reload = 0;
      
   if (cpu_rw_in == 1) // read
   begin
      writed = 0;
   // block two writes in a row (RMW) for games like Snow Bros. and Bill & Ted's Excellent Adventure
   // also you can remove this check and just patch those games, lol
   end else if (cpu_rw_in == 0 && !writed) // write
   begin
      writed = 1;
      if (romsel) // $0000-$7FFF
      begin
         if ((cpu_addr_in[14:12] == 3'b101) && (lockout == 0)) // $5000-5FFF & lockout is off
         begin
            case (cpu_addr_in[2:0])
               3'b000: // $5xx0
                  {prg_base[26:22]} = cpu_data_in[4:0];                 // CPU base address A26-A22
               3'b001: // $5xx1
                  prg_base[21:14] = cpu_data_in[7:0];                   // CPU base address A21-A14
               3'b010: // $5xx2
                  {chr_mask[18], prg_mask[20:14]} = cpu_data_in[7:0];   // CHR mask A18, CPU mask A20-A14
               3'b011: // $5xx3
                  {prg_mode[2:0], chr_bank_a[7:3]} = cpu_data_in[7:0];  // PRG mode, direct chr_bank_a access
               3'b100: // $5xx4
                  {chr_mode[2:0], chr_mask[17:13]} = cpu_data_in[7:0];  // CHR mode, CHR mask A17-A13
               3'b101: // $5xx5
                  {chr_bank_a[8], prg_bank_a[5:1], sram_page[1:0]} = cpu_data_in[7:0]; // direct prg_bank_a access, current SRAM page 0-3
               3'b110: // $5xx6
                  {flags[2:0], mapper[4:0]} = cpu_data_in[7:0];         // some flags, mapper
               3'b111: // $5xx7                                         
                  // some other parameters                  
                  {lockout, mapper[5], four_screen, mirroring[1:0], prg_write_enabled, chr_write_enabled, sram_enabled} = cpu_data_in[7:0];
            endcase
            
            if (ENABLE_MAPPER_009_010 && mapper == 6'b010001) prg_bank_b = 8'b11111101;
            if (ENABLE_MAPPER_065 && mapper == 6'b001110) prg_bank_b = 1;
         end
         
         // Mapper #163          
         if (ENABLE_MAPPER_163 && (mapper == 6'b000110))
         begin
            if (cpu_addr_in[14:0] == 15'h5101)
            begin
               if ((mapper163_r4 != 0) && (cpu_data_in == 0))
                  mapper163_r5[0] = ~mapper163_r5[0];
               mapper163_r4 = cpu_data_in;             
            end else if ((cpu_addr_in[14:0] == 15'h5100) && (cpu_data_in == 6))
            begin
               prg_mode[0] = 0;
               prg_bank_b = 4'b1100;
            end else if (cpu_addr_in[14:12] == 3'b101) begin
               case (cpu_addr_in[9:8])
                  2'b10: begin
                        prg_mode[0] = 1;
                        prg_bank_a[7:6] = cpu_data_in[1:0];
                        mapper163_r0 = cpu_data_in;
                     end
                  2'b00: begin
                        prg_mode[0] = 1;
                        prg_bank_a[5:2] = cpu_data_in[3:0];
                        chr_mode[0] = cpu_data_in[7];
                        mapper163_r1 = cpu_data_in;
                     end
                  2'b11: mapper163_r2 = cpu_data_in;
                  2'b01: mapper163_r3 = cpu_data_in;
               endcase
            end               
         end
         
         // Mapper #87
         if (ENABLE_MAPPER_087 && (mapper == 6'b001100))
         begin
            if (cpu_addr_in[14:13] == 2'b11) // $6000-$7FFF
            begin
               chr_bank_a[4:3] = {cpu_data_in[0], cpu_data_in[1]};
            end
         end
         
         // Mapper #90 - JY
         if (ENABLE_MAPPER_090_MULTIPLIER && (mapper == 6'b001101))
         begin
            if (cpu_addr_in[14:0] == 15'h5800)
               mul1 = cpu_data_in;
            if (cpu_addr_in[14:0] == 15'h5801)
               mul2 = cpu_data_in;
         end

         // MMC5
         if (ENABLE_MAPPER_005 && (mapper == 6'b001111))
         begin
            // just workaround for Castlevania 3, not real MMC5
            case (cpu_addr_in[14:0])
               15'h5105: begin // mirroring
                  if (cpu_data_in == 8'b11111111)
                     four_screen = 1;
                  else begin
                     four_screen = 0;
                     case ({cpu_data_in[4], cpu_data_in[2]})
                        2'b00: mirroring = 2'b10;
                        2'b01: mirroring = 2'b00;
                        2'b10: mirroring = 2'b01;
                        2'b11: mirroring = 2'b11;
                     endcase
                  end
               end
               15'h5115: begin
                  prg_bank_a[4:0] = {cpu_data_in[4:1], 1'b0};
                  prg_bank_b[4:0] = {cpu_data_in[4:1], 1'b1};
               end
               15'h5116: prg_bank_c[4:0] = cpu_data_in[4:0];
               15'h5117: prg_bank_d[4:0] = cpu_data_in[4:0];
               15'h5120: chr_bank_a[7:0] = cpu_data_in[7:0];
               15'h5121: chr_bank_b[7:0] = cpu_data_in[7:0];
               15'h5122: chr_bank_c[7:0] = cpu_data_in[7:0];
               15'h5123: chr_bank_d[7:0] = cpu_data_in[7:0];
               15'h5128: chr_bank_e[7:0] = cpu_data_in[7:0];
               15'h5129: chr_bank_f[7:0] = cpu_data_in[7:0];
               15'h512A: chr_bank_g[7:0] = cpu_data_in[7:0];
               15'h512B: chr_bank_h[7:0] = cpu_data_in[7:0];
               15'h5203: begin
                  mmc5_irq_ack = 1;
                  mmc5_irq_line[7:0] = cpu_data_in[7:0];
               end
               15'h5204: begin
                  mmc5_irq_ack = 1;
                  mmc5_irq_enabled = cpu_data_in[7];
               end
            endcase
         end
         
         // Mapper #189
         // It's MMC3 with flag1
         if (ENABLE_MAPPER_189 & flags[1] & (mapper == 6'b010100))
         begin
            if (cpu_addr_in[14:0] >= 15'h4120) // $4120-$7FFF
            begin
               prg_bank_a[5:2] = cpu_data_in[3:0] | cpu_data_in[7:4];
            end
         end            
         
         // Mapper #113 - NINA-03/06
         if (ENABLE_MAPPER_113 && (mapper == 6'b011011))
         begin             
            if ({cpu_addr_in[14:13], cpu_addr_in[8]} == 3'b101)
            begin
               // That is, $4100-$41FF, $4300-$43FF, $45xx, $47xx, ..., $5Dxx, and $5Fxx.
               chr_bank_a[5:3] = cpu_data_in[2:0];
               prg_bank_a[4:2] = cpu_data_in[5:3];
               mirroring = {1'b0, ~cpu_data_in[7]};
            end
         end            

         // Mapper #133
         if (ENABLE_MAPPER_133 && (mapper == 6'b011100))
         begin             
            if ({cpu_addr_in[14:13], cpu_addr_in[8]} == 3'b101)
            begin
               chr_bank_a[4:3] = cpu_data_in[1:0];
               prg_bank_a[2] = cpu_data_in[2];
            end
         end            

         // Mapper #184
         if (ENABLE_MAPPER_184 && (mapper == 6'b011111))
         begin             
            if (cpu_addr_in[14:13] == 2'b11)
            begin
               chr_bank_a[4:2] = cpu_data_in[2:0];
               chr_bank_e[4:2] = {1'b1, cpu_data_in[5:4]};
            end
         end

         // Mapper #38
         if (ENABLE_MAPPER_038 && (mapper == 6'b100000))
         begin
            if (cpu_addr_in[14:12] == 3'b111)
            begin
               prg_bank_a[3:2] = cpu_data_in[1:0];
               chr_bank_a[4:3] = cpu_data_in[3:2];
            end
         end            

         // Mapper AC-08
         if (ENABLE_MAPPER_AC08 && (mapper == 6'b100001))
         begin
            if (cpu_addr_in[14:0] == 15'h4025)
            begin
               mirroring = {1'b0, cpu_data_in[3]};
            end
         end
      end else begin // $8000-$FFFF
         // Mapper #2 - UxROM
         // flag0 - mapper #71 - for Fire Hawk only.
         // other mapper-#71 games are UxROM
         if (mapper == 6'b000001)
         begin
            if (!ENABLE_MAPPER_071 | ~flags[0] | (cpu_addr_in[14:12] != 3'b001))
            begin
               prg_bank_a[UxROM_BITSIZE+1:1] = cpu_data_in[UxROM_BITSIZE:0];
               // Mapper #30 - UNROM 512
               if (ENABLE_MAPPER_030 && flags[1])
               begin
                  // One screen mirroring select, CHR RAM bank, PRG ROM bank
                  mirroring[1:0] = {1'b1, cpu_data_in[7]};
                  chr_bank_a[1:0] = cpu_data_in[6:5];
               end                  
            end else begin // CodeMasters, blah. Mirroring control used only by Fire Hawk
               mirroring[1:0] = {1'b1, cpu_data_in[4]};
            end
         end
         
         // Mapper #3 - CNROM
         if (mapper == 6'b000010)
         begin
            chr_bank_a[7:3] = cpu_data_in[4:0];
         end
         
         // Mapper #78 - Holy Diver 
         if (ENABLE_MAPPER_078 && (mapper == 6'b000011))
         begin
            prg_bank_a[3:1] = cpu_data_in[2:0];
            chr_bank_a[6:3] = cpu_data_in[7:4];
            mirroring = {1'b0, ~cpu_data_in[3]};
         end

         // Mapper #97 - Irem's TAM-S1
         if (ENABLE_MAPPER_097 && (mapper == 6'b000100))
         begin
            prg_bank_a[5:1] = cpu_data_in[4:0];
            mirroring = {1'b0, ~cpu_data_in[7]};
         end
         
         // Mapper #93 - Sunsoft-2
         if (ENABLE_MAPPER_093 && (mapper == 6'b000101))
         begin
            prg_bank_a[3:1] = {cpu_data_in[6:4]};
            chr_write_enabled = cpu_data_in[0];
         end
         
         // Mapper #18 - Jaleco SS 88006
         if (ENABLE_MAPPER_018 && (mapper == 6'b000111))
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
               5'b11000: mapper18_irq_latch[3:0] = cpu_data_in[3:0]; // $E000
               5'b11001: mapper18_irq_latch[7:4] = cpu_data_in[3:0]; // $E001
               5'b11010: mapper18_irq_latch[11:8] = cpu_data_in[3:0]; // $E002
               5'b11011: mapper18_irq_latch[15:12] = cpu_data_in[3:0]; // $E003
               5'b11100: begin // $F000
                     mapper18_irq_value[15:0] = mapper18_irq_latch[15:0];
                     mapper18_irq_out = 0; // ack
                  end
               5'b11101: begin // $F001
                     mapper18_irq_control[3:0] = cpu_data_in[3:0];
                     mapper18_irq_out = 0;
                  end
               5'b11110: 
                  case (cpu_data_in[1:0])
                     2'b00: mirroring = 2'b01; // Horz
                     2'b01: mirroring = 2'b00; // Vert
                     2'b10: mirroring = 2'b10; // 1SsA
                     2'b11: mirroring = 2'b11; // 1SsB
                  endcase
               5'b11111: ; // $F003 - sound
            endcase
         end

         // Mapper #7 - AxROM
         if (mapper == 6'b001000)
         begin
            prg_bank_a[AxROM_BxROM_BITSIZE+2:2] = cpu_data_in[AxROM_BxROM_BITSIZE:0];
            if (!ENABLE_MAPPER_034_241_BxROM || !flags[0]) // BxROM?
               mirroring = {1'b1, cpu_data_in[4]};
         end
         
         // Mapper #228 - Cheetahmen II            
         if (ENABLE_MAPPER_228 && (mapper == 6'b001001))
         begin
            prg_bank_a[5:2] = cpu_addr_in[10:7];
            chr_bank_a[7:3] = {cpu_addr_in[2:0], cpu_data_in[1:0]}; // only 256k, sorry
            mirroring = {1'b0, cpu_addr_in[13]};
         end
         
         // Mapper #11 - ColorDreams
         if (ENABLE_MAPPER_011 && (mapper == 6'b001010))
         begin
            prg_bank_a[3:2] = cpu_data_in[1:0];
            chr_bank_a[6:3] = cpu_data_in[7:4];
         end
         
         // Mapper #66 - GxROM
         if (ENABLE_MAPPER_066 && (mapper == 6'b001011))
         begin
            prg_bank_a[3:2] = cpu_data_in[5:4];
            chr_bank_a[4:3] = cpu_data_in[1:0];
         end
         
         // Mapper #90 - JY
         if (ENABLE_MAPPER_090 && (mapper == 6'b001101))
         begin
            if (cpu_addr_in[14:12] == 3'b000) // $800x
            begin
               case (cpu_addr_in[1:0])
                  2'b00: prg_bank_a[5:0] = cpu_data_in[5:0];
                  2'b01: prg_bank_b[5:0] = cpu_data_in[5:0];
                  2'b10: prg_bank_c[5:0] = cpu_data_in[5:0];
                  2'b11: prg_bank_d[5:0] = cpu_data_in[5:0];
               endcase
            end
            if (cpu_addr_in[14:12] == 3'b001) // $900x
            begin
               case (cpu_addr_in[2:0])
                  3'b000: chr_bank_a[7:0] = cpu_data_in[7:0]; // $9000
                  3'b001: chr_bank_b[7:0] = cpu_data_in[7:0]; // $9001
                  3'b010: chr_bank_c[7:0] = cpu_data_in[7:0]; // $9002
                  3'b011: chr_bank_d[7:0] = cpu_data_in[7:0]; // $9003
                  3'b100: chr_bank_e[7:0] = cpu_data_in[7:0]; // $9004
                  3'b101: chr_bank_f[7:0] = cpu_data_in[7:0]; // $9005
                  3'b110: chr_bank_g[7:0] = cpu_data_in[7:0]; // $9006
                  3'b111: chr_bank_h[7:0] = cpu_data_in[7:0]; // $9007
               endcase
            end
            if ({cpu_addr_in[14:12], cpu_addr_in[1:0]} == 5'b10101) // $D001
               mirroring = cpu_data_in[1:0];
            if (ENABLE_MAPPER_090_ACCURATE_IRQ)
            begin
               if (cpu_addr_in[14:12] == 3'b100) // $C00x
               begin
                  case (cpu_addr_in[2:0])
                     3'b000: mapper90_irq_enabled = cpu_data_in[0];
                     3'b001: ;
                     3'b010: mapper90_irq_enabled = 0;
                     3'b011: mapper90_irq_enabled = 1;
                     3'b100: begin
                           mapper90_irq_latch[2:0] = cpu_data_in[2:0] ^ mapper90_xor[2:0];
                           mapper90_irq_reload = 1;
                        end
                     3'b101: begin
                           mapper90_irq_latch[10:3] = cpu_data_in ^ mapper90_xor;
                           mapper90_irq_reload = 1;
                        end
                     3'b110: mapper90_xor = cpu_data_in;
                     3'b111: ;                        
                  endcase
               end
            end else begin
               // use MMC3's IRQs
               if (cpu_addr_in[14:12] == 3'b100) // $C00x
               begin
                  case (cpu_addr_in[2:0])
                     3'b000: mmc3_irq_enabled = cpu_data_in[0];
                     3'b001: ;
                     3'b010: mmc3_irq_enabled = 0;
                     3'b011: mmc3_irq_enabled = 1;
                     3'b100: ;
                     3'b101: begin
                           mmc3_irq_latch = cpu_data_in ^ mapper90_xor;
                           mmc3_irq_reload = 1;
                        end
                     3'b110: mapper90_xor = cpu_data_in;
                     3'b111: ;                        
                  endcase
               end
            end
         end
         
         // Mapper #65 - Irem's H3001
         if (ENABLE_MAPPER_065 && (mapper == 6'b001110))
         begin
            case ({cpu_addr_in[14:12], cpu_addr_in[2:0]})
               6'b000000: prg_bank_a[5:0] = cpu_data_in[5:0]; // $8000
               6'b001001: mirroring = {1'b0, cpu_data_in[7]}; // $9001, mirroring
               6'b001011: begin
                     mapper65_irq_out = 0; // ack
                     mapper65_irq_enabled = cpu_data_in[7]; // $9003, enable IRQ
                  end
               6'b001100: begin
                     mapper65_irq_out = 0; // ack
                     mapper65_irq_value = mapper65_irq_latch; // $9004, IRQ reload
                  end
               6'b001101: mapper65_irq_latch[15:8] = cpu_data_in; // $9005, IRQ high value
               6'b001110: mapper65_irq_latch[7:0] = cpu_data_in; // $9006, IRQ low value
               6'b010000: prg_bank_b[5:0] = cpu_data_in[5:0]; // $A000
               6'b011000: chr_bank_a[7:0] = cpu_data_in[7:0]; // $B000
               6'b011001: chr_bank_b[7:0] = cpu_data_in[7:0]; // $B001
               6'b011010: chr_bank_c[7:0] = cpu_data_in[7:0]; // $B002
               6'b011011: chr_bank_d[7:0] = cpu_data_in[7:0]; // $B003
               6'b011100: chr_bank_e[7:0] = cpu_data_in[7:0]; // $B004
               6'b011101: chr_bank_f[7:0] = cpu_data_in[7:0]; // $B005
               6'b011110: chr_bank_g[7:0] = cpu_data_in[7:0]; // $B006
               6'b011111: chr_bank_h[7:0] = cpu_data_in[7:0]; // $B007
               6'b100000: prg_bank_c[5:0] = cpu_data_in[5:0]; // $C000
            endcase
         end
         
         // Mapper #1 - MMC1
         /*
         flag0 - 16KB of PRG RAM (SOROM)
         */
         if (mapper == 6'b010000)
         begin
            if (cpu_data_in[7] == 1) // reset
            begin
               mmc1_load_register[5:0] = 6'b100000;
               prg_mode = 3'b000;   // 0x4000 (A) + fixed last (C)
               prg_bank_c[4:0] = 5'b11110;
            end else begin          
               mmc1_load_register[5:0] = {cpu_data_in[0], mmc1_load_register[5:1]};
               if (mmc1_load_register[0] == 1)
               begin
                  case (cpu_addr_in[14:13])
                     2'b00: begin // $8000-$9FFF
                        if (mmc1_load_register[4:3] == 2'b11)
                        begin
                           prg_mode = 3'b000;   // 0x4000 (A) + fixed last (C)
                           prg_bank_c[4:1] = 4'b1111;
                        end else if (mmc1_load_register[4:3] == 2'b10)
                        begin
                           prg_mode = 3'b001;   // fixed first (C) + 0x4000 (A)
                           prg_bank_c[4:1] = 4'b0000;
                        end else                   
                           prg_mode = 3'b111;   // 0x8000 (A)
                        if (mmc1_load_register[5])
                           chr_mode = 3'b100;
                        else
                           chr_mode = 3'b000;
                        mirroring[1:0] = mmc1_load_register[2:1] ^ 2'b10;
                     end
                     2'b01: begin // $A000-$BFFF
                        chr_bank_a[6:2] = mmc1_load_register[5:1];
                        prg_bank_a[5] = mmc1_load_register[5]; // for SUROM, 512k PRG support
                        prg_bank_c[5] = mmc1_load_register[5]; // for SUROM, 512k PRG support
                     end
                     2'b10: chr_bank_e[6:2] = mmc1_load_register[5:1]; // $C000-$DFFF
                     2'b11: begin
                        prg_bank_a[4:1] = mmc1_load_register[4:1]; // $E000-$FFFF
                        sram_enabled = ~mmc1_load_register[5];
                     end
                  endcase
                  mmc1_load_register[5:0] = 6'b100000;
                  if (flags[0]) // 16KB of PRG RAM
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
         if (ENABLE_MAPPER_009_010 && (mapper == 6'b010001))
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
         
         // Mapper #152 - Bandai
         if (ENABLE_MAPPER_152 && (mapper == 6'b010010))
         begin
            chr_bank_a[6:3] = cpu_data_in[3:0];
            prg_bank_a[3:1] = cpu_data_in[6:4];
            mirroring = {1'b1, cpu_data_in[7]};
         end
   
         // Mapper #73 - VRC3
         if (ENABLE_MAPPER_073 && (mapper == 6'b010011))
         begin
            case (cpu_addr_in[14:12])
               3'b000: vrc3_irq_latch[3:0] = cpu_data_in[3:0]; // $8000-$8FFF
               3'b001: vrc3_irq_latch[7:4] = cpu_data_in[3:0]; // $9000-$9FFF
               3'b010: vrc3_irq_latch[11:8] = cpu_data_in[3:0]; // $A000-$AFFF
               3'b011: vrc3_irq_latch[15:12] = cpu_data_in[3:0]; // $B000-$BFFF
               3'b100: begin // $C000-$CFFF
                     vrc3_irq_out = 0; // ack
                     vrc3_irq_control[2:0] = cpu_data_in[2:0]; // mode, enabled, enabled after ack
                     if (vrc3_irq_control[1]) // if E is set
                        vrc3_irq_value[15:0] = vrc3_irq_latch[15:0]; // reload with latch
                  end
               3'b101: begin // $D000-$DFFF
                     vrc3_irq_out = 0; // ack
                     vrc3_irq_control[1] = vrc3_irq_control[0];
                  end
               3'b110: ; // $E000-$EFFF
               3'b111: prg_bank_a[3:1] = cpu_data_in[2:0]; // $F000-$FFFF
            endcase
         end         
         
         // Mapper #4 - MMC3/MMC6
         /*
         flag0 - TxSROM
         flag1 - mapper #189
         flag2 - mapper #206 (disable most features)
         */          
         if (mapper == 6'b010100)
         begin
            case ({cpu_addr_in[14:13], cpu_addr_in[0]})
               3'b000: begin // $8000-$9FFE, even
                  mmc3_internal[2:0] = cpu_data_in[2:0];
                  if ((!ENABLE_MAPPER_189 | ~flags[1]) & (!ENABLE_MAPPER_206 | ~flags[2])) // disabled for mappers #189 & #206
                  begin
                     if (cpu_data_in[6])
                        prg_mode = 3'b101;
                     else
                        prg_mode = 3'b100;
                  end
                  if (!ENABLE_MAPPER_206 | ~flags[2]) // disabled for mapper #206
                  begin
                     if (cpu_data_in[7])
                        chr_mode = 3'b011;
                     else
                        chr_mode = 3'b010;
                  end
               end
               3'b001: begin // $8001-$9FFF, odd
                  case (mmc3_internal[2:0])
                     3'b000: chr_bank_a[7:0] = cpu_data_in[7:0];
                     3'b001: chr_bank_c[7:0] = cpu_data_in[7:0];
                     3'b010: chr_bank_e[7:0] = cpu_data_in[7:0];
                     3'b011: chr_bank_f[7:0] = cpu_data_in[7:0];
                     3'b100: chr_bank_g[7:0] = cpu_data_in[7:0];
                     3'b101: chr_bank_h[7:0] = cpu_data_in[7:0];
                     3'b110: if (!ENABLE_MAPPER_189 | ~flags[1]) prg_bank_a[(MMC3_BITSIZE-1):0] = cpu_data_in[(MMC3_BITSIZE-1):0];
                     3'b111: if (!ENABLE_MAPPER_189 | ~flags[1]) prg_bank_b[(MMC3_BITSIZE-1):0] = cpu_data_in[(MMC3_BITSIZE-1):0];
                  endcase
               end
               3'b010: if (!ENABLE_MAPPER_206 | ~flags[2]) // disabled for mapper #206
                           mirroring = {1'b0, cpu_data_in[0]}; // $A000-$BFFE, even (mirroring)
					3'b011: ; // RAM protect... no
               3'b100: mmc3_irq_latch = cpu_data_in; // $C000-$DFFE, even (IRQ latch)
               3'b101: mmc3_irq_reload = 1; // $C001-$DFFF, odd
               3'b110: mmc3_irq_enabled = 0; // $E000-$FFFE, even
               3'b111: if (!ENABLE_MAPPER_206 | ~flags[2]) // disabled for mapper #206
                           mmc3_irq_enabled = 1; // $E001-$FFFF, odd                
            endcase
         end
         
         // Mapper #112
         if (ENABLE_MAPPER_112 && (mapper == 6'b010101))
         begin
            case (cpu_addr_in[14:13])
               2'b00: mapper112_internal[2:0] = cpu_data_in[2:0]; // $8000-$9FFF
               2'b01: begin // $A000-$BFFF
                  case (mapper112_internal[2:0])
                     3'b000: prg_bank_a[5:0] = cpu_data_in[5:0];
                     3'b001: prg_bank_b[5:0] = cpu_data_in[5:0];
                     3'b010: chr_bank_a[7:0] = cpu_data_in[7:0];
                     3'b011: chr_bank_c[7:0] = cpu_data_in[7:0];
                     3'b100: chr_bank_e[7:0] = cpu_data_in[7:0];
                     3'b101: chr_bank_f[7:0] = cpu_data_in[7:0];
                     3'b110: chr_bank_g[7:0] = cpu_data_in[7:0];
                     3'b111: chr_bank_h[7:0] = cpu_data_in[7:0];
                  endcase
               end
               2'b10: ; // $C000-$DFFF
               2'b11: mirroring = {1'b0, cpu_data_in[0]}; // $E000-$FFFF
            endcase
         end

         // Mappers #33 + #48 - Taito
         // flag0=0 - #33, flag0=1 - #48
         if (ENABLE_MAPPER_033_048 && (mapper == 6'b010110))
         begin
            case ({cpu_addr_in[14:13], cpu_addr_in[1:0]})
               4'b0000: begin
                  prg_bank_a[5:0] = cpu_data_in[5:0]; // $8000, PRG Reg 0 (8k @ $8000)
                  if (~flags[0]) // #33
                     mirroring = {1'b0, cpu_data_in[6]};
               end
               4'b0001: prg_bank_b[5:0] = cpu_data_in[5:0]; // $8001, PRG Reg 1 (8k @ $A000)
               4'b0010: chr_bank_a[7:1] = cpu_data_in[6:0]; // $8002, CHR Reg 0 (2k @ $0000)
               4'b0011: chr_bank_c[7:1] = cpu_data_in[6:0]; // $8003, CHR Reg 1 (2k @ $0800)
               4'b0100: chr_bank_e[7:0] = cpu_data_in[7:0]; // $A000, CHR Reg 2 (1k @ $1000)
               4'b0101: chr_bank_f[7:0] = cpu_data_in[7:0]; // $A001, CHR Reg 2 (1k @ $1400)
               4'b0110: chr_bank_g[7:0] = cpu_data_in[7:0]; // $A002, CHR Reg 2 (1k @ $1800)
               4'b0111: chr_bank_h[7:0] = cpu_data_in[7:0]; // $A003, CHR Reg 2 (1k @ $1C00)
               4'b1100: if (flags[0]) mirroring = {1'b0, cpu_data_in[6]};  // $E000, mirroring, for mapper #48
            endcase
            if (ENABLE_MAPPER_048_INTERRUPTS & flags[0])
            begin
               case ({cpu_addr_in[14:13], cpu_addr_in[1:0]})
                  4'b1000: mmc3_irq_latch = ~cpu_data_in; // $C000, IRQ latch
                  4'b1001: mmc3_irq_reload = 1; // $C001, IRQ reload
                  4'b1010: mmc3_irq_enabled = 1; // $C002, IRQ enable
                  4'b1011: mmc3_irq_enabled = 0; // $C003, IRQ disable & ack
               endcase
            end
         end
         
         // Mappers #42
         if (ENABLE_MAPPER_042 && (mapper == 6'b010111))
         begin
            map_rom_on_6000 = 1;
            case ({cpu_addr_in[14], cpu_addr_in[1:0]})
               3'b000: chr_bank_a[7:3] = cpu_data_in[4:0]; // $8000, CHR Reg (8k @ $8000)
               3'b100: prg_bank_6000[3:0] = cpu_data_in[3:0]; // $E000, PRG Reg (8k @ $6000)
               3'b101: mirroring = {1'b0, cpu_data_in[3]}; // Mirroring
               3'b110: if (ENABLE_MAPPER_042_INTERRUPTS) begin
                        mapper42_irq_enabled = cpu_data_in[1];
                        if (!mapper42_irq_enabled) begin
                           mapper42_irq_value = 0;
                        end
                     end
            endcase
         end
         
         // Mapper #23 - VRC2/4
         /*
         flag0 - switches A0 and A1 lines. 0=A0,A1 like VRC2b (mapper #23), 1=A1,A0 like VRC2a(#22), VRC2c(#25)
         flag1 - divides CHR bank select by two (mapper #22, VRC2a)
         */
         if (ENABLE_MAPPER_021_022_023_025 && (mapper == 6'b011000))
         begin
            case ({cpu_addr_in[14:12], flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low})
               5'b00000,
               5'b00001,
               5'b00010,
               5'b00011: prg_bank_a[4:0] = cpu_data_in[4:0];  // $8000-$8003, PRG0
               5'b00100,
               5'b00101: // VRC2-using games are usually well-behaved and only write 0 or 1 to this register,
                         // but Wai Wai World in one instance writes $FF instead
                         if (cpu_data_in != 8'b11111111) mirroring = cpu_data_in[1:0]; // $9000-$9001, mirroring
               5'b00110,
               5'b00111: prg_mode[0] = cpu_data_in[1]; // $9002-$9004, PRG swap
               5'b01000,
               5'b01001,
               5'b01010,
               5'b01011: prg_bank_b[4:0] = cpu_data_in[4:0];  // $A000-$A003, PRG1
            endcase
            // flags[0] to shift lines
            if (!ENABLE_MAPPER_022 | ~flags[1])
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
                  5'b01101: chr_bank_a[7:3] = cpu_data_in[3:0];  // $B001, CHR0 hi
                  5'b01110: chr_bank_b[2:0] = cpu_data_in[3:1];  // $B002, CHR1 low
                  5'b01111: chr_bank_b[7:3] = cpu_data_in[3:0];  // $B003, CHR1 hi
                  5'b10000: chr_bank_c[2:0] = cpu_data_in[3:1];  // $C000, CHR2 low
                  5'b10001: chr_bank_c[7:3] = cpu_data_in[3:0];  // $C001, CHR2 hi
                  5'b10010: chr_bank_d[2:0] = cpu_data_in[3:1];  // $C002, CHR3 low
                  5'b10011: chr_bank_d[7:3] = cpu_data_in[3:0];  // $C003, CHR3 hi
                  5'b10100: chr_bank_e[2:0] = cpu_data_in[3:1];  // $D000, CHR4 low
                  5'b10101: chr_bank_e[7:3] = cpu_data_in[3:0];  // $D001, CHR4 hi
                  5'b10110: chr_bank_f[2:0] = cpu_data_in[3:1];  // $D002, CHR5 low
                  5'b10111: chr_bank_f[7:3] = cpu_data_in[3:0];  // $D003, CHR5 hi
                  5'b11000: chr_bank_g[2:0] = cpu_data_in[3:1];  // $E000, CHR6 low
                  5'b11001: chr_bank_g[7:3] = cpu_data_in[3:0];  // $E001, CHR6 hi
                  5'b11010: chr_bank_h[2:0] = cpu_data_in[3:1];  // $E002, CHR7 low
                  5'b11011: chr_bank_h[7:3] = cpu_data_in[3:0];  // $E003, CHR7 hi
               endcase
            end
               
            if (ENABLE_VRC4_INTERRUPTS)
            begin
               if (cpu_addr_in[14:12] == 3'b111)
               begin
                  case ({flags[0] ? vrc_2b_low : vrc_2b_hi, flags[0] ? vrc_2b_hi : vrc_2b_low}) 
                     2'b00: vrc4_irq_latch[3:0] = cpu_data_in[3:0];  // IRQ latch low
                     2'b01: vrc4_irq_latch[7:4] = cpu_data_in[3:0];  // IRQ latch hi
                     2'b10: begin // IRQ control
                        vrc4_irq_out = 0; // ack
                        vrc4_irq_control[2:0] = cpu_data_in[2:0]; // mode, enabled, enabled after ack
                        if (vrc4_irq_control[1]) begin // if E is set
                           vrc4_irq_prescaler_counter[1:0] = 2'b00; // reset prescaler
                           vrc4_irq_prescaler[6:0] = 7'b0000000;
                           vrc4_irq_value[7:0] = vrc4_irq_latch[7:0]; // reload with latch
                        end
                     end
                     2'b11: begin // IRQ ack
                        vrc4_irq_out = 0;
                        vrc4_irq_control[1] = vrc4_irq_control[0];
                     end
                  endcase
               end
            end
         end

         // Mapper #69 - Sunsoft FME-7
         /*
         r0 - command register
         */          
         if (ENABLE_MAPPER_069 && (mapper == 6'b011001))
         begin
            if (cpu_addr_in[14:13] == 2'b00) mapper69_internal[3:0] = cpu_data_in[3:0];
            if (cpu_addr_in[14:13] == 2'b01)
            begin
               case (mapper69_internal[3:0])
                  4'b0000: chr_bank_a[7:0] = cpu_data_in[7:0]; // CHR0
                  4'b0001: chr_bank_b[7:0] = cpu_data_in[7:0]; // CHR1
                  4'b0010: chr_bank_c[7:0] = cpu_data_in[7:0]; // CHR2
                  4'b0011: chr_bank_d[7:0] = cpu_data_in[7:0]; // CHR3
                  4'b0100: chr_bank_e[7:0] = cpu_data_in[7:0]; // CHR4
                  4'b0101: chr_bank_f[7:0] = cpu_data_in[7:0]; // CHR5
                  4'b0110: chr_bank_g[7:0] = cpu_data_in[7:0]; // CHR6
                  4'b0111: chr_bank_h[7:0] = cpu_data_in[7:0]; // CHR7
                  4'b1000: {sram_enabled, map_rom_on_6000, prg_bank_6000[5:0]} = {cpu_data_in[7], ~cpu_data_in[6], cpu_data_in[5:0]}; // PRG0
                  4'b1001: prg_bank_a[5:0] = cpu_data_in[5:0]; // PRG1
                  4'b1010: prg_bank_b[5:0] = cpu_data_in[5:0]; // PRG2
                  4'b1011: prg_bank_c[5:0] = cpu_data_in[5:0]; // PRG3
                  4'b1100: mirroring[1:0] = cpu_data_in[1:0]; // mirroring
                  4'b1101: begin
                     mapper69_irq_out = 0; // ack
                     mapper69_counter_enabled = cpu_data_in[7];
                     mapper69_irq_enabled = cpu_data_in[0];
                  end
                  4'b1110: mapper69_irq_value[7:0] = cpu_data_in[7:0]; // IRQ low
                  4'b1111: mapper69_irq_value[15:8] = cpu_data_in[7:0]; // IRQ high
               endcase
            end                  
         end
         
         // Mapper #32 - IREM G-101
         if (ENABLE_MAPPER_032 && (mapper == 6'b011010))
         begin
            case (cpu_addr_in[14:12])
               3'b000: prg_bank_a[5:0] = cpu_data_in[5:0]; // $8000-$8FFF, PRG0
               3'b001: {prg_mode[0], mirroring} = {cpu_data_in[1], 1'b0, cpu_data_in[0]}; // $9000-$9FFF, PRG mode, mirroring
               3'b010: prg_bank_b[5:0] = cpu_data_in[5:0]; // $A000-$AFFF, PRG1
               3'b011: begin // $B000-$BFFF, CHR regs
                  case (cpu_addr_in[2:0])
                     3'b000: chr_bank_a[7:0] = cpu_data_in[7:0];
                     3'b001: chr_bank_b[7:0] = cpu_data_in[7:0];
                     3'b010: chr_bank_c[7:0] = cpu_data_in[7:0];
                     3'b011: chr_bank_d[7:0] = cpu_data_in[7:0];
                     3'b100: chr_bank_e[7:0] = cpu_data_in[7:0];
                     3'b101: chr_bank_f[7:0] = cpu_data_in[7:0];
                     3'b110: chr_bank_g[7:0] = cpu_data_in[7:0];
                     3'b111: chr_bank_h[7:0] = cpu_data_in[7:0];
                  endcase
               end
            endcase
         end
         
         // Mapper #36 - TXC's PCB 01-22000-400
         if (ENABLE_MAPPER_036 && (mapper == 6'b011101))
         begin
            if (cpu_addr_in[14:1] != 14'b11111111111111)
            begin
               prg_bank_a[5:2] = cpu_data_in[7:4];
               chr_bank_a[6:3] = cpu_data_in[3:0];
            end
         end

         // Mapper #70 - Bandai
         if (ENABLE_MAPPER_070 && (mapper == 6'b011110))
         begin
            prg_bank_a[4:1] = cpu_data_in[7:4];
            chr_bank_a[6:3] = cpu_data_in[3:0];
         end

         // Mapper AC-08
         if (ENABLE_MAPPER_AC08 && (mapper == 6'b100001))
         begin
            prg_bank_6000[3:0] = cpu_data_in[4:1];
            map_rom_on_6000 = 1;
         end
         
			// Mapper #75 - VRC1
         if (ENABLE_MAPPER_075 && (mapper == 6'b100010))
         begin
            case (cpu_addr_in[14:12])
               3'b000: prg_bank_a[3:0] = cpu_data_in[3:0]; // $8000-$8FFF
               3'b001: begin  // $9000-$9FFF
                           mirroring = {1'b0, cpu_data_in[0]};
                           chr_bank_a[6] = cpu_data_in[1];
                           chr_bank_e[6] = cpu_data_in[2];
                       end
               3'b010: prg_bank_b[3:0] = cpu_data_in[3:0]; // $A000-$AFFF
               3'b100: prg_bank_c[3:0] = cpu_data_in[3:0]; // $C000-$CFFF
               3'b110: chr_bank_a[5:2] = cpu_data_in[3:0]; // $E000-$EFFF
               3'b111: chr_bank_e[5:2] = cpu_data_in[3:0]; // $F000-$FFFF
            endcase
         end
      end // romsel
   end // write
   
   // Some IRQ stuff

   // for MMC3
   if (!mmc3_irq_enabled)
   begin
      // ack
      mmc3_irq_ready = 0;
      mmc3_irq_out = 0;
   end else if (mmc3_irq_enabled && (mmc3_irq_counter != 0))
   begin
      // Fire scanline IRQ if counter is zero      
      // BUT doesn't fire it when it's zero end reenabled
      mmc3_irq_ready = 1;
   end else if (mmc3_irq_ready && (mmc3_irq_counter == 0))
   begin
      mmc3_irq_out = 1;
   end

   // for mapper #90
   if (ENABLE_MAPPER_090 & ENABLE_MAPPER_090_ACCURATE_IRQ & !mapper90_irq_enabled)
   begin
       mapper90_irq_out = 0;
   end

   // for MMC5
   if (ENABLE_MAPPER_005)
   begin
      if (romsel && (cpu_addr_in[14:0] == 15'h5204)) // write or read
         mmc5_irq_ack = 1;         
      if (mmc5_irq_ack && ~mmc5_irq_out)
         mmc5_irq_ack = 0;
   end
end

// IRQ counter
always @ (posedge ppu_addr_in[12])
begin 
   // new scanline
   if (a12_low_time == 3)
   begin
      // for MMC3
      if ((mmc3_irq_reload && !mmc3_irq_reload_clear) || (mmc3_irq_counter == 0))
      begin
         mmc3_irq_counter = mmc3_irq_latch;
         if (mmc3_irq_reload) mmc3_irq_reload_clear = 1;
      end else begin
         mmc3_irq_counter = mmc3_irq_counter - 1'b1;
      end
   end
   if (!mmc3_irq_reload) mmc3_irq_reload_clear = 0;    
   
   // for mapper #90
   if (ENABLE_MAPPER_090 & ENABLE_MAPPER_090_ACCURATE_IRQ)
   begin
      if (mapper90_irq_out_clear) mapper90_irq_pending = 0;
      if (mapper90_irq_reload && !mapper90_irq_reload_clear) 
      begin
         mapper90_irq_counter = mapper90_irq_latch;
         mapper90_irq_reload_clear = 1;
      end else if (!mapper90_irq_reload)
      begin
         mapper90_irq_reload_clear = 0;
      end         
      
      if (mapper90_irq_enabled)
      begin
         reg carry;
         {carry, mapper90_irq_counter} = mapper90_irq_counter - 1'b1;
         mapper90_irq_pending = mapper90_irq_pending | carry;
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
   end else if (ppu_rd_hi_time < 4'b1111)
   begin
      // Counting how long there is no PPU reads
      ppu_rd_hi_time = ppu_rd_hi_time + 1'b1;
   end else begin
      // Too long, v-blank detected
      new_screen = 1;
   end
end   

// Scanline counter
always @ (negedge ppu_rd_in)
begin 
   if (mmc5_irq_ack) mmc5_irq_out = 0;
   if (~new_screen && new_screen_clear) new_screen_clear = 0;
   if (new_screen & ~new_screen_clear)
   begin
      scanline = 0;        
      new_screen_clear = 1;
      mapper_163_latch = 0;
   end else 
   if (ppu_addr_in[13:12] == 2'b10)
   begin
      if (ppu_nt_read_count < 3)
      begin
         ppu_nt_read_count = ppu_nt_read_count + 1'b1;
      end else begin
         scanline = scanline + 1'b1;
         if (mmc5_irq_enabled && scanline == mmc5_irq_line+1)
            mmc5_irq_out = 1;
         if (scanline == 129)
            mapper_163_latch = 1;
      end
   end else begin
      ppu_nt_read_count = 0;
   end
end

// for MMC2/MMC4
always @ (negedge ppu_rd_in)
begin
   if (ENABLE_MAPPER_009_010)
   begin
      if (ppu_addr_in[13:3] == 11'b00111111011) ppu_latch0 = 0;
      if (ppu_addr_in[13:3] == 11'b00111111101) ppu_latch0 = 1;
      if (ppu_addr_in[13:3] == 11'b01111111011) ppu_latch1 = 0;
      if (ppu_addr_in[13:3] == 11'b01111111101) ppu_latch1 = 1;
   end
end
