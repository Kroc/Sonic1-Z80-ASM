; this sound driver was disassembled by Valley Bell, to whom I am eternally
; grateful as I have no understanding of sound theory and could not have
; hoped to make sense of this
;
; terminology:
; 
; *     "PSG"
;
;       short for Programmable Sound Generator, it is the Yamaha SN76489
;       sound processor used in the Master System
; 
; *     "Channel"
;
;       the PSG has four channels of sound that the chip mixes into mono
;       output. Three of the channels produce waves (musical notes) and
;       the fourth produces noise (for percussion or sound effects)
; 
; *     "Track"
;
;       the sequence of notes played by a single channel. there are five
;       tracks, 4 represent the current song being played and the fifth
;       is for sound-effects. since there are only four actual hardware
;       channels, the SFX track overrides the noise channel of the song
;


.STRUCT Track
;===============================================================================
; each of the five tracks have a large set of variables for managing their
; state. below is the general definition of the track variables, which is
; duplicated five times in the RAM
;-------------------------------------------------------------------------------
        ; to set a frequency on the PSG, a data byte is written to the sound
        ; port with bit 7 set and bits 6 & 5 forming the sound channel number
        ; 0-3. this variable holds the bit mask for the track's particular
        ; channel to set the frequency (see `PSGchannelBits` for particulars)
        channelFrequencyPSG             DB                              ;+$00

        ; to set the volume of a channel, a data byte is written to the sound
        ; port with bits 7 & 4 set and bits 6 & 5 forming the sound channel
        ; number 0-3. bits 0-3 form the volume level where `%1111` is silence
        ; and `%0000` is maximum. this variable holds the bit mask for the
        ; track's particular channel to set the volume
        ; (see `initPSGValues` for examples)
        channelVolumePSG                DB                              ;+$01

        tickStep                        DW                              ;+$02
        fadeTicks                       DW                              ;+$04
        noteFrequencey                  DW ; no direct reference?       ;+$06
        detune                          DW                              ;+$08
        modulationFreq                  DW                              ;+$0A
        envelopeLevel                   DB                              ;+$0C
        ADSRstate                       DB                              ;+$0D
        attackRate                      DB                              ;+$0E
        decay1Rate                      DB                              ;+$0F
        decay1Level                     DB                              ;+$10
        decay2Rate                      DB                              ;+$11
        decay2Level                     DB                              ;+$12
        sustainRate                     DB                              ;+$13
        initModulationDelay             DB                              ;+$14
        initModulationStepDelay         DB                              ;+$15
        initModulationStepCount         DB                              ;+$16
        initModulationFreqDelta         DW                              ;+$17
        modulationDelay                 DB                              ;+$19
        modulationStepDelay             DB                              ;+$1A
        modulationStepCount             DB                              ;+$1B
        modulationFreqDelta             DW                              ;+$1C
        effectiveVolume                 DB                              ;+$1E
        octave                          DB                              ;+$1F
        loopAddress                     DW                              ;+$20
        masterLoopAddress               DW                              ;+$22
        defaultNoteLength               DB                              ;+$24
        noiseMode                       DB                              ;+$25
        tempoDivider                    DW                              ;+$26
        flags                           DB                              ;+$28
        baseAddress                     DW                              ;+$29
        id                              DB                              ;+$2B
        channelVolume                   DB                              ;+$2C
.ENDST

.RAMSECTION     "sound_RAM"
;===============================================================================
; name                          ; size  ; note                          ;addr
;-------------------------------------------------------------------------------
; define the sound-driver variables in RAM:
;
; (NB: in the original ROM, $DC00-$DC03 go unused)
; TODO: Set this to $DC04
;
playbackMode                    DB      ; bit 4 dis/enables fading out  ;[$DC04]
overriddenTrack                 DB      ; music track SFX overrides     ;[$DC05]
SFXpriority                     DB      ; current SFX priority level    ;[$DC06]
noiseMode                       DB      ; hi/med/lo noise & freq mode   ;[$DC07]
tickMultiplier                  DW                                      ;[$DC08]
tickDivider1                    DW                                      ;[$DC0A]
tickDivider2                    DW                                      ;[$DC0C]
tickDividerSFX                  DW                                      ;[$DC0E]
fadeTicks                       DW                                      ;[$DC10]
fadeTicksDecrement              DW                                      ;[$DC12]
channel0trackPointer            DW                                      ;[$DC14]
channel1trackPointer            DW                                      ;[$DC16]
channel2trackPointer            DW                                      ;[$DC18]
channel3trackPointer            DW                                      ;[$DC1A]
track0dataPointer               DW                                      ;[$DC1C]
track1dataPointer               DW                                      ;[$DC1E]
track2dataPointer               DW                                      ;[$DC20]
track3dataPointer               DW                                      ;[$DC22]
track4dataPointer               DW                                      ;[$DC10]
; the `_loadMusic` routine assumes that the track RAM follows the data pointers
; above, so just take note in case of rearranging the RAM here
track0vars                      INSTANCEOF Track
track1vars                      INSTANCEOF Track
track2vars                      INSTANCEOF Track
track3vars                      INSTANCEOF Track
track4vars                      INSTANCEOF Track
loopStack                       DW

.ENDS

; because the sound driver has to be banked in, there needs to be some stubs
; in a fixed bank (typically BANK0,SLOT0) to page in the correct bank before
; calling the sound driver

.SECTION    "!rst_playMusic"                                            ;$0018
;===============================================================================
rst_playMusic:                                                          ;$0018
;===============================================================================
; in    A       music ID
;-------------------------------------------------------------------------------
        jp      call_playMusic
        ;
.ENDS

.SECTION    "!rst_muteSound"                                            ;$0020
;===============================================================================
rst_muteSound:                                                          ;$0020
;===============================================================================
        jp      call_muteSound
        ;
.ENDS

.SECTION    "!rst_playSFX"              PRIORITY 1000                   ;$0028
;===============================================================================
rst_playSFX:                                                            ;$0028
;===============================================================================
; in    A       sfx ID
;-------------------------------------------------------------------------------
        jp      call_playSFX
        ;
.ENDS

; This is the public interface that forwards to the internal implementation;
; this style of implementation is unique to the sound driver -- perhaps it's
; reused in other Ancient games, or it could be a 3rd-party piece of code
;
.SECTION        "sound_driver"          NAMESPACE "sound"
;===============================================================================
update:
        jp      doUpdate
        ;
loadMusic:
        jp      doLoadMusic             ; this public call is not used in-game
        ;
stop:
        jp      doStop
        ;
unpause:
        jp      doUnpause
        ;
fadeOut:
        jp      doFadeOut
        ;
loadSFX:
        jp      doLoadSFX               ; this public call is not used in-game
        ;
playMusic:
        jp      doPlayMusic             ; called externally to start a song
        ;
playSFX:
        jp      doPlaySFX               ; called externally to start SFX
        ;

doLoadMusic:
;===============================================================================
; in    HL             Address of song data to load
;-------------------------------------------------------------------------------
        push    AF
        push    BC
        push    DE
        push    HL
        push    IX

        ; remember the song's base address in BC for later use
        ld      C,      L
        ld      B,      H

        ; read song header:
        ;-----------------------------------------------------------------------
        ; the song header contains five relative 16-bit offsets from the song's
        ; base address to each track's starting point. since the first track
        ; starts right after the header, the first value is always $000A (9)
        ld      IX,     track0dataPointer

        ; begin a loop over the five tracks
        ld      A,      5

@_1:    ; fetch the track's offset value from the header and add it to the base
        ; address giving you an absolute address to the track data
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ex      DE,     HL              ; load the offset value into HL
        add     HL,     BC              ; add the song's base address to it

        ; now fill the track's data pointer with
        ; the absolute address to the track data
        ld      [IX+0], L
        inc     IX
        ld      [IX+0], H
        inc     IX
        ex      DE,     HL

        ; move on to the next track
        dec     A
        jp      nz,     @_1

        ; initialise track variables (16-bit values)
        ;-----------------------------------------------------------------------
        ; the referenced table contains a list
        ; of addresses and 16-bit values to set
        ld      HL,     initTrackValues_words

@_2:    ; fetch the address of the variable
        ; to initialise from the table into DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]

        ; if the hi-byte is $FF (i.e. $FFFF)
        ; then leave the loop
        ld      A,      D
        inc     A                       ; if A is $FF then this will overflow
        jr      z,      @_3             ; if $00 (as above) then leave the loop

        ; now copy two bytes from the table
        ; into the variable's address
        inc     HL
        ldi
        ldi

        jp      @_2

        ; initialise track variables (8-bit values)
        ;-----------------------------------------------------------------------
@_3:    ; the referenced table contains a list
        ; of addresses and 8-bit values to set
        ld      HL,     initTrackValues_bytes

        ; fetch the address of the variable
        ; to initialise from the table into DE
@_4:    ld      E,      [HL]
        inc     HL
        ld      D,      [HL]

        ;if the hi-byte is $FF (i.e. $FFFF) then leave the loop
        ld      A,      D
        inc     A                       ; if A is $FF then this will overflow
        jr      z,      @_5             ; if $00 (as above) then leave the loop

        ; now copy one byte from the table into the variable's address
        inc     HL
        ldi

        jp      @_4

        ; finalise:
        ;-----------------------------------------------------------------------
@_5:    pop     IX
        pop     HL
        pop     DE
        pop     BC
        pop     AF

        ; store the song's base address in each track
        ld      [track0vars.baseAddress],       HL
        ld      [track1vars.baseAddress],       HL
        ld      [track2vars.baseAddress],       HL
        ld      [track3vars.baseAddress],       HL

        ret
        ;

initTrackValues_words:
;===============================================================================
; this data is used by `loadMusic` to initialise the values of the 5 tracks.
; set the master loop address to 0 so that the song will, by default, loop
; wholly: the point of the master loop can be set by the '88' command in
; the music data
;-------------------------------------------------------------------------------
        .WORD   track0vars.masterLoopAddress         $0000
        .WORD   track1vars.masterLoopAddress         $0000
        .WORD   track2vars.masterLoopAddress         $0000
        .WORD   track3vars.masterLoopAddress         $0000

        .WORD   track0vars.loopAddress               loopStack+0
        .WORD   track1vars.loopAddress               loopStack+1
        .WORD   track2vars.loopAddress               loopStack+2
        .WORD   track3vars.loopAddress               loopStack+3

        .WORD   track0vars.tickStep                  $0001
        .WORD   track1vars.tickStep                  $0001
        .WORD   track2vars.tickStep                  $0001
        .WORD   track3vars.tickStep                  $0001

        .WORD   track0vars.initModulationFreqDelta   $0000
        .WORD   track0vars.modulationFreqDelta       $0000
        .WORD   track1vars.initModulationFreqDelta   $0000
        .WORD   track1vars.modulationFreqDelta       $0000
        .WORD   track2vars.initModulationFreqDelta   $0000
        .WORD   track2vars.modulationFreqDelta       $0000
        .WORD   track3vars.initModulationFreqDelta   $0000
        .WORD   track3vars.modulationFreqDelta       $0000

        .WORD   track0vars.detune                    $0000
        .WORD   track1vars.detune                    $0000
        .WORD   track2vars.detune                    $0000
        .WORD   track3vars.detune                    $0000

        .WORD   tickDivider1                         $0001

        .WORD   $FFFF
        ;

initTrackValues_bytes:
;===============================================================================
        .TABLE  WORD                                    BYTE
        .ROW    track0vars.channelFrequencyPSG          %10000000
        .ROW    track0vars.channelVolumePSG             %10010000
        .ROW    track1vars.channelFrequencyPSG          %10100000
        .ROW    track1vars.channelVolumePSG             %10110000
        .ROW    track2vars.channelFrequencyPSG          %11000000
        .ROW    track2vars.channelVolumePSG             %11010000
        .ROW    track3vars.channelFrequencyPSG          %11100000
        .ROW    track3vars.channelVolumePSG             %11110000
        .ROW    track0vars.flags                        %00000010
        .ROW    track1vars.flags                        %00000010
        .ROW    track2vars.flags                        %00000010
        .ROW    track3vars.flags                        %00000010
        .ROW    track4vars.flags                        %00000000

        ; TODO: is there a reason this var is not set using the WORD table
        ;       above instead of two separate bytes as is the case here?
        .ROW    track0vars.initModulationDelay+0        $00
        .ROW    track1vars.initModulationDelay+0        $00
        .ROW    track2vars.initModulationDelay+0        $00
        .ROW    track3vars.initModulationDelay+0        $00
        .ROW    track0vars.initModulationDelay+1        $00
        .ROW    track1vars.initModulationDelay+1        $00
        .ROW    track2vars.initModulationDelay+1        $00
        .ROW    track3vars.initModulationDelay+1        $00
        .ROW    track0vars.id                           $00
        .ROW    track1vars.id                           $01
        .ROW    track2vars.id                           $02
        .ROW    track3vars.id                           $03
        .ROW    SFXpriority                             $00
        .ROW    playbackMode                            %00000000

        .WORD   $FFFF
        ;

initPSGValues:
;===============================================================================
        
        ;                               ; set channel xx volume to yyyy
        ;        +xx+yyyy               ; (0000 is max, 1111 is off)
        .BYTE   %10011111               ; mute channel 0
        .BYTE   %10111111               ; mute channel 1
        .BYTE   %11011111               ; mute channel 2
        .BYTE   %11111111               ; mute channel 3
        ;

doStop:
;===============================================================================
        ; put any current values for these registers aside
        push    AF
        push    HL
        push    BC

        ; mark the tracks as not "in-use" (bit 2)
        ; of the track's flags variable
        ld      A,      [track0vars.flags]
        and     %11111101
        ld      [track0vars.flags],     A

        ld      A,      [track1vars.flags]
        and     %11111101
        ld      [track1vars.flags],     A

        ld      A,      [track2vars.flags]
        and     %11111101
        ld      [track2vars.flags],     A

        ld      A,      [track3vars.flags]
        and     %11111101
        ld      [track3vars.flags],     A

        ld      A,      [track4vars.flags]
        and     %11111101
        ld      [track4vars.flags],     A

        ; reset the SFX priority,
        ; any sound effect will now play
        xor     A                       ; set A to 0
        ld      [SFXpriority],          A

        ; mute all sound channels by sending
        ; the right bytes to the sound chip
        ld      B,      4
        ld      C,      SMS_PORTS_PSG
        ld      HL,     initPSGValues
        ; TODO: 4x `oti` will be faster. we could even use `out` with static
        ;       values (instead of `initPSGValues` table), so that we no longer
        ;       need to PUSH/POP BC & HL
        otir

        ld      A,      [playbackMode]
        and     %11110111
        ld      [playbackMode],         A

        ; restore the previous state of the registers and return
        pop     BC
        pop     HL
        pop     AF
        ret
        ;

doLoadSFX:
;===============================================================================
; in    A       Priority level of SFX being loaded
;       HL      Address of SFX data
;-------------------------------------------------------------------------------
        push    AF
        push    DE
        push    HL

        ld      E,      A               ; copy priority level of new SFX into E

        ld      A,      [SFXpriority]   ; get the current driver SFX priority
        and     A                       ; is it zero? (any sound allowed)
        jr      z,      @_1             ; then proceed

        cp      E                       ; is new SFX priority < current priority
        jr      c,      @_2             ; if so, SFX is not high priority enough

@_1:    ; update the SFX priority with the new value
        ; (only sounds with higher priority will be played instead)
        ld      A,                      E
        ld      [SFXpriority],          A

        ; point the track at the sound data
        ; (all SFX go through track 4)
        ld      [track4vars.baseAddress],       HL

        ; mute the track:
        ; (fetch the mask used for that PSG channel)
        ld      A,      [track4vars.channelVolumePSG]
        or      %00001111               ; set volume to "%1111" (mute)
        out     [SMS_PORTS_PSG],        A

        ; SFX header:
        ;-----------------------------------------------------------------------
        ; get which track the sound effect should override -- there are only
        ; four hardware channels on the PSG (one is white noise), but five
        ; tracks, allowing for SFX to occur whilst the music continues
        ld      A,      [HL]
        ld      [overriddenTrack],      A

        inc     HL
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [track4vars.tempoDivider],      DE

        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [tickDividerSFX],       DE

        ; skip the unused byte
        inc     HL

        ld      [track4dataPointer],    HL

        ld      HL,     PSGchannelBits
        add     A,      A
        ld      E,      A
        ld      D,      $00
        add     HL,     DE
        ld      A,      [HL]
        ld      [track4vars],   A
        inc     HL
        ld      A,      [HL]
        ld      [track4vars.channelVolumePSG],  A
        ld      HL,     $0000
        ld      [track4vars.masterLoopAddress],         HL
        ld      [track4vars.initModulationFreqDelta],   HL
        ld      [track4vars.modulationFreqDelta],       HL
        ld      [track4vars.detune],    HL
        ld      A,      $04
        ld      [track4vars.id],        A
        inc     HL
        ld      [track4vars.tickStep],  HL
        ld      HL,     loopStack + 4
        ld      [track4vars.loopAddress],       HL
        ld      A,      $02
        ld      [track4vars.flags],     A

@_2:    pop     HL
        pop     DE
        pop     AF
        ret
        ;

PSGchannelBits:
;===============================================================================

        .BYTE   %10000000
        .BYTE   %10010000
        .BYTE   %10100000
        .BYTE   %10110000
        .BYTE   %11000000
        .BYTE   %11010000
        .BYTE   %11100000
        .BYTE   %11110000
        ;

doUnpause:
;===============================================================================
        push    AF

        ; mark the tracks as "in-use" (bit 2)
        ; of the track's flags variable
        ld      A,      [track0vars.flags]
        or      %00000010
        ld      [track0vars.flags],     A

        ld      A,      [track1vars.flags]
        or      %00000010
        ld      [track1vars.flags],     A

        ld      A,      [track2vars.flags]
        or      %00000010
        ld      [track2vars.flags],     A

        ld      A,      [track3vars.flags]
        or      %00000010
        ld      [track3vars.flags],     A

        ; fade the sound back in(?) by taking the volume level (of each track)
        ; and applying it to the [hi-byte of] each track's fade counter
        ld      A,      [track0vars.channelVolume]
        ld      [track0vars.fadeTicks+1],       A
        ld      A,      [track1vars.channelVolume]
        ld      [track1vars.fadeTicks+1],       A
        ld      A,      [track2vars.channelVolume]
        ld      [track2vars.fadeTicks+1],       A
        ld      A,      [track3vars.channelVolume]
        ld      [track3vars.fadeTicks+1],       A

        xor     A
        ld      [playbackMode],         A

        pop     AF
        ret
        ;

doFadeOut:
;===============================================================================
        push    AF
        push    HL

        ld      [fadeTicksDecrement],   HL

        ld      A,      [playbackMode]
        or      %00001000
        ld      [playbackMode],         A

        ld      HL,     $1000
        ld      [fadeTicks],    HL

        pop     HL
        pop     AF
        ret
        ;

doUpdate:
;===============================================================================
        ; track 1
        ld      IX,     track0vars
        ld      DE,     [track0dataPointer]
        ld      BC,     [tickDivider1]
        call    doUpdateTrack
        ld      [channel0trackPointer], IX
        ld      [track0dataPointer],    DE

        ; track 2
        ld      IX,     track1vars
        ld      DE,     [track1dataPointer]
        ld      BC,     [tickDivider1]
        call    doUpdateTrack
        ld      [channel1trackPointer], IX
        ld      [track1dataPointer],    DE

        ; track 3
        ld      IX,     track2vars
        ld      DE,     [track2dataPointer]
        ld      BC,     [tickDivider1]
        call    doUpdateTrack
        ld      [channel2trackPointer], IX
        ld      [track2dataPointer],    DE

        ; track 4
        ld      IX,     track3vars
        ld      DE,     [track3dataPointer]
        ld      BC,     [tickDivider1]
        call    doUpdateTrack
        ld      [channel3trackPointer], IX
        ld      [track3dataPointer],    DE

        ; SFX track
        ld      IX,     track4vars
        ld      DE,     [track4dataPointer]
        ld      BC,     [tickDividerSFX]
        call    doUpdateTrack
        ld      [track4dataPointer],    DE
        bit     1,      [IX+Track.flags]
        jr      z,      @_1

        ld      HL,     channel0trackPointer
        ld      A,      [overriddenTrack]
        add     A,      A
        ld      C,      A
        ld      B,      $00
        add     HL,     BC
        ld      [HL],   <track4vars
        inc     HL
        ld      [HL],   >track4vars
@_1:    ld      IX,     [channel0trackPointer]
        call    doProcessTrack
        ; TODO: Why not just use `inc IX`?
        ld      IX,     [channel1trackPointer]
        call    doProcessTrack
        ld      IX,     [channel2trackPointer]
        call    doProcessTrack
        ld      IX,     [channel3trackPointer]
        call    doProcessTrack

        ld      A,      [playbackMode]
        and     %00001000
        ret     z

        ld      HL,     [fadeTicks]
        ld      BC,     [fadeTicksDecrement]
        and     A
        sbc     HL,     BC
        jr      nc,     @_2

        ; stop all sound
        call    doStop
@_2:    ld      [fadeTicks],    HL
        ret
        ;

doUpdateTrack:
;===============================================================================
        bit     1,      [IX+Track.flags]
        ret     z

        ld      L,      [IX+Track.tickStep+0]
        ld      H,      [IX+Track.tickStep+1]
        and     A
        sbc     HL,     BC
        ld      [IX+Track.tickStep+0],  L
        ld      [IX+Track.tickStep+1],  H
        jr      z,      @trackReadLoop
        jp      nc,     doNote@x

@trackReadLoop:
        ld      A,      [DE]
        and     A
        jp      m,      doCommand
        cp      $70
        jr      c,      doNote
        cp      $7F
        jr      nz,     doNoiseNote
        ld      [IX+Track.effectiveVolume],     $00
        jp      doNote@doNoteLength
        ;

doNoiseNote:
;===============================================================================
        push    DE
        push    IX
        pop     HL

        ld      BC,     $000E
        add     HL,     BC
        ex      DE,     HL
        and     $0F
        ld      L,      A
        ld      H,      $00
        add     HL,     HL
        add     HL,     HL
        add     HL,     HL
        ld      BC,     noiseNoteValues
        add     HL,     BC
        ld      A,      [HL]
        ld      [IX+Track.noiseMode],   A
        inc     HL
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop     DE
        jp      doNote@resetModValues
        ;

doNote:
;===============================================================================
        and     $0F
        ld      HL,     PSGfrequencyValues
        add     A,      A
        ld      C,      A
        ld      B,      $00
        add     HL,     BC
        ld      A,      [HL]
        ld      [IX+Track.noteFrequencey],      A
        inc     HL
        ld      A,      [HL]
        ld      [IX+Track.noteFrequencey+1],    A
        ld      A,      [DE]
        rrca
        rrca
        rrca
        rrca
        and     $0F
        ld      [IX+Track.octave],      A
        bit     0,      [IX+Track.flags]
        jr      nz,     doNote@doNoteLength

