# AOtransact Project Summary

Last updated: 2026-08-08 UTC

## Purpose

`AOtransact` is a SQL- and integration-driven tooling repo with four important active areas:

- `tools/transactions-loader`
- `tools/integramaster-v3`
- `tools/offline-log`
- `tools/parspec-migrator`

The current strategic projects are:

- the redesign of `INTEGRAMASTER_V2` into `INTEGRAMASTER_V3`
- the Oasis/MACSII to Parspec migration flow in `tools/parspec-migrator`
- continued maintenance on the active Purchase Order History V2 SQL logic

This file is intended as the top-level handoff for a future Codex session.

## Repo Identity

- Repo root: `C:\Users\vshmyk\AOprojects\AOtransact`
- Git branch during the latest V3 work: `main`
- Primary live SQL instance used for validation: `LOCALHOST\ERPLINK`
- Resolved SQL Server name from validation runs: `CENTERA-DEV\ERPLINK`

## Main Workstreams

### 1. INTEGRAMASTER_V3

Primary area:

- [tools/integramaster-v3](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3)

Goal:

- redesign `INTEGRAMASTER_V2` into a reusable metadata-driven integration engine for future projects
- do not redesign the transaction log loader as part of this work

Current live V3 database:

- `INTEGRAMASTER_V3`

Current runtime schema:

- `rt`

Meaning of `rt`:

- `runtime`

### 2. Purchase Order History V2

Primary area:

- [tools/transactions-loader](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader)

This is still active production-style SQL work, especially around Purchase Order History snapshots, diffing, notifications, and retention.

### 3. Offline Log / Hybrid Recovery

Primary area:

- [tools/offline-log](C:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log)

This remains a separate log/mining toolchain and is not the current center of the V3 integration-engine redesign.

### 4. Parspec Migration

Primary area:

- [tools/parspec-migrator](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator)

Goal:

- migrate Oasis/MACSII business-layer data into Parspec object-by-object
- use `PARSPEC_MACSII.src.*` as the primary business source
- fall back to raw `OASIS_*` tables only when the business layer does not expose enough data
- keep migration payloads deterministic and restart-safe through stable ERP/CRM identifiers

## Top-Level Layout

Important directories:

- [tools](C:/Users/vshmyk/AOprojects/AOtransact/tools)
- [tools/parspec-migrator](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator)
- [AOtransact.Database](C:/Users/vshmyk/AOprojects/AOtransact/AOtransact.Database)
- [AOtransact.Sae](C:/Users/vshmyk/AOprojects/AOtransact/AOtransact.Sae)
- [installer](C:/Users/vshmyk/AOprojects/AOtransact/installer)
- [_thirdparty](C:/Users/vshmyk/AOprojects/AOtransact/_thirdparty)
- [output](C:/Users/vshmyk/AOprojects/AOtransact/output)

Important note:

- `tools` contains the actual working source files
- `output` contains generated or deployment-oriented artifacts

## INTEGRAMASTER_V3 Overview

### Design intent

V3 is intended to replace the V2 object-sync engine with a more explicit, metadata-driven runtime that separates:

- client/configuration metadata
- source capture
- current source state
- delta tracking
- work planning
- batching
- dispatch
- canonical object state

It should become reusable for future projects, not just a refactor of the current PLS integration.

### Current source of truth files

- [INTEGRAMASTER_V3.Database.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Database.sql)
- [INTEGRAMASTER_V3.Metadata.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Metadata.Bootstrap.sql)
- [INTEGRAMASTER_V3.Runtime.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Runtime.Bootstrap.sql)
- [INTEGRAMASTER_V3.RuntimeNotes.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RuntimeNotes.md)
- [INTEGRAMASTER_V3.MetadataReview.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.MetadataReview.md)
- [INTEGRAMASTER_V3.UpdateAll.Design.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.UpdateAll.Design.md)

### Metadata model

V3 replaced the V2 generic metadata model with these normalized tables:

- `cfg.IntegrationClient`
- `cfg.ConnectionProfile`
- `cfg.ClientSetting`
- `cfg.ClientSecretReference`
- `meta.SyncObject`
- `meta.SyncObjectOperation`
- `meta.SyncObjectHook`
- `meta.SyncObjectSetting`
- `meta.FieldMap`

Design rationale is documented in:

- [INTEGRAMASTER_V3.MetadataReview.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.MetadataReview.md)

