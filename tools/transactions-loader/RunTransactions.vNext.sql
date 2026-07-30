USE [INTEGRAMASTER_V2];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[RunTransactions]
    @ClientId VARCHAR(20),
    @MaxRows INT = NULL,
    @InitialBatchSize INT = 1000,
    @StopOnError BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @OasisDB SYSNAME,
        @TargetLogTable NVARCHAR(400),
        @LockResource NVARCHAR(200),
        @LockResult INT,
        @SelectSql NVARCHAR(MAX),
        @UpdateRangeSql NVARCHAR(MAX),
        @UpdateRangeSqlFallback NVARCHAR(MAX),
        @ExecuteSql NVARCHAR(MAX),
        @BatchSql NVARCHAR(MAX),
        @ExecutionResult NVARCHAR(MAX),
        @ExecutionTime DATETIME,
        @PendingCount INT = 0,
        @ProcessedCount INT = 0,
        @SucceededCount INT = 0,
        @FailedCount INT = 0,
        @StoppedOnError BIT = 0,
        @SeedStart INT = 1,
        @SeedEnd INT,
        @WorkId INT,
        @RangeStart INT,
        @RangeEnd INT,
        @RangeSize INT,
        @Midpoint INT;

    IF @InitialBatchSize IS NULL OR @InitialBatchSize < 1
        SET @InitialBatchSize = 1000;

    SELECT @OasisDB = [dbo].[GetClientParameterValue](@ClientId, 'OASIS_DB');

    IF NULLIF(LTRIM(RTRIM(@OasisDB)), '') IS NULL
        THROW 50001, 'RunTransactions: OASIS_DB is missing for the supplied ClientId.', 1;

    IF DB_ID(@OasisDB) IS NULL
        THROW 50002, 'RunTransactions: target OASIS database does not exist.', 1;

    SET @TargetLogTable = QUOTENAME(@OasisDB) + N'.dbo.TransactionLog';
    SET @LockResource = N'RunTransactions:' + @ClientId;

    EXEC @LockResult = sys.sp_getapplock
        @Resource = @LockResource,
        @LockMode = 'Exclusive',
        @LockOwner = 'Session',
        @LockTimeout = 0;

    IF @LockResult < 0
        THROW 50003, 'RunTransactions: could not acquire exclusive client lock.', 1;

    IF OBJECT_ID('tempdb..#Pending') IS NOT NULL
        DROP TABLE #Pending;

    CREATE TABLE #Pending
    (
        RowNum INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        BatchId VARCHAR(80) NULL,
        Id INT NULL,
        TransactionId VARCHAR(80) NULL,
        TransactionStatement NVARCHAR(MAX) NULL
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

    IF @MaxRows IS NULL
        SET @SelectSql = N'
            INSERT INTO #Pending (BatchId, Id, TransactionId, TransactionStatement)
            SELECT
                BatchId,
                Id,
                TransactionId,
                TransactionStatement
            FROM ' + @TargetLogTable + N'
            WHERE ExecutionTime IS NULL
              AND TransactionStatement IS NOT NULL
            ORDER BY
                BatchId,
                CASE WHEN Id IS NULL THEN 2147483647 ELSE Id END,
                TransactionId;';
    ELSE
        SET @SelectSql = N'
            INSERT INTO #Pending (BatchId, Id, TransactionId, TransactionStatement)
            SELECT TOP (@MaxRows)
                BatchId,
                Id,
                TransactionId,
                TransactionStatement
            FROM ' + @TargetLogTable + N'
            WHERE ExecutionTime IS NULL
              AND TransactionStatement IS NOT NULL
            ORDER BY
                BatchId,
                CASE WHEN Id IS NULL THEN 2147483647 ELSE Id END,
                TransactionId;';

    EXEC sys.sp_executesql
        @SelectSql,
        N'@MaxRows INT',
        @MaxRows = @MaxRows;

    SELECT @PendingCount = COUNT(1)
    FROM #Pending;

    IF @PendingCount = 0
    BEGIN
        SELECT
            @ClientId AS ClientId,
            @OasisDB AS OasisDB,
            @PendingCount AS PendingCount,
            @ProcessedCount AS ProcessedCount,
            @SucceededCount AS SucceededCount,
            @FailedCount AS FailedCount,
            @StoppedOnError AS StoppedOnError;
        RETURN;
    END;

    CREATE INDEX IX_Pending_BatchId_Id ON #Pending(BatchId, Id) INCLUDE (TransactionId);
    CREATE INDEX IX_WorkQueue_Status_WorkId ON #WorkQueue(Status, WorkId) INCLUDE (RangeStart, RangeEnd);

    WHILE @SeedStart <= @PendingCount
    BEGIN
        SET @SeedEnd = CASE
            WHEN @SeedStart + @InitialBatchSize - 1 < @PendingCount THEN @SeedStart + @InitialBatchSize - 1
            ELSE @PendingCount
        END;

        INSERT INTO #WorkQueue (RangeStart, RangeEnd)
        VALUES (@SeedStart, @SeedEnd);

        SET @SeedStart = @SeedEnd + 1;
    END;

    SET @UpdateRangeSql = N'
        UPDATE tl
        SET
            tl.ExecutionResult = @ExecutionResult,
            tl.ExecutionTime = @ExecutionTime
        FROM ' + @TargetLogTable + N' AS tl
        INNER JOIN #Pending AS p
            ON p.RowNum BETWEEN @RangeStart AND @RangeEnd
           AND p.Id IS NOT NULL
           AND p.BatchId = tl.BatchId
           AND tl.Id = p.Id
        WHERE tl.ExecutionTime IS NULL;';

    SET @UpdateRangeSqlFallback = N'
        UPDATE tl
        SET
            tl.ExecutionResult = @ExecutionResult,
            tl.ExecutionTime = @ExecutionTime
        FROM ' + @TargetLogTable + N' AS tl
        INNER JOIN #Pending AS p
            ON p.RowNum BETWEEN @RangeStart AND @RangeEnd
           AND p.Id IS NULL
           AND p.BatchId = tl.BatchId
           AND tl.TransactionId = p.TransactionId
           AND tl.TransactionStatement = p.TransactionStatement
        WHERE tl.ExecutionTime IS NULL;';

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

        SET @BatchSql = N'';
        SET @ExecutionResult = N'OK';
        SET @ExecutionTime = GETDATE();
        SET @RangeSize = @RangeEnd - @RangeStart + 1;

        SELECT @BatchSql =
            STUFF((
                SELECT
                    CHAR(10) + CASE WHEN p.RowNum > @RangeStart THEN N';' ELSE N'' END + CHAR(10) + p.TransactionStatement
                FROM #Pending AS p
                WHERE p.RowNum BETWEEN @RangeStart AND @RangeEnd
                ORDER BY p.RowNum
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, N'');

        BEGIN TRY
            BEGIN TRANSACTION;

            SET @ExecuteSql = N'USE ' + QUOTENAME(@OasisDB) + N'; SET NOCOUNT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; ' + @BatchSql + N';';
            EXEC sys.sp_executesql @ExecuteSql;

            COMMIT TRANSACTION;

            EXEC sys.sp_executesql
                @UpdateRangeSql,
                N'@RangeStart INT, @RangeEnd INT, @ExecutionResult NVARCHAR(MAX), @ExecutionTime DATETIME',
                @RangeStart = @RangeStart,
                @RangeEnd = @RangeEnd,
                @ExecutionResult = N'OK',
                @ExecutionTime = @ExecutionTime;

            IF EXISTS (
                SELECT 1
                FROM #Pending
                WHERE RowNum BETWEEN @RangeStart AND @RangeEnd
                  AND Id IS NULL
            )
            BEGIN
                EXEC sys.sp_executesql
                    @UpdateRangeSqlFallback,
                    N'@RangeStart INT, @RangeEnd INT, @ExecutionResult NVARCHAR(MAX), @ExecutionTime DATETIME',
                    @RangeStart = @RangeStart,
                    @RangeEnd = @RangeEnd,
                    @ExecutionResult = N'OK',
                    @ExecutionTime = @ExecutionTime;
            END;

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
                EXEC sys.sp_executesql
                    @UpdateRangeSql,
                    N'@RangeStart INT, @RangeEnd INT, @ExecutionResult NVARCHAR(MAX), @ExecutionTime DATETIME',
                    @RangeStart = @RangeStart,
                    @RangeEnd = @RangeEnd,
                    @ExecutionResult = @ExecutionResult,
                    @ExecutionTime = @ExecutionTime;

                IF EXISTS (
                    SELECT 1
                    FROM #Pending
                    WHERE RowNum BETWEEN @RangeStart AND @RangeEnd
                      AND Id IS NULL
                )
                BEGIN
                    EXEC sys.sp_executesql
                        @UpdateRangeSqlFallback,
                        N'@RangeStart INT, @RangeEnd INT, @ExecutionResult NVARCHAR(MAX), @ExecutionTime DATETIME',
                        @RangeStart = @RangeStart,
                        @RangeEnd = @RangeEnd,
                        @ExecutionResult = @ExecutionResult,
                        @ExecutionTime = @ExecutionTime;
                END;

                SET @ProcessedCount += 1;
                SET @FailedCount += 1;

                UPDATE #WorkQueue
                SET Status = 'F'
                WHERE WorkId = @WorkId;

                IF @StopOnError = 1
                BEGIN
                    SET @StoppedOnError = 1;
                    BREAK;
                END;
            END
            ELSE
            BEGIN
                SET @Midpoint = @RangeStart + ((@RangeEnd - @RangeStart) / 2);

                INSERT INTO #WorkQueue (RangeStart, RangeEnd)
                VALUES (@RangeStart, @Midpoint),
                       (@Midpoint + 1, @RangeEnd);

                UPDATE #WorkQueue
                SET Status = 'B'
                WHERE WorkId = @WorkId;
            END;
        END CATCH;
    END;

    SELECT
        @ClientId AS ClientId,
        @OasisDB AS OasisDB,
        @PendingCount AS PendingCount,
        @ProcessedCount AS ProcessedCount,
        @SucceededCount AS SucceededCount,
        @FailedCount AS FailedCount,
        @StoppedOnError AS StoppedOnError;
END;
GO
