<#
    DVWA One-Click Deployment Script for Windows
    ---------------------------------------------------------------
    Automates: env detection -> download DVWA -> write config
               -> create DB -> start server -> print the URL

    Usage (normal PowerShell, no admin required):
        .\setup-dvwa.ps1
    Custom install dir:
        .\setup-dvwa.ps1 -Root "E:\dvwa-lab"
    Custom port:
        .\setup-dvwa.ps1 -Port 8090

    ASCII-only source on purpose: avoids codepage issues on
    Windows PowerShell 5.1 with non-UTF8 system locales.
#>

[CmdletBinding()]
param(
    [string]$Root = "E:\dvwa-lab",
    [int]$Port = 8080,
    [string]$MysqlRoot,
    [string]$MysqlRootPassword
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Say  { param([string]$m, [string]$c = 'Cyan')   Write-Host "  $m" -ForegroundColor $c }
function Step { param([string]$m) Write-Host "`n==> $m" -ForegroundColor Green }
function Warn { param([string]$m) Write-Host "  [!] $m" -ForegroundColor Yellow }
function Die  { param([string]$m) Write-Host "  [X] $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Magenta
Write-Host "     DVWA Lab - One-Click Setup" -ForegroundColor Magenta
Write-Host "  ==========================================" -ForegroundColor Magenta

# ------------------------------------------------------------------ 1/7
Step "1/7 Detecting environment"

$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Say "Administrator: $(if ($isAdmin) { 'yes' } else { 'no' })"

# locate PHP
$phpExe = $null
$phpCandidates = @(
    'E:\xampp\php\php.exe',
    'C:\xampp\php\php.exe', 'D:\xampp\php\php.exe', 'F:\xampp\php\php.exe',
    (Join-Path $Root 'php\php.exe')
)
foreach ($c in $phpCandidates) { if (Test-Path $c) { $phpExe = $c; break } }
if (-not $phpExe) {
    $cmd = Get-Command php -ErrorAction SilentlyContinue
    if ($cmd) { $phpExe = $cmd.Source }
}
if ($phpExe) { Say "PHP: $phpExe" } else { Warn "PHP not found (will degrade gracefully)" }

# locate mysql client
$mysqlExe = $null
if ($MysqlRoot) { $mysqlExe = Join-Path $MysqlRoot 'bin\mysql.exe' }
if (-not $mysqlExe -or -not (Test-Path $mysqlExe)) {
    $mysqlExe = $null
    $mysqlCandidates = @(
        'E:\xampp\mysql\bin\mysql.exe',
        'C:\xampp\mysql\bin\mysql.exe', 'D:\xampp\mysql\bin\mysql.exe',
        'F:\xampp\mysql\bin\mysql.exe',
        'E:\MySQL\mysql-8.4.9-winx64\bin\mysql.exe'
    )
    foreach ($c in $mysqlCandidates) { if (Test-Path $c) { $mysqlExe = $c; break } }
    if (-not $mysqlExe) {
        $cmd = Get-Command mysql -ErrorAction SilentlyContinue
        if ($cmd) { $mysqlExe = $cmd.Source }
    }
}
if ($mysqlExe) { Say "MySQL client: $mysqlExe" } else { Warn "mysql.exe not found" }

# port availability
while (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    Warn "Port $Port is busy, trying $($Port + 1)"
    $Port++
}
Say "Port $Port is free"

# ------------------------------------------------------------------ 2/7
Step "2/7 Creating directories"
$webRoot = Join-Path $Root 'htdocs'
New-Item -ItemType Directory -Path $webRoot -Force | Out-Null
Say "Web root: $webRoot"

# ------------------------------------------------------------------ 3/7
Step "3/7 Fetching DVWA source"
$dvwaDir = Join-Path $webRoot 'dvwa'

function Test-Dvwa {
    param([string]$d)
    return (Test-Path (Join-Path $d 'index.php')) -and (Test-Path (Join-Path $d 'config'))
}

function Get-DvwaByGit {
    # Reuse an existing checkout instead of re-cloning on every run.
    if (Test-Dvwa $dvwaDir) {
        Say "DVWA already present, skipping download"
        return $true
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
    if (Test-Path $dvwaDir) { Remove-Item $dvwaDir -Recurse -Force }
    Say "Trying git clone ..."
    $env:GIT_TERMINAL_PROMPT = '0'
    # git prints progress to stderr. Under $ErrorActionPreference='Stop' that
    # would be treated as a fatal error and abort the script even on success,
    # so relax the preference locally and judge by the exit code instead.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -c http.sslBackend=openssl clone --depth 1 https://github.com/digininja/DVWA.git $dvwaDir 2>&1 |
            ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        $gitExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($gitExit -ne 0) { Warn "git exited with code $gitExit" }
    return (Test-Dvwa $dvwaDir)
}

function Get-DvwaByZip {
    $mirrors = @(
        'https://ghfast.top/https://github.com/digininja/DVWA/archive/refs/heads/master.zip',
        'https://gh-proxy.com/https://github.com/digininja/DVWA/archive/refs/heads/master.zip',
        'https://ghproxy.net/https://github.com/digininja/DVWA/archive/refs/heads/master.zip',
        'https://github.com/digininja/DVWA/archive/refs/heads/master.zip',
        'https://codeload.github.com/digininja/DVWA/zip/refs/heads/master'
    )
    $zip = Join-Path $env:TEMP 'dvwa-master.zip'
    foreach ($m in $mirrors) {
        try {
            $short = $m.Substring(0, [Math]::Min(58, $m.Length))
            Say "Downloading via $short ..."
            Invoke-WebRequest -Uri $m -OutFile $zip -TimeoutSec 120 -UseBasicParsing
            if ((Get-Item $zip).Length -gt 100KB) {
                $kb = [math]::Round((Get-Item $zip).Length / 1KB)
                Say "Downloaded $kb KB" 'Green'
                $tmp = Join-Path $env:TEMP 'dvwa-extract'
                if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
                Expand-Archive -Path $zip -DestinationPath $tmp -Force
                $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
                if (Test-Path $dvwaDir) { Remove-Item $dvwaDir -Recurse -Force }
                Move-Item $inner.FullName $dvwaDir
                if (Test-Dvwa $dvwaDir) { return $true }
            }
        } catch {
            Warn "failed: $($_.Exception.Message)"
        }
    }
    return $false
}

$got = Get-DvwaByGit
if (-not $got) { Warn "git clone failed, falling back to mirrors"; $got = Get-DvwaByZip }
if (-not $got) {
    Die "Could not download DVWA. Manually download https://github.com/digininja/DVWA/archive/master.zip and extract to $dvwaDir"
}
Say "DVWA source ready: $dvwaDir" 'Green'

# ------------------------------------------------------------------ 4/7
Step "4/7 Writing DVWA config"
$cfgSrc = Join-Path $dvwaDir 'config\config.inc.php.dist'
$cfgDst = Join-Path $dvwaDir 'config\config.inc.php'
if (-not (Test-Path $cfgSrc)) { Die "Config template not found: $cfgSrc" }

$dbUser = 'dvwa'
$dbPass = 'p@ssw0rd'
$dbName = 'dvwa'
$dbHost = '127.0.0.1'
$dbPort = 3306

$cfg = Get-Content $cfgSrc -Raw

# The shipped template uses this shape:
#     $_DVWA[ 'db_server' ]   = getenv('DB_SERVER') ?: '127.0.0.1';
# so each replacement must swallow the whole right-hand side, not just a
# literal string. Spacing inside the brackets varies, hence \s*.
#
# Rewriting is done with [regex]::Replace and a MatchEvaluator delegate,
# which returns the replacement text LITERALLY. Two traps this avoids:
#   1. A double-quoted -replace PATTERN would let PowerShell expand $?
#      (last-command status) into True/False and corrupt the regex.
#   2. A -replace REPLACEMENT string interprets "$" specially, so a literal
#      "$_DVWA" means "the whole match" and the substitution recurses until
#      the process runs out of memory.
function Set-DvwaLiteral {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Value
    )
    # Every literal "$" below comes from a SINGLE-quoted here-string, so
    # PowerShell never gets a chance to expand $? or $_. Building the regex
    # by concatenation keeps the two halves readable.
    $prefix = @'
(?m)^[ \t]*\$?_DVWA\[[ \t]*'
'@
    $suffix = @'
'[ \t]*\][^\r\n;]*;
'@
    $pattern = $prefix.Trim() + [regex]::Escape($Key) + $suffix.Trim()

    $replacement = '$_DVWA[ ' + "'" + $Key + "'" + ' ] = ' + "'" + $Value + "'" + ';'
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $replacement }
    return [regex]::Replace($Text, $pattern, $evaluator)
}

$cfg = Set-DvwaLiteral -Text $cfg -Key 'db_server'   -Value $dbHost
$cfg = Set-DvwaLiteral -Text $cfg -Key 'db_port'     -Value $dbPort
$cfg = Set-DvwaLiteral -Text $cfg -Key 'db_user'     -Value $dbUser
$cfg = Set-DvwaLiteral -Text $cfg -Key 'db_password' -Value $dbPass
$cfg = Set-DvwaLiteral -Text $cfg -Key 'db_database' -Value $dbName
$cfg = Set-DvwaLiteral -Text $cfg -Key 'default_security_level' -Value 'low'

Set-Content -Path $cfgDst -Value $cfg -Encoding UTF8

# fail loudly instead of silently shipping a bad config
foreach ($probe in @(
    "= '$dbHost'", "= '$dbPort'", "= '$dbUser'", "= '$dbPass'", "= '$dbName'"
)) {
    if ($cfg -notmatch [regex]::Escape($probe)) { Die "Config rewrite failed (missing $probe)" }
}
if ($cfg -notmatch "'low'") { Die "Config rewrite failed (security level not set)" }
Say "Wrote: $cfgDst" 'Green'
Say "DB target: $dbUser@$dbHost`:$dbPort/$dbName"

# ------------------------------------------------------------------ 5/7
Step "5/7 Initializing database"
if (-not $mysqlExe) {
    Warn "mysql.exe not found - skipping DB creation."
    Warn "Create it manually in phpMyAdmin (see README)."
} else {
    if (-not $MysqlRootPassword) {
        $sec = Read-Host "  MySQL root password (blank if none)" -AsSecureString
        $MysqlRootPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }

    # MySQL 8.4 removed mysql_native_password by default, while older PHP
    # builds only speak that plugin. Try caching_sha2_password first (native
    # on PHP 7.4+/8.x), then fall back. Each statement is issued on its own so
    # a missing plugin on one variant does not abort the other.
    # Build the user from scratch rather than CREATE IF NOT EXISTS + ALTER.
    # On some MariaDB builds the IF NOT EXISTS path silently skips creation and
    # a following ALTER leaves the account with an EMPTY password hash, which
    # then rejects every login. DROP + CREATE is deterministic.
    # MariaDB's root is unix_socket-authenticated, so no plugin clause is used
    # here; caching_sha2_password / mysql_native_password variants are only
    # needed for MySQL 8.x, which is selected below.
    $baseSql = @(
        "DROP USER IF EXISTS '$dbUser'@'localhost';",
        "DROP USER IF EXISTS '$dbUser'@'127.0.0.1';",
        "FLUSH PRIVILEGES;",
        "CREATE DATABASE IF NOT EXISTS $dbName;",
        "CREATE USER '$dbUser'@'localhost' IDENTIFIED BY '$dbPass';",
        "CREATE USER '$dbUser'@'127.0.0.1' IDENTIFIED BY '$dbPass';",
        "GRANT ALL PRIVILEGES ON $dbName.* TO '$dbUser'@'localhost';",
        "GRANT ALL PRIVILEGES ON $dbName.* TO '$dbUser'@'127.0.0.1';",
        "FLUSH PRIVILEGES;"
    ) -join "`n"

    $mysqlArgs = @('-u', 'root')
    if ($MysqlRootPassword) { $mysqlArgs += "-p$MysqlRootPassword" }
    $mysqlRootArg = @($mysqlArgs)

    $setPassSql = $baseSql
    $altPassSql = $baseSql

    $sqlPath = Join-Path $env:TEMP 'dvwa-init.sql'
    Set-Content -Path $sqlPath -Value ($baseSql + "`n" + $setPassSql) -Encoding ASCII
    $sqlForward = $sqlPath -replace '\\', '/'

    # mysql.exe writes warnings to stderr; do not let that abort the script.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $mysqlExe @mysqlArgs -e "source $sqlForward" 2>&1
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            Warn "caching_sha2_password path failed (exit $code), trying mysql_native_password"
            Set-Content -Path $sqlPath -Value ($baseSql + "`n" + $altPassSql) -Encoding ASCII
            $out = & $mysqlExe @mysqlArgs -e "source $sqlForward" 2>&1
            $code = $LASTEXITCODE
        }

        if ($code -eq 0) {
            Say "Database and user created" 'Green'

            # Verify the login AND assert the password hash is non-empty.
            # A zero-length hash means the account exists but rejects every
            # password - exactly the silent failure this script must catch.
            $verify = & $mysqlExe -u $dbUser "-p$dbPass" -e "SELECT 1;" $dbName 2>&1
            $loginOk = ($LASTEXITCODE -eq 0)

            $hashProbe = & $mysqlExe -u root @mysqlRootArg `
                -e "SELECT LENGTH(authentication_string) FROM mysql.user WHERE User='$dbUser' AND Host='localhost';" 2>&1
            $hashLen = 0
            foreach ($line in @($hashProbe)) {
                $t = "$line".Trim()
                if ($t -match '^\d+$') { $hashLen = [int]$t }
            }

            if ($loginOk) {
                Say "Verified: '$dbUser' can log in to '$dbName'" 'Green'
            } else {
                Warn "User created but LOGIN FAILED."
                if ($verify) { $verify | Select-Object -First 3 | ForEach-Object { Warn $_ } }
            }
            if ($hashLen -eq 0) {
                Warn "Password hash for '$dbUser'@'localhost' is EMPTY - the account will reject all logins."
                Warn "Re-run this script; if it persists, set the password manually:"
                Warn "  ALTER USER '$dbUser'@'localhost' IDENTIFIED BY '$dbPass';"
            } elseif ($hashLen -gt 0) {
                Say "Password hash present (length $hashLen)" 'Green'
            }
        } else {
            Warn "mysql exit code $code"
            if ($out) { $out | Select-Object -First 5 | ForEach-Object { Warn $_ } }
            Warn "If MySQL is not running, start it first, then re-run this script."
        }
    } finally {
        $ErrorActionPreference = $prevEap
    }
    Remove-Item $sqlPath -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------ 6/7
Step "6/7 Starting web server"
$url = '(server not started)'

if (-not $phpExe) {
    Warn "PHP not found - cannot start the built-in server."
    Warn "Options:"
    Warn "  A) Install XAMPP, then copy $dvwaDir into its htdocs and start Apache"
    Warn "  B) Install PHP into $Root\php"
} else {
    $existing = Get-CimInstance Win32_Process -Filter "Name='php.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -like "*$dvwaDir*" }
    if ($existing) {
        Say "PHP server already running (PID $($existing.ProcessId -join ','))"
    } else {
        $outLog = Join-Path $Root 'php-server.log'
        $errLog = Join-Path $Root 'php-server.err.log'
        Start-Process -FilePath $phpExe `
            -ArgumentList @('-S', "0.0.0.0:$Port", '-t', $dvwaDir) `
            -WorkingDirectory $dvwaDir `
            -WindowStyle Hidden `
            -RedirectStandardOutput $outLog `
            -RedirectStandardError  $errLog
        Start-Sleep -Seconds 3
        Say "PHP built-in server started" 'Green'
        Say "Log: $outLog"
    }
    $url = "http://localhost:$Port/setup.php"
}

# ------------------------------------------------------------------ 7/7
Step "7/7 Done"
Write-Host ""
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host "    Open this URL in your browser:" -ForegroundColor Yellow
Write-Host ""
Write-Host "      $url" -ForegroundColor White
Write-Host ""
Write-Host "    Then:" -ForegroundColor Yellow
Write-Host "      1. Scroll to the bottom, click [ Create / Reset Database ]" -ForegroundColor Gray
Write-Host "      2. Log in with  admin / password" -ForegroundColor Gray
Write-Host "      3. Left menu -> DVWA Security -> set Low" -ForegroundColor Gray
Write-Host ""
Write-Host "    Path     : $dvwaDir" -ForegroundColor DarkGray
Write-Host "    Port     : $Port" -ForegroundColor DarkGray
Write-Host "    Login    : admin / password" -ForegroundColor DarkGray
Write-Host "    Database : $dbUser / $dbPass  (db: $dbName)" -ForegroundColor DarkGray
Write-Host "  ==========================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "    Stop server : Get-Process php | Stop-Process" -ForegroundColor DarkGray
Write-Host "    Full reset  : Remove-Item '$Root' -Recurse -Force, then re-run" -ForegroundColor DarkGray
Write-Host ""
