---
name: no-personification-in-docs
description: V analytických / dokumentačních dokumentech vždy formální zápis bez personifikace (žádné "Josef", "my", "tým", "během analýzy zjišťujeme").
metadata:
  type: feedback
---

V dokumentech typu `investigation.md`, `analysis.md`, ticket docs, anomalies — vždy **formální analytický zápis ve třetí osobě / pasivní rod**. Žádné:

- jména osob ("Josef otevřel", "Martin požádal") — pokud je atribuce nutná, "reporter ticketu" nebo neuvádět
- první osoba množná ("my", "tým", "během analýzy zjišťujeme")
- vyprávěcí styl ("připojil obrázek", "po prvním pokusu se ukázalo")
- konverzační linky ("k odsouhlasení s Josefem", "ptáme se uživatele")

Místo toho: pasivní rod, neutrální deklarativní věty, **fakta + důsledky + návrhy**.

**Why:** Personifikované zápisy nepůsobí profesionálně a stávají se nečitelné s odstupem času (po měsících čtenář neví, kdo "Josef" nebo "my" byli). Formální analytický styl je vlastní normě connector docs projektu (viz stávající `analysis.md` v projektech) — drží tonalitu konzistentní napříč.

**How to apply:**
- Píšeš-li investigation/analysis/anomaly doc → ve **třetí osobě, neutrálně**.
- Kontext / motivace → "Ticket vznikl z důvodu...", "Identifikováno bylo...", "Endpoint vrací...".
- Závěry → "Doporučená varianta...", "Otevřené otázky...", ne "Co dál?", "Zeptáme se".
- Pokud potřebuješ atribuovat rozhodnutí, použij datum: "Rozhodnuto 2026-05-15: ..." místo "Josef rozhodl...".
- Tohle se vztahuje **na dokumenty v repu I plan files** (`.claude/plans/`, `Tickets/<ISSUE>/Plans/`), ne na chat-styl odpovědi v terminálu (tam se mluví normálně).

**Anti-patterny zaznamenané (2026-05-15):**
- "Josef otevřel CONN-235 s minimálním zadáním..."
- "Cíl této session..."
- "Volba k odsouhlasení s Josefem po F1.4"
- "samples staženo přes curl, žádný dotek connectoru ani DB"
