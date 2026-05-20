#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Export Jira worklogů aktuálního uživatele za měsíc do WS_<MĚSÍC>_<ROK>.xlsx.

.DESCRIPTION
    Opt-in nástroj pro účetnictví — NEpotřebný pro denní vykazování (to dělá
    skill /worklog z chatu). Přes Jira REST (Invoke-RestMethod) stáhne všechny
    worklogy přihlášeného uživatele za zadaný měsíc a vyexportuje je do Excelu.

    Modul ImportExcel je závislost POUZE tohoto skriptu — skill /worklog ani
    zbytek profilu Excel nepotřebuje.

    Konfigurace přes env vars:
      JIRA_URL          Jira base URL (default https://your-org.atlassian.net)
      JIRA_USERNAME     Jira účet (e-mail)
      JIRA_TOKEN        Jira API token
      WORKLOG_XLSX_DIR  cílový adresář .xlsx (lze přepsat -OutDir)

.PARAMETER Month
    Měsíc 1–12. Default aktuální měsíc.

.PARAMETER Year
    Rok. Default aktuální rok.

.PARAMETER OutDir
    Cílový adresář. Default env var WORKLOG_XLSX_DIR.

.EXAMPLE
    pwsh tools/worklog-export.ps1
.EXAMPLE
    pwsh tools/worklog-export.ps1 -Month 5 -Year 2026 -OutDir D:/Vykazy
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 12)][int]$Month = (Get-Date).Month,
    [ValidateRange(2000, 2100)][int]$Year = (Get-Date).Year,
    [string]$OutDir
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# --------------------------------------------------------------------------
# 1. Závislost ImportExcel
# --------------------------------------------------------------------------

if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    throw "Modul ImportExcel není nainstalován — tento skript ho jako jediný v profilu vyžaduje.`n" +
          "Instalace:  Install-Module ImportExcel -Scope CurrentUser"
}
Import-Module ImportExcel

# --------------------------------------------------------------------------
# 2. Konfigurace
# --------------------------------------------------------------------------

$jiraUrl = if ($env:JIRA_URL) { $env:JIRA_URL.TrimEnd('/') } else { 'https://your-org.atlassian.net' }
$jiraUser = $env:JIRA_USERNAME
$jiraToken = $env:JIRA_TOKEN
if ([string]::IsNullOrWhiteSpace($jiraUser) -or [string]::IsNullOrWhiteSpace($jiraToken)) {
    throw "Chybí Jira přihlášení — nastav env vars JIRA_USERNAME (e-mail) a JIRA_TOKEN (API token)."
}

$OutDir = if ($OutDir) { $OutDir }
          elseif ($env:WORKLOG_XLSX_DIR) { $env:WORKLOG_XLSX_DIR }
          else { $null }
