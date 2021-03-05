; Data

; todo: get from export
grooves:
    .dw @groove0
    .dw @groove1
    .dw @groove2
    .dw @groove3
    .dw @groove4
    .dw @groove5
    .dw @groove6
@groove0:
    .db $09 $00
@groove1:
    .db $09 $08 $00
@groove2:
    .db $08 $00
@groove3:
    .db $08 $07 $00
@groove4:
    .db $07 $00
@groove5:
    .db $07 $06 $00
@groove6:
    .db $06 $00

; todo: loop point is DPCM's Bxx
numFramesAndLoopPoint:
    .db $08 $06

; last col (conductor) is same as dpcm
framePhrases:
    .db $00 $00 $00 $00 $00 $00 $00 $00
    .db $01 $01 $01 $01 $01 $01 $01 $01
    .db $02 $02 $02 $00 $02 $01 $01 $02
    .db $02 $03 $03 $01 $02 $01 $01 $02
    .db $02 $04 $02 $00 $02 $01 $01 $02
    .db $02 $05 $05 $05 $05 $01 $01 $05
    .db $06 $06 $06 $06 $06 $06 $06 $06
    .db $07 $07 $07 $07 $07 $06 $06 $07

phraseAddrs:
    .dw @instrSQ1
    .dw @instrSQ2
    .dw @instrTRI
    .dw @instrNOISE
    .dw @instrDPCM
    .dw @instrPULSE1
    .dw @instrPULSE2
    .dw @instrConductor

@instrSQ1:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
    .dw @@phrase7
@@phrase0:
    .db $ff
@@phrase1:
    .db $ff
@@phrase2:
    .db $90 $81
    .db $a0 $47
    .db $0b $06 $7f ; G#2
    .db $5e $7f
    .db $0d $06 $7f ; A#2
    .db $ff
@@phrase3:
    .db $ff
@@phrase4:
    .db $ff
@@phrase5:
    .db $ff
@@phrase6:
    .db $90 $80 $a0 $00
    .db $03 $07 $c1 ; C2
    .db $03 $07 $c1 ; C2
    .db $5f $c3
    .db $03 $07 $c1 ; C2
    .db $5f $c1
    .db $6f $63
    .db $03 $07 $c1 ; C2
    .db $03 $07 $c1 ; C2
    .db $5f $c3
    .db $03 $07 $c1 ; C2
    .db $5f $c1
    .db $67
    .db $20 $08 $77 ; F4
    .db $23 $08 $91 ; G#4
    .db $5f $91
    .db $ff
@@phrase7:
    .db $90 $80 $a0 $00
    .db $03 $07 $c1 ; C2
    .db $03 $07 $c1 ; C2
    .db $6f $c3
    .db $03 $07 $c1 ; C2
    .db $5f $c1
    .db $6f $63
    .db $03 $07 $c1 ; C2
    .db $03 $07 $c1 ; C2
    .db $5f $c3
    .db $03 $07 $c1 ; C2
    .db $5f $c1
    .db $60
    .db $ff

@instrSQ2:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
    .dw @@phrase7
@@phrase0:
    .db $ff
@@phrase1:
    .db $ff
@@phrase2:
    .db $62
    .db $90 $7f
    .db $a0 $47
    .db $0b $06 $2f ; G#2
    .db $5e $2f
    .db $0d $06 $2f ; A#2
    .db $ff
@@phrase3:
    .db $5e $22
    .db $a0 $47
    .db $0b $06 $2f ; G#2
    .db $5e $2f
    .db $a0 $49
    .db $0d $06 $2f ; A#2
    .db $5e $2a
    .db $a0 $00
    .db $90 $80
    .db $1b $02 $80 ; C4
    .db $1d $02 $90 ; D4
    .db $ff
