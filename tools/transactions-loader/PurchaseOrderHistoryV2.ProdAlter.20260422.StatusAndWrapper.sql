USE [PLS_PROD]
GO

/*
  V2 production alter rollout (single file).
  Includes altered objects from 2026-04-22 changes:
    - dbo.GetPOitemHistoryStatus_V2
    - dbo.GetPOitemHistory_V2
*/
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
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

    /*
        Initial qualification rules:
          - Acknowledge: latest run is initial, PO updated within last 2 days, and no shipped/scheduled child rows
          - Shipped: can still apply on an initial run when shipped rows are present and visibly changed
          - Scheduled: can still apply on an initial run when scheduled rows with a real ESD are present
        So only recent "ordered-only" captures fall through to Acknowledge.
    */

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

    IF @IsInitial = 1
       AND @SourceUpdateDate IS NOT NULL
       AND @SourceUpdateDate >= DATEADD(DAY, -2, GETDATE())
       AND NOT EXISTS
    (
        SELECT 1
        FROM SRC.vw_PurchaseOrderItemSnapshotCurrentV2 c
        WHERE c.DBID = @DBID
          AND c.POID = @POID
          AND c.RowType = 'C'
          AND c.SourceState IN ('Shipped', 'Scheduled')
    )
    BEGIN
        RETURN 'Acknowledge';
    END

    /*
        If the PO currently has at least one shipped child row, the subject should
        be Shipped whenever there is any visible scheduled/shipped notification
        content to issue for the PO.
    */
    IF EXISTS
    (
        SELECT 1
        FROM SRC.vw_PurchaseOrderItemSnapshotCurrentV2 c
        WHERE c.DBID = @DBID
          AND c.POID = @POID
          AND c.RowType = 'C'
          AND c.SourceState = 'Shipped'
    )
    AND EXISTS
    (
        SELECT 1
        FROM SRC.vw_PurchaseOrderItemSnapshotDiffV2 d
        WHERE d.DBID = @DBID
          AND d.POID = @POID
          AND d.IsDeleted = 0
          AND
          (
              (
                  d.SourceState = 'Shipped'
                  AND
                  (
                      (
                          d.RowChangeFlag = '+'
                          AND
                          (
                              ISNULL(d.QtyShipped, 0) <> 0
                              OR d.ShipDate IS NOT NULL
                              OR ISNULL(d.Carrier, '') <> ''
                              OR ISNULL(d.TrackingNumber, '') <> ''
                          )
                      )
                      OR
                      (
                          d.IsQtyShippedChanged = 1
                          AND ISNULL(d.QtyShipped, 0) <> 0
                      )
                      OR
                      (
                          d.IsShipDateChanged = 1
                          AND d.ShipDate IS NOT NULL
                      )
                      OR
                      (
                          d.IsCarrierChanged = 1
                          AND ISNULL(d.Carrier, '') <> ''
                      )
                      OR
                      (
                          d.IsTrackingNumberChanged = 1
                          AND ISNULL(d.TrackingNumber, '') <> ''
                      )
                  )
              )
              OR
              (
                  d.SourceState = 'Scheduled'
                  AND d.EstimatedShipDate IS NOT NULL
                  AND
                  (
                      d.RowChangeFlag = '+'
                      OR d.IsEstimatedShipDateChanged = 1
                  )
              )
          )
    )
    BEGIN
        RETURN 'Shipped';
    END

    /* Scheduled applies when the row has a real ESD and that ESD is new or changed. */
    IF EXISTS
    (
        SELECT 1
        FROM SRC.vw_PurchaseOrderItemSnapshotDiffV2 d
        WHERE d.DBID = @DBID
          AND d.POID = @POID
          AND d.IsDeleted = 0
          AND d.SourceState = 'Scheduled'
          AND d.EstimatedShipDate IS NOT NULL
          AND
          (
              d.RowChangeFlag = '+'
              OR d.IsEstimatedShipDateChanged = 1
          )
    )
    BEGIN
        RETURN 'Scheduled';
    END

    RETURN @Status;
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION dbo.GetPOitemHistory_V2
(
    @DBID VARCHAR(32),
    @POID VARCHAR(32)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Status VARCHAR(24) = dbo.GetPOitemHistoryStatus_V2(@DBID, @POID);
    DECLARE @SourceUpdateDate DATETIME2(7) = NULL;
    DECLARE @RecentDateCutoff DATE = CAST(DATEADD(DAY, -2, GETDATE()) AS DATE);
    DECLARE @IsInitial BIT = 0;

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

    IF ISNULL(@IsInitial, 0) = 0
       AND @SourceUpdateDate IS NOT NULL
       AND @SourceUpdateDate < DATEADD(DAY, -2, GETDATE())
    BEGIN
        RETURN NULL;
    END

    IF @Status IN ('Shipped', 'Scheduled')
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

    RETURN dbo.GetPOItemHistoryDetailHtml_V2(@DBID, @POID);
END;
GO
