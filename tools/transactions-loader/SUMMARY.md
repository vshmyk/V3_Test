# V2 Summary

Last updated: 2026-05-08 UTC

## Scope

This file summarizes the current work on Purchase Order History V2 under `tools/transactions-loader`, including:

- the current logic shape
- what has been verified against live `PLS`
- what has been changed locally
- what is still pending deployment or sync

## Current source of truth

- `PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.sql`
  - Canonical editable source for the current `PLS` V2 program objects.
- `output/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.Verified.20260501.sql`
  - Started as a verified copy of live `PLS` V2 logic on `2026-05-01`.
  - This file now also includes later local edits, so it is no longer a pure untouched live dump.
- `output/PurchaseOrderHistoryV2.AlterAllPrograms.20260501.sql`
  - One-file deployment script that alters all current V2 program objects in `PLS`.
- `PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.ForProd.sql`
  - Exists, but is behind the latest diff-view / business-comparison logic.
- `output/PurchaseOrderHistoryV2.ProdDeploy.CurrentLogic.20260514.sql`
  - Focused prod deployment bundle for the current logic.
  - Includes:
    - `SRC.vw_PurchaseOrderItemSnapshotDiffV2`
    - `SRC.PurchaseOrderHistoryDE_V2`
    - `dbo.GetPOitemHistoryStatus_V2`
    - `dbo.GetPOItemHistoryDetailHtml_V2`
    - `dbo.GetPOitemHistory_V2`
- `output/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.ForProd.Refresh.20260514.sql`
  - Full refreshed copy of the current canonical source for prod handoff/reference.

## Current V2 object set

The current V2 logic is implemented by these objects:

- `SRC.vw_PurchaseOrderItemCurrentLogicalV2`
- `SRC.vw_PurchaseOrderItemSnapshotCurrentV2`
- `SRC.vw_PurchaseOrderItemSnapshotDiffV2`
- `SRC.BuildPurchaseOrderSnapshotV2`
- `SRC.PurchaseOrderHistoryDE_V2`
- `SRC.BootstrapPurchaseOrderSnapshotV2FromLegacy`
- `dbo.GetPOitemHistoryStatus_V2`
- `dbo.GetPOItemHistoryDetailHtml_V2`
- `dbo.GetPOitemHistory_V2`

## Current state of the logic

### 1. `SRC.vw_PurchaseOrderItemCurrentLogicalV2`

Purpose:

- Builds the current logical PO row set from `SRC.PurchaseOrderItem`.
- Produces ordered parent rows and scheduled/shipped child rows.

Current behavior:

- Filters to transaction types `O`, `S1`, and `S`.
- Excludes `LOT`, `SELL`, and `PRICE` noise, with the existing `PILOT` exception.
- Derives:
  - `OrderedLineUID`
  - `GroupLineUID`
  - `LogicalChildUID`
  - `SourceLineUID`
  - `SourceShipmentLineUID`
- Carries forward previous child estimated ship dates for shipped rows through `PreviousChildESD`.

### 2. `SRC.vw_PurchaseOrderItemSnapshotCurrentV2`

Purpose:

- Exposes the latest stored snapshot rows for each PO from `SRC.PurchaseOrderItemSnapshotRunV2` and `SRC.PurchaseOrderItemSnapshotV2`.

Current behavior:

- Uses the most recent `SnapshotRunId` per `DBID` and `POID`.

### 3. `SRC.vw_PurchaseOrderItemSnapshotDiffV2`

Purpose:

- Compares the latest snapshot to the previous snapshot and emits row-level and field-level differences.

Current behavior:

- Uses the latest two snapshot runs only.
- Skips empty snapshot runs when resolving the previous comparison baseline.
- Matches exact rows first by `RowKey`.
- Uses compatibility matching for child rows when exact keys differ.
- Uses a previous-parent fallback for unmatched current child rows, so newly materialized child rows can still carry meaningful previous business values.
- Preserves field-level change flags such as:
  - `IsQtyOrderedChanged`
  - `IsQtyReleasedChanged`
  - `IsQtyShippedChanged`
  - `IsEstimatedShipDateChanged`
  - `IsShipDateChanged`
  - `IsCarrierChanged`
  - `IsTrackingNumberChanged`
