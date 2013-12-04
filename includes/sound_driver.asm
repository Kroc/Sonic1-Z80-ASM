;Sonic 1 Master System Sound Driver
 ;disassembled by ValleyBell and formatted by Kroc Camen
;======================================================================================

.STRUCT TRACK
	channelFrequencyPSG	db
	channelVolumePSG	db
	tickStep		dw
	fadeTicks		dw
	noteFrequencey		dw
	detune			dw
	modulationFreq		dw
	envelopeLevel		db
	adsrState		db
	attackRate		db
	decay1Rate		db
	decay1Level		db
	decay2Rate		db
	decay2Level		db
	sustainRate		db
	initModulationDelay	dw
	initModulationStepDelay	db
	initModulationStepCount	db
	initModulationFreqDelta	dw
	modulationStepDelay	db
	modulationStepCount	db
	modulationFreqDelta	dw
	effectiveVolume		db
	octave			db
	loopAddress		dw
	masterLoopAddress	dw
	defaultNoteLength	db
	noiseMode		db
	tempoDivider		dw
	flags			db
	baseAddress		dw
	id			db
	channelVolume		db
.ENDST

;define the variables in RAM:
;--------------------------------------------------------------------------------------
.ENUM $DC04
	playbackMode		db	;bit 3 dis/enables fading out
	overriddenTrack		db	;which music track the SFX is overriding
	SFXPriority		db	;priority level of current SFX
	noiseMode		db	;high/med/low noise mode and frequency mode
	tickMultiplier		dw
	tickDivider1		dw
	tickDivider2		dw
	tickDividerSFX		dw
	fadeTicks		dw
	fadeTicksDecrement	dw
	
	channel0TrackPointer	dw
	channel1TrackPointer	dw
	channel2TrackPointer	dw
	channel3TrackPointer	dw
	
	track0DataPointer	dw
	track1DataPointer	dw
	track2DataPointer	dw
	track3DataPointer	dw
	track4DataPointer	dw
	
	track0vars		INSTANCEOF TRACK
	track1vars		INSTANCEOF TRACK
	track2vars		INSTANCEOF TRACK
	track3vars		INSTANCEOF TRACK
	track4vars		INSTANCEOF TRACK
	
	loopStack		db
.ENDE

;--------------------------------------------------------------------------------------

;this is the public interface that passes forward to the internal implementation;
 ;this style of implementation is unique to the sound driver -- perhaps it's reused
 ;in other Ancient games, or it could be a 3rd-party piece of code

sound_update	jp      _update
sound_loadMusic jp      _loadMusic	;this public call is not used in the game
sound_stop	jp      _stop
sound_unpause	jp      _unpause
sound_fadeOut	jp      _fadeOut
sound_loadSFX 	jp      _loadSFX	;this public call is not used in the game
sound_playMusic jp      _playMusic
sound_playSFX	jp      _playSFX

;--------------------------------------------------------------------------------------

_loadMusic:
;HL : An address from a look up table, e.g. $64C3
	push    af
	push    bc
	push    de
	push    hl
	push    ix
	
	;copy HL to BC
	ld      c,l
	ld      b,h
	
	ld      ix,track0DataPointer
	ld      a,5
	
-	;load the 16-bit value from the parameter address into DE
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ex      de,hl			;swap DE into HL
	add     hl,bc			;add the value to the initial address
	
	;copy the new address to RAM at track0DataPointer/D+
	ld      (ix+$00),l
	inc     ix
	ld      (ix+$00),h
	inc     ix
	ex      de,hl
	
	;repeat this process five times
	dec     a
	jp      nz,-
	
	;$64C3 + $1110 = $75D3
	;$64C3 + $2025 = $84E8
	;$64C3 + $3F3D = $A400
	;$64C3 + $393D = $9E00
	;$64C3 + $0024 = $64E7
	
	ld      hl,initTrackValues1