@resetModValues:
        ld      A,      [IX+Track.initModulationDelay]
        ld      [IX+Track.modulationDelay],     A
        ld      A,      [IX+Track.initModulationDelay+1]
        ld      [IX+Track.modulationDelay+1],   A
        ld      A,      [IX+Track.initModulationStepCount]
        srl     A
        ld      [IX+Track.modulationStepCount], A
        ld      A,      [IX+Track.initModulationFreqDelta+0]
        ld      [IX+Track.modulationFreqDelta+0],       A
        ld      A,      [IX+Track.initModulationFreqDelta+1]
        ld      [IX+Track.modulationFreqDelta+1],       A
        xor     A
        ld      [IX+Track.modulationFreq+0],    A
        ld      [IX+Track.modulationFreq+1],    A
        ld      [IX+Track.ADSRstate],           A
        ld      [IX+Track.envelopeLevel],       A
        ld      [IX+Track.effectiveVolume],     $0F

@doNoteLength:
        inc     DE
        ld      A,      [DE]
        inc     DE
        and     A
        jr      nz,     @_1
        ld      A,      [IX+Track.defaultNoteLength]
@_1:    push    DE
        ld      C,      A
        ld      L,      [IX+Track.tempoDivider+0]
        ld      H,      [IX+Track.tempoDivider+1]
        ld      A,      L
        or      H
        jr      nz,     @_2
        ld      HL,     [tickMultiplier]
@_2:    call    calcTickTime
        pop     DE
        ld      A,      L
        add     A,      [IX+Track.tickStep+0]
        ld      [IX+Track.tickStep+0],  A
        ld      A,      H
        adc     A,      [IX+Track.tickStep+1]
        ld      [IX+Track.tickStep+1],  A

@x:     res     0,      [IX+Track.flags]
        ret
        ;

noiseNoteValues:
;===============================================================================
        
        ; TODO: are these based on any meaningful calculation
        ;       that can be expressed here?
        .BYTE   $05 $FF $BE $0A $04 $05 $02 $00 $05 $E6 $24 $5A $14 $28 $08 $00
        ;

doProcessTrack:
;===============================================================================
        bit     1,      [IX+Track.flags]
        ret     z

        ld      A,      [IX+Track.ADSRstate]
        and     A
        jp      z,      ADSRenvelopeAttack

        dec     A
        jp      z,      ADSRenvelopeDecay1

        dec     A
        jp      z,      ADSRenvelopeDecay2

        dec     A
        jp      z,      ADSRenvelopeSustain
        ;

doTrackSoundOut:
;===============================================================================
        ld      A,      [IX+Track.channelFrequencyPSG]
        cp      $E0
        jr      nz,     @doModulation
        ld      C,      [IX+Track.noiseMode]
        ld      A,      [noiseMode]
        cp      C
        jp      z,      @sendVolume
        ld      A,      C
        ld      [noiseMode],    A
        or      %11100000               ; noise channel frequency?
        out     [SMS_PORTS_PSG],        A
        jp      @sendVolume

@doModulation:
        ld      E,      [IX+Track.modulationFreq+0]
        ld      D,      [IX+Track.modulationFreq+1]
        ld      A,      [IX+Track.modulationDelay]
        and     A
        jr      z,      @_1
        dec     [IX+Track.modulationDelay]
        jp      @sendFrequency

@_1:    dec     [IX+Track.modulationStepDelay]
        jp      nz,     @sendFrequency
        ld      A,      [IX+$15]
        ld      [IX+Track.modulationStepDelay], A
        ld      L,      [IX+Track.modulationFreqDelta+0]
        ld      H,      [IX+Track.modulationFreqDelta+1]
        dec     [IX+Track.modulationStepCount]
        jp      nz,     @_2
        ld      A,      [IX+Track.initModulationStepCount]
        ld      [IX+Track.modulationStepCount], A
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      [IX+Track.modulationFreqDelta+0],       L
        ld      [IX+Track.modulationFreqDelta+1],       H
        jp      @sendFrequency

@_2:    add     HL,     DE
        ld      [IX+Track.modulationFreq+0],    L
        ld      [IX+Track.modulationFreq+1],    H
        ex      DE,     HL

        ;-----------------------------------------------------------------------

@sendFrequency:
        ld      L,      [IX+Track.noteFrequencey]
        ld      H,      [IX+Track.noteFrequencey+1]
        ld      C,      [IX+Track.detune+0]
        ld      B,      [IX+Track.detune+1]
        add     HL,     BC
        add     HL,     DE
        ld      A,      [IX+Track.octave]
        and     A
        jr      z,      @_4
        ld      B,      A

@_3:    srl     H
        rr      L
        djnz    @_3

@_4:    ld      A,      L
        and     %00001111
        or      [IX+Track.channelFrequencyPSG]
        out     [SMS_PORTS_PSG],       A
        ld      A,      H
        rlca
        rlca
        rlca
        rlca
        and     %11110000
        ld      C,      A
        ld      A,      L
        rrca
        rrca
        rrca
        rrca
        and     %00001111
        or      c
        out     [SMS_PORTS_PSG],       A

@sendVolume:
        ld      A,      [IX+Track.fadeTicks+1]
        and     A
        jr      z,      @_5
        ld      C,      A
        ld      A,      [IX+Track.envelopeLevel]
        and     A
        jr      z,      @_5
        ld      L,      A
        ld      H,      $00
        call    calcTickTime
        rl      L
        ld      A,      $00
        adc     A,      H
@_5:    and     [IX+Track.effectiveVolume]
        xor     %00001111
        or      [IX+Track.channelVolumePSG]
        out     [SMS_PORTS_PSG],        A
        ld      A,      [playbackMode]
        and     %00001000
        ret     z
        ld      A,      [IX+Track.id]
        cp      $04
        ret     z
        ld      L,      [IX+Track.fadeTicks+0]
        ld      H,      [IX+Track.fadeTicks+1]
        ld      BC,     [fadeTicksDecrement]
        sbc     HL,     BC
        jr      nc,     @_6
        ld      HL,     $0000
@_6:    ld      [IX+Track.fadeTicks+0], L
        ld      [IX+Track.fadeTicks+1], H
        ret
        ;

PSGfrequencyValues:
;===============================================================================

        .WORD   $0356 $0326 $02F9 $02CE $02A5 $0280 $025C $023A
        .WORD   $021A $01FB $01DF $01C4 $03F7 $03BE $0388
        ;

doCommand:
;===============================================================================
        cp      $FF
        jp      z,      cmdFF_stopMusic
        cp      $fE
        jp      z,      cmdFE_stopSFX
        inc     DE
        ld      HL,     commandPointers
        add     A,      A
        ld      C,      A
        ld      B,      $00
        add     HL,     BC
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        jp      [HL]
        ;

cmdFF_stopMusic:
;===============================================================================
        ld      L,      [IX+Track.masterLoopAddress+0]
        ld      H,      [IX+Track.masterLoopAddress+1]
        ld      A,      L
        or      H
        jr      z,      cmdFE_stopSFX@stopTrack
        ex      DE,     HL
        jp      doUpdateTrack@trackReadLoop
        ;

cmdFE_stopSFX:
;===============================================================================
        xor     A
        ld      [SFXpriority],  A

@stopTrack:
        res     1,      [IX+Track.flags]
        ld      A,      %00001111
        or      [IX+Track.channelVolumePSG]
        out     [SMS_PORTS_PSG],        A
        ret
        ;

commandPointers:
;===============================================================================
;index  $80

        ;-----------------------------------------------------------------------
        ; TODO: the order of these entries should produce an enum beginning
        ; from $80, as well as exporting simplified constants for their
        ; functions, i.e. "TEMPO"

        .WORD   cmd80_tempo
        .WORD   cmd81_volumeSet
        .WORD   cmd82_setADSR
        .WORD   cmd83_modulation
        .WORD   cmd84_detune
        .WORD   cmd85_dummy
        .WORD   cmd86_loopStart
        .WORD   cmd87_loopEnd
        .WORD   cmd88_masterLoop
        .WORD   cmd89_noiseMode
        .WORD   cmd8A_noteLength
        .WORD   cmd8B_volumeUp
        .WORD   cmd8C_volumeDown
        .WORD   cmd8D_hold
        ;

ADSRenvelopeAttack:
;===============================================================================
        ld      A,      [IX+Track.attackRate]
        add     A,      [IX+Track.envelopeLevel]
        jp      nc,     @_1
        ld      A,      $FF
@_1:    ld      [IX+Track.envelopeLevel],       A
        jp      nc,     doTrackSoundOut
        inc     [IX+Track.ADSRstate]
        jp      doTrackSoundOut
        ;

ADSRenvelopeDecay1:
;===============================================================================
        ld      C,      [IX+Track.decay1Level]
        ld      A,      [IX+Track.envelopeLevel]
        sub     [IX+Track.decay1Rate]
        jr      c,      @_1
        cp      [IX+Track.decay1Level]
        jr      c,      @_1
        ld      C,      A
@_1:    ld      [IX+Track.envelopeLevel],       C
        jp      nc,     doTrackSoundOut
        inc     [IX+Track.ADSRstate]
        jp      doTrackSoundOut
        ;

ADSRenvelopeDecay2:
;===============================================================================
        ld      C,      [IX+Track.decay2Level]
        ld      A,      [IX+Track.envelopeLevel]
        sub     [IX+Track.decay2Rate]
        jr      c,      @_1
        cp      [IX+Track.decay2Level]
        jp      c,      @_1
        ld      C,      A
@_1:    ld      [IX+Track.envelopeLevel],       C
        jp      nc,     doTrackSoundOut
        inc     [IX+Track.ADSRstate]
        jp      doTrackSoundOut
        ;

ADSRenvelopeSustain:
;===============================================================================
        ld      A,      [IX+Track.envelopeLevel]
        sub     [IX+Track.sustainRate]
        jp      nc,     @_1
        ld      A,      $00
@_1:    ld      [IX+Track.envelopeLevel],       A
        jp      nc,     doTrackSoundOut
        inc     [IX+Track.ADSRstate]
        jp      doTrackSoundOut
        ;

cmd80_tempo:
;===============================================================================
        ld      A,      [DE]
        ld      [IX+Track.tempoDivider+0],      A
        ld      [tickMultiplier+0],     A
        inc     DE
        ld      A,      [DE]
        ld      [IX+Track.tempoDivider+1],      A
        ld      [tickMultiplier+1],     A
        inc     DE
        ld      A,      [DE]
        ld      [tickDivider1+0],       A
        ld      [tickDivider2+0],       A
        inc     DE
        ld      A,      [DE]
        ld      [tickDivider1+1],       A
        ld      [tickDivider2+1],       A
        inc     DE
        jp      doUpdateTrack@trackReadLoop
        ;

cmd81_volumeSet:
;===============================================================================
        ld      A,      [DE]
        ld      [IX+Track.channelVolume],       A
        inc     DE
        ld      A,      [IX+Track.id]
        cp      $04
        jr      z,      @_1
        ld      A,      [playbackMode]
        and     %00001000
        jp      nz,     doUpdateTrack@trackReadLoop

@_1:    ld      A,       [IX+Track.channelVolume]
        ld      [IX+Track.fadeTicks+1], A
        ld      [IX+Track.fadeTicks+0], $00
        jp      doUpdateTrack@trackReadLoop
        ;

cmd82_setADSR:
;===============================================================================
        push    IX
        pop     HL
        ld      BC,     $000E
        add     HL,     BC
        ex      DE,     HL
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ex      DE,     HL
        jp      doUpdateTrack@trackReadLoop
        ;

cmd83_modulation:
;===============================================================================
        push    IX
        pop     HL
        ld      BC,     $0014
        add     HL,     BC
        ex      DE,     HL
        ldi
        ldi
        ldi
        ldi
        ldi
        ex      DE,     HL
        jp      doUpdateTrack@trackReadLoop
        ;

cmd84_detune:
;===============================================================================
        ld      A,      [DE]
        ld      [IX+Track.detune+0],    A
        inc     DE
        ld      A,      [DE]
        ld      [IX+Track.detune+1],    A
        inc     DE
        jp      doUpdateTrack@trackReadLoop
        ;

cmd85_dummy:
;===============================================================================
        ld      A,      [DE]
        inc     DE
        jp      doUpdateTrack@trackReadLoop
        ;

cmd86_loopStart:
;===============================================================================
        ld      L,      [IX+Track.loopAddress+0]
        ld      H,      [IX+Track.loopAddress+1]
        ld      [HL],   $00
        ld      BC,     $0005
        add     HL,     BC
        ld      [IX+Track.loopAddress+0],       L
        ld      [IX+Track.loopAddress+1],       H
        jp      doUpdateTrack@trackReadLoop
        ;

cmd87_loopEnd:
;===============================================================================
        ld      L,      [IX+Track.loopAddress+0]
        ld      H,      [IX+Track.loopAddress+1]
        ld      BC,     $FFFB
        add     HL,     BC
        ld      A,      [HL]
        and     A
        jr      nz,     @loopInit
        ld      A,      [DE]
        dec     A
        jr      z,      @_2
        ld      [HL],   A
        jp      @_1

@loopInit:
        dec     [HL]
        jr      z,      @_2
@_1:    ex      DE,     HL
        inc     HL
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ld      C,      [IX+Track.baseAddress+0]
        ld      B,      [IX+Track.baseAddress+1]
        add     HL,     BC
        ex      DE,     HL
        jp      doUpdateTrack@trackReadLoop

@_2:    ld      [IX+Track.loopAddress+0],       L
        ld      [IX+Track.loopAddress+1],       H
        inc     DE
        inc     DE
        inc     DE
        jp      doUpdateTrack@trackReadLoop
        ;

cmd88_masterLoop:
;===============================================================================
        ld      [IX+Track.masterLoopAddress+0], E
        ld      [IX+Track.masterLoopAddress+1], D
        jp      doUpdateTrack@trackReadLoop
        ;

cmd89_noiseMode:
;===============================================================================
        ld      A,      [DE]
        ld      [IX+Track.noiseMode],   A
        inc     DE
        jp      doUpdateTrack@trackReadLoop
        ;

cmd8A_noteLength:
;===============================================================================
        ld      A,      [DE]
        ld      [IX+Track.defaultNoteLength],   A
        inc     DE
        jp      doUpdateTrack@trackReadLoop
        ;

cmd8B_volumeUp:
;===============================================================================
        ld      A,      [IX+Track.channelVolume]
        inc     A
        cp      $10
        jr      c,      @_1
        ld      A,      $0F
@_1:    ld      [IX+Track.channelVolume],       A
        ld      A,      [playbackMode]
        and     %00001000
        jp      nz,     doUpdateTrack@trackReadLoop
        ld      A,      [IX+Track.channelVolume]
        ld      [IX+Track.fadeTicks+1], A
        jp      doUpdateTrack@trackReadLoop
        ;

cmd8C_volumeDown:
;===============================================================================
        ld      A,      [IX+Track.channelVolume]
        dec     A
        cp      $10
        jr      c,      @_1
        xor     A
@_1:    ld      [IX+Track.channelVolume],       A
        ld      A,      [playbackMode]
        and     %00001000
        jp      nz,     doUpdateTrack@trackReadLoop
        ld      A,      [IX+Track.channelVolume]
        ld      [IX+Track.fadeTicks+1], A
        jp      doUpdateTrack@trackReadLoop
        ;

cmd8D_hold:
;===============================================================================
        set     0,      [IX+Track.flags]
        jp      doUpdateTrack@trackReadLoop
        ;

calcTickTime:
;===============================================================================
        xor     A
        ld      B,      $07
        ex      DE,     HL
        ld      L,      A
        ld      H,      A

@_1:    rl      C
        jp      nc,     @_2
        add     HL,     DE
@_2:    add     HL,     HL
        djnz    @_1

        or      C
        ret     z
        add     HL,     DE
        ret
        ;

doPlayMusic:
;===============================================================================
; in    A       index number of music track to play
;-------------------------------------------------------------------------------
        push    HL

        ; look up the index number in the music list
        ld      HL,     music_pointers  ; begin with the table of songs
        add     A,      A               ; each song is a 16-bit pointer
        add     A,      L               ; add that to the list address lo-byte 
        ld      L,      A
        ld      A,      $00
        adc     A,      H               ; add carry to the hi-byte to handle
        ld      H,      A               ; the 8-bit overflow ("$00FF > $0100")

        ; get the pointer to the song
        ; (into HL) from the song list
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A

        call    doLoadMusic

        pop     HL
        ret
        ;

doPlaySFX:
;===============================================================================
; in    A       index number of SFX to play
;-------------------------------------------------------------------------------
        push    HL
        push    DE

        ; look up the index number in the SFX list
        ld      HL,     sfx_pointers    ; begin with the list of SFX
        add     A,      A               ; 4x the index number since the SFX list
        add     A,      A               ; is 4 bytes each entry instead of 2
        ld      E,      A               ; put this index into a 16-bit number
        ld      D,      $00
        add     HL,     DE              ; and offset into the SFX list

        ; load DE with the first value
        ; -- a pointer to the SFX data
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ; the next value acts as a priority level
        ld      A,      [HL]
        ; (note that the SFX list has an extra unused byte on each entry)

        ; swap DE & HL,
        ; - DE will now be an address to SFX entry in the SFX list
        ; - HL will now be the address of the SFX's data
        ex      DE,     HL
        call    doLoadSFX

        pop     DE
        pop     HL
        ret
        ;

music_pointers:                                                         ;$C716
;===============================================================================
; TODO  in the original ROM the order needs to be preserved, and there are
;       unused entries, we'll need a way to specify this for an original build,
;       but use auto-numbering for new builds

@greenHill:                             ; index $00
        .DEFINE MUSIC_ID_GREENHILL      $00
        .EXPORT MUSIC_ID_GREENHILL
        .WORD   music_greenHill         ;=$47D0 [$C7D0]

@bridge:                                ; index $01
        .DEFINE MUSIC_ID_BRIDGE         $01
        .EXPORT MUSIC_ID_BRIDGE
        .WORD   music_bridge            ;=$574A [$D74A]

@jungle:                                ; index $02
        .DEFINE MUSIC_ID_JUNGLE         $02
        .EXPORT MUSIC_ID_JUNGLE
        .WORD   music_jungle            ;=$524A [$D24A]

@labyrinth:                             ; index $03
        .DEFINE MUSIC_ID_LABYRINTH      $03
        .EXPORT MUSIC_ID_LABYRINTH
        .WORD   music_labyrinth         ;=$760C [$F60C]

@scrapBrain:                            ; index $04
        .DEFINE MUSIC_ID_SCRAPBRAIN     $04
        .EXPORT MUSIC_ID_SCRAPBRAIN
        .WORD   music_scrapBrain        ;=$5B4F [$DB4F]

@skyBase:                               ; index $05
        .DEFINE MUSIC_ID_SKYBASE        $05
        .EXPORT MUSIC_ID_SKYBASE
        .WORD   music_skyBase           ;=$61A7 [$E1A7]

@titleScreen:                           ; index $06
        .DEFINE MUSIC_ID_TITLESCREEN    $06
        .EXPORT MUSIC_ID_TITLESCREEN
        .WORD   music_titleScreen       ;=$64C3 [$E4C3]

@mapScreen:                             ; index $07
        .DEFINE MUSIC_ID_MAPSCREEN      $07
        .EXPORT MUSIC_ID_MAPSCREEN
        .WORD   music_mapScreen         ;=$663C [$E63C]

@invincibility:                         ; index $08
        .DEFINE MUSIC_ID_INVINCIBILITY  $08
        .EXPORT MUSIC_ID_INVINCIBILITY
        .WORD   music_invincibility     ;=$6704 [$E704]

@actComplete:                           ; index $09
        .DEFINE MUSIC_ID_ACTCOMPLETE    $09
        .EXPORT MUSIC_ID_ACTCOMPLETE
        .WORD   music_actComplete       ;=$68B4 [$E8B4]

@death:                                 ; index $0A
        .DEFINE MUSIC_ID_DEATH          $0A
        .EXPORT MUSIC_ID_DEATH
        .WORD   music_death             ;=$6991 [$E991]

@boss1:                                 ; index $0B
        .DEFINE MUSIC_ID_BOSS1          $0B
        .EXPORT MUSIC_ID_BOSS1
        .WORD   music_boss              ;=$6AC0 [$EAC0]

@boss2:                                 ; index $0C
        .DEFINE MUSIC_ID_BOSS2          $0C
        .EXPORT MUSIC_ID_BOSS2
        .WORD   music_boss              ;=$6AC0 [$EAC0]

@boss3:                                 ; index $0D
        .DEFINE MUSIC_ID_BOSS3          $0D
        .EXPORT MUSIC_ID_BOSS3
        .WORD   music_boss              ;=$6AC0 [$EAC0]

@ending:                                ; index $0E
        .DEFINE MUSIC_ID_ENDING         $0E
        .EXPORT MUSIC_ID_ENDING
        .WORD   music_ending            ;=$6D54 [$ED54]

        ; an unused entry
@unused1:                               ; index $0F
        .DEFINE MUSIC_ID_UNUSED1        $0F
        .EXPORT MUSIC_ID_UNUSED1
        .WORD   music_greenHill         ;=$47D0 [$C7D0]

@specialStage:                          ; index $10
        .DEFINE MUSIC_ID_SPECIALSTAGE   $10
        .EXPORT MUSIC_ID_SPECIALSTAGE
        .WORD   music_specialStage      ;=$712C [$F12C]

        ; a couple of unused entries
@unused2:                               ; index $11
        .DEFINE MUSIC_ID_UNUSED2        $11
        .EXPORT MUSIC_ID_UNUSED2
        .WORD   music_greenHill         ;=$47D0 [$C7D0]
@unused3:                               ; index $12
        .DEFINE MUSIC_ID_UNUSED3        $12
        .EXPORT MUSIC_ID_UNUSED3
        .WORD   music_greenHill         ;=$47D0 [$C7D0]

@allEmeralds:                           ; index $13
        .DEFINE MUSIC_ID_ALLEMERALDS    $13
        .EXPORT MUSIC_ID_ALLEMERALDS
        .WORD   music_allEmeralds       ;=$798C [$F98C]

@emerald:                               ; index $14
        .DEFINE MUSIC_ID_EMERALD        $14
        .EXPORT MUSIC_ID_EMERALD
        .WORD   music_emerald           ;=$7A26 [$FA26]

;;%sfxHeader
;;@overriddenTrack:                       %byte
;;@tempoDivider:                          %word
;;@tickDivider:                           %word
;;@unused:                                %byte

