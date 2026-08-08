using AOtransact.ParspecEmulator.Models;

namespace AOtransact.ParspecEmulator.Services;

public sealed class DestinationEmulatorService
{
    private readonly BusinessLayerSourceService _businessSourceService;

    public DestinationEmulatorService(BusinessLayerSourceService businessSourceService)
    {
        _businessSourceService = businessSourceService;
    }

    public IReadOnlyList<DestinationObjectSummary> BuildObjectSummaries(IReadOnlyList<DestinationProjectionMap> projections)
    {
        return projections
            .GroupBy(p => p.ObjectName, StringComparer.OrdinalIgnoreCase)
            .Select(group =>
            {
                var fields = group.SelectMany(g => g.Fields).ToList();
                var direct = fields.Count(IsDirect);
                var derived = fields.Count(IsDerived);
                var unresolved = fields.Count - direct - derived;

                return new DestinationObjectSummary
                {
                    ObjectName = group.Key,
                    ProjectionCount = group.Count(),
                    TotalFields = fields.Count,
                    DirectFields = direct,
                    DerivedFields = derived,
                    UnresolvedFields = unresolved,
                    SourceTables = group.Select(g => g.SourceTable).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x).ToList()
                };
            })
            .OrderBy(summary => summary.ObjectName, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    public async Task<DestinationProjectionPageViewModel> BuildProjectionPageAsync(
        DestinationProjectionMap projection,
        IReadOnlyList<DestinationProjectionMap> siblingProjections,
        int take,
        CancellationToken cancellationToken)
    {
        var sourceRows = await _businessSourceService.GetRowsAsync(projection, take, cancellationToken);
        var fieldViewModels = projection.Fields
            .Select(field => new ProjectionFieldViewModel
            {
                DisplayName = field.DestinationFieldName,
                FullFieldPath = string.IsNullOrWhiteSpace(field.ParspecField) ? field.DestinationFieldName : field.ParspecField,
                HeaderClass = GetHeaderClass(field),
                HeaderReason = GetReason(field)
            })
            .ToList();

        var recordRows = sourceRows
            .Select(row => new DestinationRecordRow
            {
                RecordKey = row.DisplayKey,
                Cells = projection.Fields.Select(field => BuildCell(field, row)).ToList()
            })
            .ToList();

        return new DestinationProjectionPageViewModel
        {
            ObjectName = projection.ObjectName,
            SourceTable = projection.SourceTable,
            SourceDescription = projection.SourceDescription,
            AvailableSourceTables = siblingProjections.Select(p => p.SourceTable).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x).ToList(),
            Fields = fieldViewModels,
            Rows = recordRows,
            DirectFields = projection.Fields.Count(IsDirect),
            DerivedFields = projection.Fields.Count(IsDerived),
            UnresolvedFields = projection.Fields.Count(field => !IsDirect(field) && !IsDerived(field))
        };
    }

