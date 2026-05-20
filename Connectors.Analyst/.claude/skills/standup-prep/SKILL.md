---
name: standup-prep
description: Sestaví Yesterday / Today / Blockers blok do markdownu (copy-pasteable do Teams/Slack) z paralelních zdrojů — git log napříč Connectors+Libs+profil s autor filtrem, Jira worklogy za včera, aktivní Plans soubory, sprint board, blokované issues. Read-only. Aktivace `/standup-prep`.
---

# /standup-prep

Skill připraví standardní 3-sekční standup poznámku z agregovaných zdrojů. Žádné writes, pouze read. Sekce: **Yesterday** (co bylo hotovo), **Today** (co se plánuje), **Blockers** (kde to drhne).

## Kdy použít

- Před denním standupem (typicky 9:00).
- Po delší pauze pro „kde jsme to skončili".
- Před retro / sprint review jako podklad.

Aktivace: `/standup-prep [--days 1]`.

## Vstupy

- **`--days <N>`** (volitelné) — kolik dní zpět považovat za „yesterday". Default `1`. Pro pondělí typicky `3` (Pá–Ne).
- **`--author <name>`** (volitelné) — git autor filter. Default z `git config user.name` (+ heuristika).
- **`--no-jira`** (volitelné) — přeskočit Jira volání (offline / down).

## Workflow

Skill používá **paralelní tool calls v jednom message** pro 5 nezávislých zdrojů (3× git + 2× Jira). Až pak agreguje.

1. **Paralelní fetch** (1 message, ~5 tool calls):
   - `git log --author=<author> --since="<N> days ago" --pretty="format:%h %ad %s" --date=short` v `${PROJECT_ROOT}/Connectors`.
   - Totéž v `${PROJECT_ROOT}/Libs`.
   - Totéž v `${PROJECT_ROOT}/Connectors.Analyst`.
   - `mcp__jira__jira_search` JQL `worklogAuthor = currentUser() AND worklogDate >= -<N>d` → seznam ticketů s loggovaným časem za období.
   - `mcp__jira__jira_search` JQL `assignee = currentUser() AND sprint in openSprints() AND status not in (Done, Closed, Resolved)` → aktivní práce.
2. **Paralelní druhá vlna** (1 message):
   - `Get-ChildItem ${PROJECT_ROOT}/Tickets -Recurse -Filter *.md -Path */Plans/*` s `LastWriteTime > (Get-Date).AddDays(-7)` → aktuální plánovací soubory.
   - `mcp__jira__jira_search` JQL `assignee = currentUser() AND status in ("Blocked", "Waiting", "On Hold", "Waiting for support")` → blockers.
3. **Agregace Yesterday**:
   - Git commits → seskupit per repo, max 8 řádků, prefix `- <repo>: <hash> <subject>`.
   - Jira worklogs → per ticket: `CONN-NNN <Title> — Xh celkem`.
   - Deduplikace (commit často referenuje Jira issue v subjectu).
4. **Agregace Today**:
   - Aktivní sprint issues → `- CONN-NNN <Title> (<status>)`.
   - Modified Plans soubory s timestamp → `- Tickets/<ID>/Plans/<file>.md (touched <date>)`.
5. **Agregace Blockers**:
   - Blocked issues → `- CONN-NNN <Title> — blocked since <date>, reason: <last comment summary or label>`.
   - Pokud žádné: vypsat „— žádné blockers".
6. **Render markdown** — 3 sekce, kompaktní formát, max ~40 řádků celkem (čitelné v Teams).
7. **Tail**: krátký souhrn (5 commits / 3 tickets logged / 4 active / 1 blocker) + návrh „copy-paste do standup channel".

## Výstupní formát

```markdown
## Standup — {{DATE}}

### Yesterday
- <repo/ticket>: <co hotovo, 1 řádek>
- ...

### Today
- <CONN-NNN> <titul> — <co plánuji>
- ...

### Blockers
- <CONN-NNN> <titul> — <blocker reason>
- (nebo: žádné)
```

## Gates

- **Žádné writes** — pouze read. Žádný gate potřeba.
- **`--no-jira`** fallback pokud Jira selže — skill graceful degradation, jen git sekce.

## Notes

- **Paralelizace je klíčová** — 5+ tool calls v 1 message, ne sekvenčně. Wall-clock cíl < 10s.
- **Git autor filter** — autor commitů odpovídá `git config user.name`. Pokud override, použít `--author`.
- **Sprint custom field** — JQL `sprint in openSprints()` funguje pro většinu projektů; pokud Jira projekt nemá Agile board, fallback na `updated >= -<N>d`.
- **Modifikované Plans** jako proxy pro „today" — pokud byl včera editován `investigation.md`, je pravděpodobné, že práce dnes pokračuje.

## Návaznosti

- **Po:** typicky manuální copy-paste do Teams/Slack standup channelu.
- **Komplement:** `/worklog` (předchozí den, aby Yesterday Jira sekce byla úplná).
