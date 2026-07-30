# Rhumbix Pilot Implementation Plan

## Purpose

This plan breaks the Rhumbix pilot into buildable tasks for an Angular, AG Grid, ASP.NET Core, and SQL Server implementation.

## Assumptions

- The first production codebase will have an Angular app and ASP.NET Core API, or those will be created as part of the platform foundation.
- Existing SQL Server stored procedures remain in place for the pilot.
- The pilot can call `sp_RhumbixImportTimesheets_NoCLR` and `sp_RhumbixSyncProjects`.
- Full PowerBuilder source export is still pending, but the Rhumbix source objects are available.

## Sprint 0: Platform Setup

Deliverables:

- Angular app shell with authenticated layout.
- ASP.NET Core API project.
- SQL Server connection configuration by environment.
- Standard API error shape.
- Basic logging and request correlation.
- AG Grid installed and wrapped in an `AbioGrid` component.

Acceptance:

- Angular can call a health endpoint.
- API can connect to the target SQL Server environment.
- A sample AG Grid can retrieve rows from a test endpoint.

## Sprint 1: Rhumbix Read Model

Deliverables:

- `GET /api/rhumbix/config`.
- `GET /api/rhumbix/pending-count`.
- `GET /api/rhumbix/sync-history`.
- `GET /api/rhumbix/import-errors`, using a temporary or persisted source confirmed during implementation.
- Angular Rhumbix route and basic page layout.
- Sync History AG Grid.
- Import Errors AG Grid.

Acceptance:

- Page loads default book, today date range, and current PR period.
- Pending project count matches the PowerBuilder query.
- Sync history grid matches `d_rhumbix_sync_history.srd` for the selected book.
- Import errors grid matches available error source for the latest run.

## Sprint 2: Import Workflow

Deliverables:

- `POST /api/rhumbix/import-timesheets`.
- Backend validation for book, date range, and PR period.
- Stored procedure integration for `sp_RhumbixImportTimesheets_NoCLR`.
- Import result summary with imported, error, and total counts.
- Angular form validation and disabled/loading states.
- Date shortcuts: Today, This Week, Last Week.

Acceptance:

- Invalid date and PR period inputs return structured validation errors.
- Successful import returns counts and refreshes grids.
- Browser workflow reconciles with PowerBuilder for the same input.
- Runtime and SQL errors are logged with enough context to diagnose.

## Sprint 3: Project Sync Workflow

Deliverables:

- `POST /api/rhumbix/sync-projects`.
- Force full sync option.
- Backend stored procedure integration for `sp_RhumbixSyncProjects`.
- Angular action state and success/failure notification.
- Refresh of pending count and sync history after sync.

Acceptance:

- Sync projects action calls the same stored procedure path as PowerBuilder.
- Force full sync maps to `@force_full_sync = 1`.
- Success and failure behavior is visible in the web UI.
- Sync history refreshes after completion.

## Sprint 4: Hardening And Pilot Acceptance

Deliverables:

- Audit/run logging for import and sync.
- Authorization check for book and action permissions.
- Export support for AG Grid where useful.
- Automated backend validation tests.
- Manual reconciliation checklist.
- Pilot acceptance notes.

Acceptance:

- Users can complete the full Rhumbix workflow in the browser.
- Counts and history reconcile with PowerBuilder.
- Errors are durable enough for support after browser refresh.
- Shared grid/API patterns are reusable for the next module.

## Technical Decisions To Resolve

| Decision | Preferred Direction | Reason |
| --- | --- | --- |
| Import error storage | Persist by run ID | Temp tables are fragile across web request boundaries. |
| User ID sent to import SP | Authenticated web user, with fallback if procedure requires `RHUMBIX` | Improves audit trail without breaking existing procedure behavior. |
| Sync history row limit | Start with top 20 | Matches existing DataWindow behavior. |
| Book source | Existing Abio permissions/config table | Avoid hard-coded `ISSL-LP` in web app. |
| AG Grid row model | Server-side | Reusable pattern for large ERP grids. |

## Manual Reconciliation Checklist

- Same book selected in PowerBuilder and web app.
- Same date range and PR period.
- Import count matches.
- Error count matches.
- Total from Rhumbix count matches.
- Error detail rows match.
- Pending project count matches.
- Sync history rows match.
- Force full sync behavior matches.
- Failed stored procedure behavior is visible and logged.

## Risks

- `#import_summary` and `#timesheet_import_errors` may not be accessible after the stored procedure call unless the same SQL connection and session are preserved.
- Stored procedures may depend on desktop session assumptions.
- Existing PowerBuilder uses message boxes; the web flow needs durable error and run state.
- Book/security behavior is currently hard-coded in the exported window and needs real source validation.
- Full PowerBuilder source export may reveal additional Rhumbix-related objects not visible in the current exported files.
