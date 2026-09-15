param(
    [string]$PackageDirectory = $PSScriptRoot,
    [string]$ConfigPath = (Join-Path $PackageDirectory "aotransact-postgresql.config.json")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

$credentialEntropy = [Text.Encoding]::UTF8.GetBytes('AOtransactPostgreSQL|Credential|v1')

function Protect-CredentialPassword {
    param([string]$Password)

    $plainBytes = [Text.Encoding]::UTF8.GetBytes($Password)
    $protectedBytes = $null
    try {
        $protectedBytes = [Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $script:credentialEntropy,
            [Security.Cryptography.DataProtectionScope]::LocalMachine)
        return [Convert]::ToBase64String($protectedBytes)
    }
    finally {
        if ($null -ne $protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
        [Array]::Clear($plainBytes, 0, $plainBytes.Length)
    }
}

function Get-CredentialPassword {
    param([string]$Path)

    $lines = @(Get-Content -LiteralPath $Path)
    $protectedLine = $lines | Where-Object { $_ -like 'DPAPI_LOCAL_MACHINE=*' } | Select-Object -First 1
    if ($protectedLine) {
        $protectedBytes = $null
        $plainBytes = $null
        try {
            $protectedBytes = [Convert]::FromBase64String($protectedLine.Substring('DPAPI_LOCAL_MACHINE='.Length))
            $plainBytes = [Security.Cryptography.ProtectedData]::Unprotect(
                $protectedBytes,
                $script:credentialEntropy,
                [Security.Cryptography.DataProtectionScope]::LocalMachine)
            return [Text.Encoding]::UTF8.GetString($plainBytes)
        }
        finally {
            if ($null -ne $plainBytes) { [Array]::Clear($plainBytes, 0, $plainBytes.Length) }
            if ($null -ne $protectedBytes) { [Array]::Clear($protectedBytes, 0, $protectedBytes.Length) }
        }
    }

    $passwordLine = $lines | Where-Object { $_ -like 'Password=*' } | Select-Object -First 1
    if ($passwordLine) {
        return $passwordLine.Substring('Password='.Length)
    }
    throw "Encrypted or legacy password entry not found in $Path"
}

function Resolve-PsqlExecutable {
    param([string]$ConfiguredPath)
    if ($ConfiguredPath -ne 'auto' -and (Test-Path -LiteralPath $ConfiguredPath)) {
        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }
    $candidates = @()
    $root = 'C:\Program Files\PostgreSQL'
    if (Test-Path -LiteralPath $root) {
        foreach ($directory in Get-ChildItem -LiteralPath $root -Directory) {
            foreach ($relativePath in @('bin\psql.exe', 'pgsql\bin\psql.exe')) {
                $candidate = Join-Path $directory.FullName $relativePath
                if (Test-Path -LiteralPath $candidate) { $candidates += Get-Item -LiteralPath $candidate }
            }
        }
    }
    $selected = $candidates | Sort-Object { if ($_.FullName -match '\\PostgreSQL\\(?<version>\d+)\\') { [int]$matches['version'] } else { 0 } } -Descending | Select-Object -First 1
    if (-not $selected) { return $ConfiguredPath }
    return $selected.FullName
}

function Resolve-PostgresServiceName {
    param([string]$ConfiguredName, [string]$PsqlPath)
    if ($ConfiguredName -ne 'auto' -and (Get-Service -Name $ConfiguredName -ErrorAction SilentlyContinue)) {
        return $ConfiguredName
    }
    if ($PsqlPath -match '\\PostgreSQL\\(?<version>\d+)\\') {
        $versionService = "postgresql-x64-$($matches['version'])"
        if (Get-Service -Name $versionService -ErrorAction SilentlyContinue) { return $versionService }
    }
    $service = Get-Service -Name 'postgresql*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Running' } | Select-Object -First 1
    if (-not $service) { return $ConfiguredName }
    return $service.Name
}

function New-TextBox {
    param([string]$Text = "", [switch]$Password, [switch]$Multiline)
    $control = [Windows.Forms.TextBox]::new()
    $control.Text = $Text
    $control.Dock = 'Fill'
    $control.UseSystemPasswordChar = [bool]$Password
    if ($Multiline) {
        $control.Multiline = $true
        $control.ScrollBars = 'Both'
        $control.AcceptsReturn = $true
        $control.WordWrap = $false
        $control.Height = 230
    }
    return $control
}

function New-Page {
    param([Windows.Forms.TabControl]$Tabs, [string]$Title)
    $page = [Windows.Forms.TabPage]::new($Title)
    $page.Padding = [Windows.Forms.Padding]::new(12)
    $panel = [Windows.Forms.TableLayoutPanel]::new()
    $panel.Dock = 'Fill'
    $panel.AutoScroll = $true
    $panel.ColumnCount = 2
    [void]$panel.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Absolute, 210))
    [void]$panel.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new([Windows.Forms.SizeType]::Percent, 100))
    $page.Controls.Add($panel)
    [void]$Tabs.TabPages.Add($page)
    return $panel
}