@@phrase4:
    .db $1e $02 $a7 ; D#4
    .db $5f $ad
    .db $1e $09 $a1 ; D#4
    .db $20 $05 $a3 ; F4
    .db $5f $a1
    .db $1e $02 $a0 ; D#4
    .db $20 $03 $a0 ; F4
    .db $22 $02 $a7 ; G4
    .db $5f $a9
    .db $22 $09 $a1 ; G4
    .db $25 $04 $a3 ; A#4
    .db $23 $03 $a3 ; G#4
    .db $22 $02 $a0 ; G4
    .db $ff
@@phrase5:
    .db $22 $02 $31 ; G4
    .db $23 $04 $a5 ; G#4
    .db $5f $af
    .db $5f $a1
    .db $23 $09 $a3 ; G#4
    .db $25 $02 $a0 ; A#4
    .db $23 $03 $a0 ; G#4
    .db $22 $03 $a7 ; G4
    .db $5f $a0
    .db $ff
@@phrase6:
    .db $90 $81 $a0 $00
    .db $00 $07 $c1 ; A1
    .db $00 $07 $c1 ; A1
    .db $5f $c3
    .db $00 $07 $c1 ; A1
    .db $5f $c1
    .db $6f $63
    .db $00 $07 $c1 ; A1
    .db $00 $07 $c1 ; A1
    .db $5f $c3
    .db $00 $07 $c1 ; A1
    .db $5f $c1
    .db $63
    .db $22 $08 $67 ; G4
    .db $25 $08 $85 ; A#4
    .db $5f $91
    .db $ff
@@phrase7:
    .db $90 $81 $a0 $00
    .db $00 $07 $c1 ; A1
    .db $00 $07 $c1 ; A1
    .db $6f $c3
    .db $00 $07 $c1 ; A1
    .db $5f $c1
    .db $6f $63
    .db $00 $07 $c1 ; A1
    .db $00 $07 $c1 ; A1
    .db $5f $c3
    .db $00 $07 $c1 ; A1
    .db $5f $c1
    .db $60
    .db $ff

@instrTRI:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
    .dw @@phrase7
@@phrase0:
    .db $60
    .db $ff
@@phrase1:
    .db $6f
    .db $67
    .db $0f $0c $13 ; C3
    .db $90 $80 $5e $10
    .db $90 $7f $5e $10
    .db $90 $7e $5e $10
    .db $90 $7b $5e $10
    .db $ff
@@phrase2:
    .db $0b $0c $17 ; G#2
    .db $5f $1f
    .db $5e $17
    .db $0a $0c $17 ; G2
    .db $5f $15
    .db $0d $0c $10 ; A#2
    .db $0f $0c $10 ; C3
    .db $11 $0c $17 ; D3
    .db $5f $16
    .db $80 $05
    .db $5e $10
    .db $ff
@@phrase3:
    .db $90 $70
    .db $12 $0c $10 ; D#3
    .db $90 $78
    .db $5e $10
    .db $90 $80
    .db $5e $15
    .db $5f $1f
    .db $5e $17
    .db $90 $70
    .db $14 $0c $10 ; F3
    .db $90 $78
    .db $5e $10
    .db $90 $80
    .db $5e $15
    .db $5f $15
    .db $13 $0c $10 ; E3
    .db $12 $0c $10 ; D#3
    .db $11 $0c $17 ; D3
    .db $5f $16
    .db $80 $05
    .db $5e $10
    .db $ff
@@phrase4:
    .db $ff
@@phrase5:
    .db $90 $70
    .db $12 $0c $10 ; D#3
    .db $90 $78
    .db $5e $10
    .db $90 $80
    .db $5e $15
    .db $5f $1f
    .db $5e $16
    .db $80 $05
    .db $5e $10
    .db $90 $70
    .db $14 $0c $10 ; F3
    .db $90 $78
    .db $5e $10
    .db $90 $80
    .db $5e $15
    .db $5f $15
    .db $14 $0c $10 ; F3
    .db $15 $0c $10 ; F#3
    .db $16 $0c $17 ; G3
    .db $5f $13
    .db $16 $0d $10 ; G3
    .db $ff
