using Microsoft.Data.SqlClient;
using System.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddPolicy("LocalAngular", policy =>
    {
        policy.WithOrigins("http://localhost:4200", "http://127.0.0.1:4200")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors("LocalAngular");

var connectionString = builder.Configuration.GetConnectionString("AbioDemo")
    ?? "Server=.\\ERPLINK;Database=ABIO_DEMO;Trusted_Connection=True;TrustServerCertificate=True;";
var allowedBooks = new[] { "ISSL-LP", "MTROYAL", "MTI", "JVD" };
var today = DateOnly.FromDateTime(DateTime.UtcNow);
var currentPrPeriod = today.Year * 100 + today.Month;

app.MapGet("/api/core/config", async () =>
{
    const string sql = """
        SELECT book, description
        FROM dbo.book
        WHERE active_flag = 'Y'
        ORDER BY menu_order, book;
        """;

    var books = await QueryAsync(connectionString, sql, reader =>
        new CoreBookRow(
            reader.GetString(reader.GetOrdinal("book")),
            reader.GetString(reader.GetOrdinal("description"))));

    var defaultBook = books.FirstOrDefault(book => book.Book == "ABIODEMO")?.Book
        ?? books.FirstOrDefault()?.Book
        ?? "ABIODEMO";

    return new CoreConfigResponse(defaultBook, books);
});

app.MapGet("/api/core/menu", async (string? userId) =>
{
    var effectiveUserId = string.IsNullOrWhiteSpace(userId) ? "SHYMKVIK" : userId.Trim().ToUpperInvariant();

    const string menuSql = """
        SELECT
            program,
            description,
            menu_1 AS menu1,
            menu_2 AS menu2,
            menu_3 AS menu3,
            prompt,
            profile,
            item_type AS itemType,
            entry_session_flag AS entrySessionFlag,
            microhelp,
            help_url AS helpUrl,
            window_name AS windowName
        FROM dbo.abio_menu
        WHERE active_flag = 'Y'
          AND program <> 'menu0'
          AND menu_1 <> '*'
          AND (
              program NOT IN ('AMRPTU', 'AMLOCL', 'AMAREP')
              OR @userId IN ('MARINIJA', 'WARINGBR', 'ALEKNEGR', 'SHYMKVIK', 'PETERSMO')
          )
        ORDER BY menu_1, menu_2, menu_3, description;
        """;

    const string reportsSql = """
        SELECT
            program,
            report,
            name,
            LEFT(COALESCE(CAST(microhelp AS nvarchar(max)), ''), 500) AS microhelp,
            help_url AS helpUrl,
            datawindow_name AS datawindowName,
            LEFT(COALESCE(CAST(description AS nvarchar(max)), ''), 500) AS description
        FROM dbo.program_report
        WHERE active_flag = 'Y'
        ORDER BY program, report;
        """;

    var menuRows = await QueryMenuRowsAsync(connectionString, menuSql, effectiveUserId);
    var reportRows = await QueryReportRowsAsync(connectionString, reportsSql);
    var response = BuildMenuResponse(menuRows, reportRows);

    return response;
});

app.MapGet("/api/core/summary", async (string book) =>
{
    const string sql = """
        SELECT
            (SELECT COUNT(*) FROM dbo.client WHERE book = @book AND active_flag = 'Y') AS active_clients,
            (SELECT COUNT(*) FROM dbo.job WHERE book = @book AND active_flag = 'Y') AS active_jobs,
            (SELECT COUNT(*) FROM dbo.vendor WHERE book = @book AND active_flag = 'Y') AS active_vendors,
            (SELECT COUNT(*) FROM dbo.employee WHERE book = @book AND termination_date IS NULL) AS active_employees,
            (SELECT COUNT(*) FROM dbo.timesheet WHERE book = @book) AS timesheets,
            (SELECT COUNT(*) FROM dbo.ap_invoice WHERE book = @book) AS ap_invoice_lines,
            (SELECT COALESCE(SUM(net_purchase), 0) FROM dbo.ap_invoice WHERE book = @book) AS ap_net_purchase,
            (SELECT COUNT(*) FROM dbo.ar_invoice WHERE book = @book) AS ar_invoice_lines,
            (SELECT COALESCE(SUM(net_purchase), 0) FROM dbo.ar_invoice WHERE book = @book) AS ar_net_purchase,
            (SELECT COUNT(*) FROM dbo.gl_transaction WHERE book = @book) AS gl_transactions,
            (SELECT COALESCE(SUM(amount), 0) FROM dbo.gl_transaction WHERE book = @book) AS gl_amount,
            (SELECT COUNT(*) FROM dbo.jc_transaction WHERE book = @book) AS jc_transactions;
        """;

    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    command.Parameters.Add("@book", SqlDbType.VarChar, 8).Value = book;
    await using var reader = await command.ExecuteReaderAsync();
    await reader.ReadAsync();

    return new CoreSummaryResponse(
        ActiveClients: reader.GetInt32(reader.GetOrdinal("active_clients")),
        ActiveJobs: reader.GetInt32(reader.GetOrdinal("active_jobs")),
        ActiveVendors: reader.GetInt32(reader.GetOrdinal("active_vendors")),
        ActiveEmployees: reader.GetInt32(reader.GetOrdinal("active_employees")),
        Timesheets: reader.GetInt32(reader.GetOrdinal("timesheets")),
        ApInvoiceLines: reader.GetInt32(reader.GetOrdinal("ap_invoice_lines")),
        ApNetPurchase: reader.GetDecimal(reader.GetOrdinal("ap_net_purchase")),
        ArInvoiceLines: reader.GetInt32(reader.GetOrdinal("ar_invoice_lines")),
        ArNetPurchase: reader.GetDecimal(reader.GetOrdinal("ar_net_purchase")),
        GlTransactions: reader.GetInt32(reader.GetOrdinal("gl_transactions")),
        GlAmount: reader.GetDecimal(reader.GetOrdinal("gl_amount")),
        JcTransactions: reader.GetInt32(reader.GetOrdinal("jc_transactions")));
});

app.MapGet("/api/core/clients", async (string book) =>
{
    const string sql = """
        SELECT TOP (200)
            client AS clientId,
            name,
            city,
            province,
            active_flag AS activeFlag,
            net_out AS netOut,
            purchase,
            payment,
            last_update AS lastUpdate
        FROM dbo.client
        WHERE book = @book
        ORDER BY name, client;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryDictionaryAsync(connectionString, sql, book), 200);
});

app.MapGet("/api/core/jobs", async (string book) =>
{
    const string sql = """
        SELECT TOP (200)
            job AS jobId,
            description,
            client,
            province,
            active_flag AS activeFlag,
            job_type AS jobType,
            to_date_cost AS toDateCost,
            to_date_revenue AS toDateRevenue,
            current_budget AS currentBudget,
            (SELECT COUNT(*) FROM dbo.timesheet t WHERE t.book = dbo.job.book AND t.job = dbo.job.job) AS timesheetLines,
            (SELECT COUNT(*) FROM dbo.ap_invoice ai WHERE ai.book = dbo.job.book AND ai.job = dbo.job.job) AS apInvoiceLines,
            (SELECT COUNT(*) FROM dbo.ar_invoice ar WHERE ar.book = dbo.job.book AND ar.job = dbo.job.job) AS arInvoiceLines,
            (SELECT COUNT(*) FROM dbo.jc_transaction jt WHERE jt.book = dbo.job.book AND jt.job = dbo.job.job) AS jcTransactionLines,
            last_update AS lastUpdate
        FROM dbo.job
        WHERE book = @book
        ORDER BY active_flag DESC, job;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryDictionaryAsync(connectionString, sql, book), 200);
});

app.MapGet("/api/core/job-overview", async Task<IResult> (string book, string job) =>
{
    const string sql = """
        SELECT TOP (1)
            j.job AS jobId,
            j.description,
            j.client,
            c.name AS clientName,
            j.active_flag AS activeFlag,
            j.job_type AS jobType,
            j.start_date AS startDate,
            j.complete_date AS completeDate,
            j.current_budget AS currentBudget,
            j.to_date_cost AS toDateCost,
            j.to_date_revenue AS toDateRevenue,
            j.expected_cost AS expectedCost,
            j.expected_revenue AS expectedRevenue,
            (SELECT COUNT(*) FROM dbo.timesheet t WHERE t.book = j.book AND t.job = j.job) AS timesheetLines,
            (SELECT COALESCE(SUM(t.reg_hour + t.tah_hour + t.ovr_hour + t.travel_hour), 0) FROM dbo.timesheet t WHERE t.book = j.book AND t.job = j.job) AS timesheetHours,
            (SELECT COALESCE(SUM(t.total), 0) FROM dbo.timesheet t WHERE t.book = j.book AND t.job = j.job) AS timesheetTotal,
            (SELECT COUNT(*) FROM dbo.ap_invoice ai WHERE ai.book = j.book AND ai.job = j.job) AS apInvoiceLines,
            (SELECT COALESCE(SUM(ai.net_purchase), 0) FROM dbo.ap_invoice ai WHERE ai.book = j.book AND ai.job = j.job) AS apNetPurchase,
            (SELECT COUNT(*) FROM dbo.ar_invoice ar WHERE ar.book = j.book AND ar.job = j.job) AS arInvoiceLines,
            (SELECT COALESCE(SUM(ar.net_purchase), 0) FROM dbo.ar_invoice ar WHERE ar.book = j.book AND ar.job = j.job) AS arNetPurchase,
            (SELECT COUNT(*) FROM dbo.jc_transaction jt WHERE jt.book = j.book AND jt.job = j.job) AS jcTransactionLines,
            (SELECT COALESCE(SUM(jt.lab_amt + jt.mtl_amt + jt.equ_amt + jt.sub_amt + jt.own_amt + jt.adm_amt), 0) FROM dbo.jc_transaction jt WHERE jt.book = j.book AND jt.job = j.job) AS jcCostAmount
        FROM dbo.job j
        LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
        WHERE j.book = @book
          AND j.job = @job;
        """;

    var rows = await QueryJobDictionaryAsync(connectionString, sql, book, job);
    return rows.FirstOrDefault() is { } row
        ? Results.Ok(row)
        : Results.NotFound(new ApiErrorResponse("JOB_NOT_FOUND", "The selected job was not found.", []));
});

app.MapGet("/api/core/job-record", async Task<IResult> (string book, string job) =>
{
    const string sql = """
        SELECT TOP (1)
            j.job AS jobId,
            j.active_flag AS activeFlag,
            j.description,
            j.address_1 AS address1,
            j.address_2 AS address2,
            j.city,
            j.province,
            j.country,
            j.postal,
            j.phone,
            j.fax,
            j.client,
            c.name AS clientName,
            j.client_job AS clientJob,
            j.client_po AS clientPo,
            j.client_po_item AS item,
            j.fixed_price_flag AS fixedPriceFlag,
            j.admin_fee_percent AS adminFeePercent,
            j.invoice_dispersion_flag AS disperseLabourBillings,
            j.smtc_per_hour AS additionalHourlyAmounts,
            j.labour_surcharge_percent AS labourSurchargePercent,
            j.equipment_revenue_area AS equipmentRevenueArea,
            j.equipment_revenue_centre AS equipmentRevenueCentre,
            j.equipment_rate_type AS equipmentRate,
            j.labour_rate_type AS labourRate,
            j.labour_markup_percent AS labourMarkupPercent,
            j.material_markup_percent AS materialMarkupPercent,
            j.hbk_percent AS holdbackPercent,
            j.smtc_per_hour_label AS hourlyAmountsLabel,
            j.labour_surcharge_label AS labourSurchargeLabel,
            j.po_address_flag AS poUseJobAddress,
            j.ap_last_job_po_no AS lastJobPo,
            j.shipping_msg_type AS shippingMessage,
            j.reg_hours_per_day AS regHoursPerDay,
            j.trade_union_group AS tradeUnionGroup,
            j.wcb_class AS wcbClass,
            wcb.description AS wcbDescription,
            j.include_staff_hrs_flag AS includeStaffHours,
            j.concurrent_crew_memberships_flag AS concurrentCrews,
            j.gst_rule AS gstRule,
            gst.description AS gstDescription,
            j.timesheet_prefix AS timesheetPrefix,
            j.last_timesheet AS lastTimesheet,
            j.timesheet_sign_line AS timesheetSignLine,
            j.timesheet_message AS timesheetMessage,
            j.equipment_time_entry_sheet_approver_style AS timeEntrySheetApprover,
            j.superintendent,
            j.division,
            div.description AS divisionDescription,
            j.parent_job AS parentJob,
            j.contract_company_flag AS contractCompany,
            j.region,
            reg.description AS regionDescription,
            j.freeze_budget_flag AS freezeBudget,
            j.dashboard_group AS dashboardGroup,
            j.job_type AS jobType,
            j.site_contact AS siteContact,
            j.project_control_email_address AS siteContactEmail,
            j.contract_amount AS contractAmount,
            j.original_budget AS originalBudget,
            j.current_budget AS currentBudget,
            j.to_date_cost AS toDateCost,
            j.to_date_revenue AS toDateRevenue,
            j.to_date_payment AS toDatePayment,
            j.commitment,
            j.expected_cost AS expectedCost,
            j.expected_revenue AS expectedRevenue,
            j.year_open_cost AS yearOpenCost,
            j.period_1_cost AS period1Cost,
            j.period_2_cost AS period2Cost,
            j.period_3_cost AS period3Cost,
            j.period_4_cost AS period4Cost,
            j.period_5_cost AS period5Cost,
            j.period_6_cost AS period6Cost,
            j.period_7_cost AS period7Cost,
            j.period_8_cost AS period8Cost,
            j.period_9_cost AS period9Cost,
            j.period_10_cost AS period10Cost,
            j.period_11_cost AS period11Cost,
            j.period_12_cost AS period12Cost,
            j.year_open_revenue AS yearOpenRevenue,
            j.period_1_revenue AS period1Revenue,
            j.period_2_revenue AS period2Revenue,
            j.period_3_revenue AS period3Revenue,
            j.period_4_revenue AS period4Revenue,
            j.period_5_revenue AS period5Revenue,
            j.period_6_revenue AS period6Revenue,
            j.period_7_revenue AS period7Revenue,
            j.period_8_revenue AS period8Revenue,
            j.period_9_revenue AS period9Revenue,
            j.period_10_revenue AS period10Revenue,
            j.period_11_revenue AS period11Revenue,
            j.period_12_revenue AS period12Revenue,
            j.start_date AS startDate,
            j.complete_date AS completeDate,
            j.shutdown_start_date AS shutdownStart,
            j.shutdown_end_date AS shutdownEnd,
            j.snapshot_date AS snapshotDate,
            j.last_update AS lastUpdate,
            j.memo,
            j.file_type AS fileType,
            COALESCE((
                SELECT TOP (1) b.standard_gl_flag
                FROM dbo.book b
                WHERE b.book = j.book
            ), 'N') AS bookStandardFlag,
            (
                SELECT COUNT(1)
                FROM dbo.division_book db
                WHERE db.book = j.book
            ) AS divisionBookCount,
            (
                SELECT COUNT(1)
                FROM dbo.dashboard_group
            ) AS dashboardGroupCount,
            j.add_datetime AS addedDateTime,
            j.add_user_id AS addedBy
        FROM dbo.job j
        LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
        LEFT JOIN dbo.wcb_class wcb ON wcb.wcb_class = j.wcb_class
        LEFT JOIN dbo.gst_rule gst ON gst.gst_rule = j.gst_rule
        LEFT JOIN dbo.division div ON div.division = j.division
        LEFT JOIN dbo.region reg ON reg.region = j.region
        WHERE j.book = @book
          AND j.job = @job;
        """;

    var rows = await QueryJobDictionaryAsync(connectionString, sql, book, job);
    return rows.FirstOrDefault() is { } row
        ? Results.Ok(row)
        : Results.NotFound(new ApiErrorResponse("JOB_NOT_FOUND", "The selected job was not found.", []));
});

app.MapPut("/api/core/job-record", (JobRecordSaveCommandRequest request) =>
    JobEntryProgramLayer.SaveAsync(connectionString, request));

app.MapGet("/api/core/job-lookups", async (string book, string? job) =>
{
    var effectiveJob = Normalize(job);
    var lookups = new Dictionary<string, IReadOnlyList<CoreLookupOption>>(StringComparer.OrdinalIgnoreCase)
    {
        ["activeFlag"] = YesNoOptions(),
        ["fixedPriceFlag"] = YesNoOptions(),
        ["disperseLabourBillings"] = YesNoOptions(),
        ["poUseJobAddress"] = YesNoOptions(),
        ["includeStaffHours"] = YesNoOptions(),
        ["concurrentCrews"] = YesNoOptions(),
        ["freezeBudget"] = YesNoOptions(),
        ["contractCompany"] = YesNoOptions(),
        ["shippingMessage"] = [new("Y", "Print shipping message"), new("F", "Do not print shipping message"), new("N", "No shipping message")],
        ["timeEntrySheetApprover"] = [new("P", "Project manager"), new("E", "Equipment manager"), new("D", "Department")],
        ["province"] = await QueryLookupAsync(connectionString, """
            SELECT province AS value, CONCAT(name, ' (', country, ')') AS label
            FROM dbo.province_state
            ORDER BY province;
            """),
        ["country"] = await QueryLookupAsync(connectionString, """
            SELECT DISTINCT country AS value, country AS label
            FROM dbo.province_state
            WHERE country IS NOT NULL
            ORDER BY country;
            """),
        ["client"] = await QueryLookupAsync(connectionString, """
            SELECT client AS value, name AS label
            FROM dbo.client
            WHERE book = @book
              AND active_flag = 'Y'
            ORDER BY client;
            """, book),
        ["parentJob"] = await QueryLookupAsync(connectionString, """
            SELECT job AS value, description AS label
            FROM dbo.job
            WHERE book = @book
            ORDER BY job;
            """, book),
        ["dashboardGroup"] = await QueryLookupAsync(connectionString, """
            SELECT dashboard_group AS value, description AS label
            FROM dbo.dashboard_group
            WHERE active_flag = 'Y'
            ORDER BY dashboard_group;
            """),
        ["wcbClass"] = await QueryLookupAsync(connectionString, """
            SELECT wcb_class AS value, description AS label
            FROM dbo.wcb_class
            WHERE active_flag = 'Y'
            ORDER BY wcb_class;
            """),
        ["gstRule"] = await QueryLookupAsync(connectionString, """
            SELECT gst_rule AS value, description AS label
            FROM dbo.gst_rule
            WHERE active_flag = 'Y'
            ORDER BY gst_rule;
            """),
        ["equipmentRate"] = await QueryLookupAsync(connectionString, """
            SELECT equipment_rate_type AS value, description AS label
            FROM dbo.equipment_rate_type
            WHERE active_flag = 'Y'
            ORDER BY equipment_rate_type;
            """),
        ["labourRate"] = await QueryLookupAsync(connectionString, """
            SELECT labour_rate_type AS value, description AS label
            FROM dbo.labour_rate_type
            WHERE active_flag = 'Y'
            ORDER BY labour_rate_type;
            """),
        ["division"] = await QueryLookupAsync(connectionString, """
            SELECT d.division AS value, d.description AS label
            FROM dbo.division d
            WHERE d.active_flag = 'Y'
              AND (
                  EXISTS (
                      SELECT 1
                      FROM dbo.division_book db
                      WHERE db.book = @book
                        AND db.division = d.division
                  )
                  OR NOT EXISTS (
                      SELECT 1
                      FROM dbo.division_book db
                      WHERE db.book = @book
                  )
              )
            ORDER BY d.division;
            """, book),
        ["region"] = await QueryLookupAsync(connectionString, """
            SELECT region AS value, description AS label
            FROM dbo.region
            WHERE active_flag = 'Y'
            ORDER BY region;
            """),
        ["jobType"] = await QueryLookupAsync(connectionString, """
            SELECT DISTINCT job_type AS value, description AS label
            FROM dbo.standard_job
            WHERE active_flag = 'Y'
            ORDER BY job_type;
            """),
        ["tradeUnionGroup"] = await QueryLookupAsync(connectionString, """
            SELECT trade_union_group AS value, description AS label
            FROM dbo.trade_union_group
            WHERE book = @book
              AND active_flag = 'Y'
            ORDER BY trade_union_group;
            """, book),
        ["equipmentRevenueArea"] = effectiveJob.Length == 0
            ? []
            : await QueryLookupAsync(connectionString, """
                SELECT DISTINCT a.area AS value, a.description AS label
                FROM dbo.area a
                INNER JOIN dbo.centre c
                    ON c.book = a.book
                   AND c.job = a.job
                   AND c.area = a.area
                WHERE a.book = @book
                  AND a.job = @job
                  AND a.active_flag = 'Y'
                  AND c.active_flag = 'Y'
                  AND c.cost_type LIKE '%R%'
                ORDER BY a.area;
                """, book, effectiveJob),
        ["equipmentRevenueCentre"] = effectiveJob.Length == 0
            ? []
            : await QueryLookupAsync(connectionString, """
                SELECT DISTINCT c.centre AS value, CONCAT(c.area, ' - ', c.description) AS label
                FROM dbo.centre c
                WHERE c.book = @book
                  AND c.job = @job
                  AND c.active_flag = 'Y'
                  AND c.cost_type LIKE '%R%'
                ORDER BY c.centre;
                """, book, effectiveJob)
    };

    return new CoreLookupResponse(lookups);
});

app.MapGet("/api/core/job-report-lookups", async (string book) =>
{
    var lookups = new Dictionary<string, IReadOnlyList<CoreLookupOption>>(StringComparer.OrdinalIgnoreCase)
    {
        ["client"] = await QueryLookupAsync(connectionString, """
            SELECT j.client AS value, MIN(c.name) AS label
            FROM dbo.job j
            LEFT JOIN dbo.client c
                ON c.book = j.book
               AND c.client = j.client
            WHERE j.book = @book
              AND j.client IS NOT NULL
              AND LTRIM(RTRIM(j.client)) <> ''
            GROUP BY j.client
            ORDER BY j.client;
            """, book),
        ["jobType"] = await QueryLookupAsync(connectionString, """
            SELECT DISTINCT j.job_type AS value, COALESCE(sj.description, j.job_type) AS label
            FROM dbo.job j
            LEFT JOIN dbo.standard_job sj
                ON sj.job_type = j.job_type
            WHERE j.book = @book
              AND j.job_type IS NOT NULL
              AND LTRIM(RTRIM(j.job_type)) <> ''
            ORDER BY j.job_type;
            """, book),
        ["area"] = await QueryLookupAsync(connectionString, """
            SELECT jt.area AS value, MIN(COALESCE(a.description, jt.area)) AS label
            FROM dbo.jc_transaction jt
            LEFT JOIN dbo.area a
                ON a.book = jt.book
               AND a.job = jt.job
               AND a.area = jt.area
            WHERE jt.book = @book
              AND jt.area IS NOT NULL
              AND LTRIM(RTRIM(jt.area)) <> ''
            GROUP BY jt.area
            ORDER BY jt.area;
            """, book),
        ["centre"] = await QueryLookupAsync(connectionString, """
            SELECT jt.centre AS value, MIN(COALESCE(c.description, jt.centre)) AS label
            FROM dbo.jc_transaction jt
            LEFT JOIN dbo.centre c
                ON c.book = jt.book
               AND c.job = jt.job
               AND c.area = jt.area
               AND c.centre = jt.centre
            WHERE jt.book = @book
              AND jt.centre IS NOT NULL
              AND LTRIM(RTRIM(jt.centre)) <> ''
            GROUP BY jt.centre
            ORDER BY jt.centre;
            """, book),
        ["sourceType"] = await QueryLookupAsync(connectionString, """
            SELECT DISTINCT file_type AS value, file_type AS label
            FROM dbo.jc_transaction
            WHERE book = @book
              AND file_type IS NOT NULL
              AND LTRIM(RTRIM(file_type)) <> ''
            ORDER BY file_type;
            """, book)
    };

    return new CoreLookupResponse(lookups);
});

app.MapGet("/api/core/job-shipping", async (string book, string job) =>
{
    const string sql = """
        SELECT
            location_id AS locationId,
            display_order AS displayOrder,
            address_1 AS address1,
            address_2 AS address2,
            city,
            province,
            country,
            postal,
            contact,
            contact_phone AS contactPhone,
            active_flag AS activeFlag,
            add_user_id AS addedBy,
            add_datetime AS addedDateTime
        FROM dbo.job_shipping_info
        WHERE job = @job
        ORDER BY display_order, location_id;
        """;

    var rows = await QueryJobDictionaryAsync(connectionString, sql, book, job);
    return new GridQueryResponse<Dictionary<string, object?>>(rows, rows.Count);
});

app.MapGet("/api/core/job-checklist", async (string book, string job) =>
{
    const string sql = """
        SELECT
            jc_item AS itemNo,
            category_display_order AS categoryOrder,
            category_description AS category,
            item_display_order AS itemOrder,
            item_description AS item,
            allow_comment_flag AS allowComment,
            field_value AS value
        FROM dbo.job_checklist_item
        WHERE book = @book
          AND job = @job
        ORDER BY category_display_order, item_display_order, jc_item;
        """;

    var rows = await QueryJobDictionaryAsync(connectionString, sql, book, job);
    return new GridQueryResponse<Dictionary<string, object?>>(rows, rows.Count);
});

app.MapGet("/api/core/job-documents", async (string book, string job) =>
{
    const string sql = """
        SELECT
            document_item AS documentItem,
            segment_no AS segmentNo,
            description,
            received_datetime AS receivedDateTime,
            pdf_flag AS pdfFlag,
            add_user_id AS addedBy,
            add_datetime AS addedDateTime
        FROM dbo.job_document
        WHERE book = @book
          AND job = @job
        ORDER BY document_item, segment_no;
        """;

    var rows = await QueryJobDictionaryAsync(connectionString, sql, book, job);
    return new GridQueryResponse<Dictionary<string, object?>>(rows, rows.Count);
});

app.MapGet("/api/core/job-timesheets", async (string book, string job) =>
{
    const string sql = """
        SELECT TOP (200)
            employee,
            work_date AS workDate,
            timesheet_item AS timesheetItem,
            area,
            centre,
            trade_union AS tradeUnion,
            occupation,
            pr_yyyymm AS prPeriod,
            timesheet_status AS timesheetStatus,
            transact_flag AS transactFlag,
            reg_hour AS regHour,
            tah_hour AS tahHour,
            ovr_hour AS ovrHour,
            travel_hour AS travelHour,
            total
        FROM dbo.timesheet
        WHERE book = @book
          AND job = @job
        ORDER BY work_date DESC, employee, timesheet_item;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryJobDictionaryAsync(connectionString, sql, book, job), 200);
});

app.MapGet("/api/core/job-ap-invoices", async (string book, string job) =>
{
    const string sql = """
        SELECT TOP (200)
            vendor,
            invoice_no AS invoiceNo,
            invoice_item AS invoiceItem,
            invoice_date AS invoiceDate,
            area,
            centre,
            cost_type AS costType,
            description,
            quantity,
            rate,
            net_purchase AS netPurchase,
            net_out AS netOut,
            approval_status AS approvalStatus,
            transact_flag AS transactFlag
        FROM dbo.ap_invoice
        WHERE book = @book
          AND job = @job
        ORDER BY invoice_date DESC, invoice_no, invoice_item;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryJobDictionaryAsync(connectionString, sql, book, job), 200);
});

