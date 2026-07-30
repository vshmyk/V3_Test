using System.Runtime.InteropServices;
using System.Text;

if (args.Length < 3)
{
    Console.Error.WriteLine("Usage: PbSourceExporter <pbUtilitiesDir> <sourceRoot> <outputRoot> [libraryName] [runtimeDir]");
    return 2;
}

var utilitiesDir = Path.GetFullPath(args[0]);
var sourceRoot = Path.GetFullPath(args[1]);
var outputRoot = Path.GetFullPath(args[2]);
var libraryFilter = args.Length >= 4 ? args[3] : "jobcost.pbl";
var runtimeDir = args.Length >= 5 ? Path.GetFullPath(args[4]) : utilitiesDir;
var orcaDll = Path.Combine(utilitiesDir, "pborc.dll");

if (!File.Exists(orcaDll))
{
    Console.Error.WriteLine($"pborc.dll not found: {orcaDll}");
    return 3;
}

Directory.CreateDirectory(outputRoot);
NativeMethods.SetDefaultDllDirectories(0x00001000 | 0x00000400 | 0x00000200);
NativeMethods.AddDllDirectory(utilitiesDir);
NativeMethods.AddDllDirectory(runtimeDir);
NativeMethods.SetDllDirectory($"{utilitiesDir};{runtimeDir}");
NativeLibrary.SetDllImportResolver(typeof(Orca).Assembly, (libraryName, assembly, searchPath) =>
{
    if (libraryName.Equals("pborc.dll", StringComparison.OrdinalIgnoreCase))
    {
        return NativeLibrary.Load(orcaDll);
    }

    return IntPtr.Zero;
});

var targets = BuildTargets(libraryFilter);

var session = Orca.PBORCA_SessionOpen();
if (session == IntPtr.Zero)
{
    Console.Error.WriteLine("Could not open ORCA session.");
    return 4;
}

try
{
    var config = new OrcaConfigSession
    {
        Clobber = 2, // PBORCA_CLOBBER_ALWAYS
        ExportEncoding = 1, // PBORCA_UTF8
        ExportHeaders = 1,
        ExportIncludeBinary = 0,
        ExportCreateFile = 1,
        ExportDirectory = outputRoot,
        ImportEncoding = 1
    };

    var configureResult = Orca.PBORCA_ConfigureSession(session, ref config);
    if (configureResult != 0)
    {
        Console.Error.WriteLine($"PBORCA_ConfigureSession returned {configureResult}: {GetOrcaError(session)}");
        return 5;
    }

    var failures = 0;
    foreach (var target in targets)
    {
        var libraryPath = Path.Combine(sourceRoot, target.LibraryName);
        var result = Orca.PBORCA_LibraryEntryExport(session, libraryPath, target.EntryName, target.EntryType, null, 0);
        if (result != 0)
        {
            failures++;
            Console.Error.WriteLine($"FAILED {target.LibraryName}/{target.EntryName}{target.Extension}: {result} {GetOrcaError(session)}");
            continue;
        }

        Console.WriteLine($"exported {target.LibraryName}/{target.EntryName}{target.Extension}");
    }

    return failures == 0 ? 0 : 10;
}
finally
{
    Orca.PBORCA_SessionClose(session);
}

static string GetOrcaError(IntPtr session)
{
    var buffer = new StringBuilder(4096);
    Orca.PBORCA_SessionGetError(session, buffer, buffer.Capacity);
    return buffer.ToString();
}

