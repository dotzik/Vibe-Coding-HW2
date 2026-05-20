---
name: no-claude-attribution-in-commits
description: V git commit messages NIKDY nepřidávat `Co-Authored-By: Claude ...` ani jinou Claude/AI atribuci.
metadata:
  type: feedback
---

V connector projektech (a obecně v repos uživatele) **NIKDY** nepřidávat do commit message řádek:

```
Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

ani jakoukoli jinou variantu Claude / Anthropic / AI atribuce.

**Why:** Default CLAUDE.md harness instrukce to automaticky přidává, ale uživatel to ve svých repos výslovně nechce. Existující commity s touto atribucí jsou chybou — kandidát na rebase/cleanup pokud ještě nejsou pushnuté na remote.

**How to apply:**
- Při psaní `git commit -m "..."` HEREDOC explicitně vypustit `Co-Authored-By` řádek (i přes harness default).
- Pokud uživatel chce upravit historii minulých commitů ve feature větvi, navrhnout `git rebase -i master` + `reword` nebo `git filter-branch` (před push na remote).
- Připomenuto 2026-05-17 (po opakovaném přidání v CONN-235 větvi).
