# Parspec Migration Summary

Last updated: 2026-08-17 UTC

## Purpose

This repository contains the Oasis/MACSII to Parspec migration project only.

The current implementation is organized around three workstreams:

- `tools/parspec-migrator`
- `tools/parspec-bootstrap`
- `tools/parspec-emulator`

## Environment

- primary business-layer source: `PARSPEC_MACSII`
- inherited logic baseline: `MACSII_V2`
- raw Oasis fallback: `OASIS_MACSII`
- SQL Server: local `ERPLINK` instance
- active Parspec development target: `https://sandbox-app.parspec.io/`
- active sandbox API base: `https://platform-sandbox.parspec.io/platform-api/api/`

## Migration rules

- Every Oasis `Bid` should become a Parspec `BOM`.
- Only bids that were actually quoted should later become Parspec `Quote` records.
- Pre-bid records remain `BOM` only.
- Use `src.*` business-layer objects first.
- Use raw `oasis.*` tables only when the business layer does not expose enough information.

## Target object sequence

- `Location`
- `Manufacturer`
- `Product`
- `Company`
- `Contact`
- `Project`
- `Opportunity`
- `BOM`
- `Quote` when public create APIs are available
- `BOM line` when public write APIs are available

## API findings

- Validated working guide: Centera Phase 1 ingestion guide, updated `2026-07-27`
- Use `v2` endpoints by default
- Unknown JSON fields are silently ignored
- Every create/update should be validated with a follow-up `GET`
- Users cannot currently be created through the public API
- Opportunities have no `erpId`
- Opportunities cannot be deleted through the public API
- BOM support is currently header-level in the validated public materials
- BOM-line and Quote-line public write APIs were not available in the validated partner materials
- Purchase Orders, Sales Orders, Quotes, and their lines are read-only in the current public sandbox API
- Customer and vendor invoice writes are supported, but require existing Sales Order and Purchase Order parents respectively
- Product Master and inventory support ERP-ID-based batch upsert/delete operations

## Object status

- `Users`: scan/match/patch flow built
- `Companies`: bulk create flow built and used
- `Contacts`: bulk create flow built and used
- `Manufacturers`: load flow built
- `Projects`: mapping advanced, including stakeholder and square-footage work
- `Opportunities`: create flow built
- `BOM headers`: create flow built with distributor-only customer filtering
- `Quote headers`: source mapping prepared, awaiting final public write path
- `BOM lines`: source scan and payload contract prepared, awaiting public write path
- `Purchase Orders`: source scan/readiness work implemented, public write path not yet established
- `Vendor invoices`: source procedure implemented and validated in `PARSPEC_MACSII`; destination writes await migrated Purchase Order parents

## Source counts observed in the MACSII working set

- customers: about `2,670`
- contacts: about `4,791`
- manufacturers: about `183`
- projects: about `21,224`
- BOMs: about `31,719`
- quotes/bids: about `54,307`
- BOM lines: about `598,434`
- purchase orders: about `33,973`
- canonical ordered purchase order lines: about `139,166`

## Cross-agency sizing guidance

- customers: about `2,700`
- contacts: about `5,000`
- manufacturers: about `200`
- projects: about `22,000`
- BOMs: about `35,000`
- BOM lines: about `1,000,000`
- quotes: about `55,000`
- files: about `620,000` / `250 GB`
- largest file: up to about `3 GB`

## Important mapping decisions already made

- `Companies` source: `src.Account`
- `Contacts` source: `src.Contact` with raw Oasis fallback when needed
- `Manufacturers` source: `src.Account`
- `Projects` source: `src.Project`
- `Opportunities` source: `src.Bid`
- `BOM headers` source: `src.QuoteItem` grouped by bid/quote context
- `BOM lines` source: `src.QuoteItem`
- `PurchaseOrder` source: `src.PurchaseOrder`
- `PurchaseOrderItem` source: `src.PurchaseOrderItem`
- `EstimatedValue = Project.Valuation`
- `TotalQuoted = Project.Sell`
- `projectStakeholders` should come from `ProjectAccount` tied to the last active Oasis bid

## Purchase Order readiness

- Stable PO ERP IDs use the form `DBID:PO:<PurchaseOrderId>`.
- Canonical PO lines include only `TransactionType = 'O'`; release and shipment rows are excluded.
- Unit cost uses positive `BuyPrice`, with `NetPrice` as fallback.
- Extended cost is unit cost multiplied by ordered quantity.
- A ready-only 20-PO / 40-line Oasis test package was generated successfully.
- No PO data was sent because the current Parspec API exposes Purchase Orders as read-only.

## Verified Oasis sandbox test

On `2026-08-17`, a dependency-complete set of real Oasis records was migrated and verified by follow-up API reads:

- company `WES` / WESCO (Burnaby)
- contact `MACSBCCA001:97711` / Dakota Frego
- manufacturer `A-LINE` / A-LINE LIGHTING
- project `MACSBCCA001113467113468` / WHITE SPOT @ IDAF
- opportunity for Oasis quote `81799`
- BOM header for Oasis quote `81799`

The project stakeholder and BOM primary contact both resolved to the migrated WESCO company/contact relationship. The source BOM has 26 lines, but those lines were not sent because no BOM-line write endpoint is currently available.

API keys are supplied through `PARSPEC_API_KEY` and must not be committed.

## Important mapping clarifications

- `squareFootage` should be exposed through the business layer from raw project / bid-package data
- `submittalDueDate` can use `CHSC_QUOTE.EXPIRATIONDATE` for Quote-header planning
- `stage` should correspond to `src.Bid.BidStatus`
- BOM customer associations must resolve to distributors only
- `primaryCustomer` and `secondaryCustomer` are distributor companies
- `primaryContact` and `secondaryContact` are customer-side contacts, not internal Parspec users
- `CHSC_QUOTEDISTRIBUTORCONTACT` is the likely source for quote-side external contacts
- `Awarded By` should not be mapped to winning distributor unless Parspec confirms that semantic meaning

## Repository files to open first

1. `SUMMARY.md`
2. `tools/parspec-migrator/PARSPEC_MIGRATION_CHECKLIST.md`
3. `tools/parspec-migrator/README.md`
4. `tools/parspec-migrator/Program.cs`
5. `tools/parspec-bootstrap/README.md`
6. `tools/parspec-emulator/README.md`
7. `tools/parspec-bootstrap/PARSPEC_MACSII.VendorInvoiceOrigin.20260810.sql`

## Immediate next steps

1. Continue object-by-object migration from Projects/Opportunities/BOM into the Quote/BOM-line area.
2. Keep source-side payload modeling moving even before Parspec publishes final Quote/BOM-line write APIs.
3. Keep `PARSPEC_[ORG_NAME]` bootstrap logic reusable for future client tenants.
