---
module: domains-public-registries
version: 1.0.0
requires: [core/persona]
tags: [domain, registries, ares, rpv, sbirka-listin, finred, or-justice]
scope: all
updated: 2026-04-27
---

# Veřejné registry — doménová znalost

Stručný popis registrů, ze kterých connectory těží data. Detailní byznys kontext je v `knowledge/domain-overview.md`.

---

## ČR

### ARES (Administrativní registr ekonomických subjektů)
**URL:** https://ares.gov.cz/
**Provozovatel:** Ministerstvo financí ČR
**Connector:** `Connector.Ares.API` (4 sub-moduly)
**Cílové DB:** `AppDb` (master subjekty), `AppDb_Documents_AresOr` (raw XML)

**Sub-moduly:**
| Modul | Co poskytuje | AppDb tabulky |
|---|---|---|
| `EkonomickeSubjekty` (ES) | Základní data subjektu — IČ, DIČ, adresa, právní forma, příznaky | `subjects`, `subjects_adresy`, `subjects_nazvy`, `subjects_dic` |
| `VR` (Veřejný rejstřík) | Statutární zástupci, vazby, zápis společníků, kapitál, zástavní právo | `subjects_osoby`, `subjects_vazby`, `subjects_kapital`, `subjects_akcie` |
| `Notifikace` (ZM) | Notifikace o změnách (zdroj 12) — trigger pro retask ES/VR/RŽP | `notifikace_*`, `tasks` |
| `OrJustice` | Doplňková data z or.justice.cz | (overlap se Sbírkou listin) |

**Specifika:**
- API je REST + JSON (od 2019), starší SOAP varianta deprecated.
- OpenAPI specifikace → SDK auto-generován (RestSharp + Newtonsoft.Json + JsonSubTypes).
- ARES je primární source of truth pro CZ subjekty — ostatní connectory odkazují na `subjects.id_subject` přes IČ.

### Rejstřík právnických osob (RPV)
**URL:** veřejný XML feed
**Connector:** `Connector.CZ.RejstrikPravnichOsob`
**Cílové DB:** `AppDb` (sdílená s ARES)

**Specifika:**
- Stahuje XML feed periodicky (denní/týdenní).
- Streamované parsování `XmlReader` (feed je velký, GB+).
- Per-ticket investigation v `Docs/Ana-CONN-229/` (Python skripty pro analýzu XML diffů).
- Tabulky `Rpv_*` (Subject, Vypis, Druh, Trest, Zakon, Paragraf...).

### Sbírka listin (or.justice.cz)
**URL:** https://or.justice.cz/ias/ui/vypis-sl
**Connector:** `Connector.CZ.SbirkaListin_Archiv`
**Cílové DB:** `SbirkaListin`, `AppDb_Documents_AresOr` (overlap)

**Specifika:**
- **HTML scraping** přes `HtmlAgilityPack` (žádné API).
- Proxy rotation (CoreFramework) — anti-bot ochrana or.justice.
- Listiny = PDF přílohy, ukládají se do BLOB.
- ⚠️ Anomálie: SQL injection v query buildingu, zombie SP. Viz `_scripts/_anomalies` v dokumentaci.

---

## SK

### FinRed Dluhy (Finančná správa SK — Dlžníci dane a cla)
**URL:** https://www.financnasprava.sk/sk/elektronicke-sluzby/verejne-sluzby/zoznamy/zoznam-danovych-dlznikov
**Connector:** `Connector.SK.FinRed.Dluhy` + `DbRepairUtility.SK.FinRed.Dluhy`
**Cílové DB:** `AppDb_SK_Dluhy`, `AppDb_SK`, `AppDb_SK_Documents`

**Specifika:**
- XML download + PDF přílohy (iTextSharp parsing).
- **CONN-200 refactoring** — přechod z per-row INSERT na BulkCopy + MERGE (10× rychlejší).
- `DbRepairUtility` — opravný nástroj pro CP1250 → UTF-8 encoding bug v starších XML. Pipeline Fetch→Parse→Pair→Save, DryRun, Docker.
- Velký objem dat (100k+ dlužníků) → batch processing kritický.

### FinRed Nespolehlivý plátce (DPH)
**URL:** https://www.financnasprava.sk/sk/elektronicke-sluzby/verejne-sluzby/zoznamy/zoznam-platitelov-dph
**Connector:** `Connector.SK.FinRed.NespolehlivyPlatce`
**Cílové DB:** `AppDb_SK_NespolehlivyPlatce`, `AppDb_SK`, `AppDb_SK_Documents`

**Specifika:**
- 3 DataAccess třídy (`SkFinRedDA`, `AppEntityDA`, `BussinessInfoDA`) — komplexní cross-DB topologie.
- 6 dokumentovaných anomálií (`SetStatus` updatuje špatnou tabulku, sub-transaction side-effects, nepoužité parametry).
- Alternativní režim `RunOneTransaction()` (zakomentovaný, ale viditelný v `flow.md`).
- Refresh logika `RefreshBussInfoOfAllRecords` + `RefreshDPHFlag` (prioritizovaný rating).

---

## Externí (mimo connectory, kontext)

| Zdroj | Účel | Status |
|---|---|---|
| **CEE** (Centrální evidence exekucí) | 120k dotazů ročně, exekuční check | Externí API, mimo scope `Connectors/` |
| Insolvenční rejstřík (ČR) | Insolvence subjektů | částečně přes ARES VR (`InsolvencniRizeni*` modely) |
| OR Slovensko | SK obchodný register | (mimo aktuální scope) |
| Účetní výkazy | Finanční data | (mimo scope, jiný tým) |

---

## Doménové konvence

| Pojem | Význam |
|---|---|
| **Subjekt** | Právnická osoba (firma), unikátně identifikována IČ |
| **Osoba** | Fyzická osoba (statutár, společník), identifikována RČ/DOB+jméno |
| **Vazba** | Vztah mezi subjektem a osobou (statutár, prokurista, společník, dozorčí rada) |
| **Vypis** | Oficiální výpis z rejstříku v daný čas |
| **Listina** | PDF dokument ze Sbírky listin (účetní závěrka, smlouva, atd.) |
| **Task** | Záznam v queue tabulce — co connector má zpracovat |
| **Notifikace** | Změna v ARES VR / OR, která má vyvolat retask |
| **Dlžník** (SK) | Subjekt s dlužnou částkou na dani/clu |
| **Nespolehlivý platca** (SK) | Subjekt zařazený na seznam nespolehlivých plátců DPH |

## Etika & legalita

- Všechny zdroje jsou **veřejné registry** — sběr legální v rozsahu rate-limitů.
- HTML scraping (or.justice.cz, financnasprava.sk) — respektovat `robots.txt` a frekvenci dotazů (CoreFramework proxy manager to řeší).
- GDPR — fyzické osoby (statutáři) z veřejných registrů jsou v režimu „zveřejněno se zákonem", uložení v naší DB legální. Mazání na žádost subjektu — ad-hoc proces (mimo scope tohoto profilu).
