#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Wrapper kolem CLI `DbIntrospect` — introspekce SQL Server schématu.

.DESCRIPTION
    Mechanická část skillu /dbintrospect (HYBRID):
      1. Zajistí build CLI (jen pokud chybí sestavený výstup).
      2. Resolve argumentů — connector → cesty, default --out.
      3. Spustí CLI a relaye výstup + exit code.

    AI orchestrace (diff proti database-model.md, per-change merge se schvalováním,
    append do snapshots-log.md) zůstává ve skillu /dbintrospect — tento skript ji NEdělá.

    POZN.: `DbIntrospect` CLI je interní C# nástroj a NENÍ součástí tohoto profil
    snapshotu. Profil obsahuje jen orchestrační vrstvu (skill + tento wrapper).
    Skript očekává CLI projekt v tools/DbIntrospect/ — v plném prostředí existuje;
    v tomto snapshotu chybí a skript skončí chybou „CLI projekt nenalezen".

    CLI je read-only proti DB (sys.* views + OBJECT_DEFINITION). Connection string
    si řeší CLI sám: -Connection > env var DBINTROSPECT__CONNECTIONSTRINGS__DEFAULT
    > appsettings.Local.json > appsettings.json.

.PARAMETER Mode
    snapshot | find-objects | dump-procedures | dump-tables | discover-from-code.

.PARAMETER Database
    Cílová databáze (přepíše Initial Catalog). Povinné mimo discover-from-code.

.PARAMETER Connector
    Zkratka connectoru — pro discover-from-code resolve --path a pro label výstupu.

.PARAMETER Path
    Adresář s C# kódem pro discover-from-code (override resolve z -Connector).

.PARAMETER Like
    T-SQL LIKE filtr (find-objects / dump-procedures / dump-tables).

.PARAMETER Names
    Soubor se seznamem jmen objektů (dump-procedures / dump-tables).

.PARAMETER Out
    Výstupní adresář. Default tools/DbIntrospect/out/<label>/<datum>/<mode>/.

.PARAMETER Connection
    Connection string override (jinak řeší CLI z appsettings / env var).

.EXAMPLE
    pwsh tools/dbintrospect.ps1 -Mode snapshot -Database AppDb
.EXAMPLE
    pwsh tools/dbintrospect.ps1 -Mode discover-from-code -Connector SK.NespolehlivyPlatce
.EXAMPLE
    pwsh tools/dbintrospect.ps1 -Mode find-objects -Database AppDb -Like subjects_%
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('snapshot', 'find-objects', 'dump-procedures', 'dump-tables', 'discover-from-code')]
    [string]$Mode,

    [string]$Database,
    [string]$Connector,
    [string]$Path,
    [string]$Like,
    [string]$Names,
    [string]$Out,
    [string]$Connection,
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [int]$TimeoutSec = 900
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"

# --------------------------------------------------------------------------
# 1. Validace vstupů
# --------------------------------------------------------------------------

if ($Mode -eq 'discover-from-code') {
    if (-not $Path -and -not $Connector) {
        throw "discover-from-code vyžaduje -Path nebo -Connector."
    }
}
elseif (-not $Database) {
    throw "Mód '$Mode' vyžaduje -Database (cílová databáze)."
}

$cliRoot = Join-Path $PSScriptRoot 'DbIntrospect'
$cliProj = Join-Path $cliRoot 'src/DbIntrospect/DbIntrospect.csproj'
if (-not (Test-Path -LiteralPath $cliProj)) {
    throw "CLI projekt nenalezen: $cliProj`n" +
          "DbIntrospect CLI je interní nástroj a není součástí tohoto profil snapshotu."
}

# --------------------------------------------------------------------------
# 2. Build CLI (jen pokud chybí sestavený výstup)
# --------------------------------------------------------------------------

$binDir = Join-Path (Split-Path -Parent $cliProj) "bin/$Configuration"
$dll = $null
if (Test-Path -LiteralPath $binDir) {
    $dll = Get-ChildItem -LiteralPath $binDir -Recurse -Filter 'DbIntrospect.dll' -File |
        Select-Object -First 1
}

