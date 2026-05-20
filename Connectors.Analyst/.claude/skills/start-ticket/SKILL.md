---
name: start-ticket
description: AI orchestrace nad skriptem `tools/start-ticket.ps1` — založení per-ticket analytické složky `<connector>/.../docs/Ana-<CONN-NNN>/` (3 šablony, do git connectoru) + pracovní `Tickets/<CONN-NNN>/`. Skript dělá scaffold; skill přidá Jira pull a prefill hlavičky `investigation.md`. Aktivace `/start-ticket <CONN-NNN> <connector>`.
---

# /start-ticket

**Hybrid skill.** Mechaniku (validace ticketu, render šablon, scratch složka)
dělá `tools/start-ticket.ps1`. Tento skill řeší AI část: **Jira pull** přes
`jira` MCP a **prefill hlavičky `investigation.md`** z Jira fieldů.

## Kdy použít

- Začátek práce na ticketu — uživatel řekne „pojďme začít CONN-NNN", „start ticket",
  „založ ticket".
- Migrace staršího ticketu, ke kterému dosud nevznikla `Ana-` složka.

Aktivace: `/start-ticket <CONN-NNN> <connector> [--no-jira]`.

## Workflow

1. **Spusť skript** — scaffold analytické složky + scratch:

   ```
   pwsh tools/start-ticket.ps1 -Ticket <CONN-NNN> -Connector <connector> [-Force]
   ```

   - Vytvoří `<connector>/.../docs/Ana-<CONN-NNN>/` (`investigation.md` +
     `DbScripts/` + `XmlScripts/`) a `$PROJECT_ROOT/Tickets/<CONN-NNN>/` (scratch).
   - `{{[CONN-NNN]}}` skript dosadí. Existující soubory nepřepisuje;
     pro doplnění do existující složky předej `-Force`.
   - Neplatný ticket key / nejednoznačný connector → skript skončí chybou.
     Vrať ji uživateli, neproceeduj.

2. **Jira pull** (přeskoč při `--no-jira`):
   - `mcp__jira__jira_get_issue`, `issue_key=<CONN-NNN>`,
     `fields=summary,status,priority,labels,issuetype,assignee,reporter,created`.
   - Graceful fallback: issue neexistuje / Jira nedostupná → warning,
     hlavičku ponech s placeholdery.

3. **Prefill hlavičky `investigation.md`** — `Edit` do
   `Ana-<CONN-NNN>/investigation.md`, sekce „Kontext ticketu":

   | Pole hlavičky | Zdroj |
   |---|---|
   | `Title` | `fields.summary` |
   | `Reportér` | `fields.reporter.displayName` + datum z `fields.created` |
   | `Vlastník investigation` | `fields.assignee.displayName` (nebo „nepřiřazeno") |
   | `Datum zahájení` | dnešní datum |

   Dále první řádek `## Časová osa` → `| <dnes> | Investigation zahájena |`.
   Ostatní `{{...}}` (Problém, kroky, zbytek timeline) zůstávají k ručnímu doplnění.

4. **Souhrn uživateli** — cesta k `Ana-` složce + scratch, co vyplněno z Jiry
   vs. placeholder, návrh „začni sekcí Problém / hypotéza".

## Gates

- **Žádný Jira write** — pouze `jira_get_issue` (read).
- **Scaffold bez schválení** — vratná, low-risk operace (prázdné šablony
  v dedikované složce). Existující složka: doplnění jen s `-Force`
  ([`feedback_approval_first`](../../memory/feedback_approval_first.md)).
- **Edit `investigation.md`** jen hlavička — žádný personifikovaný obsah,
  3. osoba pasivně ([`feedback_no_personification`](../../memory/feedback_no_personification.md)).

## Notes

- **`Ana-<CONN-NNN>/`** jde do gitu connectoru (analytický artefakt). Vzor:
  `Connector.CZ.RejstrikPravnichOsob/.../Docs/Ana-CONN-229/`,
  `Connector.CZ.SbirkaListin_Archiv/.../docs/Ana-CONN-237/`.
- **`Tickets/<CONN-NNN>/`** je pracovní scratch (data, mezivýstupy) — mimo git
  connectoru, není analytický artefakt.
- Sprint custom field se v hlavičce nemapuje — šablona pole Sprint nemá.
  Pokud je potřeba, doplň ručně.

## Návaznosti

- **Po:** psaní investigation, případně `/dbintrospect <connector>` pro DB část.
- **Volitelně:** `/anomaly-report` (ticket z anomálie), `/jira-from-context`
  (z investigation roste více sub-issues).
