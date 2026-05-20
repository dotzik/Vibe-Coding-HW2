---
name: jira-from-context
description: Z analytického kontextu (investigation.md / anomaly entry / refactor proposal) složí Jira issue body podle projektových konvencí. Předloží draft ke schválení. Po explicit "založ Jira" volá mcp__jira__jira_create_issue.
---

# /jira-from-context

Skill převádí lokální dokumentový kontext (`investigation.md`, anomaly entry v `<connector>/docs/anomalies.md`, refactor proposal) na strukturované Jira issue body. **Žádný write bez explicit souhlasu** — viz [`feedback_no_jira_writes`](../../memory/feedback_no_jira_writes.md).

## Kdy použít

- Po `/anomaly-report` — založit Jira ke konkrétní anomálii.
- Po `/refactor-proposal` — založit Jira jako parent epic / story pro tracking implementace.
- Z existující `investigation.md` v `Tickets/<CONN-NNN>/Plans/` — pokud zatím není ticket.
- Kdykoli uživatel řekne „založ Jira na X" + uvede source kontext.

Aktivace: `/jira-from-context --from <source-type> --source <path>`.

## Vstupy

- **`--from <source-type>`** (povinné) — `anomaly | refactor | investigation | manual`.
- **`--source <path>`** (povinné, pokud `--from != manual`) — cesta k zdrojovému dokumentu nebo `path#anchor` pro konkrétní sekci.
- **`--project <key>`** (volitelné) — Jira project key. Default zjistit od uživatele při prvním běhu (uložit do `[[reference_jira_project_key]]` memory) nebo `CONN`.
- **`--type <issue-type>`** (volitelné) — `Bug | Task | Story | Epic`. Default heuristika:
  - `--from anomaly` → `Bug`
  - `--from refactor` (`--breaking` v proposalu) → `Epic`, jinak `Task`
  - `--from investigation` → `Task`
  - `--from manual` → vyžádat
- **`--parent <key>`** (volitelné) — parent epic/issue key pro link.

## Workflow

1. **Načíst zdroj** — `Read` souboru. Pokud `--source` obsahuje `#anchor`, extrahovat jen tu sekci (typicky `## [CONN-NNN]` v `anomalies.md`).
2. **Extrahovat pole:**
   - **Title** — 1 řádek, max ~80 znaků. Z titulku anomaly / topic proposalu / titulku investigation.
   - **Popis** — 2-5 vět context, formálně.
   - **Reprodukce** — z anomaly „Reprodukce" sekce, nebo z investigation kroků.
   - **Evidence** — `path:line` snippety, hunter findings.
   - **Návrh řešení** — z anomaly „Navržené řešení" / proposal „Plán změn".
   - **Acceptance criteria** — checkbox list, co musí být splněno pro `Done`.
   - **Labels** — odvodit z `--from`:
     - `anomaly` → `anomaly`, `bug` (pokud severity ≥ stredni), `security` (pokud zdroj security-auditor)
     - `refactor` → `refactor`, `tech-debt`
     - `investigation` → `analysis`
   - **Severity / Priority** — pokud anomaly:  KRITICKÁ→Highest, VYSOKÁ→High, STŘEDNÍ→Medium, NÍZKÁ→Low.
3. **Vyplnit body** z `templates/issue-body.md.tmpl` (uvnitř skill folderu). Jira ADF / Markdown — `jira` MCP přijímá Markdown subset.
4. **Předložit draft** uživateli:
   - target project + issue type + parent + labels
   - kompletní body preview
   - otázka „založit Jira issue?"
5. **Pokud souhlas** („založ Jira", „založ", „yes"):
   - `mcp__jira__jira_create_issue` s vyplněnými poli (`project_key`, `summary`, `issue_type`, `description`, `additional_fields` JSON s labels + priority + parent).
   - Zachytit response, extrahovat issue key + URL.
6. **Zpětný odkaz do zdroje** — append do source dokumentu sekci `**Související tickety:**` (anomaly) / `**Ticket:**` (proposal) s odkazem `[<KEY>](<URL>)`. Per-change Edit, samostatný souhlas pokud zdrojový soubor není ve vlastním scope (např. anomaly v `<connector>/docs/anomalies.md` → Edit ok bez znovuovuyžádání, je to očekávaná návaznost).
7. **Závěrečný souhrn** — issue key, URL, parent link (pokud), label list.

## Pravidla

- **Bez explicit souhlasu žádný `jira_create_issue` call.** Draft ano, write ne — [`feedback_no_jira_writes`](../../memory/feedback_no_jira_writes.md).
- **Worklogy nezakládat** v tomto skill — od toho je `/worklog`.
- **Comments na existující issue** — pokud uživatel chce komentář, ne nový ticket, povolit `mcp__jira__jira_add_comment`, ale stále s explicit souhlasem.
- **Project key** — pokud první run, zeptat se uživatele a uložit do `[[reference_jira_project_key]]` memory.
- **Formální 3. osoba** v body — [`feedback_no_personification`](../../memory/feedback_no_personification.md).

## Gates

- **Explicit „založ Jira"** před `mcp__jira__jira_create_issue`.
- **Per-anomaly / per-proposal samostatný souhlas** — žádný batch („založ Jiry pro všechny anomálie naráz" → odmítnout, vyžádat per-položku).
- **Zpětný odkaz do source dokumentu** — automatický po úspěšném create (žádné nové potvrzení; je to očekávaná návaznost). Pokud Edit selže nebo soubor čte jiný skill, fallback ne-blokující warning v terminálu.

## Výstupní artefakty

- Nový Jira issue (po souhlasu).
- Zpětný odkaz v source dokumentu (anomaly entry / proposal).
- Issue URL v terminálu.

## Návaznosti

- **Před:** `/anomaly-report` (Phase 3), `/refactor-proposal` (Phase 3), `investigation.md` (Phase 4 `/start-ticket`).
- **Po:** ručně přejít na Jira (link), případně `/worklog` pro vykázání času.

## Notes

- Pokud Jira project nepoužívá CONN- prefix, lokální `[CONN-NNN]` IDs v `anomalies.md` zůstávají oddělené od Jira key. Jira link se vkládá vedle, ne místo lokálního ID.
- Issue type heuristika je default — uživatel může overridnout `--type`.
