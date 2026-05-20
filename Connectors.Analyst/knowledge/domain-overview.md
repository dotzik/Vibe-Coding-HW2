---
module: knowledge-domain-overview
version: 1.0.0
requires: []
tags: [knowledge, business, context]
scope: all
updated: 2026-04-27
---

# Doménový kontext

## Co platforma dělá

Datová platforma **agreguje informace o firmách z veřejných obchodních registrů** ČR a SK. Connectory periodicky stahují a normalizují data o ekonomických subjektech (identifikace, adresy, statutární orgány, dluhy na daních, příznaky nespolehlivosti) do interních databází, odkud je konzumují navazující produkty.

## Produkty (relevantní pro connectory)

| Produkt | Popis | Connectory, které ho živí |
|---|---|---|
| **Prověřování firem** | Detail firmy z ČR i SK přes web/API | ARES, RPV, Sbírka listin, FinRed |
| **Automatický monitoring** | Sledování změn u vybraných firem | ARES (notifikace), periodické pull connectory |
| **Integrace ERP/CRM** | API nad výstupy connectorů | konzumenti DB výstupů connectorů |

## Datové zdroje a connectory

Inventář connectorů je v `knowledge/connectors-inventory.md`. Z byznys pohledu connectory pokrývají:

- **ČR**:
  - **ARES** (Administrativní registr ekonomických subjektů) — `Connector.Ares.API` (4 sub-moduly: ES, VR, ZM, OrJustice)
  - **Rejstřík právnických osob** — `Connector.CZ.RejstrikPravnichOsob`
  - **Sbírka listin** (or.justice.cz) — `Connector.CZ.SbirkaListin_Archiv`

- **SK**:
  - **FinRed Dluhy** (registr dluhů na daních a clu) — `Connector.SK.FinRed.Dluhy` + `DbRepairUtility`
  - **FinRed Nespolehlivý plátce** (DPH) — `Connector.SK.FinRed.NespolehlivyPlatce`

## Tlak na kvalitu dat

Důsledky špatných dat:
- **False positive** (firma je označena jako nespolehlivá, ale není) → ztráta obchodu
- **False negative** (firma je nesolventní, ale data to neukazují) → finanční ztráta
- **Latence** (data jsou stará) → rozhodování na základě neaktuálních informací

Z toho plyne **engineering důraz**:
- Idempotence connectorů (opakovaný běh nesmí poškodit data)
- Recovery z částečných selhání (jeden subjekt selže → ostatní pokračují)
- Auditovatelnost (každá změna stavu Document má log)
- DDL snapshoty DB modelu (kontroly konzistence schématu mezi prostředími)
