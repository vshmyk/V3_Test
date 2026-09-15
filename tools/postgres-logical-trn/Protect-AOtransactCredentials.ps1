param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Security

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run credential migration from an elevated PowerShell session.'
}

$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$configDirectory = Split-Path -Parent $resolvedConfigPath
$config = Get-Content -LiteralPath $resolvedConfigPath -Raw | ConvertFrom-Json
$entropy = [Text.Encoding]::UTF8.GetBytes('AOtransactPostgreSQL|Credential|v1')

function Resolve-CredentialPath {
    param([string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $script:configDirectory $Path
}

function Protect-CredentialFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Path = $Path; Status = 'Missing' }
    }

    $lines = @(Get-Content -LiteralPath $Path)
    if ($lines | Where-Object { $_ -like 'DPAPI_LOCAL_MACHINE=*' } | Select-Object -First 1) {
        return [pscustomobject]@{ Path = $Path; Status = 'Already encrypted' }
    }

    $passwordLine = $lines | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
    if (-not $passwordLine) {
        throw "Legacy Password entry not found in credential file: $Path"
    }

    $plainBytes = [Text.Encoding]::UTF8.GetBytes($passwordLine.Substring('Password='.Length))
    $protectedBytes = $null
    $temporaryPath = "$Path.dpapi.tmp"
    try {
        $protectedBytes = [Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $script:entropy,
            [Security.Cryptography.DataProtectionScope]::LocalMachine)
        $encoded = [Convert]::ToBase64String($protectedBytes)
        [IO.File]::WriteAllText($temporaryPath, "DPAPI_LOCAL_MACHINE=$encoded`r`n", [Text.Encoding]::ASCII)
        & icacls.exe $temporaryPath /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F' | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not secure encrypted credential file ACL: $Path"
        }
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if ($null -ne $protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }

    return [pscustomobject]@{ Path = $Path; Status = 'Encrypted' }
}

$credentialPaths = @(
    Resolve-CredentialPath -Path ([string]$config.postgres.credentials_path)
    Resolve-CredentialPath -Path ([string]$config.sftp.credentials_path)
) | Select-Object -Unique

$credentialPaths | ForEach-Object { Protect-CredentialFile -Path $_ }
