# AOtransact SQL Server Project

This is a SQL Server database project based on `MSBuild.Sdk.SqlProj`.

## Prerequisites

- .NET SDK 8+
- SQL Server (local or remote)
- `sqlpackage` for DACPAC publishing

## Build

```powershell
dotnet build .\AOtransact.Database\AOtransact.Database.sqlproj
```

Build output DACPAC:

`.\AOtransact.Database\bin\Debug\net8.0\AOtransact.Database.dacpac`

## Publish

```powershell
sqlpackage /Action:Publish `
  /SourceFile:".\AOtransact.Database\bin\Debug\net8.0\AOtransact.Database.dacpac" `
  /TargetConnectionString:"Server=localhost;Database=AOtransact;Integrated Security=true;TrustServerCertificate=true;"
```

## Current Objects

- `dbo.Customers`
