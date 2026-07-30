USE [INTEGRAMASTER_V3];
GO

SET NOCOUNT ON;
GO

/*
Purpose:
    Rebaseline PurchaseOrder canonical V3 state to the current V3 source-hash policy.

What it does:
    1. captures a fresh live PurchaseOrder source snapshot into rt.SourceCurrent
    2. previews active PurchaseOrder state rows that differ from rt.SourceCurrent
    3. updates rt.ObjectState.CurrentSourceHash / CurrentStateHash / CurrentPayloadJson
       from rt.SourceCurrent for matched active rows
    4. shows a post-apply preview so drift should collapse to zero

Important:
    - This does NOT touch source tables.
    - This does NOT call the destination API.
    - This treats freshly captured current source state as the accepted baseline for already-synchronized rows.
*/

DECLARE
    @PipelineRunId BIGINT;

EXEC rt.PlanPipelineRun
    @ClientCode = 'PLS',
    @ObjectList = 'PurchaseOrder',
    @RefreshSource = 1,
    @RefreshState = 0,
    @AllowDispatch = 0,
    @OutputDiagnostics = 1,
    @PipelineRunId = @PipelineRunId OUTPUT;
GO

DECLARE
    @CapturePipelineRunId BIGINT;

SELECT
    @CapturePipelineRunId = MAX(pipelineRun.PipelineRunId)
FROM rt.PipelineRun pipelineRun
INNER JOIN cfg.IntegrationClient client
    ON client.IntegrationClientId = pipelineRun.IntegrationClientId
WHERE client.ClientCode = 'PLS';

EXEC rt.ExecutePlannedSourceSnapshots
    @PipelineRunId = @CapturePipelineRunId,
    @StopOnError = 1;
GO

EXEC rt.RebaselineObjectStateFromSourceCurrent
    @ObjectCode = 'PurchaseOrder',
    @ApplyChanges = 0,
    @OutputDiagnostics = 1;
GO

EXEC rt.RebaselineObjectStateFromSourceCurrent
    @ObjectCode = 'PurchaseOrder',
    @ApplyChanges = 1,
    @OutputDiagnostics = 0;
GO

EXEC rt.RebaselineObjectStateFromSourceCurrent
    @ObjectCode = 'PurchaseOrder',
    @ApplyChanges = 0,
    @OutputDiagnostics = 1;
GO
