.macro jsr_8000Func
    .if nargs == 1
        lda #PRG_ROM_SWITCH|:\1
        jsr setAndSaveLowerBank
        jsr \1
    .else
        lda #PRG_ROM_SWITCH|\1
        jsr setAndSaveLowerBank
        jsr \2
    .endif
.endm

.macro jsr_a000Func
    .if nargs == 1
        lda #PRG_ROM_SWITCH|:\1-1
        jsr setAndSaveLowerBank
        jsr \1
    .else
        lda #PRG_ROM_SWITCH|\1-1
        jsr setAndSaveLowerBank
        jsr \2
    .endif
.endm

.macro jmp_8000Func
    .if nargs == 1
        lda #PRG_ROM_SWITCH|:\1
        jsr setAndSaveLowerBank
        jmp \1
    .else
        lda #PRG_ROM_SWITCH|\1
        jsr setAndSaveLowerBank
        jmp \2
    .endif
.endm

.macro jmp_a000Func
    .if nargs == 1
        lda #PRG_ROM_SWITCH|:\1-1
        jsr setAndSaveLowerBank
        jmp \1
    .else
        lda #PRG_ROM_SWITCH|\1-1
        jsr setAndSaveLowerBank
        jmp \2
    .endif
.endm

.macro jmp_8000FuncNested
    .if nargs == 1
        lda #PRG_ROM_SWITCH|:\1
        jsr saveAndSetNewLowerBank
        jsr \1
        jmp setBackup8000PrgBank
    .else
        lda #PRG_ROM_SWITCH|\1
        jsr setAndSaveLowerBank
        jsr \2
        jmp setBackup8000PrgBank
    .endif
.endm

.macro jmp_a000FuncNested
    .if nargs == 1
        lda #PRG_ROM_SWITCH|:\1-1
        jsr saveAndSetNewLowerBank
        jsr \1
        jmp setBackup8000PrgBank
    .else
        lda #PRG_ROM_SWITCH|\1-1
        jsr setAndSaveLowerBank
        jsr \2
        jmp setBackup8000PrgBank
    .endif
.endm

.macro waitForVBlank
-   lda PPUSTATUS.w
    bpl -
.endm


.macro jeq
    bne +
    jmp \1
+
.endm

.macro jne
    beq +
    jmp \1
+
.endm

.macro jcs
    bcc +
    jmp \1
+
.endm

.macro jpl
    bmi +
    jmp \1
+
.endm

.macro copy_byte_A
    lda \1
    sta \2
.endm

.macro copy_word_A
    copy_byte_A \1, \2
    copy_byte_A \1+1, \2+1
.endm

.macro copy_byte_X
    lda \1
    sta \2
.endm

.macro copy_word_X
    copy_byte_X \1, \2
    copy_byte_X \1+1, \2+1
.endm

.macro skip
    ; BIT trick
    .db $2C
.endm

.macro assert
    .if \1
    .else
        .print "assertion failed"
        .if NARGS == 1
            .print "!"
        .else
            .print ": "
            .print \2
        .endif
        .print "\n"
        .fail
    .endif
.endm