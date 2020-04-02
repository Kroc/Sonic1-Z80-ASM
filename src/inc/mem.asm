; the memory / ROM map must be defined for any object file

.MEMORYMAP
        ;=======================================================================
        SLOT    0       START $0000 SIZE $4000  NAME "SLOT0"    ; ROM 0
        SLOT    1       START $4000 SIZE $4000  NAME "SLOT1"    ; ROM 1
        SLOT    2       START $8000 SIZE $4000  NAME "SLOT2"    ; ROM 2
        
        ;;SLOT    X       START $0000 SIZE $C000  NAME "SLOT_MAIN"; All SLOTs
        
        SLOT    3       START $C000 SIZE $2000  NAME "RAM"      ; 8KB RAM
        ;-----------------------------------------------------------------------
        SLOT    4       START $0000 SIZE $4000  NAME "VRAM"     ; VRAM
        SLOT    5       START $0000 SIZE $10000 NAME "Z80"      ; address-space
        
        DEFAULTSLOT     0
.ENDME

; define the ROM (cartridge) size
.ROMBANKMAP
        BANKSTOTAL      16              ; use 16 banks,
        
        ;;BANKSIZE        $C000
        ;;BANKS           1
        BANKSIZE        $4000           ; each 16 KB in size
        BANKS           16              ; (that's 256 KB)
.ENDRO