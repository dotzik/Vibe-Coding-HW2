# Connectors.Analyst

Claude Code profil — **senior .NET / SQL Server analytik** pro sadu konzolových konektorů datové platformy, které těží data z veřejných obchodních registrů ČR a SK (ARES, Rejstřík právnických osob, Sbírka listin, Finančná správa SK…).

Profil dává Claudovi doménový kontext, **7 workflow-skills**, **6 PowerShell skriptů**, **5 read-only subagentů** a **3 hooky** pro analýzu, dokumentaci a údržbu konektorů.

## Co profil umí

- **Povýšit dokumentaci** konektoru na jednotný standard (`/upgrade-docs`, `/cross-consistency-check`)
- **Analyzovat DB** — introspekce stored procedur a schématu (`/dbintrospect`, `DbIntrospect` CLI)
- **Lovit problémy** — dead code, bugy, perf, security (4 hunter subagenti)
- **Reportovat** anomálie, refactor návrhy, Jira issues (`/anomaly-report`, `/refactor-proposal`, `/jira-from-context`)
- **Vykazovat čas** do Jiry z chatu (`/worklog`) + denní standup (`/standup-prep`)

## Předpoklady

| Nástroj | Verze | K čemu |
|---|---|---|
| PowerShell | 7+ (`pwsh`) | hooky + `tools/*.ps1` skripty |
| .NET SDK | 8.0+ | build konektorů + `DbIntrospect` CLI |
| Node.js + `npx` | LTS | MCP filesystem servery |
| `uvx` (uv) | aktuální | MCP `fetch` + `jira` |
| Claude Code | aktuální | běhové prostředí profilu |

Repo s konektory (`Connectors`, `Libs`, `Connectors.Analyst`) musí být lokálně dostupné pod jednou root cestou.

## Quick start

1. **Env var `PROJECT_ROOT`** — nastav na root repa (rodič `Connectors` / `Libs` / `Connectors.Analyst`).
2. **Per-user settings** — zkopíruj `.claude/settings.local.json.example` → `.claude/settings.local.json`.
3. **Jira (volitelné)** — nastav `JIRA_*` env vars (viz [`docs/getting-started.md`](docs/getting-started.md)).
4. **Spusť Claude Code** v adresáři profilu — `CLAUDE.md` se načte automaticky.
5. **Ověř** — `/mcp` (5 serverů běží) + dotaz „Kdo jsi?".

Detailní setup, troubleshooting a cross-platform poznámky: **[`docs/getting-started.md`](docs/getting-started.md)**.

## Dokumentace

| Dokument | Obsah |
|---|---|
| [`docs/getting-started.md`](docs/getting-started.md) | Instalace, env vars, settings, CLI setup, troubleshooting |
| [`docs/skills-and-tools.md`](docs/skills-and-tools.md) | Přehled 7 skills + 6 skriptů + 5 subagentů |
| [`docs/worklog.md`](docs/worklog.md) | Workflow vykazování času do Jiry |
| [`docs/UPGRADE-GUIDE.md`](docs/UPGRADE-GUIDE.md) | Povýšení existující dokumentace konektoru |
| [`docs/DOC-WORKFLOW.md`](docs/DOC-WORKFLOW.md) | Tvorba dokumentace nového konektoru |
| [`CLAUDE.md`](CLAUDE.md) | Vstupní bod profilu — moduly, registry, konvence |

## Struktura

`core/` persona · `domains/` doménové moduly · `knowledge/` referenční znalost · `templates/` šablony docs a output · `tools/` PowerShell skripty (orchestrační vrstva nad `DbIntrospect` CLI) · `state/` projektový stav · `.claude/` skills + agents + hooks + memory.

> **Pozn.:** `DbIntrospect` CLI je interní C# nástroj a není součástí tohoto profil snapshotu — profil obsahuje pouze orchestrační vrstvu (skill `dbintrospect` + wrapper skript `tools/dbintrospect.ps1`).
