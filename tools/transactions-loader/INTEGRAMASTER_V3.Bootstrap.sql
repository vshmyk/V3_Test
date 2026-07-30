USE [INTEGRAMASTER_V3];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'CFG') IS NULL
    EXEC(N'CREATE SCHEMA CFG AUTHORIZATION dbo;');
GO

IF SCHEMA_ID(N'RT') IS NULL
    EXEC(N'CREATE SCHEMA RT AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'CFG.IntegrationClient', N'U') IS NULL
BEGIN
    CREATE TABLE CFG.IntegrationClient
    (
        ClientId INT IDENTITY(1,1) NOT NULL,
        ClientCode VARCHAR(50) NOT NULL,
        DisplayName VARCHAR(200) NULL,
        DefaultTargetDatabase SYSNAME NULL,
        DefaultSourceRoot NVARCHAR(400) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_IntegrationClient_IsActive DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationClient_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationClient_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_IntegrationClient PRIMARY KEY CLUSTERED (ClientId),
        CONSTRAINT UQ_IntegrationClient_ClientCode UNIQUE (ClientCode)
    );
END;
GO

IF OBJECT_ID(N'CFG.IntegrationFeed', N'U') IS NULL
BEGIN
    CREATE TABLE CFG.IntegrationFeed
    (
        FeedId INT IDENTITY(1,1) NOT NULL,
        ClientId INT NOT NULL,
        FeedCode VARCHAR(50) NOT NULL,
        FeedName VARCHAR(200) NULL,
        SourceType VARCHAR(50) NOT NULL CONSTRAINT DF_IntegrationFeed_SourceType DEFAULT ('ZipTrn'),
        ExecutionMode VARCHAR(50) NOT NULL CONSTRAINT DF_IntegrationFeed_ExecutionMode DEFAULT ('StatementReplay'),
        SourceRoot NVARCHAR(400) NULL,
        SourceSubdirectory NVARCHAR(200) NULL,
        FilePattern NVARCHAR(200) NULL,
        RequireCheckpointFilePresent BIT NOT NULL CONSTRAINT DF_IntegrationFeed_RequireCheckpoint DEFAULT (1),
        AllowCheckpointAdvance BIT NOT NULL CONSTRAINT DF_IntegrationFeed_AllowCheckpointAdvance DEFAULT (1),
        InitialSliceSize INT NOT NULL CONSTRAINT DF_IntegrationFeed_InitialSliceSize DEFAULT (1000),
        StopOnError BIT NOT NULL CONSTRAINT DF_IntegrationFeed_StopOnError DEFAULT (0),
        MaxRetryCount INT NOT NULL CONSTRAINT DF_IntegrationFeed_MaxRetryCount DEFAULT (3),
        TargetDatabase SYSNAME NULL,
        TargetReplayTable NVARCHAR(300) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_IntegrationFeed_IsActive DEFAULT (1),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationFeed_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationFeed_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_IntegrationFeed PRIMARY KEY CLUSTERED (FeedId),
        CONSTRAINT FK_IntegrationFeed_Client FOREIGN KEY (ClientId) REFERENCES CFG.IntegrationClient (ClientId),
        CONSTRAINT UQ_IntegrationFeed_Client_FeedCode UNIQUE (ClientId, FeedCode),
        CONSTRAINT CK_IntegrationFeed_InitialSliceSize CHECK (InitialSliceSize >= 1)
    );

    CREATE INDEX IX_IntegrationFeed_Client_IsActive
        ON CFG.IntegrationFeed (ClientId, IsActive, FeedCode);
END;
GO

IF OBJECT_ID(N'CFG.IntegrationProperty', N'U') IS NULL
BEGIN
    CREATE TABLE CFG.IntegrationProperty
    (
        PropertyId BIGINT IDENTITY(1,1) NOT NULL,
        ClientId INT NULL,
        FeedId INT NULL,
        PropertyName VARCHAR(100) NOT NULL,
        PropertyValue NVARCHAR(MAX) NULL,
        IsSecret BIT NOT NULL CONSTRAINT DF_IntegrationProperty_IsSecret DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationProperty_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationProperty_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_IntegrationProperty PRIMARY KEY CLUSTERED (PropertyId),
        CONSTRAINT FK_IntegrationProperty_Client FOREIGN KEY (ClientId) REFERENCES CFG.IntegrationClient (ClientId),
        CONSTRAINT FK_IntegrationProperty_Feed FOREIGN KEY (FeedId) REFERENCES CFG.IntegrationFeed (FeedId),
        CONSTRAINT CK_IntegrationProperty_Scope CHECK
        (
            (ClientId IS NOT NULL AND FeedId IS NULL)
            OR (FeedId IS NOT NULL)
        )
    );

    CREATE INDEX IX_IntegrationProperty_Lookup
        ON CFG.IntegrationProperty (PropertyName, FeedId, ClientId);
END;
GO

IF OBJECT_ID(N'RT.IntegrationCheckpoint', N'U') IS NULL
BEGIN
    CREATE TABLE RT.IntegrationCheckpoint
    (
        FeedId INT NOT NULL,
        CheckpointName VARCHAR(100) NOT NULL,
        CheckpointValue NVARCHAR(400) NULL,
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationCheckpoint_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedBy SYSNAME NULL,
        CONSTRAINT PK_IntegrationCheckpoint PRIMARY KEY CLUSTERED (FeedId, CheckpointName),
        CONSTRAINT FK_IntegrationCheckpoint_Feed FOREIGN KEY (FeedId) REFERENCES CFG.IntegrationFeed (FeedId)
    );
END;
GO

IF OBJECT_ID(N'RT.IntegrationInboxBatch', N'U') IS NULL
BEGIN
    CREATE TABLE RT.IntegrationInboxBatch
    (
        InboxBatchId BIGINT IDENTITY(1,1) NOT NULL,
        FeedId INT NOT NULL,
        ExternalBatchKey VARCHAR(260) NOT NULL,
        SourceFilePath NVARCHAR(600) NULL,
        SourceModifiedAt DATETIME2(0) NULL,
        SourceChecksum VARCHAR(128) NULL,
        Status VARCHAR(20) NOT NULL CONSTRAINT DF_IntegrationInboxBatch_Status DEFAULT ('Loading'),
        StatementCount INT NOT NULL CONSTRAINT DF_IntegrationInboxBatch_StatementCount DEFAULT (0),
        LoadedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationInboxBatch_LoadedAt DEFAULT (SYSUTCDATETIME()),
        ReadyAt DATETIME2(0) NULL,
        CompletedAt DATETIME2(0) NULL,
        LastRunId BIGINT NULL,
        LastError NVARCHAR(MAX) NULL,
        RetryCount INT NOT NULL CONSTRAINT DF_IntegrationInboxBatch_RetryCount DEFAULT (0),
        CheckpointAppliedAt DATETIME2(0) NULL,
        CONSTRAINT PK_IntegrationInboxBatch PRIMARY KEY CLUSTERED (InboxBatchId),
        CONSTRAINT FK_IntegrationInboxBatch_Feed FOREIGN KEY (FeedId) REFERENCES CFG.IntegrationFeed (FeedId),
        CONSTRAINT UQ_IntegrationInboxBatch_Feed_Batch UNIQUE (FeedId, ExternalBatchKey),
        CONSTRAINT CK_IntegrationInboxBatch_Status CHECK (Status IN ('Loading', 'Ready', 'Running', 'Succeeded', 'Failed', 'Poisoned'))
    );

    CREATE INDEX IX_IntegrationInboxBatch_Feed_Status
        ON RT.IntegrationInboxBatch (FeedId, Status, SourceModifiedAt, ExternalBatchKey);
END;
GO

IF OBJECT_ID(N'RT.IntegrationInboxStatement', N'U') IS NULL
BEGIN
    CREATE TABLE RT.IntegrationInboxStatement
    (
        InboxStatementId BIGINT IDENTITY(1,1) NOT NULL,
        InboxBatchId BIGINT NOT NULL,
        StatementOrdinal INT NOT NULL,
        TransactionId VARCHAR(255) NULL,
        StatementText NVARCHAR(MAX) NOT NULL,
        ExecutionStatus CHAR(1) NOT NULL CONSTRAINT DF_IntegrationInboxStatement_ExecutionStatus DEFAULT ('P'),
        ExecutionResult NVARCHAR(MAX) NULL,
        ExecutedAt DATETIME2(0) NULL,
        LastRunId BIGINT NULL,
        CONSTRAINT PK_IntegrationInboxStatement PRIMARY KEY CLUSTERED (InboxStatementId),
        CONSTRAINT FK_IntegrationInboxStatement_Batch FOREIGN KEY (InboxBatchId) REFERENCES RT.IntegrationInboxBatch (InboxBatchId),
        CONSTRAINT UQ_IntegrationInboxStatement_Batch_Ordinal UNIQUE (InboxBatchId, StatementOrdinal),
        CONSTRAINT CK_IntegrationInboxStatement_Status CHECK (ExecutionStatus IN ('P', 'S', 'F'))
    );

    CREATE INDEX IX_IntegrationInboxStatement_Batch_Status_Ordinal
        ON RT.IntegrationInboxStatement (InboxBatchId, ExecutionStatus, StatementOrdinal)
        INCLUDE (TransactionId);
END;
GO

IF OBJECT_ID(N'RT.IntegrationRun', N'U') IS NULL
BEGIN
    CREATE TABLE RT.IntegrationRun
    (
        RunId BIGINT IDENTITY(1,1) NOT NULL,
        FeedId INT NOT NULL,
        Status VARCHAR(20) NOT NULL CONSTRAINT DF_IntegrationRun_Status DEFAULT ('Running'),
        HostName SYSNAME NULL,
        AppName SYSNAME NULL,
        StartedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationRun_StartedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt DATETIME2(0) NULL,
        PendingCount INT NOT NULL CONSTRAINT DF_IntegrationRun_PendingCount DEFAULT (0),
        ProcessedCount INT NOT NULL CONSTRAINT DF_IntegrationRun_ProcessedCount DEFAULT (0),
        SucceededCount INT NOT NULL CONSTRAINT DF_IntegrationRun_SucceededCount DEFAULT (0),
        FailedCount INT NOT NULL CONSTRAINT DF_IntegrationRun_FailedCount DEFAULT (0),
        InitialSliceSize INT NOT NULL,
        StopOnError BIT NOT NULL,
        LastError NVARCHAR(MAX) NULL,
        CONSTRAINT PK_IntegrationRun PRIMARY KEY CLUSTERED (RunId),
        CONSTRAINT FK_IntegrationRun_Feed FOREIGN KEY (FeedId) REFERENCES CFG.IntegrationFeed (FeedId),
        CONSTRAINT CK_IntegrationRun_Status CHECK (Status IN ('Running', 'Succeeded', 'Failed', 'Stopped'))
    );

    CREATE INDEX IX_IntegrationRun_Feed_StartedAt
        ON RT.IntegrationRun (FeedId, StartedAt DESC);
END;
GO

IF OBJECT_ID(N'RT.IntegrationRunSlice', N'U') IS NULL
BEGIN
    CREATE TABLE RT.IntegrationRunSlice
    (
        RunSliceId BIGINT IDENTITY(1,1) NOT NULL,
        RunId BIGINT NOT NULL,
        SliceNumber INT NOT NULL,
        RangeStart INT NOT NULL,
        RangeEnd INT NOT NULL,
        StatementCount INT NOT NULL,
        Status VARCHAR(20) NOT NULL,
        ErrorText NVARCHAR(MAX) NULL,
        StartedAt DATETIME2(0) NOT NULL CONSTRAINT DF_IntegrationRunSlice_StartedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt DATETIME2(0) NULL,
        CONSTRAINT PK_IntegrationRunSlice PRIMARY KEY CLUSTERED (RunSliceId),
        CONSTRAINT FK_IntegrationRunSlice_Run FOREIGN KEY (RunId) REFERENCES RT.IntegrationRun (RunId),
        CONSTRAINT CK_IntegrationRunSlice_Status CHECK (Status IN ('Succeeded', 'Failed', 'Split'))
    );

    CREATE INDEX IX_IntegrationRunSlice_Run_SliceNumber
        ON RT.IntegrationRunSlice (RunId, SliceNumber);
END;
GO

CREATE OR ALTER FUNCTION dbo.GetIntegrationPropertyValue_V3
(
    @ClientCode VARCHAR(50),
    @FeedCode VARCHAR(50),
    @PropertyName VARCHAR(100)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Value NVARCHAR(MAX);

    SELECT TOP (1)
        @Value = p.PropertyValue
    FROM CFG.IntegrationProperty p
    INNER JOIN CFG.IntegrationFeed f
        ON f.FeedId = p.FeedId
    INNER JOIN CFG.IntegrationClient c
        ON c.ClientId = f.ClientId
    WHERE c.ClientCode = @ClientCode
      AND f.FeedCode = @FeedCode
      AND p.PropertyName = @PropertyName
    ORDER BY p.PropertyId DESC;

    IF @Value IS NOT NULL
        RETURN @Value;

    SELECT TOP (1)
        @Value = p.PropertyValue
    FROM CFG.IntegrationProperty p
    INNER JOIN CFG.IntegrationClient c
        ON c.ClientId = p.ClientId
    WHERE c.ClientCode = @ClientCode
      AND p.PropertyName = @PropertyName
    ORDER BY p.PropertyId DESC;

    RETURN @Value;
END;
GO

CREATE OR ALTER VIEW dbo.vw_IntegrationFeedRuntime_V3
AS
SELECT
    c.ClientId,
    c.ClientCode,
    c.DisplayName,
    f.FeedId,
    f.FeedCode,
    f.FeedName,
    f.SourceType,
    f.ExecutionMode,
    COALESCE(f.SourceRoot, c.DefaultSourceRoot) AS EffectiveSourceRoot,
    f.SourceSubdirectory,
    COALESCE(f.FilePattern, N'*.zip') AS EffectiveFilePattern,
    f.RequireCheckpointFilePresent,
    f.AllowCheckpointAdvance,
    f.InitialSliceSize,
    f.StopOnError,
    f.MaxRetryCount,
    COALESCE(f.TargetDatabase, c.DefaultTargetDatabase) AS EffectiveTargetDatabase,
    COALESCE(f.TargetReplayTable, N'dbo.TransactionLog') AS EffectiveTargetReplayTable,
    cp.CheckpointValue AS LastTransactionBatch,
    c.IsActive AS ClientIsActive,
    f.IsActive AS FeedIsActive
FROM CFG.IntegrationClient c
INNER JOIN CFG.IntegrationFeed f
    ON f.ClientId = c.ClientId
LEFT JOIN RT.IntegrationCheckpoint cp
    ON cp.FeedId = f.FeedId
   AND cp.CheckpointName = 'LAST_TRANSACTION_BATCH';
GO

CREATE OR ALTER VIEW dbo.vw_TransactionsLoaderCompatibility_V3
AS
SELECT
    r.ClientCode AS ClientId,
    CAST('DATASOURCE_LOCATION' AS VARCHAR(100)) AS ParmName,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(r.SourceSubdirectory)), '') IS NULL THEN r.EffectiveSourceRoot
            ELSE CONCAT(
                RTRIM(COALESCE(r.EffectiveSourceRoot, N'')),
                CASE
                    WHEN RIGHT(RTRIM(COALESCE(r.EffectiveSourceRoot, N'')), 1) IN ('\', '/') THEN N''
                    ELSE N'\'
                END,
                r.SourceSubdirectory
            )
        END
        AS NVARCHAR(400)
    ) AS ParmValue