function Add-Field {
    param(
        [Windows.Forms.TableLayoutPanel]$Panel,
        [string]$Label,
        [Windows.Forms.Control]$Control,
        [int]$Height = 34
    )
    $row = $Panel.RowCount
    $Panel.RowCount++
    [void]$Panel.RowStyles.Add([Windows.Forms.RowStyle]::new([Windows.Forms.SizeType]::Absolute, $Height))
    $caption = [Windows.Forms.Label]::new()
    $caption.Text = $Label
    $caption.TextAlign = 'MiddleLeft'
    $caption.Dock = 'Fill'
    $Panel.Controls.Add($caption, 0, $row)
    $Panel.Controls.Add($Control, 1, $row)
}

function Save-PasswordFile {
    param([string]$Path, [string]$Password)
    if ([string]::IsNullOrWhiteSpace($Password)) {
        if (-not (Test-Path -LiteralPath $Path)) {
            throw "A password is required because the credential file does not exist: $Path"
        }
        return
    }
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $protectedPassword = Protect-CredentialPassword -Password $Password
    [IO.File]::WriteAllText($Path, "DPAPI_LOCAL_MACHINE=$protectedPassword`r`n", [Text.Encoding]::ASCII)
    & icacls.exe $Path /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not secure credential file ACL: $Path"
    }
}

function Test-PostgresConnection {
    param([pscustomobject]$Config, [string]$Password)
    $oldPassword = $env:PGPASSWORD
    try {
        $env:PGPASSWORD = $Password
        $result = & $Config.postgres.psql_path -h $Config.postgres.host -p $Config.postgres.port `
            -U $Config.postgres.user -d $Config.postgres.database -w -t -A -v ON_ERROR_STOP=1 `
            -c "SELECT current_database() || '|' || current_user;"
        if ($LASTEXITCODE -ne 0) {
            throw "PostgreSQL connection validation failed."
        }
        return ($result | Select-Object -Last 1).Trim()
    }
    finally {
        if ($null -eq $oldPassword) {
            Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
        } else {
            $env:PGPASSWORD = $oldPassword
        }
    }
}

function Test-SftpConnection {
    param([pscustomobject]$Config, [string]$Password)
    $dll = Join-Path $PackageDirectory 'WinSCPnet.dll'
    Add-Type -Path $dll
    $options = [WinSCP.SessionOptions]@{
        Protocol = [WinSCP.Protocol]::Sftp
        HostName = [string]$Config.sftp.host
        PortNumber = [int]$Config.sftp.port
        UserName = [string]$Config.sftp.username
        Password = $Password
        SshHostKeyFingerprint = ([string]$Config.sftp.ssh_host_key_fingerprint) -replace '(?i)SHA256:', ''
    }
    $session = [WinSCP.Session]::new()
    try {
        $session.ExecutablePath = Join-Path $PackageDirectory 'WinSCP.exe'
        $session.Open($options)
    }
    finally {
        $session.Dispose()
    }
}

function Get-CaptureFailureMessage {
    param([string]$ErrorPath, [int]$ExitCode)
    if (Test-Path -LiteralPath $ErrorPath) {
        try {
            $captureError = Get-Content -LiteralPath $ErrorPath -Raw | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace([string]$captureError.message)) {
                return "Initial capture failed: $($captureError.message)`r`n`r`nDiagnostic file: $ErrorPath"
            }
        } catch {
            return "Initial capture failed with exit code $ExitCode.`r`n`r`nDiagnostic file could not be parsed: $ErrorPath"
        }
    }
    return "Initial capture failed with exit code $ExitCode. No diagnostic file was created at $ErrorPath"
}

