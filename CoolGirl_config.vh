parameter ENABLE_MAPPER_005 = 1,             // MMC5 (partical support): Castlevania 3 only
parameter ENABLE_MAPPER_009_010 = 1,         // mappers #009 - MMC2, #010 - MMC4
parameter ENABLE_MAPPER_011 = 1,             // mapper #011 - Color Dreams
parameter ENABLE_MAPPER_018 = 0,             // mapper #018 - Jaleco SS 88006
parameter ENABLE_MAPPER_021_022_023_025 = 1, // mappers #021, #022, #023, #025 - VRC2, VRC4
parameter ENABLE_MAPPER_022 = 1,             // mapper #022 - VRC2a (shifted CHR lines)
parameter ENABLE_VRC4_INTERRUPTS = 1,        // VRC4 interrupts
parameter ENABLE_MAPPER_030 = 1,             // mapper #030 - add UNROM512 features to UxROM
parameter ENABLE_MAPPER_032 = 1,             // mapper #032 - Irem's G101
parameter ENABLE_MAPPER_033_048 = 1,         // mappers #033 & #048 - Taito      
parameter ENABLE_MAPPER_048_INTERRUPTS = 0,  // mapper #048 interrupts
parameter ENABLE_MAPPER_034_241_BxROM = 1,   // mappers #034 & #241 - BxROM: Deadly Towers (Mashou), Darkseed
parameter ENABLE_MAPPER_036 = 0,             // mapper #036 - TXC's PCB 01-22000-400
parameter ENABLE_MAPPER_038 = 0,             // mapper #038: Crime Busters
parameter ENABLE_MAPPER_042 = 1,             // mapper #042 - FDS conversions
parameter ENABLE_MAPPER_042_INTERRUPTS = 0,  // mapper #042 interrupts: for Mario Baby only
parameter ENABLE_MAPPER_065 = 1,             // mapper #065 - Irem's H3001
parameter ENABLE_MAPPER_066 = 1,             // mapper #066 - GxROM
parameter ENABLE_MAPPER_069 = 1,             // mapper #069 - Sunsoft FME-7
parameter ENABLE_MAPPER_070 = 1,             // mapper #070 - Bandai: Family Trainer, Kamen Rider Club, Space Shadow
parameter ENABLE_MAPPER_071 = 1,             // mapper #071 - Camerica: for Fire Hawk only
parameter ENABLE_MAPPER_073 = 0,             // mapper #073 - VRC3
parameter ENABLE_MAPPER_075 = 0,             // mapper #075 - VRC1
parameter ENABLE_MAPPER_078 = 1,             // mapper #078 - Irem: Holy Diver and Uchuusen - Cosmo Carrier
parameter ENABLE_MAPPER_087 = 1,             // mapper #087 - Jaleco
parameter ENABLE_MAPPER_090 = 1,             // mapper #090 - JY (partical support): Aladdin only
parameter ENABLE_MAPPER_090_ACCURATE_IRQ = 0,// mapper #090 accurate IRQs: for Super Mario World
parameter ENABLE_MAPPER_090_MULTIPLIER = 0,  // mapper #090 multiplier: for Super Mario World protection check
parameter ENABLE_MAPPER_093 = 1,             // mapper #093 - Sunsoft-2: Shanghai, Fantasy Zone
parameter ENABLE_MAPPER_097 = 0,             // mapper #097 - Irem's TAM-S1: only Kaiketsu Yanchamaru
parameter ENABLE_MAPPER_112 = 0,             // mapper #112 - NTDEC
parameter ENABLE_MAPPER_113 = 0,             // mapper #113 - NINA-03/06
parameter ENABLE_MAPPER_118 = 1,             // mapper #118 - TxSROM
parameter ENABLE_MAPPER_133 = 0,             // mapper #133 - Sachen, 72-pin version only
parameter ENABLE_MAPPER_152 = 1,             // mapper #152 - Bandai
parameter ENABLE_MAPPER_163 = 1,             // mapper #163 - Nanjing
parameter ENABLE_MAPPER_184 = 0,             // mapper #184
parameter ENABLE_MAPPER_189 = 1,             // mapper #189 - TXC
parameter ENABLE_MAPPER_206 = 0,             // mapper #206 - the simpler predecessor of the MMC3
parameter ENABLE_MAPPER_228 = 0,             // mapper #228 - Action52: Cheetahmen II only
parameter ENABLE_MAPPER_AC08 = 1,            // mapper AC-08: Green Beret FDS conversion

parameter ENABLE_FOUR_SCREEN = 1,            // Enable four-screen support, required by some games
parameter UxROM_BITSIZE = 4,                 // Maximum size for UxROM PRG (3=256KB - standard size, 4=512KB - required for some hacks/homebrew)
parameter AxROM_BxROM_BITSIZE = 3,           // Maximum size for AxROM/BxROM PRG (2=256KB - standard size, 3=512KB - required for some hacks/homebrew)
parameter MMC3_BITSIZE = 8                   // Maximum size for MMC3 PRG (6=512KB - standard size, 8=2MB - required for some hacks/homebrew)