@@phrase6:
    .db $03 $0b $11 ; C2
    .db $03 $0b $12 ; C2
    .db $62
    .db $03 $0b $13 ; C2
    .db $6f $63
    .db $03 $0b $11 ; C2
    .db $03 $0b $12 ; C2
    .db $62
    .db $03 $0b $13 ; C2
    .db $60
    .db $ff
@@phrase7:
    .db $03 $0b $11 ; C2
    .db $03 $0b $12 ; C2
    .db $62
    .db $03 $0b $13 ; C2
    .db $63
    .db $80 $0a
    .db $05 $0f $11 ; D2
    .db $80 $0a
    .db $03 $0f $11 ; C2
    .db $09 $0f $11 ; F#2
    .db $0a $0f $11 ; G2
    .db $80 $0a
    .db $05 $0f $11 ; D2
    .db $80 $0a
    .db $03 $0f $11 ; C2
    .db $80 $0a
    .db $09 $0f $11 ; F#2
    .db $80 $0a
    .db $0a $0f $11 ; G2
    .db $03 $0b $11 ; C2
    .db $03 $0b $12 ; C2
    .db $62
    .db $03 $0b $13 ; C2
    .db $6f
    .db $0a $0f $10 ; G2
    .db $08 $0f $10 ; F2
    .db $06 $0f $10 ; D#2
    .db $05 $0f $10 ; D2
    .db $ff

@instrNOISE:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
    .dw @@phrase7
@@phrase0:
    .db $01 $0f $16
    .db $01 $0f $20
    .db $01 $0f $17
    .db $01 $0f $21
    .db $01 $0f $16
    .db $01 $0f $20
    .db $01 $0f $16
    .db $01 $0f $22
    .db $01 $0f $17
    .db $01 $0f $23
    .db $01 $0f $17
    .db $01 $0f $22
    .db $01 $0f $10
    .db $ff
@@phrase1:
    .db $5e $10
    .db $01 $0f $23
    .db $01 $0f $16
    .db $01 $0f $22
    .db $01 $0f $15
    .db $01 $0f $22
    .db $01 $0f $18
    .db $01 $0f $26
    .db $01 $0f $14
    .db $01 $0f $20
    .db $01 $0f $18
    .db $01 $0f $21
    .db $01 $0f $10
    .db $ff
@@phrase2:
    .db $ff
@@phrase3:
    .db $ff
@@phrase4:
    .db $ff
@@phrase5:
    .db $5e $10
    .db $01 $0f $23
    .db $01 $0f $16
    .db $01 $0f $22
    .db $01 $0f $15
    .db $01 $0f $22
    .db $01 $0f $18
    .db $01 $0f $26
    .db $01 $0f $14
    .db $01 $0f $20
    .db $01 $0f $18
    .db $01 $0f $20
    .db $01 $0f $30
    .db $01 $0f $40
    .db $01 $0f $50
    .db $01 $0f $60
    .db $01 $0f $70
    .db $02 $0f $80
    .db $03 $0f $90
    .db $04 $0f $b0
    .db $ff
@@phrase6:
    .db $04 $0e $c1
    .db $04 $0e $a5
    .db $04 $0e $c9
    .db $6d
    .db $04 $0e $c1
    .db $04 $0e $a5
    .db $04 $0e $c9
    .db $60
    .db $ff
@@phrase7:
    .db $04 $0e $c1
    .db $04 $0e $a5
    .db $04 $0e $c9
    .db $6d
    .db $04 $0e $c1
    .db $04 $0e $a5
    .db $04 $0e $c9
    .db $60
    .db $ff

@instrDPCM:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
    .dw @@phrase7
@@phrase0:
    .db $ff
@@phrase1:
    .db $ff
@@phrase2:
    .db $ff
@@phrase3:
    .db $ff
@@phrase4:
    .db $ff
@@phrase5:
    .db $ff
@@phrase6:
    .db $00 $f0 $01
    .db $00 $f1 $05
    .db $00 $f0 $07
    .db $4f
    .db $00 $f0 $01
    .db $00 $f1 $05
    .db $00 $f0 $00
    .db $ff
