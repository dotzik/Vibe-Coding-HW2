# Skills, tools & subagents

Kompletní přehled schopností profilu. Registry se statusem: [`.claude/skills/README.md`](../.claude/skills/README.md), [`.claude/agents/README.md`](../.claude/agents/README.md).

## Skills

7 workflow-skills — vyvolání `/<name>` v promptu, nebo automaticky když dotaz odpovídá frázi v `description`.

| Skill | K čemu |
|---|---|
| `/upgrade-docs` | Povýšení dokumentace konektoru na standard — dual-view, per-doc gates |
| `/cross-consistency-check` | Audit jednotného stylu docs napříč dostupnými konektory |
| `/anomaly-report` | Formátování ⚠️ nálezu do `<connector>/docs/anomalies.md` + draft Jira |
| `/refactor-proposal` | Kategorizace kosmetic / structural / breaking + per-bucket gates |
| `/jira-from-context` | Z analytického kontextu (anomaly / refactor / investigation) → Jira issue |
| `/standup-prep` | Yesterday / Today / Blockers z git log napříč repos + Jira |
| `/worklog` | Vykázání času do Jiry z chatu — viz [`worklog.md`](worklog.md) |

**HYBRID skilly** — tenká AI vrstva nad skriptem (mechanika = skript, orchestrace = skill):

| Skill | Skript | AI část |
|---|---|---|
| `/start-ticket` | `start-ticket.ps1` | Jira pull + prefill `investigation.md` |
| `/dbintrospect` | `dbintrospect.ps1` | Merge introspekce do `database-model.md` |
| `/onboard-connector` | `onboard-connector.ps1` | Registr + zápis do `connectors-inventory.md` |

## Tools / Scripts

PowerShell 7+ skripty v `tools/`. Spuštění: `pwsh tools/<name>.ps1 -<param> …`. Detail v hlavičce každého skriptu.

| Skript | Typ | K čemu |
|---|---|---|
| `run-conn-tests.ps1` | autonomní | Build `.sln` + smoke run + parse + klasifikace GREEN/YELLOW/RED → `state/snapshots-log.md` |
| `dbintrospect.ps1` | HYBRID | Wrapper `DbIntrospect` CLI — introspekce stored procedur a schématu |
| `start-ticket.ps1` | HYBRID | Scaffold analytické složky `docs/Ana-<CONN-NNN>/` + pracovní scratch |
| `onboard-connector.ps1` | HYBRID | Render 6 docs šablon pro nový konektor |
| `worklog-export.ps1` | opt-in | Export Jira worklogů za měsíc → `WS_<MĚSÍC>_<ROK>.xlsx` (vyžaduje `ImportExcel`) |
| `statusline.ps1` | statusLine | Řádek status baru — registrovaný v `settings.json`, nevolá se ručně |

`_common.ps1` není spustitelný — je to sdílený helper modul (connector resolve, spouštění procesů s timeoutem, render šablon).

## Subagents

5 read-only subagentů — běží v izolovaném kontextu, lze je spouštět paralelně. Volá je hlavní agent přes `Agent` tool s `subagent_type`. Všichni: Read / Grep / Glob + read-only MCP `connectors` / `libs`, model sonnet.

| Subagent | K čemu |
|---|---|
| `doc-validator` | Cross-čtení kódu konektoru ↔ jeho doc soubory → diff report (Missing / Stale / Mismatched / Style) |
| `dead-code-hunter` | Public symboly bez callerů napříč Connectors + Libs + CoreFramework |
| `bug-hunter` | C# static patterns — null deref, exception swallowing, `throw ex`, race, deadlock |
| `perf-hunter` | N+1 SP volání, sync-over-async, missing BulkCopy, SELECT *, IEnumerable re-enum |
| `security-auditor` | SQL injection, secrets v lozích, deserializace bez allow-listu, hardcoded conn strings, TLS |

## Hooks

3 non-blocking PowerShell hooky (registrace v `.claude/settings.json`).

| Hook | Event | Účel |
|---|---|---|
| `track-cs-edit.ps1` | PostToolUse Edit\|Write | Track `.cs` editů v Connectors + detekce public-API / SP-volání změn |
| `validate-worklog.ps1` | PreToolUse `jira_add_worklog` | Varuje na pipe / středník v commentu (příznak kombinovaného worklogu) |
| `docs-sync-prompt.ps1` | Stop | Sumář editovaných konektorů + návrh `/upgrade-docs <name>` |
