-- Generated from live PLS V2 program objects on 2026-04-18 UTC
USE [PLS];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW SRC.vw_PurchaseOrderItemCurrentLogicalV2
AS
WITH OrderedLineAnchors AS
(
    SELECT DISTINCT
        src.DBID,
        src.POId AS POID,
        src.LineUID
    FROM SRC.PurchaseOrderItem src
    WHERE src.TransactionType = 'O'
      AND NOT EXISTS
      (
          SELECT 1
          FROM OASIS_PLS.oasis.CHSC_POLINE suppressedLine
          WHERE suppressedLine.DBID = src.DBID
            AND suppressedLine.POID = src.POId
            AND suppressedLine.LINEUID = src.LineUID
            AND ISNULL(suppressedLine.QUANTITYCODE, '') = 'N'
      )
      AND (src.PartNumber NOT LIKE '%LOT%' OR src.PartNumber LIKE '%PILOT%')
      AND src.PartNumber NOT LIKE '%SELL%'
      AND src.PartNumber NOT LIKE '%PRICE%'
      AND src.FixtureType NOT LIKE '%LOT%'
),
RawFiltered AS
(
    SELECT
        CAST(ISNULL(src.PurchaseOrderId, po.Id) AS VARCHAR(24)) AS PurchaseOrderId,
        src.DBID,
        src.POId AS POID,
        CAST(ISNULL(po.[Name], CAST(src.POId AS VARCHAR(96))) AS VARCHAR(96)) AS PONumber,
        src.TransactionType,
        src.LineUID,
        src.LineNumber,
        src.ShipmentLineUID,
        src.ParentLineUID,
        CAST(
            CASE
                WHEN src.TransactionType IN ('S1', 'S')
                     AND own.LineUID IS NOT NULL THEN src.LineUID
                ELSE COALESCE(NULLIF(src.ParentLineUID, 0), src.LineUID)
            END
            AS INT
        ) AS GroupLineUID,
        CAST(
            CASE
                WHEN src.TransactionType IN ('S1', 'S')
                     AND own.LineUID IS NOT NULL THEN src.LineUID
                ELSE COALESCE(NULLIF(src.ParentLineUID, 0), src.LineUID)
            END
            AS INT
        ) AS OrderedLineUID,
        CAST(
            CASE
                WHEN src.TransactionType = 'S' THEN COALESCE(NULLIF(src.ShipmentLineUID, 0), src.LineUID)
                ELSE COALESCE(NULLIF(src.ShipmentLineUID, 0), src.LineUID)
            END
            AS INT
        ) AS LogicalChildUID,
        src.Ordered,
        src.Released,
        src.Shipped,
        src.TargetDate,
        src.ShippedDate,
        src.Carrier,
        src.TrackingNumber,
        CAST(ISNULL(acct.[Name], '') AS NVARCHAR(255)) AS ManufacturerName,
        src.FixtureType,
        src.PartNumber,
        src.RowHash
    FROM SRC.PurchaseOrderItem src
    LEFT JOIN OrderedLineAnchors own
        ON own.DBID = src.DBID
       AND own.POID = src.POId
       AND own.LineUID = src.LineUID
    LEFT JOIN AO.PurchaseOrder po
        ON po.Id = src.PurchaseOrderId
        OR (po.DBID__c = src.DBID AND po.POId__c = src.POId)
    LEFT JOIN AO.Account acct
        ON acct.Id = src.ManufacturerId
    WHERE src.TransactionType IN ('O', 'S1', 'S')
      AND NOT EXISTS
      (
          SELECT 1
          FROM OASIS_PLS.oasis.CHSC_POLINE suppressedLine
          WHERE suppressedLine.DBID = src.DBID
            AND suppressedLine.POID = src.POId
            AND suppressedLine.LINEUID = src.LineUID
            AND ISNULL(suppressedLine.QUANTITYCODE, '') = 'N'
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM OASIS_PLS.oasis.CHSC_POLINE suppressedOrdered
          WHERE suppressedOrdered.DBID = src.DBID
            AND suppressedOrdered.POID = src.POId
            AND suppressedOrdered.LINEUID = COALESCE(NULLIF(src.ParentLineUID, 0), src.LineUID)
            AND ISNULL(suppressedOrdered.QUANTITYCODE, '') = 'N'
      )
      AND (src.PartNumber NOT LIKE '%LOT%' OR src.PartNumber LIKE '%PILOT%')
      AND src.PartNumber NOT LIKE '%SELL%'
      AND src.PartNumber NOT LIKE '%PRICE%'
      AND src.FixtureType NOT LIKE '%LOT%'
),
OrderedRows AS
(
    SELECT
        rf.PurchaseOrderId,
        rf.DBID,
        rf.POID,
        rf.POnumber,
        'P' AS RowType,
        CONCAT(rf.DBID, ':', rf.POID, ':P:', rf.LineUID) AS RowKey,
        CAST(NULL AS VARCHAR(200)) AS ParentRowKey,
        rf.LineUID AS OrderedLineUID,
        rf.LineNumber AS OrderedLineNumber,
        CAST(NULL AS INT) AS LogicalChildUID,
        rf.LineUID AS SourceLineUID,
        CAST(NULL AS INT) AS SourceShipmentLineUID,
        rf.LineUID AS GroupLineUID,
        CAST(NULL AS CHAR(1)) AS ParentItem,
        0 AS ChildCount,
        'Ordered' AS SourceState,
        rf.ManufacturerName,
        rf.FixtureType,
        rf.PartNumber,
        MAX(rf.Ordered) AS QtyOrdered,
        MAX(rf.Released) AS QtyReleased,
        CAST(0 AS NUMERIC(12,2)) AS QtyShipped,
        CAST(NULL AS DATE) AS EstimatedShipDate,
        CAST(NULL AS DATE) AS ShipDate,
        CAST(NULL AS VARCHAR(130)) AS Carrier,
        CAST(NULL AS VARCHAR(80)) AS TrackingNumber,
        MAX(rf.RowHash) AS SourceRowHash
    FROM RawFiltered rf
    WHERE rf.TransactionType = 'O'
    GROUP BY
        rf.PurchaseOrderId,
        rf.DBID,
        rf.POID,
        rf.POnumber,
        rf.LineUID,
        rf.LineNumber,
        rf.ManufacturerName,
        rf.FixtureType,
        rf.PartNumber
),
ChildRowsBase AS
(
    SELECT
        rf.PurchaseOrderId,
        rf.DBID,
        rf.POID,
        rf.POnumber,
        rf.OrderedLineUID,
        COALESCE(o.OrderedLineNumber, rf.LineNumber) AS OrderedLineNumber,
        rf.LogicalChildUID,
        rf.GroupLineUID,
        rf.LineUID,
        rf.ShipmentLineUID,
        rf.TransactionType,
        rf.TargetDate,
        rf.ShippedDate,
        rf.Ordered,
        rf.Released,
        rf.Shipped,
        rf.Carrier,
        rf.TrackingNumber,
        COALESCE(NULLIF(rf.ManufacturerName, ''), o.ManufacturerName) AS ManufacturerName,
        COALESCE(NULLIF(rf.FixtureType, ''), o.FixtureType) AS FixtureType,
        COALESCE(NULLIF(rf.PartNumber, ''), o.PartNumber) AS PartNumber,
        rf.RowHash
    FROM RawFiltered rf
    LEFT JOIN OrderedRows o
        ON o.DBID = rf.DBID
       AND o.POID = rf.POID
       AND o.OrderedLineUID = rf.OrderedLineUID
    WHERE rf.TransactionType IN ('S1', 'S')
),
ChildCounts AS
(
    SELECT
        DBID,
        POID,
        OrderedLineUID,
        COUNT(DISTINCT LogicalChildUID) AS ChildCount
    FROM ChildRowsBase
    GROUP BY DBID, POID, OrderedLineUID
),
ChildRowsAgg AS
(
    SELECT
        c.PurchaseOrderId,
        c.DBID,
        c.POID,
        c.POnumber,
        'C' AS RowType,
        CONCAT(c.DBID, ':', c.POID, ':C:', c.OrderedLineUID, ':', c.LogicalChildUID) AS RowKey,
        CONCAT(c.DBID, ':', c.POID, ':P:', c.OrderedLineUID) AS ParentRowKey,
        c.OrderedLineUID,
        c.OrderedLineNumber,
        c.LogicalChildUID,
        MAX(c.LineUID) AS SourceLineUID,
        MAX(NULLIF(c.ShipmentLineUID, 0)) AS SourceShipmentLineUID,
        c.GroupLineUID,
        CAST(CASE WHEN cc.ChildCount > 0 THEN 'Y' ELSE NULL END AS CHAR(1)) AS ParentItem,
        cc.ChildCount,
        CASE
            WHEN MAX(CASE WHEN c.TransactionType = 'S' THEN 1 ELSE 0 END) = 1 THEN 'Shipped'
            ELSE 'Scheduled'
        END AS SourceState,
        MAX(c.ManufacturerName) AS ManufacturerName,
        MAX(c.FixtureType) AS FixtureType,
        MAX(c.PartNumber) AS PartNumber,
        MAX(o.QtyOrdered) AS QtyOrdered,
        MAX(o.QtyReleased) AS QtyReleased,
        SUM(CASE WHEN c.TransactionType = 'S' THEN ISNULL(c.Shipped, 0) ELSE 0 END) AS QtyShipped,
        CAST(
            MAX(
                CASE
                    WHEN c.TransactionType = 'S1'
                         AND YEAR(c.TargetDate) > 1900
                         AND CONVERT(DATE, c.TargetDate) <> CONVERT(DATE, '20991231')
                         AND YEAR(c.ShippedDate) > 1900
                         AND CONVERT(DATE, c.ShippedDate) <> CONVERT(DATE, '20991231')
                         AND c.TargetDate < c.ShippedDate THEN c.ShippedDate
                    WHEN c.TransactionType = 'S1'
                         AND YEAR(c.TargetDate) > 1900
                         AND CONVERT(DATE, c.TargetDate) <> CONVERT(DATE, '20991231') THEN c.TargetDate
                    ELSE NULL
                END
            ) AS DATE
        ) AS RawEstimatedShipDate,
        CAST(
            MAX(
                CASE
                    WHEN c.TransactionType = 'S' AND YEAR(c.ShippedDate) > 1900 THEN c.ShippedDate
                    WHEN c.TransactionType = 'S' AND YEAR(c.TargetDate) > 1900 THEN c.TargetDate
                    ELSE NULL
                END
            ) AS DATE
        ) AS ShipDate,
        MAX(CASE WHEN c.TransactionType = 'S' THEN c.Carrier END) AS Carrier,
        MAX(CASE WHEN c.TransactionType = 'S' THEN c.TrackingNumber END) AS TrackingNumber,
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
        c.PurchaseOrderId,
        c.DBID,
        c.POID,
        c.POnumber,
        c.OrderedLineUID,
        c.OrderedLineNumber,
        c.LogicalChildUID,
        c.GroupLineUID,
        cc.ChildCount
),
PreviousChildESD AS
(
    SELECT
        s.DBID,
        s.POID,
        s.RowKey,
        s.OrderedLineUID,
        s.SourceLineUID,
        s.PartNumber,
        s.EstimatedShipDate,
        r.SnapshotRunId
    FROM SRC.PurchaseOrderItemSnapshotV2 s
    JOIN SRC.PurchaseOrderItemSnapshotRunV2 r
        ON r.SnapshotRunId = s.SnapshotRunId
    WHERE s.RowType = 'C'
      AND s.EstimatedShipDate IS NOT NULL
      AND s.EstimatedShipDate <> CONVERT(DATE, '20991231')
),
ChildRows AS
(
    SELECT
        c.PurchaseOrderId,
        c.DBID,
        c.POID,
        c.POnumber,
        c.RowType,
        c.RowKey,
        c.ParentRowKey,
        c.OrderedLineUID,
        c.OrderedLineNumber,
        c.LogicalChildUID,
        c.SourceLineUID,
        c.SourceShipmentLineUID,
        c.GroupLineUID,
        c.ParentItem,
        c.ChildCount,
        c.SourceState,
        c.ManufacturerName,
        c.FixtureType,
        c.PartNumber,
        c.QtyOrdered,
        c.QtyReleased,
        c.QtyShipped,
        COALESCE(
            c.RawEstimatedShipDate,
            p.EstimatedShipDate
        ) AS EstimatedShipDate,
        c.ShipDate,
        c.Carrier,
        c.TrackingNumber,
        c.SourceRowHash
    FROM ChildRowsAgg c
    OUTER APPLY
    (
        SELECT TOP (1)
            prev.EstimatedShipDate
        FROM PreviousChildESD prev
        WHERE prev.DBID = c.DBID
          AND prev.POID = c.POID
          AND
          (
              (
                  prev.RowKey = c.RowKey
                  AND ISNULL(prev.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
              )
              OR
              (
                  c.SourceState = 'Shipped'
                  AND prev.OrderedLineUID = c.OrderedLineUID
                  AND ISNULL(prev.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
              )
              OR
              (
                  c.SourceState = 'Shipped'
                  AND c.SourceLineUID IS NULL
                  AND prev.OrderedLineUID = c.OrderedLineUID
                  AND ISNULL(prev.PartNumber, '') = ISNULL(c.PartNumber, '')
              )
          )
        ORDER BY
            CASE
                WHEN prev.RowKey = c.RowKey
                     AND ISNULL(prev.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1) THEN 0
                WHEN c.SourceState = 'Shipped'
                     AND prev.OrderedLineUID = c.OrderedLineUID
                     AND ISNULL(prev.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1) THEN 1
                ELSE 2
            END,
            prev.SnapshotRunId DESC
    ) p
)
SELECT
    PurchaseOrderId,
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
    PurchaseOrderId,
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
FROM ChildRows;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  4. Latest snapshot view
---------------------------------------------------------------------------*/
CREATE OR ALTER VIEW SRC.vw_PurchaseOrderItemSnapshotCurrentV2
AS
WITH LatestRun AS
(
    SELECT
        r.*,
        ROW_NUMBER() OVER (PARTITION BY r.DBID, r.POID ORDER BY r.SnapshotRunId DESC) AS rn
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
)
SELECT
    r.SnapshotRunId,
    r.PurchaseOrderId,
    r.DBID,
    r.POID,
    r.PONumber,
    r.IsInitial,
    r.NotificationType,
    s.SnapshotRowId,
    s.RowType,
    s.RowKey,
    s.ParentRowKey,
    s.OrderedLineUID,
    s.OrderedLineNumber,
    s.LogicalChildUID,
    s.SourceLineUID,
    s.SourceShipmentLineUID,
    s.GroupLineUID,
    s.ParentItem,
    s.ChildCount,
    s.SourceState,
    s.ManufacturerName,
    s.FixtureType,
    s.PartNumber,
    s.QtyOrdered,
    s.QtyReleased,
    s.QtyShipped,
    s.EstimatedShipDate,
    s.ShipDate,
    s.Carrier,
    s.TrackingNumber,
    s.SourceRowHash,
    s.CreatedAt
FROM LatestRun r
JOIN SRC.PurchaseOrderItemSnapshotV2 s
    ON s.SnapshotRunId = r.SnapshotRunId
WHERE r.rn = 1;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  5. Diff view
     This is where field-by-field comparison should live.
---------------------------------------------------------------------------*/
CREATE OR ALTER VIEW [SRC].[vw_PurchaseOrderItemSnapshotDiffV2]
AS
WITH Runs AS
(
    SELECT
        r.*,
        ROW_NUMBER() OVER (PARTITION BY r.DBID, r.POID ORDER BY r.SnapshotRunId DESC) AS rn
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
),
CurrentRun AS
(
    SELECT * FROM Runs WHERE rn = 1
),
PreviousRun AS
(
    SELECT prev.*
    FROM CurrentRun c
    OUTER APPLY
    (
        SELECT TOP (1)
            r.*
        FROM SRC.PurchaseOrderItemSnapshotRunV2 r
        WHERE r.DBID = c.DBID
          AND r.POID = c.POID
          AND r.SnapshotRunId < c.SnapshotRunId
          AND EXISTS
          (
              SELECT 1
              FROM SRC.PurchaseOrderItemSnapshotV2 s
              WHERE s.SnapshotRunId = r.SnapshotRunId
                AND s.RowType = 'P'
          )
        ORDER BY r.SnapshotRunId DESC
    ) prev
),
CurrentRows AS
(
    SELECT
        r.SnapshotRunId,
        r.PurchaseOrderId,
        r.DBID,
        r.POID,
        r.PONumber,
        r.IsInitial,
        s.RowType,
        s.RowKey,
        s.ParentRowKey,
        s.OrderedLineUID,
        s.OrderedLineNumber,
        s.LogicalChildUID,
        s.SourceLineUID,
        s.SourceShipmentLineUID,
        s.GroupLineUID,
        s.ParentItem,
        s.ChildCount,
        s.SourceState,
        s.ManufacturerName,
        s.FixtureType,
        s.PartNumber,
        s.QtyOrdered,
        s.QtyReleased,
        s.QtyShipped,
        s.EstimatedShipDate,
        s.ShipDate,
        s.Carrier,
        s.TrackingNumber,
        s.SourceRowHash
    FROM CurrentRun r
    JOIN SRC.PurchaseOrderItemSnapshotV2 s
        ON s.SnapshotRunId = r.SnapshotRunId
),
PreviousRows AS
(
    SELECT
        r.SnapshotRunId,
        r.PurchaseOrderId,
        r.DBID,
        r.POID,
        r.PONumber,
        r.IsInitial,
        s.RowType,
        s.RowKey,
        s.ParentRowKey,
        s.OrderedLineUID,
        s.OrderedLineNumber,
        s.LogicalChildUID,
        s.SourceLineUID,
        s.SourceShipmentLineUID,
        s.GroupLineUID,
        s.ParentItem,
        s.ChildCount,
        s.SourceState,
        s.ManufacturerName,
        s.FixtureType,
        s.PartNumber,
        s.QtyOrdered,
        s.QtyReleased,
        s.QtyShipped,
        s.EstimatedShipDate,
        s.ShipDate,
        s.Carrier,
        s.TrackingNumber,
        s.SourceRowHash
    FROM PreviousRun r
    JOIN SRC.PurchaseOrderItemSnapshotV2 s
        ON s.SnapshotRunId = r.SnapshotRunId
),
CompatCandidates AS
(
    SELECT
        c.SnapshotRunId,
        c.PurchaseOrderId,
        c.DBID,
        c.POID,
        c.PONumber,
        c.RowType,
        c.RowKey,
        c.ParentRowKey,
        c.OrderedLineUID,
        c.OrderedLineNumber,
        c.LogicalChildUID,
        c.SourceLineUID,
        c.SourceShipmentLineUID,
        c.GroupLineUID,
        c.ParentItem,
        c.ChildCount,
        c.SourceState,
        c.IsInitial AS CurrentIsInitial,
        1 AS HasCurrent,
        1 AS HasPrevious,
        c.ManufacturerName AS CurrentManufacturerName,
        p.ManufacturerName AS PreviousManufacturerName,
        c.FixtureType AS CurrentFixtureType,
        p.FixtureType AS PreviousFixtureType,
        c.PartNumber AS CurrentPartNumber,
        p.PartNumber AS PreviousPartNumber,
        c.QtyOrdered AS CurrentQtyOrdered,
        p.QtyOrdered AS PreviousQtyOrdered,
        c.QtyReleased AS CurrentQtyReleased,
        p.QtyReleased AS PreviousQtyReleased,
        c.QtyShipped AS CurrentQtyShipped,
        p.QtyShipped AS PreviousQtyShipped,
        c.EstimatedShipDate AS CurrentEstimatedShipDate,
        p.EstimatedShipDate AS PreviousEstimatedShipDate,
        c.ShipDate AS CurrentShipDate,
        p.ShipDate AS PreviousShipDate,
        c.Carrier AS CurrentCarrier,
        p.Carrier AS PreviousCarrier,
        c.TrackingNumber AS CurrentTrackingNumber,
        p.TrackingNumber AS PreviousTrackingNumber,
        COALESCE(c.SourceRowHash, p.SourceRowHash) AS SourceRowHash,
        c.RowKey AS CurrentRowKey,
        p.RowKey AS PreviousRowKey,
        ROW_NUMBER() OVER (
            PARTITION BY c.RowKey
            ORDER BY
                CASE
                    WHEN p.RowKey = c.RowKey THEN 0
                    WHEN ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
                         AND ISNULL(p.SourceShipmentLineUID, -1) = ISNULL(c.SourceShipmentLineUID, -1)
                         AND ISNULL(p.SourceLineUID, -1) <> -1 THEN 1
                    WHEN ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
                         AND ISNULL(p.SourceLineUID, -1) <> -1
                         AND p.SourceState = c.SourceState THEN 2
                    WHEN ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
                         AND ISNULL(p.SourceLineUID, -1) <> -1 THEN 3
                    WHEN ISNULL(p.SourceShipmentLineUID, -1) = ISNULL(c.SourceShipmentLineUID, -1)
                         AND ISNULL(p.SourceShipmentLineUID, -1) <> -1 THEN 4
                    WHEN p.SourceState = 'Shipped'
                         AND c.SourceState = 'Shipped'
                         AND ISNULL(p.QtyShipped, -999999.99) = ISNULL(c.QtyShipped, -999999.99)
                         AND ISNULL(CONVERT(VARCHAR(10), p.ShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.ShipDate, 23), '')
                         AND ISNULL(p.Carrier, '') = ISNULL(c.Carrier, '')
                         AND ISNULL(p.TrackingNumber, '') = ISNULL(c.TrackingNumber, '') THEN 5
                    WHEN p.SourceState = c.SourceState
                         AND ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '')
                         AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '') THEN 6
                    WHEN p.SourceState <> c.SourceState
                         AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '') THEN 7
                    WHEN p.SourceState = c.SourceState
                         AND ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '') THEN 8
                    WHEN ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '') THEN 9
                    ELSE 10
                END,
                p.RowKey
        ) AS CurrentChoiceRank,
        ROW_NUMBER() OVER (
            PARTITION BY p.RowKey
            ORDER BY
                CASE
                    WHEN c.RowKey = p.RowKey THEN 0
                    WHEN ISNULL(c.SourceLineUID, -1) = ISNULL(p.SourceLineUID, -1)
                         AND ISNULL(c.SourceShipmentLineUID, -1) = ISNULL(p.SourceShipmentLineUID, -1)
                         AND ISNULL(c.SourceLineUID, -1) <> -1 THEN 1
                    WHEN ISNULL(c.SourceLineUID, -1) = ISNULL(p.SourceLineUID, -1)
                         AND ISNULL(c.SourceLineUID, -1) <> -1
                         AND c.SourceState = p.SourceState THEN 2
                    WHEN ISNULL(c.SourceLineUID, -1) = ISNULL(p.SourceLineUID, -1)
                         AND ISNULL(c.SourceLineUID, -1) <> -1 THEN 3
                    WHEN ISNULL(c.SourceShipmentLineUID, -1) = ISNULL(p.SourceShipmentLineUID, -1)
                         AND ISNULL(c.SourceShipmentLineUID, -1) <> -1 THEN 4
                    WHEN c.SourceState = 'Shipped'
                         AND p.SourceState = 'Shipped'
                         AND ISNULL(c.QtyShipped, -999999.99) = ISNULL(p.QtyShipped, -999999.99)
                         AND ISNULL(CONVERT(VARCHAR(10), c.ShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), p.ShipDate, 23), '')
                         AND ISNULL(c.Carrier, '') = ISNULL(p.Carrier, '')
                         AND ISNULL(c.TrackingNumber, '') = ISNULL(p.TrackingNumber, '') THEN 5
                    WHEN c.SourceState = p.SourceState
                         AND ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '')
                         AND ISNULL(c.PartNumber, '') = ISNULL(p.PartNumber, '') THEN 6
                    WHEN c.SourceState <> p.SourceState
                         AND ISNULL(c.PartNumber, '') = ISNULL(p.PartNumber, '') THEN 7
                    WHEN c.SourceState = p.SourceState
                         AND ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '') THEN 8
                    WHEN ISNULL(c.PartNumber, '') = ISNULL(p.PartNumber, '') THEN 9
                    ELSE 10
                END,
                c.RowKey
        ) AS PreviousChoiceRank
    FROM CurrentRows c
    INNER JOIN PreviousRows p
        ON p.DBID = c.DBID
       AND p.POID = c.POID
       AND p.RowType = c.RowType
       AND p.RowType = 'C'
       AND p.OrderedLineUID = c.OrderedLineUID
       AND
       (
           p.RowKey = c.RowKey
           OR
           (
               ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
               AND ISNULL(p.SourceLineUID, -1) <> -1
           )
           OR
           (
               ISNULL(p.SourceShipmentLineUID, -1) = ISNULL(c.SourceShipmentLineUID, -1)
               AND ISNULL(p.SourceShipmentLineUID, -1) <> -1
           )
           OR
           (
               p.SourceState = 'Shipped'
               AND c.SourceState = 'Shipped'
               AND ISNULL(p.QtyShipped, -999999.99) = ISNULL(c.QtyShipped, -999999.99)
               AND ISNULL(CONVERT(VARCHAR(10), p.ShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.ShipDate, 23), '')
               AND ISNULL(p.Carrier, '') = ISNULL(c.Carrier, '')
               AND ISNULL(p.TrackingNumber, '') = ISNULL(c.TrackingNumber, '')
           )
           OR
           (
               ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '')
               AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '')
           )
           OR
           (
               p.SourceState <> c.SourceState
               AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '')
           )
       )
),
CompatMatchedRows AS
(
    SELECT
        SnapshotRunId,
        PurchaseOrderId,
        DBID,
        POID,
        PONumber,
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
        CurrentIsInitial,
        HasCurrent,
        HasPrevious,
        CurrentManufacturerName,
        PreviousManufacturerName,
        CurrentFixtureType,
        PreviousFixtureType,
        CurrentPartNumber,
        PreviousPartNumber,
        CurrentQtyOrdered,
        PreviousQtyOrdered,
        CurrentQtyReleased,
        PreviousQtyReleased,
        CurrentQtyShipped,
        PreviousQtyShipped,
        CurrentEstimatedShipDate,
        PreviousEstimatedShipDate,
        CurrentShipDate,
        PreviousShipDate,
        CurrentCarrier,
        PreviousCarrier,
        CurrentTrackingNumber,
        PreviousTrackingNumber,
        SourceRowHash,
        CurrentRowKey,
        PreviousRowKey
    FROM CompatCandidates
    WHERE CurrentChoiceRank = 1
      AND PreviousChoiceRank = 1
),
CurrentAfterCompat AS
(
    SELECT c.*
    FROM CurrentRows c
    LEFT JOIN CompatMatchedRows m
        ON m.CurrentRowKey = c.RowKey
    WHERE m.CurrentRowKey IS NULL
),
PreviousAfterCompat AS
(
    SELECT p.*
    FROM PreviousRows p
    LEFT JOIN CompatMatchedRows m
        ON m.PreviousRowKey = p.RowKey
    WHERE m.PreviousRowKey IS NULL
),
MatchedRows AS
(
    SELECT
        SnapshotRunId,
        PurchaseOrderId,
        DBID,
        POID,
        PONumber,
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
        CurrentIsInitial,
        HasCurrent,
        HasPrevious,
        CurrentManufacturerName,
        PreviousManufacturerName,
        CurrentFixtureType,
        PreviousFixtureType,
        CurrentPartNumber,
        PreviousPartNumber,
        CurrentQtyOrdered,
        PreviousQtyOrdered,
        CurrentQtyReleased,
        PreviousQtyReleased,
        CurrentQtyShipped,
        PreviousQtyShipped,
        CurrentEstimatedShipDate,
        PreviousEstimatedShipDate,
        CurrentShipDate,
        PreviousShipDate,
        CurrentCarrier,
        PreviousCarrier,
        CurrentTrackingNumber,
        PreviousTrackingNumber,
        SourceRowHash
    FROM CompatMatchedRows

    UNION ALL

    SELECT
        COALESCE(c.SnapshotRunId, p.SnapshotRunId) AS SnapshotRunId,
        COALESCE(c.PurchaseOrderId, p.PurchaseOrderId) AS PurchaseOrderId,
        COALESCE(c.DBID, p.DBID) AS DBID,
        COALESCE(c.POID, p.POID) AS POID,
        COALESCE(c.PONumber, p.PONumber) AS PONumber,
        COALESCE(c.RowType, p.RowType) AS RowType,
        COALESCE(c.RowKey, p.RowKey) AS RowKey,
        COALESCE(c.ParentRowKey, p.ParentRowKey) AS ParentRowKey,
        COALESCE(c.OrderedLineUID, p.OrderedLineUID) AS OrderedLineUID,
        COALESCE(c.OrderedLineNumber, p.OrderedLineNumber) AS OrderedLineNumber,
        COALESCE(c.LogicalChildUID, p.LogicalChildUID) AS LogicalChildUID,
        COALESCE(c.SourceLineUID, p.SourceLineUID) AS SourceLineUID,
        COALESCE(c.SourceShipmentLineUID, p.SourceShipmentLineUID) AS SourceShipmentLineUID,
        COALESCE(c.GroupLineUID, p.GroupLineUID) AS GroupLineUID,
        COALESCE(c.ParentItem, p.ParentItem) AS ParentItem,
        COALESCE(c.ChildCount, p.ChildCount, 0) AS ChildCount,
        COALESCE(c.SourceState, p.SourceState) AS SourceState,
        c.IsInitial AS CurrentIsInitial,
        CASE WHEN c.RowKey IS NULL THEN 0 ELSE 1 END AS HasCurrent,
        CASE WHEN p.RowKey IS NULL THEN 0 ELSE 1 END AS HasPrevious,
        c.ManufacturerName AS CurrentManufacturerName,
        p.ManufacturerName AS PreviousManufacturerName,
        c.FixtureType AS CurrentFixtureType,
        p.FixtureType AS PreviousFixtureType,
        c.PartNumber AS CurrentPartNumber,
        p.PartNumber AS PreviousPartNumber,
        c.QtyOrdered AS CurrentQtyOrdered,
        p.QtyOrdered AS PreviousQtyOrdered,
        c.QtyReleased AS CurrentQtyReleased,
        p.QtyReleased AS PreviousQtyReleased,
        c.QtyShipped AS CurrentQtyShipped,
        p.QtyShipped AS PreviousQtyShipped,
        c.EstimatedShipDate AS CurrentEstimatedShipDate,
        p.EstimatedShipDate AS PreviousEstimatedShipDate,
        c.ShipDate AS CurrentShipDate,
        p.ShipDate AS PreviousShipDate,
        c.Carrier AS CurrentCarrier,
        p.Carrier AS PreviousCarrier,
        c.TrackingNumber AS CurrentTrackingNumber,
        p.TrackingNumber AS PreviousTrackingNumber,
        COALESCE(c.SourceRowHash, p.SourceRowHash) AS SourceRowHash
    FROM CurrentAfterCompat c
    FULL OUTER JOIN PreviousAfterCompat p
        ON p.RowKey = c.RowKey
)
SELECT
    m.SnapshotRunId,
    m.PurchaseOrderId,
    m.DBID,
    m.POID,
    m.PONumber,
    m.RowType,
    m.RowKey,
    m.ParentRowKey,
    m.OrderedLineUID,
    m.OrderedLineNumber,
    m.LogicalChildUID,
    m.SourceLineUID,
    m.SourceShipmentLineUID,
    m.GroupLineUID,
    m.ParentItem,
    m.ChildCount,
    m.SourceState,
    COALESCE(m.CurrentManufacturerName, prev.PreviousManufacturerName) AS ManufacturerName,
    COALESCE(m.CurrentFixtureType, prev.PreviousFixtureType) AS FixtureType,
    COALESCE(m.CurrentPartNumber, prev.PreviousPartNumber) AS PartNumber,
    COALESCE(m.CurrentQtyOrdered, prev.PreviousQtyOrdered) AS QtyOrdered,
    COALESCE(m.CurrentQtyReleased, prev.PreviousQtyReleased) AS QtyReleased,
    COALESCE(m.CurrentQtyShipped, prev.PreviousQtyShipped) AS QtyShipped,
    COALESCE(m.CurrentEstimatedShipDate, prev.PreviousEstimatedShipDate) AS EstimatedShipDate,
    COALESCE(m.CurrentShipDate, prev.PreviousShipDate) AS ShipDate,
    COALESCE(m.CurrentCarrier, prev.PreviousCarrier) AS Carrier,
    COALESCE(m.CurrentTrackingNumber, prev.PreviousTrackingNumber) AS TrackingNumber,
    CASE
        WHEN m.HasCurrent = 1 AND m.HasPrevious = 0 AND ISNULL(m.CurrentIsInitial, 0) = 1 THEN ''
        WHEN m.HasCurrent = 1 AND m.HasPrevious = 0 THEN '+'
        ELSE '='
    END AS RowChangeFlag,
    CAST(CASE WHEN m.HasCurrent = 0 AND m.HasPrevious = 1 THEN 1 ELSE 0 END AS BIT) AS IsDeleted,
    CAST(CASE WHEN ISNULL(m.CurrentQtyOrdered, -999999.99) <> ISNULL(prev.PreviousQtyOrdered, -999999.99) THEN 1 ELSE 0 END AS BIT) AS IsQtyOrderedChanged,
    CAST(CASE WHEN ISNULL(m.CurrentQtyReleased, -999999.99) <> ISNULL(prev.PreviousQtyReleased, -999999.99) THEN 1 ELSE 0 END AS BIT) AS IsQtyReleasedChanged,
    CAST(CASE WHEN ISNULL(m.CurrentQtyShipped, -999999.99) <> ISNULL(prev.PreviousQtyShipped, -999999.99) THEN 1 ELSE 0 END AS BIT) AS IsQtyShippedChanged,
    CAST(
        CASE
            WHEN LTRIM(RTRIM(ISNULL(prev.PreviousManufacturerName, ''))) = '' THEN 0
            WHEN LTRIM(RTRIM(ISNULL(m.CurrentManufacturerName, ''))) <> LTRIM(RTRIM(ISNULL(prev.PreviousManufacturerName, ''))) THEN 1
            ELSE 0
        END AS BIT
    ) AS IsManufacturerChanged,
    CAST(
        CASE
            WHEN LTRIM(RTRIM(ISNULL(prev.PreviousFixtureType, ''))) = '' THEN 0
            WHEN LTRIM(RTRIM(ISNULL(m.CurrentFixtureType, ''))) <> LTRIM(RTRIM(ISNULL(prev.PreviousFixtureType, ''))) THEN 1
            ELSE 0
        END AS BIT
    ) AS IsFixtureTypeChanged,
    CAST(
        CASE
            WHEN LTRIM(RTRIM(ISNULL(prev.PreviousPartNumber, ''))) = '' THEN 0
            WHEN LTRIM(RTRIM(ISNULL(m.CurrentPartNumber, ''))) <> LTRIM(RTRIM(ISNULL(prev.PreviousPartNumber, ''))) THEN 1
            ELSE 0
        END AS BIT
    ) AS IsPartNumberChanged,
    CAST(CASE WHEN ISNULL(CONVERT(VARCHAR(10), m.CurrentEstimatedShipDate, 23), '') <> ISNULL(CONVERT(VARCHAR(10), prev.PreviousEstimatedShipDate, 23), '') THEN 1 ELSE 0 END AS BIT) AS IsEstimatedShipDateChanged,
    CAST(CASE WHEN ISNULL(CONVERT(VARCHAR(10), m.CurrentShipDate, 23), '') <> ISNULL(CONVERT(VARCHAR(10), prev.PreviousShipDate, 23), '') THEN 1 ELSE 0 END AS BIT) AS IsShipDateChanged,
    CAST(CASE WHEN ISNULL(m.CurrentCarrier, '') <> ISNULL(prev.PreviousCarrier, '') THEN 1 ELSE 0 END AS BIT) AS IsCarrierChanged,
    CAST(CASE WHEN ISNULL(m.CurrentTrackingNumber, '') <> ISNULL(prev.PreviousTrackingNumber, '') THEN 1 ELSE 0 END AS BIT) AS IsTrackingNumberChanged,
    CAST(
        CASE
            WHEN m.HasCurrent = 0 AND m.HasPrevious = 1 THEN 1
            WHEN m.HasCurrent = 1 AND m.HasPrevious = 0 AND ISNULL(m.CurrentIsInitial, 0) = 0 THEN 1
            WHEN ISNULL(m.CurrentQtyOrdered, -999999.99) <> ISNULL(prev.PreviousQtyOrdered, -999999.99) THEN 1
            WHEN ISNULL(m.CurrentQtyReleased, -999999.99) <> ISNULL(prev.PreviousQtyReleased, -999999.99) THEN 1
            WHEN ISNULL(m.CurrentQtyShipped, -999999.99) <> ISNULL(prev.PreviousQtyShipped, -999999.99) THEN 1
            WHEN LTRIM(RTRIM(ISNULL(prev.PreviousManufacturerName, ''))) <> '' AND LTRIM(RTRIM(ISNULL(m.CurrentManufacturerName, ''))) <> LTRIM(RTRIM(ISNULL(prev.PreviousManufacturerName, ''))) THEN 1
            WHEN LTRIM(RTRIM(ISNULL(prev.PreviousFixtureType, ''))) <> '' AND LTRIM(RTRIM(ISNULL(m.CurrentFixtureType, ''))) <> LTRIM(RTRIM(ISNULL(prev.PreviousFixtureType, ''))) THEN 1
            WHEN LTRIM(RTRIM(ISNULL(prev.PreviousPartNumber, ''))) <> '' AND LTRIM(RTRIM(ISNULL(m.CurrentPartNumber, ''))) <> LTRIM(RTRIM(ISNULL(prev.PreviousPartNumber, ''))) THEN 1
            WHEN ISNULL(CONVERT(VARCHAR(10), m.CurrentEstimatedShipDate, 23), '') <> ISNULL(CONVERT(VARCHAR(10), prev.PreviousEstimatedShipDate, 23), '') THEN 1
            WHEN ISNULL(CONVERT(VARCHAR(10), m.CurrentShipDate, 23), '') <> ISNULL(CONVERT(VARCHAR(10), prev.PreviousShipDate, 23), '') THEN 1
            WHEN ISNULL(m.CurrentCarrier, '') <> ISNULL(prev.PreviousCarrier, '') THEN 1
            WHEN ISNULL(m.CurrentTrackingNumber, '') <> ISNULL(prev.PreviousTrackingNumber, '') THEN 1
            ELSE 0
        END AS BIT
    ) AS HasAnyFieldChange,
    m.CurrentManufacturerName,
    prev.PreviousManufacturerName,
    m.CurrentFixtureType,
    prev.PreviousFixtureType,
    m.CurrentPartNumber,
    prev.PreviousPartNumber,
    m.CurrentQtyOrdered,
    prev.PreviousQtyOrdered,
    m.CurrentQtyReleased,
    prev.PreviousQtyReleased,
    m.CurrentQtyShipped,
    prev.PreviousQtyShipped,
    m.CurrentEstimatedShipDate,
    prev.PreviousEstimatedShipDate,
    m.CurrentShipDate,
    prev.PreviousShipDate,
    m.CurrentCarrier,
    prev.PreviousCarrier,
    m.CurrentTrackingNumber,
    prev.PreviousTrackingNumber,
    m.SourceRowHash
