@echo off
chcp 65001 > nul
title 잔누 마크 도우미

rem This file only fetches the helper window and runs it. Everything else
rem (icon, desktop shortcut, updating this file) is handled there, so this
rem file should never need to change again.
rem Keep it CRLF with no BOM, or cmd mis-reads the lines.

set "SRC=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/gui.ps1"
set "GUIFILE=%TEMP%\jannu-helper-gui.ps1"

curl.exe -L -f -s -o "%GUIFILE%" "%SRC%"
if not errorlevel 1 goto run
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing $env:SRC -OutFile $env:GUIFILE } catch { exit 1 }"
if not errorlevel 1 goto run

echo.
echo   프로그램을 받지 못했습니다.
echo   인터넷 연결을 확인하신 뒤 다시 실행해 주세요.
echo.
pause
exit /b 1

:run
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%GUIFILE%" -Server jannu -Launcher "%~f0"
exit /b 0
