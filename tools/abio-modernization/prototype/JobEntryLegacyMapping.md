# Job Entry Legacy Mapping

This note tracks the legacy PowerBuilder objects that should be treated as authoritative for the Abio NG Job Entry form.

The current Angular form is a safe edit-mode scaffold. It intentionally does not persist changes yet because the full exported PowerBuilder source for the referenced objects is not available in this workspace. Before enabling writes to `dbo.job`, we need to export and map the relevant `.sr*` files from the PBLs listed below.

## Primary Legacy References

| PBL | Object | Role |
| --- | --- | --- |
| `jobcost.pbl` | `w_jc_job.srw` | Main Job Entry window and action/event orchestration. |
| `jobcost.pbl` | `d_jc_job_detail.srd` | Details tab DataWindow layout, update behavior, validation, dropdowns, protect rules. |
| `jobcost.pbl` | `d_jc_job_detail_finance.srd` | Financial tab DataWindow layout, calculated/protected financial fields, update behavior. |
| `jobcost.pbl` | `u_cst_jc_job_detail.sru` | Custom user object logic for the details DataWindow. |
| `jobcost.pbl` | `u_cst_jc_job_detail_finance.sru` | Custom user object logic for the financial DataWindow. |
| `jobcost.pbl` | `n_bo_job.sru` | Job business object logic, likely update/validation/defaulting support. |
| `jobcost.pbl` | `d_bo_job.srd` | Business-object DataWindow for job persistence. |

## Related Tab References

| PBL | Object | Role |
| --- | --- | --- |
| `jobcost.pbl` | `d_bo_job_shipping_info.srd` | Shipping tab persistence/reference object. |
| `jobcost.pbl` | `d_jc_job_shipping_info_detail.srd` | Shipping tab detail layout/update behavior. |
| `jobcost.pbl` | `d_bo_job_checklist.srd` | Checklist persistence/reference object. |
| `jobcost.pbl` | `d_bo_job_document.srd` | Supporting documents persistence/reference object. |
| `jobcost.pbl` | `d_jc_job_document_detail.srd` | Supporting documents detail layout/update behavior. |

## Related Shared References

| PBL | Object | Role |
| --- | --- | --- |
| `abio.pbl` | `d_area_for_job.srd` | Job-related area lookup/reference logic. |
| `shared_tables.pbl` | `d_bo_standard_job.srd` | Standard job template/business object reference. |
| `shared_tables.pbl` | `n_bo_standard_job.sru` | Standard job business logic. |
| `shared_tables.pbl` | `w_st_standard_job.srw` | Standard job maintenance window, useful for default/template behavior. |

## Migration Guardrails

- Do not infer update behavior from `dbo.job` alone. PowerBuilder DataWindow update properties, itemchanged validation, dropdown DataWindows, computed/protected fields, and user-object scripts must be mapped first.
- Keep job id, audit fields, last update, accumulated cost/revenue/payment, and period buckets protected until the PB rules prove otherwise.
- Treat `Edit` as a state change, not a database command. Save should remain guarded until the PB objects above are exported and mapped.
- Once exported source is available, map field-by-field behavior into a .NET command service and Angular validation rules before enabling `PUT /api/core/job-record`.

## Program-Layer Command Phases

The `.NET` command seam is `JobEntryProgramLayer.SaveAsync`. It should be filled in phase-by-phase from the exported PowerBuilder source:

1. Enter edit mode using the same action enable/protect rules as `w_jc_job`.
2. Run DataWindow `ItemChanged` and validation logic for changed fields.
3. Run program-layer pre-save validation and defaulting from `n_bo_job` / `u_cst_*` objects.
4. Persist through the mapped business-object/DataWindow update path, not direct UI field patching.
5. Run post-save refresh/audit/status behavior from the legacy window.

## Current NewGen Status

The NewGen Job Entry page currently supports:

- View mode.
- Edit mode.
- Dirty tracking.
- Cancel/restore.
- Protected field behavior.
- Guarded Save through the API program-layer command seam with changed-field reporting.
- Searchable lookup dropdowns for reference fields, restricted to valid lookup values.
- Checkbox editing for `Y`/`N` fields while preserving `Y`/`N` storage values.

Persistence is no longer a direct UI patch. The Angular UI calls the .NET Job Entry command endpoint, and that endpoint hosts the migrated equivalent of the PowerBuilder program-layer actions. Only the currently mapped safe field/update slice should be considered enabled; high-risk actions remain guarded until their PowerBuilder logic is migrated.

## Source Export Status

A local ORCA-based exporter has been scaffolded at:

```text
tools/abio-modernization/pb-source-exporter
```

The exporter uses:

```text
E:\Abio\PowerBuilderUtilities 25.0\pborc.dll
E:\Abio\Prg\jobcost.pbl
E:\Abio\Runtime 25.0.0.3711
```

The PowerBuilder 25 runtime DLLs were found in `E:\Abio\Runtime 25.0.0.3711`, and the 32-bit ORCA exporter successfully exported the first Job Entry source set to:

```text
tools/abio-modernization/pb-exported-source/jobcost.pbl.src
```

Exported Job Entry objects include `w_jc_job.srw`, `u_cst_jc_job_detail.sru`, `u_cst_jc_job_detail_finance.sru`, `n_bo_job.sru`, `d_bo_job.srd`, `d_jc_job_detail.srd`, `d_jc_job_detail_finance.srd`, and the shipping/checklist/document tab objects.

The first migrated save slice now lives in `Abio.Api/JobEntryProgramLayer.cs`. It maps safe Job Entry field persistence through the .NET command layer and implements these exported legacy rules:

- `u_cst_jc_job_detail.itemchanged`: blank client P/O clears item, blank equipment revenue area clears centre, province can default country, and selected rate-type fields allow blank/null.
- `u_cst_jc_job_detail.bo_preupdate`: sets `last_update` to today and performs the legacy address-line shift when address 2 is blank.
- `n_bo_job.bo_validate`: enforces required Job Entry fields, legacy allowed-value expressions, phone/fax/postal-code formats, reg-hours and markup ranges, shutdown date ordering/window checks, active-job commitment protection, required division when Standard GL is enabled and `division_book` rows exist, and required dashboard group when dashboard groups exist.
- `n_bo_job` reference constraints: validates mapped lookup values against the current book/reference tables for province/country, parent job, client, WCB class, G/HST rule, division, dashboard group, region, job type, labour/equipment rate types, trade union group, and equipment revenue area/centre.
- `u_cst_jc_job_detail.ue_validateaction`: blocks edits for history-file jobs.
- `n_bo_job.bo_preupdate`: keeps the concurrent-crew `Y` to `N` side effect guarded until the child `crew_member` update/report/confirmation path is migrated.
- `d_jc_job_detail` dropdown values: `timeEntrySheetApprover` now uses the legacy `P`/`E`/`D` values.

Remaining high-risk actions still need migration before broad persistence is enabled: New/Add defaults, Delete restrictions and child constraints, financial-tab action-specific editing, client default-rate confirmation, rate-change confirmation, renumbering, snapshots/history, audit/event log deltas, and child-tab updates.