FROM MatchedRows m
OUTER APPLY
(
    SELECT TOP (1)
        src.ParentLineUID
    FROM SRC.PurchaseOrderItem src
    WHERE m.HasCurrent = 1
      AND m.HasPrevious = 0
      AND m.RowType = 'C'
      AND m.SourceLineUID IS NOT NULL
      AND src.DBID = m.DBID
      AND src.POID = m.POID
      AND src.LineUID = m.SourceLineUID
      AND ISNULL(src.ParentLineUID, 0) <> 0
      AND src.TransactionType IN ('O', 'S1', 'S')
    ORDER BY
        CASE src.TransactionType
            WHEN 'S' THEN 0
            WHEN 'S1' THEN 1
            ELSE 2
        END
) lineage
OUTER APPLY
(
    SELECT TOP (1)
        COALESCE(m.PreviousManufacturerName, p.ManufacturerName) AS PreviousManufacturerName,
        COALESCE(m.PreviousFixtureType, p.FixtureType) AS PreviousFixtureType,
        COALESCE(m.PreviousPartNumber, p.PartNumber) AS PreviousPartNumber,
        COALESCE(m.PreviousQtyOrdered, p.QtyOrdered) AS PreviousQtyOrdered,
        COALESCE(m.PreviousQtyReleased, p.QtyReleased) AS PreviousQtyReleased,
        COALESCE(m.PreviousQtyShipped, p.QtyShipped) AS PreviousQtyShipped,
        COALESCE(m.PreviousEstimatedShipDate, p.EstimatedShipDate) AS PreviousEstimatedShipDate,
        COALESCE(m.PreviousShipDate, p.ShipDate) AS PreviousShipDate,
        COALESCE(m.PreviousCarrier, p.Carrier) AS PreviousCarrier,
        COALESCE(m.PreviousTrackingNumber, p.TrackingNumber) AS PreviousTrackingNumber
    FROM PreviousRun pr
    LEFT JOIN PreviousRows p
        ON p.RowType = 'P'
       AND p.DBID = m.DBID
       AND p.POID = m.POID
       AND p.OrderedLineUID = lineage.ParentLineUID
    WHERE pr.DBID = m.DBID
      AND pr.POID = m.POID
) prev;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  6. Snapshot builder
---------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE SRC.BuildPurchaseOrderSnapshotV2
(
    @PurchaseOrderId VARCHAR(24),
    @SchedulerData NVARCHAR(MAX),
    @ResetMode CHAR(1) = 'N',
    @SnapshotRunId BIGINT OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedPurchaseOrderId VARCHAR(24) = NULL;
    DECLARE @DBID VARCHAR(32) = NULL;
    DECLARE @POID INT = NULL;
    DECLARE @PONumber VARCHAR(96) = NULL;
    DECLARE @IsInitial BIT = 0;
    DECLARE @InsertedSnapshotRowCount INT = 0;
    DECLARE @RunsToPurge TABLE
    (
        SnapshotRunId BIGINT NOT NULL PRIMARY KEY
    );

    SET @ResolvedPurchaseOrderId = NULLIF(@PurchaseOrderId, '');
    IF @ResolvedPurchaseOrderId IS NULL
    BEGIN
        SET @ResolvedPurchaseOrderId = JSON_VALUE(@SchedulerData, '$.PurchaseOrder');
    END

    IF @ResolvedPurchaseOrderId IS NULL
    BEGIN
        THROW 50002, 'PurchaseOrderId was not supplied to SRC.BuildPurchaseOrderSnapshotV2.', 1;
    END

    SELECT TOP (1)
        @DBID = p.DBID__c,
        @POID = p.POID__c,
        @PONumber = p.[Name]
    FROM AO.PurchaseOrder p
    WHERE p.Id = @ResolvedPurchaseOrderId;

    IF @DBID IS NULL OR @POID IS NULL
    BEGIN
        THROW 50003, 'Could not resolve AO.PurchaseOrder metadata for SRC.BuildPurchaseOrderSnapshotV2.', 1;
    END

    /*
        Treat the PO as initial when there is no persisted snapshot content yet.
        This is intentionally based on snapshot rows, not only run-history rows,
        so orphaned run records do not block a true first-time-style capture.
    */
    IF NOT EXISTS
    (
        SELECT 1
        FROM SRC.PurchaseOrderItemSnapshotV2 s
        WHERE s.DBID = @DBID
          AND s.POID = @POID
    )
    BEGIN
        SET @IsInitial = 1;
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
        @ResolvedPurchaseOrderId,
        @DBID,
        @POID,
        ISNULL(@PONumber, CAST(@POID AS VARCHAR(96))),
        @IsInitial,
        NULL,
        @SchedulerData,
        @ResetMode
    );

    SET @SnapshotRunId = SCOPE_IDENTITY();

    INSERT INTO SRC.PurchaseOrderItemSnapshotV2
    (
        SnapshotRunId,
        DBID,
        POID,
        PONumber,
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
        v.DBID,
        v.POID,
        v.PONumber,
        v.RowType,
        v.RowKey,
        v.ParentRowKey,
        v.OrderedLineUID,
        v.OrderedLineNumber,
        v.LogicalChildUID,
        v.SourceLineUID,
        v.SourceShipmentLineUID,
        v.GroupLineUID,
        v.ParentItem,
        v.ChildCount,
        v.SourceState,
        v.ManufacturerName,
        v.FixtureType,
        v.PartNumber,
        v.QtyOrdered,
        v.QtyReleased,
        v.QtyShipped,
        v.EstimatedShipDate,
        v.ShipDate,
        v.Carrier,
        v.TrackingNumber,
        v.SourceRowHash
    FROM SRC.vw_PurchaseOrderItemCurrentLogicalV2 v
    WHERE v.DBID = @DBID
      AND v.POID = @POID;

    SET @InsertedSnapshotRowCount = @@ROWCOUNT;

    IF @InsertedSnapshotRowCount = 0
    BEGIN
        /*
            Guard against transient no-row captures. If the logical-current view
            returns nothing, discard the run so it cannot become an empty baseline.
        */
        DELETE FROM SRC.PurchaseOrderItemSnapshotRunV2
        WHERE SnapshotRunId = @SnapshotRunId;

        SET @SnapshotRunId = NULL;
        RETURN;
    END

    INSERT INTO @RunsToPurge (SnapshotRunId)
    SELECT rr.SnapshotRunId
    FROM
    (
        SELECT
            r.SnapshotRunId,
            ROW_NUMBER() OVER (ORDER BY r.SnapshotRunId DESC) AS rn
        FROM SRC.PurchaseOrderItemSnapshotRunV2 r
        WHERE r.DBID = @DBID
          AND r.POID = @POID
    ) rr
    WHERE rr.rn > 5;

    DELETE s
    FROM SRC.PurchaseOrderItemSnapshotV2 s
    JOIN @RunsToPurge p
        ON p.SnapshotRunId = s.SnapshotRunId;

    DELETE r
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
    JOIN @RunsToPurge p
        ON p.SnapshotRunId = r.SnapshotRunId;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  7. Snapshot retention helper
---------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE SRC.PurgePurchaseOrderSnapshotRunsV2
(
    @DBID VARCHAR(32),
    @POID INT,
    @KeepLatestRunCount INT = 5
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @KeepLatestRunCount < 1
        THROW 54610, '@KeepLatestRunCount must be at least 1.', 1;

    DECLARE @RunsToPurge TABLE
    (
        SnapshotRunId BIGINT NOT NULL PRIMARY KEY
    );

    INSERT INTO @RunsToPurge (SnapshotRunId)
    SELECT ranked.SnapshotRunId
    FROM
    (
        SELECT
            r.SnapshotRunId,
            rn = ROW_NUMBER() OVER (ORDER BY r.SnapshotRunId DESC)
        FROM SRC.PurchaseOrderItemSnapshotRunV2 r
        WHERE r.DBID = @DBID
          AND r.POID = @POID
    ) ranked
    WHERE ranked.rn > @KeepLatestRunCount;

    DELETE s
    FROM SRC.PurchaseOrderItemSnapshotV2 s
    JOIN @RunsToPurge purge
        ON purge.SnapshotRunId = s.SnapshotRunId;

    DELETE r
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
    JOIN @RunsToPurge purge
        ON purge.SnapshotRunId = r.SnapshotRunId;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  8. Notification wrapper proc
---------------------------------------------------------------------------*/
CREATE OR ALTER PROCEDURE SRC.PurchaseOrderHistoryDE_V2
(
    @DataEntityName VARCHAR(64),
    @SchedulerData NVARCHAR(MAX),
    @ResetMode CHAR(1) = 'N'
)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PurchaseOrderId VARCHAR(24);
    DECLARE @DBID VARCHAR(32);
    DECLARE @POID INT;
    DECLARE @SnapshotRunId BIGINT;
    DECLARE @NotificationType VARCHAR(24);
    DECLARE @ResultBody NVARCHAR(MAX);
    DECLARE @SourceUpdateUserId VARCHAR(32);

    SET @PurchaseOrderId = JSON_VALUE(@SchedulerData, '$.PurchaseOrder');

    EXEC SRC.BuildPurchaseOrderSnapshotV2
        @PurchaseOrderId = @PurchaseOrderId,
        @SchedulerData = @SchedulerData,
        @ResetMode = @ResetMode,
        @SnapshotRunId = @SnapshotRunId OUTPUT;

    IF @SnapshotRunId IS NULL
    BEGIN
        SELECT CAST(NULL AS NVARCHAR(MAX)) AS ResultBody;
        RETURN;
    END

    SELECT
        @DBID = r.DBID,
        @POID = r.POID
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
    WHERE r.SnapshotRunId = @SnapshotRunId;

    EXEC SRC.PurgePurchaseOrderSnapshotRunsV2
        @DBID = @DBID,
        @POID = @POID,
        @KeepLatestRunCount = 5;

    /* Suppress notification output for POs last updated by excluded internal users. */
    SELECT TOP (1)
        @SourceUpdateUserId = UPPER(LTRIM(RTRIM(ISNULL(po.UPDATEUSERID, ''))))
    FROM OASIS_PLS.oasis.CHSC_PO po
    WHERE po.DBID = @DBID
      AND po.POID = @POID;

    IF @SourceUpdateUserId IN ('AHARTMAN', 'GJENSEN', 'LLAFERNIER')
    BEGIN
        UPDATE SRC.PurchaseOrderItemSnapshotRunV2
        SET NotificationType = NULL
        WHERE SnapshotRunId = @SnapshotRunId;

        SELECT CAST(NULL AS NVARCHAR(MAX)) AS ResultBody;
        RETURN;
    END

    SELECT @NotificationType = dbo.GetPOitemHistoryStatus_V2(@DBID, @POID);

IF @ResetMode = 'Y'
BEGIN
    UPDATE SRC.PurchaseOrderItemSnapshotRunV2
    SET NotificationType = @NotificationType
    WHERE SnapshotRunId = @SnapshotRunId;

    SELECT CAST(NULL AS NVARCHAR(MAX)) AS ResultBody;
    RETURN;
END

SELECT @ResultBody = dbo.GetPOitemHistory_V2(@DBID, @POID, @NotificationType);

IF @ResultBody IS NULL
BEGIN
    SET @NotificationType = NULL;
END

UPDATE SRC.PurchaseOrderItemSnapshotRunV2
SET NotificationType = @NotificationType
WHERE SnapshotRunId = @SnapshotRunId;

SELECT @ResultBody AS ResultBody;
END;
GO

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
    DECLARE @RunsToPurge TABLE
    (
        SnapshotRunId BIGINT NOT NULL PRIMARY KEY
    );
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
        CAST(NULLIF(NULLIF(ShipmentLineUID, -1), 0) AS INT) AS SourceShipmentLineUID,
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
        COALESCE(NULLIF(NULLIF(ls.ShipmentLineUID, -1), 0), ls.LineUID) AS LogicalChildUID,
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
        MAX(NULLIF(NULLIF(c.ShipmentLineUID, -1), 0)) AS SourceShipmentLineUID,
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

    INSERT INTO @RunsToPurge (SnapshotRunId)
    SELECT rr.SnapshotRunId
    FROM
    (
        SELECT
            r.SnapshotRunId,
            ROW_NUMBER() OVER (ORDER BY r.SnapshotRunId DESC) AS rn
        FROM SRC.PurchaseOrderItemSnapshotRunV2 r
        WHERE r.DBID = @ResolvedDBID
          AND r.POID = @ResolvedPOID
    ) rr
    WHERE rr.rn > 5;

    DELETE s
    FROM SRC.PurchaseOrderItemSnapshotV2 s
    JOIN @RunsToPurge p
        ON p.SnapshotRunId = s.SnapshotRunId;

    DELETE r
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
    JOIN @RunsToPurge p
        ON p.SnapshotRunId = r.SnapshotRunId;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  8. Notification status helper
     Uses only the latest two snapshot runs for the target PO so status checks
     do not pay the cost of expanding the global diff/current views.
---------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION dbo.GetPOitemHistoryStatus_V2
(
    @DBID VARCHAR(32),
    @POID VARCHAR(32)
)
RETURNS VARCHAR(24)
AS
BEGIN
    DECLARE @Status VARCHAR(24) = NULL;
    DECLARE @SourceUpdateDate DATETIME2(7) = NULL;
    DECLARE @IsInitial BIT = 0;
    DECLARE @CurrentRunId BIGINT = NULL;
    DECLARE @PreviousRunId BIGINT = NULL;
    DECLARE @HasCurrentShipped BIT = 0;
    DECLARE @HasPreviousVisibleScheduled BIT = 0;
    DECLARE @HasVisibleScheduled BIT = 0;
    DECLARE @HasVisibleShipped BIT = 0;

    /*
        Initial qualification rules:
          - Acknowledge: latest run is initial, PO updated within last 5 days, and there are no current shipped child rows
          - Shipped: can still apply on an initial run when shipped rows are present and visibly changed
          - Scheduled: can still apply on an initial run when scheduled rows with a real ESD are present
        For later scheduled notifications, newly appearing scheduled rows should count
        only when the previous snapshot had no scheduled child rows with a real ESD;
        otherwise scheduled visibility should come from an existing matched business
        row so transient added rows do not generate duplicate-style notifications by
        themselves.
    */

    SELECT TOP (1)
        @CurrentRunId = r.SnapshotRunId,
        @IsInitial = ISNULL(r.IsInitial, 0)
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
    WHERE r.DBID = @DBID
      AND r.POID = @POID
    ORDER BY r.SnapshotRunId DESC;

    IF @CurrentRunId IS NULL
    BEGIN
        RETURN NULL;
    END

    SELECT TOP (1)
        @PreviousRunId = r.SnapshotRunId
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
    WHERE r.DBID = @DBID
      AND r.POID = @POID
      AND r.SnapshotRunId < @CurrentRunId
      AND EXISTS
      (
          SELECT 1
          FROM SRC.PurchaseOrderItemSnapshotV2 s
          WHERE s.SnapshotRunId = r.SnapshotRunId
            AND s.RowType = 'P'
      )
    ORDER BY r.SnapshotRunId DESC;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SRC.PurchaseOrderItemSnapshotV2 s
        WHERE s.SnapshotRunId = @CurrentRunId
          AND s.RowType = 'P'
    )
    BEGIN
        RETURN NULL;
    END

    IF EXISTS
    (
        SELECT 1
        FROM SRC.PurchaseOrderItemSnapshotV2 s
        WHERE s.SnapshotRunId = @CurrentRunId
          AND s.RowType = 'C'
          AND s.SourceState = 'Shipped'
    )
    BEGIN
        SET @HasCurrentShipped = 1;
    END

    IF EXISTS
    (
        SELECT 1
        FROM SRC.PurchaseOrderItemSnapshotV2 s
        WHERE s.SnapshotRunId = @PreviousRunId
          AND s.RowType = 'C'
          AND s.SourceState = 'Scheduled'
          AND s.EstimatedShipDate IS NOT NULL
    )
    BEGIN
        SET @HasPreviousVisibleScheduled = 1;
    END

    ;WITH CurrentRows AS
    (
        SELECT
            s.RowKey,
            s.OrderedLineUID,
            s.SourceLineUID,
            s.SourceShipmentLineUID,
            s.SourceState,
            s.PartNumber,
            s.QtyShipped,
            s.EstimatedShipDate,
            s.ShipDate,
            s.Carrier,
            s.TrackingNumber
        FROM SRC.PurchaseOrderItemSnapshotV2 s
        WHERE s.SnapshotRunId = @CurrentRunId
          AND s.RowType = 'C'
          AND s.SourceState IN ('Scheduled', 'Shipped')
    ),
    PreviousRows AS
    (
        SELECT
            s.RowKey,
            s.OrderedLineUID,
            s.SourceLineUID,
            s.SourceShipmentLineUID,
            s.SourceState,
            s.PartNumber,
            s.QtyShipped,
            s.EstimatedShipDate,
            s.ShipDate,
            s.Carrier,
            s.TrackingNumber
        FROM SRC.PurchaseOrderItemSnapshotV2 s
        WHERE s.SnapshotRunId = @PreviousRunId
          AND s.RowType = 'C'
          AND s.SourceState IN ('Scheduled', 'Shipped')
    ),
    MatchedCurrent AS
    (
        SELECT
            c.SourceState,
            c.QtyShipped,
            c.EstimatedShipDate,
            c.ShipDate,
            c.Carrier,
            c.TrackingNumber,
            COALESCE(exact.PreviousRowKey, compat.PreviousRowKey) AS PreviousRowKey,
            COALESCE(exact.PreviousQtyShipped, compat.PreviousQtyShipped) AS PreviousQtyShipped,
            COALESCE(exact.PreviousEstimatedShipDate, compat.PreviousEstimatedShipDate) AS PreviousEstimatedShipDate,
            COALESCE(exact.PreviousShipDate, compat.PreviousShipDate) AS PreviousShipDate,
            COALESCE(exact.PreviousCarrier, compat.PreviousCarrier) AS PreviousCarrier,
            COALESCE(exact.PreviousTrackingNumber, compat.PreviousTrackingNumber) AS PreviousTrackingNumber
        FROM CurrentRows c
        OUTER APPLY
        (
            SELECT TOP (1)
                p.RowKey AS PreviousRowKey,
                p.QtyShipped AS PreviousQtyShipped,
                p.EstimatedShipDate AS PreviousEstimatedShipDate,
                p.ShipDate AS PreviousShipDate,
                p.Carrier AS PreviousCarrier,
                p.TrackingNumber AS PreviousTrackingNumber
            FROM PreviousRows p
            WHERE p.RowKey = c.RowKey
        ) exact
        OUTER APPLY
        (
            SELECT TOP (1)
                p.RowKey AS PreviousRowKey,
                p.QtyShipped AS PreviousQtyShipped,
                p.EstimatedShipDate AS PreviousEstimatedShipDate,
                p.ShipDate AS PreviousShipDate,
                p.Carrier AS PreviousCarrier,
                p.TrackingNumber AS PreviousTrackingNumber
            FROM PreviousRows p
            WHERE exact.PreviousRowKey IS NULL
              AND
              (
                  p.RowKey = c.RowKey
                  OR
                  (
                      ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
                      AND ISNULL(p.SourceLineUID, -1) <> -1
                  )
                  OR
                  (
                      ISNULL(p.SourceShipmentLineUID, -1) = ISNULL(c.SourceShipmentLineUID, -1)
                      AND ISNULL(p.SourceShipmentLineUID, -1) <> -1
                  )
                  OR
                  (
                      p.OrderedLineUID = c.OrderedLineUID
                      AND
                      (
                          (
                              p.SourceState = 'Shipped'
                              AND c.SourceState = 'Shipped'
                              AND ISNULL(p.QtyShipped, -999999.99) = ISNULL(c.QtyShipped, -999999.99)
                              AND ISNULL(CONVERT(VARCHAR(10), p.ShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.ShipDate, 23), '')
                              AND ISNULL(p.Carrier, '') = ISNULL(c.Carrier, '')
                              AND ISNULL(p.TrackingNumber, '') = ISNULL(c.TrackingNumber, '')
                          )
                          OR
                          (
                              ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '')
                              AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '')
                          )
                          OR
                          (
                              p.SourceState <> c.SourceState
                              AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '')
                          )
                      )
                  )
              )
            ORDER BY
                CASE
                    WHEN p.RowKey = c.RowKey THEN 0
                    WHEN ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
                         AND ISNULL(p.SourceShipmentLineUID, -1) = ISNULL(c.SourceShipmentLineUID, -1)
                         AND ISNULL(p.SourceLineUID, -1) <> -1 THEN 1
                    WHEN ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
                         AND ISNULL(p.SourceLineUID, -1) <> -1
                         AND p.SourceState = c.SourceState THEN 2
                    WHEN ISNULL(p.SourceLineUID, -1) = ISNULL(c.SourceLineUID, -1)
                         AND ISNULL(p.SourceLineUID, -1) <> -1 THEN 3
                    WHEN ISNULL(p.SourceShipmentLineUID, -1) = ISNULL(c.SourceShipmentLineUID, -1)
                         AND ISNULL(p.SourceShipmentLineUID, -1) <> -1 THEN 4
                    WHEN p.SourceState = 'Shipped'
                         AND c.SourceState = 'Shipped'
                         AND ISNULL(p.QtyShipped, -999999.99) = ISNULL(c.QtyShipped, -999999.99)
                         AND ISNULL(CONVERT(VARCHAR(10), p.ShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.ShipDate, 23), '')
                         AND ISNULL(p.Carrier, '') = ISNULL(c.Carrier, '')
                         AND ISNULL(p.TrackingNumber, '') = ISNULL(c.TrackingNumber, '') THEN 5
                    WHEN p.SourceState = c.SourceState
                         AND ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '')
                         AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '') THEN 6
                    WHEN p.SourceState <> c.SourceState
                         AND ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '') THEN 7
                    WHEN p.SourceState = c.SourceState
                         AND ISNULL(CONVERT(VARCHAR(10), p.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '') THEN 8
                    WHEN ISNULL(p.PartNumber, '') = ISNULL(c.PartNumber, '') THEN 9
                    ELSE 10
                END,
                p.RowKey
        ) compat
    )
    SELECT
        @HasVisibleScheduled = CONVERT(BIT, ISNULL(MAX(CASE
            WHEN SourceState = 'Scheduled'
                 AND EstimatedShipDate IS NOT NULL
                 AND
                 (
                     @IsInitial = 1
                     OR @HasPreviousVisibleScheduled = 0
                     OR PreviousRowKey IS NOT NULL
                 )
                 AND ISNULL(CONVERT(VARCHAR(10), EstimatedShipDate, 23), '') <> ISNULL(CONVERT(VARCHAR(10), PreviousEstimatedShipDate, 23), '')
                THEN 1 ELSE 0 END), 0)),
        @HasVisibleShipped = CONVERT(BIT, ISNULL(MAX(CASE
            WHEN SourceState = 'Shipped'
                 AND
                 (
                     (ISNULL(QtyShipped, 0) <> 0 AND ISNULL(QtyShipped, -999999.99) <> ISNULL(PreviousQtyShipped, -999999.99))
                     OR (ShipDate IS NOT NULL AND ISNULL(CONVERT(VARCHAR(10), ShipDate, 23), '') <> ISNULL(CONVERT(VARCHAR(10), PreviousShipDate, 23), ''))
                     OR (ISNULL(Carrier, '') <> '' AND ISNULL(Carrier, '') <> ISNULL(PreviousCarrier, ''))
                     OR (ISNULL(TrackingNumber, '') <> '' AND ISNULL(TrackingNumber, '') <> ISNULL(PreviousTrackingNumber, ''))
                 )
                THEN 1 ELSE 0 END), 0))
    FROM MatchedCurrent;

    /*
        If the PO currently has at least one shipped child row, the subject should
        be Shipped whenever there is any visible scheduled/shipped notification
        content to issue for the PO.
    */
    IF @HasCurrentShipped = 1
       AND (@HasVisibleShipped = 1 OR @HasVisibleScheduled = 1)
    BEGIN
        RETURN 'Shipped';
    END

    /* Scheduled applies when the row has a real ESD and that ESD is new or changed. */
    IF @HasVisibleScheduled = 1
    BEGIN
        RETURN 'Scheduled';
    END

    IF @IsInitial = 1
    BEGIN
        SELECT TOP (1)
            @SourceUpdateDate = po.UPDATEDATE
        FROM OASIS_PLS.oasis.CHSC_PO po
        WHERE po.DBID = @DBID
          AND po.POID = @POID;

        IF @SourceUpdateDate IS NOT NULL
           AND @SourceUpdateDate >= DATEADD(DAY, -5, GETDATE())
           AND @HasCurrentShipped = 0
        BEGIN
            RETURN 'Acknowledge';
        END
    END

    RETURN @Status;
