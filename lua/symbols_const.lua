g_symbols_const = {}

g_symbols_const["PPUCTRL"] = 0x2000
g_symbols_const["PPUCTRL_NMI_ON"] = 0x80
g_symbols_const["PPUCTRL_COLOR_ON_EXT_PINS"] = 0x40
g_symbols_const["PPUCTRL_SPR_16"] = 0x20
g_symbols_const["PPUCTRL_BG_1000"] = 0x10
g_symbols_const["PPUCTRL_SPR_1000"] = 0x08
g_symbols_const["PPUCTRL_PPUDATA_INC_DOWN"] = 0x04
g_symbols_const["PPUCTRL_PPUDATA_INC_RIGHT"] = 0x00
g_symbols_const["PPUCTRL_NT_BASE"] = 0x03

g_symbols_const["PPUMASK"] = 0x2001
g_symbols_const["PPUMASK_EMP_BLUE"] = 0x80
g_symbols_const["PPUMASK_EMP_GREEN"] = 0x40
g_symbols_const["PPUMASK_EMP_RED"] = 0x20
g_symbols_const["PPUMASK_SHOW_SPR"] = 0x10
g_symbols_const["PPUMASK_SHOW_BG"] = 0x08
g_symbols_const["PPUMASK_SPR_LEFT_8PX"] = 0x04
g_symbols_const["PPUMASK_BG_LEFT_8PX"] = 0x02
g_symbols_const["PPUMASK_GREYSCALE"] = 0x01

g_symbols_const["PPUSTATUS"] = 0x2002
g_symbols_const["OAMADDR"] = 0x2003
g_symbols_const["PPUSCROLL"] = 0x2005
g_symbols_const["PPUADDR"] = 0x2006
g_symbols_const["PPUDATA"] = 0x2007
g_symbols_const["OAMDMA"] = 0x4014

g_symbols_const["NAMETABLE0"] = 0x2000
g_symbols_const["INTERNAL_PALETTES"] = 0x3f00


g_symbols_const["SND_VOL"] = 0x4000
g_symbols_const["SND_SWEEP"] = 0x4001
g_symbols_const["SND_FREQ_LO"] = 0x4002
g_symbols_const["SND_FREQ_HI"] = 0x4003
g_symbols_const["LENGTH_COUNTER_LOAD"] = 0xf8


g_symbols_const["SQ1_VOL"] = 0x4000
g_symbols_const["SQ1_SWEEP"] = 0x4001
g_symbols_const["SQ1_LO"] = 0x4002
g_symbols_const["SQ1_HI"] = 0x4003
g_symbols_const["SQ2_VOL"] = 0x4004
g_symbols_const["SQ2_SWEEP"] = 0x4005
g_symbols_const["SQ2_LO"] = 0x4006
g_symbols_const["SQ2_HI"] = 0x4007
g_symbols_const["TRI_LINEAR"] = 0x4008
g_symbols_const["TRI_LO"] = 0x400a
g_symbols_const["TRI_HI"] = 0x400b
g_symbols_const["NOISE_VOL"] = 0x400c
g_symbols_const["NOISE_LO"] = 0x400e
g_symbols_const["NOISE_HI"] = 0x400f
g_symbols_const["DMC_FREQ"] = 0x4010
g_symbols_const["DMC_RAW"] = 0x4011
g_symbols_const["DMC_START"] = 0x4012
g_symbols_const["DMC_LEN"] = 0x4013
g_symbols_const["SND_CHN"] = 0x4015
g_symbols_const["SNDENA_DMC"] = 0x10
g_symbols_const["SNDENA_NOISE"] = 0x08
g_symbols_const["SNDENA_TRI"] = 0x04
g_symbols_const["SNDENA_SQ2"] = 0x02
g_symbols_const["SNDENA_SQ1"] = 0x01
g_symbols_const["APU_FRAME_CTR"] = 0x4017


