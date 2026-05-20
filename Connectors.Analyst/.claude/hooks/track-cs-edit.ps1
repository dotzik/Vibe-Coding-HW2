#requires -Version 5
# PostToolUse hook pro Edit/Write na Connectors/**/*.cs
# - Eviduje editované soubory pro Stop hook (docs-sync-prompt)
# - Upozorní, když změna mění public API / SP volání (*DA.cs / DBAccess.cs)
# Ne-blokující: vždy exit 0, žádné permissionDecision.

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)

try {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $hookIn = $raw | ConvertFrom-Json -ErrorAction Stop
} catch { exit 0 }
$input = $hookIn

$tool = $input.tool_name
if ($tool -ne 'Edit' -and $tool -ne 'Write') { exit 0 }

# Cesta k editovanému souboru
$filePath = $null
if ($input.tool_input) {
    $filePath = $input.tool_input.file_path
}
if (-not $filePath) { exit 0 }

# Sjednocení separátorů (Windows backslash → forward slash kvůli regexu)
$normalized = $filePath -replace '\\', '/'

# Filtr: pouze .cs soubory uvnitř .../Connectors/ (cross-platform match)
if ($normalized -notmatch '(?i)/Connectors/.+\.cs$') { exit 0 }

# Extrakce jména connectoru (segment hned za /Connectors/)
$connector = $null
if ($normalized -match '(?i)/Connectors/([^/]+)/') {
    $connector = $Matches[1]
}

# Append do per-session state souboru (čte ho Stop hook docs-sync-prompt)
$stateFile = Join-Path $PSScriptRoot '.last-session-edits'
try {
    $line = "{0}`t{1}" -f ($connector ?? '?'), $filePath
    Add-Content -Path $stateFile -Value $line -Encoding UTF8 -ErrorAction Stop
} catch { }

# Heuristika — detekce změny public API / SP volání
$old = ''
$new = ''
if ($input.tool_input) {
    if ($input.tool_input.old_string) { $old = [string]$input.tool_input.old_string }
    if ($input.tool_input.new_string) { $new = [string]$input.tool_input.new_string }
    if ($input.tool_input.content)    { $new = [string]$input.tool_input.content }
}

# Regex pro public členy (třídy, metody, properties, atd.)
$rxPublic = '(?m)^\s*public\s+(class|interface|record|struct|enum|abstract|virtual|override|static|sealed|async|partial|[A-Z])'
# Regex pro SP/ADO.NET volání
$rxSpCall = 'ExecuteScalar|ExecuteNonQuery|ExecuteReader|ExecuteDataset|sp_executesql|CommandText\s*=\s*"[A-Za-z_]'

# Detekce přidání/změny public členu v nové verzi
$publicChanged = ($new -match $rxPublic) -and ($old -notmatch [regex]::Escape(($new -split "`n" | Where-Object { $_ -match $rxPublic } | Select-Object -First 1)))
# Záložní heuristika: rozdílný počet 'public ' výskytů → změna v public API
if (-not $publicChanged) {
    $oldPubCount = ([regex]::Matches($old, '\bpublic\s+')).Count
    $newPubCount = ([regex]::Matches($new, '\bpublic\s+')).Count
    if ($oldPubCount -ne $newPubCount) { $publicChanged = $true }
}

# SP volání řešíme jen v Data Access vrstvě (filename heuristika)
$isDA = $normalized -match '(?i)DA\.cs$' -or $normalized -match '(?i)DBAccess\.cs$'
$spChanged = $isDA -and (($new -match $rxSpCall) -or ($old -match $rxSpCall))

# Pokud změna spadá do jednoho z bucketů → vypsat varování (systemMessage v JSON)
if ($publicChanged -or $spChanged) {
    $reasons = @()
    if ($publicChanged) { $reasons += 'public API' }
    if ($spChanged)     { $reasons += 'SP volání' }
    $reasonStr = ($reasons -join ' / ')
    $msg = "⚠️ Změna v $filePath se dotkla: $reasonStr. Zvaž update $connector/docs/stored-procedures.md nebo /upgrade-docs $connector."
    $out = @{ systemMessage = $msg } | ConvertTo-Json -Compress
    Write-Output $out
}

exit 0
