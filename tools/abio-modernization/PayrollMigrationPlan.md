# Abio Payroll Migration Plan

## Purpose

This document prepares the Payroll module migration from Abio Legacy PowerBuilder to Abio NG. It is based on the restored `ABIO_DEMO` database, the legacy menu metadata, and the exported PowerBuilder source from `E:\Abio\Prg`.

Payroll should be treated as a high-risk command-layer migration. The Angular UI can modernize the experience, but persistence, recalculation, approval, cheque issuing, posting, period advancement, and cleanup must be implemented as explicit .NET services that preserve the legacy PowerBuilder program logic.

## Legacy Source Reviewed

PowerBuilder source was exported with the PB 25 utilities and runtime from:

- `E:\Abio\PowerBuilderUtilities 25.0`
- `E:\Abio\Runtime 25.0.0.3711`
- `E:\Abio\Prg`

Exported Payroll source is under:

- `pb-exported-source/payroll.pbl.src`
- `pb-exported-source/timesheet.pbl.src`
- `pb-exported-source/reports_pr.pbl.src`
- `pb-exported-source/shared_tables.pbl.src`
- `pb-exported-source/table.pbl.src`

Important exported objects:

| Area | Legacy objects |
| --- | --- |
| Employee Entry | `w_pr_employee.srw`, `u_cst_pr_employee_detail.sru`, `u_cst_pr_employee_cheque.sru`, `n_bo_employee.sru`, `d_bo_employee.srd`, employee child BO/DataWindows |
| Timesheet Entry | `w_pr_timesheet.srw`, `n_bo_timesheet.sru`, `n_bo_timesheet_premium.sru`, `d_pr_timesheet_detail.srd`, `d_bo_timesheet.srd`, premium DataWindows |
| Field Timesheet Review | `w_pr_field_timesheet.srw`, `n_bo_field_timesheet.sru`, `d_pr_field_timesheet_detail.srd`, `d_bo_field_timesheet.srd` |
| Cheque Entry | `w_pr_pr_cheque.srw`, `n_bo_pr_cheque.sru`, cheque child BOs, `d_bo_pr_cheque.srd`, pay/earn/premium/WCB/union/occupation DataWindows |
| Reports | `reports_pr.pbl.src` report DataWindows for employee, timesheet, cheque, PD7A, and union remittance reporting |
| Setup | Pay periods, federal/provincial tax, WCB, premium types, timesheet status, occupation, occupation rates, trade union, union rates, benefits, and premiums |

Some referenced names were not exported by the focused pass and should be revisited during implementation if needed:

- `n_bo_pr_cheque_save.sru`
- `u_cst_employee_detail.sru`
- `u_cst_pr_cheque_premium_selection.sru`
- `d_pr_employee.srd`
- `d_pr_employee_prn.srd`

## Legacy Payroll Menu Scope

The Payroll menu in `dbo.abio_menu` exposes these functional areas:

| Program | Legacy purpose |
| --- | --- |
| `PREENT` | Employee Entry: add, change, terminate, and rehire employees |
| `PREREP` | Employee Reports |
| `PRFENT` | Field Timesheet Review: process field timesheets |
| `PRTENT` | Timesheet Entry: add, change, and recalculate timesheets |
| `PRTREP` | Timesheet Reports |
| `PRCQCR` | Create Cheques from available timesheets |
| `PRCQAP` | Approve Cheques prior to issuing |
| `PRCENT` | Cheque Entry: approve, change, reconcile, and void cheques |
| `PRCREP` | Cheque Reports |
| `PRCHEQ` | Issue or reprint cheques and update employee earnings |
| `PRTRAN` | Cost issued cheque costs to Job Cost and General Ledger |
| `PRMEND` | Advance pay period and/or G/L period |
| `PRARCH` | Clean up paid timesheets and costed, reconciled cheques to history |
| `PRSETU` | Payroll setup: crews, unions, benefits, premiums, occupations, tax, WCB, pay periods, statuses, email setup |

This menu structure should become the initial Payroll navigation in Abio NG, but write actions should remain disabled until their corresponding .NET command services are migrated and tested.

## Database Scope

The main Payroll tables in `ABIO_DEMO` include:

