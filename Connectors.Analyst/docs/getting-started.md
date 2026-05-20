# Getting started — Connectors.Analyst

Detailní setup profilu. Pro rychlý přehled viz [`README.md`](../README.md).

## 1. Env vars

Profil je multi-user a cross-platform — žádné cesty nejsou hardcoded. Konfigurace jde přes env vars.

| Env var | Povinná | K čemu | Příklad |
|---|---|---|---|
| `PROJECT_ROOT` | ✅ | Root repa — rodič `Connectors` / `Libs` / `Connectors.Analyst`. Expanduje se v `.mcp.json`. | `D:/Work/Project` |
| `JIRA_CLOUD_ID` | pro Jira | Cloud ID Atlassian instance (MCP `jira`) | — |
| `JIRA_USERNAME` | pro Jira | Jira účet (e-mail) — `jira` + `worklog-export` | `jmeno@firma.cz` |
| `JIRA_TOKEN` | pro Jira | Jira API token — `jira` + `worklog-export` | — |
| `JIRA_URL` | export | Jira base URL — jen `worklog-export.ps1` (default `https://your-org.atlassian.net`) | — |
| `WORKLOG_XLSX_DIR` | export | Cílový adresář `.xlsx` — jen `worklog-export.ps1` | `D:/Vykazy` |

Jira API token: [id.atlassian.com → Security → API tokens](https://id.atlassian.com/manage-profile/security/api-tokens).

**Windows / PowerShell:**
```powershell
[Environment]::SetEnvironmentVariable('PROJECT_ROOT', 'D:/Work/Project', 'User')
```
Poté otevři **nový terminál** — env var se načte až tam.

**Linux / macOS** — přidej do `~/.profile` / `~/.zshrc`:
```bash
export PROJECT_ROOT="$HOME/work/Project"
```

## 2. Per-user settings

`.claude/settings.json` je **verzovaný** — sdílené hooky, MCP enable, permissions, statusLine. Needituj ho pro lokální potřeby.

Per-user override jde do `.claude/settings.local.json` (gitignored):
```
cp .claude/settings.local.json.example .claude/settings.local.json
```
(Windows: `Copy-Item`.) Soubor nech minimální (`{"permissions":{"allow":[]}}`), dokud nepotřebuješ vlastní override — `settings.local.json` přebíjí `settings.json`.

## 3. MCP servery

`.mcp.json` definuje 5 serverů; filesystem cesty se berou z `${PROJECT_ROOT}`.

| Server | Zdroj | K čemu |
|---|---|---|
| `connectors` | `${PROJECT_ROOT}/Connectors` | .NET konektory + jejich docs |
| `libs` | `${PROJECT_ROOT}/Libs` | sdílené knihovny (`BaseConnector`, `DBManager`…) |
| `profile` | `${PROJECT_ROOT}/Connectors.Analyst` | tento profil |
| `fetch` | `uvx mcp-server-fetch` | HTTP requesty pro webové dokumentace |
| `jira` | `uvx mcp-atlassian` | projektová Jira (worklog, issues) |

Po spuštění Claude Code ověř `/mcp` — všech 5 serverů musí běžet. Aktivace je v `.claude/settings.json` → `enabledMcpjsonServers`.

## 4. CLI nástroj DbIntrospect

`DbIntrospect` je interní C# CLI a **není součástí tohoto profil snapshotu** — profil obsahuje pouze orchestrační vrstvu (skill `dbintrospect` + wrapper `tools/dbintrospect.ps1`). V plném prostředí se CLI staví standardně přes `dotnet build` a connection string se konfiguruje v `appsettings.Local.json` (gitignored — obsahuje hesla). Wrapper `tools/dbintrospect.ps1` build zajistí sám, pokud sestavený výstup chybí.

## 5. Ověření profilu

Spusť Claude Code v adresáři profilu (`CLAUDE.md` se načte automaticky) a vyzkoušej:

| Dotaz | Očekávaný výsledek |
|---|---|
| „Kdo jsi?" | Představení role + motto „Z chaosu pořádek" |
| „Vyjmenuj connectory" | Tabulka z `knowledge/connectors-inventory.md` |
| „Co dělá `BaseConnector`?" | Aktivace `domains/connector-anatomy.md` + čtení kódu z `Libs/` |

Status bar (statusline) ukazuje: `connector │ branch │ ticket │ model │ cost │ duration`.

## Troubleshooting

| Problém | Řešení |
|---|---|
| MCP server `connectors` / `libs` / `profile` neběží | `PROJECT_ROOT` není nastaven nebo běží starý terminál → nastav + nový terminál → `/mcp` |
| `jira` selhává | Chybí `JIRA_*` env vars; ověř platnost API tokenu |
| Hook / skript hlásí „pwsh not found" | Nainstaluj PowerShell 7+ a měj `pwsh` v `PATH` |
| `worklog-export.ps1` selže na `ImportExcel` | `Install-Module ImportExcel -Scope CurrentUser` |
| Lokální `settings.local.json` přebíjí sdílené chování | Drž ho minimální; sdílená konfigurace patří do `settings.json` |

## Cross-platform poznámky

Profil běží na Windows / Linux / macOS. Skripty `tools/*.ps1` jsou PowerShell 7+ (`pwsh`), bez COM, `powershell.exe` či hardcoded `D:\`. Cesty se skládají přes `${PROJECT_ROOT}`, `$PSScriptRoot` a `Join-Path`. Hooky v `settings.json` běží pod `pwsh`.
