# COOLGIRL - ultimate multigame cartridge for Famicom

The goal of the project is to create a open source Famicom cartridge that will not be too expensive and can contain up to ~700 games of various mappers.

## Registers
Range: 5000-$5FFF

Mask: $5007

All registers are $00 on power-on and reset.

### $5xx0
```
 7  bit  0
 ---- ----
 PPPP PPPP
 |||| ||||
 ++++-++++-- PRG base offset (A29-A22)
```

### $5xx1
```
 7  bit  0
 ---- ----
 PPPP PPPP
 |||| ||||
 ++++-++++-- PRG base offset (A21-A14)
```

### $5xx2
```
 7  bit  0
 ---- ----
 AMMM MMMM
 |||| ||||
 |+++-++++-- PRG mask (A20-A14, inverted+anded with PRG address)
 +---------- CHR mask (A18, inverted+anded with CHR address)
```

### $5xx3
```
 7  bit  0
 ---- ----
 BBBC CCCC
 |||| ||||
 |||+-++++-- CHR bank A (bits 7-3)
 +++-------- PRG banking mode (see below)
```

### $5xx4
```
 7  bit  0
 ---- ----
 DDDE EEEE
 |||| ||||
 |||+-++++-- CHR mask (A17-A13, inverted+anded with CHR address)
 +++-------- CHR banking mode (see below)
```

### $5xx5
```
 7  bit  0
 ---- ----
 CDDE EEWW
 |||| ||||
 |||| ||++-- 8KiB WRAM page at $6000-$7FFF
 |+++-++---- PRG bank A (bits 5-1)
 +---------- CHR bank A (bit 8)
```

### $5xx6
```
 7  bit  0
 ---- ----
 FFFM MMMM
 |||| ||||
 |||+ ++++-- Mapper code (bits 4-0, see below)
 +++-------- Flags 2-0, functionality depends on selected mapper
```

### $5xx7
```
 7  bit  0
 ---- ----
 LMTR RSNO
 |||| |||+-- Enable WRAM (read and write) at $6000-$7FFF
 |||| ||+--- Allow writes to CHR RAM
 |||| |+---- Allow writes to flash chip
 |||+-+----- Mirroring (00=vertical, 01=horizontal, 10=1Sa, 11=1Sb)
 ||+-------- Enable four-screen mode
 |+-- ------ Mapper code (bit 5, see below)
 +---------- Lockout bit (prevent further writes to all registers)
```

## Mapper codes
```
| Code   | iNES mapper number(s) and name(s)  | Flags meaning                         | Notes                                     |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000000 | 0 (NROM)                           |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000001 | 2 (UxROM)                          | 0 - enable "Fire Hawk" mirroring for  | Mapper 2 is fully compartible with mapper |
|        | 71 (Codemasters)                   |     mapper 71 (Codemasters)           | 71 but "Fire Hawk" only uses mirroring    |
|        | 30 (UNROM-512)                     | 1 - Enable one screen mirroring       | control. UNROM-512 self-writable feature  |
|        |                                    |     select for mapper 30 (UNROM-512)  | is not supported                          |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000010 | 2 (CNROM)                          |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000011 | 78 (Irem)                          |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000100 | 97 (Irem's TAM-S1)                 |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000101 | 93 (Sunsoft-2)                     |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000110 | 163 (Nanjing)                      |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 000111 | 18 (Jaleco SS 88006)               |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001000 | 7 (AxROM)                          | 0 - disable mirroring control, used   | iNES Mapper 034 is used to designate both |
|        | 34 (BNROM, NINA-001)               |     to select mapper 34 instead of 7  | the BNROM and NINA-001 boards but only    |
|        |                                    |                                       | BNROM is supported                        |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001001 | 228 (Action 52)                    |                                       | Only Cheetahmen II is supported           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001010 | 11 (Color Dreams)                  |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001011 | 66 (GxROM)                         |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001100 | 87                                 |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001101 | 90 (J.Y. Company)                  |                                       | Partical support only, can be used for    |
|        |                                    |                                       | "Aladdin" game only                       |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001110 | 65 (Irem's H3001)                  |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 001111 | 5 (MMC5)                           |                                       | Experimental partically support, can be   |
|        |                                    |                                       | used for "Castlevania 3 (U)" only         |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010000 | 1 (MMC1)                           | 0 - enable 16KiB of WRAM              |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010001 | 9 (MMC2)                           |                                       |                                           |
|        | 10 (MMC4)                          | 0 - 0=MMC2, 1=MMC4                    |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010010 | 152                                |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010011 | 73 (VRC3)                          |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010100 | 4 (MMC3/MMC6)                      | 0 - use TxROM                         |                                           |
|        | 118 (TxROM)                        | 1 - use mapper 189                    |                                           |
|        | 189                                | 2 - use mapper 206                    |                                           |
|        | 206 (Namco, Tengen, others)        |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010101 | 112                                |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010110 | 33 (Taito)                         | 0 - 0=33, 1=48                        |                                           |
|        | 48 (Taito)                         |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 010111 | 42 (FDS conversions)               | 0 - switch   A0 and A1 lines:         |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011000 | 21 (VRC2/VRC4)                     |     0=A0,A1 like VRC2b (mapper #23),  |                                           |
|        | 22 (VRC2/VRC4)                     |     1=A1,A0 like VRC2a(#22),          |                                           |
|        | 23 (VRC2/VRC4)                     |       VRC2c(#25)                      |                                           |
|        | 25 (VRC2/VRC4)                     | 1 - divide CHR bank select by two     |                                           |
|        |                                    |     (mapper #22, VRC2a)               |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011001 | 69 (Sunsoft FME-7)                 |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011010 | 32 (IREM G-101)                    |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011011 | 79 (NINA-03/06)                    |                                       |                                           |
|        | 146 (Sachen 3015)                  |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011100 | 133 (Sachen)                       |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011101 | 36 (TXC's PCB 01-22000-400)        |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011110 | 70                                 |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 011111 | 184 (Sunsoft-1)                    |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 100000 | 38                                 |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 100001 | Reserved                           |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 100010 | 75 (VRC1)                          |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 100011 | 83                                 |                                       | Submapper 0 only                          |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 100100 | 67 (Sunsoft-3)                     |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| 100101 | 89 (Sunsoft-2 on Sunsoft-3 PCB)    |                                       |                                           |
| ------ + ---------------------------------- + ------------------------------------- + ----------------------------------------- |
| ...... | Reserved                           |                                       |                                           |

```

