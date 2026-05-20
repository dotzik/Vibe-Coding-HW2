# Memory index — Connectors.Analyst

Sdílená paměť profilu, verzovaná v gitu. Index je vždy v kontextu (přes `CLAUDE.md` referenci); jednotlivé `*.md` se tahají dle relevance.

## Feedback — jak s profilem pracovat

- [feedback_approval_first.md](feedback_approval_first.md) — Každý měnící krok (vč. `git commit`) napřed schválit, ne batch.
- [feedback_no_jira_writes.md](feedback_no_jira_writes.md) — Žádný Jira write bez schválení konkrétního zápisu; worklog až po „schvaluji".
- [feedback_jira_worklog_format.md](feedback_jira_worklog_format.md) — Jeden worklog per řádek výkazu, nikdy kombinovaný.
- [feedback_time_logging_terminology.md](feedback_time_logging_terminology.md) — Preferuj „vykázat čas"; perfektum není intent k akci.
- [feedback_no_claude_attribution.md](feedback_no_claude_attribution.md) — Commit message nikdy s `Co-Authored-By: Claude`.
- [feedback_braces_on_ifs.md](feedback_braces_on_ifs.md) — Vždy `{}` u if/else/foreach, i jednořádkových.
- [feedback_no_personification.md](feedback_no_personification.md) — Analytické/dokumentační soubory formálně, 3. osoba, bez jmen.
- [feedback_english_tech_terms.md](feedback_english_tech_terms.md) — Anglické technické termíny nepřekládat do češtiny.
- [feedback_skill_naming.md](feedback_skill_naming.md) — Skills/subagents anglický kebab-case název, český obsah.
- [feedback_tickets_scratch_only.md](feedback_tickets_scratch_only.md) — `Tickets/` je scratch; investigation výstupy do `<connector>/…/docs/Ana-CONN-NNN/`.
- [feedback_webfetch_unreliable_markup.md](feedback_webfetch_unreliable_markup.md) — WebFetch ztrácí HTML atributy; markup audit přes curl+grep.

## Project

- [project_db_permissions.md](project_db_permissions.md) — Bez práv CREATE/ALTER PROCEDURE → nová logika do `*DA.cs`, ne SP.
- [project_connector_directory_layout.md](project_connector_directory_layout.md) — Connectory mají nested layout `Connector.<X>/src/Connector.<X>/`; resolve přes glob.
- [project_connectors_dynamic_scope.md](project_connectors_dynamic_scope.md) — Počet connectorů je dynamický; nehardcodovat čísla.

## Decisions

- [decisions/001-redesign-2026-05.md](decisions/001-redesign-2026-05.md) — Proč skill/subagent/hook architektura, varianta A, split bug-hunteru.
