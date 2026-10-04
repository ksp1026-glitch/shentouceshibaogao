# Regression test for the DVWA config rewrite in setup-dvwa.ps1
# Uses the REAL template content from digininja/DVWA master.
# ASCII only, single-quoted regexes (PowerShell would corrupt $? otherwise).

$ErrorActionPreference = 'Continue'
$setup = "F:\DSH\shentouceshibaogao\tools\setup-dvwa.ps1"
$script:fail = 0

function Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Host "  PASS  $Name" -ForegroundColor Green }
    else { Write-Host "  FAIL  $Name  $Detail" -ForegroundColor Red; $script:fail++ }
}

Write-Host "=== 1. Syntax check (PS 5.1 parser) ===" -ForegroundColor Cyan
$errs = $null
[System.Management.Automation.Language.Parser]::ParseFile($setup, [ref]$null, [ref]$errs) | Out-Null
Check 'syntax' (($errs -eq $null) -or ($errs.Count -eq 0)) "errors=$($errs.Count)"
if ($errs -and $errs.Count -gt 0) {
    $errs | Select-Object -First 8 | ForEach-Object { Write-Host "        L$($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor DarkYellow }
    exit 1
}

Write-Host "`n=== 2. No non-ASCII bytes (codepage safety) ===" -ForegroundColor Cyan
$bytes = [System.IO.File]::ReadAllBytes($setup)
$nonAscii = ($bytes | Where-Object { $_ -gt 127 }).Count
Check 'ascii-only' ($nonAscii -eq 0) "nonAscii=$nonAscii"

Write-Host "`n=== 3. Regexes in the script must be single-quoted ===" -ForegroundColor Cyan
$src = Get-Content $setup -Raw
$dqRegex = [regex]::Matches($src, '\-replace\s+"[^"]*\\\$?_DVWA')
Check 'no double-quoted $?_DVWA patterns' ($dqRegex.Count -eq 0) "found=$($dqRegex.Count)"

Write-Host "`n=== 4. Real template input ===" -ForegroundColor Cyan
$real = @'
<?php
$_DVWA = array();
$_DVWA[ 'db_server' ]   = getenv('DB_SERVER') ?: '127.0.0.1';
$_DVWA[ 'db_database' ] = getenv('DB_DATABASE') ?: 'dvwa';
$_DVWA[ 'db_user' ]     = getenv('DB_USER') ?: 'dvwa';
$_DVWA[ 'db_password' ] = getenv('DB_PASSWORD') ?: 'p@ssw0rd';
$_DVWA[ 'db_port']      = getenv('DB_PORT') ?: '3306';
$_DVWA[ 'recaptcha_public_key' ]  = getenv('RECAPTCHA_PUBLIC_KEY') ?: '';
$_DVWA[ 'default_security_level' ] = getenv('DEFAULT_SECURITY_LEVEL') ?: 'impossible';
$_DVWA[ 'default_locale' ] = getenv('DEFAULT_LOCALE') ?: 'en';
$_DVWA[ 'disable_authentication' ] = getenv('DISABLE_AUTHENTICATION') ?: false;
$_DVWA['SQLI_DB'] = getenv('SQLI_DB') ?: MYSQL;
'@

$dbUser = 'dvwa'; $dbPass = 'p@ssw0rd'; $dbName = 'dvwa'; $dbHost = '127.0.0.1'; $dbPort = 3306
$cfg = $real

Write-Host "`n=== 5. Apply the script's exact replacement block ===" -ForegroundColor Cyan
$cfg = $cfg -replace '(?m)^\s*\$?_DVWA\[\s*''db_server''\s*\][^\r\n;]*;',              "`$_DVWA[ 'db_server' ]   = '$dbHost';"
$cfg = $cfg -replace '(?m)^\s*\$?_DVWA\[\s*''db_port''\s*\][^\r\n;]*;',                "`$_DVWA[ 'db_port' ]     = '$dbPort';"
$cfg = $cfg -replace '(?m)^\s*\$?_DVWA\[\s*''db_user''\s*\][^\r\n;]*;',                "`$_DVWA[ 'db_user' ]     = '$dbUser';"
$cfg = $cfg -replace '(?m)^\s*\$?_DVWA\[\s*''db_password''\s*\][^\r\n;]*;',            "`$_DVWA[ 'db_password' ] = '$dbPass';"
$cfg = $cfg -replace '(?m)^\s*\$?_DVWA\[\s*''db_database''\s*\][^\r\n;]*;',            "`$_DVWA[ 'db_database' ] = '$dbName';"
$cfg = $cfg -replace '(?m)^\s*\$?_DVWA\[\s*''default_security_level''\s*\][^\r\n;]*;', "`$_DVWA[ 'default_security_level' ] = 'low';"
Write-Host $cfg

Write-Host "`n=== 6. Rewritten values ===" -ForegroundColor Cyan
Check 'db_server'   $cfg.Contains("`$_DVWA[ 'db_server' ]   = '127.0.0.1';")
Check 'db_port'     $cfg.Contains("`$_DVWA[ 'db_port' ]     = '3306';")
Check 'db_user'     $cfg.Contains("`$_DVWA[ 'db_user' ]     = 'dvwa';")
Check 'db_password' $cfg.Contains("`$_DVWA[ 'db_password' ] = 'p@ssw0rd';")
Check 'db_database' $cfg.Contains("`$_DVWA[ 'db_database' ] = 'dvwa';")
Check 'security'    $cfg.Contains("`$_DVWA[ 'default_security_level' ] = 'low';")

Write-Host "`n=== 7. Unrelated lines preserved ===" -ForegroundColor Cyan
foreach ($keep in @('recaptcha_public_key', 'default_locale', 'disable_authentication', 'SQLI_DB')) {
    Check "preserved:$keep" ($cfg -match $keep)
}

Write-Host "`n=== 8. No leftover getenv on DB lines ===" -ForegroundColor Cyan
$dbLines = @(($cfg -split "`n") | Where-Object { $_ -match 'db_(server|user|password|database|port)' })
$stillEnv = @($dbLines | Where-Object { $_ -match 'getenv' })
Check 'db lines static' ($stillEnv.Count -eq 0) "remaining=$($stillEnv.Count)"
if ($stillEnv.Count -gt 0) { $stillEnv | ForEach-Object { Write-Host "        $_" -ForegroundColor DarkYellow } }

Write-Host "`n=== 9. Guard assertions exist in the script ===" -ForegroundColor Cyan
Check 'has post-rewrite guard' ($src -match 'Config rewrite failed')

Write-Host ""
if ($script:fail -eq 0) { Write-Host "ALL CHECKS PASSED" -ForegroundColor Green; exit 0 }
Write-Host "$($script:fail) CHECK(S) FAILED" -ForegroundColor Red
exit 1
