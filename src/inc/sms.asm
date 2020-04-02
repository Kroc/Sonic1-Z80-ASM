; number of hardware sprites on the SEGA Master System:
; there is of course no reason to change this value,
; other than creating some kind of weird super-SMS emulator
.DEF    SMS_SPRITES                     64

; display dimensions, in pixels, of the SEGA Master System:
; note that the VRAM contains a 256 x 224 px scrollable
; region for the display
.DEF    SMS_SCREEN_WIDTH                256
.DEF    SMS_SCREEN_HEIGHT               192
; notably used on CodeMasters' MicroMachines game
.DEF    SMS_SCREEN_HEIGHT_EXTENDED      224
; the super-extended display height is 240px. This leaves NTSC displays with no
; VBlank remaining causing the picture to roll around on the screen. This mode
; can be used on PAL displays, but leaves you with next to no VRAM left for
; sprites or tiles and a minuscule VBlank period
.DEF    SMS_SCREEN_HEIGHT_SUPEREXTENDED 240

.DEF    SMS_VRAM_WIDTH  256
.DEF    SMS_VRAM_HEIGHT 224

.STRUCT SMSBitPlane
        bitplane1       BYTE
        bitplane2       BYTE
        bitplane3       BYTE
        bitplane4       BYTE
.ENDST

.STRUCT SMSTile
        ;; this makes the link very slow if we include thousands of properties
        ;;rows            INSTANCEOF SMSBitPlane 8
        .               DSB 32
.ENDST

; the layout of the Sprite Attribute Table in VRAM is rather odd. instead of
; an array of sprite X/Y/indices, the Y-positions for all sprites come first,
; followed by an unused chunk of memory and then an array of interleaved
; X-positions / tile indices
;
.STRUCT SMSSpriteXI
        ;=======================================================================
        xPos            BYTE
        ; which tile to use for the sprite. As this is 8-bits
        ; instead of 9, sprites can only use the first 256 tiles in VRAM
        index           BYTE
.ENDST
