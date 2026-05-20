---
module: state-filesystem-conventions
version: 1.0.0
tags: [state, filesystem, conventions, always-active]
scope: all
updated: 2026-04-28
---

# Filesystem konvence — kde co leží

Tento dokument definuje **kam patří** scratch soubory, snapshoty, logy a dumpy. Cílem je nemít citlivá data v gitu a mít předvídatelnou strukturu.

## Pravidlo č. 1 — žádné citlivé výstupy do repu

DB snapshoty, dumpy SP, discovery výstupy mohou obsahovat schéma reálné produkční DB (názvy tabulek, sloupců, business logika). **Per default jdou mimo git** přes `.gitignore` v rootu profilu.

Pokud má být snapshot zachován v repu (např. milestone reference), zkopíruj ho explicitně do `Connectors/<connector>/docs/snapshots/<date>/` — to není gitignored, protože je to součást auditu daného connectoru; o zařazení do gitu se rozhoduje per-PR.

## Lokace per typ artefaktu

| Artefakt | Kam patří | Gitignored? |
|---|---|---|
| Lokální connection strings | `DbIntrospect` CLI `appsettings.Local.json` | ✅ |
| Dev/prod connection strings | `DbIntrospect` CLI `appsettings.{Development,Production}.json` | ✅ |
| `.env` pro Docker | `DbIntrospect` CLI `.env` | ✅ |
| Discovery výstupy z `discover-from-code` | `DbIntrospect` CLI `out/discovery-<connector>/` | ✅ |
| DB snapshoty (ad-hoc, lokální) | `DbIntrospect` CLI `snapshots/<date>/` | ✅ |
| Logy (Serilog rolling) | `DbIntrospect` CLI `logs/` | ✅ |
| Build outputs | `**/bin/`, `**/obj/`, `.vs/` | ✅ |
| Scratch / draft markdown | `_scratch/` v profile rootu | ✅ |
| Auditní snapshoty (per connector PR) | `Connectors/<connector>/docs/snapshots/<date>/` | ❌ (commitovat per PR) |
| Per-ticket investigace | `Connectors/<connector>/docs/Ana-CONN-NNN/` | ❌ (commitovat per PR) |
| Šablony, templates | `templates/connector-docs/`, `templates/analysis-folder/` | ❌ |
| State soubory (tento adresář) | `state/*.md` | ❌ |

## Konvence pojmenování

- **Datumy**: `YYYY-MM-DD` (lexikograficky řaditelné)
- **Per-DB output**: `out/<command>-<dbname-or-connector>/`
- **Snapshot adresáře**: `snapshots/<YYYY-MM-DD>/<DBname>/{tables,procedures,functions,triggers}/`
- **Discovery**: `out/discovery-<connector-shortname>/{sp-names.txt,sp-discovery.md}`

## Co dělat při pochybách

1. Obsahuje výstup reálné názvy DB objektů, kolonek, business logiku z prod DB? → `out/` nebo `snapshots/` (gitignored).
2. Je výstup šablona, dokumentace standardu, persona content? → běžná location v repu.
3. Je to per-connector audit pro PR? → `Connectors/<connector>/docs/snapshots/` a explicitní `git add`.
