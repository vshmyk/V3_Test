# AOtransact SQL Anywhere

This project is the starting point for a SQL Anywhere transaction-log extractor.

Important clarification:
- The utility set in `E:\ASE\Bin64` is SQL Anywhere tooling, not SAP ASE server tooling.
- `dbtran.exe` already translates the transaction log into SQL/DML.
- Because of that, the correct architecture here is to build around `dbtran`, not to reverse-engineer raw log pages first.

Current runner capabilities:
- reads a JSON config
- invokes `dbtran.exe`
- supports table filters (`-it`)
- supports include/exclude user filters (`-u`, `-x`)
- writes raw SQL output
- writes normalized JSON transaction output
- writes an AOtransact-style `.trn` file
- writes a small result JSON summary

Example run:

```powershell
dotnet run --project .\tools\sqlany-log\aotransact-sqlany-runner\AOtransact.SqlAnywhere.Runner.csproj -- --config .\tools\sqlany-log\sqlany.runner.config.sample.json
```

Normalized output shape:
- transaction_count
- statement_count
- insert_count / update_count / delete_count
- list of tables seen
- transaction list with statement tags and SQL text

TRN output:
- one DML statement block per parsed statement
- original `dbtran` statement tag preserved in header
- `GO` batch separators
- intended as the first bridge into AOtransact replay format

Next milestones:
1. collapse related statements into user-facing logical transactions
2. add checkpoint/state support for incremental runs
3. suppress system/noise tables and keep user DML only
4. add AOtransact `.trn` emitter for SQL Anywhere
5. add service/loop mode if needed
