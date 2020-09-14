/*
   COOLGIRL Multicart branch 3.x
*/

module CoolGirl # (
      parameter USE_MAPPER_005 = 1,             // MMC5 (partical support): Castlevania 3 only
      parameter USE_MAPPER_009_010 = 1,         // mappers #009 - MMC2, #010 - MMC4
      parameter USE_MAPPER_011 = 1,             // mapper #011 - Color Dreams
      parameter USE_MAPPER_018 = 0,             // mapper #018 - Jaleco SS 88006
      parameter USE_MAPPER_021_022_023_025 = 1, // mappers #021, #022, #023, #025 - VRC2, VRC4
      parameter USE_MAPPER_022 = 1,             // mapper #022 - VRC2a (shifted CHR lines)
      parameter USE_VRC4_INTERRUPTS = 1,        // VRC4 interrupts
      parameter USE_MAPPER_030 = 1,             // mapper #030 - add UNROM512 features to UxROM
      parameter USE_MAPPER_032 = 1,             // mapper #032 - IREM G101
      parameter USE_MAPPER_033_048 = 1,         // mappers #033 & #048 - Taito      
      parameter USE_MAPPER_048_INTERRUPTS = 0,  // mapper #048 interrupts
      parameter USE_MAPPER_034_241_BxROM = 1,   // mappers #034 & #241 - BxROM: Deadly Towers (Mashou), Darkseed
      parameter USE_MAPPER_036 = 0,             // mapper #036 - TXC's PCB 01-22000-400
      parameter USE_MAPPER_042 = 1,             // mapper #042 - FDS conversions
      parameter USE_MAPPER_042_INTERRUPTS = 0,  // mapper #042 interrupts: for Mario Baby only
      parameter USE_MAPPER_065 = 1,             // mapper #065 - Irem's H3001
      parameter USE_MAPPER_066 = 1,             // mapper #066 - GxROM
      parameter USE_MAPPER_069 = 1,             // mapper #069 - Sunsoft FME-7
      parameter USE_MAPPER_070 = 0,             // mapper #070 - Bandai: Family Trainer, Kamen Rider Club, Space Shadow
      parameter USE_MAPPER_071 = 1,             // mapper #071 - Camerica: for Fire Hawk only
      parameter USE_MAPPER_073 = 0,             // mapper #073 - VRC3
      parameter USE_MAPPER_078 = 1,             // mapper #078 - Irem: Holy Diver and Uchuusen - Cosmo Carrier
      parameter USE_MAPPER_087 = 1,             // mapper #087 - Jaleco
      parameter USE_MAPPER_090 = 1,             // mapper #090 - JY (partical support): Aladdin only
      parameter USE_MAPPER_090_ACCURATE_IRQ = 0,// mapper #090 accurate IRQs: for Super Mario World
      parameter USE_MAPPER_090_MULTIPLIER = 0,  // mapper #090 multiplier: for Super Mario World protection check
      parameter USE_MAPPER_093 = 1,             // mapper #093 - Sunsoft-2: Shanghai, Fantasy Zone
      parameter USE_MAPPER_097 = 0,             // mapper #097 - IREM TAMS1: only Kaiketsu Yanchamaru
      parameter USE_MAPPER_112 = 0,             // mapper #112 - NTDEC
      parameter USE_MAPPER_113 = 0,             // mapper #113 - NINA-03/06
      parameter USE_MAPPER_118 = 1,             // mapper #118 - TxSROM
      parameter USE_MAPPER_133 = 0,             // mapper #133 - Sachen, 72-pin version only
      parameter USE_MAPPER_152 = 1,             // mapper #152 - Bandai
      parameter USE_MAPPER_163 = 1,             // mapper #163 - Nanjing
      parameter USE_MAPPER_184 = 0,             // mapper #184
      parameter USE_MAPPER_189 = 1,             // mapper #189 - TXC
      parameter USE_MAPPER_206 = 0,             // mapper #206 - the simpler predecessor of the MMC3
      parameter USE_MAPPER_228 = 0,             // mapper #228 - Action52: Cheetahmen II only
      
      parameter USE_FOUR_SCREEN = 1,            // Enable four-screen support, required by some games
      parameter UxROM_BITSIZE = 4,              // Maximum size for UxROM PRG (3=256KB - standard size, 4=512KB - required for some hacks/homebrew)
      parameter AxROM_BxROM_BITSIZE = 3,        // Maximum size for AxROM/BxROM PRG (2=256KB - standard size, 3=512KB - required for some hacks/homebrew)
      parameter MMC3_BITSIZE = 8                // Maximum size for MMC3 PRG (6=512KB - standard size, 8=2MB - required for some hacks/homebrew)
   )
   (
   input m2,
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
   input [13:3] ppu_addr_in,
   output [18:10] ppu_addr_out,
   output ppu_rd_out,
   output ppu_wr_out,
   output ppu_ciram_a10,
   input ppu_not_a13,
   output ppu_ciram_ce,
   output ppu_not_a13_out,
      
   output irq,
   
   output cpu_shifers_oe
);
   reg [3:0] new_dendy_init = 4'b1111;
   reg [1:0] new_dendy_init_a13l = 2'b11;
   reg [1:0] new_dendy_init_a13h = 2'b11;
   wire new_dendy_init_finished = new_dendy_init == 0;
   reg new_dendy = 0;
   assign cpu_shifers_oe = 1'b0;
   assign ppu_addr_out[18] = 1'b1; // reserved
   
   assign cpu_addr_out[26:13] = {cpu_base[26:14] | (cpu_addr_mapped[20:14] & ~prg_mask[20:14]), cpu_addr_mapped[13]};
   assign sram_addr_out[14:13] = sram_page[1:0];
   assign ppu_addr_out[17:10] = ext_ntram_access ? {6'b111111, ppu_addr_in[11:10]} : {ppu_addr_mapped[17:13] & ~chr_mask[17:13], ppu_addr_mapped[12:10]};

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
   assign ppu_rd_out = ppu_rd_in | (ppu_addr_in[13] & ~ext_ntram_access);
   assign ppu_wr_out = ppu_wr_in | ((ppu_addr_in[13] | ~chr_write_enabled) & ~ext_ntram_access);
   wire ext_ntram_access = USE_FOUR_SCREEN && four_screen && ppu_addr_in[13] && ~ppu_addr_in[12]; // four-screen and $2000-$2FFF accessed 
   assign ppu_ciram_ce = new_dendy_init_finished ? 
         (new_dendy ? 1'bZ : // not used by new famiclones
         ext_ntram_access ? 1'b1 : // disable internal NTRAM
         ~ppu_addr_in[13] /*1'bZ*/) // enable it otherwise
         : 1'b0; // ground it while powering on for new famiclones
   assign ppu_not_a13_out = new_dendy_init_finished ? 1'bZ : 1'b0;  // ground it while powering on for new famiclones
   
   always @ (posedge m2)
   begin
      if (!new_dendy_init_finished)
         new_dendy_init = new_dendy_init - 1'b1;
   end
   
   always @ (negedge ppu_rd_in)
   begin
      if (new_dendy_init_finished)
      begin
         if ((new_dendy_init_a13l != 0) && 
            (new_dendy_init_a13h != 0) && 
            (ppu_addr_in[13] != ~ppu_not_a13))
               new_dendy = 1;
         if (~ppu_addr_in[13] && new_dendy_init_a13l != 0) new_dendy_init_a13l = new_dendy_init_a13l - 1'b1;
         if (ppu_addr_in[13] && new_dendy_init_a13h != 0) new_dendy_init_a13h = new_dendy_init_a13h - 1'b1;
      end
   end
   
`include "mappers.vh"
   
endmodule


