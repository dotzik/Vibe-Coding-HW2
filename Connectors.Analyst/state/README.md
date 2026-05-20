---
module: state-readme
version: 1.0.0
tags: [state, project, always-active]
scope: all
updated: 2026-04-27
---

# State — projektový stav, který se mění v čase

Soubory zde drží **aktuální stav projektu** — co je hotovo, kde co leží, jak se k čemu dostat. Žije s projektem (v gitu), na rozdíl od auto-memory v `~/.claude/projects/` (user-scoped, neverzované).

| Soubor | Co obsahuje | Aktualizovat když |
|---|---|---|
| [`cli-state.md`](./cli-state.md) | Stav `DbIntrospect` — verze, commandy, limity | Nová verze CLI, nový command, fix |
| [`db-environments.md`](./db-environments.md) | DB servery, VPN, account info (bez hesel) | Nový server, změna přístupu |
| [`snapshots-log.md`](./snapshots-log.md) | Log proběhlých DB snapshotů a klíčových zjištění | Po každém snapshot běhu proti reálné DB |
| [`filesystem-conventions.md`](./filesystem-conventions.md) | Kam patří scratch/tmp/snapshoty/logs/dumpy a co je gitignored | Změna konvence, nová třída artefaktu |

**Konvence:**
- Nikdy hesla / secrets — ty patří do `appsettings.Local.json` (gitignored)
- Datumy v `YYYY-MM-DD` formátu, vždy explicit
- Při update doplň záznam, nesmaž historii (pokud není vyloženě obsoletní)
