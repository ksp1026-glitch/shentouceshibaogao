@echo off
chcp 65001 >nul
setlocal

REM ============================================================
REM   DVWA Lab - Stop
REM   Shuts down the Apache and MariaDB started by DVWA-Start.bat.
REM   Only touches processes that live under E:\xampp.
REM ============================================================

set "SCRIPT=F:\DSH\shentouceshibaogao\tools\stop-lab.ps1"

title DVWA Lab - Stop

if not exist "%SCRIPT%" (
    echo.
    echo   [X] Script not found:
    echo       %SCRIPT%
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
    echo   You can close this window.
    REM ping is used as a portable delay; "timeout" fails when stdio is redirected
    ping -n 3 127.0.0.1 >nul 2>&1
) else (
    echo.
    echo   [!] Something went wrong - read the messages above.
    echo.
    pause
)

endlocal
