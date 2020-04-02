.INC    "inc/mem.asm"           ; memory layout
.INC    "inc/sms.asm"           ; hardware definitions

.RAMSECTION "SMS_Z80"   SLOT "Z80"
        ;===========================================================================
        ; Z80 ADDRESS SPACE:
        ;---------------------------------------------------------------------------
        ; this defines the address and size of the SEGA mapper Slot 0:
        ; you can't write to this, write to `SMS_MAPPER_SLOT0` to change bank
        SMS_SLOT0               DSB 16 * 1024                           ;[$0000]
        ; this defines the address and size of the SEGA mapper Slot 1:
        ; you can't write to this, write to `SMS_MAPPER_SLOT1` to change bank
        SMS_SLOT1               DSB 16 * 1024                           ;[$4000]
        ; this defines the address and size of the SEGA mapper Slot 2:
        ; you can't write to this, write to `SMS_MAPPER_SLOT2` to change bank
        SMS_SLOT2               DSB 16 * 1024                           ;[$8000]
        SMS_RAM                 DSB (8 * 1024)                          ;[$C000]
        SMS_RAM_MIRROR          DSB (8 * 1024) - 8                      ;[$E000]
        SMS_GLASSES             DSB 4                                   ;[$FFF8]
        ; the banking of the cartridge ROM into the slots of the Z80 address
        ; space is handled by the mapper chip. for standard SEGA mappers,
        ; writing to $FFFC configures the mapper and $FFFD/E/F sets the ROM
        ; bank number to page into the relevant memory slot. for more details,
        ; see: http://www.smspower.org/Development/Mappers
        SMS_MAPPER_CONTROL      DB                                      ;[$FFFC]
        SMS_MAPPER_SLOT0        DB                                      ;[$FFFD]
        SMS_MAPPER_SLOT1        DB                                      ;[$FFFE]
        SMS_MAPPER_SLOT2        DB                                      ;[$FFFF]
.ENDS

.RAMSECTION "SMS_VRAM"  SLOT "VRAM"
        ;=======================================================================
        ; VRAM:
        ;-----------------------------------------------------------------------
        SMS_VRAM               .DSB 16 * 1024                           ;$0000
        ;-----------------------------------------------------------------------
        SMS_VRAM_TILES          INSTANCEOF SMSTile 256 + 192            ;$0000
        SMS_VRAM_SCREEN         DSW 32 * 28                             ;$3800
        
        SMS_VRAM_SPRITES       .DSB $FF                                 ;$3F00
        ;-----------------------------------------------------------------------
        SMS_VRAM_SPRITES_YPOS   DSB SMS_SPRITES                         ;$3F00
        ; this region of the Sprite Attribute Table is unused for sprites and
        ; can be re-purposed for storing some additional background tiles
        SMS_VRAM_SPRITES_UNUSED DSB SMS_SPRITES                         ;$3F40
        SMS_VRAM_SPRITES_XPOS   INSTANCEOF SMSSpriteXI SMS_SPRITES      ;$3F80
.ENDS

; Z80 ports:
;===============================================================================
.DEF    SMS_PORTS_REGION                $3E                             EXPORT
.DEF    SMS_PORTS_CONTROL               $3F                             EXPORT

.DEF    SMS_PORTS_CONTROL_IO            %00000100                       EXPORT
.DEF    SMS_PORTS_CONTROL_BIOS          %00001000                       EXPORT
.DEF    SMS_PORTS_CONTROL_RAM           %00010000                       EXPORT
.DEF    SMS_PORTS_CONTROL_CARD          %00100000                       EXPORT
.DEF    SMS_PORTS_CONTROL_CART          %01000000                       EXPORT
.DEF    SMS_PORTS_CONTROL_EXPANSION     %10000000                       EXPORT

.DEF    SMS_PORTS_SCANLINE              $7E                             EXPORT
.DEF    SMS_PORTS_PSG                   $7F                             EXPORT
.DEF    SMS_PORTS_VDP_DATA              $BE                             EXPORT
.DEF    SMS_PORTS_VDP_CONTROL           $BF                             EXPORT

.DEF    SMS_VDP_REGISTER_WRITE          %10000000                       EXPORT
.DEF    SMS_VDP_REGISTER_0              SMS_VDP_REGISTER_WRITE | 0      EXPORT
.DEF    SMS_VDP_REGISTER_1              SMS_VDP_REGISTER_WRITE | 1      EXPORT
.DEF    SMS_VDP_REGISTER_2              SMS_VDP_REGISTER_WRITE | 2      EXPORT
.DEF    SMS_VDP_REGISTER_5              SMS_VDP_REGISTER_WRITE | 5      EXPORT
.DEF    SMS_VDP_REGISTER_6              SMS_VDP_REGISTER_WRITE | 6      EXPORT
.DEF    SMS_VDP_REGISTER_7              SMS_VDP_REGISTER_WRITE | 7      EXPORT
.DEF    SMS_VDP_REGISTER_8              SMS_VDP_REGISTER_WRITE | 8      EXPORT
.DEF    SMS_VDP_REGISTER_9              SMS_VDP_REGISTER_WRITE | 9      EXPORT
.DEF    SMS_VDP_REGISTER_10             SMS_VDP_REGISTER_WRITE | 10     EXPORT

.DEF    SMS_PORTS_JOYA                  $DC                             EXPORT

.DEF    SMS_PORTS_JOYA_PAD1UP           %00000001                       EXPORT
.DEF    SMS_PORTS_JOYA_PAD1DOWN         %00000010                       EXPORT
.DEF    SMS_PORTS_JOYA_PAD1LEFT         %00000100                       EXPORT
.DEF    SMS_PORTS_JOYA_PAD1RIGHT        %00001000                       EXPORT
.DEF    SMS_PORTS_JOYA_PAD1BUTTON1      %00010000                       EXPORT
.DEF    SMS_PORTS_JOYA_PAD1BUTTON2      %00100000                       EXPORT
.DEF    SMS_PORTS_JOYA_PAD2UP           %01000000                       EXPORT
.DEF    SMS_PORTS_JOYA_PAD2DOWN         %10000000                       EXPORT
.DEF    SMS_PORTS_JOYB_PAD2LEFT         %00000001                       EXPORT

.DEF    SMS_PORTS_JOYB                  $DD                             EXPORT

.DEF    SMS_PORTS_JOYB_PAD2RIGHT        %00000010                       EXPORT
.DEF    SMS_PORTS_JOYB_PAD2BUTTON1      %00000100                       EXPORT
.DEF    SMS_PORTS_JOYB_PAD2BUTTON2      %00001000                       EXPORT
.DEF    SMS_PORTS_JOYB_RESET            %00010000                       EXPORT
.DEF    SMS_PORTS_JOYB_UNUSED           %00100000                       EXPORT
.DEF    SMS_PORTS_JOYB_LIGHTGUN1        %01000000                       EXPORT
.DEF    SMS_PORTS_JOYB_LIGHTGUN2        %10000000                       EXPORT

.DEF    SMS_JOY_PAD1_UP                 SMS_PORTS_JOYA_PAD1UP           EXPORT
.DEF    SMS_JOY_PAD1_DOWN               SMS_PORTS_JOYA_PAD1DOWN         EXPORT
.DEF    SMS_JOY_PAD1_LEFT               SMS_PORTS_JOYA_PAD1LEFT         EXPORT
.DEF    SMS_JOY_PAD1_RIGHT              SMS_PORTS_JOYA_PAD1RIGHT        EXPORT
.DEF    SMS_JOY_PAD1_BUTTON1            SMS_PORTS_JOYA_PAD1BUTTON1      EXPORT
.DEF    SMS_JOY_PAD1_BUTTON2            SMS_PORTS_JOYA_PAD1BUTTON2      EXPORT

.DEF    SMS_JOY_PAD2_UP                 SMS_PORTS_JOYA_PAD2UP           EXPORT
.DEF    SMS_JOY_PAD2_DOWN               SMS_PORTS_JOYA_PAD2DOWN         EXPORT
.DEF    SMS_JOY_PAD2_LEFT               SMS_PORTS_JOYB_PAD2LEFT         EXPORT
.DEF    SMS_JOY_PAD2_RIGHT              SMS_PORTS_JOYB_PAD2RIGHT        EXPORT
.DEF    SMS_JOY_PAD2_BUTTON1            SMS_PORTS_JOYB_PAD2BUTTON1      EXPORT
.DEF    SMS_JOY_PAD2_BUTTON2            SMS_PORTS_JOYB_PAD2BUTTON2      EXPORT