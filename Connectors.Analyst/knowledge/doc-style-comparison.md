---
module: knowledge-doc-style-comparison
version: 2.0.0
requires: []
tags: [knowledge, documentation, best-of]
scope: all
updated: 2026-05-20
---

# Doc-style best-of mapa

Kanonická **struktura** každého doc typu žije v `templates/connector-docs/*.tmpl`. Tento soubor drží jen
**referenční connector** pro každý prvek — odkud vzít vzor, když šablona nestačí. Cíl: při povyšování
standardu vytahovat nejlepší existující řešení, ne vymýšlet nové.

## Doc typy → šablona + referenční vzor

| Doc | Šablona | Nejlepší vzor v connectorech |
|---|---|---|
| README hub | `README.md.tmpl` | ARES `docs-connectors/README.md` — mermaid mapa modulů |
| `analysis.md` | `analysis.md.tmpl` | RPV — čistá struktura Účel→Tech→Config→Architektura→Datové objekty→DB→DataAccess→Enumerace; SK.Dluhy — dual-view (Původní vs. Optimalizovaná, CONN-200); SK.Nespol. — detailní enum tabulky |
| `flow.md` | `flow.md.tmpl` | RPV — Spuštění→smyčka→sub-procesy→state machine→mapování chyb; SK.Dluhy + SK.Nespol. — více variant sekvenčního diagramu, viditelné alternativní režimy (`RunOneTransaction`) |
| `stored-procedures.md` | `stored-procedures.md.tmpl` | ARES — tabulka SP×Třída.Metoda×Cíl DB×Účel×Volá interně; SK.Dluhy — ER diagram per DB, cross-DB zvlášť |
| `database-model.md` | `database-model.md.tmpl` | SbirkaListin — DDL snapshot + datum + zdroj; ARES `db-structures/` — vyčíslené indexy/FK. Generovat z výstupu `dbintrospect snapshot`. |
| `anomalies.md` | `anomalies.md.tmpl` | SK.Nespol. + SbirkaListin — 6+6 anomálií; sloupce ID│Závažnost│Popis│Místo (file:line)│Dopad│Řešení│Status |

## Per-ticket investigation složka

`Ana-CONN-NNN/` (NNN = ID ticketu) — vzor RPV `Docs/Ana-CONN-229/` (`DbScripts/README.md`,
`XmlScripts/README.md`, `XmlSources/`, výsledky). Skeleton: `templates/analysis-folder/Ana-CONN-NNN/`.

## Anti-patterny

- Anomálie utopené v `stored-procedures.md` → migrovat do samostatného `anomalies.md`.
- Manuální SQL skript s SSMS workaroundem (4000 char truncation) → řeší `dbintrospect`.
- Snapshot bez data v záhlaví → nelze ověřit aktuálnost; standard vyžaduje datum + zdroj.
- Chybějící `database-model.md` → žádný kompletní výčet DB objektů.
