<#
    Deploy DVWA into XAMPP's htdocs and enable the GD extension.
    Run this in a normal PowerShell window (Admin recommended).

    Usage:
        powershell -ExecutionPolicy Bypass -File .\deploy-to-apache.ps1
    Custom paths:
        powershell -ExecutionPolicy Bypass -File .\deploy-to-apache.ps1 -Source "E:\dvwa-lab\htdocs\dvwa" -Htdocs "E:\xampp\htdocs"
#>

[CmdletBinding()]
param(
    [string]$Source = 'E:\dvwa-lab\htdocs\dvwa',
    [string]$Htdocs = 'E:\xampp\htdocs',
    [string]$PhpIni = 'E:\xampp\php\php.ini'
)

$ErrorActionPreference = 'Stop'

function Say  { param([string]$m, [string]$c = 'Cyan')    Write-Host "  $m" -ForegroundColor $c }
function Step { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Green }
function Warn { param([string]$m) Write-Host "  [!] $m" -ForegroundColor Yellow }
function Die  { param([string]$m) Write-Host "  [X] $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host "     Deploy DVWA to XAMPP Apache" -ForegroundColor Magenta
Write-Host "  ==========================================" -ForegroundColor Magenta

# ------------------------------------------------------------------ 1/5
Step "1/5 Checking source"
if (-not (Test-Path (Join-Path $Source 'index.php'))) {
    Die "DVWA not found at $Source (index.php missing)."
}
if (-not (Test-Path (Join-Path $Source 'config\config.inc.php'))) {
    Die "config.inc.php missing - the setup script did not finish writing it."
}
$srcCount = (Get-ChildItem $Source -Recurse -File -ErrorAction SilentlyContinue).Count
Say "Source OK: $srcCount files" 'Green'

# ------------------------------------------------------------------ 2/5
Step "2/5 Enabling GD extension"
if (-not (Test-Path $PhpIni)) {
    Warn "php.ini not found at $PhpIni - skipping GD"
} else {
    $ini = Get-Content $PhpIni -Raw
    if ($ini -match '(?m)^\s*extension\s*=\s*gd\s*$') {
        Say "GD already enabled" 'Green'
    } else {
        $new = $ini -replace '(?m)^\s*;\s*extension\s*=\s*gd\s*$', 'extension=gd'
        if ($new -eq $ini) {
            Warn "Could not find a ';extension=gd' line to uncomment - edit php.ini manually"
        } else {
            $backup = "$PhpIni.bak"
            if (-not (Test-Path $backup)) {
                Copy-Item $PhpIni $backup -Force
                Say "Backed up original to $backup"
            }
            Set-Content -Path $PhpIni -Value $new -Encoding ASCII -NoNewline
            # re-read to confirm the write actually landed
            $check = Get-Content $PhpIni -Raw
            if ($check -match '(?m)^\s*extension\s*=\s*gd\s*$') {
                Say "GD enabled and verified" 'Green'
            } else {
                Die "Wrote php.ini but GD still not enabled - check file permissions"
            }
        }
    }
}

# ------------------------------------------------------------------ 3/5
Step "3/5 Copying DVWA into htdocs"
$dest = Join-Path $Htdocs 'dvwa'
if (-not (Test-Path $Htdocs)) { Die "htdocs not found: $Htdocs" }

if (Test-Path $dest) {
    Say "Removing previous copy at $dest"
    Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
}

try {
    Copy-Item -Path $Source -Destination $dest -Recurse -Force -ErrorAction Stop
} catch {
    Die "Copy failed: $($_.Exception.Message)"
}

$dstCount = (Get-ChildItem $dest -Recurse -File -ErrorAction SilentlyContinue).Count
if ($dstCount -lt ($srcCount * 0.9)) {
    Die "Copy incomplete: only $dstCount of $srcCount files landed"
}
Say "Copied $dstCount files to $dest" 'Green'

# ------------------------------------------------------------------ 4/5
Step "4/5 Verifying deployment"
$required = @('index.php', 'setup.php', 'login.php', 'config\config.inc.php',
              'dvwa\includes\DBMS\MySQL.php', 'hackable\uploads')
$bad = 0
foreach ($f in $required) {
    if (Test-Path (Join-Path $dest $f)) {
        Say "  ok   $f" 'Green'
    } else {
        Say "  MISS $f" 'Red'
        $bad++
    }
}
if ($bad -gt 0) { Die "$bad required item(s) missing" }

# uploads must be writable by the web server
$up = Join-Path $dest 'hackable\uploads'
try {
    $probe = Join-Path $up '_wtest.tmp'
    Set-Content -Path $probe -Value 'x' -ErrorAction Stop
    Remove-Item $probe -Force
    Say "uploads directory is writable" 'Green'
} catch {
    Warn "uploads not writable - the File Upload lab will fail: $($_.Exception.Message)"
}

# ------------------------------------------------------------------ 5/5
Step "5/5 Done"
Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host "    Next steps" -ForegroundColor Yellow
Write-Host ""
Write-Host "    1. Open XAMPP Control Panel" -ForegroundColor Gray
Write-Host "    2. Click Start on BOTH Apache and MySQL" -ForegroundColor Gray
Write-Host "    3. Open this URL:" -ForegroundColor Gray
Write-Host ""
Write-Host "         http://localhost/dvwa/setup.php" -ForegroundColor White
Write-Host ""
Write-Host "    4. Scroll to the bottom, click [ Create / Reset Database ]" -ForegroundColor Gray
Write-Host "    5. Log in with  admin / password" -ForegroundColor Gray
Write-Host "    6. Left menu -> DVWA Security -> set Low" -ForegroundColor Gray
Write-Host ""
Write-Host "    Deployed to : $dest" -ForegroundColor DarkGray
Write-Host "    DB          : dvwa / p@ssw0rd  (db: dvwa, port 3306)" -ForegroundColor DarkGray
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host ""
