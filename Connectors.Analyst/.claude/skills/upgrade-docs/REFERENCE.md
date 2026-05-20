---
module: domains-documentation-craft
version: 1.0.0
requires: [core/persona]
tags: [domain, documentation, mermaid, anomalies, dual-view, standard]
scope: all
updated: 2026-04-27
---

# Recept na dokumentaci connectoru — best-of standard

Tento dokument je **návod**, jak psát/povyšovat dokumentaci konektoru tak, aby splňovala best-of standard. Pro hotové šablony viz `templates/connector-docs/`.

## Záměr standardu

- **Sjednotit** strukturu napříč 5 živými connectory (ARES, RPV, SbirkaListin, FinRed.Dluhy, FinRed.Nespol.).
- **Doplnit** chybějící artefakty: `database-model.md` (kompletní DB model) a `anomalies.md` (centrální registr ⚠️).
- **Neredestruktivně extend & align** — ne přepsat, ale doplnit.

## 5 (+1) povinných dokumentů per connector

| Dokument | Účel | Šablona |
|---|---|---|
| `README.md` | Index + mermaid mapa komponent + „Where to start" | `templates/connector-docs/README.md.tmpl` |
| `analysis.md` | Účel, tech, architektura, datové objekty, DA vrstva | `analysis.md.tmpl` |
| `flow.md` | Procesní flow (sekvence, flowcharty, state machine) | `flow.md.tmpl` |
| `stored-procedures.md` | SP přehled, ER per DB, parametry | `stored-procedures.md.tmpl` |
| `database-model.md` ✨ | Kompletní DB model (tabulky/SP/funkce/triggery/enum) | `database-model.md.tmpl` |
| `anomalies.md` ✨ | Registr ⚠️ s ID, místem, dopadem, řešením | `anomalies.md.tmpl` |

(✨ nové dokumenty oproti existujícímu stavu)

## Volitelné — per-ticket investigation

```
docs/Ana-CONN-NNN/
├── investigation.md       # Kontext ticketu, hypotéza, závěr
├── DbScripts/             # Reprodukovatelné SQL dotazy
│   ├── README.md          # Co každý skript dělá
│   └── *.sql
├── XmlScripts/            # Python analytické skripty
│   ├── README.md
│   └── *.py
└── XmlSources/            # Vstupní vzorky (XML/HTML/PDF)
```

Vzor: `Connector.CZ.RejstrikPravnichOsob/Docs/Ana-CONN-229/`.

## Pravidla pro mermaid diagramy

| Účel | Diagram | Kde použít |
|---|---|---|
| Architektura, vrstvy, komponenty | `graph TD/LR` | `analysis.md` Architektura |
| Sekvence volání mezi vrstvami | `sequenceDiagram` | `flow.md` Hlavní smyčka |
| Datové objekty, DA třídy | `classDiagram` | `analysis.md` Datové objekty + DA |
| DB schéma | `erDiagram` | `stored-procedures.md` per DB + `database-model.md` |
| Životní cyklus Document/Task | `stateDiagram-v2` | `flow.md` State machine |
| Rozhodovací logika v procesu | `flowchart TD` | `flow.md` Sub-procesy |

