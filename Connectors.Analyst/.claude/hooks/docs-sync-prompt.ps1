#requires -Version 5
# Stop hook — pokud session editovala *.cs v Connectors,
# vypíše prompt s návrhem spustit /upgrade-docs per connector.
# Ne-blokující: vždy exit 0. Po vypsání state file vymaže.

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)

# Per-session state — naplňuje track-cs-edit.ps1 (PostToolUse Edit/Write)
$stateFile = Join-Path $PSScriptRoot '.last-session-edits'
if (-not (Test-Path $stateFile)) { exit 0 }

try {
    $lines = Get-Content -Path $stateFile -Encoding UTF8 -ErrorAction Stop
} catch {
    exit 0
}

# Prázdný state → nic na práci
if (-not $lines -or $lines.Count -eq 0) {
    Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
    exit 0
}

# Grupování per connector (klíč = connector, hodnota = unikátní seznam cest)
$byConnector = @{}
foreach ($l in $lines) {
    $parts = $l -split "`t", 2
    if ($parts.Count -lt 2) { continue }
    $c = $parts[0]
    if (-not $byConnector.ContainsKey($c)) { $byConnector[$c] = @() }
    if ($byConnector[$c] -notcontains $parts[1]) { $byConnector[$c] += $parts[1] }
}

# Spočítat celkový počet souborů napříč connectory
$totalFiles = ($byConnector.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
if (-not $totalFiles -or $totalFiles -eq 0) {
    Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue
    exit 0
}

# Sestavení zprávy: seznam connectorů + per-connector suggestion /upgrade-docs
$connectorList = ($byConnector.Keys | Sort-Object) -join ', '
$suggestions = ($byConnector.Keys | Sort-Object | ForEach-Object { "/upgrade-docs $_" }) -join '  ·  '

$msg = "⚠️ V session jsi editoval $totalFiles .cs soubor(ů) v: $connectorList. Doporučuju spustit:  $suggestions  pro sync docs."

# Vymazat state — další session začíná čistá
Remove-Item -Path $stateFile -Force -ErrorAction SilentlyContinue

$out = @{ systemMessage = $msg } | ConvertTo-Json -Compress
Write-Output $out
exit 0
