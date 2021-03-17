
import sys
import os.path
import buildSound

header = [
    0x4e, 0x45, 0x53, 0x1a, 0x10, 0x10, 0x50, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
]

isExtended = 'IS_EXTENDED_ROM' in sys.argv[1:]
if isExtended:
    # PRG rom
    header[4] = 0x40 # was 0x10

    # CHR rom
    header[5] = 0x80 # was 0x10

if 'EXTENDED_RAM' in sys.argv[1:]:
    header[6] = 0x52

with open('castlevania3.bin', 'rb') as f:
    prgData = bytearray(f.read())

with open('original/OR.chr', 'rb') as f:
    chrData = f.read()

if "INSERT_SOUND" in sys.argv[1:]:
    buildSound.build(prgData)

if isExtended:
    chrData += bytearray(0x100000-len(chrData))

with open('castlevania3build.nes', 'wb') as f:
    f.write(bytearray(header) + prgData + chrData)
