<#
    DVWA Lab launcher - starts Apache + MySQL, waits until ready, opens the browser.
    Double-click this file, or run:
        powershell -ExecutionPolicy Bypass -File .\start-lab.ps1
    Requires no administrator rights for the normal (process) path.

    ASCII-only source on purpose: avoids codepage problems on
    Windows PowerShell 5.1 with non-Chinese system locales.
#>

[CmdletBinding()]
param(
    [string]$XamppRoot = 'E:\xampp',
    [string]$Url       = 'http://localhost/dvwa/',
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Continue'

function Say  { param([string]$m, [string]$c = 'Gray') Write-Host "  $m" -ForegroundColor $c }
function Step { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok   { param([string]$m) Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn { param([string]$m) Write-Host "  [!] $m" -ForegroundColor Yellow }

$httpd  = Join-Path $XamppRoot 'apache\bin\httpd.exe'
$mysqld = Join-Path $XamppRoot 'mysql\bin\mysqld.exe'
$myIni  = Join-Path $XamppRoot 'mysql\bin\my.ini'

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Magenta
Write-Host "     Starting DVWA Lab" -ForegroundColor Magenta
Write-Host "  ========================================" -ForegroundColor Magenta

# ---------------------------------------------------------------- sanity
Step "Checking installation"
if (-not (Test-Path $httpd))  { Write-Host "  [X] Apache not found: $httpd" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $mysqld)) { Write-Host "  [X] MySQL not found: $mysqld" -ForegroundColor Red; exit 1 }
Ok "Apache: $httpd"
Ok "MySQL : $mysqld"

$dvwa = Join-Path $XamppRoot 'htdocs\dvwa\index.php'
if (Test-Path $dvwa) { Ok "DVWA files present" }
else { Warn "DVWA not found at $dvwa - run deploy-to-apache.ps1 first" }

# ---------------------------------------------------------------- port check
function Test-Port {
    param([int]$Port)
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

Step "Starting MySQL (port 3306)"
if (Test-Port 3306) {
    Ok "Already listening on 3306"
} else {
    $args = @()
    if (Test-Path $myIni) { $args += "--defaults-file=$myIni" }
    $args += '--standalone'
    Start-Process -FilePath $mysqld -ArgumentList $args `
        -WorkingDirectory (Split-Path $mysqld) -WindowStyle Hidden | Out-Null

    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 800
        if (Test-Port 3306) { $ready = $true; break }
    }
    if ($ready) { Ok "MySQL is up" } else { Warn "MySQL did not open port 3306 in time" }
}

Step "Starting Apache (port 80)"
if (Test-Port 80) {
    Ok "Already listening on 80"
} else {
    Start-Process -FilePath $httpd -WorkingDirectory (Split-Path $httpd) -WindowStyle Hidden | Out-Null

    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 800
        if (Test-Port 80) { $ready = $true; break }
    }
    if ($ready) { Ok "Apache is up" } else { Warn "Apache did not open port 80 - check E:\xampp\apache\logs\error.log" }
}

# ---------------------------------------------------------------- HTTP check
Step "Testing DVWA"
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$httpOk = $false
try {
    $r = Invoke-WebRequest -Uri $Url -TimeoutSec 20 -UseBasicParsing
    $httpOk = ($r.StatusCode -eq 200)
    Ok "HTTP $($r.StatusCode) from $Url"
} catch {
    Warn "Request failed: $($_.Exception.Message)"
    Warn "Apache may be listening but DVWA not deployed - run deploy-to-apache.ps1"
}
$ErrorActionPreference = $prev

# ---------------------------------------------------------------- report
Write-Host ""
Write-Host "  ========================================" -ForegroundColor Yellow
if ($httpOk) {
    Write-Host "    Lab is READY" -ForegroundColor Green
    Write-Host ""
    Write-Host "      $Url" -ForegroundColor White
    Write-Host "      login: admin / password" -ForegroundColor Gray
} else {
    Write-Host "    Lab may not be fully ready" -ForegroundColor Yellow
    Write-Host "      Check the warnings above." -ForegroundColor Gray
}
Write-Host ""
Write-Host "    Stop later with:  .\stop-lab.ps1" -ForegroundColor DarkGray
Write-Host "  ========================================" -ForegroundColor Yellow
Write-Host ""

if ($httpOk -and -not $NoBrowser) {
    Start-Process $Url
    Say "Browser opened."
}

Say "This window can be closed - services keep running in the background." 'DarkGray'
