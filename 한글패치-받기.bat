@echo off
chcp 65001 > nul
title 엘리 한글패치 받기

rem 이 파일 하나만 있으면 된다. 실행할 때 설치 스크립트를 깃허브에서 받아와
rem 실행하므로, 스크립트가 바뀌어도 친구들은 이 파일을 다시 받을 필요가 없다.
rem 압축을 풀게 하면 "안 풀고 그냥 실행"하는 사고가 잦아서 파일 하나로 합쳤다.

set "SRC=https://raw.githubusercontent.com/spoemeo-code/elly-korean-patch/main/install.ps1"
set "TMP=%TEMP%\elly-patch-install.ps1"

echo.
echo   엘리 한글패치
echo   ───────────────────────
echo   설치 도구를 받는 중...

if exist "%TMP%" del /q "%TMP%"
curl.exe -L -f -s -o "%TMP%" "%SRC%"
if not errorlevel 1 goto run
powershell -NoProfile -Command "try { Invoke-WebRequest -UseBasicParsing '%SRC%' -OutFile '%TMP%' } catch { exit 1 }"
if not errorlevel 1 goto run

echo.
echo   [오류] 설치 도구를 받지 못했어요.
echo   인터넷이 되는지 확인하고 다시 실행해 주세요.
echo.
pause
exit /b 1

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP%"
del /q "%TMP%" 2>nul
exit /b 0
