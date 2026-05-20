#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Scaffold per-ticket analytické složky connectoru: docs/Ana-<CONN-NNN>/.

.DESCRIPTION
    Mechanická část HYBRID skillu /start-ticket:
      1. Validace ticket key (^CONN-\d+$) a resolve connectoru.
      2. Render templates/analysis-folder/Ana-CONN-NNN/ do
         <connector>/.../docs/Ana-<CONN-NNN>/ — jde do git connectoru.
      3. Vytvoření pracovní scratch složky $PROJECT_ROOT/Tickets/<CONN-NNN>/.

    Substituce {{[CONN-NNN]}} → ticket key. Existující soubory NEpřepisuje.
    Žádný Jira call — Jira pull + prefill hlavičky investigation.md dělá
    skill /start-ticket, ne tento skript.

.PARAMETER Ticket
    Jira issue key, formát CONN-<číslo> (např. CONN-237).

.PARAMETER Connector
    Zkratka connectoru — analytická složka se zakládá v jeho docs/.

.PARAMETER DocsDir
    Override docs/ adresáře connectoru (jinak resolve: src/<name>/docs apod.).

.PARAMETER Force
    Doplnit jen chybějící šablony do už existující Ana-složky (nikdy nepřepisuje).

.PARAMETER Preview
    Jen vypíše plán, nic nezapíše.

.EXAMPLE
    pwsh tools/start-ticket.ps1 -Ticket CONN-237 -Connector SbirkaListin_Archiv
.EXAMPLE
    pwsh tools/start-ticket.ps1 -Ticket CONN-237 -Connector ARES -Preview
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Ticket,
    [Parameter(Mandatory, Position = 1)][string]$Connector,
    [string]$DocsDir,
    [switch]$Force,
    [switch]$Preview
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"

# --------------------------------------------------------------------------
# 1. Validace ticket key
# --------------------------------------------------------------------------

$Ticket = $Ticket.Trim().ToUpperInvariant()
if ($Ticket -notmatch '^CONN-\d+$') {
    throw "Neplatný ticket key '$Ticket' — očekáván formát CONN-<číslo>, např. CONN-237."
}

# --------------------------------------------------------------------------
# 2. Resolve šablon, connectoru a cílových cest
# --------------------------------------------------------------------------

$srcDir = Join-Path (Get-ProfileRoot) 'templates/analysis-folder/Ana-CONN-NNN'
if (-not (Test-Path -LiteralPath $srcDir -PathType Container)) {
    throw "Šablony analytické složky nenalezeny: $srcDir"
}

$connDir    = Resolve-Connector -Name $Connector
$docsRoot   = if ($DocsDir) { $DocsDir } else { Resolve-ConnectorDocsDir -ConnectorDir $connDir }
$anaDir     = Join-Path $docsRoot "Ana-$Ticket"
$scratchDir = Join-Path (Get-ProjectRoot) "Tickets/$Ticket"

Write-Host "Ticket:     $Ticket" -ForegroundColor Cyan
Write-Host "Connector:  $($connDir.Name)" -ForegroundColor Cyan
Write-Host "Analýza:    $anaDir"
Write-Host "Scratch:    $scratchDir"

# --------------------------------------------------------------------------
# 3. Existence check analytické složky
# --------------------------------------------------------------------------

if ((Test-Path -LiteralPath $anaDir) -and -not $Force -and -not $Preview) {
    throw "Analytická složka už existuje: $anaDir`n" +
          "Použij -Force pro doplnění jen chybějících šablon (nic se nepřepisuje)."
}

# --------------------------------------------------------------------------
# 4. Render analytické složky (do git connectoru)
# --------------------------------------------------------------------------

$report = Copy-TemplateTree -SourceDir $srcDir -DestDir $anaDir `
    -Tokens @{ '[CONN-NNN]' = $Ticket } -Preview:$Preview

if ($Preview) { Write-Host "`n--- PREVIEW (nic se nezapsalo) ---" -ForegroundColor Yellow }
foreach ($r in $report) {
    $isNew = $r.Action -eq 'Created'
    $tag   = $isNew ? ($Preview ? 'by vzniklo' : 'vytvořeno') : 'přeskočeno'
    Write-Host ("  {0,-12} Ana-$Ticket/{1}" -f $tag, $r.RelPath) `
        -ForegroundColor ($isNew ? 'Green' : 'DarkGray')
}

# --------------------------------------------------------------------------
# 5. Scratch složka Tickets/<CONN-NNN>/ (pracovní, mimo git connectoru)
# --------------------------------------------------------------------------

$scratchExisted = Test-Path -LiteralPath $scratchDir
if (-not $scratchExisted -and -not $Preview) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
}
$scratchTag = if ($scratchExisted) { 'existuje' }
              elseif ($Preview)    { 'by vznikla' }
              else                 { 'vytvořena' }
Write-Host ("  {0,-12} {1}" -f $scratchTag, $scratchDir) `
    -ForegroundColor ($scratchExisted ? 'DarkGray' : 'Green')

# --------------------------------------------------------------------------
# 6. Souhrn
# --------------------------------------------------------------------------

$created = @($report | Where-Object { $_.Action -eq 'Created' }).Count
$skipped = @($report | Where-Object { $_.Action -eq 'Skipped' }).Count
$verb    = $Preview ? 'k vytvoření' : 'vytvořeno'
Write-Host ''
Write-Host "Hotovo: $created $verb, $skipped přeskočeno." -ForegroundColor Cyan
Write-Host "Další krok: skill /start-ticket doplní hlavičku investigation.md z Jiry." -ForegroundColor DarkGray

exit 0
