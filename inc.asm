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

.INCLUDE	"sms.asm"
.INCLUDE	"ram.asm"