sfx_pointers:                                                           ;$C740
;===============================================================================
        .DEFINE SFX_ID_00       $00
        .EXPORT SFX_ID_00
        .WORD   sfx_fb27        $0002   ;=$7B27 [$FB27]
        
        .DEFINE SFX_ID_01       $01
        .EXPORT SFX_ID_01
        .WORD   sfx_fb43        $0002   ;=$7B43 [$FB43]
        
        .DEFINE SFX_ID_02       $02
        .EXPORT SFX_ID_02
        .WORD   sfx_fb74        $0002   ;=$7B74 [$FB74]
        
        .DEFINE SFX_ID_03       $03
        .EXPORT SFX_ID_03
        .WORD   sfx_fb98        $0002   ;=$7B98 [$FB98]
        
        .DEFINE SFX_ID_04       $04
        .EXPORT SFX_ID_04
        .WORD   sfx_fbbf        $0002   ;=$7BBF [$FBBF]
        
        .DEFINE SFX_ID_05       $05
        .EXPORT SFX_ID_05
        .WORD   sfx_fbe6        $0002   ;=$7BE6 [$FBE6]
        
        .DEFINE SFX_ID_06       $06
        .EXPORT SFX_ID_06
        .WORD   sfx_fc18        $0002   ;=$7C18 [$FC18]
        
        .DEFINE SFX_ID_07       $07
        .EXPORT SFX_ID_07
        .WORD   sfx_fc42        $0002   ;=$7C42 [$FC42]
        
        .DEFINE SFX_ID_08       $08
        .EXPORT SFX_ID_08
        .WORD   sfx_fc5e        $0001   ;=$7C5E [$FC5E]
        
        .DEFINE SFX_ID_09       $09
        .EXPORT SFX_ID_09
        .WORD   sfx_fc8e        $0001   ;=$7C8E [$FC8E]
        
        .DEFINE SFX_ID_0A       $0A
        .EXPORT SFX_ID_0A
        .WORD   sfx_fcb7        $0002   ;=$7CB7 [$FCB7]
        
        .DEFINE SFX_ID_0B       $0B
        .EXPORT SFX_ID_0B
        .WORD   sfx_fcd8        $0001   ;=$7CD8 [$FCD8]
        
        .DEFINE SFX_ID_0C       $0C
        .EXPORT SFX_ID_0C
        .WORD   sfx_fcfd        $0001   ;=$7CFD [$FCFD]
        
        .DEFINE SFX_ID_0D       $0D
        .EXPORT SFX_ID_0D
        .WORD   sfx_fd24        $0001   ;=$7D24 [$FD24]
        
        .DEFINE SFX_ID_0E       $0E
        .EXPORT SFX_ID_0E
        .WORD   sfx_fd62        $0002   ;=$7D62 [$FD62]
        
        .DEFINE SFX_ID_0F       $0F
        .EXPORT SFX_ID_0F
        .WORD   sfx_fd62        $0001   ;=$7D62 [$FD62]
        
        .DEFINE SFX_ID_10       $10
        .EXPORT SFX_ID_10
        .WORD   sfx_fd62        $0002   ;=$7D62 [$FD62]
        
        .DEFINE SFX_ID_11       $11
        .EXPORT SFX_ID_11
        .WORD   sfx_fd62        $0002   ;=$7D62 [$FD62]
        
        .DEFINE SFX_ID_12       $12
        .EXPORT SFX_ID_12
        .WORD   sfx_fd88        $0002   ;=$7D88 [$FD88]
        
        .DEFINE SFX_ID_13       $13
        .EXPORT SFX_ID_13
        .WORD   sfx_fdb1        $0001   ;=$7DB1 [$FDB1]
        
        .DEFINE SFX_ID_14       $14
        .EXPORT SFX_ID_14
        .WORD   sfx_fdb1        $0002   ;=$7DB1 [$FDB1]
        
        .DEFINE SFX_ID_15       $15
        .EXPORT SFX_ID_15
        .WORD   sfx_fdb1        $0002   ;=$7DB1 [$FDB1]
        
        .DEFINE SFX_ID_16       $16
        .EXPORT SFX_ID_16
        .WORD   sfx_fdb1        $0002   ;=$7DB1 [$FDB1]
        
        .DEFINE SFX_ID_17       $17
        .EXPORT SFX_ID_17
        .WORD   sfx_fde6        $0001   ;=$7DE6 [$FDE6]
        
        .DEFINE SFX_ID_18       $18
        .EXPORT SFX_ID_18
        .WORD   sfx_fe0c        $0001   ;=$7E0C [$FE0C]
        
        .DEFINE SFX_ID_19       $19
        .EXPORT SFX_ID_19
        .WORD   sfx_fe2f        $0002   ;=$7E2F [$FE2F]
        
        .DEFINE SFX_ID_1A       $1A
        .EXPORT SFX_ID_1A
        .WORD   sfx_fe48        $0001   ;=$7E48 [$FE48]
        
        .DEFINE SFX_ID_1B       $1B
        .EXPORT SFX_ID_1B
        .WORD   sfx_fe5c        $0001   ;=$7E5C [$FE5C]
        
        .DEFINE SFX_ID_1C       $1C
        .EXPORT SFX_ID_1C
        .WORD   sfx_fe74        $0001   ;=$7E74 [$FE74]
        
        .DEFINE SFX_ID_1D       $1D
        .EXPORT SFX_ID_1D
        .WORD   sfx_fea4        $0001   ;=$7EA4 [$FEA4]
        
        .DEFINE SFX_ID_1E       $1E
        .EXPORT SFX_ID_1E
        .WORD   sfx_fecc        $0002   ;=$7ECC [$FECC]
        
        .DEFINE SFX_ID_1F       $1F
        .EXPORT SFX_ID_1F
        .WORD   sfx_fecc        $0002   ;=$7ECC [$FECC]
        
        .DEFINE SFX_ID_20       $20
        .EXPORT SFX_ID_20
        .WORD   sfx_fee8        $0002   ;=$7EE8 [$FEE8]
        
        .DEFINE SFX_ID_21       $21
        .EXPORT SFX_ID_21
        .WORD   sfx_ff08        $0001   ;=$7F08 [$FF08]
        
        .DEFINE SFX_ID_22       $22
        .EXPORT SFX_ID_22
        .WORD   sfx_ff4e        $0001   ;=$7F4E [$FF4E]
        
        .DEFINE SFX_ID_23       $23
        .EXPORT SFX_ID_23
        .WORD   sfx_ff83        $0002   ;=$7F83 [$FF83]
        ;

music_greenHill:                                                        ;$C7D0
;===============================================================================
@header:

        .WORD   @channel1 - @header     ; offset to channel 1
        .WORD   @channel2 - @header     ; offset to channel 2
        .WORD   @channel3 - @header     ; offset to channel 3
        .WORD   @channel4 - @header     ; offset to channel 4
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $82 $FF $14 $96 $00 $32 $0A
        .BYTE   $85 $FF
        .BYTE   $83 $0C $01 $04 $05 $00
        .BYTE   $81 $0C
        .BYTE   $8A $06
        .BYTE   $29 $00 $25 $00 $29 $00 $25 $00 $2B $00 $27 $00 $2B $00 $27 $00
        .BYTE   $30 $00 $29 $00 $30 $00 $29 $00 $32 $00 $2B $00 $32 $00 $2B $00
        .BYTE   $8A $0C
        .BYTE   $1B $18 $7F $00 $19 $18 $7F $00 $1B $18 $7F $00 $19 $18 $7F $00
        .BYTE   $1B $00 $7F $00 $19 $00 $7F $00 $20 $18 $7F $00 $1B $18 $7F $00
        .BYTE   $19 $18 $8D $19 $30 $8D $19 $24 $7F $00 $19 $18 $7F $00 $1B $18
        .BYTE   $7F $00 $20 $18 $19 $18 $7F $00 $1B $18 $7F $00 $20 $18 $20 $24
        .BYTE   $1B $00 $8D $1B $30 $8D $1B $30 $8D $1B $18 $7F $18
        .BYTE   $88
        .BYTE   $7F $30 $20 $00 $19 $18 $20 $00 $1B $18 $20 $00 $1B $18 $17 $24
        .BYTE   $8D $17 $00 $7F $18 $19 $00 $24 $00 $22 $18 $20 $00 $1B $18
        .BYTE   $20 $00 $1B $18 $17 $24 $7F $30 $20 $00 $19 $18 $20 $00 $1B $18
        .BYTE   $20 $00 $1B $18 $17 $24 $8D $17 $00 $7F $18 $19 $00 $19 $00
        .BYTE   $15 $18 $19 $00 $17 $18 $19 $00 $17 $18 $10 $24 $7F $30 $20 $00
        .BYTE   $19 $18 $20 $00 $1B $18 $20 $00 $1B $18 $17 $24 $8D $17 $00
        .BYTE   $7F $18 $19 $00 $24 $00 $22 $18 $20 $00 $1B $18 $20 $00 $1B $18
        .BYTE   $17 $24 $7F $30 $20 $00 $19 $18 $20 $00 $1B $18 $20 $00 $1B $18
        .BYTE   $17 $24 $8D $17 $00 $7F $18 $19 $00 $19 $00 $15 $18 $19 $00
        .BYTE   $17 $18 $19 $00 $17 $18 $10 $18 $14 $00 $12 $30 $8D $12 $30
        .BYTE   $8D $12 $30 $8D $12 $00 $10 $00 $12 $00 $14 $00 $8D $14 $30
        .BYTE   $8D $14 $30 $8D $14 $30 $8D $14 $00 $10 $00 $19 $00 $13 $00
        .BYTE   $8D $13 $30 $8D $13 $30 $8D $13 $30 $8D $13 $00 $10 $00 $13 $00
        .BYTE   $12 $00 $8D $12 $48 $8D $12 $00 $24 $18 $24 $00 $25 $00 $24 $00
        .BYTE   $27 $00 $24 $00 $24 $00 $20 $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $1E $96 $00 $32 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $0C
        .BYTE   $7F $00 $0C $00 $09 $00 $0C $00 $0D $00 $0A $00 $0E $00 $0B $00
        .BYTE   $86
@a:     .BYTE   $00 $06
        .BYTE   $8C $8C $8C $8C
        .BYTE   $00 $06
        .BYTE   $8B $8B $8B $8B
        .BYTE   $87 $18
        .WORD   @a - @header
        .BYTE   $00 $00 $00 $00 $0C $00 $0C $00 $0D $00 $0D $00 $0E $00 $0E $00
        .BYTE   $86
@b:     .BYTE   $00 $06
        .BYTE   $8C $8C $8C $8C
        .BYTE   $00 $06
        .BYTE   $8B $8B $8B $8B
        .BYTE   $87 $1E
        .WORD   @b - @header
        .BYTE   $02 $00 $04 $00
        .BYTE   $88
        .BYTE   $86
@c:     .BYTE   $05 $00 $05 $00 $15 $00 $05 $00 $05 $00 $05 $00 $15 $00 $05 $00
        .BYTE   $04 $00 $04 $00 $14 $00 $04 $00 $04 $00 $00 $00 $02 $00 $04 $00
        .BYTE   $87 $02
        .WORD   @c - @header
        .BYTE   $05 $00 $05 $00 $15 $00 $05 $00 $05 $00 $05 $00 $15 $00 $05 $00
        .BYTE   $04 $00 $04 $00 $14 $00 $04 $00 $04 $00 $04 $00 $14 $00 $04 $00
        .BYTE   $02 $00 $02 $00 $12 $00 $02 $00 $02 $00 $02 $00 $12 $00 $02 $00
        .BYTE   $00 $00 $00 $00 $10 $00 $00 $00 $00 $00 $00 $00 $02 $00 $04 $00
        .BYTE   $86
@d:     .BYTE   $05 $00 $05 $00 $15 $00 $05 $00 $05 $00 $05 $00 $15 $00 $05 $00
        .BYTE   $04 $00 $04 $00 $14 $00 $04 $00 $04 $00 $00 $00 $02 $00 $04 $00
        .BYTE   $87 $02
        .WORD   @d - @header
        .BYTE   $05 $00 $05 $00 $15 $00 $05 $00 $05 $00 $05 $00 $15 $00 $05 $00
        .BYTE   $04 $00 $04 $00 $14 $00 $04 $00 $04 $00 $04 $00 $14 $00 $04 $00
        .BYTE   $02 $00 $02 $00 $12 $00 $02 $00 $02 $00 $02 $00 $12 $00 $02 $00
        .BYTE   $00 $00 $00 $00 $10 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $0A $24 $09 $24 $07 $24 $05 $24 $04 $18 $02 $18
        .BYTE   $8A $24
        .BYTE   $0C $00 $0E $00 $00 $00 $02 $00 $04 $18 $09 $18 $08 $00 $07 $00
        .BYTE   $05 $00 $03 $00 $02 $18 $00 $18 $07 $24 $02 $24 $07 $24
        .BYTE   $8A $0C
        .BYTE   $07 $00 $04 $00 $04 $00 $05 $00 $05 $00 $06 $00 $07 $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $1E $82 $00 $32 $0A
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $19 $00 $15 $00 $19 $00 $15 $00 $1B $00 $17 $00 $1B $00 $17 $00
        .BYTE   $20 $00 $19 $00 $20 $00 $19 $00 $22 $00 $1B $00 $22 $00 $1B $00
        .BYTE   $30 $00
        .BYTE   $81 $04 $30 $00
        .BYTE   $81 $09 $2B $00
        .BYTE   $81 $04 $30 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $04 $2B $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $04 $29 $00
        .BYTE   $86
@e:     .BYTE   $81 $09 $30 $00
        .BYTE   $81 $04 $27 $00
        .BYTE   $81 $09 $2B $00
        .BYTE   $81 $04 $30 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $04 $2B $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $04 $29 $00
        .BYTE   $87 $0F
        .WORD   @e - @header
        .BYTE   $88
        .BYTE   $84 $04 $00
        .BYTE   $81 $09
        .BYTE   $8A $0C
        .BYTE   $7F $30 $20 $00 $19 $18 $20 $00 $1B $18 $20 $00 $1B $18
        .BYTE   $8C $27 $06 $29 $06 $30 $00 $29 $00 $7F $24
        .BYTE   $8B $19 $00 $24 $00 $22 $18 $20 $00 $1B $18 $20 $00 $1B $18
        .BYTE   $8C $27 $06 $29 $06 $30 $00 $34 $00
        .BYTE   $8B $7F $30 $20 $00 $19 $18 $20 $00 $1B $18 $20 $00 $1B $18
        .BYTE   $8C $27 $06 $29 $06 $30 $00 $29 $00 $7F $24
        .BYTE   $8B $19 $00 $19 $00 $15 $18 $19 $00 $17 $18 $19 $00 $17 $18
        .BYTE   $10 $24
        .BYTE   $8A $06
        .BYTE   $86
@f:     .BYTE   $86
        .BYTE   $81 $09 $30 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $05 $29 $00
        .BYTE   $81 $09 $22 $00
        .BYTE   $81 $05 $25 $00
        .BYTE   $87 $02 $A3 $03
        .BYTE   $81 $09 $2B $00
        .BYTE   $81 $05 $22 $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $05 $2B $00
        .BYTE   $81 $09 $32 $00
        .BYTE   $81 $05 $27 $00
        .BYTE   $81 $09 $2B $00
        .BYTE   $81 $05 $32 $00
        .BYTE   $81 $09 $2B $00
        .BYTE   $81 $05 $2B $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $05 $2B $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $05 $27 $00
        .BYTE   $81 $09 $24 $00
        .BYTE   $81 $05 $27 $00
        .BYTE   $87 $03
        .WORD   @f - @header            ;=$A2, $03
        .BYTE   $81 $09 $30 $00
        .BYTE   $81 $05 $24 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $05 $29 $00
        .BYTE   $81 $09 $22 $00
        .BYTE   $81 $05 $25 $00
        .BYTE   $81 $09 $30 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $05 $29 $00
        .BYTE   $8A $0C
        .BYTE   $81 $09 $34 $00
        .BYTE   $81 $05 $34 $00
        .BYTE   $81 $09 $30 $00
        .BYTE   $81 $05 $34 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $29 $00 $30 $00 $34 $00
        .BYTE   $8A $06
        .BYTE   $86
@g:     .BYTE   $81 $09 $2A $00
        .BYTE   $81 $05 $2A $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $05 $2A $00
        .BYTE   $81 $09 $32 $00
        .BYTE   $81 $05 $25 $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $05 $32 $00
        .BYTE   $87 $04
        .WORD   @g - @header
        .BYTE   $86
@h:     .BYTE   $81 $09 $29 $00
        .BYTE   $81 $05 $29 $00
        .BYTE   $81 $09 $24 $00
        .BYTE   $81 $05 $29 $00
        .BYTE   $81 $09 $30 $00
        .BYTE   $81 $05 $24 $00
        .BYTE   $81 $09 $24 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $87 $04
        .WORD   @h - @header
        .BYTE   $86
@i:     .BYTE   $81 $09 $28 $00
        .BYTE   $81 $05 $28 $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $05 $28 $00
        .BYTE   $81 $09 $30 $00
        .BYTE   $81 $05 $23 $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $87 $04
        .WORD   @i - @header            ;=$B2, $04
        .BYTE   $86
@j:     .BYTE   $81 $09 $30 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $05 $30 $00
        .BYTE   $81 $09 $34 $00
        .BYTE   $81 $05 $29 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $05 $34 $00
        .BYTE   $87 $04
        .WORD   @j - @header            ;=$D7, $04
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $8A $0C
        .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00 $71 $00 $71 $00
        .BYTE   $88
        .BYTE   $86
@k:     .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $0F
        .WORD   @k - @header            ;=$1C, $05
        .BYTE   $70 $00
        .BYTE   $81 $0C $71 $00 $71 $00 $71 $00
        .BYTE   $FF

        .BYTE   $00
        ;

music_marble:                                                           ;$CD0A
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;$000A
        .WORD   @channel2 - @header     ;$00D8
        .WORD   @channel3 - @header     ;$01CC
        .WORD   @channel4 - @header     ;$0505
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $82 $AF $14 $A0 $00 $05 $01
        .BYTE   $8A $0C
        .BYTE   $81 $0B $09 $00 $0B $00 $10 $00 $14 $00
        .BYTE   $88
        .BYTE   $81 $0C
        .BYTE   $83 $0C $01 $04 $06 $00
        .BYTE   $86
@a:     .BYTE   $1B $18 $1B $00 $19 $00
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$2E, $00
        .BYTE   $1B $00 $19 $00 $14 $00 $10 $00 $17 $18 $19 $00 $15 $30
        .BYTE   $8D $15 $30 $8D $15 $30 $7F $00
        .BYTE   $86
@b:     .BYTE   $19 $18 $19 $00 $17 $00
        .BYTE   $87 $03
        .WORD   @b - @header            ;=$4F, $00
        .BYTE   $19 $18 $1B $18 $15 $24 $14 $30 $8D $14 $30 $7F $00 $09 $00
        .BYTE   $0B $00 $10 $00 $14 $00
        .BYTE   $86
@c:     .BYTE   $1B $18 $1B $00 $19 $00
        .BYTE   $87 $03
        .WORD   @c - @header            ;=$6F, $00
        .BYTE   $1B $00 $19 $00 $14 $00 $10 $00 $17 $18 $19 $00 $15 $30
        .BYTE   $8D $15 $30 $8D $15 $30 $7F $00 $19 $30 $8D $19 $18 $1B $18
        .BYTE   $18 $30 $8D $18 $12 $7F $06 $1B $00 $7F $00 $1B $24 $19 $00
        .BYTE   $8D $19 $30 $8D $19 $30 $8D $19 $30
        .BYTE   $86
@d:     .BYTE   $29 $00 $30 $06 $29 $06 $30 $00 $29 $00 $2B $00 $27 $00 $22 $00
        .BYTE   $2B $00 $25 $00 $29 $06 $25 $06 $29 $00 $25 $00 $27 $00 $29 $00
        .BYTE   $2B $00 $27 $00
        .BYTE   $87 $02
        .WORD   @d - @header            ;=$AF, $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $0A
        .BYTE   $82 $FF $14 $82 $14 $32 $01
        .BYTE   $7F $30 $88
        .BYTE   $8A $0C
        .BYTE   $81 $0D
        .BYTE   $86
@e:     .BYTE   $0C $00 $0C $00 $04 $00 $04 $00 $02 $00 $02 $00 $04 $00 $04 $00
        .BYTE   $87 $02
        .WORD   @e - @header            ;=$E9, $00
        .BYTE   $86
@f:     .BYTE   $02 $00 $02 $00 $09 $00 $09 $00 $05 $00 $05 $00 $09 $00 $09 $00
        .BYTE   $87 $02
        .WORD   @f - @header            ;=$FE, $00
        .BYTE   $86
@g:     .BYTE   $0E $00 $0E $00 $07 $00 $07 $00 $02 $00 $02 $00 $07 $00 $07 $00
        .BYTE   $87 $02
        .WORD   @g - @header            ;=$13, $01
        .BYTE   $00 $00 $00 $00 $07 $00 $07 $00 $04 $00 $04 $00 $07 $00 $07 $00
        .BYTE   $0E $00 $0E $00 $05 $00 $05 $00 $04 $00 $04 $00 $0E $00 $0E $00
        .BYTE   $86
@h:     .BYTE   $0C $00 $0C $00 $04 $00 $04 $00 $02 $00 $02 $00 $04 $00 $04 $00
        .BYTE   $87 $02
        .WORD   @h - @header            ;=$48, $01
        .BYTE   $86
@i:     .BYTE   $02 $00 $02 $00 $09 $00 $09 $00 $05 $00 $05 $00 $09 $00 $09 $00
        .BYTE   $87 $02
        .WORD   @i - @header            ;=$5D, $01
        .BYTE   $0E $00 $0E $00 $05 $00 $05 $00 $02 $00 $02 $00 $05 $00 $05 $00
        .BYTE   $04 $00 $04 $00 $0B $00 $0B $00 $08 $00 $08 $00 $0B $00 $0B $00
        .BYTE   $86
@j:     .BYTE   $0C $00 $0C $00 $04 $00 $04 $00 $02 $00 $02 $00 $04 $00 $04 $00
        .BYTE   $87 $02
        .WORD   @j - @header            ;=$92, $01
        .BYTE   $86
@k:     .BYTE   $09 $00 $09 $00 $09 $00 $09 $00 $07 $00 $07 $00 $07 $00 $07 $00
        .BYTE   $05 $00 $05 $00 $05 $00 $05 $00 $07 $00 $07 $00 $07 $00 $07 $00
        .BYTE   $87 $02
        .WORD   @k - @header            ;=$A7, $01
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $84 $04 $00
        .BYTE   $82 $B9 $14 $82 $00 $05 $01
        .BYTE   $8A $0C
        .BYTE   $81 $0A
        .BYTE   $09 $00 $0B $00 $10 $00 $14 $00
        .BYTE   $88
        .BYTE   $81 $09
        .BYTE   $83 $0C $01 $04 $06 $00
        .BYTE   $7F $0C
        .BYTE   $86
