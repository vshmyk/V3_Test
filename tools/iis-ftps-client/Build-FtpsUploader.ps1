param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$projectPath = Join-Path $PSScriptRoot "AOtransact.FtpsUploader.csproj"
$publishRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $PSScriptRoot "publish\$Runtime"
} else {
    [System.IO.Path]::GetFullPath($OutputRoot)
}

& dotnet restore $projectPath -r $Runtime
if ($LASTEXITCODE -ne 0) {
    throw "dotnet restore failed with exit code $LASTEXITCODE"
}

& dotnet publish $projectPath -c $Configuration -r $Runtime --self-contained true -o $publishRoot
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

Write-Host "Published FTPS uploader to $publishRoot"
Write-Host "Executable: $(Join-Path $publishRoot 'AOtransact.FtpsUploader.exe')"
