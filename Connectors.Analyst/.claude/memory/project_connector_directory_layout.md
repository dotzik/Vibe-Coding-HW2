---
name: connector-directory-layout
description: Connector adresáře v ${PROJECT_ROOT}/Connectors/ mají nested layout Connector.<řetězec>/src/Connector.<řetězec>/, ne flat. Skripty/skills/agents musí resolveovat přes glob.
metadata:
  type: project
---

Adresářová konvence connectorů v `${PROJECT_ROOT}/Connectors/`:

```
Connector.<DOMÉNA>.<NÁZEV>/
└── src/
    └── Connector.<DOMÉNA>.<NÁZEV>/
        ├── *.cs
        ├── docs/
        └── *.csproj
```

Příklad: vstup `SK.NespolehlivyPlatce` → reálná cesta `Connector.SK.FinRed.NespolehlivyPlatce/src/Connector.SK.FinRed.NespolehlivyPlatce/`. Vstupní zkratka uživatele NENÍ identická s adresářovým názvem (chybí prefix `Connector.` a může chybět doménový segment, např. `.FinRed.`).

**Why:** Ověřeno smoke testem doc-validatoru 2026-05-15 na `SK.NespolehlivyPlatce`. Naivní resolve `${PROJECT_ROOT}/Connectors/<input>/` selže — nutný discovery přes glob a fuzzy match.

**How to apply:**
- Při resolve `<connector>` parametru ve skriptech `tools/*.ps1` (funkce `Resolve-Connector` v `tools/_common.ps1`) a navazujících skillech (`/upgrade-docs`, `/onboard-connector`, `/dbintrospect`, `/start-ticket`) **vždy přes glob `Connector.*`** v connectors-root, ne direct path append.
- Match strategie: case-insensitive substring na zbytku po prefixu `Connector.` (např. vstup `SK.NespolehlivyPlatce` matchne `Connector.SK.FinRed.NespolehlivyPlatce`). Pokud více matchů → výpis kandidátů a žádost o disambiguaci.
- Po resolve `Connector.<X>/` ještě sestoupit do `src/Connector.<X>/` — tam je `*.cs`, `docs/`, `*.csproj`.
- `docs/` adresář connectoru: `Connector.<X>/src/Connector.<X>/docs/`.
- Cross-consistency-check inventura: `list_directory Connectors/` → filtr `Connector.*` → pro každý dohledat `src/Connector.*/docs/`.