@l:     .BYTE   $1B $18 $1B $00 $19 $00
        .BYTE   $87 $03
        .WORD   @l - @header            ;=$EE, $01
        .BYTE   $1B $00 $19 $00 $14 $00 $10 $00 $17 $18 $19 $00 $15 $00
        .BYTE   $8D $15 $24
        .BYTE   $8A $03
        .BYTE   $8B $84 $00 $00
        .BYTE   $35 $00
        .BYTE   $8C $8C $8C $35 $00
        .BYTE   $8B $8B $8B $32 $00
        .BYTE   $8C $8C $8C $35 $00
        .BYTE   $8B $8B $8B $29 $00
        .BYTE   $8C $8C $8C $32 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $29 $00
        .BYTE   $8B $8B $8B $32 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $29 $00
        .BYTE   $8C $8C $8C $32 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $29 $00
        .BYTE   $8B $8B $8B $22 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $29 $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $29 $00
        .BYTE   $8B $8B $8B $22 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $19 $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $22 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $19 $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B $15 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $8C
        .BYTE   $84 $04 $00
        .BYTE   $8A $0C
        .BYTE   $7F $00
        .BYTE   $86
@m:     .BYTE   $19 $18 $19 $00 $17 $00
        .BYTE   $87 $03
        .WORD   @m - @header            ;=$B8, $02
        .BYTE   $19 $18 $1B $18 $15 $24 $14 $00 $8D $14 $18
        .BYTE   $84 $00 $00
        .BYTE   $8B $35 $0C
        .BYTE   $8C $8C $8C $35 $0C
        .BYTE   $8B $8B $8B $35 $06
        .BYTE   $8C $8C $8C $35 $06
        .BYTE   $8B $8B $8B $32 $0C
        .BYTE   $8C $8C $8C $35 $0C
        .BYTE   $8B $8B $8B $2B $06
        .BYTE   $8C $8C $8C $32 $06
        .BYTE   $8B $8B $8B $28 $24
        .BYTE   $81 $09
        .BYTE   $7F $0C
        .BYTE   $86
@n:     .BYTE   $1B $18 $1B $00 $19 $00
        .BYTE   $87 $03
        .WORD   @n - @header            ;=$00, $03
        .BYTE   $1B $00 $19 $00 $14 $00 $10 $00 $17 $18 $19 $00 $15 $00
        .BYTE   $8D $15 $24
        .BYTE   $8A $03
        .BYTE   $8B
        .BYTE   $84 $00 $00
        .BYTE   $35 $00
        .BYTE   $8C $8C $8C $35 $00
        .BYTE   $8B $8B $8B $32 $00
        .BYTE   $8C $8C $8C $35 $00
        .BYTE   $8B $8B $8B $29 $00
        .BYTE   $8C $8C $8C $32 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $29 $00
        .BYTE   $8B $8B $8B $32 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $29 $00
        .BYTE   $8C $8C $8C $32 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $29 $00
        .BYTE   $8B $8B $8B $22 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $29 $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $29 $00
        .BYTE   $8B $8B $8B $22 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $19 $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B $25 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $22 $00
        .BYTE   $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $19 $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B $15 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $8C
        .BYTE   $8A $0C
        .BYTE   $7F $0C $19 $30 $8D $19 $18 $1B $18 $18 $30 $8D $18 $12 $7F $06
        .BYTE   $1B $00 $7F $00 $1B $24 $19 $00 $8D $19 $18
        .BYTE   $8B $34 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $34 $00 $32 $00
        .BYTE   $8C $8C $8C $34 $00
        .BYTE   $8B $8B $8B $30 $06
        .BYTE   $8C $8C $8C $34 $06
        .BYTE   $8B $8B $8B $2B $24
        .BYTE   $81 $0B
        .BYTE   $8A $06
        .BYTE   $7F $0C $24 $00
        .BYTE   $8C $8C $8C $24 $00
        .BYTE   $8B $8B $8B $20 $00
        .BYTE   $8C $8C $8C $24 $00
        .BYTE   $8B $8B $8B
        .BYTE   $86
@o:     .BYTE   $19 $00
        .BYTE   $8C $8C $8C $24 $00
        .BYTE   $8C
        .BYTE   $87 $02
        .WORD   @o - @header            ;=$1D, $04
        .BYTE   $81 $0B
        .BYTE   $22 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $1B $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B
        .BYTE   $86
@p:     .BYTE   $17 $00
        .BYTE   $8C $8C $8C $1B $00
        .BYTE   $8C
        .BYTE   $87 $02
        .WORD   @p - @header            ;=$40, $04
        .BYTE   $81 $0B $20 $00
        .BYTE   $8C $8C $8C $17 $00
        .BYTE   $8B $8B $8B $19 $00
        .BYTE   $8C $8C $8C $20 $00
        .BYTE   $8B $8B $8B
        .BYTE   $86
@q:     .BYTE   $15 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8C
        .BYTE   $87 $02
        .WORD   @q - @header            ;=$63, $04
        .BYTE   $81 $0B $22 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $1B $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B
        .BYTE   $86
@r:     .BYTE   $17 $00
        .BYTE   $8C $8C $8C $1B $00
        .BYTE   $8C
        .BYTE   $87 $02
        .WORD   @r - @header            ;=$86, $04
        .BYTE   $81 $0B $24 $00
        .BYTE   $8C $8C $8C $17 $00
        .BYTE   $8B $8B $8B $20 $00
        .BYTE   $8C $8C $8C $24 $00
        .BYTE   $8B $8B $8B
        .BYTE   $86
@s:     .BYTE   $19 $00
        .BYTE   $8C $8C $8C $24 $00
        .BYTE   $8C
        .BYTE   $87 $02
        .WORD   @s - @header            ;=$A9, $04
        .BYTE   $81 $0B $22 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B $1B $00
        .BYTE   $8C $8C $8C $22 $00
        .BYTE   $8B $8B $8B
        .BYTE   $86
@t:     .BYTE   $17 $00
        .BYTE   $8C $8C $8C $1B $00
        .BYTE   $8C
        .BYTE   $87 $02
        .WORD   @t - @header            ;=$CC, $04
        .BYTE   $81 $0B $20 $00
        .BYTE   $8C $8C $8C $17 $00
        .BYTE   $8B $8B $8B $19 $00
        .BYTE   $8C $8C $8C $20 $00
        .BYTE   $8B $8B $8B $15 $00
        .BYTE   $8C $8C $8C $19 $00
        .BYTE   $8B $8B $8B
        .BYTE   $8A $0C
        .BYTE   $81 $0C $09 $00 $0B $00 $10 $00 $14 $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $0C
        .BYTE   $70 $00 $7F $00 $70 $00 $7F $00
        .BYTE   $88
        .BYTE   $86
@u:     .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $20
        .WORD   @u - @header            ;=$13, $05
        .BYTE   $86
@v:     .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $87 $08
        .WORD   @v - @header            ;=$26, $05
        .BYTE   $FF

        .BYTE   $00 $00 $00 $00 $00 $00 $00
        ;

music_jungle:                                                           ;$D24A
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$0198
        .WORD   @channel3 - @header     ;=$0325
        .WORD   @channel4 - @header     ;=$04AA
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $88
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $06
        .BYTE   $7F $12 $29 $00 $7F $0C $26 $0C $29 $00 $7F $0C $2B $00 $7F $0C
        .BYTE   $26 $00 $7F $0C $26 $00 $7F $0C $24 $00 $22 $00 $7F $0C $1B $00
        .BYTE   $7F $0C $22 $00 $7F $00 $22 $00 $24 $00 $7F $00 $26 $00 $7F $0C
        .BYTE   $24 $0C $8D $24 $30 $7F $12 $7F $12 $1B $12 $22 $12 $2B $12
        .BYTE   $29 $12 $26 $0C $22 $00 $7F $0C $24 $00 $26 $00 $7F $0C $27 $00
        .BYTE   $7F $0C $27 $00 $7F $0C $28 $00 $7F $0C $28 $00 $7F $00 $29 $0C
        .BYTE   $8D $29 $30 $7F $12 $7F $12 $29 $00 $7F $0C $26 $0C $29 $00
        .BYTE   $7F $0C $2B $00 $7F $0C $26 $00 $7F $0C $26 $00 $7F $0C $24 $00
        .BYTE   $22 $00 $7F $0C $1B $00 $7F $0C $22 $00 $7F $00 $22 $00 $24 $00
        .BYTE   $7F $00 $26 $00 $7F $0C $24 $0C $8D $24 $30 $7F $12 $7F $12 $1B
        .BYTE   $12 $22 $12 $2B $12 $29 $12 $26 $0C $22 $00 $7F $0C $24 $00 $26
        .BYTE   $00 $7F $0C $24 $00 $7F $0C $24 $00 $7F $00 $24 $00 $19 $0C $1B
        .BYTE   $00 $21 $0C $22 $0C $8D $22 $30 $7F $12
        .BYTE   $8C $8C $7F $12 $2B $03 $27 $03 $7F $0C $2B $03 $27 $03 $7F $0C
        .BYTE   $29 $03 $22 $03 $7F $00 $27 $03 $22 $03 $7F $0C $27 $03 $2B $03
        .BYTE   $7F $0C $27 $03 $2B $03 $2B $03 $32 $03 $7F $0C $27 $03 $2B $03
        .BYTE   $7F $0C $7F $0C $26 $03 $29 $03 $7F $0C $26 $03 $29 $03 $29 $03
        .BYTE   $32 $03 $7F $0C $22 $03 $26 $03 $7F $00
        .BYTE   $86
@a:     .BYTE   $26 $03
        .BYTE   $8C $29 $03
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$36, $01
        .BYTE   $86
@b:     .BYTE   $86
@c:     .BYTE   $26 $03 $29 $03
        .BYTE   $87 $02
        .WORD   @c - @header            ;=$41, $01
        .BYTE   $8B
        .BYTE   $87 $05
        .WORD   @b - @header            ;=$40, $01
        .BYTE   $8C $8C $7F $12 $2B $03 $27 $03 $7F $0C $2B $03 $27 $03 $7F $0C
        .BYTE   $29 $03 $22 $03 $7F $00 $27 $03 $22 $03 $7F $0C
        .BYTE   $8B $8B $27 $00 $7F $0C $27 $00 $29 $00 $7F $0C $2B $00 $7F $0C
        .BYTE   $86
@d:     .BYTE   $29 $00 $7F $00 $7F $00
        .BYTE   $8C $8C $8C
        .BYTE   $87 $04
        .WORD   @d - @header            ;=$7B, $01
        .BYTE   $81 $0D $29 $00 $7F $00 $2B $00 $7F $0C $29 $00 $8D $29 $24
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $06
        .BYTE   $02 $0C $0C $00 $0E $00 $7F $00 $02 $00 $0C $00 $7F $00 $0E $00
        .BYTE   $7F $0C $02 $12 $02 $00 $7F $0C $02 $00 $7F $0C $04 $00 $06 $00
        .BYTE   $7F $0C $07 $00 $7F $0C $07 $00 $7F $00 $07 $00 $08 $00 $7F $0C
        .BYTE   $08 $00 $7F $00 $09 $00 $7F $0C $09 $00 $09 $00 $7F $0C $0C $00
        .BYTE   $7F $00 $0C $00 $0E $00 $7F $00 $0C $00 $07 $0C $02 $00 $07 $00
        .BYTE   $7F $00 $02 $12 $04 $00 $07 $00 $7F $0C $06 $0C $02 $00 $06 $00
        .BYTE   $7F $00 $0E $00 $7F $0C $01 $00 $02 $00 $7F $0C $04 $00 $7F $0C
        .BYTE   $04 $00 $7F $0C $04 $00 $7F $0C $04 $00 $7F $00 $09 $00 $7F $0C
        .BYTE   $04 $00 $11 $0C $0B $00 $09 $0C $07 $00 $04 $00 $7F $00 $0C $00
        .BYTE   $02 $0C $0C $00 $0E $00 $7F $00 $02 $00 $0C $00 $7F $00 $0E $00
        .BYTE   $7F $0C $02 $12 $02 $00 $7F $0C $02 $00 $7F $0C $04 $00 $06 $00
        .BYTE   $7F $0C $07 $00 $7F $0C $07 $00 $7F $00 $07 $00 $08 $00 $7F $0C
        .BYTE   $08 $00 $7F $00 $09 $00 $7F $0C $09 $00 $09 $00 $7F $0C $0C $00
        .BYTE   $7F $00 $0C $00 $0E $00 $7F $00 $0C $00 $07 $0C $02 $00 $07 $00
        .BYTE   $7F $00 $02 $12 $04 $00 $07 $00 $7F $0C $06 $0C $02 $00 $06 $00
        .BYTE   $7F $00 $0E $00 $7F $0C $01 $00 $02 $00 $7F $0C $04 $0C $02 $00
        .BYTE   $04 $00 $7F $00 $04 $00 $09 $00 $7F $00 $0C $00 $0E $00 $7F $00
        .BYTE   $01 $00 $02 $00 $7F $0C $0C $00 $7F $0C $02 $00 $7F $00 $02 $00
        .BYTE   $04 $00 $7F $00 $06 $00
        .BYTE   $8A $12
        .BYTE   $07 $00 $02 $00 $04 $00 $02 $00 $07 $00 $06 $00 $04 $00 $02 $00
        .BYTE   $02 $00 $0C $00 $0E $00 $0C $00 $02 $00 $01 $00 $0E $00 $0C $00
        .BYTE   $07 $00 $02 $00 $04 $00 $02 $00 $07 $00 $06 $00 $04 $00 $02 $00
        .BYTE   $8A $06
        .BYTE   $09 $00 $7F $0C $0C $00 $7F $00 $0D $00 $0E $00 $7F $00 $0D $00
        .BYTE   $0C $00 $7F $0C $09 $00 $7F $00 $0C $00 $7F $0C $0C $00 $0E $00
        .BYTE   $7F $0C $01 $00 $7F $0C
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $84 $04 $00
        .BYTE   $82 $FF $14 $82 $00 $14 $0A
        .BYTE   $81 $0B
        .BYTE   $8A $06
        .BYTE   $7F $12 $26 $00 $7F $0C $22 $0C $26 $00 $7F $0C $26 $00 $7F $0C
        .BYTE   $22 $00 $7F $0C $22 $00 $7F $0C $19 $00 $19 $00 $7F $0C $17 $00
        .BYTE   $7F $0C $17 $00 $7F $0C $1B $00 $7F $00 $1B $00 $7F $0C $19 $00
        .BYTE   $7F $0C $19 $00 $14 $00 $7F $00 $11 $00 $19 $00 $7F $00 $19 $00
        .BYTE   $1B $00 $7F $00 $19 $00 $7F $12 $17 $12 $1B $12 $22 $12 $26 $12
        .BYTE   $19 $0C $19 $00 $7F $0C $1B $00 $1B $00 $7F $0C $1B $00 $7F $0C
        .BYTE   $1B $00 $7F $0C $1B $00 $7F $0C $1B $00 $7F $00 $21 $00 $7F $0C
        .BYTE   $22 $00 $24 $00 $7F $00 $26 $00 $24 $00 $7F $00 $21 $00 $19 $00
        .BYTE   $7F $00 $14 $00 $7F $12 $26 $00 $7F $0C $22 $0C $26 $00 $7F $0C
        .BYTE   $26 $00 $7F $0C $22 $00 $7F $0C $22 $00 $7F $0C $19 $00 $19 $00
        .BYTE   $7F $0C $17 $00 $7F $0C $17 $00 $7F $0C $1B $00 $7F $00 $1B $00
        .BYTE   $7F $0C $19 $00 $7F $0C $19 $00 $14 $00 $7F $00 $11 $00 $19 $00
        .BYTE   $7F $00 $19 $00 $1B $00 $7F $00 $19 $00 $7F $12 $17 $12 $1B $12
        .BYTE   $22 $12 $26 $12 $19 $0C $19 $00 $7F $0C $1B $00 $1B $00 $7F $0C
        .BYTE   $1B $00 $7F $0C $1B $00 $7F $0C $14 $0C $14 $00 $14 $00 $7F $00
        .BYTE   $19 $00 $8D $19 $24 $02 $00 $04 $00 $06 $00 $09 $00 $12 $00
        .BYTE   $16 $00 $27 $00 $7F $0C $27 $00 $7F $0C $27 $00 $7F $0C $22 $00
        .BYTE   $7F $00 $1B $00 $7F $0C $27 $00 $7F $0C $27 $00 $2B $00 $7F $0C
        .BYTE   $27 $00 $7F $0C $7F $0C $26 $00 $7F $0C $26 $00 $29 $00 $7F $0C
        .BYTE   $22 $00 $7F $00 $26 $00 $8D $26 $12 $12 $12 $14 $12 $16 $12
        .BYTE   $17 $12 $27 $00 $7F $0C $27 $00 $7F $0C $22 $00 $7F $00 $1B $00
        .BYTE   $7F $0C $22 $00 $7F $0C $22 $00 $22 $00 $7F $0C $22 $0C $7F $00
        .BYTE   $24 $00 $7F $0C $7F $12 $7F $12 $7F $12 $24 $00 $7F $00 $24 $00
        .BYTE   $7F $0C $24 $00 $8D $24 $24
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $86
@e:     .BYTE   $81 $09 $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0C $71 $00 $7F $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $1F
        .WORD   @e - @header            ;=$AE, $04
        .BYTE   $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0C $71 $00 $71 $00 $71 $00
        .BYTE   $86
@f:     .BYTE   $81 $09 $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0C $71 $00 $7F $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $0C
        .WORD   @f - @header            ;=$D3, $04
        .BYTE   $86
@g:     .BYTE   $70 $00 $7F $0C
        .BYTE   $87 $04
        .WORD   @g - @header            ;=$EA, $04
        .BYTE   $81 $0C
        .BYTE   $86
@h:     .BYTE   $71 $00
        .BYTE   $87 $0C
        .WORD   @h - @header            ;=$F5, $04
        .BYTE   $FF

        .BYTE   $00 $00 $00 $00
        ;

music_bridge:                                                           ;$D74A
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$00FB
        .WORD   @channel3 - @header     ;=$01BC
        .WORD   @channel4 - @header     ;=$03E0
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $82 $FF $14 $A0 $00 $32 $01
        .BYTE   $83 $14 $01 $04 $05 $00
        .BYTE   $8A $0C
        .BYTE   $81 $0C
        .BYTE   $88
        .BYTE   $7F $18 $29 $00 $7F $00 $27 $12 $30 $06 $7F $00 $25 $00 $7F $00
        .BYTE   $25 $00 $25 $00 $7F $00 $24 $12 $29 $06 $7F $00 $22 $00 $7F $00
        .BYTE   $22 $00 $22 $00 $7F $00 $20 $12 $25 $06 $7F $00 $2A $00 $7F $00
        .BYTE   $29 $00 $27 $00 $25 $00 $25 $18 $27 $18 $7F $18 $29 $00 $7F $00
        .BYTE   $27 $12 $30 $06 $7F $00 $25 $00 $7F $00 $25 $00 $25 $00 $7F $00
        .BYTE   $24 $12 $29 $06 $7F $00 $22 $00 $7F $00 $22 $00 $22 $00 $7F $00
        .BYTE   $20 $12 $25 $06 $7F $00 $27 $30 $8D $27 $30 $7F $00 $25 $30
        .BYTE   $8D $25 $00 $25 $00 $27 $00 $28 $00 $28 $24 $27 $30 $7F $00
        .BYTE   $28 $30 $8D $28 $00 $28 $00 $2A $00 $30 $00 $2A $00 $33 $00
        .BYTE   $81 $08 $2A $00
        .BYTE   $81 $0C $2A $00
        .BYTE   $81 $08 $33 $00
        .BYTE   $81 $0C $27 $00
        .BYTE   $81 $08 $2A $00
        .BYTE   $81 $0C $25 $00 $8D $25 $30 $7F $00 $25 $00 $27 $00 $28 $00
        .BYTE   $27 $00 $2A $00
        .BYTE   $81 $08 $27 $00
        .BYTE   $81 $0C $27 $00
        .BYTE   $81 $08 $2A $00
        .BYTE   $81 $0C $23 $00
        .BYTE   $81 $08 $27 $00
        .BYTE   $81 $0C $25 $30 $8D $25 $30 $8D $25 $30 $8D $25 $30 $7F $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------

        .BYTE   $82 $FF $1E $82 $00 $32 $01
        .BYTE   $8A $0C
        .BYTE   $81 $0D
        .BYTE   $88
        .BYTE   $05 $00 $05 $00 $15 $00 $05 $00 $04 $00 $04 $00 $14 $00 $04 $00
        .BYTE   $02 $00 $02 $00 $12 $00 $02 $00 $00 $00 $00 $00 $10 $00 $00 $00
        .BYTE   $0D $00 $0D $00 $0A $00 $0D $00 $0C $00 $0C $00 $09 $00 $0C $00
        .BYTE   $0D $00 $0D $00 $0A $00 $0D $00 $00 $00 $00 $00 $10 $00 $00 $00
        .BYTE   $05 $00 $05 $00 $15 $00 $05 $00 $04 $00 $04 $00 $14 $00 $04 $00
        .BYTE   $02 $00 $02 $00 $12 $00 $02 $00 $00 $00 $00 $00 $10 $00 $00 $00
        .BYTE   $0D $00 $0D $00 $0A $00 $0D $00 $0C $00 $0C $00 $09 $00 $0C $00
        .BYTE   $03 $00 $03 $00 $13 $00 $03 $00 $00 $00 $00 $00 $10 $00 $00 $00
        .BYTE   $86
@a:     .BYTE   $86
@b:     .BYTE   $01 $00 $01 $00 $11 $00 $01 $00
        .BYTE   $87 $02
        .WORD   @b - @header            ;=$89, $01
        .BYTE   $86
@c:     .BYTE   $03 $00 $03 $00 $13 $00 $03 $00
        .BYTE   $87 $02
        .WORD   @c - @header            ;=$96, $01
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$88, $01
        .BYTE   $86
