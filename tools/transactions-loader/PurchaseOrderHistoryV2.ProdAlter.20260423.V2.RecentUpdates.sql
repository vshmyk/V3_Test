
/*
  V2 recent production updates (2026-04-23).
  Includes:
    - dbo.GetPOitemHistoryStatus_V2
      * Acknowledge requires latest run IsInitial=1
      * Acknowledge requires CHSC_PO.UPDATEDATE within 2 days
      * Acknowledge requires no shipped/scheduled child rows
    - dbo.GetPOItemHistoryDetailHtml_V2
      * materializes per-PO diff rows inside the renderer to avoid repeated view/CTE expansion
    - dbo.GetPOitemHistory_V2
      * suppress HTML for Shipped/Scheduled unless recent item date (last 2 days)
      * removed stale CHSC_PO.UPDATEDATE suppression for non-initial runs
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

CREATE OR ALTER FUNCTION dbo.GetPOItemHistoryDetailHtml_V2
(
    @DBID VARCHAR(32),
    @POID VARCHAR(32)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Html NVARCHAR(MAX) = NULL;
    DECLARE @Status VARCHAR(24) = dbo.GetPOitemHistoryStatus_V2(@DBID, @POID);
    DECLARE @POnumber VARCHAR(96) = '';
    DECLARE @ProjectName VARCHAR(128) = '';
    DECLARE @LogoHtml NVARCHAR(MAX) = dbo.GetLogoImage();

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
        @ProjectName = ISNULL(pr.[Name], '')
    FROM SRC.vw_PurchaseOrderItemSnapshotCurrentV2 s
    LEFT JOIN AO.PurchaseOrder po
        ON po.Id = s.PurchaseOrderId
    LEFT JOIN AO.Project pr
        ON pr.Id = po.Project__c
    WHERE s.DBID = @DBID
      AND s.POID = @POID;

    DECLARE @DetailRows TABLE
    (
        RowType CHAR(1) NOT NULL,
        RowKey VARCHAR(200) NOT NULL,
        ParentRowKey VARCHAR(200) NULL,
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
    );

    DECLARE @OrderedWithCounts TABLE
    (
        RowKey VARCHAR(200) NOT NULL PRIMARY KEY,
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
        OrderedRowKey,
        ChildRowKey
    )
    SELECT
        o.OrderedLineNumber,
        1,
        CAST(0 AS BIT),
        CAST(0 AS BIT),
        COALESCE(c.SourceState, o.SourceState),
        o.EffectiveChildCount,
        CASE WHEN c.RowKey IS NOT NULL THEN c.RowChangeFlag ELSE o.RowChangeFlag END,
        o.QtyOrdered,
        o.QtyReleased,
        CASE WHEN ISNULL(o.QtyShipped, 0) = 0 THEN ISNULL(c.QtyShipped, 0) ELSE o.QtyShipped END,
        COALESCE(c.ManufacturerName, o.ManufacturerName),
        COALESCE(c.FixtureType, o.FixtureType),
        COALESCE(c.PartNumber, o.PartNumber),
        COALESCE(c.EstimatedShipDate, CASE WHEN c.SourceState = 'Shipped' THEN c.ShipDate END),
        c.QtyShipped,
        c.ShipDate,
        c.Carrier,
        c.TrackingNumber,
        o.IsQtyOrderedChanged,
        o.IsQtyReleasedChanged,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsQtyShippedChanged ELSE o.IsQtyShippedChanged END,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsManufacturerChanged ELSE o.IsManufacturerChanged END,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsFixtureTypeChanged ELSE o.IsFixtureTypeChanged END,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsPartNumberChanged ELSE o.IsPartNumberChanged END,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsEstimatedShipDateChanged ELSE CAST(0 AS BIT) END,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsShipDateChanged ELSE CAST(0 AS BIT) END,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsCarrierChanged ELSE CAST(0 AS BIT) END,
        CASE WHEN c.RowKey IS NOT NULL THEN c.IsTrackingNumberChanged ELSE CAST(0 AS BIT) END,
        o.RowKey,
        c.RowKey
    FROM @OrderedWithCounts o
    OUTER APPLY
    (
        SELECT TOP (1) c.*
        FROM @ChildRenderBase c
        WHERE c.ParentRowKey = o.RowKey
        ORDER BY c.LogicalChildUID
    ) c
    WHERE ISNULL(o.EffectiveChildCount, 0) <= 1;

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
        o.RowKey,
        CAST(NULL AS VARCHAR(200))
    FROM @OrderedWithCounts o
    WHERE ISNULL(o.EffectiveChildCount, 0) > 1;

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
        o.RowKey,
        c.RowKey
    FROM @OrderedWithCounts o
    JOIN @ChildRenderBase c
        ON c.ParentRowKey = o.RowKey
    WHERE ISNULL(o.EffectiveChildCount, 0) > 1;

    SELECT
        @Html =
            CAST(
                CONCAT(
                    '#div/',
                    @LogoHtml,
                    '<br></br>',
                    '~Subject~PO Notification (',
                    ISNULL(@Status, 'No Change'),
                    ') #',
                    @POnumber,
                    IIF(@ProjectName = '', '', CONCAT(' - ', REPLACE(@ProjectName, ' - Initial Phase', ''))),
                    '<br></br>',
                    '<div style="padding: 12px; margin-bottom: 16px; background-color: transparent; font-family: Arial, sans-serif;">',
                    '<h2 style="margin: 0; font-size: 13px; color: #62210F;">Purchase Order# ',
                    @POnumber,
                    '</h2>',
                    '<p style="margin: 4px 0 0 0; font-size: 16px; color: #333;"><b>',
                    REPLACE(@ProjectName, ' - Initial Phase', ''),
                    '</b></p>',
                    '</div>'
                ) AS NVARCHAR(MAX)
            ) +
            N'<div style="overflow-x:auto; width:100%;">' +
            N'<table cellpadding="5" cellspacing="0" border="1" style="width:100%; border-collapse:collapse; table-layout:fixed; min-width:900px;">' +
            N'<thead><tr>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:4px; text-align:center;">Qty Ordered</th>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:4px; text-align:center;">Qty Released</th>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:4px; text-align:center;">Qty Shipped</th>' +
            N'<th width="120" style="width:120px; border:1px solid black; padding:4px; text-align:left;">Manufacturer</th>' +
            N'<th width="90" style="width:90px; border:1px solid black; padding:4px; text-align:left;">Type</th>' +
            N'<th width="260" style="width:260px; border:1px solid black; padding:4px; text-align:left;">Part#</th>' +
            N'<th width="110" style="width:110px; border:1px solid black; padding:4px; text-align:center;">Estimated Ship Date</th>' +
            N'<th width="60" style="width:60px; border:1px solid black; padding:4px; text-align:center;">Shipped</th>' +
            N'<th width="110" style="width:110px; border:1px solid black; padding:4px; text-align:center;">Ship Date</th>' +
            N'<th width="140" style="width:140px; border:1px solid black; padding:4px; text-align:left;">Carrier</th>' +
            N'<th width="160" style="width:160px; border:1px solid black; padding:4px; text-align:left;">Tracking</th>' +
            N'</tr></thead><tbody>' +
            ISNULL(
                (
                    SELECT
                        N'<tr>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN rr.UseChildValues = 1 OR ISNULL(rr.QtyOrdered, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.QtyOrdered)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN rr.UseChildValues = 1 OR ISNULL(rr.QtyReleased, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.QtyReleased)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:yellow;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsQtyShippedChanged = 1 AND ISNULL(rr.QtyShipped, 0) <> 0 THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN ISNULL(rr.QtyShipped, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.QtyShipped)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:yellow;' ELSE N'' END +
                        N'">' + ISNULL(rr.ManufacturerName, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:yellow;' ELSE N'' END +
                        N'">' + ISNULL(rr.FixtureType, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') NOT IN ('Shipped', 'Scheduled') THEN N'background-color:yellow;' ELSE N'' END +
                        N'">' + ISNULL(rr.PartNumber, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') <> 'Shipped' AND rr.EstimatedShipDate IS NOT NULL THEN N'background-color:yellow;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Scheduled' AND rr.IsEstimatedShipDateChanged = 1 AND rr.EstimatedShipDate IS NOT NULL THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' + ISNULL(CONVERT(NVARCHAR(10), rr.EstimatedShipDate, 101), N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:yellow;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsQtyShippedChanged = 1 AND ISNULL(rr.ChildShipped, 0) <> 0 THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' + CASE WHEN ISNULL(rr.ChildShipped, 0) = 0 THEN N'' ELSE CONVERT(NVARCHAR(32), CONVERT(INT, rr.ChildShipped)) END + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:center; white-space:nowrap;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:yellow;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsShipDateChanged = 1 AND rr.ShipDate IS NOT NULL THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' + ISNULL(CONVERT(NVARCHAR(10), rr.ShipDate, 101), N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:yellow;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsCarrierChanged = 1 AND ISNULL(rr.Carrier, N'') <> N'' THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' + ISNULL(rr.Carrier, N'') + N'</td>' +
                        N'<td style="border:1px solid black; padding:4px; text-align:left; white-space:normal;' +
                        CASE WHEN rr.EffectiveChildCount > 1 THEN N'background-color:#f0f0f0;' ELSE N'' END +
                        CASE WHEN rr.IsParentRow = 1 THEN N'font-weight:700;' ELSE N'' END +
                        CASE
                            WHEN rr.RowChangeFlag = '+' AND ISNULL(rr.SourceState, '') = 'Shipped' THEN N'background-color:yellow;'
                            WHEN @Status <> 'Acknowledge' AND ISNULL(rr.SourceState, '') = 'Shipped' AND rr.IsTrackingNumberChanged = 1 AND ISNULL(rr.TrackingNumber, N'') <> N'' THEN N'background-color:yellow;'
                            ELSE N''
                        END +
                        N'">' +
                        CASE
                            WHEN rr.TrackingNumber IS NULL OR rr.TrackingNumber = N''
                                THEN N''
                            WHEN ISNULL(rr.Carrier, N'') = N'R+L CARRIERS'
                                THEN N'<a href="https://www2.rlcarriers.com/freight/shipping/shipment-tracing?pro=' + rr.TrackingNumber + N'&docType=PRO&source=web" target="_blank">' + rr.TrackingNumber + N'</a>'
                            ELSE N'<a href="https://www.google.com/search?q=%5B' + rr.TrackingNumber + N'%5D package tracking number" target="_blank">' + rr.TrackingNumber + N'</a>'
                        END +
                        N'</td>' +
                        N'</tr>'
                    FROM @RenderRows rr
                    ORDER BY rr.OrderedLineNumber, rr.SortBucket, rr.ChildRowKey
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'),
                N''
            ) +
            N'</tbody></table></div><br></br><br></br>';

    IF ISNULL(@Status, '') <> 'Acknowledge'
       AND
       (
           @Html IS NULL
           OR @Html NOT LIKE '%background-color:yellow;%'
       )
    BEGIN
        RETURN NULL;
    END

    RETURN @Html;
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
    DECLARE @RecentDateCutoff DATE = CAST(DATEADD(DAY, -2, GETDATE()) AS DATE);

    IF @Status IS NULL
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