app.MapGet("/api/core/job-ar-invoices", async (string book, string job) =>
{
    const string sql = """
        SELECT TOP (200)
            client,
            invoice_no AS invoiceNo,
            invoice_item AS invoiceItem,
            invoice_date AS invoiceDate,
            area,
            centre,
            description,
            lab_amount AS labAmount,
            mtl_amount AS mtlAmount,
            equ_amount AS equAmount,
            sub_amount AS subAmount,
            net_purchase AS netPurchase,
            net_out AS netOut,
            transact_flag AS transactFlag
        FROM dbo.ar_invoice
        WHERE book = @book
          AND job = @job
        ORDER BY invoice_date DESC, invoice_no, invoice_item;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryJobDictionaryAsync(connectionString, sql, book, job), 200);
});

app.MapGet("/api/core/job-cost-transactions", async (string book, string job) =>
{
    const string sql = """
        SELECT TOP (200)
            activity_date AS activityDate,
            area,
            centre,
            file_type AS fileType,
            hr_amt AS hourAmount,
            lab_amt AS labourAmount,
            mtl_amt AS materialAmount,
            equ_amt AS equipmentAmount,
            sub_amt AS subcontractAmount,
            own_amt AS ownedEquipmentAmount,
            adm_amt AS adminAmount,
            lab_amt + mtl_amt + equ_amt + sub_amt + own_amt + adm_amt AS totalCost
        FROM dbo.jc_transaction
        WHERE book = @book
          AND job = @job
        ORDER BY activity_date DESC, area, centre;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryJobDictionaryAsync(connectionString, sql, book, job), 200);
});

