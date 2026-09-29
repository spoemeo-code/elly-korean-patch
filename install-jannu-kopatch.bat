@echo off
rem Jannu Korean patch installer launcher.
rem Downloads the installer script fresh each run (always the latest, signed release) and runs it hidden.
rem Keep this file CRLF and ASCII only (no BOM), or cmd mis-reads the lines.

set "HOMEDIR=%TEMP%\jannu-kopatch"
set "SCRIPT=%HOMEDIR%\jannu-kopatch.ps1"
set "SRC=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/jannu-kopatch.ps1"
if not exist "%HOMEDIR%" mkdir "%HOMEDIR%" >nul 2>&1

curl.exe -L -f -s -o "%SCRIPT%" "%SRC%"
if not errorlevel 1 goto run
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing $env:SRC -OutFile $env:SCRIPT } catch { exit 1 }"
if not errorlevel 1 goto run

echo.
echo   Could not download the installer.
echo   Please check your internet connection and try again.
echo.
pause
exit /b 1

:run
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SCRIPT%"
exit /b 0
