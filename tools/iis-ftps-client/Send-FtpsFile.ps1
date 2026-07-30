param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$RemotePath,

    [string]$SettingsPath = (Join-Path $PSScriptRoot "ftps-settings.json"),

    [switch]$SkipCertificateCheck
)

$ErrorActionPreference = "Stop"

function Get-EscapedRemotePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $trimmed = $Value.Replace("\", "/").Trim("/")
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        throw "Remote path cannot be empty."
    }

    $segments = $trimmed.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
    return ($segments | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join "/"
}

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Local file not found: $Path"
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath
$fileInfo = Get-Item -LiteralPath $resolvedPath

if ($fileInfo.PSIsContainer) {
    throw "Path must point to a file, not a directory: $resolvedPath"
}

if (-not (Test-Path -LiteralPath $SettingsPath)) {
    throw "Settings file not found: $SettingsPath. Run Install-FtpsUploader.ps1 first."
}

$settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
if (-not $settings.CredentialPath) {
    throw "CredentialPath is missing from $SettingsPath"
}

if (-not (Test-Path -LiteralPath $settings.CredentialPath)) {
    throw "Credential file not found: $($settings.CredentialPath). Run Install-FtpsUploader.ps1 again."
}

$credential = Import-Clixml -LiteralPath $settings.CredentialPath
if (-not ($credential -is [System.Management.Automation.PSCredential])) {
    throw "Credential file is not valid: $($settings.CredentialPath)"
}

$targetRemotePath = $RemotePath
if ([string]::IsNullOrWhiteSpace($targetRemotePath)) {
    $targetRemotePath = $fileInfo.Name
}

$escapedRemotePath = Get-EscapedRemotePath -Value $targetRemotePath
$uriBuilder = [System.UriBuilder]::new("ftp", [string]$settings.Host, [int]$settings.Port, $escapedRemotePath)
$request = [System.Net.FtpWebRequest]::Create($uriBuilder.Uri)
$request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
$request.Credentials = $credential
$request.EnableSsl = [bool]$settings.EnableSsl
$request.UseBinary = $true
$request.UsePassive = [bool]$settings.UsePassive
$request.KeepAlive = $false
$request.Timeout = 120000
$request.ReadWriteTimeout = 120000

$previousCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
$previousSecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    if ($SkipCertificateCheck) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }

    $requestStream = $request.GetRequestStream()
    try {
        $fileStream = [System.IO.File]::OpenRead($resolvedPath)
        try {
            $fileStream.CopyTo($requestStream)
        }
        finally {
            $fileStream.Dispose()
        }
    }
    finally {
        $requestStream.Dispose()
    }

    $response = [System.Net.FtpWebResponse]$request.GetResponse()
    try {
        Write-Host "Upload completed."
        Write-Host "Remote URI: $($uriBuilder.Uri.AbsoluteUri)"
        Write-Host "Server status: $($response.StatusDescription.Trim())"
    }
    finally {
        $response.Dispose()
    }
}
finally {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $previousCallback
    [System.Net.ServicePointManager]::SecurityProtocol = $previousSecurityProtocol
}
