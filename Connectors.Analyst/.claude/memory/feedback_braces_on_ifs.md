---
name: braces-on-ifs
description: Vždy závorky `{}` u všech if/else/foreach, i jednořádkových.
metadata:
  type: feedback
---

V C# kódu (a obecně) **vždy psát `if`/`else`/`foreach` s `{}` závorkami**, i když jde o jednořádkové tělo. Žádné `if (x) continue;` nebo `if (x) return;` bez bloku.

**Why:** Vzneseno při kroku 4 CONN-213 (2026-05-13) — preference pro konzistenci a bezpečnost (jednoduché přidání druhé řádky bez chyby, snazší debugging breakpointy, defenzivnější styl).

**How to apply:**
- Při psaní nového kódu i refaktoru existujícího — pokud ho píšu já, vždy s `{}`.
- Při čtení existujícího kódu, který má bezbloký styl (např. `EsifDA.cs`), neměnit ho násilně mimo scope úkolu — jen nově přidané řádky drží nové pravidlo.
- Platí pro `if`, `else`, `else if`, `foreach`, `for`, `while`, `do/while`, `using` statement (ne using directive).