    public DestinationProjectionMap? ResolveProjection(
        IReadOnlyList<DestinationProjectionMap> projections,
        string objectName,
        string? sourceTable)
    {
        var candidates = projections
            .Where(p => string.Equals(p.ObjectName, objectName, StringComparison.OrdinalIgnoreCase))
            .OrderBy(p => p.SourceTable, StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (candidates.Count == 0)
        {
            return null;
        }

        if (!string.IsNullOrWhiteSpace(sourceTable))
        {
            var match = candidates.FirstOrDefault(p => string.Equals(p.SourceTable, sourceTable, StringComparison.OrdinalIgnoreCase));
            if (match is not null)
            {
                return match;
            }
        }

        return candidates[0];
    }

    private static DestinationRecordCell BuildCell(MappingField field, SourceRow row)
    {
        var value = ResolveBusinessValue(field, row.Values);
        var isValuePresent = value is not null && !string.IsNullOrWhiteSpace(value.ToString());

        if (IsDirect(field))
        {
            return new DestinationRecordCell
            {
                DisplayValue = isValuePresent ? FormatValue(value) : string.Empty,
                StatusClass = isValuePresent ? "cell-direct" : "cell-missing",
                StatusLabel = isValuePresent ? "Direct" : "Missing on source row",
                Reason = isValuePresent ? "Directly populated from MACSII_V2 business-layer data." : "Business-layer source exists for this field, but this specific record has no value."
            };
        }

        if (IsDerived(field))
        {
            value = isValuePresent ? ApplyHeuristic(field, value) : null;
            return new DestinationRecordCell
            {
                DisplayValue = value is null ? string.Empty : FormatValue(value),
                StatusClass = value is null ? "cell-missing" : "cell-derived",
                StatusLabel = value is null ? "Needs derivation" : "Derived",
                Reason = value is null
                    ? $"{GetReason(field)} This row does not currently expose enough source data in a single column."
                    : GetReason(field)
            };
        }

        return new DestinationRecordCell
        {
            DisplayValue = string.Empty,
            StatusClass = "cell-unresolved",
            StatusLabel = "Cannot populate",
            Reason = GetReason(field)
        };
    }

    private static object? ApplyHeuristic(MappingField field, object? rawValue)
    {
        if (rawValue is null)
        {
            return null;
        }

        if (ContainsAny(field.FieldStatus, "inverted"))
        {
            if (TryParseBoolean(rawValue, out var boolValue))
            {
                return !boolValue;
            }
        }

        return rawValue;
    }

    private static string GetHeaderClass(MappingField field)
    {
        if (IsDirect(field))
        {
            return "head-direct";
        }

        if (IsDerived(field))
        {
            return "head-derived";
        }

        return "head-unresolved";
    }

    private static string GetReason(MappingField field)
    {
        if (IsDirect(field))
        {
            return "Directly mapped from business-layer data.";
        }

        if (IsDerived(field))
        {
            return string.IsNullOrWhiteSpace(field.FieldStatus)
                ? "Requires derivation or reshaping from Oasis."
                : field.FieldStatus;
        }

        if (!string.IsNullOrWhiteSpace(field.FieldStatus))
        {
            return field.FieldStatus;
        }

        if (!string.IsNullOrWhiteSpace(field.Availability))
        {
            return field.Availability;
        }

        return "No usable source or logic is currently defined.";
    }

    private static object? ResolveBusinessValue(MappingField field, IReadOnlyDictionary<string, object?> rowValues)
    {
        foreach (var candidate in GetCandidateBusinessColumns(field))
        {
            if (rowValues.TryGetValue(candidate, out var value) && value is not null)
            {
                return value;
            }
        }

        return null;
    }

    private static IEnumerable<string> GetCandidateBusinessColumns(MappingField field)
    {
        var full = field.ParspecField;
        var objectName = field.DestinationObject;
        var fieldName = field.DestinationFieldName;

        foreach (var alias in GetExplicitAliases(full, objectName, fieldName))
        {
            yield return alias;
        }

        if (!string.IsNullOrWhiteSpace(fieldName))
        {
            yield return fieldName;
            yield return fieldName.Replace("_", string.Empty, StringComparison.OrdinalIgnoreCase);
        }

        if (!string.IsNullOrWhiteSpace(field.SourceField))
        {
            yield return field.SourceField;
        }
    }

    private static IEnumerable<string> GetExplicitAliases(string fullField, string objectName, string fieldName)
    {
        var key = $"{objectName}.{fieldName}";

        var aliases = key switch
        {
            "project.Project.id" => new[] { "ProjectId", "ExternalId" },
            "project.Project.name" => new[] { "ProjectName" },
            "project.Project.address" => new[] { "LocationCity", "LocationState" },
            "project.Project.is_deleted" => new[] { "ProjectStage" },
            "project.Project.project_rank" => new[] { "ProjectRank" },
            "project.Project.project_owner" => new[] { "ProjectOwner" },
            "project.Project.quoter" => new[] { "Quoter" },
            "project.Project.vertical_market" => new[] { "VerticalMarket" },
            "opportunities.Opportunity.id" => new[] { "ProjectId", "ExternalId" },
            "opportunities.Opportunity.title" => new[] { "ProjectName", "BidName" },
            "opportunities.Opportunity.estimated_value" => new[] { "Valuation", "Sell" },
            "opportunities.Opportunity.stage_config" => new[] { "ProjectStage", "BidStatus", "QuoteStatus" },
            "opportunities.Opportunity.quoter" => new[] { "Quoter", "QuoteUserId" },
            "quote.QuoteMetadata.commission" => new[] { "SellCommissions" },
            "quote.QuoteMetadata.updated_at" => new[] { "UpdateDate" },
            "quote.QuoteMetadata.commercial_model" => new[] { "BuySell" },
            "quote.QuoteDocument.id" => new[] { "QuoteId", "BidId" },
            "quote.QuoteDocument.name" => new[] { "BidName", "QuoteId" },
            "quote.QuoteDocument.updated_at" => new[] { "UpdateDate" },
            "quote.Lot.name" => new[] { "BidName" },
            "quote.Freight.calculation_method" => new[] { "MarkUp" },
            "bom.BOD.id" => new[] { "LineUID", "ItemNumber" },
            "bom.BOD.category" => new[] { "Type" },
            "bom.BOD.model_number" => new[] { "PartNumber" },
            "bom.BOD.description" => new[] { "Description" },
            "bom.BOD.quantity" => new[] { "Quantity" },
            "bom.BOD.sell_price" => new[] { "Sell" },
            "bom.BOD.base_price" => new[] { "Base" },
            "bom.BOD.markup" => new[] { "MarkUp" },
            "bom.Bom.id" => new[] { "BidId", "ProjectId", "QuoteId" },
            "bom.Bom.updated_at" => new[] { "UpdateDate" },
            "bom.BomMetadata.quote_status" => new[] { "BidStatus" },
            "rolodex.Contact.first_name" => new[] { "FIRSTNAME" },
            "rolodex.Contact.last_name" => new[] { "LASTNAME" },
            "rolodex.Contact.middle_name" => new[] { "MIDDLENAME" },
            "rolodex.Contact.phone" => new[] { "PHONE" },
            "rolodex.Contact.email" => new[] { "EMail" },
            "rolodex.Contact.title" => new[] { "JOBPOSITION" },
            "rolodex.Company.id" => new[] { "AccountId" },
            "rolodex.Company.name" => new[] { "DISTRIBUTORNAME", "SOLDNAME" },
            "rolodex.Company.phone" => new[] { "PHONE" },
            "rolodex.Company.web" => new[] { "WEB" },
            "rolodex.Company.fax" => new[] { "FAX" },
            "rolodex.CompanyRole.role_type" => new[] { "ROLE", "ACCOUNTTYPE" },
            "po_so_compilation.PurchaseOrderDoc.id" => new[] { "POID", "PurchaseOrder_Id" },
            "po_so_compilation.PurchaseOrderDoc.name" => new[] { "POnumber" },
            "po_so_compilation.PurchaseOrderDoc.status" => new[] { "POstatus" },
            "po_so_compilation.PurchaseOrderDoc.created_at" => new[] { "POdate", "PO_CreatedDate", "EntryDate" },
            "po_so_compilation.PurchaseOrderDoc.updated_at" => new[] { "UpdateDate" },
            "po_so_compilation.PurchaseOrderDoc.compiled_by" => new[] { "QuoteUserId" },
            "PurchaseOrderDoc.id" => new[] { "POID", "PurchaseOrder_Id" },
            "PurchaseOrderDoc.name" => new[] { "POnumber" },
            "PurchaseOrderDoc.status" => new[] { "POstatus" },
            "PurchaseOrderDoc.created_at" => new[] { "POdate", "PO_CreatedDate", "EntryDate" },
            "PurchaseOrderDoc.updated_at" => new[] { "UpdateDate" },
            "PurchaseOrderDoc.bom" => new[] { "ProjectId", "QuoteId" },
            "PurchaseOrderDoc.recompile_revision" => new[] { "UpdateDate" },
            "PurchaseOrderDoc.order_writer_text" => new[] { "Note" },
            "PurchaseOrderLineMapping.po_doc_id" => new[] { "POID", "PurchaseOrder_Id" },
            "PurchaseOrderLineMapping.order" => new[] { "Linenumber", "ItemNumber" },
            "PurchaseOrderLineMapping.line_uid" => new[] { "LineUID" },
            "OrderManagementMetadata.order_status" => new[] { "POstatus", "TransactionType" },
            "OrderManagementMetadata.order_notes" => new[] { "Note" },
            "OrderManagementMetadata.internal_comment" => new[] { "Note" },
            "OrderManagementMetadata.release_number" => new[] { "Released" },
            "OrderManagementMetadata.om_parent_id" => new[] { "ParentLineUID" },
            "OrderManagementMetadata.is_co_locked" => new[] { "TransactionType" },
            "SalesOrderDoc.primary_customer_company_name" => new[] { "DistributorId" },
            "SalesOrderDoc.primary_customer_contact_crm_id" => new[] { "Project__c", "Project_Id" },
            "SalesOrderDoc.customer_po_number" => new[] { "QuoteNumber", "POnumber" },
            "SalesOrderDoc.ship_to_name" => new[] { "Shipment", "DistributorId" },
            _ => Array.Empty<string>()
        };

        foreach (var alias in aliases)
        {
            yield return alias;
        }
    }

    private static string FormatValue(object? value)
    {
        return value switch
        {
            null => string.Empty,
            DateTime dateTime => dateTime.ToString("yyyy-MM-dd HH:mm:ss"),
            DateOnly dateOnly => dateOnly.ToString("yyyy-MM-dd"),
            bool boolValue => boolValue ? "true" : "false",
            _ => value.ToString() ?? string.Empty
        };
    }

    private static bool IsDirect(MappingField field)
    {
        return EqualsAny(field.Availability, "Yes")
            || EqualsAny(field.FieldStatus, "Exists", "Same column");
    }

    private static bool IsDerived(MappingField field)
    {
        return EqualsAny(field.Availability, "Partial")
            || ContainsAny(field.FieldStatus, "Derived", "Indirect", "Implicit", "Different", "Flattened", "inverted", "Choices enum");
    }

    private static bool TryParseBoolean(object rawValue, out bool value)
    {
        switch (rawValue)
        {
            case bool boolValue:
                value = boolValue;
                return true;
            case string text when string.Equals(text, "Y", StringComparison.OrdinalIgnoreCase)
                                  || string.Equals(text, "1", StringComparison.OrdinalIgnoreCase)
                                  || string.Equals(text, "true", StringComparison.OrdinalIgnoreCase):
                value = true;
                return true;
            case string text when string.Equals(text, "N", StringComparison.OrdinalIgnoreCase)
                                  || string.Equals(text, "0", StringComparison.OrdinalIgnoreCase)
                                  || string.Equals(text, "false", StringComparison.OrdinalIgnoreCase):
                value = false;
                return true;
            default:
                value = false;
                return false;
        }
    }

    private static bool EqualsAny(string value, params string[] candidates)
    {
        return candidates.Any(candidate => string.Equals(value?.Trim(), candidate, StringComparison.OrdinalIgnoreCase));
    }

    private static bool ContainsAny(string value, params string[] snippets)
    {
        return snippets.Any(snippet => value?.Contains(snippet, StringComparison.OrdinalIgnoreCase) == true);
    }
}
