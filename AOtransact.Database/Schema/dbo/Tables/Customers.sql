CREATE TABLE [dbo].[Customers]
(
    [CustomerId] INT IDENTITY(1,1) NOT NULL,
    [ExternalId] NVARCHAR(50) NOT NULL,
    [Name] NVARCHAR(200) NOT NULL,
    [Email] NVARCHAR(320) NULL,
    [CreatedAtUtc] DATETIME2(3) NOT NULL CONSTRAINT [DF_Customers_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED ([CustomerId] ASC),
    CONSTRAINT [UQ_Customers_ExternalId] UNIQUE NONCLUSTERED ([ExternalId] ASC)
);
