#!/usr/bin/env pwsh
#Requires -Version 7
<#
.SYNOPSIS
  Claude Code statusLine pro profil Connectors.Analyst.
.DESCRIPTION
  Čte JSON popis session na stdin (model, workspace, cost) a vypíše jeden
  řádek do status baru. Cross-platform (pwsh 7+), žádný hardcoded path.
  Formát:  <connector> │ <branch>[*] │ <TICKET> │ <model> │ $<cost> │ <duration>
  Při jakékoli chybě vypíše fallback a skončí s exit 0 — status bar nikdy
  nesmí shodit session.
.NOTES
  Registrace: .claude/settings.json → "statusLine".
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# StrictMode-safe čtení property z PSCustomObject (ConvertFrom-Json).
function Get-Prop {
    param($Object, [string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $null
}

try {
    $raw = [Console]::In.ReadToEnd()
    $session = $null
    if ($raw) {
        $session = $raw | ConvertFrom-Json
    }

    # --- pracovní adresář ---
    $workspace = Get-Prop $session 'workspace'
    $cwd = Get-Prop $workspace 'current_dir'
    if (-not $cwd) {
        $cwd = (Get-Location).Path
    }

    # --- connector (z cesty) ---
    $connector = 'Connectors.Analyst'
    $match = [regex]::Match($cwd, '(Connector\.[A-Za-z0-9._]+)')
    if ($match.Success) {
        $connector = $match.Groups[1].Value
    }
    elseif ($cwd -match 'Connectors\.Analyst') {
        $connector = 'Analyst-profil'
    }

    # --- git branch + dirty flag ---
    $branch = $null
    $dirty = ''
    try {
        $branchRaw = & git -C $cwd rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $branchRaw) {
            $branch = "$branchRaw".Trim()
            $status = & git -C $cwd status --porcelain 2>$null
            if ($status) {
                $dirty = '*'
            }
        }
    }
    catch {
        $branch = $null
    }

    # --- Jira ticket (z branche, fallback z cesty) ---
    $ticket = $null
    $source = if ($branch) { $branch } else { $cwd }
    $ticketMatch = [regex]::Match($source, '([A-Z]{2,}-\d+)')
    if ($ticketMatch.Success) {
        $ticket = $ticketMatch.Groups[1].Value
    }

    # --- model ---
    $model = 'Claude'
    $modelObj = Get-Prop $session 'model'
    $modelName = Get-Prop $modelObj 'display_name'
    if ($modelName) {
        $model = $modelName
    }

    # --- cost + duration ---
    $cost = '$0.00'
    $duration = ''
    $costObj = Get-Prop $session 'cost'
    if ($costObj) {
        $usd = Get-Prop $costObj 'total_cost_usd'
        if ($null -ne $usd) {
            $cost = '$' + ('{0:N2}' -f [double]$usd)
        }
        $ms = Get-Prop $costObj 'total_duration_ms'
        if ($null -ne $ms) {
            $totalSec = [int]([double]$ms / 1000)
            $duration = '{0}m{1:D2}s' -f [int][math]::Floor($totalSec / 60), ($totalSec % 60)
        }
    }

    # --- sestavení řádku ---
    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add($connector)
    if ($branch) {
        $parts.Add($branch + $dirty)
    }
    if ($ticket) {
        $parts.Add($ticket)
    }
    $parts.Add($model)
    $parts.Add($cost)
    if ($duration) {
        $parts.Add($duration)
    }

    Write-Output ($parts -join ' │ ')
}
catch {
    Write-Output 'Connectors.Analyst'
}

exit 0