-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      a,d
	inc     a
	jr      z,+
	inc     hl
	ldi     
	ldi     
	jp      -
	
+	ld      hl,initTrackValues2
-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      a,d
	inc     a
	jr      z,+
	inc     hl
	ldi     
	jp      -
	
+	pop     ix
	pop     hl
	pop     de
	pop     bc
	pop     af
	ld      ($dc4f),hl
	ld      ($dc7c),hl
	ld      ($dca9),hl
	ld      ($dcd6),hl
	ret

initTrackValues1:
.dw $DC48, $0000
.dw $DC75, $0000
.dw $DCA2, $0000
.dw $DCCF, $0000
.dw $DC46, loopStack+0
.dw $DC73, loopStack+1
.dw $DCA0, loopStack+2
.dw $DCCD, loopStack+3
.dw $DC28, $0001
.dw $DC55, $0001
.dw $DC82, $0001
.dw $DCAF, $0001
.dw $DC3D, $0000
.dw $DC42, $0000
.dw $DC6A, $0000
.dw $DC6F, $0000
.dw $DC97, $0000
.dw $DC9C, $0000
.dw $DCC4, $0000
.dw $DCC9, $0000
.dw $DC2E, $0000
.dw $DC5B, $0000
.dw $DC88, $0000
.dw $DCB5, $0000
.dw tickDivider1, $0001
.dw $FFFF

initTrackValues2:
.db $26, $DC, $80
.db $27, $DC, $90
.db $53, $DC, $A0
.db $54, $DC, $B0
.db $80, $DC, $C0
.db $81, $DC, $D0
.db $AD, $DC, $E0
.db $AE, $DC, $F0
.db $4E, $DC, $02
.db $7B, $DC, $02
.db $A8, $DC, $02
.db $D5, $DC, $02
.db $02, $DD, $00
.db $3A, $DC, $00
.db $67, $DC, $00
.db $94, $DC, $00
.db $C1, $DC, $00
.db $3B, $DC, $00
.db $68, $DC, $00
.db $95, $DC, $00
.db $C2, $DC, $00
.db $51, $DC, $00
.db $7E, $DC, $01
.db $AB, $DC, $02
.db $D8, $DC, $03
.db $06, $DC, $00
.db $04, $DC, $00
.dw $FFFF

;____________________________________________________________________($4129)_[$C129]___

initPSGValues:
;    +xx+yyyy	;set channel xx volume to yyyy (0000 is max, 1111 is off)
.db %10011111	;mute channel 0
.db %10111111	;mute channel 1
.db %11011111	;mute channel 2
.db %11111111	;mute channel 3

_stop:					;($412D) [$C12D]			
	;put any current values for these registers aside
	push    af
	push    hl
	push    bc
	
	ld      a,($dc4e)
	and     %11111101
	ld      ($dc4e),a
	
	ld      a,($dc7b)
	and     %11111101
	ld      ($dc7b),a
	
	ld      a,($dca8)
	and     %11111101
	ld      ($dca8),a
	
	ld      a,($dcd5)
	and     %11111101
	ld      ($dcd5),a
	
	ld      a,($dd02)
	and     %11111101
	ld      ($dd02),a
	
	xor     a
	ld      (SFXPriority),a
	
	;mute all sound channels by sending the right bytes to the sound chip
	ld      b,4
	ld      c,SMS_SOUND_PORT
	ld      hl,initPSGValues
	otir
	
	ld      a,(playbackMode)
	and     %11110111
	ld      (playbackMode),a
	
	;restore the previous state of the registers and return
	pop     bc
	pop     hl
	pop     af
	ret
	
;--------------------------------------------------------------------------------------
_loadSFX:
	push    af
	push    de
	push    hl
	ld      e,a
	ld      a,(SFXPriority)
	and     a
	jr      z,+
	cp      e
	jr      c,++
