;Sonic 1 Master System Sound Driver
 ;disassembled by ValleyBell and formatted by Kroc Camen
;======================================================================================

.STRUCT TRACK
	channelFrequencyPSG	db	;+$00
	channelVolumePSG	db	;+$01
	tickStep		dw	;+$02
	fadeTicks		dw	;+$04
	noteFrequencey		dw	;+$06 - can't find direct reference
	detune			dw	;+$08
	modulationFreq		dw	;+$0A
	envelopeLevel		db	;+$0C
	ADSRstate		db	;+$0D
	attackRate		db	;+$0E
	decay1Rate		db	;+$0F
	decay1Level		db	;+$10
	decay2Rate		db	;+$11
	decay2Level		db	;+$12
	sustainRate		db	;+$13
	initModulationDelay	db	;+$14
	initModulationStepDelay	db	;+$15
	initModulationStepCount	db	;+$16
	initModulationFreqDelta	dw	;+$17
	modulationDelay		db	;+$19
	modulationStepDelay	db	;+$1A
	modulationStepCount	db	;+$1B
	modulationFreqDelta	dw	;+$1C
	effectiveVolume		db	;+$1E
	octave			db	;+$1F
	loopAddress		dw	;+$20
	masterLoopAddress	dw	;+$22
	defaultNoteLength	db	;+$24
	noiseMode		db	;+$25
	tempoDivider		dw	;+$26
	flags			db	;+$28
	baseAddress		dw	;+$29
	id			db	;+$2B
	channelVolume		db	;+$2C
.ENDST

;define the variables in RAM:
;--------------------------------------------------------------------------------------
.ENUM $DC04
	playbackMode		db	;bit 3 dis/enables fading out
	overriddenTrack		db	;which music track the SFX is overriding
	SFXpriority		db	;priority level of current SFX
	noiseMode		db	;high/med/low noise mode and frequency mode
	tickMultiplier		dw	
	tickDivider1		dw	
	tickDivider2		dw	
	tickDividerSFX		dw	
	fadeTicks		dw	
	fadeTicksDecrement	dw	
	
	channel0trackPointer	dw	
	channel1trackPointer	dw	
	channel2trackPointer	dw	
	channel3trackPointer	dw	
	
	track0dataPointer	dw	
	track1dataPointer	dw	
	track2dataPointer	dw	
	track3dataPointer	dw	
	track4dataPointer	dw	
	
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
	
	ld      c,l
	ld      b,h
	
	ld      ix,track0dataPointer
	ld      a,5
	
-	;load the 16-bit value from the parameter address into DE
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ex      de,hl			
	add     hl,bc			
	
	ld      (ix+TRACK.channelFrequencyPSG),l
	inc     ix
	ld      (ix+TRACK.channelFrequencyPSG),h
	inc     ix
	ex      de,hl
	
	dec     a
	jp      nz,-
	
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
	ld      (track0vars.baseAddress),hl
	ld      (track1vars.baseAddress),hl
	ld      (track2vars.baseAddress),hl
	ld      (track3vars.baseAddress),hl
	ret

;______________________________________________________________________________________

initTrackValues1:
.dw track0vars.masterLoopAddress, $0000
.dw track1vars.masterLoopAddress, $0000
.dw track2vars.masterLoopAddress, $0000
.dw track3vars.masterLoopAddress, $0000

.dw track0vars.loopAddress, loopStack+0
.dw track1vars.loopAddress, loopStack+1
.dw track2vars.loopAddress, loopStack+2
.dw track3vars.loopAddress, loopStack+3

.dw track0vars.tickStep, $0001
.dw track1vars.tickStep, $0001
.dw track2vars.tickStep, $0001
.dw track3vars.tickStep, $0001

.dw track0vars.initModulationFreqDelta, $0000
.dw track0vars.modulationFreqDelta, 	$0000
.dw track1vars.initModulationFreqDelta, $0000
.dw track1vars.modulationFreqDelta, 	$0000
.dw track2vars.initModulationFreqDelta, $0000
.dw track2vars.modulationFreqDelta, 	$0000
.dw track3vars.initModulationFreqDelta, $0000
.dw track3vars.modulationFreqDelta, 	$0000

.dw track0vars.detune, $0000
.dw track1vars.detune, $0000
.dw track2vars.detune, $0000
.dw track3vars.detune, $0000

.dw tickDivider1, $0001
.dw $FFFF

