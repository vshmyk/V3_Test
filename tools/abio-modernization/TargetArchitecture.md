# Abio Target Architecture

## Purpose

This document proposes the target architecture for modernizing the Abio PowerBuilder desktop application into a web application with Angular for the front end, AG Grid as the primary replacement for grid-style PowerBuilder DataWindows, ASP.NET Core for application logic, and SQL Server as the data platform.

## Architecture Overview

```text
Users
  -> Angular Web App
     -> Application Shell
     -> Feature Modules
     -> Shared UI Components
     -> AG Grid Framework
     -> Auth, Session, Notifications

Angular Web App
  -> ASP.NET Core Web API

ASP.NET Core Web API
  -> Feature Endpoints
  -> Application Services
  -> Validation and Authorization
  -> Integration Services
  -> Reporting Services

Application Services
  -> Query and Repository Layer
  -> Stored Procedures and SQL
  -> SQL Server

Reporting Services
  -> PDF, Excel, and Formal Documents
```

## Frontend Architecture

The Angular application should provide the user-facing shell, routing, screen layout, forms, dialogs, grids, dashboards, notifications, and client-side validation.

Recommended frontend areas:

- `AppShell`: navigation, session state, current company/book context, user menu, and global notifications.
- `FeatureModules`: one Angular feature area per major Abio business domain.
- `SharedUi`: forms, buttons, dialogs, filter bars, lookup controls, status badges, and confirmation flows.
- `AbioGrid`: a reusable AG Grid wrapper that standardizes DataWindow-like behavior across modules.
- `ReportingViewer`: report launch, parameter capture, PDF preview, Excel export, and report history.

Angular should not connect directly to SQL Server. All data access and business actions should go through ASP.NET Core APIs.

## AG Grid Framework

AG Grid is the recommended replacement for operational DataWindow grids, lookup lists, editable transaction lines, dashboard drill-downs, and inquiry screens.

The reusable grid layer should support:

- server-side paging, sorting, and filtering;
- reusable column metadata;
- inline editing and batch save;
- inserted, updated, and deleted row tracking;
- lookup editors;
- validation markers;
- pinned summaries and grouped totals;
- row-level actions;
- export to Excel and CSV;
- saved grid layouts per user where useful.

AG Grid should not be treated as the replacement for every DataWindow. Report-style DataWindows and formal documents should move to the reporting subsystem.

## Backend Architecture

ASP.NET Core should own the application behavior currently spread across PowerBuilder windows, user objects, DataWindow update rules, embedded SQL, and transaction scripts.

Recommended backend areas:

- `Api`: HTTP endpoints and request/response contracts.
- `Application`: commands, queries, validation, authorization checks, transactions, and orchestration.
- `Domain`: core business concepts and reusable rules where the model is stable enough to justify them.
- `Data`: SQL Server access, stored procedure calls, query composition, and persistence.
- `Integrations`: external systems such as Rhumbix, ClockShark, file import/export, email, and document storage.
- `Reporting`: report generation, report parameters, PDF/Excel rendering, and report audit history.

For the first phases, it is reasonable to keep some stored procedures and SQL-heavy logic in the database when rewriting it would introduce avoidable risk.

## Data Platform

The current application is already configured for SQL Server access in `E:\Abio\abio.ini`. SQL Server should remain the primary database during the migration.

The web platform should introduce:

- connection strings managed by environment and deployment configuration;
- application-level authorization around all data access;
- explicit transaction boundaries in backend services;
- optimistic concurrency or equivalent conflict detection for editable transactional screens;
- audit logging for financial and payroll workflows;
- migration scripts for new web-specific tables, such as user preferences, grid layouts, and report history.

## Reporting Strategy

PowerBuilder DataWindows need to be split into operational grids and formal reports.

Operational grids should move to Angular plus AG Grid. Formal reports, documents, cheques, remittances, invoices, statements, and statutory outputs should move to a reporting tool.

Candidate reporting options:

- SSRS for SQL-centered paginated reports;
- DevExpress or Telerik for rich .NET report design and web preview;
- QuestPDF for code-defined PDFs where layouts are controlled by developers;
- Excel generation for analysis-oriented exports.

The reporting choice should be validated with two or three representative Abio outputs before standardizing.

## PowerBuilder Mapping Rules

| PowerBuilder Concept | Web Platform Equivalent |
| --- | --- |
| Application target `.pbt` | ASP.NET Core solution plus Angular workspace |
| Library `.pbl` | Feature module or backend bounded area |
| Window `.srw` | Angular page, dialog, or routed feature component |
| Menu `.srm` and ribbon XML | Angular shell navigation and contextual action bars |
| Grid-style DataWindow `.srd` | AG Grid screen or grid region |
| Report-style DataWindow `.srd` | Reporting subsystem |
| User object `.sru` | Angular shared component or ASP.NET Core service, depending on responsibility |
| Embedded SQL | Backend query/repository/service layer |
| PowerBuilder validation events | ASP.NET Core validation plus Angular pre-validation |
| PowerBuilder transaction scripts | ASP.NET Core application services with explicit transactions |
| MessageBox workflows | Angular dialog, toast, or validation summary |

## Suggested Repository Shape

If the modernization work lives in a new codebase, this shape would keep concerns clear:

```text
src/
  Abio.Web/                 Angular application
  Abio.Api/                 ASP.NET Core API
  Abio.Application/         commands, queries, orchestration
  Abio.Domain/              domain models and reusable rules
  Abio.Data/                SQL Server access
  Abio.Integrations/        external services
  Abio.Reporting/           report services
  Abio.Contracts/           shared DTOs and API contracts
tests/
  Abio.Application.Tests/
  Abio.Api.Tests/
  Abio.Data.Tests/
docs/
  architecture/
  migration/
```

## Key Decisions

- Angular is the UI framework, not the business logic host.
- AG Grid is the standard DataWindow replacement for tabular interaction.
- ASP.NET Core owns business rules, transactions, database access, and integration workflows.
- SQL Server remains the system of record during modernization.
- Reports are a parallel migration stream, not an AG Grid responsibility.
- The first pilot should prove the full vertical path: Angular screen, AG Grid, .NET service, SQL Server access, validation, logging, and deployment.
