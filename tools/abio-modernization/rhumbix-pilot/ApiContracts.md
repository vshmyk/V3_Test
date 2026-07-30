# Rhumbix API Contracts

## Purpose

These contracts map the exported PowerBuilder Rhumbix workflow to ASP.NET Core endpoints. They are intended as a first implementation baseline and should be adjusted after validating the actual stored procedure result sets in SQL Server.

## Source Behavior

PowerBuilder window:

- defaults `book` to `ISSL-LP`;
- defaults start and end date to today;
- computes PR period as `YYYYMM`;
- validates start date, end date, and PR period;
- counts pending projects from `centre`;
- imports timesheets through `sp_RhumbixImportTimesheets_NoCLR`;
- syncs projects through `sp_RhumbixSyncProjects`;
- displays errors from `#timesheet_import_errors`;
- displays recent sync history from `rhumbix_sync_log`.

## Endpoints

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/api/rhumbix/config` | Return defaults, allowed books, and current PR period. |
| `GET` | `/api/rhumbix/pending-count?book={book}` | Return pending project count for the selected book. |
| `GET` | `/api/rhumbix/import-errors` | Return paged import errors for AG Grid. |
| `GET` | `/api/rhumbix/sync-history` | Return recent sync history for AG Grid. |
| `POST` | `/api/rhumbix/import-timesheets` | Validate request and run the timesheet import stored procedure. |
| `POST` | `/api/rhumbix/sync-projects` | Validate request and run the project sync stored procedure. |

## DTOs

### RhumbixConfigResponse

```csharp
public sealed record RhumbixConfigResponse(
    string DefaultBook,
    IReadOnlyList<string> AllowedBooks,
    DateOnly DefaultStartDate,
    DateOnly DefaultEndDate,
    int CurrentPrPeriod,
    bool CanImportTimesheets,
    bool CanSyncProjects);
```

### Pending Count

```csharp
public sealed record RhumbixPendingCountResponse(
    string Book,
    int PendingProjectCount);
```

SQL source:

```sql
SELECT COUNT(*)
FROM centre
WHERE book = @book
  AND rhumbix_sync_pending = 'Y'
  AND active_flag = 'Y'
  AND cost_type LIKE '%L%';
```

### Import Timesheets

```csharp
public sealed record RhumbixImportTimesheetsRequest(
    string Book,
    DateOnly StartDate,
    DateOnly EndDate,
    int PrPeriod);

public sealed record RhumbixImportTimesheetsResponse(
    long RunId,
    int ImportedCount,
    int ErrorCount,
    int TotalFromRhumbix,
    string Status,
    string Message);
```

Stored procedure:

```sql
EXEC sp_RhumbixImportTimesheets_NoCLR
  @book = @Book,
  @start_date = @StartDate,
  @end_date = @EndDate,
  @pr_yyyymm = @PrPeriod,
  @user_id = @UserId;
```

Current PowerBuilder behavior uses `RHUMBIX` as the user ID. The web version should prefer the authenticated user ID when available, while preserving compatibility if the stored procedure expects a system value.

### Sync Projects

```csharp
public sealed record RhumbixSyncProjectsRequest(
    string Book,
    bool ForceFullSync);

public sealed record RhumbixSyncProjectsResponse(
    long RunId,
    string Status,
    string Message);
```

Stored procedure:

```sql
EXEC sp_RhumbixSyncProjects
  @book = @Book,
  @force_full_sync = @ForceFullSync;
```

### Import Error Row

```csharp
public sealed record RhumbixImportErrorRow(
    long ErrorId,
    string? EmployeeId,
    DateOnly? ShiftDate,
    string? RhumbixProject,
    string? RhumbixCostCode,
    string? ErrorType,
    string? ErrorMessage,
    DateTime? ErrorDateTime);
```

PowerBuilder DataWindow source:

```sql
SELECT error_id,
       employee_id,
       shift_date,
       rhumbix_project,
       rhumbix_cost_code,
       error_message,
       error_type,
       error_datetime
FROM #timesheet_import_errors
ORDER BY error_datetime DESC;
```

The temp table dependency needs validation. For a web API, error rows may need to be persisted to a real run-log table or returned directly from the import procedure response.

### Sync History Row

```csharp
public sealed record RhumbixSyncHistoryRow(
    DateTime SyncDateTime,
    string? SyncType,
    decimal? RecordsAttempted,
    decimal? RecordsCreated,
    decimal? RecordsUpdated,
    decimal? RecordsFailed,
    string StatusDisplay);
```

PowerBuilder DataWindow source:

```sql
SELECT TOP 20
    sync_datetime,
    sync_type,
    records_attempted,
    records_created,
    records_updated,
    records_failed,
    CASE
        WHEN records_failed > 0 THEN 'Failed'
        ELSE 'Success'
    END as status_display
FROM rhumbix_sync_log
WHERE book = @book
ORDER BY sync_datetime DESC;
```

## Grid Query Contract

Use one common contract for AG Grid-backed reads:

```csharp
public sealed record GridQueryRequest(
    int StartRow,
    int EndRow,
    IReadOnlyList<GridSortModel> SortModel,
    IReadOnlyDictionary<string, GridFilterModel> FilterModel);

public sealed record GridQueryResponse<T>(
    IReadOnlyList<T> Rows,
    int RowCount);
```

For the pilot, `sync-history` can return only the top 20 rows to match the current PowerBuilder behavior. The endpoint should still use the shared grid response shape so it is reusable.

## Validation Rules

Backend validation:

- `Book` is required.
- `Book` must be allowed for the current user.
- `StartDate` is required and must be on or after `1900-01-01`.
- `EndDate` is required in the web UI and must be greater than or equal to `StartDate`.
- `PrPeriod` is required for import and must be in `YYYYMM` format.
- `PrPeriod` must be between `190001` and `999912`.
- Import requires `CanImportTimesheets`.
- Sync requires `CanSyncProjects`.

Angular should duplicate these checks for immediate feedback, but ASP.NET Core is authoritative.

## Error Shape

```csharp
public sealed record ApiErrorResponse(
    string Code,
    string Message,
    IReadOnlyList<ApiFieldError> Errors);

public sealed record ApiFieldError(
    string Field,
    string Message);
```

Example:

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

## Open Validation Items

- Confirm whether `sp_RhumbixImportTimesheets_NoCLR` returns `#import_summary` reliably across API connection scope.
- Confirm whether `#timesheet_import_errors` is readable after the stored procedure call from the same connection.
- Confirm whether import errors should be persisted by `runId` for browser refresh and audit.
- Confirm the authenticated web user value expected by the import procedure.
- Confirm whether `book` values should come from an existing Abio security table.
