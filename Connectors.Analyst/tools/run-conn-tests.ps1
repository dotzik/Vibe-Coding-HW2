#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Build + smoke spuštění zadaného connectoru s klasifikací výstupu.

.DESCRIPTION
    1. Resolve adresáře connectoru v $PROJECT_ROOT/Connectors/ (glob, fuzzy match).
    2. `dotnet build` connectorové .sln (Release).
    3. Smoke run spustitelného projektu s `--once` (nebo -SmokeArgs override).
    4. Parse výstupu: počty INFO/WARN/ERROR/FATAL, klasifikace GREEN/YELLOW/RED.
    5. Append záznamu do state/snapshots-log.md.

    Plně autonomní skript — žádná AI orchestrace. Nahrazuje skill /run-conn-tests.
    Bez DB / Jira writes; jen lokální append do snapshots-log.md.

.PARAMETER Connector
    Zkratka connectoru (např. ARES, SK.NespolehlivyPlatce). Resolve přes glob.

.PARAMETER Environment
    Dev | Test | Local — mapuje na ASPNETCORE_ENVIRONMENT / DOTNET_ENVIRONMENT. Default Dev.

.PARAMETER Configuration
    Debug | Release. Default Release (CI-like ověření).

.PARAMETER Project
    Explicitní .csproj pro smoke run (cesta absolutní nebo relativní ke connectoru).
    Nutné u connectorů s více spustitelnými projekty (např. ARES Downloadery).

.PARAMETER SmokeArgs
    Argumenty pro smoke run za `--`. Default "--once".

.PARAMETER NoRun
    Jen build, žádný smoke run.

.EXAMPLE
    pwsh tools/run-conn-tests.ps1 -Connector SbirkaListin_Archiv
.EXAMPLE
    pwsh tools/run-conn-tests.ps1 -Connector ARES -Project Connector.Ares.API.Downloader.EkonomickeSubjekty
.EXAMPLE
    pwsh tools/run-conn-tests.ps1 -Connector ARES -NoRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Connector,
    [ValidateSet('Dev', 'Test', 'Local')][string]$Environment = 'Dev',
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [string]$Project,
    [string]$SmokeArgs = '--once',
    [switch]$NoRun,
    [int]$BuildTimeoutSec = 300,
    [int]$RunTimeoutSec = 300
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"

# --------------------------------------------------------------------------
# Pomocné funkce
# --------------------------------------------------------------------------

function Get-LevelCount {
    <# Počet řádků odpovídajících log levelu (Serilog `[ERR]` i textové `ERROR`). #>
    param([string]$Text, [string]$Pattern)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return @([regex]::Matches($Text, $Pattern, 'IgnoreCase, Multiline')).Count
}

function Get-MatchingLines {
    param([string]$Text, [string]$Pattern, [int]$Max = 3)
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    return @($Text -split "`r?`n" | Where-Object { $_ -match $Pattern } | Select-Object -First $Max)
}

# --------------------------------------------------------------------------
# 1. Resolve connectoru a build targetu
# --------------------------------------------------------------------------

$connDir = Resolve-Connector -Name $Connector
Write-Host "Connector:  $($connDir.Name)" -ForegroundColor Cyan

