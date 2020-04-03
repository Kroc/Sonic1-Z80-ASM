@ECHO OFF
CD %~dp0

SET WLAZ80="bin\wla-dx\wla-z80.exe" -x -I "src"
SET WLALINK="bin\wla-dx\wlalink.exe"
SET OPTIONS=-D OPTION_SOUND

CLS
ECHO:
ECHO * assemble source code:
ECHO =======================
ECHO - assemble "sms.asm"
%WLAZ80% %OPTIONS% -i -o "build/sms.o" 		"src/lib/sms.asm"
ECHO - assemble "ram.asm"
%WLAZ80% %OPTIONS% -i -o "build/ram.o" 		"src/ram.asm"
ECHO - assemble "irqs.asm"
%WLAZ80% %OPTIONS% -i -l "build/irqs.lib"	"src/irqs.asm"
ECHO - assemble "orig.asm"
%WLAZ80% %OPTIONS% -i -l "build/orig.lib"	"src/orig.asm"
ECHO - assemble "blocks.asm"
%WLAZ80% %OPTIONS% -i -o "build/blocks.o" 	"src/blocks.asm"
ECHO - assemble "sonic_the_hedgehog.asm"
%WLAZ80% %OPTIONS% -i -o "build/sonic_the_hedgehog.o" "src/sonic_the_hedgehog.asm"

ECHO - assemble "sound.asm"
%WLAZ80% %OPTIONS% -i -l "build/sound.lib" "src/sound.asm"

IF ERRORLEVEL 1 (
    ECHO ! Error
    ECHO:
    GOTO:EOF
)
ECHO - link "sonic_the_hedgehog.sms"
%WLALINK% -S "link_original.ini" "build/sonic_the_hedgehog.sms"

IF ERRORLEVEL 1 (
    ECHO ! Error
    ECHO:
    GOTO:EOF
)

IF %ERRORLEVEL% EQU 0 bin\VBinDiff\VBinDiff.exe ^
	"Sonic the Hedgehog (1991)(Sega).bin" ^
	"build/sonic_the_hedgehog.sms"

ECHO * OK.