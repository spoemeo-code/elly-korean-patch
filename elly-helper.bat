@echo off
chcp 65001 > nul
title 엘리 마크 도우미

rem Launcher. Downloads the helper window from GitHub and runs it hidden.
rem Comments stay in English: Korean comments broke parsing before chcp ran.

set "BASE=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main"
set "SRC=%BASE%/gui-elly.ps1"
set "TMP=%TEMP%\elly-helper-gui.ps1"
set "SIDE=elly"
set "HOME_DIR=%APPDATA%\elly-helper"
set "ICO=%HOME_DIR%\icon.ico"
set "LNK=%USERPROFILE%\Desktop\엘리 마크 도우미.lnk"

rem A .bat cannot carry its own icon, so make a shortcut that can. Once only.
if not exist "%HOME_DIR%" mkdir "%HOME_DIR%" > nul 2>&1
if not exist "%ICO%" curl.exe -L -f -s -o "%ICO%" "%BASE%/elly-icon.ico"
if not exist "%LNK%" if exist "%ICO%" powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%LNK%'); $s.TargetPath='%~f0'; $s.WorkingDirectory='%~dp0'; $s.IconLocation='%ICO%'; $s.Description='엘리 마크 도우미'; $s.Save()" > nul 2>&1

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