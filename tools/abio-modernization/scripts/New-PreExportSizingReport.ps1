param(
    [string]$LibraryCsv = "tools\abio-modernization\inventory\pbl-libraries.csv",
    [string]$BinaryHintsCsv = "tools\abio-modernization\inventory-binary-hints\pbl-binary-object-hints.csv",
    [string]$OutputDir = "tools\abio-modernization\pre-export-sizing"
)

$ErrorActionPreference = "Stop"

function Get-ModuleInfo {
    param([string]$Library)

    $name = $Library.ToLowerInvariant()

    if ($name -eq "dashboard.pbl" -or $name -eq "echarts_base.pbl") {
        return @{ Module = "Dashboard"; Wave = 2; Risk = "Low/Medium"; Notes = "Good fit for pilot and read-heavy AG Grid/chart patterns." }
    }
    if ($name -eq "administration_menu.pbl" -or $name -eq "abio.pbl") {
        return @{ Module = "Administration"; Wave = 3; Risk = "Low/Medium"; Notes = "Shell, menu, environment, configuration, and shared app behavior." }
    }
    if ($name -eq "project_management.pbl") {
        return @{ Module = "Project Management"; Wave = 4; Risk = "Medium"; Notes = "Operational workflows after platform patterns are proven." }
    }
    if ($name -eq "equipment.pbl" -or $name -eq "reports_eq.pbl") {
        return @{ Module = "Equipment"; Wave = 4; Risk = "Medium"; Notes = "Maintenance and operational grids." }
    }
    if ($name -eq "inventory.pbl") {
        return @{ Module = "Inventory"; Wave = 4; Risk = "Medium"; Notes = "Editable inventory workflows require transaction and audit handling." }
    }
    if ($name -eq "human_resources.pbl" -or $name -eq "reports_hr.pbl") {
        return @{ Module = "Human Resources"; Wave = 4; Risk = "Medium"; Notes = "Sensitive people data and role-based access." }
    }
    if ($name -eq "receivables.pbl" -or $name -eq "reports_ar.pbl") {
        return @{ Module = "Receivables"; Wave = 5; Risk = "Medium/High"; Notes = "Transactional AR, invoice, receipt, aging, and report reconciliation." }
    }
    if ($name -eq "payables.pbl" -or $name -eq "reports_ap.pbl") {
        return @{ Module = "Payables"; Wave = 5; Risk = "High"; Notes = "Payments, remittance, document handling, and controls." }
    }
    if ($name -eq "jobcost.pbl" -or $name -eq "reports_jc.pbl") {
        return @{ Module = "Job Cost"; Wave = 5; Risk = "High"; Notes = "Cross-module operational and financial behavior." }
    }
    if ($name -eq "payroll.pbl" -or $name -eq "reports_pr.pbl") {
        return @{ Module = "Payroll"; Wave = 5; Risk = "Very High"; Notes = "Critical payroll workflows, statutory outputs, and reconciliation." }
    }
    if ($name -eq "general_ledger.pbl" -or $name -eq "reports_gl.pbl") {
        return @{ Module = "General Ledger"; Wave = 5; Risk = "Very High"; Notes = "Posting, period close, financial integrity, and reconciliation." }
    }
    if ($name -like "reports*.pbl") {
        return @{ Module = "Reports"; Wave = 5; Risk = "High"; Notes = "Formal report migration track; validate reporting engine choice." }
    }
    if ($name -in @("shared_tables.pbl", "table.pbl", "framework.pbl")) {
        return @{ Module = "Shared Foundation"; Wave = 1; Risk = "High"; Notes = "Shared objects and table/DataWindow foundations used across modules." }
    }
    if ($name -like "pfc*.pbl" -or $name -like "pfd*.pbl" -or $name -like "pfe*.pbl" -or $name -eq "pfc_share.pbl" -or $name -eq "pfcapp.pbl") {
        return @{ Module = "PowerBuilder Framework"; Wave = 1; Risk = "Medium/High"; Notes = "PFC/PFE framework behavior to replace with Angular/.NET platform services." }
    }

    return @{ Module = "Other"; Wave = 4; Risk = "Medium"; Notes = "Needs classification after full source export." }
}

function Get-RiskWeight {
    param([string]$Risk)

    switch ($Risk) {
        "Low" { 1 }
        "Low/Medium" { 2 }
        "Medium" { 3 }
        "Medium/High" { 4 }
        "High" { 5 }
        "Very High" { 6 }
        default { 3 }
    }
}

if (-not (Test-Path $LibraryCsv)) {
    throw "LibraryCsv not found: $LibraryCsv"
}

