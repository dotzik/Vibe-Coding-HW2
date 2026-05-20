---
name: WebFetch unreliable for markup audits
description: WebFetch (Claude na pageu) opakovaně chybí HTML atributy a tvrdí, že wrapper/atribut neexistuje, když ve skutečnosti je. Pro markup audity používat curl+grep.
metadata:
  type: feedback
---

WebFetch převede HTML na markdown a pak na něj pouští druhý model. V procesu **mizí atributy a obal elementů**.

**Why:** Konkrétní incident CONN-213 (2026-05-13). WebFetch na `dotaceeu.cz/cs/statistiky-a-analyzy/seznam-operaci-(prijemcu)` tvrdil:
- „`<div class="download-list">` neexistuje" — REALITA: `<div class="download-list documents js-download-list">` v markupu byl 1×.
- „`data-filename` atribut neexistuje" — REALITA: 82 výskytů s plným `DD/MM/YYYY` datem.
- „Datum formát je mm/dd/yyyy" — REALITA: dd/mm/yyyy (cz portál).

Důsledek: URL discovery bylo implementováno na špatném základě, opravu musel vznést uživatel. Stálo to 1 commit amend.

**How to apply:**
- Pro audit konkrétního HTML markupu (atributy, class names, selectory) **NIKDY nespoléhat jen na WebFetch**.
- Místo toho: `curl -s {url} -o /tmp/page.html` (přes Bash) a hledat `grep` / `grep -c` / `grep -o` přímo v raw HTML. Velikost souboru < 200kB → grep je triviální.
- WebFetch je OK pro: high-level summary stránky, extrakce viditelného textu, rozpoznání „co stránka dělá". Není OK pro: „má tento element atribut X?".
- Když WebFetch tvrdí, že něco neexistuje, **ověřit curl-em** než postavit kód na tom předpokladu.
