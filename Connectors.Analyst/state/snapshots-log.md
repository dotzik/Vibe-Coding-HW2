---
module: state-snapshots-log
version: 1.0.0
tags: [state, snapshots, history]
scope: all
updated: 2026-04-27
---

# Log proběhlých DB snapshotů

> Append-only log. Nemažem starší záznamy — slouží jako historický kontext „co kdy jsme zjistili".

---

## 2026-04-27 — SK.FinRed.Dluhy (první produkční snapshot CLI)

**DB:** `AppDb_SK_Dluhy` + `AppDb_SK`
**CLI verze:** 0.1.0
**Output:** `<connector-repo>/Connector.SK.FinRed.Dluhy/src/Connector.SK.FinRed.Dluhy/docs/snapshots/2026-04-27/`

**Výsledky:**
- Discovery z C#: 18 unikátních SP, 19 volání (sedí s existujícím `stored-procedures.md` → validace)
- AppDb_SK_Dluhy: 4 tabulky (skFinRed_Documents, skFinRed_Documents_ImportErrors, drPO_records, drFO_records) + 8 SP (7 skFinRed_* + 1 wrapper appEntity_Dictionary_Jmena_GET)
- AppDb_SK: všech 18 SP (vč. duplicitních `skFinRed_*`)

**Klíčové architektonické zjištění:**
- Connector používá **2 connection strings** — `ConnectionString` (AppDb_SK_Dluhy zápisová) + `AppDbConnectionString` (AppDb_SK lookup + cross-DB SP)
- SP v AppDb_SK přímo updatují `[AppDb_SK_Dluhy].dbo.*` tabulky (FQN v těle SP) — `skFinRed_Documents_Insert`, `skFinRed_SetDatumDo` aj.
- `appEntity_BussinessInfo` historizace probíhá přes trigger v AppDb_SK
- Žádné MSDTC, integrita per-DB transakce + aplikační logika

**Nová dokumentace vytvořena:**
- `Connector.SK.FinRed.Dluhy/.../docs/database-model.md` — kompletní DB model
- `Connector.SK.FinRed.Dluhy/.../docs/anomalies.md` — 7 anomálií

**7 objevených anomálií (registr v `docs/anomalies.md`):**
1. **[ANOM-001] 🟡** Duplicitní `skFinRed_*` SP v obou DB (7 SP) — connector volá AppDb_SK_Dluhy verze, AppDb_SK je dead code
2. **[ANOM-002] 🟢** FK pojmenovány `*_TEST` (`FK_skFinRed_Documents_drPO_records_TEST`)
3. **[ANOM-003] 🟡** `documentData IMAGE` deprecated → migrovat na `VARBINARY(MAX)`
4. **[ANOM-004] 🟢 triaged** Záložní tabulky `*_OldCorruptedBackup` z CONN-200 fix encoding bugu, kandidáti smazání po 2026-09-29
5. **[ANOM-005] 🟡** Wrapper proxy `appEntity_Dictionary_Jmena_GET` v AppDb_SK_Dluhy — inkonzistence (ostatní appEntity_* wrapper nemají)
6. **[ANOM-006] 🟢** SSMS placeholder `<Author,,Name>` v hlavičkách SP
7. **[ANOM-007] 🟡 wont-fix** Velké zakomentované bloky v `skFinRed_SetDatumDo` z 2019-10-15 fix — zachovány jako historický kontext

**Oprávky CLI během snapshotu:**
- Rozšířen regex extractoru o `RunSP_Scalar_Bool`, `da.GetDataSet(parameters, "name")` (2-arg pattern), hranaté závorky `[name]`
- Discovery vyrostlo z 12 na 18 SP (kompletní pokrytí)
- Opraveny placeholder mismatchy v Serilog log messages

**How to apply:** SK.FinRed.Dluhy je **best-reference pro cross-DB pattern** v ekosystému. Při dokumentaci jiných SK connectorů (NespolehlivyPlatce, FinRed.* sourozenci v AppDb_SK) hledat stejný 2-CS pattern.

---

## 2026-05-20 02:08 — Connector.Ares.API (Dev, Release)

**Build:** ✅ (warnings: 196, errors: 0)
**Run:** — (přeskočeno, -NoRun)
**Counts:** —
**Top findings:**
- —

**Command:** `—`
**Operátor:** tools/run-conn-tests.ps1

---

<!-- Další záznamy připisuj sem -->
