[CmdletBinding()]
param()

# ASCII-only PowerShell 5.1 script. Run from any directory; project root is derived from this file.
$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Results = New-Object System.Collections.Generic.List[object]
$OriginalEnvironment = @{}
$PasswordWasPrompted = $false
$OriginalBundlerVersion = $env:BUNDLER_VERSION
$OriginalRailsEnv = $env:RAILS_ENV
$OriginalBundleGemfile = $env:BUNDLE_GEMFILE

function Add-Result {
    param(
        [string]$Name,
        [ValidateSet('PASS', 'FAIL', 'SKIP')][string]$Status,
        [string]$Details = ''
    )
    $Results.Add([pscustomobject]@{ Name = $Name; Status = $Status; Details = $Details }) | Out-Null
    $color = switch ($Status) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        default { 'Yellow' }
    }
    Write-Host ("[{0}] {1} {2}" -f $Status, $Name, $Details) -ForegroundColor $color
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    & $Executable @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw ("Exit code {0}: {1} {2}" -f $code, $Executable, ($Arguments -join ' '))
    }
}

function Invoke-Task {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action | Out-Host
        Add-Result -Name $Name -Status 'PASS'
        return $true
    }
    catch {
        Add-Result -Name $Name -Status 'FAIL' -Details $_.Exception.Message
        return $false
    }
}

function Set-TemporaryProcessEnvironment {
    param([string]$Name, [AllowNull()][string]$Value)
    if (-not $OriginalEnvironment.ContainsKey($Name)) {
        $OriginalEnvironment[$Name] = [Environment]::GetEnvironmentVariable($Name, 'Process')
    }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
}

function Import-LocalEnvironment {
    $envFile = Join-Path $ProjectRoot '.env'
    if (-not (Test-Path $envFile)) { return }
    foreach ($line in Get-Content -LiteralPath $envFile) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
            $name = $Matches[1]
            $value = $Matches[2]
            if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $current = [Environment]::GetEnvironmentVariable($name, 'Process')
            if ($null -eq $current) { Set-TemporaryProcessEnvironment -Name $name -Value $value }
        }
    }
}

function Ensure-DatabasePassword {
    if (-not [string]::IsNullOrEmpty($env:YARUS_DB_PASSWORD) -or -not [string]::IsNullOrEmpty($env:PGPASSWORD)) { return }
    Write-Host ''
    Write-Host 'PostgreSQL password was not found in YARUS_DB_PASSWORD or PGPASSWORD.' -ForegroundColor Yellow
    $secure = Read-Host 'Enter the password for PostgreSQL user (input is hidden; Enter for no password)' -AsSecureString
    if ($secure.Length -eq 0) { $secure.Dispose(); return }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        Set-TemporaryProcessEnvironment -Name 'YARUS_DB_PASSWORD' -Value $plain
        $script:PasswordWasPrompted = $true
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $secure.Dispose()
    }
}

function New-TemporaryRubyScript {
    param([string]$Prefix, [string]$Source)
    $path = Join-Path $env:TEMP ("{0}_{1}.rb" -f $Prefix, $PID)
    # Ruby source is ASCII-only, avoiding PowerShell 5.1 encoding ambiguity.
    [System.IO.File]::WriteAllText($path, $Source, [System.Text.Encoding]::ASCII)
    return $path
}

function Invoke-RailsCommand {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    Invoke-NativeCommand -Executable 'ruby' -Arguments (@('.\bin\rails') + $Arguments)
}

$prerequisitesPassed = $true
$bundleCommand = $null
$dbConnectionPassed = $false

