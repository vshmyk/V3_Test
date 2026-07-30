# AOtransact.Sae

New project scaffold for extracting transaction-style events from Sybase ASE / SAE text logs.

## Goal

Produce two outputs that mirror the SQL Server workflow closely enough to reuse downstream ideas:

- `manifest.json`: structured committed DML events
- `.trn`: replay-friendly SQL script when the source log contains SQL text

This first cut is intentionally format-agnostic:

- input parsing is driven by regex rules in `sae.config.sample.json`
- no SQL Server `fn_dblog` assumptions
- no binary log decoding yet

## Build

```powershell
dotnet build .\AOtransact.Sae\AOtransact.Sae.csproj
```

## Run

```powershell
dotnet run --project .\AOtransact.Sae\AOtransact.Sae.csproj -- `
  --config .\AOtransact.Sae\sae.config.sample.json `
  --input .\AOtransact.Sae\sample-data\sae.log `
  --manifest-output .\output\sae.manifest.json `
  --trn-output .\output\sae.trn
```

## Expected log shape

The sample config assumes lines like:

```text
2026-03-28 12:34:56.789 spid=17 tx=000123 op=UPDATE table=oasis.CHSC_QUOTELINE sql=update oasis.CHSC_QUOTELINE set qty=2 where quoteid=10
```

If the real SAE log uses a different format, update the regex rules rather than changing code first.

## Next step

Once we have a real SAE sample, we should replace or supplement the regex adapter with a dedicated parser for that exact format.