$templatePath = if (Test-Path -LiteralPath $ConfigPath) {
    $ConfigPath
} else {
    Join-Path $PackageDirectory 'aotransact-postgresql.config.example.json'
}
$defaults = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json
$detectedPsql = Resolve-PsqlExecutable -ConfiguredPath ([string]$defaults.postgres.psql_path)
$detectedService = Resolve-PostgresServiceName -ConfiguredName ([string]$defaults.postgres.service_name) -PsqlPath $detectedPsql

$form = [Windows.Forms.Form]::new()
$form.Text = 'AOtransactPostgreSQL Setup Wizard'
$form.StartPosition = 'CenterScreen'
$form.Size = [Drawing.Size]::new(920, 700)
$form.MinimumSize = [Drawing.Size]::new(820, 620)
$form.Font = [Drawing.Font]::new('Segoe UI', 10)

$tabs = [Windows.Forms.TabControl]::new()
$tabs.Dock = 'Fill'
$form.Controls.Add($tabs)

$clientPage = New-Page -Tabs $tabs -Title '1. Client and PostgreSQL'
$clientId = New-TextBox ([string]$defaults.client.id)
$clientName = New-TextBox ([string]$defaults.client.name)
$pgHost = New-TextBox ([string]$defaults.postgres.host)
$pgPort = New-TextBox ([string]$defaults.postgres.port)
$pgDatabase = New-TextBox ([string]$defaults.postgres.database)
$pgUser = New-TextBox ([string]$defaults.postgres.user)
$pgPassword = New-TextBox -Password
$pgPsql = New-TextBox $detectedPsql
$pgService = New-TextBox $detectedService
$slotName = New-TextBox ([string]$defaults.capture.slot_name)
Add-Field $clientPage 'Client ID' $clientId
Add-Field $clientPage 'Client name' $clientName
Add-Field $clientPage 'PostgreSQL host' $pgHost
Add-Field $clientPage 'PostgreSQL port' $pgPort
Add-Field $clientPage 'Database' $pgDatabase
Add-Field $clientPage 'Database user' $pgUser
Add-Field $clientPage 'Database password' $pgPassword
Add-Field $clientPage 'psql.exe path' $pgPsql
Add-Field $clientPage 'PostgreSQL service' $pgService
Add-Field $clientPage 'Logical slot name' $slotName

$filesPage = New-Page -Tabs $tabs -Title '2. Files and Packaging'
$installDirectory = New-TextBox 'C:\ProgramData\AOtransactPostgreSQL'
$dataDirectory = New-TextBox (Split-Path -Parent ([string]$defaults.capture.output_path))
$zipTemplate = New-TextBox ([string]$defaults.package.zip_filename_template)
$trnTemplate = New-TextBox ([string]$defaults.package.trn_entry_filename_template)
$archiveBatches = [Windows.Forms.CheckBox]::new()
$archiveBatches.Text = 'Retain non-empty .trn archive files'
$archiveBatches.Checked = [bool]$defaults.capture.archive_batches
$archiveBatches.Dock = 'Fill'
$archiveRetentionDays = New-TextBox ([string]$(if ($null -ne $defaults.capture.PSObject.Properties['archive_retention_days']) { $defaults.capture.archive_retention_days } else { 5 }))
$trimFixedCharacterSpaces = [Windows.Forms.CheckBox]::new()
$trimFixedCharacterSpaces.Text = 'Trim trailing padding from fixed-width character fields'
$trimFixedCharacterSpaces.Checked = if ($null -ne $defaults.capture.PSObject.Properties['trim_fixed_character_trailing_spaces']) { [bool]$defaults.capture.trim_fixed_character_trailing_spaces } else { $true }
$trimFixedCharacterSpaces.Dock = 'Fill'
Add-Field $filesPage 'Install directory' $installDirectory
Add-Field $filesPage 'Data directory' $dataDirectory
Add-Field $filesPage 'ZIP filename template' $zipTemplate
Add-Field $filesPage '.trn filename template' $trnTemplate
Add-Field $filesPage 'Archive batches' $archiveBatches
Add-Field $filesPage 'Archive retention days' $archiveRetentionDays
Add-Field $filesPage 'String normalization' $trimFixedCharacterSpaces