@d:     .BYTE   $05 $00 $05 $00 $15 $00 $05 $00
        .BYTE   $87 $03
        .WORD   @d - @header            ;$A7, $01
        .BYTE   $05 $00 $00 $00 $02 $00 $04 $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $96 $00 $32 $01
        .BYTE   $83 $14 $01 $04 $05 $00
        .BYTE   $81 $08
        .BYTE   $88
        .BYTE   $8A $0C
        .BYTE   $84 $04 $00
        .BYTE   $7F $12 $7F $18 $29 $00 $7F $00 $27 $12 $30 $06 $7F $00 $25 $00
        .BYTE   $7F $00 $25 $00 $25 $00 $7F $00 $24 $12 $29 $06 $7F $00 $22 $00
        .BYTE   $7F $00 $22 $00 $22 $00 $7F $00 $20 $12 $25 $06 $7F $00 $2A $00
        .BYTE   $7F $00 $29 $00 $27 $00 $25 $00 $25 $18 $27 $18 $7F $18 $29 $00
        .BYTE   $7F $00 $27 $12 $30 $06 $7F $00 $25 $00 $7F $00 $25 $00 $25 $00
        .BYTE   $7F $00 $24 $12 $29 $06 $7F $00 $22 $00 $7F $00 $22 $00 $22 $00
        .BYTE   $7F $00 $20 $12 $25 $06 $7F $00 $27 $30 $8D $27 $18 $8D $27 $12
        .BYTE   $84 $00 $00
        .BYTE   $8A $03
        .BYTE   $86
@e:     .BYTE   $86
@f:     .BYTE   $11 $00
        .BYTE   $81 $04 $11 $00
        .BYTE   $81 $08 $08 $00
        .BYTE   $81 $04 $11 $00
        .BYTE   $81 $08 $11 $00
        .BYTE   $81 $04 $08 $00
        .BYTE   $81 $08 $15 $00
        .BYTE   $81 $04 $11 $00
        .BYTE   $81 $08 $18 $00
        .BYTE   $81 $04 $15 $00
        .BYTE   $81 $08 $15 $00
        .BYTE   $81 $04 $18 $00
        .BYTE   $81 $08 $11 $00
        .BYTE   $81 $04 $15 $00
        .BYTE   $81 $08 $08 $00
        .BYTE   $81 $04 $11 $00
        .BYTE   $81 $08
        .BYTE   $87 $02
        .WORD   @f - @header            ;=$48, $02
        .BYTE   $86
@g:     .BYTE   $13 $00
        .BYTE   $81 $04 $0A $00
        .BYTE   $81 $08 $0A $00
        .BYTE   $81 $04 $13 $00
        .BYTE   $81 $08 $13 $00
        .BYTE   $81 $04 $0A $00
        .BYTE   $81 $08 $17 $00
        .BYTE   $81 $04 $13 $00
        .BYTE   $81 $08 $1A $00
        .BYTE   $81 $04 $17 $00
        .BYTE   $81 $08 $17 $00
        .BYTE   $81 $04 $1A $00
        .BYTE   $81 $08 $13 $00
        .BYTE   $81 $04 $17 $00
        .BYTE   $81 $08 $0A $00
        .BYTE   $81 $04 $13 $00
        .BYTE   $81 $08
        .BYTE   $87 $02
        .WORD   @g - @header            ;=$8D, $02
        .BYTE   $87 $02
        .WORD   @e - @header            ;=$47, $02
        .BYTE   $86
@h:     .BYTE   $15 $00
        .BYTE   $81 $04 $11 $00
        .BYTE   $81 $08 $11 $00
        .BYTE   $81 $04 $15 $00
        .BYTE   $81 $08 $15 $00
        .BYTE   $81 $04 $11 $00
        .BYTE   $81 $08 $18 $00
        .BYTE   $81 $04 $15 $00
        .BYTE   $81 $08 $21 $00
        .BYTE   $81 $04 $18 $00
        .BYTE   $81 $08 $18 $00
        .BYTE   $81 $04 $21 $00
        .BYTE   $81 $08 $15 $00
        .BYTE   $81 $04 $18 $00
        .BYTE   $81 $08 $11 $00
        .BYTE   $81 $04 $15 $00
        .BYTE   $81 $08
        .BYTE   $87 $02
        .WORD   @h - @header            ;=$D6, $02
        .BYTE   $17 $00
        .BYTE   $81 $04 $11 $00
        .BYTE   $81 $08 $13 $00
        .BYTE   $81 $04 $17 $00
        .BYTE   $81 $08 $17 $00
        .BYTE   $81 $04 $13 $00
        .BYTE   $81 $08 $1A $00
        .BYTE   $81 $04 $17 $00
        .BYTE   $81 $08 $23 $00
        .BYTE   $81 $04 $1A $00
        .BYTE   $81 $08 $1A $00
        .BYTE   $81 $04 $23 $00
        .BYTE   $81 $08 $17 $00
        .BYTE   $81 $04 $1A $00
        .BYTE   $81 $08 $13 $00
        .BYTE   $81 $04 $17 $00
        .BYTE   $81 $08 $17 $00
        .BYTE   $81 $04 $13 $00
        .BYTE   $81 $08 $13 $00
        .BYTE   $81 $04 $17 $00
        .BYTE   $81 $08 $17 $00
        .BYTE   $81 $04 $13 $00
        .BYTE   $81 $08 $1A $00
        .BYTE   $81 $04 $17 $00
        .BYTE   $81 $08 $23 $00
        .BYTE   $81 $04 $1A $00
        .BYTE   $81 $08 $27 $00
        .BYTE   $81 $04 $23 $00
        .BYTE   $81 $08 $2A $00
        .BYTE   $81 $04 $27 $00
        .BYTE   $81 $08 $27 $00
        .BYTE   $81 $04 $2A $00
        .BYTE   $81 $08
        .BYTE   $86
@i:     .BYTE   $19 $00
        .BYTE   $81 $04 $29 $00
        .BYTE   $81 $08 $15 $00
        .BYTE   $81 $04 $19 $00
        .BYTE   $81 $08 $19 $00
        .BYTE   $81 $04 $15 $00
        .BYTE   $81 $08 $20 $00
        .BYTE   $81 $04 $19 $00
        .BYTE   $81 $08 $25 $00
        .BYTE   $81 $04 $20 $00
        .BYTE   $81 $08 $20 $00
        .BYTE   $81 $04 $25 $00
        .BYTE   $81 $08 $25 $00
        .BYTE   $81 $04 $20 $00
        .BYTE   $81 $08 $29 $00
        .BYTE   $81 $04 $25 $00
        .BYTE   $81 $08
        .BYTE   $87 $04
        .WORD   @i - @header            ;=$9B, $03
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $8A $0C
        .BYTE   $88
        .BYTE   $86
@j:     .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $0F
        .WORD   @j - @header            ;=$E4, $03
        .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00 $71 $06 $71 $06
        .BYTE   $FF
        ;

music_scrapBrain:                                                       ;$DB4F
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$023F
        .WORD   @channel3 - @header     ;=$031D
        .WORD   @channel4 - @header     ;=$0604
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $04 $00 $03 $00
        .BYTE   $85 $FF
        .BYTE   $82 $FF $14 $96 $00 $32 $01
        .BYTE   $8A $06
        .BYTE   $81 $0C
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $22 $00 $24 $00 $25 $00 $27 $00
        .BYTE   $88
        .BYTE   $81 $0C $29 $30 $8D $29 $0C $27 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0C $25 $00 $24 $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0C $22 $0C $8D $22 $30 $8C $8C $25 $00 $24 $00 $25 $00
        .BYTE   $8B $8B $22 $00 $24 $00 $25 $00 $27 $00 $29 $30 $8D $29 $0C
        .BYTE   $27 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0C $25 $00 $24 $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0C $27 $00 $8D $27 $30 $8D $27 $18 $8D $27 $0C
        .BYTE   $81 $09 $12 $00 $14 $00
        .BYTE   $81 $0C $24 $00 $24 $00 $22 $00 $24 $00 $20 $00 $17 $00
        .BYTE   $81 $08 $20 $00
        .BYTE   $81 $0C $20 $00 $8D $20 $30 $22 $00 $22 $00 $24 $00 $25 $00
        .BYTE   $22 $00 $19 $00
        .BYTE   $81 $08 $22 $00
        .BYTE   $81 $0C $22 $00 $8D $22 $30 $24 $00 $24 $00 $25 $00 $27 $00
        .BYTE   $24 $00 $20 $00 $7F $00 $24 $12 $24 $0C $25 $00
        .BYTE   $81 $09 $24 $00
        .BYTE   $81 $0C $27 $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0C $29 $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0C $29 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0C $30 $00 $2A $00
        .BYTE   $81 $09 $30 $00
        .BYTE   $81 $0C $29 $00 $8D $29 $18 $22 $00 $24 $00 $25 $00 $27 $00
        .BYTE   $29 $30 $8D $29 $0C $27 $00 $8C $8C $8C $29 $00 $8B $8B $8B
        .BYTE   $25 $00 $24 $00 $8C $8C $8C $25 $00 $8B $8B $8B $22 $0C
        .BYTE   $8D $22 $30 $8C $8C $25 $00 $24 $00 $25 $00 $8B $8B $22 $00
        .BYTE   $24 $00 $25 $00 $27 $00 $29 $30 $8D $29 $0C $27 $00 $8C $8C $8C
        .BYTE   $29 $00 $8B $8B $8B $25 $00 $24 $00 $8C $8C $8C $25 $00
        .BYTE   $8B $8B $8B $27 $00 $8D $27 $30 $8D $27 $18 $8D $27 $0C
        .BYTE   $8C $8C $8C $12 $00 $14 $00 $8B $8B $8B $24 $00 $24 $00 $22 $00
        .BYTE   $24 $00 $20 $00 $17 $00
        .BYTE   $81 $08 $20 $00
        .BYTE   $81 $0C $20 $00 $8D $20 $30 $22 $00 $22 $00 $24 $00 $25 $00 $22
        .BYTE   $00 $19 $00
        .BYTE   $81 $08 $22 $00
        .BYTE   $81 $0C $22 $00 $8D $22 $30 $24 $00 $24 $00 $25 $00 $27 $00 $24
        .BYTE   $00 $20 $00 $7F $00 $24 $12 $24 $0C $25 $00 $8C $8C $8C $24 $00
        .BYTE   $8B $8B $8B $27 $00 $8C $8C $8C $25 $00 $8B $8B $8B $29 $00
        .BYTE   $8C $8C $8C $27 $00 $8B $8B $8B $29 $00 $8C $8C $8C $29 $00
        .BYTE   $8B $8B $8B $30 $00 $2A $00 $8C $8C $8C $30 $00 $8B $8B $8B
        .BYTE   $29 $30
        .BYTE   $81 $08 $29 $00
        .BYTE   $81 $0C
        .BYTE   $8A $0C
        .BYTE   $22 $30 $8D $22 $00 $22 $00 $24 $00 $25 $00 $27 $30 $8D $27 $00
        .BYTE   $27 $00 $25 $00 $24 $00 $25 $30 $8D $25 $00 $22 $00 $24 $00
        .BYTE   $25 $00 $24 $30 $8D $24 $00 $27 $00 $25 $00 $24 $00 $22 $30
        .BYTE   $8D $22 $00 $22 $00 $24 $00 $25 $00 $27 $30 $8D $27 $00 $27 $00
        .BYTE   $25 $00 $24 $00 $25 $30 $8D $25 $00 $22 $00 $24 $00 $25 $00
        .BYTE   $24 $30 $8D $24 $06 $7F $06
        .BYTE   $8A $06
        .BYTE   $19 $00 $7F $00 $22 $00 $24 $00 $25 $00 $27 $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $1E $82 $00 $32 $01
        .BYTE   $8A $06
        .BYTE   $81 $0D $7F $18
        .BYTE   $88
        .BYTE   $86
@a:     .BYTE   $86
@b:     .BYTE   $02 $00 $02 $00 $09 $00 $09 $00 $05 $00 $05 $00 $09 $00 $09 $00
        .BYTE   $87 $04
        .WORD   @b - @header            ;=$4F, $02
        .BYTE   $86
@c:     .BYTE   $0D $00 $0D $00 $05 $00 $05 $00 $02 $00 $02 $00 $05 $00 $05 $00
        .BYTE   $87 $04
        .WORD   @c - @header            ;=$64, $02
        .BYTE   $86
@d:     .BYTE   $00 $00 $00 $00 $07 $00 $07 $00 $04 $00 $04 $00 $07 $00 $07 $00
        .BYTE   $87 $02
        .WORD   @d - @header            ;=$79, $02
        .BYTE   $86
@e:     .BYTE   $02 $00 $02 $00 $09 $00 $09 $00 $05 $00 $05 $00 $09 $00 $09 $00
        .BYTE   $87 $02
        .WORD   @e - @header            ;=$8E, $02
        .BYTE   $00 $00 $00 $00 $07 $00 $07 $00 $04 $00 $04 $00 $07 $00 $07 $00
        .BYTE   $00 $00 $00 $00 $07 $00 $07 $00 $0D $00 $0D $00 $07 $00 $07 $00
        .BYTE   $0C $00 $7F $00 $0C $00 $7F $00 $00 $00 $00 $00 $7F $00 $0C $00
        .BYTE   $7F $00 $0C $00 $0D $00 $0C $00 $0C $00 $0C $00 $00 $00 $01 $00
        .BYTE   $87 $02
        .WORD   @a - @header            ;=$4E, $02
        .BYTE   $02 $30 $8D $02 $30 $00 $30 $8D $00 $30 $0D $30 $8D $0D $30
        .BYTE   $0C $30 $8D $0C $30 $02 $30 $8D $02 $30 $00 $30 $8D $00 $30
        .BYTE   $0D $30 $8D $0D $30 $0C $30 $8D $0C $00 $0C $00 $09 $00 $0C $00
        .BYTE   $0C $00 $0E $00 $00 $00 $01 $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $84 $04 $00
        .BYTE   $82 $FF $14 $96 $00 $32 $01
        .BYTE   $8A $06
        .BYTE   $81 $07 $7F $00 $22 $00 $24 $00 $25 $00
        .BYTE   $88
        .BYTE   $81 $0A
        .BYTE   $8A $06
        .BYTE   $86
@f:     .BYTE   $12 $00 $09 $00 $15 $00
        .BYTE   $81 $07 $09 $00
        .BYTE   $81 $0A $14 $00 $10 $00
        .BYTE   $81 $07 $14 $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $07 $10 $00
        .BYTE   $81 $0A $09 $12 $8D $09 $00 $09 $00 $12 $00 $10 $00 $12 $00
        .BYTE   $09 $00 $15 $00
        .BYTE   $81 $07 $09 $00
        .BYTE   $81 $0A $14 $00 $10 $00
        .BYTE   $81 $07 $14 $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $07 $10 $00
        .BYTE   $81 $0A $12 $00 $10 $00 $12 $00 $0A $00 $10 $00 $12 $00 $14 $00
        .BYTE   $15 $00 $12 $00 $19 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $17 $00 $19 $00
        .BYTE   $81 $07 $17 $00
        .BYTE   $81 $0A $15 $0C $8D $15 $18 $15 $00 $14 $00 $10 $00 $12 $00
        .BYTE   $09 $00 $19 $00
        .BYTE   $81 $07 $09 $00
        .BYTE   $81 $0A $17 $00 $19 $00
        .BYTE   $81 $07 $17 $00
        .BYTE   $81 $0A $22 $0C
        .BYTE   $8A $03 $09 $00
        .BYTE   $81 $07 $22 $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $07 $09 $00
        .BYTE   $81 $0A $09 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $07 $09 $00
        .BYTE   $81 $0A $14 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $15 $00
        .BYTE   $81 $07 $14 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $07 $15 $00
        .BYTE   $81 $0A
        .BYTE   $86
@g:     .BYTE   $10 $00
        .BYTE   $81 $07 $17 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $07 $10 $00
        .BYTE   $81 $0A $14 $00
        .BYTE   $81 $07 $17 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $07 $14 $00
        .BYTE   $81 $0A
        .BYTE   $87 $02
        .WORD   @g - @header            ;=$02, $04
        .BYTE   $10 $00
        .BYTE   $81 $07 $17 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $07 $10 $00
        .BYTE   $81 $0A $27 $06
        .BYTE   $81 $07 $17 $06
        .BYTE   $81 $0A $25 $00
        .BYTE   $81 $07 $27 $00
        .BYTE   $81 $0A $24 $12
        .BYTE   $86
@h:     .BYTE   $12 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $15 $00
        .BYTE   $81 $07 $19 $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $07 $15 $00
        .BYTE   $81 $0A
        .BYTE   $87 $02
        .WORD   @h - @header            ;=$49, $04
        .BYTE   $12 $00
        .BYTE   $81 $07 $19 $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $29 $06
        .BYTE   $81 $07 $19 $06
        .BYTE   $81 $0A $27 $00
        .BYTE   $81 $07 $29 $00
        .BYTE   $81 $0A $25 $12
        .BYTE   $86
@i:     .BYTE   $24 $00
        .BYTE   $81 $07 $20 $00
        .BYTE   $81 $0A $20 $00
        .BYTE   $81 $07 $24 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $07 $20 $00
        .BYTE   $81 $0A $20 $00
        .BYTE   $81 $07 $17 $00
        .BYTE   $81 $0A
        .BYTE   $87 $03
        .WORD   @i - @header            ;=$90, $04
        .BYTE   $24 $00
        .BYTE   $81 $07 $20 $00
        .BYTE   $81 $0A $25 $00
        .BYTE   $81 $07 $24 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $07 $25 $00
        .BYTE   $81 $0A $20 $00
        .BYTE   $81 $07 $24 $00
        .BYTE   $81 $0A $8A $06 $24 $00
        .BYTE   $81 $07 $20 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $07 $24 $00
        .BYTE   $81 $0A $27 $00 $25 $00
        .BYTE   $81 $07 $27 $00
        .BYTE   $81 $0A $24 $00 $8D $24 $18 $09 $00 $0B $00 $10 $00 $11 $00
        .BYTE   $87 $02
        .WORD   @f - @header            ;=$39, $03
        .BYTE   $8A $0C
        .BYTE   $15 $06 $09 $00 $14 $00 $12 $00 $15 $00 $09 $00 $12 $06 $14 $00
        .BYTE   $12 $00 $15 $06 $09 $00 $14 $00 $12 $00 $15 $00 $09 $00 $10 $06
        .BYTE   $14 $00 $12 $00 $15 $06 $0A $00 $14 $00 $15 $00 $17 $00 $0A $00
        .BYTE   $15 $06 $14 $00 $12 $00 $14 $06 $09 $00 $11 $00 $12 $00 $14 $00
        .BYTE   $09 $00 $14 $06 $12 $00 $11 $00 $15 $06 $09 $00 $14 $00 $12 $00
        .BYTE   $15 $00 $09 $00 $12 $06 $14 $00 $12 $00 $15 $06 $09 $00 $14 $00
        .BYTE   $12 $00 $15 $00 $09 $00 $10 $06 $14 $00 $12 $00 $15 $06 $0A $00
        .BYTE   $14 $00 $15 $00 $17 $00 $0A $00 $15 $06 $14 $00 $12 $00
        .BYTE   $8A $03
        .BYTE   $09 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $0B $00
        .BYTE   $81 $07 $09 $00
        .BYTE   $81 $0A $11 $00
        .BYTE   $81 $07 $0B $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $07 $11 $00
        .BYTE   $81 $0A $0B $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $11 $00
        .BYTE   $81 $07 $0B $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $07 $11 $00
        .BYTE   $81 $0A $14 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $11 $00
        .BYTE   $81 $07 $14 $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $07 $11 $00
        .BYTE   $81 $0A $14 $00
        .BYTE   $81 $07 $12 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $07 $14 $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $07 $17 $00
        .BYTE   $81 $0A $21 $00
        .BYTE   $81 $07 $19 $00
        .BYTE   $81 $0A $22 $00
        .BYTE   $81 $07 $21 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $07 $22 $00
        .BYTE   $81 $0A
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $70 $00 $7F $00 $70 $00 $7F $00
        .BYTE   $88
        .BYTE   $86
@j:     .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $1C
        .WORD   @j - @header            ;=$12, $06
        .BYTE   $86
@k:     .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $02
        .WORD   @k - @header            ;=$25, $06
        .BYTE   $81 $0C $71 $00 $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0C $71 $00 $71 $00 $71 $00 $71 $00 $71 $00 $71 $00 $71 $00
        .BYTE   $FF

        .BYTE   $00 $00 $00 $00
        ;

music_skyBase:                                                          ;$E1A7
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$0158
        .WORD   @channel3 - @header     ;=$01E2
        .WORD   @channel4 - @header     ;=$02C3
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $88
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $82 $FF $14 $96 $0A $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $06
        .BYTE   $86
@a:     .BYTE   $22 $00 $20 $00 $22 $00
        .BYTE   $81 $0A $20 $00
        .BYTE   $81 $0D $25 $00
        .BYTE   $81 $0A $22 $00 $25 $00
        .BYTE   $81 $0D
        .BYTE   $86
@b:     .BYTE   $25 $00 $81 $09 $25 $00
        .BYTE   $81 $0D
        .BYTE   $87 $02
        .WORD   @b - @header            ;$3B, $00
        .BYTE   $22 $00
        .BYTE   $81 $0A $25 $00
        .BYTE   $81 $0D $19 $00 $17 $00 $15 $00 $22 $00 $20 $00 $22 $00
        .BYTE   $81 $0A $20 $00
        .BYTE   $81 $0D $25 $00
        .BYTE   $81 $0A $22 $00 $25 $00
        .BYTE   $81 $0D
        .BYTE   $86
@c:     .BYTE   $25 $00
        .BYTE   $81 $0A $25 $00
        .BYTE   $81 $0D
        .BYTE   $87 $02
        .WORD   @c - @header            ;$6C, $00
        .BYTE   $22 $00
        .BYTE   $81 $0A $25 $00
        .BYTE   $81 $0D $18 $00 $17 $00 $15 $00
        .BYTE   $87 $02
        .WORD   @a - @header            ;$24, $00
        .BYTE   $86
@d:     .BYTE   $19 $00 $19 $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $0D $17 $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $0D $15 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $0D $14 $00
        .BYTE   $81 $0A $15 $00
        .BYTE   $81 $0D $12 $00
        .BYTE   $81 $0A $14 $00
        .BYTE   $81 $0D $14 $00
        .BYTE   $81 $0A $12 $00
        .BYTE   $81 $0D $15 $00
        .BYTE   $81 $0A $14 $00
        .BYTE   $81 $0D $17 $00 $1A $00 $1A $00
        .BYTE   $81 $0A $1A $00
        .BYTE   $81 $0D $19 $00
        .BYTE   $81 $0A $1A $00
        .BYTE   $81 $0D $17 $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $0D $15 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $81 $0D $14 $00
        .BYTE   $81 $0A $15 $00
        .BYTE   $81 $0D $15 $00
        .BYTE   $81 $0A $14 $00
        .BYTE   $81 $0D $17 $00
        .BYTE   $81 $0A $15 $00
        .BYTE   $81 $0D $18 $00
        .BYTE   $87 $02
        .WORD   @d - @header            ;=$8B, $00
        .BYTE   $21 $00 $19 $00 $21 $00 $22 $00
        .BYTE   $81 $0A $21 $00
        .BYTE   $81 $0D $1A $00 $22 $00 $21 $00
        .BYTE   $81 $0A $22 $00
        .BYTE   $81 $0D $21 $00 $19 $00 $24 $00 $25 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $0D $22 $00 $25 $00 $24 $00 $21 $00 $24 $00 $25 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $0D $22 $00 $25 $00 $21 $00 $24 $00 $27 $00 $2A $00 $31 $00
        .BYTE   $3A $00 $41 $00 $44 $00 $47 $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $82 $FF $14 $96 $14 $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $06
        .BYTE   $86
