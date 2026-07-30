USE [INTEGRAMASTER_V3];
GO

SET NOCOUNT ON;
GO

DECLARE
    @PipelineRunId BIGINT,
    @ObjectRunId BIGINT,
    @SourceSnapshotRunId BIGINT,
    @UpdateBusinessKey NVARCHAR(400),
    @UpdatePayloadJson NVARCHAR(MAX),
    @UpdateSourceHashHex VARCHAR(66),
    @InsertSeedBusinessKey NVARCHAR(400),
    @InsertSeedPayloadJson NVARCHAR(MAX),
    @InsertDbid VARCHAR(50),
    @InsertPoid INT,
    @InsertBusinessKey NVARCHAR(400),
    @InsertPayloadJson NVARCHAR(MAX),
    @InsertSourceHashHex VARCHAR(66),
    @UpsertRowsJson NVARCHAR(MAX),
    @SyntheticMessage NVARCHAR(4000);

EXEC rt.PlanPipelineRun
    @ClientCode = 'PLS',
    @ObjectList = 'PurchaseOrder',
    @RefreshSource = 0,
    @RefreshState = 1,
    @AllowDispatch = 0,
    @OutputDiagnostics = 1,
    @PipelineRunId = @PipelineRunId OUTPUT;

SELECT
    @ObjectRunId = objectRun.ObjectRunId
FROM rt.ObjectRun objectRun
INNER JOIN meta.SyncObject syncObj
    ON syncObj.SyncObjectId = objectRun.SyncObjectId
WHERE objectRun.PipelineRunId = @PipelineRunId
  AND syncObj.ObjectCode = 'PurchaseOrder';

;WITH SampleState AS
(
    SELECT TOP (2)
        objectState.BusinessKey,
        objectState.CurrentPayloadJson,
        JSON_VALUE(objectState.CurrentPayloadJson, '$.DBID') AS DBID,
        TRY_CONVERT(INT, JSON_VALUE(objectState.CurrentPayloadJson, '$.POID')) AS POID,
        ROW_NUMBER() OVER (ORDER BY objectState.BusinessKey) AS RowNum
    FROM rt.ObjectState objectState
    INNER JOIN meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objectState.SyncObjectId
    WHERE syncObj.ObjectCode = 'PurchaseOrder'
      AND objectState.IsDeleted = 0
    ORDER BY objectState.BusinessKey
)
SELECT
    @UpdateBusinessKey = MAX(CASE WHEN sample.RowNum = 1 THEN sample.BusinessKey END),
    @UpdatePayloadJson = MAX(CASE WHEN sample.RowNum = 1 THEN sample.CurrentPayloadJson END),
    @InsertSeedBusinessKey = MAX(CASE WHEN sample.RowNum = 2 THEN sample.BusinessKey END),
    @InsertSeedPayloadJson = MAX(CASE WHEN sample.RowNum = 2 THEN sample.CurrentPayloadJson END),
    @InsertDbid = MAX(CASE WHEN sample.RowNum = 2 THEN sample.DBID END)
FROM SampleState sample;

IF @UpdateBusinessKey IS NULL OR @InsertSeedBusinessKey IS NULL
    THROW 54300, 'ChangeCaptureTest: not enough canonical PurchaseOrder rows are available to build the test scenario.', 1;

SET @UpdatePayloadJson = JSON_MODIFY(
    @UpdatePayloadJson,
    '$.POnumber',
    CONCAT('V3-TEST-UPD-', @PipelineRunId)
);

SET @UpdateSourceHashHex = '0x' + CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @UpdatePayloadJson), 2);

SET @InsertPoid = 990000000 + CONVERT(INT, @PipelineRunId);
SET @InsertBusinessKey = CONCAT('DBID=', @InsertDbid, '|POID=', CONVERT(VARCHAR(20), @InsertPoid));
SET @InsertPayloadJson = JSON_MODIFY(@InsertSeedPayloadJson, '$.POID', @InsertPoid);
SET @InsertPayloadJson = JSON_MODIFY(@InsertPayloadJson, '$.POnumber', CONCAT('V3-TEST-INS-', @InsertPoid));
SET @InsertSourceHashHex = '0x' + CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @InsertPayloadJson), 2);
SET @SyntheticMessage = CONCAT(
    N'PurchaseOrder change-capture test for pipeline run ',
    CONVERT(NVARCHAR(30), @PipelineRunId),
    N': one synthetic update and one synthetic insert.'
);

SET @UpsertRowsJson =
(
    SELECT *
    FROM
    (
        SELECT
            @UpdateBusinessKey AS businessKey,
            @UpdateSourceHashHex AS sourceHashHex,
            @UpdatePayloadJson AS sourcePayloadJson,
            CAST(0 AS BIT) AS isDeleted
        UNION ALL
        SELECT
            @InsertBusinessKey,
            @InsertSourceHashHex,
            @InsertPayloadJson,
            CAST(0 AS BIT)
    ) upsertRow
    FOR JSON PATH
);

EXEC rt.CreateSyntheticSourceSnapshot
    @ObjectRunId = @ObjectRunId,
    @BaseSourceSnapshotRunId = NULL,
    @DeletedBusinessKeysJson = NULL,
    @UpsertRowsJson = @UpsertRowsJson,
    @Message = @SyntheticMessage,
    @SourceSnapshotRunId = @SourceSnapshotRunId OUTPUT;

EXEC rt.ExecutePlannedWorkPreparation
    @PipelineRunId = @PipelineRunId,
    @StopOnError = 1;

SELECT
    @PipelineRunId AS PipelineRunId,
    @ObjectRunId AS ObjectRunId,
    @SourceSnapshotRunId AS SyntheticSourceSnapshotRunId,
    @UpdateBusinessKey AS UpdatedBusinessKey,
    @InsertBusinessKey AS InsertedBusinessKey;

SELECT
    PipelineRunId,
    ClientCode,
    ObjectCode,
    OperationCode,
    PlannedItemCount,
    BatchSize,
    WorkSetStatus,
    MaterializedItemCount
FROM rt.vw_WorkPlanSummary
WHERE PipelineRunId = @PipelineRunId
ORDER BY OperationCode;

SELECT
    sourceDelta.ChangeType,
    sourceDelta.BusinessKey,
    CONVERT(VARCHAR(64), sourceDelta.PreviousSourceHash, 2) AS PreviousSourceHashHex,
    CONVERT(VARCHAR(64), sourceDelta.CurrentSourceHash, 2) AS CurrentSourceHashHex
FROM rt.SourceDelta sourceDelta
WHERE sourceDelta.SourceSnapshotRunId = @SourceSnapshotRunId
ORDER BY sourceDelta.ChangeType, sourceDelta.BusinessKey;

SELECT TOP (10)
    workSet.OperationCode,
    workItem.BusinessKey,
    workItem.ResultStatus,
    workItem.DestinationRecordId,
    LEFT(workItem.PayloadJson, 240) AS PayloadPreview
FROM rt.WorkItem workItem
INNER JOIN rt.WorkSet workSet
    ON workSet.WorkSetId = workItem.WorkSetId
INNER JOIN rt.ObjectRun objectRun
    ON objectRun.ObjectRunId = workSet.ObjectRunId
WHERE objectRun.PipelineRunId = @PipelineRunId
ORDER BY workSet.OperationCode, workItem.WorkItemId;
GO
