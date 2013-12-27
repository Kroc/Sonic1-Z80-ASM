;Sonic 1 Master System Sound Driver
 ;disassembled by ValleyBell and formatted by Kroc Camen
;======================================================================================
/* Terminology:

"PSG":
	Short for Programmable Sound Generator, it is the Yamaha SN76489 sound	processor in the Master System

"Channel":
	The PSG has four channels of sound that the chip mixes into the mono output.
	Three of the channels produce waves (notes) and the fourth produces noise
	(for percussion or sound effects)
*/

;each of the five tracks have a large set of variables for managing their state.
 ;below is the general definition of the track variables, which is duplicated five
 ;times in the RAM (see the Enum that follows this structure)
.STRUCT TRACK
	channelFrequencyPSG	db	;+$00
	;to set a frequency on the PSG a data byte is written to the sound port with
	 ;bit 7 set and bits 6 & 5 forming the sound channel number 0-3. this variable
	 ;holds the bit mask for the track's particular channel to set the frequency
	 ;(see `_PSGchannelBits` for the particulars)
	
	channelVolumePSG	db	;+$01
	;to set the volume of a channel, a data byte is written to the sound port with
	 ;bits 7 & 4 set and bits 6 & 5 forming the sound channel number 0-3. bits 0-3
	 ;form the volume level where 1111 is silence is 0000 is maximum. this variable
	 ;holds the bit mask for the track's particular channel to set the volume
	 ;(see `_initPSGValues` for examples)
	
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
;(NB: in the original ROM, $DC00-$DC03 go unused)
.ENUM $DC04
	playbackMode		db	;bit 4 dis/enables fading out
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
	
	;the `_loadMusic` routine assumes that the track RAM follows the data pointers
	 ;above, so just take note in case of rearranging the RAM here
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
sound_playMusic jp      _playMusic	;this is used externally to start a song
sound_playSFX	jp      _playSFX	;this is used externally to start SFX

;______________________________________________________________________________________

_loadMusic:
;HL : address of song data to load

	push    af
	push    bc
	push    de
	push    hl
	push    ix
	
	;remember the song's base address in BC for later use
	ld      c,l
	ld      b,h
	
	;read song header:
	;------------------------------------------------------------------------------
	;the song header contains five relative 16-bit offsets from the song's base
	 ;address to each track's starting point. since the first track starts right
	 ;after the header, the first value is always $000A (9)
	
	ld      ix,track0dataPointer
	
	;begin a loop over the five tracks
	ld      a,5
	
-	;fetch the track's offset value from the header and add it to the base address
	 ;giving you an absolute address to the track data
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ex      de,hl			;load the offset value into HL
	add     hl,bc			;add the song's base address to it
	
	;now fill the track's data pointer with the absolute address to the track data
	ld      (ix+0),l
	inc     ix
	ld      (ix+0),h
	inc     ix
	ex      de,hl
	
	;move on to the next track
	dec     a
	jp      nz,-
	
	;initialise track variables (16-bit values)
	;------------------------------------------------------------------------------
	;the referenced table contains a list of addresses and 16-bit values to set
	ld      hl,initTrackValues_words

-	;fetch the address of the variable to initialise from the table into DE
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	
	;if the hi-byte is $FF (i.e. $FFFF) then leave the loop
	ld      a,d
	inc     a			;if A is $FF then this will overflow to $00
	jr      z,+			;if $00 (as above) then leave the loop
	
	;now copy two bytes from the table into the variable's address
	inc     hl
	ldi     
	ldi     
	
	jp      -
	
	;initialise track variables (8-bit values)
	;------------------------------------------------------------------------------
+	;the referenced table contains a list of addresses and 8-bit values to set
	ld      hl,initTrackValues_bytes
	
	;fetch the address of the variable to initialise from the table into DE
-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	
	;if the hi-byte is $FF (i.e. $FFFF) then leave the loop
	ld      a,d
	inc     a			;if A is $FF then this will overflow to $00
	jr      z,+			;if $00 (as above) then leave the loop
	
	;now copy one byte from the table into the variable's address
	inc     hl
	ldi
	
	jp      -
	
	;finalise:
	;------------------------------------------------------------------------------
