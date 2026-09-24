@echo off
chcp 65001 > nul
title 엘리 마크 도우미

rem Runs the loader, which checks the signed release manifest before running
rem anything. On the first run on this PC the loader is fetched once; after
rem that it only replaces itself with copies that match the signed manifest.
rem Keep this file CRLF with no BOM, or cmd mis-reads the lines.

set "HOMEDIR=%APPDATA%\elly-helper"
set "LOADER=%HOMEDIR%\loader.ps1"
set "SRC=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/loader.ps1"
if not exist "%HOMEDIR%" mkdir "%HOMEDIR%" >nul 2>&1
if exist "%LOADER%" goto run

curl.exe -L -f -s -o "%LOADER%" "%SRC%"
if not errorlevel 1 goto run
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing $env:SRC -OutFile $env:LOADER } catch { exit 1 }"
if not errorlevel 1 goto run

echo.
echo   프로그램을 받지 못했습니다.
echo   인터넷 연결을 확인하신 뒤 다시 실행해 주세요.
echo.
pause
exit /b 1

:run
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%LOADER%" -Server elly -Launcher "%~f0"
exit /b 0