### Runtime tables

Current deployed V3 runtime tables:

- `rt.PipelineRun`
- `rt.ObjectRun`
- `rt.ObjectRunStep`
- `rt.SourceSnapshotRun`
- `rt.SourceSnapshotRow`
- `rt.SourceCurrent`
- `rt.SourceDelta`
- `rt.ObjectState`
- `rt.WorkSet`
- `rt.WorkItem`
- `rt.BatchRequest`
- `rt.BatchRequestItem`

### Runtime procedures

Current deployed V3 runtime procedures:

- `rt.PlanPipelineRun`
- `rt.RefreshSourceStage`
- `rt.CaptureSourceSnapshot`
- `rt.CreateSyntheticSourceSnapshot`
- `rt.ExecutePlannedSourceSnapshots`
- `rt.PlanObjectWork`
- `rt.ExecutePlannedWorkPreparation`
- `rt.BuildBatchRequests`
- `rt.ExecutePlannedBatchPreparation`
- `rt.DispatchBatchRequest`
- `rt.ExecutePlannedBatchDispatch`
- `rt.RebaselineObjectStateFromSourceCurrent`

### Runtime views

Current deployed V3 runtime views:

- `rt.vw_SyncObjectOperationMask`
- `rt.vw_PipelinePlanSummary`
- `rt.vw_WorkPlanSummary`
- `rt.vw_BatchRequestSummary`
- `rt.vw_DispatchResultSummary`

## Current V3 Runtime Behavior

### Planning

`rt.PlanPipelineRun` creates durable pipeline/object/step rows and produces a queryable execution plan.

### Source refresh

`rt.RefreshSourceStage` is the V3 wrapper for source refresh.

Current behavior:

- resolves client and object metadata from `ObjectRun`
- chooses refresh mode from `meta.SyncObjectSetting` or `cfg.ClientSetting`
- defaults to `legacy_v2_updatesourcetable`
- currently calls `INTEGRAMASTER_V2.dbo.UpdateSourceTable` under the hood

Important implication:

- V3 now orchestrates source refresh itself
- but the underlying source stage build still temporarily uses V2 loader logic

### Source capture

`rt.CaptureSourceSnapshot` reads from the configured `src` stage table and:

- derives business keys from `meta.FieldMap`
- prefers metadata-defined hash fields from `SourceHashOrder`
- falls back to stage `RowHash` only if metadata does not define a hash surface
- updates bounded current source state in `rt.SourceCurrent`
- writes inserts/updates/deletes to `rt.SourceDelta`
- keeps a durable audit header in `rt.SourceSnapshotRun`

Important design change:

- normal live captures do not materialize full row history in `rt.SourceSnapshotRow`
- `rt.SourceCurrent` is bounded current state
- `rt.SourceDelta` is the change history

### Work planning

`rt.PlanObjectWork` compares `rt.SourceCurrent` to `rt.ObjectState` and produces only real inserts/updates/deletes in `rt.WorkItem`.

### Batching and dispatch

`rt.BuildBatchRequests` creates durable outbound batches from planned work.

`rt.DispatchBatchRequest` currently supports only:

- `simulate`

It still reconciles successful simulated outcomes into `rt.ObjectState`.

### Rebaseline

`rt.RebaselineObjectStateFromSourceCurrent` exists to realign canonical object state after hash-policy changes.

Important rule:

- only use it after a fresh live source capture for the same object

## Validated V3 Results

### PurchaseOrder

`PurchaseOrder` is the main fully validated pilot.

Validated behavior:

- live source capture works
- work planning works
- batch preparation works
- simulated dispatch works
- object-state reconciliation works
- idempotent reruns work
- synthetic change tests work
- live raw-source change tests work
- source refresh is now orchestrated through `rt.RefreshSourceStage`

Observed production-scale baseline:

- `PLS.src.PurchaseOrder` row count captured: about `92,973`

Important validated milestones:

- pipeline run `7`: simulated dispatch completed and materialized `92,973` `rt.ObjectState` rows
- pipeline run `9`: idempotent rerun planned `0` inserts and `0` updates
- pipeline run `10`: synthetic test planned `1` update and `1` insert
- `2026-06-21`: rebaseline realigned `92,973` active `PurchaseOrder` state rows
- after rebaseline, a no-change live capture planned `0` updates
- after rebaseline, a single-row live `CHSC_PO.PONUMBER` change produced `1` `rt.SourceDelta` row and `1` planned update work item
- `2026-06-23`: `rt.RefreshSourceStage` was deployed and validated through pipeline run `24`