@@phrase7:
    .db $00 $f0 $01
    .db $00 $f1 $05
    .db $00 $f0 $07
    .db $4f
    .db $00 $f0 $01
    .db $00 $f1 $05
    .db $00 $f0 $03
    .db $00 $e0 $01
    .db $00 $e0 $01
    .db $00 $00 $01
    .db $00 $f1 $03
    .db $00 $f1 $01
    .db $00 $f0 $00
    .db $ff

@instrPULSE1:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
@@phrase0:
    .db $90 $82

    .db $03 $01 $51 ; C2

    .db $05 $01 $50 ; D2
    .db $70 $01 $20
    .db $06 $01 $50 ; D#2
    .db $71 $01 $20
    .db $0a $01 $50 ; G2
    .db $71 $01 $20
    .db $0b $01 $50 ; G#2
    .db $71 $01 $20
    .db $0f $01 $50 ; C3
    .db $71 $01 $20
    .db $11 $01 $50 ; D3
    .db $71 $01 $20
    .db $12 $01 $50 ; D#3
    .db $71 $01 $20

    .db $03 $01 $61 ; C2

    .db $05 $01 $60 ; D2
    .db $70 $01 $20
    .db $06 $01 $60 ; D#2
    .db $71 $01 $20
    .db $0a $01 $60 ; G2
    .db $71 $01 $20
    .db $0b $01 $60 ; G#2
    .db $71 $01 $20
    .db $0f $01 $60 ; C3
    .db $71 $01 $20
    .db $11 $01 $60 ; D3
    .db $71 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20

    .db $03 $01 $71 ; C2

    .db $05 $01 $70 ; D2
    .db $70 $01 $20
    .db $06 $01 $70 ; D#2
    .db $71 $01 $20
    .db $0a $01 $70 ; G2
    .db $71 $01 $20
    .db $0b $01 $70 ; G#2
    .db $71 $01 $20
    .db $0f $01 $70 ; C3
    .db $71 $01 $20
    .db $11 $01 $70 ; D3
    .db $71 $01 $20
    .db $12 $01 $70 ; D#3
    .db $71 $01 $20

    .db $03 $01 $81 ; C2

    .db $05 $01 $80 ; D2
    .db $70 $01 $30
    .db $06 $01 $80 ; D#2
    .db $71 $01 $30
    .db $0a $01 $80 ; G2
    .db $71 $01 $30
    .db $0b $01 $80 ; G#2
    .db $71 $01 $30
    .db $0f $01 $80 ; C3
    .db $71 $01 $30
    .db $11 $01 $80 ; D3
    .db $71 $01 $30
    .db $12 $01 $80 ; D#3
    .db $71 $01 $30

    .db $ff
@@phrase1:
    .db $03 $01 $81 ; C2

    .db $05 $01 $80 ; D2
    .db $70 $01 $30
    .db $06 $01 $80 ; D#2
    .db $71 $01 $30
    .db $0a $01 $80 ; G2
    .db $71 $01 $30
    .db $0b $01 $80 ; G#2
    .db $71 $01 $30
    .db $0f $01 $80 ; C3
    .db $71 $01 $30
    .db $11 $01 $80 ; D3
    .db $71 $01 $30
    .db $12 $01 $80 ; D#3
    .db $71 $01 $30

    .db $03 $01 $81 ; C2

    .db $05 $01 $80 ; D2
    .db $70 $01 $30
    .db $06 $01 $80 ; D#2
    .db $71 $01 $30
    .db $0a $01 $80 ; G2
    .db $71 $01 $30
    .db $0b $01 $80 ; G#2
    .db $71 $01 $30
    .db $0f $01 $80 ; C3
    .db $71 $01 $30
    .db $11 $01 $80 ; D3
    .db $71 $01 $30
    .db $12 $01 $80 ; D#3
    .db $71 $01 $30

    .db $03 $01 $81 ; C2

    .db $05 $01 $80 ; D2
    .db $70 $01 $30
    .db $06 $01 $80 ; D#2
    .db $71 $01 $30
    .db $0a $01 $80 ; G2
    .db $71 $01 $30
    .db $0b $01 $80 ; G#2
    .db $71 $01 $30
    .db $0f $01 $80 ; C3
    .db $71 $01 $30
    .db $11 $01 $80 ; D3
    .db $71 $01 $30
    .db $12 $01 $80 ; D#3
    .db $71 $01 $30

    .db $03 $01 $81 ; C2

    .db $05 $01 $80 ; D2
    .db $70 $01 $30
    .db $06 $01 $80 ; D#2
    .db $71 $01 $30
    .db $0a $01 $80 ; G2
    .db $71 $01 $30
    .db $0b $01 $80 ; G#2
    .db $71 $01 $30
    .db $0f $01 $80 ; C3
    .db $71 $01 $30
    .db $11 $01 $80 ; D3
    .db $71 $01 $30
    .db $12 $01 $80 ; D#3
    .db $71 $01 $30

    .db $ff