+	pop     ix
	pop     hl
	pop     de
	pop     bc
	pop     af
	
	;store the song's base address in each track
	ld      (track0vars.baseAddress),hl
	ld      (track1vars.baseAddress),hl
	ld      (track2vars.baseAddress),hl
	ld      (track3vars.baseAddress),hl
	
	ret

;--------------------------------------------------------------------------------------
;this data is used by `loadMusic` to initialise the values of the 5 tracks

initTrackValues_words:

;set the master loop address to 0 so that the song will, by default, loop wholly:
 ;the point of the master loop can be set by the '88' command in the music data
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

;--------------------------------------------------------------------------------------

initTrackValues_bytes:
.dw track0vars.channelFrequencyPSG
.db %10000000
.dw track0vars.channelVolumePSG
.db %10010000
.dw track1vars.channelFrequencyPSG
.db %10100000
.dw track1vars.channelVolumePSG
.db %10110000
.dw track2vars.channelFrequencyPSG
.db %11000000
.dw track2vars.channelVolumePSG
.db %11010000
.dw track3vars.channelFrequencyPSG
.db %11100000
.dw track3vars.channelVolumePSG
.db %11110000
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
.db %00000000
.dw $FFFF

;______________________________________________________________________________________

_initPSGValues:
;    +xx+yyyy	;set channel xx volume to yyyy (0000 is max, 1111 is off)
.db %10011111	;mute channel 0
.db %10111111	;mute channel 1
.db %11011111	;mute channel 2
.db %11111111	;mute channel 3

;--------------------------------------------------------------------------------------

_stop:			
	;put any current values for these registers aside
	push    af
	push    hl
	push    bc
	
	;mark the tracks as not "in-use" (bit 2) of the track's flags variable
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
	
	;reset the SFX priority, any sound effect will now play
	xor     a			;set A to 0
	ld      (SFXpriority),a
	
	;mute all sound channels by sending the right bytes to the sound chip
	ld      b,4
	ld      c,SMS_SOUND_PORT
	ld      hl,_initPSGValues
	otir
	
	ld      a,(playbackMode)
	and     %11110111
	ld      (playbackMode),a
	
	;restore the previous state of the registers and return
	pop     bc
	pop     hl
	pop     af
	ret
	
;______________________________________________________________________________________

_loadSFX:
;A  : priority level of SFX being loaded
;HL : address of SFX data
	push    af
	push    de
	push    hl
	
	ld      e,a			;copy the priority level of new SFX into E
	
	ld      a,(SFXpriority)		;get the current driver SFX priority
	and     a			;is it zero? (any sound allowed)
	jr      z,+			;then proceed
	
	cp      e			;is the new SFX priority < current priority
	jr      c,++			;if so, the SFX is not high priority enough
	
+	;update the SFX priority with the new value
	 ;(only sounds with higher priority will be played instead)
	ld      a,e
	ld      (SFXpriority),a
	
	;point the track at the sound data
	 ;(all SFX go through track 4)
	ld      (track4vars.baseAddress),hl
	
	;mute the track:
	 ;(fetch the mask used for that PSG channel)
	ld      a,(track4vars.channelVolumePSG)
	or      %00001111		;set volume to "%1111" (mute)
	out     (SMS_SOUND_PORT),a	;send change to the PSG
	
	;--- SFX header ---------------------------------------------------------------
	;get which track the sound effect should override -- there are only four
	 ;channels on the PSG (one is white noise), but five tracks, allowing for SFX
	 ;to occur whilst the music continues
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
	
	;skip the unused byte
	inc     hl
	
	ld      (track4dataPointer),hl
	
	;------------------------------------------------------------------------------
	ld      hl,_PSGchannelBits
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

;--------------------------------------------------------------------------------------

_PSGchannelBits:
.db %10000000
.db %10010000
.db %10100000
.db %10110000
.db %11000000
.db %11010000
.db %11100000
.db %11110000

;______________________________________________________________________________________

_unpause:
	push    af
	
	;mark the tracks as "in-use" (bit 2) of the track's flags variable
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
	
	;fade the sound back in(?) by taking the volume level (of each track) and
	 ;applying it to the [hi-byte of] each track's fade counter
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

;______________________________________________________________________________________

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

