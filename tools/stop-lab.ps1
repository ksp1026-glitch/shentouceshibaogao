<#
    DVWA Lab stopper - shuts down Apache and MySQL started by start-lab.ps1.
    Double-click this file, or run:
        powershell -ExecutionPolicy Bypass -File .\stop-lab.ps1

    ASCII-only source on purpose: avoids codepage problems on
    Windows PowerShell 5.1 with non-Chinese system locales.
#>

[CmdletBinding()]
param(
    [string]$XamppRoot = 'E:\xampp'
)

$ErrorActionPreference = 'Continue'

function Say  { param([string]$m, [string]$c = 'Gray') Write-Host "  $m" -ForegroundColor $c }
function Step { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok   { param([string]$m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn { param([string]$m) Write-Host "  [!] $m" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Magenta
Write-Host "     Stopping DVWA Lab" -ForegroundColor Magenta
Write-Host "  ========================================" -ForegroundColor Magenta

# Only stop processes that belong to THIS XAMPP install, so an unrelated
# MySQL/HTTP service on the machine is not touched by accident.
$apachePath = (Join-Path $XamppRoot 'apache\bin\httpd.exe')
$mysqlPath  = (Join-Path $XamppRoot 'mysql\bin\mysqld.exe')

foreach ($item in @(
    @{ Name = 'Apache'; Path = $apachePath },
    @{ Name = 'MySQL';  Path = $mysqlPath  }
)) {
    Step "Stopping $($item.Name)"
    $procs = Get-CimInstance Win32_Process -Filter "Name='$(Split-Path $item.Path -Leaf)'" -ErrorAction SilentlyContinue |
             Where-Object { $_.ExecutablePath -eq $item.Path }

    if (-not $procs) {
        Ok "Not running (or not started from $($item.Path))"
        continue
    }
    foreach ($p in $procs) {
        try {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
            Ok "Stopped PID $($p.ProcessId)"
        } catch {
            Warn "Could not stop PID $($p.ProcessId): $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Yellow
Write-Host "    Lab stopped" -ForegroundColor Green
Write-Host "    Restart with:  .\start-lab.ps1" -ForegroundColor Gray
Write-Host "  ========================================" -ForegroundColor Yellow
Write-Host ""
