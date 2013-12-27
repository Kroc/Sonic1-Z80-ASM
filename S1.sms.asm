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

;SMSExamine: <smspower.org/Development/SMSExamine>
 ;this excellent tool disassembles much of the ROM by effectively 'running' the code
 ;to determine what parts are code and what parts are data. this saved a very large
 ;amount of effort, but due to the dynamic and complex nature of code, it didn't get
 ;all of it right, therefore I used:
 
;dz80: <inkland.org.uk/dz80>
 ;to do a byte-for-byte disassembly to fill in the blanks
 ;(this had to all be manually labelled!). that was largely wasted time as I later got
 ;help from the author of:
 
;Emulicious: <emulicious.net>
 ;which was able to provide a far superior disassembly that filled in all the gaps
 ;through a specific configuration file provided kindly by the author to assist me
 
;WLA DX <villehelin.com/wla.html>
 ;I was intending to write my own Z80 assembler (in VB6!), but I have found -- after
 ;some struggling to learn it -- that WLA DX will do an excellent job

;this disassembly was made possible by earlier documentation provided by
 ;David Declerk, ValleyBell, Penta Penguin and Ravenfreak

;======================================================================================

.MEMORYMAP		
	SLOTSIZE $4000	
	SLOT 0   $0000
	SLOT 1   $4000
	SLOT 2   $8000
	DEFAULTSLOT 0
.ENDME

.ROMBANKMAP
	BANKSTOTAL 16
	BANKSIZE $4000
	BANKS 16
.ENDRO


.IFEXISTS "ROM.sms"
	.BACKGROUND "ROM.sms"
.ELSE
	.PRINTT "Please provide a Sonic 1 ROM "
	.PRINTT "named 'ROM.sms' to fill in the data banks\n"
	.FAIL
.ENDIF

;hardware constants:
;======================================================================================
.DEF SMS_CURRENT_SCANLINE 	$7E	;current vertical scanline from 0 to 191
.DEF SMS_SOUND_PORT		$7F	;write-only port to send data to sound chip
.DEF SMS_VDP_DATA		$BE	;graphics data port
.DEF SMS_VDP_CONTROL		$BF	;graphics control port

.DEF SMS_PAGE_RAM		$FFFC	;RAM select register
.DEF SMS_PAGE_0			$FFFD	;Page 0 ROM Bank
.DEF SMS_PAGE_1			$FFFE	;Page 1 ROM Bank
.DEF SMS_PAGE_2			$FFFF	;Page 2 ROM Bank

.DEF SMS_JOYPAD_1		$DC
.DEF SMS_JOYPAD_2		$DD

;game variables:
;======================================================================================
;the programmers use the IY register as a shortcut to $D200
 ;to access commonly used variables and flags
 
.STRUCT vars				;$D200:
	
	;program flow control / loading flags?
	flags0			DB	;IY+$00
	;bit 0 - when `wait` is called, execution will loop until the bit is set
	;bit 1 - unknown (set at level load)
	;bit 3 - flag to load palette on IRQ
	;bit 5 - unknown
	;bit 6 - unknown
	
	;this is used only as the comparison byte in `loadFloorLayout`
	temp			DB	;IY+$01
	
	flags2			DB	;IY+$02
	;bit 0 - unknown
	;bit 1 - unknown
	;bit 2 - unknown
	
	;value of joypad port 1 - the bits are 1 for unpressed and 0 for pressed
	joypad			DB	;IY+$03
	;bit 0 - joypad 1 up
	;bit 1 - joypad 1 down
	;bit 2 - joypad 1 left
	;bit 3 - joypad 1 right
	;bit 4 - joypad button A
	;bit 5 - joypad button B
	
	;this does not appear referenced in any code
	unused			DB	;IY+$04
	
	;taken from the level header, this controls screen scrolling and the
	 ;presence of the "rings" count on the HUD
	scrollRingFlags		DB	;IY+$05
	;bit 0 - unknown, but causes Sonic to immediately die
	;bit 1 - demo mode
	;bit 2 - ring count displayed in HUD, rings visible in the level
	;bit 3 - automatic scrolling to the right
	;bit 4 - automatic scrolling upwards
	;bit 5 - smooth scrolling
	;bit 6 - up and down wave scrolling
	;bit 7 - screen does not scroll down
	
	flags6			DB	;IY+$06
	;bit 0 - unknown
	;bit 1 - unknown
	;bit 3 - unknown
	;bit 4 - unknown
	;bit 5 - unknown
	;bit 6 - unknown
	;bit 7 - level underwater flag (enables water line)
	
	;taken from the level header, this controls the presence of the time on
	 ;the HUD and if the lightning effect is in use
	timeLightningFlags	DB	;IY+$07
	;bit 0 - centers the time in the screen on special stages
	;bit 1 - enables the lightning effect
	;bit 4 - use the boss underwater palette (specially for Labyrinth Act 3)
	;bit 5 - time is displayed in the HUD
	;bit 6 - locks the screen, no scrolling
	
	;part of the level header -- always "0" for all levels, but unknown function
	unknown0		DB	;IY+$08
	
	flags9			DB	;IY+$09
	;bit 0 - unknown
	;bit 1 - enables interrupts during `decompressArt`
	
	spriteCount		DB	;IY+$0A, number of hardware sprites in use?
	origScrollRingFlags	DB	;IY+$0B, copy made during level loading UNUSED
	origFlags6		DB	;IY+$0C, copy made during level loading
.ENDST

;temporary variables:
;--------------------------------------------------------------------------------------

;these variables are reused throughout, some times for passing extra parameters to a
 ;function and sometimes as extra working space within a function
.DEF RAM_TEMP1			$D20E
.DEF RAM_TEMP2			$D20F
.DEF RAM_TEMP3			$D210
.DEF RAM_TEMP4			$D212
.DEF RAM_TEMP5			$D213
.DEF RAM_TEMP6			$D214
.DEF RAM_TEMP7			$D215

;hardware caches:
;--------------------------------------------------------------------------------------

.DEF RAM_VDPREGISTER_0		$D218	;RAM cache of the VDP register 0
.DEF RAM_VDPREGISTER_1		$D219	;RAM cache of the VDP register 1

.DEF RAM_PAGE_1			$D235	;used to keep track of what bank is in page 1
.DEF RAM_PAGE_2			$D236	;used to keep track of what bank is in page 2

.DEF RAM_SCROLL_HORIZONTAL	$D251
.DEF RAM_SCROLL_VERTICAL	$D252

;--------------------------------------------------------------------------------------

.DEF RAM_CURRENT_LEVEL		$D23E

;level dimensions / crop
.DEF RAM_LEVEL_FLOORWIDTH	$D238	;width of level floor layout in blocks
.DEF RAM_LEVEL_FLOORHEIGHT	$D23A	;height of level floor layout in blocks
.DEF RAM_LEVEL_CROPLEFT		$D273
.DEF RAM_LEVEL_OFFSET_X		$D274
.DEF RAM_LEVEL_WIDTH		$D276
.DEF RAM_LEVEL_CROPTOP		$D277
.DEF RAM_LEVEL_OFFSET_Y		$D278
.DEF RAM_LEVEL_EXTENDHEIGHT	$D279
.DEF RAM_LEVEL_HEIGHT		$D27A

.DEF RAM_LEVEL_SOLIDITY		$D2D4

.DEF RAM_RINGS			$D2AA	;player's ring count
.DEF RAM_LIVES			$D246	;player's lives count
.DEF RAM_TIME			$D29F	;the level's time

;`loadPaletteOnInterrupt` and `loadPaletteFromInterrupt` use these to pass parameters
.DEF RAM_LOADPALETTE_ADDRESS	$D22B
.DEF RAM_LOADPALETTE_FLAGS	$D22F

;a copy of the level music index is kept so that the music can be started again (?)
 ;after other sound events like invincibility
.DEF RAM_LEVEL_MUSIC		$D2FC
;the previous song played is checked during level load to avoid re-initialising the
 ;same song (for example, when teleporting in Scrap Brain)
.DEF RAM_PREVIOUS_MUSIC		$D2D2

;the address of where the cycle palette begins
.DEF RAM_CYCLEPALETTE_POINTER	$D2A8
;the current palette in the cycle palette being used
.DEF RAM_CYCLEPALETTE_INDEX	$D2A6

.DEF RAM_RASTERSPLIT_STEP	$D247
.DEF RAM_RASTERSPLIT_LINE	$D248
.DEF RAM_WATERLINE		$D2DB

.DEF RAM_SONIC_CURRENT_FRAME	$D28F
.DEF RAM_SONIC_PREVIOUS_FRAME	$D291

.DEF RAM_RING_CURRENT_FRAME	$D293
.DEF RAM_RING_PREVIOUS_FRAME	$D295

;a pointer to a position within a sprite table, consisting of three bytes each entry:
 ;X-position, Y-position and sprite index number. this is used to set where the next
 ;sprites will be created in the table, e.g. `processSpriteLayout`
.DEF RAM_SPRITETABLE_CURRENT	$D23C

;======================================================================================

.BANK 0

START:
	di				;disable interrupts
	im   1				;set the interrupt mode to 1 --
					 ;$0038 will be called at 50/60Hz 

-	;wait for the scanline to reach 176 (no idea why)
	in   a, (SMS_CURRENT_SCANLINE)
	cp   176
	jr   nz, -
	jp   _init

;______________________________________________________________________________________

;the `rst $18` instruction jumps here
.ORG $0018
	jp   playMusic			;play a song specified by A

;the `rst $20` instruction jumps here
.ORG $0020
	jp   muteSound

;the `rst $28` instruction jumps here
.ORG $0028
	jp   playSFX			;play sound effect specified by A

;the hardware interrupt generator jumps here
.ORG $0038
	jp   IRQHandler

.ORG $003B
.db "Developed By (C) 1991 Ancient - S", $A5, "Hayashi.", $00

;____________________________________________________________________________[$0066]___
;pressing the pause button causes an interrupt and jumps to $0066

.ORG $0066
	di				;disable interrupts
	push af
	;level time HUD / lightning flags
	ld   a, (iy+vars.timeLightningFlags)
	xor  %00001000			;flip bit 3 (the pause bit)
	;save it back
	ld   (iy+vars.timeLightningFlags), a
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
	
	bit  7, (iy+vars.flags6)	;check the underwater flag
	jr   z, +			;if off, skip ahead
	
	;the raster split is controlled across multiple interrupts,
	 ;a counter is used to remember at which step the procedure is at
	 ;a value of 0 means that it needs to be initialised, and then it counts
	 ;down from 3
	
	ld   a, (RAM_RASTERSPLIT_STEP)	;get the current raster split step
	and  a				;doesn't change the number, but updates flags
	jp   nz, doRasterSplit		;if it's not zero, deal with the particulars
	
	;--- initialise raster split --------------------------------------------------
	ld   a, (RAM_WATERLINE)		;check the water line height
	and  a
	jr   z, +			;if it's zero (above the screen), skip
	
	cp   $FF			;or 255 (below the screen),
	jr   z, +			;skip
	
	;copy the water line position into the working space for the raster split.
	 ;this is to avoid the water line changing height between the multiple
	 ;interrupts needed to produce the split, I think
	ld   (RAM_RASTERSPLIT_LINE), a
	
	;set the line interrupt to fire at line 10 (top of the screen),
	 ;we will then set another interrupt to fire where we want the split to occur
	ld   a, 10
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 10
	out  (SMS_VDP_CONTROL), a
	
	;enable line interrupt IRQs (bit 5 of VDP register 0)
	ld   a, (RAM_VDPREGISTER_0)
	or   %00010000
	out  (SMS_VDP_CONTROL), a
	ld   a, $80
	out  (SMS_VDP_CONTROL), a
	
	;initialise the step counter for the water line raster split
	ld   a, 3
	ld   (RAM_RASTERSPLIT_STEP), a
	
	;------------------------------------------------------------------------------
	
+	push ix
	push iy
	
	;remember the current page 1 & 2 banks
	ld   hl, (RAM_PAGE_1)
	push hl
	
	;if the main thread is not held up at the `wait` routine
	bit  0, (iy+vars.flags0)
	call nz, _LABEL_1A0_18
	;and if it is...
	bit  0, (iy+vars.flags0)
	call z, _LABEL_F7_25
	
	;I'm  not sure why the interrupts are re-enabled before we've left the
	 ;interrupt handler, but there you go, it obviously works
	ei
	
	;there's an extra bank of code located at ROM:$C000-$FFFF,
	 ;page this into Z80:$4000-$7FFF
	ld   a, :sound_update
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	call sound_update
	
	call readJoypad
	bit  4, (iy+vars.joypad)	;joypad button A?
	call z, _setJoypadButtonB	;set joypad button B too
	
	call _LABEL_625_57
	
	;check for the reset button
	in   a, (SMS_JOYPAD_2)		;read the second joypad port which has extra
					 ;bits for lightgun / reset button
	and  %00010000			;check bit 4
	jp   z, START			;reset!
	
	;return pages 1 & 2 to the banks before we started messing around here
	pop  hl
	ld   (SMS_PAGE_1), hl
	ld   (RAM_PAGE_1), hl
	
	;pull everything off the stack so that the code that was running
	 ;before the interrupt doesn't explode
	pop  iy
	pop  ix
	pop  bc
	pop  de
	pop  hl
	pop  af
	ret

;----------------------------------------------------------------------------[$00F2]---

_setJoypadButtonB:
	res  5, (iy+vars.joypad)	;set joypad button B as on
	ret

;----------------------------------------------------------------------------[$00F7]---

_LABEL_F7_25:
	;blank the screen (remove bit 6 of VDP register 1)
	ld   a, (RAM_VDPREGISTER_1)	;get our cache value from RAM
	and  %10111111			;remove bit 6
	out  (SMS_VDP_CONTROL), a	;write the value,
	ld   a, $80 + 1			;followed by the register number
	out  (SMS_VDP_CONTROL), a
	
	;horizontal scroll
	ld   a, (RAM_SCROLL_HORIZONTAL)
	neg				;I don't understand the reason for this
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 8			;VDP register 8
	out  (SMS_VDP_CONTROL), a
	
	;vertical scroll
	ld   a, (RAM_SCROLL_VERTICAL)
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 9			;VDP register 9
	out  (SMS_VDP_CONTROL), a
	
	bit  5, (iy+vars.flags0)			
	call nz, fillScrollTiles
	
	bit  5, (iy+vars.flags0)			
	call nz, loadPaletteFromInterrupt
	
	;turn the screen back on 
	 ;(or if it was already blank before this function, leave it blank)
	ld   a, (RAM_VDPREGISTER_1)
	out  (SMS_VDP_CONTROL), a
	ld   a, $80 + 1			;VDP register 1
	out  (SMS_VDP_CONTROL), a
	
	ld   a, 8			;Sonic sprites?
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	ld   a, 9
	ld   (SMS_PAGE_2), a
	ld   (RAM_PAGE_2), a
	
	;does the Sonic sprite need updating?
	 ;(the particular frame of animation is copied to the VRAM)
	bit  7, (iy+vars.timeLightningFlags)
	call nz, updateSonicSpriteFrame
	
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (RAM_PAGE_2), a
	
	;update sprite table?
	bit  1, (iy+vars.flags0)
	call nz, updateVDPSprites
	
	bit  5, (iy+vars.flags0)
	call z, loadPaletteFromInterrupt
	
	ld   a, ($D2AC)
	and  %10000000
	call z, _LABEL_38B0_51
	
	ld   a, $FF
	ld   ($D2AC), a
	
	set  0, (iy+vars.flags0)
	ret
	
;----------------------------------------------------------------------------[$0174]---
;load a palette using the parameters set by `loadPaletteOnInterrupt`

loadPaletteFromInterrupt:
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (RAM_PAGE_2), a
	
	;if the level is underwater then skip loading the palette as the palettes
	 ;are handled by the code that does the raster split
	bit  7, (iy+vars.flags6)	;underwater flag
	jr   nz, +
	
	;get the palette loading parameters that were assigned by the main thread
	 ;(i.e. `loadPaletteOnInterrupt`)
	ld   hl, (RAM_LOADPALETTE_ADDRESS)
	ld   a, (RAM_LOADPALETTE_FLAGS)
	
	bit  3, (iy+vars.flags0)	;check the flag to specify loading the palette
	call nz, loadPalette		;load the palette if flag is set
	res  3, (iy+vars.flags0)	;unset the flag so it doesn't happen again
	ret
	
	;when the level is underwater, different logic controls loading the palette
	 ;as we have to deal with the water line
+	call _LABEL_1BA_40
	ret

;----------------------------------------------------------------------------[$01A0]---

_LABEL_1A0_18:
	bit  7, (iy+vars.flags6)	;check the underwater flag
	ret  z				;if off, leave now
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (RAM_PAGE_2), a
	
	;this seems quite pointless but could do with
	 ;killing a specific amount of time
	ld   b, $00
-	nop
	djnz -

;----------------------------------------------------------------------------[$01BA]---
	
_LABEL_1BA_40:
	ld   a, (RAM_WATERLINE)		;get the position of the water line on screen
	and  a
	jr   z, ++			;is it 0? (above the screen)
	cp   $FF			;or $FF? (below the screen)
	jr   nz, ++			;...skip ahead
	
	;--- below water --------------------------------------------------------------
	;below the water line a fixed palette is used without cycles
	
	;select the palette:
	 ;labyrinth Act 1 & 2 share an underwater palette and Labyrinth Act 3
	 ;uses a special palette to account for the boss / capsule, who normally
	 ;load their palettes on-demand
	ld   hl, S1_UnderwaterPalette
	;underwater boss palette?
	bit  4, (iy+vars.timeLightningFlags)
	jr   z, +			
	ld   hl, S1_UnderwaterPalette_Boss
	
+	ld   a, %00000011		;"load tile & sprite palettes"
	call loadPalette		;load the relevant underwater palette
	ret
	
	;--- above water --------------------------------------------------------------
++	ld   a, (RAM_CYCLEPALETTE_INDEX)
	add  a, a			;x2
	add  a, a			;x4
	add  a, a			;x8
	add  a, a			;x16
	ld   e, a
	ld   d, $00
	ld   hl, (RAM_CYCLEPALETTE_POINTER)
	add  hl, de
	ld   a, %00000001
	call loadPalette
	
	;load the sprite palette specifically for Labyrinth
	ld   hl, S1_Palette_Labyrinth_Sprites
	ld   a, %00000010
	call loadPalette
	
	ret

;----------------------------------------------------------------------------[$01F2]---
	
doRasterSplit:
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
	ld   (RAM_RASTERSPLIT_STEP), a
	
	in   a, (SMS_CURRENT_SCANLINE)	;get the current scanline
	ld   c, a
	ld   a, (RAM_RASTERSPLIT_LINE)	;get the water line height on the screen
	sub  c				;work out the difference
	
	;set VDP register 10 with the scanline number to interrupt at next
	 ;(that is, set the next interrupt to occur at the water line)
	out  (SMS_VDP_CONTROL), a
	ld   a, %10000000 + 10
	out  (SMS_VDP_CONTROL), a
	
	jp   +++
	
	;--- step 2 -------------------------------------------------------------------
+	;we don't do anything on this step
	dec  a
	ld   (RAM_RASTERSPLIT_STEP), a
	jp   +++
	
	;--- step 1 -------------------------------------------------------------------
++	dec  a
	ld   (RAM_RASTERSPLIT_STEP), a
	
	;set the VDP to point at the palette
	ld   a, $00
	out  (SMS_VDP_CONTROL), a
	ld   a, %11000000
	out  (SMS_VDP_CONTROL), a
	
	ld   b, $10
	ld   hl, S1_UnderwaterPalette
	
	;underwater boss palette?
	bit  4, (iy+vars.timeLightningFlags)
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
	
	ld   a, (RAM_VDPREGISTER_0)
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
	ld   de, RAM_VDPREGISTER_0	;to $D218 in the RAM
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
	
	call muteSound
	
	;initialise variables?
	ld   iy, $D200			;variable space starts here
	jp   _LABEL_1C49_62

;____________________________________________________________________________[$02D7]___
;the `rst $18` instruction ends up here

playMusic:
;A : index number of song to play (see `S1_MusicPointers` in "includes\music.asm")
	di				;disable interrupts
	push af
	
	;switch page 1 (Z80:$4000-$7FFF) to bank 3 ($C000-$FFFF)
	ld   a, :sound_playMusic
	ld   (SMS_PAGE_1), a
	
	pop  af
	ld   (RAM_PREVIOUS_MUSIC), a
	call sound_playMusic
	
	ld   a, (RAM_PAGE_1)
	ld   (SMS_PAGE_1), a
	
	ei				;enable interrupts
	ret

;____________________________________________________________________________[$02ED]___
;the `rst $20` instruction ends up here

muteSound:
	di				;disable interrupts
	
	;switch page 1 (Z80:$4000-$7FFF) to bank 3 (ROM:$0C000-$0FFFF)
	ld   a, :sound_stop
	ld   (SMS_PAGE_1), a
	call sound_stop
	ld   a, (RAM_PAGE_1)
	ld   (SMS_PAGE_1), a
	
	ei				;enable interrupts
	ret

;____________________________________________________________________________[$02FE]___
;the `rst $28` instruction ends up here

playSFX:
	di      
	push    af
	
	ld      a,:sound_playSFX
	ld      (SMS_PAGE_1),a
	pop     af
	call    sound_playSFX
	ld      a,(RAM_PAGE_1)
	ld      (SMS_PAGE_1),a
	
	ei      
	ret  

;____________________________________________________________________________[$031B]___

_InitVDPRegisterValues:							;	cache:
.db %00100110   ;VDP Register 0:						$D218
    ;......x.    stretch screen (33 columns)
    ;.....x..    unknown
    ;..x.....    hide left column (for scrolling)
.db %10100010	;VDP Register 1:						$D219
    ;......x.    enable 8x16 sprites
    ;..x.....    enable vsync IRQ
    ;.x......	 disable screen (no display)				;these caches
    ;x.......    unknown						;are not used
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
	bit  0, (iy+vars.flags0)
	;if bit 0 is off, then wait!
	jr   z, wait
	ret

;___ UNUSED! ________________________________________________________________[$0323]___

_323:
	set     2,(iy+vars.flags0)
	ld      ($d225),hl		;unused RAM location
	ld      ($d227),de		;unused RAM location
	ld      ($d229),bc		;unused RAM location
	ret

;____________________________________________________________________________[$0333]___

loadPaletteOnInterrupt:
	set  3, (iy+vars.flags0)	;set the flag for the interrupt handler
	;store the parameters
	ld   (RAM_LOADPALETTE_FLAGS), a
	ld   (RAM_LOADPALETTE_ADDRESS), hl
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
	
	ld   b, (iy+vars.spriteCount)
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
	ld   a, (iy+vars.spriteCount)
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
	ld   b, (iy+vars.spriteCount)
	
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
	
	ld   a, (iy+vars.spriteCount)
	ld   ($D2B4), a
	ld   (iy+vars.spriteCount), b
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
	ld      de,(RAM_PAGE_1)		;remember the current page 1 & 2 banks
	push    de
	
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	inc     a
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ei      

---	ld      a,(hl)
	cpl     
	ld      e,a

--	ld      a,(hl)
	cp      e
	jr      z,+
	out     (SMS_VDP_DATA),a
	ld      e,a
	inc     hl
	dec     bc
	ld      a,b
	or      c
	jp      nz,--
	jr      ++

+	ld      d,a
	inc     hl
	dec     bc
	ld      a,b
	or      c
	jr      z,++
	ld      a,d
	ld      e,(hl)
-:
	out     (SMS_VDP_DATA),a
	dec     e
	nop     
	nop     
	jp      nz,-
	inc     hl
	dec     bc
	ld      a,b
	or      c
	jp      nz,---

++	di      
	;restore bank numbers
	pop     de
	ld      (RAM_PAGE_1),de
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
	ld   de, (RAM_PAGE_1)
	push de
	
	;change pages 1 & 2 (Z80:$4000-$BFFF) to banks A & A+1
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	inc  a
	ld   (SMS_PAGE_2), a
	ld   (RAM_PAGE_2), a
	
	;--- read header --------------------------------------------------------------
	
	bit  1, (iy+vars.flags9)
	jr   nz, +
	ei
	
+	ld   (RAM_TEMP4), hl
	
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
	
	ld   (RAM_TEMP3), bc		;store the row count in $D210
	ld   (RAM_TEMP6), hl		;where the UniqueRows list begins
	
	;swap BC/DE/HL with their shadow values
	exx
	
	;load BC with the absolute starting address of the art header;
	 ;the DuplicateRows and ArtData values are always relative to this
	ld   bc, (RAM_TEMP4)
	;copy it to DE
	ld   e, c
	ld   d, b
	
	pop  hl				;pull the ArtData value from the stack
	add  hl, bc			;get the absolute address of ArtData
	ld   (RAM_TEMP1), hl		;and store that in $D20E
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
	ld   hl, (RAM_TEMP3)		;load HL with the original row count number
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
	
	ld   hl, (RAM_TEMP6)		;the absolute address where the UniqueRows
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
	jp   ++				;otherwise, skip to finalisation

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
	
	ld   de, (RAM_TEMP1)		;get the absolute address to the art data
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

++	bit  1, (iy+vars.flags9)
	jr   nz, +
	di
+	;restore the pages to the original banks at the beginning of the procedure
	pop  de
	ld   (RAM_PAGE_1), de
	ld   (SMS_PAGE_1), de
	
	ei
	res  1, (iy+vars.flags9)
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
;HL : absolute address to the start of the compressed screen data
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
	
---	;the current byte is stored in E to be able to check when two bytes in a row
	 ;occur (the marker for a compressed byte). it's actually stored inverted
	 ;so that the first data byte doesn't trigger an immediate repeat
	
	ld   a, (hl)			;read the current byte from the screen data
	cpl				;invert the bits ("NOT")
	ld   e, a			;move this to E
	
--	ld   a, (hl)			;read the current byte from the screen data
	cp   e				;is this equal to the previous byte?
	jr   z, +			;if yes, decompress the byte
	
	cp   $FF			;is this tile $FF?
	jr   z, _decompressScreen_skip		
	
	;--- uncompressed byte --------------------------------------------------------
	out  (SMS_VDP_DATA), a		;send the tile to the VDP
	ld   e, a			;update the "current byte" being compared
	ld   a, (RAM_TEMP1)		;get the upper byte to use for the tiles
					 ;(foreground / background / flip)
	out  (SMS_VDP_DATA), a
	
	inc  hl				;move to the next byte
	dec  bc				;decrease the remaining bytes to read
	ld   a, b			;check if remaining bytes is zero
	or   c
	jp   nz, --			;if remaining bytes, loop
	jr   ++				;otherwise end
	
	;--- decompress byte ----------------------------------------------------------
+	ld   d, a			;put the current data byte into D
	inc  hl				;move to the next byte
	dec  bc				;decrease the remaining bytes to read
	ld   a, b			;check if remaining bytes is zero
	or   c
	jr   z, ++			;if no bytes left, finish
					 ;(couldn't I just put `ret z` here?)
	
	ld   a, d			;return the data byte back to A
	ld   e, (hl)			;get the number of times to repeat the byte
	cp   $FF			;is a skip being repeated?
	jr   z, _decompressScreen_multiSkip
	
	;repeat the byte
-	out  (SMS_VDP_DATA), a
	push af
	ld   a, (RAM_TEMP1)
	out  (SMS_VDP_DATA), a
	pop  af
	dec  e
	jp   nz, -
	
-	;move to the next byte in the data
	inc  hl
	dec  bc
	
	;any remaining bytes?
	ld   a, b
	or   c
	jp   nz, ---			;if yes start checking duplicate bytes again
	
	;all bytes processed - we're done!
++	ret
	
_decompressScreen_skip:
	ld   e, a
	in   a, (SMS_VDP_DATA)
	nop
	inc  hl
	dec  bc
	in   a, (SMS_VDP_DATA)
	
	ld   a, b
	or   c
	jp   nz, --
	
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
	jp   -

;____________________________________________________________________________[$0566]___

loadPalette:
;A  : which palette(s) to set
    ;  bit 0 - tile palette (0-15)
    ;  bit 1 - sprite palette (16-31)
;HL : address of palette
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
	ld   (iy+vars.joypad), a	;store the joypad value in $D203
	ret

;____________________________________________________________________________[$05AF]___

print:
;HL : address to memory with column and row numbers, then data terminated with $FF
	
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
	ld   a, (RAM_TEMP1)		;what to use as the tile upper bits
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
	;set the first two bytes as #$E0 (X&Y position)
	ld   a, $E0
	ld   (de), a
	inc  de
	ld   (de), a
	;then move forward another two bytes (skips the sprite index number)
	inc  de
	inc  de
	;copy 189 bytes from $D000 to $D003+ (up to $D0C0)
	ldir
	
	;set parameters so that at the next interrupt,
	 ;all sprites will be hidden (see `updateVDPSprites`)
	ld   (iy+vars.spriteCount), 64
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
;convert to decimal? (used by Map and Act Complete screens for the lives number)

_LABEL_60F_111:
; C : 10
;HL : Number of lives
	xor  a				;set A to 0
	ld   b, 16
	
	;16-bit left-rotation -- that is, multiply by 2
-	rl   l
	rl   h
	rla				;if it goes above $FFFF, overflow into A
	
	cp   c				;check the overflow portion against C
	jp   c, +			;if less than 10, skip ahead
	sub  c				;-10
	
	;invert the carry flag. for values of A of 0-9, the carry will become 0,
	 ;when A hits 10, the carry will become 1 and adds 1 to DE
+	ccf
	
	;multiply DE by 2
	rl   e
	rl   d
	
	djnz -
	
	;swap DE and HL:
	 ;HL will be the number of 10s (in two's compliment?)
	ex   de, hl
	ret

;____________________________________________________________________________[$0625]___
;random number generator?

_LABEL_625_57:
	push hl
	push de
	
	ld   hl, ($D2D7)
	ld   e, l
	ld   d, h
	add  hl, de			;x2
	add  hl, de			;x4
	
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

;____________________________________________________________________________[$063E]___

_063e:
	ld      bc,(RAM_SCROLL_HORIZONTAL)
	ld      hl,($d25a)
	ld      de,($d26f)
	and     a
	sbc     hl,de
	jr      c,+
	ld      a,l
	add     a,c
	ld      c,a
	res     6,(iy+vars.flags0)
	jp      ++
	
+	ld      a,l
	add     a,c
	ld      c,a
	set     6,(iy+vars.flags0)
	
++	ld      hl,($d25d)
	ld      de,($d271)
	and     a
	sbc     hl,de
	jr      c,++
	ld      a,l
	add     a,b
	cp      $e0
	jr      c,+
	add     a,$20
+	ld      b,a
	res     7,(iy+vars.flags0)
	jp      +++

++	ld      a,l
	add     a,b
	cp      $e0
	jr      c,+
	sub     $20
+	ld      b,a
	set     7,(iy+vars.flags0)

+++	ld      (RAM_SCROLL_HORIZONTAL),bc
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

;____________________________________________________________________________[$06BD]___

_06bd:
	bit     5,(iy+vars.flags0)
	ret     z
	
	di      
	;switch pages 1 & 2 ($4000-$BFFF) to banks 4 & 5 ($10000-$17FFF)
	ld      a,4
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,5
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ei      
	
	ld      a,(RAM_LEVEL_SOLIDITY)	;get the solidity index for the level
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
	ld      (RAM_TEMP3),hl
	bit     0,(iy+vars.flags2)
	jp      z,+++
	
	bit     6,(iy+vars.flags0)
	jr      nz,+
	
	ld      b,$00
	ld      c,$08
	jp      ++

+	ld      a,(RAM_SCROLL_HORIZONTAL)
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

++	call    _08d5
	ld      a,(RAM_SCROLL_HORIZONTAL)
	bit     6,(iy+vars.flags0)
	jr      z,+
	add     a,$08
+	and     %00011111
	srl     a
	srl     a
	srl     a
	ld      c,a
	ld      b,$00
	ld      (RAM_TEMP1),bc
	exx     
	ld      de,$d180
	exx     
	ld      de,(RAM_LEVEL_FLOORWIDTH)
	ld      b,$07
-	ld      a,(hl)
	exx     
	ld      c,a
	ld      b,$00
	ld      hl,(RAM_TEMP3)
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
	ld      hl,(RAM_TEMP1)
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
	
+++	bit     1,(iy+vars.flags2)
	jp      z,+++
	bit     7,(iy+vars.flags0)
	jr      nz,+
	ld      b,$06
	ld      c,$00
	jp      ++
	
+	ld      b,$00
	ld      c,b
	
++	call    _08d5
	ld      a,(RAM_SCROLL_VERTICAL)
	and     $1f
	srl     a
	and     $fc
	ld      c,a
	ld      b,$00
	ld      (RAM_TEMP1),bc
	exx     
	ld      de,$d100
	exx     
	ld      b,$09

-	ld      a,(hl)
	exx     
	ld      c,a
	ld      b,$00
	ld      hl,(RAM_TEMP3)
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
	ld      hl,(RAM_TEMP1)
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
	djnz    -

+++	ret

;____________________________________________________________________________[$07DB]___
;fill in new tiles when the screen has scrolled

fillScrollTiles:
	bit  0, (iy+vars.flags2)
	jp   z, ++
	
	exx
	push hl
	push de
	push bc
	
	;------------------------------------------------------------------------------
	;calculate the number of bytes to offset by to get to the correct row in the
	 ;screen table
	
	ld   a, (RAM_SCROLL_VERTICAL)
	and  %11111000			;round the scroll to the nearest 8 pixels
	
	;multiply the vertical scroll offset by 8. since the scroll offset is already
	 ;a multiple of 8, this will give you 64 bytes per screen row (32 16-bit tiles)
	ld   b, $00
	add  a, a			;x2
	rl   b
	add  a, a			;x4
	rl   b
	add  a, a			;x8
	rl   b
	ld   c, a
	
	;------------------------------------------------------------------------------
	;calculate the number of bytes to get from the beginning of a row to the 
	 ;horizontal scroll position
	
	ld   a, (RAM_SCROLL_HORIZONTAL)
	
	bit  6, (iy+vars.flags0)
	jr   z, +
	add  a, 8			;add 8 pixels (left screen border?)
+	and  %11111000			;and then round to the nearest 8 pixels
	
	srl  a				;divide by 2 ...
	srl  a				;divide by 4
	add  a, c
	ld   c, a
	
	ld   hl, $3800			;beginning of the screen table
	add  hl, bc			;offset to the top of the column needed
	set  6, h			;add bit 6 to label as a VDP VRAM address
	
	ld   bc, 64			;there are 32 tiles (16-bit) per screen-width
	ld   d, $3F|%01000000		;upper limit of the screen table
					 ;(bit 6 is set as it is a VDP VRAM address)
	ld   e, 7
	
	;------------------------------------------------------------------------------
	exx
	ld   hl, $D180
	
	;find where in a block the scroll offset sits (this is needed to find which
	 ;of the 4 tiles width in a block have to be referenced)
	ld   a, (RAM_SCROLL_VERTICAL)
	and  %00011111			;MOD 32
	srl  a				;divide by 2 ...
	srl  a				;divide by 4 ...
	srl  a				;divide by 8
	ld   c, a			;load this into BC
	ld   b, $00
	add  hl, bc			;add twice to HL
	add  hl, bc
	ld   b, $32			;set BC to $BE32
	ld   c, $BE
	
	;set the VDP address calculated earlier
-	exx
	ld   a, l
	out  (SMS_VDP_CONTROL), a
	ld   a, h
	out  (SMS_VDP_CONTROL), a
	
	;move to the next row
	add  hl, bc
	ld   a, h
	cp   d				;don't go outside the screen table
	jp   nc, +++
	
--	exx
	outi				;send the tile index
	outi				;send the tile meta
	jp   nz, -
	
	exx
	pop  bc
	pop  de
	pop  hl
	exx
	
	;------------------------------------------------------------------------------
++	bit  1, (iy+vars.flags2)
	jp   z, ++			;could  optimise to `ret z`?
	ld   a, (RAM_SCROLL_VERTICAL)
	ld   b, $00
	srl  a
	srl  a
	srl  a
	bit  7, (iy+vars.flags0)
	jr   nz, +
	add  a, $18
+	cp   $1C
	jr   c, +
	sub  $1C
+	add  a, a
	add  a, a
	add  a, a
	add  a, a
	rl   b
	add  a, a
	rl   b
	add  a, a
	rl   b
	ld   c, a
	ld   a, (RAM_SCROLL_HORIZONTAL)
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
	ld   a, (RAM_SCROLL_HORIZONTAL)
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
	ld   (RAM_TEMP1), a
	ld   a, e
	out  (SMS_VDP_CONTROL), a
	and  $3F
	ld   e, a
	ld   a, d
	out  (SMS_VDP_CONTROL), a
	ld   b, $3E
	ld   c, $BE

-	bit  6, e
	jr   nz, +
	inc  e
	inc  e
	outi
	outi
	jp   nz, -
	ret

+	ld   a, (RAM_TEMP1)
	out  (SMS_VDP_CONTROL), a
	ld   a, d
	out  (SMS_VDP_CONTROL), a
	
-	outi
	outi
	jp   nz, -

++	ret

	;------------------------------------------------------------------------------
+++	sub  e
	ld   h, a
	jp   --

;____________________________________________________________________________[$08D5]___
;something to do with block mappings?

_08d5:
;BC : Address of Block Mappings?
	ld      a,(RAM_LEVEL_FLOORWIDTH);width of the level in blocks
	rlca    			;double it (x2)
	jr      c,+			;<128?
	rlca    			;double it again (x4)
	jr      c,++			;<64?
	rlca    			;double it again (x8)
	jr      c,+++			;<32?
	rlca    			;double it again (x16)
	jr      c,++++			;<16?
	jp      +++++			;...?
	
+	ld      a,($d258)
	add     a,b
	ld      e,$00
	srl     a			;divide by 2
	rr      e
	ld      d,a
	ld      a,($d257)
	add     a,c
	add     a,e
	ld      e,a
	ld      hl,$c000
	add     hl,de
	ret

++	ld      a,($d258)
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

+++	ld      a,($d258)
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

++++	ld      a,($d258)
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

+++++	ld      a,($d258)
	add     a,b
	ld      d,a
	ld      a,($d257)
	add     a,c
	ld      e,a
	ld      hl,$c000
	add     hl,de
	ret

;____________________________________________________________________________[$0966]___
;draw a block on screen?

_0966:
	;page in banks 4 & 5 (containing the block mappings)
	di      			;disable interrupts
	ld      a,:S1_BlockMappings
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,:S1_BlockMappings + 1
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	
	ld      bc,$0000		;$10000
	call    _08d5
	
	ld      de,$3800
	ld      b,$06
	
---	push    bc
	push    hl
	push    de
	ld      b,$08

--	push    bc
	push    hl
	push    de
	
	;look up solidity value?
	ld      a,(hl)
	exx     
	ld      e,a
	ld      a,(RAM_LEVEL_SOLIDITY)
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

-	ld      a,l
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
	djnz    -
	
	pop     de
	pop     hl
	inc     hl
	ld      bc,$0008
	ex      de,hl
	add     hl,bc
	ex      de,hl
	pop     bc
	djnz    --
	
	pop     de
	pop     hl
	ld      bc,(RAM_LEVEL_FLOORWIDTH)
	add     hl,bc
	ex      de,hl
	ld      bc,$0100
	add     hl,bc
	ex      de,hl
	pop     bc
	dec     b
	jp      nz,---
	
	ei      
	ret

;____________________________________________________________________________[$0A10]___

loadFloorLayout:
;HL : address of Floor Layout data
;BC : length of compressed data
	ld      de,$C000		;where in RAM the floor layout will go

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
	ret				;otherwise, finish
	
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

;____________________________________________________________________________[$0A40]___
	
_LABEL_A40_121:
	ld   a, 1
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	ld   a, 2
	ld   (SMS_PAGE_2), a
	ld   (RAM_PAGE_2), a
	
	ld   a, (iy+vars.spriteCount)
	res  0, (iy+vars.flags0)
	call wait
	
	ld   (iy+vars.spriteCount), a
	ld   b, $04
	
--	push bc
	ld   hl, ($D230)
	ld   de, $D3BC
	ld   b, $10
	call _a90
	ld   hl, ($D232)
	ld   b, $10
	call _a90
	ld   hl, $D3BC
	ld   a, $03
	call loadPaletteOnInterrupt
	ld   b, $0A

-	ld   a, (iy+vars.spriteCount)
	res  0, (iy+vars.flags0)
	call wait
	ld   (iy+vars.spriteCount), a
	djnz -
	
	pop  bc
	djnz --
	
	ret

;----------------------------------------------------------------------------[$0A90]---

_a90:
	ld   a, (hl)
	and  $03
	jr   z, +
	dec  a
+	ld   c, a
	ld   a, (hl)
	and  $0C
	jr   z, +
	sub  $04
+	or   c
	ld   c, a
	ld   a, (hl)
	and  $30
	jr   z, +
	sub  $10
+	or   c
	ld   (de), a
	inc  hl
	inc  de
	djnz _a90
	
	ret

;____________________________________________________________________________[$0AAE]___

_aae:
	ld      (RAM_TEMP6),hl
	ld      hl,($d230)
	ld      de,$d3bc
	ld      bc,$0020
	ldir    
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ld      hl,$d3bc
	ld      a,$03
	call    loadPaletteOnInterrupt
	ld      c,(iy+vars.spriteCount)
	ld      a,(RAM_VDPREGISTER_1)
	or      $40
	ld      (RAM_VDPREGISTER_1),a
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),c
	ld      b,$09
	
-	ld      a,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),a
	djnz    -
	ld      b,$04

--	push    bc
	ld      hl,(RAM_TEMP6)
	ld      de,$d3bc
	ld      b,$20

-	push    bc
	ld      a,(hl)
	and     $03
	ld      b,a
	ld      a,(de)
	and     $03
	cp      b
	jr      z,+
	dec     a
+	ld      c,a
	ld      a,(hl)
	and     $0c
	ld      b,a
	ld      a,(de)
	and     $0c
	cp      b
	jr      z,+
	sub     $04
+	or      c
	ld      c,a
	ld      a,(hl)
	and     $30
	ld      b,a
	ld      a,(de)
	and     $30
	cp      b
	jr      z,+
	sub     $10
+	or      c
	ld      (de),a
	inc     hl
	inc     de
	pop     bc
	djnz    -
	ld      hl,$d3bc
	ld      a,$03
	call loadPaletteOnInterrupt
	ld      b,$0a

-	ld      a,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),a
	djnz    -
	
	pop     bc
	djnz    --
	ret

;____________________________________________________________________________[$0B50]___

_b50:
	ld      (RAM_TEMP6),hl
	ld      hl,$d3bc
	ld      b,$20
	
-	ld      (hl),$00
	inc     hl
	djnz    -
	jp      +

;----------------------------------------------------------------------------[$0B60]---

_b60:
	ld      (RAM_TEMP6),hl
	ld      hl,($d230)
	ld      de,$d3bc
	ld      bc,$0020
	ldir    
	
+	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ld      hl,$d3bc
	ld      a,$03
	call loadPaletteOnInterrupt
	ld      c,(iy+vars.spriteCount)
	ld      a,(RAM_VDPREGISTER_1)
	or      $40
	ld      (RAM_VDPREGISTER_1),a
	res     0,(iy+vars.flags0)
	call wait
	ld      (iy+vars.spriteCount),c
	ld      b,$09
	
-	ld      a,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call wait
	ld      (iy+vars.spriteCount),a
	djnz -
	
	ld      b,$04
	
--	push    bc
	ld      hl,(RAM_TEMP6)
	ld      de,$d3bc
	ld      b,$20
	
-	push    bc
	ld      a,(hl)
	and     $03
	ld      b,a
	ld      a,(de)
	and     $03
	cp      b
	jr      nc,+
	inc     a
	
+	ld      c,a
	ld      a,(hl)
	and     $0c
	ld      b,a
	ld      a,(de)
	and     $0c
	cp      b
	jr      nc,+
	add     a,$04
	
+	or      c
	ld      c,a
	ld      a,(hl)
	and     $30
	ld      b,a
	ld      a,(de)
	and     $30
	cp      b
	jr      nc,+
	add     a,$10
	
+	or      c
	ld      (de),a
	inc     hl
	inc     de
	pop     bc
	djnz    -
	
	ld      hl,$d3bc
	ld      a,%00000011
	call loadPaletteOnInterrupt
	
	ld      b,10
-	ld      a,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call wait
	ld      (iy+vars.spriteCount),a
	djnz    -
	
	pop     bc
	djnz    --
	ret

;____________________________________________________________________________[$0C02]___
;each level has a bit flag beginning at HL

getLevelBitFlag:
;HL : an address to a series of 19 bits, one for each level
    ; $D305+: set by life monitor
    ; $D30B+: set by emerald
    ; $D311+: set by continue monitor
    ; $D317+: set by switch
	ld   a, (RAM_CURRENT_LEVEL)
	ld   c, a
	srl  a				;divide by 2 ...
	srl  a				;divide by 4 ...
	srl  a				;divide by 8
	
	;put the result into DE
	ld   e, a
	ld   d, $00
	;add that to the parameter (e.g. $D311)
	add  hl, de
	
	ld   a, c			;return to the current level number
	ld   c, 1
	and  %00000111			;MOD 8
	ret  z				;if level 0, 8, 16, ... then return C = 1
	ld   b, a			;B = 1-7
	ld   a, c			;1
	
	;slide the bit up the byte between 0-7 depending on the level number
-	rlca
	djnz -
	ld   c, a			;return via C
	
	;HL : address to the byte where the bit exists
	; C : the bit mask, e.g. 1, 2, 4, 8, 16, 32, 64 or 128
	ret

;____________________________________________________________________________[$0C1D]___
;copy power-up icon into sprite RAM

_c1d:
;HL : absolute address to uncompressed art data for the icons, assuming that slot 1
 ;    ($4000-$7FFF) is loaded with bank 5 ($14000-$17FFF)

	di      
	ld      a,5			;temporarily switch to bank 5 for the function
	ld      (SMS_PAGE_1),a
	
	ld      a,($d223)
	and     %00001111
	add     a,a			;x2
	add     a,a			;x4
	add     a,a			;x8
	ld      e,a			;put it into DE
	ld      d,$00
	add     hl,de			;offset into HL parameter
	
	ex      de,hl
	ld      bc,$2B80
	
	add     hl,bc
	ld      a,l
	out     (SMS_VDP_CONTROL),a
	ld      a,h
	or      %01000000
	out     (SMS_VDP_CONTROL),a
	
	ld      b,4
-	ld      a,(de)
	out     (SMS_VDP_DATA),a
	nop     
	nop     
	inc     de
	ld      a,(de)
	out     (SMS_VDP_DATA),a
	inc     de
	djnz    -
	
	;return to the previous bank number
	ld      a,(RAM_PAGE_1)
	ld      (SMS_PAGE_1),a
	ei      
	ret

;____________________________________________________________________________[$0C52]___
;map screen

_LABEL_C52_106:
	;reset horizontal / vertical scroll
	xor  a				;set A to 0
	ld   (RAM_SCROLL_HORIZONTAL), a
	ld   (RAM_SCROLL_VERTICAL), a
	
	ld   a, $FF
	ld   ($D216), a
	ld   c, $01
	ld   a, (RAM_CURRENT_LEVEL)
	cp   18
	ret  nc
	cp   9
	jr   c, +
	ld   c, $02
+	ld   a, ($D216)
	cp   c
	jp   z, +++
	ld   a, c
	ld   ($D216), a
	dec  a
	jr   nz, +
	ld   a, (RAM_VDPREGISTER_1)
	and  %10111111
	ld   (RAM_VDPREGISTER_1), a
	res  0, (iy+vars.flags0)
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
	ld      (RAM_PAGE_1),a
	
	;map 1 background
	ld      hl,$627e
	ld      bc,$0178
	ld      de,$3800
	ld      a,$10
	ld      (RAM_TEMP1),a
	call decompressScreen
	
	;map 1 foreground
	ld      hl,$63f6
	ld      bc,$0145
	ld      de,$3800
	ld      a,$00
	ld      (RAM_TEMP1),a
	call decompressScreen
	
	ld      hl,S1_MapScreen1_Palette
	call    _b50
	jr      ++
	
+	;turn the screen off
	ld   a, (RAM_VDPREGISTER_1)
	and  %10111111			;remove bit 6 of VDP register 1
	ld   (RAM_VDPREGISTER_1), a
	
	res  0, (iy+vars.flags0)
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
	ld      (RAM_PAGE_1),a
	
	;map screen 2 background
	ld      hl,$653b
	ld      bc,$0170
	ld      de,$3800
	ld      a,$10
	ld      (RAM_TEMP1),a
	call    decompressScreen
	
	;map screen 2 foreground
	ld      hl,$66ab
	ld      bc,$0153
	ld      de,$3800
	ld      a,$00
	ld      (RAM_TEMP1),a
	call    decompressScreen
	
	ld      hl,S1_MapScreen2_Palette
	call    _b50

	;play the map screen music
++	ld      a,index_music_mapScreen
	rst     $18			;`playMusic`
	
+++	call _LABEL_E86_110
	ld   a, (RAM_CURRENT_LEVEL)
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
	ld   (RAM_TEMP1), a
	call print
	
	ld   a, (RAM_CURRENT_LEVEL)
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
	ld   (RAM_TEMP3), de
	ld   a, (hl)
	and  a
	jr   z, _f
	
	dec  a
	add  a, a
	ld   e, a
	ld   d, $00
	ld   hl, _1201
	add  hl, de
	ld   a, (hl)
	inc  hl
	ld   h, (hl)
	ld   l, a
	jp   (hl)

__	ld   a, $01
	ld      (RAM_TEMP1),a
	ld      bc,$012c

--	push    bc
	call    _LABEL_E86_110
	ld      a,(RAM_TEMP1)
	dec     a
	ld      (RAM_TEMP1),a
	jr      nz,++
	ld      hl,(RAM_TEMP3)
-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	ld      (RAM_TEMP6),bc
	ld      a,(hl)
	inc     hl
	and     a
	jr      nz,+
	ex      de,hl
	jp      -
	
+	ld      (RAM_TEMP1),a
	ld      (RAM_TEMP3),hl
	ld      (RAM_TEMP4),de
	
++	ld      hl,(RAM_TEMP6)
	push    hl
	ld      e,h
	ld      h,$00
	ld      d,h
	ld      bc,(RAM_TEMP4)
	call    processSpriteLayout
	pop     hl
	ld      (RAM_TEMP6),hl
	pop     bc
	dec     bc
	ld      a,b
	or      c
	ret     z
	
	bit     5,(iy+vars.joypad)
	jp      nz,--
	ret     nz
	scf     
	ret

;____________________________________________________________________________[$0DD9]___
;referenced by table at $1201

_0dd9:
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	ld      hl,$00dc
	ld      de,$003c
	ld      b,$00
	
-	call    _LABEL_E86_110
	ld      a,(iy+vars.joypad)
	cp      $ff
	jp      nz,_b
	push    bc
	ld      bc,_0e72
	call    _0edd
	pop     bc
	dec     hl
	djnz    -
	
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	ld      hl,$ffd8
	ld      de,$0058
	ld      b,$80
	
-	call    _LABEL_E86_110
	ld      a,(iy+vars.joypad)
	cp      $ff
	jp      nz,_b
	push    bc
	ld      bc,_0e7a
	call    _0edd
	pop     bc
	inc     hl
	djnz    -
	
	jp      _b

;____________________________________________________________________________[$0E24]___
;referenced by table at $1201

_0e24:
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	ld      hl,$0080
	ld      de,$00c0
	ld      b,$78
	
-	call    _LABEL_E86_110
	ld      a,(iy+vars.joypad)
	cp      $ff
	jp      nz,_b
	push    bc
	ld      bc,_0e82
	call    _0edd
	pop     bc
	dec     de
	djnz    -
	
	jp      _b

;____________________________________________________________________________[$0E4B]___
;referenced by table at $1201

_0e4b:
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	ld      hl,$0078
	ld      de,$0000
	ld      b,$30
	
-	call    _LABEL_E86_110
	ld      a,(iy+vars.joypad)
	cp      $ff
	jp      nz,_b
	push    bc
	ld      bc,_0e82
	call    _0edd
	pop     bc
	inc     de
	djnz    -
	jp      _b

_0e72:	
.db <_1129, >_1129, $04, $01
.db <_113b, >_113b, $04, $00
_0e7a:
.db <_114d, >_114d, $04, $01
.db <_115f, >_115f, $04, $00
_0e82:
.db <_1183, >_1183, $04, $00

;____________________________________________________________________________[$0E86]___

_LABEL_E86_110:
	push hl
	push de
	push bc
	
	ld   hl, (RAM_TEMP1)
	push hl
	
	res  0, (iy+vars.flags0)
	call wait
	
	ld   (iy+vars.spriteCount), $00
	ld   a, (RAM_LIVES)
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
	
	ld   a, (RAM_LIVES)
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
	
	ld   (RAM_SPRITETABLE_CURRENT), hl
	pop  hl
	ld   (RAM_TEMP1), hl
	
	pop  bc
	pop  de
	pop  hl
	ret

;____________________________________________________________________________[$0EDD]___

_0edd:
;BC : address
	
	push    hl
	push    de
	
	;copy BC to HL
	ld      l,c
	ld      h,b
	
	ld      a,(RAM_TEMP2)
	add     a,a			;x2
	add     a,a			;x4
	ld      e,a
	ld      d,$00
	add     hl,de
	
	;read the address of a sprite layout from the list
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	
	ld      a,(RAM_TEMP1)
	cp      (hl)
	jr      c,+
	
	inc     hl
	ld      a,(hl)
	ld      (RAM_TEMP2),a
	xor     a
	ld      (RAM_TEMP1),a
	
+	pop     de			;Y-position
	pop     hl			;X-position
	push    hl
	push    de
	call    processSpriteLayout
	
	ld      a,(RAM_TEMP1)
	inc     a
	ld      (RAM_TEMP1),a
	
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

;----------------------------------------------------------------------------[$0F4E]---

_f4e:
.db <_0f84, >_0f84, $00			;Green Hill Act 1
.db <_0f93, >_0f93, $00			;Green Hill Act 2
.db <_0fde, >_0fde, $01			;Green Hill Act 3
.db <_0fa2, >_0fa2, $00			;Bridge Act 1
.db <_0fb1, >_0fb1, $00			;Bridge Act 2
.db <_107e, >_107e, $02			;Bridge Act 3
.db <_0fc0, >_0fc0, $00			;Jungle Act 1
.db <_0fcf, >_0fcf, $00			;Jungle Act 2
.db <_1088, >_1088, $03			;Jungle Act 3
.db <_100b, >_100b, $00			;Labyrinth Act 1
.db <_101a, >_101a, $00			;Labyrinth Act 2
.db <_1092, >_1092, $00			;Labyrinth Act 3
.db <_1029, >_1029, $00			;Scrap Brain Act 1
.db <_1038, >_1038, $00			;Scrap Brain Act 2
.db <_109c, >_109c, $00			;Scrap Brain Act 3
.db <_1047, >_1047, $00			;Sky Base Act 1
.db <_1056, >_1056, $00			;Sky Base Act 2
.db <_1056, >_1056, $00			;Sky Base Act 3

;----------------------------------------------------------------------------[$0F84]---

_0f84:					;Green Hill Act 1
.db <_10bd, >_10bd, $50, $68, $1E
.db <_10ab, >_10ab, $50, $68, $1E
.db <_0f84, >_0f84, $00, $00, $00
_0f93:					;Green Hill Act 2
.db <_10cf, >_10cf, $50, $60, $1E
.db <_10ab, >_10ab, $50, $60, $1E
.db <_0f93, >_0f93, $00, $00, $00
_0fa2:					;Bridge Act 1
.db <_10e1, >_10e1, $60, $60, $1E
.db <_10ab, >_10ab, $60, $60, $1E
.db <_0fa2, >_0fa2, $00, $00, $00
_0fb1:					;Bridge Act 2
.db <_10f3, >_10f3, $80, $50, $1E
.db <_10ab, >_10ab, $80, $50, $1E
.db <_0fb1, >_0fb1, $00, $00, $00
_0fc0:					;Jungle Act 1
.db <_1105, >_1105, $70, $48, $1E
.db <_10ab, >_10ab, $70, $48, $1E
.db <_0fc0, >_0fc0, $00, $00, $00
_0fcf:					;Jungle Act 2
.db <_1117, >_1117, $70, $38, $1E
.db <_10ab, >_10ab, $70, $38, $1E
.db <_0fcf, >_0fcf, $00, $00, $00
_0fde:					;Green Hill Act 3
.db <_1183, >_1183, $58, $58, $08
.db <_1183, >_1183, $58, $58, $08
.db <_1183, >_1183, $58, $56, $08
.db <_1183, >_1183, $58, $56, $08
.db <_1183, >_1183, $58, $55, $08
.db <_1183, >_1183, $58, $55, $08
.db <_1183, >_1183, $58, $56, $08
.db <_1183, >_1183, $58, $56, $08
.db <_0fde, >_0fde, $00, $00, $00
_100b:					;Labyrinth Act 1
.db <_1195, >_1195, $58, $68, $1E
.db <_10ab, >_10ab, $58, $68, $1E
.db <_100b, >_100b, $00, $00, $00
_101a:					;Labyrinth Act 2
.db <_11a7, >_11a7, $68, $78, $1E
.db <_10ab, >_10ab, $68, $78, $1E
.db <_101a, >_101a, $00, $00, $00
_1029:					;Scrap Brain Act 1
.db <_11b9, >_11b9, $70, $58, $1E
.db <_10ab, >_10ab, $70, $58, $1E
.db <_1029, >_1029, $00, $00, $00
_1038:					;Scrap Brain Act 2
.db <_11cb, >_11cb, $78, $48, $1E
.db <_10ab, >_10ab, $78, $48, $1E
.db <_1038, >_1038, $00, $00, $00
_1047:					;Sky Base Act 1
.db <_11dd, >_11dd, $68, $28, $1E
.db <_10ab, >_10ab, $68, $28, $1E
.db <_1047, >_1047, $00, $00, $00
_1056:					;Sky Base Act 2 / 3
.db <_11ef, >_11ef, $80, $28, $1E
.db <_11ef, >_11ef, $80, $26, $08
.db <_11ef, >_11ef, $80, $26, $08
.db <_11ef, >_11ef, $80, $25, $08
.db <_11ef, >_11ef, $80, $25, $08
.db <_11ef, >_11ef, $80, $26, $08
.db <_11ef, >_11ef, $80, $26, $08
.db <_1056, >_1056, $00, $00, $00
_107e:					;Bridge Act 3
.db <_1183, >_1183, $80, $48, $08
.db <_107e, >_107e, $00, $00, $00
_1088:					;Jungle Act 3
.db <_1183, >_1183, $78, $30, $08
.db <_1088, >_1088, $00, $00, $00
_1092:					;Labyrinth Act 3
.db <_1183, >_1183, $70, $60, $08
.db <_1092, >_1092, $00, $00, $00
_109c:					;Scrap Brain Act 3
.db <_1129, >_1129, $68, $40, $08
.db <_113b, >_113b, $68, $40, $08
.db <_109c, >_109c, $00, $00, $00

;----------------------------------------------------------------------------[$10AB]---

_10ab:					;blank frame (to make it blink)
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_10bd:					;Green Hill Act 1
.db $00, $02, $FF, $FF, $FF, $FF
.db $FE, $22, $24, $26, $28, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_10cf:					;Green Hill Act 2
.db $04, $06, $08, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_10e1:					;Bridge Act 1
.db $40, $42, $44, $46, $48, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_10f3:					;Bridge Act 2
.db $4A, $4C, $FF, $FF, $FF, $FF
.db $6A, $6C, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_1105:					;Jungle Act 1
.db $60, $62, $64, $66, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_1117:					;Jungle Act 2
.db $FE, $FE, $0E, $FF, $FF, $FF
.db $2A, $2C, $2E, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_1129:					;Scrap Brain Act 3 - step 1
.db $10, $12, $14, $16, $FF, $FF
.db $30, $32, $34, $36, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_113b:					;Scrap Brain Act 3 - step 2
.db $10, $12, $14, $18, $FF, $FF
.db $30, $32, $34, $38, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_114d:					;Robotnik flying right - frame 1
.db $50, $54, $56, $58, $FF, $FF	 ;referenced by the table at `_0e7a`
.db $70, $74, $76, $78, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_115f:					;Robotnik flying right - frame 2
.db $52, $54, $56, $58, $FF, $FF	 ;referenced by the table at `_0e7a`
.db $72, $74, $76, $78, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_1171:					;unused -- same as _114d
.db $50, $54, $56, $58, $FF, $FF
.db $70, $74, $76, $78, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_1183:					;Green Hill, Bridge, Jungle & Labyrinth Act 3
.db $5A, $5C, $5E, $FF, $FF, $FF
.db $7A, $7C, $7E, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_1195:					;Labyrinth Act 1
.db $00, $02, $FF, $FF, $FF, $FF
.db $20, $22, $04, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_11a7:					;Labyrinth Act 2
.db $0A, $0C, $0E, $FF, $FF, $FF
.db $2A, $2C, $2E, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_11b9:					;Scrap Brain Act 1
.db $68, $6A, $6C, $FF, $FF, $FF
.db $FE, $FE, $6E, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_11cb:					;Scrap Brain Act 2
.db $06, $08, $4A, $4C, $FF, $FF
.db $FE, $FE, $4E, $3E, $FF, $FF
.db $FE, $40, $42, $44, $FF, $FF
_11dd:					;Sky Base Act 1
.db $60, $62, $64, $66, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_11ef:					;Sky Base Act 2 / 3
.db $46, $48, $26, $28, $FF, $FF
.db $1A, $1C, $3A, $3C, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

;----------------------------------------------------------------------------[$1201]---
;list of functions that handle extra animations on the map screen

_1201:
.dw _0dd9
.dw _0e24
.dw _0e4b
.dw _0dd9

;____________________________________________________________________________[$1209]___

S1_ZoneTitle_Pointers:

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
	ld   a, (RAM_VDPREGISTER_1)
	and  %10111111			;remove bit 6 of $D219
	ld   (RAM_VDPREGISTER_1), a
	
	;wait for interrupt to complete?
	res  0, (iy+vars.flags0)
	call wait
	
	;load the title screen tile set
	 ;BANK 9 ($24000) + $2000 = $26000
	ld   hl, $2000
	ld   de, $0000
	ld   a, 9
	call decompressArt
	
	;load the title screen sprite set
	 ;BANK 9 ($24000) + $4B0A = $28B0A
	ld   hl, $4B0A
	ld   de, $2000
	ld   a, 9
	call decompressArt
	
	;now switch page 1 ($4000-$7FFF) to bank 5 ($14000-$17FFF)
	ld   a, 5
	ld   (SMS_PAGE_1), a
	ld   (RAM_PAGE_1), a
	
	;load the title screen itself
	ld   hl, $6000			;ROM:$16000
	ld   de, $3800
	ld   bc, $012E
	ld   a, $00
	ld   (RAM_TEMP1), a
	call decompressScreen
	
	;reset horizontal / vertical scroll
	xor  a				;set A to zero
	ld   (RAM_SCROLL_HORIZONTAL), a
	ld   (RAM_SCROLL_VERTICAL), a
	
	;load the palette
	ld   hl, S1_TitleScreen_Palette
	ld   a, %00000011		;flags to load tile and sprite palettes
	call loadPaletteOnInterrupt
	
	set  1, (iy+vars.flags0)
	
	;play title screen music
	ld   a, index_music_titleScreen
	rst  $18			;`playMusic`
	
	;initialise the animation parameters?
	xor  a
	ld   ($D216), a			;reset the screen counter
	ld   a, $01
	ld   (RAM_TEMP2), a
	ld   hl, _1372
	ld   (RAM_TEMP3), hl
	
	;------------------------------------------------------------------------------
-	;switch screen on (set bit 6 of VDP register 1)
	ld   a, (RAM_VDPREGISTER_1)
	or   %01000000
	ld   (RAM_VDPREGISTER_1), a
	
	res  0, (iy+vars.flags0)
	call wait
	
	;count to 100:
	ld   a, ($D216)			;get the screen counter
	inc  a				;add one
	cp   100			;if less than 100,
	jr   c, +			;keep counting,
	xor  a				;otherwise go back to 0
+	ld   ($D216), a			;update screen counter value
	
	ld   hl, _1352
	cp   $40
	jr   c, +
	ld   hl, _1362
+	xor  a				;set A to 0
	ld   (RAM_TEMP1), a
	call print
	
	ld   a, (RAM_TEMP2)
	dec  a
	ld   (RAM_TEMP2), a
	jr   nz, +
	
	ld   hl, (RAM_TEMP3)
	ld   e, (hl)
	inc  hl
	ld   d, (hl)
	inc  hl
	ld   a, (hl)
	inc  hl
	
	;when the animation reaches the end,
	 ;exit the title screen (begin demo mode)
	and  a
	jr   z, ++
	
	ld   (RAM_TEMP2), a
	ld   (RAM_TEMP3), hl
	ld   (RAM_TEMP4), de
	
	;set sprite table to use?
+	ld   hl, $D000
	ld   (RAM_SPRITETABLE_CURRENT), hl
	
	ld   hl, $0080
	ld   de, $0018
	ld   bc, (RAM_TEMP4)
	call processSpriteLayout
	
	;has the button been pressed? if not, repeat
	bit  5, (iy+vars.joypad)
	jp   nz, -
	
	scf

++	rst  $20			;`muteSound`
	ret

;"PRESS  BUTTON" text
_1352:					;text
.db $09, $12
.db $E3, $E4, $E5, $E6, $E6, $F1, $F1, $E9, $EB, $E7, $E7, $EA, $EC, $FF
_1362:					;text
.db $09, $12
.db $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $F1, $FF

;wagging finger animation data:
_1372:
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
.db <_13bd, >_13bd, $08
.db <_13cf, >_13cf, $08
_13b4:
.db <_13bd, >_13bd, $FF
.db <_13bd, >_13bd, $FF
.db <_13b4, >_13b4, $00
_13bd:					;frame 1 sprite layout
.db $00, $02, $04, $FF, $FF, $FF
.db $20, $22, $24, $FF, $FF, $FF
.db $40, $42, $44, $FF, $FF, $FF
_13cf:					;frame 2 sprite layout
.db $06, $08, $FF, $FF, $FF, $FF
.db $26, $28, $FF, $FF, $FF, $FF
.db $46, $48, $FF, $FF, $FF, $FF

S1_TitleScreen_Palette:			;[$13E1]
.db $00, $10, $34, $38, $06, $1B, $2F, $3F, $3D, $3E, $01, $03, $0B, $0F, $00, $3F
.db $00, $10, $34, $38, $06, $1B, $2F, $3F, $3D, $3E, $01, $03, $0B, $0F, $00, $3F

;____________________________________________________________________________[$1401]___
;Act Complete screen?

_1401:
	;turn off the screen
	ld      a,(RAM_VDPREGISTER_1)
	and     %10111111		;remove bit 6 of VDP register 1
	ld      (RAM_VDPREGISTER_1),a
	
	res     0,(iy+vars.flags0)
	call    wait
	di      
	
	;act complete sprite set
	ld      hl,$351f
	ld      de,$0000
	ld      a,9
	call    decompressArt
	
	;switch page 1 ($4000-$7FFF) to bank 5 ($14000-$17FFF)
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	
	;act complete background
	ld      hl,$67fe
	ld      bc,$0032
	ld      de,$3800
	ld      a,$00
	ld      (RAM_TEMP1),a
	call    decompressScreen
	
	xor     a
	ld      (RAM_SCROLL_HORIZONTAL),a
	ld      (RAM_SCROLL_VERTICAL),a
	ld      hl,_14fc
	ld      a,$03
	call    loadPaletteOnInterrupt
	ei      
	ld      b,$78
	
-	;turn the screen on
	ld      a,(RAM_VDPREGISTER_1)
	or      %01000000		;enable bit 6 on VDP register 1
	ld      (RAM_VDPREGISTER_1),a
	
	res     0,(iy+vars.flags0)
	call    wait
	
	djnz    -
	
	ld      a,($d284)
	and     a
	jr      nz,+
	
	ld      bc,$00b4
-	push    bc
	
	res     0,(iy+vars.flags0)
	call    wait
	
	pop     bc
	dec     bc
	ld      a,b
	or      c
	ret     z
	
	bit     5,(iy+vars.joypad)
	jp      nz,-
	
	and     a
	ret

	;------------------------------------------------------------------------------
+	ld      hl,_14de
	ld      c,$0b
	call    _16d9
	ld      hl,_14e6
	call    print
	ld      hl,_14f1
	call    print
	ld      a,$09
	ld      ($d216),a
--	ld      b,$3c
	
-	push    bc
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),$00
	ld      hl,$d216
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	
	ex      de,hl
	
	ld      hl,$d000
	ld      c,$8c
	ld      b,$5e
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	
	pop     bc
	bit     5,(iy+vars.joypad)
	jr      z,+
	djnz    -
	
	ld      a,$1a
	rst     $28			;`playSFX`
	
	ld      hl,$d216
	ld      a,(hl)
	and     a
	ret     z
	dec     (hl)
	jr      --
	
	;get the bit flag for the level
+	ld      hl,$d311
	call    getLevelBitFlag
	ld      a,c
	cpl     			;invert the level bits (i.e. create a mask)
	ld      c,a
	
	ld      a,(hl)
	and     c			;remove the level bit
	ld      (hl),a
	
	ld      hl,$D284
	dec     (hl)
	scf     			;set carry flag
	
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

;____________________________________________________________________________[$155E]___
;Act Complete screen?

_155e:
	ld	a, (RAM_CURRENT_LEVEL)
	cp 	19
	jp      z,_172f
	
	ld      a,(RAM_VDPREGISTER_1)
	and     %10111111
	ld      (RAM_VDPREGISTER_1),a
	
	res     0,(iy+vars.flags0)
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
	ld      (RAM_PAGE_1),a
	
	;UNKNOWN
	ld      hl,$612e
	ld      bc,$00bb
	ld      de,$3800
	ld      a,(RAM_CURRENT_LEVEL)
	cp      28
	jr      c,+
	
	;UNKNOWN
	ld      hl,$61e9		;$161E9?
	ld      bc,$0095
	ld      de,$3800

+	xor     a
	ld      (RAM_TEMP1),a
	call    decompressScreen
	
	ld      hl,_1711
	ld      c,$10
	ld      a,($d27f)
	and     a
	call    nz,_16d9
	
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1c
	jr      nc,+
	
	ld      a,$15
	ld      ($d2be),a
	ld      a,$04
	ld      ($d2bf),a
	ld      a,(RAM_CURRENT_LEVEL)
	ld      e,a
	ld      d,$00
	ld      hl,_1b69
	add     hl,de
	ld      e,(hl)
	ld      hl,_1b51
	add     hl,de
	ld      b,$04
	
-	push    bc
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
	djnz    -
	
+	xor     a
	ld      (RAM_SCROLL_HORIZONTAL),a
	ld      (RAM_SCROLL_VERTICAL),a
	ld      hl,$1b8d
	ld      a,$03
	call    loadPaletteOnInterrupt
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1c
	jr      c,+
	ld      hl,$d281
	inc     (hl)
	bit     2,(iy+vars.flags9)
	jr      nz,+
	ld      hl,$d282
	inc     (hl)
	ld      hl,$d285
	inc     (hl)

+	bit     2,(iy+vars.flags9)
	call    nz,_1719
	
	bit     3,(iy+vars.flags9)
	call    nz,_1726
	
	ld      hl,$153e
	ld      de,$154e
	ld      b,$08
	
-	ld      a,($d2ce)
	cp      (hl)
	jr      nz,+
	inc     hl
	ld      a,($d2cf)
	cp      (hl)
	jr      nc,+++
	inc     hl
	jr      ++

+	jr      nc,+++
	inc     hl
	inc     hl
++	inc     de
	inc     de
	djnz    -
	
	ld      de,$151e
	jr      ++++
	
+++	ex      de,hl
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
++++	ld      hl,RAM_TEMP4
	ex      de,hl
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1c
	jr      c,+
	ld      hl,_1a14
+	ldi     
	ldi     
	ldi     
	ldi     
	set     1,(iy+vars.flags0)
	ld      b,$78
	
-	push    bc
	ld      a,(RAM_VDPREGISTER_1)
	or      $40
	ld      (RAM_VDPREGISTER_1),a
	
	res     0,(iy+vars.flags0)
	call    wait
	
	call    _1a18
	pop     bc
	djnz    -
	
-	res     0,(iy+vars.flags0)
	call    wait
	
	call    _1a18
	call    _19b4
	ld      a,(RAM_CURRENT_LEVEL)
	cp      28
	call    c,_19df
	ld      a,($d216)
	inc     a
	ld      ($d216),a
	and     $03
	jr      nz,+
	ld      a,$02
	rst     $28			;`playSFX`

+	ld      hl,(RAM_TEMP4)
	ld      de,(RAM_TEMP6)
	ld      a,(RAM_RINGS)
	or      h
	or      l
	or      d
	or      e
	jp      nz,-
	ld      b,$b4
	
-	push    bc
	res     0,(iy+vars.flags0)
	call    wait
	call    _1a18
	pop     bc
	bit     5,(iy+vars.joypad)
	jr      z,+
	djnz    -

+	ret

;____________________________________________________________________________[$16D9]___

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
	ld      (RAM_TEMP1),a
	
-	push    bc
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
	djnz    -
	
	ret

_1711:
.db $14, $ad, $ae, $ff, $15, $bd, $be, $ff

;____________________________________________________________________________[$1719]___

_1719:
	xor     a
	ld      (RAM_RINGS),a
	res     3,(iy+vars.flags9)
	res     2,(iy+vars.flags9)
	ret

;____________________________________________________________________________[$1726]___
;called by Act Complete screen?

_1726:
	ld      hl,$d284
	inc     (hl)
	res     3,(iy+vars.flags9)
	ret

;____________________________________________________________________________[$172F]___
;jumped to from $155E

_172f:
	ld      a,$ff
	ld      ($d2fd),a
	ld      c,$00
	ld      a,($d27f)
	cp      $06
	jr      c,+
	ld      c,$05
+	ld      a,($d280)
	cp      $12
	jr      c,+
	ld      a,c
	add     a,$05
	daa     
	ld      c,a
+	ld      a,($d281)
	cp      $08
	jr      c,+
	ld      a,c
	add     a,$05
	daa     
	ld      c,a
+	ld      a,($d282)
	cp      $08
	jr      c,+
	ld      a,c
	add     a,$05
	daa     
	ld      c,a
+	ld      a,($d283)
	and     a
	jr      nz,+
	ld      a,c
	add     a,$0a
	daa     
	ld      c,a
+	ld      a,c
	cp      $30
	jr      nz,+
	ld      a,c
	add     a,$0a
	daa     
	add     a,$0a
	daa     
	ld      c,a
+	ld      hl,$d2ff
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
	
-	ld      bc,$003c
	call    _1860
	ld      a,($d27f)
	and     a
	jr      z,+
	dec     a
	ld      ($d27f),a
	ld      de,$0000
	ld      c,$02
	call    _39d8
	ld      a,$02
	rst     $28			;`playSFX`
	jp      -
	
+	ld      bc,$00b4
	call    _1860
	ld      a,$01
	ld      ($d216),a
	ld      hl,_198e
	call    print
	ld      bc,$00b4
	call    _1860
	
-	ld      bc,$001e
	call    _1860
	ld      a,(RAM_LIVES)
	and     a
	jr      z,+
	dec     a
	ld      (RAM_LIVES),a
	ld      de,$5000
	ld      c,$00
	call    _39d8
	ld      a,$02
	rst     $28			;`playSFX`
	jp      -
	
+	ld      bc,$00b4
	call    _1860
	ld      a,$02
	ld      ($d216),a
	ld      hl,_199e
	call    print
	ld      hl,_197a
	call    print
	ld      bc,$00b4
	call    _1860

-	ld      bc,$001e
	call    _1860
	ld      a,($d2ff)
	and     a
	jr      z,++
	dec     a
	ld      c,a
	and     $0f
	cp      $0a
	jr      c,+
	ld      a,c
	sub     $06
	ld      c,a
+	ld      a,c
	ld      ($d2ff),a
	ld      de,$0000
	ld      c,$01
	call    _39d8
	ld      a,$02
	rst     $28			;`playSFX`
	jp      -
	
++	ld      bc,$01e0
	call    _1860
	ret

;____________________________________________________________________________[$1860]___

_1860:
	push    bc
	
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),$00
	ld      hl,$d000
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      hl,$d2ba
	ld      de,$d2be
	ld      b,$04
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$90
	ld      b,$80
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      a,($d216)
	and     a
	jr      nz,+
	ld      hl,$d27f
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$90
	ld      b,$60
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      hl,_19ae
	ld      de,$d2be
	ld      b,$03
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$a0
	ld      b,$60
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	jr      ++
	
+	dec     a
	jr      nz,+
	call    _1aca
	ld      hl,_19b1
	ld      de,$d2be
	ld      b,$03
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$a0
	ld      b,$60
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	jr      ++
	
+	ld      hl,$d2ff
	ld      de,$d2be
	ld      b,$03
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$a0
	ld      b,$60
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	
++	pop     bc
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

;____________________________________________________________________________[$19B4]___

_19b4:
	ld      hl,RAM_RINGS
	ld      a,(hl)
	and     a
	ret     z
	
	dec     a
	ld      c,a
	and     %00001111
	cp      $0A
	jr      c,+
	ld      a,c
	sub     $06
	ld      c,a
+	ld      (hl),c
	ld      de,$0100
	ld      c,$00
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1c
	jr      c,+
	ld      a,($d285)
	ld      d,a
	ld      a,($d286)
	ld      e,a
+	call    _39d8
	ret

;____________________________________________________________________________[$19DF]___

_19df:
	ld      hl,(RAM_TEMP4)
	ld      de,(RAM_TEMP6)
	ld      a,h
	or      l
	or      d
	or      e
	ret     z
	ld      b,$03
	ld      hl,RAM_TEMP6
	scf     
	
-	ld      a,(hl)
	sbc     a,$00
	ld      c,a
	and     $0f
	cp      $0a
	jr      c,+
	ld      a,c
	sub     $06
	ld      c,a
+	ld      a,c
	cp      $a0
	jr      c,+
	sub     $60
+	ld      (hl),a
	ccf     
	dec     hl
	djnz    -
	
	ld      de,$0100
	ld      c,$00
	call    _39d8
	ret

_1a14:
.db $00, $00, $00, $00

;____________________________________________________________________________[$1A18]___

_1a18:
	ld      (iy+vars.spriteCount),$00
	ld      hl,$d000
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      hl,$d2ba
	ld      de,$d2be
	ld      b,$04
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$88
	ld      b,$50
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      hl,RAM_RINGS
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$98
	ld      b,$80
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1c
	jr      c,+
	ld      b,$68
+	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1c
	jr      c,+
	ld      hl,$d285
	ld      de,$d2be
	ld      b,$02
	call    _1b13
	ld      b,$68
	jr      ++
	
+	ld      hl,$151c
	ld      de,$d2be
	ld      b,$02
	call    _1b13
	ld      b,$80
++	ld      c,$c0
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	call    _1aca
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1c
	jr      nc,+
	ld      hl,RAM_TEMP4
	ld      de,$d2be
	ld      b,$04
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$88
	ld      b,$68
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ret
	
+	ld      hl,$d284
	ld      de,$d2be
	ld      b,$01
	call    _1b13
	ex      de,hl
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      c,$a8
	ld      b,$80
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ret

;____________________________________________________________________________[$1ACA]___

_1aca:
	ld      a,(RAM_LIVES)
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
	ld      a,(RAM_LIVES)
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
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $13
	jr      nz,+
	ld      b,$60
	ld      c,$90
+	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ret

;____________________________________________________________________________[$1B13]___

_1b13:
	ld      a,(hl)
	and     $f0
	jr      nz,_f
	ld      a,$fe
	ld      (de),a
	inc     de
	ld      a,(hl)
	and     $0f
	jr      nz,+
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
	
__	ld      a,(hl)
	rrca    
	rrca    
	rrca    
	rrca    
	and     $0f
	add     a,a
	add     a,$80
	ld      (de),a
	inc     de
+	ld      a,(hl)
	and     $0f
	add     a,a
	add     a,$80
	ld      (de),a
	inc     hl
	inc     de
	djnz    _b
	ld      a,$ff
	ld      (de),a
	ld      hl,$d2be
	ret

;____________________________________________________________________________[$1B51]___
;UNKNOWN

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
	ld      (iy+vars.joypad),a
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

;____________________________________________________________________________[$1C49]___

_LABEL_1C49_62:
	;set bit 0 of the parameter address (IY=$D200); when `wait` is called,
	 ;execution will pause until an interrupt event switches bit 0 of $D200 on?
	set  0, (iy+vars.flags0)			
	ei				;enable interrupts
	
	;default to 3 lives
--	ld   a, 3
	ld   (RAM_LIVES), a
	
	ld   a, $05
	ld   ($D2FD), a
	
	ld   a, $1C
	ld   ($D23F), a
	
	xor  a				;set A to 0
	ld   (RAM_CURRENT_LEVEL), a	;set starting level!
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
	
	res  0, (iy+vars.flags2)
	res  1, (iy+vars.flags2)
	call hideSprites
	call titleScreen
	
	res  1, (iy+vars.scrollRingFlags)
	jr   c, _LABEL_1C9F_104
	
	set  1, (iy+vars.scrollRingFlags)
	
_LABEL_1C9F_104:
	;are we on the end sequence?
	ld   a, (RAM_CURRENT_LEVEL)
	cp   19
	jr   nc, --
	
	res  0, (iy+vars.flags2)
	res  1, (iy+vars.flags2)
	call hideSprites
	call _LABEL_C52_106
	bit  1, (iy+vars.scrollRingFlags)
	jr   z, _LABEL_1CBD_120
	jp   c, --
	
_LABEL_1CBD_120:
	call _LABEL_A40_121
	call hideSprites
	bit  0, (iy+vars.scrollRingFlags)
	jr   nz, +
	bit  4, (iy+vars.flags6)
	jr   nz, ++
	
	;wait at title screen for button press?
+	ld   b, $3C
-	res  0, (iy+vars.flags0)
	call wait
	djnz -
	
	rst  $20			;`muteSound`
	
++	call _LABEL_1CED_131
	and     a
	jp      z,--
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
	ld   (RAM_PAGE_1), a
	
	ld   a, (RAM_CURRENT_LEVEL)
	bit  4, (iy+vars.flags6)
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
	
	set     0,(iy+vars.flags2)
	set     1,(iy+vars.flags2)
	set     1,(iy+vars.flags0)
	set     3,(iy+vars.flags6)
	res     3,(iy+vars.timeLightningFlags)
	res     0,(iy+vars.flags9)
	res     6,(iy+vars.flags6)
	res     0,(iy+vars.unknown0)
	res     6,(iy+vars.flags0)
	
	;auto scroll right?
	bit     3,(iy+vars.scrollRingFlags)
	call    nz,_1ed8		;if yes, skip way ahead
	
	ld      b,$10
-	push    bc
	
	res     0,(iy+vars.flags0)
	call    wait
	
	ld      (iy+vars.joypad),$ff	;clear joypad input
	
	ld      hl,($d223)
	inc     hl
	ld      ($d223),hl
	
	;switch page 1 ($4000-$7FFF) to bank 11 ($2C000-$2FFFF)
	ld      a,11
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	
	;are rings enabled?
	bit     2,(iy+vars.scrollRingFlags)
	call    nz,updateRingFrame
	
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
	ld      (RAM_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	
	call    _2e5a
	call    _063e
	call    _06bd
	
	set     5,(iy+vars.flags0)		
	
	pop     bc
	djnz    -
	
	;demo mode?
	bit     1,(iy+vars.scrollRingFlags)
	jr      z,_1dae
	
	ld      hl,$0000
	ld      ($d2b5),hl
	ld      (iy+vars.spriteCount),h
_1dae:
	res     0,(iy+vars.flags0)
	call    wait
	
	;switch page 1 ($4000-$7FFF) to bank 11 ($2C000-$2FFFF)
	ld      a,11
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	
	;are rings enabled?
	bit     2,(iy+vars.scrollRingFlags)
	call    nz,updateRingFrame
	
	bit     3,(iy+vars.flags6)		
	call    nz,_3a03
	
	ld      a,($d223)
	and     %00000001
	jr      nz,+
	
	ld      a,($d289)
	and     a
	call    nz,_1fa9
	
	jr      ++
	
+	ld      a,($d287)
	and     a
	jp      nz,_2067
_1de2:					;jump to here from _2067
	ld      a,($d2b1)
	and     a
	call    nz,_1f06
	
	;is lightning effect enabled?
	bit     1,(iy+vars.timeLightningFlags)
	call    nz,_1f49		;if so, handle that
	
++	bit     1,(iy+vars.flags6)
	call    nz,++
	
	;are we in demo mode?
	bit     1,(iy+vars.scrollRingFlags)
	jr      z,+			;no, skip ahead
	
	bit     5,(iy+vars.joypad)	;is button pressed?
	jp      z,_20b8			;if yes, end demo mode -- fade out and return
	
	call    _1bad			;process demo mode?
	
+	ld      hl,($d223)
	inc     hl
	ld      ($d223),hl
	
	;auto scrolling to the right? (ala Bridge 2)
	bit     3,(iy+vars.scrollRingFlags)
	call    nz,_1ee2
	
	;auto scrolling upwards?
	bit     4,(iy+vars.scrollRingFlags)
	call    nz,_1ef2
	
	;no down scrolling (ala Jungle 2)
	bit     7,(iy+vars.scrollRingFlags)
	call    nz,_1eff
	
	call    _23c9
	
	;are rings enabled?
	bit     2,(iy+vars.scrollRingFlags)
	call    nz,_239c
	
	xor     a			;set A to 0
	ld      ($d302),a
	ld      ($d2de),a
	ld      (iy+vars.spriteCount),$15
	ld      hl,$d03f		;lives icon sprite table entry
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      hl,$d001
	ld      b,$07
	ld      de,$0003
	ld      a,$e0
	
-	ld      (hl),a
	add     hl,de
	ld      (hl),a
	add     hl,de
	ld      (hl),a
	add     hl,de
	djnz    -
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	
	call    _2e5a
	call    _063e
	call    _06bd
	
	ld      hl,RAM_VDPREGISTER_1
	set     6,(hl)
	
	;paused?
	bit     3,(iy+vars.timeLightningFlags)
	call    nz,_1e9e
	
	jp      _1dae

++	ld      (iy+vars.joypad),$f7
	ld      hl,(RAM_LEVEL_CROPLEFT)
	ld      de,$0112
	add     hl,de
	ex      de,hl
	ld      hl,($d3fe)
	xor     a
	sbc     hl,de
	ret     c
	ld      (iy+vars.joypad),$ff
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
	ld      ($d406),hl
	ld      ($d408),a
	ret

;____________________________________________________________________________[$1E9E]___

_1e9e:	;demo mode?
	bit     1,(iy+vars.scrollRingFlags)
	ret     nz
	rst     $20			;`muteSound`
	
-	ld      a,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),a
	ld      a,11
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	
	;are rings enabled?
	bit     2,(iy+vars.scrollRingFlags)
	call    nz,updateRingFrame
	call    _23c9
	call    _239c
	;paused?
	bit     3,(iy+vars.timeLightningFlags)
	jr      nz,-
	
	ld      a,:sound_unpause
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	call    sound_unpause
	ret

;____________________________________________________________________________[$1ED8]___

_1ed8:
	ld      hl,($d25a)
	ld      (RAM_LEVEL_CROPLEFT),hl
	ld      ($d275),hl
	ret

;____________________________________________________________________________[$1EE2]___

_1ee2:
	ld      a,($d223)
	rrca    
	ret     nc
	ld      hl,(RAM_LEVEL_CROPLEFT)
	inc     hl
	ld      (RAM_LEVEL_CROPLEFT),hl
	ld      ($d275),hl
	ret

;____________________________________________________________________________[$1EF2]___

_1ef2:
	ld      a,($d223)
	rrca    
	ret     nc
	ld      hl,(RAM_LEVEL_EXTENDHEIGHT)
	dec     hl
	ld      (RAM_LEVEL_EXTENDHEIGHT),hl
	ret

;____________________________________________________________________________[$1EFF]___

_1eff:
	ld      hl,($d25d)
	ld      (RAM_LEVEL_EXTENDHEIGHT),hl
	ret

;____________________________________________________________________________[$1F06]___

_1f06:
	dec     a
	ld      ($d2b1),a
	ld      e,a
	di      
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ld      e,$00
	ld      a,($d2b2)
	ld      hl,($d230)
	and     a
	jp      p,+
	and     $7f
	ld      hl,($d232)
	ld      e,$10
+	ld      c,a
	ld      b,$00
	add     hl,bc
	add     a,e
	out     (SMS_VDP_CONTROL),a
	ld      a,$c0
	out     (SMS_VDP_CONTROL),a
	ld      a,($d2b1)
	and     $01
	ld      a,(hl)
	jr      z,+
	ld      a,($d2b3)
+	out     (SMS_VDP_DATA),a
	ei      
	ret

;____________________________________________________________________________[$1F49]___

_1f49:	;lightning is enabled...
	ld      de,($d2e9)
	ld      hl,$00aa
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      bc,_1f9d
	ld      e,a
	ld      d,a
	jp      ++
	
+	ld      bc,_1fa5
	ld      hl,$0082
	sbc     hl,de
	jr      z,+
	ld      bc,$1fa1
	ld      hl,$0064
	sbc     hl,de
	jr      z,++
	ld      bc,$1f9d
	ld      a,e
	or      d
	jr      z,++
	jp      +++
	
+	push    bc
	ld      a,$13
	rst     $28			;`playSFX`
	pop     bc
	
++	ld      hl,$d2a4
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
	ld      (RAM_CYCLEPALETTE_POINTER),hl
+++	inc     de
	ld      ($d2e9),de
	ret    
	
;lightning palette control:
_1f9d:
.db $02, $04
.dw S1_PaletteCycles_SkyBase1
_1fa1:
.db $02, $04
.dw S1_PaletteCycles_SkyBase1_Lightning1
_1fa5:
.db $02, $04
.dw S1_PaletteCycles_SkyBase1_Lightning2

;____________________________________________________________________________[$1FA9]___

_1fa9:
	dec     a
	ld      ($d289),a
	jr      z,+
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
	
+	call    _LABEL_A40_121
	pop     hl
	res     5,(iy+vars.flags0)
	bit     2,(iy+$0d)
	jr      nz,+++
	bit     4,(iy+vars.flags6)
	jr      nz,++++
	rst     $20			;`muteSound`
	bit     7,(iy+vars.flags6)
	call    nz,_20a4
	call    hideSprites
	call    _155e			;Act Complete screen?
	
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $1a
	jr      nc,++
	bit     0,(iy+vars.timeLightningFlags)
	jr      z,+
	ld      hl,$2047
	call    _b60
	ld      a,(RAM_CURRENT_LEVEL)
	push    af
	ld      a,($d23f)
	ld      (RAM_CURRENT_LEVEL),a
	inc     a
	ld      ($d23f),a
	call    _LABEL_1CED_131
	pop     af
	ld      (RAM_CURRENT_LEVEL),a
+	ld      hl,$d23e
	inc     (hl)
	ld      a,$01
	ret
	
++	res     0,(iy+vars.timeLightningFlags)
	ld      a,$ff
	ret
	
+++	ld      hl,$d23e
	inc     (hl)
++++	ld      a,$ff
	ret

;____________________________________________________________________________[$2023]___

_2023:
.dw $0000, _202d, _2031, _2039, _203f

_202d:
	ld a, $0E
	rst $28				;`playSFX`
	ret

_2031:
	ld      hl,RAM_LIVES
	inc     (hl)
	ld      a,$09
	rst     $28			;`playSFX`
	ret
_2039:
	ld      a,$10
	call    _39ac
	ret
_203f:
	ld      a,$07
	rst     $28			;`playSFX`
	set     0,(iy+vars.timeLightningFlags)
	ret

;____________________________________________________________________________[$2047]___

_2047:
.db $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F
.db $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F, $7F

;____________________________________________________________________________[$2067]___

_2067:
	dec	a
	ld      ($d287),a
	jp      nz,_1de2
	
	;demo mode?
	bit     1,(iy+vars.scrollRingFlags)
	jr      nz,_20b8
	bit     4,(iy+vars.origFlags6)
	jr      z,+
	set     4,(iy+vars.flags6)
+	bit     7,(iy+vars.flags6)
	call    nz,_20a4
	ld      a,(RAM_LIVES)
	and     a
	ld      a,$02
	ret     nz
	call    _LABEL_A40_121
	call    hideSprites
	res     5,(iy+vars.flags0)
	call    _1401
	ld      a,$00
	ret     nc
	ld      a,$03
	ld      (RAM_LIVES),a
	ld      a,$01
	ret

;____________________________________________________________________________[$20A4]___

_20a4:
	ld      a,(RAM_RASTERSPLIT_STEP)
	and     a
	jr      nz,_20a4
	di      
	res     7,(iy+vars.flags6)	;underwater?
	xor     a
	ld      (RAM_RASTERSPLIT_LINE),a
	ld      (RAM_WATERLINE),a
	ei      
	ret

;____________________________________________________________________________[$20B8]___

_20b8:
	ld      a,:sound_fadeOut
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	
	ld      hl,$0028
	call    sound_fadeOut
	call    _LABEL_A40_121
	
	xor     a
	ret
	
;____________________________________________________________________________[$20CB]___

loadLevel:
;PAGE 1 ($4000-$7FFF) is at BANK 5 ($14000-$17FFF)
;HL : address for the level header
	ld   a, (RAM_VDPREGISTER_1)
	and  %10111111			;remove bit 6
	ld   (RAM_VDPREGISTER_1), a
	
	res  0, (iy+vars.flags0)
	call wait
	
	;copy the level header from ROM to RAM starting at $D354
	 ;(this copies 40 bytes, even though level headers are 37 bytes long.
	 ; the developers probably removed header bytes later in development)
	ld   de, $D354
	ld   bc, 40
	ldir
	
	ld   hl, $D354			;position HL at the start of the header
	push hl				;remember the start point
	
	;read the current Scrolling / Ring HUD value
	ld   a, (iy+vars.scrollRingFlags)
	ld   (iy+$0b), a		;take a copy
	ld   a, (iy+vars.flags6)	;read the current underwater flag value
	ld   (iy+vars.origFlags6), a	;take a copy
	ld   a, $FF
	ld   ($D2AB), a
	
	xor  a				;set A to 0
	ld   l, a			;set HL to #$0000
	ld   h, a
	;clear some variables
	ld   (RAM_SCROLL_HORIZONTAL), a
	ld   (RAM_SCROLL_VERTICAL), a
	ld   ($D27B), hl
	ld   ($D27D), hl
	ld   ($D2B7), hl
	ld   (RAM_RASTERSPLIT_STEP), a
	ld   (RAM_RASTERSPLIT_LINE), a
	
	;clear $D287-$D2A4 (29 bytes)
	ld   hl, $D287
	ld   b, 29
	call _fillMemoryWithValue
	
	;get the bit flag for the level:
	 ;C returns a byte with bit x set, where x is the level number mod 8
	 ;DE will be the level number divided by 8
	 ;HL will be $D311 + the level number divided by 8
	ld	hl, $D311
	call	getLevelBitFlag
	
	;DE will now be $D311 + the level number divided by 8
	ex   de, hl
	
	ld   hl, $0800
	ld   a, (RAM_CURRENT_LEVEL)
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
	ld   (RAM_WATERLINE), a
	ld   hl, $0020

++	ld   ($D2DC), hl		;either $0800 or $0020
	ld   hl, $FFFE
	ld   (RAM_TIME), hl
	ld   hl, $23FF
	
	bit  4, (iy+vars.flags6)
	jr   z, +
	
	bit  0, (iy+vars.scrollRingFlags)
	jr   z, ++
	
	ld   hl, _2402
	
+	xor  a				;set A to 0
	ld   (RAM_RINGS), a
	
	;is this a special stage? (level number 28+)
	ld   a, (RAM_CURRENT_LEVEL)
	sub  28
	jr   c, +			;skip ahead if level < 28
	
	;triple the level number for a lookup table of 3-bytes each entry
	ld   c, a
	add  a, a
	add  a, c
	ld   e, a
	ld   d, $00
	ld   hl, _2405
	add  hl, de
	
	;copy 3 bytes from HL (`_2402` for regular levels, `_2405`+ for special stages)
	 ;to $D2CE/D/F
+	ld   de, $D2CE
	ld   bc, $0003
	ldir
	
++	;load HUD sprite set
	ld   hl, $B92E			;$2F92E
	ld   de, $3000
	ld   a, 9
	call decompressArt
	
	pop     hl			;get back the address to the level header
	;SP: Solidity Pointer
	ld      a,(hl)
	ld      (RAM_LEVEL_SOLIDITY),a
	inc     hl
	;FW: Floor Width
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (RAM_LEVEL_FLOORWIDTH),de
	;FH: Floor Height
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (RAM_LEVEL_FLOORHEIGHT),de
	;copy the next 8 bytes to $D273+
	 ;CL: Crop Left
	 ;LX: Level X Offset
	 ;??: Unknown
	 ;LW: Level Width
	 ;CT: Crop Top
	 ;LY: Level Y Offset
	 ;XH: Extend Height
	 ;LH: Level Height
	ld      de,RAM_LEVEL_CROPLEFT
	ld      bc,$0008
	ldir    
	
	;currently HL will be sitting on byte 14 ("SX") of the level header
	push    hl
	push    hl
	
	;get the level bit flag:
	 ;C returns a byte with bit x set, where x is the level number mod 8
	 ;DE will be the level number divided by 8
	 ;HL will be $D311 + the level number divided by 8
	ld      hl,$d311
	call    getLevelBitFlag
	
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
	
	ld      a,(RAM_CURRENT_LEVEL)	;get current level number
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
	
	sub     3
	jr      nc,+
	xor     a			;set A to 0
	
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
	jr      c,+
	sub     $40
	ld      h,a
	ld      a,6
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,7
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	jr      ++
	
+	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,6
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	
++	ei      			;enable interrupts
	
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
	ld      (RAM_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ei      
	
	;read the palette pointer into HL
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	;queue the palette to be loaded via the interrupt
	ld      a,$03
	call    loadPaletteOnInterrupt
	
	res     0,(iy+vars.flags0)
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
	;offset into the cycle palette pointers table
	ld      hl,S1_PaletteCycle_Pointers
	add     hl,bc			
	
	;switch pages 1 & 2 ($4000-$BFFF) to banks 1 & 2 ($4000-$BFFF)
	di      
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,2
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ei      
	
	;read the cycle palette pointer
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      (RAM_CYCLEPALETTE_POINTER),hl
	
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
	ld      (RAM_PAGE_1),a
	call    _232b			;load the object layout
	
	pop     hl
	
	;SR: Scrolling / Ring HUD flags
	ld      c,(hl)
	ld      a,(iy+vars.scrollRingFlags)		
	and     %00000010
	or      c
	ld      (iy+vars.scrollRingFlags),a
	
	;UW: Underwater flag
	inc     hl
	ld      a,(hl)
	ld      (iy+vars.flags6),a
	
	;TL: Time HUD / Lightning effect flags
	inc     hl
	ld      a,(hl)
	ld      (iy+vars.timeLightningFlags),a
	
	;00: Unknown byte
	inc     hl
	ld      a,(hl)
	ld      (iy+vars.unknown0),a
	
	;MU: Music
	inc     hl
	ld      a,(RAM_PREVIOUS_MUSIC)	;check previously played music
	cp      (hl)
	jr      z,+			;if current music is the same, skip ahead
	
	ld      a,(hl)			;get the music number from the level header
	and     a			;this won't change the value of A, but it will
					 ;update the flags, so that ...
	jp      m,+			;we can check if the sign is negative,
					 ;that is, A>127
	
	;remember the current level music to restore it after invincibility &c.
	ld      (RAM_LEVEL_MUSIC),a
	rst     $18			;`playMusic`

	;fill 64 bytes (32 16-bit numbers) from $D37C-$D3BC
+	ld      b,32
	ld      hl,$d37c
	xor     a			;set A to 0

-	ld      (hl),a
	inc     hl
	ld      (hl),a
	inc     hl
	djnz    -
	
	bit     5,(iy+vars.origFlags6)
	ret     z
	set     5,(iy+vars.flags6)
	
	ret
	
;____________________________________________________________________________[$232B]___

;load object layout
_232b:
;HL : address of an object layout?
	push    hl
	
	ld      ix,$d3fc		;current level's object list
	ld      de,$001a
	ld      c,$00
	ld      hl,($d216)
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

;----------------------------------------------------------------------------[$235E]---

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

;animate ring
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
	ld      (RAM_RING_CURRENT_FRAME),hl
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
	jr      c,+
	xor     a
+	ld      (hl),a
	ret

;____________________________________________________________________________[$23C9]___

_23c9:
	ld      a,($d2a4)		;palette Cycle Speed
	dec     a
	ld      ($d2a4),a
	ret     nz
	
	ld      a,(RAM_CYCLEPALETTE_INDEX)
	ld      l,a
	ld      h,$00
	add     hl,hl
	add     hl,hl
	add     hl,hl
	add     hl,hl
	ld      de,(RAM_CYCLEPALETTE_POINTER)
	add     hl,de
	ld      a,$01
	call    loadPaletteOnInterrupt
	ld      hl,(RAM_CYCLEPALETTE_INDEX)
	ld      a,l
	inc     a
	cp      h
	jr      c,+
	xor     a
+	ld      l,a
	ld      (RAM_CYCLEPALETTE_INDEX),hl
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
.db $01, $00, $00			;Special Stage 1?
.db $01, $00, $00			;Special Stage 2?
.db $00, $45, $00			;Special Stage 3?
.db $00, $50, $00			;Special Stage 4?
.db $00, $45, $00			;Special Stage 5?
.db $00, $50, $00			;Special Stage 6?
.db $00, $50, $00			;Special Stage 7?
.db $00, $30, $00			;Special Stage 8?
.db $01, $00, $00
.db $01, $00, $01
.db $02, $00, $01
.db $02, $FF, $02
.db $03, $01, $01
.db $03, $FE, $02
.db $04, $01, $01
.db $04, $FD, $03
.db $05, $02, $01
.db $06, $FB, $03
.db $06, $03, $00
.db $07, $FA, $03
.db $06, $05, $FF
.db $08, $F9, $03
.db $07, $06, $FE
.db $09, $F7, $03
.db $07, $08, $FD
.db $0A, $F6, $02
.db $07, $09, $FB
.db $0B, $F4, $01
.db $06, $0B, $FA
.db $0B, $F3, $00, $06, $0D, $F8, $0B, $F2, $FF
.db $05, $0E, $F6, $0B, $F1, $FD, $03, $10, $F4, $0B, $F0, $FB, $02, $12, $F2, $0A
.db $F0, $F9, $00, $13, $F0, $09, $F0, $F7, $FE, $14, $EE, $08, $F0, $F4, $FC, $15
.db $EC, $07, $F0, $F2, $F9, $15, $EA, $05, $F1, $EF, $F6, $16, $E9, $02, $F2, $ED
.db $F4, $15, $E7, $00, $F4, $EB, $F1, $15, $E6, $FD, $F5, $E8, $EE, $14, $E5, $FA
.db $F8, $E6, $EB, $13, $E5, $F7, $FA, $E4, $E8, $11, $E5, $F4, $FD, $E3, $E5, $0F
.db $E5, $F1, $00, $E1, $E3, $0D, $E6, $ED, $03, $E0, $E0, $0A, $E7, $EA, $07, $E0
.db $DE, $07, $E9, $E6, $0B, $DF, $DD, $04, $EB, $E3, $0E, $DF, $DB, $00, $EE, $E0
.db $12, $E0, $DA, $FC, $F1, $DD, $16, $E1, $DA, $F8, $F4, $DB, $1A, $E3, $DA, $F4
.db $F8, $D8, $1E, $E5, $DA, $EF, $FC, $D7, $22, $E8, $DB, $EB, $00, $D5, $25, $EB
.db $DC, $E6, $05, $D4, $28, $EE, $DE, $E2, $09, $D4, $2B, $F2, $E1, $DE, $0E, $D4
.db $2D, $F6, $E4, $D9, $13, $D5, $2F, $FB, $E8, $D6, $18, $D6, $31, $00, $EC, $D2
.db $1D, $D8, $32, $05, $F0, $CF, $22, $DA, $32, $0B, $F5, $CD, $27, $DD, $32, $10
.db $FA, $CB, $2B, $E0, $31, $16, $00, $C9, $2F, $E5, $2F, $1B, $06, $C8, $33, $E9
.db $2D, $21, $0C, $C8, $36, $EE, $2B, $26, $12, $C8, $39, $F4, $27, $2B, $18, $CA
.db $3B, $FA, $23, $30, $1E, $CB, $3D, $00, $1E, $35, $24, $CE, $3E, $06, $19, $39
.db $2A, $D1, $3E, $0D, $14, $3C, $30, $D5, $3D, $14, $0D, $3F, $35, $D9, $3C, $1B
.db $07, $41, $3A, $DF, $3A, $21, $00, $43, $3E, $E4, $37, $28, $F9, $44, $42, $EB
.db $33, $2E, $F2, $44, $45, $F1, $2F, $34, $EA, $43, $47, $F9, $2A, $3A, $E3, $41
.db $49, $00, $24, $3F, $DC, $3F

;____________________________________________________________________________[$258B]___

;end sequence screens?
_LABEL_258B_133:
	ld   a, (RAM_VDPREGISTER_1)
	and  %10111111
	ld   (RAM_VDPREGISTER_1), a
	
	res  0, (iy+vars.flags0)
	call wait
	
	xor  a
	ld   (RAM_SCROLL_HORIZONTAL), a
	ld   (RAM_SCROLL_VERTICAL), a		;vertical scroll
	
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
	ld      (RAM_PAGE_1),a
	
	;map 3 screen (end of game)
	ld      hl,$6830
	ld      bc,$0179
	ld      de,$3800
	xor     a
	ld      (RAM_TEMP1),a
	call    decompressScreen
	
	ld      a,(RAM_VDPREGISTER_1)
	or      $40
	ld      (RAM_VDPREGISTER_1),a
	
	res     0,(iy+vars.flags0)
	call    wait
	
	ld      a,1
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	ld      a,($d27f)
	cp      $06
	jp      c,+
	ld      b,$3c
	
-	push    bc
	
	res     0,(iy+vars.flags0)
	call    wait
	
	ld      hl,$d000
	ld      c,$70
	ld      b,$60
	ld      de,_2825
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	pop     bc
	djnz    -
	
	ld      a,index_music_allEmeralds
	rst     $18			;`playMusic`
	
	ld      hl,$241d
	ld      b,$3d
	
--	push    bc
	ld      c,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),c
	res     0,(iy+vars.flags0)
	call    wait
	ld      de,$d000
	ld      (RAM_SPRITETABLE_CURRENT),de
	ld      b,$03
	
-	push    bc
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
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
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
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	pop     hl
	pop     bc
	djnz    -
	
	pop     bc
	djnz    --
	ld      hl,_2047
	call    _b60
	ld      (iy+vars.spriteCount),$00
	
	ld      a,5
	ld      (SMS_PAGE_1),a
	ld      (RAM_PAGE_1),a
	
	;UNKNOWN
	ld      hl,$69a9
	ld      bc,$0145
	ld      de,$3800
	xor     a
	ld      (RAM_TEMP1),a
	call    decompressScreen
	
	ld      hl,_2828
	call    _aae
	
+	ld      bc,$00f0
	call    _2745
	call    _155e			;Act Complete screen?
	
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
	ld      (RAM_PAGE_1),a
	
	;credits screen
	ld      hl,$6c61
	ld      bc,$0189
	ld      de,$3800
	xor     a
	ld      (RAM_TEMP1),a
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
	ld      hl,S1_Credits_Palette
	call    _b50
	
	ld      a,index_music_ending
	rst     $18			;`playMusic`
	
	xor     a
	ld      (RAM_TEMP1),a
	ld      hl,S1_Credits_Text
	call    _2795
	
_2715:					;infinite loop!?
	jp      _2715

;____________________________________________________________________________[$2718]___

_2718:
	push    af
	push    hl
	push    de
	push    bc
--	push    bc
	
	res     0,(iy+vars.flags0)
	call    wait
	
	ld      (iy+vars.spriteCount),$00
	ld      hl,$d000
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      hl,$d322
	ld      b,$04
	
-	push    bc
	call    _275a
	pop     bc
	djnz    -
	
	pop     bc
	dec     bc
	ld      a,b
	or      c
	jr      nz,--
	
	pop     bc
	pop     de
	pop     hl
	pop     af
	ret

;____________________________________________________________________________[$2745]___

_2745:
	push    bc
	ld      a,(iy+vars.spriteCount)
	
	res     0,(iy+vars.flags0)
	call    wait
	
	ld      (iy+vars.spriteCount),a
	
	pop     bc
	dec     bc
	ld      a,b
	or      c
	jr      nz,_2745
	
	ret

;____________________________________________________________________________[$275A]___

_275a:
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	inc     (hl)
	ld      a,(de)
	cp      (hl)
	jr      nc,+
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
	jr      nz,+
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
	
+	inc     hl
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
	call    processSpriteLayout
	pop     hl
	ret

;____________________________________________________________________________[$2795]___

_2795:
	ld      de,$d2be
	ldi     
	ldi     
	inc     de
	ld      a,$ff
	ld      (de),a
__	ld      a,(hl)
	inc     hl
	cp      $ff
	ret     z
	cp      $fe
	jr      z,_2795
	cp      $fc
	jr      z,++
	cp      $fd
	jr      nz,+
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	call    _2718
	jr      _b
	
+	push    hl
	ld      ($d2c0),a
	ld      bc,$0008
	call    _2718
	ld      hl,$d2be
	call    print
	ld      hl,$d2be
	inc     (hl)
	pop     hl
	jr      _b
	
++	ld      b,(hl)
	inc     hl
	push    hl
---	push    bc
	ld      bc,$000c
	call    _2718
	ld      de,$3aa4
	ld      hl,$3ae4
	ld      b,$09
	
--	push    bc
	push    hl
	push    de
	ld      b,$14
	
-	di      
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
	djnz    -
	
	pop     de
	pop     hl
	ld      bc,$0040
	add     hl,bc
	ex      de,hl
	add     hl,bc
	ex      de,hl
	pop     bc
	djnz    --
	
	pop     bc
	djnz    ---
	pop     hl
	jp      _b

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

S1_Credits_Text:			;[$2905]

.ASCIITABLE
	MAP " " = $EB
	MAP "A" = $1E
	MAP "B" = $1F
	MAP "C" = $2E
	MAP "D" = $2F
	MAP "E" = $3E
	MAP "F" = $3F
	MAP "G" = $4E
	MAP "H" = $4F
	MAP "I" = $5E
	MAP "J" = $5F
	MAP "K" = $6E
	MAP "L" = $6F
	MAP "M" = $7E
	MAP "N" = $7F
	MAP "O" = $8E
	MAP "P" = $8F
	MAP "Q" = $9E
	MAP "R" = $9F
	MAP "S" = $AE
	MAP "T" = $AF
	MAP "U" = $BE
	MAP "V" = $BF
	MAP "W" = $CE
	MAP "X" = $CF
	MAP "Y" = $DE
	MAP "Z" = $DF
	MAP "@" = $AB
.ENDA

.db      $14, $03 ;, $AE, $9E, $7F, $5E, $2E			;SONIC
.asc "SQNIC"
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

S1_Credits_Palette:			;[$2AD6]
.db $35, $3D, $1F, $39, $06, $1B, $01, $34, $2B, $10, $03, $14, $2A, $1F, $00, $3F
.db $35, $3D, $1F, $39, $06, $1B, $01, $34, $2B, $10, $03, $14, $2A, $1F, $00, $3F

;____________________________________________________________________________[$2AF6]___

S1_Object_Pointers:
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
.dw _9b75				;#13: UNKNOWN
.dw _9be8				;#14: UNKNOWN
.dw _9c70				;#15: UNKNOWN
.dw _9c8e				;#16: flame thrower (Scrap Brain)
.dw _9dfa				;#17: door - one way left (Scrap Brain)
.dw _9f62				;#18: door - one way right (Scrap Brain)
.dw _a025				;#19: door (Scrap Brain)
.dw _a0e8				;#1A: electric sphere (Scrap Brain)
.dw _a1aa				;#1B: badnick - ball hog (Scrap Brain)
.dw _a33c				;#1C: UNKNOWN (ball from ball hog?)
.dw _a3f8				;#1D: switch
.dw _a4ab				;#1E: switch door
.dw _a551				;#1F: badnick - caterkiller
.dw _96f8				;#20: UNKNOWN
.dw _9afb				;#21: moving bumper (Special Stage)
.dw _a7ed				;#22: boss (Scrap Brain)
.dw _7699				;#23: free animal - rabbit
.dw _7594				;#24: free animal - bird
.dw _732c				;#25: capsule
.dw _7cf6				;#26: badnick - chopper
.dw _7e02				;#27: log - vertical (Jungle)
.dw _7e9b				;#28: log - horizontal (Jungle)
.dw _7ee6				;#29: log - floating (Jungle)
.dw _96a8				;#2A: UNKNOWN
.dw _8218				;#2B: UNKNOWN
.dw _8053				;#2C: boss (Jungle)
.dw _82e6				;#2D: badnick - yadrin (Bridge)
.dw _83c1				;#2E: UNKNOWN
.dw _94a5				;#2F: UNKNOWN
.dw _a9c7				;#30: meta - clouds (Sky Base)
.dw _aa6a				;#31: propeller (Sky Base)
.dw _ab21				;#32: badnick - bomb (Sky Base)
.dw _ad6c				;#33: canon (Sky Base)
.dw _ae35				;#34: UNKNOWN
.dw _ae88				;#35: badnick - unidos (Sky Base)
.dw _b0f4				;#36: UNKNOWN
.dw _b16c				;#37: rotating turret (Sky Base)
.dw _b297				;#38: flying platform (Sky Base)
.dw _b398				;#39: moving spiked wall (Sky Base)
.dw _b46d				;#3A: fixed turret (Sky Base)
.dw _b50e				;#3B: flying platform - up/down (Sky Base)
.dw _8837				;#3C: badnick - jaws (Labyrinth)
.dw _88fb				;#3D: spike ball (Labyrinth)
.dw _8af6				;#3E: spear (Labyrinth)
.dw _8c16				;#3F: fire ball head (Labyrinth)
.dw _8d48				;#40: meta - water line position
.dw _8e56				;#41: bubbles (Labyrinth)
.dw _8eca				;#42: UNKNOWN
.dw _8f6c				;#43: NO-CODE
.dw _8f6d				;#44: badnick - burrobot
.dw _90c0				;#45: platform - float up (Labyrinth)
.dw _bb84				;#46: boss - electric beam (Sky Base)
.dw _bcdf				;#47: UNKNOWN
.dw _8496				;#48: boss (Bridge)
.dw _9267				;#49: boss (Labyrinth)
.dw _b634				;#4A: boss (Sky Base)
.dw _7aa7				;#4B: trip zone (Green Hill)
.dw _9866				;#4C: Flipper (Special Stage)
.dw $0000				;#4D: RESET!
.dw _866c				;#4E: balance (Bridge)
.dw $0000				;#4F: RESET!
.dw _7aed				;#50: flower (Green Hill)
.dw _5d2f				;#51: monitor - checkpoint
.dw _5d80				;#52: monitor - continue
.dw _bdf9				;#53: final animation
.dw _bf4c				;#54: all emeralds animation
.dw _7b95				;#55: "make sonic blink"

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

;____________________________________________________________________________[$2E5A]___
;update HUD?

_2e5a:
	;do not update the Sonic sprite frame
	res     7,(iy+vars.timeLightningFlags)
	
	ld      hl,_2e55
	ld      de,$d2be
	ld      bc,$0005
	ldir
	
	ld      a,(RAM_LIVES)
	cp      9			;9 lives?
	jr      c,+			;if more than 9 lives,
	ld      a,9			;we will display as 9 lives
	
+	add     a,a			
	add     a,$80			
	ld      ($d2c1),a
	
	ld      c,$10
	ld      b,172			;Y-position of lives display
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	
	;show rings?
	bit     2,(iy+vars.scrollRingFlags)
	call    nz,_2ee6
	
	;show time?
	bit     5,(iy+vars.timeLightningFlags)
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
	bit     6,(iy+vars.scrollRingFlags)
	jr      z,+
	ld      de,$0080
+	ld      a,(hl)
	inc     hl
	or      (hl)
	call    z,_311a
	
	bit     0,(iy+vars.scrollRingFlags)
	call    z,_2f66
	
	ld      hl,$0000
	ld      ($d267),hl
	ld      ($d269),hl
	ld      ($d26b),hl
	ld      ($d26d),hl
	call    _31e6
	call    _329b
	ret

;____________________________________________________________________________[$2EE6]___

_2ee6:
	ld      a,(RAM_RINGS)
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
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      de,_2e52
	call    _LABEL_35CC_117
	ld      c,$28
	ld      b,$00
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ret

;____________________________________________________________________________[$2F1F]___

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
	ld      a,(RAM_CURRENT_LEVEL)
	cp      28
	jr      c,+
	
	ld      c,$70
	ld      b,$38
	
+	ld      hl,(RAM_SPRITETABLE_CURRENT)
	ld      de,$d2be
	call    _LABEL_35CC_117
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ret

;____________________________________________________________________________[$2F66]___

_2f66:
	bit     6,(iy+vars.timeLightningFlags)
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
	jr      c,+++
	
	ld      a,h
	and     a
	jr      nz,+
	
	ld      a,l
	cp      $09
	jr      c,++
	
+	ld      hl,$0008
++	bit     3,(iy+vars.scrollRingFlags)
	jr      nz,_f
	bit     5,(iy+vars.scrollRingFlags)
	jr      z,+
	ld      hl,$0001
+	ex      de,hl
	ld      hl,($d25a)
	and     a
	sbc     hl,de
	jr      c,_f
	ld      ($d25a),hl
	jp      _f
	
+++	ld      bc,($d261)
	ld      hl,($d25a)
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,_f
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      a,h
	and     a
	jr      nz,+
	ld      a,l
	cp      $09
	jr      c,++	
+	ld      hl,$0008
++	bit     3,(iy+vars.scrollRingFlags)
	jr      nz,_f
	bit     5,(iy+vars.scrollRingFlags)
	jr      z,+
	ld      hl,$0001
+	ld      de,($d25a)
	add     hl,de
	jr      c,_f
	ld      ($d25a),hl
__	ld      hl,($d25a)
	ld      de,(RAM_LEVEL_CROPLEFT)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      ($d25a),de
	jr      ++
	
+	ld      hl,($d25a)
	ld      de,($d275)
	and     a
	sbc     hl,de
	jr      c,++
	ld      ($d25a),de
++	bit     6,(iy+vars.scrollRingFlags)
	call    nz,_3164
	ld      bc,($d263)
	ld      de,($d401)
	ld      hl,($d25d)
	bit     6,(iy+vars.scrollRingFlags)
	call    nz,_31cf
	bit     7,(iy+vars.scrollRingFlags)
	call    nz,_31d3
	add     hl,bc
	bit     7,(iy+vars.scrollRingFlags)
	call    z,_31db
	and     a
	sbc     hl,de
	jr      c,+++
	ld      c,$09
	ld      a,h
	and     a
	jr      nz,+
	bit     6,(iy+vars.scrollRingFlags)
	call    nz,_311f
	ld      a,l
	cp      c
	jr      c,++
+	dec     c
	ld      l,c
	ld      h,$00
++	bit     7,(iy+vars.scrollRingFlags)
	jr      z,+
	srl     h
	rr      l
	bit     1,(iy+vars.unknown0)
	jr      nz,+
	ld      hl,$0000
+	ex      de,hl
	ld      hl,($d25d)
	and     a
	sbc     hl,de
	jr      c,_f
	ld      ($d25d),hl
	jp      _f
	
+++	ld      bc,($d265)
	ld      hl,($d25d)
	add     hl,bc
	bit     7,(iy+vars.scrollRingFlags)
	call    z,_31db
	and     a
	sbc     hl,de
	jr      nc,_f
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
	jr      nz,+
	bit     6,(iy+vars.scrollRingFlags)
	call    nz,_311f
	ld      a,l
	cp      c
	jr      c,++
+	dec     c
	ld      l,c
	ld      h,$00
++	bit     4,(iy+vars.scrollRingFlags)
	jr      nz,_f
	ld      de,($d25d)
	add     hl,de
	jr      c,_f
	ld      ($d25d),hl
__	ld      hl,($d25d)
	ld      de,(RAM_LEVEL_CROPTOP)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      ($d25d),de
+	ld      hl,($d25d)
	ld      de,(RAM_LEVEL_EXTENDHEIGHT)
	and     a
	sbc     hl,de
	jr      c,+
	ld      ($d25d),de
+	ret

;____________________________________________________________________________[$311A]___

_311a:
	ld      (hl),d
	dec     hl
	ld      (hl),e
	inc     hl
	ret

;____________________________________________________________________________[$311F]___

_311f:
	ld      c,$08
	ret

;____________________________________________________________________________[$3122]___

_3122:
	ld      de,(RAM_LEVEL_CROPTOP)
	and     a
	sbc     hl,de
	ret     z
	jr      c,+
	inc     de
	ld      (RAM_LEVEL_CROPTOP),de
	ld      (RAM_LEVEL_EXTENDHEIGHT),de
	ret
	
+	dec     de
	ld      (RAM_LEVEL_CROPTOP),de
	ld      (RAM_LEVEL_EXTENDHEIGHT),de
	ret

;____________________________________________________________________________[$3140]___

_3140:
	ld      de,(RAM_LEVEL_CROPLEFT)
	and     a
	sbc     hl,de
	ret     z
	jr      c,+
	inc     de
	ld      (RAM_LEVEL_CROPLEFT),de
	ld      ($d275),de
	ret
	
+	dec     de
	ld      (RAM_LEVEL_CROPLEFT),de
	ld      ($d275),de
	ret

;____________________________________________________________________________[$315E]___

_315e:
	jr      c,+
	inc     de
	ret
	
+	dec     de
	ret

;____________________________________________________________________________[$3164]___
	
_3164:
	ld      hl,($d29d)
	ld      de,(RAM_TIME)
	add     hl,de
	ld      bc,$0200
	ld      a,h
	and     a
	jp      p,+
	neg     
	ld      bc,$fe00
+	cp      $02
	jr      c,+
	ld      l,c
	ld      h,b
+	ld      ($d29d),hl
	ld      c,l
	ld      b,h
	ld      hl,($d25c)
	ld      a,($d25e)
	add     hl,bc
	ld      e,$00
	bit     7,b
	jr      z,+
	ld      e,$ff
+	adc     a,e
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
	jr      z,+
	ld      bc,$ffe0
	and     a
	sbc     hl,bc
	jr      nc,+
	ld      hl,$0002
	ld      (RAM_TIME),hl
	ret
	
+	ld      hl,($d2a2)
	ld      bc,$0020
	and     a
	sbc     hl,bc
	ret     c
	ld      hl,$fffe
	ld      (RAM_TIME),hl
	ret

;____________________________________________________________________________[$31CF]___

_31cf:
	ld      bc,$0020
	ret

;____________________________________________________________________________[$31D3]___

_31d3:
	ld      bc,$0070
	ret
	ld      bc,$0070
	ret

;____________________________________________________________________________[$31DB]___

_31db:
	bit     6,(iy+vars.scrollRingFlags)
	ret     nz
	ld      bc,($d2b7)
	add     hl,bc
	ret

;____________________________________________________________________________[$31E6]___

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
-	ld      a,(de)
	cp      $56
	jp      nc,+++
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
	ld      de,RAM_TEMP1
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ld      hl,($d25a)
	xor     a
	sbc     hl,bc
	jr      nc,+
	ld      l,a
	ld      h,a
	xor     a
+	ld      e,(ix+$02)
	ld      d,(ix+$03)
	sbc     hl,de
	jp      nc,++
	ld      hl,(RAM_TEMP1)
	ld      bc,($d25a)
	add     hl,bc
	xor     a
	sbc     hl,de
	jp      c,++
	ld      hl,($d25d)
	ld      bc,(RAM_TEMP3)
	sbc     hl,bc
	jr      nc,+
	ld      l,a
	ld      h,a
	xor     a
+	ld      e,(ix+$05)
	ld      d,(ix+$06)
	sbc     hl,de
	jp      nc,++
	ld      hl,(RAM_TEMP4)
	ld      bc,($d25d)
	add     hl,bc
	xor     a
	sbc     hl,de
	jp      c,++
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
	djnz    -
	
	ret
	
++	exx     
	
+++	ld      (hl),c
	inc     hl
	ld      (hl),c
	inc     hl
	push    hl
	ld      hl,$001a
	add     hl,de
	ex      de,hl
	pop     hl
	dec     b
	jp      nz,-
	ret    

;____________________________________________________________________________[$392B]___
	
_329b:	;starting from $D37E, read 16-bit numbers until a non-zero one is found,
	 ;or 31 numbers have been read
	ld      hl,$D37E
	ld      b,31
	
-	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	
	;is the value greater than zero?
	ld      a,e
	or      d
	call    nz,doObjectCode
	
	;keep reading memory until either something non-zero is found or we hit $D3BC
	djnz    -
	
	;at this point, $D37E-$D3BD is known to be empty
	
	ld      a,(iy+vars.spriteCount)
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	
	push    af
	push    hl
	
	ld      hl,$d024		;Sonic's sprite table entry
	ld      (RAM_SPRITETABLE_CURRENT),hl
	
	ld      de,$d3fc		;current level's object list
	call    doObjectCode
	
	pop     hl
	pop     af
	
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      (iy+vars.spriteCount),a
	ret

;----------------------------------------------------------------------------[$32C8]---

doObjectCode:
	ld      a,(de)			;get object from the list
	cp      $FF			;ignore object #$FF
	ret     z
	
	push    bc
	push    hl
	
	;transfer DE (address of the object) to IX
	push    de
	pop     ix
	
	;double the index number and put it into DE
	add     a,a
	ld      e,a
	ld      d,$00
	
	;offset into the object pointers table
	ld      hl,S1_Object_Pointers
	add     hl,de
	
	;get the object's pointer address into HL
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	
	;return function?
	ld      de,_32e2
	push    de
	
	;run the object's code
	jp      (hl)
	
;----------------------------------------------------------------------------[$32E2]---

_32e2:
	ld e, (ix+$07)
	ld d, (ix+$08)
	ld c, (ix+$09)
	ld l, (ix+$01)
	ld h, (ix+$02)
	ld a, (ix+$03)
	add hl, de
	adc a, c
	ld (ix+$01), l
	ld (ix+$02), h
	ld (ix+$03), a
	ld e, (ix+$0A)
	ld d, (ix+$0B)
	ld c, (ix+$0C)
	ld l, (ix+$04)
	ld h, (ix+$05)
	ld a, (ix+$06)
	add hl, de
	adc a, c
	ld (ix+$04), l
	ld (ix+$05), h
	ld (ix+$06), a
	bit 5, (ix+$18)
	jp nz, _34e6
	ld b, $00
	ld d, b
	ld e, (ix+$0E)
	srl e
	bit 7, (ix+$08)
	jr nz, +
	ld c, (ix+$0D)
	ld hl, $411E
	jp ++

+	ld c, $00
	ld hl, $4020
++	ld (RAM_TEMP3), bc
	res     6,(ix+$18)
	push    de
	push    hl
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,(RAM_LEVEL_SOLIDITY)
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
	ld      (RAM_TEMP6),a
	pop     hl
	pop     de
	and     $3f
	jp      z,+++
	ld      a,(RAM_TEMP6)
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
	jp      z,+++
	ld      e,a
	and     a
	jp      p,+
	ld      d,$ff
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,(RAM_TEMP3)
	add     hl,bc
	bit     7,(ix+$09)
	jr      nz,+
	and     a
	jp      m,++
	ld      a,l
	and     $1f
	cp      e
	jr      nc,++
	jp      +++
	
+	and     a
	jp      m,++
	ld      a,l
	and     $1f
	cp      e
	jr      nc,+++
++	set     6,(ix+$18)
	ld      a,l
	and     $e0
	ld      l,a
	add     hl,de
	and     a
	sbc     hl,bc
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,(RAM_TEMP6)
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
	jr      z,+
	dec     a
	dec     b
+	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	add     hl,bc
	adc     a,(ix+$0c)
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
+++	ld      b,$00
	ld      d,b
	bit     7,(ix+$0b)
	jr      nz,+
	ld      c,(ix+$0d)
	srl     c
	ld      e,(ix+$0e)
	ld      hl,$448a		;data?
	jp      ++
	
+	ld      c,(ix+$0d)
	srl     c
	ld      e,$00
	ld      hl,$41ec		;data?
++	ld      (RAM_TEMP3),de
	res     7,(ix+$18)
	push    bc
	push    hl
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,(RAM_LEVEL_SOLIDITY)
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
	ld      (RAM_TEMP6),a
	pop     hl
	pop     bc
	and     $3f
	jp      z,_34e6
	ld      a,(RAM_TEMP6)
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
	jp      p,+
	ld      b,$ff
+	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,(RAM_TEMP3)
	add     hl,de
	bit     7,(ix+$0c)
	jr      nz,+
	and     a
	jp      m,++
	ld      a,l
	and     $1f
	exx     
	ld      hl,(RAM_TEMP6)
	ld      h,$00
	ld      de,$3ff0		;data?
	add     hl,de
	add     a,(hl)
	exx     
	cp      c
	jr      c,_34e6
	set     7,(ix+$18)
	jp      ++
	
+	and     a
	jp      m,++
	ld      a,l
	and     $1f
	exx     
	ld      hl,(RAM_TEMP6)
	ld      h,$00
	ld      de,$3ff0		;data?
	add     hl,de
	add     a,(hl)
	exx     
	cp      c
	jr      nc,_34e6
++	ld      a,l
	and     $e0
	ld      l,a
	add     hl,bc
	and     a
	sbc     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      a,(RAM_TEMP6)
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
	jr      z,+
	dec     a
	dec     b
+	ld      l,(ix+$07)
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
	call    nz,processSpriteLayout
	
	pop     hl
	pop     bc
	ret

;____________________________________________________________________________[$350F]___
;process sprite layout data?

processSpriteLayout:
;HL : X-position
;D  : ?? (some kind of control flag)
; E : Y-position
;BC : address to a sprite layout

	;store the X-position of the sprite for aligning the rows
	ld   (RAM_TEMP6), hl
	
	;copy BC (address of a sprite layout) to its shadow value BC'
	push bc
	exx
	pop  bc
	exx
	
	;--- rows ---------------------------------------------------------------------
	;there will be 3 rows of double-high (16px) sprites
	ld   b, $00
	ld   c, $03
	
--	exx				;switch to BC/DE/HL shadow values
	
	ld   hl, (RAM_TEMP6)		;get the starting X-position
					 ;(original HL parameter)
	
	;if a row begins with $FF, the data ends early
	 ;begin a row with $FE to provide a space without ending the data early
	
	ld   a, (bc)			;get a byte from the sprite layout data
	exx				;switch to original BC/DE/HL values
	cp   $FF			;is the byte $FF?
	ret  z				;if so leave
	
	;DE is the Y-position, but if D is $FF then something else unknown happens
	
	ld   a, d			;check the D parameter
	cp   $FF			;if D is not $FF
	jr   nz, +			;then skip ahead a little
	
	ld   a, e			;check the E parameter
	cp   $F0			;if it's less than $F0,
	jr   c, +++			;then skip ahead
	jp   ++
	
+	and  a				;is the sprite byte 0?
	jr   nz, +++
	
	;exit if the row Y-position is below the screen
	ld   a, e
	cp   192
	ret  nc
	
	;--- columns ------------------------------------------------------------------
++	;begin 6 columns of single-width (8px) sprites
	ld   b, $06
	
-	exx				;switch to BC/DE/HL shadow values
	
	;has the X-position gone over 255?
	ld   a, h			;check the H parameter
	and  a				;is it >0? i.e. HL = $0100
	jr   nz, +			;if so skip
	
	ld   a, (bc)			;check the current byte of the layout data
	cp   $FE			;is it >= than $FE?
	jr   nc, +			;if so, skip
	
	;get the address of the sprite table entry
	ld   de, (RAM_SPRITETABLE_CURRENT)	
	ld   a, l			;take the current X-position
	ld   (de), a			;and set the sprite's X-position
	inc  e				
	exx
	ld   a, e			;get the current Y-position
	exx
	ld   (de), a			;set the sprite's Y-position 
	inc  e
	ld   a, (bc)			;read the layout byte
	ld   (de), a			;set the sprite index number
	
	;move to the next sprite table entry
	inc  e
	ld   (RAM_SPRITETABLE_CURRENT), de	
	inc  (iy+vars.spriteCount)	;increase the number of sprites to draw
	
	;move across 8 pixels
+	inc  bc
	ld   de, $0008
	add  hl, de
	
	;return B to the column count and decrement
	exx
	djnz -
	
	;move down 16-pixels
	ld   a, c
	ex   de, hl
	ld   c, 16
	add  hl, bc
	ex   de, hl
	
	;any rows remaining?
	ld   c, a
	dec  c
	jr   nz, --
	ret
	
	;------------------------------------------------------------------------------
	;need to work this out (when D is $FF)
+++	exx
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
	jr   nz, --
	
	ret

;____________________________________________________________________________[$3581]___

_3581:
	ld      hl,(RAM_TEMP3)
	ld      bc,(RAM_TEMP6)
	add     hl,bc
	ld      bc,($d25d)
	and     a
	sbc     hl,bc
	ex      de,hl
	ld      hl,(RAM_TEMP1)
	ld      bc,(RAM_TEMP4)
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
	jr      nz,+
	ld      a,e
	cp      $f0
	ret     c
	jp      ++
	
+	and     a
	ret     nz
	ld      a,e
	cp      $c0
	ret     nc
++	ld      h,c
	ld      bc,(RAM_SPRITETABLE_CURRENT)
	ld      a,l
	ld      (bc),a
	inc     c
	ld      a,e
	ld      (bc),a
	inc     c
	ld      a,h
	ld      (bc),a
	inc     c
	ld      (RAM_SPRITETABLE_CURRENT),bc
	inc     (iy+vars.spriteCount)
	ret

;____________________________________________________________________________[$35CC]___

_LABEL_35CC_117:
;e.g.
; C : $10
;B  : 172
;HL : (RAM_SPRITETABLE_CURRENT)
;DE : $D2BE	: $A0, $A2, $A4, ($80 + RAM_LIVES * 2), $FF
	ld   a, (de)
	cp   $FF
	ret  z
	
	cp   $FE
	jr   z, +
	
	ld   (hl), c
	inc  l
	ld   (hl), b
	inc  l
	ld   (hl), a
	inc  l
	inc  (iy+vars.spriteCount)
	
+	inc  de
	ld   a, c
	add  a, $08
	ld   c, a
	jp   _LABEL_35CC_117

;____________________________________________________________________________[$35E5]___

_35e5:
	bit     0,(iy+vars.scrollRingFlags)
	ret     nz
	bit     0,(iy+vars.unknown0)
	jp      nz,_36be
	ld      a,($d414)
	rrca    
	jp      c,_36be
	and     $02
	jp      nz,_36be

;----------------------------------------------------------------------------[$35FD]---
_35fd:
	bit     0,(iy+vars.flags9)
	ret     nz
	bit     6,(iy+vars.flags6)
	ret     nz
	bit     0,(iy+vars.unknown0)
	ret     nz
	bit     5,(iy+vars.flags6)
	jr      nz,_367e
	ld      a,(RAM_RINGS)
	and     a
	jr      nz,_3644

;----------------------------------------------------------------------------[$3618]---
_3618:
	set     0,(iy+vars.scrollRingFlags)
	ld      hl,$d414
	set     7,(hl)
	ld      hl,$fffa
	xor     a
	ld      ($d406),a
	ld      ($d407),hl
	ld      a,$60
	ld      ($d287),a
	res     6,(iy+vars.flags6)
	res     5,(iy+vars.flags6)
	res     6,(iy+vars.flags6)
	res     0,(iy+vars.unknown0)
	
	ld      a,index_music_death
	rst     $18			;`playMusic`
	
	ret

_3644:
	xor     a
	ld      (RAM_RINGS),a
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
	jr      z,+
	ld      de,$fffe
+	ld      ($d406),a
	ld      ($d407),de
	bit     1,(hl)
	jr      z,+
	ld      a,(hl)
	or      $12
	ld      (hl),a
	xor     a
	ld      de,$0002
	jr      ++
	
+	res     1,(hl)
	xor     a
	ld      de,$fffe
++	ld      ($d403),a
	ld      ($d404),de
	res     5,(iy+vars.flags6)
	set     6,(iy+vars.flags6)
	ld      (iy+vars.joypad),$ff
	ld      a,$11
	rst     $28			;`playSFX`
	ret

;----------------------------------------------------------------------------[$36BE]---
_36be:
	ld      (ix+$00),$0a
	ld      a,(RAM_TEMP1)
	ld      e,a
	ld      d,$00
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,(RAM_TEMP2)
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
	rst     $28			;`playSFX`
	ld      de,$0100
	ld      c,$00
	call    _39d8
	ret

;____________________________________________________________________________[$36F9]___

_36f9:
	ld      a,(RAM_LEVEL_FLOORWIDTH)
	cp      $80
	jr      z,+
	cp      $40
	jr      z,++
	cp      $20
	jr      z,+++
	cp      $10
	jr      z,++++
	jp      +++++
	
+	ld      l,(ix+$05)
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
	
++	ld      l,(ix+$05)
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
	
+++	ld      l,(ix+$05)
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
	
++++	ld      l,(ix+$05)
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
	
+++++	ld      l,(ix+$05)
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

;____________________________________________________________________________[$37E0]___
;copy the current Sonic animation frame into the sprite data

updateSonicSpriteFrame:
	ld   de, (RAM_SONIC_CURRENT_FRAME)
	ld   hl, (RAM_SONIC_PREVIOUS_FRAME)
	
	and  a
	sbc  hl, de
	ret  z
	
	ld   hl, $3680			;location in VRAM of the Sonic sprite
	ex   de, hl
	
	;I can't find an instance where bit 0 of IY+$06 is set,
	 ;this may be dead code
	bit  0, (iy+vars.flags6)
	jp   nz, +
	
	;------------------------------------------------------------------------------
	ld   a, e			;$80
	out  (SMS_VDP_CONTROL), a
	ld   a, d			;$36
	or   %01000000
	out  (SMS_VDP_CONTROL), a
	
	xor  a				;set A to 0
	ld   c, SMS_VDP_DATA
	ld   e, 24
	
	;by nature of the way the VDP stores image colours across bit-planes, and that
	 ;the Sonic sprite only uses palette indexes <8, the fourth byte for a tile
	 ;row is always 0. this is used as a very simple form of compression on the
	 ;Sonic sprites in the ROM as the fourth byte is excluded from the data
-	outi
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
	jp   nz, -
	
	ld   hl, (RAM_SONIC_CURRENT_FRAME)
	ld   (RAM_SONIC_PREVIOUS_FRAME), hl
	ret
	
	;------------------------------------------------------------------------------
	;adds 285 to the frame address. purpose unknown...
+	ld   bc, $011D
	add  hl, bc
	
	ld   a, e
	out  (SMS_VDP_CONTROL), a
	ld   a, d
	or   %01000000
	out  (SMS_VDP_CONTROL), a
	
	exx
	push bc
	ld   b, $18
	exx
	ld   de, $FFFA
	ld   c, $BE
	xor  a
	
-	outi
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
	jp   nz, -
	
	exx
	pop  bc
	exx
	ld   hl, (RAM_SONIC_CURRENT_FRAME)
	ld   (RAM_SONIC_PREVIOUS_FRAME), hl
	ret

;____________________________________________________________________________[$3879]___

updateRingFrame:
	ld      de,(RAM_RING_CURRENT_FRAME)
	ld      hl,(RAM_RING_PREVIOUS_FRAME)
	
	and     a
	sbc     hl,de
	ret     z
	
	ld      hl,$1f80		;location in VRAM of the ring graphics
	ex      de,hl
	di      
	ld      a,e
	out     (SMS_VDP_CONTROL),a
	ld      a,d
	or      %01000000
	out     (SMS_VDP_CONTROL),a
	ld      b,$20
	
-	ld      a,(hl)
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
	djnz    -
	
	ei      
	ld      hl,(RAM_RING_CURRENT_FRAME)
	ld      (RAM_RING_PREVIOUS_FRAME),hl
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
	
	xor  a				;set A to 0
	sbc  hl, de			;is DE > HL?
	ret  c
	
	or   h				;is H > 0?
	ret  nz
	
	ld   a, l
	cp   $08			;is L < 8?
	ret  c
	
	ld   d, a
	ld   a, (RAM_SCROLL_HORIZONTAL)
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
	ld   a, (RAM_SCROLL_VERTICAL)
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
	jr   c, +
	sub  $1C
+	ld   l, a
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
	or   %01000000
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
	ld   a, (RAM_TEMP6)
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
	ld   a, (RAM_TEMP7)
	ld   c, a
	add  hl, bc
	ex   de, hl
	ld   a, ($D40A)
	ld   c, a
	add  hl, bc
	xor  a
	sbc  hl, de
	ret

;____________________________________________________________________________[$39AC]___

_39ac:
	ld      c,a
	ld      a,(RAM_RINGS)
	add     a,c
	ld      c,a
	and     $0f
	cp      $0a
	jr      c,+
	ld      a,c
	add     a,$06
	ld      c,a
+	ld      a,c
	cp      $a0
	jr      c,+
	sub     $a0
	ld      (RAM_RINGS),a
	ld      a,(RAM_LIVES)
	inc     a
	ld      (RAM_LIVES),a
	ld      a,$09
	rst     $28			;`playSFX`
	ret
	
+	ld      (RAM_RINGS),a
	ld      a,$02
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$39D8]___
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
	ld      hl,RAM_LIVES
	inc     (hl)
	ld      a,$09
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$3A03]___

_3a03:
	bit     0,(iy+vars.scrollRingFlags)
	ret     nz	
	ld      hl,$d2d0
	bit     0,(iy+vars.timeLightningFlags)
	jr      nz,++
	ld      a,(hl)
	inc     a
	cp      $3c
	jr      c,+
	xor     a
+	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	adc     a,$00
	daa     
	cp      $60
	jr      c,+
	xor     a
+	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	adc     a,$00
	daa     
	cp      $10
	jr      c,+
	push    hl
	call    _3618
	pop     hl
	xor     a
+	ld      (hl),a
	ret
	
++	ld      a,(hl)
	inc     a
	cp      $3c
	jr      c,+
	xor     a
+	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	sbc     a,$00
	daa     
	cp      $60
	jr      c,+
	ld      a,$59
+	ld      (hl),a
	dec     hl
	ccf     
	ld      a,(hl)
	sbc     a,$00
	daa     
	cp      $60
	jr      c,+
	ld      a,$01
	ld      ($d289),a
	set     2,(iy+vars.flags9)
	xor     a
+	ld      (hl),a
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
.ORG $0000

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
	res     1,(iy+vars.unknown0)
	
	bit     7,(ix+$18)
	call    nz,_4e88
	
	;flag to update the Sonic sprite frame
	set     7,(iy+vars.timeLightningFlags)
	
	bit     0,(iy+vars.scrollRingFlags)
	jp      nz,_543c
	
	ld      a,($d412)
	and     a
	call    nz,_4ff0
	
	res     5,(ix+$18)
	
	bit     6,(iy+vars.flags6)
	call    nz,_510a
	
	ld      a,($d28c)
	and     a
	call    nz,_568f
	
	bit     0,(iy+vars.timeLightningFlags)
	call    nz,_5100
	
	bit     0,(iy+vars.unknown0)
	call    nz,_4ff5
	
	bit     4,(ix+$18)
	call    nz,_5009
	
	ld      a,($d28b)
	and     a
	call    nz,_5285
	
	ld      a,($d28a)
	and     a
	jp      nz,_5117
	
	bit     6,(iy+vars.unknown0)
	jp      nz,_5193
	
	bit     7,(iy+vars.unknown0)
	call    nz,_529c
	
	bit     4,(ix+$18)
	jp      z,+
	
	ld      hl,_4ddd
	ld      de,RAM_TEMP1
	ld      bc,$0009
	ldir    
	
	ld      hl,$0100
	ld      ($d240),hl
	ld      hl,$fd80
	ld      ($d242),hl
	ld      hl,$0010
	ld      ($d244),hl
	jp      +++
	
+	ld      a,(ix+$15)
	and     a
	jr      nz,++
	
	bit     0,(iy+vars.timeLightningFlags)
	jr      nz,+
	
-	ld      hl,_4dcb
	ld      de,RAM_TEMP1
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
	jp      +++
	
+	bit     7,(ix+$18)
	jr      nz,-
	
	ld      hl,_4dd4
	ld      de,RAM_TEMP1
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
	jp      +++
	
++	ld      hl,_4de6
	ld      de,RAM_TEMP1
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
+++	bit     1,(iy+vars.joypad)
	call    z,_50c1
	bit     1,(iy+vars.joypad)
	call    nz,_50e3
	ld      a,15
	ld      (SMS_PAGE_2),a
	ld      (RAM_PAGE_2),a
	ld      bc,$000c
	ld      de,$0010
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,(RAM_LEVEL_SOLIDITY)
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
	jr      nc,+
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
	ld      (RAM_PAGE_2),a
	push    de
	jp      (hl)
	
+	ld      hl,($d401)
	ld      de,$0024
	add     hl,de
	ex      de,hl
	ld      hl,(RAM_LEVEL_EXTENDHEIGHT)
	ld      bc,$00c0
	add     hl,bc
	xor     a
	sbc     hl,de
	call    c,_3618
	ld      hl,$0000
	ld      a,(iy+vars.joypad)
	cp      $ff
	jr      nz,+
	ld      de,($d403)
	ld      a,e
	or      d
	jr      nz,+
	ld      a,($d414)
	rlca    
	jr      nc,+
	ld      hl,($d299)
	inc     hl
+	ld      ($d299),hl
	bit     7,(iy+vars.flags6)
	call    nz,_50e8
	ld      (ix+$14),$05
	ld      hl,($d299)
	ld      de,$0168
	and     a
	sbc     hl,de
	call    nc,_5105
	ld      a,(iy+vars.joypad)
	cp      $fe
	call    z,_4edd
	bit     0,(iy+vars.joypad)
	call    nz,_4fd3
	bit     0,(ix+$18)
	jp      nz,_532e
	ld      a,(ix+$0e)
	cp      $20
	jr      z,+
	ld      hl,($d401)
	ld      de,$fff8
	add     hl,de
	ld      ($d401),hl
+	ld      (ix+$0d),$18
	ld      (ix+$0e),$20
	ld      hl,($d403)
	ld      b,(ix+$09)
	ld      c,$00
	ld      e,c
	ld      d,c
	bit     3,(iy+vars.joypad)
	jp      z,_4f01
	bit     2,(iy+vars.joypad)
	jp      z,_4f5c
	ld      a,h
	or      l
	or      b
	jr      z,_4b1b
	ld      (ix+$14),$01
	bit     7,b
	jr      nz,+
	ld      de,(RAM_TEMP4)
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
	ld      de,(RAM_TEMP1)
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
	
+	ld      de,(RAM_TEMP4)
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
	ld      de,(RAM_TEMP1)
	ld      a,($d216)
	ld      (ix+$14),a
_4b1b:
	ld      a,b
	and     a
	jp      m,+
	add     hl,de
	adc     a,c
	ld      c,a
	jp      p,++
	ld      a,($d403)
	or      (ix+$08)
	or      (ix+$09)
	jr      z,++
	ld      c,$00
	ld      l,c
	ld      h,c
	jp      ++
	
+	add     hl,de
	adc     a,c
	ld      c,a
	jp      m,++
	ld      c,$00
	ld      l,c
	ld      h,c
++	ld      a,c
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
	jr      nz,+
	bit     7,(ix+$18)
	jr      z,++
	bit     3,(ix+$18)
	jr      nz,+
	bit     5,(iy+vars.joypad)
	jr      z,++
+	bit     5,(iy+vars.joypad)
	jr      nz,+++
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
	jp      +++++
	
++	res     3,(ix+$18)
	jp      ++++
	
+++	set     3,(ix+$18)
++++	xor     a
	ld      ($d28e),a
_4bac:
	bit     7,h
	jr      nz,+
	ld      a,(RAM_TEMP7)
	cp      h
	jr      z,+++++
	jr      c,+++++
+	ld      de,($d244)
	ld      c,$00
	
+++++	bit     0,(iy+vars.flags6)
	jr      z,+
	
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
+	add     hl,de
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
	jp      p,+
	ld      a,h
	cpl     
	ld      h,a
	ld      a,l
	cpl     
	ld      l,a
	inc     hl
+	ld      de,$0100
	ex      de,hl
	and     a
	sbc     hl,de
	jr      nc,++
	ld      a,($d414)
	and     $85
	jr      nz,++
	bit     7,(ix+$0c)
	jr      z,+
	ld      (ix+$14),$13
	jr      ++
+	ld      (ix+$14),$01
++	ld      bc,$000c
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
	bit     6,(iy+vars.flags6)
	call    nz,_51bc
	bit     2,(iy+vars.unknown0)
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
	
-	ld      h,$00
	ld      l,a
	add     hl,de
	ld      a,(hl)
	and     a
	jp      p,+
	inc     hl
	ld      a,(hl)
	ld      ($d40f),a
	jp      -
	
+	ld      d,a
	ld      bc,sound_update
	bit     1,(ix+$18)
	jr      z,+
	ld      bc,_7000
+	bit     5,(iy+vars.flags6)
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
	ld      (RAM_SONIC_CURRENT_FRAME),hl
	ld      hl,_591d
	
	bit     0,(iy+vars.flags6)
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
	jp      p,+
	neg     
	ld      c,$f0
+	cp      $10
	jr      c,+
	ld      a,c
	ld      ($d404),a
+	ld      c,$10
	ld      a,($d407)
	and     a
	jp      p,+
	neg     
	ld      c,$f0
+	cp      $10
	jr      c,+
	ld      a,c
	ld      ($d407),a
+	ld      de,($d401)
	ld      hl,$0010
	and     a
	sbc     hl,de
	jr      c,+
	add     hl,de
	ld      ($d401),hl
+	bit     7,(iy+vars.flags6)
	call    nz,_5224
	bit     0,(iy+vars.unknown0)
	call    nz,_4e8d
	ld      a,($d2e1)
	and     a
	call    nz,_5231
	ld      a,($d321)
	and     a
	call    nz,_4e51
	bit     1,(iy+vars.flags6)
	jr      nz,++
	ld      hl,(RAM_LEVEL_CROPLEFT)
	ld      bc,$0008
	add     hl,bc
	ex      de,hl
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      ($d3fe),de
	ld      a,($d405)
	and     a
	jp      p,++
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
	jp      ++
	
+	ld      hl,($d275)
	ld      de,$00f8
	add     hl,de
	ex      de,hl
	ld      hl,($d3fe)
	ld      c,$18
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,++
	ex      de,hl
	scf     
	sbc     hl,bc
	ld      ($d3fe),hl
	ld      a,($d405)
	and     a
	jp      m,++
	ld      hl,($d404)
	or      h
	or      l
	jr      z,++
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
++	ld      a,($d414)
	ld      ($d2b9),a
	ld      a,($d410)
	ld      ($d2df),a
	ld      d,$01
	ld      c,$30
	cp      $01
	jr      z,+
	ld      d,$06
	ld      c,$50
	cp      $09
	jr      z,+
	inc     (ix+$13)
	ret
	
+	ld      a,($d2e0)
	ld      b,a
	ld      hl,($d403)
	bit     7,h
	jr      z,+
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
+	srl     h
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

;____________________________________________________________________________[$4DEF]___

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

;____________________________________________________________________________[$4E48]___

_4e48:
	ld      d,a
	ld      bc,_7000
	ret

;____________________________________________________________________________[$4E4D]___

_4e4d:
	ld      hl,$0000
	ret

;____________________________________________________________________________[$4E51]___

_4e51:
	dec     a
	ld      ($d321),a
	ld      hl,($d31d)
	ld      (RAM_TEMP1),hl
	ld      hl,($d31f)
	ld      (RAM_TEMP3),hl
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      hl,$fffe
	ld      (RAM_TEMP6),hl
	cp      $03
	jr      c,+
	ld      a,$b2
	call    _3581
	ld      hl,$0008
	ld      (RAM_TEMP4),hl
	ld      hl,$0002
	ld      (RAM_TEMP6),hl
+	ld      a,$5a
	call    _3581
	ret

;____________________________________________________________________________[$4E88]___

_4e88:
	set     1,(iy+vars.unknown0)
	ret

;____________________________________________________________________________[$4E8D]___

_4e8d:
	ld      hl,($d3fe)
	ld      (RAM_TEMP1),hl
	ld      hl,($d401)
	ld      (RAM_TEMP3),hl
	ld      hl,$d2f3
	ld      a,($d223)
	rrca    
	rrca    
	jr      nc,+
	ld      hl,$d2f7
+	ld      de,RAM_TEMP4
	ldi     
	ldi     
	ldi     
	ldi     
	rrca    
	ld      a,$94
	jr      nc,+
	ld      a,$96
+	call    _3581
	ld      a,($d223)
	ld      c,a
	and     $07
	ret     nz
	ld      b,$02
	ld      hl,$d2f3
	bit     3,c
	jr      z,_f
	ld      hl,$d2f7
__	push    hl
	call    _LABEL_625_57
	pop     hl
	and     $0f
	ld      (hl),a
	inc     hl
	ld      (hl),$00
	inc     hl
	djnz    _b
	ret

;____________________________________________________________________________[$4EDD]___

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
	jr      nz,+
	ld      hl,$002c
	and     a
	sbc     hl,de
	ret     c
+	inc     de
	ld      ($d2b7),de
	ret

_4f01:
	res     1,(ix+$18)
	bit     7,b
	jr      nz,+
	ld      de,(RAM_TEMP1)
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
	
+	set     1,(ix+$18)
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
	ld      de,(RAM_TEMP3)
	ld      c,$00
	jp      nc,_4b1b
	res     1,(ix+$18)
	ld      (ix+$14),$01
	jp      _4b1b
_4f5c:
	set     1,(ix+$18)
	ld      a,l
	or      h
	jr      z,+
	bit     7,b
	jr      z,_4fa6
+	ld      de,(RAM_TEMP1)
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
	ld      de,(RAM_TEMP3)
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

;____________________________________________________________________________[$4FD3]___

_4fd3:
	bit     0,(ix+$18)
	ret     nz
	ld      hl,($d2b7)
	ld      a,h
	or      l
	ret     z
	bit     7,h
	jr      z,+
	inc     hl
	ld      ($d2b7),hl
	ret
	
+	dec     hl
	ld      ($d2b7),hl
	ret

;____________________________________________________________________________[$4FEC]___

_4fec:
	dec     (ix+$15)
	ret

;____________________________________________________________________________[$4FF0]___

_4ff0:
	dec     a
	ld      ($d412),a
	ret

;____________________________________________________________________________[$4FF5]___

_4ff5:
	ld      a,($d223)
	and     $03
	ret     nz
	ld      hl,$d28d
	dec     (hl)
	ret     nz
	res     0,(iy+vars.unknown0)
	
	ld      a,(RAM_LEVEL_MUSIC)
	rst     $18			;`playMusic`
	
	ret

;____________________________________________________________________________[$5009]___

_5009:
	ld      a,(RAM_LEVEL_SOLIDITY)
	cp      $03
	ret     nz
	ld      a,(RAM_CURRENT_LEVEL)
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
	jr      nc,+
	res     5,(iy+vars.flags6)
	res     6,(iy+vars.flags6)
	res     0,(iy+vars.unknown0)
	set     3,(iy+vars.unknown0)
	set     0,(iy+vars.scrollRingFlags)
	ld      a,$c0
	ld      ($d287),a
	
	ld      a,index_music_death
	rst     $18			;`playMusic`
	
	call    _91eb
	call    _91eb
	call    _91eb
	call    _91eb
	xor     a
+	ld      e,a
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
	jr      nz,+
	ld      a,$1a
	rst     $28			;`playSFX`
+	ld      a,($d223)
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

;____________________________________________________________________________[$509D]___

_509d:
	ld      a,$10
	ld      ($d28e),a
	ld      a,$00
	rst     $28			;`playSFX`
	ret

;unreferenced?
_50a6:
	xor     a
	ld      ($d3fd),a
	ld      ($d3fe),de
	ret

;____________________________________________________________________________[$50AF]___

_50af:
	exx     
	ld      hl,($d401)
	ld      ($d2d9),hl
	exx     
	bit     2,(ix+$18)
	ret     z
	res     2,(ix+$18)
	ret

;____________________________________________________________________________[$50C1]___

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
	jr      z,+
	ld      a,$06
	rst     $28			;`playSFX`
+	set     2,(iy+vars.timeLightningFlags)
	ret

;____________________________________________________________________________[$50E3]___

_50e3:
	res     2,(iy+vars.timeLightningFlags)
	ret

;____________________________________________________________________________[$50E8]___

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

;____________________________________________________________________________[$5100]___

_5100:
	set     2,(ix+$18)
	ret

;____________________________________________________________________________[$5105]___

_5105:
	ld      (ix+$14),$0d
	ret

;____________________________________________________________________________[$510A]___

_510a:
	ld      (iy+vars.joypad),$ff
	ld      a,($d414)
	and     $fa
	ld      ($d414),a
	ret

;____________________________________________________________________________[$5117]___
;jumped to here from _48c8 (OBJECT: Sonic)

_5117:
	dec     a
	ld      ($d28a),a
	jr      z,++
	cp      $14
	jr      c,+
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),a
	ld      ($d404),hl
	ld      ($d406),a
	ld      ($d407),hl
	ld      (ix+$14),$0f
	jp      _4c39
	
+	res     1,(ix+$18)
	ld      (ix+$14),$0e
	jp      _4c39
	
++	ld      hl,($d2d5)
	ld      b,(hl)
	inc     hl
	ld      c,(hl)
	inc     hl
	ld      a,(hl)
	and     a
	jr      z,+++
	jp      m,+
	ld      ($d2d3),a
	set     4,(iy+vars.flags6)
	jr      ++	
+	set     2,(iy+$0d)
++	ld      a,$01
	ld      ($d289),a
	ret
	
+++	ld      a,b
	ld      h,$00
	ld      b,$05
	
-	add     a,a
	rl      h
	djnz    -
	
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

;____________________________________________________________________________[$5193]___
;jumped to from _48c8 (OBJECT: Sonic)

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
	res     6,(iy+vars.unknown0)
	set     2,(ix+$18)
	jp      _4c39

;____________________________________________________________________________[$51B3]___

_51b3:
	dec     a
	ld      ($d28c),a
	ld      (ix+$14),$11
	ret

;____________________________________________________________________________[$51BC]___

_51bc:
	ld      (ix+$0d),$1c
	ld      (ix+$14),$10
	bit     7,(ix+$0c)
	ret     nz
	bit     7,(ix+$18)
	ret     z
	res     6,(iy+vars.flags6)
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
	ret

;____________________________________________________________________________[$51DD]___

_51dd:
	ld      a,($d414)
	and     $fa
	ld      ($d414),a
	ld      (ix+$14),$14
	ld      hl,$d2fb
	dec     (hl)
	ret     nz
	res     2,(iy+vars.unknown0)
	ret

;____________________________________________________________________________[$51F3]___

_51f3:
	ld      a,($d412)
	and     a
	ret     nz
	bit     7,(ix+$18)
	ret     z
	ld      a,$03
	rst     $28			;`playSFX`
	ld      a,$3c
	ld      ($d412),a
	ret

;____________________________________________________________________________[$5206]___

_5206:
	ld      a,($d223)
	and     $01
	ret     nz
	ld      d,$18
	ret

;____________________________________________________________________________[$520F]___

_520f:
	ld      hl,_592b
	ret

;____________________________________________________________________________[$5213]___

_5213:
	ld      hl,_5939
	bit     1,(ix+$18)
	ret     z
	ld      hl,_594b
	ret

;____________________________________________________________________________[$521F]___

_521f:
	ld      (ix+$13),$00
	ret

;____________________________________________________________________________[$5224]___

_5224:
	bit     4,(ix+$18)
	ret     z
	ld      a,($d223)
	and     a
	call    z,_91eb
	ret

;____________________________________________________________________________[$5231]___

_5231:
	dec     a
	ld      ($d2e1),a
	cp      $06
	jr      c,+
	cp      $0a
	ret     c
+	ld      a,(iy+vars.spriteCount)
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	push    af
	push    hl
	ld      hl,$d000
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      de,($d25d)
	ld      hl,($d2e4)
	and     a
	sbc     hl,de
	ex      de,hl
	ld      bc,($d25a)
	ld      hl,($d2e2)
	and     a
	sbc     hl,bc
	ld      bc,_526e		;address of sprite layout
	call    processSpriteLayout
	
	pop     hl
	pop     af
	
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      (iy+vars.spriteCount),a
	ret

_526e:
.db $00, $02, $04, $06, $FF, $FF
.db $20, $22, $24, $26, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$5280]___

_5280:
	ld      (ix+$14),$09
	ret

;____________________________________________________________________________[$5285]___

_5285:
	dec     a
	ld      ($d28b),a
	ret     nz
	
	ld      a,(RAM_LEVEL_MUSIC)
	rst     $18			;`playMusic`
	
	ld      c,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),c
	ret

;____________________________________________________________________________[$529C]___

_529c:
	ld      (iy+vars.joypad),$fb
	ld      hl,($d3fe)
	ld      de,$1b60
	and     a
	sbc     hl,de
	ret     nc
	ld      (iy+vars.joypad),$ff
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
	jr      nz,+
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
	
+	bit     1,(iy+$0d)
	jr      nz,+
	dec     (hl)
	jp      nz,_4c39
	set     1,(iy+$0d)
	ld      (hl),$8c
+	ld      (ix+$14),$17
	ld      a,(hl)
	and     a
	jr      z,+
	dec     (hl)
	jp      _4c39
	
+	ld      (ix+$14),$19
	jp      _4c39

;____________________________________________________________________________[$532E]___
;jumped to from _48c8 (OBJECT: Sonic)

_532e:
	ld      a,(ix+$0e)
	cp      $18
	jr      z,+
	ld      hl,($d401)
	ld      de,$0008
	add     hl,de
	ld      ($d401),hl
+	ld      (ix+$0d),$18
	ld      (ix+$0e),$18
	ld      hl,($d403)
	ld      b,(ix+$09)
	ld      c,$00
	ld      e,c
	ld      d,c
	ld      a,h
	or      l
	or      b
	jp      z,++++
	ld      (ix+$14),$09
	bit     2,(iy+vars.joypad)
	jr      nz,++
	bit     1,(iy+vars.joypad)
	jr      z,++
	bit     7,(ix+$18)
	jp      z,+
	bit     7,b
	jr      nz,+++
	res     0,(ix+$18)
	jp      _4fa6
	
+	ld      de,$fff0
	ld      c,$ff
	jp      _4b1b
	
++	bit     3,(iy+vars.joypad)
	jr      nz,+++
	bit     1,(iy+vars.joypad)
	jr      z,+++
	bit     7,(ix+$18)
	jp      z,+
	bit     7,b
	jr      z,+++
	res     0,(ix+$18)
	jp      _4fa6
	
+	ld      de,$0010
	ld      c,$00
	jp      _4b1b
	
+++	ld      de,$0004
	ld      c,$00
	ld      a,b
	and     a
	jp      m,_4b1b
	ld      de,$fffc
	ld      c,$ff
	jp      _4b1b
	
++++	bit     7,(ix+$18)
	jr      z,++
	ld      (ix+$14),$07
	res     0,(ix+$18)
	ld      de,($d2b7)
	bit     7,d
	jr      z,+
	ld      hl,$ffb0
	and     a
	sbc     hl,de
	jp      nc,_4b49
+	dec     de
	ld      ($d2b7),de
	jp      _4b49
	
++	ld      (ix+$14),$09
	push    de
	push    hl
	bit     7,b
	jr      z,++
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
++	ld      de,($d240)
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

;____________________________________________________________________________[$5407]___
;jumped to from _48c8 (OBJECT: Sonic)

_5407:
	bit     7,(ix+$18)
	jr      z,++
	bit     3,(ix+$18)
	jr      nz,+
	bit     5,(iy+vars.joypad)
	jr      z,++
+	bit     5,(iy+vars.joypad)
	jr      nz,+++
	res     0,(ix+$18)
	ld      a,($d403)
	and     $f8
	ld      ($d403),a
	jp      _4b7f
	
++	res     3,(ix+$18)
	jp      _4bac
+++	set     3,(ix+$18)
	jp      _4bac

;____________________________________________________________________________[$543C]___
;jumped to from _48c8 (OBJECT: Sonic)

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
	jr      nc,+
	bit     2,(iy+vars.flags6)
	jr      nz,+
	ld      a,$01
	ld      ($d283),a
	ld      hl,RAM_LIVES
	dec     (hl)
	set     2,(iy+vars.flags6)
	jp      _54aa
	
+	xor     a
	ld      hl,$0080
	bit     3,(iy+vars.unknown0)
	jr      nz,+++
	ld      de,($d406)
	bit     7,d
	jr      nz,+
	ld      hl,$0600
	and     a
	sbc     hl,de
	jr      c,++++
+	ex      de,hl
	ld      b,(ix+$0c)
	ld      a,h
	cp      $80
	jr      nc,+
	cp      $08
	jr      nc,++
+	ld      de,$0030
	ld      c,$00
++	add     hl,de
	ld      a,b
	adc     a,c
+++	ld      ($d406),hl
	ld      ($d408),a
++++	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a

;____________________________________________________________________________[$54AA]___
;jumped to from _48c8 (OBJECT: Sonic)

_54aa:
	ld      (ix+$14),$0b
	bit     3,(iy+vars.unknown0)
	jp      z,_4c39
	ld      (ix+$14),$15
	jp      _4c39

;____________________________________________________________________________[$54BC]___
;referenced by table at _58e5
_54bc:
	bit     7,(iy+vars.flags6)
	ret     nz
	res     4,(ix+$18)
	ret

;____________________________________________________________________________[$54C6]___
;referenced by table at _58e5

_54c6:
	bit     0,(iy+vars.scrollRingFlags)
	jp      z,_35fd
	ret

;____________________________________________________________________________[$54CE]___
;referenced by table at _58e5	

_54ce:
	ld      a,(ix+$02)
	add     a,$0c
	and     $1f
	cp      $1a
	ret     c
	ld      a,($d414)
	rrca    
	jr      c,+
	and     $02
	ret     z
+	ld      l,(ix+$07)
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
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$550F]___
;referenced by table at _58e5

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
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$552D]___
;referenced by table at _58e5

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
	res     6,(iy+vars.flags6)
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f4
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$5556]___
;referenced by table at _58e5

_5556:
	ld      a,(ix+$02)
	add     a,$0c
	and     $1f
	cp      $10
	ret     nc
	res     6,(iy+vars.flags6)
	ld      (ix+$07),$00
	ld      (ix+$08),$08
	ld      (ix+$09),$00
	res     1,(ix+$18)
	ld      a,$04
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$5578]___
;referenced by table at _58e5

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

;____________________________________________________________________________[$5590]___
;referenced by table at _58e5

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

;____________________________________________________________________________[$55A8]___
;referenced by table at _58e5

_55a8:
	bit     4,(ix+$18)
	jr      nz,+
	ld      a,$12
	rst     $28			;`playSFX`
+	set     4,(ix+$18)
	ret

;____________________________________________________________________________[$55B6]___
;referenced by table at _58e5

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
	res     6,(iy+vars.flags6)
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f4
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$55E2]___
;referenced by table at _58e5

_55e2:
	bit     7,(ix+$0c)
	ret     nz
	ld      a,$05
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$55EB]___
;referenced by table at _58e5

_55eb:
	bit     4,(iy+vars.flags6)
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
	
-	ld      a,(hl)
	inc     hl
	cp      e
	jr      nz,+
	ld      a,(hl)
	cp      d
	jr      nz,+
	inc     hl
	ld      ($d2d5),hl
	ld      a,$50
	ld      ($d28a),a
	ld      a,$06
	rst     $28			;`playSFX`
	ret

+	inc     hl
	inc     hl
	inc     hl
	inc     hl
	djnz    -
	
	ret

_5643:
.db $34, $3c, $34, $2f, $00, $19, $3a, $19, $04, $00, $0e, $3a, $00, $00, $16, $1b
.db $32, $00, $00, $17, $2f, $0c, $00, $00, $ff

;____________________________________________________________________________[$565C]___
;referenced by table at _58e5

_565c:
	ld      hl,($d403)
	ld      a,($d405)
	ld      de,$fff8
	add     hl,de
	adc     a,$ff
	ld      ($d403),hl
	ld      ($d405),a
	bit     4,(ix+$18)
	jr      nz,+
	ld      a,$12
	rst     $28			;`playSFX`
+	set     4,(ix+$18)
	ret

;____________________________________________________________________________[$567C]___
;referenced by table at _58e5

_567c:
	xor     a
	ld      hl,$0005
	ld      ($d403),a
	ld      ($d404),hl
	res     1,(ix+$18)
_568a:
	ld      a,$06
	ld      ($d28c),a

;____________________________________________________________________________[$568F]___
;called by _48c8 (OBJECT: Sonic)

_568f:
	ld      a,(iy+vars.joypad)
	or      $0f
	ld      (iy+vars.joypad),a
	ld      hl,$0004
	ld      ($d407),hl
	res     0,(ix+$18)
	res     2,(ix+$18)
	ret

;____________________________________________________________________________[$56A6]___
;referenced by table at _58e5

_56a6:
	xor     a
	ld      hl,$0006
	ld      ($d403),a
	ld      ($d404),hl
	res     1,(ix+$18)
	jr      _568a

;____________________________________________________________________________[$56B6]___
;referenced by table at _58e5

_56b6:
	xor     a
	ld      hl,$fffb
	ld      ($d403),a
	ld      ($d404),hl
	set     1,(ix+$18)
	jr      _568a

;____________________________________________________________________________[$56C6]___
;referenced by table at _58e5

_56c6:
	xor     a
	ld      hl,$fffa
	ld      ($d403),a
	ld      ($d404),hl
	set     1,(ix+$18)
	jr      _568a
	
;____________________________________________________________________________[$56D6]___
;referenced by table at _58e5

_56d6:
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
	jp      p,+
	ld      de,$ffc8
	add     hl,de
	adc     a,$ff
+	ld      ($d406),hl
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
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$5727]___

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
	jr      z,+
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	ld      a,c
	cpl     
	ld      c,a
+	ld      de,$0001
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

;____________________________________________________________________________[$5761]___
;referenced by table at _58e5

_5761:
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f6
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$5771]___
;referenced by table at _58e5

_5771:
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f4
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$5781]___
;referenced by table at _58e5

_5781:
	ld      (ix+$0a),$00
	ld      (ix+$0b),$f2
	ld      (ix+$0c),$ff
	ld      a,$04
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$5791]___
;referenced by table at _58e5

_5791:
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
	jp      m,+
	ld      de,$0100
	ld      c,$00
+	add     hl,de
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
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$57CD]___
;referenced by table at _58e5

_57cd:
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
	jp      p,+
	ld      de,$ffc8
	add     hl,de
	adc     a,$ff
+	ld      ($d406),hl
	ld      ($d408),a
	jp      _57be

;____________________________________________________________________________[$57F6]___
;referenced by table at _58e5

_57f6:
	ld      hl,($d2e9)
	ld      de,$0082
	and     a
	sbc     hl,de
	ret     c
	bit     0,(iy+vars.scrollRingFlags)
	jp      z,_35fd
	ret

;____________________________________________________________________________[$5808]___
;referenced by table at _58e5

_5808:
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

;____________________________________________________________________________[$584B]___
;referenced by table at _58e5

_584b:
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

;____________________________________________________________________________[$5883]___
;referenced by table at _58e5

_5883:
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	ld      a,l
	and     $1f
	cp      $10
	ret     nc
	jp      _581b

;____________________________________________________________________________[$5893]___

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

;____________________________________________________________________________[$58D0]___
;referenced by table at _58e5

_58d0:
	bit     7,(ix+$18)
	ret     z
	ld      hl,($d401)
	ld      de,($d25d)
	and     a
	sbc     hl,de
	ret     nc
	ld      (iy+vars.joypad),$ff
	ret

;lookup table to the functions above
 ;(these are probably handle the different solidity values)
_58e5:
.dw _54bc, _54c6, _54ce, _550f, _552d, _5556, _5578, _5590
.dw _55a8, _55b6, _55e2, _55eb, _565c, _567c, _56a6, _56b6
.dw _56c6, _56d6, _5761, _5771, _5781, _5791, _57cd, _57f6
.dw _5808, _584b, _5883, _58d0

_591d:
.db $B4, $B6, $B8, $FF, $FF, $FF
.db $BA, $BC, $BE, $FF, $FF, $FF
.db $FF, $FF
_592b:
.db $B8, $B6, $B4, $FF, $FF, $FF
.db $BE, $BC, $BA, $FF, $FF, $FF
.db $FF, $FF
_5939:
.db $B4, $B6, $B8, $FF, $FF, $FF
.db $BA, $BC, $BE, $FF, $FF, $FF
.db $98, $9A, $FF, $FF, $FF, $FF
_594b:
.db $B4, $B6, $B8, $FF, $FF, $FF
.db $BA, $BC, $BE, $FF, $FF, $FF
.db $FE, $9C, $9E, $FF, $FF, $FF
.db $00, $00, $00, $00, $00, $00, $00, $00
_5965:
.db $99, $59, $99, $59, $CB, $59, $DD, $59, $DF, $59, $E2, $59, $E5, $59, $FB, $59, $FE, $59, $01, $5A, $53, $5A, $65, $5A, $68, $5A, $6B, $5A, $AF, $5A, $C5, $5A, $CC, $5A, $D0, $5A, $DE, $5A, $E1, $5A, $E4, $5A, $E7, $5A, $EA, $5A, $00, $5B, $03, $5B, $06, $5B, $00, $00, $00, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01, $02, $02, $02, $02, $02, $02, $02, $02, $03, $03, $03, $03, $03, $03, $03, $03, $04, $04, $04, $04, $04, $04, $04, $04, $05, $05, $05, $05, $05, $05, $05, $05, $FF, $00, $0D, $0D, $0D, $0D, $0E, $0E, $0E, $0E, $0F, $0F, $0F, $0F, $10, $10, $10, $10, $FF, $00, $FF, $00, $13, $FF, $00, $06, $FF, $00, $08, $08, $08, $08, $09, $09, $09, $09, $0A, $0A, $0A, $0A, $0B, $0B, $0B, $0B, $0C, $0C, $0C, $0C, $FF, $00, $07, $FF, $00, $00, $FF, $00, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $0C, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0A, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $0B, $FF, $00, $13, $13, $13, $13, $13, $13, $13, $13, $25, $25, $25, $25, $25, $25, $25, $25, $FF, $00, $11, $FF, $00, $14, $FF, $00, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $15, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $16, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $17, $FF, $22, $19, $19, $19, $19, $1A, $1A, $1B, $1B, $1C, $1C, $1D, $1D, $1E, $1E, $1F, $1F, $20, $20, $21, $21, $FF, $12, $0C, $08, $09, $0A, $0B, $FF, $00, $12, $12, $FF, $00, $12, $12, $12, $12, $12, $12, $24, $24, $24, $24, $24, $24, $FF, $00, $00, $FF, $00, $26, $FF, $00, $22, $FF, $00, $23, $FF, $00, $21, $21, $20, $20, $1F, $1F, $1E, $1E, $1D, $1D, $1C, $1C, $1B, $1B, $1A, $1A, $19, $19, $19, $19, $FF, $12, $19, $FF, $00, $1A, $FF, $00, $1B, $FF, $00

;____________________________________________________________________________[$5B09]___

;OBJECT: monitor - rings
_5b09:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _5deb
	jr      c,+
_5b24:	
	ld      a,$10
	call    _39ac
_5b29:
	xor     a			;set A to 0
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ret  
	
+	ld      hl,$5180		;$15180 - blinking items art
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
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      a,(ix+$06)
	bit     7,(ix+$18)
	jr      nz,+
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	add     hl,de
	adc     a,(ix+$0c)
+	ld      l,h
	ld      h,a
	ld      (RAM_TEMP3),hl
	ld      hl,$0004
	ld      (RAM_TEMP4),hl
	ld      hl,$0000
	ld      (RAM_TEMP6),hl
	ld      a,$5c
	call    _3581
	ld      hl,$000c
	ld      (RAM_TEMP4),hl
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
.db $54, $56, $58, $FF, $FF, $FF
.db $AA, $AC, $AE, $FF, $FF, $FF
.db $FF
_5bcc:
.db $54, $FE, $58, $FF, $FF, $FF
.db $AA, $AC, $AE, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$5BD9]___

;OBJECT: monitor - speed shoes
_5bd9:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _5deb
	jr      c,+
	ld      a,$f0
	ld      ($d411),a
	ld      a,$02
	rst     $28			;`playSFX`
	jp      _5b29
	
+	ld      hl,$5200
	jp      _5b34

;____________________________________________________________________________[$5C05]___

;OBJECT: monitor - life
_5c05:
	ld      (ix+$0D),$14
	ld      (ix+$0E),$18
	call    _5da8
	
	;check if the level has its bit flag set at $D305+
	ld      hl,$D305
	call    getLevelBitFlag
	ld      a,(hl)
	and     c
	jr      z,+			;if not set, skip ahead
	
	ld      (ix+$00),$FF
	jp      _5b29
	
+	ld      hl,$0003
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _5deb
	jr      c,+
	bit     2,(ix+$18)
	jp      nz,_5b24
	ld      hl,RAM_LIVES
	inc     (hl)
	
	;set the level's bit flag at $D305+
	ld      hl,$d305
	call    getLevelBitFlag
	ld      a,(hl)
	or      c
	ld      (hl),a
	
	xor     a			;set A to 0
	ld      (ix+$0f),a
	ld      (ix+$10),a
	
	ld      a,$09
	rst     $28			;`playSFX`
	
	ld      a,(RAM_CURRENT_LEVEL)
	cp      28			;special stage?
	ret     nc
	
	ld      hl,$d280
	inc     (hl)
	ret
	
	;------------------------------------------------------------------------------
+	ld      a,(RAM_CURRENT_LEVEL)
	cp      4			;level 4 (Bridge Act 2)?
	jr      z,+
	cp      $09			;level 9 (Labyrinth Act 1)?
	jr      z,++
	cp      $0c			;level 12 (Scrap Brain Act 1)?
	jr      z,+++
	cp      $11			;level 11 (Labyrinth Act 3)?
	jr      z,++++
	
-	ld      hl,$5280
	jp      _5b34

+	ld      c,$00
	ld      de,$0040
	ld      a,(ix+$13)
	cp      $3c
	jr      c,+
	dec     c
	ld      de,$ffc0
+	ld      (ix+$0a),e
	ld      (ix+$0b),d
	ld      (ix+$0c),c
	inc     (ix+$13)
	ld      a,(ix+$13)
	cp      $50
	jr      c,-
	ld      (ix+$13),$28
	jr      -
	
++	set     2,(ix+$18)
	ld      hl,$d317
	call    getLevelBitFlag
	ld      a,(hl)
	ld      hl,$5180
	and     c
	jp      z,_5b34
	res     2,(ix+$18)
	ld      hl,$5280
	jp      _5b34
	
+++	set     1,(ix+$18)
	ld      (ix+$07),$80
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	jr      -
	
++++	ld      a,($d280)
	cp      $11
	jr      nc,-
	ld      (ix+$00),$ff
	jr      -

;____________________________________________________________________________[$5CD7]___

;OBJECT: monitor - shield
_5cd7:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _5deb
	jr      c,+
	set     5,(iy+vars.flags6)
	jp      _5b29
	
+	ld      hl,$5300
	jp      _5b34

;____________________________________________________________________________[$5CFF]___

;OBJECT: monitor - invincibility
_5cff:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _5deb
	jr      c,+
	set     0,(iy+vars.unknown0)
	ld      a,$f0
	ld      ($d28d),a
	
	ld      a,index_music_invincibility
	rst     $18			;`playMusic`
	
	jp      _5b29
	
+	ld      hl,$5380
	jp      _5b34

;____________________________________________________________________________[$5D2F]___
;OBJECT: monitor - checkpoint

_5d2f:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _5deb
	jr      c,+
	
	ld      hl,$d311
	call    getLevelBitFlag
	ld      a,(hl)
	or      c
	ld      (hl),a
	
	ld      a,(RAM_CURRENT_LEVEL)
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
	
+	ld      hl,$5480
	jp      _5b34
	
;____________________________________________________________________________[$5D80]___
;OBJECT: monitor - continue

_5d80:
	ld      (ix+$0d),$14
	ld      (ix+$0e),$18
	call    _5da8
	ld      hl,$0003
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _5deb
	jr      c,+
	set     3,(iy+vars.flags9)
	jp      _5b29
	
+	ld      hl,$5500
	jp      _5b34

;____________________________________________________________________________[$5DA8]___

_5da8:
	bit     0,(ix+$18)
	ret     nz
	ld      a,(RAM_LEVEL_SOLIDITY)
	and     a
	jr      nz,+
	ld      bc,$0000
	ld      e,c
	ld      d,b
	call    _36f9
	ld      de,$0016
	ld      bc,$0012
	ld      a,(hl)
	cp      $ab
	jr      z,++
+	ld      de,$0004
	ld      bc,$0000
++	ld      l,(ix+$02)
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

;____________________________________________________________________________[$5DEB]___

_5deb:
	ld      hl,$0804
	ld      (RAM_TEMP1),hl
	ld      a,($d414)
	and     $01
	jr      nz,++
	ld      de,($d3fe)
	ld      c,(ix+$02)
	ld      b,(ix+$03)
	ld      hl,$ffee
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+++
	ld      hl,$0010
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+++
	ld      a,($d414)
	and     $04
	jr      nz,+
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

+	ld      a,($d408)
	and     a
	jp      m,+
++	call    _36be
	and     a
	ret

+	ld      (ix+$0a),$80
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

+++	ld      hl,($d3fe)
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
	jr      nc,+
	ld      bc,$0015
+	ld      l,(ix+$02)
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
	call    getLevelBitFlag
	ld      a,(hl)
	and     c
	jr      nz,+
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$11
	call    _5da8
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      hl,$d30b
	call    getLevelBitFlag
	ld      a,(hl)
	or      c
	ld      (hl),a
	ld      hl,$d27f
	inc     (hl)
	ld      a,$fe
	ld      ($d28b),a
	
	ld      a,index_music_emerald
	rst     $18			;`playMusic`
	
+	ld      (ix+$00),$ff
	ret

++	ld      a,($d223)
	rrca    
	jr      c,+
	ld      (ix+$0f),<_5f10
	ld      (ix+$10),>_5f10
+	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      hl,$5400		;$15400 - emerald in the blinking items art
	call    _c1d
	ret

_5f10:
.db $5C, $5E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$5F17]___

;OBJECT: end sign
_5f17:
	ld      (ix+$0d),$18
	ld      (ix+$0e),$30
	bit     0,(ix+$11)
	jr      nz,+
	res     7,(iy+vars.flags6)
	res     3,(iy+vars.scrollRingFlags)
	
	;end sign sprite set
	ld      hl,$4294
	ld      de,$2000
	ld      a,9
	call    decompressArt
	
	ld      hl,S1_EndSign_Palette
	ld      a,$02
	call    loadPaletteOnInterrupt
	set     0,(ix+$11)
+	ld      hl,($d25a)
	ld      (RAM_LEVEL_CROPLEFT),hl
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
	jr      z,++
	cp      c
	jr      z,++
	bit     7,(ix+$18)
	jr      z,++
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	bit     7,h
	jr      z,+
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
+	ld      de,$0064
	and     a
	sbc     hl,de
	jr      nc,++
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fe
	ld      (ix+$0c),$ff
++	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$001a
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	bit     3,(ix+$11)
	jr      nz,++
	bit     2,(ix+$11)
	jr      z,+
	bit     7,(ix+$18)
	jr      z,++
	
	ld      a,index_music_actComplete
	rst     $18			;`playMusic`
	
	ld      a,$0c
	rst     $28			;`playSFX`
	res     2,(ix+$11)
	set     3,(ix+$11)
	ld      a,$a0
	ld      ($d289),a
	set     1,(iy+vars.flags6)
	jp      ++
	
+	ld      hl,$0a0a
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	bit     7,(ix+$0c)
	jr      nz,++
	bit     1,(ix+$11)
	jr      nz,++
	ld      de,($d403)
	bit     7,d
	jr      z,+
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
+	ld      hl,$0300
	and     a
	sbc     hl,de
	jr      nc,+
	ld      de,$0300
+	ex      de,hl
	add     hl,hl
	ld      (ix+$14),l
	ld      (ix+$15),h
	ld      (ix+$12),$00
	set     1,(ix+$11)
	res     3,(iy+vars.flags6)
	ld      a,$0b
	rst     $28			;`playSFX`
++	ld      de,_6157
	bit     1,(ix+$11)
	jr      nz,_f
	bit     2,(ix+$11)
	jr      nz,_f
	ld      de,$6171
	bit     3,(ix+$11)
	jr      z,_f
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $0c
	jr      c,+
	cp      $1c
	jr      c,++
	ld      de,$618e
	ld      c,$01
	jr      +++
	
+	ld      de,$61a8
	ld      c,$04
	ld      a,(RAM_RINGS)
	cp      $50
	jr      nc,+++
++	cp      $40
	jr      z,+
	ld      de,$61c2
	ld      c,$03
	and     $0f
	jr      z,+++
+	ld      a,(RAM_RINGS)
	srl     a
	srl     a
	srl     a
	srl     a
	ld      b,a
	ld      a,(RAM_CURRENT_LEVEL)
	and     $03
	inc     a
	ld      de,$6174
	ld      c,$02
	cp      b
	jr      z,+++
	ld      de,$618e
	ld      c,$01
+++	ld      a,c
	ld      ($d288),a
__	ld      l,(ix+$12)
	ld      h,$00
	add     hl,de
	ld      a,(hl)
	cp      $ff
	jr      nz,+
	inc     hl
	ld      a,(hl)
	ld      (ix+$12),a
	jp      _b
	
+	ld      l,a
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
	jr      nz,+
	inc     (ix+$12)
	ret
	
+	ld      a,(ix+$14)
	add     a,(ix+$16)
	ld      (ix+$16),a
	ld      a,(ix+$15)
	push    af
	adc     a,(ix+$17)
	ld      (ix+$17),a
	pop     af
	adc     a,(ix+$12)
	cp      $18
	jr      c,+
	xor     a
+	ld      (ix+$12),a
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	ld      a,(ix+$0c)
	and     a
	jp      p,+
	ld      hl,$fc00
	sbc     hl,de
	ret     nc
+	ex      de,hl
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
	jr      c,+
	ld      l,c
	ld      h,b
	ld      de,$0010
	xor     a
	sbc     hl,de
	ld      (ix+$14),l
	ld      (ix+$15),h
	ret     nc
+	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	res     1,(ix+$11)
	set     2,(ix+$11)
	ld      (ix+$12),$00
	ret

_6157:
.db $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $04, $04, $04, $04, $04, $04, $FF, $00, $00, $FF, $00, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $01, $01, $01, $01, $01, $01, $FF, $12, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $05, $05, $05, $05, $05, $05, $FF, $12, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $06, $06, $06, $06, $06, $06, $FF, $12, $00, $00, $00, $00, $00, $00, $03, $03, $03, $03, $03, $03, $02, $02, $02, $02, $02, $02, $07, $07, $07, $07, $07, $07, $FF, $12

;these are sprite layouts

.db $4E, $50, $52, $54, $FF, $FF
.db $6E, $70, $72, $74, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

.db $08, $0A, $0C, $0E, $FF, $FF
.db $28, $2A, $2C, $2E, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

.db $FE, $12, $14, $FF, $FF, $FF
.db $FE, $32, $34, $FF, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

.db $16, $18, $1A, $1C, $FF, $FF
.db $36, $38, $3A, $3C, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

.db $56, $58, $5A, $5C, $FF, $FF
.db $76, $78, $7A, $7C, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

.db $00, $02, $04, $06, $FF, $FF
.db $20, $22, $24, $26, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

.db $4E, $4A, $4C, $54, $FF, $FF
.db $6E, $6A, $6C, $74, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

.db $4E, $46, $48, $54, $FF, $FF
.db $6E, $66, $68, $74, $FF, $FF
.db $FE, $42, $44, $FF, $FF, $FF

;____________________________________________________________________________[$626C]___

S1_EndSign_Palette:
.db $38, $20, $35, $1b, $16, $2a, $00, $3f, $03, $0f, $01, $00, $00, $00, $00, $00

;____________________________________________________________________________[$627C]___

S1_Palette_Pointers:

.dw S1_Palette_GreenHill
.dw S1_Palette_Bridge
.dw S1_Palette_Jungle
.dw S1_Palette_Labyrinth
.dw S1_Palette_ScrapBrain
.dw S1_Palette_SkyBaseExterior
.dw S1_Palette_6
.dw S1_Palette_7

S1_PaletteCycle_Pointers:		;[$628C]

.dw S1_PaletteCycles_GreenHill
.dw S1_PaletteCycles_Bridge
.dw S1_PaletteCycles_Jungle
.dw S1_PaletteCycles_Labyrinth
.dw S1_PaletteCycles_ScrapBrain
.dw S1_PaletteCycles_SkyBase1
.dw S1_PaletteCycles_6
.dw S1_PaletteCycles_7
.dw S1_PaletteCycles_8

S1_Palettes:				;[$629E]

S1_Palette_GreenHill:			;[$629E] Green Hill
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3C, $3E, $3F, $0F, $00, $3F
.db $38, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $00, $00, $00
S1_PaletteCycles_GreenHill:		;[$62BE] Green Hill Cycles x 3
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3C, $3E, $3F, $0F, $00, $3F
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3F, $3C, $3E, $0F, $00, $3F
.db $38, $01, $06, $0B, $04, $08, $0C, $3D, $3B, $34, $3E, $3F, $3C, $0F, $00, $3F
S1_Palette_Bridge:			;[$62EE] Bridge
.db $38, $01, $06, $0B, $2A, $3A, $0C, $19, $3D, $24, $38, $3C, $3F, $1F, $00, $3F
.db $38, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $0B, $00
S1_PaletteCycles_Bridge:		;[$630E] Bridge Cycles
.db $38, $01, $06, $0B, $3A, $08, $0C, $19, $3C, $24, $38, $3C, $3F, $1F, $00, $3F
.db $38, $01, $06, $0B, $3A, $08, $0C, $19, $3C, $24, $3F, $38, $3C, $1F, $00, $3F
.db $38, $01, $06, $0B, $3A, $08, $0C, $19, $3C, $24, $3C, $3F, $38, $1F, $00, $3F
S1_Palette_Jungle:			;[$633E] Jungle
.db $04, $08, $0C, $06, $0B, $05, $25, $01, $03, $10, $34, $38, $3E, $1F, $00, $3F
.db $04, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $0B, $00
S1_PaletteCycles_Jungle:		;[$635E] Jungle Cycles
.db $04, $08, $0C, $06, $0B, $05, $26, $01, $03, $10, $34, $38, $3E, $0F, $00, $3F
.db $04, $08, $0C, $06, $0B, $05, $26, $01, $03, $10, $3E, $34, $38, $0F, $00, $3F
.db $04, $08, $0C, $06, $0B, $05, $26, $01, $03, $10, $38, $3E, $34, $0F, $00, $3F
S1_Palette_Labyrinth:			;[$638E] Labyrinth
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $1E, $09, $04, $0F, $00, $3F
S1_Palette_Labyrinth_Sprites:
;the code for the water line raster split refers directly to this sprite palette:
.db $00, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $0B, $15
S1_PaletteCycles_Labyrinth:		;[$63AE] Labyrinth Cycles
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $1E, $09, $04, $0F, $00, $3F
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $09, $04, $1E, $0F, $00, $3F
.db $00, $01, $06, $0B, $27, $14, $18, $29, $12, $10, $04, $1E, $09, $0F, $00, $3F
S1_Palette_ScrapBrain:			;[$63DE] Scrap Brain
.db $00, $10, $15, $29, $3D, $01, $14, $02, $05, $0A, $0F, $3F, $07, $0F, $00, $3F
.db $00, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3D, $15, $0F, $27, $10, $29
S1_PaletteCycles_ScrapBrain:		;[$63FE] Scrap Brain Cycles
.db $00, $10, $15, $29, $3D, $01, $14, $02, $05, $0A, $0F, $3F, $07, $0F, $00, $3F
.db $00, $10, $15, $29, $3D, $01, $14, $02, $3F, $05, $0A, $0F, $07, $0F, $00, $3F
.db $00, $10, $15, $29, $3D, $01, $14, $02, $0F, $3F, $05, $0A, $07, $0F, $00, $3F
.db $00, $10, $15, $29, $3D, $01, $14, $02, $0A, $0F, $3F, $05, $07, $0F, $00, $3F
S1_Palette_SkyBaseExterior:		;[$643E] Sky Base 1/2 Exterior
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $39, $3D, $3F, $24, $00, $38
.db $10, $20, $35, $1B, $16, $2A, $00, $3F, $01, $03, $3A, $06, $0F, $27, $15, $00
S1_PaletteCycles_SkyBase1:		;[$645E] Sky Base 1 Cycles
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $39, $3D, $3F, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3F, $3D, $39, $3D, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $3F, $3D, $39, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $39, $3D, $3F, $3D, $24, $00, $38

S1_PaletteCycles_SkyBase1_Lightning1	;[$649E] Sky Base 1 Lightning Cycles 1
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3D, $39, $3D, $3F, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $10, $3F, $3D, $39, $3D, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $20, $3D, $3F, $3D, $39, $24, $00, $38
.db $10, $10, $20, $34, $30, $10, $11, $25, $2A, $39, $3D, $3F, $3D, $24, $00, $38
S1_PaletteCycles_SkyBase1_Lightning2	;[$64DE] Sky Base 1 Lightning Cycles 2
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
-	ld      hl,_66c5
	add     hl,de
	ld      (RAM_TEMP6),hl
	ld      a,(hl)
	and     a
	jr      nz,+
	ld      (ix+$12),a
	ld      e,a
	jp      -
	
+	dec     a
	jr      nz,+
	ld      c,$00
	ld      h,c
	ld      l,$28
	jp      ++
	
+	dec     a
	jr      nz,+
	ld      c,$ff
	ld      hl,$ffd8
	jp      ++
	
+	dec     a
	jr      nz,+
	ld      c,$00
	ld      l,c
	ld      h,c
	jp      ++
	
+	ld      a,(ix+$11)
	cp      $20
	jp      nz,+
	ld      hl,$ffff
	ld      (RAM_TEMP4),hl
	ld      hl,$fffc
	ld      (RAM_TEMP6),hl
	call    _7c7b
	jp      c,+
	ld      de,$0000
	ld      c,e
	ld      b,d
	call    _ac96
	ld      hl,$0001
	ld      (RAM_TEMP4),hl
	ld      hl,$fffc
	ld      (RAM_TEMP6),hl
	call    _7c7b
	jr      c,+
	ld      de,$000e
	ld      bc,$0000
	call    _ac96
	ld      a,$0a
	rst     $28			;`playSFX`
	jp      +
	
++	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
+	ld      l,(ix+$11)
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
	ld      hl,(RAM_TEMP6)
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
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0804
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ret

_66c5:
.db $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $03, $03, $04, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $03, $03, $04, $00
_66e0:
.dw _66ea, _66ea, _66ea, _66f3, _66f6
_66ea:
.db $00, $0C, $01, $0C, $02, $0C, $01, $0C, $FF
_66f3:
.db $01, $01, $FF
_66f6:
.db $03, $01, $FF

_66f9:					;sprite layouts
.db $00, $02, $04, $FF, $FF, $FF
.db $20, $22, $24, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $00, $02, $44, $FF, $FF, $FF
.db $46, $22, $4A, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $40, $02, $44, $FF, $FF, $FF
.db $26, $22, $2A, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $40, $02, $04, $FF, $FF, $FF
.db $46, $22, $4A, $FF, $FF, $FF
.db $FF

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
	jr      nz,+
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
+	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      hl,_682f
	ld      e,(ix+$11)
	ld      d,$00
	add     hl,de
	ld      c,l
	ld      b,h
	ld      a,(bc)
	and     a
	jp      p,+
	dec     d
+	ld      e,a
	ld      l,(ix+$12)
	ld      h,(ix+$13)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      de,(RAM_TEMP1)
	and     a
	sbc     hl,de
	ld      (RAM_TEMP1),hl
	inc     bc
	ld      d,$00
	ld      a,(bc)
	and     a
	jp      p,+
	dec     d
+	ld      e,a
	ld      l,(ix+$14)
	ld      h,(ix+$15)
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      a,($d408)
	and     a
	jp      m,+
	ld      hl,$0806
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	ld      hl,($d3fe)
	ld      de,(RAM_TEMP1)
	add     hl,de
	ld      ($d3fe),hl
	ld      bc,$0010
	ld      de,$0000
	call    _LABEL_7CC1_12
+	ld      hl,$6911
	ld      a,(RAM_LEVEL_SOLIDITY)
	and     a
	jr      z,+
	ld      hl,_6923
+	ld      (ix+$0f),l
	ld      (ix+$10),h
	bit     1,(ix+$18)
	jr      nz,+
	ld      a,(ix+$11)
	inc     a
	inc     a
	ld      (ix+$11),a
	cp      $e0
	ret     c
	set     1,(ix+$18)
	ret
	
+	ld      a,(ix+$11)
	dec     a
	dec     a
	ld      (ix+$11),a
	ret     nz
	res     1,(ix+$18)
	ret

;this is swinging position data
_682f:
.db $B3, $00
.db $B3, $01
.db $B3, $02
.db $B3, $02
.db $B3, $03
.db $B3, $04
.db $B3, $05
.db $B3, $06
.db $B4, $07
.db $B4, $08
.db $B4, $09
.db $B4, $0B
.db $B4, $0C
.db $B4, $0D
.db $B5, $0E
.db $B5, $0F
.db $B5, $11
.db $B5, $12
.db $B6, $13
.db $B6, $15
.db $B7, $16
.db $B7, $18
.db $B8, $19
.db $B8, $1B
.db $B9, $1D
.db $B9, $1E
.db $BA, $20
.db $BB, $22
.db $BC, $23
.db $BD, $25
.db $BE, $27
.db $BF, $29
.db $C0, $2B
.db $C2, $2D
.db $C3, $2F
.db $C4, $31
.db $C6, $32
.db $C8, $34
.db $CA, $36
.db $CC, $38
.db $CE, $3A
.db $D0, $3C
.db $D2, $3E
.db $D4, $3F
.db $D7, $41
.db $DA, $43
.db $DC, $44
.db $DF, $45
.db $E2, $47
.db $E5, $48
.db $E8, $49
.db $EC, $4A
.db $EF, $4B
.db $F2, $4C
.db $F6, $4C
.db $F9, $4C
.db $FC, $4D
.db $00, $4D
.db $03, $4D
.db $07, $4C
.db $0A, $4C
.db $0E, $4C
.db $11, $4B
.db $14, $4A
.db $18, $49
.db $1B, $48
.db $1E, $47
.db $21, $45
.db $24, $44
.db $27, $42
.db $29, $41
.db $2C, $3F
.db $2E, $3D
.db $31, $3B
.db $33, $3A
.db $35, $38
.db $37, $36
.db $39, $34
.db $3A, $32
.db $3C, $30
.db $3E, $2E
.db $3F, $2C
.db $40, $2A
.db $41, $28
.db $43, $26
.db $44, $24
.db $45, $23
.db $45, $21
.db $46, $1F
.db $47, $1D
.db $48, $1C
.db $48, $1A
.db $49, $18
.db $49, $17
.db $4A, $15
.db $4A, $14
.db $4B, $12
.db $4B, $11
.db $4B, $0F
.db $4B, $0E
.db $4C, $0D
.db $4C, $0C
.db $4C, $0A
.db $4C, $09
.db $4C, $08
.db $4C, $07
.db $4D, $06
.db $4D, $05
.db $4D, $04
.db $4D, $03
.db $4D, $02
.db $4D, $01
.db $4D, $00

;sprite layout
_6911:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $18, $1A, $18, $1A, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_6923:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $6C, $6E, $6E, $48, $FF, $FF
.db $FF, $FF, $FE, $FF, $FF, $FF
.db $FF, $FF

.db $6C, $6E, $6C, $6E, $FF, $FF
.db $FF, $FF

;____________________________________________________________________________[$693F]___

;OBJECT: UNKNOWN
_693f:
	set     5,(ix+$18)
	ld      a,(ix+$15)
	cp      $aa
	jr      z,+
	xor     a
	ld      (ix+$11),a
	ld      (ix+$15),$aa
	ld      (ix+$16),a
	ld      (ix+$17),a
	bit     5,(iy+vars.flags0)
	jr      z,+
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $12
	jr      z,+
	ld      a,($d414)
	rlca    
	jr      c,+
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
	jp      m,+
	cpl     
	add     hl,de
	adc     a,c
	ld      ($d406),hl
	ld      ($d408),a
+	xor     a
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
.db $74, $76, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $78, $7A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $7C, $7E, $FF, $FF, $FF, $FF
.db $FF

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
	jp      m,++
	ld      hl,$0806
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      de,$0000
	ld      a,(ix+$05)
	and     $1f
	cp      $10
	jr      nc,+
	ld      e,$80
+	ld      (ix+$0a),e
	ld      (ix+$0b),d
	ld      (ix+$0c),$00
	ld      bc,$0010
	call    _LABEL_7CC1_12
	ret
	
++	ld      c,$00
	ld      l,c
	ld      h,c
	ld      a,(ix+$05)
	and     $1f
	jr      z,+
	ld      hl,$ffc0
	dec     c
+	ld      (ix+$0a),l
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
	jr      c,+
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0040
	add     hl,de
	adc     a,d
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
+	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      a,($d408)
	and     a
	jp      m,+
	ld      hl,$0806
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	ld      (ix+$16),$01
	ld      bc,$0010
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	call    _LABEL_7CC1_12
+	ld      hl,$6911
	ld      a,(RAM_LEVEL_SOLIDITY)
	and     a
	jr      z,+
	ld      hl,_6923
+	ld      (ix+$0f),l
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
	ld      (RAM_TEMP6),hl
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
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      (RAM_TEMP6),hl
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,_6b72
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $05
	jr      z,+
	cp      $0b
	jr      z,+
	ld      hl,_6b70
+	ld      a,($d223)
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
	jr      c,+
	inc     d
	ex      de,hl
	sbc     hl,bc
	jr      c,+
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	ld      l,c
	ld      h,b
	ld      de,$0010
	add     hl,de
	ld      de,($d25d)
	and     a
	sbc     hl,de
	jr      c,+
	ld      hl,$00c0
	add     hl,de
	and     a
	sbc     hl,bc
	ret     nc
+	ld      (ix+$00),$ff
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
	jr      nz,+
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
+	ld      (ix+$0d),$14
	ld      (ix+$0e),$20
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,($d3fe)
	and     a
	sbc     hl,de
	jr      c,+
	ld      de,$0040
	sbc     hl,de
	jr      nc,+
	ld      a,(ix+$12)
	cp      $05
	jr      nc,+
	ld      (ix+$12),$05
+	ld      e,(ix+$12)
	ld      d,$00
-	ld      hl,$6cd7
	add     hl,de
	ld      (RAM_TEMP6),hl
	ld      a,(hl)
	and     a
	jr      nz,+
	ld      (ix+$12),a
	ld      e,a
	jp      -
	
+	dec     a
	jr      nz,++
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0030
	add     hl,de
	ld      de,($d25a)
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      a,(ix+$14)
	ld      (ix+$02),a
	ld      a,(ix+$15)
	ld      (ix+$03),a
	res     0,(ix+$18)
	ret
	
+	ld      c,$ff
	ld      hl,$fe00
	jp      +++
	
++	dec     a
	jr      nz,+
	ld      c,$00
	ld      l,c
	ld      h,c
	jp      +++
	
+	ld      a,(ix+$11)
	cp      $20
	jp      nz,+
	call    _7c7b
	jp      c,+
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
	rst     $28			;`playSFX`
	ld      c,$00
	ld      l,c
	ld      h,c
+++	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
+	ld      l,(ix+$11)
	ld      h,(ix+$12)
	ld      de,$0008
	add     hl,de
	ld      (ix+$11),l
	ld      (ix+$12),h
	ld      hl,(RAM_TEMP6)
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
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$1004
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ret

_6cd7:
.db $01, $01, $01, $01, $00, $02, $02, $03, $01, $01, $00
_6ce2:
.dw _6cea, _6cea, _6cef, _6cf4
_6cea:
.db $00, $02, $01, $02, $FF
_6cef:
.db $02, $02, $03, $02, $FF
_6cf4:
.db $04, $02, $05, $02, $FF

;sprite layout
_6cf9:
.db $FE, $0A, $FF, $FF, $FF, $FF
.db $0C, $0E, $10, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $FF, $FF, $FF, $FF, $FF
.db $0C, $0E, $2C, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $0A, $FF, $FF, $FF, $FF
.db $12, $14, $16, $FF, $FF, $FF
.db $32, $34, $FF, $FF, $FF, $FF

.db $FE, $FF, $FF, $FF, $FF, $FF
.db $12, $14, $16, $FF, $FF, $FF
.db $32, $34, $FF, $FF, $FF, $FF

.db $FE, $0A, $FF, $FF, $FF, $FF
.db $12, $14, $16, $FF, $FF, $FF
.db $30, $34, $FF, $FF, $FF, $FF

.db $FE, $FF, $FF, $FF, $FF, $FF
.db $12, $14, $16, $FF, $FF, $FF
.db $30, $34, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$6D65]___

;OBJECT: wooden platform - moving (Green Hill)
_6d65:
	set     5,(ix+$18)
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $07
	jr      z,+
	ld      hl,$0020
	ld      ($d267),hl
	ld      hl,$0048
	ld      ($d269),hl
	ld      hl,$0030
	ld      ($d26b),hl
	ld      hl,$0030
	ld      ($d26d),hl
+	ld      (ix+$0d),$1a
	ld      (ix+$0e),$10
	ld      c,$00
	ld      a,($d408)
	and     a
	jp      m,+
	ld      hl,$0806
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      c,$00
	jr      c,+
	ld      bc,$0010
	ld      de,$0000
	call    _LABEL_7CC1_12
	ld      c,$01
+	ld      l,(ix+$12)
	ld      h,(ix+$13)
	inc     hl
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      de,$00a0
	xor     a
	sbc     hl,de
	jr      c,+
	ld      (ix+$12),a
	ld      (ix+$13),a
	inc     (ix+$14)
+	ld      de,$0001
	bit     0,(ix+$14)
	jr      z,+
	ld      de,$ffff
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,c
	and     a
	jr      z,+
	ld      hl,($d3fe)
	add     hl,de
	ld      ($d3fe),hl
+	ld      hl,$6911
	ld      a,(RAM_LEVEL_SOLIDITY)
	and     a
	jr      z,+
	ld      hl,$6931
	dec     a
	jr      z,+
	ld      hl,_6923
+	ld      (ix+$0f),l
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
-	ld      hl,_6e96
	add     hl,de
	ld      (RAM_TEMP6),hl
	ld      a,(hl)
	and     a
	jr      nz,+
	ld      (ix+$12),a
	ld      e,a
	jp      -
	
+	dec     a
	jr      nz,+
	ld      c,$ff
	ld      hl,$ff00
	jp      ++
	
+	dec     a
	jr      nz,+
	ld      c,$00
	ld      hl,$0100
	jp      ++
+	ld      c,$00
	ld      l,c
	ld      h,c
++	ld      (ix+$07),l
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
	ld      hl,(RAM_TEMP6)
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
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ret

_6e96
.db $01, $01, $01, $01, $01, $01, $01, $01, $01
.db $03, $03, $03, $03, $02, $02, $02, $02, $02
.db $02, $02, $02, $02, $04, $04, $04, $04, $00

_6eb1:
.dw _6ebb, _6ebb, _6ec0, _6ec5, _6ec8
_6ebb:
.db $00, $08, $01, $08, $FF
_6ec0:
.db $02, $08, $03, $08, $FF
_6ec5:
.db $00, $FF, $FF
_6ec8:
.db $02, $FF, $FF

;sprite layout
_6ecb:
.db $60, $62, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $64, $66, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $68, $6A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $6C, $6E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$6F08]___

;OBJECT: badnick - newtron
_6f08:
	set     5,(ix+$18)
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$14
	ld      a,(ix+$11)
	cp      $02
	jr      z,+
	and     a
	jr      nz,+++
+	ld      a,($d223)
	and     $01
	jr      z,+
	ld      bc,$0000
	jr      ++
+	ld      bc,_6fed
++	inc     (ix+$17)
	ld      a,(ix+$17)
	cp      $3c
	jp      c,++++
	ld      (ix+$17),$00
	inc     (ix+$11)
	jp      ++++
	
+++	cp      $01
	jp      nz,++
	inc     (ix+$17)
	ld      a,(ix+$17)
	cp      $64
	jr      nz,+
	call    _7c7b
	jp      c,+
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
	rst     $28			;`playSFX`
+	ld      bc,_6fed
	cp      $78
	jr      c,++++
	ld      (ix+$17),$00
	inc     (ix+$11)
	jr      ++++
	
++	cp      $03
	jr      nz,++++
	ld      bc,$0000
	inc     (ix+$17)
	ld      a,(ix+$17)
	and     a
	jr      nz,++++
	ld      (ix+$11),c
++++	ld      (ix+$0f),c
	ld      (ix+$10),b
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ret   

;sprite layout
_6fed:  
.db $1C, $1E, $FF, $FF, $FF, $FF
.db $FE, $3E, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $40					;odd?
_7000:
.db $42, $FF, $FF, $FF, $FF, $FE
.db $62, $FF, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$700C]___

;OBJECT: boss (Green Hill)
_700c:
	set     5,(ix+$18)
	ld      (ix+$0d),$20
	ld      (ix+$0e),$1c
	call    _7ca6
	bit     0,(ix+$11)
	jr      nz,+
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
	
	ld      a,index_music_boss1
	rst     $18			;`playMusic`
	
	xor     a
	ld      ($d2ec),a
	ld      (ix+$12),a
	ld      (ix+$14),$a1
	ld      (ix+$15),$72
	ld      hl,$0760
	ld      de,$00e8
	call    _7c8c
	set     0,(ix+$11)
+	ld      a,(ix+$13)
	and     $3f
	ld      e,a
	ld      d,$00
	ld      hl,$7261
	add     hl,de
	ld      a,(hl)
	and     a
	jp      p,+
	ld      c,$ff
	jr      ++
+	ld      c,$00
++	ld      (ix+$0a),a
	ld      (ix+$0b),c
	ld      (ix+$0c),c
-	ld      e,(ix+$12)
	ld      d,$00
	ld      l,(ix+$14)
	ld      h,(ix+$15)
	add     hl,de
	ld      (RAM_TEMP6),hl
	ld      a,(hl)
	and     a
	jr      nz,+
	inc     hl
	ld      a,(hl)
	ld      (ix+$12),a
	jp      -
	
+	dec     a
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
	ld      hl,(RAM_LEVEL_CROPLEFT)
	ld      de,$0006
	add     hl,de
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	ld      c,$ff
	ld      hl,$ff00
	jp      c,++
	ld      (ix+$12),$00
	bit     1,(ix+$11)
	jr      nz,+
	ld      (ix+$14),$a4
	ld      (ix+$15),$72
	set     1,(ix+$11)
	jp      ++
	
+	ld      (ix+$14),$a7
	ld      (ix+$15),$72
	res     1,(ix+$11)
	jp      ++
	ld      hl,(RAM_LEVEL_CROPLEFT)
	ld      de,$00e0
	add     hl,de
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	ld      c,$00
	ld      hl,$0100
	jp      nc,++
	ld      (ix+$12),$00
	bit     2,(ix+$11)
	jr      nz,+
	ld      (ix+$14),$a1
	ld      (ix+$15),$72
	set     2,(ix+$11)
	jp      ++
	
+	ld      (ix+$14),$aa
	ld      (ix+$15),$72
	res     2,(ix+$11)
	jp      ++
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
	jp      nc,++
	ld      (ix+$12),$00
	ld      (ix+$14),$b0
	ld      (ix+$15),$72
	jp      ++
	ld      c,$00
	ld      hl,$0400
	jp      ++
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
	jp      nc,++
	ld      (ix+$12),$00
	ld      (ix+$14),$bc
	ld      (ix+$15),$72
	jp      ++
	ld      c,$ff
	ld      hl,$fc00
	jr      ++
	ld      c,$00
	ld      l,c
	ld      h,c
	jr      ++
	ld      c,$00
	ld      l,c
	ld      h,c
	ld      (ix+$14),$ad
	ld      (ix+$15),$72
	ld      (ix+$12),c
	ld      (ix+$13),c
	jr      ++
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
	jp      c,++
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,(RAM_LEVEL_CROPLEFT)
	xor     a
	sbc     hl,de
	ld      c,a
	ld      l,c
	ld      h,c
	jr      c,+
	ld      (ix+$14),$a1
	ld      (ix+$15),$72
	ld      (ix+$12),a
	jr      ++
	
+	ld      (ix+$14),$a4
	ld      (ix+$15),$72
	ld      (ix+$12),a
	jr      ++			;this doesn't look right
++	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
	ld      hl,(RAM_TEMP6)
	ld      e,(hl)
	ld      d,$00
	ld      hl,_72c8
	add     hl,de
	ld      a,(hl)
	ld      hl,_72f8
	and     a
	jr      z,+
	ld      hl,_730a
+	ld      e,a
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

;sprite layout
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
	jr      nz,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0010
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	set     0,(ix+$18)
+	ld      (ix+$0d),$1c
	ld      (ix+$0e),$40
	ld      hl,_7564
	bit     1,(ix+$18)
	jr      z,+
	ld      hl,_757c
+	ld      a,($d223)
	rrca    
	jr      nc,+
	ld      de,$000c
	add     hl,de
+	ld      c,(hl)
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
	jr      z,+
	ld      hl,_7552
+	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,($d25a)
	ld      (RAM_LEVEL_CROPLEFT),hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$ff90
	add     hl,de
	ld      ($d275),hl
	ld      hl,$0002
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jp      c,+++
	ld      a,($d408)
	and     a
	jp      m,+++
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,($d401)
	and     a
	sbc     hl,de
	jr      c,++
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0010
	add     hl,de
	ld      de,$ffea
	ld      bc,($d3fe)
	and     a
	sbc     hl,bc
	jr      nc,+
	ld      de,$001d
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      ($d3fe),hl
	jp      +
	
++	ld      hl,($d3fe)
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
	bit     1,(iy+vars.flags6)
	jr      nz,++
	set     1,(iy+vars.flags6)
+	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
+++	bit     1,(iy+vars.flags6)
	ret     z
++	ld      a,(ix+$12)
	cp      $08
	jr      nc,+
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $14
	ret     c
	ld      (ix+$11),$00
	call    _7a3a
	inc     (ix+$12)
	ret
	
+	bit     1,(ix+$18)
	jr      nz,+
	ld      a,$a0
	ld      ($d289),a
	
	ld      a,index_music_actComplete
	rst     $18			;`playMusic`
	
	set     1,(ix+$18)
+	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	res     5,(iy+vars.flags0)
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

;____________________________________________________________________________[$74B6]___

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

;sprite layout
_752e:
.db $00, $02, $04, $06, $FF, $FF
.db $20, $22, $24, $26, $FF, $FF
.db $40, $42, $44, $46, $FF, $FF
_7540:
.db $00, $08, $0A, $06, $FF, $FF
.db $20, $22, $24, $26, $FF, $FF
.db $40, $42, $44, $46, $FF, $FF
_7552:
.db $00, $68, $6A, $06, $FF, $FF
.db $20, $22, $24, $26, $FF, $FF
.db $40, $42, $44, $46, $FF, $FF

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
	jr      z,+
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fd
	ld      (ix+$0c),$ff
+	ld      de,$0012
	ld      a,(RAM_LEVEL_SOLIDITY)
	cp      $03
	jr      nz,+
	ld      de,$0038
+	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	add     hl,de
	adc     a,$00
	ld      c,a
	jp      m,+
	ld      a,h
	cp      $02
	jr      c,+
	ld      hl,$0200
	ld      c,$00
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      hl,$fe00
	ld      a,(RAM_LEVEL_SOLIDITY)
	cp      $03
	jr      nz,+
	ld      hl,$fe80
+	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),$ff
	ld      bc,_7629
	ld      a,(RAM_LEVEL_SOLIDITY)
	and     a
	jr      z,+
	ld      bc,_762e
	cp      $03
	jr      nz,+
	ld      bc,_7633
+	ld      de,_7638
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

;sprite layout
_7638:
.db $10, $12, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $6E, $0E, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $28, $2A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $2C, $2E, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $30, $32, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $50, $52, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$7699]___

;OBJECT: free animal - rabbit
_7699:
	res     5,(ix+$18)
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$20
	ld      hl,_7760
	ld      a,(RAM_LEVEL_SOLIDITY)
	and     a
	jr      z,+
	ld      hl,_777b
	dec     a
	jr      z,+
	ld      hl,$7796
	dec     a
	jr      z,+
	ld      hl,_77b1
+	ld      (ix+$0f),l
	ld      (ix+$10),h
	bit     7,(ix+$18)
	jr      z,++
	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),$01
	ld      (ix+$0c),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      hl,_7752
	ld      a,(RAM_LEVEL_SOLIDITY)
	ld      c,a
	and     a
	jr      z,+
	ld      hl,_776d
	dec     a
	jr      z,+
	ld      hl,_7788
	dec     a
	jr      z,+
	ld      hl,_77a3
+	ld      (ix+$0f),l
	ld      (ix+$10),h
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $08
	ret     c
	ld      hl,$fffc
	ld      a,c
	and     a
	jr      z,+
	ld      hl,$fffe
+	ld      (ix+$0a),$00
	ld      (ix+$0b),l
	ld      (ix+$0c),h
++	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0028
	add     hl,de
	adc     a,$00
	ld      c,a
	jp      m,+
	ld      a,h
	cp      $02
	jr      c,+
	ld      hl,$0200
	ld      c,$00
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      (ix+$07),$80
	ld      (ix+$08),$fe
	ld      (ix+$09),$ff
	ld      (ix+$11),$00
	jp      _7612

;sprite layout
_7752:
.db $70, $72, $FF, $FF, $FF, $FF
.db $54, $56, $FF, $FF, $FF, $FF
.db $FF, $FF
_7760:
.db $5C, $5E, $FF, $FF, $FF, $FF
.db $58, $5A, $FF, $FF, $FF, $FF
.db $FF
_776d:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $34, $36, $FF, $FF, $FF, $FF
.db $FF, $FF
_777b:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $38, $3A, $FF, $FF, $FF, $FF
.db $FF
_7788:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $3C, $3E, $FF, $FF, $FF, $FF
.db $FF, $FF, $FE, $FF, $FF, $FF

.db $FF, $FF, $1C, $1E, $FF, $FF
.db $FF, $FF, $FF
_77a3:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $14, $16, $FF, $FF, $FF, $FF
.db $FF, $FF
_77b1:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $18, $1A, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$77BE]___
;called by the boss object code -- probably the exploded egg ship

_77be:
	ld      a,($d2ec)
	cp      $08
	jr      nc,+++
	ld      a,($d2b1)
	and     a
	jp      nz,++
	ld      hl,$0c08
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ret     c
	bit     0,(iy+vars.scrollRingFlags)
	ret     nz
	ld      a,($d414)
	rrca    
	jr      c,+
	and     $02
	jp      z,_35fd
+	ld      de,$0001
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
	rst     $28			;`playSFX`
	ld      a,($d2ec)
	inc     a
	ld      ($d2ec),a
++	ld      hl,($d216)
	ld      de,_7922
	add     hl,de
	bit     1,(ix+$18)
	jr      z,+
	ld      de,$0012
	add     hl,de
+	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,$d2ed
	ld      (hl),$18
	inc     hl
	ld      (hl),$00
	ret
	
+++	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      de,$0024
	ld      hl,($d216)
	bit     1,(ix+$18)
	jr      z,+
	ld      de,$0036
+	add     hl,de
	ld      de,_7922
	add     hl,de
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,$d2ee
	ld      a,(hl)
	cp      $0a
	jp      nc,+
	dec     hl
	dec     (hl)
	ret     nz
	ld      (hl),$18
	inc     hl
	inc     (hl)
	call    _7a3a
	ret
	
+	ld      a,($d2ee)
	cp      $3a
	jr      nc,+
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      a,(ix+$06)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      (ix+$04),l
	ld      (ix+$05),h
	ld      (ix+$06),a
+	ld      hl,$d2ee
	ld      a,(hl)
	cp      $5a
	jr      nc,+
	inc     (hl)
	ret
	
+	jr      nz,+
	ld      (hl),$5b
	
	ld      a,(RAM_LEVEL_MUSIC)
	rst     $18			;`playMusic`
	
	ld      a,(iy+vars.spriteCount)
	res     0,(iy+vars.flags0)
	call    wait
	ld      (iy+vars.spriteCount),a
+	ld      (ix+$07),$00
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
	set     5,(iy+vars.flags0)
	set     0,(iy+vars.flags2)
	res     1,(iy+vars.flags2)
	ld      a,(RAM_CURRENT_LEVEL)
	cp      $0b
	jr      nz,+
	set     1,(iy+vars.flags9)
+	;UNKNOWN
	ld      hl,$da28
	ld      de,$2000
	ld      a,12
	call    decompressArt
	ret
   
  ;sprite layout
_7922:
.db $2A, $2C, $2E, $30, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $6C, $6E, $70, $72, $FF

.db $20, $10, $12, $14, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF

.db $2A, $16, $18, $1A, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $6C, $6E, $70, $72, $FF

.db $20, $3A, $3C, $3E, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF

.db $2A, $34, $36, $38, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $6C, $6E, $70, $72, $FF

.db $20, $10, $12, $14, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $54, $56, $66, $68, $FF

.db $2A, $16, $18, $1A, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $5A, $5C, $70, $72, $FF

.db $20, $3A, $3C, $3E, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $54, $56, $66, $68, $FF

.db $2A, $34, $36, $38, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $5A, $5C, $70, $72, $FF

.db $20, $06, $08, $0A, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF

.db $20, $06, $08, $0A, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF

.db $0E, $10, $12, $14, $16, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF

;____________________________________________________________________________[$79FA]___

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
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$fff8
	ld      de,$0010
	ld      c,$04
	bit     7,(ix+$09)
	jr      z,+
	ld      hl,$0028
	ld      c,$00
+	ld      (RAM_TEMP4),hl
	ld      (RAM_TEMP6),de
	add     a,c
	call    _3581
	ret

;____________________________________________________________________________[$7A3A]___

_7a3a:
	call    _7c7b
	ret     c
	push    hl
	call    _LABEL_625_57
	and     $1f
	ld      l,a
	ld      h,$00
	ld      (RAM_TEMP1),hl
	call    _LABEL_625_57
	and     $1f
	ld      l,a
	ld      h,$00
	ld      (RAM_TEMP3),hl
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
	ld      hl,(RAM_TEMP1)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,(RAM_TEMP3)
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
	rst     $28			;`playSFX`
	ret
	
;____________________________________________________________________________[$7AA7]___
;OBJECT: trip zone (Green Hill)

_7aa7:
	set     5,(ix+$18)
	ld      (ix+$0d),$40
	ld      (ix+$0e),$40
	ld      hl,$0000
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ret     c
	bit     6,(iy+vars.flags6)
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
	set     6,(iy+vars.flags6)
	ld      (iy+vars.joypad),$ff
	ld      a,$11
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$7AED]___
;OBJECT: flower (Green Hill)

_7aed:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      (ix+$11),$32
	ld      (ix+$12),$00
	set     0,(ix+$18)
+	ld      bc,$0000
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      ($d2ab),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      a,($d223)
	rrca    
	jr      nc,+
	ld      de,$0010
	add     hl,de
	inc     bc
+	ld      ($d2ad),hl
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

;____________________________________________________________________________[$7B95]___
;OBJECT: "make Sonic blink"

_7b95:
	set     5,(ix+$18)
	set     0,(iy+vars.flags9)
	ld      a,($d223)
	and     $01
	jp      z,+
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
	jr      ++
	
+	ld      (ix+$0f),a
	ld      (ix+$10),a
++	ld      l,(ix+$0a)
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
	jr      nc,+
	ld      (ix+$00),$ff
	res     0,(iy+vars.flags9)
	ret
	
+	ld      (ix+$07),a
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

;sprite layout
_7c29:
.db $B4, $B6, $FF, $FF, $FF, $FF
.db $FF, $FF
_7c31:
.db $B8, $BA, $FF, $FF, $FF, $FF
.db $FF, $FF
_7c39:
.db $BC, $BE, $FF, $FF, $FF, $FF
.db $FF, $FF

;____________________________________________________________________________[$7C41]___

;DE : e.g. $7de1
;BC : e.g. $7ddc
_7c41:
	ld      l,(ix+$17)

-	ld      h,$00
	add     hl,bc
	ld      a,(hl)
	cp      $ff
	jr      nz,+
	ld      l,$00
	ld      (ix+$17),l
	jp      -
	
+	inc     hl
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
	
-	ld      a,(hl)
	cp      $ff
	ret     z
	add     hl,de
	djnz    -
	
	scf     
	ret

;____________________________________________________________________________[$7C8C]___

_7c8c:
	ld      ($d27b),hl
	ld      ($d27d),de
	ld      hl,($d25a)
	ld      (RAM_LEVEL_CROPLEFT),hl
	ld      ($d275),hl
	ld      hl,($d25d)
	ld      (RAM_LEVEL_CROPTOP),hl
	ld      (RAM_LEVEL_EXTENDHEIGHT),hl
	ret

;____________________________________________________________________________[$7CA6]___

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
	res     5,(iy+vars.flags0)
	ret 

;____________________________________________________________________________[$7CC1]___

_LABEL_7CC1_12:
	bit  6, (iy+vars.flags6)
	ret  nz
	ld   l, (ix+$04)
	ld   h, (ix+$05)
	xor  a
	bit  7, d
	jr   z, +
	dec  a
+	add  hl, de
	adc  a, (ix+$06)
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
	jr      z,+
	dec     (ix+$14)
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ret
	
+	bit     0,(ix+$18)
	jr      nz,++
	bit     1,(ix+$18)
	jr      nz,+
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
+	ld      (ix+$0a),$00
	ld      (ix+$0b),$fc
	ld      (ix+$0c),$ff
	set     0,(ix+$18)
	ld      a,$12
	rst     $28			;`playSFX`
	ld      (ix+$11),$03
	jr      +++
	
++	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0010
	add     hl,de
	adc     a,$00
	ex      de,hl
	and     a
	jp      m,+
	ld      hl,$0400
	and     a
	sbc     hl,de
	jr      nc,+
	ld      de,$0400
+	ld      (ix+$0a),e
	ld      (ix+$0b),d
	ld      (ix+$0c),a
	ld      e,(ix+$12)
	ld      d,(ix+$13)
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	xor     a
	sbc     hl,de
	jr      c,+++
	ld      (ix+$04),a
	ld      (ix+$05),e
	ld      (ix+$06),d
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      (ix+$14),$1e
	res     0,(ix+$18)
+++	ld      de,_7de1
	ld      bc,_7ddc
	call    _7c41
	ld      a,(ix+$11)
	and     a
	jr      z,+
	dec     (ix+$11)
	ld      (ix+$0f),<_7df7
	ld      (ix+$10),>_7df7
+	ld      hl,$0204
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ret

_7ddc:
.db $00, $04, $01, $04, $FF

;this looks like sprite layout data, but isn't quite normal
_7de1:
.db $60, $62, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $64, $66, $FF, $FF
_7df7:
.db $FF, $FF, $FF, $FF, $68, $6A
.db $FF, $FF, $FF, $FF, $FF

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
	ld   (ix+11), a
	ld   (ix+12), a
	ld   a, ($D408)
	and  a
	jp   m, +
	ld   hl, $0806
	ld   (RAM_TEMP6), hl
	call _LABEL_3956_11
	jr   c, +
	ld   bc, $0010
	ld   e, (ix+10)
	ld   d, (ix+11)
	call _LABEL_7CC1_12
+	ld   a, ($D223)
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

;sprite layout
_7e89:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $18, $1A, $FF, $FF, $FF, $FF
.db $28, $2E, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$7E9B]___
;OBJECT: log - horizontal (Jungle)

_7e9b:
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

;sprite layout
_7ed9:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $6C, $6E, $6E, $48, $FF, $FF
.db $FF

;____________________________________________________________________________[$7EE6]___
;OBJECT: log - floating (Jungle)

_7ee6:
	set     5,(ix+$18)
	ld      (ix+$0d),$0a
	ld      (ix+$0e),$10
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffe8
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	set     0,(ix+$18)
+	ld      (ix+$0a),$40
	xor     a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      a,(ix+$11)
	cp      $14
	jr      c,+
	ld      (ix+$0a),$c0
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
+	ld      a,($d408)
	and     a
	jp      m,_8003
	ld      hl,$0806
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jp      c,_8003
	ld      bc,$0010
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	call    _LABEL_7CC1_12
	ld      hl,($d403)
	ld      a,l
	or      h
	jr      z,++
	ld      bc,$0012
	bit     7,h
	jr      z,+
	ld      bc,$fffe
+	ld      de,$0000
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
	jr      nz,+
++	ld      a,($d403)
	ld      de,($d404)
	sra     d
	rr      e
	rra     
+	ld      l,(ix+$02)
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
	jr      z,+
	ld      a,e
	cpl     
	ld      e,a
	ld      a,d
	cpl     
	ld      d,a
	inc     de
+	ld      l,(ix+$12)
	ld      h,(ix+$13)
	add     hl,de
	ld      a,h
	cp      $09
	jr      c,+
	sub     $09
	ld      h,a
+	ld      (ix+$12),l
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
.ORG $0000

.db $00, $00, $00

;jumped to by _7ee6, OBJECT: log - floating (Jungle)
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

;sprite layout
_8022:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $3A, $3C, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $FF, $FF, $FF, $FF, $FF
.db $36, $38, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $FF, $FF, $FF, $FF, $FF
.db $4C, $4E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$8053]___
;OBJECT: boss (Jungle)

_8053:
	set     5,(ix+$18)
	ld      (ix+$0d),$20
	ld      (ix+$0e),$1c
	bit     0,(ix+$18)
	jr      nz,+
	ld      hl,($d401)
	ld      de,$00e0
	and     a
	sbc     hl,de
	ret     nc
	ld      a,($d414)
	rlca    
	ret     nc
	;boss sprite set
	ld      hl,$aeb1
	ld      de,$2000
	ld      a,9
	call    decompressArt
	
	ld      hl,S1_BossPalette
	ld      a,$02
	call    loadPaletteOnInterrupt
	
	ld      a,index_music_boss1
	rst     $18			;`playMusic`
	
	xor     a
	ld      ($d2ec),a
	ld      hl,($d25a)
	ld      (RAM_LEVEL_CROPLEFT),hl
	ld      ($d275),hl
	ld      hl,($d25d)
	ld      (RAM_LEVEL_CROPTOP),hl
	ld      (RAM_LEVEL_EXTENDHEIGHT),hl
	ld      hl,$01f0
	ld      ($d27b),hl
	ld      hl,$0048
	ld      ($d27d),hl
	set     0,(ix+$18)
+	call    _7ca6
	bit     0,(ix+$11)
	jr      nz,+
	ld      (ix+$0f),<_81f4
	ld      (ix+$10),>_81f4
	ld      (ix+$0a),$80
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0058
	xor     a
	sbc     hl,de
	ret     c
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	set     0,(ix+$11)
+	ld      a,(ix+$12)
	and     a
	jp      nz,++
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	bit     1,(ix+$11)
	jr      nz,+
	ld      (ix+$0f),<_81f4
	ld      (ix+$10),>_81f4
	res     1,(ix+$18)
	ld      (ix+$07),$00
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      de,$021c
	and     a
	sbc     hl,de
	jp      nc,++++
	ld      (ix+$12),$67
	jp      ++++
	
+	ld      (ix+$0f),<_8206
	ld      (ix+$10),>_8206
	set     1,(ix+$18)
	ld      (ix+$07),$00
	ld      (ix+$08),$01
	ld      (ix+$09),$00
	ld      de,$02aa
	and     a
	sbc     hl,de
	jp      c,++++
	ld      (ix+$12),$67
	jp      ++++
	
++	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      hl,$0001
	dec     (ix+$12)
	jr      z,+
	ld      a,(ix+$12)
	cp      $40
	jr      nc,++
	ld      hl,$ffff
	cp      $28
	jr      c,++
	cp      $34
	jr      z,+++
+	ld      hl,$0000
++	ld      (ix+$0a),$00
	ld      (ix+$0b),l
	ld      (ix+$0c),h
	jr      ++++
	
+++	ld      a,(ix+$11)
	xor     $02
	ld      (ix+$11),a
	ld      a,($d2ec)
	cp      $08
	jr      nc,++++
	call    _7c7b
	ret     c
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	ld      (ix+$00),$2b
	xor     a
	ld      (ix+$01),a
	ld      hl,$000b
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,$0030
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      (ix+$11),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	call    _LABEL_625_57
	and     $3f
	add     a,$64
	ld      (ix+$12),a
	pop     ix
++++	ld      hl,$005a
	ld      ($d216),hl
	call    _77be
	call    _79fa
	ret

;sprite layout
_81f4:
.db $20, $22, $24, $26, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $54, $56, $58, $68, $FF
_8206:
.db $2A, $2C, $2E, $30, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $5A, $5C, $5E, $72, $FF

;____________________________________________________________________________[$8218]___
;OBJECT: UNKNOWN

_8218:
	res     5,(ix+$18)
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$10
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      l,(ix+$07)
	ld      h,(ix+$08)
	ld      a,(ix+$09)
	ld      de,$0002
	ld      c,$00
	and     a
	jp      m,+
	dec     c
	ld      de,$fffe
+	add     hl,de
	adc     a,c
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),a
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      c,a
	ld      a,h
	cp      $03
	jr      c,+
	ld      hl,$0300
	ld      c,$00
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      a,($d223)
	and     $01
	add     a,(ix+$11)
	ld      (ix+$11),a
	ld      a,(ix+$11)
	cp      (ix+$12)
	jr      nc,+
	ld      bc,_82c1
	ld      de,_82cd
	call    _7c41
	ret
	
+	jr      nz,+
	ld      a,($d223)
	and     $01
	ret     z
	ld      (ix+$16),$00
	ld      a,$01
	rst     $28			;`playSFX`
+	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      bc,_82c6
	ld      de,_a3bb
	call    _7c41
	ld      a,(ix+$12)
	add     a,$12
	cp      (ix+$11)
	ret     nc
	ld      (ix+$00),$ff
	ret

_82c1:
.db $00, $04, $01, $04, $FF
_82c6:
.db $01, $0C, $02, $0C, $03, $0C, $FF

;sprite layout
_82cd:
.db $08, $0A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $0C, $0E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$82E6]___
;OBJECT: badnick - Yadrin (Bridge)

_82e6:
	ld      (ix+$0d),$10
	ld      (ix+$0e),$0f
	ld      hl,$0408
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      (ix+$0d),$14
	ld      (ix+$0e),$20
	ld      hl,$1006
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0404
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      a,(ix+$11)
	cp      $50
	jr      c,+
	ld      (ix+$07),$40
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	ld      de,_837e
	ld      bc,_8379
	call    _7c41
	jp      ++
	
+	ld      (ix+$07),$c0
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      de,_837e
	ld      bc,_8374
	call    _7c41
++	ld      a,($d223)
	and     $07
	ret     nz
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $a0
	ret     c
	ld      (ix+$11),$00
	ret

_8374:
.db $00, $06, $01, $06, $FF
_8379:
.db $02, $06, $03, $06, $FF

;sprite layout
_837e:
.db $FE, $00, $02, $FF, $FF, $FF
.db $20, $22, $24, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $00, $02, $FF, $FF, $FF
.db $26, $28, $2A, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $40, $42, $FF, $FF, $FF, $FF
.db $4A, $4C, $4E, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $40, $42, $FF, $FF, $FF, $FF
.db $44, $46, $48, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$83C1]___
;OBJECT: UNKNOWN

_83c1:
	set     5,(ix+$18)
	ld      (ix+$0d),$0e
	ld      (ix+$0e),$08
	bit     0,(ix+$18)
	jr      nz,++
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      l,a
	ld      h,a
	ld      (RAM_TEMP1),hl
	bit     1,(ix+$18)
	jr      nz,+
	call    _LABEL_625_57
	and     $1f
	inc     a
	ld      (ix+$11),a
	set     1,(ix+$18)
+	dec     (ix+$11)
	jp      nz,++++
	ld      (ix+$11),$01
	ld      a,($d2ac)
	and     $80
	jp      z,++++
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      ($d2ab),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$000e
	add     hl,de
	ld      ($d2ad),hl
	ld      hl,$848e
	ld      ($d2af),hl
	set     0,(ix+$18)
	ld      a,$20
	rst     $28			;`playSFX`
++	ld      (ix+$0f),<_8481
	ld      (ix+$10),>_8481
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0020
	add     hl,de
	adc     a,$00
	ld      c,a
	ld      a,h
	cp      $04
	jr      c,++
	ld      h,$04
++	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      (RAM_TEMP1),hl
	ld      de,($d25d)
	inc     d
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	and     a
	sbc     hl,de
	jr      c,++++
	ld      (ix+$00),$ff
	ret
	
++++	ld      hl,$0402
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ret     c
	ld      a,($d408)
	and     a
	ret     m
	ld      de,(RAM_TEMP1)
	ld      bc,$0010
	call    _LABEL_7CC1_12
	ret

;sprite layout
_8481:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $70, $72, $FF, $FF, $FF, $FF
.db $FF

.db $00, $00, $00, $00, $00, $00, $00, $00

;____________________________________________________________________________[$8496]___
;OBJECT: boss (Bridge)

_8496:
	set     5,(ix+$18)
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$1c
	call    _7ca6
	ld      (ix+$0f),<_865a
	ld      (ix+$10),>_865a
	bit     0,(ix+$18)
	jr      nz,+
	ld      hl,$03a0
	ld      de,$0300
	call    _7c8c
	
	;UNKNOWN
	ld      hl,$e508
	ld      de,$2000
	ld      a,12
	call    decompressArt
	
	ld      hl,S1_BossPalette
	ld      a,$02
	call    loadPaletteOnInterrupt
	xor     a
	ld      ($d2ec),a
	
	ld      a,index_music_boss1
	rst     $18			;`playMusic`
	
	set     0,(ix+$18)
+	ld      a,(ix+$11)
	and     a
	jr      nz,+
	call    _LABEL_625_57
	and     $01
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_8632
	add     hl,de
	ld      a,(hl)
	ld      (ix+$02),a
	inc     hl
	ld      a,(hl)
	inc     hl
	ld      (ix+$03),a
	ld      a,(hl)
	inc     hl
	ld      (ix+$05),a
	ld      a,(hl)
	inc     hl
	ld      (ix+$06),a
	inc     (ix+$11)
	jp      +++
	
+	dec     a
	jr      nz,+
	ld      (ix+$0a),$80
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
	ld      hl,$0380
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	xor     a
	sbc     hl,de
	jp      c,+++
	inc     (ix+$11)
	ld      (ix+$12),a
	jp      +++
	
+	dec     a
	jr      nz,++
	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	inc     (ix+$12)
	ld      a,(ix+$12)
	cp      $64
	jp      nz,+++
	inc     (ix+$11)
	ld      a,($d2ec)
	cp      $08
	jr      nc,+++
	ld      hl,($d3fe)
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	ld      hl,_863a
	jr      c,+
	ld      hl,_864a
+	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	push    hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,bc
	ld      (RAM_TEMP3),hl
	pop     hl
	ld      b,$03
	
-	push    bc
	ld      a,(hl)
	ld      (RAM_TEMP4),a
	inc     hl
	ld      a,(hl)
	ld      (RAM_TEMP5),a
	inc     hl
	ld      a,(hl)
	ld      (RAM_TEMP6),a
	inc     hl
	ld      a,(hl)
	ld      (RAM_TEMP7),a
	inc     hl
	push    hl
	ld      c,$10
	call    _85d1
	pop     hl
	pop     bc
	djnz    -
	
	ld      a,$01
	rst     $28			;`playSFX`
	jp      +++
	
++	ld      (ix+$0a),$80
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
	ld      hl,$03c0
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	xor     a
	sbc     hl,de
	jr      nc,+++
	ld      (ix+$11),a
+++	ld      hl,$00a2
	ld      ($d216),hl
	call    _77be
	ret

;____________________________________________________________________________[$85D1]___

_85d1:
	push    bc
	call    _7c7b
	pop     bc
	ret     c
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$0d
	ld      hl,(RAM_TEMP1)
	ld      (ix+$01),a
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      hl,(RAM_TEMP3)
	ld      (ix+$04),a
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$13),c
	ld      (ix+$14),a
	ld      (ix+$15),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      hl,(RAM_TEMP4)
	xor     a
	bit     7,h
	jr      z,+
	dec     a
+	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),a
	ld      hl,(RAM_TEMP6)
	xor     a
	bit     7,h
	jr      z,+
	dec     a
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	pop     ix
	ret

_8632:
.db $D4, $03, $C0, $03, $44, $04, $C0, $03
_863a:
.db $00, $00, $F6, $FF, $C0, $FE, $00, $FC, $60, $FE, $80, $FD, $C0, $FD, $00, $FF
_864a:
.db $20, $00, $F6, $FF, $40, $01, $00, $FC, $A0, $01, $80, $FD, $40, $02, $00, $FF

;sprite layout
_865a:
.db $20, $22, $24, $26, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF

;____________________________________________________________________________[$866C]___
;OBJECT: balance (Bridge)

_866c:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      (ix+$11),$1c
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$fff0
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	set     0,(ix+$18)
+	ld      l,(ix+$14)
	ld      h,(ix+$15)
	ld      a,(ix+$16)
	ld      e,(ix+$12)
	ld      d,(ix+$13)
	ld      c,$00
	bit     7,d
	jr      z,+
	dec     c
+	add     hl,de
	adc     a,c
	ld      (ix+$14),l
	ld      (ix+$15),h
	ld      (ix+$16),a
	ld      c,h
	ld      b,a
	ld      hl,$0038
	add     hl,de
	ld      (ix+$12),l
	ld      (ix+$13),h
	bit     7,h
	jr      nz,++++
	rlca    
	jr      c,++++
	ld      a,(ix+$11)
	and     a
	jr      z,+++
	bit     1,(ix+$18)
	jr      z,++
	ld      a,l
	or      h
	jr      nz,+
	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
	jr      ++
	
+	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      de,($d2e6)
	add     hl,de
	ld      ($d406),hl
	ld      a,$ff
	ld      ($d408),a
++	ld      a,$1c
	sub     c
	ld      (ix+$11),a
	jr      z,+
	jr      nc,++++
+	bit     1,(ix+$18)
	jr      z,+++
	ld      a,$04
	rst     $28			;`playSFX`
+++	xor     a
	ld      (ix+$11),a
	ld      (ix+$12),a
	ld      (ix+$13),a
	ld      (ix+$14),a
	ld      (ix+$15),$1c
	ld      (ix+$16),a
++++	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      l,(ix+$11)
	ld      de,$0010
	add     hl,de
	ld      (RAM_TEMP6),hl
	ld      hl,_8830
	call    _881a
	ld      hl,$0028
	ld      (RAM_TEMP4),hl
	ld      a,$1c
	sub     (ix+$11)
	ld      l,a
	ld      h,$00
	ld      de,$0010
	add     hl,de
	ld      (RAM_TEMP6),hl
	ld      hl,_8830
	call    _881a
	ld      hl,$002c
	ld      (RAM_TEMP4),hl
	ld      l,(ix+$15)
	ld      h,(ix+$16)
	ld      (RAM_TEMP6),hl
	ld      hl,_8834
	call    _881a
	res     1,(ix+$18)
	ld      (ix+$0d),$14
	ld      a,$02
	ld      (RAM_TEMP6),a
	ld      a,(ix+$11)
	ld      c,a
	add     a,$08
	ld      (ix+$0e),a
	ld      a,c
	add     a,$04
	ld      (RAM_TEMP7),a
	call    _LABEL_3956_11
	jr      nc,+
	ld      a,($d408)
	and     a
	ret     m
	ld      (ix+$0d),$3c
	ld      a,$2a
	ld      (RAM_TEMP6),a
	ld      a,$1c
	sub     (ix+$11)
	add     a,$08
	ld      (ix+$0e),a
	ld      a,$1c
	sub     (ix+$11)
	add     a,$04
	ld      (RAM_TEMP7),a
	call    _LABEL_3956_11
	jr      nc,++
	ret
	
+	set     1,(ix+$18)
	ld      a,($d408)
	and     a
	ret     m
	ld      a,(ix+$11)
	cp      $1c
	jr      z,++
	ld      hl,($d406)
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      a,($d407)
	add     a,(ix+$11)
	ld      (ix+$11),a
	cp      $1c
	jr      c,+
	ld      (ix+$11),$1c
++	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
+	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,$0010
	add     hl,bc
	ld      a,(RAM_TEMP7)
	sub     $04
	ld      c,a
	add     hl,bc
	ld      a,($d40a)
	ld      c,a
	xor     a
	sbc     hl,bc
	ld      ($d401),hl
	ld      hl,$d414
	set     7,(hl)
	ret

;____________________________________________________________________________[$881A]___

_881a:
	ld      a,(hl)
	and     a
	ret     m
	push    hl
	call    _3581
	ld      hl,(RAM_TEMP4)
	ld      de,$0008
	add     hl,de
	ld      (RAM_TEMP4),hl
	pop     hl
	inc     hl
	jp      _881a

_8830:
.db $36, $38, $3A, $FF
_8834:
.db $3C, $3E, $FF

;____________________________________________________________________________[$8837]___
;OBJECT: badnick - Jaws (Labyrinth)

_8837:
	set     5,(ix+$18)
	ld      a,(ix+$11)
	cp      $80
	jr      nc,+
	ld      (ix+$07),$20
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	ld      (ix+$0d),$14
	ld      (ix+$0e),$0c
	ld      hl,$0a02
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0008
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ld      de,_88be
	ld      bc,_88b4
	call    _7c41
	jr      ++
	
+	ld      (ix+$07),$e0
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$0c
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ld      de,_88be
	ld      bc,_88b9
	call    _7c41
++	ld      a,($d223)
	and     $07
	ret     nz
	inc     (ix+$11)
	call    _LABEL_625_57
	and     $1e
	call    z,_91eb
	ret

_88b4:
.db $00, $04, $01, $04, $FF
_88b9:
.db $02, $04, $03, $04, $FF

;sprite layout
_88be:
.db $04, $2A, $2C, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $0C, $2A, $2C, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $0E, $10, $0A, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $0E, $10, $0C, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$88FB]___
;OBJECT: spike ball (Labyrinth)

_88fb:
	set     5,(ix+$18)
	ld      (ix+$0d),$08
	ld      (ix+$0e),$0c
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0008
	add     hl,de
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0008
	add     hl,de
	ld      (ix+$14),l
	ld      (ix+$15),h
	set     0,(ix+$18)
+	ld      l,(ix+$11)
	ld      h,$00
	add     hl,hl
	ld      de,_898e
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      c,(hl)
	ld      d,$00
	ld      b,d
	bit     7,e
	jr      z,+
	dec     d
+	bit     7,c
	jr      z,+
	dec     b
+	ld      l,(ix+$12)
	ld      h,(ix+$13)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$14)
	ld      h,(ix+$15)
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      hl,$0204
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      (ix+$0f),<_8987
	ld      (ix+$10),>_8987
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $b4
	ret     c
	ld      (ix+$11),$00
	ret

;sprite layout
_8987:
.db $60, $62, $FF, $FF, $FF, $FF
.db $FF

;I imagine this a set of X/Y positions to do the spiked-ball rotation
_898e:
;180 lines, ergo 2deg per frame?
.db $40, $00
.db $40, $02
.db $40, $04
.db $40, $07
.db $3F, $09
.db $3F, $0B
.db $3F, $0D
.db $3E, $0F
.db $3E, $12
.db $3D, $14
.db $3C, $16
.db $3B, $18
.db $3A, $1A
.db $3A, $1C
.db $39, $1E
.db $37, $20
.db $36, $22
.db $35, $24
.db $34, $26
.db $32, $27
.db $31, $29
.db $30, $2B
.db $2E, $2C
.db $2C, $2E
.db $2B, $30
.db $29, $31
.db $27, $32
.db $26, $34
.db $24, $35
.db $22, $36
.db $20, $37
.db $1E, $39
.db $1C, $3A
.db $1A, $3A
.db $18, $3B
.db $16, $3C
.db $14, $3D
.db $12, $3E
.db $0F, $3E
.db $0D, $3F
.db $0B, $3F
.db $09, $3F
.db $07, $40
.db $04, $40
.db $02, $40
.db $00, $40
.db $FE, $40
.db $FC, $40
.db $F9, $40
.db $F7, $3F
.db $F5, $3F
.db $F3, $3F
.db $F1, $3E
.db $EE, $3E
.db $EC, $3D
.db $EA, $3C
.db $E8, $3B
.db $E6, $3A
.db $E4, $3A
.db $E2, $39
.db $E0, $37
.db $DE, $36
.db $DC, $35
.db $DA, $34
.db $D9, $32
.db $D7, $31
.db $D5, $30
.db $D4, $2E
.db $D2, $2C
.db $D0, $2B
.db $CF, $29
.db $CE, $27
.db $CC, $26
.db $CB, $24
.db $CA, $22
.db $C9, $20
.db $C7, $1E
.db $C6, $1C
.db $C6, $1A
.db $C5, $18
.db $C4, $16
.db $C3, $14
.db $C2, $12
.db $C2, $0F
.db $C1, $0D
.db $C1, $0B
.db $C1, $09
.db $C0, $07
.db $C0, $04
.db $C0, $02
.db $C0, $00
.db $C0, $FE
.db $C0, $FC
.db $C0, $F9
.db $C1, $F7
.db $C1, $F5
.db $C1, $F3
.db $C2, $F1
.db $C2, $EE
.db $C3, $EC
.db $C4, $EA
.db $C5, $E8
.db $C6, $E6
.db $C6, $E4
.db $C7, $E2
.db $C9, $E0
.db $CA, $DE
.db $CB, $DC
.db $CC, $DA
.db $CE, $D9
.db $CF, $D7
.db $D0, $D5
.db $D2, $D4
.db $D4, $D2
.db $D5, $D0
.db $D7, $CF
.db $D9, $CE
.db $DA, $CC
.db $DC, $CB
.db $DE, $CA
.db $E0, $C9
.db $E2, $C7
.db $E4, $C6
.db $E6, $C6
.db $E8, $C5
.db $EA, $C4
.db $EC, $C3
.db $EE, $C2
.db $F1, $C2
.db $F3, $C1
.db $F5, $C1
.db $F7, $C1
.db $F9, $C0
.db $FC, $C0
.db $FE, $C0
.db $00, $C0
.db $02, $C0
.db $04, $C0
.db $07, $C0
.db $09, $C1
.db $0B, $C1
.db $0D, $C1
.db $0F, $C2
.db $12, $C2
.db $14, $C3
.db $16, $C4
.db $18, $C5
.db $1A, $C6
.db $1C, $C6
.db $1E, $C7
.db $20, $C9
.db $22, $CA
.db $24, $CB
.db $26, $CC
.db $27, $CE
.db $29, $CF
.db $2B, $D0
.db $2C, $D2
.db $2E, $D4
.db $30, $D5
.db $31, $D7
.db $32, $D9
.db $34, $DA
.db $35, $DC
.db $36, $DE
.db $37, $E0
.db $39, $E2
.db $3A, $E4
.db $3A, $E6
.db $3B, $E8
.db $3C, $EA
.db $3D, $EC
.db $3E, $EE
.db $3E, $F1
.db $3F, $F3
.db $3F, $F5
.db $3F, $F7
.db $40, $F9
.db $40, $FC
.db $40, $FE

;____________________________________________________________________________[$8AF6]___
;OBJECT: spear (Labyrinth)

_8af6:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$000c
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	set     0,(ix+$18)
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      a,($d223)
	rlca    
	rlca    
	and     $03
	jr      nz,+
	ld      hl,_8bbc
	ld      a,($d223)
	and     $3f
	ld      e,a
	cp      $08
	jr      c,++
	ld      hl,_8bcd
	ld      e,$00
	jr      ++
	
+	cp      $01
	jr      nz,+
	ld      hl,_8bcd
	ld      e,$00
	jr      ++
	
+	cp      $02
	jr      nz,+
	ld      hl,_8bc4
	ld      a,($d223)
	and     $3f
	ld      e,a
	cp      $08
	jr      c,++
	ld      hl,_8bcc
	ld      e,$00
	jr      ++
	
+	ld      hl,_8bcc
	ld      e,$00
++	ld      d,$00
	add     hl,de
	ld      a,(hl)
	ld      hl,_8bce
	add     a,a
	add     a,a
	add     a,a
	ld      e,a
	add     hl,de
	ld      b,$03
	
-	push    bc
	ld      a,(hl)
	inc     hl
	ld      e,(hl)
	inc     hl
	and     a
	jp      m,+
	push    hl
	ld      d,$00
	ld      (RAM_TEMP6),de
	call    _3581
	pop     hl
+	pop     bc
	djnz    -
	ld      (ix+$0f),b
	ld      (ix+$10),b
	ld      d,(hl)
	ld      e,$04
	ld      (RAM_TEMP6),de
	inc     hl
	ld      a,(hl)
	ld      (ix+$0d),$01
	ld      (ix+$0e),a
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      a,($d223)
	cp      $80
	ret     nz
	ld      a,$1d
	rst     $28			;`playSFX`
	ret

_8bbc:
.db $00 $01 $02 $03 $04 $05 $06 $07
_8bc4:
.db $07 $06 $05 $04 $03 $02 $01 $00
_8bcc:
.db $00
_8bcd:
.db $08
_8bce:
.db $12, $00, $32, $10, $32, $20, $01, $30, $12, $04, $32, $14, $32, $20, $02, $30
.db $12, $08, $32, $18, $32, $20, $06, $30, $12, $0C, $32, $1C, $32, $20, $0A, $30
.db $12, $10, $32, $20, $FF, $00, $0E, $30, $12, $14, $32, $20, $FF, $00, $12, $30
.db $12, $18, $32, $20, $FF, $00, $16, $30, $12, $1C, $32, $20, $FF, $00, $1A, $30
.db $12, $20, $FF, $00, $FF, $00, $1E, $30

;____________________________________________________________________________[$8C16]___
;OBJECT: fireball head (Labyrinth)

_8c16:
	res     5,(ix+$18)
	ld      (ix+$0d),$04
	ld      (ix+$0e),$0a
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$000a
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0008
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$14),l
	ld      (ix+$15),h
	ld      (ix+$11),$96
	set     0,(ix+$18)
	ld      bc,$0000
	ld      de,$0000
	call    _36f9
	ld      a,(hl)
	cp      $52
	jr      z,+
	set     1,(ix+$18)
+	ld      a,(ix+$11)
	and     a
	jr      z,++
	dec     (ix+$11)
	jr      z,+
-	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ret
	
+	ld      a,$18
	rst     $28			;`playSFX`
++	xor     a
	bit     1,(ix+$18)
	jr      nz,+
	ld      (ix+$07),$00
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      (ix+$0f),<_8d39
	ld      (ix+$10),>_8d39
	jr      ++
	
+	ld      (ix+$07),a
	ld      (ix+$08),$01
	ld      (ix+$09),a
	ld      (ix+$0f),<_8d41
	ld      (ix+$10),>_8d41
++	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	bit     6,(ix+$18)
	jr      nz,+
	bit     7,(ix+$18)
	jr      nz,+
	ld      hl,$0402
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      hl,($d25a)
	ld      bc,$fff0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25a)
	ld      bc,$0110
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,($d25d)
	ld      bc,$fff0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25d)
	ld      bc,$00d0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ret
	
+	ld      l,(ix+$12)
	ld      h,(ix+$13)
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$14)
	ld      h,(ix+$15)
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),$96
	jp      -

;sprite layout
_8d39:
.db $2E, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF
_8d41:
.db $30, $FF, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$8D48]___
;OBJECT: meta - water line position (Labyrinth)

_8d48:
	set     5,(ix+$18)
	ld      a,(ix+$11)
	ld      e,a
	ld      d,$00
	ld      hl,_8e36
	add     hl,de
	ld      e,(hl)
	ld      a,d
	bit     7,e
	jr      z,+
	dec     a
	dec     d
+	ld      l,(ix+$04)
	ld      h,(ix+$05)
	add     hl,de
	adc     a,(ix+$06)
	ld      (ix+$04),l
	ld      (ix+$05),h
	ld      (ix+$06),a
	ld      l,h
	ld      h,(ix+$06)
	ld      a,($d223)
	and     $0f
	jr      nz,+
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $20
	jr      c,+
	ld      (ix+$11),$00
+	ld      ($d2dc),hl
	ld      de,($d25d)
	and     a
	ld      a,$ff
	sbc     hl,de
	jr      c,+
	ex      de,hl
	ld      hl,$000c
	ld      a,$ff
	sbc     hl,de
	jr      nc,+
	ld      hl,$00b4
	xor     a
	sbc     hl,de
	jr      c,+
	ld      a,e
+	ld      (RAM_WATERLINE),a
	and     a
	ret     z
	cp      $ff
	ret     z
	add     a,$09
	ld      l,a
	ld      h,$00
	ld      (RAM_TEMP6),hl
	ld      hl,($d25a)
	ld      (RAM_TEMP1),hl
	ld      hl,($d25d)
	ld      (RAM_TEMP3),hl
	ld      a,(iy+vars.spriteCount)
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	push    af
	push    hl
	ld      hl,$d000
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      a,($d223)
	and     $03
	add     a,a
	add     a,a
	ld      c,a
	ld      b,$00
	ld      hl,_8e16
	add     hl,bc
	ld      b,$04
	
-	push    bc
	ld      c,(hl)
	inc     hl
	push    hl
	ld      a,($d223)
	and     $0f
	add     a,c
	ld      l,a
	ld      h,$00
	ld      (RAM_TEMP4),hl
	ld      a,$00
	call    _3581
	ld      hl,(RAM_TEMP4)
	ld      de,$0008
	add     hl,de
	ld      (RAM_TEMP4),hl
	ld      a,$02
	call    _3581
	pop     hl
	pop     bc
	djnz    -
	
	pop     hl
	pop     af
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      (iy+vars.spriteCount),a
	ret
	
_8e16:
.db $00, $40, $80, $C0, $10, $50, $90, $D0, $20, $60, $A0, $E0, $30, $70, $B0, $F0
.db $08, $48, $88, $C8, $18, $58, $98, $D8, $28, $68, $A8, $E8, $38, $78, $B8, $F8
_8e36:
.db $FE, $FC, $F8, $F0, $E8, $D8, $C8, $C8, $C8, $C8, $D8, $E8, $F0, $F8, $FC, $FE
.db $02, $04, $08, $10, $18, $28, $38, $38, $38, $38, $28, $18, $10, $08, $04, $02

;____________________________________________________________________________[$8E56]___
;OBJECT: bubbles (Labyrinth)

_8e56:
	set     5,(ix+$18)
	ld      a,(ix+$12)
	and     $7f
	jr      nz,+
	call    _LABEL_625_57
	and     $07
	ld      e,a
	ld      d,$00
	ld      hl,_8ec2
	add     hl,de
	bit     0,(hl)
	call    nz,_91eb
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      a,(ix+$11)
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_8eb6
	add     hl,de
	ld      e,(hl)
	ld      (RAM_TEMP4),de
	inc     hl
	ld      e,(hl)
	ld      (RAM_TEMP6),de
	ld      a,$0c
	call    _3581
	inc     (ix+$12)
	ld      a,($d223)
	and     $07
	ret     nz
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $06
	ret     c
	ld      (ix+$11),$00
	ret

_8eb6:
.db $08, $05, $08, $04, $07, $03
_8ebc:
.db $06, $02, $07, $01, $06, $00
_8ec2:
.db $01, $00, $01, $01, $00, $01, $00, $01

;____________________________________________________________________________[$8ECA]___
;OBJECT: UNKNOWN

_8eca:
	set 5, (ix+$18)
	xor a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      a,(ix+$11)
	and     $0f
	jr      nz,++
	call    _LABEL_625_57
	ld      bc,$0020
	ld      d,$00
	and     $3f
	cp      $20
	jr      c,+
	ld      bc,$ffe0
	ld      d,$ff
+	ld      (ix+$07),c
	ld      (ix+$08),b
	ld      (ix+$09),d
++	ld      (ix+$0a),$a0
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ex      de,hl
	ld      hl,($d25a)
	ld      bc,$0008
	xor     a
	sbc     hl,bc
	jr      nc,+
	ld      l,a
	ld      h,a
+	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25a)
	ld      bc,$0100
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ex      de,hl
	ld      hl,($d2dc)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25d)
	ld      bc,$fff0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25d)
	ld      bc,$00c0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,++
+	ld      (ix+$00),$ff
++	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      (RAM_TEMP6),hl
	ld      a,$0c
	call    _3581
	inc     (ix+$11)
	ret

;____________________________________________________________________________[$8F6C]___
;OBJECT: UNKNOWN

_8f6c:
	ret			;object nullified!

;____________________________________________________________________________[$8F6D]___
;OBJECT: badnick - Burrobot (Labyrinth)

_8f6d:
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$20
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0800
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$0010
	add     hl,de
	adc     a,$00
	ld      c,a
	jp      m,+
	ld      a,h
	cp      $04
	jr      c,+
	ld      hl,$0300
	ld      c,$00
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	bit     0,(ix+$18)
	jp      nz,++
	ld      de,$ffd0
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      de,($d3fe)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      bc,$0030
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	set     0,(ix+$18)
	ld      (ix+$0a),$80
	ld      (ix+$0b),$fd
	ld      (ix+$0c),$ff
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,($d3fe)
	and     a
	sbc     hl,de
	jr      c,+
	ld      (ix+$07),$c0
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      de,_9059
	ld      bc,_904a
	call    _7c41
	set     1,(ix+$18)
	ret
	
+	ld      (ix+$07),$40
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	ld      de,_9059
	ld      bc,_9045
	call    _7c41
	res     1,(ix+$18)
	ret
	
++	ld      bc,_9054
	bit     1,(ix+$18)
	jr      nz,+
	ld      bc,_904f
+	ld      de,_9059
	call    _7c41
	bit     7,(ix+$18)
	ret     z
	res     0,(ix+$18)
	ret

_9045:
.db $00, $04, $01, $04, $FF
_904a:
.db $02, $04, $03, $04, $FF
_904f:
.db $04, $04, $04, $04, $FF
_9054:
.db $05, $04, $05, $04, $FF

;sprite layout
_9059:
.db $44, $46, $FF, $FF, $FF, $FF
.db $64, $66, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $44, $46, $FF, $FF, $FF, $FF
.db $48, $4A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $50, $52, $FF, $FF, $FF, $FF
.db $70, $72, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $50, $52, $FF, $FF, $FF, $FF
.db $4C, $4E, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $44, $46, $FF, $FF, $FF, $FF
.db $68, $6A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $50, $52, $FF, $FF, $FF, $FF
.db $6C, $6E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$90C0]___
;OBJECT: platform - float up (Labyrinth)

_90c0:
	set     5,(ix+$18)
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$1c
	ld      (ix+$0f),<_91de
	ld      (ix+$10),>_91de
	bit     1,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (ix+$11),l
	ld      (ix+$12),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffff
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$13),l
	ld      (ix+$14),h
	set     1,(ix+$18)
+	ld      bc,$0010
	ld      de,$0020
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      a,(RAM_LEVEL_SOLIDITY)
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
	ld      c,$00
	ld      l,c
	ld      h,c
	cp      $1e
	jr      z,+
	bit     0,(ix+$18)
	jr      z,++
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$fff8
	add     hl,de
	adc     a,$ff
	ld      c,a
	ld      a,h
	neg     
	cp      $02
	jr      c,+
	ld      hl,$ff00
	ld      c,$ff
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
++	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      hl,($d25a)
	ld      bc,$ffe0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25a)
	inc     h
	and     a
	sbc     hl,de
	jr      c,+
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,($d25d)
	ld      bc,$ffe0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25d)
	ld      bc,$00e0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,++
+	ld      l,(ix+$11)
	ld      h,(ix+$12)
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$13)
	ld      h,(ix+$14)
	ld      (ix+$05),l
	ld      (ix+$06),h
	xor     a
	ld      (ix+$01),a
	ld      (ix+$04),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	res     0,(ix+$18)
	ret
	
++	ld      hl,$0e02
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ret     c
	set     0,(ix+$18)
	ld      a,($d407)
	and     a
	jp      p,+
	neg     
	cp      $02
	ret     nc
	
+	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	ld      bc,$0010
	call    _LABEL_7CC1_12
	ret

;sprite layout
_91de:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $16, $18, $1A, $1C, $FF, $FF
.db $FF

;____________________________________________________________________________[$91EB]___

_91eb:
	call    _7c7b
	ret     c
	ld      c,$42
	ld      a,(ix+$00)
	cp      $41
	jr      nz,+
	push    hl
	call    _LABEL_625_57
	and     $0f
	ld      e,a
	ld      d,$00
	ld      hl,_9257
	add     hl,de
	ld      c,(hl)
	pop     hl
+	ld      a,c
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

_9257:
.db $42, $20, $20, $20, $42, $20, $20, $20, $42, $20, $20, $20, $42, $20, $20, $20

;____________________________________________________________________________[$9267]___
;OBJECT: boss (Labyrinth)

_9267:
	set 5, (ix+$18)
	ld (ix+$0D), $20
	ld (ix+$0E), $1C
	call    _7ca6
	ld      (ix+$0f),<_9493
	ld      (ix+$10),>_9493
	bit     0,(ix+$18)
	jr      nz,+
	ld      hl,$02d0
	ld      de,$0290
	call    _7c8c
	set     1,(iy+vars.flags9)
	
	;UNKNOWN
	ld      hl,$e508
	ld      de,$2000
	ld      a,12
	call    decompressArt
	
	ld      hl,S1_BossPalette
	ld      a,$02
	call    loadPaletteOnInterrupt
	xor     a
	ld      ($d2ec),a
	
	ld      a,index_music_boss1
	rst     $18			;`playMusic`
	
	set     0,(ix+$18)
+	ld      a,(ix+$11)
	and     a
	jr      nz,+
	ld      a,(ix+$13)
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_947b
	add     hl,de
	ld      a,(hl)
	ld      (ix+$02),a
	inc     hl
	ld      a,(hl)
	inc     hl
	ld      (ix+$03),a
	ld      a,(hl)
	inc     hl
	ld      (ix+$05),a
	ld      a,(hl)
	inc     hl
	ld      (ix+$06),a
	inc     (ix+$11)
	jp      _f
	
+	dec     a
	jr      nz,+++
	ld      a,(ix+$13)
	and     a
	jr      nz,+
	ld      (ix+$0a),$80
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
	jp      ++
	
+	ld      (ix+$0a),$80
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
++	ld      hl,_9487
	ld      a,(ix+$13)
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	and     a
	sbc     hl,de
	jp      nz,_f
	inc     (ix+$11)
	ld      (ix+$12),$00
	jp      _f
	
+++	dec     a
	jp      nz,+
	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	inc     (ix+$12)
	ld      a,(ix+$12)
	cp      $64
	jp      nz,_f
	inc     (ix+$11)
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$000f
	add     hl,de
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,$0022
	add     hl,bc
	ld      (RAM_TEMP3),hl
	ld      a,(ix+$13)
	and     a
	jp      z,_9432
	ld      a,($d2ec)
	cp      $08
	jp      nc,_f
	call    _7c7b
	jp      c,_f
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$2f
	ld      hl,(RAM_TEMP1)
	ld      (ix+$01),a
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      hl,(RAM_TEMP3)
	ld      (ix+$04),a
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$18),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	pop     ix
	jp      _f
	
+	ld      a,(ix+$13)
	and     a
	jr      nz,+
	ld      (ix+$0a),$80
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
	jp      ++
	
+	ld      (ix+$0a),$80
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
++	ld      hl,$948d
	ld      a,(ix+$13)
	add     a,a
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	xor     a
	sbc     hl,de
	jr      nz,_f
	ld      (ix+$11),a
	inc     (ix+$13)
	ld      a,(ix+$13)
	cp      $03
	jr      c,_f
	ld      (ix+$13),$00
__	ld      hl,$00a2
	ld      ($d216),hl
	call    _77be
	ld      a,($d2ec)
	cp      $08
	ret     nc
	bit     7,(ix+$0c)
	ret     z
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$0010
	ld      (RAM_TEMP4),hl
	ld      hl,$0030
	ld      (RAM_TEMP6),hl
	ld      a,($d223)
	and     $02
	call    _3581
	ret
_9432:
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0004
	add     hl,de
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$fffa
	add     hl,de
	ld      (RAM_TEMP3),hl
	ld      hl,$ff00
	ld      (RAM_TEMP4),hl
	ld      hl,$ff00
	ld      (RAM_TEMP6),hl
	ld      c,$04
	call    _85d1
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0020
	add     hl,de
	ld      (RAM_TEMP1),hl
	ld      hl,$0100
	ld      (RAM_TEMP4),hl
	ld      c,$04
	call    _85d1
	ld      a,$01
	rst     $28			;`playSFX`
	jp      _b

_947b:
.db $3C, $03, $60, $03, $EC, $02, $60, $02, $8C, $03, $60, $02
_9487:
.db $28, $03, $B0, $02, $B0
_948c:
.db $02, $60, $03, $60, $02, $60, $02

;sprite layout
_9493:
.db $20, $22, $24, $26, $28, $FF
.db $40, $42, $44, $46, $48, $FF
.db $60, $62, $64, $66, $68, $FF

;____________________________________________________________________________[$94A5]___
;OBJECT: UNKNOWN

_94a5:
	set     5,(ix+$18)
	ld      (ix+$0d),$08
	ld      (ix+$0e),$0a
	ld      hl,$0404
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	bit     1,(ix+$18)
	jr      nz,+
	set     1,(ix+$18)
	ld      hl,($d3fe)
	ld      de,$000c
	add     hl,de
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,$0008
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	set     2,(ix+$18)
+	bit     0,(ix+$18)
	jr      nz,++
	ld      (ix+$0a),$40
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
	ld      hl,_9698
	bit     2,(ix+$18)
	jr      z,+
	ld      hl,_9688
+	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      hl,($d401)
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	and     a
	sbc     hl,de
	ret     nc
	set     0,(ix+$18)
	ret
	
++	ld      c,(ix+$02)
	ld      b,(ix+$03)
	ld      hl,$fff0
	add     hl,bc
	ld      de,($d25a)
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,c
	ld      h,b
	inc     d
	and     a
	sbc     hl,de
	jr      nc,+
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	ld      hl,$fff0
	add     hl,bc
	ld      de,($d25d)
	and     a
	sbc     hl,de
	jr      c,+
	ld      hl,$00c0
	add     hl,de
	and     a
	sbc     hl,bc
	jr      nc,++
+	ld      (ix+$00),$ff
++	xor     a
	ld      hl,$0002
	bit     2,(ix+$18)
	jr      nz,+
	dec     a
	ld      hl,$fffe
+	ld      e,(ix+$07)
	ld      d,(ix+$08)
	add     hl,de
	adc     a,(ix+$09)
	ld      c,a
	ld      a,h
	ld      de,$0100
	bit     7,c
	jr      z,+
	ld      a,l
	cpl     
	ld      e,a
	ld      a,h
	cpl     
	ld      d,a
	inc     de
	ld      a,d
	ld      de,$ff00
+	and     a
	jr      z,+
	ex      de,hl
+	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),c
	ld      hl,($d401)
	ld      de,$0010
	add     hl,de
	ex      de,hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,$0008
	add     hl,bc
	and     a
	sbc     hl,de
	ld      a,$ff
	ld      hl,$fffe
	bit     7,(ix+$0c)
	jr      nz,+
	ld      hl,$fffc
+	jr      nc,+
	inc     a
	ld      hl,$0002
	bit     7,(ix+$0c)
	jr      z,+
	ld      hl,$0004
+	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	add     hl,de
	adc     a,(ix+$0c)
	ld      c,a
	ld      a,h
	ld      de,$0100
	bit     7,c
	jr      z,+
	ld      a,l
	cpl     
	ld      e,a
	ld      a,h
	cpl     
	ld      d,a
	inc     de
	ld      a,d
	ld      de,$ff00
+	and     a
	jr      z,+
	ex      de,hl
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      hl,_9688
	bit     7,(ix+$09)
	jr      z,+
	ld      hl,_9698
+	push    hl
	ld      l,(ix+$07)
	ld      h,(ix+$08)
	bit     7,h
	jr      z,+
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
+	ld      e,(ix+$11)
	ld      d,(ix+$12)
	add     hl,de
	ld      (ix+$11),l
	ld      (ix+$12),h
	ld      a,h
	and     $08
	ld      e,a
	ld      d,$00
	pop     hl
	add     hl,de
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$fff9
	bit     7,(ix+$09)
	jr      z,+
	ld      de,$000f
+	add     hl,de
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      a,($d223)
	and     $0f
	ret     nz
	call    _7c7b
	ret     c
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$2a
	ld      hl,(RAM_TEMP1)
	ld      (ix+$01),a
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      hl,(RAM_TEMP3)
	ld      (ix+$04),a
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$12),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	pop     ix
	ret

;sprite layout
_9688:
.db $3C, $3E, $FF, $FF, $FF, $FF
.db $FF, $FF, $38, $3A, $FF, $FF
.db $FF, $FF, $FF, $FF
_9698:
.db $56, $58, $FF, $FF, $FF, $FF
.db $FF, $FF, $5A, $5C, $FF, $FF
.db $FF, $FF, $FF, $FF

;____________________________________________________________________________[$96A8]___
;OBJECT: UNKNOWN

_96a8:
	set     5,(ix+$18)
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      l,a
	ld      h,a
	ld      (RAM_TEMP4),hl
	ld      (RAM_TEMP6),hl
	ld      e,(ix+$12)
	ld      d,$00
	ld      hl,_96f5
	add     hl,de
	ld      a,(hl)
	call    _3581
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $0c
	ret     c
	ld      (ix+$11),$00
	inc     (ix+$12)
	ld      a,(ix+$12)
	cp      $03
	ret     c
	ld      (ix+$00),$ff
	ret

_96f5:
.db $1C, $1E, $5E

;____________________________________________________________________________[$96F8]___
;OBJECT: UNKNOWN

_96f8:
	set     5,(ix+$18)
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      a,(iy+vars.spriteCount)
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	push    af
	push    hl
	ld      a,($d2de)
	cp      $24
	jr      nc,+++
	ld      e,a
	ld      d,$00
	ld      hl,$d000
	add     hl,de
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      (RAM_TEMP6),hl
	ld      a,(ix+$12)
	and     a
	jr      z,+
	cp      $08
	jr      nc,+
	ld      hl,$0004
	ld      (RAM_TEMP4),hl
	ld      a,$0c
	jr      ++
	
+	ld      a,$40
	call    _3581
	ld      hl,(RAM_TEMP4)
	ld      de,$0008
	add     hl,de
	ld      (RAM_TEMP4),hl
	ld      a,$42
++	call    _3581
	ld      a,($d2de)
	add     a,$06
	ld      ($d2de),a
+++	pop     hl
	pop     af
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      (iy+vars.spriteCount),a
	ld      (ix+$0d),$0a
	ld      (ix+$0e),$0c
	ld      a,(ix+$12)
	and     a
	jr      z,+
	ld      c,$00
	ld      b,c
	ld      d,c
	ld      (ix+$0a),c
	ld      (ix+$0b),c
	ld      (ix+$0c),c
	dec     (ix+$12)
	jp      nz,++
	ld      (ix+$00),$ff
	jp      ++
	
+	ld      hl,$0206
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	ld      bc,($d401)
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,$fff8
	add     hl,de
	and     a
	sbc     hl,bc
	jr      nc,+
	ld      hl,$0006
	add     hl,de
	and     a
	sbc     hl,bc
	jr      c,+
	ld      a,(ix+$12)
	and     a
	jr      nz,+
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d406),hl
	ld      ($d408),a
	ld      ($d28e),a
	ld      ($d29b),hl
	set     2,(iy+vars.unknown0)
	ld      a,$20
	ld      ($d2fb),a
	ld      (ix+$12),$10
	ld      a,$22
	rst     $28			;`playSFX`
+	ld      (ix+$0a),$98
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
	ld      a,(ix+$11)
	and     $0f
	jr      nz,+
	call    _LABEL_625_57
	ld      bc,$0020
	ld      d,$00
	and     $3f
	cp      $20
	jr      c,++
	ld      bc,$ffe0
	ld      d,$ff
++	ld      (ix+$07),c
	ld      (ix+$08),b
	ld      (ix+$09),d
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ex      de,hl
	ld      hl,($d25a)
	ld      bc,$0008
	xor     a
	sbc     hl,bc
	jr      nc,+
	ld      l,a
	ld      h,a
+	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25a)
	ld      bc,$0100
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ex      de,hl
	ld      hl,($d2dc)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25d)
	ld      bc,$fff0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25d)
	ld      bc,$00c0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,++
+	ld      (ix+$00),$ff
++	inc     (ix+$11)
	ret

;____________________________________________________________________________[$9866]___
;OBJECT: flipper (Special Stage)

_9866:
	set     5,(ix+$18)
	ld      (ix+$0f),<_9a7e
	ld      (ix+$10),>_9a7e
	bit     5,(iy+vars.joypad)
	jr      nz,+
	ld      a,(ix+$11)
	ld      (ix+$12),a
	ld      a,(ix+$11)
	cp      $05
	jr      nc,++
	inc     (ix+$11)
	jp      ++
	
+	ld      a,(ix+$11)
	and     a
	jr      z,++
	dec     (ix+$11)
++	ld      a,(ix+$11)
	cp      $01
	jr      nc,+
	ld      hl,$140c
	ld      (RAM_TEMP6),hl
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$16
	call    _LABEL_3956_11
	ret     c
	ld      bc,_999e
	call    _9aaf
	ret     nc
	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
	ld      de,$fffc
	ld      hl,($d403)
	ld      a,($d405)
	add     hl,de
	adc     a,$ff
	ld      ($d403),hl
	ld      ($d405),a
	ret
	
+	cp      $04
	jp      nc,+
	ld      (ix+$0f),<_9a90
	ld      (ix+$10),>_9a90
	ld      hl,$080f
	ld      (RAM_TEMP6),hl
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$16
	call    _LABEL_3956_11
	ret     c
	ld      bc,_99be
	call    _9aaf
	ret     nc
	ld      a,(ix+$12)
	cp      (ix+$11)
	ret     nc
	ld      a,($d3fe)
	add     a,$0c
	and     $1f
	add     a,a
	ld      c,a
	ld      b,$00
	ld      hl,_99fe
	add     hl,bc
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      hl,($d403)
	ld      a,($d405)
	add     hl,de
	adc     a,$ff
	ld      ($d403),hl
	ld      ($d405),a
	ld      hl,_9a3e
	add     hl,bc
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
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
	adc     a,$ff
	ld      ($d406),hl
	ld      ($d408),a
	ret

	;unused section of code?
	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
	ld      de,$0008
	ld      hl,($d403)
	ld      a,($d405)
	add     hl,de
	adc     a,$00
	ld      ($d403),hl
	ld      ($d405),a
	ret
	
+	ld      (ix+$0f),<_9aa2
	ld      (ix+$10),>_9aa2
	ld      hl,$021a
	ld      (RAM_TEMP6),hl
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$16
	call    _LABEL_3956_11
	ret     c
	ld      bc,_99de
	call    _9aaf
	ret     nc
	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
	ld      de,$001a
	ld      hl,($d403)
	ld      a,($d405)
	add     hl,de
	adc     a,$00
	ld      ($d403),hl
	ld      ($d405),a
	ret

_999e:
.db $FF, $FF, $FE, $FE, $FE, $FD, $FD, $FD, $FC, $FC, $FC, $FC, $FB, $FB, $FB, $FB
.db $FA, $FA, $FA, $FA, $FA, $F9, $F9, $F9, $F9, $F9, $F9, $FA, $FA, $FB, $FC, $FE
_99be:
.db $EA, $EA, $EA, $F6, $F7, $F8, $F8, $F8, $F9, $F9, $F9, $FA, $FA, $FA, $FB, $FB
.db $FB, $FB, $FC, $FC, $FC, $FC, $FD, $FD, $FD, $FD, $FE, $FE, $FF, $00, $02, $04
_99de:
.db $EA, $EA, $EA, $EA, $EA, $EA, $EA, $EA, $EA, $EA, $EA, $EA, $EE, $ED, $EC, $EC
.db $EC, $ED, $EE, $EF, $F0, $F2, $F3, $F4, $F5, $F7, $F8, $F9, $FA, $FB, $FD, $FF
_99fe:
.db $00, $F8, $00, $F8, $00, $F9, $00, $FA, $00, $FB, $00, $FC, $E0, $FC, $80, $FD
.db $C0, $FD, $00, $FE, $40, $FE, $80, $FE, $C0, $FE, $00, $FF, $20, $FF, $40, $FF
.db $60, $FF, $80, $FF, $A0, $FF, $C0, $FF, $E0, $FF, $E8, $FF, $EA, $FF, $EC, $FF
.db $EE, $FF, $F0, $FF, $F2, $FF, $F4, $FF, $F6, $FF, $F8, $FF, $FC, $FF, $FE, $FF
_9a3e:
.db $00, $FC, $00, $FC, $00, $FC, $00, $FB, $00, $FA, $00, $F9, $00, $F8, $00, $F7
.db $00, $F6, $80, $F5, $00, $F5, $C0, $F4, $80, $F4, $40, $F4, $00, $F4, $00, $F4
.db $00, $F4, $00, $F4, $40, $F4, $80, $F4, $C0, $F4, $00, $F5, $00, $F6, $00, $F7
.db $00, $F9, $00, $FA, $00, $FC, $80, $FC, $00, $FD, $C0, $FD, $00, $FF, $00, $FF

;sprite layout
_9a7e:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $38, $3A, $3C, $3E, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_9a90:
.db $48, $4A, $4C, $4E, $FF, $FF
.db $68, $6A, $6C, $6E, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_9aa2:
.db $FE, $12, $14, $16, $FF, $FF
.db $FE, $32, $34, $36, $FF, $FF
.db $FF

;____________________________________________________________________________[$9AAF]___

_9aaf:
	ld      a,($d408)
	and     a
	ret     m
	ld      a,($d3fe)
	add     a,$0c
	and     $1f
	ld      l,a
	ld      h,$00
	add     hl,bc
	ld      b,$00
	ld      c,(hl)
	bit     7,c
	jr      z,+
	dec     b
+	ld      l,(ix+$05)
	ld      h,(ix+$06)
	add     hl,bc
	ld      ($d401),hl
	ld      a,($d407)
	cp      $03
	jr      nc,+
	scf     
	ret
	
+	ld      de,$0001
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
	sra     a
	rr      h
	rr      l
	ld      ($d406),hl
	ld      ($d408),a
	and     a
	ret

;____________________________________________________________________________[$9AFB]___
;OBJECT: moving bumper (Special Stage)

_9afb:
	set     5,(ix+$18)
	ld      (ix+$0d),$1c
	ld      (ix+$0e),$06
	ld      (ix+$0f),<_9b6e
	ld      (ix+$10),>_9b6e
	ld      hl,$0001
	ld      a,(ix+$12)
	cp      $60
	jr      nc,+
	ld      hl,$ffff
+	ld      (ix+$07),$00
	ld      (ix+$08),l
	ld      (ix+$09),h
	inc     a
	cp      $c0
	jr      c,+
	xor     a
+	ld      (ix+$12),a
	ld      a,(ix+$11)
	and     a
	jr      nz,+
	ld      hl,$0602
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ret     c
	ld      a,($d2e8)
	ld      de,($d2e6)
	ld      c,a
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
	adc     a,c
	ld      de,$0001
	add     hl,de
	adc     a,$00
	ld      ($d406),hl
	ld      ($d408),a
	ld      (ix+$11),$08
	ld      a,$07
	rst     $28			;`playSFX`
	ret
	
+	dec     (ix+$11)
	ret

;sprite layout
_9b6e:
.db $08, $0A, $28, $2A, $FF, $FF
.db $FF

;____________________________________________________________________________[$9B75]___
;OBJECT: UNKNOWN

_9b75:
	set     5,(ix+$18)
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$60
	ld      hl,$0000
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      e,h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      a,l
	add     a,a
	rl      h
	add     a,a
	rl      h
	add     a,a
	rl      h
	ld      d,h
	ld      hl,_9bd9
	ld      b,$05
	
-	ld      a,(hl)
	inc     hl
	cp      e
	jr      nz,+
	ld      a,(hl)
	cp      d
	jr      nz,+
	inc     hl
	ld      a,(hl)
	ld      ($d2d3),a
	ld      a,$01
	ld      ($d289),a
	set     4,(iy+vars.flags6)
	jp      ++
	
+	inc     hl
	inc     hl
	djnz    -
	
++	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ret

_9bd9:
.db $7D, $1A, $15, $7D, $01, $14, $01, $3C, $18, $01, $02
_9be4:
.db $19, $14, $0F, $1A

;____________________________________________________________________________[$9BE8]___
;OBJECT: UNKNOWN

_9be8:
	ld      (ix+$07),$80
	ld      (ix+$08),$01
	ld      (ix+$09),$00
	ld      (ix+$0f),<_9c69
	ld      (ix+$10),>_9c69
_9bfc:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      a,(ix+$02)
	ld      (ix+$11),a
	ld      a,(ix+$03)
	ld      (ix+$12),a
	ld      a,$18
	rst     $28			;`playSFX`
	set     0,(ix+$18)
+	ld      (ix+$0d),$06
	ld      (ix+$0e),$08
	ld      a,(ix+$13)
	cp      $64
	jr      nc,+
	ld      hl,$0400
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
+	inc     (ix+$13)
	ld      a,(ix+$13)
	cp      $64
	ret     c
	cp      $f0
	jr      c,+
	xor     a
	ld      (ix+$01),a
	ld      (ix+$13),a
	ld      a,(ix+$11)
	ld      (ix+$02),a
	ld      a,(ix+$12)
	ld      (ix+$03),a
	ld      a,$18
	rst     $28			;`playSFX`
	ret
	
+	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ret

;sprite layout
_9c69:
.db $0C, $0E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$9C70]___
;OBJECT: UNKNOWN

_9c70:
	ld      (ix+$07),$80
	ld      (ix+$08),$fe
	ld      (ix+$09),$ff
	ld      (ix+$0f),<_9c87
	ld      (ix+$10),>_9c87
	jp      _9bfc

;sprite layout
_9c87:
.db $2C, $2E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$9C8E]___
;OBJECT: flame thrower - scrap brain

_9c8e:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$000c
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0012
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	call    _LABEL_625_57
	ld      (ix+$11),a
	set     0,(ix+$18)
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      a,(ix+$11)
	srl     a
	srl     a
	srl     a
	srl     a
	ld      c,a
	ld      b,$00
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_9d6a
	add     hl,bc
	ld      a,(hl)
	ld      (ix+$0e),a
	ld      (ix+$0d),$06
	ld      hl,_9d4a
	add     hl,de
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	or      h
	jr      z,+
	ld      a,(ix+$11)
	add     a,a
	add     a,a
	add     a,a
	and     $1f
	ld      e,a
	ld      d,$00
	add     hl,de
	ld      b,$04
	
-	push    bc
	ld      a,(hl)
	inc     hl
	ld      e,(hl)
	inc     hl
	ld      d,$00
	push    hl
	ld      (RAM_TEMP6),de
	call    _3581
	pop     hl
	pop     bc
	djnz    -
	
	ld      a,(ix+$0e)
	and     a
	jr      z,+
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
+	inc     (ix+$11)
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      a,(ix+$11)
	cp      $70
	ret     nz
	ld      a,$17
	rst     $28			;`playSFX`
	ret

_9d4a:
.db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $9A, $9D
.db $BA, $9D, $DA, $9D, $7A, $9D, $7A, $9D, $7A, $9D, $DA, $9D, $BA, $9D, $9A, $9D
_9d6a:
.db $00, $00, $00, $00, $00, $00, $00, $1B, $1F, $22, $25, $25, $25, $22, $1F, $1B
.db $00, $15, $1E, $0E, $1E, $07, $1E, $00, $00, $17, $1E, $10, $1E, $09, $1E, $02
.db $00, $19, $1E, $12, $1E, $0B, $1E, $04, $00, $1B, $1E, $14, $1E, $0D, $1E, $06
.db $00, $0C, $1E, $08, $1E, $04, $1E, $00, $00, $0E, $1E, $0A, $1E, $06, $1E, $02
.db $00, $10, $1E, $0C, $1E, $08, $1E, $04, $00, $11, $1E, $0E, $1E, $0A, $1E, $06
.db $00, $0F, $1E, $0A, $1E, $05, $1E, $00, $00, $11, $1E, $0C, $1E, $07, $1E, $02
.db $00, $13, $1E, $0E, $1E, $09, $1E, $04, $00, $15, $1E, $10, $1E, $0B, $1E, $06
.db $00, $12, $1E, $0C, $1E, $06, $1E, $00, $00, $14, $1E, $0E, $1E, $08, $1E, $02
.db $00, $16, $1E, $10, $1E, $0A, $1E, $04, $00, $18, $1E, $12, $1E, $0C, $1E, $06

;____________________________________________________________________________[$9DFA]___
;OBJECT: door - one way left (Scrap Brain)

_9dfa:
	set     5,(ix+$18)
	call    _9ed4
	ld      a,(ix+$11)
	cp      $28
	jr      nc,++
	ld      hl,$0005
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      de,$0005
	ld      a,($d405)
	and     a
	jp      m,+
	ld      de,$ffec
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      ($d3fe),hl
	xor     a
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
++	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$ffc8
	add     hl,de
	ld      de,($d3fe)
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffe0
	add     hl,de
	ld      de,($d401)
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,$0050
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	call    _9eb4
	jr      ++
	
+	call    _9ec4
++:
	ld      de,_9f2b
_9e7e:
	ld      a,(ix+$11)
	and     $0f
	ld      c,a
	ld      b,$00
	ld      l,(ix+$12)
	ld      h,(ix+$13)
	and     a
	sbc     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      a,(ix+$11)
	srl     a
	srl     a
	srl     a
	srl     a
	and     $03
	add     a,a
	ld      c,a
	add     a,a
	add     a,a
	add     a,a
	add     a,c
	ld      c,a
	ld      b,$00
	ex      de,hl
	add     hl,bc
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ret

;____________________________________________________________________________[$9EB4]___

_9eb4:
	ld      a,(ix+$11)
	cp      $30
	ret     nc
	inc     a
	ld      (ix+$11),a
	dec     a
	ret     nz
	ld      a,$19
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$9EC4]___

_9ec4:
	ld      a,(ix+$11)
	and     a
	ret     z
	dec     a
	ld      (ix+$11),a
	cp      $2f
	ret     nz
	ld      a,$19
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$9ED4]___

_9ed4:
	ld      (ix+$0d),$04
	ld      a,(ix+$11)
	srl     a
	srl     a
	srl     a
	srl     a
	and     $03
	ld      e,a
	ld      a,$03
	sub     e
	add     a,a
	add     a,a
	add     a,a
	add     a,a
	ld      (ix+$0e),a
	bit     0,(ix+$18)
	ret     nz
	ld      bc,$0000
	ld      de,$fff0
	call    _36f9
	ld      de,$0014
	ld      a,(hl)
	cp      $a3
	jr      z,+
	ld      de,$0004
	set     1,(ix+$18)
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,(ix+$05)
	ld      (ix+$12),a
	ld      a,(ix+$06)
	ld      (ix+$13),a
	set     0,(ix+$18)
	ret

;sprite layout
_9f2b:
.db $0A, $FF, $FF, $FF, $FF, $FF
.db $3E, $FF, $FF, $FF, $FF, $FF
.db $0A, $FF, $FF, $FF, $FF, $FF

.db $3E, $FF, $FF, $FF, $FF, $FF
.db $0A, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $0A, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$9F62]___
;OBJECT: door - one way right (Scrap Brain)

_9f62:
	set     5,(ix+$18)
	call    _9ed4
	ld      a,(ix+$11)
	cp      $28
	jr      nc,++
	ld      hl,$0005
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      de,$0005
	ld      a,($d405)
	and     a
	jp      m,+
	ld      de,$ffec
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      ($d3fe),hl
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
++	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$fff0
	add     hl,de
	ld      de,($d3fe)
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,$0024
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffe0
	add     hl,de
	ld      de,($d401)
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,$0050
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	call    _9eb4
	jr      ++
+	call    _9ec4
++	ld      de,_9fee
	jp      _9e7e

;sprite layout
_9fee:
.db $36, $FF, $FF, $FF, $FF, $FF
.db $3E, $FF, $FF, $FF, $FF, $FF
.db $36, $FF, $FF, $FF, $FF, $FF

.db $3E, $FF, $FF, $FF, $FF, $FF
.db $36, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $36, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$A025]___
;OBJECT: door (Scrap Brain)

_a025:
	set     5,(ix+$18)
	call    _9ed4
	ld      a,(ix+$11)
	cp      $28
	jr      nc,++
	ld      hl,$0005
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      de,$0005
	ld      a,($d405)
	and     a
	jp      m,+
	ld      de,$ffec
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      ($d3fe),hl
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
++	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$ffc8
	add     hl,de
	ld      de,($d3fe)
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,$0024
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffe0
	add     hl,de
	ld      de,($d401)
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,$0050
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	call    _9eb4
	jr      ++
	
+	call    _9ec4
++	ld      de,_a0b1
	jp      _9e7e

;sprite layout
_a0b1:
.db $38, $FF, $FF, $FF, $FF, $FF
.db $3E, $FF, $FF, $FF, $FF, $FF
.db $38, $FF, $FF, $FF, $FF, $FF

.db $3E, $FF, $FF, $FF, $FF, $FF
.db $38, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $38, $FF, $FF, $FF, $FF, $FF

.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$A0E8]___
;OBJECT: electric sphere (Scrap Brain)

_a0e8:
	set     5,(ix+$18)
	ld      (ix+$0d),$30
	ld      (ix+$0e),$10
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0018
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0010
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	set     0,(ix+$18)
+	ld      a,(ix+$11)
	cp      $64
	jr      c,++
	jr      nz,+
	ld      a,$13
	rst     $28			;`playSFX`
+	ld      hl,$0000
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      de,_a173
	ld      bc,_a167
	call    _7c41
	jp      +++
	
++	cp      $46
	jr      nc,+
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	jp      +++
	
+	ld      de,_a173
	ld      bc,_a16e
	call    _7c41
+++	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $a0
	ret     c
	ld      (ix+$11),$00
	ret

_a167:
.db $00, $01, $01, $01, $02, $01, $FF
_a16e:
.db $02, $01, $03, $01, $FF

;sprite layout
_a173:
.db $02, $04, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $FE, $FE, $FE, $02, $04
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $FE, $16, $18, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$A1AA]___
;OBJECT: badnick - Ball Hog (Scrap Brain)

_a1aa:
	ld      (ix+$0d),$0a
	ld      (ix+$0e),$20
	ld      hl,$0803
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0e00
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ld      (ix+$0a),$00
	ld      (ix+$0b),$01
	ld      (ix+$0c),$00
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$000a
	add     hl,de
	ex      de,hl
	ld      hl,($d3fe)
	ld      bc,$000c
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+++
	ld      bc,_a2d2
	ld      a,(ix+$11)
	cp      $eb
	jr      c,++
	jr      nz,+
	ld      (ix+$16),$00
+	ld      bc,_a2d7
++	ld      de,_a2da
	call    _7c41
	ld      a,(ix+$11)
	cp      $ed
	jp      nz,++++
	call    _7c7b
	jp      c,++++
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$1c
	ld      (ix+$01),a
	ld      (ix+$02),e
	ld      (ix+$03),d
	ld      hl,$0006
	add     hl,bc
	ld      (ix+$04),a
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$07),a
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      (ix+$0a),a
	ld      (ix+$0b),$01
	ld      (ix+$0c),a
	pop     ix
	jp      ++++
	
+++	ld      bc,_a2d2
	ld      a,(ix+$11)
	cp      $eb
	jr      c,++
	jr      nz,+
	ld      (ix+$16),$00
+	ld      bc,_a2d7
++	ld      de,_a30b
	call    _7c41
	ld      a,(ix+$11)
	cp      $ed
	jr      nz,++++
	call    _7c7b
	jp      c,++++
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$1c
	ld      (ix+$01),a
	ld      (ix+$02),e
	ld      (ix+$03),d
	ld      hl,$0006
	add     hl,bc
	ld      (ix+$04),a
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$07),a
	ld      (ix+$08),$01
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),$01
	ld      (ix+$0c),a
	pop     ix
++++	inc     (ix+$11)
	ret

_a2d2:
.db $00, $1C, $01, $06, $FF
_a2d7:
.db $02, $18, $FF

;sprite layout
_a2da:
.db $40, $42, $FF, $FF, $FF, $FF
.db $60, $62, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $44, $46, $FF, $FF, $FF, $FF
.db $64, $66, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $40, $42, $FF, $FF, $FF, $FF
.db $68, $6A, $FF, $FF, $FF, $FF
.db $FF

_a30b:
.db $50, $52, $FF, $FF, $FF, $FF
.db $70, $72, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $4C, $4E, $FF, $FF, $FF, $FF
.db $6C, $6E, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $50, $52, $FF, $FF, $FF, $FF
.db $48, $4A, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$A33C]___
;OBJECT: UNKNOWN (ball from Ball Hog?)

_a33c:
	res     5,(ix+$18)
	ld      (ix+$0d),$0a
	ld      (ix+$0e),$0f
	ld      hl,$0101
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	bit     7,(ix+$18)
	jr      z,+
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fd
	ld      (ix+$0c),$ff
+	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$001f
	add     hl,de
	adc     a,$00
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      a,(ix+$11)
	cp      $82
	jr      nc,+
	ld      bc,_a3b1
	ld      de,_a3bb
	call    _7c41
	jp      ++
	
+	jr      nz,+
	ld      (ix+$16),$00
	ld      a,$01
	rst     $28			;`playSFX`
+	ld      bc,_a3b4
	ld      de,_a3bb
	call    _7c41
++	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $a5
	ret     c
	ld      (ix+$00),$ff
	ret

_a3b1:
.db $00, $08, $FF
_a3b4:
.db $01, $0C, $02, $0C, $03, $0C, $FF

;sprite layout
_a3bb:
.db $20, $22, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $74, $76, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $78, $7A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $7C, $7E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$A3F8]___
;OBJECT: switch

_a3f8:
	ld      (ix+$0d),$0a
	ld      (ix+$0e),$11
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0008
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	set     0,(ix+$18)
+	ld      hl,$0001
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      a,($d408)
	and     a
	jp      m,++
	ld      (ix+$0f),<_a48b
	ld      (ix+$10),>_a48b
	ld      a,(RAM_LEVEL_SOLIDITY)
	cp      $03
	jr      nz,+
	ld      (ix+$0f),<_a49b
	ld      (ix+$10),>_a49b
+	ld      bc,$0006
	ld      de,$0000
	call    _LABEL_7CC1_12
	bit     1,(ix+$18)
	jr      nz,+
	set     1,(ix+$18)
	ld      hl,$d317
	call    getLevelBitFlag
	ld      a,(hl)
	xor     c
	ld      (hl),a
	ld      a,$1a
	rst     $28			;`playSFX`
	jr      +
	
++	res     1,(ix+$18)
	ld      (ix+$0f),<_a493
	ld      (ix+$10),>_a493
	ld      a,(RAM_LEVEL_SOLIDITY)
	cp      $03
	jr      nz,+
	ld      (ix+$0f),$a3
	ld      (ix+$10),$a4
+	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),$02
	ld      (ix+$0c),a
	ret

;sprite layout
_a48b:
.db $1A, $1C, $FF, $FF, $FF, $FF
.db $FF, $FF
_a493:
.db $3A, $3C, $FF, $FF, $FF, $FF
.db $FF, $FF
_a49b:
.db $38, $3A, $FF, $FF, $FF, $FF
.db $FF, $FF, $34, $36, $FF, $FF
.db $FF, $FF, $FF, $FF

;____________________________________________________________________________[$A4AB]___
;OBJECT: switch door

_a4ab:
	set     5,(ix+$18)
	call    _9ed4
	ld      a,(ix+$11)
	cp      $28
	jr      nc,++
	ld      hl,$0005
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,++
	ld      de,$0005
	ld      a,($d405)
	and     a
	jp      m,+
	ld      de,$ffec
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	add     hl,de
	ld      ($d3fe),hl
	xor     a
	ld      ($d403),a
	ld      ($d404),a
	ld      ($d405),a
	
++	ld      hl,$d317
	call    getLevelBitFlag
	bit     1,(ix+$18)
	jr      z,+
	ld      a,(hl)
	and     c
	jr      nz,+++
	jr      ++
	
+	ld      a,(hl)
	and     c
	jr      z,+++
++	ld      a,(ix+$11)
	cp      $30
	jr      nc,+
	inc     a
	inc     a
	ld      (ix+$11),a
	jr      +
	
+++	ld      a,(ix+$11)
	and     a
	jr      z,+
	dec     a
	dec     a
	ld      (ix+$11),a
+	ld      de,_a51a
	jp      _9e7e

;sprite layout
_a51a:
.db $3E, $FF, $FF, $FF, $FF, $FF
.db $38, $FF, $FF, $FF, $FF, $FF
.db $3E, $FF, $FF, $FF, $FF, $FF

.db $38, $FF, $FF, $FF, $FF, $FF
.db $3E, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $3E, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$A551]___
;OBJECT: badnick - Caterkiller

_a551:
	ld      (ix+$0d),$06
	ld      (ix+$0e),$10
	ld      a,($d223)
	and     $01
	jr      nz,+++
	ld      hl,_a6b9
	bit     1,(ix+$18)
	jr      z,+
	ld      hl,_a769
+	ld      e,(ix+$11)
	sla     e
	ld      d,$00
	add     hl,de
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	ld      l,(ix+$01)
	ld      h,(ix+$02)
	ld      a,(ix+$03)
	add     hl,bc
	bit     7,b
	jr      z,+
	adc     a,$ff
	jr      ++
	
+	adc     a,$00
++	ld      (ix+$01),l
	ld      (ix+$02),h
	ld      (ix+$03),a
	ld      hl,_a6e5
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      l,(ix+$12)
	ld      h,(ix+$13)
	add     hl,de
	ld      (ix+$12),l
	ld      (ix+$13),h
	ld      c,$00
	bit     7,h
	jr      z,+
	ld      c,$ff
+	ld      (ix+$14),c
+++	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	bit     1,(ix+$18)
	jr      nz,++
	ld      hl,_a711
	ld      e,(ix+$11)
	ld      d,$00
	add     hl,de
	ld      a,$24
	call    _a688
	ld      a,$26
	call    _a6a2
	ld      a,$26
	call    _a688
	ld      a,$26
	call    _a6a2
	ld      (ix+$0d),$06
	ld      hl,$0802
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	jr      c,+
	call    _35e5
	jr      +++
	
+	ld      (ix+$0d),$16
	ld      hl,$0806
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	jr      +++
	
++	ld      hl,_a795
	ld      e,(ix+$11)
	ld      d,$00
	add     hl,de
	ld      a,$2a
	call    _a688
	ld      a,$28
	call    _a6a2
	ld      a,$28
	call    _a688
	ld      a,$28
	call    _a6a2
	ld      (ix+$0d),$10
	ld      hl,$0401
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	call    _35fd
	jr      +++
	
+	ld      (ix+$0d),$16
	ld      hl,$0410
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$0000
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
+++	ld      (ix+$0b),$01
	ld      a,($d223)
	and     $01
	ret     nz
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $16
	ret     c
	ld      (ix+$11),$00
	inc     (ix+$15)
	ld      a,(ix+$15)
	cp      $14
	ret     c
	ld      (ix+$15),$00
	ld      a,(ix+$18)
	xor     $02
	ld      (ix+$18),a
	ret

;____________________________________________________________________________[$A688]___

_a688:
	push    hl
	ld      e,(hl)
	ld      d,$00
	ld      (RAM_TEMP4),de
	ld      l,(ix+$13)
	ld      h,(ix+$14)
	ld      (RAM_TEMP6),hl
	call    _3581
	pop     hl
	ld      de,$0016
	add     hl,de
	ret

;____________________________________________________________________________[$A6A2]___

_a6a2:
	push    hl
	ld      e,(hl)
	ld      d,$00
	ld      (RAM_TEMP4),de
	ld      hl,$0000
	ld      (RAM_TEMP6),hl
	call    _3581
	pop     hl
	ld      de,$0016
	add     hl,de
	ret

_a6b9:
.db $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
.db $00 $00 $00 $00 $00 $00 $E0 $FF $E0 $FF $E0 $FF $E0 $FF $C0 $FF
.db $C0 $FF $80 $FF $80 $FF $00 $FF $00 $FF $00 $FE
_a6e5:
.db $00 $FF $80 $FF $80 $FF $C0 $FF $C0 $FF $E0 $FF $E0 $FF $F0 $FF
.db $F0 $FF $F0 $FF $F0 $FF $10 $00 $10 $00 $10 $00 $10 $00 $20 $00
.db $20 $00 $40 $00 $40 $00 $80 $00 $80 $00 $00 $01
_a711:
.db $00 $01 $02 $02 $03 $03 $03 $03 $03 $03 $03 $03 $03 $03 $03 $03
.db $03 $03 $02 $02 $01 $00 $07 $07 $07 $07 $07 $07 $07 $07 $07 $07
.db $07 $07 $07 $07 $07 $07 $07 $07 $07 $07 $07 $07 $0E $0D $0C $0C
.db $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0B $0C $0C
.db $0D $0E $15 $13 $12 $11 $10 $10 $0F $0F $0F $0F $0F $0F $0F $0F
.db $0F $0F $10 $10 $11 $12 $13 $15
_a769:
.db $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00 $00
.db $00 $00 $00 $00 $00 $00 $20 $00 $20 $00 $20 $00 $20 $00 $40 $00
.db $40 $00 $80 $00 $80 $00 $00 $01 $00 $01 $00 $02
_a795:
.db $15 $14 $13 $13 $12 $12 $12 $12 $12 $12 $12 $12 $12 $12 $12 $12
.db $12 $12 $13 $13 $14 $15 $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E
.db $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E $0E $07 $08 $09 $09
.db $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $0A $09 $09
.db $08 $07 $00 $02 $03 $04 $05 $05 $06 $06 $06 $06 $06 $06 $06 $06
.db $06 $06 $05 $05 $04 $03 $02 $00

;____________________________________________________________________________[$A7ED]___
;OBJECT: boss (Scrap Brain)

_a7ed:
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$2f
	bit     0,(ix+$18)
	jr      nz,+
	ld      hl,$0340
	ld      (RAM_LEVEL_CROPLEFT),hl
	ld      hl,$0540
	ld      ($d275),hl
	ld      hl,($d25d)
	ld      (RAM_LEVEL_CROPTOP),hl
	ld      (RAM_LEVEL_EXTENDHEIGHT),hl
	ld      hl,$0220
	ld      ($d27d),hl

	;UNKNOWN
	ld      hl,$ef3f
	ld      de,$2000
	ld      a,12
	call    decompressArt

	ld      hl,S1_BossPalette
	ld      a,$02
	call    loadPaletteOnInterrupt
	
	ld      a,index_music_boss1
	rst     $18			;`playMusic`
	
	set     0,(ix+$18)
+	bit     1,(ix+$18)
	jr      nz,+++
	ld      hl,($d25a)
	ld      (RAM_LEVEL_CROPLEFT),hl
	ld      de,_baf9
	ld      bc,_a9b7
	call    _7c41
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,($d3fe)
	xor     a
	sbc     hl,de
	ld      de,$0040
	xor     a
	ld      bc,($d403)
	bit     7,b
	jr      nz,+
	sbc     hl,de
	jr      c,++
+	ld      bc,$ff80
++	inc     b
	ld      (ix+$07),c
	ld      (ix+$08),b
	ld      (ix+$09),a
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$05a0
	xor     a
	sbc     hl,de
	jp      c,++++
	ld      l,a
	ld      h,a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      ($d403),hl
	ld      ($d405),a
	set     1,(ix+$18)
	jp      ++++
	
+++	bit     2,(ix+$18)
	jr      nz,+
	ld      hl,$0530
	ld      de,$0220
	call    _7c8c
	ld      (iy+vars.joypad),$ff
	ld      hl,$05a0
	ld      (ix+$01),$00
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$0f),<_baf9
	ld      (ix+$10),>_baf9
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $c0
	jp      c,++++
	set     2,(ix+$18)
	jp      ++++
	
+	bit     3,(ix+$18)
	jr      nz,+
	ld      (iy+vars.joypad),$ff
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	dec     (ix+$11)
	jp      nz,++++
	set     3,(ix+$18)
	jp      ++++
	
+	bit     4,(ix+$18)
	jr      nz,++
	ld      de,($d3fe)
	ld      hl,$0596
	and     a
	sbc     hl,de
	jr      nc,++++
	ld      hl,$05c0
	xor     a
	sbc     hl,de
	jr      c,++++
	or      (ix+$11)
	jr      nz,+
	ld      hl,($d401)
	ld      de,$028d
	xor     a
	sbc     hl,de
	jr      c,++++
	ld      l,a
	ld      h,a
	ld      ($d403),hl
	ld      ($d405),a
+	ld      a,$80
	ld      ($d414),a
	ld      hl,$05a0
	ld      ($d3fe),hl
	ld      (iy+vars.joypad),$ff
	ld      e,(ix+$11)
	ld      d,$00
	ld      hl,$028e
	xor     a
	sbc     hl,de
	ld      ($d400),a
	ld      ($d401),hl
	ld      a,($d2e8)
	ld      hl,($d2e6)
	ld      ($d406),hl
	ld      ($d408),a
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $c0
	jr      nz,++++
	ld      hl,($d25a)
	inc     h
	ld      ($d3fe),hl
	set     4,(ix+$18)
	
	ld      a,index_music_actComplete
	rst     $18			;`playMusic`
	
	ld      a,$a0
	ld      ($d289),a
	set     1,(iy+vars.flags6)
	ret
	
++	ld      a,(ix+$11)
	and     a
	jr      z,++++
	dec     (ix+$11)
++++	ld      e,(ix+$11)
	ld      d,$00
	ld      hl,$0280
	xor     a
	sbc     hl,de
	ld      (ix+$04),a
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      e,(ix+$11)
	ld      d,$00
	ld      hl,$02af
	and     a
	sbc     hl,de
	ld      bc,($d25d)
	and     a
	sbc     hl,bc
	ex      de,hl
	ld      hl,$05a0
	ld      bc,($d25a)
	and     a
	sbc     hl,bc
	ld      bc,_a9c0		;address of sprite layout
	call    processSpriteLayout
	ld      a,(ix+$11)
	and     $1f
	cp      $0f
	ret     nz
	ld      a,$19
	rst     $28			;`playSFX`
	ret

_a9b7:
.db $03, $08, $04, $07, $05, $08, $04, $07, $FF

;sprite layout
_a9c0:
.db $74, $76, $76, $78, $FF, $FF
.db $FF

;____________________________________________________________________________[$A9C7]___
;OBJECT: meta - clouds (Sky Base)

_a9c7:
	set     5,(ix+$18)
	ld      a,(iy+vars.spriteCount)
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	push    af
	push    hl
	ld      a,($d2de)
	cp      $24
	jr      nc,+
	ld      e,a
	ld      d,$00
	ld      hl,$d000
	add     hl,de
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      a,($d2a3)
	ld      c,a
	ld      de,($d2a1)
	ld      l,(ix+$04)
	ld      h,(ix+$05)
	ld      a,(ix+$06)
	add     hl,de
	adc     a,c
	ld      l,h
	ld      h,a
	ld      bc,($d25d)
	and     a
	sbc     hl,bc
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,($d25a)
	and     a
	sbc     hl,bc
	ld      bc,_aa63		;address of sprite layout
	call    processSpriteLayout
	ld      a,($d2de)
	add     a,$0c
	ld      ($d2de),a
+	pop     hl
	pop     af
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      (iy+vars.spriteCount),a
	ld      hl,($d25a)
	ld      de,$ffe0
	add     hl,de
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	and     a
	sbc     hl,de
	jr      nc,+
	call    _LABEL_625_57
	ld      b,$00
	add     a,a
	ld      c,a
	rl      b
	ld      hl,($d25a)
	ld      de,$01b4
	add     hl,de
	add     hl,bc
	ld      (ix+$02),l
	ld      (ix+$03),h
+	ld      (ix+$07),$00
	ld      (ix+$08),$fd
	ld      (ix+$09),$ff
	ld      (ix+$0f),$00
	ld      (ix+$10),$00
	ret

;sprite layout
_aa63:
.db $40, $42, $44, $46, $FF, $FF
.db $FF

;____________________________________________________________________________[$AA6A]___
;OBJECT: propeller (Sky Base)

_aa6a:
	set     5,(ix+$18)
	ld      (ix+$0d),$05
	ld      (ix+$0e),$14
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$000f
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$fffa
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	set     0,(ix+$18)
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      e,(ix+$11)
	ld      d,$00
	ld      hl,_ab01
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      b,$02
	
-	push    bc
	ld      a,(de)
	ld      l,a
	ld      h,$00
	ld      (RAM_TEMP4),hl
	inc     de
	ld      a,(de)
	ld      l,a
	ld      (RAM_TEMP6),hl
	inc     de
	ld      a,(de)
	inc     de
	and     a
	jp      m,+
	push    de
	call    _3581
	pop     de
+	pop     bc
	djnz    -
	
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      (ix+$0f),$00
	ld      (ix+$10),$00
	ld      a,(ix+$11)
	inc     a
	inc     a
	cp      $08
	ld      (ix+$11),a
	ret     c
	ld      (ix+$11),$00
	ret

_ab01:
.db $09, $AB, $0F, $AB, $15, $AB, $1B, $AB, $00, $00, $1C, $00, $18, $3C, $00, $00
.db $1E, $00, $18, $3E, $00, $00, $38, $00, $18, $3A, $00, $08, $1A, $00, $00, $FF

;____________________________________________________________________________[$AB21]___
;OBJECT: badnick - bomb (Sky Base)

_ab21:
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$10
	ld      a,(ix+$11)
	cp      $64
	jr      nc,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$ffc8
	add     hl,de
	ex      de,hl
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$002c
	add     hl,de
	ex      de,hl
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      (ix+$11),$64
+	ld      a,(ix+$11)
	cp      $1e
	jr      nc,+
	ld      (ix+$07),$f8
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      de,_ad0b
	ld      bc,_acf1
	call    _7c41
	jp      +++
	
+	ld      a,(ix+$11)
	cp      $64
	jp      c,++
	ld      (ix+$07),$00
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	cp      $66
	jr      nc,+
	ld      de,_ad0b
	ld      bc,_ad01
	call    _7c41
	jp      +++
	
+	ld      (ix+$0f),<_ad53
	ld      (ix+$10),>_ad53
	cp      $67
	jp      nz,+++
	ld      hl,$fffe
	ld      (RAM_TEMP4),hl
	ld      hl,$fffc
	ld      (RAM_TEMP6),hl
	call    _7c7b
	jp      c,++++
	ld      de,$0000
	ld      c,e
	ld      b,d
	call    _ac96
	ld      hl,$0003
	ld      (RAM_TEMP4),hl
	ld      hl,$fffc
	ld      (RAM_TEMP6),hl
	call    _7c7b
	jp      c,++++
	ld      de,$0008
	ld      bc,$0000
	call    _ac96
	ld      hl,$fffe
	ld      (RAM_TEMP4),hl
	ld      hl,$fffe
	ld      (RAM_TEMP6),hl
	call    _7c7b
	jp      c,++++
	ld      de,$0000
	ld      bc,$0008
	call    _ac96
	ld      hl,$0003
	ld      (RAM_TEMP4),hl
	ld      hl,$fffe
	ld      (RAM_TEMP6),hl
	call    _7c7b
	jp      c,++++
	ld      de,$0008
	ld      bc,$0008
	call    _ac96
	ld      (ix+$00),$ff
	ld      a,$1b
	rst     $28			;`playSFX`
	jr      ++++
	
++	cp      $23
	jr      nc,+
	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      de,_ad0b
	ld      bc,_acf6
	call    _7c41
	jr      +++
	
+	ld      a,(ix+$11)
	cp      $41
	jr      nc,+
	ld      (ix+$07),$08
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	ld      de,_ad0b
	ld      bc,_acf9
	call    _7c41
	jr      +++
	
+	ld      (ix+$07),$00
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	ld      de,_ad0b
	ld      bc,_acfe
	call    _7c41
+++	ld      (ix+$0a),$80
	ld      (ix+$0b),$00
	ld      (ix+$0c),$00
++++	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      a,($d223)
	and     $3f
	ret     nz
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $46
	ret     nz
	ld      (ix+$11),$00
	ret

;____________________________________________________________________________[$AC96]___

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
	ld      hl,(RAM_TEMP4)
	ld      (ix+$08),l
	ld      (ix+$09),h
	ld      (ix+$0a),a
	ld      hl,(RAM_TEMP6)
	ld      (ix+$0b),l
	ld      (ix+$0c),h
	pop     ix
	ret    

_acf1:
.db $00, $20, $01, $20, $FF
_acf6:
.db $01, $20, $FF
_acf9:
.db $02, $20, $03, $20, $FF
_acfe:
.db $03, $20, $FF
_ad01:
.db $01, $02, $04, $02, $FF, $03, $02, $05, $02, $FF

;sprite layout
_ad0b:
.db $0A, $0C, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $0E, $10, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $2A, $2C, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $2E, $30, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

_ad53:
.db $12, $14, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $32, $34, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$AD6C]___
;OBJECT: canon (Sky Base)

_ad6c:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$fffc
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	call    _LABEL_625_57
	ld      (ix+$11),a
	set     0,(ix+$18)
+	ld      a,(ix+$11)
	cp      $64
	jr      nz,+
	call    _7c7b
	jr      c,+
	push    ix
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$34
	ld      (ix+$01),a
	ld      hl,$0004
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,$0010
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	pop     ix
	ld      a,$1c
	rst     $28			;`playSFX`
	ld      (ix+$12),$18
	ld      (ix+$16),$00
	ld      (ix+$17),$00
+	ld      a,(ix+$12)
	and     a
	jr      z,+
	ld      de,_ae04
	ld      bc,_adfd
	call    _7c41
	dec     (ix+$12)
	inc     (ix+$11)
	ret
	
+	ld      (ix+$0f),a
	ld      (ix+$10),a
	inc     (ix+$11)
	ret

_adfd:
.db $00, $08, $01, $08, $02, $08, $FF

;sprite layout
_ae04:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $74, $76, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $FF, $FF, $FF, $FF, $FF
.db $78, $7A, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $FE, $FF, $FF, $FF, $FF, $FF
.db $7C, $7E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$AE35]___
;OBJECT: UNKNOWN

_ae35:
	set     5,(ix+$18)
	ld      (ix+$0d),$0c
	ld      (ix+$0e),$0c
	ld      hl,($d25a)
	ld      de,$0110
	add     hl,de
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      (ix+$00),$ff
+	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	xor     a
	ld      (ix+$07),$80
	ld      (ix+$08),$02
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      (ix+$0f),<_ae81
	ld      (ix+$10),>_ae81
	ret

;sprite layout
_ae81:
.db $02, $04, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$AE88]___
;OBJECT: badnick - Unidos (Sky Base)

_ae88:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      (ix+$11),$00
	ld      (ix+$12),$2a
	ld      (ix+$13),$52
	ld      (ix+$14),$7c
	set     0,(ix+$18)
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,($d3fe)
	and     a
	sbc     hl,de
	jr      c,+
	ld      (ix+$07),$f8
	ld      (ix+$08),$ff
	ld      (ix+$09),$ff
	ld      (ix+$0f),<_b0d5
	ld      (ix+$10),>_b0d5
	ld      hl,$ff80
	ld      ($d216),hl
	call    _af98
	ld      (ix+$16),$01
	jr      ++
	
+	ld      (ix+$07),$08
	ld      (ix+$08),$00
	ld      (ix+$09),$00
	ld      (ix+$0f),<_b0e7
	ld      (ix+$10),>_b0e7
	ld      hl,$0080
	ld      ($d216),hl
	call    _af98
	ld      (ix+$16),$ff
++	ld      (ix+$0d),$1c
	ld      (ix+$0e),$1c
	ld      hl,$1212
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ld      hl,$1010
	ld      (RAM_TEMP1),hl
	call    nc,_35e5
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	push    ix
	pop     hl
	ld      de,$0011
	add     hl,de
	ld      b,$04
	
-	push    bc
	push    hl
	ld      a,(hl)
	cp      $fe
	jr      z,+
	and     $fe
	ld      e,a
	ld      d,$00
	ld      hl,_b031
	add     hl,de
	push    hl
	ld      e,(hl)
	ld      (RAM_TEMP4),de
	inc     hl
	ld      e,(hl)
	ld      (RAM_TEMP6),de
	ld      a,$24
	call    _3581
	pop     hl
	ld      a,(hl)
	inc     a
	inc     a
	ld      (RAM_TEMP6),a
	add     a,$04
	ld      (ix+$0d),a
	inc     hl
	ld      a,(hl)
	inc     a
	inc     a
	ld      (RAM_TEMP7),a
	add     a,$04
	ld      (ix+$0e),a
	call    _LABEL_3956_11
	call    nc,_35fd
+	pop     hl
	pop     bc
	ld      a,(hl)
	cp      $fe
	jr      z,++
	add     a,(ix+$16)
	cp      $ff
	jr      nz,+
	ld      a,$a3
	jr      ++
	
+	cp      $a4
	jr      nz,++
	xor     a
++	ld      (hl),a
	inc     hl
	djnz    -
	
	ld      a,($d223)
	and     $07
	ret     z
	ld      a,(ix+$15)
	cp      $c8
	ret     nc
	inc     (ix+$15)
	ret

;____________________________________________________________________________[$AF98]___

_af98:
	ld      a,(ix+$15)
	cp      $c8
	ret     nz
	ld      a,(RAM_LEVEL_SOLIDITY)
	cp      $03
	ret     nz
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffd0
	add     hl,de
	ld      de,($d401)
	and     a
	sbc     hl,de
	ret     nc
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      bc,$002c
	add     hl,bc
	and     a
	sbc     hl,de
	ret     c
	push    ix
	pop     hl
	ld      de,$0011
	add     hl,de
	ld      b,$04
	
-	push    bc
	push    hl
	ld      a,(hl)
	cp      $4a
	call    z,_afdb
	pop     hl
	pop     bc
	inc     hl
	djnz    -
	
	ret

;____________________________________________________________________________[$AFDB]___

_afdb:
	ld      (hl),$fe
	call    _7c7b
	ret     c
	push    ix
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$36
	ld      (ix+$01),a
	ld      hl,$0012
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,$001e
	add     hl,bc
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      hl,($d216)
	ld      (ix+$07),l
	ld      (ix+$08),h
	xor     a
	bit     7,h
	jr      z,+
	ld      a,$ff
+	ld      (ix+$09),a
	xor     a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	pop     ix
	ret

_b031:
.db $0C, $03, $0D, $03, $0E, $03, $0E, $04, $0F, $04, $10, $04, $10, $05, $11, $05
.db $11, $06, $12, $06, $12, $07, $13, $07, $13, $08, $13, $09, $14, $09, $14, $0A
.db $14, $0B, $15, $0B, $15, $0C, $15, $0D, $15, $0E, $15, $0F, $15, $10, $15, $11
.db $14, $11, $14, $12, $14, $13, $13, $13, $13, $14, $13, $15, $12, $15, $12, $16
.db $11, $16, $11, $17, $10, $17, $10, $18, $0F, $18, $0E, $18, $0E, $19, $0D, $19
.db $0C, $19, $0B, $19, $0A, $19, $09, $19, $09, $18, $08, $18, $07, $18, $07, $17
.db $06, $17, $06, $16, $05, $16, $05, $15, $04, $15, $04, $14, $04, $13, $03, $13
.db $03, $12, $03, $11, $02, $11, $02, $10, $02, $0F, $02
_b0ac:
.db $0E, $02, $0D, $02, $0C, $02, $0B, $03, $0B, $03, $0A, $03, $09, $04, $09, $04
.db $08, $04, $07, $05, $07, $05, $06, $06, $06, $06, $05, $07, $05, $07, $04, $08
.db $04, $09, $04, $09, $03, $0A, $03, $0B, $03

;sprite layout
_b0d5:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $FE, $26, $28, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
_b0e7:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $FE, $20, $22, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$B0F4]___
;OBJECT: UNKNOWN

_b0f4:
	set     5,(ix+$18)
	ld      (ix+$0f),$00
	ld      (ix+$10),$00
	ld      (ix+$0d),$04
	ld      (ix+$0e),$0a
	ld      hl,$0602
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	call    nc,_35fd
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ex      de,hl
	ld      hl,($d25a)
	ld      bc,$fff0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25a)
	ld      bc,$0110
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ex      de,hl
	ld      hl,($d25d)
	ld      bc,$fff0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,+
	ld      hl,($d25d)
	ld      bc,$00d0
	add     hl,bc
	and     a
	sbc     hl,de
	jr      c,+
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      (RAM_TEMP6),hl
	ld      a,$24
	call    _3581
	ret
	
+	ld      (ix+$00),$ff
	ret

;____________________________________________________________________________[$B16C]___
;OBJECT: rotating turret (Sky Base)

_b16c:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	call    _LABEL_625_57
	and     $07
	ld      (ix+$11),a
	set     0,(ix+$18)
+	ld      (ix+$0f),$00
	ld      (ix+$10),$00
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      a,(ix+$11)
	add     a,a
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	ld      hl,_b227
	add     hl,de
	ld      b,$02
	
-	push    bc
	ld      d,$00
	ld      e,(hl)
	bit     7,e
	jr      z,+
	ld      d,$ff
+	ld      (RAM_TEMP4),de
	inc     hl
	ld      d,$00
	ld      e,(hl)
	bit     7,e
	jr      z,+
	ld      d,$ff
+	ld      (RAM_TEMP6),de
	inc     hl
	ld      a,(hl)
	inc     hl
	inc     hl
	cp      $ff
	jr      z,+
	push    hl
	call    _3581
	pop     hl
+	pop     bc
	djnz    -
	
	ld      a,($d223)
	and     $3f
	jr      nz,+
	ld      a,(ix+$11)
	inc     a
	and     $07
	ld      (ix+$11),a
+	inc     (ix+$12)
	ld      a,(ix+$12)
	cp      $1a
	ret     nz
	ld      (ix+$12),$00
	ld      a,(ix+$11)
	add     a,a
	ld      e,a
	add     a,a
	add     a,e
	ld      e,a
	ld      d,$00
	ld      hl,_b267
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (RAM_TEMP4),de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	ld      (RAM_TEMP6),de
	inc     hl
	ld      e,(hl)
	ld      d,$00
	bit     7,e
	jr      z,+
	dec     d
+	inc     hl
	ld      c,(hl)
	ld      b,$00
	bit     7,c
	jr      z,+
	dec     b
+	call    _b5c2
	ret

_b227:
.db $08, $F8, $66, $00, $00, $00, $FF, $00, $0C, $FA, $70, $00, $14, $FA, $72, $00
.db $0F, $07, $4C, $00, $17, $07, $4E, $00, $0D, $0C, $6C, $00, $15, $0C, $6E, $00
.db $08, $0F, $64, $00, $00, $00, $FF, $00, $FC, $0C, $68, $00, $04, $0C, $6A, $00
.db $F9, $07, $48, $00, $01, $07, $4A, $00, $FB, $F9, $50, $00, $03, $F9, $52, $00   
_b267:
.db $00, $00, $00, $FE, $08, $F0, $00, $01, $00, $FF, $18, $F8, $00, $02, $00, $00
.db $1E, $07, $00, $01, $00, $01, $16, $16, $00, $00, $00, $02, $08, $20, $00, $FF
.db $00, $01, $F8, $18, $00, $FE, $00, $00, $F2, $07, $00, $FF, $00, $FF, $F7, $F6

;____________________________________________________________________________[$B297]___
;OBJECT: flying platform (Sky Base)

_b297:
	set 5, (ix+$18)
	bit 0, (ix+$18)
	jr      nz,+
	ld      a,(ix+$04)
	ld      (ix+$12),a
	ld      a,(ix+$05)
	ld      (ix+$13),a
	ld      a,(ix+$06)
	ld      (ix+$14),a
	set     0,(ix+$18)
+	ld      a,($d2a3)
	ld      c,a
	ld      de,($d2a1)
	ld      l,(ix+$12)
	ld      h,(ix+$13)
	ld      a,(ix+$14)
	add     hl,de
	adc     a,c
	ld      (ix+$04),l
	ld      (ix+$05),h
	ld      (ix+$06),a
	ld      a,($d408)
	and     a
	jp      m,+
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$10
	ld      hl,$0a02
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	ld      hl,$0030
	ld      ($d26b),hl
	ld      hl,$0030
	ld      ($d26d),hl
	ld      bc,$0010
	ld      de,$0000
	call    _LABEL_7CC1_12
	ld      l,(ix+$01)
	ld      h,(ix+$02)
	ld      a,(ix+$03)
	ld      de,$0080
	add     hl,de
	adc     a,$00
	ld      (ix+$01),l
	ld      (ix+$02),h
	ld      (ix+$03),a
	ld      hl,($d3fd)
	ld      a,($d3ff)
	add     hl,de
	adc     a,$00
	ld      ($d3fd),hl
	ld      ($d3ff),a
+	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$fff8
	ld      (RAM_TEMP4),hl
	ld      e,(ix+$11)
	ld      d,$00
	ld      hl,_b388
	add     hl,de
	ld      b,$02
	
-	push    bc
	ld      e,(hl)
	ld      d,$00
	inc     hl
	ld      (RAM_TEMP6),de
	ld      a,(hl)
	inc     hl
	cp      $ff
	jr      z,+
	push    hl
	call    _3581
	pop     hl
+	pop     bc
	djnz    -
	
	ld      (ix+$0f),<_b37b
	ld      (ix+$10),>_b37b
	ld      a,(ix+$11)
	add     a,$04
	ld      (ix+$11),a
	cp      $10
	ret     c
	ld      (ix+$11),$00
	ret

;sprite layout
_b37b:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $36, $36, $36, $36, $FF, $FF
.db $FF

_b388:
.db $08, $1C, $18, $3C, $08, $1E, $18, $3E, $08, $38, $18, $3A, $0C, $1A, $00, $FF

;____________________________________________________________________________[$B398]___
;OBJECT: moving spiked wall (Sky Base)

_b398:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      (ix+$11),l
	ld      (ix+$12),h
	set     0,(ix+$18)
+	ld      (ix+$0d),$0c
	ld      (ix+$0e),$2e
	ld      (ix+$0f),<_b45b
	ld      (ix+$10),>_b45b
	ld      hl,$0202
	ld      (RAM_TEMP6),hl

	call    _LABEL_3956_11
	call    nc,_35fd
	ld      l,(ix+$01)
	ld      h,(ix+$02)
	ld      a,(ix+$03)
	ld      de,$0080
	add     hl,de
	adc     a,$00
	ld      l,h
	ld      h,a
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      (RAM_TEMP3),hl
	ld      hl,$0000
	ld      (RAM_TEMP4),hl
	ld      hl,$fff0
	ld      (RAM_TEMP6),hl
	ld      a,$16
	call    _3581
	ld      hl,$0008
	ld      (RAM_TEMP4),hl
	ld      a,$18
	call    _3581
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0580
	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	sbc     hl,de
	ret     nc
	ld      c,(ix+$05)
	ld      b,(ix+$06)
	ld      hl,$0040
	add     hl,bc
	ld      de,($d25d)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      a,(ix+$11)
	ld      (ix+$02),a
	ld      a,(ix+$12)
	ld      (ix+$03),a
+	ld      de,($d401)
	ld      hl,$ffe0
	add     hl,bc
	xor     a
	sbc     hl,de
	ret     nc
	ld      hl,$002c
	add     hl,bc
	xor     a
	sbc     hl,de
	ret     c
	ld      (ix+$07),$80
	ld      (ix+$08),a
	ld      (ix+$09),a
	ret

;sprite layout
_b45b:
.db $16, $18, $FF, $FF, $FF, $FF
.db $16, $18, $FF, $FF, $FF, $FF
.db $16, $18, $FF, $FF, $FF, $FF

;____________________________________________________________________________[$B46D]___
;OBJECT: fixed turret (Sky Base)

_b46d:
	set     5,(ix+$18)
	bit     0,(ix+$18)
	jr      nz,+
	ld      bc,$0000
	ld      e,c
	ld      d,b
	call    _36f9
	ld      a,(hl)
	sub     $3c
	cp      $04
	ret     nc
	ld      (ix+$11),a
	set     0,(ix+$18)
+	inc     (ix+$12)
	ld      a,(ix+$12)
	bit     6,a
	ret     nz
	and     $0f
	ret     nz
	ld      a,(ix+$11)
	add     a,a
	ld      e,a
	add     a,a
	add     a,a
	add     a,e
	ld      e,a
	ld      d,$00
	ld      hl,_b4e6
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (RAM_TEMP4),de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      (RAM_TEMP6),de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      c,(hl)
	inc     hl
	ld      b,(hl)
	inc     hl
	exx     
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	ld      a,h
	exx     
	cp      (hl)
	ret     nz
	inc     hl
	exx     
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,($d401)
	and     a
	sbc     hl,de
	ld      a,h
	exx     
	cp      (hl)
	ret     nz
	call    _b5c2
	ret

_b4e6:
.db $80, $FE, $80, $FE, $00, $00, $F8, $FF, $FF, $FF, $80, $01, $80, $FE, $18, $00
.db $F8, $FF, $00, $FF, $80, $FE, $80, $01, $00, $00, $10, $00, $FF, $00, $80, $01
.db $80, $01, $18, $00, $10, $00, $00, $00   

;____________________________________________________________________________[$B50E]___
;OBJECT: flying platform - up/down (Sky Base)

_b50e:
	set     5,(ix+$18)
	ld      hl,_b37b
	ld      a,(RAM_LEVEL_SOLIDITY)
	cp      $01
	jr      nz,+
	ld      hl,_b5b5
+	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      a,$50
	ld      ($d216),a
	call    _b53b
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $a0
	ret     c
	ld      (ix+$11),$00
	ret

;----------------------------------------------------------------------------[$B53B]---

_b53b:
	ld      a,($d216)
	ld      l,a
	ld      de,$0010
	ld      c,$00
	ld      a,(ix+$11)
	cp      l
	jr      c,+
	dec     c
	ld      de,$fff0
+	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	add     hl,de
	adc     a,c
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	ld      a,h
	and     a
	jp      p,+
	ld      a,l
	cpl     
	ld      l,a
	ld      a,h
	cpl     
	ld      h,a
	inc     hl
	ld      a,h
	cp      $02
	jr      c,++
	ld      (ix+$0a),$00
	ld      (ix+$0b),$fe
	ld      (ix+$0c),$ff
	jr      ++
	
+	cp      $02
	jr      c,++
	ld      (ix+$0a),$00
	ld      (ix+$0b),$02
	ld      (ix+$0c),$00
++	ld      a,($d408)
	and     a
	ret     m
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$1c
	ld      hl,$0802
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	ret     c
	ld      e,(ix+$0a)
	ld      d,(ix+$0b)
	ld      bc,$0010
	call    _LABEL_7CC1_12
	ret

;sprite layout
_b5b5:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $6C, $6E, $6C, $6E, $FF, $FF
.db $FF

;____________________________________________________________________________[$B5C2]___

_b5c2:
	push    bc
	push    de
	call    _7c7b
	pop     de
	pop     bc
	ret     c
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
	ld      (ix+$13),a
	ld      (ix+$14),a
	ld      (ix+$15),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      hl,(RAM_TEMP4)
	bit     7,h
	jr      z,+
	ld      a,$ff
+	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),a
	xor     a
	ld      hl,(RAM_TEMP6)
	bit     7,h
	jr      z,+
	ld      a,$ff
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	pop     ix
	ld      a,$01
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$B634]___
;OBJECT: boss (Sky Base)

_b634:
	ld      (ix+$0d),$1e
	ld      (ix+$0e),$2f
	set     5,(ix+$18)
	bit     2,(ix+$18)
	jp      nz,_b821
	call    _7ca6
	call    _b7e6
	bit     0,(ix+$18)
	jr      nz,+
	ld      hl,$0350
	ld      de,$0120
	call    _7c8c
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$0008
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$11),l
	ld      (ix+$12),h
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0010
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$13),l
	ld      (ix+$14),h
	xor     a
	ld      ($d2ec),a
	
	ld      a,index_music_boss3
	rst     $18			;`playMusic`
	
	set     4,(iy+vars.unknown0)
	set     0,(ix+$18)
+	ld      a,(ix+$15)
	and     a
	jp      nz,+++
	call    _b99f
	ld      a,($d223)
	and     $07
	jp      nz,++++
	ld      a,(ix+$16)
	cp      $1c
	jr      nc,+
	inc     (ix+$17)
	ld      a,(ix+$17)
	cp      $02
	jp      c,++
+	ld      (ix+$17),$00
++	inc     (ix+$16)
	ld      a,(ix+$16)
	cp      $28
	jp      c,++++
	ld      (ix+$16),$00
	inc     (ix+$15)
	jp      ++++
	
+++	dec     a
	jr      nz,+
	ld      (ix+$0a),$40
	ld      (ix+$0b),$fe
	ld      (ix+$0c),$ff
	inc     (ix+$15)
	ld      l,(ix+$11)
	ld      h,(ix+$12)
	ld      de,$0004
	add     hl,de
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$0f),<_bb1d
	ld      (ix+$10),>_bb1d
	jp      ++++
	
+	dec     a
	jp      nz,++
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$000e
	add     hl,de
	adc     a,$00
	ld      c,a
	jp      m,+
	ld      a,h
	cp      $02
	jr      c,+
	ld      hl,$0200
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      (ix+$0f),<_bb1d
	ld      (ix+$10),>_bb1d
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	dec     hl
	ld      e,(ix+$13)
	ld      d,(ix+$14)
	and     a
	sbc     hl,de
	jr      c,++++
	ld      (ix+$05),e
	ld      (ix+$06),d
	xor     a
	ld      (ix+$16),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	inc     (ix+$15)
	jp      ++++
	
++	dec     a
	jp      nz,++++
	ld      l,(ix+$11)
	ld      h,(ix+$12)
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      a,(ix+$16)
	and     a
	call    z,_b9d5
	ld      (ix+$17),$02
	set     1,(ix+$18)
	call    _b99f
	inc     (ix+$16)
	ld      a,(ix+$16)
	cp      $12
	jr      c,++++
	res     1,(ix+$18)
	xor     a
	ld      (ix+$15),a
	ld      (ix+$16),a
++++	ld      hl,$ba31
	bit     1,(ix+$18)
	jr      z,+
	ld      hl,_ba3b
+	ld      de,RAM_TEMP1
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ldi     
	ld      a,(hl)
	inc     hl
	push    hl
	call    _3581
	ld      hl,(RAM_TEMP4)
	ld      de,$0008
	add     hl,de
	ld      (RAM_TEMP4),hl
	pop     hl
	ld      a,(hl)
	call    _3581
	ld      a,($d2ec)
	cp      $0c
	ret     c
	xor     a
	ld      (ix+$11),a
	ld      (ix+$16),a
	ld      (ix+$17),a
	set     2,(ix+$18)
	res     4,(iy+vars.unknown0)
	
	ld      a,index_music_scrapBrain
	rst     $18			;`playMusic`
	
	ld      a,$21
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$B7E6]___	

_b7e6:
	ld      a,($d2b1)
	and     a
	ret     nz
	bit     0,(iy+vars.scrollRingFlags)
	ret     nz
	ld      a,($d414)
	rrca    
	jr      c,+
	and     $02
	ret     z
+	ld      hl,($d3fe)
	ld      de,$0410
	and     a
	sbc     hl,de
	ret     c
	ld      hl,$fd00
	ld      a,$ff
	ld      ($d403),hl
	ld      ($d405),a
	ld      hl,$d2b1
	ld      (hl),$18
	inc     hl
	ld      (hl),$0c
	inc     hl
	ld      (hl),$3f
	ld      a,$01
	rst     $28			;`playSFX`
	ld      hl,$d2ec
	inc     (hl)
	ret
_b821:
	bit     3,(ix+$18)
	jp      nz,++++
	res     5,(ix+$18)
	ld      a,(ix+$11)
	cp      $0f
	jr      nc,+
	add     a,a
	add     a,a
	ld      e,a
	add     a,a
	add     a,e
	ld      e,a
	ld      d,$00
	ld      hl,$ba45
	add     hl,de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      ($d2ab),de
	ld      e,(hl)
	inc     hl
	ld      d,(hl)
	inc     hl
	ld      ($d2ad),de
	ld      ($d2af),hl
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $0f
	jr      nz,+
	set     5,(iy+vars.flags0)
	res     1,(iy+vars.flags2)
	ld      hl,$0550
	ld      ($d275),hl
+	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      hl,$05e0
	xor     a
	sbc     hl,de
	jr      nc,+
	ld      c,a
	ld      b,a
	jp      +++
	
+	ex      de,hl
	ld      de,($d3fe)
	xor     a
	sbc     hl,de
	ld      de,$0040
	xor     a
	ld      bc,($d403)
	bit     7,b
	jr      nz,+
	sbc     hl,de
	jr      c,++
+	ld      bc,$ff80
++	inc     b
+++	ld      (ix+$07),c
	ld      (ix+$08),b
	ld      (ix+$09),a
	ld      a,(ix+$17)
	cp      $06
	jr      nz,+
	ld      a,(ix+$16)
	dec     a
	jr      nz,+
	bit     7,(ix+$18)
	jr      z,+
	ld      (ix+$0a),$00
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
+	ld      de,$0017
	ld      bc,$0036
	call    _36f9
	ld      e,(hl)
	ld      d,$00
	ld      hl,$3f28
	add     hl,de
	ld      a,(hl)
	and     $3f
	and     a
	jr      z,+
	bit     7,(ix+$18)
	jr      z,+
	ld      (ix+$0a),$80
	ld      (ix+$0b),$fd
	ld      (ix+$0c),$ff
+	ld      de,$0000
	ld      bc,$0008
	call    _36f9
	ld      a,(hl)
	cp      $49
	jr      nz,+
	bit     7,(ix+$18)
	jr      z,+
	xor     a
	ld      (ix+$16),a
	ld      (ix+$17),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$11),$e0
	ld      (ix+$12),$05
	ld      (ix+$13),$60
	ld      (ix+$14),$01
	ld      hl,$0550
	ld      de,$0120
	call    _7c8c
	set     3,(ix+$18)
	jp      ++++
	
+	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	ld      de,$000e
	add     hl,de
	adc     a,$00
	ld      c,a
	jp      m,+
	ld      a,h
	cp      $02
	jr      c,+
	ld      hl,$0200
+	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),c
	ld      bc,_ba28
	ld      de,_baf9
	call    _7c41
	ret
	
++++	ld      (iy+vars.joypad),$ff
	call    _b99f
	ld      a,(ix+$16)
	cp      $30
	jr      nc,++
	ld      c,a
	ld      a,($d223)
	and     $07
	jr      nz,+
	ld      a,(ix+$17)
	inc     a
	and     $01
	ld      (ix+$17),a
	inc     (ix+$16)
+	ld      a,c
	cp      $2c
	ret     c
	ld      (ix+$0f),<_bb77
	ld      (ix+$10),>_bb77
	ret
	
++	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	inc     (ix+$16)
	ld      a,(ix+$16)
	cp      $70
	ret     c
	ld      (ix+$00),$ff
	ret
	
;____________________________________________________________________________[$B99F]___

_b99f:
	ld      hl,_ba1c
	ld      a,(ix+$17)
	add     a,a
	add     a,a
	ld      e,a
	ld      d,$00
	ld      b,d
	add     hl,de
	ld      c,(hl)
	inc     hl
	ld      e,(hl)
	inc     hl
	ld      a,(hl)
	inc     hl
	ld      h,(hl)
	ld      l,a
	ld      (ix+$0f),l
	ld      (ix+$10),h
	ld      l,(ix+$11)
	ld      h,(ix+$12)
	add     hl,bc
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      l,(ix+$13)
	ld      h,(ix+$14)
	add     hl,de
	ld      (ix+$05),l
	ld      (ix+$06),h
	ret

;____________________________________________________________________________[$B9D5]___

_b9d5:
	bit     5,(iy+vars.unknown0)
	ret     nz
	call    _7c7b
	ret     c
	push    ix
	push    hl
	pop     ix
	xor     a
	ld      (ix+$00),$47
	ld      (ix+$01),a
	ld      hl,$0420
	ld      (ix+$02),l
	ld      (ix+$03),h
	ld      (ix+$04),a
	ld      hl,$012f
	ld      (ix+$05),l
	ld      (ix+$06),h
	ld      (ix+$11),a
	ld      (ix+$18),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	pop     ix
	ret

_ba1b:
.db $C9					;unused?
_ba1c:    
.db $00, $00, $F9, $BA, $00, $02, $0B, $BB, $00, $07, $0B, $BB
_ba28:
.db $03, $08, $04, $07, $05, $08, $04, $07, $FF, $30, $04, $A0, $01, $00, $00
_ba37:
.db $00, $00, $20, $22
_ba3b:
.db $30, $04, $A0, $01, $00, $00, $00, $00, $24, $26, $20, $04, $60, $01, $37, $10
.db $38, $10, $4A, $10, $4B, $10, $30, $04, $60, $01, $28, $10, $19, $10, $4C, $10
.db $4D, $10, $40, $04, $60, $01, $00, $10, $2D, $10, $4E, $10, $4F, $10, $20, $04
.db $70, $01, $00, $00, $00, $00, $00, $00, $00, $00, $30, $04, $70, $01, $00, $00
.db $00, $00, $00, $00, $00, $00, $40, $04, $70, $01, $00, $00, $00, $00, $00, $00
.db $00, $00, $20, $04, $80, $01, $00, $00, $00, $00, $00, $00, $00, $00, $30, $04
.db $80, $01, $00, $00, $00, $00, $00, $00, $00, $00, $40, $04, $80, $01, $00, $00
.db $00, $00, $00, $00, $00, $00, $20, $04, $90, $01, $00, $00, $00, $00, $00, $00
.db $00, $00, $30, $04, $90, $01, $00, $00, $00, $00, $00, $00, $00, $00, $40, $04
.db $90, $01, $00, $00, $00, $00, $00, $00, $00, $00, $20, $04, $A0, $01, $5A, $10
.db $5B, $10, $37, $10, $3B, $10, $30, $04, $A0, $01, $5C, $10, $5D, $10, $3C, $10
.db $00, $10, $40, $04, $A0, $01, $5E, $10, $5F, $10, $00, $10, $2D, $10

;sprite layout
_baf9:
.db $FE, $0A, $0C, $0E, $FF, $FF
.db $28, $2A, $2C, $2E, $FF, $FF
.db $FE, $4A, $4C, $4E, $FF, $FF

.db $FE, $0A, $0C, $0E, $FF, $FF
.db $28, $2A, $2C, $2E, $FF, $FF
.db $FE, $02, $04, $06, $FF, $FF
_bb1d:
.db $10, $12, $14, $16, $FF, $FF
.db $30, $32, $34, $FE, $FF, $FF
.db $50, $52, $54, $FE, $FF, $FF

.db $18, $1A, $1C, $1E, $FF, $FF
.db $FE, $3A, $3C, $3E, $FF, $FF
.db $FE, $64, $66, $68, $FF, $FF

.db $18, $1A, $1C, $1E, $FF, $FF
.db $FE, $3A, $3C, $3E, $FF, $FF
.db $FE, $6A, $6C, $6E, $FF, $FF

.db $18, $1A, $1C, $1E, $FF, $FF
.db $FE, $3A, $3C, $3E, $FF, $FF
.db $70, $72, $5A, $5C, $5E, $FF

.db $00, $0A, $0C, $0E, $FF, $FF
.db $28, $2A, $2C, $2E, $FF, $FF
.db $00, $4A, $4C, $4E, $FF, $FF

_bb77:
.db $FE, $FF, $FF, $FF, $FF, $FF
.db $FE, $44, $46, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$BB84]___
;OBJECT: boss - electric beam (Sky Base)

_bb84:
	set     5,(ix+$18)
	ld      hl,$0008
	ld      ($d26b),hl
	bit     0,(ix+$18)
	jr      nz,+

	;UNKNOWN
	ld      hl,$ef3f
	ld      de,$2000
	ld      a,$0c
	call    decompressArt

	ld      (ix+$12),$01
	set     0,(ix+$18)
+	ld      hl,$0390
	ld      (RAM_TEMP1),hl
	ld      l,(ix+$11)
	ld      h,$00
	ld      (RAM_TEMP4),hl
	ld      l,h
	ld      (RAM_TEMP6),hl
	ld      de,$011a
	ld      hl,_bcdd
	call    _bca5
	ld      e,(ix+$11)
	ld      d,$00
	ld      (RAM_TEMP4),de
	ld      de,$01d2
	ld      hl,_bcdd
	call    _bca5
	bit     4,(iy+vars.unknown0)
	ret     z
	bit     1,(ix+$18)
	jr      z,+
	ld      a,($d223)
	bit     0,a
	ret     nz
	and     $02
	ld      e,a
	ld      d,$00
	ld      hl,_bcc7
	add     hl,de
	ld      b,$0a
	ld      de,$0130
	
-	push    bc
	push    de
	call    _bca5
	pop     de
	push    hl
	ld      hl,$0010
	add     hl,de
	ex      de,hl
	pop     hl
	pop     bc
	djnz    -
	
	ld      hl,$0390
	ld      c,(ix+$11)
	ld      b,$00
	add     hl,bc
	ld      c,l
	ld      b,h
	ld      hl,$000c
	add     hl,bc
	ld      de,($d3fe)
	and     a
	sbc     hl,de
	jr      c,+
	ld      hl,$000e
	add     hl,de
	and     a
	sbc     hl,bc
	jr      c,+
	bit     0,(iy+vars.scrollRingFlags)
	call    z,_35fd
+	ld      a,($d2ec)
	cp      $06
	jr      nc,++
	bit     1,(ix+$18)
	jr      nz,+
	ld      a,(ix+$11)
	inc     a
	ld      (ix+$11),a
	cp      $80
	ret     c
	ld      a,($d223)
	ld      c,a
	and     $01
	ret     nz
	set     1,(ix+$18)
	ret
	
+	ld      a,($d223)
	and     $0f
	jr      nz,+
	ld      a,$13
	rst     $28			;`playSFX`
+	dec     (ix+$11)
	ret     nz
	ld      (ix+$11),$00
	res     1,(ix+$18)
	ret
	
++	ld      hl,($d3fe)
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	and     a
	sbc     hl,de
	jr      nc,+
	ld      a,(ix+$11)
	and     a
	jr      z,++
	dec     (ix+$11)
	jr      ++
	
+	ld      a,(ix+$11)
	cp      $80
	jr      nc,++
	inc     (ix+$11)
++	res     1,(ix+$18)
	ld      a,($d223)
	ld      c,a
	and     $40
	ret     nz
	ld      a,($d2ec)
	cp      $06
	ret     z
	set     1,(ix+$18)
	ld      a,c
	and     $1f
	ret     nz
	ld      a,$13
	rst     $28			;`playSFX`
	ret

;____________________________________________________________________________[$BAC5]___

_bca5:
	ld      (RAM_TEMP3),de
	ld      a,(hl)
	inc     hl
	push    hl
	call    _3581
	pop     hl
	ld      a,(hl)
	inc     hl
	push    hl
	ld      hl,(RAM_TEMP4)
	push    hl
	ld      de,$0008
	add     hl,de
	ld      (RAM_TEMP4),hl
	call    _3581
	pop     hl
	ld      (RAM_TEMP4),hl
	pop     hl
	ret

_bcc7:
.db $36, $38, $56, $58, $36, $38, $56, $58, $36, $38, $56, $58, $36, $38, $56, $58
.db $36, $38, $56, $58, $36, $38
_bcdd:
.db $40, $42

;____________________________________________________________________________[$BCDF]___
;OBJECT: UNKNOWN

_bcdf:
	set     5,(ix+$18)
	set     5,(iy+vars.unknown0)
	ld      hl,$0202
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
	bit     0,(iy+vars.scrollRingFlags)
	call    z,_35fd
	jp      ++++
	
+	ld      a,(ix+$11)
	cp      $c8
	jp      c,+++
	ld      e,(ix+$02)
	ld      d,(ix+$03)
	ld      hl,($d25a)
	ld      bc,$fff4
	add     hl,bc
	and     a
	sbc     hl,de
	jp      nc,++++
	ld      hl,($d25a)
	inc     h
	and     a
	sbc     hl,de
	jp      c,++++
	ld      hl,($d3fe)
	and     a
	sbc     hl,de
	ld      l,(ix+$07)
	ld      h,(ix+$08)
	ld      a,(ix+$09)
	jr      nc,+
	ld      c,$ff
	ld      de,$fff4
	bit     7,a
	jr      nz,++
	ld      de,$ffe8
	jr      ++

+	ld      c,$00
	ld      de,$000c
	bit     7,a
	jr      z,++
	ld      de,$0018
++	add     hl,de
	adc     a,c
	ld      (ix+$07),l
	ld      (ix+$08),h
	ld      (ix+$09),a
	ld      e,(ix+$05)
	ld      d,(ix+$06)
	ld      hl,($d25d)
	ld      bc,$fff4
	add     hl,bc
	and     a
	sbc     hl,de
	jr      nc,++++
	ld      hl,($d25d)
	ld      bc,$00c0
	add     hl,de
	and     a
	sbc     hl,de
	jr      c,++++
	ld      hl,($d401)
	and     a
	sbc     hl,de
	ld      l,(ix+$0a)
	ld      h,(ix+$0b)
	ld      a,(ix+$0c)
	jr      nc,+
	ld      c,$ff
	ld      de,$fff6
	bit     7,a
	jr      nz,++
	ld      de,$fffb
	jr      ++
	
+	ld      de,$000a
	ld      c,$00
	bit     7,a
	jr      z,++
	ld      de,$0005
++	add     hl,de
	adc     a,c
	ld      (ix+$0a),l
	ld      (ix+$0b),h
	ld      (ix+$0c),a
	jr      +
+++	inc     (ix+$11)
+	ld      bc,_bdc7
	ld      de,_bdce
	call    _7c41
	bit     4,(iy+vars.unknown0)
	ret     nz
++++	ld      (ix+$00),$ff
	res     5,(iy+vars.unknown0)
	ret

_bdc7:
.db $00, $01, $01, $01, $02, $01, $FF

;sprite layout
_bdce:
.db $44, $46, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $48, $08, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF
.db $FF, $FF, $FF, $FF, $FF, $FF

.db $60, $62, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$BDF9]___
;OBJECT: final animation

_bdf9:
	set     5,(ix+$18)
	ld      (iy+vars.joypad),$ff
	bit     1,(ix+$18)
	jr      nz,+
	ld      hl,S1_BossPalette
	ld      a,$02
	call    loadPaletteOnInterrupt
	ld      a,$ff
	ld      ($d3fc),a
	ld      hl,$0000
	ld      ($d401),hl
	ld      (ix+$12),$ff
	set     6,(iy+vars.timeLightningFlags)
	set     1,(ix+$18)
+	ld      a,($d223)
	rrca    
	jr      c,+
	ld      a,(ix+$12)
	and     a
	jr      z,+
	dec     (ix+$12)
	jr      nz,+
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      de,$003c
	add     hl,de
	ld      ($d3fe),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$ffc0
	add     hl,de
	ld      ($d401),hl
	xor     a
	ld      ($d3fc),a
	set     6,(iy+vars.unknown0)
	ld      a,$06
	rst     $28			;`playSFX`
+	ld      (ix+$0d),$20
	ld      (ix+$0e),$1c
	xor     a
	ld      (ix+$07),a
	ld      (ix+$08),$01
	ld      (ix+$09),a
	ld      (ix+$0a),a
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	bit     6,(iy+vars.timeLightningFlags)
	jr      z,+
	ld      de,($d25a)
	ld      hl,$0040
	add     hl,de
	ld      c,(ix+$02)
	ld      b,(ix+$03)
	and     a
	sbc     hl,bc
	jr      nc,+
	inc     de
	ld      ($d25a),de
+	ld      (ix+$0f),<_bf21
	ld      (ix+$10),>_bf21
	bit     0,(ix+$18)
	jr      nz,+
	ld      hl,$1008
	ld      (RAM_TEMP6),hl
	call    _LABEL_3956_11
	jr      c,+
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
	res     6,(iy+vars.timeLightningFlags)
	set     0,(ix+$18)
	ld      (ix+$11),$01
	ld      a,$01
	rst     $28			;`playSFX`
+	call    _79fa
	bit     0,(ix+$18)
	ret     z
	xor     a
	ld      (ix+$0a),$40
	ld      (ix+$0b),a
	ld      (ix+$0c),a
	ld      (ix+$0f),<_bf33
	ld      (ix+$10),>_bf33
	dec     (ix+$11)
	ret     nz
	call    _7a3a
	ld      (ix+$11),$18
	inc     (ix+$13)
	ld      a,(ix+$13)
	cp      $0a
	ret     c
	ld      a,($d27f)
	cp      $06
	jr      c,+
	set     7,(iy+vars.unknown0)
	ret
	
+	ld      a,($d289)
	and     a
	ret     nz
	ld      a,$20
	ld      ($d289),a
	set     2,(iy+$0d)
	ret

_bf21:
.db $2A, $2C, $2E, $30, $32, $FF, $4A, $4C, $4E, $50, $52, $FF, $6A, $6C, $6E, $70
.db $72, $FF

;sprite layout
_bf33:
.db $2A, $34, $36, $38, $32, $FF
.db $4A, $4C, $4E, $50, $52, $FF
.db $6A, $6C, $6E, $70, $72, $FF
.db $5C, $5E, $FF, $FF, $FF, $FF
.db $FF

;____________________________________________________________________________[$BF4C]___
;OBJECT: all emeralds animation

_bf4c:
	set     5,(ix+$18)
	ld      hl,$5400		;$15400 - emerald image
	call    _c1d
	
	bit     0,(ix+$18)
	jr      nz,+
	
	xor     a
	ld      (ix+$0f),a
	ld      (ix+$10),a
	ld      (ix+$07),a
	ld      (ix+$08),a
	ld      (ix+$09),a
	inc     (ix+$11)
	ld      a,(ix+$11)
	cp      $50
	ret     c
	set     0,(ix+$18)
	ld      (ix+$11),$64
	ret
	
+	ld      a,(ix+$11)
	and     a
	jr      z,+
	dec     (ix+$11)
	jr      ++
	
+	ld      (ix+$0a),$80
	ld      (ix+$0b),$ff
	ld      (ix+$0c),$ff
++	ld      hl,_bff1
	ld      a,($d223)
	rrca    
	jr      nc,+
	ld      a,(iy+vars.spriteCount)
	ld      hl,(RAM_SPRITETABLE_CURRENT)
	push    af
	push    hl
	ld      hl,$d000
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,($d25d)
	and     a
	sbc     hl,de
	ex      de,hl
	ld      l,(ix+$02)
	ld      h,(ix+$03)
	ld      bc,($d25a)
	and     a
	sbc     hl,bc
	ld      bc,_bff1		;address of sprite layout
	call    processSpriteLayout
	pop     hl
	pop     af
	ld      (RAM_SPRITETABLE_CURRENT),hl
	ld      (iy+vars.spriteCount),a
+	ld      l,(ix+$05)
	ld      h,(ix+$06)
	ld      de,$0020
	add     hl,de
	ld      de,($d25d)
	and     a
	sbc     hl,de
	ret     nc
	ld      a,$01
	ld      ($d289),a
	set     2,(iy+$0d)
	ret

;sprite layout
_bff1:
.db $5C, $5E, $FF, $FF, $FF, $FF
.db $FF

.db $49, $43, $20, $54, $48, $45, $20, $48

;======================================================================================
;music code and song data

.BANK 3 SLOT 1
.ORGA $4000

.include "SOUND\sound_driver.asm"
.include "SOUND\music.asm"

;we might be able to set a background repeating text like this so that we don't have
 ;to specify precise gap-filling like this
.ORGA $7FB1
.db "Master System & Game Gear Version.  "
.db "'1991 (C)Ancient. (BANK0-4)", $A2
.db "SONIC THE HEDGE"

;======================================================================================
;block mappings

.BANK 4
.ORG $0000

;[$10000]
S1_BlockMappings:

S1_BlockMappings_GreenHill:
.INCBIN "ROM.sms" SKIP $10000 READ 2944

S1_BlockMappings_Bridge:
.INCBIN "ROM.sms" SKIP $10B80 READ 2304

S1_BlockMappings_Jungle:
.INCBIN "ROM.sms" SKIP $11480 READ 2560

S1_BlockMappings_Labyrinth:
.INCBIN "ROM.sms" SKIP $11E80 READ 2816

S1_BlockMappings_ScrapBrain:
.INCBIN "ROM.sms" SKIP $12980 READ 3072

S1_BlockMappings_SkyBaseExterior:
;.INCBIN "ROM.sms" SKIP $13580 READ 3456
.INCBIN "ROM.sms" SKIP $13580 READ ($14000 - $13580)
.BANK 5
.ORG $0000
.INCBIN "ROM.sms" SKIP $14000 READ 3456 - ($14000 - $13580)

S1_BlockMappings_SkyBaseInterior:
.INCBIN "ROM.sms" SKIP $14300 READ 1664

S1_BlockMappings_SpecialStage:
.INCBIN "ROM.sms" SKIP $14980 READ 2048

;======================================================================================
;"blinking items"
;(need to properly break these down)

;[$15180]
.INCBIN "ROM.sms" SKIP $15180 READ 1024

;======================================================================================
;level headers:

.MACRO TABLE ARGS tableName
	;define the current position as the table name
__TABLE\@__:
	.DEF \1 __TABLE\@__
	;then define a reference used for counting the row index
	.REDEF __ROW__ 0
.ENDM

.MACRO ROW ARGS rowIndexLabel
__ROW\@__:
	.IFDEFM \1
		.DEF \1 __ROW__
	.ENDIF
	.REDEF __ROW__ (__ROW__+1)
.ENDM

.MACRO ENDTABLE ARGS tableName
	.DEF _sizeof_\1 (__ROW__+1)
.ENDM


.BANK 5

;[$15580]
S1_LevelHeader_Pointers:

;[$155CA]
.ORG $155CA - $14000

 TABLE "S1_LevelHeaders"
 ROW "index_levelHeaders_greenHill1"
.db $00					;SP: SolidityPointer
.dw $0100, $0010			;FW/FH: FloorWidth/Height
.db $40					;CL: CropLeft
.db $00					;LX: LevelXOffset
.db $C0					;unknown byte
.db $18					;LW: LevelWidth
.db $20					;CT: CropTop
.db $00					;LY: LevelYOffset
.db $40					;XH: ExtendHeight
.db $01					;LH: LevelHeight
.db $08					;SX: StartX
.db $0B					;SY: StartY
.dw $2DEA				;FL: FloorLayout
.dw $083E				;FS: FloorSize
.dw $0000				;BM: BlockMappings
.dw $2FE6				;LA: LevelArt
.db $09					;SB: SpriteBank
.dw $612A				;SA: SpriteArt
.db $00					;IP: InitialPalette
.db $0A					;CS: CycleSpeed
.db $03					;CC: CycleCount
.db $00					;CP: CyclePalette
.dw $0534				;OL: ObjectLayout
.db $04					;SR: Scrolling/Ring flags
.db $00					;UW: Underwater flag
.db $20					;TL: Time/Lightning flags
.db $00					;X0: Unknown byte - always 0
.db $00					;MU: Music
 ENDTABLE "S1_LevelHeaders"