@e:     .BYTE   $02 $0C $02 $0C $02 $00 $02 $0C $02 $0C $02 $00 $00 $00 $02 $00
        .BYTE   $02 $00 $05 $00 $04 $00 $00 $00 $0D $0C $0D $0C $0D $00 $0D $0C
        .BYTE   $0D $0C $0D $00 $0D $0C $0D $00 $0E $00 $00 $00 $01 $00
        .BYTE   $87 $02
        .WORD   @e - @header            ;=$65, $01
        .BYTE   $86
@f:     .BYTE   $0C $0C $0C $0C $0C $00 $0C $0C $0C $0C $0C $0C $0C $0C $0C $00
        .BYTE   $0C $00 $0C $00 $0D $0C $0D $0C $0D $00 $0D $0C $0D $0C $0D $0C
        .BYTE   $0D $00 $0D $00 $0D $00 $0D $00 $0D $00
        .BYTE   $87 $02
        .BYTE   $98 $01
        .BYTE   $86
@g:     .BYTE   $0C $00 $0C $00 $0C $0C $0C $00 $0C $0C $0C $0C $0C $0C $0C $0C
        .BYTE   $0C $00 $0C $00 $0C $00
        .BYTE   $87 $02
        .WORD   @g - @header            ;=$C7, $01
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $84 $04 $00
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0A
        .BYTE   $8A $06
        .BYTE   $86
@h:     .BYTE   $19 $00 $17 $00 $19 $00 $7F $00 $22 $0C $7F $00 $22 $00 $7F $00
        .BYTE   $22 $00 $7F $00 $19 $00 $7F $00 $15 $00 $12 $00 $12 $00 $18 $00
        .BYTE   $17 $00 $18 $00 $7F $00 $22 $0C $7F $00 $22 $00 $7F $00 $22 $00
        .BYTE   $7F $00 $18 $00 $7F $00 $15 $00 $12 $00 $12 $00
        .BYTE   $87 $02
        .WORD   @h - @header            ;=$F2, $01
        .BYTE   $83 $18 $01 $FA $F4 $FF
        .BYTE   $19 $30
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $29 $30
        .BYTE   $83 $18 $01 $FA $0C $00
        .BYTE   $28 $30
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $22 $30
        .BYTE   $83 $18 $01 $FA $F4 $FF
        .BYTE   $19 $30
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $29 $30
        .BYTE   $83 $1C $01 $FA $F6 $FF
        .BYTE   $28 $30
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $32 $30 $19 $00 $14 $00 $19 $00 $1A $00
        .BYTE   $81 $0A $19 $00
        .BYTE   $81 $0D $15 $00 $1A $00 $19 $00
        .BYTE   $81 $0A $1A $00
        .BYTE   $81 $0D $19 $00 $14 $00 $21 $00 $22 $00
        .BYTE   $81 $0A $21 $00
        .BYTE   $81 $0D $1A $00 $22 $00 $21 $00 $19 $00 $21 $00 $22 $00
        .BYTE   $81 $0A $21 $00
        .BYTE   $81 $0D $19 $00 $22 $00 $19 $00 $21 $00 $24 $00 $27 $00 $2A $00
        .BYTE   $27 $00 $2A $00 $31 $00 $34 $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $86
@i:     .BYTE   $70 $00 $70 $00 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00 $70 $00 $70 $00 $70 $00 $7F $00 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00 $70 $00 $70 $00
        .BYTE   $87 $09
        .WORD   @i - @header            ;=$C9, $02
        .BYTE   $70 $00 $70 $00 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00 $70 $00 $70 $00 $70 $00 $7F $00 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00 $71 $00 $71 $00 $71 $00
        .BYTE   $FF
        ;

music_titleScreen:                                                      ;$E4C3
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$008C
        .WORD   @channel3 - @header     ;=$00DA
        .WORD   @channel4 - @header     ;=$013C
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $05 $00 $04 $00
        .BYTE   $85 $FF
        .BYTE   $81 $0C
        .BYTE   $8A $06
        .BYTE   $81 $0D
        .BYTE   $82 $FA $1E $96 $1E $05 $01
        .BYTE   $83 $01 $01 $FA $1E $00
        .BYTE   $7F $0C
        .BYTE   $86
@a:     .BYTE   $14 $06 $7F $06
        .BYTE   $87 $03
        .WORD   @a - @header            ;$27, $00
        .BYTE   $81 $0C
        .BYTE   $82 $FF $14 $96 $02 $32 $0A
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $7F $0C $21 $18 $21 $0C $22 $12
        .BYTE   $83 $10 $01 $FA $FE $FF
        .BYTE   $1B $1E
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $21 $00 $7F $00 $21 $00 $7F $00 $21 $00 $7F $00 $19 $00 $7F $00
        .BYTE   $17 $12 $1B $1E $19 $00 $7F $00 $21 $00 $7F $00 $29 $00 $7F $00
        .BYTE   $24 $00 $7F $0C $28 $12
        .BYTE   $86
@b:     .BYTE   $29 $00 $7F $00 $8C $8C $8C
        .BYTE   $87 $04
        .WORD   @b - @header            ;=$7B, $00
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $1E $96 $0A $0A $0A
        .BYTE   $81 $0D
        .BYTE   $8A $0C
        .BYTE   $7F $30 $0C $00 $09 $00 $04 $00 $04 $00 $07 $00 $07 $06 $06 $00
        .BYTE   $07 $06 $06 $00 $0C $00 $09 $00 $04 $00 $04 $00 $02 $00 $02 $06
        .BYTE   $01 $00 $02 $06 $01 $00 $0C $00 $09 $00 $04 $00 $01 $00 $0C $06
        .BYTE   $08 $12 $09 $00
        .BYTE   $82 $FF $1E $96 $01 $0A $0A
        .BYTE   $0C $30
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $82 $02 $32 $0A
        .BYTE   $81 $0B
        .BYTE   $8A $06
        .BYTE   $7F $30
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $7F $0C $19 $18 $19 $0C $1B $12
        .BYTE   $83 $10 $01 $FA $FE $FF
        .BYTE   $17 $1E
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $19 $00 $7F $00 $19 $00 $7F $00 $19 $00 $7F $00 $14 $00 $7F $00
        .BYTE   $12 $12 $17 $1E $11 $00 $7F $00 $19 $00 $7F $00 $24 $00 $7F $00
        .BYTE   $19 $00 $7F $0C $22 $12 $21 $00 $7F $00
        .BYTE   $82 $FF $1E $96 $01 $0A $0A
        .BYTE   $09 $30
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06 $8A $0C
        .BYTE   $70 $00 $71 $00 $71 $00 $71 $00
        .BYTE   $86
@d:     .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $06 $70 $06
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $06
        .BYTE   $81 $09 $70 $00 $70 $06
        .BYTE   $81 $0B $71 $00
        .BYTE   $87 $03
        .WORD   @d - @header            ;=$4B, $01
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF
        ;

music_mapScreen:                                                        ;$E63C
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$004D
        .WORD   @channel3 - @header     ;=$008B
        .WORD   @channel4 - @header     ;=$00C2
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $81 $0D
        .BYTE   $82 $FF $14 $78 $14 $23 $01
        .BYTE   $81 $0C $07 $08 $0B $07 $12 $07 $15 $06 $17 $06 $1B $06 $22 $06
        .BYTE   $25 $06 $27 $05 $2B $05 $32 $05 $35 $05 $37 $05 $3B $05 $42 $05
        .BYTE   $45 $05
        .BYTE   $86
@a:     .BYTE   $47 $05 $7F $05 $8C $8C
        .BYTE   $87 $06
        .WORD   @a - @header            ;=$3D, $00
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $0A
        .BYTE   $82 $FF $14 $78 $14 $23 $01
        .BYTE   $7F $0C
        .BYTE   $81 $0C $07 $08 $0B $07 $12 $07 $15 $06 $17 $06 $1B $06 $22 $06
        .BYTE   $25 $06 $27 $05 $2B $05 $32 $05 $35 $05 $37 $05 $3B $05 $42 $05
        .BYTE   $45 $05
        .BYTE   $86
@b:     .BYTE   $47 $05 $7F $05 $8C $8C
        .BYTE   $87 $05
        .WORD   @b - @header            ;=$7B, $00
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $07
        .BYTE   $82 $FF $14 $78 $14 $23 $01
        .BYTE   $7F $18
        .BYTE   $81 $0C $07 $08 $0B $07 $12 $07 $15 $06 $17 $06 $1B $06 $22 $06
        .BYTE   $25 $06 $27 $05 $2B $05 $32 $05 $35 $05 $37 $05 $3B $05 $42 $05
        .BYTE   $45 $05 $47 $05 $7F $0A
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF
        ;

music_invincibility:                                                    ;$E704
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$00A4
        .WORD   @channel3 - @header     ;=$0109
        .WORD   @channel4 - @header     ;=$0160
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $88
        .BYTE   $8A $06
        .BYTE   $86
@a:     .BYTE   $81 $0C
        .BYTE   $82 $FF $14 $96 $00 $32 $0A
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $7F $0C $23 $18 $23 $0C $24 $12
        .BYTE   $83 $10 $01 $FA $FE $FF
        .BYTE   $21 $1E
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $23 $00 $7F $00 $23 $00 $7F $00 $23 $00 $7F $00 $1B $00 $7F $00
        .BYTE   $19 $12 $21 $1E
        .BYTE   $87 $02
        .WORD   @a - @header            ;=$15, $00
        .BYTE   $86
@b:     .BYTE   $7F $00 $09 $12 $0B $00 $7F $00
        .BYTE   $81 $07 $0B $00 $7F $00
        .BYTE   $81 $0D
        .BYTE   $87 $02
        .WORD   @b - @header            ;=$53, $00
        .BYTE   $8C $8C
        .BYTE   $82 $FF $00 $96 $02 $32 $0A
        .BYTE   $8A $04
        .BYTE   $1B $00 $21 $00 $23 $00 $24 $00 $26 $00 $28 $00 $23 $00 $24 $00
        .BYTE   $26 $00 $28 $00 $29 $00 $2B $00 $24 $00 $26 $00 $28 $00 $29 $00
        .BYTE   $2B $00 $31 $00 $8B $26 $00 $28 $00 $2A $00 $2B $00 $31 $00
        .BYTE   $33 $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $96 $00 $0A $0A
        .BYTE   $81 $0E
        .BYTE   $88
        .BYTE   $86
@c:     .BYTE   $8A $0C
        .BYTE   $0E $00 $0B $00 $06 $00 $06 $00 $09 $00 $09 $06 $08 $00 $09 $06
        .BYTE   $08 $00 $0E $00 $0B $00 $06 $00 $06 $00 $04 $00 $04 $06 $03 $00
        .BYTE   $04 $06 $03 $00
        .BYTE   $87 $02
        .WORD   @c - @header            ;=$AF, $00
        .BYTE   $86
@d:     .BYTE   $0C $06 $0C $12 $0E $00 $0E $00
        .BYTE   $87 $02
        .WORD   @d - @header            ;=$DA, $00
        .BYTE   $0C $06 $01 $12 $03 $00 $05 $00
        .BYTE   $8A $04
        .BYTE   $01 $00 $03 $00 $04 $00 $06 $00 $08 $00 $09 $00 $03 $00 $04 $00
        .BYTE   $06 $00 $08 $00 $09 $00 $10 $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $82 $00 $32 $0A
        .BYTE   $88
        .BYTE   $86
@e:     .BYTE   $8A $06
        .BYTE   $81 $0A
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $7F $0C $1B $18 $1B $0C $21 $12
        .BYTE   $83 $10 $01 $FA $FE $FF
        .BYTE   $19 $1E
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $1B $00 $7F $00 $1B $00 $7F $00 $1B $00 $7F $00 $16 $00 $7F $00
        .BYTE   $14 $12 $19 $1E
        .BYTE   $87 $02
        .WORD   @e - @header            ;=$12, $01
        .BYTE   $86
@f:     .BYTE   $7F $00 $11 $12 $13 $00 $7F $00
        .BYTE   $81 $06 $13 $00 $7F $00
        .BYTE   $81 $0B
        .BYTE   $87 $04
        .WORD   @f - @header            ;=$4B, $01
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $8A $0C
        .BYTE   $86
@g:     .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $06 $70 $06
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $06
        .BYTE   $81 $09 $70 $00 $70 $06
        .BYTE   $81 $0B $71 $00
        .BYTE   $87 $04
        .WORD   @g - @header            ;=$64, $01
        .BYTE   $8A $06
        .BYTE   $86
@h:     .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $0C
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0C $71 $0C
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $00
        .BYTE   $87 $04
        .WORD   @h - @header            ;=$8F, $01
        .BYTE   $FF

        .BYTE   $00 $00 $00 $00
        ;

music_actComplete:                                                      ;$E8B4
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$0044
        .WORD   @channel3 - @header     ;=$006F
        .WORD   @channel4 - @header     ;=$00A2
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $04 $00 $03 $00
        .BYTE   $85 $FF
        .BYTE   $81 $0C
        .BYTE   $8A $0C
        .BYTE   $81 $0C
        .BYTE   $82 $64 $14 $96 $00 $32 $0A
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $19 $00 $22 $00 $21 $00 $19 $00 $22 $00 $21 $00 $19 $00 $22 $00
        .BYTE   $21 $18 $32 $06 $31 $06 $29 $06 $2B $60
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $1E $96 $00 $0A $0A
        .BYTE   $81 $0D
        .BYTE   $8A $0C
        .BYTE   $09 $06 $7F $06 $0C $00 $0E $00 $01 $00 $02 $00 $04 $00 $06 $00
        .BYTE   $07 $00 $09 $18 $0C $00 $7F $06 $0E $60
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $64 $14 $82 $00 $32 $0A
        .BYTE   $81 $0B
        .BYTE   $8A $0C
        .BYTE   $83 $10 $01 $04 $06 $00
        .BYTE   $19 $06 $7F $06 $09 $00 $0B $00 $11 $00 $12 $00 $14 $00 $16 $00
        .BYTE   $17 $00 $19 $18 $21 $06 $1B $06 $21 $06 $24 $60
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $86
@a:     .BYTE   $81 $0B $71 $00 $71 $00
        .BYTE   $81 $09 $70 $00 $7F $00 $70 $00 $7F $00
        .BYTE   $87 $02
        .WORD   @a - @header            ;=$A7, $00
        .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00 $71 $00 $71 $00 $71 $00 $71 $00
        .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $88
        .BYTE   $81 $00 $7F $00
        .BYTE   $FF
        ;

music_death:                                                            ;$E991
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$0064
        .WORD   @channel3 - @header     ;=$009B
        .WORD   @channel4 - @header     ;=$00E9
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $82 $FF $14 $96 $0A $14 $0A
        .BYTE   $85 $FF
        .BYTE   $81 $0F
        .BYTE   $8A $01
        .BYTE   $86
@a:     .BYTE   $00 $00 $0C $00 $0E $00 $8C $8C $40 $00 $0C $00 $7F $00 $8C $8C
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$1D, $00
        .BYTE   $8A $06
        .BYTE   $81 $0C $30 $18 $30 $0C $31 $12
        .BYTE   $83 $0B $01 $FA $FE $FF
        .BYTE   $2A $1E
        .BYTE   $83 $10 $01 $04 $04 $00
        .BYTE   $30 $00 $7F $00 $30 $00 $7F $00 $30 $00 $7F $00 $28 $00 $7F $00
        .BYTE   $86
@b:     .BYTE   $26 $00 $7F $00 $8C
        .BYTE   $87 $08
        .WORD   @b - @header            ;=$5A, $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $1E $96 $0A $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $0C
        .BYTE   $7F $06 $09 $00 $19 $00 $14 $00 $14 $00 $17 $00 $17 $06 $16 $00
        .BYTE   $17 $06 $16 $00 $09 $00 $19 $00 $14 $00 $14 $00
        .BYTE   $82 $FF $10 $96 $01 $14 $0A
        .BYTE   $83 $10 $01 $05 $0C $00
        .BYTE   $13 $60
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $82 $0A $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $0C
        .BYTE   $83 $01 $01 $FA $05 $00
        .BYTE   $7F $06 $4B $0C
        .BYTE   $8A $06
        .BYTE   $81 $0B
        .BYTE   $83 $24 $01 $01 $01 $00
        .BYTE   $28 $18 $28 $0C $29 $12
        .BYTE   $83 $0B $01 $FA $FE $FF
        .BYTE   $26 $1E
        .BYTE   $83 $10 $01 $04 $04 $00
        .BYTE   $28 $00 $7F $00 $28 $00 $7F $00 $28 $00 $7F $00 $24 $00 $7F $00
        .BYTE   $86
@c:     .BYTE   $22 $00 $7F $00 $8C
        .BYTE   $87 $08
        .WORD   @c - @header            ;=$DF, $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $7F $06
        .BYTE   $8A $0C
        .BYTE   $70 $00
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $06 $70 $06
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $06
        .BYTE   $81 $09 $70 $00 $70 $06
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09 $70 $06 $70 $06
        .BYTE   $81 $0B $71 $00
        .BYTE   $81 $09
        .BYTE   $86
@d:     .BYTE   $71 $04
        .BYTE   $87 $18
        .WORD   @d - @header            ;=$28, $01
        .BYTE   $FF
        ;

music_boss:                                                             ;$EAC0
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$014B
        .WORD   @channel3 - @header     ;=$01B2
        .WORD   @channel4 - @header     ;=$022A
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $04 $00 $05 $00
        .BYTE   $85 $FF
        .BYTE   $88
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $06
        .BYTE   $7F $0C $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $7F $00 $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $22 $00 $7F $00
        .BYTE   $81 $09 $22 $00
        .BYTE   $81 $0D $25 $0C $22 $00 $20 $0C $22 $00 $7F $00
        .BYTE   $81 $09 $22 $00
        .BYTE   $81 $0D $19 $18 $7F $0C $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $7F $00 $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $22 $00 $7F $00
        .BYTE   $81 $09 $22 $00
        .BYTE   $81 $0D $25 $0C $22 $00 $20 $0C $22 $00 $7F $00
        .BYTE   $81 $09 $22 $00
        .BYTE   $81 $0D $29 $18 $7F $0C $2A $00 $7F $00
        .BYTE   $81 $09 $2A $00
        .BYTE   $81 $0D $7F $00 $2A $00 $7F $00
        .BYTE   $81 $09 $2A $00
        .BYTE   $81 $0D $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $2A $0C $27 $00 $25 $0C $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $22 $18 $7F $0C $2A $00 $7F $00
        .BYTE   $81 $09 $2A $00
        .BYTE   $81 $0D $7F $00 $2A $00 $7F $00
        .BYTE   $81 $09 $2A $00
        .BYTE   $81 $0D $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $2A $0C $27 $00 $25 $0C $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $32 $18
        .BYTE   $86
@a:     .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $8B $29 $00 $8C $7F $00 $29 $00
        .BYTE   $82 $FF $00 $96 $00 $14 $0A
        .BYTE   $81 $08
        .BYTE   $83 $0C $01 $F0 $EA $FF
        .BYTE   $09 $12
        .BYTE   $83 $0C $01 $F0 $16 $00
        .BYTE   $19 $12
        .BYTE   $83 $0C $01 $F0 $EA $FF
        .BYTE   $09 $12
        .BYTE   $83 $0C $01 $F0 $16 $00
        .BYTE   $19 $12
        .BYTE   $83 $0C $01 $F0 $EA $FF
        .BYTE   $09 $12
        .BYTE   $83 $0C $01 $F0 $16 $00
        .BYTE   $19 $12
        .BYTE   $83 $0C $01 $F0 $EA $FF
        .BYTE   $09 $12
        .BYTE   $81 $0D
        .BYTE   $87 $02
        .WORD   @a - @header            ;=$F4, $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $82 $FF $14 $96 $01 $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $12
        .BYTE   $86
@b:     .BYTE   $02 $00 $02 $00 $00 $00 $0E $00 $0D $00 $0E $00 $00 $00 $01 $00
        .BYTE   $87 $02
        .WORD   @b - @header            ;=$58, $01
        .BYTE   $86
@c:     .BYTE   $07 $00 $07 $00 $06 $00 $05 $00 $04 $00 $05 $00 $06 $00 $07 $00
        .BYTE   $87 $02
        .WORD   @c - @header            ;=$6D, $01
        .BYTE   $8B $09 $0C $8C $09 $06 $0C $12 $0C $12 $0C $12 $0C $12 $0C $12
        .BYTE   $0C $12 $0C $12 $8B $09 $0C $8C $09 $06 $0C $12 $0C $12 $0C $12
        .BYTE   $0C $0C $0D $06 $7F $0C $0E $06 $7F $0C $00 $06 $7F $0C $01 $06
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $84 $04 $00
        .BYTE   $82 $FF $14 $82 $00 $14 $0A
        .BYTE   $81 $0A
        .BYTE   $8A $06
        .BYTE   $86
@d:     .BYTE   $7F $0C $22 $00
        .BYTE   $86
@e:     .BYTE   $19 $00 $7F $0C
        .BYTE   $87 $03
        .WORD   @e - @header            ;=$C7, $01
        .BYTE   $19 $18 $8D $19 $0C $8D $19 $24
        .BYTE   $87 $02
        .WORD   @d - @header            ;=$C2, $01
        .BYTE   $86
@f:     .BYTE   $7F $0C $22 $00 $7F $12 $22 $00 $7F $0C $22 $00 $7F $0C $22 $0C
        .BYTE   $22 $00 $22 $0C $22 $00 $7F $0C $22 $18
        .BYTE   $87 $02
        .WORD   @f - @header            ;=$DC, $01
        .BYTE   $8B $19 $00 $7F $00 $19 $00
        .BYTE   $86
@g:     .BYTE   $09 $00 $7F $0C
        .BYTE   $87 $07
        .WORD   @g - @header            ;=$02, $02
        .BYTE   $19 $00 $7F $00 $19 $00
        .BYTE   $86
@h:     .BYTE   $09 $00 $7F $0C
        .BYTE   $87 $03
        .WORD   @h - @header            ;=$11, $02
        .BYTE   $09 $0C $0A $00 $7F $0C $0B $00 $7F $0C $10 $00 $7F $0C $11 $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $86
