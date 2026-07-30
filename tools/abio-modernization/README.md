# Abio Modernization Package

This folder contains the working modernization plan for moving the Abio PowerBuilder desktop application toward an Angular, AG Grid, ASP.NET Core, and SQL Server web platform.

## Documents

- [Target Architecture](TargetArchitecture.md) describes the proposed platform shape, major application layers, and PowerBuilder-to-web mapping rules.
- [Module Migration Plan](ModuleMigrationPlan.md) sequences the current PowerBuilder library areas into practical migration waves.
- [Rhumbix Pilot Blueprint](RhumbixPilotBlueprint.md) defines a concrete first pilot based on the exported `w_rhumbix_integration.srw` and related DataWindow objects.
- [Rhumbix Pilot Implementation Package](rhumbix-pilot/README.md) contains API contracts, AG Grid column definitions, and sprint-level implementation tasks for the first pilot.
- [PowerBuilder Source Export Guide](PowerBuilderSourceExportGuide.md) captures the remaining full-source export step and how to rerun the inventory after export.
- [Inventory Summary](inventory/InventorySummary.md) contains the current generated inventory from `E:\Abio`.
- [PBL Binary Hints Summary](inventory-binary-hints/BinaryHintsSummary.md) contains a non-authoritative pre-export scan of likely object names inside the PBL binaries.
- [Pre-Export Sizing Summary](pre-export-sizing/PreExportSizingSummary.md) turns the inventory and binary hints into a rough module and library complexity ranking.
- [Runnable Prototype](prototype/README.md) contains the Angular + AG Grid + ASP.NET Core Rhumbix pilot skeleton.

## Current Assessment

The proposed migration is feasible, but it should be treated as a replatforming effort rather than a source-to-source conversion. Angular and AG Grid replace much of the PowerBuilder desktop UI and DataWindow interaction model, while ASP.NET Core becomes the home for business logic, validation, data access, transactions, and integrations.

The current inventory found 46 target libraries totaling about 359 MB, but only 6 exported source files beside the PBLs. A heuristic binary scan also found 3,562 likely object-name hints, including 2,212 DataWindows and 326 windows. The strongest next step is still to export the full PowerBuilder source from the `.pbl` libraries, rerun the inventory script, and validate the Rhumbix pilot before estimating the remaining modules in detail.

The pre-export sizing view suggests that shared foundation/framework replacement, reporting, job cost, AP, AR, payroll, and administration deserve the earliest discovery attention. Dashboard remains a good pilot candidate because it is much smaller and aligns well with Angular plus AG Grid.

The first runnable prototype now lives in `prototype/`. Its default screen is a read-only core Abio operations console backed by the restored `ABIO_DEMO` database on `.\ERPLINK`. It uses Angular 19 because the installed Node version is `22.11.0`; the latest Angular CLI requires a newer Node 22 patch level.
