---
name: refactor-proposal
description: Kategorizovaný návrh refactoringu (kosmetic / structural / breaking) s per-bucket gates. Generuje proposal dokument, postupně provádí změny po schvalování. Volá Edit per change (structural+breaking), kosmetic možno batch v 1 message.
---

# /refactor-proposal

Skill orchestruje refactoring s **3-úrovňovými gates**: kosmetic (1 batch souhlas), structural (per-change before/after diff + souhlas), breaking (impact assessment + explicit „schvaluji breaking X" per položku). Generuje `refactor-proposal-<topic>-<DATE>.md` jako tracking dokument.

## Kdy použít

- Před větším zásahem do `*.cs` v connector / Libs / CoreFramework.
- Po `dead-code-hunter` / `bug-hunter` reportu, který chce realizovat.
- Při žádosti uživatele „refaktoruj X", „rozděl Y na menší třídy", „přejmenuj Z všude".

Aktivace: `/refactor-proposal <topic> [...args]` nebo automaticky při „refaktoruj", „extract", „rename napříč".

## Vstupy

- **`<topic>`** (povinné) — krátký popis cíle, např. `extract-IRedSubjectChecker`, `rename-_db-to-_dbManager`, `split-ProcessSectionMethods`.
- **`--ticket <CONN-NNN>`** (volitelné) — umístění proposalu do `${PROJECT_ROOT}/Tickets/<CONN-NNN>/Plans/`. Bez tiketu → `Tickets/_drafts/` (vytvořit lazy).
- **`--scope <path>`** (volitelné) — omezení analýzy na zadaný adresář / soubor. Default = celý connector pokud topic obsahuje název connectoru, jinak vyžádat.

## Workflow

1. **Analyzovat current state** — `Read` dotčených souborů. Volitelně spustit `bug-hunter` / `perf-hunter` na `--scope` pro upstream nálezy (před souhlasem uživatele).
2. **Vygenerovat proposal dokument** z `templates/proposal.md.tmpl` (uvnitř skill folderu) — 3 sekce, bez nálezů → sekce vynechána:
   - **Kosmetic** — rename, formatting, comment cleanup, dead-code removal (low risk).
   - **Structural** — extract method/class, move type, refactor signature uvnitř modulu.
   - **Breaking** — public API change, signature change v Libs/CoreFramework, change SP signatury, change DB schema.
3. **Per sekce vyplnit tabulku změn**: `path:line | change | reason | risk-note`.
4. **Pro breaking sekci** — `impact assessment`: cross-grep callerů napříč `Connectors/` + `Libs/`. Vypsat všechny dotčené místa s `path:line`.
5. **Uložit proposal** — `Write` do `Tickets/<ticket-or-drafts>/Plans/refactor-proposal-<topic>-<YYYY-MM-DD>.md`. Předem ukázat preview + souhlas.
6. **Aplikace dle bucketu** (postupně, sekce po sekci):
   - **Kosmetic** — předložit kompletní seznam položek + požádat o **1 batch souhlas** („schvaluji všechny kosmetic"). Po souhlasu možno aplikovat všechny Edits v 1 message paralelně. Lze i per-položku, pokud o to uživatel požádá.
   - **Structural** — per-change: ukázat **before/after diff** (3-5 řádků kontextu před a po), vysvětlit, požádat o souhlas. Aplikovat Edit. Pak další položka. **Žádný batch.**
   - **Breaking** — per-change: zopakovat **impact assessment** (callers v dotčeném scope), explicit požadavek `schvaluji breaking <change>`. Aplikovat Edit + immediate verify (nový `Read` všech callerů — kompiluje?). Pokud break v Libs → po každé breaking změně doporučit build connectoru, který Libs konzumuje.
7. **Update proposal dokumentu** — per aplikovanou změnu doplnit status `✅ applied` + commit hash (po commitu).
8. **Závěrečný souhrn** — počet aplikovaných změn per bucket, doporučení commit message (strukturovaná, viz „Commit konvence").

## Šablona proposal dokumentu

Viz `templates/proposal.md.tmpl` v tomto skill folderu. Sekce:
- Metadata (topic, ticket, datum, scope)
- Východisko (current state, motivace)
- Plán změn (3 sekce: Kosmetic / Structural / Breaking — bez nálezů vynechat)
- Impact assessment (pro breaking)
- Aplikace (post-implementační log per change)
- Rizika & rollback plán

## Gates

| Bucket | Gate | Aplikace |
|---|---|---|
| Kosmetic | 1 batch souhlas pro celou sekci („schvaluji všechny kosmetic") | Paralel Edit v 1 message povolen |
| Structural | Per-change before/after diff + per-change souhlas | Strictly 1 Edit per message |
| Breaking | Per-change impact assessment + explicit `schvaluji breaking <change>` | 1 Edit per message + verify build |

**Žádný auto-apply.** Žádný batch ve structural/breaking. Detail v [`feedback_approval_first`](../../memory/feedback_approval_first.md).

## Commit konvence

Po dokončení (nebo per bucket) navrhnout commit message:

```
refactor(<scope>): <topic short>

<bucket souhrn>:
- Kosmetic: <N> changes (rename _db → _dbManager v Ares)
- Structural: <N> changes (extract IRedSubjectChecker)
- Breaking: <N> changes (BaseConnector.DoWork signature: …)

Refs: <CONN-NNN> (ticket), proposal: Tickets/<...>/Plans/refactor-proposal-<topic>-<DATE>.md
```

**NEpřidávat `Co-Authored-By: Claude ...`** — viz [`feedback_no_claude_attribution`](../../memory/feedback_no_claude_attribution.md).

## Výstupní artefakty

- `Tickets/<ticket-or-drafts>/Plans/refactor-proposal-<topic>-<YYYY-MM-DD>.md` — tracking dokument.
- Edit `.cs` souborů per schválené položky.
- Návrh commit message (terminál, ne write).

## Návaznosti

- **Před:** `dead-code-hunter` / `bug-hunter` / `perf-hunter` reports (Phase 2) jako vstup.
- **Po:** `/jira-from-context --from refactor --source <proposal-path>` (Phase 3) — pokud refactor zaslouží Jira ticket.

## Rizika

- **Breaking změny v Libs** propagují do všech connectorů → vždy explicit impact assessment + verify build minimálně 1 konzumujícího connectoru.
- **Cross-grep falešně negativní** — DI registrace, reflexe, dynamic SP volání nemusí být v grepu vidět → u breaking přidat poznámku „verifikováno jen statickým grep, dynamic patterns mimo scope".
