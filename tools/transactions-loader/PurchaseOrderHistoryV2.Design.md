# Purchase Order History V2 Design

## Goal
Build a new PO item change-capture flow that:

- preserves the current parent/child grouping behavior
- compares the latest daily PO item state to the previously stored state
- highlights changed cells by explicit field comparison
- preserves Estimated Ship Date (ESD) independently from Ship Date
- avoids relying on raw row-hash diffs as the primary source of truth
- keeps the current v1 objects in place while we implement and test the new flow

## Current Design Learned
The current flow is centered on these live objects:

- `SRC.PurchaseOrderHistoryDE`
- `SRC.PurchaseOrderItemHistory`
- `dbo.GetPOitemHistory`
- `dbo.GetPOItemHistoryDetailHtml`
- `dbo.vw_PurchaseOrderItemHistory`

### What Works Today
- Parent/child grouping is already usable.
- Current display behavior can collapse a single child into one row.
- We now preserve ESD better than before for `S1 -> S` transitions.

### What Is Unreliable Today
- `SRC.PurchaseOrderItemHistory` has no true primary key.
- Matching depends on `TransactionType`, `LineUID`, `ShipmentLineUID`, and row-hash logic.
- Rendering logic and change-detection logic are tightly coupled.
- `S1` is both a source state and a display concern, which causes lifecycle problems.
- ESD is not modeled as a first-class field in the snapshot.
- A row-level `ChangeFlag` is being overloaded to represent:
  - initial rows
  - new rows
  - changed rows
  - deleted rows
  - notification intent

## V2 Design Principles
1. Normalize raw rows into logical PO item rows first.
2. Store ESD in its own column.
3. Compare normalized snapshots field-by-field.
4. Render HTML from diff-ready rows, not directly from raw transaction history.
5. Preserve current grouping semantics:
   - ordered row is the parent
   - scheduled/shipped rows are children
   - single-child rows can still collapse into one row

## V2 Logical Keys
There is no reliable physical PK in the current history table, so V2 needs explicit business keys.

### Parent Row Key
One logical parent row per ordered line:

- `DBID`
- `POID`
- `OrderedLineUID`

Suggested stored key:
- `RowType = 'P'`
- `RowKey = CONCAT(DBID, ':', POID, ':P:', OrderedLineUID)`

### Child Row Key
One logical child row per grouped scheduled/shipped child:

- `DBID`
- `POID`
- `OrderedLineUID`
- `LogicalChildUID`

Important distinction:

- `GroupLineUID` preserves the current parent/child grouping behavior
- `LogicalChildUID` is the unique row identity for snapshot/diff matching

Suggested grouping anchor:
- `GroupLineUID = COALESCE(NULLIF(ParentLineUID, 0), LineUID)`

Suggested child identity:
- `LogicalChildUID = COALESCE(NULLIF(ShipmentLineUID, 0), LineUID)`

Suggested stored key:
- `RowType = 'C'`
- `RowKey = CONCAT(DBID, ':', POID, ':C:', OrderedLineUID, ':', LogicalChildUID)`

This preserves the current grouping idea while avoiding many-to-many matching.

## ESD Rules
Raw source:

- `O` = ordered
- `S1` = scheduled
- `S` = shipped
- `R` = released and ignored

V2 handling:

1. Ignore `R`.
2. For each logical child, derive `EstimatedShipDate` from `MAX(TargetDate)` across current `S1` rows.
3. Store `EstimatedShipDate` as its own snapshot column.
4. If current raw data has `S` but no `S1`, carry forward `EstimatedShipDate` from the previous snapshot for the same logical row.
5. Store `ShipDate` only from `S`.
6. For collapsed single-child rows, display:
   - ESD from `EstimatedShipDate`
   - Ship Date from `ShipDate`

## Snapshot Model
V2 should snapshot the normalized logical display rows, not the raw transaction rows.

### Snapshot Run
Each execution creates one run row:

- which PO was processed
- when it was processed
- whether the PO is initial or incremental
- what notification type the run would produce

### Snapshot Row
Each execution stores:

- parent rows
- child rows
- one row per logical display row

This lets us compare:

- previous snapshot rows
- current snapshot rows

instead of trying to compare raw `O/S/S1` rows directly.

## Change Detection Model
V2 should compare fields directly:

- `QtyOrdered`
- `QtyReleased`
- `QtyShipped`
- `ManufacturerName`
- `FixtureType`
- `PartNumber`
- `EstimatedShipDate`
- `ShipDate`
- `Carrier`
- `TrackingNumber`

### Row Status
Keep row status simple:

- `''` = initial PO snapshot row
- `'+'` = new row introduced after the initial snapshot
- `'='` = row existed previously

Do not use row status to mean "field changed".

### Cell Change Flags
Store per-column change bits:

- `IsQtyOrderedChanged`
- `IsQtyReleasedChanged`
- `IsQtyShippedChanged`
- `IsManufacturerChanged`
- `IsFixtureTypeChanged`
- `IsPartNumberChanged`
- `IsEstimatedShipDateChanged`
- `IsShipDateChanged`
- `IsCarrierChanged`
- `IsTrackingNumberChanged`

Also store:

- `HasAnyFieldChange`
- `IsDeleted`

Deleted rows can be tracked for audit purposes even if we do not render them.

## Notification Behavior
Suggested notification intent by snapshot run:

- `Acknowledge`
  - first snapshot for the PO
  - all row statuses are `''`
- `Scheduled`
  - no shipping changes
  - at least one non-shipping field changed, especially ESD
- `Shipped`
  - at least one shipping field changed:
    - `QtyShipped`
    - `ShipDate`
    - `Carrier`
    - `TrackingNumber`
    - new shipped child row
- `NULL`
  - no material changes

## Proposed V2 Objects
### Storage
- `SRC.PurchaseOrderItemSnapshotRunV2`
- `SRC.PurchaseOrderItemSnapshotV2`

### Normalization / Diff
- `SRC.vw_PurchaseOrderItemCurrentLogicalV2`
- `SRC.vw_PurchaseOrderItemSnapshotCurrentV2`
- `SRC.vw_PurchaseOrderItemSnapshotDiffV2`

### Execution
- `SRC.BuildPurchaseOrderSnapshotV2`
- `SRC.PurchaseOrderHistoryDE_V2`

### Rendering
- `dbo.GetPOItemHistoryDetailHtml_V2`
- `dbo.GetPOitemHistory_V2`

## Recommended Build Flow
1. Resolve PO metadata from `AO.PurchaseOrder`.
2. Pull raw rows from `SRC.PurchaseOrderItem`.
3. Normalize raw rows into logical parent/child rows.
4. Carry forward ESD when `S1` has disappeared and `S` now exists.
5. Insert a new snapshot run row.
6. Insert normalized snapshot rows.
7. Compare current snapshot to previous snapshot.
8. Determine notification intent.
9. Render HTML from the diff view.

## Why This Is More Reliable
- no many-to-many history matching
- no dependency on raw row-hash semantics for business decisions
- explicit ESD lifecycle
- explicit field-level diff
- stable keys aligned to rendered rows
- grouping preserved without mixing grouping logic into diff matching

## Recommended Implementation Order
1. Create V2 storage tables.
2. Build normalization query/view.
3. Build snapshot writer proc.
4. Build diff view.
5. Build HTML renderer on top of the diff view.
6. Build wrapper proc/function.
7. Run parallel tests against the current v1 flow before cutover.
