---
name: Time logging terminology
description: Preferovaný výraz pro time logging je "vykázat čas" (byznys konvence), ne "zaloguj práci".
type: feedback
---

# Time logging terminology

Pro time logging intent (skill `/worklog`, návrhy v UI, doc texty) preferuj výraz **"vykázat čas"**. "Zaloguj práci" je zachováno jako legacy varianta, ale primárně používej "vykázat čas".

**Why:** Byznys konvence v projektu — "vykazování času" je etablovaný termín pro time tracking proti Jira issues. "Logování práce" zní techničtěji a méně přirozeně v komunikaci s ostatními. Při designu time-logging workflow korigováno `zaloguj práci` → `vykázat čas`.

**How to apply:**
- Skill `/worklog` se aktivuje imperativ/infinitiv tvary `vykaž|vykázat|vykazovat` (primární) + `zaloguj|zalogovat|log` (legacy). Perfektum (`vykázali`, `zalogoval`) je úmyslně vyloučeno — to jsou dotazy na minulost, ne intent k akci.
- V UI návrzích / textech docs preferuj "vykázat čas za <datum>" před "zalogovat práci".
- Skill se jmenuje `/worklog` (anglický kebab-case dle `feedback_skill_naming.md`); aktivuje ho i fráze „vykázat čas".

**Související:** `feedback_jira_worklog_format.md` (1 řádek Excelu = 1 worklog).
