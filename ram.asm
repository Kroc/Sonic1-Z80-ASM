
.STRUCT	Vars
;=======================================================================================================================
/*	the original programmers used the IY register as a short-cut to $D200 to access commonly used variables and
	flags */
        
	;program flow control / loading flags?
	flags0                          DB                      ;IY+$00
	;---------------------------------------------------------------------------------------------------------------
		;waitForInterrupt      				;0 - `waitForInterrupt:` will loop until bit is set
		;                      				;1 - unknown (set at level load)
		;                      				;2 - unused?
		;loadPalette           				;3 - flag to load palette on IRQ
		;                      				;4 - unused?
		;                      				;5 - unknown -- player control enabled/disabled?
		;cameraMoveHoriz       				;6 - set when the camera has moved left
		;cameraMoveVert        				;7 - set when the camera has moved up
	
	temp                            DB                    	;IY+$01
	;this is used only as the comparison byte in `loadFloorLayout:`
	
	flags2                          DB                      ;IY+$02
	;---------------------------------------------------------------------------------------------------------------
		;                                               ;0 - unknown
		;                                               ;1 - unknown
		;                                               ;2 - unknown
	
	joypad                          DB                      ;IY+$03
	;Value of joypad port 1 - the bits are 1 for unpressed and 0 for pressed
	;---------------------------------------------------------------------------------------------------------------
		;pad1up                                         ;0 - joypad 1 up
		;pad1down                                       ;1 - joypad 1 down
		;pad1left                                       ;2 - joypad 1 left
		;pad1right                                      ;3 - joypad 1 right
		;pad1A                                          ;4 - joypad button A
		;pad1B                                          ;5 - joypad button B
	
	unused                          DB                    	;IY+$04
	;This does not appear referenced in any code
	
	scrollRingFlags                 DB                      ;IY+$05
	;Taken from the level header, this controls screen scrolling and the presence of the "rings" count on the HUD
	;---------------------------------------------------------------------------------------------------------------
		;dead                                           ;0 - death flag
		;demo                                           ;1 - demo mode
		;rings                                          ;2 - ring count displayed in HUD, visible in the level
		;scrollRight                                    ;3 - automatic scrolling to the right
		;scrollUp                                       ;4 - automatic scrolling upwards
		;scrollSmooth                                   ;5 - smooth scrolling
		;scrollWave                                     ;6 - up and down wave scrolling
		;noScrollDown                                   ;7 - screen does not scroll down
	
	flags6                          DB                      ;IY+$06
	;---------------------------------------------------------------------------------------------------------------
		;                                               ;0 - make Sonic upside down! (incomplete functionality)
		;                                               ;1 - disable controls
		;                                               ;2 - unknown
		;                                               ;3 - clock is active when set
		;                                               ;4 - unknown
		;                                               ;5 - shield active
		;                                               ;6 - Sonic is in damage state
		;                                               ;7 - level underwater flag (enables water line)
	
	timeLightningFlags              DB                       ;IY+$07
	;Taken from the level header, this controls the presence of the time on the HUD
	;and if the lightning effect is in use
	;---------------------------------------------------------------------------------------------------------------
		;                                               ;0 - centres the time in the screen on special stages
		;                                               ;1 - enables the lightning effect
		;                                               ;2 - unknown
		;                                               ;3 - unknown
		;                                               ;4 - use boss underwater palette (Labyrinth Act 3)
		;                                               ;5 - time is displayed in the HUD
		;                                               ;6 - locks the screen, no scrolling
		;                                               ;7 - is special stage?
	
	unknown0                        DB                      ;IY+$08
	;Part of the level header -- always "0" for all levels, but unknown function
	;---------------------------------------------------------------------------------------------------------------
		;                                               ;0 - unused
		;                                               ;1 - unknown, set at "._4e88"
	
	flags9                          DB                      ;IY+$09
	;---------------------------------------------------------------------------------------------------------------
		;                                               ;0 - unknown
		;                                               ;1 - enables interrupts during `decompressArt`
		;                                               ;2 - set when special stage timer reaches zero
		;                                               ;3 - unknown -- reset at ":_1719"
	
	spriteUpdateCount               DB                    	;IY+$0A, # sprites requiring updates
	origScrollRingFlags             DB                    	;IY+$0B, copy made during level loading UNUSED
	origFlags6                      DB                    	;IY+$0C, copy made during level loading
	
	;currently unknown purpose
	unknown_0D                      DB                    	;IY+$0D
