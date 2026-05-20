---
name: cross-consistency-check
description: Audit sjednoceného stylu docs napříč všemi dostupnými connectory v connectors scope. Konzumuje knowledge/doc-style-comparison.md a doc-validator (per connector). Výstup tabulka „kdo má co".
---

# /cross-consistency-check

Skill provede audit dokumentační konzistence napříč všemi connectory dostupnými v aktuálním scope `connectors`. Stojí na paralelních runech subagenta `doc-validator` a agreguje výsledky do matricového reportu.

## Kdy použít

- Před release.
- Před `/upgrade-docs` na druhém connectoru ve stejném tématu (porovnání startovní pozice).
- Periodicky (~1× měsíčně) jako health check.

## Vstupy

- Žádné povinné.
- **`--connectors <list>`** (volitelné) — explicit subset (csv názvů adresářů). Default = vše, co `list_directory` vrátí v connectors-root.
- **`--connectors-root <path>`** (volitelné) — default `${PROJECT_ROOT}/Connectors/`.

Počet connectorů je dynamický — viz `.claude/memory/project_connectors_dynamic_scope.md`. Žádný hardcoded list.

## Workflow

1. **Inventura** — `list_directory` v connectors-root → seznam connectorů. Cross-check proti `knowledge/connectors-inventory.md` (flag missing/extra v reportu).
2. **Reference patterny** — načíst `knowledge/doc-style-comparison.md` jako source of truth best-of patternů.
3. **Paralelně spustit `doc-validator`** na každém connectoru přes `Agent` tool s `subagent_type: doc-validator` a promptem `--connector <name>`. Batchovat po ~5-7 paralelně (MCP rate limits + context budget hlavního agenta). Při větším N auto-batchovat sekvenčně po dávkách.
4. **Fallback** — pokud paralelně padá na MCP errors → sekvenční run s průběžným progress reportem.
5. **Agregace** do matrice (viz formát níže). Hodnota buňky: `✅` / `⚠️ <n findings>` / `❌ missing`.
6. **Top findings** — 5–10 nejnaléhavějších rozdílů, prioritizace `high / med / low`.
7. **Doporučení** — který connector spustit přes `/upgrade-docs` jako další (typicky max `⚠️` nebo `❌`).
8. **Uložit report** — preview + path → schválení → `Write` do `${PROJECT_ROOT}/Tickets/Refactor/reports/cross-consistency-<YYYY-MM-DD>.md`. Adresář `reports/` při prvním běhu vytvořit.

## Výstupní formát reportu

```markdown
# Cross-consistency check — <YYYY-MM-DD>

**Connectorů auditováno:** N (z M dostupných v connectors scope)
**Source of truth:** knowledge/doc-style-comparison.md
**Batches:** <počet dávek × velikost>

## Matrice

| Connector | analysis | flow | sp | db | anomalies | mermaid | schema prefix | CONN-NNN |
|---|---|---|---|---|---|---|---|---|
| <name> | ✅ | ⚠️ 2 | ✅ | ✅ | ❌ | ✅ | ✅ | n/a |
…

## Top findings (high prio)
- `<connector>` — `<doc>` — popis — navrhovaná akce
…

## Doporučená priorita pro /upgrade-docs
1. `<connector>` — důvod (kolik findingů, jaké priority)
2. `<connector>` — důvod
…

## Inventory drift
- Missing v knowledge/connectors-inventory.md: <list>
- Extra v inventáři, ne v connectors scope: <list>
```

## Gates

- Audit sám je **read-only**.
- **Zápis reportu** spadá pod approval-first (viz `.claude/memory/feedback_approval_first.md`) — před `Write` ukázat preview reportu + cestu, počkat na „zapsat?".

## Limity a pozor na

- **MCP rate limits** → batchovat po ~5-7 paralelně, fallback sekvenčně.
- **Style mapa neúplná** — pokud `knowledge/doc-style-comparison.md` nepokrývá všechny aktuálně dostupné connectory, doplnit jako warning v reportu (nezastavovat běh).
- **Counter růst** — při >15 connectorech zvážit sharding reportu per registr (CZ / SK / EU) místo single matrice.
- **Doc-validator dimenzování** — 1× full pass per connector, ne iterativní deep-dive (system prompt subagenta to drží).

## Výstupní artefakty

- `reports/cross-consistency-<YYYY-MM-DD>.md` v master ticket adresáři refactor iniciativy.
- Finální souhrn v terminálu (top findings + doporučení).

## Návaznosti

- Matrice → vstup pro prioritizaci `/upgrade-docs`.
- Plošné nezdokumentované anomálie → `/anomaly-report` (Phase 3).
- Nové patterny odhalené auditem → update `knowledge/doc-style-comparison.md`.
