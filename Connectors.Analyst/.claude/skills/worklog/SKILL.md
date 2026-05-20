---
name: worklog
description: Vykázání času do Jiry z popisu v chatu — uživatel nadiktuje co dělal, skill sestaví preview tabulku a po „schvaluji" pošle samostatný worklog za každou položku přes `mcp__jira__jira_add_worklog`. NIKDY nekombinuje položky do jednoho worklogu. Aktivace `/worklog` nebo fráze „vykázat čas".
---

# /worklog

Skill vykáže čas do Jiry **z toho, co uživatel napíše do chatu** — žádný Excel.
Klíčové pravidlo: **jedna položka = jeden Jira worklog**
([`feedback_jira_worklog_format`](../../memory/feedback_jira_worklog_format.md)).
Nikdy slučovat. Bez explicitního „schvaluji" žádný write
([`feedback_no_jira_writes`](../../memory/feedback_no_jira_writes.md)).

## Kdy použít

- Konec pracovního dne — „vykázat čas", „vykaž 2h CONN-142", „/worklog".
- Doplnění zapomenutého dne — „vykázat čas za 2026-05-15: …".

Aktivace: `/worklog [--start-time HH:mm]` nebo fráze „vykázat čas" / „vykaž … hodin".

## Vstup

Volný text v chatu — uživatel nadiktuje položky, např.:

> vykázat čas: 2h CONN-142 ladění parseru, 30m CONN-150 review PR, 1h porady

Skill z textu vytěží per položku: **ticket key**, **dobu**, **popis**, případně **datum**.

- **Datum** — pokud nezmíněno, default dnešní. Jeden běh `/worklog` = jeden den.
- **Doba** — `2h`, `1h 30m`, `30m`, `0.5h`, `90m` → normalizovat na Jira `time_spent`.
- **Ticket** — `^[A-Z]+-\d+$`. Chybí-li / je nejasný, **zeptat se**, nehádat.

## Workflow

1. **Parse položek z chatu** — vytěžit ticket / dobu / popis / (datum) za každou
   činnost. Nejasnou položku nevyhazovat — doptat se uživatele.
2. **Validace**:
   - Ticket regex `^[A-Z]+-\d+$`.
   - Doba → Jira `time_spent` (`1.5h` / `90m` → `1h 30m`).
   - Popis — plain text, žádný markdown.
   - Vadná položka → `⚠️ SKIP`, vyjmout z dávky, zmínit ve výstupu.
3. **Stoupající `started`** — první položka `08:00` (nebo `--start-time`), každá
   další `+= doba předchozí`. Cíl: čitelný timeline v Jira worklog UI.
4. **Idempotence check** — pro každý unikátní ticket načíst
   `mcp__jira__jira_get_worklog` (autor = aktuální uživatel, daný den).
   Worklog se shodnou dobou a `started` v rámci **±10 min** → `🟡 DUPLIKÁT`.
5. **Preview tabulka** uživateli:

   | # | Ticket | Doba | Started | Popis | Akce |
   |---|---|---|---|---|---|
   | 1 | CONN-142 | 2h | 08:00 | ladění parseru | ✅ POST |
   | 2 | CONN-150 | 30m | 10:00 | review PR | ✅ POST |

   Souhrn: `X k POST, Y duplikátů, Z chyb`.
6. **Gate** — vyžádat explicit `schvaluji` (`schvaluji vše` = celá dávka).
7. **POST sekvenčně** (NE paralelně — Jira rate limit):
   - Per položka `mcp__jira__jira_add_worklog` (`issue_key`, `time_spent`,
     `started` ISO 8601 s timezone, `comment` plain text 1:1).
   - Úspěch → ✅ + worklog ID; selhání → ❌ + důvod. HTTP 429/5xx → backoff 5/15/30s.
8. **Závěrečný report** — kolik OK / selhalo, worklog ID, návrh re-run při selhání.

## Gates

- **Explicit `schvaluji` před prvním worklogem** ([`feedback_no_jira_writes`](../../memory/feedback_no_jira_writes.md)).
- **NIKDY nekombinovat položky** do jednoho worklogu — ani stejný ticket/den
  ([`feedback_jira_worklog_format`](../../memory/feedback_jira_worklog_format.md)).
  Žádné `doba_celkem = SUM()`.
- **Žádný edit / delete** existujícího worklogu — duplikát jen přeskočit a oznámit.

## Notes

- **Žádný Excel.** Vstup je chat. Hromadný **export** Jira worklogů zpět do
  `CC_WS_<MĚSÍC>_<ROK>.xlsx` (pro účetnictví) dělá opt-in skript
  `tools/worklog-export.ps1` (jediná závislost na modulu `ImportExcel` v profilu).
- **Terminologie** — „vykázat čas" je preferovaný výraz
  ([`feedback_time_logging_terminology`](../../memory/feedback_time_logging_terminology.md)).
- **Hook `validate-worklog.ps1`** (PreToolUse `jira_add_worklog`) upozorní na
  kombinovaný worklog (pipe / středník v `comment`) — ne-blokující pojistka.

## Návaznosti

- **Po:** `/standup-prep` použije vykázané worklogy pro „Yesterday" sekci.
- **Export:** `tools/worklog-export.ps1` — měsíční `.xlsx` z Jira worklogů.
