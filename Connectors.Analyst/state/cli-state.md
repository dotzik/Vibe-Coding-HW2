---
module: state-cli
version: 1.1.0
tags: [state, cli, dbintrospect]
scope: all
updated: 2026-04-28
---

# DbIntrospect — aktuální stav

> **Pozn.:** samotné `DbIntrospect` CLI je interní C# nástroj a není součástí tohoto profil snapshotu. Profil obsahuje jen orchestrační vrstvu — skill `dbintrospect` + wrapper `tools/dbintrospect.ps1`. Tento soubor drží stav CLI jako referenci pro orchestraci.

**Verze:** 0.1.0 (Initial, 2026-04-27)
**Stack:** .NET 8 console + `Microsoft.Data.SqlClient` 5.2 + `System.CommandLine` 2.0-beta + `Serilog` 4.0

## Účel

Nahradit ručně spouštěné `_scripts/00_find_objects.sql` / `01_*_tables.sql` / `02_*_procedures.sql` napříč connectory + řešit SSMS truncation problém (default 4000 znaků na `sys.sql_modules.definition`). Inspirace `DbRepairUtility.SK.FinRed.Dluhy`.

## Commandy

| Command | Popis |
|---|---|
| `find-objects --db X --like %name%` | Vyhledání tabulek/SP/funkcí/triggerů podle filtru |
| `dump-tables --db X --names file.txt --out dir/` | DDL tabulek + indexy + FK |
| `dump-procedures --db X --names file.txt --out dir/` | Definice SP (řeší SSMS truncation streamingem NVARCHAR(MAX)) |
| `discover-from-code --path C:/.../Connector.X --out dir/` | Regex-based extrakce volání SP z C# kódu |
| `snapshot --db X --out dir/` | One-shot tabulky + SP + funkce + triggery + manifest |

## Discovery — pokryté patterny

- `RunSP("name")`, `RunSPWithOutput`, `ExecuteSP`
- `RunSP_Scalar_Guid|Int|Bool|Nullable|String|<jakýkoli suffix>`
- `GetDataSetFromSP`, `GetDataTableFromSP`, `GetDataSet_SP`, `GetDataTable_SP`
- `da.GetDataSet(parameters, "name")` — SP název jako 2. argument
- Generic: `RunSP_Scalar_Nullable<T>("name")`
- FQN: `DB.dbo.name` i `dbo.name` i `name`
- Hranaté závorky: `dbo.[name]` → normalizováno na `dbo.name`

## Connection string konvence

| Priorita | Zdroj |
|---|---|
| 1 | `--connection` CLI argument |
| 2 | env var `DBINTROSPECT__CONNECTIONSTRINGS__DEFAULT` |
| 3 | `appsettings.Local.json` (gitignored) `ConnectionStrings:Default` |
| 4 | `appsettings.json` (committed) `ConnectionStrings:Default` |

`--db` argument vždy přepisuje `Initial Catalog` v CS — jeden CS funguje pro různé DB.

## Známé limity v0.1

- **False positives v discovery** (`the`, `matchSingle`, `GetValueFromUiAdrByKA` aj.) — řešitelné whitelistem v budoucích verzích
- **Snapshot generuje DDL částečně**:
  - `CREATE TABLE` plně executable
  - Indexy a FK jen jako `--` poznámky (ne `CREATE INDEX` / `ALTER TABLE ADD CONSTRAINT`)
- **`appsettings.example.json` má Serilog config sekci**, ale CLI ji nepoužívá — Serilog je nakonfigurován hardcoded v `Program.cs` (Console + File rolling). Sekce v appsettings je placeholder pro budoucí ReadFrom.Configuration

## Build & test

- **Build status (2026-04-28):** ✅ 0 warnings, 0 errors (Release)
- **xUnit testy** (`tests/DbIntrospect.Tests/`): 9/9 zelené (2026-04-28). Pokrývají regex parser pro `discover-from-code` — 1. + 2. argument, generic, hranaté závorky, inline EXEC, bin/obj exclude, line+context recording.
- **Smoke skript** (`tests/smoke.ps1`): orchestruje všech 5 CLI commandů proti DB, ověří exit codes + output counts, generuje `tests/out/<timestamp>/smoke-report.md` (gitignored).
  - Default: `-Db AppDb -ConnectorPath ${PROJECT_ROOT}/Connectors/Connector.SK.FinRed.Dluhy`
- **Historický smoke test discover-from-code (2026-04-27):**
  - RPV: 19 SP, ARES: 44 unikátních SP / 69 volání, SK.Dluhy: 18 SP
- **Historický smoke proti DB (2026-04-27):**
  - find-objects ✅, dump-procedures AppDb_SK 18/18, AppDb_SK_Dluhy 8/18 (10 v AppDb_SK), dump-tables 4/4

## Změnový log CLI

| Datum | Verze | Co se změnilo |
|---|---|---|
| 2026-04-27 | 0.1.0 | Initial — 5 commandů, Docker, discovery rozšířen o `_Bool`, `GetDataSet(params, "name")`, hranaté závorky |
| 2026-04-28 | 0.1.0 (test scaffolding) | Doplněna `tests/` vrstva: xUnit projekt `DbIntrospect.Tests` (9 testů, 0 DB dependencies) + PowerShell `smoke.ps1` (E2E proti DB). `.gitignore` rozšířen o `tests/out/` + `tests/baselines/`. |