- Emits:
  - `RowChangeFlag`
  - `IsDeleted`
  - `HasAnyFieldChange`

Important matching rules now in place:

- Scheduled child compatibility matching uses `SourceLineUID`.
- Source shipment metadata is carried as `SourceShipmentLineUID`.
- Child comparison is business-field oriented, not purely internal-line-number oriented.
- Shipped child compatibility matching uses semantic shipped fields:
  - ordered line
  - quantity shipped
  - ship date
  - carrier
  - tracking number
- When no direct previous child match exists, the diff can fall back to the prior grouped parent row via `ParentLineUID` lineage.

Design note:

- The current logic is field-value based for business differences, but still separately tracks structural row add/remove events through `RowChangeFlag`.
- Result:
  - internal line/key drift alone is less likely to create false user-visible changes
  - true structural row rematerialization can still surface as `+` / `-` events
- Defensive baseline behavior:
  - transient zero-row snapshot runs are no longer allowed to become the `PreviousRun` baseline
  - this prevents false `+` shipped/scheduled highlights caused only by an empty intermediate capture

### 4. `SRC.BuildPurchaseOrderSnapshotV2`

Purpose:

- Creates a new snapshot run and persists current logical rows for one PO.

Current behavior:

- Resolves PO metadata from `AO.PurchaseOrder`.
- Sets `IsInitial = 1` only when there are no existing snapshot rows for that PO.
- Inserts a new run into `SRC.PurchaseOrderItemSnapshotRunV2`.
- Inserts current logical rows into `SRC.PurchaseOrderItemSnapshotV2`.
- Discards the just-created run if the logical-current view returns zero rows, so transient empty captures do not persist as empty snapshot runs.
- Prunes snapshot history so only the latest 5 runs per `DBID` + `POID` are retained.

### 5. `SRC.PurchaseOrderHistoryDE_V2`

Purpose:

- Main V2 wrapper procedure used by the scheduler / notification pipeline.

Current behavior:

- Builds a fresh snapshot first.
- Returns `NULL` immediately when the snapshot builder discards a zero-row capture.
- Resolves `DBID` and `POID` from the newly inserted snapshot run.
- Calls `dbo.GetPOitemHistoryStatus_V2`.
- Calls `dbo.GetPOitemHistory_V2`.
- Writes `NotificationType` back to the run row.
- Returns `ResultBody`.

Current local suppression rule:

- If `OASIS_PLS.oasis.CHSC_PO.UPDATEUSERID` is one of:
  - `AHARTMAN`
  - `GJENSEN`
  - `LLAFERNIER`
- Then the procedure:
  - sets `NotificationType = NULL`
  - returns `NULL` as `ResultBody`
  - skips the rest of status and HTML generation

Design note:

- This suppression was intentionally placed in `SRC.PurchaseOrderHistoryDE_V2`, not in the snapshot builder.
- Result:
  - snapshots still stay current
  - notification output is suppressed cleanly

### 6. `dbo.GetPOitemHistoryStatus_V2`

Purpose:

- Determines the V2 notification subject/status for one PO.

Current behavior:

- Works only from the latest two snapshot runs for the target PO.
- Returns one of:
  - `Shipped`
  - `Scheduled`
  - `Acknowledge`
  - `NULL`

Current decision rules:

- `Shipped`
  - returned when the PO currently has shipped child rows and there is visible shipped or scheduled notification content
- `Scheduled`
  - returned when a scheduled child row has a real estimated ship date and that date is new or changed
- `Acknowledge`
  - returned only for recent initial captures within 5 days and with no current shipped child rows
- `NULL`
  - returned when the PO has no meaningful notification state
- Previous-run guard:
  - the status helper now skips empty prior snapshots when choosing `@PreviousRunId`
  - this keeps a zero-row intermediate run from making old shipped rows look newly changed

### 7. `dbo.GetPOItemHistoryDetailHtml_V2`

Purpose:

- Builds the final HTML body.

Current behavior:

- Reads only non-deleted diff rows.
- Builds parent and child render rows.
- Supports:
  - single-child collapse
  - multi-child grouped rows
  - scheduled child suppression when shipped children already exist under the same parent
- Computes `HasVisibleHighlight` for each rendered row.
- Returns `NULL` for non-acknowledge flows when there are no visible highlight rows.
- Styles grouped rows so:
  - hierarchy parent rows render bold
  - grouped member rows render with light grey background

