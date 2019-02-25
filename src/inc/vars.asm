
.STRUCT Vars
;===============================================================================
; the original programmers used the IY register as a short-cut to $D200
; to access commonly used variables and flags

        ; program flow control / loading flags?
        flags0                  DB                                      ;IY+$00
        ;-----------------------------------------------------------------------
        ;waitForInterrupt       ;0 - `waitForInterrupt:` until bit is set
        ;                       ;1 - unknown (set at level load)
        ;                       ;2 - unused?
        ;loadPalette            ;3 - flag to load palette on IRQ
        ;                       ;4 - unused?
        ;                       ;5 - unknown -- player control enabled/disabled?
        ;cameraMoveHoriz        ;6 - set when the camera has moved left
        ;cameraMoveVert         ;7 - set when the camera has moved up
        
        ; this is used only as the comparison byte in `loadFloorLayout:`
        temp                    DB                                      ;IY+$01
        
        flags2                  DB                                      ;IY+$02
        ;-----------------------------------------------------------------------
        ;                       ;0 - unknown
        ;                       ;1 - unknown
        ;                       ;2 - unknown
        
        ; value of joypad port 1
        ; the bits are 1 for unpressed, 0 for pressed
        ;
        joypad                  DB                                      ;IY+$03
        ;-----------------------------------------------------------------------
        ;pad1up                 ;0 - joypad 1 up
        ;pad1down               ;1 - joypad 1 down
        ;pad1left               ;2 - joypad 1 left
        ;pad1right              ;3 - joypad 1 right
        ;pad1A                  ;4 - joypad button A
        ;pad1B                  ;5 - joypad button B
        
        ; this does not appear referenced in any code
        unused                  DB                                      ;IY+$04
        
        ; taken from the level header, this controls screen scrolling
        ; and the presence of the "rings" count on the HUD
        scrollRingFlags         DB                                      ;IY+$05
        ;-----------------------------------------------------------------------
        ;dead                   ;0 - death flag
        ;demo                   ;1 - demo mode
        ;rings                  ;2 - ring count in HUD, visible in the level
        ;scrollRight            ;3 - automatic scrolling to the right
        ;scrollUp               ;4 - automatic scrolling upwards
        ;scrollSmooth           ;5 - smooth scrolling
        ;scrollWave             ;6 - up and down wave scrolling
        ;noScrollDown           ;7 - screen does not scroll down
        
        flags6                  DB                                      ;IY+$06
        ;-----------------------------------------------------------------------
        ;                       ;0 - make Sonic upside down! (incomplete)
        ;                       ;1 - disable controls
        ;                       ;2 - unknown
        ;                       ;3 - clock is active when set
        ;                       ;4 - unknown
        ;                       ;5 - shield active
        ;                       ;6 - Sonic is in damage state
        ;                       ;7 - level underwater flag (enables water line)
        
        ; taken from the level header, this controls the presence of the time
        ; on the HUD, and if the lightning effect is in use
        timeLightningFlags      DB                                      ;IY+$07
        ;-----------------------------------------------------------------------
        ;                       ;0 - centres time on screen in special stages
        ;                       ;1 - enables the lightning effect
        ;                       ;2 - unknown
        ;                       ;3 - unknown
        ;                       ;4 - use boss underwater palette (Labyrinth-3)
        ;                       ;5 - time is displayed in the HUD
        ;                       ;6 - locks the screen, no scrolling
        ;                       ;7 - is special stage?
        
        ; part of the level header
        ; -- always "0" for all levels, but unknown function
        unknown0                DB                                      ;IY+$08
        ;-----------------------------------------------------------------------
        ;                       ;0 - unused
        ;                       ;1 - unknown, set at "._4e88"
        
        flags9                  DB                                      ;IY+$09
        ;-----------------------------------------------------------------------
        ;                       ;0 - unknown
        ;                       ;1 - enables interrupts during `decompressArt`
        ;                       ;2 - set when special stage timer reaches zero
        ;                       ;3 - unknown -- reset at ":_1719"
        
        spriteUpdateCount       DB      ;# sprites requiring updates    ;IY+$0A
        origScrollRingFlags     DB      ;copy made loading level UNUSED ;IY+$0B
        origFlags6              DB      ;copy made loading level        ;IY+$0C
        
        ;currently unknown purpose
        unknown_0D              DB                                      ;IY+$0D
.ENDST