## PRG banking modes
```
| Code | $8000 | $A000 | $E000 | $C000 | Notes                                    |
| ---- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 000  |       A       |       C       | UxROM, MMC4, MMC1 mode #3, etc.          |
| ---- + ------------- + ------------- + ---------------------------------------- |
| 001  |       C       |       A       | Mapper 97 (TAM-S1)                       |
| ---- + ------------- + ------------- + ---------------------------------------- |
| 010  |           Reserved            |                                          |
| ---- + ----------------------------- + ---------------------------------------- |
| 011  |           Reserved            |                                          |
| ---- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 100  |   A   |   B   |   C   |   D   | Universal, used by MMC3 mode 0, etc.     |
| ---- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 101  |   C   |   B   |   A   |   D   | MMC3 mode #1                             |
| ---- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 110  |               B               | Mapper 163                               |
| ---- + ----------------------------- + ---------------------------------------- |
| 111  |               A               | AxROM, MMC1 modes 0/1, Color Dreams      |
```
Power-on/reset state: A=0, B=~2, C=~1, D=~0

## CHR banking modes
```
| Code | $0000 | $0400 | $0800 | $0C00 | $1000 | $1400 | $1800 | $1C00 | Notes                                    |
| ---- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 000  |                               A                               | Used by many simple mappers              |
| ---- + ------------------------------------------------------------- + ---------------------------------------- |
| 001  |                          Spetial mode                         | Used by mapper 163                       |
| ---- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 010  |       A       |       C       |   E   |   F   |   G   |   H   | Used by MMC3 mode 0                      |
| ---- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 011  |   E   |   F   |   G   |   H   |       A       |       C       | Used by MMC3 mode 1                      |
| ---- + ----- + ----- + ----- + ----- + ------------- + ------------- + ---------------------------------------- |
| 100  |               A               |               E               | Used by MMC1                             |
| ---- + ----------------------------- + ------------- + ------------- + ---------------------------------------- |
| 101  |              A/B              |              E/F              | MMC2/MMC4, switched by tiles $FD or $FE  |
| ---- + ------- ----- + ------------- + ------------- + ------------- + ---------------------------------------- |
| 110  |       A       |       C       |       E       |       G       | Used by many complicated mappers         |
| ---- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ----- + ---------------------------------------- |
| 111  |   A   |   B   |   C   |   D   |   E   |  F    |   G   |   H   | Used by very complicated mappers         |
```
Power-on/reset state: A=0, B=1, C=2, D=3, E=4, F=5, G=6, H=7
