# PowerBuilder Source Export Guide

## Purpose

The current Abio folder contains the compiled PowerBuilder libraries, but most source objects are still inside `.pbl` binaries. A full text export is needed before we can produce reliable counts for screens, DataWindows, reports, menus, user objects, embedded SQL, and migration risk.

## Current State

The generated inventory in [inventory/InventorySummary.md](inventory/InventorySummary.md) shows:

- 46 target libraries referenced by `E:\Abio\abio.pbt`;
- about 359 MB of referenced `.pbl` files;
- 31 object references visible in `.pbg` files;
- 6 exported text source files beside the PBLs;
- 3,562 likely object-name hints from a non-authoritative binary scan in [inventory-binary-hints/BinaryHintsSummary.md](inventory-binary-hints/BinaryHintsSummary.md);
- no local PowerBuilder command-line export tooling found on `PATH` or in the common Appeon/Sybase installation folders checked from this workspace.

That means the next export likely needs to be done from a machine with PowerBuilder or Appeon PowerBuilder installed.

## Preferred Export Output

Export all objects into a folder outside the production/runtime folder, for example:

```text
E:\AbioExportedSource
```

Keep the exported files grouped by library if the export tool supports it:

```text
E:\AbioExportedSource
  abio\
  dashboard\
  payroll\
  payables\
  reports_pr\
```

The expected file extensions are:

| Extension | PowerBuilder Object Type |
| --- | --- |
| `.sra` | application |
| `.srd` | DataWindow |
| `.srf` | function |
| `.srm` | menu |
| `.srs` | structure |
| `.sru` | user object |
| `.srw` | window |

## Export Options

### Option 1: PowerBuilder IDE

Use the PowerBuilder IDE on a machine that can open `E:\Abio\abio.pbw` or `E:\Abio\abio.pbt`.

Export requirements:

- export every object from every target library in `abio.pbt`;
- preserve original object names;
- preserve PowerBuilder source extensions;
- avoid editing or regenerating the application during export;
- export to a separate folder such as `E:\AbioExportedSource`.

This is the safest first path if the IDE is already available.

### Option 2: ORCA-Based Export

If the environment has PBORCA tooling or an existing internal export utility, use it to export all objects listed in the target library list from `E:\Abio\abio.pbt`.

The export should include:

- windows;
- DataWindows;
- menus;
- user objects;
- global functions;
- structures;
- application object;
- any project or resource metadata available as text.

## Rerun Inventory After Export

After the full export exists, rerun the inventory script against the exported source folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\abio-modernization\scripts\Inventory-AbioPowerBuilder.ps1 `
  -SourceRoot E:\Abio `
  -ExportedSourceRoot E:\AbioExportedSource `
  -TargetFile E:\Abio\abio.pbt `
  -OutputDir tools\abio-modernization\inventory-full
```

The script searches the exported source folder recursively, so it can handle either a flat export folder or a library-grouped folder structure.

## What The Full Inventory Should Answer

The full export should let us answer:

- how many windows exist per module;
- how many DataWindows are grids, reports, forms, and lookups;
- how many DataWindows are updateable;
- where embedded SQL exists;
- which screens contain business rules in UI events;
- which reports need formal report migration;
- where AG Grid is a strong fit;
- where Angular forms or dedicated reporting are better fits;
- which modules have the highest migration risk.

## Success Criteria

The export step is complete when:

- the exported folder contains `.sr*` files for every object in every `.pbl`;
- the inventory count is much larger than the current 6 exported text files;
- object counts can be grouped by module/library;
- DataWindow and window counts can be used to refine the migration plan.
