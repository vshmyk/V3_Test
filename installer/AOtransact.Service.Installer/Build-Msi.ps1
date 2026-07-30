param(
    [string]$Configuration = 'Release',
    [string]$Version = '1.0.0',
    [string]$OutputDir = 'artifacts\msi',
    [switch]$SkipPublish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$serviceProject = Join-Path $repoRoot 'tools\offline-log\service-host\AOtransact.ServiceHost.csproj'
$converterProject = Join-Path $repoRoot 'tools\offline-log\fast-quote-convert\fast-quote-convert.csproj'
$servicePublishDir = Join-Path $repoRoot 'artifacts\publish\service-host'
$converterPublishDir = Join-Path $repoRoot 'artifacts\publish\fast-quote-convert-win64'
$payloadRoot = Join-Path $repoRoot 'artifacts\msi-payload'
$payloadServiceDir = Join-Path $payloadRoot 'service-host'
$payloadOfflineLogDir = Join-Path $payloadRoot 'offline-log'
$payloadConverterDir = Join-Path $payloadOfflineLogDir 'fast-quote-convert\bin\Release\net8.0'
$installerProject = Join-Path $repoRoot 'installer\AOtransact.Service.Installer\AOtransact.Service.Installer.wixproj'
$outputPath = Join-Path $repoRoot $OutputDir

if (-not $SkipPublish) {
    dotnet publish $serviceProject -c $Configuration -o $servicePublishDir
    dotnet publish $converterProject -c $Configuration -r win-x64 --self-contained false -o $converterPublishDir
}

if (Test-Path -LiteralPath $payloadRoot) {
    Remove-Item -LiteralPath $payloadRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $payloadServiceDir | Out-Null
New-Item -ItemType Directory -Force -Path $payloadOfflineLogDir | Out-Null
New-Item -ItemType Directory -Force -Path $payloadConverterDir | Out-Null

Copy-Item -Path (Join-Path $servicePublishDir '*') -Destination $payloadServiceDir -Recurse -Force
Copy-Item -Path (Join-Path $converterPublishDir '*') -Destination $payloadConverterDir -Recurse -Force

$offlineFiles = @(
    'Apply-TrnToTarget.ps1',
    'Convert-HybridToTrn.ps1',
    'Export-ChscMetadataSnapshot.ps1',
    'Get-LiveCommittedDmlManifest.ps1',
    'Get-RawLdfHybridMatches.ps1',
    'Prepare-RawLdfIndex.ps1',
    'Run-AOTransactProductionCycle.ps1',
    'Run-HybridLdfSingleSnapshotMultiTable.ps1',
    'production.service.config.sample.json',
    'hybrid.config.sample.json'
)
foreach ($name in $offlineFiles) {
    Copy-Item -LiteralPath (Join-Path $repoRoot ('tools\offline-log\' + $name)) -Destination (Join-Path $payloadOfflineLogDir $name) -Force
}

$serviceSettings = @{
    serviceName = 'AOTransact'
    pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
    runnerScriptPath = '.\offline-log\Run-AOTransactProductionCycle.ps1'
    configPath = '.\offline-log\production.service.config.json'
    workingDirectory = '.'
    restartDelaySeconds = 5
    restartOnUnexpectedExit = $true
    logPath = '.\logs\service-host.log'
}
$serviceSettings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $payloadServiceDir 'service-host.settings.json') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $repoRoot 'tools\offline-log\production.service.config.sample.json') -Destination (Join-Path $payloadOfflineLogDir 'production.service.config.json') -Force

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

dotnet build $installerProject -c $Configuration -p:Version=$Version -o $outputPath
