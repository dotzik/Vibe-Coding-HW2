# DOC-WORKFLOW — Jak vytvořit dokumentaci nového connectoru

> Použít pro **nový** connector bez existující dokumentace. Pro povýšení existující dokumentace viz [`UPGRADE-GUIDE.md`](./UPGRADE-GUIDE.md).

## Cíl

Vytvořit **6 dokumentů** v `<connector>/docs/` (nebo `Docs/` capital D — konvence per connector):

1. `README.md` — index + mermaid mapa komponent
2. `analysis.md` — účel, tech, architektura, datové objekty, DA vrstva
3. `flow.md` — procesní flow (sekvence, flowcharty, state machine)
4. `stored-procedures.md` — SP přehled, ER per DB, parametry
5. `database-model.md` — kompletní DB model
6. `anomalies.md` — registr ⚠️ (i prázdný, jen header)

## Postup

### Fáze 0 — Příprava

```bash
mkdir -p path/to/connector/docs
cd path/to/connector/docs
```

Zkopíruj šablony:
```bash
PROFILE=${PROJECT_ROOT}/Connectors.Analyst
cp $PROFILE/templates/connector-docs/*.tmpl ./
# přejmenuj .tmpl → .md
for f in *.tmpl; do mv "$f" "${f%.tmpl}"; done
```

### Fáze 1 — Discovery (CLI, žádná DB)

```bash
# DbIntrospect CLI = interní nástroj (mimo profil snapshot); volá se přes wrapper:
pwsh $PROFILE/tools/dbintrospect.ps1 -Mode discover-from-code \
    -Connector <your-connector>
```

Výstup:
- `sp-names.txt` — vstup pro další krok
- `sp-discovery.md` — detail volání (kde, na kterém řádku)

### Fáze 2 — Snapshot DB (CLI, vyžaduje DB)

```bash
# Connection string řeší CLI sám (appsettings.Local.json / env var / --connection)
pwsh $PROFILE/tools/dbintrospect.ps1 -Mode snapshot -Database <DBName>
```

Pokud connector používá víc DB, opakuj per DB.

### Fáze 3 — Vyplnění šablon

| Dokument | Vstup | Pomoc agenta |
|---|---|---|
| `README.md` | Manuálně | „Vygeneruj README.md pro `<connector>` z výstupu discovery a struktury složky" |
| `analysis.md` | Code reading | „Otevři hlavní `Connector.cs` a vyplň analysis.md sekce 1-7" |
| `flow.md` | Code reading | „Vyplň flow.md sekvenci podle hlavní `Run()` metody" |
| `stored-procedures.md` | Discovery + snapshot | „Spoj `sp-discovery.md` s daty ze `snapshots/.../procedures/` a vygeneruj tabulku v stored-procedures.md" |
| `database-model.md` | Snapshot | „Z `snapshots/.../tables/` a `procedures/` vygeneruj `database-model.md` podle šablony" |
| `anomalies.md` | Manuálně (může být prázdné) | „Projdi anomálie zmíněné v code commentech a vyplň `anomalies.md`" |

### Fáze 4 — Cross-link a review

1. **README.md** — uprav „Where to start" tabulku se skutečnými situacemi pro tento connector.
2. **Cross-linky** — `analysis.md` → `flow.md` (sekce 4 architektura referencuje sekvenci v flow), `stored-procedures.md` → `database-model.md` (SP tabulka odkazuje do detailu DB modelu).
3. **Per-ticket složka** — pokud existují historické analýzy/bug investigations, vytvoř `Ana-CONN-NNN/` složku ze šablony `templates/analysis-folder/`.

### Fáze 5 — Pull request

```bash
git add path/to/connector/docs/
git commit -m "docs: vytvoř dokumentaci pro <connector> (best-of standard)"
```

Kód review: minimálně 1 reviewer, který zná connector. Šablona PR popisu:

```markdown
## Co se přidává
- 6 dokumentů v `<connector>/docs/` podle best-of standardu
- 1 snapshot DB v `<connector>/docs/snapshots/<date>/`

## Standard
Šablony a recept v `Connectors.Analyst/templates/connector-docs/`.

## Verifikace
- [ ] Všechny mermaid diagramy se renderují
- [ ] Všechny `path/to/file.cs:line` reference odpovídají reálnému kódu
- [ ] DDL snapshot odpovídá produkční DB k datu <YYYY-MM-DD>
- [ ] `anomalies.md` neobsahuje fiktivní anomálie (pokud žádné nejsou, header + prázdná tabulka)
```

## Časový odhad

| Fáze | Čas |
|---|---|
| 0 — Příprava | 5 min |
| 1 — Discovery | 1 min (CLI) |
| 2 — Snapshot | 5 min (CLI, závisí na velikosti DB) |
| 3 — Vyplnění šablon | 2-4h (kritická část, vyžaduje code reading) |
| 4 — Cross-link a review | 30 min |
| 5 — PR | 15 min |
| **Celkem** | **~4-6h** per connector |

## Časté problémy

| Problém                                               | Řešení                                                                                                                     |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `discover-from-code` vrací 0 SP                       | Connector používá nestandardní DA (ne `DBManager`). Doplň pattern do regexu SP extraktoru v `DbIntrospect` CLI.            |
| Snapshot vrací `[MISSING] sp_name`                    | SP existuje v kódu jako string, ale v DB neexistuje. To je validní zjištění — zaznamenat do `anomalies.md` jako 🟠 VYSOKÁ. |
| Velikost `database-model.md` přesahuje rozumný rozsah | Sekce „Tabulky" může mít 50+ tabulek. Zvážit split do `database-model-{db}.md` per DB.                                     |
| Mermaid `erDiagram` má 30+ tabulek                    | Split do logických skupin (subjekty, dokumenty, tasky) v sub-sekcích.                                                      |