.ENDST

.STRUCT Mob							;26 bytes
;=======================================================================================================================
/*	The data-structure for a mob (Movable Object Block); the game's interactive objects and enemies.
	*/     
	type                           	DB                   	;IX+$00    - the object type index number
	Xsubpixel                      	DB                   	;IX+$01    - sub-pixel accuracy of X position
	X                              	DW                   	;IX+$02/03 - in px
	Ysubpixel                      	DB                   	;IX+$04    - sub-pixel accuracy of Y position
	Y                              	DW                   	;IX+$05/06 - in px
	Xspeed                         	DW                   	;IX+$07/08 - in px, signed (i.e. $F??? = left)
	Xdirection                     	DB                   	;IX+$09    - $FF for left, else $00
	Yspeed                         	DW                   	;IX+$0A/0B - in px, signed  (i.e. $F??? = up)
	Ydirection                     	DB                   	;IX+$0C    - $FF for up, else $00
	width                          	DB                   	;IX+$0D    - in px
	height                         	DB                   	;IX+$0E    - in px
	spriteLayout                   	DW                   	;IX+$0F/10 - address to current sprite layout
	unknown11                      	DB    
	unknown12                      	DB    
	unknown13                      	DB    
	unknown14                      	DB    
	unknown15                      	DB    
	unknown16                      	DB    
	unknown17                      	DB    
	flags                          	                        ;various mob flags
		;unknown0              	
		;unknown1              	
		;unknown2              	
		;unknown3              	
		;underwater            	            		;4 - underwater flag
		;noCollision           	            		;5 - whether the mob adheres to the floor or not
		;unknown6              	
		;unknown7              	
		;
	unknown19                      	DB                    	;unused?
.ENDST

