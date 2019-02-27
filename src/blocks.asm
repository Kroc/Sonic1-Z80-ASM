.INCLUDE        "inc\sms.asm"

.BANK   4       SLOT    1
.ORG    $0000

blockMappings:                                                          ;$1:0000

;;;[$10000]
;;S1_BlockMappings:
;;
;;S1_BlockMappings_GreenHill:
;;.INCBIN "ROM.sms" SKIP $10000 READ 2944
;;
;;S1_BlockMappings_Bridge:
;;.INCBIN "ROM.sms" SKIP $10B80 READ 2304
;;
;;S1_BlockMappings_Jungle:
;;.INCBIN "ROM.sms" SKIP $11480 READ 2560
;;
;;S1_BlockMappings_Labyrinth:
;;.INCBIN "ROM.sms" SKIP $11E80 READ 2816
;;
;;S1_BlockMappings_ScrapBrain:
;;.INCBIN "ROM.sms" SKIP $12980 READ 3072
;;
;;S1_BlockMappings_SkyBaseExterior:
;;;.INCBIN "ROM.sms" SKIP $13580 READ 3456
;;.INCBIN "ROM.sms" SKIP $13580 READ ($14000 - $13580)
;;.BANK 5
;;.ORG $0000
;;.INCBIN "ROM.sms" SKIP $14000 READ 3456 - ($14000 - $13580)
;;
;;S1_BlockMappings_SkyBaseInterior:
;;.INCBIN "ROM.sms" SKIP $14300 READ 1664
;;
;;S1_BlockMappings_SpecialStage:
;;.INCBIN "ROM.sms" SKIP $14980 READ 2048
;;
;;;======================================================================================
;;;"blinking items"
;;;(need to properly break these down)
;;
;;;[$15180]
;;.INCBIN "ROM.sms" SKIP $15180 READ 1024
;;
;;;======================================================================================
;;;level headers:
;;
;;.MACRO TABLE ARGS tableName
;;	;define the current position as the table name
;;__TABLE\@__:
;;	.DEF \1 __TABLE\@__
;;	;then define a reference used for counting the row index
;;	.REDEF __ROW__ 0
;;.ENDM
;;
;;.MACRO ROW ARGS rowIndexLabel
;;__ROW\@__:
;;	.IFDEFM \1
;;		.DEF \1 __ROW__
;;	.ENDIF
;;	.REDEF __ROW__ (__ROW__+1)
;;.ENDM
;;
;;.MACRO ENDTABLE ARGS tableName
;;	.DEF _sizeof_\1 (__ROW__+1)
;;.ENDM
;;
;;
;;.BANK 5
;;
;;;[$15580]
;;S1_LevelHeader_Pointers:
;;
;;;[$155CA]
;;.ORG $155CA - $14000
;;
;; TABLE	"S1_LevelHeaders"
;; ROW	"index_levelHeaders_greenHill1"
;;.db $00					;SP: SolidityPointer
;;.dw $0100, $0010			;FW/FH: FloorWidth/Height
;;.db $40					;CL: CropLeft
;;.db $00					;LX: LevelXOffset
;;.db $C0					;unknown byte
;;.db $18					;LW: LevelWidth
;;.db $20					;CT: CropTop
;;.db $00					;LY: LevelYOffset
;;.db $40					;XH: ExtendHeight
;;.db $01					;LH: LevelHeight
;;.db $08					;SX: StartX
;;.db $0B					;SY: StartY
;;.dw $2DEA				;FL: FloorLayout
;;.dw $083E				;FS: FloorSize
;;.dw $0000				;BM: BlockMappings
;;.dw $2FE6				;LA: LevelArt
;;.db $09					;SB: SpriteBank
;;.dw $612A				;SA: SpriteArt
;;.db $00					;IP: InitialPalette
;;.db $0A					;CS: CycleSpeed
;;.db $03					;CC: CycleCount
;;.db $00					;CP: CyclePalette
;;.dw $0534				;OL: ObjectLayout
;;.db $04					;SR: Scrolling/Ring flags
;;.db $00					;UW: Underwater flag
;;.db $20					;TL: Time/Lightning flags
;;.db $00					;X0: Unknown byte - always 0
;;.db $00					;MU: Music
;; ENDTABLE	"S1_LevelHeaders"