Current visible-highlight rules include:

- new non-shipped/non-scheduled rows
- new scheduled rows with a real estimated ship date
- new shipped rows with shipped content
- changed scheduled estimated ship date
- changed shipped quantity
- changed shipped date
- changed carrier
- changed tracking number

Yellow highlight output is rendered in HTML as CSS, for example:

- `background-color:yellow`
- `background-color:#f0f0f0;background-color:yellow`

### 8. `dbo.GetPOitemHistory_V2`

Purpose:

- Thin wrapper around the detail renderer.

Current behavior:

- Re-evaluates status if needed.
- Applies the recent-date gating for `Shipped` and `Scheduled`.
- Calls `dbo.GetPOItemHistoryDetailHtml_V2`.
- Returns `NULL` when there is no recent qualifying scheduled/shipped content.

## Verified live behavior

The following base V2 logic was verified against live `PLS` on `2026-05-01`:

- `SRC.vw_PurchaseOrderItemSnapshotDiffV2`
- `SRC.PurchaseOrderHistoryDE_V2`
- `dbo.GetPOitemHistoryStatus_V2`
- `dbo.GetPOItemHistoryDetailHtml_V2`

Evidence files:

- `output/helptext-live-PLS-vw_PurchaseOrderItemSnapshotDiffV2-20260501.txt`
- `output/helptext-live-PLS-PurchaseOrderHistoryDE_V2-20260501.txt`
- `output/helptext-live-PLS-GetPOitemHistoryStatus_V2-20260501.txt`
- `output/helptext-live-PLS-GetPOItemHistoryDetailHtml_V2-20260501.txt`

Live behavior that was confirmed:

- No-visible-highlight gate is present in the detail renderer.
- Compatibility matching based on `SourceLineUID` and `SourceShipmentLineUID` is present in the live code path.
- The scheduler wrapper correctly suppresses `NotificationType` when the final HTML body is `NULL`.

## Verified PO examples

### PO `4704476232`

Observed result:

- V2 output was correctly suppressed to `NULL` when there were no visible highlights to issue.

Why this matters:

- Confirms the no-visible-highlight gate is working as intended.

### PO `6103276194`

Observed result:

- V2 output returned HTML with yellow-highlighted changes.
- The saved HTML contained `25` yellow-style markers.

Important clarification:

- When viewing raw HTML text, the highlights appear as CSS strings, not as visible yellow blocks.
- The actual yellow markers were present in the output around the `HLI - EXO / Z.A1` section.

Examples that were confirmed in the output:

- `SSSH21.5-40A-1-B3-BLT-LAB`
- `SSS-H-BC40A`
- `201-0238-9702 4IN SQ PLASTIC ENDCAP V2`

Representative output file:

- `output/po-6103276194-real-new-run-20260501_171938.html`

### PO `4704466280`

Observed result:

- Group styling was corrected so hierarchy parent rows render bold and grouped member rows render light grey.
- Current business-comparison logic now preserves meaningful previous values for shipped component rows even when child row identity drifts.
- When recent snapshots are deleted, old shipped component rows can reappear as newly reported because the comparison falls back to an older surviving baseline.
- When a fresh snapshot is kept and the PO is rerun again, those old shipped rows no longer show as changed and the wrapper returns `NULL`.

Why this matters:

- Confirms the current logic is driven by field-value comparison plus row-lineage behavior, not by a naive "any internal line change" rule.
- Confirms snapshot-history deletion can change the baseline and therefore change what the user sees.

Representative output files:

- `output/po-4704466280-normal-v2-rerun-20260505_153629.html`
- `output/po-4704466280-normal-v2-followup-test-20260505_161919.txt`
- `output/po-4704466280-run-29651.html`

## Progress timeline

### 2026-04-29

- Verified and refined no-visible-highlight suppression behavior.
- Confirmed that detail HTML should return `NULL` when no visible highlight rows exist for non-acknowledge flows.

### 2026-05-01

- Pulled and verified the live `PLS` V2 program objects.
- Created verified local copies of the live logic.
- Confirmed PO-level behavior for:
  - `4704476232`
  - `6103276194`

### 2026-05-05