+	ld      a,e
	ld      (SFXPriority),a
	ld      ($dd03),hl
	ld      a,($dcdb)
	or      %00001111
	out     (SMS_SOUND_PORT),a
	ld      a,(hl)
	ld      (overriddenTrack),a
	inc     hl
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      ($dd00),de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (tickDividerSFX),de
	inc     hl
	ld      (track4DataPointer),hl
	ld      hl,_c1dd
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      a,(hl)
	ld      (track4vars),a
	inc     hl
	ld      a,(hl)
	ld      ($dcdb),a
	ld      hl,$0000
	ld      ($dcfc),hl
	ld      ($dcf1),hl
	ld      ($dcf6),hl
	ld      ($dce2),hl
	ld      a,$04
	ld      ($dd05),a
	inc     hl
	ld      ($dcdc),hl
	ld      hl,$dd0b
	ld      ($dcfa),hl
	ld      a,$02
	ld      ($dd02),a
++	pop     hl
	pop     de
	pop     af
	ret

_c1dd:
.db $80, $90, $a0, $b0, $c0, $d0, $e0, $f0

;--------------------------------------------------------------------------------------

_unpause:
	push    af
	ld      a,($dc4e)
	or      $02
	ld      ($dc4e),a
	ld      a,($dc7b)
	or      $02
	ld      ($dc7b),a
	ld      a,($dca8)
	or      $02
	ld      ($dca8),a
	ld      a,($dcd5)
	or      $02
	ld      ($dcd5),a
	ld      a,($dc52)
	ld      ($dc2b),a
	ld      a,($dc7f)
	ld      ($dc58),a
	ld      a,($dcac)
	ld      ($dc85),a
	ld      a,($dcd9)
	ld      ($dcb2),a
	xor     a
	ld      (playbackMode),a
	pop     af
	ret

;--------------------------------------------------------------------------------------

_fadeOut:
	push    af
	push    hl
	ld      (fadeTicksDecrement),hl
	ld      a,(playbackMode)
	or      $08
	ld      (playbackMode),a
	ld      hl,$1000
	ld      (fadeTicks),hl
	pop     hl
	pop     af
	ret

;____________________________________________________________________($423A)_[$C23A]___

_update:
	;track 1
	ld      ix,track0vars
	ld      de,(track0DataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel0TrackPointer),ix
	ld      (track0DataPointer),de
	
	;track 2
	ld      ix,track1vars
	ld      de,(track1DataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel1TrackPointer),ix
	ld      (track1DataPointer),de
	
	;track 3
	ld      ix,track2vars
	ld      de,(track2DataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel2TrackPointer),ix
	ld      (track2DataPointer),de
	
	;track 4
	ld      ix,track3vars
	ld      de,(track3DataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel3TrackPointer),ix
	ld      (track3DataPointer),de
	
	;SFX track
	ld      ix,track4vars
	ld      de,(track4DataPointer)
	ld      bc,(tickDividerSFX)
	call    _c2f4
	ld      (track4DataPointer),de
	bit     1,(ix+$28)
	jr      z,_c2bf
	
	ld      hl,channel0TrackPointer
	ld      a,(overriddenTrack)
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      (hl),$da
	inc     hl
	ld      (hl),$dc
_c2bf:
	ld      ix,(channel0TrackPointer)
	call    _c3de
	ld      ix,(channel1TrackPointer)
	call    _c3de
	ld      ix,(channel2TrackPointer)
	call    _c3de
	ld      ix,(channel3TrackPointer)
	call    _c3de
	
	ld      a,(playbackMode)
	and     $08
	ret     z
	
	ld      hl,(fadeTicks)
	ld      bc,(fadeTicksDecrement)
	and     a
	sbc     hl,bc
	jr      nc,_c2f0
	
	;stop all sound
	call    _stop
_c2f0:
	ld      (fadeTicks),hl
	ret

;____________________________________________________________________($42F4)_[$C2F4]___

_c2f4:
	bit     1,(ix+$28)
	ret     z
	
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	and     a
	sbc     hl,bc
	ld      (ix+$02),l
	ld      (ix+$03),h
	jr      z,_c30d
	jp      nc,_c3c9