FROM dbo.vw_IntegrationFeedRuntime_V3 r
WHERE r.ClientIsActive = 1
  AND r.FeedIsActive = 1

UNION ALL

SELECT
    r.ClientCode,
    'LAST_TRANSACTION_BATCH',
    CAST(r.LastTransactionBatch AS NVARCHAR(400))
FROM dbo.vw_IntegrationFeedRuntime_V3 r
WHERE r.ClientIsActive = 1
  AND r.FeedIsActive = 1

UNION ALL

SELECT
    r.ClientCode,
    'OASIS_DB',
    CAST(r.EffectiveTargetDatabase AS NVARCHAR(400))
FROM dbo.vw_IntegrationFeedRuntime_V3 r
WHERE r.ClientIsActive = 1
  AND r.FeedIsActive = 1;
GO

CREATE OR ALTER PROCEDURE CFG.UpsertIntegrationClient_V3
    @ClientCode VARCHAR(50),
    @DisplayName VARCHAR(200) = NULL,
    @DefaultTargetDatabase SYSNAME = NULL,
    @DefaultSourceRoot NVARCHAR(400) = NULL,
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE CFG.IntegrationClient
    SET
        DisplayName = @DisplayName,
        DefaultTargetDatabase = @DefaultTargetDatabase,
        DefaultSourceRoot = @DefaultSourceRoot,
        IsActive = @IsActive,
        UpdatedAt = SYSUTCDATETIME()
    WHERE ClientCode = @ClientCode;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO CFG.IntegrationClient
        (
            ClientCode,
            DisplayName,
            DefaultTargetDatabase,
            DefaultSourceRoot,
            IsActive
        )
        VALUES
        (
            @ClientCode,
            @DisplayName,
            @DefaultTargetDatabase,
            @DefaultSourceRoot,
            @IsActive
        );
    END;