initTrackValues2:
.dw track0vars.channelFrequencyPSG
.db $80
.dw track0vars.channelVolumePSG
.db $90
.dw track1vars.channelFrequencyPSG
.db $A0
.dw track1vars.channelVolumePSG
.db $B0
.dw track2vars.channelFrequencyPSG
.db $C0
.dw track2vars.channelVolumePSG
.db $D0
.dw track3vars.channelFrequencyPSG
.db $E0
.dw track3vars.channelVolumePSG
.db $F0
.dw track0vars.flags
.db %00000010
.dw track1vars.flags
.db %00000010
.dw track2vars.flags
.db %00000010
.dw track3vars.flags
.db %00000010
.dw track4vars.flags
.db %00000000

;is there a reason this var is not set using the word table above
 ;instead of two separate bytes as is the case here?
.dw track0vars.initModulationDelay+0
.db $00
.dw track1vars.initModulationDelay+0
.db $00
.dw track2vars.initModulationDelay+0
.db $00
.dw track3vars.initModulationDelay+0
.db $00
.dw track0vars.initModulationDelay+1
.db $00
.dw track1vars.initModulationDelay+1
.db $00
.dw track2vars.initModulationDelay+1
.db $00
.dw track3vars.initModulationDelay+1
.db $00
.dw track0vars.id
.db $00
.dw track1vars.id
.db $01
.dw track2vars.id
.db $02
.dw track3vars.id
.db $03
.dw SFXpriority
.db $00
.dw playbackMode
.db $00
.dw $FFFF

initPSGValues:
;    +xx+yyyy	;set channel xx volume to yyyy (0000 is max, 1111 is off)
.db %10011111	;mute channel 0
.db %10111111	;mute channel 1
.db %11011111	;mute channel 2
.db %11111111	;mute channel 3

;______________________________________________________________________________________

_stop:			
	;put any current values for these registers aside
	push    af
	push    hl
	push    bc
	
	ld      a,(track0vars.flags)
	and     %11111101
	ld      (track0vars.flags),a
	
	ld      a,(track1vars.flags)
	and     %11111101
	ld      (track1vars.flags),a
	
	ld      a,(track2vars.flags)
	and     %11111101
	ld      (track2vars.flags),a
	
	ld      a,(track3vars.flags)
	and     %11111101
	ld      (track3vars.flags),a
	
	ld      a,(track4vars.flags)
	and     %11111101
	ld      (track4vars.flags),a
	
	xor     a
	ld      (SFXpriority),a
	
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
	ld      a,(SFXpriority)
	and     a
	jr      z,+
	cp      e
	jr      c,++
+	ld      a,e
	ld      (SFXpriority),a
	ld      (track4vars.baseAddress),hl
	ld      a,(track4vars.channelVolumePSG)
	or      %00001111
	out     (SMS_SOUND_PORT),a
	ld      a,(hl)
	ld      (overriddenTrack),a
	inc     hl
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (track4vars.tempoDivider),de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (tickDividerSFX),de
	inc     hl
	ld      (track4dataPointer),hl
	ld      hl,_c1dd
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      a,(hl)
	ld      (track4vars),a
	inc     hl
	ld      a,(hl)
	ld      (track4vars.channelVolumePSG),a
	ld      hl,$0000
	ld      (track4vars.masterLoopAddress),hl
	ld      (track4vars.initModulationFreqDelta),hl
	ld      (track4vars.modulationFreqDelta),hl
	ld      (track4vars.detune),hl
	ld      a,$04
	ld      (track4vars.id),a
	inc     hl
	ld      (track4vars.tickStep),hl
	ld      hl,loopStack + 4
	ld      (track4vars.loopAddress),hl
	ld      a,$02
	ld      (track4vars.flags),a
++	pop     hl
	pop     de
	pop     af
	ret

_c1dd:
.db $80, $90, $a0, $b0, $c0, $d0, $e0, $f0

;--------------------------------------------------------------------------------------

