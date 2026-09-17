param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "dist\AOtransactPostgreSQL-win-x64")
)

$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "AOtransactPostgreSQL\AOtransactPostgreSQL.csproj"
dotnet publish $project -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true -p:DebugType=None -o $OutputDirectory
if ($LASTEXITCODE -ne 0) {
    throw "AOtransactPostgreSQL publish failed with exit code $LASTEXITCODE."
}

Copy-Item -LiteralPath (Join-Path $PSScriptRoot "aotransact-postgresql.config.example.json") `
    -Destination (Join-Path $OutputDirectory "aotransact-postgresql.config.example.json") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "aotransact-postgresql.config.example.json") `
    -Destination (Join-Path $OutputDirectory "aotransact-postgresql.config.json") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "README.md") `
    -Destination (Join-Path $OutputDirectory "README.md") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "THIRD-PARTY-NOTICES.md") `
    -Destination (Join-Path $OutputDirectory "THIRD-PARTY-NOTICES.md") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-AOtransactPostgreSQL.ps1") `
    -Destination (Join-Path $OutputDirectory "Install-AOtransactPostgreSQL.ps1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-PostgresLogicalTrn.ps1") `
    -Destination (Join-Path $OutputDirectory "Install-PostgresLogicalTrn.ps1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Configure-AOtransactPostgreSQL.ps1") `
    -Destination (Join-Path $OutputDirectory "Configure-AOtransactPostgreSQL.ps1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Protect-AOtransactCredentials.ps1") `
    -Destination (Join-Path $OutputDirectory "Protect-AOtransactCredentials.ps1") -Force
# Remove only obsolete dependencies from this explicitly selected build output.
$resolvedOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
foreach ($obsoleteName in @('WinSCPnet.dll', 'WinSCP.exe')) {
    $obsoletePath = Join-Path $resolvedOutput $obsoleteName
    if (Test-Path -LiteralPath $obsoletePath) {
        Remove-Item -LiteralPath $obsoletePath -Force
    }
}

$exe = Get-Item -LiteralPath (Join-Path $OutputDirectory "AOtransactPostgreSQL.exe")
$packagePath = Join-Path (Split-Path -Parent $OutputDirectory) "AOtransactPostgreSQL-win-x64.zip"
if (Test-Path -LiteralPath $packagePath) {
    Remove-Item -LiteralPath $packagePath -Force
}
Compress-Archive -Path (Join-Path $OutputDirectory '*') -DestinationPath $packagePath -CompressionLevel Optimal
[pscustomobject]@{
    Executable = $exe.FullName
    SizeBytes = $exe.Length
    Sha256 = (Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256).Hash
    Package = $packagePath
    PackageSha256 = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
}