| Entity | Table notes |
| --- | --- |
| Employee | `employee` has 121 columns and child tables `employee_earning`, `employee_premium`, `employee_purchase`, `employee_wcb` |
| Timesheet | `timesheet` has 72 columns and child table `timesheet_premium` |
| Field Timesheet | `field_timesheet` stores imported/reviewed mobile/field timesheet batches and updates `timesheet` as a child |
| Cheque | `pr_cheque` has 157 columns and child tables for premiums, queue, trade union, WCB, occupation, and related employee updates |
| Setup | `pay_period`, `trade_union`, `occupation`, `occupation_rate`, `premium_type`, `wcb_rate`, `timesheet_status`, federal/provincial tax tables |

Representative restored row counts:

| Table | Rows |
| --- | ---: |
| `employee` | 310 |
| `timesheet` | 5,970 |
| `field_timesheet` | 217 |
| `pr_cheque` | 750 |
| `pr_cheque_queue` | 468 |
| `occupation_rate` | 3,915 |
| `trade_union_rate` | 135 |
| `premium_type` | 52 |
| `timesheet_status` | 14 |

## Key Legacy Behavior Observed

Employee Entry:

- `w_pr_employee` opens tabs for Details, Cheque & Dues, Incentive & Accrual, Premiums, Earnings, and WCB.
- `n_bo_employee` defines the primary key `book, employee`, extensive required-field rules, expression validations, defaults, and helper functions for restrict flags and termination dates.
- `u_cst_pr_employee_detail` contains program-layer action behavior for add, change, terminate, re-employ, history, report opening, person-derived defaults, crew/supervisor lookup behavior, and creation of current-year employee earnings.

Timesheet Entry:

- `w_pr_timesheet` opens Details and Premiums tabs.
- `n_bo_timesheet` defines primary key `book, employee, work_date, timesheet_item`.
- Timesheet logic includes next item selection, last paid/last worked lookup, subtotal calculation, premium validation, pay period validation, date conversion, ISSL import insertion, and defaults for hours, earnings, file type, transaction flags, and audit columns.
- The timesheet detail DataWindow contains protected/calculated cheque and costing fields. Cheque-created/costed rows must not be treated as ordinary editable records.

Field Timesheet Review:

- `w_pr_field_timesheet` opens Details and Document tabs.
- `n_bo_field_timesheet` defines primary key `book, work_date, add_user_id, field_timesheet_item`.
- The field timesheet BO adds `n_bo_timesheet` as a child so parent review updates can update timesheets in the same transaction set.

Cheque Entry:

- `w_pr_pr_cheque` opens Gross & Net, Earn & Loss, Premiums, WCB, and conditionally Union and Occupation tabs.
- Gross & Net and Earn & Loss share the same `pr_cheque` record.
- `n_bo_pr_cheque` has large defaulting and validation logic, and explicitly registers children for reverse, issue, and create flows: timesheets, premiums, employee, employee earnings, WCB, queue, company, union, occupation, and purchases.
- Cheque actions include approve, change, reconcile, void/reverse, print/issue, reprint, and queue processing. These should be modeled as commands, not generic updates.

Setup:

- Payroll setup objects come from `shared_tables.pbl.src` and `table.pbl.src`.
- Setup tables are not low-risk just because they look like maintenance tables. Tax, WCB, union, occupation, premium, and pay period setup directly influence payroll calculations and posting.

## Target Abio NG Architecture

Recommended module structure:

- Angular routes under `/payroll`.
- AG Grid for lists and inquiry grids.
- Record pages for employee, timesheet, field timesheet, cheque, and setup details.
- Searchable lookup controls using the same valid-option restriction pattern already introduced for Job Entry.
- .NET services for read models, validation, and commands.
- Stored SQL limited to data access and set-based queries; business decisions should be visible in .NET command services unless preserving a database-side legacy routine is intentional.

Recommended API surface:

| API area | Initial endpoints |
| --- | --- |
| Employees | `GET /api/payroll/employees`, `GET /api/payroll/employees/{employee}` |
| Timesheets | `GET /api/payroll/timesheets`, `GET /api/payroll/timesheets/{employee}/{workDate}/{item}` |
| Field Timesheets | `GET /api/payroll/field-timesheets`, `GET /api/payroll/field-timesheets/{workDate}/{userId}/{item}` |
| Cheques | `GET /api/payroll/cheques`, `GET /api/payroll/cheques/{chequeNo}` |
| Setup | `GET /api/payroll/setup/*` for pay periods, statuses, unions, occupations, WCB, premiums, and taxes |
| Commands | `POST /api/payroll/*/commands/{commandName}` after each legacy command is migrated |

