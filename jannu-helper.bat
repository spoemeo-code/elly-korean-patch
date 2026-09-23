@echo off
chcp 65001 > nul
title 잔누 마크 도우미

rem Launcher. Downloads the helper window from GitHub and runs it hidden.
rem Comments stay in English: Korean comments broke parsing before chcp ran.

set "SRC=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/gui.ps1"
set "TMP=%TEMP%\jannu-helper-gui.ps1"
set "SIDE=jannu"

curl.exe -L -f -s -o "%TMP%" "%SRC%"
if not errorlevel 1 goto run
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing '%SRC%' -OutFile '%TMP%' } catch { exit 1 }"
if not errorlevel 1 goto run

echo.
echo   프로그램을 받지 못했습니다.
echo   인터넷 연결을 확인하신 뒤 다시 실행해 주세요.
echo.
pause
exit /b 1

:run
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%TMP%" -Server %SIDE%
exit /b 0