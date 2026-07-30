param(
    [string]$SourceRoot = "E:\Abio",
    [string]$ExportedSourceRoot = "",
    [string]$TargetFile = "E:\Abio\abio.pbt",
    [string]$OutputDir = "tools\abio-modernization\inventory"
)

$ErrorActionPreference = "Stop"

function Get-ObjectType {
    param([string]$Extension)

    switch ($Extension.ToLowerInvariant()) {
        ".sra" { "application" }
        ".srd" { "datawindow" }
        ".srf" { "function" }
        ".srm" { "menu" }
        ".srs" { "structure" }
        ".sru" { "userobject" }
        ".srw" { "window" }
        default { if ($Extension) { $Extension.TrimStart(".") } else { "unknown" } }
    }
}

function Get-FilePatternCount {
    param(
        [string]$Path,
        [string]$Pattern
    )

    $matches = Select-String -Path $Path -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue
    if (-not $matches) {
        return 0
    }

    return ($matches | ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
}

if (-not (Test-Path $SourceRoot)) {
    throw "SourceRoot not found: $SourceRoot"
}

if (-not (Test-Path $TargetFile)) {
    throw "TargetFile not found: $TargetFile"
}

if ([string]::IsNullOrWhiteSpace($ExportedSourceRoot)) {
    $ExportedSourceRoot = $SourceRoot
}

if (-not (Test-Path $ExportedSourceRoot)) {
    throw "ExportedSourceRoot not found: $ExportedSourceRoot"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$targetText = Get-Content -Path $TargetFile -Raw
$libListMatch = [regex]::Match($targetText, 'LibList\s+"([^"]+)"')
$targetLibraries = @()

if ($libListMatch.Success) {
    $targetLibraries = $libListMatch.Groups[1].Value.Split(";") | Where-Object { $_.Trim() -ne "" }
}

$pblRows = foreach ($libraryName in $targetLibraries) {
    $libraryPath = Join-Path $SourceRoot $libraryName
    $item = Get-Item -LiteralPath $libraryPath -ErrorAction SilentlyContinue

    [pscustomobject]@{
        Library = $libraryName
        Path = $libraryPath
        Exists = [bool]$item
        SizeBytes = if ($item) { $item.Length } else { $null }
        SizeMB = if ($item) { [math]::Round($item.Length / 1MB, 2) } else { $null }
        LastWriteTime = if ($item) { $item.LastWriteTime.ToString("s") } else { $null }
    }
}

$pbgRows = foreach ($pbg in Get-ChildItem -Path $SourceRoot -Filter *.pbg -File) {
    $text = Get-Content -Path $pbg.FullName -Raw
    $matches = [regex]::Matches($text, '"([^"]+)"\s+"([^"]+)";')

    foreach ($match in $matches) {
        $objectName = $match.Groups[1].Value
        $libraryName = $match.Groups[2].Value
        $extension = [System.IO.Path]::GetExtension($objectName)

        [pscustomobject]@{
            Pbg = $pbg.Name
            Library = $libraryName
            Object = $objectName
            Extension = $extension.ToLowerInvariant()
            ObjectType = Get-ObjectType $extension
        }
    }
}

$sourceExtensions = @("*.sra", "*.srd", "*.srf", "*.srm", "*.srs", "*.sru", "*.srw")
$exportedFiles = foreach ($pattern in $sourceExtensions) {
    Get-ChildItem -Path $ExportedSourceRoot -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue
}

$sourceRows = foreach ($file in $exportedFiles) {
    $extension = $file.Extension.ToLowerInvariant()

    [pscustomobject]@{
        File = $file.Name
        Path = $file.FullName
        Extension = $extension
        ObjectType = Get-ObjectType $extension
        SizeBytes = $file.Length
        LastWriteTime = $file.LastWriteTime.ToString("s")
        HasPbExportHeader = (Get-FilePatternCount -Path $file.FullName -Pattern '\$PBExportHeader\$') -gt 0
        SqlStatementCount = Get-FilePatternCount -Path $file.FullName -Pattern '\b(SELECT|INSERT|UPDATE|DELETE|DECLARE|PREPARE|OPEN\s+DYNAMIC|COMMIT|ROLLBACK)\b'
        DataWindowCount = Get-FilePatternCount -Path $file.FullName -Pattern '\bdatawindow\('
        RetrieveCount = Get-FilePatternCount -Path $file.FullName -Pattern '\bretrieve\s*='
        MessageBoxCount = Get-FilePatternCount -Path $file.FullName -Pattern '\bMessageBox\s*\('
    }
}

$pblRows | Export-Csv -Path (Join-Path $OutputDir "pbl-libraries.csv") -NoTypeInformation
$pbgRows | Export-Csv -Path (Join-Path $OutputDir "pbg-object-refs.csv") -NoTypeInformation
$sourceRows | Export-Csv -Path (Join-Path $OutputDir "exported-source-files.csv") -NoTypeInformation

$libraryCount = @($pblRows).Count
$librarySizeMb = [math]::Round((($pblRows | Measure-Object -Property SizeBytes -Sum).Sum) / 1MB, 2)
$pbgObjectCount = @($pbgRows).Count
$exportedSourceCount = @($sourceRows).Count

$objectTypeSummary = @($pbgRows | Group-Object ObjectType | Sort-Object Count -Descending | ForEach-Object {
    "| $($_.Name) | $($_.Count) |"
})

if ($objectTypeSummary.Count -eq 0) {
    $objectTypeSummary = @("| None | 0 |")
}

$exportedTypeSummary = @($sourceRows | Group-Object ObjectType | Sort-Object Count -Descending | ForEach-Object {
    "| $($_.Name) | $($_.Count) |"
})

if ($exportedTypeSummary.Count -eq 0) {
    $exportedTypeSummary = @("| None | 0 |")
}

$topLibraries = @($pblRows | Sort-Object SizeBytes -Descending | Select-Object -First 12 | ForEach-Object {
    "| $($_.Library) | $($_.SizeMB) | $($_.LastWriteTime) |"
})

$summary = @"
# Abio PowerBuilder Inventory

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss K")

Source root: $SourceRoot

Exported source root: $ExportedSourceRoot

Target file: $TargetFile

## Summary

| Metric | Value |
| --- | ---: |
| Target libraries in abio.pbt | $libraryCount |
| Total target library size | $librarySizeMb MB |
| Object references visible in `.pbg` files | $pbgObjectCount |
| Exported text source files found beside PBLs | $exportedSourceCount |

## PBG Object References By Type

| Object Type | Count |
| --- | ---: |
$($objectTypeSummary -join "`r`n")

## Exported Text Source Files By Type

| Object Type | Count |
| --- | ---: |
$($exportedTypeSummary -join "`r`n")

## Largest Target Libraries

| Library | Size MB | Last Write Time |
| --- | ---: | --- |
$($topLibraries -join "`r`n")

## Output Files

- `pbl-libraries.csv`
- `pbg-object-refs.csv`
- `exported-source-files.csv`

## Notes

Only `dashboard.pbg` currently exposes object references. Most `.pbg` files are empty placeholders, and most source still appears to be inside `.pbl` binaries. A full PowerBuilder export is still required for a reliable screen and DataWindow inventory.
"@

$summary | Set-Content -Path (Join-Path $OutputDir "InventorySummary.md") -Encoding UTF8

Write-Host "Inventory written to $OutputDir"
