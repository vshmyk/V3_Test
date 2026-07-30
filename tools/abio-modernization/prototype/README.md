# Abio Modernization Prototype

This prototype is the first runnable Angular, AG Grid, ASP.NET Core, and SQL Server slice for the Abio modernization plan. The default screen is now a read-only core Abio operations console backed by the restored `ABIO_DEMO` database.

## Projects

- `Abio.Api`: ASP.NET Core Web API with live read-only core endpoints against `ABIO_DEMO`, plus the earlier mock Rhumbix endpoints.
- `Abio.Web`: Angular 19 app with AG Grid, default core operations console, and the Rhumbix page preserved at `/rhumbix`.

## Run

Start the API:

```powershell
dotnet run --project .\Abio.Api\Abio.Api.csproj
```

Start the Angular app:

```powershell
cd .\Abio.Web
npm start
```

Then open:

```text
http://localhost:4200
```

The Angular dev server usually binds to:

```text
http://127.0.0.1:4200
```

## Current Scope

Core endpoints are backed by `ABIO_DEMO` on `.\ERPLINK` using Windows authentication.

Job Entry migration notes are tracked in `JobEntryLegacyMapping.md`. That mapping should be used before enabling write behavior because the Job Entry form depends on legacy PowerBuilder logic from `jobcost.pbl`, especially `w_jc_job`, `d_jc_job_detail`, `d_jc_job_detail_finance`, and related business/user objects.

Implemented live core endpoints:

- `GET /api/core/config`
- `GET /api/core/menu?userId=SHYMKVIK`
- `GET /api/core/summary?book=ABIODEMO`
- `GET /api/core/clients?book=ABIODEMO`
- `GET /api/core/jobs?book=ABIODEMO`
- `GET /api/core/vendors?book=ABIODEMO`
- `GET /api/core/ap-invoices?book=ABIODEMO`
- `GET /api/core/ar-invoices?book=ABIODEMO`
- `GET /api/core/timesheets?book=ABIODEMO`
- `GET /api/core/job-overview?book=ABIODEMO&job=6101`
- `GET /api/core/job-timesheets?book=ABIODEMO&job=6101`
- `GET /api/core/job-ap-invoices?book=ABIODEMO&job=6101`
- `GET /api/core/job-ar-invoices?book=ABIODEMO&job=6101`
- `GET /api/core/job-cost-transactions?book=ABIODEMO&job=6101`

The default Angular console now loads the left-side legacy menu from `dbo.abio_menu`, following the `d_abio_menu` DataWindow retrieve logic found in `abio.pbl`. It also appends active report rows from `dbo.program_report` under matching report-menu entries, mirroring the PowerBuilder menu constructor behavior.

Legacy menu quick access is also supported. Press `Ctrl+Q` to enter menu shortcut mode, then press the visible bracket letters in sequence, for example `a`, then `i` for Payables -> Invoice Entry. Press `Backspace` to move up one menu level or `Esc` to cancel.

The console also includes a read-only Jobs master/detail flow. Open the Jobs tab and select a job row to load overview totals plus related timesheets, AP invoices, AR invoices, and job cost transactions in a second AG Grid. Job `6101` is a useful demo record because it has activity in all four child areas.

Rhumbix endpoints still use mock API responses. The later Rhumbix implementation step is replacing those mock handlers in `Abio.Api\Program.cs` with SQL Server queries and calls to:

- `sp_RhumbixImportTimesheets_NoCLR`
- `sp_RhumbixSyncProjects`

The API is configured for local Angular CORS at `http://localhost:4200` and `http://127.0.0.1:4200`.
