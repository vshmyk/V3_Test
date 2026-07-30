param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$OutputPath = ".\artifacts\msi\AOtransact.TransactionsLoader.Installer.msi"
)

$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
$publishScript = Join-Path $PSScriptRoot "Publish-TransactionsLoader.ps1"
$installerProject = Join-Path $repoRoot "installer\AOtransact.TransactionsLoader.Installer\AOtransact.TransactionsLoader.Installer.wixproj"
$installerOutput = Join-Path $repoRoot "installer\AOtransact.TransactionsLoader.Installer\bin\x64\$Configuration\AOtransact.TransactionsLoader.Installer.msi"
$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))

& powershell -ExecutionPolicy Bypass -File $publishScript -Configuration $Configuration -Runtime $Runtime -OutputPath ".\artifacts\publish\transactions-loader"
if ($LASTEXITCODE -ne 0) {
    throw "Publish-TransactionsLoader.ps1 failed with exit code $LASTEXITCODE"
}

& dotnet build $installerProject -c $Configuration
if ($LASTEXITCODE -ne 0) {
    throw "MSI build failed with exit code $LASTEXITCODE"
}

New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($resolvedOutput)) | Out-Null
Copy-Item -LiteralPath $installerOutput -Destination $resolvedOutput -Force

Write-Host "Built Transactions Loader MSI: $resolvedOutput"