_unpause:
	push    af
	ld      a,(track0vars.flags)
	or      %00000010
	ld      (track0vars.flags),a
	
	ld      a,(track1vars.flags)
	or      %00000010
	ld      (track1vars.flags),a
	
	ld      a,(track2vars.flags)
	or      %00000010
	ld      (track2vars.flags),a
	
	ld      a,(track3vars.flags)
	or      %00000010
	ld      (track3vars.flags),a
	
	ld      a,(track0vars.channelVolume)
	ld      (track0vars.fadeTicks+1),a
	ld      a,(track1vars.channelVolume)
	ld      (track1vars.fadeTicks+1),a
	ld      a,(track2vars.channelVolume)
	ld      (track2vars.fadeTicks+1),a
	ld      a,(track3vars.channelVolume)
	ld      (track3vars.fadeTicks+1),a
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
	or      %00001000
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
	ld      de,(track0dataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel0trackPointer),ix
	ld      (track0dataPointer),de
	
	;track 2
	ld      ix,track1vars
	ld      de,(track1dataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel1trackPointer),ix
	ld      (track1dataPointer),de
	
	;track 3
	ld      ix,track2vars
	ld      de,(track2dataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel2trackPointer),ix
	ld      (track2dataPointer),de
	
	;track 4
	ld      ix,track3vars
	ld      de,(track3dataPointer)
	ld      bc,(tickDivider1)
	call    _c2f4
	ld      (channel3trackPointer),ix
	ld      (track3dataPointer),de
	
	;SFX track
	ld      ix,track4vars
	ld      de,(track4dataPointer)
	ld      bc,(tickDividerSFX)
	call    _c2f4
	ld      (track4dataPointer),de
	bit     1,(ix+TRACK.flags)
	jr      z,_c2bf
	
	ld      hl,channel0trackPointer
	ld      a,(overriddenTrack)
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      (hl),<track4vars
	inc     hl
	ld      (hl),>track4vars
_c2bf:
	ld      ix,(channel0trackPointer)
	call    _c3de
	ld      ix,(channel1trackPointer)
	call    _c3de
	ld      ix,(channel2trackPointer)
	call    _c3de
	ld      ix,(channel3trackPointer)
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
	bit     1,(ix+TRACK.flags)
	ret     z
	
	ld      l,(ix+TRACK.tickStep+0)
	ld      h,(ix+TRACK.tickStep+1)
	and     a
	sbc     hl,bc
	ld      (ix+TRACK.tickStep+0),l
	ld      (ix+TRACK.tickStep+1),h
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
	ld      (ix+TRACK.effectiveVolume),$00
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
	ld      (ix+TRACK.noiseMode),a
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
	ld      (ix+TRACK.noteFrequencey),a
	inc     hl
	ld      a,(hl)
	ld      (ix+TRACK.noteFrequencey+1),a
	ld      a,(de)
	rrca    
	rrca    
	rrca    
	rrca    
	and     $0f
	ld      (ix+TRACK.octave),a
	bit     0,(ix+TRACK.flags)
	jr      nz,_c39f
_c36e:
	ld      a,(ix+TRACK.initModulationDelay)
	ld      (ix+TRACK.modulationDelay),a
	ld      a,(ix+TRACK.initModulationDelay+1)
	ld      (ix+TRACK.modulationDelay+1),a
	ld      a,(ix+TRACK.initModulationStepCount)
	srl     a
	ld      (ix+TRACK.modulationStepCount),a
	ld      a,(ix+TRACK.initModulationFreqDelta+0)
	ld      (ix+TRACK.modulationFreqDelta+0),a
	ld      a,(ix+TRACK.initModulationFreqDelta+1)
	ld      (ix+TRACK.modulationFreqDelta+1),a
	xor     a
	ld      (ix+TRACK.modulationFreq+0),a
	ld      (ix+TRACK.modulationFreq+1),a
	ld      (ix+TRACK.ADSRstate),a
	ld      (ix+TRACK.envelopeLevel),a
	ld      (ix+TRACK.effectiveVolume),$0f
_c39f:
	inc     de
	ld      a,(de)
	inc     de
	and     a
	jr      nz,_c3a8
	ld      a,(ix+TRACK.defaultNoteLength)
_c3a8:
	push    de
	ld      c,a
	ld      l,(ix+TRACK.tempoDivider+0)
	ld      h,(ix+TRACK.tempoDivider+1)
	ld      a,l
	or      h
	jr      nz,_c3b7
	ld      hl,(tickMultiplier)
_c3b7:
	call    _c6d8
	pop     de
	ld      a,l
	add     a,(ix+TRACK.tickStep+0)
	ld      (ix+TRACK.tickStep+0),a
	ld      a,h
	adc     a,(ix+TRACK.tickStep+1)
	ld      (ix+TRACK.tickStep+1),a
_c3c9:
	res     0,(ix+TRACK.flags)
	ret

_c3ce:
.db $05, $ff, $be, $0a, $04, $05, $02, $00, $05, $e6, $24, $5a, $14, $28, $08, $00

_c3de:
	bit     1,(ix+TRACK.flags)
	ret     z
	ld      a,(ix+TRACK.ADSRstate)
	and     a
	jp      z,_c545

.db $3d, $ca, $5c, $45, $3d, $ca, $79, $45, $3d, $ca, $97, $45

