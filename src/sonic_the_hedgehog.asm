.INC    "inc/sms.asm"                   ; hardware definitions
.INC    "inc/vars.asm"
.INC    "inc/mob.asm"

; position on the screen of the player's lives display
.DEFINE HUD_LIVES_X     16
.DEFINE HUD_LIVES_Y     172
; number of thousands of pts to get an extra life
.DEFINE SCORE_1UP_PTS   5
; number of frames to wait before the idle animation kicks in
.DEFINE IDLE_TIME       6 * 60

.BANK   0       SLOT "SLOT0"
.ORG    $0000

start:                                                                  ;$0000
;===============================================================================
        di                              ; disable interrupts
        im      1                       ; set the interrupt mode to 1 --
                                        ; $0038 will be called at 50/60Hz

@wait:  ; wait for the scanline to reach 176 (no idea why)
        in      A,      [SMS_PORTS_SCANLINE]
        cp      176
        jr      nz,     @wait

        jp      init
        ;

.ORG    $0018

rst_playMusic:                                                          ;$0018
;===============================================================================
; in    A       music ID
;-------------------------------------------------------------------------------
        jp      call_playMusic
        ;

.ORG    $0020

rst_muteSound:                                                          ;$0020
;===============================================================================
        jp      call_muteSound
        ;

.ORG    $0028

rst_playSFX:                                                            ;$0028
;===============================================================================
; in    A       sfx ID
;-------------------------------------------------------------------------------
        jp      call_playSFX
        ;

.ORG    $0038

irq:                                                                    ;$0038
;===============================================================================
; Every 1/50th (PAL) or 1/60th (NTSC) of a second, an interrupt is generated
; and control passes here. there's only a small amount of space between this
; routine and the pause handler, so we just jump to the routine proper
;-------------------------------------------------------------------------------
        jp      interruptHandler
        ;
        
copyright:                                                              ;$003B
;===============================================================================
; a short copyright message is wedged between the IRQ and NMI routines
; in the original ROM.

        .BYTE   "Developed By (C) 1991 Ancient - S" $A5 "Hayashi." $00

.ORG    $0066

pause:                                                                  ;$0066
;===============================================================================
; pressing the PAUSE button causes an interrupt and jumps to $0066.
;
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        di      ; disable interrupts
        push    AF

        ; level time HUD / lightning flags
        ld      A,      [IY+Vars.timeLightningFlags]
        ; flip bit 3 (the pause bit)
        xor     %00001000
        ; save it back
        ld      [IY+Vars.timeLightningFlags],   A

        pop     AF
        ei      ; enable interrupts

        ret
        ;

interruptHandler:                                                       ;$0073
;===============================================================================
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        di      ; disable interrupts during interrupt!

        ; push everything we're going to use to the stack so that when we
        ; return from the interrupt we don't find that our registers have
        ; changed mid-instruction!

        push    AF
        push    HL
        push    DE
        push    BC

        ; get the status of the VDP
        ; (the Master System's GPU)
        in      A,      [SMS_PORTS_VDP_CONTROL]

        bit     7,      [IY+Vars.flags6]        ; check the underwater flag
        jr      z,      @_1                     ; if off, skip ahead

        ; the raster split is controlled across multiple interrupts, a counter
        ; is used to remember at which step the procedure is at. a value of 0
        ; means that it needs to be initialised, and then it counts down from 3

        ; read current step value
        ld      A,      [RAM_RASTERSPLIT_STEP]
        and     A                       ; keep value, but update flags
        jp      nz,     doRasterSplit   ; not 0?, deal with particulars

        ; initialise raster split:
        ;-----------------------------------------------------------------------
        ; check the water line height:
        ld      A,      [RAM_WATERLINE]
        and     A
        jr      z,      @_1             ; if it's zero (above the screen), skip

        cp      $FF                     ; or 255 (below the screen),
        jr      z,      @_1             ; skip

        ; copy the water line position into the working space for the raster
        ; split. this is to avoid the water line changing height between the
        ; multiple interrupts needed to produce the split, I think
        ld      [RAM_RASTERSPLIT_LINE], A

        ; set the line interrupt to fire at line 10 (top of the screen).
        ; we will then set another interrupt to fire where we want the
        ; split to occur. first send the data ("10") to the VDP...
        ld      A,                      10
        out     [SMS_PORTS_VDP_CONTROL],A
        ; and then the control command (VDP register 10)
        ld      A,                      SMS_VDP_REGISTER_10
        out     [SMS_PORTS_VDP_CONTROL],A

        ; enable line interrupt IRQs (bit 5 of VDP register 0)
        ld      A,                      [RAM_VDPREGISTER_0]
        or      %00010000               ; set bit 5
        out     [SMS_PORTS_VDP_CONTROL],A
        ; write to VDP register 0
        ld      A,                      SMS_VDP_REGISTER_0
        out     [SMS_PORTS_VDP_CONTROL],A

        ; initialise the step counter for the water line raster split
        ld      A,                      3
        ld      [RAM_RASTERSPLIT_STEP], A

        ;-----------------------------------------------------------------------
@_1:    push    IX
        push    IY

        ; remember the current page 1 & 2 banks
        ld      HL,     [RAM_SLOT1]
        push    HL

        ; if the main thread is not held up at the `waitForInterrupt` routine
        bit     0,      [IY+Vars.flags0]
        call    nz,     _01A0   ; continue to maintain water-line raster split
        ; and if it is...
        bit     0,      [IY+Vars.flags0]
        call    z,      @_00f7

        ; interrupts are re-enabled before the interrupt handler is finished
        ; so that should the remainder of this handler take too long, the
        ; water-line raster split can still interrupt at the correct scan-line
        ; -- with thanks to Valley Bell and Calindro for pointing this out
        ei

        ; we can compile with or without sound:
        .IFDEF  OPTION_SOUND
                ; switch in the music engine & data
                ld      A,                      :sound.update
                ld      [SMS_MAPPER_SLOT1],     A
                ld      [RAM_SLOT1],            A
                ; process the sound for this frame
                call    sound.update
        .ENDIF

        call    readJoypad
        bit     4,      [IY+Vars.joypad]        ; joypad button 1?
        call    z,      @setJoypadButtonB       ; set joypad button 2 too

        call    _0625

        ; check for the reset button:
        ; read 2nd joypad port which has extra bits for lightgun / reset button
        in      A,      [sms.ports.joy_b]      
        and     %00010000                       ; check bit 4
        jp      z,      start                   ; reset!

        ;-----------------------------------------------------------------------

        ; return pages 1 & 2 to the banks
        ; before we started messing around here
        pop     HL
        ld      [SMS_MAPPER_SLOT1],     HL
        ld      [RAM_SLOT1],            HL

        ; pull everything off the stack so that the code that
        ; was running before the interrupt doesn't explode
        pop     IY
        pop     IX
        pop     BC
        pop     DE
        pop     HL
        pop     AF

        ret

@setJoypadButtonB:                                                      ;$00F2
        ;=======================================================================
        res     5,      [IY+Vars.joypad]        ; set joypad button 2 as on
        ret

@_00f7:                                                                 ;$00F7
        ;=======================================================================
        ; blank the screen (remove bit 6 of VDP register 1)
        ld      A,      [RAM_VDPREGISTER_1]     ; cache value from RAM
        and     %10111111                       ; remove bit 6
        out     [SMS_PORTS_VDP_CONTROL],A       ; write the value,
        ld      A,      SMS_VDP_REGISTER_1
        out     [SMS_PORTS_VDP_CONTROL],A       ; then register.no

        ; horizontal scroll:
        ld      A,      [RAM_VDPSCROLL_HORZ]
        ; I don't understand the reason for this
        neg
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      SMS_VDP_REGISTER_8
        out     [SMS_PORTS_VDP_CONTROL],        A

        ; vertical scroll:
        ld      A,      [RAM_VDPSCROLL_VERT]
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,              SMS_VDP_REGISTER_9
        out     [SMS_PORTS_VDP_CONTROL],        A

        bit     5,      [IY+Vars.flags0]
        call    nz,     fillScrollTiles

        bit     5,      [IY+Vars.flags0]
        call    nz,     loadPaletteFromInterrupt

        ; turn the screen back on
        ; (or if it was already blank before this function, leave it blank)
        ld      A,      [RAM_VDPREGISTER_1]
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      SMS_VDP_REGISTER_1
        out     [SMS_PORTS_VDP_CONTROL],        A

        ; TODO: set these bank numbers according to the data location
        ld      A,                      8       ; Sonic sprites?
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      9
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ; does the Sonic sprite need updating?
        ; (the particular frame of animation is copied to the VRAM)
        bit     7,      [IY+Vars.timeLightningFlags]
        call    nz,     updateSonicSpriteFrame

        ; TODO: set these bank numbers according to the data location
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ; update sprite table?
        bit     1,      [IY+Vars.flags0]
        call    nz,     updateVDPSprites

        bit     5,      [IY+Vars.flags0]
        call    z,      loadPaletteFromInterrupt

        ld      A,      [RAM_D2AB+1]
        and     %10000000
        call    z,      _38b0

        ld      A,              $FF
        ld      [RAM_D2AB+1],   A

        set     0,      [IY+Vars.flags0]
        ret

loadPaletteFromInterrupt:                                               ;$0174
;===============================================================================
; loads a palette using the parameters set first by `loadPaletteOnInterrupt`.
;
; in    IY                      address of common variables (used throughout)
;       LOADPALETTE_ADDRESS     address to the palette data
;       LOADPALETTE_FLAGS       flags to load tile / sprite palettes or both
;-------------------------------------------------------------------------------

        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ; if the level is underwater then skip loading the palette as the
        ; palettes are handled by the code that does the raster split
        bit     7,      [IY+Vars.flags6]        ; underwater flag
        jr      nz,     @_1

        ; get the palette loading parameters that were assigned
        ; by the main thread (i.e. `loadPaletteOnInterrupt`)
        ld      HL,     [RAM_LOADPALETTE_ADDRESS]
        ld      A,      [RAM_LOADPALETTE_FLAGS]

        ; check flag to specify loading palette
        bit     3,      [IY+Vars.flags0]
        ; load the palette if flag is set
        call    nz,     loadPalette
        ; unset flag so it doesn't happen again
        res     3,      [IY+Vars.flags0]
        ret

        ; when the level is underwater, different logic controls loading
        ; the palette as we have to deal with the water line
@_1:    call    loadPaletteFromInterrupt_water
        ret

_01A0:                                                                  ;$01A0
;===============================================================================
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        bit     7,      [IY+Vars.flags6]        ; check the underwater flag
        ret     z                               ; if off, leave now

        ; switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
        ; TODO: set these bank numbers according to the data location
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ; this seems quite pointless but could do with
        ; killing a specific amount of time
        ld      B,      $00
@nop:   nop
        djnz    @nop

        ; NOTE: fall through the procedure below...
        ; TODO: fix this up

loadPaletteFromInterrupt_water:                                         ;$01BA
;===============================================================================
; called only from `loadPaletteFromInterrupt`
;
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        ; get the position of the water line on screen
        ld      A,      [RAM_WATERLINE]
        and     A                       ; set the CPU flags based on its value
        jr      z,      @_2             ; is it 0? (above the screen)
        cp      $FF                     ; or $FF? (below the screen)
        jr      nz,     @_2             ; ...skip ahead

        ; below water:
        ;-----------------------------------------------------------------------
        ; below the water line a fixed palette is used without colour cycles

        ; select the palette:
        ; labyrinth Act 1 & 2 share an underwater palette and Labyrinth Act 3
        ; uses a special palette to account for the boss / capsule, which
        ; normally load their palettes on-demand
        ld      HL,     underwaterPalette
        ;underwater boss palette?
        bit     4,      [IY+Vars.timeLightningFlags]
        jr      z,      @_1
        ld      HL,     underwaterPalette_Boss

@_1:    ld      A,      %00000011       ; "load tile & sprite palettes"
        call    loadPalette             ; load the relevant underwater palette
        ret

        ; above water:
        ;-----------------------------------------------------------------------
@_2:    ld      A,      [RAM_CYCLEPALETTE_INDEX]
        add     A,      A               ; x2
        add     A,      A               ; x4
        add     A,      A               ; x8
        add     A,      A               ; x16
        ld      E,      A
        ld      D,      $00
        ld      HL,     [RAM_CYCLEPALETTE_POINTER]
        add     HL,     DE
        ld      A,      %00000001
        call    loadPalette

        ; load the sprite palette specifically for Labyrinth
        ld      HL,     paletteData@labyrinth+16
        ld      A,      %00000010
        call    loadPalette

        ret

doRasterSplit:                                                          ;$01F2
;===============================================================================
; in    IY      address of the common variables (used throughout)
;       A       the raster split step number (counts down from 3)
;-------------------------------------------------------------------------------
        ; step 1?
        cp      1
        jr      z,      @_2
        ; step 2?
        cp      2
        jr      z,      @_1

        ; step 3:
        ;-----------------------------------------------------------------------
        ; set counter at step 2
        dec     A
        ld      [RAM_RASTERSPLIT_STEP], A

        in      A,      [SMS_PORTS_SCANLINE]
        ld      C,      A
        ld      A,      [RAM_RASTERSPLIT_LINE]
        sub     C       ; work out the difference

        ; set VDP register 10 with the scanline number to interrupt at next
        ; (that is, set the next interrupt to occur at the water line)
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      SMS_VDP_REGISTER_10
        out     [SMS_PORTS_VDP_CONTROL],        A

        jp      @_3

        ; step 2:
        ;-----------------------------------------------------------------------
@_1:    ; we don't do anything on this step
        dec     A
        ld      [RAM_RASTERSPLIT_STEP], A
        jp      @_3

        ; step 1:
        ;-----------------------------------------------------------------------
@_2:    dec     A
        ld      [RAM_RASTERSPLIT_STEP], A

        ; set the VDP to point at the palette
        ld      A,                              $00
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,                              %11000000
        out     [SMS_PORTS_VDP_CONTROL],        A

        ld      B,      16
        ld      HL,     underwaterPalette

        ; underwater boss palette?
        ; the boss level of Labyrinth is hardwired to use a specific palette
        ; as it is both underwater and contains the boss who would normally
        ; auto-load their palette and this would conflict
        bit     4,      [IY+Vars.timeLightningFlags]
        jr      z,      @loop
        ld      HL,     underwaterPalette_Boss

        ; copy the palette into the VDP
@loop:  ld      A,                      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL

        nop

        ld      A,                      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL
        djnz    @loop

        ld      A,      [RAM_VDPREGISTER_0]
        and     %11101111               ; remove bit 4: disable line interrupts
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,                      SMS_VDP_REGISTER_0
        out     [SMS_PORTS_VDP_CONTROL],A

@_3:    pop     BC
        pop     DE
        pop     HL
        pop     AF
        ei
        ret

underwaterPalette:                                                      ;$024B
;===============================================================================
        .TABLE  DSB 16
@tile:  .ROW    $10 $14 $14 $18 $35 $34 $2C $39 $21 $20 $1E $09 $04 $1E $10 $3F
@sprite:.ROW    $00 $20 $35 $2E $29 $3A $00 $3F $14 $29 $3A $14 $3E $3A $19 $25

underwaterPalette_Boss:                                                 ;$026B
;===============================================================================
; TODO: this should be provided by the mob, not the interrupts
; (i.e. it can be excluded if no underwater used)
        .TABLE  DSB 16
@tile:  .ROW    $10 $14 $14 $18 $35 $34 $2C $39 $21 $20 $1E $09 $04 $1E $10 $3F
@sprite:.ROW    $10 $20 $35 $2E $29 $3A $00 $3F $24 $3D $1F $17 $14 $3A $19 $00

init:                                                                   ;$028B
;===============================================================================
; clear the RAM and configure the system.
;
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        ; tell the SMS the cartridge has no RAM and to use ROM banking
        ld      A,      %10000000       ; write-protect on/off??
        ld      [SMS_MAPPER_CONTROL],   A
        ; load banks 0, 1 & 2 of the ROM into the address space ($0000-$BFFF
        ; of the address space will be mapped to $0000-$BFFF of this ROM)
        ld      A,                      0
        ld      [SMS_MAPPER_SLOT0],     A
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A

        ; empty the RAM!
        ld      HL,     RAM_FLOORLAYOUT ; starting from $C000,
        ld      DE,     RAM_FLOORLAYOUT+1 ; and copying one byte to the next,
        ld      BC,     $1FEF           ; copy 8'175 bytes ($C000-$DFEF),
        ld      [HL],   L               ; using a value of 0 ($00 from $C000)
        ldir                            ; -- faster to read a register than RAM

        ld      SP,     HL              ; place stack at the top of RAM ($DFEF)
                                        ; (`ldir` increased the HL register)

        ; initialize the VDP:
        ld      HL,     initVDPRegisterValues
        ld      DE,     RAM_VDPREGISTER_0
        ld      B,      11
        ld      C,      $8B

@loop:  ld      A,      [HL]            ; read the low-byte for the VDP
        ld      [DE],   A               ; copy to RAM
        inc     HL                      ; move to the next byte
        inc     DE
        ; send the VDP lo-byte
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      C               ; Load A with #$8B
        sub     B                       ; subtract B from A (B is decreasing),
                                        ; so A will count from #$80 to #8A
        ; send the VDP hi-byte
        out     [SMS_PORTS_VDP_CONTROL],        A
        djnz    @loop                   ; loop until B has reached 0

        ; move all sprites off the bottom of the screen!
        ; (set 64 bytes of VRAM from $3F00 to 224)
        ld      HL,     SMS_VRAM_SPRITES_YPOS
        ld      BC,     SMS_SPRITES
        ld      A,      SMS_VRAM_HEIGHT
        call    clearVRAM

        ; if the sound module is being included,
        ; mute any current sound (e.g. after soft-reset)
        .IFDEF  OPTION_SOUND
                call    call_muteSound
        .ENDIF

        ; IY is used as a shorthand to some common variables throughout,
        ; though this is in practice slower than just using an absolute address
        ; TODO: we could remove use of IY as the common variables address
        ;       entirely and perhaps use it for other things
        ld      IY,     RAM_VARS        ; variable space starts here
        jp      _1c49
        ;

call_playMusic:                                                         ;$02D7
;===============================================================================
; switch banks to the sound module and play the given song. the previous bank
; is restored afterwards. the `rst $18` instruction ends up here.
;
; in    A       index number of song to play
;-------------------------------------------------------------------------------
        di      ; disable interrupts
        push    AF

        ; switch slot 1 (Z80:$4000-$7FFF)
        ; to bank 3 (ROM:$C000-$FFFF)
        ld      A,                      :sound.playMusic
        ld      [SMS_MAPPER_SLOT1],     A

        pop     AF
        ld      [RAM_PREVIOUS_MUSIC],   A
        call    sound.playMusic

        ld      A,                      [RAM_SLOT1]
        ld      [SMS_MAPPER_SLOT1],     A

        ei      ; enable interrupts
        ret
        ;

call_muteSound:                                                         ;$02ED
;===============================================================================
; switch banks to the sound module and mute all sound. the previous bank is
; restored afterwards. the `rst $20` instruction ends up here.
;-------------------------------------------------------------------------------
        di      ; disable interrupts

        ; switch page 1 (Z80:$4000-$7FFF)
        ; to bank 3 (ROM:$0C000-$0FFFF)
        ld      A,                      :sound.stop
        ld      [SMS_MAPPER_SLOT1],     A
        call    sound.stop
        ld      A,                      [RAM_SLOT1]
        ld      [SMS_MAPPER_SLOT1],     A

        ei      ; enable interrupts
        ret
        ;

call_playSFX:                                                           ;$02FE
;===============================================================================
; switch banks to the sound module and play the given SFX. the previous bank
; is restored afterwards. the `rst $28` instruction ends up here.
;
; in    A      index number of SFX to play
;-------------------------------------------------------------------------------
        di
        push    AF

        ld      A,                      :sound.playSFX
        ld      [SMS_MAPPER_SLOT1],     A

        pop     AF
        call    sound.playSFX

        ld      A,                      [RAM_SLOT1]
        ld      [SMS_MAPPER_SLOT1],     A

        ei
        ret
        ;

initVDPRegisterValues:                                                  ;$031B
;===============================================================================
                                                                        ;cache:
        .BYTE   %00100110       ; VDP Reg#0:                            ;[$D218]
                ;......x.       ; stretch screen (33 columns)
                ;.....x..       ; unknown
                ;..x.....       ; hide left column (for scrolling)

        .BYTE   %10100010       ; VDP Reg#1: (original ROM)             ;[$D219]
                ;......x.       ; enable 8x16 sprites
                ;..x.....       ; enable vsync interrupt
                ;.x......       ; disable screen (no display)
                ;x.......       ; unknown                       ; these caches
                                                                ; are not used!
        .BYTE   %11111111       ; VDP Reg#2: screen at VRAM:$3800       ;[$D21A]
        .BYTE   %11111111       ; VDP Reg#3: unused                     ;[$D21B]
        .BYTE   %11111111       ; VDP Reg#4: unused                     ;[$D21C]
        .BYTE   %11111111       ; VDP Reg#5: sprites at VRAM:$3F00      ;[$D21D]
        .BYTE   %11111111       ; VDP Reg#6: sprite tiles in VRAM:$2000 ;[$D21E]
        .BYTE   %00000000       ; VDP Reg#7: border from sprite palette ;[$D21F]
        .BYTE   %00000000       ; VDP Reg#8: horizontal scroll offset   ;[$D220]
        .BYTE   %00000000       ; VDP Reg#9: vertical scroll offset     ;[$D221]
        .BYTE   %11111111       ; VDP Reg#10: disable line interrupts   ;[$D222]
        ;

waitForInterrupt:                                                       ;$031C
;===============================================================================
; a commonly used routine to essentially 'refresh the screen' by halting
; main execution until the interrupt handler has done its work.
;
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        ; test bit 0 of the IY parameter (IY=$D200)
        bit     0,      [IY+Vars.flags0]
        ; if bit 0 is off, then wait!
        jr      z,      waitForInterrupt

        ret
        ;

unused_0323:                                                            ;$0323
;===============================================================================
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        set     2,      [IY+Vars.flags0]
        ld      [RAM_UNUSED_D225], HL   ; unused RAM location!
        ld      [RAM_UNUSED_D227], DE   ; unused RAM location!
        ld      [RAM_UNUSED_D229], BC   ; unused RAM location!
        ret
        ;

loadPaletteOnInterrupt:                                                 ;$0333
;===============================================================================
; implementation can be found in the interrupt module
;
; in    IY      address of the common variables (used throughout)
;       A
;       HL
;-------------------------------------------------------------------------------
        ; set the flag for the interrupt handler
        set     3,      [IY+Vars.flags0]
        ;store the parameters
        ld      [RAM_LOADPALETTE_FLAGS],        A
        ld      [RAM_LOADPALETTE_ADDRESS],      HL
        ret
        ;

updateVDPSprites:                                                       ;$033E
;===============================================================================
; in    IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; sprite Y positions:

        ; set the VDP address to $3F00
        ; (Sprite Attribute Table, Y-positions)
        ld      A, <SMS_VRAM_SPRITES_YPOS
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A, >SMS_VRAM_SPRITES_YPOS
        ; add bit 6 to mark a VRAM address being given
        or      %01000000
        ; write the high-byte, with the 'address flag'
        out     [SMS_PORTS_VDP_CONTROL],        A

        ld      B,      [IY+Vars.spriteUpdateCount]
        ; Y-position of the first sprite
        ld      HL,     RAM_SPRITETABLE+1
        ld      DE,     3               ; sprite table is 3 bytes per sprite

        ld      A,      B
        and     A                       ; is sprite update count zero?
        jr      z,      @_1             ; if so, skip setting the Y-positions

        ; set sprite Y-positions:
        ; get the sprite's Y-position from RAM
@yLoop: ld      A,      [HL]            
        ; set the sprite's Y-position in the hardware
        out     [SMS_PORTS_VDP_DATA],   A
        add     HL,     DE              ; move to the next sprite
        djnz    @yLoop

        ; if the number of sprites to update is >= than the existing number of
        ; active sprites, skip ahead to setting the X-positions and indexes
@_1:    ld      A,      [RAM_ACTIVESPRITECOUNT]
        ld      B,      A
        ld      A,      [IY+Vars.spriteUpdateCount]
        ld      C,      A
        cp      B       ; test spriteUpdateCount - RAM_ACTIVESPRITECOUNT
        jr      nc,     @_2

        ; if the number of active sprites is greater than the sprite update
        ; count, that is - there will be active sprites remaining, calculate
        ; the amount remaining and make them inactive
        ld      A,      B
        sub     C
        ld      B,      A

        ; move remaining sprites off screen
@yOff:  ld      A,      SMS_VRAM_HEIGHT ; =224
        out     [SMS_PORTS_VDP_DATA],   A
        djnz    @yOff

        ; sprite X positions / indexes:
        ;-----------------------------------------------------------------------
@_2:    ld      A,      C
        and     A
        ret     z

        ld      HL,     RAM_SPRITETABLE ; first X-position in the sprite table
        ld      B,      [IY+Vars.spriteUpdateCount]

        ; set the VDP address to $3F80
        ; (sprite info table, X-positions & indexes)
        ld      A,      <SMS_VRAM_SPRITES_XPOS
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,      >SMS_VRAM_SPRITES_XPOS
        or      %01000000               ; add bit 6 to mark an address is given
        out     [SMS_PORTS_VDP_CONTROL],A

@xLoop: ld      A,      [HL]            ; set the sprite X-position
        out     [SMS_PORTS_VDP_DATA],   A
        inc     L                       ; skip Y-position
        inc     L
        ; set the sprite index number
        ld      A,                      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     L
        djnz    @xLoop

        ; set the new number of active sprites
        ld      A,      [IY+Vars.spriteUpdateCount]
        ld      [RAM_ACTIVESPRITECOUNT],        A
        ; set the update count to 0
        ld      [IY+Vars.spriteUpdateCount],    B
        ret
        ;

unused_0397:                                                            ;$0397
;===============================================================================
; fill VRAM from memory?
;
; in    BC      number of bytes to copy
;       DE      VDP address
;       HL      memory location to copy from
;-------------------------------------------------------------------------------
        di
        ld      A,      E
        out     [SMS_PORTS_VDP_CONTROL], A
        ld      A,      D
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL], A
        ei

@loop:  ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL

        dec     BC
        ld      A,      B
        or      C
        jp      nz,     @loop

        ret
        ;

unused_03ac:                                                            ;$03AC
;===============================================================================
; in    A       page 1 bank number, A+1 will be used as page 2 bank number
;       DE      VDP address
;       HL      ?
;-------------------------------------------------------------------------------
        di
        push    AF

        ; set the VDP address using DE
        ld      A,      E
        out     [SMS_PORTS_VDP_CONTROL], A
        ld      A,      D
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL], A

        pop     AF
        ld      DE,     [RAM_SLOT1]
        push    DE

        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        inc     A
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A
        ei

@_1:    ld      A,      [HL]
        cpl
        ld      E,      A

@_2:    ld      A,      [HL]
        cp      E
        jr      z,      @_3
        out     [SMS_PORTS_VDP_DATA],   A
        ld      E,      A
        inc     HL
        dec     BC
        ld      A,      B
        or      C
        jp      nz,     @_2
        jr      @_5

@_3:    ld      D,      A
        inc     HL
        dec     BC
        ld      A,      B
        or      C
        jr      z,      @_5
        ld      A,      D
        ld      E,      [HL]

@_4:    out     [SMS_PORTS_VDP_DATA],   A
        dec     E
        nop
        nop
        jp      nz,     @_4
        inc     HL
        dec     BC
        ld      A,      B
        or      C
        jp      nz,     @_1

        ; disable interrupts so that stuff does not get
        ; changed mid-way through restoring the pages
@_5:    di

        ; restore bank numbers
        pop     DE
        ld      [RAM_SLOT1],    DE      ; restore our copy of the bank numbers
        ld      A,              E       ; restore Slot 1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      A,              D       ; restore Slot 2
        ld      [SMS_MAPPER_SLOT2],     A

        ; enable interrupts and return
        ei
        ret
        ;

decompressArt:                                                          ;$0405
;===============================================================================
; in    A       bank number for the relative address HL
;       HL      relative address from beginning of bank (A) to the art data
;       D       VDP register number to set
;       E       VDP data value to send to VDP register in D
;       IY      address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        di                              ; disable interrupts

@calculateBank:
        ; determine bank number:
        ;-----------------------------------------------------------------------
        push    AF                      ; put aside the current bank number

        ; TODO: we won't need to do this address fixing here as long as all
        ;       calls to `decompressArt` are correct

        ; is the HL parameter address below the $40xx range?
        ; -- that is, does the relative address extend into the second page?
        ld      A,      H
        cp      >$4000
        jr      c,      @_2

        ; remove $40xx (e.g. so $562B becomes $162B)
        sub     >$4000
        ld      H,      A

        ; restore the A parameter (the starting bank number) and increase it so
        ; that HL now represents a relative address from the next bank up. this
        ; would mean that instead of paging in, for example, banks 9 & 10,
        ; we would get 10 & 11
        pop     AF
        inc     A
        jp      @calculateBank

        ; configure the VDP:
        ;-----------------------------------------------------------------------

@_2:    ; VDP value byte from the E parameter
        ld      A,      E
        ; send to the VDP
        out     [SMS_PORTS_VDP_CONTROL],A

        ld      A,      D
        or      %01000000               ; add bit 7 (that is, convert A to
        ; send it to the VDP            ; a VDP control register number)
        out     [SMS_PORTS_VDP_CONTROL],A

        ; switch banks:
        ;-----------------------------------------------------------------------
        pop     AF                      ; restore the A parameter

        ; add $4000 to the HL parameter to
        ; re-base it for page 1 (Z80:$4000-$7FFF)
        ld      DE,     SMS_SLOT1       ;=$4000
        add     HL,     DE

        ; stash the current page 1/2 bank numbers cached in RAM
        ld      DE,     [RAM_SLOT1]
        push    DE

        ; change pages 1 & 2 (Z80:$4000-$BFFF)
        ; to banks A & A+1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        inc     A
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ; read art header:
        ;-----------------------------------------------------------------------

        bit     1,      [IY + Vars.flags9]
        jr      nz,     @_3
        ei

@_3:    ld      [RAM_TEMP4],    HL

        ; begin reading the compressed art header:
        ; see <info.sonicretro.org/SCHG:Sonic_the_Hedgehog_(8-bit)#Header>
        ; for details on the format

        ; skip the "48 59" art header marker
        ; TODO: this can be removed from the data
        inc     HL
        inc     HL

        ; read the DuplicateRows value into DE and save for later
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        push    DE

        ; read the ArtData value into DE and save for later
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        push    DE

        ; read the row count (#$0400 for sprites, #$0800 for tiles) into BC
        inc     HL
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL

        ld      [RAM_TEMP3],    BC      ; store the row count in $D210
        ld      [RAM_TEMP6],    HL      ; where the UniqueRows list begins

        ; swap BC/DE/HL with their shadow values
        exx

        ; load BC' with the absolute starting address of the art header;
        ; the DuplicateRows and ArtData values are always relative to this
        ld      BC',    [RAM_TEMP4]
        ; copy it to DE
        ld      E',     C'
        ld      D',     B'

        pop     HL'                     ; pull the ArtData value from the stack
        add     HL',    BC'             ; get the absolute address of ArtData
        ld      [RAM_TEMP1],    HL'     ; and store that in $D20E
        ; copy it to BC.
        ; this will be used to produce a counter from 0 to RowCount
        ld      C',     L'
        ld      B',     H'

        pop     HL'                     ; load HL with the DuplicateRows value
        add     HL',    DE'             ; get DuplicateRows absolute address

        ; swap DE & HL. DE will now be the DuplicateRows absolute address,
        ; and HL will be the absolute address of the art header
        ex      DE',    HL'

        ; now swap the original values back,
        ; BC will be the row counter
        ; DE will be the ArtData value
        exx

        ; process row:
        ;-----------------------------------------------------------------------
@processRow:
        ld      HL,     [RAM_TEMP3]     ; load HL with original row count
                                        ; ($0400 for sprites, $0800 for tiles)
        xor     A                       ; set A to 0 (Carry is reset)
        sbc     HL,     BC              ; subtract counter from row count
                                        ; (that is, count upwards from 0)
        push    HL                      ; save the counter value

        ; get the row number in the current tile (0-7):
        ld      D,      A               ; zero-out D
        ld      A,      L               ; load A with the lo-byte of the counter
        and     %00000111               ; clip to the first three bits (that is,
                                        ; "mod 8" it so it counts 0-7)
        ld      E,      A               ; load E with this value, making it
                                        ; a 16-bit number in DE
        ld      HL,     @rowIndexTable
        add     HL,     DE              ; add the row number to $04F9
        ld      A,      [HL]            ; get bit mask for the particular row

        pop     DE                      ; fetch our counter back

        ;divide the counter by 4
        srl     D
        rr      E
        srl     D
        rr      E
        srl     D
        rr      E

        ld      HL,     [RAM_TEMP6]     ; the absolute address where the
                                        ; UniqueRows list begins
        add     HL,     DE              ; add the counter, so move along to the
                                        ; DE'th byte in the UniqueRows list
        ld      E,      A
        ld      A,      [HL]            ; read current byte in UniqueRows list
        and     E                       ; test if the masked bit is set
        jr      nz,     @duplicateRow   ; if bit is set, it's a duplicate row,
                                        ; otherwise continue for a unique row

        ; unique row:
        ;-----------------------------------------------------------------------

        ; swap back the BC/DE/HL shadow values:
        ; BC will be the absolute address to the ArtData
        ; DE will be the DuplicateRows absolute address
        ; HL will be the absolute address of the art header
        exx

        ; write 1 row of pixels (4 bytes) to the VDP
        ld      A,      [BC']
        out     [SMS_PORTS_VDP_DATA],   A
        inc     BC'
        nop
        nop
        ld      A,      [BC']
        out     [SMS_PORTS_VDP_DATA],   A
        inc     BC'
        nop
        nop
        ld      A,      [BC']
        out     [SMS_PORTS_VDP_DATA],   A
        inc     BC'
        nop
        nop
        ld      A,      [BC']
        out     [SMS_PORTS_VDP_DATA],   A
        inc     BC'

        ; swap BC/DE/HL back again
        ; HL is the current byte in the UniqueRows list
        exx

        dec     BC                      ; decrease the length counter
        ld      A,      B               ; combine the high byte,
        or      C                       ; with the low byte...
        jp      nz,     @processRow     ; loop back if not zero
        jp      @_5                     ; otherwise, skip to finalisation

@duplicateRow:
        ; duplicate row:
        ;-----------------------------------------------------------------------

        ; swap in the BC/DE/HL shadow values:
        ; BC will be the absolute address to the ArtData
        ; DE will be the DuplicateRows absolute address
        ; HL will be the absolute address of the art header
        exx

        ld      A,      [DE']           ; read a byte from duplicate rows list
        inc     DE'                     ; move to the next byte

        ; swap back the original BC/DE/HL values
        exx

        ; HL will be re-purposed as the index into the art data
        ld      H,      $00
        ; check if the byte from the duplicate rows list begins with $F,
        ; i.e. $Fxxx. this is used as a marker to specify a two-byte number
        ; for indices over 256
        cp      $F0
        jr      c,      @_4             ; if less than $F0, skip next byte
        sub     $F0                     ; strip the $F0, i.e $F3 = $03
        ld      H,      A               ; set hi-byte for the art data index

        exx                             ; switch DE to DuplicateRows address
        ld      A,      [DE']           ; fetch the next byte
        inc     DE'                     ; and move forward in the list
        exx                             ; return BC/DE/HL to before

        ; multiply the duplicate row's index number to the art data by 4
        ; --each row of art data is 4 bytes
@_4:    ld      L,      A
        add     HL,     HL
        add     HL,     HL

        ld      DE,     [RAM_TEMP1]     ; get absolute address to the art data
        add     HL,     DE              ; add the index from duplicate row list

        ; write 1 row of pixels (4 bytes) to the VDP
        ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL
        nop
        nop
        ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL
        nop
        nop
        ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL
        nop
        nop
        ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL

        ; decrease the remaining row count
        dec     BC

        ; check if all rows have been done
        ld      A,      B
        or      C
        jp      nz,     @processRow

@_5:    bit     1,      [IY+Vars.flags9]
        jr      nz,     @_6
        di
@_6:    ; restore the pages to the original banks
        ; at the beginning of the procedure
        pop     DE
        ld      [RAM_SLOT1],            DE
        ld      [SMS_MAPPER_SLOT1],     DE

        ei
        res     1,      [IY+Vars.flags9]
        ret

@rowIndexTable:
        .BYTE   %00000001
        .BYTE   %00000010
        .BYTE   %00000100
        .BYTE   %00001000
        .BYTE   %00010000
        .BYTE   %00100000
        .BYTE   %01000000
        .BYTE   %10000000
        ;

decompressScreen:                                                       ;$0501
;===============================================================================
; a screen layout is compressed using RLE (run-length-encoding). any byte that
; there are multiple of in a row are listed as two repeating bytes, followed
; by another byte specifying the remaining number of times to repeat
;
; in    BC      length of the compressed data
;       DE      VDP register number (D) and value byte (E) to send to the VDP
;       HL      absolute address to the start of the compressed screen data
;-------------------------------------------------------------------------------
        di      ; disable interrupts

        ; configure the VDP based on the DE parameter
        ld      A,      E
        out     [SMS_PORTS_VDP_CONTROL], A

        ; add bit 7 (that is, convert A to a VDP control register number)
        ld      A,      D
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL], A

        ei      ; enable interrupts

@_1:    ; the current byte is stored in E to be able to check when two bytes
        ; in a row occur (the marker for a compressed byte). it's actually
        ; stored inverted so that the first data byte doesn't trigger an
        ; immediate repeat

        ld      A,      [HL]            ; read current byte from screen data
        cpl                             ; invert the bits ("NOT")
        ld      E,      A               ; move this to E

@_2:    ld      A,      [HL]            ; read current byte from screen data
        cp      E                       ; is this equal to the previous byte?
        jr      z,      @_3             ; if yes, decompress the byte

        cp      $FF                     ; is this tile $FF?
        jr      z,      @skip

        ; uncompressed byte:
        ;-----------------------------------------------------------------------
        out     [SMS_PORTS_VDP_DATA], A ; send the tile to the VDP
        ld      E,      A               ; update current byte being compared
        ld      A,      [RAM_TEMP1]     ; get the upper byte for the tiles
                                        ; (foreground / background / flip)
        out     [SMS_PORTS_VDP_DATA], A

        inc     HL                      ; move to the next byte
        dec     BC                      ; decrease the remaining bytes to read
        ld      A,      B               ; check if remaining bytes is zero
        or      C
        jp      nz,     @_2             ; if remaining bytes, loop
        jr      @_6                     ; otherwise end

        ; decompress byte:
        ;-----------------------------------------------------------------------
@_3:    ld      D,      A               ; put the current data byte into D
        inc     HL                      ; move to the next byte
        dec     BC                      ; decrease the remaining bytes to read
        ld      A,      B               ; check if remaining bytes is zero
        or      c
        jr      z,      @_6             ; if no bytes left, finish
                                        ; (couldn't I just put `ret z` here?)

        ld      A,      D               ; return the data byte back to A
        ld      E,      [HL]            ; get number of times to repeat the byte
        cp      $FF                     ; is a skip being repeated?
        jr      z,      @multiSkip

        ; repeat the byte
@_4:    out     [SMS_PORTS_VDP_DATA],   A
        push    AF
        ld      A,      [RAM_TEMP1]
        out     [SMS_PORTS_VDP_DATA],   A
        pop     AF
        dec     E
        jp      nz,     @_4

@_5:    ; move to the next byte in the data
        inc     HL
        dec     BC

        ; any remaining bytes?
        ld      A,      B
        or      C
        jp      nz,     @_1             ; start checking duplicate bytes again

        ; all bytes processed - we're done!
@_6:    ret

@skip:
        ;-----------------------------------------------------------------------
        ld      E,      A
        in      A,      [SMS_PORTS_VDP_DATA]
        nop
        inc     HL
        dec     BC
        in      A,      [SMS_PORTS_VDP_DATA]

        ld      A,      B
        or      C
        jp      nz,     @_2

        ei
        ret

@multiSkip:
        ;-----------------------------------------------------------------------
        in      A,      [SMS_PORTS_VDP_DATA]
        push    AF
        pop     AF
        in      A,      [SMS_PORTS_VDP_DATA]
        nop
        dec     E
        jp      nz,     @multiSkip
        jp      @_5
        ;

loadPalette:                                                            ;$0566
;===============================================================================
; in    A       which palette(s) to set
;               bit 0 - tile palette (0-15)
;               bit 1 - sprite palette (16-31)
;       HL      address of palette
;
; out   LOADPALETTE_TILE
;       LOADPALETTE_SPRITE
;-------------------------------------------------------------------------------
        push    AF

        ld      B,      16              ; we will copy 16 colours
        ld      C,      0               ; beginning at palette index 0 (tiles)

        bit     0,      A               ; are we loading a tile palette?
        jr      z,      @_1             ; if no, skip ahead to sprite palette

        ld      [RAM_LOADPALETTE_TILE], HL
        call    @sendPalette            ; send the palette colours to the VDP

@_1:    pop     AF

        bit     1,      A               ; are we loading a sprite palette?
        ret     z                       ; if no, finish here

        ; store the address of the sprite palette
        ld      [RAM_LOADPALETTE_SPRITE],       HL

        ld      B,      16              ; we will copy 16 colours
        ld      C,      16              ; beginning at index 16 (sprites)

        bit     0,      A               ; if loading both tile & sprite palette
        jr      nz,     @sendPalette    ; then stick with what we've set

        ; if loading sprite palette only, then ignore the first colour
        ; (I believe this has to do with the screen background colour
        ; being set from the sprite palette?)
        inc     HL
        ld      B,      15              ; copy 15 colours
        ld      C,      17              ; to indexes 17-31, that is, skip no.16

@sendPalette:
        ld      A,      C               ; send palette index number to begin at
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,      %11000000       ; specify palette operation (bits 7 & 6)
        out     [SMS_PORTS_VDP_CONTROL],A

        ; TODO: this can be unrolled into `outi` to go faster
        ld      C,      $BE             ; send the colours to the palette
        otir
        ret
        ;

clearVRAM:                                                              ;$0595
;===============================================================================
; utility routine to wipe the Master System's Video RAM with the provided value.
; called only by `init`
;
; in    HL      VRAM address
;       BC      length
;       A       value
;-------------------------------------------------------------------------------
        ld      E,      A               ; temporarily shift the value to E
        ld      A,      L
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,      H
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL],A

@loop:  ld      A,      E               ; return the value to A
        out     [SMS_PORTS_VDP_DATA],   A ; send it to the VDP

        dec     BC
        ld      A, B
        or      C
        jr      nz,     @loop
        ret
        ;

readJoypad:                                                             ;$05A7
;===============================================================================
; in    IY      Address of the common variables (used throughout)
; out   Vars.joypad
;-------------------------------------------------------------------------------

        in      A, [sms.ports.joy_a]    ; read the joypad port
        or      %11000000               ; mask out bits 7 & 6 -
                                        ; these are joypad 2 down / up
        ld      [IY+Vars.joypad], A     ; store the joypad value in $D203
        ret
        ;

print:                                                                  ;$05AF
;===============================================================================
; in    HL      Address to memory with column & row numbers,
;               then text data terminated with $FF
;-------------------------------------------------------------------------------
        ; get the column number
        ld      C,      [HL]
        inc     HL

        ; the screen layout on the Master System is a 32x28 table of 16-bit
        ; values (64 bytes per row). we therefore need to multiply the row
        ; number by 64 to get the right offset into the screen layout data
        ld      A,      [HL]            ; read the row number
        inc     HL

        ; we multiply by 64 by first multiplying by 256 -- very simple, we just
        ; make the value the hi-byte in a 16-bit word, e.g. "$0C00" -- and then
        ; divide by 4 by rotating the bits to the right
        rrca                            ; divide by two (equal to multiply 128)
        rrca                            ; and again (equal to multiply by 64)

        ld      E,      A
        and     %00111111               ; strip off the rotated bits
        ld      D,      A

        ld      A,      E
        and     %11000000
        ld      E,      A

        ld      B,      $00
        ex      DE,     HL
        sla     C                       ; multiply column by 2 (16-bit values)
        add     HL,     BC
        ld      BC,     SMS_VRAM_SCREEN
        add     HL,     BC

        ; set the VDP to point to the screen address calculated
        di
        ld      A,      L
        out     [SMS_PORTS_VDP_CONTROL], A
        ld      A,      H
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL], A
        ei

        ; read bytes from memory until hitting $FF
@loop:  ld      A,      [DE]
        cp      $FF
        ret     z

        out     [SMS_PORTS_VDP_DATA],   A
        push    AF                      ; kill time?
        pop     AF
        ld      A,      [RAM_TEMP1]     ; what to use as the tile upper bits
                                        ; (front/back, flip &c.)
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE
        djnz    @loop

        ret
        ;

hideSprites:                                                            ;$05E2
;===============================================================================
; Moves all hardware sprites off-screen.
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        ; get the address of the game's main sprite table
        ld      HL,     RAM_SPRITETABLE
        ld      E,      L               ; copy to DE
        ld      D,      H
        ld      BC,     189             ; size of SPRITETABLE - 3?
        ; set the first two bytes as 224 (X&Y position)
        ld      A,      224
        ld      [DE],   A
        inc     DE
        ld      [DE],   A
        ; then move forward another two bytes (skips the sprite index number)
        inc     DE
        inc     DE
        ; copy 189 bytes from $D000 to $D003+ (up to $D0C0)
        ldir

        ;set parameters so that at the next interrupt,
        ;all sprites will be hidden (see `updateVDPSprites`)

        ;mark all 64 hardware sprites as requiring update
        ld      [IY+Vars.spriteUpdateCount],       64
        ;and set zero active sprites
        xor     A                                          ;(set A to 0)
        ld      [RAM_ACTIVESPRITECOUNT],        A

        ret
        ;

multiply:                                                               ;$05FC
;===============================================================================
; multiplies input HL by C
;
; in    HL      the starting value
;       C       the number to multiply by (i.e. HL * C)
;
; out   HL      the value after multiplication
;       DE      is clobbered with the starting value
;       A       set to 0
;       B       set to 0 due to countdown loop
;       C       the last bit of input C, 0 or 1
;-------------------------------------------------------------------------------

        xor     A                       ; set A to 0
        ld      B,      7               ; we will process all 8-bits of C
        ex      DE,     HL              ; transfer the HL parameter to DE
        ld      L,      A               ; set HL as $0000
        ld      H,      A

@loop:  rl      C                       ; shift the bits in C up one
        jp      nc,     @_1             ; skip if it hasn't overflowed yet
        add     HL,     DE              ; add the parameter value to the total
@_1:    add     HL,     HL              ; double the current total
        djnz    @loop

        ; is there any carry remaining?
        or      C                       ; check if C is 0
        ret     z                       ; if so, no carry the number is final
        add     HL,     DE              ; otherwise add one more
        ret
        ;

_LABEL_60F_111:                                                         ;$060F
;===============================================================================
; convert to decimal? (used by Map & Act Complete screens for the lives number)
;
; in    C               ; always 10 - base?
;       HL              ; always number of lives
;       DE              ; e.g. 60 ($3C)
;
; out   DE
;       HL
;-------------------------------------------------------------------------------

        xor     A                       ; set A to 0
        ld      B,   16                 ; process 16 bits

        ; multiply HL by 2, using a 24-bit result
@loop:  rl      L                       ; carry is held
        rl      H                       ; shift carry into H, hold next carry
        rla                             ; if above carries, carry into A

        ;D:00000000 E:00111100 C:0A A:00000000 H:00000000 L:01001100 B:16
        ;D:00000000 E:01111000 C:0A A:00000000 H:00000000 L:10011000 B:15
        ;D:00000000 E:11110000 C:0A A:00000000 H:00000001 L:00110000 B:14
        ;D:00000001 E:11100000 C:0A A:00000000 H:00000010 L:01100000 B:13
        ;D:00000011 E:11000000 C:0A A:00000000 H:00000100 L:11000000 B:12
        ;D:00000111 E:10000000 C:0A A:00000000 H:00001001 L:10000000 B:11
        ;D:00001111 E:00000000 C:0A A:00000000 H:00010011 L:00000000 B:10
        ;D:00011110 E:00000000 C:0A A:00000000 H:00100110 L:00000000 B:09
        ;D:00111100 E:00000000 C:0A A:00000000 H:01001100 L:00000000 B:08
        ;D:01111000 E:00000000 C:0A A:00000000 H:10011000 L:00000000 B:07
        ;D:11110000 E:00000000 C:0A A:00000001 H:00110000 L:00000000 B:06
        ;D:11100000 E:00000000 C:0A A:00000010 H:01100000 L:00000000 B:05
        ;D:11000000 E:00000000 C:0A A:00000100 H:11000000 L:00000000 B:04
        ;D:10000000 E:00000000 C:0A A:00001001 H:10000000 L:00000000 B:03
        ;D:00000000 E:00000000 C:0A A:00010011 H:00000000 L:00000000 B:02
        ;
        ;D:00000000 E:00000000 C:0A A:00001001 H:00000000 L:00000000 B:02
        ;
        ;D:00000000 E:00111100 C:0A A:00100110 H:00000000 L:00000000 B:01
        ;D:00000000 E:00111100 C:0A A:01001100 H:00000000 L:00000000 B:00
        ;D:00000000 E:01111000 C:0A A:00000010 H:00000000 L:00000000 B:00

        ; are the upper-most bits (A)
        ; still less than the parameter value?
        cp      C
        jp      c,      @_1             ; if less than 10, skip ahead
        sub     C                       ; -10

@_1:    ; multiply DE by 2
        ccf                             ; don't include the carry from previous
        rl      E
        rl      D

        ; move on to the next bit
        djnz    @loop

        ; swap DE and HL:
        ; HL will be the number of 10s (in two's compliment?)
        ex      DE,     HL
        ret
        ;

_0625:                                                                  ;$0625
;===============================================================================
; random number generator?
;-------------------------------------------------------------------------------
        push    HL
        push    DE

        ld      HL,     [RAM_D2D7]
        ld      E,      L
        ld      D,      H
        add     HL,     DE              ;x2
        add     HL,     DE              ;x4

        ld      A,      L
        add     A,      H
        ld      H,      A
        add     A,      L
        ld      L,      A

        ld      DE,     $0054
        add     HL,     DE
        ld      [RAM_D2D7],     HL
        ld      A,      H

        pop     DE
        pop     HL
        ret
        ;

updateVDPscroll:                                                        ;$063E
;===============================================================================
; called only by `_LABEL_1CED_131`
;
; Checks if the camera has moved and updates the VDP scroll register cache
; accordingly (this is then written to the VDP during the interrupt routine).
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        ; fill B with vertical and C with horizontal VDP scroll values
        ld      BC,     [RAM_VDPSCROLL_HORZ]

        ; has the camera moved horizontally?
        ;-----------------------------------------------------------------------
        ld      HL,     [RAM_CAMERA_X]
        ld      DE,     [RAM_CAMERA_X_PREV]
        and     A                       ; clear carry flag
        sbc     HL,     DE              ; `RAM_CAMERA_X_LEFT` > `RAM_CAMERA_X`?
        jr      c,      @_1             ; jump if the camera has moved left

        ; HL will contain the amount the screen has
        ; scrolled since the last time this function was called

        ; camera moved right:
        ld      A,      L
        add     A,      C
        ld      C,      A
        res     6,      [IY+Vars.flags0]
        jp      @_2

        ; camera moved left:
@_1:    ld      A,      L
        add     A,      C
        ld      C,      A
        set     6,      [IY+Vars.flags0]

        ; has the camera moved vertically?
        ;-----------------------------------------------------------------------
@_2:    ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     [RAM_CAMERA_Y_PREV]
        and     A                       ; clear carry flag
        sbc     HL,     DE              ; `RAM_CAMERA_Y_UP` > `RAM_CAMERA_Y`?
        jr      c,      @_4             ; jump if the camera has moved up

        ; camera moved down:
        ld      A,      L
        add     A,      B
        cp      SMS_VRAM_HEIGHT         ; if > 224 (bottom of the VRAM)
        jr      c,      @_3

        ; add 32 to wrap 224 around 256 back to 0+
        add     A,      256-SMS_VRAM_HEIGHT

@_3:    ld      B,      A
        res     7,      [IY+Vars.flags0]
        jp      @_6

        ; camera moved up:
@_4:    ld      A,      L
        add     A,      B
        cp      SMS_VRAM_HEIGHT         ; if > 224 (bottom of the VRAM)
        jr      c,      @_5

        ; subtract 32 to wrap 0 around 256 back to 224
        sub     256-SMS_VRAM_HEIGHT

@_5:    ld      B,      A
        set     7,      [IY+Vars.flags0]

        ;-----------------------------------------------------------------------

        ; update the VDP horizontal / vertical scroll values in the RAM,
        ; the interrupt routine will send the values to the chip
@_6:    ld      [RAM_VDPSCROLL_HORZ],   BC

        ; get the number of blocks across / down the camera is located:
        ; we multiply the camera position by 8 and take only the high byte
        ; (effectively dividing by 256) so that everything below 32 pixels
        ; of precision is lost

        ld      HL,     [RAM_CAMERA_X]
        sla     L       ; x2 ...
        rl      H
        sla     L       ; x4 ...
        rl      H
        sla     L       ; x8
        rl      H
        ld      C,      H               ; take the high byte

        ld      HL,     [RAM_CAMERA_Y]
        sla     L       ; x2 ...
        rl      H
        sla     L       ; x4 ...
        rl      H
        sla     L       ; x8
        rl      H
        ld      B,      H               ; take the high byte

        ; now store the block X & Y counts
        ld      [RAM_BLOCK_X],  BC

        ; update the left / up values now that the camera has moved
        ld      HL,                     [RAM_CAMERA_X]
        ld      [RAM_CAMERA_X_PREV],    HL
        ld      HL,                     [RAM_CAMERA_Y]
        ld      [RAM_CAMERA_Y_PREV],    HL

        ret
        ;

fillOverscrollCache:                                                    ;$06BD
;===============================================================================
; This fills the overscroll cache so that when the screen scrolls onto new
; tiles they can be copied across in a fast and straight-forward fashion.
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; scrolling enabled??
        ; TODO: this could be located at the call site (macro?)
        ; to avoid the wasted `call`+`ret`
        bit     5,      [IY+Vars.flags0]
        ret     z

        ; interrupts are disabled so that tiles do not
        ; get written to the screen between updating them
        di
        ; switch pages 1 & 2 ($4000-$BFFF)
        ; to banks 4 & 5 ($10000-$17FFF)
        ld      A,                      :blockMappings
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      :blockMappings+1
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A
        ei

        ;-----------------------------------------------------------------------
        ; get the address of the solidity data for the level's tilemap:
        ; TODO: we should just store the solidity data adress in the level
        ;       header, instead of an index

        ; get the solidity index for the level
        ld      A,      [RAM_LEVEL_SOLIDITY]
        add     A,      A               ; double it (for a pointer)
        ld      C,      A               ; and put it into a 16-bit number (BC)
        ld      B,      $00

        ; look up the index in the solidity pointer table
        ld      HL,     solidityBlocks
        add     HL,     BC

        ; load an address at the table
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A

        ; store the solidity data address in RAM
        ld      [RAM_TEMP3],    HL

        ;-----------------------------------------------------------------------
        ; horizontal scrolling allowed??
        bit     0,      [IY+Vars.flags2]
        jp      z,      @vert           ; skip to vertical scroll handling

        ; has the camera moved left?
        bit     6,      [IY+Vars.flags0]
        jr      nz,     @horz

        ld      B,      $00
        ld      C,      $08
        jp      @_1

        ; get the position in the floor layout (in RAM) of the camera:

@horz:  ld      A,      [RAM_VDPSCROLL_HORZ]
        and     %00011111               ; MOD 32 (i.e. 0-31 looping)
        add     A,      8               ; add 8 (ergo, 8-39)
        rrca                            ; divide by 2 ...
        rrca                            ; ... 4
        rrca                            ; ... 8
        rrca                            ; ... 16
        rrca                            ; ... 32
        and     %00000001               ; remove everything but bit 0
        ld      B,      $00             ; load result into BC
                                        ; -- either $0000 or $0001
        ld      C,      A

@_1:    call    getFloorLayoutRAMPosition

        ;-----------------------------------------------------------------------
        ld      A,      [RAM_VDPSCROLL_HORZ]

        ; has the camera moved left?
        bit     6,      [IY+Vars.flags0]
        jr      z,      @_2
        add     A,      8

        ; which of the four tiles width in a block is on the left-hand side of
        ; the screen -- that is, determine which column within a block the
        ; camera is on
@_2:    and     %00011111               ;MOD 32 (limit to pixels within block)
        srl     A                       ; divide by 2 ...
        srl     A                       ; divide by 4 ...
        srl     A                       ; divide by 8 (determine tile, 0-3)
        ld      C,      A               ; copy the tile number (0-3) into BC
        ld      B,      $00
        ld      [RAM_TEMP1],    BC      ; stash it away for later

        exx
        ld      DE',    RAM_OVERSCROLLCACHE_HORZ
        exx
        ld      DE,     [RAM_LEVEL_FLOORWIDTH]

        ld      B,      7
@loopH: ld      A,      [HL]            ; read block index from the FloorLayout

        exx
        ld      C',     A
        ld      B',     $00
        ld      HL',    [RAM_TEMP3]     ; retrieve the solidity data address
        add     HL',    BC'             ; offset block index into solidity data

        ; multiply the block index by 16
        ; (blocks are each 16 bytes long)
        rlca    ; x2 ...
        rlca    ; x4 ...
        rlca    ; x8 ...
        rlca    ; x16
        ld      C',     A
        and     %00001111               ; MOD 16
        ld      B',     A
        ld      A,      C'              ; return to the block index * 16 value
        xor     B'
        ld      C',     A

        ld      A,      [HL']           ; read solidity data for block index
        rrca
        rrca
        rrca
        and     %00010000

        ld      HL',    [RAM_TEMP1]     ; retrieve column number of VDP scroll
        add     HL',    BC'
        ld      BC',    [RAM_BLOCKMAPPINGS]
        add     HL',    BC'
        ld      BC',    4
        ldi                             ; copy the first byte

        ld      [DE'],  A
        inc     E'
        add     HL',    BC'
        ldi

        ld      [DE'],  A
        inc     E'
        inc     C'
        add     HL',    BC'
        ldi

        ld      [DE'],  A
        inc     E
        inc     C'
        add     HL',    BC'
        ldi

        ld      [DE'],  A
        inc     E'

        exx
        add     HL,     DE
        djnz    @loopH

        ;-----------------------------------------------------------------------

@vert:  bit     1,      [IY+Vars.flags2]
        jp      z,      @exit

        bit     7,      [IY+Vars.flags0]        ; camera moved up?
        jr      nz,     @_3

        ld      B,      $06
        ld      C,      $00
        jp      @_4

@_3:    ld      B,      $00
        ld      C,      B

        ;-----------------------------------------------------------------------

@_4:    call    getFloorLayoutRAMPosition
        ld      A,      [RAM_VDPSCROLL_VERT]
        and     %00011111
        srl     A
        and     %11111100
        ld      C,      A
        ld      B,      $00
        ld      [RAM_TEMP1],    BC

        exx
        ld      DE',    RAM_OVERSCROLLCACHE_VERT
        exx

        ld      B,      $09

@loopV: ld      A,      [HL]

        exx
        ld      C',     A
        ld      B',     $00
        ld      HL',    [RAM_TEMP3]
        add     HL',    BC'
        rlca
        rlca
        rlca
        rlca
        ld      C',     A
        and     %00001111
        ld      B',     A
        ld      A,      C'
        xor     B'
        ld      C',     A
        ld      A,      [HL']
        rrca
        rrca
        rrca
        and     %00010000
        ld      HL',    [RAM_TEMP1]
        add     HL',    BC'
        ld      BC',    [RAM_BLOCKMAPPINGS]
        add     HL',    BC'
        ldi
        ld      [DE'],  A
        inc     E'
        ldi
        ld      [DE'],  A
        inc     E'
        ldi
        ld      [DE'],  A
        inc     E'
        ldi
        ld      [DE'],  A
        inc     E'
        exx

        inc     HL
        djnz    @loopV

@exit:  ret
        ;


fillScrollTiles:                                                        ;$07DB
;===============================================================================
; Fills in new tiles when the screen has scrolled.
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        bit     0,      [IY+Vars.flags2]
        jp      z,      @_4

        exx
        push    HL'
        push    DE'
        push    BC'

        ;-----------------------------------------------------------------------
        ; calculate the number of bytes to offset by to get to the correct row
        ; in the screen table
        ; TODO: a look-up table for this might be faster

        ld      A,   [RAM_VDPSCROLL_VERT]
        and     %11111000               ; round scroll to the nearest 8 pixels

        ; multiply the vertical scroll offset by 8. since the scroll offset is
        ; already a multiple of 8; this will give you 64 bytes per screen row
        ; (32 x 16-bit tiles)
        ld      B',     $00
        add     A,      A               ;x2
        rl      B'
        add     A,      A               ;x4
        rl      B'
        add     A,      A               ;x8
        rl      B'
        ld      C',     A

        ;-----------------------------------------------------------------------
        ; calculate the number of bytes to get from the beginning of a row to
        ; the horizontal scroll position

        ld      A,      [RAM_VDPSCROLL_HORZ]

        ; camera moved left?
        bit     6,      [IY+Vars.flags0]
        jr      z,      @_1

        add     A,      8               ; add 8 pixels (left screen border?)

@_1:    and     %11111000               ; round to the nearest 8 pixels (a tile)

        srl     A                       ; divide by 2 ...
        srl     A                       ; divide by 4
        add     A,      C'              ; add it to earlier rows calculation
        ld      C',     A

        ; BC will now hold the number of bytes needed to get from the beginning
        ; of the scren name table in VRAM to the top-left corner of the visible
        ; portion (the screen)

        ; add the VRAM base address to make an absolute address in VRAM
        ld      HL',    SMS_VRAM_SCREEN
        add     HL',    BC'             ; offset to top of the column needed
        set     6,      H'              ; add bit 6 as a VDP VRAM address

        ; there are 32 tiles (16-bit) per screen-width
        ld      BC',    64
        ld      D',     $3F | %01000000 ; upper limit of the screen table
                                        ; (bit 6 is set for VDP VRAM address)
        ld      E',     7
        exx

        ;-----------------------------------------------------------------------

        ld      HL,     RAM_OVERSCROLLCACHE_HORZ

        ; find where in a block the scroll offset sits (this is needed to find
        ; which of the 4 tiles width in a block have to be referenced)
        ld      A,      [RAM_VDPSCROLL_VERT]
        and     %00011111               ; MOD 32
        srl     A                       ; divide by 2 ...
        srl     A                       ; divide by 4 ...
        srl     A                       ; divide by 8
        ld      C,      A               ; load this into BC
        ld      B,      $00
        add     HL,     BC              ; add twice to HL
        add     HL,     BC
        ld      B,      <$BE32          ; set BC to $BE32
        ld      C,      >$BE32          ; (purpose unknown)

        ; set the VDP address calculated earlier,
        ; that is, the tile beginning in the top-left corner of the screen
@_2:    exx
        ld      A,      L'
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      H'
        out     [SMS_PORTS_VDP_CONTROL],        A

        ; move to the next row
        add     HL',    BC'
        ld      A,      H'
        cp      D'                      ; don't go outside the screen table
        jp      nc,     @_10

@_3:    exx

        outi                            ; send the tile index
        outi                            ; send the tile meta
        jp      nz,     @_2

        exx
        pop     BC'
        pop     DE'
        pop     HL'
        exx

        ;-----------------------------------------------------------------------

@_4:    bit     1,      [IY+Vars.flags2]
        jp      z,      @exit           ; could  optimise to `ret z`?

        ld      A,      [RAM_VDPSCROLL_VERT]
        ld      B,      $00
        srl     A
        srl     A
        srl     A

        ; camera moved up?
        bit     7,      [IY+Vars.flags0]
        jr      nz,     @_5

        add     A,      $18
@_5:    cp      $1C
        jr      c,      @_6
        sub     $1C

@_6:    add     A,      A
        add     A,      A
        add     A,      A
        add     A,      A
        rl      B
        add     A,      A
        rl      B
        add     A,      A
        rl      B
        ld      C,      A
        ld      A,      [RAM_VDPSCROLL_HORZ]
        add     A,      $08
        and     %11111000
        srl     A
        srl     A
        add     A,      C
        ld      C,      A
        ld      HL,     SMS_VRAM_SCREEN
        add     HL,     BC
        set     6,      H
        ex      DE,     HL
        ld      HL,     RAM_OVERSCROLLCACHE_VERT
        ld      A,      [RAM_VDPSCROLL_HORZ]
        and     %00011111
        add     A,      $08
        srl     A
        srl     A
        srl     A
        ld      C,      A
        ld      B,      $00
        add     HL,     BC
        add     HL,     BC
        ld      A,      E
        and     %11000000
        ld      [RAM_TEMP1],    A
        ld      A,              E
        out     [SMS_PORTS_VDP_CONTROL],A
        and     %00111111
        ld      E,      A
        ld      A,      D
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      B,      $3E
        ld      C,      $BE

@_7:    bit     6,      E
        jr      nz,     @_8

        inc     E
        inc     E
        outi
        outi
        jp      nz,     @_7
        ret

@_8:    ld      A,      [RAM_TEMP1]
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,      D
        out     [SMS_PORTS_VDP_CONTROL],A

@_9:    outi
        outi
        jp      nz,     @_9

@exit:  ret

        ;-----------------------------------------------------------------------

@_10:   sub     E
        ld      H,      A
        jp      @_3
        ;

getFloorLayoutRAMPosition:                                              ;$08D5
;===============================================================================
; Converts block X & Y co-ords into an address in the Floor Layout in RAM.
;
; in    BC      a flag, $0000 or $0001 depending on callee?
;               I think this is an "offset"
;-------------------------------------------------------------------------------
        ; get the low-byte of the width of the level in blocks. many levels are
        ; 256 blocks wide, ergo have a FloorWidth of $0100, making the low-byte
        ; "$00"
        ld      A,      [RAM_LEVEL_FLOORWIDTH]
        rlca                            ; double it (x2)
        jr      c,      @width128       ; >128?
        rlca                            ; double it again (x4)
        jr      c,      @width64        ; >64?
        rlca                            ; double it again (x8)
        jr      c,      @width32        ; >32?
        rlca                            ; double it again (x16)
        jr      c,      @width16        ; >16?
        jp      @width256               ; otherwise, 256?

@width128:
        ;-----------------------------------------------------------------------
        ld      A,      [RAM_BLOCK_Y]
        add     A,      B
        ld      E,      $00
        srl     A                       ; divide by 2
        rr      E
        ld      D,      A

        ld      A,      [RAM_BLOCK_X]
        add     A,      C
        add     A,      E
        ld      E,      A

        ld      HL,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width64:
        ;-----------------------------------------------------------------------
        ld      A,      [RAM_BLOCK_Y]
        add     A,      B
        ld      E,      $00
        srl     A
        rr      E
        srl     A
        rr      E
        ld      D,      A

        ld      A,      [RAM_BLOCK_X]
        add     A,      C
        add     A,      E
        ld      E,      A

        ld      HL,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width32:
        ;-----------------------------------------------------------------------
        ld      A,      [RAM_BLOCK_Y]
        add     A,      B
        ld      E,      $00
        srl     A
        rr      E
        srl     A
        rr      E
        srl     A
        rr      E
        ld      D,      A
        ld      A,      [RAM_BLOCK_X]
        add     A,      C
        add     A,      E
        ld      E,      A

        ld      HL,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width16:
        ;-----------------------------------------------------------------------
        ld      A,      [RAM_BLOCK_Y]
        add     A,      B
        ld      E,      $00
        srl     A
        rr      E
        srl     A
        rr      E
        srl     A
        rr      E
        srl     A
        rr      E
        ld      D,      A
        ld      A,      [RAM_BLOCK_X]
        add     A,      C
        add     A,      E
        ld      E,      A

        ld      HL,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width256:
        ;-----------------------------------------------------------------------
        ld      A,      [RAM_BLOCK_Y]
        add     A,      B
        ld      D,      A
        ld      A,      [RAM_BLOCK_X]
        add     A,      C
        ld      E,      A

        ld      HL,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret
        ;

fillScreenWithFloorLayout:                                              ;$0966
;===============================================================================
; This routine is only called during level loading to populate the screen with
; the visible portion of the Floor Layout. Scrolling fills in only the new
; tiles, so a full refresh of the screen is not required.
;-------------------------------------------------------------------------------
        ; interrupts are disabled during this routine
        ; due to it writing to the display
        di

        ; page in the Block Mappings, these are the 4x4 tile combinations that
        ; make up the Floor / Level
        ld      A,                      :blockMappings
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      :blockMappings + 1
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ld      BC,     $0000
        call    getFloorLayoutRAMPosition

        ;-----------------------------------------------------------------------
        ld      DE,     SMS_VRAM_SCREEN
        ; in 192-line mode the screen is 6 blocks tall,
        ; TODO: in 224-line mode it's 7 blocks tall
        ld      B,      SMS_SCREEN_HEIGHT / 32

@_1:    push    BC
        push    HL
        push    DE
        ld      B,      SMS_SCREEN_WIDTH / 32

@_2:    push    BC
        push    HL
        push    DE

        ; get the block index at the
        ; current location in the Floor Layout
        ld      A,      [HL]

        exx
        ld      E',     A               ; copy the block index to E
        ld      A,      [RAM_LEVEL_SOLIDITY]; load A with level's solidity index
        add     A,      A               ; double it (i.e. for a 16-bit pointer)
        ld      C',     A               ; put it into BC'
        ld      B',     $00
        ; get address of solidity pointer list
        ld      HL',    solidityBlocks
        add     HL',    BC'             ; offset solidity index into the list
        ld      A,      [HL']           ; read the data pointer into HL'
        inc     HL'
        ld      H',     [HL']
        ld      L',     A
        ld      D',     $00             ; DE' is the block index
        add     HL',    DE'             ; offset block index into solidity data
        ld      A,      [HL']           ; and get the solidity value

        ; in the solidity data, bit 7 determines that the tile should appear
        ; in front of sprites. rotate the byte three times to position bit 7 at
        ; bit 4. this byte will form the high-byte of the 16-bit value for the
        ; name table entry (bit 4 will therefore become bit 12 in a 16-bit no.)
        rrca
        rrca
        rrca

        ; bit 12 of a name table entry specifies if the tile should appear
        ; in front of sprites. allow just this bit if it's set
        and     %00010000
        ld      C',     A
        exx

        ; return the block index to HL
        ld      L,      [HL]
        ld      H,      $00
        ; block mappings are 16 bytes each
        ; TODO: make the number of shifts here based !BLOCK.SIZE?
        ; (add     HL   HL) x !BLOCK.SIZE
        add     HL,     HL              ; x2 ...
        add     HL,     HL              ; x4 ...
        add     HL,     HL              ; x8 ...
        add     HL,     HL              ; x16
        ld      BC,     [RAM_BLOCKMAPPINGS]
        add     HL,     BC

        ; DE will be the address of block mapping
        ; HL will be an address in the screen name table
        ex      DE,     HL

        ;-----------------------------------------------------------------------
        ld      B,      4               ; 4 rows of the block mapping

        ; set the screen name address
@_3:    ld      A,      L
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      H
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL],        A

        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE

        exx
        ld      A,      C'
        exx

        out     [SMS_PORTS_VDP_DATA],   A
        nop
        nop
        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE

        exx
        ld      A,      C'
        exx

        out     [SMS_PORTS_VDP_DATA],   A
        nop
        nop
        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE

        exx
        ld      A,      C'
        exx
        out     [SMS_PORTS_VDP_DATA],   A
        nop
        nop
        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE

        exx
        ld      A,      C'
        exx

        out     [SMS_PORTS_VDP_DATA],   A
        ld      A,      B
        ld      BC,     64
        add     HL,     BC
        ld      B,      A
        djnz    @_3

        pop     DE
        pop     HL
        inc     HL
        ld      BC,     $0008
        ex      DE,     HL
        add     HL,     BC
        ex      DE,     HL
        pop     BC
        djnz    @_2

        pop     DE
        pop     HL
        ld      BC,     [RAM_LEVEL_FLOORWIDTH]
        add     HL,     BC
        ex      DE,     HL
        ld      BC,     $0100
        add     HL,     BC
        ex      DE,     HL
        pop     BC
        dec     B
        jp      nz,     @_1

        ei      ; enable interrupts
        ret
        ;

loadFloorLayout:                                                        ;$0A10
;===============================================================================
; NOTE: called only by `loadLevel`
;
; in    HL      address of Floor Layout data
;       BC      length of compressed data
;-------------------------------------------------------------------------------
        ld      DE,     RAM_FLOORLAYOUT ; where in RAM the floor layout will go

        ; RLE decompress floor layout:
        ;-----------------------------------------------------------------------
@_1:    ld      A,      [HL]            ; read first byte of the floor layout
        cpl                             ; flip it to avoid first byte comparison
        ld      [IY+$01], A             ; this is the comparison byte

@_2:    ld      A,      [HL]            ; read the current byte
        cp      [IY+$01]                ; same as the comparison byte?
        jr      z,      @_3             ; if so, decompress it

        ; copy byte as normal:
        ld      [DE],           A       ; write it to RAM
        ld      [IY+$01],       A       ; update the comparison byte
        inc     HL                      ; move forward
        inc     DE
        dec     BC                      ; count number of remaining bytes
        ld      A,      B               ; are there remaining bytes?
        or      C
        jp      nz,     @_2             ; if so continue
        ret                             ; otherwise, finish

        ; if the last two bytes of the data are duplicates, don't try
        ; decompress further when there is no more data to be read!
@_3:    dec     BC                      ; reduce count of remaining bytes
        ld      A,      B               ; are there remaining bytes?
        or      C
        ret     z                       ; if not, finish

        ld      A,      [HL]            ; read the value to repeat
        inc     HL                      ; move to next byte (the repeat count)
        push    BC                      ; put length of compressed data aside
        ld      B,      [HL]            ; get the repeat count

@_4:    ld      [DE],   A               ; write value to RAM
        inc     DE                      ; move forward in RAM
        djnz    @_4                     ; continue until repeating is complete

        pop     BC                      ; retrieve the data length
        inc     HL                      ; move forward in the compressed data

        ; check if bytes remain
        dec     BC
        ld      A,      B
        or      C
        jp      nz,     @_1
        ret
        ;

fadeOut:                                                                ;$0A40
;===============================================================================
; Fades the screen to black.
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; switch in the default set of banks as palette data is primarily in
        ; bank 0 & 1, though I am not certain about bank 2 (where the majority
        ; of the mob code is)
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]; wait for interrupt to occur
        call    waitForInterrupt        ; refresh screen

        ; after the interrupt, the sprite update count would be cleared,
        ; put it back to its old value
        ld      [IY+Vars.spriteUpdateCount], A

        ld      B,      4
@_1:    push    BC                      ; put aside the loop counter

        ; fade out the tile palette one step
        ld      HL,     [RAM_LOADPALETTE_TILE]
        ld      DE,     RAM_PALETTE
        ld      B,      16
        call    darkenPalette

        ; fade out the sprite palette one step
        ld      HL,     [RAM_LOADPALETTE_SPRITE]
        ld      B,      16
        call    darkenPalette

        ; load the darkened palette on the next interrupt
        ld      HL,     RAM_PALETTE
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        ; wait 10 frames
        ld      B,      10
@_2:    ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount], A
        djnz    @_2

        pop     BC                      ; retrieve the loop counter
        djnz    @_1                     ; before looping back

        ret
        ;

darkenPalette:                                                          ;$0A90
;===============================================================================
; fades a palette one step darker
;
; in    HL      source palette address
;       DE      destination palette address (RAM)
;       B       length of palette (16)
;-------------------------------------------------------------------------------
        ; NOTE: SMS colours are in the format: 00BBGGRR

        ld      A,      [HL]            ; read the colour
        and     %00000011               ; does it have any red component?
        jr      z,      @_1             ; if not, skip ahead
        dec     A                       ; reduce the red brightness by 1

@_1:    ld      C,      A
        ld      A,      [HL]
        and     %00001100               ; does it have any green component?
        jr      z,      @_2             ; if not, skip ahead
        sub     %00000100               ; reduce the green brightness by 1

@_2:    or      C                       ; merge the green component back in
        ld      C,      A               ; put aside the current colour code
        ld      A,      [HL]            ; fetch the original colour code again
        and     %00110000               ; does it have any blue component?
        jr      z,      @_3             ; if not, skip ahead
        sub     %00010000               ; reduce the blue brightness by 1

@_3:    or      C                       ; merge the blue component back in
        ld      [DE],   A               ; update the palette colour

        ; move to the next palette colour and repeat
        inc     HL
        inc     DE
        djnz    darkenPalette

        ret
        ;

_aae:                                                                   ;$0AAE
;===============================================================================
; in    HL
;       IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      [RAM_TEMP6],    HL

        ; copy parameter palette into the
        ; temporary RAM palette used for fading out

        ld      HL,     [RAM_LOADPALETTE_TILE]
        ld      DE,     RAM_PALETTE
        ld      BC,     32              ; both palettes
        ldir

        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ;switch to using the temporary palette on screen
        ld      HL,     RAM_PALETTE
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        ld      C,      [IY+Vars.spriteUpdateCount]

        ld      A,      [RAM_VDPREGISTER_1]
        or      %01000000               ; enable screen (bit6 of VDP register 1)
        ld      [RAM_VDPREGISTER_1],    A

        ; wait for interrupt (refresh screen)
        ; -- the switch to the temporary palette (above) will occur
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ; refreshing the screen will zero-out the sprite
        ; update count, return it to the previous value
        ld      [IY+Vars.spriteUpdateCount],       C

        ; wait for 9 more frames
        ld      B,      9
@_1:    ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       A
        djnz    @_1

        ; fade palette
        ; (why is this not just calling `darkenPalette`?)

        ld      B,      4
@_2:    push    BC
        ld      HL,     [RAM_TEMP6]     ; restore the HL parameter
        ld      DE,     RAM_PALETTE
        ld      B,      32

@_3:    push    BC

        ld      A,      [HL]
        and     %00000011
        ld      B,      A
        ld      A,      [DE]
        and     %00000011
        cp      B
        jr      z,      @_4
        dec     A
@_4:    ld      C,      A
        ld      A,      [HL]
        and     %00001100
        ld      B,      A
        ld      A,      [DE]
        and     %00001100
        cp      B
        jr      z,      @_5
        sub     %00000100
@_5:    or      C
        ld      C,      A
        ld      A,      [HL]
        and     %00110000
        ld      B,      A
        ld      A,      [DE]
        and     %00110000
        cp      B
        jr      z,      @_6
        sub     %00010000
@_6:    or      C
        ld      [DE],   A
        inc     HL
        inc     DE
        pop     BC
        djnz    @_3

        ld      HL,     RAM_PALETTE
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        ; wait for 10 frames
        ld      B,      10
@_7:    ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       A
        djnz    @_7

        pop     BC
        djnz    @_2
        ret
        ;

_b50:                                                                   ;$0B50
;===============================================================================
; in    HL      Address of a palette
;-------------------------------------------------------------------------------
        ld      [RAM_TEMP6],    HL      ; put the palette parameter aside
        ld      HL,     RAM_PALETTE     ; RAM cache of current palette

        ; erase the current palette
        ld      B,      32              ; 32 colours
@loop:  ld      [HL],   $00             ; set the palette colour to black
        inc     HL
        djnz    @loop

        jp      _b60@_1
        ;

_b60:                                                                   ;$0B60
;===============================================================================
; in    HL
;       IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      [RAM_TEMP6],    HL

        ld      HL,     [RAM_LOADPALETTE_TILE]
        ld      DE,     RAM_PALETTE
        ld      BC,     32              ; 32 colours
        ldir

        ;-----------------------------------------------------------------------

@_1:    ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ld      HL,     RAM_PALETTE
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        ld      C,      [IY+Vars.spriteUpdateCount]
        ld      A,      [RAM_VDPREGISTER_1]
        or      $40
        ld      [RAM_VDPREGISTER_1],    A

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       C
        ld      B,      $09

@_2:    ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       A
        djnz    @_2

        ld      B,      $04

@_3:    push    BC
        ld      HL,     [RAM_TEMP6]
        ld      DE,     RAM_PALETTE
        ld      B,      32

@_4:    push    BC
        ld      A,      [HL]
        and     %00000011
        ld      B,      A
        ld      A,      [DE]
        and     %00000011
        cp      B
        jr      nc,     @_5
        inc     A
@_5:    ld      C,      A
        ld      A,      [HL]
        and     %00001100
        ld      B,      A
        ld      A,      [DE]
        and     %00001100
        cp      B
        jr      nc,     @_6
        add     A,      $04
@_6:    or      C
        ld      C,      A
        ld      A,      [HL]
        and     %00110000
        ld      B,      A
        ld      A,      [DE]
        and     %00110000
        cp      B
        jr      nc,     @_7
        add     A,      $10
@_7:    or      C
        ld      [DE],   A
        inc     HL
        inc     DE
        pop     BC
        djnz    @_4

        ld      HL,     RAM_PALETTE
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        ld      B,      10
@_8:    ld      A,       [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       A
        djnz    @_8

        pop     BC
        djnz    @_3

        ret
        ;

getLevelBitFlag:                                                        ;$0C02
;===============================================================================
; in    HL      an address to a series of 19 bits, one for each level
;               D305+: set by life monitor
;               D30B+: set by emerald
;               D311+: set by continue monitor
;               D317+: set by switch
;-------------------------------------------------------------------------------
        ld      A,      [RAM_CURRENT_LEVEL]
        ld      C,      A
        srl     A       ; divide by 2 ...
        srl     A       ; divide by 4 ...
        srl     A       ; divide by 8

        ; put the result into DE
        ld      E,      A
        ld      D,      $00
        ; add that to the parameter (e.g. D311)
        add     HL,     DE

        ld      A,      C               ; return to the current level number
        ld      C,      1
        and     %00000111               ; MOD 8
        ret     z                       ; if level 0,8,16,... then return C=1
        ld      B,      A               ; B = 1-7
        ld      A,      C               ; 1

        ; slide the bit up the byte between
        ; 0-7 depending on the level number
@loop:  rlca
        djnz    @loop
        ld      C,      A               ; return via C

        ; HL : address to the byte where the bit exists
        ;  C : the bit mask, e.g. 1, 2, 4, 8, 16, 32, 64 or 128
        ret
        ;


loadPowerUpIcon:                                                        ;$0C1D
;===============================================================================
; copy power-up icon into sprite VRAM
;
; in    HL      absolute address to uncompressed art data for the icons,
;               assuming that slot 1 ($4000-$7FFF) is loaded with bank 5
;               ($14000-$17FFF)
;-------------------------------------------------------------------------------
        di
        ld      A,                      5
        ld      [SMS_MAPPER_SLOT1],     A

        ld      A,      [RAM_FRAMECOUNT]
        and     %00001111
        add     A,      A               ; x2
        add     A,      A               ; x4
        add     A,      A               ; x8
        ld      E,      A               ; put it into DE
        ld      D,      $00
        add     HL,     DE              ; offset into HL parameter

        ex      DE,     HL
        ld      BC,     $2B80

        add     HL,     BC
        ld      A,      L
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      H
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL],        A

        ld      B,      4
@loop:  ld      A,       [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        nop
        nop
        inc     DE
        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE
        djnz    @loop

        ; return to the previous bank number
        ld      A,      [RAM_SLOT1]
        ld      [SMS_MAPPER_SLOT1],     A
        ei

        ret
        ;

_LABEL_C52_106:                                                         ;$0C52
;===============================================================================
; map screen?
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; reset horizontal / vertical hardware
        ; scroll; the map screen doesn't scroll
        xor     A                       ; set A to 0
        ld      [RAM_VDPSCROLL_HORZ],   A
        ld      [RAM_VDPSCROLL_VERT],   A

        ld      A,      $FF
        ld      [RAM_D216],     A

        ; either one or two, depending on level
        ; -- probably regular or special stage
        ld      C,      $01

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      18
        ret     nc

        cp      9
        jr      c,      @_1

        ld      C,      $02

@_1:    ld      A,      [RAM_D216]
        cp      C
        jp      z,      @_4

        ld      A,      C
        ld      [RAM_D216],     A
        dec     A
        jr      nz,     @_2

        ; turn the screen off
        ld      A,      [RAM_VDPREGISTER_1]
        and     %10111111               ; remove bit 6 of VDP register 1
        ld      [RAM_VDPREGISTER_1],    A

        ; refresh the screen (wait for interrupt to complete)
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ; TODO: use labels & expressions to specify the tileset locations

        ; map screen 1 tileset
        ld      HL,     $0000
        ld      DE,     $0000
        ld      A,      12              ;=$30000
        call    decompressArt

        ;map screen 1 sprite set
        ld      HL,     $526B           ;=$2926B
        ld      DE,     $2000
        ld      A,      9
        call    decompressArt

        ; HUD tileset
        ld      HL,     $B92E           ;=$2F92E
        ld      DE,     $3000
        ld      A,      9
        call    decompressArt

        ; load page 1 ($4000-$7FFF)
        ; with bank 5 ($14000-$17FFF)
        ld      A,                      5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ; map 1 background
        ld      HL,     $627E
        ld      BC,     $0178
        ld      DE,     SMS_VRAM_SCREEN
        ld      A,      $10
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ; map 1 foreground
        ld      HL,     $63F6
        ld      BC,     $0145
        ld      DE,     SMS_VRAM_SCREEN
        ld      A,      $00
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ld      HL,     map1Palette
        call    _b50
        jr      @_3

        ;-----------------------------------------------------------------------

@_2:    ; turn the screen off
        ld      A,      [RAM_VDPREGISTER_1]
        and     %10111111               ; remove bit 6 of VDP register 1
        ld      [RAM_VDPREGISTER_1],    A

        ; refresh the screen
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ; map screen 2 tileset
        ld      HL,     $1801           ;=$31801
        ld      DE,     $0000
        ld      A,      12
        call    decompressArt

        ;map screen 2 sprites
        ld      HL,     $5942           ;=$29942
        ld      DE,     $2000
        ld      A, 9
        call    decompressArt

        ;HUD tileset
        ld      HL,     $B92E           ;=$2F92E
        ld      DE,     $3000
        ld      A, 9
        call    decompressArt

        ;load page 1 ($4000-$7FFF) with bank 5 ($14000-$17FFF)
        ld      A, 5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;map screen 2 background
        ld      HL,     $653B
        ld      BC,     $0170
        ld      DE,     SMS_VRAM_SCREEN
        ld      A,      $10
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ;map screen 2 foreground
        ld      HL,     $66AB
        ld      BC,     $0153
        ld      DE,     SMS_VRAM_SCREEN
        ld      A,      $00
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ld      HL,     map2Palette
        call    _b50

        ;play the map screen music:
        ; (we can compile with, or without, sound)
@_3:    .IFDEF  OPTION_SOUND
                ld      A,      7
                rst     $18     ;=rst_playMusic
        .ENDIF

        ;-----------------------------------------------------------------------

@_4:    call    _LABEL_E86_110
        ld      A,      [RAM_CURRENT_LEVEL]
        add     A,      A
        ld      C,      A
        ld      B,      $00
        ld      HL,     zoneTitles
        add     HL,     BC
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A

        ;display in-front of sprites (bit 12 of tile)
        ld      A,      %00010000
        ld      [RAM_TEMP1],    A
        call    print

        ld      A,      [RAM_CURRENT_LEVEL]
        ld      C,      A
        add     A,      A
        add     A,      C
        ld      E,      A
        ld      D,      $00
        ld      HL,     _f4e
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_TEMP3],    DE
        ld      A,      [HL]
        and     A
        jr      z,      @_

        dec     A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     _1201
        add     HL,     DE
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        jp      [HL]

; NOTE: externally jumped to
@_:     ld      A,      $01
        ld      [RAM_TEMP1],    A
        ld      BC,     $012C

@_5:    push    BC
        call    _LABEL_E86_110
        ld      A,      [RAM_TEMP1]
        dec     A
        ld      [RAM_TEMP1],    A
        jr      nz,     @_8

        ld      HL,     [RAM_TEMP3]
@_6:    ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL
        ld      [RAM_TEMP6],    BC
        ld      A,      [HL]
        inc     HL
        and     A
        jr      nz,     @_7

        ex      DE,     HL
        jp      @_6

        ;-----------------------------------------------------------------------

@_7:    ld      [RAM_TEMP1],    A
        ld      [RAM_TEMP3],    HL
        ld      [RAM_TEMP4],    DE

@_8:    ld      HL,      [RAM_TEMP6]
        push    HL
        ld      E,H
        ld      H,$00
        ld      D,H
        ld      BC,     [RAM_TEMP4]
        call    processSpriteLayout
        pop     HL
        ld      [RAM_TEMP6],    HL
        pop     BC
        dec     BC
        ld      A,      B
        or      C
        ret     z

        bit     5,      [IY+Vars.joypad]
        jp      nz,     @_5
        ret     nz

        scf
        ret
        ;

_0dd9:                                                                  ;$0DD9
;===============================================================================
; referenced by table at $1201
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        ld      HL,     $00DC
        ld      DE,     $003C
        ld      B,      $00

@_1:    call    _LABEL_E86_110
        ld      A,      [IY+Vars.joypad]
        cp      $FF
        jp      nz,     _LABEL_C52_106@_

        push    BC
        ld      BC,     _0e72
        call    _0edd

        pop     BC
        dec     HL
        djnz    @_1

        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        ld      HL,     $FFD8
        ld      DE,     $0058
        ld      B,      $80

@_2:    call    _LABEL_E86_110
        ld      A,      [IY+Vars.joypad]
        cp      $FF
        jp      nz,     _LABEL_C52_106@_

        push    BC
        ld      BC,     _0e7a
        call    _0edd
        pop     BC
        inc     HL
        djnz    @_2

        jp      _LABEL_C52_106@_
        ;

_0e24:                                                                  ;$0E24
;===============================================================================
; referenced by table at $1201
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        ld      HL,     $0080
        ld      DE,     $00C0
        ld      B,      $78

@loop:  call    _LABEL_E86_110
        ld      A,      [IY+Vars.joypad]
        cp      $FF
        jp      nz,     _LABEL_C52_106@_

        push    BC
        ld      BC,     _0e82
        call    _0edd
        pop     BC
        dec     DE
        djnz    @loop

        jp      _LABEL_C52_106@_
        ;

_0e4b:                                                                  ;$04EB
;===============================================================================
; referenced by table at $1201
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        ld      HL,     $0078
        ld      DE,     $0000
        ld      B,      $30

@loop:  call    _LABEL_E86_110
        ld      A,      [IY+Vars.joypad]
        cp      $FF
        jp      nz,     _LABEL_C52_106@_

        push    BC
        ld      BC,     _0e82
        call    _0edd
        pop     BC
        inc     DE
        djnz    @loop

        jp      _LABEL_C52_106@_
        ;

_0e72:                                                                  ;$0E72
;===============================================================================
        .TABLE  WORD    BYT BYT
        .ROW    _1129   $04 $01
        .ROW    _113b   $04 $00
        ;

_0e7a:                                                                  ;$0E7A
;===============================================================================
        .TABLE  WORD    BYT BYT
        .ROW    _114d   $04 $01
        .ROW    _115f   $04 $00
        ;

_0e82:                                                                  ;$0E82
;===============================================================================
        .TABLE  WORD    BYT BYT
        .ROW    _1183   $04 $00
        ;

_LABEL_E86_110:                                                         ;$0E86
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;       TEMP1
;-------------------------------------------------------------------------------
        push    HL
        push    DE
        push    BC

        ld      HL,     [RAM_TEMP1]
        push    HL

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       $00
        ld      A,      [RAM_LIVES]
        ld      L,      A
        ld      H,      $00
        ld      C,      $0A
        call    _LABEL_60F_111

        ld      A,      L
        add     A,      A
        add     A,      $80
        ld      [RAM_LAYOUT_BUFFER],    A
        ld      C,      10
        call    multiply

        ex      DE,     HL

        ld      A,      [RAM_LIVES]
        ld      L,      A
        ld      H,      $00
        and     A
        sbc     HL,     DE
        ld      A,      L
        add     A,      A
        add     A,      $80
        ld      [RAM_LAYOUT_BUFFER+1],  A
        ld      A,      $FF
        ld      [RAM_LAYOUT_BUFFER+2],  A

        ld      B,      167
        ld      C,      40
        ld      HL,     RAM_SPRITETABLE
        ld      DE,     RAM_LAYOUT_BUFFER
        call    layoutSpritesHorizontal

        ld      [RAM_SPRITETABLE_ADDR], HL
        pop     HL
        ld      [RAM_TEMP1],    HL

        pop     BC
        pop     DE
        pop     HL
        ret
        ;

_0edd:                                                                  ;$0EDD
;===============================================================================
; something to do with constructing the sprites on the map screen?
;
; in    BC
;-------------------------------------------------------------------------------
        push    HL
        push    DE

        ;copy BC to HL
        ld      L,      C
        ld      H,      B

        ld      A,      [RAM_TEMP2]
        add     A,      A                                       ;x2
        add     A,      A                                       ;x4
        ld      E,      A
        ld      D,      $00
        add     HL,     DE

        ;read the address of a sprite layout from the list
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL

        ld      A,      [RAM_TEMP1]
        cp      [HL]
        jr      c,      @_1

        inc     HL
        ld      A,      [HL]
        ld      [RAM_TEMP2],    A
        xor     A
        ld      [RAM_TEMP1],    A

@_1:    pop     DE                                              ;Y-position
        pop     HL                                              ;X-position
        push    HL
        push    DE
        call    processSpriteLayout

        ld      A,      [RAM_TEMP1]
        inc     A
        ld      [RAM_TEMP1],    A

        pop     DE
        pop     HL
        ret
        ;

map1Palette:                                                            ;$0F0E
;===============================================================================
        .TABLE  DSB 16
        .ROW    $35 $01 $06 $0B $04 $08 $0C $3D $1F $39 $2A $14 $25 $2B $00 $3F
        .ROW    $2B $20 $35 $1B $16 $2A $00 $3F $03 $0F $01 $15 $00 $3C $00 $3F
        ;

map2Palette:                                                            ;$0F2E
;===============================================================================
        .TABLE  DSB 16
        .ROW    $25 $01 $06 $0B $04 $18 $2C $35 $2B $10 $2A $14 $15 $1F $00 $3F
        .ROW    $2B $20 $35 $1B $16 $2A $00 $3F $03 $0F $01 $15 $07 $2D $00 $3F
        ;

_f4e:                                                                   ;$0F4E
;===============================================================================
; TODO: these rows need to be appended by the level definitons

        .TABLE  WORD    BYTE
        .ROW    _0f84   $00             ; Green Hill Act 1
        .ROW    _0f93   $00             ; Green Hill Act 2
        .ROW    _0fde   $01             ; Green Hill Act 3
        .ROW    _0fa2   $00             ; Bridge Act 1
        .ROW    _0fb1   $00             ; Bridge Act 2
        .ROW    _107e   $02             ; Bridge Act 3
        .ROW    _0fc0   $00             ; Jungle Act 1
        .ROW    _0fcf   $00             ; Jungle Act 2
        .ROW    _1088   $03             ; Jungle Act 3
        .ROW    _100b   $00             ; Labyrinth Act 1
        .ROW    _101a   $00             ; Labyrinth Act 2
        .ROW    _1092   $00             ; Labyrinth Act 3
        .ROW    _1029   $00             ; Scrap Brain Act 1
        .ROW    _1038   $00             ; Scrap Brain Act 2
        .ROW    _109c   $00             ; Scrap Brain Act 3
        .ROW    _1047   $00             ; Sky Base Act 1
        .ROW    _1056   $00             ; Sky Base Act 2
        .ROW    _1056   $00             ; Sky Base Act 3
        ;

_0f84:  ; Green Hill Act 1                                              ;$0F84
;===============================================================================
        .TABLE  WORD    DSB 3
        .ROW    _10bd   $50 $68 $1E
        .ROW    _10ab   $50 $68 $1E
        .ROW    _0f84   $00 $00 $00
        ;

_0f93:  ; Green Hill Act 2                                              ;$0F93
;===============================================================================
        .TABLE  WORD    DSB 3
        .ROW    _10cf   $50 $60 $1E
        .ROW    _10ab   $50 $60 $1E
        .ROW    _0f93   $00 $00 $00
        ;

_0fa2:  ; Bridge Act 1                                                  ;$0FA2
;===============================================================================
        .TABLE  WORD    DSB 3
        .ROW    _10e1   $60 $60 $1E
        .ROW    _10ab   $60 $60 $1E
        .ROW    _0fa2   $00 $00 $00
        ;

_0fb1:  ; Bridge Act 2                                                  ;$0FB1
;===============================================================================
        .TABLE  WORD    DSB 3
        .ROW    _10f3   $80 $50 $1E
        .ROW    _10ab   $80 $50 $1E
        .ROW    _0fb1   $00 $00 $00
        ;

_0fc0:  ; Jungle Act 1                                                  ;$0FC0
;===============================================================================
        .TABLE  WORD    DSB 3
        .ROW    _1105   $70 $48 $1E
        .ROW    _10ab   $70 $48 $1E
        .ROW    _0fc0   $00 $00 $00
        ;

_0fcf:  ; Jungle Act 2                                                  ;$0FCF
;===============================================================================
        .TABLE  WORD    DSB 3
        .ROW    _1117   $70 $38 $1E
        .ROW    _10ab   $70 $38 $1E
        .ROW    _0fcf   $00 $00 $00
        ;

_0fde:  ; Green Hill Act 3                                              ;$0FDE
;===============================================================================
        .TABLE  WORD    DSB 3
        .ROW    _1183   $58 $58 $08
        .ROW    _1183   $58 $58 $08
        .ROW    _1183   $58 $56 $08
        .ROW    _1183   $58 $56 $08
        .ROW    _1183   $58 $55 $08
        .ROW    _1183   $58 $55 $08
        .ROW    _1183   $58 $56 $08
        .ROW    _1183   $58 $56 $08
        .ROW    _0fde   $00 $00 $00
        ;

_100b:  ; Labyrinth Act 1                                               ;$100B
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _1195   $58 $68 $1E
        .ROW    _10ab   $58 $68 $1E
        .ROW    _100b   $00 $00 $00
        ;

_101a:  ; Labyrinth Act 2                                               ;$101A
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _11a7   $68 $78 $1E
        .ROW    _10ab   $68 $78 $1E
        .ROW    _101a   $00 $00 $00
        ;

_1029:  ; Scrap Brain Act 1                                             ;$1029
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _11b9   $70 $58 $1E
        .ROW    _10ab   $70 $58 $1E
        .ROW    _1029   $00 $00 $00
        ;

_1038:  ; Scrap Brain Act 2                                             ;$1038
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _11cb   $78 $48 $1E
        .ROW    _10ab   $78 $48 $1E
        .ROW    _1038   $00 $00 $00
        ;

_1047:  ; Sky Base Act 1                                                ;$1047
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _11dd   $68 $28 $1E
        .ROW    _10ab   $68 $28 $1E
        .ROW    _1047   $00 $00 $00
        ;

_1056:  ; Sky Base Act 2 / 3                                            ;$1056
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _11ef   $80 $28 $1E
        .ROW    _11ef   $80 $26 $08
        .ROW    _11ef   $80 $26 $08
        .ROW    _11ef   $80 $25 $08
        .ROW    _11ef   $80 $25 $08
        .ROW    _11ef   $80 $26 $08
        .ROW    _11ef   $80 $26 $08
        .ROW    _1056   $00 $00 $00
        ;

_107e:  ; Bridge Act 3                                                  ;$107E
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _1183   $80 $48 $08
        .ROW    _107e   $00 $00 $00
        ;

_1088:  ; Jungle Act 3                                                  ;$1088
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _1183   $78 $30 $08
        .ROW    _1088   $00 $00 $00
        ;

_1092:  ; Labyrinth Act 3                                               ;$1092
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _1183   $70 $60 $08
        .ROW    _1092   $00 $00 $00
        ;

_109c:  ; Scrap Brain Act 3                                             ;$109C
;===============================================================================
        .TABLE  WORD    DSB 3        
        .ROW    _1129   $68 $40 $08
        .ROW    _113b   $68 $40 $08
        .ROW    _109c   $00 $00 $00
        ;

; blank frame (to make it blink)

_10ab:                                                                  ;$10AB
;===============================================================================
        ; why not self-terminating,
        ; rather than the full block?
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_10bd:                                                                  ;$10BD
;===============================================================================
        ; Green Hill Act 1
        .BYTE   $00 $02 $FF $FF $FF $FF
        .BYTE   $FE $22 $24 $26 $28 $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_10cf:                                                                  ;$10CF
;===============================================================================
        ; Green Hill Act 2
        .BYTE   $04 $06 $08 $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_10e1:                                                                  ;$10E1
;===============================================================================
        ; Bridge Act 1
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_10f3:                                                                  ;$10F3
;===============================================================================
        ; Bridge Act 2
        .BYTE   $4A $4C $FF $FF $FF $FF
        .BYTE   $6A $6C $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_1105:                                                                  ;$1105
;===============================================================================
        ; Jungle Act 1
        .BYTE   $60 $62 $64 $66 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_1117:                                                                  ;$1117
;===============================================================================
        ; Jungle Act 2
        .BYTE   $FE $FE $0E $FF $FF $FF
        .BYTE   $2A $2C $2E $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_1129:                                                                  ;$1129
;===============================================================================
        ; Scrap Brain Act 3 - step 1
        .BYTE   $10 $12 $14 $16 $FF $FF
        .BYTE   $30 $32 $34 $36 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_113b:                                                                  ;$113B
;===============================================================================
        ; Scrap Brain Act 3 - step 2
        .BYTE   $10 $12 $14 $18 $FF $FF
        .BYTE   $30 $32 $34 $38 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_114d:                                                                  ;$114D
;===============================================================================
        ; Robotnik flying right frame 1
        .BYTE   $50 $54 $56 $58 $FF $FF                                 ;referenced by table at `_0e7a`
        .BYTE   $70 $74 $76 $78 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_115f:                                                                  ;$115F
;===============================================================================
        ; Robotnik flying right frame 2
        .BYTE   $52 $54 $56 $58 $FF $FF                                 ;referenced by table at `_0e7a`
        .BYTE   $72 $74 $76 $78 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_1171:                                                                  ;$1171
;===============================================================================
        ; unused -- same as _114d
        .BYTE   $50 $54 $56 $58 $FF $FF
        .BYTE   $70 $74 $76 $78 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_1183:                                                                  ;$1183
;===============================================================================
        ; Green Hill, Bridge, Jungle & Labyrinth Act 3
        .BYTE   $5A $5C $5E $FF $FF $FF
        .BYTE   $7A $7C $7E $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_1195:                                                                  ;$1195
;===============================================================================
        ; Labyrinth Act 1
        .BYTE   $00 $02 $FF $FF $FF $FF
        .BYTE   $20 $22 $04 $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_11a7:                                                                  ;$11A7
;===============================================================================
        ; Labyrinth Act 2
        .BYTE   $0A $0C $0E $FF $FF $FF
        .BYTE   $2A $2C $2E $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_11b9:                                                                  ;$11B9
;===============================================================================
        ; Scrap Brain Act 1
        .BYTE   $68 $6A $6C $FF $FF $FF
        .BYTE   $FE $FE $6E $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_11cb:                                                                  ;$11CB
;===============================================================================
        ; Scrap Brain Act 2
        .BYTE   $06 $08 $4A $4C $FF $FF
        .BYTE   $FE $FE $4E $3E $FF $FF
        .BYTE   $FE $40 $42 $44 $FF $FF
        ;

_11dd:                                                                  ;$11DD
;===============================================================================
        ; Sky Base Act 1
        .BYTE   $60 $62 $64 $66 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_11ef:                                                                  ;$11EF
;===============================================================================
        ; Sky Base Act 2 / 3
        .BYTE   $46 $48 $26 $28 $FF $FF
        .BYTE   $1A $1C $3A $3C $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

; list of functions that handle
; extra animations on the map screen:

_1201:                                                                  ;$1201
;===============================================================================
        .ADDR   _0dd9
        .ADDR   _0e24
        .ADDR   _0e4b
        .ADDR   _0dd9
        ;

zoneTitles:                                                             ;$1209
;===============================================================================
        .ADDR   @greenHill              ; Green Hill Act 1
        .ADDR   @greenHill              ; Green Hill Act 2
        .ADDR   @greenHill              ; Green Hill Act 3
        .ADDR   @bridge                 ; Bridge Act 1
        .ADDR   @bridge                 ; Bridge Act 2
        .ADDR   @bridge                 ; Bridge Act 3
        .ADDR   @jungle                 ; Jungle Act 1
        .ADDR   @jungle                 ; Jungle Act 2
        .ADDR   @jungle                 ; Jungle Act 3
        .ADDR   @labyrinth              ; Labyrinth Act 1
        .ADDR   @labyrinth              ; Labyrinth Act 2
        .ADDR   @labyrinth              ; Labyrinth Act 3
        .ADDR   @scrapBrain             ; Scrap Brain Act 1
        .ADDR   @scrapBrain             ; Scrap Brain Act 2
        .ADDR   @scrapBrain             ; Scrap Brain Act 3
        .ADDR   @skyBase                ; Sky Base Act 1
        .ADDR   @skyBase                ; Sky Base Act 2
        .ADDR   @skyBase                ; Sky Base Act 3

@greenHill:     ; "GREEN HILL"                                          ;$122D
        .BYTE   $10 $13 $46 $62 $44 $44 $51 $EB $47 $40 $43 $43 $EB $EB $FF
@bridge:        ; "BRIDGE"                                              ;$123C
        .BYTE   $10 $13 $35 $62 $40 $37 $46 $44 $EB $EB $EB $EB $EB $EB $FF
@jungle:        ; "JUNGLE"                                              ;$124B
        .BYTE   $10 $13 $41 $81 $51 $46 $43 $44 $EB $EB $EB $EB $EB $EB $FF
@labyrinth:     ; "LABYRINTH"                                           ;$125A
        .BYTE   $10 $13 $6F $1E $1F $DE $9F $5E $7F $AF $4F $EB $EB $EB $FF
@scrapBrain:    ; "SCRAP BRAIN"                                         ;$1269
        .BYTE   $10 $13 $AE $2E $9F $1E $8F $EB $1F $9F $1E $5E $7F $EB $FF
@skyBase:       ; "SKY BASE"                                            ;$1278
        .BYTE   $10 $13 $AE $6E $DE $EB $1F $1E $AE $3E $EB $EB $EB $EB $FF
        ;

titleScreen:                                                            ;$1287
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------

        ;turn off screen
        ld      A,      [RAM_VDPREGISTER_1]
        and     %10111111                                       ;remove bit 6 of $D219
        ld      [RAM_VDPREGISTER_1],    A

        ;refresh the screen
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ;load the title screen tile set
        ;BANK 9 ($24000) + $2000 = $26000
        ld      HL,     $2000
        ld      DE,     $0000
        ld      A, 9
        call    decompressArt

        ;load the title screen sprite set
        ;BANK 9 ($24000) + $4B0A = $28B0A
        ld      HL,     $4B0A
        ld      DE,     $2000
        ld      A, 9
        call    decompressArt

        ;now switch page 1 ($4000-$7FFF) to bank 5 ($14000-$17FFF)
        ld      A, 5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;load the title screen itself
        ld      HL,     $6000                                   ;ROM:$16000
        ld      DE,     SMS_VRAM_SCREEN
        ld      BC,     $012E
        ld      A,      $00
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ;reset horizontal / vertical scroll
        xor     A                                          ;set A to zero
        ld      [RAM_VDPSCROLL_HORZ],   A
        ld      [RAM_VDPSCROLL_VERT],   A

        ;load the palette
        ld      HL,     @S1_TitleScreen_Palette
        ld      A,      %00000011                               ;flags to load tile & sprite palettes
        call    loadPaletteOnInterrupt

        set     1,      [IY+Vars.flags0]

        ;play title screen music:
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_TITLESCREEN
                rst     $18     ;=rst_playMusic
        .ENDIF

        ;initialise the animation parameters?
        xor     A
        ld      [RAM_D216],     A       ; reset the screen counter
        ld      A,      $01
        ld      [RAM_TEMP2],    A
        ld      HL,     @_1372
        ld      [RAM_TEMP3],    HL

        ;-----------------------------------------------------------------------
@_1:    ;switch screen on (set bit 6 of VDP register 1)
        ld      A,      [RAM_VDPREGISTER_1]
        or      %01000000
        ld      [RAM_VDPREGISTER_1],    A

        ;refresh the screen
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ;count to 100:
        ld      A,      [RAM_D216]      ; get the screen counter
        inc     A                       ; add one
        cp      100                     ; if less than 100,
        jr      c,      @_2             ; keep counting,

        xor     A                       ; otherwise go back to 0
@_2:    ld      [RAM_D216],     A       ; update screen counter value

        ld      HL,     @_1352
        cp      $40
        jr      c,      @_3

        ld      HL,     @_1362
@_3:    xor     A                                          ;set A to 0
        ld      [RAM_TEMP1],    A
        call    print

        ld      A,      [RAM_TEMP2]
        dec     A
        ld      [RAM_TEMP2],    A
        jr      nz,     @_4

        ld      HL,     [RAM_TEMP3]
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      A,      [HL]
        inc     HL

        ;when the animation reaches the end,
        ;exit the title screen (begin demo mode)
        and     A
        jr      z,      @_5

        ld      [RAM_TEMP2],    A
        ld      [RAM_TEMP3],    HL
        ld      [RAM_TEMP4],    DE

        ;set the game's main sprite table as the table to use
@_4:    ld      HL,     RAM_SPRITETABLE
        ld      [RAM_SPRITETABLE_ADDR], HL

        ld      HL,     $0080
        ld      DE,     $0018
        ld      BC,     [RAM_TEMP4]
        call    processSpriteLayout

        ;has the button been pressed? if not, repeat
        bit     5,      [IY+Vars.joypad]
        jp      nz,     @_1

        scf

        ; (we can compile with, or without, sound)
@_5:    .IFDEF  OPTION_SOUND
                rst     rst_muteSound
        .ENDIF
        ret

        ;-----------------------------------------------------------------------

@_1352: ; "PRESS  BUTTON" text                                          ;$1352
        .BYTE   $09 $12
        .BYTE   $E3 $E4 $E5 $E6 $E6 $F1 $F1 $E9 $EB $E7 $E7 $EA $EC $FF
@_1362:                                                                 ;$1362
        .BYTE   $09 $12
        .BYTE   $F1 $F1 $F1 $F1 $F1 $F1 $F1 $F1 $F1 $F1 $F1 $F1 $F1 $FF

@_1372: ; wagging finger animation data:                                ;$1372
        .TABLE  WORD    BYTE
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
        .ROW    @_13bd  $08
        .ROW    @_13cf  $08
@_13b4: .ROW    @_13bd  $FF                                             ;$13B4
        .ROW    @_13bd  $FF
        .ROW    @_13b4  $00

@_13bd: ; frame 1 sprite layout                                         ;$13BD
        .BYTE   $00 $02 $04 $FF $FF $FF
        .BYTE   $20 $22 $24 $FF $FF $FF
        .BYTE   $40 $42 $44 $FF $FF $FF

@_13cf: ; frame 2 sprite layout                                         ;$13CF
        .BYTE   $06 $08 $FF $FF $FF $FF
        .BYTE   $26 $28 $FF $FF $FF $FF
        .BYTE   $46 $48 $FF $FF $FF $FF

@S1_TitleScreen_Palette:                                                ;$13E1
        .TABLE  DSB 16
        .ROW    $00 $10 $34 $38 $06 $1B $2F $3F $3D $3E $01 $03 $0B $0F $00 $3F
        .ROW    $00 $10 $34 $38 $06 $1B $2F $3F $3D $3E $01 $03 $0B $0F $00 $3F
        ;

_1401:                                                                  ;$1401
;===============================================================================
; Act Complete screen?
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ;turn off the screen
        ld      A,      [RAM_VDPREGISTER_1]
        and     %10111111                                       ;remove bit 6 of VDP register 1
        ld      [RAM_VDPREGISTER_1],    A

        ;refresh the screen
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        di

        ;act complete sprite set
        ld      HL,     $351f
        ld      DE,     $0000
        ld      A, 9
        call    decompressArt

        ;switch page 1 ($4000-$7FFF) to bank 5 ($14000-$17FFF)
        ld      A, 5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;act complete background
        ld      HL,     $67FE
        ld      BC,     $0032
        ld      DE,     SMS_VRAM_SCREEN
        ld      A,      $00
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        xor     A
        ld      [RAM_VDPSCROLL_HORZ],   A
        ld      [RAM_VDPSCROLL_VERT],   A

        ld      HL,     @_14fc
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        ei

        ld      B,      $78

@_1:    ;turn the screen on
        ld      A,      [RAM_VDPREGISTER_1]
        or      %01000000                                       ;enable bit 6 on VDP register 1
        ld      [RAM_VDPREGISTER_1],    A

        ;refresh the screen
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        djnz    @_1

        ld      A,      [RAM_D284]
        and     A
        jr      nz,     @_3

        ld      BC,     $00B4
@_2:    push    BC

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        pop     BC
        dec     BC
        ld      A,      B
        or      C
        ret     z

        bit     5,      [IY+Vars.joypad]
        jp      nz,     @_2

        and     A
        ret

        ;-----------------------------------------------------------------------
@_3:    ld      HL,     @_14de
        ld      C,      $0B
        call    _16d9
        ld      HL,     @_14e6
        call    print
        ld      HL,     @_14f1
        call    print

        ld      A,      $09
        ld      [RAM_D216],     A

@_4:    ld      B,      $3C
@_5:    push    BC

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       $00
        ld      HL,     RAM_D216
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $01
        call    _1b13

        ex      DE,     HL

        ld      HL,     RAM_SPRITETABLE
        ld      C, 140
        ld      B, 94
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        pop     BC
        bit     5,      [IY+Vars.joypad]
        jr      z,      @_6

        djnz    @_5

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_1A
                rst     $28     ;=rst_playSFX
        .ENDIF

        ld      HL,     RAM_D216
        ld      A,      [HL]
        and     A
        ret     z

        dec     [HL]
        jr      @_4

        ;get the bit flag for the level
@_6:    ld      HL,     RAM_D311
        call    getLevelBitFlag
        ld      A,      C
        cpl                                                     ;invert the level bits (create a mask)
        ld      C,      A

        ld      A,      [HL]
        and     C                                               ;remove the level bit
        ld      [HL],   A

        ld      HL,     RAM_D284
        dec     [HL]
        scf                                                     ;set carry flag

        ret

        ;-----------------------------------------------------------------------


@_14de: .BYTE   $0F $80 $81 $FF                                         ;$14DE
        .BYTE   $10 $90 $91 $FF
@_14e6: ; text                                                          ;$14E6
        .BYTE   $08 $0C $67 $68 $69 $6A $6B $6C $6D $6E $FF
@_14f1: ; text                                                          ;$14F1
        .BYTE   $08 $0D $77 $78 $79 $7A $7B $7C $7D $7E $FF

@_14fc: ; this first bit looks like a palette                           ;$14FC
        .BYTE   $00 $01 $06 $0B $04 $08 $0C $3D $1F $39 $2A $14 $14 $27 $00 $3F
        .BYTE   $00 $20 $35 $1B $16 $2A $00 $3F $03 $0F $01 $15 $00 $3C $00 $3F

        .BYTE   $01 $00 $00 $00 $00 $00 $00 $00 $01 $00 $00 $00 $05 $00 $00 $00
        .BYTE   $10 $00 $00 $00 $30 $00 $00 $00 $50 $00 $00 $01 $00 $00 $00 $03
        .BYTE   $00 $00 $05 $00 $03 $00 $02 $30 $02 $00 $01 $30 $01 $00 $00 $30
        .BYTE   $00 $00 $1E $15 $22 $15 $26 $15 $2A $15 $2E $15 $32 $15 $36 $15
        .BYTE   $3A $15
        ;

_155e:                                                                  ;$155E
;===============================================================================
; Act Complete screen?
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      19
        jp      z,      _172f

        ld      A,      [RAM_VDPREGISTER_1]
        and     %10111111
        ld      [RAM_VDPREGISTER_1],    A

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ;load HUD sprites
        ld      HL,     $B92E
        ld      DE,     $3000
        ld      A,      9
        call    decompressArt

        ;level complete screen tile set
        ld      HL,     $351f
        ld      DE,     $0000
        ld      A,      9
        call    decompressArt

        ;load page 1 ($4000-$7FFF) with bank 5 ($14000-$17FFF)
        ld      A,      5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;UNKNOWN
        ld      HL,     $612E
        ld      BC,     $00BB
        ld      DE,     SMS_VRAM_SCREEN
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      28                                              ;special stage?
        jr      c,      @_1

        ;UNKNOWN
        ld      HL,     $61E9                                   ;$161E9?
        ld      BC,     $0095
        ld      DE,     SMS_VRAM_SCREEN

@_1:    xor     A
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ld      HL,     _1711
        ld      C,      $10
        ld      A,      [RAM_D27F]
        and     A
        call    nz,     _16d9

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1C
        jr      nc,     @_3

        ld      A,      $15
        ld      [RAM_LAYOUT_BUFFER],    A
        ld      A,      $04
        ld      [RAM_LAYOUT_BUFFER+1],  A
        ld      A,      [RAM_CURRENT_LEVEL]
        ld      E,      A
        ld      D,      $00
        ld      HL,     _1b69
        add     HL,     DE
        ld      E,      [HL]
        ld      HL,     _1b51
        add     HL,     DE
        ld      B,      $04

@_2:    push    BC
        push    HL
        ld      DE,     RAM_LAYOUT_BUFFER+1
        ld      A,      [DE]
        inc     A
        ld      [DE],   A
        inc     DE
        ldi
        ldi
        ld      A,      $FF
        ld      [DE],   A
        ld      HL,     RAM_LAYOUT_BUFFER
        call    print
        pop     HL
        pop     BC
        inc     HL
        inc     HL
        djnz    @_2

@_3:    xor     A
        ld      [RAM_VDPSCROLL_HORZ],   A
        ld      [RAM_VDPSCROLL_VERT],   A
        ld      HL,     actComplete_Palette
        ld      A,      %00000011
        call    loadPaletteOnInterrupt
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1C
        jr      c,      @_4

        ld      HL,     $D281
        inc     [HL]
        bit     2,      [IY+Vars.flags9]
        jr      nz,     @_4

        ld      HL,     $D282
        inc     [HL]
        ld      HL,     RAM_D285
        inc     [HL]

@_4:    bit     2,      [IY+Vars.flags9]
        call    nz,     _1719

        bit     3,      [IY+Vars.flags9]
        call    nz,     _1726

        ld      HL,     $153E
        ld      DE,     $154E
        ld      B,      $08

@_5:    ld      A,      [RAM_TIME_MINUTES]
        cp      [HL]
        jr      nz,     @_6

        inc     HL
        ld      A,      [RAM_TIME_SECONDS]
        cp      [HL]
        jr      nc,     @_8

        inc     HL
        jr      @_7
@_6:    jr      nc,     @_8

        inc     HL
        inc     HL
@_7:    inc     DE
        inc     DE
        djnz    @_5

        ld      DE,     $151E
        jr      @_9

@_8:    ex      DE,     HL
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
@_9:    ld      HL,     RAM_TEMP4
        ex      DE,     HL
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1C
        jr      c,      @_10

        ld      HL,     _1a14
@_10:   ldi
        ldi
        ldi
        ldi
        set     1,      [IY+Vars.flags0]
        ld      B,      $78

@_11:   push    BC
        ld      A,      [RAM_VDPREGISTER_1]
        or      $40
        ld      [RAM_VDPREGISTER_1],    A

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        call    _1a18
        pop     BC
        djnz    @_11

@_12:   res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        call    _1a18
        call    _19b4
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      28
        call    c,      _19df
        ld      A,      [RAM_D216]
        inc     A
        ld      [RAM_D216],     A
        and     $03
        jr      nz,     @_13

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_02
                rst     $28     ;=rst_playSFX
        .ENDIF

@_13:   ld      HL,     [RAM_TEMP4]
        ld      DE,     [RAM_TEMP6]
        ld      A,      [RAM_RINGS]
        or      H
        or      L
        or      D
        or      E
        jp      nz,     @_12

        ld      B,      $B4

@_14:   push    BC

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        call    _1a18
        pop     BC
        bit     5,      [IY+Vars.joypad]
        jr      z,      @exit
        djnz    @_14

@exit:  ret
        ;

_16d9:                                                                  ;$16D9
;===============================================================================
        ld      B,      A
        push    BC
        ld      DE,     RAM_LAYOUT_BUFFER
        srl     A
        ld      B,      A
        ld      A,      C
        sub     B
        ld      [DE],   A
        inc     DE
        ld      BC,     $0004
        ldir
        ld      [DE],   A
        inc     DE
        ld      BC,     $0004
        ldir
        pop     BC
        xor     A
        ld      [RAM_TEMP1],    A

@loop:  push    BC
        ld      HL,     RAM_LAYOUT_BUFFER
        call    print
        ld      HL,     RAM_D2C3
        call    print
        ld      HL,     RAM_LAYOUT_BUFFER
        inc     [HL]
        inc     [HL]
        ld      HL,     RAM_D2C3
        inc     [HL]
        inc     [HL]
        pop     BC
        djnz    @loop

        ret
        ;

_1711:                                                                  ;$1711
;===============================================================================

        .BYTE   $14 $AD $AE $FF
        .BYTE   $15 $BD $BE $FF
        ;

_1719:                                                                  ;$1719
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        xor     A                       ; set A to 0
        ld      [RAM_RINGS],    A       ; set ring-count to 0

        res     3,      [IY+Vars.flags9]
        res     2,      [IY+Vars.flags9]

        ret
        ;

_1726:                                                                  ;$1726
;===============================================================================
; called by Act Complete screen?
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      HL,     RAM_D284
        inc     [HL]
        res     3,      [IY+Vars.flags9]
        ret
        ;

_172f:                                                                  ;$172F
;===============================================================================
; jumped to from $155E

        ; when adding the final bonuses, don't
        ; award an extra life for every 5 thousand
        ld      A,      $FF
        ld      [RAM_SCORE_1UP],        A

        ld      C,      $00
        ld      A,      [RAM_D27F]
        cp      $06
        jr      c,      @_1

        ld      C,      $05
@_1:    ld      A,      [RAM_D280]
        cp      $12
        jr      c,      @_2

        ld      A,      C
        add     A,      $05
        daa
        ld      C,      A
@_2:    ld      A,       [$D281]
        cp      $08
        jr      c,      @_3

        ld      A,      C
        add     A,      $05
        daa
        ld      C,      A
@_3:    ld      A,       [$D282]
        cp      $08
        jr      c,      @_4

        ld      A,      C
        add     A,      $05
        daa
        ld      C,      A
@_4:    ld      A,      [RAM_D283]
        and     A
        jr      nz,     @_5

        ld      A,      C
        add     A,      $0A
        daa
        ld      C,      A
@_5:    ld      A,      C
        cp      $30
        jr      nz,     @_6

        ld      A,      C
        add     A,      $0A
        daa
        add     A,      $0A
        daa
        ld      C,      A
@_6:    ld      HL,     RAM_D2FF
        ld      [HL],   C
        inc     HL
        ld      [HL],   $00
        inc     HL
        ld      [HL],   $00
        ld      HL,     _1907
        call    print
        ld      HL,     _191c
        call    print
        ld      HL,     _1931
        call    print
        ld      HL,     _1946
        call    print
        ld      HL,     _1953
        call    print
        ld      HL,     _1960
        call    print
        ld      HL,     _196d
        call    print
        ld      HL,     _197e
        call    print
        xor     A
        ld      [RAM_D216],     A
        ld      BC,     $00B4
        call    _1860

@_7:    ld      BC,     $003C
        call    _1860
        ld      A,      [RAM_D27F]
        and     A
        jr      z,      @_8

        dec     A
        ld      [RAM_D27F],     A

        ld      DE,    $0000
        ld      C,    $02
        call    increaseScore

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_02
                rst     $28     ;=rst_playSFX
        .ENDIF

        jp      @_7

@_8:    ld      BC,     $00B4
        call    _1860
        ld      A,      $01
        ld      [RAM_D216],     A
        ld      HL,     _198e
        call    print
        ld      BC,     $00B4
        call    _1860

@_9:    ld      BC,     $001E
        call    _1860
        ld      A,      [RAM_LIVES]
        and     A
        jr      z,      @_10
        dec     A
        ld      [RAM_LIVES],    A

        ld      DE,    $5000
        ld      C,    $00
        call    increaseScore

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_02
                rst     $28     ;=rst_playSFX
        .ENDIF

        jp      @_9

@_10:   ld      BC,     $00B4
        call    _1860
        ld      A,      $02
        ld      [RAM_D216],     A
        ld      HL,     _199e
        call    print
        ld      HL,     _197a
        call    print
        ld      BC,     $00B4
        call    _1860

@_11:   ld      BC,     $001E
        call    _1860
        ld      A,      [RAM_D2FF]
        and     A
        jr      z,      @_13

        dec     A
        ld      C,      A
        and     $0F
        cp      $0A
        jr      c,      @_12

        ld      A,      C
        sub     $06
        ld      C,      A
@_12:   ld      A,      C
        ld      [RAM_D2FF],     A

        ld      DE,    $0000
        ld      C,    $01
        call    increaseScore

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_02
                rst     $28     ;=rst_playSFX
        .ENDIF

        jp      @_11

@_13:   ld      BC,     $01E0
        call    _1860
        ret
        ;

_1860:                                                                  ;$1860
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        push    BC

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       $00
        ld      HL,     RAM_SPRITETABLE
        ld      [RAM_SPRITETABLE_ADDR], HL
        ld      HL,     RAM_SCORE_MILLIONS
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $04
        call    _1b13

        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C, 144
        ld      B, 128
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        ld      A,      [RAM_D216]
        and     A
        jr      nz,     @_1
        ld      HL,     RAM_D27F
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $01
        call    _1b13

        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C, 144
        ld      B, 96
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        ld      HL,     _19ae
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $03
        call    _1b13

        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C, 160
        ld      B, 96
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        jr      @_3

@_1:    dec     A
        jr      nz,     @_2
        call    _1aca
        ld      HL,     _19b1
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $03
        call    _1b13

        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C, 160
        ld      B, 96
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        jr      @_3

@_2:    ld      HL,     RAM_D2FF
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $03
        call    _1b13

        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C,      160
        ld      B,      96
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

@_3:    pop     BC
        dec     BC
        ld      A,      B
        or      C
        jp      nz,     _1860
        ret
        ;

;these look like text boxes

_1907:                                                                  ;$1907
;===============================================================================

        .BYTE   $07 $09 $DA $DB $DB $DB $DB $DB $DB $DB $DB $DB $DB $DB $DB $DB
        .BYTE   $DB $DB $DB $DC $FF
        ;

_191c:                                                                  ;$191C
;===============================================================================

        .BYTE   $07 $0A
        .BYTE   $EA $EB $EB $EB $EB $EB $EB $EB $EB $EB $EB $EB $EB $EB $EB $EB $EB $EC
        .BYTE   $FF
        ;

_1931:                                                                  ;$1931
;===============================================================================

        .BYTE   $07 $0B
        .BYTE   $FB $FC $FC $FC $FC $FC $FC $FC $FC $FC $FC $FC $FC $FC $FC $FC $FC $FD
        .BYTE   $FF
        ;

_1946:                                                                  ;$1946
;===============================================================================

        .BYTE   $11 $0B
        .BYTE   $DA $DB $DB $DB $DB $DB $DB $DB $DB $DC
        .BYTE   $FF
        ;

_1953:                                                                  ;$1953
;===============================================================================

        .BYTE   $11 $0C
        .BYTE   $EA $EB $EB $EB $EB $EB $EB $EB $EB $EC
        .BYTE   $FF
        ;

_1960:                                                                  ;$1960
;===============================================================================

        .BYTE   $11 $0D
        .BYTE   $EA $EB $EB $FA $EB $EB $EB $EB $EB $EC
        .BYTE   $FF
        ;

_196d:                                                                  ;$196D
;===============================================================================

        .BYTE   $11 $0E
        .BYTE   $FB $FC $FC $FC $FC $FC $FC $FC $FC $FD
        .BYTE   $FF
        ;

_197a:                                                                  ;$197A
;===============================================================================

        .BYTE   $14 $0D
        .BYTE   $EB
        .BYTE   $FF
        ;

_197e:                                                                  ;$197E
;===============================================================================
        
        ; "CHAOS EMERALD"
        .BYTE   $08 $0A
        .BYTE   $36 $47 $34 $61 $70 $EB $44 $50 $44 $62 $34 $43 $37
        .BYTE   $FF
        ;

_198e:                                                                  ;$198E
;===============================================================================
        
        ; "SONIC LEFT"
        .BYTE   $08 $0A
        .BYTE   $70 $52 $51 $40 $36 $EB $43 $44 $45 $80 $EB $EB $EB
        .BYTE   $FF
        ;

_199e:                                                                  ;$199E
;===============================================================================
        
        ; "SPECIAL BONUS"
        .BYTE   $08 $0A
        .BYTE   $70 $60 $44 $36 $40 $34 $43 $EB $35 $52 $51 $81 $70
        .BYTE   $FF
        ;

;unknown:
_19ae:                                                                  ;$19AE
;===============================================================================
        
        .BYTE   $02 $00 $00
        ;

_19b1:                                                                  ;$19B1
;===============================================================================

        .BYTE   $00 $50 $00
        ;

_19b4:                                                                  ;$19B4
;===============================================================================
        ld      HL,     RAM_RINGS
        ld      A,      [HL]
        and     A
        ret     z

        dec     A
        ld      C,      A
        and     %00001111
        cp      $0A
        jr      c,      @_1

        ld      A,      C
        sub     $06
        ld      C,      A
@_1:    ld      [HL],   C
        ld      DE,     $0100
        ld      C,      $00
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1C
        jr      c,      @_2

        ld      A,      [RAM_D285]
        ld      D,      A
        ld      A,      [RAM_D286]
        ld      E,      A
@_2:    call    increaseScore
        ret
        ;

_19df:                                                                  ;$19DF
;===============================================================================
        ld      HL,     [RAM_TEMP4]
        ld      DE,     [RAM_TEMP6]
        ld      A,      H
        or      L
        or      D
        or      E
        ret     z

        ld      B,      $03
        ld      HL,     RAM_TEMP6
        scf

@loop:  ld      A,       [HL]
        sbc     A,      $00
        ld      C,      A
        and     $0F
        cp      $0A
        jr      c,      @_1
        ld      A,      C
        sub     $06
        ld      C,      A
@_1:    ld      A,      C
        cp      $A0
        jr      c,      @_2

        sub     $60
@_2:    ld      [HL],   A
        ccf
        dec     HL
        djnz    @loop

        ld      DE,    $0100
        ld      C,    $00
        call    increaseScore

        ret
        ;

_1a14:                                                                  ;$1A14
;===============================================================================
        .BYTE   $00 $00 $00 $00
        ;

_1a18:                                                                  ;$1A18
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      [IY+Vars.spriteUpdateCount],       $00
        ld      HL,     RAM_SPRITETABLE
        ld      [RAM_SPRITETABLE_ADDR], HL
        ld      HL,     RAM_SCORE_MILLIONS
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $04
        call    _1b13

        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C, 136
        ld      B, 80
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        ld      HL,     RAM_RINGS
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $01
        call    _1b13

        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C, 152
        ld      B, 128
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1C
        jr      c,      @_1

        ld      B, 104
@_1:    call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1C
        jr      c,      @_2

        ld      HL,     RAM_D285
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $02
        call    _1b13
        ld      B,      $68
        jr      @_3

@_2:    ld      HL,     $151C
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $02
        call    _1b13
        ld      B,      128
@_3:    ld      C,      192
        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL
        call    _1aca
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1C
        jr      nc,     @_4

        ld      HL,     RAM_TEMP4
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $04
        call    _1b13
        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C,      136
        ld      B,      104
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL
        ret

@_4:    ld      HL,     RAM_D284
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      B,      $01
        call    _1b13
        ex      DE,     HL
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      C,      168
        ld      B,      128
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL
        ret
        ;

_1aca:                                                                  ;$1ACA
;===============================================================================
        ;load number of lives into HL
        ld      A,      [RAM_LIVES]
        ld      L,      A
        ld      H,      $00
        ld      C,      $0A
        call    _LABEL_60F_111

        ld      A,      L
        add     A,      A
        add     A,      $80
        ld      [RAM_LAYOUT_BUFFER],    A
        ld      C,      10
        call    multiply

        ex      DE,     HL
        ld      A,      [RAM_LIVES]
        ld      L,      A
        ld      H,      $00
        and     A
        sbc     HL,     DE
        ld      A,      L
        add     A,      A
        add     A,      $80
        ld      [RAM_LAYOUT_BUFFER+1],  A
        ld      A,      $FF
        ld      [RAM_LAYOUT_BUFFER+2],  A
        ld      C,      $38
        ld      B,      $9F
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $13
        jr      nz,     @_1

        ld      B, 96
        ld      C, 144
@_1:    ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      DE,     RAM_LAYOUT_BUFFER
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL
        ret
        ;

_1b13:                                                                  ;$1B13
;===============================================================================
        ld      A,      [HL]
        and     $F0
        jr      nz,     @_

        ld      A,      $FE
        ld      [DE],   A
        inc     DE
        ld      A,      [HL]
        and     $0F
        jr      nz,     @_1

        ld      A,      $FE
        ld      [DE],   A
        inc     HL
        inc     DE
        djnz    _1b13

        ld      A,      $FF
        ld      [DE],   A
        dec     DE
        ld      A,      $80
        ld      [DE],   A
        ld      HL,     RAM_LAYOUT_BUFFER
        ret

@_:     ld      A,      [HL]
        rrca
        rrca
        rrca
        rrca
        and     $0F
        add     A,      A
        add     A,      $80
        ld      [DE],   A
        inc     DE
@_1:    ld      A,       [HL]
        and     $0F
        add     A,      A
        add     A,      $80
        ld      [DE],   A
        inc     HL
        inc     DE
        djnz    @_
        ld      A,      $FF
        ld      [DE],   A
        ld      HL,     RAM_LAYOUT_BUFFER
        ret
        ;

;UNKNOWN

_1b51:                                                                  ;$1B51
;===============================================================================

        .BYTE   $83 $84 $93 $94 $A3 $A4 $B3 $B4 $85 $86 $95 $96 $A5 $A6 $B5 $B6
        .BYTE   $87 $88 $97 $98 $A7 $A8 $B7 $B8
        ;

_1b69:                                                                  ;$1B69
;===============================================================================

        .BYTE   $00 $08 $10 $00 $08 $10 $00 $08 $10 $00 $08 $10 $00 $08 $10 $00
        .BYTE   $08 $10 $00 $00 $08 $08 $08 $08 $08 $08 $08 $08 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00
        ;

;"Sonic Has Passed" screen palette:

actComplete_Palette:                                                    ;$1B8D
;===============================================================================
        .TABLE  DSB 16
        .ROW    $35 $01 $06 $0B $04 $08 $0C $3D $1F $39 $2A $14 $25 $2B $00 $3F
        .ROW    $35 $20 $35 $1B $16 $2A $00 $3F $01 $03 $3A $06 $0F $00 $00 $00
        ;

_1bad:                                                                  ;$1BAD
;===============================================================================
; Demo playback??
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      HL,     [RAM_D2B5]
        ld      DE,     @_1bc6
        add     HL,     DE
        ld      A,      [HL]
        ld      [IY+Vars.joypad],  A
        ld      A,      [RAM_FRAMECOUNT]
        and     %00011111
        ret     nz

        ld      HL,     [RAM_D2B5]
        inc     HL
        ld      [RAM_D2B5],     HL
        ret

@_1bc6: ; joystick data? (lines are high by default)                    ;$1BC6
        ;-----------------------------------------------------------------------
        .BYTE   $F7 $F7 $F7 $F7 $DF $F7 $FF $FF $D7 $F7 $F7 $F7 $FF $DF $F7 $F7
        .BYTE   $DF $F7 $F7 $F7 $F7 $FF $FF $DF $F7 $FF $FF $FF $FB $F7 $F7 $F5
        .BYTE   $FF $FF $FF $FF $FB $FB $F9 $FF $FF $FF $FF $F7 $F7 $F7 $F7 $D7
        .BYTE   $FF $FF $D7 $FF $FF $FF $FF $FF $FF $FF $D7 $FB $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $D7 $F7 $F7 $FF $D7
        .BYTE   $FB $F7 $F7 $F7 $F7 $FB $FB $F7 $FF $D7 $FB $FF $F7 $F7 $D7 $FB
        .BYTE   $D7 $F7 $F7 $F7 $FF $FF $FF $FF $FF $FF $FF $F7 $F7 $F7 $D7 $FF
        .BYTE   $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $00
        ;

_1c49:                                                                  ;$1C49
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ;set bit 0 of the parameter address (IY=$D200);
        ;`waitForInterrupt` will pause until an interrupt event switches bit 0 of $D200 on
        set     0,      [IY+Vars.flags0]
        ei                                                      ;enable interrupts

        ;default to 3 lives
@_1:    ld      A,              3
        ld      [RAM_LIVES],    A

        ;set the number of thousands of pts per extra life
        ld      A,              SCORE_1UP_PTS
        ld      [RAM_SCORE_1UP],A

        ld      A,              $1C
        ld      [RAM_D23F],     A

        xor     A                               ; set A to 0
        ld      [RAM_CURRENT_LEVEL],    A       ; set starting level!
        ld      [RAM_FRAMECOUNT],       A
        ld      [IY+Vars.unknown_0D],   A

        ld      HL,     RAM_D27F
        ld      B,      $08
        call    fillMemoryWithValue

        ld      HL,     $D200
        ld      B,      $0E
        call    fillMemoryWithValue

        ld      HL,     RAM_SCORE_MILLIONS
        ld      B,      $04
        call    fillMemoryWithValue

        ld      HL,     RAM_D305
        ld      B,      $18
        call    fillMemoryWithValue

        res     0,      [IY+Vars.flags2]
        res     1,      [IY+Vars.flags2]
        call    hideSprites
        call    titleScreen

        res     1,      [IY+Vars.scrollRingFlags]
        jr      c,      @_LABEL_1C9F_104

        set     1,      [IY+Vars.scrollRingFlags]

@_LABEL_1C9F_104:
        ;are we on the end sequence?
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      19
        jr      nc,     @_1

        res     0,      [IY+Vars.flags2]
        res     1,      [IY+Vars.flags2]
        call    hideSprites
        call    _LABEL_C52_106
        bit     1,      [IY+Vars.scrollRingFlags]
        jr      z,      @_LABEL_1CBD_120
        jp      c,      @_1

@_LABEL_1CBD_120:
        call    fadeOut
        call    hideSprites
        bit     0,      [IY+Vars.scrollRingFlags]
        jr      nz,     @_2

        bit     4,      [IY+Vars.flags6]
        jr      nz,     @_3

        ;wait at title screen for button press?
@_2:    ld      B,      $3C

@wait:  res     0,      [IY+Vars.flags0]
        call    waitForInterrupt
        djnz    @wait

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                rst     rst_muteSound
        .ENDIF

@_3:    call    _LABEL_1CED_131
        and     A
        jp      z,      @_1

        dec     A
        jr      z,      @_LABEL_1C9F_104

        jp      @_LABEL_1CBD_120
        ;

fillMemoryWithValue:                                                    ;$1CE8
;===============================================================================
; in    HL      memory address
;       B       number of bytes to fill
;       A       which value to fill with
;-------------------------------------------------------------------------------
        ld      [HL],      A
        inc     HL
        djnz    fillMemoryWithValue

        ret
        ;

_LABEL_1CED_131:                                                        ;$1CED
;===============================================================================
; start level? (could be main gameplay loop)
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; load page 1 (Z80:$4000-$7FFF)
        ; with bank 5 (ROM:$14000-$17FFF)
        ld      A,                      5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ld      A,      [RAM_CURRENT_LEVEL]

        bit     4,      [IY+Vars.flags6]
        jr      z,      @_1

        ld      A,      [RAM_D2D3]

@_1:    add     A,      A               ; double the level number (for an index)
        ld      L,      A               ; put this into a 16-bit number
        ld      H,      $00

        ;the level pointers table begins at $15580 (page 1 $4000 + $1580 remainder)
        ;TODO: must confirm that this gets correctly calculated automatically
        ld      DE,     $5580   ;\\levels\headers                ;=$5580

        add     HL,     DE                                      ;offset into the pointers table
        ld      A,      [HL]                                    ;read the low byte
        inc     HL                                              ;move forward
        ld      H,      [HL]                                    ;read the hi-byte
        ld      L,      A                                       ;add the lo-byte to make 16-bit address

        ;is this a null level? (offset $0000)
        ;the `or H` will set Z if the result is 0, this will only ever happen with $0000
        or      H
        jp      z,      _LABEL_258B_133

        ;add the pointer value to the level pointers table to find the start of the level header
        ;(the level headers begin after the level pointers)
        add     HL,     DE
        call    loadLevel

        set     0,      [IY+Vars.flags2]
        set     1,      [IY+Vars.flags2]
        set     1,      [IY+Vars.flags0]
        set     3,      [IY+Vars.flags6]
        res     3,      [IY+Vars.timeLightningFlags]       ;unknown
        res     0,      [IY+Vars.flags9]
        res     6,      [IY+Vars.flags6]
        res     0,      [IY+Vars.unknown0]
        res     6,      [IY+Vars.flags0]                   ;camera moved left flag

        ;auto scroll right?
        bit     3,      [IY+Vars.scrollRingFlags]
        call    nz,     lockCameraHorizontal       ;prevent the camera from scrolling manually

        ;loop 16 times...
        ;-----------------------------------------------------------------------
        ld      B,      16
@_2:    push    BC

        ;wait one frame
        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.joypad],  $FF                     ;clear joypad input

        ;increase the frame counter
        ld      HL,     [RAM_FRAMECOUNT]
        inc     HL
        ld      [RAM_FRAMECOUNT],       HL

        ;switch page 1 ($4000-$7FFF) to bank 11 ($2C000-$2FFFF)
        ld      A,                      11
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;are rings enabled?
        bit     2,      [IY+Vars.scrollRingFlags]
        call    nz,     animateFloorRing

        ;establish the default zones around the edges of the screen which initiate scrolling.
        ;mobs can provide a temporary override to this
        ld      HL,                     $0060                   ;=96
        ld      [RAM_SCROLLZONE_LEFT],  HL

        ld      HL,                     $0088                   ;=136
        ld      [RAM_SCROLLZONE_RIGHT], HL

        ld      HL,                     $0060                   ;=96
        ld      [RAM_SCROLLZONE_TOP],   HL

        ld      HL,                     $0070                   ;=112
        ld      [RAM_SCROLLZONE_BOTTOM],HL

        ;animate ring?
        call    _239c

        ;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        call    refresh
        call    updateVDPscroll
        call    fillOverscrollCache

        set     5,      [IY+Vars.flags0]

        pop     BC
        djnz    @_2

        ;-----------------------------------------------------------------------

        ;demo mode?
        bit     1,      [IY+Vars.scrollRingFlags]
        jr      z,      @_1dae

        ld      HL,     $0000
        ld      [RAM_D2B5],     HL
        ld      [IY+Vars.spriteUpdateCount],       H

@_1dae: res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ;switch page 1 ($4000-$7FFF) to bank 11 ($2C000-$2FFFF)
        ld      A,                      11
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;are rings enabled?
        bit     2,      [IY+Vars.scrollRingFlags]
        call    nz,     animateFloorRing

        bit     3,      [IY+Vars.flags6]
        call    nz,     updateTime

        ;every other frame?
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        jr      nz,     @_3

        ld      A,      [RAM_D289]
        and     A
        call    nz,     _1fa9

        jr      @_4

        ;-----------------------------------------------------------------------

@_3:    ld      A,       [RAM_D287]
        and     A
        jp      nz,     _2067
@_1de2:                                                         ;jump to here from _2067
        ld      A,      [RAM_D2B1]
        and     A
        call    nz,     _1f06

        ;is lightning effect enabled?
        bit     1,      [IY+Vars.timeLightningFlags]
        call    nz,     _1f49                                   ;if so, handle that

@_4:    bit     1,      [IY+Vars.flags6]
        call    nz,     @_7

        ;are we in demo mode?
        bit     1,      [IY+Vars.scrollRingFlags]
        jr      z,      @_5                                     ;no, skip ahead

        bit     5,      [IY+Vars.joypad]                   ;is button pressed?
        jp      z,      _20b8                                   ;if yes, end demo mode

        call    _1bad                                           ;process demo mode?

        ;increase the frame counter
@_5:    ld      HL,      [RAM_FRAMECOUNT]
        inc     HL
        ld      [RAM_FRAMECOUNT],       HL

        ;auto scrolling to the right? (ala Bridge 2)
        bit     3,      [IY+Vars.scrollRingFlags]
        call    nz,     autoscrollRight

        ;auto scrolling upwards?
        bit     4,      [IY+Vars.scrollRingFlags]
        call    nz,     autoscrollUp

        ;no down scrolling (ala Jungle 2)
        bit     7,      [IY+Vars.scrollRingFlags]
        call    nz,     dontScrollDown

        call    _23c9

        ;are rings enabled?
        bit     2,      [IY+Vars.scrollRingFlags]
        call    nz,     _239c

        xor     A                                          ;set A to 0
        ld      [RAM_D302],     A
        ld      [RAM_D2DE],     A

        ld      [IY+Vars.spriteUpdateCount],       $15
        ld      HL,                     $D03F                   ;lives icon sprite table entry
        ld      [RAM_SPRITETABLE_ADDR], HL

        ld      HL,     RAM_SPRITETABLE+1                           ;sprite Y-value
        ld      B,      $07
        ld      DE,     $0003
        ld      A,      $E0

@_6:    ld      [HL],   A
        add     HL,     DE
        ld      [HL],   A
        add     HL,     DE
        ld      [HL],   A
        add     HL,     DE
        djnz    @_6

        ;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        call    refresh
        call    updateVDPscroll
        call    fillOverscrollCache

        ld      HL,     RAM_VDPREGISTER_1
        set     6,      [HL]

        ;paused?
        bit     3,      [IY+Vars.timeLightningFlags]
        call    nz,     _1e9e

        jp      @_1dae

        ;-----------------------------------------------------------------------

@_7:    ld      [IY+Vars.joypad],       $F7
        ld      HL,     [RAM_LEVEL_LEFT]
        ld      DE,     $0112
        add     HL,     DE
        ex      DE,     HL
        ld      HL,     [RAM_SONIC.X]

        xor     A                                          ;set A to 0
        sbc     HL,     DE
        ret     c

        ld      [IY+Vars.joypad],  $FF

        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A

        ret
        ;

_1e9e:                                                                  ;$1E9E
;===============================================================================
; demo mode?
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        bit     1,      [IY+Vars.scrollRingFlags]
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                rst     rst_muteSound
        .ENDIF

@_1:    ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       A

        ld      A,                      11
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;are rings enabled?
        bit     2,      [IY+Vars.scrollRingFlags]
        call    nz,     animateFloorRing
        call    _23c9
        call    _239c
        ;paused?
        bit     3,      [IY+Vars.timeLightningFlags]
        jr      nz,     @_1

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,                      :sound.unpause
                ld      [SMS_MAPPER_SLOT1],     A
                ld      [RAM_SLOT1],            A
                call    sound.unpause
        .ENDIF

        ret
        ;

lockCameraHorizontal:                                                   ;$1ED8
;===============================================================================
; lock the screen -- prevents the screen scrolling left or right
; (i.e. during boss battles)
;-------------------------------------------------------------------------------
        ld      HL,     [RAM_CAMERA_X]
        ld      [RAM_LEVEL_LEFT],       HL
        ld      [RAM_LEVEL_RIGHT],      HL
        ret
        ;

autoscrollRight:                                                        ;$1EE2
;===============================================================================
; move the left-hand side of the level across -- i.e. Bridge Act 2
;-------------------------------------------------------------------------------
        ld      A,      [RAM_FRAMECOUNT]
        rrca
        ret     nc

        ;increase the left hand crop by a pixel
        ld      HL,     [RAM_LEVEL_LEFT]
        inc     HL
        ld      [RAM_LEVEL_LEFT],       HL
        ;prevent scrolling to the right by limiting the width of the level to the same
        ;NOTE: removing this would allow the player to continue running right, but not return left beyond a moving
        ;      point -- this would be useful for some kind of chase scene (i.e. wall of lava)
        ld      [RAM_LEVEL_RIGHT],      HL
        ret
        ;

autoscrollUp:                                                           ;$1EF2
;===============================================================================
; autoscroll upwards -- unused by the game, but working
;-------------------------------------------------------------------------------
        ;ensure there's a pause before starting to scroll upwards, otherwise the player won't have time to react!
        ld      A,      [RAM_FRAMECOUNT]
        rrca
        ret     nc

        ;shift the bottom of the level up one pixel
        ld      HL,     [RAM_LEVEL_BOTTOM]
        dec     HL
        ld      [RAM_LEVEL_BOTTOM],     HL
        ret
        ;

dontScrollDown:                                                         ;$1EFF
;===============================================================================
; Fixes the bottom of the level to the current screen position,
; i.e. Jungle Act 2
;-------------------------------------------------------------------------------
        ld      HL,     [RAM_CAMERA_Y]
        ld      [RAM_LEVEL_BOTTOM],     HL
        ret
        ;


_1f06:                                                                  ;$1F06
;===============================================================================
        dec     A
        ld      [RAM_D2B1],     A
        ld      E,      A

        di
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ld      E,      $00
        ld      A,      [RAM_D2B1+1]
        ld      HL,     [RAM_LOADPALETTE_TILE]
        and     A
        jp      p,      @_1

        and     $7F
        ld      HL,     [RAM_LOADPALETTE_SPRITE]
        ld      E,      $10
@_1:    ld      C,      A
        ld      B,      $00
        add     HL,     BC
        add     A,      E
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      %11000000
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      [RAM_D2B1]
        and     %00000001
        ld      A,      [HL]
        jr      z,      @_2

        ld      A,      [RAM_D2B3]

@_2:    out     [SMS_PORTS_VDP_DATA],   A

        ei
        ret
        ;

_1f49:                                                                  ;$1F49
;===============================================================================
        ;lightning is enabled...

        ld      DE,     [RAM_D2E9]
        ld      HL,     $00AA
        xor     A
        sbc     HL,     DE
        jr      nc,     @_1

        ld      BC,     _1f9d
        ld      E,      A
        ld      D,      A
        jp      @_3

@_1:    ld      BC,     _1fa5
        ld      HL,     $0082
        sbc     HL,     DE
        jr      z,      @_2

        ld      BC,     $1FA1
        ld      HL,     $0064
        sbc     HL,     DE
        jr      z,      @_3

        ld      BC,     $1f9d
        ld      A,      E
        or      D
        jr      z,      @_3
        jp      @_4

@_2:    push    BC

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_13
                rst     $28     ;=rst_playSFX
        .ENDIF

        pop     BC

@_3:    ld      HL,     RAM_CYCLEPALETTE_COUNTER
        ld      A,      [BC]
        ld      [HL],   A
        inc     HL
        ld      [HL],   A
        inc     HL
        inc     BC
        ld      [HL],   $00
        inc     HL
        ld      A,      [BC]
        ld      [HL],   A
        inc     BC
        ld      A,      [BC]
        ld      L,      A
        inc     BC
        ld      A,      [BC]
        ld      H,      A
        ld      [RAM_CYCLEPALETTE_POINTER],     HL
@_4:    inc     DE
        ld      [RAM_D2E9],     DE
        ret
        ;

;lightning palette control:

_1f9d:                                                                  ;$1F9D
;===============================================================================
        .TABLE  DSB 2   WORD
        .ROW    $02 $04 paletteData@skyBase_cycles
        ;

_1fa1:                                                                  ;$1FA1
;===============================================================================
        .TABLE  DSB 2   WORD
        .ROW    $02 $04 paletteData@skyBase_cycles_Lightning1
        ;

_1fa5:                                                                  ;$1FA5
;===============================================================================
        .TABLE  DSB 2   WORD
        .ROW    $02 $04 paletteData@skyBase_cycles_Lightning2
        ;

_1fa9:                                                                  ;$1FA9
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        dec     A
        ld      [RAM_D289],     A
        jr      z,      @_1

        cp      $88
        ret     nz

        ;-----------------------------------------------------------------------

        ;an action to take, according to table _2033?
        ld      A,      [RAM_D288]
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     _2023
        add     HL,     DE
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        or      H
        ret     z

        jp      [HL]

        ;-----------------------------------------------------------------------

@_1:    call    fadeOut

        pop     HL
        res     5,      [IY+Vars.flags0]
        bit     2,      [IY+Vars.unknown_0D]
        jr      nz,     @_4

        bit     4,      [IY+Vars.flags6]
        jr      nz,     @_5

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                rst     rst_muteSound
        .ENDIF

        bit     7,      [IY+Vars.flags6]
        call    nz,     _20a4

        call    hideSprites
        call    _155e                                           ;Act Complete screen?

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $1A     ; TODO: which level?
        jr      nc,     @_3

        bit     0,      [IY+Vars.timeLightningFlags]
        jr      z,      @_2

        ld      HL,     $2047   ; TODO: what is this?
        call    _b60
        ld      A,      [RAM_CURRENT_LEVEL]
        push    AF
        ld      A,      [RAM_D23F]
        ld      [RAM_CURRENT_LEVEL],    A
        inc     A
        ld      [RAM_D23F],     A
        call    _LABEL_1CED_131
        pop     AF
        ld      [RAM_CURRENT_LEVEL],    A
@_2:    ld      HL,     RAM_CURRENT_LEVEL                           ;note use of HL here
        inc     [HL]
        ld      A,      $01
        ret

@_3:    res     0,      [IY+Vars.timeLightningFlags]
        ld      A,      $FF
        ret

@_4:    ld      HL,     RAM_CURRENT_LEVEL                           ;note use of HL here
        inc     [HL]
@_5:    ld      A,      $FF

        ret
;

_2023:                                                                  ;$2023
;===============================================================================
        .ADDR   $0000
        .ADDR   _202d
        .ADDR   addExtraLife
        .ADDR   add10Rings
        .ADDR   _203f
        ;

_202d:                                                                  ;$202D
;===============================================================================
; TODO: should be a macro so as to exclude entirely without sound

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_0E
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

addExtraLife:                                                           ;$2031
;===============================================================================
        ;increases lives
        ld      HL,     RAM_LIVES
        inc     [HL]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_09       ; extra life sound?
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

add10Rings:                                                             ;$2039
;===============================================================================
        ;add 10 rings to the ring counter
        ld      A,      $10
        call    increaseRings
        ret
        ;

_203f:                                                                  ;$203F
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_07
                rst     $28     ;=rst_playSFX
        .ENDIF

        set     0,      [IY+Vars.timeLightningFlags]

        ret
        ;

_2047:                                                                  ;$2047
;===============================================================================

        .BYTE   $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F
        .BYTE   $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F $7F
        ;

_2067:                                                                  ;$2067
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        dec     A
        ld	    [RAM_D287],     A
        jp      nz, _LABEL_1CED_131@_1de2
	
        ;demo mode?
        bit     1,  [IY+Vars.scrollRingFlags]
        jr	    nz, _20b8
        bit	    4,  [IY+Vars.origFlags6]
        jr	    z,  +
        set	    4,  [IY+Vars.flags6]
+	    bit	    7,  [IY+Vars.flags6]
        call	nz, _20a4
        ld	    A,  [RAM_LIVES]
        and	    A
        ld	    A,  $02
        ret	    nz
	
        call	fadeOut
        call	hideSprites
        res	    5,  [IY+Vars.flags0]
        call	_1401
        ld	    A,  $00
        ret	nc
	
        ld	    A,  $03
        ld	    [RAM_LIVES],    A
        ld	    A,  $01
        ret

_20a4:                                                                  ;$20A4
;===============================================================================
        ; wait until the water raster effect has finished its work
        ; (it requires three interrupts to produce)
        ld      A,      [RAM_RASTERSPLIT_STEP]
        and     A
        jr      nz,     _20a4

        di

        res     7,      [IY+Vars.flags6]                   ;underwater?

        xor     A                                          ;set A to 0
        ld      [RAM_RASTERSPLIT_LINE], A
        ld      [RAM_WATERLINE],        A

        ei
        ret
        ;

_20b8:                                                                  ;$20B8
;===============================================================================
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,                      :sound.fadeOut
                ld      [SMS_MAPPER_SLOT1],     A
                ld      [RAM_SLOT1],            A
        .ENDIF

        ld      HL,     $0028

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                call    sound.fadeOut
        .ENDIF

        call    fadeOut

        xor     A
        ret
        ;

loadLevel:                                                              ;$20CB
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;       HL      Address of the level header
;-------------------------------------------------------------------------------
        ;PAGE 1 ($4000-$7FFF) is at BANK 5 ($14000-$17FFF)

        ld      A,      [RAM_VDPREGISTER_1]
        and     %10111111                                       ;remove bit 6
        ld      [RAM_VDPREGISTER_1],    A

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ;copy the level header from ROM to RAM starting at $D354
        ;(this copies 40 bytes, even though level headers are 37 bytes long.
        ;the developers probably removed header bytes later in development)
        ld      DE,     RAM_LEVEL_HEADER
        ld      BC,     40
        ldir

        ld      HL,     RAM_LEVEL_HEADER                    ;position HL at the start of the header
        push    HL                                       ;remember the start point

        ;read the current Scrolling / Ring HUD value
        ld      A,      [IY+Vars.scrollRingFlags]          ;take a copy
        ld      [IY+Vars.origScrollRingFlags],     A
        ld      A,      [IY+Vars.flags6]                   ;read the current underwater flag value
        ld      [IY+Vars.origFlags6],      A               ;take a copy

        ld      A,              $FF
        ld      [RAM_D2AB],     A

        ;clear some variables
        xor     A                                          ;set A to 0
        ld      L, A                                  ;set HL to #$0000
        ld      H, A
        ld      [RAM_VDPSCROLL_HORZ],   A
        ld      [RAM_VDPSCROLL_VERT],   A
        ld      [RAM_CAMERA_X_GOTO],    HL
        ld      [RAM_CAMERA_Y_GOTO],    HL
        ld      [RAM_D2B7],             HL
        ld      [RAM_RASTERSPLIT_STEP], A
        ld      [RAM_RASTERSPLIT_LINE], A

        ;clear D287-$D2A4 (29 bytes)
        ld      HL,     RAM_D287
        ld      B,      29
        call    fillMemoryWithValue

        ;get the bit flag for the level:
        ;C returns a byte with bit x set, where x is the level number mod 8
        ;DE will be the level number divided by 8
        ;HL will be D311 + the level number divided by 8
        ld      HL,     RAM_D311
        call    getLevelBitFlag

        ;DE will now be D311 + the level number divided by 8
        ex      DE,     HL

        ld      HL,     $0800
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      9
        jr      c,      @_2                                     ;less than level 9? (Labyrinth Act 1)

        cp      11
        jr      z,      @_1                                     ;if level 11 (Labyrinth Act 3)
        jr      nc,     @_2                                     ;if >= level 11 (Labyrinth Act 3)

        ;this must be level 9 or 10 (Labyrinth Act 1/2)
        ld      A,      [DE]
        and     C                                               ;is the bit for the level set?
        jr      z,      @_2                                     ;if so, skip this next part

@_1:    ld      A,              $FF
        ld      [RAM_WATERLINE],A

        ld      HL,     $0020

@_2:    ld      [RAM_D2DC],     HL      ; either $0800 or $0020

        ld      HL,     $FFFE

        ld      [RAM_TIME],     HL
        ld      HL,     $23FF

        bit     4,      [IY+Vars.flags6]
        jr      z,      @_3

        bit     0,      [IY+Vars.scrollRingFlags]
        jr      z,      @_5

        ld      HL,     _2402

        ;set number of collected rings to 0
@_3:    xor     A                                          ;set A to 0
        ld      [RAM_RINGS],    A

        ;is this a special stage? (level number 28+)
        ;TODO: this should be based on header, not level number
        ld      A,      [RAM_CURRENT_LEVEL]
        sub     28
        jr      c,      @_4                                     ;skip ahead if level < 28

        ;triple the level number for a lookup table of 3-bytes each entry
        ld      C,      A
        add     A,      A
        add     A,      C
        ld      E,      A
        ld      D,      $00
        ld      HL,     _2405
        add     HL,     DE

        ;copy 3 bytes from HL (`_2402` for regular levels, `_2405`+ for special stages) to D2CE/F/D0
        ;set the level time?
@_4:    ld      DE,     RAM_TIME_MINUTES
        ld      BC,     $0003
        ldir

@_5:    ;load HUD sprite set
        ld      HL,     $B92E           ;=$2F92E
        ld      DE,     $3000
        ld      A,      9
        call    decompressArt

        ;begin reading the level header:

        pop     HL                                       ;get back the level header address
        ;SP: Solidity Pointer
        ;-----------------------------------------------------------------------
        ld      A,      [HL]
        ld      [RAM_LEVEL_SOLIDITY],   A
        inc     HL

        ;FW: Floor Width
        ;-----------------------------------------------------------------------
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_LEVEL_FLOORWIDTH], DE

        ;FH: Floor Height
        ;-----------------------------------------------------------------------
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_LEVEL_FLOORHEIGHT],DE

        ;copy the next 8 bytes to $D273+
        ;-----------------------------------------------------------------------
        ;$D273/4 - LX: Level X Offset
        ;$D275/6 - LW: Level Width
        ;$D277/8 - LY: Level Y Offset
        ;$D279/A - LH: Level Height
        ld      DE,     RAM_LEVEL_LEFT
        ld      BC,     8
        ldir

        ;player start position:
        ;-----------------------------------------------------------------------
        ;currently HL will be sitting on byte 14 ("SX") of the level header
        push    HL
        push    HL

        ;get the level bit flag:
        ;C returns a byte with bit x set, where x is the level number mod 8
        ;DE will be the level number divided by 8
        ;HL will be D311 + the level number divided by 8
        ld      HL,     RAM_D311
        call    getLevelBitFlag

        ld      A,      [HL]
        ex      DE,     HL                                      ;DE will now be D311+

        ;return to the "SX" byte in the level header,
        ;A will have been set from D311+
        pop     HL

        and     c
        jr      z,      @_6

        cpl                                                     ;NOT A
        ld      C,      A
        ld      A,      [DE]                                    ;Set A to the value at D311+0-7
        and     C                                               ;unset the level bit
        ld      [DE],   A

        ;copy 3 bytes from $2402 to D2CE, these will be $01, $30 & $00
        ;(set level time?)
        ld      HL,     _2402
        ld      DE,     RAM_TIME_MINUTES
        ld      BC,     $0003
        ldir

        ld      A,      [RAM_CURRENT_LEVEL]                         ;get current level number
        add     A,      A                                       ;double it (i.e. for 16-bit tables)
        ld      E,      A                                       ;put it into DE
        ld      D,      $00

        ld      HL,     RAM_D32E
        add     HL,     DE                                      ;D32E + (level number * 2)

        ;NOTE: since other data in RAM begins at $D354 (a copy of the level header)
        ;this places a limit -- 19 -- on the number of main levels.
        ;special stages and levels visited by teleporter are not included -- AFAIK

        ;set starting X position:

@_6:    ld      [RAM_D216],     HL
        ld      A,      [HL]                                    ;get the value at that RAM address

        ;if the value is less than 3, just use 0
        ;(this is so that if the player starting position is at the left of the level,
        ; it doesn't try and place the camera before the level's left edge)
        sub     3
        jr      nc,     @_7

        xor     A                                          ;set A to 0
@_7:    ld      [RAM_BLOCK_X],  A

        ;using the number as the hi-byte, divide by 8 into DE
        ;e.g.
        ;4     A: 00000100 E: 00000000 (1024) -> A: 00000000 E: 10000000 (128)
        ;5     A: 00000101 E: 00000000 (1280) -> A: 00000000 E: 10100000 (160)
        ;6     A: 00000110 E: 00000000 (1536) -> A: 00000000 E: 11000000 (192)
        ;7     A: 00000111 E: 00000000 (1792) -> A: 00000000 E: 11100000 (224)
        ;8     A: 00001000 E: 00000000 (2048) -> A: 00000001 E: 00000000 (256)
        
        ;as you can see, the effective outcome is multiplying by 32!
        ld      E,      $00
        rrca
        rr      E
        rrca
        rr      E
        rrca
        rr      E
        and     %00011111                                       ;mask off top 3 bits from the rotation
        ld      D,      A
        ld      [RAM_CAMERA_X],         DE
        ld      [RAM_CAMERA_X_PREV],    DE

        ;set starting Y position:

        inc     HL
        ld      A,      [HL]

        sub     3
        jr      nc,     @_8

        xor     A                                          ;set A to 0

@_8:    ld      [RAM_BLOCK_Y],  A
        ld      E,      $00
        rrca
        rr      E
        rrca
        rr      E
        rrca
        rr      E
        and     %00011111                                       ;mask off top 3 bits from the rotation
        ld      D,      A
        ld      [RAM_CAMERA_Y],         DE
        ld      [RAM_CAMERA_Y_PREV],    DE

        ;return to the "SX" byte in the level header
        pop     HL
        inc     HL                                              ;skip over "SX"
        inc     HL                                              ;and "SY"

        ;since we skip Sonic's X/Y position, where do these get used?
        ;assumedly from the level header copied to RAM at $D354+?

        ;load floor layout:
        ;-----------------------------------------------------------------------
        ;FL: Floor Layout address
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL

        ;FS: Floor Size (in bytes)
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL

        ;remember our place in the level header,
        ;we're currently sitting at the "BM" Block Mapping bytes
        push    HL

        ex      DE,     HL                                      ;HL will be the Floor Layout address
        ld      A,      H                                       ;look at the hi-byte of the FloorLayout
        di                                                      ;disable interrupts
        cp      $40                                             ;is it $40xx or above?
        jr      c,      @_9

        sub     $40
        ld      H,      A

        ld      A,                      6
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      7
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A
        jr      @_10

@_9:    ld      A,                      5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      6
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

@_10:   ei                                                      ;enable interrupts

        ;load the Floor Layout into RAM
        ld      DE,     $4000                                   ;re-base the FloorLayout address to Page 1
        add     HL,     DE
        call    loadFloorLayout

        ;return to our place in the level header
        pop     HL

        ;BM: Block Mapping address
        ;-----------------------------------------------------------------------
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL

        ;swap DE & HL
        ;DE will be current position in the level header
        ;HL will be Block Mapping address
        ex      DE,     HL

        ;rebase the Block Mapping address to Page 1
        ld      BC,     $4000
        add     HL,     BC
        ld      [RAM_BLOCKMAPPINGS],    HL

        ;swap back DE & HL
        ;HL will be current position in the level header
        ex      DE,     HL

        ;LA : Level Art address
        ;-----------------------------------------------------------------------
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL

        ;store the current position in the level header
        push    HL

        ;swap DE & HL
        ;DE will be current position in the level header
        ;HL will be Level Art address
        ex      DE,     HL

        ;load the level art from bank 12+ ($30000)
        ld      DE,     $0000
        ld      A,      12
        call    decompressArt

        ;return to our position in the level header
        pop     HL

        ;sprite art:
        ;-----------------------------------------------------------------------
        ;SB: get the bank number for the sprite art
        ld      A,      [HL]
        inc     HL

        ;SA: Sprite Art address
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ;handle as with Level Art
        push    HL
        ex      DE,     HL
        ld      DE,     $2000
        call    decompressArt
        pop     HL

        ;palettes:
        ;-----------------------------------------------------------------------
        ;IP: Initial Palette
        ld      A,      [HL]

        ;store our current position in the level header
        push    HL

        ;convert the value to 16-bit for a lookup in the palette pointers table
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     $627C
        add     HL,     DE

        ;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
        di
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A
        ei

        ;read the palette pointer into HL
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A

        ;queue the palette to be loaded via the interrupt
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        call    fillScreenWithFloorLayout

        pop     HL
        inc     HL

        ;CS: Cycle Speed
        ld      DE,     RAM_CYCLEPALETTE_COUNTER
        ld      A,      [HL]
        ld      [DE],   A
        inc     DE
        ;store a second copy at the next byte in RAM
        ld      [DE],   A
        inc     DE
        inc     HL
        ;store 0 at the next byte in RAM
        ;(RAM_CYCLEPALETTE_INDEX)
        xor     A                                          ;set A to 0
        ld      [DE],   A
        inc     DE

        ;CC: Colour Cycles
        ld      A,      [HL]
        ld      [DE],   A

        ;CP: Cycle Palette
        inc     HL
        ld      A,      [HL]

        ;swap DE & HL
        ;DE will be current position in the level header
        ex      DE,     HL

        add     A,      A                                       ;double the cycle palette index
        ld      C,      A                                       ;put it into a 16-bit number
        ld      B,      $00
        ;offset into the cycle palette pointers table
        ld      HL,     paletteCyclePointers
        add     HL,     BC

        ;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
        di
        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A
        ei

        ;read the cycle palette pointer
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ld      [RAM_CYCLEPALETTE_POINTER],     HL

        ;swap back DE & HL
        ;HL will be the current position in the level header
        ex      DE,     HL

        ;ML: Mob Layout
        ;-----------------------------------------------------------------------
        inc     HL
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL

        ;store the current position in the level header
        push    HL

        ;the mob layouts are relative from $15580, which is just odd really
        ld      HL,     $5580
        add     HL,     DE

        ;switch page 1 ($4000-$BFFF) to page 5 ($14000-$17FFF)
        ld      A,                      5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        call    loadMobList

        pop     HL

        ;SR: Scrolling / Ring HUD flags
        ;-----------------------------------------------------------------------
        ld      C,      [HL]
        ld      A,      [IY+Vars.scrollRingFlags]
        and     %00000010
        or      C
        ld      [IY+Vars.scrollRingFlags], A

        ;UW: Underwater flag
        ;-----------------------------------------------------------------------
        inc     HL
        ld      A,      [HL]
        ld      [IY+Vars.flags6],  A

        ;TL: Time HUD / Lightning effect flags
        ;-----------------------------------------------------------------------
        inc     HL
        ld      A,      [HL]
        ld      [IY+Vars.timeLightningFlags],      A

        ;00: Unknown byte
        inc     HL
        ld      A,      [HL]
        ld      [IY+Vars.unknown0],        A

        ;MU: Music
        ;-----------------------------------------------------------------------
        inc     HL
        ld      A,      [RAM_PREVIOUS_MUSIC]                        ;check previously played music
        cp      [HL]
        jr      z,      @_11                                    ;if current music is the same, skip ahead

        ld      A,      [HL]                                    ;get the music number from the level header
        and     A                                               ;this won't change the value of A, but it will
                                                                ;update the flags, so that ...
        jp      m,      @_11                                    ;we can check if the sign is negative,
                                                                ;that is, A>127

        ;remember the current level music to restore it after invincibility &c.
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      [RAM_LEVEL_MUSIC],      A
                rst     $18     ;=rst_playMusic
        .ENDIF

        ;-----------------------------------------------------------------------

        ;fill 64 bytes (32 16-bit numbers) from $D37C-$D3BC
@_11:   ld      B,      32
        ld      HL,     RAM_ACTIVEMOBS
        xor     A                                          ;set A to 0

@_12:   ld      [HL],   A
        inc     HL
        ld      [HL],   A
        inc     HL
        djnz    @_12

        bit     5,      [IY+Vars.origFlags6]
        ret     z

        set     5,      [IY+Vars.flags6]
        ret
        ;

loadMobList:                                                            ;$232B
;===============================================================================
; Reads in a list of mob IDs and their positions within the level.
;
; in    HL      Address of a mob layout list
;-------------------------------------------------------------------------------
        ;NOTE: D2F2 is used only here -- perhaps a regular temp variable could be used

        ;immediately put aside a copy of the mob layout list address
        push    HL

        ;add Sonic to the list of active mobs first
        ld      IX,     RAM_SONIC
        ld      DE,     _sizeof_Mob     ;=$001A (length of the mob?)
        ld      C,      $00             ;?
        ld      HL,     [RAM_D216]      ;=$D32E + (level number * 2)
        ld      A,      MOB_ID_SONIC    ;=0
        call    loadMobFromList

        ;return to the mob layout list originally provided
        pop     HL

        ;-----------------------------------------------------------------------
        ld      A,     [HL]             ; first byte is number of mobs to load
        inc     HL

        ld      [RAM_D2F2],     A       ; put aside no. of mobs in the layout
        dec     A                       ; reduce by 1,
        ld      B,     A                ; and set as the loop counter

        ; loop over the number of mobs:
@_1:    ld      A,       [HL]                    ;read the mob type
        inc     HL                                      ;move on to the X & Y position
        call    loadMobFromList
        djnz    @_1

        ;-----------------------------------------------------------------------

        ld      A,      [RAM_D2F2]      ; retrieve number of mobs in layout
        ld      B,      A
        ld      A,      $20
        sub     B
        ret     z                                               ;exit if exactly 32 mobs!

        ;remove the remaining mobs (out of 32)
        ld      B,      A
@_2:    ld      [IX+Mob.type],      $FF                     ;remove mob?
        add     IX,     DE
        djnz    @_2

        ret
        ;

loadMobFromList:                                                        ;$235E
;===============================================================================
; in    IX      Address of the mob structure to be setup
;       A       Mob type
;       HL      address with the X & Y byte Block-offsets of the mob on the Floor
;       DE      size of the mob structure (to skip to the next one)
; out   IX      IX will be updated to be pointing to the next mob structure in RAM
;       HL      The pointer to the mob layout list will have been moved forward to the next mob in the list
;-------------------------------------------------------------------------------
        ld      [IX+Mob.type],      A               ;set the mob type

        ;x position:
        ;-----------------------------------------------------------------------
        ld      A, [HL]                          ;get X position from the mob layout
        exx                                                     ;put aside parameters and switch to shadow registers
        ;convert X-pos to 16-bit number in HL
        ld      L', A
        ld      H', $00
        ;align the mob to whole pixels (not sub-pixels)
        ld      [IX+Mob.Xsubpixel], H'

        ;multiply by 32: (expand Blocks to pixels)
        add     HL',        HL'                         ;x2 ...
        add     HL',        HL'                         ;x4 ...
        add     HL',        HL'                         ;x8 ...
        add     HL',        HL'                         ;x16 ...
        add     HL',        HL'                         ;x32

        ;set the pixel X-position of the mob on the Floor
        ld      [IX+Mob.X+0],       L'
        ld      [IX+Mob.X+1],       H'

        ;y position:
        ;-----------------------------------------------------------------------
        exx                                                     ;return to original parameters
        inc     HL                                    ;move over the X-position to the Y-position
        ld      A, [HL]                          ;get the Y position from the mob layout
        exx                                                     ;return to the shadow registers
        ;convert X-pos to 16-bit number in HL
        ld      L', A
        ld      H', $00
        ;align the mob to whole pixels (not sub-pixels)
        ld      [IX+Mob.Ysubpixel], H'

        ;multiply by 32: (expand Blocks to pixels)
        add     HL',        HL'                         ;x2 ...
        add     HL',        HL'                         ;x4 ...
        add     HL',        HL'                         ;x8 ...
        add     HL',        HL'                         ;x16 ...
        add     HL',        HL'                         ;x32

        ;set the pixel Y-position of the mob on the Floor
        ld      [IX+Mob.Y+0],       L'
        ld      [IX+Mob.Y+1],       H'

        ;set the rest of the mob structure to 0:
        ;-----------------------------------------------------------------------
        ;TODO: sizes used here need to be calculated directly off of the `Mob` type

        ;transfer IX (mob address) to HL
        push    IX
        pop     HL'

        ;skip to the 7th byte of the mob: `.xpseed`, skipping type/x/y-pos,
        ;this assumes a contiguous order
        ld      DE',        Mob.Xspeed                      ;=7
        add     HL',     DE'

        ;erase the next 19 bytes (remainder of mob data structure)
        ld      B',        19
        xor     A                                          ;set A to 0
@loop:  ld      [HL'],  A
        inc     HL'
        djnz    @loop

        ;return to the original parameters
        exx
        inc     HL                                    ;move to the beginning of the next mob in the list
        add     IX,     DE                      ;move to the next mob structure in memory
                                                                ;TODO: this number can simply be hard-coded
        ret
        ;

_239c:                                                                  ;$239C
;===============================================================================
; animate ring

        ;ld      (SCROLLZONE_LEFT) = $0060
        ;ld      (SCROLLZONE_RIGHT) = $0088
        ;ld      (SCROLLZONE_TOP) = $0060
        ;ld      (SCROLLZONE_BOTTOM) = $0070

        ld      A,      [RAM_D297]
        ld      E,      A
        ld      D,      $00
        ld      HL,     _23f9
        add     HL,     DE
        ld      A,      [HL]
        ;16-bit divide by 2
        ld      L,      D
        srl     A
        rr      L
        ld      H,      A

        ld      DE,     $7CF0
        add     HL,     DE
        ld      [RAM_RING_CURRENT_FRAME],       HL

        ld      HL,     RAM_D298
        ld      A,      [HL]
        inc     A
        ld      [HL],   A
        cp      $0A
        ret     c

        ld      [HL],   $00
        dec     HL
        ld      A,      [HL]
        inc     A
        cp      $06
        jr      c,      @_1

        xor     A

@_1:    ld      [HL],   A

        ret
        ;

_23c9:                                                                  ;$23C9
;===============================================================================
        ld      A,      [RAM_CYCLEPALETTE_COUNTER]
        dec     A
        ld      [RAM_CYCLEPALETTE_COUNTER],     A
        ret     nz

        ld      A,      [RAM_CYCLEPALETTE_INDEX]
        ld      L,      A
        ld      H,      $00
        add     HL,     HL
        add     HL,     HL
        add     HL,     HL
        add     HL,     HL
        ld      DE,     [RAM_CYCLEPALETTE_POINTER]
        add     HL,     DE
        ld      A,      %00000001
        call    loadPaletteOnInterrupt
        ld      HL,     [RAM_CYCLEPALETTE_INDEX]
        ld      A,      L
        inc     A
        cp      H
        jr      c,      @_1

        xor     A
@_1:    ld      L,      A
        ld      [RAM_CYCLEPALETTE_INDEX],       HL
        ld      A,      [RAM_CYCLEPALETTE_SPEED]
        ld      [RAM_CYCLEPALETTE_COUNTER],     A
        ret
        ;

_23f9:                                                                  ;$23F9
;===============================================================================
        .BYTE   $05 $04 $03 $02 $01 $00
        ;

_23ff:                                                                  ;$23FF
;===============================================================================
        .BYTE   $00 $00 $00
        ;

_2402:                                                                  ;$2402
;===============================================================================
        .BYTE   $01 $30 $00
        ;

_2405:                                                                  ;$2405
;===============================================================================

        .BYTE   $01 $00 $00                                             ;Special Stage 1?
        .BYTE   $01 $00 $00                                             ;Special Stage 2?
        .BYTE   $00 $45 $00                                             ;Special Stage 3?
        .BYTE   $00 $50 $00                                             ;Special Stage 4?
        .BYTE   $00 $45 $00                                             ;Special Stage 5?
        .BYTE   $00 $50 $00                                             ;Special Stage 6?
        .BYTE   $00 $50 $00                                             ;Special Stage 7?
        .BYTE   $00 $30 $00                                             ;Special Stage 8?
        .BYTE   $01 $00 $00
        .BYTE   $01 $00 $01
        .BYTE   $02 $00 $01
        .BYTE   $02 $FF $02
        .BYTE   $03 $01 $01
        .BYTE   $03 $FE $02
        .BYTE   $04 $01 $01
        .BYTE   $04 $FD $03
        .BYTE   $05 $02 $01
        .BYTE   $06 $FB $03
        .BYTE   $06 $03 $00
        .BYTE   $07 $FA $03
        .BYTE   $06 $05 $FF
        .BYTE   $08 $F9 $03
        .BYTE   $07 $06 $FE
        .BYTE   $09 $F7 $03
        .BYTE   $07 $08 $FD
        .BYTE   $0A $F6 $02
        .BYTE   $07 $09 $FB
        .BYTE   $0B $F4 $01
        .BYTE   $06 $0B $FA
        .BYTE   $0B $F3 $00 $06 $0D $F8 $0B $F2 $FF
        .BYTE   $05 $0E $F6 $0B $F1 $FD $03 $10 $F4 $0B $F0 $FB $02 $12 $F2 $0A
        .BYTE   $F0 $F9 $00 $13 $F0 $09 $F0 $F7 $FE $14 $EE $08 $F0 $F4 $FC $15
        .BYTE   $EC $07 $F0 $F2 $F9 $15 $EA $05 $F1 $EF $F6 $16 $E9 $02 $F2 $ED
        .BYTE   $F4 $15 $E7 $00 $F4 $EB $F1 $15 $E6 $FD $F5 $E8 $EE $14 $E5 $FA
        .BYTE   $F8 $E6 $EB $13 $E5 $F7 $FA $E4 $E8 $11 $E5 $F4 $FD $E3 $E5 $0F
        .BYTE   $E5 $F1 $00 $E1 $E3 $0D $E6 $ED $03 $E0 $E0 $0A $E7 $EA $07 $E0
        .BYTE   $DE $07 $E9 $E6 $0B $DF $DD $04 $EB $E3 $0E $DF $DB $00 $EE $E0
        .BYTE   $12 $E0 $DA $FC $F1 $DD $16 $E1 $DA $F8 $F4 $DB $1A $E3 $DA $F4
        .BYTE   $F8 $D8 $1E $E5 $DA $EF $FC $D7 $22 $E8 $DB $EB $00 $D5 $25 $EB
        .BYTE   $DC $E6 $05 $D4 $28 $EE $DE $E2 $09 $D4 $2B $F2 $E1 $DE $0E $D4
        .BYTE   $2D $F6 $E4 $D9 $13 $D5 $2F $FB $E8 $D6 $18 $D6 $31 $00 $EC $D2
        .BYTE   $1D $D8 $32 $05 $F0 $CF $22 $DA $32 $0B $F5 $CD $27 $DD $32 $10
        .BYTE   $FA $CB $2B $E0 $31 $16 $00 $C9 $2F $E5 $2F $1B $06 $C8 $33 $E9
        .BYTE   $2D $21 $0C $C8 $36 $EE $2B $26 $12 $C8 $39 $F4 $27 $2B $18 $CA
        .BYTE   $3B $FA $23 $30 $1E $CB $3D $00 $1E $35 $24 $CE $3E $06 $19 $39
        .BYTE   $2A $D1 $3E $0D $14 $3C $30 $D5 $3D $14 $0D $3F $35 $D9 $3C $1B
        .BYTE   $07 $41 $3A $DF $3A $21 $00 $43 $3E $E4 $37 $28 $F9 $44 $42 $EB
        .BYTE   $33 $2E $F2 $44 $45 $F1 $2F $34 $EA $43 $47 $F9 $2A $3A $E3 $41
        .BYTE   $49 $00 $24 $3F $DC $3F
        ;

;end sequence screens?

_LABEL_258B_133:                                                        ;$258B
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      A,      [RAM_VDPREGISTER_1]
        and     %10111111
        ld      [RAM_VDPREGISTER_1],    A

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ;reset the screen scroll (for static screens)
        xor     A
        ld      [RAM_VDPSCROLL_HORZ],   A
        ld      [RAM_VDPSCROLL_VERT],   A

        ld      HL,     _2828
        ld      A,      %00000011
        call    loadPaletteOnInterrupt

        ;load the map screen 1
        ld      HL,     $0000
        ld      DE,     $0000
        ld      A,      $0C                                     ;bank 12 ($30000+)
        call    decompressArt

        ;load page 1 ($4000-$7FFF) with bank 5 ($14000-$17FFF)
        ld      A, 5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;map 3 screen (end of game)
        ld      HL,     $6830
        ld      BC,     $0179
        ld      DE,     SMS_VRAM_SCREEN
        xor     A
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ld      A,      [RAM_VDPREGISTER_1]
        or      %01000000
        ld      [RAM_VDPREGISTER_1],    A

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      A,                      1
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A
        ld      A,      [RAM_D27F]
        cp      $06
        jp      c,      @_4

        ld      B,      $3C

@_1:    push    BC

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      HL,     RAM_SPRITETABLE
        ld      C, 112
        ld      B, 96
        ld      DE,     _2825
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL
        pop     BC
        djnz    @_1

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_ALLEMERALDS
                rst     $18     ;=rst_playMusic
        .ENDIF

        ld      HL,     $241D
        ld      B,      $3D

@_2:    push    BC
        ld      C,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       C

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      DE,     RAM_SPRITETABLE
        ld      [RAM_SPRITETABLE_ADDR], DE
        ld      B,      $03

@_3:    push    BC
        push    HL
        ld      A,      $70
        add     A,      [HL]
        ld      C,      A
        inc     HL
        ld      A,      $60
        add     A,      [HL]
        ld      B,      A
        inc     HL
        push    BC
        ld      DE,     _2825
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL
        pop     BC
        pop     HL
        ld      A,      [HL]
        neg
        add     A,      $70
        ld      C,      A
        inc     HL
        ld      A,      [HL]
        neg
        add     A,      $60
        ld      B,      A
        inc     HL
        push    HL
        ld      DE,     _2825
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL
        pop     HL
        pop     BC
        djnz    @_3

        pop     BC
        djnz    @_2

        ld      HL,     _2047
        call    _b60
        ld      [IY+Vars.spriteUpdateCount],       $00

        ld      A,                      5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;UNKNOWN
        ld      HL,     $69A9
        ld      BC,     $0145
        ld      DE,     SMS_VRAM_SCREEN
        xor     A
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        ld      HL,     _2828
        call    _aae                                      ;called only by this routine,
                                                                ;appears to fade the screen out

        ;-----------------------------------------------------------------------

@_4:    ld      BC,     240
        call    waitFrames
        call    _155e                                           ;Act Complete screen?

        ld      BC,     240
        call    waitFrames
        call    fadeOut

        ld      BC,     120
        call    waitFrames

         ;map screen 2 / credits screen tile set
        ld      HL,     $1801
        ld      DE,     $0000
        ld      A,      12
        call    decompressArt

        ;title screen animated finger sprite set
        ld      HL,     $4B0A
        ld      DE,     $2000
        ld      A,      9
        call    decompressArt

        ld      A,                      5
        ld      [SMS_MAPPER_SLOT1],     A
        ld      [RAM_SLOT1],            A

        ;credits screen
        ld      HL,     $6C61
        ld      BC,     $0189
        ld      DE,     SMS_VRAM_SCREEN
        xor     A
        ld      [RAM_TEMP1],    A
        call    decompressScreen

        xor     A                                          ;set A to 0
        ;NOTE: These are addresses! See `_275a`
        ld      HL,     RAM_D322
        ld      [HL],   <_2848
        inc     HL
        ld      [HL],   >_2848
        inc     HL
        ld      [HL],   A                                  ;$2848 = 0
        inc     HL
        ld      [HL],   <_2857
        inc     HL
        ld      [HL],   >_2857
        inc     HL
        ld      [HL],   A                                  ;$2857 = 0
        inc     HL
        ld      [HL],   <_2869
        inc     HL
        ld      [HL],   >_2869
        inc     HL
        ld      [HL],   A                                  ;$2869 = 0
        inc     HL
        ld      [HL],   <_2872
        inc     HL
        ld      [HL],   >_2872
        inc     HL
        ld      [HL],   A                                  ;$2872 = 0

        ld      BC,     1
        call    _2718

        ld      HL,     creditsPalette
        call    _b50

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_ENDING
                rst     $18     ;=rst_playMusic
        .ENDIF

        xor     A                                          ;(set A to 0)
        ld      [RAM_TEMP1],    A
        ld      HL,     creditsText
        call    _2795

@infiniteLoop:
        ;this could be the game-freeze after the final credits
        jp      @infiniteLoop
        ;

_2718:                                                                  ;$2718
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        push    AF
        push    HL
        push    DE
        push    BC
@_1:    push    BC

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       $00
        ld      HL,     RAM_SPRITETABLE
        ld      [RAM_SPRITETABLE_ADDR], HL

        ld      HL,     RAM_D322
        ld      B,      $04

@_2:    push    BC
        call    _275a
        pop     BC
        djnz    @_2

        pop     BC
        dec     BC
        ld      A,      B
        or      C
        jr      nz,     @_1

        pop     BC
        pop     DE
        pop     HL
        pop     AF
        ret
        ;

waitFrames:                                                             ;$2745
;===============================================================================
; Wait a given number of frames.
;
; in    IY      Address of the common variables (used throughout)
;       BC      Number of frames to wait
;-------------------------------------------------------------------------------
        push    BC

        ;refresh the screen
        ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       A

        pop     BC
        dec     BC

        ld      A,     B
        or      C
        jr      nz,    waitFrames

        ret
        ;


_275a:                                                                  ;$275A
;===============================================================================
; called only by _2718
;
; in    HL
;-------------------------------------------------------------------------------
        ld      E,      [HL]                                    ;E = D322 ($48)
        inc     HL
        ld      D,      [HL]                                    ;D = D323 ($28)
        inc     HL
        inc     [HL]                                            ;D324

        ld      A,      [DE]                                    ;[$2848]
        cp      [HL]
        jr      nc,     @_1

        ld      [HL],   $00                                     ;reset the counter
        inc     DE                                              ;move to the next frame of animation
        inc     DE                                              ;(three bytes each frame index)
        inc     DE
        ;update the pointer in RAM to the new animation frame
        dec     HL
        ld      [HL],   D
        dec     HL
        ld      [HL],   E
        ;check for the end of the animation list ("$FF" wait time)
        inc     HL
        inc     HL
        ld      A,      [DE]
        cp      $FF
        jr      nz,     @_1

        inc     DE
        ld      A,      [DE]
        ld      B,      A
        inc     DE
        ld      A,      [DE]
        dec     HL
        ld      [HL],   A
        dec     HL
        ld      [HL],   B
        jr     _275a

        ;-----------------------------------------------------------------------

@_1:    inc     HL
        inc     DE
        push    HL
        ex      DE,     HL
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        ex      DE,     HL
        ld      A,      [HL]
        inc     HL
        ld      E,      [HL]
        inc     HL
        ld      C,      L
        ld      B,      H
        ld      L,      A
        ld      H,      $00
        ld      D,      H
        call    processSpriteLayout

        pop     HL
        ret
        ;

_2795:                                                                  ;$2795
;===============================================================================
        ld      DE,     RAM_LAYOUT_BUFFER
        ldi
        ldi
        inc     DE
        ld      A,      $FF
        ld      [DE],   A
@_:     ld      A,      [HL]
        inc     HL
        cp      $FF
        ret     z

        cp      $FE
        jr      z,     _2795

        cp      $FC
        jr      z,      @_2

        cp      $FD
        jr      nz,     @_1

        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL
        call    _2718
        jr      @_

@_1:    push    HL
        ld      [RAM_LAYOUT_BUFFER+2],  A
        ld      BC,     $0008
        call    _2718
        ld      HL,     RAM_LAYOUT_BUFFER
        call    print
        ld      HL,     RAM_LAYOUT_BUFFER
        inc     [HL]
        pop     HL
        jr      @_

@_2:    ld      B,       [HL]
        inc     HL
        push    HL

@_3:    push    BC
        ld      BC,     $000C
        call    _2718
        ld      DE,     $3AA4
        ld      HL,     $3AE4
        ld      B,      $09

@_4:    push    BC
        push    HL
        push    DE
        ld      B,      $14

@_5:    di
        ld      A,      L
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      H
        out     [SMS_PORTS_VDP_CONTROL],        A
        push    IX
        pop     IX
        in      A,      [SMS_PORTS_VDP_DATA]
        ld      C,      A
        push    IX
        pop     IX
        ld      A,      E
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      D
        or      $40
        out     [SMS_PORTS_VDP_CONTROL],        A
        push    IX
        pop     IX
        ld      A,      C
        out     [SMS_PORTS_VDP_DATA],   A
        push    IX
        pop     IX
        ei
        inc     HL
        inc     DE
        djnz    @_5

        pop     DE
        pop     HL
        ld      BC,     $0040
        add     HL,     BC
        ex      DE,     HL
        add     HL,     BC
        ex      DE,     HL
        pop     BC
        djnz    @_4

        pop     BC
        djnz    @_3
        pop     HL
        jp      @_
        ;

_2825:                                                                  ;$2825
;===============================================================================
        .BYTE   $5C $5E $FF
        ;

;Used by "_275a"

_2828:                                                                  ;$2828
;===============================================================================
; Credits screen palette.
;
        .TABLE  DSB 16
        .ROW    $35 $01 $06 $0B $04 $08 $0C $3D $1F $39 $2A $14 $25 $2B $00 $3F
        .ROW    $35 $20 $35 $1B $16 $2A $00 $3F $03 $0F $01 $15 $00 $3C $00 $3F
        ;

_2848:                                                                  ;$2848
;===============================================================================
        .TABLE  BYTE    WORD
        .ROW    $96     _2902
        .ROW    $86     _289F
        .ROW    $E9     _2902
        .ROW    $6F     _289F
        .ROW    $FF     _2848
        ;

_2857:                                                                  ;$2857
;===============================================================================
        .TABLE  BYTE    WORD
        .ROW    $36     _28B1
        .ROW    $48     _28BA
        .ROW    $54     _28A8
        .ROW    $1E     _28B1
        .ROW    $44     _28BA
        .ROW    $FF     _2857
        ;

_2869:                                                                  ;$2869
;===============================================================================
        .TABLE  BYTE    WORD
        .ROW    $23     _28C3
        .ROW    $23     _28CC
        .ROW    $FF     _2869
        ;

_2872:                                                                  ;$2872
;===============================================================================
        .TABLE  BYTE    WORD
        .ROW    $E4     _28F3
        .ROW    $19     _28E4
        .ROW    $19     _28D5
        .ROW    $19     _28E4
        .ROW    $19     _28D5
        .ROW    $FA     _28F3
        .ROW    $85     _28E4
        .ROW    $E8     _28F3
        .ROW    $19     _28E4
        .ROW    $19     _28D5
        .ROW    $19     _28E4
        .ROW    $19     _28D5
        .ROW    $19     _28E4
        .ROW    $19     _28D5
        .ROW    $FF     _2872
        ;

;looks like the sprite layouts for the singing Sonic on the credits screen

_289F:                                                                  ;$289F
;===============================================================================
        .BYTE   $40 $48 $50 $FF $FF $FF
        .BYTE   $FF $FF $FF
        ;

_28A8:                                                                  ;$28A8
;===============================================================================
        .BYTE   $40 $58 $4A $FF $FF $FF
        .BYTE   $FF $FF $FF
        ;

_28B1:                                                                  ;$28B1
;===============================================================================
        .BYTE   $40 $58 $4C $FF $FF $FF
        .BYTE   $FF $FF $FF
        ;

_28BA:                                                                  ;$28BA
;===============================================================================
        .BYTE   $40 $58 $4E $FF $FF $FF
        .BYTE   $FF $FF $FF
        ;

_28C3:                                                                  ;$28C3
;===============================================================================
        .BYTE   $40 $78 $6A $6C $6E $FF
        .BYTE   $FF $FF $FF
        ;

_28CC:                                                                  ;$28CC
;===============================================================================
        .BYTE   $40 $78 $70 $72 $74 $FF
        .BYTE   $FF $FF $FF
        ;

_28D5:                                                                  ;$28D5
;===============================================================================
        .BYTE   $48 $50 $0A $0C $FF $FF
        .BYTE   $FF $FF
        ;

_28DD:                                                                  ;$28DD
;===============================================================================
        .BYTE   $2A $2C $FF $FF $FF $FF
        .BYTE   $FF
        ;

_28E4:                                                                  ;$28E4
;===============================================================================
        .BYTE   $48 $50 $0E $10 $FF $FF
        .BYTE   $FF $FF
        ;

_28EC:                                                                  ;$28EC
;===============================================================================
        .BYTE   $2E $30 $FF $FF $FF $FF
        .BYTE   $FF
        ;

_28F3:                                                                  ;$28F3
;===============================================================================
        .BYTE   $48 $60 $12 $14 $FF $FF
        .BYTE   $FF $FF
        ;

_28FB:                                                                  ;$28FB
;===============================================================================
        ;unused?
        .BYTE   $32 $34 $FF $FF $FF $FF
        .BYTE   $FF
        ;

_2902:                                                                  ;$2902
;===============================================================================
        .BYTE   $40 $48 $FF
        ;

creditsText:                                                            ;$2905
;===============================================================================
;ASCIITABLE
;      MAP     " " = $EB
;      MAP     "A" = $1E
;      MAP     "B" = $1F
;      MAP     "C" = $2E
;      MAP     "D" = $2F
;      MAP     "E" = $3E
;      MAP     "F" = $3F
;      MAP     "G" = $4E
;      MAP     "H" = $4F
;      MAP     "I" = $5E
;      MAP     "J" = $5F
;      MAP     "K" = $6E
;      MAP     "L" = $6F
;      MAP     "M" = $7E
;      MAP     "N" = $7F
;      MAP     "O" = $8E
;      MAP     "P" = $8F
;      MAP     "Q" = $9E
;      MAP     "R" = $9F
;      MAP     "S" = $AE
;      MAP     "T" = $AF
;      MAP     "U" = $BE
;      MAP     "V" = $BF
;      MAP     "W" = $CE
;      MAP     "X" = $CF
;      MAP     "Y" = $DE
;      MAP     "Z" = $DF
;      MAP     "@" = $AB
;ENDA
        
        .BYTE   $14 $03 $AE $9E $7F $5E $2E                             ;SONIC
        .BYTE   $FE $15 $04 $AF $4F $3E                                 ;THE
        .BYTE   $FE $13 $05 $4F $3E $2F $4E $3E $4F $9E $4E             ;HEDGEHOG
        .BYTE   $FD $3C $00
        .BYTE   $FE $12 $0C $7E $1E $AE $AF $3E $9F                     ;MASTER
        .BYTE   $FE $13 $0D $AE $DE $AE $AF $3E $7E                     ;SYSTEM
        .BYTE   $FE $14 $0E $BF $3E $9F $AE $5E $9E $7F                 ;VERSION
        .BYTE   $FD $3C $00
        .BYTE   $FC $09
        .BYTE   $FE $14 $0B $AE $9E $7F $5E $2E                         ;SONIC
        .BYTE   $FE $15 $0C $AF $4F $3E                                 ;THE
        .BYTE   $FE $13 $0D $4F $3E $2F $4E $3E $4F $9E $4E             ;HEDGEHOG
        .BYTE   $FD $3C $00
        .BYTE   $FE $12 $0F $8E $9F $5E $4E $5E $7F $1E $6F             ;ORIGINAL
        .BYTE   $FE $13 $10 $2E $4F $1E $9F $1E $2E $AF $3E $9F         ;CHARACTER
        .BYTE   $FE $14 $11 $2F $3E $AE $5E $4E $7F                     ;DESIGN
        .BYTE   $FD $3C $00
        .BYTE   $FC $04
        .BYTE   $FE $14 $10 $AB $AE $3E $4E $1E                         ;(C)SEGA
        .BYTE   $FD $B4 $00
        .BYTE   $FC $09
        .BYTE   $FE $14 $0E $AE $AF $1E $3F $3F                         ;STAFF
        .BYTE   $FD $B4 $00
        .BYTE   $FC $09
        .BYTE   $FE $12 $0B $4E $1E $7E $3E                             ;GAME
        .BYTE   $FE $13 $0C $8F $9F $9E $4E $9F $1E $7E                 ;PROGRAM
        .BYTE   $FD $3C $00
        .BYTE   $FE $13 $0E $AE $4F $5E $7F $9E $1F $BE                 ;SHINOBU
        .BYTE   $FE $14 $0F $4F $1E $DE $1E $AE $4F $5E                 ;HAYASHI
        .BYTE   $FD $F0 $00
        .BYTE   $FC $09
        .BYTE   $FE $12 $0B $4E $9F $1E $8F $4F $5E $2E                 ;GRAPHIC
        .BYTE   $FE $14 $0C $2F $3E $AE $5E $4E $7F                     ;DESIGN
        .BYTE   $FD $3C $00
        .BYTE   $FE $13 $0E $1E $DE $1E $7F $9E                         ;AYANO
        .BYTE   $FE $14 $0F $6E $9E $AE $4F $5E $9F $9E                 ;KOSHIRO
        .BYTE   $FD $3C $00
        .BYTE   $FE $13 $11 $AF $1E $CF $3E $3F $BE $7F $5E             ;TAKAFUNI
        .BYTE   $FE $14 $12 $DE $BE $7F $9E $BE $3E                     ;YUNOUE
        .BYTE   $FD $F0 $00
        .BYTE   $FC $09
        .BYTE   $FE $12 $0B $AE $9E $BE $7F $2F                         ;SOUND
        .BYTE   $FE $13 $0C $8F $9F $9E $2F $BE $2E $3E                 ;PRODUCE
        .BYTE   $FD $3C $00
        .BYTE   $FE $13 $0E $7E $1E $AE $1E $AF $9E                     ;MASATO
        .BYTE   $FE $14 $0F $7F $1E $CF $1E $7E $BE $9F $1E             ;NAKAMURA
        .BYTE   $FD $F0 $00
        .BYTE   $FC $09
        .BYTE   $FE $12 $0B $9F $3E $1E $9F $9F $1E $7F $4E $3E         ;REARRANGE
        .BYTE   $FE $15 $0C $1E $7F $2F                                 ;AND
        .BYTE   $FE $12 $0D $9E $9F $5E $4E $5E $7F $1E $6F             ;ORIGINAL
        .BYTE   $FE $16 $0E $7E $BE $AE $5E $2E                         ;MUSIC
        .BYTE   $FD $3C $00
        .BYTE   $FE $13 $10 $DE $BE $DF $9E                             ;YUZO
        .BYTE   $FE $14 $11 $6E $9E $AE $4F $5E $9F $9E                 ;KOSHIRO
        .BYTE   $FD $F0 $00
        .BYTE   $FC $09
        .BYTE   $FE $13 $0D $AE $8F $3E $2E $5E $1E $6F                 ;SPECIAL
        .BYTE   $FE $15 $0E $AF $4F $1E $7F $6E $AE                     ;THANKS
        .BYTE   $FD $B4 $00
        .BYTE   $FC $02
        .BYTE   $FE $13 $0E $DE $8E $AE $4F $5E $8E $EB $DE             ;YOSHIRO Y
        .BYTE   $FD $3C $00
        .BYTE   $FE $13 $11 $6F $BE $7F $1E $9F $5E $1E $7F             ;LUNARIAN
        .BYTE   $FE $1A $12 $AE $4E                                     ;SG
        .BYTE   $FD $B4 $00
        .BYTE   $FC $09
        .BYTE   $FE $12 $0C $8F $9F $3E $AE $3E $7F $AF $3E $2F         ;PRESENTED
        .BYTE   $FE $16 $0E $1F $DE                                     ;BY
        .BYTE   $FE $15 $10 $AE $3E $4E $1E                             ;SEGA
        .BYTE   $FD $B4 $00
        .BYTE   $FE $19 $13 $3E $7F $2F                                 ;END
        .BYTE   $FF
        ;

creditsPalette:                                                         ;$2AD6
;===============================================================================
        .TABLE  DSB 16
        .ROW    $35 $3D $1F $39 $06 $1B $01 $34 $2B $10 $03 $14 $2A $1F $00 $3F
        .ROW    $35 $3D $1F $39 $06 $1B $01 $34 $2B $10 $03 $14 $2A $1F $00 $3F
        ;

mobPointers:                                                            ;$2AF6
;===============================================================================
; this is the list of mobs defined in the game,
; with the order of this table providing the mob IDs
;
.ENUMID 0       EXPORT
@sonic:                                 ; Sonic
        .ENUMID MOB_ID_SONIC                                            ;=$00
        .ADDR   sonic_process
@powerUp_ring:                          ; 10 rings monitor
        .ENUMID MOB_ID_RINGS                                            ;=$01
        .ADDR   powerups_ring_process   
@powerUp_speed:                         ; speed shoes monitor
        .ENUMID MOB_ID_SPEEDUP                                          ;=$02
        .ADDR   powerups_speed_process  
@powerUp_life:                          ; extra life monitor
        .ENUMID MOB_ID_1UP                                              ;=$03
        .ADDR   powerups_life_process   
@powerUp_shield:                        ; sheild monitor
        .ENUMID MOB_ID_SHIELD                                           ;=$04
        .ADDR   powerups_shield_process 
@powerUp_invincibility:                 ; invincibility monitor
        .ENUMID MOB_ID_INVINCIBILITY                                    ;=$05
        .ADDR   powerups_invincibility_process
@powerUp_emerald:                       ; chaos emerald
        .ENUMID MOB_ID_EMERALD                                          ;=$06
        .ADDR   powerups_emerald_process
@boss_endSign:                          ; end sign
        .ENUMID MOB_ID_ENDSIGN                                          ;=$07
        .ADDR   boss_endSign_process
@badnick_crabMeat:                      ; badnick - crabmeat
        .ENUMID MOB_ID_CRABMEAT                                         ;=$08
        .ADDR   badnick_crabmeat_process
@platform_swinging:                     ;#09: wooden platform - swinging (Green Hill)
        .ADDR   platform_swinging_process
@explosion:                             ;#0A: explosion
        .ADDR   explosion_process
@platform:                              ;#0B: wooden platform (Green Hill)
        .ADDR   platform_sinking_process
@platform_falling:                      ;#0C: wooden platform - falling (Green Hill)
        .ADDR   platform_falling_process
@_6ac1:                                 ;#0D: UNKNOWN
        .ADDR   unknown_6ac1_process
@badnick_buzzBomber:                    ;#0E: badnick - buzz bomber
        .ADDR   badnick_buzzbomber_process
@platform_leftRight:                    ;#0F: wooden platform - moving (Green Hill)
        .ADDR   platform_moving_process
@badnick_motobug:                       ;#10: badnick - motobug
        .ADDR   badnick_motobug_process
@badnick_newtron:                       ;#11: badnick - newtron
        .ADDR   badnick_newtron_process
@boss_greenHill:                        ;#12: boss (Green Hill)
        .ADDR   boss_greenHill_process
@_9b75:                                 ;#13: UNKNOWN - bullet?
        .ADDR   unknown_9b75_process
@_9be8:                                 ;#14: UNKNOWN - fireball right?
        .ADDR   unknown_9be8_process
@_9c70:                                 ;#15: UNKNOWN - fireball left?
        .ADDR   _9c70
@trap_flameThrower:                     ;#16: flame thrower (Scrap Brain)
        .ADDR   mob_trap_flameThrower
@door_left:                             ;#17: door - one way left (Scrap Brain)
        .ADDR   mob_door_left
@door_right:                            ;#18: door - one way right (Scrap Brain)
        .ADDR   mob_door_right
@door_door:                             ;#19: door (Scrap Brain)
        .ADDR   mob_door
@trap_electric:                         ;#1A: electric sphere (Scrap Brain)
        .ADDR   trap_electric_process
@badnick_ballHog:                       ;#1B: badnick - ball hog (Scrap Brain)
        .ADDR   badnick_ballhog_process
@_a33c:                                 ;#1C: UNKNOWN - ball from ball hog?
        .ADDR   unknown_a33c_process
@switch:                                ;#1D: switch
        .ADDR   door_switch_process
@door_switchActivated:                  ;#1E: switch door
        .ADDR   door_switching_process
@badnick_caterkiller:                   ;#1F: badnick - caterkiller
        .ADDR   badnick_caterkiller_process
@_96f8:                                 ;#20: UNKNOWN
        .ADDR   unknown_96f8_process
@platform_bumper:                       ;#21: moving bumper (Special Stage)
        .ADDR   platform_bumper_process
@boss_scrapBrain:                       ;#22: boss (Scrap Brain)
        .ADDR   boss_scrapBrain_process
@boss_freeRabbit:                       ;#23: free animal - rabbit
        .ADDR   boss_freeRabbit_process
@boss_freeBird:                         ;#24: free animal - bird
        .ADDR   boss_freeBird_process
@boss_capsule:                          ;#25: capsule
        .ADDR   boss_capsule_process
@badnick_chopper:                       ;#26: badnick - chopper
        .ADDR   badnick_chopper_process
@platform_fallVert:                     ;#27: log - vertical (Jungle)
        .ADDR   mob_platform_fallVert
@platform_fallHoriz:                    ;#28: log - horizontal (Jungle)
        .ADDR   mob_platform_fallHoriz
@platform_roll:                         ;#29: log - floating (Jungle)
        .ADDR   mob_platform_roll
@_96a8:                                 ;#2A: UNKNOWN
        .ADDR   unknown_96a8_process
@_8218:                                 ;#2B: UNKNOWN
        .ADDR   unknown_8218_process
@boss_jungle:                           ;#2C: boss (Jungle)
        .ADDR   boss_jungle_process
@badnick_yadrin:                        ;#2D: badnick - yadrin (Bridge)
        .ADDR   badnick_yadrin_process
@platform_bridge:                       ;#2E: falling bridge (Bridge)
        .ADDR   platform_bridge_process
@_94a5:                                 ;#2F: UNKNOWN - wave moving projectile?
        .ADDR   unknown_94a5_process
@meta_clouds:                           ;#30: meta - clouds (Sky Base)
        .ADDR   meta_clouds_process
@trap_propeller:                        ;#31: propeller (Sky Base)
        .ADDR   trap_propeller_process
@badnick_bomb:                          ;#32: badnick - bomb (Sky Base)
        .ADDR   mob_badnick_bomb
@trap_cannon:                           ;#33: cannon (Sky Base)
        .ADDR   trap_cannon_process
@trap_cannonBall:                       ;#34: cannon ball (Sky Base)
        .ADDR   trap_cannonball_process
@badnick_unidos:                        ;#35: badnick - unidos (Sky Base)
        .ADDR   badnick_unidos_process
@_b0f4:                                 ;#36: UNKNOWN - stationary, lethal
        .ADDR   unknown_b0f4_process
@trap_turretRotating:                   ;#37: rotating turret (Sky Base)
        .ADDR   trap_turretRotating_process
@platform_flyingRight:                  ;#38: flying platform (Sky Base)
        .ADDR   platform_flyingRight_process
@_b398:                                 ;#39: moving spiked wall (Sky Base)
        .ADDR   trap_spikewall_process
@trap_turretFixed:                      ;#3A: fixed turret (Sky Base)
        .ADDR   trap_turretFixed_process
@platform_flyingUpDown:                 ;#3B: flying platform - up/down (Sky Base)
        .ADDR   platform_flyingUpDown_process
@badnick_jaws:                          ;#3C: badnick - jaws (Labyrinth)
        .ADDR   badnick_jaws_process
@trap_spikeBall:                        ;#3D: spike ball (Labyrinth)
        .ADDR   trap_spikeBall_process
@trap_spear:                            ;#3E: spear (Labyrinth)
        .ADDR   trap_spear_process
@trap_fireball:                         ;#3F: fire ball head (Labyrinth)
        .ADDR   trap_fireball_process
@meta_water:                            ;#40: meta - water line position
        .ADDR   meta_water_process
@powerUp_bubbles:                       ;#41: bubbles (Labyrinth)
        .ADDR   powerups_bubbles_process
@_8eca:                                 ;#42: UNKNOWN
        .ADDR   _8eca
@null:                                  ;#43: NO-CODE
        .ADDR   null_process
@badnick_burrobot:                      ;#44: badnick - burrobot
        .ADDR   badnick_burrobot_process
@platform_float:                        ;#45: platform - float up (Labyrinth)
        .ADDR   platform_float_process
@boss_electricBeam:                     ;#46: boss - electric beam (Sky Base)
        .ADDR   boss_electricBeam_process
@_bcdf:                                 ;#47: UNKNOWN
        .ADDR   unknown_bcdf_process
@boss_bridge:                           ;#48: boss (Bridge)
        .ADDR   mob_boss_bridge
@boss_labyrinth:                        ;#49: boss (Labyrinth)
        .ADDR   mob_boss_labyrinth
@boss_skybase:                          ;#4A: boss (Sky Base)
        .ADDR   boss_skyBase_process
@meta_trip:                             ;#4B: trip zone (Green Hill)
        .ADDR   meta_trip_process
@platform_flipper:                      ;#4C: Flipper (Special Stage)
        .ADDR   platform_flipper_process
@_0000_1                                ;#4D: RESET!
        .ADDR   $0000
@platform_balance:                      ;#4E: balance (Bridge)
        .ADDR   platform_balance_process
@_0000_2                                ;#4F: RESET!
        .ADDR   $0000
@flower:                                ;#50: flower (Green Hill)
        .ADDR   flower_process
@powerUp_checkpoint:                    ;#51: monitor - checkpoint
        .ADDR   powerups_checkpoint_process
@powerUp_continue:                      ;#52: monitor - continue
        .ADDR   powerups_continue_process
@anim_final:                            ;#53: final animation
        .ADDR   cutscene_final_process
@anim_emeralds:                         ;#54: all emeralds animation
        .ADDR   cutscene_emeralds_process
@_7b95:                                 ;#55: "make sonic blink"
        .ADDR   meta_blink_process
        ;

mobBounds:                                                              ;$2BA2
;===============================================================================
; 1.  the X-distance the mob can be left of the camera without despawning
; 2.  the X-distance the mob can be right of the camera without despawning
;     NOTE: this has to include the screen width of $0100 (256)
; 3.  the Y-distance the mob can be above the camera without despawning
; 4.  the Y-distance the mob can be below of the camera without despawning
;     NOTE: this has to include the screen height of $00C0 (192)

        .TABLE  WORD  WORD  WORD  WORD
        .ROW    $0100 $0200 $0100 $0200      ;#00: Sonic
        .ROW    $0020 $0120 $0020 $00E0      ;#01: monitor - ring
        .ROW    $0020 $0120 $0020 $00E0      ;#02: monitor - speed shoes
        .ROW    $0020 $0120 $0020 $00E0      ;#03: monitor - life
        .ROW    $0020 $0120 $0020 $00E0      ;#04: monitor - shield
        .ROW    $0020 $0120 $0020 $00E0      ;#05: monitor - invincibility
        .ROW    $0020 $0120 $0020 $00E0      ;#06: chaos emerald
        .ROW    $0020 $0120 $0060 $00E0      ;#07: end sign
        .ROW    $0010 $0110 $0020 $00E0      ;#08: badnick - crabmeat
        .ROW    $00A0 $01A0 $0040 $0100      ;#09: wooden platform - swinging (Green Hill)
        .ROW    $0040 $0140 $0040 $0100      ;#0A: explosion
        .ROW    $0020 $0120 $0020 $00E0      ;#0B: wooden platform (Green Hill)
        .ROW    $0020 $0120 $0030 $00F0      ;#0C: wooden platform - falling (Green Hill)
        .ROW    $0100 $0200 $0100 $01C0      ;#0D: UNKNOWN
        .ROW    $0040 $0140 $0040 $0100      ;#0E: badnick - buzz bomber
        .ROW    $00A0 $01A0 $0020 $00E0      ;#0F: wooden platform - moving (Green Hill)
        .ROW    $0010 $0110 $0010 $00D0      ;#10: badnick - motobug
        .ROW    $0010 $0110 $0010 $00D0      ;#11: badnick - newtron
        .ROW    $00C0 $01C0 $0080 $0140      ;#12: boss (Green Hill)
        .ROW    $0020 $0120 $0020 $00E0      ;#13: UNKNOWN - bullet?
        .ROW    $0008 $0140 $0010 $00D0      ;#14: UNKNOWN - fireball right?
        .ROW    $0040 $0108 $0010 $00D0      ;#15: UNKNOWN - fireball left?
        .ROW    $0010 $0110 $0020 $00E0      ;#16: flame thrower (Scrap Brain)
        .ROW    $0020 $0120 $0030 $00CC      ;#17: door - one way left (Scrap Brain)
        .ROW    $0020 $0120 $0030 $00CC      ;#18: door - one way right (Scrap Brain)
        .ROW    $0020 $0120 $0030 $00CC      ;#19: door (Scrap Brain)
        .ROW    $0020 $0120 $0020 $00DA      ;#1A: electric sphere (Scrap Brain)
        .ROW    $0030 $0130 $0030 $00F0      ;#1B: badnick - ball hog (Scrap Brain)
        .ROW    $0100 $0180 $0100 $01C0      ;#1C: UNKNOWN - ball from ball hog?
        .ROW    $0010 $0110 $0010 $00D0      ;#1D: switch
        .ROW    $0020 $0120 $0030 $00C8      ;#1E: switch door
        .ROW    $0020 $0120 $0020 $00E0      ;#1F: badnick - caterkiller
        .ROW    $0020 $0120 $0020 $00E0      ;#20: UNKNOWN
        .ROW    $0020 $0120 $0080 $0140      ;#21: moving bumper (Special Stage)
        .ROW    $0010 $0110 $0080 $00F0      ;#22: boss (Scrap Brain)
        .ROW    $0020 $0120 $0010 $00D0      ;#23: free animal - rabbit
        .ROW    $0020 $0120 $0010 $00D0      ;#24: free animal - bird
        .ROW    $0020 $0120 $0020 $00E0      ;#25: capsule
        .ROW    $0010 $0110 $0060 $0100      ;#26: badnick - chopper
        .ROW    $0028 $0128 $0100 $01C0      ;#27: log - vertical (Jungle)
        .ROW    $0028 $0128 $0100 $01C0      ;#28: log - horizontal (Jungle)
        .ROW    $0010 $0110 $0010 $00D0      ;#29: log - floating (Jungle)
        .ROW    $0020 $0120 $0020 $00E0      ;#2A: UNKNOWN
        .ROW    $0010 $0110 $0010 $00D0      ;#2B: UNKNOWN
        .ROW    $0040 $0140 $00C0 $0180      ;#2C: boss (Jungle)
        .ROW    $0010 $0110 $0010 $00D0      ;#2D: badnick - yadrin (Bridge)
        .ROW    $0080 $0180 $0040 $01C0      ;#2E: falling bridge (Bridge)
        .ROW    $0020 $0120 $0020 $00E0      ;#2F: UNKNOWN - wave moving projectile?
        .ROW    $0800 $0800 $0030 $00F0      ;#30: meta - clouds (Sky Base)
        .ROW    $0010 $0110 $0020 $00E0      ;#31: propeller (Sky Base)
        .ROW    $0020 $0120 $0020 $00E0      ;#32: badnick - bomb (Sky Base)
        .ROW    $0000 $0100 $0000 $00C0      ;#33: cannon (Sky Base)
        .ROW    $0200 $0300 $0200 $02C0      ;#34: cannon ball (Sky Base)
        .ROW    $0010 $0110 $0010 $00D0      ;#35: badnick - unidos (Sky Base)
        .ROW    $0040 $0140 $0040 $0100      ;#36: UNKNOWN - stationary, lethal
        .ROW    $0010 $0110 $0010 $00D0      ;#37: rotating turret (Sky Base)
        .ROW    $0040 $0140 $0020 $00E0      ;#38: flying platform (Sky Base)
        .ROW    $0080 $0180 $0050 $00D0      ;#39: moving spiked wall (Sky Base)
        .ROW    $0010 $0110 $0010 $00D0      ;#3A: fixed turret (Sky Base)
        .ROW    $0010 $0110 $0060 $0120      ;#3B: flying platform - up/down (Sky Base)
        .ROW    $0010 $0110 $0010 $00D0      ;#3C: badnick - jaws (Labyrinth)
        .ROW    $0060 $0160 $0060 $0120      ;#3D: spike ball (Labyrinth)
        .ROW    $0010 $0110 $0010 $00D0      ;#3E: spear (Labyrinth)
        .ROW    $0020 $0120 $0020 $00E0      ;#3F: fire ball head (Labyrinth)
        .ROW    $2000 $2100 $0020 $00E0      ;#40: meta - water line position
        .ROW    $0008 $0108 $0008 $00C8      ;#41: bubbles (Labyrinth)
        .ROW    $0020 $0120 $0020 $00E0      ;#42: UNKNOWN
        .ROW    $0020 $0120 $0020 $00E0      ;#43: NO-CODE
        .ROW    $0020 $0120 $0020 $00E0      ;#44: badnick - burrobot
        .ROW    $0028 $0128 $0028 $00E8      ;#45: platform - float up (Labyrinth)
        .ROW    $0060 $0160 $0020 $00E0      ;#46: boss - electric beam (Sky Base)
        .ROW    $0100 $0200 $0100 $01C0      ;#47: UNKNOWN
        .ROW    $0010 $0110 $0010 $00D0      ;#48: boss (Bridge)
        .ROW    $0010 $0110 $0100 $01C0      ;#49: boss (Labyrinth)
        .ROW    $0010 $0110 $0010 $00D0      ;#4A: boss (Sky Base)
        .ROW    $0010 $0110 $0010 $00D0      ;#4B: trip zone (Green Hill)
        .ROW    $0020 $0120 $0020 $00E0      ;#4C: Flipper (Special Stage)
        .ROW    $0020 $0120 $0020 $00E0      ;#4D: RESET!
        .ROW    $0038 $0128 $0030 $00F0      ;#4E: balance (Bridge)
        .ROW    $0020 $0120 $0020 $00E0      ;#4F: RESET!
        .ROW    $0010 $0110 $0010 $00D0      ;#50: flower (Green Hill)
        .ROW    $0020 $0120 $0020 $00E0      ;#51: monitor - checkpoint
        .ROW    $0020 $0120 $0020 $00E0      ;#52: monitor - continue
        .ROW    $0100 $01E0 $00C0 $0180      ;#53: final animation
        .ROW    $0100 $0200 $0100 $01C0      ;#54: all emeralds animation
        .ROW    $0800 $0900 $0800 $08C0      ;#55: "make sonic blink"
        ;

hudRingLayout:                                                          ;$2E52
;===============================================================================
; ring count HUD layout
;
        .BYTE   $A6 $A8 $FF
        ;

hudLivesLayout:                                                         ;$2E55
;===============================================================================
; this is the sprite-layout for the lives display on levels
;
        .BYTE   $A0 $A2 $A4 $00 $FF
        ;

refresh:                                                                ;$2E5A
;===============================================================================
; Updates the game display -- refreshes the lives & time display,
; updates the camera and processes all the mobs in the level
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ;do not update the Sonic sprite frame (upon Interrupt)
        res     7,      [IY+Vars.timeLightningFlags]

        ;populate the buffer with the bytes in the layout
        ld      HL,     hudLivesLayout
        ld      DE,     RAM_LAYOUT_BUFFER
        ld      BC,     _sizeof_hudLivesLayout  ;=5
        ldir                                                    ;TODO: unroll this for speed

        ld      A,      [RAM_LIVES]
        cp      9                                               ;9 lives?
        jr      c,      @_1                                     ;if more than 9 lives,
        ld      A,        9                               ;we will display as 9 lives

@_1:    add     A,      A                                 ;double for the 8x16 sprite lookup
        add     A,        $80                             ;numeral sprites begin at index $80
        ld      [RAM_LAYOUT_BUFFER+3],  A                 ;put number of lives into the buffer

        ld      C,      HUD_LIVES_X     ; x-position of lives display
        ld      B,      HUD_LIVES_Y     ; y-position of lives display
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ; TODO: loading DE not needed
        ; -- we still have this value from before
        ld      DE,     RAM_LAYOUT_BUFFER
        call    layoutSpritesHorizontal

        ld      [RAM_SPRITETABLE_ADDR], HL

        ;-----------------------------------------------------------------------

        ;show rings?
        bit     2,      [IY+Vars.scrollRingFlags]
        call    nz,     displayRingCount

        ;show time?
        bit     5,      [IY+Vars.timeLightningFlags]
        call    nz,     displayTime

        ;-----------------------------------------------------------------------

        ld      DE,     $0060
        ld      HL,     RAM_SCROLLZONE_OVERRIDE_LEFT                ;gets set by moving platforms, e.g. $20
        ld      A,      [HL]                                    ;[$D267]
        inc     HL      ;$D268
        or      [HL]                                            ;[$D268]
        call    z,      updateCamera@_311a                      ;=0?
       ;ld      [HL]                D                           ;[$D268] = $60  `write $6000?
       ;dec     HL      ;$D267          `is this an address?
       ;ld      [HL]    E                                       ;[$D267] = $00
       ;inc     HL      ;$D268

        inc     HL
        ld      DE,     $0088
        ld      A,      [HL]
        inc     HL
        or      [HL]
        call    z,      updateCamera@_311a

        inc     HL
        ld      DE,     $0060
        ld      A,      [HL]
        inc     HL
        or      [HL]
        call    z,      updateCamera@_311a

        inc     HL
        ld      DE,     $0070
        ;up-down wave scrolling?
        bit     6,      [IY+Vars.scrollRingFlags]
        jr      z,      @_2

        ld      DE,     $0080
@_2:    ld      A,       [HL]
        inc     HL
        or      [HL]
        call    z,      updateCamera@_311a

        ;is Sonic alive?
        bit     0,      [IY+Vars.scrollRingFlags]
        call    z,      updateCamera                            ;handle camera movement

        ld      HL,     $0000
        ld      [RAM_SCROLLZONE_OVERRIDE_LEFT],         HL
        ld      [RAM_SCROLLZONE_OVERRIDE_RIGHT],        HL
        ld      [RAM_SCROLLZONE_OVERRIDE_TOP],          HL
        ld      [RAM_SCROLLZONE_OVERRIDE_BOTTOM],       HL

        ;check for mobs that have gone too far off-screen and should be despawned
        call    checkMobsOutOfBounds
        ;run the code for all the different mobs in the level (including the player)
        call    processMobs

        ret
        ;

displayRingCount:                                                       ;$2EE6
;===============================================================================
; Update the player's ring-count on the screen.
;
; TODO: it'll be faster to layout the sprites when the level loads,
;       and just update the indices here
;-------------------------------------------------------------------------------
        ld      A,      [RAM_RINGS]
        ld      C,      A
        rrca
        rrca
        rrca
        rrca
        and     %00001111
        add     A,      A
        add     A,      $80                                     ;TODO: numeral 0 tile index
        ld      [RAM_LAYOUT_BUFFER],    A
        ld      A,      C
        and     %00001111
        add     A,      A
        add     A,      $80                                     ;TODO: numeral 0 tile index
        ld      [RAM_LAYOUT_BUFFER+1],  A
        ld      A,      $FF
        ld      [RAM_LAYOUT_BUFFER+2],  A

        ld      C, 20
        ld      B, 0
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      DE,     hudRingLayout
        call    layoutSpritesHorizontal

        ld      C, 40
        ld      B, 0
        ld      DE,     RAM_LAYOUT_BUFFER
        call    layoutSpritesHorizontal

        ld      [RAM_SPRITETABLE_ADDR], HL

        ret
        ;

displayTime:                                                            ;$2F1F
;===============================================================================
; Draws the level time on the screen.
;
; TODO: It'll be faster to layout the sprites at level load and just update
; the indices here instead of redoing the layout every time
;-------------------------------------------------------------------------------
        ld      HL,     RAM_LAYOUT_BUFFER

        ld      A,      [RAM_TIME_MINUTES]
        and     %00001111
        add     A,      A
        add     A,      $80                             ;TODO: numeral 0 tile index

        ld      [HL],   A
        inc     HL
        ld      [HL],   $B0                             ;TODO: colon tile index
        inc     HL

        ;TODO: a look-up table has to be faster than this...
        ;      (could also lookup straight to the tile index, as calculated below)
        ld      A,      [RAM_TIME_SECONDS]
        ld      C,      A
        srl     A
        srl     A
        srl     A
        srl     A

        ;convert this to a sprite tile index --
        add     A,      A                                       ;doubled because 8x16 sprites
        add     A,      $80                                     ;TODO: base offset of the numeral tiles

        ld      [HL],    A
        inc     HL

        ld      A,      C
        and     %00001111
        add     A,      A
        add     A,      $80                                     ;TODO: base offset of the numeral tiles
        ld      [HL],   A
        inc     HL
        ld      [HL],    $FF                             ;terminate the buffer

        ld      C, 24
        ld      B, 16

        ;are we on the special stage?
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      28
        jr      c,      @_1

        ;position the time in the centre of the screen on special stages
        ;TODO: this is inefficient changing the position twice
        ld      C, 112
        ld      B, 56

@_1:    ld      HL,     [RAM_SPRITETABLE_ADDR]
        ld      DE,     RAM_LAYOUT_BUFFER
        call    layoutSpritesHorizontal
        ld      [RAM_SPRITETABLE_ADDR], HL

        ret
        ;

updateCamera:                                                           ;$2F66
;===============================================================================
; called only by "refresh"
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; if scrolling is locked, do nothing
        ; TODO: we could do this test at the call site
        ; instead and avoid the wasted call/ret?
        bit     6,      [IY+Vars.timeLightningFlags]
        ret     nz

        ; does the camera need to be moved horizontally toward a target?
        ld      HL,     [RAM_CAMERA_X_GOTO]
        ld      A,      L
        or      H
        call    nz,     @scrollCameraTo_horizontal

        ; does the camera need to be moved vertically toward a target?
        ld      HL,     [RAM_CAMERA_Y_GOTO]
        ld      A,      L
        or      H
        call    nz,     @scrollCameraTo_vertical

        ; coalesce scroll zones:
        ;-----------------------------------------------------------------------
        ;
        ;       .-------------------------.
        ;       |  +-------------------+  |     The default Scroll Zone (1)
        ;       |  |2.+-------------+  |  |     expands or contracts to fit
        ;       |  |  |1.           |  |  |     the temporary override
        ;       |  |<-|             |->|  |     Scroll Zone (2)
        ;       |  |  |             |  |  |
        ;       |  |  +-------------+  |  |
        ;       |  +-------------------+  |
        ;       '-------------------------'

        ; manage the region within which Sonic
        ; can be before scrolling the screen?

        ld      HL,     [RAM_SCROLLZONE_OVERRIDE_LEFT]      ;=32
        ld      DE,     [RAM_SCROLLZONE_LEFT]               ;=96
        and     A       ; clear flags, particularly carry
        sbc     HL,     DE
        ; cause the DE value to head towards equality with HL?
        call    nz,     @_315e
        ;---------------v
        ;       jr      c       @_1
        ;       inc     DE
        ;       ret
        ;
        ;._1     dec     DE
        ;       ret

        ld      [RAM_SCROLLZONE_LEFT],  DE

        ld      HL,     [RAM_SCROLLZONE_OVERRIDE_RIGHT]     ;=72
        ld      DE,     [RAM_SCROLLZONE_RIGHT]              ;=136
        and     A                                    ;clear flags, particularly carry
        sbc     HL,     DE
        call    nz,     @_315e
        ld      [RAM_SCROLLZONE_RIGHT], DE

        ld      HL,     [RAM_SCROLLZONE_OVERRIDE_TOP]               ;=48
        ld      DE,     [RAM_SCROLLZONE_TOP]                        ;=96
        and     A                                    ;clear flags, particularly carry
        sbc     HL,     DE
        call    nz,     @_315e
        ld      [RAM_SCROLLZONE_TOP],   DE

        ld      HL,     [RAM_SCROLLZONE_OVERRIDE_BOTTOM]    ;=48
        ld      DE,     [RAM_SCROLLZONE_BOTTOM]             ;=112
        and     A                                    ;clear flags, particularly carry
        sbc     HL,     DE
        call    nz,     @_315e
        ld      [RAM_SCROLLZONE_BOTTOM],DE

        ; check left-hand scroll zone:
        ;-----------------------------------------------------------------------
        ;
        ;       > CameraX  > ScrollZoneX
        ;       .----------+--------------.
        ;       |          |              |
        ;       |  scroll  |              |
        ;       |ZoneOffset|              |
        ;       |--------->|              |
        ;       |          |              |
        ;       |  scroll  |              |
        ;       |   Zone   |              |
        ;       '----------+--------------'

        ld      BC,     [RAM_SCROLLZONE_LEFT]
        ld      DE,     [RAM_SONIC.X]
        ld      HL,     [RAM_CAMERA_X]
        add     HL,     BC
        and     A                                    ;clear flags, particularly carry
        sbc     HL,     DE
        ;if the player is outside of the left-hand scroll zone, skip forward --
        ; (we'll have to check the right-hand scroll zone next)
        jr      c,      @scrollZoneRight

        ;limit the camera to a maximum of 8 pixels per frame: if it could go faster,
        ;then more than one columm of scroll tiles would be required

        ;HL > 255?
        ;TODO: we could use `XOR A` instead of `AND A` above to reset A,
        ;      allowing us to use just `AND H` below to do the zero-check quicker
        ld      A,      H
        and     A
        jr      nz,     @limitScrollLeft

        ld      A,      L
        cp      9                                               ;TODO: shouldn't this be 8?
        jr      c,      @_2

@limitScrollLeft:
        ; limit scroll speed to 8 pixels / frame
        ; -- we can only introduce one column of tiles per-frame!
        ld      HL,     $0008

        ;-----------------------------------------------------------------------

        ; is the camera auto-scrolling to the right?
@_2:    bit     3,      [IY+Vars.scrollRingFlags]
        jr      nz,     @levelLeftLimit

        ; is camera set to smooth scrolling?
        bit     5,      [IY+Vars.scrollRingFlags]
        jr      z,      @_3             ; if not, skip ahead

        ; smooth scrolling: scroll only 1 pixel at a time
        ld      HL, $0001

@_3:    ex      DE,     HL
        ; move camera X position
        ld      HL,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     DE
        ; skip if moving the camera would under/overflow
        jr      c,      @levelLeftLimit
        ; commit the new camera position
        ld      [RAM_CAMERA_X], HL

        ; TODO: this could be a `jr`
        jp      @levelLeftLimit

        ; check right-hand scroll zone:
        ;-----------------------------------------------------------------------
@scrollZoneRight:
        ;       * CameraX       * ScrollZoneX
        ;       .---------------+---------.
        ;       |               |         |
        ;       |     scroll    |         |
        ;       |   ZoneOffset  |         |
        ;       |-------------->|         |
        ;       |               |         |
        ;       |               |  scroll |
        ;       |               |   Zone  |
        ;       '---------------+---------'

        ld      BC,     [RAM_SCROLLZONE_RIGHT]
        ld      HL,     [RAM_CAMERA_X]
        add     HL,     BC
        and     A       ; clear the carry flag
        sbc     HL,     DE
        ; if the player is outside of the right-hand
        ; scroll zone, skip forward
        jr      nc,     @levelLeftLimit

        ; within right-hand scroll zone:
        ; flip all the bits in HL?
        ; TODO: WHY??? Why wouldn't a simple zero check suffice?
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A

        inc     HL
        ld      A,      H
        and     A
        jr      nz,     @limitScrollRight

        ld      A,      L
        cp      $09
        jr      c,      @_6

@limitScrollRight:
        ; limit scroll speed to 8
        ld      HL, $0008

        ; is the camera auto-scrolling to the right?
@_6:    bit     3,      [IY+Vars.scrollRingFlags]
        ; yes? skip ahead
        jr      nz,     @levelLeftLimit

        ; is camera set to smooth scrolling?
        bit     5,      [IY+Vars.scrollRingFlags]
        jr      z,      @checkOverflow

        ; smooth scrolling: scroll only 1 pixel at a time
        ld      HL, $0001

@checkOverflow:
        ; ensure that the camera position won't under/overflow
        ld      DE,     [RAM_CAMERA_X]
        add     HL,     DE
        jr      c,      @levelLeftLimit

        ld      [RAM_CAMERA_X], HL

        ; camera cannot go past left edge of level:
        ;-----------------------------------------------------------------------
        ; note that a Level is a sub-portion of a Floor Layout (more than one
        ; Level can be packed on a Floor Layout), therefore the left-hand edge
        ; of the level is not necessarily 0
@levelLeftLimit:
        ld      HL,     [RAM_CAMERA_X]
        ld      DE,     [RAM_LEVEL_LEFT]
        and     A
        sbc     HL,     DE
        jr      nc,     @levelRightLimit

        ;stop the camera at the level boundary
        ld      [RAM_CAMERA_X], DE
        jr      @cameraY

        ; camera cannot go past right edge of level:
        ;-----------------------------------------------------------------------
@levelRightLimit:
        ld      HL,     [RAM_CAMERA_X]
        ld      DE,     [RAM_LEVEL_RIGHT]
        and     A
        sbc     HL,     DE
        jr      c,      @cameraY

        ; stop the camera at the level boundary
        ld      [RAM_CAMERA_X], DE

@cameraY:
        ;-----------------------------------------------------------------------
        ; is the camera waving up and down?
        bit     6,      [IY+Vars.scrollRingFlags]
        call    nz,     @_3164

        ld      BC,     [RAM_SCROLLZONE_TOP]
        ld      DE,     [RAM_SONIC.Y]
        ld      HL,     [RAM_CAMERA_Y]

        ; is the camera waving up and down?
        bit     6,      [IY+Vars.scrollRingFlags]
        ; -- if so, the top scroll zone is set to a fixed value
        call    nz,     @updateCamera_scrollZone_waving         ;=`ld BC $0020`

        ; is the camera prevented from scrolling down?
        bit     7,      [IY+Vars.scrollRingFlags]
        ; -- if so, the top scroll zone is set to a fixed value
        call    nz,     @updateCamera_scrollZone_noDown         ;=`ld BC $0070`

        ; get the absolute position of the top scroll zone on the Floor Layout
        add     HL,     BC

        ; is the camera prevented from scrolling down?
        bit     7,      [IY+Vars.scrollRingFlags]
        ; -- if so, increase the scroll zone further
        call    z,      @updateCamera_scrollZone_increase

        and     A
        sbc     HL,     DE
        jr      c,      @_13

        ld      C,      $09

        ld      A,      H
        and     A
        jr      nz,     @_10

        ; is the camera waving up and down?
        bit     6,      [IY+Vars.scrollRingFlags]
        call    nz,     @_311f

        ld      A,      L
        cp      C
        jr      c,      @_11

@_10:   dec     C
        ld      L,      C
        ld      H,      $00

        ; is the camera prevented from scrolling down?
@_11:   bit     7,      [IY+Vars.scrollRingFlags]
        jr      z,      @_12

        srl     H
        rr      L
        bit     1,      [IY+Vars.unknown0]
        jr      nz,     @_12

        ld      HL,     $0000

@_12:   ex      DE,     HL
        ld      HL,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        jr      c,      @levelTopLimit

        ld      [RAM_CAMERA_Y], HL
        jp      @levelTopLimit

        ;-----------------------------------------------------------------------

@_13:   ld      BC,     [RAM_SCROLLZONE_BOTTOM]
        ld      HL,     [RAM_CAMERA_Y]
        add     HL,     BC

        ; is the camera prevented from scrolling down?
        bit     7,      [IY+Vars.scrollRingFlags]
        ; if so, increase the scroll zone further
        call    z,      @updateCamera_scrollZone_increase

        and     A
        sbc     HL,     DE
        jr      nc,     @levelTopLimit

        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      C,      $09
        ld      A,      H
        and     A
        jr      nz,     @_14

        bit     6,      [IY+Vars.scrollRingFlags]          ;up-down wave scrolling?
        call    nz,     @_311f
        ld      A,      L
        cp      C
        jr      c,      @_15

@_14:   dec     C
        ld      L,      C
        ld      H,      $00

@_15:   bit     4,      [IY+Vars.scrollRingFlags]          ;auto scroll up?
        jr      nz,     @levelTopLimit

        ld      DE,     [RAM_CAMERA_Y]
        add     HL,     DE
        jr      c,      @levelTopLimit

        ld      [RAM_CAMERA_Y], HL

        ; camera cannot go past top edge of level:
        ;-----------------------------------------------------------------------
@levelTopLimit:
        ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     [RAM_LEVEL_TOP]
        and     A
        sbc     HL,     DE
        jr      nc,     @levelBottomLimit
        ; stop the camera at the level boundary
        ld      [RAM_CAMERA_Y], DE

        ; camera cannot go past bottom edge of level:
        ;-----------------------------------------------------------------------
@levelBottomLimit:
        ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     [RAM_LEVEL_BOTTOM]
        and     A
        sbc     HL,     DE
        jr      c,      @ret                                    ;TODO: use `ret c`?
        ; stop the camera at the level boundary
        ld      [RAM_CAMERA_Y], DE

@ret:   ret

        ; ancillary functions:

@_311a:                                                                 ;$311A
        ;=======================================================================
        ; TODO: this seems very inefficient and should be a macro instead
        ld      [HL],   D
        dec     HL
        ld      [HL],   E
        inc     HL
        ret

@_311f:                                                                 ;$311F
        ;=======================================================================
        ; TODO: this seems very inefficient and should be a macro instead
        ld      C,      $08
        ret

@scrollCameraTo_vertical:                                               ;$3122
        ;=======================================================================
        ; scroll vertically towards the locked camera position
        ld      DE,     [RAM_LEVEL_TOP]
        and     A
        sbc     HL,     DE
        ret     z
        jr      c,      @up

        ; scroll downwards
        inc     DE
        ld      [RAM_LEVEL_TOP],        DE
        ld      [RAM_LEVEL_BOTTOM],     DE
        ret

        ; scroll upwards
@up:    dec     DE
        ld      [RAM_LEVEL_TOP],        DE
        ld      [RAM_LEVEL_BOTTOM],     DE
        ret

@scrollCameraTo_horizontal:                                             ;$3140
        ;=======================================================================
        ; scroll horizontally towards the locked camera position
        ld      DE,     [RAM_LEVEL_LEFT]
        and     A                                               ;reset carry so it doesn't affect `sbc`
        sbc     HL,     DE
        ret     z                                               ;if HL = DE then return -- no change
        jr      c,      @_1a                                    ;is DE > HL?

        inc     DE
        ld      [RAM_LEVEL_LEFT],       DE
        ld      [RAM_LEVEL_RIGHT],      DE
        ret

@_1a:   dec     DE
        ld      [RAM_LEVEL_LEFT],       DE
        ld      [RAM_LEVEL_RIGHT],      DE
        ret

@_315e:                                                                 ;$315E
        ;=======================================================================
        jr      c,      @_1b
        inc     DE
        ret

@_1b:   dec     DE
        ret

@_3164:                                                                 ;$3164
        ;=======================================================================
        ld      HL,     [RAM_D29D]
        ld      DE,     [RAM_TIME]
        add     HL,     DE
        ld      BC,     $0200
        ld      A,      H
        and     A
        jp      p,      @_1c

        neg
        ld      BC,     $FE00

@_1c:   cp      $02
        jr      c,      @_2c

        ld      L,      C
        ld      H,      B

@_2c:   ld      [RAM_D29D],     HL
        ld      C,      L
        ld      B,      H
        ld      HL,     [RAM_D25C]                                  ;between RAM_CAMERA_X & Y
        ld      A,      [RAM_CAMERA_Y+1]                            ;high-byte of RAM_CAMERA_X
        add     HL,     BC
        ld      E,      $00
        bit     7,      B
        jr      z,      @_3c
        ld      E,      $FF
@_3c:   adc     A,      E
        ld      [RAM_D25C],             HL
        ld      [RAM_CAMERA_Y+1],       A
        ld      HL,     [RAM_D2A1]
        ld      A,      [RAM_D2A3]
        add     HL,     BC
        adc     A,      E
        ld      [RAM_D2A1],     HL
        ld      [RAM_D2A3],     A
        ld      HL,     [RAM_D2A2]
        bit     7,      H
        jr      z,      @_4c
        ld      BC,     $FFE0
        and     A
        sbc     HL,     BC
        jr      nc,     @_4c
        ld      HL,     $0002
        ld      [RAM_TIME],     HL
        ret

@_4c:   ld      HL,     [RAM_D2A2]
        ld      BC,     $0020
        and     A
        sbc     HL,     BC
        ret     c
        ld      HL,     $FFFE
        ld      [RAM_TIME],     HL
        ret

@updateCamera_scrollZone_waving:                                        ;$31CF
        ;=======================================================================
        ld      BC,     $0020
        ret

@updateCamera_scrollZone_noDown:                                        ;$31D3
        ;=======================================================================
        ld      BC,      $0070
        ret

@unused_31d7:                                                           ;$31D7
        ;=======================================================================
        ld      BC,     $0070
        ret

@updateCamera_scrollZone_increase:                                      ;$31DB
        ;=======================================================================
        ; not applicable with up-down wave scrolling
        bit     6,      [IY+Vars.scrollRingFlags]
        ret     nz

        ld      BC,     [RAM_D2B7]
        add     HL,     BC

        ret
        ;

checkMobsOutOfBounds:                                                   ;$31E6
;===============================================================================
; Check active mobs to see if they have moved too far off-screen and need to be
; despawned. To avoid slow down, only four mobs are checked per frame.
;
; called only by `refresh`, could be inlined?
;-------------------------------------------------------------------------------
        ; check only 4 mobs per frame:

        ld      A,      [RAM_FRAMECOUNT]
        and     %00000111               ; "MOD 8"
        ; TODO: a look-up table for this multiplication should be faster
        ld      C,      A
        ld      HL,     $0068           ;=104 (size of 4 mob structures)
                                        ; TODO: calculate this dynamically
        call    multiply                ; multiply 104 by the frame number 0-7

        ld      DE,     RAM_SONIC       ; address of first mob's data
        add     HL,     DE              ; offset to the chosen group of 4 mobs
        ex      DE,     HL              ; put this aside for now

        ; skips through the list of current mobs 4 at a time
        ; i.e. mob number 0, 4, 8, 12, 16, 20, 24, 28

        ; TODO: Could transfer the "A MOD 8" result via register I
        ;       to avoid having to redo this calculation
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000111               ; "MOD 8"
        add     A,      A               ; x 2
        add     A,      A               ; x 4
        add     A,      A               ; x 8

        ld      C,      A
        ld      B,      $00
        ld      HL,     RAM_ACTIVEMOBS  ; list of current mob pointers
        add     HL,     BC

        ld      C,      B               ; this will be used to remove mobs
        ld      B,      4               ; load loop counter for 4 mobs

        ; fetch the mob's boundary data:
        ;-----------------------------------------------------------------------
@loop:  ld      A,      [DE]            ; get the mob ID (which type it is)
        cp      $56                     ; > length of the mob code pointers list?
        jp      nc,     @removeMob      ; skip this loop

        ; switch the mob address to IX
        push    DE
        pop     IX

        ; swap BC/DE/HL with their shadow values
        exx

        ; TODO: perhaps a lookup table could be faster here
        add     A,      A               ; double the mob ID
        ld      L',     A               ; put this into HL'
        ld      H',     $00
        add     HL',    HL'             ; ID x 4
        add     HL',    HL'             ; ID x 8, i.e. 8 bytes per ID

        ld      DE',    mobBounds
        add     HL',    DE'             ; offset into the table, 8 bytes per ID

        ; load BC with the first WORD, the maxmimum distance
        ; left of the camera the mob can go before despawning
        ld      C',     [HL']
        inc     HL'
        ld      B',     [HL']

        ; copy the remaining data into the temporary space
        inc     HL'
        ld      DE',    RAM_TEMP1
        ; BUG: this reduces BC' by 6, likely unintended as the leftLimit value
        ;      does not already factor this in and does not benefit from it
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi

        ; left & right bounds:
        ;-----------------------------------------------------------------------
        ; if the camera is near the left edge of the Floor Layout then the mob's
        ; area of off-screen allowance will overhang void-space. we check for
        ; this to avoid miscalculation further down the line
        ld      HL',    [RAM_CAMERA_X]
        xor     A                       ; reset carry flag
        sbc     HL',    BC'
        jr      nc,     @x

        ; the camera is at the left-most side of the floor,
        ; so don't underflow and believe the camera is at the far-right instead
        ld      L',     A
        ld      H',     A
        xor     A

        ; has the mob gone too far left of the camera?
@x:     ld      E',     [IX+Mob.X+0]
        ld      D',     [IX+Mob.X+1]
        sbc     HL',    DE'
        jp      nc,     @removeMobExx   ; if so, remove it

        ; the next WORD is how far right of the camera the mob can go before
        ; despawning. note that this value has the width of the screen included
        ; TODO: would adding 256 to the left limit be faster / good enough?
        ld      HL',    [RAM_TEMP1]
        ld      BC',    [RAM_CAMERA_X]
        add     HL',    BC'
        xor     A                       ; reset carry flag
        sbc     HL',    DE'             ; has the mob gone too far right?
        jp      c,      @removeMobExx   ; if so, remove it

        ;top & bottom bounds:
        ;-----------------------------------------------------------------------

        ; if the camera is near the top edge of the Floor Layout then the mob's
        ; area of off-screen allowance will overhang void-space. we check for
        ; this to avoid miscalculation further down the line
        ld      HL',    [RAM_CAMERA_Y]
        ld      BC',    [RAM_TEMP3]
        sbc     HL',    BC'
        jr      nc,     @y

        ; the camera is at the top-most side of the floor,
        ; so don't underflow and believe the camera is at the bottom instead
        ld      L',     A
        ld      H',     A
        xor     A

@y:     ; has the mob gone too far above the camera?
        ld      E',     [IX+Mob.Y+0]
        ld      D',     [IX+Mob.Y+1]
        sbc     HL',    DE'
        jp      nc,     @removeMobExx   ; if so, remove it

        ; the next WORD is how far below the camera the mob can go before
        ; despawning. note that this value has the height of the screen included

        ; TODO: would adding 192 to the bottom limit be faster / good enough?
        ;       also this would help with dynamically supporting 224-lines

        ld      HL',    [RAM_TEMP4]
        ld      BC',    [RAM_CAMERA_Y]
        add     HL',    BC'
        xor     A
        sbc     HL',    DE'
        jp      c,      @removeMobExx

        ;-----------------------------------------------------------------------

        ; return to the non-shadow BC/DE/HL values
        exx

        ; TODO: why do we need to write the same pointer back again?
        ld      [HL],   E
        inc     HL
        ld      [HL],   D
        inc     HL

        ; move on to the next mob to process
        push    HL
        ld      HL,     $001A           ;=26, size of a mob structure
        add     HL,     DE
        ex      DE,     HL
        pop     HL

        djnz    @loop

        ret

        ; remove the out-of-bounds mob!
        ;-----------------------------------------------------------------------

@removeMobExx:
        ; return to the non-shadow BC/DE/HL values
        exx

@removeMob:
        ; zero out the pointer to the mob in the active mob list
        ld      [HL],   C
        inc     HL
        ld      [HL],   C
        inc     HL

        ; move on to the next mob to process
        push    HL
        ld      HL,     $001A           ;=26, size of a mob structure
        add     HL,     DE
        ex      DE,     HL
        pop     HL

        ; TODO: djnz cannot be used here probably because of >-128 relative
        ;       jump. reorganisation of code might solve this
        dec     B
        jp      nz,     @loop

        ret
        ;

processMobs:                                                            ;$392B
;===============================================================================
; Runs the code for each of the mobs in memory.
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; starting from $D37E (we skip Sonic), read pointers until a non-zero
        ; one is found, or 31 pointers have been read
        ld      HL,     RAM_ACTIVEMOBS+2
        ld      B,      31

        ; read the pointer into DE
@loop:  ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL

        ; is the pointer non-zero?
        ld      A,      E
        or      D
        call    nz,     processMob      ; if so process as a mob

        ; keep reading memory until either something
        ; non-zero is found or we hit $D3BC
        djnz    @loop

        ;-----------------------------------------------------------------------

        ld      A,      [IY+Vars.spriteUpdateCount]
        ld      HL,     [RAM_SPRITETABLE_ADDR]

        push    AF
        push    HL

        ; process the player:
        ld      HL,     $D024           ; TODO: Sonic's sprite table entry (VRAM)
        ld      [RAM_SPRITETABLE_ADDR], HL
        ld      DE,     RAM_SONIC
        call    processMob

        pop     HL
        pop     AF

        ld      [RAM_SPRITETABLE_ADDR], HL
        ld      [IY+Vars.spriteUpdateCount],       A
        ret
        ;

processMob:                                                             ;$32C8
;===============================================================================
; in    DE      Address of a mob structure
;-------------------------------------------------------------------------------
        ld      A,      [DE]            ; get mob from the list
        cp      $FF                     ; ignore mob type $FF
        ret     z

        push    BC
        push    HL

        ; transfer DE (address of the mob) to IX
        push    DE
        pop     IX

        ; double the mob type number and put it into DE
        add     A,      A
        ld      E,      A
        ld      D,      $00

         ;offset into the mob code pointers table
        ld      HL,     mobPointers
        add     HL,     DE

        ; get the mob's code address into HL
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A

        ; once the mob's own code has been run,
        ; handle the common actions for all mobs
        ld      DE,     postProcessMob
        push    DE

        ; run the mob's code
        jp      [HL]
        ;

postProcessMob:                                                         ;$32E2
;===============================================================================
; Once a mob has run its personal code, this routine handles things that all
; mobs share, such as moving the mob and collision with Sonic.
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ;move mob:

        ; TODO: could have a mob flag to mark as stationary and skip this bit,
        ;       alternatively, the callback set up before processing the mob
        ;       could be selected based on the mob's flags

        ; move the mob horizontally
        ld      E,      [IX+Mob.Xspeed+0]
        ld      D,      [IX+Mob.Xspeed+1]
        ld      C,      [IX+Mob.Xdirection]
        ld      L,      [IX+Mob.Xsubpixel]
        ld      H,      [IX+Mob.X+0]
        ld      A,      [IX+Mob.X+1]
        add     HL,     DE
        adc     A,      C

        ld      [IX+Mob.Xsubpixel],     L
        ld      [IX+Mob.X+0],           H
        ld      [IX+Mob.X+1],           A

        ; move the mob vertically
        ld      E,      [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        ld      C,      [IX+Mob.Ydirection]
        ld      L,      [IX+Mob.Ysubpixel]
        ld      H,      [IX+Mob.Y+0]
        ld      A,      [IX+Mob.Y+1]
        add     HL,     DE
        adc     A,      C

        ld      [IX+Mob.Ysubpixel],     L
        ld      [IX+Mob.Y+0],           H
        ld      [IX+Mob.Y+1],           A

        ; does the mob interact with the floor?
        bit     5,      [IX+Mob.flags]
        jp      nz,     @_34e6          ; if not skip over collision handling

        ; find the 'nose' of the mob, according to its direction:
        ;-----------------------------------------------------------------------

        ; divide the mob height by 2 to find its vertical middle point
        ; TODO: would it be worthwhile storing this with the mob
        ;       or using a lookup table?
        ld      B,      $00
        ld      D,      B
        ld      E,      [IX+Mob.height]
        srl     E                       ; divide height by 2

        ; moving left or right?
        bit     7,      [IX+Mob.Xspeed+1]
        jr      nz,     @facingLeft

@facingRight:
        ;- collision will be checked with the right side of the mob
        ld      C,      [IX+Mob.width]
        ld      HL,     Unknown@_411E
        jp      @_2

@facingLeft:
        ; - collision will be checked with the left side of the mob
        ld      C,      $00             ; TODO: B & D are already zero, could use those
        ld      HL,     Unknown@_4020

        ; put aside the 'nose' x-position of the mob
@_2:    ld      [RAM_TEMP3],    BC

        ; clear the flag for mob-collision-with-floor
        res     6,      [IX+Mob.flags]

        push    DE
        push    HL

        ; check for mob collision with Floor:
        ;-----------------------------------------------------------------------

        ; lookup the Block the mob is within
        ; NOTE: `BC` is the pixel x-offset to apply, `DE` is the y-offset
        call    getFloorLayoutRAMAddressForMob
        ; read the Block index from the address returned. this tells us which
        ; Block the mob is within, though a Block is 4x4 Tiles / 32x32 pixels
        ld      E,        [HL]
        ld      D,        $00
        ; TODO: all this solidity pointer lookup could be done away with by
        ;       storing this result in RAM somewhere (or in the level header)
        ld      A,      [RAM_LEVEL_SOLIDITY]; solidity index for the level
        add     A,      A               ; double it for a table look-up
        ld      C,      A               ; transfer value to BC
        ld      B,      D
        ; offset into the solidity table
        ld      HL,     solidityBlocks
        add     HL,     BC
        ; get the level's solidity pointer from the table
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ; look up the block in the level's block solidity table
        add     HL,     DE
        ld      A,      [HL]

        ; the top two bits of the line-solidity are used as flags
        ; - bit 7 : "totally solid", for faster collision checks
        ; - bit 6 : water?
        and     %00111111
        ; put aside the solidity flags for the Block that the mob is within
        ld      [RAM_TEMP6],    A

        pop     HL
        pop     DE

        and     %00111111               ; air (or water), and nothing else?
        ; if there's no flags remaining for this Block,
        ; no kind of collision can be possible, so skip ahead
        jp      z,      @_7

        ; TODO: could we not have used B/C instead of [RAM_TEMP6] here?
        ld      A,      [RAM_TEMP6]
        add     A,      A               ; double it for a look-up table
        ld      C,      A               ; transfer to BC
        ld      B,      $00

        ; TODO: this might not be necessary, D could already be 0?
        ld      D,      B

        ; offset into the lookup table, either "Unknown._411e" (facing right)
        ; or "Unknown._4020" (facing left)
        add     HL,     BC
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A

        ; the data is a per-line solidity lookup!
        ld      A,      [IX+Mob.Y+0]
        add     A,      E               ; get the vertical middle point
        and     %00011111               ; "MOD 32", i.e. position within the Block
        ld      E,      A
        add     HL,     DE              ; find the data for that particuar Block row

        ; bit 7 implies a solid line, collision is unavoidable
        ld      A,      [HL]
        cp      $80
        jp      z,      @_7

        ; if the line is not solid, a collision may or may not
        ; occur depending on the exact position of the mob

        ld      E, A
        and     A
        jp      p,      @_3             ; skip if bit 7 is unset

        ld      D,      $FF

        ; here, D is $00 or $FF?

@_3:    ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ; retrieve the 'nose' position of the mob
        ld      BC,     [RAM_TEMP3]
        add     HL,     BC

        ; facing left or right?
        bit     7,      [IX+Mob.Xdirection]
        jr      nz,     @_4

        ; facing left:
        and     A
        jp      m,      @_5             ; skip if bit 7 is set

        ld      A,      L
        and     %00011111               ; "MOD 32"
        cp      E
        jr      nc,     @_5

        jp      @_7

        ; facing right:
@_4:    and     A
        jp      m,      @_5             ; skip if bit 7 is set

        ld      A,      L
        and     %00011111               ; "MOD 32"
        cp      E
        jr      nc,     @_7

        ; collision:
        ;.......................................................................

        ; set the flag for mob collision with the Floor. this can simply mean
        ; that the mob is standing on the floor rather than "in air"
@_5:    set     6,      [IX+Mob.flags]

        ; clip xPos to whole counts of 32 -- convert xPos to the left-nearest
        ; block (effectively "INT(xPos / 32) * 32")
        ld      A,      L
        and     %11100000

        ld      L,      A
        add     HL,     DE
        and     A                       ; clear carry flag
        sbc     HL,     BC
        ld      [IX+Mob.X+0],   L
        ld      [IX+Mob.X+1],   H

        ld      A,      [RAM_TEMP6]
        ld      E,      A
        ld      D,      $00
        ld      HL,     UnknownCollision@_3FBF
        add     HL,     DE
        ld      C,      [HL]

        ld      [IX+Mob.Xspeed+0],      D
        ld      [IX+Mob.Xspeed+1],      D
        ld      [IX+Mob.Xdirection],    D
        ld      A,      D
        ld      B,      D

        bit     7,      C
        jr      z,      @_6

        ; unused because of the data!?
        dec     A
        dec     B

@_6:    ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        add     HL,     BC
        adc     A,      [IX+Mob.Ydirection]
        ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    A

        ; no collision?
        ;.......................................................................

        ; zero the upper bytes of two sixteen bit words
@_7:    ld      B,      $00
        ld      D, B

        ; negative speed? i.e. is moving up
        bit     7,      [IX+Mob.Yspeed+1]
        jr      nz,     @_8             ; skip the next bit if speed is negative

        ld      C,      [IX+Mob.width]
        srl     C
        ld      E,      [IX+Mob.height]
        ld      HL,     Unknown@_448A
        jp      @_9

@_8:    ld      C,      [IX+Mob.width]
        srl     C
        ld      E,      $00
        ld      HL,     Unknown@_41EC

@_9:    ld      [RAM_TEMP3],    DE
        res     7,      [IX+Mob.flags]
        push    BC
        push    HL
        call    getFloorLayoutRAMAddressForMob
        ld      E,      [HL]
        ld      D,      $00
        ld      A,      [RAM_LEVEL_SOLIDITY]
        add     A,      A
        ld      C,      A
        ld      B,      D
        ld      HL,     solidityBlocks
        add     HL,     BC
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        add     HL,     DE
        ld      A,      [HL]
        and     $3F
        ld      [RAM_TEMP6],    A
        pop     HL
        pop     BC
        and     $3F
        jp      z,      @_34e6
        ld      A,      [RAM_TEMP6]
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      B,      D
        add     HL,     DE
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ld      A,      [IX+Mob.X+0]
        add     A,      C
        and     %00011111
        ld      C,      A
        add     HL,     BC
        ld      A,      [HL]
        cp      $80
        jp      z,      @_34e6
        ld      C,      A
        and     A
        jp      p,      @_10
        ld      B,      $FF
@_10:   ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     [RAM_TEMP3]
        add     HL,     DE
        bit     7,      [IX+Mob.Ydirection]
        jr      nz,     @_11
        and     A
        jp      m,      @_12            ; skip if bit 7 is set
        ld      A,      L
        and     %00011111
        exx
        ld      HL,     [RAM_TEMP6]
        ld      H,      $00
        ld      DE,     UnknownCollision@_3FF0
        add     HL,     DE
        add     A,      [HL]
        exx
        cp      C
        jr      c,      @_34e6
        set     7,      [IX+Mob.flags]
        jp      @_12

@_11:   and     A
        jp      m,      @_12            ; skip if bit 7 is set
        ld      A,      L
        and     %00011111
        exx
        ld      HL,     [RAM_TEMP6]
        ld      H,      $00
        ld      DE,     UnknownCollision@_3FF0
        add     HL,     DE
        add     A,      [HL]
        exx
        cp      C
        jr      nc,     @_34e6
@_12:   ld      A,      L
        and     $E0
        ld      L,      A
        add     HL,     BC
        and     A
        sbc     HL,     DE
        ld      [IX+Mob.Y+0],   L
        ld      [IX+Mob.Y+1],   H
        ld      A,      [RAM_TEMP6]
        ld      E,      A
        ld      D,      $00
        ld      HL,     $3F90           ; data?
        add     HL,     DE
        ld      C,      [HL]
        ld      [IX+Mob.Yspeed+0],      D
        ld      [IX+Mob.Yspeed+1],      D
        ld      [IX+Mob.Ydirection],    D
        ld      A,      D
        ld      B,      D
        bit     7,      C
        jr      z,      @_13
        dec     A
        dec     B
@_13:   ld      L,      [IX+Mob.Xspeed+0]
        ld      H,      [IX+Mob.Xspeed+1]
        add     HL,     BC
        adc     A,      [IX+Mob.Xdirection]
        ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    A

        ; is the mob on-screen?
        ;-----------------------------------------------------------------------

@_34e6: ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     [RAM_CAMERA_Y]
        and     A                       ; clear Carry before subtracting
        sbc     HL,     BC

        ex      DE,     HL

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      BC,     [RAM_CAMERA_X]
        and     A                       ; clear Carry before subtracting
        sbc     HL,     BC

        ; if the mob has a sprite layout,
        ; update the mob's position on the screen
        ld      C,      [IX+Mob.spriteLayout+0]
        ld      B,      [IX+Mob.spriteLayout+1]
        ld      A,      C
        or      B
        call    nz,     processSpriteLayout

        pop     HL
        pop     BC

        ret
        ;

processSpriteLayout:                                                    ;$350F
;===============================================================================
; Puts a mob on screen, combining multiple hardware sprites using a Sprite
; Layout - a list of sprites to arrange in a maximum 6 x 4 layout (note that
; each hardware sprite is 8 x 16, giving a maximum mob size of 48 x 64 px)
;
; in    IY      Address of the common variables (used throughout)
;       HL      X-position to place sprite layout on screen
;       D       ?? (some kind of control flag)
;       E       Y-position to place sprite layout on screen
;       BC      Address of a sprite layout
;-------------------------------------------------------------------------------
        ; store the X-position of the sprite for aligning the rows
        ld      [RAM_TEMP6],    HL

        ; copy BC (address of a sprite layout)
        ; to its shadow value BC'
        push    BC
        exx
        pop     BC'
        exx

        ; rows:
        ;-----------------------------------------------------------------------
        ; there will be 3 rows of double-high (16px) sprites
        ld      B,      0
        ld      C,      3

@_1:    exx     ;-->                    ; switch to BC/DE/HL shadow values

        ld      HL',    [RAM_TEMP6]     ; get the starting X-position
                                        ; (original HL parameter)

        ; if a row begins with $FF, the data ends early.
        ; begin a row with $FE to provide a space without ending the data early

        ld      A,      [BC']           ; get a byte from the sprite layout data

        exx     ;<--                    ; switch to original BC/DE/HL values

        cp      $FF                     ; is the byte $FF?
        ret     z                       ; if so leave

        ; DE is the Y-position, but if D is $FF
        ; then something else unknown happens

        ld      A,      D               ; check the D parameter
        cp      $FF                     ; if D is not $FF
        jr      nz,     @_2             ; then skip ahead a little

        ld      A,      E               ; check the E parameter
        cp      $F0                     ; if it's less than $F0,
        jr      c,      @_5             ; then skip ahead
        jp      @_3

@_2:    and     A                       ; is the sprite byte 0?
        jr      nz,     @_5

        ; exit if the row Y-position is below the screen
        ld      A,      E
        cp      192
        ret     nc

        ; columns:
        ;-----------------------------------------------------------------------
@_3:    ; begin 6 columns of single-width (8px) sprites
        ld      B, 6

@loop:  exx                             ; switch to BC/DE/HL shadow values

        ; has the X-position gone over 255?
        ld      A,      H'              ; check the H parameter
        and     A                       ; is it >0? i.e. HL = $0100
        jr      nz,     @_4             ; if so skip

        ld      A,      [BC']           ; check the current byte of the layout data
        cp      $FE                     ; is it >= than $FE?
        jr      nc,     @_4             ; if so, skip

        ; get the address of the sprite table entry
        ld      DE',    [RAM_SPRITETABLE_ADDR]
        ld      A,      L'              ; take the current X-position
        ld      [DE'],  A               ; and set the sprite's X-position
        inc     E'
        exx
        ld      A,      E               ; get the current Y-position
        exx
        ld      [DE'],  A               ; set the sprite's Y-position
        inc     E'
        ld      A,      [BC']           ; read the layout byte
        ld      [DE'],  A               ; set the sprite index number

        ; move to the next sprite table entry
        inc     E'
        ld      [RAM_SPRITETABLE_ADDR], DE'
        inc     [IY+Vars.spriteUpdateCount]

        ; move across 8 pixels
@_4:    inc     BC'
        ld      DE',    $0008
        add     HL',    DE'

        ; return B to the column count and decrement
        exx
        djnz    @loop

        ; move down 16-pixels
        ld      A,      C
        ex      DE,     HL
        ld      C,      16
        add     HL,     BC
        ex      DE,     HL

        ; any rows remaining?
        ld      C,      A
        dec     C
        jr      nz,     @_1
        ret

        ;-----------------------------------------------------------------------
        ; TODO: need to work this out (when D is $FF)
@_5:    exx
        ex      DE,     HL
        ld      HL,     $0006
        add     HL,     BC
        ld      C,      L
        ld      B,      H
        ex      DE,     HL
        exx
        ld      A,      C
        ex      DE,     HL
        ld      C,      $10
        add     HL,     BC
        ex      DE,     HL
        ld      C,      A
        dec     C
        jr      nz,     @_1

        ret
        ;

_3581:                                                                  ;$3581
;===============================================================================
; in    IY              Address of the common variables (used throughout)
;       RAM_TEMP3       y-position of some kind
;       RAM_TEMP6       y-position of some kind
;       RAM_TEMP1       x-position of some kind
;       RAM_TEMP4       x-position of some kind
;-------------------------------------------------------------------------------
        ld      HL,     [RAM_TEMP3]
        ld      BC,     [RAM_TEMP6]
        add     HL,     BC
        ld      BC,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     BC

        ex      DE,     HL

        ld      HL,     [RAM_TEMP1]
        ld      BC,     [RAM_TEMP4]
        add     HL,     BC
        ld      BC,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     BC
        ld      C,      A
        ld      A,      H
        and     A
        ret     nz

        ld      A,      D
        cp      $FF
        jr      nz,     @_1
        ld      A,      E
        cp      $F0
        ret     c
        jp      @_2

@_1:    and     A
        ret     nz
        ld      A,      E
        cp      $C0
        ret     nc
@_2:    ld      H,      C
        ld      BC,     [RAM_SPRITETABLE_ADDR]
        ld      A,      L
        ld      [BC],   A
        inc     C
        ld      A,      E
        ld      [BC],   A
        inc     C
        ld      A,      H
        ld      [BC],   A
        inc     C
        ld      [RAM_SPRITETABLE_ADDR], BC
        inc     [IY+Vars.spriteUpdateCount]
        ret
        ;

layoutSpritesHorizontal:                                                ;$35CC
;===============================================================================
; Places a set of sprites next to each other, dictated by a small data
; stream of indices, with $FE to leave a blank space and $FF to terminate.
; This routine is typically used to place text and numbers on screen.
;
; in    IY      Address of the common variables (used throughout)
;       B
;       C
;       HL      (SPRITETABLE_ADDR)
;       DE      LAYOUT_BUFFER : $A0, $A2, $A4, ($80 + LIVES * 2), $FF
;-------------------------------------------------------------------------------
        ld      A,      [DE]            ; check the current byte in the list
        cp      $FF                     ; is it an end marker? ($FF)
        ret     z                       ; if so, return

        cp      $FE                     ; special case for $FE command
        jr      z,      @skip           ; (skip ahead)

        ld      [HL],   C
        inc     L
        ld      [HL],   B
        inc     L
        ld      [HL],   A
        inc     L

        inc     [IY+Vars.spriteUpdateCount]

@skip:  inc     DE                      ; move to the next data byte
        ; move right 8 pixels
        ld      A,      C
        add     A,      8
        ld      C,      A
        jp      layoutSpritesHorizontal ; process more sprites in the list
        ;

hitPlayer:                                                              ;$35E5
;===============================================================================
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; is the player already dead?
        bit     0,      [IY+Vars.scrollRingFlags]
        ret     nz      ; if so, leave now

        bit     0,      [IY+Vars.unknown0]
        jp      nz,     _36be

        ld      A,      [RAM_SONIC.flags]
        rrca
        jp      c,      _36be

        and     %00000010
        jp      nz,     _36be

@_35fd:                                                                 ;$35FD
        ;-----------------------------------------------------------------------
        bit     0,      [IY+Vars.flags9]
        ret     nz

        ; is player in damage-state?
        bit     6,      [IY+Vars.flags6]
        ret     nz      ; if so, do not continue

        bit     0,      [IY+Vars.unknown0]
        ret     nz

        bit     5,      [IY+Vars.flags6]
        jr      nz,     dropRings@_367e

        ; has the player any rings?
        ld      A,      [RAM_RINGS]
        and     A
        jr      nz,     dropRings       ; if so, drop them

@kill:  ; kill the player!                                              ;$3618
        ;-----------------------------------------------------------------------
        set     0,      [IY+Vars.scrollRingFlags]

        ; set flag 7 on the mob (mob death state?)
        ld      HL,     RAM_SONIC.flags
        set     7,      [HL]

        ld      HL,     $FFFA
        xor     A       ; set A to zero
        ld      [RAM_SONIC.Yspeed+0],   A
        ld      [RAM_SONIC.Yspeed+1],   HL

        ld      A,      $60
        ld      [RAM_D287],     A

        res     6,      [IY+Vars.flags6]        ; turn off damage-state flag
        res     5,      [IY+Vars.flags6]        ; remove shield
        res     6,      [IY+Vars.flags6]        ; TODO: bug or oversight?
        res     0,      [IY+Vars.unknown0]      ; the 0 byte from the level header

        ; play the death sound effect:
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_DEATH
                rst     $18     ;=rst_playMusic
        .ENDIF

        ret
        ;

dropRings:                                                              ;$3644
;===============================================================================
; lose rings!
;
; in    IX      Address of the current mob being processed
;       IY      Address of the common variables (used throughout)
;       HL      ?
;-------------------------------------------------------------------------------
        ; set player's ring-count to 0
        xor     A
        ld      [RAM_RINGS],    A

        ; find an available unused mob-slot
        call    findEmptyMob
        jr      c,      @_367e

        push    IX
        push    HL
        pop     IX

        ld      [IX+Mob.type],          $55     ; "make Sonic blink"?
        ld      [IX+Mob.unknown11],     $06
        ld      [IX+Mob.unknown12],     $00
        ld      HL,     [RAM_SONIC.X]
        ld      [IX+Mob.X+0],   L
        ld      [IX+Mob.X+1],   H
        ld      HL,     [RAM_SONIC.Y]
        ld      [IX+Mob.Y+0],   L
        ld      [IX+Mob.Y+1],   H
        ld      [IX+Mob.Yspeed+0],      $00
        ld      [IX+Mob.Yspeed+1],      $fc
        ld      [IX+Mob.Ydirection],    $ff
        pop     IX

@_367e: ld      HL,     RAM_SONIC.flags
        ld      DE,     $fffc
        xor     A

        bit     4,      [HL]
        jr      z,      @_1

        ld      DE,     $fffe
@_1:    ld      [RAM_SONIC.Yspeed+0],   A
        ld      [RAM_SONIC.Yspeed+1],   DE
        bit     1,      [HL]
        jr      z,      @_2
        ld      A,      [HL]
        or      $12
        ld      [HL],   A
        xor     A
        ld      DE,     $0002
        jr      @_3

@_2:    res     1,      [HL]
        xor     A
        ld      DE,     $FFFE
@_3:    ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   DE
        res     5,      [IY+Vars.flags6]
        set     6,      [IY+Vars.flags6]
        ld      [IY+Vars.joypad],       $FF

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_11
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret
        ;

_36be:                                                                  ;$36BE
;===============================================================================
; in    IX              Address of the current mob being processed
;       TODO: could we use BC/DE as parameters instead of RAM addresses?
;       RAM_TEMP1       An X-offset to place the explosion in the right place
;       RAM_TEMP2       A Y-offset to place the explosion in the right place
;-------------------------------------------------------------------------------
        ld      [IX+Mob.type],  $0A     ; change mob to explosion

        ; get the X-offset given in the parameter
        ld      A,      [RAM_TEMP1]
        ld      E,      A
        ld      D,      $00

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE

        ld      [IX+Mob.X+0],   L
        ld      [IX+Mob.X+1],   H

        ; get the Y-offset given in the parameter
        ld      A,      [RAM_TEMP2]
        ld      E,      A               ; note that D is still zero

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     DE
        ld      [IX+Mob.Y+0],   L
        ld      [IX+Mob.Y+1],   H

        xor     A
        ld      [IX+Mob.spriteLayout+0],A
        ld      [IX+Mob.spriteLayout+1],A

        ; play the explosion sound:
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

        ; give the player 100 points
        ld      DE,    $0100
        ld      C,    $00
        call    increaseScore

        ret
        ;

getFloorLayoutRAMAddressForMob:                                         ;$36F9
;===============================================================================
; TODO: This whole thing seems highly inefficient
;
; Retrieves an address in the Floor Layout in RAM based on the given mob's
; position. Note that each byte in the Floor Layout represents a 32x32 Block
; (4x4 tiles).
;
; in    IX      Address of the mob to process
;       BC      Horizontal pixel offset to add to the mob's X position before locating tile
;       DE      Vertical pixel offset to add to the mob's Y position before locating tile
;
; out   HL      An address within the Floor Layout in RAM
;-------------------------------------------------------------------------------
        ; how wide is the floor layout?
        ; TODO: we could do this check when loading
        ; a level and store the exact label to jump-to in RAM
        ld      A,      [RAM_LEVEL_FLOORWIDTH]
        cp      128
        jr      z,      @width128
        cp      64
        jr      z,      @width64
        cp      32
        jr      z,      @width32
        cp      16
        jr      z,      @width16

        jp      @width256

@width128:
        ;-----------------------------------------------------------------------
        ; 128 block wide level:
        ;
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     DE
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        and     %10000000
        ld      L,      A
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     BC
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      L,      H
        ld      H,      $00
        add     HL,     DE
        ld      DE,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width64:
        ;-----------------------------------------------------------------------
        ; 64 block wide level:
        ;
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     DE
        ld      A,      L
        add     A,      A
        rl      H
        and     %11000000
        ld      L,      A
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     BC
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      L,      H
        ld      H,      $00
        add     HL,     DE
        ld      DE,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width32:
        ;-----------------------------------------------------------------------
        ; 32 block wide level:
        ;
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     DE
        ld      A,      L
        and     %11100000
        ld      L,      A
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     BC
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      L,      H
        ld      H,      $00
        add     HL,     DE
        ld      DE,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width16:
        ;-----------------------------------------------------------------------
        ; 16 block wide level:
        ;
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     DE
        ld      A,      L
        srl     H
        rra
        and     %11110000
        ld      L,      A
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     BC
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      L,      H
        ld      H,      $00
        add     HL,     DE
        ld      DE,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret

@width256:
        ;-----------------------------------------------------------------------
        ; level is 256 blocks wide:
        ;
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ; add the offset we've been given to aim at the "feet" of the mob
        add     HL,     DE

        ; 16-bit multiply by 8
        ld      A, L
        rlca    ;x2 ...
        rl      H
        rlca    ; x4 ...
        rl      H
        rlca    ; x8
        rl      H

        ; put Y-position aside into DE
        ex      DE,     HL

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ; add the offset we've been given to aim at the "feet" of the mob
        add     HL,     BC

        ; 16-bit multiply by 8
        ld      A, L
        rlca    ; x2 ...
        rl      H
        rlca    ; x4 ...
        rl      H
        rlca    ; x8
        rl      H

        ld      L,      H
        ld      H,      $00
        ld      E,      H
        add     HL,     DE
        ld      DE,     RAM_FLOORLAYOUT
        add     HL,     DE
        ret
        ;

updateSonicSpriteFrame:                                                 ;$37E0
;===============================================================================
; Copy the current Sonic animation frame into VRAM.
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ld      DE,     [RAM_SONIC_CURRENT_FRAME]
        ld      HL,     [RAM_SONIC_PREVIOUS_FRAME]

        ; has the animation advanced a frame?
        and     A                       ; ANDing A with itself resets the flags
        sbc     HL,     DE              ; check the difference in frame counts
        ret     z                       ; exit if no progress

        ld      HL,     $3680           ; location in VRAM of the Sonic sprite
        ex      DE,     HL              ; TODO: make this dynamic, somehow

        ; I can't find an instance where bit 0 of IY+$06 is set,
        ; this may be dead code
        bit     0,      [IY+Vars.flags6]
        jp      nz,     @_2

        ;-----------------------------------------------------------------------
        ld      A,      E               ;=$80
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,      D               ;=$36
        or      %01000000               ; set bit 6 to specify a VDP address
        out     [SMS_PORTS_VDP_CONTROL],A

        xor     A       ; set A to 0
        ld      C,      SMS_PORTS_VDP_DATA
        ld      E,      24

        ; by nature of the way the VDP stores image colours across bit-planes,
        ; and that the Sonic sprite only uses palette indices < 8, the fourth
        ; byte for a tile row is always 0. this is used as a very simple form
        ; of compression on the Sonic sprites in the ROM as the fourth byte is
        ; always excluded from the data
@_1:    outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A
        outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A
        outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A
        outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A

        dec     E
        jp      nz,     @_1

        ld      HL,     [RAM_SONIC_CURRENT_FRAME]
        ld      [RAM_SONIC_PREVIOUS_FRAME],     HL
        ret

        ;-----------------------------------------------------------------------
        ; adds 285 to the frame address. purpose unknown...
@_2:    ld      BC,     $011D
        add     HL,     BC

        ld      A,      E
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,      D
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL],A

        exx
        push    BC
        ld      B,      $18
        exx
        ld      DE,     $FFFA
        ld      C,      $BE
        xor     A

@_3:    outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A
        add     HL,     DE
        outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A
        add     HL,     DE
        outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A
        add     HL,     DE
        outi
        outi
        outi
        out     [SMS_PORTS_VDP_DATA],   A
        add     HL,     DE
        exx
        dec     B
        exx
        jp      nz,     @_3

        exx
        pop     BC
        exx
        ld      HL,     [RAM_SONIC_CURRENT_FRAME]
        ld      [RAM_SONIC_PREVIOUS_FRAME],     HL
        ret
        ;

animateFloorRing:                                                       ;$3879
;===============================================================================
; Updates the rings in the Floor Layout with their next frame of animation.
;-------------------------------------------------------------------------------
        ld      DE,     [RAM_RING_CURRENT_FRAME]
        ld      HL,     [RAM_RING_PREVIOUS_FRAME]

        and     A
        sbc     HL,     DE
        ret     z

        ; TODO: location in VRAM of the ring graphics
        ld      HL,     $1F80
        ex      DE,     HL

        di
        ld      A,      E
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      A,      D
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL],        A
        ld      B,      $20

@loop:  ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        nop
        inc     HL
        ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        nop
        inc     HL
        ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        nop
        inc     HL
        ld      A,      [HL]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     HL
        djnz    @loop

        ei
        ld      HL,     [RAM_RING_CURRENT_FRAME]
        ld      [RAM_RING_PREVIOUS_FRAME],      HL
        ret
        ;

_38b0:                                                                  ;$38B0
;===============================================================================
        ld      HL,     [RAM_D2AB]
        ld      A,      L
        and     %11111000
        ld      L,      A

        ld      DE,     [RAM_CAMERA_X]
        ld      A,      E
        and     %11111000
        ld      E,      A

        xor     A                       ; set A to 0
        sbc     HL,     DE              ; is DE > HL?
        ret     c

        or      H                       ; is H > 0?
        ret     nz

        ld      A,      L
        cp      $08                     ; is L < 8?
        ret     c

        ld      D,      A
        ld      A,      [RAM_VDPSCROLL_HORZ]
        and     %11111000
        ld      E,      A
        add     HL,     DE
        srl     H
        rr      L
        srl     H
        rr      L
        srl     H
        rr      L
        ld      A,      L
        and     %00011111
        add     A,      A
        ld      C,      A
        ld      HL,     [RAM_D2AD]
        ld      A,      L
        and     $F8
        ld      L,      A
        ld      DE,     [RAM_CAMERA_Y]
        ld      A,      E
        and     $F8
        ld      E,      A
        xor     A
        sbc     HL,     DE
        ret     c
        or      H
        ret     nz
        ld      A,      L
        cp      $C0
        ret     nc
        ld      D,      $00
        ld      A,      [RAM_VDPSCROLL_VERT]
        and     $F8
        ld      E,      A
        add     HL,     DE
        srl     H
        rr      L
        srl     H
        rr      L
        srl     H
        rr      L
        ld      A,      L
        cp      $1C
        jr      c,      @_1
        sub     $1C
@_1:    ld      L,      A
        ld      H,      $00
        ld      B,      H
        rrca
        rrca
        ld      H,      A
        and     $C0
        ld      L,      A
        ld      A,      H
        xor     L
        ld      H,      A
        add     HL,     BC
        ld      BC,     SMS_VRAM_SCREEN
        add     HL,     BC
        ld      DE,     [RAM_D2AF]
        ld      B,      $02

@loop:  ld      A,      L
        out     [SMS_PORTS_VDP_CONTROL],A
        ld      A,      H
        or      %01000000
        out     [SMS_PORTS_VDP_CONTROL],A

        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE
        nop
        nop
        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE
        nop
        nop
        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE
        nop
        nop
        ld      A,      [DE]
        out     [SMS_PORTS_VDP_DATA],   A
        inc     DE

        ld      A,      B
        ld      BC,     $0040
        add     HL,     BC
        ld      B,      A
        djnz    @loop

        ret
        ;

detectCollisionWithSonic:                                               ;$3956
;===============================================================================
; Tests to see if the given mob has collided with Sonic.
;
; in    IX              Address of the current mob being processed
;       IY              Address of the common variables (used throughout)
;       RAM_TEMP6       Left indent of the mob, in pixels
;       RAM_TEMP7       Top indent of the mob, in pixels
; out   AF              Carry flag is clear if collision, otherwise set
;-------------------------------------------------------------------------------
        ; is Sonic dead? (no collision detection)
        bit     0,      [IY+Vars.scrollRingFlags]
        scf                             ; return carry flag set (no-collision)
        ret     nz                      ; if Sonic-dead flag on, leave now

        ;-----------------------------------------------------------------------

        ; calculate the right-hand edge of the mob
        ; (mob X-position + mob width)
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.width]
        ld      B,      $00
        add     HL,     BC

        ld      DE,     [RAM_SONIC.X]

        ; is Sonic to the right of the mob?
        xor     A                       ; set A to 0, clearing the carry flag
        sbc     HL,     DE
        ret     c                       ; return carry-set for no-collision

        ;-----------------------------------------------------------------------

        ; calculate the mob's left edge:
        ; note that the mob provides an 'indent'. the sprite may well begin at
        ; a certain X-position but the graphic within may be indented a little
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      A,      [RAM_TEMP6]     ; get the mob's left indent
        ld      C,      A
        add     HL,     BC              ; combine the two

        ; now swap the mob's X-position with the previous calculation of Sonic's
        ; X-position. HL will be Sonic's X-position and DE will be the mob's
        ex      DE,     HL

        ; calculate Sonic's right edge:
        ld      A,      [RAM_SONIC.width]
        ld      C,      A               ; note that B is still 0
        add     HL,     BC

        ; is Sonic to the left of the mob?
        xor     A                       ; set A to 0, clearing the carry flag
        sbc     HL,     DE
        ret     c                       ; return carry-set for no-collision

        ;-----------------------------------------------------------------------

        ; calculate the mob's bottom edge
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      C,      [IX+Mob.height]
        add     HL,     BC

        ld      DE,     [RAM_SONIC.Y]
        xor     A                       ; set A to 0, clearing the carry flag
        sbc     HL,     DE
        ret     c                       ; return carry-set for no-collision

        ; calculate the mob's top edge
        ; (including the indent)
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      A,      [RAM_TEMP7]
        ld      C,      A
        add     HL,     BC

        ex      DE,     HL

        ld      A,      [RAM_SONIC.height]
        ld      C,      A
        add     HL,     BC
        xor     A                       ; set A to 0, clearing the carry flag
        sbc     HL,     DE

        ret     ; return carry-set for no-collision
        ;

increaseRings:                                                          ;$39AC
;===============================================================================
; NOTE: why does this not just use DAA?
;
; in    A       Number of rings to add
;-------------------------------------------------------------------------------
        ; add the given number to the total ring count
        ld      C,      A
        ld      A,      [RAM_RINGS]
        add     A,      C
        ld      C,      A               ; move the new total to C

        and     %00001111               ; look at the last digit $0-$F
        cp      10                      ; is it above $A? (11-16)
        jr      c,      @is100rings

        ld      A,      C
        add     A,      $06             ; TODO: WHY????
        ld      C,      A

@is100rings:
        ;-----------------------------------------------------------------------
        ld      A,      C
        cp      $A0
        jr      c,      @pickupRing     ; if not yet 100, keep going

        ; subtract 100 rings
        sub     $A0
        ld      [RAM_RINGS],    A

        ; add 1 to the lives count
        ld      A,      [RAM_LIVES]
        inc     A
        ld      [RAM_LIVES],    A

        ; play the 1-up sound effect:
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_09
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret

@pickupRing:
        ;-----------------------------------------------------------------------
        ; update the ring total
        ld      [RAM_RINGS],    A
        ; play the pickup-ring sound:
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_02
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

increaseScore:                                                          ;$39D8
;===============================================================================
; in    C       Thousands to add to the score
;       D       Hundreds to add to the score
;       E       Tens to add to the score
;-------------------------------------------------------------------------------
        ld      HL,     RAM_SCORE_TENS  ; read the tens unit of the score
        ld      A,      E               ; handle the amount to add
        add     A,      [HL]            ; add the tens to the score
        daa                             ; adjust to binary-coded-decimal
        ld      [HL],   A               ; save the new tens value

        dec     HL                      ; move down to hundreds units
        ld      A,      D               ; handle the amount to add
        adc     A,      [HL]            ; add the hundreds to the score
        daa                             ; adjust to binary-coded-decimal
        ld      [HL],   A               ; save the new hundreds value

        dec     HL                      ; move down to thousands units
        ld      A,      C               ; handle the amount to add
        adc     A,      [HL]            ; add the thousands to the score
        daa                             ; adjust to binary-coded-decimal
        ld      [HL],   A               ; save the new thousands value

        ; push the current thousands value to the side
        ld      C,    A

        dec     HL                      ; move down to millions units
        ld      A,     $00
        adc     A,     [HL]
        daa
        ld      [HL],     A

        ;-----------------------------------------------------------------------

        ; check if current score qualifies for an extra life
        ld      HL,     RAM_SCORE_1UP
        ld      A,      C
        cp      [HL]
        ret     c

        ; increase the score requirement
        ; for an extra life to the next multiple
        ld      A,      SCORE_1UP_PTS
        add     A,      [HL]
        daa                             ; adjust to binary-coded-decimal
        ld      [HL],   A

        ; add an extra life
        ld      HL,     RAM_LIVES
        inc     [HL]

        ; play extra life sound effect:
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_09
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

updateTime:                                                             ;$3A03
;===============================================================================
; called only by `_LABEL_1CED_131`; main game loop?
;
; in    IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        ; is Sonic dead? if so, exit now
        bit     0,      [IY+Vars.scrollRingFlags]
        ret     nz

        ; address of level time?
        ld      HL,     RAM_TIME_FRAMES

        ; is the time counting down? (special stages)
        bit     0,      [IY+Vars.timeLightningFlags]
        jr      nz,     @countdown

        ; time is counting up:
        ;-----------------------------------------------------------------------
        ; wait 60 frames for a second
        ; (TODO: detect PAL/NTSC and use the correct frame rate?)
        ;
        ld      A,      [HL]            ; load the current frame-count
        inc     A                       ; add another frame
        cp      60                      ; is it 60 or less?
        jr      c,      @_1             ; if so, keep going
        xor     A                       ; otherwise, set frame-count to 0
@_1:    ld      [HL],   A               ; update the frame counter

        ; increase seconds counter:
        dec     HL                      ; move down to the seconds counter
        ccf                             ; flip the carry flag
        ld      A,      [HL]            ; read the number of seconds
        adc     A,      $00             ; if frame count hit 60, add a second
        daa                             ; adjust up to binary-coded-decimal
        cp      $60                     ; 60 seconds? (BCD)
        jr      c,      @_2             ; if not, keep going
        xor     A                       ; otherwise, set A to 0
@_2:    ld      [HL],   A               ; update the seconds counter

        ; increase minutes counter:
        dec     HL                      ; move down to the minute counter
        ccf                             ; flip the carry flag
        ld      A,      [HL]            ; read the number of minutes
        adc     A,      $00             ; if seconds hit 60, add a minute
        daa                             ; adjust up to binary-coded-decimal
        cp      $10                     ; 10 minutes?
        jr      c,      @_3             ; if not, keep going

        push    HL                      ; put the minute counter addr aside
        call    hitPlayer@kill          ; go do out-of-time
        pop     HL                      ; go back to the minute counter addr
        xor     A                       ; reset to 0

@_3:    ld      [HL],   A               ; update the minute counter
        ret                             ; exit!

        ; time is counting down:
        ;-----------------------------------------------------------------------
@countdown:
        ; wait 60 frames for a second
        ; (TODO: this is a repeat of above, so could be re-organised to share)

        ld      A,      [HL]            ; load the current frame-count
        inc     A                       ; add another frame
        cp      60                      ; is it 60 or less?
        jr      c,      @_5             ; if so, keep going
        xor     A                       ; otherwise, set frame-count to 0
@_5:    ld      [HL],   A               ; update the frame counter

        dec     HL                      ; move down to the seconds counter
        ccf                             ; flip the carry flag
        ld      A,      [HL]            ; read the number of seconds
        sbc     A,      $00             ; if frame count hit 60 remove a second
        daa                             ; adjust up to binary-coded-decimal
        cp      $60                     ; when seconds hit zero, no carry
        jr      c,      @_6             ; above 0 seconds, keep going
        ld      A,      $59             ; otherwise, loop around to 59 seconds
@_6:    ld      [HL],   A               ; update the seconds counter

        dec     HL                      ; move down to the minutes counter
        ccf                             ; flip the carry flag
        ld      A,      [HL]            ; read the number of minutes
        sbc     A,      $00             ; if seconds hit 0, remove a minute
        daa                             ; adjust up to binary-coded-decimal
        cp      $60                     ; when minutes hit zero, no carry
        jr      c,      @_7             ; above 0 minutes, keep going

        ; set some flags?
        ld      A,      $01
        ld      [RAM_D289],     A
        set     2,      [IY+Vars.flags9]

        xor     A
@_7:    ld      [HL],   A

        ret
        ;

_3a62:                                                                  ;$3A62
;===============================================================================
        ; seemingly unused?
        .BYTE   $01 $30 $00
        ;

solidityBlocks:                                                         ;$3A65
;===============================================================================
; solidity pointer table
;
        ;TODO: this should be populated by the tilesets
        .ADDR   @greenHill     @bridge        @jungle
        .ADDR   @labyrinth     @scrapBrain    @skyBaseInterior
        .ADDR   @specialStage  @skyBaseExterior

        ;00 = sky
        ;16 = solid
        ;10 = flat ground
        ;08 = slope up 1
        ;09 = slope up 2
        ;0A = slope up 3
        ;05 = slope down 1
        ;06 = slope down 2
        ;07 = slope down 3
        ;03 = slope steep up 1
        ;04 = slope steep up 2
        ;01 = slope steep down 1
        ;02 = slope steep down 2
        ;0C = dip down 1
        ;0D = dip up 1
        ;0E = dip down 2
        ;0F = dip up 2
        ;0B = dip
        ;12 = Edge down
        ;15 = Edge up
        ;1E = ceiling
        ;11 = ramp
        ;27 = ? (also ground)
        ;14 = edge ground

@greenHill:                                                             ;$3A75
;-------------------------------------------------------------------------------
        ; TODO: the order of these numbers is determined by the Block Mappings,
        ;       how do we propagate the definition and order?

        .BYTE   $00 $16 $10 $10 $10 $00 $00 $08 $09 $0A $05 $06 $07 $03 $04 $01
        .BYTE   $02 $10 $00 $00 $00 $10 $10 $00 $00 $00 $10 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $10 $00 $00 $00 $00 $00 $00 $00 $10 $10 $0C
        .BYTE   $0D $0E $0F $0B $10 $10 $10 $10 $00 $10 $10 $10 $00 $10 $10 $10
        .BYTE   $10 $10 $10 $10 $10 $16 $16 $12 $10 $15 $00 $00 $10 $16 $1E $16
        .BYTE   $11 $10 $00 $10 $10 $1E $1E $1E $10 $1E $00 $00 $16 $1E $16 $1E
        .BYTE   $00 $27 $1E $00 $27 $27 $27 $27 $27 $16 $27 $27 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $14 $00 $00 $05 $0A $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $80 $80 $90 $80 $96 $90 $80 $90 $80 $80 $80 $A7 $A7 $A7 $A7 $A7
        .BYTE   $A7 $A7 $A7 $A7 $A7 $00 $00 $00 $00 $90 $9E $80 $80 $80 $80 $80
        .BYTE   $90 $00 $00 $00 $00 $00 $00 $00

@bridge:                                                                ;$3B2D
;-------------------------------------------------------------------------------
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $13 $10 $12 $12 $13 $00 $00 $00 $00 $00 $00 $10 $10 $00 $00 $00
        .BYTE   $12 $13 $10 $13 $12 $00 $00 $00 $07 $2B $00 $00 $08 $00 $09 $06
        .BYTE   $05 $29 $10 $2A $0A $00 $00 $00 $10 $10 $2E $00 $2D $00 $00 $00
        .BYTE   $00 $00 $80 $80 $80 $00 $80 $80 $80 $80 $00 $00 $80 $00 $00 $80
        .BYTE   $2C $27 $10 $00 $00 $00 $80 $80 $10 $16 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $12 $10 $13 $00 $00 $10 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $13 $16 $16 $12 $00 $00 $00 $00 $10 $2D $2E $00 $00 $00 $00 $00

@jungle:                                                                ;$3BBD
;-------------------------------------------------------------------------------
        .BYTE   $00 $10 $00 $00 $00 $00 $00 $00 $10 $10 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $10 $10 $10 $10 $10 $10 $10 $16 $16 $16 $16 $27 $16
        .BYTE   $1E $10 $10 $00 $00 $00 $00 $00 $00 $10 $00 $00 $10 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $27 $00 $00 $10
        .BYTE   $11 $00 $01 $00 $00 $10 $10 $00 $04 $01 $02 $03 $06 $07 $05 $08
        .BYTE   $09 $0A $10 $0E $0F $05 $0A $04 $01 $10 $10 $17 $00 $0B $05 $14
        .BYTE   $0A $00 $10 $27 $10 $00 $00 $00 $10 $1E $00 $10 $10 $00 $00 $10
        .BYTE   $10 $10 $00 $00 $00 $1E $00 $27 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $80 $80 $80 $80 $80 $A7 $80 $27 $A7 $A7 $A7 $A7 $A7 $A7 $A7
        .BYTE   $A7 $A7 $80 $80 $10 $10 $96 $96 $16 $16 $16 $16 $00 $00 $00 $00

@labyrinth:                                                             ;$35CD
;-------------------------------------------------------------------------------
        .BYTE   $00 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16
        .BYTE   $16 $16 $16 $16 $16 $16 $16 $16 $00 $00 $00 $00 $00 $00 $80 $27
        .BYTE   $00 $00 $00 $00 $00 $00 $80 $27 $00 $00 $00 $00 $00 $27 $A7 $16
        .BYTE   $00 $00 $1E $27 $00 $1E $00 $27 $00 $27 $00 $16 $27 $27 $9E $80
        .BYTE   $1E $1E $1E $16 $16 $16 $16 $16 $27 $1E $1E $16 $16 $16 $16 $16
        .BYTE   $06 $07 $00 $00 $08 $09 $02 $01 $12 $05 $14 $15 $0A $13 $04 $03
        .BYTE   $04 $00 $04 $03 $08 $09 $06 $07 $03 $01 $02 $01 $0A $06 $09 $05
        .BYTE   $00 $00 $04 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $16 $16 $10 $16 $16 $16 $16 $16 $00 $27 $16 $16 $16 $16 $00
        .BYTE   $1E $00 $27 $1E $00 $1E $00 $00 $01 $04 $01 $04 $09 $06 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $A8 $00 $00 $00 $00 $00 $00 $00

@scrapBrain:                                                            ;$3D0D
;-------------------------------------------------------------------------------
        .BYTE   $00 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $1E $1E $1E $1A
        .BYTE   $1B $1C $1D $1F $20 $21 $22 $23 $24 $1B $1C $16 $1E $1E $1E $1E
        .BYTE   $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16 $27
        .BYTE   $27 $27 $04 $03 $02 $01 $08 $09 $0A $05 $06 $07 $0A $05 $03 $02
        .BYTE   $15 $14 $16 $16 $13 $12 $10 $10 $10 $10 $10 $10 $10 $10 $16 $27
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $1E $00 $1E $1E $1E $00 $00 $10 $80 $80 $27 $27 $27
        .BYTE   $16 $16 $27 $27 $27 $1E $1E $16 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $02 $03 $90 $80 $9E $16 $16 $02 $03 $1B $1C $16 $16 $19 $18
        .BYTE   $25 $26 $00 $00 $00 $27 $27 $1E $1E $27 $1E $00 $00 $00 $00 $1E
        .BYTE   $27 $1E $27 $9E $9E $16 $16 $00 $00 $1E $16 $1E $1E $90 $90 $90
        .BYTE   $16 $16 $16 $16 $00 $00 $00 $00 $A7 $9E $00

@skyBaseInterior:                                                       ;$3DC8
;-------------------------------------------------------------------------------
        .BYTE   $00 $10 $16 $16 $10 $10 $10 $10 $10 $00 $00 $16 $16 $1E $00 $00
        .BYTE   $00 $00 $10 $10 $10 $00 $90 $80 $1E $00 $00 $00 $10 $10 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $03 $04 $00 $00 $08 $09 $0A $16 $13
        .BYTE   $15 $02 $01 $00 $07 $06 $05 $16 $14 $12 $0A $05 $10 $10 $00 $00
        .BYTE   $03 $02 $10 $00 $00 $10 $00 $00 $00 $00 $00 $00 $00 $00 $10 $10
        .BYTE   $10 $00 $00 $10 $00 $10 $00 $00 $00 $10 $10 $10 $10 $16 $16 $04
        .BYTE   $03 $03 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $10 $10 $16 $00 $10 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $16 $00 $00 $00 $00 $00 $00 $00 $00 $10 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $1E $00 $00 $00 $1E $1E $10 $00 $00 $10 $10 $1E $1E $16 $16
        .BYTE   $1E $1E $1E $1E $1E $00 $10 $1E $1E $10 $10 $1E $00 $02 $0A $16
        .BYTE   $00 $00 $00 $00 $00 $00 $10 $1E $16 $1E $00 $10 $10 $10 $10 $10
        .BYTE   $1E $00 $10 $00 $00 $10 $10 $10 $10 $1E $90 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $9E $1E $00 $00 $00 $00 $00 $00 $00 $00 $00

@specialStage:                                                          ;$3EA8
;-------------------------------------------------------------------------------
        .BYTE   $00 $27 $27 $27 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $1E $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $27 $00 $00 $00 $00 $00 $27 $27 $16 $00 $00 $00
        .BYTE   $27 $1E $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00

@skyBaseExterior:                                                       ;$3F28
;-------------------------------------------------------------------------------
        .BYTE   $00 $27 $27 $16 $1E $1E $16 $27 $27 $1E $1E $00 $00 $16 $27 $27
        .BYTE   $16 $1E $1E $16 $16 $16 $16 $01 $02 $04 $03 $1D $1C $1A $1B $01
        .BYTE   $02 $04 $03 $1D $1C $1A $1B $00 $00 $00 $00 $00 $00 $00 $16 $9E
        .BYTE   $9E $80 $1E $27 $A7 $A7 $80 $80 $16 $16 $80 $1E $1E $27 $27 $27
        .BYTE   $16 $1E $16 $16 $16 $16 $16 $16 $27 $00 $1E $00 $00 $00 $00 $00
        .BYTE   $00 $00 $16 $16 $16 $16 $16 $16 $16 $16 $A7 $A7 $9E $9E $16 $00
        .BYTE   $9E $A7 $80 $9E $A7 $80 $00 $00 $00 $1C $1C $E4 $E4 $12 $12 $12
        .BYTE   $EE $EE $EE $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $12 $EE $00 $00 $00 $00
        ;

UnknownCollision:                                                       ;$3FBF
;===============================================================================
@_3FBF: ; 47 entries, according to number of solidity types             ;$3FBF
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00

        ; junk data?
        .BYTE   $00 $00
        
@_3FF0: ; 47 entries, according to number of solidity types             ;$3FF0
        .BYTE   $00 $08 $08 $08 $08 $06 $06 $06 $06 $06 $06 $03 $03 $03 $03 $03

.BANK   1       SLOT    "SLOT1"
.ORG    $0000
                                                                        ;$4000
        .BYTE   $03 $08 $03 $03 $03 $03 $03 $03 $00 $00 $00 $00 $00 $00 $00 $00 
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $03 $03 $04 $04 $03 $03 $03 $03

        ; junk data?
        .BYTE   $00
        ;

; referenced by "postProcessMob"
; something to do with mob floor collision

Unknown:                                                                ;$4020
;===============================================================================

        ; this is a lookup table using block solidity as index
@_4020: .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_407E  ;$4020
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_409E @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_40BE @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_40DE
        .ADDR   @_40FE @_407E @_407E @_407E @_407E @_407E @_407E


@_407E: .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 ;=$80                  `$407E
        .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000
        .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000
        .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000

@_409E: .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 ;=$1C                  `$409E
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100

@_40BE: .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 ;=$1C                  `$40BE
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100
        .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 ;=$80
        .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000

@_40DE: .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 ;=$80                  `$40DE
        .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 ;=$1C
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100

@_40FE: .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 ;=$80                  `$40FE
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 ;=$1C
        .BYTE   %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 %00011100 ;=$1C
        .BYTE   %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 %10000000 ;=$80

        ;-----------------------------------------------------------------------

@_411E: .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_407E         ;$411E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_417C @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_418C @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_41AC
        .ADDR   @_41CC @_407E @_407E @_407E @_407E @_407E @_407E

@_417C: .BYTE   $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 ;$417C

@_418C: .BYTE   $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 ;$418C
        .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 

@_41AC: .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 ;$41AC
        .BYTE   $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 $04 

@_41CC: .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $04 $04 $04 $04 $04 $04 $04 $04 ;$41CC
        .BYTE   $04 $04 $04 $04 $04 $04 $04 $04 $80 $80 $80 $80 $80 $80 $80 $80

        ;-----------------------------------------------------------------------

@_41EC: .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_407E         ;$41EC
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_424A @_407E
        .ADDR   @_426A @_428A @_42AA @_42CA @_42EA @_430A @_432A @_434A
        .ADDR   @_436A @_438A @_43AA @_43CA @_43EA @_440A @_442A @_444A
        .ADDR   @_446A @_407E @_407E @_407E @_407E @_407E @_407E
        

@_424A: .BYTE   $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F ;$424A
        .BYTE   $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F

@_426A: .BYTE   $18 $18 $17 $17 $16 $16 $15 $15 $14 $14 $13 $13 $12 $12 $11 $11 ;$426A
        .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10

@_428A: .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 ;$428A
        .BYTE   $11 $11 $12 $12 $13 $13 $14 $14 $15 $15 $16 $16 $17 $17 $18 $18

@_42AA: .BYTE   $0F $0E $0D $0C $0B $0A $09 $08 $07 $06 $05 $04 $03 $02 $01 $00 ;$42AA
        .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80

@_42CA: .BYTE   $2F $2E $2D $2C $2B $2A $29 $28 $27 $26 $25 $24 $23 $22 $21 $20 ;$42CA
        .BYTE   $1F $1E $1D $1C $1B $1A $19 $18 $17 $16 $15 $14 $13 $12 $11 $10

@_42EA: .BYTE   $10 $11 $12 $13 $14 $15 $16 $17 $18 $19 $1A $1B $1C $1D $1E $1F ;$42EA
        .BYTE   $20 $21 $22 $23 $24 $25 $26 $27 $28 $29 $2A $2B $2C $2D $2E $2F

@_430A: .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 ;$430A
        .BYTE   $00 $01 $02 $03 $04 $05 $06 $07 $08 $09 $0A $0B $0C $0D $0E $0F

@_432A: .BYTE   $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F ;$432A
        .BYTE   $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F $0F

@_434A: .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 ;$434A
        .BYTE   $00 $00 $01 $01 $02 $02 $03 $03 $04 $04 $05 $05 $06 $06 $07 $07

@_436A: .BYTE   $08 $08 $09 $09 $0A $0A $0B $0B $0C $0C $0D $0D $0E $0E $0F $0F ;$436A
        .BYTE   $10 $10 $11 $11 $12 $12 $13 $13 $14 $14 $15 $15 $16 $16 $17 $17

@_438A: .BYTE   $18 $18 $19 $19 $1A $1A $1B $1B $1C $1C $1D $1D $1E $1E $1F $1F ;$438A
        .BYTE   $20 $20 $21 $21 $22 $22 $23 $23 $24 $24 $25 $25 $26 $26 $27 $27

@_43AA: .BYTE   $27 $27 $26 $26 $25 $25 $24 $24 $23 $23 $22 $22 $21 $21 $20 $20 ;$43AA
        .BYTE   $1F $1F $1E $1E $1D $1D $1C $1C $1B $1B $1A $1A $19 $19 $18 $18

@_43CA: .BYTE   $17 $17 $16 $16 $15 $15 $14 $14 $13 $13 $12 $12 $11 $11 $10 $10 ;$43CA
        .BYTE   $0F $0F $0E $0E $0D $0D $0C $0C $0B $0B $0A $0A $09 $09 $08 $08

@_43EA: .BYTE   $07 $07 $06 $06 $05 $05 $04 $04 $03 $03 $02 $02 $01 $01 $00 $00 ;$43EA
        .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80

@_440A: .BYTE   $08 $08 $09 $09 $0A $0A $0B $0B $0C $0C $0D $0D $0E $0E $0F $0F ;$440A
        .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10

@_442A: .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 ;$442A
        .BYTE   $0F $0F $0E $0E $0D $0D $0C $0C $0B $0B $0A $0A $09 $09 $08 $08

@_444A: .BYTE   $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F ;$444A
        .BYTE   $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F $1F

@_446A: .BYTE   $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 ;$446A
        .BYTE   $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17 $17

        ;-----------------------------------------------------------------------

@_448A: .ADDR   @_407E @_44E8 @_4508 @_4528 @_4548 @_4568 @_4588 @_45A8         ;$448A
        .ADDR   @_45C8 @_45E8 @_4608 @_4628 @_4648 @_4668 @_4688 @_46A8
        .ADDR   @_46C8 @_46E8 @_4708 @_4728 @_4748 @_4768 @_4788 @_47A8
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_407E
        .ADDR   @_407E @_407E @_407E @_407E @_407E @_407E @_407E @_47C8
        .ADDR   @_47E8 @_4808 @_4828 @_4848 @_4868 @_4888 @_48A8


@_44E8: .BYTE   $10 $11 $12 $13 $14 $15 $16 $17 $18 $19 $1A $1B $1C $1D $1E $1F ;$44E8
        .BYTE   $20 $21 $22 $23 $24 $25 $26 $27 $28 $29 $2A $2B $2C $2D $2E $2F

@_4508: .BYTE   $F0 $F1 $F2 $F3 $F4 $F5 $F6 $F7 $F8 $F9 $FA $FB $FC $FD $FE $FF ;$4508
        .BYTE   $00 $01 $02 $03 $04 $05 $06 $07 $08 $09 $0A $0B $0C $0D $0E $0F

@_4528: .BYTE   $0F $0E $0D $0C $0B $0A $09 $08 $07 $06 $05 $04 $03 $02 $01 $00 ;$4528
        .BYTE   $FF $FE $FD $FC $FB $FA $F9 $F8 $F7 $F6 $F5 $F4 $F3 $F2 $F1 $F0

@_4548: .BYTE   $2F $2E $2D $2C $2B $2A $29 $28 $27 $26 $25 $24 $23 $22 $21 $20 ;$4548
        .BYTE   $1F $1E $1D $1C $1B $1A $19 $18 $17 $16 $15 $14 $13 $12 $11 $10

@_4568: .BYTE   $F8 $F8 $F9 $F9 $FA $FA $FB $FB $FC $FC $FD $FD $FE $FE $FF $FF ;$4568
        .BYTE   $00 $00 $01 $01 $02 $02 $03 $03 $04 $04 $05 $05 $06 $06 $07 $07

@_4588: .BYTE   $08 $08 $09 $09 $0A $0A $0B $0B $0C $0C $0D $0D $0E $0E $0F $0F ;$4588
        .BYTE   $10 $10 $11 $11 $12 $12 $13 $13 $14 $14 $15 $15 $16 $16 $17 $17

@_45A8: .BYTE   $18 $18 $19 $19 $1A $1A $1B $1B $1C $1C $1D $1D $1E $1E $1F $1F ;$45A8
        .BYTE   $20 $20 $21 $21 $22 $22 $23 $23 $24 $24 $25 $25 $26 $26 $27 $27

@_45C8: .BYTE   $27 $27 $26 $26 $25 $25 $24 $24 $23 $23 $22 $22 $21 $21 $20 $20 ;$45C8
        .BYTE   $1F $1F $1E $1E $1D $1D $1C $1C $1B $1B $1A $1A $19 $19 $18 $18

@_45E8: .BYTE   $17 $17 $16 $16 $15 $15 $14 $14 $13 $13 $12 $12 $11 $11 $10 $10 ;$45E8
        .BYTE   $0F $0F $0E $0E $0D $0D $0C $0C $0B $0B $0A $0A $09 $09 $08 $08

@_4608: .BYTE   $07 $07 $06 $06 $05 $05 $04 $04 $03 $03 $02 $02 $01 $01 $00 $00 ;$4608
        .BYTE   $FF $FF $FE $FE $FD $FD $FC $FC $FB $FB $FA $FA $F9 $F9 $F8 $F8

@_4628: .BYTE   $10 $10 $10 $10 $10 $10 $10 $11 $11 $11 $11 $11 $12 $12 $12 $12 ;$4628
        .BYTE   $12 $12 $12 $12 $12 $11 $11 $11 $11 $11 $10 $10 $10 $10 $10 $10

@_4648: .BYTE   $10 $10 $10 $10 $10 $10 $10 $11 $11 $11 $11 $11 $12 $12 $12 $12 ;$4648
        .BYTE   $13 $13 $13 $14 $14 $15 $15 $15 $16 $16 $16 $17 $17 $17 $17 $17

@_4668: .BYTE   $17 $17 $17 $17 $17 $16 $16 $16 $15 $15 $15 $14 $14 $13 $13 $13 ;$4668
        .BYTE   $12 $12 $12 $12 $11 $11 $11 $11 $11 $10 $10 $10 $10 $10 $10 $10

@_4688: .BYTE   $08 $08 $08 $08 $08 $08 $08 $09 $09 $09 $09 $09 $0A $0A $0A $0A ;$4688
        .BYTE   $0B $0B $0B $0C $0C $0D $0D $0D $0E $0E $0E $0F $0F $0F $0F $0F

@_46A8: .BYTE   $0F $0F $0F $0F $0F $0E $0E $0E $0D $0D $0D $0C $0C $0B $0B $0B ;$46A8
        .BYTE   $0A $0A $0A $0A $09 $09 $09 $09 $09 $08 $08 $08 $08 $08 $08 $08

@_46C8: .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 ;$46C8
        .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10

@_46E8: .BYTE   $10 $11 $12 $13 $14 $15 $16 $17 $18 $19 $19 $1A $1A $1A $1B $1B ;$46E8
        .BYTE   $1B $1B $1B $1A $1A $1A $19 $19 $18 $17 $16 $14 $11 $10 $10 $10

@_4708: .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 ;$4708
        .BYTE   $11 $11 $12 $12 $13 $13 $14 $14 $15 $15 $16 $16 $17 $17 $18 $18

@_4728: .BYTE   $18 $18 $17 $17 $16 $16 $15 $15 $14 $14 $13 $13 $12 $12 $11 $11 ;$4728
        .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10

@_4748: .BYTE   $08 $08 $09 $09 $0A $0A $0B $0B $0C $0C $0D $0D $0E $0E $0F $0F ;$4748
        .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10

@_4768: .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 ;$4768
        .BYTE   $0F $0F $0E $0E $0D $0D $0C $0C $0B $0B $0A $0A $09 $09 $08 $08

@_4788: .BYTE   $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF ;$4788
        .BYTE   $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF $FF

@_47A8: .BYTE   $08 $08 $08 $08 $09 $09 $09 $09 $0A $0A $0A $0A $0B $0B $0B $0B ;$47A8
        .BYTE   $0B $0B $0B $0B $0A $0A $0A $0A $09 $09 $09 $09 $08 $08 $08 $08

        ;unused?
@_47C8: .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 ;$47C8
        .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10

        ;unused?
@_47E8: .BYTE   $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 ;$47E8
        .BYTE   $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08

@_4808: .BYTE   $08 $08 $08 $08 $09 $09 $09 $09 $0A $0A $0A $0A $0B $0B $0B $0B ;$4808
        .BYTE   $0C $0C $0C $0C $0D $0D $0D $0D $0E $0E $0E $0E $0F $0F $0F $0F

        ;unused?
@_4828: .BYTE   $0F $0F $0F $0F $0E $0E $0E $0E $0D $0D $0D $0D $0C $0C $0C $0C ;$4828
        .BYTE   $0B $0B $0B $0B $0A $0A $0A $0A $09 $09 $09 $09 $08 $08 $08 $08

        ;unused?
@_4848: .BYTE   $07 $07 $06 $06 $05 $05 $04 $04 $03 $03 $02 $02 $01 $01 $00 $00 ;$4848
        .BYTE   $00 $00 $01 $01 $02 $02 $03 $03 $04 $04 $05 $05 $06 $06 $07 $07

        ;unused?
@_4868: .BYTE   $08 $08 $08 $08 $09 $09 $09 $09 $0A $0A $0A $0A $0B $0B $0C $0C ;$4868
        .BYTE   $0C $0C $0B $0B $0A $0A $0A $0A $09 $09 $09 $09 $08 $08 $08 $08

        ;unused?
@_4888: .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 ;$4888
        .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10

        ;unused?
@_48A8: .BYTE   $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 $10 ;$48A8
        .BYTE   $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80 $80
        ;

sonic_process:                                                          ;$48C8
;===============================================================================
; in    IX      Address of the current mob being processed
;       IY      Address of the common variables (used throughout)
;-------------------------------------------------------------------------------
        res     1,      [IY+Vars.unknown0]

        bit     7,      [IX+Mob.flags]
        call    nz,     @_4e88

        ; flag to update the Sonic sprite frame
        set     7,      [IY+Vars.timeLightningFlags]

        ; is Sonic dead?
        bit     0,      [IY+Vars.scrollRingFlags]
        jp      nz,     @_543c

        ; reduce this number until it hits 0. appears to only be set when
        ; changing direction from left to right; something to do with
        ; acceleration/skidding?
        ld      A,      [RAM_SONIC.unknown16]
        and     A
        call    nz,     @_4ff0

        ; configure the flags on Sonic so that he adheres to the ground.
        ; I'm not sure why this is done every frame
        res     5,      [IX+Mob.flags]

        ; is Sonic in damage state?
        bit     6,      [IY+Vars.flags6]
        call    nz,     @_510a

        ld      A,      [RAM_D28C]
        and     A
        call    nz,     @_568f

        ; special stage? (time is centred)
        bit     0,      [IY+Vars.timeLightningFlags]
        call    nz,     @_5100

        bit     0,      [IY+Vars.unknown0]
        call    nz,     @_4ff5

        ; is Sonic underwater? -- count down oxygen...
        bit     4,      [IX+Mob.flags]  ; check mob underwater flag
        call    nz,     @drownTimer

        ld      A,      [RAM_D28B]
        and     A
        call    nz,     @_5285

        ld      A,      [RAM_D28A]
        and     A
        jp      nz,     @_5117

        bit     6,      [IY+Vars.unknown0]
        jp      nz,     @_5193

        bit     7,      [IY+Vars.unknown0]
        call    nz,     @_529c

        ;-----------------------------------------------------------------------

        bit     4,      [IX+Mob.flags]  ; mob underwater?
        jp      z,      @_1

        ld      HL,     @_4ddd
        ld      DE,     RAM_TEMP1
        ld      BC,     $0009
        ldir

        ld      HL,     $0100
        ld      [RAM_D240],     HL
        ld      HL,     $FD80
        ld      [RAM_D242],     HL
        ld      HL,     $0010
        ld      [RAM_D244],     HL
        jp      @_5

        ;-----------------------------------------------------------------------

@_1:    ld      A,       [IX+Mob.unknown15]
        and     A
        jr      nz,     @_4

        ; special stage?
        bit     0,      [IY+Vars.timeLightningFlags]
        jr      nz,     @_3

@_2:    ld      HL,     @_4dcb
        ld      DE,     RAM_TEMP1
        ld      BC,     $0009
        ldir

        ld      HL,     $0300
        ld      [RAM_D240],     HL
        ld      HL,     $FC80
        ld      [RAM_D242],     HL
        ld      HL,     $0038
        ld      [RAM_D244],     HL
        ld      HL,     [$DC0C]
        ld      [$DC0A],        HL
        jp      @_5

@_3:    bit     7,      [IX+Mob.flags]
        jr      nz,     @_2

        ld      HL,     @_4dd4
        ld      DE,     RAM_TEMP1
        ld      BC,     $0009
        ldir

        ld      HL,     $0C00
        ld      [RAM_D240],     HL
        ld      HL,     $FC80
        ld      [RAM_D242],     HL
        ld      HL,     $0038
        ld      [RAM_D244],     HL
        ld      HL,     [$DC0C]
        ld      [$DC0A],        HL
        jp      @_5

@_4:    ld      HL,     @_4de6
        ld      DE,     RAM_TEMP1
        ld      BC,     $0009
        ldir

        ld      HL,     $0600
        ld      [RAM_D240],     HL
        ld      HL,     $FC80
        ld      [RAM_D242],     HL
        ld      HL,     $0038
        ld      [RAM_D244],     HL
        ld      HL,     [$DC0C]
        inc     HL
        ld      [$DC0A],        HL

        ld      A,      [RAM_FRAMECOUNT]
        and     %00000011
        call    z,      @_4fec

        ;-----------------------------------------------------------------------

        ; is up pressed on the joypad?
@_5:    bit     1,      [IY+Vars.joypad]
        call    z,      @_50c1

        bit     1,      [IY+Vars.joypad]
        call    nz,     @_50e3

        ; handle collision with tile underneath Sonic:
        ;-----------------------------------------------------------------------
        ld      A,                      15
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ;$3F9ED =
        ;0010, 00C4, 0154, 01F4, 02B4, 0374, 044C, 04CC
        ;  (180) (144) (160) (192) (192) (216) (128)

        ; locate which block is underneath Sonic?
        ld      BC,     12
        ld      DE,     16
        call    getFloorLayoutRAMAddressForMob

        ; get the block index from the Floor Layout address returned
        ld      E,      [HL]
        ld      D,      0

        ; get the solidity index for the current level
        ld      A,      [RAM_LEVEL_SOLIDITY]
        ; double it to look it up in a list of pointers (2 bytes each)
        add     A,      A
        ; transfer it into HL so as to add it to the pointer table address
        ld      L,      A
        ld      H,      D
        ; access the table of data offsets at $3F9ED (bank 15)
        ld      BC,     $B9ED           ;=$3F9ED
        ; lookup the solidity index in the table of offsets
        add     HL,     BC
        ; read the 2-byte offset value into HL
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ; make an absolute address: $3F9ED + offset for solidity + block index
        add     HL,     DE
        add     HL,     BC
        ; read the byte of data for the particular block index
        ld      A,      [HL]
        ; if it's higher than the number of solidity types, skip ahead
        cp      $1C     ;=number of entries in @_58e5
        jr      nc,     @callback

        ; double the data byte read and transfer to HL for 16-bit use
        add     A,      A
        ld      L,      A
        ld      H,      D
        ld      DE,     @_58e5
        add     HL,     DE
        ; load HL with the address in the lookup table
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A

        ; load DE with the callback address
        ld      DE,     @callback

        ; switch back to the regular bank layout (where the mob code is)
        ld      A,                      2
        ld      [SMS_MAPPER_SLOT2],     A
        ld      [RAM_SLOT2],            A

        ; keep a copy of the callback address and jump to the specific
        ; solidity routine for the tile under Sonic
        push    DE
        jp      [HL]

@callback:
        ; has Sonic fallen out of the level?
        ;-----------------------------------------------------------------------
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $0024           ; height of Sonic?
        add     HL,     DE
        ex      DE,     HL
        ld      HL,     [RAM_LEVEL_BOTTOM]
        ld      BC,     $00C0           ; height of the screen
        add     HL,     BC
        xor     A       ; set A to zero, clearing the carry flag
        sbc     HL,     DE
        call    c,      hitPlayer@kill  ; if over, die!

        ; idle timer:
        ;-----------------------------------------------------------------------
        ld      HL,     $0000           ; reset the idle timer?

        ld      A,      [IY+Vars.joypad]; check joypad state
        cp      $FF                     ; is any button being pressed?
        jr      nz,     @_7             ; skip the idle timer update

        ; is player moving left or right?
        ; get the horizontal speed:
        ld      DE,     [RAM_SONIC.Xspeed]
        ld      A,      E               ; shift E into A for next instruction
        or      D                       ; combine E & D
        jr      nz,     @_7             ; if it's not zero, skip

        ld      A,      [RAM_SONIC.flags]
        rlca
        jr      nc,     @_7

        ld      HL,     [RAM_IDLE_TIMER]
        inc     HL

        ; update the idle timer
@_7:    ld      [RAM_IDLE_TIMER],       HL

        ;-----------------------------------------------------------------------

        bit     7,      [IY+Vars.flags6]
        call    nz,     @_50e8

        ld      [IX+Mob.unknown14],     $05
        ld      HL,     [RAM_IDLE_TIMER]
        ld      DE,     IDLE_TIME       ; idle time until waiting animation
        and     A                       ; clear the carry flag for below
        sbc     HL,    DE
        call    nc,     @_5105

        ; is up pressed?
        ld      A,      [IY+Vars.joypad]
        cp      %11111110
        call    z,      @_4edd

        ; up not pressed?
        bit     0,      [IY+Vars.joypad]
        call    nz,     @_4fd3

        bit     0,      [IX+Mob.flags]
        jp      nz,     @_532e

        ; ducking or spinning?
        ld      A,      [IX+Mob.height]
        cp      $20
        jr      z,      @_8

        ; falling?
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $FFF8
        add     HL,     DE
        ld      [RAM_SONIC.Y],  HL

@_8:    ld      [IX+Mob.width],         24
        ld      [IX+Mob.height],        32
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      B,      [IX+Mob.Xdirection]
        ld      C,      $00
        ld      E,      C
        ld      D,      C

        ; is right pressed?
        bit     3,      [IY+Vars.joypad]
        jp      z,      @_4f01

        ; is left pressed?
        bit     2,      [IY+Vars.joypad]
        jp      z,      @_4f5c

        ld      A,      H
        or      L
        or      B
        jr      z,      @_4b1b

        ld      [IX+Mob.unknown14],     $01
        bit     7,      B
        jr      nz,     @_9

        ld      DE,     [RAM_TEMP4]
        ld      A,      E
        cpl
        ld      A,      D
        ld      E,      A
        cpl
        ld      D,      A
        inc     DE
        ld      C,      $FF

        push    HL
        push    DE
        ld      DE,     [RAM_D240]
        xor     A
        sbc     HL,     DE
        pop     DE
        pop     HL
        jr      c,      @_4b1b

        ld      DE,     [RAM_TEMP1]
        ld      A,      E
        cpl
        ld      E,      A
        ld      A,      D
        cpl
        ld      D,      A
        inc     DE
        ld      C,      $FF
        ld      A,      [RAM_D216]
        ld      [IX+Mob.unknown14],     A
        jp      @_4b1b

        ;-----------------------------------------------------------------------

@_9:    ld      DE,     [RAM_TEMP4]
        ld      C,      $00

        push    HL
        push    DE
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      DE,     [RAM_D240]
        xor     A
        sbc     HL,     DE
        pop     DE
        pop     HL
        jr      c,      @_4b1b

        ld      DE,     [RAM_TEMP1]
        ld      A,      [RAM_D216]
        ld      [IX+Mob.unknown14],     A
@_4b1b:
        ld      A,      B
        and     A
        jp      m,      @_10

        add     HL,     DE
        adc     A,      C
        ld      C,      A
        jp      p,      @_11

        ld      A,      [RAM_SONIC.Xspeed]
        or      [IX+Mob.Xspeed+1]
        or      [IX+Mob.Xdirection]
        jr      z,      @_11

        ld      C,      $00
        ld      L,      C
        ld      H,      C
        jp      @_11

        ;-----------------------------------------------------------------------

@_10:   add     HL,     DE
        adc     A,      C
        ld      C,      A
        jp      m,      @_11
        ld      C,      $00
        ld      L,      C
        ld      H,      C
@_11:   ld      A,                      C
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A
@_4b49:
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      B,      [IX+Mob.Ydirection]
        ld      C,      $00
        ld      E,      C
        ld      D,      C
        bit     7,      [IX+Mob.flags]
        call    nz,     @_50af
        bit     0,      [IX+Mob.flags]
        jp      nz,     @_5407
        ld      A,      [RAM_D28E]
        and     A
        jr      nz,     @_12
        bit     7,      [IX+Mob.flags]
        jr      z,      @_13
        bit     3,      [IX+Mob.flags]
        jr      nz,     @_12
        ;button 2 pressed?
        bit     5,      [IY+Vars.joypad]
        jr      z,      @_13
        ;button 2 not pressed?
@_12:   bit     5,      [IY+Vars.joypad]
        jr      nz,     @_14
@_4b7f:
        ld      A,      [RAM_D28E]
        and     A
        call    z,      @_509d
        ld      HL,     [RAM_D242]
        ld      B,      $FF
        ld      C,      $00
        ld      E,      C
        ld      D,      C
        ld      A,      [RAM_D28E]
        dec     A
        ld      [RAM_D28E],     A
        set     2,      [IX+Mob.flags]
        jp      @_17

        ;-----------------------------------------------------------------------

@_13:   res     3,      [IX+Mob.flags]
        jp      @_15

        ;-----------------------------------------------------------------------

@_14:   set     3,      [IX+Mob.flags]
@_15:   xor     A
        ld      [RAM_D28E],     A
@_4bac:
        bit     7,      H
        jr      nz,     @_16
        ld      A,      [RAM_TEMP7]
        cp      H
        jr      z,      @_17
        jr      c,      @_17
@_16:   ld      DE,      [RAM_D244]
        ld      C,      $00

@_17:   bit     0,      [IY+Vars.flags6]
        jr      z,      @_18

        push    HL
        ld      A,      E
        cpl
        ld      E,      A
        ld      A,      D
        cpl
        ld      D,      A
        ld      A,      C
        cpl
        ld      HL,     $0001
        add     HL,     DE
        ex      DE,     HL
        adc     A,      $00
        ld      C,      A
        pop     HL
@_18:   add     HL,     DE
        ld      A,      B
        adc     A,      C
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        push    HL
        ld      A,      E
        cpl
        ld      L,      A
        ld      A,      D
        cpl
        ld      H,      A
        ld      A,      C
        cpl
        ld      DE,     $0001
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_D2E6],     HL
        ld      [RAM_D2E8],     A
        pop     HL
        bit     2,      [IX+Mob.flags]
        call    nz,     @_5280
        ld      A,      H
        and     A
        jp      p,      @_19
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      L
        cpl
        ld      L,      A
        inc     HL
@_19:   ld      DE,     $0100
        ex      DE,     HL
        and     A
        sbc     HL,     DE
        jr      nc,     @_21
        ld      A,      [RAM_SONIC.flags]
        and     $85
        jr      nz,     @_21
        bit     7,      [IX+Mob.Ydirection]
        jr      z,      @_20
        ld      [IX+Mob.unknown14],     $13
        jr      @_21
@_20:   ld      [IX+Mob.unknown14],     $01
@_21:   ld      BC,     $000C
        ld      DE,     $0008
        call    getFloorLayoutRAMAddressForMob
        ld      A,      [HL]
        and     $7F
        cp      $79
        call    nc,     @_4def
@_4c39:
        ld      A,      [RAM_D28C]
        and     A
        call    nz,     @_51b3
        bit     6,      [IY+Vars.flags6]
        call    nz,     @_51bc
        bit     2,      [IY+Vars.unknown0]
        call    nz,     @_51dd
        ld      A,      [RAM_SONIC.unknown14]
        cp      $0A
        call    z,      @_51f3
        ld      L,      [IX+Mob.unknown14]
        ld      C,      L
        ld      H,      $00
        add     HL,     HL
        ld      DE,     @_5965
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        ld      [RAM_SONIC.unknown11],  DE
        ld      A,      [RAM_D2DF]
        sub     C
        call    nz,     @_521f
        ld      A,      [RAM_SONIC.unknown13]

@_22:   ld      H,      $00
        ld      L,      A
        add     HL,     DE
        ld      A,      [HL]
        and     A
        jp      p,      @_23
        inc     HL
        ld      A,      [HL]
        ld      [RAM_SONIC.unknown13],  A
        jp      @_22

        ;-----------------------------------------------------------------------

@_23:   ld      D,      A
        ;TODO: what on earth is this? (could be a data ref, and not a ref to this label)
        ld      BC,     sound.update
        bit     1,      [IX+Mob.flags]
        jr      z,      @_24
        ld      BC,     $7000           ; immediate $7000 or label?
@_24:   bit     5,      [IY+Vars.flags6]
        call    nz,     @_5206
        ld      A,      [RAM_D302]
        and     A
        call    nz,     @_4e48
        ld      A,      D
        rrca
        rrca
        rrca
        ld      E,      A
        and     $E0
        ld      L,      A
        ld      A,      E
        and     %00011111
        add     A,      D
        ld      H,      A
        add     HL,     BC
        ld      [RAM_SONIC_CURRENT_FRAME],      HL
        ld      HL,     @_591d

        bit     0,      [IY+Vars.flags6]
        call    nz,     @_520f

        ld      A,      [RAM_SONIC.unknown14]
        cp      $13
        call    z,      @_5213
        ld      A,      [RAM_D302]
        and     A
        call    nz,     @_4e4d
        ld      [RAM_SONIC.spriteLayout],       HL
        ld      C,      $10
        ld      A,      [RAM_SONIC.Xspeed+1]
        and     A
        jp      p,      @_25
        neg
        ld      C,      $F0
@_25:   cp      $10
        jr      c,      @_26
        ld      A,      C
        ld      [RAM_SONIC.Xspeed+1],   A
@_26:   ld      C,      $10
        ld      A,      [RAM_SONIC.Yspeed+1]
        and     A
        jp      p,      @_27
        neg
        ld      C,      $F0
@_27:   cp      $10
        jr      c,      @_28
        ld      A,      C
        ld      [RAM_SONIC.Yspeed+1],   A
@_28:   ld      DE,      [RAM_SONIC.Y]
        ld      HL,     $0010
        and     A
        sbc     HL,     DE
        jr      c,      @_29
        add     HL,     DE
        ld      [RAM_SONIC.Y],  HL
@_29:   bit     7,      [IY+Vars.flags6]
        call    nz,     @_5224
        bit     0,      [IY+Vars.unknown0]
        call    nz,     @_4e8d
        ld      A,      [RAM_D2E1]
        and     A
        call    nz,     @_5231
        ld      A,      [RAM_D321]
        and     A
        call    nz,     @_4e51
        bit     1,      [IY+Vars.flags6]
        jr      nz,     @_31
        ld      HL,     [RAM_LEVEL_LEFT]
        ld      BC,     $0008
        add     HL,     BC
        ex      DE,     HL
        ld      HL,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      nc,     @_30
        ld      [RAM_SONIC.X],  DE
        ld      A,      [RAM_SONIC.Xdirection]
        and     A
        jp      p,      @_31

        xor     A                                          ;(set A to zero)
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   A
        ld      [RAM_SONIC.Xdirection], A
        jp      @_31

        ;-----------------------------------------------------------------------

@_30:   ld      HL,     [RAM_LEVEL_RIGHT]
        ld      DE,     $00F8                                   ;248 -- screen width less 8?
        add     HL,     DE

        ex      DE,     HL
        ld      HL,     [RAM_SONIC.X]
        ld      C,      $18
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_31
        ex      DE,     HL
        scf
        sbc     HL,     BC
        ld      [RAM_SONIC.X],  HL
        ld      A,      [RAM_SONIC.Xdirection]
        and     A
        jp      m,      @_31
        ld      HL,     [RAM_SONIC.Xspeed+1]
        or      H
        or      L
        jr      z,      @_31

        xor     A                                          ;(set A to 0)
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   A
        ld      [RAM_SONIC.Xdirection], A

@_31:   ld      A,      [RAM_SONIC.flags]
        ld      [RAM_D2B9],     A
        ld      A,      [RAM_SONIC.unknown14]
        ld      [RAM_D2DF],     A
        ld      D,      $01
        ld      C,      $30
        cp      $01
        jr      z,      @_32
        ld      D,      $06
        ld      C,      $50
        cp      $09
        jr      z,      @_32
        inc     [IX+Mob.unknown13]
        ret

@_32:   ld      A,      [RAM_D2E0]
        ld      B,      A
        ld      HL,     [RAM_SONIC.Xspeed]
        bit     7,      H
        jr      z,      @_33
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
@_33:   srl     H
        rr      L
        ld      A,      L
        add     A,      B
        ld      [RAM_D2E0],     A
        ld      A,      H
        adc     A,      D
        adc     A,      [IX+Mob.unknown13]
        ld      [RAM_SONIC.unknown13],  A
        cp      C
        ret     c

        sub     C
        ld      [RAM_SONIC.unknown13],  A

        ret

        ;-----------------------------------------------------------------------


@_4dcb: .BYTE   $10 $00 $30 $00 $08 $00 $00 $08 $02                     ;$4DCB
@_4dd4: .BYTE   $10 $00 $30 $00 $02 $00 $00 $08 $02                     ;$4DD4
@_4ddd: .BYTE   $04 $00 $0C $00 $02 $00 $00 $02 $01                     ;$4DDD
@_4de6: .BYTE   $10 $00 $30 $00 $08 $00 $00 $08 $02                     ;$4DE6

        ;-----------------------------------------------------------------------

@_4def: ex      DE,     HL                                              ;$4DEF

        ld      HL,     [RAM_SONIC.Y]
        ld      BC,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     BC
        ret     c

        ld      BC,     $0010
        and     A
        sbc     HL,     BC
        ret     c

        ld      HL,     [RAM_SONIC.X]
        ld      BC,     $000C
        add     HL,     BC
        ld      A,      [DE]
        ld      C,      A
        ld      A,      L
        rrca
        rrca
        rrca
        rrca
        and     %00000001
        inc     A
        ld      B,      A
        ld      A,      C
        and     B
        ret     z

        ld      A,      L
        and     $F0
        ld      L,      A
        ld      [RAM_D2AB],     HL
        ld      [RAM_D31D],     HL
        ld      A,      C
        xor     B
        ld      [DE],   A
        ld      HL,     [RAM_SONIC.Y]
        ld      BC,     $0008
        add     HL,     BC
        ld      A,      L
        and     $E0
        add     A,      $08
        ld      L,      A
        ld      [RAM_D2AD],     HL
        ld      [RAM_D31F],     HL
        ld      A,      $06
        ld      [RAM_D321],     A
        ld      HL,     @_595d
        ld      [RAM_D2AF],     HL

        ;add one ring to the ring count
        ld      A,      $01
        call    increaseRings

        ret

        ;-----------------------------------------------------------------------

@_4e48: ld      D,      A                                               ;$4E48
        ld      BC,     $7000           ; immediate $7000 or label?
        ret

        ;-----------------------------------------------------------------------

@_4e4d: ld      HL,     $0000                                           ;$4E4D
        ret

        ;-----------------------------------------------------------------------

@_4e51: dec     A                                                       ;$4E51
        ld      [RAM_D321],     A
        ld      HL,     [RAM_D31D]
        ld      [RAM_TEMP1],    HL
        ld      HL,     [RAM_D31F]
        ld      [RAM_TEMP3],    HL
        ld      HL,     $0000
        ld      [RAM_TEMP4],    HL
        ld      HL,     $FFFE
        ld      [RAM_TEMP6],    HL
        cp      $03
        jr      c,      @_34

        ld      A,      $B2
        call    _3581
        ld      HL,     $0008
        ld      [RAM_TEMP4],    HL
        ld      HL,     $0002
        ld      [RAM_TEMP6],    HL
@_34:   ld      A,      $5A
        call    _3581
        ret

        ;-----------------------------------------------------------------------

@_4e88: set     1,      [IY+Vars.unknown0]                              ;$4E88
        ret

        ;-----------------------------------------------------------------------

@_4e8d: ld      HL,     [RAM_SONIC.X]                                   ;$4E8D
        ld      [RAM_TEMP1],    HL
        ld      HL,     [RAM_SONIC.Y]
        ld      [RAM_TEMP3],    HL
        ld      HL,     RAM_D2F3
        ld      A,      [RAM_FRAMECOUNT]
        rrca
        rrca
        jr      nc,     @_35
        ld      HL,     RAM_D2F7
@_35:   ld      DE,     RAM_TEMP4
        ldi
        ldi
        ldi
        ldi
        rrca
        ld      A,      $94
        jr      nc,     @_36
        ld      A,      $96
@_36:   call    _3581
        ld      A,      [RAM_FRAMECOUNT]
        ld      C,      A
        and     %00000111
        ret     nz
        ld      B,      $02
        ld      HL,     RAM_D2F3
        bit     3,      C
        jr      z,      @_37
        ld      HL,     RAM_D2F7
@_37:   push    HL
        call    _0625
        pop     HL
        and     $0F
        ld      [HL],   A
        inc     HL
        ld      [HL],   $00
        inc     HL
        djnz    @_37
        ret

        ;-----------------------------------------------------------------------

        ;is Sonic moving?
@_4edd: ld      HL,     [RAM_SONIC.Xspeed]                                  ;$4EDD
        ld      A,      H
        or      L
        ret     nz

        ld      A,      [RAM_SONIC.flags]
        rlca
        ret     nc

        ld      [IX+Mob.unknown14], $0C
        ld      DE,     [RAM_D2B7]
        bit     7,      D
        jr      nz,     @_38

        ld      HL,     $002C
        and     A
        sbc     HL,     DE
        ret     c
@_38:   inc     DE
        ld      [RAM_D2B7],     DE

        ret

        ;-----------------------------------------------------------------------

@_4f01: res     1,      [IX+Mob.flags]                                  ;$4F01
        bit     7,      B
        jr      nz,     @_39
        ld      DE,     [RAM_TEMP1]
        ld      C,      $00
        ld      [IX+Mob.unknown14], $01
        push    HL
        exx
        pop     HL
        ld      DE,     [RAM_D240]
        xor     A
        sbc     HL,     DE
        exx
        jp      c,      @_4b1b
        ld      B,      A
        ld      E,      A
        ld      D,      A
        ld      C,      A
        ld      HL,     [RAM_D240]
        ld      A,      [RAM_D216]
        ld      [IX+Mob.unknown14], A
        jp      @_4b1b

        ;-----------------------------------------------------------------------

@_39:   set     1,      [IX+Mob.flags]
        ld      [IX+Mob.unknown14], $0A
        push    HL
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      DE,     $0100
        and     A
        sbc     HL,     DE
        pop     HL
        ld      DE,     [RAM_TEMP3]
        ld      C,      $00
        jp      nc,     @_4b1b
        res     1,      [IX+Mob.flags]
        ld      [IX+Mob.unknown14], $01
        jp      @_4b1b

        ;-----------------------------------------------------------------------

@_4f5c:                                                                 ;$4F5C
        set     1,      [IX+Mob.flags]
        ld      A,      L
        or      H
        jr      z,      @_40
        bit     7,      B
        jr      z,      @_4fa6
@_40:   ld      DE,     [RAM_TEMP1]
        ld      A,      E
        cpl
        ld      E,      A
        ld      A,      D
        cpl
        ld      D,      A
        inc     DE
        ld      C,      $FF
        ld      [IX+Mob.unknown14], $01
        push    HL

        exx
        pop     HL'
        ld      A,      L'
        cpl
        ld      L',     A
        ld      A,      H'
        cpl
        ld      H',     A
        inc     HL'
        ld      DE',    [RAM_D240]
        xor     A
        sbc     HL',    DE'
        exx

        jp      c,      @_4b1b
        ld      E,      A
        ld      D,      A
        ld      C,      A
        ld      HL,     [RAM_D240]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      B,      $FF
        ld      A,      [RAM_D216]
        ld      [IX+Mob.unknown14], A
        jp      @_4b1b

        ;-----------------------------------------------------------------------

@_4fa6:
        res     1,      [IX+Mob.flags]
        ld      [IX+Mob.unknown14], $0A
        ld      DE,     [RAM_TEMP3]
        ld      A,      E
        cpl
        ld      E,      A
        ld      A,      D
        cpl
        ld      D,      A
        inc     DE
        ld      C,      $FF
        push    HL

        exx
        pop     HL'
        ld      BC',    $0100
        and     A
        sbc     HL',    BC'
        exx

        jp      nc,     @_4b1b
        set     1,      [IX+Mob.flags]
        ld      [IX+Mob.unknown14], $01
        jp      @_4b1b

        ;-----------------------------------------------------------------------

@_4fd3: bit     0,      [IX+Mob.flags]                                  ;$4FD3
        ret     nz

        ld      HL,     [RAM_D2B7]
        ld      A,      H
        or      L
        ret     z

        bit     7,      H
        jr      z,      @_41

        inc     HL
        ld      [RAM_D2B7],     HL
        ret

@_41:   dec     HL
        ld      [RAM_D2B7],     HL

        ret

        ;-----------------------------------------------------------------------

@_4fec: dec     [IX+Mob.unknown15]                                      ;$4FEC
        ret

        ;-----------------------------------------------------------------------

@_4ff0: dec     A                                                       ;$4FF0
        ld      [RAM_SONIC.unknown16],  A
        ret

        ;-----------------------------------------------------------------------

@_4ff5: ld      A,      [RAM_FRAMECOUNT]                                    ;$4FF5
        and     %00000011
        ret     nz

        ld      HL,     RAM_D28D
        dec     [HL]
        ret     nz

        res     0,      [IY+Vars.unknown0]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      [RAM_LEVEL_MUSIC]
                rst     $18     ;=rst_playMusic
        .ENDIF

        ret

@drownTimer:                                                            ;$5009
        ;-----------------------------------------------------------------------
        ;check for specific solidity data for this level
        ld      A,      [RAM_LEVEL_SOLIDITY]
        cp      $03                                             ;labyrinth?
        ret     nz

        ;is this labyrinth act 3?
        ;TODO: the no-drowning effect of Labyrinth Act 3 should be a level header flag, not hard-coded like this
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $0B
        ret     z                                               ;yes? not applicable

        ;increase drown timer...
        ld      HL,     [RAM_D29B]
        inc     HL
        ld      [RAM_D29B],     HL

        ld      DE,     $0300
        and     A
        sbc     HL,     DE
        ret     c

        ;count down 1 every 256 frames
        ld      A,      $05
        sub     H
        jr      nc,     @_42

        res     5,      [IY+Vars.flags6]                  ;remove shield
        res     6,      [IY+Vars.flags6]                  ;clear damage state
        res     0,      [IY+Vars.unknown0]
        set     3,      [IY+Vars.unknown0]
        set     0,      [IY+Vars.scrollRingFlags]         ;mark player as dead
        ld      A,      $C0
        ld      [RAM_D287],     A

        ;drowned!
        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_DEATH
                rst     $18     ;=rst_playMusic
        .ENDIF

        call    _91eb
        call    _91eb
        call    _91eb
        call    _91eb
        xor     A

        ;layout the oxygen countdown number
@_42:   ld      E,      A
        add     A,      A
        add     A,      $80
        ld      [RAM_LAYOUT_BUFFER],    A
        ld      A,      $FF
        ld      [RAM_LAYOUT_BUFFER+1],  A
        ld      D,      $00
        ld      HL,     @_5097
        add     HL,     DE
        ld      A,      [RAM_FRAMECOUNT]
        and     [HL]
        jr      nz,     @_43

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_1A
                rst     $28     ;=rst_playSFX
        .ENDIF

@_43:   ld      A,      [RAM_FRAMECOUNT]
        rrca
        ret     nc

        ld      HL,     [RAM_SONIC.X]
        ld      DE,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     DE
        ld      A,      L
        add     A,      $08
        ld      C,      A
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        ld      A,      L
        add     A,      $EC
        ld      B,      A
        ld      HL,     $D03C
        ld      DE,     RAM_LAYOUT_BUFFER
        call    layoutSpritesHorizontal

        ret

        ;-----------------------------------------------------------------------


@_5097: .BYTE   $01 $07 $0F $1F $3F $7F                                 ;$5097

        ;-----------------------------------------------------------------------

@_509d: ld      A,      $10                                             ;$509D
        ld      [RAM_D28E],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_00
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret

        ;--- UNUSED! (8 bytes) -----------------------------------------------------------------------------------------

        xor     A                                                       ;$50A6
        ld      [RAM_SONIC.Xsubpixel],  A
        ld      [RAM_SONIC.X],          DE
        ret

        ;-----------------------------------------------------------------------

@_50af: exx                                                             ;$50AF
        ld      HL',    [RAM_SONIC.Y]
        ld      [RAM_D2D9],     HL
        exx
        bit     2,      [IX+Mob.flags]
        ret     z

        res     2,      [IX+Mob.flags]
        ret

        ;-----------------------------------------------------------------------
        ;joypad up is pressed...

@_50c1: bit     2,      [IX+Mob.flags]                                  ;$50C1
        ret     nz

        bit     0,      [IX+Mob.flags]
        ret     nz

        bit     7,      [IX+Mob.flags]
        ret     z

        ;is Sonic moving?
        set     0,      [IX+Mob.flags]

        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      L
        or      H
        jr      z,      @_44

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_06
                rst     $28     ;=rst_playSFX
        .ENDIF

@_44:   set     2,      [IY+Vars.timeLightningFlags]
        ret

        ;-----------------------------------------------------------------------

@_50e3: res     2,      [IY+Vars.timeLightningFlags]                    ;$50E3
        ret

        ;-----------------------------------------------------------------------

@_50e8: ld      HL,     [RAM_D2DC]                                          ;$50E8
        ld      DE,     [RAM_SONIC.Y]
        and     A
        sbc     HL,     DE
        jp      c,      @_55a8

        ld      HL,     $0000
        ld      [RAM_D29B],     HL

        res     4,      [IX+Mob.flags]                     ;mob not underwater
        ret

        ;-----------------------------------------------------------------------

@_5100: set     2,      [IX+Mob.flags]                                  ;$5100
        ret

        ;-----------------------------------------------------------------------

@_5105: ld      [IX+Mob.unknown14],     $0D                             ;$5105
        ret

        ;-----------------------------------------------------------------------

@_510a: ; clear joypad input                                            ;$510A
        ld      [IY+Vars.joypad],  $FF

        ld      A,        [RAM_SONIC.flags]
        and     %11111010
        ld      [RAM_SONIC.flags],      A

        ret

        ;-----------------------------------------------------------------------

@_5117: dec     A                                                       ;$5117
        ld      [RAM_D28A],     A
        jr      z,      @_46
        cp      $14
        jr      c,      @_45

        xor     A
        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   HL
        ld      [RAM_SONIC.Yspeed+0],   A
        ld      [RAM_SONIC.Yspeed+1],   HL

        ld      [IX+Mob.unknown14], $0F
        jp      @_4c39

        ;-----------------------------------------------------------------------

@_45:   res     1,      [IX+Mob.flags]
        ld      [IX+Mob.unknown14], $0E
        jp      @_4c39

        ;-----------------------------------------------------------------------

@_46:   ld      HL,     [RAM_D2D5]
        ld      B,      [HL]
        inc     HL
        ld      C,      [HL]
        inc     HL
        ld      A,      [HL]
        and     A
        jr      z,      @_49
        jp      m,      @_47
        ld      [RAM_D2D3],     A
        set     4,      [IY+Vars.flags6]
        jr      @_48

@_47:   set     2,      [IY+Vars.unknown_0D]

@_48:   ld      A,      $01
        ld      [RAM_D289],     A
        ret

@_49:   ld      A,      B
        ld      H,      $00
        ld      B,      $05

@_50:   add     A,      A
        rl      H
        djnz    @_50

        ld      L,      A
        ld      DE,     $0008
        add     HL,     DE
        ld      [RAM_SONIC.X],  HL
        ld      A,      C
        ld      H,      $00
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      L,      A
        ld      [RAM_SONIC.Y],  HL

        xor     A
        ld      [RAM_SONIC.Xsubpixel],  A
        ld      [RAM_SONIC.Ysubpixel],  A
        ret

        ;-----------------------------------------------------------------------

@_5193: xor     A       ;set A to 0                                     ;$5319
        ld      L,      A
        ld      H,      A
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A                  ;set "not jumping"

        ld      [IX+Mob.unknown14], $16
        ld      A,      [RAM_SONIC.unknown13]
        cp      $12
        jp      c,      @_4c39

        res     6,      [IY+Vars.unknown0]
        set     2,      [IX+Mob.flags]
        jp      @_4c39

        ;-----------------------------------------------------------------------

@_51b3: dec     A                                                       ;$51B3
        ld      [RAM_D28C],     A
        ld      [IX+Mob.unknown14], $11
        ret

        ;-----------------------------------------------------------------------

@_51bc: ld      [IX+Mob.width],         28                              ;$51BC
        ld      [IX+Mob.unknown14],     16

        bit     7,      [IX+Mob.Ydirection]
        ret     nz

        bit     7,      [IX+Mob.flags]
        ret     z

        res     6,      [IY+Vars.flags6]

        xor     A
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   A
        ld      [RAM_SONIC.Xdirection], A

        ret

        ;-----------------------------------------------------------------------

@_51dd: ld      A,      [RAM_SONIC.flags]                                   ;$51DD
        and     $FA
        ld      [RAM_SONIC.flags],      A
        ld      [IX+Mob.unknown14],     $14
        ld      HL,     RAM_D2FB
        dec     [HL]
        ret     nz

        res     2,      [IY+Vars.unknown0]
        ret

        ;-----------------------------------------------------------------------

@_51f3: ld      A,      [RAM_SONIC.unknown16]                              ;$51F3
        and     A
        ret     nz

        bit     7,      [IX+Mob.flags]
        ret     z

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_03
                rst     $28     ;=rst_playSFX
        .ENDIF

        ld      A,      $3C
        ld      [RAM_SONIC.unknown16],  A
        ret

        ;-----------------------------------------------------------------------

        ; every other frame...                                          ;$5206
@_5206: ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        ret     nz

        ld      D,      $18
        ret

        ;-----------------------------------------------------------------------

@_520f: ld      HL,     @_592b                                          ;$592B
        ret

        ;-----------------------------------------------------------------------

@_5213: ld      HL,     @_5939                                          ;$5213

        bit     1,      [IX+Mob.flags]
        ret     z

        ld      HL,     @_594b
        ret

        ;-----------------------------------------------------------------------

@_521f: ld      [IX+Mob.unknown13],     $00                             ;$521F
        ret

        ;-----------------------------------------------------------------------

        ; mob underwater?
@_5224: bit     4,      [IX+Mob.flags]                                  ;$5224
        ret     z

        ld      A,      [RAM_FRAMECOUNT]
        and     A
        call    z,      _91eb                                ;do this every 256 frames...?

        ret

        ;-----------------------------------------------------------------------

@_5231: dec     A                                                       ;$5231
        ld      [RAM_D2E1],     A
        cp      $06
        jr      c,      @_51

        cp      $0A
        ret     c

@_51:   ld      A,      [IY+Vars.spriteUpdateCount]
        ld      HL,     [RAM_SPRITETABLE_ADDR]                    ;get current sprite-table address

        push    AF                                      ;remember no. of sprite updates pending
        push    HL                                         ;remember current sprite-table address
        ld      HL,     RAM_SPRITETABLE ; load the game's main sprite table
        ld      [RAM_SPRITETABLE_ADDR], HL                 ;and set the pointer to that

        ld      DE,     [RAM_CAMERA_Y]
        ld      HL,     [RAM_D2E4]
        and     A
        sbc     HL,     DE
        ex      DE,     HL
        ld      BC,     [RAM_CAMERA_X]
        ld      HL,     [RAM_D2E2]
        and     A
        sbc     HL,     BC
        ld      BC,     @_526e                                  ;address of sprite layout
        call    processSpriteLayout

        pop     HL
        pop     AF

        ld      [RAM_SPRITETABLE_ADDR],         HL
        ld      [IY+Vars.spriteUpdateCount],    A
        ret

        ;-----------------------------------------------------------------------

@_526e: .BYTE   $00 $02 $04 $06 $FF $FF                                 ;$526E
        .BYTE   $20 $22 $24 $26 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        ;-----------------------------------------------------------------------

@_5280: ld      [IX+Mob.unknown14],     $09                             ;$5280
        ret

        ;-----------------------------------------------------------------------

@_5285: dec     A                                                       ;$5285
        ld      [RAM_D28B],     A
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      [RAM_LEVEL_MUSIC]
                rst     $18     ;=rst_playMusic
        .ENDIF

        ld      C,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       C
        ret

        ;-----------------------------------------------------------------------

@_529c: ld      [IY+Vars.joypad],       $FB                             ;$529C
        ld      HL,     [RAM_SONIC.X]
        ld      DE,     $1B60
        and     A
        sbc     HL,     DE
        ret     nc

        ld      [IY+Vars.joypad],  $FF
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      L
        or      H
        ret     nz

        res     1,      [IX+Mob.flags]

        pop     HL
        set     1,      [IX+Mob.flags]
        ld      [IX+Mob.unknown14], $18
        ld      HL,     RAM_D2FE

        bit     0,      [IY+Vars.unknown_0D]
        jr      nz,     @_52

        ld      [HL],   $50
        call    findEmptyMob
        jp      c,      @_4c39

        push    IX
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $54                     ;all emeralds animation
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.flags],     A
        ld      [IX+Mob.Xsubpixel], A
        ld      HL,     [RAM_SONIC.X]
        ld      DE,     $0002
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $000E
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        pop     IX

        set     0,      [IY+Vars.unknown_0D]
        jp      @_4c39

        ;-----------------------------------------------------------------------

@_52:   bit     1,      [IY+Vars.unknown_0D]
        jr      nz,     @_53

        dec     [HL]
        jp      nz,     @_4c39

        set     1,      [IY+Vars.unknown_0D]
        ld      [HL],   $8C
@_53:   ld      [IX+Mob.unknown14],     $17
        ld      A,      [HL]
        and     A
        jr      z,      @_54

        dec     [HL]
        jp      @_4c39

@_54:   ld      [IX+Mob.unknown14],     $19
        jp      @_4c39

        ;-----------------------------------------------------------------------

@_532e: ld      A,      [IX+Mob.height]                                 ;$532E
        cp      $18
        jr      z,      @_55

        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $0008
        add     HL,     DE
        ld      [RAM_SONIC.Y],  HL

@_55:   ld      [IX+Mob.width],         $18
        ld      [IX+Mob.height],        $18
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      B,      [IX+Mob.Xdirection]
        ld      C,      $00
        ld      E,      C
        ld      D,      C
        ld      A,      H
        or      L
        or      B
        jp      z,      @_60

        ld      [IX+Mob.unknown14], $09

        bit     2,      [IY+Vars.joypad]
        jr      nz,     @_57

        bit     1,      [IY+Vars.joypad]
        jr      z,      @_57

        bit     7,      [IX+Mob.flags]
        jp      z,      @_56

        bit     7,      B
        jr      nz,     @_59

        res     0,      [IX+Mob.flags]
        jp      @_4fa6

@_56:   ld      DE,     $FFF0
        ld      C,      $FF
        jp      @_4b1b

@_57:   bit     3,      [IY+Vars.joypad]
        jr      nz,     @_59

        bit     1,      [IY+Vars.joypad]
        jr      z,      @_59

        bit     7,      [IX+Mob.flags]
        jp      z,      @_58

        bit     7,      B
        jr      z,      @_59

        res     0,      [IX+Mob.flags]
        jp      @_4fa6

@_58:   ld      DE,     $0010
        ld      C,      $00
        jp      @_4b1b

@_59:   ld      DE,     $0004
        ld      C,      $00
        ld      A,      B
        and     A
        jp      m,      @_4b1b

        ld      DE,     $FFFC
        ld      C,      $FF
        jp      @_4b1b

@_60:   bit     7,      [IX+Mob.flags]
        jr      z,      @_62

        ld      [IX+Mob.unknown14], $07
        res     0,      [IX+Mob.flags]
        ld      DE,     [RAM_D2B7]

        bit     7,      D
        jr      z,      @_61

        ld      HL,     $FFB0
        and     A
        sbc     HL,     DE
        jp      nc,     @_4b49

@_61:   dec     DE
        ld      [RAM_D2B7],     DE
        jp      @_4b49

@_62:   ld      [IX+Mob.unknown14],     $09
        push    DE
        push    HL

        bit     7,      B
        jr      z,      @_63

        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
@_63:   ld      DE,     [RAM_D240]
        xor     A
        sbc     HL,     DE
        pop     HL
        pop     DE
        jp      c,      @_4b1b

        ld      C,      A
        ld      E,      C
        ld      D,      C
        ld      [IX+Mob.unknown14], $09
        jp      @_4b1b

        ;-----------------------------------------------------------------------

@_5407: bit     7,      [IX+Mob.flags]                                  ;$5407
        jr      z,      @_65

        bit     3,      [IX+Mob.flags]
        jr      nz,     @_64

        bit     5,      [IY+Vars.joypad]
        jr      z,      @_65

@_64:   bit     5,      [IY+Vars.joypad]
        jr      nz,     @_66

        res     0,      [IX+Mob.flags]

        ld      A,      [RAM_SONIC.Xspeed]
        and     $F8
        ld      [RAM_SONIC.Xspeed],     A
        jp      @_4b7f

@_65:   res     3,      [IX+Mob.flags]
        jp      @_4bac

@_66:   set     3,      [IX+Mob.flags]
        jp      @_4bac

        ;-----------------------------------------------------------------------
        ;Sonic is dead...

@_543c: set     5,      [IX+Mob.flags]  ; make Sonic pass over the floor;$543C

        ld      A,      [RAM_D287]
        cp      $60
        jr      z,      @_54aa

        ;has Sonic finished falling off the screen?
        ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     $00C0                                   ;height of screen?
        add     HL,     DE
        ld      DE,     [RAM_SONIC.Y]
        sbc     HL,     DE
        jr      nc,     @_67

        bit     2,      [IY+Vars.flags6]
        jr      nz,     @_67

        ld      A,      $01
        ld      [RAM_D283],     A

        ;remove a life...
        ld      HL,     RAM_LIVES
        dec     [HL]

        set     2,      [IY+Vars.flags6]
        jp      @_54aa

@_67:   xor     A
        ld      HL,     $0080

        bit     3,      [IY+Vars.unknown0]
        jr      nz,     @_71

        ld      DE,     [RAM_SONIC.Yspeed]

        bit     7,      D
        jr      nz,     @_68

        ld      HL,     $0600
        and     A
        sbc     HL,     DE
        jr      c,      @_72

@_68:   ex      DE,     HL
        ld      B,      [IX+Mob.Ydirection]
        ld      A,      H
        cp      $80
        jr      nc,     @_69

        cp      $08
        jr      nc,     @_70

@_69:   ld      DE,     $0030
        ld      C,      $00
@_70:   add     HL,     DE
        ld      A,      B
        adc     A,      C
@_71:   ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A

@_72:   xor     A
        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A

@_54aa:                                                                 ;$54AA
        ld      [IX+Mob.unknown14],     $0B

        bit     3,      [IY+Vars.unknown0]
        jp      z,      @_4c39

        ld      [IX+Mob.unknown14], $15
        jp      @_4c39

        ;=======================================================================
        ; referenced by table at `_58e5` - index $00
        ; air

@_54bc: ; check if the player is underwater                             ;$54BC
        bit     7,      [IY+Vars.flags6]                  ;underwater flag
        ret     nz                                              ;this solidity is not valid underwater

        res     4,      [IX+Mob.flags]                     ;turn off mob underwater flag
        ret

        ;=======================================================================
        ; referenced by table at `_58e5` - index $01
        ; spikes?

        ; is the player dead?
@_54c6: bit     0,      [IY+Vars.scrollRingFlags]                       ;$54C6
        jp      z,      hitPlayer@_35fd ; if not, damage them
        ret

        ;=======================================================================
        ; referenced by table at `_58e5` - index $02
        ; jump ramp?

@_54ce: ld      A,      [IX+Mob.X+0]                                    ;$54CE
        add     A,      $0C
        and     %00011111
        cp      $1A
        ret     c

        ld      A,      [RAM_SONIC.flags]
        rrca
        jr      c,      @_73

        and     $02
        ret     z

@_73:   ld      L,       [IX+Mob.Xspeed+0]
        ld      H,      [IX+Mob.Xspeed+1]

        bit     7,      [IX+Mob.Xdirection]
        ret     nz

        ld      DE,     $0301
        and     A
        sbc     HL,     DE
        ret     c

        ld      L,      [IX+Mob.Xspeed+1]
        ld      H,      [IX+Mob.Xdirection]
        add     HL,     HL
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  L
        ld      [IX+Mob.Ydirection],        H

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_05
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $03
        ;horizontal spring? (facing left)

@_550f: ld      A,      [IX+Mob.X+0]                                    ;$550F
        add     A,      $0C
        and     %00011111
        cp      $10
        ret     c

        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $F8
        ld      [IX+Mob.Xdirection],        $FF
        set     1,      [IX+Mob.flags]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $04
        ;vertical spring?

@_552d:
        ld      A,      [IX+Mob.X+0]                                    ;$552D
        add     A,      $0C
        and     %00011111
        cp      $10
        ret     c

        bit     7,      [IX+Mob.flags]
        ret     z

        ld      A,      [RAM_D2B9]
        and     $80
        ret     nz

        res     6,      [IY+Vars.flags6]
        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $F4
        ld      [IX+Mob.Ydirection],        $FF

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $05

@_5556: ld      A,       [IX+Mob.X+0]                                   ;$5556
        add     A,      $0C
        and     %00011111
        cp      $10
        ret     nc

        res     6,      [IY+Vars.flags6]
        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $08
        ld      [IX+Mob.Xdirection],        $00
        res     1,      [IX+Mob.flags]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $06

@_5578: bit     7,      [IX+Mob.flags]                                  ;$5578
        ret     z

        ld      HL,     [RAM_SONIC.Xsubpixel]
        ld      A,      [RAM_SONIC.X+1]
        ld      DE,     $FE80
        add     HL,     DE
        adc     A,      $FF
        ld      [RAM_SONIC.Xsubpixel],  HL
        ld      [RAM_SONIC.X+1],        A
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $07

@_5590: bit     7,      [IX+Mob.flags]                                  ;$5590
        ret     z

        ld      HL,     [RAM_SONIC.Xsubpixel]
        ld      A,      [RAM_SONIC.X+1]
        ld      DE,     $0200
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_SONIC.Xsubpixel],  HL
        ld      [RAM_SONIC.X+1],        A
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $08
        ;water? (non-raster)

@_55a8: bit     4,      [IX+Mob.flags]  ; mob underwater?               ;$55A8
        jr      nz,     @_74

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_12       ; splash?
                rst     $28     ;=rst_playSFX
        .ENDIF

@_74:   set     4,      [IX+Mob.flags]                      ;set mob underwater
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $09
        ;vertical spring? (up-centre)

@_55b6: ld      A,      [IX+Mob.X+0]                                    ;$55B6
        add     A,      $0C
        and     %00011111
        cp      $08
        ret     c

        cp      $18
        ret     nc

        bit     7,      [IX+Mob.flags]
        ret     z

        ld      A,      [RAM_D2B9]
        and     $80
        ret     nz

        res     6,      [IY+Vars.flags6]
        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $F4
        ld      [IX+Mob.Ydirection],        $FF

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $0A

@_55e2: bit     7,      [IX+Mob.Ydirection]                             ;$55E2
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_05
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $0B

@_55eb: bit     4,      [IY+Vars.flags6]                                ;$55EB
        ret     nz

        ld      A,      [RAM_SONIC.X]
        add     A,      $0C
        and     %00011111
        cp      $08
        ret     c

        cp      $18
        ret     nc

        ld      HL,     [RAM_SONIC.X]
        ld      BC,     $000c
        add     HL,     BC
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      E,      H
        ld      HL,     [RAM_SONIC.Y]
        ld      BC,     $0010
        add     HL,     BC
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      D,      H
        ld      HL,     @_5643
        ld      B,      $05

@_75:   ld      A,       [HL]
        inc     HL
        cp      E
        jr      nz,     @_76

        ld      A,      [HL]
        cp      D
        jr      nz,     @_76

        inc     HL
        ld      [RAM_D2D5],     HL
        ld      A,              $50
        ld      [RAM_D28A],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_06
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret

@_76:   inc     HL
        inc     HL
        inc     HL
        inc     HL
        djnz    @_75

        ret

        ;-----------------------------------------------------------------------

@_5643: .BYTE   $34 $3C $34 $2F $00 $19 $3A $19 $04 $00 $0E $3A $00 $00 $16 $1B ;$5643
        .BYTE   $32 $00 $00 $17 $2F $0C $00 $00 $FF

        ;=======================================================================
        ;referenced by table at `_58e5` - index $0C

@_565c: ld      HL,     [RAM_SONIC.Xspeed]                                  ;$565C
        ld      A,      [RAM_SONIC.Xdirection]
        ld      DE,     $FFF8
        add     HL,     DE
        adc     A,      $FF
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A

        bit     4,      [IX+Mob.flags]                     ;mob underwater?
        jr      nz,     @_77

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_12
                rst     $28     ;=rst_playSFX
        .ENDIF

@_77:   set     4,      [IX+Mob.flags]                     ;set mob underwater
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $0D

@_567c: xor     A       ; set A to 0                                    ;$567C
        ld      HL,     $0005
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   HL

        res     1,      [IX+Mob.flags]

@_568a: ld      A,              $06
        ld      [RAM_D28C],     A

        ;-----------------------------------------------------------------------

@_568f: ld      A,      [IY+Vars.joypad]                                ;$568F
        or      $0F
        ld      [IY+Vars.joypad],  A

        ld      HL,     $0004
        ld      [RAM_SONIC.Yspeed+1],   HL

        res     0,      [IX+Mob.flags]
        res     2,      [IX+Mob.flags]
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $0E

@_56a6: xor     A                                                       ;$56A6
        ld      HL,     $0006
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   HL
        res     1,      [IX+Mob.flags]
        jr      @_568a

        ;=======================================================================
        ;referenced by table at `_58e5` - index $0F

@_56b6: xor     A                                                       ;$56B6
        ld      HL,     $FFFB
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   HL

        set     1,      [IX+Mob.flags]

        jr      @_568a

        ;=======================================================================
        ;referenced by table at `_58e5` - index $10

@_56c6: xor     A                                                       ;$56C6
        ld      HL,     $FFFA
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   HL

        set     1,      [IX+Mob.flags]

        jr      @_568a

        ;=======================================================================
        ;referenced by table at `_58e5` - index $11

@_56d6: ld      A,      [RAM_D2E1]                                          ;$56D6
        cp      $08
        ret     nc

        call    @_5727
        ld      DE,     $0001
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Ydirection]
        cpl
        add     HL,     DE
        adc     A,      $00
        and     A
        jp      p,      @_78

        ld      DE,     $FFC8
        add     HL,     DE
        adc     A,      $FF

@_78:   ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        ld      BC,     $000C
        ld      HL,     [RAM_SONIC.X]
        add     HL,     BC
        ld      A,      L
        and     $E0
        ld      L,      A
        ld      [RAM_D2E2],     HL
        ld      BC,     $0010
        ld      HL,     [RAM_SONIC.Y]
        add     HL,     BC
        ld      A,      L
        and     $E0
        ld      L,      A
        ld      [RAM_D2E4],     HL
        ld      A,      $10
        ld      [RAM_D2E1],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_07
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;-----------------------------------------------------------------------
        ;called by functions referenced by `_58e5`

@_5727: ld      HL,     [RAM_SONIC.Xspeed]                                 ;$5727
        ld      A,      [RAM_SONIC.Xdirection]
        ld      C,      A
        and     $80
        ld      B,      A
        ld      A,      [RAM_SONIC.X]
        add     A,      $0C
        and     %00011111
        sub     $10
        and     $80
        cp      B
        jr      z,      @_79

        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      C
        cpl
        ld      C,      A
@_79:   ld      DE,     $0001
        ld      A,      C
        add     HL,     DE
        adc     A,      $00
        ld      E,      L
        ld      D,      H
        ld      C,      A
        sra     C
        rr      D
        rr      E
        add     HL,     DE
        adc     A,      C
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $12

@_5761: ld      [IX+Mob.Yspeed+0],      $00                             ;$5761
        ld      [IX+Mob.Yspeed+1],      $F6
        ld      [IX+Mob.Ydirection],    $FF

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $13

@_5771: ld      [IX+Mob.Yspeed+0],      $00                             ;$5771
        ld      [IX+Mob.Yspeed+1],      $F4
        ld      [IX+Mob.Ydirection],    $FF

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $14

@_5781: ld      [IX+Mob.Yspeed+0],      $00                             ;$5781
        ld      [IX+Mob.Yspeed+1],      $F2
        ld      [IX+Mob.Ydirection],    $FF

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $15

@_5791: ld      A,      [RAM_D2B1]                                          ;$5791
        and     A
        ret     nz

        ld      DE,     $0001
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Xdirection]
        cpl
        add     HL,     DE
        adc     A,      $00
        ld      DE,     $FF00
        ld      C,      $FF
        jp      m,      @_80

        ld      DE,     $0100
        ld      C,      $00
@_80:   add     HL,     DE
        adc     A,      C
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A
@_57be: ld      HL,     RAM_D2B1
        ld      [HL],   $04
        inc     HL
        ld      [HL],   $0E
        inc     HL
        ld      [HL],   $3F

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_07
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $16

@_57cd: call    @_5727                                                  ;$57CD
        ld      DE,     $0001
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Ydirection]
        cpl
        add     HL,     DE
        adc     A,      $00
        and     A
        jp      p,      @_81

        ld      DE,     $FFC8
        add     HL,     DE
        adc     A,      $FF
@_81:   ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        jp      @_57be

        ;=======================================================================
        ;referenced by table at `_58e5` - index $17

@_57f6: ld      HL,     [RAM_D2E9]                                          ;$57F6
        ld      DE,     $0082
        and     A
        sbc     HL,     DE
        ret     c

        bit     0,      [IY+Vars.scrollRingFlags]
        jp      z,      hitPlayer@_35fd
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $18

@_5808: ld      A,      [RAM_SONIC.flags]                                   ;$5808
        rlca
        ret     nc

        ld      HL,     [RAM_SONIC.X]
        ld      BC,     $000C
        add     HL,     BC
        ld      A,      L
        and     %00011111
        cp      $10
        jr      nc,     @_5858

@_581b: ld      HL,      [RAM_SONIC.X]
        ld      BC,     $000C
        add     HL,     BC
        ld      A,      L
        and     $E0
        ld      C,      A
        ld      B,      H
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $0010
        add     HL,     DE
        ld      A,      L
        and     $E0
        ld      E,      A
        ld      D,      H
        call    @_5893
        ret     c

        ld      BC,     $000C
        ld      DE,     $0010
        call    getFloorLayoutRAMAddressForMob

        ld      C,      $00
        ld      A,      [HL]
        cp      $8A
        jr      z,      @_5849

        ld      C,      $89
@_5849: ld      [HL],   C
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $19

@_584b: ld      HL,     [RAM_SONIC.X]                                       ;$584B
        ld      BC,     $000c
        add     HL,     BC
        ld      A,      L
        and     %00011111
        cp      $10
        ret     c

@_5858: ld      A,      L
        and     $E0
        add     A,      $10
        ld      C,      A
        ld      B,      H
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $0010
        add     HL,     DE
        ld      A,      L
        and     $E0
        ld      E,      A
        ld      D,      H
        call    @_5893
        ret     c

        ld      BC,     $000C
        ld      DE,     $0010
        call    getFloorLayoutRAMAddressForMob

        ld      C,      $00
        ld      A,      [HL]
        cp      $89
        jr      z,      @_5849

        ld      C,      $8A
        ld      [HL],   C
        ret

        ;=======================================================================
        ;referenced by table at `_58e5` - index $1A

@_5883: ld      HL,     [RAM_SONIC.X]                                       ;$5883
        ld      BC,     $000c
        add     HL,     BC
        ld      A,      L
        and     %00011111
        cp      $10
        ret     nc
        jp      @_581b

        ;-----------------------------------------------------------------------
        ;called by functions referenced by `58e5`

@_5893: push    BC                                                      ;$5893
        push    DE
        call    findEmptyMob
        pop     DE
        pop     BC
        ret     c

        push    IX
        push    HL
        pop     IX

        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $2E                 ;falling bridge piece
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       C
        ld      [IX+Mob.X+1],       B
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       E
        ld      [IX+Mob.Y+1],       D
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        ld      [IX+Mob.flags],     A

        pop     IX
        and     A
        ret

        ;=======================================================================
        ; referenced by table at `_58e5` - index $1B

@_58d0: bit     7,      [IX+Mob.flags]                                  ;$58D0
        ret     z

        ;is Sonic on the screen (vertically)
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,      DE
        ret     nc

        ;clear joypad input
        ld      [IY+Vars.joypad],  $FF
        ret

        ;=======================================================================
        ; lookup table to the functions above
        ; (these probably handle the different solidity values)

@_58e5: .ADDR   @_54bc @_54c6 @_54ce @_550f @_552d @_5556 @_5578 @_5590  ;$58E5
        .ADDR   @_55a8 @_55b6 @_55e2 @_55eb @_565c @_567c @_56a6 @_56b6
        .ADDR   @_56c6 @_56d6 @_5761 @_5771 @_5781 @_5791 @_57cd @_57f6
        .ADDR   @_5808 @_584b @_5883 @_58d0

        ;=======================================================================
        ; sprite layouts

@_591d: ; Sonic's sprite layout                                         ;$591D
        .BYTE   $B4 $B6 $B8 $FF $FF $FF
        .BYTE   $BA $BC $BE $FF $FF $FF
        .BYTE   $FF $FF

@_592b: .BYTE   $B8 $B6 $B4 $FF $FF $FF                                 ;$592B
        .BYTE   $BE $BC $BA $FF $FF $FF
        .BYTE   $FF $FF

@_5939: .BYTE   $B4 $B6 $B8 $FF $FF $FF                                 ;$5939
        .BYTE   $BA $BC $BE $FF $FF $FF
        .BYTE   $98 $9A $FF $FF $FF $FF

@_594b: .BYTE   $B4 $B6 $B8 $FF $FF $FF                                 ;$594B
        .BYTE   $BA $BC $BE $FF $FF $FF
        .BYTE   $FE $9C $9E $FF $FF $FF

@_595d: ; unknown data                                                  ;$593D
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00

@_5965: ; unknown data                                                  ;$5965
        .BYTE   $99 $59 $99 $59 $CB $59 $DD $59 $DF $59 $E2 $59 $E5 $59 $FB $59
        .BYTE   $FE $59 $01 $5A $53 $5A $65 $5A $68 $5A $6B $5A $AF $5A $C5 $5A
        .BYTE   $CC $5A $D0 $5A $DE $5A $E1 $5A $E4 $5A $E7 $5A $EA $5A $00 $5B
        .BYTE   $03 $5B $06 $5B $00 $00 $00 $00 $00 $00 $00 $00 $01 $01 $01 $01
        .BYTE   $01 $01 $01 $01 $02 $02 $02 $02 $02 $02 $02 $02 $03 $03 $03 $03
        .BYTE   $03 $03 $03 $03 $04 $04 $04 $04 $04 $04 $04 $04 $05 $05 $05 $05
        .BYTE   $05 $05 $05 $05 $FF $00 $0D $0D $0D $0D $0E $0E $0E $0E $0F $0F
        .BYTE   $0F $0F $10 $10 $10 $10 $FF $00 $FF $00 $13 $FF $00 $06 $FF $00
        .BYTE   $08 $08 $08 $08 $09 $09 $09 $09 $0A $0A $0A $0A $0B $0B $0B $0B
        .BYTE   $0C $0C $0C $0C $FF $00 $07 $FF $00 $00 $FF $00 $0C $0C $0C $0C
        .BYTE   $0C $0C $0C $0C $0C $0C $0C $0C $0C $0C $0C $0C $08 $08 $08 $08
        .BYTE   $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $08 $09 $09 $09 $09
        .BYTE   $09 $09 $09 $09 $09 $09 $09 $09 $09 $09 $09 $09 $0A $0A $0A $0A
        .BYTE   $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0B $0B $0B $0B
        .BYTE   $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $FF $00 $13 $13
        .BYTE   $13 $13 $13 $13 $13 $13 $25 $25 $25 $25 $25 $25 $25 $25 $FF $00
        .BYTE   $11 $FF $00 $14 $FF $00 $16 $16 $16 $16 $16 $16 $16 $16 $16 $16
        .BYTE   $16 $16 $16 $16 $16 $16 $15 $15 $15 $15 $15 $15 $15 $15 $15 $15
        .BYTE   $15 $15 $15 $15 $15 $15 $15 $15 $16 $16 $16 $16 $16 $16 $16 $16
        .BYTE   $16 $16 $16 $16 $16 $16 $16 $16 $17 $17 $17 $17 $17 $17 $17 $17
        .BYTE   $17 $17 $17 $17 $17 $17 $17 $17 $FF $22 $19 $19 $19 $19 $1A $1A
        .BYTE   $1B $1B $1C $1C $1D $1D $1E $1E $1F $1F $20 $20 $21 $21 $FF $12
        .BYTE   $0C $08 $09 $0A $0B $FF $00 $12 $12 $FF $00 $12 $12 $12 $12 $12
        .BYTE   $12 $24 $24 $24 $24 $24 $24 $FF $00 $00 $FF $00 $26 $FF $00 $22
        .BYTE   $FF $00 $23 $FF $00 $21 $21 $20 $20 $1F $1F $1E $1E $1D $1D $1C
        .BYTE   $1C $1B $1B $1A $1A $19 $19 $19 $19 $FF $12 $19 $FF $00 $1A $FF
        .BYTE   $00 $1B $FF $00
        ;

powerups_ring_process:                                                  ;$5B09
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    24
        call    _5da8
        ld      HL,     $0003
        ld      [RAM_TEMP6],    HL

        call    detectCollisionWithSonic
        jr      c,      @_1

        call    _5deb
        jr      c,      @_1

        ;Add 10 rings to the ring count
@_5b24: ld      A,      $10
        call    increaseRings

@_5b29: xor     A       ;set A to 0
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ret

        ;-----------------------------------------------------------------------

@_1:    ld      HL,     $5180           ;$15180 - blinking items art

@_5b34: call    loadPowerUpIcon

        ld      [IX+Mob.spriteLayout+0],    <@_5bbf
        ld      [IX+Mob.spriteLayout+1],    >@_5bbf

        ld      A,      [RAM_FRAMECOUNT]
        and     %00000111
        cp      $05
        ret     nc

        ld      [IX+Mob.spriteLayout+0],    <@_5bcc
        ld      [IX+Mob.spriteLayout+1],    >@_5bcc
        ld      L,      [IX+Mob.Xsubpixel]
        ld      H,      [IX+Mob.X+0]
        ld      A,      [IX+Mob.X+1]
        ld      E,      [IX+Mob.Xspeed+0]
        ld      D,      [IX+Mob.Xspeed+1]
        add     HL,     DE
        adc     A,      [IX+Mob.Xdirection]
        ld      L,      H
        ld      H,      A
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Ysubpixel]
        ld      H,      [IX+Mob.Y+0]
        ld      A,      [IX+Mob.Y+1]

        bit     7,      [IX+Mob.flags]
        jr      nz,     @_2

        ld      E,      [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        add     HL,     DE
        adc     A,      [IX+Mob.Ydirection]
@_2:    ld      L,      H
        ld      H,      A
        ld      [RAM_TEMP3],    HL
        ld      HL,     $0004
        ld      [RAM_TEMP4],    HL
        ld      HL,     $0000
        ld      [RAM_TEMP6],    HL

        ld      A,      $5C
        call    _3581

        ld      HL,     $000C
        ld      [RAM_TEMP4],    HL

        ld      A,      $5E
        call    _3581

        bit     1,      [IX+Mob.flags]
        ret     z

        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0040
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ret

@_5bbf: .BYTE   $54 $56 $58 $FF $FF $FF
        .BYTE   $AA $AC $AE $FF $FF $FF
        .BYTE   $FF

@_5bcc: .BYTE   $54 $FE $58 $FF $FF $FF
        .BYTE   $AA $AC $AE $FF $FF $FF
        .BYTE   $FF
        ;

powerups_speed_process:                                                 ;$5BD9
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    24
        call    _5da8
        ld      HL,     $0003
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_1

        call    _5deb
        jr      c,      @_1

        ld      A,      $F0
        ld      [RAM_SONIC.unknown15],  A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_02
                rst     $28     ;=rst_playSFX
        .ENDIF

        jp      powerups_ring_process@_5b29

@_1:    ld      HL,     $5200
        jp      powerups_ring_process@_5b34
        ;

powerups_life_process:                                                  ;$5C05
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    24
        call    _5da8

        ;check if the level has its bit flag set at D305+
        ld      HL,     RAM_D305
        call    getLevelBitFlag

        ld      A,      [HL]
        and     C
        jr      z,      @_1                                     ;if not set, skip ahead

        ld      [IX+Mob.type],      $FF                     ;remove object?
        jp      powerups_ring_process@_5b29

@_1:    ld      HL,             $0003
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        call    _5deb
        jr      c,      @_2

        bit     2,      [IX+Mob.flags]
        jp      nz,     powerups_ring_process@_5b24

        ld      HL,     RAM_LIVES
        inc     [HL]

        ;set the level's bit flag at D305+
        ld      HL,     RAM_D305
        call    getLevelBitFlag
        ld      A,      [HL]
        or      C
        ld      [HL],   A

        xor     A                                          ;set A to 0
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_09
                rst     $28     ;=rst_playSFX
        .ENDIF

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      28                                              ;special stage?
        ret     nc

        ld      HL,     RAM_D280
        inc     [HL]
        ret

        ;-----------------------------------------------------------------------

@_2:    ld      A,       [RAM_CURRENT_LEVEL]
        cp      4                                               ;level 4 (Bridge Act 2)?
        jr      z,      @_4

        cp      $09                                             ;level 9 (Labyrinth Act 1)?
        jr      z,      @_6

        cp      $0C                                             ;level 12 (Scrap Brain Act 1)?
        jr      z,      @_7

        cp      $11                                             ;level 11 (Labyrinth Act 3)?
        jr      z,      @_8

@_3:    ld      HL,     $5280
        jp      powerups_ring_process@_5b34

@_4:    ld      C,      $00
        ld      DE,     $0040
        ld      A,      [IX+Mob.unknown13]
        cp      $3C
        jr      c,      @_5

        dec     C
        ld      DE,     $FFC0

@_5:    ld      [IX+Mob.Yspeed+0],      E
        ld      [IX+Mob.Yspeed+1],      D
        ld      [IX+Mob.Ydirection],    C

        inc     [IX+Mob.unknown13]
        ld      A,      [IX+Mob.unknown13]
        cp      $50
        jr      c,      @_3

        ld      [IX+Mob.unknown13], $28
        jr      @_3

@_6:    set     2,      [IX+Mob.flags]
        ld      HL,     RAM_D317
        call    getLevelBitFlag
        ld      A,      [HL]
        ld      HL,     $5180
        and     C
        jp      z,      powerups_ring_process@_5b34

        res     2,      [IX+Mob.flags]

        ld      HL,     $5280
        jp      powerups_ring_process@_5b34

@_7:    set     1,      [IX+Mob.flags]

        ld      [IX+Mob.Xspeed+0],  $80
        ld      [IX+Mob.Xspeed+1],  $00
        ld      [IX+Mob.Xdirection],        $00
        jr      @_3

@_8:    ld      A,      [RAM_D280]
        cp      $11
        jr      nc,     @_3

        ld      [IX+Mob.type],      $FF                     ;remove object?
        jr      @_3
        ;

powerups_shield_process:                                                ;$5CD7
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    24
        call    _5da8

        ld      HL,     $0003
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_1

        call    _5deb
        jr      c,      @_1

        set     5,      [IY+Vars.flags6]
        jp      powerups_ring_process@_5b29

@_1:    ld      HL,     $5300
        jp      powerups_ring_process@_5b34
        ;

powerups_invincibility_process:                                         ;$5CFF
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    24
        call    _5da8

        ld      HL,     $0003
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_1

        call    _5deb
        jr      c,      @_1

        set     0,      [IY+Vars.unknown0]

        ld      A,              $F0
        ld      [RAM_D28D],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_INVINCIBILITY
                rst     $18     ;=rst_playMusic
        .ENDIF

        jp      powerups_ring_process@_5b29

@_1:    ld      HL,     $5380
        jp      powerups_ring_process@_5b34
        ;

powerups_checkpoint_process:                                            ;$5D2F
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    24
        call    _5da8

        ld      HL,             $0003
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_1

        call    _5deb
        jr      c,      @_1

        ld      HL,     RAM_D311
        call    getLevelBitFlag
        ld      A,      [HL]
        or      C
        ld      [HL],   A

        ld      A,      [RAM_CURRENT_LEVEL]
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     RAM_D32E
        add     HL,     DE
        ex      DE,     HL                                      ;DE is D32E + level number * 2
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     HL
        add     HL,     HL
        add     HL,     HL
        ld      A,      H
        ld      [DE],   A
        inc     DE
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     HL
        add     HL,     HL
        add     HL,     HL
        ld      A,      H
        dec     A
        ld      [DE],   A
        jp      powerups_ring_process@_5b29

@_1:    ld      HL,     $5480
        jp      powerups_ring_process@_5b34
        ;

powerups_continue_process:                                              ;$5D80
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    24
        call    _5da8

        ld      HL,             $0003
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_1

        call    _5deb
        jr      c,      @_1

        set     3,      [IY+Vars.flags9]
        jp      powerups_ring_process@_5b29

@_1:    ld      HL,     $5500
        jp      powerups_ring_process@_5b34
        ;

_5da8:                                                                  ;$5DA8
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        bit     0,      [IX+Mob.flags]
        ret     nz

        ld      A,      [RAM_LEVEL_SOLIDITY]
        and     A
        jr      nz,     @_1

        ld      BC,     $0000
        ld      E,      C
        ld      D,      B
        call    getFloorLayoutRAMAddressForMob

        ld      DE,     $0016
        ld      BC,     $0012
        ld      A,      [HL]
        cp      $AB
        jr      z,      @_2

@_1:    ld      DE,     $0004
        ld      BC,     $0000
@_2:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H

        set     0,      [IX+Mob.flags]

        ret
        ;

_5deb:                                                                  ;$5DEB
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      HL,             $0804
        ld      [RAM_TEMP1],    HL

        ld      A,      [RAM_SONIC.flags]
        and     %00000001
        jr      nz,     @_2

        ld      DE,     [RAM_SONIC.X]
        ld      C,      [IX+Mob.X+0]
        ld      B,      [IX+Mob.X+1]
        ld      HL,     $FFEE
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      HL,     $0010
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_4

        ld      A,      [RAM_SONIC.flags]
        and     $04
        jr      nz,     @_1

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      A,      [RAM_SONIC.height]
        ld      C,      A
        xor     A
        ld      B,      A
        sbc     HL,     BC
        ld      [RAM_SONIC.Y],  HL
        ld      [RAM_D28E],     A
        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        ld      HL,     RAM_SONIC.flags

        set     7,      [HL]
        scf

        ret

@_1:    ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_3

@_2:    call    _36be
        and     A

        ret

@_3:    ld      [IX+Mob.Yspeed+0],      $80
        ld      [IX+Mob.Yspeed+1],      $FE
        ld      [IX+Mob.Ydirection],    $FF
        ld      HL,     $0400
        xor     A
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        ld      [RAM_D28E],             A
        set     1,      [IX+Mob.flags]
        scf
        ret

@_4:    ld      HL,     [RAM_SONIC.X]
        ld      DE,     $000C
        add     HL,     DE
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      BC,     $000A
        add     HL,     BC
        ld      BC,     $FFEB
        and     A
        sbc     HL,     DE
        jr      nc,     @_5

        ld      BC,     $0015
@_5:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     BC
        ld      [RAM_SONIC.X],  HL

        xor     A
        ld      [RAM_SONIC.Xsubpixel],  A
        ld      L,      A
        ld      H,      A
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   HL
        scf
        ret
        ;

powerups_emerald_process:                                               ;$5EA2
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      HL,     RAM_D30B
        call    getLevelBitFlag
        ld      A,      [HL]
        and     C
        jr      nz,     @_1

        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    17
        call    _5da8

        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A

        ld      HL,             $0202
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      HL,     RAM_D30B
        call    getLevelBitFlag

        ld      A,      [HL]
        or      C
        ld      [HL],   A
        ld      HL,     RAM_D27F
        inc     [HL]
        ld      A,              $FE
        ld      [RAM_D28B],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_EMERALD
                rst     $18     ;=rst_playMusic
        .ENDIF

@_1:    ld      [IX+Mob.type],  $FF                     ;remove object?
        ret

@_2:    ld      A,      [RAM_FRAMECOUNT]
        rrca
        jr      c,      @_3

        ld      [IX+Mob.spriteLayout+0],    <@_5f10
        ld      [IX+Mob.spriteLayout+1],    >@_5f10
@_3:    ld      L,       [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0020
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ld      HL,     $5400                                   ;$15400 - emerald in blinking items art
        call    loadPowerUpIcon

        ret

@_5f10: .BYTE   $5C $5E $FF $FF $FF $FF
        .BYTE   $FF
        ;

boss_endSign_process:                                                   ;$5F17
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     24
        ld      [IX+Mob.height],    48

        ;the end-sign has to load its own graphics and palette,
        ;check if this has been done yet
        bit     0,      [IX+Mob.unknown11]
        ;TODO: if we have to do this check every frame, then it would be better to turn this around and
        ;      fall through for the more common case, and jump for the one-time initialisation
        jr      nz,     @_1

        ;one time intialisation:
        ;-----------------------------------------------------------------------
@init:  ;turn 'under-water' mode off -- disabling the 'water line' raster effect,
        ;this is because the end-sign has no equivilent under-water palette
        res     7,      [IY+Vars.flags6]
        ;turn off auto-scroll to the right, if it was on
        ;TODO: would also need to disable auto-scroll up, if it were in use
        res     3,      [IY+Vars.scrollRingFlags]

        ;end-sign sprite set
        ld      HL,     $4294
        ld      DE,     $2000
        ld      A,      9
        call    decompressArt

        ;load the end-sign palette
        ld      HL,     @S1_EndSign_Palette
        ld      A,      %00000010
        call    loadPaletteOnInterrupt

        ;initialisation complete, do not repeat this step
        set     0,      [IX+Mob.unknown11]

        ;-----------------------------------------------------------------------

        ;prevent the player leaving the screen by locking the left-hand side of the screen
        ;(the edge of the level is effectively moved up to the current screen position)
@_1:    ld      HL,     [RAM_CAMERA_X]
        ld      [RAM_LEVEL_LEFT],       HL

        ;set the right-hand edge of the level such that the end-sign will be in the middle of the screen:
        ;note that the right-hand edge of the level is defined as the maximum left-hand position of the screen on
        ;the level -- the width of the screen is implicit. i.e. the same value for the left & right level limits
        ;will simply lock the screen in place and prevent any scrolling
        ld      L,     [IX+Mob.X+0]
        ld      H,     [IX+Mob.X+1]
        ;subtract 112 -- it's faster to add a big number and cause an overflow into a lower number because
        ;the 16-bit subtract instruction `sbc` adds any existing carry
        ;TODO: this number should be calculated based on the width of the sign, and is currently incorrect
        ;      -- perhaps the sign was originally intended to be 28 or 32 px wide
        ld      DE,      $FF90                           ;-112
        add     HL,    DE
        ld      [RAM_LEVEL_RIGHT],      HL

        ;change the size of the zones at the top & bottom of the screen that initiate scrolling.
        ;this is done so that if you are above / below the sign, the camera will centre the screen
        ld      HL,     128             ;=$0080
        ld      [RAM_SCROLLZONE_OVERRIDE_TOP],          HL
        ld      HL,     136             ;=$0088
        ld      [RAM_SCROLLZONE_OVERRIDE_BOTTOM],       HL

        ;a copy of the player's status that the end-sign keeps
        ld      C,      [IX+Mob.unknown13]
        ;get the player's current status
        ld      A,      [RAM_SONIC.flags]
        ;TODO: whatever bit 7 is on Sonic, it's forced on
        and     %10000000

        ld      [IX+Mob.unknown13], A
        ;BUG: this can never be true?
        jr      z,      @_3
        ;has the player's status changed since the last frame?
        cp      C
        jr      z,      @_3

        bit     7,      [IX+Mob.flags]
        jr      z,      @_3

        ;-----------------------------------------------------------------------

        ;compare the x-positions of the end-sign and player
        ;TODO: the sign X position was already read earlier, we could use the stack for that
        ld      E,     [IX+Mob.X+0]
        ld      D,     [IX+Mob.X+1]
        ld      HL,    [RAM_SONIC.X]
        and     A                                    ;clear the carry before doing a 16-bit add/subtract
        sbc     HL,   DE

        ;has the player hit/passed the sign?
        bit     7,      H                            ;is the negative bit set?
        jr      z,      @_2                                     ;no? skip forward

        ;convert negative number to positive (2's compliment)
        ;-- take the distance between player and end-sign and flip the bits, then add 1
        ld      A,  L
        cpl                                                     ;flip the bits (can only be done in A)
        ld      L,   A
        ld      A,  H
        cpl                                                     ;flip the bits (can only be done in A)
        ld      H,   A
        inc     HL                                     ;add 1, as negative numbers have +1 range

        ;check for maximum speed allowed beyond the end-sign
        ;-- the height the end-sign leaps into the air is based upon your speed
        ;   (or more accurately, how far past it you are)
@_2:    ld      DE,     100                             ;=$0064
        and     A
        sbc     HL,    DE
        jr      nc,     @_3

        ;make the end-sign leap up into the air at maximum speed
        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $FE
        ld      [IX+Mob.Ydirection],        $FF

        ;-----------------------------------------------------------------------

@_3:    ld      L,    [IX+Mob.Yspeed+0]
        ld      H,   [IX+Mob.Yspeed+1]
        ld      A,        [IX+Mob.Ydirection]
        ld      DE,     26                                      ;=$001A
        add     HL,  DE
        adc     A,        $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A

        bit     3,      [IX+Mob.unknown11]
        jr      nz,     @_7
        bit     2,      [IX+Mob.unknown11]
        jr      z,      @_4
        bit     7,      [IX+Mob.flags]
        jr      z,      @_7

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_ACTCOMPLETE
                rst     $18     ;=rst_playMusic
                ld      A,      SFX_ID_0C
                rst     $28     ;=rst_playSFX
        .ENDIF

        res     2,      [IX+Mob.unknown11]
        set     3,      [IX+Mob.unknown11]
        ld      A,      $A0
        ld      [RAM_D289],     A
        set     1,      [IY+Vars.flags6]
        jp      @_7

@_4:    ld      HL,             $0A0A
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_7

        bit     7,      [IX+Mob.Ydirection]
        jr      nz,     @_7

        bit     1,      [IX+Mob.unknown11]
        jr      nz,     @_7

        ld      DE,     [RAM_SONIC.Xspeed]
        bit     7,      D
        jr      z,      @_5

        ld      A,      E
        cpl
        ld      E,      A
        ld      A,      D
        cpl
        ld      D,      A
        inc     DE
@_5:    ld      HL,     $0300
        and     A
        sbc     HL,     DE
        jr      nc,     @_6

        ld      DE,     $0300
@_6:    ex      DE,     HL
        add     HL,     HL
        ld      [IX+Mob.unknown14], L
        ld      [IX+Mob.unknown15], H
        ld      [IX+Mob.unknown12], $00
        set     1,      [IX+Mob.unknown11]
        res     3,      [IY+Vars.flags6]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_0B
                rst     $28     ;=rst_playSFX
        .ENDIF

@_7:    ld      DE,     @_6157
        bit     1,      [IX+Mob.unknown11]
        jr      nz,     @_

        bit     2,      [IX+Mob.unknown11]
        jr      nz,     @_

        ld      DE,     $6171
        bit     3,      [IX+Mob.unknown11]
        jr      z,      @_

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $0C
        jr      c,      @_8
        cp      $1C
        jr      c,      @_9

        ld      DE,     $618E
        ld      c,      $01
        jr      @_11

@_8:    ld      DE,     $61A8
        ld      C,      $04
        ld      A,      [RAM_RINGS]
        cp      $50
        jr      nc,     @_11

@_9:    cp      $40
        jr      z,      @_10

        ld      DE,     $61C2
        ld      C,      $03
        and     $0F
        jr      z,      @_11

@_10:   ld      A,      [RAM_RINGS]
        srl     A
        srl     A
        srl     A
        srl     A
        ld      B,      A
        ld      A,      [RAM_CURRENT_LEVEL]
        and     $03
        inc     A
        ld      DE,     $6174
        ld      C,      $02
        cp      B
        jr      z,      @_11

        ld      DE,     $618E
        ld      C,      $01
@_11:   ld      A,      C
        ld      [RAM_D288],     A
@_:     ld      L,      [IX+Mob.unknown12]
        ld      H,      $00
        add     HL,     DE
        ld      A,      [HL]
        cp      $FF
        jr      nz,     @_12

        inc     HL
        ld      A,      [HL]
        ld      [IX+Mob.unknown12], A
        jp      @_

@_12:   ld      L,      A
        ld      H,      $00
        add     HL,     HL
        ld      E,      L
        ld      D,      H
        add     HL,     HL
        add     HL,     HL
        add     HL,     HL
        add     HL,     DE
        ld      DE,     @_61dc
        add     HL,     DE
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H

        bit     1,      [IX+Mob.unknown11]
        jr      nz,     @_13

        inc     [IX+Mob.unknown12]
        ret

@_13:   ld      A,       [IX+Mob.unknown14]
        add     A,      [IX+Mob.unknown16]
        ld      [IX+Mob.unknown16], A
        ld      A,      [IX+Mob.unknown15]
        push    AF
        adc     A,      [IX+Mob.unknown17]
        ld      [IX+Mob.unknown17], A
        pop     AF
        adc     A,      [IX+Mob.unknown12]
        cp      $18
        jr      c,      @_14

        xor     A
@_14:   ld      [IX+Mob.unknown12],     A
        ld      E,      [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        and     A
        jp      p,      @_15

        ld      HL,     $FC00
        sbc     HL,     DE
        ret     nc

@_15:   ex      DE,     HL
        ld      E,      [IX+Mob.unknown14]
        ld      D,      [IX+Mob.unknown15]
        ld      C,      E
        ld      B,      D
        srl     D
        rr      E
        srl     D
        rr      E
        srl     D
        rr      E
        srl     D
        rr      E
        srl     D
        rr      E
        and     A
        sbc     HL,     DE
        sbc     A,      $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        xor     A
        ld      DE,     $0008
        sbc     HL,     DE
        jr      c,      @_16

        ld      L,      C
        ld      H,      B
        ld      DE,     $0010
        xor     A
        sbc     HL,     DE
        ld      [IX+Mob.unknown14], L
        ld      [IX+Mob.unknown15], H
        ret     nc

@_16:   ld      [IX+Mob.Yspeed+0],      A
        ld      [IX+Mob.Yspeed+1],      A
        ld      [IX+Mob.Ydirection],    A
        res     1,      [IX+Mob.unknown11]
        set     2,      [IX+Mob.unknown11]
        ld      [IX+Mob.unknown12], $00

        ret

        ;-----------------------------------------------------------------------

        ;UNKNOWN
@_6157:                         ;$6157

        .BYTE   $00 $00 $00 $00 $00 $00
        .BYTE   $03 $03 $03 $03 $03 $03
        .BYTE   $02 $02 $02 $02 $02 $02
        .BYTE   $04 $04 $04 $04 $04 $04
        .BYTE   $FF

        .BYTE   $00 $00 $FF

        .BYTE   $00 $00 $00 $00 $00 $00 $00
        .BYTE   $03 $03 $03 $03 $03 $03
        .BYTE   $02 $02 $02 $02 $02 $02
        .BYTE   $01 $01 $01 $01 $01 $01
        .BYTE   $FF $12

        .BYTE   $00 $00 $00 $00 $00 $00
        .BYTE   $03 $03 $03 $03 $03 $03
        .BYTE   $02 $02 $02 $02 $02 $02
        .BYTE   $05 $05 $05 $05 $05 $05
        .BYTE   $FF $12

        .BYTE   $00 $00 $00 $00 $00 $00
        .BYTE   $03 $03 $03 $03 $03 $03
        .BYTE   $02 $02 $02 $02 $02 $02
        .BYTE   $06 $06 $06 $06 $06 $06
        .BYTE   $FF $12

        .BYTE   $00 $00 $00 $00 $00 $00
        .BYTE   $03 $03 $03 $03 $03 $03
        .BYTE   $02 $02 $02 $02 $02 $02
        .BYTE   $07 $07 $07 $07 $07 $07
        .BYTE   $FF $12

        ;these are sprite layouts

@_61dc: .BYTE   $4E $50 $52 $54 $FF $FF                                         ;$61DC
        .BYTE   $6E $70 $72 $74 $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        .BYTE   $08 $0A $0C $0E $FF $FF
        .BYTE   $28 $2A $2C $2E $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        .BYTE   $FE $12 $14 $FF $FF $FF
        .BYTE   $FE $32 $34 $FF $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        .BYTE   $16 $18 $1A $1C $FF $FF
        .BYTE   $36 $38 $3A $3C $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        .BYTE   $56 $58 $5A $5C $FF $FF
        .BYTE   $76 $78 $7A $7C $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        .BYTE   $00 $02 $04 $06 $FF $FF
        .BYTE   $20 $22 $24 $26 $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        .BYTE   $4E $4A $4C $54 $FF $FF
        .BYTE   $6E $6A $6C $74 $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        .BYTE   $4E $46 $48 $54 $FF $FF
        .BYTE   $6E $66 $68 $74 $FF $FF
        .BYTE   $FE $42 $44 $FF $FF $FF

        ;-----------------------------------------------------------------------

@S1_EndSign_Palette:                                                    ;$626C

        .BYTE   $38 $20 $35 $1B $16 $2A $00 $3F $03 $0F $01 $00 $00 $00 $00 $00
        ;

palettePointers:                                                        ;$627C
;===============================================================================
@greenHill:
        .ADDR   paletteData@greenHill
@bridge:
        .ADDR   paletteData@bridge
@jungle:
        .ADDR   paletteData@jungle
@labyrinth:
        .ADDR   paletteData@labyrinth
@scrapBrain:
        .ADDR   paletteData@scrapBrain
@skyBaseExt:
        .ADDR   paletteData@skyBaseExt
@skyBaseInt:
        .ADDR   paletteData@skyBaseInt
@specialStage:
        .ADDR   paletteData@specialStage
        ;

paletteCyclePointers:                                                   ;$628C
;===============================================================================
@greenHill:
        .ADDR   paletteData@greenHill_cycles
@bridge:
        .ADDR   paletteData@bridge_cycles
@jungle:
        .ADDR   paletteData@jungle_cycles
@labyrinth:
        .ADDR   paletteData@labyrinth_cycles
@scrapBrain:
        .ADDR   paletteData@scrapBrain_cycles
@skyBase1:
        .ADDR   paletteData@skyBase_cycles
@skyBaseInt:
        .ADDR   paletteData@skyBaseInt_cycles
@specialStage:
        .ADDR   paletteData@specialStage_cycles
@skyBaseExt:
        .ADDR   paletteData@skyBaseExt_cycles
        ;

; the regular and cycle palettes are lumped together in one data-block,
; the pointer tables above sort them into an order

paletteData:                                                            ;$629E
;===============================================================================
@greenHill:                                                             ;$629E
        .TABLE  DSB 16
        .ROW    $38 $01 $06 $0B $04 $08 $0C $3D $3B $34 $3C $3E $3F $0F $00 $3F
        .ROW    $38 $20 $35 $1B $16 $2A $00 $3F $01 $03 $3A $06 $0F $00 $00 $00

@greenHill_cycles:                                                      ;$62BE
        .TABLE  DSB 16
        .ROW    $38 $01 $06 $0B $04 $08 $0C $3D $3B $34 $3C $3E $3F $0F $00 $3F
        .ROW    $38 $01 $06 $0B $04 $08 $0C $3D $3B $34 $3F $3C $3E $0F $00 $3F
        .ROW    $38 $01 $06 $0B $04 $08 $0C $3D $3B $34 $3E $3F $3C $0F $00 $3F

        ;-----------------------------------------------------------------------

@bridge:                                                                ;$62EE
        .TABLE  DSB 16
        .ROW    $38 $01 $06 $0B $2A $3A $0C $19 $3D $24 $38 $3C $3F $1F $00 $3F
        .ROW    $38 $20 $35 $1B $16 $2A $00 $3F $01 $03 $3A $06 $0F $27 $0B $00

@bridge_cycles:                                                         ;$630E
        .TABLE  DSB 16
        .ROW    $38 $01 $06 $0B $3A $08 $0C $19 $3C $24 $38 $3C $3F $1F $00 $3F
        .ROW    $38 $01 $06 $0B $3A $08 $0C $19 $3C $24 $3F $38 $3C $1F $00 $3F
        .ROW    $38 $01 $06 $0B $3A $08 $0C $19 $3C $24 $3C $3F $38 $1F $00 $3F

        ;-----------------------------------------------------------------------

@jungle:                                                                ;$633E
        .TABLE  DSB 16
        .ROW    $04 $08 $0C $06 $0B $05 $25 $01 $03 $10 $34 $38 $3E $1F $00 $3F
        .ROW    $04 $20 $35 $1B $16 $2A $00 $3F $01 $03 $3A $06 $0F $27 $0B $00

@jungle_cycles:                                                         ;$635E
        .TABLE  DSB 16
        .ROW    $04 $08 $0C $06 $0B $05 $26 $01 $03 $10 $34 $38 $3E $0F $00 $3F
        .ROW    $04 $08 $0C $06 $0B $05 $26 $01 $03 $10 $3E $34 $38 $0F $00 $3F
        .ROW    $04 $08 $0C $06 $0B $05 $26 $01 $03 $10 $38 $3E $34 $0F $00 $3F

        ;-----------------------------------------------------------------------

@labyrinth:                                                             ;$638E
        .TABLE  DSB 16
        .ROW    $00 $01 $06 $0B $27 $14 $18 $29 $12 $10 $1E $09 $04 $0F $00 $3F
        ;the water line raster split refers directly to this sprite palette:
        .ROW    $00 $20 $35 $1B $16 $2A $00 $3F $01 $03 $3A $06 $0F $27 $0B $15

@labyrinth_cycles:                                                      ;$63AE
        .TABLE  DSB 16
        .ROW    $00 $01 $06 $0B $27 $14 $18 $29 $12 $10 $1E $09 $04 $0F $00 $3F
        .ROW    $00 $01 $06 $0B $27 $14 $18 $29 $12 $10 $09 $04 $1E $0F $00 $3F
        .ROW    $00 $01 $06 $0B $27 $14 $18 $29 $12 $10 $04 $1E $09 $0F $00 $3F

        ;-----------------------------------------------------------------------

@scrapBrain:                                                            ;$63DE
        .TABLE  DSB 16
        .ROW    $00 $10 $15 $29 $3D $01 $14 $02 $05 $0A $0F $3F $07 $0F $00 $3F
        .ROW    $00 $20 $35 $1B $16 $2A $00 $3F $01 $03 $3D $15 $0F $27 $10 $29

@scrapBrain_cycles:                                                     ;$63FE
        .TABLE  DSB 16
        .ROW    $00 $10 $15 $29 $3D $01 $14 $02 $05 $0A $0F $3F $07 $0F $00 $3F
        .ROW    $00 $10 $15 $29 $3D $01 $14 $02 $3F $05 $0A $0F $07 $0F $00 $3F
        .ROW    $00 $10 $15 $29 $3D $01 $14 $02 $0F $3F $05 $0A $07 $0F $00 $3F
        .ROW    $00 $10 $15 $29 $3D $01 $14 $02 $0A $0F $3F $05 $07 $0F $00 $3F

        ;-----------------------------------------------------------------------

@skyBaseExt:                                                            ;$643E
        .TABLE  DSB 16
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $10 $3D $39 $3D $3F $24 $00 $38
        .ROW    $10 $20 $35 $1B $16 $2A $00 $3F $01 $03 $3A $06 $0F $27 $15 $00

@skyBase_cycles:                                                        ;$645E
        .TABLE  DSB 16
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $10 $3D $39 $3D $3F $24 $00 $38
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $10 $3F $3D $39 $3D $24 $00 $38
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $10 $3D $3F $3D $39 $24 $00 $38
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $10 $39 $3D $3F $3D $24 $00 $38

@skyBase_cycles_Lightning1:                                             ;$649E
        .TABLE  DSB 16
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $10 $3D $39 $3D $3F $24 $00 $38
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $10 $3F $3D $39 $3D $24 $00 $38
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $20 $3D $3F $3D $39 $24 $00 $38
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $2A $39 $3D $3F $3D $24 $00 $38

@skyBase_cycles_Lightning2:                                             ;$64DE
        .TABLE  DSB 16
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $2F $3D $39 $3D $3F $24 $00 $38
        .ROW    $30 $14 $29 $2E $3A $01 $02 $17 $10 $3F $3D $39 $3D $0F $00 $3F
        .ROW    $10 $10 $20 $34 $30 $10 $11 $25 $3F $3D $3F $3D $39 $24 $00 $38
        .ROW    $30 $14 $29 $2E $3A $01 $02 $17 $10 $3F $3D $39 $3D $0F $00 $3F

@skyBaseExt_cycles:                                                     ;$651E
        .TABLE  DSB 16
        .ROW    $10 $14 $29 $2E $3A $01 $02 $17 $10 $3D $39 $3D $3F $0F $00 $3F
        .ROW    $10 $14 $29 $2E $3A $01 $02 $17 $10 $3F $3D $39 $3D $0F $00 $3F
        .ROW    $10 $14 $29 $2E $3A $01 $02 $17 $10 $3D $3F $3D $39 $0F $00 $3F
        .ROW    $10 $14 $29 $2E $3A $01 $02 $17 $10 $39 $3D $3F $3D $0F $00 $3F

        ;-----------------------------------------------------------------------

@specialStage:                                                          ;$655E
        .TABLE  DSB 16
        .ROW    $10 $04 $3B $1B $19 $2D $21 $32 $17 $13 $12 $27 $30 $1F $00 $3F
        .ROW    $10 $20 $35 $1B $16 $2A $00 $3F $19 $13 $12 $27 $04 $1F $21 $30

@specialStage_cycles:                                                   ;$657E
        .TABLE  DSB 16
        .ROW    $10 $04 $3B $1B $19 $2D $11 $32 $17 $13 $12 $27 $30 $1F $00 $3F

        ;-----------------------------------------------------------------------

@skyBaseInt:                                                            ;$658E
        .TABLE  DSB 16
        .ROW    $00 $14 $39 $3D $28 $10 $20 $34 $0F $07 $3C $14 $39 $0F $00 $3F
        .ROW    $00 $20 $35 $1B $16 $2A $00 $3F $15 $3A $0F $03 $01 $02 $3E $00

@skyBaseInt_cycles:                                                     ;$65AE
        .TABLE  DSB 16
        .ROW    $00 $14 $39 $3D $28 $10 $20 $34 $0F $07 $3C $14 $39 $0F $00 $3F
        .ROW    $00 $14 $39 $3D $28 $10 $20 $34 $07 $0F $28 $14 $39 $0F $00 $3F
        .ROW    $00 $14 $39 $3D $28 $10 $20 $34 $0F $07 $14 $14 $39 $0F $00 $3F
        .ROW    $00 $14 $39 $3D $28 $10 $20 $34 $07 $0F $00 $14 $39 $0F $00 $3F

        ;

badnick_crabmeat_process:                                               ;$65EE
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ;define the size of the mob
        ;TODO: we don't need to do this every frame. we could set this up when the mob spawns
        ld      [IX+Mob.width],     16
        ld      [IX+Mob.height],    31

        ld      E,      [IX+$12]
        ld      D,      $00

        ;select frame of animation:
        ;-----------------------------------------------------------------------

@_1:    ld      HL,     @_66c5
        add     HL,     DE
        ld      [RAM_TEMP6],    HL
        ld      A,      [HL]
        and     A
        jr      nz,     @_2

        ;when we hit the end of the animation list, start over
        ld      [IX+$12],   A                               ;set the mob's counter to 0
        ld      E,      A                               ;and likewise with the working copy
        jp      @_1                                             ;proceed with next frame of animation

        ;-----------------------------------------------------------------------

@_2:    dec     A
        jr      nz,     @_3

        ld      C,      $00
        ld      H,      C
        ld      L,      $28
        jp      @_6

        ;-----------------------------------------------------------------------

@_3:    dec     A
        jr      nz,     @_4

        ld      C,      $FF
        ld      HL,     $FFD8
        jp      @_6

        ;-----------------------------------------------------------------------

@_4:    dec     A
        jr      nz,     @_5

        ld      C,      $00
        ld      L,      C
        ld      H,      C
        jp      @_6

        ;-----------------------------------------------------------------------

@_5:    ld      A,                   [IX+Mob.unknown11]
        cp      $20
        jp      nz,     @_7

        ld      HL,     $FFFF
        ld      [RAM_TEMP4],    HL
        ld      HL,     $FFFC
        ld      [RAM_TEMP6],    HL

        call    findEmptyMob
        jp      c,      @_7

        ld      DE,     $0000
        ld      C,      E
        ld      B,      D
        call    _ac96

        ld      HL,     $0001
        ld      [RAM_TEMP4],    HL
        ld      HL,     $FFFC
        ld      [RAM_TEMP6],    HL

        call    findEmptyMob
        jr      c,      @_7

        ld      DE,     $000E
        ld      BC,     $0000
        call    _ac96

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_0A
                rst     $28     ;=rst_playSFX
        .ENDIF

        jp      @_7

        ;-----------------------------------------------------------------------

        ;update the mob's speed and direction
@_6:    ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    C

@_7:    ld      L,                   [IX+Mob.unknown11]
        ld      H,      [IX+$12]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.unknown11], L
        ld      [IX+$12],   H
        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0020
        add     HL,     DE
        adc     A,      D
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ld      HL,     [RAM_TEMP6]
        ld      A,      [HL]
        add     A,      A
        ld      E,      A
        ld      HL,     @_66e0
        add     HL,     DE
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        ld      DE,     @layout
        call    animateMob

        ld      HL,     $0A04
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic

        ld      HL,     $0804
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ret

        ;-----------------------------------------------------------------------

        ;what action to take on each frame:

@_66c5: .BYTE   $01 $01 $01 $01 $01 $01 $01 $01 $01 $01
        .BYTE   $03 $03
        .BYTE   $04
        .BYTE   $02 $02 $02 $02 $02 $02 $02 $02 $02 $02
        .BYTE   $03 $03
        .BYTE   $04
        .BYTE   $00

@_66e0: 
        .ADDR   @_66ea @_66ea @_66ea @_66f3 @_66f6

@_66ea: .BYTE   $00 $0C $01 $0C $02 $0C $01 $0C $FF
@_66f3: .BYTE   $01 $01 $FF
@_66f6: .BYTE   $03 $01 $FF

        ;sprite layouts                                                                                         `$66F9
@layout:.BYTE   $00 $02 $04 $FF $FF $FF
        .BYTE   $20 $22 $24 $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $00 $02 $44 $FF $FF $FF
        .BYTE   $46 $22 $4A $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $40 $02 $44 $FF $FF $FF
        .BYTE   $26 $22 $2A $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $40 $02 $04 $FF $FF $FF
        .BYTE   $46 $22 $4A $FF $FF $FF
        .BYTE   $FF
        ;

platform_swinging_process:                                              ;$673C
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor

        ld      HL,     $0020
        ld      [RAM_SCROLLZONE_OVERRIDE_LEFT],         HL
        ld      HL,     $0048
        ld      [RAM_SCROLLZONE_OVERRIDE_RIGHT],        HL
        ld      HL,     $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_TOP],          HL
        ld      HL,     $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_BOTTOM],       HL

        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [IX+Mob.unknown12], L
        ld      [IX+Mob.unknown13], H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [IX+Mob.unknown14], L
        ld      [IX+Mob.unknown15], H
        ld      [IX+Mob.unknown11], $E0
        set     0,      [IX+Mob.flags]
        set     1,      [IX+Mob.flags]
@_1:    ld      [IX+Mob.width],         26
        ld      [IX+Mob.height],        16
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      HL,     @_682f
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        add     HL,     DE
        ld      C,      L
        ld      B,      H
        ld      A,      [BC]
        and     A
        jp      p,      @_2

        dec     D
@_2:    ld      E,      A
        ld      L,      [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      DE,     [RAM_TEMP1]
        and     A
        sbc     HL,     DE
        ld      [RAM_TEMP1],    HL
        inc     BC
        ld      D,      $00
        ld      A,      [BC]
        and     A
        jp      p,      @_3

        dec     D
@_3:    ld      E,      A
        ld      L,      [IX+Mob.unknown14]
        ld      H,      [IX+Mob.unknown15]
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_4

        ld      HL,     $0806
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_4

        ld      HL,     [RAM_SONIC.X]
        ld      DE,     [RAM_TEMP1]
        add     HL,     DE
        ld      [RAM_SONIC.X],  HL
        ld      BC,     $0010
        ld      DE,     $0000
        call    _LABEL_7CC1_12
@_4:    ld      HL,     spriteLayouts@_6911
        ld      A,      [RAM_LEVEL_SOLIDITY]
        and     A
        jr      z,      @_5

        ld      HL,     spriteLayouts@_6923
@_5:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        bit     1,      [IX+Mob.flags]
        jr      nz,     @_6

        ld      A,      [IX+Mob.unknown11]
        inc     A
        inc     A
        ld      [IX+Mob.unknown11], A
        cp      $E0
        ret     c

        set     1,      [IX+Mob.flags]
        ret

@_6:    ld      A,       [IX+Mob.unknown11]
        dec     A
        dec     A
        ld      [IX+Mob.unknown11], A
        ret     nz
        res     1,      [IX+Mob.flags]
        ret

@_682f: ;this is swinging position data
        .TABLE  BYT BYT
        .ROW    $B3 $00
        .ROW    $B3 $01
        .ROW    $B3 $02
        .ROW    $B3 $02
        .ROW    $B3 $03
        .ROW    $B3 $04
        .ROW    $B3 $05
        .ROW    $B3 $06
        .ROW    $B4 $07
        .ROW    $B4 $08
        .ROW    $B4 $09
        .ROW    $B4 $0B
        .ROW    $B4 $0C
        .ROW    $B4 $0D
        .ROW    $B5 $0E
        .ROW    $B5 $0F
        .ROW    $B5 $11
        .ROW    $B5 $12
        .ROW    $B6 $13
        .ROW    $B6 $15
        .ROW    $B7 $16
        .ROW    $B7 $18
        .ROW    $B8 $19
        .ROW    $B8 $1B
        .ROW    $B9 $1D
        .ROW    $B9 $1E
        .ROW    $BA $20
        .ROW    $BB $22
        .ROW    $BC $23
        .ROW    $BD $25
        .ROW    $BE $27
        .ROW    $BF $29
        .ROW    $C0 $2B
        .ROW    $C2 $2D
        .ROW    $C3 $2F
        .ROW    $C4 $31
        .ROW    $C6 $32
        .ROW    $C8 $34
        .ROW    $CA $36
        .ROW    $CC $38
        .ROW    $CE $3A
        .ROW    $D0 $3C
        .ROW    $D2 $3E
        .ROW    $D4 $3F
        .ROW    $D7 $41
        .ROW    $DA $43
        .ROW    $DC $44
        .ROW    $DF $45
        .ROW    $E2 $47
        .ROW    $E5 $48
        .ROW    $E8 $49
        .ROW    $EC $4A
        .ROW    $EF $4B
        .ROW    $F2 $4C
        .ROW    $F6 $4C
        .ROW    $F9 $4C
        .ROW    $FC $4D
        .ROW    $00 $4D
        .ROW    $03 $4D
        .ROW    $07 $4C
        .ROW    $0A $4C
        .ROW    $0E $4C
        .ROW    $11 $4B
        .ROW    $14 $4A
        .ROW    $18 $49
        .ROW    $1B $48
        .ROW    $1E $47
        .ROW    $21 $45
        .ROW    $24 $44
        .ROW    $27 $42
        .ROW    $29 $41
        .ROW    $2C $3F
        .ROW    $2E $3D
        .ROW    $31 $3B
        .ROW    $33 $3A
        .ROW    $35 $38
        .ROW    $37 $36
        .ROW    $39 $34
        .ROW    $3A $32
        .ROW    $3C $30
        .ROW    $3E $2E
        .ROW    $3F $2C
        .ROW    $40 $2A
        .ROW    $41 $28
        .ROW    $43 $26
        .ROW    $44 $24
        .ROW    $45 $23
        .ROW    $45 $21
        .ROW    $46 $1F
        .ROW    $47 $1D
        .ROW    $48 $1C
        .ROW    $48 $1A
        .ROW    $49 $18
        .ROW    $49 $17
        .ROW    $4A $15
        .ROW    $4A $14
        .ROW    $4B $12
        .ROW    $4B $11
        .ROW    $4B $0F
        .ROW    $4B $0E
        .ROW    $4C $0D
        .ROW    $4C $0C
        .ROW    $4C $0A
        .ROW    $4C $09
        .ROW    $4C $08
        .ROW    $4C $07
        .ROW    $4D $06
        .ROW    $4D $05
        .ROW    $4D $04
        .ROW    $4D $03
        .ROW    $4D $02
        .ROW    $4D $01
        .ROW    $4D $00
        ;

spriteLayouts:                                                          ;$6911
;===============================================================================

@_6911: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $18 $1A $18 $1A $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
@_6923: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $6C $6E $6E $48 $FF $FF
        .BYTE   $FF $FF

@_6931: .BYTE   $FE $FF $FF $FF
        .BYTE   $FF $FF

        .BYTE   $6C $6E $6C $6E $FF $FF
        .BYTE   $FF $FF
        ;

explosion_process:                                                      ;$693F
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ;mob does not collide with the floor

        ld      A,      [IX+Mob.unknown15]
        cp      $AA                     ;=170, lifetime of explosion?
        jr      z,      @_1

        ;-----------------------------------------------------------------------

        xor     A
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown15], $AA
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A

        bit     5,      [IY+Vars.flags0]
        jr      z,      @_1

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $12
        jr      z,      @_1

        ld      A,      [RAM_SONIC.flags]
        rlca
        jr      c,      @_1

        ld      A,      [RAM_D2E8]
        ld      DE,     [RAM_D2E6]
        inc     DE
        ld      C,      A
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_1

        cpl
        add     HL,     DE
        adc     A,      C
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A

        ;-----------------------------------------------------------------------

@_1:    xor     A                                          ;set A to 0
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A

        ld      DE,     @_69be
        ld      BC,     @_69b7
        call    animateMob

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $18
        ret     c

        ;explosion has finished, remove it from the mob list:
        ld      [IX+Mob.type],      $FF
        ret

        ;-----------------------------------------------------------------------

@_69b7: ;animation order                                                                                       `$69B7
        .BYTE   $00 $08
        .BYTE   $01 $08
        .BYTE   $02 $08
        .BYTE   $FF

@_69be: ;sprite layout                                                                                         `$69BE
        .BYTE   $74 $76 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $78 $7A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $7C $7E $FF $FF $FF $FF
        .BYTE   $FF
        ;

platform_sinking_process:                                               ;$69E9
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor

        ld      [IX+Mob.width],     26
        ld      [IX+Mob.height],    16
        ld      [IX+Mob.spriteLayout+0],    <spriteLayouts@_6911
        ld      [IX+Mob.spriteLayout+1],    >spriteLayouts@_6911

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_2

        ld      HL,     $0806
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      DE,     $0000

        ld      A,      [IX+Mob.Y+0]
        and     %00011111                                       ;MOD 32
        cp      $10
        jr      nc,     @_1

        ld      E,      $80
@_1:    ld      [IX+Mob.Yspeed+0],      E
        ld      [IX+Mob.Yspeed+1],      D
        ld      [IX+Mob.Ydirection],    $00
        ld      BC,     $0010
        call    _LABEL_7CC1_12
        ret

@_2:    ld      C,      $00
        ld      L,      C
        ld      H,      C
        ld      A,      [IX+Mob.Y+0]
        and     %00011111
        jr      z,      @_3

        ld      HL,     $ffc0
        dec     C
@_3:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
        ret
        ;

platform_falling_process:                                               ;$6A47
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      A,      [IX+Mob.unknown16]
        add     A,      [IX+Mob.unknown17]
        ld      [IX+Mob.unknown17], A
        cp      $18
        jr      c,      @_1

        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0040
        add     HL,     DE
        adc     A,      D
        ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    A
@_1:    ld      [IX+Mob.width],         26
        ld      [IX+Mob.height],        16

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_2

        ld      HL,     $0806
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      [IX+Mob.unknown16], $01
        ld      BC,     $0010
        ld      E,      [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        call    _LABEL_7CC1_12
@_2:    ld      HL,     spriteLayouts@_6911
        ld      A,      [RAM_LEVEL_SOLIDITY]
        and     A
        jr      z,      @_3

        ld      HL,     spriteLayouts@_6923
@_3:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     $00c0
        add     HL,     DE
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        and     A
        sbc     HL,     DE
        ret     nc

        ld      [IX+Mob.type],      $FF                     ;remove object?
        ret
        ;

unknown_6ac1_process:                                                   ;$6AC1
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     2
        ld      [IX+Mob.height],    2
        ld      HL,             $0303
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      E,      [IX+Mob.unknown13]
        ld      D,      [IX+Mob.unknown14]
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      HL,     $0000
        ld      [RAM_TEMP4],    HL
        ld      [RAM_TEMP6],    HL
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H
        ld      HL,     @_6b72
        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $05
        jr      z,      @_1

        cp      $0B
        jr      z,      @_1

        ld      HL,     @_6b70
@_1:    ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        ld      E,      A
        ld      D,      $00
        add     HL,     DE
        ld      A,      [HL]
        call    _3581
        ld      C,      [IX+Mob.X+0]
        ld      B,      [IX+Mob.X+1]
        ld      L,      C
        ld      H,      B
        ld      DE,     $FFF8
        add     HL,     DE
        ld      DE,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     DE
        jr      c,      @_2

        inc     D
        ex      DE,     HL
        sbc     HL,     BC
        jr      c,      @_2

        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        ld      L,      C
        ld      H,      B
        ld      DE,     $0010
        add     HL,     DE
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        jr      c,      @_2

        ld      HL,     $00c0
        add     HL,     DE
        and     A
        sbc     HL,     BC
        ret     nc

@_2:    ld      [IX+Mob.type],  $FF                     ;remove object?
        ret

@_6b70: .BYTE   $06 $08
@_6b72: .BYTE   $34 $36
        ;

badnick_buzzbomber_process:                                             ;$6B74
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor

        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      [IX+Mob.unknown14], E
        ld      [IX+Mob.unknown15], D

        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      [IX+$12],   A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A

        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $0100
        add     HL,     BC
        sbc     HL,     DE
        ret     nc

        set     0,      [IX+Mob.flags]
@_1:    ld      [IX+Mob.width],         20
        ld      [IX+Mob.height],        32
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      c,      @_2

        ld      DE,     $0040
        sbc     HL,     DE
        jr      nc,     @_2

        ld      A,      [IX+$12]
        cp      $05
        jr      nc,     @_2

        ld      [IX+$12],   $05
@_2:    ld      E,       [IX+$12]
        ld      D,      $00

@_3:    ld      HL,     $6CD7
        add     HL,     DE
        ld      [RAM_TEMP6],    HL
        ld      A,      [HL]
        and     A
        jr      nz,     @_4

        ld      [IX+$12],   A
        ld      E,      A
        jp      @_3

@_4:    dec     A
        jr      nz,     @_6

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0030
        add     HL,     DE
        ld      DE,     [RAM_CAMERA_X]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_5

        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      A,      [IX+Mob.unknown14]
        ld      [IX+Mob.X+0],       A
        ld      A,      [IX+Mob.unknown15]
        ld      [IX+Mob.X+1],       A
        res     0,      [IX+Mob.flags]
        ret

@_5:    ld      C,      $FF
        ld      HL,     $FE00
        jp      @_8

@_6:    dec     A
        jr      nz,     @_7

        ld      C,      $00
        ld      L,      C
        ld      H,      C
        jp      @_8

@_7:    ld      A,       [IX+Mob.unknown11]
        cp      $20
        jp      nz,     @_9

        call    findEmptyMob
        jp      c,      @_9

        push    BC
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX

        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $0D             ;unknown object
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       E
        ld      [IX+Mob.X+1],       D
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     $0020
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown13], A
        ld      [IX+Mob.unknown14], A
        ld      [IX+Mob.unknown15], A
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $FF
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.Yspeed+0],  $80
        ld      [IX+Mob.Yspeed+1],  $01
        ld      [IX+Mob.Ydirection],        A

        pop     IX
        pop     BC

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_0A
                rst     $28     ;=rst_playSFX
        .ENDIF

        ld      C,      $00
        ld      L,      C
        ld      H,      C

@_8:    ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    C

@_9:    ld      L,       [IX+Mob.unknown11]
        ld      H,      [IX+$12]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.unknown11], L
        ld      [IX+$12],   H
        ld      HL,     [RAM_TEMP6]
        ld      A,      [HL]
        add     A,      A
        ld      E,      A
        ld      HL,     @_6ce2
        add     HL,     DE
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        ld      DE,     @_6cf9
        call    animateMob

        ld      HL,     $1000
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic

        ld      HL,     $1004
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ret

        ;no reference to this?
@_6cd7: .BYTE   $01 $01 $01 $01 $00 $02 $02 $03 $01 $01 $00

        ;animation frame order
@_6ce2: .ADDR   @_6cea @_6cea @_6cef @_6cf4

@_6cea: .BYTE   $00 $02 $01 $02 $FF
@_6cef: .BYTE   $02 $02 $03 $02 $FF
@_6cf4: .BYTE   $04 $02 $05 $02 $FF

        ;sprite layout

@_6cf9: .BYTE   $FE $0A $FF $FF $FF $FF
        .BYTE   $0C $0E $10 $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $0C $0E $2C $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $0A $FF $FF $FF $FF
        .BYTE   $12 $14 $16 $FF $FF $FF
        .BYTE   $32 $34 $FF $FF $FF $FF

        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $12 $14 $16 $FF $FF $FF
        .BYTE   $32 $34 $FF $FF $FF $FF

        .BYTE   $FE $0A $FF $FF $FF $FF
        .BYTE   $12 $14 $16 $FF $FF $FF
        .BYTE   $30 $34 $FF $FF $FF $FF

        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $12 $14 $16 $FF $FF $FF
        .BYTE   $30 $34 $FF $FF $FF $FF
        ;

platform_moving_process:                                                ;$6D65
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $07                                             ;Jungle act 2?
        jr      z,      @_1

        ld      HL,     $0020
        ld      [RAM_SCROLLZONE_OVERRIDE_LEFT],         HL
        ld      HL,     $0048
        ld      [RAM_SCROLLZONE_OVERRIDE_RIGHT],        HL
        ld      HL,     $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_TOP],          HL
        ld      HL,     $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_BOTTOM],       HL

@_1:    ld      [IX+Mob.width],         26
        ld      [IX+Mob.height],        16
        ld      C,      $00

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_2

        ld      HL,     $0806
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic

        ld      C,      $00
        jr      c,      @_2

        ld      BC,     $0010
        ld      DE,     $0000
        call    _LABEL_7CC1_12
        ld      C,      $01

        ;move right 1px
@_2:    ld      L,       [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        inc     HL
        ld      [IX+Mob.unknown12], L
        ld      [IX+Mob.unknown13], H

        ld      DE,     $00A0
        xor     A                                          ;set A to 0
        sbc     HL,     DE
        jr      c,      @_3

        ld      [IX+Mob.unknown12], A
        ld      [IX+Mob.unknown13], A
        inc     [IX+Mob.unknown14]

@_3:    ld      DE,     $0001
        bit     0,      [IX+Mob.unknown14]
        jr      z,      @_4

        ;move left 1px?
        ld      DE,     $FFFF
@_4:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      A,      C
        and     A
        jr      z,      @_5

        ld      HL,     [RAM_SONIC.X]
        add     HL,     DE
        ld      [RAM_SONIC.X],  HL

@_5:    ld      HL,     spriteLayouts@_6911
        ld      A,      [RAM_LEVEL_SOLIDITY]
        and     A
        jr      z,      @_6

        ld      HL,     spriteLayouts@_6931
        dec     A
        jr      z,      @_6

        ld      HL,     spriteLayouts@_6923
@_6:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H

        ret
        ;

badnick_motobug_process:                                                ;$6E0C
;===============================================================================
; AI for the Motobug Badnick.
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ; this mob adheres to the floor
        ; TODO: this shouldn't need to be done every frame?
        res     5,      [IX+Mob.flags]

        ; define the size of the mob
        ; TODO: we don't need to do this every frame.
        ;       we could set this up when the mob spawns
        ld      [IX+Mob.width],         10
        ld      [IX+Mob.height],        16

        ld      E,      [IX+$12]
        ld      D,      $00

@actions:
        ; a "$00" AI action tells the code to repeat the mob's pre-programmed
        ; actions, the "behaviour" table near the bottom of this page gives a
        ; list of AI actions the mob will automatically play through whilst
        ; this chunk of code is not an AI action itself, we use it to define
        ; the zero value enum used as the list-terminator

@@loop:                                 ;index = $00
        ;=======================================================================
        ; NOTE: this row MUST be index 0 as the code works on that basis
        ;
        ; in    IX              Address of the current mob being processed
        ;       DE              the high-byte of the mob's counter,
        ;                       provided in the low-byte of DE
        ; out   RAM_TEMP6       Address within animation table, for the current
        ;                       frame (this tells the mob what to do each frame)
        ;-----------------------------------------------------------------------
        ld      HL,     badnick_motobug_behaviour
        add     HL,     DE
        ld      [RAM_TEMP6],    HL
        ld      A,      [HL]
        and     A
        jr      nz,     @@moveLeft
        
        ; we've hit the end of the animation list, start over
        ld      [IX+$12],       A       ; set the mob's counter to 0
        ld      E,              A       ; and likewise with the working copy
        jp      @@loop                  ; proceed with next frame of animation


        ; this is the mob's first AI action, "move left":

@@moveLeft:                                              ;@index = $01
        ;=======================================================================
        ; out   A
        ;       C
        ;       HL
        ;-----------------------------------------------------------------------
        dec     A
        jr      nz,     @@moveRight
        
        ld      C,      $FF             ; set direction: left
        ld      HL,     $FF00           ; set speed: -256
        jp      @@apply

@@moveRight:                                             ;@index = $02
        ;=======================================================================
        ; out   C
        ;       HL
        ;-----------------------------------------------------------------------
        dec     A
        jr      nz,     @@idleLeft
        
        ld      C,      $00             ; set direction: right
        ld      HL,     $0100           ; set speed: +256
        jp      @@apply

        ; the AI code handles "idleLeft" and "idleRight" actions the same,
        ; they only differ in the animation displayed. therefore we define
        ; the "idleLeft" index but provide no code, the "idleRight" index
        ; will share the same ROM address but have a higher index

@@idleLeft:                                              ;@index = $03
@@idleRight:                                             ;@index = $04
        ;=======================================================================
        ; out   C       direction is set to $00 (default facing right)
        ;       HL      speed is set to $0000
        ;-----------------------------------------------------------------------
        ld      C,    $00
        ld      L,        C
        ld      H,        C

        ;fall through to the ".apply" action below:
        ;...

@@apply:                                                 ;@index = $05
        ;=======================================================================
        ; in    IX      Address of the current mob being processed
        ;       HL
        ;       C
        ;       RAM_TEMP6
        ;-----------------------------------------------------------------------
        ; apply the chosen direction and speed
        ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    C

        ld      L,      [IX+Mob.unknown11]
        ld      H,      [IX+$12]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.unknown11],     L
        ld      [IX+$12],               H

        ; apply gravity to the mob, it will attempt to move downward any time
        ; possible. because it adheres to the ground it won't fall through the
        ; floor
        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $02
        ld      [IX+Mob.Ydirection],        $00

        ;-----------------------------------------------------------------------

        ld      HL,     [RAM_TEMP6]
        ld      A,      [HL]
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     badnick_motobobug_actions
        add     HL,     DE
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        ld      DE,     badnick_motobug_spriteLayout
        call    animateMob

        ld      HL,     $0203
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic

        ; if hit, place the explosion in the centre (0,0 offset)
        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ret
        ;

badnick_motobug_behaviour:                                              ;$6E96
;===============================================================================

        .DSB    9, 1    ;=badnick_motobug_process@actions@moveLeft
        .DSB    4, 3    ;=badnick_motobug_process@actions@idleLeft?
        .DSB    9, 2    ;=badnick_motobug_process@actions@moveRight
        .DSB    4, 5    ;=badnick_motobug_process@actions@apply
        .DB        0    ;=badnick_motobug_process@actions@loop
        ;

badnick_motobobug_actions:                                              ;$6EB1
;===============================================================================
        ; the "actions" table pairs an AI action with an animation,
        ; for each action we create we need to push a pointer on to this table

        ; since the "loop" action is just a list-terminator,
        ; the following is a dummy entry
        .ADDR   badnick_motobug_animations@moveLeft
        ; here we map the "moveLeft" action to the "moveLeft" animation
        .ADDR   badnick_motobug_animations@moveLeft
        ; here we map the "moveRight" action to the "moveRight" animation
        .ADDR   badnick_motobug_animations@moveRight
        ; the "idleLeft" action has to be added to the actions table
        .ADDR   badnick_motobug_animations@idleLeft
        ; here we map the "idleRight" action to the "idleRight" animation
        .ADDR   badnick_motobug_animations@idleRight
        ;

badnick_motobug_animations:                                             ;$6EBB
;===============================================================================
; Maps actions to a set of animation timings.
;-------------------------------------------------------------------------------

        ; sprite layout         ;frame length
        ; ($FF terminates)      ;($FF for infinite)
@moveLeft:                                                      ;@index = $00                                  `$6EBB
        .BYTE   0               8       ;=badnick_motobug_spriteLayout@leftIdle
        .BYTE   1               8       ;=badnick_motobug_spriteLayout@leftMove
        .BYTE   $FF

@moveRight:                                                     ;@index = $01                                  `$6EC0
        .BYTE   2               8       ;=badnick_motobug_spriteLayout@rightIdle
        .BYTE   3               8       ;=badnick_motobug_spriteLayout@rightMove
        .BYTE   $FF

@idleLeft:                                                      ;@index = $02                                  `$6EC5
        .BYTE   0               $FF     ;=badnick_motobug_spriteLayout@leftIdle
        .BYTE   $FF

@idleRight:                                                     ;@index = $03                                  `$6EC8
        .BYTE   2               $FF     ;=badnick_motobug_spriteLayout@rightIdle
        .BYTE   $FF
        ;

badnick_motobug_spriteLayout:                                           ;$6ECB
;===============================================================================
; The Sprite Layouts (sprite composition of each animation frame)
; for the Motobug Badnick.
;-------------------------------------------------------------------------------
@leftIdle:                                                      ;@index = $00
        ; facing left -- frame #1
        .BYTE   $60 $62 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

@leftMove:                                                      ;@index = $01
        ; facing left -- frame #2 (when moving)
        .BYTE   $64 $66 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

@rightIdle:                                                     ;@index = $02
        ; facing right -- frame #1
        .BYTE   $68 $6A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

@rightMove:                                                     ;@index = $03
        ; facing right -- frame #2 (when moving)
        .BYTE   $6C $6E $FF $FF $FF $FF
        .BYTE   $FF
        ;

badnick_newtron_process:                                                ;$6F08
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    20
        ld      A,      [IX+Mob.unknown11]
        cp      $02
        jr      z,      @_1

        and     A
        jr      nz,     @_4

@_1:    ld      A,      [RAM_FRAMECOUNT]
        and     $01
        jr      z,      @_2

        ld      BC,     $0000
        jr      @_3

@_2:    ld      BC,     @_6fed
@_3:    inc     [IX+Mob.unknown17]
        ld      A,      [IX+Mob.unknown17]
        cp      $3C
        jp      c,      @_7

        ld      [IX+Mob.unknown17], $00
        inc     [IX+Mob.unknown11]
        jp      @_7

@_4:    cp      $01
        jp      nz,     @_6

        inc     [IX+Mob.unknown17]
        ld      A,      [IX+Mob.unknown17]
        cp      $64
        jr      nz,     @_5

        call    findEmptyMob
        jp      c,      @_5

        push    BC
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX

        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $0D                     ;unknown object
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       E
        ld      [IX+Mob.X+1],       D
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     $0006
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown13], A
        ld      [IX+Mob.unknown14], A
        ld      [IX+Mob.unknown15], A
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $FE
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A

        pop     IX
        pop     BC

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_0A
                rst     $28     ;=rst_playSFX
        .ENDIF

@_5:    ld      BC,     @_6fed
        cp      $78
        jr      c,      @_7

        ld      [IX+Mob.unknown17], $00
        inc     [IX+Mob.unknown11]
        jr      @_7

@_6:    cp      $03
        jr      nz,     @_7

        ld      BC,     $0000
        inc     [IX+Mob.unknown17]
        ld      A,      [IX+Mob.unknown17]
        and     A
        jr      nz,     @_7

        ld      [IX+Mob.unknown11], C

@_7:    ld      [IX+Mob.spriteLayout+0],        C
        ld      [IX+Mob.spriteLayout+1],        B
        ld      HL,     $0202
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ret

        ;sprite layout
@_6fed: .BYTE   $1C $1E $FF $FF $FF $FF
        .BYTE   $FE $3E $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $40                                             ;odd?

@_7000: .BYTE   $42 $FF $FF $FF $FF $FE
        .BYTE   $62 $FF $FF $FF $FF $FF
        ;

boss_greenHill_process:                                                 ;$700C
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     32
        ld      [IX+Mob.height],    28
        call    _7ca6
        bit     0,      [IX+Mob.unknown11]
        jr      nz,     @_1

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFF8
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H

        ;boss sprite set
        ld      HL,     $aeb1
        ld      DE,     $2000
        ld      A,      9
        call    decompressArt

        ld      HL,     bossPalette
        ld      A,      %00000010
        call    loadPaletteOnInterrupt

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_BOSS1
                rst     $18     ;=rst_playMusic
        .ENDIF

        xor     A
        ld      [RAM_D2EC],             A
        ld      [IX+Mob.unknown12],     A
        ld      [IX+Mob.unknown14],     $A1
        ld      [IX+Mob.unknown15],     $72

        ld      HL,     $0760
        ld      DE,     $00E8
        call    _7c8c

        set     0,      [IX+Mob.unknown11]
@_1:    ld      A,       [IX+Mob.unknown13]
        and     $3F
        ld      E,      A
        ld      D,      $00
        ld      HL,     $7261
        add     HL,     DE
        ld      A,      [HL]
        and     A
        jp      p,      @_2

        ld      C,      $FF
        jr      @_3
@_2:    ld      C,      $00
@_3:    ld      [IX+Mob.Yspeed+0],      A
        ld      [IX+Mob.Yspeed+1],      C
        ld      [IX+Mob.Ydirection],    C
@_4:    ld      E,       [IX+Mob.unknown12]
        ld      D,      $00
        ld      L,      [IX+Mob.unknown14]
        ld      H,      [IX+Mob.unknown15]
        add     HL,     DE
        ld      [RAM_TEMP6],    HL
        ld      A,      [HL]
        and     A
        jr      nz,     @_5

        inc     HL
        ld      A,      [HL]
        ld      [IX+Mob.unknown12], A
        jp      @_4

@_5:    dec     A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_724b
        add     HL,     DE
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        jp      [HL]
        ld      HL,     [RAM_LEVEL_LEFT]
        ld      DE,     $0006
        add     HL,     DE
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        ld      C,      $FF
        ld      HL,     $FF00
        jp      c,      @_9

        ld      [IX+Mob.unknown12], $00
        bit     1,      [IX+Mob.unknown11]
        jr      nz,     @_6

        ld      [IX+Mob.unknown14], $A4
        ld      [IX+Mob.unknown15], $72
        set     1,      [IX+Mob.unknown11]
        jp      @_9

@_6:    ld      [IX+Mob.unknown14],     $A7
        ld      [IX+Mob.unknown15],     $72
        res     1,      [IX+Mob.unknown11]
        jp      @_9

        ld      HL,     [RAM_LEVEL_LEFT]
        ld      DE,     $00e0
        add     HL,     DE
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        ld      C,      $00
        ld      HL,     $0100
        jp      nc,     @_9

        ld      [IX+Mob.unknown12], $00
        bit     2,      [IX+Mob.unknown11]
        jr      nz,     @_7

        ld      [IX+Mob.unknown14], $A1
        ld      [IX+Mob.unknown15], $72
        set     2,      [IX+Mob.unknown11]
        jp      @_9

@_7:    ld      [IX+Mob.unknown14],$aa
        ld      [IX+Mob.unknown15],$72
        res     2,      [IX+Mob.unknown11]
        jp      @_9

        ld      [IX+Mob.Yspeed+0],  $60
        ld      [IX+Mob.Yspeed+1],  $00
        ld      [IX+Mob.Ydirection],        $00
        ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     $0074
        add     HL,     DE
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        xor     A
        sbc     HL,     DE
        ld      C,      A
        ld      L,      C
        ld      H,      C
        jp      nc,     @_9

        ld      [IX+Mob.unknown12], $00
        ld      [IX+Mob.unknown14], $B0
        ld      [IX+Mob.unknown15], $72
        jp      @_9

        ld      C,      $00
        ld      HL,     $0400
        jp      @_9

        ld      [IX+Mob.Yspeed+0],  $60
        ld      [IX+Mob.Yspeed+1],  $00
        ld      [IX+Mob.Ydirection],        $00
        ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     $0074
        add     HL,     DE
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        xor     A
        sbc     HL,     DE
        ld      C,      A
        ld      L,      C
        ld      H,      C
        jp      nc,     @_9

        ld      [IX+Mob.unknown12], $00
        ld      [IX+Mob.unknown14], $BC
        ld      [IX+Mob.unknown15], $72
        jp      @_9

        ld      C,      $FF
        ld      HL,     $FC00
        jr      @_9

        ld      C,      $00
        ld      L,      C
        ld      H,      C
        jr      @_9

        ld      C,      $00
        ld      L,      C
        ld      H,      C
        ld      [IX+Mob.unknown14], $AD
        ld      [IX+Mob.unknown15], $72
        ld      [IX+Mob.unknown12], C
        ld      [IX+Mob.unknown13], C
        jr      @_9

        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $FF
        ld      [IX+Mob.Ydirection],        $FF
        ld      HL,     [RAM_CAMERA_Y]
        ld      DE,     $001A
        add     HL,     DE
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        xor     A
        sbc     HL,     DE
        ld      C,      A
        ld      L,      C
        ld      H,      C
        jp      c,      @_9
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     [RAM_LEVEL_LEFT]
        xor     A
        sbc     HL,     DE
        ld      C,      A
        ld      L,      C
        ld      H,      C
        jr      c,      @_8
        ld      [IX+Mob.unknown14], $A1
        ld      [IX+Mob.unknown15], $72
        ld      [IX+Mob.unknown12], A
        jr      @_9

@_8:    ld      [IX+Mob.unknown14],     $A4
        ld      [IX+Mob.unknown15],     $72
        ld      [IX+Mob.unknown12],     A
        jr      @_9

@_9:    ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    C
        ld      HL,     [RAM_TEMP6]
        ld      E,      [HL]
        ld      D,      $00
        ld      HL,     @_72c8
        add     HL,     DE
        ld      A,      [HL]
        ld      HL,     @_72f8
        and     A
        jr      z,      @_10

        ld      HL,     @_730a
@_10:   ld      E,      A
        ld      A,      [IX+Mob.flags]
        and     $FD
        or      E
        ld      [IX+Mob.flags],     A
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H
        ld      HL,             $0012
        ld      [RAM_D216],     HL
        call    _77be
        call    _79fa
        inc     [IX+Mob.unknown13]
        ld      A,      [IX+Mob.unknown13]
        and     $0F
        ret     nz

        inc     [IX+Mob.unknown12]
        ret

@_724b: .BYTE   $AC $70 $EC $70 $2C $71 $5D $71 $65 $71 $96 $71 $9D $71 $A3 $71
        .BYTE   $B7 $71 $00 $00 $9D $71 $00 $14 $28 $28 $3C $3C $3C $50 $50 $50
        .BYTE   $50 $64 $64 $64 $64 $64 $64 $64 $64 $64 $64 $50 $50 $50 $50 $3C
        .BYTE   $3C $3C $28 $28 $14 $00 $00 $EC $D8 $D8 $C4 $C4 $C4 $B0 $B0 $B0
        .BYTE   $B0 $9C $9C $9C $9C $9C $9C $9C $9C $9C $9C $B0 $B0 $B0 $B0 $C4
        .BYTE   $C4 $C4 $D8 $D8 $EC $00 $01 $00 $00 $02 $00 $00 $03 $00 $00 $05
        .BYTE   $00 $00 $09 $00 $00 $07 $07 $07 $07 $04 $04 $04 $04 $04 $08 $00
        .BYTE   $00 $0B $0B $0B $0B $06 $06 $06 $06 $06 $08 $00 $00
@_72c8: .BYTE   $00 $00 $02 $02 $02 $00 $00 $02 $02 $00 $02 $00 $00 $00 $01 $04
        .BYTE   $01 $00 $01 $04 $01 $01 $01 $04 $01 $01 $01 $04 $01 $FF $02 $02
        .BYTE   $01 $05 $01 $02 $01 $05 $01 $03 $01 $05 $01 $03 $01 $05 $01 $FF

        ; sprite layout
@_72f8: .BYTE   $20 $22 $24 $26 $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF
@_730a: .BYTE   $2A $2C $2E $30 $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $6C $6E $70 $72 $FF
        ;

bossPalette:                                                            ;$731C
;===============================================================================
        .TABLE  DSB 16
        .ROW    $38 $20 $35 $1B $16 $2A $00 $3F $15 $3A $0F $03 $01 $02 $3E $00
        ;

boss_capsule_process:                                                   ;$732C
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0010
        add     HL,     DE
        ld      [IX+Mob.Y+0],   L
        ld      [IX+Mob.Y+1],   H
        set     0,      [IX+Mob.flags]
@_1:    ld      [IX+Mob.width],         28
        ld      [IX+Mob.height],        64
        ld      HL,     @_7564
        bit     1,      [IX+Mob.flags]
        jr      z,      @_2

        ld      HL,     @_757c
@_2:    ld      A,      [RAM_FRAMECOUNT]
        rrca
        jr      nc,     @_3

        ld      DE,     $000C
        add     HL,     DE
@_3:    ld      C,       [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     BC
        ld      [RAM_D2AB],     HL
        ex      DE,     HL
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL
        ld      [RAM_D2AF],     HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     BC
        ld      [RAM_D2AD],     HL
        ld      HL,     @_752e
        ld      A,      [RAM_FRAMECOUNT]
        and     $10
        jr      z,      @_4

        ld      HL,     @_7552
@_4:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        ld      HL,     [RAM_CAMERA_X]
        ld      [RAM_LEVEL_LEFT],       HL

        ;something to do with scrolling
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FF90
        add     HL,     DE
        ld      [RAM_LEVEL_RIGHT],      HL

        ld      HL,             $0002
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jp      c,      @_8

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_8

        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        ld      HL,     [RAM_SONIC.Y]
        and     A
        sbc     HL,     DE
        jr      c,      @_6

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0010
        add     HL,     DE
        ld      DE,     $FFEA
        ld      BC,     [RAM_SONIC.X]
        and     A
        sbc     HL,     BC
        jr      nc,     @_5

        ld      DE,     $001d
@_5:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [RAM_SONIC.X],  HL
        jp      @_7

@_6:    ld      HL,     [RAM_SONIC.X]
        ld      BC,     $000C
        add     HL,     BC
        ld      C,      L
        ld      B,      H
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        ret     c

        ex      DE,     HL
        ld      DE,     $0020
        add     HL,     DE
        and     A
        sbc     HL,     BC
        ret     c

        ld      A,      C
        and     %00011111
        ld      C,      A
        ld      B,      $00
        ld      HL,     @_750e
        add     HL,     BC
        ld      C,      [HL]
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFE0
        add     HL,     DE
        add     HL,     BC
        ld      [RAM_SONIC.Y],  HL
        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        ld      HL,     RAM_SONIC.flags
        set     7,      [HL]
        ld      A,      C
        cp      $03
        ret     nz

        ld      [IX+Mob.spriteLayout+0],    <@_7540
        ld      [IX+Mob.spriteLayout+1],    >@_7540
        bit     1,      [IY+Vars.flags6]
        jr      nz,     @_9

        set     1,      [IY+Vars.flags6]

        ;Stop Sonic's movement (reset speed and direction)
@_7:    xor     A
        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A

@_8:    bit     1,      [IY+Vars.flags6]
        ret     z

@_9:    ld      A,       [IX+Mob.unknown12]
        cp      $08
        jr      nc,     @_10

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $14
        ret     c

        ld      [IX+Mob.unknown11],$00
        call    _7a3a
        inc     [IX+Mob.unknown12]
        ret

@_10:   bit     1,      [IX+Mob.flags]
        jr      nz,     @_11

        ld      A,              $A0
        ld      [RAM_D289],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_ACTCOMPLETE
                rst     $18     ;=rst_playMusic
        .ENDIF

        set     1,      [IX+Mob.flags]
@_11:   xor     A
        ld      [IX+Mob.spriteLayout+0],A
        ld      [IX+Mob.spriteLayout+1],A
        res     5,      [IY+Vars.flags0]
        ld      A,      [RAM_FRAMECOUNT]
        and     $0F
        ret     nz

        call    _0625
        and     %00000001
        add     A,      $23
        call    @_74b6
        inc     [IX+Mob.unknown16]
        ld      A,      [IX+Mob.unknown16]
        cp      $0C
        ret     c

        ld      [IX+Mob.type],      $FF                     ;remove object?
        ret

        ;-----------------------------------------------------------------------

@_74b6: ld      [RAM_D216],     A                                       ;$74B6
        call    findEmptyMob
        ret     c

        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX
        ld      A,      [RAM_D216]
        ld      [IX+Mob.type],      A

        xor     A                                          ;set A to 0
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        ld      [IX+Mob.Xsubpixel], A
        ld      HL,     $0008
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     $001A
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        call    _0625
        ld      [IX+Mob.Yspeed+0],  A
        call    _0625
        and     %00000001
        inc     A
        inc     A
        neg
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        $FF
        pop     IX
        ret

@_750e: .BYTE   $15 $12 $11 $10 $10 $0F $0E $0D $03 $03 $03 $03 $03 $03 $03 $03
        .BYTE   $03 $03 $03 $03 $03 $03 $03 $03 $0D $0E $0F $10 $10 $11 $12 $15

        ;sprite layout
@_752e: .BYTE   $00 $02 $04 $06 $FF $FF
        .BYTE   $20 $22 $24 $26 $FF $FF
        .BYTE   $40 $42 $44 $46 $FF $FF
@_7540: .BYTE   $00 $08 $0A $06 $FF $FF
        .BYTE   $20 $22 $24 $26 $FF $FF
        .BYTE   $40 $42 $44 $46 $FF $FF
@_7552: .BYTE   $00 $68 $6A $06 $FF $FF
        .BYTE   $20 $22 $24 $26 $FF $FF
        .BYTE   $40 $42 $44 $46 $FF $FF

@_7564: .BYTE   $00 $00 $30 $00 $60 $19 $62 $19 $61 $19 $63 $19 $10 $00 $30 $00
        .BYTE   $64 $19 $66 $19 $65 $19 $67 $19
@_757c: .BYTE   $00 $00 $20 $00 $00 $00 $00 $00 $49 $19 $4B $19 $10 $00 $20 $00
        .BYTE   $00 $00 $00 $00 $4D $19 $4F $19
        ;

boss_freeBird_process:                                                  ;$7594
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        res     5,      [IX+Mob.flags]      ;mob adheres to the floor
        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    16
        bit     7,      [IX+Mob.flags]
        jr      z,      @_1

        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $FD
        ld      [IX+Mob.Ydirection],        $FF
@_1:    ld      DE,     $0012
        ld      A,      [RAM_LEVEL_SOLIDITY]
        cp      $03
        jr      nz,     @_2

        ld      DE,     $0038
@_2:    ld      L,                   [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        add     HL,     DE
        adc     A,      $00
        ld      C,      A
        jp      m,      @_3

        ld      A,      H
        cp      $02
        jr      c,      @_3

        ld      HL,     $0200
        ld      C,      $00
@_3:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
        ld      HL,     $FE00
        ld      A,      [RAM_LEVEL_SOLIDITY]
        cp      $03
        jr      nz,     @_4

        ld      HL,     $FE80
@_4:    ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    $FF
        ld      BC,     @_7629
        ld      A,      [RAM_LEVEL_SOLIDITY]
        and     A
        jr      z,      @_5

        ld      BC,     @_762e
        cp      $03
        jr      nz,     @_5

        ld      BC,     @_7633
@_5:    ld      DE,     @_7638
        call    animateMob

@_7612: ld      L,                   [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0010
        add     HL,     DE
        ld      DE,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     DE
        ret     nc

        ld      [IX+Mob.type],      $FF                             ;remove object?
        ret

@_7629: .BYTE   $00 $02 $01 $02 $FF
@_762e: .BYTE   $02 $04 $03 $04 $FF
@_7633: .BYTE   $04 $03 $05 $03 $FF

        ;sprite layout
@_7638: .BYTE   $10 $12 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $6E $0E $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $28 $2A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $2C $2E $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $30 $32 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $50 $52 $FF $FF $FF $FF
        .BYTE   $FF
        ;

boss_freeRabbit_process:                                                ;$7699
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        res     5,      [IX+Mob.flags]              ;mob adheres to the floor

        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    32

        ld      HL,     @_7760
        ld      A,      [RAM_LEVEL_SOLIDITY]
        and     A
        jr      z,      @_1

        ld      HL,     @_777b
        dec     A
        jr      z,      @_1

        ld      HL,     @_7796
        dec     A
        jr      z,      @_1

        ld      HL,     @_77b1
@_1:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        bit     7,      [IX+Mob.flags]
        jr      z,      @_4

        xor     A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  $01
        ld      [IX+Mob.Ydirection],        A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A

        ld      HL,     @_7752
        ld      A,      [RAM_LEVEL_SOLIDITY]
        ld      C,      A
        and     A
        jr      z,      @_2

        ld      HL,     @_776d
        dec     A
        jr      z,      @_2

        ld      HL,     @_7788
        dec     A
        jr      z,      @_2

        ld      HL,     @_77a3
@_2:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $08
        ret     c

        ld      HL,     $FFFC
        ld      A,      C
        and     A
        jr      z,      @_3

        ld      HL,     $FFFE
@_3:    ld      [IX+Mob.Yspeed+0],      $00
        ld      [IX+Mob.Yspeed+1],  L
        ld      [IX+Mob.Ydirection],        H
@_4:    ld      L,       [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0028
        add     HL,     DE
        adc     A,      $00
        ld      C,      A
        jp      m,      @_5

        ld      A,      H
        cp      $02
        jr      c,      @_5

        ld      HL,     $0200
        ld      C,      $00
@_5:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        C
        ld      [IX+Mob.Xspeed+0],  $80
        ld      [IX+Mob.Xspeed+1],  $FE
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.unknown11], $00
        jp      boss_freeBird_process@_7612

        ;sprite layout
@_7752: .BYTE   $70 $72 $FF $FF $FF $FF
        .BYTE   $54 $56 $FF $FF $FF $FF
        .BYTE   $FF $FF

@_7760: .BYTE   $5C $5E $FF $FF $FF $FF
        .BYTE   $58 $5A $FF $FF $FF $FF
        .BYTE   $FF

@_776d: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $34 $36 $FF $FF $FF $FF
        .BYTE   $FF $FF

@_777b: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $38 $3A $FF $FF $FF $FF
        .BYTE   $FF

@_7788: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $3C $3E $FF $FF $FF $FF
        .BYTE   $FF $FF

@_7796: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $1C $1E $FF $FF $FF $FF
        .BYTE   $FF

@_77a3: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $14 $16 $FF $FF $FF $FF
        .BYTE   $FF $FF

@_77b1: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $18 $1A $FF $FF $FF $FF
        .BYTE   $FF
        ;

_77be:                                                                  ;$77BE
;===============================================================================
; called by the boss mob code -- probably the exploded egg ship
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      A,      [RAM_D2EC]
        cp      $08
        jr      nc,     @_4
        ld      A,      [RAM_D2B1]
        and     A
        jp      nz,     @_2
        ld      HL,     $0c08
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        ret     c

        bit     0,      [IY+Vars.scrollRingFlags]
        ret     nz
        ld      A,      [RAM_SONIC.flags]
        rrca
        jr      c,      @_1
        and     %00000010
        jp      z,      hitPlayer@_35fd
@_1:    ld      DE,     $0001
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Ydirection]
        cpl
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A

        ;stop Sonic's movement (reset speed and direction)
        xor     A                          ;set A to 0
        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A

        ld      A,              $18
        ld      [RAM_D2B1],     A
        ld      A,              $8F
        ld      [RAM_D2B1+1],   A
        ld      A,              $3F
        ld      [RAM_D2B3],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

        ;TODO: Wouldn't just `LD HL, D2EC` & `INC [HL]` be quicker?
        ld      A,      [RAM_D2EC]
        inc     A
        ld      [RAM_D2EC],     A

@_2:    ld      HL,     [RAM_D216]
        ld      DE,     @_7922
        add     HL,     DE
        bit     1,      [IX+Mob.flags]
        jr      z,      @_3
        ld      DE,     $0012
        add     HL,     DE
@_3:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H

        ld      HL,     RAM_D2ED
        ld      [HL],   $18
        inc     HL
        ld      [HL],   $00
        ret

        ;-----------------------------------------------------------------------

@_4:    xor     A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A

        ld      DE,     $0024
        ld      HL,     [RAM_D216]
        bit     1,      [IX+Mob.flags]
        jr      z,      @_5
        ld      DE,     $0036
@_5:    add     HL,     DE
        ld      DE,     @_7922
        add     HL,     DE
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H
        ld      HL,     RAM_D2ED+1      ; lo-addr of D2ED
        ld      A,      [HL]
        cp      $0A
        jp      nc,     @_6
        dec     HL
        dec     [HL]
        ret     nz
        ld      [HL],   $18
        inc     HL
        inc     [HL]
        call    _7a3a
        ret

@_6:    ld      A,      [RAM_D2ED+1]                              ;lo-addr of D2ED
        cp      $3A
        jr      nc,     @_7
        ld      L,      [IX+Mob.Ysubpixel]
        ld      H,      [IX+Mob.Y+0]
        ld      A,      [IX+Mob.Y+1]
        ld      DE,     $0020
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Ysubpixel], L
        ld      [IX+Mob.Y+0],       H
        ld      [IX+Mob.Y+1],       A
@_7:    ld      HL,     RAM_D2ED+1                                ;lo-addr of D2ED
        ld      A,      [HL]
        cp      $5A
        jr      nc,     @_8
        inc     [HL]
        ret

@_8:    jr      nz,     @_9
        ld      [HL],   $5B

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      [RAM_LEVEL_MUSIC]
                rst     $18     ;=rst_playMusic
        .ENDIF

        ld      A,      [IY+Vars.spriteUpdateCount]

        res     0,      [IY+Vars.flags0]
        call    waitForInterrupt

        ld      [IY+Vars.spriteUpdateCount],       A

@_9:    ld      [IX+Mob.Xspeed+0],      $00
        ld      [IX+Mob.Xspeed+1],      $03
        ld      [IX+Mob.Xdirection],    $00
        ld      [IX+Mob.Yspeed+0],      $60
        ld      [IX+Mob.Yspeed+1],      $FF
        ld      [IX+Mob.Ydirection],    $FF
        ld      [IX+Mob.spriteLayout+0],    <@_7922
        ld      [IX+Mob.spriteLayout+1],    >@_7922
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     [RAM_CAMERA_X]
        inc     D
        and     A
        sbc     HL,     DE
        ret     c

        ;unlocks the screen?
        ld      [IX+Mob.type],  $FF                     ;remove mob?
        ld      HL,     $2000                   ;8192 -- max width of a level in pixels?
        ld      [RAM_LEVEL_RIGHT],      HL
        ld      HL,     $0000
        ld      [RAM_CAMERA_X_GOTO],    HL

        set     5,      [IY+Vars.flags0]
        set     0,      [IY+Vars.flags2]
        res     1,      [IY+Vars.flags2]

        ld      A,      [RAM_CURRENT_LEVEL]
        cp      $0B
        jr      nz,     @_10

        set     1,      [IY+Vars.flags9]

@_10:   ;UNKNOWN
        ld      HL,     $DA28
        ld      DE,     $2000
        ld      A,      12
        call    decompressArt
        ret

        ;sprite layouts

@_7922: .BYTE   $2A $2C $2E $30 $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $6C $6E $70 $72 $FF

        .BYTE   $20 $10 $12 $14 $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF

        .BYTE   $2A $16 $18 $1A $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $6C $6E $70 $72 $FF

        .BYTE   $20 $3A $3C $3E $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF

        .BYTE   $2A $34 $36 $38 $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $6C $6E $70 $72 $FF

        .BYTE   $20 $10 $12 $14 $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $54 $56 $66 $68 $FF

        .BYTE   $2A $16 $18 $1A $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $5A $5C $70 $72 $FF

        .BYTE   $20 $3A $3C $3E $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $54 $56 $66 $68 $FF

        .BYTE   $2A $34 $36 $38 $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $5A $5C $70 $72 $FF

        .BYTE   $20 $06 $08 $0A $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF

        .BYTE   $20 $06 $08 $0A $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF

        .BYTE   $0E $10 $12 $14 $16 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF
        ;

_79fa:                                                                  ;$79FA
;===============================================================================
; called by green hill boss, jungle boss and final animation
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      A,      [IX+Mob.Xspeed+0]
        or      [IX+Mob.Xspeed+1]
        ret     z
        ld      A,      [RAM_FRAMECOUNT]
        bit     0,      A
        ret     nz
        and     $02
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      HL,     $FFF8
        ld      DE,     $0010
        ld      C,      $04

        bit     7,      [IX+Mob.Xdirection]
        jr      z,      @_1

        ld      HL,     $0028
        ld      C,      $00
@_1:    ld      [RAM_TEMP4],    HL
        ld      [RAM_TEMP6],    DE
        add     A,      C
        call    _3581
        ret
        ;

_7a3a:                                                                  ;$7A3A
;===============================================================================
; called by `_77be`, capsule and final animation
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        call    findEmptyMob
        ret     c

        push    HL
        call    _0625
        and     %00011111
        ld      L,      A
        ld      H,      $00
        ld      [RAM_TEMP1],    HL
        call    _0625
        and     %00011111
        ld      L,      A
        ld      H,      $00
        ld      [RAM_TEMP3],    HL
        pop     HL
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $0A                     ;explosion
        ld      [IX+Mob.Xsubpixel], A
        ld      HL,     [RAM_TEMP1]
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     [RAM_TEMP3]
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A

        pop     IX

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret
        ;

meta_trip_process:                                                      ;$7AA7
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     64
        ld      [IX+Mob.height],    64
        ld      HL,     $0000
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        ret     c

        bit     6,      [IY+Vars.flags6]
        ret     nz

        ld      A,      [RAM_SONIC.flags]
        and     $80
        ret     z

        ld      HL,     $FFFB
        xor     A
        ld      [RAM_SONIC.Yspeed+0],   A
        ld      [RAM_SONIC.Yspeed+1],   HL
        ld      HL,     $0003
        xor     A
        ld      [RAM_SONIC.Xspeed+0],   A
        ld      [RAM_SONIC.Xspeed+1],   HL
        ld      HL,     RAM_SONIC.flags
        res     1,      [HL]
        set     6,      [IY+Vars.flags6]
        ld      [IY+Vars.joypad],  $FF

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_11
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

flower_process:                                                         ;$7AED
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      [IX+Mob.unknown11], $32
        ld      [IX+Mob.unknown12], $00
        set     0,      [IX+Mob.flags]
@_1:    ld      BC,     $0000
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_D2AB],     HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      A,      [RAM_FRAMECOUNT]
        rrca
        jr      nc,     @_2

        ld      DE,     $0010
        add     HL,     DE
        inc     BC
@_2:    ld      [RAM_D2AD],     HL
        ld      A,      [IX+Mob.unknown12]
        add     A,      A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_7b85
        add     HL,     DE
        push    HL
        add     HL,     BC
        ld      A,      [HL]
        add     A,      A
        add     A,      A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_7b5d
        add     HL,     DE
        ld      [RAM_D2AF],     HL
        pop     HL
        inc     HL
        inc     HL
        ld      A,      [RAM_FRAMECOUNT]
        rrca
        ret     c

        dec     [IX+Mob.unknown11]
        ret     nz

        ld      A,      [HL]
        ld      [IX+Mob.unknown11], A
        inc     [IX+Mob.unknown12]
        ld      A,      [IX+Mob.unknown12]
        cp      $04
        ret     c

        ld      [IX+Mob.unknown12], $00
        ret

@_7b5d: .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $F0 $00 $F1 $00 $E2 $00 $F2 $00
        .BYTE   $00 $00 $00 $00 $F0 $00 $F1 $00 $E2 $00 $F2 $00 $2E $00 $2F $00
        .BYTE   $2E $00 $2F $00 $2E $00 $2F $00
@_7b85: .BYTE   $00 $01 $08 $00 $02 $03 $78 $00 $01 $04 $08 $00 $02 $03 $78 $00
        ;

meta_blink_process:                                                     ;$7B95
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        set     0,      [IY+Vars.flags9]
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        jp      z,      @_1

        ld      A,      [IX+Mob.unknown12]
        ld      C,      A
        add     A,      A
        add     A,      C
        ld      C,      A
        ld      B,      $00
        ld      HL,     @_7c17
        add     HL,     BC
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      A,      [HL]
        ld      [IX+Mob.spriteLayout+0],    E
        ld      [IX+Mob.spriteLayout+1],    D
        ld      [RAM_D302],     A
        jr      @_2

@_1:    ld      [IX+Mob.spriteLayout+0],        A
        ld      [IX+Mob.spriteLayout+1],        A
@_2:    ld      L,       [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0020
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        ld      HL,     [RAM_CAMERA_Y]
        inc     H
        xor     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      [IX+Mob.type],      $FF                     ;remove object?
        res     0,      [IY+Vars.flags9]
        ret

@_3:    ld      [IX+Mob.Xspeed+0],      A
        ld      [IX+Mob.Xspeed+1],      A
        ld      [IX+Mob.Xdirection],    A
        dec     [IX+Mob.unknown11]
        ret     nz

        ld      [IX+Mob.unknown11], $06
        inc     [IX+Mob.unknown12]
        ld      A,      [IX+Mob.unknown12]
        cp      $06
        ret     c

        ld      [IX+Mob.unknown12], $00
        ret

@_7c17: .TABLE  WORD    BYTE                                            ;$7C17
        .ROW    @_7c29  $1C
        .ROW    @_7c31  $1C
        .ROW    @_7c39  $1C
        .ROW    @_7c29  $1D
        .ROW    @_7c31  $1D
        .ROW    @_7c39  $1D

        ; sprite layout
@_7c29: .BYTE   $B4 $B6 $FF $FF $FF $FF
        .BYTE   $FF $FF
@_7c31: .BYTE   $B8 $BA $FF $FF $FF $FF
        .BYTE   $FF $FF
@_7c39: .BYTE   $BC $BE $FF $FF $FF $FF
        .BYTE   $FF $FF
        ;

animateMob:                                                             ;$7C41
;===============================================================================
; in    IX      Address of the current mob being processed
;       DE      e.g. $7DE1
;       BC      e.g. $7DDC
;-------------------------------------------------------------------------------
        ld      L,      [IX+Mob.unknown17]

@_1:    ld      H,      $00
        add     HL,     BC
        ld      A,      [HL]
        cp      $FF
        jr      nz,     @_2
        ld      L,      $00
        ld      [IX+Mob.unknown17], L
        jp      @_1

@_2:    inc     HL
        push    HL
        ld      L,      A
        ld      H,      $00
        add     HL,     HL
        ld      C,      L
        ld      B,      H
        add     HL,     HL
        add     HL,     HL
        add     HL,     HL
        add     HL,     BC
        add     HL,     DE
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H
        pop     HL
        inc     [IX+Mob.unknown16]
        ld      A,      [HL]
        cp      [IX+Mob.unknown16]
        ret     nc

        ld      [IX+Mob.unknown16], $00
        inc     [IX+Mob.unknown17]
        inc     [IX+Mob.unknown17]
        ret
        ;

findEmptyMob:                                                           ;$7C7B
;===============================================================================
; Search through the mob storage and find the first empty mob slot available
; (this is used when spawning new mobs, such as bullets).
;
; out   AF      carry is set if no mob was found
;       B       mob slot index number (0-31)
;       HL      address of the empty mob slot selected
;-------------------------------------------------------------------------------
        ld      HL,     RAM_MOBS
        ld      DE,     _sizeof_Mob
        ld      B,      31                                      ;number of mob slots, less Sonic?

@loop:  ld      A,      [HL]
        cp      $FF                                             ;"No Mob" number
        ret     z                                               ;if = $FF then exit, empty slot found
        add     HL,     DE
        djnz    @loop

        ;no free mob place found!
        scf                                                     ;set the carry as a return flag
        ret
        ;

_7c8c:                                                                  ;$7C8C
;===============================================================================
; used by bosses to lock the screen?
;
; in    HL
;       DE
;-------------------------------------------------------------------------------
        ld      [RAM_CAMERA_X_GOTO],    HL
        ld      [RAM_CAMERA_Y_GOTO],    DE

        ld      HL,     [RAM_CAMERA_X]
        ld      [RAM_LEVEL_LEFT],       HL
        ld      [RAM_LEVEL_RIGHT],      HL

        ld      HL,     [RAM_CAMERA_Y]
        ld      [RAM_LEVEL_TOP],        HL
        ld      [RAM_LEVEL_BOTTOM],     HL
        ret
        ;

_7ca6:                                                                  ;$7CA6
;===============================================================================
        ld      HL,     [RAM_CAMERA_X_GOTO]
        ld      DE,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     DE
        ret     nz

        ld      HL,     [RAM_CAMERA_Y_GOTO]
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        ret     nz

        res     5,      [IY+Vars.flags0]
        ret
        ;

_LABEL_7CC1_12:                                                         ;$7CC1
;===============================================================================
; in    IX      Address of the current mob being processed
;       D       bit 7 sets A to $FF instead of 0 -- direction?
;-------------------------------------------------------------------------------
        bit     6,      [IY+Vars.flags6]
        ret     nz

        ld      L,      [IX+Mob.Ysubpixel]
        ld      H,      [IX+Mob.Y+0]

        xor     A                                          ;set A to 0

        bit     7,      D
        jr      z,      @_1

        dec     A
@_1:    add     HL,     DE
        adc     A,      [IX+Mob.Y+1]
        ld      L,      H
        ld      H,      A
        add     HL,     BC
        ld      A,      [RAM_SONIC.height]
        ld      C,      A
        xor     A
        ld      B,      A
        sbc     HL,     BC
        ld      [RAM_SONIC.Y],  HL
        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A

        ld      HL,     RAM_SONIC.flags
        set     7,      [HL]

        ret
        ;

badnick_chopper_process:                                                ;$7CF6
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ;mob does not collide with the floor
        set     5,      [IX+Mob.flags]

        ;define the size of the mob
        ;TODO: we don't need to do this every frame. we could set this up when the mob spawns
        ld      [IX+Mob.width],     8
        ld      [IX+Mob.height],    12

        ld      A,      [IX+Mob.unknown14]
        and     A
        jr      z,      @_1

        dec     [IX+Mob.unknown14]

        ;remove mob from screen (no sprite layout)
        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ret

        ;-----------------------------------------------------------------------

@_1:    bit     0,      [IX+Mob.flags]
        jr      nz,     @_3

        bit     1,      [IX+Mob.flags]
        jr      nz,     @_2

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFF4
        add     HL,     DE
        ld      [IX+$12],   L
        ld      [IX+Mob.unknown13], H
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        set     1,      [IX+Mob.flags]

@_2:    ld      [IX+Mob.Yspeed+0],      $00
        ld      [IX+Mob.Yspeed+1],      $FC
        ld      [IX+Mob.Ydirection],    $FF
        set     0,      [IX+Mob.flags]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_12
                rst     $28     ;=rst_playSFX
        .ENDIF

        ld      [IX+Mob.unknown11], $03
        jr      @_5

@_3:    ld      L,       [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0010
        add     HL,     DE
        adc     A,      $00
        ex      DE,     HL
        and     A
        jp      m,      @_4

        ld      HL,     $0400
        and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      DE,     $0400
@_4:    ld      [IX+Mob.Yspeed+0],      E
        ld      [IX+Mob.Yspeed+1],      D
        ld      [IX+Mob.Ydirection],    A
        ld      E,      [IX+$12]
        ld      D,      [IX+Mob.unknown13]
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        xor     A
        sbc     HL,     DE
        jr      c,      @_5

        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       E
        ld      [IX+Mob.Y+1],       D
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        ld      [IX+Mob.unknown14], $1E
        res     0,      [IX+Mob.flags]
@_5:    ld      DE,     @_7de1
        ld      BC,     @_7ddc
        call    animateMob
        ld      A,      [IX+Mob.unknown11]
        and     A
        jr      z,      @_6

        dec     [IX+Mob.unknown11]
        ld      [IX+Mob.spriteLayout+0],    (<@_7df7)
        ld      [IX+Mob.spriteLayout+1],    (>@_7df7)

@_6:    ld      HL,     $0204
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic

        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ret

@_7ddc: .BYTE   $00 $04 $01 $04 $FF

        ;sprite layout
@_7de1: .BYTE   $60 $62 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $64 $66 $FF $FF

@_7df7: .BYTE   $FF $FF $FF $FF $68 $6A
        .BYTE   $FF $FF $FF $FF $FF
        ;

mob_platform_fallVert:                                                  ;$7E02
;===============================================================================
; log - vertical (Jungle)
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor

        ld      HL,     $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_LEFT], HL
        ld      HL,     $0058
        ld      [RAM_SCROLLZONE_OVERRIDE_RIGHT],HL

        ld      [IX+Mob.width],     $0C
        ld      [IX+Mob.height],    $10
        ld      [IX+Mob.spriteLayout+0],    <@_7e89
        ld      [IX+Mob.spriteLayout+1],    >@_7e89
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_7e3c
        ld      A,      [IX+Mob.Y+0]
        ld      [IX+Mob.unknown12], A
        ld      A,      [IX+Mob.Y+1]
        ld      [IX+Mob.unknown13], A
        ld      [IX+Mob.unknown14], $C0
        set     0,      [IX+Mob.flags]
@_7e3c: ld      [IX+Mob.Yspeed+0],      $80
        xor     A
        ld      [IX+Mob.Yspeed+1],      A
        ld      [IX+Mob.Ydirection],    A

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_1

        ld      HL,     $0806
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_1

        ld      BC,     $0010
        ld      E,      [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        call    _LABEL_7CC1_12
@_1:    ld      A,      [RAM_FRAMECOUNT]
        and     $03
        ret     nz
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      [IX+Mob.unknown14]
        ret     c

        xor     A                                          ;set A to 0
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.Ysubpixel], A
        ld      A,      [IX+Mob.unknown12]
        ld      [IX+Mob.Y+0],       A
        ld      A,      [IX+Mob.unknown13]
        ld      [IX+Mob.Y+1],       A
        ret

        ;sprite layout
@_7e89: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $18 $1A $FF $FF $FF $FF
        .BYTE   $28 $2E $FF $FF $FF $FF
        ;

mob_platform_fallHoriz:                                                 ;$7E9B
;===============================================================================
; log - horizontal (Jungle)
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]               ;mob does not collide with the floor

        ld      HL,     $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_LEFT], HL
        ld      HL,     $0058
        ld      [RAM_SCROLLZONE_OVERRIDE_RIGHT],HL

        ld      [IX+Mob.width],     $1A
        ld      [IX+Mob.height],    $10
        ld      [IX+Mob.spriteLayout+0],    <@layout
        ld      [IX+Mob.spriteLayout+1],    >@layout
        bit     0,      [IX+Mob.flags]
        jp      nz,     mob_platform_fallVert@_7e3c
        ld      A,      [IX+Mob.Y+0]
        ld      [IX+Mob.unknown12], A
        ld      A,      [IX+Mob.Y+1]
        ld      [IX+Mob.unknown13], A
        ld      [IX+Mob.unknown14], $C6
        set     0,      [IX+Mob.flags]
        jp      mob_platform_fallVert@_7e3c

        ; sprite layout
@layout:.BYTE   $FE $FF $FF $FF $FF $FF                                 ;$7ED9
        .BYTE   $6C $6E $6E $48 $FF $FF
        .BYTE   $FF
        ;

mob_platform_roll:                                                      ;$7EE6
;===============================================================================
; log - floating (Jungle)
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor
        ld      [IX+Mob.width],     $0A
        ld      [IX+Mob.height],    $10
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFE8
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        set     0,      [IX+Mob.flags]
@_1:    ld      [IX+Mob.Yspeed+0],      $40
        xor     A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        ld      A,      [IX+Mob.unknown11]
        cp      $14
        jr      c,      @_2
        ld      [IX+Mob.Yspeed+0],  $C0
        ld      [IX+Mob.Yspeed+1],  $FF
        ld      [IX+Mob.Ydirection],        $FF

@_2:    ld      A,       [RAM_SONIC.Ydirection]
        and     A
        jp      m,      mob_platform_roll_continue@_8003

        ld      HL,     $0806
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jp      c,      mob_platform_roll_continue@_8003
        ld      BC,     $0010
        ld      E,      [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        call    _LABEL_7CC1_12
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      L
        or      H
        jr      z,      @_4
        ld      BC,     $0012
        bit     7,      H
        jr      z,      @_3
        ld      BC,     $FFFE
@_3:    ld      DE,     $0000
        call    getFloorLayoutRAMAddressForMob
        ld      E,      [HL]
        ld      D,      $00
        ld      A,      [RAM_LEVEL_SOLIDITY]
        add     A,      A
        ld      C,      A
        ld      B,      D
        ld      HL,     solidityBlocks
        add     HL,     BC
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        add     HL,     DE
        ld      A,      [HL]
        and     $3F
        ld      A,      D
        ld      E,      D
        jr      nz,     @_5
@_4:    ld      A,      [RAM_SONIC.Xspeed+0]
        ld      DE,     [RAM_SONIC.Xspeed+1]
        sra     D
        rr      E
        rra
@_5:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     A,      [IX+Mob.Xsubpixel]
        adc     HL,     DE
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [RAM_SONIC.Xsubpixel],  A
        ld      DE,     $FFFC
        add     HL,     DE
        ld      [RAM_SONIC.X],  HL
        ld      DE,     [RAM_SONIC.Xspeed]
        bit     7,      D
        jr      z,      @_6
        ld      A,      E
        cpl
        ld      E,      A
        ld      A,      D
        cpl
        ld      D,      A
        inc     DE
@_6:    ld      L,       [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        add     HL,     DE
        ld      A,      H
        cp      $09
        jr      c,      @_7
        sub     $09
        ld      H,      A
@_7:    ld      [IX+Mob.unknown12],     L
        ld      [IX+Mob.unknown13],     H
        ld      E,      A
        ld      D,      $00
        ld      HL,     mob_platform_roll_continue@_8019
        add     HL,     DE
        ld      E,      [HL]
        ld      HL,     mob_platform_roll_continue@_8022
        add     HL,     DE
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H
        jr      mob_platform_roll_continue@_800b
        ;

; ROM header goes here

.BANK   2       SLOT    "SLOT2"
.ORG    $0003

mob_platform_roll_continue:                                             ;$8003
;===============================================================================
; jumped to by `doObjectCode_platform_roll`, OBJECT: log - floating (Jungle)
;
@_8003: ld      [IX+Mob.spriteLayout+0],        <@_8022
        ld      [IX+Mob.spriteLayout+1],        >@_8022
@_800b: inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $28
        ret     c

        ld      [IX+Mob.unknown11], $00
        ret

@_8019: .BYTE   $00 $00 $00 $12 $12 $12 $24 $24 $24

        ; sprite layout
@_8022: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $3A $3C $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $36 $38 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $4C $4E $FF $FF $FF $FF
        .BYTE   $FF
        ;

boss_jungle_process:                                                    ;$8053
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     32
        ld      [IX+Mob.height],    28
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $00E0
        and     A
        sbc     HL,     DE
        ret     nc

        ld      A,      [RAM_SONIC.flags]
        rlca
        ret     nc

        ;boss sprite set
        ld      HL,     $AEb1
        ld      DE,     $2000
        ld      A,      9
        call    decompressArt

        ld      HL,     bossPalette
        ld      A,      %00000010
        call    loadPaletteOnInterrupt

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_BOSS1
                rst     $18     ;=rst_playMusic
        .ENDIF

        xor     A
        ld      [RAM_D2EC],     A

        ;there's a routine at `_7c8c` for setting the scroll positions that should
         ;have been used here?
        ld      HL,     [RAM_CAMERA_X]
        ld      [RAM_LEVEL_LEFT],       HL
        ld      [RAM_LEVEL_RIGHT],      HL

        ld      HL,     [RAM_CAMERA_Y]
        ld      [RAM_LEVEL_TOP],        HL
        ld      [RAM_LEVEL_BOTTOM],     HL
        ld      HL,     $01F0
        ld      [RAM_CAMERA_X_GOTO],    HL
        ld      HL,     $0048
        ld      [RAM_CAMERA_Y_GOTO],    HL

        set     0,      [IX+Mob.flags]

@_1:    call    _7ca6
        bit     0,      [IX+Mob.unknown11]
        jr      nz,     @_2

        ld      [IX+Mob.spriteLayout+0],    <@_81f4
        ld      [IX+Mob.spriteLayout+1],    >@_81f4
        ld      [IX+Mob.Yspeed+0],  $80
        ld      [IX+Mob.Yspeed+1],  $00
        ld      [IX+Mob.Ydirection],        $00
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0058
        xor     A
        sbc     HL,     DE
        ret     c

        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        set     0,      [IX+Mob.unknown11]
@_2:    ld      A,       [IX+Mob.unknown12]
        and     A
        jp      nz,     @_4

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        bit     1,      [IX+Mob.unknown11]
        jr      nz,     @_3

        ld      [IX+Mob.spriteLayout+0],    <@_81f4
        ld      [IX+Mob.spriteLayout+1],    >@_81f4
        res     1,      [IX+Mob.flags]
        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $FF
        ld      [IX+Mob.Xdirection],        $FF
        ld      DE,     $021C
        and     A
        sbc     HL,     DE
        jp      nc,     @_8

        ld      [IX+Mob.unknown12], $67
        jp      @_8

@_3:    ld      [IX+Mob.spriteLayout+0],        <@_8206
        ld      [IX+Mob.spriteLayout+1],        >@_8206
        set     1,      [IX+Mob.flags]
        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $01
        ld      [IX+Mob.Xdirection],        $00
        ld      DE,     $02AA
        and     A
        sbc     HL,     DE
        jp      c,      @_8

        ld      [IX+Mob.unknown12], $67
        jp      @_8

@_4:    xor     A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      HL,     $0001
        dec     [IX+Mob.unknown12]
        jr      z,      @_5

        ld      A,      [IX+Mob.unknown12]
        cp      $40
        jr      nc,     @_6

        ld      HL,     $FFFF
        cp      $28
        jr      c,      @_6

        cp      $34
        jr      z,      @_7

@_5:    ld      HL,     $0000
@_6:    ld      [IX+Mob.Yspeed+0],      $00
        ld      [IX+Mob.Yspeed+1],      L
        ld      [IX+Mob.Ydirection],    H
        jr      @_8

@_7:    ld      A,       [IX+Mob.unknown11]
        xor     $02
        ld      [IX+Mob.unknown11], A
        ld      A,      [RAM_D2EC]
        cp      $08
        jr      nc,     @_8

        call    findEmptyMob
        ret     c

        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX
        ld      [IX+Mob.type],      $2B                     ;unknown object
        xor     A                                          ;set A to 0
        ld      [IX+Mob.Xsubpixel], A
        ld      HL,     $000B
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     $0030
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        call    _0625
        and     $3F
        add     A,      $64
        ld      [IX+Mob.unknown12], A
        pop     IX
@_8:    ld      HL,     $005A
        ld      [RAM_D216],     HL
        call    _77be
        call    _79fa
        ret

        ;sprite layout
@_81f4: .BYTE   $20 $22 $24 $26 $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $54 $56 $58 $68 $FF
@_8206: .BYTE   $2A $2C $2E $30 $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $5A $5C $5E $72 $FF
        ;

unknown_8218_process:                                                   ;$8218
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        res     5,      [IX+Mob.flags]                      ;mob adheres to the floor
        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    16
        ld      HL,     $0202
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      L,      [IX+Mob.Xspeed+0]
        ld      H,      [IX+Mob.Xspeed+1]
        ld      A,      [IX+Mob.Xdirection]
        ld      DE,     $0002
        ld      C,      $00
        and     A
        jp      m,      @_1

        dec     C
        ld      DE,     $FFFE
@_1:    add     HL,     DE
        adc     A,      C
        ld      [IX+Mob.Xspeed+0],  L
        ld      [IX+Mob.Xspeed+1],  H
        ld      [IX+Mob.Xdirection],        A
        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0020
        add     HL,     DE
        adc     A,      $00
        ld      C,      A
        ld      A,      H
        cp      $03
        jr      c,      @_2

        ld      HL,     $0300
        ld      C,      $00
@_2:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        add     A,      [IX+Mob.unknown11]
        ld      [IX+Mob.unknown11],     A
        ld      A,      [IX+Mob.unknown11]
        cp      [IX+Mob.unknown12]
        jr      nc,     @_3

        ld      BC,     @_82c1
        ld      DE,     @_82cd
        call    animateMob
        ret

@_3:    jr      nz,     @_4
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        ret     z

        ld      [IX+Mob.unknown16], $00

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

@_4:    xor     A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A

        ld      BC,     @_82c6
        ld      DE,     unknown_a33c_process@_a3bb
        call    animateMob

        ld      A,      [IX+Mob.unknown12]
        add     A,      $12
        cp      [IX+Mob.unknown11]
        ret     nc

        ld      [IX+Mob.type],      $FF                     ;remove object?
        ret

@_82c1: .BYTE   $00 $04 $01 $04 $FF
@_82c6: .BYTE   $01 $0C $02 $0C $03 $0C $FF

        ;sprite layout
@_82cd: .BYTE   $08 $0A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $0C $0E $FF $FF $FF $FF
        .BYTE   $FF
        ;

badnick_yadrin_process:                                                 ;$82E6
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     16
        ld      [IX+Mob.height],    15
        ld      HL,     $0408
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    32
        ld      HL,     $1006
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        ld      HL,     $0404
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0020
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ld      A,      [IX+Mob.unknown11]
        cp      $50
        jr      c,      @_1

        ld      [IX+Mob.Xspeed+0],  $40
        ld      [IX+Mob.Xspeed+1],  $00
        ld      [IX+Mob.Xdirection],        $00
        ld      DE,     @_837e
        ld      BC,     @_8379
        call    animateMob
        jp      @_2

@_1:    ld      [IX+Mob.Xspeed+0],      $C0
        ld      [IX+Mob.Xspeed+1],      $FF
        ld      [IX+Mob.Xdirection],    $FF
        ld      DE,     @_837e
        ld      BC,     @_8374
        call    animateMob
@_2:    ld      A,      [RAM_FRAMECOUNT]
        and     %00000111
        ret     nz

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $A0
        ret     c

        ld      [IX+Mob.unknown11], $00
        ret

@_8374: .BYTE   $00 $06 $01 $06 $FF
@_8379: .BYTE   $02 $06 $03 $06 $FF

        ;sprite layout
@_837e: .BYTE   $FE $00 $02 $FF $FF $FF
        .BYTE   $20 $22 $24 $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $00 $02 $FF $FF $FF
        .BYTE   $26 $28 $2A $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $40 $42 $FF $FF $FF $FF
        .BYTE   $4A $4C $4E $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $40 $42 $FF $FF $FF $FF
        .BYTE   $44 $46 $48 $FF $FF $FF
        .BYTE   $FF
        ;

platform_bridge_process:                                                ;$83C1
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     14
        ld      [IX+Mob.height],    8
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_2

        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      L, A
        ld      H, A
        ld      [RAM_TEMP1],    HL

        bit     1,      [IX+Mob.flags]
        jr      nz,     @_1

        call    _0625
        and     %00011111
        inc     A
        ld      [IX+Mob.unknown11], A
        set     1,      [IX+Mob.flags]
@_1:    dec     [IX+Mob.unknown11]
        jp      nz,     @_4

        ld      [IX+Mob.unknown11], $01
        ld      A,      [RAM_D2AB+1]
        and     $80
        jp      z,      @_4

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_D2AB],     HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $000e
        add     HL,     DE
        ld      [RAM_D2AD],     HL
        ld      HL,     @_848e
        ld      [RAM_D2AF],     HL
        set     0,      [IX+Mob.flags]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_20
                rst     $28     ;=rst_playSFX
        .ENDIF

@_2:    ld      [IX+Mob.spriteLayout+0],        <@_8481
        ld      [IX+Mob.spriteLayout+1],        >@_8481
        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0020
        add     HL,     DE
        adc     A,      $00
        ld      C,      A
        ld      A,      H
        cp      $04
        jr      c,      @_3

        ld      H,      $04
@_3:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
        ld      [RAM_TEMP1],    HL
        ld      DE,     [RAM_CAMERA_Y]
        inc     D
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        and     A
        sbc     HL,     DE
        jr      c,      @_4

        ld      [IX+Mob.type],      $FF                     ;remove object?
        ret

@_4:    ld      HL,     $0402
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        ret     c

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        ret     m

        ld      DE,     [RAM_TEMP1]
        ld      BC,     $0010
        call    _LABEL_7CC1_12
        ret

        ;sprite layout
@_8481: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $70 $72 $FF $FF $FF $FF
        .BYTE   $FF
@_848e: .BYTE   $00 $00 $00 $00 $00 $00 $00 $00
        ;

mob_boss_bridge:                                                        ;$8496
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor
        ld      [IX+Mob.width],     30
        ld      [IX+Mob.height],    28
        call    _7ca6
        ld      [IX+Mob.spriteLayout+0],    <_865a
        ld      [IX+Mob.spriteLayout+1],    >_865a
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      HL,     $03A0
        ld      DE,     $0300
        call    _7c8c

        ;UNKNOWN
        ld      HL,     $E508
        ld      DE,     $2000
        ld      A,      12
        call    decompressArt

        ld      HL,     bossPalette
        ld      A,      %00000010
        call    loadPaletteOnInterrupt
        xor     A
        ld      [RAM_D2EC],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_BOSS1
                rst     $18     ;=rst_playMusic
        .ENDIF

        set     0,      [IX+Mob.flags]
@_1:    ld      A,       [IX+Mob.unknown11]
        and     A
        jr      nz,     @_2

        call    _0625
        and     %00000001
        add     A,      A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     _8632
        add     HL,     DE
        ld      A,      [HL]
        ld      [IX+Mob.X+0],       A
        inc     HL
        ld      A,      [HL]
        inc     HL
        ld      [IX+Mob.X+1],       A
        ld      A,      [HL]
        inc     HL
        ld      [IX+Mob.Y+0],       A
        ld      A,      [HL]
        inc     HL
        ld      [IX+Mob.Y+1],       A
        inc     [IX+Mob.unknown11]
        jp      @_6

@_2:    dec     A
        jr      nz,     @_3

        ld      [IX+Mob.Yspeed+0],  $80
        ld      [IX+Mob.Yspeed+1],  $FF
        ld      [IX+Mob.Ydirection],        $FF
        ld      HL,     $0380
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        xor     A
        sbc     HL,     DE
        jp      c,      @_6

        inc     [IX+Mob.unknown11]
        ld      [IX+Mob.unknown12], A
        jp      @_6

@_3:    dec     A
        jr      nz,     @_5

        xor     A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        inc     [IX+Mob.unknown12]
        ld      A,      [IX+Mob.unknown12]
        cp      $64
        jp      nz,     @_6

        inc     [IX+Mob.unknown11]
        ld      A,      [RAM_D2EC]
        cp      $08
        jr      nc,     @_6

        ld      HL,     [RAM_SONIC.X]
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        ld      HL,     _863a
        jr      c,      @_4

        ld      HL,     _864a
@_4:    ld      E,       [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL
        push    HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     BC
        ld      [RAM_TEMP3],    HL
        pop     HL
        ld      B,      $03

@loop:  push    BC
        ld      A,      [HL]
        ld      [RAM_TEMP4],    A
        inc     HL
        ld      A,      [HL]
        ld      [RAM_TEMP5],    A
        inc     HL
        ld      A,      [HL]
        ld      [RAM_TEMP6],    A
        inc     HL
        ld      A,      [HL]
        ld      [RAM_TEMP7],    A
        inc     HL
        push    HL
        ld      C,      $10
        call    _85d1
        pop     HL
        pop     BC
        djnz    @loop

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

        jp      @_6

@_5:    ld      [IX+Mob.Yspeed+0],      $80
        ld      [IX+Mob.Yspeed+1],      $00
        ld      [IX+Mob.Ydirection],    $00
        ld      HL,     $03C0
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_6

        ld      [IX+Mob.unknown11], A

@_6:    ld      HL,             $00A2
        ld      [RAM_D216],     HL
        call    _77be
        ret
        ;

_85d1:                                                                  ;$85D1
;===============================================================================
; called by bridge & labyrinth boss
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        push    BC
        call    findEmptyMob
        pop     BC
        ret     c

        push    IX
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $0D                     ;unknown mob
        ld      HL,     [RAM_TEMP1]
        ld      [IX+Mob.Xsubpixel],     A
        ld      [IX+Mob.X+0],           L
        ld      [IX+Mob.X+1],           H
        ld      HL,     [RAM_TEMP3]
        ld      [IX+Mob.Ysubpixel],     A
        ld      [IX+Mob.Y+0],           L
        ld      [IX+Mob.Y+1],           H
        ld      [IX+Mob.unknown11],     A
        ld      [IX+Mob.unknown13],     C
        ld      [IX+Mob.unknown14],     A
        ld      [IX+Mob.unknown15],     A
        ld      [IX+Mob.unknown16],     A
        ld      [IX+Mob.unknown17],     A
        ld      HL,     [RAM_TEMP4]
        xor     A
        bit     7,      H
        jr      z,      @_1

        dec     A
@_1:    ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    A
        ld      HL,     [RAM_TEMP6]
        xor     A
        bit     7,      H
        jr      z,      @_2

        dec     A
@_2:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    A
        pop     IX
        ret
        ;

_8632:                                                                  ;$8632
;===============================================================================
        .BYTE   $D4 $03 $C0 $03 $44 $04 $C0 $03
        ;

_863a:                                                                  ;$863A
;===============================================================================
        .BYTE   $00 $00 $F6 $FF $C0 $FE $00 $FC $60 $FE $80 $FD $C0 $FD $00 $FF
        ;

_864a:                                                                  ;$864A
;===============================================================================
        .BYTE   $20 $00 $F6 $FF $40 $01 $00 $FC $A0 $01 $80 $FD $40 $02 $00 $FF
        ;

;sprite layout

_865a:                                                                  ;$865A
;===============================================================================

        .BYTE   $20 $22 $24 $26 $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF
        ;

platform_balance_process:                                               ;$866C
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      [IX+Mob.unknown11], $1C
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FFF0
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        set     0,      [IX+Mob.flags]
@_1:    ld      L,       [IX+Mob.unknown14]
        ld      H,      [IX+Mob.unknown15]
        ld      A,      [IX+Mob.unknown16]
        ld      E,      [IX+Mob.unknown12]
        ld      D,      [IX+Mob.unknown13]
        ld      C,      $00
        bit     7,      D
        jr      z,      @_2

        dec     C
@_2:    add     HL,     DE
        adc     A,      C
        ld      [IX+Mob.unknown14], L
        ld      [IX+Mob.unknown15], H
        ld      [IX+Mob.unknown16], A
        ld      C,      H
        ld      B,      A
        ld      HL,     $0038
        add     HL,     DE
        ld      [IX+Mob.unknown12], L
        ld      [IX+Mob.unknown13], H
        bit     7,      H
        jr      nz,     @_7

        rlca
        jr      c,      @_7

        ld      A,      [IX+Mob.unknown11]
        and     A
        jr      z,      @_6

        bit     1,      [IX+Mob.flags]
        jr      z,      @_4

        ld      A,      L
        or      H
        jr      nz,     @_3
        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        jr      @_4

@_3:    ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      DE,     [RAM_D2E6]
        add     HL,     DE
        ld      [RAM_SONIC.Yspeed],     HL

        ld      A,      $FF
        ld      [RAM_SONIC.Ydirection], A                       ;set Sonic as currently jumping

@_4:    ld      A,      $1C
        sub     C
        ld      [IX+Mob.unknown11], A
        jr      z,      @_5
        jr      nc,     @_7

@_5:    bit     1,      [IX+Mob.flags]
        jr      z,      @_6

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_04
                rst     $28     ;=rst_playSFX
        .ENDIF

@_6:    xor     A
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown12], A
        ld      [IX+Mob.unknown13], A
        ld      [IX+Mob.unknown14], A
        ld      [IX+Mob.unknown15], $1C
        ld      [IX+Mob.unknown16], A
@_7:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      HL,     $0000
        ld      [RAM_TEMP4],    HL
        ld      L,      [IX+Mob.unknown11]
        ld      DE,     $0010
        add     HL,     DE
        ld      [RAM_TEMP6],    HL
        ld      HL,     @_8830
        call    @_881a
        ld      HL,     $0028
        ld      [RAM_TEMP4],    HL
        ld      A,      $1C
        sub     [IX+Mob.unknown11]
        ld      L,      A
        ld      H,      $00
        ld      DE,     $0010
        add     HL,     DE
        ld      [RAM_TEMP6],    HL
        ld      HL,     @_8830
        call    @_881a
        ld      HL,     $002c
        ld      [RAM_TEMP4],    HL
        ld      L,      [IX+Mob.unknown15]
        ld      H,      [IX+Mob.unknown16]
        ld      [RAM_TEMP6],    HL
        ld      HL,     @_8834
        call    @_881a
        res     1,      [IX+Mob.flags]
        ld      [IX+Mob.width],     $14
        ld      A,      $02
        ld      [RAM_TEMP6],    A
        ld      A,      [IX+Mob.unknown11]
        ld      C,      A
        add     A,      $08
        ld      [IX+Mob.height],    A
        ld      A,      C
        add     A,      $04
        ld      [RAM_TEMP7],    A
        call    detectCollisionWithSonic
        jr      nc,     @_8

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        ret     m

        ld      [IX+Mob.width],     $3C
        ld      A,      $2A
        ld      [RAM_TEMP6],    A
        ld      A,      $1C
        sub     [IX+Mob.unknown11]
        add     A,      $08
        ld      [IX+Mob.height],        A
        ld      A,      $1C
        sub     [IX+Mob.unknown11]
        add     A,      $04
        ld      [RAM_TEMP7],    A
        call    detectCollisionWithSonic
        jr      nc,     @_9
        ret

@_8:    set     1,      [IX+Mob.flags]

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        ret     m

        ld      A,      [IX+Mob.unknown11]
        cp      $1C
        jr      z,      @_9
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      [IX+Mob.unknown12], L
        ld      [IX+Mob.unknown13], H
        ld      A,      [RAM_SONIC.Yspeed+1]
        add     A,      [IX+Mob.unknown11]
        ld      [IX+Mob.unknown11], A
        cp      $1C
        jr      c,      @_10

        ld      [IX+Mob.unknown11], $1C
@_9:    ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
@_10:   ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     $0010
        add     HL,     BC
        ld      A,      [RAM_TEMP7]
        sub     $04
        ld      C,      A
        add     HL,     BC
        ld      A,      [RAM_SONIC.height]
        ld      C,      A
        xor     A
        sbc     HL,     BC
        ld      [RAM_SONIC.Y],  HL
        ld      HL,     RAM_SONIC.flags
        set     7,      [HL]
        ret

        ;-----------------------------------------------------------------------

@_881a: ld      A,       [HL]
        and     A
        ret     m

        push    HL
        call    _3581
        ld      HL,     [RAM_TEMP4]
        ld      DE,     $0008
        add     HL,     DE
        ld      [RAM_TEMP4],    HL
        pop     HL
        inc     HL
        jp      @_881a

        ;-----------------------------------------------------------------------

@_8830: .BYTE   $36 $38 $3A $FF
@_8834: .BYTE   $3C $3E $FF
        ;

badnick_jaws_process:                                                   ;$8837
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor
        ld      A,      [IX+Mob.unknown11]
        cp      $80
        jr      nc,     @_1

        ld      [IX+Mob.Xspeed+0],  $20
        ld      [IX+Mob.Xspeed+1],  $00
        ld      [IX+Mob.Xdirection],        $00

        ld      [IX+Mob.width],     20
        ld      [IX+Mob.height],    12

        ld      HL,     $0A02
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic

        ld      HL,     $0008
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ld      DE,     @_88be
        ld      BC,     @_88b4
        call    animateMob
        jr      @_2

@_1:    ld      [IX+Mob.Xspeed+0],      $E0
        ld      [IX+Mob.Xspeed+1],      $FF
        ld      [IX+Mob.Xdirection],    $FF

        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    12

        ld      HL,     $0202
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic

        ld      HL,     $0000
        ld      [RAM_TEMP1],    HL
        call    nc,     hitPlayer

        ld      DE,     @_88be
        ld      BC,     @_88b9
        call    animateMob

@_2:    ld      A,                   [RAM_FRAMECOUNT]
        and     $07
        ret     nz

        inc     [IX+Mob.unknown11]
        call    _0625
        and     $1E
        call    z,      _91eb

        ret

@_88b4: .BYTE   $00 $04 $01 $04 $FF
@_88b9: .BYTE   $02 $04 $03 $04 $FF

        ;sprite layout
@_88be: .BYTE   $04 $2A $2C $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $0C $2A $2C $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $0E $10 $0A $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $0E $10 $0C $FF $FF $FF
        .BYTE   $FF
        ;

trap_spikeBall_process:                                                 ;$88FB
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     8
        ld      [IX+Mob.height],    12
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.unknown12], L
        ld      [IX+Mob.unknown13], H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.unknown14], L
        ld      [IX+Mob.unknown15], H
        set     0,      [IX+Mob.flags]
@_1:    ld      L,       [IX+Mob.unknown11]
        ld      H,      $00
        add     HL,     HL
        ld      DE,     @_898e
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      C,      [HL]
        ld      D,      $00
        ld      B,      D
        bit     7,      E
        jr      z,      @_2

        dec     D
@_2:    bit     7,      C
        jr      z,      @_3

        dec     D
@_3:    ld      L,       [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      L,      [IX+Mob.unknown14]
        ld      H,      [IX+Mob.unknown15]
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      HL,     $0204
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      [IX+Mob.spriteLayout+0],    <@_8987
        ld      [IX+Mob.spriteLayout+1],    >@_8987
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $B4
        ret     c

        ld      [IX+Mob.unknown11], $00
        ret

        ;sprite layout
@_8987: .BYTE   $60 $62 $FF $FF $FF $FF
        .BYTE   $FF

        ;I imagine this a set of X/Y positions to do the spiked-ball rotation
@_898e: ;180 lines, ergo 2deg per frame?
        .BYTE   $40     $00
        .BYTE   $40     $02
        .BYTE   $40     $04
        .BYTE   $40     $07
        .BYTE   $3F     $09
        .BYTE   $3F     $0B
        .BYTE   $3F     $0D
        .BYTE   $3E     $0F
        .BYTE   $3E     $12
        .BYTE   $3D     $14
        .BYTE   $3C     $16
        .BYTE   $3B     $18
        .BYTE   $3A     $1A
        .BYTE   $3A     $1C
        .BYTE   $39     $1E
        .BYTE   $37     $20
        .BYTE   $36     $22
        .BYTE   $35     $24
        .BYTE   $34     $26
        .BYTE   $32     $27
        .BYTE   $31     $29
        .BYTE   $30     $2B
        .BYTE   $2E     $2C
        .BYTE   $2C     $2E
        .BYTE   $2B     $30
        .BYTE   $29     $31
        .BYTE   $27     $32
        .BYTE   $26     $34
        .BYTE   $24     $35
        .BYTE   $22     $36
        .BYTE   $20     $37
        .BYTE   $1E     $39
        .BYTE   $1C     $3A
        .BYTE   $1A     $3A
        .BYTE   $18     $3B
        .BYTE   $16     $3C
        .BYTE   $14     $3D
        .BYTE   $12     $3E
        .BYTE   $0F     $3E
        .BYTE   $0D     $3F
        .BYTE   $0B     $3F
        .BYTE   $09     $3F
        .BYTE   $07     $40
        .BYTE   $04     $40
        .BYTE   $02     $40
        .BYTE   $00     $40
        .BYTE   $FE     $40
        .BYTE   $FC     $40
        .BYTE   $F9     $40
        .BYTE   $F7     $3F
        .BYTE   $F5     $3F
        .BYTE   $F3     $3F
        .BYTE   $F1     $3E
        .BYTE   $EE     $3E
        .BYTE   $EC     $3D
        .BYTE   $EA     $3C
        .BYTE   $E8     $3B
        .BYTE   $E6     $3A
        .BYTE   $E4     $3A
        .BYTE   $E2     $39
        .BYTE   $E0     $37
        .BYTE   $DE     $36
        .BYTE   $DC     $35
        .BYTE   $DA     $34
        .BYTE   $D9     $32
        .BYTE   $D7     $31
        .BYTE   $D5     $30
        .BYTE   $D4     $2E
        .BYTE   $D2     $2C
        .BYTE   $D0     $2B
        .BYTE   $CF     $29
        .BYTE   $CE     $27
        .BYTE   $CC     $26
        .BYTE   $CB     $24
        .BYTE   $CA     $22
        .BYTE   $C9     $20
        .BYTE   $C7     $1E
        .BYTE   $C6     $1C
        .BYTE   $C6     $1A
        .BYTE   $C5     $18
        .BYTE   $C4     $16
        .BYTE   $C3     $14
        .BYTE   $C2     $12
        .BYTE   $C2     $0F
        .BYTE   $C1     $0D
        .BYTE   $C1     $0B
        .BYTE   $C1     $09
        .BYTE   $C0     $07
        .BYTE   $C0     $04
        .BYTE   $C0     $02
        .BYTE   $C0     $00
        .BYTE   $C0     $FE
        .BYTE   $C0     $FC
        .BYTE   $C0     $F9
        .BYTE   $C1     $F7
        .BYTE   $C1     $F5
        .BYTE   $C1     $F3
        .BYTE   $C2     $F1
        .BYTE   $C2     $EE
        .BYTE   $C3     $EC
        .BYTE   $C4     $EA
        .BYTE   $C5     $E8
        .BYTE   $C6     $E6
        .BYTE   $C6     $E4
        .BYTE   $C7     $E2
        .BYTE   $C9     $E0
        .BYTE   $CA     $DE
        .BYTE   $CB     $DC
        .BYTE   $CC     $DA
        .BYTE   $CE     $D9
        .BYTE   $CF     $D7
        .BYTE   $D0     $D5
        .BYTE   $D2     $D4
        .BYTE   $D4     $D2
        .BYTE   $D5     $D0
        .BYTE   $D7     $CF
        .BYTE   $D9     $CE
        .BYTE   $DA     $CC
        .BYTE   $DC     $CB
        .BYTE   $DE     $CA
        .BYTE   $E0     $C9
        .BYTE   $E2     $C7
        .BYTE   $E4     $C6
        .BYTE   $E6     $C6
        .BYTE   $E8     $C5
        .BYTE   $EA     $C4
        .BYTE   $EC     $C3
        .BYTE   $EE     $C2
        .BYTE   $F1     $C2
        .BYTE   $F3     $C1
        .BYTE   $F5     $C1
        .BYTE   $F7     $C1
        .BYTE   $F9     $C0
        .BYTE   $FC     $C0
        .BYTE   $FE     $C0
        .BYTE   $00     $C0
        .BYTE   $02     $C0
        .BYTE   $04     $C0
        .BYTE   $07     $C0
        .BYTE   $09     $C1
        .BYTE   $0B     $C1
        .BYTE   $0D     $C1
        .BYTE   $0F     $C2
        .BYTE   $12     $C2
        .BYTE   $14     $C3
        .BYTE   $16     $C4
        .BYTE   $18     $C5
        .BYTE   $1A     $C6
        .BYTE   $1C     $C6
        .BYTE   $1E     $C7
        .BYTE   $20     $C9
        .BYTE   $22     $CA
        .BYTE   $24     $CB
        .BYTE   $26     $CC
        .BYTE   $27     $CE
        .BYTE   $29     $CF
        .BYTE   $2B     $D0
        .BYTE   $2C     $D2
        .BYTE   $2E     $D4
        .BYTE   $30     $D5
        .BYTE   $31     $D7
        .BYTE   $32     $D9
        .BYTE   $34     $DA
        .BYTE   $35     $DC
        .BYTE   $36     $DE
        .BYTE   $37     $E0
        .BYTE   $39     $E2
        .BYTE   $3A     $E4
        .BYTE   $3A     $E6
        .BYTE   $3B     $E8
        .BYTE   $3C     $EA
        .BYTE   $3D     $EC
        .BYTE   $3E     $EE
        .BYTE   $3E     $F1
        .BYTE   $3F     $F3
        .BYTE   $3F     $F5
        .BYTE   $3F     $F7
        .BYTE   $40     $F9
        .BYTE   $40     $FC
        .BYTE   $40     $FE
        ;

trap_spear_process:                                                     ;$8AF6
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $000C
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        set     0,      [IX+Mob.flags]
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      HL,     $0000
        ld      [RAM_TEMP4],    HL
        ld      A,      [RAM_FRAMECOUNT]
        rlca
        rlca
        and     $03
        jr      nz,     @_2

        ld      HL,     @_8bbc
        ld      A,      [RAM_FRAMECOUNT]
        and     $3F
        ld      E,      A
        cp      $08
        jr      c,      @_5

        ld      HL,     @_8bcd
        ld      E,      $00
        jr      @_5

@_2:    cp      $01
        jr      nz,     @_3

        ld      HL,     @_8bcd
        ld      E,      $00
        jr      @_5

@_3:    cp      $02
        jr      nz,     @_4

        ld      HL,     @_8bc4
        ld      A,      [RAM_FRAMECOUNT]
        and     $3f
        ld      E,      A
        cp      $08
        jr      c,      @_5

        ld      HL,     @_8bcc
        ld      E,      $00
        jr      @_5

@_4:    ld      HL,     @_8bcc
        ld      E,      $00
@_5:    ld      D,      $00
        add     HL,     DE
        ld      A,      [HL]
        ld      HL,     @_8bce
        add     A,      A
        add     A,      A
        add     A,      A
        ld      E,      A
        add     HL,     DE
        ld      B,      $03

@loop:  push    BC
        ld      A,      [HL]
        inc     HL
        ld      E,      [HL]
        inc     HL
        and     A
        jp      m,      @_6
        push    HL
        ld      D,      $00
        ld      [RAM_TEMP6],    DE
        call    _3581
        pop     HL
@_6:    pop     BC
        djnz    @loop

        ld      [IX+Mob.spriteLayout+0],    B
        ld      [IX+Mob.spriteLayout+1],    B
        ld      D,      [HL]
        ld      E,      $04
        ld      [RAM_TEMP6],    DE
        inc     HL
        ld      A,      [HL]
        ld      [IX+Mob.width],     $01
        ld      [IX+Mob.height],    A
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      A,      [RAM_FRAMECOUNT]
        cp      $80
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_1D
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret

@_8bbc: .BYTE   $00 $01 $02 $03 $04 $05 $06 $07
@_8bc4: .BYTE   $07 $06 $05 $04 $03 $02 $01 $00
@_8bcc: .BYTE   $00
@_8bcd: .BYTE   $08
@_8bce: .BYTE   $12 $00 $32 $10 $32 $20 $01 $30 $12 $04 $32 $14 $32 $20 $02 $30
        .BYTE   $12 $08 $32 $18 $32 $20 $06 $30 $12 $0C $32 $1C $32 $20 $0A $30
        .BYTE   $12 $10 $32 $20 $FF $00 $0E $30 $12 $14 $32 $20 $FF $00 $12 $30
        .BYTE   $12 $18 $32 $20 $FF $00 $16 $30 $12 $1C $32 $20 $FF $00 $1A $30
        .BYTE   $12 $20 $FF $00 $FF $00 $1E $30
        ;

trap_fireball_process:                                                  ;$8C16
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        res     5,      [IX+Mob.flags]                      ;mob adheres to the floor
                                                                ;(it doesn't move, so this is odd)
        ld      [IX+Mob.width],     4
        ld      [IX+Mob.height],    10
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $000A
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.unknown12], L
        ld      [IX+Mob.unknown13], H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown14], L
        ld      [IX+Mob.unknown15], H
        ld      [IX+Mob.unknown11], $96
        set     0,      [IX+Mob.flags]
        ld      BC,     $0000
        ld      DE,     $0000
        call    getFloorLayoutRAMAddressForMob
        ld      A,      [HL]
        cp      $52
        jr      z,      @_1

        set     1,      [IX+Mob.flags]
@_1:    ld      A,       [IX+Mob.unknown11]
        and     A
        jr      z,      @_4

        dec     [IX+Mob.unknown11]
        jr      z,      @_3

@_2:    xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ret

        ;-----------------------------------------------------------------------

        ; (we can compile with, or without, sound)
@_3:    .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_18
                rst     $28     ;=rst_playSFX
        .ENDIF

@_4:    xor     A
        bit     1,      [IX+Mob.flags]
        jr      nz,     @_5

        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $FF
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.spriteLayout+0],    <@_8d39
        ld      [IX+Mob.spriteLayout+1],    >@_8d39
        jr      @_6

@_5:    ld      [IX+Mob.Xspeed+0],      A
        ld      [IX+Mob.Xspeed+1],  $01
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.spriteLayout+0],    <@_8d41
        ld      [IX+Mob.spriteLayout+1],    >@_8d41
@_6:    ld      [IX+Mob.Yspeed+0],      A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        bit     6,      [IX+Mob.flags]
        jr      nz,     @_7

        bit     7,      [IX+Mob.flags]
        jr      nz,     @_7

        ld      HL,     $0402
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $FFF0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_7

        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $0110
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_7

        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $FFF0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_7

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $00d0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_7

        ret

@_7:    ld      L,       [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      L,      [IX+Mob.unknown14]
        ld      H,      [IX+Mob.unknown15]
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], $96
        jp      @_2

        ;-----------------------------------------------------------------------
        ;sprite layout

@_8d39: .BYTE   $2E $FF $FF $FF $FF $FF
        .BYTE   $FF $FF
@_8d41: .BYTE   $30 $FF $FF $FF $FF $FF
        .BYTE   $FF
        ;

meta_water_process:                                                     ;$8D48
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      A,      [IX+Mob.unknown11]
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_8e36
        add     HL,     DE
        ld      E,      [HL]
        ld      A,      D
        bit     7,      E
        jr      z,      @_1

        dec     A
        dec     D
@_1:    ld      L,       [IX+Mob.Ysubpixel]
        ld      H,      [IX+Mob.Y+0]
        add     HL,     DE
        adc     A,      [IX+Mob.Y+1]
        ld      [IX+Mob.Ysubpixel], L
        ld      [IX+Mob.Y+0],       H
        ld      [IX+Mob.Y+1],       A
        ld      L,      H
        ld      H,      [IX+Mob.Y+1]
        ld      A,      [RAM_FRAMECOUNT]
        and     $0F
        jr      nz,     @_2

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $20
        jr      c,      @_2

        ld      [IX+Mob.unknown11], $00
@_2:    ld      [RAM_D2DC],     HL
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        ld      A,      $FF
        sbc     HL,     DE
        jr      c,      @_3

        ex      DE,     HL
        ld      HL,     $000C
        ld      A,      $FF
        sbc     HL,     DE
        jr      nc,     @_3

        ld      HL,     $00B4
        xor     A
        sbc     HL,     DE
        jr      c,      @_3

        ld      A,      E
@_3:    ld      [RAM_WATERLINE],        A
        and     A
        ret     z

        cp      $FF
        ret     z

        add     A,      $09
        ld      L,      A
        ld      H,      $00
        ld      [RAM_TEMP6],    HL
        ld      HL,     [RAM_CAMERA_X]
        ld      [RAM_TEMP1],    HL
        ld      HL,     [RAM_CAMERA_Y]
        ld      [RAM_TEMP3],    HL
        ld      A,      [IY+Vars.spriteUpdateCount]
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        push    AF
        push    HL
        ld      HL,     RAM_SPRITETABLE
        ld      [RAM_SPRITETABLE_ADDR], HL
        ld      A,      [RAM_FRAMECOUNT]
        and     $03
        add     A,      A
        add     A,      A
        ld      C,      A
        ld      B,      $00
        ld      HL,     @_8e16
        add     HL,     BC
        ld      B,      $04

@loop:  push    BC
        ld      C,      [HL]
        inc     HL
        push    HL
        ld      A,      [RAM_FRAMECOUNT]
        and     $0F
        add     A,      C
        ld      L,      A
        ld      H,      $00
        ld      [RAM_TEMP4],    HL
        ld      A,      $00
        call    _3581
        ld      HL,     [RAM_TEMP4]
        ld      DE,     $0008
        add     HL,     DE
        ld      [RAM_TEMP4],    HL
        ld      A,      $02
        call    _3581
        pop     HL
        pop     BC
        djnz    @loop

        pop     HL
        pop     AF
        ld      [RAM_SPRITETABLE_ADDR], HL
        ld      [IY+Vars.spriteUpdateCount],       A
        ret

        ;-----------------------------------------------------------------------

@_8e16: .BYTE   $00 $40 $80 $C0 $10 $50 $90 $D0 $20 $60 $A0 $E0 $30 $70 $B0 $F0
        .BYTE   $08 $48 $88 $C8 $18 $58 $98 $D8 $28 $68 $A8 $E8 $38 $78 $B8 $F8
@_8e36: .BYTE   $FE $FC $F8 $F0 $E8 $D8 $C8 $C8 $C8 $C8 $D8 $E8 $F0 $F8 $FC $FE
        .BYTE   $02 $04 $08 $10 $18 $28 $38 $38 $38 $38 $28 $18 $10 $08 $04 $02
        ;

powerups_bubbles_process:                                               ;$8E56
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      A,      [IX+Mob.unknown12]
        and     %01111111                                       ;=$7F
        jr      nz,     @_1

        call    _0625
        and     %00000111
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_8ec2
        add     HL,     DE
        bit     0,      [HL]
        call    nz,     _91eb

@_1:    ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      A,      [IX+Mob.unknown11]
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_8eb6
        add     HL,     DE
        ld      E,      [HL]
        ld      [RAM_TEMP4],        DE
        inc     HL
        ld      E,      [HL]
        ld      [RAM_TEMP6],        DE
        ld      A,      $0C
        call    _3581
        inc     [IX+Mob.unknown12]
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000111
        ret     nz

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $06
        ret     c

        ld      [IX+Mob.unknown11],     $00
        ret

@_8eb6: .BYTE   $08 $05 $08 $04 $07 $03 $06 $02 $07 $01 $06 $00
@_8ec2: .BYTE   $01 $00 $01 $01 $00 $01 $00 $01
        ;

_8eca:                                                                  ;$8ECA
;===============================================================================
; unknown mob
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]
        xor     A
        ld      [IX+Mob.spriteLayout+0],        A
        ld      [IX+Mob.spriteLayout+1],        A
        ld      A,      [IX+Mob.unknown11]
        and     $0F
        jr      nz,     @_2

        call    _0625
        ld      BC,     $0020
        ld      D,      $00
        and     $3F
        cp      $20
        jr      c,      @_1

        ld      BC,     $FFE0
        ld      D,      $FF
@_1:    ld      [IX+Mob.Xspeed+0],      C
        ld      [IX+Mob.Xspeed+1],      B
        ld      [IX+Mob.Xdirection],    D
@_2:    ld      [IX+Mob.Yspeed+0],      $A0
        ld      [IX+Mob.Yspeed+1],      $FF
        ld      [IX+Mob.Ydirection],    $FF
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ex      DE,     HL
        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $0008
        xor     A
        sbc     HL,     BC
        jr      nc,     @_3

        ld      L,      A
        ld      H,      A
@_3:    and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $0100
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_4

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        ex      DE,     HL
        ld      HL,     [RAM_D2DC]
        and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $fff0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $00C0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_5

@_4:    ld      [IX+Mob.type],  $FF                     ;remove mob?
@_5:    ld      HL,     $0000
        ld      [RAM_TEMP4],        HL
        ld      [RAM_TEMP6],        HL
        ld      A,      $0C
        call    _3581
        inc     [IX+Mob.unknown11]
        ret
        ;

null_process:                                                           ;$8F6C
;===============================================================================
        ret                             ; object nullified!
        ;

badnick_burrobot_process:                                               ;$8F6D
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ;define the size of the mob
        ;TODO: we don't need to do this every frame. we could set this up when the mob spawns
        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    32

        ;check for collision with Sonic. use a 2px offset on the sprite
        ;TODO: need a means of dynamically generating this 16-bit number from mob specification
        ld      HL,      $0202
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic

        ;if carry is clear, the play took a hit:
        ;define the x/y offset of where to place the explosion
        ld      HL,     $0800
        ld      [RAM_TEMP1],        HL
        call    nc,     hitPlayer

        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $0010
        add     HL,     DE
        adc     A,      $00
        ld      C,      A
        jp      m,      @_1

        ld      A,      H
        cp      $04
        jr      c,      @_1

        ld      HL,     $0300
        ld      C,      $00

@_1:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C

        bit     0,      [IX+Mob.flags]
        jp      nz,     @_4

        ld      DE,     $FFD0
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      DE,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      nc,     @_2

        ld      BC,     $0030
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_2
        set     0,      [IX+Mob.flags]
        ld      [IX+Mob.Yspeed+0],  $80
        ld      [IX+Mob.Yspeed+1],  $FD
        ld      [IX+Mob.Ydirection],        $FF
@_2:    ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      c,      @_3

        ld      [IX+Mob.Xspeed+0],  $C0
        ld      [IX+Mob.Xspeed+1],  $FF
        ld      [IX+Mob.Xdirection],        $FF
        ld      DE,     @_9059
        ld      BC,     @_904a
        call    animateMob
        set     1,      [IX+Mob.flags]
        ret

@_3:    ld      [IX+Mob.Xspeed+0],      $40
        ld      [IX+Mob.Xspeed+1],      $00
        ld      [IX+Mob.Xdirection],    $00
        ld      DE,     @_9059
        ld      BC,     @_9045
        call    animateMob
        res     1,      [IX+Mob.flags]
        ret

@_4:    ld      BC,     @_9054
        bit     1,      [IX+Mob.flags]
        jr      nz,     @_5

        ld      BC,     @_904f
@_5:    ld      DE,     @_9059
        call    animateMob

        bit     7,      [IX+Mob.flags]
        ret     z

        res     0,      [IX+Mob.flags]
        ret

        ;-----------------------------------------------------------------------

@_9045: .BYTE   $00 $04 $01 $04 $FF
@_904a: .BYTE   $02 $04 $03 $04 $FF
@_904f: .BYTE   $04 $04 $04 $04 $FF
@_9054: .BYTE   $05 $04 $05 $04 $FF

        ;sprite layout

@_9059: .BYTE   $44 $46 $FF $FF $FF $FF
        .BYTE   $64 $66 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $44 $46 $FF $FF $FF $FF
        .BYTE   $48 $4A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $50 $52 $FF $FF $FF $FF
        .BYTE   $70 $72 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $50 $52 $FF $FF $FF $FF
        .BYTE   $4C $4E $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $44 $46 $FF $FF $FF $FF
        .BYTE   $68 $6A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $50 $52 $FF $FF $FF $FF
        .BYTE   $6C $6E $FF $FF $FF $FF
        .BYTE   $FF
        ;

platform_float_process:                                                 ;$90C0
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     30
        ld      [IX+Mob.height],    28
        ld      [IX+Mob.spriteLayout+0],    <@_91de
        ld      [IX+Mob.spriteLayout+1],    >@_91de
        bit     1,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [IX+Mob.unknown11], L
        ld      [IX+Mob.unknown12], H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFFF
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown13], L
        ld      [IX+Mob.unknown14], H
        set     1,      [IX+Mob.flags]
@_1:    ld      BC,     $0010
        ld      DE,     $0020
        call    getFloorLayoutRAMAddressForMob
        ld      E,      [HL]
        ld      D,      $00
        ld      A,      [RAM_LEVEL_SOLIDITY]
        add     A,      A
        ld      C,      A
        ld      B,      D
        ld      HL,     solidityBlocks
        add     HL,     BC
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        add     HL,     DE
        ld      A,      [HL]
        and     $3F
        ld      C,      $00
        ld      L,      C
        ld      H,      C
        cp      $1E
        jr      z,      @_2

        bit     0,      [IX+Mob.flags]
        jr      z,      @_3

        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $FFF8
        add     HL,     DE
        adc     A,      $FF
        ld      C,      A
        ld      A,      H
        neg
        cp      $02
        jr      c,      @_2

        ld      HL,     $FF00
        ld      C,      $FF
@_2:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
@_3:    ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $FFE0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      HL,     [RAM_CAMERA_X]
        inc     H
        and     A
        sbc     HL,     DE
        jr      c,      @_4

        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $FFE0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $00e0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_5

@_4:    ld      L,      [IX+Mob.unknown11]
        ld      H,      [IX+Mob.unknown12]
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      L,      [IX+Mob.unknown13]
        ld      H,      [IX+Mob.unknown14]
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H

        xor     A                                          ;set A to 0
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        res     0,      [IX+Mob.flags]
        ret

        ;-----------------------------------------------------------------------

@_5:    ld      HL,     $0E02
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        ret     c

        set     0,      [IX+Mob.flags]
        ld      A,      [RAM_SONIC.Yspeed+1]
        and     A
        jp      p,      @_6

        neg
        cp      $02
        ret     nc

@_6:    ld      E,       [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        ld      BC,     $0010
        call    _LABEL_7CC1_12
        ret

        ;-----------------------------------------------------------------------

        ;sprite layout
        
@_91de: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $16 $18 $1A $1C $FF $FF
        .BYTE   $FF
        ;

_91eb:                                                                  ;$91EB
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        call    findEmptyMob
        ret     c

        ld      C,      $42
        ld      A,      [IX+Mob.type]
        cp      $41
        jr      nz,     @_1

        push    HL
        call    _0625
        and     $0F
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_9257
        add     HL,     DE
        ld      C,      [HL]
        pop     HL
@_1:    ld      A,      C
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX
        ld      [IX+Mob.type],      A
        xor     A                                          ;set A to 0
        ld      [IX+Mob.Xsubpixel], A
        call    _0625
        and     $0F
        ld      L,      A
        ld      H,      $00
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.Ysubpixel], $00
        call    _0625
        and     $0F
        ld      L,      A
        xor     A
        ld      H,      A
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown12], A
        ld      [IX+Mob.flags],     A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        pop     IX
        ret

@_9257: .BYTE   $42 $20 $20 $20 $42 $20 $20 $20 $42 $20 $20 $20 $42 $20 $20 $20
        ;

mob_boss_labyrinth:                                                     ;$9267
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]
        ld      [IX+Mob.width],     32
        ld      [IX+Mob.height],    28
        call    _7ca6
        ld      [IX+Mob.spriteLayout+0],    <@_9493
        ld      [IX+Mob.spriteLayout+1],    >@_9493
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      HL,     $02d0
        ld      DE,     $0290
        call    _7c8c

        set     1,      [IY+Vars.flags9]

        ;UNKNOWN
        ld      HL,     $E508
        ld      DE,     $2000
        ld      A,      12
        call    decompressArt

        ld      HL,     bossPalette
        ld      A,      %00000010
        call    loadPaletteOnInterrupt
        xor     A
        ld      [RAM_D2EC], A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_BOSS1
                rst     $18     ;=rst_playMusic
        .ENDIF

        set     0,      [IX+Mob.flags]
@_1:    ld      A,       [IX+Mob.unknown11]
        and     A
        jr      nz,     @_2

        ld      A,      [IX+Mob.unknown13]
        add     A,      A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_947b
        add     HL,     DE
        ld      A,      [HL]
        ld      [IX+Mob.X+0],       A
        inc     HL
        ld      A,      [HL]
        inc     HL
        ld      [IX+Mob.X+1],       A
        ld      A,      [HL]
        inc     HL
        ld      [IX+Mob.Y+0],       A
        ld      A,      [HL]
        inc     HL
        ld      [IX+Mob.Y+1],       A
        inc     [IX+Mob.unknown11]
        jp      @_

        ;-----------------------------------------------------------------------

@_2:    dec     A
        jr      nz,     @_5

        ld      A,      [IX+Mob.unknown13]
        and     A
        jr      nz,     @_3

        ld      [IX+Mob.Yspeed+0],  $80
        ld      [IX+Mob.Yspeed+1],  $FF
        ld      [IX+Mob.Ydirection],        $FF
        jp      @_4

@_3:    ld      [IX+Mob.Yspeed+0],      $80
        ld      [IX+Mob.Yspeed+1],      $00
        ld      [IX+Mob.Ydirection],    $00
@_4:    ld      HL,     @_9487
        ld      A,      [IX+Mob.unknown13]
        add     A,      A
        ld      E,      A
        ld      D,      $00
        add     HL,     DE
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        and     A
        sbc     HL,     DE
        jp      nz,     @_

        inc     [IX+Mob.unknown11]
        ld      [IX+Mob.unknown12],$00
        jp      @_

        ;-----------------------------------------------------------------------

@_5:    dec     A
        jp      nz,     @_6

        xor     A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        inc     [IX+Mob.unknown12]
        ld      A,      [IX+Mob.unknown12]
        cp      $64
        jp      nz,     @_

        inc     [IX+Mob.unknown11]
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $000F
        add     HL,     DE
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     $0022
        add     HL,     BC
        ld      [RAM_TEMP3],        HL
        ld      A,      [IX+Mob.unknown13]
        and     A
        jp      z,      @_9432
        ld      A,      [RAM_D2EC]
        cp      $08
        jp      nc,     @_

        call    findEmptyMob
        jp      c,      @_

        push    IX
        push    HL
        pop     IX

        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $2F                     ;unknown mob
        ld      HL,     [RAM_TEMP1]
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      HL,     [RAM_TEMP3]
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.flags],     A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A

        pop     IX
        jp      @_

        ;-----------------------------------------------------------------------

@_6:    ld      A,       [IX+Mob.unknown13]
        and     A
        jr      nz,     @_7

        ld      [IX+Mob.Yspeed+0],  $80
        ld      [IX+Mob.Yspeed+1],  $00
        ld      [IX+Mob.Ydirection],        $00
        jp      @_8

@_7:    ld      [IX+Mob.Yspeed+0],      $80
        ld      [IX+Mob.Yspeed+1],      $FF
        ld      [IX+Mob.Ydirection],    $FF
@_8:    ld      HL,     $948D
        ld      A,      [IX+Mob.unknown13]
        add     A,      A
        ld      E,      A
        ld      D,      $00
        add     HL,     DE
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        xor     A
        sbc     HL,     DE
        jr      nz,     @_

        ld      [IX+Mob.unknown11], A
        inc     [IX+Mob.unknown13]
        ld      A,      [IX+Mob.unknown13]
        cp      $03
        jr      c,      @_

        ld      [IX+Mob.unknown13], $00

@_:     ld      HL,     $00A2
        ld      [RAM_D216], HL
        call    _77be
        ld      A,      [RAM_D2EC]
        cp      $08
        ret     nc

        bit     7,      [IX+Mob.Ydirection]
        ret     z

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        ld      HL,     $0010
        ld      [RAM_TEMP4],        HL
        ld      HL,     $0030
        ld      [RAM_TEMP6],        HL
        ld      A,      [RAM_FRAMECOUNT]
        and     $02
        call    _3581
        ret

        ;-----------------------------------------------------------------------

@_9432: ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0004
        add     HL,     DE
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFFA
        add     HL,     DE
        ld      [RAM_TEMP3],        HL
        ld      HL,     $FF00
        ld      [RAM_TEMP4],        HL
        ld      HL,     $FF00
        ld      [RAM_TEMP6],        HL
        ld      C,      $04
        call    _85d1
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0020
        add     HL,     DE
        ld      [RAM_TEMP1],        HL
        ld      HL,     $0100
        ld      [RAM_TEMP4],        HL
        ld      C,      $04
        call    _85d1

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

        jp      @_

        ;-----------------------------------------------------------------------

@_947b: .BYTE   $3C $03 $60 $03 $EC $02 $60 $02 $8C $03 $60 $02
@_9487: .BYTE   $28 $03 $B0 $02 $B0
@_948c: .BYTE   $02 $60 $03 $60 $02 $60 $02

        ;sprite layout
@_9493: .BYTE   $20 $22 $24 $26 $28 $FF
        .BYTE   $40 $42 $44 $46 $48 $FF
        .BYTE   $60 $62 $64 $66 $68 $FF
        ;

unknown_94a5_process:                                                   ;$94A5
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     8
        ld      [IX+Mob.height],    10
        ld      HL,     $0404
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        bit     1,      [IX+Mob.flags]
        jr      nz,     @_1

        set     1,      [IX+Mob.flags]
        ld      HL,     [RAM_SONIC.X]
        ld      DE,     $000C
        add     HL,     DE
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      BC,     $0008
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_1

        set     2,      [IX+Mob.flags]
@_1:    bit     0,      [IX+Mob.flags]
        jr      nz,     @_3

        ld      [IX+Mob.Yspeed+0],  $40
        ld      [IX+Mob.Yspeed+1],  $00
        ld      [IX+Mob.Ydirection],        $00
        ld      HL,     @_9698
        bit     2,      [IX+Mob.flags]
        jr      z,      @_2

        ld      HL,     @_9688
@_2:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        ld      HL,     [RAM_SONIC.Y]
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        and     A
        sbc     HL,     DE
        ret     nc

        set     0,      [IX+Mob.flags]
        ret

        ;-----------------------------------------------------------------------

@_3:    ld      C,       [IX+Mob.X+0]
        ld      B,      [IX+Mob.X+1]
        ld      HL,     $FFF0
        add     HL,     BC
        ld      DE,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     DE
        jr      c,      @_4

        ld      L,      C
        ld      H,      B
        inc     D
        and     A
        sbc     HL,     DE
        jr      nc,     @_4

        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        ld      HL,     $FFF0
        add     HL,     BC
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        jr      c,      @_4

        ld      HL,     $00c0
        add     HL,     DE
        and     A
        sbc     HL,     BC
        jr      nc,     @_5

@_4:    ld      [IX+Mob.type],  $FF                     ;remove object
@_5:    xor     A
        ld      HL,     $0002
        bit     2,      [IX+Mob.flags]
        jr      nz,     @_6

        dec     A
        ld      HL,     $FFFE
@_6:    ld      E,       [IX+Mob.Xspeed+0]
        ld      D,      [IX+Mob.Xspeed+1]
        add     HL,     DE
        adc     A,      [IX+Mob.Xdirection]
        ld      C,      A
        ld      A,      H
        ld      DE,     $0100
        bit     7,      C
        jr      z,      @_7

        ld      A,      L
        cpl
        ld      E,      A
        ld      A,      H
        cpl
        ld      D,      A
        inc     DE
        ld      A,      D
        ld      DE,     $FF00
@_7:    and     A
        jr      z,      @_8

        ex      DE,     HL
@_8:    ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    C
        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $0010
        add     HL,     DE
        ex      DE,     HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     $0008
        add     HL,     BC
        and     A
        sbc     HL,     DE
        ld      A,      $FF
        ld      HL,     $FFFE
        bit     7,      [IX+Mob.Ydirection]
        jr      nz,     @_9

        ld      HL,     $FFFC
@_9:    jr      nc,     @_10

        inc     A
        ld      HL,     $0002
        bit     7,      [IX+Mob.Ydirection]
        jr      z,      @_10

        ld      HL,     $0004
@_10:   ld      E,       [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        add     HL,     DE
        adc     A,      [IX+Mob.Ydirection]
        ld      C,      A
        ld      A,      H
        ld      DE,     $0100
        bit     7,      C
        jr      z,      @_11
        ld      A,      L
        cpl
        ld      E,      A
        ld      A,      H
        cpl
        ld      D,      A
        inc     DE
        ld      A,      D
        ld      DE,     $FF00
@_11:   and     A
        jr      z,      @_12

        ex      DE,     HL
@_12:   ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
        ld      HL,     @_9688
        bit     7,      [IX+Mob.Xdirection]
        jr      z,      @_13

        ld      HL,     @_9698
@_13:   push    HL
        ld      L,      [IX+Mob.Xspeed+0]
        ld      H,      [IX+Mob.Xspeed+1]
        bit     7,      H
        jr      z,      @_14

        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
@_14:   ld      E,       [IX+Mob.unknown11]
        ld      D,      [IX+Mob.unknown12]
        add     HL,     DE
        ld      [IX+Mob.unknown11], L
        ld      [IX+Mob.unknown12], H
        ld      A,      H
        and     $08
        ld      E,      A
        ld      D,      $00
        pop     HL
        add     HL,     DE
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FFF9
        bit     7,      [IX+Mob.Xdirection]
        jr      z,      @_15

        ld      DE,     $000F
@_15:   add     HL,     DE
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        ld      A,      [RAM_FRAMECOUNT]
        and     $0F
        ret     nz

        call    findEmptyMob
        ret     c

        push    IX
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $2A                     ;unknown object
        ld      HL,     [RAM_TEMP1]
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      HL,     [RAM_TEMP3]
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown12], A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        pop     IX
        ret

        ;sprite layout
@_9688: .BYTE   $3C $3E $FF $FF $FF $FF
        .BYTE   $FF $FF $38 $3A $FF $FF
        .BYTE   $FF $FF $FF $FF
@_9698: .BYTE   $56 $58 $FF $FF $FF $FF
        .BYTE   $FF $FF $5A $5C $FF $FF
        .BYTE   $FF $FF $FF $FF
        ;

unknown_96a8_process:                                                   ;$96A8
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        ld      L, A
        ld      H, A
        ld      [RAM_TEMP4],        HL
        ld      [RAM_TEMP6],        HL
        ld      E,      [IX+Mob.unknown12]
        ld      D,      $00
        ld      HL,     @_96f5
        add     HL,     DE
        ld      A,      [HL]
        call    _3581
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $0C
        ret     c

        ld      [IX+Mob.unknown11], $00
        inc     [IX+Mob.unknown12]
        ld      A,      [IX+Mob.unknown12]
        cp      $03
        ret     c

        ld      [IX+Mob.type],      $FF                     ;remove object?
        ret

@_96f5: .BYTE   $1C $1E $5E
        ;

unknown_96f8_process:                                                   ;$96F8
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      A,      [IY+Vars.spriteUpdateCount]
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        push    AF
        push    HL
        ld      A,      [RAM_D2DE]
        cp      $24
        jr      nc,     @_3

        ld      E,      A
        ld      D,      $00
        ld      HL,     RAM_SPRITETABLE
        add     HL,     DE
        ld      [RAM_SPRITETABLE_ADDR],     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        ld      HL,     $0000
        ld      [RAM_TEMP4],        HL
        ld      [RAM_TEMP6],        HL
        ld      A,      [IX+Mob.unknown12]
        and     A
        jr      z,      @_1

        cp      $08
        jr      nc,     @_1

        ld      HL,     $0004
        ld      [RAM_TEMP4],        HL
        ld      A,      $0C
        jr      @_2

@_1:    ld      A,      $40
        call    _3581
        ld      HL,     [RAM_TEMP4]
        ld      DE,     $0008
        add     HL,     DE
        ld      [RAM_TEMP4],        HL
        ld      A,      $42
@_2:    call    _3581
        ld      A,      [RAM_D2DE]
        add     A,      $06
        ld      [RAM_D2DE], A
@_3:    pop     HL
        pop     AF
        ld      [RAM_SPRITETABLE_ADDR],     HL
        ld      [IY+Vars.spriteUpdateCount],       A
        ld      [IX+Mob.width],     $0A
        ld      [IX+Mob.height],    $0C
        ld      A,      [IX+Mob.unknown12]
        and     A
        jr      z,      @_4

        ld      C,      $00
        ld      B,      C
        ld      D,      C
        ld      [IX+Mob.Yspeed+0],  C
        ld      [IX+Mob.Yspeed+1],  C
        ld      [IX+Mob.Ydirection],        C
        dec     [IX+Mob.unknown12]
        jp      nz,     @_6

        ld      [IX+Mob.type],      $FF                     ;remove object
        jp      @_6

@_4:    ld      HL,     $0206
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_5

        ld      BC,     [RAM_SONIC.Y]
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        ld      HL,     $FFF8
        add     HL,     DE
        and     A
        sbc     HL,     BC
        jr      nc,     @_5

        ld      HL,     $0006
        add     HL,     DE
        and     A
        sbc     HL,     BC
        jr      c,      @_5

        ld      A,      [IX+Mob.unknown12]
        and     A
        jr      nz,     @_5

        xor     A
        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        ld      [RAM_D28E], A
        ld      [RAM_D29B], HL
        set     2,      [IY+Vars.unknown0]
        ld      A,      $20
        ld      [RAM_D2FB], A
        ld      [IX+Mob.unknown12], $10

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_22
                rst     $28     ;=rst_playSFX
        .ENDIF

@_5:    ld      [IX+Mob.Yspeed+0],      $98
        ld      [IX+Mob.Yspeed+1],      $FF
        ld      [IX+Mob.Ydirection],    $FF
        ld      A,      [IX+Mob.unknown11]
        and     $0F
        jr      nz,     @_7

        call    _0625
        ld      BC,     $0020
        ld      D,      $00
        and     $3F
        cp      $20
        jr      c,      @_6

        ld      BC,     $FFE0
        ld      D,      $FF
@_6:    ld      [IX+Mob.Xspeed+0],      C
        ld      [IX+Mob.Xspeed+1],      B
        ld      [IX+Mob.Xdirection],    D
@_7:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ex      DE,     HL
        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $0008
        xor     A
        sbc     HL,     BC
        jr      nc,     @_8

        ld      L,      A
        ld      H,      A
@_8:    and     A
        sbc     HL,     DE
        jr      nc,     @_9

        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $0100
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_9

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ex      DE,     HL
        ld      HL,     [RAM_D2DC]
        and     A
        sbc     HL,     DE
        jr      nc,     @_9

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $FFF0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_9

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $00C0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_10

@_9:    ld      [IX+Mob.type],  $FF                     ;remove object
@_10:   inc     [IX+Mob.unknown11]
        ret
        ;

platform_flipper_process:                                               ;$9866
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]              ;mob does not collide with the floor
        ld      [IX+Mob.spriteLayout+0],    <@_9a7e
        ld      [IX+Mob.spriteLayout+1],    >@_9a7e
        bit     5,      [IY+Vars.joypad]
        jr      nz,     @_1

        ld      A,      [IX+Mob.unknown11]
        ld      [IX+Mob.unknown12], A
        ld      A,      [IX+Mob.unknown11]
        cp      $05
        jr      nc,     @_2

        inc     [IX+Mob.unknown11]
        jp      @_2

@_1:    ld      A,       [IX+Mob.unknown11]
        and     A
        jr      z,      @_2

        dec     [IX+Mob.unknown11]
@_2:    ld      A,       [IX+Mob.unknown11]
        cp      $01
        jr      nc,     @_3

        ld      HL,     $140C
        ld      [RAM_TEMP6],        HL
        ld      [IX+Mob.width],     $1E
        ld      [IX+Mob.height],    $16
        call    detectCollisionWithSonic
        ret     c

        ld      BC,     @_999e
        call    @_9aaf
        ret     nc

        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        ld      DE,     $FFFC
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      [RAM_SONIC.Xdirection]
        add     HL,     DE
        adc     A,      $FF
        ld      [RAM_SONIC.Xspeed], HL
        ld      [RAM_SONIC.Xdirection],     A
        ret

@_3:    cp      $04
        jp      nc,     @_4
        ld      [IX+Mob.spriteLayout+0],    <@_9a90
        ld      [IX+Mob.spriteLayout+1],    >@_9a90
        ld      HL,     $080f
        ld      [RAM_TEMP6],        HL
        ld      [IX+Mob.width],     $1E
        ld      [IX+Mob.height],    $16
        call    detectCollisionWithSonic
        ret     c

        ld      BC,     @_99be
        call    @_9aaf
        ret     nc

        ld      A,      [IX+Mob.unknown12]
        cp      [IX+Mob.unknown11]
        ret     nc

        ld      A,      [RAM_SONIC.X]
        add     A,      $0C
        and     %00011111
        add     A,      A
        ld      C,      A
        ld      B,      $00
        ld      HL,     @_99fe
        add     HL,     BC
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      [RAM_SONIC.Xdirection]
        add     HL,     DE
        adc     A,      $FF
        ld      [RAM_SONIC.Xspeed], HL
        ld      [RAM_SONIC.Xdirection],     A
        ld      HL,     @_9a3e
        add     HL,     BC
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Ydirection]
        cpl
        add     HL,     DE
        adc     A,      $FF
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        ret

        ;unused section of code?
        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        ld      DE,     $0008
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      [RAM_SONIC.Xdirection]
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_SONIC.Xspeed], HL
        ld      [RAM_SONIC.Xdirection],     A
        ret

@_4:    ld      [IX+Mob.spriteLayout+0],        <@_9aa2
        ld      [IX+Mob.spriteLayout+1],        >@_9aa2
        ld      HL,     $021A
        ld      [RAM_TEMP6],        HL
        ld      [IX+Mob.width],     $1E
        ld      [IX+Mob.height],    $16
        call    detectCollisionWithSonic
        ret     c

        ld      BC,     @_99de
        call    @_9aaf
        ret     nc

        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        ld      DE,     $001a
        ld      HL,     [RAM_SONIC.Xspeed]
        ld      A,      [RAM_SONIC.Xdirection]
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_SONIC.Xspeed], HL
        ld      [RAM_SONIC.Xdirection],     A
        ret

@_999e: .BYTE   $FF $FF $FE $FE $FE $FD $FD $FD $FC $FC $FC $FC $FB $FB $FB $FB
        .BYTE   $FA $FA $FA $FA $FA $F9 $F9 $F9 $F9 $F9 $F9 $FA $FA $FB $FC $FE
@_99be: .BYTE   $EA $EA $EA $F6 $F7 $F8 $F8 $F8 $F9 $F9 $F9 $FA $FA $FA $FB $FB
        .BYTE   $FB $FB $FC $FC $FC $FC $FD $FD $FD $FD $FE $FE $FF $00 $02 $04
@_99de: .BYTE   $EA $EA $EA $EA $EA $EA $EA $EA $EA $EA $EA $EA $EE $ED $EC $EC
        .BYTE   $EC $ED $EE $EF $F0 $F2 $F3 $F4 $F5 $F7 $F8 $F9 $FA $FB $FD $FF
@_99fe: .BYTE   $00 $F8 $00 $F8 $00 $F9 $00 $FA $00 $FB $00 $FC $E0 $FC $80 $FD
        .BYTE   $C0 $FD $00 $FE $40 $FE $80 $FE $C0 $FE $00 $FF $20 $FF $40 $FF
        .BYTE   $60 $FF $80 $FF $A0 $FF $C0 $FF $E0 $FF $E8 $FF $EA $FF $EC $FF
        .BYTE   $EE $FF $F0 $FF $F2 $FF $F4 $FF $F6 $FF $F8 $FF $FC $FF $FE $FF
@_9a3e: .BYTE   $00 $FC $00 $FC $00 $FC $00 $FB $00 $FA $00 $F9 $00 $F8 $00 $F7
        .BYTE   $00 $F6 $80 $F5 $00 $F5 $C0 $F4 $80 $F4 $40 $F4 $00 $F4 $00 $F4
        .BYTE   $00 $F4 $00 $F4 $40 $F4 $80 $F4 $C0 $F4 $00 $F5 $00 $F6 $00 $F7
        .BYTE   $00 $F9 $00 $FA $00 $FC $80 $FC $00 $FD $C0 $FD $00 $FF $00 $FF

        ;sprite layout
@_9a7e: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $38 $3A $3C $3E $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
@_9a90: .BYTE   $48 $4A $4C $4E $FF $FF
        .BYTE   $68 $6A $6C $6E $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
@_9aa2: .BYTE   $FE $12 $14 $16 $FF $FF
        .BYTE   $FE $32 $34 $36 $FF $FF
        .BYTE   $FF

        ;-----------------------------------------------------------------------

@_9aaf: ld      A,      [RAM_SONIC.Ydirection]                              ;$9AAF
        and     A
        ret     m

        ld      A,      [RAM_SONIC.X]
        add     A,      $0c
        and     %00011111
        ld      L,      A
        ld      H,      $00
        add     HL,     BC
        ld      B,      $00
        ld      C,      [HL]
        bit     7,      C
        jr      z,      @_5

        dec     B
@_5:    ld      L,       [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     BC
        ld      [RAM_SONIC.Y],      HL
        ld      A,      [RAM_SONIC.Yspeed+1]
        cp      $03
        jr      nc,     @_6

        scf
        ret

@_6:    ld      DE,     $0001
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Ydirection]
        cpl
        add     HL,     DE
        adc     A,      $00
        sra     A
        rr      H
        rr      L
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        and     A
        ret
        ;

platform_bumper_process:                                                ;$9AFB
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     $1C
        ld      [IX+Mob.height],    $06
        ld      [IX+Mob.spriteLayout+0],    <@_9b6e
        ld      [IX+Mob.spriteLayout+1],    >@_9b6e
        ld      HL,     $0001
        ld      A,      [IX+Mob.unknown12]
        cp      $60
        jr      nc,     @_1

        ld      HL,     $FFFF
@_1:    ld      [IX+Mob.Xspeed+0],      $00
        ld      [IX+Mob.Xspeed+1],      L
        ld      [IX+Mob.Xdirection],    H
        inc     A
        cp      $C0
        jr      c,      @_2

        xor     A
@_2:    ld      [IX+Mob.unknown12],     A
        ld      A,      [IX+Mob.unknown11]
        and     A
        jr      nz,     @_3

        ld      HL,     $0602
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        ret     c

        ld      A,      [RAM_D2E8]
        ld      DE,     [RAM_D2E6]
        ld      C,      A
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Ydirection]
        cpl
        add     HL,     DE
        adc     A,      C
        ld      DE,     $0001
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        ld      [IX+Mob.unknown11], $08

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_07
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret

@_3:    dec     [IX+Mob.unknown11]
        ret

        ;sprite layout
        
@_9b6e: .BYTE   $08 $0A $28 $2A $FF $FF
        .BYTE   $FF
;

unknown_9b75_process:                                                   ;$9B75
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     30
        ld      [IX+Mob.height],    96
        ld      HL,     $0000
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      E,      H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      A,      L
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        add     A,      A
        rl      H
        ld      D,      H
        ld      HL,     @_9bd9
        ld      B,      $05

@loop:  ld      A,       [HL]
        inc     HL
        cp      E
        jr      nz,     @_1

        ld      A,      [HL]
        cp      D
        jr      nz,     @_1

        inc     HL
        ld      A,      [HL]
        ld      [RAM_D2D3], A
        ld      A,      $01
        ld      [RAM_D289], A
        set     4,      [IY+Vars.flags6]
        jp      @_2

@_1:    inc     HL
        inc     HL
        djnz    @loop

@_2:    xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ret

@_9bd9: .BYTE   $7D $1A $15 $7D $01 $14 $01 $3C $18 $01 $02
        .BYTE   $19 $14 $0F $1A
        ;

unknown_9be8_process:                                                   ;$9BE8
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.Xspeed+0],  $80
        ld      [IX+Mob.Xspeed+1],  $01
        ld      [IX+Mob.Xdirection],        $00
        ld      [IX+Mob.spriteLayout+0],    <@_9c69
        ld      [IX+Mob.spriteLayout+1],    >@_9c69

@_9bfc: set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      A,      [IX+Mob.X+0]
        ld      [IX+Mob.unknown11], A
        ld      A,      [IX+Mob.X+1]
        ld      [IX+Mob.unknown12], A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_18
                rst     $28     ;=rst_playSFX
        .ENDIF

        set     0,      [IX+Mob.flags]
@_1:    ld      [IX+Mob.width],         $06
        ld      [IX+Mob.height],        $08
        ld      A,      [IX+Mob.unknown13]
        cp      $64
        jr      nc,     @_2

        ld      HL,     $0400
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

@_2:    inc     [IX+Mob.unknown13]
        ld      A,      [IX+Mob.unknown13]
        cp      $64
        ret     c

        cp      $F0
        jr      c,      @_3

        xor     A                                          ;set A to 0
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.unknown13], A
        ld      A,      [IX+Mob.unknown11]
        ld      [IX+Mob.X+0],       A
        ld      A,      [IX+Mob.unknown12]
        ld      [IX+Mob.X+1],       A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_18
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret

@_3:    xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ret

        ;sprite layout
        
@_9c69: .BYTE   $0C $0E $FF $FF $FF $FF
        .BYTE   $FF
        ;

_9c70:                                                                  ;$9C70
;===============================================================================
; unknown mob
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.Xspeed+0],  $80
        ld      [IX+Mob.Xspeed+1],  $FE
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.spriteLayout+0],    <@_9c87
        ld      [IX+Mob.spriteLayout+1],    >@_9c87
        jp      unknown_9be8_process@_9bfc

        ;sprite layout

@_9c87: .BYTE   $2C $2E $FF $FF $FF $FF
        .BYTE   $FF
        ;

mob_trap_flameThrower:                                                  ;$9C8E
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $000C
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0012
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        call    _0625
        ld      [IX+Mob.unknown11], A
        set     0,      [IX+Mob.flags]
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        ld      HL,     $0000
        ld      [RAM_TEMP4],        HL
        ld      A,      [IX+Mob.unknown11]
        srl     A
        srl     A
        srl     A
        srl     A
        ld      C,      A
        ld      B,      $00
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     _9d6a
        add     HL,     BC
        ld      A,      [HL]
        ld      [IX+Mob.height],    A
        ld      [IX+Mob.width],     $06
        ld      HL,     _9d4a
        add     HL,     DE
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        or      H
        jr      z,      @_2
        ld      A,      [IX+Mob.unknown11]
        add     A,      A
        add     A,      A
        add     A,      A
        and     %00011111
        ld      E,      A
        ld      D,      $00
        add     HL,     DE
        ld      B,      $04

@loop:  push    BC
        ld      A,      [HL]
        inc     HL
        ld      E,      [HL]
        inc     HL
        ld      D,      $00
        push    HL
        ld      [RAM_TEMP6],        DE
        call    _3581
        pop     HL
        pop     BC
        djnz    @loop

        ld      A,      [IX+Mob.height]
        and     A
        jr      z,      @_2

        ld      HL,     $0202
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

@_2:    inc     [IX+Mob.unknown11]
        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        ld      A,      [IX+Mob.unknown11]
        cp      $70
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_17
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

_9d4a:                                                                  ;$9D4A
;===============================================================================

        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $9A $9D
        .BYTE   $BA $9D $DA $9D $7A $9D $7A $9D $7A $9D $DA $9D $BA $9D $9A $9D
        ;

_9d6a:                                                                  ;$9D6A
;===============================================================================

        .BYTE   $00 $00 $00 $00 $00 $00 $00 $1B $1F $22 $25 $25 $25 $22 $1F $1B
        .BYTE   $00 $15 $1E $0E $1E $07 $1E $00 $00 $17 $1E $10 $1E $09 $1E $02
        .BYTE   $00 $19 $1E $12 $1E $0B $1E $04 $00 $1B $1E $14 $1E $0D $1E $06
        .BYTE   $00 $0C $1E $08 $1E $04 $1E $00 $00 $0E $1E $0A $1E $06 $1E $02
        .BYTE   $00 $10 $1E $0C $1E $08 $1E $04 $00 $11 $1E $0E $1E $0A $1E $06
        .BYTE   $00 $0F $1E $0A $1E $05 $1E $00 $00 $11 $1E $0C $1E $07 $1E $02
        .BYTE   $00 $13 $1E $0E $1E $09 $1E $04 $00 $15 $1E $10 $1E $0B $1E $06
        .BYTE   $00 $12 $1E $0C $1E $06 $1E $00 $00 $14 $1E $0E $1E $08 $1E $02
        .BYTE   $00 $16 $1E $10 $1E $0A $1E $04 $00 $18 $1E $12 $1E $0C $1E $06
        ;

mob_door_left:                                                          ;$9DFA
;===============================================================================
; door - one way left (Scrap Brain)
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]               ;mob does not collide with the floor
        call    _9ed4
        ld      A,      [IX+Mob.unknown11]
        cp      $28
        jr      nc,     @_2

        ld      HL,     $0005
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      DE,     $0005
        ld      A,      [RAM_SONIC.Xdirection]
        and     A
        jp      m,      @_1

        ld      DE,     $FFEC
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [RAM_SONIC.X],      HL
        xor     A
        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Xspeed], HL
        ld      [RAM_SONIC.Xdirection],     A
@_2:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FFC8
        add     HL,     DE
        ld      DE,     [RAM_SONIC.X]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        jr      c,      @_3

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFE0
        add     HL,     DE
        ld      DE,     [RAM_SONIC.Y]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     $0050
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_3

        call    _9eb4
        jr      @_4

@_3:    call    _9ec4
@_4:    ld      DE,     _9f2b
@_9e7e: ld      A,      [IX+Mob.unknown11]
        and     $0F
        ld      C,      A
        ld      B,      $00
        ld      L,      [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        and     A
        sbc     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      A,      [IX+Mob.unknown11]
        srl     A
        srl     A
        srl     A
        srl     A
        and     $03
        add     A,      A
        ld      C,      A
        add     A,      A
        add     A,      A
        add     A,      A
        add     A,      C
        ld      C,      A
        ld      B,      $00
        ex      DE,     HL
        add     HL,     BC
        ld      [IX+Mob.spriteLayout+0],    L
        ld      [IX+Mob.spriteLayout+1],    H
        ret
        ;

_9eb4:                                                                  ;$9EB4
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      A,      [IX+Mob.unknown11]
        cp      $30
        ret     nc
        inc     A
        ld      [IX+Mob.unknown11], A
        dec     A
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_19
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret
        ;

_9ec4:                                                                  ;$9EC4
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      A,      [IX+Mob.unknown11]
        and     A
        ret     z

        dec     A
        ld      [IX+Mob.unknown11], A
        cp      $2F
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_19
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

_9ed4:                                                                  ;$9ED4
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     4
        ld      A,      [IX+Mob.unknown11]
        srl     A
        srl     A
        srl     A
        srl     A
        and     $03
        ld      E,      A
        ld      A,      $03
        sub     E
        add     A,      A
        add     A,      A
        add     A,      A
        add     A,      A
        ld      [IX+Mob.height],    A
        bit     0,      [IX+Mob.flags]
        ret     nz

        ld      BC,     $0000
        ld      DE,     $FFF0
        call    getFloorLayoutRAMAddressForMob
        ld      DE,     $0014
        ld      A,      [HL]
        cp      $A3
        jr      z,      @_1

        ld      DE,     $0004
        set     1,      [IX+Mob.flags]
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      A,      [IX+Mob.Y+0]
        ld      [IX+Mob.unknown12], A
        ld      A,      [IX+Mob.Y+1]
        ld      [IX+Mob.unknown13], A
        set     0,      [IX+Mob.flags]
        ret
        ;

;sprite layout
_9f2b:                                                                  ;$9F2B
;===============================================================================

        .BYTE   $0A $FF $FF $FF $FF $FF
        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $0A $FF $FF $FF $FF $FF

        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $0A $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $0A $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF
        ;

mob_door_right:                                                         ;$9F62
;===============================================================================
; door - one way right (Scrap Brain)
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor
        call    _9ed4
        ld      A,      [IX+Mob.unknown11]
        cp      $28
        jr      nc,     @_2

        ld      HL,     $0005
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      DE,     $0005
        ld      A,      [RAM_SONIC.Xdirection]
        and     A
        jp      m,      @_1

        ld      DE,     $FFEC
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [RAM_SONIC.X],      HL

        xor     A
        ld      [RAM_SONIC.Xspeed+0],       A
        ld      [RAM_SONIC.Xspeed+1],       A
        ld      [RAM_SONIC.Xdirection],     A

@_2:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FFF0
        add     HL,     DE
        ld      DE,     [RAM_SONIC.X]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      BC,     $0024
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_3

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $ffe0
        add     HL,     DE
        ld      DE,     [RAM_SONIC.Y]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     $0050
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_3

        call    _9eb4
        jr      @_4
@_3:    call    _9ec4
@_4:    ld      DE,     @_9fee
        jp      mob_door_left@_9e7e

        ;-----------------------------------------------------------------------

@_9fee: ;sprite layout                                                                                         `$9FEE
        .BYTE   $36 $FF $FF $FF $FF $FF
        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $36 $FF $FF $FF $FF $FF

        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $36 $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $36 $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF
        ;

mob_door:                                                               ;$A025
;===============================================================================
; in    IX         Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                     ;mob does not collide with the floor
        call    _9ed4

        ld      A,      [IX+Mob.unknown11]
        cp      $28
        jr      nc,     @_2

        ld      HL,     $0005
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      DE,     $0005
        ld      A,      [RAM_SONIC.Xdirection]
        and     A
        jp      m,      @_1

        ld      DE,     $FFEC
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [RAM_SONIC.X],      HL

        xor     A
        ld      [RAM_SONIC.Xspeed+0],       A
        ld      [RAM_SONIC.Xspeed+1],       A
        ld      [RAM_SONIC.Xdirection],     A

@_2:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FFC8
        add     HL,     DE
        ld      DE,     [RAM_SONIC.X]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      BC,     $0024
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_3

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFE0
        add     HL,     DE
        ld      DE,     [RAM_SONIC.Y]
        xor     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     $0050
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_3

        call    _9eb4
        jr      @_4

@_3:    call    _9ec4
@_4:    ld      DE,     @_a0b1
        jp      mob_door_left@_9e7e

        ;-----------------------------------------------------------------------

        ;sprite layout
@_a0b1:                                                                 ;$A0B1
        .BYTE   $38 $FF $FF $FF $FF $FF
        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $38 $FF $FF $FF $FF $FF

        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $38 $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $38 $FF $FF $FF $FF $FF

        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF
        ;

trap_electric_process:                                                  ;$A0E8
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     $30
        ld      [IX+Mob.height],    $10
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0018
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0010
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        set     0,      [IX+Mob.flags]
@_1:    ld      A,       [IX+Mob.unknown11]
        cp      $64
        jr      c,      @_3
        jr      nz,     @_2

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_13
                rst     $28     ;=rst_playSFX
        .ENDIF

@_2:    ld      HL,     $0000
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      DE,     @_a173
        ld      BC,     @_a167
        call    animateMob
        jp      @_5

@_3:    cp      $46
        jr      nc,     @_4

        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        jp      @_5

@_4:    ld      DE,     @_a173
        ld      BC,     @_a16e
        call    animateMob
@_5:    inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $A0
        ret     c

        ld      [IX+Mob.unknown11], $00
        ret

@_a167:                                                                 ;$A167
        .BYTE   $00 $01 $01 $01 $02 $01 $FF
@_a16e:                                                                 ;$A16E
        .BYTE   $02 $01 $03 $01 $FF

@_a173: ; sprite layout                                                 ;$A173
        .BYTE   $02 $04 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $FE $FE $FE $02 $04
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $FE $16 $18 $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF
        ;

badnick_ballhog_process:                                                ;$A1AA
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     10
        ld      [IX+Mob.height],    32

        ld      HL,     $0803
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic

        ld      HL,     $0E00
        ld      [RAM_TEMP1],        HL
        call    nc,     hitPlayer

        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $01
        ld      [IX+Mob.Ydirection],        $00
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $000A
        add     HL,     DE
        ex      DE,     HL
        ld      HL,     [RAM_SONIC.X]
        ld      BC,     $000C
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_3

        ld      BC,     @_a2d2
        ld      A,      [IX+Mob.unknown11]
        cp      $EB
        jr      c,      @_2
        jr      nz,     @_1

        ld      [IX+Mob.unknown16], $00
@_1:    ld      BC,     @_a2d7
@_2:    ld      DE,     @_a2da
        call    animateMob
        ld      A,      [IX+Mob.unknown11]
        cp      $ED
        jp      nz,     @_6

        call    findEmptyMob
        jp      c,      @_6

        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $1C                     ;ball from the Ball Hog
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       E
        ld      [IX+Mob.X+1],       D
        ld      HL,     $0006
        add     HL,     BC
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  $FF
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  $01
        ld      [IX+Mob.Ydirection],        A
        pop     IX
        jp      @_6

        ;-----------------------------------------------------------------------

@_3:    ld      BC,     @_a2d2
        ld      A,      [IX+Mob.unknown11]
        cp      $EB
        jr      c,      @_5
        jr      nz,     @_4

        ld      [IX+Mob.unknown16], $00
@_4:    ld      BC,     @_a2d7
@_5:    ld      DE,     @_a30b
        call    animateMob
        ld      A,      [IX+Mob.unknown11]
        cp      $ED
        jr      nz,     @_6

        call    findEmptyMob
        jp      c,      @_6

        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    IX
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $1C                     ;ball from the Ball Hog
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       E
        ld      [IX+Mob.X+1],       D
        ld      HL,     $0006
        add     HL,     BC
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  $01
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  $01
        ld      [IX+Mob.Ydirection],        A
        pop     IX
@_6:    inc     [IX+Mob.unknown11]
        ret

@_a2d2:                                                                 ;$A2D2
        .BYTE   $00 $1C $01 $06 $FF

@_a2d7:                                                                 ;$A2D7
        .BYTE   $02 $18 $FF

@_a2da: ; sprite layouts                                                ;$A2DA

        .BYTE   $40 $42 $FF $FF $FF $FF
        .BYTE   $60 $62 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $44 $46 $FF $FF $FF $FF
        .BYTE   $64 $66 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $40 $42 $FF $FF $FF $FF
        .BYTE   $68 $6A $FF $FF $FF $FF
        .BYTE   $FF

@_a30b: .BYTE   $50 $52 $FF $FF $FF $FF                                 ;$A30B
        .BYTE   $70 $72 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $4C $4E $FF $FF $FF $FF
        .BYTE   $6C $6E $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $50 $52 $FF $FF $FF $FF
        .BYTE   $48 $4A $FF $FF $FF $FF
        .BYTE   $FF
        ;

unknown_a33c_process:                                                   ;$A33C
;===============================================================================
; mob: UNKNOWN (ball from Ball Hog?)
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        res     5,      [IX+Mob.flags]                      ;mob adheres to the floor
        ld      [IX+Mob.width],     $0A
        ld      [IX+Mob.height],    $0F
        ld      HL,     $0101
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        bit     7,      [IX+Mob.flags]
        jr      z,      @_1

        ld      [IX+Mob.Yspeed+0],  $00
        ld      [IX+Mob.Yspeed+1],  $FD
        ld      [IX+Mob.Ydirection],        $FF
@_1:    ld      L,       [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $001F
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Yspeed+0],  L
        ld      [IX+Mob.Yspeed+1],  H
        ld      [IX+Mob.Ydirection],        A
        ld      A,      [IX+Mob.unknown11]
        cp      $82
        jr      nc,     @_2

        ld      BC,     @_a3b1
        ld      DE,     @_a3bb
        call    animateMob
        jp      @_4

@_2:    jr      nz,     @_3
        ld      [IX+Mob.unknown16], $00

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

@_3:    ld      BC,     @_a3b4
        ld      DE,     @_a3bb
        call    animateMob
@_4:    inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $A5
        ret     c

        ld      [IX+Mob.type],      $FF                     ;remove mob?
        ret

@_a3b1:                                                                 ;$A3B1
        .BYTE   $00 $08 $FF

@_a3b4:                                                                 ;$A3B4
        .BYTE   $01 $0C $02 $0C $03 $0C $FF

        ;sprite layout
@_a3bb:                                                                 ;$A3BB
        .BYTE   $20 $22 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $74 $76 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $78 $7A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $7C $7E $FF $FF $FF $FF
        .BYTE   $FF
        ;

door_switch_process:                                                    ;$A3F8
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     $0A
        ld      [IX+Mob.height],    $11

        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H

        set     0,      [IX+Mob.flags]

@_1:    ld      HL,     $0001
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_3

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_3

        ld      [IX+Mob.spriteLayout+0],    <@_a48b
        ld      [IX+Mob.spriteLayout+1],    >@_a48b
        ld      A,      [RAM_LEVEL_SOLIDITY]
        cp      $03
        jr      nz,     @_2

        ld      [IX+Mob.spriteLayout+0],    <@_a49b
        ld      [IX+Mob.spriteLayout+1],    >@_a49b

@_2:    ld      BC,     $0006
        ld      DE,     $0000
        call    _LABEL_7CC1_12

        bit     1,      [IX+Mob.flags]
        jr      nz,     @_4

        set     1,      [IX+Mob.flags]
        ld      HL,     RAM_D317
        call    getLevelBitFlag
        ld      A,      [HL]
        xor     C
        ld      [HL],   A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_1A
                rst     $28     ;=rst_playSFX
        .ENDIF

        jr      @_4

        ;-------------------------------------------------------------------------------------------

@_3:    res     1,      [IX+Mob.flags]
        ld      [IX+Mob.spriteLayout+0],    <@_a493
        ld      [IX+Mob.spriteLayout+1],    >@_a493
        ld      A,      [RAM_LEVEL_SOLIDITY]
        cp      $03
        jr      nz,     @_4

        ld      [IX+Mob.spriteLayout+0],    <@_a4a3 ;TODO: invalid address??
        ld      [IX+Mob.spriteLayout+1],    >@_a4a3

@_4:    xor     A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  $02
        ld      [IX+Mob.Ydirection],        A
        ret

        ;sprite layout
@_a48b:                                                                 ;$A48B
        .BYTE   $1A $1C $FF $FF $FF $FF
        .BYTE   $FF $FF

@_a493:                                                                 ;$A493
        .BYTE   $3A $3C $FF $FF $FF $FF
        .BYTE   $FF $FF

@_a49b:                                                                 ;$A49B
        .BYTE   $38 $3A $FF $FF $FF $FF
        .BYTE   $FF $FF

@_a4a3:
        .BYTE   $34 $36 $FF $FF $FF $FF
        .BYTE   $FF $FF
        ;

door_switching_process:                                                 ;$A4AB
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        call    _9ed4

        ld      A,      [IX+Mob.unknown11]
        cp      $28
        jr      nc,     @_2

        ld      HL,     $0005
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      DE,     $0005
        ld      A,      [RAM_SONIC.Xdirection]
        and     A
        jp      m,      @_1

        ld      DE,     $FFEC
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ld      [RAM_SONIC.X],      HL

        xor     A
        ld      [RAM_SONIC.Xspeed+0],       A
        ld      [RAM_SONIC.Xspeed+1],       A
        ld      [RAM_SONIC.Xdirection],     A

        ;-----------------------------------------------------------------------

@_2:    ld      HL,     RAM_D317
        call    getLevelBitFlag
        bit     1,      [IX+Mob.flags]
        jr      z,      @_3
        ld      A,      [HL]
        and     c
        jr      nz,     @_5
        jr      @_4

@_3:    ld      A,       [HL]
        and     C
        jr      z,      @_5

@_4:    ld      A,       [IX+Mob.unknown11]
        cp      $30
        jr      nc,     @_6

        inc     A
        inc     A
        ld      [IX+Mob.unknown11], A
        jr      @_6

@_5:    ld      A,       [IX+Mob.unknown11]
        and     A
        jr      z,      @_6

        dec     A
        dec     A
        ld      [IX+Mob.unknown11], A
@_6:    ld      DE,     @_a51a
        jp      mob_door_left@_9e7e

        ;sprite layout
@_a51a:                                                                 ;$A51A
        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $38 $FF $FF $FF $FF $FF
        .BYTE   $3E $FF $FF $FF $FF $FF

        .BYTE   $38 $FF $FF $FF $FF $FF
        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $3E $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF
        ;

badnick_caterkiller_process:                                            ;$A551
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     6
        ld      [IX+Mob.height],    16

        ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        jr      nz,     @_5

        ld      HL,     @_a6b9

        bit     1,      [IX+Mob.flags]
        jr      z,      @_1

        ld      HL,     @_a769
@_1:    ld      E,       [IX+Mob.unknown11]
        sla     E
        ld      D,      $00
        add     HL,     DE
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        ld      L,      [IX+Mob.Xsubpixel]
        ld      H,      [IX+Mob.X+0]
        ld      A,      [IX+Mob.X+1]
        add     HL,     BC
        bit     7,      B
        jr      z,      @_2

        adc     A,      $FF
        jr      @_3

@_2:    adc     A,      $00
@_3:    ld      [IX+Mob.Xsubpixel],     L
        ld      [IX+Mob.X+0],       H
        ld      [IX+Mob.X+1],       A
        ld      HL,     @_a6e5
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        ld      L,      [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        add     HL,     DE
        ld      [IX+Mob.unknown12], L
        ld      [IX+Mob.unknown13], H
        ld      C,      $00
        bit     7,      H
        jr      z,      @_4

        ld      C,      $FF
@_4:    ld      [IX+Mob.unknown14],     C
@_5:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        bit     1,      [IX+Mob.flags]
        jr      nz,     @_7

        ld      HL,     @_a711
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        add     HL,     DE

        ld      A,      $24
        call    @_a688

        ld      A,      $26
        call    @_a6a2

        ld      A,      $26
        call    @_a688

        ld      A,      $26
        call    @_a6a2

        ld      [IX+Mob.width],     $06
        ld      HL,     $0802
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        ld      HL,     $0000
        ld      [RAM_TEMP1],        HL
        jr      c,      @_6

        call    hitPlayer
        jr      @_9

@_6:    ld      [IX+Mob.width], $16
        ld      HL,     $0806
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd
        jr      @_9

@_7:    ld      HL,     @_a795
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        add     HL,     DE

        ld      A,      $2A
        call    @_a688

        ld      A,      $28
        call    @_a6a2

        ld      A,      $28
        call    @_a688

        ld      A,      $28
        call    @_a6a2

        ld      [IX+Mob.width],     $10
        ld      HL,     $0401
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        jr      c,      @_8

        call    hitPlayer@_35fd
        jr      @_9

@_8:    ld      [IX+Mob.width], $16
        ld      HL,     $0410
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        ld      HL,     $0000
        ld      [RAM_TEMP1],        HL
        call    nc,     hitPlayer

@_9:    ld      [IX+Mob.Yspeed+1],      $01
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000001
        ret     nz

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $16
        ret     c

        ld      [IX+Mob.unknown11], $00
        inc     [IX+Mob.unknown15]
        ld      A,      [IX+Mob.unknown15]
        cp      $14
        ret     c

        ld      [IX+Mob.unknown15], $00
        ld      A,      [IX+Mob.flags]
        xor     $02
        ld      [IX+Mob.flags],     A
        ret

        ;===============================================================================================================

@_a688:                                                                 ;$A688
        push    HL
        ld      E,      [HL]
        ld      D,      $00
        ld      [RAM_TEMP4],        DE
        ld      L,      [IX+Mob.unknown13]
        ld      H,      [IX+Mob.unknown14]
        ld      [RAM_TEMP6],        HL
        call    _3581
        pop     HL
        ld      DE,     $0016
        add     HL,     DE
        ret

        ;===============================================================================================================

@_a6a2:                                                                 ;$A6A2
        push    HL
        ld      E,      [HL]
        ld      D,      $00
        ld      [RAM_TEMP4],        DE
        ld      HL,     $0000
        ld      [RAM_TEMP6],        HL
        call    _3581
        pop     HL
        ld      DE,     $0016
        add     HL,     DE
        ret

@_a6b9:                                                                 ;$A6B9
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $E0 $FF $E0 $FF $E0 $FF $E0 $FF $C0 $FF
        .BYTE   $C0 $FF $80 $FF $80 $FF $00 $FF $00 $FF $00 $FE

@_a6e5:                                                                 ;$A6E5
        .BYTE   $00 $FF $80 $FF $80 $FF $C0 $FF $C0 $FF $E0 $FF $E0 $FF $F0 $FF
        .BYTE   $F0 $FF $F0 $FF $F0 $FF $10 $00 $10 $00 $10 $00 $10 $00 $20 $00
        .BYTE   $20 $00 $40 $00 $40 $00 $80 $00 $80 $00 $00 $01

@_a711:                                                                 ;$A711
        .BYTE   $00 $01 $02 $02 $03 $03 $03 $03 $03 $03 $03 $03 $03 $03 $03 $03
        .BYTE   $03 $03 $02 $02 $01 $00 $07 $07 $07 $07 $07 $07 $07 $07 $07 $07
        .BYTE   $07 $07 $07 $07 $07 $07 $07 $07 $07 $07 $07 $07 $0E $0D $0C $0C
        .BYTE   $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0C $0C
        .BYTE   $0D $0E $15 $13 $12 $11 $10 $10 $0F $0F $0F $0F $0F $0F $0F $0F
        .BYTE   $0F $0F $10 $10 $11 $12 $13 $15

@_a769:                                                                 ;$A769
        .BYTE   $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $20 $00 $20 $00 $20 $00 $20 $00 $40 $00
        .BYTE   $40 $00 $80 $00 $80 $00 $00 $01 $00 $01 $00 $02

@_a795:                                                                 ;$A795
        .BYTE   $15 $14 $13 $13 $12 $12 $12 $12 $12 $12 $12 $12 $12 $12 $12 $12
        .BYTE   $12 $12 $13 $13 $14 $15 $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E
        .BYTE   $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E $07 $08 $09 $09
        .BYTE   $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $09 $09
        .BYTE   $08 $07 $00 $02 $03 $04 $05 $05 $06 $06 $06 $06 $06 $06 $06 $06
        .BYTE   $06 $06 $05 $05 $04 $03 $02 $00
        ;

boss_scrapBrain_process:                                                ;$A7ED
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],     $1E
        ld      [IX+Mob.height],    $2F
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      HL,     $0340
        ld      [RAM_LEVEL_LEFT],   HL

        ;lock the screen at 1344 pixels, 42 blocks
        ;(near the boss lift in Scrap Brain Act 3)
        ld      HL,     $0540
        ld      [RAM_LEVEL_RIGHT],  HL

        ld      HL,     [RAM_CAMERA_Y]
        ld      [RAM_LEVEL_TOP],    HL
        ld      [RAM_LEVEL_BOTTOM], HL
        ld      HL,     $0220
        ld      [RAM_CAMERA_Y_GOTO],        HL

        ;UNKNOWN
        ld      HL,     $EF3F
        ld      DE,     $2000
        ld      A,      12
        call    decompressArt

        ld      HL,     bossPalette
        ld      A,      %00000010
        call    loadPaletteOnInterrupt

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_BOSS1
                rst     $18     ;=rst_playMusic
        .ENDIF

        set     0,      [IX+Mob.flags]
@_1:    bit     1,      [IX+Mob.flags]
        jr      nz,     @_4

        ld      HL,     [RAM_CAMERA_X]
        ld      [RAM_LEVEL_LEFT],   HL
        ld      DE,     _baf9
        ld      BC,     @_a9b7
        call    animateMob

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     [RAM_SONIC.X]
        xor     A
        sbc     HL,     DE
        ld      DE,     $0040
        xor     A
        ld      BC,     [RAM_SONIC.Xspeed]
        bit     7,      B
        jr      nz,     @_2

        sbc     HL,     DE
        jr      c,      @_3

@_2:    ld      BC,     $FF80
@_3:    inc     B
        ld      [IX+Mob.Xspeed+0],  C
        ld      [IX+Mob.Xspeed+1],  B
        ld      [IX+Mob.Xdirection],        A
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $05A0
        xor     A
        sbc     HL,     DE
        jp      c,      @_9

        ld      L,      A
        ld      H,      A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [RAM_SONIC.Xspeed], HL
        ld      [RAM_SONIC.Xdirection],     A
        set     1,      [IX+Mob.flags]
        jp      @_9

@_4:    bit     2,      [IX+Mob.flags]
        jr      nz,     @_5

        ld      HL,     $0530
        ld      DE,     $0220
        call    _7c8c

        ld      [IY+Vars.joypad],  $FF
        ld      HL,     $05A0
        ld      [IX+Mob.Xsubpixel], $00
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.spriteLayout+0],    <_baf9
        ld      [IX+Mob.spriteLayout+1],    >_baf9
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $C0
        jp      c,      @_9

        set     2,      [IX+Mob.flags]
        jp      @_9

@_5:    bit     3, [IX+Mob.flags]
        jr      nz,     @_6

        ld      [IY+Vars.joypad],  $FF
        xor     A
        ld      [IX+Mob.spriteLayout+0],    A
        ld      [IX+Mob.spriteLayout+1],    A
        dec     [IX+Mob.unknown11]
        jp      nz,     @_9
        set     3,      [IX+Mob.flags]
        jp      @_9

@_6:    bit     4,      [IX+Mob.flags]                      ;mob underwater?
        jr      nz,     @_8

        ld      DE,     [RAM_SONIC.X]
        ld      HL,     $0596
        and     A
        sbc     HL,     DE
        jr      nc,     @_9

        ld      HL,     $05C0
        xor     A
        sbc     HL,     DE
        jr      c,      @_9

        or      [IX+Mob.unknown11]
        jr      nz,     @_7

        ld      HL,     [RAM_SONIC.Y]
        ld      DE,     $028D
        xor     A
        sbc     HL,     DE
        jr      c,      @_9

        ld      L, A
        ld      H, A
        ld      [RAM_SONIC.Xspeed], HL
        ld      [RAM_SONIC.Xdirection],     A
@_7:    ld      A,      $80
        ld      [RAM_SONIC.flags],  A
        ld      HL,     $05A0
        ld      [RAM_SONIC.X],      HL

        ld      [IY+Vars.joypad],  $FF
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        ld      HL,     $028E
        xor     A                                          ;set A to 0
        sbc     HL,     DE
        ld      [RAM_SONIC.Ysubpixel],      A
        ld      [RAM_SONIC.Y],      HL
        ld      A,      [RAM_D2E8]
        ld      HL,     [RAM_D2E6]
        ld      [RAM_SONIC.Yspeed], HL
        ld      [RAM_SONIC.Ydirection],     A
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $C0
        jr      nz,     @_9

        ld      HL,     [RAM_CAMERA_X]
        inc     H
        ld      [RAM_SONIC.X],      HL
        set     4,      [IX+Mob.flags]                      ;set mob underwater

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_ACTCOMPLETE
                rst     $18     ;=rst_playMusic
        .ENDIF

        ld      A,      $A0
        ld      [RAM_D289], A
        set     1,      [IY+Vars.flags6]
        ret

@_8:    ld      A,       [IX+Mob.unknown11]
        and     A
        jr      z,      @_9

        dec     [IX+Mob.unknown11]
@_9:    ld      E,       [IX+Mob.unknown11]
        ld      D,      $00
        ld      HL,     $0280
        xor     A
        sbc     HL,     DE
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        ld      HL,     $02AF
        and     A
        sbc     HL,     DE
        ld      BC,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     BC
        ex      DE,     HL
        ld      HL,     $05A0
        ld      BC,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     BC
        ld      BC,     @_a9c0                                  ;address of sprite layout
        call    processSpriteLayout
        ld      A,      [IX+Mob.unknown11]
        and     %00011111
        cp      $0F
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_19
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

@_a9b7:                                                                 ;$A9B7
        .BYTE   $03 $08 $04 $07 $05 $08 $04 $07 $FF

        ; sprite layout
@_a9c0:                                                                 ;$A9C0
        .BYTE   $74 $76 $76 $78 $FF $FF
        .BYTE   $FF
        ;

meta_clouds_process:                                                    ;$A9C7
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      A,      [IY+Vars.spriteUpdateCount]
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        push    AF
        push    HL
        ld      A,      [RAM_D2DE]
        cp      $24
        jr      nc,     @_1

        ld      E,      A
        ld      D,      $00
        ld      HL,     RAM_SPRITETABLE
        add     HL,     DE
        ld      [RAM_SPRITETABLE_ADDR],     HL
        ld      A,      [RAM_D2A3]
        ld      C,      A
        ld      DE,     [RAM_D2A1]
        ld      L,      [IX+Mob.Ysubpixel]
        ld      H,      [IX+Mob.Y+0]
        ld      A,      [IX+Mob.Y+1]
        add     HL,     DE
        adc     A,      C
        ld      L,      H
        ld      H,      A
        ld      BC,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     BC
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      BC,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     BC
        ld      BC,     @_aa63                                  ;address of sprite layout
        call    processSpriteLayout

        ld      A,      [RAM_D2DE]
        add     A,      $0C
        ld      [RAM_D2DE], A

@_1:    pop     HL
        pop     AF
        ld      [RAM_SPRITETABLE_ADDR],     HL
        ld      [IY+Vars.spriteUpdateCount],       A
        ld      HL,     [RAM_CAMERA_X]
        ld      DE,     $FFE0
        add     HL,     DE
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        jr      nc,     @_2

        call    _0625
        ld      B,      $00
        add     A,      A
        ld      C,      A
        rl      B
        ld      HL,     [RAM_CAMERA_X]
        ld      DE,     $01B4
        add     HL,     DE
        add     HL,     BC
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
@_2:    ld      [IX+Mob.Xspeed+0],      $00
        ld      [IX+Mob.Xspeed+1],      $FD
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.spriteLayout+0],    $00
        ld      [IX+Mob.spriteLayout+1],    $00
        ret

        ;sprite layout
@_aa63:                                                                 ;$AA63
        .BYTE   $40 $42 $44 $46 $FF $FF
        .BYTE   $FF
        ;

trap_propeller_process:                                                 ;$AA6A
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     $05
        ld      [IX+Mob.height],    $14
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $000f
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFFA
        add     HL,     DE
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        set     0,      [IX+Mob.flags]
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        ld      HL,     @_ab01
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        ld      B,      $02

@loop:  push    BC
        ld      A,      [DE]
        ld      L,      A
        ld      H,      $00
        ld      [RAM_TEMP4],        HL
        inc     DE
        ld      A,      [DE]
        ld      L,      A
        ld      [RAM_TEMP6],        HL
        inc     DE
        ld      A,      [DE]
        inc     DE
        and     A
        jp      m,      @_2
        push    DE
        call    _3581
        pop     DE
@_2:    pop     BC
        djnz    @loop

        ld      HL,     $0202
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      [IX+Mob.spriteLayout+0],    $00
        ld      [IX+Mob.spriteLayout+1],    $00
        ld      A,      [IX+Mob.unknown11]
        inc     A
        inc     A
        cp      $08
        ld      [IX+Mob.unknown11], A
        ret     c

        ld      [IX+Mob.unknown11],$00
        ret

@_ab01:                                                                 ;$AB01
        .BYTE   $09 $AB $0F $AB $15 $AB $1B $AB $00 $00 $1C $00 $18 $3C $00 $00
        .BYTE   $1E $00 $18 $3E $00 $00 $38 $00 $18 $3A $00 $08 $1A $00 $00 $FF
        ;

mob_badnick_bomb:                                                       ;$AB21
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],$0c
        ld      [IX+Mob.height],$10
        ld      A,      [IX+Mob.unknown11]
        cp      $64
        jr      nc,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FFC8
        add     HL,     DE
        ex      DE,     HL
        ld      HL,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      c,      @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $002C
        add     HL,     DE
        ex      DE,     HL
        ld      HL,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      nc,     @_1

        ld      [IX+Mob.unknown11], $64
@_1:    ld      A,       [IX+Mob.unknown11]
        cp      $1E
        jr      nc,     @_2

        ld      [IX+Mob.Xspeed+0],  $F8
        ld      [IX+Mob.Xspeed+1],  $FF
        ld      [IX+Mob.Xdirection],        $FF
        ld      DE,     _ad0b
        ld      BC,     _acf1
        call    animateMob
        jp      @_7

@_2:    ld      A,       [IX+Mob.unknown11]
        cp      $64
        jp      c,      @_4

        ld      [IX+Mob.Xspeed+0],  $00
        ld      [IX+Mob.Xspeed+1],  $00
        ld      [IX+Mob.Xdirection],        $00
        cp      $66
        jr      nc,     @_3

        ld      DE,     _ad0b
        ld      BC,     _ad01
        call    animateMob
        jp      @_7

@_3:    ld      [IX+Mob.spriteLayout+0],        <_ad53
        ld      [IX+Mob.spriteLayout+1],        >_ad53
        cp      $67
        jp      nz,     @_7

        ld      HL,     $FFFE
        ld      [RAM_TEMP4],        HL
        ld      HL,     $FFFC
        ld      [RAM_TEMP6],        HL
        call    findEmptyMob
        jp      c,      @_8

        ld      DE,     $0000
        ld      C,      E
        ld      B,      D
        call    _ac96
        ld      HL,     $0003
        ld      [RAM_TEMP4],        HL
        ld      HL,     $FFFC
        ld      [RAM_TEMP6],        HL
        call    findEmptyMob
        jp      c,      @_8


        ld      DE,     $0008
        ld      BC,     $0000
        call    _ac96

        ld      HL,     $FFFE
        ld      [RAM_TEMP4],        HL
        ld      HL,     $FFFE
        ld      [RAM_TEMP6],        HL
        call    findEmptyMob
        jp      c,      @_8

        ld      DE,     $0000
        ld      BC,     $0008
        call    _ac96

        ld      HL,     $0003
        ld      [RAM_TEMP4],        HL
        ld      HL,     $FFFE
        ld      [RAM_TEMP6],        HL
        call    findEmptyMob
        jp      c,      @_8

        ld      DE,     $0008
        ld      BC,     $0008
        call    _ac96

        ld      [IX+Mob.type],      $FF                     ;remove mob?

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_1B
                rst     $28     ;=rst_playSFX
        .ENDIF

        jr      @_8

        ;-----------------------------------------------------------------------

@_4:    cp      $23
        jr      nc,     @_5

        xor     A
        ld      [IX+Mob.Xspeed+0],  A
        ld      [IX+Mob.Xspeed+1],  A
        ld      [IX+Mob.Xdirection],        A
        ld      DE,     _ad0b
        ld      BC,     _acf6
        call    animateMob
        jr      @_7

@_5:    ld      A,       [IX+Mob.unknown11]
        cp      $41
        jr      nc,     @_6

        ld      [IX+Mob.Xspeed+0],  $08
        ld      [IX+Mob.Xspeed+1],  $00
        ld      [IX+Mob.Xdirection],        $00
        ld      DE,     _ad0b
        ld      BC,     _acf9
        call    animateMob
        jr      @_7

@_6:    ld      [IX+Mob.Xspeed+0],      $00
        ld      [IX+Mob.Xspeed+1],      $00
        ld      [IX+Mob.Xdirection],    $00
        ld      DE,     _ad0b
        ld      BC,     _acfe
        call    animateMob

@_7:    ld      [IX+Mob.Yspeed+0],      $80
        ld      [IX+Mob.Yspeed+1],      $00
        ld      [IX+Mob.Ydirection],    $00
@_8:    ld      HL,             $0202
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      A,      [RAM_FRAMECOUNT]
        and     $3F
        ret     nz

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $46
        ret     nz

        ld      [IX+Mob.unknown11], $00
        ret
        ;

_ac96:                                                                  ;$AC96
;===============================================================================
; crabmeat and bomb use this -- must be the spray shots
;
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        push    IX
        push    HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ex      DE,     HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     BC
        ld      C,      L
        ld      B,      H
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $0D                     ;unknown mob
        ld      [IX+Mob.Xsubpixel], A
        ld      [IX+Mob.X+0],       E
        ld      [IX+Mob.X+1],       D
        ld      [IX+Mob.Ysubpixel], A
        ld      [IX+Mob.Y+0],       C
        ld      [IX+Mob.Y+1],       B
        ld      [IX+Mob.unknown11], A
        ld      [IX+Mob.unknown13], $24
        ld      [IX+Mob.unknown14], A
        ld      [IX+Mob.unknown15], A
        ld      [IX+Mob.unknown16], A
        ld      [IX+Mob.unknown17], A
        ld      [IX+Mob.Xspeed+0],  A

        ld      HL,     [RAM_TEMP4]
        ld      [IX+Mob.Xspeed+1],  L
        ld      [IX+Mob.Xdirection],        H
        ld      [IX+Mob.Yspeed+0],  A

        ld      HL,     [RAM_TEMP6]
        ld      [IX+Mob.Yspeed+1],  L
        ld      [IX+Mob.Ydirection],        H

        pop     IX
        ret
        ;

_acf1:                                                                  ;$ACF1
;===============================================================================
        .BYTE   $00 $20 $01 $20 $FF
        ;

_acf6:                                                                  ;$ACF6
;===============================================================================
        .BYTE   $01 $20 $FF
        ;

_acf9:                                                                  ;$ACF9
;===============================================================================
        .BYTE   $02 $20 $03 $20 $FF
        ;

_acfe:                                                                  ;$ACFE
;===============================================================================
        .BYTE   $03 $20 $FF
        ;

_ad01:                                                                  ;$AD01
;===============================================================================
        .BYTE   $01 $02 $04 $02 $FF
        .BYTE   $03 $02 $05 $02 $FF
        ;

;sprite layouts

_ad0b:                                                                  ;$AD0B
;===============================================================================

        .BYTE   $0A $0C $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $0E $10 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $2A $2C $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $2E $30 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        ;

_ad53:                                                                  ;$AD53
;===============================================================================

        .BYTE   $12 $14 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $32 $34 $FF $FF $FF $FF
        .BYTE   $FF
        ;

trap_cannon_process:                                                    ;$AD6C
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $FFFC
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        call    _0625
        ld      [IX+Mob.unknown11], A
        set     0,      [IX+Mob.flags]
@_1:    ld      A,       [IX+Mob.unknown11]
        cp      $64
        jr      nz,     @_2

        call    findEmptyMob
        jr      c,      @_2

        push    IX
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $34                     ;unknown object
        ld      [IX+Mob.Xsubpixel], A
        ld      HL,     $0004
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     $0010
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        pop     IX

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_1C
                rst     $28     ;=rst_playSFX
        .ENDIF

        ld      [IX+Mob.unknown12], $18
        ld      [IX+Mob.unknown16], $00
        ld      [IX+Mob.unknown17], $00
@_2:    ld      A,       [IX+Mob.unknown12]
        and     A
        jr      z,      @_3

        ld      DE,     @_ae04
        ld      BC,     @_adfd
        call    animateMob
        dec     [IX+Mob.unknown12]
        inc     [IX+Mob.unknown11]
        ret

@_3:    ld      [IX+Mob.spriteLayout+0],        A
        ld      [IX+Mob.spriteLayout+1],        A
        inc     [IX+Mob.unknown11]
        ret

@_adfd:                                                                 ;$ADFD
        .BYTE   $00 $08 $01 $08 $02 $08 $FF

@_ae04: ; sprite layout                                                 ;$AE04
        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $74 $76 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $78 $7A $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $7C $7E $FF $FF $FF $FF
        .BYTE   $FF
        ;

trap_cannonball_process:                                                ;$AE35
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                      ;mob does not collide with the floor
        ld      [IX+Mob.width],     12
        ld      [IX+Mob.height],    12
        ld      HL,     [RAM_CAMERA_X]
        ld      DE,     $0110
        add     HL,     DE
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        jr      nc,     @_1

        ld      [IX+Mob.type],      $FF                     ;remove object?
@_1:    ld      HL,     $0202
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        xor     A
        ld      [IX+Mob.Xspeed+0],  $80
        ld      [IX+Mob.Xspeed+1],  $02
        ld      [IX+Mob.Xdirection],        A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        ld      [IX+Mob.spriteLayout+0],    <@_ae81
        ld      [IX+Mob.spriteLayout+1],    >@_ae81
        ret

        ;sprite layout
@_ae81:                                                                 ;$AE81
        .BYTE   $02 $04 $FF $FF $FF $FF
        .BYTE   $FF
        ;

badnick_unidos_process:                                                 ;$AE88
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]                              ;mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1
        ld      [IX+Mob.unknown11], $00
        ld      [IX+Mob.unknown12], $2A
        ld      [IX+Mob.unknown13], $52
        ld      [IX+Mob.unknown14], $7C
        set     0,      [IX+Mob.flags]
@_1:    ld      L,       [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      c,      @_2

        ld      [IX+Mob.Xspeed+0],  $F8
        ld      [IX+Mob.Xspeed+1],  $FF
        ld      [IX+Mob.Xdirection],        $FF
        ld      [IX+Mob.spriteLayout+0],    <@_b0d5
        ld      [IX+Mob.spriteLayout+1],    >@_b0d5

        ;set speed + direction of shot?
        ld      HL,     $FF80
        ld      [RAM_D216], HL
        call    @_af98

        ld      [IX+Mob.unknown16], $01
        jr      @_3

        ;-----------------------------------------------------------------------

@_2:    ld      [IX+Mob.Xspeed+0],              $08
        ld      [IX+Mob.Xspeed+1],              $00
        ld      [IX+Mob.Xdirection],            $00
        ld      [IX+Mob.spriteLayout+0],        <@_b0e7
        ld      [IX+Mob.spriteLayout+1],        >@_b0e7

        ;set speed + direction of shot?
        ld      HL,     $0080
        ld      [RAM_D216], HL
        call    @_af98

        ld      [IX+Mob.unknown16],     $FF
@_3:    ld      [IX+Mob.width],         $1C
        ld      [IX+Mob.height],        $1C
        ld      HL,     $1212
        ld      [RAM_TEMP6],        HL
        call    detectCollisionWithSonic
        ld      HL,     $1010
        ld      [RAM_TEMP1],        HL
        call    nc,     hitPlayer

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],        HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],        HL
        push    IX
        pop     HL
        ld      DE,     $0011
        add     HL,     DE

        ld      B,      $04
@loop:  push    BC
        push    HL
        ld      A,      [HL]
        cp      $FE
        jr      z,      @_4

        and     %11111110
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_b031
        add     HL,     DE
        push    HL
        ld      E,      [HL]
        ld      [RAM_TEMP4],        DE
        inc     HL
        ld      E,      [HL]
        ld      [RAM_TEMP6],        DE
        ld      A,      $24
        call    _3581
        pop     HL
        ld      A,      [HL]
        inc     A
        inc     A
        ld      [RAM_TEMP6],        A
        add     A,      $04
        ld      [IX+Mob.width],     A
        inc     HL
        ld      A,      [HL]
        inc     A
        inc     A
        ld      [RAM_TEMP7],        A
        add     A,      $04
        ld      [IX+Mob.height],    A
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

@_4:    pop     HL
        pop     BC
        ld      A,      [HL]
        cp      $FE
        jr      z,      @_6

        add     A,      [IX+Mob.unknown16]
        cp      $FF
        jr      nz,     @_5

        ld      A,      $A3
        jr      @_6

        ;-----------------------------------------------------------------------

@_5:    cp      $A4
        jr      nz,     @_6

        xor     A

@_6:    ld      [HL],   A
        inc     HL
        djnz    @loop

        ld      A,      [RAM_FRAMECOUNT]
        and     %00000111
        ret     z
        ld      A,      [IX+Mob.unknown15]
        cp      $C8
        ret     nc
        inc     [IX+Mob.unknown15]
        ret

        ;===============================================================================================================

@_af98:                                                                 ;$AF98
        ld      A,      [IX+Mob.unknown15]
        cp      $C8
        ret     nz

        ld      A,      [RAM_LEVEL_SOLIDITY]
        cp      $03
        ret     nz

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFD0
        add     HL,     DE
        ld      DE,     [RAM_SONIC.Y]
        and     A
        sbc     HL,     DE
        ret     nc

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      BC,     $002C
        add     HL,     BC
        and     A
        sbc     HL,     DE
        ret     c

        push    IX
        pop     HL
        ld      DE,     $0011
        add     HL,     DE
        ld      B,      $04

@loop2: push    BC
        push    HL
        ld      A,      [HL]
        cp      $4A
        call    z,      @_afdb

        pop     HL
        pop     BC
        inc     HL
        djnz    @loop2

        ret

        ;===============================================================================================================

@_afdb:                                                                 ;$AFDB
        ld      [HL],   $FE
        call    findEmptyMob
        ret     c

        push    IX
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        push    HL
        pop     IX
        xor     A                                          ;set A to 0
        ld      [IX+Mob.type],      $36                     ;unknown mob
        ld      [IX+Mob.Xsubpixel], A
        ld      HL,     $0012
        add     HL,     DE
        ld      [IX+Mob.X+0],       L
        ld      [IX+Mob.X+1],       H
        ld      [IX+Mob.Ysubpixel], A
        ld      HL,     $001E
        add     HL,     BC
        ld      [IX+Mob.Y+0],       L
        ld      [IX+Mob.Y+1],       H
        ld      HL,     [RAM_D216]
        ld      [IX+Mob.Xspeed+0],  L
        ld      [IX+Mob.Xspeed+1],  H
        xor     A
        bit     7,      H
        jr      z,      @_7

        ld      A,      $FF
@_7:    ld      [IX+Mob.Xdirection],    A
        xor     A
        ld      [IX+Mob.Yspeed+0],  A
        ld      [IX+Mob.Yspeed+1],  A
        ld      [IX+Mob.Ydirection],        A
        pop     IX
        ret

@_b031:                                                                 ;$B031
        .BYTE   $0C $03 $0D $03 $0E $03 $0E $04 $0F $04 $10 $04 $10 $05 $11 $05
        .BYTE   $11 $06 $12 $06 $12 $07 $13 $07 $13 $08 $13 $09 $14 $09 $14 $0A
        .BYTE   $14 $0B $15 $0B $15 $0C $15 $0D $15 $0E $15 $0F $15 $10 $15 $11
        .BYTE   $14 $11 $14 $12 $14 $13 $13 $13 $13 $14 $13 $15 $12 $15 $12 $16
        .BYTE   $11 $16 $11 $17 $10 $17 $10 $18 $0F $18 $0E $18 $0E $19 $0D $19
        .BYTE   $0C $19 $0B $19 $0A $19 $09 $19 $09 $18 $08 $18 $07 $18 $07 $17
        .BYTE   $06 $17 $06 $16 $05 $16 $05 $15 $04 $15 $04 $14 $04 $13 $03 $13
        .BYTE   $03 $12 $03 $11 $02 $11 $02 $10 $02 $0F $02
                                                                        ;$B0AC
        .BYTE   $0E $02 $0D $02 $0C $02 $0B $03 $0B $03 $0A $03 $09 $04 $09 $04
        .BYTE   $08 $04 $07 $05 $07 $05 $06 $06 $06 $06 $05 $07 $05 $07 $04 $08
        .BYTE   $04 $09 $04 $09 $03 $0A $03 $0B $03

        ; sprite layout
@_b0d5:                                                                 ;$B0D5
        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $FE $26 $28 $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
@_b0e7:                                                                 ;$B0E7
        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $FE $20 $22 $FF $FF $FF
        .BYTE   $FF
        ;

unknown_b0f4_process:                                                   ;$B0F4
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        ld      [IX+Mob.spriteLayout+0],$00
        ld      [IX+Mob.spriteLayout+1],$00
        ld      [IX+Mob.width],         $04
        ld      [IX+Mob.height],        $0A
        ld      HL,     $0602
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ex      DE,     HL
        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $FFF0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_1

        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $0110
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_1

        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ex      DE,     HL
        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $FFF0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_1

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $00D0
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      c,      @_1

        ld      HL,     $0000
        ld      [RAM_TEMP4],    HL
        ld      [RAM_TEMP6],    HL
        ld      A,      $24
        call    _3581
        ret

@_1:    ld      [IX+Mob.type],  $FF     ; remove mob?
        ret
        ;

trap_turretRotating_process:                                            ;$B16C
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        call    _0625
        and     %00000111
        ld      [IX+Mob.unknown11],     A
        set     0,      [IX+Mob.flags]
@_1:    ld      [IX+Mob.spriteLayout+0],        $00
        ld      [IX+Mob.spriteLayout+1],        $00
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      A,      [IX+Mob.unknown11]
        add     A,      A
        add     A,      A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_b227
        add     HL,     DE
        ld      B,      $02

@loop:  push    BC
        ld      D,      $00
        ld      E,      [HL]
        bit     7,      E
        jr      z,      @_2

        ld      D,      $FF
@_2:    ld      [RAM_TEMP4],    DE
        inc     HL
        ld      D,      $00
        ld      E,      [HL]
        bit     7,      E
        jr      z,      @_3

        ld      D,      $FF
@_3:    ld      [RAM_TEMP6],    DE
        inc     HL
        ld      A,      [HL]
        inc     HL
        inc     HL
        cp      $FF
        jr      z,      @_4

        push    HL
        call    _3581
        pop     HL
@_4:    pop     BC
        djnz    @loop

        ld      A,      [RAM_FRAMECOUNT]
        and     $3F
        jr      nz,     @_5

        ld      A,      [IX+Mob.unknown11]
        inc     A
        and     %00000111
        ld      [IX+Mob.unknown11],     A
@_5:    inc     [IX+Mob.unknown12]
        ld      A,      [IX+Mob.unknown12]
        cp      $1A
        ret     nz

        ld      [IX+Mob.unknown12],     $00
        ld      A,      [IX+Mob.unknown11]
        add     A,      A
        ld      E,      A
        add     A,      A
        add     A,      E
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_b267
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_TEMP4],    DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        ld      [RAM_TEMP6],    DE
        inc     HL
        ld      E,      [HL]
        ld      D,      $00
        bit     7,      E
        jr      z,      @_6

        dec     D
@_6:    inc     HL
        ld      C,      [HL]
        ld      B,      $00
        bit     7,      C
        jr      z,      @_7

        dec     B
@_7:    call    _b5c2
        ret

@_b227:                                                                 ;$B227
        .BYTE   $08 $F8 $66 $00 $00 $00 $FF $00 $0C $FA $70 $00 $14 $FA $72 $00
        .BYTE   $0F $07 $4C $00 $17 $07 $4E $00 $0D $0C $6C $00 $15 $0C $6E $00
        .BYTE   $08 $0F $64 $00 $00 $00 $FF $00 $FC $0C $68 $00 $04 $0C $6A $00
        .BYTE   $F9 $07 $48 $00 $01 $07 $4A $00 $FB $F9 $50 $00 $03 $F9 $52 $00

@_b267:                                                                 ;$B267
        .BYTE   $00 $00 $00 $FE $08 $F0 $00 $01 $00 $FF $18 $F8 $00 $02 $00 $00
        .BYTE   $1E $07 $00 $01 $00 $01 $16 $16 $00 $00 $00 $02 $08 $20 $00 $FF
        .BYTE   $00 $01 $F8 $18 $00 $FE $00 $00 $F2 $07 $00 $FF $00 $FF $F7 $F6
        ;

platform_flyingRight_process:                                           ;$B297
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      A,      [IX+Mob.Ysubpixel]
        ld      [IX+Mob.unknown12],     A

        ld      A,      [IX+Mob.Y+0]
        ld      [IX+Mob.unknown13],     A

        ld      A,      [IX+Mob.Y+1]
        ld      [IX+Mob.unknown14],     A

        set     0,      [IX+Mob.flags]

@_1:    ld      A,      [RAM_D2A3]
        ld      C,      A
        ld      DE,     [RAM_D2A1]
        ld      L,      [IX+Mob.unknown12]
        ld      H,      [IX+Mob.unknown13]
        ld      A,      [IX+Mob.unknown14]
        add     HL,     DE
        adc     A,      C
        ld      [IX+Mob.Ysubpixel],     L
        ld      [IX+Mob.Y+0],           H
        ld      [IX+Mob.Y+1],           A

        ld      A,      [RAM_SONIC.Ydirection]
        and     A
        jp      m,      @_2

        ld      [IX+Mob.width],         $1E
        ld      [IX+Mob.height],        $10
        ld      HL,             $0A02
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_2

        ld      HL,     $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_TOP],          HL
        ld      HL,     $0030           ; TODO: not needed; HL is already $0030
        ld      [RAM_SCROLLZONE_OVERRIDE_BOTTOM],       HL

        ld      BC,     $0010
        ld      DE,     $0000
        call    _LABEL_7CC1_12
        ld      L,      [IX+Mob.Xsubpixel]
        ld      H,      [IX+Mob.X+0]
        ld      A,      [IX+Mob.X+1]
        ld      DE,     $0080
        add     HL,     DE
        adc     A,      $00
        ld      [IX+Mob.Xsubpixel],     L
        ld      [IX+Mob.X+0],           H
        ld      [IX+Mob.X+1],           A
        ld      HL,     [RAM_SONIC.Xsubpixel]
        ld      A,      [RAM_SONIC.X+1]
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_SONIC.Xsubpixel],  HL
        ld      [RAM_SONIC.X+1],        A
@_2:    ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      HL,     $FFF8
        ld      [RAM_TEMP4],    HL
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        ld      HL,     @_b388
        add     HL,     DE
        ld      B,      $02

@loop:  push    BC
        ld      E,      [HL]
        ld      D,      $00
        inc     HL
        ld      [RAM_TEMP6],    DE
        ld      A,      [HL]
        inc     HL
        cp      $FF
        jr      z,      @_3

        push    HL
        call    _3581
        pop     HL
@_3:    pop     BC
        djnz    @loop

        ld      [IX+Mob.spriteLayout+0],        <@_b37b
        ld      [IX+Mob.spriteLayout+1],        >@_b37b
        ld      A,      [IX+Mob.unknown11]
        add     A,      $04
        ld      [IX+Mob.unknown11],     A
        cp      $10
        ret     c

        ld      [IX+Mob.unknown11],     $00
        ret

        ; sprite layout
@_b37b:                                                                 ;$B37B
        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $36 $36 $36 $36 $FF $FF
        .BYTE   $FF

@_b388:                                                                 ;$B388
        .BYTE   $08 $1C $18 $3C $08 $1E $18 $3E $08 $38 $18 $3A $0C $1A $00 $FF
        ;

trap_spikewall_process:                                                 ;$B398
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      [IX+Mob.unknown11],     L
        ld      [IX+Mob.unknown12],     H
        set     0,      [IX+Mob.flags]
@_1:    ld      [IX+Mob.width],                 12
        ld      [IX+Mob.height],                46
        ld      [IX+Mob.spriteLayout+0],        <@_b45b
        ld      [IX+Mob.spriteLayout+1],        >@_b45b
        ld      HL,     $0202
        ld      [RAM_TEMP6],    HL

        call    detectCollisionWithSonic
        call    nc,     hitPlayer@_35fd

        ld      L,      [IX+Mob.Xsubpixel]
        ld      H,      [IX+Mob.X+0]
        ld      A,      [IX+Mob.X+1]
        ld      DE,     $0080
        add     HL,     DE
        adc     A,      $00
        ld      L,      H
        ld      H,      A
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      [RAM_TEMP3],    HL
        ld      HL,     $0000
        ld      [RAM_TEMP4],    HL
        ld      HL,     $FFF0
        ld      [RAM_TEMP6],    HL
        ld      A,      $16
        call    _3581
        ld      HL,     $0008
        ld      [RAM_TEMP4],    HL
        ld      A,      $18
        call    _3581
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0580
        xor     A
        ld      [IX+Mob.Xspeed+0],      A
        ld      [IX+Mob.Xspeed+1],      A
        ld      [IX+Mob.Xdirection],    A
        sbc     HL,     DE
        ret     nc
        ld      C,      [IX+Mob.Y+0]
        ld      B,      [IX+Mob.Y+1]
        ld      HL,     $0040
        add     HL,     BC
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        jr      nc,     @_2

        ld      A,      [IX+Mob.unknown11]
        ld      [IX+Mob.X+0],   A
        ld      A,      [IX+Mob.unknown12]
        ld      [IX+Mob.X+1],   A
@_2:    ld      DE,     [RAM_SONIC.Y]
        ld      HL,     $FFE0
        add     HL,     BC
        xor     A
        sbc     HL,     DE
        ret     nc

        ld      HL,     $002C
        add     HL,     BC
        xor     A
        sbc     HL,     DE
        ret     c

        ld      [IX+Mob.Xspeed+0],      $80
        ld      [IX+Mob.Xspeed+1],      A
        ld      [IX+Mob.Xdirection],    A
        ret

        ; sprite layout
@_b45b: .BYTE   $16 $18 $FF $FF $FF $FF
        .BYTE   $16 $18 $FF $FF $FF $FF
        .BYTE   $16 $18 $FF $FF $FF $FF
        ;

trap_turretFixed_process:                                               ;$B46D
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      BC,     $0000
        ld      E,      C
        ld      D,      B
        call    getFloorLayoutRAMAddressForMob
        ld      A,      [HL]
        sub     $3C
        cp      $04
        ret     nc

        ld      [IX+Mob.unknown11],     A
        set     0,      [IX+Mob.flags]

@_1:    inc     [IX+Mob.unknown12]
        ld      A,      [IX+Mob.unknown12]
        bit     6,      A
        ret     nz

        and     $0F
        ret     nz

        ld      A,      [IX+Mob.unknown11]
        add     A,      A
        ld      E,      A
        add     A,      A
        add     A,      A
        add     A,      E
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_b4e6
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_TEMP4],    DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_TEMP6],    DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      C,      [HL]
        inc     HL
        ld      B,      [HL]
        inc     HL
        exx
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      HL,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        ld      A,      H
        exx
        cp      [HL]
        ret     nz

        inc     HL
        exx
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        ld      HL,     [RAM_SONIC.Y]
        and     A
        sbc     HL,     DE
        ld      A,      H
        exx
        cp      [HL]
        ret     nz

        call    _b5c2
        ret

@_b4e6: .BYTE   $80 $FE $80 $FE $00 $00 $F8 $FF $FF $FF $80 $01 $80 $FE $18 $00
        .BYTE   $F8 $FF $00 $FF $80 $FE $80 $01 $00 $00 $10 $00 $FF $00 $80 $01
        .BYTE   $80 $01 $18 $00 $10 $00 $00 $00
        ;

platform_flyingUpDown_process:                                          ;$B50E
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        ld      HL,     platform_flyingRight_process@_b37b
        ld      A,      [RAM_LEVEL_SOLIDITY]
        cp      $01
        jr      nz,     @_1

        ld      HL,     @_b5b5
@_1:    ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        ld      A,              $50
        ld      [RAM_D216],     A
        call    @_b53b
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $A0
        ret     c

        ld      [IX+Mob.unknown11],     $00
        ret

        ;-----------------------------------------------------------------------

@_b53b: ld      A,      [RAM_D216]                                      ;$B53B
        ld      L,      A
        ld      DE,     $0010
        ld      C,      $00
        ld      A,      [IX+Mob.unknown11]
        cp      L
        jr      c,      @_2

        dec     C
        ld      DE,     $FFF0
@_2:    ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        add     HL,     DE
        adc     A,      C
        ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    A
        ld      A,      H
        and     A
        jp      p,      @_3

        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        inc     HL
        ld      A,      H
        cp      $02
        jr      c,      @_4

        ld      [IX+Mob.Yspeed+0],      $00
        ld      [IX+Mob.Yspeed+1],      $FE
        ld      [IX+Mob.Ydirection],    $FF
        jr      @_4

@_3:    cp      $02
        jr      c,      @_4

        ld      [IX+Mob.Yspeed+0],      $00
        ld      [IX+Mob.Yspeed+1],      $02
        ld      [IX+Mob.Ydirection],    $00

@_4:    ld      A,      [RAM_SONIC.Ydirection]
        and     A
        ret     m

        ld      [IX+Mob.width],         $1E
        ld      [IX+Mob.height],        $1C
        ld      HL,             $0802
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        ret     c

        ld      E,      [IX+Mob.Yspeed+0]
        ld      D,      [IX+Mob.Yspeed+1]
        ld      BC,     $0010
        call    _LABEL_7CC1_12

        ret

        ; sprite layout
@_b5b5: .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $6C $6E $6C $6E $FF $FF
        .BYTE   $FF
        ;

_b5c2:                                                                  ;$B5C2
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        push    BC
        push    DE
        call    findEmptyMob
        pop     DE
        pop     BC
        ret     c

        push    IX
        push    HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        add     HL,     DE
        ex      DE,     HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        add     HL,     BC
        ld      C,      L
        ld      B,      H
        pop     IX
        xor     A                               ; set A to 0
        ld      [IX+Mob.type],          $0D     ; unknown mob?
        ld      [IX+Mob.Xsubpixel],     A
        ld      [IX+Mob.X+0],           E
        ld      [IX+Mob.X+1],           D
        ld      [IX+Mob.Ysubpixel],     A
        ld      [IX+Mob.Y+0],           C
        ld      [IX+Mob.Y+1],           B
        ld      [IX+Mob.unknown11],     A
        ld      [IX+Mob.unknown13],     A
        ld      [IX+Mob.unknown14],     A
        ld      [IX+Mob.unknown15],     A
        ld      [IX+Mob.unknown16],     A
        ld      [IX+Mob.unknown17],     A
        ld      HL,     [RAM_TEMP4]
        bit     7,      H
        jr      z,      @_1

        ld      A,      $FF
@_1:    ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    A
        xor     A
        ld      HL,     [RAM_TEMP6]
        bit     7,      H
        jr      z,      @_2

        ld      A,      $FF
@_2:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    A
        pop     IX

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret
        ;

boss_skyBase_process:                                                   ;$B634
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ld      [IX+Mob.width],         30
        ld      [IX+Mob.height],        47
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        bit     2,      [IX+Mob.flags]
        jp      nz,     @_b821

        call    _7ca6
        call    @_b7e6
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ld      HL,     $0350
        ld      DE,     $0120
        call    _7c8c

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $0008
        add     HL,     DE
        ld      [IX+Mob.X+0],           L
        ld      [IX+Mob.X+1],           H
        ld      [IX+Mob.unknown11],     L
        ld      [IX+Mob.unknown12],     H
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0010
        add     HL,     DE
        ld      [IX+Mob.Y+0],           L
        ld      [IX+Mob.Y+1],           H
        ld      [IX+Mob.unknown13],     L
        ld      [IX+Mob.unknown14],     H
        xor     A
        ld      [RAM_D2EC],     A

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_BOSS3
                rst     $18     ;=rst_playMusic
        .ENDIF

        set     4,      [IY+Vars.unknown0]
        set     0,      [IX+Mob.flags]
@_1:    ld      A,      [IX+Mob.unknown15]
        and     A
        jp      nz,     @_4

        call    @_b99f
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000111
        jp      nz,     @_8

        ld      A,      [IX+Mob.unknown16]
        cp      $1C
        jr      nc,     @_2

        inc     [IX+Mob.unknown17]
        ld      A,      [IX+Mob.unknown17]
        cp      $02
        jp      c,      @_3

@_2:    ld      [IX+Mob.unknown17],     $00
@_3:    inc     [IX+Mob.unknown16]
        ld      A,      [IX+Mob.unknown16]
        cp      $28
        jp      c,      @_8

        ld      [IX+Mob.unknown16],     $00
        inc     [IX+Mob.unknown15]
        jp      @_8

@_4:    dec     A
        jr      nz,     @_5

        ld      [IX+Mob.Yspeed+0],      $40
        ld      [IX+Mob.Yspeed+1],      $FE
        ld      [IX+Mob.Ydirection],    $FF
        inc     [IX+Mob.unknown15]
        ld      L,      [IX+Mob.unknown11]
        ld      H,      [IX+Mob.unknown12]
        ld      DE,     $0004
        add     HL,     DE
        ld      [IX+Mob.X+0],   L
        ld      [IX+Mob.X+1],   H
        ld      [IX+Mob.spriteLayout+0],<_bb1d
        ld      [IX+Mob.spriteLayout+1],>_bb1d
        jp      @_8

@_5:    dec     A
        jp      nz,     @_7
        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $000E
        add     HL,     DE
        adc     A,      $00
        ld      C,      A
        jp      m,      @_6

        ld      A,      H
        cp      $02
        jr      c,      @_6

        ld      HL,     $0200
@_6:    ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
        ld      [IX+Mob.spriteLayout+0],<_bb1d
        ld      [IX+Mob.spriteLayout+1],>_bb1d
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        dec     HL
        ld      E,      [IX+Mob.unknown13]
        ld      D,      [IX+Mob.unknown14]
        and     A
        sbc     HL,     DE
        jr      c,      @_8

        ld      [IX+Mob.Y+0],   E
        ld      [IX+Mob.Y+1],   D
        xor     A
        ld      [IX+Mob.unknown16],     A
        ld      [IX+Mob.Yspeed+0],      A
        ld      [IX+Mob.Yspeed+1],      A
        ld      [IX+Mob.Ydirection],    A
        inc     [IX+Mob.unknown15]
        jp      @_8

@_7:    dec     A
        jp      nz,     @_8
        ld      L,      [IX+Mob.unknown11]
        ld      H,      [IX+Mob.unknown12]
        ld      [IX+Mob.X+0],   L
        ld      [IX+Mob.X+1],   H
        ld      A,      [IX+Mob.unknown16]
        and     A
        call    z,      @_b9d5

        ld      [IX+Mob.unknown17],     $02
        set     1,      [IX+Mob.flags]
        call    @_b99f
        inc     [IX+Mob.unknown16]
        ld      A,      [IX+Mob.unknown16]
        cp      $12
        jr      c,      @_8

        res     1,      [IX+Mob.flags]
        xor     A
        ld      [IX+Mob.unknown15],     A
        ld      [IX+Mob.unknown16],     A

@_8:    ld      HL,     $ba31           ; TODO!
        bit     1,      [IX+Mob.flags]
        jr      z,      @_9

        ld      HL,     @_ba3b
@_9:    ld      DE,     RAM_TEMP1
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ld      A,      [HL]
        inc     HL
        push    HL
        call    _3581
        ld      HL,     [RAM_TEMP4]
        ld      DE,     $0008
        add     HL,     DE
        ld      [RAM_TEMP4],    HL
        pop     HL
        ld      A,      [HL]
        call    _3581
        ld      A,      [RAM_D2EC]
        cp      $0C
        ret     c

        xor     A
        ld      [IX+Mob.unknown11],     A
        ld      [IX+Mob.unknown16],     A
        ld      [IX+Mob.unknown17],     A
        set     2,      [IX+Mob.flags]
        res     4,      [IY+Vars.unknown0]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      MUSIC_ID_SCRAPBRAIN
                rst     $18     ;=rst_playMusic
                ld      A,      SFX_ID_21
                rst     $28     ;=rst_playSFX
        .ENDIF
        ret

        ;-----------------------------------------------------------------------

@_b7e6: ld      A,      [RAM_D2B1]                                      ;$B7E6
        and     A
        ret     nz
        bit     0,      [IY+Vars.scrollRingFlags]
        ret     nz
        ld      A,      [RAM_SONIC.flags]
        rrca
        jr      c,      @_10

        and     $02
        ret     z

@_10:   ld      HL,     [RAM_SONIC.X]
        ld      DE,     $0410
        and     A
        sbc     HL,     DE
        ret     c

        ld      HL,     $FD00
        ld      A,      $FF
        ld      [RAM_SONIC.Xspeed],     HL
        ld      [RAM_SONIC.Xdirection], A
        ld      HL,     RAM_D2B1
        ld      [HL],   $18
        inc     HL
        ld      [HL],   $0C
        inc     HL
        ld      [HL],   $3F

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

        ld      HL,     RAM_D2EC
        inc     [HL]
        ret

        ;-----------------------------------------------------------------------

@_b821: bit     3,      [IX+Mob.flags]                                  ;$B821
        jp      nz,     @_20

        res     5,      [IX+Mob.flags]  ; make mob adhere to the floor
        ld      A,      [IX+Mob.unknown11]
        cp      $0F
        jr      nc,     @_11

        add     A,      A
        add     A,      A
        ld      E,      A
        add     A,      A
        add     A,      E
        ld      E,      A
        ld      D,      $00
        ld      HL,     $BA45
        add     HL,     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_D2AB],     DE
        ld      E,      [HL]
        inc     HL
        ld      D,      [HL]
        inc     HL
        ld      [RAM_D2AD],     DE
        ld      [RAM_D2AF],     HL
        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $0F
        jr      nz,     @_11

        set     5,      [IY+Vars.flags0]
        res     1,      [IY+Vars.flags2]

        ; something to do with scrolling
        ld      HL,     $0550
        ld      [RAM_LEVEL_RIGHT],      HL

@_11:   ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      HL,     $05E0
        xor     A
        sbc     HL,     DE
        jr      nc,     @_12

        ld      C,      A
        ld      B,      A
        jp      @_15

@_12:   ex      DE,     HL
        ld      DE,     [RAM_SONIC.X]
        xor     A
        sbc     HL,     DE
        ld      DE,     $0040
        xor     A
        ld      BC,     [RAM_SONIC.Xspeed]
        bit     7,      B
        jr      nz,     @_13

        sbc     HL,     DE
        jr      c,      @_14

@_13:   ld      BC,     $FF80
@_14:   inc     B
@_15:   ld      [IX+Mob.Xspeed+0],      C
        ld      [IX+Mob.Xspeed+1],      B
        ld      [IX+Mob.Xdirection],    A
        ld      A,      [IX+Mob.unknown17]
        cp      $06
        jr      nz,     @_16

        ld      A,      [IX+Mob.unknown16]
        dec     A
        jr      nz,     @_16

        bit     7,      [IX+Mob.flags]
        jr      z,      @_16

        ld      [IX+Mob.Yspeed+0],      $00
        ld      [IX+Mob.Yspeed+1],      $FF
        ld      [IX+Mob.Ydirection],    $FF
@_16:   ld      DE,     $0017
        ld      BC,     $0036
        call    getFloorLayoutRAMAddressForMob
        ld      E,      [HL]
        ld      D,      $00
        ld      HL,     $3F28
        add     HL,     DE
        ld      A,      [HL]
        and     $3F
        and     A
        jr      z,      @_17

        bit     7,      [IX+Mob.flags]
        jr      z,      @_17

        ld      [IX+Mob.Yspeed+0],      $80
        ld      [IX+Mob.Yspeed+1],      $FD
        ld      [IX+Mob.Ydirection],    $FF
@_17:   ld      DE,     $0000
        ld      BC,     $0008
        call    getFloorLayoutRAMAddressForMob
        ld      A,      [HL]
        cp      $49
        jr      nz,     @_18

        bit     7,      [IX+Mob.flags]
        jr      z,      @_18

        xor     A
        ld      [IX+Mob.unknown16],     A
        ld      [IX+Mob.unknown17],     A
        ld      [IX+Mob.Xspeed+0],      A
        ld      [IX+Mob.Xspeed+1],      A
        ld      [IX+Mob.Xdirection],    A
        ld      [IX+Mob.unknown11],     $E0
        ld      [IX+Mob.unknown12],     $05
        ld      [IX+Mob.unknown13],     $60
        ld      [IX+Mob.unknown14],     $01

        ld      HL,     $0550
        ld      DE,     $0120
        call    _7c8c

        set     3,      [IX+Mob.flags]
        jp      @_20

@_18:   ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        ld      DE,     $000E
        add     HL,     DE
        adc     A,      $00
        ld      C,      A
        jp      m,      @_19

        ld      A,      H
        cp      $02
        jr      c,      @_19

        ld      HL,     $0200
@_19:   ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    C
        ld      BC,     @_ba28
        ld      DE,     _baf9
        call    animateMob
        ret

@_20:   ld      [IY+Vars.joypad],       $FF
        call    @_b99f
        ld      A,      [IX+Mob.unknown16]
        cp      $30
        jr      nc,     @_22

        ld      C,      A
        ld      A,      [RAM_FRAMECOUNT]
        and     %00000111
        jr      nz,     @_21

        ld      A,      [IX+Mob.unknown17]
        inc     A
        and     %00000001
        ld      [IX+Mob.unknown17],     A
        inc     [IX+Mob.unknown16]
@_21:   ld      A,      C
        cp      $2C
        ret     c

        ld      [IX+Mob.spriteLayout+0],        <_bb77
        ld      [IX+Mob.spriteLayout+1],        >_bb77
        ret

@_22:   xor     A
        ld      [IX+Mob.spriteLayout+0],        A
        ld      [IX+Mob.spriteLayout+1],        A
        inc     [IX+Mob.unknown16]
        ld      A,      [IX+Mob.unknown16]
        cp      $70
        ret     c

        ld      [IX+Mob.type],  $FF     ; remove mob?
        ret

        ;-----------------------------------------------------------------------

@_b99f: ld      HL,     @_ba1c                                          ;$B99F
        ld      A,      [IX+Mob.unknown17]
        add     A,      A
        add     A,      A
        ld      E,      A
        ld      D,      $00
        ld      B,      D
        add     HL,     DE
        ld      C,      [HL]
        inc     HL
        ld      E,      [HL]
        inc     HL
        ld      A,      [HL]
        inc     HL
        ld      H,      [HL]
        ld      L,      A
        ld      [IX+Mob.spriteLayout+0],        L
        ld      [IX+Mob.spriteLayout+1],        H
        ld      L,      [IX+Mob.unknown11]
        ld      H,      [IX+Mob.unknown12]
        add     HL,     BC
        ld      [IX+Mob.X+0],   L
        ld      [IX+Mob.X+1],   H
        ld      L,      [IX+Mob.unknown13]
        ld      H,      [IX+Mob.unknown14]
        add     HL,     DE
        ld      [IX+Mob.Y+0],   L
        ld      [IX+Mob.Y+1],   H
        ret

        ;-----------------------------------------------------------------------

@_b9d5: bit     5,      [IY+Vars.unknown0]                              ;$B9D5
        ret     nz

        call    findEmptyMob
        ret     c

        push    IX
        push    HL
        pop     IX

        xor     A                               ; set A to 0
        ld      [IX+Mob.type],          $47     ; unknown mob
        ld      [IX+Mob.Xsubpixel],     A
        ld      HL,     $0420
        ld      [IX+Mob.X+0],           L
        ld      [IX+Mob.X+1],           H
        ld      [IX+Mob.Ysubpixel],     A
        ld      HL,     $012F
        ld      [IX+Mob.Y+0],           L
        ld      [IX+Mob.Y+1],           H
        ld      [IX+Mob.unknown11],     A
        ld      [IX+Mob.flags],         A
        ld      [IX+Mob.Xspeed+0],      A
        ld      [IX+Mob.Xspeed+1],      A
        ld      [IX+Mob.Xdirection],    A
        ld      [IX+Mob.Yspeed+0],      A
        ld      [IX+Mob.Yspeed+1],      A
        ld      [IX+Mob.Ydirection],    A

        pop     IX
        ret

@_ba1b: .BYTE   $C9                     ; unused?
@_ba1c: .BYTE   $00 $00 $F9 $BA $00 $02 $0B $BB $00 $07 $0B $BB
@_ba28: .BYTE   $03 $08 $04 $07 $05 $08 $04 $07 $FF $30 $04 $A0 $01 $00 $00
@_ba37: .BYTE   $00 $00 $20 $22         ; unused, or part of above?
@_ba3b: .BYTE   $30 $04 $A0 $01 $00 $00 $00 $00 $24 $26 $20 $04 $60 $01 $37 $10
        .BYTE   $38 $10 $4A $10 $4B $10 $30 $04 $60 $01 $28 $10 $19 $10 $4C $10
        .BYTE   $4D $10 $40 $04 $60 $01 $00 $10 $2D $10 $4E $10 $4F $10 $20 $04
        .BYTE   $70 $01 $00 $00 $00 $00 $00 $00 $00 $00 $30 $04 $70 $01 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $40 $04 $70 $01 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $20 $04 $80 $01 $00 $00 $00 $00 $00 $00 $00 $00 $30 $04
        .BYTE   $80 $01 $00 $00 $00 $00 $00 $00 $00 $00 $40 $04 $80 $01 $00 $00
        .BYTE   $00 $00 $00 $00 $00 $00 $20 $04 $90 $01 $00 $00 $00 $00 $00 $00
        .BYTE   $00 $00 $30 $04 $90 $01 $00 $00 $00 $00 $00 $00 $00 $00 $40 $04
        .BYTE   $90 $01 $00 $00 $00 $00 $00 $00 $00 $00 $20 $04 $A0 $01 $5A $10
        .BYTE   $5B $10 $37 $10 $3B $10 $30 $04 $A0 $01 $5C $10 $5D $10 $3C $10
        .BYTE   $00 $10 $40 $04 $A0 $01 $5E $10 $5F $10 $00 $10 $2D $10
        ;

_baf9:                                                                  ;$BAF9
;===============================================================================
        .BYTE   $FE $0A $0C $0E $FF $FF
        .BYTE   $28 $2A $2C $2E $FF $FF
        .BYTE   $FE $4A $4C $4E $FF $FF
        
        .BYTE   $FE $0A $0C $0E $FF $FF
        .BYTE   $28 $2A $2C $2E $FF $FF
        .BYTE   $FE $02 $04 $06 $FF $FF
        ;

_bb1d:                                                                  ;$BB1D
;===============================================================================
; part of sky boss only
;
        .BYTE   $10 $12 $14 $16 $FF $FF
        .BYTE   $30 $32 $34 $FE $FF $FF
        .BYTE   $50 $52 $54 $FE $FF $FF

        .BYTE   $18 $1A $1C $1E $FF $FF
        .BYTE   $FE $3A $3C $3E $FF $FF
        .BYTE   $FE $64 $66 $68 $FF $FF

        .BYTE   $18 $1A $1C $1E $FF $FF
        .BYTE   $FE $3A $3C $3E $FF $FF
        .BYTE   $FE $6A $6C $6E $FF $FF

        .BYTE   $18 $1A $1C $1E $FF $FF
        .BYTE   $FE $3A $3C $3E $FF $FF
        .BYTE   $70 $72 $5A $5C $5E $FF

        .BYTE   $00 $0A $0C $0E $FF $FF
        .BYTE   $28 $2A $2C $2E $FF $FF
        .BYTE   $00 $4A $4C $4E $FF $FF
        ;

_bb77:                                                                  ;$BB77
;===============================================================================
        .BYTE   $FE $FF $FF $FF $FF $FF
        .BYTE   $FE $44 $46 $FF $FF $FF
        .BYTE   $FF
        ;

boss_electricBeam_process:                                              ;$BB84
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor

        ld      HL,     $0008
        ld      [RAM_SCROLLZONE_OVERRIDE_TOP],  HL

        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        ;UNKNOWN
        ld      HL,     $EF3F
        ld      DE,     $2000
        ld      A,      $0C
        call    decompressArt

        ld      [IX+Mob.unknown12],     $01
        set     0,      [IX+Mob.flags]
@_1:    ld      HL,     $0390
        ld      [RAM_TEMP1],    HL
        ld      L,      [IX+Mob.unknown11]
        ld      H,      $00
        ld      [RAM_TEMP4],    HL
        ld      L,      H
        ld      [RAM_TEMP6],    HL
        ld      DE,     $011A
        ld      HL,     @_bcdd
        call    @_bca5
        ld      E,      [IX+Mob.unknown11]
        ld      D,      $00
        ld      [RAM_TEMP4],    DE
        ld      DE,     $01D2
        ld      HL,     @_bcdd
        call    @_bca5
        bit     4,      [IY+Vars.unknown0]
        ret     z

        bit     1,      [IX+Mob.flags]
        jr      z,      @_2

        ld      A,      [RAM_FRAMECOUNT]
        bit     0,      A
        ret     nz

        and     $02
        ld      E,      A
        ld      D,      $00
        ld      HL,     @_bcc7
        add     HL,     DE
        ld      B,      $0a
        ld      DE,     $0130

@loop:  push    BC
        push    DE
        call    @_bca5
        pop     DE
        push    HL
        ld      HL,     $0010
        add     HL,     DE
        ex      DE,     HL
        pop     HL
        pop     BC
        djnz    @loop

        ld      HL,     $0390
        ld      C,      [IX+Mob.unknown11]
        ld      B,      $00
        add     HL,     BC
        ld      C,      L
        ld      B,      H
        ld      HL,     $000C
        add     HL,     BC
        ld      DE,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        jr      c,      @_2

        ld      HL,     $000E
        add     HL,     DE
        and     A
        sbc     HL,     BC
        jr      c,      @_2

        bit     0,      [IY+Vars.scrollRingFlags]
        call    z,      hitPlayer@_35fd

@_2:    ld      A,      [RAM_D2EC]
        cp      $06
        jr      nc,     @_5

        bit     1,      [IX+Mob.flags]
        jr      nz,     @_3

        ld      A,      [IX+Mob.unknown11]
        inc     A
        ld      [IX+Mob.unknown11],     A
        cp      $80
        ret     c

        ld      A,      [RAM_FRAMECOUNT]
        ld      C,      A
        and     %00000001
        ret     nz

        set     1,      [IX+Mob.flags]
        ret

@_3:    ld      A,      [RAM_FRAMECOUNT]
        and     $0F
        jr      nz,     @_4

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_13
                rst     $28     ;=rst_playSFX
        .ENDIF

@_4:    dec     [IX+Mob.unknown11]
        ret     nz

        ld      [IX+Mob.unknown11],     $00
        res     1,      [IX+Mob.flags]
        ret

@_5:    ld      HL,     [RAM_SONIC.X]
        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        and     A
        sbc     HL,     DE
        jr      nc,     @_6

        ld      A,      [IX+Mob.unknown11]
        and     A
        jr      z,      @_7

        dec     [IX+Mob.unknown11]
        jr      @_7

@_6:    ld      A,      [IX+Mob.unknown11]
        cp      $80
        jr      nc,     @_7

        inc     [IX+Mob.unknown11]
@_7:    res     1,      [IX+Mob.flags]
        ld      A,      [RAM_FRAMECOUNT]
        ld      C,      A
        and     $40
        ret     nz

        ld      A,      [RAM_D2EC]
        cp      $06
        ret     z

        set     1,      [IX+Mob.flags]
        ld      A,      C
        and     %00011111
        ret     nz

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_13
                rst     $28     ;=rst_playSFX
        .ENDIF

        ret

        ;-----------------------------------------------------------------------

@_bca5: ld      [RAM_TEMP3],    DE                                      ;$BAC5
        ld      A,      [HL]
        inc     HL
        push    HL
        call    _3581
        pop     HL
        ld      A,      [HL]
        inc     HL
        push    HL
        ld      HL,     [RAM_TEMP4]
        push    HL
        ld      DE,     $0008
        add     HL,     DE
        ld      [RAM_TEMP4],    HL
        call    _3581
        pop     HL
        ld      [RAM_TEMP4],    HL
        pop     HL
        ret

        ;-----------------------------------------------------------------------

@_bcc7: .BYTE   $36 $38 $56 $58 $36 $38 $56 $58 $36 $38 $56 $58 $36 $38 $56 $58
        .BYTE   $36 $38 $56 $58 $36 $38
@_bcdd: .BYTE   $40 $42
        ;

unknown_bcdf_process:                                                   ;$BCDF
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor
        set     5,      [IY+Vars.unknown0]
        ld      HL,     $0202
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_1

        bit     0,      [IY+Vars.scrollRingFlags]
        call    z,      hitPlayer@_35fd

        jp      @_8

@_1:    ld      A,       [IX+Mob.unknown11]
        cp      $C8
        jp      c,      @_6

        ld      E,      [IX+Mob.X+0]
        ld      D,      [IX+Mob.X+1]
        ld      HL,     [RAM_CAMERA_X]
        ld      BC,     $FFF4
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jp      nc,     @_8

        ld      HL,     [RAM_CAMERA_X]
        inc     H
        and     A
        sbc     HL,     DE
        jp      c,      @_8

        ld      HL,     [RAM_SONIC.X]
        and     A
        sbc     HL,     DE
        ld      L,      [IX+Mob.Xspeed+0]
        ld      H,      [IX+Mob.Xspeed+1]
        ld      A,      [IX+Mob.Xdirection]
        jr      nc,     @_2

        ld      C,      $FF
        ld      DE,     $FFF4
        bit     7,      A
        jr      nz,     @_3

        ld      DE,     $FFE8
        jr      @_3

@_2:    ld      C,      $00
        ld      DE,     $000C
        bit     7,      A
        jr      z,      @_3

        ld      DE,     $0018
@_3:    add     HL,     DE
        adc     A,      C
        ld      [IX+Mob.Xspeed+0],      L
        ld      [IX+Mob.Xspeed+1],      H
        ld      [IX+Mob.Xdirection],    A
        ld      E,      [IX+Mob.Y+0]
        ld      D,      [IX+Mob.Y+1]
        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $FFF4
        add     HL,     BC
        and     A
        sbc     HL,     DE
        jr      nc,     @_8

        ld      HL,     [RAM_CAMERA_Y]
        ld      BC,     $00c0
        add     HL,     DE
        and     A
        sbc     HL,     DE
        jr      c,      @_8

        ld      HL,     [RAM_SONIC.Y]
        and     A
        sbc     HL,     DE
        ld      L,      [IX+Mob.Yspeed+0]
        ld      H,      [IX+Mob.Yspeed+1]
        ld      A,      [IX+Mob.Ydirection]
        jr      nc,     @_4

        ld      C,      $FF
        ld      DE,     $FFF6
        bit     7,      A
        jr      nz,     @_5

        ld      DE,     $FFFB
        jr      @_5

@_4:    ld      DE,     $000A
        ld      C,      $00
        bit     7,      A
        jr      z,      @_5

        ld      DE,     $0005
@_5:    add     HL,     DE
        adc     A,      C
        ld      [IX+Mob.Yspeed+0],      L
        ld      [IX+Mob.Yspeed+1],      H
        ld      [IX+Mob.Ydirection],    A
        jr      @_7
@_6:    inc     [IX+Mob.unknown11]
@_7:    ld      BC,     @_bdc7
        ld      DE,     @_bdce
        call    animateMob
        bit     4,      [IY+Vars.unknown0]
        ret     nz

@_8:    ld      [IX+Mob.type],  $FF     ; remove object?
        res     5,      [IY+Vars.unknown0]
        ret

@_bdc7: .BYTE   $00 $01 $01 $01 $02 $01 $FF

        ; sprite layout
@_bdce: .BYTE   $44 $46 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $48 $08 $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF
        .BYTE   $FF $FF $FF $FF $FF $FF

        .BYTE   $60 $62 $FF $FF $FF $FF
        .BYTE   $FF
        ;

cutscene_final_process:                                                 ;$BDF9
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        ; mob does not collide with the floor
        set     5,      [IX+Mob.flags]

        ; clear joypad input
        ld      [IY+Vars.joypad],       $FF

        bit     1,      [IX+Mob.flags]
        jr      nz,     @_1
        ld      HL,     bossPalette
        ld      A,      %00000010
        call    loadPaletteOnInterrupt

        ; remove the player (i.e. prevent player interaction)
        ld      A,      $FF
        ld      [RAM_SONIC],    A
        ; move Sonic off the level
        ld      HL,     $0000
        ld      [RAM_SONIC.Y],  HL

        ld      [IX+$12],       $FF
        ; lock the screen - no scrolling
        set     6,      [IY+Vars.timeLightningFlags]
        set     1,      [IX+Mob.flags]
@_1:    ld      A,      [RAM_FRAMECOUNT]
        rrca
        jr      c,      @_2

        ld      A,      [IX+$12]
        and     A
        jr      z,      @_2

        dec     [IX+$12]
        jr      nz,     @_2

        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      DE,     $003C
        add     HL,     DE
        ld      [RAM_SONIC.X],   HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $FFC0
        add     HL,     DE
        ld      [RAM_SONIC.Y],  HL
        xor     A                       ; set A to 0
        ld      [RAM_SONIC],    A
        set     6,      [IY+Vars.unknown0]

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_06
                rst     $28     ;=rst_playSFX
        .ENDIF

@_2:    ld      [IX+Mob.width],         32
        ld      [IX+Mob.height],        28
        xor     A
        ld      [IX+Mob.Xspeed+0],      A
        ld      [IX+Mob.Xspeed+1],      $01
        ld      [IX+Mob.Xdirection],    A
        ld      [IX+Mob.Yspeed+0],      A
        ld      [IX+Mob.Yspeed+1],      A
        ld      [IX+Mob.Ydirection],    A
        bit     6,      [IY+Vars.timeLightningFlags]
        jr      z,      @_3

        ld      DE,     [RAM_CAMERA_X]
        ld      HL,     $0040
        add     HL,     DE
        ld      C,      [IX+Mob.X+0]
        ld      B,      [IX+Mob.X+1]
        and     A
        sbc     HL,     BC
        jr      nc,     @_3

        inc     DE
        ld      [RAM_CAMERA_X], DE
@_3:    ld      [IX+Mob.spriteLayout+0],<@_bf21
        ld      [IX+Mob.spriteLayout+1],>@_bf21
        bit     0,      [IX+Mob.flags]
        jr      nz,     @_4

        ld      HL,             $1008
        ld      [RAM_TEMP6],    HL
        call    detectCollisionWithSonic
        jr      c,      @_4

        ld      DE,     $0001
        ld      HL,     [RAM_SONIC.Yspeed]
        ld      A,      L
        cpl
        ld      L,      A
        ld      A,      H
        cpl
        ld      H,      A
        ld      A,      [RAM_SONIC.Ydirection]
        cpl
        add     HL,     DE
        adc     A,      $00
        ld      [RAM_SONIC.Yspeed],     HL
        ld      [RAM_SONIC.Ydirection], A
        res     6,      [IY+Vars.timeLightningFlags]
        set     0,      [IX+Mob.flags]
        ld      [IX+Mob.unknown11],     $01

        ; (we can compile with, or without, sound)
        .IFDEF  OPTION_SOUND
                ld      A,      SFX_ID_01
                rst     $28     ;=rst_playSFX
        .ENDIF

@_4:    call    _79fa
        bit     0,      [IX+Mob.flags]
        ret     z

        xor     A
        ld      [IX+Mob.Yspeed+0],      $40
        ld      [IX+Mob.Yspeed+1],      A
        ld      [IX+Mob.Ydirection],    A
        ld      [IX+Mob.spriteLayout+0],<@_bf33
        ld      [IX+Mob.spriteLayout+1],>@_bf33
        dec     [IX+Mob.unknown11]
        ret     nz

        call    _7a3a
        ld      [IX+Mob.unknown11],     $18
        inc     [IX+Mob.unknown13]
        ld      A,      [IX+Mob.unknown13]
        cp      $0A
        ret     c

        ld      A,      [RAM_D27F]
        cp      $06
        jr      c,      @_5

        set     7,      [IY+Vars.unknown0]
        ret

@_5:    ld      A,      [RAM_D289]
        and     A
        ret     nz

        ld      A,              $20
        ld      [RAM_D289],     A
        set     2,      [IY+Vars.unknown_0D]
        ret

@_bf21: .BYTE   $2A $2C $2E $30 $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $6C $6E $70 $72 $FF

        ; sprite layout
@_bf33: .BYTE   $2A $34 $36 $38 $32 $FF
        .BYTE   $4A $4C $4E $50 $52 $FF
        .BYTE   $6A $6C $6E $70 $72 $FF
        .BYTE   $5C $5E $FF $FF $FF $FF
        .BYTE   $FF
        ;

cutscene_emeralds_process:                                              ;$BF4C
;===============================================================================
; in    IX      Address of the current mob being processed
;-------------------------------------------------------------------------------
        set     5,      [IX+Mob.flags]  ; mob does not collide with the floor

        ; load the emerald image into VRAM,
        ; not more than one power-up can be on screen at a time
        ld      HL,     $5400           ;=$15400 - emerald image
        call    loadPowerUpIcon

        bit     0,      [IX+Mob.flags]
        jr      nz,     @_1

        xor     A                       ; set A to 0
        ld      [IX+Mob.spriteLayout+0],A
        ld      [IX+Mob.spriteLayout+1],A
        ld      [IX+Mob.Xspeed+0],      A
        ld      [IX+Mob.Xspeed+1],      A
        ld      [IX+Mob.Xdirection],    A

        inc     [IX+Mob.unknown11]
        ld      A,      [IX+Mob.unknown11]
        cp      $50
        ret     c

        set     0,      [IX+Mob.flags]
        ld      [IX+Mob.unknown11],     $64
        ret

@_1:    ld      A,      [IX+Mob.unknown11]
        and     A
        jr      z,      @_2

        dec     [IX+Mob.unknown11]
        jr      @_3

@_2:    ld      [IX+Mob.Yspeed+0],      $80
        ld      [IX+Mob.Yspeed+1],      $FF
        ld      [IX+Mob.Ydirection],    $FF
@_3:    ld      HL,     @_bff1
        ld      A,      [RAM_FRAMECOUNT]
        rrca
        jr      nc,     @_4

        ld      A,      [IY+Vars.spriteUpdateCount]
        ld      HL,     [RAM_SPRITETABLE_ADDR]
        push    AF
        push    HL
        ld      HL,     RAM_SPRITETABLE
        ld      [RAM_SPRITETABLE_ADDR], HL
        ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        ex      DE,     HL
        ld      L,      [IX+Mob.X+0]
        ld      H,      [IX+Mob.X+1]
        ld      BC,     [RAM_CAMERA_X]
        and     A
        sbc     HL,     BC
        ld      BC,     @_bff1          ; address of sprite layout
        call    processSpriteLayout
        pop     HL
        pop     AF
        ld      [RAM_SPRITETABLE_ADDR],         HL
        ld      [IY+Vars.spriteUpdateCount],    A
@_4:    ld      L,      [IX+Mob.Y+0]
        ld      H,      [IX+Mob.Y+1]
        ld      DE,     $0020
        add     HL,     DE
        ld      DE,     [RAM_CAMERA_Y]
        and     A
        sbc     HL,     DE
        ret     nc

        ld      A,              $01
        ld      [RAM_D289],     A

        set     2,      [IY+Vars.unknown_0D]
        ret

        ;sprite layout

@_bff1: .BYTE   $5C $5E $FF $FF $FF $FF
        .BYTE   $FF

        .BYTE   $49 $43 $20 $54 $48 $45 $20 $48
        ;
