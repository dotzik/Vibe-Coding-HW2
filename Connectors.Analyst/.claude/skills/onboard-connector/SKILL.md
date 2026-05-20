---
name: onboard-connector
description: AI orchestrace nad skriptem `tools/onboard-connector.ps1` — kostra dokumentace nového connectoru (6 šablon z `templates/connector-docs/` do `<connector>/.../docs/`). Skript dělá render; skill ověří registr proti `REFERENCE.md` a appendne řádek do `knowledge/connectors-inventory.md`. Aktivace `/onboard-connector <name> --registry <key>`.
---

# /onboard-connector

**Hybrid skill.** Render 6 docs šablon dělá `tools/onboard-connector.ps1`.
Tento skill řeší AI část: **validaci registru** proti `REFERENCE.md` a
**zápis do `knowledge/connectors-inventory.md`**. Nevytváří `.csproj` ani C# kód.

## Kdy použít

- Startuje nový connector (nová ČR/SK registr integrace).
- Migrace legacy connectoru bez standardní `docs/` struktury.

Aktivace: `/onboard-connector <name> --registry <key> [--dry-run]`.

## Workflow

1. **Validuj registr** — načti `REFERENCE.md` (vedle tohoto SKILL.md) a ověř,
   že `<key>` je popsaný (`ares`, `or.justice`, `finred`, `nespolehlivy`,
   `rpv`, `sl`, `sl_archiv`, …). Chybí-li, **zastav** a navrhni registr nejdřív
   doplnit — `REFERENCE.md` je single source of truth.

2. **Předlož plán uživateli** (gate) — cílový `docs/`, 6 souborů k vytvoření,
   preview řádku do inventáře. Vyžádej `schvaluji`.

3. **Spusť skript** (po souhlasu; `--dry-run` → `-Preview` lze rovnou):

   ```
   pwsh tools/onboard-connector.ps1 -Connector <name> [-Registry <key>] `
        [-DocsDir <dir>] [-Force] [-Preview]
   ```

   - Skript resolve `docs/` (`src/<name>/docs` apod.), vyrenderuje 6 šablon,
     dosadí `{{ConnectorName}}`. Existující soubory nepřepisuje (`-Force` =
     doplnit chybějící). Úplně nový connector bez adresáře → předej `-DocsDir`.

4. **Append do `knowledge/connectors-inventory.md`** — nový řádek do tabulky
   `## Connectors`: `#` (auto-increment), `Projekt`, `.NET`, `Zdroj dat`,
   `Stav docs` (`🆕 onboarded <datum>`), `Charakteristika` (placeholder).

5. **Souhrn + TODO uživateli** — cesta k `docs/`, vytvořené soubory, a TODO:
   `.csproj` (`dotnet new`), `<Name> : BaseConnector`, `appsettings.json`,
   po prvním běhu `/dbintrospect <name>`, po 2-3 ticketech `/upgrade-docs`.

## Gates

- **1 explicit `schvaluji`** před spuštěním skriptu (vznikne 6 souborů)
  ([`feedback_approval_first`](../../memory/feedback_approval_first.md)).
- **Inventory zápis** ve stejném souhlasu (atomic — kostra + inventář spolu).
- **Registry-first** — žádný edit `REFERENCE.md`; chybí-li registr, jen gap + stop.
- **Žádný Jira/DB write.**

## Notes

- **Dynamic scope** — počet connectorů nikde nehardcodovat, odečíst z adresáře
  ([`project_connectors_dynamic_scope`](../../memory/project_connectors_dynamic_scope.md)).
- **Docs layout** — standard `src/<name>/docs/` (viz
  [`project_connector_directory_layout`](../../memory/project_connector_directory_layout.md));
  skript ho resolve sám, override přes `-DocsDir`.
- **Žádný personifikovaný obsah** v generovaných docs — 3. osoba pasivně
  ([`feedback_no_personification`](../../memory/feedback_no_personification.md)).
- **`Charakteristika`** v inventáři — placeholder, doplní se po prvních ticketech.

## Návaznosti

- **Před:** rozhodnutí o novém connectoru, registr popsaný v `REFERENCE.md`.
- **Po:** `.csproj` + C# implementace → `/dbintrospect` snapshot →
  `/upgrade-docs` po stabilizaci.