app.MapGet("/api/core/job-report", async Task<IResult> (
    string book,
    string report,
    string? label,
    string? datawindowName,
    string? fromJob,
    string? toJob,
    string? activeFlag,
    string? client,
    string? jobType,
    string? area,
    string? centre,
    string? sourceType,
    string? activityFrom,
    string? activityTo) =>
{
    var requestFilters = new JobReportRequestFilters(
        FromJob: Normalize(fromJob),
        ToJob: Normalize(toJob),
        ActiveFlag: Normalize(activeFlag),
        Client: Normalize(client),
        JobType: Normalize(jobType),
        Area: Normalize(area),
        Centre: Normalize(centre),
        SourceType: Normalize(sourceType),
        ActivityFrom: ParseDateOnly(activityFrom),
        ActivityTo: ParseDateOnly(activityTo));
    var definition = BuildJobReportDefinition(report, label, datawindowName);
    var rows = await QueryJobReportDictionaryAsync(connectionString, definition.Sql, book, requestFilters);
    return Results.Ok(new CoreJobReportResponse(
        Title: definition.Title,
        ReportKey: Normalize(report),
        DatawindowName: Normalize(datawindowName),
        Source: definition.Source,
        Filters: BuildJobReportFilterLabels(book, label, datawindowName, definition.RowLimit, requestFilters),
        Columns: definition.Columns,
        Rows: rows,
        RowCount: rows.Count));
});

