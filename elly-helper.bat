@echo off
chcp 65001 > nul
title 엘리 마크 도우미
set "SELF=%~f0"
set "APPTITLE=엘리 마크 도우미"

rem Launcher. Downloads the helper window from GitHub and runs it hidden.
rem Keep this file CRLF with no BOM, or cmd mis-reads the lines.

set "BASE=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main"
set "SRC=%BASE%/gui-elly.ps1"
set "GUIFILE=%TEMP%\elly-helper-gui.ps1"
set "SIDE=elly"
set "HOMEDIR=%APPDATA%\elly-helper"
set "ICO=%HOMEDIR%\icon.ico"

rem A .bat cannot carry its own icon, so make a shortcut that can.
rem The desktop is not always %USERPROFILE%\Desktop (OneDrive moves it),
rem so ask Windows where it actually is.
if not exist "%HOMEDIR%" mkdir "%HOMEDIR%" >nul 2>&1
if not exist "%ICO%" curl.exe -L -f -s -o "%ICO%" "%BASE%/elly-icon.ico"
if exist "%ICO%" powershell -NoProfile -Command "$d=[Environment]::GetFolderPath('Desktop'); if ($d) { $p=Join-Path $d ($env:APPTITLE + '.lnk'); if (-not (Test-Path $p)) { $s=(New-Object -ComObject WScript.Shell).CreateShortcut($p); $s.TargetPath=$env:SELF; $s.WorkingDirectory=(Split-Path $env:SELF); $s.IconLocation=$env:ICO; $s.Description=$env:APPTITLE; $s.Save() } }" >nul 2>&1

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
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%GUIFILE%" -Server %SIDE%
exit /b 0
