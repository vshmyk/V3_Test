USE [INTEGRAMASTER_V3];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'CFG') IS NULL
    EXEC(N'CREATE SCHEMA CFG AUTHORIZATION dbo;');
GO

IF SCHEMA_ID(N'DEF') IS NULL
    EXEC(N'CREATE SCHEMA DEF AUTHORIZATION dbo;');
GO

IF SCHEMA_ID(N'RT') IS NULL
    EXEC(N'CREATE SCHEMA RT AUTHORIZATION dbo;');
GO

IF SCHEMA_ID(N'LEGACY') IS NULL
    EXEC(N'CREATE SCHEMA LEGACY AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'CFG.Client', N'U') IS NULL
BEGIN
    CREATE TABLE CFG.Client
    (
        ClientId INT IDENTITY(1,1) NOT NULL,
        ClientCode VARCHAR(50) NOT NULL,
        DisplayName VARCHAR(200) NULL,
        SourceDatabaseName SYSNAME NULL,
        DestinationPlatform VARCHAR(50) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_CFG_Client_IsActive DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_CFG_Client_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_CFG_Client_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_CFG_Client PRIMARY KEY CLUSTERED (ClientId),
        CONSTRAINT UQ_CFG_Client_ClientCode UNIQUE (ClientCode)
    );
END;
GO

IF OBJECT_ID(N'CFG.ConnectionProfile', N'U') IS NULL
BEGIN
    CREATE TABLE CFG.ConnectionProfile
    (
        ConnectionProfileId INT IDENTITY(1,1) NOT NULL,
        ClientId INT NOT NULL,
        ProfileCode VARCHAR(50) NOT NULL,
        ProfileType VARCHAR(50) NOT NULL,
        ServerName SYSNAME NULL,
        DatabaseName SYSNAME NULL,
        LinkedServerName SYSNAME NULL,
        EndpointBaseUrl NVARCHAR(1000) NULL,
        CredentialReference NVARCHAR(400) NULL,
        IsDefault BIT NOT NULL CONSTRAINT DF_CFG_ConnectionProfile_IsDefault DEFAULT (0),
        IsActive BIT NOT NULL CONSTRAINT DF_CFG_ConnectionProfile_IsActive DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_CFG_ConnectionProfile_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_CFG_ConnectionProfile_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_CFG_ConnectionProfile PRIMARY KEY CLUSTERED (ConnectionProfileId),
        CONSTRAINT FK_CFG_ConnectionProfile_Client FOREIGN KEY (ClientId) REFERENCES CFG.Client (ClientId),
        CONSTRAINT UQ_CFG_ConnectionProfile_Client_ProfileCode UNIQUE (ClientId, ProfileCode)
    );
END;
GO

IF OBJECT_ID(N'CFG.RuntimeSetting', N'U') IS NULL
BEGIN
    CREATE TABLE CFG.RuntimeSetting
    (
        RuntimeSettingId BIGINT IDENTITY(1,1) NOT NULL,
        ClientId INT NOT NULL,
        ObjectDefId INT NULL,
        SettingName VARCHAR(100) NOT NULL,
        SettingValue NVARCHAR(MAX) NULL,
        IsSecret BIT NOT NULL CONSTRAINT DF_CFG_RuntimeSetting_IsSecret DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_CFG_RuntimeSetting_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_CFG_RuntimeSetting_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_CFG_RuntimeSetting PRIMARY KEY CLUSTERED (RuntimeSettingId),
        CONSTRAINT FK_CFG_RuntimeSetting_Client FOREIGN KEY (ClientId) REFERENCES CFG.Client (ClientId)
    );

    CREATE INDEX IX_CFG_RuntimeSetting_Client_Object_Name
        ON CFG.RuntimeSetting (ClientId, ObjectDefId, SettingName);
END;
GO

IF OBJECT_ID(N'DEF.ObjectDefinition', N'U') IS NULL
BEGIN
    CREATE TABLE DEF.ObjectDefinition
    (
        ObjectDefId INT IDENTITY(1,1) NOT NULL,
        ClientId INT NOT NULL,
        ObjectCode VARCHAR(80) NOT NULL,
        DisplayName VARCHAR(200) NULL,
        SourceDefinition NVARCHAR(MAX) NULL,
        SourceStageTable SYSNAME NULL,
        SourceTableName SYSNAME NULL,
        AoTableName SYSNAME NULL,
        DestinationObjectName VARCHAR(120) NULL,
        TransactionMask VARCHAR(10) NULL,
        SortOrder INT NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_SortOrder DEFAULT (1000),
        BatchSize INT NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_BatchSize DEFAULT (200),
        SyncDelayMinutes INT NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_SyncDelay DEFAULT (0),
        RetrieveNewDestination BIT NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_RetrieveNewDestination DEFAULT (0),
        RestrictOnReload BIT NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_RestrictOnReload DEFAULT (0),
        ResultSetDefinition NVARCHAR(MAX) NULL,
        SourceConstraintSql NVARCHAR(MAX) NULL,
        DestinationConstraintSql NVARCHAR(MAX) NULL,
        DataSourceParameter NVARCHAR(255) NULL,
        UpdateProcessorName NVARCHAR(255) NULL,
        PreUpdateProcessorName NVARCHAR(255) NULL,
        PreAoUpdateProcessorName NVARCHAR(255) NULL,
        UpdateTriggerName NVARCHAR(255) NULL,
        SourcePostInitName NVARCHAR(255) NULL,
        AoPostInitName NVARCHAR(255) NULL,
        LegacyAoObjectHash BINARY(32) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_IsActive DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DEF_ObjectDefinition_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DEF_ObjectDefinition PRIMARY KEY CLUSTERED (ObjectDefId),
        CONSTRAINT FK_DEF_ObjectDefinition_Client FOREIGN KEY (ClientId) REFERENCES CFG.Client (ClientId),
        CONSTRAINT UQ_DEF_ObjectDefinition_Client_ObjectCode UNIQUE (ClientId, ObjectCode)
    );

    CREATE INDEX IX_DEF_ObjectDefinition_Client_SortOrder
        ON DEF.ObjectDefinition (ClientId, IsActive, SortOrder, ObjectCode);
END;
GO

IF OBJECT_ID(N'DEF.ObjectDependency', N'U') IS NULL
BEGIN
    CREATE TABLE DEF.ObjectDependency
    (
        ObjectDependencyId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectDefId INT NOT NULL,
        DependsOnObjectDefId INT NOT NULL,
        DependencyType VARCHAR(30) NOT NULL CONSTRAINT DF_DEF_ObjectDependency_Type DEFAULT ('hard'),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DEF_ObjectDependency_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DEF_ObjectDependency PRIMARY KEY CLUSTERED (ObjectDependencyId),
        CONSTRAINT FK_DEF_ObjectDependency_Object FOREIGN KEY (ObjectDefId) REFERENCES DEF.ObjectDefinition (ObjectDefId),
        CONSTRAINT FK_DEF_ObjectDependency_DependsOn FOREIGN KEY (DependsOnObjectDefId) REFERENCES DEF.ObjectDefinition (ObjectDefId),
        CONSTRAINT UQ_DEF_ObjectDependency UNIQUE (ObjectDefId, DependsOnObjectDefId, DependencyType)
    );
END;
GO

IF OBJECT_ID(N'DEF.ObjectHook', N'U') IS NULL
BEGIN
    CREATE TABLE DEF.ObjectHook
    (
        ObjectHookId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectDefId INT NOT NULL,
        HookPhase VARCHAR(40) NOT NULL,
        ProcedureName NVARCHAR(255) NOT NULL,
        ExecutionOrder INT NOT NULL CONSTRAINT DF_DEF_ObjectHook_ExecutionOrder DEFAULT (1),
        IsEnabled BIT NOT NULL CONSTRAINT DF_DEF_ObjectHook_IsEnabled DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DEF_ObjectHook_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DEF_ObjectHook_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DEF_ObjectHook PRIMARY KEY CLUSTERED (ObjectHookId),
        CONSTRAINT FK_DEF_ObjectHook_Object FOREIGN KEY (ObjectDefId) REFERENCES DEF.ObjectDefinition (ObjectDefId)
    );

    CREATE INDEX IX_DEF_ObjectHook_Object_Phase_Order
        ON DEF.ObjectHook (ObjectDefId, HookPhase, ExecutionOrder);
END;
GO

IF OBJECT_ID(N'DEF.FieldMap', N'U') IS NULL
BEGIN
    CREATE TABLE DEF.FieldMap
    (
        FieldMapId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectDefId INT NOT NULL,
        FieldOrder INT NOT NULL CONSTRAINT DF_DEF_FieldMap_FieldOrder DEFAULT (1000),
        SourceFieldName NVARCHAR(800) NULL,
        DestinationFieldName VARCHAR(80) NULL,
        SourceHashExpression NVARCHAR(800) NULL,
        DestinationHashExpression NVARCHAR(800) NULL,
        SourceType VARCHAR(30) NULL,
        DestinationType VARCHAR(30) NULL,
        IsSourceKey BIT NOT NULL CONSTRAINT DF_DEF_FieldMap_IsSourceKey DEFAULT (0),
        IsDestinationKey BIT NOT NULL CONSTRAINT DF_DEF_FieldMap_IsDestinationKey DEFAULT (0),
        UpdateEnabled BIT NOT NULL CONSTRAINT DF_DEF_FieldMap_UpdateEnabled DEFAULT (1),
        IsConditionalSync BIT NOT NULL CONSTRAINT DF_DEF_FieldMap_IsConditionalSync DEFAULT (0),
        IncludeInOutbound BIT NOT NULL CONSTRAINT DF_DEF_FieldMap_IncludeInOutbound DEFAULT (1),
        SecondarySourceKey NVARCHAR(80) NULL,
        DefaultValue NVARCHAR(800) NULL,
        ComputedExpression NVARCHAR(MAX) NULL,
        AliasName VARCHAR(64) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_DEF_FieldMap_IsActive DEFAULT (1),
        LegacyMappingId INT NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DEF_FieldMap_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DEF_FieldMap_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_DEF_FieldMap PRIMARY KEY CLUSTERED (FieldMapId),
        CONSTRAINT FK_DEF_FieldMap_Object FOREIGN KEY (ObjectDefId) REFERENCES DEF.ObjectDefinition (ObjectDefId)
    );

    CREATE INDEX IX_DEF_FieldMap_Object_FieldOrder
        ON DEF.FieldMap (ObjectDefId, IsActive, FieldOrder, FieldMapId);
END;
GO

IF OBJECT_ID(N'RT.PipelineRun', N'U') IS NULL
BEGIN
    CREATE TABLE RT.PipelineRun
    (
        PipelineRunId BIGINT IDENTITY(1,1) NOT NULL,
        ClientId INT NOT NULL,
        RequestedObjects NVARCHAR(MAX) NULL,
        RefreshAo BIT NOT NULL,
        RefreshSource BIT NOT NULL,
        UpdateDestination BIT NOT NULL,
        OutputResult BIT NOT NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_RT_PipelineRun_Status DEFAULT ('Planned'),
        StartedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_PipelineRun_StartedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt DATETIME2(0) NULL,
        TriggeredBy SYSNAME NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_RT_PipelineRun PRIMARY KEY CLUSTERED (PipelineRunId),
        CONSTRAINT FK_RT_PipelineRun_Client FOREIGN KEY (ClientId) REFERENCES CFG.Client (ClientId)
    );

    CREATE INDEX IX_RT_PipelineRun_Client_StartedAt
        ON RT.PipelineRun (ClientId, StartedAt DESC);
END;
GO

IF OBJECT_ID(N'RT.ObjectRun', N'U') IS NULL
BEGIN
    CREATE TABLE RT.ObjectRun
    (
        ObjectRunId BIGINT IDENTITY(1,1) NOT NULL,
        PipelineRunId BIGINT NOT NULL,
        ObjectDefId INT NOT NULL,
        SortOrder INT NOT NULL,
        RequestedTransactionMask VARCHAR(10) NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_RT_ObjectRun_Status DEFAULT ('Planned'),
        SourceStatus VARCHAR(30) NULL,
        StateStatus VARCHAR(30) NULL,
        DestinationStatus VARCHAR(30) NULL,
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_RT_ObjectRun PRIMARY KEY CLUSTERED (ObjectRunId),
        CONSTRAINT FK_RT_ObjectRun_Run FOREIGN KEY (PipelineRunId) REFERENCES RT.PipelineRun (PipelineRunId),
        CONSTRAINT FK_RT_ObjectRun_Object FOREIGN KEY (ObjectDefId) REFERENCES DEF.ObjectDefinition (ObjectDefId)
    );

    CREATE INDEX IX_RT_ObjectRun_Run_SortOrder
        ON RT.ObjectRun (PipelineRunId, SortOrder, ObjectRunId);
END;
GO

IF OBJECT_ID(N'RT.ObjectRunStep', N'U') IS NULL
BEGIN
    CREATE TABLE RT.ObjectRunStep
    (
        ObjectRunStepId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectRunId BIGINT NOT NULL,
        StepCode VARCHAR(40) NOT NULL,
        ExecutionOrder INT NOT NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_RT_ObjectRunStep_Status DEFAULT ('Planned'),
        ProcedureName NVARCHAR(255) NULL,
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_RT_ObjectRunStep PRIMARY KEY CLUSTERED (ObjectRunStepId),
        CONSTRAINT FK_RT_ObjectRunStep_ObjectRun FOREIGN KEY (ObjectRunId) REFERENCES RT.ObjectRun (ObjectRunId)
    );

    CREATE INDEX IX_RT_ObjectRunStep_ObjectRun_Order
        ON RT.ObjectRunStep (ObjectRunId, ExecutionOrder, ObjectRunStepId);
END;
GO

IF OBJECT_ID(N'RT.SourceSnapshotRun', N'U') IS NULL
BEGIN
    CREATE TABLE RT.SourceSnapshotRun
    (
        SourceSnapshotRunId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectRunId BIGINT NOT NULL,
        SnapshotStatus VARCHAR(30) NOT NULL CONSTRAINT DF_RT_SourceSnapshotRun_Status DEFAULT ('Planned'),
        RowCount INT NOT NULL CONSTRAINT DF_RT_SourceSnapshotRun_RowCount DEFAULT (0),
        StartedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_SourceSnapshotRun_StartedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_RT_SourceSnapshotRun PRIMARY KEY CLUSTERED (SourceSnapshotRunId),
        CONSTRAINT FK_RT_SourceSnapshotRun_ObjectRun FOREIGN KEY (ObjectRunId) REFERENCES RT.ObjectRun (ObjectRunId)
    );
END;
GO

IF OBJECT_ID(N'RT.SourceSnapshotRow', N'U') IS NULL
BEGIN
    CREATE TABLE RT.SourceSnapshotRow
    (
        SourceSnapshotRowId BIGINT IDENTITY(1,1) NOT NULL,
        SourceSnapshotRunId BIGINT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        SourceHash VARBINARY(256) NULL,
        SourcePayloadJson NVARCHAR(MAX) NOT NULL,
        SourcePayloadCanonical NVARCHAR(MAX) NULL,
        IsDeleted BIT NOT NULL CONSTRAINT DF_RT_SourceSnapshotRow_IsDeleted DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_SourceSnapshotRow_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_RT_SourceSnapshotRow PRIMARY KEY CLUSTERED (SourceSnapshotRowId),
        CONSTRAINT FK_RT_SourceSnapshotRow_Run FOREIGN KEY (SourceSnapshotRunId) REFERENCES RT.SourceSnapshotRun (SourceSnapshotRunId)
    );

    CREATE INDEX IX_RT_SourceSnapshotRow_Run_BusinessKey
        ON RT.SourceSnapshotRow (SourceSnapshotRunId, BusinessKey);
END;
GO

IF OBJECT_ID(N'RT.ObjectState', N'U') IS NULL
BEGIN
    CREATE TABLE RT.ObjectState
    (
        ObjectStateId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectDefId INT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        DestinationId VARCHAR(64) NULL,
        CurrentSourceHash VARBINARY(256) NULL,
        CurrentDestinationHash VARBINARY(256) NULL,
        CurrentPayloadJson NVARCHAR(MAX) NULL,
        LastSnapshotRunId BIGINT NULL,
        LastSuccessfulBatchRequestId BIGINT NULL,
        LastSeenAt DATETIME2(0) NULL,
        LastAppliedAt DATETIME2(0) NULL,
        IsDeleted BIT NOT NULL CONSTRAINT DF_RT_ObjectState_IsDeleted DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_ObjectState_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_ObjectState_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_RT_ObjectState PRIMARY KEY CLUSTERED (ObjectStateId),
        CONSTRAINT FK_RT_ObjectState_Object FOREIGN KEY (ObjectDefId) REFERENCES DEF.ObjectDefinition (ObjectDefId),
        CONSTRAINT UQ_RT_ObjectState_Object_BusinessKey UNIQUE (ObjectDefId, BusinessKey)
    );
END;
GO

IF OBJECT_ID(N'RT.WorkSet', N'U') IS NULL
BEGIN
    CREATE TABLE RT.WorkSet
    (
        WorkSetId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectRunId BIGINT NOT NULL,
        TransactionType VARCHAR(10) NOT NULL,
        BatchSize INT NOT NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_RT_WorkSet_Status DEFAULT ('Planned'),
        PlannedCount INT NOT NULL CONSTRAINT DF_RT_WorkSet_PlannedCount DEFAULT (0),
        SucceededCount INT NOT NULL CONSTRAINT DF_RT_WorkSet_SucceededCount DEFAULT (0),
        FailedCount INT NOT NULL CONSTRAINT DF_RT_WorkSet_FailedCount DEFAULT (0),
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_RT_WorkSet PRIMARY KEY CLUSTERED (WorkSetId),
        CONSTRAINT FK_RT_WorkSet_ObjectRun FOREIGN KEY (ObjectRunId) REFERENCES RT.ObjectRun (ObjectRunId)
    );
END;
GO

IF OBJECT_ID(N'RT.WorkItem', N'U') IS NULL
BEGIN
    CREATE TABLE RT.WorkItem
    (
        WorkItemId BIGINT IDENTITY(1,1) NOT NULL,
        WorkSetId BIGINT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        DestinationId VARCHAR(64) NULL,
        SourceHash VARBINARY(256) NULL,
        PayloadJson NVARCHAR(MAX) NOT NULL,
        ResultStatus VARCHAR(30) NOT NULL CONSTRAINT DF_RT_WorkItem_ResultStatus DEFAULT ('Planned'),
        ResultMessage NVARCHAR(MAX) NULL,
        AttemptCount INT NOT NULL CONSTRAINT DF_RT_WorkItem_AttemptCount DEFAULT (0),
        LastAttemptAt DATETIME2(0) NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_WorkItem_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_WorkItem_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_RT_WorkItem PRIMARY KEY CLUSTERED (WorkItemId),
        CONSTRAINT FK_RT_WorkItem_WorkSet FOREIGN KEY (WorkSetId) REFERENCES RT.WorkSet (WorkSetId)
    );

    CREATE INDEX IX_RT_WorkItem_WorkSet_Status
        ON RT.WorkItem (WorkSetId, ResultStatus, WorkItemId);
END;
GO

IF OBJECT_ID(N'RT.BatchRequest', N'U') IS NULL
BEGIN
    CREATE TABLE RT.BatchRequest
    (
        BatchRequestId BIGINT IDENTITY(1,1) NOT NULL,
        WorkSetId BIGINT NOT NULL,
        BatchNumber INT NOT NULL,
        RequestPayloadJson NVARCHAR(MAX) NULL,
        ResponsePayloadJson NVARCHAR(MAX) NULL,
        TransportStatus VARCHAR(30) NOT NULL CONSTRAINT DF_RT_BatchRequest_Status DEFAULT ('Planned'),
        HttpStatusCode INT NULL,
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        ErrorMessage NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_RT_BatchRequest_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_RT_BatchRequest PRIMARY KEY CLUSTERED (BatchRequestId),
        CONSTRAINT FK_RT_BatchRequest_WorkSet FOREIGN KEY (WorkSetId) REFERENCES RT.WorkSet (WorkSetId),
        CONSTRAINT UQ_RT_BatchRequest_WorkSet_Batch UNIQUE (WorkSetId, BatchNumber)
    );
END;
GO

CREATE OR ALTER VIEW LEGACY.vw_AOobject_V2
AS
SELECT
    ao.ClientId,
    ao.ObjectName,
    ao.SortOrder,
    ao.ActiveFlag,
    ao.DataSource,
    ao.AOtable,
    ao.UpdateProcessor,
    ao.DataSourceTable,
    ao.SrcDataConstraint,
    ao.DestObject,
    ao.TransactionTypes,
    ao.destDataConstraint,
    ao.BatchSize,
    ao.RetrieveNewDest,
    ao.SourcePostInit,
    ao.O4Json,
    ao.DataSourceParameter,
    ao.SyncDelay,
    ao.RestrictOnReload,
    ao.AOPostInit,
    ao.UpdateSourceProcessor,
    ao.PreUpdateProcessor,
    ao.PreAOupdateProcessor,
    ao.LastUpdate,
    ao.ResultSet,
    ao.UpdateTrigger
FROM INTEGRAMASTER_V2.dbo.AOobject ao;
GO

CREATE OR ALTER VIEW LEGACY.vw_SyncFieldMapping_V2
AS
SELECT
    sf.Id,
    sf.ClientId,
    sf.ObjectName,
    sf.SrcField,
    sf.DestField,
    sf.SrcHashComponent,
    sf.DestHashComponent_DEL,
    sf.ActiveFlag,
    sf.SrcKey,
    sf.DestKey,
    sf.SrcOrderInHash,
    sf.DestOrderInHash,
    sf.FieldSortOrder,
    sf.UpdateFlag,
    sf.DefaultValue,
    sf.SrcColType,
    sf.DestColType,
    sf.ConditionalSync,
    sf.SrcSecondaryKey,
    sf.ComputedValue,
    sf.ToOasis,
    sf.Alias
FROM INTEGRAMASTER_V2.dbo.SyncFieldMapping sf;
GO

CREATE OR ALTER PROCEDURE CFG.UpsertClient_V3
    @ClientCode VARCHAR(50),
    @DisplayName VARCHAR(200) = NULL,
    @SourceDatabaseName SYSNAME = NULL,
    @DestinationPlatform VARCHAR(50) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE CFG.Client
    SET
        DisplayName = @DisplayName,
        SourceDatabaseName = @SourceDatabaseName,
        DestinationPlatform = @DestinationPlatform,
        IsActive = @IsActive,
        UpdatedAt = SYSUTCDATETIME()
    WHERE ClientCode = @ClientCode;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO CFG.Client
        (
            ClientCode,
            DisplayName,
            SourceDatabaseName,
            DestinationPlatform,
            IsActive
        )
        VALUES
        (
            @ClientCode,
            @DisplayName,
            @SourceDatabaseName,
            @DestinationPlatform,
            @IsActive
        );
    END;
END;
GO

CREATE OR ALTER PROCEDURE LEGACY.ImportMetadataFromV2_V3
    @ClientCode VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientId INT;
    DECLARE @SourceDatabaseName SYSNAME;

    SELECT @SourceDatabaseName = cp.ParmValue
    FROM INTEGRAMASTER_V2.dbo.ClientProperties cp
    WHERE cp.ClientId = @ClientCode
      AND cp.ParmName IN ('DBNAME', 'DB_NAME');

    EXEC CFG.UpsertClient_V3
        @ClientCode = @ClientCode,
        @DisplayName = @ClientCode,
        @SourceDatabaseName = @SourceDatabaseName,
        @DestinationPlatform = 'Salesforce',
        @IsActive = 1;

    SELECT @ClientId = ClientId
    FROM CFG.Client
    WHERE ClientCode = @ClientCode;

    MERGE DEF.ObjectDefinition AS tgt
    USING
    (
        SELECT
            @ClientId AS ClientId,
            ao.ObjectName,
            ao.DataSource,
            ao.DataSourceTable,
            ao.AOtable,
            ao.DestObject,
            ao.TransactionTypes,
            ao.SortOrder,
            ISNULL(ao.BatchSize, 200) AS BatchSize,
            ISNULL(ao.SyncDelay, 0) AS SyncDelay,
            ao.RetrieveNewDest,
            ao.RestrictOnReload,
            ao.ResultSet,
            ao.SrcDataConstraint,
            ao.destDataConstraint,
            ao.DataSourceParameter,
            ao.UpdateProcessor,
            ao.PreUpdateProcessor,
            ao.PreAOupdateProcessor,
            ao.UpdateTrigger,
            ao.SourcePostInit,
            ao.AOPostInit,
            CASE WHEN ao.ActiveFlag = 'Y' THEN 1 ELSE 0 END AS IsActive
        FROM LEGACY.vw_AOobject_V2 ao
        WHERE ao.ClientId = @ClientCode
    ) AS src
        ON tgt.ClientId = src.ClientId
       AND tgt.ObjectCode = src.ObjectName
    WHEN MATCHED THEN
        UPDATE SET
            DisplayName = src.ObjectName,
            SourceDefinition = src.DataSource,
            SourceTableName = src.DataSourceTable,
            AoTableName = src.AOtable,
            DestinationObjectName = src.DestObject,
            TransactionMask = src.TransactionTypes,
            SortOrder = src.SortOrder,
            BatchSize = src.BatchSize,
            SyncDelayMinutes = src.SyncDelay,
            RetrieveNewDestination = CASE WHEN src.RetrieveNewDest = 'Y' THEN 1 ELSE 0 END,
            RestrictOnReload = CASE WHEN src.RestrictOnReload = 'Y' THEN 1 ELSE 0 END,
            ResultSetDefinition = src.ResultSet,
            SourceConstraintSql = src.SrcDataConstraint,
            DestinationConstraintSql = src.destDataConstraint,
            DataSourceParameter = src.DataSourceParameter,
            UpdateProcessorName = src.UpdateProcessor,
            PreUpdateProcessorName = src.PreUpdateProcessor,
            PreAoUpdateProcessorName = src.PreAOupdateProcessor,
            UpdateTriggerName = src.UpdateTrigger,
            SourcePostInitName = src.SourcePostInit,
            AoPostInitName = src.AOPostInit,
            IsActive = src.IsActive,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            ClientId,
            ObjectCode,
            DisplayName,
            SourceDefinition,
            SourceTableName,
            AoTableName,
            DestinationObjectName,
            TransactionMask,
            SortOrder,
            BatchSize,
            SyncDelayMinutes,
            RetrieveNewDestination,
            RestrictOnReload,
            ResultSetDefinition,
            SourceConstraintSql,
            DestinationConstraintSql,
            DataSourceParameter,
            UpdateProcessorName,
            PreUpdateProcessorName,
            PreAoUpdateProcessorName,
            UpdateTriggerName,
            SourcePostInitName,
            AoPostInitName,
            IsActive
        )
        VALUES
        (
            src.ClientId,
            src.ObjectName,
            src.ObjectName,
            src.DataSource,
            src.DataSourceTable,
            src.AOtable,
            src.DestObject,
            src.TransactionTypes,
            src.SortOrder,
            src.BatchSize,
            src.SyncDelay,
            CASE WHEN src.RetrieveNewDest = 'Y' THEN 1 ELSE 0 END,
            CASE WHEN src.RestrictOnReload = 'Y' THEN 1 ELSE 0 END,
            src.ResultSet,
            src.SrcDataConstraint,
            src.destDataConstraint,
            src.DataSourceParameter,
            src.UpdateProcessor,
            src.PreUpdateProcessor,
            src.PreAOupdateProcessor,
            src.UpdateTrigger,
            src.SourcePostInit,
            src.AOPostInit,
            src.IsActive
        );

    MERGE DEF.FieldMap AS tgt
    USING
    (
        SELECT
            od.ObjectDefId,
            sf.Id AS LegacyMappingId,
            ISNULL(sf.FieldSortOrder, 1000) AS FieldOrder,
            sf.SrcField,
            sf.DestField,
            sf.SrcHashComponent,
            sf.DestHashComponent_DEL,
            sf.SrcColType,
            sf.DestColType,
            CASE WHEN sf.SrcKey = 'Y' THEN 1 ELSE 0 END AS IsSourceKey,
            CASE WHEN sf.DestKey = 'Y' THEN 1 ELSE 0 END AS IsDestinationKey,
            CASE WHEN ISNULL(sf.UpdateFlag, 'Y') = 'Y' THEN 1 ELSE 0 END AS UpdateEnabled,
            CASE WHEN ISNULL(sf.ConditionalSync, '') <> '' THEN 1 ELSE 0 END AS IsConditionalSync,
            CASE WHEN ISNULL(sf.ToOasis, '') = 'Y' OR ISNULL(sf.ToOasis, '') = '' THEN 1 ELSE 0 END AS IncludeInOutbound,
            sf.SrcSecondaryKey,
            sf.DefaultValue,
            sf.ComputedValue,
            sf.Alias,
            CASE WHEN sf.ActiveFlag = 'Y' THEN 1 ELSE 0 END AS IsActive
        FROM LEGACY.vw_SyncFieldMapping_V2 sf
        INNER JOIN CFG.Client c
            ON c.ClientCode = sf.ClientId
        INNER JOIN DEF.ObjectDefinition od
            ON od.ClientId = c.ClientId
           AND od.ObjectCode = sf.ObjectName
        WHERE sf.ClientId = @ClientCode
    ) AS src
        ON tgt.ObjectDefId = src.ObjectDefId
       AND tgt.LegacyMappingId = src.LegacyMappingId
    WHEN MATCHED THEN
        UPDATE SET
            FieldOrder = src.FieldOrder,
            SourceFieldName = src.SrcField,
            DestinationFieldName = src.DestField,
            SourceHashExpression = src.SrcHashComponent,
            DestinationHashExpression = src.DestHashComponent_DEL,
            SourceType = src.SrcColType,
            DestinationType = src.DestColType,
            IsSourceKey = src.IsSourceKey,
            IsDestinationKey = src.IsDestinationKey,
            UpdateEnabled = src.UpdateEnabled,
            IsConditionalSync = src.IsConditionalSync,
            IncludeInOutbound = src.IncludeInOutbound,
            SecondarySourceKey = src.SrcSecondaryKey,
            DefaultValue = src.DefaultValue,
            ComputedExpression = src.ComputedValue,
            AliasName = src.Alias,
            IsActive = src.IsActive,
            UpdatedAt = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN
        INSERT
        (
            ObjectDefId,
            FieldOrder,
            SourceFieldName,
            DestinationFieldName,
            SourceHashExpression,
            DestinationHashExpression,
            SourceType,
            DestinationType,
            IsSourceKey,
            IsDestinationKey,
            UpdateEnabled,
            IsConditionalSync,
            IncludeInOutbound,
            SecondarySourceKey,
            DefaultValue,
            ComputedExpression,
            AliasName,
            IsActive,
            LegacyMappingId
        )
        VALUES
        (
            src.ObjectDefId,
            src.FieldOrder,
            src.SrcField,
            src.DestField,
            src.SrcHashComponent,
            src.DestHashComponent_DEL,
            src.SrcColType,
            src.DestColType,
            src.IsSourceKey,
            src.IsDestinationKey,
            src.UpdateEnabled,
            src.IsConditionalSync,
            src.IncludeInOutbound,
            src.SrcSecondaryKey,
            src.DefaultValue,
            src.ComputedValue,
            src.Alias,
            src.IsActive,
            src.LegacyMappingId
        );

    DELETE h
    FROM DEF.ObjectHook h
    INNER JOIN DEF.ObjectDefinition od
        ON od.ObjectDefId = h.ObjectDefId
    INNER JOIN CFG.Client c
        ON c.ClientId = od.ClientId
    WHERE c.ClientCode = @ClientCode;

    INSERT INTO DEF.ObjectHook
    (
        ObjectDefId,
        HookPhase,
        ProcedureName,
        ExecutionOrder,
        IsEnabled
    )
    SELECT
        od.ObjectDefId,
        hook.HookPhase,
        hook.ProcedureName,
        hook.ExecutionOrder,
        1
    FROM DEF.ObjectDefinition od
    CROSS APPLY
    (
        VALUES
            ('PreObject', od.PreUpdateProcessorName, 10),
            ('SourcePostInit', od.SourcePostInitName, 20),
            ('PreAoRefresh', od.PreAoUpdateProcessorName, 30),
            ('AoPostInit', od.AoPostInitName, 40),
            ('BeforeOutbound', od.UpdateProcessorName, 50),
            ('Trigger', od.UpdateTriggerName, 60)
    ) hook(HookPhase, ProcedureName, ExecutionOrder)
    INNER JOIN CFG.Client c
        ON c.ClientId = od.ClientId
    WHERE c.ClientCode = @ClientCode
      AND NULLIF(LTRIM(RTRIM(hook.ProcedureName)), '') IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE RT.RunUpdateAll_V3
    @ClientId VARCHAR(20),
    @Objects VARCHAR(MAX) = NULL,
    @RefreshAO CHAR(1),
    @RefreshSource CHAR(1),
    @UpdateDestination CHAR(1),
    @OutputResult CHAR(1) = 'Y'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @ClientKey INT,
        @PipelineRunId BIGINT;

    SELECT @ClientKey = ClientId
    FROM CFG.Client
    WHERE ClientCode = @ClientId
      AND IsActive = 1;

    IF @ClientKey IS NULL
        THROW 52000, 'RunUpdateAll_V3: client is not registered in CFG.Client.', 1;

    INSERT INTO RT.PipelineRun
    (
        ClientId,
        RequestedObjects,
        RefreshAo,
        RefreshSource,
        UpdateDestination,
        OutputResult,
        Status,
        StartedAt,
        TriggeredBy,
        Message
    )
    VALUES
    (
        @ClientKey,
        @Objects,
        CASE WHEN @RefreshAO = 'Y' THEN 1 ELSE 0 END,
        CASE WHEN @RefreshSource = 'Y' THEN 1 ELSE 0 END,
        CASE WHEN @UpdateDestination = 'Y' THEN 1 ELSE 0 END,
        CASE WHEN @OutputResult = 'Y' THEN 1 ELSE 0 END,
        'Planned',
        SYSUTCDATETIME(),
        ORIGINAL_LOGIN(),
        'Run seeded by RT.RunUpdateAll_V3. Planning only foundation; execution pipeline not yet wired to source/destination processors.'
    );

    SET @PipelineRunId = SCOPE_IDENTITY();

    INSERT INTO RT.ObjectRun
    (
        PipelineRunId,
        ObjectDefId,
        SortOrder,
        RequestedTransactionMask,
        Status
    )
    SELECT
        @PipelineRunId,
        od.ObjectDefId,
        od.SortOrder,
        od.TransactionMask,
        'Planned'
    FROM DEF.ObjectDefinition od
    LEFT JOIN
    (
        SELECT DISTINCT LTRIM(RTRIM([value])) AS ObjectCode
        FROM STRING_SPLIT(ISNULL(@Objects, ''), ',')
        WHERE LTRIM(RTRIM([value])) <> ''
    ) req
        ON req.ObjectCode = od.ObjectCode
    WHERE od.ClientId = @ClientKey
      AND od.IsActive = 1
      AND (
            ISNULL(@Objects, '') = ''
            OR req.ObjectCode = od.ObjectCode
          )
    ORDER BY od.SortOrder, od.ObjectCode;

    INSERT INTO RT.ObjectRunStep
    (
        ObjectRunId,
        StepCode,
        ExecutionOrder,
        Status,
        ProcedureName
    )
    SELECT
        oru.ObjectRunId,
        steps.StepCode,
        steps.ExecutionOrder,
        'Planned',
        steps.ProcedureName
    FROM RT.ObjectRun oru
    INNER JOIN DEF.ObjectDefinition od
        ON od.ObjectDefId = oru.ObjectDefId
    OUTER APPLY
    (
        SELECT
            'PreObject' AS StepCode,
            10 AS ExecutionOrder,
            od.PreUpdateProcessorName AS ProcedureName
        UNION ALL
        SELECT 'RefreshSource', 20, NULL
        WHERE @RefreshSource = 'Y'
        UNION ALL
        SELECT 'SourcePostInit', 30, od.SourcePostInitName
        UNION ALL
        SELECT 'RefreshState', 40, NULL
        UNION ALL
        SELECT 'PreAoRefresh', 50, od.PreAoUpdateProcessorName
        UNION ALL
        SELECT 'AoPostInit', 60, od.AoPostInitName
        WHERE @RefreshAO = 'Y'
        UNION ALL
        SELECT 'PlanDeletes', 70, NULL
        WHERE @UpdateDestination = 'Y' AND od.TransactionMask LIKE '%D%'
        UNION ALL
        SELECT 'PlanInserts', 80, NULL
        WHERE @UpdateDestination = 'Y' AND od.TransactionMask LIKE '%I%'
        UNION ALL
        SELECT 'PlanUpdates', 90, od.UpdateProcessorName
        WHERE @UpdateDestination = 'Y' AND od.TransactionMask LIKE '%U%'
        UNION ALL
        SELECT 'DispatchBatches', 100, NULL
        WHERE @UpdateDestination = 'Y'
        UNION ALL
        SELECT 'ReconcileResults', 110, NULL
        WHERE @UpdateDestination = 'Y'
        UNION ALL
        SELECT 'FinalizeObject', 120, od.UpdateTriggerName
    ) steps
    WHERE oru.PipelineRunId = @PipelineRunId;

    UPDATE RT.PipelineRun
    SET Status = 'ReadyToExecute'
    WHERE PipelineRunId = @PipelineRunId;

    SELECT
        @PipelineRunId AS PipelineRunId,
        @ClientId AS ClientCode,
        (
            SELECT COUNT(1)
            FROM RT.ObjectRun
            WHERE PipelineRunId = @PipelineRunId
        ) AS PlannedObjectCount,
        (
            SELECT COUNT(1)
            FROM RT.ObjectRunStep s
            INNER JOIN RT.ObjectRun o
                ON o.ObjectRunId = s.ObjectRunId
            WHERE o.PipelineRunId = @PipelineRunId
        ) AS PlannedStepCount;
END;
GO

/*
Suggested bootstrap sequence for a live client:

EXEC LEGACY.ImportMetadataFromV2_V3 @ClientCode = 'PLS';

EXEC RT.RunUpdateAll_V3
    @ClientId = 'PLS',
    @Objects = NULL,
    @RefreshAO = 'Y',
    @RefreshSource = 'Y',
    @UpdateDestination = 'Y',
    @OutputResult = 'Y';
*/