try {
    Push-Location $ProjectRoot
    Set-TemporaryProcessEnvironment -Name 'BUNDLE_GEMFILE' -Value (Join-Path $ProjectRoot 'Gemfile')
    Write-Host 'Yarus backend verification' -ForegroundColor Cyan
    Write-Host ("Project: {0}" -f $ProjectRoot)
    Write-Host ''

    if (-not (Test-Path 'Gemfile') -or -not (Test-Path 'Gemfile.lock') -or -not (Test-Path 'Rakefile') -or -not (Test-Path 'config\application.rb')) {
        throw 'Project files are missing. Run this script from the scripts folder inside the project archive.'
    }

    $gemfile = Get-Content -LiteralPath 'Gemfile' -Raw
    $dockerfile = Get-Content -LiteralPath 'Dockerfile' -Raw
    $rubyVersionFile = (Get-Content -LiteralPath '.ruby-version' -Raw).Trim()
    $pinsOk = (
        $gemfile -match '(?m)^ruby "4\.0\.9"$' -and
        $gemfile -match '(?m)^gem "rails", "~> 8\.1\.4"$' -and
        $gemfile -match '(?m)^gem "pg", "~> 1\.7"$' -and
        $rubyVersionFile -eq 'ruby-4.0.9' -and
        $dockerfile -match '(?m)^ARG RUBY_VERSION=4\.0\.9$' -and
        $dockerfile -match 'RUBYGEMS_VERSION="4\.0\.20"' -and
        $dockerfile -match 'BUNDLER_VERSION="4\.0\.20"'
    )
    if ($pinsOk) { Add-Result 'Project version settings' 'PASS' 'Gemfile, .ruby-version and Dockerfile agree.' }
    else { Add-Result 'Project version settings' 'FAIL' 'Check Ruby 4.0.9, Rails 8.1.4, pg 1.7 and Dockerfile.'; $prerequisitesPassed = $false }

    $rubyOut = (& ruby -e 'print RUBY_VERSION' 2>&1 | Out-String).Trim()
    $rubyCode = $LASTEXITCODE
    if ($rubyCode -ne 0 -or $rubyOut -ne '4.0.9') { Add-Result 'Ruby 4.0.9' 'FAIL' ("Detected: {0}" -f $rubyOut); $prerequisitesPassed = $false }
    else { Add-Result 'Ruby 4.0.9' 'PASS' $rubyOut }

    $gemOut = (& gem -v 2>&1 | Out-String).Trim()
    $gemCode = $LASTEXITCODE
    if ($gemCode -ne 0 -or $gemOut -ne '4.0.20') { Add-Result 'RubyGems 4.0.20' 'FAIL' ("Detected: {0}" -f $gemOut); $prerequisitesPassed = $false }
    else { Add-Result 'RubyGems 4.0.20' 'PASS' $gemOut }

    if ($prerequisitesPassed) {
        Set-TemporaryProcessEnvironment -Name 'BUNDLER_VERSION' -Value '4.0.20'
        $bundleCommand = Get-Command bundle -ErrorAction SilentlyContinue
        if ($null -eq $bundleCommand) { throw 'Bundler command was not found in PATH.' }
        $bundleExe = $bundleCommand.Source
        $bundleOut = (& $bundleExe '_4.0.20_' '--version' 2>&1 | Out-String).Trim()
        $bundleCode = $LASTEXITCODE
        if ($bundleCode -ne 0 -or $bundleOut -notmatch '4\.0\.20') { throw ("Bundler 4.0.20 is unavailable: {0}" -f $bundleOut) }
        Add-Result 'Bundler 4.0.20' 'PASS' $bundleOut

        $bundleInstallOk = Invoke-Task 'Install and resolve dependencies' {
            $marker = Join-Path $PSScriptRoot '.refresh-lockfile-on-first-run'
            if (Test-Path $marker) {
                Invoke-NativeCommand -Executable $bundleExe -Arguments @('_4.0.20_', 'update')
                Remove-Item -LiteralPath $marker -Force
            }
            else { Invoke-NativeCommand -Executable $bundleExe -Arguments @('_4.0.20_', 'install') }
        }

        if ($bundleInstallOk) {
            $lock = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot 'Gemfile.lock')) -replace "`r", ''
            $lockChecks = @(
                @{ Name = 'Gemfile.lock Rails 8.1.4'; Pattern = '(?m)^    rails \(8\.1\.4\)$'; Message = 'Rails 8.1.4 not found in lockfile.' },
                @{ Name = 'Gemfile.lock pg Windows UCRT 1.7.0'; Pattern = '(?m)^    pg \(1\.7\.0-x64-mingw-ucrt\)$'; Message = 'Windows UCRT pg 1.7.0 not found in lockfile.' },
                @{ Name = 'Gemfile.lock Ruby 4.0.9'; Pattern = '(?m)^RUBY VERSION\n[ \t]+ruby 4\.0\.9p[0-9]+[ \t]*$'; Message = 'RUBY VERSION section does not contain Ruby 4.0.9.' },
                @{ Name = 'Gemfile.lock Bundler 4.0.20'; Pattern = '(?m)^BUNDLED WITH\n[ \t]+4\.0\.20[ \t]*$'; Message = 'BUNDLED WITH section does not contain Bundler 4.0.20.' }
            )
            foreach ($check in $lockChecks) {
                if ($lock -match $check.Pattern) { Add-Result $check.Name 'PASS' }
                else { Add-Result $check.Name 'FAIL' $check.Message; $bundleInstallOk = $false }
            }
        }

        if ($bundleInstallOk) {
            $bundleCheckOk = Invoke-Task 'Bundler dependency check' {
                Invoke-NativeCommand -Executable $bundleExe -Arguments @('_4.0.20_', 'check')
            }

            $railsLoadOk = Invoke-Task 'Load Rails and verify version' {
                $rubySource = @'
require "bundler/setup"
require "rails"
puts Rails.version
'@
                $temp = New-TemporaryRubyScript 'yarus_rails_version' $rubySource
                try {
                    $output = @(& ruby $temp 2>&1)
                    $code = $LASTEXITCODE
                    $text = ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
                    if ($code -ne 0) { throw $text }
                    $found = $output | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ -eq '8.1.4' } | Select-Object -Last 1
                    if ($found -ne '8.1.4') { throw ("Expected Rails 8.1.4. Output: {0}" -f $text) }
                    Write-Host ("Rails {0}" -f $found)
                }
                finally { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
            }

            $zeitwerkOk = Invoke-Task 'Zeitwerk check' {
                Invoke-RailsCommand @('zeitwerk:check')
            }

            Import-LocalEnvironment
            Ensure-DatabasePassword

            $dbConnectionPassed = Invoke-Task 'PostgreSQL connection' {
                $rubySource = @'
require "bundler/setup"
require "pg"
username = ENV["YARUS_DB_USERNAME"]
username = ENV.fetch("PGUSER", "postgres") if username.nil? || username.empty?
password = ENV["YARUS_DB_PASSWORD"]
password = ENV["PGPASSWORD"] if password.nil? || password.empty?
connection = PG.connect(
  host: ENV.fetch("YARUS_DB_HOST", "localhost"),
  port: ENV.fetch("YARUS_DB_PORT", "5432"),
  user: username,
  password: password,
  dbname: ENV.fetch("YARUS_DB_MAINTENANCE_DATABASE", "postgres")
)
server_version = connection.exec("SELECT version()").getvalue(0, 0)
puts server_version
unless server_version.match?(/^PostgreSQL 18\.6(?:\D|$)/)
  abort("Expected PostgreSQL 18.6, found: #{server_version}")
end
connection.close
'@
                $temp = New-TemporaryRubyScript 'yarus_postgres_check' $rubySource
                try { Invoke-NativeCommand -Executable 'ruby' -Arguments @($temp) }
                finally { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
            }

            if ($dbConnectionPassed) {
                $devOk = Invoke-Task 'Development database prepare and migrations' { Invoke-RailsCommand @('db:prepare') }
                if ($devOk) { Invoke-Task 'Development migration status' { Invoke-RailsCommand @('db:migrate:status') } | Out-Null }
                else { Add-Result 'Development migration status' 'SKIP' 'Development db:prepare failed.' }

                $oldRailsEnv = $env:RAILS_ENV
                try {
                    Set-TemporaryProcessEnvironment -Name 'RAILS_ENV' -Value 'test'
                    $testOk = Invoke-Task 'Test database prepare and migrations' { Invoke-RailsCommand @('db:prepare') }
                    if ($testOk) { Invoke-Task 'Minitest suite' { Invoke-RailsCommand @('test') } | Out-Null }
                    else { Add-Result 'Minitest suite' 'SKIP' 'Test database was not prepared.' }
                }
                finally { Set-TemporaryProcessEnvironment -Name 'RAILS_ENV' -Value $oldRailsEnv }
            }
            else {
                Add-Result 'Development database prepare and migrations' 'SKIP' 'No PostgreSQL connection.'
                Add-Result 'Development migration status' 'SKIP' 'No PostgreSQL connection.'
                Add-Result 'Test database prepare and migrations' 'SKIP' 'No PostgreSQL connection.'
                Add-Result 'Minitest suite' 'SKIP' 'No PostgreSQL connection.'
            }
        }
        else {
            Add-Result 'Bundler dependency check' 'SKIP' 'Lockfile checks failed.'
            Add-Result 'Load Rails and verify version' 'SKIP'
            Add-Result 'Zeitwerk check' 'SKIP'
            Add-Result 'PostgreSQL connection' 'SKIP'
            Add-Result 'Development database prepare and migrations' 'SKIP'
            Add-Result 'Development migration status' 'SKIP'
            Add-Result 'Test database prepare and migrations' 'SKIP'
            Add-Result 'Minitest suite' 'SKIP'
        }
    }
    else {
        Add-Result 'Bundler and following checks' 'SKIP' 'Ruby or RubyGems version check failed.'
    }
}
catch {
    Add-Result 'Verification script error' 'FAIL' $_.Exception.Message
}
finally {
    foreach ($name in $OriginalEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $OriginalEnvironment[$name], 'Process')
    }
    if ($OriginalEnvironment.ContainsKey('BUNDLER_VERSION')) { $env:BUNDLER_VERSION = $OriginalBundlerVersion }
    if ($OriginalEnvironment.ContainsKey('RAILS_ENV')) { $env:RAILS_ENV = $OriginalRailsEnv }
    if ($OriginalEnvironment.ContainsKey('BUNDLE_GEMFILE')) { $env:BUNDLE_GEMFILE = $OriginalBundleGemfile }
    Pop-Location -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'YARUS BACKEND VERIFICATION SUMMARY' -ForegroundColor Cyan
$passed = @($Results | Where-Object { $_.Status -eq 'PASS' }).Count
$failed = @($Results | Where-Object { $_.Status -eq 'FAIL' }).Count
$skipped = @($Results | Where-Object { $_.Status -eq 'SKIP' }).Count
Write-Host ("Passed: {0} | Failed: {1} | Skipped: {2}" -f $passed, $failed, $skipped)
$Results | Format-Table -AutoSize
if ($failed -gt 0) { exit 1 }
exit 0