@i:     .BYTE   $81 $09 $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0B $71 $0C
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $10
        .WORD   @i - @header            ;=$30, $02
        .BYTE   $81 $0C $71 $00 $7F $00 $71 $00
        .BYTE   $81 $09 $70 $12 $70 $12 $70 $12
        .BYTE   $86
@j:     .BYTE   $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0B $71 $0C
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $02
        .WORD   @j - @header            ;=$55, $02
        .BYTE   $81 $0C $71 $00 $7F $00 $71 $00
        .BYTE   $81 $09 $70 $12 $70 $12 $70 $12 $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0B $71 $0C
        .BYTE   $81 $09 $70 $00
        .BYTE   $81 $0B $71 $00 $71 $00 $71 $00 $71 $00 $71 $00 $71 $00
        .BYTE   $FF
        ;

music_ending:                                                           ;$ED54
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$0164
        .WORD   @channel3 - @header     ;=$0254
        .WORD   @channel4 - @header     ;=$0392
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $02 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $7F $30
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $06
        .BYTE   $86
@a:     .BYTE   $21 $00 $7F $00 $19 $0C $8D $19 $24 $7F $00 $22 $00 $7F $00
        .BYTE   $22 $00 $22 $00 $24 $00 $21 $00 $7F $00 $19 $0C $8D $19 $24
        .BYTE   $7F $00 $16 $00 $7F $00 $19 $00 $19 $00 $1B $00
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$25, $00
        .BYTE   $21 $00 $7F $00 $19 $0C $8D $19 $24 $7F $00 $22 $00 $7F $00
        .BYTE   $22 $00 $22 $00 $24 $00 $21 $00 $7F $00 $19 $1E $29 $00
        .BYTE   $8D $29 $30 $7F $18 $20 $00 $19 $0C $20 $00 $1B $0C $20 $00
        .BYTE   $1B $0C $17 $12 $7F $12 $19 $00 $24 $00 $22 $0C $20 $00 $1B $0C
        .BYTE   $20 $00 $1B $0C $17 $12 $7F $18 $20 $00 $19 $0C $20 $00 $1B $0C
        .BYTE   $20 $00 $1B $0C $17 $12 $7F $12 $19 $00 $19 $00 $15 $0C $19 $00
        .BYTE   $17 $0C $19 $00 $17 $0C $10 $0C $14 $00 $12 $30 $8D $12 $1E
        .BYTE   $10 $00 $12 $00 $14 $0C $8D $14 $48 $10 $00 $19 $00 $13 $48
        .BYTE   $8D $13 $0C $10 $00 $13 $00 $12 $30 $14 $18 $1B $0C $21 $00
        .BYTE   $22 $00 $24 $00
        .BYTE   $86
@b:     .BYTE   $21 $00 $7F $00 $19 $0C $8D $19 $24 $7F $00 $22 $00 $7F $00
        .BYTE   $22 $00 $22 $00 $24 $00 $21 $00 $7F $00 $19 $0C $8D $19 $24
        .BYTE   $7F $00 $16 $00 $7F $00 $19 $00 $19 $00 $1B $00
        .BYTE   $87 $03
        .WORD   @b - @header            ;=$E1, $00
        .BYTE   $21 $00 $7F $00 $19 $0C $8D $19 $24 $7F $00 $22 $00 $7F $00
        .BYTE   $22 $00 $22 $00 $24 $00 $21 $00 $7F $00 $19 $1E $29 $0C $29 $00
        .BYTE   $26 $00 $7F $00 $29 $00 $2B $00 $7F $00 $29 $00 $8D $29 $30
        .BYTE   $8D $29 $30 $8D $29 $30 $8D $29 $30 $7F $30 $7F $30 $7F $00
        .BYTE   $22 $00 $7F $0C $22 $00 $7F $00 $22 $00 $21 $00 $8D $21 $36
        .BYTE   $8D $21 $30
        .BYTE   $81 $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $7F $30
        .BYTE   $82 $FF $14 $96 $14 $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $06
        .BYTE   $86
@c:     .BYTE   $0C $0C $0C $0C $01 $00 $11 $00 $01 $00 $02 $0C $02 $00 $12 $00
        .BYTE   $02 $00 $04 $00 $04 $00 $14 $00 $04 $00
        .BYTE   $87 $08
        .WORD   @c - @header            ;=$72, $01
        .BYTE   $86
@d:     .BYTE   $05 $00 $05 $00 $10 $00 $05 $0C $05 $00 $00 $00 $05 $00 $04 $00
        .BYTE   $04 $00 $10 $00 $04 $0C $00 $00 $02 $00 $04 $00
        .BYTE   $87 $04
        .WORD   @d - @header            ;=$91, $01
        .BYTE   $0D $0C $0D $00 $0C $0C $0C $00 $0D $0C $0D $00 $00 $0C $00 $00
        .BYTE   $02 $0C $04 $0C $0C $0C $0C $00 $0E $0C $0E $00 $00 $0C $00 $00
        .BYTE   $02 $0C $02 $00 $04 $0C $00 $0C $08 $0C $08 $00 $07 $0C $07 $00
        .BYTE   $05 $0C $05 $00 $03 $0C $03 $00 $02 $0C $00 $0C $07 $0C $07 $00
        .BYTE   $02 $0C $02 $00 $07 $0C $07 $00 $8C $8C $8C $8C $04 $00 $04 $00
        .BYTE   $8B $04 $00 $8B $04 $00 $8B $04 $00 $8B $04 $00 $04 $00
        .BYTE   $86
@e:     .BYTE   $0C $0C $0C $0C $01 $00 $11 $00 $01 $00 $02 $0C $02 $00 $12 $00
        .BYTE   $02 $00 $04 $00 $04 $00 $14 $00 $04 $00
        .BYTE   $87 $0B
        .WORD   @e - @header            ;=$10, $02
        .BYTE   $05 $00 $05 $00 $15 $00 $05 $00 $07 $00 $17 $00 $07 $00 $09 $0C
        .BYTE   $04 $0C $01 $00
        .BYTE   $82 $FF $14 $96 $14 $00 $0A
        .BYTE   $0C $30 $8D $0C $18
        .BYTE   $81 $00
        .BYTE   $88
        .BYTE   $7F
        .BYTE   $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $7F $30
        .BYTE   $84 $04 $00
        .BYTE   $82 $FF $14 $82 $00 $14 $0A
        .BYTE   $8A $03
        .BYTE   $86
@f:     .BYTE   $81 $0B $39 $00
        .BYTE   $81 $07 $34 $00
        .BYTE   $81 $0B $38 $00
        .BYTE   $81 $07 $39 $00
        .BYTE   $81 $0B $36 $00
        .BYTE   $81 $07 $38 $00
        .BYTE   $81 $0B $34 $00
        .BYTE   $81 $07 $36 $00
        .BYTE   $87 $20
        .WORD   @f - @header            ;=$63, $02
        .BYTE   $8A $06
        .BYTE   $81 $0B
        .BYTE   $86
@g:     .BYTE   $19 $00 $15 $00 $10 $00 $09 $00 $09 $00 $10 $00 $15 $00 $19 $00
        .BYTE   $17 $00 $14 $00 $10 $00 $07 $00 $07 $00 $10 $00 $14 $00 $17 $00
        .BYTE   $87 $03
        .WORD   @g - @header            ;=$8C, $02
        .BYTE   $19 $00 $15 $00 $10 $00 $09 $00 $09 $00 $10 $00 $15 $00 $19 $00
        .BYTE   $10 $00 $14 $00 $17 $00 $1B $00 $20 $00 $24 $00 $27 $00 $2B $00
        .BYTE   $1A $00 $22 $00 $25 $00 $29 $00 $2A $00 $32 $00 $35 $00 $39 $00
        .BYTE   $3A $00 $39 $00 $35 $00 $32 $00 $2A $00 $29 $00 $25 $00 $22 $00
        .BYTE   $09 $00 $0B $00 $10 $00 $14 $00 $19 $00 $1B $00 $20 $00 $24 $00
        .BYTE   $29 $00 $24 $00 $20 $00 $1B $00 $19 $00 $14 $00 $10 $00 $0B $00
        .BYTE   $08 $00 $0A $00 $10 $00 $13 $00 $18 $00 $1A $00 $20 $00 $23 $00
        .BYTE   $28 $00 $2A $00 $30 $00 $33 $00 $38 $00 $33 $00 $30 $00 $27 $00
        .BYTE   $07 $00 $09 $00 $0B $00 $12 $00 $17 $00 $19 $00 $1B $00 $17 $00
        .BYTE   $14 $00 $08 $00 $09 $00 $0B $00 $11 $00 $12 $00 $14 $00 $16 $00
        .BYTE   $8A $03
        .BYTE   $86
@h:     .BYTE   $81 $0B $39 $00
        .BYTE   $81 $07 $34 $00
        .BYTE   $81 $0B $38 $00
        .BYTE   $81 $07 $39 $00
        .BYTE   $81 $0B $36 $00
        .BYTE   $81 $07 $38 $00
        .BYTE   $81 $0B $34 $00
        .BYTE   $81 $07 $36 $00
        .BYTE   $87 $2C
        .WORD   @h - @header            ;=$53, $03
        .BYTE   $81 $0B
        .BYTE   $8A $06
        .BYTE   $7F $00 $19 $00 $7F $0C $19 $00 $7F $00 $19 $00 $14 $36
        .BYTE   $8D $14 $30
        .BYTE   $81 $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $8A $06
        .BYTE   $81 $09 $70 $0C $70 $0C $70 $0C $70 $0C
        .BYTE   $86
@i:     .BYTE   $86
@j:     .BYTE   $70 $00 $70 $00
        .BYTE   $81 $0D $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $0F
        .WORD   @j - @header            ;=$A0, $03
        .BYTE   $70 $00
        .BYTE   $81 $0D $71 $00 $71 $00 $71 $00
        .BYTE   $87 $06
        .WORD   @i - @header            ;=$9F, $03
        .BYTE   $86
@k:     .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0D $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $0F
        .WORD   @k - @header            ;=$BF, $03
        .BYTE   $81 $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

        .BYTE   $00
        ;

music_specialStage:                                                     ;$F12C
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$0279
        .WORD   @channel3 - @header     ;=$0359
        .WORD   @channel4 - @header     ;=$049F
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $07 $00 $06 $00
        .BYTE   $85 $FF
        .BYTE   $88
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $06
        .BYTE   $86
@a:     .BYTE   $29 $30 $7F $0C $26 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $29 $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $2B $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $22 $00 $7F $00 $22 $00 $7F $00 $22 $00 $1B $00 $7F $00
        .BYTE   $22 $00 $7F $00 $7F $00 $1B $00 $7F $00 $22 $00 $7F $00 $24 $00
        .BYTE   $7F $00 $29 $30 $7F $0C $26 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $29 $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $2B $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $32 $00 $7F $12 $2B $00 $7F $0C $26 $00 $29 $00 $7F $0C
        .BYTE   $2B $00 $7F $0C $26 $00 $7F $00 $29 $30 $7F $0C $26 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $29 $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $2B $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $22 $00 $7F $00 $22 $00 $7F $00 $22 $00 $1B $00 $7F $00
        .BYTE   $22 $00 $7F $00 $7F $00 $1B $00 $7F $00 $22 $00 $7F $00 $24 $00
        .BYTE   $7F $00 $29 $30 $7F $0C $26 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $29 $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $2B $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $32 $00 $7F $12 $2B $00 $7F $0C $35 $00 $7F $00 $35 $00
        .BYTE   $34 $00 $7F $00 $32 $00 $2B $0C $7F $00 $7F $0C $26 $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $27 $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $26 $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $2A $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $2A $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $2B $00
        .BYTE   $81 $09 $2A $00
        .BYTE   $81 $0D $31 $00
        .BYTE   $81 $09 $2B $00
        .BYTE   $81 $0D $32 $00 $7F $12 $31 $00 $7F $0C $2B $00 $7F $00 $2B $00
        .BYTE   $7F $00 $31 $00 $2B $00 $7F $00 $26 $00 $7F $00 $7F $0C $24 $00
        .BYTE   $7F $00 $26 $00 $7F $00 $24 $00 $7F $00 $2B $00 $7F $00 $2B $00
        .BYTE   $7F $00 $31 $00 $7F $00 $2B $00 $7F $00 $29 $30 $7F $0C $29 $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $2B $00
        .BYTE   $81 $09 $29 $00
        .BYTE   $81 $0D $31 $00
        .BYTE   $81 $09 $2B $00
        .BYTE   $81 $0D
        .BYTE   $87 $02
        .WORD   @a - @header            ;=$24, $00
        .BYTE   $86
@b:     .BYTE   $82 $FF $14 $96 $0A $14 $0A
        .BYTE   $81 $0D $32 $00 $7F $00 $32 $00 $7F $00 $32 $00 $7F $18
        .BYTE   $82 $FF $00 $96 $00 $14 $0A
        .BYTE   $81 $09
        .BYTE   $86
@c:     .BYTE   $42 $01 $44 $01
        .BYTE   $87 $02
        .WORD   @c - @header            ;=$B4, $01
        .BYTE   $7F $02 $7F $00
        .BYTE   $86
@d:     .BYTE   $42 $01 $44 $01
        .BYTE   $87 $02
        .WORD   @d - @header            ;=$C1, $01
        .BYTE   $7F $02
        .BYTE   $86
@e:     .BYTE   $42 $01 $44 $01
        .BYTE   $87 $02
        .WORD   @e - @header            ;=$CC, $01
        .BYTE   $7F $02 $7F $00
        .BYTE   $86
@f:     .BYTE   $42 $01 $44 $01
        .BYTE   $87 $06
        .WORD   @f - @header            ;=$D9, $01
        .BYTE   $82 $FF $14 $96 $0A $14 $0A
        .BYTE   $81 $0D $32 $00 $7F $00 $32 $00 $7F $00 $32 $00
        .BYTE   $82 $FF $00 $96 $00 $14 $0A
        .BYTE   $81 $09
        .BYTE   $86
@g:     .BYTE   $39 $01 $3B $01
        .BYTE   $87 $02
        .WORD   @g - @header            ;=$FE, $01
        .BYTE   $7F $02
        .BYTE   $86
@h:     .BYTE   $42 $01 $44 $01
        .BYTE   $87 $02
        .WORD   @h - @header            ;=$09, $02
        .BYTE   $7F $02
        .BYTE   $86
@i:     .BYTE   $42 $01 $44 $01
        .BYTE   $87 $06
        .WORD   @i - @header            ;=$14, $02
        .BYTE   $86
@j:     .BYTE   $39 $01 $3B $01
        .BYTE   $87 $02
        .WORD   @j - @header            ;=$1D, $02
        .BYTE   $7F $02
        .BYTE   $86
@k:     .BYTE   $42 $01 $44 $01
        .BYTE   $87 $02
        .WORD   @k - @header            ;=$28, $02
        .BYTE   $7F $02
        .BYTE   $86
@l:     .BYTE   $86
@m:     .BYTE   $39 $01 $3B $01
        .BYTE   $87 $02
        .WORD   @m - @header            ;=$34, $02
        .BYTE   $7F $02
        .BYTE   $87 $05
        .WORD   @l - @header            ;=$33, $02
        .BYTE   $87 $03
        .WORD   @b - @header            ;=$95, $01
        .BYTE   $82 $FF $14 $96 $0A $14 $0A
        .BYTE   $81 $0D $32 $00 $7F $00 $32 $00 $7F $00 $32 $00 $7F $30 $1B $00
        .BYTE   $1A $00 $19 $00 $7F $0C
        .BYTE   $82 $FF $1E $96 $14 $0A $0A
        .BYTE   $83 $01 $01 $FA $3C $00
        .BYTE   $2B $0C $22 $0C $12 $0C $7F $30
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $82 $FF $12 $96 $10 $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $06
        .BYTE   $86
@n:     .BYTE   $86
@o:     .BYTE   $02 $0C $12 $0C $02 $0C $12 $00 $02 $0C $02 $00 $12 $00 $02 $00
        .BYTE   $02 $0C $12 $0C $07 $0C $17 $0C $07 $0C $17 $00 $07 $0C $07 $00
        .BYTE   $17 $00 $07 $00 $07 $0C $17 $0C
        .BYTE   $87 $04
        .WORD   @o - @header            ;=$87, $02
        .BYTE   $06 $0C $16 $0C $06 $0C $16 $00 $06 $0C $06 $00 $16 $0C $06 $0C
        .BYTE   $16 $00 $06 $00 $0E $0C $0B $0C $0E $00 $0E $00 $0B $00 $0E $0C
        .BYTE   $0E $00 $0B $00 $0E $00 $0E $0C $0B $0C $04 $0C $14 $0C $04 $00
        .BYTE   $04 $00 $14 $00 $04 $0C $04 $00 $14 $00 $04 $00 $04 $0C $14 $0C
        .BYTE   $09 $0C $19 $0C $0A $0C $1A $0C $0B $0C $1B $0C $11 $0C $21 $0C
        .BYTE   $87 $02
        .WORD   @n - @header            ;=$86, $02
        .BYTE   $86
@p:     .BYTE   $02 $0C $12 $0C $02 $0C $12 $00 $02 $0C $02 $00 $12 $00 $02 $00
        .BYTE   $02 $0C $12 $0C $07 $0C $17 $0C $07 $0C $17 $00 $07 $0C $07 $00
        .BYTE   $17 $00 $07 $00 $07 $0C $17 $0C
        .BYTE   $87 $03
        .WORD   @p - @header            ;=$08, $03
        .BYTE   $02 $0C $12 $0C $02 $0C $12 $00 $02 $0C $02 $00 $12 $00 $02 $00
        .BYTE   $02 $0C $12 $0C $09 $0C $0C $0C $0C $0C $0C $0C $0C $0C $0E $0C
        .BYTE   $00 $0C $01 $0C
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $82 $FF $14 $82 $00 $14 $0A
        .BYTE   $81 $0A
        .BYTE   $8A $06
        .BYTE   $86
@q:     .BYTE   $86
@r:     .BYTE   $26 $00
        .BYTE   $81 $06 $26 $00
        .BYTE   $81 $0A $22 $00
        .BYTE   $81 $06 $26 $00
        .BYTE   $81 $0A $32 $00
        .BYTE   $81 $06 $22 $00
        .BYTE   $81 $0A $31 $00 $32 $00
        .BYTE   $81 $06 $31 $00
        .BYTE   $81 $0A $22 $00
        .BYTE   $81 $06 $32 $00
        .BYTE   $81 $0A $22 $00 $26 $00
        .BYTE   $81 $06 $22 $00
        .BYTE   $81 $0A $26 $00
        .BYTE   $81 $06 $26 $00
        .BYTE   $81 $0A $1B $00
        .BYTE   $81 $06 $26 $00
        .BYTE   $81 $0A $1B $00
        .BYTE   $81 $06 $1B $00
        .BYTE   $81 $0A $2B $00
        .BYTE   $81 $06 $1B $00
        .BYTE   $81 $0A $29 $00 $27 $00
        .BYTE   $81 $06 $29 $00
        .BYTE   $81 $0A $27 $00
        .BYTE   $81 $06 $27 $00
        .BYTE   $81 $0A $27 $00 $1B $00
        .BYTE   $81 $06 $27 $00
        .BYTE   $81 $0A $1B $00
        .BYTE   $81 $06 $1B $00
        .BYTE   $81 $0A
        .BYTE   $87 $04
        .WORD   @r - @header            ;=$67, $03
        .BYTE   $21 $18 $1A $18 $1B $18 $21 $18 $1B $00 $7F $00 $1B $00 $7F $00
        .BYTE   $26 $00 $27 $00 $26 $00 $22 $00 $7F $00 $22 $00 $1B $00 $7F $00
        .BYTE   $16 $00 $7F $00 $12 $00 $7F $00 $24 $18 $14 $18 $16 $18 $18 $18
        .BYTE   $19 $00 $7F $00 $19 $00 $7F $00 $17 $00 $7F $00 $17 $00 $7F $00
        .BYTE   $16 $00 $17 $00 $16 $00 $14 $00 $7F $00 $14 $00 $7F $00 $14 $00
        .BYTE   $87 $02
        .WORD   @q - @header            ;=$66, $03
        .BYTE   $86
@s:     .BYTE   $81 $0A $12 $00
        .BYTE   $86
@t:     .BYTE   $16 $00 $19 $00 $21 $00 $32 $00 $8C $8C
        .BYTE   $87 $03
        .WORD   @t - @header            ;=$3D, $04
        .BYTE   $16 $00 $19 $00 $21 $00
        .BYTE   $81 $0A $17 $00
        .BYTE   $86
@u:     .BYTE   $1B $00 $22 $00 $26 $00 $27 $00 $8C $8C
        .BYTE   $87 $03
        .WORD   @u - @header            ;=$56, $04
        .BYTE   $1B $00 $22 $00 $26 $00
        .BYTE   $87 $03
        .WORD   @s - @header            ;=$38, $04
        .BYTE   $81 $0A $12 $00
        .BYTE   $86
@v:     .BYTE   $16 $00 $19 $00 $21 $00 $32 $00 $8C $8C
        .BYTE   $87 $03
        .WORD   @v - @header            ;=$73, $04
        .BYTE   $16 $00 $19 $00 $21 $00 $19 $00
        .BYTE   $86
@w:     .BYTE   $21 $00 $24 $00 $27 $00 $29 $00 $8C $8C
        .BYTE   $87 $03
        .WORD   @w - @header            ;=$8A, $04
        .BYTE   $24 $00 $27 $00 $29 $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $86
@x:     .BYTE   $81 $09 $70 $00 $70 $00
        .BYTE   $81 $0C $71 $00
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $7C
        .WORD   @x - @header            ;=$A5, $04
        .BYTE   $81 $0D $71 $00 $7F $00
        .BYTE   $81 $09 $70 $00 $7F $00 $70 $00 $7F $00 $70 $00 $7F $00 $70 $00
        .BYTE   $7F $00
        .BYTE   $81 $0C $71 $00 $7F $00 $71 $00 $71 $00 $71 $00 $7F $00
        .BYTE   $FF

        .BYTE   $00 $00
        ;

music_labyrinth:                                                        ;$F60C
;===============================================================================
@header:
        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$01E0
        .WORD   @channel3 - @header     ;=$029D
        .WORD   @channel4 - @header     ;=$0351
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $01 $00
        .BYTE   $85 $FF
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $27 $48 $8D $27 $24 $23 $0C $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $20 $00 $8D $20 $48 $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $0C $26 $00 $7F $00
        .BYTE   $81 $09 $26 $00
        .BYTE   $81 $0D $27 $00 $8D $27 $48 $8D $27 $24 $23 $0C $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $20 $00 $8D $20 $48 $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $0C $23 $00 $7F $0C $20 $00 $7F $00
        .BYTE   $81 $09 $20 $00
        .BYTE   $81 $0D $20 $00 $1A $12 $17 $0C $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $17 $0C $1A $00 $7F $00
        .BYTE   $81 $09 $1A $00
        .BYTE   $81 $0D $20 $00 $8D $20 $48 $7F $00
        .BYTE   $81 $09 $20 $00
        .BYTE   $81 $0D
        .BYTE   $86
