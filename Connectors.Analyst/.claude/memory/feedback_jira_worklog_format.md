---
name: Jira worklog — jeden záznam per řádek Excelu
description: Při logování práce do Jiry přes mcp__jira__jira_add_worklog vytvořit samostatný worklog za KAŽDÝ řádek z Excelového výkazu, ne jeden kombinovaný.
type: feedback
---

Při logování dnešní práce do Jiry: jeden worklog per řádek z `CC_WS_*.xlsx` výkazu, **ne jeden kombinovaný**. Každý worklog má:

- `time_spent` = hodiny z toho řádku Excelu (např. `1h 30m`, `30m`, `2h`)
- `comment` = text z popisu daného řádku, plain text 1:1 z Excelu, žádný markdown
- `started` = postupně narůstající čas v rámci pracovního dne (08:00 → 16:00 pro 8h den), aby šly worklogy v Jiře v rozumném pořadí

**Why:** Uživatel si v Jiře vede time tracking po jednotlivých činnostech, ne jako blok per den. Kombinovaný 8h záznam s 7 řádky popisu uvnitř byl 2026-05-04 smazán s pokynem rozepsat per řádek. Kombinovaný worklog ničí granularitu, kterou si uživatel vede.

**How to apply:** kdykoliv po dotazu typu „zaloguj práci do Jira" / „log do Jiry" — počet API volání = počet datových řádků v Excelu pro daný den. Jakmile narazím na den s víc řádky pro stejný ticket, **nesnažit se je slučovat**, posílat každý zvlášť. Když je víc ticketů v jednom dni, každý řádek jde do toho ticketu, který má v Excelu sloupec `Ticket`.
