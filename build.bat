@ECHO OFF
CD %~dp0

SET WLAZ80="bin\wla-z80.exe"
SET WLALINK="bin\wlalink.exe"
SET OPTIONS=-D OPTION_AUDIO

CLS
ECHO:
ECHO * assemble source code:
ECHO =======================
ECHO - assemble "sonic_the_hedgehog.asm"
%WLAZ80% %OPTIONS% -i -o "build/sonic_the_hedgehog.o" "sonic_the_hedgehog.asm"
IF ERRORLEVEL 1 (
    ECHO ! Error
    ECHO:
    GOTO:EOF
)
ECHO - link "sonic_the_hedgehog.sms"
%WLALINK% -S "link.ini" "sonic_the_hedgehog.sms"

ECHO * OK.
ECHO: