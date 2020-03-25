.INCLUDE        "inc/sms.asm"           ; hardware definitions

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