@@phrase2:
    .db $ff
@@phrase3:
    .db $ff
@@phrase4:
    .db $ff
@@phrase5:
    .db $ff
@@phrase6:
    .db $90 $80

    .db $03 $0a $81 ; C2

    .db $05 $0a $80 ; D2
    .db $70 $0a $30
    .db $06 $0a $80 ; D#2
    .db $71 $0a $30
    .db $0a $0a $80 ; G2
    .db $71 $0a $30
    .db $0b $0a $80 ; G#2
    .db $71 $0a $30
    .db $0f $0a $80 ; C3
    .db $71 $0a $30
    .db $11 $0a $80 ; D3
    .db $71 $0a $30
    .db $12 $0a $80 ; D#3
    .db $71 $0a $30

    .db $03 $0a $81 ; C2

    .db $05 $0a $80 ; D2
    .db $70 $0a $30
    .db $06 $0a $80 ; D#2
    .db $71 $0a $30
    .db $0a $0a $80 ; G2
    .db $71 $0a $30
    .db $0b $0a $80 ; G#2
    .db $71 $0a $30
    .db $0f $0a $80 ; C3
    .db $71 $0a $30
    .db $11 $0a $80 ; D3
    .db $71 $0a $30
    .db $12 $0a $80 ; D#3
    .db $71 $0a $30

    .db $03 $0a $81 ; C2

    .db $05 $0a $80 ; D2
    .db $70 $0a $30
    .db $06 $0a $80 ; D#2
    .db $71 $0a $30
    .db $0a $0a $80 ; G2
    .db $71 $0a $30
    .db $0b $0a $80 ; G#2
    .db $71 $0a $30
    .db $0f $0a $80 ; C3
    .db $71 $0a $30
    .db $11 $0a $80 ; D3
    .db $71 $0a $30
    .db $12 $0a $80 ; D#3
    .db $71 $0a $30

    .db $03 $0a $81 ; C2

    .db $05 $0a $80 ; D2
    .db $70 $0a $30
    .db $06 $0a $80 ; D#2
    .db $71 $0a $30
    .db $0a $0a $80 ; G2
    .db $71 $0a $30
    .db $0b $0a $80 ; G#2
    .db $71 $0a $30
    .db $0f $0a $80 ; C3
    .db $71 $0a $30
    .db $11 $0a $80 ; D3
    .db $71 $0a $30
    .db $12 $0a $80 ; D#3
    .db $71 $0a $30

    .db $ff

