;Sonic 1 Master System Disassembly
 ;created by Kroc Camen <kroc@camendesign.com>
 ;for MaSS1VE: The Master System Sonic 1 Visual Editor <github.com/Kroc/MaSS1VE>
;======================================================================================
;please use tab stops at 8 and a line width of 88 chars, thanks
;--------------------------------------------------------------------------------------

;This source code is given to the public domain
 ;whilst "SEGA" and "Sonic" are registered trademarks of Sega Enterprises, Ltd.,
 ;this is not their source code (I haven't broken into SEGA's offices ¬__¬), so not
 ;their copyright. Neither does this contain any byte-for-byte data of the original
 ;ROM (this is all ASCII codes, even the hex data parts). the fact that this text file
 ;can be processed with an algorithm and produces a file that is the same as the
 ;original ROM is also not a copyright violation -- SEGA don't own a patent on the
 ;compiling algorithm
 
;--------------------------------------------------------------------------------------
 
;this disassembly was made by using these tools:

;SMSExamine: <www.smspower.org/Development/SMSExamine>
 ;this excellent tool disassembles much of the ROM by effectively 'running' the code
 ;to determine what parts are code and what parts are data. this saved a very large
 ;amount of effort, but due to the dynamic and complex nature of code, it didn't get
 ;all of it right, therefore I used:
 
;dz80: <www.inkland.org.uk/dz80/>
 ;to do a byte-for-byte disassembly to fill in the blanks
 ;(this had to all be manually labelled!)

;WLA DX <www.villehelin.com/wla.html>
 ;I was intending to write my own Z80 assembler (in VB6!), but I have found -- after
 ;some struggling to learn it -- that WLA DX will do an excellent job

;this disassembly was made possible by earlier documentation provided by
 ;David Declerk, ValleyBell, Penta Penguin and Ravenfreak

;======================================================================================

;configure the bank boundaries. the Master System doesn't have 16 slots but this is
 ;necessary for WLA DX to stop saying that the data is "overflowing the boundary"

 .MEMORYMAP		
	SLOTSIZE $4000	
	SLOT 0   $0000	; CODE
	SLOT 1   $4000	; CODE
	SLOT 2   $8000	; CODE
	SLOT 3   $C000	; CODE (sound driver) + Music
	SLOT 4  $10000	; Block Mappings
	SLOT 5  $14000	; Block Mappings
			; Level Headers
			; Object Layout
			; Floor Layout
	SLOT 6  $18000	; Floor Layout
	SLOT 7  $1C000	; Floor Layout
	SLOT 8  $20000	; Sonic Sprites
	SLOT 9  $24000	; Sonic Sprites
			; Tiles and Sprites
	SLOT 10 $28000	; Tiles and Sprites
	SLOT 11 $2C000	; Tiles and Sprites
	SLOT 12 $30000	; Tiles and Sprites
			; Level Art
	SLOT 13 $34000	; Level Art
	SLOT 14 $38000	; Level Art
	SLOT 15 $3C000	; Level Art
	DEFAULTSLOT 0
.ENDME

.ROMBANKMAP
	BANKSTOTAL 16
	BANKSIZE $4000
	BANKS 16
.ENDRO

;NOTE: YOU WILL NEED TO PROVIDE YOUR OWN SONIC 1 ROM HERE TO FILL IN THE DATA BANKS
.BACKGROUND "ROM.sms"

;======================================================================================

.DEF SMS_CURRENT_SCANLINE 	$7E	;current vertical scanline from 0 to 191
.DEF SMS_SOUND_PORT		$7F	;write-only port to send data to sound chip
.DEF SMS_VDP_DATA		$BE	;VRAM data port
.DEF SMS_VDP_CONTROL		$BF	;VRAM control port

.DEF SMS_PAGE_RAM		$FFFC	;RAM select register
.DEF SMS_PAGE_0			$FFFD	;Page 0 ROM Bank
.DEF SMS_PAGE_1			$FFFE	;Page 1 ROM Bank
.DEF SMS_PAGE_2			$FFFF	;Page 2 ROM Bank

.DEF SMS_JOYPAD_1		$DC
.DEF SMS_JOYPAD_2		$DD

;Game variables in RAM:
;--------------------------------------------------------------------------------------
.DEF S1_VDPREGISTER_0		$D218	;RAM cache of the VDP register 0
.DEF S1_VDPREGISTER_1		$D219	;RAM cache of the VDP register 1

.DEF S1_PAGE_1			$D235	;used to keep track of what bank is in page 1
.DEF S1_PAGE_2			$D236	;used to keep track of what bank is in page 2

.DEF S1_CURRENT_LEVEL		$D23E

.DEF S1_LEVEL_FLOORWIDTH	$D238	;width of level floor layout in blocks
.DEF S1_LEVEL_FLOORHEIGHT	$D23A	;height of level floor layout in blocks

;level dimensions / crop
.DEF S1_LEVEL_CROPLEFT		$D273
.DEF S1_LEVEL_OFFSET_X		$D274
.DEF S1_LEVEL_WIDTH		$D276
.DEF S1_LEVEL_CROPTOP		$D277
.DEF S1_LEVEL_OFFSET_Y		$D278
.DEF S1_LEVEL_EXTENDHEIGHT	$D279
.DEF S1_LEVEL_HEIGHT		$D27A

.DEF S1_LEVEL_SOLIDITY		$D2D4

.DEF S1_RASTERSPLIT_STEP	$D247
.DEF S1_RASTERSPLIT_LINE	$D248

.DEF S1_RINGS			$D2AA	;player's ring count
.DEF S1_LIVES			$D246	;player's lives count
.DEF S1_TIME			$D29F	;the level's time

;======================================================================================

.BANK 0 SLOT 0

_START:					;[$0000]
	di				;disable interrupts
	im   1				;set the interrupt mode to 1 --
					 ;$38 will be called at 50/60Hz 

-	;wait for the scanline to reach 176 (no idea why)
	in   a, (SMS_CURRENT_SCANLINE)
	cp   176
	jr   nz, -
	jp   _init

;--------------------------------------------------------------------------------------

.ORGA $0018
_RST_18:				;[$0018]
	jp   _RST18Handler		;load a music track specified by A

.ORGA $0020
_RST_20:				;[$0020]
	jp   _LABEL_2ED_7

.ORGA $0028
_RST_28:				;[$0028]
	jp _2fe

.ORGA $0038
_RST_38:				;[$0038]
	jp   IRQHandler

; Data from 3B to 65 (43 bytes)
.db "Developed By (C) 1991 Ancient - S", $A5, "Hayashi.", $00

;____________________________________________________________________________[$0066]___

_NMI_HANDLER:
	di				;disable interrupts
	push af
	ld   a, (iy+$07)		;level time HUD / lightning flags
	xor  %00001000			;fip bit 4 (the pause bit)
	ld   (iy+$07), a		;save it back
	pop  af
	ei				;enable interrupts
	ret

;____________________________________________________________________________[$0073]___

IRQHandler:
	di				;disable interrupts during the interrupt!
	
	;push everything we're going to use to the stack so that when we return
	 ;from the interrupt we don't find that our registers have changed
	 ;mid-instruction!
	push af
	push hl
	push de
	push bc
	
	in   a, (SMS_VDP_CONTROL)	;get the status of the VDP
	
	bit  7, (iy+$06)		;check the underwater flag
	jr   z, +			;if off, skip ahead
	
	;the raster split is controlled across multiple interrupts,
	 ;a counter is used to remember at which step the procedure is at
	 ;a value of 0 means that it needs to be initialised, and then it counts
	 ;down from 3
	
	ld   a, ($D247)			;get the current raster split step
	and  a				;doesn't change the number, but updates flags
	jp   nz, _LABEL_1F2_17		;if it's not zero, deal with the particulars
	
	;--- initialise raster split --------------------------------------------------
	ld   a, ($D2DB)			;check the water line height
	and  a
	jr   z, +			;if it's zero (above the screen), skip
	
	cp   $FF			;or 255 (below the screen),
	jr   z, +			;skip
	
	;copy the water line position into the working space for the raster split.
	 ;this is to avoid the water line changing height between the multiple
	 ;interrupts needed to produce the split, I think
	ld   ($D248), a
	
	;set the line interrupt to fire at line 9 (top of the screen),
	 ;we will then set another interrupt to fire where we want the split to occur
	ld   a, $0A
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 10
	out  (SMS_VDP_CONTROL), a
	
	;enable line interrupt IRQs (bit 5 of VDP register 0)
	ld   a, (S1_VDPREGISTER_0)
	or   %00010000
	out  (SMS_VDP_CONTROL), a
	ld   a, $80
	out  (SMS_VDP_CONTROL), a
	
	;initialise the step counter for the water line raster split
	ld   a, 3
	ld   ($D247), a
	
	;------------------------------------------------------------------------------
	
+	push ix
	push iy
	
	;remember the current page 1 & 2 banks
	ld   hl, (S1_PAGE_1)
	push hl
	
	;if the main thread is not held up at the `wait` routine
	bit  0, (iy+$00)
	call nz, _LABEL_1A0_18
	;and if it is...
	bit  0, (iy+$00)
	call z, _LABEL_F7_25
	
	;I'm  not sure why the interrupts are re-enabled before we've left the
	 ;interrupt handler, but there you go, it obviously works
	ei
	
	;there's an extra bank of code located at ROM:$C000-$FFFF,
	 ;page this into Z80:$4000-$7FFF
	ld   a, :_c000
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	call _c000
	
	call readJoypad
	bit  4, (iy+$03)		;joypad button A?
	call z, _setJoypadButtonB	;set joypad button B too
	
	call _LABEL_625_57
	
	;check for the reset button
	in   a, (SMS_JOYPAD_2)		;read the second joypad port which has extra
					 ;bits for lightgun / reset button
	and  %00010000			;check bit 4
	jp   z, _START			;reset!
	
	;return pages 1 & 2 to the banks before we started messing around here
	pop  hl
	ld   (SMS_PAGE_1), hl
	ld   (S1_PAGE_1), hl
	
	;pull everything off the stack so that the code that was running
	 ;before the interrupt doesn't explode
	pop  iy
	pop  ix
	pop  bc
	pop  de
	pop  hl
	pop  af
	ret

;____________________________________________________________________________[$00F2]___

_setJoypadButtonB:
	res  5, (iy+$03)		;set joypad button B as on
	ret
	
;____________________________________________________________________________[$00F7]___
	
_LABEL_F7_25:
	;blank the screen (remove bit 6 of VDP register 1)
	ld   a, (S1_VDPREGISTER_1)	;get our cache value from RAM
	and  %10111111			;remove bit 6
	out  (SMS_VDP_CONTROL), a	;write the value,
	ld   a, $80 + 1			;followed by the register number
	out  (SMS_VDP_CONTROL), a
	
	;horizontal scroll
	ld   a, ($D251)
	neg				;I don't understand the reason for this
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 8			;VDP register 8
	out  (SMS_VDP_CONTROL), a
	
	;vertical scroll
	ld   a, ($D252)
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 9			;VDP register 9
	out  (SMS_VDP_CONTROL), a
	
	bit  5, (iy+$00)			
	call nz, _LABEL_7DB_26
	bit  5, (iy+$00)			
	call nz, _LABEL_174_38
	
	;turn the screen back on 
	 ;(or if it was already blank before this function, leave it blank)
	ld   a, (S1_VDPREGISTER_1)
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 1			;VDP register 1
	out  (SMS_VDP_CONTROL), a
	
	ld   a, 8			;Sonic sprites?
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	ld   a, 9
	ld   (SMS_PAGE_2), a
	ld   (S1_PAGE_2), a
	
	bit  7, (iy+$07)
	call nz, _LABEL_37E0_41
	
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (S1_PAGE_2), a
	
	;update sprite table?
	bit  1, (iy+$00)
	call nz, updateVDPSprites
	
	bit  5, (iy+$00)
	call z, _LABEL_174_38
	
	ld   a, ($D2AC)
	and  %10000000
	call z, _LABEL_38B0_51
	
	ld   a, $FF
	ld   ($D2AC), a
	
	set  0, (iy+$00)
	ret
	
;______________________________________________________________________________________
	
_LABEL_174_38:				;[$0174]
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (S1_PAGE_2), a
	
	;if the level is underwater then skip loading the palette as the palettes
	 ;are handled by the code that does the raster split
	bit  7, (iy+$06)		;underwater flag
	jr   nz, +
	
	;get the palette loading parameters that were assigned by the main thread
	 ;(i.e. `loadPaletteOnInterrupt`)
	ld   hl, ($D22B)		;address of palette
	ld   a, ($D22F)			;flags for loading tile and/or sprite palette
	
	bit  3, (iy+$00)		;check the flag to specify loading the palette
	call nz, loadPalette		;load the palette if flag is set
	res  3, (iy+$00)		;unset the flag so it doesn't happen again
	ret
	
	;when the level is underwater, different logic controls loading the palette
	 ;as we have to deal with the water line
+	call _LABEL_1BA_40
	ret

;____________________________________________________________________________[$01A0]___

_LABEL_1A0_18:
	bit  7, (iy+$06)		;check the underwater flag
	ret  z				;if off, leave now
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (S1_PAGE_2), a
	
	;this seems quite pointless but could do with
	 ;killing a specific amount of time
	ld   b, $00
-	nop
	djnz -
	
_LABEL_1BA_40:
	ld   a, ($D2DB)			;get the position of the water line on screen
	and  a
	jr   z, ++			;is it 0?
	cp   $FF			;or $FF? (i.e. off the screen)
	jr   nz, ++			;...skip ahead
	
	;select the palette
	 ;labyrinth Act 1 & 2 share an underwater palette and Labyrinth Act 3
	 ;uses a special palette to account for the boss / capsule, who normally
	 ;load their palettes on-demand
	ld   hl, S1_UnderwaterPalette
	bit  4, (iy+$07)		;underwater boss palette?
	jr   z, +			
	ld   hl, S1_UnderwaterPalette_Boss

+	ld   a, %00000011		;"load tile & sprite palettes"
	call loadPalette		;load the relevant underwater palette
	ret
	
++	ld   a, ($D2A6)
	add  a, a
	add  a, a
	add  a, a
	add  a, a
	ld   e, a
	ld   d, $00
	ld   hl, ($D2A8)
	add  hl, de
	ld   a, %00000001
	call loadPalette
	
	ld   hl, S1_LabyrinthSpritePalette
	ld   a, %00000010
	call loadPalette
	
	ret

;____________________________________________________________________________[$01F2]___
	
_LABEL_1F2_17:
;A : the raster split step number (counts down from 3)
	;step 1?
	cp   1
	jr   z, ++
	;step 2?
	cp   2
	jr   z, +
	
	;--- step 3 -------------------------------------------------------------------
	;set counter at step 2
	dec  a
	ld   ($D247), a
	
	in   a, (SMS_CURRENT_SCANLINE)	;get the current scanline
	ld   c, a
	ld   a, ($D248)			;get the water line height on the screen
	sub  c				;work out the difference
	
	;set VDP register 10 with the scanline number to interrupt at next
	 ;(that is, set the next interrupt to occur at the water line)
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 10
	out  (SMS_VDP_CONTROL), a
	
	jp   +++
	
	;--- step 2 -------------------------------------------------------------------
+	;we don't do anything on this step
	dec  a
	ld   ($D247), a
	jp   +++
	
	;--- step 1 -------------------------------------------------------------------
++	dec  a
	ld   ($D247), a
	
	;set the VDP to point at the palette
	ld   a, $00
	out  (SMS_VDP_CONTROL), a
	ld   a, %11000000
	out  (SMS_VDP_CONTROL), a
	
	ld   b, $10
	ld   hl, S1_UnderwaterPalette
	
	bit  4, (iy+$07)		;underwater boss palette
	jr   z, _f			;jump forward to `__`
	
	ld   hl, S1_UnderwaterPalette_Boss

	;copy the palette into the VDP
__	ld   a, (hl)
	out  (SMS_VDP_DATA), a
	inc  hl
	nop
	ld   a, (hl)
	out  (SMS_VDP_DATA), a
	inc  hl
	djnz _b				;jump backward to `__`
	
	ld   a, (S1_VDPREGISTER_0)
	and  %11101111			;remove bit 4 -- disable line interrupts
	out  (SMS_VDP_CONTROL), a
	ld   a, $80
	out  (SMS_VDP_CONTROL), a

+++	pop  bc
	pop  de
	pop  hl
	pop  af
	ei
	ret
	
;____________________________________________________________________________[$024B]___
;underwater palettes

S1_UnderwaterPalette:			;[$024B]
.db $10, $14, $14, $18, $35, $34, $2C, $39, $21, $20, $1E, $09, $04, $1E, $10, $3F
.db $00, $20, $35, $2E, $29, $3A, $00, $3F, $14, $29, $3A, $14, $3E, $3A, $19, $25

S1_UnderwaterPalette_Boss:		;[$026B]
.db $10, $14, $14, $18, $35, $34, $2C, $39, $21, $20, $1E, $09, $04, $1E, $10, $3F
.db $10, $20, $35, $2E, $29, $3A, $00, $3F, $24, $3D, $1F, $17, $14, $3A, $19, $00

;____________________________________________________________________________[$028B]___

_init:
	;tell the SMS the cartridge has no RAM and to use ROM banking
	 ;(the meaning of bit 7 is undocumented)
	ld   a, %10000000
	ld   (SMS_PAGE_RAM), a
	;load banks 0, 1 & 2 of the ROM into the address space
	 ;($0000-$BFFF of the address space will be mapped to $0000-$BFFF of this ROM)
	ld   a, 0
	ld   (SMS_PAGE_0), a
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	
	;empty the RAM!
	ld   hl, $C000			;starting from $C000,
	ld   de, $C001			;and copying one byte to the next byte,
	ld   bc, $1FEF			;copy 8'175 bytes ($C000-$DFEF),
	ld   (hl), l			;using a value of 0 (the #$00 from the $C000)
	ldir				 ;--it's faster to read a register than RAM
	
	ld   sp, hl			;place the stack at the top of RAM ($DFEF)
					 ;(note that LDIR increased the HL register)
	
	;initialize the VDP:
	ld   hl, _InitVDPRegisterValues	;begin copying from $0311 in the ROM,
	ld   de, S1_VDPREGISTER_0	;to $D218 in the RAM
	ld   b, $0B			;copying 11 bytes
	ld   c, $8B
				
-	ld   a, (hl)			;read the lo-byte for the VDP
	ld   (de), a			;copy to RAM
	inc  hl				;move to the next byte
	inc  de				
	out  (SMS_VDP_CONTROL), a	;send the VDP lo-byte
	ld   a, c			;Load A with #$8B
	sub  b				;subtract B from A (B is decreasing),
					 ;so A will count from #$80 to #8A
	out  (SMS_VDP_CONTROL), a	;send the VDP hi-byte
	djnz -				;loop until B has reached 0
	
	;move all sprites off the bottom of the screen!
	 ;(set 64 bytes of VRAM from $3F00 to #$E0)
	ld   hl, $3F00
	ld   bc, 64
	ld   a, $E0
	call _clearVRAM
	
	;mute sound
	call _LABEL_2ED_7
	
	;initialise variables?
	ld   iy, $D200			;variable space starts here
	jp   _LABEL_1C49_62

;____________________________________________________________________________[$02D7]___

;I believe this loads a music track
_RST18Handler:
	di				;disable interrupts
	push af
	
	;switch page 1 (Z80:$4000-$7FFF) to bank 3 ($C000-$FFFF)
	ld   a, :_c012
	ld   (SMS_PAGE_1), a
	
	pop  af
	ld   ($D2D2), a
	call _c012
	
	ld   a, (S1_PAGE_1)
	ld   (SMS_PAGE_1), a
	
	ei				;enable interrupts
	ret

;______________________________________________________________________________________

_LABEL_2ED_7:				;[$02E7]
	di				;disable interrupts
	
	;switch page 1 (Z80:$4000-$7FFF) to bank 3 (ROM:$0C000-$0FFFF)
	ld   a, :_c006
	ld   (SMS_PAGE_1), a
	call _c006
	ld   a, (S1_PAGE_1)
	ld   (SMS_PAGE_1), a
	
	ei				;enable interrupts
	ret

_2fe:
	di      
	push    af
	ld      a,:_c015
	ld      (SMS_PAGE_1),a
	pop     af
	call    _c015
	ld      a,(S1_PAGE_1)
	ld      (SMS_PAGE_1),a
	ei      
	ret  

;--------------------------------------------------------------------------------------

_InitVDPRegisterValues:			;[$031B]				cache:
.db %00100110   ;VDP Register 0:						$D218
    ;......x.    stretch screen (33 columns)
    ;.....x..    unknown
    ;..x.....    hide left column (for scrolling)
.db %10100010	;vDP Register 1:						$D219
    ;......x.    enable 8x16 sprites
    ;..x.....    enable vsync IRQ
    ;.x......	 disable screen (no display)
    ;x.......    unknown
.db $FF		;VDP Register 2: place screen at VRAM:$3800			$D21A
.db $FF		;VDP Register 3: unused						$D21B
.db $FF		;VDP Register 4: unused						$D21C
.db $FF		;VDP Register 5: set sprites at VRAM:$3f00			$D21D
.db $FF		;VDP Register 6: set sprites to use tiles from VRAM:$2000	$D21E
.db $00		;VDP Register 7: set border colour from the sprite palette	$D21F
.db $00		;VDP Register 8: horizontal scroll offset			$D220
.db $00		;VDP Register 9: vertical scroll offset				$D221
.db $FF		;VDP Register 10: disable line interrupts			$D222

;____________________________________________________________________________[$031C]___

wait:
	;test bit 0 of the IY parameter (IY=$D200)
	bit  0, (iy+$00)
	;if bit 0 is off, then wait!
	jr   z, wait
	ret

;--------------------------------------------------------------------------------------

_323:
	set     2,(iy+$00)
	ld      ($d225),hl
	ld      ($d227),de
	ld      ($d229),bc
	ret

;____________________________________________________________________________[$0333]___

loadPaletteOnInterrupt:
	set  3, (iy+$00)		;set the flag for the interrupt handler
	ld   ($D22F), a			;store the parameters
	ld   ($D22B), hl
	ret

;____________________________________________________________________________[$033E]___

updateVDPSprites:
	;--- sprite Y positions -------------------------------------------------------
	
	;set the VDP address to $3F00 (sprite info table, Y-positions)
	ld   a, $00
	out  (SMS_VDP_CONTROL), a
	ld   a, $3F
	or   %01000000			;add bit 6 to mark an address being given
	out  (SMS_VDP_CONTROL), a
	
	ld   b, (iy+$0a)		;number of sprites to update?
	ld   hl, $D001			;Y-position of the first sprite
	ld   de, $0003			;sprite table is 3 bytes per sprite
	
	ld   a, b
	and  a				;is A zero?
	jr   z, +		

	;set sprite Y-positions
-	ld   a, (hl)
	out  (SMS_VDP_DATA), a
	add  hl, de
	djnz -
	
+	ld   a, ($D2B4)
	ld   b, a
	ld   a, (iy+$0a)
	ld   c, a
	cp   b
	jr   nc, +			;"A >= B" (iy+$0a) >= ($D2B4)
	
	ld   a, b
	sub  c
	ld   b, a

	;move remaining sprites off screen?
-	ld   a, 224
	out  (SMS_VDP_DATA), a
	djnz -
	
	;--- sprite X positions / indexes ---------------------------------------------
+	ld   a, c
	and  a
	ret  z
	
	ld   hl, $D000			;first X-position in the sprite table
	ld   b, (iy+$0a)
	
	;set the VDP address to $3F80 (sprite info table, X-positions & indexes)
	ld   a, $80
	out  (SMS_VDP_CONTROL), a
	ld   a, $3F
	or   %01000000			;add bit 6 to mark an address being given
	out  (SMS_VDP_CONTROL), a
	
-	ld   a, (hl)			;set the sprite X-position
	out  (SMS_VDP_DATA), a
	inc  l				;skip Y-position
	inc  l				
	ld   a, (hl)			;set the sprite index number
	out  (SMS_VDP_DATA), a
	inc  l
	djnz -
	
	ld   a, (iy+$0a)
	ld   ($D2B4), a
	ld   (iy+$0a), b
	ret

;___ UNUSED! ________________________________________________________________[$0397]___	

;fill VRAM from memory?
_0397:
;BC : number of bytes to copy
;DE : VDP address
;HL : memory location to copy from
	di      
	ld      a,e
	out     (SMS_VDP_CONTROL),a
	ld      a,d
	or      %01000000
	out     (SMS_VDP_CONTROL),a
	ei      

-	ld      a,(hl)
	out     (SMS_VDP_DATA),a
	inc     hl
	
	dec     bc
	ld      a,b
	or      c
	jp      nz,-
	
	ret     
	
;___ UNUSED! ________________________________________________________________[$03AC]___

_03ac:
;A  : bank number for page 1, A+1 will be used as the bank number for page 2
;DE : VDP address
;HL : 
	di      
	push    af

	;set the VDP address using DE
	ld      a,e
	out     (SMS_VDP_CONTROL),a
	ld      a,d
	or      %01000000
	out     (SMS_VDP_CONTROL),a
	
	pop     af
	ld      de,(S1_PAGE_1)		;remember the current page 1 & 2 banks
	push    de
	
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	inc     a
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ei      
_03ca:
	ld      a,(hl)
	cpl     
	ld      e,a
_03cd:
	ld      a,(hl)
	cp      e
	jr      z,_03dd
	out     (SMS_VDP_DATA),a
	ld      e,a
	inc     hl
	dec     bc
	ld      a,b
	or      c
	jp      nz,_03cd
	jr      _03f5
_03dd:
	ld      d,a
	inc     hl
	dec     bc
	ld      a,b
	or      c
	jr      z,_03f5
	ld      a,d
	ld      e,(hl)
_03e6:
	out     (SMS_VDP_DATA),a
	dec     e
	nop     
	nop     
	jp      nz,_03e6
	inc     hl
	dec     bc
	ld      a,b
	or      c
	jp      nz,_03ca
_03f5:
	di      
	;restore bank numbers
	pop     de
	ld      (S1_PAGE_1),de
	ld      a,e
	ld      (SMS_PAGE_1),a
	ld      a,d
	ld      (SMS_PAGE_2),a
	ei      
	ret  

;____________________________________________________________________________[$0405]___

decompressArt:
;HL : relative address from the beginning of the intended bank (A) to the data
;DE : VDP register number (D) and value byte (E) to send to the VDP
;A  : bank number for the relative address HL
	di				;disable interrupts
-	push af				;remember the A parameter
	
	;--- determine bank number ----------------------------------------------------
	
	;is the HL parameter address below the $40xx range?
	 ;--that is, does the relative address extend into the second page?
	ld   a, h
	cp   $40
	jr   c, +
	
	;remove #$40xx (e.g. so $562B becomes $162B)
	sub  $40
	ld   h, a
	
	;restore the A parameter (the starting bank number) and increase it so that
	 ;HL now represents a relative address from the next bank up. this would mean
	 ;that instead of paging in, for example, banks 9 & 10, we would get 10 & 11
	pop  af
	inc  a
	jp -
	
	;--- configure the VDP --------------------------------------------------------
	
+	ld   a, e			;load the second byte from the DE parameter
	out  (SMS_VDP_CONTROL), a	;send as the value byte to the VDP
	
	ld   a, d
	or   %01000000			;add bit 7 (that is, convert A to a
					 ;VDP control register number)
	out  (SMS_VDP_CONTROL), a	;send it to the VDP
	
	;--- switch banks -------------------------------------------------------------
	
	pop  af				;restore the A parameter
	
	;add $4000 to the HL parameter to re-base it for page 1 (Z80:$4000-$7FFF)
	ld   de, $4000
	add  hl, de
	
	;stash the current page 1/2 bank numbers cached in RAM
	ld   de, (S1_PAGE_1)
	push de
	
	;change pages 1 & 2 (Z80:$4000-$BFFF) to banks A & A+1
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	inc  a
	ld   (SMS_PAGE_2), a
	ld   (S1_PAGE_2), a
	
	;--- read header --------------------------------------------------------------
	
	bit  1, (iy+$09)
	jr   nz, +
	ei
	
+	ld   ($D212), hl
	
	;begin reading the compressed art header:
	 ;see <info.sonicretro.org/SCHG:Sonic_the_Hedgehog_%288-bit%29#Header>
	 ;for details on the format
	
	;skip the "48 59" art header marker
	inc  hl
	inc  hl
	
	;read the DuplicateRows value into DE and save for later
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	inc  hl
	push de
	
	;read the ArtData value into DE and save for later
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	push de
	
	;read the row count (#$0400 for sprites, #$0800 for tiles) into BC
	inc  hl
	ld   c, (hl)
	inc  hl
	ld   b, (hl)
	inc  hl
	
	ld   ($D210), bc		;store the row count in $D210
	ld   ($D214), hl		;where the UniqueRows list begins
	
	;swap BC/DE/HL with their shadow values
	exx
	
	;load BC with the absolute starting address of the art header;
	 ;the DuplicateRows and ArtData values are always relative to this
	ld   bc, ($D212)
	;copy it to DE
	ld   e, c
	ld   d, b
	
	pop  hl				;pull the ArtData value from the stack
	add  hl, bc			;get the absolute address of ArtData
	ld   ($D20E), hl		;and store that in $D20E
	;copy it to BC. this will be used to produce a counter from 0 to RowCount
	ld   c, l
	ld   b, h
	
	pop  hl				;load HL with the DuplicateRows value
	add  hl, de			;get the absolute address of DuplicateRows
	
	;swap DE & HL. DE will now be the DuplicateRows absolute address,
	 ;and HL will be the absolute address of the art header
	ex   de, hl
	
	;now swap the original values back,
	 ;BC will be the row counter
	 ;DE will be the ArtData value
	exx
	
	;--- process row --------------------------------------------------------------
_processRow:
	ld   hl, ($D210)		;load HL with the original row count number
					 ;(#$0400 for sprites, #$0800 for tiles)
	xor  a				;set A to 0 (Carry is reset)
	sbc  hl, bc			;subtract current counter from the row count
					 ;that is, count upwards from 0
	push hl				;save the counter value
	
	;get the row number in the current tile (0-7):
	ld   d, a			;zero-out D
	ld   a, l			;load A with the lo-byte of the counter
	and  %00000111			;clip to the first three bits,
					 ;that is, "mod 8" it so it counts 0-7
	ld   e, a			;load E with this value, making it a
					 ;16-bit number in DE
	ld   hl, _rowIndexTable
	add  hl, de			;add the row number to $04F9
	ld   a, (hl)			;get the bit mask for the particular row
	
	pop  de				;fetch our counter back
	
	;divide the counter by 4
	srl  d
	rr   e
	srl  d
	rr   e
	srl  d
	rr   e
	
	ld   hl, ($D214)		;the absolute address where the UniqueRows
					 ;list begins
	add  hl, de			;add the counter, so move along to the
					 ;DE'th byte in the UniqueRows list
	ld   e, a			
	ld   a, (hl)			;read the current byte in the UniqueRows list
	and  e				;test if the masked bit is set
	jr   nz, _duplicateRow		;if the bit is set, it's a duplicate row,
					 ;otherwise continue for a unique row
	
	;--- unique row ---------------------------------------------------------------
	
	;swap back the BC/DE/HL shadow values
	 ;BC will be the absolute address to the ArtData
	 ;DE will be the DuplicateRows absolute address
	 ;HL will be the absolute address of the art header
	exx
	
	;write 1 row of pixles (4 bytes) to the VDP
	ld   a, (bc)
	out  (SMS_VDP_DATA), a
	inc  bc
	nop
	nop
	ld   a, (bc)
	out  (SMS_VDP_DATA), a
	inc  bc
	nop
	nop
	ld   a, (bc)
	out  (SMS_VDP_DATA), a
	inc  bc
	nop
	nop
	ld   a, (bc)
	out  (SMS_VDP_DATA), a
	inc  bc
	
	;swap BC/DE/HL back again
	 ;HL is the current byte in the UniqueRows list
	exx
	
	dec  bc				;decrease the length counter
	ld   a, b			;combine the high byte,
	or   c				;with the low byte...
	jp   nz, _processRow		;loop back if not zero
	jp   _decompressArt_finish	;otherwise, skip to finalisation

_duplicateRow:
	;--- duplicate row ------------------------------------------------------------
	
	;swap in the BC/DE/HL shadow values
	 ;BC will be the absolute address to the ArtData
	 ;DE will be the DuplicateRows absolute address
	 ;HL will be the absolute address of the art header
	exx
	
	ld   a, (de)			;read a byte from the duplicate rows list
	inc  de				;move to the next byte
	
	;swap back the original BC/DE/HL values
	exx
	
	;HL will be re-purposed as the index into the art data
	ld   h, $00
	;check if the byte from the duplicate rows list begins with $F, i.e. $Fxxx
	 ;this is used as a marker to specify a two-byte number for indexes over 256
	cp   $F0
	jr   c, +			;if less than $F0, skip reading next byte
	sub  $F0			;strip the $F0, i.e $F3 = $03
	ld   h, a			;and set as the hi-byte for the art data index
	exx				;switch DE to DuplicateRows list abs. address
	ld   a, (de)			;fetch the next byte
	inc  de				;and move forward in the list
	exx				;return BC/DE/HL to before
	;multiply the duplicate row's index number to the art data by 4
	 ;--each row of art data is 4 bytes
+	ld   l, a
	add  hl, hl			
	add  hl, hl
	
	ld   de, ($D20E)		;get the absolute address to the art data
	add  hl, de			;add the index from the duplicate row list
	
	;write 1 row of pixles (4 bytes) to the VDP
	ld   a, (hl)			
	out  (SMS_VDP_DATA), a
	inc  hl
	nop
	nop
	ld   a, (hl)
	out  (SMS_VDP_DATA), a
	inc  hl
	nop
	nop
	ld   a, (hl)
	out  (SMS_VDP_DATA), a
	inc  hl
	nop
	nop
	ld   a, (hl)
	out  (SMS_VDP_DATA), a
	inc  hl
	
	;decrease the remaining row count
	dec  bc
	
	;check if all rows have been done
	ld   a, b
	or   c
	jp   nz, _processRow

_decompressArt_finish:
	bit  1, (iy+$09)
	jr   nz, +
	di
+	;restore the pages to the original banks at the beginning of the procedure
	pop  de
	ld   (S1_PAGE_1), de
	ld   (SMS_PAGE_1), de
	
	ei
	res  1, (iy+$09)
	ret

_rowIndexTable:
.db %00000001
.db %00000010
.db %00000100
.db %00001000
.db %00010000
.db %00100000
.db %01000000
.db %10000000

;____________________________________________________________________________[$0501]___

decompressScreen:
;BC : length of the compressed data
;DE : VDP register number (D) and value byte (E) to send to the VDP
;HL : Absolute address to the start of the compressed screen data
	di				;disable interrupts
	
	;configure the VDP based on the DE parameter
	ld   a, e
	out  (SMS_VDP_CONTROL), a
	ld   a, d
	or   %01000000			;add bit 7 (that is, convert A to a
					 ;VDP control register number)
	out  (SMS_VDP_CONTROL), a
	
	ei				;enable interrupts
	
;a screen layout is compressed using RLE (run-length-encoding). any byte that there
 ;are multiple of in a row are listed as two repeating bytes, followed by another byte
 ;specifying the remaining number of times to repeat
	
_LABEL_50B_83:
	;the current byte is stored in E to be able to check when two bytes in a row
	 ;occur (the marker for a compressed byte). it's actually stored inverted
	 ;so that the first data byte doesn't trigger an immediate repeat
	
	ld   a, (hl)			;read the current byte from the screen data
	cpl				;invert the bits ("NOT")
	ld   e, a			;move this to E
	
_LABEL_50E_79:
	ld   a, (hl)			;read the current byte from the screen data
	cp   e				;is this equal to the previous byte?
	jr   z, +			;if yes, decompress the byte
	
	cp   $FF			;is this tile $FF?
	jr   z, _decompressScreen_skip		
	
	;--- uncompressed byte --------------------------------------------------------
	out  (SMS_VDP_DATA), a		;send the tile to the VDP
	ld   e, a			;update the "current byte" being compared
	ld   a, ($D20E)			;get the upper byte to use for the tiles
					 ;(foreground / background / flip)
	out  (SMS_VDP_DATA), a
	
	inc  hl				;move to the next byte
	dec  bc				;decrease the remaining bytes to read
	ld   a, b			;check if remaining bytes is zero
	or   c
	jp   nz, _LABEL_50E_79		;if remaining bytes, loop
	jr   _LABEL_548_80		;otherwise end
	
	;--- decompress byte ----------------------------------------------------------
+	ld   d, a			;put the current data byte into D
	inc  hl				;move to the next byte
	dec  bc				;decrease the remaining bytes to read
	ld   a, b			;check if remaining bytes is zero
	or   c
	jr   z, _LABEL_548_80		;if no bytes left, finish
					 ;(couldn't I just put `ret z` here?)
	
	ld   a, d			;return the data byte back to A
	ld   e, (hl)			;get the number of times to repeat the byte
	cp   $FF			;is a skip being repeated?
	jr   z, _decompressScreen_multiSkip
	
	;repeat the byte
-	out  (SMS_VDP_DATA), a
	push af
	ld   a, ($D20E)
	out  (SMS_VDP_DATA), a
	pop  af
	dec  e
	jp   nz, -
	
_LABEL_541_84:
	inc  hl
	dec  bc
	
	;any remaining bytes?
	ld   a, b
	or   c
	jp   nz, _LABEL_50B_83		;if yes start checking duplicate bytes again
_LABEL_548_80:
	ret
	
_decompressScreen_skip:
	ld   e, a
	in   a, (SMS_VDP_DATA)
	nop
	inc  hl
	dec  bc
	in   a, (SMS_VDP_DATA)
	
	ld   a, b
	or   c
	jp   nz, _LABEL_50E_79
	
	ei
	ret

_decompressScreen_multiSkip:
	in   a, (SMS_VDP_DATA)
	push af
	pop  af
	in   a, (SMS_VDP_DATA)
	nop
	dec  e
	jp   nz, _decompressScreen_multiSkip
	jp   _LABEL_541_84

;____________________________________________________________________________[$0566]___

loadPalette:
;A  : which palette(s) to set
    ;  bit 0 - tile palette (0-15)
    ;  bit 1 - sprite palette (16-31)
;HL : Address of palette
	push af
	
	ld   b, 16			;we will copy 16 colours
	ld   c, 0			;beginning at palette index 0 (tiles)
	
	bit  0, a			;are we loading a tile palette?
	jr   z, +			;if no, skip ahead to the sprite palette
	
	ld   ($D230), hl		;store the address of the tile palette
	call _sendPalette		;send the palette colours to the VDP
	
+	pop  af
	
	bit  1, a			;are we loading a sprite palette?
	ret  z				;if no, finish here
	
	ld   ($D232), hl		;store the address of the sprite palette
	
	ld   b, 16			;we will copy 16 colours
	ld   c, 16			;beginning at palette index 16 (sprites)
	
	bit  0, a			;if loading both tile and sprite palette	
	jr   nz, _sendPalette		 ;then stick with what we've set and do it
	
	;if loading sprite palette only, then ignore the first colour
	 ;(I believe this has to do with the screen background colour being set from
	 ; the sprite palette?)
	inc  hl
	ld   b, 15			;copy 15 colours
	ld   c, 17			;to indexes 17-31, that is, skip no. 16
	
_sendPalette:
	ld   a, c			;send the palette index number to begin at
	out  (SMS_VDP_CONTROL), a
	ld   a, %11000000		;specify palette operation (bits 7 & 6)
	out  (SMS_VDP_CONTROL), a
	ld   c, $BE			;send the colours to the palette
	otir
	ret

;____________________________________________________________________________[$0595]___

_clearVRAM:
;HL : VRAM address
;BC : length
;A  : value
	ld   e, a
	ld   a, l
	out  (SMS_VDP_CONTROL), a
	ld   a, h
	or   %01000000
	out  (SMS_VDP_CONTROL), a
	
-	ld   a, e
	out  (SMS_VDP_DATA), a
	dec  bc
	ld   a, b
	or   c
	jr   nz, -
	ret

;____________________________________________________________________________[$05A7]___

readJoypad:
	in   a, (SMS_JOYPAD_1)		;read the joypad port
	or   %11000000			;mask out bits 7 & 6 - these are joypad 2
					 ;down / up
	ld   (iy+$03), a		;store the joypad value in $D203
	ret

;____________________________________________________________________________[$05AF]___

print:
;HL : Address to memory with column and row numbers, then data terminated with $FF
	
	;get the column number
	ld   c, (hl)
	inc  hl
	
	;the screen layout on the Master System is a 32x28 table of 16-bit values
	 ;(64 bytes per row). we therefore need to multiply the row number by 64
	 ;to get the right offset into the screen layout data
	ld   a, (hl)			;read the row number
	inc  hl
	
	;we multiply by 64 by first multiplying by 256 -- very simple, we just make
	 ;the value the hi-byte in a 16-bit word, e.g. "$0C00" -- and then divide
	 ;by 4 by rotating the bits to the right
	rrca				;divide by two
	rrca				;and again, making it four times
	
	ld   e, a
	and  %00111111			;strip off the rotated bits
	ld   d, a
	
	ld   a, e
	and  %11000000
	ld   e, a
	
	ld   b, $00
	ex   de, hl
	sla  c				;multiply column number by 2 (16-bit values)
	add  hl, bc
	ld   bc, $3800
	add  hl, bc
	
	;set the VDP to point to the screen address calculated
	di
	ld   a, l
	out  (SMS_VDP_CONTROL), a
	ld   a, h
	or   %01000000
	out  (SMS_VDP_CONTROL), a
	ei

	;read bytes from memory until hitting $FF
-	ld   a, (de)
	cp   $FF
	ret  z
	
	out  (SMS_VDP_DATA), a
	push af				;kill time?
	pop  af
	ld   a, ($D20E)			;what to use as the tile upper bits
					 ;(front/back, flip &c.)
	out  (SMS_VDP_DATA), a
	inc  de
	djnz -
	
	ret

;____________________________________________________________________________[$05E2]___

hideSprites:
	ld   hl, $D000
	ld   e, l
	ld   d, h
	ld   bc, $00BD
	;set the first two bytes as #$E0
	ld   a, $E0
	ld   (de), a
	inc  de
	ld   (de), a
	;then move forward another two bytes
	inc  de
	inc  de
	;copy 189 bytes from $D000 to $D003+ (up to $D0C0)
	ldir
	
	;set parameters so that at the next interrupt,
	 ;all sprites will be hidden (see `updateVDPSprites`)
	ld   (iy+$0a), 64		;update 64 sprites
	xor  a				;(set A to 0)
	ld   ($D2B4), a			;with 0 remaining
	ret

;____________________________________________________________________________[$05FC]___

_LABEL_5FC_114:
	xor  a				;set A to 0
	ld   b, $07
	ex   de, hl
	ld   l, a
	ld   h, a

-	rl   c
	jp   nc, +
	add  hl, de
+	add  hl, hl
	djnz -
	
	or   c
	ret  z
	add  hl, de
	ret

;____________________________________________________________________________[$060F]___
	
_LABEL_60F_111:
	xor  a
	ld   b, $10
-	rl   l
	rl   h
	rla
	cp   c
	jp   c, +
	sub  c
+	ccf
	rl   e
	rl   d
	djnz -
	ex   de, hl
	ret

;____________________________________________________________________________[$0625]___
	
_LABEL_625_57:
	push hl
	push de
	ld   hl, ($D2D7)
	ld   e, l
	ld   d, h
	add  hl, de
	add  hl, de
	ld   a, l
	add  a, h
	ld   h, a
	add  a, l
	ld   l, a
	ld   de, $0054
	add  hl, de
	ld   ($D2D7), hl
	ld   a, h
	pop  de
	pop  hl
	ret

_063e:
	ld      bc,($d251)
	ld      hl,($d25a)
	ld      de,($d26f)
	and     a
	sbc     hl,de
	jr      c,_0658
	ld      a,l
	add     a,c
	ld      c,a
	res     6,(iy+$00)
	jp      _065f
_0658:
	ld      a,l
	add     a,c
	ld      c,a
	set     6,(iy+$00)
_065f:
	ld      hl,($d25d)
	ld      de,($d271)
	and     a
	sbc     hl,de
	jr      c,_067b
	ld      a,l
	add     a,b
	cp      $e0
	jr      c,_0673
	add     a,$20
_0673:
	ld      b,a
	res     7,(iy+$00)
	jp      _0688
_067b:
	ld      a,l
	add     a,b
	cp      $e0
	jr      c,_0683
	sub     $20
_0683:
	ld      b,a
	set     7,(iy+$00)
_0688:
	ld      ($d251),bc
	ld      hl,($d25a)
	sla     l
	rl      h
	sla     l
	rl      h
	sla     l
	rl      h
	ld      c,h
	ld      hl,($d25d)
	sla     l
	rl      h
	sla     l
	rl      h
	sla     l
	rl      h
	ld      b,h
	ld      ($d257),bc
	ld      hl,($d25a)
	ld      ($d26f),hl
	ld      hl,($d25d)
	ld      ($d271),hl
	ret     
_06bd:
	bit     5,(iy+$00)
	ret     z
_06c2:
	di      
	;switch pages 1 & 2 ($4000-$BFFF) to banks 4 & 5 ($10000-$17FFF)
	ld      a,4
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,5
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ei      
	
	ld      a,(S1_LEVEL_SOLIDITY)	;get the solidity index for the level
	add     a,a			;double it (for a pointer)
	ld      c,a			;and put it into a 16-bit number
	ld      b,$00
	
	;lookup the index in the solidity pointer table
	ld      hl,S1_SolidityPointers
	add     hl,bc
	
	;load an address at the table
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	;store the solidity data address in RAM
	ld      ($d210),hl
	bit     0,(iy+$02)
	jp      z,_0772
	
	bit     6,(iy+$00)
	jr      nz,_06fa
	
	ld      b,$00
	ld      c,$08
	jp      _070b
_06fa:
	ld      a,($d251)
	and     %00011111
	add     a,$08
	rrca    
	rrca    
	rrca    
	rrca    
	rrca    
	and     %00000001
	ld      b,$00
	ld      c,a
_070b:
	call    _08d5
	ld      a,($d251)
	bit     6,(iy+$00)
	jr      z,_0719
	add     a,$08
_0719:
	and     %00011111
	srl     a
	srl     a
	srl     a
	ld      c,a
	ld      b,$00
	ld      ($d20e),bc
	exx     
	ld      de,$d180
	exx     
	ld      de,(S1_LEVEL_FLOORWIDTH)
	ld      b,$07
-	ld      a,(hl)
	exx     
	ld      c,a
	ld      b,$00
	ld      hl,($d210)
	add     hl,bc
	rlca    
	rlca    
	rlca    
	rlca    
	ld      c,a
	and     $0f
	ld      b,a
	ld      a,c
	xor     b
	ld      c,a
	ld      a,(hl)
	rrca    
	rrca    
	rrca    
	and     $10
	ld      hl,($d20e)
	add     hl,bc
	ld      bc,($d24f)
	add     hl,bc
	ld      bc,$0004
	ldi     
	ld      (de),a
	inc     e
	add     hl,bc
	ldi     
	ld      (de),a
	inc     e
	inc     c
	add     hl,bc
	ldi     
	ld      (de),a
	inc     e
	inc     c
	add     hl,bc
	ldi     
	ld      (de),a
	inc     e
	exx     
	add     hl,de
	djnz    -
_0772:
	bit     1,(iy+$02)
	jp      z,_07da
	bit     7,(iy+$00)
	jr      nz,_0786
	ld      b,$06
	ld      c,$00
	jp      _0789
_0786:
	ld      b,$00
	ld      c,b
_0789:
	call    _08d5
	ld      a,($d252)
	and     $1f
	srl     a
	and     $fc
	ld      c,a
	ld      b,$00
	ld      ($d20e),bc
	exx     
	ld      de,$d100
	exx     
	ld      b,$09
_07a3:
	ld      a,(hl)
	exx     
	ld      c,a
	ld      b,$00
	ld      hl,($d210)
	add     hl,bc
	rlca    
	rlca    
	rlca    
	rlca    
	ld      c,a
	and     $0f
	ld      b,a
	ld      a,c
	xor     b
	ld      c,a
	ld      a,(hl)
	rrca    
	rrca    
	rrca    
	and     $10
	ld      hl,($d20e)
	add     hl,bc
	ld      bc,($d24f)
	add     hl,bc
	ldi     
	ld      (de),a
	inc     e
	ldi     
	ld      (de),a
	inc     e
	ldi     
	ld      (de),a
	inc     e
	ldi     
	ld      (de),a
	inc     e
	exx     
	inc     hl
	djnz    _07a3
_07da:
	ret

;____________________________________________________________________________[$07DB]___

_LABEL_7DB_26:
	bit  0, (iy+$02)
	jp   z, _LABEL_849_27
	
	exx
	push hl
	push de
	push bc
	
	ld   a, ($D252)			;vertical scroll?
	and  %11111000
	ld   b, $00
	add  a, a
	rl   b
	add  a, a
	rl   b
	add  a, a
	rl   b
	ld   c, a
	ld   a, ($D251)			;horizontal scroll?
	
	bit  6, (iy+$00)
	jr   z, +
	
	add  a, $08
+	and  %11111000
	srl  a
	srl  a
	add  a, c
	ld   c, a
	ld   hl, $3800
	add  hl, bc
	set  6, h
	ld   bc, $0040
	ld   d, $7F
	ld   e, $07
	exx
	ld   hl, $D180
	ld   a, ($D252)			;vertical scroll?
	and  $1F
	srl  a
	srl  a
	srl  a
	ld   c, a
	ld   b, $00
	add  hl, bc
	add  hl, bc
	ld   b, $32
	ld   c, $BE
_LABEL_82F_30:
	exx
	ld   a, l
	out  (SMS_VDP_CONTROL), a
	ld   a, h
	out  (SMS_VDP_CONTROL), a
	add  hl, bc
	ld   a, h
	cp   d
	jp   nc, _LABEL_8D0_29
_LABEL_83C_37:
	exx
	outi
	outi
	jp   nz, _LABEL_82F_30
	exx
	pop  bc
	pop  de
	pop  hl
	exx
_LABEL_849_27:
	bit  1, (iy+$02)
	jp   z, _LABEL_8CF_31
	ld   a, ($D252)
	ld   b, $00
	srl  a
	srl  a
	srl  a
	bit  7, (iy+$00)
	jr   nz, _LABEL_863_32
	add  a, $18
_LABEL_863_32:
	cp   $1C
	jr   c, _LABEL_869_33
	sub  $1C
_LABEL_869_33:
	add  a, a
	add  a, a
	add  a, a
	add  a, a
	rl   b
	add  a, a
	rl   b
	add  a, a
	rl   b
	ld   c, a
	ld   a, ($D251)
	add  a, $08
	and  $F8
	srl  a
	srl  a
	add  a, c
	ld   c, a
	ld   hl, $3800
	add  hl, bc
	set  6, h
	ex   de, hl
	ld   hl, $D100
	ld   a, ($D251)
	and  $1F
	add  a, $08
	srl  a
	srl  a
	srl  a
	ld   c, a
	ld   b, $00
	add  hl, bc
	add  hl, bc
	ld   a, e
	and  $C0
	ld   ($D20E), a
	ld   a, e
	out  (SMS_VDP_CONTROL), a
	and  $3F
	ld   e, a
	ld   a, d
	out  (SMS_VDP_CONTROL), a
	ld   b, $3E
	ld   c, $BE
_LABEL_8B2_35:
	bit  6, e
	jr   nz, _LABEL_8C0_34
	inc  e
	inc  e
	outi
	outi
	jp   nz, _LABEL_8B2_35
	ret

_LABEL_8C0_34:				;[$08C0]
	ld   a, ($D20E)
	out  (SMS_VDP_CONTROL), a
	ld   a, d
	out  (SMS_VDP_CONTROL), a
_LABEL_8C8_36:
	outi
	outi
	jp   nz, _LABEL_8C8_36
_LABEL_8CF_31:
	ret

_LABEL_8D0_29:				;[$08D0]
	sub  e
	ld   h, a
	jp   _LABEL_83C_37
_08d5:
	ld      a,(S1_LEVEL_FLOORWIDTH)	;get width of the level's floor layout
	rlca    			;double it (x2)
	jr      c,_08e7
	rlca    			;double it again (x4)
	jr      c,_08fd
	rlca    			;double it again (x8)
	jr      c,_0917
	rlca    			;double it again (x16)
	jr      c,_0935
	jp      _0957
_08e7:
	ld      a,($d258)
	add     a,b
	ld      e,$00
	srl     a
	rr      e
	ld      d,a
	ld      a,($d257)
	add     a,c
	add     a,e
	ld      e,a
	ld      hl,$c000
	add     hl,de
	ret     

_08fd:
	ld      a,($d258)
	add     a,b
	ld      e,$00
	srl     a
	rr      e
	srl     a
	rr      e
	ld      d,a
	ld      a,($d257)
	add     a,c
	add     a,e
	ld      e,a
	ld      hl,$c000
	add     hl,de
	ret     

_0917:
	ld      a,($d258)
	add     a,b
	ld      e,$00
	srl     a
	rr      e
	srl     a
	rr      e
	srl     a
	rr      e
	ld      d,a
	ld      a,($d257)
	add     a,c
	add     a,e
	ld      e,a
	ld      hl,$c000
	add     hl,de
	ret     

_0935:
	ld      a,($d258)
	add     a,b
	ld      e,$00
	srl     a
	rr      e
	srl     a
	rr      e
	srl     a
	rr      e
	srl     a
	rr      e
	ld      d,a
	ld      a,($d257)
	add     a,c
	add     a,e
	ld      e,a
	ld      hl,$c000
	add     hl,de
	ret     

_0957:
	ld      a,($d258)
	add     a,b
	ld      d,a
	ld      a,($d257)
	add     a,c
	ld      e,a
	ld      hl,$c000
	add     hl,de
	ret     

_0966:
	di      			;disable interrupts
	ld      a,4
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,5
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	
	ld      bc,$0000
	call    _08d5
	ld      de,$3800
	ld      b,$06
_0982:
	push    bc
	push    hl
	push    de
	ld      b,$08
_0987:	;look up solidity value?
	push    bc
	push    hl
	push    de
	ld      a,(hl)
	exx     
	ld      e,a
	ld      a,(S1_LEVEL_SOLIDITY)
	add     a,a
	ld      c,a
	ld      b,$00
	ld      hl,S1_SolidityPointers
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      d,$00
	add     hl,de
	ld      a,(hl)
	rrca    
	rrca    
	rrca    
	and     $10
	ld      c,a
	exx     
	ld      l,(hl)
	ld      h,$00
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      bc,($d24f)
	add     hl,bc
	ex      de,hl
	ld      b,$04
_09b6:
	ld      a,l
	out     (SMS_VDP_CONTROL),a
	ld      a,h
	or      $40
	out     (SMS_VDP_CONTROL),a
	ld      a,(de)
	out     (SMS_VDP_DATA),a
	inc     de
	exx     
	ld      a,c
	exx     
	out     (SMS_VDP_DATA),a
	nop     
	nop     
	ld      a,(de)
	out     (SMS_VDP_DATA),a
	inc     de
	exx     
	ld      a,c
	exx     
	out     (SMS_VDP_DATA),a
	nop     
	nop     
	ld      a,(de)
	out     (SMS_VDP_DATA),a
	inc     de
	exx     
	ld      a,c
	exx     
	out     (SMS_VDP_DATA),a
	nop     
	nop     
	ld      a,(de)
	out     (SMS_VDP_DATA),a
	inc     de
	exx     
	ld      a,c
	exx     
	out     (SMS_VDP_DATA),a
	ld      a,b
	ld      bc,$0040
	add     hl,bc
	ld      b,a
	djnz    _09b6
	pop     de
	pop     hl
	inc     hl
	ld      bc,$0008
	ex      de,hl
	add     hl,bc
	ex      de,hl
	pop     bc
	djnz    _0987
	pop     de
	pop     hl
	ld      bc,(S1_LEVEL_FLOORWIDTH)
	add     hl,bc
	ex      de,hl
	ld      bc,$0100
	add     hl,bc
	ex      de,hl
	pop     bc
	dec     b
	jp      nz,_0982
	ei      
	ret     

;____________________________________________________________________________[$0A10]___

loadFloorLayout:
;HL : address of Floor Layout data
;BC : length of compressed data
	ld      de,$c000		;where in RAM the floor layout will go

--	;RLE decompress floor layout:
	;------------------------------------------------------------------------------
	ld      a,(hl)			;read the first byte of the floor layout
	cpl     			;flip it to avoid first byte comparison
	ld      (iy+$01),a		;this is the comparison byte

-	ld      a,(hl)			;read the current byte
	cp      (iy+$01)		;is it the same as the comparison byte?
	jr      z,+			;if so, decompress it
	
	;copy byte as normal:
	ld      (de),a			;write it to RAM	
	ld      (iy+$01),a		;update the comparison byte
	inc     hl			;move forward
	inc     de
	dec     bc			;count count of remaining bytes
	ld      a,b			;are there remaining bytes?
	or      c
	jp      nz,-			;if so continue
	ret     			;otherwise, finish
	;if the last two bytes of the data are duplicates, don't try decompress
	 ;further when there is no more data to be read!
+	dec     bc			;reduce count of remaining bytes
	ld      a,b			;are there remaining bytes?
	or      c
	ret     z			;if not, finish
	
	ld      a,(hl)			;read the value to repeat
	inc     hl			;move to the next byte (the repeat count)
	push    bc			;put BC (length of compressed data) to the side
	ld      b,(hl)			;get the repeat count
-	ld      (de),a			;write value to RAM
	inc     de			;move forward in RAM
	djnz    -			;continue until repeating value is complete
	
	pop     bc			;retrieve the data length
	inc     hl			;move forward in the compressed data
	
	;check if bytes remain
	dec     bc
	ld      a,b
	or      c
	jp      nz,--
	ret

;______________________________________________________________________________________
	
_LABEL_A40_121:				;[$0A40]
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (S1_PAGE_2), a
	ld   a, (iy+$0a)
	res  0, (iy+$00)
	call wait
	ld   (iy+$0a), a
	ld   b, $04
_LABEL_A5F_127:
	push bc
	ld   hl, ($D230)
	ld   de, $D3BC
	ld   b, $10
	call _LABEL_A90_122
	ld   hl, ($D232)
	ld   b, $10
	call _LABEL_A90_122
	ld   hl, $D3BC
	ld   a, $03
	call loadPaletteOnInterrupt
	ld   b, $0A
_LABEL_A7D_126:
	ld   a, (iy+$0a)
	res  0, (iy+$00)
	call wait
	ld   (iy+$0a), a
	djnz _LABEL_A7D_126
	pop  bc
	djnz _LABEL_A5F_127
	ret
_LABEL_A90_122:				;[$0A90]
	ld   a, (hl)
	and  $03
	jr   z, _LABEL_A96_123
	dec  a
_LABEL_A96_123:
	ld   c, a
	ld   a, (hl)
	and  $0C
	jr   z, _LABEL_A9E_124
	sub  $04
_LABEL_A9E_124:
	or   c
	ld   c, a
	ld   a, (hl)
	and  $30
	jr   z, _LABEL_AA7_125
	sub  $10
_LABEL_AA7_125:
	or   c
	ld   (de), a
	inc  hl
	inc  de
	djnz _LABEL_A90_122
	ret
_aae:					;[$0AAE]
	ld      ($d214),hl
	ld      hl,($d230)
	ld      de,$d3bc
	ld      bc,$0020
	ldir    
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ld      hl,$d3bc
	ld      a,$03
	call    loadPaletteOnInterrupt
	ld      c,(iy+$0a)
	ld      a,(S1_VDPREGISTER_1)
	or      $40
	ld      (S1_VDPREGISTER_1),a
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),c
	ld      b,$09
_aeb:
	ld      a,(iy+$0a)
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),a
	djnz    _aeb
	ld      b,$04
_afc:
	push    bc
	ld      hl,($d214)
	ld      de,$d3bc
	ld      b,$20
_b05:
	push    bc
	ld      a,(hl)
	and     $03
	ld      b,a
	ld      a,(de)
	and     $03
	cp      b
	jr      z,_b11
	dec     a
_b11:
	ld      c,a
	ld      a,(hl)
	and     $0c
	ld      b,a
	ld      a,(de)
	and     $0c
	cp      b
	jr      z,_b1e
	sub     $04
_b1e:
	or      c
	ld      c,a
	ld      a,(hl)
	and     $30
	ld      b,a
	ld      a,(de)
	and     $30
	cp      b
	jr      z,_b2c
	sub     $10
_b2c:
	or      c
	ld      (de),a
	inc     hl
	inc     de
	pop     bc
	djnz    _b05
	ld      hl,$d3bc
	ld      a,$03
	call loadPaletteOnInterrupt
	ld      b,$0a
_b3d:
	ld      a,(iy+$0a)
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),a
	djnz    _b3d
	pop     bc
	djnz    _afc
	ret     
_b50:					;[$0B50]
	ld      ($d214),hl
	ld      hl,$d3bc
	ld      b,$20
_b58:
	ld      (hl),$00
	inc     hl
	djnz    _b58
	jp      _b6e
_b60:					;[$0B60]	
	ld      ($d214),hl
	ld      hl,($d230)
	ld      de,$d3bc
	ld      bc,$0020
	ldir    
_b6e:
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ld      hl,$d3bc
	ld      a,$03
	call loadPaletteOnInterrupt
	ld      c,(iy+$0a)
	ld      a,(S1_VDPREGISTER_1)
	or      $40
	ld      (S1_VDPREGISTER_1),a
	res     0,(iy+$00)
	call wait
	ld      (iy+$0a),c
	ld      b,$09
_b9d:
	ld      a,(iy+$0a)
	res     0,(iy+$00)
	call wait
	ld      (iy+$0a),a
	djnz _b9d
	ld      b,$04
_bae:
	push    bc
	ld      hl,($d214)
	ld      de,$d3bc
	ld      b,$20
_bb7:
	push    bc
	ld      a,(hl)
	and     $03
	ld      b,a
	ld      a,(de)
	and     $03
	cp      b
	jr      nc,_bc3
	inc     a
_bc3:
	ld      c,a
	ld      a,(hl)
	and     $0c
	ld      b,a
	ld      a,(de)
	and     $0c
	cp      b
	jr      nc,_bd0
	add     a,$04
_bd0:
	or      c
	ld      c,a
	ld      a,(hl)
	and     $30
	ld      b,a
	ld      a,(de)
	and     $30
	cp      b
	jr      nc,_bde
	add     a,$10
_bde:
	or      c
	ld      (de),a
	inc     hl
	inc     de
	pop     bc
	djnz    _bb7
	ld      hl,$d3bc
	ld      a,$03
	call loadPaletteOnInterrupt
	ld      b,$0a
_bef:
	ld      a,(iy+$0a)
	res     0,(iy+$00)
	call wait
	ld      (iy+$0a),a
	djnz    _bef
	pop     bc
	djnz    _bae
	ret

;______________________________________________________________________________________
	
_LABEL_C02_135:				;[$0C02]
;HL : e.g. $D311
	ld   a, (S1_CURRENT_LEVEL)
	ld   c, a
	;divide the level number by 8?
	srl  a
	srl  a
	srl  a
	
	;put the result into DE
	ld   e, a
	ld   d, $00
	;add that to the parameter (i.e. $D311)
	add  hl, de
	
	ld   a, c			;return to the current level number
	ld   c, $01
	and  $07			;mod 8
	ret  z				;if level 0, 8, 16, ... then return C = 1
	ld   b, a			;B = 0-7
	ld   a, c			;$01
	
	;slide the bit up the byte between 0-7 depending on the level number
-	rlca
	djnz -
	ld   c, a			;return via C
	ret

;______________________________________________________________________________________
	
_c1d:					;[$0C1D]
	di      
	ld      a,5
	ld      (SMS_PAGE_1),a
	
	ld      a,($d223)
	and     $0f
	add     a,a
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ex      de,hl
	ld      bc,$2b80
	add     hl,bc
	ld      a,l
	out     (SMS_VDP_CONTROL),a
	ld      a,h
	or      $40
	out     (SMS_VDP_CONTROL),a
	ld      b,$04
_c3e:
	ld      a,(de)
	out     (SMS_VDP_DATA),a
	nop     
	nop     
	inc     de
	ld      a,(de)
	out     (SMS_VDP_DATA),a
	inc     de
	djnz    _c3e
	ld      a,(S1_PAGE_1)
	ld      (SMS_PAGE_1),a
	ei      
	ret

_LABEL_C52_106:				;[$0C52]
	xor  a				;set A to 0
	ld   ($D251), a			;set horizontal scroll to 0 (done on IRQ)
	ld   ($D252), a			;set vertical scroll to 0 (done on IRQ)
	
	ld   a, $FF
	ld   ($D216), a
	ld   c, $01
	ld   a, (S1_CURRENT_LEVEL)
	cp   18
	ret  nc
	cp   9
	jr   c, _LABEL_C6C_107
	ld   c, $02
_LABEL_C6C_107:
	ld   a, ($D216)
	cp   c
	jp   z, _LABEL_D3F_108
	ld   a, c
	ld   ($D216), a
	dec  a
	jr   nz, _LABEL_CDC_109
	ld   a, (S1_VDPREGISTER_1)
	and  %10111111
	ld   (S1_VDPREGISTER_1), a
	res  0, (iy+$00)
	call wait
	
	;map screen 1 tileset
	ld   hl, $0000
	ld   de, $0000
	ld   a, 12			;$30000
	call decompressArt
	
	;map screen 1 sprite set
	ld   hl, $526B			;$2926B
	ld   de, $2000
	ld   a, 9
	call decompressArt
	
	;HUD tileset
	ld      hl,$b92e		;$2F92E
	ld      de,$3000
	ld      a,9
	call decompressArt
	
	;load page 1 ($4000-$7FFF) with bank 5 ($14000-$17FFF)
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	;map 1 background
	ld      hl,$627e
	ld      bc,$0178
	ld      de,$3800
	ld      a,$10
	ld      ($d20e),a
	call decompressScreen
	
	;map 1 foreground
	ld      hl,$63f6
	ld      bc,$0145
	ld      de,$3800
	ld      a,$00
	ld      ($d20e),a
	call decompressScreen
	
	ld      hl,S1_MapScreen1_Palette
	call    _b50
	jr      _d3c
	
_LABEL_CDC_109:
	;turn the screen off
	ld   a, (S1_VDPREGISTER_1)
	and  %10111111			;remove bit 6 of VDP register 1
	ld   (S1_VDPREGISTER_1), a
	
	res  0, (iy+$00)
	call wait
	
	;map screen 2 tileset
	ld   hl, $1801			;$31801
	ld   de, $0000
	ld   a, 12
	call decompressArt
	
	;map screen 2 sprites
	ld      hl,$5942		;$29942
	ld      de,$2000
	ld      a,9
	call    decompressArt
	
	;HUD tileset
	ld      hl,$b92e		;$2F92E
	ld      de,$3000
	ld      a,$09
	call    decompressArt
	
	;load page 1 ($4000-$7FFF) with bank 5 ($14000-$17FFF)
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	;map screen 2 background
	ld      hl,$653b
	ld      bc,$0170
	ld      de,$3800
	ld      a,$10
	ld      ($d20e),a
	call    decompressScreen
	
	;map screen 2 foreground
	ld      hl,$66ab
	ld      bc,$0153
	ld      de,$3800
	ld      a,$00
	ld      ($d20e),a
	call    decompressScreen
	
	ld      hl,S1_MapScreen2_Palette
	call    _b50
_d3c:					;[$0D3C]
	ld      a,$07
	rst     $18
	
_LABEL_D3F_108:				;[$0D3F]
	call _LABEL_E86_110
	ld   a, (S1_CURRENT_LEVEL)
	add  a, a
	ld   c, a
	ld   b, $00
	ld   hl, S1_ZoneTitle_Pointers
	add  hl, bc
	ld   a, (hl)
	inc  hl
	ld   h, (hl)
	ld   l, a
	
	ld   a, %00010000		;display in-front of sprites (bit 12 of tile)
	ld   ($D20E), a
	call print
	
	ld   a, (S1_CURRENT_LEVEL)
	ld   c, a
	add  a, a
	add  a, c
	ld   e, a
	ld   d, $00
	ld   hl, _f4e
	add  hl, de
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	inc  hl
	ld   ($D210), de
	ld   a, (hl)
	and  a
	jr   z, _LABEL_D80_119
	
	dec  a
	add  a, a
	ld   e, a
	ld   d, $00
	ld   hl, $1201
	add  hl, de
	ld   a, (hl)
	inc  hl
	ld   h, (hl)
	ld   l, a
	jp   (hl)
_LABEL_D80_119:
	ld   a, $01
	ld      ($d20e),a
	ld      bc,$012c
_0d88:
	push    bc
	call    _LABEL_E86_110
	ld      a,($d20e)
	dec     a
	ld      ($d20e),a
	jr      nz,_0db7
	ld      hl,($d210)
_0d98:
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	ld      ($d214),bc
	ld      a,(hl)
	inc     hl
	and     a
	jr      nz,_0dad
	ex      de,hl
	jp      _0d98
_0dad:
	ld      ($d20e),a
	ld      ($d210),hl
	ld      ($d212),de
_0db7:
	ld      hl,($d214)
	push    hl
	ld      e,h
	ld      h,$00
	ld      d,h
	ld      bc,($d212)
	call    _LABEL_350F_95
	pop     hl
	ld      ($d214),hl
	pop     bc
	dec     bc
	ld      a,b
	or      c
	ret     z
	
	bit     5,(iy+$03)
	jp      nz,_0d88
	ret     nz
	scf     
_0dd8:
	ret     
_0dd9:
	ld      hl,$0000
	ld      ($d20e),hl
	ld      hl,$00dc
	ld      de,$003c
	ld      b,$00
_0de7:
	call    _LABEL_E86_110
	ld      a,(iy+$03)
	cp      $ff
	jp      nz,_LABEL_D80_119
	push    bc
	ld      bc,$0e72
	call    _0edd
	pop     bc
	dec     hl
	djnz    _0de7
	ld      hl,$0000
	ld      ($d20e),hl
	ld      hl,$ffd8
	ld      de,$0058
	ld      b,$80
_0e0b:
	call    _LABEL_E86_110
	ld      a,(iy+$03)
	cp      $ff
	jp      nz,_LABEL_D80_119
	push    bc
	ld      bc,$0e7a
	call    _0edd
	pop     bc
	inc     hl
	djnz    _0e0b
	jp      _LABEL_D80_119
	ld      hl,$0000
	ld      ($d20e),hl
	ld      hl,$0080
	ld      de,$00c0
	ld      b,$78
_0e32:
	call    _LABEL_E86_110
	ld      a,(iy+$03)
	cp      $ff
	jp      nz,_LABEL_D80_119
	push    bc
	ld      bc,_0e82
	call    _0edd
	pop     bc
	dec     de
	djnz    _0e32
	jp      _LABEL_D80_119
	ld      hl,$0000
	ld      ($d20e),hl
	ld      hl,$0078
	ld      de,$0000
	ld      b,$30
_0e59:
	call    _LABEL_E86_110
	ld      a,(iy+$03)
	cp      $ff
	jp      nz,_LABEL_D80_119
	push    bc
	ld      bc,_0e82
	call    _0edd
	pop     bc
	inc     de
	djnz    _0e59
	jp      _LABEL_D80_119
	add     hl,hl
	ld      de,$0104
	dec     sp
	ld      de,$0004
	ld      c,l
	ld      de,$0104
	ld      e,a
	ld      de,$0004
_0e82:
	add     a,e
	ld      de,$0004
_LABEL_E86_110:				;[$0E86]
	push hl
	push de
	push bc
	ld   hl, ($D20E)
	push hl
	res  0, (iy+$00)
	call wait
	ld   (iy+$0a), $00
	ld   a, (S1_LIVES)
	ld   l, a
	ld   h, $00
	ld   c, $0A
	call _LABEL_60F_111
	ld   a, l
	add  a, a
	add  a, $80
	ld   ($D2BE), a
	ld   c, $0A
	call _LABEL_5FC_114
	ex   de, hl
	ld   a, (S1_LIVES)
	ld   l, a
	ld   h, $00
	and  a
	sbc  hl, de
	ld   a, l
	add  a, a
	add  a, $80
	ld   ($D2BF), a
	ld   a, $FF
	ld   ($D2C0), a
	ld   b, $A7
	ld   c, $28
	ld   hl, $D000
	ld   de, $D2BE
	call _LABEL_35CC_117
	ld   ($D23C), hl
	pop  hl
	ld   ($D20E), hl
	pop  bc
	pop  de
	pop  hl
	ret
	
_0edd:
	push    hl
	push    de
	ld      l,c
	ld      h,b
	ld      a,($d20f)
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	ld      a,($d20e)
	cp      (hl)
	jr      c,_0efd
	inc     hl
	ld      a,(hl)
	ld      ($d20f),a
	xor     a
	ld      ($d20e),a
_0efd:
	pop     de
	pop     hl
	push    hl
	push    de
	call    _LABEL_350F_95
	ld      a,($d20e)
	inc     a
	ld      ($d20e),a
	pop     de
	pop     hl
	ret     
;______________________________________________________________________________________

S1_MapScreen1_Palette:			;[$0F0E]
.db $35, $01, $06, $0B, $04, $08, $0C, $3D, $1F, $39, $2A, $14, $25, $2B, $00, $3F
.db $2B, $20, $35, $1B, $16, $2A, $00, $3F, $03, $0F, $01, $15, $00, $3C, $00, $3F

S1_MapScreen2_Palette:			;[$0F2E]
.db $25, $01, $06, $0B, $04, $18, $2C, $35, $2B, $10, $2A, $14, $15, $1F, $00, $3F
.db $2B, $20, $35, $1B, $16, $2A, $00, $3F, $03, $0F, $01, $15, $07, $2D, $00, $3F

;--------------------------------------------------------------------------------------

;$0F4E-$1208: UNKNOWN
_f4e:
.db $84, $0F, $00			;Green Hill Act 1
.db $93, $0F, $00			;Green Hill Act 2
.db $DE, $0F, $01			;Green Hill Act 3
.db $A2, $0F, $00			;Bridge Act 1
.db $B1, $0F, $00			;Bridge Act 2
.db $7E, $10, $02			;Bridge Act 3
.db $C0, $0F, $00			;Jungle Act 1
.db $CF, $0F, $00			;Jungle Act 2
.db $88, $10, $03			;Jungle Act 3
.db $0B, $10, $00			;Labyrinth Act 1
.db $1A, $10, $00			;Labyrinth Act 2
.db $92, $10, $00			;Labyrinth Act 3
.db $29, $10, $00			;Scrap Brain Act 1
.db $38, $10, $00			;Scrap Brain Act 2
.db $9C, $10, $00			;Scrap Brain Act 3
.db $47, $10, $00			;Sky Base Act 1
.db $56, $10, $00			;Sky Base Act 2
.db $56, $10, $00			;Sky Base Act 3

_f84:					;Green Hill Act 1
.db $BD, $10, $50, $68, $1E, $AB, $10, $50, $68, $1E, $84, $0F, $00, $00, $00
_f93:					;Green Hill Act 2
.db $CF, $10, $50, $60, $1E, $AB, $10, $50, $60, $1E, $93, $0F, $00, $00, $00
_fa2:					;Bridge Act 1
.db $E1, $10, $60, $60, $1E, $AB, $10, $60, $60, $1E, $A2, $0F, $00, $00, $00
_fb1:					;Bridge Act 2
.db $F3, $10, $80, $50, $1E, $AB, $10, $80, $50, $1E, $B1, $0F, $00, $00, $00
_fc0:					;Jungle Act 1
.db $05, $11, $70, $48, $1E, $AB, $10, $70, $48, $1E, $C0, $0F, $00, $00, $00
_fcf:					;Jungle Act 2
.db $17, $11, $70, $38, $1E, $AB, $10, $70, $38, $1E, $CF, $0F, $00, $00, $00
_fde:					;Green Hill Act 3
.db $83, $11, $58, $58, $08, $83, $11, $58, $58, $08, $83, $11, $58, $56, $08
.db $83, $11, $58, $56, $08, $83, $11, $58, $55, $08, $83, $11, $58, $55, $08
.db $83, $11, $58, $56, $08, $83, $11, $58, $56, $08, $DE, $0F, $00, $00, $00
_100b:					;Labyrinth Act 1
.db $95, $11, $58, $68, $1E, $AB, $10, $58, $68, $1E, $0B, $10, $00, $00, $00
_101a:					;Labyrinth Act 2
.db $A7, $11, $68, $78, $1E, $AB, $10, $68, $78, $1E, $1A, $10, $00, $00, $00
_1029:					;Scrap Brain Act 1
.db $B9, $11, $70, $58, $1E, $AB, $10, $70, $58, $1E, $29, $10, $00, $00, $00
_1038:					;Scrap Brain Act 2
.db $CB, $11, $78, $48, $1E, $AB, $10, $78, $48, $1E, $38, $10, $00, $00, $00
_1047:					;Sky Base Act 1
.db $DD, $11, $68, $28, $1E, $AB, $10, $68, $28, $1E, $47, $10, $00, $00, $00
_1056:					;Sky Base Act 2 / 3
.db $EF, $11, $80, $28, $1E, $EF, $11, $80, $26, $08, $EF, $11, $80, $26, $08
.db $EF, $11, $80, $25, $08, $EF, $11, $80, $25, $08, $EF, $11, $80, $26, $08
.db $EF, $11, $80, $26, $08, $56, $10, $00, $00, $00
_107e:					;Bridge Act 3
.db $83, $11, $80, $48, $08, $7E, $10, $00, $00, $00
_1088:					;Jungle Act 3
.db $83, $11, $78, $30, $08, $88, $10, $00, $00, $00
_1092:					;Labyrinth Act 3
.db $83, $11, $70, $60, $08, $92, $10, $00, $00, $00
_109c:					;Scrap Brain Act 3
.db $29, $11, $68, $40, $08, $3B, $11, $68, $40, $08, $9C, $10, $00, $00, $00

_10ab:
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $00, $02, $FF, $FF, $FF, $FF, $FE, $22, $24, $26, $28, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $04, $06, $08, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $40, $42, $44, $46, $48, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $4A, $4C, $FF, $FF, $FF, $FF, $6A, $6C
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $60, $62, $64, $66, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FE, $FE, $0E, $FF
.db $FF, $FF, $2A, $2C, $2E, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $10, $12
.db $14, $16, $FF, $FF, $30, $32, $34, $36, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $10, $12, $14, $18, $FF, $FF, $30, $32, $34, $38, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $50, $54, $56, $58, $FF, $FF, $70, $74, $76, $78, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $52, $54, $56, $58, $FF, $FF, $72, $74, $76, $78, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $50, $54, $56, $58, $FF, $FF, $70, $74, $76, $78
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $5A, $5C, $5E, $FF, $FF, $FF, $7A, $7C
.db $7E, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $02, $FF, $FF, $FF, $FF
.db $20, $22, $04, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $0A, $0C, $0E, $FF
.db $FF, $FF, $2A, $2C, $2E, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $68, $6A
.db $6C, $FF, $FF, $FF, $FE, $FE, $6E, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $06, $08, $4A, $4C, $FF, $FF, $FE, $FE, $4E, $3E, $FF, $FF, $FE, $40, $42, $44
.db $FF, $FF, $60, $62, $64, $66, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $46, $48, $26, $28, $FF, $FF, $1A, $1C, $3A, $3C, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $D9, $0D, $24, $0E, $4B, $0E, $D9, $0D

;______________________________________________________________________________________

S1_ZoneTitle_Pointers:			;[$1209]

.dw S1_ZoneTitle_1			;Green Hill Act 1
.dw S1_ZoneTitle_1			;Green Hill Act 2
.dw S1_ZoneTitle_1			;Green Hill Act 3
.dw S1_ZoneTitle_2			;Bridge Act 1
.dw S1_ZoneTitle_2			;Bridge Act 2
.dw S1_ZoneTitle_2			;Bridge Act 3
.dw S1_ZoneTitle_3			;Jungle Act 1
.dw S1_ZoneTitle_3			;Jungle Act 2
.dw S1_ZoneTitle_3			;Jungle Act 3
.dw S1_ZoneTitle_4			;Labyrinth Act 1
.dw S1_ZoneTitle_4			;Labyrinth Act 2
.dw S1_ZoneTitle_4			;Labyrinth Act 3
.dw S1_ZoneTitle_5			;Scrap Brain Act 1
.dw S1_ZoneTitle_5			;Scrap Brain Act 2
.dw S1_ZoneTitle_5			;Scrap Brain Act 3
.dw S1_ZoneTitle_6			;Sky Base Act 1
.dw S1_ZoneTitle_6			;Sky Base Act 2
.dw S1_ZoneTitle_6			;Sky Base Act 3

S1_ZoneTitles:				;[$122D]

S1_ZoneTitle_1:		;"GREEN HILL"	;[$122D]
.db $10, $13, $46, $62, $44, $44, $51, $EB, $47, $40, $43, $43, $EB, $EB, $FF
S1_ZoneTitle_2:		;"BRIDGE"	;[$123C]
.db $10, $13, $35, $62, $40, $37, $46, $44, $EB, $EB, $EB, $EB, $EB, $EB, $FF
S1_ZoneTitle_3:		;"JUNGLE"	;[$124B]
.db $10, $13, $41, $81, $51, $46, $43, $44, $EB, $EB, $EB, $EB, $EB, $EB, $FF
S1_ZoneTitle_4:		;"LABYRINTH"	;[$125A]
.db $10, $13, $6F, $1E, $1F, $DE, $9F, $5E, $7F, $AF, $4F, $EB, $EB, $EB, $FF
S1_ZoneTitle_5:		;"SCRAP BRAIN"	;[$1269]
.db $10, $13, $AE, $2E, $9F, $1E, $8F, $EB, $1F, $9F, $1E, $5E, $7F, $EB, $FF
S1_ZoneTitle_6:		;"SKY BASE"	;[$1278]
.db $10, $13, $AE, $6E, $DE, $EB, $1F, $1E, $AE, $3E, $EB, $EB, $EB, $EB, $FF

;____________________________________________________________________________[$1287]___

titleScreen:
	;turn off screen
	ld   a, (S1_VDPREGISTER_1)
	and  %10111111			;remove bit 6 of $D219
	ld   (S1_VDPREGISTER_1), a
	
	;wait for interrupt to complete?
	res  0, (iy+$00)
	call wait
	
	;load the title screen tile set
	 ;BANK 9 ($24000) + $2000 = $26000
	ld   hl, $2000
	ld   de, $0000
	ld   a, $09
	call decompressArt
	
	;load the title screen sprite set
	 ;BANK 9 ($24000) + $4B0A = $28B0A
	ld   hl, $4B0A
	ld   de, $2000
	ld   a, $09
	call decompressArt
	
	;now switch page 1 ($4000-$7FFF) to bank 5 ($14000-$17FFF)
	ld   a, 5
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	
	;load the title screen itself
	ld   hl, $6000			;ROM:$16000
	ld   de, $3800
	ld   bc, $012E
	ld   a, $00
	ld   ($D20E), a
	call decompressScreen
	
	xor  a				;set A to zero
	ld   ($D251), a
	ld   ($D252), a
	ld   hl, $13E1
	ld   a, $03
	call loadPaletteOnInterrupt
	
	set  1, (iy+$00)
	ld   a, $06
	rst  $18
	
	xor  a
	ld   ($D216), a
	ld   a, $01
	ld   ($D20F), a
	ld   hl, _1372
	ld   ($D210), hl
_LABEL_12EA_102:
	ld   a, (S1_VDPREGISTER_1)
	or   $40
	ld   (S1_VDPREGISTER_1), a
	
	res  0, (iy+$00)
	call wait
	
	ld   a, ($D216)
	inc  a
	cp   $64
	jr   c, _LABEL_1302_89
	xor  a
_LABEL_1302_89:
	ld   ($D216), a
	ld   hl, _1352
	cp   $40
	jr   c, _LABEL_130F_90
	ld   hl, _1362
_LABEL_130F_90:
	xor  a				;set A to 0
	ld   ($D20E), a
	call print
	
	ld   a, ($D20F)
	dec  a
	ld   ($D20F), a
	jr   nz, _LABEL_1335_93
	ld   hl, ($D210)
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	inc  hl
	ld   a, (hl)
	inc  hl
	and  a
	jr   z, _LABEL_1350_94
	ld   ($D20F), a
	ld   ($D210), hl
	ld   ($D212), de
_LABEL_1335_93:
	ld   hl, $D000
	ld   ($D23C), hl
	ld   hl, $0080
	ld   de, $0018
	ld   bc, ($D212)
	call _LABEL_350F_95
	bit  5, (iy+$03)
	jp   nz, _LABEL_12EA_102
	scf
_LABEL_1350_94:
	rst  $20
	ret

_1352:					;text
.db $09, $12
.db $E3, $E4, $E5, $E6, $E6, $F1, $F1, $E9, $EB, $E7, $E7, $EA, $EC, $FF
_1362:					;text
.db $09, $12
.db $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $FF

_1372:					;unknown
.db $BD, $13, $08, $CF, $13, $08, $BD, $13, $08, $CF, $13, $08, $BD, $13, $08, $CF
.db $13, $08, $BD, $13, $08, $CF, $13, $08, $BD, $13, $08, $CF, $13, $08, $BD, $13
.db $08, $CF, $13, $08, $BD, $13, $08, $CF, $13, $08, $BD, $13, $08, $CF, $13, $08
.db $BD, $13, $08, $CF, $13, $08, $BD, $13, $08, $CF, $13, $08, $BD, $13, $08, $CF
.db $13, $08, $BD, $13, $FF, $BD, $13, $FF, $B4, $13, $00, $00, $02, $04, $FF, $FF
.db $FF, $20, $22, $24, $FF, $FF, $FF, $40, $42, $44, $FF, $FF, $FF, $06, $08, $FF
.db $FF, $FF, $FF, $26, $28, $FF, $FF, $FF, $FF, $46, $48, $FF, $FF, $FF, $FF

;______________________________________________________________________________________

S1_TitleScreen_Palette			;[$13E1]
.db $00, $10, $34, $38, $06, $1B, $2F, $3F, $3D, $3E, $01, $03, $0B, $0F, $00, $3F
.db $00, $10, $34, $38, $06, $1B, $2F, $3F, $3D, $3E, $01, $03, $0B, $0F, $00, $3F

;______________________________________________________________________________________

_1401:
	;turn off the screen
	ld      a,(S1_VDPREGISTER_1)
	and     %10111111		;remove bit 6 of VDP register 1
	ld      (S1_VDPREGISTER_1),a
	
	res     0,(iy+$00)
	call    wait
	di      
	
	;level complete sprite set
	ld      hl,$351f
	ld      de,$0000
	ld      a,9
	call    decompressArt
	
	;switch page 1 ($4000-$7FFF) to bank 5 ($14000-$17FFF)
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	;level complete background
	ld      hl,$67fe
	ld      bc,$0032
	ld      de,$3800
	ld      a,$00
	ld      ($d20e),a
	call    decompressScreen
	
	xor     a
	ld      ($d251),a
	ld      ($d252),a
	ld      hl,_14fc
	ld      a,$03
	call    loadPaletteOnInterrupt
	ei      
	ld      b,$78
_1447:
	;turn the screen on
	ld      a,(S1_VDPREGISTER_1)
	or      %01000000		;enable bit 6 on VDP register 1
	ld      (S1_VDPREGISTER_1),a
	
	res     0,(iy+$00)
	call    wait
	
	djnz    _1447
	
	ld      a,($d284)
	and     a
	jr      nz,_1477
	
	ld      bc,$00b4
_1461:
	push    bc
	
	res     0,(iy+$00)
	call    wait
	
	pop     bc
	dec     bc
	ld      a,b
	or      c
	ret     z
	
	bit     5,(iy+$03)
	jp      nz,_1461
	
	and     a
	ret     
_1477:
	ld      hl,_14de
	ld      c,$0b
	call    _16d9
	ld      hl,_14e6
	call    print
	ld      hl,_14f1
	call    print
	ld      a,$09
	ld      ($d216),a
_1490:
	ld      b,$3c
_1492:
	push    bc
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),$00
	ld      hl,$d216
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	ex      de,hl
	ld      hl,$d000
	ld      c,$8c
	ld      b,$5e
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	pop     bc
	bit     5,(iy+$03)
	jr      z,_14cc
	djnz    _1492
	ld      a,$1a
	rst     $28
	ld      hl,$d216
	ld      a,(hl)
	and     a
	ret     z
	dec     (hl)
	jr      _1490
_14cc:
	ld      hl,$d311
	call    _LABEL_C02_135
	ld      a,c
	cpl     
	ld      c,a
	ld      a,(hl)
	and     c
	ld      (hl),a
	ld      hl,$d284
	dec     (hl)
	scf     
	ret     

_14de:
.db $0f, $80, $81, $ff
.db $10, $90, $91, $ff
_14e6:					;text
.db $08, $0c, $67, $68, $69, $6a, $6b, $6c, $6d, $6e, $ff
_14f1:					;text
.db $08, $0d, $77, $78, $79, $7a, $7b, $7c, $7d, $7e, $ff

_14fc:
;this first bit looks like a palette
.db $00, $01, $06, $0B, $04, $08, $0C, $3D, $1F, $39, $2A, $14, $14, $27, $00, $3F
.db $00, $20, $35, $1B, $16, $2A, $00, $3F, $03, $0F, $01, $15, $00, $3C, $00, $3F

.db $01, $00, $00, $00, $00, $00, $00, $00, $01, $00, $00, $00, $05, $00, $00, $00
.db $10, $00, $00, $00, $30, $00, $00, $00, $50, $00, $00, $01, $00, $00, $00, $03
.db $00, $00, $05, $00, $03, $00, $02, $30, $02, $00, $01, $30, $01, $00, $00, $30
.db $00, $00, $1E, $15, $22, $15, $26, $15, $2A, $15, $2E, $15, $32, $15, $36, $15
.db $3A, $15

_155e:
	ld	a, (S1_CURRENT_LEVEL)
	cp 	19
	jp      z,_172f
	
	ld      a,(S1_VDPREGISTER_1)
	and     $bf
	ld      (S1_VDPREGISTER_1),a
	
	res     0,(iy+$00)
	call    wait
	
	;load HUD sprites
	ld      hl,$b92e
	ld      de,$3000
	ld      a,9
	call    decompressArt
	
	;level complete screen tile set
	ld      hl,$351f
	ld      de,$0000
	ld      a,9
	call    decompressArt
	
	;load page 1 ($4000-$7FFF) with bank 5 ($14000-$17FFF)
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	;UNKNOWN
	ld      hl,$612e
	ld      bc,$00bb
	ld      de,$3800
	ld      a,(S1_CURRENT_LEVEL)
	cp      28
	jr      c,_15ac
	
	;UNKNOWN
	ld      hl,$61e9		;$161E9?
	ld      bc,$0095
	ld      de,$3800
_15ac:
	xor     a
	ld      ($d20e),a
	call    decompressScreen
	
	ld      hl,_1711
	ld      c,$10
	ld      a,($d27f)
	and     a
	call    nz,_16d9
	
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      nc,_15fd
	
	ld      a,$15
	ld      ($d2be),a
	ld      a,$04
	ld      ($d2bf),a
	ld      a,(S1_CURRENT_LEVEL)
	ld      e,a
	ld      d,$00
	ld      hl,_1b69
	add     hl,de
	ld      e,(hl)
	ld      hl,_1b51
	add     hl,de
	ld      b,$04
_15e1:
	push    bc
	push    hl
	ld      de,$d2bf
	ld      a,(de)
	inc     a
	ld      (de),a
	inc     de
	ldi     
	ldi     
	ld      a,$ff
	ld      (de),a
	ld      hl,$d2be
	call    print
	pop     hl
	pop     bc
	inc     hl
	inc     hl
	djnz    _15e1
_15fd:
	xor     a
	ld      ($d251),a
	ld      ($d252),a
	ld      hl,$1b8d
	ld      a,$03
	call    loadPaletteOnInterrupt
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      c,_1625
	ld      hl,$d281
	inc     (hl)
	bit     2,(iy+$09)
	jr      nz,_1625
	ld      hl,$d282
	inc     (hl)
	ld      hl,$d285
	inc     (hl)
_1625:
	bit     2,(iy+$09)
	call    nz,_1719
	bit     3,(iy+$09)
	call    nz,_1726
	ld      hl,$153e
	ld      de,$154e
	ld      b,$08
_163b:
	ld      a,($d2ce)
	cp      (hl)
	jr      nz,_164b
	inc     hl
	ld      a,($d2cf)
	cp      (hl)
	jr      nc,_1658
	inc     hl
	jr      _164f
_164b:
	jr      nc,_1658
	inc     hl
	inc     hl
_164f:
	inc     de
	inc     de
	djnz    _163b
	ld      de,$151e
	jr      _165c
_1658:
	ex      de,hl
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
_165c:
	ld      hl,$d212
	ex      de,hl
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      c,_166a
	ld      hl,_1a14
_166a:
	ldi     
	ldi     
	ldi     
	ldi     
	set     1,(iy+$00)
	ld      b,$78
_1678:
	push    bc
	ld      a,(S1_VDPREGISTER_1)
	or      $40
	ld      (S1_VDPREGISTER_1),a
	
	res     0,(iy+$00)
	call    wait
	
	call    _1a18
	pop     bc
	djnz    _1678
_168e:
	res     0,(iy+$00)
	call    wait
	
	call    _1a18
	call    _19b4
	ld      a,(S1_CURRENT_LEVEL)
	cp      28
	call    c,_19df
	ld      a,($d216)
	inc     a
	ld      ($d216),a
	and     $03
	jr      nz,_16b1
	ld      a,$02
	rst     $28
_16b1:
	ld      hl,($d212)
	ld      de,($d214)
	ld      a,(S1_RINGS)
	or      h
	or      l
	or      d
	or      e
	jp      nz,_168e
	ld      b,$b4
_16c4:
	push    bc
	res     0,(iy+$00)
	call    wait
	call    _1a18
	pop     bc
	bit     5,(iy+$03)
	jr      z,_16d8
	djnz    _16c4
_16d8:
	ret     
_16d9:
	ld      b,a
	push    bc
	ld      de,$d2be
	srl     a
	ld      b,a
	ld      a,c
	sub     b
	ld      (de),a
	inc     de
	ld      bc,$0004
	ldir    
	ld      (de),a
	inc     de
	ld      bc,$0004
	ldir    
	pop     bc
	xor     a
	ld      ($d20e),a
_16f6:
	push    bc
	ld      hl,$d2be
	call    print
	ld      hl,$d2c3
	call    print
	ld      hl,$d2be
	inc     (hl)
	inc     (hl)
	ld      hl,$d2c3
	inc     (hl)
	inc     (hl)
	pop     bc
	djnz    _16f6
	ret     
_1711:
.db $14, $ad, $ae, $ff, $15, $bd, $be, $ff
_1719:
	xor     a
	ld      (S1_RINGS),a
	res     3,(iy+$09)
	res     2,(iy+$09)
	ret     
_1726:
	ld      hl,$d284
	inc     (hl)
	res     3,(iy+$09)
	ret     
_172f:
	ld      a,$ff
	ld      ($d2fd),a
	ld      c,$00
	ld      a,($d27f)
	cp      $06
	jr      c,_173f
	ld      c,$05
_173f:
	ld      a,($d280)
	cp      $12
	jr      c,_174b
	ld      a,c
	add     a,$05
	daa     
	ld      c,a
_174b:
	ld      a,($d281)
	cp      $08
	jr      c,_1757
	ld      a,c
	add     a,$05
	daa     
	ld      c,a
_1757:
	ld      a,($d282)
	cp      $08
	jr      c,_1763
	ld      a,c
	add     a,$05
	daa     
	ld      c,a
_1763:
	ld      a,($d283)
	and     a
	jr      nz,_176e
	ld      a,c
	add     a,$0a
	daa     
	ld      c,a
_176e:
	ld      a,c
	cp      $30
	jr      nz,_177b
	ld      a,c
	add     a,$0a
	daa     
	add     a,$0a
	daa     
	ld      c,a
_177b:
	ld      hl,$d2ff
	ld      (hl),c
	inc     hl
	ld      (hl),$00
	inc     hl
	ld      (hl),$00
	ld      hl,_1907
	call    print
	ld      hl,_191c
	call    print
	ld      hl,_1931
	call    print
	ld      hl,_1946
	call    print
	ld      hl,_1953
	call    print
	ld      hl,_1960
	call    print
	ld      hl,_196d
	call    print
	ld      hl,_197e
	call    print
	xor     a
	ld      ($d216),a
	ld      bc,$00b4
	call    _1860
_17bf:
	ld      bc,$003c
	call    _1860
	ld      a,($d27f)
	and     a
	jr      z,_17dd
	dec     a
	ld      ($d27f),a
	ld      de,$0000
	ld      c,$02
	call    _39d8
	ld      a,$02
	rst     $28
	jp      _17bf
_17dd:
	ld      bc,$00b4
	call    _1860
	ld      a,$01
	ld      ($d216),a
	ld      hl,_198e
	call    print
	ld      bc,$00b4
	call    _1860
_17f4:
	ld      bc,$001e
	call    _1860
	ld      a,(S1_LIVES)
	and     a
	jr      z,_1812
	dec     a
	ld      (S1_LIVES),a
	ld      de,$5000
	ld      c,$00
	call    _39d8
	ld      a,$02
	rst     $28
	jp      _17f4
_1812:
	ld      bc,$00b4
	call    _1860
	ld      a,$02
	ld      ($d216),a
	ld      hl,_199e
	call    print
	ld      hl,_197a
	call    print
	ld      bc,$00b4
	call    _1860
_182f:
	ld      bc,$001e
	call    _1860
	ld      a,($d2ff)
	and     a
	jr      z,_1859
	dec     a
	ld      c,a
	and     $0f
	cp      $0a
	jr      c,_1847
	ld      a,c
	sub     $06
	ld      c,a
_1847:
	ld      a,c
	ld      ($d2ff),a
	ld      de,$0000
	ld      c,$01
	call    _39d8
	ld      a,$02
	rst     $28
	jp      _182f
_1859:
	ld      bc,$01e0
	call    _1860
	ret     
_1860:
	push    bc
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),$00
	ld      hl,$d000
	ld      ($d23c),hl
	ld      hl,$d2ba
	ld      de,$d2be
	ld      b,$04
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$90
	ld      b,$80
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ld      a,($d216)
	and     a
	jr      nz,_18c5
	ld      hl,$d27f
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$90
	ld      b,$60
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ld      hl,_19ae
	ld      de,$d2be
	ld      b,$03
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$a0
	ld      b,$60
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	jr      _18ff
_18c5:
	dec     a
	jr      nz,_18e6
	call    _1aca
	ld      hl,_19b1
	ld      de,$d2be
	ld      b,$03
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$a0
	ld      b,$60
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	jr      _18ff
_18e6:
	ld      hl,$d2ff
	ld      de,$d2be
	ld      b,$03
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$a0
	ld      b,$60
	call    _LABEL_35CC_117
	ld      ($d23c),hl
_18ff:
	pop     bc
	dec     bc
	ld      a,b
	or      c
	jp      nz,_1860
	ret     

;these look like text boxes
_1907:
.db $07, $09, $DA, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DB
.db $DB, $DB, $DB, $DC, $FF
_191c:
.db $07, $0A, $EA, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EB
.db $EB, $EB, $EB, $EC, $FF
_1931:
.db $07, $0B, $FB, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC
.db $FC, $FC, $FC, $FD, $FF
_1946:
.db $11, $0B, $DA, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DB, $DC, $FF
_1953:
.db $11, $0C, $EA, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EB, $EC, $FF
_1960:
.db $11, $0D, $EA, $EB, $EB, $FA, $EB, $EB, $EB, $EB, $EB, $EC, $FF
_196d:
.db $11, $0E, $FB, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FD, $FF
_197a:
.db $14, $0D, $EB, $FF

_197e:					;"CHAOS EMERALD"
.db $08, $0A, $36, $47, $34, $61, $70, $EB, $44, $50, $44, $62, $34, $43, $37, $FF
_198e:					;"SONIC LEFT"
.db $08, $0A, $70, $52, $51, $40, $36, $EB, $43, $44, $45, $80, $EB, $EB, $EB, $FF
_199e:					;"SPECIAL BONUS"
.db $08, $0A, $70, $60, $44, $36, $40, $34, $43, $EB, $35, $52, $51, $81, $70, $FF

;unknown:
_19ae:
.db $02, $00, $00
_19b1:
.db $00, $50, $00

_19b4:
	ld      hl,S1_RINGS
	ld      a,(hl)
	and     a
	ret     z
	dec     a
	ld      c,a
	and     $0f
	cp      $0a
	jr      c,_19c6
	ld      a,c
	sub     $06
	ld      c,a
_19c6:
	ld      (hl),c
	ld      de,$0100
	ld      c,$00
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      c,_19db
	ld      a,($d285)
	ld      d,a
	ld      a,($d286)
	ld      e,a
_19db:
	call    _39d8
	ret     
_19df:
	ld      hl,($d212)
	ld      de,($d214)
	ld      a,h
	or      l
	or      d
	or      e
	ret     z
	ld      b,$03
	ld      hl,$d214
	scf     
_19f1:
	ld      a,(hl)
	sbc     a,$00
	ld      c,a
	and     $0f
	cp      $0a
	jr      c,_19ff
	ld      a,c
	sub     $06
	ld      c,a
_19ff:
	ld      a,c
	cp      $a0
	jr      c,_1a06
	sub     $60
_1a06:
	ld      (hl),a
	ccf     
	dec     hl
	djnz    _19f1
	ld      de,$0100
	ld      c,$00
	call    _39d8
	ret     
_1a14:
.db $00, $00, $00, $00
_1a18:
	ld      (iy+$0a),$00
	ld      hl,$d000
	ld      ($d23c),hl
	ld      hl,$d2ba
	ld      de,$d2be
	ld      b,$04
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$88
	ld      b,$50
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ld      hl,S1_RINGS
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$98
	ld      b,$80
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      c,_1a57
	ld      b,$68
_1a57:
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      c,_1a73
	ld      hl,$d285
	ld      de,$d2be
	ld      b,$02
	call    _1b13
	ld      b,$68
	jr      _1a80
_1a73:
	ld      hl,$151c
	ld      de,$d2be
	ld      b,$02
	call    _1b13
	ld      b,$80
_1a80
	ld      c,$c0
	ex      de,hl
	ld      hl,($d23c)
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	call    _1aca
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      nc,_1ab0
	ld      hl,$d212
	ld      de,$d2be
	ld      b,$04
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$88
	ld      b,$68
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ret     
_1ab0:
	ld      hl,$d284
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	ex      de,hl
	ld      hl,($d23c)
	ld      c,$a8
	ld      b,$80
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ret     
_1aca:
	ld      a,(S1_LIVES)
	ld      l,a
	ld      h,$00
	ld      c,$0a
	call    _LABEL_60F_111
	ld      a,l
	add     a,a
	add     a,$80
	ld      ($d2be),a
	ld      c,$0a
	call    _LABEL_5FC_114
	ex      de,hl
	ld      a,(S1_LIVES)
	ld      l,a
	ld      h,$00
	and     a
	sbc     hl,de
	ld      a,l
	add     a,a
	add     a,$80
	ld      ($d2bf),a
	ld      a,$ff
	ld      ($d2c0),a
	ld      c,$38
	ld      b,$9f
	ld      a,(S1_CURRENT_LEVEL)
	cp      $13
	jr      nz,_1b06
	ld      b,$60
	ld      c,$90
_1b06:
	ld      hl,($d23c)
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ret     
_1b13:
	ld      a,(hl)
	and     $f0
	jr      nz,_1b33
	ld      a,$fe
	ld      (de),a
	inc     de
	ld      a,(hl)
	and     $0f
	jr      nz,_1b3f
	ld      a,$fe
	ld      (de),a
	inc     hl
	inc     de
	djnz    _1b13
	ld      a,$ff
	ld      (de),a
	dec     de
	ld      a,$80
	ld      (de),a
	ld      hl,$d2be
	ret     
_1b33:
	ld      a,(hl)
	rrca    
	rrca    
	rrca    
	rrca    
	and     $0f
	add     a,a
	add     a,$80
	ld      (de),a
	inc     de
_1b3f:
	ld      a,(hl)
	and     $0f
	add     a,a
	add     a,$80
	ld      (de),a
	inc     hl
	inc     de
	djnz    _1b33
	ld      a,$ff
	ld      (de),a
	ld      hl,$d2be
	ret     

_1b51:
.db $83, $84, $93, $94, $A3, $A4, $B3, $B4, $85, $86, $95, $96, $A5, $A6, $B5, $B6
.db $87, $88, $97, $98, $A7, $A8, $B7, $B8
_1b69:
.db $00, $08, $10, $00, $08, $10, $00, $08, $10, $00, $08, $10, $00, $08, $10, $00
.db $08, $10, $00, $00, $08, $08, $08, $08, $08, $08, $08, $08, $00, $00, $00, $00
.db $00, $00, $00, $00

;____________________________________________________________________________[$1B8D]___

;"Sonic Has Passed" screen palette:
S1_ActComplete_Palette:
.db $35, $01, $06, $0B, $04, $08, $0C, $3D, $1F, $39, $2A, $14, $25, $2B, $00, $3F
.db $35, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $00, $00, $00

;______________________________________________________________________________________

_1bad:
	ld      hl,($d2b5)
	ld      de,_1bc6
	add     hl,de
	ld      a,(hl)
	ld      (iy+$03),a
	ld      a,($d223)
	and     $1f
	ret     nz
	ld      hl,($d2b5)
	inc     hl
	ld      ($d2b5),hl
	ret     

_1bc6:
.db $F7, $F7, $F7, $F7, $DF, $F7, $FF, $FF, $D7, $F7, $F7, $F7, $FF, $DF, $F7, $F7
.db $DF, $F7, $F7, $F7, $F7, $FF, $FF, $DF, $F7, $FF, $FF, $FF, $FB, $F7, $F7, $F5
.db $FF, $FF, $FF, $FF, $FB, $FB, $F9, $FF, $FF, $FF, $FF, $F7, $F7, $F7, $F7, $D7
.db $FF, $FF, $D7, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $D7, $FB, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $D7, $F7, $F7, $FF, $D7
.db $FB, $F7, $F7, $F7, $F7, $FB, $FB, $F7, $FF, $D7, $FB, $FF, $F7, $F7, $D7, $FB
.db $D7, $F7, $F7, $F7, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $F7, $F7, $F7, $D7, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $00

;--------------------------------------------------------------------------------------

_LABEL_1C49_62:				;[$1C49]
	;set bit 0 of the parameter address (IY=$D200); when `wait` is called,
	 ;execution will pause until an interrupt event switches bit 0 of $D200 on?
	set  0, (iy+$00)			
	ei				;enable interrupts
_LABEL_1C4E_105:
	ld   a, $03
	ld   (S1_LIVES), a
	
	ld   a, $05
	ld   ($D2FD), a
	
	ld   a, $1C
	ld   ($D23F), a
	
	xor  a				;set A to 0
	ld   (S1_CURRENT_LEVEL), a	;set starting level!
	ld   ($D223), a
	ld   (iy+$0d), a
	
	ld   hl, $D27F
	ld   b, $08
	call _fillMemoryWithValue
	
	ld   hl, $D200
	ld   b, $0E
	call _fillMemoryWithValue
	
	ld   hl, $D2BA
	ld   b, $04
	call _fillMemoryWithValue
	
	ld   hl, $D305
	ld   b, $18
	call _fillMemoryWithValue
	
	res  0, (iy+$02)
	res  1, (iy+$02)
	call hideSprites
	call titleScreen
	
	res  1, (iy+$05)
	jr   c, _LABEL_1C9F_104
	
	set  1, (iy+$05)
_LABEL_1C9F_104:
	;are we on the end sequence?
	ld   a, (S1_CURRENT_LEVEL)
	cp   19
	jr   nc, _LABEL_1C4E_105
	
	res  0, (iy+$02)
	res  1, (iy+$02)
	call hideSprites
	call _LABEL_C52_106
	bit  1, (iy+$05)
	jr   z, _LABEL_1CBD_120
	jp   c, _LABEL_1C4E_105
_LABEL_1CBD_120:
	call _LABEL_A40_121
	call hideSprites
	bit  0, (iy+$05)
	jr   nz, _LABEL_1CCF_128
	bit  4, (iy+$06)
	jr   nz, _LABEL_1CDB_129
_LABEL_1CCF_128:
	ld   b, $3C
_LABEL_1CD1_130:
	res  0, (iy+$00)
	call wait
	djnz _LABEL_1CD1_130
	rst  $20
_LABEL_1CDB_129:
	call _LABEL_1CED_131
	and     a
	jp      z,_LABEL_1C4E_105
	dec     a
	jr	z,_LABEL_1C9F_104
	jp      _LABEL_1CBD_120
	
;____________________________________________________________________________[$1CE8]___

_fillMemoryWithValue:
;HL :	memory address
;B  :	length
;A  :	value
	ld   (hl), a
	inc  hl
	djnz _fillMemoryWithValue
	ret

;____________________________________________________________________________[$1CED]___

;start level?
_LABEL_1CED_131:
	;load page 1 (Z80:$4000-$7FFF) with bank 5 (ROM:$14000-$17FFF)
	ld   a, 5
	ld   (SMS_PAGE_1), a
	ld   (S1_PAGE_1), a
	
	ld   a, (S1_CURRENT_LEVEL)
	bit  4, (iy+$06)
	jr   z, +
	ld   a, ($D2D3)

+	add  a, a			;double the level number
	ld   l, a			;put this into a 16-bit number
	ld   h, $00
	ld   de, $5580			;the level pointers table begins at $15580
					 ;page 1 $4000 + $1580
	add  hl, de			;offset into the pointers table
	ld   a, (hl)			;read the low byte
	inc  hl				;move forward
	ld   h, (hl)			;read the hi-byte
	ld   l, a			;add the lo-byte in to make a 16-bit address
	
	;is this a null level? (offset $0000); the `OR H` will set Z if the result
	 ;is 0, this will only ever happen with $0000
	or   h				
	jp   z, _LABEL_258B_133
	
	;add the pointer value to the level pointers table to find the start of the
	 ;level header (the level headers begin after the level pointers)
	add  hl, de			
	call loadLevel
	
	set     0,(iy+$02)
	set     1,(iy+$02)
	set     1,(iy+$00)
	set     3,(iy+$06)
	res     3,(iy+$07)
	res     0,(iy+$09)
	res     6,(iy+$06)
	res     0,(iy+$08)
	res     6,(iy+$00)
	
	bit     3,(iy+$05)		;auto scroll right?
	call    nz,_1ed8		;if yes, skip way ahead
	
	ld      b,$10
_1d42:
	push    bc
	
	res     0,(iy+$00)
	call    wait
	
	ld      (iy+$03),$ff		;clear joypad input
	
	ld      hl,($d223)
	inc     hl
	ld      ($d223),hl
	
	;switch page 1 ($4000-$7FFF) to bank 11 ($2C000-$2FFFF)
	ld      a,11
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	bit     2,(iy+$05)		;are rings enabled?
	call    nz,_3879
	
	ld      hl,$0060
	ld      ($d25f),hl
	
	ld      hl,$0088
	ld      ($d261),hl
	
	ld      hl,$0060
	ld      ($d263),hl
	
	ld      hl,$0070
	ld      ($d265),hl
	
	call    _239c
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	
	call    _2e5a
	call    _063e
	call    _06bd
	
	set     5,(iy+$00)		
	
	pop     bc
	djnz    _1d42
	
	bit     1,(iy+$05)
	jr      z,_1dae
	
	ld      hl,$0000
	ld      ($d2b5),hl
	ld      (iy+$0a),h
_1dae:
	res     0,(iy+$00)
	call    wait
	
	;switch page 1 ($4000-$7FFF) to bank 11 ($2C000-$2FFFF)
	ld      a,11
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	bit     2,(iy+$05)		;are rings enabled?
	call    nz,_3879
	
	bit     3,(iy+$06)		
	call    nz,_3a03
	
	ld      a,($d223)
	and     %00000001
	jr      nz,_1ddb
	
	ld      a,($d289)
	and     a
	call    nz,_1fa9
	
	jr      _1df0
_1ddb:
	ld      a,($d287)
	and     a
	jp      nz,_2067
_1de2:
	ld      a,($d2b1)
	and     a
	call    nz,_1f06
	
	bit     1,(iy+$07)		;is lightning effect enabled?
	call    nz,_1f49		;if so, handle that
_1df0:
	bit     1,(iy+$06)
	call    nz,_1e78
	
	bit     1,(iy+$05)		;demo mode?
	jr      z,_1e07
	
	bit     5,(iy+$03)		;Button B?
	jp      z,_20b8
	
	call    _1bad
_1e07:
	ld      hl,($d223)
	inc     hl
	ld      ($d223),hl
	
	bit     3,(iy+$05)		;auto scrolling to the right? (ala Bridge 2)
	call    nz,_1ee2
	
	bit     4,(iy+$05)		;auto scrolling upwards?
	call    nz,_1ef2
	
	bit     7,(iy+$05)		;no down scrolling (ala Jungle 2)
	call    nz,_1eff
	
	call    _23c9
	
	bit     2,(iy+$05)		;are rings enabled?
	call    nz,_239c
	
	xor     a			;set A to 0
	ld      ($d302),a
	ld      ($d2de),a
	ld      (iy+$0a),$15
	ld      hl,$d03f
	ld      ($d23c),hl
	ld      hl,$d001
	ld      b,$07
	ld      de,$0003
	ld      a,$e0
_1e48:
	ld      (hl),a
	add     hl,de
	ld      (hl),a
	add     hl,de
	ld      (hl),a
	add     hl,de
	djnz    _1e48
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	
	call    _2e5a
	call    _063e
	call    _06bd
	
	ld      hl,S1_VDPREGISTER_1
	set     6,(hl)
	
	bit     3,(iy+$07)		;paused?
	call    nz,_1e9e
	
	jp      _1dae

_1e78:
	ld      (iy+$03),$f7
	ld      hl,(S1_LEVEL_CROPLEFT)
	ld      de,$0112
	add     hl,de
	ex      de,hl
	ld      hl,($d3fe)
	xor     a
	sbc     hl,de
	ret     c
	ld      (iy+$03),$ff
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
	ld      ($d406),hl
	ld      ($d408),a
	ret     
_1e9e:
	bit     1,(iy+$05)		;demo mode?
	ret     nz
	rst     $20
_1ea4:
	ld      a,(iy+$0a)
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),a
	ld      a,11
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	bit     2,(iy+$05)		;are rings enabled?
	call    nz,_3879
	call    _23c9
	call    _239c
	bit     3,(iy+$07)		;paused?
	jr      nz,_1ea4
	
	ld      a,:_c009
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	call    _c009
	ret     
_1ed8:
	ld      hl,($d25a)
	ld      (S1_LEVEL_CROPLEFT),hl
	ld      ($d275),hl
	ret     
_1ee2:
	ld      a,($d223)
	rrca    
	ret     nc
_1ee7:
	ld      hl,(S1_LEVEL_CROPLEFT)
	inc     hl
	ld      (S1_LEVEL_CROPLEFT),hl
	ld      ($d275),hl
	ret     
_1ef2:
	ld      a,($d223)
	rrca    
	ret     nc
_1ef7:
	ld      hl,(S1_LEVEL_EXTENDHEIGHT)
	dec     hl
	ld      (S1_LEVEL_EXTENDHEIGHT),hl
	ret     
_1eff:
	ld      hl,($d25d)
	ld      (S1_LEVEL_EXTENDHEIGHT),hl
	ret     
_1f06:
	dec     a
	ld      ($d2b1),a
	ld      e,a
	di      
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ld      e,$00
	ld      a,($d2b2)
	ld      hl,($d230)
	and     a
	jp      p,_1f2f
	and     $7f
	ld      hl,($d232)
	ld      e,$10
_1f2f:
	ld      c,a
	ld      b,$00
	add     hl,bc
	add     a,e
	out     (SMS_VDP_CONTROL),a
	ld      a,$c0
	out     (SMS_VDP_CONTROL),a
	ld      a,($d2b1)
	and     $01
	ld      a,(hl)
	jr      z,_1f45
	ld      a,($d2b3)
_1f45:
	out     (SMS_VDP_DATA),a
	ei      
	ret     
_1f49:	;lightning is enabled...
	ld      de,($d2e9)
	ld      hl,$00aa
	xor     a
	sbc     hl,de
	jr      nc,_1f5d
	ld      bc,_1f9d
	ld      e,a
	ld      d,a
	jp      _1f80
_1f5d:
	ld      bc,_1fa5
	ld      hl,$0082
	sbc     hl,de
	jr      z,_1f7b
	ld      bc,$1fa1
	ld      hl,$0064
	sbc     hl,de
	jr      z,_1f80
	ld      bc,$1f9d
	ld      a,e
	or      d
	jr      z,_1f80
	jp      _1f97
_1f7b:
	push    bc
	ld      a,$13
	rst     $28
	pop     bc
_1f80:
	ld      hl,$d2a4
	ld      a,(bc)
	ld      (hl),a
	inc     hl
	ld      (hl),a
	inc     hl
	inc     bc
	ld      (hl),$00
	inc     hl
	ld      a,(bc)
	ld      (hl),a
	inc     bc
	ld      a,(bc)
	ld      l,a
	inc     bc
	ld      a,(bc)
	ld      h,a
	ld      ($d2a8),hl
_1f97:
	inc     de
	ld      ($d2e9),de
	ret    
	
;lightning palette control:
_1f9d:
.db $02, $04, $5e, $64
_1fa1:
.db $02, $04, $9e, $64
_1fa5:
.db $02, $04, $de, $64

_1fa9:
	dec     a
	ld      ($d289),a
	jr      z,_1fc4
	cp      $88
	ret     nz
	ld      a,($d288)
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,$2023
	add     hl,de
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	or      h
	ret     z
	jp      (hl)
_1fc4:
	call    _LABEL_A40_121
	pop     hl
	res     5,(iy+$00)
	bit     2,(iy+$0d)
	jr      nz,_201c
	bit     4,(iy+$06)
	jr      nz,_2020
	rst     $20
	bit     7,(iy+$06)
	call    nz,_20a4
	call    hideSprites
	call    _155e
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1a
	jr      nc,_2015
	bit     0,(iy+$07)
	jr      z,_200e
	ld      hl,$2047
	call    _b60
	ld      a,(S1_CURRENT_LEVEL)
	push    af
	ld      a,($d23f)
	ld      (S1_CURRENT_LEVEL),a
	inc     a
	ld      ($d23f),a
	call    _LABEL_1CED_131
	pop     af
	ld      (S1_CURRENT_LEVEL),a
_200e:
	ld      hl,$d23e
	inc     (hl)
	ld      a,$01
	ret     
_2015:
	res     0,(iy+$07)
	ld      a,$ff
	ret     
_201c:
	ld      hl,$d23e
	inc     (hl)
_2020:
	ld      a,$ff
	ret     
_2023:
.db $00, $00, $2d, $20, $31, $20, $39, $20, $3f, $20, $3e, $0e, $ef, $c9
_2031:
	ld      hl,S1_LIVES
	inc     (hl)
	ld      a,$09
	rst     $28
	ret     
_2039:
	ld      a,$10
	call    _39ac
	ret     
_203f
	ld      a,$07
	rst     $28
	set     0,(iy+$07)
	ret     
_2047:
.db $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F
.db $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F
_2067:
	dec	a
	ld      ($d287),a
	jp      nz,_1de2
	bit     1,(iy+$05)		;demo mode?
	jr      nz,_20b8
	bit     4,(iy+$0c)
	jr      z,_207e
	set     4,(iy+$06)
_207e:
	bit     7,(iy+$06)
	call    nz,_20a4
	ld      a,(S1_LIVES)
	and     a
	ld      a,$02
	ret     nz
	call    _LABEL_A40_121
	call    hideSprites
	res     5,(iy+$00)
	call    _1401
	ld      a,$00
	ret     nc
	ld      a,$03
	ld      (S1_LIVES),a
	ld      a,$01
	ret     
_20a4:
	ld      a,($d247)
	and     a
	jr      nz,_20a4
	di      
	res     7,(iy+$06)		;underwater?
	xor     a
	ld      ($d248),a
	ld      ($d2db),a
	ei      
	ret     
_20b8:
	ld      a,:_c00c
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      hl,$0028
	call    _c00c
	call    _LABEL_A40_121
	xor     a
	ret
	
;____________________________________________________________________________[$20CB]___

loadLevel:
;PAGE 1 ($4000-$7FFF) is at BANK 5 ($14000-$17FFF)
;HL : address for the level header
	ld   a, (S1_VDPREGISTER_1)
	and  %10111111			;remove bit 6
	ld   (S1_VDPREGISTER_1), a
	
	res  0, (iy+$00)
	call wait
	
	;copy the level header from ROM to RAM starting at $D354
	 ;(this copies 40 bytes, even though level headers are 37 bytes long.
	 ; the developers probably removed header bytes later in development)
	ld   de, $D354
	ld   bc, 40
	ldir
	
	ld   hl, $D354			;position HL at the start of the header
	push hl				;remember the start point
	
	ld   a, (iy+$05)		;read the current Scrolling / Ring HUD value
	ld   (iy+$0b), a		;take a copy
	ld   a, (iy+$06)		;read the current underwater flag value
	ld   (iy+$0c), a		;take a copy
	ld   a, $FF
	ld   ($D2AB), a
	
	xor  a				;set A to 0
	ld   l, a			;set HL to #$0000
	ld   h, a
	;clear some variables
	ld   ($D251), a
	ld   ($D252), a
	ld   ($D27B), hl
	ld   ($D27D), hl
	ld   ($D2B7), hl
	ld   ($D247), a
	ld   ($D248), a
	
	;clear $D287-$D2A4 (29 bytes)
	ld   hl, $D287
	ld   b, 29
	call _fillMemoryWithValue
	
	;something to do with grouping the levels into 8:
	 ;C returns a byte with bit x set, where x is the level number mod 8
	 ;DE will be the level number divided by 8
	 ;HL will be $D311 + the level number divided by 8
	ld   hl, $D311
	call _LABEL_C02_135
	
	;DE will now be $D311 + the level number divided by 8
	ex   de, hl
	
	ld   hl, $0800
	ld   a, (S1_CURRENT_LEVEL)
	cp   9				
	jr   c, ++			;less than level 9? (Labyrinth Act 1)
	cp   11
	jr   z, +			;if level 11 (Labyrinth Act 3)
	jr   nc, ++			;if >= level 11 (Labyrinth Act 3)
	
	;this must be level 9 or 10 (Labyrinth Act 1/2)
	ld   a, (de)			
	and  c				;is the bit for the level set?
	jr   z, ++			;if so, skip this next part

+	ld   a, $FF
	ld   ($D2DB), a
	ld   hl, $0020

++	ld   ($D2DC), hl		;either $0800 or $0020
	ld   hl, $FFFE
	ld   (S1_TIME), hl
	ld   hl, $23FF
	
	bit  4, (iy+$06)
	jr   z, _LABEL_2155_139
	
	bit  0, (iy+$05)
	jr   z, _LABEL_2172_140
	
	ld   hl, _2402
	
_LABEL_2155_139:
	xor  a				;set A to 0
	ld   (S1_RINGS), a
	
	;is this a special stage? (level number 28+)
	ld   a, (S1_CURRENT_LEVEL)
	sub  $1C
	jr   c, _LABEL_216A_141
	ld   c, a
	add  a, a
	add  a, c
	ld   e, a
	ld   d, $00
	ld   hl, _2405
	add  hl, de
	
_LABEL_216A_141:
	ld   de, $D2CE
	ld   bc, $0003
	ldir
	
_LABEL_2172_140:
	;load HUD sprite set
	ld   hl, $B92E			;$2F92E
	ld   de, $3000
	ld   a, 9
	call decompressArt
	
	pop     hl			;get back the address to the level header
	;SP: Solidity Pointer
	ld      a,(hl)
	ld      (S1_LEVEL_SOLIDITY),a
	inc     hl
	;FW: Floor Width
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (S1_LEVEL_FLOORWIDTH),de
	;FH: Floor Height
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (S1_LEVEL_FLOORHEIGHT),de
	;copy the next 8 bytes to $D273+
	 ;CL: Crop Left
	 ;LX: Level X Offset
	 ;??: Unknown
	 ;LW: Level Width
	 ;CT: Crop Top
	 ;LY: Level Y Offset
	 ;XH: Extend Height
	 ;LH: Level Height
	ld      de,S1_LEVEL_CROPLEFT
	ld      bc,$0008
	ldir    
	
	;currently HL will be sitting on byte 14 ("SX") of the level header
	push    hl
	push    hl
	
	;do the strange thing with dividing the level number by 8:
	 ;C returns a byte with bit x set, where x is the level number mod 8
	 ;DE will be the level number divided by 8
	 ;HL will be $D311 + the level number divided by 8
	ld      hl,$d311
	call    _LABEL_C02_135
	
	ld      a,(hl)
	ex      de,hl			;DE will now be $D311+
	
	;return to the "SX" byte in the level header,
	 ;A will have been set from $D311+
	pop     hl
	
	and     c			
	jr      z,+			
	
	cpl     			;NOT A
	ld      c,a
	ld      a,(de)			;Set A to the value at $D311+0-7
	and     c			;unset the level bit
	ld      (de),a			
	
	;copy 3 bytes from $2402 to $D2CE, these will be $01, $30 & $00
	ld      hl,_2402
	ld      de,$d2ce
	ld      bc,$0003
	ldir    
	
	ld      a,(S1_CURRENT_LEVEL)	;get current level number
	add     a,a			;double it (i.e. for 16-bit tables)
	ld      e,a			;put it into DE
	ld      d,$00
	
	ld      hl,$d32e		
	add     hl,de			;$D32E + (level number * 2)
	
	;NOTE: since other data in RAM begins at $D354 (a copy of the level header)
	 ;this places a limit -- 19 -- on the number of main levels.
	 ;special stages and levels visited by teleporter are not included
	
+	ld      ($d216),hl		
	ld      a,(hl)			;get the value at that RAM address	
	
	;is it greater than or equal to 3?
	sub     3			
	jr      nc,+			
	xor     a			
	
+	ld      ($d257),a
	;using the number as the hi-byte, divide by 8 into DE, e.g.
	 ;4	A: 00000100 E: 00000000 (1024) -> A: 00000000 E: 10000000 (128)
	 ;5	A: 00000101 E: 00000000 (1280) -> A: 00000000 E: 10100000 (160)
	 ;6	A: 00000110 E: 00000000 (1536) -> A: 00000000 E: 11000000 (192)
	 ;7	A: 00000111 E: 00000000 (1792) -> A: 00000000 E: 11100000 (224)
	 ;8	A: 00001000 E: 00000000 (2048) -> A: 00000001 E: 00000000 (256)
	;as you can see, the effective outcome is multiplying by 32!
	ld      e,$00
	rrca    
	rr      e
	rrca    
	rr      e
	rrca    
	rr      e
	and     %00011111		;mask off the top 3 bits from the rotation
	ld      d,a
	ld      ($d25a),de
	ld      ($d26f),de
	
	;move to the second byte, repeat the same process
	inc     hl
	ld      a,(hl)
	
	sub     $03
	jr      nc,+
	xor     a
	
+	ld      ($d258),a
	ld      e,$00
	rrca    
	rr      e
	rrca    
	rr      e
	rrca    
	rr      e
	and     %00011111		;mask off the top 3 bits from the rotation
	ld      d,a
	ld      ($d25d),de
	ld      ($d271),de
	
	;return to the "SX" byte in the level header
	pop     hl
	inc     hl			;skip over "SX"
	inc     hl			;and "SY"
	
	;since we skip Sonic's X/Y position, where do these get used?
	 ;assumedly from the level header copied to RAM at $D354+?
	
	;FL: Floor Layout
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	;FS: Floor Size
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	
	;remember our place in the level header, we're currently sitting at the
	 ;"BM" Block Mapping bytes
	push    hl
	
	ex      de,hl			;HL will be the Floor Layout address
	ld      a,h			;look at the hi-byte of the Floor Layout
	di      
	cp      $40			;is it $40xx or above?
	jr      c,_222e
	sub     $40
	ld      h,a
	ld      a,6
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,7
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	jr      _223e
_222e:
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,6
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
_223e:
	ei      			;enable interrupts
	
	;load the Floor Layout into RAM
	ld      de,$4000		;re-base the Floor Layout address to Page 1
	add     hl,de
	call    loadFloorLayout
	
	;return to our place in the level header
	pop     hl
	
	;BM: Block Mapping address
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	
	;swap DE & HL
	 ;DE will be current position in the level header
	 ;HL will be Block Mapping address
	ex      de,hl
	
	;rebase the Block Mapping address to Page 1
	ld      bc,$4000
	add     hl,bc
	ld      ($d24f),hl
	
	;swap back DE & HL
	 ;HL will be current position in the level header
	ex      de,hl
	
	;LA : Level Art address
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	
	;store the current position in the level header
	push    hl
	
	;swap DE & HL
	 ;DE will be current position in the level header
	 ;HL will be Level Art address
	ex      de,hl
	
	;load the level art from bank 12+ ($30000)
	ld      de,$0000
	ld      a,12
	call    decompressArt
	
	;return to our position in the level header
	pop     hl
	
	;get the bank number for the sprite art
	ld      a,(hl)
	inc     hl
	
	;SA: Sprite Art address
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	;handle as with Level Art
	push    hl
	ex      de,hl
	ld      de,$2000
	call    decompressArt
	pop     hl
	
	;IP: Initial Palette
	ld      a,(hl)
	
	;store our current position in the level header
	push    hl
	
	;convert the value to 16-bit for a lookup in the palette pointers table
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,$627c
	add     hl,de
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	di      
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ei      
	
	;read the palette pointer into HL
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	;queue the palette to be loaded via the interrupt
	ld      a,$03
	call    loadPaletteOnInterrupt
	
	res     0,(iy+$00)
	call    wait
	
	call    _0966
	
	pop     hl
	inc     hl
	
	;CS: Cycle Speed
	ld      de,$d2a4
	ld      a,(hl)
	ld      (de),a
	inc     de
	;store a second copy at the next byte in RAM
	ld      (de),a
	inc     de
	inc     hl
	;store 0 at the next byte in RAM
	xor     a
	ld      (de),a
	inc     de
	
	;CC: Colour Cycles
	ld      a,(hl)
	ld      (de),a
	
	;CP: Cycle Palette
	inc     hl
	ld      a,(hl)
	
	;swap DE & HL,
	 ;DE will be current position in the level header
	ex      de,hl
	
	add     a,a			;double the cycle palette index
	ld      c,a			;put it into a 16-bit number
	ld      b,$00
	ld      hl,$628c		;offset into the cycle palette pointers table
	add     hl,bc			
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	di      
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ei      
	
	;read the cycle palette pointer
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      ($d2a8),hl
	
	;swap back DE & HL
	 ;HL will be the current position in the level header
	ex      de,hl
	
	;OL: Object Layout
	inc     hl
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	
	;store the current position in the level header
	push    hl
	
	;the object layouts are relative from $15580, which is just odd really
	ld      hl,$5580
	add     hl,de
	
	;switch page 1 ($4000-$BFFF) to page 5 ($14000-$17FFF)
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	call    _232b			;load the object layout
	
	pop     hl
	
	;SR: Scrolling / Ring HUD flags
	ld      c,(hl)
	ld      a,(iy+$05)		
	and     %00000010
	or      c
	ld      (iy+$05),a
	
	;UW: Underwater flag
	inc     hl
	ld      a,(hl)
	ld      (iy+$06),a
	
	;TL: Time HUD / Lightning effect flags
	inc     hl
	ld      a,(hl)
	ld      (iy+$07),a
	
	;00: Unknown byte
	inc     hl
	ld      a,(hl)
	ld      (iy+$08),a
	
	;MU: Music
	inc     hl
	ld      a,($d2d2)		;check current music
	cp      (hl)
	jr      z,+			;if current music is the same, skip ahead
	
	ld      a,(hl)			;get the music number from the level header
	and     a			;this won't change the value of A, but it will
					 ;update the flags, so that ...
	jp      m,+			;we can check if the sign is negative,
					 ;that is, A>127
	
	;I believe this queues the music to be loaded
	ld      ($d2fc),a
	rst     $18

	;fill 64 bytes (32 16-bit numbers) from $D37C-$D3BC
+	ld      b,$20
	ld      hl,$d37c
	xor     a			;set A to 0

-	ld      (hl),a
	inc     hl
	ld      (hl),a
	inc     hl
	djnz    -
	
	bit     5,(iy+$0c)
	ret     z
	set     5,(iy+$06)
	
	ret     
	
;____________________________________________________________________________[$232B]___

;load object layout
_232b:
;HL : address of an object layout?
	push    hl
	
	ld      ix,$d3fc		;current level's object list
	ld      de,$001a
	ld      c,$00
	ld      hl,($d216)		;per-level X/Y position
	ld      a,$00
	call    _235e
	
	pop     hl
	
	ld      a,(hl)			;number of objects
	inc     hl
	
	ld      ($d2f2),a
	dec     a
	ld      b,a

	;loop over the number of objects:
-	ld      a,(hl)			;load the Object ID
	inc     hl
	call    _235e
	djnz    -
	
	ld      a,($d2f2)
	ld      b,a
	ld      a,$20
	sub     b
	ret     z
	ld      b,a

-	ld      (ix+$00),$ff
	add     ix,de
	djnz    -
	ret     

;__________________________________________________________________________[$235E]_____

;add object
_235e:
	ld      (ix+$00),a		;set $D3FC with the Object ID
	ld      a,(hl)			;X or Y position?
	exx     
	ld      l,a			;convert A to 16-bit number in HL
	ld      h,$00
	ld      (ix+$01),h
	;multiply by 32
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      (ix+$02),l
	ld      (ix+$03),h
	exx     
	
	;X or Y positiond
	inc     hl
	ld      a,(hl)
	
	exx     
	ld      l,a
	ld      h,$00
	ld      (ix+$04),h
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      (ix+$05),l
	ld      (ix+$06),h
	
	;transfer IX to HL
	push    ix
	pop     hl
	
	ld      de,7
	add     hl,de
	ld      b,$13
	xor     a			;set A to 0

-	ld      (hl),a
	inc     hl
	djnz    -
	
	exx     
	;add 7 to the original IX value
	inc     hl
	add     ix,de
	ret     

;______________________________________________________________________________________

;cycle palette?
_239c:
;ld      ($d25f) = $0060	
;ld      ($d261) = $0088	
;ld      ($d263) = $0060
;ld      ($d265) = $0070
	ld      a,($d297)
	ld      e,a
	ld      d,$00
	ld      hl,_23f9
	add     hl,de
	ld      a,(hl)
	ld      l,d
	srl     a
	rr      l
	ld      h,a
	ld      de,$7cf0
	add     hl,de
	ld      ($d293),hl
	ld      hl,$d298
	ld      a,(hl)
	inc     a
	ld      (hl),a
	cp      $0a
	ret     c
	ld      (hl),$00
	dec     hl
	ld      a,(hl)
	inc     a
	cp      $06
	jr      c,_23c7
	xor     a
_23c7:
	ld      (hl),a
	ret     
_23c9:
	ld      a,($d2a4)		;palette Cycle Speed
	dec     a
	ld      ($d2a4),a
	ret     nz
	
	ld      a,($d2a6)
	ld      l,a
	ld      h,$00
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      de,($d2a8)
	add     hl,de
	ld      a,$01
	call    loadPaletteOnInterrupt
	ld      hl,($d2a6)
	ld      a,l
	inc     a
	cp      h
	jr      c,_23ee
	xor     a
_23ee:
	ld      l,a
	ld      ($d2a6),hl
	ld      a,($d2a5)
	ld      ($d2a4),a
	ret     

_23f9:
.db $05, $04, $03, $02, $01, $00
_23ff:
.db $00, $00, $00
_2402:
.db $01, $30, $00
_2405:
.db $01, $00, $00

.db $01
.db $00, $00, $00, $45, $00, $00, $50, $00, $00, $45, $00, $00, $50, $00, $00, $50
.db $00, $00, $30, $00, $01, $00, $00, $01, $00, $01, $02, $00, $01, $02, $FF, $02
.db $03, $01, $01, $03, $FE, $02, $04, $01, $01, $04, $FD, $03, $05, $02, $01, $06
.db $FB, $03, $06, $03, $00, $07, $FA, $03, $06, $05, $FF, $08, $F9, $03, $07, $06
.db $FE, $09, $F7, $03, $07, $08, $FD, $0A, $F6, $02, $07, $09, $FB, $0B, $F4, $01
.db $06, $0B, $FA, $0B, $F3, $00, $06, $0D, $F8, $0B, $F2, $FF, $05, $0E, $F6, $0B
.db $F1, $FD, $03, $10, $F4, $0B, $F0, $FB, $02, $12, $F2, $0A, $F0, $F9, $00, $13
.db $F0, $09, $F0, $F7, $FE, $14, $EE, $08, $F0, $F4, $FC, $15, $EC, $07, $F0, $F2
.db $F9, $15, $EA, $05, $F1, $EF, $F6, $16, $E9, $02, $F2, $ED, $F4, $15, $E7, $00
.db $F4, $EB, $F1, $15, $E6, $FD, $F5, $E8, $EE, $14, $E5, $FA, $F8, $E6, $EB, $13
.db $E5, $F7, $FA, $E4, $E8, $11, $E5, $F4, $FD, $E3, $E5, $0F, $E5, $F1, $00, $E1
.db $E3, $0D, $E6, $ED, $03, $E0, $E0, $0A, $E7, $EA, $07, $E0, $DE, $07, $E9, $E6
.db $0B, $DF, $DD, $04, $EB, $E3, $0E, $DF, $DB, $00, $EE, $E0, $12, $E0, $DA, $FC
.db $F1, $DD, $16, $E1, $DA, $F8, $F4, $DB, $1A, $E3, $DA, $F4, $F8, $D8, $1E, $E5
.db $DA, $EF, $FC, $D7, $22, $E8, $DB, $EB, $00, $D5, $25, $EB, $DC, $E6, $05, $D4
.db $28, $EE, $DE, $E2, $09, $D4, $2B, $F2, $E1, $DE, $0E, $D4, $2D, $F6, $E4, $D9
.db $13, $D5, $2F, $FB, $E8, $D6, $18, $D6, $31, $00, $EC, $D2, $1D, $D8, $32, $05
.db $F0, $CF, $22, $DA, $32, $0B, $F5, $CD, $27, $DD, $32, $10, $FA, $CB, $2B, $E0
.db $31, $16, $00, $C9, $2F, $E5, $2F, $1B, $06, $C8, $33, $E9, $2D, $21, $0C, $C8
.db $36, $EE, $2B, $26, $12, $C8, $39, $F4, $27, $2B, $18, $CA, $3B, $FA, $23, $30
.db $1E, $CB, $3D, $00, $1E, $35, $24, $CE, $3E, $06, $19, $39, $2A, $D1, $3E, $0D
.db $14, $3C, $30, $D5, $3D, $14, $0D, $3F, $35, $D9, $3C, $1B, $07, $41, $3A, $DF
.db $3A, $21, $00, $43, $3E, $E4, $37, $28, $F9, $44, $42, $EB, $33, $2E, $F2, $44
.db $45, $F1, $2F, $34, $EA, $43, $47, $F9, $2A, $3A, $E3, $41, $49, $00, $24, $3F
.db $DC, $3F

;skip null level / do end sequence?
_LABEL_258B_133:			;[$258B]
	ld   a, (S1_VDPREGISTER_1)
	and  %10111111
	ld   (S1_VDPREGISTER_1), a
	
	res  0, (iy+$00)
	call wait
	
	xor  a
	ld   ($D251), a			;horizontal scroll
	ld   ($D252), a			;vertical scroll
	
	ld   hl, $2828
	ld   a, $03
	call loadPaletteOnInterrupt
	
	;load the map screen 1
	ld   hl, $0000
	ld   de, $0000
	ld   a, $0C			;bank 12 ($30000+)
	call decompressArt
	
	;load page 1 ($4000-$7FFF) with bank 5 ($14000-$17FFF)
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	;map 3 screen (end of game)
	ld      hl,$6830
	ld      bc,$0179
	ld      de,$3800
	xor     a
	ld      ($d20e),a
	call    decompressScreen
	
	ld      a,(S1_VDPREGISTER_1)
	or      $40
	ld      (S1_VDPREGISTER_1),a
	
	res     0,(iy+$00)
	call    wait
	
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	ld      a,($d27f)
	cp      $06
	jp      c,_2693
	ld      b,$3c
_25ed:
	push    bc
	
	res     0,(iy+$00)
	call    wait
	
	ld      hl,$d000
	ld      c,$70
	ld      b,$60
	ld      de,_2825
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	pop     bc
	djnz    _25ed
	ld      a,$13
	rst     $18
	ld      hl,$241d
	ld      b,$3d
_2610:
	push    bc
	ld      c,(iy+$0a)
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),c
	res     0,(iy+$00)
	call    wait
	ld      de,$d000
	ld      ($d23c),de
	ld      b,$03
_262e:
	push    bc
	push    hl
	ld      a,$70
	add     a,(hl)
	ld      c,a
	inc     hl
	ld      a,$60
	add     a,(hl)
	ld      b,a
	inc     hl
	push    bc
	ld      de,_2825
	ld      hl,($d23c)
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	pop     bc
	pop     hl
	ld      a,(hl)
	neg     
	add     a,$70
	ld      c,a
	inc     hl
	ld      a,(hl)
	neg     
	add     a,$60
	ld      b,a
	inc     hl
	push    hl
	ld      de,_2825
	ld      hl,($d23c)
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	pop     hl
	pop     bc
	djnz    _262e
	pop     bc
	djnz    _2610
	ld      hl,_2047
	call    _b60
	ld      (iy+$0a),$00
	
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	;UNKNOWN
	ld      hl,$69a9
	ld      bc,$0145
	ld      de,$3800
	xor     a
	ld      ($d20e),a
	call    decompressScreen
	
	ld      hl,_2828
	call    _aae
_2693:
	ld      bc,$00f0
	call    _2745
	call    _155e
	ld      bc,$00f0
	call    _2745
	call    _LABEL_A40_121
	ld      bc,$0078
	call    _2745
	
	;map screen 2 / credits screen tile set
	ld      hl,$1801
	ld      de,$0000
	ld      a,12
	call    decompressArt
	
	;title screen animated finger sprite set
	ld      hl,$4b0a
	ld      de,$2000
	ld      a,9
	call    decompressArt
	
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (S1_PAGE_1),a
	
	;credits screen
	ld      hl,$6c61
	ld      bc,$0189
	ld      de,$3800
	xor     a
	ld      ($d20e),a
	call    decompressScreen
	
	xor     a
	ld      hl,$d322
	ld      (hl),$48
	inc     hl
	ld      (hl),$28
	inc     hl
	ld      (hl),a
	inc     hl
	ld      (hl),$57
	inc     hl
	ld      (hl),$28
	inc     hl
	ld      (hl),a
	inc     hl
	ld      (hl),$69
	inc     hl
	ld      (hl),$28
	inc     hl
	ld      (hl),a
	inc     hl
	ld      (hl),$72
	inc     hl
	ld      (hl),$28
	inc     hl
	ld      (hl),a
	ld      bc,$0001
	call    _2718
	ld      hl,_2ad6
	call    _b50
	ld      a,$0e
	rst     $18
	xor     a
	ld      ($d20e),a
	ld      hl,_2905
	call    _2795
	
_2715:					;infinite loop!?
	jp      _2715

_2718:
	push    af
	push    hl
	push    de
	push    bc
_271c:
	push    bc
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),$00
	ld      hl,$d000
	ld      ($d23c),hl
	ld      hl,$d322
	ld      b,$04
_2733:
	push    bc
	call    _275a
	pop     bc
	djnz    _2733
	pop     bc
	dec     bc
	ld      a,b
	or      c
	jr      nz,_271c
	pop     bc
	pop     de
	pop     hl
	pop     af
	ret     
_2745:
	push    bc
	ld      a,(iy+$0a)
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),a
	pop     bc
	dec     bc
	ld      a,b
	or      c
	jr      nz,_2745
	ret     
_275a:
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	inc     (hl)
	ld      a,(de)
	cp      (hl)
	jr      nc,_277e
	ld      (hl),$00
	inc     de
	inc     de
	inc     de
	dec     hl
	ld      (hl),d
	dec     hl
	ld      (hl),e
	inc     hl
	inc     hl
	ld      a,(de)
	cp      $ff
	jr      nz,_277e
	inc     de
	ld      a,(de)
	ld      b,a
	inc     de
	ld      a,(de)
	dec     hl
	ld      (hl),a
	dec     hl
	ld      (hl),b
	jr      _275a
_277e:
	inc     hl
	inc     de
	push    hl
	ex      de,hl
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ex      de,hl
	ld      a,(hl)
	inc     hl
	ld      e,(hl)
	inc     hl
	ld      c,l
	ld      b,h
	ld      l,a
	ld      h,$00
	ld      d,h
	call    _LABEL_350F_95
	pop     hl
	ret     

_2795:
	ld      de,$d2be
	ldi     
	ldi     
	inc     de
	ld      a,$ff
	ld      (de),a
_27a0:
	ld      a,(hl)
	inc     hl
	cp      $ff
	ret     z
	cp      $fe
	jr      z,_2795
	cp      $fc
	jr      z,_27d1
	cp      $fd
	jr      nz,_27ba
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	call    _2718
	jr      _27a0
_27ba:
	push    hl
	ld      ($d2c0),a
	ld      bc,$0008
	call    _2718
	ld      hl,$d2be
	call    print
	ld      hl,$d2be
	inc     (hl)
	pop     hl
	jr      _27a0
_27d1:
	ld      b,(hl)
	inc     hl
	push    hl
_27d4:
	push    bc
	ld      bc,$000c
	call    _2718
	ld      de,$3aa4
	ld      hl,$3ae4
	ld      b,$09
_27e3:
	push    bc
	push    hl
	push    de
	ld      b,$14
_27e8:
	di      
	ld      a,l
	out     (SMS_VDP_CONTROL),a
	ld      a,h
	out     (SMS_VDP_CONTROL),a
	push    ix
	pop     ix
	in      a,(SMS_VDP_DATA)
	ld      c,a
	push    ix
	pop     ix
	ld      a,e
	out     (SMS_VDP_CONTROL),a
	ld      a,d
	or      $40
	out     (SMS_VDP_CONTROL),a
	push    ix
	pop     ix
	ld      a,c
	out     (SMS_VDP_DATA),a
	push    ix
	pop     ix
	ei      
	inc     hl
	inc     de
	djnz    _27e8
	pop     de
	pop     hl
	ld      bc,$0040
	add     hl,bc
	ex      de,hl
	add     hl,bc
	ex      de,hl
	pop     bc
	djnz    _27e3
	pop     bc
	djnz    _27d4
	pop     hl
	jp      _27a0

_2825:
.db $5c, $5e, $ff
_2828:
.db $35, $01, $06, $0B, $04, $08, $0C, $3D, $1F, $39, $2A, $14, $25, $2B, $00, $3F
.db $35, $20, $35, $1B, $16, $2A, $00, $3F, $03, $0F, $01, $15, $00, $3C, $00, $3F
.db $96, $02, $29, $86, $9F, $28, $E9, $02, $29, $6F, $9F, $28, $FF, $48, $28, $36
.db $B1, $28, $48, $BA, $28, $54, $A8, $28, $1E, $B1, $28, $44, $BA, $28, $FF, $57
.db $28, $23, $C3, $28, $23, $CC, $28, $FF, $69, $28, $E4, $F3, $28, $19, $E4, $28
.db $19, $D5, $28, $19, $E4, $28, $19, $D5, $28, $FA, $F3, $28, $85, $E4, $28, $E8
.db $F3, $28, $19, $E4, $28, $19, $D5, $28, $19, $E4, $28, $19, $D5, $28, $19, $E4
.db $28, $19, $D5, $28, $FF, $72, $28, $40, $48, $50, $FF, $FF, $FF, $FF, $FF, $FF
.db $40, $58, $4A, $FF, $FF, $FF, $FF, $FF, $FF, $40, $58, $4C, $FF, $FF, $FF, $FF
.db $FF, $FF, $40, $58, $4E, $FF, $FF, $FF, $FF, $FF, $FF, $40, $78, $6A, $6C, $6E
.db $FF, $FF, $FF, $FF, $40, $78, $70, $72, $74, $FF, $FF, $FF, $FF, $48, $50, $0A
.db $0C, $FF, $FF, $FF, $FF, $2A, $2C, $FF, $FF, $FF, $FF, $FF, $48, $50, $0E, $10
.db $FF, $FF, $FF, $FF, $2E, $30, $FF, $FF, $FF, $FF, $FF, $48, $60, $12, $14, $FF
.db $FF, $FF, $FF, $32, $34, $FF, $FF, $FF, $FF, $FF, $40, $48, $FF

_2905:					;credits text
.db      $14, $03, $AE, $9E, $7F, $5E, $2E			;SONIC
.db $FE, $15, $04, $AF, $4F, $3E				;THE
.db $FE, $13, $05, $4F, $3E, $2F, $4E, $3E, $4F, $9E, $4E	;HEDGEHOG
.db $FD, $3C, $00
.db $FE, $12, $0C, $7E, $1E, $AE, $AF, $3E, $9F			;MASTER
.db $FE, $13, $0D, $AE, $DE, $AE, $AF, $3E, $7E			;SYSTEM
.db $FE, $14, $0E, $BF, $3E, $9F, $AE, $5E, $9E, $7F		;VERSION
.db $FD, $3C, $00
.db $FC, $09
.db $FE, $14, $0B, $AE, $9E, $7F, $5E, $2E			;SONIC
.db $FE, $15, $0C, $AF, $4F, $3E				;THE
.db $FE, $13, $0D, $4F, $3E, $2F, $4E, $3E, $4F, $9E, $4E	;HEDGEHOG
.db $FD, $3C, $00
.db $FE, $12, $0F, $8E, $9F, $5E, $4E, $5E, $7F, $1E, $6F	;ORIGINAL
.db $FE, $13, $10, $2E, $4F, $1E, $9F, $1E, $2E, $AF, $3E, $9F	;CHARACTER
.db $FE, $14, $11, $2F, $3E, $AE, $5E, $4E, $7F			;DESIGN
.db $FD, $3C, $00
.db $FC, $04
.db $FE, $14, $10, $AB, $AE, $3E, $4E, $1E			;©SEGA
.db $FD, $B4, $00
.db $FC, $09
.db $FE, $14, $0E, $AE, $AF, $1E, $3F, $3F			;STAFF
.db $FD, $B4, $00
.db $FC, $09
.db $FE, $12, $0B, $4E, $1E, $7E, $3E				;GAME
.db $FE, $13, $0C, $8F, $9F, $9E, $4E, $9F, $1E, $7E		;PROGRAM
.db $FD, $3C, $00
.db $FE, $13, $0E, $AE, $4F, $5E, $7F, $9E, $1F, $BE		;SHINOBU
.db $FE, $14, $0F, $4F, $1E, $DE, $1E, $AE, $4F, $5E		;HAYASHI
.db $FD, $F0, $00
.db $FC, $09
.db $FE, $12, $0B, $4E, $9F, $1E, $8F, $4F, $5E, $2E		;GRAPHIC
.db $FE, $14, $0C, $2F, $3E, $AE, $5E, $4E, $7F			;DESIGN
.db $FD, $3C, $00
.db $FE, $13, $0E, $1E, $DE, $1E, $7F, $9E			;AYANO
.db $FE, $14, $0F, $6E, $9E, $AE, $4F, $5E, $9F, $9E		;KOSHIRO
.db $FD, $3C, $00
.db $FE, $13, $11, $AF, $1E, $CF, $3E, $3F, $BE, $7F, $5E	;TAKAFUNI
.db $FE, $14, $12, $DE, $BE, $7F, $9E, $BE, $3E			;YUNOUE
.db $FD, $F0, $00
.db $FC, $09
.db $FE, $12, $0B, $AE, $9E, $BE, $7F, $2F			;SOUND
.db $FE, $13, $0C, $8F, $9F, $9E, $2F, $BE, $2E, $3E		;PRODUCE
.db $FD, $3C, $00
.db $FE, $13, $0E, $7E, $1E, $AE, $1E, $AF, $9E			;MASATO
.db $FE, $14, $0F, $7F, $1E, $CF, $1E, $7E, $BE, $9F, $1E	;NAKAMURA
.db $FD, $F0, $00
.db $FC, $09
.db $FE, $12, $0B, $9F, $3E, $1E, $9F, $9F, $1E, $7F, $4E, $3E	;REARRANGE
.db $FE, $15, $0C, $1E, $7F, $2F				;AND
.db $FE, $12, $0D, $9E, $9F, $5E, $4E, $5E, $7F, $1E, $6F	;ORIGINAL
.db $FE, $16, $0E, $7E, $BE, $AE, $5E, $2E			;MUSIC
.db $FD, $3C, $00
.db $FE, $13, $10, $DE, $BE, $DF, $9E				;YUZO
.db $FE, $14, $11, $6E, $9E, $AE, $4F, $5E, $9F, $9E		;KOSHIRO
.db $FD, $F0, $00
.db $FC, $09
.db $FE, $13, $0D, $AE, $8F, $3E, $2E, $5E, $1E, $6F		;SPECIAL
.db $FE, $15, $0E, $AF, $4F, $1E, $7F, $6E, $AE			;THANKS
.db $FD, $B4, $00
.db $FC, $02
.db $FE, $13, $0E, $DE, $8E, $AE, $4F, $5E, $8E, $EB, $DE	;YOSHIRO Y
.db $FD, $3C, $00
.db $FE, $13, $11, $6F, $BE, $7F, $1E, $9F, $5E, $1E, $7F	;LUNARIAN
.db $FE, $1A, $12, $AE, $4E					;SG
.db $FD, $B4, $00
.db $FC, $09
.db $FE, $12, $0C, $8F, $9F, $3E, $AE, $3E, $7F, $AF, $3E, $2F	;PRESENTED
.db $FE, $16, $0E, $1F, $DE					;BY
.db $FE, $15, $10, $AE, $3E, $4E, $1E				;SEGA
.db $FD, $B4, $00
.db $FE, $19, $13, $3E, $7F, $2F				;END
.db $FF

_2ad6:					;credits screen palette
.db $35, $3D, $1F, $39, $06, $1B, $01, $34, $2B, $10, $03, $14, $2A, $1F, $00, $3F
.db $35, $3D, $1F, $39, $06, $1B, $01, $34, $2B, $10, $03, $14, $2A, $1F, $00, $3F

;____________________________________________________________________________[$2AF6]___

_2af6:					;object table?
.dw _48c8				;#00: Sonic
.dw _5b09				;#01: monitor - ring
.dw _5bd9				;#02: monitor - speed shoes
.dw _5c05				;#03: monitor - life
.dw _5cd7				;#04: monitor - shield
.dw _5cff				;#05: monitor - invincibility
.dw _5ea2				;#06: chaos emerald
.dw _5f17				;#07: end sign
.dw _65ee				;#08: badnick - crabmeat
.dw _673c				;#09: wooden platform - swinging (Green Hill)
.dw _693f				;#0A: UNKNOWN
.dw _69e9				;#0B: wooden platform (Green Hill)
.dw _6a47				;#0C: wooden platform - falling (Green Hill)
.dw _6ac1				;#0D: UNKNOWN
.dw _6b74				;#0E: badnick - buzz bomber
.dw _6d65				;#0F: wooden platform - moving (Green Hill)
.dw _6e0c				;#10: badnick - motobug
.dw _6f08				;#11: badnick - newtron
.dw _700c				;#12: boss (Green Hill)
.db $75, $9B				;#13: UNKNOWN
.db $E8, $9B				;#14: UNKNOWN
.db $70, $9C				;#15: UNKNOWN
.db $8E, $9C				;#16: flame thrower (Scrap Brain)
.db $FA, $9D				;#17: door - one way left (Scrap Brain)
.db $62, $9F				;#18: door - one way right (Scrap Brain)
.db $25, $A0				;#19: door (Scrap Brain)
.db $E8, $A0				;#1A: electric sphere (Scrap Brain)
.db $AA, $A1				;#1B: badnick - ball hog (Scrap Brain)
.db $3C, $A3				;#1C: UNKNOWN (ball from ball hog?)
.db $F8, $A3				;#1D: switch
.db $AB, $A4				;#1E: switch door
.db $51, $A5				;#1F: badnick - caterkiller
.db $F8, $96				;#20: UNKNOWN
.db $FB, $9A				;#21: moving bumber (Scrap Brain)
.db $ED, $A7				;#22: boss (Scrap Brain)
.dw _7699				;#23: free animal - rabbit
.dw _7594				;#24: free animal - bird
.dw _732c				;#25: capsule
.dw _7cf6				;#26: badnick - chopper
.dw _7e02				;#27: log - vertical (Jungle)
.dw _7e9b				;#28: log - horizontal (Jungle)
.db $E6, $7E				;#29: log - floating (Jungle)
.db $A8, $96				;#2A: UNKNOWN
.db $18, $82				;#2B: UNKNOWN
.db $53, $80				;#2C: boss (Jungle)
.db $E6, $82				;#2D: badnick - yadrin (Bridge)
.db $C1, $83				;#2E: UNKNOWN
.db $A5, $94				;#2F: UNKNOWN
.db $C7, $A9				;#30: meta - clouds (Sky Base)
.db $6A, $AA				;#31: propeller (Sky Base)
.db $21, $AB				;#32: badnick - bomb (Sky Base)
.db $6C, $AD				;#33: canon (Sky Base)
.db $35, $AE				;#34: UNKNOWN
.db $88, $AE				;#35: badnick - unidos (Sky Base)
.db $F4, $B0				;#36: UNKNOWN
.db $6C, $B1				;#37: rotating turret (Sky Base)
.db $97, $B2				;#38: flying platform (Sky Base)
.db $98, $B3				;#39: moving spiked wall (Sky Base)
.db $6D, $B4				;#3A: fixed turret (Sky Base)
.db $0E, $B5				;#3B: flying platform - up/down (Sky Base)
.db $37, $88				;#3C: badnick - jaws (Labyrinth)
.db $FB, $88				;#3D: spike ball (Labyrinth)
.db $F6, $8A				;#3E: spear (Labyrinth)
.db $16, $8C				;#3F: fire ball head (Labyrinth)
.db $48, $8D				;#40: meta - water line position
.db $56, $8E				;#41: bubbles (Labyrinth)
.db $CA, $8E				;#42: UNKNOWN
.db $6C, $8F				;#43: UNKNOWN
.db $6D, $8F				;#44: badnick - burrobot
.db $C0, $90				;#45: platform - float up (Labyrinth)
.db $84, $BB				;#46: boss - electric beam (Sky Base)
.db $DF, $BC				;#47: UNKNOWN
.db $96, $84				;#48: boss (Bridge)
.db $67, $92				;#49: boss (Labyrinth)
.db $34, $B6				;#4A: boss (Sky Base)
.db $A7, $7A				;#4B: trip zone (Green Hill)
.db $66, $98				;#4C: Flipper (Special Stage)
.dw $0000				;#4D: RESET!
.db $6C, $86				;#4E: balance (Bridge)
.dw $0000				;#4F: RESET!
.db $ED, $7A				;#50: flower (Green Hill)
.db $2F, $5D				;#51: monitor - checkpoint
.db $80, $5D				;#52: monitor - continue
.db $F9, $BD				;#53: final animation
.db $4C, $BF				;#54: all emeralds animation
.db $95, $7B				;#55: "make sonic blink"

;____________________________________________________________________________[$2BA2]___

_2ba2:
.db $00, $01, $00, $02
.db $00, $01, $00, $02, $20, $00, $20, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $20, $00, $20, $01, $60, $00, $E0, $00, $10, $00, $10, $01
.db $20, $00, $E0, $00, $A0, $00, $A0, $01, $40, $00, $00, $01, $40, $00, $40, $01
.db $40, $00, $00, $01, $20, $00, $20, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $30, $00, $F0, $00, $00, $01, $00, $02, $00, $01, $C0, $01, $40, $00, $40, $01
.db $40, $00, $00, $01, $A0, $00, $A0, $01, $20, $00, $E0, $00, $10, $00, $10, $01
.db $10, $00, $D0, $00, $10, $00, $10, $01, $10, $00, $D0, $00, $C0, $00, $C0, $01
.db $80, $00, $40, $01, $20, $00, $20, $01, $20, $00, $E0, $00, $08, $00, $40, $01
.db $10, $00, $D0, $00, $40, $00, $08, $01, $10, $00, $D0, $00, $10, $00, $10, $01
.db $20, $00, $E0, $00, $20, $00, $20, $01, $30, $00, $CC, $00, $20, $00, $20, $01
.db $30, $00, $CC, $00, $20, $00, $20, $01, $30, $00, $CC, $00, $20, $00, $20, $01
.db $20, $00, $DA, $00, $30, $00, $30, $01, $30, $00, $F0, $00, $00, $01, $80, $01
.db $00, $01, $C0, $01, $10, $00, $10, $01, $10, $00, $D0, $00, $20, $00, $20, $01
.db $30, $00, $C8, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $20, $00, $20, $01, $80, $00, $40, $01, $10, $00, $10, $01
.db $80, $00, $F0, $00, $20, $00, $20, $01, $10, $00, $D0, $00, $20, $00, $20, $01
.db $10, $00, $D0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $10, $00, $10, $01
.db $60, $00, $00, $01, $28, $00, $28, $01, $00, $01, $C0, $01, $28, $00, $28, $01
.db $00, $01, $C0, $01, $10, $00, $10, $01, $10, $00, $D0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $10, $00, $10, $01, $10, $00, $D0, $00, $40, $00, $40, $01
.db $C0, $00, $80, $01, $10, $00, $10, $01, $10, $00, $D0, $00, $80, $00, $80, $01
.db $40, $00, $C0, $01, $20, $00, $20, $01, $20, $00, $E0, $00, $00, $08, $00, $08
.db $30, $00, $F0, $00, $10, $00, $10, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $00, $00, $00, $01, $00, $00, $C0, $00, $00, $02, $00, $03
.db $00, $02, $C0, $02, $10, $00, $10, $01, $10, $00, $D0, $00, $40, $00, $40, $01
.db $40, $00, $00, $01, $10, $00, $10, $01, $10, $00, $D0, $00, $40, $00, $40, $01
.db $20, $00, $E0, $00, $80, $00, $80, $01, $50, $00, $D0, $00, $10, $00, $10, $01
.db $10, $00, $D0, $00, $10, $00, $10, $01, $60, $00, $20, $01, $10, $00, $10, $01
.db $10, $00, $D0, $00, $60, $00, $60, $01, $60, $00, $20, $01, $10, $00, $10, $01
.db $10, $00, $D0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $00, $20, $00, $21
.db $20, $00, $E0, $00, $08, $00, $08, $01, $08, $00, $C8, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $28, $00, $28, $01, $28, $00, $E8, $00, $60, $00, $60, $01
.db $20, $00, $E0, $00, $00, $01, $00, $02, $00, $01, $C0, $01, $10, $00, $10, $01
.db $10, $00, $D0, $00, $10, $00, $10, $01, $00, $01, $C0, $01, $10, $00, $10, $01
.db $10, $00, $D0, $00, $10, $00, $10, $01, $10, $00, $D0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $38, $00, $28, $01
.db $30, $00, $F0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $10, $00, $10, $01
.db $10, $00, $D0, $00, $20, $00, $20, $01, $20, $00, $E0, $00, $20, $00, $20, $01
.db $20, $00, $E0, $00, $00, $01, $E0, $01, $C0, $00, $80, $01, $00, $01, $00, $02
.db $00, $01, $C0, $01, $00, $08, $00, $09, $00, $08, $C0, $08
_2e52:
.db $A6, $A8, $FF
_2e55:
.db $A0, $A2, $A4, $00, $FF

_2e5a:
	res     7,(iy+$07)
	
	ld      hl,_2e55
	ld      de,$d2be
	ld      bc,$0005
	ldir    
	
	ld      a,(S1_LIVES)
	cp      $09
	jr      c,_2e72
	ld      a,$09
_2e72:
	add     a,a
	add     a,$80
	ld      ($d2c1),a
	ld      c,$10
	ld      b,$ac
	ld      hl,($d23c)
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	bit     2,(iy+$05)
	call    nz,_2ee6
	bit     5,(iy+$07)
	call    nz,_2f1f
	ld      de,$0060
	ld      hl,$d267
	ld      a,(hl)
	inc     hl
	or      (hl)
	call    z,_311a
	inc     hl
	ld      de,$0088
	ld      a,(hl)
	inc     hl
	or      (hl)
	call    z,_311a
	inc     hl
	ld      de,$0060
	ld      a,(hl)
	inc     hl
	or      (hl)
	call    z,_311a
	inc     hl
	ld      de,$0070
	bit     6,(iy+$05)
	jr      z,_2ec3
	ld      de,$0080
_2ec3:
	ld      a,(hl)
	inc     hl
	or      (hl)
	call    z,_311a
	bit     0,(iy+$05)
	call    z,_2f66
	ld      hl,$0000
	ld      ($d267),hl
	ld      ($d269),hl
	ld      ($d26b),hl
	ld      ($d26d),hl
	call    _31e6
	call    _329b
	ret     

_2ee6:
	ld      a,(S1_RINGS)
	ld      c,a
	rrca    
	rrca    
	rrca    
	rrca    
	and     $0f
	add     a,a
	add     a,$80
	ld      ($d2be),a
	ld      a,c
	and     $0f
	add     a,a
	add     a,$80
	ld      ($d2bf),a
	ld      a,$ff
	ld      ($d2c0),a
	ld      c,$14
	ld      b,$00
	ld      hl,($d23c)
	ld      de,_2e52
	call    _LABEL_35CC_117
	ld      c,$28
	ld      b,$00
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ret     

_2f1f:
	ld      hl,$d2be
	ld      a,($d2ce)
	and     $0f
	add     a,a
	add     a,$80
	ld      (hl),a
	inc     hl
	ld      (hl),$b0
	inc     hl
	ld      a,($d2cf)
	ld      c,a
	srl     a
	srl     a
	srl     a
	srl     a
	add     a,a
	add     a,$80
	ld      (hl),a
	inc     hl
	ld      a,c
	and     $0f
	add     a,a
	add     a,$80
	ld      (hl),a
	inc     hl
	ld      (hl),$ff
	ld      c,$18
	ld      b,$10
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	jr      c,_2f59
	ld      c,$70
	ld      b,$38
_2f59:
	ld      hl,($d23c)
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      ($d23c),hl
	ret     

_2f66:
	bit     6,(iy+$07)
	ret     nz
	ld      hl,($d27b)
	ld      a,l
	or      h
	call    nz,_3140
	ld      hl,($d27d)
	ld      a,l
	or      h
	call    nz,_3122
	ld      hl,($d267)
	ld      de,($d25f)
	and     a
	sbc     hl,de
	call    nz,_315e
	ld      ($d25f),de
	ld      hl,($d269)
	ld      de,($d261)
	and     a
	sbc     hl,de
	call    nz,_315e
	ld      ($d261),de
	ld      hl,($d26b)
	ld      de,($d263)
	and     a
	sbc     hl,de
	call    nz,_315e
	ld      ($d263),de
	ld      hl,($d26d)
	ld      de,($d265)
	and     a
	sbc     hl,de
	call    nz,_315e
	ld      ($d265),de
	ld      bc,($d25f)
	ld      de,($d3fe)
	ld      hl,($d25a)
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,_2ffa
	ld      a,h
	and     a
	jr      nz,_2fd9
	ld      a,l
	cp      $09
	jr      c,_2fdc
_2fd9:
	ld      hl,$0008
_2fdc:
	bit     3,(iy+$05)
	jr      nz,_3033
	bit     5,(iy+$05)
	jr      z,_2feb
	ld      hl,$0001
_2feb:
	ex      de,hl
	ld      hl,($d25a)
	and     a
	sbc     hl,de
	jr      c,_3033
	ld      ($d25a),hl
	jp      _3033
_2ffa:
	ld      bc,($d261)
	ld      hl,($d25a)
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,_3033
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      a,h
	and     a
	jr      nz,_3017
	ld      a,l
	cp      $09
	jr      c,_301a
_3017:
	ld      hl,$0008
_301a:
	bit     3,(iy+$05)
	jr      nz,_3033
	bit     5,(iy+$05)
	jr      z,_3029
	ld      hl,$0001
_3029:
	ld      de,($d25a)
	add     hl,de
	jr      c,_3033
	ld      ($d25a),hl
_3033:
	ld      hl,($d25a)
	ld      de,(S1_LEVEL_CROPLEFT)
	and     a
	sbc     hl,de
	jr      nc,_3045
	ld      ($d25a),de
	jr      _3055
_3045:
	ld      hl,($d25a)
	ld      de,($d275)
	and     a
	sbc     hl,de
	jr      c,_3055
	ld      ($d25a),de
_3055:
	bit     6,(iy+$05)
	call    nz,_3164
	ld      bc,($d263)
	ld      de,($d401)
	ld      hl,($d25d)
	bit     6,(iy+$05)
	call    nz,_31cf
	bit     7,(iy+$05)
	call    nz,_31d3
	add     hl,bc
	bit     7,(iy+$05)
	call    z,_31db
	and     a
	sbc     hl,de
	jr      c,_30b9
	ld      c,$09
	ld      a,h
	and     a
	jr      nz,_3093
	bit     6,(iy+$05)
	call    nz,_311f
	ld      a,l
	cp      c
	jr      c,_3097
_3093:
	dec     c
	ld      l,c
	ld      h,$00
_3097:
	bit     7,(iy+$05)
	jr      z,_30aa
	srl     h
	rr      l
	bit     1,(iy+$08)
	jr      nz,_30aa
	ld      hl,$0000
_30aa:
	ex      de,hl
	ld      hl,($d25d)
	and     a
	sbc     hl,de
	jr      c,_30f9
	ld      ($d25d),hl
	jp      _30f9
_30b9:
	ld      bc,($d265)
	ld      hl,($d25d)
	add     hl,bc
	bit     7,(iy+$05)
	call    z,_31db
	and     a
	sbc     hl,de
	jr      nc,_30f9
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      c,$09
	ld      a,h
	and     a
	jr      nz,_30e5
	bit     6,(iy+$05)
	call    nz,_311f
	ld      a,l
	cp      c
	jr      c,_30e9
_30e5:
	dec     c
	ld      l,c
	ld      h,$00
_30e9:
	bit     4,(iy+$05)
	jr      nz,_30f9
	ld      de,($d25d)
	add     hl,de
	jr      c,_30f9
	ld      ($d25d),hl
_30f9:
	ld      hl,($d25d)
	ld      de,(S1_LEVEL_CROPTOP)
	and     a
	sbc     hl,de
	jr      nc,_3109
	ld      ($d25d),de
_3109:
	ld      hl,($d25d)
	ld      de,(S1_LEVEL_EXTENDHEIGHT)
	and     a
	sbc     hl,de
	jr      c,_3119
	ld      ($d25d),de
_3119:
	ret     

_311a:
	ld      (hl),d
	dec     hl
	ld      (hl),e
	inc     hl
	ret     

_311f:
	ld      c,$08
	ret     

_3122:
	ld      de,(S1_LEVEL_CROPTOP)
	and     a
	sbc     hl,de
	ret     z
	jr      c,_3136
	inc     de
	ld      (S1_LEVEL_CROPTOP),de
	ld      (S1_LEVEL_EXTENDHEIGHT),de
	ret     
_3136:
	dec     de
	ld      (S1_LEVEL_CROPTOP),de
	ld      (S1_LEVEL_EXTENDHEIGHT),de
	ret     

_3140:
	ld      de,(S1_LEVEL_CROPLEFT)
	and     a
	sbc     hl,de
	ret     z
	jr      c,_3154
	inc     de
	ld      (S1_LEVEL_CROPLEFT),de
	ld      ($d275),de
	ret     
_3154:
	dec     de
	ld      (S1_LEVEL_CROPLEFT),de
	ld      ($d275),de
	ret     

_315e:
	jr      c,_3162
	inc     de
	ret     
_3162:
	dec     de
	ret     

_3164:
	ld      hl,($d29d)
	ld      de,(S1_TIME)
	add     hl,de
	ld      bc,$0200
	ld      a,h
	and     a
	jp      p,_3179
	neg     
	ld      bc,$fe00
_3179:
	cp      $02
	jr      c,_317f
	ld      l,c
	ld      h,b
_317f:
	ld      ($d29d),hl
	ld      c,l
	ld      b,h
	ld      hl,($d25c)
	ld      a,($d25e)
	add     hl,bc
	ld      e,$00
	bit     7,b
	jr      z,_3193
	ld      e,$ff
_3193:
	adc     a,e
	ld      ($d25c),hl
	ld      ($d25e),a
	ld      hl,($d2a1)
	ld      a,($d2a3)
	add     hl,bc
	adc     a,e
	ld      ($d2a1),hl
	ld      ($d2a3),a
	ld      hl,($d2a2)
	bit     7,h
	jr      z,_31be
	ld      bc,$ffe0
	and     a
	sbc     hl,bc
	jr      nc,_31be
	ld      hl,$0002
	ld      (S1_TIME),hl
	ret     
_31be:
	ld      hl,($d2a2)
	ld      bc,$0020
	and     a
	sbc     hl,bc
	ret     c
	ld      hl,$fffe
	ld      (S1_TIME),hl
	ret     

_31cf:
	ld      bc,$0020
	ret     

_31d3:
	ld      bc,$0070
	ret     
	ld      bc,$0070
	ret     

_31db:
	bit     6,(iy+$05)
	ret     nz
	ld      bc,($d2b7)
	add     hl,bc
	ret     
_31e6:
	ld      a,($d223)
	and     $07
	ld      c,a
	ld      hl,$0068
	call    _LABEL_5FC_114
	ld      de,$d3fc			;current level's object list
	add     hl,de
	ex      de,hl
	ld      a,($d223)
	and     $07
	add     a,a
	add     a,a
	add     a,a
	ld      c,a
	ld      b,$00
	ld      hl,$d37c
	add     hl,bc
	ld      c,b
	ld      b,$04
_3209:
	ld      a,(de)
	cp      $56
	jp      nc,_328b
	push    de
	pop     ix
	exx     
	add     a,a
	ld      l,a
	ld      h,$00
	add     hl,hl
	add     hl,hl
	ld      de,_2ba2
	add     hl,de
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	ld      de,$d20e
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ld      hl,($d25a)
	xor     a
	sbc     hl,bc
	jr      nc,_323b
	ld      l,a
	ld      h,a
	xor     a
_323b:
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	sbc     hl,de
	jp      nc,_328a
	ld      hl,($d20e)
	ld      bc,($d25a)
	add     hl,bc
	xor     a
	sbc     hl,de
	jp      c,_328a
	ld      hl,($d25d)
	ld      bc,($d210)
	sbc     hl,bc
	jr      nc,_3262
	ld      l,a
	ld      h,a
	xor     a
_3262:
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	sbc     hl,de
	jp      nc,_328a
	ld      hl,($d212)
	ld      bc,($d25d)
	add     hl,bc
	xor     a
	sbc     hl,de
	jp      c,_328a
	exx     
	ld      (hl),e
	inc     hl
	ld      (hl),d
	inc     hl
	push    hl
	ld      hl,$001a
	add     hl,de
	ex      de,hl
	pop     hl
	djnz    _3209
	ret     
_328a:
	exx     
_328b:
	ld      (hl),c
	inc     hl
	ld      (hl),c
	inc     hl
	push    hl
	ld      hl,$001a
	add     hl,de
	ex      de,hl
	pop     hl
	dec     b
	jp      nz,_3209
	ret    

;____________________________________________________________________________[$392B]___
	
_329b:	;starting from $D37E, read 16-bit numbers until a non-zero one is found,
	 ;or 16 numbers have been read
	ld      hl,$d37e
	ld      b,$1f
	
-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	
	;is it greater than zero?
	ld      a,e
	or      d
	call    nz,+
	
	;keep reading memory until either something non-zero is found or we hit $D39D
	djnz    -
	
	;at this point, $D37E-$D39E is known to be empty
	
	ld      a,(iy+$0a)		;number of sprites?
	ld      hl,($d23c)
	push    af
	push    hl
	
	ld      hl,$d024
	ld      ($d23c),hl
	
	ld      de,$d3fc		;current level's object list
	call    +
	
	pop     hl
	pop     af
	ld      ($d23c),hl
	ld      (iy+$0a),a
	ret     
	
+	ld      a,(de)			;get object from the list
	cp      $ff			;ignore object #$FF
	ret     z
	
	push    bc
	push    hl
	
	push    de
	pop     ix
	
	add     a,a
	ld      e,a
	ld      d,$00
	
	ld      hl,_2af6		;object look up table
	add     hl,de
	
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	ld      de,$32e2
	push    de
	
	jp      (hl)			;run object code?
	
;--- this is probably data?
_32e2:
	ld      e,(ix+$07)
	ld      d,(ix+$08)
	ld      c,(ix+$09)
	ld      l,(ix+$01)
	ld      h,(ix+$02)
	ld      a,(ix+$03)
	add     hl,de
	adc     a,c
	ld      (ix+$01),l
	ld      (ix+$02),h
	ld      (ix+$03),a
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	ld      c,(ix+$0c)
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      a,(ix+$06)
	add     hl,de
	adc     a,c
	ld      (ix+$04),l
	ld      (ix+$05),h
	ld      (ix+$06),a
;---
_331c:
	bit     5,(ix+$18)
	jp      nz,_34e6
	ld      b,$00
	ld      d,b
	ld      e,(ix+$0e)
	srl     e
	bit     7,(ix+$08)
	jr      nz,_333a
	ld      c,(ix+$0d)
	ld      hl,$411e			;data?
	jp      _333f
_333a:
	ld      c,$00
	ld      hl,$4020			;data?
_333f:
	ld      ($d210),bc
	res     6,(ix+$18)
	push    de
	push    hl
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,(S1_LEVEL_SOLIDITY)
	add     a,a
	ld      c,a
	ld      b,d
	ld      hl,S1_SolidityPointers
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	add     hl,de
	ld      a,(hl)
	and     $3f
	ld      ($d214),a
	pop     hl
	pop     de
	and     $3f
	jp      z,_33f6
	ld      a,($d214)
	add     a,a
	ld      c,a
	ld      b,$00
	ld      d,b
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      a,(ix+$05)
	add     a,e
	and     $1f
	ld      e,a
	add     hl,de
	ld      a,(hl)
	cp      $80
	jp      z,_33f6
	ld      e,a
	and     a
	jp      p,_338d
	ld      d,$ff
_338d:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,($d210)
	add     hl,bc
	bit     7,(ix+$09)
	jr      nz,_33ab
	and     a
	jp      m,_33b5
	ld      a,l
	and     $1f
	cp      e
	jr      nc,_33b5
	jp      _33f6
_33ab:
	and     a
	jp      m,_33b5
	ld      a,l
	and     $1f
	cp      e
	jr      nc,_33f6
_33b5:
	set     6,(ix+$18)
	ld      a,l
	and     $e0
	ld      l,a
	add     hl,de
	and     a
	sbc     hl,bc
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,($d214)
	ld      e,a
	ld      d,$00
	ld      hl,$3fbf			;data?
	add     hl,de
	ld      c,(hl)
	ld      (ix+$07),d
	ld      (ix+$08),d
	ld      (ix+$09),d
	ld      a,d
	ld      b,d
	bit     7,c
	jr      z,_33e3
	dec     a
	dec     b
_33e3:
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	add     hl,bc
	adc     a,(ix+$0c)
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
_33f6:
	ld      b,$00
	ld      d,b
	bit     7,(ix+$0b)
	jr      nz,_340d
	ld      c,(ix+$0d)
	srl     c
	ld      e,(ix+$0e)
	ld      hl,$448a		;data?
	jp      _3417
_340d:
	ld      c,(ix+$0d)
	srl     c
	ld      e,$00
	ld      hl,$41ec		;data?
_3417:
	ld      ($d210),de
	res     7,(ix+$18)
	push    bc
	push    hl
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,(S1_LEVEL_SOLIDITY)
	add     a,a
	ld      c,a
	ld      b,d
	ld      hl,S1_SolidityPointers
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	add     hl,de
	ld      a,(hl)
	and     $3f
	ld      ($d214),a
	pop     hl
	pop     bc
	and     $3f
	jp      z,_34e6
	ld      a,($d214)
	add     a,a
	ld      e,a
	ld      d,$00
	ld      b,d
	add     hl,de
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      a,(ix+$02)
	add     a,c
	and     $1f
	ld      c,a
	add     hl,bc
	ld      a,(hl)
	cp      $80
	jp      z,_34e6
	ld      c,a
	and     a
	jp      p,_3465
	ld      b,$ff
_3465:
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,($d210)
	add     hl,de
	bit     7,(ix+$0c)
	jr      nz,_3493
	and     a
	jp      m,_34a9
	ld      a,l
	and     $1f
	exx     
	ld      hl,($d214)
	ld      h,$00
	ld      de,$3ff0		;data?
	add     hl,de
	add     a,(hl)
	exx     
	cp      c
	jr      c,_34e6
	set     7,(ix+$18)
	jp      _34a9
_3493:
	and     a
	jp      m,_34a9
	ld      a,l
	and     $1f
	exx     
	ld      hl,($d214)
	ld      h,$00
	ld      de,$3ff0		;data?
	add     hl,de
	add     a,(hl)
	exx     
	cp      c
	jr      nc,_34e6
_34a9:
	ld      a,l
	and     $e0
	ld      l,a
	add     hl,bc
	and     a
	sbc     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      a,($d214)
	ld      e,a
	ld      d,$00
	ld      hl,$3f90		;data?
	add     hl,de
	ld      c,(hl)
	ld      (ix+$0a),d
	ld      (ix+$0b),d
	ld      (ix+$0c),d
	ld      a,d
	ld      b,d
	bit     7,c
	jr      z,_34d3
	dec     a
	dec     b
_34d3:
	ld      l,(ix+$07)
	ld      h,(ix+$08)
	add     hl,bc
	adc     a,(ix+$09)
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),a
_34e6:
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,($d25d)
	and     a
	sbc     hl,bc
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,($d25a)
	and     a
	sbc     hl,bc
	ld      c,(ix+$0f)
	ld      b,(ix+$10)
	ld      a,c
	or      b
	call    nz,_LABEL_350F_95
	pop     hl
	pop     bc
	ret

_LABEL_350F_95:				;[$350F]
	ld   ($D214), hl
	push bc
	exx
	pop  bc
	exx
	ld   b, $00
	ld   c, $03
_LABEL_351A_101:
	exx
	ld   hl, ($D214)
	ld   a, (bc)
	exx
	cp   $FF
	ret  z
	ld   a, d
	cp   $FF
	jr   nz, _LABEL_3530_96
	ld   a, e
	cp   $F0
	jr   c, _LABEL_356C_97
	jp   _LABEL_3537_98
_LABEL_3530_96:				;[$3530]
	and  a
	jr   nz, _LABEL_356C_97
	ld   a, e
	cp   $C0
	ret  nc
_LABEL_3537_98:				;[$3537]
	ld   b, $06
_LABEL_3539_100:
	exx
	ld   a, h
	and  a
	jr   nz, _LABEL_3559_99
	ld   a, (bc)
	cp   $FE
	jr   nc, _LABEL_3559_99
	ld   de, ($D23C)
	ld   a, l
	ld   (de), a
	inc  e
	exx
	ld   a, e
	exx
	ld   (de), a
	inc  e
	ld   a, (bc)
	ld   (de), a
	inc  e
	ld   ($D23C), de
	inc  (iy+10)
_LABEL_3559_99:
	inc  bc
	ld   de, $0008
	add  hl, de
	exx
	djnz _LABEL_3539_100
	ld   a, c
	ex   de, hl
	ld   c, $10
	add  hl, bc
	ex   de, hl
	ld   c, a
	dec  c
	jr   nz, _LABEL_351A_101
	ret

_LABEL_356C_97:				;[$356C]
	exx
	ex   de, hl
	ld   hl, $0006
	add  hl, bc
	ld   c, l
	ld   b, h
	ex   de, hl
	exx
	ld   a, c
	ex   de, hl
	ld   c, $10
	add  hl, bc
	ex   de, hl
	ld   c, a
	dec  c
	jr   nz, _LABEL_351A_101
	ret

_3581:
	ld      hl,($d210)
	ld      bc,($d214)
	add     hl,bc
	ld      bc,($d25d)
	and     a
	sbc     hl,bc
	ex      de,hl
	ld      hl,($d20e)
	ld      bc,($d212)
	add     hl,bc
	ld      bc,($d25a)
	and     a
	sbc     hl,bc
	ld      c,a
	ld      a,h
	and     a
	ret     nz
	ld      a,d
	cp      $ff
	jr      nz,_35b0
	ld      a,e
	cp      $f0
	ret     c
	jp      _35b6
_35b0:
	and     a
	ret     nz
	ld      a,e
	cp      $c0
	ret     nc
_35b6:
	ld      h,c
	ld      bc,($d23c)
	ld      a,l
	ld      (bc),a
	inc     c
	ld      a,e
	ld      (bc),a
	inc     c
	ld      a,h
	ld      (bc),a
	inc     c
	ld      ($d23c),bc
	inc     (iy+$0a)
	ret     
_LABEL_35CC_117:			;[$35CC]
	ld   a, (de)
	cp   $FF
	ret  z
	cp   $FE
	jr   z, _LABEL_35DD_118
	ld   (hl), c
	inc  l
	ld   (hl), b
	inc  l
	ld   (hl), a
	inc  l
	inc  (iy+10)
_LABEL_35DD_118:
	inc  de
	ld   a, c
	add  a, $08
	ld   c, a
	jp   _LABEL_35CC_117

_35e5:
	bit     0,(iy+$05)
	ret     nz
_35ea:
	bit     0,(iy+$08)
	jp      nz,_36be
	ld      a,($d414)
	rrca    
	jp      c,_36be
	and     $02
	jp      nz,_36be

_35fd:
	bit     0,(iy+$09)
	ret     nz
_3602:
	bit     6,(iy+$06)
	ret     nz
_3607:
	bit     0,(iy+$08)
	ret     nz
_360c:
	bit     5,(iy+$06)
	jr      nz,_367e
	ld      a,(S1_RINGS)
	and     a
	jr      nz,_3644
_3618:
	set     0,(iy+$05)
	ld      hl,$d414
	set     7,(hl)
	ld      hl,$fffa
	xor     a
	ld      ($d406),a
	ld      ($d407),hl
	ld      a,$60
	ld      ($d287),a
	res     6,(iy+$06)
	res     5,(iy+$06)
	res     6,(iy+$06)
	res     0,(iy+$08)
	ld      a,$0a
	rst     $18
	ret     
_3644:
	xor     a
	ld      (S1_RINGS),a
	call    _7c7b
	jr      c,_367e
	push    ix
	push    hl
	pop     ix
	ld      (ix+$00),$55
	ld      (ix+$11),$06
	ld      (ix+$12),$00
	ld      hl,($d3fe)
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      hl,($d401)
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fc
	ld      (ix+$0c),$ff
	pop     ix
_367e:
	ld      hl,$d414
	ld      de,$fffc
	xor     a
	bit     4,(hl)
	jr      z,_368c
	ld      de,$fffe
_368c:
	ld      ($d406),a
	ld      ($d407),de
	bit     1,(hl)
	jr      z,_36a1
	ld      a,(hl)
	or      $12
	ld      (hl),a
	xor     a
	ld      de,$0002
	jr      _36a7
_36a1:
	res     1,(hl)
	xor     a
	ld      de,$fffe
_36a7:
	ld      ($d403),a
	ld      ($d404),de
	res     5,(iy+$06)
	set     6,(iy+$06)
	ld      (iy+$03),$ff
	ld      a,$11
	rst     $28
	ret     
_36be:
	ld      (ix+$00),$0a
	ld      a,($d20e)
	ld      e,a
	ld      d,$00
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,($d20f)
	ld      e,a
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      a,$01
	rst     $28
	ld      de,$0100
	ld      c,$00
	call    _39d8
	ret     

_36f9:
	ld      a,(S1_LEVEL_FLOORWIDTH)
	cp      $80
	jr      z,_370f
	cp      $40
	jr      z,_373b
	cp      $20
	jr      z,_3764
	cp      $10
	jr      z,_378a
	jp      _37b3
_370f:
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,de
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	and     $80
	ld      l,a
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      l,h
	ld      h,$00
	add     hl,de
	ld      de,$c000
	add     hl,de
	ret     
_373b:
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,de
	ld      a,l
	add     a,a
	rl      h
	and     $c0
	ld      l,a
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      l,h
	ld      h,$00
	add     hl,de
	ld      de,$c000
	add     hl,de
	ret     
_3764:
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,de
	ld      a,l
	and     $e0
	ld      l,a
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      l,h
	ld      h,$00
	add     hl,de
	ld      de,$c000
	add     hl,de
	ret     
_378a:
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,de
	ld      a,l
	srl     h
	rra     
	and     $f0
	ld      l,a
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      l,h
	ld      h,$00
	add     hl,de
	ld      de,$c000
	add     hl,de
	ret     
_37b3:
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,de
	ld      a,l
	rlca    
	rl      h
	rlca    
	rl      h
	rlca    
	rl      h
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	ld      a,l
	rlca    
	rl      h
	rlca    
	rl      h
	rlca    
	rl      h
	ld      l,h
	ld      h,$00
	ld      e,h
	add     hl,de
	ld      de,$c000
	add     hl,de
	ret     

_LABEL_37E0_41:				;[$37E0]
	ld   de, ($D28F)
	ld   hl, ($D291)
	and  a
	sbc  hl, de
	ret  z
	ld   hl, $3680
	ex   de, hl
	bit  0, (iy+6)
	jp   nz, _LABEL_382E_42
	ld   a, e
	out  (SMS_VDP_CONTROL), a
	ld   a, d
	or   $40
	out  (SMS_VDP_CONTROL), a
	xor  a
	ld   c, $BE
	ld   e, $18
_LABEL_3803_43:
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	dec  e
	jp   nz, _LABEL_3803_43
	ld   hl, ($D28F)
	ld   ($D291), hl
	ret
_LABEL_382E_42:				;[$382E]
	ld   bc, $011D
	add  hl, bc
	ld   a, e
	out  (SMS_VDP_CONTROL), a
	ld   a, d
	or   $40
	out  (SMS_VDP_CONTROL), a
	exx
	push bc
	ld   b, $18
	exx
	ld   de, $FFFA
	ld   c, $BE
	xor  a
_LABEL_3845_44:
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	add  hl, de
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	add  hl, de
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	add  hl, de
	outi
	outi
	outi
	out  (SMS_VDP_DATA), a
	add  hl, de
	exx
	dec  b
	exx
	jp   nz, _LABEL_3845_44
	exx
	pop  bc
	exx
	ld   hl, ($D28F)
	ld   ($D291), hl
	ret
_3879:
	ld      de,($d293)
	ld      hl,($d295)
	and     a
	sbc     hl,de
	ret     z
	ld      hl,$1f80
	ex      de,hl
	di      
	ld      a,e
	out     (SMS_VDP_CONTROL),a
	ld      a,d
	or      $40
	out     (SMS_VDP_CONTROL),a
	ld      b,$20
_3893:
	ld      a,(hl)
	out     (SMS_VDP_DATA),a
	nop     
	inc     hl
	ld      a,(hl)
	out     (SMS_VDP_DATA),a
	nop     
	inc     hl
	ld      a,(hl)
	out     (SMS_VDP_DATA),a
	nop     
	inc     hl
	ld      a,(hl)
	out     (SMS_VDP_DATA),a
	inc     hl
	djnz    _3893
	ei      
	ld      hl,($d293)
	ld      ($d295),hl
	ret     

;____________________________________________________________________________[$38B0]___

_LABEL_38B0_51:
	ld   hl, ($D2AB)
	ld   a, l
	and  %11111000
	ld   l, a
	
	ld   de, ($D25A)
	ld   a, e
	and  %11111000
	ld   e, a
	
	xor  a
	sbc  hl, de			;is DE > HL?
	ret  c
	
	or   h				;is H > 0?
	ret  nz
	
	ld   a, l
	cp   $08			;is L < 8?
	ret  c
	
	ld   d, a
	ld   a, ($D251)
	and  %11111000
	ld   e, a
	add  hl, de
	srl  h
	rr   l
	srl  h
	rr   l
	srl  h
	rr   l
	ld   a, l
	and  $1F
	add  a, a
	ld   c, a
	ld   hl, ($D2AD)
	ld   a, l
	and  $F8
	ld   l, a
	ld   de, ($D25D)
	ld   a, e
	and  $F8
	ld   e, a
	xor  a
	sbc  hl, de
	ret  c
	or   h
	ret  nz
	ld   a, l
	cp   $C0
	ret  nc
	ld   d, $00
	ld   a, ($D252)
	and  $F8
	ld   e, a
	add  hl, de
	srl  h
	rr   l
	srl  h
	rr   l
	srl  h
	rr   l
	ld   a, l
	cp   $1C
	jr   c, _LABEL_3917_52
	sub  $1C
_LABEL_3917_52:
	ld   l, a
	ld   h, $00
	ld   b, h
	rrca
	rrca
	ld   h, a
	and  $C0
	ld   l, a
	ld   a, h
	xor  l
	ld   h, a
	add  hl, bc
	ld   bc, $3800
	add  hl, bc
	ld   de, ($D2AF)
	ld   b, $02

-	ld   a, l
	out  (SMS_VDP_CONTROL), a
	ld   a, h
	or   $40
	out  (SMS_VDP_CONTROL), a
	ld   a, (de)
	out  (SMS_VDP_DATA), a
	inc  de
	nop
	nop
	ld   a, (de)
	out  (SMS_VDP_DATA), a
	inc  de
	nop
	nop
	ld   a, (de)
	out  (SMS_VDP_DATA), a
	inc  de
	nop
	nop
	ld   a, (de)
	out  (SMS_VDP_DATA), a
	inc  de
	ld   a, b
	ld   bc, $0040
	add  hl, bc
	ld   b, a
	djnz -
	
	ret

;____________________________________________________________________________[$3956]___

_LABEL_3956_11:
	bit  0, (iy+5)
	scf
	ret  nz
	ld   l, (ix+2)
	ld   h, (ix+3)
	ld   c, (ix+13)
	ld   b, $00
	add  hl, bc
	ld   de, ($D3FE)
	xor  a
	sbc  hl, de
	ret  c
	ld   l, (ix+2)
	ld   h, (ix+3)
	ld   a, ($D214)
	ld   c, a
	add  hl, bc
	ex   de, hl
	ld   a, ($D409)
	ld   c, a
	add  hl, bc
	xor  a
	sbc  hl, de
	ret  c
	ld   l, (ix+5)
	ld   h, (ix+6)
	ld   c, (ix+14)
	add  hl, bc
	ld   de, ($D401)
	xor  a
	sbc  hl, de
	ret  c
	ld   l, (ix+5)
	ld   h, (ix+6)
	ld   a, ($D215)
	ld   c, a
	add  hl, bc
	ex   de, hl
	ld   a, ($D40A)
	ld   c, a
	add  hl, bc
	xor  a
	sbc  hl, de
	ret
_39ac:
	ld      c,a
	ld      a,(S1_RINGS)
	add     a,c
	ld      c,a
	and     $0f
	cp      $0a
	jr      c,_39bc
	ld      a,c
	add     a,$06
	ld      c,a
_39bc:
	ld      a,c
	cp      $a0
	jr      c,_39d1
	sub     $a0
	ld      (S1_RINGS),a
	ld      a,(S1_LIVES)
	inc     a
	ld      (S1_LIVES),a
	ld      a,$09
	rst     $28
	ret     
_39d1:
	ld      (S1_RINGS),a
	ld      a,$02
	rst     $28
	ret     
_39d8:
	ld      hl,$d2bd
	ld      a,e
	add     a,(hl)
	daa     
	ld      (hl),a
	dec     hl
	ld      a,d
	adc     a,(hl)
	daa     
	ld      (hl),a
	dec     hl
	ld      a,c
	adc     a,(hl)
	daa     
	ld      (hl),a
	ld      c,a
	dec     hl
	ld      a,$00
	adc     a,(hl)
	daa     
	ld      (hl),a
	ld      hl,$d2fd
	ld      a,c
	cp      (hl)
	ret     c
	
	ld      a,$05
	add     a,(hl)
	daa     
	ld      (hl),a
	ld      hl,S1_LIVES
	inc     (hl)
	ld      a,$09
	rst     $28
	ret     

_3a03:
	bit     0,(iy+$05)
	ret     nz	
	ld      hl,$d2d0
	bit     0,(iy+$07)
	jr      nz,_3a37
	ld      a,(hl)
	inc     a
	cp      $3c
	jr      c,_3a18
	xor     a
_3a18:
	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	adc     a,$00
	daa     
	cp      $60
	jr      c,_3a24
	xor     a
_3a24:
	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	adc     a,$00
	daa     
	cp      $10
	jr      c,_3a35
	push    hl
	call    _3618
	pop     hl
	xor     a
_3a35:
	ld      (hl),a
	ret     
_3a37:
	ld      a,(hl)
	inc     a
	cp      $3c
	jr      c,_3a3e
	xor     a
_3a3e:
	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	sbc     a,$00
	daa     
	cp      $60
	jr      c,_3a4b
	ld      a,$59
_3a4b:
	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	sbc     a,$00
	daa     
	cp      $60
	jr      c,_3a60
	ld      a,$01
	ld      ($d289),a
	set     2,(iy+$09)
	xor     a
_3a60:
	ld      (hl),a
	ret     

_3a62:
.db $01, $30, $00

;solidity pointer table
S1_SolidityPointers:			;[$3A65]
.dw S1_SolidityData_0, S1_SolidityData_1, S1_SolidityData_2, S1_SolidityData_3
.dw S1_SolidityData_4, S1_SolidityData_5, S1_SolidityData_6, S1_SolidityData_7

;solidity data
S1_SolidityData_0:			;[$3A75] Green Hill
.db $00, $16, $10, $10, $10, $00, $00, $08, $09, $0A, $05, $06, $07, $03, $04, $01
.db $02, $10, $00, $00, $00, $10, $10, $00, $00, $00, $10, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $10, $00, $00, $00, $00, $00, $00, $00, $10, $10, $0C
.db $0D, $0E, $0F, $0B, $10, $10, $10, $10, $00, $10, $10, $10, $00, $10, $10, $10
.db $10, $10, $10, $10, $10, $16, $16, $12, $10, $15, $00, $00, $10, $16, $1E, $16
.db $11, $10, $00, $10, $10, $1E, $1E, $1E, $10, $1E, $00, $00, $16, $1E, $16, $1E
.db $00, $27, $1E, $00, $27, $27, $27, $27, $27, $16, $27, $27, $00, $00, $00, $00
.db $00, $00, $00, $14, $00, $00, $05, $0A, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $80, $80, $90, $80, $96, $90, $80, $90, $80, $80, $80, $A7, $A7, $A7, $A7, $A7
.db $A7, $A7, $A7, $A7, $A7, $00, $00, $00, $00, $90, $9E, $80, $80, $80, $80, $80
.db $90, $00, $00, $00, $00, $00, $00, $00
S1_SolidityData_1:			;[$3B2D] Bridge
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $13, $10, $12, $12, $13, $00, $00, $00, $00, $00, $00, $10, $10, $00, $00, $00
.db $12, $13, $10, $13, $12, $00, $00, $00, $07, $2B, $00, $00, $08, $00, $09, $06
.db $05, $29, $10, $2A, $0A, $00, $00, $00, $10, $10, $2E, $00, $2D, $00, $00, $00
.db $00, $00, $80, $80, $80, $00, $80, $80, $80, $80, $00, $00, $80, $00, $00, $80
.db $2C, $27, $10, $00, $00, $00, $80, $80, $10, $16, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $12, $10, $13, $00, $00, $10, $00, $00, $00, $00, $00, $00, $00, $00
.db $13, $16, $16, $12, $00, $00, $00, $00, $10, $2D, $2E, $00, $00, $00, $00, $00
S1_SolidityData_2:			;[$3BBD] Jungle
.db $00, $10, $00, $00, $00, $00, $00, $00, $10, $10, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $10, $10, $10, $10, $10, $10, $10, $16, $16, $16, $16, $27, $16
.db $1E, $10, $10, $00, $00, $00, $00, $00, $00, $10, $00, $00, $10, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $27, $00, $00, $10
.db $11, $00, $01, $00, $00, $10, $10, $00, $04, $01, $02, $03, $06, $07, $05, $08
.db $09, $0A, $10, $0E, $0F, $05, $0A, $04, $01, $10, $10, $17, $00, $0B, $05, $14
.db $0A, $00, $10, $27, $10, $00, $00, $00, $10, $1E, $00, $10, $10, $00, $00, $10
.db $10, $10, $00, $00, $00, $1E, $00, $27, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $80, $80, $80, $80, $80, $A7, $80, $27, $A7, $A7, $A7, $A7, $A7, $A7, $A7
.db $A7, $A7, $80, $80, $10, $10, $96, $96, $16, $16, $16, $16, $00, $00, $00, $00
S1_SolidityData_3:			;[$35CD] Labyrinth
.db $00, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16
.db $16, $16, $16, $16, $16, $16, $16, $16, $00, $00, $00, $00, $00, $00, $80, $27
.db $00, $00, $00, $00, $00, $00, $80, $27, $00, $00, $00, $00, $00, $27, $A7, $16
.db $00, $00, $1E, $27, $00, $1E, $00, $27, $00, $27, $00, $16, $27, $27, $9E, $80
.db $1E, $1E, $1E, $16, $16, $16, $16, $16, $27, $1E, $1E, $16, $16, $16, $16, $16
.db $06, $07, $00, $00, $08, $09, $02, $01, $12, $05, $14, $15, $0A, $13, $04, $03
.db $04, $00, $04, $03, $08, $09, $06, $07, $03, $01, $02, $01, $0A, $06, $09, $05
.db $00, $00, $04, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $16, $16, $10, $16, $16, $16, $16, $16, $00, $27, $16, $16, $16, $16, $00
.db $1E, $00, $27, $1E, $00, $1E, $00, $00, $01, $04, $01, $04, $09, $06, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $A8, $00, $00, $00, $00, $00, $00, $00
S1_SolidityData_4:			;[$3D0D] Scrap Brain
.db $00, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $1E, $1E, $1E, $1A
.db $1B, $1C, $1D, $1F, $20, $21, $22, $23, $24, $1B, $1C, $16, $1E, $1E, $1E, $1E
.db $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $27
.db $27, $27, $04, $03, $02, $01, $08, $09, $0A, $05, $06, $07, $0A, $05, $03, $02
.db $15, $14, $16, $16, $13, $12, $10, $10, $10, $10, $10, $10, $10, $10, $16, $27
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $1E, $00, $1E, $1E, $1E, $00, $00, $10, $80, $80, $27, $27, $27
.db $16, $16, $27, $27, $27, $1E, $1E, $16, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $02, $03, $90, $80, $9E, $16, $16, $02, $03, $1B, $1C, $16, $16, $19, $18
.db $25, $26, $00, $00, $00, $27, $27, $1E, $1E, $27, $1E, $00, $00, $00, $00, $1E
.db $27, $1E, $27, $9E, $9E, $16, $16, $00, $00, $1E, $16, $1E, $1E, $90, $90, $90
.db $16, $16, $16, $16, $00, $00, $00, $00, $A7, $9E, $00
S1_SolidityData_5:			;[$3DC8] Sky Base 1 & 2 (exterior)
.db $00, $10, $16, $16, $10, $10, $10, $10, $10, $00, $00, $16, $16, $1E, $00, $00
.db $00, $00, $10, $10, $10, $00, $90, $80, $1E, $00, $00, $00, $10, $10, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $03, $04, $00, $00, $08, $09, $0A, $16, $13
.db $15, $02, $01, $00, $07, $06, $05, $16, $14, $12, $0A, $05, $10, $10, $00, $00
.db $03, $02, $10, $00, $00, $10, $00, $00, $00, $00, $00, $00, $00, $00, $10, $10
.db $10, $00, $00, $10, $00, $10, $00, $00, $00, $10, $10, $10, $10, $16, $16, $04
.db $03, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $10, $10, $16, $00, $10, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $16, $00, $00, $00, $00, $00, $00, $00, $00, $10, $00, $00, $00, $00, $00, $00
.db $00, $1E, $00, $00, $00, $1E, $1E, $10, $00, $00, $10, $10, $1E, $1E, $16, $16
.db $1E, $1E, $1E, $1E, $1E, $00, $10, $1E, $1E, $10, $10, $1E, $00, $02, $0A, $16
.db $00, $00, $00, $00, $00, $00, $10, $1E, $16, $1E, $00, $10, $10, $10, $10, $10
.db $1E, $00, $10, $00, $00, $10, $10, $10, $10, $1E, $90, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $9E, $1E, $00, $00, $00, $00, $00, $00, $00, $00, $00
S1_SolidityData_6:			;[$3EA8] Special Stage
.db $00, $27, $27, $27, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $1E, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $27, $00, $00, $00, $00, $00, $27, $27, $16, $00, $00, $00
.db $27, $1E, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
S1_SolidityData_7:			;[$3F28] Sky Base 2 & 3 (interior)
.db $00, $27, $27, $16, $1E, $1E, $16, $27, $27, $1E, $1E, $00, $00, $16, $27, $27
.db $16, $1E, $1E, $16, $16, $16, $16, $01, $02, $04, $03, $1D, $1C, $1A, $1B, $01
.db $02, $04, $03, $1D, $1C, $1A, $1B, $00, $00, $00, $00, $00, $00, $00, $16, $9E
.db $9E, $80, $1E, $27, $A7, $A7, $80, $80, $16, $16, $80, $1E, $1E, $27, $27, $27
.db $16, $1E, $16, $16, $16, $16, $16, $16, $27, $00, $1E, $00, $00, $00, $00, $00
.db $00, $00, $16, $16, $16, $16, $16, $16, $16, $16, $A7, $A7, $9E, $9E, $16, $00
.db $9E, $A7, $80, $9E, $A7, $80, $00, $00, $00, $1C, $1C, $E4, $E4, $12, $12, $12
.db $EE, $EE, $EE, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $12, $EE, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $08, $08, $08, $08, $06, $06, $06
.db $06, $06, $06, $03, $03, $03, $03, $03

;======================================================================================

.BANK 1 SLOT 1
.ORGA $4000

.db $03, $08, $03, $03, $03, $03, $03, $03, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00, $00, $00, $03, $03, $04, $04, $03, $03, $03, $03, $00
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $9E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $BE, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $DE, $40
.db $FE, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $1C, $1C
.db $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C
.db $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C
.db $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $1C, $1C
.db $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $80, $80
.db $80, $80, $80, $80, $80, $80, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C, $1C
.db $1C, $1C, $1C, $1C, $1C, $1C, $80, $80, $80, $80, $80, $80, $80, $80, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7C, $41, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $8C, $41, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $AC, $41, $CC, $41
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $04, $04, $04, $04
.db $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
.db $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $04, $04, $04, $04
.db $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $80, $80, $80, $80
.db $80, $80, $80, $80, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04
.db $04, $04, $04, $04, $80, $80, $80, $80, $80, $80, $80, $80, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $4A, $42, $7E, $40, $6A, $42, $8A, $42
.db $AA, $42, $CA, $42, $EA, $42, $0A, $43, $2A, $43, $4A, $43, $6A, $43, $8A, $43
.db $AA, $43, $CA, $43, $EA, $43, $0A, $44, $2A, $44, $4A, $44, $6A, $44, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $1F, $1F, $1F, $1F, $1F, $1F
.db $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F
.db $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $18, $18, $17, $17, $16, $16
.db $15, $15, $14, $14, $13, $13, $12, $12, $11, $11, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $11, $11, $12, $12, $13, $13
.db $14, $14, $15, $15, $16, $16, $17, $17, $18, $18, $0F, $0E, $0D, $0C, $0B, $0A
.db $09, $08, $07, $06, $05, $04, $03, $02, $01, $00, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $2F, $2E, $2D, $2C, $2B, $2A
.db $29, $28, $27, $26, $25, $24, $23, $22, $21, $20, $1F, $1E, $1D, $1C, $1B, $1A
.db $19, $18, $17, $16, $15, $14, $13, $12, $11, $10, $10, $11, $12, $13, $14, $15
.db $16, $17, $18, $19, $1A, $1B, $1C, $1D, $1E, $1F, $20, $21, $22, $23, $24, $25
.db $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $00, $01, $02, $03, $04, $05
.db $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F, $0F, $0F, $0F, $0F, $0F, $0F
.db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
.db $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $00, $00, $01, $01, $02, $02
.db $03, $03, $04, $04, $05, $05, $06, $06, $07, $07, $08, $08, $09, $09, $0A, $0A
.db $0B, $0B, $0C, $0C, $0D, $0D, $0E, $0E, $0F, $0F, $10, $10, $11, $11, $12, $12
.db $13, $13, $14, $14, $15, $15, $16, $16, $17, $17, $18, $18, $19, $19, $1A, $1A
.db $1B, $1B, $1C, $1C, $1D, $1D, $1E, $1E, $1F, $1F, $20, $20, $21, $21, $22, $22
.db $23, $23, $24, $24, $25, $25, $26, $26, $27, $27, $27, $27, $26, $26, $25, $25
.db $24, $24, $23, $23, $22, $22, $21, $21, $20, $20, $1F, $1F, $1E, $1E, $1D, $1D
.db $1C, $1C, $1B, $1B, $1A, $1A, $19, $19, $18, $18, $17, $17, $16, $16, $15, $15
.db $14, $14, $13, $13, $12, $12, $11, $11, $10, $10, $0F, $0F, $0E, $0E, $0D, $0D
.db $0C, $0C, $0B, $0B, $0A, $0A, $09, $09, $08, $08, $07, $07, $06, $06, $05, $05
.db $04, $04, $03, $03, $02, $02, $01, $01, $00, $00, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $08, $08, $09, $09, $0A, $0A
.db $0B, $0B, $0C, $0C, $0D, $0D, $0E, $0E, $0F, $0F, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $0F, $0F, $0E, $0E, $0D, $0D
.db $0C, $0C, $0B, $0B, $0A, $0A, $09, $09, $08, $08, $1F, $1F, $1F, $1F, $1F, $1F
.db $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F
.db $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $17, $17, $17, $17, $17, $17
.db $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17
.db $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $7E, $40, $E8, $44, $08, $45
.db $28, $45, $48, $45, $68, $45, $88, $45, $A8, $45, $C8, $45, $E8, $45, $08, $46
.db $28, $46, $48, $46, $68, $46, $88, $46, $A8, $46, $C8, $46, $E8, $46, $08, $47
.db $28, $47, $48, $47, $68, $47, $88, $47, $A8, $47, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40, $7E, $40
.db $7E, $40, $7E, $40, $7E, $40, $7E, $40, $C8, $47, $E8, $47, $08, $48, $28, $48
.db $48, $48, $68, $48, $88, $48, $A8, $48, $10, $11, $12, $13, $14, $15, $16, $17
.db $18, $19, $1A, $1B, $1C, $1D, $1E, $1F, $20, $21, $22, $23, $24, $25, $26, $27
.db $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $F0, $F1, $F2, $F3, $F4, $F5, $F6, $F7
.db $F8, $F9, $FA, $FB, $FC, $FD, $FE, $FF, $00, $01, $02, $03, $04, $05, $06, $07
.db $08, $09, $0A, $0B, $0C, $0D, $0E, $0F, $0F, $0E, $0D, $0C, $0B, $0A, $09, $08
.db $07, $06, $05, $04, $03, $02, $01, $00, $FF, $FE, $FD, $FC, $FB, $FA, $F9, $F8
.db $F7, $F6, $F5, $F4, $F3, $F2, $F1, $F0, $2F, $2E, $2D, $2C, $2B, $2A, $29, $28
.db $27, $26, $25, $24, $23, $22, $21, $20, $1F, $1E, $1D, $1C, $1B, $1A, $19, $18
.db $17, $16, $15, $14, $13, $12, $11, $10, $F8, $F8, $F9, $F9, $FA, $FA, $FB, $FB
.db $FC, $FC, $FD, $FD, $FE, $FE, $FF, $FF, $00, $00, $01, $01, $02, $02, $03, $03
.db $04, $04, $05, $05, $06, $06, $07, $07, $08, $08, $09, $09, $0A, $0A, $0B, $0B
.db $0C, $0C, $0D, $0D, $0E, $0E, $0F, $0F, $10, $10, $11, $11, $12, $12, $13, $13
.db $14, $14, $15, $15, $16, $16, $17, $17, $18, $18, $19, $19, $1A, $1A, $1B, $1B
.db $1C, $1C, $1D, $1D, $1E, $1E, $1F, $1F, $20, $20, $21, $21, $22, $22, $23, $23
.db $24, $24, $25, $25, $26, $26, $27, $27, $27, $27, $26, $26, $25, $25, $24, $24
.db $23, $23, $22, $22, $21, $21, $20, $20, $1F, $1F, $1E, $1E, $1D, $1D, $1C, $1C
.db $1B, $1B, $1A, $1A, $19, $19, $18, $18, $17, $17, $16, $16, $15, $15, $14, $14
.db $13, $13, $12, $12, $11, $11, $10, $10, $0F, $0F, $0E, $0E, $0D, $0D, $0C, $0C
.db $0B, $0B, $0A, $0A, $09, $09, $08, $08, $07, $07, $06, $06, $05, $05, $04, $04
.db $03, $03, $02, $02, $01, $01, $00, $00, $FF, $FF, $FE, $FE, $FD, $FD, $FC, $FC
.db $FB, $FB, $FA, $FA, $F9, $F9, $F8, $F8, $10, $10, $10, $10, $10, $10, $10, $11
.db $11, $11, $11, $11, $12, $12, $12, $12, $12, $12, $12, $12, $12, $11, $11, $11
.db $11, $11, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $11
.db $11, $11, $11, $11, $12, $12, $12, $12, $13, $13, $13, $14, $14, $15, $15, $15
.db $16, $16, $16, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $16, $16, $16
.db $15, $15, $15, $14, $14, $13, $13, $13, $12, $12, $12, $12, $11, $11, $11, $11
.db $11, $10, $10, $10, $10, $10, $10, $10, $08, $08, $08, $08, $08, $08, $08, $09
.db $09, $09, $09, $09, $0A, $0A, $0A, $0A, $0B, $0B, $0B, $0C, $0C, $0D, $0D, $0D
.db $0E, $0E, $0E, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0E, $0E, $0E
.db $0D, $0D, $0D, $0C, $0C, $0B, $0B, $0B, $0A, $0A, $0A, $0A, $09, $09, $09, $09
.db $09, $08, $08, $08, $08, $08, $08, $08, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $11, $12, $13, $14, $15, $16, $17
.db $18, $19, $19, $1A, $1A, $1A, $1B, $1B, $1B, $1B, $1B, $1A, $1A, $1A, $19, $19
.db $18, $17, $16, $14, $11, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $11, $11, $12, $12, $13, $13, $14, $14
.db $15, $15, $16, $16, $17, $17, $18, $18, $18, $18, $17, $17, $16, $16, $15, $15
.db $14, $14, $13, $13, $12, $12, $11, $11, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $08, $08, $09, $09, $0A, $0A, $0B, $0B
.db $0C, $0C, $0D, $0D, $0E, $0E, $0F, $0F, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $0F, $0F, $0E, $0E, $0D, $0D, $0C, $0C
.db $0B, $0B, $0A, $0A, $09, $09, $08, $08, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $08, $08, $08, $08, $09, $09, $09, $09
.db $0A, $0A, $0A, $0A, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0A, $0A, $0A, $0A
.db $09, $09, $09, $09, $08, $08, $08, $08, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $08, $08, $08, $08, $08, $08, $08, $08
.db $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08
.db $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $09, $09, $09, $09
.db $0A, $0A, $0A, $0A, $0B, $0B, $0B, $0B, $0C, $0C, $0C, $0C, $0D, $0D, $0D, $0D
.db $0E, $0E, $0E, $0E, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0E, $0E, $0E, $0E
.db $0D, $0D, $0D, $0D, $0C, $0C, $0C, $0C, $0B, $0B, $0B, $0B, $0A, $0A, $0A, $0A
.db $09, $09, $09, $09, $08, $08, $08, $08, $07, $07, $06, $06, $05, $05, $04, $04
.db $03, $03, $02, $02, $01, $01, $00, $00, $00, $00, $01, $01, $02, $02, $03, $03
.db $04, $04, $05, $05, $06, $06, $07, $07, $08, $08, $08, $08, $09, $09, $09, $09
.db $0A, $0A, $0A, $0A, $0B, $0B, $0C, $0C, $0C, $0C, $0B, $0B, $0A, $0A, $0A, $0A
.db $09, $09, $09, $09, $08, $08, $08, $08, $80, $80, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10, $10
.db $10, $10, $10, $10, $10, $10, $10, $10, $80, $80, $80, $80, $80, $80, $80, $80
.db $80, $80, $80, $80, $80, $80, $80, $80

;____________________________________________________________________________[$48C8]___

;OBJECT - Sonic
_48c8:
	res     1,(iy+$08)
	bit     7,(ix+$18)
	call    nz,_4e88
	set     7,(iy+$07)
	bit     0,(iy+$05)
	jp      nz,_543c
	ld      a,($d412)
	and     a
	call    nz,_4ff0
	res     5,(ix+$18)
	bit     6,(iy+$06)
	call    nz,_510a
	ld      a,($d28c)
	and     a
	call    nz,_568f
	bit     0,(iy+$07)
	call    nz,_5100
	bit     0,(iy+$08)
	call    nz,_4ff5
	bit     4,(ix+$18)
	call    nz,_5009
	ld      a,($d28b)
	and     a
	call    nz,_5285
	ld      a,($d28a)
	and     a
	jp      nz,_5117
	bit     6,(iy+$08)
	jp      nz,_5193
	bit     7,(iy+$08)
	call    nz,_529c
	bit     4,(ix+$18)
	jp      z,_494f
	ld      hl,_4ddd
	ld      de,$d20e
	ld      bc,$0009
	ldir    
	ld      hl,$0100
	ld      ($d240),hl
	ld      hl,$fd80
	ld      ($d242),hl
	ld      hl,$0010
	ld      ($d244),hl
	jp      _49d9

_494f:
	ld      a,(ix+$15)
	and     a
	jr      nz,_49ad
	bit     0,(iy+$07)
	jr      nz,_4981
_495b:
	ld      hl,_4dcb
	ld      de,$d20e
	ld      bc,$0009
	ldir    
	ld      hl,$0300
	ld      ($d240),hl
	ld      hl,$fc80
	ld      ($d242),hl
	ld      hl,$0038
	ld      ($d244),hl
	ld      hl,($dc0c)
	ld      ($dc0a),hl
	jp      _49d9
_4981:
	bit     7,(ix+$18)
	jr      nz,_495b
	ld      hl,_4dd4
	ld      de,$d20e
	ld      bc,$0009
	ldir    
	ld      hl,$0c00
	ld      ($d240),hl
	ld      hl,$fc80
	ld      ($d242),hl
	ld      hl,$0038
	ld      ($d244),hl
	ld      hl,($dc0c)
	ld      ($dc0a),hl
	jp      _49d9

_49ad:
	ld      hl,_4de6
	ld      de,$d20e
	ld      bc,$0009
	ldir    
	ld      hl,$0600
	ld      ($d240),hl
	ld      hl,$fc80
	ld      ($d242),hl
	ld      hl,$0038
	ld      ($d244),hl
	ld      hl,($dc0c)
	inc     hl
	ld      ($dc0a),hl
	ld      a,($d223)
	and     $03
	call    z,_4fec
_49d9:
	bit     1,(iy+$03)
	call    z,_50c1
	bit     1,(iy+$03)
	call    nz,_50e3
	ld      a,15
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	ld      bc,$000c
	ld      de,$0010
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,(S1_LEVEL_SOLIDITY)
	add     a,a
	ld      l,a
	ld      h,d
	ld      bc,$b9ed
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	add     hl,de
	add     hl,bc
	ld      a,(hl)
	cp      $1c
	jr      nc,_4a28
	add     a,a
	ld      l,a
	ld      h,d
	ld      de,_58e5
	add     hl,de
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      de,$4a28		;data?
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (S1_PAGE_2),a
	push    de
	jp      (hl)
_4a28:
	ld      hl,($d401)
	ld      de,$0024
	add     hl,de
	ex      de,hl
	ld      hl,(S1_LEVEL_EXTENDHEIGHT)
	ld      bc,$00c0
	add     hl,bc
	xor     a
	sbc     hl,de
	call    c,_3618
	ld      hl,$0000
	ld      a,(iy+$03)
	cp      $ff
	jr      nz,_4a59
	ld      de,($d403)
	ld      a,e
	or      d
	jr      nz,_4a59
	ld      a,($d414)
	rlca    
	jr      nc,_4a59
	ld      hl,($d299)
	inc     hl
_4a59:
	ld      ($d299),hl
	bit     7,(iy+$06)
	call    nz,_50e8
	ld      (ix+$14),$05
	ld      hl,($d299)
	ld      de,$0168
	and     a
	sbc     hl,de
	call    nc,_5105
	ld      a,(iy+$03)
	cp      $fe
	call    z,_4edd
	bit     0,(iy+$03)
	call    nz,_4fd3
	bit     0,(ix+$18)
	jp      nz,_532e
	ld      a,(ix+$0e)
	cp      $20
	jr      z,_4a9a
	ld      hl,($d401)
	ld      de,$fff8
	add     hl,de
	ld      ($d401),hl
_4a9a:
	ld      (ix+$0d),$18
	ld      (ix+$0e),$20
	ld      hl,($d403)
	ld      b,(ix+$09)
	ld      c,$00
	ld      e,c
	ld      d,c
	bit     3,(iy+$03)
	jp      z,_4f01
	bit     2,(iy+$03)
	jp      z,_4f5c
	ld      a,h
	or      l
	or      b
	jr      z,_4b1b
	ld      (ix+$14),$01
	bit     7,b
	jr      nz,_4af7
	ld      de,($d212)
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
	ld      c,$ff
	push    hl
	push    de
	ld      de,($d240)
	xor     a
	sbc     hl,de
	pop     de
	pop     hl
	jr      c,_4b1b
	ld      de,($d20e)
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
	ld      c,$ff
	ld      a,($d216)
	ld      (ix+$14),a
	jp      _4b1b
_4af7:
	ld      de,($d212)
	ld      c,$00
	push    hl
	push    de
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      de,($d240)
	xor     a
	sbc     hl,de
	pop     de
	pop     hl
	jr      c,_4b1b
	ld      de,($d20e)
	ld      a,($d216)
	ld      (ix+$14),a
_4b1b:
	ld      a,b
	and     a
	jp      m,_4b38
	add     hl,de
	adc     a,c
	ld      c,a
	jp      p,_4b42
	ld      a,($d403)
	or      (ix+$08)
	or      (ix+$09)
	jr      z,_4b42
	ld      c,$00
	ld      l,c
	ld      h,c
	jp      _4b42
_4b38:
	add     hl,de
	adc     a,c
	ld      c,a
	jp      m,_4b42
	ld      c,$00
	ld      l,c
	ld      h,c
_4b42:
	ld      a,c
	ld      ($d403),hl
	ld      ($d405),a
_4b49:
	ld      hl,($d406)
	ld      b,(ix+$0c)
	ld      c,$00
	ld      e,c
	ld      d,c
	bit     7,(ix+$18)
	call    nz,_50af
	bit     0,(ix+$18)
	jp      nz,_5407
	ld      a,($d28e)
	and     a
	jr      nz,_4b79
	bit     7,(ix+$18)
	jr      z,_4b9d
	bit     3,(ix+$18)
	jr      nz,_4b79
	bit     5,(iy+$03)
	jr      z,_4b9d
_4b79:
	bit     5,(iy+$03)
	jr      nz,_4ba4
_4b7f:
	ld      a,($d28e)
	and     a
	call    z,_509d
	ld      hl,($d242)
	ld      b,$ff
	ld      c,$00
	ld      e,c
	ld      d,c
	ld      a,($d28e)
	dec     a
	ld      ($d28e),a
	set     2,(ix+$18)
	jp      _4bbe
_4b9d:
	res     3,(ix+$18)
	jp      _4ba8
_4ba4:
	set     3,(ix+$18)
_4ba8:
	xor     a
	ld      ($d28e),a
_4bac:
	bit     7,h
	jr      nz,_4bb8
	ld      a,($d215)
	cp      h
	jr      z,_4bbe
	jr      c,_4bbe
_4bb8:
	ld      de,($d244)
	ld      c,$00
_4bbe:
	bit     0,(iy+$06)
	jr      z,_4bd6
	push    hl
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	ld      a,c
	cpl     
	ld      hl,$0001
	add     hl,de
	ex      de,hl
	adc     a,$00
	ld      c,a
	pop     hl
_4bd6:
	add     hl,de
	ld      a,b
	adc     a,c
	ld      ($d406),hl
	ld      ($d408),a
	push    hl
	ld      a,e
	cpl     
	ld      l,a
	ld      a,d
	cpl     
	ld      h,a
	ld      a,c
	cpl     
	ld      de,$0001
	add     hl,de
	adc     a,$00
	ld      ($d2e6),hl
	ld      ($d2e8),a
	pop     hl
	bit     2,(ix+$18)
	call    nz,_5280
	ld      a,h
	and     a
	jp      p,_4c08
	ld      a,h
	cpl     
	ld      h,a
	ld      a,l
	cpl     
	ld      l,a
	inc     hl
_4c08:
	ld      de,$0100
	ex      de,hl
	and     a
	sbc     hl,de
	jr      nc,_4c28
	ld      a,($d414)
	and     $85
	jr      nz,_4c28
	bit     7,(ix+$0c)
	jr      z,_4c24
	ld      (ix+$14),$13
	jr      _4c28
_4c24:
	ld      (ix+$14),$01
_4c28:
	ld      bc,$000c
	ld      de,$0008
	call    _36f9
	ld      a,(hl)
	and     $7f
	cp      $79
	call    nc,_4def
_4c39:
	ld      a,($d28c)
	and     a
	call    nz,_51b3
	bit     6,(iy+$06)
	call    nz,_51bc
	bit     2,(iy+$08)
	call    nz,_51dd
	ld      a,($d410)
	cp      $0a
	call    z,_51f3
	ld      l,(ix+$14)
	ld      c,l
	ld      h,$00
	add     hl,hl
	ld      de,_5965
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      ($d40d),de
	ld      a,($d2df)
	sub     c
	call    nz,_521f
	ld      a,($d40f)
_4c72:
	ld      h,$00
	ld      l,a
	add     hl,de
	ld      a,(hl)
	and     a
	jp      p,_4c83
	inc     hl
	ld      a,(hl)
	ld      ($d40f),a
	jp      _4c72
_4c83:
	ld      d,a
	ld      bc,_c000
	bit     1,(ix+$18)
	jr      z,_4c90
	ld      bc,_7000
_4c90:
	bit     5,(iy+$06)
	call    nz,_5206
	ld      a,($d302)
	and     a
	call    nz,_4e48
	ld      a,d
	rrca    
	rrca    
	rrca    
	ld      e,a
	and     $e0
	ld      l,a
	ld      a,e
	and     $1f
	add     a,d
	ld      h,a
	add     hl,bc
	ld      ($d28f),hl
	ld      hl,_591d
	bit     0,(iy+$06)
	call    nz,_520f
	ld      a,($d410)
	cp      $13
	call    z,_5213
	ld      a,($d302)
	and     a
	call    nz,_4e4d
	ld      ($d40b),hl
	ld      c,$10
	ld      a,($d404)
	and     a
	jp      p,_4cd8
	neg     
	ld      c,$f0
_4cd8:
	cp      $10
	jr      c,_4ce0
	ld      a,c
	ld      ($d404),a
_4ce0:
	ld      c,$10
	ld      a,($d407)
	and     a
	jp      p,_4ced
	neg     
	ld      c,$f0
_4ced:
	cp      $10
	jr      c,_4cf5
	ld      a,c
	ld      ($d407),a
_4cf5:
	ld      de,($d401)
	ld      hl,$0010
	and     a
	sbc     hl,de
	jr      c,_4d05
	add     hl,de
	ld      ($d401),hl
_4d05:
	bit     7,(iy+$06)
	call    nz,_5224
	bit     0,(iy+$08)
	call    nz,_4e8d
	ld      a,($d2e1)
	and     a
	call    nz,_5231
	ld      a,($d321)
	and     a
	call    nz,_4e51
	bit     1,(iy+$06)
	jr      nz,_4d81
	ld      hl,(S1_LEVEL_CROPLEFT)
	ld      bc,$0008
	add     hl,bc
	ex      de,hl
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	jr      nc,_4d4f
	ld      ($d3fe),de
	ld      a,($d405)
	and     a
	jp      p,_4d81
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
	jp      _4d81
_4d4f:
	ld      hl,($d275)
	ld      de,$00f8
	add     hl,de
	ex      de,hl
	ld      hl,($d3fe)
	ld      c,$18
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,_4d81
	ex      de,hl
	scf     
	sbc     hl,bc
	ld      ($d3fe),hl
	ld      a,($d405)
	and     a
	jp      m,_4d81
	ld      hl,($d404)
	or      h
	or      l
	jr      z,_4d81
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
_4d81:
	ld      a,($d414)
	ld      ($d2b9),a
	ld      a,($d410)
	ld      ($d2df),a
	ld      d,$01
	ld      c,$30
	cp      $01
	jr      z,_4da1
	ld      d,$06
	ld      c,$50
	cp      $09
	jr      z,_4da1
	inc     (ix+$13)
	ret     
_4da1:
	ld      a,($d2e0)
	ld      b,a
	ld      hl,($d403)
	bit     7,h
	jr      z,_4db3
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
_4db3:
	srl     h
	rr      l
	ld      a,l
	add     a,b
	ld      ($d2e0),a
	ld      a,h
	adc     a,d
	adc     a,(ix+$13)
	ld      ($d40f),a
	cp      c
	ret     c
	sub     c
	ld      ($d40f),a
	ret     

_4dcb:
.db $10, $00, $30, $00, $08, $00, $00, $08, $02
_4dd4:
.db $10, $00, $30, $00, $02, $00, $00, $08, $02
_4ddd:
.db $04, $00, $0c, $00, $02, $00, $00, $02, $01
_4de6:
.db $10, $00, $30, $00, $08, $00, $00, $08, $02

_4def:
	ex      de,hl
	ld      hl,($d401)
	ld      bc,($d25d)
	and     a
	sbc     hl,bc
	ret     c
	ld      bc,$0010
	and     a
	sbc     hl,bc
	ret     c
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      a,(de)
	ld      c,a
	ld      a,l
	rrca    
	rrca    
	rrca    
	rrca    
	and     $01
	inc     a
	ld      b,a
	ld      a,c
	and     b
	ret     z
	ld      a,l
	and     $f0
	ld      l,a
	ld      ($d2ab),hl
	ld      ($d31d),hl
	ld      a,c
	xor     b
	ld      (de),a
	ld      hl,($d401)
	ld      bc,$0008
	add     hl,bc
	ld      a,l
	and     $e0
	add     a,$08
	ld      l,a
	ld      ($d2ad),hl
	ld      ($d31f),hl
	ld      a,$06
	ld      ($d321),a
	ld      hl,$595d
	ld      ($d2af),hl
	ld      a,$01
	call    _39ac
	ret     

_4e48:
	ld      d,a
	ld      bc,_7000
	ret     

_4e4d:
	ld      hl,$0000
	ret     

_4e51:
	dec     a
	ld      ($d321),a
	ld      hl,($d31d)
	ld      ($d20e),hl
	ld      hl,($d31f)
	ld      ($d210),hl
	ld      hl,$0000
	ld      ($d212),hl
	ld      hl,$fffe
	ld      ($d214),hl
	cp      $03
	jr      c,_4e82
	ld      a,$b2
	call    _3581
	ld      hl,$0008
	ld      ($d212),hl
	ld      hl,$0002
	ld      ($d214),hl
_4e82:
	ld      a,$5a
	call    _3581
	ret     

_4e88:
	set     1,(iy+$08)
	ret     

_4e8d:
	ld      hl,($d3fe)
	ld      ($d20e),hl
	ld      hl,($d401)
	ld      ($d210),hl
	ld      hl,$d2f3
	ld      a,($d223)
	rrca    
	rrca    
	jr      nc,_4ea6
	ld      hl,$d2f7
_4ea6:
	ld      de,$d212
	ldi     
	ldi     
	ldi     
	ldi     
	rrca    
	ld      a,$94
	jr      nc,_4eb8
	ld      a,$96
_4eb8:
	call    _3581
	ld      a,($d223)
	ld      c,a
	and     $07
	ret     nz
	ld      b,$02
	ld      hl,$d2f3
	bit     3,c
	jr      z,_4ece
	ld      hl,$d2f7
_4ece:
	push    hl
	call    _LABEL_625_57
	pop     hl
	and     $0f
	ld      (hl),a
	inc     hl
	ld      (hl),$00
	inc     hl
	djnz    _4ece
	ret     

_4edd:
	ld      hl,($d403)
	ld      a,h
	or      l
	ret     nz
	ld      a,($d414)
	rlca    
	ret     nc
	ld      (ix+$14),$0c
	ld      de,($d2b7)
	bit     7,d
	jr      nz,_4efb
	ld      hl,$002c
	and     a
	sbc     hl,de
	ret     c
_4efb:
	inc     de
	ld      ($d2b7),de
	ret     

_4f01:
	res     1,(ix+$18)
	bit     7,b
	jr      nz,_4f31
	ld      de,($d20e)
	ld      c,$00
	ld      (ix+$14),$01
	push    hl
	exx     
	pop     hl
	ld      de,($d240)
	xor     a
	sbc     hl,de
	exx     
	jp      c,_4b1b
	ld      b,a
	ld      e,a
	ld      d,a
	ld      c,a
	ld      hl,($d240)
	ld      a,($d216)
	ld      (ix+$14),a
	jp      _4b1b
_4f31:
	set     1,(ix+$18)
	ld      (ix+$14),$0a
	push    hl
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      de,$0100
	and     a
	sbc     hl,de
	pop     hl
	ld      de,($d210)
	ld      c,$00
	jp      nc,_4b1b
	res     1,(ix+$18)
	ld      (ix+$14),$01
	jp      _4b1b
_4f5c:
	set     1,(ix+$18)
	ld      a,l
	or      h
	jr      z,_4f68
	bit     7,b
	jr      z,_4fa6
_4f68:
	ld      de,($d20e)
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
	ld      c,$ff
	ld      (ix+$14),$01
	push    hl
	exx     
	pop     hl
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      de,($d240)
	xor     a
	sbc     hl,de
	exx     
	jp      c,_4b1b
	ld      e,a
	ld      d,a
	ld      c,a
	ld      hl,($d240)
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      b,$ff
	ld      a,($d216)
	ld      (ix+$14),a
	jp      _4b1b
_4fa6:
	res     1,(ix+$18)
	ld      (ix+$14),$0a
	ld      de,($d210)
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
	ld      c,$ff
	push    hl
	exx     
	pop     hl
	ld      bc,$0100
	and     a
	sbc     hl,bc
	exx     
	jp      nc,_4b1b
	set     1,(ix+$18)
	ld      (ix+$14),$01
	jp      _4b1b

_4fd3:
	bit     0,(ix+$18)
	ret     nz
	ld      hl,($d2b7)
	ld      a,h
	or      l
	ret     z
	bit     7,h
	jr      z,_4fe7
	inc     hl
	ld      ($d2b7),hl
	ret     

_4fe7:
	dec     hl
	ld      ($d2b7),hl
	ret     

_4fec:
	dec     (ix+$15)
	ret     

_4ff0:
	dec     a
	ld      ($d412),a
	ret     

_4ff5:
	ld      a,($d223)
	and     $03
	ret     nz
	ld      hl,$d28d
	dec     (hl)
	ret     nz
	res     0,(iy+$08)
	ld      a,($d2fc)
	rst     $18
	ret     

_5009:
	ld      a,(S1_LEVEL_SOLIDITY)
	cp      $03
	ret     nz
	ld      a,(S1_CURRENT_LEVEL)
	cp      $0b
	ret     z
	ld      hl,($d29b)
	inc     hl
	ld      ($d29b),hl
	ld      de,$0300
	and     a
	sbc     hl,de
	ret     c
	ld      a,$05
	sub     h
	jr      nc,_5051
	res     5,(iy+$06)
	res     6,(iy+$06)
	res     0,(iy+$08)
	set     3,(iy+$08)
	set     0,(iy+$05)
	ld      a,$c0
	ld      ($d287),a
	ld      a,$0a
	rst     $18
	call    _91eb
	call    _91eb
	call    _91eb
	call    _91eb
	xor     a
_5051:
	ld      e,a
	add     a,a
	add     a,$80
	ld      ($d2be),a
	ld      a,$ff
	ld      ($d2bf),a
	ld      d,$00
	ld      hl,_5097
	add     hl,de
	ld      a,($d223)
	and     (hl)
	jr      nz,_506c
	ld      a,$1a
	rst     $28
_506c:
	ld      a,($d223)
	rrca    
	ret     nc
	ld      hl,($d3fe)
	ld      de,($d25a)
	and     a
	sbc     hl,de
	ld      a,l
	add     a,$08
	ld      c,a
	ld      hl,($d401)
	ld      de,($d25d)
	and     a
	sbc     hl,de
	ld      a,l
	add     a,$ec
	ld      b,a
	ld      hl,$d03c
	ld      de,$d2be
	call    _LABEL_35CC_117
	ret     

_5097:
.db $01, $07, $0f, $1f, $3f, $7f

_509d:
	ld      a,$10
	ld      ($d28e),a
	ld      a,$00
	rst     $28
	ret     

_50a6:
	xor     a
	ld      ($d3fd),a
	ld      ($d3fe),de
	ret     

_50af:
	exx     
	ld      hl,($d401)
	ld      ($d2d9),hl
	exx     
	bit     2,(ix+$18)
	ret     z
	res     2,(ix+$18)
	ret     

_50c1:
	bit     2,(ix+$18)
	ret     nz
	bit     0,(ix+$18)
	ret     nz
	bit     7,(ix+$18)
	ret     z
	set     0,(ix+$18)
	ld      hl,($d403)
	ld      a,l
	or      h
	jr      z,_50de
	ld      a,$06
	rst     $28
_50de:
	set     2,(iy+$07)
	ret     

_50e3:
	res     2,(iy+$07)
	ret     

_50e8:
	ld      hl,($d2dc)
	ld      de,($d401)
	and     a
	sbc     hl,de
	jp      c,_55a8
	ld      hl,$0000
	ld      ($d29b),hl
	res     4,(ix+$18)
	ret     

_5100:
	set     2,(ix+$18)
	ret     

_5105:
	ld      (ix+$14),$0d
	ret     

_510a:
	ld      (iy+$03),$ff
	ld      a,($d414)
	and     $fa
	ld      ($d414),a
	ret     

_5117:
	dec     a
	ld      ($d28a),a
	jr      z,_5142
	cp      $14
	jr      c,_5137
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),a
	ld      ($d404),hl
	ld      ($d406),a
	ld      ($d407),hl
	ld      (ix+$14),$0f
	jp      _4c39
_5137:
	res     1,(ix+$18)
	ld      (ix+$14),$0e
	jp      _4c39
_5142:
	ld      hl,($d2d5)
	ld      b,(hl)
	inc     hl
	ld      c,(hl)
	inc     hl
	ld      a,(hl)
	and     a
	jr      z,_5163
	jp      m,_5159
	ld      ($d2d3),a
	set     4,(iy+$06)
	jr      _515d
_5159:
	set     2,(iy+$0d)
_515d:
	ld      a,$01
	ld      ($d289),a
	ret     

_5163:
	ld      a,b
	ld      h,$00
	ld      b,$05
_5168:
	add     a,a
	rl      h
	djnz    _5168
	ld      l,a
	ld      de,$0008
	add     hl,de
	ld      ($d3fe),hl
	ld      a,c
	ld      h,$00
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      l,a
	ld      ($d401),hl
	xor     a
	ld      ($d3fd),a
	ld      ($d400),a
	ret     

_5193:
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d406),hl
	ld      ($d408),a
	ld      (ix+$14),$16
	ld      a,($d40f)
	cp      $12
	jp      c,_4c39
	res     6,(iy+$08)
	set     2,(ix+$18)
	jp      _4c39

_51b3:
	dec     a
	ld      ($d28c),a
	ld      (ix+$14),$11
	ret     

_51bc:
	ld      (ix+$0d),$1c
	ld      (ix+$14),$10
	bit     7,(ix+$0c)
	ret     nz
	bit     7,(ix+$18)
	ret     z
	res     6,(iy+$06)
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
	ret     

_51dd:
	ld      a,($d414)
	and     $fa
	ld      ($d414),a
	ld      (ix+$14),$14
	ld      hl,$d2fb
	dec     (hl)
	ret     nz
	res     2,(iy+$08)
	ret     

_51f3:
	ld      a,($d412)
	and     a
	ret     nz
	bit     7,(ix+$18)
	ret     z
	ld      a,$03
	rst     $28
	ld      a,$3c
	ld      ($d412),a
	ret     

_5206:
	ld      a,($d223)
	and     $01
	ret     nz
	ld      d,$18
	ret     

_520f:
	ld      hl,_592b
	ret     

_5213:
	ld      hl,_5939
	bit     1,(ix+$18)
	ret     z
	ld      hl,_594b
	ret     

_521f:
	ld      (ix+$13),$00
	ret     

_5224:
	bit     4,(ix+$18)
	ret     z
	ld      a,($d223)
	and     a
	call    z,_91eb
	ret     

_5231:
	dec     a
	ld      ($d2e1),a
	cp      $06
	jr      c,_523c
	cp      $0a
	ret     c
_523c:
	ld      a,(iy+$0a)
	ld      hl,($d23c)
	push    af
	push    hl
	ld      hl,$d000
	ld      ($d23c),hl
	ld      de,($d25d)
	ld      hl,($d2e4)
	and     a
	sbc     hl,de
	ex      de,hl
	ld      bc,($d25a)
	ld      hl,($d2e2)
	and     a
	sbc     hl,bc
	ld      bc,_526e
	call    _LABEL_350F_95
	pop     hl
	pop     af
	ld      ($d23c),hl
	ld      (iy+$0a),a
	ret     

_526e:
.db $00, $02, $04, $06, $ff, $ff, $20, $22, $24, $26, $ff, $ff, $ff, $ff, $ff, $ff
.db $ff, $ff

_5280:
	ld      (ix+$14),$09
	ret     

_5285:
	dec     a
	ld      ($d28b),a
	ret     nz
	ld      a,($d2fc)
	rst     $18
	ld      c,(iy+$0a)
	res     0,(iy+$00)
	call    wait
_5298:
	ld      (iy+$0a),c
	ret     

_529c:
	ld      (iy+$03),$fb
	ld      hl,($d3fe)
	ld      de,$1b60
	and     a
	sbc     hl,de
	ret     nc
	ld      (iy+$03),$ff
	ld      hl,($d403)
	ld      a,l
	or      h
	ret     nz
	res     1,(ix+$18)
	pop     hl
	set     1,(ix+$18)
	ld      (ix+$14),$18
	ld      hl,$d2fe
	bit     0,(iy+$0d)
	jr      nz,_530b
	ld      (hl),$50
	call    _7c7b
	jp      c,_4c39
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$54
	ld      (ix+$11),a
	ld      (ix+$18),a
	ld      (ix+$01),a
	ld      hl,($d3fe)
	ld      de,$0002
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,($d401)
	ld      de,$000e
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	pop     ix
	set     0,(iy+$0d)
	jp      _4c39
_530b:
	bit     1,(iy+$0d)
	jr      nz,_531b
	dec     (hl)
	jp      nz,_4c39
	set     1,(iy+$0d)
	ld      (hl),$8c
_531b:
	ld      (ix+$14),$17
	ld      a,(hl)
	and     a
	jr      z,_5327
	dec     (hl)
	jp      _4c39
_5327:
	ld      (ix+$14),$19
	jp      _4c39

_532e:
	ld      a,(ix+$0e)
	cp      $18
	jr      z,_533f
	ld      hl,($d401)
	ld      de,$0008
	add     hl,de
	ld      ($d401),hl
_533f:
	ld      (ix+$0d),$18
	ld      (ix+$0e),$18
	ld      hl,($d403)
	ld      b,(ix+$09)
	ld      c,$00
	ld      e,c
	ld      d,c
	ld      a,h
	or      l
	or      b
	jp      z,_53b9
	ld      (ix+$14),$09
	bit     2,(iy+$03)
	jr      nz,_5381
	bit     1,(iy+$03)
	jr      z,_5381
	bit     7,(ix+$18)
	jp      z,_5379
	bit     7,b
	jr      nz,_53a7
	res     0,(ix+$18)
	jp      _4fa6
_5379:
	ld      de,$fff0
	ld      c,$ff
	jp      _4b1b
_5381:
	bit     3,(iy+$03)
	jr      nz,_53a7
	bit     1,(iy+$03)
	jr      z,_53a7
	bit     7,(ix+$18)
	jp      z,_539f
	bit     7,b
	jr      z,_53a7
	res     0,(ix+$18)
	jp      _4fa6
_539f:
	ld      de,$0010
	ld      c,$00
	jp      _4b1b
_53a7:
	ld      de,$0004
	ld      c,$00
	ld      a,b
	and     a
	jp      m,_4b1b
	ld      de,$fffc
	ld      c,$ff
	jp      _4b1b

_53b9:
	bit     7,(ix+$18)
	jr      z,_53e0
	ld      (ix+$14),$07
	res     0,(ix+$18)
	ld      de,($d2b7)
	bit     7,d
	jr      z,_53d8
	ld      hl,$ffb0
	and     a
	sbc     hl,de
	jp      nc,_4b49
_53d8:
	dec     de
	ld      ($d2b7),de
	jp      _4b49
_53e0:
	ld      (ix+$14),$09
	push    de
	push    hl
	bit     7,b
	jr      z,_53f1
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
_53f1:
	ld      de,($d240)
	xor     a
	sbc     hl,de
	pop     hl
	pop     de
	jp      c,_4b1b
	ld      c,a
	ld      e,c
	ld      d,c
	ld      (ix+$14),$09
	jp      _4b1b
_5407:
	bit     7,(ix+$18)
	jr      z,_542e
	bit     3,(ix+$18)
	jr      nz,_5419
	bit     5,(iy+$03)
	jr      z,_542e
_5419:
	bit     5,(iy+$03)
	jr      nz,_5435
	res     0,(ix+$18)
	ld      a,($d403)
	and     $f8
	ld      ($d403),a
	jp      _4b7f
_542e:
	res     3,(ix+$18)
	jp      _4bac
_5435:
	set     3,(ix+$18)
	jp      _4bac

_543c:
	set     5,(ix+$18)
	ld      a,($d287)
	cp      $60
	jr      z,_54aa
	ld      hl,($d25d)
	ld      de,$00c0
	add     hl,de
	ld      de,($d401)
	sbc     hl,de
	jr      nc,_546c
	bit     2,(iy+$06)
	jr      nz,_546c
	ld      a,$01
	ld      ($d283),a
	ld      hl,S1_LIVES
	dec     (hl)
	set     2,(iy+$06)
	jp      _54aa
_546c:
	xor     a
	ld      hl,$0080
	bit     3,(iy+$08)
	jr      nz,_549b
	ld      de,($d406)
	bit     7,d
	jr      nz,_5486
	ld      hl,$0600
	and     a
	sbc     hl,de
	jr      c,_54a1
_5486:
	ex      de,hl
	ld      b,(ix+$0c)
	ld      a,h
	cp      $80
	jr      nc,_5493
	cp      $08
	jr      nc,_5498
_5493:
	ld      de,$0030
	ld      c,$00
_5498:
	add     hl,de
	ld      a,b
	adc     a,c
_549b:
	ld      ($d406),hl
	ld      ($d408),a
_54a1:
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
_54aa:
	ld      (ix+$14),$0b
	bit     3,(iy+$08)
	jp      z,_4c39
	ld      (ix+$14),$15
	jp      _4c39

	bit     7,(iy+$06)
	ret     nz
	res     4,(ix+$18)
	ret     

	bit     0,(iy+$05)
	jp      z,_35fd
	ret     

_54ce:
	ld      a,(ix+$02)
	add     a,$0c
	and     $1f
	cp      $1a
	ret     c
	ld      a,($d414)
	rrca    
	jr      c,_54e1
	and     $02
	ret     z
_54e1:
	ld      l,(ix+$07)
	ld      h,(ix+$08)
	bit     7,(ix+$09)
	ret     nz
	ld      de,$0301
	and     a
	sbc     hl,de
	ret     c
	ld      l,(ix+$08)
	ld      h,(ix+$09)
	add     hl,hl
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      (ix+$0a),$00
	ld      (ix+$0b),l
	ld      (ix+$0c),h
	ld      a,$05
	rst     $28
	ret     

_550f:
	ld      a,(ix+$02)
	add     a,$0c
	and     $1f
	cp      $10
	ret     c
	ld      (ix+$07),$00
	ld      (ix+$08),$f8
	ld      (ix+$09),$ff
	set     1,(ix+$18)
	ld      a,$04
	rst     $28
	ret     

_552d:
	ld      a,(ix+$02)
	add     a,$0c
	and     $1f
	cp      $10
	ret     c
	bit     7,(ix+$18)
	ret     z
	ld      a,($d2b9)
	and     $80
	ret     nz
	res     6,(iy+$06)
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f4
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28
	ret     

_5556:
	ld      a,(ix+$02)
	add     a,$0c
	and     $1f
	cp      $10
	ret     nc
	res     6,(iy+$06)
	ld      (ix+$07),$00
	ld      (ix+$08),$08
	ld      (ix+$09),$00
	res     1,(ix+$18)
	ld      a,$04
	rst     $28
	ret     

_5578:
	bit     7,(ix+$18)
	ret     z
	ld      hl,($d3fd)
	ld      a,($d3ff)
	ld      de,$fe80
	add     hl,de
	adc     a,$ff
	ld      ($d3fd),hl
	ld      ($d3ff),a
	ret     

_5590:
	bit     7,(ix+$18)
	ret     z
	ld      hl,($d3fd)
	ld      a,($d3ff)
	ld      de,$0200
	add     hl,de
	adc     a,$00
	ld      ($d3fd),hl
	ld      ($d3ff),a
	ret     

_55a8:
	bit     4,(ix+$18)
	jr      nz,_55b1
	ld      a,$12
	rst     $28
_55b1:
	set     4,(ix+$18)
	ret     

_55b6:
	ld      a,(ix+$02)
	add     a,$0c
	and     $1f
	cp      $08
	ret     c
	cp      $18
	ret     nc
	bit     7,(ix+$18)
	ret     z
	ld      a,($d2b9)
	and     $80
	ret     nz
	res     6,(iy+$06)
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f4
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28
	ret     

_55e2:
	bit     7,(ix+$0c)
	ret     nz
	ld      a,$05
	rst     $28
	ret     

_55eb:
	bit     4,(iy+$06)
	ret     nz
	ld      a,($d3fe)
	add     a,$0c
	and     $1f
	cp      $08
	ret     c
	cp      $18
	ret     nc
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      e,h
	ld      hl,($d401)
	ld      bc,$0010
	add     hl,bc
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      d,h
	ld      hl,_5643
	ld      b,$05
_5626:
	ld      a,(hl)
	inc     hl
	cp      e
	jr      nz,_563c
	ld      a,(hl)
	cp      d
	jr      nz,_563c
	inc     hl
	ld      ($d2d5),hl
	ld      a,$50
	ld      ($d28a),a
	ld      a,$06
	rst     $28
	ret     

_563c:
	inc     hl
	inc     hl
	inc     hl
	inc     hl
	djnz    _5626
	ret     

_5643:
.db $34, $3c, $34, $2f, $00, $19, $3a, $19, $04, $00, $0e, $3a, $00, $00, $16, $1b
.db $32, $00, $00, $17, $2f, $0c, $00, $00, $ff

_565c:
	ld      hl,($d403)
	ld      a,($d405)
	ld      de,$fff8
	add     hl,de
	adc     a,$ff
	ld      ($d403),hl
	ld      ($d405),a
	bit     4,(ix+$18)
	jr      nz,_5677
	ld      a,$12
	rst     $28
_5677:
	set     4,(ix+$18)
	ret     
	xor     a
	ld      hl,$0005
	ld      ($d403),a
	ld      ($d404),hl
	res     1,(ix+$18)
_568a:
	ld      a,$06
	ld      ($d28c),a
_568f:
	ld      a,(iy+$03)
	or      $0f
	ld      (iy+$03),a
	ld      hl,$0004
	ld      ($d407),hl
	res     0,(ix+$18)
	res     2,(ix+$18)
	ret     
	xor     a
	ld      hl,$0006
	ld      ($d403),a
	ld      ($d404),hl
	res     1,(ix+$18)
	jr      _568a
	xor     a
	ld      hl,$fffb
	ld      ($d403),a
	ld      ($d404),hl
	set     1,(ix+$18)
	jr      _568a
	xor     a
	ld      hl,$fffa
	ld      ($d403),a
	ld      ($d404),hl
	set     1,(ix+$18)
	jr      _568a
	ld      a,($d2e1)
	cp      $08
	ret     nc
	call    _5727
	ld      de,$0001
	ld      hl,($d406)
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	ld      a,($d408)
	cpl     
	add     hl,de
	adc     a,$00
	and     a
	jp      p,_56fc
	ld      de,$ffc8
	add     hl,de
	adc     a,$ff
_56fc:
	ld      ($d406),hl
	ld      ($d408),a
	ld      bc,$000c
	ld      hl,($d3fe)
	add     hl,bc
	ld      a,l
	and     $e0
	ld      l,a
	ld      ($d2e2),hl
	ld      bc,$0010
	ld      hl,($d401)
	add     hl,bc
	ld      a,l
	and     $e0
	ld      l,a
	ld      ($d2e4),hl
	ld      a,$10
	ld      ($d2e1),a
	ld      a,$07
	rst     $28
	ret     

_5727:
	ld      hl,($d403)
	ld      a,($d405)
	ld      c,a
	and     $80
	ld      b,a
	ld      a,($d3fe)
	add     a,$0c
	and     $1f
	sub     $10
	and     $80
	cp      b
	jr      z,_5748
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	ld      a,c
	cpl     
	ld      c,a
_5748:
	ld      de,$0001
	ld      a,c
	add     hl,de
	adc     a,$00
	ld      e,l
	ld      d,h
	ld      c,a
	sra     c
	rr      d
	rr      e
	add     hl,de
	adc     a,c
	ld      ($d403),hl
	ld      ($d405),a
	ret     
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f6
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28
	ret     
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f4
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28
	ret     
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f2
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28
	ret     
	ld      a,($d2b1)
	and     a
	ret     nz
	ld      de,$0001
	ld      hl,($d403)
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	ld      a,($d405)
	cpl     
	add     hl,de
	adc     a,$00
	ld      de,$ff00
	ld      c,$ff
	jp      m,_57b6
	ld      de,$0100
	ld      c,$00
_57b6:
	add     hl,de
	adc     a,c
	ld      ($d403),hl
	ld      ($d405),a
_57be:
	ld      hl,$d2b1
	ld      (hl),$04
	inc     hl
	ld      (hl),$0e
	inc     hl
	ld      (hl),$3f
	ld      a,$07
	rst     $28
	ret     
	call    _5727
	ld      de,$0001
	ld      hl,($d406)
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	ld      a,($d408)
	cpl     
	add     hl,de
	adc     a,$00
	and     a
	jp      p,_57ed
	ld      de,$ffc8
	add     hl,de
	adc     a,$ff
_57ed:
	ld      ($d406),hl
	ld      ($d408),a
	jp      _57be
	ld      hl,($d2e9)
	ld      de,$0082
	and     a
	sbc     hl,de
	ret     c
	bit     0,(iy+$05)
	jp      z,_35fd
	ret     
	ld      a,($d414)
	rlca    
	ret     nc
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      a,l
	and     $1f
	cp      $10
	jr      nc,_5858
_581b:
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      a,l
	and     $e0
	ld      c,a
	ld      b,h
	ld      hl,($d401)
	ld      de,$0010
	add     hl,de
	ld      a,l
	and     $e0
	ld      e,a
	ld      d,h
	call    _5893
	ret     c
	ld      bc,$000c
	ld      de,$0010
	call    _36f9
	ld      c,$00
	ld      a,(hl)
	cp      $8a
	jr      z,_5849
	ld      c,$89
_5849:
	ld      (hl),c
	ret     
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      a,l
	and     $1f
	cp      $10
	ret     c
_5858:
	ld      a,l
	and     $e0
	add     a,$10
	ld      c,a
	ld      b,h
	ld      hl,($d401)
	ld      de,$0010
	add     hl,de
	ld      a,l
	and     $e0
	ld      e,a
	ld      d,h
	call    _5893
	ret     c
	ld      bc,$000c
	ld      de,$0010
	call    _36f9
	ld      c,$00
	ld      a,(hl)
	cp      $89
	jr      z,_5849
	ld      c,$8a
	ld      (hl),c
	ret     
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      a,l
	and     $1f
	cp      $10
	ret     nc
	jp      _581b

_5893:
	push    bc
	push    de
	call    _7c7b
	pop     de
	pop     bc
	ret     c
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$2e
	ld      (ix+$01),a
	ld      (ix+$02),c
	ld      (ix+$03),b
	ld      (ix+$04),a
	ld      (ix+$05),e
	ld      (ix+$06),d
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      (ix+$18),a
	pop     ix
	and     a
	ret     
	bit     7,(ix+$18)
	ret     z
	ld      hl,($d401)
	ld      de,($d25d)
	and     a
	sbc     hl,de
	ret     nc
	ld      (iy+$03),$ff
	ret  
   
_58e5:					;lookup table?
.db $BC, $54, $C6, $54, $CE, $54, $0F, $55, $2D, $55, $56, $55, $78, $55, $90, $55
.db $A8, $55, $B6, $55, $E2, $55, $EB, $55, $5C, $56, $7C, $56, $A6, $56, $B6, $56
.db $C6, $56, $D6, $56, $61, $57, $71, $57, $81, $57, $91, $57, $CD, $57, $F6, $57
.db $08, $58, $4B, $58, $83, $58, $D0, $58
_591d:
.db $B4, $B6, $B8, $FF, $FF, $FF, $BA, $BC, $BE, $FF, $FF, $FF, $FF, $FF
_592b:
.db $B8, $B6, $B4, $FF, $FF, $FF, $BE, $BC, $BA, $FF, $FF, $FF, $FF, $FF
_5939:
.db $B4, $B6, $B8, $FF, $FF, $FF, $BA, $BC, $BE, $FF, $FF, $FF, $98, $9A, $FF, $FF
.db $FF, $FF
_594b:
.db $B4, $B6, $B8, $FF, $FF, $FF, $BA, $BC, $BE, $FF, $FF, $FF, $FE, $9C, $9E, $FF
.db $FF, $FF, $00, $00, $00, $00, $00, $00, $00, $00
_5965:
.db $99, $59, $99, $59, $CB, $59, $DD, $59, $DF, $59, $E2, $59, $E5, $59, $FB, $59, $FE, $59, $01, $5A, $53, $5A, $65, $5A, $68, $5A, $6B, $5A, $AF, $5A, $C5, $5A, $CC, $5A, $D0, $5A, $DE, $5A, $E1, $5A, $E4, $5A, $E7, $5A, $EA, $5A, $00, $5B, $03, $5B, $06, $5B, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03, $03, $03, $03, $04, $04, $04, $04, $04, $04, $04, $04, $05, $05, $05, $05, $05, $05, $05, $05, $FF, $00, $0D, $0D, $0D, $0D, $0E, $0E, $0E, $0E, $0F, $0F, $0F, $0F, $10, $10, $10, $10, $FF, $00, $FF, $00, $13, $FF, $00, $06, $FF, $00, $08, $08, $08, $08, $09, $09, $09, $09, $0A, $0A, $0A, $0A, $0B, $0B, $0B, $0B, $0C, $0C, $0C, $0C, $FF, $00, $07, $FF, $00, $00, $FF, $00, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $FF, $00, $13, $13, $13, $13, $13, $13, $13, $13, $25, $25, $25, $25, $25, $25, $25, $25, $FF, $00, $11, $FF, $00, $14, $FF, $00, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $FF, $22, $19, $19, $19, $19, $1A, $1A, $1B, $1B, $1C, $1C, $1D, $1D, $1E, $1E, $1F, $1F, $20, $20, $21, $21, $FF, $12, $0C, $08, $09, $0A, $0B, $FF, $00, $12, $12, $FF, $00, $12, $12, $12, $12, $12, $12, $24, $24, $24, $24, $24, $24, $FF, $00, $00, $FF, $00, $26, $FF, $00, $22, $FF, $00, $23, $FF, $00, $21, $21, $20, $20, $1F, $1F, $1E, $1E, $1D, $1D, $1C, $1C, $1B, $1B, $1A, $1A, $19, $19, $19, $19, $FF, $12, $19, $FF, $00, $1A, $FF, $00, $1B, $FF, $00

;____________________________________________________________________________[$5B09]___

;OBJECT: monitor - rings
_5b09:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5b31
	call    _5deb
	jr      c,_5b31
_5b24:	
	ld      a,$10
	call    _39ac
_5b29:
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ret  

_5b31:   
	ld      hl,$5180
_5b34:
	call    _c1d
	ld      (ix+$0f),<_5bbf
	ld      (ix+$10),>_5bbf
	ld      a,($d223)
	and     $07
	cp      $05
	ret     nc
	ld      (ix+$0f),<_5bcc
	ld      (ix+$10),>_5bcc
	ld      l,(ix+$01)
	ld      h,(ix+$02)
	ld      a,(ix+$03)
	ld      e,(ix+$07)
	ld      d,(ix+$08)
	add     hl,de
	adc     a,(ix+$09)
	ld      l,h
	ld      h,a
	ld      ($d20e),hl
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      a,(ix+$06)
	bit     7,(ix+$18)
	jr      nz,_5b80
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	add     hl,de
	adc     a,(ix+$0c)
_5b80:
	ld      l,h
	ld      h,a
	ld      ($d210),hl
	ld      hl,$0004
	ld      ($d212),hl
	ld      hl,$0000
	ld      ($d214),hl
	ld      a,$5c
	call    _3581
	ld      hl,$000c
	ld      ($d212),hl
	ld      a,$5e
	call    _3581
	bit     1,(ix+$18)
	ret     z
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0040
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ret     

_5bbf:
.db $54, $56, $58, $FF, $FF, $FF, $AA, $AC, $AE, $FF, $FF, $FF, $FF
_5bcc:
.db $54, $FE, $58, $FF, $FF, $FF, $AA, $AC, $AE, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$5BD9]___

;OBJECT: monitor - speed shoes
_5bd9:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5bff
	call    _5deb
	jr      c,_5bff
	ld      a,$f0
	ld      ($d411),a
	ld      a,$02
	rst     $28
	jp      _5b29
_5bff:
	ld      hl,$5200
	jp      _5b34

;____________________________________________________________________________[$5C05]___

;OBJECT: monitor - life
_5c05:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$d305
	call    _LABEL_C02_135
	ld      a,(hl)
	and     c
	jr      z,_5c21
	ld      (ix+$00),$ff
	jp      _5b29
_5c21:
	ld      hl,$0003
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5c5a
	call    _5deb
	jr      c,_5c5a
	bit     2,(ix+$18)
	jp      nz,_5b24
	ld      hl,S1_LIVES
	inc     (hl)
	ld      hl,$d305
	call    _LABEL_C02_135
	ld      a,(hl)
	or      c
	ld      (hl),a
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      a,$09
	rst     $28
	ld      a,(S1_CURRENT_LEVEL)
	cp      $1c
	ret     nc
	ld      hl,$d280
	inc     (hl)
	ret     

_5c5a:
	ld      a,(S1_CURRENT_LEVEL)
	cp      4			;level 4 (Bridge Act 2)?
	jr      z,_5c73
	cp      $09			;level 9 (Labyrinth Act 1)?
	jr      z,_5c9c
	cp      $0c			;level 12 (Scrap Brain Act 1)?
	jr      z,_5cb8
	cp      $11			;level 11 (Labyrinth Act 3)?
	jr      z,_5cca
_5c6d:
	ld      hl,$5280
	jp      _5b34

_5c73:
	ld      c,$00
	ld      de,$0040
	ld      a,(ix+$13)
	cp      $3c
	jr      c,_5c83
	dec     c
	ld      de,$ffc0
_5c83:
	ld      (ix+$0a),e
	ld      (ix+$0b),d
	ld      (ix+$0c),c
	inc     (ix+$13)
	ld      a,(ix+$13)
	cp      $50
	jr      c,_5c6d
	ld      (ix+$13),$28
	jr      _5c6d
_5c9c:
	set     2,(ix+$18)
	ld      hl,$d317
	call    _LABEL_C02_135
	ld      a,(hl)
	ld      hl,$5180
	and     c
	jp      z,_5b34
	res     2,(ix+$18)
	ld      hl,$5280
	jp      _5b34
_5cb8:
	set     1,(ix+$18)
	ld      (ix+$07),$80
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	jr      _5c6d
_5cca:
	ld      a,($d280)
	cp      $11
	jr      nc,_5c6d
	ld      (ix+$00),$ff
	jr      _5c6d

;____________________________________________________________________________[$5CD7]___

;OBJECT: monitor - shield
_5cd7:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5cf9
	call    _5deb
	jr      c,_5cf9
	set     5,(iy+$06)
	jp      _5b29
_5cf9:
	ld      hl,$5300
	jp      _5b34

;____________________________________________________________________________[$5CFF]___

;OBJECT: monitor - invincibility
_5cff:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5d29
	call    _5deb
	jr      c,_5d29
	set     0,(iy+$08)
	ld      a,$f0
	ld      ($d28d),a
	ld      a,$08
	rst     $18
	jp      _5b29
_5d29:
	ld      hl,$5380
	jp      _5b34
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5d7a
	call    _5deb
	jr      c,_5d7a
	ld      hl,$d311
	call    _LABEL_C02_135
	ld      a,(hl)
	or      c
	ld      (hl),a
	ld      a,(S1_CURRENT_LEVEL)
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,$d32e
	add     hl,de
	ex      de,hl			;DE is $D32E + level number * 2
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      a,h
	ld      (de),a
	inc     de
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      a,h
	dec     a
	ld      (de),a
	jp      _5b29
_5d7a:
	ld      hl,$5480
	jp      _5b34
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5da2
	call    _5deb
	jr      c,_5da2
	set     3,(iy+$09)
	jp      _5b29
_5da2:
	ld      hl,$5500
	jp      _5b34

_5da8:
	bit     0,(ix+$18)
	ret     nz
	ld      a,(S1_LEVEL_SOLIDITY)
	and     a
	jr      nz,_5dc6
	ld      bc,$0000
	ld      e,c
	ld      d,b
	call    _36f9
	ld      de,$0016
	ld      bc,$0012
	ld      a,(hl)
	cp      $ab
	jr      z,_5dcc
_5dc6:
	ld      de,$0004
	ld      bc,$0000
_5dcc:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	set     0,(ix+$18)
	ret     

_5deb:
	ld      hl,$0804
	ld      ($d20e),hl
	ld      a,($d414)
	and     $01
	jr      nz,_5e49
	ld      de,($d3fe)
	ld      c,(ix+$02)
	ld      b,(ix+$03)
	ld      hl,$ffee
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,_5e6d
	ld      hl,$0010
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,_5e6d
	ld      a,($d414)
	and     $04
	jr      nz,_5e42
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      a,($d40a)
	ld      c,a
	xor     a
	ld      b,a
	sbc     hl,bc
	ld      ($d401),hl
	ld      ($d28e),a
	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
	ld      hl,$d414
	set     7,(hl)
	scf     
	ret     

_5e42:
	ld      a,($d408)
	and     a
	jp      m,_5e4e
_5e49:
	call    _36be
	and     a
	ret     

_5e4e:
	ld      (ix+$0a),$80
	ld      (ix+$0b),$fe
	ld      (ix+$0c),$ff
	ld      hl,$0400
	xor     a
	ld      ($d406),hl
	ld      ($d408),a
	ld      ($d28e),a
	set     1,(ix+$18)
	scf     
	ret     

_5e6d:
	ld      hl,($d3fe)
	ld      de,$000c
	add     hl,de
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,$000a
	add     hl,bc
	ld      bc,$ffeb
	and     a
	sbc     hl,de
	jr      nc,_5e8a
	ld      bc,$0015
_5e8a:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	ld      ($d3fe),hl
	xor     a
	ld      ($d3fd),a
	ld      l,a
	ld      h,a
	ld      ($d403),a
	ld      ($d404),hl
	scf     
	ret

;____________________________________________________________________________[$5EA2]___

;OBJECT: chaos emerald	
_5ea2:	
	ld      hl,$d30b
	call    _LABEL_C02_135
	ld      a,(hl)
	and     c
	jr      nz,_5ede
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$11
	call    _5da8
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      hl,$0202
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_5ee3
	ld      hl,$d30b
	call    _LABEL_C02_135
	ld      a,(hl)
	or      c
	ld      (hl),a
	ld      hl,$d27f
	inc     (hl)
	ld      a,$fe
	ld      ($d28b),a
	ld      a,$14
	rst     $18
_5ede:
	ld      (ix+$00),$ff
	ret     

_5ee3:
	ld      a,($d223)
	rrca    
	jr      c,_5ef1
	ld      (ix+$0f),<_5f10
	ld      (ix+$10),>_5f10
_5ef1:
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      hl,$5400
	call    _c1d
	ret     

_5f10:
.db $5C, $5E, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$5F17]___

;OBJECT: end sign
_5f17:
	ld      (ix+$0d),$18
	ld      (ix+$0e),$30
	bit     0,(ix+$11)
	jr      nz,_5f44
	res     7,(iy+$06)
	res     3,(iy+$05)
	
	;end sign sprite set
	ld      hl,$4294
	ld      de,$2000
	ld      a,9
	call    decompressArt
	
	ld      hl,S1_EndSign_Palette
	ld      a,$02
	call    loadPaletteOnInterrupt
	set     0,(ix+$11)
_5f44:
	ld      hl,($d25a)
	ld      (S1_LEVEL_CROPLEFT),hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$ff90
	add     hl,de
	ld      ($d275),hl
	ld      hl,$0080
	ld      ($d26b),hl
	ld      hl,$0088
	ld      ($d26d),hl
	ld      c,(ix+$13)
	ld      a,($d414)
	and     $80
	ld      (ix+$13),a
	jr      z,_5fa4
	cp      c
	jr      z,_5fa4
	bit     7,(ix+$18)
	jr      z,_5fa4
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	bit     7,h
	jr      z,_5f90
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
_5f90:
	ld      de,$0064
	and     a
	sbc     hl,de
	jr      nc,_5fa4
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fe
	ld      (ix+$0c),$ff
_5fa4:
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$001a
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	bit     3,(ix+$11)
	jr      nz,_6030
	bit     2,(ix+$11)
	jr      z,_5fe8
	bit     7,(ix+$18)
	jr      z,_6030
	ld      a,$09
	rst     $18
	ld      a,$0c
	rst     $28
	res     2,(ix+$11)
	set     3,(ix+$11)
	ld      a,$a0
	ld      ($d289),a
	set     1,(iy+$06)
	jp      _6030
_5fe8:
	ld      hl,$0a0a
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_6030
	bit     7,(ix+$0c)
	jr      nz,_6030
	bit     1,(ix+$11)
	jr      nz,_6030
	ld      de,($d403)
	bit     7,d
	jr      z,_600e
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
_600e:
	ld      hl,$0300
	and     a
	sbc     hl,de
	jr      nc,_6019
	ld      de,$0300
_6019:
	ex      de,hl
	add     hl,hl
	ld      (ix+$14),l
	ld      (ix+$15),h
	ld      (ix+$12),$00
	set     1,(ix+$11)
	res     3,(iy+$06)
	ld      a,$0b
	rst     $28
_6030:
	ld      de,_6157
	bit     1,(ix+$11)
	jr      nz,_6096
	bit     2,(ix+$11)
	jr      nz,_6096
	ld      de,$6171
	bit     3,(ix+$11)
	jr      z,_6096
	ld      a,(S1_CURRENT_LEVEL)
	cp      $0c
	jr      c,_605a
	cp      $1c
	jr      c,_6066
	ld      de,$618e
	ld      c,$01
	jr      _6092
_605a:
	ld      de,$61a8
	ld      c,$04
	ld      a,(S1_RINGS)
	cp      $50
	jr      nc,_6092
_6066:
	cp      $40
	jr      z,_6073
	ld      de,$61c2
	ld      c,$03
	and     $0f
	jr      z,_6092
_6073:
	ld      a,(S1_RINGS)
	srl     a
	srl     a
	srl     a
	srl     a
	ld      b,a
	ld      a,(S1_CURRENT_LEVEL)
	and     $03
	inc     a
	ld      de,$6174
	ld      c,$02
	cp      b
	jr      z,_6092
	ld      de,$618e
	ld      c,$01
_6092:
	ld      a,c
	ld      ($d288),a
_6096:
	ld      l,(ix+$12)
	ld      h,$00
	add     hl,de
	ld      a,(hl)
	cp      $ff
	jr      nz,_60a9
	inc     hl
	ld      a,(hl)
	ld      (ix+$12),a
	jp      _6096
_60a9:
	ld      l,a
	ld      h,$00
	add     hl,hl
	ld      e,l
	ld      d,h
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,de
	ld      de,$61dc
	add     hl,de
	ld      (ix+$0f),l
	ld      (ix+$10),h
	bit     1,(ix+$11)
	jr      nz,_60c7
	inc     (ix+$12)
	ret     
_60c7:
	ld      a,(ix+$14)
	add     a,(ix+$16)
	ld      (ix+$16),a
	ld      a,(ix+$15)
	push    af
	adc     a,(ix+$17)
	ld      (ix+$17),a
	pop     af
	adc     a,(ix+$12)
	cp      $18
	jr      c,_60e3
	xor     a
_60e3:
	ld      (ix+$12),a
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	ld      a,(ix+$0c)
	and     a
	jp      p,_60f9
	ld      hl,$fc00
	sbc     hl,de
	ret     nc
_60f9:
	ex      de,hl
	ld      e,(ix+$14)
	ld      d,(ix+$15)
	ld      c,e
	ld      b,d
	srl     d
	rr      e
	srl     d
	rr      e
	srl     d
	rr      e
	srl     d
	rr      e
	srl     d
	rr      e
	and     a
	sbc     hl,de
	sbc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	xor     a
	ld      de,$0008
	sbc     hl,de
	jr      c,_6141
	ld      l,c
	ld      h,b
	ld      de,$0010
	xor     a
	sbc     hl,de
	ld      (ix+$14),l
	ld      (ix+$15),h
	ret     nc
_6141:
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	res     1,(ix+$11)
	set     2,(ix+$11)
	ld      (ix+$12),$00
	ret     

_6157:
.db $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $04, $04, $04, $04, $04, $04, $FF, $00, $00, $FF, $00, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $FF, $12, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $05, $05, $05, $05, $05, $05, $FF, $12, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $06, $06, $06, $06, $06, $06, $FF, $12, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $07, $07, $07, $07, $07, $07, $FF, $12, $4E, $50, $52, $54, $FF, $FF, $6E, $70, $72, $74, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF, $08, $0A, $0C, $0E, $FF, $FF, $28, $2A, $2C, $2E, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF, $FE, $12, $14, $FF, $FF, $FF, $FE, $32, $34, $FF, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF, $16, $18, $1A, $1C, $FF, $FF, $36, $38, $3A, $3C, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF, $56, $58, $5A, $5C, $FF, $FF, $76, $78, $7A, $7C, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF, $00, $02, $04, $06, $FF, $FF, $20, $22, $24, $26, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF, $4E, $4A, $4C, $54, $FF, $FF, $6E, $6A, $6C, $74, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF, $4E, $46, $48, $54, $FF, $FF, $6E, $66, $68, $74, $FF, $FF, $FE, $42, $44, $FF, $FF, $FF

;____________________________________________________________________________[$626C]___

S1_EndSign_Palette:
.db $38, $20, $35, $1b, $16, $2a, $00, $3f, $03, $0f, $01, $00, $00, $00, $00, $00

;____________________________________________________________________________[$627C]___

S1_Palette_Pointers:

.dw S1_Palette_0, S1_Palette_1, S1_Palette_2, S1_Palette_3
.dw S1_Palette_4, S1_Palette_5, S1_Palette_6, S1_Palette_7

S1_PaletteCycle_Pointers:		;[$628C]

.dw S1_PaletteCycles_0, S1_PaletteCycles_1, S1_PaletteCycles_2
.dw S1_PaletteCycles_3, S1_PaletteCycles_4, S1_PaletteCycles_5
.dw S1_PaletteCycles_6, S1_PaletteCycles_7, S1_PaletteCycles_8

S1_Palettes:				;[$629E]

S1_Palette_0:				;[$629E] Green Hill
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3C, $3E, $3F, $0F, $00, $3F
.db $38, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $00, $00, $00
S1_PaletteCycles_0:			;[$62BE] Green Hill Cycles x 3
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3C, $3E, $3F, $0F, $00, $3F
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3F, $3C, $3E, $0F, $00, $3F
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3E, $3F, $3C, $0F, $00, $3F
S1_Palette_1:				;[$62EE] Bridge
.db $38, $01, $06, $0B, $2A, $3A, $0C, $19, $3D, $24, $38, $3C, $3F, $1F, $00, $3F
.db $38, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $0B, $00
S1_PaletteCycles_1:			;[$630E] Bridge Cycles
.db $38, $01, $06, $0B, $3A, $08, $0C, $19, $3C, $24, $38, $3C, $3F, $1F, $00, $3F
.db $38, $01, $06, $0B, $3A, $08, $0C, $19, $3C, $24, $3F, $38, $3C, $1F, $00, $3F
.db $38, $01, $06, $0B, $3A, $08, $0C, $19, $3C, $24, $3C, $3F, $38, $1F, $00, $3F
S1_Palette_2:				;[$633E] Jungle
.db $04, $08, $0C, $06, $0B, $05, $25, $01, $03, $10, $34, $38, $3E, $1F, $00, $3F
.db $04, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $0B, $00
S1_PaletteCycles_2:			;[$635E] Jungle Cycles
.db $04, $08, $0C, $06, $0B, $05, $26, $01, $03, $10, $34, $38, $3E, $0F, $00, $3F
.db $04, $08, $0C, $06, $0B, $05, $26, $01, $03, $10, $3E, $34, $38, $0F, $00, $3F
.db $04, $08, $0C, $06, $0B, $05, $26, $01, $03, $10, $38, $3E, $34, $0F, $00, $3F
S1_Palette_3:				;[$638E] Labyrinth
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $1E, $09, $04, $0F, $00, $3F
S1_LabyrinthSpritePalette:
;the code for the water line raster split refers directly to this sprite palette:
.db $00, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $0B, $15
S1_PaletteCycles_3:			;[$63AE] Labyrinth Cycles
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $1E, $09, $04, $0F, $00, $3F
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $09, $04, $1E, $0F, $00, $3F
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $04, $1E, $09, $0F, $00, $3F
S1_Palette_4:				;[$63DE] Scrap Brain
.db $00, $10, $15, $29, $3D, $01, $14, $02, $05, $0A, $0F, $3F, $07, $0F, $00, $3F
.db $00, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3D, $15, $0F, $27, $10, $29
S1_PaletteCycles_4:			;[$63FE] Scrap Brain Cycles
.db $00, $10, $15, $29, $3D, $01, $14, $02, $05, $0A, $0F, $3F, $07, $0F, $00, $3F
.db $00, $10, $15, $29, $3D, $01, $14, $02, $3F, $05, $0A, $0F, $07, $0F, $00, $3F
.db $00, $10, $15, $29, $3D, $01, $14, $02, $0F, $3F, $05, $0A, $07, $0F, $00, $3F
.db $00, $10, $15, $29, $3D, $01, $14, $02, $0A, $0F, $3F, $05, $07, $0F, $00, $3F
S1_Palette_5:				;[$643E] Sky Base 1/2 Exterior
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $39, $3D, $3F, $24, $00, $38
.db $10, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $15, $00
S1_PaletteCycles_5:			;[$645E] Sky Base 1 Cycles
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $39, $3D, $3F, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3F, $3D, $39, $3D, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $3F, $3D, $39, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $39, $3D, $3F, $3D, $24, $00, $38

S1_Lightning_Palette_1			;[$649E] Sky Base 1 Lightning Cycles 1
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $39, $3D, $3F, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3F, $3D, $39, $3D, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $20, $3D, $3F, $3D, $39, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $2A, $39, $3D, $3F, $3D, $24, $00, $38
S1_Lightning_Palette_2			;[$64DE] Sky Base 1 Lightning Cycles 2
.db $10, $10, $20, $34, $30, $10, $11, $25, $2F, $3D, $39, $3D, $3F, $24, $00, $38
.db $30, $14, $29, $2E, $3A, $01, $02, $17, $10, $3F, $3D, $39, $3D, $0F, $00, $3F
.db $10, $10, $20, $34, $30, $10, $11, $25, $3F, $3D, $3F, $3D, $39, $24, $00, $38
.db $30, $14, $29, $2E, $3A, $01, $02, $17, $10, $3F, $3D, $39, $3D, $0F, $00, $3F

S1_PaletteCycles_8:			;[$651E] Sky Base 2
.db $10, $14, $29, $2E, $3A, $01, $02, $17, $10, $3D, $39, $3D, $3F, $0F, $00, $3F
.db $10, $14, $29, $2E, $3A, $01, $02, $17, $10, $3F, $3D, $39, $3D, $0F, $00, $3F
.db $10, $14, $29, $2E, $3A, $01, $02, $17, $10, $3D, $3F, $3D, $39, $0F, $00, $3F
.db $10, $14, $29, $2E, $3A, $01, $02, $17, $10, $39, $3D, $3F, $3D, $0F, $00, $3F
S1_Palette_7:				;[$655E] Special Stage
.db $10, $04, $3B, $1B, $19, $2D, $21, $32, $17, $13, $12, $27, $30, $1F, $00, $3F
.db $10, $20, $35, $1B, $16, $2A, $00, $3F, $19, $13, $12, $27, $04, $1F, $21, $30
S1_PaletteCycles_7:			;[$657E] Special Stage Cycles
.db $10, $04, $3B, $1B, $19, $2D, $11, $32, $17, $13, $12, $27, $30, $1F, $00, $3F
S1_Palette_6:				;[$658E] Sky Base 2/3 Interior
.db $00, $14, $39, $3D, $28, $10, $20, $34, $0F, $07, $3C, $14, $39, $0F, $00, $3F
.db $00, $20, $35, $1B, $16, $2A, $00, $3F, $15, $3A, $0F, $03, $01, $02, $3E, $00
S1_PaletteCycles_6:			;[$65AE] Sky Base 2/3 Interior Cycles
.db $00, $14, $39, $3D, $28, $10, $20, $34, $0F, $07, $3C, $14, $39, $0F, $00, $3F
.db $00, $14, $39, $3D, $28, $10, $20, $34, $07, $0F, $28, $14, $39, $0F, $00, $3F
.db $00, $14, $39, $3D, $28, $10, $20, $34, $0F, $07, $14, $14, $39, $0F, $00, $3F
.db $00, $14, $39, $3D, $28, $10, $20, $34, $07, $0F, $00, $14, $39, $0F, $00, $3F

;____________________________________________________________________________[$65EE]___

;OBJECT: badnick - crabmeat
_65ee:
	ld      (ix+$0d),$10
	ld      (ix+$0e),$1f
	ld      e,(ix+$12)
	ld      d,$00
_65fb:
	ld      hl,_66c5
	add     hl,de
	ld      ($d214),hl
	ld      a,(hl)
	and     a
	jr      nz,_660d
	ld      (ix+$12),a
	ld      e,a
	jp      _65fb
_660d:
	dec     a
	jr      nz,_6618
	ld      c,$00
	ld      h,c
	ld      l,$28
	jp      _666f
_6618:
	dec     a
	jr      nz,_6623
	ld      c,$ff
	ld      hl,$ffd8
	jp      _666f
_6623:
	dec     a
	jr      nz,_662d
	ld      c,$00
	ld      l,c
	ld      h,c
	jp      _666f
_662d:
	ld      a,(ix+$11)
	cp      $20
	jp      nz,_6678
	ld      hl,$ffff
	ld      ($d212),hl
	ld      hl,$fffc
	ld      ($d214),hl
	call    _7c7b
	jp      c,_6678
	ld      de,$0000
	ld      c,e
	ld      b,d
	call    _ac96
	ld      hl,$0001
	ld      ($d212),hl
	ld      hl,$fffc
	ld      ($d214),hl
	call    _7c7b
	jr      c,_6678
	ld      de,$000e
	ld      bc,$0000
	call    _ac96
	ld      a,$0a
	rst     $28
	jp      _6678
_666f:
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
_6678:
	ld      l,(ix+$11)
	ld      h,(ix+$12)
	ld      de,$0008
	add     hl,de
	ld      (ix+$11),l
	ld      (ix+$12),h
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0020
	add     hl,de
	adc     a,d
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      hl,($d214)
	ld      a,(hl)
	add     a,a
	ld      e,a
	ld      hl,_66e0
	add     hl,de
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	ld      de,_66f9
	call    _7c41
	ld      hl,$0a04
	ld      ($d214),hl
	call    _LABEL_3956_11
	ld      hl,$0804
	ld      ($d20e),hl
	call    nc,_35e5
	ret     

_66c5:
.db $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $03, $03, $04, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $03, $03, $04, $00
_66e0:
.db $EA, $66, $EA, $66, $EA, $66, $F3, $66, $F6, $66, $00, $0C, $01, $0C, $02, $0C, $01, $0C, $FF, $01, $01, $FF, $03, $01, $FF
_66f9:
.db $00, $02, $04, $FF, $FF, $FF, $20, $22, $24, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00, $02, $44, $FF, $FF, $FF, $46, $22, $4A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $40, $02, $44, $FF, $FF, $FF, $26, $22, $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $40, $02, $04, $FF, $FF, $FF, $46, $22, $4A, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$673C]___

;OBJECT: wooden platform - swinging (Green Hill)
_673c:
	set     5,(ix+$18)
	ld      hl,$0020
	ld      ($d267),hl
	ld      hl,$0048
	ld      ($d269),hl
	ld      hl,$0030
	ld      ($d26b),hl
	ld      hl,$0030
	ld      ($d26d),hl
	bit     0,(ix+$18)
	jr      nz,_6782
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (ix+$14),l
	ld      (ix+$15),h
	ld      (ix+$11),$e0
	set     0,(ix+$18)
	set     1,(ix+$18)
_6782:
	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      ($d20e),hl
	ld      hl,_682f
	ld      e,(ix+$11)
	ld      d,$00
	add     hl,de
	ld      c,l
	ld      b,h
	ld      a,(bc)
	and     a
	jp      p,_67a4
	dec     d
_67a4:
	ld      e,a
	ld      l,(ix+$12)
	ld      h,(ix+$13)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      de,($d20e)
	and     a
	sbc     hl,de
	ld      ($d20e),hl
	inc     bc
	ld      d,$00
	ld      a,(bc)
	and     a
	jp      p,_67c5
	dec     d
_67c5:
	ld      e,a
	ld      l,(ix+$14)
	ld      h,(ix+$15)
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      a,($d408)
	and     a
	jp      m,_67f9
	ld      hl,$0806
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_67f9
	ld      hl,($d3fe)
	ld      de,($d20e)
	add     hl,de
	ld      ($d3fe),hl
	ld      bc,$0010
	ld      de,$0000
	call    _LABEL_7CC1_12
_67f9:
	ld      hl,$6911
	ld      a,(S1_LEVEL_SOLIDITY)
	and     a
	jr      z,_6805
	ld      hl,$6923
_6805:
	ld      (ix+$0f),l
	ld      (ix+$10),h
	bit     1,(ix+$18)
	jr      nz,_6821
	ld      a,(ix+$11)
	inc     a
	inc     a
	ld      (ix+$11),a
	cp      $e0
	ret     c
	set     1,(ix+$18)
	ret     
_6821:
	ld      a,(ix+$11)
	dec     a
	dec     a
	ld      (ix+$11),a
	ret     nz
	res     1,(ix+$18)
	ret     

_682f:
.db $B3, $00, $B3, $01, $B3, $02, $B3, $02, $B3, $03, $B3, $04, $B3, $05, $B3, $06, $B4, $07, $B4, $08, $B4, $09, $B4, $0B, $B4, $0C, $B4, $0D, $B5, $0E, $B5, $0F, $B5, $11, $B5, $12, $B6, $13, $B6, $15, $B7, $16, $B7, $18, $B8, $19, $B8, $1B, $B9, $1D, $B9, $1E, $BA, $20, $BB, $22, $BC, $23, $BD, $25, $BE, $27, $BF, $29, $C0, $2B, $C2, $2D, $C3, $2F, $C4, $31, $C6, $32, $C8, $34, $CA, $36, $CC, $38, $CE, $3A, $D0, $3C, $D2, $3E, $D4, $3F, $D7, $41, $DA, $43, $DC, $44, $DF, $45, $E2, $47, $E5, $48, $E8, $49, $EC, $4A, $EF, $4B, $F2, $4C, $F6, $4C, $F9, $4C, $FC, $4D, $00, $4D, $03, $4D, $07, $4C, $0A, $4C, $0E, $4C, $11, $4B, $14, $4A, $18, $49, $1B, $48, $1E, $47, $21, $45, $24, $44, $27, $42, $29, $41, $2C, $3F, $2E, $3D, $31, $3B, $33, $3A, $35, $38, $37, $36, $39, $34, $3A, $32, $3C, $30, $3E, $2E, $3F, $2C, $40, $2A, $41, $28, $43, $26, $44, $24, $45, $23, $45, $21, $46, $1F, $47, $1D, $48, $1C, $48, $1A, $49, $18, $49, $17, $4A, $15, $4A, $14, $4B, $12, $4B, $11, $4B, $0F, $4B, $0E, $4C, $0D, $4C, $0C, $4C, $0A, $4C, $09, $4C, $08, $4C, $07, $4D, $06, $4D, $05, $4D, $04, $4D, $03, $4D, $02, $4D, $01, $4D, $00

_6911:
.db $FE, $FF, $FF, $FF, $FF, $FF, $18, $1A, $18, $1A, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF
_6923:
.db $FE, $FF, $FF, $FF, $FF, $FF, $6C, $6E, $6E, $48, $FF, $FF, $FF, $FF
.db $FE, $FF, $FF, $FF, $FF, $FF, $6C, $6E, $6C, $6E, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$693F]___

;OBJECT: UNKNOWN
_693f:
	set     5,(ix+$18)
	ld      a,(ix+$15)
	cp      $aa
	jr      z,_698d
	xor     a
	ld      (ix+$11),a
	ld      (ix+$15),$aa
	ld      (ix+$16),a
	ld      (ix+$17),a
	bit     5,(iy+$00)
	jr      z,_698d
	ld      a,(S1_CURRENT_LEVEL)
	cp      $12
	jr      z,_698d
	ld      a,($d414)
	rlca    
	jr      c,_698d
	ld      a,($d2e8)
	ld      de,($d2e6)
	inc     de
	ld      c,a
	ld      hl,($d406)
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	ld      a,($d408)
	and     a
	jp      m,_698d
	cpl     
	add     hl,de
	adc     a,c
	ld      ($d406),hl
	ld      ($d408),a
_698d:
	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      de,_69be
	ld      bc,_69b7
	call    _7c41
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $18
	ret     c
	ld      (ix+$00),$ff
	ret     

_69b7:
.db $00, $08, $01, $08, $02, $08, $ff
_69be:
.db $74, $76, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $78, $7A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $7C, $7E, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$69E9]___

;OBJECT: wooden platform (Green Hill)
_69e9:
	set     5,(ix+$18)
	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      (ix+$0f),<_6911
	ld      (ix+$10),>_6911
	ld      a,($d408)
	and     a
	jp      m,_6a2e
	ld      hl,$0806
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_6a2e
	ld      de,$0000
	ld      a,(ix+$05)
	and     $1f
	cp      $10
	jr      nc,_6a1d
	ld      e,$80
_6a1d:
	ld      (ix+$0a),e
	ld      (ix+$0b),d
	ld      (ix+$0c),$00
	ld      bc,$0010
	call    _LABEL_7CC1_12
	ret   
_6a2e:  
	ld      c,$00
	ld      l,c
	ld      h,c
	ld      a,(ix+$05)
	and     $1f
	jr      z,_6a3d
	ld      hl,$ffc0
	dec     c
_6a3d:
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ret     

;____________________________________________________________________________[$6A47]___

;OBJECT: wooden platform - falling (Green Hill)
_6a47:
	set     5,(ix+$18)
	ld      a,(ix+$16)
	add     a,(ix+$17)
	ld      (ix+$17),a
	cp      $18
	jr      c,_6a6f
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0040
	add     hl,de
	adc     a,d
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
_6a6f:
	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      a,($d408)
	and     a
	jp      m,_6a99
	ld      hl,$0806
	ld      ($d214),hl
	call    _LABEL_3956_11
	jr      c,_6a99
	ld      (ix+$16),$01
	ld      bc,$0010
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	call    _LABEL_7CC1_12
_6a99:
	ld      hl,$6911
	ld      a,(S1_LEVEL_SOLIDITY)
	and     a
	jr      z,_6aa5
	ld      hl,_6923
_6aa5:
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,($d25d)
	ld      de,$00c0
	add     hl,de
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	and     a
	sbc     hl,de
	ret     nc
	ld      (ix+$00),$ff
	ret     

;____________________________________________________________________________[$6AC1]___

;OBJECT: UNKNOWN
_6ac1:
	set     5,(ix+$18)
	ld      (ix+$0d),$02
	ld      (ix+$0e),$02
	ld      hl,$0303
	ld      ($d214),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      e,(ix+$13)
	ld      d,(ix+$14)
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      ($d20e),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      ($d210),hl
	ld      hl,$0000
	ld      ($d212),hl
	ld      ($d214),hl
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,_6b72
	ld      a,(S1_CURRENT_LEVEL)
	cp      $05
	jr      z,_6b26
	cp      $0b
	jr      z,_6b26
	ld      hl,_6b70
_6b26:
	ld      a,($d223)
	and     $01
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      a,(hl)
	call    _3581
	ld      c,(ix+$02)
	ld      b,(ix+$03)
	ld      l,c
	ld      h,b
	ld      de,$fff8
	add     hl,de
	ld      de,($d25a)
	and     a
	sbc     hl,de
	jr      c,_6b6b
	inc     d
	ex      de,hl
	sbc     hl,bc
	jr      c,_6b6b
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	ld      l,c
	ld      h,b
	ld      de,$0010
	add     hl,de
	ld      de,($d25d)
	and     a
	sbc     hl,de
	jr      c,_6b6b
	ld      hl,$00c0
	add     hl,de
	and     a
	sbc     hl,bc
	ret     nc
_6b6b:
	ld      (ix+$00),$ff
	ret   

_6b70:
.db $06, $08
_6b72:
.db $34, $36

;____________________________________________________________________________[$6B74]___

;OBJECT: badnick - buzz bomber
_6b74:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,_6bab
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      (ix+$14),e
	ld      (ix+$15),d
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      (ix+$12),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      hl,($d25a)
	ld      bc,$0100
	add     hl,bc
	sbc     hl,de
	ret     nc
	set     0,(ix+$18)
_6bab:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$20
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,($d3fe)
	and     a
	sbc     hl,de
	jr      c,_6bd4
	ld      de,$0040
	sbc     hl,de
	jr      nc,_6bd4
	ld      a,(ix+$12)
	cp      $05
	jr      nc,_6bd4
	ld      (ix+$12),$05
_6bd4:
	ld      e,(ix+$12)
	ld      d,$00
_6bd9:
	ld      hl,$6cd7
	add     hl,de
	ld      ($d214),hl
	ld      a,(hl)
	and     a
	jr      nz,_6beb
	ld      (ix+$12),a
	ld      e,a
	jp      _6bd9
_6beb:
	dec     a
	jr      nz,_6c20
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0030
	add     hl,de
	ld      de,($d25a)
	xor     a
	sbc     hl,de
	jr      nc,_6c18
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      a,(ix+$14)
	ld      (ix+$02),a
	ld      a,(ix+$15)
	ld      (ix+$03),a
	res     0,(ix+$18)
	ret   
_6c18:  
	ld      c,$ff
	ld      hl,$fe00
	jp      _6c98
_6c20:
	dec     a
	jr      nz,_6c2a
	ld      c,$00
	ld      l,c
	ld      h,c
	jp      _6c98
_6c2a:
	ld      a,(ix+$11)
	cp      $20
	jp      nz,_6ca1
	call    _7c7b
	jp      c,_6ca1
	push    bc
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$0d
	ld      (ix+$01),a
	ld      (ix+$02),e
	ld      (ix+$03),d
	ld      (ix+$04),a
	ld      hl,$0020
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$13),a
	ld      (ix+$14),a
	ld      (ix+$15),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$07),$00
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      (ix+$0a),$80
	ld      (ix+$0b),$01
	ld      (ix+$0c),a
	pop     ix
	pop     bc
	ld      a,$0a
	rst     $28
	ld      c,$00
	ld      l,c
	ld      h,c
_6c98:
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
_6ca1:
	ld      l,(ix+$11)
	ld      h,(ix+$12)
	ld      de,$0008
	add     hl,de
	ld      (ix+$11),l
	ld      (ix+$12),h
	ld      hl,($d214)
	ld      a,(hl)
	add     a,a
	ld      e,a
	ld      hl,_6ce2
	add     hl,de
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	ld      de,_6cf9
	call    _7c41
	ld      hl,$1000
	ld      ($d214),hl
	call    _LABEL_3956_11
	ld      hl,$1004
	ld      ($d20e),hl
	call    nc,_35e5
	ret     

_6cd7:
.db $01, $01, $01, $01, $00, $02, $02, $03, $01, $01, $00
_6ce2:
.db $EA, $6C, $EA, $6C, $EF, $6C, $F4, $6C, $00, $02, $01, $02, $FF, $02, $02, $03, $02, $FF, $04, $02, $05, $02, $FF
_6cf9:
.db $FE, $0A, $FF, $FF, $FF, $FF, $0C, $0E, $10, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FE, $FF, $FF, $FF, $FF, $FF, $0C, $0E, $2C, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FE, $0A, $FF, $FF, $FF, $FF, $12, $14, $16, $FF, $FF, $FF, $32, $34, $FF, $FF, $FF, $FF, $FE, $FF, $FF, $FF, $FF, $FF, $12, $14, $16, $FF, $FF, $FF, $32, $34, $FF, $FF, $FF, $FF, $FE, $0A, $FF, $FF, $FF, $FF, $12, $14, $16, $FF, $FF, $FF, $30, $34, $FF, $FF, $FF, $FF, $FE, $FF, $FF, $FF, $FF, $FF, $12, $14, $16, $FF, $FF, $FF, $30, $34, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$6D65]___

;OBJECT: wooden platform - moving (Green Hill)
_6d65:
	set     5,(ix+$18)
	ld      a,(S1_CURRENT_LEVEL)
	cp      $07
	jr      z,_6d88
	ld      hl,$0020
	ld      ($d267),hl
	ld      hl,$0048
	ld      ($d269),hl
	ld      hl,$0030
	ld      ($d26b),hl
	ld      hl,$0030
	ld      ($d26d),hl
_6d88:
	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      c,$00
	ld      a,($d408)
	and     a
	jp      m,_6db1
	ld      hl,$0806
	ld      ($d214),hl
	call    _LABEL_3956_11
	ld      c,$00
	jr      c,_6db1
	ld      bc,$0010
	ld      de,$0000
	call    _LABEL_7CC1_12
	ld      c,$01
_6db1:
	ld      l,(ix+$12)
	ld      h,(ix+$13)
	inc     hl
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      de,$00a0
	xor     a
	sbc     hl,de
	jr      c,_6dcf
	ld      (ix+$12),a
	ld      (ix+$13),a
	inc     (ix+$14)
_6dcf:
	ld      de,$0001
	bit     0,(ix+$14)
	jr      z,_6ddb
	ld      de,$ffff
_6ddb:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,c
	and     a
	jr      z,_6df3
	ld      hl,($d3fe)
	add     hl,de
	ld      ($d3fe),hl
_6df3:
	ld      hl,$6911
	ld      a,(S1_LEVEL_SOLIDITY)
	and     a
	jr      z,_6e05
	ld      hl,$6931
	dec     a
	jr      z,_6e05
	ld      hl,_6923
_6e05:
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ret     

;____________________________________________________________________________[$6E0C]___

;OBJECT: badnick - motobug
_6e0c:
	res     5,(ix+$18)
	ld      (ix+$0d),$0a
	ld      (ix+$0e),$10
	ld      e,(ix+$12)
	ld      d,$00
_6e1d:
	ld      hl,_6e96
	add     hl,de
	ld      ($d214),hl
	ld      a,(hl)
	and     a
	jr      nz,_6e2f
	ld      (ix+$12),a
	ld      e,a
	jp      _6e1d
_6e2f:
	dec     a
	jr      nz,_6e3a
	ld      c,$ff
	ld      hl,$ff00
	jp      _6e49
_6e3a:
	dec     a
	jr      nz,_6e45
	ld      c,$00
	ld      hl,$0100
	jp      _6e49
_6e45:
	ld      c,$00
	ld      l,c
	ld      h,c
_6e49:
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
	ld      l,(ix+$11)
	ld      h,(ix+$12)
	ld      de,$0008
	add     hl,de
	ld      (ix+$11),l
	ld      (ix+$12),h
	ld      (ix+$0a),$00
	ld      (ix+$0b),$02
	ld      (ix+$0c),$00
	ld      hl,($d214)
	ld      a,(hl)
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_6eb1
	add     hl,de
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	ld      de,_6ecb
	call    _7c41
	ld      hl,$0203
	ld      ($d214),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      ($d20e),hl
	call    nc,_35e5
	ret     

_6e96
.db $01, $01, $01, $01, $01, $01, $01, $01, $01, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $02, $02, $02, $04, $04, $04, $04, $00  
_6eb1:
.db $BB, $6E, $BB, $6E, $C0, $6E, $C5, $6E, $C8, $6E, $00, $08, $01, $08, $FF, $02, $08, $03, $08, $FF, $00, $FF, $FF, $02, $FF, $FF
_6ecb:
.db $60, $62, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $64, $66, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $68, $6A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $6C, $6E, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$6F08]___

;OBJECT: badnick - newtron
_6f08:
	set     5,(ix+$18)
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$14
	ld      a,(ix+$11)
	cp      $02
	jr      z,_6f1e
	and     a
	jr      nz,_6f42
_6f1e:
	ld      a,($d223)
	and     $01
	jr      z,_6f2a
	ld      bc,$0000
	jr      _6f2d
_6f2a:
	ld      bc,_6fed
_6f2d:
	inc     (ix+$17)
	ld      a,(ix+$17)
	cp      $3c
	jp      c,_6fd4
	ld      (ix+$17),$00
	inc     (ix+$11)
	jp      _6fd4
_6f42:
	cp      $01
	jp      nz,_6fc1
	inc     (ix+$17)
	ld      a,(ix+$17)
	cp      $64
	jr      nz,_6fb1
	call    _7c7b
	jp      c,_6fb1
	push    bc
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$0d
	ld      (ix+$01),a
	ld      (ix+$02),e
	ld      (ix+$03),d
	ld      (ix+$04),a
	ld      hl,$0006
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$13),a
	ld      (ix+$14),a
	ld      (ix+$15),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$07),$00
	ld      (ix+$08),$fe
	ld      (ix+$09),$ff
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	pop     ix
	pop     bc
	ld      a,$0a
	rst     $28
_6fb1:
	ld      bc,_6fed
	cp      $78
	jr      c,_6fd4
	ld      (ix+$17),$00
	inc     (ix+$11)
	jr      _6fd4
_6fc1:
	cp      $03
	jr      nz,_6fd4
	ld      bc,$0000
	inc     (ix+$17)
	ld      a,(ix+$17)
	and     a
	jr      nz,_6fd4
	ld      (ix+$11),c
_6fd4:
	ld      (ix+$0f),c
	ld      (ix+$10),b
	ld      hl,$0202
	ld      ($d214),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      ($d20e),hl
	call    nc,_35e5
	ret   

_6fed:  
.db $1C, $1E, $FF, $FF, $FF, $FF, $FE, $3E, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $40
_7000:
.db $42, $FF, $FF, $FF, $FF, $FE, $62, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$700C]___

;OBJECT: boss (Green Hill)
_700c:
	set     5,(ix+$18)
	ld      (ix+$0d),$20
	ld      (ix+$0e),$1c
	call    _7ca6
	bit     0,(ix+$11)
	jr      nz,_7063
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$fff8
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	
	;boss sprite set
	ld      hl,$aeb1
	ld      de,$2000
	ld      a,9
	call    decompressArt
	
	ld      hl,S1_BossPalette
	ld      a,$02
	call    loadPaletteOnInterrupt
	ld      a,$0b
	rst     $18
	xor     a
	ld      ($d2ec),a
	ld      (ix+$12),a
	ld      (ix+$14),$a1
	ld      (ix+$15),$72
	ld      hl,$0760
	ld      de,$00e8
	call    _7c8c
	set     0,(ix+$11)
_7063:
	ld      a,(ix+$13)
	and     $3f
	ld      e,a
	ld      d,$00
	ld      hl,$7261
	add     hl,de
	ld      a,(hl)
	and     a
	jp      p,_7078
	ld      c,$ff
	jr      _707a
_7078:
	ld      c,$00
_707a:
	ld      (ix+$0a),a
	ld      (ix+$0b),c
	ld      (ix+$0c),c
_7083:
	ld      e,(ix+$12)
	ld      d,$00
	ld      l,(ix+$14)
	ld      h,(ix+$15)
	add     hl,de
	ld      ($d214),hl
	ld      a,(hl)
	and     a
	jr      nz,_709e
	inc     hl
	ld      a,(hl)
	ld      (ix+$12),a
	jp      _7083
_709e:
	dec     a
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_724b
	add     hl,de
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	jp      (hl)
	ld      hl,(S1_LEVEL_CROPLEFT)
	ld      de,$0006
	add     hl,de
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	ld      c,$ff
	ld      hl,$ff00
	jp      c,_7205
	ld      (ix+$12),$00
	bit     1,(ix+$11)
	jr      nz,_70dd
	ld      (ix+$14),$a4
	ld      (ix+$15),$72
	set     1,(ix+$11)
	jp      _7205
_70dd:
	ld      (ix+$14),$a7
	ld      (ix+$15),$72
	res     1,(ix+$11)
	jp      _7205
	ld      hl,(S1_LEVEL_CROPLEFT)
	ld      de,$00e0
	add     hl,de
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	ld      c,$00
	ld      hl,$0100
	jp      nc,_7205
	ld      (ix+$12),$00
	bit     2,(ix+$11)
	jr      nz,_711d
	ld      (ix+$14),$a1
	ld      (ix+$15),$72
	set     2,(ix+$11)
	jp      _7205
_711d:
	ld      (ix+$14),$aa
	ld      (ix+$15),$72
	res     2,(ix+$11)
	jp      _7205
	ld      (ix+$0a),$60
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
	ld      hl,($d25d)
	ld      de,$0074
	add     hl,de
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	xor     a
	sbc     hl,de
	ld      c,a
	ld      l,c
	ld      h,c
	jp      nc,_7205
	ld      (ix+$12),$00
	ld      (ix+$14),$b0
	ld      (ix+$15),$72
	jp      _7205
	ld      c,$00
	ld      hl,$0400
	jp      _7205
	ld      (ix+$0a),$60
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
	ld      hl,($d25d)
	ld      de,$0074
	add     hl,de
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	xor     a
	sbc     hl,de
	ld      c,a
	ld      l,c
	ld      h,c
	jp      nc,_7205
	ld      (ix+$12),$00
	ld      (ix+$14),$bc
	ld      (ix+$15),$72
	jp      _7205
	ld      c,$ff
	ld      hl,$fc00
	jr      _7205
	ld      c,$00
	ld      l,c
	ld      h,c
	jr      _7205
	ld      c,$00
	ld      l,c
	ld      h,c
	ld      (ix+$14),$ad
	ld      (ix+$15),$72
	ld      (ix+$12),c
	ld      (ix+$13),c
	jr      _7205
	ld      (ix+$0a),$00
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
	ld      hl,($d25d)
	ld      de,$001a
	add     hl,de
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	xor     a
	sbc     hl,de
	ld      c,a
	ld      l,c
	ld      h,c
	jp      c,_7205
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,(S1_LEVEL_CROPLEFT)
	xor     a
	sbc     hl,de
	ld      c,a
	ld      l,c
	ld      h,c
	jr      c,_71f8
	ld      (ix+$14),$a1
	ld      (ix+$15),$72
	ld      (ix+$12),a
	jr      _7205
_71f8:
	ld      (ix+$14),$a4
	ld      (ix+$15),$72
	ld      (ix+$12),a
	jr      _7205
_7205:
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
	ld      hl,($d214)
	ld      e,(hl)
	ld      d,$00
	ld      hl,_72c8
	add     hl,de
	ld      a,(hl)
	ld      hl,_72f8
	and     a
	jr      z,_7222
	ld      hl,_730a
_7222:
	ld      e,a
	ld      a,(ix+$18)
	and     $fd
	or      e
	ld      (ix+$18),a
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,$0012
	ld      ($d216),hl
	call    _77be
	call    _79fa
	inc     (ix+$13)
	ld      a,(ix+$13)
	and     $0f
	ret     nz
	inc     (ix+$12)
	ret    

_724b: 
.db $AC, $70, $EC, $70, $2C, $71, $5D, $71, $65, $71, $96, $71, $9D, $71, $A3, $71, $B7, $71, $00, $00, $9D, $71, $00, $14, $28, $28, $3C, $3C, $3C, $50, $50, $50, $50, $64, $64, $64, $64, $64, $64, $64, $64, $64, $64, $50, $50, $50, $50, $3C, $3C, $3C, $28, $28, $14, $00, $00, $EC, $D8, $D8, $C4, $C4, $C4, $B0, $B0, $B0, $B0, $9C, $9C, $9C, $9C, $9C, $9C, $9C, $9C, $9C, $9C, $B0, $B0, $B0, $B0, $C4, $C4, $C4, $D8, $D8, $EC, $00, $01, $00, $00, $02, $00, $00, $03, $00, $00, $05, $00, $00, $09, $00, $00, $07, $07, $07, $07, $04, $04, $04, $04, $04, $08, $00, $00, $0B, $0B, $0B, $0B, $06, $06, $06, $06, $06, $08, $00, $00   
_72c8:
.db $00, $00, $02, $02, $02, $00, $00, $02, $02, $00, $02, $00, $00, $00, $01, $04, $01, $00, $01, $04, $01, $01, $01, $04, $01, $01, $01, $04, $01, $FF, $02, $02, $01, $05, $01, $02, $01, $05, $01, $03, $01, $05, $01, $03, $01, $05, $01, $FF
_72f8:
.db $20, $22, $24, $26, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF
_730a:
.db $2A, $2C, $2E, $30, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $6C, $6E, $70, $72, $FF

S1_BossPalette:				;[$731C]
.db $38, $20, $35, $1B, $16, $2A, $00, $3F, $15, $3A, $0F, $03, $01, $02, $3E, $00   

;____________________________________________________________________________[$732C]___

;OBJECT: capsule
_732c:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,_734a
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0010
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	set     0,(ix+$18)
_734a:
	ld      (ix+$0d),$1c
	ld      (ix+$0e),$40
	ld      hl,_7564
	bit     1,(ix+$18)
	jr      z,_735e
	ld      hl,_757c
_735e:
	ld      a,($d223)
	rrca    
	jr      nc,_7368
	ld      de,$000c
	add     hl,de
_7368:
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	ld      ($d2ab),hl
	ex      de,hl
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	ld      ($d2af),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,bc
	ld      ($d2ad),hl
	ld      hl,_752e
	ld      a,($d223)
	and     $10
	jr      z,_7396
	ld      hl,_7552
_7396:
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,($d25a)
	ld      (S1_LEVEL_CROPLEFT),hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$ff90
	add     hl,de
	ld      ($d275),hl
	ld      hl,$0002
	ld      ($d214),hl
	call    _LABEL_3956_11
	jp      c,_745b
	ld      a,($d408)
	and     a
	jp      m,_745b
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,($d401)
	and     a
	sbc     hl,de
	jr      c,_73f6
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0010
	add     hl,de
	ld      de,$ffea
	ld      bc,($d3fe)
	and     a
	sbc     hl,bc
	jr      nc,_73e9
	ld      de,$001d
_73e9:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      ($d3fe),hl
	jp      _7452
_73f6:
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      c,l
	ld      b,h
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	ret     c
	ex      de,hl
	ld      de,$0020
	add     hl,de
	and     a
	sbc     hl,bc
	ret     c
	ld      a,c
	and     $1f
	ld      c,a
	ld      b,$00
	ld      hl,_750e
	add     hl,bc
	ld      c,(hl)
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffe0
	add     hl,de
	add     hl,bc
	ld      ($d401),hl
	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
	ld      hl,$d414
	set     7,(hl)
	ld      a,c
	cp      $03
	ret     nz
	ld      (ix+$0f),<_7540
	ld      (ix+$10),>_7540
	bit     1,(iy+$06)
	jr      nz,_7460
	set     1,(iy+$06)
_7452:
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
_745b:
	bit     1,(iy+$06)
	ret     z
_7460:
	ld      a,(ix+$12)
	cp      $08
	jr      nc,_747b
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $14
	ret     c
	ld      (ix+$11),$00
	call    _7a3a
	inc     (ix+$12)
	ret     
_747b:
	bit     1,(ix+$18)
	jr      nz,_748d
	ld      a,$a0
	ld      ($d289),a
	ld      a,$09
	rst     $18
	set     1,(ix+$18)
_748d:
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	res     5,(iy+$00)
	ld      a,($d223)
	and     $0f
	ret     nz
	call    _LABEL_625_57
	and     $01
	add     a,$23
	call    _74b6
	inc     (ix+$16)
	ld      a,(ix+$16)
	cp      $0c
	ret     c
	ld      (ix+$00),$ff
	ret     

_74b6:
	ld      ($d216),a
	call    _7c7b
	ret     c
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	ld      a,($d216)
	ld      (ix+$00),a
	xor     a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$01),a
	ld      hl,$0008
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,$001a
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	call    _LABEL_625_57
	ld      (ix+$0a),a
	call    _LABEL_625_57
	and     $01
	inc     a
	inc     a
	neg     
	ld      (ix+$0b),a
	ld      (ix+$0c),$ff
	pop     ix
	ret    

_750e:
.db $15, $12, $11, $10, $10, $0F, $0E, $0D, $03, $03, $03, $03, $03, $03, $03, $03
.db $03, $03, $03, $03, $03, $03, $03, $03, $0D, $0E, $0F, $10, $10, $11, $12, $15
_752e:
.db $00, $02, $04, $06, $FF, $FF, $20, $22, $24, $26, $FF, $FF, $40, $42, $44, $46
.db $FF, $FF
_7540:
.db $00, $08, $0A, $06, $FF, $FF, $20, $22, $24, $26, $FF, $FF, $40, $42, $44, $46
.db $FF, $FF
_7552:
.db $00, $68, $6A, $06, $FF, $FF, $20, $22, $24, $26, $FF, $FF, $40, $42, $44, $46
.db $FF, $FF
_7564:
.db $00, $00, $30, $00, $60, $19, $62, $19, $61, $19, $63, $19, $10, $00, $30, $00
.db $64, $19, $66, $19, $65, $19, $67, $19
_757c:
.db $00, $00, $20, $00, $00, $00, $00, $00, $49, $19, $4B, $19, $10, $00, $20, $00
.db $00, $00, $00, $00, $4D, $19, $4F, $19

;____________________________________________________________________________[$7594]___

;OBJECT: free animal - bird
_7594:
	res     5,(ix+$18)
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$10
	bit     7,(ix+$18)
	jr      z,_75b2
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fd
	ld      (ix+$0c),$ff
_75b2:
	ld      de,$0012
	ld      a,(S1_LEVEL_SOLIDITY)
	cp      $03
	jr      nz,_75bf
	ld      de,$0038
_75bf:
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	add     hl,de
	adc     a,$00
	ld      c,a
	jp      m,_75d9
	ld      a,h
	cp      $02
	jr      c,_75d9
	ld      hl,$0200
	ld      c,$00
_75d9:
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      hl,$fe00
	ld      a,(S1_LEVEL_SOLIDITY)
	cp      $03
	jr      nz,_75ef
	ld      hl,$fe80
_75ef:
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),$ff
	ld      bc,_7629
	ld      a,(S1_LEVEL_SOLIDITY)
	and     a
	jr      z,_760c
	ld      bc,_762e
	cp      $03
	jr      nz,_760c
	ld      bc,_7633
_760c:
	ld      de,_7638
	call    _7c41
_7612:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0010
	add     hl,de
	ld      de,($d25a)
	and     a
	sbc     hl,de
	ret     nc
	ld      (ix+$00),$ff
	ret 
	
_7629:
.db $00, $02, $01, $02, $ff
_762e:
.db $02, $04, $03, $04, $ff
_7633:
.db $04, $03, $05, $03, $ff
_7638:
.db $10, $12, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $6E, $0E, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $28, $2A, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $2C, $2E, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $30, $32, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $50, $52, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$7699]___

;OBJECT: free animal - rabbit
_7699:
	res     5,(ix+$18)
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$20
	ld      hl,_7760
	ld      a,(S1_LEVEL_SOLIDITY)
	and     a
	jr      z,_76bd
	ld      hl,_777b
	dec     a
	jr      z,_76bd
	ld      hl,$7796
	dec     a
	jr      z,_76bd
	ld      hl,_77b1
_76bd:
	ld      (ix+$0f),l
	ld      (ix+$10),h
	bit     7,(ix+$18)
	jr      z,_7719
	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),$01
	ld      (ix+$0c),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      hl,_7752
	ld      a,(S1_LEVEL_SOLIDITY)
	ld      c,a
	and     a
	jr      z,_76f6
	ld      hl,_776d
	dec     a
	jr      z,_76f6
	ld      hl,_7788
	dec     a
	jr      z,_76f6
	ld      hl,_77a3
_76f6:
	ld      (ix+$0f),l
	ld      (ix+$10),h
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $08
	ret     c
	ld      hl,$fffc
	ld      a,c
	and     a
	jr      z,_770f
	ld      hl,$fffe
_770f:
	ld      (ix+$0a),$00
	ld      (ix+$0b),l
	ld      (ix+$0c),h
_7719:
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0028
	add     hl,de
	adc     a,$00
	ld      c,a
	jp      m,_7736
	ld      a,h
	cp      $02
	jr      c,_7736
	ld      hl,$0200
	ld      c,$00
_7736:
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      (ix+$07),$80
	ld      (ix+$08),$fe
	ld      (ix+$09),$ff
	ld      (ix+$11),$00
	jp      _7612

_7752:
.db $70, $72, $FF, $FF, $FF, $FF, $54, $56, $FF, $FF, $FF, $FF, $FF, $FF
_7760:
.db $5C, $5E, $FF, $FF, $FF, $FF, $58, $5A, $FF, $FF, $FF, $FF, $FF
_776d:
.db $FE, $FF, $FF, $FF, $FF, $FF, $34, $36, $FF, $FF, $FF, $FF, $FF, $FF
_777b:
.db $FE, $FF, $FF, $FF, $FF, $FF, $38, $3A, $FF, $FF, $FF, $FF, $FF
_7788:
.db $FE, $FF, $FF, $FF, $FF, $FF, $3C, $3E, $FF, $FF, $FF, $FF, $FF, $FF, $FE, $FF, $FF, $FF, $FF, $FF, $1C, $1E, $FF, $FF, $FF, $FF, $FF
_77a3:
.db $FE, $FF, $FF, $FF, $FF, $FF, $14, $16, $FF, $FF, $FF, $FF, $FF, $FF
_77b1:
.db $FE, $FF, $FF, $FF, $FF, $FF, $18, $1A, $FF, $FF, $FF, $FF, $FF

_77be:
	ld      a,($d2ec)
	cp      $08
	jr      nc,_7841
	ld      a,($d2b1)
	and     a
	jp      nz,_7821
	ld      hl,$0c08
	ld      ($d214),hl
	call    _LABEL_3956_11
	ret     c
	bit     0,(iy+$05)
	ret     nz
	ld      a,($d414)
	rrca    
	jr      c,_77e6
	and     $02
	jp      z,_35fd
_77e6:
	ld      de,$0001
	ld      hl,($d406)
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	ld      a,($d408)
	cpl     
	add     hl,de
	adc     a,$00
	ld      ($d406),hl
	ld      ($d408),a
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
	ld      a,$18
	ld      ($d2b1),a
	ld      a,$8f
	ld      ($d2b2),a
	ld      a,$3f
	ld      ($d2b3),a
	ld      a,$01
	rst     $28
	ld      a,($d2ec)
	inc     a
	ld      ($d2ec),a
_7821:
	ld      hl,($d216)
	ld      de,_7922
	add     hl,de
	bit     1,(ix+$18)
	jr      z,_7832
	ld      de,$0012
	add     hl,de
_7832:
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,$d2ed
	ld      (hl),$18
	inc     hl
	ld      (hl),$00
	ret     
_7841:
	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      de,$0024
	ld      hl,($d216)
	bit     1,(ix+$18)
	jr      z,_7863
	ld      de,$0036
_7863:
	add     hl,de
	ld      de,_7922
	add     hl,de
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,$d2ee
	ld      a,(hl)
	cp      $0a
	jp      nc,_7882
	dec     hl
	dec     (hl)
	ret     nz
	ld      (hl),$18
	inc     hl
	inc     (hl)
	call    _7a3a
	ret     
_7882:
	ld      a,($d2ee)
	cp      $3a
	jr      nc,_78a1
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      a,(ix+$06)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      (ix+$04),l
	ld      (ix+$05),h
	ld      (ix+$06),a
_78a1:
	ld      hl,$d2ee
	ld      a,(hl)
	cp      $5a
	jr      nc,_78ab
	inc     (hl)
	ret     
_78ab:
	jr      nz,_78c0
	ld      (hl),$5b
	ld      a,($d2fc)
	rst     $18
	ld      a,(iy+$0a)
	res     0,(iy+$00)
	call    wait
	ld      (iy+$0a),a
_78c0:
	ld      (ix+$07),$00
	ld      (ix+$08),$03
	ld      (ix+$09),$00
	ld      (ix+$0a),$60
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
	ld      (ix+$0f),<_7922
	ld      (ix+$10),>_7922
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,($d25a)
	inc     d
	and     a
	sbc     hl,de
	ret     c
	ld      (ix+$00),$ff
	ld      hl,$2000
	ld      ($d275),hl
	ld      hl,$0000
	ld      ($d27b),hl
	set     5,(iy+$00)
	set     0,(iy+$02)
	res     1,(iy+$02)
	ld      a,(S1_CURRENT_LEVEL)
	cp      $0b
	jr      nz,_7916
	set     1,(iy+$09)
_7916:	
	;UNKNOWN
	ld      hl,$da28
	ld      de,$2000
	ld      a,12
	call    decompressArt
	ret
    
_7922:
.db $2A, $2C, $2E, $30, $32, $FF, $4A, $4C, $4E, $50, $52, $FF, $6A, $6C, $6E, $70, $72, $FF, $20, $10, $12, $14, $28, $FF, $40, $42, $44, $46, $48, $FF, $60, $62, $64, $66, $68, $FF, $2A, $16, $18, $1A, $32, $FF, $4A, $4C, $4E, $50, $52, $FF, $6A, $6C, $6E, $70, $72, $FF, $20, $3A, $3C, $3E, $28, $FF, $40, $42, $44, $46, $48, $FF, $60, $62, $64, $66, $68, $FF, $2A, $34, $36, $38, $32, $FF, $4A, $4C, $4E, $50, $52, $FF, $6A, $6C, $6E, $70, $72, $FF, $20, $10, $12, $14, $28, $FF, $40, $42, $44, $46, $48, $FF, $60, $54, $56, $66, $68, $FF, $2A, $16, $18, $1A, $32, $FF, $4A, $4C, $4E, $50, $52, $FF, $6A, $5A, $5C, $70, $72, $FF, $20, $3A, $3C, $3E, $28, $FF, $40, $42, $44, $46, $48, $FF, $60, $54, $56, $66, $68, $FF, $2A, $34, $36, $38, $32, $FF, $4A, $4C, $4E, $50, $52, $FF, $6A, $5A, $5C, $70, $72, $FF, $20, $06, $08, $0A, $28, $FF, $40, $42, $44, $46, $48, $FF, $60, $62, $64, $66, $68, $FF, $20, $06, $08, $0A, $28, $FF, $40, $42, $44, $46, $48, $FF, $60, $62, $64, $66, $68, $FF, $0E, $10, $12, $14, $16, $FF, $40, $42, $44, $46, $48, $FF, $60, $62, $64, $66, $68, $FF

_79fa:
	ld      a,(ix+$07)
	or      (ix+$08)
	ret     z
	ld      a,($d223)
	bit     0,a
	ret     nz
	and     $02
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      ($d20e),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      ($d210),hl
	ld      hl,$fff8
	ld      de,$0010
	ld      c,$04
	bit     7,(ix+$09)
	jr      z,_7a2e
	ld      hl,$0028
	ld      c,$00
_7a2e:
	ld      ($d212),hl
	ld      ($d214),de
	add     a,c
	call    _3581
	ret     

_7a3a:
	call    _7c7b
	ret     c
	push    hl
	call    _LABEL_625_57
	and     $1f
	ld      l,a
	ld      h,$00
	ld      ($d20e),hl
	call    _LABEL_625_57
	and     $1f
	ld      l,a
	ld      h,$00
	ld      ($d210),hl
	pop     hl
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$0a
	ld      (ix+$01),a
	ld      hl,($d20e)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,($d210)
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	pop     ix
	ld      a,$01
	rst     $28
	ret     
	set     5,(ix+$18)
	ld      (ix+$0d),$40
	ld      (ix+$0e),$40
	ld      hl,$0000
	ld      ($d214),hl
	call    _LABEL_3956_11
	ret     c
	bit     6,(iy+$06)
	ret     nz
	ld      a,($d414)
	and     $80
	ret     z
	ld      hl,$fffb
	xor     a
	ld      ($d406),a
	ld      ($d407),hl
	ld      hl,$0003
	xor     a
	ld      ($d403),a
	ld      ($d404),hl
	ld      hl,$d414
	res     1,(hl)
	set     6,(iy+$06)
	ld      (iy+$03),$ff
	ld      a,$11
	rst     $28
	ret     
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,_7b03
	ld      (ix+$11),$32
	ld      (ix+$12),$00
	set     0,(ix+$18)
_7b03:
	ld      bc,$0000
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      ($d2ab),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      a,($d223)
	rrca    
	jr      nc,_7b20
	ld      de,$0010
	add     hl,de
	inc     bc
_7b20:
	ld      ($d2ad),hl
	ld      a,(ix+$12)
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_7b85
	add     hl,de
	push    hl
	add     hl,bc
	ld      a,(hl)
	add     a,a
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_7b5d
	add     hl,de
	ld      ($d2af),hl
	pop     hl
	inc     hl
	inc     hl
	ld      a,($d223)
	rrca    
	ret     c
	dec     (ix+$11)
	ret     nz
	ld      a,(hl)
	ld      (ix+$11),a
	inc     (ix+$12)
	ld      a,(ix+$12)
	cp      $04
	ret     c
	ld      (ix+$12),$00
	ret  

_7b5d:   
.db $00, $00, $00, $00, $00, $00, $00, $00, $F0, $00, $F1, $00, $E2, $00, $F2, $00, $00, $00, $00, $00, $F0, $00, $F1, $00, $E2, $00, $F2, $00, $2E, $00, $2F, $00, $2E, $00, $2F, $00, $2E, $00, $2F, $00  
_7b85:
.db $00, $01, $08, $00, $02, $03, $78, $00, $01, $04, $08, $00, $02, $03, $78, $00

_7b95  
	set     5,(ix+$18)
	set     0,(iy+$09)
	ld      a,($d223)
	and     $01
	jp      z,_7bc2
	ld      a,(ix+$12)
	ld      c,a
	add     a,a
	add     a,c
	ld      c,a
	ld      b,$00
	ld      hl,_7c17
	add     hl,bc
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      a,(hl)
	ld      (ix+$0f),e
	ld      (ix+$10),d
	ld      ($d302),a
	jr      _7bc8
_7bc2:
	ld      (ix+$0f),a
	ld      (ix+$10),a
_7bc8:
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,($d25d)
	inc     h
	xor     a
	sbc     hl,de
	jr      nc,_7bf8
	ld      (ix+$00),$ff
	res     0,(iy+$09)
	ret     
_7bf8:
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	dec     (ix+$11)
	ret     nz
	ld      (ix+$11),$06
	inc     (ix+$12)
	ld      a,(ix+$12)
	cp      $06
	ret     c
	ld      (ix+$12),$00
	ret     

_7c17:
.db <_7c29, >_7c29, $1C
.db <_7c31, >_7c31, $1C
.db <_7c39, >_7c39, $1C
.db <_7c29, >_7c29, $1D
.db <_7c31, >_7c31, $1D
.db <_7c39, >_7c39, $1D
_7c29:
.db $B4, $B6, $FF, $FF, $FF, $FF, $FF, $FF
_7c31:
.db $B8, $BA, $FF, $FF, $FF, $FF, $FF, $FF
_7c39:
.db $BC, $BE, $FF, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$7C41]___

;DE : e.g. $7de1
;BC : e.g. $7ddc
_7c41:
	ld      l,(ix+$17)

-	ld      h,$00
	add     hl,bc
	ld      a,(hl)
	cp      $ff
	jr      nz,_7c54
	ld      l,$00
	ld      (ix+$17),l
	jp      -
_7c54:
	inc     hl
	push    hl
	ld      l,a
	ld      h,$00
	add     hl,hl
	ld      c,l
	ld      b,h
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,bc
	add     hl,de
	ld      (ix+$0f),l
	ld      (ix+$10),h
	pop     hl
	inc     (ix+$16)
	ld      a,(hl)
	cp      (ix+$16)
	ret     nc
	ld      (ix+$16),$00
	inc     (ix+$17)
	inc     (ix+$17)
	ret     


;____________________________________________________________________________[$7C7B]___	

_7c7b:
	ld      hl,$d416
	ld      de,$001a
	ld      b,$1f
_7c83:
	ld      a,(hl)
	cp      $ff
	ret     z
	add     hl,de
	djnz    _7c83
	scf     
	ret     

_7c8c:
	ld      ($d27b),hl
	ld      ($d27d),de
	ld      hl,($d25a)
	ld      (S1_LEVEL_CROPLEFT),hl
	ld      ($d275),hl
	ld      hl,($d25d)
	ld      (S1_LEVEL_CROPTOP),hl
	ld      (S1_LEVEL_EXTENDHEIGHT),hl
	ret     

_7ca6:
	ld      hl,($d27b)
	ld      de,($d25a)
	and     a
	sbc     hl,de
	ret     nz
	ld      hl,($d27d)
	ld      de,($d25d)
	and     a
	sbc     hl,de
	ret     nz
	res     5,(iy+$00)
	ret 

_LABEL_7CC1_12:				;[$7CC1]
	bit  6, (iy+6)
	ret  nz
	ld   l, (ix+4)
	ld   h, (ix+5)
	xor  a
	bit  7, d
	jr   z, _LABEL_7CD2_13
	dec  a
_LABEL_7CD2_13:
	add  hl, de
	adc  a, (ix+6)
	ld   l, h
	ld   h, a
	add  hl, bc
	ld   a, ($D40A)
	ld   c, a
	xor  a
	ld   b, a
	sbc  hl, bc
	ld   ($D401), hl
	ld   a, ($D2E8)
	ld   hl, ($D2E6)
	ld   ($D406), hl
	ld   ($D408), a
	ld   hl, $D414
	set  7, (hl)
	ret

;____________________________________________________________________________[$7CF6]___

;OBJECT: badnick - chopper
_7cf6:
	set     5,(ix+$18)
	ld      (ix+$0d),$08
	ld      (ix+$0e),$0c
	ld      a,(ix+$14)
	and     a
	jr      z,_7d13
	dec     (ix+$14)
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ret     
_7d13:
	bit     0,(ix+$18)
	jr      nz,_7d5c
	bit     1,(ix+$18)
	jr      nz,_7d43
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$fff4
	add     hl,de
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0008
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	set     1,(ix+$18)
_7d43:
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fc
	ld      (ix+$0c),$ff
	set     0,(ix+$18)
	ld      a,$12
	rst     $28
	ld      (ix+$11),$03
	jr      _7daf
_7d5c:
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0010
	add     hl,de
	adc     a,$00
	ex      de,hl
	and     a
	jp      m,_7d7b
	ld      hl,$0400
	and     a
	sbc     hl,de
	jr      nc,_7d7b
	ld      de,$0400
_7d7b:
	ld      (ix+$0a),e
	ld      (ix+$0b),d
	ld      (ix+$0c),a
	ld      e,(ix+$12)
	ld      d,(ix+$13)
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	xor     a
	sbc     hl,de
	jr      c,_7daf
	ld      (ix+$04),a
	ld      (ix+$05),e
	ld      (ix+$06),d
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      (ix+$14),$1e
	res     0,(ix+$18)
_7daf:
	ld      de,_7de1
	ld      bc,_7ddc
	call    _7c41
	ld      a,(ix+$11)
	and     a
	jr      z,_7dc9
	dec     (ix+$11)
	ld      (ix+$0f),<_7df7
	ld      (ix+$10),>_7df7
_7dc9:
	ld      hl,$0204
	ld      ($d214),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      ($d20e),hl
	call    nc,_35e5
	ret     

_7ddc:
.db $00, $04, $01, $04, $FF
_7de1:
.db $60, $62, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $64, $66, $FF, $FF
_7df7:
.db $FF, $FF, $FF, $FF, $68, $6A, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$7E02]___

;OBJECT: log - vertical (Jungle)
_7e02:
	set     5,(ix+$18)
	ld      hl,$0030
	ld      ($d267),hl
	ld      hl,$0058
	ld      ($d269),hl
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$10
	ld      (ix+$0f),<_7e89
	ld      (ix+$10),>_7e89
	bit     0,(ix+$18)
	jr      nz,_7e3c
	ld      a,(ix+$05)
	ld      (ix+$12),a
	ld      a,(ix+$06)
	ld      (ix+$13),a
	ld      (ix+$14),$c0
	set     0,(ix+$18)
_7e3c:
	ld      (ix+$0a),$80
	xor     a

_LABEL_7E41_9:				;[$7E41]
	ld   (ix+11), a
	ld   (ix+12), a
	ld   a, ($D408)
	and  a
	jp   m, _LABEL_7E65_10
	ld   hl, $0806
	ld   ($D214), hl
	call _LABEL_3956_11
	jr   c, _LABEL_7E65_10
	ld   bc, $0010
	ld   e, (ix+10)
	ld   d, (ix+11)
	call _LABEL_7CC1_12
_LABEL_7E65_10:
	ld   a, ($D223)
	and  $03
	ret  nz
	inc  (ix+17)
	ld   a, (ix+17)
	cp   (ix+20)
	ret  c
	xor  a
	ld   (ix+17), a
	ld   (ix+4), a
	ld   a, (ix+18)
	ld   (ix+5), a
	ld   a, (ix+19)
	ld   (ix+6), a
	ret

_7e89:
.db $FE, $FF, $FF, $FF, $FF, $FF, $18, $1A, $FF, $FF, $FF, $FF, $28, $2E, $FF, $FF
.db $FF, $FF

_7e9b
	set     5,(ix+$18)
	ld      hl,$0030
	ld      ($d267),hl
	ld      hl,$0058
	ld      ($d269),hl
	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      (ix+$0f),<_7ed9
	ld      (ix+$10),>_7ed9
	bit     0,(ix+$18)
	jp      nz,_7e3c
	ld      a,(ix+$05)
	ld      (ix+$12),a
	ld      a,(ix+$06)
	ld      (ix+$13),a
	ld      (ix+$14),$c6
	set     0,(ix+$18)
	jp      _7e3c

_7ed9:
.db $FE, $FF, $FF, $FF, $FF, $FF, $6C, $6E, $6E, $48, $FF, $FF, $FF

_7ee6:
	set     5,(ix+$18)
	ld      (ix+$0d),$0a
	ld      (ix+$0e),$10
	bit     0,(ix+$18)
	jr      nz,_7f0c
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffe8
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	set     0,(ix+$18)
_7f0c:
	ld      (ix+$0a),$40
	xor     a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      a,(ix+$11)
	cp      $14
	jr      c,_7f2a
	ld      (ix+$0a),$c0
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
_7f2a:
	ld      a,($d408)
	and     a
	jp      m,_8003
	ld      hl,$0806
	ld      ($d214),hl
	call    _LABEL_3956_11
	jp      c,_8003
	ld      bc,$0010
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	call    _LABEL_7CC1_12
	ld      hl,($d403)
	ld      a,l
	or      h
	jr      z,_7f79
	ld      bc,$0012
	bit     7,h
	jr      z,_7f5a
	ld      bc,$fffe
_7f5a:
	ld      de,$0000
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,($d2d4)
	add     a,a
	ld      c,a
	ld      b,d
	ld      hl,S1_SolidityPointers
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	add     hl,de
	ld      a,(hl)
	and     $3f
	ld      a,d
	ld      e,d
	jr      nz,_7f85
_7f79:
	ld      a,($d403)
	ld      de,($d404)
	sra     d
	rr      e
	rra     
_7f85:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     a,(ix+$01)
	adc     hl,de
	ld      (ix+$01),a
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      ($d3fd),a
	ld      de,$fffc
	add     hl,de
	ld      ($d3fe),hl
	ld      de,($d403)
	bit     7,d
	jr      z,_7fb2
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
_7fb2:
	ld      l,(ix+$12)
	ld      h,(ix+$13)
	add     hl,de
	ld      a,h
	cp      $09
	jr      c,_7fc1
	sub     $09
	ld      h,a
_7fc1:
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      e,a
	ld      d,$00
	ld      hl,_8019
	add     hl,de
	ld      e,(hl)
	ld      hl,_8022
	add     hl,de
	ld      (ix+$0f),l
	ld      (ix+$10),h
	jr      _800b

.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.db $00, $00, $00, $00, $00

;could someone explain why this isn't calculating the right checksum?
 ;the compiled output of this file is byte-for-byte the same as the original ROM!
;.SMSTAG

.db "TMR SEGA"

.db $59, $59
.db $1B, $A5
.db $76, $70, $00
.db $40

;======================================================================================

.BANK 2 SLOT 2

.ORGA $8000
.db $00, $00, $00

_8003:   
	ld      (ix+$0f),<_8022
	ld      (ix+$10),>_8022
_800b:
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $28
	ret     c
	ld      (ix+$11),$00
	ret     

_8019:
.db $00, $00, $00, $12, $12, $12, $24, $24, $24
_8022:
.db $FE, $FF, $FF, $FF, $FF, $FF, $3A, $3C, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FE, $FF, $FF, $FF, $FF, $FF, $36, $38, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FE, $FF, $FF, $FF, $FF, $FF, $4C, $4E, $FF, $FF, $FF, $FF, $FF

.ENDASM
_8053:
8053 ddcb18ee  set     5,(ix+$18)
8057 dd360d20  ld      (ix+$0d),$20
805b dd360e1c  ld      (ix+$0e),$1c
805f ddcb1846  bit     0,(ix+$18)
8063 204b      jr      nz,_80b0
8065 2a01d4    ld      hl,($d401)
8068 11e000    ld      de,$00e0
806b a7        and     a
806c ed52      sbc     hl,de
806e d0        ret     nc
806f 3a14d4    ld      a,($d414)
8072 07        rlca    
8073 d0        ret     nc
		;boss sprite set
8074 21b1ae    ld      hl,$aeb1
8077 110020    ld      de,$2000
807a 3e09      ld      a,9
807c cd0504    call    decompressArt

807f 211c73    ld      hl,S1_BossPalette
8082 3e02      ld      a,$02
8084 cd3303    call    loadPaletteOnInterrupt
8087 3e0b      ld      a,$0b
8089 df        rst     $18
808a af        xor     a
808b 32ecd2    ld      ($d2ec),a
808e 2a5ad2    ld      hl,($d25a)
8091 2273d2    ld      (S1_LEVEL_CROPLEFT),hl
8094 2275d2    ld      ($d275),hl
8097 2a5dd2    ld      hl,($d25d)
809a 2277d2    ld      (S1_LEVEL_CROPTOP),hl
809d 2279d2    ld      (S1_LEVEL_EXTENDHEIGHT),hl
80a0 21f001    ld      hl,$01f0
80a3 227bd2    ld      ($d27b),hl
80a6 214800    ld      hl,$0048
80a9 227dd2    ld      ($d27d),hl
80ac ddcb18c6  set     0,(ix+$18)
_80b0:
80b0 cda67c    call    _7ca6
80b3 ddcb1146  bit     0,(ix+$11)
80b7 202e      jr      nz,_80e7
80b9 dd360ff4  ld      (ix+$0f),<_81f4
80bd dd361081  ld      (ix+$10),>_81f4
80c1 dd360a80  ld      (ix+$0a),$80
80c5 dd360b00  ld      (ix+$0b),$00
80c9 dd360c00  ld      (ix+$0c),$00
80cd dd6e05    ld      l,(ix+$05)
80d0 dd6606    ld      h,(ix+$06)
80d3 115800    ld      de,$0058
80d6 af        xor     a
80d7 ed52      sbc     hl,de
80d9 d8        ret     c
80da dd770a    ld      (ix+$0a),a
80dd dd770b    ld      (ix+$0b),a
80e0 dd770c    ld      (ix+$0c),a
80e3 ddcb11c6  set     0,(ix+$11)
_80e7:
80e7 dd7e12    ld      a,(ix+$12)
80ea a7        and     a
80eb c24a81    jp      nz,_814a
80ee dd6e02    ld      l,(ix+$02)
80f1 dd6603    ld      h,(ix+$03)
80f4 ddcb114e  bit     1,(ix+$11)
80f8 2028      jr      nz,_8122
80fa dd360ff4  ld      (ix+$0f),$f4
80fe dd361081  ld      (ix+$10),$81
8102 ddcb188e  res     1,(ix+$18)
8106 dd360700  ld      (ix+$07),$00
810a dd3608ff  ld      (ix+$08),$ff
810e dd3609ff  ld      (ix+$09),$ff
8112 111c02    ld      de,$021c
8115 a7        and     a
8116 ed52      sbc     hl,de
8118 d2e781    jp      nc,_81e7
811b dd361267  ld      (ix+$12),$67
811f c3e781    jp      _81e7
_8122:
8122 dd360f06  ld      (ix+$0f),$06
8126 dd361082  ld      (ix+$10),$82
812a ddcb18ce  set     1,(ix+$18)
812e dd360700  ld      (ix+$07),$00
8132 dd360801  ld      (ix+$08),$01
8136 dd360900  ld      (ix+$09),$00
813a 11aa02    ld      de,$02aa
813d a7        and     a
813e ed52      sbc     hl,de
8140 dae781    jp      c,_81e7
8143 dd361267  ld      (ix+$12),$67
8147 c3e781    jp      _81e7
_814a:
814a af        xor     a
814b dd7707    ld      (ix+$07),a
814e dd7708    ld      (ix+$08),a
8151 dd7709    ld      (ix+$09),a
8154 210100    ld      hl,$0001
8157 dd3512    dec     (ix+$12)
815a 2812      jr      z,_816e
815c dd7e12    ld      a,(ix+$12)
815f fe40      cp      $40
8161 300e      jr      nc,_8171
8163 21ffff    ld      hl,$ffff
8166 fe28      cp      $28
8168 3807      jr      c,_8171
816a fe34      cp      $34
816c 280f      jr      z,_817d
_816e:
816e 210000    ld      hl,$0000
_8171:
8171 dd360a00  ld      (ix+$0a),$00
8175 dd750b    ld      (ix+$0b),l
8178 dd740c    ld      (ix+$0c),h
817b 186a      jr      _81e7
_817d:
817d dd7e11    ld      a,(ix+$11)
8180 ee02      xor     $02
8182 dd7711    ld      (ix+$11),a
8185 3aecd2    ld      a,($d2ec)
8188 fe08      cp      $08
818a 305b      jr      nc,_81e7
818c cd7b7c    call    _7c7b
818f d8        ret     c
8190 dd5e02    ld      e,(ix+$02)
8193 dd5603    ld      d,(ix+$03)
8196 dd4e05    ld      c,(ix+$05)
8199 dd4606    ld      b,(ix+$06)
819c dde5      push    ix
819e e5        push    hl
819f dde1      pop     ix
81a1 dd36002b  ld      (ix+$00),$2b
81a5 af        xor     a
81a6 dd7701    ld      (ix+$01),a
81a9 210b00    ld      hl,$000b
81ac 19        add     hl,de
81ad dd7502    ld      (ix+$02),l
81b0 dd7403    ld      (ix+$03),h
81b3 dd7704    ld      (ix+$04),a
81b6 213000    ld      hl,$0030
81b9 09        add     hl,bc
81ba dd7505    ld      (ix+$05),l
81bd dd7406    ld      (ix+$06),h
81c0 dd7707    ld      (ix+$07),a
81c3 dd7708    ld      (ix+$08),a
81c6 dd7709    ld      (ix+$09),a
81c9 dd770a    ld      (ix+$0a),a
81cc dd770b    ld      (ix+$0b),a
81cf dd770c    ld      (ix+$0c),a
81d2 dd7711    ld      (ix+$11),a
81d5 dd7716    ld      (ix+$16),a
81d8 dd7717    ld      (ix+$17),a
81db cd2506    call    _LABEL_625_57
81de e63f      and     $3f
81e0 c664      add     a,$64
81e2 dd7712    ld      (ix+$12),a
81e5 dde1      pop     ix
_81e7:
81e7 215a00    ld      hl,$005a
81ea 2216d2    ld      ($d216),hl
81ed cdbe77    call    _77be
81f0 cdfa79    call    _79fa
81f3 c9        ret     

_81f4:
81f4 2022      jr      nz,_8218
81f6 24        inc     h
81f7 2628      ld      h,$28
81f9 ff        rst     $38
81fa 40        ld      b,b
81fb 42        ld      b,d
81fc 44        ld      b,h
81fd 46        ld      b,(hl)
81fe 48        ld      c,b
81ff ff        rst     $38
8200 60        ld      h,b
8201 54        ld      d,h
8202 56        ld      d,(hl)
8203 58        ld      e,b
8204 68        ld      l,b
8205 ff        rst     $38
8206 2a2c2e    ld      hl,($2e2c)
8209 3032      jr------nc,$823d
820b ff        rst     $38
820c 4a        ld      c,d
820d 4c        ld      c,h
820e 4e        ld      c,(hl)
820f 50        ld      d,b
8210 52        ld      d,d
8211 ff        rst     $38
8212 6a        ld      l,d
8213 5a        ld      e,d
8214 5c        ld      e,h
8215 5e        ld      e,(hl)
8216 72        ld      (hl),d
8217 ff        rst     $38

_8218:
8218 ddcb18ae  res     5,(ix+$18)
821c dd360d0c  ld      (ix+$0d),$0c
8220 dd360e10  ld      (ix+$0e),$10
8224 210202    ld      hl,$0202
8227 2214d2    ld      ($d214),hl
822a cd5639    call    _LABEL_3956_11
822d d4fd35    call    nc,_35fd
8230 dd6e07    ld      l,(ix+$07)
8233 dd6608    ld      h,(ix+$08)
8236 dd7e09    ld      a,(ix+$09)
8239 110200    ld      de,$0002
823c 0e00      ld      c,$00
823e a7        and     a
823f fa4682    jp      m,_8246
8242 0d        dec     c
8243 11feff    ld      de,$fffe
_8246:
8246 19        add     hl,de
8247 89        adc     a,c
8248 dd7507    ld      (ix+$07),l
824b dd7408    ld      (ix+$08),h
824e dd7709    ld      (ix+$09),a
8251 dd6e0a    ld      l,(ix+$0a)
8254 dd660b    ld      h,(ix+$0b)
8257 dd7e0c    ld      a,(ix+$0c)
825a 112000    ld      de,$0020
825d 19        add     hl,de
825e ce00      adc     a,$00
8260 4f        ld      c,a
8261 7c        ld      a,h
8262 fe03      cp      $03
8264 3805      jr      c,_826b
8266 210003    ld      hl,$0300
8269 0e00      ld      c,$00
_826b:
826b dd750a    ld      (ix+$0a),l
826e dd740b    ld      (ix+$0b),h
8271 dd710c    ld      (ix+$0c),c
8274 3a23d2    ld      a,($d223)
8277 e601      and     $01
8279 dd8611    add     a,(ix+$11)
827c dd7711    ld      (ix+$11),a
827f dd7e11    ld      a,(ix+$11)
8282 ddbe12    cp      (ix+$12)
8285 300a      jr      nc,_8291
8287 01c182    ld      bc,$82c1
828a 11cd82    ld      de,$82cd
828d cd417c    call    _7c41
8290 c9        ret     
_8291:
8291 200d      jr      nz,_82a0
8293 3a23d2    ld      a,($d223)
8296 e601      and     $01
8298 c8        ret     z
8299 dd361600  ld      (ix+$16),$00
829d 3e01      ld      a,$01
829f ef        rst     $28
_82a0:
82a0 af        xor     a
82a1 dd7707    ld      (ix+$07),a
82a4 dd7708    ld      (ix+$08),a
82a7 dd7709    ld      (ix+$09),a
82aa 01c682    ld      bc,$82c6
82ad 11bba3    ld      de,$a3bb
82b0 cd417c    call    _7c41
82b3 dd7e12    ld      a,(ix+$12)
82b6 c612      add     a,$12
82b8 ddbe11    cp      (ix+$11)
82bb d0        ret     nc
82bc dd3600ff  ld      (ix+$00),$ff
82c0 c9        ret     
82c1 00        nop     
82c2 04        inc     b
82c3 0104ff    ld      bc,$ff04
82c6 010c02    ld      bc,$020c
82c9 0c        inc     c
82ca 03        inc     bc
82cb 0c        inc     c
82cc ff        rst     $38
82cd 08        ex      af,af'
82ce 0a        ld      a,(bc)
82cf ff        rst     $38
82d0 ff        rst     $38
82d1 ff        rst     $38
82d2 ff        rst     $38
82d3 ff        rst     $38
82d4 ff        rst     $38
82d5 ff        rst     $38
82d6 ff        rst     $38
82d7 ff        rst     $38
82d8 ff        rst     $38
82d9 ff        rst     $38
82da ff        rst     $38
82db ff        rst     $38
82dc ff        rst     $38
82dd ff        rst     $38
82de ff        rst     $38
82df 0c        inc     c
82e0 0eff      ld      c,$ff
82e2 ff        rst     $38
82e3 ff        rst     $38
82e4 ff        rst     $38
82e5 ff        rst     $38
82e6 dd360d10  ld      (ix+$0d),$10
82ea dd360e0f  ld      (ix+$0e),$0f
82ee 210804    ld      hl,$0408
82f1 2214d2    ld      ($d214),hl
82f4 cd5639    call    _LABEL_3956_11
82f7 d4fd35    call    nc,_35fd
82fa dd360d14  ld      (ix+$0d),$14
82fe dd360e20  ld      (ix+$0e),$20
8302 210610    ld      hl,$1006
8305 2214d2    ld      ($d214),hl
8308 cd5639    call    _LABEL_3956_11
830b 210404    ld      hl,$0404
830e 220ed2    ld      ($d20e),hl
8311 d4e535    call    nc,_35e5
8314 dd6e0a    ld      l,(ix+$0a)
8317 dd660b    ld      h,(ix+$0b)
831a dd7e0c    ld      a,(ix+$0c)
831d 112000    ld      de,$0020
8320 19        add     hl,de
8321 ce00      adc     a,$00
8323 dd750a    ld      (ix+$0a),l
8326 dd740b    ld      (ix+$0b),h
8329 dd770c    ld      (ix+$0c),a
832c dd7e11    ld      a,(ix+$11)
832f fe50      cp      $50
8331 3818      jr      c,_834b
8333 dd360740  ld      (ix+$07),$40
8337 dd360800  ld      (ix+$08),$00
833b dd360900  ld      (ix+$09),$00
833f 117e83    ld      de,$837e
8342 017983    ld      bc,$8379
8345 cd417c    call    _7c41
8348 c36083    jp      _8360
_834b:
834b dd3607c0  ld      (ix+$07),$c0
834f dd3608ff  ld      (ix+$08),$ff
8353 dd3609ff  ld      (ix+$09),$ff
8357 117e83    ld      de,$837e
835a 017483    ld      bc,$8374
835d cd417c    call    _7c41
_8360:
8360 3a23d2    ld      a,($d223)
8363 e607      and     $07
8365 c0        ret     nz
8366 dd3411    inc     (ix+$11)
8369 dd7e11    ld      a,(ix+$11)
836c fea0      cp      $a0
836e d8        ret     c
836f dd361100  ld      (ix+$11),$00
8373 c9        ret     
8374 00        nop     
8375 0601      ld      b,$01
8377 06ff      ld      b,$ff
8379 02        ld      (bc),a
837a 0603      ld      b,$03
837c 06ff      ld      b,$ff
837e fe00      cp      $00
8380 02        ld      (bc),a
8381 ff        rst     $38
8382 ff        rst     $38
8383 ff        rst     $38
8384 2022      jr------nz,$83a8
8386 24        inc     h
8387 ff        rst     $38
8388 ff        rst     $38
8389 ff        rst     $38
838a ff        rst     $38
838b ff        rst     $38
838c ff        rst     $38
838d ff        rst     $38
838e ff        rst     $38
838f ff        rst     $38
8390 fe00      cp      $00
8392 02        ld      (bc),a
8393 ff        rst     $38
8394 ff        rst     $38
8395 ff        rst     $38
8396 2628      ld      h,$28
8398 2affff    ld      hl,(SMS_PAGE_2)
839b ff        rst     $38
839c ff        rst     $38
839d ff        rst     $38
839e ff        rst     $38
839f ff        rst     $38
83a0 ff        rst     $38
83a1 ff        rst     $38
83a2 40        ld      b,b
83a3 42        ld      b,d
83a4 ff        rst     $38
83a5 ff        rst     $38
83a6 ff        rst     $38
83a7 ff        rst     $38
83a8 4a        ld      c,d
83a9 4c        ld      c,h
83aa 4e        ld      c,(hl)
83ab ff        rst     $38
83ac ff        rst     $38
83ad ff        rst     $38
83ae ff        rst     $38
83af ff        rst     $38
83b0 ff        rst     $38
83b1 ff        rst     $38
83b2 ff        rst     $38
83b3 ff        rst     $38
83b4 40        ld      b,b
83b5 42        ld      b,d
83b6 ff        rst     $38
83b7 ff        rst     $38
83b8 ff        rst     $38
83b9 ff        rst     $38
83ba 44        ld      b,h
83bb 46        ld      b,(hl)
83bc 48        ld      c,b
83bd ff        rst     $38
83be ff        rst     $38
83bf ff        rst     $38
83c0 ff        rst     $38
83c1 ddcb18ee  set     5,(ix+$18)
83c5 dd360d0e  ld      (ix+$0d),$0e
83c9 dd360e08  ld      (ix+$0e),$08
83cd ddcb1846  bit     0,(ix+$18)
83d1 2054      jr      nz,_8427
83d3 af        xor     a
83d4 dd770f    ld      (ix+$0f),a
83d7 dd7710    ld      (ix+$10),a
83da 6f        ld      l,a
83db 67        ld      h,a
83dc 220ed2    ld      ($d20e),hl
83df ddcb184e  bit     1,(ix+$18)
83e3 200d      jr      nz,_83f2
83e5 cd2506    call    _LABEL_625_57
83e8 e61f      and     $1f
83ea 3c        inc     a
83eb dd7711    ld      (ix+$11),a
83ee ddcb18ce  set     1,(ix+$18)
_83f2:
83f2 dd3511    dec     (ix+$11)
83f5 c26784    jp      nz,_8467
83f8 dd361101  ld      (ix+$11),$01
83fc 3aacd2    ld      a,($d2ac)
83ff e680      and     $80
8401 ca6784    jp      z,_8467
8404 dd6e02    ld      l,(ix+$02)
8407 dd6603    ld      h,(ix+$03)
840a 22abd2    ld      ($d2ab),hl
840d dd6e05    ld      l,(ix+$05)
8410 dd6606    ld      h,(ix+$06)
8413 110e00    ld      de,$000e
8416 19        add     hl,de
8417 22add2    ld      ($d2ad),hl
841a 218e84    ld      hl,$848e
841d 22afd2    ld      ($d2af),hl
8420 ddcb18c6  set     0,(ix+$18)
8424 3e20      ld      a,$20
8426 ef        rst     $28
_8427:
8427 dd360f81  ld      (ix+$0f),$81
842b dd361084  ld      (ix+$10),$84
842f dd6e0a    ld      l,(ix+$0a)
8432 dd660b    ld      h,(ix+$0b)
8435 dd7e0c    ld      a,(ix+$0c)
8438 112000    ld      de,$0020
843b 19        add     hl,de
843c ce00      adc     a,$00
843e 4f        ld      c,a
843f 7c        ld      a,h
8440 fe04      cp      $04
8442 3802      jr      c,_8446
8444 2604      ld      h,$04
_8446:
8446 dd750a    ld      (ix+$0a),l
8449 dd740b    ld      (ix+$0b),h
844c dd710c    ld      (ix+$0c),c
844f 220ed2    ld      ($d20e),hl
8452 ed5b5dd2  ld      de,($d25d)
8456 14        inc     d
8457 dd6e05    ld      l,(ix+$05)
845a dd6606    ld      h,(ix+$06)
845d a7        and     a
845e ed52      sbc     hl,de
8460 3805      jr      c,_8467
8462 dd3600ff  ld      (ix+$00),$ff
8466 c9        ret     
_8467:
8467 210204    ld      hl,$0402
846a 2214d2    ld      ($d214),hl
846d cd5639    call    _LABEL_3956_11
8470 d8        ret     c
8471 3a08d4    ld      a,($d408)
8474 a7        and     a
8475 f8        ret     m
8476 ed5b0ed2  ld      de,($d20e)
847a 011000    ld      bc,$0010
847d cdc17c    call    _LABEL_7CC1_12
8480 c9        ret     
8481 feff      cp      $ff
8483 ff        rst     $38
8484 ff        rst     $38
8485 ff        rst     $38
8486 ff        rst     $38
8487 70        ld      (hl),b
8488 72        ld      (hl),d
8489 ff        rst     $38
848a ff        rst     $38
848b ff        rst     $38
848c ff        rst     $38
848d ff        rst     $38
848e 00        nop     
848f 00        nop     
8490 00        nop     
8491 00        nop     
8492 00        nop     
8493 00        nop     
8494 00        nop     
8495 00        nop     
8496 ddcb18ee  set     5,(ix+$18)
849a dd360d1e  ld      (ix+$0d),$1e
849e dd360e1c  ld      (ix+$0e),$1c
84a2 cda67c    call    _7ca6
84a5 dd360f5a  ld      (ix+$0f),$5a
84a9 dd361086  ld      (ix+$10),$86
84ad ddcb1846  bit     0,(ix+$18)
84b1 2027      jr      nz,_84da
84b3 21a003    ld      hl,$03a0
84b6 110003    ld      de,$0300
84b9 cd8c7c    call    _7c8c

		;UNKNOWN
84bc 2108e5    ld      hl,$e508
84bf 110020    ld      de,$2000
84c2 3e0c      ld      a,12
84c4 cd0504    call    decompressArt

84c7 211c73    ld      hl,S1_BossPalette
84ca 3e02      ld      a,$02
84cc cd3303    call    loadPaletteOnInterrupt
84cf af        xor     a
84d0 32ecd2    ld      ($d2ec),a
84d3 3e0b      ld      a,$0b
84d5 df        rst     $18
84d6 ddcb18c6  set     0,(ix+$18)
_84da:
84da dd7e11    ld      a,(ix+$11)
84dd a7        and     a
84de 2028      jr      nz,_8508
84e0 cd2506    call    _LABEL_625_57
84e3 e601      and     $01
84e5 87        add     a,a
84e6 87        add     a,a
84e7 5f        ld      e,a
84e8 1600      ld      d,$00
84ea 213286    ld      hl,$8632
84ed 19        add     hl,de
84ee 7e        ld      a,(hl)
84ef dd7702    ld      (ix+$02),a
84f2 23        inc     hl
84f3 7e        ld      a,(hl)
84f4 23        inc     hl
84f5 dd7703    ld      (ix+$03),a
84f8 7e        ld      a,(hl)
84f9 23        inc     hl
84fa dd7705    ld      (ix+$05),a
84fd 7e        ld      a,(hl)
84fe 23        inc     hl
84ff dd7706    ld      (ix+$06),a
8502 dd3411    inc     (ix+$11)
8505 c3c785    jp      _85c7
_8508:
8508 3d        dec     a
8509 2024      jr      nz,_852f
850b dd360a80  ld      (ix+$0a),$80
850f dd360bff  ld      (ix+$0b),$ff
8513 dd360cff  ld      (ix+$0c),$ff
8517 218003    ld      hl,$0380
851a dd5e05    ld      e,(ix+$05)
851d dd5606    ld      d,(ix+$06)
8520 af        xor     a
8521 ed52      sbc     hl,de
8523 dac785    jp      c,_85c7
8526 dd3411    inc     (ix+$11)
8529 dd7712    ld      (ix+$12),a
852c c3c785    jp      _85c7
_852f:
852f 3d        dec     a
8530 2078      jr      nz,_85aa
8532 af        xor     a
8533 dd770a    ld      (ix+$0a),a
8536 dd770b    ld      (ix+$0b),a
8539 dd770c    ld      (ix+$0c),a
853c dd3412    inc     (ix+$12)
853f dd7e12    ld      a,(ix+$12)
8542 fe64      cp      $64
8544 c2c785    jp      nz,_85c7
8547 dd3411    inc     (ix+$11)
854a 3aecd2    ld      a,($d2ec)
854d fe08      cp      $08
854f 3076      jr      nc,_85c7
8551 2afed3    ld      hl,($d3fe)
8554 dd5e02    ld      e,(ix+$02)
8557 dd5603    ld      d,(ix+$03)
855a a7        and     a
855b ed52      sbc     hl,de
855d 213a86    ld      hl,$863a
8560 3803      jr      c,_8565
8562 214a86    ld      hl,$864a
_8565:
8565 5e        ld      e,(hl)
8566 23        inc     hl
8567 56        ld      d,(hl)
8568 23        inc     hl
8569 4e        ld      c,(hl)
856a 23        inc     hl
856b 46        ld      b,(hl)
856c 23        inc     hl
856d e5        push    hl
856e dd6e02    ld      l,(ix+$02)
8571 dd6603    ld      h,(ix+$03)
8574 19        add     hl,de
8575 220ed2    ld      ($d20e),hl
8578 dd6e05    ld      l,(ix+$05)
857b dd6606    ld      h,(ix+$06)
857e 09        add     hl,bc
857f 2210d2    ld      ($d210),hl
8582 e1        pop     hl
8583 0603      ld      b,$03
_8585:
8585 c5        push    bc
8586 7e        ld      a,(hl)
8587 3212d2    ld      ($d212),a
858a 23        inc     hl
858b 7e        ld      a,(hl)
858c 3213d2    ld      ($d213),a
858f 23        inc     hl
8590 7e        ld      a,(hl)
8591 3214d2    ld      ($d214),a
8594 23        inc     hl
8595 7e        ld      a,(hl)
8596 3215d2    ld      ($d215),a
8599 23        inc     hl
859a e5        push    hl
859b 0e10      ld      c,$10
859d cdd185    call    _85d1
85a0 e1        pop     hl
85a1 c1        pop     bc
85a2 10e1      djnz    _8585
85a4 3e01      ld      a,$01
85a6 ef        rst     $28
85a7 c3c785    jp      _85c7
_85aa:
85aa dd360a80  ld      (ix+$0a),$80
85ae dd360b00  ld      (ix+$0b),$00
85b2 dd360c00  ld      (ix+$0c),$00
85b6 21c003    ld      hl,$03c0
85b9 dd5e05    ld      e,(ix+$05)
85bc dd5606    ld      d,(ix+$06)
85bf af        xor     a
85c0 ed52      sbc     hl,de
85c2 3003      jr      nc,_85c7
85c4 dd7711    ld      (ix+$11),a
_85c7:
85c7 21a200    ld      hl,$00a2
85ca 2216d2    ld      ($d216),hl
85cd cdbe77    call    _77be
85d0 c9        ret     

_85d1:
85d1 c5        push    bc
85d2 cd7b7c    call    _7c7b
85d5 c1        pop     bc
85d6 d8        ret     c
85d7 dde5      push    ix
85d9 e5        push    hl
85da dde1      pop     ix
85dc af        xor     a
85dd dd36000d  ld      (ix+$00),$0d
85e1 2a0ed2    ld      hl,($d20e)
85e4 dd7701    ld      (ix+$01),a
85e7 dd7502    ld      (ix+$02),l
85ea dd7403    ld      (ix+$03),h
85ed 2a10d2    ld      hl,($d210)
85f0 dd7704    ld      (ix+$04),a
85f3 dd7505    ld      (ix+$05),l
85f6 dd7406    ld      (ix+$06),h
85f9 dd7711    ld      (ix+$11),a
85fc dd7113    ld      (ix+$13),c
85ff dd7714    ld      (ix+$14),a
8602 dd7715    ld      (ix+$15),a
8605 dd7716    ld      (ix+$16),a
8608 dd7717    ld      (ix+$17),a
860b 2a12d2    ld      hl,($d212)
860e af        xor     a
860f cb7c      bit     7,h
8611 2801      jr      z,_8614
8613 3d        dec     a
_8614:
8614 dd7507    ld      (ix+$07),l
8617 dd7408    ld      (ix+$08),h
861a dd7709    ld      (ix+$09),a
861d 2a14d2    ld      hl,($d214)
8620 af        xor     a
8621 cb7c      bit     7,h
8623 2801      jr      z,_8626
8625 3d        dec     a
_8626:
8626 dd750a    ld      (ix+$0a),l
8629 dd740b    ld      (ix+$0b),h
862c dd770c    ld      (ix+$0c),a
862f dde1      pop     ix
8631 c9        ret     
8632 d403c0    call----nc,$c003
8635 03        inc     bc
8636 44        ld      b,h
8637 04        inc     b
8638 c0        ret     nz
8639 03        inc     bc
863a 00        nop     
863b 00        nop     
863c f6ff      or      $ff
863e c0        ret     nz
863f fe00      cp      $00
8641 fc60fe    call----m,$fe60
8644 80        add     a,b
8645 fdc0      ret     nz
8647 fd00      nop     
8649 ff        rst     $38
864a 2000      jr------nz,$864c
864c f6ff      or      $ff
864e 40        ld      b,b
864f 0100fc    ld      bc,$fc00
8652 a0        and     b
8653 0180fd    ld      bc,$fd80
8656 40        ld      b,b
8657 02        ld      (bc),a
8658 00        nop     
8659 ff        rst     $38
865a 2022      jr------nz,$867e
865c 24        inc     h
865d 2628      ld      h,$28
865f ff        rst     $38
8660 40        ld      b,b
8661 42        ld      b,d
8662 44        ld      b,h
8663 46        ld      b,(hl)
8664 48        ld      c,b
8665 ff        rst     $38
8666 60        ld      h,b
8667 62        ld      h,d
8668 64        ld      h,h
8669 66        ld      h,(hl)
866a 68        ld      l,b
866b ff        rst     $38
866c ddcb18ee  set     5,(ix+$18)
8670 ddcb1846  bit     0,(ix+$18)
8674 2018      jr      nz,_868e
8676 dd36111c  ld      (ix+$11),$1c
867a dd6e02    ld      l,(ix+$02)
867d dd6603    ld      h,(ix+$03)
8680 11f0ff    ld      de,$fff0
8683 19        add     hl,de
8684 dd7502    ld      (ix+$02),l
8687 dd7403    ld      (ix+$03),h
868a ddcb18c6  set     0,(ix+$18)
_868e:
868e dd6e14    ld      l,(ix+$14)
8691 dd6615    ld      h,(ix+$15)
8694 dd7e16    ld      a,(ix+$16)
8697 dd5e12    ld      e,(ix+$12)
869a dd5613    ld      d,(ix+$13)
869d 0e00      ld      c,$00
869f cb7a      bit     7,d
86a1 2801      jr      z,_86a4
86a3 0d        dec     c
_86a4:
86a4 19        add     hl,de
86a5 89        adc     a,c
86a6 dd7514    ld      (ix+$14),l
86a9 dd7415    ld      (ix+$15),h
86ac dd7716    ld      (ix+$16),a
86af 4c        ld      c,h
86b0 47        ld      b,a
86b1 213800    ld      hl,$0038
86b4 19        add     hl,de
86b5 dd7512    ld      (ix+$12),l
86b8 dd7413    ld      (ix+$13),h
86bb cb7c      bit     7,h
86bd 205c      jr      nz,_871b
86bf 07        rlca    
86c0 3859      jr      c,_871b
86c2 dd7e11    ld      a,(ix+$11)
86c5 a7        and     a
86c6 283f      jr      z,_8707
86c8 ddcb184e  bit     1,(ix+$18)
86cc 2826      jr      z,_86f4
86ce 7d        ld      a,l
86cf b4        or      h
86d0 200e      jr      nz,_86e0
86d2 3ae8d2    ld      a,($d2e8)
86d5 2ae6d2    ld      hl,($d2e6)
86d8 2206d4    ld      ($d406),hl
86db 3208d4    ld      ($d408),a
86de 1814      jr      _86f4
_86e0:
86e0 7d        ld      a,l
86e1 2f        cpl     
86e2 6f        ld      l,a
86e3 7c        ld      a,h
86e4 2f        cpl     
86e5 67        ld      h,a
86e6 23        inc     hl
86e7 ed5be6d2  ld      de,($d2e6)
86eb 19        add     hl,de
86ec 2206d4    ld      ($d406),hl
86ef 3eff      ld      a,$ff
86f1 3208d4    ld      ($d408),a
_86f4:
86f4 3e1c      ld      a,$1c
86f6 91        sub     c
86f7 dd7711    ld      (ix+$11),a
86fa 2802      jr      z,_86fe
86fc 301d      jr      nc,_871b
_86fe:
86fe ddcb184e  bit     1,(ix+$18)
8702 2803      jr      z,_8707
8704 3e04      ld      a,$04
8706 ef        rst     $28
_8707:
8707 af        xor     a
8708 dd7711    ld      (ix+$11),a
870b dd7712    ld      (ix+$12),a
870e dd7713    ld      (ix+$13),a
8711 dd7714    ld      (ix+$14),a
8714 dd36151c  ld      (ix+$15),$1c
8718 dd7716    ld      (ix+$16),a
_871b:
871b dd6e02    ld      l,(ix+$02)
871e dd6603    ld      h,(ix+$03)
8721 220ed2    ld      ($d20e),hl
8724 dd6e05    ld      l,(ix+$05)
8727 dd6606    ld      h,(ix+$06)
872a 2210d2    ld      ($d210),hl
872d 210000    ld      hl,$0000
8730 2212d2    ld      ($d212),hl
8733 dd6e11    ld      l,(ix+$11)
8736 111000    ld      de,$0010
8739 19        add     hl,de
873a 2214d2    ld      ($d214),hl
873d 213088    ld      hl,$8830
8740 cd1a88    call    _881a
8743 212800    ld      hl,$0028
8746 2212d2    ld      ($d212),hl
8749 3e1c      ld      a,$1c
874b dd9611    sub     (ix+$11)
874e 6f        ld      l,a
874f 2600      ld      h,$00
8751 111000    ld      de,$0010
8754 19        add     hl,de
8755 2214d2    ld      ($d214),hl
8758 213088    ld      hl,$8830
875b cd1a88    call    _881a
875e 212c00    ld      hl,$002c
8761 2212d2    ld      ($d212),hl
8764 dd6e15    ld      l,(ix+$15)
8767 dd6616    ld      h,(ix+$16)
876a 2214d2    ld      ($d214),hl
876d 213488    ld      hl,$8834
8770 cd1a88    call    _881a
8773 ddcb188e  res     1,(ix+$18)
8777 dd360d14  ld      (ix+$0d),$14
877b 3e02      ld      a,$02
877d 3214d2    ld      ($d214),a
8780 dd7e11    ld      a,(ix+$11)
8783 4f        ld      c,a
8784 c608      add     a,$08
8786 dd770e    ld      (ix+$0e),a
8789 79        ld      a,c
878a c604      add     a,$04
878c 3215d2    ld      ($d215),a
878f cd5639    call    _LABEL_3956_11
8792 3028      jr      nc,_87bc
8794 3a08d4    ld      a,($d408)
8797 a7        and     a
8798 f8        ret     m
8799 dd360d3c  ld      (ix+$0d),$3c
879d 3e2a      ld      a,$2a
879f 3214d2    ld      ($d214),a
87a2 3e1c      ld      a,$1c
87a4 dd9611    sub     (ix+$11)
87a7 c608      add     a,$08
87a9 dd770e    ld      (ix+$0e),a
87ac 3e1c      ld      a,$1c
87ae dd9611    sub     (ix+$11)
87b1 c604      add     a,$04
87b3 3215d2    ld      ($d215),a
87b6 cd5639    call    _LABEL_3956_11
87b9 3032      jr      nc,_87ed
87bb c9        ret     
_87bc:
87bc ddcb18ce  set     1,(ix+$18)
87c0 3a08d4    ld      a,($d408)
87c3 a7        and     a
87c4 f8        ret     m
87c5 dd7e11    ld      a,(ix+$11)
87c8 fe1c      cp      $1c
87ca 2821      jr      z,_87ed
87cc 2a06d4    ld      hl,($d406)
87cf 7d        ld      a,l
87d0 2f        cpl     
87d1 6f        ld      l,a
87d2 7c        ld      a,h
87d3 2f        cpl     
87d4 67        ld      h,a
87d5 23        inc     hl
87d6 dd7512    ld      (ix+$12),l
87d9 dd7413    ld      (ix+$13),h
87dc 3a07d4    ld      a,($d407)
87df dd8611    add     a,(ix+$11)
87e2 dd7711    ld      (ix+$11),a
87e5 fe1c      cp      $1c
87e7 3810      jr      c,_87f9
87e9 dd36111c  ld      (ix+$11),$1c
_87ed:
87ed 3ae8d2    ld      a,($d2e8)
87f0 2ae6d2    ld      hl,($d2e6)
87f3 2206d4    ld      ($d406),hl
87f6 3208d4    ld      ($d408),a
_87f9:
87f9 dd6e05    ld      l,(ix+$05)
87fc dd6606    ld      h,(ix+$06)
87ff 011000    ld      bc,$0010
8802 09        add     hl,bc
8803 3a15d2    ld      a,($d215)
8806 d604      sub     $04
8808 4f        ld      c,a
8809 09        add     hl,bc
880a 3a0ad4    ld      a,($d40a)
880d 4f        ld      c,a
880e af        xor     a
880f ed42      sbc     hl,bc
8811 2201d4    ld      ($d401),hl
8814 2114d4    ld      hl,$d414
8817 cbfe      set     7,(hl)
8819 c9        ret     

_881a:
881a 7e        ld      a,(hl)
881b a7        and     a
881c f8        ret     m
881d e5        push    hl
881e cd8135    call    _3581
8821 2a12d2    ld      hl,($d212)
8824 110800    ld      de,$0008
8827 19        add     hl,de
8828 2212d2    ld      ($d212),hl
882b e1        pop     hl
882c 23        inc     hl
882d c31a88    jp      _881a
8830 3638      ld      (hl),$38
8832 3aff3c    ld      a,($3cff)
8835 3eff      ld      a,$ff
8837 ddcb18ee  set     5,(ix+$18)
883b dd7e11    ld      a,(ix+$11)
883e fe80      cp      $80
8840 3031      jr      nc,_8873
8842 dd360720  ld      (ix+$07),$20
8846 dd360800  ld      (ix+$08),$00
884a dd360900  ld      (ix+$09),$00
884e dd360d14  ld      (ix+$0d),$14
8852 dd360e0c  ld      (ix+$0e),$0c
8856 21020a    ld      hl,$0a02
8859 2214d2    ld      ($d214),hl
885c cd5639    call    _LABEL_3956_11
885f 210800    ld      hl,$0008
8862 220ed2    ld      ($d20e),hl
8865 d4e535    call    nc,_35e5
8868 11be88    ld      de,$88be
886b 01b488    ld      bc,$88b4
886e cd417c    call    _7c41
8871 182f      jr      _88a2
_8873:
8873 dd3607e0  ld      (ix+$07),$e0
8877 dd3608ff  ld      (ix+$08),$ff
887b dd3609ff  ld      (ix+$09),$ff
887f dd360d0c  ld      (ix+$0d),$0c
8883 dd360e0c  ld      (ix+$0e),$0c
8887 210202    ld      hl,$0202
888a 2214d2    ld      ($d214),hl
888d cd5639    call    _LABEL_3956_11
8890 210000    ld      hl,$0000
8893 220ed2    ld      ($d20e),hl
8896 d4e535    call    nc,_35e5
8899 11be88    ld      de,$88be
889c 01b988    ld      bc,$88b9
889f cd417c    call    _7c41
_88a2:
88a2 3a23d2    ld      a,($d223)
88a5 e607      and     $07
88a7 c0        ret     nz
88a8 dd3411    inc     (ix+$11)
88ab cd2506    call    _LABEL_625_57
88ae e61e      and     $1e
88b0 cceb91    call    z,_91eb
88b3 c9        ret     
88b4 00        nop     
88b5 04        inc     b
88b6 0104ff    ld      bc,$ff04
88b9 02        ld      (bc),a
88ba 04        inc     b
88bb 03        inc     bc
88bc 04        inc     b
88bd ff        rst     $38
88be 04        inc     b
88bf 2a2cff    ld      hl,($ff2c)
88c2 ff        rst     $38
88c3 ff        rst     $38
88c4 ff        rst     $38
88c5 ff        rst     $38
88c6 ff        rst     $38
88c7 ff        rst     $38
88c8 ff        rst     $38
88c9 ff        rst     $38
88ca ff        rst     $38
88cb ff        rst     $38
88cc ff        rst     $38
88cd ff        rst     $38
88ce ff        rst     $38
88cf ff        rst     $38
88d0 0c        inc     c
88d1 2a2cff    ld      hl,($ff2c)
88d4 ff        rst     $38
88d5 ff        rst     $38
88d6 ff        rst     $38
88d7 ff        rst     $38
88d8 ff        rst     $38
88d9 ff        rst     $38
88da ff        rst     $38
88db ff        rst     $38
88dc ff        rst     $38
88dd ff        rst     $38
88de ff        rst     $38
88df ff        rst     $38
88e0 ff        rst     $38
88e1 ff        rst     $38
88e2 0e10      ld      c,$10
88e4 0a        ld      a,(bc)
88e5 ff        rst     $38
88e6 ff        rst     $38
88e7 ff        rst     $38
88e8 ff        rst     $38
88e9 ff        rst     $38
88ea ff        rst     $38
88eb ff        rst     $38
88ec ff        rst     $38
88ed ff        rst     $38
88ee ff        rst     $38
88ef ff        rst     $38
88f0 ff        rst     $38
88f1 ff        rst     $38
88f2 ff        rst     $38
88f3 ff        rst     $38
88f4 0e10      ld      c,$10
88f6 0c        inc     c
88f7 ff        rst     $38
88f8 ff        rst     $38
88f9 ff        rst     $38
88fa ff        rst     $38
88fb ddcb18ee  set     5,(ix+$18)
88ff dd360d08  ld      (ix+$0d),$08
8903 dd360e0c  ld      (ix+$0e),$0c
8907 ddcb1846  bit     0,(ix+$18)
890b 2024      jr      nz,_8931
890d dd6e02    ld      l,(ix+$02)
8910 dd6603    ld      h,(ix+$03)
8913 110800    ld      de,$0008
8916 19        add     hl,de
8917 dd7512    ld      (ix+$12),l
891a dd7413    ld      (ix+$13),h
891d dd6e05    ld      l,(ix+$05)
8920 dd6606    ld      h,(ix+$06)
8923 110800    ld      de,$0008
8926 19        add     hl,de
8927 dd7514    ld      (ix+$14),l
892a dd7415    ld      (ix+$15),h
892d ddcb18c6  set     0,(ix+$18)
_8931:
8931 dd6e11    ld      l,(ix+$11)
8934 2600      ld      h,$00
8936 29        add     hl,hl
8937 118e89    ld      de,$898e
893a 19        add     hl,de
893b 5e        ld      e,(hl)
893c 23        inc     hl
893d 4e        ld      c,(hl)
893e 1600      ld      d,$00
8940 42        ld      b,d
8941 cb7b      bit     7,e
8943 2801      jr      z,_8946
8945 15        dec     d
_8946:
8946 cb79      bit     7,c
8948 2801      jr      z,_894b
894a 05        dec     b
_894b:
894b dd6e12    ld      l,(ix+$12)
894e dd6613    ld      h,(ix+$13)
8951 19        add     hl,de
8952 dd7502    ld      (ix+$02),l
8955 dd7403    ld      (ix+$03),h
8958 dd6e14    ld      l,(ix+$14)
895b dd6615    ld      h,(ix+$15)
895e 09        add     hl,bc
895f dd7505    ld      (ix+$05),l
8962 dd7406    ld      (ix+$06),h
8965 210402    ld      hl,$0204
8968 2214d2    ld      ($d214),hl
896b cd5639    call    _LABEL_3956_11
896e d4fd35    call    nc,_35fd
8971 dd360f87  ld      (ix+$0f),$87
8975 dd361089  ld      (ix+$10),$89
8979 dd3411    inc     (ix+$11)
897c dd7e11    ld      a,(ix+$11)
897f feb4      cp      $b4
8981 d8        ret     c
8982 dd361100  ld      (ix+$11),$00
8986 c9        ret     
8987 60        ld      h,b
8988 62        ld      h,d
8989 ff        rst     $38
898a ff        rst     $38
898b ff        rst     $38
898c ff        rst     $38
898d ff        rst     $38
898e 40        ld      b,b
898f 00        nop     
8990 40        ld      b,b
8991 02        ld      (bc),a
8992 40        ld      b,b
8993 04        inc     b
8994 40        ld      b,b
8995 07        rlca    
8996 3f        ccf     
8997 09        add     hl,bc
8998 3f        ccf     
8999 0b        dec     bc
899a 3f        ccf     
899b 0d        dec     c
899c 3e0f      ld      a,$0f
899e 3e12      ld      a,$12
89a0 3d        dec     a
89a1 14        inc     d
89a2 3c        inc     a
89a3 163b      ld      d,$3b
89a5 183a      jr------$89e1
89a7 1a        ld      a,(de)
89a8 3a1c39    ld      a,($391c)
89ab 1e37      ld      e,$37
89ad 2036      jr------nz,$89e5
89af 223524    ld      ($2435),hl
89b2 34        inc     (hl)
89b3 2632      ld      h,$32
89b5 27        daa     
89b6 312930    ld      sp,$3029
89b9 2b        dec     hl
89ba 2e2c      ld      l,$2c
89bc 2c        inc     l
89bd 2e2b      ld      l,$2b
89bf 3029      jr------nc,$89ea
89c1 312732    ld      sp,$3227
89c4 2634      ld      h,$34
89c6 24        inc     h
89c7 35        dec     (hl)
89c8 223620    ld      ($2036),hl
89cb 37        scf     
89cc 1e39      ld      e,$39
89ce 1c        inc     e
89cf 3a1a3a    ld      a,($3a1a)
89d2 183b      jr------$8a0f
89d4 163c      ld      d,$3c
89d6 14        inc     d
89d7 3d        dec     a
89d8 12        ld      (de),a
89d9 3e0f      ld      a,$0f
89db 3e0d      ld      a,$0d
89dd 3f        ccf     
89de 0b        dec     bc
89df 3f        ccf     
89e0 09        add     hl,bc
89e1 3f        ccf     
89e2 07        rlca    
89e3 40        ld      b,b
89e4 04        inc     b
89e5 40        ld      b,b
89e6 02        ld      (bc),a
89e7 40        ld      b,b
89e8 00        nop     
89e9 40        ld      b,b
89ea fe40      cp      $40
89ec fc40f9    call----m,$f940
89ef 40        ld      b,b
89f0 f7        rst     $30
89f1 3f        ccf     
89f2 f5        push    af
89f3 3f        ccf     
89f4 f3        di      
89f5 3f        ccf     
89f6 f1        pop     af
89f7 3eee      ld      a,$ee
89f9 3eec      ld      a,$ec
89fb 3d        dec     a
89fc ea3ce8    jp------pe,$e83c
89ff 3b        dec     sp
8a00 e63a      and     $3a
8a02 e43ae2    call----po,$e23a
8a05 39        add     hl,sp
8a06 e0        ret     po
8a07 37        scf     
8a08 de36      sbc     a,$36
8a0a dc35da    call----c,$da35
8a0d 34        inc     (hl)
8a0e d9        exx     
8a0f 32d731    ld      ($31d7),a
8a12 d5        push    de
8a13 30d4      jr------nc,$89e9
8a15 2ed2      ld      l,$d2
8a17 2c        inc     l
8a18 d0        ret     nc
8a19 2b        dec     hl
8a1a cf        rst     $08
8a1b 29        add     hl,hl
8a1c ce27      adc     a,$27
8a1e cc26cb    call----z,$cb26
8a21 24        inc     h
8a22 ca22c9    jp------z,$c922
8a25 20c7      jr------nz,$89ee
8a27 1ec6      ld      e,$c6
8a29 1c        inc     e
8a2a c61a      add     a,$1a
8a2c c5        push    bc
8a2d 18c4      jr------$89f3
8a2f 16c3      ld      d,$c3
8a31 14        inc     d
8a32 c212c2    jp------nz,$c212
8a35 0f        rrca    
8a36 c1        pop     bc
8a37 0d        dec     c
8a38 c1        pop     bc
8a39 0b        dec     bc
8a3a c1        pop     bc
8a3b 09        add     hl,bc
8a3c c0        ret     nz
8a3d 07        rlca    
8a3e c0        ret     nz
8a3f 04        inc     b
8a40 c0        ret     nz
8a41 02        ld      (bc),a
8a42 c0        ret     nz
8a43 00        nop     
8a44 c0        ret     nz
8a45 fec0      cp      $c0
8a47 fcc0f9    call----m,$f9c0
8a4a c1        pop     bc
8a4b f7        rst     $30
8a4c c1        pop     bc
8a4d f5        push    af
8a4e c1        pop     bc
8a4f f3        di      
8a50 c2f1c2    jp------nz,$c2f1
8a53 eec3      xor     $c3
8a55 ecc4ea    call----pe,$eac4
8a58 c5        push    bc
8a59 e8        ret     pe
8a5a c6e6      add     a,$e6
8a5c c6e4      add     a,$e4
8a5e c7        rst     $00
8a5f e2c9e0    jp------po,$e0c9
8a62 cadecb    jp------z,$cbde
8a65 dcccda    call----c,$dacc
8a68 ced9      adc     a,$d9
8a6a cf        rst     $08
8a6b d7        rst     $10
8a6c d0        ret     nc
8a6d d5        push    de
8a6e d2d4d4    jp------nc,$d4d4
8a71 d2d5d0    jp------nc,$d0d5
8a74 d7        rst     $10
8a75 cf        rst     $08
8a76 d9        exx     
8a77 ceda      adc     a,$da
8a79 ccdccb    call----z,$cbdc
8a7c deca      sbc     a,$ca
8a7e e0        ret     po
8a7f c9        ret     
8a80 e2c7e4    jp------po,$e4c7
8a83 c6e6      add     a,$e6
8a85 c6e8      add     a,$e8
8a87 c5        push    bc
8a88 eac4ec    jp------pe,$ecc4
8a8b c3eec2    jp------$c2ee
8a8e f1        pop     af
8a8f c2f3c1    jp------nz,$c1f3
8a92 f5        push    af
8a93 c1        pop     bc
8a94 f7        rst     $30
8a95 c1        pop     bc
8a96 f9        ld      sp,hl
8a97 c0        ret     nz
8a98 fcc0fe    call----m,$fec0
8a9b c0        ret     nz
8a9c 00        nop     
8a9d c0        ret     nz
8a9e 02        ld      (bc),a
8a9f c0        ret     nz
8aa0 04        inc     b
8aa1 c0        ret     nz
8aa2 07        rlca    
8aa3 c0        ret     nz
8aa4 09        add     hl,bc
8aa5 c1        pop     bc
8aa6 0b        dec     bc
8aa7 c1        pop     bc
8aa8 0d        dec     c
8aa9 c1        pop     bc
8aaa 0f        rrca    
8aab c212c2    jp------nz,$c212
8aae 14        inc     d
8aaf c316c4    jp------$c416
8ab2 18c5      jr------$8a79
8ab4 1a        ld      a,(de)
8ab5 c61c      add     a,$1c
8ab7 c61e      add     a,$1e
8ab9 c7        rst     $00
8aba 20c9      jr------nz,$8a85
8abc 22ca24    ld      ($24ca),hl
8abf cb26      sla     (hl)
8ac1 cc27ce    call----z,$ce27
8ac4 29        add     hl,hl
8ac5 cf        rst     $08
8ac6 2b        dec     hl
8ac7 d0        ret     nc
8ac8 2c        inc     l
8ac9 d22ed4    jp------nc,$d42e
8acc 30d5      jr------nc,$8aa3
8ace 31d732    ld      sp,$32d7
8ad1 d9        exx     
8ad2 34        inc     (hl)
8ad3 da35dc    jp------c,$dc35
8ad6 36de      ld      (hl),$de
8ad8 37        scf     
8ad9 e0        ret     po
8ada 39        add     hl,sp
8adb e23ae4    jp------po,$e43a
8ade 3ae63b    ld      a,($3be6)
8ae1 e8        ret     pe
8ae2 3c        inc     a
8ae3 ea3dec    jp------pe,$ec3d
8ae6 3eee      ld      a,$ee
8ae8 3ef1      ld      a,$f1
8aea 3f        ccf     
8aeb f3        di      
8aec 3f        ccf     
8aed f5        push    af
8aee 3f        ccf     
8aef f7        rst     $30
8af0 40        ld      b,b
8af1 f9        ld      sp,hl
8af2 40        ld      b,b
8af3 fc40fe    call----m,$fe40

8af6 ddcb18ee  set     5,(ix+$18)
8afa ddcb1846  bit     0,(ix+$18)
8afe 2014      jr      nz,_8b14
8b00 dd6e02    ld      l,(ix+$02)
8b03 dd6603    ld      h,(ix+$03)
8b06 110c00    ld      de,$000c
8b09 19        add     hl,de
8b0a dd7502    ld      (ix+$02),l
8b0d dd7403    ld      (ix+$03),h
8b10 ddcb18c6  set     0,(ix+$18)
_8b14:
8b14 dd6e02    ld      l,(ix+$02)
8b17 dd6603    ld      h,(ix+$03)
8b1a 220ed2    ld      ($d20e),hl
8b1d dd6e05    ld      l,(ix+$05)
8b20 dd6606    ld      h,(ix+$06)
8b23 2210d2    ld      ($d210),hl
8b26 210000    ld      hl,$0000
8b29 2212d2    ld      ($d212),hl
8b2c 3a23d2    ld      a,($d223)
8b2f 07        rlca    
8b30 07        rlca    
8b31 e603      and     $03
8b33 2014      jr      nz,_8b49
8b35 21bc8b    ld      hl,$8bbc
8b38 3a23d2    ld      a,($d223)
8b3b e63f      and     $3f
8b3d 5f        ld      e,a
8b3e fe08      cp      $08
8b40 382f      jr      c,_8b71
8b42 21cd8b    ld      hl,$8bcd
8b45 1e00      ld      e,$00
8b47 1828      jr      _8b71
_8b49:
8b49 fe01      cp      $01
8b4b 2007      jr      nz,_8b54
8b4d 21cd8b    ld      hl,$8bcd
8b50 1e00      ld      e,$00
8b52 181d      jr      _8b71
_8b54:
8b54 fe02      cp      $02
8b56 2014      jr      nz,_8b6c
8b58 21c48b    ld      hl,$8bc4
8b5b 3a23d2    ld      a,($d223)
8b5e e63f      and     $3f
8b60 5f        ld      e,a
8b61 fe08      cp      $08
8b63 380c      jr      c,_8b71
8b65 21cc8b    ld      hl,$8bcc
8b68 1e00      ld      e,$00
8b6a 1805      jr      _8b71
_8b6c:
8b6c 21cc8b    ld      hl,$8bcc
8b6f 1e00      ld      e,$00
_8b71:
8b71 1600      ld      d,$00
8b73 19        add     hl,de
8b74 7e        ld      a,(hl)
8b75 21ce8b    ld      hl,$8bce
8b78 87        add     a,a
8b79 87        add     a,a
8b7a 87        add     a,a
8b7b 5f        ld      e,a
8b7c 19        add     hl,de
8b7d 0603      ld      b,$03
_8b7f:
8b7f c5        push    bc
8b80 7e        ld      a,(hl)
8b81 23        inc     hl
8b82 5e        ld      e,(hl)
8b83 23        inc     hl
8b84 a7        and     a
8b85 fa938b    jp      m,_8b93
8b88 e5        push    hl
8b89 1600      ld      d,$00
8b8b ed5314d2  ld      ($d214),de
8b8f cd8135    call    _3581
8b92 e1        pop     hl
_8b93:
8b93 c1        pop     bc
8b94 10e9      djnz    _8b7f
8b96 dd700f    ld      (ix+$0f),b
8b99 dd7010    ld      (ix+$10),b
8b9c 56        ld      d,(hl)
8b9d 1e04      ld      e,$04
8b9f ed5314d2  ld      ($d214),de
8ba3 23        inc     hl
8ba4 7e        ld      a,(hl)
8ba5 dd360d01  ld      (ix+$0d),$01
8ba9 dd770e    ld      (ix+$0e),a
8bac cd5639    call    _LABEL_3956_11
8baf d4fd35    call    nc,_35fd
8bb2 3a23d2    ld      a,($d223)
8bb5 fe80      cp      $80
8bb7 c0        ret     nz
8bb8 3e1d      ld      a,$1d
8bba ef        rst     $28
8bbb c9        ret     
8bbc 00        nop     
8bbd 010203    ld      bc,$0302
8bc0 04        inc     b
8bc1 05        dec     b
8bc2 0607      ld      b,$07
8bc4 07        rlca    
8bc5 0605      ld      b,$05
8bc7 04        inc     b
8bc8 03        inc     bc
8bc9 02        ld      (bc),a
8bca 010000    ld      bc,$0000
8bcd 08        ex      af,af'
8bce 12        ld      (de),a
8bcf 00        nop     
8bd0 321032    ld      ($3210),a
8bd3 2001      jr------nz,$8bd6
8bd5 3012      jr------nc,$8be9
8bd7 04        inc     b
8bd8 321432    ld      ($3214),a
8bdb 2002      jr------nz,$8bdf
8bdd 3012      jr------nc,$8bf1
8bdf 08        ex      af,af'
8be0 321832    ld      ($3218),a
8be3 2006      jr------nz,$8beb
8be5 3012      jr------nc,$8bf9
8be7 0c        inc     c
8be8 321c32    ld      ($321c),a
8beb 200a      jr------nz,$8bf7
8bed 3012      jr------nc,$8c01
8bef 1032      djnz----$8c23
8bf1 20ff      jr------nz,$8bf2
8bf3 00        nop     
8bf4 0e30      ld      c,$30
8bf6 12        ld      (de),a
8bf7 14        inc     d
8bf8 3220ff    ld      ($ff20),a
8bfb 00        nop     
8bfc 12        ld      (de),a
8bfd 3012      jr------nc,$8c11
8bff 1832      jr------$8c33
8c01 20ff      jr------nz,$8c02
8c03 00        nop     
8c04 1630      ld      d,$30
8c06 12        ld      (de),a
8c07 1c        inc     e
8c08 3220ff    ld      ($ff20),a
8c0b 00        nop     
8c0c 1a        ld      a,(de)
8c0d 3012      jr------nc,$8c21
8c0f 20ff      jr------nz,$8c10
8c11 00        nop     
8c12 ff        rst     $38
8c13 00        nop     
8c14 1e30      ld      e,$30

8c16 ddcb18ae  res     5,(ix+$18)
8c1a dd360d04  ld      (ix+$0d),$04
8c1e dd360e0a  ld      (ix+$0e),$0a
8c22 ddcb1846  bit     0,(ix+$18)
8c26 2046      jr      nz,_8c6e
8c28 dd6e02    ld      l,(ix+$02)
8c2b dd6603    ld      h,(ix+$03)
8c2e 110a00    ld      de,$000a
8c31 19        add     hl,de
8c32 dd7502    ld      (ix+$02),l
8c35 dd7403    ld      (ix+$03),h
8c38 dd7512    ld      (ix+$12),l
8c3b dd7413    ld      (ix+$13),h
8c3e dd6e05    ld      l,(ix+$05)
8c41 dd6606    ld      h,(ix+$06)
8c44 110800    ld      de,$0008
8c47 19        add     hl,de
8c48 dd7505    ld      (ix+$05),l
8c4b dd7406    ld      (ix+$06),h
8c4e dd7514    ld      (ix+$14),l
8c51 dd7415    ld      (ix+$15),h
8c54 dd361196  ld      (ix+$11),$96
8c58 ddcb18c6  set     0,(ix+$18)
8c5c 010000    ld      bc,$0000
8c5f 110000    ld      de,$0000
8c62 cdf936    call    _36f9
8c65 7e        ld      a,(hl)
8c66 fe52      cp      $52
8c68 2804      jr      z,_8c6e
8c6a ddcb18ce  set     1,(ix+$18)
_8c6e:
8c6e dd7e11    ld      a,(ix+$11)
8c71 a7        and     a
8c72 2819      jr      z,_8c8d
8c74 dd3511    dec     (ix+$11)
8c77 2811      jr      z,_8c8a
_8c79:
8c79 af        xor     a
8c7a dd770f    ld      (ix+$0f),a
8c7d dd7710    ld      (ix+$10),a
8c80 dd7707    ld      (ix+$07),a
8c83 dd7708    ld      (ix+$08),a
8c86 dd7709    ld      (ix+$09),a
8c89 c9        ret     
_8c8a:
8c8a 3e18      ld      a,$18
8c8c ef        rst     $28
_8c8d:
8c8d af        xor     a
8c8e ddcb184e  bit     1,(ix+$18)
8c92 2016      jr      nz,_8caa
8c94 dd360700  ld      (ix+$07),$00
8c98 dd3608ff  ld      (ix+$08),$ff
8c9c dd3609ff  ld      (ix+$09),$ff
8ca0 dd360f39  ld      (ix+$0f),$39
8ca4 dd36108d  ld      (ix+$10),$8d
8ca8 1812      jr      _8cbc
_8caa:
8caa dd7707    ld      (ix+$07),a
8cad dd360801  ld      (ix+$08),$01
8cb1 dd7709    ld      (ix+$09),a
8cb4 dd360f41  ld      (ix+$0f),$41
8cb8 dd36108d  ld      (ix+$10),$8d
_8cbc:
8cbc dd770a    ld      (ix+$0a),a
8cbf dd770b    ld      (ix+$0b),a
8cc2 dd770c    ld      (ix+$0c),a
8cc5 ddcb1876  bit     6,(ix+$18)
8cc9 204f      jr      nz,_8d1a
8ccb ddcb187e  bit     7,(ix+$18)
8ccf 2049      jr      nz,_8d1a
8cd1 210204    ld      hl,$0402
8cd4 2214d2    ld      ($d214),hl
8cd7 cd5639    call    _LABEL_3956_11
8cda d4fd35    call    nc,_35fd
8cdd dd5e02    ld      e,(ix+$02)
8ce0 dd5603    ld      d,(ix+$03)
8ce3 2a5ad2    ld      hl,($d25a)
8ce6 01f0ff    ld      bc,$fff0
8ce9 09        add     hl,bc
8cea a7        and     a
8ceb ed52      sbc     hl,de
8ced 302b      jr      nc,_8d1a
8cef 2a5ad2    ld      hl,($d25a)
8cf2 011001    ld      bc,$0110
8cf5 09        add     hl,bc
8cf6 a7        and     a
8cf7 ed52      sbc     hl,de
8cf9 381f      jr      c,_8d1a
8cfb dd5e05    ld      e,(ix+$05)
8cfe dd5606    ld      d,(ix+$06)
8d01 2a5dd2    ld      hl,($d25d)
8d04 01f0ff    ld      bc,$fff0
8d07 09        add     hl,bc
8d08 a7        and     a
8d09 ed52      sbc     hl,de
8d0b 300d      jr      nc,_8d1a
8d0d 2a5dd2    ld      hl,($d25d)
8d10 01d000    ld      bc,$00d0
8d13 09        add     hl,bc
8d14 a7        and     a
8d15 ed52      sbc     hl,de
8d17 3801      jr      c,_8d1a
8d19 c9        ret     
_8d1a:
8d1a dd6e12    ld      l,(ix+$12)
8d1d dd6613    ld      h,(ix+$13)
8d20 dd7502    ld      (ix+$02),l
8d23 dd7403    ld      (ix+$03),h
8d26 dd6e14    ld      l,(ix+$14)
8d29 dd6615    ld      h,(ix+$15)
8d2c dd7505    ld      (ix+$05),l
8d2f dd7406    ld      (ix+$06),h
8d32 dd361196  ld      (ix+$11),$96
8d36 c3798c    jp      _8c79

8d39 2eff      ld      l,$ff
8d3b ff        rst     $38
8d3c ff        rst     $38
8d3d ff        rst     $38
8d3e ff        rst     $38
8d3f ff        rst     $38
8d40 ff        rst     $38
8d41 30ff      jr------nc,$8d42
8d43 ff        rst     $38
8d44 ff        rst     $38
8d45 ff        rst     $38
8d46 ff        rst     $38
8d47 ff        rst     $38

8d48 ddcb18ee  set     5,(ix+$18)
8d4c dd7e11    ld      a,(ix+$11)
8d4f 5f        ld      e,a
8d50 1600      ld      d,$00
8d52 21368e    ld      hl,$8e36
8d55 19        add     hl,de
8d56 5e        ld      e,(hl)
8d57 7a        ld      a,d
8d58 cb7b      bit     7,e
8d5a 2802      jr      z,_8d5e
8d5c 3d        dec     a
8d5d 15        dec     d
_8d5e:
8d5e dd6e04    ld      l,(ix+$04)
8d61 dd6605    ld      h,(ix+$05)
8d64 19        add     hl,de
8d65 dd8e06    adc     a,(ix+$06)
8d68 dd7504    ld      (ix+$04),l
8d6b dd7405    ld      (ix+$05),h
8d6e dd7706    ld      (ix+$06),a
8d71 6c        ld      l,h
8d72 dd6606    ld      h,(ix+$06)
8d75 3a23d2    ld      a,($d223)
8d78 e60f      and     $0f
8d7a 200e      jr      nz,_8d8a
8d7c dd3411    inc     (ix+$11)
8d7f dd7e11    ld      a,(ix+$11)
8d82 fe20      cp      $20
8d84 3804      jr      c,_8d8a
8d86 dd361100  ld      (ix+$11),$00
_8d8a:
8d8a 22dcd2    ld      ($d2dc),hl
8d8d ed5b5dd2  ld      de,($d25d)
8d91 a7        and     a
8d92 3eff      ld      a,$ff
8d94 ed52      sbc     hl,de
8d96 3813      jr      c,_8dab
8d98 eb        ex      de,hl
8d99 210c00    ld      hl,$000c
8d9c 3eff      ld      a,$ff
8d9e ed52      sbc     hl,de
8da0 3009      jr      nc,_8dab
8da2 21b400    ld      hl,$00b4
8da5 af        xor     a
8da6 ed52      sbc     hl,de
8da8 3801      jr      c,_8dab
8daa 7b        ld      a,e
_8dab:
8dab 32dbd2    ld      ($d2db),a
8dae a7        and     a
8daf c8        ret     z
8db0 feff      cp      $ff
8db2 c8        ret     z
8db3 c609      add     a,$09
8db5 6f        ld      l,a
8db6 2600      ld      h,$00
8db8 2214d2    ld      ($d214),hl
8dbb 2a5ad2    ld      hl,($d25a)
8dbe 220ed2    ld      ($d20e),hl
8dc1 2a5dd2    ld      hl,($d25d)
8dc4 2210d2    ld      ($d210),hl
8dc7 fd7e0a    ld      a,(iy+$0a)
8dca 2a3cd2    ld      hl,($d23c)
8dcd f5        push    af
8dce e5        push    hl
8dcf 2100d0    ld      hl,$d000
8dd2 223cd2    ld      ($d23c),hl
8dd5 3a23d2    ld      a,($d223)
8dd8 e603      and     $03
8dda 87        add     a,a
8ddb 87        add     a,a
8ddc 4f        ld      c,a
8ddd 0600      ld      b,$00
8ddf 21168e    ld      hl,$8e16
8de2 09        add     hl,bc
8de3 0604      ld      b,$04
_8de5:
8de5 c5        push    bc
8de6 4e        ld      c,(hl)
8de7 23        inc     hl
8de8 e5        push    hl
8de9 3a23d2    ld      a,($d223)
8dec e60f      and     $0f
8dee 81        add     a,c
8def 6f        ld      l,a
8df0 2600      ld      h,$00
8df2 2212d2    ld      ($d212),hl
8df5 3e00      ld      a,$00
8df7 cd8135    call    _3581
8dfa 2a12d2    ld      hl,($d212)
8dfd 110800    ld      de,$0008
8e00 19        add     hl,de
8e01 2212d2    ld      ($d212),hl
8e04 3e02      ld      a,$02
8e06 cd8135    call    _3581
8e09 e1        pop     hl
8e0a c1        pop     bc
8e0b 10d8      djnz    _8de5
8e0d e1        pop     hl
8e0e f1        pop     af
8e0f 223cd2    ld      ($d23c),hl
8e12 fd770a    ld      (iy+$0a),a
8e15 c9        ret     
8e16 00        nop     
8e17 40        ld      b,b
8e18 80        add     a,b
8e19 c0        ret     nz
8e1a 1050      djnz    _8e6c
8e1c 90        sub     b
8e1d d0        ret     nc
8e1e 2060      jr------nz,$8e80
8e20 a0        and     b
8e21 e0        ret     po
8e22 3070      jr------nc,$8e94
8e24 b0        or      b
8e25 f0        ret     p
8e26 08        ex      af,af'
8e27 48        ld      c,b
8e28 88        adc     a,b
8e29 c8        ret     z
8e2a 1858      jr------$8e84
8e2c 98        sbc     a,b
8e2d d8        ret     c
8e2e 2868      jr------z,$8e98
8e30 a8        xor     b
8e31 e8        ret     pe
8e32 3878      jr------c,$8eac
8e34 b8        cp      b
8e35 f8        ret     m
8e36 fefc      cp      $fc
8e38 f8        ret     m
8e39 f0        ret     p
8e3a e8        ret     pe
8e3b d8        ret     c
8e3c c8        ret     z
8e3d c8        ret     z
8e3e c8        ret     z
8e3f c8        ret     z
8e40 d8        ret     c
8e41 e8        ret     pe
8e42 f0        ret     p
8e43 f8        ret     m
8e44 fcfe02    call----m,$02fe
8e47 04        inc     b
8e48 08        ex      af,af'
8e49 1018      djnz----$8e63
8e4b 2838      jr------z,$8e85
8e4d 3838      jr------c,$8e87
8e4f 3828      jr------c,$8e79
8e51 1810      jr------$8e63
8e53 08        ex      af,af'
8e54 04        inc     b
8e55 02        ld      (bc),a

8e56 ddcb18ee  set     5,(ix+$18)
8e5a dd7e12    ld      a,(ix+$12)
8e5d e67f      and     $7f
8e5f 2011      jr      nz,_8e72
8e61 cd2506    call    _LABEL_625_57
8e64 e607      and     $07
8e66 5f        ld      e,a
8e67 1600      ld      d,$00
8e69 21c28e    ld      hl,$8ec2
_8e6c:
8e6c 19        add     hl,de
8e6d cb46      bit     0,(hl)
8e6f c4eb91    call    nz,_91eb
_8e72:
8e72 dd6e02    ld      l,(ix+$02)
8e75 dd6603    ld      h,(ix+$03)
8e78 220ed2    ld      ($d20e),hl
8e7b dd6e05    ld      l,(ix+$05)
8e7e dd6606    ld      h,(ix+$06)
8e81 2210d2    ld      ($d210),hl
8e84 dd7e11    ld      a,(ix+$11)
8e87 87        add     a,a
8e88 5f        ld      e,a
8e89 1600      ld      d,$00
8e8b 21b68e    ld      hl,$8eb6
8e8e 19        add     hl,de
8e8f 5e        ld      e,(hl)
8e90 ed5312d2  ld      ($d212),de
8e94 23        inc     hl
8e95 5e        ld      e,(hl)
8e96 ed5314d2  ld      ($d214),de
8e9a 3e0c      ld      a,$0c
8e9c cd8135    call    _3581
8e9f dd3412    inc     (ix+$12)
8ea2 3a23d2    ld      a,($d223)
8ea5 e607      and     $07
8ea7 c0        ret     nz
8ea8 dd3411    inc     (ix+$11)
8eab dd7e11    ld      a,(ix+$11)
8eae fe06      cp      $06
8eb0 d8        ret     c
8eb1 dd361100  ld      (ix+$11),$00
8eb5 c9        ret     
8eb6 08        ex      af,af'
8eb7 05        dec     b
8eb8 08        ex      af,af'
8eb9 04        inc     b
8eba 07        rlca    
8ebb 03        inc     bc
_8ebc:
8ebc 0602      ld      b,$02
8ebe 07        rlca    
8ebf 010600    ld      bc,$0006
8ec2 010001    ld      bc,$0100
8ec5 010001    ld      bc,$0100
8ec8 00        nop     
8ec9 01ddcb    ld      bc,$cbdd
8ecc 18ee      jr      _8ebc
8ece af        xor     a
8ecf dd770f    ld      (ix+$0f),a
8ed2 dd7710    ld      (ix+$10),a
8ed5 dd7e11    ld      a,(ix+$11)
8ed8 e60f      and     $0f
8eda 201c      jr      nz,_8ef8
8edc cd2506    call    _LABEL_625_57
8edf 012000    ld      bc,$0020
8ee2 1600      ld      d,$00
8ee4 e63f      and     $3f
8ee6 fe20      cp      $20
8ee8 3805      jr      c,_8eef
8eea 01e0ff    ld      bc,$ffe0
8eed 16ff      ld      d,$ff
_8eef:
8eef dd7107    ld      (ix+$07),c
8ef2 dd7008    ld      (ix+$08),b
8ef5 dd7209    ld      (ix+$09),d
_8ef8:
8ef8 dd360aa0  ld      (ix+$0a),$a0
8efc dd360bff  ld      (ix+$0b),$ff
8f00 dd360cff  ld      (ix+$0c),$ff
8f04 dd6e02    ld      l,(ix+$02)
8f07 dd6603    ld      h,(ix+$03)
8f0a 220ed2    ld      ($d20e),hl
8f0d eb        ex      de,hl
8f0e 2a5ad2    ld      hl,($d25a)
8f11 010800    ld      bc,$0008
8f14 af        xor     a
8f15 ed42      sbc     hl,bc
8f17 3002      jr      nc,_8f1b
8f19 6f        ld      l,a
8f1a 67        ld      h,a
_8f1b:
8f1b a7        and     a
8f1c ed52      sbc     hl,de
8f1e 3036      jr      nc,_8f56
8f20 2a5ad2    ld      hl,($d25a)
8f23 010001    ld      bc,$0100
8f26 09        add     hl,bc
8f27 a7        and     a
8f28 ed52      sbc     hl,de
8f2a 382a      jr      c,_8f56
8f2c dd6e05    ld      l,(ix+$05)
8f2f dd6606    ld      h,(ix+$06)
8f32 2210d2    ld      ($d210),hl
8f35 eb        ex      de,hl
8f36 2adcd2    ld      hl,($d2dc)
8f39 a7        and     a
8f3a ed52      sbc     hl,de
8f3c 3018      jr      nc,_8f56
8f3e 2a5dd2    ld      hl,($d25d)
8f41 01f0ff    ld      bc,$fff0
8f44 09        add     hl,bc
8f45 a7        and     a
8f46 ed52      sbc     hl,de
8f48 300c      jr      nc,_8f56
8f4a 2a5dd2    ld      hl,($d25d)
8f4d 01c000    ld      bc,$00c0
8f50 09        add     hl,bc
8f51 a7        and     a
8f52 ed52      sbc     hl,de
8f54 3004      jr      nc,_8f5a
_8f56:
8f56 dd3600ff  ld      (ix+$00),$ff
_8f5a:
8f5a 210000    ld      hl,$0000
8f5d 2212d2    ld      ($d212),hl
8f60 2214d2    ld      ($d214),hl
8f63 3e0c      ld      a,$0c
8f65 cd8135    call    _3581
8f68 dd3411    inc     (ix+$11)
8f6b c9        ret     
8f6c c9        ret     
8f6d dd360d0c  ld      (ix+$0d),$0c
8f71 dd360e20  ld      (ix+$0e),$20
8f75 210202    ld      hl,$0202
8f78 2214d2    ld      ($d214),hl
8f7b cd5639    call    _LABEL_3956_11
8f7e 210008    ld      hl,$0800
8f81 220ed2    ld      ($d20e),hl
8f84 d4e535    call    nc,_35e5
8f87 dd6e0a    ld      l,(ix+$0a)
8f8a dd660b    ld      h,(ix+$0b)
8f8d dd7e0c    ld      a,(ix+$0c)
8f90 111000    ld      de,$0010
8f93 19        add     hl,de
8f94 ce00      adc     a,$00
8f96 4f        ld      c,a
8f97 faa48f    jp      m,_8fa4
8f9a 7c        ld      a,h
8f9b fe04      cp      $04
8f9d 3805      jr      c,_8fa4
8f9f 210003    ld      hl,$0300
8fa2 0e00      ld      c,$00
_8fa4:
8fa4 dd750a    ld      (ix+$0a),l
8fa7 dd740b    ld      (ix+$0b),h
8faa dd710c    ld      (ix+$0c),c
8fad ddcb1846  bit     0,(ix+$18)
8fb1 c22990    jp      nz,_9029
8fb4 11d0ff    ld      de,$ffd0
8fb7 dd6e02    ld      l,(ix+$02)
8fba dd6603    ld      h,(ix+$03)
8fbd 19        add     hl,de
8fbe ed5bfed3  ld      de,($d3fe)
8fc2 a7        and     a
8fc3 ed52      sbc     hl,de
8fc5 301f      jr      nc,_8fe6
8fc7 013000    ld      bc,$0030
8fca dd6e02    ld      l,(ix+$02)
8fcd dd6603    ld      h,(ix+$03)
8fd0 09        add     hl,bc
8fd1 a7        and     a
8fd2 ed52      sbc     hl,de
8fd4 3810      jr      c,_8fe6
8fd6 ddcb18c6  set     0,(ix+$18)
8fda dd360a80  ld      (ix+$0a),$80
8fde dd360bfd  ld      (ix+$0b),$fd
8fe2 dd360cff  ld      (ix+$0c),$ff
_8fe6:
8fe6 dd6e02    ld      l,(ix+$02)
8fe9 dd6603    ld      h,(ix+$03)
8fec ed5bfed3  ld      de,($d3fe)
8ff0 a7        and     a
8ff1 ed52      sbc     hl,de
8ff3 381a      jr      c,_900f
8ff5 dd3607c0  ld      (ix+$07),$c0
8ff9 dd3608ff  ld      (ix+$08),$ff
8ffd dd3609ff  ld      (ix+$09),$ff
9001 115990    ld      de,$9059
9004 014a90    ld      bc,$904a
9007 cd417c    call    _7c41
900a ddcb18ce  set     1,(ix+$18)
900e c9        ret     
_900f:
900f dd360740  ld      (ix+$07),$40
9013 dd360800  ld      (ix+$08),$00
9017 dd360900  ld      (ix+$09),$00
901b 115990    ld      de,$9059
901e 014590    ld      bc,$9045
9021 cd417c    call    _7c41
9024 ddcb188e  res     1,(ix+$18)
9028 c9        ret     
_9029:
9029 015490    ld      bc,$9054
902c ddcb184e  bit     1,(ix+$18)
9030 2003      jr      nz,_9035
9032 014f90    ld      bc,$904f
_9035:
9035 115990    ld      de,$9059
9038 cd417c    call    _7c41
903b ddcb187e  bit     7,(ix+$18)
903f c8        ret     z
9040 ddcb1886  res     0,(ix+$18)
9044 c9        ret     
9045 00        nop     
9046 04        inc     b
9047 0104ff    ld      bc,$ff04
904a 02        ld      (bc),a
904b 04        inc     b
904c 03        inc     bc
904d 04        inc     b
904e ff        rst     $38
904f 04        inc     b
9050 04        inc     b
9051 04        inc     b
9052 04        inc     b
9053 ff        rst     $38
9054 05        dec     b
9055 04        inc     b
9056 05        dec     b
9057 04        inc     b
9058 ff        rst     $38
9059 44        ld      b,h
905a 46        ld      b,(hl)
905b ff        rst     $38
905c ff        rst     $38
905d ff        rst     $38
905e ff        rst     $38
905f 64        ld      h,h
9060 66        ld      h,(hl)
9061 ff        rst     $38
9062 ff        rst     $38
9063 ff        rst     $38
9064 ff        rst     $38
9065 ff        rst     $38
9066 ff        rst     $38
9067 ff        rst     $38
9068 ff        rst     $38
9069 ff        rst     $38
906a ff        rst     $38
906b 44        ld      b,h
906c 46        ld      b,(hl)
906d ff        rst     $38
906e ff        rst     $38
906f ff        rst     $38
9070 ff        rst     $38
9071 48        ld      c,b
9072 4a        ld      c,d
9073 ff        rst     $38
9074 ff        rst     $38
9075 ff        rst     $38
9076 ff        rst     $38
9077 ff        rst     $38
9078 ff        rst     $38
9079 ff        rst     $38
907a ff        rst     $38
907b ff        rst     $38
907c ff        rst     $38
907d 50        ld      d,b
907e 52        ld      d,d
907f ff        rst     $38
9080 ff        rst     $38
9081 ff        rst     $38
9082 ff        rst     $38
9083 70        ld      (hl),b
9084 72        ld      (hl),d
9085 ff        rst     $38
9086 ff        rst     $38
9087 ff        rst     $38
9088 ff        rst     $38
9089 ff        rst     $38
908a ff        rst     $38
908b ff        rst     $38
908c ff        rst     $38
908d ff        rst     $38
908e ff        rst     $38
908f 50        ld      d,b
9090 52        ld      d,d
9091 ff        rst     $38
9092 ff        rst     $38
9093 ff        rst     $38
9094 ff        rst     $38
9095 4c        ld      c,h
9096 4e        ld      c,(hl)
9097 ff        rst     $38
9098 ff        rst     $38
9099 ff        rst     $38
909a ff        rst     $38
909b ff        rst     $38
909c ff        rst     $38
909d ff        rst     $38
909e ff        rst     $38
909f ff        rst     $38
90a0 ff        rst     $38
90a1 44        ld      b,h
90a2 46        ld      b,(hl)
90a3 ff        rst     $38
90a4 ff        rst     $38
90a5 ff        rst     $38
90a6 ff        rst     $38
90a7 68        ld      l,b
90a8 6a        ld      l,d
90a9 ff        rst     $38
90aa ff        rst     $38
90ab ff        rst     $38
90ac ff        rst     $38
90ad ff        rst     $38
90ae ff        rst     $38
90af ff        rst     $38
90b0 ff        rst     $38
90b1 ff        rst     $38
90b2 ff        rst     $38
90b3 50        ld      d,b
90b4 52        ld      d,d
90b5 ff        rst     $38
90b6 ff        rst     $38
90b7 ff        rst     $38
90b8 ff        rst     $38
90b9 6c        ld      l,h
90ba 6e        ld      l,(hl)
90bb ff        rst     $38
90bc ff        rst     $38
90bd ff        rst     $38
90be ff        rst     $38
90bf ff        rst     $38
90c0 ddcb18ee  set     5,(ix+$18)
90c4 dd360d1e  ld      (ix+$0d),$1e
90c8 dd360e1c  ld      (ix+$0e),$1c
90cc dd360fde  ld      (ix+$0f),$de
90d0 dd361091  ld      (ix+$10),$91
90d4 ddcb184e  bit     1,(ix+$18)
90d8 2026      jr      nz,_9100
90da dd6e02    ld      l,(ix+$02)
90dd dd6603    ld      h,(ix+$03)
90e0 dd7511    ld      (ix+$11),l
90e3 dd7412    ld      (ix+$12),h
90e6 dd6e05    ld      l,(ix+$05)
90e9 dd6606    ld      h,(ix+$06)
90ec 11ffff    ld      de,$ffff
90ef 19        add     hl,de
90f0 dd7505    ld      (ix+$05),l
90f3 dd7406    ld      (ix+$06),h
90f6 dd7513    ld      (ix+$13),l
90f9 dd7414    ld      (ix+$14),h
90fc ddcb18ce  set     1,(ix+$18)
_9100:
9100 011000    ld      bc,$0010
9103 112000    ld      de,$0020
9106 cdf936    call    _36f9
9109 5e        ld      e,(hl)
910a 1600      ld      d,$00
910c 3ad4d2    ld      a,(S1_LEVEL_SOLIDITY)
910f 87        add     a,a
9110 4f        ld      c,a
9111 42        ld      b,d
9112 21653a    ld      hl,S1_SolidityPointers
9115 09        add     hl,bc
9116 7e        ld      a,(hl)
9117 23        inc     hl
9118 66        ld      h,(hl)
9119 6f        ld      l,a
911a 19        add     hl,de
911b 7e        ld      a,(hl)
911c e63f      and     $3f
911e 0e00      ld      c,$00
9120 69        ld      l,c
9121 61        ld      h,c
9122 fe1e      cp      $1e
9124 2822      jr      z,_9148
9126 ddcb1846  bit     0,(ix+$18)
912a 2825      jr      z,_9151
912c dd6e0a    ld      l,(ix+$0a)
912f dd660b    ld      h,(ix+$0b)
9132 dd7e0c    ld      a,(ix+$0c)
9135 11f8ff    ld      de,$fff8
9138 19        add     hl,de
9139 ceff      adc     a,$ff
913b 4f        ld      c,a
913c 7c        ld      a,h
913d ed44      neg     
913f fe02      cp      $02
9141 3805      jr      c,_9148
9143 2100ff    ld      hl,$ff00
9146 0eff      ld      c,$ff
_9148:
9148 dd750a    ld      (ix+$0a),l
914b dd740b    ld      (ix+$0b),h
914e dd710c    ld      (ix+$0c),c
_9151:
9151 dd5e02    ld      e,(ix+$02)
9154 dd5603    ld      d,(ix+$03)
9157 2a5ad2    ld      hl,($d25a)
915a 01e0ff    ld      bc,$ffe0
915d 09        add     hl,bc
915e a7        and     a
915f ed52      sbc     hl,de
9161 3027      jr      nc,_918a
9163 2a5ad2    ld      hl,($d25a)
9166 24        inc     h
9167 a7        and     a
9168 ed52      sbc     hl,de
916a 381e      jr      c,_918a
916c dd5e05    ld      e,(ix+$05)
916f dd5606    ld      d,(ix+$06)
9172 2a5dd2    ld      hl,($d25d)
9175 01e0ff    ld      bc,$ffe0
9178 09        add     hl,bc
9179 a7        and     a
917a ed52      sbc     hl,de
917c 300c      jr      nc,_918a
917e 2a5dd2    ld      hl,($d25d)
9181 01e000    ld      bc,$00e0
9184 09        add     hl,bc
9185 a7        and     a
9186 ed52      sbc     hl,de
9188 302d      jr      nc,_91b7
_918a:
918a dd6e11    ld      l,(ix+$11)
918d dd6612    ld      h,(ix+$12)
9190 dd7502    ld      (ix+$02),l
9193 dd7403    ld      (ix+$03),h
9196 dd6e13    ld      l,(ix+$13)
9199 dd6614    ld      h,(ix+$14)
919c dd7505    ld      (ix+$05),l
919f dd7406    ld      (ix+$06),h
91a2 af        xor     a
91a3 dd7701    ld      (ix+$01),a
91a6 dd7704    ld      (ix+$04),a
91a9 dd770a    ld      (ix+$0a),a
91ac dd770b    ld      (ix+$0b),a
91af dd770c    ld      (ix+$0c),a
91b2 ddcb1886  res     0,(ix+$18)
91b6 c9        ret     
_91b7:
91b7 21020e    ld      hl,$0e02
91ba 2214d2    ld      ($d214),hl
91bd cd5639    call    _LABEL_3956_11
91c0 d8        ret     c
91c1 ddcb18c6  set     0,(ix+$18)
91c5 3a07d4    ld      a,($d407)
91c8 a7        and     a
91c9 f2d191    jp      p,_91d1
91cc ed44      neg     
91ce fe02      cp      $02
91d0 d0        ret     nc
_91d1:
91d1 dd5e0a    ld      e,(ix+$0a)
91d4 dd560b    ld      d,(ix+$0b)
91d7 011000    ld      bc,$0010
91da cdc17c    call    _LABEL_7CC1_12
91dd c9        ret     
91de feff      cp      $ff
91e0 ff        rst     $38
91e1 ff        rst     $38
91e2 ff        rst     $38
91e3 ff        rst     $38
91e4 1618      ld      d,$18
91e6 1a        ld      a,(de)
91e7 1c        inc     e
91e8 ff        rst     $38
91e9 ff        rst     $38
91ea ff        rst     $38

.ASM
.ORGA $91EB
_91eb:
	call    _7c7b
	ret     c
	ld      c,$42
	ld      a,(ix+$00)
	cp      $41
	jr      nz,_9207
	push    hl
	call    _LABEL_625_57
	and     $0f
	ld      e,a
	ld      d,$00
	ld      hl,$9257
	add     hl,de
	ld      c,(hl)
	pop     hl
_9207:
	ld      a,c
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	ld      (ix+$00),a
	xor     a
	ld      (ix+$01),a
	call    _LABEL_625_57
	and     $0f
	ld      l,a
	ld      h,$00
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),$00
	call    _LABEL_625_57
	and     $0f
	ld      l,a
	xor     a
	ld      h,a
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$12),a
	ld      (ix+$18),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	pop     ix
	ret     

.ENDASM
9257 42        ld      b,d
9258 2020      jr------nz,$927a
925a 2042      jr------nz,$929e
925c 2020      jr------nz,$927e
925e 2042      jr------nz,$92a2
9260 2020      jr------nz,$9282
9262 2042      jr------nz,$92a6
9264 2020      jr------nz,$9286
9266 20dd      jr------nz,$9245
9268 cb18      rr      b
926a eedd      xor     $dd
926c 360d      ld      (hl),$0d
926e 20dd      jr------nz,$924d
9270 360e      ld      (hl),$0e
9272 1c        inc     e
9273 cda67c    call    _7ca6
9276 dd360f93  ld      (ix+$0f),$93
927a dd361094  ld      (ix+$10),$94
927e ddcb1846  bit     0,(ix+$18)
9282 202b      jr      nz,_92af
9284 21d002    ld      hl,$02d0
9287 119002    ld      de,$0290
928a cd8c7c    call    _7c8c
928d fdcb09ce  set     1,(iy+$09)

		;UNKNOWN
9291 2108e5    ld      hl,$e508
9294 110020    ld      de,$2000
9297 3e0c      ld      a,12
9299 cd0504    call    decompressArt

929c 211c73    ld      hl,S1_BossPalette
929f 3e02      ld      a,$02
92a1 cd3303    call    loadPaletteOnInterrupt
92a4 af        xor     a
92a5 32ecd2    ld      ($d2ec),a
92a8 3e0b      ld      a,$0b
92aa df        rst     $18
92ab ddcb18c6  set     0,(ix+$18)
_92af:
92af dd7e11    ld      a,(ix+$11)
92b2 a7        and     a
92b3 2026      jr      nz,_92db
92b5 dd7e13    ld      a,(ix+$13)
92b8 87        add     a,a
92b9 87        add     a,a
92ba 5f        ld      e,a
92bb 1600      ld      d,$00
92bd 217b94    ld      hl,$947b
92c0 19        add     hl,de
92c1 7e        ld      a,(hl)
92c2 dd7702    ld      (ix+$02),a
92c5 23        inc     hl
92c6 7e        ld      a,(hl)
92c7 23        inc     hl
92c8 dd7703    ld      (ix+$03),a
92cb 7e        ld      a,(hl)
92cc 23        inc     hl
92cd dd7705    ld      (ix+$05),a
92d0 7e        ld      a,(hl)
92d1 23        inc     hl
92d2 dd7706    ld      (ix+$06),a
92d5 dd3411    inc     (ix+$11)
92d8 c3f793    jp      _93f7
_92db:
92db 3d        dec     a
92dc 2046      jr      nz,_9324
92de dd7e13    ld      a,(ix+$13)
92e1 a7        and     a
92e2 200f      jr      nz,_92f3
92e4 dd360a80  ld      (ix+$0a),$80
92e8 dd360bff  ld      (ix+$0b),$ff
92ec dd360cff  ld      (ix+$0c),$ff
92f0 c3ff92    jp      _92ff
_92f3:
92f3 dd360a80  ld      (ix+$0a),$80
92f7 dd360b00  ld      (ix+$0b),$00
92fb dd360c00  ld      (ix+$0c),$00
_92ff:
92ff 218794    ld      hl,$9487
9302 dd7e13    ld      a,(ix+$13)
9305 87        add     a,a
9306 5f        ld      e,a
9307 1600      ld      d,$00
9309 19        add     hl,de
930a 7e        ld      a,(hl)
930b 23        inc     hl
930c 66        ld      h,(hl)
930d 6f        ld      l,a
930e dd5e05    ld      e,(ix+$05)
9311 dd5606    ld      d,(ix+$06)
9314 a7        and     a
9315 ed52      sbc     hl,de
9317 c2f793    jp      nz,_93f7
931a dd3411    inc     (ix+$11)
931d dd361200  ld      (ix+$12),$00
9321 c3f793    jp      _93f7
_9324:
9324 3d        dec     a
9325 c2ab93    jp      nz,_93ab
9328 af        xor     a
9329 dd770a    ld      (ix+$0a),a
932c dd770b    ld      (ix+$0b),a
932f dd770c    ld      (ix+$0c),a
9332 dd3412    inc     (ix+$12)
9335 dd7e12    ld      a,(ix+$12)
9338 fe64      cp      $64
933a c2f793    jp      nz,_93f7
933d dd3411    inc     (ix+$11)
9340 dd6e02    ld      l,(ix+$02)
9343 dd6603    ld      h,(ix+$03)
9346 110f00    ld      de,$000f
9349 19        add     hl,de
934a 220ed2    ld      ($d20e),hl
934d dd6e05    ld      l,(ix+$05)
9350 dd6606    ld      h,(ix+$06)
9353 012200    ld      bc,$0022
9356 09        add     hl,bc
9357 2210d2    ld      ($d210),hl
935a dd7e13    ld      a,(ix+$13)
935d a7        and     a
935e ca3294    jp      z,_9432
9361 3aecd2    ld      a,($d2ec)
9364 fe08      cp      $08
9366 d2f793    jp      nc,_93f7
9369 cd7b7c    call    _7c7b
936c daf793    jp      c,_93f7
936f dde5      push    ix
9371 e5        push    hl
9372 dde1      pop     ix
9374 af        xor     a
9375 dd36002f  ld      (ix+$00),$2f
9379 2a0ed2    ld      hl,($d20e)
937c dd7701    ld      (ix+$01),a
937f dd7502    ld      (ix+$02),l
9382 dd7403    ld      (ix+$03),h
9385 2a10d2    ld      hl,($d210)
9388 dd7704    ld      (ix+$04),a
938b dd7505    ld      (ix+$05),l
938e dd7406    ld      (ix+$06),h
9391 dd7718    ld      (ix+$18),a
9394 dd7707    ld      (ix+$07),a
9397 dd7708    ld      (ix+$08),a
939a dd7709    ld      (ix+$09),a
939d dd770a    ld      (ix+$0a),a
93a0 dd770b    ld      (ix+$0b),a
93a3 dd770c    ld      (ix+$0c),a
93a6 dde1      pop     ix
93a8 c3f793    jp      _93f7
_93ab:
93ab dd7e13    ld      a,(ix+$13)
93ae a7        and     a
93af 200f      jr      nz,_93c0
93b1 dd360a80  ld      (ix+$0a),$80
93b5 dd360b00  ld      (ix+$0b),$00
93b9 dd360c00  ld      (ix+$0c),$00
93bd c3cc93    jp      _93cc
_93c0:
93c0 dd360a80  ld      (ix+$0a),$80
93c4 dd360bff  ld      (ix+$0b),$ff
93c8 dd360cff  ld      (ix+$0c),$ff
_93cc:
93cc 218d94    ld      hl,$948d
93cf dd7e13    ld      a,(ix+$13)
93d2 87        add     a,a
93d3 5f        ld      e,a
93d4 1600      ld      d,$00
93d6 19        add     hl,de
93d7 7e        ld      a,(hl)
93d8 23        inc     hl
93d9 66        ld      h,(hl)
93da 6f        ld      l,a
93db dd5e05    ld      e,(ix+$05)
93de dd5606    ld      d,(ix+$06)
93e1 af        xor     a
93e2 ed52      sbc     hl,de
93e4 2011      jr      nz,_93f7
93e6 dd7711    ld      (ix+$11),a
93e9 dd3413    inc     (ix+$13)
93ec dd7e13    ld      a,(ix+$13)
93ef fe03      cp      $03
93f1 3804      jr      c,_93f7
93f3 dd361300  ld      (ix+$13),$00
_93f7:
93f7 21a200    ld      hl,$00a2
93fa 2216d2    ld      ($d216),hl
93fd cdbe77    call    _77be
9400 3aecd2    ld      a,($d2ec)
9403 fe08      cp      $08
9405 d0        ret     nc
9406 ddcb0c7e  bit     7,(ix+$0c)
940a c8        ret     z
940b dd6e02    ld      l,(ix+$02)
940e dd6603    ld      h,(ix+$03)
9411 220ed2    ld      ($d20e),hl
9414 dd6e05    ld      l,(ix+$05)
9417 dd6606    ld      h,(ix+$06)
941a 2210d2    ld      ($d210),hl
941d 211000    ld      hl,$0010
9420 2212d2    ld      ($d212),hl
9423 213000    ld      hl,$0030
9426 2214d2    ld      ($d214),hl
9429 3a23d2    ld      a,($d223)
942c e602      and     $02
942e cd8135    call    _3581
9431 c9        ret     
_9432:
9432 dd6e02    ld      l,(ix+$02)
9435 dd6603    ld      h,(ix+$03)
9438 110400    ld      de,$0004
943b 19        add     hl,de
943c 220ed2    ld      ($d20e),hl
943f dd6e05    ld      l,(ix+$05)
9442 dd6606    ld      h,(ix+$06)
9445 11faff    ld      de,$fffa
9448 19        add     hl,de
9449 2210d2    ld      ($d210),hl
944c 2100ff    ld      hl,$ff00
944f 2212d2    ld      ($d212),hl
9452 2100ff    ld      hl,$ff00
9455 2214d2    ld      ($d214),hl
9458 0e04      ld      c,$04
945a cdd185    call    _85d1
945d dd6e02    ld      l,(ix+$02)
9460 dd6603    ld      h,(ix+$03)
9463 112000    ld      de,$0020
9466 19        add     hl,de
9467 220ed2    ld      ($d20e),hl
946a 210001    ld      hl,$0100
946d 2212d2    ld      ($d212),hl
9470 0e04      ld      c,$04
9472 cdd185    call    _85d1
9475 3e01      ld      a,$01
9477 ef        rst     $28
9478 c3f793    jp      _93f7
947b 3c        inc     a
947c 03        inc     bc
947d 60        ld      h,b
947e 03        inc     bc
947f ec0260    call----pe,$6002
9482 02        ld      (bc),a
9483 8c        adc     a,h
9484 03        inc     bc
9485 60        ld      h,b
9486 02        ld      (bc),a
9487 2803      jr      z,_948c
9489 b0        or      b
948a 02        ld      (bc),a
948b b0        or      b
_948c:
948c 02        ld      (bc),a
948d 60        ld      h,b
948e 03        inc     bc
948f 60        ld      h,b
9490 02        ld      (bc),a
9491 60        ld      h,b
9492 02        ld      (bc),a
9493 2022      jr      nz,_94b7
9495 24        inc     h
9496 2628      ld      h,$28
9498 ff        rst     $38
9499 40        ld      b,b
949a 42        ld      b,d
949b 44        ld      b,h
949c 46        ld      b,(hl)
949d 48        ld      c,b
949e ff        rst     $38
949f 60        ld      h,b
94a0 62        ld      h,d
94a1 64        ld      h,h
94a2 66        ld      h,(hl)
94a3 68        ld      l,b
94a4 ff        rst     $38
94a5 ddcb18ee  set     5,(ix+$18)
94a9 dd360d08  ld      (ix+$0d),$08
94ad dd360e0a  ld      (ix+$0e),$0a
94b1 210404    ld      hl,$0404
94b4 2214d2    ld      ($d214),hl
_94b7:
94b7 cd5639    call    _LABEL_3956_11
94ba d4fd35    call    nc,_35fd
94bd ddcb184e  bit     1,(ix+$18)
94c1 201f      jr      nz,_94e2
94c3 ddcb18ce  set     1,(ix+$18)
94c7 2afed3    ld      hl,($d3fe)
94ca 110c00    ld      de,$000c
94cd 19        add     hl,de
94ce eb        ex      de,hl
94cf dd6e02    ld      l,(ix+$02)
94d2 dd6603    ld      h,(ix+$03)
94d5 010800    ld      bc,$0008
94d8 09        add     hl,bc
94d9 a7        and     a
94da ed52      sbc     hl,de
94dc 3004      jr      nc,_94e2
94de ddcb18d6  set     2,(ix+$18)
_94e2:
94e2 ddcb1846  bit     0,(ix+$18)
94e6 2030      jr      nz,_9518
94e8 dd360a40  ld      (ix+$0a),$40
94ec dd360b00  ld      (ix+$0b),$00
94f0 dd360c00  ld      (ix+$0c),$00
94f4 219896    ld      hl,$9698
94f7 ddcb1856  bit     2,(ix+$18)
94fb 2803      jr      z,_9500
94fd 218896    ld      hl,$9688
_9500:
9500 dd750f    ld      (ix+$0f),l
9503 dd7410    ld      (ix+$10),h
9506 2a01d4    ld      hl,($d401)
9509 dd5e05    ld      e,(ix+$05)
950c dd5606    ld      d,(ix+$06)
950f a7        and     a
9510 ed52      sbc     hl,de
9512 d0        ret     nc
9513 ddcb18c6  set     0,(ix+$18)
9517 c9        ret     
_9518:
9518 dd4e02    ld      c,(ix+$02)
951b dd4603    ld      b,(ix+$03)
951e 21f0ff    ld      hl,$fff0
9521 09        add     hl,bc
9522 ed5b5ad2  ld      de,($d25a)
9526 a7        and     a
9527 ed52      sbc     hl,de
9529 3824      jr      c,_954f
952b 69        ld      l,c
952c 60        ld      h,b
952d 14        inc     d
952e a7        and     a
952f ed52      sbc     hl,de
9531 301c      jr      nc,_954f
9533 dd4e05    ld      c,(ix+$05)
9536 dd4606    ld      b,(ix+$06)
9539 21f0ff    ld      hl,$fff0
953c 09        add     hl,bc
953d ed5b5dd2  ld      de,($d25d)
9541 a7        and     a
9542 ed52      sbc     hl,de
9544 3809      jr      c,_954f
9546 21c000    ld      hl,$00c0
9549 19        add     hl,de
954a a7        and     a
954b ed42      sbc     hl,bc
954d 3004      jr      nc,_9553
_954f:
954f dd3600ff  ld      (ix+$00),$ff
_9553:
9553 af        xor     a
9554 210200    ld      hl,$0002
9557 ddcb1856  bit     2,(ix+$18)
955b 2004      jr      nz,_9561
955d 3d        dec     a
955e 21feff    ld      hl,$fffe
_9561:
9561 dd5e07    ld      e,(ix+$07)
9564 dd5608    ld      d,(ix+$08)
9567 19        add     hl,de
9568 dd8e09    adc     a,(ix+$09)
956b 4f        ld      c,a
956c 7c        ld      a,h
956d 110001    ld      de,$0100
9570 cb79      bit     7,c
9572 280b      jr      z,_957f
9574 7d        ld      a,l
9575 2f        cpl     
9576 5f        ld      e,a
9577 7c        ld      a,h
9578 2f        cpl     
9579 57        ld      d,a
957a 13        inc     de
957b 7a        ld      a,d
957c 1100ff    ld      de,$ff00
_957f:
957f a7        and     a
9580 2801      jr      z,_9583
9582 eb        ex      de,hl
_9583:
9583 dd7507    ld      (ix+$07),l
9586 dd7408    ld      (ix+$08),h
9589 dd7109    ld      (ix+$09),c
958c 2a01d4    ld      hl,($d401)
958f 111000    ld      de,$0010
9592 19        add     hl,de
9593 eb        ex      de,hl
9594 dd6e05    ld      l,(ix+$05)
9597 dd6606    ld      h,(ix+$06)
959a 010800    ld      bc,$0008
959d 09        add     hl,bc
959e a7        and     a
959f ed52      sbc     hl,de
95a1 3eff      ld      a,$ff
95a3 21feff    ld      hl,$fffe
95a6 ddcb0c7e  bit     7,(ix+$0c)
95aa 2003      jr      nz,_95af
95ac 21fcff    ld      hl,$fffc
_95af:
95af 300d      jr      nc,_95be
95b1 3c        inc     a
95b2 210200    ld      hl,$0002
95b5 ddcb0c7e  bit     7,(ix+$0c)
95b9 2803      jr      z,_95be
95bb 210400    ld      hl,$0004
_95be:
95be dd5e0a    ld      e,(ix+$0a)
95c1 dd560b    ld      d,(ix+$0b)
95c4 19        add     hl,de
95c5 dd8e0c    adc     a,(ix+$0c)
95c8 4f        ld      c,a
95c9 7c        ld      a,h
95ca 110001    ld      de,$0100
95cd cb79      bit     7,c
95cf 280b      jr      z,_95dc
95d1 7d        ld      a,l
95d2 2f        cpl     
95d3 5f        ld      e,a
95d4 7c        ld      a,h
95d5 2f        cpl     
95d6 57        ld      d,a
95d7 13        inc     de
95d8 7a        ld      a,d
95d9 1100ff    ld      de,$ff00
_95dc:
95dc a7        and     a
95dd 2801      jr      z,_95e0
95df eb        ex      de,hl
_95e0:
95e0 dd750a    ld      (ix+$0a),l
95e3 dd740b    ld      (ix+$0b),h
95e6 dd710c    ld      (ix+$0c),c
95e9 218896    ld      hl,$9688
95ec ddcb097e  bit     7,(ix+$09)
95f0 2803      jr      z,_95f5
95f2 219896    ld      hl,$9698
_95f5:
95f5 e5        push    hl
95f6 dd6e07    ld      l,(ix+$07)
95f9 dd6608    ld      h,(ix+$08)
95fc cb7c      bit     7,h
95fe 2807      jr      z,_9607
9600 7d        ld      a,l
9601 2f        cpl     
9602 6f        ld      l,a
9603 7c        ld      a,h
9604 2f        cpl     
9605 67        ld      h,a
9606 23        inc     hl
_9607:
9607 dd5e11    ld      e,(ix+$11)
960a dd5612    ld      d,(ix+$12)
960d 19        add     hl,de
960e dd7511    ld      (ix+$11),l
9611 dd7412    ld      (ix+$12),h
9614 7c        ld      a,h
9615 e608      and     $08
9617 5f        ld      e,a
9618 1600      ld      d,$00
961a e1        pop     hl
961b 19        add     hl,de
961c dd750f    ld      (ix+$0f),l
961f dd7410    ld      (ix+$10),h
9622 dd6e02    ld      l,(ix+$02)
9625 dd6603    ld      h,(ix+$03)
9628 11f9ff    ld      de,$fff9
962b ddcb097e  bit     7,(ix+$09)
962f 2803      jr      z,_9634
9631 110f00    ld      de,$000f
_9634:
9634 19        add     hl,de
9635 220ed2    ld      ($d20e),hl
9638 dd6e05    ld      l,(ix+$05)
963b dd6606    ld      h,(ix+$06)
963e 2210d2    ld      ($d210),hl
9641 3a23d2    ld      a,($d223)
9644 e60f      and     $0f
9646 c0        ret     nz
9647 cd7b7c    call    _7c7b
964a d8        ret     c
964b dde5      push    ix
964d e5        push    hl
964e dde1      pop     ix
9650 af        xor     a
9651 dd36002a  ld      (ix+$00),$2a
9655 2a0ed2    ld      hl,($d20e)
9658 dd7701    ld      (ix+$01),a
965b dd7502    ld      (ix+$02),l
965e dd7403    ld      (ix+$03),h
9661 2a10d2    ld      hl,($d210)
9664 dd7704    ld      (ix+$04),a
9667 dd7505    ld      (ix+$05),l
966a dd7406    ld      (ix+$06),h
966d dd7711    ld      (ix+$11),a
9670 dd7712    ld      (ix+$12),a
9673 dd7707    ld      (ix+$07),a
9676 dd7708    ld      (ix+$08),a
9679 dd7709    ld      (ix+$09),a
967c dd770a    ld      (ix+$0a),a
967f dd770b    ld      (ix+$0b),a
9682 dd770c    ld      (ix+$0c),a
9685 dde1      pop     ix
9687 c9        ret     
9688 3c        inc     a
9689 3eff      ld      a,$ff
968b ff        rst     $38
968c ff        rst     $38
968d ff        rst     $38
968e ff        rst     $38
968f ff        rst     $38
9690 383a      jr------c,$96cc
9692 ff        rst     $38
9693 ff        rst     $38
9694 ff        rst     $38
9695 ff        rst     $38
9696 ff        rst     $38
9697 ff        rst     $38
9698 56        ld      d,(hl)
9699 58        ld      e,b
969a ff        rst     $38
969b ff        rst     $38
969c ff        rst     $38
969d ff        rst     $38
969e ff        rst     $38
969f ff        rst     $38
96a0 5a        ld      e,d
96a1 5c        ld      e,h
96a2 ff        rst     $38
96a3 ff        rst     $38
96a4 ff        rst     $38
96a5 ff        rst     $38
96a6 ff        rst     $38
96a7 ff        rst     $38
96a8 ddcb18ee  set     5,(ix+$18)
96ac af        xor     a
96ad dd770f    ld      (ix+$0f),a
96b0 dd7710    ld      (ix+$10),a
96b3 dd6e02    ld      l,(ix+$02)
96b6 dd6603    ld      h,(ix+$03)
96b9 220ed2    ld      ($d20e),hl
96bc dd6e05    ld      l,(ix+$05)
96bf dd6606    ld      h,(ix+$06)
96c2 2210d2    ld      ($d210),hl
96c5 6f        ld      l,a
96c6 67        ld      h,a
96c7 2212d2    ld      ($d212),hl
96ca 2214d2    ld      ($d214),hl
96cd dd5e12    ld      e,(ix+$12)
96d0 1600      ld      d,$00
96d2 21f596    ld      hl,$96f5
96d5 19        add     hl,de
96d6 7e        ld      a,(hl)
96d7 cd8135    call    _3581
96da dd3411    inc     (ix+$11)
96dd dd7e11    ld      a,(ix+$11)
96e0 fe0c      cp      $0c
96e2 d8        ret     c
96e3 dd361100  ld      (ix+$11),$00
96e7 dd3412    inc     (ix+$12)
96ea dd7e12    ld      a,(ix+$12)
96ed fe03      cp      $03
96ef d8        ret     c
96f0 dd3600ff  ld      (ix+$00),$ff
96f4 c9        ret     
96f5 1c        inc     e
96f6 1e5e      ld      e,$5e
96f8 ddcb18ee  set     5,(ix+$18)
96fc af        xor     a
96fd dd770f    ld      (ix+$0f),a
9700 dd7710    ld      (ix+$10),a
9703 fd7e0a    ld      a,(iy+$0a)
9706 2a3cd2    ld      hl,($d23c)
9709 f5        push    af
970a e5        push    hl
970b 3aded2    ld      a,($d2de)
970e fe24      cp      $24
9710 3055      jr      nc,_9767
9712 5f        ld      e,a
9713 1600      ld      d,$00
9715 2100d0    ld      hl,$d000
9718 19        add     hl,de
9719 223cd2    ld      ($d23c),hl
971c dd6e02    ld      l,(ix+$02)
971f dd6603    ld      h,(ix+$03)
9722 220ed2    ld      ($d20e),hl
9725 dd6e05    ld      l,(ix+$05)
9728 dd6606    ld      h,(ix+$06)
972b 2210d2    ld      ($d210),hl
972e 210000    ld      hl,$0000
9731 2212d2    ld      ($d212),hl
9734 2214d2    ld      ($d214),hl
9737 dd7e12    ld      a,(ix+$12)
973a a7        and     a
973b 280e      jr      z,_974b
973d fe08      cp      $08
973f 300a      jr      nc,_974b
9741 210400    ld      hl,$0004
9744 2212d2    ld      ($d212),hl
9747 3e0c      ld      a,$0c
9749 1811      jr      _975c
_974b:
974b 3e40      ld      a,$40
974d cd8135    call    _3581
9750 2a12d2    ld      hl,($d212)
9753 110800    ld      de,$0008
9756 19        add     hl,de
9757 2212d2    ld      ($d212),hl
975a 3e42      ld      a,$42
_975c:
975c cd8135    call    _3581
975f 3aded2    ld      a,($d2de)
9762 c606      add     a,$06
9764 32ded2    ld      ($d2de),a
_9767:
9767 e1        pop     hl
9768 f1        pop     af
9769 223cd2    ld      ($d23c),hl
976c fd770a    ld      (iy+$0a),a
976f dd360d0a  ld      (ix+$0d),$0a
9773 dd360e0c  ld      (ix+$0e),$0c
9777 dd7e12    ld      a,(ix+$12)
977a a7        and     a
977b 281a      jr      z,_9797
977d 0e00      ld      c,$00
977f 41        ld      b,c
9780 51        ld      d,c
9781 dd710a    ld      (ix+$0a),c
9784 dd710b    ld      (ix+$0b),c
9787 dd710c    ld      (ix+$0c),c
978a dd3512    dec     (ix+$12)
978d c20998    jp      nz,_9809
9790 dd3600ff  ld      (ix+$00),$ff
9794 c30998    jp      _9809
_9797:
9797 210602    ld      hl,$0206
979a 2214d2    ld      ($d214),hl
979d cd5639    call    _LABEL_3956_11
97a0 3841      jr      c,_97e3
97a2 ed4b01d4  ld      bc,($d401)
97a6 dd5e05    ld      e,(ix+$05)
97a9 dd5606    ld      d,(ix+$06)
97ac 21f8ff    ld      hl,$fff8
97af 19        add     hl,de
97b0 a7        and     a
97b1 ed42      sbc     hl,bc
97b3 302e      jr      nc,_97e3
97b5 210600    ld      hl,$0006
97b8 19        add     hl,de
97b9 a7        and     a
97ba ed42      sbc     hl,bc
97bc 3825      jr      c,_97e3
97be dd7e12    ld      a,(ix+$12)
97c1 a7        and     a
97c2 201f      jr      nz,_97e3
97c4 af        xor     a
97c5 6f        ld      l,a
97c6 67        ld      h,a
97c7 2206d4    ld      ($d406),hl
97ca 3208d4    ld      ($d408),a
97cd 328ed2    ld      ($d28e),a
97d0 229bd2    ld      ($d29b),hl
97d3 fdcb08d6  set     2,(iy+$08)
97d7 3e20      ld      a,$20
97d9 32fbd2    ld      ($d2fb),a
97dc dd361210  ld      (ix+$12),$10
97e0 3e22      ld      a,$22
97e2 ef        rst     $28
_97e3:
97e3 dd360a98  ld      (ix+$0a),$98
97e7 dd360bff  ld      (ix+$0b),$ff
97eb dd360cff  ld      (ix+$0c),$ff
97ef dd7e11    ld      a,(ix+$11)
97f2 e60f      and     $0f
97f4 201c      jr      nz,_9812
97f6 cd2506    call    _LABEL_625_57
97f9 012000    ld      bc,$0020
97fc 1600      ld      d,$00
97fe e63f      and     $3f
9800 fe20      cp      $20
9802 3805      jr      c,_9809
9804 01e0ff    ld      bc,$ffe0
9807 16ff      ld      d,$ff
_9809:
9809 dd7107    ld      (ix+$07),c
980c dd7008    ld      (ix+$08),b
980f dd7209    ld      (ix+$09),d
_9812:
9812 dd6e02    ld      l,(ix+$02)
9815 dd6603    ld      h,(ix+$03)
9818 eb        ex      de,hl
9819 2a5ad2    ld      hl,($d25a)
981c 010800    ld      bc,$0008
981f af        xor     a
9820 ed42      sbc     hl,bc
9822 3002      jr      nc,_9826
9824 6f        ld      l,a
9825 67        ld      h,a
_9826:
9826 a7        and     a
9827 ed52      sbc     hl,de
9829 3033      jr      nc,_985e
982b 2a5ad2    ld      hl,($d25a)
982e 010001    ld      bc,$0100
9831 09        add     hl,bc
9832 a7        and     a
9833 ed52      sbc     hl,de
9835 3827      jr      c,_985e
9837 dd6e05    ld      l,(ix+$05)
983a dd6606    ld      h,(ix+$06)
983d eb        ex      de,hl
983e 2adcd2    ld      hl,($d2dc)
9841 a7        and     a
9842 ed52      sbc     hl,de
9844 3018      jr      nc,_985e
9846 2a5dd2    ld      hl,($d25d)
9849 01f0ff    ld      bc,$fff0
984c 09        add     hl,bc
984d a7        and     a
984e ed52      sbc     hl,de
9850 300c      jr      nc,_985e
9852 2a5dd2    ld      hl,($d25d)
9855 01c000    ld      bc,$00c0
9858 09        add     hl,bc
9859 a7        and     a
985a ed52      sbc     hl,de
985c 3004      jr      nc,_9862
_985e:
985e dd3600ff  ld      (ix+$00),$ff
_9862:
9862 dd3411    inc     (ix+$11)
9865 c9        ret     
9866 ddcb18ee  set     5,(ix+$18)
986a dd360f7e  ld      (ix+$0f),$7e
986e dd36109a  ld      (ix+$10),$9a
9872 fdcb036e  bit     5,(iy+$03)
9876 2013      jr      nz,_988b
9878 dd7e11    ld      a,(ix+$11)
987b dd7712    ld      (ix+$12),a
987e dd7e11    ld      a,(ix+$11)
9881 fe05      cp      $05
9883 300f      jr      nc,_9894
9885 dd3411    inc     (ix+$11)
9888 c39498    jp      _9894
_988b:
988b dd7e11    ld      a,(ix+$11)
988e a7        and     a
988f 2803      jr      z,_9894
9891 dd3511    dec     (ix+$11)
_9894:
9894 dd7e11    ld      a,(ix+$11)
9897 fe01      cp      $01
9899 3038      jr      nc,_98d3
989b 210c14    ld      hl,$140c
989e 2214d2    ld      ($d214),hl
98a1 dd360d1e  ld      (ix+$0d),$1e
98a5 dd360e16  ld      (ix+$0e),$16
98a9 cd5639    call    _LABEL_3956_11
98ac d8        ret     c
98ad 019e99    ld      bc,$999e
98b0 cdaf9a    call    _9aaf
98b3 d0        ret     nc
98b4 3ae8d2    ld      a,($d2e8)
98b7 2ae6d2    ld      hl,($d2e6)
98ba 2206d4    ld      ($d406),hl
98bd 3208d4    ld      ($d408),a
98c0 11fcff    ld      de,$fffc
98c3 2a03d4    ld      hl,($d403)
98c6 3a05d4    ld      a,($d405)
98c9 19        add     hl,de
98ca ceff      adc     a,$ff
98cc 2203d4    ld      ($d403),hl
98cf 3205d4    ld      ($d405),a
98d2 c9        ret     
_98d3:
98d3 fe04      cp      $04
98d5 d25e99    jp      nc,_995e
98d8 dd360f90  ld      (ix+$0f),$90
98dc dd36109a  ld      (ix+$10),$9a
98e0 210f08    ld      hl,$080f
98e3 2214d2    ld      ($d214),hl
98e6 dd360d1e  ld      (ix+$0d),$1e
98ea dd360e16  ld      (ix+$0e),$16
98ee cd5639    call    _LABEL_3956_11
98f1 d8        ret     c
98f2 01be99    ld      bc,$99be
98f5 cdaf9a    call    _9aaf
98f8 d0        ret     nc
98f9 dd7e12    ld      a,(ix+$12)
98fc ddbe11    cp      (ix+$11)
98ff d0        ret     nc
9900 3afed3    ld      a,($d3fe)
9903 c60c      add     a,$0c
9905 e61f      and     $1f
9907 87        add     a,a
9908 4f        ld      c,a
9909 0600      ld      b,$00
990b 21fe99    ld      hl,$99fe
990e 09        add     hl,bc
990f 5e        ld      e,(hl)
9910 23        inc     hl
9911 56        ld      d,(hl)
9912 2a03d4    ld      hl,($d403)
9915 3a05d4    ld      a,($d405)
9918 19        add     hl,de
9919 ceff      adc     a,$ff
991b 2203d4    ld      ($d403),hl
991e 3205d4    ld      ($d405),a
9921 213e9a    ld      hl,$9a3e
9924 09        add     hl,bc
9925 5e        ld      e,(hl)
9926 23        inc     hl
9927 56        ld      d,(hl)
9928 2a06d4    ld      hl,($d406)
992b 7d        ld      a,l
992c 2f        cpl     
992d 6f        ld      l,a
992e 7c        ld      a,h
992f 2f        cpl     
9930 67        ld      h,a
9931 3a08d4    ld      a,($d408)
9934 2f        cpl     
9935 19        add     hl,de
9936 ceff      adc     a,$ff
9938 2206d4    ld      ($d406),hl
993b 3208d4    ld      ($d408),a
993e c9        ret     
993f 3ae8d2    ld      a,($d2e8)
9942 2ae6d2    ld      hl,($d2e6)
9945 2206d4    ld      ($d406),hl
9948 3208d4    ld      ($d408),a
994b 110800    ld      de,$0008
994e 2a03d4    ld      hl,($d403)
9951 3a05d4    ld      a,($d405)
9954 19        add     hl,de
9955 ce00      adc     a,$00
9957 2203d4    ld      ($d403),hl
995a 3205d4    ld      ($d405),a
995d c9        ret     
_995e:
995e dd360fa2  ld      (ix+$0f),$a2
9962 dd36109a  ld      (ix+$10),$9a
9966 211a02    ld      hl,$021a
9969 2214d2    ld      ($d214),hl
996c dd360d1e  ld      (ix+$0d),$1e
9970 dd360e16  ld      (ix+$0e),$16
9974 cd5639    call    _LABEL_3956_11
9977 d8        ret     c
9978 01de99    ld      bc,$99de
997b cdaf9a    call    _9aaf
997e d0        ret     nc
997f 3ae8d2    ld      a,($d2e8)
9982 2ae6d2    ld      hl,($d2e6)
9985 2206d4    ld      ($d406),hl
9988 3208d4    ld      ($d408),a
998b 111a00    ld      de,$001a
998e 2a03d4    ld      hl,($d403)
9991 3a05d4    ld      a,($d405)
9994 19        add     hl,de
9995 ce00      adc     a,$00
9997 2203d4    ld      ($d403),hl
999a 3205d4    ld      ($d405),a
999d c9        ret     
999e ff        rst     $38
999f ff        rst     $38
99a0 fefe      cp      $fe
99a2 fefd      cp      $fd
99a4 fdfdfcfcfc  call----m,$fcfc
99a9 fcfbfb    call----m,$fbfb
99ac fb        ei      
99ad fb        ei      
99ae fafafa    jp------m,$fafa
99b1 fafaf9    jp------m,$f9fa
99b4 f9        ld      sp,hl
99b5 f9        ld      sp,hl
99b6 f9        ld      sp,hl
99b7 f9        ld      sp,hl
99b8 f9        ld      sp,hl
99b9 fafafb    jp------m,$fbfa
99bc fcfeea    call----m,$eafe
99bf eaeaf6    jp------pe,$f6ea
99c2 f7        rst     $30
99c3 f8        ret     m
99c4 f8        ret     m
99c5 f8        ret     m
99c6 f9        ld      sp,hl
99c7 f9        ld      sp,hl
99c8 f9        ld      sp,hl
99c9 fafafa    jp------m,$fafa
99cc fb        ei      
99cd fb        ei      
99ce fb        ei      
99cf fb        ei      
99d0 fcfcfc    call----m,$fcfc
99d3 fcfdfd    call----m,$fdfd
99d6 fdfdfefe  cp      $fe
99da ff        rst     $38
99db 00        nop     
99dc 02        ld      (bc),a
99dd 04        inc     b
99de eaeaea    jp------pe,$eaea
99e1 eaeaea    jp------pe,$eaea
99e4 eaeaea    jp------pe,$eaea
99e7 eaeaea    jp------pe,$eaea
99ea eeed      xor     $ed
99ec ececec    call----pe,$ecec
99ef edee      db      $ed, $ee         ; Undocumented 8 T-State NOP
99f1 ef        rst     $28
99f2 f0        ret     p
99f3 f2f3f4    jp------p,$f4f3
99f6 f5        push    af
99f7 f7        rst     $30
99f8 f8        ret     m
99f9 f9        ld      sp,hl
99fa fafbfd    jp------m,$fdfb
99fd ff        rst     $38
99fe 00        nop     
99ff f8        ret     m
9a00 00        nop     
9a01 f8        ret     m
9a02 00        nop     
9a03 f9        ld      sp,hl
9a04 00        nop     
9a05 fa00fb    jp------m,$fb00
9a08 00        nop     
9a09 fce0fc    call----m,$fce0
9a0c 80        add     a,b
9a0d fdc0      ret     nz
9a0f fd00      nop     
9a11 fe40      cp      $40
9a13 fe80      cp      $80
9a15 fec0      cp      $c0
9a17 fe00      cp      $00
9a19 ff        rst     $38
9a1a 20ff      jr------nz,$9a1b
9a1c 40        ld      b,b
9a1d ff        rst     $38
9a1e 60        ld      h,b
9a1f ff        rst     $38
9a20 80        add     a,b
9a21 ff        rst     $38
9a22 a0        and     b
9a23 ff        rst     $38
9a24 c0        ret     nz
9a25 ff        rst     $38
9a26 e0        ret     po
9a27 ff        rst     $38
9a28 e8        ret     pe
9a29 ff        rst     $38
9a2a eaffec    jp------pe,$ecff
9a2d ff        rst     $38
9a2e eeff      xor     $ff
9a30 f0        ret     p
9a31 ff        rst     $38
9a32 f2fff4    jp------p,$f4ff
9a35 ff        rst     $38
9a36 f6ff      or      $ff
9a38 f8        ret     m
9a39 ff        rst     $38
9a3a fcfffe    call----m,$feff
9a3d ff        rst     $38
9a3e 00        nop     
9a3f fc00fc    call----m,$fc00
9a42 00        nop     
9a43 fc00fb    call----m,$fb00
9a46 00        nop     
9a47 fa00f9    jp------m,$f900
9a4a 00        nop     
9a4b f8        ret     m
9a4c 00        nop     
9a4d f7        rst     $30
9a4e 00        nop     
9a4f f680      or      $80
9a51 f5        push    af
9a52 00        nop     
9a53 f5        push    af
9a54 c0        ret     nz
9a55 f480f4    call----p,$f480
9a58 40        ld      b,b
9a59 f400f4    call----p,$f400
9a5c 00        nop     
9a5d f400f4    call----p,$f400
9a60 00        nop     
9a61 f440f4    call----p,$f440
9a64 80        add     a,b
9a65 f4c0f4    call----p,$f4c0
9a68 00        nop     
9a69 f5        push    af
9a6a 00        nop     
9a6b f600      or      $00
9a6d f7        rst     $30
9a6e 00        nop     
9a6f f9        ld      sp,hl
9a70 00        nop     
9a71 fa00fc    jp------m,$fc00
9a74 80        add     a,b
9a75 fc00fd    call----m,$fd00
9a78 c0        ret     nz
9a79 fd00      nop     
9a7b ff        rst     $38
9a7c 00        nop     
9a7d ff        rst     $38
9a7e feff      cp      $ff
9a80 ff        rst     $38
9a81 ff        rst     $38
9a82 ff        rst     $38
9a83 ff        rst     $38
9a84 383a      jr------c,$9ac0
9a86 3c        inc     a
9a87 3eff      ld      a,$ff
9a89 ff        rst     $38
9a8a ff        rst     $38
9a8b ff        rst     $38
9a8c ff        rst     $38
9a8d ff        rst     $38
9a8e ff        rst     $38
9a8f ff        rst     $38
9a90 48        ld      c,b
9a91 4a        ld      c,d
9a92 4c        ld      c,h
9a93 4e        ld      c,(hl)
9a94 ff        rst     $38
9a95 ff        rst     $38
9a96 68        ld      l,b
9a97 6a        ld      l,d
9a98 6c        ld      l,h
9a99 6e        ld      l,(hl)
9a9a ff        rst     $38
9a9b ff        rst     $38
9a9c ff        rst     $38
9a9d ff        rst     $38
9a9e ff        rst     $38
9a9f ff        rst     $38
9aa0 ff        rst     $38
9aa1 ff        rst     $38
9aa2 fe12      cp      $12
9aa4 14        inc     d
9aa5 16ff      ld      d,$ff
9aa7 ff        rst     $38
9aa8 fe32      cp      $32
9aaa 34        inc     (hl)
9aab 36ff      ld      (hl),$ff
9aad ff        rst     $38
9aae ff        rst     $38

_9aaf:
9aaf 3a08d4    ld      a,($d408)
9ab2 a7        and     a
9ab3 f8        ret     m
9ab4 3afed3    ld      a,($d3fe)
9ab7 c60c      add     a,$0c
9ab9 e61f      and     $1f
9abb 6f        ld      l,a
9abc 2600      ld      h,$00
9abe 09        add     hl,bc
9abf 0600      ld      b,$00
9ac1 4e        ld      c,(hl)
9ac2 cb79      bit     7,c
9ac4 2801      jr      z,_9ac7
9ac6 05        dec     b
_9ac7:
9ac7 dd6e05    ld      l,(ix+$05)
9aca dd6606    ld      h,(ix+$06)
9acd 09        add     hl,bc
9ace 2201d4    ld      ($d401),hl
9ad1 3a07d4    ld      a,($d407)
9ad4 fe03      cp      $03
9ad6 3002      jr      nc,_9ada
9ad8 37        scf     
9ad9 c9        ret    
_9ada: 
9ada 110100    ld      de,$0001
9add 2a06d4    ld      hl,($d406)
9ae0 7d        ld      a,l
9ae1 2f        cpl     
9ae2 6f        ld      l,a
9ae3 7c        ld      a,h
9ae4 2f        cpl     
9ae5 67        ld      h,a
9ae6 3a08d4    ld      a,($d408)
9ae9 2f        cpl     
9aea 19        add     hl,de
9aeb ce00      adc     a,$00
9aed cb2f      sra     a
9aef cb1c      rr      h
9af1 cb1d      rr      l
9af3 2206d4    ld      ($d406),hl
9af6 3208d4    ld      ($d408),a
9af9 a7        and     a
9afa c9        ret     
9afb ddcb18ee  set     5,(ix+$18)
9aff dd360d1c  ld      (ix+$0d),$1c
9b03 dd360e06  ld      (ix+$0e),$06
9b07 dd360f6e  ld      (ix+$0f),$6e
9b0b dd36109b  ld      (ix+$10),$9b
9b0f 210100    ld      hl,$0001
9b12 dd7e12    ld      a,(ix+$12)
9b15 fe60      cp      $60
9b17 3003      jr      nc,_9b1c
9b19 21ffff    ld      hl,$ffff
_9b1c:
9b1c dd360700  ld      (ix+$07),$00
9b20 dd7508    ld      (ix+$08),l
9b23 dd7409    ld      (ix+$09),h
9b26 3c        inc     a
9b27 fec0      cp      $c0
9b29 3801      jr      c,_9b2c
9b2b af        xor     a
_9b2c:
9b2c dd7712    ld      (ix+$12),a
9b2f dd7e11    ld      a,(ix+$11)
9b32 a7        and     a
9b33 2035      jr      nz,_9b6a
9b35 210206    ld      hl,$0602
9b38 2214d2    ld      ($d214),hl
9b3b cd5639    call    _LABEL_3956_11
9b3e d8        ret     c
9b3f 3ae8d2    ld      a,($d2e8)
9b42 ed5be6d2  ld      de,($d2e6)
9b46 4f        ld      c,a
9b47 2a06d4    ld      hl,($d406)
9b4a 7d        ld      a,l
9b4b 2f        cpl     
9b4c 6f        ld      l,a
9b4d 7c        ld      a,h
9b4e 2f        cpl     
9b4f 67        ld      h,a
9b50 3a08d4    ld      a,($d408)
9b53 2f        cpl     
9b54 19        add     hl,de
9b55 89        adc     a,c
9b56 110100    ld      de,$0001
9b59 19        add     hl,de
9b5a ce00      adc     a,$00
9b5c 2206d4    ld      ($d406),hl
9b5f 3208d4    ld      ($d408),a
9b62 dd361108  ld      (ix+$11),$08
9b66 3e07      ld      a,$07
9b68 ef        rst     $28
9b69 c9        ret     
_9b6a:
9b6a dd3511    dec     (ix+$11)
9b6d c9        ret     
9b6e 08        ex      af,af'
9b6f 0a        ld      a,(bc)
9b70 282a      jr      z,_9b9c
9b72 ff        rst     $38
9b73 ff        rst     $38
9b74 ff        rst     $38

_9b75:
9b75 ddcb18ee  set     5,(ix+$18)
9b79 dd360d1e  ld      (ix+$0d),$1e
9b7d dd360e60  ld      (ix+$0e),$60
9b81 210000    ld      hl,$0000
9b84 2214d2    ld      ($d214),hl
9b87 cd5639    call    _LABEL_3956_11
9b8a 3845      jr      c,_9bd1
9b8c dd6e02    ld      l,(ix+$02)
9b8f dd6603    ld      h,(ix+$03)
9b92 7d        ld      a,l
9b93 87        add     a,a
9b94 cb14      rl      h
9b96 87        add     a,a
9b97 cb14      rl      h
9b99 87        add     a,a
9b9a cb14      rl      h
_9b9c:
9b9c 5c        ld      e,h
9b9d dd6e05    ld      l,(ix+$05)
9ba0 dd6606    ld      h,(ix+$06)
9ba3 7d        ld      a,l
9ba4 87        add     a,a
9ba5 cb14      rl      h
9ba7 87        add     a,a
9ba8 cb14      rl      h
9baa 87        add     a,a
9bab cb14      rl      h
9bad 54        ld      d,h
9bae 21d99b    ld      hl,$9bd9
9bb1 0605      ld      b,$05
_9bb3:
9bb3 7e        ld      a,(hl)
9bb4 23        inc     hl
9bb5 bb        cp      e
9bb6 2015      jr      nz,_9bcd
9bb8 7e        ld      a,(hl)
9bb9 ba        cp      d
9bba 2011      jr      nz,_9bcd
9bbc 23        inc     hl
9bbd 7e        ld      a,(hl)
9bbe 32d3d2    ld      ($d2d3),a
9bc1 3e01      ld      a,$01
9bc3 3289d2    ld      ($d289),a
9bc6 fdcb06e6  set     4,(iy+$06)
9bca c3d19b    jp      _9bd1
_9bcd:
9bcd 23        inc     hl
9bce 23        inc     hl
9bcf 10e2      djnz    _9bb3
_9bd1:
9bd1 af        xor     a
9bd2 dd770f    ld      (ix+$0f),a
9bd5 dd7710    ld      (ix+$10),a
9bd8 c9        ret     
9bd9 7d        ld      a,l
9bda 1a        ld      a,(de)
9bdb 15        dec     d
9bdc 7d        ld      a,l
9bdd 011401    ld      bc,$0114
9be0 3c        inc     a
9be1 1801      jr      _9be4
9be3 02        ld      (bc),a
_9be4:
9be4 19        add     hl,de
9be5 14        inc     d
9be6 0f        rrca    
9be7 1a        ld      a,(de)
9be8 dd360780  ld      (ix+$07),$80
9bec dd360801  ld      (ix+$08),$01
9bf0 dd360900  ld      (ix+$09),$00
9bf4 dd360f69  ld      (ix+$0f),$69
9bf8 dd36109c  ld      (ix+$10),$9c
_9bfc:
9bfc ddcb18ee  set     5,(ix+$18)
9c00 ddcb1846  bit     0,(ix+$18)
9c04 2013      jr      nz,_9c19
9c06 dd7e02    ld      a,(ix+$02)
9c09 dd7711    ld      (ix+$11),a
9c0c dd7e03    ld      a,(ix+$03)
9c0f dd7712    ld      (ix+$12),a
9c12 3e18      ld      a,$18
9c14 ef        rst     $28
9c15 ddcb18c6  set     0,(ix+$18)
_9c19:
9c19 dd360d06  ld      (ix+$0d),$06
9c1d dd360e08  ld      (ix+$0e),$08
9c21 dd7e13    ld      a,(ix+$13)
9c24 fe64      cp      $64
9c26 300c      jr      nc,_9c34
9c28 210004    ld      hl,$0400
9c2b 2214d2    ld      ($d214),hl
9c2e cd5639    call    _LABEL_3956_11
9c31 d4fd35    call    nc,_35fd
_9c34:
9c34 dd3413    inc     (ix+$13)
9c37 dd7e13    ld      a,(ix+$13)
9c3a fe64      cp      $64
9c3c d8        ret     c
9c3d fef0      cp      $f0
9c3f 3817      jr      c,_9c58
9c41 af        xor     a
9c42 dd7701    ld      (ix+$01),a
9c45 dd7713    ld      (ix+$13),a
9c48 dd7e11    ld      a,(ix+$11)
9c4b dd7702    ld      (ix+$02),a
9c4e dd7e12    ld      a,(ix+$12)
9c51 dd7703    ld      (ix+$03),a
9c54 3e18      ld      a,$18
9c56 ef        rst     $28
9c57 c9        ret     
_9c58:
9c58 af        xor     a
9c59 dd770f    ld      (ix+$0f),a
9c5c dd7710    ld      (ix+$10),a
9c5f dd7707    ld      (ix+$07),a
9c62 dd7708    ld      (ix+$08),a
9c65 dd7709    ld      (ix+$09),a
9c68 c9        ret     
9c69 0c        inc     c
9c6a 0eff      ld      c,$ff
9c6c ff        rst     $38
9c6d ff        rst     $38
9c6e ff        rst     $38
9c6f ff        rst     $38
9c70 dd360780  ld      (ix+$07),$80
9c74 dd3608fe  ld      (ix+$08),$fe
9c78 dd3609ff  ld      (ix+$09),$ff
9c7c dd360f87  ld      (ix+$0f),$87
9c80 dd36109c  ld      (ix+$10),$9c
9c84 c3fc9b    jp      _9bfc
9c87 2c        inc     l
9c88 2eff      ld      l,$ff
9c8a ff        rst     $38
9c8b ff        rst     $38
9c8c ff        rst     $38
9c8d ff        rst     $38
9c8e ddcb18ee  set     5,(ix+$18)
9c92 ddcb1846  bit     0,(ix+$18)
9c96 202a      jr      nz,_9cc2
9c98 dd6e02    ld      l,(ix+$02)
9c9b dd6603    ld      h,(ix+$03)
9c9e 110c00    ld      de,$000c
9ca1 19        add     hl,de
9ca2 dd7502    ld      (ix+$02),l
9ca5 dd7403    ld      (ix+$03),h
9ca8 dd6e05    ld      l,(ix+$05)
9cab dd6606    ld      h,(ix+$06)
9cae 111200    ld      de,$0012
9cb1 19        add     hl,de
9cb2 dd7505    ld      (ix+$05),l
9cb5 dd7406    ld      (ix+$06),h
9cb8 cd2506    call    _LABEL_625_57
9cbb dd7711    ld      (ix+$11),a
9cbe ddcb18c6  set     0,(ix+$18)
_9cc2:
9cc2 dd6e02    ld      l,(ix+$02)
9cc5 dd6603    ld      h,(ix+$03)
9cc8 220ed2    ld      ($d20e),hl
9ccb dd6e05    ld      l,(ix+$05)
9cce dd6606    ld      h,(ix+$06)
9cd1 2210d2    ld      ($d210),hl
9cd4 210000    ld      hl,$0000
9cd7 2212d2    ld      ($d212),hl
9cda dd7e11    ld      a,(ix+$11)
9cdd cb3f      srl     a
9cdf cb3f      srl     a
9ce1 cb3f      srl     a
9ce3 cb3f      srl     a
9ce5 4f        ld      c,a
9ce6 0600      ld      b,$00
9ce8 87        add     a,a
9ce9 5f        ld      e,a
9cea 1600      ld      d,$00
9cec 216a9d    ld      hl,$9d6a
9cef 09        add     hl,bc
9cf0 7e        ld      a,(hl)
9cf1 dd770e    ld      (ix+$0e),a
9cf4 dd360d06  ld      (ix+$0d),$06
9cf8 214a9d    ld      hl,$9d4a
9cfb 19        add     hl,de
9cfc 7e        ld      a,(hl)
9cfd 23        inc     hl
9cfe 66        ld      h,(hl)
9cff 6f        ld      l,a
9d00 b4        or      h
9d01 2833      jr      z,_9d36
9d03 dd7e11    ld      a,(ix+$11)
9d06 87        add     a,a
9d07 87        add     a,a
9d08 87        add     a,a
9d09 e61f      and     $1f
9d0b 5f        ld      e,a
9d0c 1600      ld      d,$00
9d0e 19        add     hl,de
9d0f 0604      ld      b,$04
_9d11:
9d11 c5        push    bc
9d12 7e        ld      a,(hl)
9d13 23        inc     hl
9d14 5e        ld      e,(hl)
9d15 23        inc     hl
9d16 1600      ld      d,$00
9d18 e5        push    hl
9d19 ed5314d2  ld      ($d214),de
9d1d cd8135    call    _3581
9d20 e1        pop     hl
9d21 c1        pop     bc
9d22 10ed      djnz    _9d11
9d24 dd7e0e    ld      a,(ix+$0e)
9d27 a7        and     a
9d28 280c      jr      z,_9d36
9d2a 210202    ld      hl,$0202
9d2d 2214d2    ld      ($d214),hl
9d30 cd5639    call    _LABEL_3956_11
9d33 d4fd35    call    nc,_35fd
_9d36:
9d36 dd3411    inc     (ix+$11)
9d39 af        xor     a
9d3a dd770f    ld      (ix+$0f),a
9d3d dd7710    ld      (ix+$10),a
9d40 dd7e11    ld      a,(ix+$11)
9d43 fe70      cp      $70
9d45 c0        ret     nz
9d46 3e17      ld      a,$17
9d48 ef        rst     $28
9d49 c9        ret     
9d4a 00        nop     
9d4b 00        nop     
9d4c 00        nop     
9d4d 00        nop     
9d4e 00        nop     
9d4f 00        nop     
9d50 00        nop     
9d51 00        nop     
9d52 00        nop     
9d53 00        nop     
9d54 00        nop     
9d55 00        nop     
9d56 00        nop     
9d57 00        nop     
9d58 9a        sbc     a,d
9d59 9d        sbc     a,l
9d5a ba        cp      d
9d5b 9d        sbc     a,l
9d5c da9d7a    jp------c,$7a9d
9d5f 9d        sbc     a,l
9d60 7a        ld      a,d
9d61 9d        sbc     a,l
9d62 7a        ld      a,d
9d63 9d        sbc     a,l
9d64 da9dba    jp------c,$ba9d
9d67 9d        sbc     a,l
9d68 9a        sbc     a,d
9d69 9d        sbc     a,l
9d6a 00        nop     
9d6b 00        nop     
9d6c 00        nop     
9d6d 00        nop     
9d6e 00        nop     
9d6f 00        nop     
9d70 00        nop     
9d71 1b        dec     de
9d72 1f        rra     
9d73 222525    ld      ($2525),hl
9d76 25        dec     h
9d77 221f1b    ld      ($1b1f),hl
9d7a 00        nop     
9d7b 15        dec     d
9d7c 1e0e      ld      e,$0e
9d7e 1e07      ld      e,$07
9d80 1e00      ld      e,$00
9d82 00        nop     
9d83 17        rla     
9d84 1e10      ld      e,$10
9d86 1e09      ld      e,$09
9d88 1e02      ld      e,$02
9d8a 00        nop     
9d8b 19        add     hl,de
9d8c 1e12      ld      e,$12
9d8e 1e0b      ld      e,$0b
9d90 1e04      ld      e,$04
9d92 00        nop     
9d93 1b        dec     de
9d94 1e14      ld      e,$14
9d96 1e0d      ld      e,$0d
9d98 1e06      ld      e,$06
9d9a 00        nop     
9d9b 0c        inc     c
9d9c 1e08      ld      e,$08
9d9e 1e04      ld      e,$04
9da0 1e00      ld      e,$00
9da2 00        nop     
9da3 0e1e      ld      c,$1e
9da5 0a        ld      a,(bc)
9da6 1e06      ld      e,$06
9da8 1e02      ld      e,$02
9daa 00        nop     
9dab 101e      djnz----$9dcb
9dad 0c        inc     c
9dae 1e08      ld      e,$08
9db0 1e04      ld      e,$04
9db2 00        nop     
9db3 111e0e    ld      de,$0e1e
9db6 1e0a      ld      e,$0a
9db8 1e06      ld      e,$06
9dba 00        nop     
9dbb 0f        rrca    
9dbc 1e0a      ld      e,$0a
9dbe 1e05      ld      e,$05
9dc0 1e00      ld      e,$00
9dc2 00        nop     
9dc3 111e0c    ld      de,$0c1e
9dc6 1e07      ld      e,$07
9dc8 1e02      ld      e,$02
9dca 00        nop     
9dcb 13        inc     de
9dcc 1e0e      ld      e,$0e
9dce 1e09      ld      e,$09
9dd0 1e04      ld      e,$04
9dd2 00        nop     
9dd3 15        dec     d
9dd4 1e10      ld      e,$10
9dd6 1e0b      ld      e,$0b
9dd8 1e06      ld      e,$06
9dda 00        nop     
9ddb 12        ld      (de),a
9ddc 1e0c      ld      e,$0c
9dde 1e06      ld      e,$06
9de0 1e00      ld      e,$00
9de2 00        nop     
9de3 14        inc     d
9de4 1e0e      ld      e,$0e
9de6 1e08      ld      e,$08
9de8 1e02      ld      e,$02
9dea 00        nop     
9deb 161e      ld      d,$1e
9ded 101e      djnz----$9e0d
9def 0a        ld      a,(bc)
9df0 1e04      ld      e,$04
9df2 00        nop     
9df3 181e      jr------$9e13
9df5 12        ld      (de),a
9df6 1e0c      ld      e,$0c
9df8 1e06      ld      e,$06

9dfa ddcb18ee  set     5,(ix+$18)
9dfe cdd49e    call    _9ed4
9e01 dd7e11    ld      a,(ix+$11)
9e04 fe28      cp      $28
9e06 302b      jr      nc,_9e33
9e08 210500    ld      hl,$0005
9e0b 2214d2    ld      ($d214),hl
9e0e cd5639    call    _LABEL_3956_11
9e11 3820      jr      c,_9e33
9e13 110500    ld      de,$0005
9e16 3a05d4    ld      a,($d405)
9e19 a7        and     a
9e1a fa209e    jp      m,_9e20
9e1d 11ecff    ld      de,$ffec
_9e20:
9e20 dd6e02    ld      l,(ix+$02)
9e23 dd6603    ld      h,(ix+$03)
9e26 19        add     hl,de
9e27 22fed3    ld      ($d3fe),hl
9e2a af        xor     a
9e2b 6f        ld      l,a
9e2c 67        ld      h,a
9e2d 2203d4    ld      ($d403),hl
9e30 3205d4    ld      ($d405),a
_9e33:
9e33 dd6e02    ld      l,(ix+$02)
9e36 dd6603    ld      h,(ix+$03)
9e39 11c8ff    ld      de,$ffc8
9e3c 19        add     hl,de
9e3d ed5bfed3  ld      de,($d3fe)
9e41 af        xor     a
9e42 ed52      sbc     hl,de
9e44 3032      jr      nc,_9e78
9e46 dd6e02    ld      l,(ix+$02)
9e49 dd6603    ld      h,(ix+$03)
9e4c a7        and     a
9e4d ed52      sbc     hl,de
9e4f 3827      jr      c,_9e78
9e51 dd6e05    ld      l,(ix+$05)
9e54 dd6606    ld      h,(ix+$06)
9e57 11e0ff    ld      de,$ffe0
9e5a 19        add     hl,de
9e5b ed5b01d4  ld      de,($d401)
9e5f af        xor     a
9e60 ed52      sbc     hl,de
9e62 3014      jr      nc,_9e78
9e64 dd6e05    ld      l,(ix+$05)
9e67 dd6606    ld      h,(ix+$06)
9e6a 015000    ld      bc,$0050
9e6d 09        add     hl,bc
9e6e a7        and     a
9e6f ed52      sbc     hl,de
9e71 3805      jr      c,_9e78
9e73 cdb49e    call    _9eb4
9e76 1803      jr      _9e7b
_9e78:
9e78 cdc49e    call    _9ec4
_9e7b:
9e7b 112b9f    ld      de,$9f2b
_9e7e:
9e7e dd7e11    ld      a,(ix+$11)
9e81 e60f      and     $0f
9e83 4f        ld      c,a
9e84 0600      ld      b,$00
9e86 dd6e12    ld      l,(ix+$12)
9e89 dd6613    ld      h,(ix+$13)
9e8c a7        and     a
9e8d ed42      sbc     hl,bc
9e8f dd7505    ld      (ix+$05),l
9e92 dd7406    ld      (ix+$06),h
9e95 dd7e11    ld      a,(ix+$11)
9e98 cb3f      srl     a
9e9a cb3f      srl     a
9e9c cb3f      srl     a
9e9e cb3f      srl     a
9ea0 e603      and     $03
9ea2 87        add     a,a
9ea3 4f        ld      c,a
9ea4 87        add     a,a
9ea5 87        add     a,a
9ea6 87        add     a,a
9ea7 81        add     a,c
9ea8 4f        ld      c,a
9ea9 0600      ld      b,$00
9eab eb        ex      de,hl
9eac 09        add     hl,bc
9ead dd750f    ld      (ix+$0f),l
9eb0 dd7410    ld      (ix+$10),h
9eb3 c9        ret     

_9eb4:
9eb4 dd7e11    ld      a,(ix+$11)
9eb7 fe30      cp      $30
9eb9 d0        ret     nc
9eba 3c        inc     a
9ebb dd7711    ld      (ix+$11),a
9ebe 3d        dec     a
9ebf c0        ret     nz
9ec0 3e19      ld      a,$19
9ec2 ef        rst     $28
9ec3 c9        ret     

_9ec4:
9ec4 dd7e11    ld      a,(ix+$11)
9ec7 a7        and     a
9ec8 c8        ret     z
9ec9 3d        dec     a
9eca dd7711    ld      (ix+$11),a
9ecd fe2f      cp      $2f
9ecf c0        ret     nz
9ed0 3e19      ld      a,$19
9ed2 ef        rst     $28
9ed3 c9        ret     

_9ed4:
9ed4 dd360d04  ld      (ix+$0d),$04
9ed8 dd7e11    ld      a,(ix+$11)
9edb cb3f      srl     a
9edd cb3f      srl     a
9edf cb3f      srl     a
9ee1 cb3f      srl     a
9ee3 e603      and     $03
9ee5 5f        ld      e,a
9ee6 3e03      ld      a,$03
9ee8 93        sub     e
9ee9 87        add     a,a
9eea 87        add     a,a
9eeb 87        add     a,a
9eec 87        add     a,a
9eed dd770e    ld      (ix+$0e),a
9ef0 ddcb1846  bit     0,(ix+$18)
9ef4 c0        ret     nz
9ef5 010000    ld      bc,$0000
9ef8 11f0ff    ld      de,$fff0
9efb cdf936    call    _36f9
9efe 111400    ld      de,$0014
9f01 7e        ld      a,(hl)
9f02 fea3      cp      $a3
9f04 2807      jr      z,_9f0d
9f06 110400    ld      de,$0004
9f09 ddcb18ce  set     1,(ix+$18)
_9f0d:
9f0d dd6e02    ld      l,(ix+$02)
9f10 dd6603    ld      h,(ix+$03)
9f13 19        add     hl,de
9f14 dd7502    ld      (ix+$02),l
9f17 dd7403    ld      (ix+$03),h
9f1a dd7e05    ld      a,(ix+$05)
9f1d dd7712    ld      (ix+$12),a
9f20 dd7e06    ld      a,(ix+$06)
9f23 dd7713    ld      (ix+$13),a
9f26 ddcb18c6  set     0,(ix+$18)
9f2a c9        ret     
9f2b 0a        ld      a,(bc)
9f2c ff        rst     $38
9f2d ff        rst     $38
9f2e ff        rst     $38
9f2f ff        rst     $38
9f30 ff        rst     $38
9f31 3eff      ld      a,$ff
9f33 ff        rst     $38
9f34 ff        rst     $38
9f35 ff        rst     $38
9f36 ff        rst     $38
9f37 0a        ld      a,(bc)
9f38 ff        rst     $38
9f39 ff        rst     $38
9f3a ff        rst     $38
9f3b ff        rst     $38
9f3c ff        rst     $38
9f3d 3eff      ld      a,$ff
9f3f ff        rst     $38
9f40 ff        rst     $38
9f41 ff        rst     $38
9f42 ff        rst     $38
9f43 0a        ld      a,(bc)
9f44 ff        rst     $38
9f45 ff        rst     $38
9f46 ff        rst     $38
9f47 ff        rst     $38
9f48 ff        rst     $38
9f49 ff        rst     $38
9f4a ff        rst     $38
9f4b ff        rst     $38
9f4c ff        rst     $38
9f4d ff        rst     $38
9f4e ff        rst     $38
9f4f 0a        ld      a,(bc)
9f50 ff        rst     $38
9f51 ff        rst     $38
9f52 ff        rst     $38
9f53 ff        rst     $38
9f54 ff        rst     $38
9f55 ff        rst     $38
9f56 ff        rst     $38
9f57 ff        rst     $38
9f58 ff        rst     $38
9f59 ff        rst     $38
9f5a ff        rst     $38
9f5b ff        rst     $38
9f5c ff        rst     $38
9f5d ff        rst     $38
9f5e ff        rst     $38
9f5f ff        rst     $38
9f60 ff        rst     $38
9f61 ff        rst     $38
9f62 ddcb18ee  set     5,(ix+$18)
9f66 cdd49e    call    _9ed4
9f69 dd7e11    ld      a,(ix+$11)
9f6c fe28      cp      $28
9f6e 302c      jr      nc,_9f9c
9f70 210500    ld      hl,$0005
9f73 2214d2    ld      ($d214),hl
9f76 cd5639    call    _LABEL_3956_11
9f79 3821      jr      c,_9f9c
9f7b 110500    ld      de,$0005
9f7e 3a05d4    ld      a,($d405)
9f81 a7        and     a
9f82 fa889f    jp      m,_9f88
9f85 11ecff    ld      de,$ffec
_9f88:
9f88 dd6e02    ld      l,(ix+$02)
9f8b dd6603    ld      h,(ix+$03)
9f8e 19        add     hl,de
9f8f 22fed3    ld      ($d3fe),hl
9f92 af        xor     a
9f93 3203d4    ld      ($d403),a
9f96 3204d4    ld      ($d404),a
9f99 3205d4    ld      ($d405),a
_9f9c:
9f9c dd6e02    ld      l,(ix+$02)
9f9f dd6603    ld      h,(ix+$03)
9fa2 11f0ff    ld      de,$fff0
9fa5 19        add     hl,de
9fa6 ed5bfed3  ld      de,($d3fe)
9faa af        xor     a
9fab ed52      sbc     hl,de
9fad 3036      jr      nc,_9fe5
9faf dd6e02    ld      l,(ix+$02)
9fb2 dd6603    ld      h,(ix+$03)
9fb5 012400    ld      bc,$0024
9fb8 09        add     hl,bc
9fb9 a7        and     a
9fba ed52      sbc     hl,de
9fbc 3827      jr      c,_9fe5
9fbe dd6e05    ld      l,(ix+$05)
9fc1 dd6606    ld      h,(ix+$06)
9fc4 11e0ff    ld      de,$ffe0
9fc7 19        add     hl,de
9fc8 ed5b01d4  ld      de,($d401)
9fcc af        xor     a
9fcd ed52      sbc     hl,de
9fcf 3014      jr      nc,_9fe5
9fd1 dd6e05    ld      l,(ix+$05)
9fd4 dd6606    ld      h,(ix+$06)
9fd7 015000    ld      bc,$0050
9fda 09        add     hl,bc
9fdb a7        and     a
9fdc ed52      sbc     hl,de
9fde 3805      jr      c,_9fe5
9fe0 cdb49e    call    _9eb4
9fe3 1803      jr      _9fe8
_9fe5:
9fe5 cdc49e    call    _9ec4
_9fe8:
9fe8 11ee9f    ld      de,$9fee
9feb c37e9e    jp      _9e7e
9fee 36ff      ld      (hl),$ff
9ff0 ff        rst     $38
9ff1 ff        rst     $38
9ff2 ff        rst     $38
9ff3 ff        rst     $38
9ff4 3eff      ld      a,$ff
9ff6 ff        rst     $38
9ff7 ff        rst     $38
9ff8 ff        rst     $38
9ff9 ff        rst     $38
9ffa 36ff      ld      (hl),$ff
9ffc ff        rst     $38
9ffd ff        rst     $38
9ffe ff        rst     $38
9fff ff        rst     $38
a000 3eff      ld      a,$ff
a002 ff        rst     $38
a003 ff        rst     $38
a004 ff        rst     $38
a005 ff        rst     $38
a006 36ff      ld      (hl),$ff
a008 ff        rst     $38
a009 ff        rst     $38
a00a ff        rst     $38
a00b ff        rst     $38
a00c ff        rst     $38
a00d ff        rst     $38
a00e ff        rst     $38
a00f ff        rst     $38
a010 ff        rst     $38
a011 ff        rst     $38
a012 36ff      ld      (hl),$ff
a014 ff        rst     $38
a015 ff        rst     $38
a016 ff        rst     $38
a017 ff        rst     $38
a018 ff        rst     $38
a019 ff        rst     $38
a01a ff        rst     $38
a01b ff        rst     $38
a01c ff        rst     $38
a01d ff        rst     $38
a01e ff        rst     $38
a01f ff        rst     $38
a020 ff        rst     $38
a021 ff        rst     $38
a022 ff        rst     $38
a023 ff        rst     $38
a024 ff        rst     $38
a025 ddcb18ee  set     5,(ix+$18)
a029 cdd49e    call    _9ed4
a02c dd7e11    ld      a,(ix+$11)
a02f fe28      cp      $28
a031 302c      jr      nc,_a05f
a033 210500    ld      hl,$0005
a036 2214d2    ld      ($d214),hl
a039 cd5639    call    _LABEL_3956_11
a03c 3821      jr      c,_a05f
a03e 110500    ld      de,$0005
a041 3a05d4    ld      a,($d405)
a044 a7        and     a
a045 fa4ba0    jp      m,_a04b
a048 11ecff    ld      de,$ffec
_a04b:
a04b dd6e02    ld      l,(ix+$02)
a04e dd6603    ld      h,(ix+$03)
a051 19        add     hl,de
a052 22fed3    ld      ($d3fe),hl
a055 af        xor     a
a056 3203d4    ld      ($d403),a
a059 3204d4    ld      ($d404),a
a05c 3205d4    ld      ($d405),a
_a05f:
a05f dd6e02    ld      l,(ix+$02)
a062 dd6603    ld      h,(ix+$03)
a065 11c8ff    ld      de,$ffc8
a068 19        add     hl,de
a069 ed5bfed3  ld      de,($d3fe)
a06d af        xor     a
a06e ed52      sbc     hl,de
a070 3036      jr      nc,_a0a8
a072 dd6e02    ld      l,(ix+$02)
a075 dd6603    ld      h,(ix+$03)
a078 012400    ld      bc,$0024
a07b 09        add     hl,bc
a07c a7        and     a
a07d ed52      sbc     hl,de
a07f 3827      jr      c,_a0a8
a081 dd6e05    ld      l,(ix+$05)
a084 dd6606    ld      h,(ix+$06)
a087 11e0ff    ld      de,$ffe0
a08a 19        add     hl,de
a08b ed5b01d4  ld      de,($d401)
a08f af        xor     a
a090 ed52      sbc     hl,de
a092 3014      jr      nc,_a0a8
a094 dd6e05    ld      l,(ix+$05)
a097 dd6606    ld      h,(ix+$06)
a09a 015000    ld      bc,$0050
a09d 09        add     hl,bc
a09e a7        and     a
a09f ed52      sbc     hl,de
a0a1 3805      jr      c,_a0a8
a0a3 cdb49e    call    _9eb4
a0a6 1803      jr      _a0ab
_a0a8:
a0a8 cdc49e    call    _9ec4
_a0ab:
a0ab 11b1a0    ld      de,$a0b1
a0ae c37e9e    jp      _9e7e

a0b1 38ff      jr------c,$a0b2
a0b3 ff        rst     $38
a0b4 ff        rst     $38
a0b5 ff        rst     $38
a0b6 ff        rst     $38
a0b7 3eff      ld      a,$ff
a0b9 ff        rst     $38
a0ba ff        rst     $38
a0bb ff        rst     $38
a0bc ff        rst     $38
a0bd 38ff      jr------c,$a0be
a0bf ff        rst     $38
a0c0 ff        rst     $38
a0c1 ff        rst     $38
a0c2 ff        rst     $38
a0c3 3eff      ld      a,$ff
a0c5 ff        rst     $38
a0c6 ff        rst     $38
a0c7 ff        rst     $38
a0c8 ff        rst     $38
a0c9 38ff      jr------c,$a0ca
a0cb ff        rst     $38
a0cc ff        rst     $38
a0cd ff        rst     $38
a0ce ff        rst     $38
a0cf ff        rst     $38
a0d0 ff        rst     $38
a0d1 ff        rst     $38
a0d2 ff        rst     $38
a0d3 ff        rst     $38
a0d4 ff        rst     $38
a0d5 38ff      jr------c,$a0d6
a0d7 ff        rst     $38
a0d8 ff        rst     $38
a0d9 ff        rst     $38
a0da ff        rst     $38
a0db ff        rst     $38
a0dc ff        rst     $38
a0dd ff        rst     $38
a0de ff        rst     $38
a0df ff        rst     $38
a0e0 ff        rst     $38
a0e1 ff        rst     $38
a0e2 ff        rst     $38
a0e3 ff        rst     $38
a0e4 ff        rst     $38
a0e5 ff        rst     $38
a0e6 ff        rst     $38
a0e7 ff        rst     $38
a0e8 ddcb18ee  set     5,(ix+$18)
a0ec dd360d30  ld      (ix+$0d),$30
a0f0 dd360e10  ld      (ix+$0e),$10
a0f4 ddcb1846  bit     0,(ix+$18)
a0f8 2024      jr      nz,_a11e
a0fa dd6e02    ld      l,(ix+$02)
a0fd dd6603    ld      h,(ix+$03)
a100 111800    ld      de,$0018
a103 19        add     hl,de
a104 dd7502    ld      (ix+$02),l
a107 dd7403    ld      (ix+$03),h
a10a dd6e05    ld      l,(ix+$05)
a10d dd6606    ld      h,(ix+$06)
a110 111000    ld      de,$0010
a113 19        add     hl,de
a114 dd7505    ld      (ix+$05),l
a117 dd7406    ld      (ix+$06),h
a11a ddcb18c6  set     0,(ix+$18)
_a11e:
a11e dd7e11    ld      a,(ix+$11)
a121 fe64      cp      $64
a123 381d      jr      c,_a142
a125 2003      jr      nz,_a12a
a127 3e13      ld      a,$13
a129 ef        rst     $28
_a12a:
a12a 210000    ld      hl,$0000
a12d 2214d2    ld      ($d214),hl
a130 cd5639    call    _LABEL_3956_11
a133 d4fd35    call    nc,_35fd
a136 1173a1    ld      de,$a173
a139 0167a1    ld      bc,$a167
a13c cd417c    call    _7c41
a13f c359a1    jp      _a159
_a142:
a142 fe46      cp      $46
a144 300a      jr      nc,_a150
a146 af        xor     a
a147 dd770f    ld      (ix+$0f),a
a14a dd7710    ld      (ix+$10),a
a14d c359a1    jp      _a159
_a150:
a150 1173a1    ld      de,$a173
a153 016ea1    ld      bc,$a16e
a156 cd417c    call    _7c41
_a159:
a159 dd3411    inc     (ix+$11)
a15c dd7e11    ld      a,(ix+$11)
a15f fea0      cp      $a0
a161 d8        ret     c
a162 dd361100  ld      (ix+$11),$00
a166 c9        ret     
a167 00        nop     
a168 010101    ld      bc,$0101
a16b 02        ld      (bc),a
a16c 01ff02    ld      bc,$02ff
a16f 010301    ld      bc,$0103
a172 ff        rst     $38
a173 02        ld      (bc),a
a174 04        inc     b
a175 ff        rst     $38
a176 ff        rst     $38
a177 ff        rst     $38
a178 ff        rst     $38
a179 ff        rst     $38
a17a ff        rst     $38
a17b ff        rst     $38
a17c ff        rst     $38
a17d ff        rst     $38
a17e ff        rst     $38
a17f ff        rst     $38
a180 ff        rst     $38
a181 ff        rst     $38
a182 ff        rst     $38
a183 ff        rst     $38
a184 ff        rst     $38
a185 fefe      cp      $fe
a187 fefe      cp      $fe
a189 02        ld      (bc),a
a18a 04        inc     b
a18b ff        rst     $38
a18c ff        rst     $38
a18d ff        rst     $38
a18e ff        rst     $38
a18f ff        rst     $38
a190 ff        rst     $38
a191 ff        rst     $38
a192 ff        rst     $38
a193 ff        rst     $38
a194 ff        rst     $38
a195 ff        rst     $38
a196 ff        rst     $38
a197 fefe      cp      $fe
a199 1618      ld      d,$18
a19b ff        rst     $38
a19c ff        rst     $38
a19d ff        rst     $38
a19e ff        rst     $38
a19f ff        rst     $38
a1a0 ff        rst     $38
a1a1 ff        rst     $38
a1a2 ff        rst     $38
a1a3 ff        rst     $38
a1a4 ff        rst     $38
a1a5 ff        rst     $38
a1a6 ff        rst     $38
a1a7 ff        rst     $38
a1a8 ff        rst     $38
a1a9 ff        rst     $38
a1aa dd360d0a  ld      (ix+$0d),$0a
a1ae dd360e20  ld      (ix+$0e),$20
a1b2 210308    ld      hl,$0803
a1b5 2214d2    ld      ($d214),hl
a1b8 cd5639    call    _LABEL_3956_11
a1bb 21000e    ld      hl,$0e00
a1be 220ed2    ld      ($d20e),hl
a1c1 d4e535    call    nc,_35e5
a1c4 dd360a00  ld      (ix+$0a),$00
a1c8 dd360b01  ld      (ix+$0b),$01
a1cc dd360c00  ld      (ix+$0c),$00
a1d0 dd6e02    ld      l,(ix+$02)
a1d3 dd6603    ld      h,(ix+$03)
a1d6 110a00    ld      de,$000a
a1d9 19        add     hl,de
a1da eb        ex      de,hl
a1db 2afed3    ld      hl,($d3fe)
a1de 010c00    ld      bc,$000c
a1e1 09        add     hl,bc
a1e2 a7        and     a
a1e3 ed52      sbc     hl,de
a1e5 3076      jr      nc,_a25d
a1e7 01d2a2    ld      bc,$a2d2
a1ea dd7e11    ld      a,(ix+$11)
a1ed feeb      cp      $eb
a1ef 3809      jr      c,_a1fa
a1f1 2004      jr      nz,_a1f7
a1f3 dd361600  ld      (ix+$16),$00
_a1f7:
a1f7 01d7a2    ld      bc,$a2d7
_a1fa:
a1fa 11daa2    ld      de,$a2da
a1fd cd417c    call    _7c41
a200 dd7e11    ld      a,(ix+$11)
a203 feed      cp      $ed
a205 c2cea2    jp      nz,_a2ce
a208 cd7b7c    call    _7c7b
a20b dacea2    jp      c,_a2ce
a20e dd5e02    ld      e,(ix+$02)
a211 dd5603    ld      d,(ix+$03)
a214 dd4e05    ld      c,(ix+$05)
a217 dd4606    ld      b,(ix+$06)
a21a dde5      push    ix
a21c e5        push    hl
a21d dde1      pop     ix
a21f af        xor     a
a220 dd36001c  ld      (ix+$00),$1c
a224 dd7701    ld      (ix+$01),a
a227 dd7302    ld      (ix+$02),e
a22a dd7203    ld      (ix+$03),d
a22d 210600    ld      hl,$0006
a230 09        add     hl,bc
a231 dd7704    ld      (ix+$04),a
a234 dd7505    ld      (ix+$05),l
a237 dd7406    ld      (ix+$06),h
a23a dd7711    ld      (ix+$11),a
a23d dd7716    ld      (ix+$16),a
a240 dd7717    ld      (ix+$17),a
a243 dd7707    ld      (ix+$07),a
a246 dd3608ff  ld      (ix+$08),$ff
a24a dd3609ff  ld      (ix+$09),$ff
a24e dd770a    ld      (ix+$0a),a
a251 dd360b01  ld      (ix+$0b),$01
a255 dd770c    ld      (ix+$0c),a
a258 dde1      pop     ix
a25a c3cea2    jp      _a2ce
_a25d:
a25d 01d2a2    ld      bc,$a2d2
a260 dd7e11    ld      a,(ix+$11)
a263 feeb      cp      $eb
a265 3809      jr      c,_a270
a267 2004      jr      nz,_a26d
a269 dd361600  ld      (ix+$16),$00
_a26d:
a26d 01d7a2    ld      bc,$a2d7
_a270:
a270 110ba3    ld      de,$a30b
a273 cd417c    call    _7c41
a276 dd7e11    ld      a,(ix+$11)
a279 feed      cp      $ed
a27b 2051      jr      nz,_a2ce
a27d cd7b7c    call    _7c7b
a280 dacea2    jp      c,_a2ce
a283 dd5e02    ld      e,(ix+$02)
a286 dd5603    ld      d,(ix+$03)
a289 dd4e05    ld      c,(ix+$05)
a28c dd4606    ld      b,(ix+$06)
a28f dde5      push    ix
a291 e5        push    hl
a292 dde1      pop     ix
a294 af        xor     a
a295 dd36001c  ld      (ix+$00),$1c
a299 dd7701    ld      (ix+$01),a
a29c dd7302    ld      (ix+$02),e
a29f dd7203    ld      (ix+$03),d
a2a2 210600    ld      hl,$0006
a2a5 09        add     hl,bc
a2a6 dd7704    ld      (ix+$04),a
a2a9 dd7505    ld      (ix+$05),l
a2ac dd7406    ld      (ix+$06),h
a2af dd7711    ld      (ix+$11),a
a2b2 dd7716    ld      (ix+$16),a
a2b5 dd7717    ld      (ix+$17),a
a2b8 dd7707    ld      (ix+$07),a
a2bb dd360801  ld      (ix+$08),$01
a2bf dd7709    ld      (ix+$09),a
a2c2 dd770a    ld      (ix+$0a),a
a2c5 dd360b01  ld      (ix+$0b),$01
a2c9 dd770c    ld      (ix+$0c),a
a2cc dde1      pop     ix
_a2ce:
a2ce dd3411    inc     (ix+$11)
a2d1 c9        ret
     
a2d2 00        nop     
a2d3 1c        inc     e
a2d4 0106ff    ld      bc,$ff06
a2d7 02        ld      (bc),a
a2d8 18ff      jr------$a2d9
a2da 40        ld      b,b
a2db 42        ld      b,d
a2dc ff        rst     $38
a2dd ff        rst     $38
a2de ff        rst     $38
a2df ff        rst     $38
a2e0 60        ld      h,b
a2e1 62        ld      h,d
a2e2 ff        rst     $38
a2e3 ff        rst     $38
a2e4 ff        rst     $38
a2e5 ff        rst     $38
a2e6 ff        rst     $38
a2e7 ff        rst     $38
a2e8 ff        rst     $38
a2e9 ff        rst     $38
a2ea ff        rst     $38
a2eb ff        rst     $38
a2ec 44        ld      b,h
a2ed 46        ld      b,(hl)
a2ee ff        rst     $38
a2ef ff        rst     $38
a2f0 ff        rst     $38
a2f1 ff        rst     $38
a2f2 64        ld      h,h
a2f3 66        ld      h,(hl)
a2f4 ff        rst     $38
a2f5 ff        rst     $38
a2f6 ff        rst     $38
a2f7 ff        rst     $38
a2f8 ff        rst     $38
a2f9 ff        rst     $38
a2fa ff        rst     $38
a2fb ff        rst     $38
a2fc ff        rst     $38
a2fd ff        rst     $38
a2fe 40        ld      b,b
a2ff 42        ld      b,d
a300 ff        rst     $38
a301 ff        rst     $38
a302 ff        rst     $38
a303 ff        rst     $38
a304 68        ld      l,b
a305 6a        ld      l,d
a306 ff        rst     $38
a307 ff        rst     $38
a308 ff        rst     $38
a309 ff        rst     $38
a30a ff        rst     $38
a30b 50        ld      d,b
a30c 52        ld      d,d
a30d ff        rst     $38
a30e ff        rst     $38
a30f ff        rst     $38
a310 ff        rst     $38
a311 70        ld      (hl),b
a312 72        ld      (hl),d
a313 ff        rst     $38
a314 ff        rst     $38
a315 ff        rst     $38
a316 ff        rst     $38
a317 ff        rst     $38
a318 ff        rst     $38
a319 ff        rst     $38
a31a ff        rst     $38
a31b ff        rst     $38
a31c ff        rst     $38
a31d 4c        ld      c,h
a31e 4e        ld      c,(hl)
a31f ff        rst     $38
a320 ff        rst     $38
a321 ff        rst     $38
a322 ff        rst     $38
a323 6c        ld      l,h
a324 6e        ld      l,(hl)
a325 ff        rst     $38
a326 ff        rst     $38
a327 ff        rst     $38
a328 ff        rst     $38
a329 ff        rst     $38
a32a ff        rst     $38
a32b ff        rst     $38
a32c ff        rst     $38
a32d ff        rst     $38
a32e ff        rst     $38
a32f 50        ld      d,b
a330 52        ld      d,d
a331 ff        rst     $38
a332 ff        rst     $38
a333 ff        rst     $38
a334 ff        rst     $38
a335 48        ld      c,b
a336 4a        ld      c,d
a337 ff        rst     $38
a338 ff        rst     $38
a339 ff        rst     $38
a33a ff        rst     $38
a33b ff        rst     $38
a33c ddcb18ae  res     5,(ix+$18)
a340 dd360d0a  ld      (ix+$0d),$0a
a344 dd360e0f  ld      (ix+$0e),$0f
a348 210101    ld      hl,$0101
a34b 2214d2    ld      ($d214),hl
a34e cd5639    call    _LABEL_3956_11
a351 d4fd35    call    nc,_35fd
a354 ddcb187e  bit     7,(ix+$18)
a358 280c      jr      z,_a366
a35a dd360a00  ld      (ix+$0a),$00
a35e dd360bfd  ld      (ix+$0b),$fd
a362 dd360cff  ld      (ix+$0c),$ff
_a366:
a366 dd6e0a    ld      l,(ix+$0a)
a369 dd660b    ld      h,(ix+$0b)
a36c dd7e0c    ld      a,(ix+$0c)
a36f 111f00    ld      de,$001f
a372 19        add     hl,de
a373 ce00      adc     a,$00
a375 dd750a    ld      (ix+$0a),l
a378 dd740b    ld      (ix+$0b),h
a37b dd770c    ld      (ix+$0c),a
a37e dd7e11    ld      a,(ix+$11)
a381 fe82      cp      $82
a383 300c      jr      nc,_a391
a385 01b1a3    ld      bc,$a3b1
a388 11bba3    ld      de,$a3bb
a38b cd417c    call    _7c41
a38e c3a3a3    jp      _a3a3
_a391:
a391 2007      jr      nz,_a39a
a393 dd361600  ld      (ix+$16),$00
a397 3e01      ld      a,$01
a399 ef        rst     $28
_a39a:
a39a 01b4a3    ld      bc,$a3b4
a39d 11bba3    ld      de,$a3bb
a3a0 cd417c    call    _7c41
_a3a3:
a3a3 dd3411    inc     (ix+$11)
a3a6 dd7e11    ld      a,(ix+$11)
a3a9 fea5      cp      $a5
a3ab d8        ret     c
a3ac dd3600ff  ld      (ix+$00),$ff
a3b0 c9        ret     
a3b1 00        nop     
a3b2 08        ex      af,af'
a3b3 ff        rst     $38
a3b4 010c02    ld      bc,$020c
a3b7 0c        inc     c
a3b8 03        inc     bc
a3b9 0c        inc     c
a3ba ff        rst     $38
a3bb 2022      jr------nz,$a3df
a3bd ff        rst     $38
a3be ff        rst     $38
a3bf ff        rst     $38
a3c0 ff        rst     $38
a3c1 ff        rst     $38
a3c2 ff        rst     $38
a3c3 ff        rst     $38
a3c4 ff        rst     $38
a3c5 ff        rst     $38
a3c6 ff        rst     $38
a3c7 ff        rst     $38
a3c8 ff        rst     $38
a3c9 ff        rst     $38
a3ca ff        rst     $38
a3cb ff        rst     $38
a3cc ff        rst     $38
a3cd 74        ld      (hl),h
a3ce 76        halt    
a3cf ff        rst     $38
a3d0 ff        rst     $38
a3d1 ff        rst     $38
a3d2 ff        rst     $38
a3d3 ff        rst     $38
a3d4 ff        rst     $38
a3d5 ff        rst     $38
a3d6 ff        rst     $38
a3d7 ff        rst     $38
a3d8 ff        rst     $38
a3d9 ff        rst     $38
a3da ff        rst     $38
a3db ff        rst     $38
a3dc ff        rst     $38
a3dd ff        rst     $38
a3de ff        rst     $38
a3df 78        ld      a,b
a3e0 7a        ld      a,d
a3e1 ff        rst     $38
a3e2 ff        rst     $38
a3e3 ff        rst     $38
a3e4 ff        rst     $38
a3e5 ff        rst     $38
a3e6 ff        rst     $38
a3e7 ff        rst     $38
a3e8 ff        rst     $38
a3e9 ff        rst     $38
a3ea ff        rst     $38
a3eb ff        rst     $38
a3ec ff        rst     $38
a3ed ff        rst     $38
a3ee ff        rst     $38
a3ef ff        rst     $38
a3f0 ff        rst     $38
a3f1 7c        ld      a,h
a3f2 7e        ld      a,(hl)
a3f3 ff        rst     $38
a3f4 ff        rst     $38
a3f5 ff        rst     $38
a3f6 ff        rst     $38
a3f7 ff        rst     $38
a3f8 dd360d0a  ld      (ix+$0d),$0a
a3fc dd360e11  ld      (ix+$0e),$11
a400 ddcb1846  bit     0,(ix+$18)
a404 2014      jr      nz,_a41a
a406 dd6e02    ld      l,(ix+$02)
a409 dd6603    ld      h,(ix+$03)
a40c 110800    ld      de,$0008
a40f 19        add     hl,de
a410 dd7502    ld      (ix+$02),l
a413 dd7403    ld      (ix+$03),h
a416 ddcb18c6  set     0,(ix+$18)
_a41a:
a41a 210100    ld      hl,$0001
a41d 2214d2    ld      ($d214),hl
a420 cd5639    call    _LABEL_3956_11
a423 383f      jr      c,_a464
a425 3a08d4    ld      a,($d408)
a428 a7        and     a
a429 fa64a4    jp      m,_a464
a42c dd360f8b  ld      (ix+$0f),$8b
a430 dd3610a4  ld      (ix+$10),$a4
a434 3ad4d2    ld      a,(S1_LEVEL_SOLIDITY)
a437 fe03      cp      $03
a439 2008      jr      nz,_a443
a43b dd360f9b  ld      (ix+$0f),$9b
a43f dd3610a4  ld      (ix+$10),$a4
_a443:
a443 010600    ld      bc,$0006
a446 110000    ld      de,$0000
a449 cdc17c    call    _LABEL_7CC1_12
a44c ddcb184e  bit     1,(ix+$18)
a450 202d      jr      nz,_a47f
a452 ddcb18ce  set     1,(ix+$18)
a456 2117d3    ld      hl,$d317
a459 cd020c    call    _LABEL_C02_135
a45c 7e        ld      a,(hl)
a45d a9        xor     c
a45e 77        ld      (hl),a
a45f 3e1a      ld      a,$1a
a461 ef        rst     $28
a462 181b      jr      _a47f
_a464:
a464 ddcb188e  res     1,(ix+$18)
a468 dd360f93  ld      (ix+$0f),$93
a46c dd3610a4  ld      (ix+$10),$a4
a470 3ad4d2    ld      a,(S1_LEVEL_SOLIDITY)
a473 fe03      cp      $03
a475 2008      jr      nz,_a47f
a477 dd360fa3  ld      (ix+$0f),$a3
a47b dd3610a4  ld      (ix+$10),$a4
_a47f:
a47f af        xor     a
a480 dd770a    ld      (ix+$0a),a
a483 dd360b02  ld      (ix+$0b),$02
a487 dd770c    ld      (ix+$0c),a
a48a c9        ret     
a48b 1a        ld      a,(de)
a48c 1c        inc     e
a48d ff        rst     $38
a48e ff        rst     $38
a48f ff        rst     $38
a490 ff        rst     $38
a491 ff        rst     $38
a492 ff        rst     $38
a493 3a3cff    ld      a,($ff3c)
a496 ff        rst     $38
a497 ff        rst     $38
a498 ff        rst     $38
a499 ff        rst     $38
a49a ff        rst     $38
a49b 383a      jr------c,$a4d7
a49d ff        rst     $38
a49e ff        rst     $38
a49f ff        rst     $38
a4a0 ff        rst     $38
a4a1 ff        rst     $38
a4a2 ff        rst     $38
a4a3 34        inc     (hl)
a4a4 36ff      ld      (hl),$ff
a4a6 ff        rst     $38
a4a7 ff        rst     $38
a4a8 ff        rst     $38
a4a9 ff        rst     $38
a4aa ff        rst     $38
a4ab ddcb18ee  set     5,(ix+$18)
a4af cdd49e    call    _9ed4
a4b2 dd7e11    ld      a,(ix+$11)
a4b5 fe28      cp      $28
a4b7 302c      jr      nc,_a4e5
a4b9 210500    ld      hl,$0005
a4bc 2214d2    ld      ($d214),hl
a4bf cd5639    call    _LABEL_3956_11
a4c2 3821      jr      c,_a4e5
a4c4 110500    ld      de,$0005
a4c7 3a05d4    ld      a,($d405)
a4ca a7        and     a
a4cb fad1a4    jp      m,_a4d1
a4ce 11ecff    ld      de,$ffec
_a4d1:
a4d1 dd6e02    ld      l,(ix+$02)
a4d4 dd6603    ld      h,(ix+$03)
a4d7 19        add     hl,de
a4d8 22fed3    ld      ($d3fe),hl
a4db af        xor     a
a4dc 3203d4    ld      ($d403),a
a4df 3204d4    ld      ($d404),a
a4e2 3205d4    ld      ($d405),a
_a4e5:
a4e5 2117d3    ld      hl,$d317
a4e8 cd020c    call    _LABEL_C02_135
a4eb ddcb184e  bit     1,(ix+$18)
a4ef 2806      jr      z,_a4f7
a4f1 7e        ld      a,(hl)
a4f2 a1        and     c
a4f3 2014      jr      nz,_a509
a4f5 1804      jr      _a4fb
_a4f7:
a4f7 7e        ld      a,(hl)
a4f8 a1        and     c
a4f9 280e      jr      z,_a509
_a4fb:
a4fb dd7e11    ld      a,(ix+$11)
a4fe fe30      cp      $30
a500 3012      jr      nc,_a514
a502 3c        inc     a
a503 3c        inc     a
a504 dd7711    ld      (ix+$11),a
a507 180b      jr      _a514
_a509:
a509 dd7e11    ld      a,(ix+$11)
a50c a7        and     a
a50d 2805      jr      z,_a514
a50f 3d        dec     a
a510 3d        dec     a
a511 dd7711    ld      (ix+$11),a
_a514:
a514 111aa5    ld      de,$a51a
a517 c37e9e    jp      _9e7e
a51a 3eff      ld      a,$ff
a51c ff        rst     $38
a51d ff        rst     $38
a51e ff        rst     $38
a51f ff        rst     $38
a520 38ff      jr------c,$a521
a522 ff        rst     $38
a523 ff        rst     $38
a524 ff        rst     $38
a525 ff        rst     $38
a526 3eff      ld      a,$ff
a528 ff        rst     $38
a529 ff        rst     $38
a52a ff        rst     $38
a52b ff        rst     $38
a52c 38ff      jr------c,$a52d
a52e ff        rst     $38
a52f ff        rst     $38
a530 ff        rst     $38
a531 ff        rst     $38
a532 3eff      ld      a,$ff
a534 ff        rst     $38
a535 ff        rst     $38
a536 ff        rst     $38
a537 ff        rst     $38
a538 ff        rst     $38
a539 ff        rst     $38
a53a ff        rst     $38
a53b ff        rst     $38
a53c ff        rst     $38
a53d ff        rst     $38
a53e 3eff      ld      a,$ff
a540 ff        rst     $38
a541 ff        rst     $38
a542 ff        rst     $38
a543 ff        rst     $38
a544 ff        rst     $38
a545 ff        rst     $38
a546 ff        rst     $38
a547 ff        rst     $38
a548 ff        rst     $38
a549 ff        rst     $38
a54a ff        rst     $38
a54b ff        rst     $38
a54c ff        rst     $38
a54d ff        rst     $38
a54e ff        rst     $38
a54f ff        rst     $38
a550 ff        rst     $38
a551 dd360d06  ld      (ix+$0d),$06
a555 dd360e10  ld      (ix+$0e),$10
a559 3a23d2    ld      a,($d223)
a55c e601      and     $01
a55e 2053      jr      nz,_a5b3
a560 21b9a6    ld      hl,$a6b9
a563 ddcb184e  bit     1,(ix+$18)
a567 2803      jr      z,_a56c
a569 2169a7    ld      hl,$a769
_a56c:
a56c dd5e11    ld      e,(ix+$11)
a56f cb23      sla     e
a571 1600      ld      d,$00
a573 19        add     hl,de
a574 4e        ld      c,(hl)
a575 23        inc     hl
a576 46        ld      b,(hl)
a577 dd6e01    ld      l,(ix+$01)
a57a dd6602    ld      h,(ix+$02)
a57d dd7e03    ld      a,(ix+$03)
a580 09        add     hl,bc
a581 cb78      bit     7,b
a583 2804      jr      z,_a589
a585 ceff      adc     a,$ff
a587 1802      jr      _a58b
_a589:
a589 ce00      adc     a,$00
_a58b:
a58b dd7501    ld      (ix+$01),l
a58e dd7402    ld      (ix+$02),h
a591 dd7703    ld      (ix+$03),a
a594 21e5a6    ld      hl,$a6e5
a597 19        add     hl,de
a598 5e        ld      e,(hl)
a599 23        inc     hl
a59a 56        ld      d,(hl)
a59b dd6e12    ld      l,(ix+$12)
a59e dd6613    ld      h,(ix+$13)
a5a1 19        add     hl,de
a5a2 dd7512    ld      (ix+$12),l
a5a5 dd7413    ld      (ix+$13),h
a5a8 0e00      ld      c,$00
a5aa cb7c      bit     7,h
a5ac 2802      jr      z,_a5b0
a5ae 0eff      ld      c,$ff
_a5b0:
a5b0 dd7114    ld      (ix+$14),c
_a5b3:
a5b3 dd6e02    ld      l,(ix+$02)
a5b6 dd6603    ld      h,(ix+$03)
a5b9 220ed2    ld      ($d20e),hl
a5bc dd6e05    ld      l,(ix+$05)
a5bf dd6606    ld      h,(ix+$06)
a5c2 2210d2    ld      ($d210),hl
a5c5 ddcb184e  bit     1,(ix+$18)
a5c9 2049      jr      nz,_a614
a5cb 2111a7    ld      hl,$a711
a5ce dd5e11    ld      e,(ix+$11)
a5d1 1600      ld      d,$00
a5d3 19        add     hl,de
a5d4 3e24      ld      a,$24
a5d6 cd88a6    call    _a688
a5d9 3e26      ld      a,$26
a5db cda2a6    call    _a6a2
a5de 3e26      ld      a,$26
a5e0 cd88a6    call    _a688
a5e3 3e26      ld      a,$26
a5e5 cda2a6    call    _a6a2
a5e8 dd360d06  ld      (ix+$0d),$06
a5ec 210208    ld      hl,$0802
a5ef 2214d2    ld      ($d214),hl
a5f2 cd5639    call    _LABEL_3956_11
a5f5 210000    ld      hl,$0000
a5f8 220ed2    ld      ($d20e),hl
a5fb 3805      jr      c,_a602
a5fd cde535    call    _35e5
a600 1859      jr      _a65b
_a602:
a602 dd360d16  ld      (ix+$0d),$16
a606 210608    ld      hl,$0806
a609 2214d2    ld      ($d214),hl
a60c cd5639    call    _LABEL_3956_11
a60f d4fd35    call    nc,_35fd
a612 1847      jr      _a65b
_a614:
a614 2195a7    ld      hl,$a795
a617 dd5e11    ld      e,(ix+$11)
a61a 1600      ld      d,$00
a61c 19        add     hl,de
a61d 3e2a      ld      a,$2a
a61f cd88a6    call    _a688
a622 3e28      ld      a,$28
a624 cda2a6    call    _a6a2
a627 3e28      ld      a,$28
a629 cd88a6    call    _a688
a62c 3e28      ld      a,$28
a62e cda2a6    call    _a6a2
a631 dd360d10  ld      (ix+$0d),$10
a635 210104    ld      hl,$0401
a638 2214d2    ld      ($d214),hl
a63b cd5639    call    _LABEL_3956_11
a63e 3805      jr      c,_a645
a640 cdfd35    call    _35fd
a643 1816      jr      _a65b
_a645:
a645 dd360d16  ld      (ix+$0d),$16
a649 211004    ld      hl,$0410
a64c 2214d2    ld      ($d214),hl
a64f cd5639    call    _LABEL_3956_11
a652 210000    ld      hl,$0000
a655 220ed2    ld      ($d20e),hl
a658 d4e535    call    nc,_35e5
_a65b:
a65b dd360b01  ld      (ix+$0b),$01
a65f 3a23d2    ld      a,($d223)
a662 e601      and     $01
a664 c0        ret     nz
a665 dd3411    inc     (ix+$11)
a668 dd7e11    ld      a,(ix+$11)
a66b fe16      cp      $16
a66d d8        ret     c
a66e dd361100  ld      (ix+$11),$00
a672 dd3415    inc     (ix+$15)
a675 dd7e15    ld      a,(ix+$15)
a678 fe14      cp      $14
a67a d8        ret     c
a67b dd361500  ld      (ix+$15),$00
a67f dd7e18    ld      a,(ix+$18)
a682 ee02      xor     $02
a684 dd7718    ld      (ix+$18),a
a687 c9        ret     

_a688:
a688 e5        push    hl
a689 5e        ld      e,(hl)
a68a 1600      ld      d,$00
a68c ed5312d2  ld      ($d212),de
a690 dd6e13    ld      l,(ix+$13)
a693 dd6614    ld      h,(ix+$14)
a696 2214d2    ld      ($d214),hl
a699 cd8135    call    _3581
a69c e1        pop     hl
a69d 111600    ld      de,$0016
a6a0 19        add     hl,de
a6a1 c9        ret     

_a6a2:
a6a2 e5        push    hl
a6a3 5e        ld      e,(hl)
a6a4 1600      ld      d,$00
a6a6 ed5312d2  ld      ($d212),de
a6aa 210000    ld      hl,$0000
a6ad 2214d2    ld      ($d214),hl
a6b0 cd8135    call    _3581
a6b3 e1        pop     hl
a6b4 111600    ld      de,$0016
a6b7 19        add     hl,de
a6b8 c9        ret     
a6b9 00        nop     
a6ba 00        nop     
a6bb 00        nop     
a6bc 00        nop     
a6bd 00        nop     
a6be 00        nop     
a6bf 00        nop     
a6c0 00        nop     
a6c1 00        nop     
a6c2 00        nop     
a6c3 00        nop     
a6c4 00        nop     
a6c5 00        nop     
a6c6 00        nop     
a6c7 00        nop     
a6c8 00        nop     
a6c9 00        nop     
a6ca 00        nop     
a6cb 00        nop     
a6cc 00        nop     
a6cd 00        nop     
a6ce 00        nop     
a6cf e0        ret     po
a6d0 ff        rst     $38
a6d1 e0        ret     po
a6d2 ff        rst     $38
a6d3 e0        ret     po
a6d4 ff        rst     $38
a6d5 e0        ret     po
a6d6 ff        rst     $38
a6d7 c0        ret     nz
a6d8 ff        rst     $38
a6d9 c0        ret     nz
a6da ff        rst     $38
a6db 80        add     a,b
a6dc ff        rst     $38
a6dd 80        add     a,b
a6de ff        rst     $38
a6df 00        nop     
a6e0 ff        rst     $38
a6e1 00        nop     
a6e2 ff        rst     $38
a6e3 00        nop     
a6e4 fe00      cp      $00
a6e6 ff        rst     $38
a6e7 80        add     a,b
a6e8 ff        rst     $38
a6e9 80        add     a,b
a6ea ff        rst     $38
a6eb c0        ret     nz
a6ec ff        rst     $38
a6ed c0        ret     nz
a6ee ff        rst     $38
a6ef e0        ret     po
a6f0 ff        rst     $38
a6f1 e0        ret     po
a6f2 ff        rst     $38
a6f3 f0        ret     p
a6f4 ff        rst     $38
a6f5 f0        ret     p
a6f6 ff        rst     $38
a6f7 f0        ret     p
a6f8 ff        rst     $38
a6f9 f0        ret     p
a6fa ff        rst     $38
a6fb 1000      djnz----$a6fd
a6fd 1000      djnz----$a6ff
a6ff 1000      djnz----$a701
a701 1000      djnz----$a703
a703 2000      jr------nz,$a705
a705 2000      jr------nz,$a707
a707 40        ld      b,b
a708 00        nop     
a709 40        ld      b,b
a70a 00        nop     
a70b 80        add     a,b
a70c 00        nop     
a70d 80        add     a,b
a70e 00        nop     
a70f 00        nop     
a710 010001    ld      bc,$0100
a713 02        ld      (bc),a
a714 02        ld      (bc),a
a715 03        inc     bc
a716 03        inc     bc
a717 03        inc     bc
a718 03        inc     bc
a719 03        inc     bc
a71a 03        inc     bc
a71b 03        inc     bc
a71c 03        inc     bc
a71d 03        inc     bc
a71e 03        inc     bc
a71f 03        inc     bc
a720 03        inc     bc
a721 03        inc     bc
a722 03        inc     bc
a723 02        ld      (bc),a
a724 02        ld      (bc),a
a725 010007    ld      bc,$0700
a728 07        rlca    
a729 07        rlca    
a72a 07        rlca    
a72b 07        rlca    
a72c 07        rlca    
a72d 07        rlca    
a72e 07        rlca    
a72f 07        rlca    
a730 07        rlca    
a731 07        rlca    
a732 07        rlca    
a733 07        rlca    
a734 07        rlca    
a735 07        rlca    
a736 07        rlca    
a737 07        rlca    
a738 07        rlca    
a739 07        rlca    
a73a 07        rlca    
a73b 07        rlca    
a73c 07        rlca    
a73d 0e0d      ld      c,$0d
a73f 0c        inc     c
a740 0c        inc     c
a741 0b        dec     bc
a742 0b        dec     bc
a743 0b        dec     bc
a744 0b        dec     bc
a745 0b        dec     bc
a746 0b        dec     bc
a747 0b        dec     bc
a748 0b        dec     bc
a749 0b        dec     bc
a74a 0b        dec     bc
a74b 0b        dec     bc
a74c 0b        dec     bc
a74d 0b        dec     bc
a74e 0b        dec     bc
a74f 0c        inc     c
a750 0c        inc     c
a751 0d        dec     c
a752 0e15      ld      c,$15
a754 13        inc     de
a755 12        ld      (de),a
a756 111010    ld      de,$1010
a759 0f        rrca    
a75a 0f        rrca    
a75b 0f        rrca    
a75c 0f        rrca    
a75d 0f        rrca    
a75e 0f        rrca    
a75f 0f        rrca    
a760 0f        rrca    
a761 0f        rrca    
a762 0f        rrca    
a763 1010      djnz----$a775
a765 111213    ld      de,$1312
a768 15        dec     d
a769 00        nop     
a76a 00        nop     
a76b 00        nop     
a76c 00        nop     
a76d 00        nop     
a76e 00        nop     
a76f 00        nop     
a770 00        nop     
a771 00        nop     
a772 00        nop     
a773 00        nop     
a774 00        nop     
a775 00        nop     
a776 00        nop     
a777 00        nop     
a778 00        nop     
a779 00        nop     
a77a 00        nop     
a77b 00        nop     
a77c 00        nop     
a77d 00        nop     
a77e 00        nop     
a77f 2000      jr------nz,$a781
a781 2000      jr------nz,$a783
a783 2000      jr------nz,$a785
a785 2000      jr------nz,$a787
a787 40        ld      b,b
a788 00        nop     
a789 40        ld      b,b
a78a 00        nop     
a78b 80        add     a,b
a78c 00        nop     
a78d 80        add     a,b
a78e 00        nop     
a78f 00        nop     
a790 010001    ld      bc,$0100
a793 00        nop     
a794 02        ld      (bc),a
a795 15        dec     d
a796 14        inc     d
a797 13        inc     de
a798 13        inc     de
a799 12        ld      (de),a
a79a 12        ld      (de),a
a79b 12        ld      (de),a
a79c 12        ld      (de),a
a79d 12        ld      (de),a
a79e 12        ld      (de),a
a79f 12        ld      (de),a
a7a0 12        ld      (de),a
a7a1 12        ld      (de),a
a7a2 12        ld      (de),a
a7a3 12        ld      (de),a
a7a4 12        ld      (de),a
a7a5 12        ld      (de),a
a7a6 12        ld      (de),a
a7a7 13        inc     de
a7a8 13        inc     de
a7a9 14        inc     d
a7aa 15        dec     d
a7ab 0e0e      ld      c,$0e
a7ad 0e0e      ld      c,$0e
a7af 0e0e      ld      c,$0e
a7b1 0e0e      ld      c,$0e
a7b3 0e0e      ld      c,$0e
a7b5 0e0e      ld      c,$0e
a7b7 0e0e      ld      c,$0e
a7b9 0e0e      ld      c,$0e
a7bb 0e0e      ld      c,$0e
a7bd 0e0e      ld      c,$0e
a7bf 0e0e      ld      c,$0e
a7c1 07        rlca    
a7c2 08        ex      af,af'
a7c3 09        add     hl,bc
a7c4 09        add     hl,bc
a7c5 0a        ld      a,(bc)
a7c6 0a        ld      a,(bc)
a7c7 0a        ld      a,(bc)
a7c8 0a        ld      a,(bc)
a7c9 0a        ld      a,(bc)
a7ca 0a        ld      a,(bc)
a7cb 0a        ld      a,(bc)
a7cc 0a        ld      a,(bc)
a7cd 0a        ld      a,(bc)
a7ce 0a        ld      a,(bc)
a7cf 0a        ld      a,(bc)
a7d0 0a        ld      a,(bc)
a7d1 0a        ld      a,(bc)
a7d2 0a        ld      a,(bc)
a7d3 09        add     hl,bc
a7d4 09        add     hl,bc
a7d5 08        ex      af,af'
a7d6 07        rlca    
a7d7 00        nop     
a7d8 02        ld      (bc),a
a7d9 03        inc     bc
a7da 04        inc     b
a7db 05        dec     b
a7dc 05        dec     b
a7dd 0606      ld      b,$06
a7df 0606      ld      b,$06
a7e1 0606      ld      b,$06
a7e3 0606      ld      b,$06
a7e5 0606      ld      b,$06
a7e7 05        dec     b
a7e8 05        dec     b
a7e9 04        inc     b
a7ea 03        inc     bc
a7eb 02        ld      (bc),a
a7ec 00        nop     
a7ed dd360d1e  ld      (ix+$0d),$1e
a7f1 dd360e2f  ld      (ix+$0e),$2f
a7f5 ddcb1846  bit     0,(ix+$18)
a7f9 2035      jr      nz,_a830
a7fb 214003    ld      hl,$0340
a7fe 2273d2    ld      (S1_LEVEL_CROPLEFT),hl
a801 214005    ld      hl,$0540
a804 2275d2    ld      ($d275),hl
a807 2a5dd2    ld      hl,($d25d)
a80a 2277d2    ld      (S1_LEVEL_CROPTOP),hl
a80d 2279d2    ld      (S1_LEVEL_EXTENDHEIGHT),hl
a810 212002    ld      hl,$0220
a813 227dd2    ld      ($d27d),hl

		;UNKNOWN
a816 213fef    ld      hl,$ef3f
a819 110020    ld      de,$2000
a81c 3e0c      ld      a,12
a81e cd0504    call    decompressArt

a821 211c73    ld      hl,S1_BossPalette
a824 3e02      ld      a,$02
a826 cd3303    call    loadPaletteOnInterrupt
a829 3e0b      ld      a,$0b
a82b df        rst     $18
a82c ddcb18c6  set     0,(ix+$18)
_a830:
a830 ddcb184e  bit     1,(ix+$18)
a834 205d      jr      nz,_a893
a836 2a5ad2    ld      hl,($d25a)
a839 2273d2    ld      (S1_LEVEL_CROPLEFT),hl
a83c 11f9ba    ld      de,$baf9
a83f 01b7a9    ld      bc,$a9b7
a842 cd417c    call    _7c41
a845 dd6e02    ld      l,(ix+$02)
a848 dd6603    ld      h,(ix+$03)
a84b ed5bfed3  ld      de,($d3fe)
a84f af        xor     a
a850 ed52      sbc     hl,de
a852 114000    ld      de,$0040
a855 af        xor     a
a856 ed4b03d4  ld      bc,($d403)
a85a cb78      bit     7,b
a85c 2004      jr      nz,_a862
a85e ed52      sbc     hl,de
a860 3803      jr      c,_a865
_a862:
a862 0180ff    ld      bc,$ff80
_a865:
a865 04        inc     b
a866 dd7107    ld      (ix+$07),c
a869 dd7008    ld      (ix+$08),b
a86c dd7709    ld      (ix+$09),a
a86f dd6e02    ld      l,(ix+$02)
a872 dd6603    ld      h,(ix+$03)
a875 11a005    ld      de,$05a0
a878 af        xor     a
a879 ed52      sbc     hl,de
a87b da74a9    jp      c,_a974
a87e 6f        ld      l,a
a87f 67        ld      h,a
a880 dd7707    ld      (ix+$07),a
a883 dd7708    ld      (ix+$08),a
a886 2203d4    ld      ($d403),hl
a889 3205d4    ld      ($d405),a
a88c ddcb18ce  set     1,(ix+$18)
a890 c374a9    jp      _a974
_a893:
a893 ddcb1856  bit     2,(ix+$18)
a897 2034      jr      nz,_a8cd
a899 213005    ld      hl,$0530
a89c 112002    ld      de,$0220
a89f cd8c7c    call    _7c8c
a8a2 fd3603ff  ld      (iy+$03),$ff
a8a6 21a005    ld      hl,$05a0
a8a9 dd360100  ld      (ix+$01),$00
a8ad dd7502    ld      (ix+$02),l
a8b0 dd7403    ld      (ix+$03),h
a8b3 dd360ff9  ld      (ix+$0f),$f9
a8b7 dd3610ba  ld      (ix+$10),$ba
a8bb dd3411    inc     (ix+$11)
a8be dd7e11    ld      a,(ix+$11)
a8c1 fec0      cp      $c0
a8c3 da74a9    jp      c,_a974
a8c6 ddcb18d6  set     2,(ix+$18)
a8ca c374a9    jp      _a974
_a8cd:
a8cd ddcb185e  bit     3,(ix+$18)
a8d1 2018      jr      nz,_a8eb
a8d3 fd3603ff  ld      (iy+$03),$ff
a8d7 af        xor     a
a8d8 dd770f    ld      (ix+$0f),a
a8db dd7710    ld      (ix+$10),a
a8de dd3511    dec     (ix+$11)
a8e1 c274a9    jp      nz,_a974
a8e4 ddcb18de  set     3,(ix+$18)
a8e8 c374a9    jp      _a974
_a8eb:
a8eb ddcb1866  bit     4,(ix+$18)
a8ef 207a      jr      nz,_a96b
a8f1 ed5bfed3  ld      de,($d3fe)
a8f5 219605    ld      hl,$0596
a8f8 a7        and     a
a8f9 ed52      sbc     hl,de
a8fb 3077      jr      nc,_a974
a8fd 21c005    ld      hl,$05c0
a900 af        xor     a
a901 ed52      sbc     hl,de
a903 386f      jr      c,_a974
a905 ddb611    or      (ix+$11)
a908 2013      jr      nz,_a91d
a90a 2a01d4    ld      hl,($d401)
a90d 118d02    ld      de,$028d
a910 af        xor     a
a911 ed52      sbc     hl,de
a913 385f      jr      c,_a974
a915 6f        ld      l,a
a916 67        ld      h,a
a917 2203d4    ld      ($d403),hl
a91a 3205d4    ld      ($d405),a
_a91d:
a91d 3e80      ld      a,$80
a91f 3214d4    ld      ($d414),a
a922 21a005    ld      hl,$05a0
a925 22fed3    ld      ($d3fe),hl
a928 fd3603ff  ld      (iy+$03),$ff
a92c dd5e11    ld      e,(ix+$11)
a92f 1600      ld      d,$00
a931 218e02    ld      hl,$028e
a934 af        xor     a
a935 ed52      sbc     hl,de
a937 3200d4    ld      ($d400),a
a93a 2201d4    ld      ($d401),hl
a93d 3ae8d2    ld      a,($d2e8)
a940 2ae6d2    ld      hl,($d2e6)
a943 2206d4    ld      ($d406),hl
a946 3208d4    ld      ($d408),a
a949 dd3411    inc     (ix+$11)
a94c dd7e11    ld      a,(ix+$11)
a94f fec0      cp      $c0
a951 2021      jr      nz,_a974
a953 2a5ad2    ld      hl,($d25a)
a956 24        inc     h
a957 22fed3    ld      ($d3fe),hl
a95a ddcb18e6  set     4,(ix+$18)
a95e 3e09      ld      a,$09
a960 df        rst     $18
a961 3ea0      ld      a,$a0
a963 3289d2    ld      ($d289),a
a966 fdcb06ce  set     1,(iy+$06)
a96a c9        ret     
_a96b:
a96b dd7e11    ld      a,(ix+$11)
a96e a7        and     a
a96f 2803      jr      z,_a974
a971 dd3511    dec     (ix+$11)
_a974:
a974 dd5e11    ld      e,(ix+$11)
a977 1600      ld      d,$00
a979 218002    ld      hl,$0280
a97c af        xor     a
a97d ed52      sbc     hl,de
a97f dd7704    ld      (ix+$04),a
a982 dd7505    ld      (ix+$05),l
a985 dd7406    ld      (ix+$06),h
a988 dd5e11    ld      e,(ix+$11)
a98b 1600      ld      d,$00
a98d 21af02    ld      hl,$02af
a990 a7        and     a
a991 ed52      sbc     hl,de
a993 ed4b5dd2  ld      bc,($d25d)
a997 a7        and     a
a998 ed42      sbc     hl,bc
a99a eb        ex      de,hl
a99b 21a005    ld      hl,$05a0
a99e ed4b5ad2  ld      bc,($d25a)
a9a2 a7        and     a
a9a3 ed42      sbc     hl,bc
a9a5 01c0a9    ld      bc,$a9c0
a9a8 cd0f35    call    _LABEL_350F_95
a9ab dd7e11    ld      a,(ix+$11)
a9ae e61f      and     $1f
a9b0 fe0f      cp      $0f
a9b2 c0        ret     nz
a9b3 3e19      ld      a,$19
a9b5 ef        rst     $28
a9b6 c9        ret     
a9b7 03        inc     bc
a9b8 08        ex      af,af'
a9b9 04        inc     b
a9ba 07        rlca    
a9bb 05        dec     b
a9bc 08        ex      af,af'
a9bd 04        inc     b
a9be 07        rlca    
a9bf ff        rst     $38
a9c0 74        ld      (hl),h
a9c1 76        halt    
a9c2 76        halt    
a9c3 78        ld      a,b
a9c4 ff        rst     $38
a9c5 ff        rst     $38
a9c6 ff        rst     $38
a9c7 ddcb18ee  set     5,(ix+$18)
a9cb fd7e0a    ld      a,(iy+$0a)
a9ce 2a3cd2    ld      hl,($d23c)
a9d1 f5        push    af
a9d2 e5        push    hl
a9d3 3aded2    ld      a,($d2de)
a9d6 fe24      cp      $24
a9d8 3042      jr      nc,_aa1c
a9da 5f        ld      e,a
a9db 1600      ld      d,$00
a9dd 2100d0    ld      hl,$d000
a9e0 19        add     hl,de
a9e1 223cd2    ld      ($d23c),hl
a9e4 3aa3d2    ld      a,($d2a3)
a9e7 4f        ld      c,a
a9e8 ed5ba1d2  ld      de,($d2a1)
a9ec dd6e04    ld      l,(ix+$04)
a9ef dd6605    ld      h,(ix+$05)
a9f2 dd7e06    ld      a,(ix+$06)
a9f5 19        add     hl,de
a9f6 89        adc     a,c
a9f7 6c        ld      l,h
a9f8 67        ld      h,a
a9f9 ed4b5dd2  ld      bc,($d25d)
a9fd a7        and     a
a9fe ed42      sbc     hl,bc
aa00 eb        ex      de,hl
aa01 dd6e02    ld      l,(ix+$02)
aa04 dd6603    ld      h,(ix+$03)
aa07 ed4b5ad2  ld      bc,($d25a)
aa0b a7        and     a
aa0c ed42      sbc     hl,bc
aa0e 0163aa    ld      bc,$aa63
aa11 cd0f35    call    _LABEL_350F_95
aa14 3aded2    ld      a,($d2de)
aa17 c60c      add     a,$0c
aa19 32ded2    ld      ($d2de),a
_aa1c:
aa1c e1        pop     hl
aa1d f1        pop     af
aa1e 223cd2    ld      ($d23c),hl
aa21 fd770a    ld      (iy+$0a),a
aa24 2a5ad2    ld      hl,($d25a)
aa27 11e0ff    ld      de,$ffe0
aa2a 19        add     hl,de
aa2b eb        ex      de,hl
aa2c dd6e02    ld      l,(ix+$02)
aa2f dd6603    ld      h,(ix+$03)
aa32 a7        and     a
aa33 ed52      sbc     hl,de
aa35 3017      jr      nc,_aa4e
aa37 cd2506    call    _LABEL_625_57
aa3a 0600      ld      b,$00
aa3c 87        add     a,a
aa3d 4f        ld      c,a
aa3e cb10      rl      b
aa40 2a5ad2    ld      hl,($d25a)
aa43 11b401    ld      de,$01b4
aa46 19        add     hl,de
aa47 09        add     hl,bc
aa48 dd7502    ld      (ix+$02),l
aa4b dd7403    ld      (ix+$03),h
_aa4e:
aa4e dd360700  ld      (ix+$07),$00
aa52 dd3608fd  ld      (ix+$08),$fd
aa56 dd3609ff  ld      (ix+$09),$ff
aa5a dd360f00  ld      (ix+$0f),$00
aa5e dd361000  ld      (ix+$10),$00
aa62 c9        ret     
aa63 40        ld      b,b
aa64 42        ld      b,d
aa65 44        ld      b,h
aa66 46        ld      b,(hl)
aa67 ff        rst     $38
aa68 ff        rst     $38
aa69 ff        rst     $38
aa6a ddcb18ee  set     5,(ix+$18)
aa6e dd360d05  ld      (ix+$0d),$05
aa72 dd360e14  ld      (ix+$0e),$14
aa76 ddcb1846  bit     0,(ix+$18)
aa7a 2024      jr      nz,_aaa0
aa7c dd6e02    ld      l,(ix+$02)
aa7f dd6603    ld      h,(ix+$03)
aa82 110f00    ld      de,$000f
aa85 19        add     hl,de
aa86 dd7502    ld      (ix+$02),l
aa89 dd7403    ld      (ix+$03),h
aa8c dd6e05    ld      l,(ix+$05)
aa8f dd6606    ld      h,(ix+$06)
aa92 11faff    ld      de,$fffa
aa95 19        add     hl,de
aa96 dd7505    ld      (ix+$05),l
aa99 dd7406    ld      (ix+$06),h
aa9c ddcb18c6  set     0,(ix+$18)
_aaa0:
aaa0 dd6e02    ld      l,(ix+$02)
aaa3 dd6603    ld      h,(ix+$03)
aaa6 220ed2    ld      ($d20e),hl
aaa9 dd6e05    ld      l,(ix+$05)
aaac dd6606    ld      h,(ix+$06)
aaaf 2210d2    ld      ($d210),hl
aab2 dd5e11    ld      e,(ix+$11)
aab5 1600      ld      d,$00
aab7 2101ab    ld      hl,$ab01
aaba 19        add     hl,de
aabb 5e        ld      e,(hl)
aabc 23        inc     hl
aabd 56        ld      d,(hl)
aabe 0602      ld      b,$02
_aac0:
aac0 c5        push    bc
aac1 1a        ld      a,(de)
aac2 6f        ld      l,a
aac3 2600      ld      h,$00
aac5 2212d2    ld      ($d212),hl
aac8 13        inc     de
aac9 1a        ld      a,(de)
aaca 6f        ld      l,a
aacb 2214d2    ld      ($d214),hl
aace 13        inc     de
aacf 1a        ld      a,(de)
aad0 13        inc     de
aad1 a7        and     a
aad2 fadaaa    jp      m,_aada
aad5 d5        push    de
aad6 cd8135    call    _3581
aad9 d1        pop     de
_aada:
aada c1        pop     bc
aadb 10e3      djnz    _aac0
aadd 210202    ld      hl,$0202
aae0 2214d2    ld      ($d214),hl
aae3 cd5639    call    _LABEL_3956_11
aae6 d4fd35    call    nc,_35fd
aae9 dd360f00  ld      (ix+$0f),$00
aaed dd361000  ld      (ix+$10),$00
aaf1 dd7e11    ld      a,(ix+$11)
aaf4 3c        inc     a
aaf5 3c        inc     a
aaf6 fe08      cp      $08
aaf8 dd7711    ld      (ix+$11),a
aafb d8        ret     c
aafc dd361100  ld      (ix+$11),$00
ab00 c9        ret     
ab01 09        add     hl,bc
ab02 ab        xor     e
ab03 0f        rrca    
ab04 ab        xor     e
ab05 15        dec     d
ab06 ab        xor     e
ab07 1b        dec     de
ab08 ab        xor     e
ab09 00        nop     
ab0a 00        nop     
ab0b 1c        inc     e
ab0c 00        nop     
ab0d 183c      jr------$ab4b
ab0f 00        nop     
ab10 00        nop     
ab11 1e00      ld      e,$00
ab13 183e      jr------$ab53
ab15 00        nop     
ab16 00        nop     
ab17 3800      jr------c,$ab19
ab19 183a      jr------$ab55
ab1b 00        nop     
ab1c 08        ex      af,af'
ab1d 1a        ld      a,(de)
ab1e 00        nop     
ab1f 00        nop     
ab20 ff        rst     $38
ab21 dd360d0c  ld      (ix+$0d),$0c
ab25 dd360e10  ld      (ix+$0e),$10
ab29 dd7e11    ld      a,(ix+$11)
ab2c fe64      cp      $64
ab2e 302a      jr      nc,_ab5a
ab30 dd6e02    ld      l,(ix+$02)
ab33 dd6603    ld      h,(ix+$03)
ab36 11c8ff    ld      de,$ffc8
ab39 19        add     hl,de
ab3a eb        ex      de,hl
ab3b 2afed3    ld      hl,($d3fe)
ab3e a7        and     a
ab3f ed52      sbc     hl,de
ab41 3817      jr      c,_ab5a
ab43 dd6e02    ld      l,(ix+$02)
ab46 dd6603    ld      h,(ix+$03)
ab49 112c00    ld      de,$002c
ab4c 19        add     hl,de
ab4d eb        ex      de,hl
ab4e 2afed3    ld      hl,($d3fe)
ab51 a7        and     a
ab52 ed52      sbc     hl,de
ab54 3004      jr      nc,_ab5a
ab56 dd361164  ld      (ix+$11),$64
_ab5a:
ab5a dd7e11    ld      a,(ix+$11)
ab5d fe1e      cp      $1e
ab5f 3018      jr      nc,_ab79
ab61 dd3607f8  ld      (ix+$07),$f8
ab65 dd3608ff  ld      (ix+$08),$ff
ab69 dd3609ff  ld      (ix+$09),$ff
ab6d 110bad    ld      de,$ad0b
ab70 01f1ac    ld      bc,$acf1
ab73 cd417c    call    _7c41
ab76 c36aac    jp      _ac6a
_ab79:
ab79 dd7e11    ld      a,(ix+$11)
ab7c fe64      cp      $64
ab7e da1eac    jp      c,_ac1e
ab81 dd360700  ld      (ix+$07),$00
ab85 dd360800  ld      (ix+$08),$00
ab89 dd360900  ld      (ix+$09),$00
ab8d fe66      cp      $66
ab8f 300c      jr      nc,_ab9d
ab91 110bad    ld      de,$ad0b
ab94 0101ad    ld      bc,$ad01
ab97 cd417c    call    _7c41
ab9a c36aac    jp      _ac6a
_ab9d:
ab9d dd360f53  ld      (ix+$0f),$53
aba1 dd3610ad  ld      (ix+$10),$ad
aba5 fe67      cp      $67
aba7 c26aac    jp      nz,_ac6a
abaa 21feff    ld      hl,$fffe
abad 2212d2    ld      ($d212),hl
abb0 21fcff    ld      hl,$fffc
abb3 2214d2    ld      ($d214),hl
abb6 cd7b7c    call    _7c7b
abb9 da76ac    jp      c,_ac76
abbc 110000    ld      de,$0000
abbf 4b        ld      c,e
abc0 42        ld      b,d
abc1 cd96ac    call    _ac96
abc4 210300    ld      hl,$0003
abc7 2212d2    ld      ($d212),hl
abca 21fcff    ld      hl,$fffc
abcd 2214d2    ld      ($d214),hl
abd0 cd7b7c    call    _7c7b
abd3 da76ac    jp      c,_ac76
abd6 110800    ld      de,$0008
abd9 010000    ld      bc,$0000
abdc cd96ac    call    _ac96
abdf 21feff    ld      hl,$fffe
abe2 2212d2    ld      ($d212),hl
abe5 21feff    ld      hl,$fffe
abe8 2214d2    ld      ($d214),hl
abeb cd7b7c    call    _7c7b
abee da76ac    jp      c,_ac76
abf1 110000    ld      de,$0000
abf4 010800    ld      bc,$0008
abf7 cd96ac    call    _ac96
abfa 210300    ld      hl,$0003
abfd 2212d2    ld      ($d212),hl
ac00 21feff    ld      hl,$fffe
ac03 2214d2    ld      ($d214),hl
ac06 cd7b7c    call    _7c7b
ac09 da76ac    jp      c,_ac76
ac0c 110800    ld      de,$0008
ac0f 010800    ld      bc,$0008
ac12 cd96ac    call    _ac96
ac15 dd3600ff  ld      (ix+$00),$ff
ac19 3e1b      ld      a,$1b
ac1b ef        rst     $28
ac1c 1858      jr      _ac76
_ac1e:
ac1e fe23      cp      $23
ac20 3015      jr      nc,_ac37
ac22 af        xor     a
ac23 dd7707    ld      (ix+$07),a
ac26 dd7708    ld      (ix+$08),a
ac29 dd7709    ld      (ix+$09),a
ac2c 110bad    ld      de,$ad0b
ac2f 01f6ac    ld      bc,$acf6
ac32 cd417c    call    _7c41
ac35 1833      jr      _ac6a
_ac37:
ac37 dd7e11    ld      a,(ix+$11)
ac3a fe41      cp      $41
ac3c 3017      jr      nc,_ac55
ac3e dd360708  ld      (ix+$07),$08
ac42 dd360800  ld      (ix+$08),$00
ac46 dd360900  ld      (ix+$09),$00
ac4a 110bad    ld      de,$ad0b
ac4d 01f9ac    ld      bc,$acf9
ac50 cd417c    call    _7c41
ac53 1815      jr      _ac6a
_ac55:
ac55 dd360700  ld      (ix+$07),$00
ac59 dd360800  ld      (ix+$08),$00
ac5d dd360900  ld      (ix+$09),$00
ac61 110bad    ld      de,$ad0b
ac64 01feac    ld      bc,$acfe
ac67 cd417c    call    _7c41
_ac6a:
ac6a dd360a80  ld      (ix+$0a),$80
ac6e dd360b00  ld      (ix+$0b),$00
ac72 dd360c00  ld      (ix+$0c),$00
_ac76:
ac76 210202    ld      hl,$0202
ac79 2214d2    ld      ($d214),hl
ac7c cd5639    call    _LABEL_3956_11
ac7f d4fd35    call    nc,_35fd
ac82 3a23d2    ld      a,($d223)
ac85 e63f      and     $3f
ac87 c0        ret     nz
ac88 dd3411    inc     (ix+$11)
ac8b dd7e11    ld      a,(ix+$11)
ac8e fe46      cp      $46
ac90 c0        ret     nz
ac91 dd361100  ld      (ix+$11),$00
ac95 c9        ret     

.ASM
.ORGA $AC96
_ac96:
	push    ix
	push    hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ex      de,hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,bc
	ld      c,l
	ld      b,h
	pop     ix
	xor     a
	ld      (ix+$00),$0d
	ld      (ix+$01),a
	ld      (ix+$02),e
	ld      (ix+$03),d
	ld      (ix+$04),a
	ld      (ix+$05),c
	ld      (ix+$06),b
	ld      (ix+$11),a
	ld      (ix+$13),$24
	ld      (ix+$14),a
	ld      (ix+$15),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$07),a
	ld      hl,($d212)
	ld      (ix+$08),l
	ld      (ix+$09),h
	ld      (ix+$0a),a
	ld      hl,($d214)
	ld      (ix+$0b),l
	ld      (ix+$0c),h
	pop     ix
	ret    
	
.ENDASM
acf1 00        nop     
acf2 2001      jr------nz,$acf5
acf4 20ff      jr------nz,$acf5
acf6 0120ff    ld      bc,$ff20
acf9 02        ld      (bc),a
acfa 2003      jr------nz,$acff
acfc 20ff      jr------nz,$acfd
acfe 03        inc     bc
acff 20ff      jr------nz,$ad00
ad01 010204    ld      bc,$0402
ad04 02        ld      (bc),a
ad05 ff        rst     $38
ad06 03        inc     bc
ad07 02        ld      (bc),a
ad08 05        dec     b
ad09 02        ld      (bc),a
ad0a ff        rst     $38
ad0b 0a        ld      a,(bc)
ad0c 0c        inc     c
ad0d ff        rst     $38
ad0e ff        rst     $38
ad0f ff        rst     $38
ad10 ff        rst     $38
ad11 ff        rst     $38
ad12 ff        rst     $38
ad13 ff        rst     $38
ad14 ff        rst     $38
ad15 ff        rst     $38
ad16 ff        rst     $38
ad17 ff        rst     $38
ad18 ff        rst     $38
ad19 ff        rst     $38
ad1a ff        rst     $38
ad1b ff        rst     $38
ad1c ff        rst     $38
ad1d 0e10      ld      c,$10
ad1f ff        rst     $38
ad20 ff        rst     $38
ad21 ff        rst     $38
ad22 ff        rst     $38
ad23 ff        rst     $38
ad24 ff        rst     $38
ad25 ff        rst     $38
ad26 ff        rst     $38
ad27 ff        rst     $38
ad28 ff        rst     $38
ad29 ff        rst     $38
ad2a ff        rst     $38
ad2b ff        rst     $38
ad2c ff        rst     $38
ad2d ff        rst     $38
ad2e ff        rst     $38
ad2f 2a2cff    ld      hl,($ff2c)
ad32 ff        rst     $38
ad33 ff        rst     $38
ad34 ff        rst     $38
ad35 ff        rst     $38
ad36 ff        rst     $38
ad37 ff        rst     $38
ad38 ff        rst     $38
ad39 ff        rst     $38
ad3a ff        rst     $38
ad3b ff        rst     $38
ad3c ff        rst     $38
ad3d ff        rst     $38
ad3e ff        rst     $38
ad3f ff        rst     $38
ad40 ff        rst     $38
ad41 2e30      ld      l,$30
ad43 ff        rst     $38
ad44 ff        rst     $38
ad45 ff        rst     $38
ad46 ff        rst     $38
ad47 ff        rst     $38
ad48 ff        rst     $38
ad49 ff        rst     $38
ad4a ff        rst     $38
ad4b ff        rst     $38
ad4c ff        rst     $38
ad4d ff        rst     $38
ad4e ff        rst     $38
ad4f ff        rst     $38
ad50 ff        rst     $38
ad51 ff        rst     $38
ad52 ff        rst     $38
ad53 12        ld      (de),a
ad54 14        inc     d
ad55 ff        rst     $38
ad56 ff        rst     $38
ad57 ff        rst     $38
ad58 ff        rst     $38
ad59 ff        rst     $38
ad5a ff        rst     $38
ad5b ff        rst     $38
ad5c ff        rst     $38
ad5d ff        rst     $38
ad5e ff        rst     $38
ad5f ff        rst     $38
ad60 ff        rst     $38
ad61 ff        rst     $38
ad62 ff        rst     $38
ad63 ff        rst     $38
ad64 ff        rst     $38
ad65 3234ff    ld      ($ff34),a
ad68 ff        rst     $38
ad69 ff        rst     $38
ad6a ff        rst     $38
ad6b ff        rst     $38

ad6c ddcb18ee  set     5,(ix+$18)
ad70 ddcb1846  bit     0,(ix+$18)
ad74 201a      jr      nz,_ad90
ad76 dd6e02    ld      l,(ix+$02)
ad79 dd6603    ld      h,(ix+$03)
ad7c 11fcff    ld      de,$fffc
ad7f 19        add     hl,de
ad80 dd7502    ld      (ix+$02),l
ad83 dd7403    ld      (ix+$03),h
ad86 cd2506    call    _LABEL_625_57
ad89 dd7711    ld      (ix+$11),a
ad8c ddcb18c6  set     0,(ix+$18
_ad90:
ad90 dd7e11    ld      a,(ix+$11)
ad93 fe64      cp      $64
ad95 2046      jr      nz,_addd
ad97 cd7b7c    call    _7c7b
ad9a 3841      jr      c,_addd
ad9c dde5      push    ix
ad9e dd5e02    ld      e,(ix+$02)
ada1 dd5603    ld      d,(ix+$03)
ada4 dd4e05    ld      c,(ix+$05)
ada7 dd4606    ld      b,(ix+$06)
adaa e5        push    hl
adab dde1      pop     ix
adad af        xor     a
adae dd360034  ld      (ix+$00),$34
adb2 dd7701    ld      (ix+$01),a
adb5 210400    ld      hl,$0004
adb8 19        add     hl,de
adb9 dd7502    ld      (ix+$02),l
adbc dd7403    ld      (ix+$03),h
adbf dd7704    ld      (ix+$04),a
adc2 211000    ld      hl,$0010
adc5 09        add     hl,bc
adc6 dd7505    ld      (ix+$05),l
adc9 dd7406    ld      (ix+$06),h
adcc dde1      pop     ix
adce 3e1c      ld      a,$1c
add0 ef        rst     $28
add1 dd361218  ld      (ix+$12),$18
add5 dd361600  ld      (ix+$16),$00
add9 dd361700  ld      (ix+$17),$00
_addd:
addd dd7e12    ld      a,(ix+$12)
ade0 a7        and     a
ade1 2810      jr      z,_adf3
ade3 1104ae    ld      de,$ae04
ade6 01fdad    ld      bc,$adfd
ade9 cd417c    call    _7c41
adec dd3512    dec     (ix+$12)
adef dd3411    inc     (ix+$11)
adf2 c9        ret     
_adf3:
adf3 dd770f    ld      (ix+$0f),a
adf6 dd7710    ld      (ix+$10),a
adf9 dd3411    inc     (ix+$11)
adfc c9        ret     
adfd 00        nop     
adfe 08        ex      af,af'
adff 010802    ld      bc,$0208
ae02 08        ex      af,af'
ae03 ff        rst     $38
ae04 feff      cp      $ff
ae06 ff        rst     $38
ae07 ff        rst     $38
ae08 ff        rst     $38
ae09 ff        rst     $38
ae0a 74        ld      (hl),h
ae0b 76        halt    
ae0c ff        rst     $38
ae0d ff        rst     $38
ae0e ff        rst     $38
ae0f ff        rst     $38
ae10 ff        rst     $38
ae11 ff        rst     $38
ae12 ff        rst     $38
ae13 ff        rst     $38
ae14 ff        rst     $38
ae15 ff        rst     $38
ae16 feff      cp      $ff
ae18 ff        rst     $38
ae19 ff        rst     $38
ae1a ff        rst     $38
ae1b ff        rst     $38
ae1c 78        ld      a,b
ae1d 7a        ld      a,d
ae1e ff        rst     $38
ae1f ff        rst     $38
ae20 ff        rst     $38
ae21 ff        rst     $38
ae22 ff        rst     $38
ae23 ff        rst     $38
ae24 ff        rst     $38
ae25 ff        rst     $38
ae26 ff        rst     $38
ae27 ff        rst     $38
ae28 feff      cp      $ff
ae2a ff        rst     $38
ae2b ff        rst     $38
ae2c ff        rst     $38
ae2d ff        rst     $38
ae2e 7c        ld      a,h
ae2f 7e        ld      a,(hl)
ae30 ff        rst     $38
ae31 ff        rst     $38
ae32 ff        rst     $38
ae33 ff        rst     $38
ae34 ff        rst     $38
ae35 ddcb18ee  set     5,(ix+$18)
ae39 dd360d0c  ld      (ix+$0d),$0c
ae3d dd360e0c  ld      (ix+$0e),$0c
ae41 2a5ad2    ld      hl,($d25a)
ae44 111001    ld      de,$0110
ae47 19        add     hl,de
ae48 dd5e02    ld      e,(ix+$02)
ae4b dd5603    ld      d,(ix+$03)
ae4e a7        and     a
ae4f ed52      sbc     hl,de
ae51 3004      jr      nc,_ae57
ae53 dd3600ff  ld      (ix+$00),$ff
_ae57:
ae57 210202    ld      hl,$0202
ae5a 2214d2    ld      ($d214),hl
ae5d cd5639    call    _LABEL_3956_11
ae60 d4fd35    call    nc,_35fd
ae63 af        xor     a
ae64 dd360780  ld      (ix+$07),$80
ae68 dd360802  ld      (ix+$08),$02
ae6c dd7709    ld      (ix+$09),a
ae6f dd770a    ld      (ix+$0a),a
ae72 dd770b    ld      (ix+$0b),a
ae75 dd770c    ld      (ix+$0c),a
ae78 dd360f81  ld      (ix+$0f),$81
ae7c dd3610ae  ld      (ix+$10),$ae
ae80 c9        ret     
ae81 02        ld      (bc),a
ae82 04        inc     b
ae83 ff        rst     $38
ae84 ff        rst     $38
ae85 ff        rst     $38
ae86 ff        rst     $38
ae87 ff        rst     $38
ae88 ddcb18ee  set     5,(ix+$18)
ae8c ddcb1846  bit     0,(ix+$18)
ae90 2014      jr      nz,_aea6
ae92 dd361100  ld      (ix+$11),$00
ae96 dd36122a  ld      (ix+$12),$2a
ae9a dd361352  ld      (ix+$13),$52
ae9e dd36147c  ld      (ix+$14),$7c
aea2 ddcb18c6  set     0,(ix+$18)
_aea6:
aea6 dd6e02    ld      l,(ix+$02)
aea9 dd6603    ld      h,(ix+$03)
aeac ed5bfed3  ld      de,($d3fe)
aeb0 a7        and     a
aeb1 ed52      sbc     hl,de
aeb3 3823      jr      c,_aed8
aeb5 dd3607f8  ld      (ix+$07),$f8
aeb9 dd3608ff  ld      (ix+$08),$ff
aebd dd3609ff  ld      (ix+$09),$ff
aec1 dd360fd5  ld      (ix+$0f),$d5
aec5 dd3610b0  ld      (ix+$10),$b0
aec9 2180ff    ld      hl,$ff80
aecc 2216d2    ld      ($d216),hl
aecf cd98af    call    _af98
aed2 dd361601  ld      (ix+$16),$01
aed6 1821      jr      _aef9
_aed8:
aed8 dd360708  ld      (ix+$07),$08
aedc dd360800  ld      (ix+$08),$00
aee0 dd360900  ld      (ix+$09),$00
aee4 dd360fe7  ld      (ix+$0f),$e7
aee8 dd3610b0  ld      (ix+$10),$b0
aeec 218000    ld      hl,$0080
aeef 2216d2    ld      ($d216),hl
aef2 cd98af    call    _af98
aef5 dd3616ff  ld      (ix+$16),$ff
_aef9:
aef9 dd360d1c  ld      (ix+$0d),$1c
aefd dd360e1c  ld      (ix+$0e),$1c
af01 211212    ld      hl,$1212
af04 2214d2    ld      ($d214),hl
af07 cd5639    call    _LABEL_3956_11
af0a 211010    ld      hl,$1010
af0d 220ed2    ld      ($d20e),hl
af10 d4e535    call    nc,_35e5
af13 dd6e02    ld      l,(ix+$02)
af16 dd6603    ld      h,(ix+$03)
af19 220ed2    ld      ($d20e),hl
af1c dd6e05    ld      l,(ix+$05)
af1f dd6606    ld      h,(ix+$06)
af22 2210d2    ld      ($d210),hl
af25 dde5      push    ix
af27 e1        pop     hl
af28 111100    ld      de,$0011
af2b 19        add     hl,de
af2c 0604      ld      b,$04
_af2e:
af2e c5        push    bc
af2f e5        push    hl
af30 7e        ld      a,(hl)
af31 fefe      cp      $fe
af33 2838      jr      z,_af6d
af35 e6fe      and     $fe
af37 5f        ld      e,a
af38 1600      ld      d,$00
af3a 2131b0    ld      hl,$b031
af3d 19        add     hl,de
af3e e5        push    hl
af3f 5e        ld      e,(hl)
af40 ed5312d2  ld      ($d212),de
af44 23        inc     hl
af45 5e        ld      e,(hl)
af46 ed5314d2  ld      ($d214),de
af4a 3e24      ld      a,$24
af4c cd8135    call    _3581
af4f e1        pop     hl
af50 7e        ld      a,(hl)
af51 3c        inc     a
af52 3c        inc     a
af53 3214d2    ld      ($d214),a
af56 c604      add     a,$04
af58 dd770d    ld      (ix+$0d),a
af5b 23        inc     hl
af5c 7e        ld      a,(hl)
af5d 3c        inc     a
af5e 3c        inc     a
af5f 3215d2    ld      ($d215),a
af62 c604      add     a,$04
af64 dd770e    ld      (ix+$0e),a
af67 cd5639    call    _LABEL_3956_11
af6a d4fd35    call    nc,_35fd
_af6d:
af6d e1        pop     hl
af6e c1        pop     bc
af6f 7e        ld      a,(hl)
af70 fefe      cp      $fe
af72 2810      jr      z,_af84
af74 dd8616    add     a,(ix+$16)
af77 feff      cp      $ff
af79 2004      jr      nz,_af7f
af7b 3ea3      ld      a,$a3
af7d 1805      jr      _af84
_af7f:
af7f fea4      cp      $a4
af81 2001      jr      nz,_af84
af83 af        xor     a
_af84:
af84 77        ld      (hl),a
af85 23        inc     hl
af86 10a6      djnz    _af2e
af88 3a23d2    ld      a,($d223)
af8b e607      and     $07
af8d c8        ret     z
af8e dd7e15    ld      a,(ix+$15)
af91 fec8      cp      $c8
af93 d0        ret     nc
af94 dd3415    inc     (ix+$15)
af97 c9        ret     

_af98:
af98 dd7e15    ld      a,(ix+$15)
af9b fec8      cp      $c8
af9d c0        ret     nz
af9e 3ad4d2    ld      a,(S1_LEVEL_SOLIDITY)
afa1 fe03      cp      $03
afa3 c0        ret     nz
afa4 dd6e05    ld      l,(ix+$05)
afa7 dd6606    ld      h,(ix+$06)
afaa 11d0ff    ld      de,$ffd0
afad 19        add     hl,de
afae ed5b01d4  ld      de,($d401)
afb2 a7        and     a
afb3 ed52      sbc     hl,de
afb5 d0        ret     nc
afb6 dd6e05    ld      l,(ix+$05)
afb9 dd6606    ld      h,(ix+$06)
afbc 012c00    ld      bc,$002c
afbf 09        add     hl,bc
afc0 a7        and     a
afc1 ed52      sbc     hl,de
afc3 d8        ret     c
afc4 dde5      push    ix
afc6 e1        pop     hl
afc7 111100    ld      de,$0011
afca 19        add     hl,de
afcb 0604      ld      b,$04
_afcd:
afcd c5        push    bc
afce e5        push    hl
afcf 7e        ld      a,(hl)
afd0 fe4a      cp      $4a
afd2 ccdbaf    call    z,_afdb
afd5 e1        pop     hl
afd6 c1        pop     bc
afd7 23        inc     hl
afd8 10f3      djnz    _afcd
afda c9        ret     

_afdb:
afdb 36fe      ld      (hl),$fe
afdd cd7b7c    call    _7c7b
afe0 d8        ret     c
afe1 dde5      push    ix
afe3 dd5e02    ld      e,(ix+$02)
afe6 dd5603    ld      d,(ix+$03)
afe9 dd4e05    ld      c,(ix+$05)
afec dd4606    ld      b,(ix+$06)
afef e5        push    hl
aff0 dde1      pop     ix
aff2 af        xor     a
aff3 dd360036  ld      (ix+$00),$36
aff7 dd7701    ld      (ix+$01),a
affa 211200    ld      hl,$0012
affd 19        add     hl,de
affe dd7502    ld      (ix+$02),l
b001 dd7403    ld      (ix+$03),h
b004 dd7704    ld      (ix+$04),a
b007 211e00    ld      hl,$001e
b00a 09        add     hl,bc
b00b dd7505    ld      (ix+$05),l
b00e dd7406    ld      (ix+$06),h
b011 2a16d2    ld      hl,($d216)
b014 dd7507    ld      (ix+$07),l
b017 dd7408    ld      (ix+$08),h
b01a af        xor     a
b01b cb7c      bit     7,h
b01d 2802      jr      z,_b021
b01f 3eff      ld      a,$ff
_b021:
b021 dd7709    ld      (ix+$09),a
b024 af        xor     a
b025 dd770a    ld      (ix+$0a),a
b028 dd770b    ld      (ix+$0b),a
b02b dd770c    ld      (ix+$0c),a
b02e dde1      pop     ix
b030 c9        ret     

b031 0c        inc     c
b032 03        inc     bc
b033 0d        dec     c
b034 03        inc     bc
b035 0e03      ld      c,$03
b037 0e04      ld      c,$04
b039 0f        rrca    
b03a 04        inc     b
b03b 1004      djnz----$b041
b03d 1005      djnz----$b044
b03f 110511    ld      de,$1105
b042 0612      ld      b,$12
b044 0612      ld      b,$12
b046 07        rlca    
b047 13        inc     de
b048 07        rlca    
b049 13        inc     de
b04a 08        ex      af,af'
b04b 13        inc     de
b04c 09        add     hl,bc
b04d 14        inc     d
b04e 09        add     hl,bc
b04f 14        inc     d
b050 0a        ld      a,(bc)
b051 14        inc     d
b052 0b        dec     bc
b053 15        dec     d
b054 0b        dec     bc
b055 15        dec     d
b056 0c        inc     c
b057 15        dec     d
b058 0d        dec     c
b059 15        dec     d
b05a 0e15      ld      c,$15
b05c 0f        rrca    
b05d 15        dec     d
b05e 1015      djnz----$b075
b060 111411    ld      de,$1114
b063 14        inc     d
b064 12        ld      (de),a
b065 14        inc     d
b066 13        inc     de
b067 13        inc     de
b068 13        inc     de
b069 13        inc     de
b06a 14        inc     d
b06b 13        inc     de
b06c 15        dec     d
b06d 12        ld      (de),a
b06e 15        dec     d
b06f 12        ld      (de),a
b070 1611      ld      d,$11
b072 1611      ld      d,$11
b074 17        rla     
b075 1017      djnz----$b08e
b077 1018      djnz----$b091
b079 0f        rrca    
b07a 180e      jr------$b08a
b07c 180e      jr------$b08c
b07e 19        add     hl,de
b07f 0d        dec     c
b080 19        add     hl,de
b081 0c        inc     c
b082 19        add     hl,de
b083 0b        dec     bc
b084 19        add     hl,de
b085 0a        ld      a,(bc)
b086 19        add     hl,de
b087 09        add     hl,bc
b088 19        add     hl,de
b089 09        add     hl,bc
b08a 1808      jr------$b094
b08c 1807      jr------$b095
b08e 1807      jr------$b097
b090 17        rla     
b091 0617      ld      b,$17
b093 0616      ld      b,$16
b095 05        dec     b
b096 1605      ld      d,$05
b098 15        dec     d
b099 04        inc     b
b09a 15        dec     d
b09b 04        inc     b
b09c 14        inc     d
b09d 04        inc     b
b09e 13        inc     de
b09f 03        inc     bc
b0a0 13        inc     de
b0a1 03        inc     bc
b0a2 12        ld      (de),a
b0a3 03        inc     bc

b0a4 110211    ld      de,$1102
b0a7 02        ld      (bc),a
b0a8 1002      djnz    _b0ac
b0aa 0f        rrca    
b0ab 02        ld      (bc),a
_b0ac:
b0ac 0e02      ld      c,$02
b0ae 0d        dec     c
b0af 02        ld      (bc),a
b0b0 0c        inc     c
b0b1 02        ld      (bc),a
b0b2 0b        dec     bc
b0b3 03        inc     bc
b0b4 0b        dec     bc
b0b5 03        inc     bc
b0b6 0a        ld      a,(bc)
b0b7 03        inc     bc
b0b8 09        add     hl,bc
b0b9 04        inc     b
b0ba 09        add     hl,bc
b0bb 04        inc     b
b0bc 08        ex      af,af'
b0bd 04        inc     b
b0be 07        rlca    
b0bf 05        dec     b
b0c0 07        rlca    
b0c1 05        dec     b
b0c2 0606      ld      b,$06
b0c4 0606      ld      b,$06
b0c6 05        dec     b
b0c7 07        rlca    
b0c8 05        dec     b
b0c9 07        rlca    
b0ca 04        inc     b
b0cb 08        ex      af,af'
b0cc 04        inc     b
b0cd 09        add     hl,bc
b0ce 04        inc     b
b0cf 09        add     hl,bc
b0d0 03        inc     bc
b0d1 0a        ld      a,(bc)
b0d2 03        inc     bc
b0d3 0b        dec     bc
b0d4 03        inc     bc
b0d5 feff      cp      $ff
b0d7 ff        rst     $38
b0d8 ff        rst     $38
b0d9 ff        rst     $38
b0da ff        rst     $38
b0db fe26      cp      $26
b0dd 28ff      jr------z,$b0de
b0df ff        rst     $38
b0e0 ff        rst     $38
b0e1 ff        rst     $38
b0e2 ff        rst     $38
b0e3 ff        rst     $38
b0e4 ff        rst     $38
b0e5 ff        rst     $38
b0e6 ff        rst     $38
b0e7 feff      cp      $ff
b0e9 ff        rst     $38
b0ea ff        rst     $38
b0eb ff        rst     $38
b0ec ff        rst     $38
b0ed fe20      cp      $20
b0ef 22ffff    ld      (SMS_PAGE_2),hl
b0f2 ff        rst     $38
b0f3 ff        rst     $38
b0f4 ddcb18ee  set     5,(ix+$18)
b0f8 dd360f00  ld      (ix+$0f),$00
b0fc dd361000  ld      (ix+$10),$00
b100 dd360d04  ld      (ix+$0d),$04
b104 dd360e0a  ld      (ix+$0e),$0a
b108 210206    ld      hl,$0602
b10b 2214d2    ld      ($d214),hl
b10e cd5639    call    _LABEL_3956_11
b111 d4fd35    call    nc,_35fd
b114 dd6e02    ld      l,(ix+$02)
b117 dd6603    ld      h,(ix+$03)
b11a 220ed2    ld      ($d20e),hl
b11d eb        ex      de,hl
b11e 2a5ad2    ld      hl,($d25a)
b121 01f0ff    ld      bc,$fff0
b124 09        add     hl,bc
b125 a7        and     a
b126 ed52      sbc     hl,de
b128 303d      jr      nc,_b167
b12a 2a5ad2    ld      hl,($d25a)
b12d 011001    ld      bc,$0110
b130 09        add     hl,bc
b131 a7        and     a
b132 ed52      sbc     hl,de
b134 3831      jr      c,_b167
b136 dd6e05    ld      l,(ix+$05)
b139 dd6606    ld      h,(ix+$06)
b13c 2210d2    ld      ($d210),hl
b13f eb        ex      de,hl
b140 2a5dd2    ld      hl,($d25d)
b143 01f0ff    ld      bc,$fff0
b146 09        add     hl,bc
b147 a7        and     a
b148 ed52      sbc     hl,de
b14a 301b      jr      nc,_b167
b14c 2a5dd2    ld      hl,($d25d)
b14f 01d000    ld      bc,$00d0
b152 09        add     hl,bc
b153 a7        and     a
b154 ed52      sbc     hl,de
b156 380f      jr      c,_b167
b158 210000    ld      hl,$0000
b15b 2212d2    ld      ($d212),hl
b15e 2214d2    ld      ($d214),hl
b161 3e24      ld      a,$24
b163 cd8135    call    _3581
b166 c9        ret     
_b167:
b167 dd3600ff  ld      (ix+$00),$ff
b16b c9        ret     
b16c ddcb18ee  set     5,(ix+$18)
b170 ddcb1846  bit     0,(ix+$18)
b174 200c      jr      nz,_b182
b176 cd2506    call    _LABEL_625_57
b179 e607      and     $07
b17b dd7711    ld      (ix+$11),a
b17e ddcb18c6  set     0,(ix+$18)
_b182:
b182 dd360f00  ld      (ix+$0f),$00
b186 dd361000  ld      (ix+$10),$00
b18a dd6e02    ld      l,(ix+$02)
b18d dd6603    ld      h,(ix+$03)
b190 220ed2    ld      ($d20e),hl
b193 dd6e05    ld      l,(ix+$05)
b196 dd6606    ld      h,(ix+$06)
b199 2210d2    ld      ($d210),hl
b19c dd7e11    ld      a,(ix+$11)
b19f 87        add     a,a
b1a0 87        add     a,a
b1a1 87        add     a,a
b1a2 5f        ld      e,a
b1a3 1600      ld      d,$00
b1a5 2127b2    ld      hl,$b227
b1a8 19        add     hl,de
b1a9 0602      ld      b,$02
_b1ab:
b1ab c5        push    bc
b1ac 1600      ld      d,$00
b1ae 5e        ld      e,(hl)
b1af cb7b      bit     7,e
b1b1 2802      jr      z,_b1b5
b1b3 16ff      ld      d,$ff
_b1b5:
b1b5 ed5312d2  ld      ($d212),de
b1b9 23        inc     hl
b1ba 1600      ld      d,$00
b1bc 5e        ld      e,(hl)
b1bd cb7b      bit     7,e
b1bf 2802      jr      z,_b1c3
b1c1 16ff      ld      d,$ff
_b1c3:
b1c3 ed5314d2  ld      ($d214),de
b1c7 23        inc     hl
b1c8 7e        ld      a,(hl)
b1c9 23        inc     hl
b1ca 23        inc     hl
b1cb feff      cp      $ff
b1cd 2805      jr      z,_b1d4
b1cf e5        push    hl
b1d0 cd8135    call    _3581
b1d3 e1        pop     hl
_b1d4:
b1d4 c1        pop     bc
b1d5 10d4      djnz    _b1ab
b1d7 3a23d2    ld      a,($d223)
b1da e63f      and     $3f
b1dc 2009      jr      nz,_b1e7
b1de dd7e11    ld      a,(ix+$11)
b1e1 3c        inc     a
b1e2 e607      and     $07
b1e4 dd7711    ld      (ix+$11),a
_b1e7:
b1e7 dd3412    inc     (ix+$12)
b1ea dd7e12    ld      a,(ix+$12)
b1ed fe1a      cp      $1a
b1ef c0        ret     nz
b1f0 dd361200  ld      (ix+$12),$00
b1f4 dd7e11    ld      a,(ix+$11)
b1f7 87        add     a,a
b1f8 5f        ld      e,a
b1f9 87        add     a,a
b1fa 83        add     a,e
b1fb 5f        ld      e,a
b1fc 1600      ld      d,$00
b1fe 2167b2    ld      hl,$b267
b201 19        add     hl,de
b202 5e        ld      e,(hl)
b203 23        inc     hl
b204 56        ld      d,(hl)
b205 23        inc     hl
b206 ed5312d2  ld      ($d212),de
b20a 5e        ld      e,(hl)
b20b 23        inc     hl
b20c 56        ld      d,(hl)
b20d ed5314d2  ld      ($d214),de
b211 23        inc     hl
b212 5e        ld      e,(hl)
b213 1600      ld      d,$00
b215 cb7b      bit     7,e
b217 2801      jr      z,_b21a
b219 15        dec     d
_b21a:
b21a 23        inc     hl
b21b 4e        ld      c,(hl)
b21c 0600      ld      b,$00
b21e cb79      bit     7,c
b220 2801      jr      z,_b223
b222 05        dec     b
_b223:
b223 cdc2b5    call    _b5c2
b226 c9        ret     
b227 08        ex      af,af'
b228 f8        ret     m

b229 66        ld      h,(hl)
b22a 00        nop     
b22b 00        nop     
b22c 00        nop     
b22d ff        rst     $38
b22e 00        nop     
b22f 0c        inc     c
b230 fa7000    jp------m,$0070
b233 14        inc     d
b234 fa7200    jp------m,$0072
b237 0f        rrca    
b238 07        rlca    
b239 4c        ld      c,h
b23a 00        nop     
b23b 17        rla     
b23c 07        rlca    
b23d 4e        ld      c,(hl)
b23e 00        nop     
b23f 0d        dec     c
b240 0c        inc     c
b241 6c        ld      l,h
b242 00        nop     
b243 15        dec     d
b244 0c        inc     c
b245 6e        ld      l,(hl)
b246 00        nop     
b247 08        ex      af,af'
b248 0f        rrca    
b249 64        ld      h,h
b24a 00        nop     
b24b 00        nop     
b24c 00        nop     
b24d ff        rst     $38
b24e 00        nop     
b24f fc0c68    call----m,$680c
b252 00        nop     
b253 04        inc     b
b254 0c        inc     c
b255 6a        ld      l,d
b256 00        nop     
b257 f9        ld      sp,hl
b258 07        rlca    
b259 48        ld      c,b
b25a 00        nop     
b25b 01074a    ld      bc,$4a07
b25e 00        nop     
b25f fb        ei      
b260 f9        ld      sp,hl
b261 50        ld      d,b
b262 00        nop     
b263 03        inc     bc
b264 f9        ld      sp,hl
b265 52        ld      d,d
b266 00        nop     
b267 00        nop     
b268 00        nop     
b269 00        nop     
b26a fe08      cp      $08
b26c f0        ret     p
b26d 00        nop     
b26e 0100ff    ld      bc,$ff00
b271 18f8      jr------$b26b
b273 00        nop     
b274 02        ld      (bc),a
b275 00        nop     
b276 00        nop     
b277 1e07      ld      e,$07
b279 00        nop     
b27a 010001    ld      bc,$0100
b27d 1616      ld      d,$16
b27f 00        nop     
b280 00        nop     
b281 00        nop     
b282 02        ld      (bc),a
b283 08        ex      af,af'
b284 2000      jr------nz,$b286
b286 ff        rst     $38
b287 00        nop     
b288 01f818    ld      bc,$18f8
b28b 00        nop     
b28c fe00      cp      $00
b28e 00        nop     
b28f f20700    jp------p,$0007
b292 ff        rst     $38
b293 00        nop     
b294 ff        rst     $38
b295 f7        rst     $30
b296 f6dd      or      $dd
b298 cb18      rr      b
b29a eedd      xor     $dd
b29c cb18      rr      b
b29e 46        ld      b,(hl)
b29f 2016      jr      nz,_b2b7
b2a1 dd7e04    ld      a,(ix+$04)
b2a4 dd7712    ld      (ix+$12),a
b2a7 dd7e05    ld      a,(ix+$05)
b2aa dd7713    ld      (ix+$13),a
b2ad dd7e06    ld      a,(ix+$06)
b2b0 dd7714    ld      (ix+$14),a
b2b3 ddcb18c6  set     0,(ix+$18)
_b2b7:
b2b7 3aa3d2    ld      a,($d2a3)
b2ba 4f        ld      c,a
b2bb ed5ba1d2  ld      de,($d2a1)
b2bf dd6e12    ld      l,(ix+$12)
b2c2 dd6613    ld      h,(ix+$13)
b2c5 dd7e14    ld      a,(ix+$14)
b2c8 19        add     hl,de
b2c9 89        adc     a,c
b2ca dd7504    ld      (ix+$04),l
b2cd dd7405    ld      (ix+$05),h
b2d0 dd7706    ld      (ix+$06),a
b2d3 3a08d4    ld      a,($d408)
b2d6 a7        and     a
b2d7 fa29b3    jp      m,_b329
b2da dd360d1e  ld      (ix+$0d),$1e
b2de dd360e10  ld      (ix+$0e),$10
b2e2 21020a    ld      hl,$0a02
b2e5 2214d2    ld      ($d214),hl
b2e8 cd5639    call    _LABEL_3956_11
b2eb 383c      jr      c,_b329
b2ed 213000    ld      hl,$0030
b2f0 226bd2    ld      ($d26b),hl
b2f3 213000    ld      hl,$0030
b2f6 226dd2    ld      ($d26d),hl
b2f9 011000    ld      bc,$0010
b2fc 110000    ld      de,$0000
b2ff cdc17c    call    _LABEL_7CC1_12
b302 dd6e01    ld      l,(ix+$01)
b305 dd6602    ld      h,(ix+$02)
b308 dd7e03    ld      a,(ix+$03)
b30b 118000    ld      de,$0080
b30e 19        add     hl,de
b30f ce00      adc     a,$00
b311 dd7501    ld      (ix+$01),l
b314 dd7402    ld      (ix+$02),h
b317 dd7703    ld      (ix+$03),a
b31a 2afdd3    ld      hl,($d3fd)
b31d 3affd3    ld      a,($d3ff)
b320 19        add     hl,de
b321 ce00      adc     a,$00
b323 22fdd3    ld      ($d3fd),hl
b326 32ffd3    ld      ($d3ff),a
_b329:
b329 dd6e02    ld      l,(ix+$02)
b32c dd6603    ld      h,(ix+$03)
b32f 220ed2    ld      ($d20e),hl
b332 dd6e05    ld      l,(ix+$05)
b335 dd6606    ld      h,(ix+$06)
b338 2210d2    ld      ($d210),hl
b33b 21f8ff    ld      hl,$fff8
b33e 2212d2    ld      ($d212),hl
b341 dd5e11    ld      e,(ix+$11)
b344 1600      ld      d,$00
b346 2188b3    ld      hl,$b388
b349 19        add     hl,de
b34a 0602      ld      b,$02
_b34c:
b34c c5        push    bc
b34d 5e        ld      e,(hl)
b34e 1600      ld      d,$00
b350 23        inc     hl
b351 ed5314d2  ld      ($d214),de
b355 7e        ld      a,(hl)
b356 23        inc     hl
b357 feff      cp      $ff
b359 2805      jr      z,_b360
b35b e5        push    hl
b35c cd8135    call    _3581
b35f e1        pop     hl
_b360:
b360 c1        pop     bc
b361 10e9      djnz    _b34c
b363 dd360f7b  ld      (ix+$0f),$7b
b367 dd3610b3  ld      (ix+$10),$b3
b36b dd7e11    ld      a,(ix+$11)
b36e c604      add     a,$04
b370 dd7711    ld      (ix+$11),a
b373 fe10      cp      $10
b375 d8        ret     c
b376 dd361100  ld      (ix+$11),$00
b37a c9        ret     
b37b feff      cp      $ff
b37d ff        rst     $38
b37e ff        rst     $38
b37f ff        rst     $38
b380 ff        rst     $38
b381 3636      ld      (hl),$36
b383 3636      ld      (hl),$36
b385 ff        rst     $38
b386 ff        rst     $38
b387 ff        rst     $38
b388 08        ex      af,af'
b389 1c        inc     e
b38a 183c      jr      _b3c8
b38c 08        ex      af,af'
b38d 1e18      ld      e,$18
b38f 3e08      ld      a,$08
b391 3818      jr      c,_b3ab
b393 3a0c1a    ld      a,($1a0c)
b396 00        nop     
b397 ff        rst     $38
b398 ddcb18ee  set     5,(ix+$18)
b39c ddcb1846  bit     0,(ix+$18)
b3a0 2010      jr      nz,_b3b2
b3a2 dd6e02    ld      l,(ix+$02)
b3a5 dd6603    ld      h,(ix+$03)
b3a8 dd7511    ld      (ix+$11),l
_b3ab:
b3ab dd7412    ld      (ix+$12),h
b3ae ddcb18c6  set     0,(ix+$18)
_b3b2:
b3b2 dd360d0c  ld      (ix+$0d),$0c
b3b6 dd360e2e  ld      (ix+$0e),$2e
b3ba dd360f5b  ld      (ix+$0f),$5b
b3be dd3610b4  ld      (ix+$10),$b4
b3c2 210202    ld      hl,$0202
b3c5 2214d2    ld      ($d214),hl
_b3c8:
b3c8 cd5639    call    _LABEL_3956_11
b3cb d4fd35    call    nc,_35fd
b3ce dd6e01    ld      l,(ix+$01)
b3d1 dd6602    ld      h,(ix+$02)
b3d4 dd7e03    ld      a,(ix+$03)
b3d7 118000    ld      de,$0080
b3da 19        add     hl,de
b3db ce00      adc     a,$00
b3dd 6c        ld      l,h
b3de 67        ld      h,a
b3df 220ed2    ld      ($d20e),hl
b3e2 dd6e05    ld      l,(ix+$05)
b3e5 dd6606    ld      h,(ix+$06)
b3e8 2210d2    ld      ($d210),hl
b3eb 210000    ld      hl,$0000
b3ee 2212d2    ld      ($d212),hl
b3f1 21f0ff    ld      hl,$fff0
b3f4 2214d2    ld      ($d214),hl
b3f7 3e16      ld      a,$16
b3f9 cd8135    call    _3581
b3fc 210800    ld      hl,$0008
b3ff 2212d2    ld      ($d212),hl
b402 3e18      ld      a,$18
b404 cd8135    call    _3581
b407 dd6e02    ld      l,(ix+$02)
b40a dd6603    ld      h,(ix+$03)
b40d 118005    ld      de,$0580
b410 af        xor     a
b411 dd7707    ld      (ix+$07),a
b414 dd7708    ld      (ix+$08),a
b417 dd7709    ld      (ix+$09),a
b41a ed52      sbc     hl,de
b41c d0        ret     nc
b41d dd4e05    ld      c,(ix+$05)
b420 dd4606    ld      b,(ix+$06)
b423 214000    ld      hl,$0040
b426 09        add     hl,bc
b427 ed5b5dd2  ld      de,($d25d)
b42b a7        and     a
b42c ed52      sbc     hl,de
b42e 300c      jr      nc,_b43c
b430 dd7e11    ld      a,(ix+$11)
b433 dd7702    ld      (ix+$02),a
b436 dd7e12    ld      a,(ix+$12)
b439 dd7703    ld      (ix+$03),a
_b43c:
b43c ed5b01d4  ld      de,($d401)
b440 21e0ff    ld      hl,$ffe0
b443 09        add     hl,bc
b444 af        xor     a
b445 ed52      sbc     hl,de
b447 d0        ret     nc
b448 212c00    ld      hl,$002c
b44b 09        add     hl,bc
b44c af        xor     a
b44d ed52      sbc     hl,de
b44f d8        ret     c
b450 dd360780  ld      (ix+$07),$80
b454 dd7708    ld      (ix+$08),a
b457 dd7709    ld      (ix+$09),a
b45a c9        ret     
b45b 1618      ld      d,$18
b45d ff        rst     $38
b45e ff        rst     $38
b45f ff        rst     $38
b460 ff        rst     $38
b461 1618      ld      d,$18
b463 ff        rst     $38
b464 ff        rst     $38
b465 ff        rst     $38
b466 ff        rst     $38
b467 1618      ld      d,$18
b469 ff        rst     $38
b46a ff        rst     $38
b46b ff        rst     $38
b46c ff        rst     $38
b46d ddcb18ee  set     5,(ix+$18)
b471 ddcb1846  bit     0,(ix+$18)
b475 2015      jr      nz,_b48c
b477 010000    ld      bc,$0000
b47a 59        ld      e,c
b47b 50        ld      d,b
b47c cdf936    call    _36f9
b47f 7e        ld      a,(hl)
b480 d63c      sub     $3c
b482 fe04      cp      $04
b484 d0        ret     nc
b485 dd7711    ld      (ix+$11),a
b488 ddcb18c6  set     0,(ix+$18)
_b48c:
b48c dd3412    inc     (ix+$12)
b48f dd7e12    ld      a,(ix+$12)
b492 cb77      bit     6,a
b494 c0        ret     nz
b495 e60f      and     $0f
b497 c0        ret     nz
b498 dd7e11    ld      a,(ix+$11)
b49b 87        add     a,a
b49c 5f        ld      e,a
b49d 87        add     a,a
b49e 87        add     a,a
b49f 83        add     a,e
b4a0 5f        ld      e,a
b4a1 1600      ld      d,$00
b4a3 21e6b4    ld      hl,$b4e6
b4a6 19        add     hl,de
b4a7 5e        ld      e,(hl)
b4a8 23        inc     hl
b4a9 56        ld      d,(hl)
b4aa 23        inc     hl
b4ab ed5312d2  ld      ($d212),de
b4af 5e        ld      e,(hl)
b4b0 23        inc     hl
b4b1 56        ld      d,(hl)
b4b2 23        inc     hl
b4b3 ed5314d2  ld      ($d214),de
b4b7 5e        ld      e,(hl)
b4b8 23        inc     hl
b4b9 56        ld      d,(hl)
b4ba 23        inc     hl
b4bb 4e        ld      c,(hl)
b4bc 23        inc     hl
b4bd 46        ld      b,(hl)
b4be 23        inc     hl
b4bf d9        exx     
b4c0 dd5e02    ld      e,(ix+$02)
b4c3 dd5603    ld      d,(ix+$03)
b4c6 2afed3    ld      hl,($d3fe)
b4c9 a7        and     a
b4ca ed52      sbc     hl,de
b4cc 7c        ld      a,h
b4cd d9        exx     
b4ce be        cp      (hl)
b4cf c0        ret     nz
b4d0 23        inc     hl
b4d1 d9        exx     
b4d2 dd5e05    ld      e,(ix+$05)
b4d5 dd5606    ld      d,(ix+$06)
b4d8 2a01d4    ld      hl,($d401)
b4db a7        and     a
b4dc ed52      sbc     hl,de
b4de 7c        ld      a,h
b4df d9        exx     
b4e0 be        cp      (hl)
b4e1 c0        ret     nz
b4e2 cdc2b5    call    _b5c2
b4e5 c9        ret     
b4e6 80        add     a,b
b4e7 fe80      cp      $80
b4e9 fe00      cp      $00
b4eb 00        nop     
b4ec f8        ret     m
b4ed ff        rst     $38
b4ee ff        rst     $38
b4ef ff        rst     $38
b4f0 80        add     a,b
b4f1 0180fe    ld      bc,$fe80
b4f4 1800      jr------$b4f6
b4f6 f8        ret     m
b4f7 ff        rst     $38
b4f8 00        nop     
b4f9 ff        rst     $38
b4fa 80        add     a,b
b4fb fe80      cp      $80
b4fd 010000    ld      bc,$0000
b500 1000      djnz----$b502
b502 ff        rst     $38
b503 00        nop     
b504 80        add     a,b
b505 018001    ld      bc,$0180
b508 1800      jr------$b50a
b50a 1000      djnz----$b50c
b50c 00        nop     
b50d 00        nop     
b50e ddcb18ee  set     5,(ix+$18)
b512 217bb3    ld      hl,$b37b
b515 3ad4d2    ld      a,(S1_LEVEL_SOLIDITY)
b518 fe01      cp      $01
b51a 2003      jr      nz,_b51f
b51c 21b5b5    ld      hl,$b5b5
_b51f:
b51f dd750f    ld      (ix+$0f),l
b522 dd7410    ld      (ix+$10),h
b525 3e50      ld      a,$50
b527 3216d2    ld      ($d216),a
b52a cd3bb5    call    _b53b
b52d dd3411    inc     (ix+$11)
b530 dd7e11    ld      a,(ix+$11)
b533 fea0      cp      $a0
b535 d8        ret     c
b536 dd361100  ld      (ix+$11),$00
b53a c9        ret     

_b53b:
b53b 3a16d2    ld      a,($d216)
b53e 6f        ld      l,a
b53f 111000    ld      de,$0010
b542 0e00      ld      c,$00
b544 dd7e11    ld      a,(ix+$11)
b547 bd        cp      l
b548 3804      jr      c,_b54e
b54a 0d        dec     c
b54b 11f0ff    ld      de,$fff0
_b54e:
b54e dd6e0a    ld      l,(ix+$0a)
b551 dd660b    ld      h,(ix+$0b)
b554 dd7e0c    ld      a,(ix+$0c)
b557 19        add     hl,de
b558 89        adc     a,c
b559 dd750a    ld      (ix+$0a),l
b55c dd740b    ld      (ix+$0b),h
b55f dd770c    ld      (ix+$0c),a
b562 7c        ld      a,h
b563 a7        and     a
b564 f281b5    jp      p,_b581
b567 7d        ld      a,l
b568 2f        cpl     
b569 6f        ld      l,a
b56a 7c        ld      a,h
b56b 2f        cpl     
b56c 67        ld      h,a
b56d 23        inc     hl
b56e 7c        ld      a,h
b56f fe02      cp      $02
b571 381e      jr      c,_b591
b573 dd360a00  ld      (ix+$0a),$00
b577 dd360bfe  ld      (ix+$0b),$fe
b57b dd360cff  ld      (ix+$0c),$ff
b57f 1810      jr      _b591
_b581:
b581 fe02      cp      $02
b583 380c      jr      c,_b591
b585 dd360a00  ld      (ix+$0a),$00
b589 dd360b02  ld      (ix+$0b),$02
b58d dd360c00  ld      (ix+$0c),$00
_b591:
b591 3a08d4    ld      a,($d408)
b594 a7        and     a
b595 f8        ret     m
b596 dd360d1e  ld      (ix+$0d),$1e
b59a dd360e1c  ld      (ix+$0e),$1c
b59e 210208    ld      hl,$0802
b5a1 2214d2    ld      ($d214),hl
b5a4 cd5639    call    _LABEL_3956_11
b5a7 d8        ret     c
b5a8 dd5e0a    ld      e,(ix+$0a)
b5ab dd560b    ld      d,(ix+$0b)
b5ae 011000    ld      bc,$0010
b5b1 cdc17c    call    _LABEL_7CC1_12
b5b4 c9        ret     
b5b5 feff      cp      $ff
b5b7 ff        rst     $38
b5b8 ff        rst     $38
b5b9 ff        rst     $38
b5ba ff        rst     $38
b5bb 6c        ld      l,h
b5bc 6e        ld      l,(hl)
b5bd 6c        ld      l,h
b5be 6e        ld      l,(hl)
b5bf ff        rst     $38
b5c0 ff        rst     $38
b5c1 ff        rst     $38

_b5c2:
b5c2 c5        push    bc
b5c3 d5        push    de
b5c4 cd7b7c    call    _7c7b
b5c7 d1        pop     de
b5c8 c1        pop     bc
b5c9 d8        ret     c
b5ca dde5      push    ix
b5cc e5        push    hl
b5cd dd6e02    ld      l,(ix+$02)
b5d0 dd6603    ld      h,(ix+$03)
b5d3 19        add     hl,de
b5d4 eb        ex      de,hl
b5d5 dd6e05    ld      l,(ix+$05)
b5d8 dd6606    ld      h,(ix+$06)
b5db 09        add     hl,bc
b5dc 4d        ld      c,l
b5dd 44        ld      b,h
b5de dde1      pop     ix
b5e0 af        xor     a
b5e1 dd36000d  ld      (ix+$00),$0d
b5e5 dd7701    ld      (ix+$01),a
b5e8 dd7302    ld      (ix+$02),e
b5eb dd7203    ld      (ix+$03),d
b5ee dd7704    ld      (ix+$04),a
b5f1 dd7105    ld      (ix+$05),c
b5f4 dd7006    ld      (ix+$06),b
b5f7 dd7711    ld      (ix+$11),a
b5fa dd7713    ld      (ix+$13),a
b5fd dd7714    ld      (ix+$14),a
b600 dd7715    ld      (ix+$15),a
b603 dd7716    ld      (ix+$16),a
b606 dd7717    ld      (ix+$17),a
b609 2a12d2    ld      hl,($d212)
b60c cb7c      bit     7,h
b60e 2802      jr      z,_b612
b610 3eff      ld      a,$ff
_b612:
b612 dd7507    ld      (ix+$07),l
b615 dd7408    ld      (ix+$08),h
b618 dd7709    ld      (ix+$09),a
b61b af        xor     a
b61c 2a14d2    ld      hl,($d214)
b61f cb7c      bit     7,h
b621 2802      jr      z,_b625
b623 3eff      ld      a,$ff
_b625:
b625 dd750a    ld      (ix+$0a),l
b628 dd740b    ld      (ix+$0b),h
b62b dd770c    ld      (ix+$0c),a
b62e dde1      pop     ix
b630 3e01      ld      a,$01
b632 ef        rst     $28
b633 c9        ret     
b634 dd360d1e  ld      (ix+$0d),$1e
b638 dd360e2f  ld      (ix+$0e),$2f
b63c ddcb18ee  set     5,(ix+$18)
b640 ddcb1856  bit     2,(ix+$18)
b644 c221b8    jp      nz,_b821
b647 cda67c    call    _7ca6
b64a cde6b7    call    _b7e6
b64d ddcb1846  bit     0,(ix+$18)
b651 2044      jr      nz,_b697
b653 215003    ld      hl,$0350
b656 112001    ld      de,$0120
b659 cd8c7c    call    _7c8c
b65c dd6e02    ld      l,(ix+$02)
b65f dd6603    ld      h,(ix+$03)
b662 110800    ld      de,$0008
b665 19        add     hl,de
b666 dd7502    ld      (ix+$02),l
b669 dd7403    ld      (ix+$03),h
b66c dd7511    ld      (ix+$11),l
b66f dd7412    ld      (ix+$12),h
b672 dd6e05    ld      l,(ix+$05)
b675 dd6606    ld      h,(ix+$06)
b678 111000    ld      de,$0010
b67b 19        add     hl,de
b67c dd7505    ld      (ix+$05),l
b67f dd7406    ld      (ix+$06),h
b682 dd7513    ld      (ix+$13),l
b685 dd7414    ld      (ix+$14),h
b688 af        xor     a
b689 32ecd2    ld      ($d2ec),a
b68c 3e0d      ld      a,$0d
b68e df        rst     $18
b68f fdcb08e6  set     4,(iy+$08)
b693 ddcb18c6  set     0,(ix+$18)
_b697:
b697 dd7e15    ld      a,(ix+$15)
b69a a7        and     a
b69b c2d4b6    jp      nz,_b6d4
b69e cd9fb9    call    _b99f
b6a1 3a23d2    ld      a,($d223)
b6a4 e607      and     $07
b6a6 c293b7    jp      nz,_b793
b6a9 dd7e16    ld      a,(ix+$16)
b6ac fe1c      cp      $1c
b6ae 300b      jr      nc,_b6bb
b6b0 dd3417    inc     (ix+$17)
b6b3 dd7e17    ld      a,(ix+$17)
b6b6 fe02      cp      $02
b6b8 dabfb6    jp      c,_b6bf
_b6bb:
b6bb dd361700  ld      (ix+$17),$00
_b6bf:
b6bf dd3416    inc     (ix+$16)
b6c2 dd7e16    ld      a,(ix+$16)
b6c5 fe28      cp      $28
b6c7 da93b7    jp      c,_b793
b6ca dd361600  ld      (ix+$16),$00
b6ce dd3415    inc     (ix+$15)
b6d1 c393b7    jp      _b793
_b6d4:
b6d4 3d        dec     a
b6d5 202a      jr      nz,_b701
b6d7 dd360a40  ld      (ix+$0a),$40
b6db dd360bfe  ld      (ix+$0b),$fe
b6df dd360cff  ld      (ix+$0c),$ff
b6e3 dd3415    inc     (ix+$15)
b6e6 dd6e11    ld      l,(ix+$11)
b6e9 dd6612    ld      h,(ix+$12)
b6ec 110400    ld      de,$0004
b6ef 19        add     hl,de
b6f0 dd7502    ld      (ix+$02),l
b6f3 dd7403    ld      (ix+$03),h
b6f6 dd360f1d  ld      (ix+$0f),$1d
b6fa dd3610bb  ld      (ix+$10),$bb
b6fe c393b7    jp      _b793
_b701:
b701 3d        dec     a
b702 c25cb7    jp      nz,_b75c
b705 dd6e0a    ld      l,(ix+$0a)
b708 dd660b    ld      h,(ix+$0b)
b70b dd7e0c    ld      a,(ix+$0c)
b70e 110e00    ld      de,$000e
b711 19        add     hl,de
b712 ce00      adc     a,$00
b714 4f        ld      c,a
b715 fa20b7    jp      m,_b720
b718 7c        ld      a,h
b719 fe02      cp      $02
b71b 3803      jr      c,_b720
b71d 210002    ld      hl,$0200
_b720:
b720 dd750a    ld      (ix+$0a),l
b723 dd740b    ld      (ix+$0b),h
b726 dd710c    ld      (ix+$0c),c
b729 dd360f1d  ld      (ix+$0f),$1d
b72d dd3610bb  ld      (ix+$10),$bb
b731 dd6e05    ld      l,(ix+$05)
b734 dd6606    ld      h,(ix+$06)
b737 2b        dec     hl
b738 dd5e13    ld      e,(ix+$13)
b73b dd5614    ld      d,(ix+$14)
b73e a7        and     a
b73f ed52      sbc     hl,de
b741 3850      jr      c,_b793
b743 dd7305    ld      (ix+$05),e
b746 dd7206    ld      (ix+$06),d
b749 af        xor     a
b74a dd7716    ld      (ix+$16),a
b74d dd770a    ld      (ix+$0a),a
b750 dd770b    ld      (ix+$0b),a
b753 dd770c    ld      (ix+$0c),a
b756 dd3415    inc     (ix+$15)
b759 c393b7    jp      _b793
_b75c:
b75c 3d        dec     a
b75d c293b7    jp      nz,_b793
b760 dd6e11    ld      l,(ix+$11)
b763 dd6612    ld      h,(ix+$12)
b766 dd7502    ld      (ix+$02),l
b769 dd7403    ld      (ix+$03),h
b76c dd7e16    ld      a,(ix+$16)
b76f a7        and     a
b770 ccd5b9    call    z,_b9d5
b773 dd361702  ld      (ix+$17),$02
b777 ddcb18ce  set     1,(ix+$18)
b77b cd9fb9    call    _b99f
b77e dd3416    inc     (ix+$16)
b781 dd7e16    ld      a,(ix+$16)
b784 fe12      cp      $12
b786 380b      jr      c,_b793
b788 ddcb188e  res     1,(ix+$18)
b78c af        xor     a
b78d dd7715    ld      (ix+$15),a
b790 dd7716    ld      (ix+$16),a
_b793:
b793 2131ba    ld      hl,$ba31
b796 ddcb184e  bit     1,(ix+$18)
b79a 2803      jr      z,_b79f
b79c 213bba    ld      hl,$ba3b
_b79f:
b79f 110ed2    ld      de,$d20e
b7a2 eda0      ldi     
b7a4 eda0      ldi     
b7a6 eda0      ldi     
b7a8 eda0      ldi     
b7aa eda0      ldi     
b7ac eda0      ldi     
b7ae eda0      ldi     
b7b0 eda0      ldi     
b7b2 7e        ld      a,(hl)
b7b3 23        inc     hl
b7b4 e5        push    hl
b7b5 cd8135    call    _3581
b7b8 2a12d2    ld      hl,($d212)
b7bb 110800    ld      de,$0008
b7be 19        add     hl,de
b7bf 2212d2    ld      ($d212),hl
b7c2 e1        pop     hl
b7c3 7e        ld      a,(hl)
b7c4 cd8135    call    _3581
b7c7 3aecd2    ld      a,($d2ec)
b7ca fe0c      cp      $0c
b7cc d8        ret     c
b7cd af        xor     a
b7ce dd7711    ld      (ix+$11),a
b7d1 dd7716    ld      (ix+$16),a
b7d4 dd7717    ld      (ix+$17),a
b7d7 ddcb18d6  set     2,(ix+$18)
b7db fdcb08a6  res     4,(iy+$08)
b7df 3e04      ld      a,$04
b7e1 df        rst     $18
b7e2 3e21      ld      a,$21
b7e4 ef        rst     $28
b7e5 c9        ret     

_b7e6:
b7e6 3ab1d2    ld      a,($d2b1)
b7e9 a7        and     a
b7ea c0        ret     nz
b7eb fdcb0546  bit     0,(iy+$05)
b7ef c0        ret     nz
b7f0 3a14d4    ld      a,($d414)
b7f3 0f        rrca    
b7f4 3803      jr      c,_b7f9
b7f6 e602      and     $02
b7f8 c8        ret     z
_b7f9:
b7f9 2afed3    ld      hl,($d3fe)
b7fc 111004    ld      de,$0410
b7ff a7        and     a
b800 ed52      sbc     hl,de
b802 d8        ret     c
b803 2100fd    ld      hl,$fd00
b806 3eff      ld      a,$ff
b808 2203d4    ld      ($d403),hl
b80b 3205d4    ld      ($d405),a
b80e 21b1d2    ld      hl,$d2b1
b811 3618      ld      (hl),$18
b813 23        inc     hl
b814 360c      ld      (hl),$0c
b816 23        inc     hl
b817 363f      ld      (hl),$3f
b819 3e01      ld      a,$01
b81b ef        rst     $28
b81c 21ecd2    ld      hl,$d2ec
b81f 34        inc     (hl)
b820 c9        ret     
_b821:
b821 ddcb185e  bit     3,(ix+$18)
b825 c25bb9    jp      nz,_b95b
b828 ddcb18ae  res     5,(ix+$18)
b82c dd7e11    ld      a,(ix+$11)
b82f fe0f      cp      $0f
b831 3037      jr      nc,_b86a
b833 87        add     a,a
b834 87        add     a,a
b835 5f        ld      e,a
b836 87        add     a,a
b837 83        add     a,e
b838 5f        ld      e,a
b839 1600      ld      d,$00
b83b 2145ba    ld      hl,$ba45
b83e 19        add     hl,de
b83f 5e        ld      e,(hl)
b840 23        inc     hl
b841 56        ld      d,(hl)
b842 23        inc     hl
b843 ed53abd2  ld      ($d2ab),de
b847 5e        ld      e,(hl)
b848 23        inc     hl
b849 56        ld      d,(hl)
b84a 23        inc     hl
b84b ed53add2  ld      ($d2ad),de
b84f 22afd2    ld      ($d2af),hl
b852 dd3411    inc     (ix+$11)
b855 dd7e11    ld      a,(ix+$11)
b858 fe0f      cp      $0f
b85a 200e      jr      nz,_b86a
b85c fdcb00ee  set     5,(iy+$00)
b860 fdcb028e  res     1,(iy+$02)
b864 215005    ld      hl,$0550
b867 2275d2    ld      ($d275),hl
_b86a:
b86a dd5e02    ld      e,(ix+$02)
b86d dd5603    ld      d,(ix+$03)
b870 21e005    ld      hl,$05e0
b873 af        xor     a
b874 ed52      sbc     hl,de
b876 3005      jr      nc,_b87d
b878 4f        ld      c,a
b879 47        ld      b,a
b87a c399b8    jp      _b899
_b87d:
b87d eb        ex      de,hl
b87e ed5bfed3  ld      de,($d3fe)
b882 af        xor     a
b883 ed52      sbc     hl,de
b885 114000    ld      de,$0040
b888 af        xor     a
b889 ed4b03d4  ld      bc,($d403)
b88d cb78      bit     7,b
b88f 2004      jr      nz,_b895
b891 ed52      sbc     hl,de
b893 3803      jr      c,_b898
_b895:
b895 0180ff    ld      bc,$ff80
_b898:
b898 04        inc     b
_b899:
b899 dd7107    ld      (ix+$07),c
b89c dd7008    ld      (ix+$08),b
b89f dd7709    ld      (ix+$09),a
b8a2 dd7e17    ld      a,(ix+$17)
b8a5 fe06      cp      $06
b8a7 2018      jr      nz,_b8c1
b8a9 dd7e16    ld      a,(ix+$16)
b8ac 3d        dec     a
b8ad 2012      jr      nz,_b8c1
b8af ddcb187e  bit     7,(ix+$18)
b8b3 280c      jr      z,_b8c1
b8b5 dd360a00  ld      (ix+$0a),$00
b8b9 dd360bff  ld      (ix+$0b),$ff
b8bd dd360cff  ld      (ix+$0c),$ff
_b8c1:
b8c1 111700    ld      de,$0017
b8c4 013600    ld      bc,$0036
b8c7 cdf936    call    _36f9
b8ca 5e        ld      e,(hl)
b8cb 1600      ld      d,$00
b8cd 21283f    ld      hl,$3f28
b8d0 19        add     hl,de
b8d1 7e        ld      a,(hl)
b8d2 e63f      and     $3f
b8d4 a7        and     a
b8d5 2812      jr      z,_b8e9
b8d7 ddcb187e  bit     7,(ix+$18)
b8db 280c      jr      z,_b8e9
b8dd dd360a80  ld      (ix+$0a),$80
b8e1 dd360bfd  ld      (ix+$0b),$fd
b8e5 dd360cff  ld      (ix+$0c),$ff
_b8e9:
b8e9 110000    ld      de,$0000
b8ec 010800    ld      bc,$0008
b8ef cdf936    call    _36f9
b8f2 7e        ld      a,(hl)
b8f3 fe49      cp      $49
b8f5 2036      jr      nz,_b92d
b8f7 ddcb187e  bit     7,(ix+$18)
b8fb 2830      jr      z,_b92d
b8fd af        xor     a
b8fe dd7716    ld      (ix+$16),a
b901 dd7717    ld      (ix+$17),a
b904 dd7707    ld      (ix+$07),a
b907 dd7708    ld      (ix+$08),a
b90a dd7709    ld      (ix+$09),a
b90d dd3611e0  ld      (ix+$11),$e0
b911 dd361205  ld      (ix+$12),$05
b915 dd361360  ld      (ix+$13),$60
b919 dd361401  ld      (ix+$14),$01
b91d 215005    ld      hl,$0550
b920 112001    ld      de,$0120
b923 cd8c7c    call    _7c8c
b926 ddcb18de  set     3,(ix+$18)
b92a c35bb9    jp      _b95b
_b92d:
b92d dd6e0a    ld      l,(ix+$0a)
b930 dd660b    ld      h,(ix+$0b)
b933 dd7e0c    ld      a,(ix+$0c)
b936 110e00    ld      de,$000e
b939 19        add     hl,de
b93a ce00      adc     a,$00
b93c 4f        ld      c,a
b93d fa48b9    jp      m,_b948
b940 7c        ld      a,h
b941 fe02      cp      $02
b943 3803      jr      c,_b948
b945 210002    ld      hl,$0200
_b948:
b948 dd750a    ld      (ix+$0a),l
b94b dd740b    ld      (ix+$0b),h
b94e dd710c    ld      (ix+$0c),c
b951 0128ba    ld      bc,$ba28
b954 11f9ba    ld      de,$baf9
b957 cd417c    call    _7c41
b95a c9        ret     
_b95b:
b95b fd3603ff  ld      (iy+$03),$ff
b95f cd9fb9    call    _b99f
b962 dd7e16    ld      a,(ix+$16)
b965 fe30      cp      $30
b967 3021      jr      nc,_b98a
b969 4f        ld      c,a
b96a 3a23d2    ld      a,($d223)
b96d e607      and     $07
b96f 200c      jr      nz,_b97d
b971 dd7e17    ld      a,(ix+$17)
b974 3c        inc     a
b975 e601      and     $01
b977 dd7717    ld      (ix+$17),a
b97a dd3416    inc     (ix+$16)
_b97d:
b97d 79        ld      a,c
b97e fe2c      cp      $2c
b980 d8        ret     c
b981 dd360f77  ld      (ix+$0f),$77
b985 dd3610bb  ld      (ix+$10),$bb
b989 c9        ret     
_b98a:
b98a af        xor     a
b98b dd770f    ld      (ix+$0f),a
b98e dd7710    ld      (ix+$10),a
b991 dd3416    inc     (ix+$16)
b994 dd7e16    ld      a,(ix+$16)
b997 fe70      cp      $70
b999 d8        ret     c
b99a dd3600ff  ld      (ix+$00),$ff
b99e c9        ret     

_b99f:
b99f 211cba    ld      hl,$ba1c
b9a2 dd7e17    ld      a,(ix+$17)
b9a5 87        add     a,a
b9a6 87        add     a,a
b9a7 5f        ld      e,a
b9a8 1600      ld      d,$00
b9aa 42        ld      b,d
b9ab 19        add     hl,de
b9ac 4e        ld      c,(hl)
b9ad 23        inc     hl
b9ae 5e        ld      e,(hl)
b9af 23        inc     hl
b9b0 7e        ld      a,(hl)
b9b1 23        inc     hl
b9b2 66        ld      h,(hl)
b9b3 6f        ld      l,a
b9b4 dd750f    ld      (ix+$0f),l
b9b7 dd7410    ld      (ix+$10),h
b9ba dd6e11    ld      l,(ix+$11)
b9bd dd6612    ld      h,(ix+$12)
b9c0 09        add     hl,bc
b9c1 dd7502    ld      (ix+$02),l
b9c4 dd7403    ld      (ix+$03),h
b9c7 dd6e13    ld      l,(ix+$13)
b9ca dd6614    ld      h,(ix+$14)
b9cd 19        add     hl,de
b9ce dd7505    ld      (ix+$05),l
b9d1 dd7406    ld      (ix+$06),h
b9d4 c9        ret     

_b9d5:
b9d5 fdcb086e  bit     5,(iy+$08)
b9d9 c0        ret     nz
b9da cd7b7c    call    _7c7b
b9dd d8        ret     c
b9de dde5      push    ix
b9e0 e5        push    hl
b9e1 dde1      pop     ix
b9e3 af        xor     a
b9e4 dd360047  ld      (ix+$00),$47
b9e8 dd7701    ld      (ix+$01),a
b9eb 212004    ld      hl,$0420
b9ee dd7502    ld      (ix+$02),l
b9f1 dd7403    ld      (ix+$03),h
b9f4 dd7704    ld      (ix+$04),a
b9f7 212f01    ld      hl,$012f
b9fa dd7505    ld      (ix+$05),l
b9fd dd7406    ld      (ix+$06),h
ba00 dd7711    ld      (ix+$11),a
ba03 dd7718    ld      (ix+$18),a
ba06 dd7707    ld      (ix+$07),a
ba09 dd7708    ld      (ix+$08),a
ba0c dd7709    ld      (ix+$09),a
ba0f dd770a    ld      (ix+$0a),a
ba12 dd770b    ld      (ix+$0b),a
ba15 dd770c    ld      (ix+$0c),a
ba18 dde1      pop     ix
ba1a c9        ret     
ba1b c9        ret     
ba1c 00        nop     
ba1d 00        nop     
ba1e f9        ld      sp,hl
ba1f ba        cp      d
ba20 00        nop     
ba21 02        ld      (bc),a
ba22 0b        dec     bc
ba23 bb        cp      e
ba24 00        nop     
ba25 07        rlca    
ba26 0b        dec     bc
ba27 bb        cp      e
ba28 03        inc     bc
ba29 08        ex      af,af'
ba2a 04        inc     b
ba2b 07        rlca    
ba2c 05        dec     b
ba2d 08        ex      af,af'
ba2e 04        inc     b
ba2f 07        rlca    
ba30 ff        rst     $38
ba31 3004      jr      nc,_ba37
ba33 a0        and     b
ba34 010000    ld      bc,$0000
_ba37:
ba37 00        nop     
ba38 00        nop     
ba39 2022      jr------nz,$ba5d
ba3b 3004      jr------nc,$ba41
ba3d a0        and     b
ba3e 010000    ld      bc,$0000
ba41 00        nop     
ba42 00        nop     
ba43 24        inc     h
ba44 2620      ld      h,$20
ba46 04        inc     b
ba47 60        ld      h,b
ba48 013710    ld      bc,$1037
ba4b 3810      jr------c,$ba5d
ba4d 4a        ld      c,d
ba4e 104b      djnz----$ba9b
ba50 1030      djnz----$ba82
ba52 04        inc     b
ba53 60        ld      h,b
ba54 012810    ld      bc,$1028
ba57 19        add     hl,de
ba58 104c      djnz----$baa6
ba5a 104d      djnz----$baa9
ba5c 1040      djnz----$ba9e
ba5e 04        inc     b
ba5f 60        ld      h,b
ba60 010010    ld      bc,$1000
ba63 2d        dec     l
ba64 104e      djnz----$bab4
ba66 104f      djnz----$bab7
ba68 1020      djnz----$ba8a
ba6a 04        inc     b
ba6b 70        ld      (hl),b
ba6c 010000    ld      bc,$0000
ba6f 00        nop     
ba70 00        nop     
ba71 00        nop     
ba72 00        nop     
ba73 00        nop     
ba74 00        nop     
ba75 3004      jr------nc,$ba7b
ba77 70        ld      (hl),b
ba78 010000    ld      bc,$0000
ba7b 00        nop     
ba7c 00        nop     
ba7d 00        nop     
ba7e 00        nop     
ba7f 00        nop     
ba80 00        nop     
ba81 40        ld      b,b
ba82 04        inc     b
ba83 70        ld      (hl),b
ba84 010000    ld      bc,$0000
ba87 00        nop     
ba88 00        nop     
ba89 00        nop     
ba8a 00        nop     
ba8b 00        nop     
ba8c 00        nop     
ba8d 2004      jr------nz,$ba93
ba8f 80        add     a,b
ba90 010000    ld      bc,$0000
ba93 00        nop     
ba94 00        nop     
ba95 00        nop     
ba96 00        nop     
ba97 00        nop     
ba98 00        nop     
ba99 3004      jr------nc,$ba9f
ba9b 80        add     a,b
ba9c 010000    ld      bc,$0000
ba9f 00        nop     
baa0 00        nop     
baa1 00        nop     
baa2 00        nop     
baa3 00        nop     
baa4 00        nop     
baa5 40        ld      b,b
baa6 04        inc     b
baa7 80        add     a,b
baa8 010000    ld      bc,$0000
baab 00        nop     
baac 00        nop     
baad 00        nop     
baae 00        nop     
baaf 00        nop     
bab0 00        nop     
bab1 2004      jr------nz,$bab7
bab3 90        sub     b
bab4 010000    ld      bc,$0000
bab7 00        nop     
bab8 00        nop     
bab9 00        nop     
baba 00        nop     
babb 00        nop     
babc 00        nop     
babd 3004      jr------nc,$bac3
babf 90        sub     b
bac0 010000    ld      bc,$0000
bac3 00        nop     
bac4 00        nop     
bac5 00        nop     
bac6 00        nop     
bac7 00        nop     
bac8 00        nop     
bac9 40        ld      b,b
baca 04        inc     b
bacb 90        sub     b
bacc 010000    ld      bc,$0000
bacf 00        nop     
bad0 00        nop     
bad1 00        nop     
bad2 00        nop     
bad3 00        nop     
bad4 00        nop     
bad5 2004      jr------nz,$badb
bad7 a0        and     b
bad8 015a10    ld      bc,$105a
badb 5b        ld      e,e
badc 1037      djnz----$bb15
bade 103b      djnz----$bb1b
bae0 1030      djnz----$bb12
bae2 04        inc     b
bae3 a0        and     b
bae4 015c10    ld      bc,$105c
bae7 5d        ld      e,l
bae8 103c      djnz----$bb26
baea 1000      djnz----$baec
baec 1040      djnz----$bb2e
baee 04        inc     b
baef a0        and     b
baf0 015e10    ld      bc,$105e
baf3 5f        ld      e,a
baf4 1000      djnz----$baf6
baf6 102d      djnz----$bb25
baf8 10fe      djnz----$baf8
bafa 0a        ld      a,(bc)
bafb 0c        inc     c
bafc 0eff      ld      c,$ff
bafe ff        rst     $38
baff 282a      jr------z,$bb2b
bb01 2c        inc     l
bb02 2eff      ld      l,$ff
bb04 ff        rst     $38
bb05 fe4a      cp      $4a
bb07 4c        ld      c,h
bb08 4e        ld      c,(hl)
bb09 ff        rst     $38
bb0a ff        rst     $38
bb0b fe0a      cp      $0a
bb0d 0c        inc     c
bb0e 0eff      ld      c,$ff
bb10 ff        rst     $38
bb11 282a      jr------z,$bb3d
bb13 2c        inc     l
bb14 2eff      ld      l,$ff
bb16 ff        rst     $38
bb17 fe02      cp      $02
bb19 04        inc     b
bb1a 06ff      ld      b,$ff
bb1c ff        rst     $38
bb1d 1012      djnz----$bb31
bb1f 14        inc     d
bb20 16ff      ld      d,$ff
bb22 ff        rst     $38
bb23 3032      jr------nc,$bb57
bb25 34        inc     (hl)
bb26 feff      cp      $ff
bb28 ff        rst     $38
bb29 50        ld      d,b
bb2a 52        ld      d,d
bb2b 54        ld      d,h
bb2c feff      cp      $ff
bb2e ff        rst     $38
bb2f 181a      jr------$bb4b
bb31 1c        inc     e
bb32 1eff      ld      e,$ff
bb34 ff        rst     $38
bb35 fe3a      cp      $3a
bb37 3c        inc     a
bb38 3eff      ld      a,$ff
bb3a ff        rst     $38
bb3b fe64      cp      $64
bb3d 66        ld      h,(hl)
bb3e 68        ld      l,b
bb3f ff        rst     $38
bb40 ff        rst     $38
bb41 181a      jr------$bb5d
bb43 1c        inc     e
bb44 1eff      ld      e,$ff
bb46 ff        rst     $38
bb47 fe3a      cp      $3a
bb49 3c        inc     a
bb4a 3eff      ld      a,$ff
bb4c ff        rst     $38
bb4d fe6a      cp      $6a
bb4f 6c        ld      l,h
bb50 6e        ld      l,(hl)
bb51 ff        rst     $38
bb52 ff        rst     $38
bb53 181a      jr------$bb6f
bb55 1c        inc     e
bb56 1eff      ld      e,$ff
bb58 ff        rst     $38
bb59 fe3a      cp      $3a
bb5b 3c        inc     a
bb5c 3eff      ld      a,$ff
bb5e ff        rst     $38
bb5f 70        ld      (hl),b
bb60 72        ld      (hl),d
bb61 5a        ld      e,d
bb62 5c        ld      e,h
bb63 5e        ld      e,(hl)
bb64 ff        rst     $38
bb65 00        nop     
bb66 0a        ld      a,(bc)
bb67 0c        inc     c
bb68 0eff      ld      c,$ff
bb6a ff        rst     $38
bb6b 282a      jr------z,$bb97
bb6d 2c        inc     l
bb6e 2eff      ld      l,$ff
bb70 ff        rst     $38
bb71 00        nop     
bb72 4a        ld      c,d
bb73 4c        ld      c,h
bb74 4e        ld      c,(hl)
bb75 ff        rst     $38
bb76 ff        rst     $38
bb77 feff      cp      $ff
bb79 ff        rst     $38
bb7a ff        rst     $38
bb7b ff        rst     $38
bb7c ff        rst     $38
bb7d fe44      cp      $44
bb7f 46        ld      b,(hl)
bb80 ff        rst     $38
bb81 ff        rst     $38
bb82 ff        rst     $38
bb83 ff        rst     $38

bb84 ddcb18ee  set     5,(ix+$18)
bb88 210800    ld      hl,$0008
bb8b 226bd2    ld      ($d26b),hl
bb8e ddcb1846  bit     0,(ix+$18)
bb92 2013      jr      nz,_bba7

		;UNKNOWN
bb94 213fef    ld      hl,$ef3f
bb97 110020    ld      de,$2000
bb9a 3e0c      ld      a,$0c
bb9c cd0504    call    decompressArt

bb9f dd361201  ld      (ix+$12),$01
bba3 ddcb18c6  set     0,(ix+$18)
_bba7:
bba7 219003    ld      hl,$0390
bbaa 220ed2    ld      ($d20e),hl
bbad dd6e11    ld      l,(ix+$11)
bbb0 2600      ld      h,$00
bbb2 2212d2    ld      ($d212),hl
bbb5 6c        ld      l,h
bbb6 2214d2    ld      ($d214),hl
bbb9 111a01    ld      de,$011a
bbbc 21ddbc    ld      hl,$bcdd
bbbf cda5bc    call    _bca5
bbc2 dd5e11    ld      e,(ix+$11)
bbc5 1600      ld      d,$00
bbc7 ed5312d2  ld      ($d212),de
bbcb 11d201    ld      de,$01d2
bbce 21ddbc    ld      hl,$bcdd
bbd1 cda5bc    call    _bca5
bbd4 fdcb0866  bit     4,(iy+$08)
bbd8 c8        ret     z
bbd9 ddcb184e  bit     1,(ix+$18)
bbdd 284c      jr      z,_bc2b
bbdf 3a23d2    ld      a,($d223)
bbe2 cb47      bit     0,a
bbe4 c0        ret     nz
bbe5 e602      and     $02
bbe7 5f        ld      e,a
bbe8 1600      ld      d,$00
bbea 21c7bc    ld      hl,$bcc7
bbed 19        add     hl,de
bbee 060a      ld      b,$0a
bbf0 113001    ld      de,$0130
_bbf3:
bbf3 c5        push    bc
bbf4 d5        push    de
bbf5 cda5bc    call    _bca5
bbf8 d1        pop     de
bbf9 e5        push    hl
bbfa 211000    ld      hl,$0010
bbfd 19        add     hl,de
bbfe eb        ex      de,hl
bbff e1        pop     hl
bc00 c1        pop     bc
bc01 10f0      djnz    _bbf3
bc03 219003    ld      hl,$0390
bc06 dd4e11    ld      c,(ix+$11)
bc09 0600      ld      b,$00
bc0b 09        add     hl,bc
bc0c 4d        ld      c,l
bc0d 44        ld      b,h
bc0e 210c00    ld      hl,$000c
bc11 09        add     hl,bc
bc12 ed5bfed3  ld      de,($d3fe)
bc16 a7        and     a
bc17 ed52      sbc     hl,de
bc19 3810      jr      c,_bc2b
bc1b 210e00    ld      hl,$000e
bc1e 19        add     hl,de
bc1f a7        and     a
bc20 ed42      sbc     hl,bc
bc22 3807      jr      c,_bc2b
bc24 fdcb0546  bit     0,(iy+$05)
bc28 ccfd35    call    z,_35fd
_bc2b
bc2b 3aecd2    ld      a,($d2ec)
bc2e fe06      cp      $06
bc30 3033      jr      nc,_bc65
bc32 ddcb184e  bit     1,(ix+$18)
bc36 2016      jr      nz,_bc4e
bc38 dd7e11    ld      a,(ix+$11)
bc3b 3c        inc     a
bc3c dd7711    ld      (ix+$11),a
bc3f fe80      cp      $80
bc41 d8        ret     c
bc42 3a23d2    ld      a,($d223)
bc45 4f        ld      c,a
bc46 e601      and     $01
bc48 c0        ret     nz
bc49 ddcb18ce  set     1,(ix+$18)
bc4d c9        ret     
_bc4e:
bc4e 3a23d2    ld      a,($d223)
bc51 e60f      and     $0f
bc53 2003      jr      nz,_bc58
bc55 3e13      ld      a,$13
bc57 ef        rst     $28
_bc58:
bc58 dd3511    dec     (ix+$11)
bc5b c0        ret     nz
bc5c dd361100  ld      (ix+$11),$00
bc60 ddcb188e  res     1,(ix+$18)
bc64 c9        ret     
_bc65:
bc65 2afed3    ld      hl,($d3fe)
bc68 dd5e02    ld      e,(ix+$02)
bc6b dd5603    ld      d,(ix+$03)
bc6e a7        and     a
bc6f ed52      sbc     hl,de
bc71 300b      jr      nc,_bc7e
bc73 dd7e11    ld      a,(ix+$11)
bc76 a7        and     a
bc77 280f      jr      z,_bc88
bc79 dd3511    dec     (ix+$11)
bc7c 180a      jr      _bc88
_bc7e:
bc7e dd7e11    ld      a,(ix+$11)
bc81 fe80      cp      $80
bc83 3003      jr      nc,_bc88
bc85 dd3411    inc     (ix+$11)
_bc88:
bc88 ddcb188e  res     1,(ix+$18)
bc8c 3a23d2    ld      a,($d223)
bc8f 4f        ld      c,a
bc90 e640      and     $40
bc92 c0        ret     nz
bc93 3aecd2    ld      a,($d2ec)
bc96 fe06      cp      $06
bc98 c8        ret     z
bc99 ddcb18ce  set     1,(ix+$18)
bc9d 79        ld      a,c
bc9e e61f      and     $1f
bca0 c0        ret     nz
bca1 3e13      ld      a,$13
bca3 ef        rst     $28
bca4 c9        ret     

_bca5:
bca5 ed5310d2  ld      ($d210),de
bca9 7e        ld      a,(hl)
bcaa 23        inc     hl
bcab e5        push    hl
bcac cd8135    call    _3581
bcaf e1        pop     hl
bcb0 7e        ld      a,(hl)
bcb1 23        inc     hl
bcb2 e5        push    hl
bcb3 2a12d2    ld      hl,($d212)
bcb6 e5        push    hl
bcb7 110800    ld      de,$0008
bcba 19        add     hl,de
bcbb 2212d2    ld      ($d212),hl
bcbe cd8135    call    _3581
bcc1 e1        pop     hl
bcc2 2212d2    ld      ($d212),hl
bcc5 e1        pop     hl
bcc6 c9        ret     
bcc7 3638      ld      (hl),$38
bcc9 56        ld      d,(hl)
bcca 58        ld      e,b
bccb 3638      ld      (hl),$38
bccd 56        ld      d,(hl)
bcce 58        ld      e,b
bccf 3638      ld      (hl),$38
bcd1 56        ld      d,(hl)
bcd2 58        ld      e,b
bcd3 3638      ld      (hl),$38
bcd5 56        ld      d,(hl)
bcd6 58        ld      e,b
bcd7 3638      ld      (hl),$38
bcd9 56        ld      d,(hl)
bcda 58        ld      e,b
bcdb 3638      ld      (hl),$38
bcdd 40        ld      b,b
bcde 42        ld      b,d
bcdf ddcb18ee  set     5,(ix+$18)
bce3 fdcb08ee  set     5,(iy+$08)
bce7 210202    ld      hl,$0202
bcea 2214d2    ld      ($d214),hl
bced cd5639    call    _LABEL_3956_11
bcf0 380a      jr      c,_bcfc
bcf2 fdcb0546  bit     0,(iy+$05)
bcf6 ccfd35    call    z,_35fd
bcf9 c3bebd    jp      _bdbe
_bcfc:
bcfc dd7e11    ld      a,(ix+$11)
bcff fec8      cp      $c8
bd01 daadbd    jp      c,_bdad
bd04 dd5e02    ld      e,(ix+$02)
bd07 dd5603    ld      d,(ix+$03)
bd0a 2a5ad2    ld      hl,($d25a)
bd0d 01f4ff    ld      bc,$fff4
bd10 09        add     hl,bc
bd11 a7        and     a
bd12 ed52      sbc     hl,de
bd14 d2bebd    jp      nc,_bdbe
bd17 2a5ad2    ld      hl,($d25a)
bd1a 24        inc     h
bd1b a7        and     a
bd1c ed52      sbc     hl,de
bd1e dabebd    jp      c,_bdbe
bd21 2afed3    ld      hl,($d3fe)
bd24 a7        and     a
bd25 ed52      sbc     hl,de
bd27 dd6e07    ld      l,(ix+$07)
bd2a dd6608    ld      h,(ix+$08)
bd2d dd7e09    ld      a,(ix+$09)
bd30 300e      jr      nc,_bd40
bd32 0eff      ld      c,$ff
bd34 11f4ff    ld      de,$fff4
bd37 cb7f      bit     7,a
bd39 2011      jr      nz,_bd4c
bd3b 11e8ff    ld      de,$ffe8
bd3e 180c      jr      _bd4c
_bd40:
bd40 0e00      ld      c,$00
bd42 110c00    ld      de,$000c
bd45 cb7f      bit     7,a
bd47 2803      jr      z,_bd4c
bd49 111800    ld      de,$0018
_bd4c:
bd4c 19        add     hl,de
bd4d 89        adc     a,c
bd4e dd7507    ld      (ix+$07),l
bd51 dd7408    ld      (ix+$08),h
bd54 dd7709    ld      (ix+$09),a
bd57 dd5e05    ld      e,(ix+$05)
bd5a dd5606    ld      d,(ix+$06)
bd5d 2a5dd2    ld      hl,($d25d)
bd60 01f4ff    ld      bc,$fff4
bd63 09        add     hl,bc
bd64 a7        and     a
bd65 ed52      sbc     hl,de
bd67 3055      jr      nc,_bdbe
bd69 2a5dd2    ld      hl,($d25d)
bd6c 01c000    ld      bc,$00c0
bd6f 19        add     hl,de
bd70 a7        and     a
bd71 ed52      sbc     hl,de
bd73 3849      jr      c,_bdbe
bd75 2a01d4    ld      hl,($d401)
bd78 a7        and     a
bd79 ed52      sbc     hl,de
bd7b dd6e0a    ld      l,(ix+$0a)
bd7e dd660b    ld      h,(ix+$0b)
bd81 dd7e0c    ld      a,(ix+$0c)
bd84 300e      jr      nc,_bd94
bd86 0eff      ld      c,$ff
bd88 11f6ff    ld      de,$fff6
bd8b cb7f      bit     7,a
bd8d 2011      jr      nz,_bda0
bd8f 11fbff    ld      de,$fffb
bd92 180c      jr      _bda0
_bd94:
bd94 110a00    ld      de,$000a
bd97 0e00      ld      c,$00
bd99 cb7f      bit     7,a
bd9b 2803      jr      z,_bda0
bd9d 110500    ld      de,$0005
_bda0:
bda0 19        add     hl,de
bda1 89        adc     a,c
bda2 dd750a    ld      (ix+$0a),l
bda5 dd740b    ld      (ix+$0b),h
bda8 dd770c    ld      (ix+$0c),a
bdab 1803      jr      _bdb0
_bdad:
bdad dd3411    inc     (ix+$11)
_bdb0:
bdb0 01c7bd    ld      bc,$bdc7
bdb3 11cebd    ld      de,$bdce
bdb6 cd417c    call    _7c41
bdb9 fdcb0866  bit     4,(iy+$08)
bdbd c0        ret     nz
_bdbe:
bdbe dd3600ff  ld      (ix+$00),$ff
bdc2 fdcb08ae  res     5,(iy+$08)
bdc6 c9        ret     
bdc7 00        nop     
bdc8 010101    ld      bc,$0101
bdcb 02        ld      (bc),a
bdcc 01ff44    ld      bc,$44ff
bdcf 46        ld      b,(hl)
bdd0 ff        rst     $38
bdd1 ff        rst     $38
bdd2 ff        rst     $38
bdd3 ff        rst     $38
bdd4 ff        rst     $38
bdd5 ff        rst     $38
bdd6 ff        rst     $38
bdd7 ff        rst     $38
bdd8 ff        rst     $38
bdd9 ff        rst     $38
bdda ff        rst     $38
bddb ff        rst     $38
bddc ff        rst     $38
bddd ff        rst     $38
bdde ff        rst     $38
bddf ff        rst     $38
bde0 48        ld      c,b
bde1 08        ex      af,af'
bde2 ff        rst     $38
bde3 ff        rst     $38
bde4 ff        rst     $38
bde5 ff        rst     $38
bde6 ff        rst     $38
bde7 ff        rst     $38
bde8 ff        rst     $38
bde9 ff        rst     $38
bdea ff        rst     $38
bdeb ff        rst     $38
bdec ff        rst     $38
bded ff        rst     $38
bdee ff        rst     $38
bdef ff        rst     $38
bdf0 ff        rst     $38
bdf1 ff        rst     $38
bdf2 60        ld      h,b
bdf3 62        ld      h,d
bdf4 ff        rst     $38
bdf5 ff        rst     $38
bdf6 ff        rst     $38
bdf7 ff        rst     $38
bdf8 ff        rst     $38
bdf9 ddcb18ee  set     5,(ix+$18)
bdfd fd3603ff  ld      (iy+$03),$ff
be01 ddcb184e  bit     1,(ix+$18)
be05 201f      jr      nz,_be26
be07 211c73    ld      hl,S1_BossPalette
be0a 3e02      ld      a,$02
be0c cd3303    call    loadPaletteOnInterrupt
be0f 3eff      ld      a,$ff
be11 32fcd3    ld      ($d3fc),a
be14 210000    ld      hl,$0000
be17 2201d4    ld      ($d401),hl
be1a dd3612ff  ld      (ix+$12),$ff
be1e fdcb07f6  set     6,(iy+$07)
be22 ddcb18ce  set     1,(ix+$18)
_be26:
be26 3a23d2    ld      a,($d223)
be29 0f        rrca    
be2a 3830      jr      c,_be5c
be2c dd7e12    ld      a,(ix+$12)
be2f a7        and     a
be30 282a      jr      z,_be5c
be32 dd3512    dec     (ix+$12)
be35 2025      jr      nz,_be5c
be37 dd6e02    ld      l,(ix+$02)
be3a dd6603    ld      h,(ix+$03)
be3d 113c00    ld      de,$003c
be40 19        add     hl,de
be41 22fed3    ld      ($d3fe),hl
be44 dd6e05    ld      l,(ix+$05)
be47 dd6606    ld      h,(ix+$06)
be4a 11c0ff    ld      de,$ffc0
be4d 19        add     hl,de
be4e 2201d4    ld      ($d401),hl
be51 af        xor     a
be52 32fcd3    ld      ($d3fc),a
be55 fdcb08f6  set     6,(iy+$08)
be59 3e06      ld      a,$06
be5b ef        rst     $28
_be5c:
be5c dd360d20  ld      (ix+$0d),$20
be60 dd360e1c  ld      (ix+$0e),$1c
be64 af        xor     a
be65 dd7707    ld      (ix+$07),a
be68 dd360801  ld      (ix+$08),$01
be6c dd7709    ld      (ix+$09),a
be6f dd770a    ld      (ix+$0a),a
be72 dd770b    ld      (ix+$0b),a
be75 dd770c    ld      (ix+$0c),a
be78 fdcb0776  bit     6,(iy+$07)
be7c 2818      jr      z,_be96
be7e ed5b5ad2  ld      de,($d25a)
be82 214000    ld      hl,$0040
be85 19        add     hl,de
be86 dd4e02    ld      c,(ix+$02)
be89 dd4603    ld      b,(ix+$03)
be8c a7        and     a
be8d ed42      sbc     hl,bc
be8f 3005      jr      nc,_be96
be91 13        inc     de
be92 ed535ad2  ld      ($d25a),de
_be96:
be96 dd360f21  ld      (ix+$0f),$21
be9a dd3610bf  ld      (ix+$10),$bf
be9e ddcb1846  bit     0,(ix+$18)
bea2 2033      jr      nz,_bed7
bea4 210810    ld      hl,$1008
bea7 2214d2    ld      ($d214),hl
beaa cd5639    call    _LABEL_3956_11
bead 3828      jr      c,_bed7
beaf 110100    ld      de,$0001
beb2 2a06d4    ld      hl,($d406)
beb5 7d        ld      a,l
beb6 2f        cpl     
beb7 6f        ld      l,a
beb8 7c        ld      a,h
beb9 2f        cpl     
beba 67        ld      h,a
bebb 3a08d4    ld      a,($d408)
bebe 2f        cpl     
bebf 19        add     hl,de
bec0 ce00      adc     a,$00
bec2 2206d4    ld      ($d406),hl
bec5 3208d4    ld      ($d408),a
bec8 fdcb07b6  res     6,(iy+$07)
becc ddcb18c6  set     0,(ix+$18)
bed0 dd361101  ld      (ix+$11),$01
bed4 3e01      ld      a,$01
bed6 ef        rst     $28
_bed7:
bed7 cdfa79    call    _79fa
beda ddcb1846  bit     0,(ix+$18)
bede c8        ret     z
bedf af        xor     a
bee0 dd360a40  ld      (ix+$0a),$40
bee4 dd770b    ld      (ix+$0b),a
bee7 dd770c    ld      (ix+$0c),a
beea dd360f33  ld      (ix+$0f),$33
beee dd3610bf  ld      (ix+$10),$bf
bef2 dd3511    dec     (ix+$11)
bef5 c0        ret     nz
bef6 cd3a7a    call    _7a3a
bef9 dd361118  ld      (ix+$11),$18
befd dd3413    inc     (ix+$13)
bf00 dd7e13    ld      a,(ix+$13)
bf03 fe0a      cp      $0a
bf05 d8        ret     c
bf06 3a7fd2    ld      a,($d27f)
bf09 fe06      cp      $06
bf0b 3805      jr      c,_bf12
bf0d fdcb08fe  set     7,(iy+$08)
bf11 c9        ret     
_bf12:
bf12 3a89d2    ld      a,($d289)
bf15 a7        and     a
bf16 c0        ret     nz
bf17 3e20      ld      a,$20
bf19 3289d2    ld      ($d289),a
bf1c fdcb0dd6  set     2,(iy+$0d)
bf20 c9        ret     
bf21 2a2c2e    ld      hl,($2e2c)
bf24 3032      jr------nc,$bf58
bf26 ff        rst     $38
bf27 4a        ld      c,d
bf28 4c        ld      c,h
bf29 4e        ld      c,(hl)
bf2a 50        ld      d,b
bf2b 52        ld      d,d
bf2c ff        rst     $38
bf2d 6a        ld      l,d
bf2e 6c        ld      l,h
bf2f 6e        ld      l,(hl)
bf30 70        ld      (hl),b
bf31 72        ld      (hl),d
bf32 ff        rst     $38
bf33 2a3436    ld      hl,($3634)
bf36 3832      jr------c,$bf6a
bf38 ff        rst     $38
bf39 4a        ld      c,d
bf3a 4c        ld      c,h
bf3b 4e        ld      c,(hl)
bf3c 50        ld      d,b
bf3d 52        ld      d,d
bf3e ff        rst     $38
bf3f 6a        ld      l,d
bf40 6c        ld      l,h
bf41 6e        ld      l,(hl)
bf42 70        ld      (hl),b
bf43 72        ld      (hl),d
bf44 ff        rst     $38
bf45 5c        ld      e,h
bf46 5e        ld      e,(hl)
bf47 ff        rst     $38
bf48 ff        rst     $38
bf49 ff        rst     $38
bf4a ff        rst     $38
bf4b ff        rst     $38

bf4c ddcb18ee  set     5,(ix+$18)
bf50 210054    ld      hl,$5400
bf53 cd1d0c    call    _c1d
bf56 ddcb1846  bit     0,(ix+$18)
bf5a 2022      jr      nz,_bf7e
bf5c af        xor     a
bf5d dd770f    ld      (ix+$0f),a
bf60 dd7710    ld      (ix+$10),a
bf63 dd7707    ld      (ix+$07),a
bf66 dd7708    ld      (ix+$08),a
bf69 dd7709    ld      (ix+$09),a
bf6c dd3411    inc     (ix+$11)
bf6f dd7e11    ld      a,(ix+$11)
bf72 fe50      cp      $50
bf74 d8        ret     c
bf75 ddcb18c6  set     0,(ix+$18)
bf79 dd361164  ld      (ix+$11),$64
bf7d c9        ret   
_bf7e:  
bf7e dd7e11    ld      a,(ix+$11)
bf81 a7        and     a
bf82 2805      jr      z,_bf89
bf84 dd3511    dec     (ix+$11)
bf87 180c      jr      _bf95
_bf89:
bf89 dd360a80  ld      (ix+$0a),$80
bf8d dd360bff  ld      (ix+$0b),$ff
bf91 dd360cff  ld      (ix+$0c),$ff
_bf95:
bf95 21f1bf    ld      hl,$bff1
bf98 3a23d2    ld      a,($d223)
bf9b 0f        rrca    
bf9c 3037      jr      nc,_bfd5
bf9e fd7e0a    ld      a,(iy+$0a)
bfa1 2a3cd2    ld      hl,($d23c)
bfa4 f5        push    af
bfa5 e5        push    hl
bfa6 2100d0    ld      hl,$d000
bfa9 223cd2    ld      ($d23c),hl
bfac dd6e05    ld      l,(ix+$05)
bfaf dd6606    ld      h,(ix+$06)
bfb2 ed5b5dd2  ld      de,($d25d)
bfb6 a7        and     a
bfb7 ed52      sbc     hl,de
bfb9 eb        ex      de,hl
bfba dd6e02    ld      l,(ix+$02)
bfbd dd6603    ld      h,(ix+$03)
bfc0 ed4b5ad2  ld      bc,($d25a)
bfc4 a7        and     a
bfc5 ed42      sbc     hl,bc
bfc7 01f1bf    ld      bc,$bff1
bfca cd0f35    call    _LABEL_350F_95
bfcd e1        pop     hl
bfce f1        pop     af
bfcf 223cd2    ld      ($d23c),hl
bfd2 fd770a    ld      (iy+$0a),a
_bfd5:
bfd5 dd6e05    ld      l,(ix+$05)
bfd8 dd6606    ld      h,(ix+$06)
bfdb 112000    ld      de,$0020
bfde 19        add     hl,de
bfdf ed5b5dd2  ld      de,($d25d)
bfe3 a7        and     a
bfe4 ed52      sbc     hl,de
bfe6 d0        ret     nc
bfe7 3e01      ld      a,$01
bfe9 3289d2    ld      ($d289),a
bfec fdcb0dd6  set     2,(iy+$0d)
bff0 c9        ret     
bff1 5c        ld      e,h
bff2 5e        ld      e,(hl)
bff3 ff        rst     $38
bff4 ff        rst     $38
bff5 ff        rst     $38
bff6 ff        rst     $38
bff7 ff        rst     $38
bff8 49        ld      c,c
bff9 43        ld      b,e
bffa 2054      jr------nz,$c050
bffc 48        ld      c,b
bffd 45        ld      b,l
bffe 2048      jr------nz,$c048
.ASM

;======================================================================================
;music code and song data

.BANK 3 SLOT 1

.ORG $C000
.ORGA $4000

_c000:		jp      _c23a
_c003:		jp      _c018
_c006:		jp      _c12d
_c009:		jp      _c1e5
_c00c:		jp      _c224
_c00f: 		jp      _c171
_c012:		jp      _c6eb
_c015:		jp      _c6ff

;--------------------------------------------------------------------------------------

_c018:
;HL : An address from a look up table, e.g. $64C3
	push    af
	push    bc
	push    de
	push    hl
	push    ix
	
	;copy HL to BC
	ld      c,l
	ld      b,h
	
	ld      ix,$dc1c
	ld      a,$05
_c026:
	;load the 16-bit value from the parameter address into DE
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ex      de,hl			;swap DE into HL
	add     hl,bc			;add the value to the initial address
	
	;copy the new address to RAM at $DC1C/D+
	ld      (ix+$00),l
	inc     ix
	ld      (ix+$00),h
	inc     ix
	ex      de,hl
	
	;repeat this process five times
	dec     a
	jp      nz,_c026
	
	;$64C3 + $1110 = $75D3
	;$64C3 + $2025 = $84E8
	;$64C3 + $3F3D = $A400
	;$64C3 + $393D = $9E00
	;$64C3 + $0024 = $64E7
	
	ld      hl,_c070

-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      a,d
	inc     a
	jr      z,+
	inc     hl
	ldi     
	ldi     
	jp      -
	
+	ld      hl,_c0d6
-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      a,d
	inc     a
	jr      z,+
	inc     hl
	ldi     
	jp      -
	
+	pop     ix
	pop     hl
	pop     de
	pop     bc
	pop     af
	ld      ($dc4f),hl
	ld      ($dc7c),hl
	ld      ($dca9),hl
	ld      ($dcd6),hl
	ret     

_c070:
.db $48, $DC, $00, $00, $75, $DC, $00, $00, $A2, $DC, $00, $00, $CF, $DC, $00, $00
.db $46, $DC, $07, $DD, $73, $DC, $08, $DD, $A0, $DC, $09, $DD, $CD, $DC, $0A, $DD
.db $28, $DC, $01, $00, $55, $DC, $01, $00, $82, $DC, $01, $00, $AF, $DC, $01, $00
.db $3D, $DC, $00, $00, $42, $DC, $00, $00, $6A, $DC, $00, $00, $6F, $DC, $00, $00
.db $97, $DC, $00, $00, $9C, $DC, $00, $00, $C4, $DC, $00, $00, $C9, $DC, $00, $00
.db $2E, $DC, $00, $00, $5B, $DC, $00, $00, $88, $DC, $00, $00, $B5, $DC, $00, $00
.db $0A, $DC, $01, $00, $FF, $FF
_c0d6:
.db $26, $DC, $80, $27, $DC, $90, $53, $DC, $A0, $54, $DC, $B0, $80, $DC, $C0, $81
.db $DC, $D0, $AD, $DC, $E0, $AE, $DC, $F0, $4E, $DC, $02, $7B, $DC, $02, $A8, $DC
.db $02, $D5, $DC, $02, $02, $DD, $00, $3A, $DC, $00, $67, $DC, $00, $94, $DC, $00
.db $C1, $DC, $00, $3B, $DC, $00, $68, $DC, $00, $95, $DC, $00, $C2, $DC, $00, $51
.db $DC, $00, $7E, $DC, $01, $AB, $DC, $02, $D8, $DC, $03, $06, $DC, $00, $04, $DC
.db $00, $FF, $FF

;____________________________________________________________________($4129)_[$C129]___

initPSGValues:
;    +xx+yyyy	;set channel xx volume to yyyy (0000 is max, 1111 is off)
.db %10011111	;mute channel 0
.db %10111111	;mute channel 1
.db %11011111	;mute channel 2
.db %11111111	;mute channel 3

_c12d:					;($412D) [$C12D]			
	;put any current values for these registers aside
	push    af
	push    hl
	push    bc
	
	ld      a,($dc4e)
	and     %11111101
	ld      ($dc4e),a
	
	ld      a,($dc7b)
	and     %11111101
	ld      ($dc7b),a
	
	ld      a,($dca8)
	and     %11111101
	ld      ($dca8),a
	
	ld      a,($dcd5)
	and     %11111101
	ld      ($dcd5),a
	
	ld      a,($dd02)
	and     %11111101
	ld      ($dd02),a
	
	xor     a
	ld      ($dc06),a
	
	;mute all sound channels by sending the right bytes to the sound chip
	ld      b,4
	ld      c,SMS_SOUND_PORT
	ld      hl,initPSGValues
	otir
	
	ld      a,($dc04)
	and     %11110111
	ld      ($dc04),a
	
	;restore the previous state of the registers and return
	pop     bc
	pop     hl
	pop     af
	ret     
	
;--------------------------------------------------------------------------------------
_c171:
	push    af
	push    de
	push    hl
	ld      e,a
	ld      a,($dc06)
	and     a
	jr      z,_c17e
	cp      e
	jr      c,_c1d9
_c17e:
	ld      a,e
	ld      ($dc06),a
	ld      ($dd03),hl
	ld      a,($dcdb)
	or      %00001111
	out     (SMS_SOUND_PORT),a
	ld      a,(hl)
	ld      ($dc05),a
	inc     hl
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      ($dd00),de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      ($dc0e),de
	inc     hl
	ld      ($dc24),hl
	ld      hl,_c1dd
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      a,(hl)
	ld      ($dcda),a
	inc     hl
	ld      a,(hl)
	ld      ($dcdb),a
	ld      hl,$0000
	ld      ($dcfc),hl
	ld      ($dcf1),hl
	ld      ($dcf6),hl
	ld      ($dce2),hl
	ld      a,$04
	ld      ($dd05),a
	inc     hl
	ld      ($dcdc),hl
	ld      hl,$dd0b
	ld      ($dcfa),hl
	ld      a,$02
	ld      ($dd02),a
_c1d9:
	pop     hl
	pop     de
	pop     af
	ret     

_c1dd:
.db $80, $90, $a0, $b0, $c0, $d0, $e0, $f0

;--------------------------------------------------------------------------------------

_c1e5:
	push    af
	ld      a,($dc4e)
	or      $02
	ld      ($dc4e),a
	ld      a,($dc7b)
	or      $02
	ld      ($dc7b),a
	ld      a,($dca8)
	or      $02
	ld      ($dca8),a
	ld      a,($dcd5)
	or      $02
	ld      ($dcd5),a
	ld      a,($dc52)
	ld      ($dc2b),a
	ld      a,($dc7f)
	ld      ($dc58),a
	ld      a,($dcac)
	ld      ($dc85),a
	ld      a,($dcd9)
	ld      ($dcb2),a
	xor     a
	ld      ($dc04),a
	pop     af
	ret     

;--------------------------------------------------------------------------------------

_c224:
	push    af
	push    hl
	ld      ($dc12),hl
	ld      a,($dc04)
	or      $08
	ld      ($dc04),a
	ld      hl,$1000
	ld      ($dc10),hl
	pop     hl
	pop     af
	ret     

;____________________________________________________________________($423A)_[$C23A]___

_c23a:
	ld      ix,$dc26
	ld      de,($dc1c)
	ld      bc,($dc0a)
	call    _c2f4
	ld      ($dc14),ix
	ld      ($dc1c),de
	
	ld      ix,$dc53
	ld      de,($dc1e)
	ld      bc,($dc0a)
	call    _c2f4
	ld      ($dc16),ix
	ld      ($dc1e),de
	
	ld      ix,$dc80
	ld      de,($dc20)
	ld      bc,($dc0a)
	call    _c2f4
	ld      ($dc18),ix
	ld      ($dc20),de
	
	ld      ix,$dcad
	ld      de,($dc22)
	ld      bc,($dc0a)
	call    _c2f4
	ld      ($dc1a),ix
	ld      ($dc22),de
	
	ld      ix,$dcda
	ld      de,($dc24)
	ld      bc,($dc0e)
	call    _c2f4
	ld      ($dc24),de
	bit     1,(ix+$28)
	jr      z,_c2bf
	
	ld      hl,$dc14
	ld      a,($dc05)
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      (hl),$da
	inc     hl
	ld      (hl),$dc
_c2bf:
	ld      ix,($dc14)
	call    _c3de
	ld      ix,($dc16)
	call    _c3de
	ld      ix,($dc18)
	call    _c3de
	ld      ix,($dc1a)
	call    _c3de
	
	ld      a,($dc04)
	and     $08
	ret     z
	
	ld      hl,($dc10)
	ld      bc,($dc12)
	and     a
	sbc     hl,bc
	jr      nc,_c2f0
	call    _c12d			;reset sound / mute?
_c2f0:
	ld      ($dc10),hl
	ret     

;____________________________________________________________________($42F4)_[$C2F4]___

_c2f4:
	bit     1,(ix+$28)
	ret     z
	
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	and     a
	sbc     hl,bc
	ld      (ix+$02),l
	ld      (ix+$03),h
	jr      z,_c30d
	jp      nc,_c3c9
_c30d:
	ld      a,(de)
	and     a
	jp      m,_c4f3
	cp      $70
	jr      c,_c34b
	cp      $7f
	jr      nz,_c321
	ld      (ix+$1e),$00
	jp      _c39f
_c321:
	push    de
	push    ix
	pop     hl
	ld      bc,$000e
	add     hl,bc
	ex      de,hl
	and     $0f
	ld      l,a
	ld      h,$00
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      bc,_c3ce
	add     hl,bc
	ld      a,(hl)
	ld      (ix+$25),a
	inc     hl
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	pop     de
	jp      _c36e
_c34b:
	and     $0f
	ld      hl,_c4d5
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      a,(hl)
	ld      (ix+$06),a
	inc     hl
	ld      a,(hl)
	ld      (ix+$07),a
	ld      a,(de)
	rrca    
	rrca    
	rrca    
	rrca    
	and     $0f
	ld      (ix+$1f),a
	bit     0,(ix+$28)
	jr      nz,_c39f
_c36e:
	ld      a,(ix+$14)
	ld      (ix+$19),a
	ld      a,(ix+$15)
	ld      (ix+$1a),a
	ld      a,(ix+$16)
	srl     a
	ld      (ix+$1b),a
	ld      a,(ix+$17)
	ld      (ix+$1c),a
	ld      a,(ix+$18)
	ld      (ix+$1d),a
	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0d),a
	ld      (ix+$0c),a
	ld      (ix+$1e),$0f
_c39f:
	inc     de
	ld      a,(de)
	inc     de
	and     a
	jr      nz,_c3a8
	ld      a,(ix+$24)
_c3a8:
	push    de
	ld      c,a
	ld      l,(ix+$26)
	ld      h,(ix+$27)
	ld      a,l
	or      h
	jr      nz,_c3b7
	ld      hl,($dc08)
_c3b7:
	call    _c6d8
	pop     de
	ld      a,l
	add     a,(ix+$02)
	ld      (ix+$02),a
	ld      a,h
	adc     a,(ix+$03)
	ld      (ix+$03),a
_c3c9:
	res     0,(ix+$28)
	ret     

_c3ce:
.db $05, $ff, $be, $0a, $04, $05, $02, $00, $05, $e6, $24, $5a, $14, $28, $08, $00

_c3de:
	bit     1,(ix+$28)
	ret     z
	ld      a,(ix+$0d)
	and     a
	jp      z,_c545

.db $3d, $ca, $5c, $45, $3d, $ca, $79, $45, $3d, $ca, $97, $45

_c3f6:
	ld      a,(ix+$00)
	cp      $e0
	jr      nz,_c412
	ld      c,(ix+$25)
	ld      a,($dc07)
	cp      c
	jp      z,_c48f
	ld      a,c
	ld      ($dc07),a
	or      %11100000		;noise channel frequency?
	out     (SMS_SOUND_PORT),a
	jp      _c48f
_c412:
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	ld      a,(ix+$19)
	and     a
	jr      z,_c424
	dec     (ix+$19)
	jp      _c45a
_c424:
	dec     (ix+$1a)
	jp      nz,_c45a
	ld      a,(ix+$15)
	ld      (ix+$1a),a
	ld      l,(ix+$1c)
	ld      h,(ix+$1d)
	dec     (ix+$1b)
	jp      nz,_c452
	ld      a,(ix+$16)
	ld      (ix+$1b),a
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      (ix+$1c),l
	ld      (ix+$1d),h
	jp      _c45a
_c452:
	add     hl,de
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ex      de,hl
_c45a:
	ld      l,(ix+$06)
	ld      h,(ix+$07)
	ld      c,(ix+$08)
	ld      b,(ix+$09)
	add     hl,bc
	add     hl,de
	ld      a,(ix+$1f)
	and     a
	jr      z,_c475
	ld      b,a
_c46f:
	srl     h
_c471:
	rr      l
	djnz    _c46f
_c475:
	ld      a,l
	and     %00001111
	or      (ix+$00)
	out     (SMS_SOUND_PORT),a
	ld      a,h
	rlca    
	rlca    
	rlca    
	rlca    
	and     %11110000
	ld      c,a
	ld      a,l
	rrca    
	rrca    
	rrca    
	rrca    
	and     %00001111
	or      c
	out     (SMS_SOUND_PORT),a
_c48f:
	ld      a,(ix+$05)
	and     a
	jr      z,_c4a7
	ld      c,a
	ld      a,(ix+$0c)
	and     a
	jr      z,_c4a7
	ld      l,a
	ld      h,$00
	call    _c6d8
	rl      l
	ld      a,$00
	adc     a,h
_c4a7:
	and     (ix+$1e)
	xor     %00001111
	or      (ix+$01)
	out     (SMS_SOUND_PORT),a
	ld      a,($dc04)
	and     $08
	ret     z
	ld      a,(ix+$2b)
	cp      $04
	ret     z
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      bc,($dc12)
	sbc     hl,bc
	jr      nc,_c4ce
	ld      hl,$0000
_c4ce:
	ld      (ix+$04),l
	ld      (ix+$05),h
	ret     

_c4d5:
.db $56, $03, $26, $03, $f9, $02, $ce, $02, $a5, $02, $80, $02, $5c, $02, $3a, $02
.db $1a, $02, $fb, $01, $df, $01, $c4, $01, $f7, $03, $be, $03, $88, $03

_c4f3:
	cp      $ff
	jp      z,_c50b
	cp      $fe
	jp      z,_c519
	inc     de
	ld      hl,_c529
	add     a,a
	ld      c,a
	ld      b,$00
	add     hl,bc
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	jp      (hl)
_c50b:
	ld      l,(ix+$22)
	ld      h,(ix+$23)
	ld      a,l
	or      h
	jr      z,_c51d
	ex      de,hl
	jp      _c30d
_c519:
	xor     a
	ld      ($dc06),a
_c51d:
	res     1,(ix+$28)
	ld      a,%00001111
	or      (ix+$01)
	out     (SMS_SOUND_PORT),a
	ret     

_c529:
.dw _c5ae, _c5d1, _c5f2, _c60a, _c620, _c62d, _c632, _c647
.dw _c67d, _c686, _c68e, _c696, _c6b4, _c6d1

_c545:
	ld      a,(ix+$0e)
	add     a,(ix+$0c)
	jp      nc,_c550
	ld      a,$ff
_c550:
	ld      (ix+$0c),a
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6
_c55c:
	ld      c,(ix+$10)
	ld      a,(ix+$0c)
	sub     (ix+$0f)
	jr      c,_c56d
	cp      (ix+$10)
	jr      c,_c56d
	ld      c,a
_c56d:
	ld      (ix+$0c),c
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6
_c579:
	ld      c,(ix+$12)
	ld      a,(ix+$0c)
	sub     (ix+$11)
	jr      c,_c58b
	cp      (ix+$12)
	jp      c,_c58b
	ld      c,a
_c58b:
	ld      (ix+$0c),c
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6
_c597:
	ld      a,(ix+$0c)
	sub     (ix+$13)
	jp      nc,_c5a2
	ld      a,$00
_c5a2:
	ld      (ix+$0c),a
	jp      nc,_c3f6
	inc     (ix+$0d)
	jp      _c3f6

_c5ae:
	ld      a,(de)
	ld      (ix+$26),a
	ld      ($dc08),a
	inc     de
	ld      a,(de)
	ld      (ix+$27),a
	ld      ($dc09),a
	inc     de
	ld      a,(de)
	ld      ($dc0a),a
	ld      ($dc0c),a
	inc     de
	ld      a,(de)
	ld      ($dc0b),a
	ld      ($dc0d),a
	inc     de
	jp      _c30d
_c5d1:
	ld      a,(de)
	ld      (ix+$2c),a
	inc     de
	ld      a,(ix+$2b)
	cp      $04
	jr      z,_c5e5
	ld      a,($dc04)
	and     $08
	jp      nz,_c30d
_c5e5:
	ld      a,(ix+$2c)
	ld      (ix+$05),a
	ld      (ix+$04),$00
	jp      _c30d
	
_c5f2:
	push    ix
	pop     hl
	ld      bc,$000e
	add     hl,bc
	ex      de,hl
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ex      de,hl
	jp      _c30d
_c60a:
	push    ix
	pop     hl
	ld      bc,$0014
	add     hl,bc
	ex      de,hl
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ex      de,hl
	jp      _c30d
_c620:
	ld      a,(de)
	ld      (ix+$08),a
	inc     de
	ld      a,(de)
	ld      (ix+$09),a
	inc     de
	jp      _c30d
_c62d:
	ld      a,(de)
	inc     de
	jp      _c30d
_c632:
	ld      l,(ix+$20)
	ld      h,(ix+$21)
	ld      (hl),$00
	ld      bc,$0005
	add     hl,bc
	ld      (ix+$20),l
	ld      (ix+$21),h
	jp      _c30d
_c647:
	ld      l,(ix+$20)
	ld      h,(ix+$21)
	ld      bc,$fffb
	add     hl,bc
	ld      a,(hl)
	and     a
	jr      nz,_c65d
	ld      a,(de)
	dec     a
	jr      z,_c671
	ld      (hl),a
	jp      _c660
_c65d:
	dec     (hl)
	jr      z,_c671
_c660:
	ex      de,hl
	inc     hl
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      c,(ix+$29)
	ld      b,(ix+$2a)
	add     hl,bc
	ex      de,hl
	jp      _c30d
_c671:
	ld      (ix+$20),l
	ld      (ix+$21),h
	inc     de
	inc     de
	inc     de
	jp      _c30d
_c67d:
	ld      (ix+$22),e
	ld      (ix+$23),d
	jp      _c30d
_c686:
	ld      a,(de)
	ld      (ix+$25),a
	inc     de
	jp      _c30d
_c68e:
	ld      a,(de)
	ld      (ix+$24),a
	inc     de
	jp      _c30d
_c696:
	ld      a,(ix+$2c)
	inc     a
	cp      $10
	jr      c,_c6a0
	ld      a,$0f
_c6a0:
	ld      (ix+$2c),a
	ld      a,($dc04)
	and     $08
	jp      nz,_c30d
	ld      a,(ix+$2c)
	ld      (ix+$05),a
	jp      _c30d
_c6b4:
	ld      a,(ix+$2c)
	dec     a
	cp      $10
	jr      c,_c6bd
	xor     a
_c6bd:
	ld      (ix+$2c),a
	ld      a,($dc04)
	and     $08
	jp      nz,_c30d
	ld      a,(ix+$2c)
	ld      (ix+$05),a
	jp      _c30d
_c6d1:
	set     0,(ix+$28)
	jp      _c30d
_c6d8:
	xor     a
	ld      b,$07
	ex      de,hl
	ld      l,a
	ld      h,a
_c6de:
	rl      c
	jp      nc,_c6e4
	add     hl,de
_c6e4:
	add     hl,hl
	djnz    _c6de
	or      c
	ret     z
	add     hl,de
	ret     

;--------------------------------------------------------------------------------------
;this fetches an address from a look up table and stores it in HL

_c6eb:
	push    hl
	ld      hl,S1_MusicPointers
	
	add     a,a
	add     a,l
	ld      l,a
	ld      a,$00
	adc     a,h
	ld      h,a
	
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	call    _c018
	
	pop     hl
	ret     

;--------------------------------------------------------------------------------------

_c6ff:
	push    hl
	push    de
	ld      hl,S1_SFXPointers
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      a,(hl)
	ex      de,hl
	call    _c171
	pop     de
	pop     hl
	ret

;____________________________________________________________________________[$C716]___

;insert the music data
.include "includes\music.asm"

;we might be able to set a background repeating text like this so that we don't have
 ;to specify precise gap-filling like this
.ORGA $7FB1
.db "Master System & Game Gear Version.  "
.db "'1991 (C)Ancient. (BANK0-4)", $A2
.db "SONIC THE HEDGE"

;======================================================================================

.BANK 4 SLOT 4
.ORGA $10000

;======================================================================================

.BANK 5 SLOT 5
.ORGA $14000

;======================================================================================

.BANK 6 SLOT 6
.ORGA $18000

;======================================================================================

.BANK 7 SLOT 7
.ORGA $1C000

;======================================================================================

.BANK 8 SLOT 8
.ORGA $20000

;======================================================================================

.BANK 9 SLOT 9
.ORGA $24000

;======================================================================================

.BANK 10 SLOT 10
.ORGA $28000

;======================================================================================

.BANK 11 SLOT 11
.ORGA $2C000

;======================================================================================

.BANK 12 SLOT 12
.ORGA $30000

;======================================================================================

.BANK 13 SLOT 13
.ORGA $34000

;======================================================================================

.BANK 14 SLOT 14
.ORGA $38000

;======================================================================================

.BANK 15 SLOT 15
.ORGA $3C000
