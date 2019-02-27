; the memory / ROM map must be defined for any object file

.MEMORYMAP
        SLOT            0       START $0000 SIZE $4000  ; ROM 0
        SLOT            1       START $4000 SIZE $4000  ; ROM 1
        SLOT            2       START $8000 SIZE $4000  ; ROM 2
        SLOT            3       START $C000 SIZE $2000  ; 8KB RAM
        SLOT            4       START $0000 SIZE $4000  ; VRAM
        SLOT            5       START $0000 SIZE $10000 ; Z80 address space
        DEFAULTSLOT     0
.ENDME

; define the ROM (cartridge) size
.ROMBANKMAP
        BANKSTOTAL      16              ; use 16 banks,
        BANKSIZE        $4000           ; each 16 KB in size
        BANKS           16              ; (that's 256 KB)
.ENDRO

; number of hardware sprites on the SEGA Master System:
; there is of course no reason to change this value,
; other than creating some kind of weird super-SMS emulator
.DEF    SMS_SPRITES                     64

; display dimensions, in pixels, of the SEGA Master System.
; note that the VRAM contains a 256 x 224 px scrollable region for the display
.DEF    SMS_SCREEN_WIDTH                256
.DEF    SMS_SCREEN_HEIGHT               192
; notably used on CodeMasters' MicroMachines game
.DEF    SMS_SCREEN_HEIGHT_EXTENDED      224
; the super-extended display height is 240px. This leaves NTSC displays with no
; VBlank remaining causing the picture to roll around on the screen. This mode
; can be used on PAL displays, but leaves you with next to no VRAM left for
; sprites or tiles and a miniscule VBlank period
.DEF    SMS_SCREEN_HEIGHT_SUPEREXTENDED 240

.STRUCT SMSTile
        bitplane1       BYTE
        bitplane2       BYTE
        bitplane3       BYTE
        bitplane4       BYTE
.ENDST

; The layout of the Sprite Attribute Table in VRAM is rather odd. Instead an
; array of sprite X/Y/indices, the Y-positions for all sprites come first,
; followed by an unused chunk of memory and then an array of interleaved
; X-positions / tile indices
.STRUCT SMSSpriteXI
        xPos            BYTE
        ; which tile to use for the sprite. As this is 8-bits instead of 9,
        ; sprites can only use the first 256 tiles in VRAM.
        index           BYTE
.ENDST

; Z80 ports:
;===============================================================================
.DEF    SMS_PORTS_REGION                $3E
.DEF    SMS_PORTS_CONTROL               $3F

.DEF    SMS_PORTS_CONTROL_IO            %00000100
.DEF    SMS_PORTS_CONTROL_BIOS          %00001000
.DEF    SMS_PORTS_CONTROL_RAM           %00010000
.DEF    SMS_PORTS_CONTROL_CARD          %00100000
.DEF    SMS_PORTS_CONTROL_CART          %01000000
.DEF    SMS_PORTS_CONTROL_EXPANSION     %10000000

.DEF    SMS_PORTS_SCANLINE              $7E
.DEF    SMS_PORTS_PSG                   $7F
.DEF    SMS_PORTS_VDP_DATA              $BE
.DEF    SMS_PORTS_VDP_CONTROL           $BF

.DEF    SMS_VDP_REGISTER_WRITE          %10000000
.DEF    SMS_VDP_REGISTER_0              SMS_VDP_REGISTER_WRITE | 0
.DEF    SMS_VDP_REGISTER_1              SMS_VDP_REGISTER_WRITE | 1
.DEF    SMS_VDP_REGISTER_2              SMS_VDP_REGISTER_WRITE | 2
.DEF    SMS_VDP_REGISTER_5              SMS_VDP_REGISTER_WRITE | 5
.DEF    SMS_VDP_REGISTER_6              SMS_VDP_REGISTER_WRITE | 6
.DEF    SMS_VDP_REGISTER_7              SMS_VDP_REGISTER_WRITE | 7
.DEF    SMS_VDP_REGISTER_8              SMS_VDP_REGISTER_WRITE | 8
.DEF    SMS_VDP_REGISTER_9              SMS_VDP_REGISTER_WRITE | 9
.DEF    SMS_VDP_REGISTER_10             SMS_VDP_REGISTER_WRITE | 10

.DEF    sms.ports.joy_a                 $DC

.DEF    sms.ports.joy_a.pad1up          %00000001
.DEF    sms.ports.joy_a.pad1down        %00000010
.DEF    sms.ports.joy_a.pad1left        %00000100
.DEF    sms.ports.joy_a.pad1right       %00001000
.DEF    sms.ports.joy_a.pad1button1     %00010000
.DEF    sms.ports.joy_a.pad1button2     %00100000
.DEF    sms.ports.joy_a.pad2up          %01000000
.DEF    sms.ports.joy_a.pad2down        %10000000
.DEF    sms.ports.joy_b.pad2left        %00000001

.DEF    sms.ports.joy_b                 $DD

.DEF    sms.ports.joy_b.pad2right       %00000010
.DEF    sms.ports.joy_b.pad2button1     %00000100
.DEF    sms.ports.joy_b.pad2button2     %00001000
.DEF    sms.ports.joy_b.reset           %00010000
.DEF    sms.ports.joy_b.unused          %00100000
.DEF    sms.ports.joy_b.lightgun1       %01000000
.DEF    sms.ports.joy_b.lightgun2       %10000000

.DEF    SMS_JOY_PAD1_UP                 sms.ports.joy_a.pad1up
.DEF    SMS_JOY_PAD1_DOWN               sms.ports.joy_a.pad1down
.DEF    SMS_JOY_PAD1_LEFT               sms.ports.joy_a.pad1left
.DEF    SMS_JOY_PAD1_RIGHT              sms.ports.joy_a.pad1right
.DEF    SMS_JOY_PAD1_BUTTON1            sms.ports.joy_a.pad1button1
.DEF    SMS_JOY_PAD1_BUTTON2            sms.ports.joy_a.pad1button2

.DEF    SMS_JOY_PAD2_UP                 sms.ports.joy_a.pad2up
.DEF    SMS_JOY_PAD2_DOWN               sms.ports.joy_a.pad2down
.DEF    SMS_JOY_PAD2_LEFT               sms.ports.joy_b.pad2left
.DEF    SMS_JOY_PAD2_RIGHT              sms.ports.joy_b.pad2right
.DEF    SMS_JOY_PAD2_BUTTON1            sms.ports.joy_b.pad2button1
.DEF    SMS_JOY_PAD2_BUTTON2            sms.ports.joy_b.pad2button2
