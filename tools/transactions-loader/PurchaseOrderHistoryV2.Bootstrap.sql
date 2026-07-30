/*
    Bootstrap a V2 snapshot from a preserved legacy PurchaseOrderItemHistory table.
    Intended use:
      - seed yesterday's baseline into V2
      - then run SRC.PurchaseOrderHistoryDE_V2 against refreshed raw data
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE SRC.BootstrapPurchaseOrderSnapshotV2FromLegacy
(
    @LegacyTableName SYSNAME,
    @PurchaseOrderId VARCHAR(24) = NULL,
    @DBID VARCHAR(32) = NULL,
    @POID INT = NULL,
    @ReplaceExisting BIT = 0,
    @SnapshotRunId BIGINT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedPurchaseOrderId VARCHAR(24) = NULL;
    DECLARE @ResolvedDBID VARCHAR(32) = NULL;
    DECLARE @ResolvedPOID INT = NULL;
    DECLARE @ResolvedPONumber VARCHAR(96) = NULL;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @LegacyDb SYSNAME = PARSENAME(@LegacyTableName, 3);
    DECLARE @LegacySchema SYSNAME = PARSENAME(@LegacyTableName, 2);
    DECLARE @LegacyObject SYSNAME = PARSENAME(@LegacyTableName, 1);
    DECLARE @LegacyQualified NVARCHAR(512);

    IF @LegacyObject IS NULL
    BEGIN
        SET @LegacyObject = @LegacyTableName;
        SET @LegacySchema = 'dbo';
        SET @LegacyDb = DB_NAME();
    END
    ELSE
    BEGIN
        SET @LegacySchema = ISNULL(@LegacySchema, 'dbo');
        SET @LegacyDb = ISNULL(@LegacyDb, DB_NAME());
    END

    SET @LegacyQualified =
        QUOTENAME(@LegacyDb) + N'.' +
        QUOTENAME(@LegacySchema) + N'.' +
        QUOTENAME(@LegacyObject);

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.databases d
        WHERE d.name = @LegacyDb
    )
    BEGIN
        THROW 50010, 'Legacy bootstrap table was not found.', 1;
    END

    SET @ResolvedPurchaseOrderId = NULLIF(@PurchaseOrderId, '');

    IF @ResolvedPurchaseOrderId IS NOT NULL
    BEGIN
        SELECT TOP (1)
            @ResolvedDBID = p.DBID__c,
            @ResolvedPOID = p.POID__c,
            @ResolvedPONumber = p.[Name]
        FROM AO.PurchaseOrder p
        WHERE p.Id = @ResolvedPurchaseOrderId;
    END
    ELSE
    BEGIN
        SET @ResolvedDBID = @DBID;
        SET @ResolvedPOID = @POID;

        SELECT TOP (1)
            @ResolvedPurchaseOrderId = p.Id,
            @ResolvedPONumber = p.[Name]
        FROM AO.PurchaseOrder p
        WHERE p.DBID__c = @ResolvedDBID
          AND p.POID__c = @ResolvedPOID;
    END

    IF @ResolvedDBID IS NULL OR @ResolvedPOID IS NULL
    BEGIN
        THROW 50011, 'Could not resolve AO purchase order metadata for bootstrap.', 1;
    END

    IF @ReplaceExisting = 1
    BEGIN
        DELETE s
        FROM SRC.PurchaseOrderItemSnapshotV2 s
        JOIN SRC.PurchaseOrderItemSnapshotRunV2 r
            ON r.SnapshotRunId = s.SnapshotRunId
        WHERE r.DBID = @ResolvedDBID
          AND r.POID = @ResolvedPOID;

        DELETE r
        FROM SRC.PurchaseOrderItemSnapshotRunV2 r
        WHERE r.DBID = @ResolvedDBID
          AND r.POID = @ResolvedPOID;
    END

    INSERT INTO SRC.PurchaseOrderItemSnapshotRunV2
    (
        PurchaseOrderId,
        DBID,
        POID,
        PONumber,
        IsInitial,
        NotificationType,
        SchedulerData,
        ResetMode
    )
    VALUES
    (
        ISNULL(@ResolvedPurchaseOrderId, ''),
        @ResolvedDBID,
        @ResolvedPOID,
        ISNULL(@ResolvedPONumber, CAST(@ResolvedPOID AS VARCHAR(96))),
        1,
        'Bootstrap',
        CONCAT('{\"LegacyTable\":\"', @LegacyTableName, '\"}'),
        'N'
    );

    SET @SnapshotRunId = SCOPE_IDENTITY();

    SET @sql = N'
;WITH LegacySource AS
(
    SELECT *
    FROM ' + @LegacyQualified + N'
    WHERE DBID = @DBID
      AND POID = @POID
      AND TransactionType IN (''O'', ''S1'', ''S'')
),
OrderedRows AS
(
    SELECT
        ''P'' AS RowType,
        CONCAT(DBID, '':'', POID, '':P:'', LineUID) AS RowKey,
        CAST(NULL AS VARCHAR(200)) AS ParentRowKey,
        DBID,
        POID,
        POnumber,
        LineUID AS OrderedLineUID,
        LineNumber AS OrderedLineNumber,
        CAST(NULL AS INT) AS LogicalChildUID,
        LineUID AS SourceLineUID,
        CAST(NULLIF(ShipmentLineUID, -1) AS INT) AS SourceShipmentLineUID,
        LineUID AS GroupLineUID,
        CAST(NULL AS CHAR(1)) AS ParentItem,
        0 AS ChildCount,
        ''Ordered'' AS SourceState,
        ManufacturerName,
        FixtureType,
        PartNumber,
        Ordered AS QtyOrdered,
        Released AS QtyReleased,
        CAST(0 AS NUMERIC(12,2)) AS QtyShipped,
        CAST(NULL AS DATE) AS EstimatedShipDate,
        CAST(NULL AS DATE) AS ShipDate,
        CAST(NULL AS VARCHAR(130)) AS Carrier,
        CAST(NULL AS VARCHAR(80)) AS TrackingNumber,
        RowHash AS SourceRowHash
    FROM LegacySource
    WHERE TransactionType = ''O''
),
ChildRowsBase AS
(
    SELECT
        ls.DBID,
        ls.POID,
        ls.POnumber,
        COALESCE(NULLIF(ls.GroupLineUID, 0), ls.LineUID) AS OrderedLineUID,
        COALESCE(o.OrderedLineNumber, ls.LineNumber) AS OrderedLineNumber,
        COALESCE(NULLIF(ls.ShipmentLineUID, -1), ls.LineUID) AS LogicalChildUID,
        COALESCE(NULLIF(ls.GroupLineUID, 0), ls.LineUID) AS GroupLineUID,
        ls.LineUID,
        ls.ShipmentLineUID,
        ls.TransactionType,
        ls.ORSdate,
        ls.Ordered,
        ls.Released,
        ls.Shipped,
        ls.Carrier,
        ls.TrackingNumber,
        COALESCE(NULLIF(ls.ManufacturerName, ''''), o.ManufacturerName) AS ManufacturerName,
        COALESCE(NULLIF(ls.FixtureType, ''''), o.FixtureType) AS FixtureType,
        COALESCE(NULLIF(ls.PartNumber, ''''), o.PartNumber) AS PartNumber,
        ls.RowHash
    FROM LegacySource ls
    LEFT JOIN OrderedRows o
        ON o.DBID = ls.DBID
       AND o.POID = ls.POID
       AND o.OrderedLineUID = COALESCE(NULLIF(ls.GroupLineUID, 0), ls.LineUID)
    WHERE ls.TransactionType IN (''S1'', ''S'')
),
ChildCounts AS
(
    SELECT
        DBID,
        POID,
        OrderedLineUID,
        COUNT(DISTINCT GroupLineUID) AS ChildCount
    FROM ChildRowsBase
    GROUP BY DBID, POID, OrderedLineUID
),
ChildRows AS
(
    SELECT
        ''C'' AS RowType,
        CONCAT(c.DBID, '':'', c.POID, '':C:'', c.OrderedLineUID, '':'', c.LogicalChildUID) AS RowKey,
        CONCAT(c.DBID, '':'', c.POID, '':P:'', c.OrderedLineUID) AS ParentRowKey,
        c.DBID,
        c.POID,
        c.POnumber,
        c.OrderedLineUID,
        c.OrderedLineNumber,
        c.LogicalChildUID,
        MAX(c.LineUID) AS SourceLineUID,
        MAX(NULLIF(c.ShipmentLineUID, -1)) AS SourceShipmentLineUID,
        c.GroupLineUID,
        CAST(CASE WHEN cc.ChildCount > 0 THEN ''Y'' ELSE NULL END AS CHAR(1)) AS ParentItem,
        cc.ChildCount,
        CASE
            WHEN MAX(CASE WHEN c.TransactionType = ''S'' THEN 1 ELSE 0 END) = 1 THEN ''Shipped''
            ELSE ''Scheduled''
        END AS SourceState,
        MAX(c.ManufacturerName) AS ManufacturerName,
        MAX(c.FixtureType) AS FixtureType,
        MAX(c.PartNumber) AS PartNumber,
        MAX(o.QtyOrdered) AS QtyOrdered,
        MAX(o.QtyReleased) AS QtyReleased,
        SUM(CASE WHEN c.TransactionType = ''S'' THEN ISNULL(c.Shipped, 0) ELSE 0 END) AS QtyShipped,
        MAX(CASE WHEN c.TransactionType = ''S1'' AND YEAR(c.ORSdate) > 1900 AND CONVERT(DATE, c.ORSdate) <> CONVERT(DATE, ''20991231'') THEN c.ORSdate END) AS EstimatedShipDate,
        MAX(CASE WHEN c.TransactionType = ''S'' AND YEAR(c.ORSdate) > 1900 THEN c.ORSdate END) AS ShipDate,
        MAX(CASE WHEN c.TransactionType = ''S'' THEN c.Carrier END) AS Carrier,
        MAX(CASE WHEN c.TransactionType = ''S'' THEN c.TrackingNumber END) AS TrackingNumber,
        MAX(c.RowHash) AS SourceRowHash
    FROM ChildRowsBase c
    LEFT JOIN OrderedRows o
        ON o.DBID = c.DBID
       AND o.POID = c.POID
       AND o.OrderedLineUID = c.OrderedLineUID
    LEFT JOIN ChildCounts cc
        ON cc.DBID = c.DBID
       AND cc.POID = c.POID
       AND cc.OrderedLineUID = c.OrderedLineUID
    GROUP BY
        c.DBID,
        c.POID,
        c.POnumber,
        c.OrderedLineUID,
        c.OrderedLineNumber,
        c.LogicalChildUID,
        c.GroupLineUID,
        cc.ChildCount
)
INSERT INTO SRC.PurchaseOrderItemSnapshotV2
(
    SnapshotRunId,
    DBID,
    POID,
    POnumber,
    RowType,
    RowKey,
    ParentRowKey,
    OrderedLineUID,
    OrderedLineNumber,
    LogicalChildUID,
    SourceLineUID,
    SourceShipmentLineUID,
    GroupLineUID,
    ParentItem,
    ChildCount,
    SourceState,
    ManufacturerName,
    FixtureType,
    PartNumber,
    QtyOrdered,
    QtyReleased,
    QtyShipped,
    EstimatedShipDate,
    ShipDate,
    Carrier,
    TrackingNumber,
    SourceRowHash
)
SELECT
    @SnapshotRunId,
    DBID,
    POID,
    POnumber,
    RowType,
    RowKey,
    ParentRowKey,
    OrderedLineUID,
    OrderedLineNumber,
    LogicalChildUID,
    SourceLineUID,
    SourceShipmentLineUID,
    GroupLineUID,
    ParentItem,
    ChildCount,
    SourceState,
    ManufacturerName,
    FixtureType,
    PartNumber,
    QtyOrdered,
    QtyReleased,
    QtyShipped,
    EstimatedShipDate,
    ShipDate,
    Carrier,
    TrackingNumber,
    SourceRowHash
FROM OrderedRows
UNION ALL
SELECT
    @SnapshotRunId,
    DBID,
    POID,
    POnumber,
    RowType,
    RowKey,
    ParentRowKey,
    OrderedLineUID,
    OrderedLineNumber,
    LogicalChildUID,
    SourceLineUID,
    SourceShipmentLineUID,
    GroupLineUID,
    ParentItem,
    ChildCount,
    SourceState,
    ManufacturerName,
    FixtureType,
    PartNumber,
    QtyOrdered,
    QtyReleased,
    QtyShipped,
    EstimatedShipDate,
    ShipDate,
    Carrier,
    TrackingNumber,
    SourceRowHash
FROM ChildRows;';

    EXEC sp_executesql
        @sql,
        N'@DBID VARCHAR(32), @POID INT, @SnapshotRunId BIGINT',
        @DBID = @ResolvedDBID,
        @POID = @ResolvedPOID,
        @SnapshotRunId = @SnapshotRunId;
END;
GO