;______________________________________________________________________________________

_update:
	;track 1
	ld      ix,track0vars
	ld      de,(track0dataPointer)
	ld      bc,(tickDivider1)
	call    _updateTrack
	ld      (channel0trackPointer),ix
	ld      (track0dataPointer),de
	
	;track 2
	ld      ix,track1vars
	ld      de,(track1dataPointer)
	ld      bc,(tickDivider1)
	call    _updateTrack
	ld      (channel1trackPointer),ix
	ld      (track1dataPointer),de
	
	;track 3
	ld      ix,track2vars
	ld      de,(track2dataPointer)
	ld      bc,(tickDivider1)
	call    _updateTrack
	ld      (channel2trackPointer),ix
	ld      (track2dataPointer),de
	
	;track 4
	ld      ix,track3vars
	ld      de,(track3dataPointer)
	ld      bc,(tickDivider1)
	call    _updateTrack
	ld      (channel3trackPointer),ix
	ld      (track3dataPointer),de
	
	;SFX track
	ld      ix,track4vars
	ld      de,(track4dataPointer)
	ld      bc,(tickDividerSFX)
	call    _updateTrack
	ld      (track4dataPointer),de
	bit     1,(ix+TRACK.flags)
	jr      z,+
	
	ld      hl,channel0trackPointer
	ld      a,(overriddenTrack)
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      (hl),<track4vars
	inc     hl
	ld      (hl),>track4vars
+	ld      ix,(channel0trackPointer)
	call    _processTrack
	ld      ix,(channel1trackPointer)
	call    _processTrack
	ld      ix,(channel2trackPointer)
	call    _processTrack
	ld      ix,(channel3trackPointer)
	call    _processTrack
	
	ld      a,(playbackMode)
	and     %00001000
	ret     z
	
	ld      hl,(fadeTicks)
	ld      bc,(fadeTicksDecrement)
	and     a
	sbc     hl,bc
	jr      nc,+
	
	;stop all sound
	call    _stop
+	ld      (fadeTicks),hl
	ret

;______________________________________________________________________________________

_updateTrack:
	bit     1,(ix+TRACK.flags)
	ret     z
	
	ld      l,(ix+TRACK.tickStep+0)
	ld      h,(ix+TRACK.tickStep+1)
	and     a
	sbc     hl,bc
	ld      (ix+TRACK.tickStep+0),l
	ld      (ix+TRACK.tickStep+1),h
	jr      z,_trackReadLoop
	jp      nc,++

_trackReadLoop:
	ld      a,(de)
	and     a
	jp      m,_doCommand
	cp      $70
	jr      c,_doNote
	cp      $7f
	jr      nz,_doNoiseNote
	ld      (ix+TRACK.effectiveVolume),$00
	jp      _doNoteLength

;--------------------------------------------------------------------------------------

_doNoiseNote:
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
	ld      bc,_noiseNoteValues
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
	jp      _resetModValues

;--------------------------------------------------------------------------------------

_doNote:
	and     $0f
	ld      hl,_PSGfrequencyValues
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
	jr      nz,_doNoteLength

;--------------------------------------------------------------------------------------

_resetModValues:
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

;--------------------------------------------------------------------------------------

_doNoteLength:
	inc     de
	ld      a,(de)
	inc     de
	and     a
	jr      nz,+
	ld      a,(ix+TRACK.defaultNoteLength)
+	push    de
	ld      c,a
	ld      l,(ix+TRACK.tempoDivider+0)
	ld      h,(ix+TRACK.tempoDivider+1)
	ld      a,l
	or      h
	jr      nz,+
	ld      hl,(tickMultiplier)
+	call    _calcTickTime
	pop     de
	ld      a,l
	add     a,(ix+TRACK.tickStep+0)
	ld      (ix+TRACK.tickStep+0),a
	ld      a,h
	adc     a,(ix+TRACK.tickStep+1)
	ld      (ix+TRACK.tickStep+1),a
	
++	res     0,(ix+TRACK.flags)
	ret

_noiseNoteValues:
.db $05, $ff, $be, $0a, $04, $05, $02, $00, $05, $e6, $24, $5a, $14, $28, $08, $00

;______________________________________________________________________________________

