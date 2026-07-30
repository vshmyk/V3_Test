# ABIO Modernization Summary

## Current Objective

The project is modernizing the Abio PowerBuilder desktop application into a web platform. The preferred target shape is:

- Angular for the browser UI.
- AG Grid as the primary replacement for PowerBuilder DataWindow-style tabular screens.
- ASP.NET Core / .NET for API, validation, workflow, transaction handling, and integration logic.
- SQL Server as the system of record, initially using the restored `ABIO_DEMO` database.

This is best treated as a replatforming effort, not an automatic source-to-source conversion. PowerBuilder screens, DataWindows, global functions, and embedded SQL need to be translated into explicit API contracts, Angular screens, AG Grid column definitions, and .NET services.

## Source And Inventory Context

The PowerBuilder application source is located at `E:\Abio`.

Current inventory findings:

- `E:\Abio\abio.pbt` references 46 PowerBuilder libraries.
- The referenced PBL files total roughly 359 MB.
- Only a small number of exported `.sr*` source files were visible at first inspection.
- A binary hint scan found approximately 3,562 likely PowerBuilder object names.
- The scan included about 2,212 likely DataWindows, 726 user objects, and 326 windows.

The important next discovery step remains exporting the full PowerBuilder source from the PBLs. The existing inventory is useful for sizing, but full exported source is needed to accurately migrate screen logic, DataWindow SQL, validation, and update behavior.

## Database Context

`ABIO_DEMO` has been restored in SQL Server on:

```text
Server: .\ERPLINK
Database: ABIO_DEMO
Authentication: Windows integrated security
```

The prototype connection string is stored in:

```text
tools/abio-modernization/prototype/Abio.Api/appsettings.Development.json
```

Initial database discovery found:

- 275 user tables.
- 31 stored procedures.
- 112 scalar functions.
- Important core tables include `job`, `client`, `vendor`, `timesheet`, `ap_invoice`, `ar_invoice`, `jc_transaction`, `gl_transaction`, and `event_log`.

The current prototype uses read-only queries. Write, posting, approval, import, and accounting transaction behavior has not yet been migrated.

## Documents And Tooling Created

Modernization planning material is under:

```text
tools/abio-modernization
```

Key documents:

- `README.md` - package overview.
- `AbioNgMigrationCheatSheet.md` - shared migration/UI/middle-tier patterns and consistency rules for future work.
- `TargetArchitecture.md` - target Angular / AG Grid / .NET architecture.
- `ModuleMigrationPlan.md` - staged migration approach by functional area.
- `PowerBuilderSourceExportGuide.md` - guidance for exporting full PB source.
- `PayrollMigrationPlan.md` - Payroll module source inventory and staged migration plan.
- `RhumbixPilotBlueprint.md` - earlier Rhumbix pilot plan, now parked.
- `prototype/README.md` - runnable prototype instructions.
- `knowledge-base/AbioWebsiteKnowledge.md` - public website-derived Abio ERP/product context for replatforming and AI assistant grounding.
- `knowledge-base/AbioWebsiteIndex.json` - machine-friendly indexed KB records by module, entity, workflow, keyword, and source route.
- `knowledge-base/LegacyTrainingMaterials.md` - module/menu/report training index generated from `ABIO_DEMO`.
- `knowledge-base/LegacyTrainingMaterialsIndex.json` - machine-friendly legacy training index from `dbo.abio_menu` and `dbo.program_report`.

The website-derived KB should be used as a product-context overlay while replatforming. It is helpful for vocabulary, module relationships, navigation concepts, AI assistant grounding, and user-facing explanations. It is not authoritative for validations, posting logic, payroll calculations, save behavior, permissions, or accounting rules.

The legacy training-materials KB is more operationally specific than the website KB. It should be used for menu-to-module mapping, contextual help text, report explanations, report DataWindow discovery, and future AI assistant retrieval.

Inventory and analysis scripts:

- `scripts/Inventory-AbioPowerBuilder.ps1`
- `scripts/Scan-PblBinaryHints.ps1`
- `scripts/New-PreExportSizingReport.ps1`

Generated inventory output:

- `inventory/`
- `inventory-binary-hints/`
- `pre-export-sizing/`

## Prototype State

The runnable prototype lives in:

```text
tools/abio-modernization/prototype
```

Projects:

- `Abio.Modernization.sln`
- `Abio.Api` - ASP.NET Core Web API.
- `Abio.Web` - Angular 19 app with AG Grid.

Local run commands:

```powershell
dotnet run --project .\Abio.Api\Abio.Api.csproj
```

```powershell
cd .\Abio.Web
npm start
```

Expected local URLs:

```text
API: http://localhost:5239
Web: http://localhost:4200 or http://127.0.0.1:4200
```

The Angular app defaults to the core Abio operations console. The earlier Rhumbix prototype remains available at `/rhumbix`, but Rhumbix is intentionally parked while the project focuses on core Abio functionality.

