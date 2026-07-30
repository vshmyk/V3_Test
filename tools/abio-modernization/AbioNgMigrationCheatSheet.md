# Abio NG Migration Cheat Sheet

## Target Shape

- Use Angular for browser UI.
- Use ASP.NET Core / .NET for middle-tier services, validations, commands, transactions, and integration logic.
- Use SQL Server `ABIO_DEMO` as the current system of record.
- Use AG Grid for list, inquiry, and tabular DataWindow replacement.
- Treat this as replatforming, not automatic PowerBuilder conversion.

## Source Of Truth

- Legacy source lives under `E:\Abio\Prg`.
- Exported PB source lives under `tools/abio-modernization/pb-exported-source`.
- Public/product context KB lives under `tools/abio-modernization/knowledge-base`.
- `ABIO_Summary.md` is the current project-state summary.
- Exact business behavior must come from PB source, DataWindow definitions, SQL schema, and database behavior, not from UI assumptions.

## UI Navigation Pattern

- Use the Job module pattern as the default for migrated modules.
- List screens open records in the same page, not a separate browser tab.
- Clickable identifiers should be blue links with normal font weight.
- Record view should replace the list view and include a close/back button returning to the list.
- Record pages should use a legacy-style title bar, tabs, action strip, scrollable body, and optional right-side context/safety panel.
- Keep list search as all-fields quick search.
- Avoid selected-row-driven detail panels unless specifically requested.

## Record Page Pattern

- Match the legacy visual DataWindow layout when recreating form pages.
- Use tabs with the same labels as Legacy, but without numeric prefixes.
- Use action buttons instead of the PB `action` field.
- Show unavailable or unmigrated actions as guarded commands, not hidden magic.
- Keep the top/title/actions/tabs area stable where practical; make the field body scrollable.
- Use checkboxes for Y/N fields while preserving `Y`/`N` values.
- Use date inputs/calendar controls for date fields in edit mode.
- Use searchable lookup controls for reference fields.
- Restrict lookup fields to valid values unless the legacy source explicitly allows free entry.

## AG Grid Pattern

- AG Grid is the default DataWindow list/table replacement.
- Use AG Grid for lists, child rows, inquiry tabs, and setup tables.
- Use hyperlink renderers for navigable identifiers.
- Use all-field search/quick filter for list screens.
- Keep formal printed/statutory reports separate from AG Grid; reports need their own migration path.

## .NET Middle-Tier Pattern

- Build middle-tier services before enabling API/UI writes.
- Prefer explicit services and command methods over direct table-update endpoints.
- Keep read models separate from write/command models.
- Write commands must own validation, defaults, side effects, transaction boundary, audit behavior, and reconciliation tests.
- Use named commands such as `ChangeEmployee`, `AddTimesheet`, `RecalculateTimesheet`, `ApproveCheque`, `IssueCheque`, `CostPayroll`.
- Do not expose generic `PUT table row` behavior for transactional modules.

## Command Safety Rules

- Payroll, GL, AP, AR, Job Cost, posting, cheque, period-close, and archive actions are high risk.
- Do not enable writes until the matching PB action/event/program-layer path is migrated.
- Guard unmigrated write actions with a structured response such as `blocked-pending-legacy-command-migration`.
- Guard responses should list required PB libraries/objects and migration steps.
- Always preserve transaction integrity and rollback behavior.
- Side effects across child tables must run in one .NET transaction.

## PowerBuilder Migration Rules

- Identify all PB objects involved before implementing a write workflow.
- Inspect windows (`.srw`), user objects (`.sru`), DataWindows (`.srd`), structures, global functions, and referenced child BOs.
- DataWindow update definitions identify table/column/key behavior but are not the whole business rule.
- Program-layer events such as action changes, itemchanged, preupdate, postupdate, apply/save, delete, and custom `ue_*` events must be migrated.
- Preserve defaults, validation rules, protected/calculated fields, lookup filtering, and child update behavior.
- When a PB object is missing from export, re-run targeted export before guessing.

## Lookup And Field Rules

- Lookup fields should show all valid options when opened.
- Lookup fields should support search like Salesforce-style lookup fields.
- Values should default to the current value in edit mode.
- Do not allow arbitrary `...(current value)` free-entry placeholders unless legacy allows it.
- Use valid-option restriction for reference fields.
- Use Y/N checkboxes for Boolean-like flags.
- Preserve stored database values exactly, even if UI control changes.

## Payroll-Specific Rules

- Payroll migration starts with middle-tier and read-only UI.
- Employee, Timesheet, Field Timesheet, Cheque, Setup, and Reports are separate but related flows.
- Payroll writes are command-layer only.
- Create Cheques, Approve Cheques, Issue/Reprint Cheques, Cost to J/C and G/L, Advance Pay Period, and Cleanup remain guarded until PB logic is migrated.
- Payroll record tabs should follow Legacy:
  - Employee: Details, Cheque & Dues, Incentive & Accrual, Premiums, Earnings, WCB.
  - Timesheet: Details, Premiums.
  - Field Timesheet: Details, Document.
  - Cheque: Gross & Net, Earn & Loss, Premiums, WCB, Union, Occupation.

## Job Module Pattern To Reuse

- Use same-page record navigation.
- Keep the record title large and close/back action on the right.
- Use modernized legacy-style tabs.
- Keep action buttons visually distinct from tabs.
- Use a right-side intelligence/context panel when useful.
- Remove unnecessary outer white panels when record content already has its own frame.

## AI / Knowledge Base Pattern

- Use website/training KB for vocabulary, contextual help, module explanations, and assistant grounding.
- Do not use KB content as authority for validations, posting, payroll calculations, or save behavior.
- AI suggestions should be informational unless backed by migrated command logic.
- Context panels may show facts, tips, watchlists, or suggested actions, but must not imply unimplemented automation is safe.

## Verification Pattern

- Build after code changes.
- For API work, run `dotnet build tools\abio-modernization\prototype\Abio.Api\Abio.Api.csproj --no-restore`.
- If `Abio.Api.exe` is locked, stop `Abio.Api`, rebuild, then restart.
- For Angular work, run `npm run build` in `tools/abio-modernization/prototype/Abio.Web`.
- Smoke-test new API endpoints against `ABIO_DEMO`.
- For migrated write commands, add side-by-side tests against Legacy behavior before enabling UI actions.

## Documentation Pattern

- Update `ABIO_Summary.md` when the project state changes.
- Add module-specific plans under `tools/abio-modernization`.
- Record which PB objects are authoritative for each migrated workflow.
- Document guarded/unmigrated actions clearly.
- Keep docs practical and implementation-oriented.

## Current Local URLs

- API: `http://localhost:5239`
- Angular app: `http://localhost:4200` or `http://127.0.0.1:4200`
- Core console: `/`
- Payroll console: `/payroll`
- Rhumbix pilot: `/rhumbix`