@instrPULSE2:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
@@phrase0:
    .db $90 $7e

    .db $03 $01 $21 ; C2

    .db $05 $01 $20 ; D2
    .db $70 $01 $10
    .db $06 $01 $20 ; D#2
    .db $71 $01 $10
    .db $0a $01 $20 ; G2
    .db $71 $01 $10
    .db $0b $01 $20 ; G#2
    .db $71 $01 $10
    .db $0f $01 $20 ; C3
    .db $71 $01 $10
    .db $11 $01 $20 ; D3
    .db $71 $01 $10
    .db $12 $01 $20 ; D#3
    .db $71 $01 $10

    .db $03 $01 $31 ; C2

    .db $05 $01 $30 ; D2
    .db $70 $01 $10
    .db $06 $01 $30 ; D#2
    .db $71 $01 $10
    .db $0a $01 $30 ; G2
    .db $71 $01 $10
    .db $0b $01 $40 ; G#2
    .db $71 $01 $10
    .db $0f $01 $40 ; C3
    .db $71 $01 $10
    .db $11 $01 $40 ; D3
    .db $71 $01 $10
    .db $12 $01 $40 ; D#3
    .db $71 $01 $10

    .db $03 $01 $51 ; C2

    .db $05 $01 $30 ; D2
    .db $70 $01 $20
    .db $06 $01 $50 ; D#2
    .db $71 $01 $20
    .db $0a $01 $50 ; G2
    .db $71 $01 $20
    .db $0b $01 $50 ; G#2
    .db $71 $01 $20
    .db $0f $01 $50 ; C3
    .db $71 $01 $20
    .db $11 $01 $50 ; D3
    .db $71 $01 $20
    .db $12 $01 $50 ; D#3
    .db $71 $01 $20

    .db $03 $01 $61 ; C2

    .db $05 $01 $30 ; D2
    .db $70 $01 $20
    .db $06 $01 $60 ; D#2
    .db $71 $01 $20
    .db $0a $01 $60 ; G2
    .db $71 $01 $20
    .db $0b $01 $60 ; G#2
    .db $71 $01 $20
    .db $0f $01 $60 ; C3
    .db $71 $01 $20
    .db $11 $01 $60 ; D3
    .db $71 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20

    .db $ff
@@phrase1:
    .db $03 $01 $61 ; C2

    .db $05 $01 $60 ; D2
    .db $70 $01 $20
    .db $06 $01 $60 ; D#2
    .db $71 $01 $20
    .db $0a $01 $60 ; G2
    .db $71 $01 $20
    .db $0b $01 $60 ; G#2
    .db $71 $01 $20
    .db $0f $01 $60 ; C3
    .db $71 $01 $20
    .db $11 $01 $60 ; D3
    .db $71 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20

    .db $03 $01 $61 ; C2

    .db $05 $01 $60 ; D2
    .db $70 $01 $20
    .db $06 $01 $60 ; D#2
    .db $71 $01 $20
    .db $0a $01 $60 ; G2
    .db $71 $01 $20
    .db $0b $01 $60 ; G#2
    .db $71 $01 $20
    .db $0f $01 $60 ; C3
    .db $71 $01 $20
    .db $11 $01 $60 ; D3
    .db $71 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20

    .db $03 $01 $61 ; C2

    .db $05 $01 $60 ; D2
    .db $70 $01 $20
    .db $06 $01 $60 ; D#2
    .db $71 $01 $20
    .db $0a $01 $60 ; G2
    .db $71 $01 $20
    .db $0b $01 $60 ; G#2
    .db $71 $01 $20
    .db $0f $01 $60 ; C3
    .db $71 $01 $20
    .db $11 $01 $60 ; D3
    .db $71 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20

    .db $03 $01 $61 ; C2

    .db $05 $01 $60 ; D2
    .db $70 $01 $20
    .db $06 $01 $60 ; D#2
    .db $71 $01 $20
    .db $0a $01 $60 ; G2
    .db $71 $01 $20
    .db $0b $01 $60 ; G#2
    .db $71 $01 $20
    .db $0f $01 $60 ; C3
    .db $71 $01 $20
    .db $11 $01 $60 ; D3
    .db $71 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20

    .db $ff
@@phrase2:
    .db $ff
@@phrase3:
    .db $ff
@@phrase4:
    .db $ff
@@phrase5:
    .db $ff