## Implemented Core API Endpoints

The following live, read-only endpoints currently query `ABIO_DEMO`:

- `GET /api/core/config`
- `GET /api/core/summary?book=ABIODEMO`
- `GET /api/core/clients?book=ABIODEMO`
- `GET /api/core/jobs?book=ABIODEMO`
- `GET /api/core/vendors?book=ABIODEMO`
- `GET /api/core/ap-invoices?book=ABIODEMO`
- `GET /api/core/ar-invoices?book=ABIODEMO`
- `GET /api/core/timesheets?book=ABIODEMO`

The Jobs flow is being expanded into a PowerBuilder-style master/detail screen. Selecting a job in the Angular AG Grid should load:

- Job overview totals.
- Job timesheets.
- Job AP invoice lines.
- Job AR invoice lines.
- Job cost transactions.

## Current UI State

The Angular core console currently provides:

- Book selector from `dbo.book`.
- A modern workflow-oriented landing page over the legacy `dbo.abio_menu` catalog, styled as an Abio NG operations workspace.
- Modern business menu groups for Home & Work Queue, Projects & Jobs, People & Payroll, Purchasing & Vendors, Customers & Revenue, Finance & Compliance, Assets & Inventory, Reports & Insights, and Administration.
- A two-column left navigation panel with company selector, workflow search, modern business sections, and visible shortcuts into core lists/payroll.
- The modern main menu is a one-column tree rendered from the Legacy `abio_menu` hierarchy, preserving Legacy shortcut letters and menu order while using the Abio NG visual shell.
- Report and report-menu entries are displayed under a dedicated `Reports` branch inside their related top-level business category, then grouped by the original Legacy report-menu categories such as Vendor Reports, Invoice Reports, Cheque Reports, Job Reports, and similar category nodes.
- Applicable menu items now open their migrated main lists directly, using dataset-specific AG Grid column layouts modeled after the legacy list/DataWindow structure.
- The new Abio NG main menu is the persistent shell. Module content, including Payroll, should render inside the right-hand workspace instead of replacing the shell with an older module-specific menu.
- Job and Payroll record forms support Arrow Up/Arrow Down field navigation in addition to Tab through a shared Angular directive. Editable text-like and numeric fields auto-select their value on focus, while read-only fields remain selectable for navigation without looking like edit mode.
- Dashboard cards for payroll approvals, job budget exceptions, AP invoice review, and timesheet approvals.
- Recent-records, suggested-actions, and KPI panels to support a modern ERP landing-page pattern while preserving the legacy catalog underneath.
- AG Grid tabs for clients, jobs, vendors, AP invoices, AR invoices, and timesheets.
- Jobs grid columns include transaction counts to identify jobs with activity.
- A job drilldown area is being implemented below the Jobs grid.

The new menu is not a static mockup. The Angular core console now loads the existing legacy menu from `/api/core/menu`, flattens the active menu/report entries, and projects them into modern workflow groups. This preserves legacy search/program visibility while presenting the business-oriented navigation style intended for Abio NG.

AG Grid is the right fit for replacing many PowerBuilder DataWindow browsing and inquiry screens, especially where the PB behavior is read-only, filterable, sortable, and tabular. Editable DataWindows will need extra design for validation, save transactions, row status, optimistic concurrency, and backend command endpoints.

## Recently Verified Demo Data

For `book = ABIODEMO`, the summary endpoint previously returned representative counts including:

- 29 active clients.
- 17 active jobs.
- 118 active vendors.
- 116 active employees.
- 1,694 timesheets.
- 378 AP invoice lines.
- 524 AR invoice lines.
- 2,853 GL transactions.
- 816 job cost transactions.

Jobs with useful child activity include examples such as:

- `6101` - Green River Highway.
- `Z6103` - Blue River-offset.
- `1503` - Sidney Aquatic Centre.
- `6200` - Trans Mountain Phase 1.
- `6103` - Blue River Highway.

## Known Limitations

- Full PowerBuilder source export is still needed for exact migration mapping across the whole application, although focused Job Cost and Payroll source exports now exist under `tools/abio-modernization/pb-exported-source`.
- Current API is read-only and mostly table-query based.
- PowerBuilder event scripts, DataWindow update rules, and transaction boundaries have not yet been fully reconstructed.
- Authentication, authorization, auditing, and deployment architecture are not implemented in the prototype.
- Rhumbix endpoints are still mock-based and intentionally out of current focus.
- The current prototype is a modernization spike, not production-ready application code.

## Payroll Migration Baseline

Payroll migration planning has started from exported PB source and `ABIO_DEMO` metadata. The focused source export includes Employee Entry, Timesheet Entry, Field Timesheet Review, Cheque Entry, Payroll reports, and setup objects from `payroll.pbl`, `timesheet.pbl`, `reports_pr.pbl`, `shared_tables.pbl`, and `table.pbl`.

