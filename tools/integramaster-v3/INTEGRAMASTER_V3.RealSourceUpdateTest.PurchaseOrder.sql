USE [INTEGRAMASTER_V3];
GO

SET NOCOUNT ON;
GO

/*
Purpose:
    Controlled real-source update test for PurchaseOrder.

What it does:
    1. picks one existing PurchaseOrder row that already has canonical V3 state
    2. updates OASIS_PLS.oasis.CHSC_PO.PONUMBER
    3. refreshes PLS.SRC.PurchaseOrder through the V3 RefreshSource wrapper
    4. captures the refreshed source into V3 current-state/delta runtime
    5. runs V3 work preparation
    6. shows the planned update work item
    7. reverts the raw source row
    8. refreshes PLS.SRC.PurchaseOrder again through the same V3 wrapper

Important:
    - This script changes a real source row temporarily.
    - It does NOT dispatch to the destination API.
    - It assumes PurchaseOrder canonical state already exists in INTEGRAMASTER_V3.rt.ObjectState.
*/

DECLARE
    @Dbid VARCHAR(50),
    @Poid INT,
    @BusinessKey NVARCHAR(400),
    @OriginalPoNumber VARCHAR(100),
    @TestPoNumber VARCHAR(100),
    @PipelineRunId BIGINT,
    @PlannedObjectRunId BIGINT,
    @CapturedSourceSnapshotRunId BIGINT,
    @RawRowUpdated BIT = 0;

;WITH CandidateRow AS
(
    SELECT TOP (1)
        raw.DBID,
        raw.POID,
        raw.PONUMBER,
        objectState.BusinessKey
    FROM OASIS_PLS.oasis.CHSC_PO raw
    INNER JOIN INTEGRAMASTER_V3.rt.ObjectState objectState
        ON objectState.BusinessKey = CONCAT('DBID=', raw.DBID, '|POID=', CONVERT(VARCHAR(20), raw.POID))
       AND objectState.IsDeleted = 0
    INNER JOIN INTEGRAMASTER_V3.meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objectState.SyncObjectId
    WHERE syncObj.ObjectCode = 'PurchaseOrder'
      AND raw.PONUMBER NOT LIKE 'V3-REALTEST-%'
    ORDER BY raw.UPDATEDATE DESC, raw.POID DESC
)
SELECT
    @Dbid = candidate.DBID,
    @Poid = candidate.POID,
    @BusinessKey = candidate.BusinessKey,
    @OriginalPoNumber = candidate.PONUMBER
FROM CandidateRow candidate;

IF @Dbid IS NULL OR @Poid IS NULL
    THROW 54400, 'RealSourceUpdateTest: could not find a PurchaseOrder row with existing canonical V3 state.', 1;

SET @TestPoNumber = CONCAT('V3-REALTEST-', CONVERT(VARCHAR(20), @Poid));

SELECT
    'BaselineRaw' AS StageName,
    raw.DBID,
    raw.POID,
    raw.PONUMBER,
    raw.UPDATEDATE,
    raw.UPDATEUSERID
FROM OASIS_PLS.oasis.CHSC_PO raw
WHERE raw.DBID = @Dbid
  AND raw.POID = @Poid;

SELECT
    'BaselineStage' AS StageName,
    src.DBID,
    src.POID,
    src.PONUMBER,
    src.UpdateDate,
    CONVERT(VARCHAR(64), src.RowHash, 2) AS RowHashHex
FROM PLS.SRC.PurchaseOrder src
WHERE src.DBID = @Dbid
  AND src.POID = @Poid;

SELECT
    'BaselineState' AS StageName,
    objectState.BusinessKey,
    objectState.DestinationRecordId,
    JSON_VALUE(objectState.CurrentPayloadJson, '$.POnumber') AS CanonicalPoNumber,
    CONVERT(VARCHAR(64), objectState.CurrentSourceHash, 2) AS CurrentSourceHashHex,
    objectState.LastAppliedAt
FROM INTEGRAMASTER_V3.rt.ObjectState objectState
INNER JOIN INTEGRAMASTER_V3.meta.SyncObject syncObj
    ON syncObj.SyncObjectId = objectState.SyncObjectId
WHERE syncObj.ObjectCode = 'PurchaseOrder'
  AND objectState.BusinessKey = @BusinessKey;

