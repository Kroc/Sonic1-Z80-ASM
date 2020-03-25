.INC    "inc/sms.asm"           ; hardware definitions
.INC    "inc/vars.asm"
.INC    "inc/mob.asm"

.RAMSECTION "sonic1"            SLOT 3
;===============================================================================
; name                          ; size  ; note                          ; addr
;-------------------------------------------------------------------------------
; the floor layout (i.e. the tiles Sonic runs around on). a 'level' is
; a sub-portion of this floor layout since sometimes multiple levels
; are crammed into one layout (such as the special stages)
RAM_FLOORLAYOUT                 DSB 4096                                ;[$C000]

; X/Y/I data for the 64 sprites
RAM_SPRITETABLE                 DSB 64 * 3                              ;[$D000]
        
RAM_D0C0                        DSB 64  ; UNUSED                        ;[$D0C0]
        
; when the screen scrolls and new tiles need to be filled in, they are pulled
; from these caches which have the necessary tiles already in horizontal /
; vertical order for speed. (NOTE: though these are 128 bytes each,
; I don't think that much is used)
RAM_OVERSCROLLCACHE_VERT        DSB 128                                 ;[$D100]
RAM_OVERSCROLLCACHE_HORZ        DSB 128                                 ;[$D180]

; throughout the codebase, IY is used as a shorthand to $D200 where many
; commonly used variables exist. therefore these use the `[IY+Vars.abc]`
; form of addressing. for the sake of completeness, we'll also define the
; absolute location of these variables too, i.e. `VARS.abc`
RAM_VARS                        INSTANCEOF Vars                         ;[$D200]

; these temporary variables are reused throughout, some times for passing extra
; parameters to functions and sometimes as extra working space within functions
RAM_TEMP1                       DB                                      ;[$D20F]
RAM_TEMP2                       DB                                      ;[$D210]
RAM_TEMP3                       DB                                      ;[$D211]
RAM_TEMP4                       DB                                      ;[$D212]
RAM_TEMP5                       DB                                      ;[$D213]
RAM_TEMP6                       DB                                      ;[$D214]
RAM_TEMP7                       DB                                      ;[$D215]

RAM_D216                        DW      ; UNKNOWN                       ;[$D216]

RAM_VDPREGISTER_0               DB      ; RAM cache of VDP register 0   ;[$D218]
RAM_VDPREGISTER_1               DB      ; RAM cache of VDP register 1   ;[$D219]
; though the code copies the VDP registers here, these ones are not recalled
RAM_VDPREGISTER_2               DB                                      ;[$D21A]
RAM_VDPREGISTER_3               DB                                      ;[$D21B]
RAM_VDPREGISTER_4               DB                                      ;[$D21C]
RAM_VDPREGISTER_5               DB                                      ;[$D21D]
RAM_VDPREGISTER_6               DB                                      ;[$D21E]
RAM_VDPREGISTER_7               DB                                      ;[$D21F]
RAM_VDPREGISTER_8               DB                                      ;[$D220]
RAM_VDPREGISTER_9               DB                                      ;[$D221]
RAM_VDPREGISTER_10              DB                                      ;[$D222]

RAM_FRAMECOUNT                  DW      ; 16-bit continual frame count  ;[$D223]

; referenced only by unused function `unused_0323:`
RAM_UNUSED_D225                 DW                                      ;[$D225]
RAM_UNUSED_D227                 DW                                      ;[$D227]
RAM_UNUSED_D229                 DW                                      ;[$D229]

; `loadPaletteOnInterrupt:` and `loadPaletteFromInterrupt:`
; use these to pass parameters
RAM_LOADPALETTE_ADDRESS         DW                                      ;[$D22B]
RAM_D22D                        DW      ; UNUSED                        ;[$D22D]
RAM_LOADPALETTE_FLAGS           DB                                      ;[$D22F]

; `loadPalette:` uses these to pass the addresses
; of the tile/sprite palettes to load
RAM_LOADPALETTE_TILE            DW                                      ;[$D230]
RAM_LOADPALETTE_SPRITE          DW                                      ;[$D232]

RAM_D234                        DB      ; UNUSED                        ;[$D234]

; these keep track of which bank is in which slot
; -- slot 0 is always bank 0
RAM_SLOT1                       DB                                      ;[$D235]
RAM_SLOT2                       DB                                      ;[$D236]

RAM_D237                        DB      ; UNUSED                        ;[$D237]

RAM_LEVEL_FLOORWIDTH            DW      ; floor-layout width in blocks  ;[$D238]
RAM_LEVEL_FLOORHEIGHT           DW      ; floor-layout height in blocks ;[$D23A]

RAM_SPRITETABLE_ADDR            DW      ; pointer to sprite table       ;[$D23C]

RAM_CURRENT_LEVEL               DB                                      ;[$D23E]

RAM_D23F                        DB      ; UNKNOWN                       ;[$D23F]
RAM_D240                        DW      ; UNKNOWN                       ;[$D240]
RAM_D242                        DW      ; UNKNOWN                       ;[$D242]
RAM_D244                        DW      ; UNKNOWN                       ;[$D244]

RAM_LIVES                       DB      ; player's lives count          ;[$D246]

RAM_RASTERSPLIT_STEP            DB                                      ;[$D247]
RAM_RASTERSPLIT_LINE            DB                                      ;[$D248]

RAM_D249                        DSB 6   ; UNUSED                        ;[$D249]

; absolute address of the block mappings when in page 1 (i.e. $4000)
RAM_BLOCKMAPPINGS               DW                                      ;[$D24F]

RAM_VDPSCROLL_HORZ              DB                                      ;[$D251]
RAM_VDPSCROLL_VERT              DB                                      ;[$D252]

RAM_D253                        DSB 4   ; UNUSED                        ;[$D253]

RAM_BLOCK_X                     DB      ; X-pos of camera in blocks     ;[$D257]
RAM_BLOCK_Y                     DB      ; Y-pos of camera in blocks     ;[$D258]

RAM_D259                        DB      ; UNUSED                        ;[$D259]

RAM_CAMERA_X                    DW                                      ;[$D25A]
RAM_D25C                        DB      ; UNKNOWN?? (read as $D25C/D)   ;[$D25C]
RAM_CAMERA_Y                    DW                                      ;[$D25D]

; the scroll zones define how close the player can get to the edges of the
; screen before it scrolls. note that these are offsets from the top-left
; screen corner, so the right and bottom zones are determined by how far
; left/down they begin, not their widths
RAM_SCROLLZONE_LEFT             DW                                      ;[$D25F]
RAM_SCROLLZONE_RIGHT            DW                                      ;[$D261]
RAM_SCROLLZONE_TOP              DW                                      ;[$D263]
RAM_SCROLLZONE_BOTTOM           DW                                      ;[$D265]

; to avoid 'leaps of faith', some mobs (typically moving platforms) override
; the scroll zones to allow more of the platform to be visible on screen
RAM_SCROLLZONE_OVERRIDE_LEFT    DW                                      ;[$D267]
RAM_SCROLLZONE_OVERRIDE_RIGHT   DW                                      ;[$D269]
RAM_SCROLLZONE_OVERRIDE_TOP     DW                                      ;[$D26B]
RAM_SCROLLZONE_OVERRIDE_BOTTOM  DW                                      ;[$D26D]
        
RAM_CAMERA_X_PREV               DW      ; used to check if              ;[$D26F]
RAM_CAMERA_Y_PREV               DW      ; the camera has moved          ;[$D271]

RAM_LEVEL_LEFT                  DW                                      ;[$D273]
; prevents the level scrolling past this left-most point (i.e. sets an
; effective right-hand limit to the level -- this + width of the screen)
RAM_LEVEL_RIGHT                 DW                                      ;[$D275]
RAM_LEVEL_TOP                   DW                                      ;[$D277]
RAM_LEVEL_BOTTOM                DW                                      ;[$D279]

; a point to move the camera to
RAM_CAMERA_X_GOTO               DW                                      ;[$D27B]
RAM_CAMERA_Y_GOTO               DW                                      ;[$D27D]

RAM_D27F                        DB      ; UNKNOWN ($D27F/80)            ;[$D27F]
RAM_D280                        DB      ; UNKNOWN ($D280/1)             ;[$D280]
RAM_D281                        DB      ; UNKNOWN ($D281/2)             ;[$D281]
RAM_D282                        DB      ; UNKNOWN ($D282/3)             ;[$D282]
RAM_D283                        DB      ; UNKNOWN                       ;[$D283]
RAM_D284                        DB      ; UNKNOWN ($D284/5)             ;[$D284]
RAM_D285                        DB      ; UNKNOWN ($D285/6)             ;[$D285]
RAM_D286                        DB      ; UNKNOWN                       ;[$D286]
RAM_D287                        DB      ; UNKNOWN ($D287/8)             ;[$D287]
RAM_D288                        DB      ; UNKNOWN                       ;[$D288]
RAM_D289                        DB      ; UNKNOWN - looks like flags    ;[$D289]
RAM_D28A                        DB      ; UNKNOWN                       ;[$D28A]
RAM_D28B                        DB      ; UNKNOWN                       ;[$D28B]
RAM_D28C                        DB      ; UNKNOWN                       ;[$D28C]
RAM_D28D                        DB      ; UNKNOWN ($D28D/E)             ;[$D28D]
RAM_D28E                        DB      ; UNKNOWN                       ;[$D28E]

RAM_SONIC_CURRENT_FRAME         DW                                      ;[$D28F]
RAM_SONIC_PREVIOUS_FRAME        DW                                      ;[$D291]

RAM_RING_CURRENT_FRAME          DW                                      ;[$D293]
RAM_RING_PREVIOUS_FRAME         DW                                      ;[$D295]

RAM_D297                        DB      ; UNKNOWN                       ;[$D297]
RAM_D298                        DB      ; UNKNOWN ($D298/9)             ;[$D298]
RAM_IDLE_TIMER                  DW      ; UNKNOWN                       ;[$D299]
RAM_D29B                        DW      ; UNKNOWN                       ;[$D29B]
RAM_D29D                        DW      ; UNKNOWN                       ;[$D29D]

RAM_TIME                        DW      ; the level's time              ;[$D29F]

RAM_D2A1                        DB      ; UNKNOWN ($D2A1/2)             ;[$D2A1]
RAM_D2A2                        DB      ; UNKNOWN ($D2A2/3)             ;[$D2A2]
RAM_D2A3                        DB      ; UNKNOWN                       ;[$D2A3]

RAM_CYCLEPALETTE_COUNTER        DB      ; counter for applying below    ;[$D2A4]
RAM_CYCLEPALETTE_SPEED          DB      ; no.frames between palettes    ;[$D2A5]

RAM_CYCLEPALETTE_INDEX          DW      ; current palette within cycle  ;[$D2A6]
RAM_CYCLEPALETTE_POINTER        DW      ; addr. of current palette      ;[$D2A8]

RAM_RINGS                       DB      ; player's ring count           ;[$D2AA]

RAM_D2AB                        DW      ; UNKNOWN                       ;[$D2AB]
RAM_D2AD                        DW      ; UNKNOWN                       ;[$D2AD]
RAM_D2AF                        DW      ; UNKNOWN                       ;[$D2AF]
RAM_D2B1                        DW      ; UNKNOWN                       ;[$D2B1]
RAM_D2B3                        DB      ; UNKNOWN                       ;[$D2B3]

RAM_ACTIVESPRITECOUNT           DB      ; no.hardware sprites "in use"  ;[$D2B4]

RAM_D2B5                        DW      ; UNKNOWN                       ;[$D2B5]
RAM_D2B7                        DW      ; UNKNOWN                       ;[$D2B7]
RAM_D2B9                        DB      ; UNKNOWN                       ;[$D2B9]

RAM_SCORE_MILLIONS              DB                                      ;[$D2BA]
RAM_SCORE_THOUSANDS             DB                                      ;[$D2BB]
RAM_SCORE_HUNDREDS              DB                                      ;[$D2BC]
RAM_SCORE_TENS                  DB                                      ;[$D2BD]

RAM_LAYOUT_BUFFER               DSB 5                                   ;[$D2BE]

RAM_D2C3                        DSB 11  ; UNKNOWN - text in RAM?        ;[$D2C3]

RAM_TIME_MINUTES                DB      ; level timer - minutes         ;[$D2CE]
RAM_TIME_SECONDS                DB      ; level timer - seconds         ;[$D2CF]
RAM_TIME_FRAMES                 DB      ; level timer - frames          ;[$D2D0]

RAM_D2D1                        DB      ; UNUSED                        ;[$D2D1]

; the previous song played is checked during level load to avoid starting
; the same song again (for example, when teleporting in Scrap Brain)
RAM_PREVIOUS_MUSIC              DB                                      ;[$D2D2]

RAM_D2D3                        DB      ; UNKNOWN                       ;[$D2D3]

RAM_LEVEL_SOLIDITY              DB                                      ;[$D2D4]

RAM_D2D5                        DW      ; UNKNOWN                       ;[$D2D5]
RAM_D2D7                        DW      ; UNKNOWN                       ;[$D2D7]
RAM_D2D9                        DW      ; UNKNOWN                       ;[$D2D9]

RAM_WATERLINE                   DB                                      ;[$D2DB]

RAM_D2DC                        DW      ; UNKNOWN                       ;[$D2DC]
RAM_D2DE                        DB      ; UNKNOWN                       ;[$D2DE]
RAM_D2DF                        DB      ; UNKNOWN                       ;[$D2DF]
RAM_D2E0                        DB      ; UNKNOWN                       ;[$D2E0]
RAM_D2E1                        DB      ; UNKNOWN                       ;[$D2E1]
RAM_D2E2                        DW      ; UNKNOWN                       ;[$D2E2]
RAM_D2E4                        DW      ; UNKNOWN                       ;[$D2E4]
RAM_D2E6                        DW      ; UNKNOWN                       ;[$D2E6]
RAM_D2E8                        DB      ; UNKNOWN                       ;[$D2E8]
RAM_D2E9                        DW      ; UNKNOWN                       ;[$D2E9]

RAM_D2EB                        DB      ; UNUSED                        ;[$D2EB]

RAM_D2EC                        DB      ; used by boss objects          ;[$D2EC]
RAM_D2ED                        DW      ; UNKNOWN                       ;[$D2ED]

RAM_D2EF                        DSB 3   ; UNUSED                        ;[$D2EF]

RAM_D2F2                        DB      ; used in `loadMobList:`        ;[$D2F2]
RAM_D2F3                        DB      ; used by Sonic                 ;[$D2F3]

RAM_D2F4                        DSB 3                                   ;[$D2F4]

RAM_D2F7                        DB      ; used by Sonic                 ;[$D2F7]

RAM_D2F8                        DSB 3   ; UNUSED                        ;[$F2F8]

RAM_D2FB                        DB                                      ;[$D2FB]

; a copy of the level music index is kept so that the music can be started
; again (?) after other sound events like invincibility
RAM_LEVEL_MUSIC                 DB                                      ;[$D2FC]

RAM_SCORE_1UP                   DB      ; points (x1000) for exta life  ;[$D2FD]
RAM_D2FE                        DB                                      ;[$D2FE]
RAM_D2FF                        DB                                      ;[$D2FF]

RAM_D300                        DSB 2   ; UNUSED

RAM_D302                        DB                                      ;[$D302]
RAM_D303                        DSB 2                                   ;[$D303]

; these are a series of bit flags,
; each set assigns one bit per-level
RAM_D305                        DSB 6   ; set by life monitor           ;[$D305]
RAM_D30B                        DSB 6   ; set by emerald                ;[$D30B]
RAM_D311                        DSB 6   ; set by continue monitor       ;[$D311]
RAM_D317                        DSB 6   ; set by switch                 ;[$D317]

RAM_D31D                        DW                                      ;[$D31D]
RAM_D31F                        DW      ; used by Sonic                 ;[$D31F]
RAM_D321                        DB      ; used by Sonic                 ;[$D321]

RAM_D322                        DB      ; used in credits screen?       ;[$D322]

; note: 11 bytes is typical of text storage
RAM_D323                        DSB 11  ; UNUSED                        ;[$D323]

; 2-bytes per level, 19 levels (excluding warps and special stages)
RAM_D32E                        DSW 19                                  ;[$D32E]

; the level's header is copied here, though little of it seems actually used;
; other addresses are used as duplicates of these values. NOTE: 40 bytes are
; copied instead of 37, the header was probably reduced during development)
RAM_LEVEL_HEADER                DSB 40                                  ;[$D354]
        ;.solidity              ; UNUSED                                ;[$D354] 
        ;.floorWidth            ; UNUSED                                ;[$D355] 
        ;.floorHeight           ; UNUSED                                ;[$D357] 
        ;.levelLeft             ; UNUSED                                ;[$D359] 
        ;.levelRight            ; UNUSED                                ;[$D35B] 
        ;.levelTop              ; UNUSED                                ;[$D35D] 
        ;.levelBottom           ; UNUSED                                ;[$D35F] 
        ;.startX                ; UNUSED                                ;[$D361] 
        ;.startY                ; UNUSED                                ;[$D362] 
        ;.floorLayout           ; UNUSED                                ;[$D363] 
        ;.floorSize             ; UNUSED                                ;[$D365] 
        ;.blockMapping          ; UNUSED                                ;[$D367] 
        ;.levelArt              ; UNUSED                                ;[$D369] 
        ;.spriteArt             ; UNUSED                                ;[$D36B] 
        ;.bank                  ; UNUSED                                ;[$D36D] 
        ;.initialPalette        ; UNUSED                                ;[$D36E] 
        ;.cycleSpeed            ; UNUSED                                ;[$D36F] 
        ;.cycleCount            ; UNUSED                                ;[$D370] 
        ;.cyclePalette          ; UNUSED                                ;[$D371] 
        ;.objectLayout          ; UNUSED                                ;[$D372] 
        ;.scrollRingFlags       ; UNUSED                                ;[$D374] 
        ;.underwaterFlag        ; UNUSED                                ;[$D375] 
        ;.timeLightningFlags    ; UNUSED                                ;[$D376] 
        ;.zero                  ; UNUSED                                ;[$D377] 
        ;.music                 ; UNUSED                                ;[$D378] 

