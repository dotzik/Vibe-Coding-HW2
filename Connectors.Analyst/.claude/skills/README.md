# Skills

Adresář specializovaných workflow-skills profilu `Connectors.Analyst`. Anglické kebab-case názvy, český obsah (viz [`feedback_skill_naming`](../memory/feedback_skill_naming.md)).

**Vyvolání:** `/<name>` v promptu, nebo automaticky, když je v promptu fráze z `description:` v SKILL.md frontmatteru.

## Registr — 7 workflow-skills

| Skill | K čemu |
|---|---|
| `upgrade-docs` | Povýšení dokumentace zadaného connectoru na standard |
| `cross-consistency-check` | Audit sjednoceného stylu docs napříč dostupnými connectory |
| `anomaly-report` | Formátování ⚠️ nálezu do `<connector>/docs/anomalies.md` + draft Jira |
| `refactor-proposal` | Kategorizace kosmetic / structural / breaking + per-bucket gates |
| `jira-from-context` | Z `investigation.md` / anomaly / refactor → Jira issue přes `jira` MCP |
| `standup-prep` | Yesterday / Today / Blockers z git log + Jira |
| `worklog` | Vykázání času z chatu → per-položku Jira worklog (NIKDY kombinovaný) |

## HYBRID skilly — tenká AI vrstva nad `tools/*.ps1`

Mechaniku dělá skript, skill řeší AI orchestraci. Detail skriptů: [`../../docs/skills-and-tools.md`](../../docs/skills-and-tools.md).

| Skill | Skript | AI část |
|---|---|---|
| `start-ticket` | `tools/start-ticket.ps1` | Jira pull + prefill `investigation.md` |
| `dbintrospect` | `tools/dbintrospect.ps1` | Diff introspekce proti `database-model.md` |
| `onboard-connector` | `tools/onboard-connector.ps1` | Registr + zápis do `connectors-inventory.md` |

> **Skript místo skillu:** `run-conn-tests` byl převeden na plně autonomní skript
> `tools/run-conn-tests.ps1` (build + smoke + parse, bez AI orchestrace).

## Struktura skill folderu

```
<name>/
├── SKILL.md              # povinné — frontmatter + Kdy použít / Vstupy / Workflow / Výstup / Šablona / Gates
├── REFERENCE.md          # volitelné — doménová znalost (např. migrovaná z domains/)
└── templates/            # volitelné — šablony výstupních artefaktů
    └── <artifact>.md.tmpl
```