app.MapGet("/api/core/vendors", async (string book) =>
{
    const string sql = """
        SELECT TOP (200)
            vendor AS vendorId,
            name,
            city,
            province,
            active_flag AS activeFlag,
            cost_type AS costType,
            net_out AS netOut,
            purchase,
            payment,
            last_update AS lastUpdate
        FROM dbo.vendor
        WHERE book = @book
        ORDER BY name, vendor;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryDictionaryAsync(connectionString, sql, book), 200);
});

app.MapGet("/api/core/ap-invoices", async (string book) =>
{
    const string sql = """
        SELECT TOP (200)
            vendor,
            invoice_no AS invoiceNo,
            invoice_item AS invoiceItem,
            invoice_date AS invoiceDate,
            job,
            cost_type AS costType,
            description,
            net_purchase AS netPurchase,
            net_out AS netOut,
            approval_status AS approvalStatus,
            transact_flag AS transactFlag
        FROM dbo.ap_invoice
        WHERE book = @book
        ORDER BY invoice_date DESC, invoice_no, invoice_item;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryDictionaryAsync(connectionString, sql, book), 200);
});

app.MapGet("/api/core/ar-invoices", async (string book) =>
{
    const string sql = """
        SELECT TOP (200)
            client,
            invoice_no AS invoiceNo,
            invoice_item AS invoiceItem,
            invoice_date AS invoiceDate,
            job,
            description,
            lab_amount AS labAmount,
            mtl_amount AS mtlAmount,
            equ_amount AS equAmount,
            net_purchase AS netPurchase,
            net_out AS netOut,
            transact_flag AS transactFlag
        FROM dbo.ar_invoice
        WHERE book = @book
        ORDER BY invoice_date DESC, invoice_no, invoice_item;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryDictionaryAsync(connectionString, sql, book), 200);
});

app.MapGet("/api/core/timesheets", async (string book) =>
{
    const string sql = """
        SELECT TOP (200)
            employee,
            work_date AS workDate,
            timesheet_item AS timesheetItem,
            job,
            area,
            centre,
            trade_union AS tradeUnion,
            occupation,
            pr_yyyymm AS prPeriod,
            transact_flag AS transactFlag,
            reg_hour AS regHour,
            tah_hour AS tahHour,
            ovr_hour AS ovrHour,
            total
        FROM dbo.timesheet
        WHERE book = @book
        ORDER BY work_date DESC, employee, timesheet_item;
        """;

    return new GridQueryResponse<Dictionary<string, object?>>(await QueryDictionaryAsync(connectionString, sql, book), 200);
});

app.MapGet("/api/payroll/inventory", () => PayrollProgramLayer.GetInventory());

app.MapGet("/api/payroll/employees", (string book, string? search, int? limit, bool? includeHistory) =>
    PayrollProgramLayer.GetEmployeesAsync(
        connectionString,
        new PayrollListRequest(book, search, limit, includeHistory ?? false)));

app.MapGet("/api/payroll/employee-record", (string book, long employee) =>
    PayrollProgramLayer.GetEmployeeRecordAsync(connectionString, book, employee));

app.MapGet("/api/payroll/timesheets", (string book, string? search, int? limit, bool? includeHistory) =>
    PayrollProgramLayer.GetTimesheetsAsync(
        connectionString,
        new PayrollListRequest(book, search, limit, includeHistory ?? false)));

app.MapGet("/api/payroll/timesheet-record", (string book, long employee, DateTime workDate, int timesheetItem) =>
    PayrollProgramLayer.GetTimesheetRecordAsync(connectionString, book, employee, workDate, timesheetItem));

app.MapGet("/api/payroll/field-timesheets", (string book, string? search, int? limit, bool? includeHistory) =>
    PayrollProgramLayer.GetFieldTimesheetsAsync(
        connectionString,
        new PayrollListRequest(book, search, limit, includeHistory ?? false)));

app.MapGet("/api/payroll/field-timesheet-record", (string book, DateTime workDate, string addUserId, int fieldTimesheetItem) =>
    PayrollProgramLayer.GetFieldTimesheetRecordAsync(connectionString, book, workDate, addUserId, fieldTimesheetItem));

app.MapGet("/api/payroll/cheques", (string book, string? search, int? limit, bool? includeHistory) =>
    PayrollProgramLayer.GetChequesAsync(
        connectionString,
        new PayrollListRequest(book, search, limit, includeHistory ?? false)));

app.MapGet("/api/payroll/cheque-record", (string book, long chequeNo) =>
    PayrollProgramLayer.GetChequeRecordAsync(connectionString, book, chequeNo));

app.MapGet("/api/payroll/setup", (string book, string setupArea, int? limit) =>
    PayrollProgramLayer.GetSetupAsync(connectionString, book, setupArea, limit));

app.MapGet("/api/payroll/lookups", (string book) =>
    PayrollProgramLayer.GetLookupsAsync(connectionString, book));

app.MapGet("/api/payroll/validation-rules", () =>
    PayrollProgramLayer.GetValidationRules());

app.MapPost("/api/payroll/commands", (PayrollCommandRequest request) =>
    PayrollProgramLayer.ExecuteCommandAsync(connectionString, request));

app.MapGet("/api/rhumbix/config", () =>
    new RhumbixConfigResponse(
        DefaultBook: "ISSL-LP",
        AllowedBooks: allowedBooks,
        DefaultStartDate: today,
        DefaultEndDate: today,
        CurrentPrPeriod: currentPrPeriod,
        CanImportTimesheets: true,
        CanSyncProjects: true));

app.MapGet("/api/rhumbix/pending-count", (string book) =>
{
    var pendingCount = book.Equals("ISSL-LP", StringComparison.OrdinalIgnoreCase) ? 14 : 3;
    return Results.Ok(new RhumbixPendingCountResponse(book, pendingCount));
});

app.MapGet("/api/rhumbix/import-errors", () =>
    new GridQueryResponse<RhumbixImportErrorRow>(
        Rows:
        [
            new(1042, "E-10291", today.AddDays(-1), "RHX-2108", "LAB-REG", "Missing Mapping", "Cost code does not map to an active Abio labour cost code.", DateTime.UtcNow.AddMinutes(-48)),
            new(1041, "E-20411", today.AddDays(-1), "RHX-2190", "TRAVEL", "Validation", "Employee is not active for the selected book.", DateTime.UtcNow.AddMinutes(-74))
        ],
        RowCount: 2));

app.MapGet("/api/rhumbix/sync-history", (string book) =>
    new GridQueryResponse<RhumbixSyncHistoryRow>(
        Rows:
        [
            new(DateTime.UtcNow.AddHours(-3), "Project", 62, 4, 57, 1, "Failed"),
            new(DateTime.UtcNow.AddDays(-1), "Cost Code", 128, 9, 119, 0, "Success"),
            new(DateTime.UtcNow.AddDays(-2), "Project", 61, 0, 61, 0, "Success")
        ],
        RowCount: 3));

app.MapPost("/api/rhumbix/import-timesheets", (RhumbixImportTimesheetsRequest request) =>
{
    var validationErrors = ValidateImportRequest(request, allowedBooks);
    if (validationErrors.Count > 0)
    {
        return Results.BadRequest(new ApiErrorResponse("VALIDATION_FAILED", "Please correct the highlighted fields.", validationErrors));
    }

    return Results.Ok(new RhumbixImportTimesheetsResponse(
        RunId: DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
        ImportedCount: 38,
        ErrorCount: 2,
        TotalFromRhumbix: 40,
        Status: "CompletedWithErrors",
        Message: "Mock import completed with errors. Replace this handler with the stored procedure call."));
});

app.MapPost("/api/rhumbix/sync-projects", (RhumbixSyncProjectsRequest request) =>
{
    var validationErrors = ValidateBook(request.Book, allowedBooks);
    if (validationErrors.Count > 0)
    {
        return Results.BadRequest(new ApiErrorResponse("VALIDATION_FAILED", "Please correct the highlighted fields.", validationErrors));
    }

    return Results.Ok(new RhumbixSyncProjectsResponse(
        RunId: DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
        Status: "Success",
        Message: request.ForceFullSync
            ? "Mock full project sync completed."
            : "Mock pending project sync completed."));
});

app.Run();

static List<ApiFieldError> ValidateImportRequest(RhumbixImportTimesheetsRequest request, IReadOnlyCollection<string> allowedBooks)
{
    var errors = ValidateBook(request.Book, allowedBooks);

    if (request.StartDate < new DateOnly(1900, 1, 1))
    {
        errors.Add(new ApiFieldError("startDate", "Start date must be on or after 1900-01-01."));
    }

    if (request.EndDate < request.StartDate)
    {
        errors.Add(new ApiFieldError("endDate", "End date must be greater than or equal to start date."));
    }

    if (request.PrPeriod is < 190001 or > 999912)
    {
        errors.Add(new ApiFieldError("prPeriod", "PR period must be in YYYYMM format."));
    }

    return errors;
}

static List<ApiFieldError> ValidateBook(string book, IReadOnlyCollection<string> allowedBooks)
{
    var errors = new List<ApiFieldError>();
    if (string.IsNullOrWhiteSpace(book))
    {
        errors.Add(new ApiFieldError("book", "Book is required."));
        return errors;
    }

    if (!allowedBooks.Contains(book, StringComparer.OrdinalIgnoreCase))
    {
        errors.Add(new ApiFieldError("book", "Book is not available to the current user."));
    }

    return errors;
}

static JobReportDefinition BuildJobReportDefinition(string report, string? label, string? datawindowName)
{
    var normalizedLabel = FirstNonBlank(label, report, datawindowName, "Job Report");
    var key = $"{report} {label} {datawindowName}".ToLowerInvariant();
    var datawindow = Normalize(datawindowName).ToLowerInvariant();
    const int rowLimit = 500;

    bool IsDataWindow(string name) => datawindow.Equals(name, StringComparison.OrdinalIgnoreCase);

    if (IsDataWindow("d_report_job_cash_position") || key.Contains("cash"))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from d_report_job_cash_position.srd; layout columns follow the exported Job Costing DataWindow.",
            rowLimit,
            JobCashPositionColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                c.name AS clientName,
                j.active_flag AS activeFlag,
                j.to_date_cost AS toDateCost,
                j.to_date_revenue AS toDateRevenue,
                j.to_date_payment AS toDatePayment,
                j.to_date_revenue - j.to_date_payment AS receivablePosition,
                j.to_date_payment - j.to_date_cost AS cashPosition,
                j.current_budget AS currentBudget
            FROM dbo.job j
            LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
            ORDER BY ABS(j.to_date_payment - j.to_date_cost) DESC, j.job;
            """);
    }

    if (IsDataWindow("d_report_job_over_under_billings") || key.Contains("over") || key.Contains("under"))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job Over/Under Billings report intent; billing variance derived from job cost/revenue totals.",
            rowLimit,
            JobOverUnderColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                c.name AS clientName,
                j.active_flag AS activeFlag,
                j.to_date_cost AS toDateCost,
                j.to_date_revenue AS toDateRevenue,
                j.to_date_revenue - j.to_date_cost AS overUnderBilling,
                CASE
                    WHEN j.to_date_revenue - j.to_date_cost > 0 THEN 'Over'
                    WHEN j.to_date_revenue - j.to_date_cost < 0 THEN 'Under'
                    ELSE 'Even'
                END AS billingPosition,
                j.current_budget AS currentBudget
            FROM dbo.job j
            LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
            ORDER BY ABS(j.to_date_revenue - j.to_date_cost) DESC, j.job;
            """);
    }

    if (IsDataWindow("d_report_job_first_6_months") || (key.Contains("first") && key.Contains("6")))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job First 6 Months report intent using job period columns 1-6.",
            rowLimit,
            JobFirstSixColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                j.active_flag AS activeFlag,
                j.period_1_cost AS period1Cost,
                j.period_2_cost AS period2Cost,
                j.period_3_cost AS period3Cost,
                j.period_4_cost AS period4Cost,
                j.period_5_cost AS period5Cost,
                j.period_6_cost AS period6Cost,
                j.period_1_revenue AS period1Revenue,
                j.period_2_revenue AS period2Revenue,
                j.period_3_revenue AS period3Revenue,
                j.period_4_revenue AS period4Revenue,
                j.period_5_revenue AS period5Revenue,
                j.period_6_revenue AS period6Revenue
            FROM dbo.job j
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
            ORDER BY j.job;
            """);
    }

    if (IsDataWindow("d_report_job_last_6_months") || (key.Contains("last") && key.Contains("6")))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job Last 6 Months report intent using job period columns 7-12.",
            rowLimit,
            JobLastSixColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                j.active_flag AS activeFlag,
                j.period_7_cost AS period7Cost,
                j.period_8_cost AS period8Cost,
                j.period_9_cost AS period9Cost,
                j.period_10_cost AS period10Cost,
                j.period_11_cost AS period11Cost,
                j.period_12_cost AS period12Cost,
                j.period_7_revenue AS period7Revenue,
                j.period_8_revenue AS period8Revenue,
                j.period_9_revenue AS period9Revenue,
                j.period_10_revenue AS period10Revenue,
                j.period_11_revenue AS period11Revenue,
                j.period_12_revenue AS period12Revenue
            FROM dbo.job j
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
            ORDER BY j.job;
            """);
    }

    if (IsDataWindow("d_report_job_profit_accrual") || key.Contains("profit") || key.Contains("accrual"))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job Profit Accrual report intent using expected/to-date cost and revenue.",
            rowLimit,
            JobProfitAccrualColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                c.name AS clientName,
                j.active_flag AS activeFlag,
                j.to_date_cost AS toDateCost,
                j.to_date_revenue AS toDateRevenue,
                j.expected_cost AS expectedCost,
                j.expected_revenue AS expectedRevenue,
                j.expected_revenue - j.expected_cost AS expectedProfit,
                j.to_date_revenue - j.to_date_cost AS toDateProfit,
                (j.expected_revenue - j.expected_cost) - (j.to_date_revenue - j.to_date_cost) AS accrualVariance
            FROM dbo.job j
            LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
            ORDER BY ABS((j.expected_revenue - j.expected_cost) - (j.to_date_revenue - j.to_date_cost)) DESC, j.job;
            """);
    }

    if (IsDataWindow("d_report_job_recent_activity") || key.Contains("recent") || key.Contains("activity"))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job Recent Activity report intent using latest activity across J/C, A/P, A/R, and timesheets.",
            rowLimit,
            JobRecentActivityColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                c.name AS clientName,
                j.active_flag AS activeFlag,
                activity.lastJobCostActivity,
                activity.lastApInvoiceDate,
                activity.lastArInvoiceDate,
                activity.lastTimesheetDate,
                j.last_update AS jobLastUpdate
            FROM dbo.job j
            LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
            OUTER APPLY (
                SELECT
                    (SELECT MAX(jt.activity_date) FROM dbo.jc_transaction jt WHERE jt.book = j.book AND jt.job = j.job) AS lastJobCostActivity,
                    (SELECT MAX(ai.invoice_date) FROM dbo.ap_invoice ai WHERE ai.book = j.book AND ai.job = j.job) AS lastApInvoiceDate,
                    (SELECT MAX(ar.invoice_date) FROM dbo.ar_invoice ar WHERE ar.book = j.book AND ar.job = j.job) AS lastArInvoiceDate,
                    (SELECT MAX(t.work_date) FROM dbo.timesheet t WHERE t.book = j.book AND t.job = j.job) AS lastTimesheetDate
            ) activity
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
              AND (@activityFrom IS NULL OR COALESCE(activity.lastJobCostActivity, activity.lastApInvoiceDate, activity.lastArInvoiceDate, activity.lastTimesheetDate, j.last_update) >= @activityFrom)
              AND (@activityTo IS NULL OR COALESCE(activity.lastJobCostActivity, activity.lastApInvoiceDate, activity.lastArInvoiceDate, activity.lastTimesheetDate, j.last_update) <= @activityTo)
            ORDER BY COALESCE(activity.lastJobCostActivity, activity.lastApInvoiceDate, activity.lastArInvoiceDate, activity.lastTimesheetDate, j.last_update) DESC, j.job;
            """);
    }

    if (IsDataWindow("d_report_jc_centre_to_src_comp_revenue") || IsDataWindow("d_report_jc_centre_to_src_comp_cost") || ((key.Contains("centre") || key.Contains("center") || key.Contains("source")) && !key.Contains("transaction")))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Centre to Source Comparison report intent using J/C transaction centre/source totals.",
            rowLimit,
            CentreToSourceColumns(),
            """
            SELECT TOP (500)
                jt.job AS jobId,
                j.description AS jobDescription,
                jt.area,
                jt.centre,
                jt.file_type AS sourceType,
                COUNT(*) AS transactionCount,
                SUM(jt.hr_amt) AS hourAmount,
                SUM(jt.lab_amt) AS labourAmount,
                SUM(jt.mtl_amt) AS materialAmount,
                SUM(jt.equ_amt) AS equipmentAmount,
                SUM(jt.sub_amt) AS subcontractAmount,
                SUM(jt.own_amt) AS ownedEquipmentAmount,
                SUM(jt.adm_amt) AS adminAmount,
                SUM(jt.lab_amt + jt.mtl_amt + jt.equ_amt + jt.sub_amt + jt.own_amt + jt.adm_amt) AS totalCost
            FROM dbo.jc_transaction jt
            INNER JOIN dbo.job j ON j.book = jt.book AND j.job = jt.job
            WHERE jt.book = @book
              AND (@fromJob = '' OR jt.job >= @fromJob)
              AND (@toJob = '' OR jt.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
              AND (@area = '' OR jt.area = @area)
              AND (@centre = '' OR jt.centre = @centre)
              AND (@sourceType = '' OR jt.file_type = @sourceType)
              AND (@activityFrom IS NULL OR jt.activity_date >= @activityFrom)
              AND (@activityTo IS NULL OR jt.activity_date <= @activityTo)
            GROUP BY jt.job, j.description, jt.area, jt.centre, jt.file_type
            ORDER BY jt.job, jt.area, jt.centre, jt.file_type;
            """);
    }

    if (IsDataWindow("d_report_jc_centre_to_transaction_comp") || key.Contains("transaction") || key.Contains("comparison"))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job Cost Transaction Comparison report intent using J/C transaction cost buckets.",
            rowLimit,
            TransactionComparisonColumns(),
            """
            SELECT TOP (500)
                jt.job AS jobId,
                j.description AS jobDescription,
                jt.file_type AS sourceType,
                COUNT(*) AS transactionCount,
                MIN(jt.activity_date) AS firstActivityDate,
                MAX(jt.activity_date) AS lastActivityDate,
                SUM(jt.lab_amt) AS labourAmount,
                SUM(jt.mtl_amt) AS materialAmount,
                SUM(jt.equ_amt) AS equipmentAmount,
                SUM(jt.sub_amt) AS subcontractAmount,
                SUM(jt.own_amt) AS ownedEquipmentAmount,
                SUM(jt.adm_amt) AS adminAmount,
                SUM(jt.lab_amt + jt.mtl_amt + jt.equ_amt + jt.sub_amt + jt.own_amt + jt.adm_amt) AS totalCost
            FROM dbo.jc_transaction jt
            INNER JOIN dbo.job j ON j.book = jt.book AND j.job = jt.job
            WHERE jt.book = @book
              AND (@fromJob = '' OR jt.job >= @fromJob)
              AND (@toJob = '' OR jt.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
              AND (@area = '' OR jt.area = @area)
              AND (@centre = '' OR jt.centre = @centre)
              AND (@sourceType = '' OR jt.file_type = @sourceType)
              AND (@activityFrom IS NULL OR jt.activity_date >= @activityFrom)
              AND (@activityTo IS NULL OR jt.activity_date <= @activityTo)
            GROUP BY jt.job, j.description, jt.file_type
            ORDER BY jt.job, jt.file_type;
            """);
    }

    if (IsDataWindow("d_report_jc_job_cost_and_revenue") || (key.Contains("cost") && key.Contains("revenue")))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job Costs and Revenue report intent using job financial totals.",
            rowLimit,
            JobCostRevenueColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                c.name AS clientName,
                j.active_flag AS activeFlag,
                j.current_budget AS currentBudget,
                j.to_date_cost AS toDateCost,
                j.to_date_revenue AS toDateRevenue,
                j.to_date_payment AS toDatePayment,
                j.expected_cost AS expectedCost,
                j.expected_revenue AS expectedRevenue,
                j.to_date_revenue - j.to_date_cost AS toDateMargin,
                j.expected_revenue - j.expected_cost AS expectedMargin
            FROM dbo.job j
            LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
            ORDER BY j.job;
            """);
    }

    if (IsDataWindow("d_report_job_status") || key.Contains("status"))
    {
        return new JobReportDefinition(
            normalizedLabel,
            "Migrated from Legacy Job Status report intent using job master status and financial fields.",
            rowLimit,
            JobStatusColumns(),
            """
            SELECT TOP (500)
                j.job AS jobId,
                j.description,
                j.client,
                c.name AS clientName,
                j.active_flag AS activeFlag,
                j.job_type AS jobType,
                j.start_date AS startDate,
                j.complete_date AS completeDate,
                j.current_budget AS currentBudget,
                j.to_date_cost AS toDateCost,
                j.to_date_revenue AS toDateRevenue,
                j.expected_cost AS expectedCost,
                j.expected_revenue AS expectedRevenue,
                j.last_update AS lastUpdate
            FROM dbo.job j
            LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
            WHERE j.book = @book
              AND (@fromJob = '' OR j.job >= @fromJob)
              AND (@toJob = '' OR j.job <= @toJob)
              AND (@activeFlag = '' OR j.active_flag = @activeFlag)
              AND (@client = '' OR j.client = @client)
              AND (@jobType = '' OR j.job_type = @jobType)
            ORDER BY j.active_flag DESC, j.job;
            """);
    }

    return new JobReportDefinition(
        normalizedLabel,
        "Migrated from Legacy Job List report intent using the job master list layout.",
        rowLimit,
        JobListColumns(),
        """
        SELECT TOP (500)
            j.job AS jobId,
            j.description,
            j.client,
            c.name AS clientName,
            j.province,
            j.active_flag AS activeFlag,
            j.job_type AS jobType,
            j.start_date AS startDate,
            j.complete_date AS completeDate,
            j.current_budget AS currentBudget,
            j.to_date_cost AS toDateCost,
            j.to_date_revenue AS toDateRevenue,
            j.last_update AS lastUpdate
        FROM dbo.job j
        LEFT JOIN dbo.client c ON c.book = j.book AND c.client = j.client
        WHERE j.book = @book
          AND (@fromJob = '' OR j.job >= @fromJob)
          AND (@toJob = '' OR j.job <= @toJob)
          AND (@activeFlag = '' OR j.active_flag = @activeFlag)
          AND (@client = '' OR j.client = @client)
          AND (@jobType = '' OR j.job_type = @jobType)
        ORDER BY j.active_flag DESC, j.job;
        """);
}

