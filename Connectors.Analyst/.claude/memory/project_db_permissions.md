---
name: DB permissions — no CREATE PROCEDURE
description: Vývojáři nemají v dev/prod DB práva na CREATE/ALTER PROCEDURE, takže logika, která by jinak šla do SP, musí být v C# (DataAccess vrstvě).
metadata:
  type: project
---

V projektovém prostředí nemají vývojáři na dev ani prod DB práva na `CREATE PROCEDURE` / `ALTER PROCEDURE`. To se týká všech databází, které konektory používají (`AppDb_ThirdParty`, `AppDb`, `AppDb_CZ_*`, `AppDb_SK_*`). DB servery a přístup viz `state/db-environments.md`.

**Why:** DBA-managed prostředí, oddělené role pro vývojáře. Není to oversight — je to záměrná governance.

**How to apply:**
- Když navrhuji řešení, které by „přirozeně" patřilo do nové SP, navrhnu místo toho **inline SQL v `DataAccess` (`*DA.cs`) přes `DBManager`**.
- Existující SP lze volat a dostávat jejich výstup, ale ne upravit/vytvořit. Pokud SP potřebuje fix, je to ticket na DBA.
- Příklad: CONN-213 / `Connector.CZ.ESIF` — `EsifDA.cs` v session 2026-05-12 přibylo +278 řádků (logika, která by jinak šla do nové SP, je v C#).
- Při refactoringu existující SP volání nepřepisovat „do C# kvůli čistotě" — SP nelze smazat. Pokud je SP nepoužitá, řešit s DBA.

Vztahuje se k: workflow při návrhu DA/Storage vrstvy konektorů.
