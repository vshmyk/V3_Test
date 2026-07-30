param(
    [string] $Server = ".\ERPLINK",
    [string] $Database = "ABIO_DEMO",
    [string] $OutputDirectory = (Join-Path $PSScriptRoot "..\knowledge-base")
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Data

function Invoke-AbioQuery {
    param(
        [string] $ConnectionString,
        [string] $Sql
    )

    $connection = [System.Data.SqlClient.SqlConnection]::new($ConnectionString)
    $command = $connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = 120

    $table = [System.Data.DataTable]::new()
    $adapter = [System.Data.SqlClient.SqlDataAdapter]::new($command)

    try {
        [void] $adapter.Fill($table)
    }
    finally {
        $adapter.Dispose()
        $command.Dispose()
        $connection.Dispose()
    }

    return ,$table
}

function Convert-TableToObjects {
    param([System.Data.DataTable] $Table)

    $rows = @()
    foreach ($row in $Table.Rows) {
        $item = [ordered] @{}
        foreach ($column in $Table.Columns) {
            $value = $row[$column.ColumnName]
            if ($value -is [System.DBNull]) {
                $value = $null
            }
            elseif ($value -is [string]) {
                $value = $value.Trim()
            }

            $item[$column.ColumnName] = $value
        }
        $rows += [pscustomobject] $item
    }

    return $rows
}

function Get-ModuleName {
    param([string] $Menu1, [string] $Program)

    switch ($Menu1) {
        "a" { return "Accounts Payable" }
        "b" { return "Accounts Receivable" }
        "c" { return "Payroll" }
        "d" { return "General Ledger" }
        "e" { return "Job Costing" }
        "f" { return "Human Resources" }
        "g" { return "Equipment" }
        "h" { return "Project Management" }
        "i" { return "Inventory" }
        "j" { return "Shared Reports" }
        "k" { return "Administration" }
    }

    switch -Regex ($Program) {
        "^AP" { return "Accounts Payable" }
        "^AR" { return "Accounts Receivable" }
        "^PR" { return "Payroll" }
        "^GL" { return "General Ledger" }
        "^JC" { return "Job Costing" }
        "^HR" { return "Human Resources" }
        "^EQ" { return "Equipment" }
        "^PM" { return "Project Management" }
        "^NV" { return "Inventory" }
        "^SR|^DR|^UT" { return "Shared Reports" }
        "^AM" { return "Administration" }
        default { return "Global" }
    }
}

$connectionString = "Server=$Server;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;"
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$menuSql = @"
SELECT
    program,
    description,
    menu_1,
    menu_2,
    menu_3,
    prompt,
    profile,
    active_flag,
    item_type,
    CAST(help AS varchar(max)) AS help,
    microhelp,
    help_url,
    window_name
FROM dbo.abio_menu
WHERE NULLIF(LTRIM(RTRIM(CAST(help AS varchar(max)))),'') IS NOT NULL
   OR NULLIF(LTRIM(RTRIM(microhelp)),'') IS NOT NULL
   OR NULLIF(LTRIM(RTRIM(help_url)),'') IS NOT NULL
ORDER BY menu_1, menu_2, menu_3, program;
"@

$reportSql = @"
SELECT
    program,
    report,
    name,
    active_flag,
    control_flag,
    datawindow_name,
    description,
    microhelp,
    help_url
FROM dbo.program_report
WHERE NULLIF(LTRIM(RTRIM(description)),'') IS NOT NULL
   OR NULLIF(LTRIM(RTRIM(microhelp)),'') IS NOT NULL
   OR NULLIF(LTRIM(RTRIM(help_url)),'') IS NOT NULL
ORDER BY program, report;
"@

$menuRows = Convert-TableToObjects (Invoke-AbioQuery -ConnectionString $connectionString -Sql $menuSql)
$reportRows = Convert-TableToObjects (Invoke-AbioQuery -ConnectionString $connectionString -Sql $reportSql)

$menuIndex = foreach ($row in $menuRows) {
    $module = Get-ModuleName -Menu1 $row.menu_1 -Program $row.program
    [pscustomobject] [ordered] @{
        id = "menu:$($row.program)"
        sourceTable = "dbo.abio_menu"
        module = $module
        program = $row.program
        description = $row.description
        prompt = $row.prompt
        shortcut = (($row.menu_1, $row.menu_2, $row.menu_3) | Where-Object { $_ -and $_.Trim() }) -join ""
        itemType = $row.item_type
        active = $row.active_flag -eq "Y"
        profile = $row.profile
        windowName = $row.window_name
        help = $row.help
        microhelp = $row.microhelp
        helpUrl = $row.help_url
    }
}

$reportIndex = foreach ($row in $reportRows) {
    $module = Get-ModuleName -Menu1 "" -Program $row.program
    [pscustomobject] [ordered] @{
        id = "report:$($row.program):$($row.report)"
        sourceTable = "dbo.program_report"
        module = $module
        program = $row.program
        report = $row.report
        name = $row.name
        active = $row.active_flag -eq "Y"
        controlFlag = $row.control_flag
        datawindowName = $row.datawindow_name
        summary = $row.microhelp
        trainingText = $row.description
        helpUrl = $row.help_url
    }
}

$courseLinks = $menuIndex |
    Where-Object { $_.helpUrl } |
    Group-Object module, helpUrl |
    ForEach-Object {
        $first = $_.Group[0]
        [pscustomobject] [ordered] @{
            module = $first.module
            helpUrl = $first.helpUrl
            menuItemCount = $_.Count
        }
    } |
    Sort-Object module, helpUrl

$moduleSummary = foreach ($group in ($menuIndex | Group-Object module | Sort-Object Name)) {
    $reports = @($reportIndex | Where-Object { $_.module -eq $group.Name })
    [pscustomobject] [ordered] @{
        module = $group.Name
        menuItems = $group.Count
        activeMenuItems = @($group.Group | Where-Object active).Count
        menuItemsWithHelpUrl = @($group.Group | Where-Object helpUrl).Count
        menuItemsWithMicrohelp = @($group.Group | Where-Object microhelp).Count
        reportTrainingRecords = $reports.Count
        reportTrainingRecordsWithHelpUrl = @($reports | Where-Object helpUrl).Count
    }
}

$kb = [pscustomobject] [ordered] @{
    generatedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    source = [ordered] @{
        database = $Database
        server = $Server
        menuSource = "dbo.abio_menu"
        reportSource = "dbo.program_report"
        usage = "Legacy module training/help index for Abio NG replatforming and future AI assistant retrieval"
        authorityLimit = "Use this as learning/help/context. PowerBuilder source and transactional SQL remain authoritative for behavior."
    }
    moduleSummary = $moduleSummary
    courseLinks = $courseLinks
    menuItems = $menuIndex
    reportTrainingRecords = $reportIndex
}

$jsonPath = Join-Path $OutputDirectory "LegacyTrainingMaterialsIndex.json"
$kb | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8

$mdPath = Join-Path $OutputDirectory "LegacyTrainingMaterials.md"
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# Legacy Training Materials Index")
$lines.Add("")
$lines.Add(("Generated from `dbo.abio_menu` and `dbo.program_report` in `{0}`." -f $Database))
$lines.Add("")
$lines.Add("This index is especially useful because it connects legacy menu programs, shortcuts, windows, help URLs, report DataWindows, and report-level training text. Use it as a practical knowledge source for Abio NG navigation, contextual help, and future AI assistant grounding.")
$lines.Add("")
$lines.Add("Do not treat this as authoritative for posting, validation, payroll calculation, or save behavior. Those still come from migrated PowerBuilder and SQL logic.")
$lines.Add("")
$lines.Add("## Module Summary")
$lines.Add("")
$lines.Add("| Module | Menu Items | With Help URL | With Microhelp | Report Training Records |")
$lines.Add("| --- | ---: | ---: | ---: | ---: |")
foreach ($module in $moduleSummary) {
    $lines.Add("| $($module.module) | $($module.menuItems) | $($module.menuItemsWithHelpUrl) | $($module.menuItemsWithMicrohelp) | $($module.reportTrainingRecords) |")
}
$lines.Add("")
$lines.Add("## Course And Lesson Links")
$lines.Add("")
$lines.Add("| Module | Help URL | Menu Items |")
$lines.Add("| --- | --- | ---: |")
foreach ($link in $courseLinks) {
    $lines.Add("| $($link.module) | $($link.helpUrl) | $($link.menuItemCount) |")
}
$lines.Add("")
$lines.Add("## Most Useful Report Training Records")
$lines.Add("")
$lines.Add("These are the highest-value records for AI/contextual help because they include purpose, what users see, criteria, when to use the report, and practical interpretation notes.")
$lines.Add("")
foreach ($moduleGroup in ($reportIndex | Where-Object { $_.active -and $_.trainingText } | Group-Object module | Sort-Object Name)) {
    $lines.Add("### $($moduleGroup.Name)")
    $topReports = $moduleGroup.Group | Select-Object -First 8
    foreach ($report in $topReports) {
        $summary = if ($report.summary) { $report.summary } else { ($report.trainingText -replace "\s+", " ").Substring(0, [Math]::Min(220, ($report.trainingText -replace "\s+", " ").Length)) }
        $lines.Add("")
        $lines.Add(('- `{0}/{1}` - {2}' -f $report.program, $report.report, $report.name))
        $lines.Add(('  Source DataWindow: `{0}`' -f $report.datawindowName))
        $lines.Add("  Summary: $summary")
    }
    $lines.Add("")
}

$lines | Set-Content -Path $mdPath -Encoding UTF8

Write-Host "Wrote $jsonPath"
Write-Host "Wrote $mdPath"
Write-Host "Menu records: $($menuIndex.Count)"
Write-Host "Report training records: $($reportIndex.Count)"