RAM_D379                        DSB 3   ; UNUSED                        ;[$D379]

; a list of the active mobs in the level?
RAM_ACTIVEMOBS                  DSW 32                                  ;[$D37C]

; a working-copy of the palette, for fade effects
RAM_PALETTE                     DSB 32                                  ;[$D3BC]

RAM_D3DE                        DSB 32  ; UNUSED                        ;[$D3DE]

; mobs: the 32 mobs in the level begin here:

; the player is a mob like any other and has reserved parameters in memory
RAM_SONIC                       INSTANCEOF Mob                          ;[$D3FC]
        ;.type                                                          ;[$D3FC]
        ;.Xsubpixel                                                     ;[$D3FD]
        ;.X                                                             ;[$D3FE]
        ;.Ysubpixel                                                     ;[$D400]
        ;.Y                                                             ;[$D401]
        ;.Xspeed                                                        ;[$D403]
        ;.Xdirection                                                    ;[$D405]
        ;.Yspeed                                                        ;[$D406]
        ;.Ydirecton                                                     ;[$D408]
        ;.width                                                         ;[$D409]
        ;.height                                                        ;[$D40A]
        ;.spriteLayout                                                  ;[$D40B]
        ;.unknown11                                                     ;[$D40D]
        ;.unknown12                                                     ;[$D40E]
        ;.unknown13                                                     ;[$D40F]
        ;.unknown14                                                     ;[$D410]
        ;.unknown15                                                     ;[$D411]
        ;.unknown16                                                     ;[$D412]
        ;.unknown17                                                     ;[$D413]
        ;.flags                                                         ;[$D414]
        ;.unknown19                                                     ;[$D415]
            
; remaining 31 mobs are here
RAM_MOBS                        INSTANCEOF Mob 31               ;[$D416]-[$D73C]

.ENDS