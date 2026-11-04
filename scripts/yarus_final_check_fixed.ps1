# YARUS final verification script for Windows PowerShell 5.1+ (fixed DB check)
# Run this file from the project root (the folder containing Gemfile and bin\rails).
# The PostgreSQL password is requested securely and is not written into the report.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\Gemfile") -or -not (Test-Path ".\bin\rails")) {
    Write-Host "ERROR: Run this script from the Yarus project root (Gemfile and bin\rails must exist)." -ForegroundColor Red
    exit 1
}

$reportDir = Join-Path (Get-Location) "reports"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $reportDir "yarus-final-check-$stamp.txt"
$script:CheckResults = @()

Start-Transcript -Path $reportPath -Force | Out-Null

function Invoke-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Write-Host ""
    Write-Host ("--- {0} ---" -f $Name) -ForegroundColor Cyan
    try {
        & $Executable @Arguments
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        $code = 1
    }

    if ($code -eq 0) {
        Write-Host ("PASS: {0}" -f $Name) -ForegroundColor Green
        $script:CheckResults += [PSCustomObject]@{ Check = $Name; Result = "PASS" }
    }
    else {
        Write-Host ("FAIL (exit {0}): {1}" -f $code, $Name) -ForegroundColor Red
        $script:CheckResults += [PSCustomObject]@{ Check = $Name; Result = "FAIL" }
    }
}

$envNames = @("YARUS_DB_PASSWORD", "YARUS_DB_HOST", "YARUS_DB_USERNAME", "RAILS_ENV")
$oldEnv = @{}
foreach ($name in $envNames) {
    $oldEnv[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}
$ptr = [IntPtr]::Zero

try {
    Write-Host "YARUS FINAL CHECK" -ForegroundColor Yellow
    Write-Host ("Project: {0}" -f (Get-Location).Path)
    Write-Host ("Date: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
    Write-Host "PostgreSQL password is entered securely; it is not printed."

    $secure = Read-Host "PostgreSQL password for user postgres" -AsSecureString
    if ($secure.Length -eq 0) { throw "The PostgreSQL password was empty." }
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $env:YARUS_DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    $env:YARUS_DB_HOST = "127.0.0.1"
    $env:YARUS_DB_USERNAME = "postgres"
    $env:RAILS_ENV = "development"

    Write-Host ""
    Write-Host "Environment versions" -ForegroundColor Cyan
    ruby --version
    bundle --version
    ruby .\bin\rails --version

    Invoke-Check "Bundler dependencies" "bundle" @("check")
    Invoke-Check "PostgreSQL connection (development)" "ruby" @(".\bin\rails", "db:version")
    Invoke-Check "Zeitwerk autoloading" "ruby" @(".\bin\rails", "zeitwerk:check")
    Invoke-Check "Development migration status" "ruby" @(".\bin\rails", "db:migrate:status")
    Invoke-Check "Rails routes load" "ruby" @(".\bin\rails", "routes")

    Write-Host ""
    Write-Host "Switching to the test environment. The next step reloads schema in the test database only." -ForegroundColor Yellow
    $env:RAILS_ENV = "test"
    Invoke-Check "Load schema into test database" "ruby" @(".\bin\rails", "db:schema:load")
    Invoke-Check "Automated Minitest suite" "ruby" @(".\bin\rails", "test")

    Write-Host ""
    Write-Host "Optional browser smoke test" -ForegroundColor Cyan
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:3000/" -UseBasicParsing -TimeoutSec 3
        if ($response.StatusCode -eq 200) {
            Write-Host "PASS: GET / returned HTTP 200." -ForegroundColor Green
            $script:CheckResults += [PSCustomObject]@{ Check = "Browser GET / (server already running)"; Result = "PASS" }
        }
        else {
            Write-Host ("FAIL: GET / returned HTTP {0}." -f $response.StatusCode) -ForegroundColor Red
            $script:CheckResults += [PSCustomObject]@{ Check = "Browser GET / (server already running)"; Result = "FAIL" }
        }
    }
    catch {
        Write-Host "SKIP: No Rails server responded at http://127.0.0.1:3000. This does not affect the automated test result." -ForegroundColor Yellow
        $script:CheckResults += [PSCustomObject]@{ Check = "Browser GET / (server already running)"; Result = "SKIP" }
    }
}
catch {
    Write-Host ("SCRIPT ERROR: {0}" -f $_.Exception.Message) -ForegroundColor Red
    $script:CheckResults += [PSCustomObject]@{ Check = "Script execution"; Result = "FAIL" }
}
finally {
    foreach ($name in $envNames) {
        if ($null -eq $oldEnv[$name]) {
            Remove-Item ("Env:{0}" -f $name) -ErrorAction SilentlyContinue
        }
        else {
            Set-Item ("Env:{0}" -f $name) $oldEnv[$name]
        }
    }
    if ($ptr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

Write-Host ""
Write-Host "FINAL SUMMARY" -ForegroundColor Yellow
$script:CheckResults | Format-Table -AutoSize
$passed = @($script:CheckResults | Where-Object { $_.Result -eq "PASS" }).Count
$failed = @($script:CheckResults | Where-Object { $_.Result -eq "FAIL" }).Count
$skipped = @($script:CheckResults | Where-Object { $_.Result -eq "SKIP" }).Count
Write-Host ("Passed: {0}; Failed: {1}; Skipped: {2}" -f $passed, $failed, $skipped)
Write-Host ("Report: {0}" -f $reportPath)

Stop-Transcript | Out-Null

if ($failed -gt 0) { exit 1 } else { exit 0 }