$sftpPage = New-Page -Tabs $tabs -Title '3. SFTP'
$sftpEnabled = [Windows.Forms.CheckBox]::new()
$sftpEnabled.Text = 'Upload ZIP batches by SFTP'
$sftpEnabled.Checked = [bool]$defaults.sftp.enabled
$sftpEnabled.Dock = 'Fill'
$sftpHost = New-TextBox ([string]$defaults.sftp.host)
$sftpPort = New-TextBox ([string]$defaults.sftp.port)
$sftpUser = New-TextBox ([string]$defaults.sftp.username)
$sftpPassword = New-TextBox -Password
$sftpDirectory = New-TextBox ([string]$defaults.sftp.remote_directory)
$sftpFingerprint = New-TextBox ([string]$defaults.sftp.ssh_host_key_fingerprint)
$remoteTemplate = New-TextBox ([string]$defaults.sftp.remote_filename_template)
Add-Field $sftpPage 'Enable SFTP' $sftpEnabled
Add-Field $sftpPage 'SFTP host' $sftpHost
Add-Field $sftpPage 'SFTP port' $sftpPort
Add-Field $sftpPage 'SFTP username' $sftpUser
Add-Field $sftpPage 'SFTP password' $sftpPassword
Add-Field $sftpPage 'Remote directory' $sftpDirectory
Add-Field $sftpPage 'SSH host fingerprint' $sftpFingerprint
Add-Field $sftpPage 'Remote ZIP template' $remoteTemplate

$schedulePage = New-Page -Tabs $tabs -Title '4. Schedule and Tables'
$scheduleEnabled = [Windows.Forms.CheckBox]::new()
$scheduleEnabled.Text = 'Install recurring Windows scheduled task'
$scheduleEnabled.Checked = [bool]$defaults.schedule.enabled
$scheduleEnabled.Dock = 'Fill'
$scheduleInterval = New-TextBox ([string]$defaults.schedule.interval_minutes)
$maxChangesPerRun = New-TextBox ([string]$(if ($null -ne $defaults.capture.PSObject.Properties['max_changes_per_run']) { $defaults.capture.max_changes_per_run } else { 10000 }))
$taskName = New-TextBox ([string]$defaults.schedule.task_name)
$configurePostgres = [Windows.Forms.CheckBox]::new()
$configurePostgres.Text = 'Configure logical decoding now (may restart PostgreSQL)'
$configurePostgres.Checked = $true
$configurePostgres.Dock = 'Fill'
$runInitial = [Windows.Forms.CheckBox]::new()
$runInitial.Text = 'Run one capture before installing the schedule'
$runInitial.Checked = $true
$runInitial.Dock = 'Fill'
$tables = New-TextBox -Text ((@($defaults.tables)) -join "`r`n") -Multiline
Add-Field $schedulePage 'Enable schedule' $scheduleEnabled
Add-Field $schedulePage 'Interval in minutes' $scheduleInterval
Add-Field $schedulePage 'Maximum WAL rows per run' $maxChangesPerRun
Add-Field $schedulePage 'Scheduled task name' $taskName
Add-Field $schedulePage 'PostgreSQL setup' $configurePostgres
Add-Field $schedulePage 'Initial validation run' $runInitial
Add-Field $schedulePage 'Tracked tables (one per line)' $tables 260

$footer = [Windows.Forms.Panel]::new()
$footer.Dock = 'Bottom'
$footer.Height = 64
$form.Controls.Add($footer)
$footer.BringToFront()

$status = [Windows.Forms.Label]::new()
$status.Text = 'Complete each page, then validate and install.'
$status.AutoSize = $false
$status.TextAlign = 'MiddleLeft'
$status.Location = [Drawing.Point]::new(12, 8)
$status.Size = [Drawing.Size]::new(560, 44)
$footer.Controls.Add($status)

$installButton = [Windows.Forms.Button]::new()
$installButton.Text = 'Validate and Install'
$installButton.Size = [Drawing.Size]::new(175, 38)
$installButton.Anchor = 'Top,Right'
$installButton.Location = [Drawing.Point]::new(615, 12)
$footer.Controls.Add($installButton)