g_symbols_const["JOY1"] = 0x4016
g_symbols_const["JOY2"] = 0x4017
g_symbols_const["PADF_A"] = 0x80
g_symbols_const["PADF_B"] = 0x40
g_symbols_const["PADF_SELECT"] = 0x20
g_symbols_const["PADF_START"] = 0x10
g_symbols_const["PADF_UP"] = 0x08
g_symbols_const["PADF_DOWN"] = 0x04
g_symbols_const["PADF_LEFT"] = 0x02
g_symbols_const["PADF_RIGHT"] = 0x01


g_symbols_const["PCM_MODE"] = 0x5010
g_symbols_const["PRG_MODE"] = 0x5100
g_symbols_const["PRG_MODE_16_8_8"] = 0x02
g_symbols_const["CHR_MODE"] = 0x5101
g_symbols_const["EXTENDED_RAM_PROTECT_A"] = 0x5102
g_symbols_const["EXTENDED_RAM_PROTECT_B"] = 0x5103
g_symbols_const["EXTENDED_RAM_MODE"] = 0x5104


g_symbols_const["MMC5_PULSE1_VOL"] = 0x5000
g_symbols_const["MMC5_PULSE1_LO"] = 0x5002
g_symbols_const["MMC5_PULSE1_HI"] = 0x5003
g_symbols_const["MMC5_PULSE2_VOL"] = 0x5004
g_symbols_const["MMC5_PULSE2_LO"] = 0x5006
g_symbols_const["MMC5_PULSE2_HI"] = 0x5007
g_symbols_const["MMC5_STATUS"] = 0x5015
g_symbols_const["SNDENA_MMC5_PULSE1"] = 0x01
g_symbols_const["SNDENA_MMC5_PULSE2"] = 0x02






g_symbols_const["NAMETABLE_MAPPING"] = 0x5105
g_symbols_const["NT_VERTICAL_MIRROR"] = 0x44 
g_symbols_const["NT_HORIZONTAL_MIRROR"] = 0x50 
g_symbols_const["NT_SINGLE_SCREEN_CIRAM_1"] = 0x55 
g_symbols_const["NT_ALL_MODES_HORIZONTAL_MIRROR"] = 0xd8
g_symbols_const["NT_ALL_MODES_VERTICAL_MIRROR"] = 0xe4 
g_symbols_const["NT_SINGLE_SCREEN_FILL_MODE"] = 0xff 
g_symbols_const["FILL_MODE_TILE"] = 0x5106
g_symbols_const["FILL_MODE_COLOUR"] = 0x5107
g_symbols_const["PRG_BANK_8000"] = 0x5115
g_symbols_const["PRG_BANK_c000"] = 0x5116
g_symbols_const["PRG_ROM_SWITCH"] = 0x80


g_symbols_const["CHR_BANK_0000"] = 0x5120
g_symbols_const["CHR_BANK_0400"] = 0x5121
g_symbols_const["CHR_BANK_0800"] = 0x5122
g_symbols_const["CHR_BANK_0c00"] = 0x5123
g_symbols_const["CHR_BANK_1000"] = 0x5124
g_symbols_const["CHR_BANK_1400"] = 0x5125
g_symbols_const["CHR_BANK_1800"] = 0x5126
g_symbols_const["CHR_BANK_1c00"] = 0x5127
g_symbols_const["CHR_BANK_0000_1000"] = 0x5128
g_symbols_const["CHR_BANK_0400_1400"] = 0x5129
g_symbols_const["CHR_BANK_0800_1800"] = 0x512a
g_symbols_const["CHR_BANK_0c00_1c00"] = 0x512b
g_symbols_const["VERTICAL_SPLIT_MODE"] = 0x5200
g_symbols_const["SCANLINE_CMP_VALUE"] = 0x5203
g_symbols_const["SCANLINE_IRQ_STATUS"] = 0x5204
return {g_symbols_const=g_symbols_const}