END;
GO

CREATE OR ALTER PROCEDURE CFG.UpsertIntegrationFeed_V3
    @ClientCode VARCHAR(50),
    @FeedCode VARCHAR(50),
    @FeedName VARCHAR(200) = NULL,
    @SourceType VARCHAR(50) = 'ZipTrn',
    @ExecutionMode VARCHAR(50) = 'StatementReplay',
    @SourceRoot NVARCHAR(400) = NULL,
    @SourceSubdirectory NVARCHAR(200) = NULL,
    @FilePattern NVARCHAR(200) = N'*.zip',
    @RequireCheckpointFilePresent BIT = 1,
    @AllowCheckpointAdvance BIT = 1,
    @InitialSliceSize INT = 1000,
    @StopOnError BIT = 0,
    @MaxRetryCount INT = 3,
    @TargetDatabase SYSNAME = NULL,
    @TargetReplayTable NVARCHAR(300) = N'dbo.TransactionLog',
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientId INT;

    SELECT @ClientId = ClientId
    FROM CFG.IntegrationClient
    WHERE ClientCode = @ClientCode;

    IF @ClientId IS NULL
        THROW 51000, 'UpsertIntegrationFeed_V3: client does not exist.', 1;

    UPDATE CFG.IntegrationFeed
    SET
        FeedName = @FeedName,
        SourceType = @SourceType,
        ExecutionMode = @ExecutionMode,
        SourceRoot = @SourceRoot,
        SourceSubdirectory = @SourceSubdirectory,
        FilePattern = @FilePattern,
        RequireCheckpointFilePresent = @RequireCheckpointFilePresent,
        AllowCheckpointAdvance = @AllowCheckpointAdvance,
        InitialSliceSize = @InitialSliceSize,
        StopOnError = @StopOnError,
        MaxRetryCount = @MaxRetryCount,
        TargetDatabase = @TargetDatabase,
        TargetReplayTable = @TargetReplayTable,
        IsActive = @IsActive,
        UpdatedAt = SYSUTCDATETIME()
    WHERE ClientId = @ClientId
      AND FeedCode = @FeedCode;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO CFG.IntegrationFeed
        (
            ClientId,
            FeedCode,
            FeedName,
            SourceType,
            ExecutionMode,
            SourceRoot,
            SourceSubdirectory,
            FilePattern,
            RequireCheckpointFilePresent,
            AllowCheckpointAdvance,
            InitialSliceSize,
            StopOnError,
            MaxRetryCount,
            TargetDatabase,
            TargetReplayTable,
            IsActive
        )
        VALUES
        (
            @ClientId,
            @FeedCode,
            @FeedName,
            @SourceType,
            @ExecutionMode,
            @SourceRoot,
            @SourceSubdirectory,
            @FilePattern,
            @RequireCheckpointFilePresent,
            @AllowCheckpointAdvance,
            @InitialSliceSize,
            @StopOnError,
            @MaxRetryCount,
            @TargetDatabase,
            @TargetReplayTable,
            @IsActive
        );
    END;