_c3f6:
	ld      a,(ix+TRACK.channelFrequencyPSG)
	cp      $e0
	jr      nz,_c412
	ld      c,(ix+TRACK.noiseMode)
	ld      a,(noiseMode)
	cp      c
	jp      z,_c48f
	ld      a,c
	ld      (noiseMode),a
	or      %11100000		;noise channel frequency?
	out     (SMS_SOUND_PORT),a
	jp      _c48f
_c412:
	ld      e,(ix+TRACK.modulationFreq+0)
	ld      d,(ix+TRACK.modulationFreq+1)
	ld      a,(ix+TRACK.modulationDelay)
	and     a
	jr      z,_c424
	dec     (ix+TRACK.modulationDelay)
	jp      _c45a
_c424:
	dec     (ix+TRACK.modulationStepDelay)
	jp      nz,_c45a
	ld      a,(ix+$15)
	ld      (ix+TRACK.modulationStepDelay),a
	ld      l,(ix+TRACK.modulationFreqDelta+0)
	ld      h,(ix+TRACK.modulationFreqDelta+1)
	dec     (ix+TRACK.modulationStepCount)
	jp      nz,_c452
	ld      a,(ix+TRACK.initModulationStepCount)
	ld      (ix+TRACK.modulationStepCount),a
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      (ix+TRACK.modulationFreqDelta+0),l
	ld      (ix+TRACK.modulationFreqDelta+1),h
	jp      _c45a
_c452:
	add     hl,de
	ld      (ix+TRACK.modulationFreq+0),l
	ld      (ix+TRACK.modulationFreq+1),h
	ex      de,hl
_c45a:
	ld      l,(ix+TRACK.noteFrequencey)
	ld      h,(ix+TRACK.noteFrequencey+1)
	ld      c,(ix+TRACK.detune+0)
	ld      b,(ix+TRACK.detune+1)
	add     hl,bc
	add     hl,de
	ld      a,(ix+TRACK.octave)
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
	or      (ix+TRACK.channelFrequencyPSG)
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
	ld      a,(ix+TRACK.fadeTicks+1)
	and     a
	jr      z,_c4a7
	ld      c,a
	ld      a,(ix+TRACK.envelopeLevel)
	and     a
	jr      z,_c4a7
	ld      l,a
	ld      h,$00
	call    _c6d8
	rl      l
	ld      a,$00
	adc     a,h
_c4a7:
	and     (ix+TRACK.effectiveVolume)
	xor     %00001111
	or      (ix+TRACK.channelVolumePSG)
	out     (SMS_SOUND_PORT),a
	ld      a,(playbackMode)
	and     $08
	ret     z
	ld      a,(ix+TRACK.id)
	cp      $04
	ret     z
	ld      l,(ix+TRACK.fadeTicks+0)
	ld      h,(ix+TRACK.fadeTicks+1)
	ld      bc,(fadeTicksDecrement)
	sbc     hl,bc
	jr      nc,_c4ce
	ld      hl,$0000
_c4ce:
	ld      (ix+TRACK.fadeTicks+0),l
	ld      (ix+TRACK.fadeTicks+1),h
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
	ld      l,(ix+TRACK.masterLoopAddress+0)
	ld      h,(ix+TRACK.masterLoopAddress+1)
	ld      a,l
	or      h
	jr      z,_c51d
	ex      de,hl
	jp      _c30d
_c519:
	xor     a
	ld      (SFXpriority),a
_c51d:
	res     1,(ix+TRACK.flags)
	ld      a,%00001111
	or      (ix+TRACK.channelVolumePSG)
	out     (SMS_SOUND_PORT),a
	ret

_c529:
.dw _c5ae, _c5d1, _c5f2, _c60a, _c620, _c62d, _c632, _c647
.dw _c67d, _c686, _c68e, _c696, _c6b4, _c6d1

_c545:
	ld      a,(ix+TRACK.attackRate)
	add     a,(ix+TRACK.envelopeLevel)
	jp      nc,_c550
	ld      a,$ff
_c550:
	ld      (ix+TRACK.envelopeLevel),a
	jp      nc,_c3f6
	inc     (ix+TRACK.ADSRstate)
	jp      _c3f6
_c55c:
	ld      c,(ix+TRACK.decay1Level)
	ld      a,(ix+TRACK.envelopeLevel)
	sub     (ix+TRACK.decay1Rate)
	jr      c,_c56d
	cp      (ix+TRACK.decay1Level)
	jr      c,_c56d
	ld      c,a
