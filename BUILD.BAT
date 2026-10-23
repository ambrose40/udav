@echo off
rem Run inside DOS/DOSBox from the repository root.
set UDAV_BUILT=0
if not exist BUILD\NUL mkdir BUILD
TASM\TASM.EXE /l ZMEI.ASM,BUILD\,BUILD\ > BUILD\ASSEMBLE.LOG
if errorlevel 1 goto failed
TASM\TLINK.EXE /t /m BUILD\ZMEI.OBJ,BUILD\ZMEI.COM,BUILD\ZMEI.MAP > BUILD\LINK.LOG
if errorlevel 1 goto failed
echo Build succeeded: BUILD\ZMEI.COM
set UDAV_BUILT=1
goto end
:failed
echo Build failed. See BUILD\ASSEMBLE.LOG and BUILD\LINK.LOG.
:end