static IReadOnlyList<CoreJobReportColumn> JobListColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 260),
    Col("client", "Client", 110),
    Col("clientName", "Client Name", 190),
    Col("activeFlag", "Active", 90),
    Col("jobType", "Job Type", 120),
    Col("province", "Province", 100),
    Col("startDate", "Start Date", 125),
    Col("lastUpdate", "Last Update", 125),
    Col("currentBudget", "Current Budget", 145, true),
    Col("toDateCost", "To Date Cost", 140, true),
    Col("toDateRevenue", "To Date Revenue", 155, true)
];

static IReadOnlyList<CoreJobReportColumn> JobStatusColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 260),
    Col("client", "Client", 110),
    Col("clientName", "Client Name", 190),
    Col("activeFlag", "Active", 90),
    Col("jobType", "Job Type", 120),
    Col("startDate", "Start Date", 125),
    Col("completeDate", "Complete Date", 135),
    Col("currentBudget", "Current Budget", 145, true),
    Col("toDateCost", "To Date Cost", 140, true),
    Col("toDateRevenue", "To Date Revenue", 155, true),
    Col("expectedCost", "Expected Cost", 145, true),
    Col("expectedRevenue", "Expected Revenue", 160, true),
    Col("lastUpdate", "Last Update", 125)
];

