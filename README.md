# Vibe Coding — HW2: Konfigurace kódovacího agenta

Vypracovaný úkol: **nasdílení nastavení kódovacího agenta** s využitím MCP serverů, Skills a Subagentů — bez pluginů a marketplace.

**Kódovací agent:** Claude Code

## Co je v repu

Složka [`Connectors.Analyst/`](Connectors.Analyst/) je kompletní profil kódovacího agenta — doménově zaměřený asistent (senior .NET / SQL Server analytik nad sadou konzolových konektorů pro veřejné registry).

Profil je **anonymizovaný**: odstraněny názvy firmy, interní infrastruktura, connection stringy, jména osob i klientů. Zachována je struktura a funkčnost — předmětem úkolu je konfigurace agenta, ne doménová data.

## Co profil demonstruje

| Komponenta | Počet | Kde |
|---|---|---|
| **MCP servery** | 5 | [`Connectors.Analyst/.mcp.json`](Connectors.Analyst/.mcp.json) |
| **Skills** | 10 (7 workflow + 3 hybrid) | [`Connectors.Analyst/.claude/skills/`](Connectors.Analyst/.claude/skills/) |
| **Subagenti** | 5 (read-only) | [`Connectors.Analyst/.claude/agents/`](Connectors.Analyst/.claude/agents/) |
| **Hooks** | 3 | [`Connectors.Analyst/.claude/settings.json`](Connectors.Analyst/.claude/settings.json) |
| **PowerShell skripty** | 6 | [`Connectors.Analyst/tools/`](Connectors.Analyst/tools/) |

Žádné plugins ani marketplace.

## Kudy začít

1. [`Connectors.Analyst/README.md`](Connectors.Analyst/README.md) — přehled profilu
2. [`Connectors.Analyst/CLAUDE.md`](Connectors.Analyst/CLAUDE.md) — vstupní bod: moduly, registry, konvence
3. [`Connectors.Analyst/docs/skills-and-tools.md`](Connectors.Analyst/docs/skills-and-tools.md) — detail skills, subagentů a skriptů
