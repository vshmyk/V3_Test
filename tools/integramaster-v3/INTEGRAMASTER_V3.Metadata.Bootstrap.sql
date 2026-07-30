USE [INTEGRAMASTER_V3];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'cfg') IS NULL
    EXEC(N'CREATE SCHEMA cfg AUTHORIZATION dbo;');
GO

IF SCHEMA_ID(N'meta') IS NULL
    EXEC(N'CREATE SCHEMA meta AUTHORIZATION dbo;');
GO

IF SCHEMA_ID(N'legacy') IS NULL
    EXEC(N'CREATE SCHEMA legacy AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'meta.OperationType', N'U') IS NULL
BEGIN
    CREATE TABLE meta.OperationType
    (
        OperationCode CHAR(1) NOT NULL,
        OperationName VARCHAR(40) NOT NULL,
        Description VARCHAR(200) NULL,
        CONSTRAINT PK_meta_OperationType PRIMARY KEY CLUSTERED (OperationCode),
        CONSTRAINT CK_meta_OperationType_Code CHECK (OperationCode IN ('I', 'U', 'D', 'R'))
    );

    INSERT INTO meta.OperationType (OperationCode, OperationName, Description)
    VALUES
        ('I', 'Insert', 'Create destination records'),
        ('U', 'Update', 'Update existing destination records'),
        ('D', 'Delete', 'Delete or remove destination records'),
        ('R', 'Refresh', 'Refresh-only or read-only processing');
END;
GO

IF OBJECT_ID(N'meta.HookPhaseType', N'U') IS NULL
BEGIN
    CREATE TABLE meta.HookPhaseType
    (
        HookPhaseCode VARCHAR(40) NOT NULL,
        HookPhaseName VARCHAR(80) NOT NULL,
        Description VARCHAR(200) NULL,
        ExecutionOrder INT NOT NULL,
        CONSTRAINT PK_meta_HookPhaseType PRIMARY KEY CLUSTERED (HookPhaseCode)
    );

    INSERT INTO meta.HookPhaseType (HookPhaseCode, HookPhaseName, Description, ExecutionOrder)
    VALUES
        ('PreObject', 'Pre Object', 'Runs before standard object processing', 10),
        ('RefreshSource', 'Refresh Source', 'Standard source refresh phase', 20),
        ('SourcePostLoad', 'Source Post Load', 'Runs after source stage build', 30),
        ('PreStateRefresh', 'Pre State Refresh', 'Runs before state table refresh', 40),
        ('RefreshState', 'Refresh State', 'Standard shadow-state refresh phase', 50),
        ('StatePostLoad', 'State Post Load', 'Runs after state table refresh', 60),
        ('BeforeDispatch', 'Before Dispatch', 'Runs before outbound batch dispatch', 70),
        ('AfterDispatch', 'After Dispatch', 'Runs after outbound batch dispatch', 80),
        ('FinalizeObject', 'Finalize Object', 'Final object-specific trigger or closeout step', 90);
END;
GO

IF OBJECT_ID(N'cfg.IntegrationClient', N'U') IS NULL
BEGIN
    CREATE TABLE cfg.IntegrationClient
    (
        IntegrationClientId INT IDENTITY(1,1) NOT NULL,
        ClientCode VARCHAR(50) NOT NULL,
        DisplayName VARCHAR(200) NULL,
        SourceDatabaseName SYSNAME NULL,
        DestinationPlatform VARCHAR(50) NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_cfg_IntegrationClient_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_IntegrationClient_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_IntegrationClient_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_cfg_IntegrationClient PRIMARY KEY CLUSTERED (IntegrationClientId),
        CONSTRAINT UQ_cfg_IntegrationClient_ClientCode UNIQUE (ClientCode)
    );
END;
GO

IF OBJECT_ID(N'cfg.ConnectionProfile', N'U') IS NULL
BEGIN
    CREATE TABLE cfg.ConnectionProfile
    (
        ConnectionProfileId INT IDENTITY(1,1) NOT NULL,
        IntegrationClientId INT NOT NULL,
        ProfileCode VARCHAR(50) NOT NULL,
        ConnectionType VARCHAR(30) NOT NULL,
        ServerName SYSNAME NULL,
        DatabaseName SYSNAME NULL,
        LinkedServerName SYSNAME NULL,
        BaseUrl NVARCHAR(1000) NULL,
        RootPath NVARCHAR(1000) NULL,
        CredentialReferenceName NVARCHAR(255) NULL,
        IsDefault BIT NOT NULL CONSTRAINT DF_cfg_ConnectionProfile_IsDefault DEFAULT (0),
        IsEnabled BIT NOT NULL CONSTRAINT DF_cfg_ConnectionProfile_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_ConnectionProfile_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_ConnectionProfile_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_cfg_ConnectionProfile PRIMARY KEY CLUSTERED (ConnectionProfileId),
        CONSTRAINT FK_cfg_ConnectionProfile_Client FOREIGN KEY (IntegrationClientId) REFERENCES cfg.IntegrationClient (IntegrationClientId),
        CONSTRAINT UQ_cfg_ConnectionProfile_Client_ProfileCode UNIQUE (IntegrationClientId, ProfileCode),
        CONSTRAINT CK_cfg_ConnectionProfile_ConnectionType CHECK (ConnectionType IN ('sql_database', 'linked_server', 'http_api', 'file_path'))
    );

    CREATE INDEX IX_cfg_ConnectionProfile_Client_Type
        ON cfg.ConnectionProfile (IntegrationClientId, ConnectionType, IsEnabled);
END;
GO

IF OBJECT_ID(N'cfg.ClientSetting', N'U') IS NULL
BEGIN
    CREATE TABLE cfg.ClientSetting
    (
        ClientSettingId BIGINT IDENTITY(1,1) NOT NULL,
        IntegrationClientId INT NOT NULL,
        SettingName VARCHAR(100) NOT NULL,
        SettingValue NVARCHAR(MAX) NULL,
        SettingCategory VARCHAR(40) NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_cfg_ClientSetting_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_ClientSetting_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_ClientSetting_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_cfg_ClientSetting PRIMARY KEY CLUSTERED (ClientSettingId),
        CONSTRAINT FK_cfg_ClientSetting_Client FOREIGN KEY (IntegrationClientId) REFERENCES cfg.IntegrationClient (IntegrationClientId),
        CONSTRAINT UQ_cfg_ClientSetting_Client_Setting UNIQUE (IntegrationClientId, SettingName)
    );
END;
GO

IF OBJECT_ID(N'cfg.ClientSecretReference', N'U') IS NULL
BEGIN
    CREATE TABLE cfg.ClientSecretReference
    (
        ClientSecretReferenceId BIGINT IDENTITY(1,1) NOT NULL,
        IntegrationClientId INT NOT NULL,
        SecretName VARCHAR(100) NOT NULL,
        SecretReference NVARCHAR(255) NOT NULL,
        SecretKind VARCHAR(40) NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_cfg_ClientSecretReference_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_ClientSecretReference_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_cfg_ClientSecretReference_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_cfg_ClientSecretReference PRIMARY KEY CLUSTERED (ClientSecretReferenceId),
        CONSTRAINT FK_cfg_ClientSecretReference_Client FOREIGN KEY (IntegrationClientId) REFERENCES cfg.IntegrationClient (IntegrationClientId),
        CONSTRAINT UQ_cfg_ClientSecretReference_Client_Secret UNIQUE (IntegrationClientId, SecretName)
    );
END;
GO

IF OBJECT_ID(N'meta.SyncObject', N'U') IS NULL
BEGIN
    CREATE TABLE meta.SyncObject
    (
        SyncObjectId INT IDENTITY(1,1) NOT NULL,
        IntegrationClientId INT NOT NULL,
        ObjectCode VARCHAR(80) NOT NULL,
        DisplayName VARCHAR(200) NULL,
        ExecutionOrder INT NOT NULL,
        SourceDefinitionSql NVARCHAR(MAX) NULL,
        SourceStageSchemaName SYSNAME NOT NULL CONSTRAINT DF_meta_SyncObject_SourceStageSchemaName DEFAULT ('SRC'),
        SourceStageTableName SYSNAME NULL,
        StateSchemaName SYSNAME NOT NULL CONSTRAINT DF_meta_SyncObject_StateSchemaName DEFAULT ('AO'),
        StateTableName SYSNAME NULL,
        DestinationObjectName VARCHAR(120) NULL,
        BatchSize INT NOT NULL CONSTRAINT DF_meta_SyncObject_BatchSize DEFAULT (200),
        SyncDelayMinutes INT NOT NULL CONSTRAINT DF_meta_SyncObject_SyncDelayMinutes DEFAULT (0),
        RetrieveDestinationState BIT NOT NULL CONSTRAINT DF_meta_SyncObject_RetrieveDestinationState DEFAULT (0),
        IsEnabled BIT NOT NULL CONSTRAINT DF_meta_SyncObject_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_SyncObject_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_SyncObject_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_meta_SyncObject PRIMARY KEY CLUSTERED (SyncObjectId),
        CONSTRAINT FK_meta_SyncObject_Client FOREIGN KEY (IntegrationClientId) REFERENCES cfg.IntegrationClient (IntegrationClientId),
        CONSTRAINT UQ_meta_SyncObject_Client_ObjectCode UNIQUE (IntegrationClientId, ObjectCode),
        CONSTRAINT CK_meta_SyncObject_ExecutionOrder CHECK (ExecutionOrder > 0),
        CONSTRAINT CK_meta_SyncObject_BatchSize CHECK (BatchSize > 0),
        CONSTRAINT CK_meta_SyncObject_SyncDelay CHECK (SyncDelayMinutes >= 0)
    );

    CREATE INDEX IX_meta_SyncObject_Client_Order
        ON meta.SyncObject (IntegrationClientId, IsEnabled, ExecutionOrder, ObjectCode);
END;
GO

IF OBJECT_ID(N'meta.SyncObjectOperation', N'U') IS NULL
BEGIN
    CREATE TABLE meta.SyncObjectOperation
    (
        SyncObjectOperationId BIGINT IDENTITY(1,1) NOT NULL,
        SyncObjectId INT NOT NULL,
        OperationCode CHAR(1) NOT NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_meta_SyncObjectOperation_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_SyncObjectOperation_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_meta_SyncObjectOperation PRIMARY KEY CLUSTERED (SyncObjectOperationId),
        CONSTRAINT FK_meta_SyncObjectOperation_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT FK_meta_SyncObjectOperation_Type FOREIGN KEY (OperationCode) REFERENCES meta.OperationType (OperationCode),
        CONSTRAINT UQ_meta_SyncObjectOperation_Object_Operation UNIQUE (SyncObjectId, OperationCode)
    );
END;
GO

IF OBJECT_ID(N'meta.SyncObjectHook', N'U') IS NULL
BEGIN
    CREATE TABLE meta.SyncObjectHook
    (
        SyncObjectHookId BIGINT IDENTITY(1,1) NOT NULL,
        SyncObjectId INT NOT NULL,
        HookPhaseCode VARCHAR(40) NOT NULL,
        ProcedureName NVARCHAR(255) NOT NULL,
        ExecutionOrder INT NOT NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_meta_SyncObjectHook_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_SyncObjectHook_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_SyncObjectHook_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_meta_SyncObjectHook PRIMARY KEY CLUSTERED (SyncObjectHookId),
        CONSTRAINT FK_meta_SyncObjectHook_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT FK_meta_SyncObjectHook_Phase FOREIGN KEY (HookPhaseCode) REFERENCES meta.HookPhaseType (HookPhaseCode),
        CONSTRAINT UQ_meta_SyncObjectHook_Object_Phase_Proc UNIQUE (SyncObjectId, HookPhaseCode, ProcedureName)
    );

    CREATE INDEX IX_meta_SyncObjectHook_Object_Phase_Order
        ON meta.SyncObjectHook (SyncObjectId, HookPhaseCode, ExecutionOrder);
END;
GO

IF OBJECT_ID(N'meta.SyncObjectSetting', N'U') IS NULL
BEGIN
    CREATE TABLE meta.SyncObjectSetting
    (
        SyncObjectSettingId BIGINT IDENTITY(1,1) NOT NULL,
        SyncObjectId INT NOT NULL,
        SettingName VARCHAR(100) NOT NULL,
        SettingValue NVARCHAR(MAX) NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_meta_SyncObjectSetting_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_SyncObjectSetting_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_SyncObjectSetting_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_meta_SyncObjectSetting PRIMARY KEY CLUSTERED (SyncObjectSettingId),
        CONSTRAINT FK_meta_SyncObjectSetting_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT UQ_meta_SyncObjectSetting_Object_Setting UNIQUE (SyncObjectId, SettingName)
    );
END;
GO

IF OBJECT_ID(N'meta.FieldMap', N'U') IS NULL
BEGIN
    CREATE TABLE meta.FieldMap
    (
        FieldMapId BIGINT IDENTITY(1,1) NOT NULL,
        SyncObjectId INT NOT NULL,
        LegacyMapId INT NULL,
        DisplayOrder INT NULL,
        SourceFieldName NVARCHAR(800) NULL,
        StateColumnName VARCHAR(80) NULL,
        OutboundFieldName VARCHAR(80) NULL,
        SourceHashExpression NVARCHAR(800) NULL,
        StateHashExpression NVARCHAR(800) NULL,
        SourceHashOrder INT NULL,
        StateHashOrder INT NULL,
        SourceDataType VARCHAR(30) NULL,
        StateDataType VARCHAR(30) NULL,
        IsSourceMatchKey BIT NOT NULL CONSTRAINT DF_meta_FieldMap_IsSourceMatchKey DEFAULT (0),
        IsStateMatchKey BIT NOT NULL CONSTRAINT DF_meta_FieldMap_IsStateMatchKey DEFAULT (0),
        UpdateEnabled BIT NOT NULL CONSTRAINT DF_meta_FieldMap_UpdateEnabled DEFAULT (1),
        IncludeInOutbound BIT NOT NULL CONSTRAINT DF_meta_FieldMap_IncludeInOutbound DEFAULT (1),
        SecondarySourceKeyName VARCHAR(80) NULL,
        DefaultValueExpression NVARCHAR(800) NULL,
        ComputedValueExpression NVARCHAR(MAX) NULL,
        AliasName VARCHAR(64) NULL,
        IsEnabled BIT NOT NULL CONSTRAINT DF_meta_FieldMap_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_FieldMap_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_meta_FieldMap_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_meta_FieldMap PRIMARY KEY CLUSTERED (FieldMapId),
        CONSTRAINT FK_meta_FieldMap_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT UQ_meta_FieldMap_Object_LegacyMap UNIQUE (SyncObjectId, LegacyMapId)
    );

    CREATE UNIQUE INDEX UX_meta_FieldMap_Object_DisplayOrder
        ON meta.FieldMap (SyncObjectId, DisplayOrder)
        WHERE DisplayOrder IS NOT NULL;

    CREATE INDEX IX_meta_FieldMap_Object_Order
        ON meta.FieldMap (SyncObjectId, IsEnabled, DisplayOrder, FieldMapId);
END;
GO

CREATE OR ALTER VIEW legacy.vw_ClientProperties_V2
AS
SELECT
    ClientId,
    ParmName,
    ParmValue
FROM INTEGRAMASTER_V2.dbo.ClientProperties;
GO

CREATE OR ALTER VIEW legacy.vw_AOobject_V2
AS
SELECT
    ClientId,
    ObjectName,
    SortOrder,
    ActiveFlag,
    DataSource,
    AOtable,
    UpdateProcessor,
    DataSourceTable,
    SrcDataConstraint,
    DestObject,
    TransactionTypes,
    destDataConstraint,
    BatchSize,
    RetrieveNewDest,
    SourcePostInit,
    O4Json,
    DataSourceParameter,
    SyncDelay,
    RestrictOnReload,
    AOPostInit,
    UpdateSourceProcessor,
    PreUpdateProcessor,
    PreAOupdateProcessor,
    LastUpdate,
    ResultSet,
    UpdateTrigger
FROM INTEGRAMASTER_V2.dbo.AOobject;
GO

CREATE OR ALTER VIEW legacy.vw_SyncFieldMapping_V2
AS
SELECT
    Id,
    ClientId,
    ObjectName,
    SrcField,
    DestField,
    SrcHashComponent,
    DestHashComponent_DEL,
    ActiveFlag,
    SrcKey,
    DestKey,
    SrcOrderInHash,
    DestOrderInHash,
    FieldSortOrder,
    UpdateFlag,
    DefaultValue,
    SrcColType,
    DestColType,
    ConditionalSync,
    SrcSecondaryKey,
    ComputedValue,
    ToOasis,
    Alias
FROM INTEGRAMASTER_V2.dbo.SyncFieldMapping;
GO

CREATE OR ALTER PROCEDURE legacy.ImportClientFromV2
    @ClientCode VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IntegrationClientId INT;
    DECLARE @SourceDatabaseName SYSNAME;
    DECLARE @DestinationUrl NVARCHAR(1000);
    DECLARE @LinkedServerName SYSNAME;

    SELECT TOP (1) @SourceDatabaseName = ParmValue
    FROM legacy.vw_ClientProperties_V2
    WHERE ClientId = @ClientCode
      AND ParmName IN ('DBNAME', 'DB_NAME');

    SELECT TOP (1) @DestinationUrl = ParmValue
    FROM legacy.vw_ClientProperties_V2
    WHERE ClientId = @ClientCode
      AND ParmName = 'DEST_URL';

    SELECT TOP (1) @LinkedServerName = ParmValue
    FROM legacy.vw_ClientProperties_V2
    WHERE ClientId = @ClientCode
      AND ParmName = 'LINKED_SERVER';

    MERGE cfg.IntegrationClient AS tgt
    USING
    (
        SELECT
            @ClientCode AS ClientCode,
            @ClientCode AS DisplayName,
            @SourceDatabaseName AS SourceDatabaseName,
            CASE WHEN @DestinationUrl IS NULL THEN NULL ELSE 'Salesforce' END AS DestinationPlatform
    ) AS src
        ON tgt.ClientCode = src.ClientCode
    WHEN MATCHED THEN
        UPDATE SET
            DisplayName = src.DisplayName,
            SourceDatabaseName = src.SourceDatabaseName,
            DestinationPlatform = src.DestinationPlatform,
            IsEnabled = 1,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            ClientCode,
            DisplayName,
            SourceDatabaseName,
            DestinationPlatform,
            IsEnabled
        )
        VALUES
        (
            src.ClientCode,
            src.DisplayName,
            src.SourceDatabaseName,
            src.DestinationPlatform,
            1
        );

    SELECT @IntegrationClientId = IntegrationClientId
    FROM cfg.IntegrationClient
    WHERE ClientCode = @ClientCode;

    MERGE cfg.ConnectionProfile AS tgt
    USING
    (
        SELECT
            @IntegrationClientId AS IntegrationClientId,
            CAST('SOURCE_DATABASE' AS VARCHAR(50)) AS ProfileCode,
            CAST('sql_database' AS VARCHAR(30)) AS ConnectionType,
            CAST(NULL AS SYSNAME) AS ServerName,
            @SourceDatabaseName AS DatabaseName,
            CAST(NULL AS SYSNAME) AS LinkedServerName,
            CAST(NULL AS NVARCHAR(1000)) AS BaseUrl,
            CAST(NULL AS NVARCHAR(1000)) AS RootPath
        WHERE @SourceDatabaseName IS NOT NULL
        UNION ALL
        SELECT
            @IntegrationClientId,
            'LINKED_SERVER',
            'linked_server',
            NULL,
            NULL,
            @LinkedServerName,
            NULL,
            NULL
        WHERE @LinkedServerName IS NOT NULL
        UNION ALL
        SELECT
            @IntegrationClientId,
            'DESTINATION_API',
            'http_api',
            NULL,
            NULL,
            NULL,
            @DestinationUrl,
            NULL
        WHERE @DestinationUrl IS NOT NULL
    ) AS src
        ON tgt.IntegrationClientId = src.IntegrationClientId
       AND tgt.ProfileCode = src.ProfileCode
    WHEN MATCHED THEN
        UPDATE SET
            ConnectionType = src.ConnectionType,
            DatabaseName = src.DatabaseName,
            LinkedServerName = src.LinkedServerName,
            BaseUrl = src.BaseUrl,
            RootPath = src.RootPath,
            IsEnabled = 1,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            IntegrationClientId,
            ProfileCode,
            ConnectionType,
            ServerName,
            DatabaseName,
            LinkedServerName,
            BaseUrl,
            RootPath,
            IsDefault,
            IsEnabled
        )
        VALUES
        (
            src.IntegrationClientId,
            src.ProfileCode,
            src.ConnectionType,
            src.ServerName,
            src.DatabaseName,
            src.LinkedServerName,
            src.BaseUrl,
            src.RootPath,
            1,
            1
        );

    MERGE cfg.ClientSecretReference AS tgt
    USING
    (
        SELECT
            @IntegrationClientId AS IntegrationClientId,
            ParmName AS SecretName,
            CONCAT(@ClientCode, ':', ParmName) AS SecretReference,
            CASE
                WHEN ParmName LIKE '%PASSWORD%' THEN 'password'
                WHEN ParmName LIKE '%SECRET%' THEN 'secret'
                WHEN ParmName LIKE '%TOKEN%' THEN 'token'
                ELSE 'credential'
            END AS SecretKind
        FROM legacy.vw_ClientProperties_V2
        WHERE ClientId = @ClientCode
          AND (
                ParmName LIKE '%PASSWORD%'
                OR ParmName LIKE '%SECRET%'
                OR ParmName LIKE '%TOKEN%'
              )
    ) AS src
        ON tgt.IntegrationClientId = src.IntegrationClientId
       AND tgt.SecretName = src.SecretName
    WHEN MATCHED THEN
        UPDATE SET
            SecretReference = src.SecretReference,
            SecretKind = src.SecretKind,
            IsEnabled = 1,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            IntegrationClientId,
            SecretName,
            SecretReference,
            SecretKind,
            IsEnabled
        )
        VALUES
        (
            src.IntegrationClientId,
            src.SecretName,
            src.SecretReference,
            src.SecretKind,
            1
        );

    MERGE cfg.ClientSetting AS tgt
    USING
    (
        SELECT
            @IntegrationClientId AS IntegrationClientId,
            ParmName AS SettingName,
            CAST(ParmValue AS NVARCHAR(MAX)) AS SettingValue,
            CASE
                WHEN ParmName LIKE '%PATH%' OR ParmName LIKE '%LOCATION%' OR ParmName LIKE '%FILE%' THEN 'path'
                WHEN ParmName LIKE '%URL%' THEN 'endpoint'
                ELSE 'legacy'
            END AS SettingCategory
        FROM legacy.vw_ClientProperties_V2
        WHERE ClientId = @ClientCode
          AND ParmName NOT IN
          (
              'DBNAME', 'DB_NAME', 'LINKED_SERVER', 'DEST_URL'
          )
          AND ParmName NOT LIKE '%PASSWORD%'
          AND ParmName NOT LIKE '%SECRET%'
          AND ParmName NOT LIKE '%TOKEN%'
    ) AS src
        ON tgt.IntegrationClientId = src.IntegrationClientId
       AND tgt.SettingName = src.SettingName
    WHEN MATCHED THEN
        UPDATE SET
            SettingValue = src.SettingValue,
            SettingCategory = src.SettingCategory,
            IsEnabled = 1,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            IntegrationClientId,
            SettingName,
            SettingValue,
            SettingCategory,
            IsEnabled
        )
        VALUES
        (
            src.IntegrationClientId,
            src.SettingName,
            src.SettingValue,
            src.SettingCategory,
            1
        );
