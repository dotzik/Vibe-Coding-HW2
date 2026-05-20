---
module: knowledge-connectors-inventory
version: 1.1.0
requires: []
tags: [knowledge, inventory, connectors, libs, always-active]
scope: all
updated: 2026-05-20
---

# Inventář — Connectors a Libs

Stav k 2026-05-20. Pro povýšení dokumentace zvažuj sloupec **Stav docs** a **Charakteristika** — určují prioritu a styl práce.

Standardní sada docs = 6 dokumentů: `README.md` · `analysis.md` · `flow.md` · `stored-procedures.md` · `database-model.md` · `anomalies.md` (šablony `templates/connector-docs/*.tmpl`). Sloupec **Stav docs** udává reálný počet `n/6`.

## Connectors (`${PROJECT_ROOT}/Connectors`)

| # | Projekt | .NET | Zdroj dat | Stav docs | Charakteristika |
|---|---|---|---|---|---|
| 1 | `Connector.Ares.API` | net6.0 / net8.0 | ARES (ES, VR, ZM, OrJustice) | ✅ **best** — `docs-connectors/` hub + per-modul `docs/` (analysis/flow/SP) + `db-structures/` | Nestandardní multi-modul layout; centrální README s mermaid mapou, ER topologie, DDL snapshoty, SP tabulka. Některé moduly (Common, OrJustice.Scraper) mají jen analysis+flow. |
| 2 | `Connector.CZ.ESIF` | net8.0 | dotaceeu.cz — příjemci dotací EU 2021–2027 | ✅ **6/6** + `docs/db-structures/` | Task-based, režimy DOWNLOAD_LATEST / MISSING / FROM_DATE / FROM_FILE, single/multi-thread. Cíl DB `AppDb_ThirdParty`. |
| 3 | `Connector.CZ.IsRed` | net8.0 | data.gov.cz — registr (IsRed) | ❌ **0/6** — prázdný `Docs/` | Stahuje seznam PO; proxy + paralelní zpracování. Cíl DB `AppDb`. Kandidát na onboarding docs. |
| 4 | `Connector.CZ.RejstrikPravnichOsob` | net8.0 | RPV (XML feed) | ⚠️ **3/6** (analysis, flow, stored-procedures) + `Ana-CONN-229/` — chybí README, database-model, anomalies | Per-ticket analytická složka (`Ana-CONN-229/`), čistý template, žádné anomálie |
| 5 | `Connector.CZ.SbirkaListin` | net8.0 | or.justice.cz (HTML scraping) — metadata listin | ✅ **6/6** | Sourozenec k SL_Archiv. Stahuje jen tabulku přehled listin, PDF nestahuje. 11 anomálií. Křehký HTML→XML parsing. |
| 6 | `Connector.CZ.SbirkaListin_Archiv` | net8.0 | or.justice.cz (HTML+PDF) — přílohy | ⚠️ **4/6** (README, analysis, flow, stored-procedures) — chybí database-model, anomalies; `db-structures/` prázdný | Stahuje vlastní PDF přílohy listin. Introspekční SQL pattern. |
| 7 | `Connector.CZ.SbirkaListin_UZ_SpravceDane` | net8.0 | or.justice.cz — úřední záznamy / správce daně | ❌ **0/6** — bez docs adresáře | Třetí člen SL rodiny — UZ příznak (správce daně). 2 DA třídy, 7 SQL souborů. Kandidát na povýšení dle SL standardu. |
| 8 | `Connector.SK.FinRed.Dluhy` | net8.0 | Finančná správa SK (XML+PDF) | ⚠️ **5/6** (analysis, flow, stored-procedures, database-model, anomalies) — chybí README | Dual architektura (Původní vs. Optimalizovaná, CONN-200) + samostatný `DbRepairUtility.SK.FinRed.Dluhy`. |
| 9 | `Connector.SK.FinRed.NespolehlivyPlatce` | net8.0 | Finančná správa SK (DPH) | ⚠️ **3/6** (analysis, flow, stored-procedures) — chybí README, database-model, anomalies | 6 anomálií (stále v `stored-procedures.md`), cross-DB topologie (3 DB), `RunOneTransaction` alternativní režim. |
| 10 | `Connector.SK.Rzp` | net8.0 | SK registr právnických osôb (RZP) | ❌ **0/6** — prázdný `docs/` | Stahuje/aktualizuje info o PO; proxy + task manager. Cíl DB `AppDb_SK`. Kandidát na onboarding docs. |
| 11 | `Connector.SK.SocPoj` | net8.0 | SK Sociálna poisťovňa | ❌ **0/6** — bez docs adresáře | Download (TMP→MAIN) + `RunBussInfoRefresh`; proxy + multi-thread. Cíl DB `AppDb_SK`. Kandidát na onboarding docs. |
| 12 | `Connector.SK.SUSRRPO` | net8.0 | SÚSR RPO — denní dávky (api.statistics.sk) | ✅ **6/6** + `Ana-CONN-222/` | Daily batch model; raw JSON + task fronta. ⚠️ CONN-222: od 2026-03-23 neprodukuje (gap-intolerance, 13 anomálií). Cíl DB `AppDb_SK_ThirdParty`, `AppDb_SK`. |