$cancelButton = [Windows.Forms.Button]::new()
$cancelButton.Text = 'Cancel'
$cancelButton.Size = [Drawing.Size]::new(95, 38)
$cancelButton.Anchor = 'Top,Right'
$cancelButton.Location = [Drawing.Point]::new(795, 12)
$cancelButton.Add_Click({ $form.Close() })
$footer.Controls.Add($cancelButton)

$installButton.Add_Click({
    $installButton.Enabled = $false
    $form.UseWaitCursor = $true
    try {
        $id = $clientId.Text.Trim()
        if ($id -notmatch '^[A-Za-z0-9_-]+$') {
            throw 'Client ID may contain only letters, numbers, underscore, and hyphen.'
        }
        $pgPortValue = 0
        $sftpPortValue = 0
        $intervalValue = 0
        $maxChangesValue = 0
        $archiveRetentionValue = 0
        if (-not [int]::TryParse($pgPort.Text, [ref]$pgPortValue) -or $pgPortValue -notin 1..65535) {
            throw 'PostgreSQL port must be between 1 and 65535.'
        }
        if (-not [int]::TryParse($sftpPort.Text, [ref]$sftpPortValue) -or $sftpPortValue -notin 1..65535) {
            throw 'SFTP port must be between 1 and 65535.'
        }
        if (-not [int]::TryParse($scheduleInterval.Text, [ref]$intervalValue) -or $intervalValue -lt 1) {
            throw 'Schedule interval must be at least one minute.'
        }
        if (-not [int]::TryParse($maxChangesPerRun.Text, [ref]$maxChangesValue) -or $maxChangesValue -lt 1) {
            throw 'Maximum WAL rows per run must be at least 1.'
        }
        if (-not [int]::TryParse($archiveRetentionDays.Text, [ref]$archiveRetentionValue) -or $archiveRetentionValue -lt 1) {
            throw 'Archive retention days must be at least 1.'
        }
        if (-not (Test-Path -LiteralPath $pgPsql.Text.Trim())) {
            throw "psql.exe was not found: $($pgPsql.Text.Trim())"
        }

        $tableList = @($tables.Lines | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
        if ($tableList.Count -eq 0) {
            throw 'At least one tracked table is required.'
        }
        foreach ($table in $tableList) {
            if ($table -notmatch '^[^.]+\.[^.]+$') {
                throw "Tracked table must use schema.table format: $table"
            }
        }

        $dataPath = $dataDirectory.Text.Trim().TrimEnd('\')
        $installPath = $installDirectory.Text.Trim().TrimEnd('\')
        New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
        $pgCredentialPath = Join-Path $dataPath 'postgresql-credentials.txt'
        $sftpCredentialPath = Join-Path $dataPath 'sftp-credentials.txt'

        $config = [ordered]@{
            client = [ordered]@{ id = $id; name = $clientName.Text.Trim() }
            postgres = [ordered]@{
                host = $pgHost.Text.Trim(); port = $pgPortValue; database = $pgDatabase.Text.Trim()
                user = $pgUser.Text.Trim(); credentials_path = $pgCredentialPath
                psql_path = $pgPsql.Text.Trim(); service_name = $pgService.Text.Trim()
            }
            capture = [ordered]@{
                slot_name = $slotName.Text.Trim(); output_path = (Join-Path $dataPath 'transactions.trn')
                archive_directory = (Join-Path $dataPath 'archive'); checkpoint_path = (Join-Path $dataPath 'checkpoint.json')
                last_batch_path = (Join-Path $dataPath 'last-batch.json'); error_path = (Join-Path $dataPath 'last-error.json')
                resume_from_saved_checkpoint = $true; archive_batches = $archiveBatches.Checked
                archive_empty_batches = $false; clear_output_when_empty = $true
                archive_retention_days = $archiveRetentionValue
                trim_fixed_character_trailing_spaces = $trimFixedCharacterSpaces.Checked
                max_changes_per_run = $maxChangesValue
            }
            package = [ordered]@{
                enabled = $true; directory = (Join-Path $dataPath 'outbox')
                sent_directory = (Join-Path $dataPath 'sent')
                zip_filename_template = $zipTemplate.Text.Trim(); trn_entry_filename_template = $trnTemplate.Text.Trim()
            }
            sftp = [ordered]@{
                enabled = $sftpEnabled.Checked; host = $sftpHost.Text.Trim(); port = $sftpPortValue
                username = $sftpUser.Text.Trim(); credentials_path = $sftpCredentialPath
                ssh_host_key_fingerprint = $sftpFingerprint.Text.Trim(); remote_directory = $sftpDirectory.Text.Trim()
                remote_filename_template = $remoteTemplate.Text.Trim(); upload_empty_files = $false
                winscp_dll_path = (Join-Path $installPath 'WinSCPnet.dll')
            }
            schedule = [ordered]@{
                enabled = $scheduleEnabled.Checked; interval_minutes = $intervalValue; task_name = $taskName.Text.Trim()
            }
            tables = $tableList
        }
        $configObject = [pscustomobject]$config

        Save-PasswordFile -Path $pgCredentialPath -Password $pgPassword.Text
        if ($sftpEnabled.Checked) {
            Save-PasswordFile -Path $sftpCredentialPath -Password $sftpPassword.Text
        }
        $status.Text = 'Validating PostgreSQL connection...'
        [Windows.Forms.Application]::DoEvents()
        $pgValidationPassword = if ($pgPassword.Text) { $pgPassword.Text } else { Get-CredentialPassword -Path $pgCredentialPath }
        $pgIdentity = Test-PostgresConnection -Config $configObject -Password $pgValidationPassword

        if ($sftpEnabled.Checked) {
            $status.Text = 'Validating SFTP authentication and host key...'
            [Windows.Forms.Application]::DoEvents()
            $sftpValidationPassword = if ($sftpPassword.Text) { $sftpPassword.Text } else { Get-CredentialPassword -Path $sftpCredentialPath }
            Test-SftpConnection -Config $configObject -Password $sftpValidationPassword
        }

        $configDirectory = Split-Path -Parent $ConfigPath
        New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
        [IO.File]::WriteAllText($ConfigPath, (($configObject | ConvertTo-Json -Depth 8) + "`r`n"), [Text.Encoding]::UTF8)

        if ($configurePostgres.Checked) {
            $status.Text = 'Configuring PostgreSQL logical decoding...'
            [Windows.Forms.Application]::DoEvents()
            & (Join-Path $PackageDirectory 'Install-PostgresLogicalTrn.ps1') -ConfigPath $ConfigPath
            if ($LASTEXITCODE -ne 0) { throw "PostgreSQL setup failed with exit code $LASTEXITCODE." }
        }

        $status.Text = 'Installing utility and scheduled task...'
        [Windows.Forms.Application]::DoEvents()
        & (Join-Path $PackageDirectory 'Install-AOtransactPostgreSQL.ps1') `
            -ConfigPath $ConfigPath -InstallDirectory $installPath -ForceConfig
        if ($LASTEXITCODE -ne 0) { throw "Utility installation failed with exit code $LASTEXITCODE." }

        $installedConfig = Join-Path $installPath 'aotransact-postgresql.config.json'
        if ($runInitial.Checked) {
            $status.Text = 'Running initial transaction capture...'
            [Windows.Forms.Application]::DoEvents()
            & (Join-Path $installPath 'AOtransactPostgreSQL.exe') --config $installedConfig
            if ($LASTEXITCODE -ne 0) {
                throw (Get-CaptureFailureMessage -ErrorPath ([string]$configObject.capture.error_path) -ExitCode $LASTEXITCODE)
            }
        }

        $status.Text = "Installation complete for $id. PostgreSQL: $pgIdentity"
        [Windows.Forms.MessageBox]::Show(
            "AOtransactPostgreSQL is installed for $id.`r`n`r`nConfig: $installedConfig`r`nInstall: $installPath",
            'Installation complete', 'OK', 'Information') | Out-Null
    }
    catch {
        $status.Text = "Installation failed: $($_.Exception.Message)"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Installation failed', 'OK', 'Error') | Out-Null
    }
    finally {
        $form.UseWaitCursor = $false
        $installButton.Enabled = $true
    }
})

[void]$form.ShowDialog()