@a:     .BYTE   $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$CE, $00
        .BYTE   $20 $00 $7F $00
        .BYTE   $81 $09 $20 $00
        .BYTE   $81 $0D $20 $00 $1A $12 $17 $0C $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $17 $0C $1A $00 $7F $00
        .BYTE   $81 $09 $1A $00
        .BYTE   $81 $0D $20 $00 $8D $20 $48 $7F $00
        .BYTE   $81 $09 $20 $00
        .BYTE   $81 $0D
        .BYTE   $86
@b:     .BYTE   $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D
        .BYTE   $87 $03
        .WORD   @b - @header            ;=$1E, $01
        .BYTE   $30 $00 $8D $30 $0C $30 $00 $2A $12 $27 $0C $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $23 $12 $25 $0C $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $20 $0C $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $25 $0C $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $30 $00 $8D $30 $0C $30 $00 $2A $12 $27 $0C $23 $00
        .BYTE   $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $23 $12 $25 $0C $27 $00 $7F $00
        .BYTE   $81 $09 $27 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $20 $0C $23 $00 $7F $00
        .BYTE   $81 $09 $23 $00
        .BYTE   $81 $0D $25 $12 $25 $00 $25 $00 $7F $00
        .BYTE   $81 $09 $25 $00
        .BYTE   $81 $0D $25 $0C $26 $00 $7F $0C $27 $00
        .BYTE   $8D     ; superfluous
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $96 $00 $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $00 $12
        .BYTE   $86
@c:     .BYTE   $03 $12 $05 $12 $06 $0C $07 $00 $7F $00
        .BYTE   $81 $0A $07 $00
        .BYTE   $81 $0E $07 $00 $0C $12 $0D $12 $0E $0C $00 $00 $7F $00
        .BYTE   $81 $0A $00 $00
        .BYTE   $81 $0E $00 $00
        .BYTE   $87 $07
        .WORD   @c - @header            ;=$EF, $01
        .BYTE   $03 $12 $05 $12 $06 $0C $07 $00 $7F $00
        .BYTE   $81 $0A $07 $00
        .BYTE   $81 $0E $07 $00 $0C $12 $0D $12 $0E $0C $00 $00
        .BYTE   $86
@d:     .BYTE   $00 $12
        .BYTE   $87 $03
        .WORD   @d - @header            ;=$32, $02
        .BYTE   $00 $00 $00 $00 $00 $00
        .BYTE   $86
@e:     .BYTE   $0D $12
        .BYTE   $87 $03
        .WORD   @e - @header            ;=$3F, $02
        .BYTE   $0D $00 $0D $00 $0D $00
        .BYTE   $86
@f:     .BYTE   $08 $12
        .BYTE   $87 $03
        .WORD   @f - @header            ;=$4C, $02
        .BYTE   $08 $00 $08 $00 $08 $00
        .BYTE   $86
@g:     .BYTE   $07 $12
        .BYTE   $87 $03
        .WORD   @g - @header            ;=$59, $02
        .BYTE   $07 $00 $07 $00 $07 $00
        .BYTE   $86
@h:     .BYTE   $00 $12
        .BYTE   $87 $03
        .WORD   @h - @header            ;=$66, $02
        .BYTE   $00 $00 $00 $00 $00 $00
        .BYTE   $86
@i:     .BYTE   $0D $12
        .BYTE   $87 $03
        .WORD   @i - @header            ;=$73, $02
        .BYTE   $0D $00 $0D $00 $0D $00
        .BYTE   $86
@j:     .BYTE   $08 $12
        .BYTE   $87 $03
        .WORD   @j - @header            ;=$80, $02
        .BYTE   $08 $00 $08 $00 $08 $00 $07 $12 $07 $12 $0D $00 $0D $00 $0D $00
        .BYTE   $0E $00 $0E $00 $0E $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $84 $04 $00
        .BYTE   $82 $FF $14 $8C $00 $14 $0A
        .BYTE   $81 $0B
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $86
@k:     .BYTE   $81 $0B
        .BYTE   $86
@l:     .BYTE   $30 $00 $7F $00 $8C $8C $8C $8C $30 $00 $8B $8B $8B
        .BYTE   $87 $06
        .WORD   @l - @header            ;=$B0, $02
        .BYTE   $81 $0A $20 $0C $20 $00 $7F $0C $20 $00 $7F $0C $17 $00
        .BYTE   $8D $17 $24 $23 $00 $25 $00 $26 $00 $27 $00 $26 $00 $25 $00
        .BYTE   $23 $00 $20 $00 $1A $00 $20 $00 $1A $00 $17 $0C $1A $00 $17 $00
        .BYTE   $87 $02
        .WORD   @k - @header            ;=$AD, $02
        .BYTE   $86
@m:     .BYTE   $7F $0C $17 $00 $17 $0C $7F $00 $12 $0C $1A $00 $7F $0C $20 $12
        .BYTE   $20 $00 $1A $00 $7F $0C $12 $0C $15 $00 $7F $0C $17 $12 $17 $00
        .BYTE   $13 $00 $7F $0C $15 $0C $16 $00 $7F $0C $17 $00 $7F $0C $17 $00
        .BYTE   $13 $12 $15 $0C $13 $00 $7F $0C $17 $00
        .BYTE   $87 $02
        .WORD   @m - @header            ;=$F3, $02
        .BYTE   $86
@n:     .BYTE   $17 $48 $17 $48 $20 $48 $20 $12 $22 $00 $23 $00 $25 $00 $27 $00
        .BYTE   $25 $00 $23 $00 $22 $00 $1A $00 $17 $00
        .BYTE   $87 $02
        .WORD   @n - @header            ;=$32, $03
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $09
        .BYTE   $8A $06
        .BYTE   $88
        .BYTE   $86
@o:     .BYTE   $81 $09 $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0B $71 $0C
        .BYTE   $81 $09 $70 $00
        .BYTE   $87 $2F
        .WORD   @o - @header            ;=$57, $03
        .BYTE   $81 $09 $70 $00 $7F $00 $70 $00
        .BYTE   $81 $0B $71 $00 $71 $00 $71 $00
        .BYTE   $FF

        .BYTE   $00 $00 $00 $00
        ;

music_allEmeralds:                                                      ;$F98C
;===============================================================================
@header:
        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$003E
        .WORD   @channel3 - @header     ;=$006B
        .WORD   @channel4 - @header     ;=$0096
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $01 $00 $02 $00
        .BYTE   $85 $FF
        .BYTE   $83 $01 $01 $FE $F8 $FF
        .BYTE   $82 $FF $00 $96 $00 $14 $0A
        .BYTE   $81 $08 $7F $30 $7F $30
        .BYTE   $86
@a:     .BYTE   $14 $24
        .BYTE   $8B
        .BYTE   $87 $04
        .WORD   @a - @header            ;=$25, $00
        .BYTE   $14 $24 $14 $24 $14 $24
        .BYTE   $86
@b:     .BYTE   $14 $24
        .BYTE   $8C
        .BYTE   $87 $09
        .WORD   @b - @header            ;=$33, $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $83 $01 $01 $FE $F8 $FF
        .BYTE   $82 $FF $00 $96 $00 $14 $0A
        .BYTE   $81 $05 $7F $30 $7F $3C
        .BYTE   $86
@c:     .BYTE   $14 $24
        .BYTE   $8B
        .BYTE   $87 $04
        .WORD   @c - @header            ;=$52, $00
        .BYTE   $14 $24 $14 $24 $14 $24
        .BYTE   $86
@d:     .BYTE   $14 $24
        .BYTE   $8C
        .BYTE   $87 $09
        .WORD   @d - @header            ;=$60, $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $82 $0A $14 $0A
        .BYTE   $81 $06
        .BYTE   $8A $03
        .BYTE   $86
@e:     .BYTE   $4B $00 $3B $00 $4B $00 $3B $00
        .BYTE   $8B
        .BYTE   $87 $07
        .WORD   @e - @header            ;=$77, $00
        .BYTE   $86
@f:     .BYTE   $4B $00 $3B $00 $4B $00 $3B $00
        .BYTE   $8C
        .BYTE   $87 $0D
        .WORD   @f - @header            ;=$85, $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $88
        .BYTE   $7F $10
        .BYTE   $FF
        ;

music_emerald:                                                          ;$FA26
;===============================================================================
@header:

        .WORD   @channel1 - @header     ;=$000A
        .WORD   @channel2 - @header     ;=$0086
        .WORD   @channel3 - @header     ;=$00BC
        .WORD   @channel4 - @header     ;=$00FB
        .WORD   $0000

@channel1:
        ;-----------------------------------------------------------------------
        .BYTE   $80 $05 $00 $06 $00
        .BYTE   $85 $FF
        .BYTE   $83 $10 $01 $04 $07 $00
        .BYTE   $82 $FF $0A $96 $0A $14 $0A
        .BYTE   $81 $0D
        .BYTE   $8A $06
        .BYTE   $24 $00
        .BYTE   $81 $0A $1B $00
        .BYTE   $81 $0D $24 $00 $24 $00 $24 $0C $24 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $0D $1B $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $0D $24 $00
        .BYTE   $81 $0A $1B $00
        .BYTE   $81 $0D $26 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $81 $0D $22 $00
        .BYTE   $81 $0A $26 $00
        .BYTE   $81 $0D $26 $00
        .BYTE   $81 $0A $22 $00
        .BYTE   $81 $0D $27 $00
        .BYTE   $81 $0A $26 $00
        .BYTE   $81 $0D $24 $00
        .BYTE   $81 $0A $27 $00
        .BYTE   $81 $0D $27 $00
        .BYTE   $81 $0A $24 $00
        .BYTE   $82 $FF $00 $96 $00 $14 $0A
        .BYTE   $28 $48 $8D $28 $24
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel2:
        ;-----------------------------------------------------------------------
        .BYTE   $82 $FF $14 $96 $14 $14 $0A
        .BYTE   $81 $0E
        .BYTE   $8A $06
        .BYTE   $04 $12 $04 $00 $04 $0C $04 $0C $0E $0C $04 $0C $02 $0C $0C $0C
        .BYTE   $02 $0C $00 $0C $00 $0C $00 $0C $04 $0C $04 $0C $02 $0C
        .BYTE   $82 $FF $00 $96 $00 $14 $0A
        .BYTE   $04 $48
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel3:
        ;-----------------------------------------------------------------------
        .BYTE   $84 $04 $00
        .BYTE   $82 $FF $14 $82 $0A $14 $0A
        .BYTE   $81 $0B
        .BYTE   $8A $06
        .BYTE   $18 $12 $18 $00 $18 $0C $18 $0C $18 $0C $18 $0C $12 $00 $19 $00
        .BYTE   $22 $00 $24 $00 $26 $00 $29 $00 $20 $00 $22 $00 $24 $00 $27 $00
        .BYTE   $30 $00 $32 $00
        .BYTE   $86
@a:     .BYTE   $34 $04 $36 $04
        .BYTE   $87 $0F
        .WORD   @a - @header            ;=$EF, $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF

@channel4:
        ;-----------------------------------------------------------------------
        .BYTE   $81 $00
        .BYTE   $88
        .BYTE   $7F $00
        .BYTE   $FF
        ;

sfx_fb27:                                                               ;$FB27
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $83 $03 $01 $FA $F0 $FF
        .BYTE   $81 $0F $15 $03 $1A $15
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fb43:                                                               ;$FB43
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $8A $01
        .BYTE   $81 $0F $10 $00 $07 $00 $04 $00 $00 $00
        .BYTE   $86
@a:     .BYTE   $17 $00 $15 $00 $14 $00 $12 $00 $10 $00 $0B $00 $8C $8C $8C $8C
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$1A, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fb74:                                                               ;$FB74
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00
        
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F $34 $04 $37 $04 $40 $04 $8C $8C $40 $04 $8C $8C $40 $04
        .BYTE   $8C $8C $40 $04
        .BYTE   $81 $00 $FE
        ;

sfx_fb98:                                                               ;$FB98
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $8A $01 $28 $00 $2A $00 $28 $00 $2A $00 $7F $02
        .BYTE   $86
@a:     .BYTE   $28 $00 $2A $00
        .BYTE   $87 $09
        .WORD   @a - @header            ;=$1C, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fbbf:                                                               ;$FBBF
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $8A $01
        .BYTE   $86
@a:     .BYTE   $17 $00 $19 $00 $1B $00 $20 $00 $22 $00 $24 $00 $8C $8C
        .BYTE   $87 $07
        .WORD   @a - @header            ;=$12, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fbe6:                                                               ;FBE6
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $83 $01 $01 $FA $F2 $FF
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0A
        .BYTE   $86
@a:     .BYTE   $3B $02 $8D $8B
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$16, $00
        .BYTE   $3B $02
        .BYTE   $83 $01 $01 $FA $17 $00
        .BYTE   $86
@b:     .BYTE   $4B $03 $8D $8C
        .BYTE   $87 $0E
        .WORD   @b - @header            ;=$27, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fc18:                                                               ;$FC18
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $83 $01 $01 $FA $FE $FF
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0A
        .BYTE   $86
@a:     .BYTE   $3B $0C $8D $8B
        .BYTE   $87 $04
        .WORD   @a - @header            ;=$16, $00
        .BYTE   $86
@b:     .BYTE   $3B $0C $8D $8C
        .BYTE   $87 $06
        .WORD   @b - @header            ;=$1F, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fc42:                                                               ;$FC42
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $86
@a:     .BYTE   $10 $01 $30 $01 $8C
        .BYTE   $87 $0F
        .WORD   @a - @header            ;=$10, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fc5e:                                                               ;$FC5E
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $83 $01 $01 $FA $BF $FF
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $8A $06
        .BYTE   $81 $0F
        .BYTE   $86
@a:     .BYTE   $10 $00 $8C $12 $00 $8C $14 $00 $8C $15 $00 $8C $17 $00 $8C
        .BYTE   $19 $00
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$18, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fc8e:                                                               ;$FC8E
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $8A $04
        .BYTE   $81 $0F $38 $00 $40 $00 $43 $00 $40 $00 $43 $00
        .BYTE   $86
@a:     .BYTE   $48 $00 $7F $00 $8C $8C
        .BYTE   $87 $07
        .WORD   @a - @header            ;=$1C, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fcb7:                                                               ;FCB7
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $86
@a:     .BYTE   $18 $01 $7F $01 $8C $10 $01 $7F $01 $8C
        .BYTE   $87 $07
        .WORD   @a - @header            ;=$10, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fcd8:                                                               ;$FCD8
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $8A $01
        .BYTE   $81 $0F
        .BYTE   $86
@a:     .BYTE   $3B $00 $49 $00 $7F $02 $3B $00 $49 $00 $7F $02
        .BYTE   $87 $FF
        .WORD   @a - @header            ;=$12, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fcfd:                                                               ;$FCFD
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $1E $C8 $1E $0A $01
        .BYTE   $83 $01 $01 $FA $F0 $FF
        .BYTE   $81 $0F $10 $02 $7F $02
        .BYTE   $86
@a:     .BYTE   $19 $0C $8C $8C $8C $8C
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$1A, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fd24:                                                               ;FD24
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $00 $0A
        .BYTE   $83 $01 $01 $FA $C4 $FF
        .BYTE   $81 $00
        .BYTE   $86
@a:     .BYTE   $00 $09 $8B
        .BYTE   $87 $0A
        .WORD   @a - @header            ;=$16, $00
        .BYTE   $86
@b:     .BYTE   $86
@c:     .BYTE   $00 $09 $00 $09 $8B
        .BYTE   $87 $04
        .WORD   @c - @header            ;=$1F, $00
        .BYTE   $86
@d:     .BYTE   $00 $09
        .BYTE   $87 $08
        .WORD   @d - @header            ;=$29, $00
        .BYTE   $86
@e:     .BYTE   $00 $09 $00 $09 $8C
        .BYTE   $87 $04
        .WORD   @e - @header            ;=$30, $00
        .BYTE   $87 $FF
        .WORD   @b - @header            ;=$1E, $00
        .BYTE   $FE
        ;

sfx_fd62:                                                               ;FD62
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FF $00 $0A $01
        .BYTE   $81 $0F
        .BYTE   $86
@a:     .BYTE   $00 $01 $01 $01
        .BYTE   $87 $02
        .WORD   @a - @header            ;=$10, $00
        .BYTE   $7F $05
        .BYTE   $86
@b:     .BYTE   $00 $01 $01 $01
        .BYTE   $87 $10
        .WORD   @b - @header            ;=$1B, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fd88:                                                               ;$FD88
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $03     $0001   $0001   $00

        .BYTE   $81 $0D
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $8A $02
        .BYTE   $89 $05
        .BYTE   $00 $00 $7F $00
        .BYTE   $89 $04
        .BYTE   $81 $0C $00 $00 $8B
        .BYTE   $86
@a:     .BYTE   $00 $00 $8C
        .BYTE   $87 $0D
        .WORD   @a - @header            ;=$1F, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fdb1:                                                               ;$FDB1
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $8A $01
        .BYTE   $01 $00 $7F $00 $02 $00 $7F $00 $03 $00 $7F $00
        .BYTE   $86
@a:     .BYTE   $04 $00 $7F $00
        .BYTE   $87 $0F
        .WORD   @a - @header            ;=$1E, $00
        .BYTE   $86
@b:     .BYTE   $04 $00 $7F $00 $7F $00 $8C
        .BYTE   $87 $0F
        .WORD   @b - @header            ;=$27, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fde6:                                                               ;$FDE6
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $03     $0001   $0001   $00

        .BYTE   $81 $07
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $89 $06
        .BYTE   $86
@a:     .BYTE   $00 $0C $8B
        .BYTE   $87 $07
        .WORD   @a - @header            ;=$12, $00
        .BYTE   $00 $30
        .BYTE   $86
@b:     .BYTE   $00 $02 $8C
        .BYTE   $87 $0E
        .WORD   @b - @header            ;=$1C, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fe0c:                                                               ;$FE0C
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $03     $0001   $0001   $00

        .BYTE   $81 $0F
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $89 $06
        .BYTE   $86
@a:     .BYTE   $00 $03 $7F $03 $8C $8C $8C $8C
        .BYTE   $87 $03
        .WORD   @a - @header            ;=$12, $00
        .BYTE   $00 $03
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fe2f:                                                               ;$FE2F
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $00 $0A
        .BYTE   $81 $0E
        .BYTE   $86
@a:     .BYTE   $0C $02 $0D $02
        .BYTE   $87 $0A
        .WORD   @a - @header            ;=$10, $00
        .BYTE   $FE
        ;

sfx_fe48:                                                               ;$FE48
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0D $49 $03
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fe5c:                                                               ;$FE5C
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $03     $0001   $0001   $00

        .BYTE   $81 $0F
        .BYTE   $82 $FF $0A $96 $14 $50 $0A
        .BYTE   $8A $10
        .BYTE   $89 $06
        .BYTE   $00 $12
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fe74:                                                               ;$FE74
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $8A $01
        .BYTE   $81 $0F $0C $02 $7F $02
        .BYTE   $86
@a:     .BYTE   $11 $00 $09 $00 $07 $00 $04 $00 $03 $00 $00 $00 $0E $00 $0C $00
        .BYTE   $8C $8C $8C
        .BYTE   $87 $04
        .WORD   @a - @header            ;=$16, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fea4:                                                               ;$FEA4
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00
        
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $8A $01
        .BYTE   $17 $00 $10 $00 $07 $00 $00 $00 $0C $00
        .BYTE   $86
@a:     .BYTE   $4B $00 $0B $00 $8C
        .BYTE   $87 $0F
        .WORD   @a - @header            ;=$1C, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fecc:                                                               ;$FECC
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $86
@a:     .BYTE   $19 $01 $39 $01 $8C
        .BYTE   $87 $0F
        .WORD   @a - @header            ;=$10, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_fee8:                                                               ;$FEE8
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $03     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $8A $03
        .BYTE   $81 $0E
        .BYTE   $89 $06
        .BYTE   $86
@a:     .BYTE   $00 $00 $7F $00 $8C
        .BYTE   $87 $0E
        .WORD   @a - @header            ;=$14, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_ff08:                                                               ;$FF08
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00
        
        .BYTE   $82 $FF $00 $FA $00 $32 $0A
        .BYTE   $81 $0F
        .BYTE   $8A $01
        .BYTE   $09 $00 $7F $00 $47 $00 $7F $00 $40 $00 $5B $00 $7F $00 $57 $02
        .BYTE   $54 $00 $4B $00 $7F $02 $5B $00 $7F $00 $54 $00 $7F $00 $5B $00
        .BYTE   $7F $00
        .BYTE   $81 $0C
        .BYTE   $86
@a:     .BYTE   $5B $00 $0C $00 $7F $00 $57 $00 $8C
        .BYTE   $87 $06
        .WORD   @a - @header            ;=$36, $00
        .BYTE   $81 $00
        .BYTE   $FE
        ;

sfx_ff4e:                                                               ;$FF4E
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $82 $FF $00 $FA $00 $00 $0A
        .BYTE   $81 $0B
        .BYTE   $8A $01
        .BYTE   $19 $00 $8B $15 $00 $8B $22 $00 $27 $00 $7F $03 $2B $00 $32 $00
        .BYTE   $36 $00 $39 $00 $7F $06
        .BYTE   $81 $05 $2B $00 $32 $00 $36 $00 $39 $00
        .BYTE   $81 $00
        .BYTE   $FE

        .BYTE   $00
        ;

sfx_ff83:                                                              ;$FF83
;===============================================================================
@header:
        .TABLE  BYTE    WORD    WORD    BYTE
        .ROW    $02     $0001   $0001   $00

        .BYTE   $83 $01 $01 $FA $F2 $FF
        .BYTE   $82 $FF $00 $FA $00 $00 $0A
        .BYTE   $86
@a:     .BYTE   $81 $0A
        .BYTE   $86
@b:     .BYTE   $30 $06 $8B
        .BYTE   $87 $04
        .WORD   @b - @header            ;=$17, $00
        .BYTE   $86
@c:     .BYTE   $30 $06 $8C $8C
        .BYTE   $87 $05
        .WORD   @c - @header            ;=$1F, $00
        .BYTE   $87 $FF
        .WORD   @a - @header            ;=$14, $00
        .BYTE   $81 $00
        .BYTE   $FE

;===============================================================================

        ; the background text in the original ROM
.BYTE   "Master System & Game Gear Version.  '1991 (C)Ancient. (BANK0-4)" $A2
.BYTE   "SONIC THE HEDGE"
        ;

.ENDS