_c56d:
	ld      (ix+TRACK.envelopeLevel),c
	jp      nc,_c3f6
	inc     (ix+TRACK.ADSRstate)
	jp      _c3f6
_c579:
	ld      c,(ix+TRACK.decay2Level)
	ld      a,(ix+TRACK.envelopeLevel)
	sub     (ix+TRACK.decay2Rate)
	jr      c,_c58b
	cp      (ix+TRACK.decay2Level)
	jp      c,_c58b
	ld      c,a
_c58b:
	ld      (ix+TRACK.envelopeLevel),c
	jp      nc,_c3f6
	inc     (ix+TRACK.ADSRstate)
	jp      _c3f6
_c597:
	ld      a,(ix+TRACK.envelopeLevel)
	sub     (ix+TRACK.sustainRate)
	jp      nc,_c5a2
	ld      a,$00
_c5a2:
	ld      (ix+TRACK.envelopeLevel),a
	jp      nc,_c3f6
	inc     (ix+TRACK.ADSRstate)
	jp      _c3f6

_c5ae:
	ld      a,(de)
	ld      (ix+TRACK.tempoDivider+0),a
	ld      (tickMultiplier+0),a
	inc     de
	ld      a,(de)
	ld      (ix+TRACK.tempoDivider+1),a
	ld      (tickMultiplier+1),a
	inc     de
	ld      a,(de)
	ld      (tickDivider1+0),a
	ld      (tickDivider2+0),a
	inc     de
	ld      a,(de)
	ld      (tickDivider1+1),a
	ld      (tickDivider2+1),a
	inc     de
	jp      _c30d
_c5d1:
	ld      a,(de)
	ld      (ix+TRACK.channelVolume),a
	inc     de
	ld      a,(ix+TRACK.id)
	cp      $04
	jr      z,_c5e5
	ld      a,(playbackMode)
	and     $08
	jp      nz,_c30d
_c5e5:
	ld      a,(ix+TRACK.channelVolume)
	ld      (ix+TRACK.fadeTicks+1),a
	ld      (ix+TRACK.fadeTicks+0),$00
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
	ld      (ix+TRACK.detune+0),a
	inc     de
	ld      a,(de)
	ld      (ix+TRACK.detune+1),a
	inc     de
	jp      _c30d
_c62d:
	ld      a,(de)
	inc     de
	jp      _c30d
_c632:
	ld      l,(ix+TRACK.loopAddress+0)
	ld      h,(ix+TRACK.loopAddress+1)
	ld      (hl),$00
	ld      bc,$0005
	add     hl,bc
	ld      (ix+TRACK.loopAddress+0),l
	ld      (ix+TRACK.loopAddress+1),h
	jp      _c30d
_c647:
	ld      l,(ix+TRACK.loopAddress+0)
	ld      h,(ix+TRACK.loopAddress+1)
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
	ld      c,(ix+TRACK.baseAddress+0)
	ld      b,(ix+TRACK.baseAddress+1)
	add     hl,bc
	ex      de,hl
	jp      _c30d
_c671:
	ld      (ix+TRACK.loopAddress+0),l
	ld      (ix+TRACK.loopAddress+1),h
	inc     de
	inc     de
	inc     de
	jp      _c30d
_c67d:
	ld      (ix+TRACK.masterLoopAddress+0),e
	ld      (ix+TRACK.masterLoopAddress+1),d
	jp      _c30d
_c686:
	ld      a,(de)
	ld      (ix+TRACK.noiseMode),a
	inc     de
	jp      _c30d
_c68e:
	ld      a,(de)
	ld      (ix+TRACK.defaultNoteLength),a
	inc     de
	jp      _c30d
_c696:
	ld      a,(ix+TRACK.channelVolume)
	inc     a
	cp      $10
	jr      c,_c6a0
	ld      a,$0f
_c6a0:
	ld      (ix+TRACK.channelVolume),a
	ld      a,(playbackMode)
	and     $08
	jp      nz,_c30d
	ld      a,(ix+TRACK.channelVolume)
	ld      (ix+TRACK.fadeTicks+1),a
	jp      _c30d
_c6b4:
	ld      a,(ix+TRACK.channelVolume)
	dec     a
	cp      $10
	jr      c,_c6bd
	xor     a
_c6bd:
	ld      (ix+TRACK.channelVolume),a
	ld      a,(playbackMode)
	and     $08
	jp      nz,_c30d
	ld      a,(ix+TRACK.channelVolume)
	ld      (ix+TRACK.fadeTicks+1),a
	jp      _c30d
_c6d1:
	set     0,(ix+TRACK.flags)
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