$sln = Resolve-ConnectorSln -ConnectorDir $connDir
if ($sln) {
    $buildTarget = $sln.FullName
    Write-Host "Build:      $($sln.Name)"
}
else {
    $csprojs = @(Get-ChildItem -LiteralPath $connDir.FullName -Recurse -Filter '*.csproj' -File |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' })
    if ($csprojs.Count -ne 1) {
        throw "Connector nemá .sln a obsahuje $($csprojs.Count) projektů — nelze jednoznačně buildovat. " +
              "Přidej .sln nebo uprav skript."
    }
    $buildTarget = $csprojs[0].FullName
    Write-Host "Build:      $($csprojs[0].Name)"
}

# --------------------------------------------------------------------------
# 2. Build
# --------------------------------------------------------------------------

Write-Host "`n--- dotnet build ($Configuration) ---" -ForegroundColor Yellow
$build = Invoke-Capture -FilePath 'dotnet' `
    -Arguments @('build', $buildTarget, '-c', $Configuration, '--nologo', '-v', 'minimal') `
    -TimeoutSec $BuildTimeoutSec `
    -EnvVars @{ MSBUILDTERMINALLOGGER = 'off' }

$buildOut = "$($build.Stdout)`n$($build.Stderr)"
$buildSucceeded = ($build.ExitCode -eq 0) -and (-not $build.TimedOut)

# Počty z MSBuild summary, fallback na počítání řádků.
$warnCount = 0
$errCount = 0
if ($buildOut -match '(?m)^\s*(\d+)\s+Warning\(s\)') { $warnCount = [int]$Matches[1] }
else { $warnCount = Get-LevelCount -Text $buildOut -Pattern '(?m):\s*warning\s' }
if ($buildOut -match '(?m)^\s*(\d+)\s+Error\(s\)') { $errCount = [int]$Matches[1] }
else { $errCount = Get-LevelCount -Text $buildOut -Pattern '(?m):\s*error\s' }

if ($buildSucceeded) {
    Write-Host "Build:      OK (warnings: $warnCount, errors: $errCount)" -ForegroundColor Green
}
else {
    Write-Host "Build:      FAILED (warnings: $warnCount, errors: $errCount)" -ForegroundColor Red
    $errLines = Get-MatchingLines -Text $buildOut -Pattern ':\s*error\s' -Max 5
    if ($build.TimedOut) { $errLines = @("Build timeout po ${BuildTimeoutSec}s.") }
    $errLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

# --------------------------------------------------------------------------
# 3. Smoke run
# --------------------------------------------------------------------------

$runStatus = $null      # GREEN / YELLOW / RED  (null = neproveden)
$runExit = $null
$counts = [ordered]@{ INFO = 0; WARN = 0; ERROR = 0; FATAL = 0 }
$topFindings = @()
$smokeCmd = $null

if (-not $buildSucceeded) {
    Write-Host "`nSmoke run:  přeskočen (build FAILED)." -ForegroundColor Red
}
elseif ($NoRun) {
    Write-Host "`nSmoke run:  přeskočen (-NoRun)." -ForegroundColor DarkGray
}
else {
    # Resolve spustitelného projektu.
    $runProj = $null
    if ($Project) {
        $runProj = if ([System.IO.Path]::IsPathRooted($Project)) { $Project }
                   else { Join-Path $connDir.FullName $Project }
        if (-not (Test-Path -LiteralPath $runProj)) {
            throw "-Project '$Project' nenalezen ($runProj)."
        }
        if ((Get-Item -LiteralPath $runProj).PSIsContainer) {
            $runProj = (Get-ChildItem -LiteralPath $runProj -Filter '*.csproj' -File |
                Select-Object -First 1).FullName
        }
    }
    else {
        $runnable = Get-RunnableProjects -ConnectorDir $connDir
        if ($runnable.Count -eq 1) {
            $runProj = $runnable[0].FullName
        }
        elseif ($runnable.Count -eq 0) {
            Write-Host "`nSmoke run:  přeskočen — žádný spustitelný projekt nenalezen." -ForegroundColor Yellow
        }
        else {
            Write-Host "`nSmoke run:  přeskočen — connector má $($runnable.Count) spustitelných projektů." -ForegroundColor Yellow
            Write-Host "  Vyber jeden přes -Project:" -ForegroundColor Yellow
            $runnable | ForEach-Object { Write-Host "    $($_.BaseName)" -ForegroundColor Yellow }
        }
    }

    if ($runProj) {
        $smokeArgList = @($SmokeArgs -split '\s+' | Where-Object { $_ })
        $runArgs = @('run', '--project', $runProj, '-c', $Configuration, '--no-build', '--') + $smokeArgList
        $smokeCmd = "dotnet $($runArgs -join ' ')"

        Write-Host "`n--- smoke run ($Environment) ---" -ForegroundColor Yellow
        Write-Host "  $smokeCmd" -ForegroundColor DarkGray

        $run = Invoke-Capture -FilePath 'dotnet' -Arguments $runArgs `
            -TimeoutSec $RunTimeoutSec `
            -EnvVars @{
                ASPNETCORE_ENVIRONMENT = $Environment
                DOTNET_ENVIRONMENT     = $Environment
            }

        $runOut = "$($run.Stdout)`n$($run.Stderr)"
        $runExit = $run.ExitCode

        # Levely: textová ('ERROR') i Serilog krátká ('[ERR]') forma.
        $counts.INFO  = Get-LevelCount -Text $runOut -Pattern '(\bINFO\b|\[INF\])'
        $counts.WARN  = Get-LevelCount -Text $runOut -Pattern '(\bWARN(ING)?\b|\[WRN\])'
        $counts.ERROR = Get-LevelCount -Text $runOut -Pattern '(\bERROR\b|\[ERR\])'
        $counts.FATAL = Get-LevelCount -Text $runOut -Pattern '(\bFATAL\b|\[FTL\])'

        if ($run.TimedOut) {
            $runStatus = 'RED'
            $topFindings = @("Smoke run timeout po ${RunTimeoutSec}s.")
        }
        elseif ($counts.ERROR -gt 0 -or $counts.FATAL -gt 0 -or $runExit -ne 0) {
            $runStatus = 'RED'
            $topFindings = Get-MatchingLines -Text $runOut -Pattern '(\bERROR\b|\bFATAL\b|\[ERR\]|\[FTL\])' -Max 3
        }
        elseif ($counts.WARN -gt 0) {
            $runStatus = 'YELLOW'
            $topFindings = Get-MatchingLines -Text $runOut -Pattern '(\bWARN(ING)?\b|\[WRN\])' -Max 3
        }
        else {
            $runStatus = 'GREEN'
        }

        $color = @{ GREEN = 'Green'; YELLOW = 'Yellow'; RED = 'Red' }[$runStatus]
        Write-Host "Smoke run:  $runStatus (exit: $runExit, doba: $([math]::Round($run.DurationMs/1000,1))s)" -ForegroundColor $color
        Write-Host "Counts:     INFO $($counts.INFO) / WARN $($counts.WARN) / ERROR $($counts.ERROR) / FATAL $($counts.FATAL)"
        $topFindings | ForEach-Object { Write-Host "  $_" -ForegroundColor $color }
    }
}

# --------------------------------------------------------------------------
# 4. Append do state/snapshots-log.md
# --------------------------------------------------------------------------

$ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
$buildLine = if ($buildSucceeded) { "✅ (warnings: $warnCount, errors: $errCount)" }
             else { "❌ (warnings: $warnCount, errors: $errCount)" }

if ($null -eq $runStatus) {
    $runLine = if ($NoRun) { '— (přeskočeno, -NoRun)' }
               elseif (-not $buildSucceeded) { '— (přeskočeno, build FAILED)' }
               else { '— (přeskočeno, nejednoznačný spustitelný projekt)' }
    $countsLine = '—'
}
else {
    $icon = @{ GREEN = '✅ GREEN'; YELLOW = '🟡 YELLOW'; RED = '🔴 RED' }[$runStatus]
    $runLine = "$icon (exit: $runExit)"
    $countsLine = "INFO $($counts.INFO) / WARN $($counts.WARN) / ERROR $($counts.ERROR) / FATAL $($counts.FATAL)"
}

$findingsBlock = if ($topFindings.Count -gt 0) {
    ($topFindings | ForEach-Object { "- $($_.Trim())" }) -join "`n"
} else { '- —' }

$entry = @"
## $ts — $($connDir.Name) ($Environment, $Configuration)

**Build:** $buildLine
**Run:** $runLine
**Counts:** $countsLine
**Top findings:**
$findingsBlock

**Command:** ``$(if ($smokeCmd) { $smokeCmd } else { '—' })``
**Operátor:** tools/run-conn-tests.ps1
"@

$logPath = Add-SnapshotLogEntry -EntryMarkdown $entry
Write-Host "`nZapsáno do: $logPath" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# Exit code skriptu
# --------------------------------------------------------------------------

if (-not $buildSucceeded) { exit 1 }
if ($runStatus -eq 'RED') { exit 1 }
exit 0