_processTrack:
	bit     1,(ix+TRACK.flags)
	ret     z
	
	ld      a,(ix+TRACK.ADSRstate)
	and     a
	jp      z,_ADSRenvelopeAttack
	
	dec	a
	jp	z, _ADSRenvelopeDecay1
	
	dec	a
	jp	z, _ADSRenvelopeDecay2
	
	dec	a
	jp	z, _ADSRenvelopeSustain

_doTrackSoundOut:
	ld      a,(ix+TRACK.channelFrequencyPSG)
	cp      $e0
	jr      nz,_doModulation
	ld      c,(ix+TRACK.noiseMode)
	ld      a,(noiseMode)
	cp      c
	jp      z,_sendVolume
	ld      a,c
	ld      (noiseMode),a
	or      %11100000		;noise channel frequency?
	out     (SMS_SOUND_PORT),a
	jp      _sendVolume
	
;--------------------------------------------------------------------------------------

_doModulation:
	ld      e,(ix+TRACK.modulationFreq+0)
	ld      d,(ix+TRACK.modulationFreq+1)
	ld      a,(ix+TRACK.modulationDelay)
	and     a
	jr      z,+
	dec     (ix+TRACK.modulationDelay)
	jp      _sendFrequency
	
+	dec     (ix+TRACK.modulationStepDelay)
	jp      nz,_sendFrequency
	ld      a,(ix+$15)
	ld      (ix+TRACK.modulationStepDelay),a
	ld      l,(ix+TRACK.modulationFreqDelta+0)
	ld      h,(ix+TRACK.modulationFreqDelta+1)
	dec     (ix+TRACK.modulationStepCount)
	jp      nz,+
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
	jp      _sendFrequency
	
+	add     hl,de
	ld      (ix+TRACK.modulationFreq+0),l
	ld      (ix+TRACK.modulationFreq+1),h
	ex      de,hl

;--------------------------------------------------------------------------------------

_sendFrequency:
	ld      l,(ix+TRACK.noteFrequencey)
	ld      h,(ix+TRACK.noteFrequencey+1)
	ld      c,(ix+TRACK.detune+0)
	ld      b,(ix+TRACK.detune+1)
	add     hl,bc
	add     hl,de
	ld      a,(ix+TRACK.octave)
	and     a
	jr      z,+
	ld      b,a
	
-	srl     h
	rr      l
	djnz    -
	
+	ld      a,l
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
	
_sendVolume:
	ld      a,(ix+TRACK.fadeTicks+1)
	and     a
	jr      z,+
	ld      c,a
	ld      a,(ix+TRACK.envelopeLevel)
	and     a
	jr      z,+
	ld      l,a
	ld      h,$00
	call    _calcTickTime
	rl      l
	ld      a,$00
	adc     a,h
+	and     (ix+TRACK.effectiveVolume)
	xor     %00001111
	or      (ix+TRACK.channelVolumePSG)
	out     (SMS_SOUND_PORT),a
	ld      a,(playbackMode)
	and     %00001000
	ret     z
	ld      a,(ix+TRACK.id)
	cp      $04
	ret     z
	ld      l,(ix+TRACK.fadeTicks+0)
	ld      h,(ix+TRACK.fadeTicks+1)
	ld      bc,(fadeTicksDecrement)
	sbc     hl,bc
	jr      nc,+
	ld      hl,$0000
+	ld      (ix+TRACK.fadeTicks+0),l
	ld      (ix+TRACK.fadeTicks+1),h
	ret

_PSGfrequencyValues:
.dw $0356, $0326, $02F9, $02CE, $02A5, $0280, $025C, $023A
.dw $021A, $01FB, $01DF, $01C4, $03F7, $03BE, $0388

;______________________________________________________________________________________

_doCommand:
	cp      $ff
	jp      z,_cmdFF_stopMusic
	cp      $fe
	jp      z,_cmdFE_stopSFX
	inc     de
	ld      hl,_commandPointers
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	jp      (hl)

;--------------------------------------------------------------------------------------

_cmdFF_stopMusic:
	ld      l,(ix+TRACK.masterLoopAddress+0)
	ld      h,(ix+TRACK.masterLoopAddress+1)
	ld      a,l
	or      h
	jr      z,_stopTrack
	ex      de,hl
	jp      _trackReadLoop
	
