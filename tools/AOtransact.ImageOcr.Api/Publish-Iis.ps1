param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$projectPath = Join-Path $PSScriptRoot "AOtransact.ImageOcr.Api.csproj"

dotnet publish $projectPath `
    -c $Configuration `
    /p:PublishProfile=FolderProfile

Write-Host "Published IIS-ready output to bin\$Configuration\net8.0\publish"