static ExportTarget[] BuildTargets(string libraryFilter)
{
    var library = Path.GetFileName(libraryFilter).ToLowerInvariant();
    return library switch
    {
        "payroll.pbl" =>
        [
            Window(libraryFilter, "w_pr_employee"),
            Window(libraryFilter, "w_pr_field_timesheet"),
            Window(libraryFilter, "w_pr_timesheet"),
            Window(libraryFilter, "w_pr_pr_cheque"),
            Window(libraryFilter, "w_pr_paystubs_email"),
            UserObject(libraryFilter, "n_bo_employee"),
            UserObject(libraryFilter, "n_bo_employee_earning"),
            UserObject(libraryFilter, "n_bo_employee_premium"),
            UserObject(libraryFilter, "n_bo_employee_purchase"),
            UserObject(libraryFilter, "n_bo_employee_wcb"),
            UserObject(libraryFilter, "n_bo_field_timesheet"),
            UserObject(libraryFilter, "n_bo_timesheet"),
            UserObject(libraryFilter, "n_bo_timesheet_premium"),
            UserObject(libraryFilter, "n_bo_pr_cheque"),
            UserObject(libraryFilter, "n_bo_pr_cheque_save"),
            UserObject(libraryFilter, "n_bo_pr_cheque_premium"),
            UserObject(libraryFilter, "n_bo_pr_cheque_trade_union"),
            UserObject(libraryFilter, "n_bo_pr_cheque_wcb"),
            UserObject(libraryFilter, "n_bo_pr_cheque_queue"),
            UserObject(libraryFilter, "u_cst_employee_detail"),
            UserObject(libraryFilter, "u_cst_pr_employee_detail"),
            UserObject(libraryFilter, "u_cst_pr_employee_cheque"),
            UserObject(libraryFilter, "u_cst_pr_cheque_premium_selection"),
            DataWindow(libraryFilter, "d_pr_employee"),
            DataWindow(libraryFilter, "d_pr_employee_filter"),
            DataWindow(libraryFilter, "d_pr_employee_list"),
            DataWindow(libraryFilter, "d_pr_employee_earning"),
            DataWindow(libraryFilter, "d_pr_employee_premium"),
            DataWindow(libraryFilter, "d_pr_employee_wcb"),
            DataWindow(libraryFilter, "d_bo_employee"),
            DataWindow(libraryFilter, "d_bo_employee_earning"),
            DataWindow(libraryFilter, "d_bo_employee_premium"),
            DataWindow(libraryFilter, "d_bo_employee_purchase"),
            DataWindow(libraryFilter, "d_bo_employee_wcb"),
            DataWindow(libraryFilter, "d_pr_field_timesheet_list"),
            DataWindow(libraryFilter, "d_pr_field_timesheet_filter"),
            DataWindow(libraryFilter, "d_pr_field_timesheet_detail"),
            DataWindow(libraryFilter, "d_bo_field_timesheet"),
            DataWindow(libraryFilter, "d_pr_timesheet_list_new"),
            DataWindow(libraryFilter, "d_pr_timesheet_filter_new"),
            DataWindow(libraryFilter, "d_pr_timesheet_detail"),
            DataWindow(libraryFilter, "d_pr_timesheet_premium"),
            DataWindow(libraryFilter, "d_pr_timesheet_premium_display"),
            DataWindow(libraryFilter, "d_pr_timesheet_preliminary"),
            DataWindow(libraryFilter, "d_pr_timesheet_prn"),
            DataWindow(libraryFilter, "d_bo_timesheet"),
            DataWindow(libraryFilter, "d_bo_timesheet_premium"),
            DataWindow(libraryFilter, "d_pr_pr_cheque_list"),
            DataWindow(libraryFilter, "d_pr_pr_cheque_filter"),
            DataWindow(libraryFilter, "d_pr_pr_cheque_approve"),
            DataWindow(libraryFilter, "d_pr_pr_cheque_prn"),
            DataWindow(libraryFilter, "d_pr_cheque_earn"),
            DataWindow(libraryFilter, "d_pr_cheque_pay"),
            DataWindow(libraryFilter, "d_pr_cheque_premium"),
            DataWindow(libraryFilter, "d_pr_cheque_wcb"),
            DataWindow(libraryFilter, "d_pr_cheque_trade_union"),
            DataWindow(libraryFilter, "d_pr_cheque_occupation"),
            DataWindow(libraryFilter, "d_bo_pr_cheque"),
            DataWindow(libraryFilter, "d_bo_pr_cheque_premium"),
            DataWindow(libraryFilter, "d_bo_pr_cheque_trade_union"),
            DataWindow(libraryFilter, "d_bo_pr_cheque_wcb"),
            DataWindow(libraryFilter, "d_bo_pr_cheque_queue"),
            DataWindow(libraryFilter, "d_prtran_cheques"),
            DataWindow(libraryFilter, "d_prtran_timesheet"),
            DataWindow(libraryFilter, "d_prtran_cheque_summary"),
        ],
        "timesheet.pbl" =>
        [
            DataWindow(libraryFilter, "d_pr_timesheet_detail")
        ],
        "reports_pr.pbl" =>
        [
            DataWindow(libraryFilter, "d_report_pr_employee_list"),
            DataWindow(libraryFilter, "d_report_pr_employee_report_1"),
            DataWindow(libraryFilter, "d_pr_employee_prn"),
            DataWindow(libraryFilter, "d_report_pr_timesheet_hours_by_employee"),
            DataWindow(libraryFilter, "d_report_pr_timesheet_by_centre_in_job"),
            DataWindow(libraryFilter, "d_report_pr_timesheet_by_cheque"),
            DataWindow(libraryFilter, "d_report_pr_timesheet_employees_without"),
            DataWindow(libraryFilter, "d_report_pr_cheques_by_employee"),
            DataWindow(libraryFilter, "d_report_pr_cheques_by_gl_period"),
            DataWindow(libraryFilter, "d_report_pr_cheques_by_trade_union"),
            DataWindow(libraryFilter, "d_report_pr_cheques_pd7a"),
            DataWindow(libraryFilter, "d_report_pr_cheques_union_remittance")
        ],
        "reports_jc.pbl" => HintedDataWindows(libraryFilter),
        "shared_tables.pbl" =>
        [
            Window(libraryFilter, "w_st_crew"),
            Window(libraryFilter, "w_st_pay_period"),
            Window(libraryFilter, "w_st_premium_type"),
            Window(libraryFilter, "w_st_timesheet_status"),
            Window(libraryFilter, "w_st_federal_tax"),
            Window(libraryFilter, "w_st_province_tax"),
            UserObject(libraryFilter, "n_bo_pay_period"),
            UserObject(libraryFilter, "n_bo_premium_type"),
            UserObject(libraryFilter, "n_bo_timesheet_status"),
            UserObject(libraryFilter, "n_bo_federal_tax"),
            UserObject(libraryFilter, "n_bo_province_income_tax"),
            DataWindow(libraryFilter, "d_st_pay_period_detail"),
            DataWindow(libraryFilter, "d_st_premium_type_detail"),
            DataWindow(libraryFilter, "d_st_timesheet_status_detail"),
            DataWindow(libraryFilter, "d_st_federal_tax_detail"),
            DataWindow(libraryFilter, "d_st_province_income_tax")
        ],
        "table.pbl" =>
        [
            Window(libraryFilter, "w_tb_trade_union"),
            Window(libraryFilter, "w_tb_occupation"),
            Window(libraryFilter, "w_st_premium_type"),
            UserObject(libraryFilter, "n_bo_trade_union"),
            UserObject(libraryFilter, "n_bo_trade_union_rate"),
            UserObject(libraryFilter, "n_bo_trade_union_benefit"),
            UserObject(libraryFilter, "n_bo_trade_union_premium"),
            UserObject(libraryFilter, "n_bo_occupation"),
            UserObject(libraryFilter, "n_bo_occupation_rate"),
            UserObject(libraryFilter, "n_bo_wcb_class"),
            UserObject(libraryFilter, "n_bo_wcb_rate"),
            DataWindow(libraryFilter, "d_tb_trade_union_detail"),
            DataWindow(libraryFilter, "d_tb_trade_union_rate"),
            DataWindow(libraryFilter, "d_tb_trade_union_benefit_selected"),
            DataWindow(libraryFilter, "d_tb_trade_union_premium_selected"),
            DataWindow(libraryFilter, "d_tb_occupation_detail"),
            DataWindow(libraryFilter, "d_tb_occupation_rate_detail"),
            DataWindow(libraryFilter, "d_tb_wcb_class_detail"),
            DataWindow(libraryFilter, "d_tb_wcb_rate")
        ],
        _ =>
        [
            Window(libraryFilter, "w_jc_job"),
            DataWindow(libraryFilter, "d_jc_job_detail"),
            DataWindow(libraryFilter, "d_jc_job_detail_finance"),
            UserObject(libraryFilter, "n_bo_job"),
            DataWindow(libraryFilter, "d_bo_job"),
            UserObject(libraryFilter, "u_cst_jc_job_detail"),
            UserObject(libraryFilter, "u_cst_jc_job_detail_finance"),
            DataWindow(libraryFilter, "d_bo_job_shipping_info"),
            DataWindow(libraryFilter, "d_jc_job_shipping_info_detail"),
            DataWindow(libraryFilter, "d_bo_job_checklist"),
            DataWindow(libraryFilter, "d_bo_job_document"),
            DataWindow(libraryFilter, "d_jc_job_document_detail")
        ]
    };
}