_cmdFE_stopSFX:
	xor     a
	ld      (SFXpriority),a
	
_stopTrack:
	res     1,(ix+TRACK.flags)
	ld      a,%00001111
	or      (ix+TRACK.channelVolumePSG)
	out     (SMS_SOUND_PORT),a
	ret

;--------------------------------------------------------------------------------------

_commandPointers:
.dw _cmd80_tempo
.dw _cmd81_volumeSet
.dw _cmd82_setADSR
.dw _cmd83_modulation
.dw _cmd84_detune
.dw _cmd85_dummy
.dw _cmd86_loopStart
.dw _cmd87_loopEnd
.dw _cmd88_masterLoop
.dw _cmd89_noiseMode
.dw _cmd8A_noteLength
.dw _cmd8B_volumeUp
.dw _cmd8C_volumeDown
.dw _cmd8D_hold

;--------------------------------------------------------------------------------------

_ADSRenvelopeAttack:
	ld      a,(ix+TRACK.attackRate)
	add     a,(ix+TRACK.envelopeLevel)
	jp      nc,+
	ld      a,$ff
+	ld      (ix+TRACK.envelopeLevel),a
	jp      nc,_doTrackSoundOut
	inc     (ix+TRACK.ADSRstate)
	jp      _doTrackSoundOut

;--------------------------------------------------------------------------------------
	
_ADSRenvelopeDecay1:
	ld      c,(ix+TRACK.decay1Level)
	ld      a,(ix+TRACK.envelopeLevel)
	sub     (ix+TRACK.decay1Rate)
	jr      c,+
	cp      (ix+TRACK.decay1Level)
	jr      c,+
	ld      c,a
+	ld      (ix+TRACK.envelopeLevel),c
	jp      nc,_doTrackSoundOut
	inc     (ix+TRACK.ADSRstate)
	jp      _doTrackSoundOut

;--------------------------------------------------------------------------------------

_ADSRenvelopeDecay2:
	ld      c,(ix+TRACK.decay2Level)
	ld      a,(ix+TRACK.envelopeLevel)
	sub     (ix+TRACK.decay2Rate)
	jr      c,+
	cp      (ix+TRACK.decay2Level)
	jp      c,+
	ld      c,a
+	ld      (ix+TRACK.envelopeLevel),c
	jp      nc,_doTrackSoundOut
	inc     (ix+TRACK.ADSRstate)
	jp      _doTrackSoundOut

;--------------------------------------------------------------------------------------

_ADSRenvelopeSustain:
	ld      a,(ix+TRACK.envelopeLevel)
	sub     (ix+TRACK.sustainRate)
	jp      nc,+
	ld      a,$00
+	ld      (ix+TRACK.envelopeLevel),a
	jp      nc,_doTrackSoundOut
	inc     (ix+TRACK.ADSRstate)
	jp      _doTrackSoundOut

;--------------------------------------------------------------------------------------

_cmd80_tempo:
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
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd81_volumeSet:
	ld      a,(de)
	ld      (ix+TRACK.channelVolume),a
	inc     de
	ld      a,(ix+TRACK.id)
	cp      $04
	jr      z,+
	ld      a,(playbackMode)
	and     %00001000
	jp      nz,_trackReadLoop
	
+	ld      a,(ix+TRACK.channelVolume)
	ld      (ix+TRACK.fadeTicks+1),a
	ld      (ix+TRACK.fadeTicks+0),$00
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------
	
_cmd82_setADSR:
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
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd83_modulation:
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
	jp      _trackReadLoop
	
;--------------------------------------------------------------------------------------

_cmd84_detune:
	ld      a,(de)
	ld      (ix+TRACK.detune+0),a
	inc     de
	ld      a,(de)
	ld      (ix+TRACK.detune+1),a
	inc     de
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd85_dummy:
	ld      a,(de)
	inc     de
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd86_loopStart:
	ld      l,(ix+TRACK.loopAddress+0)
	ld      h,(ix+TRACK.loopAddress+1)
	ld      (hl),$00
	ld      bc,$0005
	add     hl,bc
	ld      (ix+TRACK.loopAddress+0),l
	ld      (ix+TRACK.loopAddress+1),h
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd87_loopEnd:
	ld      l,(ix+TRACK.loopAddress+0)
	ld      h,(ix+TRACK.loopAddress+1)
	ld      bc,$fffb
	add     hl,bc
	ld      a,(hl)
	and     a
	jr      nz,_loopInit
	ld      a,(de)
	dec     a
	jr      z,++
	ld      (hl),a
	jp      +
	