For write behavior, avoid endpoints such as `PUT /api/payroll/timesheets/{id}` until the equivalent PB action/event path has been migrated. Use explicit commands such as `ChangeTimesheet`, `RecalculateTimesheet`, `ApproveCheque`, `VoidCheque`, `IssueCheque`, `CostPayroll`, and `AdvancePayPeriod`.

## Migration Sequence

### Phase 0 - Payroll Discovery Baseline

Deliverables:

- Complete source-export gap check for missing referenced Payroll objects.
- DataWindow SQL and update-column extraction for employee, timesheet, field timesheet, cheque, and setup objects.
- Report inventory from `PREREP`, `PRTREP`, and `PRCREP`.
- Command inventory for create cheques, approve cheques, issue cheques, payroll costing, period advance, and cleanup.
- Side-by-side test dataset selection from `ABIO_DEMO`.

Acceptance:

- Every Payroll menu item maps to source objects, database tables, and target migration status.
- High-risk commands are flagged as disabled until migrated.

### Phase 1 - Read-Only Payroll Shell

Deliverables:

- Payroll landing page in Abio NG.
- Left-menu integration for Payroll nodes and `/cbc`-style shortcut search.
- AG Grid lists for Employees, Timesheets, Field Timesheets, Cheques, and Setup.
- Hyperlink navigation from Employee, Timesheet, Cheque, Job, Union, Occupation, and WCB fields.
- Read-only record pages matching the legacy tab structure.

Recommended first UI tabs:

| Record | Tabs |
| --- | --- |
| Employee | Details, Cheque & Dues, Incentive & Accrual, Premiums, Earnings, WCB |
| Timesheet | Details, Premiums |
| Field Timesheet | Details, Document |
| Cheque | Gross & Net, Earn & Loss, Premiums, WCB, Union, Occupation |

Acceptance:

- Counts and list results reconcile with PB for the same book and filters.
- Record pages show legacy-equivalent fields and child rows.
- No Payroll writes are enabled.

### Phase 2 - Payroll Setup Read/Edit, With Guardrails

Deliverables:

- Read-only setup pages first.
- Command-layer edit for safe setup entities only after rules are migrated.
- Lookup endpoints used by Employee and Timesheet edit modes.

Suggested order:

1. Timesheet Status.
2. Premium Type.
3. Occupation and Occupation Rate.
4. WCB Class and WCB Rate.
5. Trade Union, Union Rate, Union Benefit, Union Premium.
6. Pay Period Start Dates.
7. Federal and Provincial Tax setup.

Acceptance:

- Edits pass legacy validation rules and DB constraints.
- Setup changes have audit coverage and can be reconciled.
- Tax/WCB/union setup changes require role-based permission.

### Phase 3 - Employee Entry Commands

Deliverables:

- Employee read model and child-tab read models.
- Employee edit command service based on `n_bo_employee` and `u_cst_pr_employee_detail`.
- Commands for Add, Change, Terminate, Re-employ, and History.
- Validated dropdowns for province, tax province, union, occupation, WCB, region, shift, job, centre, GL account, ROE reason, and related flags.

Acceptance:

- Add defaults match PB for a new employee.
- Change preserves protected/calculated fields.
- Terminate and re-employ reproduce PB behavior, including ROE fields, termination date rules, and current-year earnings behavior.
- Side-by-side PB vs NG tests cover valid and invalid changes.

### Phase 4 - Timesheet Entry Commands

Deliverables:

- Timesheet detail and premium record pages.
- Commands for Add, Change, Delete, Recalculate, and Premium maintenance.
- Pay period validation, next item logic, daily subtotal behavior, WCB/GST/occupation/rate lookups, and protected paid/costed row rules.
- Import-readiness analysis for ISSL and field timesheet sources.

Acceptance:

- New timesheet default values match `n_bo_timesheet`.
- Recalculation matches PB totals for representative employees/jobs/unions.
- Paid or costed timesheets cannot be edited outside legacy-permitted actions.
- Timesheet premium validation matches PB.

