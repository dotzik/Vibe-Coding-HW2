---
name: feedback-english-tech-terms
description: V connector kontextu projektu držet anglické technické termíny, nepřekládat je do češtiny ("bucket" ne "kbelík", "stored procedure" ne "uložená procedura", "task state" ne "stav úkolu").
metadata:
  type: feedback
---

V komunikaci o connectorech držet **anglické technické termíny** v originále, ne je překládat do češtiny. Týká se pojmů jako:

- `bucket` (ne „kbelík")
- `stored procedure`, `SP` (ne „uložená procedura")
- `task state`, `state_id` (ne „stav úkolu")
- `catch-all`, `swallow`, `rethrow`, `race condition`
- `transaction scope`, `BulkCopy`, `ER diagram`
- `null guard`, `exception swallowing`, `socket exhaustion`

**Why:** Repo, code, comments, Jira a docs jsou smíšené čeština + anglické termíny. Vlastní české překlady technických pojmů vnášejí dvojznačnost a zní improvizovaně. Konzistence s kódem a komunitou je cennější než „pure czech".

**How to apply:** Když píšu o errors / states / DB / HTTP / async / threading, používat anglické názvy přímo v české větě. Vyhnout se vlastním českým neologismům i pro pojmy které český překlad mají (např. „kbelík" pro bucket je nikde zavedené). Domain-specific české termíny (živnostník, statutární orgán, předmět podnikání, IČ) zůstávají česky — ty jsou byznys, ne tech.