BEGIN TRY
    UPDATE raw
    SET
        raw.PONUMBER = @TestPoNumber,
        raw.UPDATEDATE = SYSUTCDATETIME()
    FROM OASIS_PLS.oasis.CHSC_PO raw
    WHERE raw.DBID = @Dbid
      AND raw.POID = @Poid;

    SET @RawRowUpdated = 1;

    EXEC INTEGRAMASTER_V3.rt.PlanPipelineRun
        @ClientCode = 'PLS',
        @ObjectList = 'PurchaseOrder',
        @RefreshSource = 1,
        @RefreshState = 1,
        @AllowDispatch = 0,
        @OutputDiagnostics = 1,
        @PipelineRunId = @PipelineRunId OUTPUT;

    SELECT TOP (1)
        @PlannedObjectRunId = objectRun.ObjectRunId
    FROM INTEGRAMASTER_V3.rt.ObjectRun objectRun
    INNER JOIN INTEGRAMASTER_V3.meta.SyncObject syncObj
        ON syncObj.SyncObjectId = objectRun.SyncObjectId
    WHERE objectRun.PipelineRunId = @PipelineRunId
      AND syncObj.ObjectCode = 'PurchaseOrder';

    EXEC INTEGRAMASTER_V3.rt.ExecutePlannedSourceSnapshots
        @PipelineRunId = @PipelineRunId,
        @StopOnError = 1;

    SELECT TOP (1)
        @CapturedSourceSnapshotRunId = snapshotRun.SourceSnapshotRunId
    FROM INTEGRAMASTER_V3.rt.SourceSnapshotRun snapshotRun
    WHERE snapshotRun.ObjectRunId = @PlannedObjectRunId
      AND snapshotRun.Status = 'completed'
    ORDER BY snapshotRun.SourceSnapshotRunId DESC;

    EXEC INTEGRAMASTER_V3.rt.ExecutePlannedWorkPreparation
        @PipelineRunId = @PipelineRunId,
        @StopOnError = 1;

    SELECT
        @PipelineRunId AS PipelineRunId,
        @CapturedSourceSnapshotRunId AS CapturedSourceSnapshotRunId,
        @BusinessKey AS TestedBusinessKey,
        @OriginalPoNumber AS OriginalPoNumber,
        @TestPoNumber AS TestPoNumber;

    SELECT
        'ChangedStage' AS StageName,
        src.DBID,
        src.POID,
        src.PONUMBER,
        src.UpdateDate,
        CONVERT(VARCHAR(64), src.RowHash, 2) AS RowHashHex
    FROM PLS.SRC.PurchaseOrder src
    WHERE src.DBID = @Dbid
      AND src.POID = @Poid;

    SELECT
        sourceDelta.ChangeType,
        sourceDelta.BusinessKey,
        CONVERT(VARCHAR(64), sourceDelta.PreviousSourceHash, 2) AS PreviousSourceHashHex,
        CONVERT(VARCHAR(64), sourceDelta.CurrentSourceHash, 2) AS CurrentSourceHashHex
    FROM INTEGRAMASTER_V3.rt.SourceDelta sourceDelta
    WHERE sourceDelta.SourceSnapshotRunId = @CapturedSourceSnapshotRunId
      AND sourceDelta.BusinessKey = @BusinessKey;

    SELECT
        workSet.OperationCode,
        workItem.BusinessKey,
        workItem.ResultStatus,
        workItem.DestinationRecordId,
        LEFT(workItem.PayloadJson, 300) AS PayloadPreview
    FROM INTEGRAMASTER_V3.rt.WorkItem workItem
    INNER JOIN INTEGRAMASTER_V3.rt.WorkSet workSet
        ON workSet.WorkSetId = workItem.WorkSetId
    INNER JOIN INTEGRAMASTER_V3.rt.ObjectRun objectRun
        ON objectRun.ObjectRunId = workSet.ObjectRunId
    WHERE objectRun.PipelineRunId = @PipelineRunId
      AND workItem.BusinessKey = @BusinessKey
    ORDER BY workSet.OperationCode, workItem.WorkItemId;
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(MAX) = ERROR_MESSAGE();

    IF @RawRowUpdated = 1
    BEGIN
        UPDATE raw
        SET
            raw.PONUMBER = @OriginalPoNumber,
            raw.UPDATEDATE = SYSUTCDATETIME()
        FROM OASIS_PLS.oasis.CHSC_PO raw
        WHERE raw.DBID = @Dbid
          AND raw.POID = @Poid;

        EXEC INTEGRAMASTER_V3.rt.PlanPipelineRun
            @ClientCode = 'PLS',
            @ObjectList = 'PurchaseOrder',
            @RefreshSource = 1,
            @RefreshState = 0,
            @AllowDispatch = 0,
            @OutputDiagnostics = 0,
            @PipelineRunId = @PipelineRunId OUTPUT;

        EXEC INTEGRAMASTER_V3.rt.ExecutePlannedSourceSnapshots
            @PipelineRunId = @PipelineRunId,
            @StopOnError = 1;
    END;

    THROW 54401, @ErrorMessage, 1;
END CATCH;

UPDATE raw
SET
    raw.PONUMBER = @OriginalPoNumber,
    raw.UPDATEDATE = SYSUTCDATETIME()
FROM OASIS_PLS.oasis.CHSC_PO raw
WHERE raw.DBID = @Dbid
  AND raw.POID = @Poid;

EXEC INTEGRAMASTER_V3.rt.PlanPipelineRun
    @ClientCode = 'PLS',
    @ObjectList = 'PurchaseOrder',
    @RefreshSource = 1,
    @RefreshState = 0,
    @AllowDispatch = 0,
    @OutputDiagnostics = 0,
    @PipelineRunId = @PipelineRunId OUTPUT;

EXEC INTEGRAMASTER_V3.rt.ExecutePlannedSourceSnapshots
    @PipelineRunId = @PipelineRunId,
    @StopOnError = 1;

SELECT
    'RevertedRaw' AS StageName,
    raw.DBID,
    raw.POID,
    raw.PONUMBER,
    raw.UPDATEDATE,
    raw.UPDATEUSERID
FROM OASIS_PLS.oasis.CHSC_PO raw
WHERE raw.DBID = @Dbid
  AND raw.POID = @Poid;

SELECT
    'RevertedStage' AS StageName,
    src.DBID,
    src.POID,
    src.PONUMBER,
    src.UpdateDate,
    CONVERT(VARCHAR(64), src.RowHash, 2) AS RowHashHex
FROM PLS.SRC.PurchaseOrder src
WHERE src.DBID = @Dbid
  AND src.POID = @Poid;
GO
