CREATE OR ALTER PROCEDURE [SRC].[VendorInvoice_Origin]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastUpdate DATETIME2(7);

    SELECT
        @LastUpdate = DATEADD(DAY, -1, ISNULL(LastUpdate, DATEADD(DAY, -2000, GETDATE())))
    FROM INTEGRAMASTER_V2.dbo.AOobject
    WHERE ClientId = 'MACSII'
      AND ObjectName = 'VendorInvoice';

    ;WITH InvoiceBase AS
    (
        SELECT
            i.DBID,
            i.INVOICEID,
            i.PARENTDBID,
            i.PARENTID,
            InvoiceErpId = CONCAT(LTRIM(RTRIM(i.DBID)), ':VINV:', CONVERT(VARCHAR(20), i.INVOICEID)),
            PurchaseOrderErpId = CONCAT(LTRIM(RTRIM(i.PARENTDBID)), ':PO:', CONVERT(VARCHAR(20), i.PARENTID)),
            VendorInvoiceNumber = NULLIF(LTRIM(RTRIM(i.INVOICENUMBER)), ''),
            InvoiceDate = CONVERT(DATE, i.INVOICEDATE),
            DueDate = CONVERT(DATE, i.DUEDATE),
            EntryDate = CONVERT(DATE, COALESCE(i.STATEMENTDATE, i.CREATEDATE, i.INVOICEDATE)),
            TotalAmount = TRY_CONVERT(DECIMAL(18, 4), i.TOTALPRICE),
            PaidAmount = TRY_CONVERT(DECIMAL(18, 4), i.AMOUNTPAID),
            Paid = CAST(CASE
                WHEN ISNULL(TRY_CONVERT(DECIMAL(18, 4), i.AMOUNTPAID), 0) <> 0
                  OR ISNULL(i.PAIDSTATUS, 0) <> 0
                THEN 1
                ELSE 0
            END AS BIT),
            PaymentTermsDescription = NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(255), i.TERMS))), ''),
            Notes = NULLIF(LTRIM(RTRIM(CONVERT(VARCHAR(MAX), i.NOTES))), ''),
            ProjectErpId = po.ProjectExternalId,
            QuoteId = po.QuoteId,
            DistributorSourceId = COALESCE(
                NULLIF(LTRIM(RTRIM(i.DISTRIBUTORID)), ''),
                NULLIF(LTRIM(RTRIM(rawPo.DISTRIBUTORID)), '')
            ),
            ManufacturerSourceId = COALESCE(
                NULLIF(LTRIM(RTRIM(i.MANUFACTURERID)), ''),
                NULLIF(LTRIM(RTRIM(rawPo.MANUFACTURERID)), '')
            ),
            VendorSourceId = COALESCE(
                NULLIF(LTRIM(RTRIM(i.MANUFACTURERID)), ''),
                NULLIF(LTRIM(RTRIM(rawPo.MANUFACTURERID)), ''),
                NULLIF(LTRIM(RTRIM(i.DISTRIBUTORID)), ''),
                NULLIF(LTRIM(RTRIM(rawPo.DISTRIBUTORID)), '')
            ),
            ShipFromSourceId = COALESCE(
                NULLIF(LTRIM(RTRIM(i.DISTRIBUTORID)), ''),
                NULLIF(LTRIM(RTRIM(rawPo.DISTRIBUTORID)), ''),
                NULLIF(LTRIM(RTRIM(i.MANUFACTURERID)), ''),
                NULLIF(LTRIM(RTRIM(rawPo.MANUFACTURERID)), '')
            ),
            PayToName = COALESCE(
                NULLIF(LTRIM(RTRIM(i.BILLNAME)), ''),
                NULLIF(LTRIM(RTRIM(i.SHIPCO)), ''),
                NULLIF(LTRIM(RTRIM(i.SHIPNAME)), '')
            ),
            PayToLine1 = NULLIF(LTRIM(RTRIM(i.BILLLINE1)), ''),
            PayToLine2 = NULLIF(LTRIM(RTRIM(i.BILLLINE2)), ''),
            PayToCity = NULLIF(LTRIM(RTRIM(i.BILLCITY)), ''),
            PayToState = NULLIF(LTRIM(RTRIM(i.BILLSTATE)), ''),
            PayToPostalCode = NULLIF(LTRIM(RTRIM(i.BILLZIP)), ''),
            PayToCountry = NULLIF(LTRIM(RTRIM(i.BILLCOUNTRY)), ''),
            ShipToName = COALESCE(
                NULLIF(LTRIM(RTRIM(i.SHIPCO)), ''),
                NULLIF(LTRIM(RTRIM(i.SHIPNAME)), ''),
                NULLIF(LTRIM(RTRIM(i.PROJECT)), '')
            ),
            ShipToLine1 = NULLIF(LTRIM(RTRIM(i.SHIPLINE1)), ''),
            ShipToLine2 = NULLIF(LTRIM(RTRIM(i.SHIPLINE2)), ''),
            ShipToCity = NULLIF(LTRIM(RTRIM(i.SHIPCITY)), ''),
            ShipToState = NULLIF(LTRIM(RTRIM(i.SHIPSTATE)), ''),
            ShipToPostalCode = NULLIF(LTRIM(RTRIM(i.SHIPZIP)), ''),
            ShipToCountry = NULLIF(LTRIM(RTRIM(i.SHIPCOUNTRY)), ''),
            SourceStatusId = i.STATUS,
            SourcePaidStatusId = i.PAIDSTATUS,
            UpdatedAt = COALESCE(i.UPDATEDATE, i.CREATEDATE, i.INVOICEDATE)
        FROM OASIS_MACSII.oasis.CHSC_INVOICE i
        LEFT JOIN OASIS_MACSII.oasis.CHSC_PO rawPo
            ON i.PARENTTYPE = 2
           AND i.PARENTDBID = rawPo.DBID
           AND i.PARENTID = rawPo.POID
        LEFT JOIN src.PurchaseOrder po
            ON i.PARENTDBID = po.DBID
           AND CONVERT(VARCHAR(20), i.PARENTID) = po.POID
        WHERE i.PARENTTYPE = 2
          AND COALESCE(i.UPDATEDATE, i.CREATEDATE, i.INVOICEDATE) >= ISNULL(@LastUpdate, DATEADD(DAY, -2000, GETDATE()))
    ),
    LineBase AS
    (
        SELECT
            il.DBID,
            il.INVOICEID,
            LineNumber = il.LINENUMBER + 1,
            ErpLineId = COALESCE(
                NULLIF(CONVERT(VARCHAR(50), NULLIF(il.LINEUID, 0)), ''),
                CONCAT('LN-', CONVERT(VARCHAR(50), il.LINENUMBER + 1))
            ),
            Quantity = ISNULL(TRY_CONVERT(INT, il.QUANTITY), 0),
            ModelNumber = NULLIF(LTRIM(RTRIM(il.PARTNUMBER)), ''),
            Description = NULLIF(LTRIM(RTRIM(il.DESCRIPTION)), ''),
            PricingPer = 1,
            SellingUom = CASE UPPER(NULLIF(LTRIM(RTRIM(COALESCE(il.PARTQUANTITY, il.UNITQUANTITY))), ''))
                WHEN 'E' THEN 'EA'
                WHEN 'EA' THEN 'EA'
                WHEN 'PC' THEN 'EA'
                WHEN 'L' THEN 'LOT'
                ELSE COALESCE(NULLIF(LTRIM(RTRIM(COALESCE(il.PARTQUANTITY, il.UNITQUANTITY))), ''), 'EA')
            END,
            UnitCostAmount = CAST(
                COALESCE(
                    NULLIF(TRY_CONVERT(DECIMAL(18, 4), il.COST), 0),
                    TRY_CONVERT(DECIMAL(18, 4), il.NETPRICE),
                    0
                ) AS DECIMAL(18, 4)
            ),
            ExtendedCostAmount = CAST(
                COALESCE(
                    CASE
                        WHEN NULLIF(TRY_CONVERT(DECIMAL(18, 4), il.COST), 0) IS NOT NULL
                             AND NULLIF(TRY_CONVERT(DECIMAL(18, 4), il.NETPRICE), 0) IS NULL
                        THEN TRY_CONVERT(DECIMAL(18, 4), il.COST) * ABS(COALESCE(TRY_CONVERT(DECIMAL(18, 4), il.QUANTITY), 1))
                        ELSE TRY_CONVERT(DECIMAL(18, 4), il.NETPRICE) * ABS(COALESCE(TRY_CONVERT(DECIMAL(18, 4), il.QUANTITY), 1))
                    END,
                    0
                ) AS DECIMAL(18, 4)
            ),
            IsTaxLine = CASE
                WHEN ISNULL(TRY_CONVERT(DECIMAL(18, 4), il.TAXRATE), 0) > 0
                  OR UPPER(ISNULL(il.PARTNUMBER, '')) LIKE '%GST%'
                  OR UPPER(ISNULL(il.PARTNUMBER, '')) LIKE '%HST%'
                  OR UPPER(ISNULL(il.PARTNUMBER, '')) LIKE '%PST%'
                  OR UPPER(ISNULL(il.PARTNUMBER, '')) LIKE '%TAX%'
                  OR UPPER(ISNULL(il.DESCRIPTION, '')) LIKE '%TAX%'
                THEN 1
                ELSE 0
            END,
            IsFreightLine = CASE
                WHEN UPPER(ISNULL(il.PARTNUMBER, '')) LIKE '%FREIGHT%'
                  OR UPPER(ISNULL(il.DESCRIPTION, '')) LIKE '%FREIGHT%'
                THEN 1
                ELSE 0
            END
        FROM OASIS_MACSII.oasis.CHSC_INVOICELINE il
    )
    SELECT
        ib.InvoiceErpId,
        ib.PurchaseOrderErpId,
        ib.ProjectErpId,
        ib.QuoteId,
        ib.DBID,
        ib.INVOICEID,
        ib.PARENTDBID,
        ib.PARENTID,
        ib.VendorInvoiceNumber,
        ib.InvoiceDate,
        ib.DueDate,
        ib.EntryDate,
        ib.DistributorSourceId,
        ib.ManufacturerSourceId,
        ib.VendorSourceId,
        ib.ShipFromSourceId,
        ib.PayToName,
        ib.PayToLine1,
        ib.PayToLine2,
        ib.PayToCity,
        ib.PayToState,
        ib.PayToPostalCode,
        ib.PayToCountry,
        ib.ShipToName,
        ib.ShipToLine1,
        ib.ShipToLine2,
        ib.ShipToCity,
        ib.ShipToState,
        ib.ShipToPostalCode,
        ib.ShipToCountry,
        SubtotalAmount = lineTotals.SubtotalAmount,
        TaxAmount = lineTotals.TaxAmount,
        FreightAmount = lineTotals.FreightAmount,
        ib.TotalAmount,
        ib.PaidAmount,
        ib.Paid,
        ib.PaymentTermsDescription,
        ib.Notes,
        SourceStatusId = ib.SourceStatusId,
        SourcePaidStatusId = ib.SourcePaidStatusId,
        RecommendedParspecStatus = CASE
            WHEN ISNULL(ib.Paid, 0) = 1 THEN 'PAID'
            ELSE 'OPEN'
        END,
        RecommendedWorkflowState = CASE
            WHEN ISNULL(ib.Paid, 0) = 1 THEN 'CLOSED'
            ELSE 'OPEN'
        END,
        LineItemsJson = lineJson.LineItemsJson,
        PayloadJson =
        (
            SELECT
                ib.InvoiceErpId AS erpId,
                ib.VendorInvoiceNumber AS vendorInvoiceNumber,
                CONVERT(VARCHAR(10), ib.InvoiceDate, 23) AS invoiceDate,
                CONVERT(VARCHAR(10), ib.DueDate, 23) AS dueDate,
                CONVERT(VARCHAR(10), ib.EntryDate, 23) AS entryDate,
                CONVERT(VARCHAR(32), lineTotals.SubtotalAmount) AS subtotalAmount,
                CONVERT(VARCHAR(32), lineTotals.TaxAmount) AS taxAmount,
                CONVERT(VARCHAR(32), lineTotals.FreightAmount) AS freightAmount,
                CONVERT(VARCHAR(32), ib.TotalAmount) AS totalAmount,
                ib.Paid AS paid,
                CONVERT(VARCHAR(32), ISNULL(ib.PaidAmount, 0)) AS paidAmount,
                ib.PaymentTermsDescription AS paymentTermsDescription,
                ib.Notes AS notes,
                JSON_QUERY(
                    (
                        SELECT
                            ib.PurchaseOrderErpId AS erpId
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                ) AS purchaseOrder,
                JSON_QUERY(
                    (
                        SELECT
                            ib.VendorSourceId AS erpId,
                            ib.PayToName AS name,
                            JSON_QUERY(
                                (
                                    SELECT
                                        ib.PayToLine1 AS line1,
                                        ib.PayToLine2 AS line2,
                                        ib.PayToCity AS city,
                                        ib.PayToState AS stateOrRegionCode,
                                        ib.PayToPostalCode AS postalCode,
                                        ib.PayToCountry AS countryCode
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                )
                            ) AS address
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                ) AS payTo,
                JSON_QUERY(
                    (
                        SELECT
                            ib.ShipFromSourceId AS erpId,
                            ib.PayToName AS name,
                            JSON_QUERY(
                                (
                                    SELECT
                                        ib.PayToLine1 AS line1,
                                        ib.PayToLine2 AS line2,
                                        ib.PayToCity AS city,
                                        ib.PayToState AS stateOrRegionCode,
                                        ib.PayToPostalCode AS postalCode,
                                        ib.PayToCountry AS countryCode
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                )
                            ) AS address
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                ) AS shipFrom,
                JSON_QUERY(
                    (
                        SELECT
                            ib.ShipToName AS name,
                            JSON_QUERY(
                                (
                                    SELECT
                                        ib.ShipToLine1 AS line1,
                                        ib.ShipToLine2 AS line2,
                                        ib.ShipToCity AS city,
                                        ib.ShipToState AS stateOrRegionCode,
                                        ib.ShipToPostalCode AS postalCode,
                                        ib.ShipToCountry AS countryCode
                                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                                )
                            ) AS address
                        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                    )
                ) AS shipTo,
                JSON_QUERY(lineJson.LineItemsJson) AS lineItems
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM InvoiceBase ib
    OUTER APPLY
    (
        SELECT
            SubtotalAmount = CAST(SUM(CASE WHEN lb.IsTaxLine = 0 AND lb.IsFreightLine = 0 THEN lb.ExtendedCostAmount ELSE 0 END) AS DECIMAL(18, 4)),
            TaxAmount = CAST(SUM(CASE WHEN lb.IsTaxLine = 1 THEN lb.ExtendedCostAmount ELSE 0 END) AS DECIMAL(18, 4)),
            FreightAmount = CAST(SUM(CASE WHEN lb.IsFreightLine = 1 THEN lb.ExtendedCostAmount ELSE 0 END) AS DECIMAL(18, 4))
        FROM LineBase lb
        WHERE lb.DBID = ib.DBID
          AND lb.INVOICEID = ib.INVOICEID
    ) lineTotals
    OUTER APPLY
    (
        SELECT
            LineItemsJson =
            (
                SELECT
                    lb.ErpLineId AS erpLineId,
                    lb.Quantity AS quantity,
                    lb.ModelNumber AS modelNumber,
                    lb.Description AS description,
                    CONVERT(VARCHAR(32), lb.UnitCostAmount) AS unitCostAmount,
                    CONVERT(VARCHAR(32), lb.ExtendedCostAmount) AS extendedCostAmount,
                    lb.PricingPer AS pricingPer,
                    lb.SellingUom AS sellingUom
                FROM LineBase lb
                WHERE lb.DBID = ib.DBID
                  AND lb.INVOICEID = ib.INVOICEID
                ORDER BY lb.LineNumber
                FOR JSON PATH
            )
    ) lineJson
    ORDER BY
        ib.UpdatedAt DESC,
        ib.DBID,
        ib.INVOICEID;
END