static IReadOnlyList<CoreJobReportColumn> JobCashPositionColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 280),
    Col("toDateCost", "To Date Cost", 140, true),
    Col("toDateRevenue", "To Date Revenue", 155, true),
    Col("toDatePayment", "To Date Payment", 155, true),
    Col("receivablePosition", "Receivable Position", 165, true),
    Col("cashPosition", "Cash Position", 150, true),
    Col("currentBudget", "Current Budget", 145, true)
];

static IReadOnlyList<CoreJobReportColumn> JobOverUnderColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 280),
    Col("toDateCost", "To Date Cost", 140, true),
    Col("toDateRevenue", "To Date Revenue", 155, true),
    Col("overUnderBilling", "Over/Under", 145, true),
    Col("billingPosition", "Position", 110),
    Col("currentBudget", "Current Budget", 145, true)
];

static IReadOnlyList<CoreJobReportColumn> JobFirstSixColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 260),
    Col("period1Revenue", "Revenue Month 1", 155, true),
    Col("period2Revenue", "Revenue Month 2", 155, true),
    Col("period3Revenue", "Revenue Month 3", 155, true),
    Col("period4Revenue", "Revenue Month 4", 155, true),
    Col("period5Revenue", "Revenue Month 5", 155, true),
    Col("period6Revenue", "Revenue Month 6", 155, true),
    Col("period1Cost", "Cost Month 1", 145, true),
    Col("period2Cost", "Cost Month 2", 145, true),
    Col("period3Cost", "Cost Month 3", 145, true),
    Col("period4Cost", "Cost Month 4", 145, true),
    Col("period5Cost", "Cost Month 5", 145, true),
    Col("period6Cost", "Cost Month 6", 145, true)
];

static IReadOnlyList<CoreJobReportColumn> JobLastSixColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 260),
    Col("period7Revenue", "Revenue Month 7", 155, true),
    Col("period8Revenue", "Revenue Month 8", 155, true),
    Col("period9Revenue", "Revenue Month 9", 155, true),
    Col("period10Revenue", "Revenue Month 10", 165, true),
    Col("period11Revenue", "Revenue Month 11", 165, true),
    Col("period12Revenue", "Revenue Month 12", 165, true),
    Col("period7Cost", "Cost Month 7", 145, true),
    Col("period8Cost", "Cost Month 8", 145, true),
    Col("period9Cost", "Cost Month 9", 145, true),
    Col("period10Cost", "Cost Month 10", 155, true),
    Col("period11Cost", "Cost Month 11", 155, true),
    Col("period12Cost", "Cost Month 12", 155, true)
];

static IReadOnlyList<CoreJobReportColumn> JobProfitAccrualColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 280),
    Col("expectedRevenue", "Expected Revenue", 160, true),
    Col("expectedCost", "Expected Cost", 145, true),
    Col("expectedProfit", "Expected Profit", 150, true),
    Col("toDateRevenue", "To Date Revenue", 155, true),
    Col("toDateCost", "To Date Cost", 140, true),
    Col("toDateProfit", "To Date Profit", 145, true),
    Col("accrualVariance", "Accrual Variance", 160, true)
];

static IReadOnlyList<CoreJobReportColumn> JobRecentActivityColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 280),
    Col("activeFlag", "Active", 90),
    Col("lastJobCostActivity", "J/C Activity", 135),
    Col("lastApInvoiceDate", "A/P Invoice", 135),
    Col("lastArInvoiceDate", "A/R Invoice", 135),
    Col("lastTimesheetDate", "Labour", 135),
    Col("jobLastUpdate", "Job Costing", 135)
];

