USE [INTEGRAMASTER_V3];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'rt') IS NULL
    EXEC(N'CREATE SCHEMA rt AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'rt.PipelineRun', N'U') IS NULL
BEGIN
    CREATE TABLE rt.PipelineRun
    (
        PipelineRunId BIGINT IDENTITY(1,1) NOT NULL,
        IntegrationClientId INT NOT NULL,
        RequestedObjectList NVARCHAR(MAX) NULL,
        RunMode VARCHAR(20) NOT NULL CONSTRAINT DF_rt_PipelineRun_RunMode DEFAULT ('plan'),
        RefreshSource BIT NOT NULL CONSTRAINT DF_rt_PipelineRun_RefreshSource DEFAULT (1),
        RefreshState BIT NOT NULL CONSTRAINT DF_rt_PipelineRun_RefreshState DEFAULT (1),
        AllowDispatch BIT NOT NULL CONSTRAINT DF_rt_PipelineRun_AllowDispatch DEFAULT (0),
        OutputDiagnostics BIT NOT NULL CONSTRAINT DF_rt_PipelineRun_OutputDiagnostics DEFAULT (1),
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_rt_PipelineRun_Status DEFAULT ('planned'),
        RequestedBy SYSNAME NULL,
        StartedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_PipelineRun_StartedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_rt_PipelineRun PRIMARY KEY CLUSTERED (PipelineRunId),
        CONSTRAINT FK_rt_PipelineRun_Client FOREIGN KEY (IntegrationClientId) REFERENCES cfg.IntegrationClient (IntegrationClientId),
        CONSTRAINT CK_rt_PipelineRun_RunMode CHECK (RunMode IN ('plan', 'execute')),
        CONSTRAINT CK_rt_PipelineRun_Status CHECK (Status IN ('planned', 'ready', 'running', 'completed', 'failed', 'cancelled'))
    );

    CREATE INDEX IX_rt_PipelineRun_Client_StartedAt
        ON rt.PipelineRun (IntegrationClientId, StartedAt DESC);
END;
GO

CREATE OR ALTER PROCEDURE rt.RebaselineObjectStateFromSourceCurrent
    @ObjectCode VARCHAR(80),
    @BusinessKey NVARCHAR(400) = NULL,
    @ApplyChanges BIT = 0,
    @OutputDiagnostics BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @SyncObjectId INT,
        @Now DATETIME2(0) = SYSUTCDATETIME(),
        @CandidateStateRowCount INT = 0,
        @MatchedSourceRowCount INT = 0,
        @AlreadyAlignedCount INT = 0,
        @WouldRebaselineCount INT = 0,
        @MissingSourceCurrentCount INT = 0,
        @AppliedRowCount INT = 0;

    SELECT
        @SyncObjectId = syncObj.SyncObjectId
    FROM meta.SyncObject syncObj
    WHERE syncObj.ObjectCode = @ObjectCode;

    IF @SyncObjectId IS NULL
        THROW 54270, 'RebaselineObjectStateFromSourceCurrent: object code was not found.', 1;

    CREATE TABLE #RebaselineCandidate
    (
        BusinessKey NVARCHAR(400) NOT NULL,
        DestinationRecordId VARCHAR(64) NULL,
        ExistingSourceHash VARBINARY(256) NULL,
        ExistingStateHash VARBINARY(256) NULL,
        ExistingPayloadJson NVARCHAR(MAX) NULL,
        CurrentSourceHash VARBINARY(256) NULL,
        CurrentPayloadJson NVARCHAR(MAX) NULL,
        HasSourceCurrent BIT NOT NULL,
        NeedsRebaseline BIT NOT NULL,
        PRIMARY KEY CLUSTERED (BusinessKey)
    );

    INSERT INTO #RebaselineCandidate
    (
        BusinessKey,
        DestinationRecordId,
        ExistingSourceHash,
        ExistingStateHash,
        ExistingPayloadJson,
        CurrentSourceHash,
        CurrentPayloadJson,
        HasSourceCurrent,
        NeedsRebaseline
    )
    SELECT
        objectState.BusinessKey,
        objectState.DestinationRecordId,
        objectState.CurrentSourceHash,
        objectState.CurrentStateHash,
        objectState.CurrentPayloadJson,
        sourceCurrent.SourceHash,
        sourceCurrent.SourcePayloadJson,
        CASE WHEN sourceCurrent.SourceCurrentId IS NULL THEN 0 ELSE 1 END,
        CASE
            WHEN sourceCurrent.SourceCurrentId IS NULL THEN 0
            WHEN
            (
                (objectState.CurrentSourceHash IS NULL AND sourceCurrent.SourceHash IS NOT NULL)
                OR (objectState.CurrentSourceHash IS NOT NULL AND sourceCurrent.SourceHash IS NULL)
                OR (objectState.CurrentSourceHash <> sourceCurrent.SourceHash)
                OR (objectState.CurrentStateHash IS NULL AND sourceCurrent.SourceHash IS NOT NULL)
                OR (objectState.CurrentStateHash IS NOT NULL AND sourceCurrent.SourceHash IS NULL)
                OR (objectState.CurrentStateHash <> sourceCurrent.SourceHash)
                OR ISNULL(objectState.CurrentPayloadJson, N'') <> ISNULL(sourceCurrent.SourcePayloadJson, N'')
            )
            THEN 1
            ELSE 0
        END
    FROM rt.ObjectState objectState
    LEFT JOIN rt.SourceCurrent sourceCurrent
        ON sourceCurrent.SyncObjectId = objectState.SyncObjectId
       AND sourceCurrent.BusinessKey = objectState.BusinessKey
    WHERE objectState.SyncObjectId = @SyncObjectId
      AND objectState.IsDeleted = 0
      AND (@BusinessKey IS NULL OR objectState.BusinessKey = @BusinessKey);

    SELECT
        @CandidateStateRowCount = COUNT(*),
        @MatchedSourceRowCount = SUM(CASE WHEN candidate.HasSourceCurrent = 1 THEN 1 ELSE 0 END),
        @AlreadyAlignedCount = SUM(CASE WHEN candidate.HasSourceCurrent = 1 AND candidate.NeedsRebaseline = 0 THEN 1 ELSE 0 END),
        @WouldRebaselineCount = SUM(CASE WHEN candidate.NeedsRebaseline = 1 THEN 1 ELSE 0 END),
        @MissingSourceCurrentCount = SUM(CASE WHEN candidate.HasSourceCurrent = 0 THEN 1 ELSE 0 END)
    FROM #RebaselineCandidate candidate;

    IF @ApplyChanges = 1
    BEGIN
        UPDATE objectState
        SET
            objectState.CurrentSourceHash = candidate.CurrentSourceHash,
            objectState.CurrentStateHash = candidate.CurrentSourceHash,
            objectState.CurrentPayloadJson = candidate.CurrentPayloadJson,
            objectState.LastSeenAt = @Now,
            objectState.UpdatedAt = @Now
        FROM rt.ObjectState objectState
        INNER JOIN #RebaselineCandidate candidate
            ON candidate.BusinessKey = objectState.BusinessKey
        WHERE objectState.SyncObjectId = @SyncObjectId
          AND objectState.IsDeleted = 0
          AND candidate.NeedsRebaseline = 1;

        SET @AppliedRowCount = @@ROWCOUNT;
    END;

    SELECT
        @ObjectCode AS ObjectCode,
        @BusinessKey AS BusinessKeyFilter,
        @ApplyChanges AS ApplyChanges,
        @CandidateStateRowCount AS CandidateStateRowCount,
        @MatchedSourceRowCount AS MatchedSourceRowCount,
        @AlreadyAlignedCount AS AlreadyAlignedCount,
        @WouldRebaselineCount AS WouldRebaselineCount,
        @MissingSourceCurrentCount AS MissingSourceCurrentCount,
        @AppliedRowCount AS AppliedRowCount,
        @Now AS EvaluatedAt;

    IF @OutputDiagnostics = 1
    BEGIN
        SELECT TOP (50)
            candidate.BusinessKey,
            candidate.DestinationRecordId,
            CASE
                WHEN candidate.HasSourceCurrent = 0 THEN 'missing_source_current'
                WHEN candidate.NeedsRebaseline = 1 THEN 'needs_rebaseline'
                ELSE 'already_aligned'
            END AS RebaselineStatus,
            CONVERT(VARCHAR(64), candidate.ExistingSourceHash, 2) AS ExistingSourceHashHex,
            CONVERT(VARCHAR(64), candidate.CurrentSourceHash, 2) AS CurrentSourceHashHex,
            JSON_VALUE(candidate.ExistingPayloadJson, '$.POnumber') AS ExistingPoNumber,
            JSON_VALUE(candidate.CurrentPayloadJson, '$.POnumber') AS CurrentPoNumber
        FROM #RebaselineCandidate candidate
        WHERE candidate.HasSourceCurrent = 0
           OR candidate.NeedsRebaseline = 1
        ORDER BY
            CASE WHEN candidate.HasSourceCurrent = 0 THEN 0 ELSE 1 END,
            candidate.BusinessKey;
    END;
END;
GO

IF OBJECT_ID(N'rt.ObjectRun', N'U') IS NULL
BEGIN
    CREATE TABLE rt.ObjectRun
    (
        ObjectRunId BIGINT IDENTITY(1,1) NOT NULL,
        PipelineRunId BIGINT NOT NULL,
        SyncObjectId INT NOT NULL,
        ExecutionOrder INT NOT NULL,
        PlannedOperationMask VARCHAR(10) NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_rt_ObjectRun_Status DEFAULT ('planned'),
        SourceStatus VARCHAR(30) NULL,
        StateStatus VARCHAR(30) NULL,
        DispatchStatus VARCHAR(30) NULL,
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_rt_ObjectRun PRIMARY KEY CLUSTERED (ObjectRunId),
        CONSTRAINT FK_rt_ObjectRun_Run FOREIGN KEY (PipelineRunId) REFERENCES rt.PipelineRun (PipelineRunId),
        CONSTRAINT FK_rt_ObjectRun_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT UQ_rt_ObjectRun_Run_Object UNIQUE (PipelineRunId, SyncObjectId),
        CONSTRAINT CK_rt_ObjectRun_Status CHECK (Status IN ('planned', 'ready', 'running', 'completed', 'failed', 'skipped'))
    );

    CREATE INDEX IX_rt_ObjectRun_Run_Order
        ON rt.ObjectRun (PipelineRunId, ExecutionOrder, ObjectRunId);
END;
GO

IF OBJECT_ID(N'rt.ObjectRunStep', N'U') IS NULL
BEGIN
    CREATE TABLE rt.ObjectRunStep
    (
        ObjectRunStepId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectRunId BIGINT NOT NULL,
        StepCode VARCHAR(40) NOT NULL,
        StepName VARCHAR(100) NOT NULL,
        ExecutionOrder INT NOT NULL,
        StepKind VARCHAR(20) NOT NULL,
        ProcedureName NVARCHAR(255) NULL,
        OperationCode CHAR(1) NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_rt_ObjectRunStep_Status DEFAULT ('planned'),
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_rt_ObjectRunStep PRIMARY KEY CLUSTERED (ObjectRunStepId),
        CONSTRAINT FK_rt_ObjectRunStep_ObjectRun FOREIGN KEY (ObjectRunId) REFERENCES rt.ObjectRun (ObjectRunId),
        CONSTRAINT FK_rt_ObjectRunStep_OperationType FOREIGN KEY (OperationCode) REFERENCES meta.OperationType (OperationCode),
        CONSTRAINT CK_rt_ObjectRunStep_StepKind CHECK (StepKind IN ('system', 'hook', 'operation')),
        CONSTRAINT CK_rt_ObjectRunStep_Status CHECK (Status IN ('planned', 'ready', 'running', 'completed', 'failed', 'skipped'))
    );

    CREATE INDEX IX_rt_ObjectRunStep_ObjectRun_Order
        ON rt.ObjectRunStep (ObjectRunId, ExecutionOrder, ObjectRunStepId);
END;
GO

IF OBJECT_ID(N'rt.SourceSnapshotRun', N'U') IS NULL
BEGIN
    CREATE TABLE rt.SourceSnapshotRun
    (
        SourceSnapshotRunId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectRunId BIGINT NOT NULL,
        SourceProfileId INT NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_rt_SourceSnapshotRun_Status DEFAULT ('planned'),
        SnapshotRowCount INT NOT NULL CONSTRAINT DF_rt_SourceSnapshotRun_SnapshotRowCount DEFAULT (0),
        StartedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_SourceSnapshotRun_StartedAt DEFAULT (SYSUTCDATETIME()),
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_rt_SourceSnapshotRun PRIMARY KEY CLUSTERED (SourceSnapshotRunId),
        CONSTRAINT FK_rt_SourceSnapshotRun_ObjectRun FOREIGN KEY (ObjectRunId) REFERENCES rt.ObjectRun (ObjectRunId),
        CONSTRAINT FK_rt_SourceSnapshotRun_SourceProfile FOREIGN KEY (SourceProfileId) REFERENCES cfg.ConnectionProfile (ConnectionProfileId),
        CONSTRAINT CK_rt_SourceSnapshotRun_Status CHECK (Status IN ('planned', 'running', 'completed', 'failed', 'discarded'))
    );
END;
GO

IF OBJECT_ID(N'rt.SourceSnapshotRow', N'U') IS NULL
BEGIN
    CREATE TABLE rt.SourceSnapshotRow
    (
        SourceSnapshotRowId BIGINT IDENTITY(1,1) NOT NULL,
        SourceSnapshotRunId BIGINT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        SourceHash VARBINARY(256) NULL,
        SourcePayloadJson NVARCHAR(MAX) NOT NULL,
        IsDeleted BIT NOT NULL CONSTRAINT DF_rt_SourceSnapshotRow_IsDeleted DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_SourceSnapshotRow_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_rt_SourceSnapshotRow PRIMARY KEY CLUSTERED (SourceSnapshotRowId),
        CONSTRAINT FK_rt_SourceSnapshotRow_Run FOREIGN KEY (SourceSnapshotRunId) REFERENCES rt.SourceSnapshotRun (SourceSnapshotRunId)
    );

    CREATE INDEX IX_rt_SourceSnapshotRow_Run_Key
        ON rt.SourceSnapshotRow (SourceSnapshotRunId, BusinessKey);
END;
GO

IF OBJECT_ID(N'rt.SourceCurrent', N'U') IS NULL
BEGIN
    CREATE TABLE rt.SourceCurrent
    (
        SourceCurrentId BIGINT IDENTITY(1,1) NOT NULL,
        SyncObjectId INT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        SourceHash VARBINARY(256) NULL,
        SourcePayloadJson NVARCHAR(MAX) NOT NULL,
        LastSourceSnapshotRunId BIGINT NOT NULL,
        LastSeenAt DATETIME2(0) NOT NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_SourceCurrent_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_SourceCurrent_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_rt_SourceCurrent PRIMARY KEY CLUSTERED (SourceCurrentId),
        CONSTRAINT FK_rt_SourceCurrent_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT FK_rt_SourceCurrent_SnapshotRun FOREIGN KEY (LastSourceSnapshotRunId) REFERENCES rt.SourceSnapshotRun (SourceSnapshotRunId),
        CONSTRAINT UQ_rt_SourceCurrent_Object_BusinessKey UNIQUE (SyncObjectId, BusinessKey)
    );

    CREATE INDEX IX_rt_SourceCurrent_Object_BusinessKey
        ON rt.SourceCurrent (SyncObjectId, BusinessKey);
END;
GO

IF OBJECT_ID(N'rt.SourceDelta', N'U') IS NULL
BEGIN
    CREATE TABLE rt.SourceDelta
    (
        SourceDeltaId BIGINT IDENTITY(1,1) NOT NULL,
        SourceSnapshotRunId BIGINT NOT NULL,
        SyncObjectId INT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        ChangeType CHAR(1) NOT NULL,
        PreviousSourceHash VARBINARY(256) NULL,
        CurrentSourceHash VARBINARY(256) NULL,
        PreviousPayloadJson NVARCHAR(MAX) NULL,
        CurrentPayloadJson NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_SourceDelta_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_rt_SourceDelta PRIMARY KEY CLUSTERED (SourceDeltaId),
        CONSTRAINT FK_rt_SourceDelta_SnapshotRun FOREIGN KEY (SourceSnapshotRunId) REFERENCES rt.SourceSnapshotRun (SourceSnapshotRunId),
        CONSTRAINT FK_rt_SourceDelta_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT CK_rt_SourceDelta_ChangeType CHECK (ChangeType IN ('I', 'U', 'D'))
    );

    CREATE INDEX IX_rt_SourceDelta_Run_ChangeType
        ON rt.SourceDelta (SourceSnapshotRunId, ChangeType, BusinessKey);

    CREATE INDEX IX_rt_SourceDelta_Object_BusinessKey
        ON rt.SourceDelta (SyncObjectId, BusinessKey, SourceSnapshotRunId DESC);
END;
GO

IF OBJECT_ID(N'rt.ObjectState', N'U') IS NULL
BEGIN
    CREATE TABLE rt.ObjectState
    (
        ObjectStateId BIGINT IDENTITY(1,1) NOT NULL,
        SyncObjectId INT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        DestinationRecordId VARCHAR(64) NULL,
        CurrentSourceHash VARBINARY(256) NULL,
        CurrentStateHash VARBINARY(256) NULL,
        CurrentPayloadJson NVARCHAR(MAX) NULL,
        LastSeenAt DATETIME2(0) NULL,
        LastAppliedAt DATETIME2(0) NULL,
        IsDeleted BIT NOT NULL CONSTRAINT DF_rt_ObjectState_IsDeleted DEFAULT (0),
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_ObjectState_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_ObjectState_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_rt_ObjectState PRIMARY KEY CLUSTERED (ObjectStateId),
        CONSTRAINT FK_rt_ObjectState_Object FOREIGN KEY (SyncObjectId) REFERENCES meta.SyncObject (SyncObjectId),
        CONSTRAINT UQ_rt_ObjectState_Object_BusinessKey UNIQUE (SyncObjectId, BusinessKey)
    );
END;
GO

IF OBJECT_ID(N'rt.WorkSet', N'U') IS NULL
BEGIN
    CREATE TABLE rt.WorkSet
    (
        WorkSetId BIGINT IDENTITY(1,1) NOT NULL,
        ObjectRunId BIGINT NOT NULL,
        OperationCode CHAR(1) NOT NULL,
        PlannedItemCount INT NOT NULL CONSTRAINT DF_rt_WorkSet_PlannedItemCount DEFAULT (0),
        BatchSize INT NOT NULL,
        Status VARCHAR(30) NOT NULL CONSTRAINT DF_rt_WorkSet_Status DEFAULT ('planned'),
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        Message NVARCHAR(MAX) NULL,
        CONSTRAINT PK_rt_WorkSet PRIMARY KEY CLUSTERED (WorkSetId),
        CONSTRAINT FK_rt_WorkSet_ObjectRun FOREIGN KEY (ObjectRunId) REFERENCES rt.ObjectRun (ObjectRunId),
        CONSTRAINT FK_rt_WorkSet_OperationType FOREIGN KEY (OperationCode) REFERENCES meta.OperationType (OperationCode),
        CONSTRAINT UQ_rt_WorkSet_ObjectRun_Operation UNIQUE (ObjectRunId, OperationCode),
        CONSTRAINT CK_rt_WorkSet_Status CHECK (Status IN ('planned', 'ready', 'running', 'completed', 'failed', 'skipped'))
    );
END;
GO

IF OBJECT_ID(N'rt.WorkItem', N'U') IS NULL
BEGIN
    CREATE TABLE rt.WorkItem
    (
        WorkItemId BIGINT IDENTITY(1,1) NOT NULL,
        WorkSetId BIGINT NOT NULL,
        BusinessKey NVARCHAR(400) NOT NULL,
        DestinationRecordId VARCHAR(64) NULL,
        SourceHash VARBINARY(256) NULL,
        PayloadJson NVARCHAR(MAX) NOT NULL,
        ResultStatus VARCHAR(30) NOT NULL CONSTRAINT DF_rt_WorkItem_ResultStatus DEFAULT ('planned'),
        ResultMessage NVARCHAR(MAX) NULL,
        AttemptCount INT NOT NULL CONSTRAINT DF_rt_WorkItem_AttemptCount DEFAULT (0),
        LastAttemptAt DATETIME2(0) NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_WorkItem_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_WorkItem_UpdatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_rt_WorkItem PRIMARY KEY CLUSTERED (WorkItemId),
        CONSTRAINT FK_rt_WorkItem_WorkSet FOREIGN KEY (WorkSetId) REFERENCES rt.WorkSet (WorkSetId),
        CONSTRAINT CK_rt_WorkItem_ResultStatus CHECK (ResultStatus IN ('planned', 'ready', 'running', 'completed', 'failed', 'skipped'))
    );

    CREATE INDEX IX_rt_WorkItem_WorkSet_Status
        ON rt.WorkItem (WorkSetId, ResultStatus, WorkItemId);
END;
GO

IF OBJECT_ID(N'rt.BatchRequest', N'U') IS NULL
BEGIN
    CREATE TABLE rt.BatchRequest
    (
        BatchRequestId BIGINT IDENTITY(1,1) NOT NULL,
        WorkSetId BIGINT NOT NULL,
        BatchNumber INT NOT NULL,
        RequestPayloadJson NVARCHAR(MAX) NULL,
        ResponsePayloadJson NVARCHAR(MAX) NULL,
        TransportStatus VARCHAR(30) NOT NULL CONSTRAINT DF_rt_BatchRequest_TransportStatus DEFAULT ('planned'),
        HttpStatusCode INT NULL,
        StartedAt DATETIME2(0) NULL,
        EndedAt DATETIME2(0) NULL,
        ErrorMessage NVARCHAR(MAX) NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_BatchRequest_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_rt_BatchRequest PRIMARY KEY CLUSTERED (BatchRequestId),
        CONSTRAINT FK_rt_BatchRequest_WorkSet FOREIGN KEY (WorkSetId) REFERENCES rt.WorkSet (WorkSetId),
        CONSTRAINT UQ_rt_BatchRequest_WorkSet_Batch UNIQUE (WorkSetId, BatchNumber),
        CONSTRAINT CK_rt_BatchRequest_Status CHECK (TransportStatus IN ('planned', 'ready', 'running', 'completed', 'failed', 'skipped'))
    );
END;
GO

IF OBJECT_ID(N'rt.BatchRequestItem', N'U') IS NULL
BEGIN
    CREATE TABLE rt.BatchRequestItem
    (
        BatchRequestItemId BIGINT IDENTITY(1,1) NOT NULL,
        BatchRequestId BIGINT NOT NULL,
        WorkItemId BIGINT NOT NULL,
        ItemSequence INT NOT NULL,
        RequestItemJson NVARCHAR(MAX) NOT NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_rt_BatchRequestItem_CreatedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_rt_BatchRequestItem PRIMARY KEY CLUSTERED (BatchRequestItemId),
        CONSTRAINT FK_rt_BatchRequestItem_BatchRequest FOREIGN KEY (BatchRequestId) REFERENCES rt.BatchRequest (BatchRequestId),
        CONSTRAINT FK_rt_BatchRequestItem_WorkItem FOREIGN KEY (WorkItemId) REFERENCES rt.WorkItem (WorkItemId),
        CONSTRAINT UQ_rt_BatchRequestItem_Batch_ItemSequence UNIQUE (BatchRequestId, ItemSequence),
        CONSTRAINT UQ_rt_BatchRequestItem_Batch_WorkItem UNIQUE (BatchRequestId, WorkItemId)
    );

    CREATE INDEX IX_rt_BatchRequestItem_WorkItem
        ON rt.BatchRequestItem (WorkItemId, BatchRequestId);
END;
GO

IF COL_LENGTH(N'rt.BatchRequestItem', N'ResponseItemJson') IS NULL
    ALTER TABLE rt.BatchRequestItem ADD ResponseItemJson NVARCHAR(MAX) NULL;
GO

IF COL_LENGTH(N'rt.BatchRequestItem', N'ResponseStatus') IS NULL
    ALTER TABLE rt.BatchRequestItem ADD ResponseStatus VARCHAR(30) NULL;
GO

IF COL_LENGTH(N'rt.BatchRequestItem', N'DestinationRecordId') IS NULL
    ALTER TABLE rt.BatchRequestItem ADD DestinationRecordId VARCHAR(64) NULL;
GO

IF COL_LENGTH(N'rt.BatchRequestItem', N'ErrorMessage') IS NULL
    ALTER TABLE rt.BatchRequestItem ADD ErrorMessage NVARCHAR(MAX) NULL;
GO

CREATE OR ALTER VIEW rt.vw_SyncObjectOperationMask
AS
SELECT
    so.SyncObjectId,
    STRING_AGG(soo.OperationCode, '') WITHIN GROUP (ORDER BY soo.OperationCode) AS OperationMask
FROM meta.SyncObject so
LEFT JOIN meta.SyncObjectOperation soo
    ON soo.SyncObjectId = so.SyncObjectId
   AND soo.IsEnabled = 1
GROUP BY so.SyncObjectId;
GO

CREATE OR ALTER PROCEDURE rt.PlanPipelineRun
    @ClientCode VARCHAR(50),
    @ObjectList VARCHAR(MAX) = NULL,
    @RefreshSource BIT = 1,
    @RefreshState BIT = 1,
    @AllowDispatch BIT = 0,
    @OutputDiagnostics BIT = 1,
    @PipelineRunId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IntegrationClientId INT;

    SELECT @IntegrationClientId = IntegrationClientId
    FROM cfg.IntegrationClient
    WHERE ClientCode = @ClientCode
      AND IsEnabled = 1;

    IF @IntegrationClientId IS NULL
        THROW 54000, 'PlanPipelineRun: client is not registered or not enabled.', 1;

    INSERT INTO rt.PipelineRun
    (
        IntegrationClientId,
        RequestedObjectList,
        RunMode,
        RefreshSource,
        RefreshState,
        AllowDispatch,
        OutputDiagnostics,
        Status,
        RequestedBy,
        Message
    )
    VALUES
    (
        @IntegrationClientId,
        @ObjectList,
        'plan',
        @RefreshSource,
        @RefreshState,
        @AllowDispatch,
        @OutputDiagnostics,
        'planned',
        ORIGINAL_LOGIN(),
        'Planning-only V3 pipeline run.'
    );

    SET @PipelineRunId = SCOPE_IDENTITY();

    ;WITH RequestedObjects AS
    (
        SELECT DISTINCT LTRIM(RTRIM([value])) AS ObjectCode
        FROM STRING_SPLIT(ISNULL(@ObjectList, ''), ',')
        WHERE LTRIM(RTRIM([value])) <> ''
    )
    INSERT INTO rt.ObjectRun
    (
        PipelineRunId,
        SyncObjectId,
        ExecutionOrder,
        PlannedOperationMask,
        Status
    )
    SELECT
        @PipelineRunId,
        so.SyncObjectId,
        so.ExecutionOrder,
        ISNULL(mask.OperationMask, ''),
        'planned'
    FROM meta.SyncObject so
    LEFT JOIN rt.vw_SyncObjectOperationMask mask
        ON mask.SyncObjectId = so.SyncObjectId
    LEFT JOIN RequestedObjects ro
        ON ro.ObjectCode = so.ObjectCode
    WHERE so.IntegrationClientId = @IntegrationClientId
      AND so.IsEnabled = 1
      AND (ISNULL(@ObjectList, '') = '' OR ro.ObjectCode = so.ObjectCode)
    ORDER BY so.ExecutionOrder, so.ObjectCode;

    INSERT INTO rt.ObjectRunStep
    (
        ObjectRunId,
        StepCode,
        StepName,
        ExecutionOrder,
        StepKind,
        ProcedureName,
        OperationCode,
        Status
    )
    SELECT
        objRun.ObjectRunId,
        stepData.StepCode,
        stepData.StepName,
        stepData.ExecutionOrder,
        stepData.StepKind,
        stepData.ProcedureName,
        stepData.OperationCode,
        'planned'
    FROM rt.ObjectRun objRun
    INNER JOIN meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objRun.SyncObjectId
    OUTER APPLY
    (
        SELECT
            CAST('PreObject' AS VARCHAR(40)) AS StepCode,
            CAST('Pre Object' AS VARCHAR(100)) AS StepName,
            10 AS ExecutionOrder,
            CAST('system' AS VARCHAR(20)) AS StepKind,
            CAST(NULL AS NVARCHAR(255)) AS ProcedureName,
            CAST(NULL AS CHAR(1)) AS OperationCode
        UNION ALL
        SELECT
            'RefreshSource',
            'Refresh Source',
            20,
            'system',
            NULL,
            NULL
        WHERE @RefreshSource = 1
        UNION ALL
        SELECT
            'SourcePostLoad',
            'Source Post Load',
            30,
            'system',
            NULL,
            NULL
        UNION ALL
        SELECT
            'RefreshState',
            'Refresh State',
            50,
            'system',
            NULL,
            NULL
        WHERE @RefreshState = 1
        UNION ALL
        SELECT
            CONCAT('Plan', op.OperationCode),
            CASE op.OperationCode
                WHEN 'D' THEN 'Plan Deletes'
                WHEN 'I' THEN 'Plan Inserts'
                WHEN 'U' THEN 'Plan Updates'
                WHEN 'R' THEN 'Plan Refresh'
            END,
            CASE op.OperationCode
                WHEN 'D' THEN 70
                WHEN 'I' THEN 80
                WHEN 'U' THEN 90
                WHEN 'R' THEN 95
            END,
            'operation',
            NULL,
            op.OperationCode
        FROM meta.SyncObjectOperation op
        WHERE op.SyncObjectId = syncObj.SyncObjectId
          AND op.IsEnabled = 1
        UNION ALL
        SELECT
            'BuildBatches',
            'Build Batches',
            120,
            'system',
            NULL,
            NULL
        WHERE @AllowDispatch = 1
        UNION ALL
        SELECT
            'DispatchBatches',
            'Dispatch Batches',
            130,
            'system',
            NULL,
            NULL
        WHERE @AllowDispatch = 1
        UNION ALL
        SELECT
            'ReconcileResults',
            'Reconcile Results',
            140,
            'system',
            NULL,
            NULL
        UNION ALL
        SELECT
            CONCAT('Hook:', hook.HookPhaseCode, ':', hook.SyncObjectHookId),
            CONCAT('Hook ', hook.HookPhaseCode),
            1000 + hook.ExecutionOrder,
            'hook',
            hook.ProcedureName,
            NULL
        FROM meta.SyncObjectHook hook
        WHERE hook.SyncObjectId = syncObj.SyncObjectId
          AND hook.IsEnabled = 1
        UNION ALL
        SELECT
            'FinalizeObject',
            'Finalize Object',
            2000,
            'system',
            NULL,
            NULL
    ) stepData
    WHERE objRun.PipelineRunId = @PipelineRunId;

    UPDATE rt.PipelineRun
    SET Status = 'ready'
    WHERE PipelineRunId = @PipelineRunId;

    SELECT
        @PipelineRunId AS PipelineRunId,
        @ClientCode AS ClientCode,
        (SELECT COUNT(*) FROM rt.ObjectRun WHERE PipelineRunId = @PipelineRunId) AS PlannedObjectCount,
        (SELECT COUNT(*) FROM rt.ObjectRunStep s INNER JOIN rt.ObjectRun r ON r.ObjectRunId = s.ObjectRunId WHERE r.PipelineRunId = @PipelineRunId) AS PlannedStepCount;
END;
GO

CREATE OR ALTER VIEW rt.vw_PipelinePlanSummary
AS
SELECT
    run.PipelineRunId,
    client.ClientCode,
    run.RunMode,
    run.Status AS PipelineStatus,
    objRun.ObjectRunId,
    syncObj.ObjectCode,
    objRun.ExecutionOrder,
    objRun.PlannedOperationMask,
    objRun.Status AS ObjectStatus,
    step.ObjectRunStepId,
    step.StepCode,
    step.StepName,
    step.ExecutionOrder AS StepExecutionOrder,
    step.StepKind,
    step.ProcedureName,
    step.OperationCode,
    step.Status AS StepStatus
FROM rt.PipelineRun run
INNER JOIN cfg.IntegrationClient client
    ON client.IntegrationClientId = run.IntegrationClientId
INNER JOIN rt.ObjectRun objRun
    ON objRun.PipelineRunId = run.PipelineRunId
INNER JOIN meta.SyncObject syncObj
    ON syncObj.SyncObjectId = objRun.SyncObjectId
INNER JOIN rt.ObjectRunStep step
    ON step.ObjectRunId = objRun.ObjectRunId;
GO

CREATE OR ALTER PROCEDURE rt.CaptureSourceSnapshot
    @ObjectRunId BIGINT,
    @ForceRecapture BIT = 1,
    @SourceSnapshotRunId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @SyncObjectId INT,
        @IntegrationClientId INT,
        @ObjectCode VARCHAR(80),
        @SourceStageSchemaName SYSNAME,
        @SourceStageTableName SYSNAME,
        @SourceDatabaseName SYSNAME,
        @SourceProfileId INT,
        @QualifiedSourceObject NVARCHAR(512),
        @BusinessKeyRawExpression NVARCHAR(MAX),
        @SourceHashRawExpression NVARCHAR(MAX),
        @SourceHashSelectExpression NVARCHAR(MAX),
        @Sql NVARCHAR(MAX),
        @SnapshotRowCount INT,
        @DuplicateBusinessKeyCount INT,
        @InsertDeltaCount INT = 0,
        @UpdateDeltaCount INT = 0,
        @DeleteDeltaCount INT = 0,
        @HasRowHash BIT = 0,
        @RefreshStepExists BIT = 0,
        @ErrorMessage NVARCHAR(MAX);

    SET @SourceSnapshotRunId = NULL;

    BEGIN TRY
        SELECT
            @SyncObjectId = objRun.SyncObjectId,
            @IntegrationClientId = syncObj.IntegrationClientId,
            @ObjectCode = syncObj.ObjectCode,
            @SourceStageSchemaName = syncObj.SourceStageSchemaName,
            @SourceStageTableName = syncObj.SourceStageTableName
        FROM rt.ObjectRun objRun
        INNER JOIN meta.SyncObject syncObj
            ON syncObj.SyncObjectId = objRun.SyncObjectId
        WHERE objRun.ObjectRunId = @ObjectRunId;

        IF @SyncObjectId IS NULL
            THROW 54100, 'CaptureSourceSnapshot: object run was not found.', 1;

        IF NULLIF(@SourceStageTableName, N'') IS NULL
            THROW 54101, 'CaptureSourceSnapshot: source stage table is not configured for the object.', 1;

        SELECT TOP (1)
            @SourceProfileId = profile.ConnectionProfileId,
            @SourceDatabaseName = profile.DatabaseName
        FROM cfg.ConnectionProfile profile
        WHERE profile.IntegrationClientId = @IntegrationClientId
          AND profile.ConnectionType = 'sql_database'
          AND profile.IsEnabled = 1
        ORDER BY
            CASE WHEN profile.ProfileCode = 'SOURCE_DATABASE' THEN 0 ELSE 1 END,
            CASE WHEN profile.IsDefault = 1 THEN 0 ELSE 1 END,
            profile.ConnectionProfileId;

        IF @SourceProfileId IS NULL OR NULLIF(@SourceDatabaseName, N'') IS NULL
            THROW 54102, 'CaptureSourceSnapshot: default sql_database source profile is not configured.', 1;

        SELECT
            @BusinessKeyRawExpression = STRING_AGG(
                N'N''' + REPLACE(fieldMap.SourceFieldName, N'''', N'''''') + N'='' + ISNULL(CONVERT(NVARCHAR(4000), src.' + QUOTENAME(fieldMap.SourceFieldName) + N'), N''<NULL>'')',
                N' + N''|'' + '
            ) WITHIN GROUP (ORDER BY ISNULL(fieldMap.DisplayOrder, 2147483647), fieldMap.FieldMapId)
        FROM meta.FieldMap fieldMap
        WHERE fieldMap.SyncObjectId = @SyncObjectId
          AND fieldMap.IsEnabled = 1
          AND fieldMap.IsSourceMatchKey = 1
          AND NULLIF(LTRIM(RTRIM(fieldMap.SourceFieldName)), N'') IS NOT NULL;

        IF @BusinessKeyRawExpression IS NULL
            THROW 54103, 'CaptureSourceSnapshot: no enabled source match-key fields are defined.', 1;

        SELECT
            @SourceHashRawExpression = STRING_AGG(
                N'ISNULL(CONVERT(NVARCHAR(MAX), src.' + QUOTENAME(fieldMap.SourceFieldName) + N'), N''<NULL>'')',
                N' + N''|'' + '
            ) WITHIN GROUP (ORDER BY fieldMap.SourceHashOrder, fieldMap.FieldMapId)
        FROM meta.FieldMap fieldMap
        WHERE fieldMap.SyncObjectId = @SyncObjectId
          AND fieldMap.IsEnabled = 1
          AND fieldMap.SourceHashOrder IS NOT NULL
          AND NULLIF(LTRIM(RTRIM(fieldMap.SourceFieldName)), N'') IS NOT NULL;

        SET @QualifiedSourceObject = QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SourceStageSchemaName) + N'.' + QUOTENAME(@SourceStageTableName);

        SET @Sql = N'
SELECT @HasRowHash = CASE
    WHEN EXISTS
    (
        SELECT 1
        FROM ' + QUOTENAME(@SourceDatabaseName) + N'.sys.columns AS sourceColumn
        WHERE sourceColumn.object_id = OBJECT_ID(N''' + REPLACE(@QualifiedSourceObject, N'''', N'''''') + N''')
          AND sourceColumn.name = N''RowHash''
    )
    THEN 1
    ELSE 0
END;';

        EXEC sys.sp_executesql
            @Sql,
            N'@HasRowHash BIT OUTPUT',
            @HasRowHash = @HasRowHash OUTPUT;

        IF @SourceHashRawExpression IS NOT NULL
        BEGIN
            SET @SourceHashSelectExpression = N'HASHBYTES(''SHA2_256'', hashData.RawHashText)';
        END
        ELSE IF @HasRowHash = 1
        BEGIN
            SET @SourceHashSelectExpression = N'src.[RowHash]';
        END
        ELSE
        BEGIN
            THROW 54104, 'CaptureSourceSnapshot: source row hash is unavailable and no metadata hash fields are defined.', 1;
        END;

        IF @ForceRecapture = 1
        BEGIN
            UPDATE snapshotRun
            SET
                snapshotRun.Status = 'discarded',
                snapshotRun.EndedAt = SYSUTCDATETIME(),
                snapshotRun.Message = CONCAT(
                    ISNULL(snapshotRun.Message + N' ', N''),
                    N'Superseded by a newer source snapshot run for object run ',
                    CONVERT(NVARCHAR(30), @ObjectRunId),
                    N'.'
                )
            FROM rt.SourceSnapshotRun snapshotRun
            WHERE snapshotRun.ObjectRunId = @ObjectRunId
              AND snapshotRun.Status IN ('planned', 'running', 'completed');
        END;

        INSERT INTO rt.SourceSnapshotRun
        (
            ObjectRunId,
            SourceProfileId,
            Status,
            Message
        )
        VALUES
        (
            @ObjectRunId,
            @SourceProfileId,
            'running',
            CONCAT(N'Capturing source rows from ', @QualifiedSourceObject, N'.')
        );

        SET @SourceSnapshotRunId = SCOPE_IDENTITY();

        SELECT @RefreshStepExists = CASE WHEN EXISTS
        (
            SELECT 1
            FROM rt.ObjectRunStep
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshSource'
        )
        THEN 1 ELSE 0 END;

        UPDATE rt.ObjectRun
        SET
            Status = 'running',
            SourceStatus = 'running',
            StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
            EndedAt = NULL,
            Message = CONCAT(N'Capturing source snapshot from ', @QualifiedSourceObject, N'.')
        WHERE ObjectRunId = @ObjectRunId;

        IF @RefreshStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'running',
                StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
                EndedAt = NULL,
                Message = CONCAT(N'Capturing source snapshot from ', @QualifiedSourceObject, N'.')
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshSource';
        END;

        CREATE TABLE #CapturedSourceRow
        (
            BusinessKey NVARCHAR(400) NOT NULL,
            SourceHash VARBINARY(256) NULL,
            SourcePayloadJson NVARCHAR(MAX) NOT NULL,
            IsDeleted BIT NOT NULL DEFAULT (0),
            PRIMARY KEY CLUSTERED (BusinessKey)
        );

        SET @Sql = N'
INSERT INTO #CapturedSourceRow
(
    BusinessKey,
    SourceHash,
    SourcePayloadJson,
    IsDeleted
)
SELECT
    CASE
        WHEN LEN(keyData.RawBusinessKey) <= 400 THEN keyData.RawBusinessKey
        ELSE LEFT(keyData.RawBusinessKey, 335) + N''|#'' + CONVERT(VARCHAR(64), HASHBYTES(''SHA2_256'', keyData.RawBusinessKey), 2)
    END AS BusinessKey,
    ' + @SourceHashSelectExpression + N' AS SourceHash,
    payload.SourcePayloadJson,
    0
FROM ' + @QualifiedSourceObject + N' AS src
CROSS APPLY
(
    SELECT ' + @BusinessKeyRawExpression + N' AS RawBusinessKey
) AS keyData
' + CASE
        WHEN @SourceHashRawExpression IS NULL THEN N''
        ELSE N'CROSS APPLY
(
    SELECT ' + @SourceHashRawExpression + N' AS RawHashText
) AS hashData
'
    END + N'
CROSS APPLY
(
    SELECT
        (
            SELECT src.*
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        ) AS SourcePayloadJson
) AS payload;';

        EXEC sys.sp_executesql @Sql;

        SELECT
            @SnapshotRowCount = COUNT(*)
        FROM #CapturedSourceRow capturedRow;

        SELECT
            @DuplicateBusinessKeyCount = COUNT(*)
        FROM
        (
            SELECT capturedRow.BusinessKey
            FROM #CapturedSourceRow capturedRow
            GROUP BY capturedRow.BusinessKey
            HAVING COUNT(*) > 1
        ) AS duplicateKey;

        IF @DuplicateBusinessKeyCount > 0
            THROW 54105, 'CaptureSourceSnapshot: duplicate business keys were detected in the captured source rows.', 1;

        INSERT INTO rt.SourceDelta
        (
            SourceSnapshotRunId,
            SyncObjectId,
            BusinessKey,
            ChangeType,
            PreviousSourceHash,
            CurrentSourceHash,
            PreviousPayloadJson,
            CurrentPayloadJson
        )
        SELECT
            @SourceSnapshotRunId,
            @SyncObjectId,
            capturedRow.BusinessKey,
            'I',
            NULL,
            capturedRow.SourceHash,
            NULL,
            capturedRow.SourcePayloadJson
        FROM #CapturedSourceRow capturedRow
        LEFT JOIN rt.SourceCurrent currentRow
            ON currentRow.SyncObjectId = @SyncObjectId
           AND currentRow.BusinessKey = capturedRow.BusinessKey
        WHERE currentRow.SourceCurrentId IS NULL;

        SET @InsertDeltaCount = @@ROWCOUNT;

        INSERT INTO rt.SourceDelta
        (
            SourceSnapshotRunId,
            SyncObjectId,
            BusinessKey,
            ChangeType,
            PreviousSourceHash,
            CurrentSourceHash,
            PreviousPayloadJson,
            CurrentPayloadJson
        )
        SELECT
            @SourceSnapshotRunId,
            @SyncObjectId,
            capturedRow.BusinessKey,
            'U',
            currentRow.SourceHash,
            capturedRow.SourceHash,
            currentRow.SourcePayloadJson,
            capturedRow.SourcePayloadJson
        FROM #CapturedSourceRow capturedRow
        INNER JOIN rt.SourceCurrent currentRow
            ON currentRow.SyncObjectId = @SyncObjectId
           AND currentRow.BusinessKey = capturedRow.BusinessKey
        WHERE
        (
            (capturedRow.SourceHash IS NULL AND currentRow.SourceHash IS NOT NULL)
            OR (capturedRow.SourceHash IS NOT NULL AND currentRow.SourceHash IS NULL)
            OR (capturedRow.SourceHash <> currentRow.SourceHash)
        );

        SET @UpdateDeltaCount = @@ROWCOUNT;

        INSERT INTO rt.SourceDelta
        (
            SourceSnapshotRunId,
            SyncObjectId,
            BusinessKey,
            ChangeType,
            PreviousSourceHash,
            CurrentSourceHash,
            PreviousPayloadJson,
            CurrentPayloadJson
        )
        SELECT
            @SourceSnapshotRunId,
            @SyncObjectId,
            currentRow.BusinessKey,
            'D',
            currentRow.SourceHash,
            NULL,
            currentRow.SourcePayloadJson,
            NULL
        FROM rt.SourceCurrent currentRow
        LEFT JOIN #CapturedSourceRow capturedRow
            ON capturedRow.BusinessKey = currentRow.BusinessKey
        WHERE currentRow.SyncObjectId = @SyncObjectId
          AND capturedRow.BusinessKey IS NULL;

        SET @DeleteDeltaCount = @@ROWCOUNT;

        DELETE currentRow
        FROM rt.SourceCurrent currentRow
        LEFT JOIN #CapturedSourceRow capturedRow
            ON capturedRow.BusinessKey = currentRow.BusinessKey
        WHERE currentRow.SyncObjectId = @SyncObjectId
          AND capturedRow.BusinessKey IS NULL;

        UPDATE currentRow
        SET
            currentRow.SourceHash = capturedRow.SourceHash,
            currentRow.SourcePayloadJson = capturedRow.SourcePayloadJson,
            currentRow.LastSourceSnapshotRunId = @SourceSnapshotRunId,
            currentRow.LastSeenAt = SYSUTCDATETIME(),
            currentRow.UpdatedAt = SYSUTCDATETIME()
        FROM rt.SourceCurrent currentRow
        INNER JOIN #CapturedSourceRow capturedRow
            ON capturedRow.BusinessKey = currentRow.BusinessKey
        WHERE currentRow.SyncObjectId = @SyncObjectId;

        INSERT INTO rt.SourceCurrent
        (
            SyncObjectId,
            BusinessKey,
            SourceHash,
            SourcePayloadJson,
            LastSourceSnapshotRunId,
            LastSeenAt
        )
        SELECT
            @SyncObjectId,
            capturedRow.BusinessKey,
            capturedRow.SourceHash,
            capturedRow.SourcePayloadJson,
            @SourceSnapshotRunId,
            SYSUTCDATETIME()
        FROM #CapturedSourceRow capturedRow
        LEFT JOIN rt.SourceCurrent currentRow
            ON currentRow.SyncObjectId = @SyncObjectId
           AND currentRow.BusinessKey = capturedRow.BusinessKey
        WHERE currentRow.SourceCurrentId IS NULL;

        UPDATE rt.SourceSnapshotRun
        SET
            Status = 'completed',
            SnapshotRowCount = @SnapshotRowCount,
            EndedAt = SYSUTCDATETIME(),
            Message = CONCAT(
                N'Captured ',
                CONVERT(NVARCHAR(30), @SnapshotRowCount),
                N' source rows from ',
                @QualifiedSourceObject,
                N'; delta I=',
                CONVERT(NVARCHAR(30), @InsertDeltaCount),
                N', U=',
                CONVERT(NVARCHAR(30), @UpdateDeltaCount),
                N', D=',
                CONVERT(NVARCHAR(30), @DeleteDeltaCount),
                N' for object ',
                @ObjectCode,
                N'.'
            )
        WHERE SourceSnapshotRunId = @SourceSnapshotRunId;

        UPDATE rt.ObjectRun
        SET
            SourceStatus = 'completed',
            Status = 'running',
            Message = CONCAT(
                N'Source snapshot captured from ',
                @QualifiedSourceObject,
                N' with ',
                CONVERT(NVARCHAR(30), @SnapshotRowCount),
                N' rows.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        IF @RefreshStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'completed',
                EndedAt = SYSUTCDATETIME(),
                Message = CONCAT(
                    N'Captured ',
                    CONVERT(NVARCHAR(30), @SnapshotRowCount),
                    N' source rows from ',
                    @QualifiedSourceObject,
                    N'.'
                )
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshSource';
        END;

        SELECT
            @SourceSnapshotRunId AS SourceSnapshotRunId,
            @ObjectRunId AS ObjectRunId,
            @ObjectCode AS ObjectCode,
            @QualifiedSourceObject AS SourceObjectName,
            @SnapshotRowCount AS SnapshotRowCount;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        IF @SourceSnapshotRunId IS NOT NULL
        BEGIN
            UPDATE rt.SourceSnapshotRun
            SET
                Status = 'failed',
                EndedAt = SYSUTCDATETIME(),
                Message = @ErrorMessage
            WHERE SourceSnapshotRunId = @SourceSnapshotRunId;
        END;

        UPDATE rt.ObjectRun
        SET
            SourceStatus = 'failed',
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId;

        UPDATE rt.ObjectRunStep
        SET
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId
          AND StepCode = 'RefreshSource'
          AND Status <> 'completed';

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE rt.RefreshSourceStage
    @ObjectRunId BIGINT,
    @OutputDiagnostics BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @PipelineRunId BIGINT,
        @SyncObjectId INT,
        @IntegrationClientId INT,
        @ClientCode VARCHAR(50),
        @ObjectCode VARCHAR(80),
        @SourceStageSchemaName SYSNAME,
        @SourceStageTableName SYSNAME,
        @RefreshMode VARCHAR(50),
        @RefreshProcedureName NVARCHAR(255),
        @RefreshStartedAt DATETIME2(3) = SYSUTCDATETIME(),
        @RefreshEndedAt DATETIME2(3),
        @RefreshDurationMs INT,
        @ErrorMessage NVARCHAR(MAX),
        @RefreshStepExists BIT = 0,
        @Sql NVARCHAR(MAX);

    BEGIN TRY
        SELECT
            @PipelineRunId = objectRun.PipelineRunId,
            @SyncObjectId = objectRun.SyncObjectId,
            @IntegrationClientId = syncObj.IntegrationClientId,
            @ClientCode = client.ClientCode,
            @ObjectCode = syncObj.ObjectCode,
            @SourceStageSchemaName = syncObj.SourceStageSchemaName,
            @SourceStageTableName = syncObj.SourceStageTableName
        FROM rt.ObjectRun objectRun
        INNER JOIN meta.SyncObject syncObj
            ON syncObj.SyncObjectId = objectRun.SyncObjectId
        INNER JOIN cfg.IntegrationClient client
            ON client.IntegrationClientId = syncObj.IntegrationClientId
        WHERE objectRun.ObjectRunId = @ObjectRunId;

        IF @SyncObjectId IS NULL
            THROW 54110, 'RefreshSourceStage: object run was not found.', 1;

        IF NULLIF(@SourceStageTableName, N'') IS NULL
            THROW 54111, 'RefreshSourceStage: source stage table is not configured for the object.', 1;

        SELECT @RefreshStepExists = CASE WHEN EXISTS
        (
            SELECT 1
            FROM rt.ObjectRunStep
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshSource'
        )
        THEN 1 ELSE 0 END;

        SELECT
            @RefreshMode = COALESCE(
                NULLIF(MAX(CASE WHEN objectSetting.SettingName = 'SOURCE_REFRESH_MODE' THEN objectSetting.SettingValue END), ''),
                NULLIF(MAX(CASE WHEN clientSetting.SettingName = 'V3_SOURCE_REFRESH_MODE' THEN clientSetting.SettingValue END), ''),
                'legacy_v2_updatesourcetable'
            ),
            @RefreshProcedureName = COALESCE(
                NULLIF(MAX(CASE WHEN objectSetting.SettingName = 'SOURCE_REFRESH_PROCEDURE' THEN objectSetting.SettingValue END), ''),
                NULLIF(MAX(CASE WHEN clientSetting.SettingName = 'V3_SOURCE_REFRESH_PROCEDURE' THEN clientSetting.SettingValue END), '')
            )
        FROM (SELECT 1 AS Stub) seed
        LEFT JOIN meta.SyncObjectSetting objectSetting
            ON objectSetting.SyncObjectId = @SyncObjectId
           AND objectSetting.IsEnabled = 1
           AND objectSetting.SettingName IN ('SOURCE_REFRESH_MODE', 'SOURCE_REFRESH_PROCEDURE')
        LEFT JOIN cfg.ClientSetting clientSetting
            ON clientSetting.IntegrationClientId = @IntegrationClientId
           AND clientSetting.IsEnabled = 1
           AND clientSetting.SettingName IN ('V3_SOURCE_REFRESH_MODE', 'V3_SOURCE_REFRESH_PROCEDURE');

        UPDATE rt.ObjectRun
        SET
            Status = 'running',
            SourceStatus = 'running',
            StartedAt = ISNULL(StartedAt, @RefreshStartedAt),
            EndedAt = NULL,
            Message = CONCAT(
                N'Refreshing source stage ',
                QUOTENAME(@SourceStageSchemaName),
                N'.',
                QUOTENAME(@SourceStageTableName),
                N' for object ',
                @ObjectCode,
                N'.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        IF @RefreshStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'running',
                StartedAt = ISNULL(StartedAt, @RefreshStartedAt),
                EndedAt = NULL,
                Message = CONCAT(
                    N'Refreshing source stage ',
                    QUOTENAME(@SourceStageSchemaName),
                    N'.',
                    QUOTENAME(@SourceStageTableName),
                    N' using mode ',
                    @RefreshMode,
                    N'.'
                )
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshSource';
        END;

        IF @RefreshMode = 'legacy_v2_updatesourcetable'
        BEGIN
            EXEC INTEGRAMASTER_V2.dbo.UpdateSourceTable
                @ClientId = @ClientCode,
                @ObjectName = @ObjectCode;
        END
        ELSE IF @RefreshMode IN ('custom_procedure', 'custom')
        BEGIN
            IF NULLIF(@RefreshProcedureName, N'') IS NULL
                THROW 54112, 'RefreshSourceStage: refresh mode custom_procedure requires SOURCE_REFRESH_PROCEDURE or V3_SOURCE_REFRESH_PROCEDURE.', 1;

            SET @Sql = N'EXEC ' + @RefreshProcedureName + N' @ClientId = @ResolvedClientCode, @ObjectName = @ResolvedObjectCode;';

            EXEC sys.sp_executesql
                @Sql,
                N'@ResolvedClientCode VARCHAR(50), @ResolvedObjectCode VARCHAR(80)',
                @ResolvedClientCode = @ClientCode,
                @ResolvedObjectCode = @ObjectCode;
        END
        ELSE IF @RefreshMode IN ('skip', 'none', 'capture_only')
        BEGIN
            SET @RefreshProcedureName = NULL;
        END
        ELSE
            THROW 54113, 'RefreshSourceStage: refresh mode is not supported.', 1;

        SET @RefreshEndedAt = SYSUTCDATETIME();
        SET @RefreshDurationMs = DATEDIFF(MILLISECOND, @RefreshStartedAt, @RefreshEndedAt);

        UPDATE rt.ObjectRun
        SET
            Status = 'running',
            SourceStatus = 'running',
            Message = CONCAT(
                N'Source stage refresh completed for object ',
                @ObjectCode,
                N' in ',
                CONVERT(NVARCHAR(30), @RefreshDurationMs),
                N' ms using mode ',
                @RefreshMode,
                N'.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        IF @RefreshStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'running',
                EndedAt = @RefreshEndedAt,
                Message = CONCAT(
                    N'Source stage refresh completed in ',
                    CONVERT(NVARCHAR(30), @RefreshDurationMs),
                    N' ms using mode ',
                    @RefreshMode,
                    N'.'
                )
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshSource';
        END;

        IF @OutputDiagnostics = 1
        BEGIN
            SELECT
                @PipelineRunId AS PipelineRunId,
                @ObjectRunId AS ObjectRunId,
                @ClientCode AS ClientCode,
                @ObjectCode AS ObjectCode,
                @RefreshMode AS RefreshMode,
                @RefreshProcedureName AS RefreshProcedureName,
                @RefreshDurationMs AS RefreshDurationMs,
                QUOTENAME(@SourceStageSchemaName) + N'.' + QUOTENAME(@SourceStageTableName) AS SourceStageObjectName;
        END;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE rt.ObjectRun
        SET
            SourceStatus = 'failed',
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId;

        UPDATE rt.ObjectRunStep
        SET
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId
          AND StepCode = 'RefreshSource'
          AND Status <> 'completed';

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE rt.ExecutePlannedSourceSnapshots
    @PipelineRunId BIGINT,
    @ObjectList VARCHAR(MAX) = NULL,
    @StopOnError BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @ObjectRunId BIGINT,
        @SourceSnapshotRunId BIGINT,
        @ProcessedObjectCount INT = 0,
        @FailedObjectCount INT = 0,
        @ErrorMessage NVARCHAR(MAX);

    IF NOT EXISTS
    (
        SELECT 1
        FROM rt.PipelineRun
        WHERE PipelineRunId = @PipelineRunId
    )
        THROW 54120, 'ExecutePlannedSourceSnapshots: pipeline run was not found.', 1;

    UPDATE rt.PipelineRun
    SET
        Status = 'running',
        StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
        EndedAt = NULL,
        Message = 'Executing source snapshot phase.'
    WHERE PipelineRunId = @PipelineRunId;

    DECLARE object_cursor CURSOR LOCAL FAST_FORWARD FOR
    WITH RequestedObjects AS
    (
        SELECT DISTINCT LTRIM(RTRIM([value])) AS ObjectCode
        FROM STRING_SPLIT(ISNULL(@ObjectList, ''), ',')
        WHERE LTRIM(RTRIM([value])) <> ''
    )
    SELECT objectRun.ObjectRunId
    FROM rt.ObjectRun objectRun
    INNER JOIN meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objectRun.SyncObjectId
    LEFT JOIN RequestedObjects requested
        ON requested.ObjectCode = syncObj.ObjectCode
    WHERE objectRun.PipelineRunId = @PipelineRunId
      AND (ISNULL(@ObjectList, '') = '' OR requested.ObjectCode = syncObj.ObjectCode)
      AND EXISTS
      (
          SELECT 1
          FROM rt.ObjectRunStep step
          WHERE step.ObjectRunId = objectRun.ObjectRunId
            AND step.StepCode = 'RefreshSource'
      )
    ORDER BY objectRun.ExecutionOrder, objectRun.ObjectRunId;

    OPEN object_cursor;

    FETCH NEXT FROM object_cursor INTO @ObjectRunId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC rt.RefreshSourceStage
                @ObjectRunId = @ObjectRunId,
                @OutputDiagnostics = 0;

            EXEC rt.CaptureSourceSnapshot
                @ObjectRunId = @ObjectRunId,
                @ForceRecapture = 1,
                @SourceSnapshotRunId = @SourceSnapshotRunId OUTPUT;

            SET @ProcessedObjectCount += 1;
        END TRY
        BEGIN CATCH
            SET @FailedObjectCount += 1;
            SET @ErrorMessage = ERROR_MESSAGE();

            IF @StopOnError = 1
            BEGIN
                CLOSE object_cursor;
                DEALLOCATE object_cursor;

                UPDATE rt.PipelineRun
                SET
                    Status = 'failed',
                    EndedAt = SYSUTCDATETIME(),
                    Message = CONCAT(
                        N'Source snapshot phase failed after ',
                        CONVERT(NVARCHAR(30), @ProcessedObjectCount),
                        N' completed objects. Last error: ',
                        @ErrorMessage
                    )
                WHERE PipelineRunId = @PipelineRunId;

                THROW;
            END;
        END CATCH;

        FETCH NEXT FROM object_cursor INTO @ObjectRunId;
    END;

    CLOSE object_cursor;
    DEALLOCATE object_cursor;

    UPDATE rt.PipelineRun
    SET
        Status = CASE WHEN @FailedObjectCount > 0 THEN 'failed' ELSE 'running' END,
        Message = CASE
            WHEN @FailedObjectCount > 0 THEN CONCAT(
                N'Source snapshot phase completed with ',
                CONVERT(NVARCHAR(30), @FailedObjectCount),
                N' failed objects and ',
                CONVERT(NVARCHAR(30), @ProcessedObjectCount),
                N' successful objects.'
            )
            ELSE CONCAT(
                N'Source snapshot phase completed for ',
                CONVERT(NVARCHAR(30), @ProcessedObjectCount),
                N' objects.'
            )
        END
    WHERE PipelineRunId = @PipelineRunId;

    SELECT
        @PipelineRunId AS PipelineRunId,
        @ProcessedObjectCount AS SuccessfulObjectCount,
        @FailedObjectCount AS FailedObjectCount;
END;
GO

CREATE OR ALTER PROCEDURE rt.PlanObjectWork
    @ObjectRunId BIGINT,
    @ResetWork BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @SyncObjectId INT,
        @ObjectCode VARCHAR(80),
        @BatchSize INT,
        @LatestSourceSnapshotRunId BIGINT,
        @RefreshStateStepExists BIT = 0,
        @InsertCount INT = 0,
        @UpdateCount INT = 0,
        @DeleteCount INT = 0,
        @RefreshCount INT = 0,
        @ActiveStateRowCount INT = 0,
        @DeletedStateRowCount INT = 0,
        @ErrorMessage NVARCHAR(MAX);

    BEGIN TRY
        SELECT
            @SyncObjectId = syncObj.SyncObjectId,
            @ObjectCode = syncObj.ObjectCode,
            @BatchSize = syncObj.BatchSize
        FROM rt.ObjectRun objectRun
        INNER JOIN meta.SyncObject syncObj
            ON syncObj.SyncObjectId = objectRun.SyncObjectId
        WHERE objectRun.ObjectRunId = @ObjectRunId;

        IF @SyncObjectId IS NULL
            THROW 54140, 'PlanObjectWork: object run was not found.', 1;

        SELECT TOP (1)
            @LatestSourceSnapshotRunId = snapshotRun.SourceSnapshotRunId
        FROM rt.SourceSnapshotRun snapshotRun
        WHERE snapshotRun.ObjectRunId = @ObjectRunId
          AND snapshotRun.Status = 'completed'
        ORDER BY snapshotRun.SourceSnapshotRunId DESC;

        IF @LatestSourceSnapshotRunId IS NULL
            THROW 54141, 'PlanObjectWork: no completed source snapshot exists for the object run.', 1;

        SELECT @RefreshStateStepExists = CASE WHEN EXISTS
        (
            SELECT 1
            FROM rt.ObjectRunStep
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshState'
        )
        THEN 1 ELSE 0 END;

        IF @ResetWork = 1
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM rt.BatchRequest batchRequest
                INNER JOIN rt.WorkSet workSet
                    ON workSet.WorkSetId = batchRequest.WorkSetId
                WHERE workSet.ObjectRunId = @ObjectRunId
            )
                THROW 54142, 'PlanObjectWork: existing batch requests prevent work-plan reset for this object run.', 1;

            DELETE workItem
            FROM rt.WorkItem workItem
            INNER JOIN rt.WorkSet workSet
                ON workSet.WorkSetId = workItem.WorkSetId
            WHERE workSet.ObjectRunId = @ObjectRunId;

            DELETE workSet
            FROM rt.WorkSet workSet
            WHERE workSet.ObjectRunId = @ObjectRunId;
        END
        ELSE IF EXISTS
        (
            SELECT 1
            FROM rt.WorkSet
            WHERE ObjectRunId = @ObjectRunId
        )
            THROW 54143, 'PlanObjectWork: work sets already exist for the object run.', 1;

        UPDATE rt.ObjectRun
        SET
            Status = 'running',
            StateStatus = 'running',
            StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
            EndedAt = NULL,
            Message = CONCAT(
                N'Planning work items from source snapshot ',
                CONVERT(NVARCHAR(30), @LatestSourceSnapshotRunId),
                N'.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        IF @RefreshStateStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'running',
                StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
                EndedAt = NULL,
                Message = CONCAT(
                    N'Comparing source snapshot ',
                    CONVERT(NVARCHAR(30), @LatestSourceSnapshotRunId),
                    N' to canonical object state.'
                )
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshState';
        END;

        SELECT
            @ActiveStateRowCount = SUM(CASE WHEN objectState.IsDeleted = 0 THEN 1 ELSE 0 END),
            @DeletedStateRowCount = SUM(CASE WHEN objectState.IsDeleted = 1 THEN 1 ELSE 0 END)
        FROM rt.ObjectState objectState
        WHERE objectState.SyncObjectId = @SyncObjectId;

        SELECT
            @InsertCount = COUNT(*)
        FROM rt.SourceCurrent sourceCurrent
        LEFT JOIN rt.ObjectState objectState
            ON objectState.SyncObjectId = @SyncObjectId
           AND objectState.BusinessKey = sourceCurrent.BusinessKey
        WHERE sourceCurrent.SyncObjectId = @SyncObjectId
          AND (
                objectState.ObjectStateId IS NULL
                OR objectState.IsDeleted = 1
              );

        SELECT
            @UpdateCount = COUNT(*)
        FROM rt.SourceCurrent sourceCurrent
        INNER JOIN rt.ObjectState objectState
            ON objectState.SyncObjectId = @SyncObjectId
           AND objectState.BusinessKey = sourceCurrent.BusinessKey
        WHERE sourceCurrent.SyncObjectId = @SyncObjectId
          AND objectState.IsDeleted = 0
          AND
          (
              (sourceCurrent.SourceHash IS NULL AND objectState.CurrentSourceHash IS NOT NULL)
              OR (sourceCurrent.SourceHash IS NOT NULL AND objectState.CurrentSourceHash IS NULL)
              OR (sourceCurrent.SourceHash <> objectState.CurrentSourceHash)
          );

        SELECT
            @DeleteCount = COUNT(*)
        FROM rt.ObjectState objectState
        LEFT JOIN rt.SourceCurrent sourceCurrent
            ON sourceCurrent.SyncObjectId = @SyncObjectId
           AND sourceCurrent.BusinessKey = objectState.BusinessKey
        WHERE objectState.SyncObjectId = @SyncObjectId
          AND objectState.IsDeleted = 0
          AND objectState.DestinationRecordId IS NOT NULL
          AND sourceCurrent.SourceCurrentId IS NULL;

        INSERT INTO rt.WorkSet
        (
            ObjectRunId,
            OperationCode,
            PlannedItemCount,
            BatchSize,
            Status,
            Message
        )
        SELECT
            @ObjectRunId,
            op.OperationCode,
            CASE op.OperationCode
                WHEN 'I' THEN @InsertCount
                WHEN 'U' THEN @UpdateCount
                WHEN 'D' THEN @DeleteCount
                WHEN 'R' THEN @RefreshCount
                ELSE 0
            END AS PlannedItemCount,
            @BatchSize,
            CASE
                WHEN CASE op.OperationCode
                    WHEN 'I' THEN @InsertCount
                    WHEN 'U' THEN @UpdateCount
                    WHEN 'D' THEN @DeleteCount
                    WHEN 'R' THEN @RefreshCount
                    ELSE 0
                END = 0
                THEN 'skipped'
                ELSE 'ready'
            END AS Status,
            CASE op.OperationCode
                WHEN 'I' THEN CONCAT(N'Planned insert candidates: ', CONVERT(NVARCHAR(30), @InsertCount), N'.')
                WHEN 'U' THEN CONCAT(N'Planned update candidates: ', CONVERT(NVARCHAR(30), @UpdateCount), N'.')
                WHEN 'D' THEN CONCAT(N'Planned delete candidates: ', CONVERT(NVARCHAR(30), @DeleteCount), N'.')
                WHEN 'R' THEN N'Refresh operation planning is reserved for a future V3 slice.'
            END AS Message
        FROM meta.SyncObjectOperation op
        WHERE op.SyncObjectId = @SyncObjectId
          AND op.IsEnabled = 1;

        INSERT INTO rt.WorkItem
        (
            WorkSetId,
            BusinessKey,
            DestinationRecordId,
            SourceHash,
            PayloadJson,
            ResultStatus
        )
        SELECT
            workSet.WorkSetId,
            sourceCurrent.BusinessKey,
            objectState.DestinationRecordId,
            sourceCurrent.SourceHash,
            sourceCurrent.SourcePayloadJson,
            'ready'
        FROM rt.WorkSet workSet
        INNER JOIN rt.SourceCurrent sourceCurrent
            ON sourceCurrent.SyncObjectId = @SyncObjectId
        LEFT JOIN rt.ObjectState objectState
            ON objectState.SyncObjectId = @SyncObjectId
           AND objectState.BusinessKey = sourceCurrent.BusinessKey
        WHERE workSet.ObjectRunId = @ObjectRunId
          AND workSet.OperationCode = 'I'
          AND (
                objectState.ObjectStateId IS NULL
                OR objectState.IsDeleted = 1
              );

        INSERT INTO rt.WorkItem
        (
            WorkSetId,
            BusinessKey,
            DestinationRecordId,
            SourceHash,
            PayloadJson,
            ResultStatus
        )
        SELECT
            workSet.WorkSetId,
            sourceCurrent.BusinessKey,
            objectState.DestinationRecordId,
            sourceCurrent.SourceHash,
            sourceCurrent.SourcePayloadJson,
            'ready'
        FROM rt.WorkSet workSet
        INNER JOIN rt.SourceCurrent sourceCurrent
            ON sourceCurrent.SyncObjectId = @SyncObjectId
        INNER JOIN rt.ObjectState objectState
            ON objectState.SyncObjectId = @SyncObjectId
           AND objectState.BusinessKey = sourceCurrent.BusinessKey
        WHERE workSet.ObjectRunId = @ObjectRunId
          AND workSet.OperationCode = 'U'
          AND objectState.IsDeleted = 0
          AND
          (
              (sourceCurrent.SourceHash IS NULL AND objectState.CurrentSourceHash IS NOT NULL)
              OR (sourceCurrent.SourceHash IS NOT NULL AND objectState.CurrentSourceHash IS NULL)
              OR (sourceCurrent.SourceHash <> objectState.CurrentSourceHash)
          );

        INSERT INTO rt.WorkItem
        (
            WorkSetId,
            BusinessKey,
            DestinationRecordId,
            SourceHash,
            PayloadJson,
            ResultStatus
        )
        SELECT
            workSet.WorkSetId,
            objectState.BusinessKey,
            objectState.DestinationRecordId,
            objectState.CurrentSourceHash,
            ISNULL(objectState.CurrentPayloadJson, N'{}'),
            'ready'
        FROM rt.WorkSet workSet
        INNER JOIN rt.ObjectState objectState
            ON objectState.SyncObjectId = @SyncObjectId
        LEFT JOIN rt.SourceCurrent sourceCurrent
            ON sourceCurrent.SyncObjectId = @SyncObjectId
           AND sourceCurrent.BusinessKey = objectState.BusinessKey
        WHERE workSet.ObjectRunId = @ObjectRunId
          AND workSet.OperationCode = 'D'
          AND objectState.IsDeleted = 0
          AND objectState.DestinationRecordId IS NOT NULL
          AND sourceCurrent.SourceCurrentId IS NULL;

        UPDATE step
        SET
            Status = CASE WHEN workSet.PlannedItemCount = 0 THEN 'skipped' ELSE 'completed' END,
            StartedAt = ISNULL(step.StartedAt, SYSUTCDATETIME()),
            EndedAt = SYSUTCDATETIME(),
            Message = CASE workSet.OperationCode
                WHEN 'I' THEN CONCAT(N'Planned ', CONVERT(NVARCHAR(30), workSet.PlannedItemCount), N' inserts.')
                WHEN 'U' THEN CONCAT(N'Planned ', CONVERT(NVARCHAR(30), workSet.PlannedItemCount), N' updates.')
                WHEN 'D' THEN CONCAT(N'Planned ', CONVERT(NVARCHAR(30), workSet.PlannedItemCount), N' deletes.')
                WHEN 'R' THEN N'Refresh operation planning is reserved for a future V3 slice.'
            END
        FROM rt.ObjectRunStep step
        INNER JOIN rt.WorkSet workSet
            ON workSet.ObjectRunId = step.ObjectRunId
           AND workSet.OperationCode = step.OperationCode
        WHERE step.ObjectRunId = @ObjectRunId
          AND step.StepCode LIKE 'Plan%';

        IF @InsertCount + @UpdateCount + @DeleteCount + @RefreshCount = 0
        BEGIN
            UPDATE rt.ObjectRun
            SET
                DispatchStatus = 'skipped'
            WHERE ObjectRunId = @ObjectRunId;

            UPDATE step
            SET
                step.Status = 'skipped',
                step.StartedAt = ISNULL(step.StartedAt, SYSUTCDATETIME()),
                step.EndedAt = SYSUTCDATETIME(),
                step.Message = 'No work items were required after source/state comparison.'
            FROM rt.ObjectRunStep step
            WHERE step.ObjectRunId = @ObjectRunId
              AND step.StepCode IN ('BuildBatches', 'DispatchBatches', 'ReconcileResults')
              AND step.Status = 'planned';
        END;

        IF @RefreshStateStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'completed',
                EndedAt = SYSUTCDATETIME(),
                Message = CONCAT(
                    N'Loaded ',
                    CONVERT(NVARCHAR(30), @ActiveStateRowCount),
                    N' active and ',
                    CONVERT(NVARCHAR(30), @DeletedStateRowCount),
                    N' deleted canonical state rows before work planning.'
                )
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'RefreshState';
        END;

        UPDATE rt.ObjectRun
        SET
            StateStatus = 'completed',
            Status = 'ready',
            Message = CONCAT(
                N'Planned work from source snapshot ',
                CONVERT(NVARCHAR(30), @LatestSourceSnapshotRunId),
                N' for object ',
                @ObjectCode,
                N'. Inserts=',
                CONVERT(NVARCHAR(30), @InsertCount),
                N', Updates=',
                CONVERT(NVARCHAR(30), @UpdateCount),
                N', Deletes=',
                CONVERT(NVARCHAR(30), @DeleteCount),
                N'.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        SELECT
            @ObjectRunId AS ObjectRunId,
            @ObjectCode AS ObjectCode,
            @LatestSourceSnapshotRunId AS SourceSnapshotRunId,
            @InsertCount AS InsertCount,
            @UpdateCount AS UpdateCount,
            @DeleteCount AS DeleteCount;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE rt.ObjectRun
        SET
            StateStatus = 'failed',
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId;

        UPDATE rt.ObjectRunStep
        SET
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId
          AND (StepCode = 'RefreshState' OR StepCode LIKE 'Plan%')
          AND Status <> 'completed';

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE rt.ExecutePlannedWorkPreparation
    @PipelineRunId BIGINT,
    @ObjectList VARCHAR(MAX) = NULL,
    @StopOnError BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @ObjectRunId BIGINT,
        @ProcessedObjectCount INT = 0,
        @FailedObjectCount INT = 0,
        @ErrorMessage NVARCHAR(MAX);

    IF NOT EXISTS
    (
        SELECT 1
        FROM rt.PipelineRun
        WHERE PipelineRunId = @PipelineRunId
    )
        THROW 54160, 'ExecutePlannedWorkPreparation: pipeline run was not found.', 1;

    UPDATE rt.PipelineRun
    SET
        Status = 'running',
        StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
        EndedAt = NULL,
        Message = 'Preparing work sets from completed source snapshots.'
    WHERE PipelineRunId = @PipelineRunId;

    DECLARE object_cursor CURSOR LOCAL FAST_FORWARD FOR
    WITH RequestedObjects AS
    (
        SELECT DISTINCT LTRIM(RTRIM([value])) AS ObjectCode
        FROM STRING_SPLIT(ISNULL(@ObjectList, ''), ',')
        WHERE LTRIM(RTRIM([value])) <> ''
    )
    SELECT objectRun.ObjectRunId
    FROM rt.ObjectRun objectRun
    INNER JOIN meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objectRun.SyncObjectId
    LEFT JOIN RequestedObjects requested
        ON requested.ObjectCode = syncObj.ObjectCode
    WHERE objectRun.PipelineRunId = @PipelineRunId
      AND (ISNULL(@ObjectList, '') = '' OR requested.ObjectCode = syncObj.ObjectCode)
      AND EXISTS
      (
          SELECT 1
          FROM rt.SourceSnapshotRun snapshotRun
          WHERE snapshotRun.ObjectRunId = objectRun.ObjectRunId
            AND snapshotRun.Status = 'completed'
      )
    ORDER BY objectRun.ExecutionOrder, objectRun.ObjectRunId;

    OPEN object_cursor;

    FETCH NEXT FROM object_cursor INTO @ObjectRunId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC rt.PlanObjectWork
                @ObjectRunId = @ObjectRunId,
                @ResetWork = 1;

            SET @ProcessedObjectCount += 1;
        END TRY
        BEGIN CATCH
            SET @FailedObjectCount += 1;
            SET @ErrorMessage = ERROR_MESSAGE();

            IF @StopOnError = 1
            BEGIN
                CLOSE object_cursor;
                DEALLOCATE object_cursor;

                UPDATE rt.PipelineRun
                SET
                    Status = 'failed',
                    EndedAt = SYSUTCDATETIME(),
                    Message = CONCAT(
                        N'Work preparation failed after ',
                        CONVERT(NVARCHAR(30), @ProcessedObjectCount),
                        N' completed objects. Last error: ',
                        @ErrorMessage
                    )
                WHERE PipelineRunId = @PipelineRunId;

                THROW;
            END;
        END CATCH;

        FETCH NEXT FROM object_cursor INTO @ObjectRunId;
    END;

    CLOSE object_cursor;
    DEALLOCATE object_cursor;

    UPDATE rt.PipelineRun
    SET
        Status = CASE WHEN @FailedObjectCount > 0 THEN 'failed' ELSE 'ready' END,
        Message = CASE
            WHEN @FailedObjectCount > 0 THEN CONCAT(
                N'Work preparation completed with ',
                CONVERT(NVARCHAR(30), @FailedObjectCount),
                N' failed objects and ',
                CONVERT(NVARCHAR(30), @ProcessedObjectCount),
                N' successful objects.'
            )
            ELSE CONCAT(
                N'Work preparation completed for ',
                CONVERT(NVARCHAR(30), @ProcessedObjectCount),
                N' objects.'
            )
        END
    WHERE PipelineRunId = @PipelineRunId;

    SELECT
        @PipelineRunId AS PipelineRunId,
        @ProcessedObjectCount AS SuccessfulObjectCount,
        @FailedObjectCount AS FailedObjectCount;
END;
GO

CREATE OR ALTER VIEW rt.vw_WorkPlanSummary
AS
SELECT
    pipelineRun.PipelineRunId,
    client.ClientCode,
    objectRun.ObjectRunId,
    syncObj.ObjectCode,
    workSet.WorkSetId,
    workSet.OperationCode,
    workSet.PlannedItemCount,
    workSet.BatchSize,
    workSet.Status AS WorkSetStatus,
    COUNT(workItem.WorkItemId) AS MaterializedItemCount,
    MIN(workItem.CreatedAt) AS FirstItemCreatedAt,
    MAX(workItem.CreatedAt) AS LastItemCreatedAt
FROM rt.WorkSet workSet
INNER JOIN rt.ObjectRun objectRun
    ON objectRun.ObjectRunId = workSet.ObjectRunId
INNER JOIN rt.PipelineRun pipelineRun
    ON pipelineRun.PipelineRunId = objectRun.PipelineRunId
INNER JOIN cfg.IntegrationClient client
    ON client.IntegrationClientId = pipelineRun.IntegrationClientId
INNER JOIN meta.SyncObject syncObj
    ON syncObj.SyncObjectId = objectRun.SyncObjectId
LEFT JOIN rt.WorkItem workItem
    ON workItem.WorkSetId = workSet.WorkSetId
GROUP BY
    pipelineRun.PipelineRunId,
    client.ClientCode,
    objectRun.ObjectRunId,
    syncObj.ObjectCode,
    workSet.WorkSetId,
    workSet.OperationCode,
    workSet.PlannedItemCount,
    workSet.BatchSize,
    workSet.Status;
GO

CREATE OR ALTER PROCEDURE rt.BuildBatchRequests
    @WorkSetId BIGINT,
    @ResetBatches BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @ObjectRunId BIGINT,
        @SyncObjectId INT,
        @ClientCode VARCHAR(50),
        @ObjectCode VARCHAR(80),
        @OperationCode CHAR(1),
        @BatchSize INT,
        @DestinationObjectName VARCHAR(120),
        @WorkItemCount INT = 0,
        @PreparedItemCount INT = 0,
        @BatchRequestCount INT = 0,
        @BuildBatchesStepExists BIT = 0,
        @ErrorMessage NVARCHAR(MAX);

    BEGIN TRY
        SELECT
            @ObjectRunId = workSet.ObjectRunId,
            @SyncObjectId = syncObj.SyncObjectId,
            @ClientCode = client.ClientCode,
            @ObjectCode = syncObj.ObjectCode,
            @OperationCode = workSet.OperationCode,
            @BatchSize = workSet.BatchSize,
            @DestinationObjectName = syncObj.DestinationObjectName
        FROM rt.WorkSet workSet
        INNER JOIN rt.ObjectRun objectRun
            ON objectRun.ObjectRunId = workSet.ObjectRunId
        INNER JOIN meta.SyncObject syncObj
            ON syncObj.SyncObjectId = objectRun.SyncObjectId
        INNER JOIN cfg.IntegrationClient client
            ON client.IntegrationClientId = syncObj.IntegrationClientId
        WHERE workSet.WorkSetId = @WorkSetId;

        IF @ObjectRunId IS NULL
            THROW 54180, 'BuildBatchRequests: work set was not found.', 1;

        IF NULLIF(@DestinationObjectName, '') IS NULL
            THROW 54181, 'BuildBatchRequests: destination object name is not configured.', 1;

        SELECT @BuildBatchesStepExists = CASE WHEN EXISTS
        (
            SELECT 1
            FROM rt.ObjectRunStep
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'BuildBatches'
        )
        THEN 1 ELSE 0 END;

        IF @ResetBatches = 1
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM rt.BatchRequest batchRequest
                WHERE batchRequest.WorkSetId = @WorkSetId
                  AND
                  (
                      batchRequest.StartedAt IS NOT NULL
                      OR batchRequest.EndedAt IS NOT NULL
                      OR batchRequest.ResponsePayloadJson IS NOT NULL
                      OR batchRequest.TransportStatus IN ('running', 'completed', 'failed')
                  )
            )
                THROW 54182, 'BuildBatchRequests: existing transport history prevents batch reset for this work set.', 1;

            DELETE batchRequestItem
            FROM rt.BatchRequestItem batchRequestItem
            INNER JOIN rt.BatchRequest batchRequest
                ON batchRequest.BatchRequestId = batchRequestItem.BatchRequestId
            WHERE batchRequest.WorkSetId = @WorkSetId;

            DELETE batchRequest
            FROM rt.BatchRequest batchRequest
            WHERE batchRequest.WorkSetId = @WorkSetId;
        END
        ELSE IF EXISTS
        (
            SELECT 1
            FROM rt.BatchRequest
            WHERE WorkSetId = @WorkSetId
        )
            THROW 54183, 'BuildBatchRequests: batch requests already exist for the work set.', 1;

        UPDATE rt.WorkSet
        SET
            Status = CASE WHEN PlannedItemCount = 0 THEN 'skipped' ELSE 'running' END,
            StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
            EndedAt = NULL,
            Message = CASE
                WHEN PlannedItemCount = 0 THEN 'No work items are available for batch generation.'
                ELSE 'Building batch requests from work items.'
            END
        WHERE WorkSetId = @WorkSetId;

        IF @BuildBatchesStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'running',
                StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
                EndedAt = NULL,
                Message = CONCAT(N'Building batch requests for operation ', @OperationCode, N'.')
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'BuildBatches';
        END;

        SELECT
            @WorkItemCount = COUNT(*)
        FROM rt.WorkItem
        WHERE WorkSetId = @WorkSetId
          AND ResultStatus IN ('planned', 'ready');

        IF @WorkItemCount = 0
        BEGIN
            UPDATE rt.WorkSet
            SET
                Status = 'skipped',
                EndedAt = SYSUTCDATETIME(),
                Message = 'No eligible work items were found for batch generation.'
            WHERE WorkSetId = @WorkSetId;

            IF @BuildBatchesStepExists = 1
            BEGIN
                UPDATE rt.ObjectRunStep
                SET
                    Status = 'skipped',
                    EndedAt = SYSUTCDATETIME(),
                    Message = 'No eligible work items were found for batch generation.'
                WHERE ObjectRunId = @ObjectRunId
                  AND StepCode = 'BuildBatches'
                  AND Status <> 'completed';
            END;

            SELECT
                @WorkSetId AS WorkSetId,
                @OperationCode AS OperationCode,
                0 AS WorkItemCount,
                0 AS BatchRequestCount;

            RETURN;
        END;

        CREATE TABLE #PreparedWorkItem
        (
            WorkItemId BIGINT NOT NULL,
            BatchNumber INT NOT NULL,
            ItemSequence INT NOT NULL,
            RequestItemJson NVARCHAR(MAX) NOT NULL,
            PRIMARY KEY CLUSTERED (WorkItemId)
        );

        IF @OperationCode IN ('I', 'U')
        BEGIN
            ;WITH MappedFieldPayload AS
            (
                SELECT
                    workItem.WorkItemId,
                    workItem.BusinessKey,
                    workItem.DestinationRecordId,
                    N'{' + STRING_AGG(
                        N'"' + STRING_ESCAPE(fieldMap.OutboundFieldName, 'json') + N'":' +
                        CASE sourceJson.[type]
                            WHEN 0 THEN N'null'
                            WHEN 1 THEN N'"' + STRING_ESCAPE(sourceJson.[value], 'json') + N'"'
                            WHEN 2 THEN sourceJson.[value]
                            WHEN 3 THEN LOWER(sourceJson.[value])
                            WHEN 4 THEN sourceJson.[value]
                            WHEN 5 THEN sourceJson.[value]
                            ELSE N'null'
                        END,
                        N','
                    ) WITHIN GROUP (ORDER BY ISNULL(fieldMap.DisplayOrder, 2147483647), fieldMap.FieldMapId) + N'}' AS ValuesJson
                FROM rt.WorkItem workItem
                INNER JOIN meta.FieldMap fieldMap
                    ON fieldMap.SyncObjectId = @SyncObjectId
                   AND fieldMap.IsEnabled = 1
                   AND fieldMap.IncludeInOutbound = 1
                   AND NULLIF(LTRIM(RTRIM(ISNULL(fieldMap.OutboundFieldName, ''))), '') IS NOT NULL
                CROSS APPLY OPENJSON(workItem.PayloadJson) sourceJson
                WHERE workItem.WorkSetId = @WorkSetId
                  AND workItem.ResultStatus IN ('planned', 'ready')
                  AND sourceJson.[key] = fieldMap.SourceFieldName COLLATE Latin1_General_BIN2
                GROUP BY
                    workItem.WorkItemId,
                    workItem.BusinessKey,
                    workItem.DestinationRecordId
            ),
            NumberedItem AS
            (
                SELECT
                    mapped.WorkItemId,
                    ROW_NUMBER() OVER (ORDER BY mapped.WorkItemId) AS RowNumber,
                    mapped.BusinessKey,
                    mapped.DestinationRecordId,
                    mapped.ValuesJson
                FROM MappedFieldPayload mapped
            )
            INSERT INTO #PreparedWorkItem
            (
                WorkItemId,
                BatchNumber,
                ItemSequence,
                RequestItemJson
            )
            SELECT
                numbered.WorkItemId,
                ((numbered.RowNumber - 1) / @BatchSize) + 1,
                ((numbered.RowNumber - 1) % @BatchSize) + 1,
                N'{"businessKey":"' + STRING_ESCAPE(numbered.BusinessKey, 'json') +
                N'","destinationRecordId":' +
                CASE
                    WHEN numbered.DestinationRecordId IS NULL THEN N'null'
                    ELSE N'"' + STRING_ESCAPE(numbered.DestinationRecordId, 'json') + N'"'
                END +
                N',"values":' + numbered.ValuesJson + N'}'
            FROM NumberedItem numbered;
        END
        ELSE IF @OperationCode = 'D'
        BEGIN
            ;WITH NumberedItem AS
            (
                SELECT
                    workItem.WorkItemId,
                    ROW_NUMBER() OVER (ORDER BY workItem.WorkItemId) AS RowNumber,
                    workItem.BusinessKey,
                    workItem.DestinationRecordId
                FROM rt.WorkItem workItem
                WHERE workItem.WorkSetId = @WorkSetId
                  AND workItem.ResultStatus IN ('planned', 'ready')
                  AND workItem.DestinationRecordId IS NOT NULL
            )
            INSERT INTO #PreparedWorkItem
            (
                WorkItemId,
                BatchNumber,
                ItemSequence,
                RequestItemJson
            )
            SELECT
                numbered.WorkItemId,
                ((numbered.RowNumber - 1) / @BatchSize) + 1,
                ((numbered.RowNumber - 1) % @BatchSize) + 1,
                N'{"businessKey":"' + STRING_ESCAPE(numbered.BusinessKey, 'json') +
                N'","destinationRecordId":"' + STRING_ESCAPE(numbered.DestinationRecordId, 'json') + N'"}'
            FROM NumberedItem numbered;
        END
        ELSE
            THROW 54184, 'BuildBatchRequests: operation is not supported for batch generation.', 1;

        SELECT
            @PreparedItemCount = COUNT(*)
        FROM #PreparedWorkItem;

        IF @PreparedItemCount <> @WorkItemCount
            THROW 54185, 'BuildBatchRequests: one or more work items could not be shaped into outbound payloads.', 1;

        CREATE TABLE #InsertedBatchRequest
        (
            BatchRequestId BIGINT NOT NULL,
            BatchNumber INT NOT NULL,
            PRIMARY KEY CLUSTERED (BatchNumber)
        );

        ;WITH BatchPayload AS
        (
            SELECT
                prepared.BatchNumber,
                N'{"clientCode":"' + STRING_ESCAPE(@ClientCode, 'json') +
                N'","objectCode":"' + STRING_ESCAPE(@ObjectCode, 'json') +
                N'","destinationObject":"' + STRING_ESCAPE(@DestinationObjectName, 'json') +
                N'","operation":"' + @OperationCode +
                N'","batchNumber":' + CONVERT(NVARCHAR(30), prepared.BatchNumber) +
                N',"recordCount":' + CONVERT(NVARCHAR(30), COUNT(*)) +
                N',"records":[' +
                STRING_AGG(prepared.RequestItemJson, N',') WITHIN GROUP (ORDER BY prepared.ItemSequence) +
                N']}' AS RequestPayloadJson
            FROM #PreparedWorkItem prepared
            GROUP BY prepared.BatchNumber
        )
        INSERT INTO rt.BatchRequest
        (
            WorkSetId,
            BatchNumber,
            RequestPayloadJson,
            TransportStatus
        )
        OUTPUT inserted.BatchRequestId, inserted.BatchNumber
            INTO #InsertedBatchRequest
            (
                BatchRequestId,
                BatchNumber
            )
        SELECT
            @WorkSetId,
            batchPayload.BatchNumber,
            batchPayload.RequestPayloadJson,
            'ready'
        FROM BatchPayload batchPayload
        ORDER BY batchPayload.BatchNumber;

        INSERT INTO rt.BatchRequestItem
        (
            BatchRequestId,
            WorkItemId,
            ItemSequence,
            RequestItemJson
        )
        SELECT
            insertedBatch.BatchRequestId,
            prepared.WorkItemId,
            prepared.ItemSequence,
            prepared.RequestItemJson
        FROM #PreparedWorkItem prepared
        INNER JOIN #InsertedBatchRequest insertedBatch
            ON insertedBatch.BatchNumber = prepared.BatchNumber;

        SELECT
            @BatchRequestCount = COUNT(*)
        FROM #InsertedBatchRequest;

        UPDATE rt.WorkSet
        SET
            Status = 'ready',
            EndedAt = SYSUTCDATETIME(),
            Message = CONCAT(
                N'Built ',
                CONVERT(NVARCHAR(30), @BatchRequestCount),
                N' batch requests from ',
                CONVERT(NVARCHAR(30), @PreparedItemCount),
                N' work items.'
            )
        WHERE WorkSetId = @WorkSetId;

        UPDATE rt.ObjectRun
        SET
            Status = 'ready',
            Message = CONCAT(
                N'Built batch requests for operation ',
                @OperationCode,
                N' on object ',
                @ObjectCode,
                N'.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        IF @BuildBatchesStepExists = 1
        BEGIN
            UPDATE rt.ObjectRunStep
            SET
                Status = 'completed',
                EndedAt = SYSUTCDATETIME(),
                Message = CONCAT(
                    N'Built ',
                    CONVERT(NVARCHAR(30), @BatchRequestCount),
                    N' batch requests from ',
                    CONVERT(NVARCHAR(30), @PreparedItemCount),
                    N' work items.'
                )
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'BuildBatches';
        END;

        SELECT
            @WorkSetId AS WorkSetId,
            @OperationCode AS OperationCode,
            @PreparedItemCount AS WorkItemCount,
            @BatchRequestCount AS BatchRequestCount;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE rt.WorkSet
        SET
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE WorkSetId = @WorkSetId;

        IF @ObjectRunId IS NOT NULL
        BEGIN
            UPDATE rt.ObjectRun
            SET
                Status = 'failed',
                EndedAt = SYSUTCDATETIME(),
                Message = @ErrorMessage
            WHERE ObjectRunId = @ObjectRunId;

            UPDATE rt.ObjectRunStep
            SET
                Status = 'failed',
                EndedAt = SYSUTCDATETIME(),
                Message = @ErrorMessage
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode = 'BuildBatches'
              AND Status <> 'completed';
        END;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE rt.ExecutePlannedBatchPreparation
    @PipelineRunId BIGINT,
    @ObjectList VARCHAR(MAX) = NULL,
    @StopOnError BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @WorkSetId BIGINT,
        @ProcessedWorkSetCount INT = 0,
        @FailedWorkSetCount INT = 0,
        @ErrorMessage NVARCHAR(MAX);

    IF NOT EXISTS
    (
        SELECT 1
        FROM rt.PipelineRun
        WHERE PipelineRunId = @PipelineRunId
    )
        THROW 54200, 'ExecutePlannedBatchPreparation: pipeline run was not found.', 1;

    UPDATE rt.PipelineRun
    SET
        Status = 'running',
        StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
        EndedAt = NULL,
        Message = 'Building batch requests from ready work sets.'
    WHERE PipelineRunId = @PipelineRunId;

    DECLARE workset_cursor CURSOR LOCAL FAST_FORWARD FOR
    WITH RequestedObjects AS
    (
        SELECT DISTINCT LTRIM(RTRIM([value])) AS ObjectCode
        FROM STRING_SPLIT(ISNULL(@ObjectList, ''), ',')
        WHERE LTRIM(RTRIM([value])) <> ''
    )
    SELECT workSet.WorkSetId
    FROM rt.WorkSet workSet
    INNER JOIN rt.ObjectRun objectRun
        ON objectRun.ObjectRunId = workSet.ObjectRunId
    INNER JOIN meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objectRun.SyncObjectId
    LEFT JOIN RequestedObjects requested
        ON requested.ObjectCode = syncObj.ObjectCode
    WHERE objectRun.PipelineRunId = @PipelineRunId
      AND (ISNULL(@ObjectList, '') = '' OR requested.ObjectCode = syncObj.ObjectCode)
      AND workSet.Status = 'ready'
      AND workSet.PlannedItemCount > 0
    ORDER BY
        objectRun.ExecutionOrder,
        CASE workSet.OperationCode
            WHEN 'D' THEN 1
            WHEN 'I' THEN 2
            WHEN 'U' THEN 3
            WHEN 'R' THEN 4
            ELSE 9
        END,
        workSet.WorkSetId;

    OPEN workset_cursor;

    FETCH NEXT FROM workset_cursor INTO @WorkSetId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC rt.BuildBatchRequests
                @WorkSetId = @WorkSetId,
                @ResetBatches = 1;

            SET @ProcessedWorkSetCount += 1;
        END TRY
        BEGIN CATCH
            SET @FailedWorkSetCount += 1;
            SET @ErrorMessage = ERROR_MESSAGE();

            IF @StopOnError = 1
            BEGIN
                CLOSE workset_cursor;
                DEALLOCATE workset_cursor;

                UPDATE rt.PipelineRun
                SET
                    Status = 'failed',
                    EndedAt = SYSUTCDATETIME(),
                    Message = CONCAT(
                        N'Batch preparation failed after ',
                        CONVERT(NVARCHAR(30), @ProcessedWorkSetCount),
                        N' completed work sets. Last error: ',
                        @ErrorMessage
                    )
                WHERE PipelineRunId = @PipelineRunId;

                THROW;
            END;
        END CATCH;

        FETCH NEXT FROM workset_cursor INTO @WorkSetId;
    END;

    CLOSE workset_cursor;
    DEALLOCATE workset_cursor;

    UPDATE rt.PipelineRun
    SET
        Status = CASE WHEN @FailedWorkSetCount > 0 THEN 'failed' ELSE 'ready' END,
        Message = CASE
            WHEN @FailedWorkSetCount > 0 THEN CONCAT(
                N'Batch preparation completed with ',
                CONVERT(NVARCHAR(30), @FailedWorkSetCount),
                N' failed work sets and ',
                CONVERT(NVARCHAR(30), @ProcessedWorkSetCount),
                N' successful work sets.'
            )
            ELSE CONCAT(
                N'Batch preparation completed for ',
                CONVERT(NVARCHAR(30), @ProcessedWorkSetCount),
                N' work sets.'
            )
        END
    WHERE PipelineRunId = @PipelineRunId;

    SELECT
        @PipelineRunId AS PipelineRunId,
        @ProcessedWorkSetCount AS SuccessfulWorkSetCount,
        @FailedWorkSetCount AS FailedWorkSetCount;
END;
GO

CREATE OR ALTER VIEW rt.vw_BatchRequestSummary
AS
SELECT
    pipelineRun.PipelineRunId,
    client.ClientCode,
    objectRun.ObjectRunId,
    syncObj.ObjectCode,
    workSet.WorkSetId,
    workSet.OperationCode,
    batchRequest.BatchRequestId,
    batchRequest.BatchNumber,
    batchRequest.TransportStatus,
    COUNT(batchRequestItem.BatchRequestItemId) AS BatchItemCount,
    MIN(batchRequestItem.ItemSequence) AS FirstItemSequence,
    MAX(batchRequestItem.ItemSequence) AS LastItemSequence,
    batchRequest.CreatedAt
FROM rt.BatchRequest batchRequest
INNER JOIN rt.WorkSet workSet
    ON workSet.WorkSetId = batchRequest.WorkSetId
INNER JOIN rt.ObjectRun objectRun
    ON objectRun.ObjectRunId = workSet.ObjectRunId
INNER JOIN rt.PipelineRun pipelineRun
    ON pipelineRun.PipelineRunId = objectRun.PipelineRunId
INNER JOIN cfg.IntegrationClient client
    ON client.IntegrationClientId = pipelineRun.IntegrationClientId
INNER JOIN meta.SyncObject syncObj
    ON syncObj.SyncObjectId = objectRun.SyncObjectId
LEFT JOIN rt.BatchRequestItem batchRequestItem
    ON batchRequestItem.BatchRequestId = batchRequest.BatchRequestId
GROUP BY
    pipelineRun.PipelineRunId,
    client.ClientCode,
    objectRun.ObjectRunId,
    syncObj.ObjectCode,
    workSet.WorkSetId,
    workSet.OperationCode,
    batchRequest.BatchRequestId,
    batchRequest.BatchNumber,
    batchRequest.TransportStatus,
    batchRequest.CreatedAt;
GO

CREATE OR ALTER PROCEDURE rt.DispatchBatchRequest
    @BatchRequestId BIGINT,
    @DispatchMode VARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @PipelineRunId BIGINT,
        @ObjectRunId BIGINT,
        @SyncObjectId INT,
        @ClientCode VARCHAR(50),
        @ObjectCode VARCHAR(80),
        @OperationCode CHAR(1),
        @DestinationObjectName VARCHAR(120),
        @AllowDispatch BIT,
        @ResolvedDispatchMode VARCHAR(30),
        @WorkSetId BIGINT,
        @PendingBatchCount INT = 0,
        @FailedBatchCount INT = 0,
        @CompletedBatchCount INT = 0,
        @ResponsePayloadJson NVARCHAR(MAX),
        @Now DATETIME2(0) = SYSUTCDATETIME(),
        @ErrorMessage NVARCHAR(MAX);

    BEGIN TRY
        SELECT
            @PipelineRunId = pipelineRun.PipelineRunId,
            @ObjectRunId = objectRun.ObjectRunId,
            @SyncObjectId = syncObj.SyncObjectId,
            @ClientCode = client.ClientCode,
            @ObjectCode = syncObj.ObjectCode,
            @OperationCode = workSet.OperationCode,
            @DestinationObjectName = syncObj.DestinationObjectName,
            @AllowDispatch = pipelineRun.AllowDispatch,
            @WorkSetId = workSet.WorkSetId
        FROM rt.BatchRequest batchRequest
        INNER JOIN rt.WorkSet workSet
            ON workSet.WorkSetId = batchRequest.WorkSetId
        INNER JOIN rt.ObjectRun objectRun
            ON objectRun.ObjectRunId = workSet.ObjectRunId
        INNER JOIN rt.PipelineRun pipelineRun
            ON pipelineRun.PipelineRunId = objectRun.PipelineRunId
        INNER JOIN meta.SyncObject syncObj
            ON syncObj.SyncObjectId = objectRun.SyncObjectId
        INNER JOIN cfg.IntegrationClient client
            ON client.IntegrationClientId = pipelineRun.IntegrationClientId
        WHERE batchRequest.BatchRequestId = @BatchRequestId;

        IF @WorkSetId IS NULL
            THROW 54220, 'DispatchBatchRequest: batch request was not found.', 1;

        SELECT
            @ResolvedDispatchMode = COALESCE(
                NULLIF(@DispatchMode, ''),
                NULLIF(MAX(CASE WHEN setting.SettingName = 'V3_DISPATCH_MODE' THEN setting.SettingValue END), ''),
                'simulate'
            )
        FROM cfg.ClientSetting setting
        INNER JOIN cfg.IntegrationClient client
            ON client.IntegrationClientId = setting.IntegrationClientId
        WHERE client.ClientCode = @ClientCode;

        IF @ResolvedDispatchMode NOT IN ('simulate')
            THROW 54221, 'DispatchBatchRequest: dispatch mode is not supported yet. Supported mode: simulate.', 1;

        IF @AllowDispatch = 0
            THROW 54222, 'DispatchBatchRequest: pipeline run was not planned with AllowDispatch = 1.', 1;

        UPDATE rt.BatchRequest
        SET
            TransportStatus = 'running',
            StartedAt = ISNULL(StartedAt, @Now),
            EndedAt = NULL,
            ErrorMessage = NULL
        WHERE BatchRequestId = @BatchRequestId
          AND TransportStatus IN ('ready', 'planned');

        UPDATE workItem
        SET
            workItem.ResultStatus = 'running',
            workItem.AttemptCount = workItem.AttemptCount + 1,
            workItem.LastAttemptAt = @Now,
            workItem.UpdatedAt = @Now,
            workItem.ResultMessage = CONCAT(N'Dispatching batch request ', CONVERT(NVARCHAR(30), @BatchRequestId), N'.')
        FROM rt.WorkItem workItem
        INNER JOIN rt.BatchRequestItem batchRequestItem
            ON batchRequestItem.WorkItemId = workItem.WorkItemId
        WHERE batchRequestItem.BatchRequestId = @BatchRequestId
          AND workItem.ResultStatus IN ('planned', 'ready', 'running');

        UPDATE rt.ObjectRun
        SET
            Status = 'running',
            DispatchStatus = 'running',
            StartedAt = ISNULL(StartedAt, @Now),
            EndedAt = NULL,
            Message = CONCAT(N'Dispatching batch request ', CONVERT(NVARCHAR(30), @BatchRequestId), N'.')
        WHERE ObjectRunId = @ObjectRunId;

        UPDATE step
        SET
            step.Status = 'running',
            step.StartedAt = ISNULL(step.StartedAt, @Now),
            step.EndedAt = NULL,
            step.Message = CONCAT(N'Dispatching batch request ', CONVERT(NVARCHAR(30), @BatchRequestId), N'.')
        FROM rt.ObjectRunStep step
        WHERE step.ObjectRunId = @ObjectRunId
          AND step.StepCode = 'DispatchBatches';

        UPDATE step
        SET
            step.Status = 'running',
            step.StartedAt = ISNULL(step.StartedAt, @Now),
            step.EndedAt = NULL,
            step.Message = CONCAT(N'Reconciling batch request ', CONVERT(NVARCHAR(30), @BatchRequestId), N'.')
        FROM rt.ObjectRunStep step
        WHERE step.ObjectRunId = @ObjectRunId
          AND step.StepCode = 'ReconcileResults';

        CREATE TABLE #DispatchResult
        (
            BatchRequestItemId BIGINT NOT NULL,
            WorkItemId BIGINT NOT NULL,
            BusinessKey NVARCHAR(400) NOT NULL,
            DestinationRecordId VARCHAR(64) NULL,
            ResponseStatus VARCHAR(30) NOT NULL,
            ResponseItemJson NVARCHAR(MAX) NOT NULL,
            ErrorMessage NVARCHAR(MAX) NULL,
            PayloadJson NVARCHAR(MAX) NOT NULL,
            SourceHash VARBINARY(256) NULL,
            PRIMARY KEY CLUSTERED (BatchRequestItemId)
        );

        INSERT INTO #DispatchResult
        (
            BatchRequestItemId,
            WorkItemId,
            BusinessKey,
            DestinationRecordId,
            ResponseStatus,
            ResponseItemJson,
            ErrorMessage,
            PayloadJson,
            SourceHash
        )
        SELECT
            batchRequestItem.BatchRequestItemId,
            workItem.WorkItemId,
            workItem.BusinessKey,
            CASE
                WHEN @OperationCode IN ('I', 'U') THEN ISNULL(
                    workItem.DestinationRecordId,
                    'SIM' + RIGHT(REPLICATE('0', 15) + CONVERT(VARCHAR(15), workItem.WorkItemId), 15)
                )
                ELSE workItem.DestinationRecordId
            END AS DestinationRecordId,
            'completed',
            N'{"simulated":true,"success":true,"operation":"' + @OperationCode +
            N'","objectCode":"' + STRING_ESCAPE(@ObjectCode, 'json') +
            N'","businessKey":"' + STRING_ESCAPE(workItem.BusinessKey, 'json') +
            N'","destinationRecordId":' +
            CASE
                WHEN CASE
                    WHEN @OperationCode IN ('I', 'U') THEN ISNULL(workItem.DestinationRecordId, 'SIM' + RIGHT(REPLICATE('0', 15) + CONVERT(VARCHAR(15), workItem.WorkItemId), 15))
                    ELSE workItem.DestinationRecordId
                END IS NULL THEN N'null'
                ELSE N'"' + STRING_ESCAPE(
                    CASE
                        WHEN @OperationCode IN ('I', 'U') THEN ISNULL(workItem.DestinationRecordId, 'SIM' + RIGHT(REPLICATE('0', 15) + CONVERT(VARCHAR(15), workItem.WorkItemId), 15))
                        ELSE workItem.DestinationRecordId
                    END,
                    'json'
                ) + N'"'
            END +
            N',"completedAt":"' + CONVERT(NVARCHAR(30), @Now, 127) + N'"}',
            NULL,
            workItem.PayloadJson,
            workItem.SourceHash
        FROM rt.BatchRequestItem batchRequestItem
        INNER JOIN rt.WorkItem workItem
            ON workItem.WorkItemId = batchRequestItem.WorkItemId
        WHERE batchRequestItem.BatchRequestId = @BatchRequestId;

        SELECT
            @ResponsePayloadJson = N'{"mode":"' + @ResolvedDispatchMode +
            N'","batchRequestId":' + CONVERT(NVARCHAR(30), @BatchRequestId) +
            N',"destinationObject":"' + STRING_ESCAPE(@DestinationObjectName, 'json') +
            N'","operation":"' + @OperationCode +
            N'","results":[' +
            STRING_AGG(dispatchResult.ResponseItemJson, N',') WITHIN GROUP (ORDER BY dispatchResult.BatchRequestItemId) +
            N']}'
        FROM #DispatchResult dispatchResult;

        UPDATE batchRequestItem
        SET
            batchRequestItem.ResponseItemJson = dispatchResult.ResponseItemJson,
            batchRequestItem.ResponseStatus = dispatchResult.ResponseStatus,
            batchRequestItem.DestinationRecordId = dispatchResult.DestinationRecordId,
            batchRequestItem.ErrorMessage = dispatchResult.ErrorMessage
        FROM rt.BatchRequestItem batchRequestItem
        INNER JOIN #DispatchResult dispatchResult
            ON dispatchResult.BatchRequestItemId = batchRequestItem.BatchRequestItemId;

        UPDATE workItem
        SET
            workItem.ResultStatus = dispatchResult.ResponseStatus,
            workItem.DestinationRecordId = dispatchResult.DestinationRecordId,
            workItem.ResultMessage = CASE
                WHEN dispatchResult.ErrorMessage IS NULL THEN N'Simulated dispatch completed successfully.'
                ELSE dispatchResult.ErrorMessage
            END,
            workItem.UpdatedAt = @Now
        FROM rt.WorkItem workItem
        INNER JOIN #DispatchResult dispatchResult
            ON dispatchResult.WorkItemId = workItem.WorkItemId;

        IF @OperationCode IN ('I', 'U')
        BEGIN
            MERGE rt.ObjectState AS targetState
            USING
            (
                SELECT
                    @SyncObjectId AS SyncObjectId,
                    dispatchResult.BusinessKey,
                    dispatchResult.DestinationRecordId,
                    dispatchResult.SourceHash,
                    dispatchResult.PayloadJson
                FROM #DispatchResult dispatchResult
                WHERE dispatchResult.ResponseStatus = 'completed'
            ) AS sourceState
                ON targetState.SyncObjectId = sourceState.SyncObjectId
               AND targetState.BusinessKey = sourceState.BusinessKey
            WHEN MATCHED THEN
                UPDATE SET
                    DestinationRecordId = sourceState.DestinationRecordId,
                    CurrentSourceHash = sourceState.SourceHash,
                    CurrentStateHash = sourceState.SourceHash,
                    CurrentPayloadJson = sourceState.PayloadJson,
                    LastSeenAt = @Now,
                    LastAppliedAt = @Now,
                    IsDeleted = 0,
                    UpdatedAt = @Now
            WHEN NOT MATCHED THEN
                INSERT
                (
                    SyncObjectId,
                    BusinessKey,
                    DestinationRecordId,
                    CurrentSourceHash,
                    CurrentStateHash,
                    CurrentPayloadJson,
                    LastSeenAt,
                    LastAppliedAt,
                    IsDeleted,
                    CreatedAt,
                    UpdatedAt
                )
                VALUES
                (
                    sourceState.SyncObjectId,
                    sourceState.BusinessKey,
                    sourceState.DestinationRecordId,
                    sourceState.SourceHash,
                    sourceState.SourceHash,
                    sourceState.PayloadJson,
                    @Now,
                    @Now,
                    0,
                    @Now,
                    @Now
                );
        END;

        IF @OperationCode = 'D'
        BEGIN
            UPDATE objectState
            SET
                objectState.CurrentSourceHash = NULL,
                objectState.CurrentStateHash = NULL,
                objectState.CurrentPayloadJson = dispatchResult.PayloadJson,
                objectState.LastAppliedAt = @Now,
                objectState.IsDeleted = 1,
                objectState.UpdatedAt = @Now
            FROM rt.ObjectState objectState
            INNER JOIN #DispatchResult dispatchResult
                ON dispatchResult.BusinessKey = objectState.BusinessKey
            WHERE objectState.SyncObjectId = @SyncObjectId
              AND dispatchResult.ResponseStatus = 'completed';
        END;

        UPDATE rt.BatchRequest
        SET
            TransportStatus = 'completed',
            HttpStatusCode = 200,
            ResponsePayloadJson = @ResponsePayloadJson,
            EndedAt = @Now,
            ErrorMessage = NULL
        WHERE BatchRequestId = @BatchRequestId;

        SELECT
            @PendingBatchCount = SUM(CASE WHEN batchRequest.TransportStatus IN ('planned', 'ready', 'running') THEN 1 ELSE 0 END),
            @FailedBatchCount = SUM(CASE WHEN batchRequest.TransportStatus = 'failed' THEN 1 ELSE 0 END),
            @CompletedBatchCount = SUM(CASE WHEN batchRequest.TransportStatus = 'completed' THEN 1 ELSE 0 END)
        FROM rt.BatchRequest batchRequest
        WHERE batchRequest.WorkSetId = @WorkSetId;

        UPDATE rt.WorkSet
        SET
            Status = CASE
                WHEN @FailedBatchCount > 0 THEN 'failed'
                WHEN @PendingBatchCount > 0 THEN 'running'
                ELSE 'completed'
            END,
            StartedAt = ISNULL(StartedAt, @Now),
            EndedAt = CASE WHEN @PendingBatchCount = 0 THEN @Now ELSE NULL END,
            Message = CONCAT(
                N'Dispatch mode ',
                @ResolvedDispatchMode,
                N'. Completed batches=',
                CONVERT(NVARCHAR(30), @CompletedBatchCount),
                N', Pending batches=',
                CONVERT(NVARCHAR(30), @PendingBatchCount),
                N'.'
            )
        WHERE WorkSetId = @WorkSetId;

        UPDATE rt.ObjectRun
        SET
            DispatchStatus = CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM rt.BatchRequest batchRequest
                    INNER JOIN rt.WorkSet workSet
                        ON workSet.WorkSetId = batchRequest.WorkSetId
                    WHERE workSet.ObjectRunId = @ObjectRunId
                      AND batchRequest.TransportStatus IN ('planned', 'ready', 'running')
                )
                THEN 'running'
                ELSE 'completed'
            END,
            Status = 'ready',
            Message = CONCAT(
                N'Dispatch mode ',
                @ResolvedDispatchMode,
                N' completed for batch request ',
                CONVERT(NVARCHAR(30), @BatchRequestId),
                N'.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        UPDATE step
        SET
            step.Status = CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM rt.BatchRequest batchRequest
                    INNER JOIN rt.WorkSet workSet
                        ON workSet.WorkSetId = batchRequest.WorkSetId
                    WHERE workSet.ObjectRunId = @ObjectRunId
                      AND batchRequest.TransportStatus IN ('planned', 'ready', 'running')
                )
                THEN 'running'
                ELSE 'completed'
            END,
            step.EndedAt = CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM rt.BatchRequest batchRequest
                    INNER JOIN rt.WorkSet workSet
                        ON workSet.WorkSetId = batchRequest.WorkSetId
                    WHERE workSet.ObjectRunId = @ObjectRunId
                      AND batchRequest.TransportStatus IN ('planned', 'ready', 'running')
                )
                THEN NULL
                ELSE @Now
            END,
            step.Message = CONCAT(
                N'Latest dispatched batch request: ',
                CONVERT(NVARCHAR(30), @BatchRequestId),
                N'.'
            )
        FROM rt.ObjectRunStep step
        WHERE step.ObjectRunId = @ObjectRunId
          AND step.StepCode = 'DispatchBatches';

        UPDATE step
        SET
            step.Status = CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM rt.BatchRequest batchRequest
                    INNER JOIN rt.WorkSet workSet
                        ON workSet.WorkSetId = batchRequest.WorkSetId
                    WHERE workSet.ObjectRunId = @ObjectRunId
                      AND batchRequest.TransportStatus IN ('planned', 'ready', 'running')
                )
                THEN 'running'
                ELSE 'completed'
            END,
            step.EndedAt = CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM rt.BatchRequest batchRequest
                    INNER JOIN rt.WorkSet workSet
                        ON workSet.WorkSetId = batchRequest.WorkSetId
                    WHERE workSet.ObjectRunId = @ObjectRunId
                      AND batchRequest.TransportStatus IN ('planned', 'ready', 'running')
                )
                THEN NULL
                ELSE @Now
            END,
            step.Message = CONCAT(
                N'Reconciled simulated results for batch request ',
                CONVERT(NVARCHAR(30), @BatchRequestId),
                N'.'
            )
        FROM rt.ObjectRunStep step
        WHERE step.ObjectRunId = @ObjectRunId
          AND step.StepCode = 'ReconcileResults';

    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        UPDATE rt.BatchRequest
        SET
            TransportStatus = 'failed',
            EndedAt = SYSUTCDATETIME(),
            ErrorMessage = @ErrorMessage
        WHERE BatchRequestId = @BatchRequestId;

        IF @WorkSetId IS NOT NULL
        BEGIN
            UPDATE rt.WorkSet
            SET
                Status = 'failed',
                EndedAt = SYSUTCDATETIME(),
                Message = @ErrorMessage
            WHERE WorkSetId = @WorkSetId;
        END;

        IF @ObjectRunId IS NOT NULL
        BEGIN
            UPDATE rt.ObjectRun
            SET
                DispatchStatus = 'failed',
                Status = 'failed',
                EndedAt = SYSUTCDATETIME(),
                Message = @ErrorMessage
            WHERE ObjectRunId = @ObjectRunId;

            UPDATE rt.ObjectRunStep
            SET
                Status = 'failed',
                EndedAt = SYSUTCDATETIME(),
                Message = @ErrorMessage
            WHERE ObjectRunId = @ObjectRunId
              AND StepCode IN ('DispatchBatches', 'ReconcileResults')
              AND Status <> 'completed';
        END;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE rt.ExecutePlannedBatchDispatch
    @PipelineRunId BIGINT,
    @ObjectList VARCHAR(MAX) = NULL,
    @DispatchMode VARCHAR(30) = NULL,
    @StopOnError BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @AllowDispatch BIT,
        @BatchRequestId BIGINT,
        @ProcessedBatchCount INT = 0,
        @FailedBatchCount INT = 0,
        @ErrorMessage NVARCHAR(MAX);

    SELECT @AllowDispatch = AllowDispatch
    FROM rt.PipelineRun
    WHERE PipelineRunId = @PipelineRunId;

    IF @AllowDispatch IS NULL
        THROW 54240, 'ExecutePlannedBatchDispatch: pipeline run was not found.', 1;

    IF @AllowDispatch = 0
        THROW 54241, 'ExecutePlannedBatchDispatch: pipeline run must be planned with AllowDispatch = 1.', 1;

    UPDATE rt.PipelineRun
    SET
        Status = 'running',
        StartedAt = ISNULL(StartedAt, SYSUTCDATETIME()),
        EndedAt = NULL,
        Message = 'Dispatching ready batch requests.'
    WHERE PipelineRunId = @PipelineRunId;

    DECLARE batch_cursor CURSOR LOCAL FAST_FORWARD FOR
    WITH RequestedObjects AS
    (
        SELECT DISTINCT LTRIM(RTRIM([value])) AS ObjectCode
        FROM STRING_SPLIT(ISNULL(@ObjectList, ''), ',')
        WHERE LTRIM(RTRIM([value])) <> ''
    )
    SELECT batchRequest.BatchRequestId
    FROM rt.BatchRequest batchRequest
    INNER JOIN rt.WorkSet workSet
        ON workSet.WorkSetId = batchRequest.WorkSetId
    INNER JOIN rt.ObjectRun objectRun
        ON objectRun.ObjectRunId = workSet.ObjectRunId
    INNER JOIN meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objectRun.SyncObjectId
    LEFT JOIN RequestedObjects requested
        ON requested.ObjectCode = syncObj.ObjectCode
    WHERE objectRun.PipelineRunId = @PipelineRunId
      AND (ISNULL(@ObjectList, '') = '' OR requested.ObjectCode = syncObj.ObjectCode)
      AND batchRequest.TransportStatus = 'ready'
    ORDER BY
        objectRun.ExecutionOrder,
        batchRequest.BatchNumber,
        batchRequest.BatchRequestId;

    OPEN batch_cursor;

    FETCH NEXT FROM batch_cursor INTO @BatchRequestId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC rt.DispatchBatchRequest
                @BatchRequestId = @BatchRequestId,
                @DispatchMode = @DispatchMode;

            SET @ProcessedBatchCount += 1;
        END TRY
        BEGIN CATCH
            SET @FailedBatchCount += 1;
            SET @ErrorMessage = ERROR_MESSAGE();

            IF @StopOnError = 1
            BEGIN
                CLOSE batch_cursor;
                DEALLOCATE batch_cursor;

                UPDATE rt.PipelineRun
                SET
                    Status = 'failed',
                    EndedAt = SYSUTCDATETIME(),
                    Message = CONCAT(
                        N'Batch dispatch failed after ',
                        CONVERT(NVARCHAR(30), @ProcessedBatchCount),
                        N' completed batches. Last error: ',
                        @ErrorMessage
                    )
                WHERE PipelineRunId = @PipelineRunId;

                THROW;
            END;
        END CATCH;

        FETCH NEXT FROM batch_cursor INTO @BatchRequestId;
    END;

    CLOSE batch_cursor;
    DEALLOCATE batch_cursor;

    UPDATE rt.PipelineRun
    SET
        Status = CASE WHEN @FailedBatchCount > 0 THEN 'failed' ELSE 'ready' END,
        Message = CASE
            WHEN @FailedBatchCount > 0 THEN CONCAT(
                N'Batch dispatch completed with ',
                CONVERT(NVARCHAR(30), @FailedBatchCount),
                N' failed batches and ',
                CONVERT(NVARCHAR(30), @ProcessedBatchCount),
                N' successful batches.'
            )
            ELSE CONCAT(
                N'Batch dispatch completed for ',
                CONVERT(NVARCHAR(30), @ProcessedBatchCount),
                N' batches.'
            )
        END
    WHERE PipelineRunId = @PipelineRunId;

    SELECT
        @PipelineRunId AS PipelineRunId,
        @ProcessedBatchCount AS SuccessfulBatchCount,
        @FailedBatchCount AS FailedBatchCount;
END;
GO

CREATE OR ALTER VIEW rt.vw_DispatchResultSummary
AS
SELECT
    pipelineRun.PipelineRunId,
    client.ClientCode,
    syncObj.ObjectCode,
    workSet.OperationCode,
    batchRequest.BatchRequestId,
    batchRequest.TransportStatus,
    COUNT(batchRequestItem.BatchRequestItemId) AS BatchItemCount,
    SUM(CASE WHEN batchRequestItem.ResponseStatus = 'completed' THEN 1 ELSE 0 END) AS CompletedItemCount,
    SUM(CASE WHEN batchRequestItem.ResponseStatus = 'failed' THEN 1 ELSE 0 END) AS FailedItemCount,
    MIN(batchRequest.StartedAt) AS DispatchStartedAt,
    MAX(batchRequest.EndedAt) AS DispatchEndedAt
FROM rt.BatchRequest batchRequest
INNER JOIN rt.WorkSet workSet
    ON workSet.WorkSetId = batchRequest.WorkSetId
INNER JOIN rt.ObjectRun objectRun
    ON objectRun.ObjectRunId = workSet.ObjectRunId
INNER JOIN rt.PipelineRun pipelineRun
    ON pipelineRun.PipelineRunId = objectRun.PipelineRunId
INNER JOIN cfg.IntegrationClient client
    ON client.IntegrationClientId = pipelineRun.IntegrationClientId
INNER JOIN meta.SyncObject syncObj
    ON syncObj.SyncObjectId = objectRun.SyncObjectId
LEFT JOIN rt.BatchRequestItem batchRequestItem
    ON batchRequestItem.BatchRequestId = batchRequest.BatchRequestId
GROUP BY
    pipelineRun.PipelineRunId,
    client.ClientCode,
    syncObj.ObjectCode,
    workSet.OperationCode,
    batchRequest.BatchRequestId,
    batchRequest.TransportStatus;
GO

CREATE OR ALTER PROCEDURE rt.CreateSyntheticSourceSnapshot
    @ObjectRunId BIGINT,
    @BaseSourceSnapshotRunId BIGINT = NULL,
    @DeletedBusinessKeysJson NVARCHAR(MAX) = NULL,
    @UpsertRowsJson NVARCHAR(MAX) = NULL,
    @Message NVARCHAR(4000) = NULL,
    @SourceSnapshotRunId BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @SyncObjectId INT,
        @ObjectCode VARCHAR(80),
        @SourceProfileId INT,
        @ResolvedBaseSnapshotRunId BIGINT,
        @BaseMode VARCHAR(30),
        @BaseRowCount INT = 0,
        @SnapshotRowCount INT = 0,
        @DuplicateBusinessKeyCount INT = 0,
        @InsertDeltaCount INT = 0,
        @UpdateDeltaCount INT = 0,
        @DeleteDeltaCount INT = 0,
        @Now DATETIME2(0) = SYSUTCDATETIME(),
        @ErrorMessage NVARCHAR(MAX);

    SET @SourceSnapshotRunId = NULL;

    BEGIN TRY
        SELECT
            @SyncObjectId = syncObj.SyncObjectId,
            @ObjectCode = syncObj.ObjectCode
        FROM rt.ObjectRun objectRun
        INNER JOIN meta.SyncObject syncObj
            ON syncObj.SyncObjectId = objectRun.SyncObjectId
        WHERE objectRun.ObjectRunId = @ObjectRunId;

        IF @SyncObjectId IS NULL
            THROW 54260, 'CreateSyntheticSourceSnapshot: object run was not found.', 1;

        IF @BaseSourceSnapshotRunId IS NULL
        BEGIN
            SELECT TOP (1)
                @ResolvedBaseSnapshotRunId = snapshotRun.SourceSnapshotRunId,
                @SourceProfileId = snapshotRun.SourceProfileId
            FROM rt.SourceSnapshotRun snapshotRun
            INNER JOIN rt.ObjectRun objectRun
                ON objectRun.ObjectRunId = snapshotRun.ObjectRunId
            WHERE objectRun.SyncObjectId = @SyncObjectId
              AND snapshotRun.Status = 'completed'
            ORDER BY snapshotRun.SourceSnapshotRunId DESC;
        END
        ELSE
        BEGIN
            SELECT
                @ResolvedBaseSnapshotRunId = snapshotRun.SourceSnapshotRunId,
                @SourceProfileId = snapshotRun.SourceProfileId
            FROM rt.SourceSnapshotRun snapshotRun
            INNER JOIN rt.ObjectRun objectRun
                ON objectRun.ObjectRunId = snapshotRun.ObjectRunId
            WHERE snapshotRun.SourceSnapshotRunId = @BaseSourceSnapshotRunId
              AND objectRun.SyncObjectId = @SyncObjectId
              AND snapshotRun.Status = 'completed';
        END;

        IF @ResolvedBaseSnapshotRunId IS NULL
            THROW 54261, 'CreateSyntheticSourceSnapshot: no completed base source snapshot is available for the object.', 1;

        CREATE TABLE #DeletedBusinessKey
        (
            BusinessKey NVARCHAR(400) NOT NULL,
            PRIMARY KEY CLUSTERED (BusinessKey)
        );

        IF NULLIF(LTRIM(RTRIM(ISNULL(@DeletedBusinessKeysJson, N''))), N'') IS NOT NULL
        BEGIN
            INSERT INTO #DeletedBusinessKey
            (
                BusinessKey
            )
            SELECT DISTINCT
                deletedRow.BusinessKey
            FROM OPENJSON(@DeletedBusinessKeysJson)
                WITH
                (
                    BusinessKey NVARCHAR(400) '$'
                ) deletedRow
            WHERE NULLIF(LTRIM(RTRIM(deletedRow.BusinessKey)), N'') IS NOT NULL;
        END;

        CREATE TABLE #UpsertRow
        (
            BusinessKey NVARCHAR(400) NOT NULL,
            SourceHash VARBINARY(256) NULL,
            SourcePayloadJson NVARCHAR(MAX) NOT NULL,
            IsDeleted BIT NOT NULL DEFAULT (0),
            PRIMARY KEY CLUSTERED (BusinessKey)
        );

        IF NULLIF(LTRIM(RTRIM(ISNULL(@UpsertRowsJson, N''))), N'') IS NOT NULL
        BEGIN
            INSERT INTO #UpsertRow
            (
                BusinessKey,
                SourceHash,
                SourcePayloadJson,
                IsDeleted
            )
            SELECT
                upsertRow.BusinessKey,
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(ISNULL(upsertRow.SourceHashHex, N''))), N'') IS NULL THEN NULL
                    ELSE CONVERT(VARBINARY(256), REPLACE(upsertRow.SourceHashHex, N'0x', N''), 2)
                END,
                upsertRow.SourcePayloadJson,
                ISNULL(upsertRow.IsDeleted, 0)
            FROM OPENJSON(@UpsertRowsJson)
                WITH
                (
                    BusinessKey NVARCHAR(400) '$.businessKey',
                    SourceHashHex NVARCHAR(514) '$.sourceHashHex',
                    SourcePayloadJson NVARCHAR(MAX) '$.sourcePayloadJson',
                    IsDeleted BIT '$.isDeleted'
                ) upsertRow
            WHERE NULLIF(LTRIM(RTRIM(upsertRow.BusinessKey)), N'') IS NOT NULL
              AND NULLIF(LTRIM(RTRIM(upsertRow.SourcePayloadJson)), N'') IS NOT NULL;
        END;

        INSERT INTO #DeletedBusinessKey
        (
            BusinessKey
        )
        SELECT
            upsertRow.BusinessKey
        FROM #UpsertRow upsertRow
        LEFT JOIN #DeletedBusinessKey deletedRow
            ON deletedRow.BusinessKey = upsertRow.BusinessKey
        WHERE upsertRow.IsDeleted = 1
          AND deletedRow.BusinessKey IS NULL;

        DELETE upsertRow
        FROM #UpsertRow upsertRow
        WHERE upsertRow.IsDeleted = 1;

        CREATE TABLE #SyntheticSourceRow
        (
            BusinessKey NVARCHAR(400) NOT NULL,
            SourceHash VARBINARY(256) NULL,
            SourcePayloadJson NVARCHAR(MAX) NOT NULL,
            IsDeleted BIT NOT NULL DEFAULT (0),
            PRIMARY KEY CLUSTERED (BusinessKey)
        );

        IF @BaseSourceSnapshotRunId IS NULL
        BEGIN
            INSERT INTO #SyntheticSourceRow
            (
                BusinessKey,
                SourceHash,
                SourcePayloadJson,
                IsDeleted
            )
            SELECT
                currentRow.BusinessKey,
                currentRow.SourceHash,
                currentRow.SourcePayloadJson,
                0
            FROM rt.SourceCurrent currentRow
            WHERE currentRow.SyncObjectId = @SyncObjectId;

            SET @BaseRowCount = @@ROWCOUNT;
            SET @BaseMode = 'current';
        END
        ELSE
        BEGIN
            INSERT INTO #SyntheticSourceRow
            (
                BusinessKey,
                SourceHash,
                SourcePayloadJson,
                IsDeleted
            )
            SELECT
                baseRow.BusinessKey,
                baseRow.SourceHash,
                baseRow.SourcePayloadJson,
                baseRow.IsDeleted
            FROM rt.SourceSnapshotRow baseRow
            WHERE baseRow.SourceSnapshotRunId = @ResolvedBaseSnapshotRunId;

            SET @BaseRowCount = @@ROWCOUNT;
            SET @BaseMode = 'snapshot';

            IF @BaseRowCount = 0
                THROW 54263, 'CreateSyntheticSourceSnapshot: the requested base snapshot no longer has materialized rows; use the current source cache or provide a legacy snapshot run with stored rows.', 1;
        END;

        DELETE syntheticRow
        FROM #SyntheticSourceRow syntheticRow
        INNER JOIN #DeletedBusinessKey deletedRow
            ON deletedRow.BusinessKey = syntheticRow.BusinessKey;

        UPDATE syntheticRow
        SET
            syntheticRow.SourceHash = upsertRow.SourceHash,
            syntheticRow.SourcePayloadJson = upsertRow.SourcePayloadJson,
            syntheticRow.IsDeleted = 0
        FROM #SyntheticSourceRow syntheticRow
        INNER JOIN #UpsertRow upsertRow
            ON upsertRow.BusinessKey = syntheticRow.BusinessKey;

        INSERT INTO #SyntheticSourceRow
        (
            BusinessKey,
            SourceHash,
            SourcePayloadJson,
            IsDeleted
        )
        SELECT
            upsertRow.BusinessKey,
            upsertRow.SourceHash,
            upsertRow.SourcePayloadJson,
            0
        FROM #UpsertRow upsertRow
        LEFT JOIN #SyntheticSourceRow syntheticRow
            ON syntheticRow.BusinessKey = upsertRow.BusinessKey
        WHERE syntheticRow.BusinessKey IS NULL;

        UPDATE snapshotRun
        SET
            snapshotRun.Status = 'discarded',
            snapshotRun.EndedAt = @Now,
            snapshotRun.Message = CONCAT(
                ISNULL(snapshotRun.Message + N' ', N''),
                N'Superseded by a newer synthetic snapshot for object run ',
                CONVERT(NVARCHAR(30), @ObjectRunId),
                N'.'
            )
        FROM rt.SourceSnapshotRun snapshotRun
        WHERE snapshotRun.ObjectRunId = @ObjectRunId
          AND snapshotRun.Status IN ('planned', 'running', 'completed');

        INSERT INTO rt.SourceSnapshotRun
        (
            ObjectRunId,
            SourceProfileId,
            Status,
            Message
        )
        VALUES
        (
            @ObjectRunId,
            @SourceProfileId,
            'running',
            COALESCE(
                @Message,
                CONCAT(
                    N'Synthetic source snapshot based on snapshot run ',
                    CONVERT(NVARCHAR(30), @ResolvedBaseSnapshotRunId),
                    N' for object ',
                    @ObjectCode,
                    N'.'
                )
            )
        );

        SET @SourceSnapshotRunId = SCOPE_IDENTITY();

        SELECT
            @SnapshotRowCount = COUNT(*)
        FROM #SyntheticSourceRow syntheticRow;

        SELECT
            @DuplicateBusinessKeyCount = COUNT(*)
        FROM
        (
            SELECT syntheticRow.BusinessKey
            FROM #SyntheticSourceRow syntheticRow
            GROUP BY syntheticRow.BusinessKey
            HAVING COUNT(*) > 1
        ) duplicateKey;

        IF @DuplicateBusinessKeyCount > 0
            THROW 54262, 'CreateSyntheticSourceSnapshot: duplicate business keys were created in the synthetic snapshot.', 1;

        INSERT INTO rt.SourceDelta
        (
            SourceSnapshotRunId,
            SyncObjectId,
            BusinessKey,
            ChangeType,
            PreviousSourceHash,
            CurrentSourceHash,
            PreviousPayloadJson,
            CurrentPayloadJson
        )
        SELECT
            @SourceSnapshotRunId,
            @SyncObjectId,
            syntheticRow.BusinessKey,
            'I',
            NULL,
            syntheticRow.SourceHash,
            NULL,
            syntheticRow.SourcePayloadJson
        FROM #SyntheticSourceRow syntheticRow
        LEFT JOIN rt.SourceCurrent currentRow
            ON currentRow.SyncObjectId = @SyncObjectId
           AND currentRow.BusinessKey = syntheticRow.BusinessKey
        WHERE currentRow.SourceCurrentId IS NULL;

        SET @InsertDeltaCount = @@ROWCOUNT;

        INSERT INTO rt.SourceDelta
        (
            SourceSnapshotRunId,
            SyncObjectId,
            BusinessKey,
            ChangeType,
            PreviousSourceHash,
            CurrentSourceHash,
            PreviousPayloadJson,
            CurrentPayloadJson
        )
        SELECT
            @SourceSnapshotRunId,
            @SyncObjectId,
            syntheticRow.BusinessKey,
            'U',
            currentRow.SourceHash,
            syntheticRow.SourceHash,
            currentRow.SourcePayloadJson,
            syntheticRow.SourcePayloadJson
        FROM #SyntheticSourceRow syntheticRow
        INNER JOIN rt.SourceCurrent currentRow
            ON currentRow.SyncObjectId = @SyncObjectId
           AND currentRow.BusinessKey = syntheticRow.BusinessKey
        WHERE
        (
            (syntheticRow.SourceHash IS NULL AND currentRow.SourceHash IS NOT NULL)
            OR (syntheticRow.SourceHash IS NOT NULL AND currentRow.SourceHash IS NULL)
            OR (syntheticRow.SourceHash <> currentRow.SourceHash)
        );

        SET @UpdateDeltaCount = @@ROWCOUNT;

        INSERT INTO rt.SourceDelta
        (
            SourceSnapshotRunId,
            SyncObjectId,
            BusinessKey,
            ChangeType,
            PreviousSourceHash,
            CurrentSourceHash,
            PreviousPayloadJson,
            CurrentPayloadJson
        )
        SELECT
            @SourceSnapshotRunId,
            @SyncObjectId,
            currentRow.BusinessKey,
            'D',
            currentRow.SourceHash,
            NULL,
            currentRow.SourcePayloadJson,
            NULL
        FROM rt.SourceCurrent currentRow
        LEFT JOIN #SyntheticSourceRow syntheticRow
            ON syntheticRow.BusinessKey = currentRow.BusinessKey
        WHERE currentRow.SyncObjectId = @SyncObjectId
          AND syntheticRow.BusinessKey IS NULL;

        SET @DeleteDeltaCount = @@ROWCOUNT;

        DELETE currentRow
        FROM rt.SourceCurrent currentRow
        LEFT JOIN #SyntheticSourceRow syntheticRow
            ON syntheticRow.BusinessKey = currentRow.BusinessKey
        WHERE currentRow.SyncObjectId = @SyncObjectId
          AND syntheticRow.BusinessKey IS NULL;

        UPDATE currentRow
        SET
            currentRow.SourceHash = syntheticRow.SourceHash,
            currentRow.SourcePayloadJson = syntheticRow.SourcePayloadJson,
            currentRow.LastSourceSnapshotRunId = @SourceSnapshotRunId,
            currentRow.LastSeenAt = @Now,
            currentRow.UpdatedAt = @Now
        FROM rt.SourceCurrent currentRow
        INNER JOIN #SyntheticSourceRow syntheticRow
            ON syntheticRow.BusinessKey = currentRow.BusinessKey
        WHERE currentRow.SyncObjectId = @SyncObjectId;

        INSERT INTO rt.SourceCurrent
        (
            SyncObjectId,
            BusinessKey,
            SourceHash,
            SourcePayloadJson,
            LastSourceSnapshotRunId,
            LastSeenAt
        )
        SELECT
            @SyncObjectId,
            syntheticRow.BusinessKey,
            syntheticRow.SourceHash,
            syntheticRow.SourcePayloadJson,
            @SourceSnapshotRunId,
            @Now
        FROM #SyntheticSourceRow syntheticRow
        LEFT JOIN rt.SourceCurrent currentRow
            ON currentRow.SyncObjectId = @SyncObjectId
           AND currentRow.BusinessKey = syntheticRow.BusinessKey
        WHERE currentRow.SourceCurrentId IS NULL;

        UPDATE rt.SourceSnapshotRun
        SET
            Status = 'completed',
            SnapshotRowCount = @SnapshotRowCount,
            EndedAt = @Now,
            Message = COALESCE(
                @Message,
                CONCAT(
                    N'Synthetic source snapshot created from ',
                    @BaseMode,
                    N' base ',
                    CONVERT(NVARCHAR(30), @ResolvedBaseSnapshotRunId),
                    N' with ',
                    CONVERT(NVARCHAR(30), @SnapshotRowCount),
                    N' rows; delta I=',
                    CONVERT(NVARCHAR(30), @InsertDeltaCount),
                    N', U=',
                    CONVERT(NVARCHAR(30), @UpdateDeltaCount),
                    N', D=',
                    CONVERT(NVARCHAR(30), @DeleteDeltaCount),
                    N'.'
                )
            )
        WHERE SourceSnapshotRunId = @SourceSnapshotRunId;

        UPDATE rt.ObjectRun
        SET
            SourceStatus = 'completed',
            Status = 'ready',
            Message = CONCAT(
                N'Synthetic source snapshot ',
                CONVERT(NVARCHAR(30), @SourceSnapshotRunId),
                N' is ready for planning.'
            )
        WHERE ObjectRunId = @ObjectRunId;

        UPDATE step
        SET
            step.Status = 'completed',
            step.StartedAt = ISNULL(step.StartedAt, @Now),
            step.EndedAt = @Now,
            step.Message = CONCAT(
                N'Using synthetic source snapshot ',
                CONVERT(NVARCHAR(30), @SourceSnapshotRunId),
                N'.'
            )
        FROM rt.ObjectRunStep step
        WHERE step.ObjectRunId = @ObjectRunId
          AND step.StepCode = 'RefreshSource';

        SELECT
            @SourceSnapshotRunId AS SourceSnapshotRunId,
            @ResolvedBaseSnapshotRunId AS BaseSourceSnapshotRunId,
            @BaseMode AS BaseMode,
            @SnapshotRowCount AS SnapshotRowCount,
            @InsertDeltaCount AS InsertDeltaCount,
            @UpdateDeltaCount AS UpdateDeltaCount,
            @DeleteDeltaCount AS DeleteDeltaCount;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();

        IF @SourceSnapshotRunId IS NOT NULL
        BEGIN
            UPDATE rt.SourceSnapshotRun
            SET
                Status = 'failed',
                EndedAt = SYSUTCDATETIME(),
                Message = @ErrorMessage
            WHERE SourceSnapshotRunId = @SourceSnapshotRunId;
        END;

        UPDATE rt.ObjectRun
        SET
            SourceStatus = 'failed',
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId;

        UPDATE rt.ObjectRunStep
        SET
            Status = 'failed',
            EndedAt = SYSUTCDATETIME(),
            Message = @ErrorMessage
        WHERE ObjectRunId = @ObjectRunId
          AND StepCode = 'RefreshSource'
          AND Status <> 'completed';

        THROW;
    END CATCH;
END;
GO
