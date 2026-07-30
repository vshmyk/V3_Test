using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.Data.SqlClient;
using System.Data;
using System.Globalization;
using System.Text;
using System.Text.Json;

public static class JobEntryProgramLayer
{
    private static readonly string[] ProtectedFields =
    [
        "jobId",
        "addedDateTime",
        "addedBy",
        "lastUpdate",
        "lastJobPo",
        "lastTimesheet",
        "snapshotDate",
        "contractAmount",
        "originalBudget",
        "currentBudget",
        "toDateCost",
        "toDateRevenue",
        "toDatePayment",
        "commitment",
        "yearOpenCost",
        "yearOpenRevenue",
        "period1Cost",
        "period2Cost",
        "period3Cost",
        "period4Cost",
        "period5Cost",
        "period6Cost",
        "period7Cost",
        "period8Cost",
        "period9Cost",
        "period10Cost",
        "period11Cost",
        "period12Cost",
        "period1Revenue",
        "period2Revenue",
        "period3Revenue",
        "period4Revenue",
        "period5Revenue",
        "period6Revenue",
        "period7Revenue",
        "period8Revenue",
        "period9Revenue",
        "period10Revenue",
        "period11Revenue",
        "period12Revenue"
    ];

    private static readonly Dictionary<string, JobFieldDefinition> FieldMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["activeFlag"] = CharField("active_flag", 1),
        ["description"] = StringField("description", 35),
        ["address1"] = StringField("address_1", 35),
        ["address2"] = StringField("address_2", 35),
        ["city"] = StringField("city", 20),
        ["province"] = StringField("province", 2),
        ["country"] = StringField("country", 3),
        ["postal"] = StringField("postal", 10),
        ["phone"] = StringField("phone", 10),
        ["fax"] = StringField("fax", 10),
        ["client"] = StringField("client", 6),
        ["clientJob"] = StringField("client_job", 6),
        ["clientPo"] = StringField("client_po", 20),
        ["item"] = StringField("client_po_item", 4),
        ["fixedPriceFlag"] = CharField("fixed_price_flag", 1),
        ["adminFeePercent"] = DecimalField("admin_fee_percent", 4, 2),
        ["disperseLabourBillings"] = CharField("invoice_dispersion_flag", 1),
        ["additionalHourlyAmounts"] = DecimalField("smtc_per_hour", 12, 2),
        ["labourSurchargePercent"] = DecimalField("labour_surcharge_percent", 5, 2),
        ["equipmentRevenueArea"] = StringField("equipment_revenue_area", 5),
        ["equipmentRevenueCentre"] = StringField("equipment_revenue_centre", 6),
        ["equipmentRate"] = StringField("equipment_rate_type", 8, nullIfBlank: true),
        ["labourRate"] = StringField("labour_rate_type", 8, nullIfBlank: true),
        ["labourMarkupPercent"] = DecimalField("labour_markup_percent", 4, 1),
        ["materialMarkupPercent"] = DecimalField("material_markup_percent", 4, 1),
        ["holdbackPercent"] = DecimalField("hbk_percent", 4, 1),
        ["hourlyAmountsLabel"] = StringField("smtc_per_hour_label", 50),
        ["labourSurchargeLabel"] = StringField("labour_surcharge_label", 50),
        ["poUseJobAddress"] = CharField("po_address_flag", 1),
        ["shippingMessage"] = CharField("shipping_msg_type", 1),
        ["regHoursPerDay"] = DecimalField("reg_hours_per_day", 3, 1),
        ["includeStaffHours"] = CharField("include_staff_hrs_flag", 1),
        ["timesheetPrefix"] = StringField("timesheet_prefix", 5),
        ["tradeUnionGroup"] = StringField("trade_union_group", 5),
        ["concurrentCrews"] = CharField("concurrent_crew_memberships_flag", 1),
        ["wcbClass"] = StringField("wcb_class", 3),
        ["gstRule"] = CharField("gst_rule", 1),
        ["timesheetSignLine"] = StringField("timesheet_sign_line", 25),
        ["timesheetMessage"] = StringField("timesheet_message", 25),
        ["timeEntrySheetApprover"] = CharField("equipment_time_entry_sheet_approver_style", 1),
        ["superintendent"] = StringField("superintendent", 25),
        ["parentJob"] = StringField("parent_job", 6),
        ["freezeBudget"] = CharField("freeze_budget_flag", 1),
        ["jobType"] = StringField("job_type", 12),
        ["siteContact"] = StringField("site_contact", 25),
        ["division"] = StringField("division", 3),
        ["contractCompany"] = CharField("contract_company_flag", 1),
        ["region"] = StringField("region", 6),
        ["dashboardGroup"] = StringField("dashboard_group", 6),
        ["siteContactEmail"] = StringField("project_control_email_address", 50),
        ["startDate"] = DateTimeField("start_date"),
        ["completeDate"] = DateTimeField("complete_date"),
        ["shutdownStart"] = DateTimeField("shutdown_start_date"),
        ["shutdownEnd"] = DateTimeField("shutdown_end_date"),
        ["memo"] = StringField("memo", 500),
        ["expectedCost"] = DecimalField("expected_cost", 12, 2),
        ["expectedRevenue"] = DecimalField("expected_revenue", 12, 2),
        ["lastUpdate"] = DateTimeField("last_update")
    };

    public static async Task<IResult> SaveAsync(string connectionString, JobRecordSaveCommandRequest request)
    {
        var book = Normalize(request.Book).ToUpperInvariant();
        var job = Normalize(request.Job);
        if (book.Length == 0 || job.Length == 0)
        {
            return Results.BadRequest(new ApiErrorResponse(
                "JOB_SAVE_INVALID_KEY",
                "Book and job are required before running the Job Entry save command.",
                [
                    new ApiFieldError("book", "Book is required."),
                    new ApiFieldError("job", "Job is required.")
                ]));
        }

        var changedFields = NormalizeChangedFields(request.ChangedFields);
        if (changedFields.Length == 0)
        {
            return Results.Ok(SavedResponse("No changed fields to save.", changedFields));
        }

        var protectedChanges = changedFields
            .Where(field => ProtectedFields.Contains(field, StringComparer.OrdinalIgnoreCase))
            .ToArray();

        if (protectedChanges.Length > 0)
        {
            return Results.BadRequest(new ApiErrorResponse(
                "JOB_SAVE_PROTECTED_FIELDS",
                "The Job Entry command rejected changes to protected/calculated fields before legacy validation is run.",
                protectedChanges.Select(field => new ApiFieldError(field, "This field is protected by the Job Entry program layer.")).ToArray()));
        }

        var unmappedChanges = changedFields
            .Where(field => !FieldMap.ContainsKey(field))
            .ToArray();

        if (unmappedChanges.Length > 0)
        {
            return Results.Conflict(new JobRecordSaveCommandResponse(
                Status: "legacy-program-layer-not-mapped",
                Message: "One or more changed fields are not mapped to the Job Entry program-layer command yet.",
                ChangedFields: unmappedChanges,
                RequiredLegacyReferences: LegacyReferences(),
                RequiredCommandPhases: RequiredCommandPhases()));
        }

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var transaction = await connection.BeginTransactionAsync();

        var current = await LoadCurrentJobAsync(connection, transaction, book, job);
        if (current is null)
        {
            return Results.NotFound(new ApiErrorResponse("JOB_NOT_FOUND", "The selected job was not found.", []));
        }

        if (current.FileType.Equals("H", StringComparison.OrdinalIgnoreCase))
        {
            return Results.BadRequest(new ApiErrorResponse(
                "JOB_SAVE_HISTORY_BLOCKED",
                "Use the J/C Retrieval utility to restore this job to the current file before changing it.",
                [new ApiFieldError("jobId", "Legacy Job Entry blocks edits for history jobs.")]));
        }

        var finalValues = new Dictionary<string, object?>(request.Draft, StringComparer.OrdinalIgnoreCase);
        ApplyLegacyItemChangedDefaults(connection, transaction, changedFields, finalValues);
        ApplyLegacyPreUpdateDefaults(finalValues);

        var validationErrors = await ValidateLegacyRulesAsync(connection, transaction, book, job, changedFields, current, finalValues);
        if (validationErrors.Count > 0)
        {
            return Results.BadRequest(new ApiErrorResponse(
                "JOB_SAVE_VALIDATION_FAILED",
                "The Job Entry command found legacy validation errors.",
                validationErrors));
        }

        var updateFields = changedFields
            .Concat(GetSideEffectFields(changedFields, finalValues))
            .Append("lastUpdate")
            .Where(FieldMap.ContainsKey)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        await UpdateJobAsync(connection, transaction, book, job, updateFields, finalValues);
        await transaction.CommitAsync();

        return Results.Ok(SavedResponse("Job saved through the migrated Job Entry command layer.", updateFields));
    }

    private static void ApplyLegacyItemChangedDefaults(
        SqlConnection connection,
        IDbTransaction transaction,
        string[] changedFields,
        IDictionary<string, object?> finalValues)
    {
        if (changedFields.Contains("clientPo", StringComparer.OrdinalIgnoreCase)
            && Normalize(GetString(finalValues, "clientPo")).Length == 0)
        {
            finalValues["item"] = null;
        }

        if (changedFields.Contains("equipmentRevenueArea", StringComparer.OrdinalIgnoreCase)
            && Normalize(GetString(finalValues, "equipmentRevenueArea")).Length == 0)
        {
            finalValues["equipmentRevenueCentre"] = string.Empty;
        }

        if (changedFields.Contains("province", StringComparer.OrdinalIgnoreCase)
            && !changedFields.Contains("country", StringComparer.OrdinalIgnoreCase))
        {
            var province = Normalize(GetString(finalValues, "province")).ToUpperInvariant();
            if (province.Length > 0 && TryGetProvinceCountry(connection, transaction, province, out var country))
            {
                finalValues["country"] = country;
            }
        }
    }

    private static void ApplyLegacyPreUpdateDefaults(IDictionary<string, object?> finalValues)
    {
        finalValues["lastUpdate"] = DateTime.Today;

        var address1 = Normalize(GetString(finalValues, "address1"));
        var address2 = Normalize(GetString(finalValues, "address2"));
        if (address1.Length > 0 && address2.Length == 0)
        {
            finalValues["address1"] = string.Empty;
            finalValues["address2"] = address1;
        }

        if (Normalize(GetString(finalValues, "labourRate")).Length == 0)
        {
            finalValues["labourRate"] = null;
        }

        if (Normalize(GetString(finalValues, "equipmentRate")).Length == 0)
        {
            finalValues["equipmentRate"] = null;
        }
    }

    private static async Task<IReadOnlyList<ApiFieldError>> ValidateLegacyRulesAsync(
        SqlConnection connection,
        IDbTransaction transaction,
        string book,
        string job,
        string[] changedFields,
        CurrentJobSnapshot current,
        IDictionary<string, object?> finalValues)
    {
        var errors = new List<ApiFieldError>();

        if (Normalize(GetString(finalValues, "description")).Length == 0)
        {
            errors.Add(new ApiFieldError("description", "Please enter a description."));
        }

        var concurrentCrews = Normalize(GetString(finalValues, "concurrentCrews")).ToUpperInvariant();
        if (changedFields.Contains("concurrentCrews", StringComparer.OrdinalIgnoreCase)
            && current.ConcurrentCrewMembershipsFlag.Equals("Y", StringComparison.OrdinalIgnoreCase)
            && concurrentCrews == "N")
        {
            errors.Add(new ApiFieldError(
                "concurrentCrews",
                "Changing concurrent crews from Y to N expires/deletes active crew-member rows in legacy Job Entry. That child-BO side effect must be migrated before this save is allowed."));
        }

        AddRequiredErrors(errors, finalValues);
        AddAllowedValueErrors(errors, finalValues);
        AddFormatErrors(errors, finalValues);
        AddRangeErrors(errors, finalValues);
        AddShutdownDateErrors(errors, finalValues);

        if (Normalize(GetString(finalValues, "activeFlag")).Equals("N", StringComparison.OrdinalIgnoreCase)
            && current.Commitment != 0)
        {
            errors.Add(new ApiFieldError("activeFlag", "Job cannot be inactivated if committed costs are non-zero."));
        }

        await AddLookupErrorsAsync(connection, transaction, book, job, finalValues, errors);

        var standardGlFlag = await ScalarStringAsync(
            connection,
            transaction,
            "SELECT standard_gl_flag FROM dbo.book WHERE book = @book;",
            ("@book", book));
        if (standardGlFlag.Equals("Y", StringComparison.OrdinalIgnoreCase)
            && Normalize(GetString(finalValues, "division")).Length == 0
            && await CountAsync(connection, transaction, "SELECT COUNT(1) FROM dbo.division_book WHERE book = @book;", ("@book", book)) > 0)
        {
            errors.Add(new ApiFieldError("division", $"Please add a division for job {job}."));
        }

        if (Normalize(GetString(finalValues, "dashboardGroup")).Length == 0
            && await CountAsync(connection, transaction, "SELECT COUNT(1) FROM dbo.dashboard_group;") > 0)
        {
            errors.Add(new ApiFieldError("dashboardGroup", "Dashboard Group is a required field."));
        }

        foreach (var changedField in changedFields.Where(FieldMap.ContainsKey))
        {
            var field = FieldMap[changedField];
            if (field.Type is SqlDbType.VarChar or SqlDbType.Char)
            {
                var value = Normalize(GetString(finalValues, changedField));
                if (field.Length > 0 && value.Length > field.Length)
                {
                    errors.Add(new ApiFieldError(changedField, $"{changedField} cannot exceed {field.Length} characters."));
                }
            }
        }

        return errors;
    }

    private static void AddRequiredErrors(ICollection<ApiFieldError> errors, IDictionary<string, object?> finalValues)
    {
        var requiredFields = new (string Field, string Message)[]
        {
            ("description", "Description is Required"),
            ("province", "Province is Required"),
            ("country", "Country is Required"),
            ("parentJob", "Parent_job is Required"),
            ("poUseJobAddress", "P/O Job Address is Required"),
            ("timeEntrySheetApprover", "Time entry sheet approver is Required"),
            ("shippingMessage", "Shipping message is Required"),
            ("wcbClass", "WCB Class is Required"),
            ("gstRule", "GST Rule is Required"),
            ("fixedPriceFlag", "Fixed Price Flag is Required"),
            ("disperseLabourBillings", "A/R Dispersion Flag is Required"),
            ("freezeBudget", "Freeze Budget Flag is Required"),
            ("includeStaffHours", "Include Staff Hours Flag is Required"),
            ("regHoursPerDay", "Reg hours/day is Required"),
            ("additionalHourlyAmounts", "SMTC per hour is Required"),
            ("activeFlag", "active? is Required"),
            ("concurrentCrews", "multi-job crew membership? is Required"),
            ("labourMarkupPercent", "Labour markup % is Required"),
            ("materialMarkupPercent", "Material markup % is Required")
        };

        foreach (var requiredField in requiredFields)
        {
            if (Normalize(GetString(finalValues, requiredField.Field)).Length == 0)
            {
                errors.Add(new ApiFieldError(requiredField.Field, requiredField.Message));
            }
        }
    }

    private static void AddAllowedValueErrors(ICollection<ApiFieldError> errors, IDictionary<string, object?> finalValues)
    {
        AddAllowedValueError(errors, finalValues, "activeFlag", ["Y", "N"], "Active Flag Must be Y or N");
        AddAllowedValueError(errors, finalValues, "fixedPriceFlag", ["Y", "N"], "Fixed Price Flag Must be Y or N");
        AddAllowedValueError(errors, finalValues, "freezeBudget", ["Y", "N"], "Freeze Budget Flag Must be Y or N");
        AddAllowedValueError(errors, finalValues, "includeStaffHours", ["Y", "N"], "Include Staff Hours Flag Must be Y or N");
        AddAllowedValueError(errors, finalValues, "disperseLabourBillings", ["Y", "N"], "Invoice Dispersion Flag Must be Y or N");
        AddAllowedValueError(errors, finalValues, "poUseJobAddress", ["Y", "N"], "P/O Job Address Flag Must be Y or N");
        AddAllowedValueError(errors, finalValues, "concurrentCrews", ["Y", "N"], "multi-job crew membership? Must be Y or N");
        AddAllowedValueError(errors, finalValues, "shippingMessage", ["Y", "N", "F"], "Shipping message Must be Y, N or F");
        AddAllowedValueError(errors, finalValues, "timeEntrySheetApprover", ["P", "E", "D"], "Time entry sheet approver Must be P, E or D");
    }

    private static void AddAllowedValueError(
        ICollection<ApiFieldError> errors,
        IDictionary<string, object?> finalValues,
        string field,
        IReadOnlyCollection<string> allowedValues,
        string message)
    {
        var value = Normalize(GetString(finalValues, field)).ToUpperInvariant();
        if (value.Length > 0 && !allowedValues.Contains(value))
        {
            errors.Add(new ApiFieldError(field, message));
        }
    }

    private static void AddFormatErrors(ICollection<ApiFieldError> errors, IDictionary<string, object?> finalValues)
    {
        var country = Normalize(GetString(finalValues, "country")).ToUpperInvariant();
        var postal = Normalize(GetString(finalValues, "postal")).Replace(" ", string.Empty).ToUpperInvariant();
        if (postal.Length > 0)
        {
            var validPostal = country switch
            {
                "USA" => (postal.Length == 5 || postal.Length == 9) && postal.All(char.IsDigit),
                _ => postal.Length == 6
                    && char.IsLetter(postal[0])
                    && char.IsDigit(postal[1])
                    && char.IsLetter(postal[2])
                    && char.IsDigit(postal[3])
                    && char.IsLetter(postal[4])
                    && char.IsDigit(postal[5])
            };

            if (!validPostal)
            {
                errors.Add(new ApiFieldError("postal", "Postal Code Format Must be A9A9A9 For Canada Or 99999, 999999999 For US."));
            }
        }

        AddPhoneError(errors, finalValues, "phone", "Phone Must Be 7 or 10 Digits Number");
        AddPhoneError(errors, finalValues, "fax", "Fax Must Be 7 or 10 Digits Number");
    }

    private static void AddPhoneError(
        ICollection<ApiFieldError> errors,
        IDictionary<string, object?> finalValues,
        string field,
        string message)
    {
        var value = Normalize(GetString(finalValues, field));
        if (value.Length > 0 && (!value.All(char.IsDigit) || (value.Length != 7 && value.Length != 10)))
        {
            errors.Add(new ApiFieldError(field, message));
        }
    }

    private static void AddRangeErrors(ICollection<ApiFieldError> errors, IDictionary<string, object?> finalValues)
    {
        AddDecimalRangeError(errors, finalValues, "regHoursPerDay", 7, 12, "Reg hours/day must be between 7 to 12");
        AddDecimalRangeError(errors, finalValues, "materialMarkupPercent", 0, 100, "Material markup % must be between 0 to 100");
        AddDecimalRangeError(errors, finalValues, "labourMarkupPercent", 0, 100, "Labour markup % must be between 0 to 100");
    }

    private static void AddDecimalRangeError(
        ICollection<ApiFieldError> errors,
        IDictionary<string, object?> finalValues,
        string field,
        decimal min,
        decimal max,
        string message)
    {
        var value = Normalize(GetString(finalValues, field));
        if (value.Length == 0)
        {
            return;
        }

        if (!decimal.TryParse(value, NumberStyles.Number, CultureInfo.InvariantCulture, out var decimalValue)
            || decimalValue < min
            || decimalValue > max)
        {
            errors.Add(new ApiFieldError(field, message));
        }
    }

    private static void AddShutdownDateErrors(ICollection<ApiFieldError> errors, IDictionary<string, object?> finalValues)
    {
        var hasStartDate = TryGetDateTime(finalValues, "startDate", out var startDate) && !IsLegacyBlankDate(startDate);
        var hasShutdownStart = TryGetDateTime(finalValues, "shutdownStart", out var shutdownStart) && !IsLegacyBlankDate(shutdownStart);
        var hasShutdownEnd = TryGetDateTime(finalValues, "shutdownEnd", out var shutdownEnd) && !IsLegacyBlankDate(shutdownEnd);

        if (hasStartDate && hasShutdownStart && shutdownStart.Date < startDate.Date)
        {
            errors.Add(new ApiFieldError("shutdownStart", "Shutdown start date must be after Start Date."));
        }

        if (hasShutdownStart && (shutdownStart.Date - DateTime.Today).TotalDays > 365)
        {
            errors.Add(new ApiFieldError("shutdownStart", "Shutdown start date should be within next year."));
        }

        if (hasShutdownStart && hasShutdownEnd && shutdownEnd.Date < shutdownStart.Date)
        {
            errors.Add(new ApiFieldError("shutdownEnd", "Shutdown end date must be after Shutdown start Date."));
        }

        if (hasShutdownEnd && (shutdownEnd.Date - DateTime.Today).TotalDays > 365)
        {
            errors.Add(new ApiFieldError("shutdownEnd", "Shutdown end date should be within next year."));
        }
    }

    private static async Task AddLookupErrorsAsync(
        SqlConnection connection,
        IDbTransaction transaction,
        string book,
        string job,
        IDictionary<string, object?> finalValues,
        ICollection<ApiFieldError> errors)
    {
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "province", "SELECT COUNT(1) FROM dbo.province_state WHERE province = @value;", "Province is not valid");
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "country", "SELECT COUNT(1) FROM dbo.province_state WHERE country = @value;", "Country is not valid");
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "parentJob", "SELECT COUNT(1) FROM dbo.job WHERE book = @book AND job = @value;", "Parent job is not valid", book);
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "client", "SELECT COUNT(1) FROM dbo.client WHERE book = @book AND client = @value;", "Client is not valid", book, allowBlank: true);
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "wcbClass", "SELECT COUNT(1) FROM dbo.wcb_class WHERE wcb_class = @value AND active_flag = 'Y';", "WCB Class is not valid");
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "gstRule", "SELECT COUNT(1) FROM dbo.gst_rule WHERE gst_rule = @value AND active_flag = 'Y';", "GST Rule is not valid");
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "equipmentRate", "SELECT COUNT(1) FROM dbo.equipment_rate_type WHERE equipment_rate_type = @value AND active_flag = 'Y';", "Equipment rate type is not valid", allowBlank: true);
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "labourRate", "SELECT COUNT(1) FROM dbo.labour_rate_type WHERE labour_rate_type = @value AND active_flag = 'Y';", "Labour rate type is not valid", allowBlank: true);
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "dashboardGroup", "SELECT COUNT(1) FROM dbo.dashboard_group WHERE dashboard_group = @value AND active_flag = 'Y';", "Dashboard Group is not valid");
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "division", "SELECT COUNT(1) FROM dbo.division WHERE division = @value AND active_flag = 'Y';", "Division is not valid", allowBlank: true);
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "region", "SELECT COUNT(1) FROM dbo.region WHERE region = @value AND active_flag = 'Y';", "Region is not valid", allowBlank: true);
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "jobType", "SELECT COUNT(1) FROM dbo.standard_job WHERE job_type = @value AND active_flag = 'Y';", "Job type is not valid", allowBlank: true);
        await AddLookupErrorAsync(connection, transaction, finalValues, errors, "tradeUnionGroup", "SELECT COUNT(1) FROM dbo.trade_union_group WHERE book = @book AND trade_union_group = @value AND active_flag = 'Y';", "Trade union group is not valid", book, allowBlank: true);

        var area = Normalize(GetString(finalValues, "equipmentRevenueArea"));
        if (area.Length > 0)
        {
            var areaCount = await CountAsync(
                connection,
                transaction,
                """
                SELECT COUNT(1)
                FROM dbo.area a
                WHERE a.book = @book
                  AND a.job = @job
                  AND a.area = @value
                  AND a.active_flag = 'Y';
                """,
                ("@book", book),
                ("@job", job),
                ("@value", area));
            if (areaCount == 0)
            {
                errors.Add(new ApiFieldError("equipmentRevenueArea", "Equipment revenue area is not valid"));
            }
        }

        var centre = Normalize(GetString(finalValues, "equipmentRevenueCentre"));
        if (centre.Length > 0)
        {
            var centreCount = await CountAsync(
                connection,
                transaction,
                """
                SELECT COUNT(1)
                FROM dbo.centre c
                WHERE c.book = @book
                  AND c.job = @job
                  AND c.centre = @value
                  AND (@area = '' OR c.area = @area)
                  AND c.active_flag = 'Y'
                  AND c.cost_type LIKE '%R%';
                """,
                ("@book", book),
                ("@job", job),
                ("@value", centre),
                ("@area", area));
            if (centreCount == 0)
            {
                errors.Add(new ApiFieldError("equipmentRevenueCentre", "Equipment revenue centre is not valid"));
            }
        }
    }

    private static async Task AddLookupErrorAsync(
        SqlConnection connection,
        IDbTransaction transaction,
        IDictionary<string, object?> finalValues,
        ICollection<ApiFieldError> errors,
        string field,
        string sql,
        string message,
        string? book = null,
        bool allowBlank = false)
    {
        var value = Normalize(GetString(finalValues, field));
        if (value.Length == 0)
        {
            if (!allowBlank)
            {
                return;
            }

            return;
        }

        var parameters = new List<(string Name, string Value)> { ("@value", value) };
        if (!string.IsNullOrWhiteSpace(book))
        {
            parameters.Add(("@book", book));
        }

        if (await CountAsync(connection, transaction, sql, parameters.ToArray()) == 0)
        {
            errors.Add(new ApiFieldError(field, message));
        }
    }

    private static async Task UpdateJobAsync(
        SqlConnection connection,
        IDbTransaction transaction,
        string book,
        string job,
        string[] updateFields,
        IDictionary<string, object?> finalValues)
    {
        var setClauses = new List<string>();
        await using var command = connection.CreateCommand();
        command.Transaction = (SqlTransaction)transaction;

        for (var index = 0; index < updateFields.Length; index++)
        {
            var fieldName = updateFields[index];
            var field = FieldMap[fieldName];
            var parameterName = $"@p{index}";
            setClauses.Add($"{field.ColumnName} = {parameterName}");

            var parameter = command.Parameters.Add(parameterName, field.Type);
            if (field.Length > 0)
            {
                parameter.Size = field.Length;
            }

            if (field.Precision > 0)
            {
                parameter.Precision = field.Precision;
                parameter.Scale = field.Scale;
            }

            parameter.Value = ToDbValue(finalValues, fieldName, field);
        }

        command.CommandText = $"""
            UPDATE dbo.job
            SET {string.Join(", ", setClauses)}
            WHERE book = @book
              AND job = @job;
            """;

        command.Parameters.Add("@book", SqlDbType.VarChar, 8).Value = book;
        command.Parameters.Add("@job", SqlDbType.VarChar, 6).Value = job;

        await command.ExecuteNonQueryAsync();
    }

    private static object ToDbValue(IDictionary<string, object?> values, string fieldName, JobFieldDefinition field)
    {
        if (field.Type is SqlDbType.VarChar or SqlDbType.Char)
        {
            var value = Normalize(GetString(values, fieldName));
            if (field.NullIfBlank && value.Length == 0)
            {
                return DBNull.Value;
            }

            return value;
        }

        if (field.Type == SqlDbType.DateTime)
        {
            var value = GetString(values, fieldName);
            if (Normalize(value).Length == 0)
            {
                return DBNull.Value;
            }

            if (TryGetDateTime(values, fieldName, out var dateTime))
            {
                return dateTime;
            }

            throw new InvalidOperationException($"{fieldName} is not a valid date.");
        }

        if (field.Type == SqlDbType.Decimal)
        {
            var value = GetString(values, fieldName);
            if (Normalize(value).Length == 0)
            {
                return DBNull.Value;
            }

            return Convert.ToDecimal(value, CultureInfo.InvariantCulture);
        }

        return GetString(values, fieldName);
    }

    private static string[] GetSideEffectFields(string[] changedFields, IDictionary<string, object?> finalValues)
    {
        var sideEffects = new List<string>();
        if (changedFields.Contains("clientPo", StringComparer.OrdinalIgnoreCase))
        {
            sideEffects.Add("item");
        }

        if (changedFields.Contains("equipmentRevenueArea", StringComparer.OrdinalIgnoreCase))
        {
            sideEffects.Add("equipmentRevenueCentre");
        }

        if (changedFields.Contains("province", StringComparer.OrdinalIgnoreCase)
            && !changedFields.Contains("country", StringComparer.OrdinalIgnoreCase))
        {
            sideEffects.Add("country");
        }

        if (finalValues.ContainsKey("address1"))
        {
            sideEffects.Add("address1");
        }

        if (finalValues.ContainsKey("address2"))
        {
            sideEffects.Add("address2");
        }

        return sideEffects.ToArray();
    }

    private static async Task<CurrentJobSnapshot?> LoadCurrentJobAsync(
        SqlConnection connection,
        IDbTransaction transaction,
        string book,
        string job)
    {
        const string sql = """
            SELECT TOP (1)
                file_type,
                concurrent_crew_memberships_flag,
                commitment
            FROM dbo.job
            WHERE book = @book
              AND job = @job;
            """;

        await using var command = new SqlCommand(sql, connection, (SqlTransaction)transaction);
        command.Parameters.Add("@book", SqlDbType.VarChar, 8).Value = book;
        command.Parameters.Add("@job", SqlDbType.VarChar, 6).Value = job;
        await using var reader = await command.ExecuteReaderAsync();
        if (!await reader.ReadAsync())
        {
            return null;
        }

        return new CurrentJobSnapshot(
            Normalize(reader["file_type"] as string),
            Normalize(reader["concurrent_crew_memberships_flag"] as string),
            reader["commitment"] is DBNull ? 0 : Convert.ToDecimal(reader["commitment"], CultureInfo.InvariantCulture));
    }

    private static bool TryGetProvinceCountry(SqlConnection connection, IDbTransaction transaction, string province, out string country)
    {
        using var command = new SqlCommand(
            "SELECT TOP (1) country FROM dbo.province_state WHERE province = @province;",
            connection,
            (SqlTransaction)transaction);
        command.Parameters.Add("@province", SqlDbType.VarChar, 2).Value = province;
        country = Normalize(command.ExecuteScalar() as string);
        return country.Length > 0;
    }

    private static async Task<int> CountAsync(
        SqlConnection connection,
        IDbTransaction transaction,
        string sql,
        params (string Name, string Value)[] parameters)
    {
        await using var command = new SqlCommand(sql, connection, (SqlTransaction)transaction);
        foreach (var parameter in parameters)
        {
            command.Parameters.Add(parameter.Name, SqlDbType.VarChar).Value = parameter.Value;
        }

        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }

    private static async Task<string> ScalarStringAsync(
        SqlConnection connection,
        IDbTransaction transaction,
        string sql,
        params (string Name, string Value)[] parameters)
    {
        await using var command = new SqlCommand(sql, connection, (SqlTransaction)transaction);
        foreach (var parameter in parameters)
        {
            command.Parameters.Add(parameter.Name, SqlDbType.VarChar).Value = parameter.Value;
        }

        return Normalize(await command.ExecuteScalarAsync());
    }

    private static string GetString(IDictionary<string, object?> values, string fieldName)
    {
        if (!values.TryGetValue(fieldName, out var value) || value is null)
        {
            return string.Empty;
        }

        return value switch
        {
            string text => text,
            JsonElement { ValueKind: JsonValueKind.String } element => element.GetString() ?? string.Empty,
            JsonElement { ValueKind: JsonValueKind.Number } element => element.GetRawText(),
            JsonElement { ValueKind: JsonValueKind.True } => "Y",
            JsonElement { ValueKind: JsonValueKind.False } => "N",
            JsonElement { ValueKind: JsonValueKind.Null } => string.Empty,
            DateTime dateTime => dateTime.ToString("yyyy.MM.dd", CultureInfo.InvariantCulture),
            _ => Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty
        };
    }

    private static bool TryGetDateTime(IDictionary<string, object?> values, string fieldName, out DateTime dateTime)
    {
        var text = Normalize(GetString(values, fieldName));
        if (DateTime.TryParseExact(text, "yyyy.MM.dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out dateTime))
        {
            return true;
        }

        return DateTime.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.AssumeLocal, out dateTime);
    }

    private static bool IsLegacyBlankDate(DateTime dateTime) => dateTime.Date <= new DateTime(1900, 1, 1);

    private static string[] NormalizeChangedFields(IEnumerable<string> changedFields) =>
        changedFields
            .Select(Normalize)
            .Where(field => field.Length > 0)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Order(StringComparer.OrdinalIgnoreCase)
            .ToArray();

    private static JobRecordSaveCommandResponse SavedResponse(string message, IReadOnlyList<string> changedFields) =>
        new(
            Status: "saved",
            Message: message,
            ChangedFields: changedFields,
            RequiredLegacyReferences: [],
            RequiredCommandPhases: []);

    private static IReadOnlyList<LegacyProgramReference> LegacyReferences() =>
    [
        new("jobcost.pbl", "w_jc_job.srw", "Main Job Entry window and action/event orchestration."),
        new("jobcost.pbl", "d_jc_job_detail.srd", "Details tab DataWindow validation, protect rules, dropdowns, and update behavior."),
        new("jobcost.pbl", "d_jc_job_detail_finance.srd", "Financial tab DataWindow rules and calculated/protected fields."),
        new("jobcost.pbl", "n_bo_job.sru", "Job business-object validation/defaulting/update behavior."),
        new("jobcost.pbl", "d_bo_job.srd", "Business-object DataWindow persistence behavior."),
        new("jobcost.pbl", "u_cst_jc_job_detail.sru", "Details DataWindow custom user-object logic."),
        new("jobcost.pbl", "u_cst_jc_job_detail_finance.sru", "Financial DataWindow custom user-object logic.")
    ];

    private static IReadOnlyList<string> RequiredCommandPhases() =>
    [
        "Enter edit mode using the same action enable/protect rules as w_jc_job.",
        "Run DataWindow itemchanged/validation logic for changed fields.",
        "Run program-layer pre-save validation and defaulting from n_bo_job/u_cst objects.",
        "Persist through the mapped business-object/DataWindow update path, not direct UI field patching.",
        "Run post-save refresh/audit/status behavior from the legacy window."
    ];

    private static JobFieldDefinition StringField(string column, int length, bool nullIfBlank = false) =>
        new(column, SqlDbType.VarChar, length, 0, 0, nullIfBlank);

    private static JobFieldDefinition CharField(string column, int length) =>
        new(column, SqlDbType.Char, length, 0, 0, false);

    private static JobFieldDefinition DecimalField(string column, byte precision, byte scale) =>
        new(column, SqlDbType.Decimal, 0, precision, scale, false);

    private static JobFieldDefinition DateTimeField(string column) =>
        new(column, SqlDbType.DateTime, 0, 0, 0, false);

    private static string Normalize(object? value) =>
        Convert.ToString(value, CultureInfo.InvariantCulture)?.Trim() ?? string.Empty;

    private sealed record JobFieldDefinition(
        string ColumnName,
        SqlDbType Type,
        int Length,
        byte Precision,
        byte Scale,
        bool NullIfBlank);

    private sealed record CurrentJobSnapshot(string FileType, string ConcurrentCrewMembershipsFlag, decimal Commitment);
}