static IReadOnlyList<CoreJobReportColumn> CentreToSourceColumns() =>
[
    Col("jobId", "Job", 110),
    Col("jobDescription", "Job Description", 250),
    Col("area", "Area", 100),
    Col("centre", "Centre", 110),
    Col("sourceType", "Source", 100),
    Col("transactionCount", "Transactions", 125, true),
    Col("hourAmount", "Hours", 115, true),
    Col("labourAmount", "Labour", 125, true),
    Col("materialAmount", "Material", 125, true),
    Col("equipmentAmount", "Equipment", 135, true),
    Col("subcontractAmount", "Subs", 125, true),
    Col("totalCost", "Total Cost", 140, true)
];

static IReadOnlyList<CoreJobReportColumn> TransactionComparisonColumns() =>
[
    Col("jobId", "Job", 110),
    Col("jobDescription", "Job Description", 250),
    Col("sourceType", "Source", 100),
    Col("transactionCount", "Transactions", 125, true),
    Col("firstActivityDate", "First Activity", 135),
    Col("lastActivityDate", "Last Activity", 135),
    Col("labourAmount", "Labour", 125, true),
    Col("materialAmount", "Material", 125, true),
    Col("equipmentAmount", "Equipment", 135, true),
    Col("subcontractAmount", "Subs", 125, true),
    Col("totalCost", "Total Cost", 140, true)
];

static IReadOnlyList<CoreJobReportColumn> JobCostRevenueColumns() =>
[
    Col("jobId", "Job", 110),
    Col("description", "Description", 260),
    Col("client", "Client", 110),
    Col("clientName", "Client Name", 190),
    Col("currentBudget", "Current Budget", 145, true),
    Col("toDateCost", "Cost Total", 135, true),
    Col("toDateRevenue", "Revenue Total", 145, true),
    Col("toDatePayment", "Payment", 135, true),
    Col("expectedCost", "Expected Cost", 145, true),
    Col("expectedRevenue", "Expected Revenue", 160, true),
    Col("toDateMargin", "To Date Margin", 150, true),
    Col("expectedMargin", "Expected Margin", 155, true)
];

static CoreJobReportColumn Col(string field, string headerName, int width, bool numeric = false) =>
    new(field, headerName, width, numeric);

static async Task<IReadOnlyList<CoreLookupOption>> QueryLookupAsync(string connectionString, string sql, string? book = null, string? job = null)
{
    var rows = new List<CoreLookupOption>();
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    if (!string.IsNullOrWhiteSpace(book))
    {
        command.Parameters.Add("@book", SqlDbType.VarChar, 8).Value = book;
    }

    if (!string.IsNullOrWhiteSpace(job))
    {
        command.Parameters.Add("@job", SqlDbType.VarChar, 12).Value = job;
    }

    await using var reader = await command.ExecuteReaderAsync();
    while (await reader.ReadAsync())
    {
        rows.Add(new CoreLookupOption(ReadString(reader, "value"), ReadString(reader, "label")));
    }

    return rows;
}

static IReadOnlyList<CoreLookupOption> YesNoOptions() =>
[
    new("Y", "Yes"),
    new("N", "No")
];

static async Task<List<T>> QueryAsync<T>(string connectionString, string sql, Func<SqlDataReader, T> map)
{
    var rows = new List<T>();
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        rows.Add(map(reader));
    }

    return rows;
}

static async Task<List<Dictionary<string, object?>>> QueryDictionaryAsync(string connectionString, string sql, string book)
{
    var rows = new List<Dictionary<string, object?>>();
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    command.Parameters.Add("@book", SqlDbType.VarChar, 8).Value = book;
    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < reader.FieldCount; i++)
        {
            row[reader.GetName(i)] = await reader.IsDBNullAsync(i) ? null : reader.GetValue(i);
        }

        rows.Add(row);
    }

    return rows;
}

static async Task<List<Dictionary<string, object?>>> QueryJobReportDictionaryAsync(
    string connectionString,
    string sql,
    string book,
    JobReportRequestFilters filters)
{
    var rows = new List<Dictionary<string, object?>>();
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    command.Parameters.Add("@book", SqlDbType.VarChar, 8).Value = book;
    command.Parameters.Add("@fromJob", SqlDbType.VarChar, 12).Value = filters.FromJob;
    command.Parameters.Add("@toJob", SqlDbType.VarChar, 12).Value = filters.ToJob;
    command.Parameters.Add("@activeFlag", SqlDbType.VarChar, 1).Value = filters.ActiveFlag;
    command.Parameters.Add("@client", SqlDbType.VarChar, 12).Value = filters.Client;
    command.Parameters.Add("@jobType", SqlDbType.VarChar, 20).Value = filters.JobType;
    command.Parameters.Add("@area", SqlDbType.VarChar, 12).Value = filters.Area;
    command.Parameters.Add("@centre", SqlDbType.VarChar, 12).Value = filters.Centre;
    command.Parameters.Add("@sourceType", SqlDbType.VarChar, 12).Value = filters.SourceType;
    command.Parameters.Add("@activityFrom", SqlDbType.Date).Value = filters.ActivityFrom is null
        ? DBNull.Value
        : filters.ActivityFrom.Value.ToDateTime(TimeOnly.MinValue);
    command.Parameters.Add("@activityTo", SqlDbType.Date).Value = filters.ActivityTo is null
        ? DBNull.Value
        : filters.ActivityTo.Value.ToDateTime(TimeOnly.MinValue);
    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < reader.FieldCount; i++)
        {
            row[reader.GetName(i)] = await reader.IsDBNullAsync(i) ? null : reader.GetValue(i);
        }

        rows.Add(row);
    }

    return rows;
}

static async Task<List<Dictionary<string, object?>>> QueryJobDictionaryAsync(string connectionString, string sql, string book, string job)
{
    var rows = new List<Dictionary<string, object?>>();
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    command.Parameters.Add("@book", SqlDbType.VarChar, 8).Value = book;
    command.Parameters.Add("@job", SqlDbType.VarChar, 12).Value = job;
    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < reader.FieldCount; i++)
        {
            row[reader.GetName(i)] = await reader.IsDBNullAsync(i) ? null : reader.GetValue(i);
        }

        rows.Add(row);
    }

    return rows;
}

static async Task<List<AbioMenuRow>> QueryMenuRowsAsync(string connectionString, string sql, string userId)
{
    var rows = new List<AbioMenuRow>();
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    command.Parameters.Add("@userId", SqlDbType.VarChar, 8).Value = userId;
    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        rows.Add(new AbioMenuRow(
            Program: ReadString(reader, "program"),
            Description: ReadString(reader, "description"),
            Menu1: ReadString(reader, "menu1"),
            Menu2: ReadString(reader, "menu2"),
            Menu3: ReadString(reader, "menu3"),
            Prompt: ReadString(reader, "prompt"),
            Profile: ReadString(reader, "profile"),
            ItemType: ReadString(reader, "itemType"),
            EntrySessionFlag: ReadString(reader, "entrySessionFlag"),
            Microhelp: ReadString(reader, "microhelp"),
            HelpUrl: ReadString(reader, "helpUrl"),
            WindowName: ReadString(reader, "windowName")));
    }

    return rows;
}

static async Task<List<ProgramReportRow>> QueryReportRowsAsync(string connectionString, string sql)
{
    var rows = new List<ProgramReportRow>();
    await using var connection = new SqlConnection(connectionString);
    await connection.OpenAsync();
    await using var command = new SqlCommand(sql, connection);
    await using var reader = await command.ExecuteReaderAsync();

    while (await reader.ReadAsync())
    {
        rows.Add(new ProgramReportRow(
            Program: ReadString(reader, "program"),
            Report: ReadString(reader, "report"),
            Name: ReadString(reader, "name"),
            Microhelp: ReadString(reader, "microhelp"),
            HelpUrl: ReadString(reader, "helpUrl"),
            DatawindowName: ReadString(reader, "datawindowName"),
            Description: ReadString(reader, "description")));
    }

    return rows;
}

static CoreMenuResponse BuildMenuResponse(IReadOnlyList<AbioMenuRow> menuRows, IReadOnlyList<ProgramReportRow> reportRows)
{
    var reportsByProgram = reportRows
        .GroupBy(report => Normalize(report.Program), StringComparer.OrdinalIgnoreCase)
        .ToDictionary(group => group.Key, group => group.ToList(), StringComparer.OrdinalIgnoreCase);

    var modules = new List<CoreMenuNode>();
    foreach (var moduleGroup in menuRows.GroupBy(row => Normalize(row.Menu1)).OrderBy(group => group.Key))
    {
        var moduleRow = moduleGroup.FirstOrDefault(row => IsBlank(row.Menu2) && IsBlank(row.Menu3) && IsType(row, "menu"))
            ?? moduleGroup.First();

        var childRows = moduleGroup
            .Where(row => !ReferenceEquals(row, moduleRow) && !IsBlank(row.Menu2))
            .GroupBy(row => Normalize(row.Menu2))
            .OrderBy(group => group.Key);

        var children = new List<CoreMenuNode>();
        foreach (var childGroup in childRows)
        {
            var parentRow = childGroup.FirstOrDefault(row => IsBlank(row.Menu3)) ?? childGroup.First();
            var nestedChildren = childGroup
                .Where(row => !ReferenceEquals(row, parentRow) && !IsBlank(row.Menu3))
                .OrderBy(row => Normalize(row.Menu3))
                .Select(row => ToMenuNode(row, [], reportsByProgram))
                .ToList();

            children.Add(ToMenuNode(parentRow, nestedChildren, reportsByProgram));
        }

        modules.Add(ToMenuNode(moduleRow, children, reportsByProgram));
    }

    return new CoreMenuResponse(modules, menuRows.Count, reportRows.Count);
}