static ExportTarget[] HintedDataWindows(string libraryFilter)
{
    var library = Path.GetFileName(libraryFilter);
    var hintPath = Path.GetFullPath(Path.Combine(
        AppContext.BaseDirectory,
        "..",
        "..",
        "..",
        "..",
        "..",
        "..",
        "..",
        "inventory-binary-hints",
        "pbl-binary-object-hints.csv"));

    if (!File.Exists(hintPath))
    {
        hintPath = Path.GetFullPath(Path.Combine(
            Directory.GetCurrentDirectory(),
            "tools",
            "abio-modernization",
            "inventory-binary-hints",
            "pbl-binary-object-hints.csv"));
    }

    if (!File.Exists(hintPath))
    {
        Console.Error.WriteLine($"Hint inventory not found for {library}: {hintPath}");
        return [];
    }

    return File.ReadLines(hintPath)
        .Skip(1)
        .Select(line => line.Split(','))
        .Where(parts => parts.Length >= 4)
        .Where(parts => parts[0].Trim('"').Equals(library, StringComparison.OrdinalIgnoreCase))
        .Where(parts => parts[2].Trim('"').Equals(".srd", StringComparison.OrdinalIgnoreCase))
        .Where(parts => parts[3].Trim('"').Equals("datawindow", StringComparison.OrdinalIgnoreCase))
        .Select(parts => Path.GetFileNameWithoutExtension(parts[1].Trim('"')))
        .Where(name => !string.IsNullOrWhiteSpace(name))
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
        .Select(name => DataWindow(libraryFilter, name))
        .ToArray();
}