_c30d:
	ld      a,(de)
	and     a
	jp      m,_c4f3
	cp      $70
	jr      c,_c34b
	cp      $7f
	jr      nz,_c321
	ld      (ix+$1e),$00
	jp      _c39f
_c321:
	push    de
	push    ix
	pop     hl
	ld      bc,$000e
	add     hl,bc
	ex      de,hl
	and     $0f
	ld      l,a
	ld      h,$00
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      bc,_c3ce
	add     hl,bc
	ld      a,(hl)
	ld      (ix+$25),a
	inc     hl
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	pop     de
	jp      _c36e
_c34b:
	and     $0f
	ld      hl,_c4d5
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      a,(hl)
	ld      (ix+$06),a
	inc     hl
	ld      a,(hl)
	ld      (ix+$07),a
	ld      a,(de)
	rrca    
	rrca    
	rrca    
	rrca    
	and     $0f
	ld      (ix+$1f),a
	bit     0,(ix+$28)
	jr      nz,_c39f
_c36e:
	ld      a,(ix+$14)
	ld      (ix+$19),a
	ld      a,(ix+$15)
	ld      (ix+$1a),a
	ld      a,(ix+$16)
	srl     a
	ld      (ix+$1b),a
	ld      a,(ix+$17)
	ld      (ix+$1c),a
	ld      a,(ix+$18)
	ld      (ix+$1d),a
	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0d),a
	ld      (ix+$0c),a
	ld      (ix+$1e),$0f
_c39f:
	inc     de
	ld      a,(de)
	inc     de
	and     a
	jr      nz,_c3a8
	ld      a,(ix+$24)
_c3a8:
	push    de
	ld      c,a
	ld      l,(ix+$26)
	ld      h,(ix+$27)
	ld      a,l
	or      h
	jr      nz,_c3b7
	ld      hl,(tickMultiplier)
_c3b7:
	call    _c6d8
	pop     de
	ld      a,l
	add     a,(ix+$02)
	ld      (ix+$02),a
	ld      a,h
	adc     a,(ix+$03)
	ld      (ix+$03),a
_c3c9:
	res     0,(ix+$28)
	ret

_c3ce:
.db $05, $ff, $be, $0a, $04, $05, $02, $00, $05, $e6, $24, $5a, $14, $28, $08, $00

_c3de:
	bit     1,(ix+$28)
	ret     z
	ld      a,(ix+$0d)
	and     a
	jp      z,_c545

.db $3d, $ca, $5c, $45, $3d, $ca, $79, $45, $3d, $ca, $97, $45

_c3f6:
	ld      a,(ix+$00)
	cp      $e0
	jr      nz,_c412
	ld      c,(ix+$25)
	ld      a,(noiseMode)
	cp      c
	jp      z,_c48f
	ld      a,c
	ld      (noiseMode),a
	or      %11100000		;noise channel frequency?
	out     (SMS_SOUND_PORT),a
	jp      _c48f
_c412:
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	ld      a,(ix+$19)
	and     a
	jr      z,_c424
	dec     (ix+$19)
	jp      _c45a
_c424:
	dec     (ix+$1a)
	jp      nz,_c45a
	ld      a,(ix+$15)
	ld      (ix+$1a),a
	ld      l,(ix+$1c)
	ld      h,(ix+$1d)
	dec     (ix+$1b)
	jp      nz,_c452
	ld      a,(ix+$16)
	ld      (ix+$1b),a
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      (ix+$1c),l
	ld      (ix+$1d),h
	jp      _c45a
_c452:
	add     hl,de
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ex      de,hl
_c45a:
	ld      l,(ix+$06)
	ld      h,(ix+$07)
	ld      c,(ix+$08)
	ld      b,(ix+$09)
	add     hl,bc
	add     hl,de
	ld      a,(ix+$1f)
	and     a
	jr      z,_c475
	ld      b,a
