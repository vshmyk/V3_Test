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
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-AOtransactPostgreSQL.ps1") `
    -Destination (Join-Path $OutputDirectory "Install-AOtransactPostgreSQL.ps1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Install-PostgresLogicalTrn.ps1") `
    -Destination (Join-Path $OutputDirectory "Install-PostgresLogicalTrn.ps1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Configure-AOtransactPostgreSQL.ps1") `
    -Destination (Join-Path $OutputDirectory "Configure-AOtransactPostgreSQL.ps1") -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "Protect-AOtransactCredentials.ps1") `
    -Destination (Join-Path $OutputDirectory "Protect-AOtransactCredentials.ps1") -Force
$winScpDirectory = "C:\Program Files (x86)\WinSCP"
foreach ($winScpFile in @('WinSCPnet.dll', 'WinSCP.exe')) {
    $sourceWinScpFile = Join-Path $winScpDirectory $winScpFile
    if (-not (Test-Path -LiteralPath $sourceWinScpFile)) {
        throw "Required SFTP runtime file not found: $sourceWinScpFile"
    }
    Copy-Item -LiteralPath $sourceWinScpFile -Destination (Join-Path $OutputDirectory $winScpFile) -Force
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
