# Abio Module Migration Plan

## Purpose

This plan sequences the Abio PowerBuilder application into practical migration waves. It is based on the visible PowerBuilder target and libraries in `E:\Abio\abio.pbt`, plus the exported sample objects currently available in `E:\Abio`.

The plan assumes a target platform of Angular, AG Grid, ASP.NET Core, SQL Server, and a dedicated reporting subsystem.

## Migration Principles

- Build the platform foundation before migrating critical financial workflows.
- Start with contained screens that prove the architecture without carrying payroll or general ledger risk.
- Treat report migration as a parallel stream.
- Keep SQL Server as the primary database.
- Move business logic into ASP.NET Core services as screens are migrated.
- Use AG Grid for operational grids, not formal printed reports.
- Maintain parallel validation against the PowerBuilder application until each module is accepted.

## Recommended Waves

| Wave | Area | Goal | Risk |
| --- | --- | --- | --- |
| 0 | Discovery | Export full PB source, inventory objects, classify screens, identify reports and integrations | Medium |
| 1 | Platform Foundation | Build Angular shell, AG Grid wrapper, ASP.NET Core API foundation, auth, logging, reporting proof of concept | Medium |
| 2 | Pilot | Migrate one contained feature end to end, preferably Rhumbix or Dashboard | Medium |
| 3 | Low-Risk Modules | Move dashboards, lookups, administration, and read-mostly inquiry screens | Low/Medium |
| 4 | Medium-Risk Modules | Move equipment, inventory, HR, project management, and non-critical maintenance screens | Medium |
| 5 | High-Risk Modules | Move AP, AR, job cost, payroll, GL, posting, closing, and core financial processes | High |
| 6 | Decommissioning | Run reconciliations, retire desktop screens by module, archive PB dependencies | High |

## Module Sequence

| Order | Module | Current PB Signal | Suggested UI Pattern | Risk | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | Dashboard | `dashboard.pbl`, `dashboard.pbg`, exported dashboard DataWindows | Angular dashboards, AG Grid drill-downs, charts | Low | Good early candidate because it is likely read-heavy and validates the grid/dashboard pattern. |
| 2 | Administration | `administration_menu.pbl` | Forms, lookup grids, permissions screens | Low/Medium | Useful for building shared shell, navigation, preferences, and configuration patterns. |
| 3 | Project Management | `project_management.pbl` | Forms, grids, workflow actions | Low/Medium | Often operational and less financially final than GL/payroll. |
| 4 | Equipment | `equipment.pbl` | Maintenance forms, editable grids, lookup screens | Medium | Good fit for AG Grid and reusable maintenance patterns. |
| 5 | Inventory | `inventory.pbl` | Editable grids, stock forms, movement workflows | Medium | Requires careful transaction handling and audit behavior. |
| 6 | Human Resources | `human_resources.pbl` | Forms, grids, document views | Medium | Sensitive data requires authorization and audit attention. |
| 7 | Receivables | `receivables.pbl`, `reports_ar.pbl` | Transaction screens, grids, reports | Medium/High | Requires reconciliation against invoices, aging, receipts, and formal reports. |
| 8 | Payables | `payables.pbl`, `reports_ap.pbl` | Transaction screens, approvals, reports | High | Cheques, remittances, document workflows, and payment controls raise risk. |
| 9 | Job Cost | `jobcost.pbl`, `reports_jc.pbl` | Hybrid forms, grids, summaries | High | Likely cross-cuts payroll, AR, AP, inventory, and reporting. |
| 10 | Payroll | `payroll.pbl`, `reports_pr.pbl` | Complex transactional workflows and statutory reporting | Very High | Leave until platform, reconciliation, reporting, and audit patterns are mature. |
| 11 | General Ledger | `general_ledger.pbl`, `reports_gl.pbl` | Posting workflows, period close, reports | Very High | Needs strict transaction integrity and financial reconciliation. |
| Parallel | Reports | `reports*.pbl`, `.srd` objects | Reporting subsystem | High | Convert continuously alongside functional modules. |

## Discovery Checklist

Before a detailed estimate, gather:

- full text export of all `.pbl` objects;
- object inventory by type: windows, DataWindows, menus, user objects, functions, structures;
- DataWindow inventory by purpose: grid, updateable grid, form, report, lookup, nested report;
- embedded SQL inventory;
- stored procedure inventory;
- external integration inventory;
- report output inventory;
- security and role model inventory;
- batch jobs, scheduled tasks, and file import/export flows;
- database schema and cross-database dependency inventory.

## Current Inventory Baseline

The first generated inventory is available at [inventory/InventorySummary.md](inventory/InventorySummary.md).

Current findings:

- `abio.pbt` references 46 target libraries.
- The referenced `.pbl` files total about 359 MB.
- Only 31 object references are visible through `.pbg` files, all from `dashboard.pbg`.
- The visible `.pbg` object references include 22 DataWindows, 5 windows, 2 menus, and 2 user objects.
- Only 6 exported source files were found beside the PBLs: 5 DataWindows and 1 window.
- Most of the migration inventory still requires full source export from the `.pbl` binaries.

A separate non-authoritative binary scan is available at [inventory-binary-hints/BinaryHintsSummary.md](inventory-binary-hints/BinaryHintsSummary.md). It found 3,562 likely object-name hints:

- 2,212 DataWindows;
- 726 user objects;
- 326 windows;
- 238 functions;
- 40 structures;
- 20 menus.

The largest binary-hint areas were `receivables.pbl`, `shared_tables.pbl`, `payables.pbl`, `jobcost.pbl`, `abio.pbl`, `administration_menu.pbl`, and `payroll.pbl`. These counts should be used for early sizing only; exported `.sr*` files remain the authoritative source.

The current pre-export sizing report is available at [pre-export-sizing/PreExportSizingSummary.md](pre-export-sizing/PreExportSizingSummary.md). Its highest-ranked module groups are:

- PowerBuilder Framework;
- Reports;
- Shared Foundation;
- Job Cost;
- Payables;
- Receivables;
- Payroll;
- Administration.

This does not mean those should all be migrated first. It means they deserve early discovery because they are likely to influence architecture, reusable services, report strategy, and migration risk. Dashboard and Rhumbix still remain better first delivery pilots.

Generated CSV outputs:

- [pbl-libraries.csv](inventory/pbl-libraries.csv)
- [pbg-object-refs.csv](inventory/pbg-object-refs.csv)
- [exported-source-files.csv](inventory/exported-source-files.csv)
- [pbl-binary-object-hints.csv](inventory-binary-hints/pbl-binary-object-hints.csv)
- [module-sizing.csv](pre-export-sizing/module-sizing.csv)
- [library-sizing.csv](pre-export-sizing/library-sizing.csv)

## Per-Screen Migration Checklist

For each screen:

1. Identify the PowerBuilder objects involved.
2. Classify the screen as grid, form, report, hybrid, workflow, or integration.
3. Extract retrieval SQL, update behavior, validation, and event logic.
4. Define Angular route, screen layout, forms, and AG Grid regions.
5. Define ASP.NET Core endpoints and DTOs.
6. Move database access and transactions into backend services.
7. Recreate validation in backend services, with Angular pre-validation for fast feedback.
8. Recreate exports and report links.
9. Validate results against the PowerBuilder screen.
10. Add automated tests for critical rules and API contracts.

## Estimation Buckets

Use these buckets after the inventory is complete:

| Bucket | Example | Typical Complexity |
| --- | --- | --- |
| Read-only grid | Inquiry list, lookup, dashboard drill-down | Low |
| Editable maintenance grid | Table maintenance with simple validation | Medium |
| Header/detail transaction | Invoice, payment, inventory movement | Medium/High |
| Workflow screen | Posting, approval, import, sync | High |
| Formal report | Cheque, remittance, statement, statutory form | High |
| Cross-module process | Payroll run, GL close, job cost billing | Very High |

## Acceptance Approach

Each migrated module should be accepted through:

- side-by-side comparison with the PowerBuilder app;
- database reconciliation for transactional screens;
- report output comparison for formal documents;
- user acceptance testing by role;
- audit and permission review;
- performance testing with production-like data volumes.

## Immediate Next Step

The Rhumbix integration is the best first pilot because it has exported PowerBuilder source available and includes a useful vertical slice: filters, actions, validation, database operations, import/sync behavior, status counts, and DataWindow-style result grids.