_c46f:
	srl     h
_c471:
	rr      l
	djnz    _c46f
_c475:
	ld      a,l
	and     %00001111
	or      (ix+$00)
	out     (SMS_SOUND_PORT),a
	ld      a,h
	rlca    
	rlca    
	rlca    
	rlca    
	and     %11110000
	ld      c,a
	ld      a,l
	rrca    
	rrca    
	rrca    
	rrca    
	and     %00001111
	or      c
	out     (SMS_SOUND_PORT),a
_c48f:
	ld      a,(ix+$05)
	and     a
	jr      z,_c4a7
	ld      c,a
	ld      a,(ix+$0c)
	and     a
	jr      z,_c4a7
	ld      l,a
	ld      h,$00
	call    _c6d8
	rl      l
	ld      a,$00
	adc     a,h
_c4a7:
	and     (ix+$1e)
	xor     %00001111
	or      (ix+$01)
	out     (SMS_SOUND_PORT),a
	ld      a,(playbackMode)
	and     $08
	ret     z
	ld      a,(ix+$2b)
	cp      $04
	ret     z
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      bc,(fadeTicksDecrement)
	sbc     hl,bc
	jr      nc,_c4ce
	ld      hl,$0000
_c4ce:
	ld      (ix+$04),l
	ld      (ix+$05),h
	ret

_c4d5:
.db $56, $03, $26, $03, $f9, $02, $ce, $02, $a5, $02, $80, $02, $5c, $02, $3a, $02
.db $1a, $02, $fb, $01, $df, $01, $c4, $01, $f7, $03, $be, $03, $88, $03

_c4f3:
	cp      $ff
	jp      z,_c50b
	cp      $fe
	jp      z,_c519
	inc     de
	ld      hl,_c529
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	jp      (hl)
_c50b:
	ld      l,(ix+$22)
	ld      h,(ix+$23)
	ld      a,l
	or      h
	jr      z,_c51d
	ex      de,hl
	jp      _c30d
_c519:
	xor     a
	ld      (SFXPriority),a
_c51d:
	res     1,(ix+$28)
	ld      a,%00001111
	or      (ix+$01)
	out     (SMS_SOUND_PORT),a
	ret

_c529:
.dw _c5ae, _c5d1, _c5f2, _c60a, _c620, _c62d, _c632, _c647
.dw _c67d, _c686, _c68e, _c696, _c6b4, _c6d1

_c545:
	ld      a,(ix+$0e)
	add     a,(ix+$0c)
	jp      nc,_c550
	ld      a,$ff
_c550:
	ld      (ix+$0c),a
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6
_c55c:
	ld      c,(ix+$10)
	ld      a,(ix+$0c)
	sub     (ix+$0f)
	jr      c,_c56d
	cp      (ix+$10)
	jr      c,_c56d
	ld      c,a
_c56d:
	ld      (ix+$0c),c
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6
_c579:
	ld      c,(ix+$12)
	ld      a,(ix+$0c)
	sub     (ix+$11)
	jr      c,_c58b
	cp      (ix+$12)
	jp      c,_c58b
	ld      c,a
_c58b:
	ld      (ix+$0c),c
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6
_c597:
	ld      a,(ix+$0c)
	sub     (ix+$13)
	jp      nc,_c5a2
	ld      a,$00
_c5a2:
	ld      (ix+$0c),a
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6

_c5ae:
	ld      a,(de)
	ld      (ix+$26),a
	ld      (tickMultiplier),a
	inc     de
	ld      a,(de)
	ld      (ix+$27),a
	ld      ($dc09),a
	inc     de
	ld      a,(de)
	ld      (tickDivider1),a
	ld      (tickDivider2),a
	inc     de
	ld      a,(de)
	ld      ($dc0b),a
	ld      ($dc0d),a
	inc     de
	jp      _c30d