END;
GO

CREATE OR ALTER PROCEDURE RT.SetIntegrationCheckpoint_V3
    @ClientCode VARCHAR(50),
    @FeedCode VARCHAR(50),
    @CheckpointName VARCHAR(100),
    @CheckpointValue NVARCHAR(400),
    @UpdatedBy SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FeedId INT;

    SELECT @FeedId = f.FeedId
    FROM CFG.IntegrationFeed f
    INNER JOIN CFG.IntegrationClient c
        ON c.ClientId = f.ClientId
    WHERE c.ClientCode = @ClientCode
      AND f.FeedCode = @FeedCode;

    IF @FeedId IS NULL
        THROW 51001, 'SetIntegrationCheckpoint_V3: feed does not exist.', 1;

    UPDATE RT.IntegrationCheckpoint
    SET
        CheckpointValue = @CheckpointValue,
        UpdatedAt = SYSUTCDATETIME(),
        UpdatedBy = COALESCE(@UpdatedBy, ORIGINAL_LOGIN())
    WHERE FeedId = @FeedId
      AND CheckpointName = @CheckpointName;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO RT.IntegrationCheckpoint
        (
            FeedId,
            CheckpointName,
            CheckpointValue,
            UpdatedAt,
            UpdatedBy
        )
        VALUES
        (
            @FeedId,
            @CheckpointName,
            @CheckpointValue,
            SYSUTCDATETIME(),
            COALESCE(@UpdatedBy, ORIGINAL_LOGIN())
        );
    END;
END;
GO

