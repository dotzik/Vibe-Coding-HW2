---
name: no-jira-writes
description: Žádný zápis do Jiry bez explicitního schválení uživatele pro daný konkrétní zápis. Worklogy smím postovat, ale až po „schvaluji" na konkrétní rozpad.
metadata:
  type: feedback
---

**Žádný Jira write bez explicitního schválení daného zápisu.** Platí pro VŠE — worklogy, komentáře, ticketu, transitions. Schválení je per-akce: souhlas s jedním rozpadem neplatí pro příští.

**Worklogy (`mcp__jira__jira_add_worklog`):** smím je volat, ale workflow je vždy: 1) připravím rozpad (časy + komentáře, diakritika, granulárně dle [[feedback_jira_worklog_format.md]]), 2) ukážu uživateli, 3) **čekám na explicitní „schvaluji / zaloguj to"**, 4) teprve pak volám API. Bez kroku 3 nevolat. Nestačí, že uživatel dřív řekl „zaloguj do Jiry" — pořád musí odsouhlasit konkrétní rozpad.

**Ostatní write akce — jen návrh textu.** `jira_add_comment`, `jira_create_issue`, `jira_update_issue`, `jira_transition_issue`, `jira_edit_comment`, `jira_create_issue_link`, `jira_link_to_epic`, ekvivalenty v `mcp__claude_ai_Atlassian_Rovo__*` — nevolat. Připravím Markdown blok, uživatel postuje sám.

**Read-only OK:** `jira_get_issue`, `jira_search`, `jira_get_transitions`, `jira_get_worklog` apod. — volně.

**Why:** Uživatel chce plnou kontrolu nad tím, co a kdy jde do Jiry. 2026-05-14 (session CONN-213): poprvé povoleno postnout worklogy, vzápětí upřesněno, že zápis smí proběhnout jen s explicitním svolením pro ten konkrétní případ — ne jako trvalé zmocnění.

**How to apply:** Krok „zaloguj worklog" → ukázat rozpad, zastavit se, počkat na souhlas, pak `jira_add_worklog` per položku. Krok „Jira komentář / ticket / transition" → připravit text, nevolat API.

Související: [[feedback_approval_first.md]], [[feedback_jira_worklog_format.md]].