_c5d1:
	ld      a,(de)
	ld      (ix+$2c),a
	inc     de
	ld      a,(ix+$2b)
	cp      $04
	jr      z,_c5e5
	ld      a,(playbackMode)
	and     $08
	jp      nz,_c30d
_c5e5:
	ld      a,(ix+$2c)
	ld      (ix+$05),a
	ld      (ix+$04),$00
	jp      _c30d
	
_c5f2:
	push    ix
	pop     hl
	ld      bc,$000e
	add     hl,bc
	ex      de,hl
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ex      de,hl
	jp      _c30d
_c60a:
	push    ix
	pop     hl
	ld      bc,$0014
	add     hl,bc
	ex      de,hl
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ex      de,hl
	jp      _c30d
_c620:
	ld      a,(de)
	ld      (ix+$08),a
	inc     de
	ld      a,(de)
	ld      (ix+$09),a
	inc     de
	jp      _c30d
_c62d:
	ld      a,(de)
	inc     de
	jp      _c30d
_c632:
	ld      l,(ix+$20)
	ld      h,(ix+$21)
	ld      (hl),$00
	ld      bc,$0005
	add     hl,bc
	ld      (ix+$20),l
	ld      (ix+$21),h
	jp      _c30d
_c647:
	ld      l,(ix+$20)
	ld      h,(ix+$21)
	ld      bc,$fffb
	add     hl,bc
	ld      a,(hl)
	and     a
	jr      nz,_c65d
	ld      a,(de)
	dec     a
	jr      z,_c671
	ld      (hl),a
	jp      _c660
_c65d:
	dec     (hl)
	jr      z,_c671
_c660:
	ex      de,hl
	inc     hl
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      c,(ix+$29)
	ld      b,(ix+$2a)
	add     hl,bc
	ex      de,hl
	jp      _c30d
_c671:
	ld      (ix+$20),l
	ld      (ix+$21),h
	inc     de
	inc     de
	inc     de
	jp      _c30d
_c67d:
	ld      (ix+$22),e
	ld      (ix+$23),d
	jp      _c30d
_c686:
	ld      a,(de)
	ld      (ix+$25),a
	inc     de
	jp      _c30d
_c68e:
	ld      a,(de)
	ld      (ix+$24),a
	inc     de
	jp      _c30d
_c696:
	ld      a,(ix+$2c)
	inc     a
	cp      $10
	jr      c,_c6a0
	ld      a,$0f
_c6a0:
	ld      (ix+$2c),a
	ld      a,(playbackMode)
	and     $08
	jp      nz,_c30d
	ld      a,(ix+$2c)
	ld      (ix+$05),a
	jp      _c30d
_c6b4:
	ld      a,(ix+$2c)
	dec     a
	cp      $10
	jr      c,_c6bd
	xor     a
_c6bd:
	ld      (ix+$2c),a
	ld      a,(playbackMode)
	and     $08
	jp      nz,_c30d
	ld      a,(ix+$2c)
	ld      (ix+$05),a
	jp      _c30d
_c6d1:
	set     0,(ix+$28)
	jp      _c30d
_c6d8:
	xor     a
	ld      b,$07
	ex      de,hl
	ld      l,a
	ld      h,a
_c6de:
	rl      c
	jp      nc,_c6e4
	add     hl,de
_c6e4:
	add     hl,hl
	djnz    _c6de
	or      c
	ret     z
	add     hl,de
	ret

;______________________________________________________________________________________

_playMusic:
	push    hl
	ld      hl,S1_MusicPointers
	
	add     a,a
	add     a,l
	ld      l,a
	ld      a,$00
	adc     a,h
	ld      h,a
	
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	call    _loadMusic
	
	pop     hl
	ret

;______________________________________________________________________________________

_playSFX:
	push    hl
	push    de
	ld      hl,S1_SFXPointers
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      a,(hl)
	ex      de,hl
	call    _loadSFX
	pop     de
	pop     hl
	ret