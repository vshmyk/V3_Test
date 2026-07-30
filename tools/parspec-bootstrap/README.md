# Parspec Client Database Bootstrap

Baseline tooling for standing up a new client business-layer database from the current MACSII development template.

Naming convention:

- raw Oasis source: `MACS_OASIS` or `OASIS_[ORG_NAME]`
- client business-layer database: `PARSPEC_[ORG_NAME]`
- template source for inherited business logic: `MACS_V2` or current legacy equivalent `MACSII_V2`

## What this bootstrap does

`New-ParspecClientDatabase.ps1`:

- copies `MACSII_V2` into a new `PARSPEC_[ORG_NAME]` database by backup/restore
- stores bootstrap metadata in the target database
- inventories inherited SQL modules that still reference `OASIS_MACSII` or `MACSII_V2`
- optionally rewrites those module definitions to point at:
  - `OASIS_[ORG_NAME]`
  - `PARSPEC_[ORG_NAME]`

This is intended as the baseline starting point for all 15 client organizations.

## Current template assumptions

Reviewed on `.\ERPLINK` on `2026-07-21`:

- intended canonical template business-layer DB: `MACS_V2`
- intended canonical raw DB: `MACS_OASIS`
- intended canonical target DB: `PARSPEC_MACSII`
- current live equivalents still present on the server:
  - `MACSII_V2`
  - `OASIS_MACSII`
- raw Oasis DBs already present on the server include:
  - `OASIS_MACSII`
  - `OASIS_FLUX`
  - `OASIS_MERCER1`
  - `OASIS_MH`
  - `OASIS_PLS`
  - `OASIS_PROLUX`
  - `OASIS_SALEX`
- `MACSII_V2` object surface:
  - `AO`: `47` objects
  - `dbo`: `67` objects
  - `SRC`: `109` objects
- inherited SQL modules with hard-coded `OASIS_MACSII` references: `50`
- inherited SQL modules with hard-coded `MACSII_V2` self-references: `30`

That means clone-and-retarget is the right baseline approach for now.

## MACSII baseline command

When the canonical names exist:

```powershell
.\New-ParspecClientDatabase.ps1 `
  -OrgName MACSII `
  -RawDatabaseName MACS_OASIS `
  -TemplateDatabaseName MACS_V2 `
  -TargetDatabaseName PARSPEC_MACSII `
  -RetargetModuleReferences
```

With the current live legacy-equivalent names on `.\ERPLINK`:

```powershell
.\New-ParspecClientDatabase.ps1 `
  -OrgName MACSII `
  -RawDatabaseName OASIS_MACSII `
  -TemplateDatabaseName MACSII_V2 `
  -TargetDatabaseName PARSPEC_MACSII `
  -RetargetModuleReferences
```

## Usage

Dry run:

```powershell
cd C:\Users\vshmyk\AOprojects\AOtransact\tools\parspec-bootstrap
.\New-ParspecClientDatabase.ps1 -OrgName PLS -WhatIf
```

Create the database and bootstrap metadata only:

```powershell
.\New-ParspecClientDatabase.ps1 -OrgName PLS
```

Create the database and retarget inherited module references:

```powershell
.\New-ParspecClientDatabase.ps1 -OrgName PLS -RetargetModuleReferences
```

Custom database names if needed:

```powershell
.\New-ParspecClientDatabase.ps1 `
  -OrgName CLIENTA `
  -RawDatabaseName OASIS_CLIENTA `
  -TargetDatabaseName PARSPEC_CLIENTA `
  -RetargetModuleReferences
```

## What gets created in the target database

- `dbo.ParspecBootstrapConfig`
- `dbo.ParspecModuleReferenceInventory`

These hold:

- the template/raw/target naming
- the bootstrap timestamp
- the inventory of inherited modules that reference old database names

## What this does not do yet

- create Parspec API-side objects
- populate `src.*` with client data
- validate that all client-specific linked databases exist
- reconcile organization-specific AO/account/user differences
- regenerate mappings from the Excel workbook automatically

## Current MACSII scope exclusions

For `PARSPEC_MACSII`, these inherited origin procedures are intentionally ignored and are not part of the Parspec migration baseline:

- `SRC.EmployeeIncentive_Origin`
- `SRC.ProjectContact_Origin`

## Recommended rollout order

1. Create the raw source database for the client, preferably `MACS_OASIS`-style or `OASIS_[ORG_NAME]`.
2. Clone the active business-layer template, preferably `MACS_V2` or current legacy `MACSII_V2`, to `PARSPEC_[ORG_NAME]`.
3. Retarget inherited module references from the template raw DB to the client raw DB.
4. Run source object validation, starting with:
   - `SRC.Account_Origin`
   - `SRC.Contact_Origin`
   - `SRC.Project_Origin`
   - `SRC.PurchaseOrder_Origin`
   - `SRC.PurchaseOrderItem_Origin`
5. Run object-by-object Parspec migration scans from the new client database context.