;name                                   size                    note                                            addr
;=======================================================================================================================
.RAMSECTION "sonic1"			SLOT 3
	;the floor layout (i.e. the tiles Sonic runs around on). a 'level' is a sub-portion of this floor layout
	;since sometimes multiple levels are crammed into one layout (such as the special stages)
	FLOORLAYOUT                     DSB 4096                                                            	;[$C000]

	;X/Y/I data for the 64 sprites
	SPRITETABLE                     DSB 64 * 3                                                          	;[$D000]
	
	D0C0                            DSB 64              	;UNUSED                                        	;[$D0C0]
	
	;when the screen scrolls and new tiles need to be filled in, they are pulled from these
	;caches which have the necessary tiles already in horizontal / vertical order for speed
	;(NOTE: though these are 128 bytes each, I don't think that much is used)
	OVERSCROLLCACHE_VERT            DSB 128                                                             	;[$D100]
	OVERSCROLLCACHE_HORZ            DSB 128                                                             	;[$D180]

	;throughout the codebase, IY is used as a shorthand to $D200 where many commonly used RAM variables exist.
	;therefore these use the `[IY`vars+vars.abc]` form of addressing. for the sake of completeness, we'll also
	;define the absolute location of these variables too, i.e. `VARS.abc`
	VARS                            INSTANCEOF Vars                                                         ;[$D200]

	;these temporary variables are reused throughout, some times for passing extra parameters
	;to a function and sometimes as extra working space within a function
	TEMP1                           DB                                                                   	;[$D20F]
	TEMP3                           DW                                                                   	;[$D210]
	TEMP4                           DB                                                                   	;[$D212]
	TEMP5                           DB                                                                   	;[$D213]
	TEMP6                           DB                                                                   	;[$D214]
	TEMP7                           DB                                                                   	;[$D215]

	D216                            DW                   	;UNKNOWN                                       	;[$D216]

	VDPREGISTER_0                   DB                   	;RAM cache of the VDP register 0               	;[$D218]
	VDPREGISTER_1                   DB                   	;RAM cache of the VDP register 1               	;[$D219]
	;though the code copies the VDP registers here, these ones are not recalled
	VDPREGISTER_2                   DB                                                                   	;[$D21A]
	VDPREGISTER_3                   DB                                                                   	;[$D21B]
	VDPREGISTER_4                   DB                                                                   	;[$D21C]
	VDPREGISTER_5                   DB                                                                   	;[$D21D]
	VDPREGISTER_6                   DB                                                                   	;[$D21E]
	VDPREGISTER_7                   DB                                                                   	;[$D21F]
	VDPREGISTER_8                   DB                                                                   	;[$D220]
	VDPREGISTER_9                   DB                                                                   	;[$D221]
	VDPREGISTER_10                  DB                                                                   	;[$D222]

	FRAMECOUNT                      DW                   	;a 16-bit continual frame count                	;[$D223]

	;referenced only by unused function `unused_0323:`
	UNUSED_D225                     DW                                                                   	;[$D225]
	UNUSED_D227                     DW                                                                   	;[$D227]
	UNUSED_D229                     DW                                                                   	;[$D229]

	;`loadPaletteOnInterrupt:` and `loadPaletteFromInterrupt:` use these to pass parameters
	LOADPALETTE_ADDRESS             DW                                                                   	;[$D22B]
	D22D                            DW                   	;UNUSED                                        	;[$D22D]
	LOADPALETTE_FLAGS               DB                                                                   	;[$D22F]

	;`loadPalette:` uses these to pass the addresses of the tile/sprite palettes to load
	LOADPALETTE_TILE                DW                                                                   	;[$D230]
	LOADPALETTE_SPRITE              DW                                                                   	;[$D232]

	D234                            DB                   	;UNUSED                                        	;[$D234]
	
	;these keep track of which bank is in which slot; slot 0 is always bank 0
	SLOT1                           DB                                                                   	;[$D235]
	SLOT2                           DB                                                                   	;[$D236]
	
	D237                            DB                   	;UNUSED                                        	;[$D237]
	
	LEVEL_FLOORWIDTH                DW                   	;width of the floor layout in blocks           	;[$D238]
	LEVEL_FLOORHEIGHT               DW                   	;height of the floor layout in blocks          	;[$D23A]
	
	SPRITETABLE_ADDR                DW                   	;pointer to which sprite table to use          	;[$D23C]
	
	CURRENT_LEVEL                   DB                                                                   	;[$D23E]
	
	D23F                            DB                   	;UNKNOWN                                       	;[$D23F]
	D240                            DW                   	;UNKNOWN                                       	;[$D240]
	D242                            DW                   	;UNKNOWN                                       	;[$D242]
	D244                            DW                   	;UNKNOWN                                       	;[$D244]
	
	LIVES                           DB                   	;player's lives count                          	;[$D246]
	
	RASTERSPLIT_STEP                DB                                                                   	;[$D247]
	RASTERSPLIT_LINE                DB                                                                   	;[$D248]
	
	D249                            DSB 6               	;UNUSED                                        	;[$D249]
	
	;absolute address of the block mappings when in page 1 (i.e. $4000)
	BLOCKMAPPINGS                   DW                                                                   	;[$D24F]
	
	VDPSCROLL_HORZ                  DB                                                                   	;[$D251]
	VDPSCROLL_VERT                  DB                                                                   	;[$D252]
	
	D253                            DSB 4               	;UNUSED                                        	;[$D253]
	
	BLOCK_X                         DB                   	;number of blocks across the camera is          ;[$D257]
	BLOCK_Y                         DB                   	;number of blocks down the camera is            ;[$D258]
	
	D259                            DB                   	;UNUSED                                        	;[$D259]
	
	CAMERA_X                        DW                                                                   	;[$D25A]
	D25C                            DB                   	;UNKNOWN?? (read as $D25C/D)                   	;[$D25C]
	CAMERA_Y                        DW                                                                   	;[$D25D]
	
	;the scroll zones define how close the player can get to the edges of the screen before it scrolls.
	;note that these are offsets from the top-left screen corner, so the right and bottom zones are determined
	;by how far left/down they begin, not their widths
	SCROLLZONE_LEFT                 DW                                                                   	;[$D25F]
	SCROLLZONE_RIGHT                DW                                                                   	;[$D261]
	SCROLLZONE_TOP                  DW                                                                   	;[$D263]
	SCROLLZONE_BOTTOM               DW                                                                   	;[$D265]
	
	;to avoid 'leaps of faith', some mobs (typically moving platforms) override the scroll zones to allow more of the
	;platform to be visible on screen
	SCROLLZONE_OVERRIDE_LEFT        DW                                                                   	;[$D267]
	SCROLLZONE_OVERRIDE_RIGHT       DW                                                                   	;[$D269]
	SCROLLZONE_OVERRIDE_TOP         DW                                                                   	;[$D26B]
	SCROLLZONE_OVERRIDE_BOTTOM      DW                                                                   	;[$D26D]
	
	CAMERA_X_PREV                   DW                   	;used to check if the camera has moved         	;[$D26F]
	CAMERA_Y_PREV                   DW                   	;used to check if the camera has moved         	;[$D271]
	
	LEVEL_LEFT                      DW                                                                   	;[$D273]
	;prevents the level scrolling past this left-most point
	;(i.e. sets an effective right-hand limit to the level -- this + width of the screen)
	LEVEL_RIGHT                     DW                                                                   	;[$D275]
	LEVEL_TOP                       DW                                                                   	;[$D277]
	LEVEL_BOTTOM                    DW                                                                   	;[$D279]
	
	;a point to move the camera to
	CAMERA_X_GOTO                   DW                                                                   	;[$D27B]
	CAMERA_Y_GOTO                   DW                                                                   	;[$D27D]
	
	D27F                            DB                   	;UNKNOWN ($D27F/80)                            	;[$D27F]
	D280                            DB                   	;UNKNOWN ($D280/1)                             	;[$D280]
	D281                            DB                   	;UNKNOWN ($D281/2)                             	;[$D281]
	D282                            DB                   	;UNKNOWN ($D282/3)                             	;[$D282]
	D283                            DB                   	;UNKNOWN                                       	;[$D283]
	D284                            DB                   	;UNKNOWN ($D284/5)                             	;[$D284]
	D285                            DB                   	;UNKNOWN ($D285/6)                             	;[$D285]
	D286                            DB                   	;UNKNOWN                                       	;[$D286]
	D287                            DB                   	;UNKNOWN ($D287/8)                             	;[$D287]
	D288                            DB                   	;UNKNOWN                                       	;[$D288]
	D289                            DB                   	;UNKNOWN - looks like flags                    	;[$D289]
	D28A                            DB                   	;UNKNOWN                                       	;[$D28A]
	D28B                            DB                   	;UNKNOWN                                       	;[$D28B]
	D28C                            DB                   	;UNKNOWN                                       	;[$D28C]
	D28D                            DB                   	;UNKNOWN ($D28D/E)                             	;[$D28D]
	D28E                            DB                   	;UNKNOWN                                       	;[$D28E]
	
	SONIC_CURRENT_FRAME             DW                                                                   	;[$D28F]
	SONIC_PREVIOUS_FRAME            DW                                                                   	;[$D291]
	
	RING_CURRENT_FRAME              DW                                                                   	;[$D293]
	RING_PREVIOUS_FRAME             DW                                                                   	;[$D295]
	
	D297                            DB                   	;UNKNOWN                                       	;[$D297]
	D298                            DB                   	;UNKNOWN ($D298/9)                             	;[$D298]
	IDLE_TIME                       DW                   	;UNKNOWN                                       	;[$D299]
	D29B                            DW                   	;UNKNOWN                                       	;[$D29B]
	D29D                            DW                   	;UNKNOWN                                       	;[$D29D]
	
	TIME                            DW                   	;the level's time                              	;[$D29F]
	
	D2A1                            DB                   	;UNKNOWN ($D2A1/2)                             	;[$D2A1]
	D2A2                            DB                   	;UNKNOWN ($D2A2/3)                             	;[$D2A2]
	D2A3                            DB                   	;UNKNOWN                                       	;[$D2A3]
	
	CYCLEPALETTE_COUNTER            DB                   	;counter for applying the speed                	;[$D2A4]
	CYCLEPALETTE_SPEED              DB                   	;number of frames between each palette         	;[$D2A5]
	
	CYCLEPALETTE_INDEX              DW                   	;current palette in the cycle palette          	;[$D2A6]
	CYCLEPALETTE_POINTER            DW                   	;address where cycle palette begins            	;[$D2A8]
	
	RINGS                           DB                   	;player's ring count                           	;[$D2AA]
	
	D2AB                            DW                   	;UNKNOWN                                       	;[$D2AB]
	D2AD                            DW                   	;UNKNOWN                                       	;[$D2AD]
	D2AF                            DW                   	;UNKNOWN                                       	;[$D2AF]
	D2B1                            DW                   	;UNKNOWN                                       	;[$D2B1]
	D2B3                            DB                   	;UNKNOWN                                       	;[$D2B3]
	
	ACTIVESPRITECOUNT               DB                   	;number of hardware sprites "in use"           	;[$D2B4]
	
	D2B5                            DW                   	;UNKNOWN                                       	;[$D2B5]
	D2B7                            DW                   	;UNKNOWN                                       	;[$D2B7]
	D2B9                            DB                   	;UNKNOWN                                       	;[$D2B9]
	
	SCORE_MILLIONS                  DB                                                                   	;[$D2BA]
	SCORE_THOUSANDS                 DB                                                                   	;[$D2BB]
	SCORE_HUNDREDS                  DB                                                                   	;[$D2BC]
	SCORE_TENS                      DB                                                                   	;[$D2BD]
	
	LAYOUT_BUFFER                   DSB 5                                                               	;[$D2BE]
	
	D2C3                            DSB 11              	;UNKNOWN - probably text in RAM                	;[$D2C3]
	
	TIME_MINUTES                    DB                   	;level timer - minutes                         	;[$D2CE]
	TIME_SECONDS                    DB                   	;level timer - seconds                         	;[$D2CF]
	TIME_FRAMES                     DB                   	;level timer - frames                          	;[$D2D0]
	
	D2D1                            DB                   	;UNUSED                                        	;[$D2D1]
	
	;the previous song played is checked during level load to avoid starting
	;the same song again (for example, when teleporting in Scrap Brain)
	PREVIOUS_MUSIC                  DB                                                                   	;[$D2D2]
	
	D2D3                            DB                   	;UNKNOWN                                       	;[$D2D3]
	
	LEVEL_SOLIDITY                  DB                                                                   	;[$D2D4]
	
	D2D5                            DW                   	;UNKNOWN                                        ;[$D2D5]
	D2D7                            DW                   	;UNKNOWN                                        ;[$D2D7]
	D2D9                            DW                   	;UNKNOWN                                        ;[$D2D9]
	
	WATERLINE                       DB                                                                   	;[$D2DB]
	
	D2DC                            DW                   	;UNKNOWN                                        ;[$D2DC]
	D2DE                            DB                   	;UNKNOWN                                        ;[$D2DE]
	D2DF                            DB                   	;UNKNOWN                                        ;[$D2DF]
	D2E0                            DB                   	;UNKNOWN                                        ;[$D2E0]
	D2E1                            DB                   	;UNKNOWN                                        ;[$D2E1]
	D2E2                            DW                   	;UNKNOWN                                        ;[$D2E2]
	D2E4                            DW                   	;UNKNOWN                                        ;[$D2E4]
	D2E6                            DW                   	;UNKNOWN                                        ;[$D2E6]
	D2E8                            DB                   	;UNKNOWN                                        ;[$D2E8]
	D2E9                            DW                   	;UNKNOWN                                        ;[$D2E9]
	
	D2EB                            DB                   	;UNUSED                                         ;[$D2EB]
	
	D2EC                            DB                   	;used by boss objects                           ;[$D2EC]
	D2ED                            DW                   	;UNKNOWN                                        ;[$D2ED]
	
	D2EF                            DSB 3               	;UNUSED                                         ;[$D2EF]
	
	D2F2                            DB                   	;used as temporary in `loadMobList:`         	;[$D2F2]
	D2F3                            DB                   	;used by Sonic                                  ;[$D2F3]
	
	D2F4                            DSB 3                                                               	;[$D2F4]
	
	D2F7                            DB                   	;used by Sonic                                  ;[$D2F7]
	
	D2F8                            DSB 3               	;UNUSED                                         ;[$F2F8]
	
	D2FB                            DB                                                                   	;[$D2FB]
	
	;a copy of the level music index is kept so that the music can be started
	;again (?) after other sound events like invincibility
	LEVEL_MUSIC                     DB                                                                   	;[$D2FC]
	
	SCORE_1UP                       DB                   	;number of thousands of pts for exta life       ;[$D2FD]
	D2FE                            DB                                                                   	;[$D2FE]
	D2FF                            DB                                                                   	;[$D2FF]
	
	D300                            DSB 2               	;UNUSED
	
	D302                            DB                                                                   	;[$D302]
	
	D303                            DSB 2                                                                 	;[$D303]
	
	;these are a series of bit flags, each set assigns one bit per-level
	D305                            DSB 6               	;set by life monitor                            ;[$D305]
	D30B                            DSB 6               	;set by emerald                                 ;[$D30B]
	D311                            DSB 6               	;set by continue monitor                        ;[$D311]
	D317                            DSB 6               	;set by switch                                  ;[$D317]
	
	D31D                            DW                                                                   	;[$D31D]
	D31F                            DW                   	;used by Sonic                                  ;[$D31F]
	D321                            DB                   	;used by Sonic                                  ;[$D321]
	
	D322                            DB                   	;used in credits screen?                        ;[$D322]
	
	;note: 11 bytes is typical of text storage
	D323                            DSB 11                  ;UNUSED
	
	;2-bytes per level, 19 levels (excluding warps and special stages)
	D32E				DSW 19                                                              	;[$D32E]
	
	;the level's header is copied here, though little of it seems actually used;
	;other addresses are used as duplicates of these values. NOTE: 40 bytes are
	;copied instead of 37, the header was probably reduced during development)
	;LEVEL_HEADER                   %levelHeader                                                            ;[$D354]
					;.solidity             	;UNUSED                                        	;[$D354] 
					;.floorWidth           	;UNUSED                                        	;[$D355] 
					;.floorHeight          	;UNUSED                                        	;[$D357] 
					;.levelLeft            	;UNUSED                                        	;[$D359] 
					;.levelRight           	;UNUSED                                        	;[$D35B] 
					;.levelTop             	;UNUSED                                        	;[$D35D] 
					;.levelBottom          	;UNUSED                                        	;[$D35F] 
					;.startX               	;UNUSED                                        	;[$D361] 
					;.startY               	;UNUSED                                        	;[$D362] 
					;.floorLayout          	;UNUSED                                        	;[$D363] 
					;.floorSize            	;UNUSED                                        	;[$D365] 
					;.blockMapping         	;UNUSED                                        	;[$D367] 
					;.levelArt             	;UNUSED                                        	;[$D369] 
					;.spriteArt            	;UNUSED                                        	;[$D36B] 
					;.bank                 	;UNUSED                                        	;[$D36D] 
					;.initialPalette       	;UNUSED                                        	;[$D36E] 
					;.cycleSpeed           	;UNUSED                                        	;[$D36F] 
					;.cycleCount           	;UNUSED                                        	;[$D370] 
					;.cyclePalette         	;UNUSED                                        	;[$D371] 
					;.objectLayout         	;UNUSED                                        	;[$D372] 
					;.scrollRingFlags      	;UNUSED                                        	;[$D374] 
					;.underwaterFlag       	;UNUSED                                        	;[$D375] 
					;.timeLightningFlags   	;UNUSED                                        	;[$D376] 
					;.zero                 	;UNUSED                                        	;[$D377] 
					;.music                	;UNUSED                                        	;[$D378] 
	
	D379                            DSB 3               	;UNUSED                                         ;[$D379]
	
	;a list of the active mobs in the level?
	ACTIVEMOBS                      DSW 32                                                              	;[$D37C]
	
	;a working-copy of the palette, for fade effects
	PALETTE                         DSB 32                                                              	;[$D3BC]
	
	D3DE                            DSB 32                	;UNUSED                                       	;[$D3DE]

	;mobs: the 32 mobs in the level begin here:

	;the player is a mob like any other and has reserved parameters in memory
	SONIC                          	INSTANCEOF Mob								;[$D3FC]
					;.type                                                                 	;[$D3FC]
					;.Xsubpixel                                                            	;[$D3FD]
					;.X                                                                    	;[$D3FE]
					;.Ysubpixel                                                            	;[$D400]
					;.Y                                                                    	;[$D401]
					;.Xspeed                                                               	;[$D403]
					;.Xdirection                                                           	;[$D405]
					;.Yspeed                                                               	;[$D406]
					;.Ydirecton                                                            	;[$D408]
					;.width                                                                	;[$D409]
					;.height                                                               	;[$D40A]
					;.spriteLayout                                                         	;[$D40B]
					;.unknown11                                                            	;[$D40D]
					;.unknown12                                                            	;[$D40E]
					;.unknown13                                                            	;[$D40F]
					;.unknown14                                                            	;[$D410]
					;.unknown15                                                            	;[$D411]
					;.unknown16                                                            	;[$D412]
					;.unknown17                                                            	;[$D413]
					;.flags                                                                	;[$D414]
					;.unknown19                                                            	;[$D415]
                    
	;remaining 31 mobs are here
	MOBS                           	INSTANCEOF Mob 31                                        	;[$D416]-[$D73C]
.ENDS
