# Parspec Emulator

Local ASP.NET site that:

- reads the mapping workbook at `E:\Parspec\OasisFields __ Parspec Mapping_vShare - Copy.xlsm`
- queries live Oasis rows from `OASIS_MACSII` on `.\ERPLINK`
- projects Oasis rows into destination-side Parspec objects and fields
- lets you inspect populated destination records in a browser

## Run

```powershell
cd tools\parspec-emulator
dotnet run
```

Default launch profile URL:

- `http://localhost:5037`

If you want a fixed URL:

```powershell
dotnet run --urls http://127.0.0.1:5099
```

## Current behavior

- Home page lists destination Parspec objects inferred from the workbook.
- Each object page can switch between contributing Oasis source tables.
- The main grid shows destination columns only, with one row per Oasis source record.
- Column headers and cells are color-coded as:
  - `Direct`
  - `Derived`
  - `Missing on source row`
  - `Cannot currently populate`
- The current derivation layer is intentionally lightweight and meant for inspection, not final migration execution.

## Notes

- This is an inspection emulator, not a full migration engine.
- It uses workbook field definitions directly, so workbook updates are reflected after restart.
- It is designed to answer: “What would the destination Parspec object look like if we populated it from Oasis right now?”