CREATE OR ALTER PROCEDURE RT.EnqueueIntegrationBatch_V3
    @ClientCode VARCHAR(50),
    @FeedCode VARCHAR(50),
    @ExternalBatchKey VARCHAR(260),
    @SourceFilePath NVARCHAR(600) = NULL,
    @SourceModifiedAt DATETIME2(0) = NULL,
    @SourceChecksum VARCHAR(128) = NULL,
    @InboxBatchId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FeedId INT;

    SELECT @FeedId = f.FeedId
    FROM CFG.IntegrationFeed f
    INNER JOIN CFG.IntegrationClient c
        ON c.ClientId = f.ClientId
    WHERE c.ClientCode = @ClientCode
      AND f.FeedCode = @FeedCode;

    IF @FeedId IS NULL
        THROW 51002, 'EnqueueIntegrationBatch_V3: feed does not exist.', 1;

    SELECT @InboxBatchId = InboxBatchId
    FROM RT.IntegrationInboxBatch
    WHERE FeedId = @FeedId
      AND ExternalBatchKey = @ExternalBatchKey;

    IF @InboxBatchId IS NULL
    BEGIN
        INSERT INTO RT.IntegrationInboxBatch
        (
            FeedId,
            ExternalBatchKey,
            SourceFilePath,
            SourceModifiedAt,
            SourceChecksum
        )
        VALUES
        (
            @FeedId,
            @ExternalBatchKey,
            @SourceFilePath,
            @SourceModifiedAt,
            @SourceChecksum
        );

        SET @InboxBatchId = SCOPE_IDENTITY();
    END;
END;
GO

CREATE OR ALTER PROCEDURE RT.EnqueueIntegrationStatement_V3
    @InboxBatchId BIGINT,
    @StatementOrdinal INT,
    @TransactionId VARCHAR(255) = NULL,
    @StatementText NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM RT.IntegrationInboxBatch
        WHERE InboxBatchId = @InboxBatchId
    )
    BEGIN
        THROW 51003, 'EnqueueIntegrationStatement_V3: batch does not exist.', 1;
    END

    UPDATE RT.IntegrationInboxBatch
    SET Status = CASE WHEN Status = 'Loading' THEN 'Loading' ELSE Status END
    WHERE InboxBatchId = @InboxBatchId;

    MERGE RT.IntegrationInboxStatement AS tgt
    USING
    (
        SELECT
            @InboxBatchId AS InboxBatchId,
            @StatementOrdinal AS StatementOrdinal
    ) AS src
        ON tgt.InboxBatchId = src.InboxBatchId
       AND tgt.StatementOrdinal = src.StatementOrdinal
    WHEN MATCHED THEN
        UPDATE SET
            TransactionId = @TransactionId,
            StatementText = @StatementText
    WHEN NOT MATCHED THEN
        INSERT
        (
            InboxBatchId,
            StatementOrdinal,
            TransactionId,
            StatementText
        )
        VALUES
        (
            @InboxBatchId,
            @StatementOrdinal,
            @TransactionId,
            @StatementText
        );

    UPDATE b
    SET StatementCount = x.StatementCount
    FROM RT.IntegrationInboxBatch b
    CROSS APPLY
    (
        SELECT COUNT(1) AS StatementCount
        FROM RT.IntegrationInboxStatement s
        WHERE s.InboxBatchId = b.InboxBatchId
    ) x
    WHERE b.InboxBatchId = @InboxBatchId;
END;
GO

CREATE OR ALTER PROCEDURE RT.MarkIntegrationBatchReady_V3
    @InboxBatchId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE RT.IntegrationInboxBatch
    SET
        Status = 'Ready',
        ReadyAt = SYSUTCDATETIME(),
        LastError = NULL
    WHERE InboxBatchId = @InboxBatchId
      AND Status IN ('Loading', 'Failed');

    IF @@ROWCOUNT = 0
        THROW 51004, 'MarkIntegrationBatchReady_V3: batch not found or not transitionable.', 1;
END;
GO

