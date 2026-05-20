# UPGRADE-GUIDE — Povýšení existující dokumentace na best-of standard

> Pro connectory, které **už mají** docs/. Cíl: extend & align, ne přepsat.

## Filosofie

Motto profilu: **„Z chaosu pořádek."**

- **NE**: smazat existující `analysis.md` a vygenerovat nový ze šablony.
- **ANO**: spočítat diff vs. šablonu, identifikovat chybějící sekce, doplnit je.
- **ANO**: identifikovat unikátní hodnotné sekce, které šablona nemá → povýšit standard, ne dokument.

## Postup per connector

### Krok 1 — Diff existujícího vs. standard

Otevři dva soubory vedle sebe (nebo poprosit agenta):

```
existující:  Connectors/<connector>/src/.../docs/analysis.md
šablona:     Connectors.Analyst/templates/connector-docs/analysis.md.tmpl
```

Vyrob tabulku:

| Sekce | Existuje v dokumentu? | Existuje v šabloně? | Akce |
|---|---|---|---|
| Účel | ✅ | ✅ | nic |
| Technologie | ✅ | ✅ | porovnat verze, doplnit chybějící |
| Konfigurace JSON | ❌ | ✅ | **doplnit** |
| Architektura | ✅ | ✅ | je dual-view? Pokud byl refactor, přidat |
| Datové objekty (class diagram) | ✅ | ✅ | nic |
| Anomálie inline ⚠️ | ✅ | ❌ | **migrovat** do nového `anomalies.md` |
| Per-ticket složka `Ana-CONN-NNN/` | částečně | ✅ | doplnit chybějící |

### Krok 2 — Spustit CLI snapshot

```bash
# Per každou DB connectoru (DbIntrospect CLI = interní nástroj, mimo profil snapshot):
pwsh tools/dbintrospect.ps1 -Mode snapshot -Database AppDb \
    -Out ${PROJECT_ROOT}/Connectors/<connector>/docs/snapshots/$(date +%F)/AppDb/
```

### Krok 3 — Vytvořit `database-model.md` (nový dokument)

Použij šablonu `templates/connector-docs/database-model.md.tmpl` + obsah snapshotu.

Agent prompt:
> „Z `<connector>/docs/snapshots/<date>/AppDb/` (tabulky a procedury) vygeneruj `<connector>/docs/database-model.md` podle šablony `templates/connector-docs/database-model.md.tmpl`. Doplň ER diagram (mermaid) z relací FK. Sekci enumerace nech jako prázdnou tabulku (vyplníme ručně)."

### Krok 4 — Vytvořit `anomalies.md` (nový dokument)

Migrovat ⚠️ z existujícího `analysis.md` / `flow.md` / `stored-procedures.md` do tabulky.

Agent prompt:
> „V dokumentech `<connector>/docs/*.md` najdi všechny ⚠️ anomálie. Pro každou vyplň záznam v `anomalies.md` podle šablony: ID (přiřaď [ANOM-NNN] pokud nemá ticket), závažnost, popis, místo, dopad, navržené řešení, status=open. Nemaž původní ⚠️ z dokumentů — jen přidej `viz anomalies.md#ANOM-NNN`."

### Krok 5 — Doplnit chybějící sekce v existujících dokumentech

Per dokument, podle diff tabulky z kroku 1.

**Pravidlo:** **nemaž žádný existující obsah** bez explicitního schválení. Pouze doplňuj.

### Krok 6 — Vytvořit `README.md` (pokud chybí)

Použij šablonu `templates/connector-docs/README.md.tmpl`.

### Krok 7 — Cross-link

Po doplnění:
- `analysis.md` → odkaz na `database-model.md` v sekci „DB objekty"
- `stored-procedures.md` → odkaz na `database-model.md` (DDL detail)
- Všechny dokumenty → odkaz na `anomalies.md` (pokud relevantní pro sekci)

### Krok 8 — PR

```markdown
## Co se mění
- Doplněno: README.md, database-model.md, anomalies.md
- Doplněny chybějící sekce v: analysis.md (Konfigurace JSON), flow.md (Mapování chyb→stavy)
- Migrace: ⚠️ z analysis.md a stored-procedures.md → centralizováno v anomalies.md (originály zachovány s odkazem)
- Snapshot DB: docs/snapshots/<date>/

## Žádné mažu
- Žádný existující obsah nebyl smazán.

## Verifikace
- [ ] Diff vs. původní stav (`git diff`) — žádné minus řádky kromě reformátování
- [ ] Mermaid diagramy se renderují
- [ ] Snapshot odpovídá produkční DB
```

## Pořadí povyšování (priorita)

| Connector | Priorita | Důvod |
|---|---|---|
| `Connector.CZ.RejstrikPravnichOsob` | 🟢 NÍZKÁ | Už má `Docs/` (capital D) s nadstandardem (Scripts/, Ana-CONN-229/). Stačí doplnit `database-model.md` + `anomalies.md`. |
| `Connector.SK.FinRed.NespolehlivyPlatce` | 🟠 STŘEDNÍ | Bohaté anomálie inline — migrovat do `anomalies.md`. |
| `Connector.CZ.SbirkaListin_Archiv` | 🟠 STŘEDNÍ | Má `_scripts/` introspekci → nahradit `DbIntrospect snapshot`. Anomálie migrovat. |
| `Connector.SK.FinRed.Dluhy` | 🟡 STŘEDNÍ-NÍZKÁ | Dual-view existuje, anomálie minimální. Doplnit `database-model.md`. |
| `Connector.Ares.API` | 🔴 VYSOKÁ-složité | Nejvíc dokumentace, ale rozdrobená. Konsolidovat per-modul `docs/` + povýšit `docs-connectors/` hub. **Naplánovat samostatně.** |

## Co dělat NESMÍŠ

- ❌ Smazat `*.Original` archivní složky
- ❌ Přepsat existující `flow.md` / `analysis.md` jen kvůli „uklidu"
- ❌ Vymyslet anomálie, které nejsou v kódu (jen migruj reálné)
- ❌ Změnit konvenci pojmenování per connector bez schválení (capital `D` vs. lowercase `d` v `Docs/`)
- ❌ Force-push do main brache po PR
