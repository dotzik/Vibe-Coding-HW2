---
module: knowledge-shared-libs
version: 1.0.0
requires: []
tags: [knowledge, libs, baseconnector, dbmanager, framework]
scope: all
updated: 2026-04-27
---

# Sdílené knihovny — referenční přehled

Detailní popis vrstev a vzorů použití je v `domains/connector-anatomy.md` a `domains/ado-net-dbmanager.md`. Tento soubor je inventář.

## Lokální Libs (`${PROJECT_ROOT}/Libs`)

### `BaseConnector` (netstandard2.1, v1.2.2.1)
**Cesta:** `${PROJECT_ROOT}/Libs/BaseConnector/`

Abstraktní bázová třída sdílená všemi novými konektory (RPV, SK.FinRed.*, SbirkaListin). ARES je starší — používá vlastní `Connector` v `Downloader.Common`.

Klíčové typy:
- `Connector` (abstract) — orchestrátor běhu connectoru
- `ProcessInstance` — kontext jednoho běhu (start/stop, statistika, logger)
- `Document` — jeden zpracovaný dokument (subjekt/entita)
- `InstanceConfig` — JSON konfigurace per běh
- `Task` lifecycle — `NEW → DOWNLOADED → PARSED → SAVED → DONE / FAILED`

**Závislosti:** `CoreFramework` 2.4.9.1, `DBManager` 2.2.1, `Messaging` 1.1.0, `Microsoft.Extensions.Configuration` 9.0.0-preview.

---

### `DBManager` (netstandard2.0, v2.2.3)
**Cesta:** `${PROJECT_ROOT}/Libs/DBManager/DBManager/`

Tenký ADO.NET wrapper. **Žádný ORM** — pracuje s `DataSet` / `DataTable` / `IDataReader`.

Klíčové typy:
- `DBManager` (entry point) — `new DBManager(connStr, country, project)`
- `DA/CommonDA` (`da` property) — `GetDataSetFromSP(name, params)`, `GetDataTable(...)`, `ExecuteSP(...)`
- `DA/TransactionDA` (`transactionDA` property) — varianty s transakcí
- `DataAccessManager/DBTransactionManager` — wrapper kolem `TransactionScope`
- `DataAccessManager/IDBManager` — interface pro mockování v testech

**Závislost:** `System.Data.SqlClient` 4.8.6 (legacy — nemigrovat bez plánu).

**Vzor volání** (z reálných connectorů):
```csharp
var db = new DBManager.DBManager(connStr, "CZ", "Connectors");
var pars = new Dictionary<string, object> { { "@ic", "12345678" } };
DataSet ds = db.da.GetDataSetFromSP("subjects_GetIdSubjectsByIc", pars);

// nebo s transakcí
db.transactionDA.RunSP("subjekts_CreateNewSubjectByIc", pars, txManager);
```

---

### `Rating` (v1.0.0)
**Cesta:** `${PROJECT_ROOT}/Libs/Rating/`

Skórování / rating. Volaný z connectorů po uložení dat.

---

## Externí (mimo `Libs`, kritické závislosti)

### `CoreFramework` (interní NuGet, v2.4.x)
**Status:** **Black-box** — zdrojáky nejsou v `${PROJECT_ROOT}/Libs`. Nepřístupné z MCP serverů.

Co poskytuje (z analýzy volání):
- Proxy manager (rotace IP pro ARES/Sbírka listin scraping)
- Task distributor (dispatcher tasků mezi vlákny)
- Logger (strukturované logování s úrovněmi)
- Hash helper (deduplikace dokumentů)
- Address parser (rozpad adresy na složky)
- Zip compressor (ukládání originálních XML/PDF do BLOB)

Pokud potřeba prozkoumat chování konkrétní třídy → otevřít konektor, najít volání, dohádat z chování. **Nedoporučovat změny v CoreFramework — není v naší kontrole.**

### `Messaging` (v1.1.0)
Email, logging utility. Závislost `BaseConnector`.

---

## Verze .NET v ekosystému

| Vrstva | .NET |
|---|---|
| `DBManager` | netstandard2.0 |
| `BaseConnector` | netstandard2.1 |
| Konektory ARES (Common, ES, VR, ZM) | net6.0 / net8.0 |
| Konektory ostatní (RPV, SbirkaListin, FinRed.*) | net8.0 |
| `DbRepairUtility.SK.FinRed.Dluhy` | net8.0 |
| `DbIntrospect` (plánovaný) | **net8.0** |

**Implikace:** netstandard knihovny musí zůstat netstandard (kompatibilita dolů). Konzumenti běží na net8.0 default.

---

## Anti-patterny v aktuálním stacku

| Co | Kde | Doporučení |
|---|---|---|
| `System.Data.SqlClient` (nikoliv `Microsoft.Data.SqlClient`) | `DBManager` | Migrovat až bude důvod (např. SQL Server 2022 features). |
| Žádné `Polly` (retry/backoff) | všechny connectory volající API | Při příští dotyku doplnit pro robustnost. |
| Žádné EF/Dapper | (záměr) | **Zachovat** — projekt je explicitně raw ADO.NET + SP. |
| `appsettings.json` v repu s connection stringem | (riziko) | Vždy `appsettings.Local.json` (gitignored) nebo env var. |
