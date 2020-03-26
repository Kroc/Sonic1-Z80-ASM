@ECHO OFF
CD %~dp0

SET WLAZ80="bin\wla-dx\wla-z80.exe" -I "src"
SET WLALINK="bin\wla-dx\wlalink.exe"
SET OPTIONS=-D OPTION_SOUND

CLS
ECHO:
ECHO * assemble source code:
ECHO =======================
ECHO - assemble "sms.asm"
%WLAZ80% %OPTIONS% -i -o "build/sms.o" "src/lib/sms.asm"
ECHO - assemble "ram.asm"
%WLAZ80% %OPTIONS% -i -o "build/ram.o" "src/ram.asm"
ECHO - assemble "sound.asm"
%WLAZ80% %OPTIONS% -i -o "build/sound.o" "src/sound.asm"
ECHO - assemble "blocks.asm"
%WLAZ80% %OPTIONS% -i -o "build/blocks.o" "src/blocks.asm"
ECHO - assemble "sonic_the_hedgehog.asm"
%WLAZ80% %OPTIONS% -i -o "build/sonic_the_hedgehog.o" "src/sonic_the_hedgehog.asm"
IF ERRORLEVEL 1 (
    ECHO ! Error
    ECHO:
    GOTO:EOF
)
ECHO - link "sonic_the_hedgehog.sms"
%WLALINK% -S "link.ini" "sonic_the_hedgehog.sms"

IF %ERRORLEVEL% EQU 0 bin\VBinDiff\VBinDiff.exe ^
	"Sonic the Hedgehog (1991)(Sega).bin" ^
	"sonic_the_hedgehog.sms"

ECHO * OK.