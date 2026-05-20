---
name: skill-and-agent-naming
description: Skills a subagents používají anglické kebab-case názvy, ale jejich obsah (SKILL.md, agent prompt, výstupy) je česky
metadata:
  type: feedback
---

Skills (`.claude/skills/<name>/`) a subagents (`.claude/agents/<name>.md`) v tomto profilu **MUSÍ mít anglické kebab-case názvy** (např. `upgrade-docs`, `anomaly-report`, `doc-validator`, `dead-code-hunter`), ale **obsah souborů a generované výstupy jsou česky**.

**Why:** Profil bude sdílen v týmu, kde ne všichni mluví anglicky → obsah česky. Zároveň `/<command>` slash commandy a názvy v toolu Agent vypadají profesionálněji a interně konzistentněji v angličtině; míchání češtiny do identifikátorů vytváří nepořádek (diakritika, kebab-case ČJ vypadá divně).

**How to apply:** Při zakládání nového skill/subagentu zvol anglický kebab-case slug (`/povys-docs` → `/upgrade-docs`, `/anomaly-report` zůstává, `/jira-from-context` zůstává). Frontmatter `name:` a název adresáře = anglicky. Tělo SKILL.md, prompty subagentů, šablony výstupů, hlášky → česky (s anglickými technickými termíny dle `core/persona.md`).
