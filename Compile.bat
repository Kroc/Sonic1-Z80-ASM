@ECHO OFF
CLS

CD %~dp0

IF EXIST S1.o ERASE S1.o
WLADX\wla-z80 -o s1.sms.asm

IF EXIST S1-mod.sms ERASE S1-mod.sms
IF %ERRORLEVEL% EQU 0 WLADX\wlalink -r link.txt ROM_NEW.sms

IF %ERRORLEVEL% EQU 0 VBinDiff\VBinDiff.exe ROM.sms ROM_NEW.sms

PAUSE