### Phase 5 - Field Timesheet Review

Deliverables:

- Field timesheet list, detail, and document view.
- Batch review commands that update `field_timesheet` and child `timesheet` records in one .NET transaction.
- Status filtering and completed/in-progress behavior from PB.

Acceptance:

- Field timesheet processing produces the same child timesheets as Legacy.
- Partial failure rolls back the transaction.
- Review status and document visibility match PB.

### Phase 6 - Cheque Create, Approve, Entry, Issue

Deliverables:

- Cheque read model and tabs.
- Cheque command services for Create, Approve, Change, Reconcile, Void/Reverse, Issue, Reprint, and Paystub Email.
- Child update logic for timesheets, premiums, employee earnings, employee WCB, cheque queue, union, occupation, purchases, and company state.
- Formal report/print pathway for cheques and paystubs.

Acceptance:

- Gross/net, earnings, deductions, WCB, union, and premium totals reconcile with Legacy.
- Approved/issued/reversed/reconciled statuses transition only through permitted commands.
- Issuing cheques updates employee earnings and related child tables exactly once.
- Reprint does not duplicate issuing side effects.

### Phase 7 - Payroll Costing, Period Advance, Cleanup

Deliverables:

- `PRTRAN` command service to apply issued cheque costs to Job Cost and General Ledger.
- `PRMEND` command service to advance pay period and/or G/L period.
- `PRARCH` cleanup/archive command service.
- Pre-flight preview and reconciliation reports before destructive/closing actions.

Acceptance:

- Job Cost and General Ledger entries reconcile to PB output.
- Period advancement is blocked when required Payroll conditions are not satisfied.
- Cleanup/archive has preview, audit, and rollback strategy.

### Phase 8 - Payroll Reports And AI Help

Deliverables:

- Report migration for Employee Reports, Timesheet Reports, Cheque Reports, PD7A, union remittance, T4-related data, and operational reports.
- Contextual help from `LegacyTrainingMaterials.md` and Payroll source inventory.
- Optional right-side Payroll intelligence panel for warnings, missing setup, open timesheets, pending cheques, and period-close readiness.

Acceptance:

- Reports reconcile to PB output for selected periods/employees.
- AI/help content cites internal KB records and does not invent payroll rules.
- Suggestions are informational until backed by migrated validation/command logic.

## Implementation Rules

- Do not write directly from Angular forms to Payroll tables.
- Do not implement generic update endpoints for Payroll transaction tables.
- Keep each legacy action as a named command with its own validation and transaction boundary.
- Use .NET tests for validations, defaults, protected fields, command preconditions, side effects, and reconciliation totals.
- Keep Payroll commands behind permissions and feature flags until side-by-side validation is complete.
- Maintain audit/event logging for every Payroll write.
- Prefer read-only rollout first so users can validate navigation, layouts, lists, and field semantics before transactional risk is introduced.

## First Recommended Delivery Slice

The first practical slice should be read-only Payroll foundation:

1. Add `/payroll` landing route and route Payroll menu items to placeholder pages.
2. Add API read endpoints for Employees, Timesheets, Field Timesheets, Cheques, Pay Periods, and Setup lists.
3. Build AG Grid lists with all-field search and hyperlink navigation.
4. Build Employee record page with legacy tabs in read-only mode.
5. Build Timesheet and Cheque record pages in read-only mode.
6. Add a Payroll "not yet migrated" action banner for Add/Edit/Delete/Create/Issue/Post commands.
7. Add reconciliation checks comparing NG counts and key totals against Legacy/DataWindow SQL.

This gives users visible progress and lets us validate the module shape without risking payroll calculations or accounting postings.

## Open Questions

- Which Payroll workflow should be the first write-enabled pilot: Employee Change, Timesheet Add/Recalculate, or a safe setup table?
- Are cheque printing, EFT, paystubs email, T4/ROE, and PD7A outputs in scope for the first Payroll release or later Payroll release?
- Should Payroll remain unavailable unless the user has a dedicated Payroll role in Abio NG?
- Should `PRTRAN`, `PRMEND`, and `PRARCH` require a preview/approval step even if Legacy allows direct execution?