CREATE OR ALTER PROCEDURE RT.RunIntegrationFeed_V3
    @ClientCode VARCHAR(50),
    @FeedCode VARCHAR(50),
    @MaxStatements INT = NULL,
    @InitialSliceSize INT = NULL,
    @StopOnError BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @FeedId INT,
        @TargetDatabase SYSNAME,
        @ExecutionMode VARCHAR(50),
        @EffectiveInitialSliceSize INT,
        @EffectiveStopOnError BIT,
        @RunId BIGINT,
        @LockResource NVARCHAR(200),
        @LockResult INT,
        @PendingCount INT = 0,
        @ProcessedCount INT = 0,
        @SucceededCount INT = 0,
        @FailedCount INT = 0,
        @SliceStart INT = 1,
        @SliceEnd INT,
        @WorkId INT,
        @RangeStart INT,
        @RangeEnd INT,
        @RangeSize INT,
        @Midpoint INT,
        @SliceNumber INT = 0,
        @BatchSql NVARCHAR(MAX),
        @ExecuteSql NVARCHAR(MAX),
        @ExecutionResult NVARCHAR(MAX),
        @Stopped BIT = 0;

    SELECT
        @FeedId = FeedId,
        @TargetDatabase = EffectiveTargetDatabase,
        @ExecutionMode = ExecutionMode,
        @EffectiveInitialSliceSize = COALESCE(@InitialSliceSize, InitialSliceSize),
        @EffectiveStopOnError = COALESCE(@StopOnError, StopOnError)
    FROM dbo.vw_IntegrationFeedRuntime_V3
    WHERE ClientCode = @ClientCode
      AND FeedCode = @FeedCode
      AND ClientIsActive = 1
      AND FeedIsActive = 1;

    IF @FeedId IS NULL
        THROW 51005, 'RunIntegrationFeed_V3: active client/feed not found.', 1;

    IF @ExecutionMode <> 'StatementReplay'
        THROW 51006, 'RunIntegrationFeed_V3 currently supports only StatementReplay mode.', 1;

    IF NULLIF(LTRIM(RTRIM(@TargetDatabase)), '') IS NULL
        THROW 51007, 'RunIntegrationFeed_V3: target database is missing.', 1;

    IF DB_ID(@TargetDatabase) IS NULL
        THROW 51008, 'RunIntegrationFeed_V3: target database does not exist.', 1;

    IF @EffectiveInitialSliceSize IS NULL OR @EffectiveInitialSliceSize < 1
        SET @EffectiveInitialSliceSize = 1000;

    SET @LockResource = CONCAT(N'RunIntegrationFeed_V3:', @ClientCode, N':', @FeedCode);

    EXEC @LockResult = sys.sp_getapplock
        @Resource = @LockResource,
        @LockMode = 'Exclusive',
        @LockOwner = 'Session',
        @LockTimeout = 0;

    IF @LockResult < 0
        THROW 51009, 'RunIntegrationFeed_V3: could not acquire exclusive feed lock.', 1;

    INSERT INTO RT.IntegrationRun
    (
        FeedId,
        Status,
        HostName,
        AppName,
        InitialSliceSize,
        StopOnError
    )
    VALUES
    (
        @FeedId,
        'Running',
        HOST_NAME(),
        APP_NAME(),
        @EffectiveInitialSliceSize,
        @EffectiveStopOnError
    );

    SET @RunId = SCOPE_IDENTITY();

    IF OBJECT_ID('tempdb..#Pending') IS NOT NULL
        DROP TABLE #Pending;

    CREATE TABLE #Pending
    (
        RowNum INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        InboxStatementId BIGINT NOT NULL,
        InboxBatchId BIGINT NOT NULL,
        ExternalBatchKey VARCHAR(260) NOT NULL,
        StatementOrdinal INT NOT NULL,
        TransactionId VARCHAR(255) NULL,
        StatementText NVARCHAR(MAX) NOT NULL
    );

    IF OBJECT_ID('tempdb..#WorkQueue') IS NOT NULL
        DROP TABLE #WorkQueue;

    CREATE TABLE #WorkQueue
    (
        WorkId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        RangeStart INT NOT NULL,
        RangeEnd INT NOT NULL,
        Status CHAR(1) NOT NULL DEFAULT ('P')
    );

    INSERT INTO #Pending
    (
        InboxStatementId,
        InboxBatchId,
        ExternalBatchKey,
        StatementOrdinal,
        TransactionId,
        StatementText
    )
    SELECT
        s.InboxStatementId,
        s.InboxBatchId,
        b.ExternalBatchKey,
        s.StatementOrdinal,
        s.TransactionId,
        s.StatementText
    FROM RT.IntegrationInboxBatch b
    INNER JOIN RT.IntegrationInboxStatement s
        ON s.InboxBatchId = b.InboxBatchId
    WHERE b.FeedId = @FeedId
      AND b.Status IN ('Ready', 'Running', 'Failed')
      AND s.ExecutionStatus = 'P'
      AND b.RetryCount <=
            (
                SELECT MaxRetryCount
                FROM CFG.IntegrationFeed f
                WHERE f.FeedId = @FeedId
            )
    ORDER BY
        COALESCE(b.SourceModifiedAt, b.LoadedAt),
        b.ExternalBatchKey,
        s.StatementOrdinal;

    IF @MaxStatements IS NOT NULL AND @MaxStatements > 0
    BEGIN
        DELETE FROM #Pending
        WHERE RowNum > @MaxStatements;
    END;

    SELECT @PendingCount = COUNT(1)
    FROM #Pending;

    UPDATE RT.IntegrationRun
    SET PendingCount = @PendingCount
    WHERE RunId = @RunId;

    IF @PendingCount = 0
    BEGIN
        UPDATE RT.IntegrationRun
        SET
            Status = 'Succeeded',
            EndedAt = SYSUTCDATETIME()
        WHERE RunId = @RunId;

        SELECT
            @RunId AS RunId,
            @ClientCode AS ClientCode,
            @FeedCode AS FeedCode,
            @PendingCount AS PendingCount,
            @ProcessedCount AS ProcessedCount,
            @SucceededCount AS SucceededCount,
            @FailedCount AS FailedCount,
            CAST(0 AS BIT) AS StoppedOnError;
        RETURN;
    END;

    UPDATE b
    SET
        Status = 'Running',
        LastRunId = @RunId,
        LastError = NULL
    FROM RT.IntegrationInboxBatch b
    WHERE EXISTS
    (
        SELECT 1
        FROM #Pending p
        WHERE p.InboxBatchId = b.InboxBatchId
    );

    WHILE @SliceStart <= @PendingCount
    BEGIN
        SET @SliceEnd = CASE
            WHEN @SliceStart + @EffectiveInitialSliceSize - 1 < @PendingCount THEN @SliceStart + @EffectiveInitialSliceSize - 1
            ELSE @PendingCount
        END;

        INSERT INTO #WorkQueue (RangeStart, RangeEnd)
        VALUES (@SliceStart, @SliceEnd);

        SET @SliceStart = @SliceEnd + 1;
    END;

    WHILE EXISTS (SELECT 1 FROM #WorkQueue WHERE Status = 'P')
    BEGIN
        SELECT TOP (1)
            @WorkId = WorkId,
            @RangeStart = RangeStart,
            @RangeEnd = RangeEnd
        FROM #WorkQueue
        WHERE Status = 'P'
        ORDER BY WorkId;

        UPDATE #WorkQueue
        SET Status = 'R'
        WHERE WorkId = @WorkId;

        SET @SliceNumber += 1;
        SET @ExecutionResult = N'OK';
        SET @RangeSize = @RangeEnd - @RangeStart + 1;

        SELECT @BatchSql =
            STUFF((
                SELECT
                    CHAR(10) + CASE WHEN p.RowNum > @RangeStart THEN N';' ELSE N'' END + CHAR(10) + p.StatementText
                FROM #Pending p
                WHERE p.RowNum BETWEEN @RangeStart AND @RangeEnd
                ORDER BY p.RowNum
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, N'');

        BEGIN TRY
            BEGIN TRANSACTION;

            SET @ExecuteSql =
                N'USE ' + QUOTENAME(@TargetDatabase) + N'; SET NOCOUNT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; '
                + @BatchSql + N';';

            EXEC sys.sp_executesql @ExecuteSql;

            COMMIT TRANSACTION;

            UPDATE s
            SET
                ExecutionStatus = 'S',
                ExecutionResult = N'OK',
                ExecutedAt = SYSUTCDATETIME(),
                LastRunId = @RunId
            FROM RT.IntegrationInboxStatement s
            INNER JOIN #Pending p
                ON p.InboxStatementId = s.InboxStatementId
            WHERE p.RowNum BETWEEN @RangeStart AND @RangeEnd;

            INSERT INTO RT.IntegrationRunSlice
            (
                RunId,
                SliceNumber,
                RangeStart,
                RangeEnd,
                StatementCount,
                Status,
                StartedAt,
                EndedAt
            )
            VALUES
            (
                @RunId,
                @SliceNumber,
                @RangeStart,
                @RangeEnd,
                @RangeSize,
                'Succeeded',
                SYSUTCDATETIME(),
                SYSUTCDATETIME()
            );

            SET @ProcessedCount += @RangeSize;
            SET @SucceededCount += @RangeSize;

            UPDATE #WorkQueue
            SET Status = 'S'
            WHERE WorkId = @WorkId;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;

            SET @ExecutionResult =
                CONCAT(
                    N'ERROR ',
                    ERROR_NUMBER(),
                    N' (severity ',
                    ERROR_SEVERITY(),
                    N', state ',
                    ERROR_STATE(),
                    N', line ',
                    ERROR_LINE(),
                    N'): ',
                    ERROR_MESSAGE()
                );

            IF @RangeSize = 1
            BEGIN
                UPDATE s
                SET
                    ExecutionStatus = 'F',
                    ExecutionResult = @ExecutionResult,
                    ExecutedAt = SYSUTCDATETIME(),
                    LastRunId = @RunId
                FROM RT.IntegrationInboxStatement s
                INNER JOIN #Pending p
                    ON p.InboxStatementId = s.InboxStatementId
                WHERE p.RowNum BETWEEN @RangeStart AND @RangeEnd;

                INSERT INTO RT.IntegrationRunSlice
                (
                    RunId,
                    SliceNumber,
                    RangeStart,
                    RangeEnd,
                    StatementCount,
                    Status,
                    ErrorText,
                    StartedAt,
                    EndedAt
                )
                VALUES
                (
                    @RunId,
                    @SliceNumber,
                    @RangeStart,
                    @RangeEnd,
                    1,
                    'Failed',
                    @ExecutionResult,
                    SYSUTCDATETIME(),
                    SYSUTCDATETIME()
                );

                SET @ProcessedCount += 1;
                SET @FailedCount += 1;

                UPDATE #WorkQueue
                SET Status = 'F'
                WHERE WorkId = @WorkId;

                IF @EffectiveStopOnError = 1
                BEGIN
                    SET @Stopped = 1;
                    BREAK;
                END;
            END
            ELSE
            BEGIN
                SET @Midpoint = @RangeStart + ((@RangeEnd - @RangeStart) / 2);

                INSERT INTO #WorkQueue (RangeStart, RangeEnd)
                VALUES (@RangeStart, @Midpoint),
                       (@Midpoint + 1, @RangeEnd);

                INSERT INTO RT.IntegrationRunSlice
                (
                    RunId,
                    SliceNumber,
                    RangeStart,
                    RangeEnd,
                    StatementCount,
                    Status,
                    ErrorText,
                    StartedAt,
                    EndedAt
                )
                VALUES
                (
                    @RunId,
                    @SliceNumber,
                    @RangeStart,
                    @RangeEnd,
                    @RangeSize,
                    'Split',
                    @ExecutionResult,
                    SYSUTCDATETIME(),
                    SYSUTCDATETIME()
                );

                UPDATE #WorkQueue
                SET Status = 'B'
                WHERE WorkId = @WorkId;
            END;
        END CATCH;
    END;

    UPDATE b
    SET
        Status = CASE
            WHEN EXISTS
                 (
                     SELECT 1
                     FROM RT.IntegrationInboxStatement s
                     WHERE s.InboxBatchId = b.InboxBatchId
                       AND s.ExecutionStatus = 'F'
                 ) THEN
                    CASE WHEN b.RetryCount + 1 > f.MaxRetryCount THEN 'Poisoned' ELSE 'Failed' END
            WHEN EXISTS
                 (
                     SELECT 1
                     FROM RT.IntegrationInboxStatement s
                     WHERE s.InboxBatchId = b.InboxBatchId
                       AND s.ExecutionStatus = 'P'
                 ) THEN 'Ready'
            ELSE 'Succeeded'
        END,
        CompletedAt = CASE
            WHEN NOT EXISTS
                 (
                     SELECT 1
                     FROM RT.IntegrationInboxStatement s
                     WHERE s.InboxBatchId = b.InboxBatchId
                       AND s.ExecutionStatus = 'P'
                 ) THEN SYSUTCDATETIME()
            ELSE NULL
        END,
        LastRunId = @RunId,
        LastError = CASE
            WHEN EXISTS
                 (
                     SELECT 1
                     FROM RT.IntegrationInboxStatement s
                     WHERE s.InboxBatchId = b.InboxBatchId
                       AND s.ExecutionStatus = 'F'
                 ) THEN 'One or more statements failed during replay.'
            ELSE NULL
        END,
        RetryCount = CASE
            WHEN EXISTS
                 (
                     SELECT 1
                     FROM RT.IntegrationInboxStatement s
                     WHERE s.InboxBatchId = b.InboxBatchId
                       AND s.ExecutionStatus = 'F'
                 ) THEN b.RetryCount + 1
            ELSE b.RetryCount
        END
    FROM RT.IntegrationInboxBatch b
    INNER JOIN CFG.IntegrationFeed f
        ON f.FeedId = b.FeedId
    WHERE b.FeedId = @FeedId
      AND EXISTS
      (
          SELECT 1
          FROM #Pending p
          WHERE p.InboxBatchId = b.InboxBatchId
      );

    IF EXISTS
    (
        SELECT 1
        FROM CFG.IntegrationFeed f
        WHERE f.FeedId = @FeedId
          AND f.AllowCheckpointAdvance = 1
    )
    BEGIN
        ;WITH LatestSucceeded AS
        (
            SELECT TOP (1)
                b.ExternalBatchKey
            FROM RT.IntegrationInboxBatch b
            WHERE b.FeedId = @FeedId
              AND b.Status = 'Succeeded'
            ORDER BY COALESCE(b.SourceModifiedAt, b.LoadedAt) DESC, b.InboxBatchId DESC
        )
        MERGE RT.IntegrationCheckpoint AS tgt
        USING
        (
            SELECT
                @FeedId AS FeedId,
                CAST('LAST_TRANSACTION_BATCH' AS VARCHAR(100)) AS CheckpointName,
                ls.ExternalBatchKey AS CheckpointValue
            FROM LatestSucceeded ls
        ) AS src
            ON tgt.FeedId = src.FeedId
           AND tgt.CheckpointName = src.CheckpointName
        WHEN MATCHED THEN
            UPDATE SET
                CheckpointValue = src.CheckpointValue,
                UpdatedAt = SYSUTCDATETIME(),
                UpdatedBy = ORIGINAL_LOGIN()
        WHEN NOT MATCHED THEN
            INSERT
            (
                FeedId,
                CheckpointName,
                CheckpointValue,
                UpdatedAt,
                UpdatedBy
            )
            VALUES
            (
                src.FeedId,
                src.CheckpointName,
                src.CheckpointValue,
                SYSUTCDATETIME(),
                ORIGINAL_LOGIN()
            );

        UPDATE b
        SET CheckpointAppliedAt = SYSUTCDATETIME()
        FROM RT.IntegrationInboxBatch b
        WHERE b.FeedId = @FeedId
          AND b.Status = 'Succeeded'
          AND b.CheckpointAppliedAt IS NULL;
    END;

    UPDATE RT.IntegrationRun
    SET
        Status = CASE
            WHEN @Stopped = 1 THEN 'Stopped'
            WHEN @FailedCount > 0 THEN 'Failed'
            ELSE 'Succeeded'
        END,
        EndedAt = SYSUTCDATETIME(),
        ProcessedCount = @ProcessedCount,
        SucceededCount = @SucceededCount,
        FailedCount = @FailedCount,
        LastError = CASE WHEN @FailedCount > 0 THEN 'Replay completed with one or more failed statements.' ELSE NULL END
    WHERE RunId = @RunId;

    SELECT
        @RunId AS RunId,
        @ClientCode AS ClientCode,
        @FeedCode AS FeedCode,
        @PendingCount AS PendingCount,
        @ProcessedCount AS ProcessedCount,
        @SucceededCount AS SucceededCount,
        @FailedCount AS FailedCount,
        CAST(@Stopped AS BIT) AS StoppedOnError;
END;
GO

/*
Example bootstrap for the current transaction replay use case:

EXEC CFG.UpsertIntegrationClient_V3
    @ClientCode = 'PLS',
    @DisplayName = 'PLS',
    @DefaultTargetDatabase = 'OASIS_PLS',
    @DefaultSourceRoot = '\\server\share\PLS';

EXEC CFG.UpsertIntegrationFeed_V3
    @ClientCode = 'PLS',
    @FeedCode = 'TRANSACTIONS',
    @FeedName = 'PLS transaction replay',
    @SourceType = 'ZipTrn',
    @ExecutionMode = 'StatementReplay',
    @SourceSubdirectory = 'Logs',
    @FilePattern = '*.zip',
    @InitialSliceSize = 1000,
    @TargetReplayTable = 'dbo.TransactionLog';

EXEC RT.SetIntegrationCheckpoint_V3
    @ClientCode = 'PLS',
    @FeedCode = 'TRANSACTIONS',
    @CheckpointName = 'LAST_TRANSACTION_BATCH',
    @CheckpointValue = 'pls_20260618_235959';
*/
