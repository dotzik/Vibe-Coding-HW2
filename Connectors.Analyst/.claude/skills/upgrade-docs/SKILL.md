---
name: upgrade-docs
description: Povýšení dokumentace zadaného connectoru na standard. Konzumuje doc-validator report a templates/connector-docs/*.tmpl. Po validaci uživatel schvaluje navrhované změny per dokument.
---

# /upgrade-docs

Skill orchestruje povýšení dokumentace jednoho connectoru na sjednocený standard. Stojí na subagentovi `doc-validator` (cross-validace) a šablonách v `templates/connector-docs/`.

## Kdy použít

- Po větším zásahu do kódu connectoru (refactor, nové SP, změna lifecycle).
- Při onboardingu nového vývojáře na connector.
- Periodicky před release.

Aktivace: `/upgrade-docs <connector>` nebo automaticky při frázích typu „povyš docs pro X", „dotáhni dokumentaci connectoru X na standard".

## Vstupy

- **`<connector>`** (povinné) — název adresáře v `${PROJECT_ROOT}/Connectors/` (např. `SK.NespolehlivyPlatce`, `RejstrikPravnichOsob`, `Ares`).
- **`--only <doc>`** (volitelné) — omezení na jeden dokument: `analysis | flow | sp | db | anomalies`. Pro inkrementální upgrade.

## Workflow

1. **Validace vstupu** — ověřit existenci `Connectors/<connector>/`. Pokud chybí `docs/` adresář → navrhnout spuštění `/onboard-connector` (Phase 4) a ukončit.
2. **Spustit `doc-validator`** přes `Agent` tool s `subagent_type: doc-validator` a promptem `--connector <connector>`. Výstup = markdown report (Missing / Stale / Mismatched / Style deviations).
3. **Předložit report** ke kontrole bez úprav.
4. **Per dokument navrhnout konkrétní změny** jako diff/preview — strategie viz „Dual-view povýšení" níže.
5. **Vyžádat schválení per dokument** (žádný batch). Při požadavku na úpravu → revize a opakovaný preview.
6. **Aplikovat schválené změny** přes `Edit` nebo `mcp__connectors__edit_file`. Při větším přepisu `Write` (vždy předchozí `Read`).
7. **Update changelog** — buď `<connector>/docs/CHANGELOG.md` (pokud existuje), nebo položka do sekce „Changelog" na konci `analysis.md`. Konvence není napevno daná — rozhodnout per connector.
8. **Závěrečný souhrn** — které dokumenty byly povýšeny, kolik findingů z reportu zůstává otevřených (typicky `Style deviations` low-prio se odkládají na další iteraci).

## Dual-view povýšení

Princip: **nezahazovat unikátní obsah**, dotahovat na šablonu aditivně.

- Načíst aktuální doc + příslušnou šablonu z `templates/connector-docs/<doc>.md.tmpl`.
- Zachovat původní strukturu nadpisů, pokud se neliší od šablony zásadně.
- **Chybějící sekce přidat**, nikoliv přepsat existující obsah.
- Při zásadní rozdílnosti (např. starý `flow.md` má vlastní mermaid, šablona má jiný styl) → nabídnout vedle sebe „původní" + „nová" verzi v jednom dokumentu (sekce `## Původní lifecycle (před povýšením)` + `## Lifecycle (standard 2026-05)`); smazání staré verze ponechat na následném schválení.
- **Formální 3. osoba, pasivní rod, bez jmen osob a konverzačních linek.** Detail v `.claude/memory/feedback_no_personification.md`.

## Šablony

Reference (NE copy) — jediný source of truth v `templates/connector-docs/`:

- `analysis.md.tmpl`
- `flow.md.tmpl`
- `stored-procedures.md.tmpl`
- `database-model.md.tmpl`
- `anomalies.md.tmpl`
- `README.md.tmpl` (pokud `<connector>/docs/README.md` chybí)

Změna šablony → editace v `templates/connector-docs/`, ne ve skill folderu. Pokud by skill v budoucnu potřeboval skill-specific tweak, vznikne `skills/upgrade-docs/templates/<doc>.md.tmpl` jako override; aktuálně neexistuje a není potřeba.

## Gates

- **Per-dokument schválení uživatelem před zápisem.** Žádný auto-apply. Detail v `.claude/memory/feedback_approval_first.md`.
- Před každou změnou ukázat:
  - cestu k souboru,
  - rozsah (přidání sekce / přepis sekce / dual-view),
  - mini-preview prvních ~10 řádků nového obsahu,
  - explicitní otázku „zapsat?".
- Pokud uživatel řekne „přepiš jinak" → revize, opakovat preview cyklus.

## Výstupní artefakty

- Upravené `.md` v `<connector>/docs/`.
- Případný changelog update.
- Finální souhrnný post v terminálu (ne markdown soubor).

## Návaznosti

- `/cross-consistency-check` doporučit po dokončení, pokud bylo v session povýšeno více connectorů.
- `/anomaly-report` (Phase 3) navázat, pokud doc-validator nahlásil nezdokumentované anomálie v kódu (`⚠️`, `TODO`, `FIXME` bez vazby na `anomalies.md`).