if (-not $OutDir) {
    throw "Není kam exportovat — předej -OutDir nebo nastav env var WORKLOG_XLSX_DIR."
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

# Rozsah měsíce + název souboru/listu.
$from = [datetime]::new($Year, $Month, 1)
$to   = $from.AddMonths(1).AddDays(-1)
$cs   = [System.Globalization.CultureInfo]::GetCultureInfo('cs-CZ')
$monthName = $cs.DateTimeFormat.MonthNames[$Month - 1].ToUpper($cs)
$outFile = Join-Path $OutDir "WS_${monthName}_${Year}.xlsx"

# --------------------------------------------------------------------------
# 3. Jira REST klient
# --------------------------------------------------------------------------

$authHeader = 'Basic ' + [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes("${jiraUser}:${jiraToken}"))
$headers = @{ Authorization = $authHeader; Accept = 'application/json' }

function Invoke-Jira {
    param([Parameter(Mandatory)][string]$Path, [hashtable]$Query = @{})
    $uri = "$jiraUrl$Path"
    if ($Query.Count -gt 0) {
        $pairs = foreach ($k in $Query.Keys) { "$k=" + [uri]::EscapeDataString([string]$Query[$k]) }
        $uri += '?' + ($pairs -join '&')
    }
    try {
        return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    }
    catch {
        $code = $_.Exception.Response.StatusCode.value__ 2>$null
        if ($code -eq 401 -or $code -eq 403) {
            throw "Jira odmítla přihlášení (HTTP $code) — zkontroluj JIRA_USERNAME / JIRA_TOKEN."
        }
        throw "Jira REST volání selhalo ($Path): $($_.Exception.Message)"
    }
}

# Plochý text z ADF (Atlassian Document Format) — rekurzivně sesbírá text nody.
function Get-AdfText {
    param($Node)
    if ($null -eq $Node) { return '' }
    if ($Node -is [string]) { return $Node }
    $sb = [System.Text.StringBuilder]::new()
    if ($Node.PSObject.Properties['text']) { [void]$sb.Append([string]$Node.text) }
    if ($Node.PSObject.Properties['content'] -and $Node.content) {
        foreach ($child in $Node.content) { [void]$sb.Append((Get-AdfText $child)) }
        if ($Node.PSObject.Properties['type'] -and $Node.type -in @('paragraph', 'heading')) {
            [void]$sb.Append(' ')
        }
    }
    return $sb.ToString()
}

# --------------------------------------------------------------------------
# 4. Stažení worklogů
# --------------------------------------------------------------------------

Write-Host "Jira:       $jiraUrl" -ForegroundColor Cyan
Write-Host "Období:     $($from.ToString('yyyy-MM-dd')) – $($to.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan

$me = Invoke-Jira -Path '/rest/api/3/myself'
$myAccountId = $me.accountId
Write-Host "Uživatel:   $($me.displayName)"

# Issues s worklogem aktuálního uživatele v období.
$jql = 'worklogAuthor = currentUser() ' +
       "AND worklogDate >= `"$($from.ToString('yyyy/MM/dd'))`" " +
       "AND worklogDate <= `"$($to.ToString('yyyy/MM/dd'))`""

$issueKeys = [System.Collections.Generic.List[string]]::new()
$pageToken = $null
do {
    $q = @{ jql = $jql; fields = 'key'; maxResults = 100 }
    if ($pageToken) { $q.nextPageToken = $pageToken }
    $resp = Invoke-Jira -Path '/rest/api/3/search/jql' -Query $q
    foreach ($i in $resp.issues) { $issueKeys.Add($i.key) }
    $pageToken = if ($resp.PSObject.Properties['nextPageToken']) { $resp.nextPageToken } else { $null }
    $isLast = (-not $resp.PSObject.Properties['isLast']) -or $resp.isLast
} while ($pageToken -and -not $isLast)

Write-Host "Issues:     $($issueKeys.Count) s worklogem v období"

# Per issue stáhnout worklogy, filtrovat na autora + období.
$rows = [System.Collections.Generic.List[object]]::new()
foreach ($key in $issueKeys) {
    $startAt = 0
    do {
        $wl = Invoke-Jira -Path "/rest/api/3/issue/$key/worklog" `
            -Query @{ startAt = $startAt; maxResults = 100 }
        foreach ($w in $wl.worklogs) {
            if ($w.author.accountId -ne $myAccountId) { continue }
            $started = [datetimeoffset]::Parse([string]$w.started)
            if ($started.Date -lt $from -or $started.Date -gt $to) { continue }
            $comment = if ($w.PSObject.Properties['comment']) { (Get-AdfText $w.comment).Trim() } else { '' }
            $rows.Add([pscustomobject]@{
                Datum  = $started.ToString('yyyy-MM-dd')
                Ticket = $key
                Hodiny = [math]::Round($w.timeSpentSeconds / 3600, 2)
                Popis  = ($comment -replace '\s+', ' ')
                Start  = $started.ToString('HH:mm')
            })
        }
        $startAt += $wl.maxResults
    } while ($startAt -lt $wl.total)
}

# --------------------------------------------------------------------------
# 5. Export do .xlsx
# --------------------------------------------------------------------------

if ($rows.Count -eq 0) {
    Write-Host "Žádné worklogy v období — .xlsx se nevytváří." -ForegroundColor Yellow
    exit 0
}

$sorted = $rows | Sort-Object Datum, Start | Select-Object Datum, Ticket, Hodiny, Popis
$sorted | Export-Excel -Path $outFile -WorksheetName $monthName -TableName 'Worklogy' `
    -AutoSize -ClearSheet -FreezeTopRow

$totalH = [math]::Round((($rows | Measure-Object Hodiny -Sum).Sum), 2)
Write-Host ''
Write-Host "Export:     $($rows.Count) worklogů, celkem ${totalH}h" -ForegroundColor Green
Write-Host "Soubor:     $outFile" -ForegroundColor Cyan

exit 0