END;
GO

CREATE OR ALTER PROCEDURE legacy.ImportObjectsFromV2
    @ClientCode VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IntegrationClientId INT;

    SELECT @IntegrationClientId = IntegrationClientId
    FROM cfg.IntegrationClient
    WHERE ClientCode = @ClientCode;

    IF @IntegrationClientId IS NULL
        THROW 53000, 'ImportObjectsFromV2: client must be imported first.', 1;

    ;WITH LegacyObjects AS
    (
        SELECT
            ao.ClientId,
            ao.ObjectName,
            MIN(ao.SortOrder) AS SortOrder,
            MAX(CASE WHEN ao.ActiveFlag = 'Y' THEN 1 ELSE 0 END) AS IsEnabled,
            MAX(ao.DataSource) AS DataSource,
            MAX(ao.DataSourceTable) AS DataSourceTable,
            MAX(ao.AOtable) AS AOtable,
            MAX(ao.DestObject) AS DestObject,
            MAX(ISNULL(ao.BatchSize, 200)) AS BatchSize,
            MAX(ISNULL(ao.SyncDelay, 0)) AS SyncDelay,
            MAX(CASE WHEN ao.RetrieveNewDest = 'Y' THEN 1 ELSE 0 END) AS RetrieveDestinationState
        FROM legacy.vw_AOobject_V2 ao
        WHERE ao.ClientId = @ClientCode
        GROUP BY ao.ClientId, ao.ObjectName
    )
    MERGE meta.SyncObject AS tgt
    USING
    (
        SELECT
            @IntegrationClientId AS IntegrationClientId,
            lo.ObjectName,
            lo.SortOrder,
            lo.DataSource,
            PARSENAME(lo.DataSourceTable, 2) AS SourceStageSchemaName,
            PARSENAME(lo.DataSourceTable, 1) AS SourceStageTableName,
            PARSENAME(lo.AOtable, 2) AS StateSchemaName,
            PARSENAME(lo.AOtable, 1) AS StateTableName,
            lo.DestObject,
            lo.BatchSize,
            lo.SyncDelay,
            lo.RetrieveDestinationState,
            lo.IsEnabled
        FROM LegacyObjects lo
    ) AS src
        ON tgt.IntegrationClientId = src.IntegrationClientId
       AND tgt.ObjectCode = src.ObjectName
    WHEN MATCHED THEN
        UPDATE SET
            DisplayName = src.ObjectName,
            ExecutionOrder = src.SortOrder,
            SourceDefinitionSql = src.DataSource,
            SourceStageSchemaName = ISNULL(src.SourceStageSchemaName, 'SRC'),
            SourceStageTableName = src.SourceStageTableName,
            StateSchemaName = ISNULL(src.StateSchemaName, 'AO'),
            StateTableName = src.StateTableName,
            DestinationObjectName = src.DestObject,
            BatchSize = src.BatchSize,
            SyncDelayMinutes = src.SyncDelay,
            RetrieveDestinationState = src.RetrieveDestinationState,
            IsEnabled = src.IsEnabled,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            IntegrationClientId,
            ObjectCode,
            DisplayName,
            ExecutionOrder,
            SourceDefinitionSql,
            SourceStageSchemaName,
            SourceStageTableName,
            StateSchemaName,
            StateTableName,
            DestinationObjectName,
            BatchSize,
            SyncDelayMinutes,
            RetrieveDestinationState,
            IsEnabled
        )
        VALUES
        (
            src.IntegrationClientId,
            src.ObjectName,
            src.ObjectName,
            src.SortOrder,
            src.DataSource,
            ISNULL(src.SourceStageSchemaName, 'SRC'),
            src.SourceStageTableName,
            ISNULL(src.StateSchemaName, 'AO'),
            src.StateTableName,
            src.DestObject,
            src.BatchSize,
            src.SyncDelay,
            src.RetrieveDestinationState,
            src.IsEnabled
        );

    DELETE op
    FROM meta.SyncObjectOperation op
    INNER JOIN meta.SyncObject so
        ON so.SyncObjectId = op.SyncObjectId
    INNER JOIN cfg.IntegrationClient c
        ON c.IntegrationClientId = so.IntegrationClientId
    WHERE c.ClientCode = @ClientCode;

    INSERT INTO meta.SyncObjectOperation
    (
        SyncObjectId,
        OperationCode,
        IsEnabled
    )
    SELECT DISTINCT
        so.SyncObjectId,
        ops.OperationCode,
        1
    FROM legacy.vw_AOobject_V2 ao
    INNER JOIN cfg.IntegrationClient c
        ON c.ClientCode = ao.ClientId
    INNER JOIN meta.SyncObject so
        ON so.IntegrationClientId = c.IntegrationClientId
       AND so.ObjectCode = ao.ObjectName
    CROSS APPLY
    (
        SELECT SUBSTRING(ao.TransactionTypes, v.number, 1) AS OperationCode
        FROM master.dbo.spt_values v
        WHERE v.type = 'P'
          AND v.number BETWEEN 1 AND LEN(ISNULL(ao.TransactionTypes, ''))
    ) ops
    WHERE ao.ClientId = @ClientCode
      AND ops.OperationCode IN ('I', 'U', 'D', 'R');

    DELETE h
    FROM meta.SyncObjectHook h
    INNER JOIN meta.SyncObject so
        ON so.SyncObjectId = h.SyncObjectId
    INNER JOIN cfg.IntegrationClient c
        ON c.IntegrationClientId = so.IntegrationClientId
    WHERE c.ClientCode = @ClientCode;

    INSERT INTO meta.SyncObjectHook
    (
        SyncObjectId,
        HookPhaseCode,
        ProcedureName,
        ExecutionOrder,
        IsEnabled
    )
    SELECT
        so.SyncObjectId,
        hook.HookPhaseCode,
        hook.ProcedureName,
        hook.ExecutionOrder,
        1
    FROM legacy.vw_AOobject_V2 ao
    INNER JOIN cfg.IntegrationClient c
        ON c.ClientCode = ao.ClientId
    INNER JOIN meta.SyncObject so
        ON so.IntegrationClientId = c.IntegrationClientId
       AND so.ObjectCode = ao.ObjectName
    CROSS APPLY
    (
        VALUES
            ('PreObject', ao.PreUpdateProcessor, 10),
            ('SourcePostLoad', ao.SourcePostInit, 30),
            ('PreStateRefresh', ao.PreAOupdateProcessor, 40),
            ('StatePostLoad', ao.AOPostInit, 60),
            ('BeforeDispatch', ao.UpdateSourceProcessor, 70),
            ('FinalizeObject', ao.UpdateTrigger, 90)
    ) hook(HookPhaseCode, ProcedureName, ExecutionOrder)
    WHERE ao.ClientId = @ClientCode
      AND NULLIF(LTRIM(RTRIM(hook.ProcedureName)), '') IS NOT NULL;

    MERGE meta.SyncObjectSetting AS tgt
    USING
    (
        SELECT
            so.SyncObjectId,
            opt.SettingName,
            opt.SettingValue
        FROM legacy.vw_AOobject_V2 ao
        INNER JOIN cfg.IntegrationClient c
            ON c.ClientCode = ao.ClientId
        INNER JOIN meta.SyncObject so
            ON so.IntegrationClientId = c.IntegrationClientId
           AND so.ObjectCode = ao.ObjectName
        CROSS APPLY
        (
            VALUES
                ('LEGACY_RESULT_SET', CAST(ao.ResultSet AS NVARCHAR(MAX))),
                ('LEGACY_DATA_SOURCE_PARAMETER', CAST(ao.DataSourceParameter AS NVARCHAR(MAX))),
                ('LEGACY_O4_JSON', CAST(ao.O4Json AS NVARCHAR(MAX))),
                ('LEGACY_RESTRICT_ON_RELOAD', CAST(ao.RestrictOnReload AS NVARCHAR(MAX))),
                ('LEGACY_SRC_CONSTRAINT', CAST(ao.SrcDataConstraint AS NVARCHAR(MAX))),
                ('LEGACY_DEST_CONSTRAINT', CAST(ao.destDataConstraint AS NVARCHAR(MAX))),
                ('LEGACY_UPDATE_PROCESSOR', CAST(ao.UpdateProcessor AS NVARCHAR(MAX)))
        ) opt(SettingName, SettingValue)
        WHERE ao.ClientId = @ClientCode
          AND NULLIF(LTRIM(RTRIM(opt.SettingValue)), '') IS NOT NULL
    ) AS src
        ON tgt.SyncObjectId = src.SyncObjectId
       AND tgt.SettingName = src.SettingName
    WHEN MATCHED THEN
        UPDATE SET
            SettingValue = src.SettingValue,
            IsEnabled = 1,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            SyncObjectId,
            SettingName,
            SettingValue,
            IsEnabled
        )
        VALUES
        (
            src.SyncObjectId,
            src.SettingName,
            src.SettingValue,
            1
        );
