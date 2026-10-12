@echo off
chcp 65001 >nul
setlocal

REM ============================================================
REM   Clash Core - Start
REM
REM   Use this when Clash Verge says "core is not running" but you
REM   still need your network. It starts the mihomo core directly.
REM
REM   Root fix (needs Administrator):
REM     & "C:\Program Files\Clash Verge\resources\clash-verge-service-install.exe"
REM   Installing the service lets the GUI manage the core normally.
REM ============================================================

set "SCRIPT=F:\DSH\shentouceshibaogao\tools\start-clash-core.ps1"

title Clash Core

if not exist "%SCRIPT%" (
    echo.
    echo   [X] Script not found:
    echo       %SCRIPT%
    echo.
    pause
    exit /b 1
)

echo.
echo   Starting Clash core, please wait...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
    echo.
    echo   Done. You can close this window.
    REM ping is used as a portable delay; "timeout" fails when stdio is redirected
    ping -n 4 127.0.0.1 >nul 2>&1
) else (
    echo.
    echo   [!] Failed - read the messages above.
    echo.
    pause
)

endlocal
