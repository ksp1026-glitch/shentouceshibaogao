<#
    Start the Clash Verge core (mihomo) manually.
    ================================================================
    WHY THIS EXISTS
      Clash Verge 2.5.7 tries to launch its core through a Windows
      service ("service mode"). If that service is not installed, the
      core never starts and you end up with no proxy at all.

      Installing the service needs Administrator rights:
          & "C:\Program Files\Clash Verge\resources\clash-verge-service-install.exe"
      Run that from an elevated PowerShell to fix it properly.

      Until then, this script starts the core directly. The GUI will
      NOT be able to control it, but the proxy (port 7897) works.

    USAGE
        powershell -ExecutionPolicy Bypass -File .\start-clash-core.ps1
        powershell -ExecutionPolicy Bypass -File .\start-clash-core.ps1 -Stop

    ASCII-only source on purpose: avoids codepage problems on
    Windows PowerShell 5.1 with non-Chinese system locales.
#>

[CmdletBinding()]
param(
    [string]$ConfigDir = "$env:APPDATA\io.github.clash-verge-rev.clash-verge-rev",
    [string]$CoreExe   = 'C:\Program Files\Clash Verge\verge-mihomo.exe',
    [int]$ProxyPort    = 7897,
    [switch]$Stop
)

$ErrorActionPreference = 'Continue'

function Say  { param([string]$m, [string]$c = 'Gray') Write-Host "  $m" -ForegroundColor $c }
function Step { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok   { param([string]$m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn { param([string]$m) Write-Host "  [!] $m" -ForegroundColor Yellow }

function Test-Port {
    param([int]$Port)
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

$cfg = Join-Path $ConfigDir 'clash-verge.yaml'

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Magenta
Write-Host "     Clash core (mihomo) control" -ForegroundColor Magenta
Write-Host "  ========================================" -ForegroundColor Magenta

# ------------------------------------------------------------------ STOP
if ($Stop) {
    Step "Stopping core"
    $procs = Get-Process -Name 'verge-mihomo*' -ErrorAction SilentlyContinue
    if (-not $procs) { Ok "No core process running" }
    else {
        foreach ($p in $procs) {
            try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Ok "Stopped PID $($p.Id)" }
            catch { Warn "Could not stop PID $($p.Id): $($_.Exception.Message)" }
        }
    }
    Start-Sleep -Seconds 2
    if (Test-Port $ProxyPort) { Warn "Port $ProxyPort still listening" }
    else { Ok "Proxy port $ProxyPort released" }
    Say "Note: this does NOT stop the Clash Verge GUI." 'DarkGray'
    exit 0
}

# ------------------------------------------------------------------ START
Step "1/5 Checking prerequisites"
if (-not (Test-Path $CoreExe)) { Warn "Core not found: $CoreExe"; exit 1 }
Ok "Core: $CoreExe"
if (-not (Test-Path $cfg)) { Warn "Config not found: $cfg"; exit 1 }
Ok "Config: $cfg"

Step "2/5 Checking if already running"
if (Test-Port $ProxyPort) {
    Ok "Port $ProxyPort already listening - nothing to do"
    Say "If the proxy is broken, stop it first:  -Stop" 'DarkGray'
    exit 0
}
if (Get-Process -Name 'verge-mihomo*' -ErrorAction SilentlyContinue) {
    Warn "A core process exists but the port is not open; restarting it"
    Get-Process -Name 'verge-mihomo*' -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
}

Step "3/5 Validating config"
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$testOut = & $CoreExe -t -d $ConfigDir -f $cfg 2>&1
$testCode = $LASTEXITCODE
$ErrorActionPreference = $prevEap

if ($testCode -ne 0) {
    Warn "Config test failed (exit $testCode):"
    $testOut | Select-Object -First 8 | ForEach-Object { Warn "  $_" }
    exit 1
}
Ok "Config is valid"

Step "4/5 Starting core"
$logOut = Join-Path $ConfigDir 'manual-core.log'
$logErr = Join-Path $ConfigDir 'manual-core.err.log'
Remove-Item $logOut, $logErr -Force -ErrorAction SilentlyContinue

$proc = Start-Process -FilePath $CoreExe `
    -ArgumentList @('-d', $ConfigDir, '-f', $cfg) `
    -WorkingDirectory $ConfigDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logOut `
    -RedirectStandardError  $logErr `
    -PassThru

# wait for the proxy port
$ready = $false
for ($i = 0; $i -lt 25; $i++) {
    Start-Sleep -Milliseconds 800
    if (Test-Port $ProxyPort) { $ready = $true; break }
}

if (-not $ready) {
    Warn "Port $ProxyPort did not open. Last log lines:"
    Get-Content $logErr -Tail 10 -ErrorAction SilentlyContinue | ForEach-Object { Warn "  $_" }
    exit 1
}
Ok "Core started (PID $($proc.Id)), port $ProxyPort is listening"

Step "5/5 Testing proxy"
$ErrorActionPreference = 'Continue'
$ok = $false
foreach ($u in @('https://www.google.com', 'https://github.com')) {
    try {
        $r = Invoke-WebRequest -Uri $u -Proxy "http://127.0.0.1:$ProxyPort" -TimeoutSec 20 -UseBasicParsing
        Ok "$u  ->  HTTP $($r.StatusCode)"
        $ok = $true
    } catch {
        Warn "$u  ->  $($_.Exception.Message.Split([char]10)[0])"
    }
}
$ErrorActionPreference = $prevEap

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Yellow
if ($ok) {
    Write-Host "    Proxy is WORKING" -ForegroundColor Green
    Write-Host ""
    Write-Host "      System proxy: 127.0.0.1:$ProxyPort" -ForegroundColor Gray
} else {
    Write-Host "    Core is up but traffic failed" -ForegroundColor Yellow
    Write-Host "      Check your subscription / node health" -ForegroundColor Gray
}
Write-Host ""
Write-Host "    Stop with : .\start-clash-core.ps1 -Stop" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    NOTE: the Clash Verge GUI cannot control this core." -ForegroundColor DarkGray
Write-Host "          To fix properly, install the service as Administrator:" -ForegroundColor DarkGray
Write-Host '          & "C:\Program Files\Clash Verge\resources\clash-verge-service-install.exe"' -ForegroundColor DarkGray
Write-Host "  ========================================" -ForegroundColor Yellow
Write-Host ""