**Pravidla obsahu diagramu:**
- Maximálně 15 uzlů per diagram (víc → split do sub-grafů přes `subgraph`).
- Cross-DB references explicit popisem nebo barvou (cílem je, aby reader viděl „toto sahá do jiné DB").
- U `sequenceDiagram` číslovat kroky přes `Note over` pokud je jich víc než 5.

## Pravidla pro anomálie

### Kde anomálie patří
- **Vždy** do `anomalies.md` (nový dokument). Tabulka s ID, závažností, místem, dopadem, řešením, statusem.
- **Také odkaz** v relevantním dokumentu (`stored-procedures.md`, `flow.md`) jako `⚠️ viz anomalies.md#CONN-NNN`.
- **Nepatří** do code commentů (těžko spojit napříč), nepatří do README (přehlcuje).

### Závažnost
| Stupeň | Kdy | Příklad |
|---|---|---|
| 🔴 KRITICKÁ | Ztráta dat, bezpečnostní díra, blokuje produkční běh | SQL injection, mažu data, špatná cílová tabulka v SP |
| 🟠 VYSOKÁ | Špatná data, ale recoverable | `skFinRed_Documents_SetStatus` updatuje špatnou tabulku |
| 🟡 STŘEDNÍ | Inefficiency, dluh | Nepoužité parametry SP, zombie SP, `DateTime.Now` vs `GETDATE()` |
| 🟢 NÍZKÁ | Cosmetic, code smell | Zakomentovaný kód, typo v jméně |

### Status workflow
`open` → `triaged` (rozhodnutí o řešení) → `in-progress` → `fixed` (s odkazem na commit/PR) | `wont-fix` (s odůvodněním)

## Pravidla pro dual-view (refaktoring)

Když dokumentuji refaktoring (vzor: SK.Dluhy CONN-200):

1. **Nemažu starý diagram** — přejmenuji ho na "Architektura — původní (před CONN-NNN)".
2. **Přidávám nový diagram** vedle něj — "Architektura — po optimalizaci (CONN-NNN)".
3. **Přidávám tabulku rozdílů** (co se změnilo, proč, dopad).
4. **Po N měsících** (typicky 6) můžu starý diagram archivovat do `Ana-CONN-NNN/`. Předtím ne.

## Konvence pro reference do kódu

- Vždy `path/to/file.cs:line` (např. `Connector.CZ.SbirkaListin_Archiv/src/.../Parser.cs:142`).
- Cesty relativní od `${PROJECT_ROOT}/Connectors/` (zkracuje a je MCP-friendly).
- Při více řádcích: `file.cs:42-58`.
- Při více souborech ve stejné složce: vyjmenovat za sebou, ne celá složka.

## Konvence pro DB objekty

- Vždy plné jméno: `[AppDb].[dbo].[subjects]` (DB.schema.tabulka).
- Při SP s parametry uvádět typy: `subjekts_CreateNewSubjectByIc(@ic NVARCHAR(20), @id_subject INT OUTPUT)`.
- Cross-DB v textu vyznačovat: „SP volá `[AppDb].[dbo].[subjects_GetByIc]` a updatuje `[AppDb_Documents_AresOr].[dbo].[Documents]`".

## Workflow „povýšit existující dokumentaci"

1. **Diff** existujícího `analysis.md` (`flow.md`, `SP.md`) proti `templates/connector-docs/*.tmpl`.
2. **Vyjmenuj** sekce, které šablona má a dokument ne (= co doplnit).
3. **Vyjmenuj** sekce, které dokument má navíc (= zachovat, případně povýšit standard).
4. **Vygeneruj DDL snapshot** přes `DbIntrospect snapshot` → základ pro nový `database-model.md`.
5. **Migruj anomálie** z roztroušených ⚠️ v textu do nového `anomalies.md`.
6. **Doplň `README.md`** v `docs/` jako index + mermaid mapa komponent.
7. **Pull request** s diffem — uživatel reviewuje, neexistuje silver bullet auto-merge.

## Anti-patterny v dokumentaci

| Anti-pattern | Proč nedělat |
|---|---|
| ASCII art diagramy | Mermaid je dostupný všude, lepší rendering, editovatelný |
| Generické popisy ("metoda dělá to, co má") | Žádná hodnota. Buď konkrétní popis, nebo nic. |
| Outdated diagram bez data poslední aktualizace | Nelze říct, jestli platí. Vždy `updated: YYYY-MM-DD`. |
| Duplikace obsahu napříč dokumenty | Místo toho cross-link s anchor. |
| TODO bez vlastníka a deadline | Buď ticket (`[CONN-NNN]`), nebo nic. |
| Mermaid s 30+ uzly | Nečitelný. Split do sub-grafů. |
