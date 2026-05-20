---
module: knowledge-nuget-and-stack
version: 1.0.0
requires: []
tags: [knowledge, nuget, stack, technology]
scope: all
updated: 2026-04-27
---

# NuGet a technologický stack

## Hlavní NuGet balíčky napříč connectory

| Balíček | Verze | Použití | Connectory |
|---|---|---|---|
| `BaseConnector` | 1.1.6 – 1.2.x | Bázová třída connectoru | RPV, SbirkaListin, FinRed.* |
| `DBManager` | 2.1.3 – 2.2.x | ADO.NET wrapper | všechny (přímo nebo přes BaseConnector) |
| `CoreFramework` | 2.4.x | Proxy, task dist., logger, hash, address, zip | všechny |
| `Rating` | 1.0.0 | Skórování | všechny |
| `Messaging` | 1.1.0 | Email, log | BaseConnector |
| `Microsoft.Extensions.Configuration*` | 7.0.0 / 9.0.0-preview | JSON appsettings | všechny moderní |
| `HtmlAgilityPack` | 1.11.61 | HTML scraping (or.justice.cz) | SbirkaListin |
| `iTextSharp` | 5.5.13.3 | PDF parsing (FinRed Dluhy PDF přílohy) | SK.FinRed.Dluhy |
| `Microsoft.Data.SqlClient` | (plán) | Modern ADO.NET klient | `DbIntrospect` |
| `System.Data.SqlClient` | 4.8.6 | Legacy ADO.NET | `DBManager` (netstandard2.0) |
| `RestSharp`, `Newtonsoft.Json`, `JsonSubTypes` | dle OpenAPI gen | ARES SDK | `Connector.Ares.API` (auto-gen) |

## Co v projektu **NENÍ** (záměrně nebo k zvážení)

| Balíček | Důvod absence | Doporučení |
|---|---|---|
| Entity Framework Core | Záměr — drží se ADO.NET + SP | **Nezavádět**. |
| Dapper | Záměr — drží se ADO.NET + SP | **Nezavádět** v core connectorech. (V CLI tools by mohl pomoct.) |
| Polly | Historický nedostatek | **Zvážit** při příštím dotyku connectoru, který volá nestabilní API (ARES, or.justice.cz). |
| Serilog / NLog | Záměr — používá se `Messaging` logger | V `DbIntrospect` chceme `Serilog` (vzor: `DbRepairUtility`). |
| MediatR / CQRS | Over-engineering pro batch ETL | **Nezavádět**. |
| OpenTelemetry | Není observability tlak | Zvážit pro production monitoring v budoucnu. |
| FluentValidation | Validace probíhá v SP / přímo v kódu | Zvážit pro CLI argumenty (System.CommandLine to řeší jinak). |
| xUnit / NUnit | Connectory dnes nemají unit testy | **Doplnit** při refaktoringu kritických tříd (BaseConnector, DBManager). |

## Stack pro `DbIntrospect` (CLI tool)

| Vrstva | Volba | Důvod |
|---|---|---|
| Runtime | .NET 8 | Aligned se zbytkem moderních connectorů |
| ADO.NET klient | `Microsoft.Data.SqlClient` | Modern, supported |
| CLI parser | `System.CommandLine` | Standard od MS, no third-party |
| Logging | `Serilog` (Console + File sink) | Vzor `DbRepairUtility` |
| Konfigurace | `Microsoft.Extensions.Configuration.Json` + env vars | Standard |
| Code analyzer (DiscoverFromCode) | Regex (start) → Roslyn (pokud bude potřeba) | Začít jednoduše |
| Container | Docker multi-stage | Vzor `DbRepairUtility/Dockerfile` |

## Konvence pojmenování

- **Connector projekty**: `Connector.<Country>.<Source>` (např. `Connector.CZ.RejstrikPravnichOsob`) nebo `Connector.<Source>.API` (ARES — historické).
- **Stored procedures**: 
  - AppDb: `subjekts_*`, `subjects_*`, `task_*` (camelCase a snake_case mix — historicky)
  - AppDb_Documents_AresOr: `SaveSourceDocumentToDB`, `UpdateSourceDocumentStatus` (PascalCase)
  - AppDb_SK_*: `skFinRed_*` (camelCase)
- **Tabulky**: PascalCase nebo snake_case dle DB (AppDb: snake_case, AppDb_SK: PascalCase)
- **C# DataAccess třídy**: `<Domain>DA` (např. `SkFinRedDA`, `AppEntityDA`, `CommonDA`)
