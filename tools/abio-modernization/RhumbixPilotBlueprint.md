# Rhumbix Pilot Blueprint

## Purpose

This blueprint defines a first modernization pilot for the Abio application based on the exported PowerBuilder window `E:\Abio\w_rhumbix_integration.srw` and related DataWindow objects.

The goal is to prove the complete target architecture with one contained feature:

- Angular screen;
- AG Grid result lists;
- ASP.NET Core API;
- SQL Server access;
- validation;
- import and sync actions;
- logging and error handling.

Implementation-ready companion files are available in [rhumbix-pilot](rhumbix-pilot/README.md).

## Source Signals

Visible source objects:

- `E:\Abio\w_rhumbix_integration.srw`: PowerBuilder window with date filters, PR period, import action, sync action, result counts, error DataWindow, and sync history DataWindow.
- `E:\Abio\d_rhumbix_import_errors.srd`: DataWindow showing import errors.
- `E:\Abio\d_rhumbix_sync_history.srd`: DataWindow showing sync history.
- `E:\Abio\abio.ini`: SQL Server connection configuration pattern.

Observed behaviors from the exported window:

- set date range shortcuts;
- compute current PR period as `YYYYMM`;
- validate start date, end date, and PR period;
- count pending projects;
- retrieve sync history;
- import timesheets;
- sync projects;
- show result counts and messages.

## Pilot Scope

In scope:

- book/company selector;
- start date and end date filters;
- PR period input;
- Today, This Week, and Last Week shortcuts;
- Import Timesheets action;
- Sync Projects action;
- pending project count;
- imported, error, and total result counts;
- AG Grid for import errors;
- AG Grid for sync history;
- backend validation and transaction handling;
- structured logging for import and sync runs.

Out of scope for the first pilot:

- full payroll module migration;
- full project management module migration;
- replacing all Rhumbix-related stored procedures or SQL if existing database logic can be safely reused;
- formal reporting beyond grid export.

## Angular Screen Design

Route:

```text
/integrations/rhumbix
```

Main regions:

- header action bar with book selector, refresh, import, and sync actions;
- filter form with start date, end date, PR period, and date shortcut buttons;
- compact status strip for pending projects and last sync;
- result counters for imported, errors, and total;
- tabbed content area with Import Errors and Sync History;
- AG Grid instance for each tab.

Recommended Angular components:

```text
RhumbixIntegrationPage
RhumbixFilterForm
RhumbixSummaryStrip
RhumbixErrorsGrid
RhumbixSyncHistoryGrid
```

## AG Grid Mapping

### Import Errors Grid

PowerBuilder source:

```text
d_rhumbix_import_errors.srd
```

Suggested columns:

| Field | Header | Type |
| --- | --- | --- |
| `errorId` | Error # | number |
| `employeeId` | Employee | text |
| `shiftDate` | Date | date |
| `rhumbixProject` | Project | text |
| `rhumbixCostCode` | Cost Code | text |
| `errorType` | Error Type | text |
| `errorMessage` | Error Message | text |
| `errorDateTime` | Time | dateTime |

Suggested grid behavior:

- server-side filtering and sorting;
- default sort by `errorDateTime` descending;
- quick filter;
- CSV/Excel export;
- row detail panel if error messages become too long.

### Sync History Grid

Suggested columns should be confirmed from the exported `d_rhumbix_sync_history.srd`, then implemented with the same grid wrapper.

Expected behavior:

- server-side filtering and sorting;
- default sort by sync time descending;
- status badge renderer;
- details action for failed sync rows.

## API Contract

Suggested endpoints:

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/api/rhumbix/config` | Return defaults, books, permissions, and current PR period |
| `GET` | `/api/rhumbix/pending-count?book=...` | Return pending project count |
| `GET` | `/api/rhumbix/import-errors` | Return paged AG Grid result for import errors |
| `GET` | `/api/rhumbix/sync-history` | Return paged AG Grid result for sync history |
| `POST` | `/api/rhumbix/import-timesheets` | Validate and execute import |
| `POST` | `/api/rhumbix/sync-projects` | Validate and execute project sync |

### Request: Import Timesheets

```json
{
  "book": "ISSL",
  "startDate": "2026-07-01",
  "endDate": "2026-07-03",
  "prPeriod": 202607
}
```

### Response: Import Timesheets

```json
{
  "runId": 12345,
  "importedCount": 38,
  "errorCount": 2,
  "totalCount": 40,
  "message": "Import completed with errors."
}
```

### Response: Validation Error

```json
{
  "code": "VALIDATION_FAILED",
  "message": "Please correct the highlighted fields.",
  "errors": [
    {
      "field": "endDate",
      "message": "End date must be greater than or equal to start date."
    }
  ]
}
```

## Backend Services

Recommended services:

```text
RhumbixController
RhumbixApplicationService
RhumbixImportService
RhumbixProjectSyncService
RhumbixQueryService
RhumbixRunLogService
```

Responsibilities:

- validate date ranges and PR period;
- verify user permission for selected book;
- count pending projects;
- run import inside a clear transaction boundary;
- run project sync inside a clear transaction boundary;
- record run log and outcome counts;
- return structured errors to Angular;
- expose paged results for AG Grid.

## Validation Rules

Initial rules based on the PowerBuilder window:

- `startDate` is required and must be a valid date.
- `endDate` is optional in PB but should default to `startDate` in the web UI.
- `endDate` must be greater than or equal to `startDate`.
- `prPeriod` is required and must use `YYYYMM` format.
- `prPeriod` must be between `190001` and `999912`.
- `book` is required and must be allowed for the current user.

The backend should enforce all rules. Angular should also pre-validate them for immediate feedback.

## Logging And Audit

Each import or sync should create a run log entry with:

- run ID;
- user ID;
- book;
- action type;
- start time;
- end time;
- status;
- request parameters;
- imported count;
- error count;
- total count;
- exception details when applicable.

This is important because the web system will replace desktop message flows with durable operational visibility.

## Testing Plan

Backend tests:

- valid date range imports successfully;
- invalid start date fails validation;
- end date before start date fails validation;
- invalid PR period fails validation;
- unauthorized book fails authorization;
- import service logs success and failure;
- sync service logs success and failure.

Frontend tests:

- date shortcuts populate expected date ranges;
- invalid filters disable or block import action;
- import result counts render after success;
- error grid requests server-side data with expected filters;
- sync history grid refreshes after sync action.

Manual acceptance:

- compare imported/error/total counts against PowerBuilder for the same input;
- compare import error rows against `d_rhumbix_import_errors`;
- compare sync history rows against `d_rhumbix_sync_history`;
- confirm permissions and book filtering;
- confirm performance with production-like row counts.

## Pilot Success Criteria

The pilot is successful when:

- a user can complete the Rhumbix import and sync workflow in the browser;
- AG Grid replaces the relevant DataWindow result lists;
- backend validation matches or improves the PowerBuilder behavior;
- results reconcile with the existing desktop workflow;
- logs make each run traceable;
- the shared grid and API patterns are reusable for the next module.

## Follow-On Work

After pilot acceptance:

- harden the reusable `AbioGrid` wrapper;
- finalize API response standards;
- finalize report/export strategy;
- inventory the next Dashboard or Administration screens;
- use actual pilot velocity to refine the full modernization estimate.
