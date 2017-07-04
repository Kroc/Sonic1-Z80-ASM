
.MEMORYMAP		
	SLOT		0		START $0000 SIZE $4000	;ROM 0
	SLOT		1		START $4000 SIZE $4000	;ROM 1
	SLOT		2		START $8000 SIZE $4000	;ROM 2
	SLOT		3		START $C000 SIZE $2000	;8KB RAM
	DEFAULTSLOT	0
.ENDME

.ENUM	$0000				EXPORT
	sms.slot0			DSB $4000
	sms.slot1			DSB $4000
	sms.slot2			DSB $4000
	sms.ram				DSB $2000
.ENDE

;define the ROM (cartridge) size
.ROMBANKMAP
	BANKSTOTAL	16					;use 16 banks,
	BANKSIZE	$4000					;each 16 KB in size
	BANKS		16		 			;(that's 256 KB)
.ENDRO

;number of hardware sprites on the SEGA Master System:
;there is of course no reason to change this value, other than creating some kind of weird super-SMS emulator
.DEF 	SMS_SPRITES			64

;display dimensions, in pixels, of the SEGA Master System.
;note that the VRAM contains a 256 x 224 px scrollable region for the display

.DEF 	SMS_SCREEN_WIDTH		256                     ;display width in pixels
.DEF 	SMS_SCREEN_HEIGHT               192                     ;display height in pixels
.DEF 	SMS_SCREEN_HEIGHT_EXTENDED      224			;notably used on CodeMasters' MicroMachines game
.DEF	SMS_SCREEN_HEIGHT_SUPEREXTENDED	240
	;the super-extended display height is 240px. This leaves NTSC displays with no VBlank remaining causing the
        ;picture to roll around on the screen. This mode can be used on PAL displays, but leaves you with next to no
        ;VRAM left for sprites or tiles and a miniscule VBlank period

;Z80 ports:
;=======================================================================================================================
.DEF	sms.ports.region		$3E
.DEF	sms.ports.control		$3F

.DEF 	sms.ports.control.io		%00000100
.DEF 	sms.ports.control.bios		%00001000
.DEF 	sms.ports.control.ram		%00010000
.DEF 	sms.ports.control.card		%00100000
.DEF 	sms.ports.control.cart		%01000000
.DEF 	sms.ports.control.expansion	%10000000

.DEF	sms.ports.scanline		$7E
.DEF	sms.ports.psg			$7F
.DEF	sms.ports.vdp_data		$BE
.DEF	sms.ports.vdp_control		$BF

.DEF 	SMS_VDP_REGISTER_WRITE		%10000000
.DEF 	SMS_VDP_REGISTER_0		SMS_VDP_REGISTER_WRITE | 0
.DEF 	SMS_VDP_REGISTER_1		SMS_VDP_REGISTER_WRITE | 1
.DEF 	SMS_VDP_REGISTER_2		SMS_VDP_REGISTER_WRITE | 2
.DEF 	SMS_VDP_REGISTER_5		SMS_VDP_REGISTER_WRITE | 5
.DEF 	SMS_VDP_REGISTER_6		SMS_VDP_REGISTER_WRITE | 6
.DEF 	SMS_VDP_REGISTER_7		SMS_VDP_REGISTER_WRITE | 7
.DEF 	SMS_VDP_REGISTER_8		SMS_VDP_REGISTER_WRITE | 8
.DEF 	SMS_VDP_REGISTER_9		SMS_VDP_REGISTER_WRITE | 9
.DEF 	SMS_VDP_REGISTER_10		SMS_VDP_REGISTER_WRITE | 10

.DEF	sms.ports.joy_a			$DC

.DEF	sms.ports.joy_a.pad1up          %00000001
.DEF	sms.ports.joy_a.pad1down        %00000010
.DEF	sms.ports.joy_a.pad1left	%00000100
.DEF	sms.ports.joy_a.pad1right	%00001000
.DEF	sms.ports.joy_a.pad1button1	%00010000
.DEF	sms.ports.joy_a.pad1button2	%00100000
.DEF	sms.ports.joy_a.pad2up		%01000000
.DEF	sms.ports.joy_a.pad2down	%10000000
.DEF	sms.ports.joy_b.pad2left	%00000001

.DEF	sms.ports.joy_b			$DD

.DEF	sms.ports.joy_b.pad2right	%00000010
.DEF	sms.ports.joy_b.pad2button1	%00000100
.DEF	sms.ports.joy_b.pad2button2	%00001000
.DEF	sms.ports.joy_b.reset		%00010000
.DEF	sms.ports.joy_b.unused		%00100000
.DEF	sms.ports.joy_b.lightgun1	%01000000
.DEF	sms.ports.joy_b.lightgun2	%10000000

.DEF	SMS_JOY_PAD1_UP			sms.ports.joy_a.pad1up
.DEF	SMS_JOY_PAD1_DOWN		sms.ports.joy_a.pad1down
.DEF	SMS_JOY_PAD1_LEFT		sms.ports.joy_a.pad1left
.DEF	SMS_JOY_PAD1_RIGHT		sms.ports.joy_a.pad1right
.DEF	SMS_JOY_PAD1_BUTTON1		sms.ports.joy_a.pad1button1
.DEF	SMS_JOY_PAD1_BUTTON2		sms.ports.joy_a.pad1button2

.DEF	SMS_JOY_PAD2_UP			sms.ports.joy_a.pad2up
.DEF	SMS_JOY_PAD2_DOWN		sms.ports.joy_a.pad2down
.DEF	SMS_JOY_PAD2_LEFT		sms.ports.joy_b.pad2left
.DEF	SMS_JOY_PAD2_RIGHT		sms.ports.joy_b.pad2right
.DEF	SMS_JOY_PAD2_BUTTON1		sms.ports.joy_b.pad2button1
.DEF	SMS_JOY_PAD2_BUTTON2		sms.ports.joy_b.pad2button2