if (-not $dll) {
    Write-Host "CLI není sestaveno — dotnet build ($Configuration)..." -ForegroundColor Yellow
    $build = Invoke-Capture -FilePath 'dotnet' `
        -Arguments @('build', $cliProj, '-c', $Configuration, '--nologo', '-v', 'minimal') `
        -TimeoutSec 300 -EnvVars @{ MSBUILDTERMINALLOGGER = 'off' }
    if ($build.ExitCode -ne 0 -or $build.TimedOut) {
        Write-Host $build.Stdout
        Write-Host $build.Stderr
        throw "Build CLI selhal (exit $($build.ExitCode))."
    }
    $dll = Get-ChildItem -LiteralPath $binDir -Recurse -Filter 'DbIntrospect.dll' -File |
        Select-Object -First 1
    if (-not $dll) { throw "Build proběhl, ale DbIntrospect.dll nenalezen v $binDir." }
}
Write-Host "CLI:        $($dll.FullName)" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# 3. Resolve argumentů CLI
# --------------------------------------------------------------------------

# discover-from-code: --path z -Connector, pokud nezadáno -Path.
if ($Mode -eq 'discover-from-code' -and -not $Path) {
    $Path = (Resolve-Connector -Name $Connector).FullName
}

# Default --out: tools/DbIntrospect/out/<label>/<datum>/<mode>/  (gitignored).
if (-not $Out -and $Mode -ne 'find-objects') {
    $label = if ($Database) { $Database } elseif ($Connector) { $Connector } else { 'run' }
    $label = $label -replace '[^\w.-]', '_'
    $Out = Join-Path $cliRoot "out/$label/$(Get-Date -Format 'yyyy-MM-dd')/$Mode"
}
if ($Out) {
    New-Item -ItemType Directory -Path $Out -Force | Out-Null
    $Out = (Resolve-Path -LiteralPath $Out).Path
}

$cliArgs = @($Mode)
switch ($Mode) {
    'discover-from-code' {
        $cliArgs += @('--path', $Path)
        if ($Out) { $cliArgs += @('--out', $Out) }
    }
    default {
        $cliArgs += @('--db', $Database)
        if ($Like)       { $cliArgs += @('--like', $Like) }
        if ($Names)      { $cliArgs += @('--names', $Names) }
        if ($Out)        { $cliArgs += @('--out', $Out) }
        if ($Connection) { $cliArgs += @('--connection', $Connection) }
    }
}

# --------------------------------------------------------------------------
# 4. Spuštění CLI
# --------------------------------------------------------------------------

Write-Host "Mode:       $Mode" -ForegroundColor Cyan
if ($Database) { Write-Host "DB:         $Database" }
if ($Path)     { Write-Host "Path:       $Path" }
if ($Out)  { Write-Host "Out:        $Out" }
Write-Host "`n--- DbIntrospect $($cliArgs -join ' ') ---" -ForegroundColor Yellow

# Spuštění sestaveného DLL → čistý výstup programu (bez build chatteru).
# WorkingDirectory = adresář DLL → CLI najde appsettings.json, logy jdou do bin/logs/.
$result = Invoke-Streamed -FilePath 'dotnet' `
    -Arguments (@($dll.FullName) + $cliArgs) `
    -TimeoutSec $TimeoutSec `
    -WorkingDirectory $dll.Directory.FullName

Write-Host ''
if ($result.TimedOut) {
    Write-Host "CLI timeout po ${TimeoutSec}s — proces ukončen." -ForegroundColor Red
    exit 124
}

# Exit codes CLI: 0 = OK, 1 = objekt chybí / nic nenalezeno, 2 = neočekávaná chyba.
$msg = switch ($result.ExitCode) {
    0       { 'OK' }
    1       { 'dokončeno s MISSING / žádný objekt nenalezen' }
    2       { 'neočekávaná chyba CLI' }
    default { "exit $($result.ExitCode)" }
}
$color = if ($result.ExitCode -eq 0) { 'Green' } elseif ($result.ExitCode -eq 1) { 'Yellow' } else { 'Red' }
Write-Host "CLI hotovo: $msg (exit $($result.ExitCode), doba $([math]::Round($result.DurationMs/1000,1))s)" -ForegroundColor $color
if ($Out) { Write-Host "Výstup v:   $Out" -ForegroundColor Cyan }

exit $result.ExitCode
