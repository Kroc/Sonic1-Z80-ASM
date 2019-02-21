@ECHO OFF
CD %~dp0

SET WLAZ80="bin\wla-z80.exe"
SET WLALINK="bin\wlalink.exe"
SET OPTIONS=-D OPTION_AUDIO

CLS
ECHO:
ECHO * assemble source code:
ECHO =======================
ECHO - assemble "ram.asm"
%WLAZ80% %OPTIONS% -o "build/ram.o" "ram.asm"
ECHO - assemble "sonic_the_hedgehog.asm"
%WLAZ80% %OPTIONS% -v -i -o "build/sonic_the_hedgehog.o" "sonic_the_hedgehog.asm"
IF NOT ERRORLEVEL 1 (
    ECHO - link "sonic_the_hedgehog.sms"
    %WLALINK% -S -v "link.ini" "sonic_the_hedgehog.sms"
    ECHO * OK.
)
ECHO: