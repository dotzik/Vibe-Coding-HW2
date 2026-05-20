---
name: connectors-dynamic-scope
description: Počet connectorů je dynamický a roste — MCP connectors zpřístupňuje jen subset podle aktuálně řešených ticketů. Nikdy nehardcodovat konkrétní číslo (7, N) v skills/agents/docs.
metadata:
  type: project
---

Ekosystém projektu má rostoucí počet .NET konektorů (registry CZ + SK + EU). Aktuálně přes MCP `connectors` exponovaný subset (~7 v 2026-05) je řízen tickety, ne pevnou množinou.

**Why:** Při zápisu skills/agents/docs hrozí hardcoding aktuálního čísla → drift, nutnost revize při každém přidání connectoru. Také brání budoucímu škálování (sharding per registr).

**How to apply:**
- V description / system promptech / docs psát „všechny dostupné connectory v connectors scope" nebo „N connectorů", ne „7 connectorů".
- Workflow vždy postavit na dynamic discovery (`list_directory` connectors), ne na enumerated listu.
- Při paralelních runech (např. `/cross-consistency-check`) batchovat po ~5-7 kvůli MCP rate limits + context budgetu — limit je technický, ne sémantický.
- Existující zmínky „7 connectorů" v `CLAUDE.md`, master `README.md`, `knowledge/connectors-inventory.md` neopravovat hurá-akcí — flag a opravit při nejbližší editaci daného souboru.
