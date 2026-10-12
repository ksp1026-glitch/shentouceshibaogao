@echo off
chcp 65001 >nul
setlocal

REM ============================================================
REM   DVWA Lab - Start
REM   Starts XAMPP Apache + MariaDB, then opens the browser.
REM   Double-click this file (or the desktop shortcut).
REM ============================================================

set "SCRIPT=F:\DSH\shentouceshibaogao\tools\start-lab.ps1"
set "URL=http://localhost/dvwa/"

title DVWA Lab

if not exist "%SCRIPT%" (
    echo.
    echo   [X] Launcher not found:
    echo       %SCRIPT%
    echo.
    pause
    exit /b 1
)

echo.
echo   Starting DVWA lab, please wait...
echo.

REM -NoBrowser: let this script open the browser AFTER services are up
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -NoBrowser
set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
    start "" "%URL%"
    echo   Browser opened. You can close this window.
    REM ping is used as a portable delay; "timeout" fails when stdio is redirected
    ping -n 3 127.0.0.1 >nul 2>&1
) else (
    echo.
    echo   [!] Something went wrong - read the messages above.
    echo       If it mentions Administrator, run the desktop shortcut
    echo       "DVWA Lab (Admin)" instead - it elevates automatically.
    echo.
    pause
)

endlocal