END;
GO

CREATE OR ALTER PROCEDURE legacy.ImportFieldMapsFromV2
    @ClientCode VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IntegrationClientId INT;

    SELECT @IntegrationClientId = IntegrationClientId
    FROM cfg.IntegrationClient
    WHERE ClientCode = @ClientCode;

    IF @IntegrationClientId IS NULL
        THROW 53001, 'ImportFieldMapsFromV2: client must be imported first.', 1;

    MERGE meta.FieldMap AS tgt
    USING
    (
        SELECT
            so.SyncObjectId,
            sf.Id AS LegacyMapId,
            NULLIF(sf.FieldSortOrder, 0) AS DisplayOrder,
            sf.SrcField,
            sf.DestField,
            sf.DestField AS OutboundFieldName,
            sf.SrcHashComponent,
            sf.DestHashComponent_DEL,
            NULLIF(sf.SrcOrderInHash, 0) AS SourceHashOrder,
            NULLIF(sf.DestOrderInHash, 0) AS StateHashOrder,
            sf.SrcColType,
            sf.DestColType,
            CASE WHEN sf.SrcKey = 'Y' THEN 1 ELSE 0 END AS IsSourceMatchKey,
            CASE WHEN sf.DestKey = 'Y' THEN 1 ELSE 0 END AS IsStateMatchKey,
            CASE WHEN ISNULL(sf.UpdateFlag, 'Y') = 'Y' THEN 1 ELSE 0 END AS UpdateEnabled,
            CASE WHEN ISNULL(sf.ToOasis, '') = 'N' THEN 0 ELSE 1 END AS IncludeInOutbound,
            sf.SrcSecondaryKey,
            sf.DefaultValue,
            sf.ComputedValue,
            sf.Alias,
            CASE WHEN sf.ActiveFlag = 'Y' THEN 1 ELSE 0 END AS IsEnabled
        FROM legacy.vw_SyncFieldMapping_V2 sf
        INNER JOIN cfg.IntegrationClient c
            ON c.ClientCode = sf.ClientId
        INNER JOIN meta.SyncObject so
            ON so.IntegrationClientId = c.IntegrationClientId
           AND so.ObjectCode = sf.ObjectName
        WHERE sf.ClientId = @ClientCode
    ) AS src
        ON tgt.SyncObjectId = src.SyncObjectId
       AND tgt.LegacyMapId = src.LegacyMapId
    WHEN MATCHED THEN
        UPDATE SET
            DisplayOrder = src.DisplayOrder,
            SourceFieldName = src.SrcField,
            StateColumnName = src.DestField,
            OutboundFieldName = src.OutboundFieldName,
            SourceHashExpression = src.SrcHashComponent,
            StateHashExpression = src.DestHashComponent_DEL,
            SourceHashOrder = src.SourceHashOrder,
            StateHashOrder = src.StateHashOrder,
            SourceDataType = src.SrcColType,
            StateDataType = src.DestColType,
            IsSourceMatchKey = src.IsSourceMatchKey,
            IsStateMatchKey = src.IsStateMatchKey,
            UpdateEnabled = src.UpdateEnabled,
            IncludeInOutbound = src.IncludeInOutbound,
            SecondarySourceKeyName = src.SrcSecondaryKey,
            DefaultValueExpression = src.DefaultValue,
            ComputedValueExpression = src.ComputedValue,
            AliasName = src.Alias,
            IsEnabled = src.IsEnabled,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            SyncObjectId,
            LegacyMapId,
            DisplayOrder,
            SourceFieldName,
            StateColumnName,
            OutboundFieldName,
            SourceHashExpression,
            StateHashExpression,
            SourceHashOrder,
            StateHashOrder,
            SourceDataType,
            StateDataType,
            IsSourceMatchKey,
            IsStateMatchKey,
            UpdateEnabled,
            IncludeInOutbound,
            SecondarySourceKeyName,
            DefaultValueExpression,
            ComputedValueExpression,
            AliasName,
            IsEnabled
        )
        VALUES
        (
            src.SyncObjectId,
            src.LegacyMapId,
            src.DisplayOrder,
            src.SrcField,
            src.DestField,
            src.OutboundFieldName,
            src.SrcHashComponent,
            src.DestHashComponent_DEL,
            src.SourceHashOrder,
            src.StateHashOrder,
            src.SrcColType,
            src.DestColType,
            src.IsSourceMatchKey,
            src.IsStateMatchKey,
            src.UpdateEnabled,
            src.IncludeInOutbound,
            src.SrcSecondaryKey,
            src.DefaultValue,
            src.ComputedValue,
            src.Alias,
            src.IsEnabled
        );
END;
GO

CREATE OR ALTER PROCEDURE legacy.ImportClientPackageFromV2
    @ClientCode VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC legacy.ImportClientFromV2 @ClientCode = @ClientCode;
    EXEC legacy.ImportObjectsFromV2 @ClientCode = @ClientCode;
    EXEC legacy.ImportFieldMapsFromV2 @ClientCode = @ClientCode;
END;
GO
