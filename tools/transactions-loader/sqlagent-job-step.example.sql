/*
Example SQL Server Agent job for the Transactions Loader pipeline.

Step 1:
- runs the published loader executable to stage new DML into TransactionLog

Step 2:
- executes INTEGRAMASTER_V2.dbo.RunTransactions for the same client

Adjust these values before use:
- @job_name
- @client_id
- @loader_path
- @config_path
- @run_transactions_db
- @schedule_name
*/

DECLARE @job_name sysname = N'AOtransact - Transactions Pipeline - PLS';
DECLARE @schedule_name sysname = N'Every 15 Minutes';
DECLARE @server_name sysname = @@SERVERNAME;
DECLARE @client_id nvarchar(50) = N'PLS';
DECLARE @loader_path nvarchar(4000) = N'C:\ProgramData\AOtransact\TransactionsLoader\AOtransact.TransactionsLoader.exe';
DECLARE @config_path nvarchar(4000) = N'C:\ProgramData\AOtransact\TransactionsLoader\transactions-loader.config.sample.json';
DECLARE @run_transactions_db sysname = N'INTEGRAMASTER_V2';
DECLARE @load_step_name sysname = N'Load Transaction Files';
DECLARE @apply_step_name sysname = N'Apply Loaded Transactions';
DECLARE @load_command nvarchar(max) =
    N'"' + @loader_path + N'" --client-id ' + QUOTENAME(@client_id, '"') +
    N' --config "' + @config_path + N'"';
DECLARE @apply_command nvarchar(max) =
    N'EXEC dbo.RunTransactions @ClientId = N''' + REPLACE(@client_id, '''', '''''') + N''';';

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @job_name)
BEGIN
    EXEC msdb.dbo.sp_add_job
        @job_name = @job_name,
        @enabled = 1,
        @description = N'Loads zipped TRN batches into TransactionLog and then applies pending DML to the target database.',
        @start_step_id = 1;
END;

IF EXISTS (
    SELECT 1
    FROM msdb.dbo.sysjobsteps s
    INNER JOIN msdb.dbo.sysjobs j ON j.job_id = s.job_id
    WHERE j.name = @job_name
      AND s.step_name = @load_step_name
)
BEGIN
    EXEC msdb.dbo.sp_update_jobstep
        @job_name = @job_name,
        @step_name = @load_step_name,
        @step_id = 1,
        @subsystem = N'CmdExec',
        @command = @load_command,
        @database_name = N'master',
        @on_success_action = 3,
        @on_success_step_id = 2,
        @on_fail_action = 2,
        @retry_attempts = 0,
        @retry_interval = 0,
        @output_file_name = N'C:\ProgramData\AOtransact\Logs\transactions-loader-pls.log';
END;
ELSE
BEGIN
    EXEC msdb.dbo.sp_add_jobstep
        @job_name = @job_name,
        @step_name = @load_step_name,
        @step_id = 1,
        @subsystem = N'CmdExec',
        @command = @load_command,
        @database_name = N'master',
        @on_success_action = 3,
        @on_success_step_id = 2,
        @on_fail_action = 2,
        @retry_attempts = 0,
        @retry_interval = 0,
        @output_file_name = N'C:\ProgramData\AOtransact\Logs\transactions-loader-pls.log';
END;

IF EXISTS (
    SELECT 1
    FROM msdb.dbo.sysjobsteps s
    INNER JOIN msdb.dbo.sysjobs j ON j.job_id = s.job_id
    WHERE j.name = @job_name
      AND s.step_name = @apply_step_name
)
BEGIN
    EXEC msdb.dbo.sp_update_jobstep
        @job_name = @job_name,
        @step_name = @apply_step_name,
        @step_id = 2,
        @subsystem = N'TSQL',
        @command = @apply_command,
        @database_name = @run_transactions_db,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 0,
        @retry_interval = 0,
        @output_file_name = N'C:\ProgramData\AOtransact\Logs\runtransactions-pls.log';
END;
ELSE
BEGIN
    EXEC msdb.dbo.sp_add_jobstep
        @job_name = @job_name,
        @step_name = @apply_step_name,
        @step_id = 2,
        @subsystem = N'TSQL',
        @command = @apply_command,
        @database_name = @run_transactions_db,
        @on_success_action = 1,
        @on_fail_action = 2,
        @retry_attempts = 0,
        @retry_interval = 0,
        @output_file_name = N'C:\ProgramData\AOtransact\Logs\runtransactions-pls.log';
END;

IF NOT EXISTS (
    SELECT 1
    FROM msdb.dbo.sysjobschedules js
    INNER JOIN msdb.dbo.sysjobs j ON j.job_id = js.job_id
    INNER JOIN msdb.dbo.sysschedules ss ON ss.schedule_id = js.schedule_id
    WHERE j.name = @job_name
      AND ss.name = @schedule_name
)
BEGIN
    EXEC msdb.dbo.sp_add_jobschedule
        @job_name = @job_name,
        @name = @schedule_name,
        @enabled = 1,
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 4,
        @freq_subday_interval = 15,
        @active_start_time = 0;
END;

IF NOT EXISTS (
    SELECT 1
    FROM msdb.dbo.sysjobservers js
    INNER JOIN msdb.dbo.sysjobs j ON j.job_id = js.job_id
    WHERE j.name = @job_name
)
BEGIN
    EXEC msdb.dbo.sp_add_jobserver
        @job_name = @job_name,
        @server_name = @server_name;
END;
