;
;  spritedemo
;
;  Created by Quinn Dunki on 7/19/16
;  Copyright (c) 2015 One Girl, One Laptop Productions. All rights reserved.
;


.org $6000

.include "macros.s"

; Softswitches
TEXT = $c050
HIRES1 = $c057
HIRES2 = $c058


; ROM entry points
COUT = $fded
ROMWAIT = $fca8

; Zero page locations we use (unused by Monitor, Applesoft, or ProDOS)
PARAM0			= $06
PARAM1			= $07
PARAM2			= $08
PARAM3			= $09
SCRATCH0		= $19
SCRATCH1		= $1a

; Macros
.macro BLITBYTE xPos,yPos,addr
	lda #xPos
	sta PARAM0
	lda #yPos
	sta PARAM1
	lda #<addr
	sta PARAM2
	lda #>addr
	sta PARAM3
	jsr BlitSpriteOnByte
.endmacro

.macro BLIT xPos,yPos,addr
	lda #xPos
	sta PARAM0
	lda #yPos
	sta PARAM1
	lda #<addr
	sta PARAM2
	lda #>addr
	sta PARAM3
	jsr BlitSprite
.endmacro


.macro WAIT
	lda #$80
	jsr $fca8
.endmacro



main:
	jsr EnableHires

	lda #$00
	jsr LinearFill

	ldx #0
loop:
	txa
	asl
	asl
	sta PARAM0
	lda #0
	sta PARAM1
	lda #<BOX_MAG_SHIFT0
	sta PARAM2
	lda #>BOX_MAG_SHIFT0
	sta PARAM3
	jsr BlitSprite

	lda #88
	sta PARAM1
	lda #<BOX_GRN_SHIFT0
	sta PARAM2
	lda #>BOX_GRN_SHIFT0
	sta PARAM3
	jsr BlitSprite

	lda #96
	sta PARAM1
	lda #<BOX_BLU_SHIFT0
	sta PARAM2
	lda #>BOX_BLU_SHIFT0
	sta PARAM3
	jsr BlitSprite

	lda #184
	sta PARAM1
	lda #<BOX_ORG_SHIFT0
	sta PARAM2
	lda #>BOX_ORG_SHIFT0
	sta PARAM3
	jsr BlitSprite

	inx
	cpx #35
	bne loop

	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BlitSprite
; Trashes everything, including parameters
; PARAM0: X Pos
; PARAM1: Y Pos
; PARAM2: Sprite Ptr LSB
; PARAM3: Sprite Ptr MSB
;
BlitSprite:
	SAVE_AXY

	clc						; Compute sprite data base  2
	ldx PARAM0					; 3
	lda HGRROWBYTES_BITSHIFT,x	; 4
	adc PARAM2					; 3
	sta PARAM2					; 3
	lda #0						; 2
	adc PARAM3					; 3
	sta PARAM3					; 3

	lda #7						; 2
	sta SCRATCH0			; Tracks row index	3

	asl						; Multiply by byte width	2
	asl											;		2
	sta SCRATCH1			; Tracks total bytes	3
	ldy #0										; 2
					; 37 cycles overhead

blitSprite_Yloop:
	clc						; Calculate Y line on screen   2
	lda SCRATCH0				; 3
	adc	PARAM1					; 3
	tax							; 2

	lda HGRROWS_H,x			; Compute hires row     4
	sta blitSprite_smc+2	; Self-modifying code	4
	sta blitSprite_smc+5					;      4
	lda HGRROWS_L,x							; 4
	sta blitSprite_smc+1					; 4
	sta blitSprite_smc+4					; 4

	ldx PARAM0				; Compute hires horizontal byte  3
	lda HGRROWBYTES,x						; 4
	tax										; 2

blitSprite_Xloop:
	lda (PARAM2),y					; 5

blitSprite_smc:
	ora $2000,x
	sta $2000,x						; 5
	inx								; 2
	iny								; 2
	tya						; End of row?  2
	and #$03				; If last two bits are zero, we've wrapped a row  2
	bne blitSprite_Xloop			; 2

	dec SCRATCH0					; 5
	bpl blitSprite_Yloop			; 3
							; 71 cycles per row
	RESTORE_AXY
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BlitSpriteOnByte
; Trashes everything
; PARAM0: X Byte
; PARAM1: Y Pos
; PARAM2: Sprite Ptr MSB
; PARAM3: Sprite Ptr LSB
;
BlitSpriteOnByte:
	ldy #7

blitSpriteOnByte_loop:
	clc
	tya
	adc	PARAM1	; Calculate Y line
	tax

	lda HGRROWS_H,x			; Compute hires row
	sta blitSpriteOnByte_smc+2
	lda HGRROWS_L,x
	sta blitSpriteOnByte_smc+1

	ldx PARAM0				; Compute hires column
	lda (PARAM2),y

blitSpriteOnByte_smc:
	sta $2000,x
	dey
	bpl blitSpriteOnByte_loop
	rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; EnableHires
; Trashes A
;
EnableHires:
	lda TEXT
	lda HIRES1
	lda HIRES2
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LinearFill
; A: Byte value to fill
; Trashes all registers
;
LinearFill:
	ldx #0

linearFill_outer:
	pha
	lda HGRROWS_H,x
	sta linearFill_inner+2
	lda HGRROWS_L,x
	sta linearFill_inner+1
	pla

	ldy #39
linearFill_inner:
	sta $2000,y
	dey
	bpl linearFill_inner

	inx
	cpx #192
	bne linearFill_outer
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VenetianFill
; A: Byte value to fill
; Trashes all registers
;
VenetianFill:
	ldx #$3f
venetianFill_outer:
	stx venetianFill_inner+2
	ldy #$00
venetianFill_inner:
	sta $2000,y		; Upper byte of address is self-modified
	iny
	bne venetianFill_inner
	dex
	cpx #$1f
	bne venetianFill_outer
	rts


.include "hgrtableX.s"
.include "hgrtableY.s"
.include "spritegen0.s"
.include "spritegen1.s"
.include "spritegen2.s"
.include "spritegen3.s"

; Suppress some linker warnings - Must be the last thing in the file
.SEGMENT "ZPSAVE"
.SEGMENT "EXEHDR"
.SEGMENT "STARTUP"
.SEGMENT "INIT"
.SEGMENT "LOWCODE"
