using Microsoft.Data.SqlClient;
using System.Data;
using System.Text.Json;
using System.Text.RegularExpressions;

public static partial class PayrollProgramLayer
{
    private const int DefaultListLimit = 250;

    private static readonly IReadOnlyDictionary<string, PayrollCommandDefinition> CommandDefinitions =
        new Dictionary<string, PayrollCommandDefinition>(StringComparer.OrdinalIgnoreCase)
        {
            ["employee.add"] = new(
                "employee.add",
                "Add Employee",
                "Adds a new employee using Employee Entry defaults, validation, person-derived values, and employee earning setup.",
                "PREENT",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("payroll.pbl", "w_pr_employee.srw", "Employee Entry window"),
                    Ref("payroll.pbl", "u_cst_pr_employee_detail.sru", "Add action and person/default logic"),
                    Ref("payroll.pbl", "n_bo_employee.sru", "Employee BO validation/defaults"),
                    Ref("payroll.pbl", "d_bo_employee.srd", "Employee update DataWindow")
                ]),
            ["employee.change"] = new(
                "employee.change",
                "Change Employee",
                "Changes employee master/payroll settings while preserving legacy validation, protected fields, audit behavior, and related child updates.",
                "PREENT",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("payroll.pbl", "w_pr_employee.srw", "Employee Entry window"),
                    Ref("payroll.pbl", "u_cst_pr_employee_detail.sru", "Change action, itemchanged, report/history hooks"),
                    Ref("payroll.pbl", "n_bo_employee.sru", "Employee BO validation/defaults"),
                    Ref("payroll.pbl", "n_bo_employee_earning.sru", "Employee earning child behavior"),
                    Ref("payroll.pbl", "n_bo_employee_wcb.sru", "Employee WCB child behavior")
                ]),
            ["employee.terminate"] = new(
                "employee.terminate",
                "Terminate Employee",
                "Terminates an employee with ROE, termination-date, restrictions, and earnings checks.",
                "PREENT",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("payroll.pbl", "u_cst_pr_employee_detail.sru", "Terminate action and ROE behavior"),
                    Ref("payroll.pbl", "n_bo_employee.sru", "Termination validation and helper functions")
                ]),
            ["employee.rehire"] = new(
                "employee.rehire",
                "Re-employ Employee",
                "Re-employs a terminated employee and removes termination restrictions using the legacy action path.",
                "PREENT",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("payroll.pbl", "u_cst_pr_employee_detail.sru", "Re-employ action Y behavior"),
                    Ref("payroll.pbl", "n_bo_employee.sru", "Employee validation/defaults")
                ]),
            ["timesheet.add"] = new(
                "timesheet.add",
                "Add Timesheet",
                "Adds a timesheet using legacy next-item, pay-period, employee/job/rate, premium, and cost protection logic.",
                "PRTENT",
                "blocked-pending-legacy-command-migration",
                TimesheetReferences()),
            ["timesheet.change"] = new(
                "timesheet.change",
                "Change Timesheet",
                "Changes an unposted/unpaid timesheet through the legacy Timesheet Entry validation path.",
                "PRTENT",
                "blocked-pending-legacy-command-migration",
                TimesheetReferences()),
            ["timesheet.recalculate"] = new(
                "timesheet.recalculate",
                "Recalculate Timesheet",
                "Recalculates hours, earnings, premiums, WCB, GST, fringe, and totals using migrated PB payroll rules.",
                "PRTENT",
                "blocked-pending-legacy-command-migration",
                TimesheetReferences()),
            ["timesheet.delete"] = new(
                "timesheet.delete",
                "Delete Timesheet",
                "Deletes only legacy-permitted timesheets and child premiums.",
                "PRTENT",
                "blocked-pending-legacy-command-migration",
                TimesheetReferences()),
            ["fieldTimesheet.review"] = new(
                "fieldTimesheet.review",
                "Review Field Timesheet",
                "Processes field timesheet batches and updates child timesheets in one transaction.",
                "PRFENT",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("payroll.pbl", "w_pr_field_timesheet.srw", "Field Timesheet Review window"),
                    Ref("payroll.pbl", "n_bo_field_timesheet.sru", "Field Timesheet BO and child timesheet registration"),
                    Ref("payroll.pbl", "d_bo_field_timesheet.srd", "Field Timesheet update DataWindow"),
                    Ref("payroll.pbl", "n_bo_timesheet.sru", "Child timesheet BO")
                ]),
            ["cheque.create"] = new(
                "cheque.create",
                "Create Cheques",
                "Creates cheques from available timesheets and builds cheque child records.",
                "PRCQCR",
                "blocked-pending-legacy-command-migration",
                ChequeReferences()),
            ["cheque.approve"] = new(
                "cheque.approve",
                "Approve Cheques",
                "Approves queued cheques prior to issuing.",
                "PRCQAP",
                "blocked-pending-legacy-command-migration",
                ChequeReferences()),
            ["cheque.change"] = new(
                "cheque.change",
                "Change Cheque",
                "Changes legacy-permitted cheque fields and child rows.",
                "PRCENT",
                "blocked-pending-legacy-command-migration",
                ChequeReferences()),
            ["cheque.reconcile"] = new(
                "cheque.reconcile",
                "Reconcile Cheque",
                "Marks issued cheques as reconciled using legacy status/action rules.",
                "PRCENT",
                "blocked-pending-legacy-command-migration",
                ChequeReferences()),
            ["cheque.void"] = new(
                "cheque.void",
                "Void Or Reverse Cheque",
                "Voids/reverses a cheque and updates related timesheets, premiums, earnings, WCB, purchases, and queue rows.",
                "PRCENT",
                "blocked-pending-legacy-command-migration",
                ChequeReferences()),
            ["cheque.issue"] = new(
                "cheque.issue",
                "Issue Cheques",
                "Issues or reprints cheques and updates employee earnings and related payroll state exactly once.",
                "PRCHEQ",
                "blocked-pending-legacy-command-migration",
                ChequeReferences()),
            ["payroll.cost"] = new(
                "payroll.cost",
                "Cost To J/C And G/L",
                "Applies issued cheque costs to Job Cost and General Ledger.",
                "PRTRAN",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("payroll.pbl", "d_prtran_cheques.srd", "Payroll costing cheque selection"),
                    Ref("payroll.pbl", "d_prtran_timesheet.srd", "Payroll costing timesheet rows"),
                    Ref("payroll.pbl", "d_prtran_cheque_summary.srd", "Payroll costing summary"),
                    Ref("payroll.pbl", "n_bo_pr_cheque.sru", "Cheque child registrations and costing state")
                ]),
            ["payroll.advancePeriod"] = new(
                "payroll.advancePeriod",
                "Advance Pay Period",
                "Advances Payroll and/or G/L period after legacy pre-flight checks.",
                "PRMEND",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("shared_tables.pbl", "n_bo_pay_period.sru", "Pay period setup/validation"),
                    Ref("shared_tables.pbl", "d_st_pay_period_detail.srd", "Pay period DataWindow")
                ]),
            ["payroll.cleanup"] = new(
                "payroll.cleanup",
                "Clean Up Payroll",
                "Moves paid timesheets and costed/reconciled cheques to history.",
                "PRARCH",
                "blocked-pending-legacy-command-migration",
                [
                    Ref("payroll.pbl", "n_bo_timesheet.sru", "Timesheet file type/history behavior"),
                    Ref("payroll.pbl", "n_bo_pr_cheque.sru", "Cheque file type/history behavior")
                ])
        };

    public static PayrollModuleInventory GetInventory() =>
        new(
            Module: "Payroll",
            Status: "middle-tier-foundation",
            SourceLibraries:
            [
                "payroll.pbl",
                "timesheet.pbl",
                "reports_pr.pbl",
                "shared_tables.pbl",
                "table.pbl"
            ],
            MenuPrograms:
            [
                "PREENT",
                "PREREP",
                "PRFENT",
                "PRTENT",
                "PRTREP",
                "PRCQCR",
                "PRCQAP",
                "PRCENT",
                "PRCREP",
                "PRCHEQ",
                "PRTRAN",
                "PRMEND",
                "PRARCH",
                "PRSETU"
            ],
            Commands: CommandDefinitions.Values.ToArray(),
            ReadModels:
            [
                "employees",
                "employeeRecord",
                "timesheets",
                "timesheetRecord",
                "fieldTimesheets",
                "fieldTimesheetRecord",
                "cheques",
                "chequeRecord",
                "setup",
                "lookups"
            ],
            SafetyNotes:
            [
                "Payroll writes are intentionally blocked until each PB action/event path is migrated.",
                "Do not save Payroll transaction tables through generic update endpoints.",
                "Create, approve, issue, post, period advance, and cleanup must be explicit commands with reconciliation tests."
            ]);

    public static async Task<PayrollListResult> GetEmployeesAsync(string connectionString, PayrollListRequest request)
    {
        const string sql = """
            SELECT TOP (@limit)
                e.book,
                e.employee,
                e.name,
                e.employment_type AS employmentType,
                e.trade_union AS tradeUnion,
                e.occupation,
                e.job,
                e.centre,
                e.tax_province AS taxProvince,
                e.wcb_class AS wcbClass,
                e.hire_date AS hireDate,
                e.termination_date AS terminationDate,
                e.restrict_flag AS restrictFlag,
                e.file_type AS fileType
            FROM dbo.employee e
            WHERE e.book = @book
              AND (@includeHistory = 1 OR e.file_type = 'C')
              AND (@search = '' OR
                   CONVERT(varchar(20), e.employee) LIKE @searchLike OR
                   e.name LIKE @searchLike OR
                   e.trade_union LIKE @searchLike OR
                   e.occupation LIKE @searchLike OR
                   e.job LIKE @searchLike OR
                   e.centre LIKE @searchLike)
            ORDER BY CASE WHEN e.termination_date IS NULL THEN 0 ELSE 1 END, e.name, e.employee;
            """;

        return await QueryListAsync(connectionString, request, sql);
    }

    public static async Task<PayrollRecordResult> GetEmployeeRecordAsync(string connectionString, string book, long employee)
    {
        const string headerSql = """
            SELECT TOP (1) *
            FROM dbo.employee
            WHERE book = @book AND employee = @employee;
            """;

        var parameters = new[]
        {
            Parameter("@book", SqlDbType.VarChar, NormalizeBook(book), 8),
            Parameter("@employee", SqlDbType.Int, employee)
        };

        var header = await QuerySingleDictionaryAsync(connectionString, headerSql, parameters);
        if (header is null)
        {
            return PayrollRecordResult.NotFound("employee", $"Employee {employee} was not found in {NormalizeBook(book)}.");
        }

        var children = new Dictionary<string, IReadOnlyList<Dictionary<string, object?>>>(StringComparer.OrdinalIgnoreCase)
        {
            ["earnings"] = await QueryDictionaryAsync(connectionString, """
                SELECT TOP (10) *
                FROM dbo.employee_earning
                WHERE book = @book AND employee = @employee
                ORDER BY tax_year DESC;
                """, parameters),
            ["premiums"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.employee_premium
                WHERE book = @book AND employee = @employee
                ORDER BY premium_type;
                """, parameters),
            ["wcb"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.employee_wcb
                WHERE book = @book AND employee = @employee
                ORDER BY wcb_class;
                """, parameters),
            ["purchases"] = await QueryDictionaryAsync(connectionString, """
                SELECT TOP (25) *
                FROM dbo.employee_purchase
                WHERE book = @book AND employee = @employee
                ORDER BY cheque_no DESC;
                """, parameters)
        };

        return PayrollRecordResult.Found("employee", header, children, EmployeeTabs());
    }

    public static async Task<PayrollListResult> GetTimesheetsAsync(string connectionString, PayrollListRequest request)
    {
        const string sql = """
            SELECT TOP (@limit)
                t.book,
                t.employee,
                e.name AS employeeName,
                t.work_date AS workDate,
                t.timesheet_item AS timesheetItem,
                t.job,
                t.area,
                t.centre,
                t.trade_union AS tradeUnion,
                t.occupation,
                t.wcb_class AS wcbClass,
                t.pr_yyyymm AS prPeriod,
                t.timesheet_status AS timesheetStatus,
                t.cheque_no AS chequeNo,
                t.transact_flag AS transactFlag,
                t.reg_hour AS regHour,
                t.tah_hour AS tahHour,
                t.ovr_hour AS ovrHour,
                t.travel_hour AS travelHour,
                t.total
            FROM dbo.timesheet t
            LEFT JOIN dbo.employee e ON e.book = t.book AND e.employee = t.employee
            WHERE t.book = @book
              AND (@includeHistory = 1 OR t.file_type = 'C')
              AND (@search = '' OR
                   CONVERT(varchar(20), t.employee) LIKE @searchLike OR
                   e.name LIKE @searchLike OR
                   t.job LIKE @searchLike OR
                   t.area LIKE @searchLike OR
                   t.centre LIKE @searchLike OR
                   t.trade_union LIKE @searchLike OR
                   t.occupation LIKE @searchLike OR
                   t.pr_yyyymm LIKE @searchLike OR
                   CONVERT(varchar(20), t.cheque_no) LIKE @searchLike)
            ORDER BY t.work_date DESC, t.employee, t.timesheet_item;
            """;

        return await QueryListAsync(connectionString, request, sql);
    }

    public static async Task<PayrollRecordResult> GetTimesheetRecordAsync(string connectionString, string book, long employee, DateTime workDate, int timesheetItem)
    {
        var parameters = new[]
        {
            Parameter("@book", SqlDbType.VarChar, NormalizeBook(book), 8),
            Parameter("@employee", SqlDbType.Int, employee),
            Parameter("@workDate", SqlDbType.DateTime, workDate),
            Parameter("@timesheetItem", SqlDbType.Int, timesheetItem)
        };

        var header = await QuerySingleDictionaryAsync(connectionString, """
            SELECT TOP (1) *
            FROM dbo.timesheet
            WHERE book = @book
              AND employee = @employee
              AND work_date = @workDate
              AND timesheet_item = @timesheetItem;
            """, parameters);

        if (header is null)
        {
            return PayrollRecordResult.NotFound("timesheet", "The selected timesheet was not found.");
        }

        var children = new Dictionary<string, IReadOnlyList<Dictionary<string, object?>>>(StringComparer.OrdinalIgnoreCase)
        {
            ["premiums"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.timesheet_premium
                WHERE book = @book
                  AND employee = @employee
                  AND work_date = @workDate
                  AND timesheet_item = @timesheetItem
                ORDER BY premium_type;
                """, parameters)
        };

        return PayrollRecordResult.Found("timesheet", header, children, ["Details", "Premiums"]);
    }

    public static async Task<PayrollListResult> GetFieldTimesheetsAsync(string connectionString, PayrollListRequest request)
    {
        const string sql = """
            SELECT TOP (@limit)
                ft.book,
                ft.work_date AS workDate,
                ft.add_user_id AS addUserId,
                ft.field_timesheet_item AS fieldTimesheetItem,
                ft.file_type AS fileType,
                ft.add_datetime AS addDateTime,
                LEFT(COALESCE(CAST(ft.note AS varchar(max)), ''), 250) AS notePreview,
                (SELECT COUNT(*) FROM dbo.timesheet t
                 WHERE t.book = ft.book
                   AND t.work_date = ft.work_date
                   AND t.field_timesheet_item = ft.field_timesheet_item) AS timesheetRows
            FROM dbo.field_timesheet ft
            WHERE ft.book = @book
              AND (@includeHistory = 1 OR ft.file_type = 'C')
              AND (@search = '' OR
                   ft.add_user_id LIKE @searchLike OR
                   CONVERT(varchar(20), ft.field_timesheet_item) LIKE @searchLike OR
                   CAST(ft.note AS varchar(max)) LIKE @searchLike)
            ORDER BY ft.work_date DESC, ft.field_timesheet_item DESC;
            """;

        return await QueryListAsync(connectionString, request, sql);
    }

    public static async Task<PayrollRecordResult> GetFieldTimesheetRecordAsync(string connectionString, string book, DateTime workDate, string addUserId, int fieldTimesheetItem)
    {
        var parameters = new[]
        {
            Parameter("@book", SqlDbType.VarChar, NormalizeBook(book), 8),
            Parameter("@workDate", SqlDbType.DateTime, workDate),
            Parameter("@addUserId", SqlDbType.VarChar, Normalize(addUserId), 8),
            Parameter("@fieldTimesheetItem", SqlDbType.Int, fieldTimesheetItem)
        };

        var header = await QuerySingleDictionaryAsync(connectionString, """
            SELECT TOP (1) *
            FROM dbo.field_timesheet
            WHERE book = @book
              AND work_date = @workDate
              AND add_user_id = @addUserId
              AND field_timesheet_item = @fieldTimesheetItem;
            """, parameters);

        if (header is null)
        {
            return PayrollRecordResult.NotFound("fieldTimesheet", "The selected field timesheet was not found.");
        }

        var children = new Dictionary<string, IReadOnlyList<Dictionary<string, object?>>>(StringComparer.OrdinalIgnoreCase)
        {
            ["timesheets"] = await QueryDictionaryAsync(connectionString, """
                SELECT TOP (200) *
                FROM dbo.timesheet
                WHERE book = @book
                  AND work_date = @workDate
                  AND field_timesheet_item = @fieldTimesheetItem
                ORDER BY employee, timesheet_item;
                """, parameters)
        };

        return PayrollRecordResult.Found("fieldTimesheet", header, children, ["Details", "Document"]);
    }

    public static async Task<PayrollListResult> GetChequesAsync(string connectionString, PayrollListRequest request)
    {
        const string sql = """
            SELECT TOP (@limit)
                c.book,
                c.cheque_no AS chequeNo,
                c.employee,
                e.name AS employeeName,
                c.pr_yyyymm AS prPeriod,
                c.cheque_status AS chequeStatus,
                c.issue_date AS issueDate,
                c.trade_union AS tradeUnion,
                c.reg_hour AS regHour,
                c.tah_hour AS tahHour,
                c.ovr_hour AS ovrHour,
                c.travel_hour AS travelHour,
                c.gross_pay AS grossPay,
                c.net_pay AS netPay,
                c.cpp_contribution AS cppContribution,
                c.ei_premium AS eiPremium,
                c.income_tax AS incomeTax
            FROM dbo.pr_cheque c
            LEFT JOIN dbo.employee e ON e.book = c.book AND e.employee = c.employee
            WHERE c.book = @book
              AND (@includeHistory = 1 OR c.file_type = 'C')
              AND (@search = '' OR
                   CONVERT(varchar(20), c.cheque_no) LIKE @searchLike OR
                   CONVERT(varchar(20), c.employee) LIKE @searchLike OR
                   e.name LIKE @searchLike OR
                   c.pr_yyyymm LIKE @searchLike OR
                   c.cheque_status LIKE @searchLike OR
                   c.trade_union LIKE @searchLike)
            ORDER BY c.cheque_no DESC;
            """;

        return await QueryListAsync(connectionString, request, sql);
    }

    public static async Task<PayrollRecordResult> GetChequeRecordAsync(string connectionString, string book, long chequeNo)
    {
        var parameters = new[]
        {
            Parameter("@book", SqlDbType.VarChar, NormalizeBook(book), 8),
            Parameter("@chequeNo", SqlDbType.Int, chequeNo)
        };

        var header = await QuerySingleDictionaryAsync(connectionString, """
            SELECT TOP (1) *
            FROM dbo.pr_cheque
            WHERE book = @book AND cheque_no = @chequeNo;
            """, parameters);

        if (header is null)
        {
            return PayrollRecordResult.NotFound("cheque", $"Cheque {chequeNo} was not found in {NormalizeBook(book)}.");
        }

        var children = new Dictionary<string, IReadOnlyList<Dictionary<string, object?>>>(StringComparer.OrdinalIgnoreCase)
        {
            ["premiums"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.pr_cheque_premium
                WHERE book = @book AND cheque_no = @chequeNo
                ORDER BY premium_type;
                """, parameters),
            ["wcb"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.pr_cheque_wcb
                WHERE book = @book AND cheque_no = @chequeNo
                ORDER BY wcb_class;
                """, parameters),
            ["tradeUnions"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.pr_cheque_trade_union
                WHERE book = @book AND cheque_no = @chequeNo
                ORDER BY trade_union;
                """, parameters),
            ["occupations"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.pr_cheque_occupation
                WHERE book = @book AND cheque_no = @chequeNo
                ORDER BY trade_union, occupation;
                """, parameters),
            ["queue"] = await QueryDictionaryAsync(connectionString, """
                SELECT *
                FROM dbo.pr_cheque_queue
                WHERE book = @book AND cheque_no = @chequeNo
                ORDER BY queue_key;
                """, parameters),
            ["timesheets"] = await QueryDictionaryAsync(connectionString, """
                SELECT TOP (200) *
                FROM dbo.timesheet
                WHERE book = @book AND cheque_no = @chequeNo
                ORDER BY employee, work_date, timesheet_item;
                """, parameters)
        };

        return PayrollRecordResult.Found("cheque", header, children, ChequeTabs());
    }

    public static async Task<PayrollSetupResult> GetSetupAsync(string connectionString, string book, string setupArea, int? limit = null)
    {
        var normalizedArea = Normalize(setupArea);
        if (!SetupQueries.TryGetValue(normalizedArea, out var definition))
        {
            return new PayrollSetupResult(
                normalizedArea,
                "unsupported-setup-area",
                [],
                $"Setup area '{normalizedArea}' is not part of the Payroll middle-tier registry yet.");
        }

        var rows = await QueryDictionaryAsync(connectionString, definition.Sql, [
            Parameter("@book", SqlDbType.VarChar, NormalizeBook(book), 8),
            Parameter("@limit", SqlDbType.Int, ClampLimit(limit))
        ]);

        return new PayrollSetupResult(normalizedArea, "ok", rows, definition.LegacySource);
    }

    public static async Task<PayrollLookupResult> GetLookupsAsync(string connectionString, string book)
    {
        var normalizedBook = NormalizeBook(book);
        var lookups = new Dictionary<string, IReadOnlyList<PayrollLookupOption>>(StringComparer.OrdinalIgnoreCase)
        {
            ["employee"] = await QueryLookupAsync(connectionString, """
                SELECT TOP (500)
                    CONVERT(varchar(20), employee) AS value,
                    CONCAT(CONVERT(varchar(20), employee), ' - ', name) AS label
                FROM dbo.employee
                WHERE book = @book AND file_type = 'C'
                ORDER BY name, employee;
                """, normalizedBook),
            ["tradeUnion"] = await QueryLookupAsync(connectionString, """
                SELECT trade_union AS value, CONCAT(trade_union, ' - ', description) AS label
                FROM dbo.trade_union
                WHERE book = @book
                ORDER BY trade_union;
                """, normalizedBook),
            ["occupation"] = await QueryLookupAsync(connectionString, """
                SELECT TOP (500) occupation AS value, CONCAT(occupation, ' - ', description) AS label
                FROM dbo.occupation
                WHERE book = @book
                ORDER BY occupation;
                """, normalizedBook),
            ["wcbClass"] = await QueryLookupAsync(connectionString, """
                SELECT
                    wcb_class AS value,
                    CONCAT(wcb_class, ' - ', MAX(tax_year), ' rate ', CONVERT(varchar(20), MAX(wcb_rate))) AS label
                FROM dbo.wcb_rate
                WHERE book = @book
                  AND file_type = 'C'
                GROUP BY wcb_class
                ORDER BY wcb_class;
                """, normalizedBook),
            ["premium"] = await QueryLookupAsync(connectionString, """
                SELECT premium_type AS value, CONCAT(premium_type, ' - ', description) AS label
                FROM dbo.premium_type
                WHERE active_flag = 'Y'
                ORDER BY premium_type;
                """, normalizedBook),
            ["timesheetStatus"] = await QueryLookupAsync(connectionString, """
                SELECT timesheet_status AS value, CONCAT(timesheet_status, ' - ', description) AS label
                FROM dbo.timesheet_status
                WHERE active_flag = 'Y'
                ORDER BY timesheet_status;
                """, normalizedBook),
            ["job"] = await QueryLookupAsync(connectionString, """
                SELECT TOP (500) job AS value, CONCAT(job, ' - ', description) AS label
                FROM dbo.job
                WHERE book = @book AND active_flag = 'Y'
                ORDER BY job;
                """, normalizedBook),
            ["centre"] = await QueryLookupAsync(connectionString, """
                SELECT TOP (500) centre AS value, CONCAT(centre, ' - ', description) AS label
                FROM dbo.centre
                WHERE book = @book
                ORDER BY centre;
                """, normalizedBook)
        };

        return new PayrollLookupResult(normalizedBook, lookups);
    }

    public static PayrollValidationCatalog GetValidationRules() =>
        new(
            Version: "payroll-pb-validation-2026-07-05",
            SourceObjects:
            [
                Ref("payroll.pbl", "n_bo_employee.sru", "Employee BO required/expression/advanced validations"),
                Ref("payroll.pbl", "u_cst_pr_employee_detail.sru", "Employee Entry itemchanged and action-layer validations"),
                Ref("payroll.pbl", "n_bo_timesheet.sru", "Timesheet BO required/expression/advanced validations"),
                Ref("payroll.pbl", "n_bo_timesheet_premium.sru", "Timesheet Premium child validations"),
                Ref("payroll.pbl", "n_bo_pr_cheque.sru", "Cheque command validations"),
                Ref("payroll.pbl", "n_bo_field_timesheet.sru", "Field Timesheet review validations")
            ],
            RecordTypes: new Dictionary<string, IReadOnlyList<PayrollValidationRule>>(StringComparer.OrdinalIgnoreCase)
            {
                ["employee"] =
                [
                    ..RequiredRules("employee",
                    [
                        ("employee", "Employee is Required"),
                        ("book", "Company is Required"),
                        ("name", "Name is Required"),
                        ("employmentType", "Employment Type is Required"),
                        ("tradeUnion", "Union is Required"),
                        ("occupation", "Occupation is Required"),
                        ("shift", "Shift is Required"),
                        ("federalZoneDeduction", "Federal zone deduction is Required"),
                        ("federalTd1Claim", "Federal TD1 claim is Required"),
                        ("provincialTd1Claim", "Provincial TD1 claim is Required"),
                        ("addIncomeTaxPerCk", "Add Income tax per ck is Required"),
                        ("cppExemptFlag", "CPP exempt flag is Required"),
                        ("eiExemptFlag", "EI exempt flag is Required"),
                        ("incomeTaxExemptFlag", "Tax exempt flag is Required"),
                        ("hireDate", "Hire Date is Required"),
                        ("garnisheeFlag", "Garnishee flag is Required"),
                        ("safetyToRrspFlag", "Safety to RRSP is Required"),
                        ("otherIncentiveToRrspFlag", "Other incentive to RRSP flag is Required"),
                        ("vacationPercent", "Vacation % is Required"),
                        ("statutoryPercent", "Statutory % is Required"),
                        ("employerRrspPercent", "RRSP % earn is Required"),
                        ("staffSafetyPercent", "Staff % earn is Required"),
                        ("smtcPercent", "Tool % earn is Required"),
                        ("incentivePercent", "Incentive % earn is Required"),
                        ("trainingPercent", "Training % earn is Required"),
                        ("loaRate", "LOA/hr is Required"),
                        ("mileageRate", "Mileage/hr is Required"),
                        ("mileageTaxableFlag", "Mileage taxable flag is Required"),
                        ("siteAllowTaxableFlag", "Site allow taxable flag is Required"),
                        ("employeeRrspPerCk", "Employee RRSP is Required"),
                        ("taxableBenefitPerCk", "Taxable benefit per cheque is Required"),
                        ("taxableBenefitPerMonth", "Taxable benefit per month is Required"),
                        ("charityPerCk", "Charity flag is Required"),
                        ("turnaroundCycleDays", "Cycle days is Required"),
                        ("nextTurnaroundAmt", "Turnaround amt is Required"),
                        ("duesPerMonth", "Dues per month is Required"),
                        ("securityDeposit", "Security Deposit is Required"),
                        ("advanceRepay", "Advance/repay is Required"),
                        ("vacationOwed", "Vacation owed is Required"),
                        ("statutoryOwed", "Statutory owed is Required"),
                        ("personalSafetyOwed", "Personal safety owed is Required"),
                        ("groupSafetyOwed", "Group safety owed is Required"),
                        ("staffSafetyOwed", "Other safety owed is Required"),
                        ("smtcOwed", "Tools owed is Required"),
                        ("training", "Training earn is Required"),
                        ("retentionOwed", "Retention Owed is Required"),
                        ("incentiveOwed", "Incentive Owed is Required"),
                        ("restrictFlag", "Restrict Access flag is Required"),
                        ("fileType", "File Type is Required"),
                        ("addUserId", "Add user id is Required"),
                        ("addDatetime", "Add date time is Required"),
                        ("localHireFlag", "Local Hire Flag is Required"),
                        ("dailyDuesFlag", "Daily Dues Flag is Required"),
                        ("adminFeeFlag", "Admin Fee Flag is Required"),
                        ("loaTaxableFlag", "LOA Taxable Flag is Required"),
                        ("permitFeeFlag", "Permit Fee Flag is Required"),
                        ("employeeRrspPercent", "Employee RRSP percent is Required")
                    ]),
                    EnumRule("employee", "taxProvince", "Tax Province must be a valid Canadian province code.", ["AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"]),
                    EnumRule("employee", "employmentType", "Employment Type must be E, S, T, or V.", ["E", "S", "T", "V"]),
                    EnumRule("employee", "shift", "Shift must be D or N.", ["D", "N"]),
                    EnumRule("employee", "fileType", "File Type must be C, H, R, or T.", ["C", "H", "R", "T"]),
                    ..YnRules("employee", ["adminFeeFlag", "cppExemptFlag", "dailyDuesFlag", "eiExemptFlag", "garnisheeFlag", "incomeTaxExemptFlag", "localHireFlag", "loaTaxableFlag", "mileageTaxableFlag", "otherIncentiveToRrspFlag", "payPensionToCashFlag", "permitFeeFlag", "restrictFlag", "safetyToRrspFlag", "siteAllowTaxableFlag", "weeklyDuesFlag", "jobBasedWcbClass"]),
                    ExpressionRule("employee", "centre", "Area and Centre is Required", "Area and centre must both be blank or both populated."),
                    ExpressionRule("employee", "terminationDate", "ROE/termination-date rules must be satisfied.", "Migrated backend advanced validation required from n_bo_employee.sru."),
                    ExpressionRule("employee", "eftAccount", "Either Institution, Branch and Account, or US routing and Account, are Required", "Migrated backend advanced validation required from n_bo_employee.sru.")
                ],
                ["timesheet"] =
                [
                    ..RequiredRules("timesheet",
                    [
                        ("book", "Book is Required"),
                        ("employee", "Employee is Required"),
                        ("workDate", "Date is Required"),
                        ("timesheetItem", "Timesheet item is Required"),
                        ("glAccount", "G/L Account is Required"),
                        ("restrictFlag", "Restrict Flag is Required"),
                        ("transactFlag", "Transact Flag is Required"),
                        ("prYyyymm", "G/L yyyymm is Required"),
                        ("wcbClass", "WCB class is Required"),
                        ("gstRule", "GST rule is Required")
                    ]),
                    ExpressionRule("timesheet", "tradeUnion", "Union is Required", "Required unless file_type is R."),
                    ExpressionRule("timesheet", "occupation", "Occupation is Required", "Required unless file_type is R."),
                    EnumRule("timesheet", "shift", "Shift must be D or N.", ["D", "N"]),
                    ..YnRules("timesheet", ["tahSpotFlag", "ovrSpotFlag", "transactFlag", "restrictFlag"]),
                    ExpressionRule("timesheet", "area", "Area and Centre is Required", "Area and centre must both be blank or both populated."),
                    ExpressionRule("timesheet", "centre", "Area and Centre is Required", "Area and centre must both be blank or both populated."),
                    ExpressionRule("timesheet", "workDate", "date more than 2 years ago or more than 65 in the future", "Migrated backend advanced validation required from n_bo_timesheet.sru."),
                    ExpressionRule("timesheet", "prYyyymm", "Pay period and G/L month must be valid.", "Migrated backend advanced validation required from n_bo_timesheet.sru."),
                    ExpressionRule("timesheet", "glAccount", "G/L account is reserved for J/C labour costs, timesheet must be posted to a job.", "Migrated backend advanced validation required from n_bo_timesheet.sru.")
                ],
                ["fieldTimesheet"] =
                [
                    ..RequiredRules("fieldTimesheet",
                    [
                        ("book", "Book is Required"),
                        ("workDate", "Date is Required"),
                        ("fieldTimesheetItem", "Field timesheet item is Required"),
                        ("addUserId", "Add user id is Required"),
                        ("fileType", "File Type is Required")
                    ]),
                    ExpressionRule("fieldTimesheet", "timesheets", "Child timesheet review must run in the same transaction.", "Migrated backend command validation required from n_bo_field_timesheet.sru.")
                ],
                ["cheque"] =
                [
                    ..RequiredRules("cheque",
                    [
                        ("book", "Book is Required"),
                        ("chequeNo", "Cheque No is Required"),
                        ("employee", "Employee is Required"),
                        ("chequeStatus", "Cheque Status is Required"),
                        ("prYyyymm", "Payroll period is Required"),
                        ("fileType", "File Type is Required")
                    ]),
                    ExpressionRule("cheque", "chequeStatus", "Cheque action/status transition must be valid.", "Migrated backend command validation required from n_bo_pr_cheque.sru."),
                    ExpressionRule("cheque", "issueDate", "Issue/reprint/void/reconcile date rules must be valid.", "Migrated backend command validation required from n_bo_pr_cheque.sru.")
                ]
            });

    public static Task<PayrollCommandResult> ExecuteCommandAsync(string connectionString, PayrollCommandRequest request)
    {
        ArgumentNullException.ThrowIfNull(connectionString);

        var commandName = Normalize(request.CommandName);
        var validationErrors = ValidateCommandPayload(commandName, request.Payload ?? []);
        if (!CommandDefinitions.TryGetValue(commandName, out var command))
        {
            return Task.FromResult(new PayrollCommandResult(
                Status: "unsupported-command",
                CommandName: commandName,
                Message: $"Payroll command '{commandName}' is not registered in the middle tier.",
                LegacyProgram: "",
                RequiredLegacyReferences: [],
                RequiredMigrationSteps:
                [
                    "Add a PayrollCommandDefinition for this legacy action.",
                    "Identify the PB window, user object, business object, and DataWindow update path.",
                    "Implement the .NET command with validation, transaction, audit, and reconciliation tests."
                ],
                ChangedFields: request.ChangedFields ?? [],
                ValidationErrors: validationErrors));
        }

        return Task.FromResult(new PayrollCommandResult(
            Status: validationErrors.Any(error => error.Severity.Equals("error", StringComparison.OrdinalIgnoreCase))
                ? "validation-failed"
                : command.Status,
            CommandName: command.Name,
            Message: validationErrors.Any(error => error.Severity.Equals("error", StringComparison.OrdinalIgnoreCase))
                ? $"{command.DisplayName} failed migrated validation checks. Fix validation errors before this command can continue."
                : $"{command.DisplayName} is intentionally blocked. Migrate the referenced PowerBuilder program-layer logic before enabling this command.",
            LegacyProgram: command.LegacyProgram,
            RequiredLegacyReferences: command.LegacyReferences,
            RequiredMigrationSteps:
            [
                "Extract and summarize the PB action/event path for this command.",
                "Map editable, protected, calculated, and child DataWindow fields.",
                "Port defaults, itemchanged behavior, validation, and pre/post-update logic into .NET.",
                "Wrap all side effects in one SQL transaction.",
                "Add side-by-side tests against Abio Legacy and ABIO_DEMO before exposing an API endpoint."
            ],
            ChangedFields: request.ChangedFields ?? [],
            ValidationErrors: validationErrors));
    }

    private static IReadOnlyList<PayrollValidationError> ValidateCommandPayload(string commandName, IReadOnlyDictionary<string, object?> payload)
    {
        var recordType = RecordTypeForCommand(commandName);
        if (recordType.Length == 0 || !GetValidationRules().RecordTypes.TryGetValue(recordType, out var rules))
        {
            return [];
        }

        var errors = new List<PayrollValidationError>();
        foreach (var rule in rules)
        {
            if (rule.Severity != "error")
            {
                continue;
            }

            if (rule.RuleType.Equals("required", StringComparison.OrdinalIgnoreCase)
                && IsMissing(payload, rule.Field))
            {
                errors.Add(new PayrollValidationError(rule.Field, rule.Message, rule.RuleId, rule.Severity));
            }

            if (rule.RuleType.Equals("enum", StringComparison.OrdinalIgnoreCase)
                && !IsMissing(payload, rule.Field))
            {
                var value = ValueAsString(payload, rule.Field);
                if (!rule.AllowedValues.Contains(value, StringComparer.OrdinalIgnoreCase))
                {
                    errors.Add(new PayrollValidationError(rule.Field, rule.Message, rule.RuleId, rule.Severity));
                }
            }
        }

        return errors;
    }

    private static string RecordTypeForCommand(string commandName)
    {
        if (commandName.StartsWith("employee.", StringComparison.OrdinalIgnoreCase))
        {
            return "employee";
        }

        if (commandName.StartsWith("timesheet.", StringComparison.OrdinalIgnoreCase))
        {
            return "timesheet";
        }

        if (commandName.StartsWith("fieldTimesheet.", StringComparison.OrdinalIgnoreCase))
        {
            return "fieldTimesheet";
        }

        if (commandName.StartsWith("cheque.", StringComparison.OrdinalIgnoreCase))
        {
            return "cheque";
        }

        return "";
    }

    private static IReadOnlyList<PayrollValidationRule> RequiredRules(
        string recordType,
        IReadOnlyList<(string Field, string Message)> rules) =>
        rules.Select(rule => new PayrollValidationRule(
            RuleId: $"{recordType}.{rule.Field}.required",
            Field: rule.Field,
            RuleType: "required",
            Message: rule.Message,
            Severity: "error",
            AllowedValues: [],
            AppliesOn: ["add", "change"],
            LegacySource: recordType == "employee" ? "payroll.pbl/n_bo_employee.sru" : "payroll.pbl/n_bo_timesheet.sru",
            FrontendHint: "Mark field required and validate before command submission.")).ToArray();

    private static PayrollValidationRule EnumRule(
        string recordType,
        string field,
        string message,
        IReadOnlyList<string> allowedValues) =>
        new(
            RuleId: $"{recordType}.{field}.enum",
            Field: field,
            RuleType: "enum",
            Message: message,
            Severity: "error",
            AllowedValues: allowedValues,
            AppliesOn: ["add", "change"],
            LegacySource: recordType == "employee" ? "payroll.pbl/n_bo_employee.sru" : "payroll.pbl/n_bo_timesheet.sru",
            FrontendHint: "Restrict field to the listed values.");

    private static IReadOnlyList<PayrollValidationRule> YnRules(string recordType, IReadOnlyList<string> fields) =>
        fields.Select(field => EnumRule(recordType, field, $"{FormatRuleField(field)} must be Y or N.", ["Y", "N"])).ToArray();

    private static PayrollValidationRule ExpressionRule(
        string recordType,
        string field,
        string message,
        string frontendHint) =>
        new(
            RuleId: $"{recordType}.{field}.expression",
            Field: field,
            RuleType: "expression",
            Message: message,
            Severity: "backend-required",
            AllowedValues: [],
            AppliesOn: ["add", "change"],
            LegacySource: recordType == "employee" ? "payroll.pbl/n_bo_employee.sru" : "payroll.pbl/n_bo_timesheet.sru",
            FrontendHint: frontendHint);

    private static bool IsMissing(IReadOnlyDictionary<string, object?> payload, string field) =>
        !payload.TryGetValue(field, out var value) || string.IsNullOrWhiteSpace(ValueAsString(value));

    private static string ValueAsString(IReadOnlyDictionary<string, object?> payload, string field) =>
        payload.TryGetValue(field, out var value) ? ValueAsString(value) : string.Empty;

    private static string ValueAsString(object? value)
    {
        if (value is null)
        {
            return string.Empty;
        }

        if (value is JsonElement element)
        {
            return element.ValueKind switch
            {
                JsonValueKind.String => element.GetString()?.Trim() ?? string.Empty,
                JsonValueKind.Number => element.GetRawText(),
                JsonValueKind.True => "Y",
                JsonValueKind.False => "N",
                JsonValueKind.Null => string.Empty,
                _ => element.GetRawText().Trim()
            };
        }

        return Convert.ToString(value)?.Trim() ?? string.Empty;
    }

    private static string FormatRuleField(string field) =>
        Regex.Replace(field, "([A-Z])", " $1").Trim();

    private static readonly IReadOnlyDictionary<string, PayrollSetupQuery> SetupQueries =
        new Dictionary<string, PayrollSetupQuery>(StringComparer.OrdinalIgnoreCase)
        {
            ["payPeriods"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.pay_period
                WHERE file_type = 'C'
                ORDER BY year DESC, pay_period_type;
                """, "shared_tables.pbl/n_bo_pay_period.sru, d_st_pay_period_detail.srd"),
            ["tradeUnions"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.trade_union
                WHERE book = @book
                ORDER BY trade_union;
                """, "table.pbl/n_bo_trade_union.sru, d_tb_trade_union_detail.srd"),
            ["occupation"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.occupation
                WHERE book = @book
                ORDER BY occupation;
                """, "table.pbl/n_bo_occupation.sru, d_tb_occupation_detail.srd"),
            ["occupationRates"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.occupation_rate
                WHERE book = @book
                ORDER BY occupation, effective_date DESC;
                """, "table.pbl/n_bo_occupation_rate.sru, d_tb_occupation_rate_detail.srd"),
            ["premiumTypes"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.premium_type
                ORDER BY premium_type;
                """, "shared_tables.pbl/n_bo_premium_type.sru, d_st_premium_type_detail.srd"),
            ["timesheetStatuses"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.timesheet_status
                ORDER BY timesheet_status;
                """, "shared_tables.pbl/n_bo_timesheet_status.sru, d_st_timesheet_status_detail.srd"),
            ["wcbRates"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.wcb_rate
                WHERE book = @book
                ORDER BY wcb_class, tax_year DESC;
                """, "table.pbl/n_bo_wcb_rate.sru, d_tb_wcb_rate.srd"),
            ["federalTax"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.federal_tax
                ORDER BY effective_date DESC;
                """, "shared_tables.pbl/n_bo_federal_tax.sru, d_st_federal_tax_detail.srd"),
            ["provinceIncomeTax"] = new("""
                SELECT TOP (@limit) *
                FROM dbo.province_income_tax
                ORDER BY province, effective_date DESC;
                """, "shared_tables.pbl/n_bo_province_income_tax.sru, d_st_province_income_tax.srd")
        };

    private static async Task<PayrollListResult> QueryListAsync(string connectionString, PayrollListRequest request, string sql)
    {
        var normalized = NormalizeListRequest(request);
        var rows = await QueryDictionaryAsync(connectionString, sql, [
            Parameter("@book", SqlDbType.VarChar, normalized.Book, 8),
            Parameter("@limit", SqlDbType.Int, normalized.Limit),
            Parameter("@search", SqlDbType.VarChar, normalized.Search, 200),
            Parameter("@searchLike", SqlDbType.VarChar, $"%{EscapeLike(normalized.Search)}%", 204),
            Parameter("@includeHistory", SqlDbType.Bit, normalized.IncludeHistory)
        ]);

        return new PayrollListResult(normalized.Book, normalized.Search, normalized.Limit, rows, rows.Count);
    }

    private static async Task<IReadOnlyList<Dictionary<string, object?>>> QueryDictionaryAsync(
        string connectionString,
        string sql,
        IReadOnlyList<SqlParameter> parameters)
    {
        var rows = new List<Dictionary<string, object?>>();
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        command.CommandTimeout = 60;
        foreach (var parameter in parameters)
        {
            command.Parameters.Add(CloneParameter(parameter));
        }

        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            rows.Add(ReadDictionary(reader));
        }

        return rows;
    }

    private static async Task<Dictionary<string, object?>?> QuerySingleDictionaryAsync(
        string connectionString,
        string sql,
        IReadOnlyList<SqlParameter> parameters)
    {
        var rows = await QueryDictionaryAsync(connectionString, sql, parameters);
        return rows.FirstOrDefault();
    }

    private static async Task<IReadOnlyList<PayrollLookupOption>> QueryLookupAsync(string connectionString, string sql, string book)
    {
        var rows = new List<PayrollLookupOption>();
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        command.Parameters.Add(Parameter("@book", SqlDbType.VarChar, book, 8));
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            rows.Add(new PayrollLookupOption(ReadString(reader, "value"), ReadString(reader, "label")));
        }

        return rows;
    }

    private static Dictionary<string, object?> ReadDictionary(SqlDataReader reader)
    {
        var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < reader.FieldCount; i++)
        {
            row[ToCamelCase(reader.GetName(i))] = reader.IsDBNull(i) ? null : reader.GetValue(i);
        }

        return row;
    }

    private static string ReadString(SqlDataReader reader, string name)
    {
        var ordinal = reader.GetOrdinal(name);
        return reader.IsDBNull(ordinal) ? string.Empty : Convert.ToString(reader.GetValue(ordinal))?.Trim() ?? string.Empty;
    }

    private static SqlParameter Parameter(string name, SqlDbType type, object? value, int? size = null)
    {
        var parameter = new SqlParameter(name, type)
        {
            Value = value ?? DBNull.Value
        };

        if (size.HasValue)
        {
            parameter.Size = size.Value;
        }

        return parameter;
    }

    private static SqlParameter CloneParameter(SqlParameter source)
    {
        var parameter = new SqlParameter(source.ParameterName, source.SqlDbType)
        {
            Direction = source.Direction,
            IsNullable = source.IsNullable,
            Value = source.Value
        };

        if (source.Size > 0)
        {
            parameter.Size = source.Size;
        }

        parameter.Precision = source.Precision;
        parameter.Scale = source.Scale;
        return parameter;
    }

    private static NormalizedPayrollListRequest NormalizeListRequest(PayrollListRequest request) =>
        new(
            NormalizeBook(request.Book),
            Normalize(request.Search),
            ClampLimit(request.Limit),
            request.IncludeHistory);

    private static int ClampLimit(int? limit) => Math.Clamp(limit ?? DefaultListLimit, 1, 1_000);

    private static string NormalizeBook(string? book)
    {
        var normalized = Normalize(book).ToUpperInvariant();
        return normalized.Length == 0 ? "ABIODEMO" : normalized;
    }

    private static string Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? string.Empty : value.Trim();

    private static string ToCamelCase(string value)
    {
        var cleaned = SnakeCaseRegex().Replace(value, match => match.Groups[1].Value.ToUpperInvariant());
        return cleaned.Length <= 1 ? cleaned.ToLowerInvariant() : char.ToLowerInvariant(cleaned[0]) + cleaned[1..];
    }

    private static string EscapeLike(string value) => value.Replace("[", "[[]").Replace("%", "[%]").Replace("_", "[_]");

    private static IReadOnlyList<string> EmployeeTabs() =>
        ["Details", "Cheque & Dues", "Incentive & Accrual", "Premiums", "Earnings", "WCB"];

    private static IReadOnlyList<string> ChequeTabs() =>
        ["Gross & Net", "Earn & Loss", "Premiums", "WCB", "Union", "Occupation"];

    private static IReadOnlyList<LegacyProgramReference> TimesheetReferences() =>
    [
        Ref("payroll.pbl", "w_pr_timesheet.srw", "Timesheet Entry window"),
        Ref("payroll.pbl", "n_bo_timesheet.sru", "Timesheet BO validation/defaults/calculation helpers"),
        Ref("payroll.pbl", "n_bo_timesheet_premium.sru", "Timesheet premium child BO"),
        Ref("payroll.pbl", "d_pr_timesheet_detail.srd", "Timesheet detail visual/update DataWindow"),
        Ref("payroll.pbl", "d_bo_timesheet.srd", "Timesheet update DataWindow")
    ];

    private static IReadOnlyList<LegacyProgramReference> ChequeReferences() =>
    [
        Ref("payroll.pbl", "w_pr_pr_cheque.srw", "Cheque Entry window and tab wiring"),
        Ref("payroll.pbl", "n_bo_pr_cheque.sru", "Cheque BO validation/defaults/child registrations"),
        Ref("payroll.pbl", "d_bo_pr_cheque.srd", "Cheque update DataWindow"),
        Ref("payroll.pbl", "n_bo_pr_cheque_premium.sru", "Cheque premium child BO"),
        Ref("payroll.pbl", "n_bo_pr_cheque_trade_union.sru", "Cheque union child BO"),
        Ref("payroll.pbl", "n_bo_pr_cheque_wcb.sru", "Cheque WCB child BO"),
        Ref("payroll.pbl", "n_bo_pr_cheque_queue.sru", "Cheque queue child BO"),
        Ref("payroll.pbl", "n_bo_timesheet.sru", "Timesheet child updates")
    ];

    private static LegacyProgramReference Ref(string library, string objectName, string role) => new(library, objectName, role);

    [GeneratedRegex("_(.)")]
    private static partial Regex SnakeCaseRegex();

    private sealed record NormalizedPayrollListRequest(string Book, string Search, int Limit, bool IncludeHistory);

    private sealed record PayrollSetupQuery(string Sql, string LegacySource);
}

public sealed record PayrollModuleInventory(
    string Module,
    string Status,
    IReadOnlyList<string> SourceLibraries,
    IReadOnlyList<string> MenuPrograms,
    IReadOnlyList<PayrollCommandDefinition> Commands,
    IReadOnlyList<string> ReadModels,
    IReadOnlyList<string> SafetyNotes);

public sealed record PayrollCommandDefinition(
    string Name,
    string DisplayName,
    string Description,
    string LegacyProgram,
    string Status,
    IReadOnlyList<LegacyProgramReference> LegacyReferences);

public sealed record PayrollListRequest(
    string Book,
    string? Search = null,
    int? Limit = null,
    bool IncludeHistory = false);

public sealed record PayrollListResult(
    string Book,
    string Search,
    int Limit,
    IReadOnlyList<Dictionary<string, object?>> Rows,
    int RowCount);

public sealed record PayrollRecordResult(
    string RecordType,
    string Status,
    string Message,
    Dictionary<string, object?>? Header,
    IReadOnlyDictionary<string, IReadOnlyList<Dictionary<string, object?>>> Children,
    IReadOnlyList<string> Tabs)
{
    public static PayrollRecordResult Found(
        string recordType,
        Dictionary<string, object?> header,
        IReadOnlyDictionary<string, IReadOnlyList<Dictionary<string, object?>>> children,
        IReadOnlyList<string> tabs) =>
        new(recordType, "ok", "", header, children, tabs);

    public static PayrollRecordResult NotFound(string recordType, string message) =>
        new(recordType, "not-found", message, null, new Dictionary<string, IReadOnlyList<Dictionary<string, object?>>>(), []);
}

public sealed record PayrollSetupResult(
    string SetupArea,
    string Status,
    IReadOnlyList<Dictionary<string, object?>> Rows,
    string LegacySourceOrMessage);

public sealed record PayrollLookupResult(
    string Book,
    IReadOnlyDictionary<string, IReadOnlyList<PayrollLookupOption>> Fields);

public sealed record PayrollLookupOption(string Value, string Label);

public sealed record PayrollValidationCatalog(
    string Version,
    IReadOnlyList<LegacyProgramReference> SourceObjects,
    IReadOnlyDictionary<string, IReadOnlyList<PayrollValidationRule>> RecordTypes);

public sealed record PayrollValidationRule(
    string RuleId,
    string Field,
    string RuleType,
    string Message,
    string Severity,
    IReadOnlyList<string> AllowedValues,
    IReadOnlyList<string> AppliesOn,
    string LegacySource,
    string FrontendHint);

public sealed record PayrollValidationError(
    string Field,
    string Message,
    string RuleId,
    string Severity);

public sealed record PayrollCommandRequest(
    string Book,
    string CommandName,
    string UserId,
    Dictionary<string, object?> Payload,
    IReadOnlyList<string>? ChangedFields = null,
    bool DryRun = true);

public sealed record PayrollCommandResult(
    string Status,
    string CommandName,
    string Message,
    string LegacyProgram,
    IReadOnlyList<LegacyProgramReference> RequiredLegacyReferences,
    IReadOnlyList<string> RequiredMigrationSteps,
    IReadOnlyList<string> ChangedFields,
    IReadOnlyList<PayrollValidationError> ValidationErrors);
