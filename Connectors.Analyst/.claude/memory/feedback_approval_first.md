---
name: approval-first-workflow
description: Při společné práci na ticketu schválit každý měnící krok a vysvětlovat průběžně, ne batch.
metadata:
  type: feedback
---

Při společné práci na ticketu (typicky implementace podle Plans/) **nedělat žádnou změnu bez explicitního souhlasu uživatele**. Před každým edit/Write/Bash, který něco mění, popsat co a proč se chystám udělat, a počkat na „ok / jdi / udělej to".

**Why:** Uživatel chce držet kontrolu nad krokováním a zároveň si průběžně vysvětlovat rozhodnutí — preferuje dialog nad batch-implementací. Vzneseno při startu CONN-213 (2026-05-13).

**How to apply:**
- Read/Glob/Grep/jira_get_issue a podobné read-only akce běží volně.
- Edit/Write/spuštění příkazů, které něco mění (kód, DB, git, Jira komentář) → nejdřív krátký záměr + reference do plánu, pak `AskUserQuestion` nebo prostá otázka „mám pokračovat?".
- Když je krok netriviální (nový algoritmus, SQL DDL, refactor metody), vysvětlit i **proč** to dělám tak, ne jen co; čekat na potvrzení nebo úpravu směru.
- Plán [[plans-per-ticket]] zůstává zdrojem pravdy pro pořadí kroků; tahle feedback rule určuje **tempo a styl** jejich provádění.
- **`git commit` patří mezi měnící akce** — i pro dokumentační/audit commity vždy nejdřív ukázat diff (`git diff` / `git diff --cached`) a počkat na schválení. NIKDY si nedávat `git add + git commit` v jednom kroku bez schválení uživatelem. Připomenuto 2026-05-17 po pokutě za commit investigation.md auditu bez review.
