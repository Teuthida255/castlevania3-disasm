.memorymap
    defaultslot 1

    ; (ram)
    slotsize $800
    slot 0 $0000

    slotsize $2000
    slot 1 $8000

    slotsize $2000
    slot 2 $a000

    slotsize $2000
    slot 3 $c000

    slotsize $2000
    slot 4 $e000

    slotsize $2000
    slot 5 $6000
.endme

.rombanksize $2000
.ifdef IS_EXTENDED_ROM
    .rombanks $50
.else
    .rombanks $20
.endif

.asciitable
.enda

.emptyfill $ff