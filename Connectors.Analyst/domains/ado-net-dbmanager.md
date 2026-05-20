---
module: domains-ado-net-dbmanager
version: 1.0.0
requires: [core/persona]
tags: [domain, ado.net, dbmanager, stored-procedures, transactions]
scope: all
updated: 2026-04-27
---

# DataAccess vrstva — `DBManager`, ADO.NET, Stored Procedures

Ekosystém projektu **nepoužívá ORM**. Veškerý DB přístup jde přes `Libs/DBManager/` (tenký ADO.NET wrapper) a stored procedures. Tento dokument je referenční manuál pro typické vzory.

## `DBManager` API (cheat sheet)

```csharp
// Vytvoření instance — jednou per connector run
var db = new DBManager.DBManager(connectionString, country: "CZ", project: "Connectors");

// === READ ===
DataSet ds = db.da.GetDataSetFromSP("subjects_GetIdSubjectsByIc", new Dictionary<string, object>
{
    { "@ic", "12345678" }
});
DataTable dt = db.da.GetDataTableFromSP("subjects_GetByPravniForma", parameters);

// === WRITE bez transakce ===
db.da.RunSP("subjects_Nazvy_UpdateByIc", parameters);

// === WRITE s transakcí ===
using var tx = db.transactionDA.BeginTransaction();
try
{
    db.transactionDA.RunSP("subjekts_CreateNewSubjectByIc", pars1, tx);
    db.transactionDA.RunSP("subjects_Adresy_UpdateByIc_Simplified", pars2, tx);
    tx.Commit();
}
catch
{
    tx.Rollback();
    throw;
}

// === OUTPUT parametry ===
var pars = new Dictionary<string, object> { { "@ic", "12345678" } };
var outPars = new Dictionary<string, object> { { "@id_subject", DBNull.Value } };
db.da.RunSPWithOutput("subjekts_CreateNewSubjectByIc", pars, outPars);
int newId = Convert.ToInt32(outPars["@id_subject"]);
```

## Vzory volání SP per typ operace

### CREATE / INSERT s vrácením ID
**SP konvence:** `<entity>s_CreateNew<Entity>By<Klíč>` (např. `subjekts_CreateNewSubjectByIc`)
```sql
CREATE PROCEDURE subjekts_CreateNewSubjectByIc
    @ic NVARCHAR(20),
    @id_subject INT OUTPUT
AS
BEGIN
    INSERT INTO subjects (ic, ...) VALUES (@ic, ...);
    SET @id_subject = SCOPE_IDENTITY();
END
```
C# pattern: `RunSPWithOutput`, vyzvednout `@id_*` z `outPars`.

### UPDATE atomický s kontrolou existence
**SP konvence:** `<entity>s_<Field>_UpdateBy<Klíč>` (např. `subjects_Nazvy_UpdateByIc`)
```sql
CREATE PROCEDURE subjects_Nazvy_UpdateByIc
    @ic NVARCHAR(20),
    @nazev NVARCHAR(MAX)
AS
BEGIN
    UPDATE subjects SET nazev = @nazev, last_check = GETDATE()
    WHERE ic = @ic;
END
```

### Soft-delete / set datum_do
**SP konvence:** `<entity>s_<Field>_SetDatumDo` (např. `subjects_Nazvy_SetDatumDo`)
Soft-delete je standardní pattern v AppDb — `datum_do IS NULL` znamená aktivní záznam.

### Bulk insert (preferovaný pattern při větším objemu)
Vzor: `Connector.SK.FinRed.Dluhy` po CONN-200 optimalizaci.
```csharp
using var bulk = new SqlBulkCopy(connection, SqlBulkCopyOptions.Default, transaction)
{
    DestinationTableName = "[AppDb_SK_Dluhy].[dbo].[Stage_Dluhy]",
    BatchSize = 1000
};
bulk.WriteToServer(dataTable);

// Následně MERGE z Stage do cílové tabulky
db.transactionDA.RunSP("skFinRed_MergeFromStage", null, tx);
```

