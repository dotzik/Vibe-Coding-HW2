---
name: feedback-tickets-scratch-only
description: Adresář ${PROJECT_ROOT}/Tickets/ je jen scratch / pomocný workspace, NIKDY ne destinace pro investigation výstupy. Per-ticket investigace patří do <connector-repo>/src/<connector>/docs/Ana-CONN-NNN/ (viz Ana-CONN-229 v RPV, Ana-CONN-237 v SbirkaListin_Archiv).
metadata:
  type: feedback
---

`${PROJECT_ROOT}/Tickets/<CONN-NNN>/` je **scratch / working workspace** — místo pro rozpracované plány, dočasné poznámky, kandidáty před zveřejněním. **NIKDY ne finální výstupy investigation.**

**Why:** Per-ticket analytické výstupy (investigation.md + queries/ + screenshots/ + atd.) patří do versioned connector repo, ne do scratch adresáře Analyst profile-u. Tam jsou viditelné v code review, dohledatelné v `git log`, propojené s kódem (`../../ProcessInstance.cs#L116`), a přežijí restrukturalizaci Analyst profile-u.

**How to apply:** Per-ticket investigation umístit do:

```
<connector-repo>/src/<connector>/docs/Ana-CONN-NNN/
├── investigation.md
├── queries/
│   ├── 01_<topic>.sql
│   └── ...
├── DataSource/      (optional — sample data)
└── Scripts/         (optional — opravné SQL skripty)
```

Případy mimo:
- `Connector.CZ.RejstrikPravnichOsob` používá `Docs/` (velké D) s `Ana-CONN-NNN/` uvnitř — historická varianta, replikovat při práci v tomto connectoru.
- `SbirkaListin_Archiv`, `SK.Rzp` (a novější) používají `docs/` (malé d) — preferovaný styl pro nové.

`Tickets/<CONN-NNN>/` může držet pouze:
- ranou rozpracovanou heuristikou před promotion do connector repo
- meta-plány (`/start-ticket` skeleton, Plans/)
- artefakty které k connector repo nepatří (npc. CV-style analýza)
- **draft Jira komentářů (`jira-comment-draft.md`) a podobné agent-workflow scratch** — investigation.md a SQL queries do connector repa patří, draft Jira komentáře NE (potvrzeno 2026-05-20 u CONN-222)

Po dokončení investigation: přesunout do connector repo, scratch folder smazat / nechat prázdný.
