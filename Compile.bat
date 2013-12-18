@ECHO OFF
CLS
COLOR 1F

CD %~dp0

IF EXIST S1.o ERASE S1.o
IF EXIST ROM_NEW.sms ERASE ROM_NEW.sms
IF EXIST ROM_NEW.sym ERASE ROM_NEW.sym

ECHO.
ECHO Compiling Object File...
ECHO ===============================================================================
IF %ERRORLEVEL% EQU 0 WLADX\wla-z80 -vo s1.sms.asm S1.o

ECHO.
ECHO Linking ROM...
ECHO ===============================================================================
IF %ERRORLEVEL% EQU 0 WLADX\wlalink -vSr link.txt ROM_NEW.sms

ECHO.
IF %ERRORLEVEL% EQU 0 VBinDiff\VBinDiff.exe ROM.sms ROM_NEW.sms

PAUSE