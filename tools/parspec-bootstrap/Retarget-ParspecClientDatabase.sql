SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @TargetDatabaseName SYSNAME = N'$(TargetDatabaseName)';
DECLARE @TemplateDatabaseName SYSNAME = N'$(TemplateDatabaseName)';
DECLARE @RawDatabaseName SYSNAME = N'$(RawDatabaseName)';
DECLARE @OrgName VARCHAR(100) = N'$(OrgName)';

IF OBJECT_ID(N'dbo.ParspecBootstrapConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ParspecBootstrapConfig
    (
        BootstrapConfigId INT IDENTITY(1,1) NOT NULL,
        OrgName VARCHAR(100) NOT NULL,
        TemplateDatabaseName SYSNAME NOT NULL,
        RawDatabaseName SYSNAME NOT NULL,
        TargetDatabaseName SYSNAME NOT NULL,
        BootstrapedAtUtc DATETIME2(0) NOT NULL,
        BootstrapMode VARCHAR(40) NOT NULL,
        CONSTRAINT PK_ParspecBootstrapConfig PRIMARY KEY CLUSTERED (BootstrapConfigId)
    );
END;

IF OBJECT_ID(N'dbo.ParspecModuleReferenceInventory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ParspecModuleReferenceInventory
    (
        ModuleReferenceInventoryId BIGINT IDENTITY(1,1) NOT NULL,
        CapturedAtUtc DATETIME2(0) NOT NULL,
        SchemaName SYSNAME NOT NULL,
        ObjectName SYSNAME NOT NULL,
        ObjectType VARCHAR(60) NOT NULL,
        ReferencesTemplateDb BIT NOT NULL,
        ReferencesRawTemplateDb BIT NOT NULL,
        DefinitionSnippet NVARCHAR(1000) NULL,
        CONSTRAINT PK_ParspecModuleReferenceInventory PRIMARY KEY CLUSTERED (ModuleReferenceInventoryId)
    );
END;

DELETE FROM dbo.ParspecBootstrapConfig;

INSERT INTO dbo.ParspecBootstrapConfig
(
    OrgName,
    TemplateDatabaseName,
    RawDatabaseName,
    TargetDatabaseName,
    BootstrapedAtUtc,
    BootstrapMode
)
VALUES
(
    @OrgName,
    @TemplateDatabaseName,
    @RawDatabaseName,
    @TargetDatabaseName,
    SYSUTCDATETIME(),
    'baseline'
);

TRUNCATE TABLE dbo.ParspecModuleReferenceInventory;

INSERT INTO dbo.ParspecModuleReferenceInventory
(
    CapturedAtUtc,
    SchemaName,
    ObjectName,
    ObjectType,
    ReferencesTemplateDb,
    ReferencesRawTemplateDb,
    DefinitionSnippet
)
SELECT
    SYSUTCDATETIME(),
    s.name,
    o.name,
    o.type_desc,
    CASE WHEN LOWER(m.definition) LIKE '%' + LOWER(@TemplateDatabaseName) + '%' THEN 1 ELSE 0 END,
    CASE WHEN LOWER(m.definition) LIKE '%' + LOWER(@RawDatabaseName) + '%' OR LOWER(m.definition) LIKE '%oasis_macsii%' THEN 1 ELSE 0 END,
    LEFT(REPLACE(REPLACE(m.definition, CHAR(13), ' '), CHAR(10), ' '), 1000)
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE LOWER(m.definition) LIKE '%oasis_macsii%'
   OR LOWER(m.definition) LIKE '%' + LOWER(@TemplateDatabaseName) + '%';

SELECT
    OrgName,
    TemplateDatabaseName,
    RawDatabaseName,
    TargetDatabaseName,
    BootstrapedAtUtc,
    BootstrapMode
FROM dbo.ParspecBootstrapConfig;

SELECT
    SchemaName,
    ObjectName,
    ObjectType,
    ReferencesTemplateDb,
    ReferencesRawTemplateDb
FROM dbo.ParspecModuleReferenceInventory
ORDER BY SchemaName, ObjectType, ObjectName;
