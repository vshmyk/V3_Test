param(
    [Parameter()]
    [string]$ServerInstance = "LOCALHOST\SQLEXPRESS",

    [Parameter()]
    [string]$Database = "OASIS_MH",

    [Parameter()]
    [int]$WindowMinutes = 15,

    [Parameter()]
    [string]$StartLsn,

    [Parameter()]
    [string]$OutputPath = ".\output\mh-den08.quote-only.logscan.json",

    [Parameter()]
    [string]$SqlUser,

    [Parameter()]
    [string]$SqlPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-CommittedTableTransactions.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Required script not found: $scriptPath"
}

$invokeParams = @{
    ServerInstance = $ServerInstance
    Database       = $Database
    Tables         = @("[MH-DEN08].[CHSC_QUOTE]")
    WindowMinutes  = $WindowMinutes
    OutputPath     = $OutputPath
}

if (-not [string]::IsNullOrWhiteSpace($StartLsn)) {
    $invokeParams["StartLsn"] = $StartLsn
}

if (-not [string]::IsNullOrWhiteSpace($SqlUser)) {
    if ([string]::IsNullOrWhiteSpace($SqlPassword)) {
        throw "SqlPassword is required when SqlUser is provided."
    }
    $invokeParams["SqlUser"] = $SqlUser
    $invokeParams["SqlPassword"] = $SqlPassword
}

& $scriptPath @invokeParams