@@phrase6:
    .db $0f $01 $61 ; C3

    .db $11 $01 $60 ; D3
    .db $70 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20
    .db $16 $01 $60 ; G3
    .db $71 $01 $20
    .db $17 $01 $60 ; G#3
    .db $71 $01 $20
    .db $1b $01 $60 ; C4
    .db $71 $01 $20
    .db $1d $01 $60 ; D4
    .db $71 $01 $20
    .db $1e $01 $60 ; D#4
    .db $71 $01 $20

    .db $0f $01 $61 ; C3

    .db $11 $01 $60 ; D3
    .db $70 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20
    .db $16 $01 $60 ; G3
    .db $71 $01 $20
    .db $17 $01 $60 ; G#3
    .db $71 $01 $20
    .db $1b $01 $60 ; C4
    .db $71 $01 $20
    .db $1d $01 $60 ; D4
    .db $71 $01 $20
    .db $1e $01 $60 ; D#4
    .db $71 $01 $20

    .db $0f $01 $61 ; C3

    .db $11 $01 $60 ; D3
    .db $70 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20
    .db $16 $01 $60 ; G3
    .db $71 $01 $20
    .db $17 $01 $60 ; G#3
    .db $71 $01 $20
    .db $1b $01 $60 ; C4
    .db $71 $01 $20
    .db $1d $01 $60 ; D4
    .db $71 $01 $20
    .db $1e $01 $60 ; D#4
    .db $71 $01 $20

    .db $0f $01 $61 ; C3

    .db $11 $01 $60 ; D3
    .db $70 $01 $20
    .db $12 $01 $60 ; D#3
    .db $71 $01 $20
    .db $16 $01 $60 ; G3
    .db $71 $01 $20
    .db $17 $01 $60 ; G#3
    .db $71 $01 $20
    .db $1b $01 $60 ; C4
    .db $71 $01 $20
    .db $1d $01 $60 ; D4
    .db $71 $01 $20
    .db $1e $01 $60 ; D#4
    .db $71 $01 $20

    .db $ff

@instrConductor:
    .dw @@phrase0
    .dw @@phrase1
    .dw @@phrase2
    .dw @@phrase3
    .dw @@phrase4
    .dw @@phrase5
    .dw @@phrase6
    .dw @@phrase7
@@phrase0:
    .db $90 $8f $87 $91 $87 $92 $87 $93
    .db $87 $94 $8b $95 $ff
@@phrase1:
    .db $20 $96 $ff
@@phrase2:
    .db $ff
@@phrase3:
    .db $ff
@@phrase4:
    .db $ff
@@phrase5:
    .db $8f $8f $8f $95 $83 $94 $83 $93 $83 $92 $ff
@@phrase6:
    .db $96 $ff
@@phrase7:
    .db $ff

; vol - arp - pitch - n/a - duty/noise
; todo: python script to convert out of ranges to $ff
instrumentData:
    .db $ff $ff $ff $ff $ff ; 00
    .db $00 $ff $07 $ff $00 ; 01
    .db $02 $ff $02 $ff $03 ; 02
    .db $02 $ff $02 $ff $02 ; 03
    .db $02 $ff $09 $ff $03 ; 04
    .db $02 $ff $09 $ff $02 ; 05
    .db $01 $00 $07 $ff $01 ; 06
    .db $05 $03 $ff $ff $05 ; 07
    .db $06 $ff $06 $ff $06 ; 08
    .db $07 $ff $03 $ff $07 ; 09
    .db $00 $ff $01 $ff $00 ; 0a
    .db $ff $02 $ff $ff $ff ; 0b
    .db $ff $ff $04 $ff $ff ; 0c
    .db $ff $ff $05 $ff $ff ; 0d
    .db $03 $01 $ff $ff $ff ; 0e
    .db $08 $ff $ff $ff $04 ; 0f


; loop - release - length - vals
instrumentVolData:
    .dw @vol0
    .dw @vol1
    .dw @vol2
    .dw @vol3
    .dw @vol4
    .dw @vol5
    .dw @vol6
    .dw @vol7
    .dw @vol8

@vol0:
    .db $12 $12 $14, $0f $0e $0d $0c $0b $0a $0a $09 $09 $08 $07 $06 $06 $05 $04 $04 $03 $02 $01 $01
