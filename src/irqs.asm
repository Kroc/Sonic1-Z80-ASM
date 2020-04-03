.INC    "inc/vars.asm"

.SECTION    "!rst_reset"                                                ;$0000
;===============================================================================
rst_reset:                                                              ;$0000
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
.ENDS

.SECTION    "!irq"                                                      ;$0038
;===============================================================================
irq:                                                                    ;$0038
;===============================================================================
; Every 1/50th (PAL) or 1/60th (NTSC) of a second, an interrupt is generated
; and control passes here. there's only a small amount of space between this
; routine and the pause handler, so we just jump to the routine proper
;-------------------------------------------------------------------------------
        jp      interruptHandler
        ;
.ENDS

.SECTION    "!nmi_pause"                                                ;$0066
;===============================================================================
nmi_pause:                                                              ;$0066
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
.ENDS

.SECTION    "interruptHandler"                                          ;$0073
;===============================================================================
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

        call    main_0625

        ; check for the reset button:
        ; read 2nd joypad port which has extra bits for lightgun / reset button
        in      A,      [SMS_PORTS_JOYB]      
        and     %00010000                       ; check bit 4
        jp      z,      rst_reset               ; reset!

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
        call    z,      main_38b0

        ld      A,              $FF
        ld      [RAM_D2AB+1],   A

        set     0,      [IY+Vars.flags0]
        ret

loadPaletteFromInterrupt:                                               ;$0174
;===============================================================================
; loads a palette using the parameters set first by `loadPaletteOnInterrupt`:
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
        ;
        
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
; TODO: this should be defined by the mob, not the interrupts
; (i.e. it can be excluded if no underwater used)
        .TABLE  DSB 16
@tile:  .ROW    $10 $14 $14 $18 $35 $34 $2C $39 $21 $20 $1E $09 $04 $1E $10 $3F
@sprite:.ROW    $10 $20 $35 $2E $29 $3A $00 $3F $24 $3D $1F $17 $14 $3A $19 $00

.ENDS
