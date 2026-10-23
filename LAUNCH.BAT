@echo off
rem Run from the project directory. CHOICE is built into DOSBox.
:menu
cls
echo UDAV - DOS snake
echo ================
echo.
echo 1. Build and run
echo 2. Build only
echo 3. Run existing build
echo 4. View build logs
echo 5. Return to DOS prompt
echo.
choice /c12345 /n Select [1-5]:
rem Test ERRORLEVEL in descending order: IF means greater than or equal.
if errorlevel 5 goto end
if errorlevel 4 goto logs
if errorlevel 3 goto run
if errorlevel 2 goto build
if errorlevel 1 goto buildrun
goto menu

:buildrun
call BUILD.BAT
if "%UDAV_BUILT%"=="1" goto run
pause
goto menu

:build
call BUILD.BAT
pause
goto menu

:run
if not exist BUILD\ZMEI.COM goto missing
BUILD\ZMEI.COM
goto menu

:missing
echo No BUILD\ZMEI.COM found. Choose 1 or 2 to build first.
pause
goto menu

:logs
echo.
echo --- Assembler ---
if exist BUILD\ASSEMBLE.LOG type BUILD\ASSEMBLE.LOG
if not exist BUILD\ASSEMBLE.LOG echo No assembler log. Build the game first.
echo.
echo --- Linker ---
if exist BUILD\LINK.LOG type BUILD\LINK.LOG
if not exist BUILD\LINK.LOG echo No linker log. Build the game first.
echo.
pause
goto menu

:end