## Transakční patterny

### Per-document transakce (default)
Nejčastější vzor — chyba u 1 dokumentu nezabije celý běh.
```csharp
foreach (var doc in documents)
{
    using var tx = db.transactionDA.BeginTransaction();
    try { /* save doc */ tx.Commit(); }
    catch { tx.Rollback(); LogError(doc, ex); continue; }
}
```

### Whole-batch transakce (alternativní režim)
Vzor: `Connector.SK.FinRed.NespolehlivyPlatce.RunOneTransaction()` (zakomentovaný, ale viditelný v `flow.md`).
```csharp
using var tx = db.transactionDA.BeginTransaction();
try
{
    foreach (var doc in documents) { /* save doc */ }
    tx.Commit();
}
catch { tx.Rollback(); throw; } // všechno nebo nic
```
**Pozor:** dlouhé transakce blokují ostatní readery → použít jen u malých dávek.

### Cross-DB problém
Vzor: SK.NespolehlivyPlatce updatuje **3 DB** v jednom běhu (AppDb_SK, AppDb_SK_Documents, AppDb_SK_Dluhy → ⚠️ anomálie).

**Doporučení standardu:**
- **Nepoužívat** distribuovanou transakci (MSDTC) — komplikované, fragile.
- **Per-DB transakce + kompenzační logika**: pokud DB2 selže po commit DB1, mít explicit "undo" SP.
- Anomálii dokumentovat v `anomalies.md` (které DB se updatují, jaké je riziko parciálního stavu).

## Časté chyby a antipatterny

| Anti-pattern | Příklad | Lepší způsob |
|---|---|---|
| Dynamický SQL z user inputu | `SqlCommand("SELECT * FROM x WHERE ic = '" + ic + "'")` ⚠️ SbirkaListin má (anomálie) | Parametrizované SP, vždy. |
| `Convert.ToInt32(reader[0])` bez null check | reader vrací `DBNull` | `reader.IsDBNull(0) ? null : reader.GetInt32(0)` |
| `using var conn` v cyklu | otevírá tisíce spojení | Sdílet přes `DBManager` instanci, nebo pool. |
| `tx.Commit()` v `try`, ale `finally` bez `Rollback` | leak | Vzor `using var tx + try/catch tx.Rollback`. |
| `SET @output = ...` v SP, ale `Direction = Input` v C# | bezhlavá hodnota | Explicit `ParameterDirection.Output`. |

## Nástroje pro práci s DB

- **`DbIntrospect`** (skill `dbintrospect` + `tools/dbintrospect.ps1`) — generická introspekce. Použij místo SSMS, když potřebuješ:
  - Najít SP/tabulku (`find-objects`)
  - Vytáhnout definici SP bez SSMS truncation (`dump-procedures`)
  - Snapshot celého schématu (`snapshot`)
  - Najít, které SP volá daný connector (`discover-from-code`)
- **SQL Server Management Studio (SSMS)** — pro ad-hoc dotazy, plán dotazu, debugging. **Pozor:** default truncation `definition` na 4000 znaků, viz workaround v ARES `_scripts/02_*_procedures.sql` komentáři.
- **`DbRepairUtility.SK.FinRed.Dluhy`** — vzor pro pipelines (Fetch→Parse→Pair→Save) s DryRun.

## Reference do reálných connectorů

| Vzor | Otevři |
|---|---|
| Standardní DA třída (single-DB) | `Connector.CZ.RejstrikPravnichOsob/src/.../DataAccess/RpvDA.cs` |
| Multi-DA (3 DB) | `Connector.SK.FinRed.NespolehlivyPlatce/src/.../DataAccess/` (`SkFinRedDA`, `AppEntityDA`, `BussinessInfoDA`) |
| Bulk + MERGE optimalizace | `Connector.SK.FinRed.Dluhy/src/.../DataAccess/` (po CONN-200) |
| Sdílená SP knihovna napříč moduly | ARES `Downloader.Common/AppDb/*` (34 SP volaných ES i VR) |
