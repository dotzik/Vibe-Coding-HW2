---
name: dbintrospect
description: AI orchestrace nad skriptem `tools/dbintrospect.ps1` (wrapper CLI DbIntrospect — interní nástroj, mimo profil snapshot) — introspekce SP, tabulek a volání z C# kódu. Skript dělá mechaniku (build CLI, spuštění, výstup); skill řeší diff výstupu proti `<connector>/docs/database-model.md` a per-change merge po explicit schválení. Aktivace `/dbintrospect <connector> [--mode <m>]`.
---

# /dbintrospect

**Hybrid skill.** Mechanickou část (build CLI, resolve argumentů, spuštění, relay výstupu)
dělá `tools/dbintrospect.ps1`. Tento skill řeší AI část: interpretaci výstupu, **diff
proti `database-model.md`** a **per-change merge** se schvalováním + log do snapshots.

## Kdy použít

- Příprava / refresh `database-model.md` pro connector (nové SP, nové tabulky).
- Triáž anomálie — porovnat skutečná těla SP s tím, co connector volá.
- Před `/onboard-connector` finalizací — dump DB struktur.

Aktivace: `/dbintrospect <connector> [--mode snapshot|find-objects|dump-procedures|dump-tables|discover-from-code] [--db <name>]`.

## Workflow

1. **Spusť skript** — mapuj vstupy uživatele na parametry `tools/dbintrospect.ps1`:

   ```
   pwsh tools/dbintrospect.ps1 -Mode <mode> [-Database <db>] [-Connector <conn>] `
        [-Like <pattern>] [-Names <file>] [-Path <dir>] [-Out <dir>]
   ```

   - `-Database` je povinné pro všechny módy **kromě** `discover-from-code`.
   - `discover-from-code` resolve `--path` z `-Connector` (skript), nebo zadej `-Path`.
   - Skript zajistí build CLI, default `-Out` (gitignored `tools/DbIntrospect/out/... (gitignored)`),
     vrátí exit code (0 OK / 1 MISSING / 2 chyba) a vypíše cestu k výstupu.

2. **Načti výstup** z `-Out` adresáře:
   - `snapshot` → `manifest.md` (counts, datum, verze CLI) + `tables/` `procedures/` `functions/` `triggers/`.
   - `discover-from-code` → `sp-names.txt` + `sp-discovery.md` (počet unikátních SP, volání).
   - `dump-*` → soubory `*.sql`.
   - **MISSING objekty** (`_MISSING_*.md`) — vždy uveď v reportu, nikdy tichá ztráta.

3. **Diff proti `<connector>/docs/database-model.md`** (jen `snapshot`):
   - Načti existující `database-model.md` (pokud je).
   - Identifikuj: nové / smazané SP, nové / smazané tabulky, high-level změny sloupců.
   - Předlož kompaktní tabulku diffu.

4. **Per-change merge do `database-model.md`**:
   - **NEpřepisuj** celý soubor. Per jednotlivá změna vyžádej `schvaluji`
     ([`feedback_approval_first`](../../memory/feedback_approval_first.md)).
   - Striktně **1 `Edit` per message** (viditelnost změny).
   - Číselné enumerace CLI nezná — význam doplň ručně.

5. **Append do `state/snapshots-log.md`** (po `snapshot`):

   ```markdown
   ## YYYY-MM-DD HH:mm — <connector> (snapshot, db=<db>)

   **CLI verze:** <z manifest.md>
   **Counts:** tabulek N / SP M / funkcí K / triggerů L
   **MISSING:** seznam (nebo —)
   **Output:** <out-path>
   **Operátor:** /dbintrospect
   ```

6. **Souhrn** — 5-10 řádek + návrh dalšího kroku (typicky `/upgrade-docs <connector>`).

## Gates

- **Žádný DB write** — CLI je read-only; skript ani skill nezapisují do DB.
- **Edit `database-model.md`** striktně per-change po explicit `schvaluji`.
- **Žádný `Edit` paralelně** v rámci merge — 1 změna per message.
- **Žádný auto-commit / push.**

## Notes

- **Connection string** řeší CLI sám (`-Connection` > env var `DBINTROSPECT__CONNECTIONSTRINGS__DEFAULT`
  > `appsettings.Local.json` > `appsettings.json`). Detaily: `REFERENCE.md`.
- **False positives v `discover-from-code`** — známý limit; finding neoznačuj jako „dead SP"
  bez cross-checku (`find-objects` nebo manuální grep DB).
- **Cílové umístění snapshotu** — skript ukládá do gitignored `out/`; finální snapshoty
  připoj do `<connector>/docs/snapshots/<datum>/` při merge (rozhodnutí AI).
- **DB modeling konvence** (pojmenování, soft-delete, audit sloupce, cross-DB vzory) — `REFERENCE.md`.

## Návaznosti

- **Před:** typicky `/onboard-connector` nebo příprava `/upgrade-docs`.
- **Po:** `/upgrade-docs <connector>` (sekce `database-model.md`) nebo přímý edit.
