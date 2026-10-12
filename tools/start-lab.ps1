<#
    DVWA Lab launcher - starts Apache + MariaDB, waits until ready, opens the browser.
    Double-click this file, or run:
        powershell -ExecutionPolicy Bypass -File .\start-lab.ps1

    Handles a common conflict: a standalone MySQL install (e.g. MySQL84) grabbing
    port 3306 before XAMPP's MariaDB can bind it. DVWA's data lives in XAMPP's
    MariaDB, so the intruder must go. Stopping a SERVICE needs an elevated shell;
    the script says so clearly instead of failing silently.

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

$httpd    = Join-Path $XamppRoot 'apache\bin\httpd.exe'
$mysqld   = Join-Path $XamppRoot 'mysql\bin\mysqld.exe'
$myIni    = Join-Path $XamppRoot 'mysql\bin\my.ini'
$mysqlCli = Join-Path $XamppRoot 'mysql\bin\mysql.exe'

function Test-Port {
    param([int]$Port)
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Magenta
Write-Host "     Starting DVWA Lab" -ForegroundColor Magenta
Write-Host "  ========================================" -ForegroundColor Magenta

function Test-Admin {
    return ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------- 1. sanity
Step "1/6 Checking installation"
if (-not (Test-Path $httpd))  { Write-Host "  [X] Apache not found: $httpd" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $mysqld)) { Write-Host "  [X] MySQL not found: $mysqld" -ForegroundColor Red; exit 1 }
Ok "Apache: $httpd"
Ok "MariaDB: $mysqld"
if (Test-Admin) { Ok "Running as Administrator" } else { Say "Not Administrator (fine unless a service must be stopped)" 'DarkGray' }

$dvwa = Join-Path $XamppRoot 'htdocs\dvwa\index.php'
if (Test-Path $dvwa) { Ok "DVWA files present" }
else { Warn "DVWA not found at $dvwa - run deploy-to-apache.ps1 first" }

# ---------------------------------------------------------------- 2. free port 3306
Step "2/6 Checking port 3306"
$portOk = $false
if (Test-Port 3306) {
    $holder = Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue |
              Select-Object -First 1
    $proc   = Get-Process -Id $holder.OwningProcess -ErrorAction SilentlyContinue
    $path   = if ($proc) { $proc.Path } else { '' }

    if ($path -like "$XamppRoot*") {
        Ok "XAMPP MariaDB already owns 3306"
        $portOk = $true
    } else {
        Warn "Port 3306 is held by a DIFFERENT MySQL: $path"
        Warn "DVWA's data lives in XAMPP's MariaDB, so this one must be stopped."

        # find a Windows service pointing at that binary
        $svc = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
               Where-Object { $_.PathName -and $_.PathName -like "*$path*" } |
               Select-Object -First 1

        if ($svc) {
            Say "Owning service: $($svc.Name) (state=$($svc.State))" 'DarkGray'
            if (Test-Admin) {
                $r = & net stop $svc.Name 2>&1
                if ($LASTEXITCODE -eq 0) { Ok "Stopped service $($svc.Name)" }
                else { Warn "net stop failed:"; $r | Select-Object -First 3 | ForEach-Object { Warn "  $_" } }
            } else {
                Warn "Needs Administrator to stop the service. Options:"
                Warn "  a) Re-run this script from an ADMIN PowerShell, or"
                Warn "  b) Run manually:  net stop $($svc.Name)"
            }
        } else {
            Warn "No service found; killing PID $($proc.Id) directly"
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }

        # keep it from auto-starting again after reboot
        if ($svc -and (Test-Admin)) {
            try {
                Set-Service -Name $svc.Name -StartupType Manual -ErrorAction Stop
                Ok "Set $($svc.Name) to Manual startup (won't steal the port next boot)"
            } catch { Warn "Could not change startup type of $($svc.Name)" }
        } elseif ($svc) {
            Warn "Also set it to Manual so this stops recurring:"
            Warn "  Set-Service -Name $($svc.Name) -StartupType Manual"
        }

        Start-Sleep -Seconds 3
        # if still busy, kill whatever remains
        if (Test-Port 3306) {
            $still = Get-NetTCPConnection -LocalPort 3306 -State Listen -ErrorAction SilentlyContinue |
                     Select-Object -First 1
            $sp = Get-Process -Id $still.OwningProcess -ErrorAction SilentlyContinue
            if ($sp -and $sp.Path -notlike "$XamppRoot*") {
                Warn "Still busy; forcing kill of PID $($sp.Id)"
                Stop-Process -Id $sp.Id -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }
        }

        if (Test-Port 3306) { Warn "Port 3306 still busy - MariaDB may fail to start" }
        else { Ok "Port 3306 freed" }
    }
} else {
    Ok "Port 3306 is free"
}

# ---------------------------------------------------------------- 3. MariaDB
Step "3/6 Starting XAMPP MariaDB"
if (Test-Port 3306) {
    Ok "Already listening on 3306"
} else {
    $mArgs = @()
    if (Test-Path $myIni) { $mArgs += "--defaults-file=$myIni" }
    $mArgs += '--standalone'
    Start-Process -FilePath $mysqld -ArgumentList $mArgs `
        -WorkingDirectory (Split-Path $mysqld) -WindowStyle Hidden | Out-Null

    $ready = $false
    for ($i = 0; $i -lt 25; $i++) {
        Start-Sleep -Milliseconds 800
        if (Test-Port 3306) { $ready = $true; break }
    }
    if ($ready) { Ok "MariaDB is up" }
    else { Warn "MariaDB did not open port 3306 - check E:\xampp\mysql\data\*.err" }
}

# confirm the dvwa account really works in THIS server
if (Test-Path $mysqlCli) {
    $probe = & $mysqlCli -u dvwa '-pp@ssw0rd' -e "SELECT 1;" dvwa 2>&1
    if ($LASTEXITCODE -eq 0) {
        Ok "DVWA DB user 'dvwa' logs in successfully"
    } else {
        Warn "Cannot log in as 'dvwa' - wrong MariaDB instance is running"
        $probe | Select-Object -First 2 | ForEach-Object { Warn "  $_" }
        Warn "The data must live in XAMPP's MariaDB (E:\xampp\mysql\data)"
    }
}

# ---------------------------------------------------------------- 4. Apache
Step "4/6 Starting Apache (port 80)"
if (Test-Port 80) {
    Ok "Already listening on 80"
} else {
    Start-Process -FilePath $httpd -WorkingDirectory (Split-Path $httpd) -WindowStyle Hidden | Out-Null

    $ready = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 800
        if (Test-Port 80) { $ready = $true; break }
    }
    if ($ready) { Ok "Apache is up" }
    else { Warn "Apache did not open port 80 - check E:\xampp\apache\logs\error.log" }
}

# ---------------------------------------------------------------- 5. HTTP
Step "5/6 Testing DVWA"
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$httpOk = $false
try {
    $r = Invoke-WebRequest -Uri $Url -TimeoutSec 20 -UseBasicParsing
    $httpOk = ($r.StatusCode -eq 200)
    Ok "HTTP $($r.StatusCode) from $Url"
    if ($r.Content -match 'Damn Vulnerable|login|username') { Ok "Page content looks like DVWA" }
} catch {
    Warn "Request failed: $($_.Exception.Message)"
}
$ErrorActionPreference = $prev

# ---------------------------------------------------------------- 6. report
Step "6/6 Result"
Write-Host ""
Write-Host "  ========================================" -ForegroundColor Yellow
if ($httpOk) {
    Write-Host "    Lab is READY" -ForegroundColor Green
    Write-Host ""
    Write-Host "      $Url" -ForegroundColor White
    Write-Host "      login: admin / password" -ForegroundColor Gray
} else {
    Write-Host "    Lab NOT ready - see warnings above" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "    Stop later : .\stop-lab.ps1" -ForegroundColor DarkGray
Write-Host "  ========================================" -ForegroundColor Yellow
Write-Host ""

if ($httpOk -and -not $NoBrowser) {
    Start-Process $Url
    Say "Browser opened."
}

Say "This window can be closed - services keep running." 'DarkGray'