static ExportTarget DataWindow(string libraryName, string entryName) => new(libraryName, entryName, OrcaType.DataWindow, ".srd");

static ExportTarget UserObject(string libraryName, string entryName) => new(libraryName, entryName, OrcaType.UserObject, ".sru");

static ExportTarget Window(string libraryName, string entryName) => new(libraryName, entryName, OrcaType.Window, ".srw");

internal enum OrcaType
{
    Application = 0,
    DataWindow = 1,
    Function = 2,
    Menu = 3,
    Query = 4,
    Structure = 5,
    UserObject = 6,
    Window = 7,
    Pipeline = 8,
    Project = 9,
    ProxyObject = 10,
    Binary = 11
}

internal sealed record ExportTarget(string LibraryName, string EntryName, OrcaType EntryType, string Extension);

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
internal struct OrcaConfigSession
{
    public int Clobber;
    public int ExportEncoding;
    public int ExportHeaders;
    public int ExportIncludeBinary;
    public int ExportCreateFile;
    [MarshalAs(UnmanagedType.LPWStr)]
    public string ExportDirectory;
    public int ImportEncoding;
    public IntPtr Filler1;
    public IntPtr Filler2;
    public IntPtr Filler3;
    public IntPtr Filler4;
}

internal static partial class Orca
{
    [DllImport("pborc.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern IntPtr PBORCA_SessionOpen();

    [DllImport("pborc.dll", CallingConvention = CallingConvention.Winapi)]
    public static extern void PBORCA_SessionClose(IntPtr session);

    [DllImport("pborc.dll", CallingConvention = CallingConvention.Winapi, CharSet = CharSet.Unicode)]
    public static extern void PBORCA_SessionGetError(IntPtr session, StringBuilder errorBuffer, int errorBufferSize);

    [DllImport("pborc.dll", CallingConvention = CallingConvention.Winapi, CharSet = CharSet.Unicode)]
    public static extern int PBORCA_ConfigureSession(IntPtr session, ref OrcaConfigSession config);

    [DllImport("pborc.dll", CallingConvention = CallingConvention.Winapi, CharSet = CharSet.Unicode)]
    public static extern int PBORCA_LibraryEntryExport(
        IntPtr session,
        string libraryName,
        string entryName,
        OrcaType entryType,
        [MarshalAs(UnmanagedType.LPWStr)] string? exportBuffer,
        int exportBufferSize);
}

internal static partial class NativeMethods
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetDllDirectory(string pathName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetDefaultDllDirectories(uint directoryFlags);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern IntPtr AddDllDirectory(string newDirectory);
}
