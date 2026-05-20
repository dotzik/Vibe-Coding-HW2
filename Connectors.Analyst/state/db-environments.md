---
module: state-db-environments
version: 1.0.0
tags: [state, database, vpn, environments]
scope: all
updated: 2026-04-27
---

# DB prostředí — servery, přístup, konvence

> **NIKDY nezapisuj hesla / connection strings s credentials do tohoto souboru** (committed v gitu). Hesla patří do `appsettings.Local.json` (gitignored) per connector nebo per CLI nástroj, případně do env vars.

## SK prostředí

**Server:** privátní DB server (hostname/IP per prostředí — drž v env var, ne zde)
**Síť:** privátní rozsah → **vyžaduje VPN**
**Konektivita:**
- ICMP (ping) může být blokovaný firewallem — `ping` na DB server timeoutuje
- TCP 1433 testovat přes PowerShell: `Test-NetConnection -ComputerName <host> -Port 1433 -InformationLevel Quiet`

**Účet pro vývoj/snapshot:** dedikovaný SQL Auth účet s READ access (jméno per prostředí — drž v konfiguraci, ne zde).

**Connection string format pro CLI (bez hesla):**
```
User ID=<user>;Application Name=Connector_SK;Data Source=<host>;PASSWORD=<hidden>;TrustServerCertificate=true;Encrypt=false
```
- `TrustServerCertificate=true` + `Encrypt=false` jsou **nutné** — Microsoft.Data.SqlClient 5.x default vyžaduje TLS, server pravděpodobně self-signed certifikát
- `Initial Catalog` neuvádět — CLI argument `--db` ho přepíše

## DB inventář (SK prostředí)

| DB | Role | Connectory, které ji vlastní/používají |
|---|---|---|
| `AppDb_SK_Dluhy` | Zápisová DB pro FinRed.Dluhy + sourozenci | `Connector.SK.FinRed.Dluhy` (vlastník), tabulky `skUnion_*` `skVzp_*` `socPoj_*` `slovKons_*` patří jiným SK connectorům |
| `AppDb_SK` | Lookup + cross-DB SP storage | sdílená — `appEntity_*`, `app_Lookups`, `app_checks_*`, `appEntity_BussinessInfo` |

## ČR prostředí

> Nezdokumentováno — connection strings v RPV/SbirkaListin/ARES connectorů nebyly zatím poskytnuty. Doplnit při příštím snapshotu CZ DB (`AppDb`, `AppDb_Documents_AresOr`, `AppDb_ThirdParty`).

## Konvence pro nové DB

Při přidání nového prostředí doplň zde:
- Server hostname/IP + síťový rozsah (privátní/veřejný/VPN)
- Konektivita test (ICMP/TCP port)
- Účet (jen jméno, ne heslo)
- DB inventář s rolemi
- Specifika SQL Server verze nebo collation, pokud relevantní