if (-not (Test-Path $BinaryHintsCsv)) {
    throw "BinaryHintsCsv not found: $BinaryHintsCsv"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$libraries = Import-Csv $LibraryCsv
$hints = Import-Csv $BinaryHintsCsv

$rows = foreach ($library in $libraries) {
    $moduleInfo = Get-ModuleInfo $library.Library
    $libraryHints = @($hints | Where-Object { $_.Library -eq $library.Library })
    $typeCounts = @{}
    foreach ($group in ($libraryHints | Group-Object ObjectType)) {
        $typeCounts[$group.Name] = @($group.Group)
    }
    $objectCount = $libraryHints.Count
    $datawindowCount = if ($typeCounts.ContainsKey("datawindow")) { @($typeCounts["datawindow"]).Count } else { 0 }
    $windowCount = if ($typeCounts.ContainsKey("window")) { @($typeCounts["window"]).Count } else { 0 }
    $userObjectCount = if ($typeCounts.ContainsKey("userobject")) { @($typeCounts["userobject"]).Count } else { 0 }
    $functionCount = if ($typeCounts.ContainsKey("function")) { @($typeCounts["function"]).Count } else { 0 }
    $menuCount = if ($typeCounts.ContainsKey("menu")) { @($typeCounts["menu"]).Count } else { 0 }
    $structureCount = if ($typeCounts.ContainsKey("structure")) { @($typeCounts["structure"]).Count } else { 0 }
    $sizeMb = [double]$library.SizeMB
    $riskWeight = Get-RiskWeight $moduleInfo.Risk

    [pscustomobject]@{
        Module = $moduleInfo.Module
        Library = $library.Library
        Wave = $moduleInfo.Wave
        Risk = $moduleInfo.Risk
        SizeMB = $sizeMb
        ObjectHints = $objectCount
        DataWindows = $datawindowCount
        Windows = $windowCount
        UserObjects = $userObjectCount
        Functions = $functionCount
        Menus = $menuCount
        Structures = $structureCount
        PreExportComplexityScore = [math]::Round(($objectCount * 1.0) + ($datawindowCount * 0.4) + ($windowCount * 1.5) + ($userObjectCount * 0.8) + ($sizeMb * 2.0) + ($riskWeight * 25), 1)
        Notes = $moduleInfo.Notes
    }
}

$moduleRows = $rows |
    Group-Object Module |
    ForEach-Object {
        $items = @($_.Group)
        $risk = ($items | Sort-Object { Get-RiskWeight $_.Risk } -Descending | Select-Object -First 1).Risk
        $wave = ($items | Measure-Object -Property Wave -Minimum).Minimum

        [pscustomobject]@{
            Module = $_.Name
            Wave = $wave
            Risk = $risk
            Libraries = ($items | Measure-Object).Count
            SizeMB = [math]::Round((($items | Measure-Object -Property SizeMB -Sum).Sum), 2)
            ObjectHints = (($items | Measure-Object -Property ObjectHints -Sum).Sum)
            DataWindows = (($items | Measure-Object -Property DataWindows -Sum).Sum)
            Windows = (($items | Measure-Object -Property Windows -Sum).Sum)
            UserObjects = (($items | Measure-Object -Property UserObjects -Sum).Sum)
            Functions = (($items | Measure-Object -Property Functions -Sum).Sum)
            Menus = (($items | Measure-Object -Property Menus -Sum).Sum)
            Structures = (($items | Measure-Object -Property Structures -Sum).Sum)
            PreExportComplexityScore = [math]::Round((($items | Measure-Object -Property PreExportComplexityScore -Sum).Sum), 1)
        }
    } |
    Sort-Object PreExportComplexityScore -Descending

$rows | Sort-Object PreExportComplexityScore -Descending | Export-Csv -Path (Join-Path $OutputDir "library-sizing.csv") -NoTypeInformation
$moduleRows | Export-Csv -Path (Join-Path $OutputDir "module-sizing.csv") -NoTypeInformation

$moduleTable = $moduleRows | ForEach-Object {
    "| $($_.Module) | $($_.Wave) | $($_.Risk) | $($_.Libraries) | $($_.SizeMB) | $($_.ObjectHints) | $($_.DataWindows) | $($_.Windows) | $($_.PreExportComplexityScore) |"
}

$topLibraryRows = $rows |
    Sort-Object PreExportComplexityScore -Descending |
    Select-Object -First 20 |
    ForEach-Object {
        "| $($_.Library) | $($_.Module) | $($_.Risk) | $($_.SizeMB) | $($_.ObjectHints) | $($_.DataWindows) | $($_.Windows) | $($_.PreExportComplexityScore) |"
    }

$summary = @"
# Abio Pre-Export Migration Sizing

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')

## Important Caveat

This report is based on library metadata and the non-authoritative PBL binary object-name scan. It is useful for early prioritization and sizing conversations, but the full PowerBuilder source export remains required before final estimates.

## Module Sizing

| Module | Wave | Risk | Libraries | Size MB | Object Hints | DataWindows | Windows | Complexity Score |
| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
$($moduleTable -join "`r`n")

## Largest Library Hotspots

| Library | Module | Risk | Size MB | Object Hints | DataWindows | Windows | Complexity Score |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
$($topLibraryRows -join "`r`n")

## Reading The Score

The complexity score is a rough pre-export ranking. It combines object-name hint counts, DataWindow count, window count, user object count, PBL size, and known business risk. Higher values mean the area probably deserves more discovery and migration planning effort.

## Output Files

- module-sizing.csv
- library-sizing.csv
"@

$summary | Set-Content -Path (Join-Path $OutputDir "PreExportSizingSummary.md") -Encoding UTF8

Write-Host "Pre-export sizing report written to $OutputDir"