Measured steady-state one-row live test after rebaseline:

- V2-backed source refresh through V3 wrapper: about `15.8s`
- V3 pipeline planning: about `33 ms`
- V3 source capture: about `2.4s`
- V3 work preparation: about `0.5s`

Conclusion:

- the main bottleneck is still source-stage refresh
- not V3 change capture
- not V3 work planning

### PurchaseOrderItem

`PurchaseOrderItem` is not yet fully baselined in V3.

Status discovered on `2026-06-29`:

- no prior `rt.SourceCurrent` rows
- no prior `rt.ObjectState` rows
- capture currently fails on duplicate business keys before any `rt.SourceDelta` rows are written

Current blocker:

- the configured `IsSourceMatchKey` set for `PurchaseOrderItem` is not unique

Observed duplicate-key findings:

- `63` duplicate business keys
- `130` rows participating in duplicate groups
- max duplicate group size: `3`

Strong candidate fix:

- include `ShipmentLineUID` in the `PurchaseOrderItem` source match key

Observed effect of that candidate:

- duplicate business keys dropped to `0` in testing

Current implication:

- if a user says they updated `src.PurchaseOrderItem`, that update has not yet been captured in V3 unless this key issue is fixed first

### QuoteItem

`QuoteItem` has been included in example planning work but is not yet validated end-to-end like `PurchaseOrder`.

## Important V3 Limitations

Still not implemented:

- real destination transport beyond `simulate`
- expression-driven outbound values where future clients need richer computed outbound fields
- actual hook execution phases like `PreObject`, `SourcePostLoad`, `StatePostLoad`, `FinalizeObject`
- retention/purge policy for `rt.SourceDelta`

Important operational caveats:

- synthetic source tests mutate `rt.SourceCurrent` for the selected object
- a later live capture restores the real current-state cache
- if canonical state was seeded under an older hash surface, broad false updates can appear until rebaseline is run

## Important V3 Test Assets

- [INTEGRAMASTER_V3.ChangeCaptureTest.PurchaseOrder.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.ChangeCaptureTest.PurchaseOrder.sql)
- [INTEGRAMASTER_V3.RebaselineObjectState.PurchaseOrder.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RebaselineObjectState.PurchaseOrder.sql)
- [INTEGRAMASTER_V3.RealSourceUpdateTest.PurchaseOrder.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RealSourceUpdateTest.PurchaseOrder.sql)

## Purchase Order History V2 Overview

Primary editable source:

- [PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql)

Primary V2 summary:

- [tools/transactions-loader/SUMMARY.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/SUMMARY.md)

Recent important maintenance/deployment artifact:

- [PurchaseOrderHistoryV2.ProdDeploy.20260626.DeleteLatestAndRetain5Runs.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/output/PurchaseOrderHistoryV2.ProdDeploy.20260626.DeleteLatestAndRetain5Runs.sql)

That 2026-06-26 script is a broad maintenance script for V2 PO snapshot retention and latest-run deletion behavior.

Important note:

- the V2 PO-history subsystem is still active and separate from the V3 integration-engine redesign
- V3 work should not casually rewrite or replace this subsystem

## Offline Log Overview

Primary documentation:

- [tools/offline-log/README.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/README.md)

High-level purpose:

- collect committed DML from SQL Server logs
- build live manifests from `fn_dblog` or `fn_full_dblog`
- match offline LDF bytes
- convert activity into `.trn` outputs

This remains part of the repo but was not the main area of change in the latest V3 sessions.

## Important Environment-Specific Facts

These matter a lot in future sessions:

- live V2 and V3 validation used `LOCALHOST\ERPLINK`
- `INTEGRAMASTER_V3` exists on `CENTERA-DEV\ERPLINK`
- `OASIS_PLS` exists on that same instance
- `PLS.src.*` stage tables are live source-stage inputs for V3 capture
- `rt.RefreshSourceStage` still routes to `INTEGRAMASTER_V2.dbo.UpdateSourceTable` by default

Do not assume:

- another machine has the same SQL instance name
- another machine has the same DB names
- another machine has the same filesystem paths

## Parspec Migration Overview

Primary documents and code:

- [tools/parspec-migrator/Program.cs](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/Program.cs)
- [tools/parspec-migrator/README.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/README.md)
- [tools/parspec-migrator/PARSPEC_MIGRATION_CHECKLIST.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/PARSPEC_MIGRATION_CHECKLIST.md)

Active source and environment assumptions:

- working source tenant for development is `PARSPEC_MACSII`
- business logic is inherited from `MACSII_V2` and can be extended where needed
- raw fallback source is `OASIS_MACSII`
- live SQL Server is on the local `ERPLINK` instance used in prior sessions
- active Parspec target for development is the Minor staging sandbox

Core migration rules established so far:

- every Oasis `Bid` should migrate to a Parspec `BOM`
- only bids that were actually quoted should later migrate to a Parspec `Quote`
- pre-bid records remain `BOM` only
- `src.*` business-layer objects are the primary source of truth
- raw `oasis.*` tables are used only to fill business-layer gaps

Current object model being targeted in Parspec:

- `Location`
- `Manufacturer`
- `Product`
- `Company`
- `Contact`
- `Project`
- `Opportunity`
- `BOM`
- `Quote` once public create APIs are available
- `BOM line` once public write APIs are available

Important API findings from the Parspec API Guide and runtime validation:

- the working guide is the Centera Phase 1 ingestion guide, last updated `2026-07-27`
- use `v2` endpoints by default
- unknown JSON fields are silently ignored, so every write should be validated with a follow-up `GET`
- users are not created through the current public API
- opportunities have no `erpId`
- opportunities cannot be deleted through the public API
- the currently validated BOM API supports header-level work only
- BOM line and Quote line public write APIs were not available in the validated materials
- purchase orders, sales orders, and quotes were still described as system-generated/read-only in the validated public materials
- live runtime testing showed nested `v2` BOM endpoints supported `GET` and `PATCH`, but not `DELETE`

Parspec product understanding gathered from help-center review:

- the app workflow is centered around `Project -> Opportunity -> BOM`
- quotes are downstream/generated from BOM work rather than the primary standalone authoring object
- BOMs can be associated with multiple customers
- sections/lots/scopes matter for future BOM-line modeling

Implemented migrator commands in `Program.cs`:

- `users-scan`
- `users-probe-api`
- `users-match-parspec`
- `users-patch`
- `locations-scan`
- `companies-scan`
- `companies-create`
- `companies-create-all`
- `contacts-scan`
- `contacts-create`
- `contacts-create-all`
- `manufacturers-scan`
- `manufacturers-create`
- `manufacturers-create-all`
- `projects-scan`
- `projects-create`
- `projects-create-all`
- `opportunities-scan`
- `opportunities-create`
- `opportunities-create-all`
- `boms-scan`
- `boms-create`
- `boms-create-all`
- `bom-lines-scan`
- `purchase-orders-scan`

Current source-to-Parspec mapping stance by object:

- `Users`: inspect/match/patch only because public create is not available
- `Companies`: sourced from `src.Account`
- `Contacts`: sourced from `src.Contact` with raw Oasis fallback when required
- `Manufacturers`: sourced from `src.Account`
- `Projects`: sourced from `src.Project`
- `Opportunities`: sourced from `src.Bid`
- `BOM headers`: sourced from `src.QuoteItem` grouped by bid/quote context
- `BOM lines`: sourced from `src.QuoteItem`
- `Purchase Orders`: sourced from `src.PurchaseOrder` and `src.PurchaseOrderItem`

Important source-side decisions already made:

- ignore `SRC.EmployeeIncentive_Origin`
- ignore `SRC.ProjectContact_Origin`
- use `src.PurchaseOrder` for PO headers
- use `src.PurchaseOrderItem` for PO lines
- expose raw project/bid-package data through the business layer when needed
- `EstimatedValue = Project.Valuation`
- `TotalQuoted = Project.Sell`
- `projectStakeholders` should map from `ProjectAccount` and should reflect accounts associated with the last active Oasis bid

Important mapping fixes and refinements already identified:

- `squareFootage` should come from `OASIS_MACSII.oasis.CHSC_PROJECT` and related bid-package context exposed through the business layer
- `submittalDueDate` can use `CHSC_QUOTE.EXPIRATIONDATE` for the Quote-header plan
- Quote/BOM `stage` should correspond to `src.Bid.BidStatus`
- BOM customer associations must resolve to distributor accounts only
- contractor companies were previously leaking into BOM customer fields and that source-side filter was corrected
- `primaryCustomer` and `secondaryCustomer` are distributor companies
- `primaryContact` / `secondaryContact` are customer-side contacts, not internal Parspec users
- `CHSC_QUOTEDISTRIBUTORCONTACT` is the likely source for quote-side external contacts
- do not map `Awarded By` to winning distributor unless Parspec confirms that semantic meaning

Known object status as of `2026-08-08`:

- users: scan/match/patch flow built; create still unavailable in the public API
- companies: bulk population flow built and used against Parspec
- contacts: bulk population flow built and used against Parspec
- manufacturers: load flow built; follow-up validation in Parspec remains important because manufacturer visibility depends on tenant/runtime behavior
- projects: mapping and readiness work substantially advanced, with stakeholder and square-footage work called out specifically
- opportunities: create flow built
- BOM headers: create flow built and customer-role filtering corrected
- Quote headers: mapped conceptually, but full public create/write workflow remained pending API availability during the validated phase
- BOM lines: source scan and field contract prepared, but public write API availability remained the main blocker during validated work
- purchase orders: scan and source-readiness work implemented; public write support was not yet established in the validated materials

Current source volumes observed in the MACSII working dataset:

- customers: about `2,670`
- contacts: about `4,791`
- manufacturers: about `183`
- projects: about `21,224`
- BOMs: about `31,719`
- quotes/bids: about `54,307`
- BOM lines: about `598,434`
- purchase orders: about `33,973`
- purchase order lines: about `357,608`

Cross-agency planning volumes provided for migration sizing:

- customers: about `2,700`
- contacts: about `5,000`
- manufacturers: about `200`
- projects: about `22,000` across the last 8 years
- BOMs: about `35,000` across the last 8 years
- BOM lines: about `1,000,000` across the last 8 years
- quotes: about `55,000` across the last 8 years
- files: about `620,000` files / `250 GB`
- largest expected file: up to about `3 GB`

Quote-status planning information gathered for Parspec:

- rough open/in-progress quotes: about `6,500`
- rough finalized quotes: about `46,000`
- source `src.Bid.BidStatus` distribution reviewed in detail during the project
- Oasis does not maintain a clean explicit `Won` flag, but won status can be inferred from statuses such as `Ordered`
- all historical BOM lines are expected to migrate for reporting
- most clients want historical quote visibility for up to 5 years
- pending options are likely excludable, but that should still be confirmed tenant-by-tenant

Current scan/report artifacts worth reopening:

- [companies-scan.20260722_000852.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/output/companies-scan.20260722_000852.json)
- [contacts-scan.20260722_044605.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/output/contacts-scan.20260722_044605.json)
- [manufacturers-scan.20260722_054951.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/output/manufacturers-scan.20260722_054951.json)
- [projects-scan.20260722_060625.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/output/projects-scan.20260722_060625.json)
- [companies-create-all.20260722_021552.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/output/companies-create-all.20260722_021552.json)
- [contacts-create-all.20260722_052643.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/output/contacts-create-all.20260722_052643.json)
- [manufacturers-create-all.20260722_060029.json](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/output/manufacturers-create-all.20260722_060029.json)

BOM-line readiness snapshot from prior analysis:

- total candidate lines reviewed: about `598,434`
- resolved first-pass base fields: `11 / 13`
- unresolved items were `productErpId` strategy and the missing/uncertain public write endpoint
- already prepared fields included `bom`, `erpLineId`, `modelNumber`, `description`, `manufacturerErpId`, `quantity`, `unitSellPriceAmount`, `extendedSellPriceAmount`, `pricingPer`, `sellingUom`, and `type`

Purchase-order readiness snapshot from prior analysis:

- total purchase orders reviewed: `33,973`
- total purchase-order lines reviewed: `357,608`
- resolved first-pass base PO fields: `14 / 15`
- the intentionally unresolved item was public write-endpoint availability
- PO/project linkage existed for `20,509` records in the reviewed scan
- line-level part numbers existed for nearly all lines
- tracking numbers existed for a meaningful subset

File-migration assumptions gathered so far:

- extraction will be performed by the Centera side directly from Oasis storage/database
- upload target will be Parspec-provided pre-signed S3 URLs
- expected file types include `msg`, `htm`, `pdf`, `xlsx`, `xml`, `jpg`, `xls`, `rtf`, `doc`, `zip`, `o2o`, `docx`, `xlsm`, `lnk`, `png`, `html`, `ods`, `xltx`, `csv`, `eml`, `enc`, `heic`, `tif`, `jpeg`, `xlt`, `txt`, `svg`, `pptx`, `mht`, `m4v`, `dot`, `dev`, and `odt`
- preserving source project folder hierarchy is still an open design choice; flattening into Parspec project default folders may be acceptable for phase 1 if clients agree

Identifier strategy:

- Oasis commonly uses compound primary keys of 2 to 5 fields
- those compound keys can be concatenated into stable deterministic ERP IDs
- this is important for idempotent retries and batch reruns

Manufacturer catalog/pricing readiness:

- structured manufacturer pricing/catalog data exists in Oasis
- example fields observed include `PARTNUMBER`, `PARTNUMBERNORMALIZED`, `MFGPARTNUMBER`, `UPC`, `SKU`, `DESCRIPTION`, `TYPE`, `BOOKPRICE`, `BOOKCOMMISSION`, and `LEVEL1PRICE` through `LEVEL5PRICE`
- this should be enough to support a future product/master pricing workstream once the final Parspec product-loading scope is agreed

What remained blocked or waiting on Parspec at the end of the validated work:

- public Quote create/write workflow
- public BOM-line write workflow
- final production-ready semantics for Quote-only fields that are not visible in the existing business layer
- final decision on how much historical quote detail should be writable versus archived/read-only in Parspec

## Recommended Next Steps

Highest-value next steps for the next Codex session:

1. Fix `PurchaseOrderItem` business-key metadata by adding `ShipmentLineUID` to the source match key and validate capture.
2. Baseline `PurchaseOrderItem` into `rt.SourceCurrent` and `rt.ObjectState` once key uniqueness is fixed.
3. Continue the Parspec migration in `tools/parspec-migrator` from the current object sequence, with Projects/Opportunities/BOM/Quote/BOM-line work as the active downstream area.
4. Add retention/purge for `rt.SourceDelta`.
5. Decide whether to keep using V2 `UpdateSourceTable` under the V3 refresh wrapper or start introducing object-specific/custom refresh procedures.
6. Implement real destination transport when ready to leave `simulate`.

## First Files To Open In A New Session

1. [SUMMARY.md](C:/Users/vshmyk/AOprojects/AOtransact/SUMMARY.md)
2. [tools/parspec-migrator/PARSPEC_MIGRATION_CHECKLIST.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/PARSPEC_MIGRATION_CHECKLIST.md)
3. [tools/parspec-migrator/Program.cs](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/Program.cs)
4. [tools/parspec-migrator/README.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/README.md)
5. [INTEGRAMASTER_V3.RuntimeNotes.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.RuntimeNotes.md)
6. [INTEGRAMASTER_V3.Runtime.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Runtime.Bootstrap.sql)
7. [INTEGRAMASTER_V3.Metadata.Bootstrap.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/integramaster-v3/INTEGRAMASTER_V3.Metadata.Bootstrap.sql)
8. [tools/transactions-loader/SUMMARY.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/SUMMARY.md)
9. [PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql](C:/Users/vshmyk/AOprojects/AOtransact/tools/transactions-loader/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql)
10. [tools/offline-log/README.md](C:/Users/vshmyk/AOprojects/AOtransact/tools/offline-log/README.md)

## Resume Guidance

If a future session needs to continue this repo quickly:

1. Read this file.
2. Decide whether the active task is `tools/parspec-migrator`, `tools/integramaster-v3`, or `tools/transactions-loader`.
3. For Parspec work, read `tools/parspec-migrator/PARSPEC_MIGRATION_CHECKLIST.md` and inspect the latest output files under `tools/parspec-migrator/output`.
4. For V3 work, read `INTEGRAMASTER_V3.RuntimeNotes.md`.
5. Check the latest `rt.SourceSnapshotRun`, `rt.SourceDelta`, `rt.ObjectRun`, and `rt.WorkSet` rows in `INTEGRAMASTER_V3` when resuming V3.
6. Verify whether the target V3 object already has `rt.SourceCurrent` and `rt.ObjectState` baseline rows.
7. If not, treat the object as not yet baselined before interpreting any “one changed row” claim.
8. For `PurchaseOrderItem`, fix match-key uniqueness before attempting live capture again.
