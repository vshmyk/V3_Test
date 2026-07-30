# Rhumbix Pilot Implementation Package

This folder turns the Rhumbix modernization pilot into implementation-ready artifacts.

## Source Objects

- `E:\Abio\w_rhumbix_integration.srw`
- `E:\Abio\d_rhumbix_import_errors.srd`
- `E:\Abio\d_rhumbix_sync_history.srd`

## Documents

- [ApiContracts.md](ApiContracts.md) defines the ASP.NET Core API surface and DTOs.
- [AgGridColumnDefs.json](AgGridColumnDefs.json) defines the first-pass AG Grid columns for import errors and sync history.
- [ImplementationPlan.md](ImplementationPlan.md) breaks the pilot into buildable work items.

## Pilot Goal

Build one vertical slice of the target platform:

- Angular page for Rhumbix import and project sync;
- AG Grid replacement for the two DataWindows;
- ASP.NET Core endpoints and services;
- SQL Server stored procedure integration;
- validation, logging, and acceptance checks against the PowerBuilder behavior.