@vol1:
    .db $ff $ff $20, $01 $01 $01 $02 $02 $02 $02 $02 $02 $02 $03 $03 $03 $03 $03 $04 $04 $04 $05 $05 $06 $06 $07 $07 $08 $09 $0a $0b $0c $0d $0e $0f
@vol2:
    .db $02 $02 $04, $0f $0e $0e $0e
@vol3:
    .db $21 $21 $22, $0f $0e $0d $0c $0b $0a $0a $09 $09 $08 $08 $07 $07 $07 $06 $06 $05 $05 $05 $04 $04 $04 $03 $03 $03 $03 $03 $02 $02 $02 $02 $02 $02 $01
@vol4:
@vol5:
    .db $04 $05 $11, $0f $0d $0c $0a $0a $0a $08 $07 $05 $04 $02 $01 $01 $06 $03 $02 $01
@vol6:
    .db $08 $ff $0e, $03 $04 $05 $07 $08 $0b $0c $0d $0f $0c $08 $09 $0d $e
@vol7:
    .db $ff $ff $01, $0e
@vol8:
    .db $00 $01 $04, $0f $0f $00 $00


instrumentArpData:
    .dw @arp0
    .dw @arp1
    .dw @arp2
    .dw @arp3

@arp0:
    .db $00 $ff $08, $00 $00 $40 $40 $80 $80 $0c $0c
@arp1:
    .db $02 $ff $04, $00 $02 $03 $04
@arp2:
    .db $ff $ff $03, $2d $28 $21
@arp3:
    .db $ff $ff $02, $f4 $00


instrumentPitch:
    .dw @pitch0
    .dw @pitch1
    .dw @pitch2
    .dw @pitch3
    .dw @pitch4
    .dw @pitch5
    .dw @pitch6
    .dw @pitch7
    .dw @pitch8
    .dw @pitch9

@pitch0:
@pitch1:
    .db $00 $ff $10, $02 $01 $01 $00 $00 $ff $ff $fe $fe $ff $ff $00 $00 $01 $01 $02
@pitch2:
    .db $01 $00 $0b, $00 $02 $01 $01 $fe $fe $ff $fe $ff $02 $02
@pitch3:
    .db $00 $ff $01, $14
@pitch4:
    .db $01 $01 $0d, $00 $fd $fe $ff $01 $02 $03 $03 $02 $01 $ff $fe $fd
@pitch5:
    .db $00 $ff $01, $10
@pitch6:
    .db $01 $00 $0b, $00 $fe $fe $01 $01 $02 $02 $02 $ff $ff $fe
@pitch7:
    .db $00 $00 $01, $00
@pitch8:
@pitch9:
    .db $10 $ff $19, $0a $ff $00 $ff $00 $ff $00 $ff $00 $ff $ff $ff $ff $00 $00 $02 $01 $01 $fe $fe $ff $fe $ff $02 $02


instrumentDutyNoise:
    .dw @dt0
    .dw @dt1
    .dw @dt2
    .dw @dt3
    .dw @dt4
    .dw @dt5
    .dw @dt6
    .dw @dt7

@dt0:
    .db $04 $04 $08, $01 $00 $00 $00 $00 $00 $00 $00
@dt1:
    .db $00 $ff $0c, $00 $00 $00 $01 $01 $01 $02 $02 $02 $01 $01 $01
@dt2:
    .db $04 $04 $08, $00 $01 $01 $01 $01 $01 $01 $01
@dt3:
    .db $04 $04 $08, $01 $02 $02 $02 $02 $02 $02 $02
@dt4:
    .db $00 $ff $08, $01 $01 $01 $01 $00 $00 $00 $00
@dt5:
    .db $ff $ff $02, $01 $00
@dt6:
    .db $00 $ff $10, $02 $02 $02 $02 $01 $01 $01 $01 $00 $00 $00 $00 $01 $01 $01 $01
@dt7:
    .db $00 $ff $04, $02 $02 $02 $02