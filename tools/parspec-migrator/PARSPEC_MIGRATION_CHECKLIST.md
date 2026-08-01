# Parspec Migration Checklist

Working migration checklist for the Centera -> Parspec project, based on:

- Parspec API Guide for Centera, last updated July 27, 2026
- Parspec public schema and live runtime behavior validated through July 31, 2026
- current MACSII/Oasis business-layer mappings in `PARSPEC_MACSII`

## Current understanding

- Every Oasis `Bid` should migrate to a Parspec `BOM`.
- Only bids that were actually quoted should also migrate to a Parspec `Quote` once Quote APIs are released.
- Pre-bid bids remain `BOM` only.
- The stable hierarchy is:
  - `Location`
  - `Manufacturer`
  - `Product`
  - `Company`
  - `Contact`
  - `Project`
  - `Opportunity`
  - `BOM`
  - `Quote` (conditional, API pending)
  - `BOM lines` (API pending)

## Phase 1: Ready Now

These areas are supported by the currently published Parspec partner API and can be implemented now.

### Foundation and rules

- Use `v2` endpoints by default.
- Send camelCase JSON field names only.
- Treat unknown field names as unsafe because Parspec silently ignores them.
- Validate every create/update with a follow-up `GET`.
- Keep sandbox and production base URLs configurable.
- Keep all external IDs stable and deterministic.

### Locations

- Confirm final branch/workgroup to Parspec location mapping.
- Keep `LocationMappings` current in [appsettings.json](/abs/path/C:/Users/vshmyk/AOprojects/AOtransact/tools/parspec-migrator/appsettings.json).
- Re-run `locations-scan` when new tenants or branches are added.

### Manufacturers

- Load all active source manufacturers into Parspec.
- Preserve:
  - `name`
  - `erpId`
  - `website`
  - visibility defaults
  - abbreviations
- Prepare for future roles/relationships if needed by the customer.

### Products

- Define the source of truth for product master records.
- Decide whether `src.QuoteItem.PartNumber` is sufficient for first-pass product seeding or whether a broader raw-product source is required.
- Map:
  - `manufacturerErpId`
  - `productErpId`
  - `modelNumber`
  - `description`
  - `unitCostAmount`
  - `unitSellPriceAmount`
- Use deterministic ERP IDs before product loading starts.

### Companies

- Continue using `src.Account` as the main source.
- Keep customer and manufacturer migration flows separate even though the business layer shares storage.
- Preserve:
  - `erpId`
  - `name`
  - `businessType`
  - `crmId`
  - `outsideSalesAgent`
  - email/phone/website
  - notes
  - address

### Contacts

- Continue using `src.Contact` plus raw Oasis contact fallback where needed.
- Preserve:
  - owning company
  - `crmId`
  - names
  - email
  - phone
  - job title
  - notes
  - address

### Projects

- Continue using `src.Project`.
- Preserve:
  - `erpId`
  - `crmId`
  - `name`
  - `location`
  - `marketVertical`
  - `constructionScope` if later sourced
  - `squareFootage`
  - `owner`
  - `projectStakeholders`
- Respect Parspec stakeholder cap of 10.

### Opportunities

- Continue using `src.Bid` for opportunity/header-level fields.
- Preserve:
  - `crmId`
  - `title`
  - `stage`
  - `priority`
  - `estimatedValue`
  - `quoteDueDate`
  - `submittalDueDate`
  - `quoter`
  - `pm`
- Remember:
  - opportunities have no `erpId`
  - opportunities cannot be deleted via public API

### BOM headers

- Continue creating one Parspec BOM per Oasis bid.
- Use source bid/project context to resolve:
  - `crmId`
  - `name`
  - `salesAgent`
  - primary customer
  - secondary customer
- Keep the distributor-only customer fix in place:
  - customer companies must resolve only through accounts with `src.Account.Role = 'Distributor'`

## Phase 2: Prepared, Waiting on Parspec API

These areas are source-ready on our side, but the public write API is not yet published in the materials we validated.

### Quote headers

- Source: `src.Bid`
- Planned rule:
  - create Quotes only for bids that were actually quoted
  - do not create Quotes for pre-bid-only records
- Tasks ready now:
  - finalize quoted vs pre-bid classifier
  - prepare deterministic payload builder
  - prepare small-batch test cases

### BOM lines

- Source: `src.QuoteItem`
- Current readiness from `bom-lines-scan` on July 31, 2026:
  - total candidates: `598,434`
  - resolved base fields: `11/13`
  - unresolved: `productErpId`, public write endpoint
- First-pass contract already prepared for:
  - `bom`
  - `erpLineId`
  - `modelNumber`
  - `description`
  - `manufacturerErpId`
  - `quantity`
  - `unitSellPriceAmount`
  - `extendedSellPriceAmount`
  - `pricingPer`
  - `sellingUom`
  - `type`

### Quote lines

- Likely source: `src.QuoteItem`
- Wait for final Parspec Quote API before implementing write logic.
- Reuse BOM-line contract where schemas overlap.

## Open Decisions

These decisions should be made before full production migration.

### Bid classifier

- Define exact rule for:
  - `BOM only`
  - `BOM + Quote`
- Likely inputs:
  - `src.Bid.BidStatus`
  - possible quote-sent / awarded / won-lost indicators
  - any business-layer derived status already present

### Product key strategy

- Decide what becomes Parspec `productErpId`.
- Candidates may include:
  - existing Oasis product identifiers
  - part number-based composite keys
  - manufacturer + part number composite strategy

### Pricing policy

- Confirm how Oasis price levels map into future Parspec line APIs:
  - `Sell`
  - `Base`
  - `OBase`
  - `Level1`
  - `Level2`
  - `Level3`
- Confirm whether only sell-side pricing is required in Phase 1.

### BOM grouping policy

- Decide how to represent:
  - blank structural rows
  - grouped/rolled-up rows
  - sections
  - lots
- Some `src.QuoteItem` rows are commercial lines; some appear structural.

### Cleanup policy

- Public API deletion is limited:
  - BOM deletion was not available on the live public endpoints we tested on July 31, 2026
  - opportunities are not deletable through public API
- Define sandbox reset strategy with Parspec team before heavy test loading.

## What to Build Next

Recommended immediate work order:

1. Add a bid classifier for `BOM only` vs `BOM + Quote`.
2. Freeze source-side Quote header mapping from `src.Bid`.
3. Freeze source-side Quote/BOM line payload models from `src.QuoteItem`.
4. Prepare small deterministic test batches:
   - pre-bid only
   - quoted but not won
   - won
   - lost/no-bid
5. Once Parspec releases Quote/BOM-line APIs, map our prepared payload builders to the published request schema and validate in sandbox.

## Commands Already Available

- `dotnet run -- locations-scan`
- `dotnet run -- companies-scan`
- `dotnet run -- contacts-scan`
- `dotnet run -- manufacturers-scan`
- `dotnet run -- projects-scan`
- `dotnet run -- opportunities-scan`
- `dotnet run -- boms-scan`
- `dotnet run -- bom-lines-scan`

## Current Practical Summary

- We can confidently keep building the migration backbone now.
- We should not block on Quote/BOM-line APIs for source-side design.
- The next release from Parspec should plug into a migration flow that is already source-classified, payload-shaped, and test-batched.