_loopInit:
	dec     (hl)
	jr      z,++
+	ex      de,hl
	inc     hl
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      c,(ix+TRACK.baseAddress+0)
	ld      b,(ix+TRACK.baseAddress+1)
	add     hl,bc
	ex      de,hl
	jp      _trackReadLoop
	
++	ld      (ix+TRACK.loopAddress+0),l
	ld      (ix+TRACK.loopAddress+1),h
	inc     de
	inc     de
	inc     de
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd88_masterLoop:
	ld      (ix+TRACK.masterLoopAddress+0),e
	ld      (ix+TRACK.masterLoopAddress+1),d
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd89_noiseMode:
	ld      a,(de)
	ld      (ix+TRACK.noiseMode),a
	inc     de
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd8A_noteLength:
	ld      a,(de)
	ld      (ix+TRACK.defaultNoteLength),a
	inc     de
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd8B_volumeUp:
	ld      a,(ix+TRACK.channelVolume)
	inc     a
	cp      $10
	jr      c,+
	ld      a,$0f
+	ld      (ix+TRACK.channelVolume),a
	ld      a,(playbackMode)
	and     %00001000
	jp      nz,_trackReadLoop
	ld      a,(ix+TRACK.channelVolume)
	ld      (ix+TRACK.fadeTicks+1),a
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd8C_volumeDown:
	ld      a,(ix+TRACK.channelVolume)
	dec     a
	cp      $10
	jr      c,+
	xor     a
+	ld      (ix+TRACK.channelVolume),a
	ld      a,(playbackMode)
	and     %00001000
	jp      nz,_trackReadLoop
	ld      a,(ix+TRACK.channelVolume)
	ld      (ix+TRACK.fadeTicks+1),a
	jp      _trackReadLoop

;--------------------------------------------------------------------------------------

_cmd8D_hold:
	set     0,(ix+TRACK.flags)
	jp      _trackReadLoop

;______________________________________________________________________________________

_calcTickTime:
	xor     a
	ld      b,$07
	ex      de,hl
	ld      l,a
	ld      h,a
	
-	rl      c
	jp      nc,+
	add     hl,de
+	add     hl,hl
	djnz    -
	
	or      c
	ret     z
	add     hl,de
	ret

;______________________________________________________________________________________

_playMusic:
;A : index number of music track to play (see `S1_SFXPointers`)

	push    hl
	
	;look up the index number in the music list
	ld      hl,S1_MusicPointers	;begin with the table of songs
	add     a,a			;double the ID (each song is a 16-bit pointer)
	add     a,l			;add that to the lo-byte of the list address
	ld      l,a
	ld      a,$00
	adc     a,h			;add the carry to the hi-byte so that we
	ld      h,a			;handle the 8-bit overflow ("$00FF > $0100")
	
	;get the pointer to the song (into HL) from the song list
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	call    _loadMusic
	
	pop     hl
	ret

;______________________________________________________________________________________

_playSFX:
;A: index number of SFX to play (see `S1_SFXPointers`)

	push    hl
	push    de
	
	;look up the index number in the SFX list
	ld      hl,S1_SFXPointers	;begin with the list of SFX
	add     a,a			;quadruple the index number since the SFX
	add     a,a			 ;list is four bytes each entry instead of two
	ld      e,a			;put this index number into a 16-bit number
	ld      d,$00
	add     hl,de			;and offset into the SFX list
	
	;load DE with the first value -- a pointer to the SFX data
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	;the next value acts as a priority level
	ld      a,(hl)
	;(note that the SFX list has an extra unused byte on each entry)
	
	;swap DE & HL,
	 ;DE will now be an address to SFX's entry in the SFX list
	 ;HL will now be the address of the SFX's data
	ex      de,hl
	call    _loadSFX
	
	pop     de
	pop     hl
	ret