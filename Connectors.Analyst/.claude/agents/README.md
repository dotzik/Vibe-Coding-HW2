# Subagents

Adresář specializovaných subagentů profilu `Connectors.Analyst`. Anglické kebab-case názvy, český system prompt (viz [`feedback_skill_naming`](../memory/feedback_skill_naming.md)).

**Vyvolání:** hlavní agent přes `Agent` tool s `subagent_type: <name>`. Subagenti běží v izolovaném kontextu, chrání hlavní agent před zaplavením, lze je spouštět paralelně.

## Registr 5 subagentů

| Subagent | Status | Fáze | Tools (whitelist) | Model | K čemu |
|---|---|---|---|---|---|
| `doc-validator` | ✅ DONE | 1 | Read, Grep, Glob, MCP connectors/libs (read+list) | sonnet | Cross-čtení kódu connectoru a jeho 5 doc souborů → diff report |
| `dead-code-hunter` | ✅ DONE | 2 | Read, Grep, Glob, MCP connectors/libs (read) | sonnet | Public symboly bez callerů napříč connectory + Libs + CoreFramework |
| `bug-hunter` | ✅ DONE | 2 | Read, Grep, Glob, MCP connectors/libs (read) | sonnet | C# static patterns (null deref, exception swallowing, throw vs throw ex, race, deadlock) |
| `perf-hunter` | ✅ DONE | 2 | Read, Grep, Glob, MCP connectors/libs (read) | sonnet | N+1 SP volání, missing async, BulkCopy vs single insert, SELECT *, IEnumerable re-enum |
| `security-auditor` | ✅ DONE | 2 | Read, Grep, Glob, MCP connectors/libs (read) | sonnet | SQL injection, secrets v lozích, deserializace bez allow-list, hardcoded connection strings, TLS |

**Status legenda:** ⏳ TODO · 🚧 IN PROGRESS · ✅ DONE · ⏸️ BLOCKED

## Konvence

- **Read-only** — žádný subagent nemá `Write` / `Edit` / `Bash`. Findings vrací jako markdown report; o zápisu rozhoduje hlavní agent s uživatelem (typicky přes skill `/anomaly-report` ve fázi 3).
- **Frontmatter** — `name`, `description` (kdy hlavní agent má subagenta volat — rozhodující pro routing), `tools` (whitelist), `model`.
- **Output formát** — `# <Subagent> findings — <scope>`, sekce per finding s `path:line` evidencí, severity (low / med / high), vysvětlení.
- **Paralelizace** — 4 hunters jsou nezávislí, lze spustit v 1 message multiple `Agent` tool calls. Pozor na MCP rate limits.

## Struktura agent souboru

```
<name>.md
└── frontmatter (name, description, tools, model)
    + system prompt (česky, ~50-100 řádků)
```