static CoreMenuNode ToMenuNode(AbioMenuRow row, IReadOnlyList<CoreMenuNode> children, IReadOnlyDictionary<string, List<ProgramReportRow>> reportsByProgram)
{
    var nodeChildren = children.ToList();
    var normalizedProgram = Normalize(row.Program);
    if (IsReportMenu(row) && reportsByProgram.TryGetValue(normalizedProgram, out var reports))
    {
        nodeChildren.AddRange(reports.Select(report => ToReportNode(row, report)));
    }

    return new CoreMenuNode(
        Key: BuildMenuKey(row),
        Program: Normalize(row.Program),
        Label: FirstNonBlank(row.Prompt, row.Description, row.Program),
        Description: Normalize(row.Description),
        ItemType: Normalize(row.ItemType),
        Profile: Normalize(row.Profile),
        EntrySessionFlag: Normalize(row.EntrySessionFlag),
        Microhelp: Normalize(row.Microhelp),
        HelpUrl: Normalize(row.HelpUrl),
        WindowName: Normalize(row.WindowName),
        Menu1: Normalize(row.Menu1),
        Menu2: Normalize(row.Menu2),
        Menu3: Normalize(row.Menu3),
        Children: nodeChildren);
}

static CoreMenuNode ToReportNode(AbioMenuRow parentRow, ProgramReportRow row) =>
    new(
        Key: $"report:{Normalize(row.Program)}:{Normalize(row.Report)}",
        Program: Normalize(row.Program),
        Label: FirstNonBlank(row.Name, row.Report),
        Description: Normalize(row.Description),
        ItemType: "report",
        Profile: "",
        EntrySessionFlag: "N",
        Microhelp: Normalize(row.Microhelp),
        HelpUrl: Normalize(row.HelpUrl),
        WindowName: Normalize(row.DatawindowName),
        Menu1: Normalize(parentRow.Menu1),
        Menu2: Normalize(parentRow.Menu2),
        Menu3: Normalize(row.Report),
        Children: []);

static string ReadString(SqlDataReader reader, string name)
{
    var ordinal = reader.GetOrdinal(name);
    return reader.IsDBNull(ordinal) ? string.Empty : Convert.ToString(reader.GetValue(ordinal))?.Trim() ?? string.Empty;
}

static bool IsBlank(string value) => string.IsNullOrWhiteSpace(value);

static bool IsType(AbioMenuRow row, string itemType) => Normalize(row.ItemType).Equals(itemType, StringComparison.OrdinalIgnoreCase);

static bool IsReportMenu(AbioMenuRow row) => Normalize(row.ItemType).Equals("report menu", StringComparison.OrdinalIgnoreCase);

static string Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? string.Empty : value.Trim();

static string FirstNonBlank(params string?[] values) => values.Select(Normalize).FirstOrDefault(value => value.Length > 0) ?? string.Empty;

static DateOnly? ParseDateOnly(string? value)
{
    return DateOnly.TryParse(value, out var parsed) ? parsed : null;
}

static IReadOnlyList<string> BuildJobReportFilterLabels(
    string book,
    string? label,
    string? datawindowName,
    int rowLimit,
    JobReportRequestFilters filters)
{
    var labels = new List<string>
    {
        $"book = {book}",
        $"legacy report = {Normalize(label)}"
    };

    if (filters.FromJob.Length > 0)
    {
        labels.Add($"from job = {filters.FromJob}");
    }

    if (filters.ToJob.Length > 0)
    {
        labels.Add($"to job = {filters.ToJob}");
    }

    if (filters.ActiveFlag.Length > 0)
    {
        labels.Add($"active = {filters.ActiveFlag}");
    }

    if (filters.Client.Length > 0)
    {
        labels.Add($"client = {filters.Client}");
    }

    if (filters.JobType.Length > 0)
    {
        labels.Add($"job type = {filters.JobType}");
    }

    if (filters.Area.Length > 0)
    {
        labels.Add($"area = {filters.Area}");
    }

    if (filters.Centre.Length > 0)
    {
        labels.Add($"centre = {filters.Centre}");
    }

    if (filters.SourceType.Length > 0)
    {
        labels.Add($"source = {filters.SourceType}");
    }

    if (filters.ActivityFrom is not null)
    {
        labels.Add($"activity from = {filters.ActivityFrom:yyyy-MM-dd}");
    }

    if (filters.ActivityTo is not null)
    {
        labels.Add($"activity to = {filters.ActivityTo:yyyy-MM-dd}");
    }

    return labels;
}

static string BuildMenuKey(AbioMenuRow row)
{
    var program = Normalize(row.Program);
    if (program.Length > 0)
    {
        return program;
    }

    return string.Join(":", new[] { Normalize(row.Menu1), Normalize(row.Menu2), Normalize(row.Menu3) }.Where(value => value.Length > 0));
}

public sealed record CoreBookRow(string Book, string Description);

public sealed record CoreConfigResponse(string DefaultBook, IReadOnlyList<CoreBookRow> Books);

public sealed record CoreMenuResponse(IReadOnlyList<CoreMenuNode> Modules, int MenuRowCount, int ReportRowCount);

public sealed record CoreLookupResponse(IReadOnlyDictionary<string, IReadOnlyList<CoreLookupOption>> Fields);

public sealed record CoreLookupOption(string Value, string Label);

public sealed record CoreMenuNode(
    string Key,
    string Program,
    string Label,
    string Description,
    string ItemType,
    string Profile,
    string EntrySessionFlag,
    string Microhelp,
    string HelpUrl,
    string WindowName,
    string Menu1,
    string Menu2,
    string Menu3,
    IReadOnlyList<CoreMenuNode> Children);

public sealed record AbioMenuRow(
    string Program,
    string Description,
    string Menu1,
    string Menu2,
    string Menu3,
    string Prompt,
    string Profile,
    string ItemType,
    string EntrySessionFlag,
    string Microhelp,
    string HelpUrl,
    string WindowName);

public sealed record ProgramReportRow(
    string Program,
    string Report,
    string Name,
    string Microhelp,
    string HelpUrl,
    string DatawindowName,
    string Description);

public sealed record CoreSummaryResponse(
    int ActiveClients,
    int ActiveJobs,
    int ActiveVendors,
    int ActiveEmployees,
    int Timesheets,
    int ApInvoiceLines,
    decimal ApNetPurchase,
    int ArInvoiceLines,
    decimal ArNetPurchase,
    int GlTransactions,
    decimal GlAmount,
    int JcTransactions);

public sealed record CoreJobReportResponse(
    string Title,
    string ReportKey,
    string DatawindowName,
    string Source,
    IReadOnlyList<string> Filters,
    IReadOnlyList<CoreJobReportColumn> Columns,
    IReadOnlyList<Dictionary<string, object?>> Rows,
    int RowCount);

public sealed record JobReportDefinition(
    string Title,
    string Source,
    int RowLimit,
    IReadOnlyList<CoreJobReportColumn> Columns,
    string Sql);

public sealed record JobReportRequestFilters(
    string FromJob,
    string ToJob,
    string ActiveFlag,
    string Client,
    string JobType,
    string Area,
    string Centre,
    string SourceType,
    DateOnly? ActivityFrom,
    DateOnly? ActivityTo);

public sealed record CoreJobReportColumn(
    string Field,
    string HeaderName,
    int Width,
    bool Numeric);

public sealed record RhumbixConfigResponse(
    string DefaultBook,
    IReadOnlyList<string> AllowedBooks,
    DateOnly DefaultStartDate,
    DateOnly DefaultEndDate,
    int CurrentPrPeriod,
    bool CanImportTimesheets,
    bool CanSyncProjects);

public sealed record RhumbixPendingCountResponse(string Book, int PendingProjectCount);

public sealed record RhumbixImportTimesheetsRequest(string Book, DateOnly StartDate, DateOnly EndDate, int PrPeriod);

public sealed record RhumbixImportTimesheetsResponse(
    long RunId,
    int ImportedCount,
    int ErrorCount,
    int TotalFromRhumbix,
    string Status,
    string Message);

public sealed record RhumbixSyncProjectsRequest(string Book, bool ForceFullSync);

public sealed record RhumbixSyncProjectsResponse(long RunId, string Status, string Message);

public sealed record RhumbixImportErrorRow(
    long ErrorId,
    string? EmployeeId,
    DateOnly? ShiftDate,
    string? RhumbixProject,
    string? RhumbixCostCode,
    string? ErrorType,
    string? ErrorMessage,
    DateTime? ErrorDateTime);

public sealed record RhumbixSyncHistoryRow(
    DateTime SyncDateTime,
    string? SyncType,
    decimal? RecordsAttempted,
    decimal? RecordsCreated,
    decimal? RecordsUpdated,
    decimal? RecordsFailed,
    string StatusDisplay);

public sealed record GridQueryResponse<T>(IReadOnlyList<T> Rows, int RowCount);

public sealed record ApiErrorResponse(string Code, string Message, IReadOnlyList<ApiFieldError> Errors);

public sealed record ApiFieldError(string Field, string Message);

public sealed record JobRecordSaveCommandRequest(
    string Book,
    string Job,
    Dictionary<string, object?> Original,
    Dictionary<string, object?> Draft,
    IReadOnlyList<string> ChangedFields,
    string UserId);

public sealed record JobRecordSaveCommandResponse(
    string Status,
    string Message,
    IReadOnlyList<string> ChangedFields,
    IReadOnlyList<LegacyProgramReference> RequiredLegacyReferences,
    IReadOnlyList<string> RequiredCommandPhases);

public sealed record LegacyProgramReference(string Library, string ObjectName, string Role);
