param(
    [string]$SourceRoot = "E:\Abio",
    [string]$TargetFile = "E:\Abio\abio.pbt",
    [string]$OutputDir = "tools\abio-modernization\inventory-binary-hints"
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

if (-not (Test-Path $SourceRoot)) {
    throw "SourceRoot not found: $SourceRoot"
}

if (-not (Test-Path $TargetFile)) {
    throw "TargetFile not found: $TargetFile"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$targetText = Get-Content -Path $TargetFile -Raw
$libListMatch = [regex]::Match($targetText, 'LibList\s+"([^"]+)"')
$targetLibraries = @()

if ($libListMatch.Success) {
    $targetLibraries = $libListMatch.Groups[1].Value.Split(";") | Where-Object { $_.Trim() -ne "" }
}

$objectPattern = '(?i)(?:^|[^a-z0-9_])((?:a|d|f|m|n|p|s|u|w)_[a-z0-9_]+\.(?:sra|srd|srf|srm|srs|sru|srw))'
$hintRows = New-Object System.Collections.Generic.List[object]

foreach ($libraryName in $targetLibraries) {
    $libraryPath = Join-Path $SourceRoot $libraryName
    $item = Get-Item -LiteralPath $libraryPath -ErrorAction SilentlyContinue

    if (-not $item) {
        continue
    }

    $bytes = [IO.File]::ReadAllBytes($item.FullName)
    $unicodeText = [Text.Encoding]::Unicode.GetString($bytes)
    $matches = [regex]::Matches($unicodeText, $objectPattern)
    $uniqueObjects = $matches | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Sort-Object -Unique

    foreach ($objectName in $uniqueObjects) {
        $extension = [System.IO.Path]::GetExtension($objectName)

        $hintRows.Add([pscustomobject]@{
            Library = $libraryName
            Object = $objectName
            Extension = $extension.ToLowerInvariant()
            ObjectType = Get-ObjectType $extension
            Source = "PBL Unicode string scan"
        })
    }
}

$hintRows | Export-Csv -Path (Join-Path $OutputDir "pbl-binary-object-hints.csv") -NoTypeInformation

$librarySummary = $hintRows |
    Group-Object Library |
    Sort-Object Count -Descending |
    ForEach-Object {
        "| $($_.Name) | $($_.Count) |"
    }

if (-not $librarySummary) {
    $librarySummary = @("| None | 0 |")
}

$typeSummary = $hintRows |
    Group-Object ObjectType |
    Sort-Object Count -Descending |
    ForEach-Object {
        "| $($_.Name) | $($_.Count) |"
    }

if (-not $typeSummary) {
    $typeSummary = @("| None | 0 |")
}

$summary = @"
# Abio PBL Binary Object Hints

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss K")

Source root: $SourceRoot

Target file: $TargetFile

## Important Caveat

This is a heuristic inventory. It scans PBL binaries for Unicode strings that look like exported PowerBuilder object names. It can find useful object-name hints before a full source export, but it is not a replacement for a real PowerBuilder export.

## Summary

| Metric | Value |
| --- | ---: |
| Target libraries scanned | $($targetLibraries.Count) |
| Object name hints found | $($hintRows.Count) |

## Object Hints By Type

| Object Type | Count |
| --- | ---: |
$($typeSummary -join "`r`n")

## Object Hints By Library

| Library | Object Hints |
| --- | ---: |
$($librarySummary -join "`r`n")

## Output Files

- `pbl-binary-object-hints.csv`

## Recommended Use

Use this output to refine early risk and sizing conversations while waiting for full source export. Use exported `.sr*` source files as the authoritative inventory once they are available.
"@

$summary | Set-Content -Path (Join-Path $OutputDir "BinaryHintsSummary.md") -Encoding UTF8

Write-Host "Binary hint inventory written to $OutputDir"
