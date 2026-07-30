param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$OutputPath = ".\artifacts\publish\transactions-loader"
)

$ErrorActionPreference = "Stop"

$projectPath = ".\tools\transactions-loader\AOtransact.TransactionsLoader.csproj"
$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))

dotnet restore $projectPath -r $Runtime
if ($LASTEXITCODE -ne 0) {
  throw "dotnet restore failed with exit code $LASTEXITCODE"
}

dotnet publish $projectPath `
  -c $Configuration `
  -r $Runtime `
  --no-restore `
  --self-contained false `
  -o $resolvedOutput

Write-Host "Published Transactions Loader to $resolvedOutput"