The Payroll module should be migrated as command-layer workflows, not generic table edits. High-risk actions such as create cheques, approve cheques, issue/reprint cheques, cost to Job Cost and General Ledger, advance pay period, and cleanup/archive must remain disabled in Abio NG until their PowerBuilder program-layer logic is implemented and reconciled in .NET.

The recommended first Payroll slice is read-only: Payroll landing page, AG Grid lists, hyperlink navigation, and read-only record pages for Employees, Timesheets, Field Timesheets, Cheques, and Setup. Details are documented in `tools/abio-modernization/PayrollMigrationPlan.md`.

The first .NET Payroll middle-tier foundation has been added in `tools/abio-modernization/prototype/Abio.Api/PayrollProgramLayer.cs`. It defines Payroll read models, lookup services, setup queries, command contracts, a command registry, and guarded command responses for all major Payroll workflows so API/UI work can be added on top of a safer program-layer seam.

Payroll API endpoints have now been added on top of the middle-tier layer:

- `GET /api/payroll/inventory`
- `GET /api/payroll/employees`
- `GET /api/payroll/employee-record`
- `GET /api/payroll/timesheets`
- `GET /api/payroll/timesheet-record`
- `GET /api/payroll/field-timesheets`
- `GET /api/payroll/field-timesheet-record`
- `GET /api/payroll/cheques`
- `GET /api/payroll/cheque-record`
- `GET /api/payroll/setup`
- `GET /api/payroll/lookups`
- `POST /api/payroll/commands`

The read endpoints have been smoke-tested against `ABIO_DEMO`. The command endpoint is intentionally guarded and returns `blocked-pending-legacy-command-migration` for write workflows until their PB program-layer logic is migrated.

The first read-only Payroll UI shell has been added in Angular under `tools/abio-modernization/prototype/Abio.Web/src/app/payroll`. It is available at `/payroll` and includes:

- Payroll landing/console page.
- Book selector, search, row limit, and include-history controls.
- AG Grid lists for Employees, Timesheets, Field Timesheets, Cheques, and Setup.
- Setup selector for pay periods, trade unions, occupations, occupation rates, premium types, timesheet statuses, WCB rates, federal tax, and provincial tax.
- Hyperlink-style record opening from list identifiers.
- Read-only record preview with legacy-style tabs and child grids where available.
- Guarded command buttons that call `POST /api/payroll/commands` and display the migrated command guard response.

The legacy left menu now routes Payroll module/menu nodes to `/payroll`.

The Payroll UI has been aligned with the Job module navigation style. Selecting a linked Payroll identifier now opens a same-page record window instead of a side preview. The record view uses a legacy-style title bar, close/back button, tabs, action strip, scrollable record body, and a right-side safety/context panel.

The Payroll workspace now keeps the main legacy menu panel visible at all times, matching the Job Costing pattern. Payroll menu folders expand in the left panel, Payroll leaves switch the right-hand Payroll view, and the right-hand content area scrolls independently so navigation remains anchored while users move between lists and records.

Payroll record tabs are being migrated into explicit read-only tab models. Employee and Timesheet tabs now render tab-specific field groups and child grids. Field Timesheet tabs now distinguish Details from Document/child Timesheet rows. Cheque tabs now distinguish Gross & Net, Earn & Loss, Premiums, WCB, Union, and Occupation; the API now returns the missing `pr_cheque_occupation` child rows for the Occupation tab.

Payroll validation migration has started from the exported PowerBuilder BO source. The API now exposes `GET /api/payroll/validation-rules` with migrated validation metadata for Employee, Timesheet, Field Timesheet, and Cheque records. Guarded command responses now include validation errors and return `validation-failed` before the blocked-command stage when required or fixed-value rules fail. Angular consumes the same validation catalog to show required markers, frontend validation summaries, and backend-only rule notes. Advanced PB validations such as cross-table lookups, date-window checks, rate/pay-period checks, termination/ROE behavior, and command-specific side effects are explicitly marked as backend migration targets until fully ported and side-by-side tested.

## Recommended Next Steps

1. Finish and validate the Job master/detail flow.
2. Expand Payroll record page field layouts for Employee, Timesheet, Field Timesheet, and Cheque using the visual DataWindow layouts from PB.
3. Add direct route/deep-link support for Payroll records.
4. Use the exported PowerBuilder source to identify the real PB screen and DataWindow SQL behind job inquiry, AP, AR, timesheets, payroll, and job cost.
5. Replace broad table reads with domain-specific .NET services and explicit DTOs.
6. Add read-only detail screens for client and vendor flows using the same master/detail pattern.
7. Choose one safe write workflow, such as a small maintenance screen or approval action, and design the first end-to-end update transaction.
8. Add automated API tests against a known `ABIO_DEMO` fixture or snapshot.