**Závěr:** ze 12 živých connectorů má **4** kompletní docs (ARES — speciální hub layout, ESIF, SbirkaListin, SUSRRPO), **4** částečné (RPO, SbirkaListin_Archiv, SK.FinRed.Dluhy, SK.FinRed.NespolehlivyPlatce — chybí 1–3 dokumenty) a **4** bez docs (IsRed, SbirkaListin_UZ_SpravceDane, SK.Rzp, SK.SocPoj). Úkol: **dodělat** částečné na 6/6 (extend & align, nepřepisovat) a **onboardovat** chybějící.

> **Pozn. k charakteristikám 4 nových connectorů** (`ESIF`, `IsRed`, `Rzp`, `SocPoj`): odvozeny z code-skim, ne z plného doc-survey — zdroj dat a cílové DB jsou předběžné, ověřit při onboardingu docs. (`SUSRRPO` má od 2026-05-20 plnou dokumentaci 6/6.)

**Pozn. k dvojici SL connectorů:** `SbirkaListin` (zdrojDat = SL) a `SbirkaListin_Archiv` (zdrojDat = SL_Archiv = 50) jsou **dva odlišné connectory**, ne refaktor. SL stahuje metadata (tabulku „Přehled listin"), zjišťuje, kterým listinám chybí PDF v archivu, a přes `TaskManager.InsertOrActivateTask` zakládá tasky pro SL_Archiv, který stahuje vlastní PDF. `SbirkaListin_UZ_SpravceDane` je třetí člen rodiny (úřední záznamy / správce daně).

**Pozn. k `.Original` archivům:** dřívější `*.Original` snapshoty (`RejstrikPravnichOsob.Original`, `FinRed.Dluhy.Original`) už v adresáři `Connectors/` nejsou — z inventáře odstraněny.

---

## Libs (`${PROJECT_ROOT}/Libs`)

| Projekt | .NET | Verze | Účel |
|---|---|---|---|
| `BaseConnector` | netstandard2.1 | 1.2.2.1 | Abstraktní bázová třída pro všechny connectory (`Connector`, `ProcessInstance`, `Document`, `InstanceConfig`) |
| `DBManager` | netstandard2.0 | 2.2.3 | ADO.NET wrapper — `da.GetDataSetFromSP()`, `transactionDA.RunSP()`, `DBTransactionManager` |
| `Rating` | — | 1.0.0 | Rating / skórování |

**Externí (mimo Libs adresář, ale klíčové):**
- `CoreFramework` 2.4.x — interní NuGet, černá skříňka. Obsahuje proxy manager, task distributor, logger, hash helper, address parser, zip compressor.
- `Messaging` 1.1.0 — email, logging utility (závislost `BaseConnector`).

---

## Pomocné nástroje

| Nástroj | Lokace | Stav |
|---|---|---|
| `DbRepairUtility.SK.FinRed.Dluhy` | `Connectors/Connector.SK.FinRed.Dluhy/src/DbRepairUtility.SK.FinRed.Dluhy/` | ✅ existuje. Pipeline Fetch→Parse→Pair→Save, DryRun, Docker. Inspirace pro `DbIntrospect`. |
| `DbIntrospect` | interní C# CLI (mimo tento profil snapshot) | Generická DB introspekce (SP / tabulky / volání z C#); profil obsahuje jen orchestrační vrstvu — wrapper `tools/dbintrospect.ps1` + skill `dbintrospect`. |

---

## Cross-cutting témata k řešení

1. **`database-model.md`** — existuje u 4 connectorů (ESIF, SbirkaListin, SK.FinRed.Dluhy, SUSRRPO). Chybí u zbytku, kde už docs jsou (RPO, SbirkaListin_Archiv, SK.FinRed.NespolehlivyPlatce). Generovat z výstupu `dbintrospect snapshot`.
2. **`anomalies.md`** — samostatný dokument existuje u ESIF, SbirkaListin, SK.FinRed.Dluhy, SUSRRPO. SK.FinRed.NespolehlivyPlatce má 6 anomálií stále utopených v `stored-procedures.md` — migrovat do samostatného `anomalies.md` (anti-pattern dle `doc-style-comparison.md`).
3. **Snapshoty DDL** — strukturované `db-structures/` má ARES a ESIF; SbirkaListin_Archiv má adresář `db-structures/` prázdný. CLI `DbIntrospect` to zobecní.
4. **Per-ticket investigation** — `Ana-CONN-NNN/` má RPO (`Ana-CONN-229/`) a SUSRRPO (`Ana-CONN-222/`). Standard ji povyšuje na konvenci (skill `start-ticket`).
5. **4 connectory bez docs** (IsRed, SbirkaListin_UZ_SpravceDane, SK.Rzp, SK.SocPoj) — kandidáti na `onboard-connector` (scaffold 6 šablon) + naplnění.
