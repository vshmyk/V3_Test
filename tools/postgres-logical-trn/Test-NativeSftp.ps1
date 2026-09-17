param(
    [Parameter(Mandatory = $true)][string]$CaptureExecutable,
    [Parameter(Mandatory = $true)][string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$directory = Split-Path -Parent (Resolve-Path -LiteralPath $ConfigPath).Path
if (-not [IO.Path]::IsPathRooted($config.sftp.credentials_path)) {
    $config.sftp.credentials_path = Join-Path $directory $config.sftp.credentials_path
}
$temp = Join-Path $env:TEMP ('aotransact-sftp-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$testConfig = Join-Path $temp 'config.json'
function Save-TestSettings {
    [IO.File]::WriteAllText($testConfig, ($config | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
}

& $CaptureExecutable --test-sftp-transfer --config $ConfigPath
if ($LASTEXITCODE -ne 0) { throw 'Native SFTP transfer/collision test failed.' }

$originalFingerprint = [string]$config.sftp.ssh_host_key_fingerprint
$config.sftp.ssh_host_key_fingerprint = $originalFingerprint.Replace('SHA256:', '')
$config.sftp | Add-Member -Force NoteProperty winscp_dll_path 'C:\not-installed\WinSCPnet.dll'
Save-TestSettings
& $CaptureExecutable --test-sftp --config $testConfig
if ($LASTEXITCODE -ne 0) { throw 'Legacy SHA-256 notation / no-WinSCP test failed.' }

$config.sftp.ssh_host_key_fingerprint = 'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
Save-TestSettings
& $CaptureExecutable --test-sftp --config $testConfig
if ($LASTEXITCODE -eq 0) { throw 'Incorrect host key was accepted.' }

$config.sftp.ssh_host_key_fingerprint = '*'
Save-TestSettings
& $CaptureExecutable --test-sftp --config $testConfig
if ($LASTEXITCODE -eq 0) { throw 'Wildcard host key was accepted.' }

Write-Host 'Native SFTP live transfer, collision, retry, legacy notation, incorrect-key, and wildcard tests passed.'
# Expected-negative tests return nonzero; the test harness itself succeeded.
$global:LASTEXITCODE = 0
