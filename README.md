# Parspec Migration Project

Standalone repository for the Oasis/MACSII to Parspec migration work.

## Scope

This repo contains the Parspec-focused project assets only:

- `tools/parspec-migrator`
- `tools/parspec-bootstrap`
- `tools/parspec-emulator`
- `SUMMARY.md`

It intentionally excludes unrelated `AOtransact` workstreams such as `transactions-loader`, `integramaster-v3`, and `offline-log`.

## Current migration model

- Every Oasis `Bid` should migrate to a Parspec `BOM`.
- Only bids that were actually quoted should later migrate to a Parspec `Quote` when the public Quote APIs are ready.
- Pre-bid records remain `BOM` only.
- `PARSPEC_MACSII.src.*` is the primary source.
- Raw `OASIS_*` data is used only to fill business-layer gaps.

## Main folders

- `tools/parspec-migrator`: object-by-object API migration harness
- `tools/parspec-bootstrap`: SQL/bootstrap tooling for standing up `PARSPEC_[ORG_NAME]` databases
- `tools/parspec-emulator`: local inspection UI for workbook/API mapping review

## Start here

1. Read `SUMMARY.md`.
2. Read `tools/parspec-migrator/PARSPEC_MIGRATION_CHECKLIST.md`.
3. Use the migrator for live object-by-object loading.
4. Use the emulator when you need field-level inspection against workbook/source data.
