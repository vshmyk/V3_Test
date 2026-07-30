USE [OASIS_PLS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.TransactionLog')
      AND name = N'IX_TransactionLog_Pending_BatchId_Id'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_TransactionLog_Pending_BatchId_Id]
    ON [dbo].[TransactionLog] ([BatchId] ASC, [Id] ASC)
    INCLUDE ([TransactionId], [BatchTime], [TransactionStatement])
    WHERE [ExecutionTime] IS NULL;
END;
GO
