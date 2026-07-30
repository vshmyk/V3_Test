# PowerBuilder Source Exporter

This is a small ORCA-based utility for exporting focused Abio PowerBuilder source objects from PBL files.

## Intended Use

Export Job Entry legacy objects from:

```text
E:\Abio\Prg\jobcost.pbl
```

to:

```text
tools\abio-modernization\pb-exported-source\jobcost.pbl.src
```

## Command

Run from the repository root:

```powershell
dotnet publish tools\abio-modernization\pb-source-exporter\PbSourceExporter.csproj -c Debug -r win-x86 --self-contained false

$env:PATH = 'E:\Abio\PowerBuilderUtilities 25.0;' + $env:PATH
& 'C:\Program Files (x86)\dotnet\dotnet.exe' `
  'tools\abio-modernization\pb-source-exporter\bin\Debug\net9.0\win-x86\publish\PbSourceExporter.dll' `
  'E:\Abio\PowerBuilderUtilities 25.0' `
  'E:\Abio\Prg' `
  'C:\Users\vshmyk\AOprojects\AOtransact\tools\abio-modernization\pb-exported-source\jobcost.pbl.src' `
  'jobcost.pbl'
```

## Current Blocker

`E:\Abio\PowerBuilderUtilities 25.0\pborc.dll` is 32-bit and depends on:

```text
PBVM.dll
PBSHR.dll
```

Those DLLs are not currently present in the PB utilities folder or the checked Abio folders. `pbautobuild250.exe` fails with the same missing `PBORC.DLL` load error, so the PowerBuilder 25 32-bit runtime must be installed or copied into the utility path before export can proceed.
