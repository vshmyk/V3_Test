param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$InstallRoot = "C:\ProgramData\AOtransact\TransactionsLoader",
    [switch]$SelfContained
)

$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$projectPath = Join-Path $repoRoot "tools\transactions-loader\AOtransact.TransactionsLoader.csproj"
$publishRoot = Join-Path $repoRoot "artifacts\publish\transactions-loader"
$installRoot = [System.IO.Path]::GetFullPath($InstallRoot)

$publishArgs = @(
    "publish",
    $projectPath,
    "-c", $Configuration,
    "-r", $Runtime,
    "--no-restore",
    "-o", $publishRoot
)

& dotnet restore $projectPath -r $Runtime
if ($LASTEXITCODE -ne 0) {
    throw "dotnet restore failed with exit code $LASTEXITCODE"
}

if ($SelfContained) {
    $publishArgs += "--self-contained"
    $publishArgs += "true"
} else {
    $publishArgs += "--self-contained"
    $publishArgs += "false"
}

& dotnet @publishArgs
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
Copy-Item -Path (Join-Path $publishRoot "*") -Destination $installRoot -Recurse -Force

$configFiles = @(
    "transactions-loader.config.sample.json",
    "transactions-loader.config.erplink.json",
    "transactions-loader.config.erplink.all.json",
    "transactions-loader.config.production.sample.json"
)

foreach ($configFile in $configFiles) {
    $sourcePath = Join-Path $PSScriptRoot $configFile
    if (Test-Path -LiteralPath $sourcePath) {
        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $installRoot $configFile) -Force
    }
}

$logsPath = "C:\ProgramData\AOtransact\Logs"
New-Item -ItemType Directory -Force -Path $logsPath | Out-Null

Write-Host "Installed Transactions Loader to $installRoot"
Write-Host "Executable: $(Join-Path $installRoot 'AOtransact.TransactionsLoader.exe')"
Write-Host "Production sample config: $(Join-Path $installRoot 'transactions-loader.config.production.sample.json')"