- Added a new local suppression rule in `SRC.PurchaseOrderHistoryDE_V2` for `CHSC_PO.UPDATEUSERID` values:
  - `AHARTMAN`
  - `GJENSEN`
  - `LLAFERNIER`
- Updated `SRC.vw_PurchaseOrderItemSnapshotDiffV2` to improve business-field comparison when child row keys drift.
- Added previous-parent fallback lineage for unmatched current child rows so business history is preserved when rows rematerialize under new child keys.
- Corrected grouped-row rendering so hierarchy parents are bold and grouped member rows are light grey.
- Verified on PO `4704466280` that:
  - deleting recent snapshots causes fallback to an older baseline and can re-surface old shipments
  - rerunning again without deleting the latest snapshot clears those false re-reports
- Deleted all `2026-05-05` V2 runs in local `PLS` and reran all `177` of the day's POs from a clean same-day baseline.
- Batch rerun result:
  - `12` HTML results
  - `165` `NULL` results
  - `8` `Shipped`
  - `4` `Scheduled`
- Generated an all-program alter script:
  - `output/PurchaseOrderHistoryV2.AlterAllPrograms.20260501.sql`
- Generated focused prod deploy bundle:
  - `output/PurchaseOrderHistoryV2.ProdDeploy.CurrentLogic.20260505.sql`

### 2026-05-08

- Updated previous-run selection to skip empty prior snapshots when choosing the comparison baseline.
- Added a zero-row capture guard in `SRC.BuildPurchaseOrderSnapshotV2` so empty transient captures are discarded instead of leaving orphaned run rows.
- Updated `SRC.PurchaseOrderHistoryDE_V2` to return `NULL` cleanly when the builder discards a zero-row capture.
- Generated refreshed prod handoff files:
  - `output/PurchaseOrderHistoryV2.ProdDeploy.CurrentLogic.20260508.sql`
  - `output/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.ForProd.Refresh.20260508.sql`

### 2026-05-14

- Refreshed `dbo.GetPOItemHistoryDetailHtml_V2` styling to match the requested email mockup:
  - dark brown purchase-order heading
  - orange table header row with left-aligned labels
  - 11pt body typography
  - softer highlighted cells using `#FFFFB0`
  - footer area with logo, tagline, and CSR signature block
- Used `AO.PurchaseOrder.CSR__c` with fallback to `OwnerId` to populate the CSR name in the footer when available.
- Generated refreshed prod handoff files:
  - `output/PurchaseOrderHistoryV2.ProdDeploy.CurrentLogic.20260514.sql`
  - `output/PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.ForProd.Refresh.20260514.sql`

## Deployment status

### Confirmed in live `PLS`

- Base V2 logic verified on `2026-05-01`
- No-visible-highlight suppression
- Current diff and status matching behavior

### Local only, not yet confirmed deployed

- `UPDATEUSERID` suppression in `SRC.PurchaseOrderHistoryDE_V2`
- Updated business-comparison logic in `SRC.vw_PurchaseOrderItemSnapshotDiffV2`
- Previous-parent fallback lineage in the diff view
- Group parent/member styling updates in `dbo.GetPOItemHistoryDetailHtml_V2`
- Updated canonical source file
- Updated verified copy
- Generated all-program alter script
- Generated focused prod deploy bundle

## Known gaps

- `PurchaseOrderHistoryV2.ProgramObjects.PLS.Current.ForProd.sql` is not in sync with the latest current logic and should not be used as the deployment source.
- The latest business-comparison / previous-parent fallback logic has been validated locally in `PLS`, but not yet confirmed in production.
- The `UPDATEUSERID` suppression was added locally after the `2026-05-01` live verification, so it still needs deployment and live validation.

## Recommended next deployment file

If deploying current V2 logic to `PLS`, use:

- `output/PurchaseOrderHistoryV2.ProdDeploy.CurrentLogic.20260514.sql`

## Recommended next validation after deploy

- Re-run one PO where `UPDATEUSERID` is in the excluded list and confirm `ResultBody = NULL`.
- Re-run `4704476232` and confirm it still suppresses correctly for no visible highlights.
- Re-run `6103276194` and confirm yellow highlight output is unchanged.
- Re-run `4704466280` after one baseline-establishing run and confirm the second rerun suppresses old previously reported shipments.
