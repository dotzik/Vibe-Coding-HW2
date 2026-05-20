#requires -Version 5
# PreToolUse hook pro mcp__jira__jira_add_worklog
# Varování, pokud `comment` vypadá jako kombinovaný multi-aktivity záznam
# (pipe `|` nebo semicolon mezi víc aktivitami).
# Ne-blokující: pouze warning, vždy exit 0, ŽÁDNÝ permissionDecision.
# Důvod: feedback_jira_worklog_format — jedna činnost = jeden worklog.

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)

try {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $hookIn = $raw | ConvertFrom-Json -ErrorAction Stop
} catch { exit 0 }
$input = $hookIn

# Vytáhneme comment z tool_input
$comment = $null
if ($input.tool_input -and $input.tool_input.comment) {
    $comment = [string]$input.tool_input.comment
}
if (-not $comment) { exit 0 }

# Heuristika kombinovaného záznamu:
#  - pipe '|' kdekoli (typický separátor v Excel kombinacích)
#  - semicolon ';' MEZI multi-word aktivitami (ne pouze koncové)
$pipeHit = $comment -match '\s\|\s' -or $comment -match '\|'
$semiHit = $comment -match '\w+\s*;\s*\w'

if ($pipeHit -or $semiHit) {
    $sep = if ($pipeHit) { 'pipe (|)' } else { 'semicolon (;)' }
    $issue = if ($input.tool_input.issue_key) { $input.tool_input.issue_key } else { '?' }
    $msg = "⚠️ Worklog comment pro $issue obsahuje $sep — vypadá jako kombinovaný záznam (více aktivit v jednom worklogu). Konvence: jedna činnost = jeden worklog (feedback_jira_worklog_format). Pokud je to vědomé, pokračuj; jinak rozděl do víc volání. Comment: `"$comment`""
    # Ne-blokující: pouze systemMessage, žádné decision/permissionDecision
    $out = @{ systemMessage = $msg } | ConvertTo-Json -Compress
    Write-Output $out
}

exit 0
