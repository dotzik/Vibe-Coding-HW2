#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Scaffold dokumentační kostry connectoru: docs/ se 6 šablonami.

.DESCRIPTION
    Mechanická část HYBRID skillu /onboard-connector:
      1. Resolve cílového docs/ adresáře (z -DocsDir nebo z adresáře connectoru).
      2. Render 6 šablon z templates/connector-docs/ se substitucí placeholderů.

    Substituce: {{ConnectorName}} → -Connector, {{Registry}} → -Registry,
    {{Date}} → dnešní datum. Substituuje se jen placeholder, který v šabloně
    skutečně je; ruční fill-in placeholdery zůstávají. Existující soubory
    NEpřepisuje. Validaci registru a zápis do knowledge/connectors-inventory.md
    dělá skill /onboard-connector, ne tento skript.

.PARAMETER Connector
    Název connectoru — dosadí se za {{ConnectorName}} v šablonách.

.PARAMETER DocsDir
    Cílový docs/ adresář. Bez něj skript resolve adresář connectoru v
    $PROJECT_ROOT/Connectors/ a zvolí src/<name>/docs (nebo <name>/docs).

.PARAMETER Registry
    Volitelný klíč registru — dosadí se za {{Registry}}.

.PARAMETER Force
    Doplnit jen chybějící šablony do už existujícího docs/ (nikdy nepřepisuje).

.PARAMETER Preview
    Jen vypíše plán, nic nezapíše.

.EXAMPLE
    pwsh tools/onboard-connector.ps1 -Connector Connector.CZ.IsRed
.EXAMPLE
    pwsh tools/onboard-connector.ps1 -Connector ARES -DocsDir D:/tmp/docs -Preview
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Connector,
    [string]$DocsDir,
    [string]$Registry,
    [switch]$Force,
    [switch]$Preview
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/_common.ps1"

# --------------------------------------------------------------------------
# 1. Resolve šablon
# --------------------------------------------------------------------------

$srcDir = Join-Path (Get-ProfileRoot) 'templates/connector-docs'
if (-not (Test-Path -LiteralPath $srcDir -PathType Container)) {
    throw "Šablony connector-docs nenalezeny: $srcDir"
}

# --------------------------------------------------------------------------
# 2. Resolve cílového docs/ adresáře
# --------------------------------------------------------------------------

if ($DocsDir) {
    $destDir = $DocsDir
}
else {
    $connDir = Resolve-Connector -Name $Connector
    $destDir = Resolve-ConnectorDocsDir -ConnectorDir $connDir
    Write-Host "Connector:  $($connDir.Name)" -ForegroundColor Cyan
}
Write-Host "Docs:       $destDir" -ForegroundColor Cyan

# --------------------------------------------------------------------------
# 3. Existence check
# --------------------------------------------------------------------------

if ((Test-Path -LiteralPath $destDir) -and -not $Force -and -not $Preview) {
    $existing = @(Get-ChildItem -LiteralPath $destDir -File -Filter '*.md' -ErrorAction SilentlyContinue)
    if ($existing.Count -gt 0) {
        throw "docs/ už obsahuje $($existing.Count) .md souborů: $destDir`n" +
              "Pro doplnění jen chybějících šablon použij -Force, jinak zvaž /upgrade-docs."
    }
}

# --------------------------------------------------------------------------
# 4. Render 6 šablon
# --------------------------------------------------------------------------

$tokens = @{
    ConnectorName = $Connector
    Registry      = ($Registry ?? '')
    Date          = (Get-Date -Format 'yyyy-MM-dd')
}
$report = Copy-TemplateTree -SourceDir $srcDir -DestDir $destDir -Tokens $tokens -Preview:$Preview

# --------------------------------------------------------------------------
# 5. Souhrn
# --------------------------------------------------------------------------

if ($Preview) { Write-Host "`n--- PREVIEW (nic se nezapsalo) ---" -ForegroundColor Yellow }
foreach ($r in $report) {
    $isNew = $r.Action -eq 'Created'
    $tag   = $isNew ? ($Preview ? 'by vzniklo' : 'vytvořeno') : 'přeskočeno'
    Write-Host ("  {0,-12} {1}" -f $tag, $r.RelPath) -ForegroundColor ($isNew ? 'Green' : 'DarkGray')
}

$created = @($report | Where-Object { $_.Action -eq 'Created' }).Count
$skipped = @($report | Where-Object { $_.Action -eq 'Skipped' }).Count
$verb    = $Preview ? 'k vytvoření' : 'vytvořeno'
Write-Host ''
Write-Host "Hotovo: $created $verb, $skipped přeskočeno." -ForegroundColor Cyan
Write-Host "Další krok: skill /onboard-connector ověří registr a zapíše do connectors-inventory.md." -ForegroundColor DarkGray

exit 0