END;
GO




SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  9. Detail HTML renderer
---------------------------------------------------------------------------*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER FUNCTION dbo.GetPOItemHistoryDetailHtml_V2
(
    @DBID VARCHAR(32),
    @POID VARCHAR(32),
    @Status VARCHAR(24) = NULL
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Html NVARCHAR(MAX) = NULL;
    DECLARE @POnumber VARCHAR(96) = '';
    DECLARE @ProjectName VARCHAR(128) = '';
    DECLARE @CSRName NVARCHAR(128) = N'';
    DECLARE @CSREmail NVARCHAR(255) = N'';
    DECLARE @CSRPhone NVARCHAR(120) = N'206.436.8818';
    DECLARE @CSRAddress NVARCHAR(255) = N'6004 S. 190th St.| Suite 203, Kent, WA 98032';
    DECLARE @CreateTerritoryId VARCHAR(32) = '';
    DECLARE @SignatureHtml NVARCHAR(MAX) = N'';
    DECLARE @LogoHtml NVARCHAR(MAX) = dbo.GetLogoImage();

    SET @Status = ISNULL(@Status, dbo.GetPOitemHistoryStatus_V2(@DBID, @POID));

    IF NOT EXISTS
    (
        SELECT 1
        FROM SRC.vw_PurchaseOrderItemSnapshotCurrentV2 d
        WHERE d.DBID = @DBID
          AND d.POID = @POID
          AND d.RowType = 'P'
    )
    BEGIN
        RETURN NULL;
    END

    SELECT TOP (1)
        @POnumber = s.PONumber,
        @ProjectName = ISNULL(pr.[Name], ''),
        @CSRName = LTRIM(RTRIM(ISNULL(csr.[Name], ownerUser.[Name]))),
        @CSREmail = LTRIM(RTRIM(ISNULL(csr.Email, ownerUser.Email))),
        @CSRPhone = COALESCE(
            NULLIF(LTRIM(RTRIM(ISNULL(csr.Phone, ''))), ''),
            NULLIF(LTRIM(RTRIM(ISNULL(ownerUser.Phone, ''))), ''),
            @CSRPhone
        ),
        @CreateTerritoryId = UPPER(LTRIM(RTRIM(ISNULL(rawPo.CREATETERRITORYID, ''))))
    FROM SRC.vw_PurchaseOrderItemSnapshotCurrentV2 s
    LEFT JOIN AO.PurchaseOrder po
        ON po.Id = s.PurchaseOrderId
    LEFT JOIN OASIS_PLS.oasis.CHSC_PO rawPo
        ON rawPo.DBID = s.DBID
       AND rawPo.POID = s.POID
    LEFT JOIN AO.Project pr
        ON pr.Id = po.Project__c
    LEFT JOIN AO.[User] csr
        ON csr.Id = po.CSR__c
    LEFT JOIN AO.[User] ownerUser
        ON ownerUser.Id = po.OwnerId
    WHERE s.DBID = @DBID
      AND s.POID = @POID;

    IF @CreateTerritoryId = 'PLSEWA'
    BEGIN
        SET @CSRAddress = N'12830 E. Mirabeau Parkway, Spokane Valley, WA 99216';
    END

    SET @ProjectName = REPLACE(@ProjectName, ' - Initial Phase', '');

    SET @SignatureHtml =
        N'<div style="margin-bottom:12px; font-family:''Tw Cen MT'', Arial, sans-serif; font-size:14pt; line-height:1.15; color:#111;">' +
        CASE
            WHEN LTRIM(RTRIM(ISNULL(@CSRName, N''))) <> N'' THEN N'<div id="senderName" style="margin:0 0 8px 0; font-family:''Tw Cen MT'', Arial, sans-serif; font-size:14pt; line-height:1.1; font-weight:700; letter-spacing:0.2px; color:#111; text-transform:uppercase;">' + @CSRName + N'</div>'
            ELSE N''
        END +
        CASE
            WHEN LTRIM(RTRIM(ISNULL(@CSRPhone, N''))) <> N'' THEN N'<div style="margin:0 0 8px 0; font-family:''Tw Cen MT'', Arial, sans-serif; font-size:14pt; line-height:1.15; color:#111;"><span style="color:#F28C28; font-weight:700;">o:</span> ' + @CSRPhone + N'</div>'
            ELSE N''
        END +
        CASE
            WHEN LTRIM(RTRIM(ISNULL(@CSRAddress, N''))) <> N'' THEN N'<div style="margin:0 0 10px 0; font-family:''Tw Cen MT'', Arial, sans-serif; font-size:14pt; line-height:1.15; color:#555;">' + @CSRAddress + N'</div>'
            ELSE N''
        END +
        N'</div>';

    DECLARE @DetailRows TABLE
    (
        RowType CHAR(1) NOT NULL,
        RowKey VARCHAR(200) NOT NULL,
        ParentRowKey VARCHAR(200) NULL,
        OrderedLineUID INT NOT NULL,
        OrderedLineNumber INT NOT NULL,
        LogicalChildUID INT NULL,
        SourceState VARCHAR(32) NULL,
        ManufacturerName NVARCHAR(255) NULL,
        FixtureType VARCHAR(130) NULL,
        PartNumber VARCHAR(260) NULL,
        QtyOrdered NUMERIC(12,2) NULL,
        QtyReleased NUMERIC(12,2) NULL,
        QtyShipped NUMERIC(12,2) NULL,
        EstimatedShipDate DATE NULL,
        ShipDate DATE NULL,
        Carrier VARCHAR(130) NULL,
        TrackingNumber VARCHAR(80) NULL,
        RowChangeFlag VARCHAR(8) NULL,
        IsQtyOrderedChanged BIT NOT NULL,
        IsQtyReleasedChanged BIT NOT NULL,
        IsQtyShippedChanged BIT NOT NULL,
        IsManufacturerChanged BIT NOT NULL,
        IsFixtureTypeChanged BIT NOT NULL,
        IsPartNumberChanged BIT NOT NULL,
        IsEstimatedShipDateChanged BIT NOT NULL,
        IsShipDateChanged BIT NOT NULL,
        IsCarrierChanged BIT NOT NULL,
        IsTrackingNumberChanged BIT NOT NULL,
        PRIMARY KEY CLUSTERED (RowKey)
    );

    INSERT INTO @DetailRows
    (
        RowType,
        RowKey,
        ParentRowKey,
        OrderedLineUID,
        OrderedLineNumber,
        LogicalChildUID,
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
        RowChangeFlag,
        IsQtyOrderedChanged,
        IsQtyReleasedChanged,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged,
        IsEstimatedShipDateChanged,
        IsShipDateChanged,
        IsCarrierChanged,
        IsTrackingNumberChanged
    )
    SELECT
        d.RowType,
        d.RowKey,
        d.ParentRowKey,
        d.OrderedLineUID,
        d.OrderedLineNumber,
        d.LogicalChildUID,
        d.SourceState,
        d.ManufacturerName,
        d.FixtureType,
        d.PartNumber,
        d.QtyOrdered,
        d.QtyReleased,
        d.QtyShipped,
        d.EstimatedShipDate,
        d.ShipDate,
        d.Carrier,
        d.TrackingNumber,
        d.RowChangeFlag,
        d.IsQtyOrderedChanged,
        d.IsQtyReleasedChanged,
        d.IsQtyShippedChanged,
        d.IsManufacturerChanged,
        d.IsFixtureTypeChanged,
        d.IsPartNumberChanged,
        d.IsEstimatedShipDateChanged,
        d.IsShipDateChanged,
        d.IsCarrierChanged,
        d.IsTrackingNumberChanged
    FROM SRC.vw_PurchaseOrderItemSnapshotDiffV2 d
    WHERE d.DBID = @DBID
      AND d.POID = @POID
      AND d.IsDeleted = 0;

    DECLARE @OrderedBase TABLE
    (
        RowKey VARCHAR(200) NOT NULL PRIMARY KEY,
        OrderedLineUID INT NOT NULL,
        OrderedLineNumber INT NOT NULL,
        SourceState VARCHAR(32) NULL,
        RowChangeFlag VARCHAR(8) NULL,
        QtyOrdered NUMERIC(12,2) NULL,
        QtyReleased NUMERIC(12,2) NULL,
        QtyShipped NUMERIC(12,2) NULL,
        ManufacturerName NVARCHAR(255) NULL,
        FixtureType VARCHAR(130) NULL,
        PartNumber VARCHAR(260) NULL,
        IsQtyOrderedChanged BIT NOT NULL,
        IsQtyReleasedChanged BIT NOT NULL,
        IsQtyShippedChanged BIT NOT NULL,
        IsManufacturerChanged BIT NOT NULL,
        IsFixtureTypeChanged BIT NOT NULL,
        IsPartNumberChanged BIT NOT NULL
    );

    INSERT INTO @OrderedBase
    (
        RowKey,
        OrderedLineUID,
        OrderedLineNumber,
        SourceState,
        RowChangeFlag,
        QtyOrdered,
        QtyReleased,
        QtyShipped,
        ManufacturerName,
        FixtureType,
        PartNumber,
        IsQtyOrderedChanged,
        IsQtyReleasedChanged,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged
    )
    SELECT
        d.RowKey,
        d.OrderedLineUID,
        d.OrderedLineNumber,
        d.SourceState,
        d.RowChangeFlag,
        d.QtyOrdered,
        d.QtyReleased,
        d.QtyShipped,
        d.ManufacturerName,
        d.FixtureType,
        d.PartNumber,
        d.IsQtyOrderedChanged,
        d.IsQtyReleasedChanged,
        d.IsQtyShippedChanged,
        d.IsManufacturerChanged,
        d.IsFixtureTypeChanged,
        d.IsPartNumberChanged
    FROM @DetailRows d
    WHERE d.RowType = 'P';

    DECLARE @ChildBase TABLE
    (
        RowKey VARCHAR(200) NOT NULL PRIMARY KEY,
        ParentRowKey VARCHAR(200) NULL,
        OrderedLineNumber INT NOT NULL,
        LogicalChildUID INT NULL,
        SourceState VARCHAR(32) NULL,
        RowChangeFlag VARCHAR(8) NULL,
        QtyShipped NUMERIC(12,2) NULL,
        ManufacturerName NVARCHAR(255) NULL,
        FixtureType VARCHAR(130) NULL,
        PartNumber VARCHAR(260) NULL,
        EstimatedShipDate DATE NULL,
        ShipDate DATE NULL,
        Carrier VARCHAR(130) NULL,
        TrackingNumber VARCHAR(80) NULL,
        IsQtyShippedChanged BIT NOT NULL,
        IsManufacturerChanged BIT NOT NULL,
        IsFixtureTypeChanged BIT NOT NULL,
        IsPartNumberChanged BIT NOT NULL,
        IsEstimatedShipDateChanged BIT NOT NULL,
        IsShipDateChanged BIT NOT NULL,
        IsCarrierChanged BIT NOT NULL,
        IsTrackingNumberChanged BIT NOT NULL
    );

    INSERT INTO @ChildBase
    (
        RowKey,
        ParentRowKey,
        OrderedLineNumber,
        LogicalChildUID,
        SourceState,
        RowChangeFlag,
        QtyShipped,
        ManufacturerName,
        FixtureType,
        PartNumber,
        EstimatedShipDate,
        ShipDate,
        Carrier,
        TrackingNumber,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged,
        IsEstimatedShipDateChanged,
        IsShipDateChanged,
        IsCarrierChanged,
        IsTrackingNumberChanged
    )
    SELECT
        d.RowKey,
        d.ParentRowKey,
        d.OrderedLineNumber,
        d.LogicalChildUID,
        d.SourceState,
        d.RowChangeFlag,
        d.QtyShipped,
        d.ManufacturerName,
        d.FixtureType,
        d.PartNumber,
        d.EstimatedShipDate,
        d.ShipDate,
        d.Carrier,
        d.TrackingNumber,
        d.IsQtyShippedChanged,
        d.IsManufacturerChanged,
        d.IsFixtureTypeChanged,
        d.IsPartNumberChanged,
        d.IsEstimatedShipDateChanged,
        d.IsShipDateChanged,
        d.IsCarrierChanged,
        d.IsTrackingNumberChanged
    FROM @DetailRows d
    WHERE d.RowType = 'C';

    DECLARE @ChildRenderBase TABLE
    (
        RowKey VARCHAR(200) NOT NULL PRIMARY KEY,
        ParentRowKey VARCHAR(200) NULL,
        OrderedLineNumber INT NOT NULL,
        LogicalChildUID INT NULL,
        SourceState VARCHAR(32) NULL,
        RowChangeFlag VARCHAR(8) NULL,
        QtyShipped NUMERIC(12,2) NULL,
        ManufacturerName NVARCHAR(255) NULL,
        FixtureType VARCHAR(130) NULL,
        PartNumber VARCHAR(260) NULL,
        EstimatedShipDate DATE NULL,
        ShipDate DATE NULL,
        Carrier VARCHAR(130) NULL,
        TrackingNumber VARCHAR(80) NULL,
        IsQtyShippedChanged BIT NOT NULL,
        IsManufacturerChanged BIT NOT NULL,
        IsFixtureTypeChanged BIT NOT NULL,
        IsPartNumberChanged BIT NOT NULL,
        IsEstimatedShipDateChanged BIT NOT NULL,
        IsShipDateChanged BIT NOT NULL,
        IsCarrierChanged BIT NOT NULL,
        IsTrackingNumberChanged BIT NOT NULL
    );

    INSERT INTO @ChildRenderBase
    (
        RowKey,
        ParentRowKey,
        OrderedLineNumber,
        LogicalChildUID,
        SourceState,
        RowChangeFlag,
        QtyShipped,
        ManufacturerName,
        FixtureType,
        PartNumber,
        EstimatedShipDate,
        ShipDate,
        Carrier,
        TrackingNumber,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged,
        IsEstimatedShipDateChanged,
        IsShipDateChanged,
        IsCarrierChanged,
        IsTrackingNumberChanged
    )
    SELECT
        c.RowKey,
        c.ParentRowKey,
        c.OrderedLineNumber,
        c.LogicalChildUID,
        c.SourceState,
        c.RowChangeFlag,
        c.QtyShipped,
        c.ManufacturerName,
        c.FixtureType,
        c.PartNumber,
        c.EstimatedShipDate,
        c.ShipDate,
        c.Carrier,
        c.TrackingNumber,
        c.IsQtyShippedChanged,
        c.IsManufacturerChanged,
        c.IsFixtureTypeChanged,
        c.IsPartNumberChanged,
        c.IsEstimatedShipDateChanged,
        c.IsShipDateChanged,
        c.IsCarrierChanged,
        c.IsTrackingNumberChanged
    FROM @ChildBase c
    WHERE NOT
    (
        c.SourceState = 'Scheduled'
        AND EXISTS
        (
            SELECT 1
            FROM @ChildBase s
            WHERE s.ParentRowKey = c.ParentRowKey
              AND s.SourceState = 'Shipped'
        )
    )
      /* scheduled child de-dupe v2: same parent/type, tolerate child part-number variants */
      AND NOT
    (
        c.SourceState = 'Scheduled'
        AND EXISTS
        (
            SELECT 1
            FROM @ChildBase better
            WHERE better.ParentRowKey = c.ParentRowKey
              AND better.RowKey <> c.RowKey
              AND better.SourceState = 'Scheduled'
              AND ISNULL(better.ManufacturerName, '') = ISNULL(c.ManufacturerName, '')
              AND ISNULL(better.FixtureType, '') = ISNULL(c.FixtureType, '')
              AND
              (
                  (better.EstimatedShipDate IS NOT NULL AND c.EstimatedShipDate IS NULL)
                  OR
                  (
                      ISNULL(CONVERT(VARCHAR(10), better.EstimatedShipDate, 23), '') = ISNULL(CONVERT(VARCHAR(10), c.EstimatedShipDate, 23), '')
                      AND better.RowKey < c.RowKey
                  )
              )
        )
    );

    DECLARE @OrderedWithCounts TABLE
    (
        RowKey VARCHAR(200) NOT NULL PRIMARY KEY,
        OrderedLineUID INT NOT NULL,
        OrderedLineNumber INT NOT NULL,
        SourceState VARCHAR(32) NULL,
        RowChangeFlag VARCHAR(8) NULL,
        QtyOrdered NUMERIC(12,2) NULL,
        QtyReleased NUMERIC(12,2) NULL,
        QtyShipped NUMERIC(12,2) NULL,
        ManufacturerName NVARCHAR(255) NULL,
        FixtureType VARCHAR(130) NULL,
        PartNumber VARCHAR(260) NULL,
        IsQtyOrderedChanged BIT NOT NULL,
        IsQtyReleasedChanged BIT NOT NULL,
        IsQtyShippedChanged BIT NOT NULL,
        IsManufacturerChanged BIT NOT NULL,
        IsFixtureTypeChanged BIT NOT NULL,
        IsPartNumberChanged BIT NOT NULL,
        EffectiveChildCount INT NOT NULL,
        TotalChildQtyShipped NUMERIC(12,2) NOT NULL
    );

    INSERT INTO @OrderedWithCounts
    (
        RowKey,
        OrderedLineUID,
        OrderedLineNumber,
        SourceState,
        RowChangeFlag,
        QtyOrdered,
        QtyReleased,
        QtyShipped,
        ManufacturerName,
        FixtureType,
        PartNumber,
        IsQtyOrderedChanged,
        IsQtyReleasedChanged,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged,
        EffectiveChildCount,
        TotalChildQtyShipped
    )
    SELECT
        o.RowKey,
        o.OrderedLineUID,
        o.OrderedLineNumber,
        o.SourceState,
        o.RowChangeFlag,
        o.QtyOrdered,
        o.QtyReleased,
        o.QtyShipped,
        o.ManufacturerName,
        o.FixtureType,
        o.PartNumber,
        o.IsQtyOrderedChanged,
        o.IsQtyReleasedChanged,
        o.IsQtyShippedChanged,
        o.IsManufacturerChanged,
        o.IsFixtureTypeChanged,
        o.IsPartNumberChanged,
        ISNULL(cc.EffectiveChildCount, 0),
        ISNULL(cc.TotalChildQtyShipped, 0)
    FROM @OrderedBase o
    OUTER APPLY
    (
        SELECT
            COUNT(*) AS EffectiveChildCount,
            SUM(ISNULL(c.QtyShipped, 0)) AS TotalChildQtyShipped
        FROM @ChildRenderBase c
        WHERE c.ParentRowKey = o.RowKey
    ) cc;

    DECLARE @OrderedLineHierarchy TABLE
    (
        ChildOrderedLineUID INT NOT NULL PRIMARY KEY,
        ParentOrderedLineUID INT NOT NULL
    );

    INSERT INTO @OrderedLineHierarchy
    (
        ChildOrderedLineUID,
        ParentOrderedLineUID
    )
    SELECT DISTINCT
        CAST(src.LineUID AS INT),
        CAST(src.ParentLineUID AS INT)
    FROM SRC.PurchaseOrderItem src
    WHERE src.DBID = @DBID
      AND src.POID = @POID
      AND src.TransactionType = 'O'
      AND ISNULL(src.ParentLineUID, 0) <> 0
      AND (src.PartNumber NOT LIKE '%LOT%' OR src.PartNumber LIKE '%PILOT%')
      AND src.PartNumber NOT LIKE '%SELL%'
      AND src.PartNumber NOT LIKE '%PRICE%'
      AND src.FixtureType NOT LIKE '%LOT%';

    DECLARE @SingleOrderedChildCollapse TABLE
    (
        ParentOrderedRowKey VARCHAR(200) NOT NULL PRIMARY KEY,
        ChildOrderedRowKey VARCHAR(200) NOT NULL
    );

    INSERT INTO @SingleOrderedChildCollapse
    (
        ParentOrderedRowKey,
        ChildOrderedRowKey
    )
    SELECT
        p.RowKey,
        c.RowKey
    FROM @OrderedWithCounts p
    JOIN
    (
        SELECT
            h.ParentOrderedLineUID,
            MIN(h.ChildOrderedLineUID) AS ChildOrderedLineUID
        FROM @OrderedLineHierarchy h
        GROUP BY h.ParentOrderedLineUID
        HAVING COUNT(*) = 1
    ) h
        ON h.ParentOrderedLineUID = p.OrderedLineUID
    JOIN @OrderedWithCounts c
        ON c.OrderedLineUID = h.ChildOrderedLineUID
       AND c.EffectiveChildCount = 1;

    DECLARE @MultiOrderedChildGroup TABLE
    (
        ChildOrderedRowKey VARCHAR(200) NOT NULL PRIMARY KEY,
        ParentOrderedRowKey VARCHAR(200) NOT NULL,
        GroupChildCount INT NOT NULL
    );

    INSERT INTO @MultiOrderedChildGroup
    (
        ChildOrderedRowKey,
        ParentOrderedRowKey,
        GroupChildCount
    )
    SELECT
        c.RowKey,
        p.RowKey,
        h.ChildCount
    FROM
    (
        SELECT
            ParentOrderedLineUID,
            COUNT(*) AS ChildCount
        FROM @OrderedLineHierarchy
        GROUP BY ParentOrderedLineUID
        HAVING COUNT(*) > 1
    ) h
    JOIN @OrderedWithCounts p
        ON p.OrderedLineUID = h.ParentOrderedLineUID
    JOIN @OrderedLineHierarchy oh
        ON oh.ParentOrderedLineUID = h.ParentOrderedLineUID
    JOIN @OrderedWithCounts c
        ON c.OrderedLineUID = oh.ChildOrderedLineUID;

    DECLARE @MultiOrderedParentGroup TABLE
    (
        ParentOrderedRowKey VARCHAR(200) NOT NULL PRIMARY KEY,
        GroupChildCount INT NOT NULL
    );

    INSERT INTO @MultiOrderedParentGroup
    (
        ParentOrderedRowKey,
        GroupChildCount
    )
    SELECT DISTINCT
        ParentOrderedRowKey,
        GroupChildCount
    FROM @MultiOrderedChildGroup;

    DECLARE @RenderRows TABLE
    (
        OrderedLineNumber INT NOT NULL,
        SortBucket INT NOT NULL,
        IsParentRow BIT NOT NULL,
        UseChildValues BIT NOT NULL,
        SourceState VARCHAR(32) NULL,
        EffectiveChildCount INT NOT NULL,
        RowChangeFlag VARCHAR(8) NULL,
        QtyOrdered NUMERIC(12,2) NULL,
        QtyReleased NUMERIC(12,2) NULL,
        QtyShipped NUMERIC(12,2) NULL,
        ManufacturerName NVARCHAR(255) NULL,
        FixtureType VARCHAR(130) NULL,
        PartNumber VARCHAR(260) NULL,
        EstimatedShipDate DATE NULL,
        ChildShipped NUMERIC(12,2) NULL,
        ShipDate DATE NULL,
        Carrier VARCHAR(130) NULL,
        TrackingNumber VARCHAR(80) NULL,
        IsQtyOrderedChanged BIT NOT NULL,
        IsQtyReleasedChanged BIT NOT NULL,
        IsQtyShippedChanged BIT NOT NULL,
        IsManufacturerChanged BIT NOT NULL,
        IsFixtureTypeChanged BIT NOT NULL,
        IsPartNumberChanged BIT NOT NULL,
        IsEstimatedShipDateChanged BIT NOT NULL,
        IsShipDateChanged BIT NOT NULL,
        IsCarrierChanged BIT NOT NULL,
        IsTrackingNumberChanged BIT NOT NULL,
        HasVisibleHighlight BIT NOT NULL,
        OrderedRowKey VARCHAR(200) NOT NULL,
        ChildRowKey VARCHAR(200) NULL
    );

    INSERT INTO @RenderRows
    (
        OrderedLineNumber,
        SortBucket,
        IsParentRow,
        UseChildValues,
        SourceState,
        EffectiveChildCount,
        RowChangeFlag,
        QtyOrdered,
        QtyReleased,
        QtyShipped,
        ManufacturerName,
        FixtureType,
        PartNumber,
        EstimatedShipDate,
        ChildShipped,
        ShipDate,
        Carrier,
        TrackingNumber,
        IsQtyOrderedChanged,
        IsQtyReleasedChanged,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged,
        IsEstimatedShipDateChanged,
        IsShipDateChanged,
        IsCarrierChanged,
        IsTrackingNumberChanged,
        HasVisibleHighlight,
        OrderedRowKey,
        ChildRowKey
    )
    SELECT
        o.OrderedLineNumber,
        1,
        CAST(CASE WHEN mpg.ParentOrderedRowKey IS NOT NULL THEN 1 ELSE 0 END AS BIT),
        CAST(0 AS BIT),
        COALESCE(mc.SourceState, c.SourceState, o.SourceState),
        ISNULL(COALESCE(mpg.GroupChildCount, mcg.GroupChildCount), o.EffectiveChildCount),
        CASE
            WHEN mc.RowKey IS NOT NULL THEN mc.RowChangeFlag
            WHEN c.RowKey IS NOT NULL THEN c.RowChangeFlag
            ELSE o.RowChangeFlag
        END,
        o.QtyOrdered,
        o.QtyReleased,
        CASE
            WHEN ISNULL(o.QtyShipped, 0) = 0 THEN ISNULL(COALESCE(mc.QtyShipped, c.QtyShipped), 0)
            ELSE o.QtyShipped
        END,
        CASE WHEN mc.RowKey IS NOT NULL THEN o.ManufacturerName ELSE COALESCE(c.ManufacturerName, o.ManufacturerName) END,
        CASE WHEN mc.RowKey IS NOT NULL THEN o.FixtureType ELSE COALESCE(c.FixtureType, o.FixtureType) END,
        CASE WHEN mc.RowKey IS NOT NULL THEN o.PartNumber ELSE COALESCE(c.PartNumber, o.PartNumber) END,
        COALESCE(
            mc.EstimatedShipDate,
            CASE WHEN mc.SourceState = 'Shipped' THEN mc.ShipDate END,
            c.EstimatedShipDate,
            CASE WHEN c.SourceState = 'Shipped' THEN c.ShipDate END
        ),
        COALESCE(mc.QtyShipped, c.QtyShipped),
        COALESCE(mc.ShipDate, c.ShipDate),
        COALESCE(mc.Carrier, c.Carrier),
        COALESCE(mc.TrackingNumber, c.TrackingNumber),
        o.IsQtyOrderedChanged,
        o.IsQtyReleasedChanged,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN mc.IsQtyShippedChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsQtyShippedChanged
            ELSE o.IsQtyShippedChanged
        END,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN o.IsManufacturerChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsManufacturerChanged
            ELSE o.IsManufacturerChanged
        END,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN o.IsFixtureTypeChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsFixtureTypeChanged
            ELSE o.IsFixtureTypeChanged
        END,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN o.IsPartNumberChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsPartNumberChanged
            ELSE o.IsPartNumberChanged
        END,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN mc.IsEstimatedShipDateChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsEstimatedShipDateChanged
            ELSE CAST(0 AS BIT)
        END,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN mc.IsShipDateChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsShipDateChanged
            ELSE CAST(0 AS BIT)
        END,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN mc.IsCarrierChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsCarrierChanged
            ELSE CAST(0 AS BIT)
        END,
        CASE
            WHEN mc.RowKey IS NOT NULL THEN mc.IsTrackingNumberChanged
            WHEN c.RowKey IS NOT NULL THEN c.IsTrackingNumberChanged
            ELSE CAST(0 AS BIT)
        END,
        CAST(0 AS BIT),
        o.RowKey,
        COALESCE(mc.RowKey, c.RowKey)
    FROM @OrderedWithCounts o
    LEFT JOIN @MultiOrderedParentGroup mpg
        ON mpg.ParentOrderedRowKey = o.RowKey
    LEFT JOIN @MultiOrderedChildGroup mcg
        ON mcg.ChildOrderedRowKey = o.RowKey
    OUTER APPLY
    (
        SELECT TOP (1) c.*
        FROM @ChildRenderBase c
        WHERE c.ParentRowKey = o.RowKey
        ORDER BY c.LogicalChildUID
    ) c
    OUTER APPLY
    (
        SELECT TOP (1) c.*
        FROM @SingleOrderedChildCollapse soc
        JOIN @ChildRenderBase c
            ON c.ParentRowKey = soc.ChildOrderedRowKey
        WHERE soc.ParentOrderedRowKey = o.RowKey
        ORDER BY c.LogicalChildUID
    ) mc
    WHERE ISNULL(o.EffectiveChildCount, 0) <= 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM @SingleOrderedChildCollapse soc
          WHERE soc.ChildOrderedRowKey = o.RowKey
      );

    INSERT INTO @RenderRows
    (
        OrderedLineNumber,
        SortBucket,
        IsParentRow,
        UseChildValues,
        SourceState,
        EffectiveChildCount,
        RowChangeFlag,
        QtyOrdered,
        QtyReleased,
        QtyShipped,
        ManufacturerName,
        FixtureType,
        PartNumber,
        EstimatedShipDate,
        ChildShipped,
        ShipDate,
        Carrier,
        TrackingNumber,
        IsQtyOrderedChanged,
        IsQtyReleasedChanged,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged,
        IsEstimatedShipDateChanged,
        IsShipDateChanged,
        IsCarrierChanged,
        IsTrackingNumberChanged,
        HasVisibleHighlight,
        OrderedRowKey,
        ChildRowKey
    )
    SELECT
        o.OrderedLineNumber,
        1,
        CAST(1 AS BIT),
        CAST(0 AS BIT),
        o.SourceState,
        o.EffectiveChildCount,
        o.RowChangeFlag,
        o.QtyOrdered,
        o.QtyReleased,
        CASE
            WHEN o.TotalChildQtyShipped > ISNULL(o.QtyOrdered, 0)
                THEN ISNULL(o.QtyOrdered, 0)
            ELSE o.TotalChildQtyShipped
        END,
        o.ManufacturerName,
        o.FixtureType,
        o.PartNumber,
        CAST(NULL AS DATE),
        CAST(NULL AS NUMERIC(12,2)),
        CAST(NULL AS DATE),
        CAST(NULL AS VARCHAR(130)),
        CAST(NULL AS VARCHAR(80)),
        o.IsQtyOrderedChanged,
        o.IsQtyReleasedChanged,
        o.IsQtyShippedChanged,
        o.IsManufacturerChanged,
        o.IsFixtureTypeChanged,
        o.IsPartNumberChanged,
        CAST(0 AS BIT),
        CAST(0 AS BIT),
        CAST(0 AS BIT),
        CAST(0 AS BIT),
        CAST(0 AS BIT),
        o.RowKey,
        CAST(NULL AS VARCHAR(200))
    FROM @OrderedWithCounts o
    WHERE ISNULL(o.EffectiveChildCount, 0) > 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM @SingleOrderedChildCollapse soc
          WHERE soc.ChildOrderedRowKey = o.RowKey
      );

    INSERT INTO @RenderRows
    (
        OrderedLineNumber,
        SortBucket,
        IsParentRow,
        UseChildValues,
        SourceState,
        EffectiveChildCount,
        RowChangeFlag,
        QtyOrdered,
        QtyReleased,
        QtyShipped,
        ManufacturerName,
        FixtureType,
        PartNumber,
        EstimatedShipDate,
        ChildShipped,
        ShipDate,
        Carrier,
        TrackingNumber,
        IsQtyOrderedChanged,
        IsQtyReleasedChanged,
        IsQtyShippedChanged,
        IsManufacturerChanged,
        IsFixtureTypeChanged,
        IsPartNumberChanged,
        IsEstimatedShipDateChanged,
        IsShipDateChanged,
        IsCarrierChanged,
        IsTrackingNumberChanged,
        HasVisibleHighlight,
        OrderedRowKey,
        ChildRowKey
    )
    SELECT
        o.OrderedLineNumber,
        2,
        CAST(0 AS BIT),
        CAST(1 AS BIT),
        c.SourceState,
        o.EffectiveChildCount,
        c.RowChangeFlag,
        o.QtyOrdered,
        o.QtyReleased,
        c.QtyShipped,
        c.ManufacturerName,
        c.FixtureType,
        c.PartNumber,
        COALESCE(c.EstimatedShipDate, CASE WHEN c.SourceState = 'Shipped' THEN c.ShipDate END),
        c.QtyShipped,
        c.ShipDate,
        c.Carrier,
        c.TrackingNumber,
        o.IsQtyOrderedChanged,
        o.IsQtyReleasedChanged,
        c.IsQtyShippedChanged,
        c.IsManufacturerChanged,
        c.IsFixtureTypeChanged,
        c.IsPartNumberChanged,
        c.IsEstimatedShipDateChanged,
        c.IsShipDateChanged,
        c.IsCarrierChanged,
        c.IsTrackingNumberChanged,
        CAST(0 AS BIT),
        o.RowKey,
        c.RowKey
    FROM @OrderedWithCounts o
    JOIN @ChildRenderBase c
        ON c.ParentRowKey = o.RowKey
    WHERE ISNULL(o.EffectiveChildCount, 0) > 1
      AND NOT EXISTS
      (
          SELECT 1
          FROM @SingleOrderedChildCollapse soc
          WHERE soc.ChildOrderedRowKey = o.RowKey
      );

    UPDATE rr
    SET HasVisibleHighlight =
        CASE
            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN 1
            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') <> 'Shipped' AND rr.EstimatedShipDate IS NOT NULL THEN 1
            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped'
                 AND
                 (
                     CASE WHEN rr.UseChildValues = 1 THEN ISNULL(rr.ChildShipped, 0) ELSE ISNULL(rr.QtyShipped, 0) END <> 0
                     OR rr.ShipDate IS NOT NULL
                     OR ISNULL(rr.Carrier, '') <> ''
                     OR ISNULL(rr.TrackingNumber, '') <> ''
                 ) THEN 1
            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Scheduled'
                 AND rr.IsEstimatedShipDateChanged = 1
                 AND rr.EstimatedShipDate IS NOT NULL THEN 1
            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped'
                 AND rr.IsQtyShippedChanged = 1
                 AND CASE WHEN rr.UseChildValues = 1 THEN ISNULL(rr.ChildShipped, 0) ELSE ISNULL(rr.QtyShipped, 0) END <> 0 THEN 1
            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped'
                 AND rr.IsShipDateChanged = 1
                 AND rr.ShipDate IS NOT NULL THEN 1
            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped'
                 AND rr.IsCarrierChanged = 1
                 AND ISNULL(rr.Carrier, '') <> '' THEN 1
            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped'
                 AND rr.IsTrackingNumberChanged = 1
                 AND ISNULL(rr.TrackingNumber, '') <> '' THEN 1
            ELSE 0
        END
    FROM @RenderRows rr;

    IF ISNULL(@Status, '') <> 'Acknowledge'
       AND NOT EXISTS
    (
        SELECT 1
        FROM @RenderRows rr
        WHERE rr.HasVisibleHighlight = 1
    )
    BEGIN
        RETURN NULL;
    END

    SELECT
        @Html =
            CAST(
                CONCAT(
                    '#div/',
                    '~Subject~PO Notification (',
                    ISNULL(@Status, 'No Change'),
                    ') #',
                    @POnumber,
                    IIF(@ProjectName = '', '', CONCAT(' - ', @ProjectName)),
                    '<br></br>',
                    '<div style="padding: 12px 12px 18px 12px; margin-bottom: 14px; background-color: transparent; font-family: Arial, sans-serif; color: #333;">',
                    '<h2 style="margin: 0; font-size: 13.5pt; line-height: 1.2; color: #62210F; font-weight: 700;">Purchase Order# ',
                    @POnumber,
                    '</h2>',
                    '<p style="margin: 6px 0 0 0; font-size: 12pt; line-height: 1.25; color: #333; font-weight: 700;">',
                    @ProjectName,
                    '</p>',
                    '</div>'
                ) AS NVARCHAR(MAX)
            ) +
            N'<div style="overflow-x:auto; width:100%; font-family:Arial, sans-serif; font-size:11pt; color:#333;">' +
            N'<table cellpadding="5" cellspacing="0" border="1" style="width:100%; border-collapse:collapse; table-layout:fixed; min-width:900px; font-family:Arial, sans-serif; font-size:11pt; color:#333;">' +
            N'<thead><tr>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:6px 4px; text-align:center; background-color:#FEB634; font-size:13pt; font-weight:700;">Qty Ordered</th>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:6px 4px; text-align:center; background-color:#FEB634; font-size:13pt; font-weight:700;">Qty Released</th>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:6px 4px; text-align:center; background-color:#FEB634; font-size:13pt; font-weight:700;">Qty Shipped</th>' +
            N'<th width="120" style="width:120px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Manufacturer</th>' +
            N'<th width="90" style="width:90px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Type</th>' +
            N'<th width="260" style="width:260px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Part#</th>' +
            N'<th width="110" style="width:110px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Estimated Ship Date</th>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Shipped</th>' +
            N'<th width="110" style="width:110px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Ship Date</th>' +
            N'<th width="140" style="width:140px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Carrier</th>' +
            N'<th width="160" style="width:160px; border:1px solid black; padding:6px 4px; text-align:left; background-color:#FEB634; font-size:13pt; font-weight:700;">Tracking</th>' +
            N'</tr></thead><tbody>' +
            ISNULL(
                (
                    SELECT
                        N'<tr>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN rr.UseChildValues = 1 OR ISNULL(rr.QtyOrdered, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.QtyOrdered)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN rr.UseChildValues = 1 OR ISNULL(rr.QtyReleased, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.QtyReleased)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:#FFFFB0;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsQtyShippedChanged = 1 AND ISNULL(rr.QtyShipped, 0) <> 0 THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN ISNULL(rr.QtyShipped, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.QtyShipped)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:#FFFFB0;' ELSE N'' END +
                        N'">' + ISNULL(rr.ManufacturerName, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:#FFFFB0;' ELSE N'' END +
                        N'">' + ISNULL(rr.FixtureType, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:#FFFFB0;' ELSE N'' END +
                        N'">' + ISNULL(rr.PartNumber, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') <> 'Shipped' AND rr.EstimatedShipDate IS NOT NULL THEN N'background-color:#FFFFB0;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Scheduled' AND rr.IsEstimatedShipDateChanged = 1 AND rr.EstimatedShipDate IS NOT NULL THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' + ISNULL(CONVERT(NVARCHAR(10), rr.EstimatedShipDate, 101), N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:#FFFFB0;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsQtyShippedChanged = 1 AND ISNULL(rr.ChildShipped, 0) <> 0 THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN ISNULL(rr.ChildShipped, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.ChildShipped)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:#FFFFB0;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsShipDateChanged = 1 AND rr.ShipDate IS NOT NULL THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' + ISNULL(CONVERT(NVARCHAR(10), rr.ShipDate, 101), N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:#FFFFB0;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsCarrierChanged = 1 AND ISNULL(rr.Carrier, N'') <> N'' THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' + ISNULL(rr.Carrier, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:#FFFFB0;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsTrackingNumberChanged = 1 AND ISNULL(rr.TrackingNumber, N'') <> N'' THEN N'background-color:#FFFFB0;'
                            ELSE N''
                        END +
                        N'">' +
                        /* tracking link carrier map v2 */
                        CASE
                            WHEN rr.TrackingNumber IS NULL OR rr.TrackingNumber = N''
                                THEN N''
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) IN (N'FEDEX', N'FED EX', N'FDEG', N'FEDEX GROUND', N'FDEN', N'FX', N'FXFE', N'FEDEX-PRIORITY OVERNIGHT')
                                THEN N'<a href="https://www.fedex.com/wtrk/track/?trknbr=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) IN (N'UPS', N'UPS GROUND', N'UPSN')
                                THEN N'<a href="https://www.ups.com/track?track=yes&trackNums=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) = N'XPO'
                                THEN N'<a href="https://ext-web.ltl-xpo.com/public-app/shipments?referenceNumber=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) = N'SAIA'
                                THEN N'<a href="https://www.saia.com/track/details;pro=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN ISNULL(rr.Carrier, N'') = N'R+L CARRIERS'
                                THEN N'<a href="https://www2.rlcarriers.com/freight/shipping/shipment-tracing?pro=' + rr.TrackingNumber + N'&docType=PRO&source=web" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) = N'THE CUSTOM COMPANIES'
                                THEN N'<a href="https://api.customco.com/scripts/cgiip.exe/boldetail.htm?wbtn=PRO&wpro1=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) LIKE N'%DAYLIGHT%'
                                THEN N'<a href="https://mydaylight.dylt.com/external/shipment?probill=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) IN (N'OLD DOMINION', N'ODFL')
                                THEN N'<a href="https://www.odfl.com/us/en/tools/trace-track-ltl-freight.html?proNumbers=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) = N'ESTES'
                                THEN N'<a href="https://www.estes-express.com/myestes/shipment-tracking/?query=' + rr.TrackingNumber + N'&type=PRO" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) = N'MAINFREIGHT'
                                THEN N'<a href="https://www.mainfreight.com/track/api/trackings?reference=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) = N'CNWY'
                                THEN N'<a href="https://ext-web.ltl-xpo.com/public-app/shipments?referenceNumber=' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            WHEN UPPER(LTRIM(RTRIM(ISNULL(rr.Carrier, N'')))) IN (N'ABFS', N'MOLY')
                                THEN N'<a href="https://arcb.com/panther-premium/tracking#/' + rr.TrackingNumber + N'" target="_blank">' + rr.TrackingNumber + N'</a>'
                            ELSE N'<a href="https://www.google.com/search?q=%5B' + rr.TrackingNumber + N'%5D%20package%20tracking%20number" target="_blank">' + rr.TrackingNumber + N'</a>'
                        END +
                        N'</td>' +
                        N'</tr>'
                    FROM @RenderRows rr
                    ORDER BY rr.OrderedLineNumber, rr.SortBucket, rr.ChildRowKey
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'),
                N''
            ) +
            N'</tbody></table></div>' +
            N'<div style="margin-top:24px; font-family:Arial, sans-serif; font-size:11pt; color:#333; text-align:left;">' +
            ISNULL(@SignatureHtml, N'') +
            N'<div style="display:block; max-width:240px;">' +
            ISNULL(@LogoHtml, N'') +
            N'</div>' +
            N'</div><br></br><br></br>';

    RETURN @Html;
END;
GO


SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*---------------------------------------------------------------------------
  10. Wrapper HTML function
---------------------------------------------------------------------------*/
CREATE OR ALTER FUNCTION dbo.GetPOitemHistory_V2
(
    @DBID VARCHAR(32),
    @POID VARCHAR(32),
    @Status VARCHAR(24) = NULL
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @SourceUpdateDate DATETIME2(7) = NULL;
    DECLARE @RecentDateCutoff DATE = CAST(DATEADD(DAY, -5, GETDATE()) AS DATE);
    DECLARE @IsInitial BIT = 0;
    DECLARE @Html NVARCHAR(MAX) = NULL;

    SET @Status = ISNULL(@Status, dbo.GetPOitemHistoryStatus_V2(@DBID, @POID));

    IF @Status IS NULL
    BEGIN
        RETURN NULL;
    END

    SELECT TOP (1)
        @IsInitial = ISNULL(r.IsInitial, 0)
    FROM SRC.PurchaseOrderItemSnapshotRunV2 r
    WHERE r.DBID = @DBID
      AND r.POID = @POID
    ORDER BY r.SnapshotRunId DESC;

    SELECT TOP (1)
        @SourceUpdateDate = po.UPDATEDATE
    FROM OASIS_PLS.oasis.CHSC_PO po
    WHERE po.DBID = @DBID
      AND po.POID = @POID;

    IF @Status IN ('Shipped', 'Scheduled')
       AND NOT
       (
           ISNULL(@IsInitial, 0) = 1
           AND @SourceUpdateDate IS NOT NULL
           AND @SourceUpdateDate >= DATEADD(DAY, -5, GETDATE())
           AND NOT EXISTS
           (
               SELECT 1
               FROM SRC.vw_PurchaseOrderItemSnapshotCurrentV2 s
               WHERE s.DBID = @DBID
                 AND s.POID = @POID
                 AND s.RowType = 'C'
                 AND s.SourceState = 'Shipped'
           )
       )
       AND NOT EXISTS
    (
        SELECT 1
        FROM SRC.vw_PurchaseOrderItemSnapshotCurrentV2 c
        WHERE c.DBID = @DBID
          AND c.POID = @POID
          AND c.RowType = 'C'
          AND
          (
              (
                  c.SourceState = 'Shipped'
                  AND c.ShipDate IS NOT NULL
                  AND c.ShipDate >= @RecentDateCutoff
              )
              OR
              (
                  c.SourceState = 'Scheduled'
                  AND c.EstimatedShipDate IS NOT NULL
                  AND c.EstimatedShipDate >= @RecentDateCutoff
              )
          )
    )
    BEGIN
        RETURN NULL;
    END

    SET @Html = dbo.GetPOItemHistoryDetailHtml_V2(@DBID, @POID, @Status);

    RETURN @Html;
END;
GO




