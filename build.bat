@ECHO OFF
CD %~dp0

SET WLAZ80="bin\wla-dx\wla-z80.exe" -x -I "src"
SET WLALINK="bin\wla-dx\wlalink.exe"
SET OPTIONS=-D OPTION_SOUND

CLS
ECHO:
ECHO * assemble source code:
ECHO =======================
ECHO - assemble "sms.wla"
%WLAZ80% %OPTIONS% -i -o "build/sms.o" 		"src/lib/sms.wla"
ECHO - assemble "ram.wla"
%WLAZ80% %OPTIONS% -i -o "build/ram.o" 		"src/ram.wla"
ECHO - assemble "irqs.wla"
%WLAZ80% %OPTIONS% -i -l "build/irqs.lib"	"src/irqs.wla"
ECHO - assemble "orig.wla"
%WLAZ80% %OPTIONS% -i -l "build/orig.lib"	"src/orig.wla"
ECHO - assemble "blocks.wla"
%WLAZ80% %OPTIONS% -i -o "build/blocks.o" 	"src/blocks.wla"
ECHO - assemble "sonic_the_hedgehog.wla"
%WLAZ80% %OPTIONS% -i -o "build/sonic_the_hedgehog.o" "src/sonic_the_hedgehog.wla"

ECHO - assemble "sound.wla"
%WLAZ80% %OPTIONS% -i -l "build/sound.lib" "src/sound.wla"

IF ERRORLEVEL 1 (
    ECHO ! Error
    ECHO:
    GOTO:EOF
)
ECHO - link "sonic_the_hedgehog.wla"
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