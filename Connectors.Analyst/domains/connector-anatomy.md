---
module: domains-connector-anatomy
version: 1.0.0
requires: [core/persona]
tags: [domain, connector, baseconnector, processinstance, document, task, lifecycle]
scope: all
updated: 2026-04-27
---

# Anatomie connectoru — `BaseConnector`, `ProcessInstance`, `Document`, `Task`

## Architektura na vysoké úrovni

```mermaid
graph TD
    subgraph Libs
        BC[BaseConnector<br/>abstract Connector]
        BC_PI[ProcessInstance<br/>kontext běhu]
        BC_DOC[Document<br/>jeden subjekt]
        BC_CFG[InstanceConfig<br/>JSON]
        DBM[DBManager<br/>ADO.NET wrapper]
    end

    subgraph "Connector.X (konkrétní)"
        IMPL[XConnector : Connector]
        DA[XDataAccess<br/>volání SP]
        PARSER[XParser<br/>XML/HTML/PDF]
    end

    subgraph "Externí"
        API[Veřejný registr<br/>API/HTTP/feed]
        DB[(SQL Server<br/>per-doména DB)]
    end

    IMPL -->|inherits| BC
    IMPL -->|uses| BC_PI
    IMPL -->|produces| BC_DOC
    IMPL -->|reads| BC_CFG
    IMPL -->|via| DA
    IMPL -->|via| PARSER

    DA -->|GetDataSetFromSP / RunSP| DBM
    DBM --> DB
    PARSER --> API
```

## Lifecycle jednoho běhu connectoru

```mermaid
sequenceDiagram
    participant Op as Operátor / Scheduler
    participant Conn as XConnector
    participant PI as ProcessInstance
    participant API as Veřejný registr
    participant Doc as Document
    participant DA as DataAccess
    participant DB as SQL Server

    Op->>Conn: Run(InstanceConfig)
    Conn->>PI: Start(runId, logger)
    Conn->>DA: NactiTaskyKeZpracovani()
    DA->>DB: EXEC tasks_GetPending
    DB-->>DA: tasks[]
    DA-->>Conn: tasks[]

    loop pro každý task
        Conn->>API: Stáhnout data (proxy, retry)
        API-->>Conn: response (XML/HTML/PDF)
        Conn->>Doc: Parse(response)
        Doc->>Doc: Validovat, hashovat
        Conn->>DA: Save(document)
        DA->>DB: EXEC subjekts_CreateNewSubjectByIc, subjects_*
        Conn->>DA: SetTaskStatus(DONE)
    end

    Conn->>PI: Stop(stats)
```

## Klíčové třídy z `BaseConnector` (Libs)

| Třída | Cesta | Role |
|---|---|---|
| `Connector` (abstract) | `Libs/BaseConnector/.../Connector.cs` | Orchestrátor — `Run()`, error handling, logging |
| `ProcessInstance` | `Libs/BaseConnector/.../ProcessInstance.cs` | Kontext jednoho běhu (runId, start/stop, statistika, logger handle) |
| `Document` | `Libs/BaseConnector/.../Document.cs` | Reprezentace 1 zpracovaného subjektu (metadata, payload, status) |
| `InstanceConfig` | `Libs/BaseConnector/.../InstanceConfig.cs` | Deserializovaný JSON config (limity, prahy, prostředí) |
| `Task` | `Libs/BaseConnector/.../Task.cs` | Záznam v queue tabulce — co zpracovat, v jakém stavu |
| `TaskError` | `Libs/BaseConnector/.../TaskError.cs` | Chybový stav tasku — error code, message, kdy |

> **Poznámka.** ARES (`Connector.Ares.API`) má vlastní `Connector` v `Downloader.Common`, **nedědí z `BaseConnector`**. Je to historické (vznikl později). Při refaktoringu zvážit migraci, ale nedělat zbytečně.

## Lifecycle Document a Task (state machine)

```mermaid
stateDiagram-v2
    [*] --> NEW: Task vytvořen
    NEW --> DOWNLOADING: Connector si task převzal
    DOWNLOADING --> DOWNLOADED: API odpověděl
    DOWNLOADING --> FAILED: timeout / 5xx
    DOWNLOADED --> PARSED: Parser uspěl
    DOWNLOADED --> FAILED: parsing error
    PARSED --> SAVED: SP uložily data
    PARSED --> FAILED: SP chyba (deadlock, FK violation)
    SAVED --> DONE: Task uzavřen
    FAILED --> RETRY: do limitu pokusů
    RETRY --> DOWNLOADING
    FAILED --> DEAD: limit překročen
    DONE --> [*]
    DEAD --> [*]
```

Konkrétní hodnoty stavů a transition logika jsou per-connector (viz `flow.md` daného connectoru).

## Vzor implementace nového connectoru

```csharp
public class MyConnector : Connector
{
    private readonly MyDataAccess _da;
    private readonly MyParser _parser;

    public MyConnector(InstanceConfig config) : base(config)
    {
        _da = new MyDataAccess(config.ConnectionString);
        _parser = new MyParser();
    }

    public override void Run()
    {
        using var pi = new ProcessInstance(this);
        var tasks = _da.GetPendingTasks();

        foreach (var task in tasks)
        {
            try
            {
                var raw = DownloadFromApi(task);
                var doc = _parser.Parse(raw);
                _da.Save(doc);
                _da.SetTaskStatus(task.Id, TaskStatus.Done);
            }
            catch (Exception ex)
            {
                _da.LogTaskError(task.Id, ex);
                _da.SetTaskStatus(task.Id, TaskStatus.Failed);
            }
        }
    }
}
```

## Kde co najít v reálných connectorech (pro inspiraci)

| Hledám | Otevři |
|---|---|
| Vzor implementace `Run()` | `Connector.CZ.RejstrikPravnichOsob/src/.../Connector.cs` |
| Dual-view refactoring (původní + optimalizovaný) | `Connector.SK.FinRed.Dluhy/src/.../docs/analysis.md` (CONN-200) |
| Alternativní režim běhu (jeden vs. transactional) | `Connector.SK.FinRed.NespolehlivyPlatce/src/.../Run()` + `RunOneTransaction()` |
| Task distributor / paralelizace | `CoreFramework` (black-box) — volání v ARES `Downloader.Common` |
| HTML scraping pattern | `Connector.CZ.SbirkaListin_Archiv/src/.../Parser.cs` |
| PDF parsing pattern | `Connector.SK.FinRed.Dluhy/src/.../PdfParser.cs` |

## Časté pasti

| Past | Kde se objevuje | Mitigace |
|---|---|---|
| **Cross-DB transakce** | SK.NespolehlivyPlatce updatuje 3 DB | Buď MSDTC (komplikované), nebo per-DB transakce s kompenzací. Standard: per-DB. |
| **`GETDATE()` vs. `DateTime.Now`** | SbirkaListin (anomálie) | Volba musí být konzistentní per task — datum ID je v C#, datum DB záznamu má být `GETDATE()`. |
| **SP volaný s null parametrem** | AppDb má SP s `@param = NULL OUTPUT` | Vždy zkontrolovat, jestli je `@output` typu OUTPUT a parametr má `Direction = ParameterDirection.Output` v C#. |
| **Idempotence při opakovaném běhu** | všechny | Hash dokumentu se ukládá → pokud existuje s tímto hash, skip insert (nebo update jen status). |
