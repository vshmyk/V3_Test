import { CommonModule } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectorRef, Component, ElementRef, HostListener, NgZone, OnInit, inject } from '@angular/core';
import { FormBuilder, FormsModule, ReactiveFormsModule } from '@angular/forms';
import { AgGridAngular } from 'ag-grid-angular';
import { AllCommunityModule, ColDef, ICellRendererParams, ModuleRegistry } from 'ag-grid-community';
import { PayrollConsoleComponent } from '../payroll/payroll-console.component';
import { ArrowFieldNavigationDirective } from '../shared/arrow-field-navigation.directive';
import { CoreApiService } from './core-api.service';
import {
  CoreBookRow,
  CoreDataset,
  CoreGridRow,
  CoreJobReportColumn,
  CoreJobReportResponse,
  CoreJobOverview,
  CoreJobRecordTab,
  CoreLookupOption,
  CoreMenuNode,
  CoreSummaryResponse,
  JobRecordSaveCommandResponse
} from './core.models';

ModuleRegistry.registerModules([AllCommunityModule]);

interface CoreTab {
  id: CoreDataset;
  label: string;
}

interface LegacyListColumn {
  field: string;
  headerName: string;
  width?: number;
  minWidth?: number;
  flex?: number;
}

interface ReportGroupingResult {
  node: CoreMenuNode | null;
  categories: CoreMenuNode[];
  looseReports: CoreMenuNode[];
  reportMenuTemplate: CoreMenuNode | null;
}

interface RecordReference {
  dataset: CoreDataset;
  value: string;
  matchFields: string[];
  sourceRow?: CoreGridRow;
}

interface RecordField {
  field: string;
  label: string;
  value: CoreGridRow[string];
  displayValue: string;
}

interface RecordView {
  dataset: CoreDataset;
  title: string;
  subtitle: string;
  row: CoreGridRow;
  fields: RecordField[];
}

interface RecordWorkspaceTab {
  id: string;
  label: string;
  subtitle: string;
  view: RecordView;
}

interface LegacyFormField {
  label: string;
  field: string;
  descriptionField?: string;
  wide?: boolean;
  protected?: boolean;
  editLocked?: boolean;
  required?: boolean;
}

interface LegacyFormSection {
  title: string;
  columns: LegacyFormField[][];
}

interface JobRecordTab {
  id: CoreJobRecordTab;
  label: string;
}

type RecordActionId = 'new' | 'edit' | 'save' | 'cancel' | 'delete';

interface RecordAction {
  id: RecordActionId;
  label: string;
  enabled: boolean;
  primary?: boolean;
  title?: string;
}

interface JobInsightMetric {
  label: string;
  value: string;
  tone?: 'good' | 'watch' | 'alert';
}

interface JobInsightAction {
  label: string;
  detail: string;
  tab?: CoreJobRecordTab;
  disabled?: boolean;
}

interface JobRelatedTab {
  id: string;
  label: string;
  subtitle: string;
  field: string;
  value: string;
  status: string;
  fields: RecordField[];
}

interface ActiveJobReport {
  node: CoreMenuNode;
  response: CoreJobReportResponse;
  columnDefs: ColDef<CoreGridRow>[];
}

interface JobReportFilterDefinition {
  key: string;
  label: string;
  type: 'text' | 'select' | 'date';
  placeholder?: string;
  options?: { value: string; label: string }[];
}

interface ModernMenuGroup {
  id: string;
  label: string;
  description: string;
  iconClass: string;
  actionLabel: string;
  links: ModernMenuLink[];
  items: CoreMenuNode[];
}

interface ModernMenuLink {
  label: string;
  iconClass: string;
  groupId?: string;
  dataset?: CoreDataset;
  payrollView?: string;
  payroll?: boolean;
  legacyProgram?: string;
  legacyReport?: string;
  children?: ModernMenuLink[];
}

interface ModernLandingCard {
  label: string;
  value: string;
  detail: string;
  iconClass: string;
  tone?: 'good' | 'watch' | 'alert';
  dataset?: CoreDataset;
}

interface ModernActionCard {
  label: string;
  detail: string;
  iconClass: string;
  groupId?: string;
  dataset?: CoreDataset;
  payroll?: boolean;
  legacyProgram?: string;
  legacyReport?: string;
}

interface ModernRecentRecord {
  type: string;
  name: string;
  detail: string;
  updated: string;
  iconClass: string;
  dataset?: CoreDataset;
}

interface ModernKpi {
  label: string;
  value: string;
  delta: string;
  direction: 'up' | 'down';
}

@Component({
  selector: 'app-core-console',
  imports: [CommonModule, FormsModule, ReactiveFormsModule, AgGridAngular, PayrollConsoleComponent, ArrowFieldNavigationDirective],
  templateUrl: './core-console.component.html',
  styleUrl: './core-console.component.scss'
})
export class CoreConsoleComponent implements OnInit {
  private readonly api = inject(CoreApiService);
  private readonly fb = inject(FormBuilder);
  private readonly changeDetector = inject(ChangeDetectorRef);
  private readonly zone = inject(NgZone);
  private readonly elementRef = inject<ElementRef<HTMLElement>>(ElementRef);

  readonly form = this.fb.nonNullable.group({
    book: ['']
  });

  readonly tabs: CoreTab[] = [
    { id: 'clients', label: 'Clients' },
    { id: 'jobs', label: 'Jobs' },
    { id: 'vendors', label: 'Vendors' },
    { id: 'ap-invoices', label: 'AP Invoices' },
    { id: 'ar-invoices', label: 'AR Invoices' },
    { id: 'timesheets', label: 'Timesheets' }
  ];

  readonly defaultColDef: ColDef = {
    filter: true,
    resizable: true,
    sortable: true
  };

  readonly jobRecordTabs: JobRecordTab[] = [
    { id: 'details', label: 'Details' },
    { id: 'financial', label: 'Financial' },
    { id: 'shipping', label: 'Shipping' },
    { id: 'checklist', label: 'Checklist' },
    { id: 'documents', label: 'Supporting Documents' }
  ];

  readonly clientFormSections: LegacyFormSection[] = [
    {
      title: 'client office',
      columns: [
        [
          { label: 'client', field: 'clientId', editLocked: true, required: true },
          { label: 'name', field: 'name', required: true },
          { label: 'city', field: 'city' }
        ],
        [
          { label: 'province', field: 'province' },
          { label: 'active?', field: 'activeFlag' },
          { label: 'last update', field: 'lastUpdate', protected: true }
        ]
      ]
    },
    {
      title: 'accounts receivable',
      columns: [
        [
          { label: 'net out', field: 'netOut', protected: true },
          { label: 'purchase', field: 'purchase', protected: true }
        ],
        [
          { label: 'payment', field: 'payment', protected: true }
        ]
      ]
    }
  ];

  readonly jobFinancialSections: LegacyFormSection[] = [
    {
      title: 'contract',
      columns: [
        [
          { label: 'contract amount', field: 'contractAmount' },
          { label: 'original budget', field: 'originalBudget' },
          { label: 'current budget', field: 'currentBudget' },
          { label: 'commitment', field: 'commitment' }
        ],
        [
          { label: 'to date cost', field: 'toDateCost' },
          { label: 'to date revenue', field: 'toDateRevenue' },
          { label: 'to date payment', field: 'toDatePayment' },
          { label: 'expected cost', field: 'expectedCost' },
          { label: 'expected revenue', field: 'expectedRevenue' }
        ]
      ]
    },
    {
      title: 'cost periods',
      columns: [
        [
          { label: 'year open cost', field: 'yearOpenCost' },
          { label: 'period 1 cost', field: 'period1Cost' },
          { label: 'period 2 cost', field: 'period2Cost' },
          { label: 'period 3 cost', field: 'period3Cost' },
          { label: 'period 4 cost', field: 'period4Cost' },
          { label: 'period 5 cost', field: 'period5Cost' },
          { label: 'period 6 cost', field: 'period6Cost' }
        ],
        [
          { label: 'period 7 cost', field: 'period7Cost' },
          { label: 'period 8 cost', field: 'period8Cost' },
          { label: 'period 9 cost', field: 'period9Cost' },
          { label: 'period 10 cost', field: 'period10Cost' },
          { label: 'period 11 cost', field: 'period11Cost' },
          { label: 'period 12 cost', field: 'period12Cost' }
        ]
      ]
    },
    {
      title: 'revenue periods',
      columns: [
        [
          { label: 'year open revenue', field: 'yearOpenRevenue' },
          { label: 'period 1 revenue', field: 'period1Revenue' },
          { label: 'period 2 revenue', field: 'period2Revenue' },
          { label: 'period 3 revenue', field: 'period3Revenue' },
          { label: 'period 4 revenue', field: 'period4Revenue' },
          { label: 'period 5 revenue', field: 'period5Revenue' },
          { label: 'period 6 revenue', field: 'period6Revenue' }
        ],
        [
          { label: 'period 7 revenue', field: 'period7Revenue' },
          { label: 'period 8 revenue', field: 'period8Revenue' },
          { label: 'period 9 revenue', field: 'period9Revenue' },
          { label: 'period 10 revenue', field: 'period10Revenue' },
          { label: 'period 11 revenue', field: 'period11Revenue' },
          { label: 'period 12 revenue', field: 'period12Revenue' }
        ]
      ]
    }
  ];

  readonly jobFormSections: LegacyFormSection[] = [
    {
      title: 'jobsite office',
      columns: [
        [
          { label: 'description', field: 'description', wide: true, required: true },
          { label: 'address 1', field: 'address1', wide: true },
          { label: 'address 2', field: 'address2', wide: true },
          { label: 'city', field: 'city' },
          { label: 'office phone', field: 'phone' }
        ],
        [
          { label: 'province', field: 'province', required: true },
          { label: 'country', field: 'country' },
          { label: 'postal code', field: 'postal' },
          { label: 'fax', field: 'fax' }
        ]
      ]
    },
    {
      title: 'accounts receivable',
      columns: [
        [
          { label: 'client', field: 'client', descriptionField: 'clientName' },
          { label: 'client job', field: 'clientJob' },
          { label: 'client P/O', field: 'clientPo' },
          { label: 'item', field: 'item' },
          { label: 'fixed price?', field: 'fixedPriceFlag', required: true },
          { label: 'admin fee', field: 'adminFeePercent' },
          { label: 'disperse labour billings?', field: 'disperseLabourBillings', required: true },
          { label: 'additional hourly amounts', field: 'additionalHourlyAmounts' },
          { label: 'labour surcharge', field: 'labourSurchargePercent' }
        ],
        [
          { label: 'equipment revenue area', field: 'equipmentRevenueArea' },
          { label: 'equipment revenue centre', field: 'equipmentRevenueCentre' },
          { label: 'T&M equipment rate', field: 'equipmentRate' },
          { label: 'T&M labour rate', field: 'labourRate' },
          { label: 'labour markup', field: 'labourMarkupPercent' },
          { label: 'material markup', field: 'materialMarkupPercent' },
          { label: 'holdback', field: 'holdbackPercent' },
          { label: 'hourly amounts label', field: 'hourlyAmountsLabel', wide: true },
          { label: 'labour surcharge label', field: 'labourSurchargeLabel', wide: true }
        ]
      ]
    },
    {
      title: 'accounts payable',
      columns: [
        [
          { label: 'P/O use job address?', field: 'poUseJobAddress', required: true },
          { label: 'last job p/o', field: 'lastJobPo' }
        ],
        [
          { label: 'shipping message', field: 'shippingMessage', required: true },
          { label: '"Ship to:"', field: 'address1', wide: true, protected: true }
        ]
      ]
    },
    {
      title: 'payroll',
      columns: [
        [
          { label: 'reg hours/day', field: 'regHoursPerDay', required: true },
          { label: 'include staff hours?', field: 'includeStaffHours', required: true },
          { label: 'timesheet prefix', field: 'timesheetPrefix' },
          { label: 'last timesheet', field: 'lastTimesheet' }
        ],
        [
          { label: 'trade union group', field: 'tradeUnionGroup' },
          { label: 'concurrent crews?', field: 'concurrentCrews', required: true },
          { label: 'WCB class', field: 'wcbClass', descriptionField: 'wcbDescription', required: true },
          { label: 'G/HST rule', field: 'gstRule', descriptionField: 'gstDescription', required: true },
          { label: 'timesheet sign line', field: 'timesheetSignLine', wide: true },
          { label: 'timesheet message', field: 'timesheetMessage', wide: true }
        ]
      ]
    },
    {
      title: 'equipment',
      columns: [
        [
          { label: 'time entry sheet approver', field: 'timeEntrySheetApprover', descriptionField: 'siteContact', required: true }
        ]
      ]
    },
    {
      title: 'management',
      columns: [
        [
          { label: 'superintendent', field: 'superintendent', wide: true },
          { label: 'parent job', field: 'parentJob', required: true },
          { label: 'freeze budget?', field: 'freezeBudget', required: true },
          { label: 'job type', field: 'jobType', wide: true },
          { label: 'site contact', field: 'siteContact', wide: true }
        ],
        [
          { label: 'division', field: 'division', descriptionField: 'divisionDescription', required: true },
          { label: 'contract company', field: 'contractCompany' },
          { label: 'region', field: 'region', descriptionField: 'regionDescription' },
          { label: 'dashboard group', field: 'dashboardGroup', required: true },
          { label: 'site contact email', field: 'siteContactEmail', wide: true }
        ]
      ]
    },
    {
      title: 'dates',
      columns: [
        [
          { label: 'start date', field: 'startDate' },
          { label: 'shutdown start', field: 'shutdownStart' },
          { label: 'snapshot date', field: 'snapshotDate' }
        ],
        [
          { label: 'complete date', field: 'completeDate' },
          { label: 'shutdown end', field: 'shutdownEnd' },
          { label: 'last update', field: 'lastUpdate', editLocked: true }
        ]
      ]
    },
    {
      title: 'memo',
      columns: [[{ label: 'memo', field: 'memo', wide: true }]]
    }
  ];

  readonly jobFieldTooltips: Record<string, string> = {
    activeFlag: 'must be one of Yes or No - postings cannot be made against inactive jobs',
    additionalHourlyAmounts: 'This amount will be added for every hour worked on a job,\nregardless if it is overtime or regular time. Use it to\ntrack Time and Materials costs such as small tools, or,\nequipment amounts, such as scaffolding, that is negotiated\nas an hourly adder.\nUsed by the A/R Client Daily reports and for Client Time Sheets',
    address1: 'the job address and phone number are used in the printing of purchase orders',
    adminFeePercent: 'Admin fee will be included when A/R invoice is generated from daysheets',
    client: 'used for reporting purposes',
    clientJob: 'How the client identifies this job (used for reporting purposes)',
    clientPo: 'If the client has a purchase order, record it here (used for reporting purposes)',
    completeDate: 'blank or valid date after start date',
    concurrentCrews: 'Y = Yes, employees on crews for this job can also be on other crews or\nN = No, employees on crews for this job cannot be on other crews.\n(* Note that this setting is ignored when "concurrent crew memberships?" is "Y" on Properties Entry *)',
    country: 'valid country',
    dashboardGroup: 'entry in this field allows reporting by dashboard group',
    description: 'up to 25 characters in length',
    disperseLabourBillings: 'Used by A/R Intercompany Billing for T&M labour.\nYes - mirror dispersion logic with the T&M rates\nNo - apply T&M rates directly to dispersed labour',
    division: 'entry in this field allows reporting by division',
    equipmentRate: 'Used by A/R Intercompany Billing to determine equipment costs for this job. Clicking on the label will display the equipment rates.',
    equipmentRevenueArea: 'Used by A/R Intercompany Billing. Equipment invoices for this job will be posted to this area.',
    equipmentRevenueCentre: 'Used by A/R Intercompany Billing. Equipment invoices for this job will be posted to this centre.',
    fax: 'blank, 9999999 or 9999999999',
    fixedPriceFlag: 'For reporting purposes, Yes - the billings per area should not exceed the P/O amount for the area, or No',
    freezeBudget: 'Yes - protect the original budget fields on centres for this job, or No.\nSet this flag when the job original budget is correct and any future\nbudget changes should be recorded in the current budget fields.\n(Note: this flag is only available in Z action to prevent inadvertently\ndisabling the centre original budget fields.)',
    gstRule: 'default G/HST recovery rule applied to P/R Timesheets posted to this job',
    holdbackPercent: 'Invoices created from LEMS will hold back this percent',
    hourlyAmountsLabel: 'Label for the hourly amounts on the A/R Client Time Sheets',
    includeStaffHours: 'No or Yes to accumulate staff overtime, shutdown and travel hours in the job costing centres',
    item: 'used for reporting purposes',
    jobId: 'key field, up to 6 characters - no blanks',
    jobType: 'When the job is first added, one area and a set of centres will be created for this job based on this job type.\nAfter that invoices will use this job type to default centres.',
    labourMarkupPercent: 'T&M mark up on labour costs. Used primarily by the A/R Client Daily reports',
    labourRate: 'T&M mark up on labour costs by occupation. Clicking on the label will display the occupation rates.',
    labourSurchargeLabel: 'Label for the labour surcharge on the A/R Client Time Sheets',
    labourSurchargePercent: 'A percentage applied to total labour costs billed on a job,\nadding a separate line item to the A/R Client Time Sheets.\nUse it to recover costs that are proportional to labour,\nsuch as scaffolding, small tools and consumables,\nindirect supervision, or contractor overhead.\nThe surcharge is calculated on base labour billing amounts\nand does not compound with other surcharges.',
    lastJobPo: 'used by P/O entry to generate unique P/O numbers',
    lastTimesheet: 'unique identifier printed on the C/C Time Entry Sheet',
    lastUpdate: 'most recent change to this job, or to an invoice, payment or centre posted to this job',
    materialMarkupPercent: 'T&M mark up on material costs. Used primarily by the A/R Client Daily reports',
    memo: 'May be blank. Use <ctrl><enter> to start a new line.',
    parentJob: 'information in this field is used in the G/L Transaction reports to join sets of jobs',
    phone: 'blank, 9999999 or 9999999999',
    poUseJobAddress: 'Yes - P/Os use job address, or No - P/Os use company address',
    postal: 'blank or A9A9A9 (for Canada) or 99999 or 99999-9999 (for USA)',
    province: 'purchase orders and invoices pointed to a job use the job province code to determine the\ndefault tax type - clicking on the description will display the tax record for the entered province',
    regHoursPerDay: 'regular payroll hours per day, 7.0 to 12.0',
    region: 'job region',
    shippingMessage: 'Y - Display "Ship To:" on P/O, F - Display Ship FOB To: on P/O or N - No label on P/O shipping label',
    shutdownEnd: 'blank or valid date after shutdown start date and within next year',
    shutdownStart: 'Blank or valid date after job start and within next year.\nOvertime hours worked during the shutdown period are recorded as shutdown premium.',
    siteContact: 'Abio Field will send confirmation and Docusign emails here',
    siteContactEmail: 'Abio Field will send confirmation and Docusign emails here',
    snapshotDate: 'Date the last time the snapshot was updated.\nWhen a snapshot is taken all current centre costs, commitments and\nforecast amounts are copied to their corresponding snapshot values.\nAll invoices, P/Os and J/C labour dispersion records that make up these\ncosts and commitments are also stamped with the date of the snapshot.\nTaking a snapshot of a job progress and costs on a specific date\nallows the final cost of the job to be more accurately forecast.',
    startDate: 'valid date within last 10 years or next 30 days',
    timeEntrySheetApprover: "'P'roject manager, 'E'quipment manager or 'D'epartment.\nThis value will determine the titles displayed on the Equipment Timesheets report.",
    timesheetMessage: 'Special instructions to payroll staff for this job. Displays on the timesheet.',
    timesheetPrefix: 'if populated will be part of Ticket # in the C/C Time Entry Sheet report',
    timesheetSignLine: 'if populated will include a signing area at the bottom of the C/C Time Entry Sheet with this label',
    tradeUnionGroup: 'Use the union in this group with the matching occupation when importing payroll timesheets',
    wcbClass: 'Used during P/R Timesheet Entry to determine assessment rates.\nMust be an active WCB Class with rates for the current calendar year'
  };

  books: CoreBookRow[] = [];
  legacyMenuModules: CoreMenuNode[] = [];
  modernMenuGroups: ModernMenuGroup[] = [];
  selectedModernMenuGroupId = 'home';
  activeWorkspace: 'core' | 'payroll' | 'job-report' = 'core';
  activePayrollView = 'employees';
  expandedModernMenuLinks = new Set<string>([
    'home:Work Queue',
    'projects-jobs:Jobs',
    'people-payroll:Employees',
    'people-payroll:Time Entry',
    'purchasing-vendors:Vendors',
    'purchasing-vendors:Procurement',
    'customers-revenue:Accounts Receivable'
  ]);
  expandedMenuKeys = new Set<string>();
  selectedMenuNode: CoreMenuNode | null = null;
  menuQuickAccessActive = false;
  menuQuickAccessPath: CoreMenuNode[] = [];
  menuSearchText = '';
  activeTab: CoreDataset = 'clients';
  rows: CoreGridRow[] = [];
  columnDefs: ColDef<CoreGridRow>[] = [];
  listSearchText = '';
  recordView: RecordView | null = null;
  recordTabs: RecordWorkspaceTab[] = [];
  activeRecordTabId = '';
  activeJobRecordTab: CoreJobRecordTab = 'details';
  jobRecordTabRows: CoreGridRow[] = [];
  jobRecordTabColumnDefs: ColDef<CoreGridRow>[] = [];
  jobRecordTabStatus = '';
  isJobRecordTabLoading = false;
  jobOverview: CoreJobOverview | null = null;
  isJobOverviewLoading = false;
  jobOverviewMessage = '';
  jobRelatedTabs: JobRelatedTab[] = [];
  activeJobRelatedTabId = '';
  isJobEditMode = false;
  isJobSaveRunning = false;
  jobCommandMessage = '';
  jobEditDraft: CoreGridRow = {};
  isClientEditMode = false;
  isClientSaveRunning = false;
  clientCommandMessage = '';
  clientEditDraft: CoreGridRow = {};
  jobLookupOptions: Record<string, CoreLookupOption[]> = {};
  activeJobLookupField = '';
  jobLookupSearchText: Record<string, string> = {};
  activeJobReport: ActiveJobReport | null = null;
  jobReportSearchText = '';
  jobReportMessage = '';
  jobReportFilterDraft: Record<string, string> = {};
  jobReportFilters: JobReportFilterDefinition[] = [];
  jobReportLookupOptions: Record<string, CoreLookupOption[]> = {};
  summary: CoreSummaryResponse | null = null;
  private jobEditOriginal: CoreGridRow = {};
  private clientEditOriginal: CoreGridRow = {};
  statusMessage = 'Loading ABIO_DEMO...';
  menuStatusMessage = 'Loading legacy menu from ABIO_DEMO...';
  companyName = 'BuilDomo Construction';
  isLoading = false;

  @HostListener('document:keydown', ['$event'])
  handleGlobalKeydown(event: KeyboardEvent): void {
    const key = event.key.toLowerCase();
    if (event.ctrlKey && !event.altKey && !event.metaKey && key === 'q') {
      event.preventDefault();
      this.startMenuQuickAccess();
      return;
    }

    if (!this.menuQuickAccessActive) {
      return;
    }

    if (key === 'escape') {
      event.preventDefault();
      this.stopMenuQuickAccess('Menu quick access cancelled.');
      return;
    }

    if (key === 'backspace') {
      event.preventDefault();
      this.moveMenuQuickAccessUp();
      return;
    }

    if (/^[a-z0-9]$/.test(key) && !event.ctrlKey && !event.altKey && !event.metaKey) {
      event.preventDefault();
      this.activateMenuShortcut(key);
    }
  }

  ngOnInit(): void {
    this.api.getMenu().subscribe({
      next: menu => {
        this.legacyMenuModules = menu.modules;
        this.modernMenuGroups = this.buildModernMenuGroups(menu.modules);
        this.expandedMenuKeys = new Set(menu.modules.slice(0, 1).map(item => item.key));
        this.menuStatusMessage = `${menu.menuRowCount} menu rows and ${menu.reportRowCount} reports loaded from abio_menu.`;
      },
      error: () => {
        this.menuStatusMessage = 'Could not load dbo.abio_menu. Using core tabs only.';
      }
    });

    this.api.getConfig().subscribe({
      next: config => {
        this.books = config.books;
        this.form.patchValue({ book: config.defaultBook });
        this.refreshAll();
      },
      error: () => {
        this.statusMessage = 'API is not reachable. Start Abio.Api on http://localhost:5239.';
      }
    });
  }

  refreshAll(): void {
    const book = this.form.controls.book.value;
    if (!book) {
      return;
    }

    this.statusMessage = `Loading ${book}...`;
    this.isLoading = true;

    this.loadDataset(this.activeTab);
    this.loadSummary(book);
    this.loadJobReportLookups(book);
  }

  loadDataset(tab: CoreDataset): void {
    this.activeWorkspace = 'core';
    this.activeJobReport = null;
    this.activeTab = tab;
    this.closeAllRecordTabs();
    const book = this.form.controls.book.value;
    if (!book) {
      return;
    }

    this.isLoading = true;
    this.api.getDataset(tab, book).subscribe({
      next: result => {
        this.rows = result.rows;
        this.columnDefs = this.buildColumns(result.rows, tab);
        this.statusMessage = `${this.labelFor(tab)} loaded from ABIO_DEMO`;
        this.isLoading = false;
      },
      error: () => {
        this.statusMessage = `Could not load ${this.labelFor(tab)}.`;
        this.isLoading = false;
      }
    });
  }

  selectLegacyNode(node: CoreMenuNode): void {
    this.selectedMenuNode = node;
    if (node.children.length > 0) {
      this.toggleLegacyNode(node);
      return;
    }

    if (this.isPayrollMenuNode(node)) {
      this.openPayrollWorkspace(this.payrollViewForMenuNode(node) ?? 'employees');
      return;
    }

    if (this.isJobReportNode(node)) {
      this.openJobReport(node);
      return;
    }

    const mappedDataset = this.datasetForMenuNode(node);
    if (!mappedDataset) {
      this.statusMessage = `${node.label} (${node.program || node.itemType}) is in the legacy menu but is not migrated yet.`;
      return;
    }

    this.loadDataset(mappedDataset);
  }

  selectModernMenuGroup(group: ModernMenuGroup): void {
    this.selectedModernMenuGroupId = group.id;
    this.menuStatusMessage = `${group.label}: ${group.items.length} legacy functions mapped into this workflow area.`;
  }

  openModernMenuItem(node: CoreMenuNode): void {
    this.selectedMenuNode = node;
    this.selectLegacyNode(node);
  }

  openModernMenuLink(link: ModernMenuLink | ModernActionCard): void {
    if ('children' in link && link.children?.length) {
      const groupId = this.selectedModernMenuGroup?.id ?? 'home';
      this.toggleModernMenuLink(groupId, link);
      return;
    }

    if (link.payroll) {
      this.openPayrollWorkspace('payrollView' in link && link.payrollView ? link.payrollView : 'employees');
      return;
    }

    if (link.legacyProgram) {
      const legacyNode = this.findLegacyReportNode(link.legacyProgram, link.legacyReport);
      if (legacyNode) {
        this.openModernMenuItem(legacyNode);
      } else {
        this.statusMessage = `${link.label} is mapped to ${link.legacyProgram}${link.legacyReport ? `/${link.legacyReport}` : ''}, but that Legacy report is not available in the current menu.`;
      }

      return;
    }

    if (link.dataset) {
      this.listSearchText = '';
      this.loadDataset(link.dataset);
      return;
    }

    if (link.groupId) {
      this.selectedModernMenuGroupId = link.groupId;
    }
  }

  toggleModernMenuLink(groupId: string, link: ModernMenuLink): void {
    const key = this.modernMenuLinkKey(groupId, link);
    if (this.expandedModernMenuLinks.has(key)) {
      this.expandedModernMenuLinks.delete(key);
    } else {
      this.expandedModernMenuLinks.add(key);
    }
  }

  isModernMenuLinkExpanded(groupId: string, link: ModernMenuLink): boolean {
    return this.expandedModernMenuLinks.has(this.modernMenuLinkKey(groupId, link));
  }

  modernMenuLinkKey(groupId: string, link: ModernMenuLink): string {
    return `${groupId}:${link.label}`;
  }

  private findLegacyReportNode(program: string, report?: string): CoreMenuNode | null {
    const normalizedProgram = program.toUpperCase();
    const normalizedReport = (report ?? '').toLowerCase();
    return this.flattenMenuNodes(this.groupedReportMenuModules).find(node =>
      node.itemType.toLowerCase() === 'report'
      && node.program.toUpperCase() === normalizedProgram
      && (!normalizedReport || node.menu3.toLowerCase() === normalizedReport)
    ) ?? null;
  }

  private openPayrollWorkspace(view: string): void {
    this.activeWorkspace = 'payroll';
    this.activePayrollView = view;
    this.closeAllRecordTabs();
    this.activeJobReport = null;
    this.statusMessage = `Opened Payroll ${view.replace(/-/g, ' ')} list.`;
  }

  openJobReport(node: CoreMenuNode, resetFilters = true): void {
    const book = this.form.controls.book.value;
    if (!book) {
      this.statusMessage = 'Select a book before running the Job report.';
      return;
    }

    this.activeWorkspace = 'job-report';
    this.closeAllRecordTabs();
    this.activeJobReport = null;
    this.jobReportSearchText = '';
    if (resetFilters) {
      this.jobReportFilterDraft = this.defaultJobReportFilters(node);
    }
    this.jobReportFilters = this.jobReportFilterDefinitions(node);

    this.jobReportMessage = `Loading ${node.label}...`;
    this.isLoading = true;
    this.statusMessage = `Running ${node.label}...`;

    let reportRequest;
    try {
      reportRequest = this.api.getJobReport(
        book,
        node.menu3 || node.program || node.key,
        node.label,
        node.windowName,
        this.jobReportFilterDraft
      );
    } catch (error) {
      this.activeJobReport = null;
      this.jobReportMessage = `Could not prepare ${node.label}. ${error instanceof Error ? error.message : ''}`;
      this.statusMessage = this.jobReportMessage;
      this.isLoading = false;
      return;
    }

    reportRequest.subscribe({
      next: response => {
        try {
          this.activeJobReport = {
            node,
            response,
            columnDefs: this.buildJobReportColumns(response.columns)
          };
          this.jobReportMessage = '';
          this.statusMessage = `${response.title} loaded from ABIO_DEMO.`;
        } catch (error) {
          this.activeJobReport = null;
          this.jobReportMessage = `Could not render ${node.label}. ${error instanceof Error ? error.message : ''}`;
          this.statusMessage = this.jobReportMessage;
        } finally {
          this.isLoading = false;
          this.changeDetector.detectChanges();
        }
      },
      error: (error: HttpErrorResponse) => {
        this.jobReportMessage = this.jobReportErrorMessage(node, error);
        this.statusMessage = this.jobReportMessage;
        this.isLoading = false;
        this.changeDetector.detectChanges();
      }
    });
  }

  private jobReportErrorMessage(node: CoreMenuNode, error: HttpErrorResponse): string {
    if (error.status === 404) {
      return `${node.label} could not run because the Abio.Api process at localhost:5239 has not loaded the Job Report endpoint yet. Restart Abio.Api and try again.`;
    }

    if (error.status === 0) {
      return `${node.label} could not run because Abio.Api is not reachable at localhost:5239.`;
    }

    return `Could not run ${node.label}. ${error.message}`;
  }

  get activeJobReportFilters(): JobReportFilterDefinition[] {
    return this.jobReportFilters;
  }

  updateJobReportFilter(key: string, value: string): void {
    this.jobReportFilterDraft = {
      ...this.jobReportFilterDraft,
      [key]: value
    };
  }

  applyJobReportFilters(): void {
    const node = this.activeJobReport?.node ?? this.selectedMenuNode;
    if (node) {
      this.openJobReport(node, false);
    }
  }

  clearJobReportFilters(): void {
    const node = this.activeJobReport?.node ?? this.selectedMenuNode;
    if (node) {
      this.jobReportFilterDraft = this.defaultJobReportFilters(node);
      this.openJobReport(node, false);
    }
  }

  private defaultJobReportFilters(_node: CoreMenuNode): Record<string, string> {
    return {
      fromJob: '',
      toJob: '',
      activeFlag: '',
      client: '',
      jobType: '',
      area: '',
      centre: '',
      sourceType: '',
      activityFrom: '',
      activityTo: ''
    };
  }

  private jobReportFilterDefinitions(node: CoreMenuNode): JobReportFilterDefinition[] {
    const datawindow = node.windowName.toLowerCase();
    const commonFilters: JobReportFilterDefinition[] = [
      { key: 'fromJob', label: 'From job', type: 'text', placeholder: 'e.g. 1000' },
      { key: 'toJob', label: 'To job', type: 'text', placeholder: 'e.g. 9999' },
      {
        key: 'activeFlag',
        label: 'Active',
        type: 'select',
        options: [
          { value: '', label: 'All' },
          { value: 'Y', label: 'Active only' },
          { value: 'N', label: 'Inactive only' }
        ]
      },
      { key: 'client', label: 'Client', type: 'select', options: this.reportLookupOptionsFor('client') },
      { key: 'jobType', label: 'Job type', type: 'select', options: this.reportLookupOptionsFor('jobType') }
    ];

    if (datawindow.includes('recent_activity')) {
      return [
        ...commonFilters,
        { key: 'activityFrom', label: 'Activity from', type: 'date' },
        { key: 'activityTo', label: 'Activity to', type: 'date' }
      ];
    }

    if (datawindow.includes('centre_to') || datawindow.includes('transaction_comp')) {
      return [
        ...commonFilters,
        { key: 'area', label: 'Area', type: 'select', options: this.reportLookupOptionsFor('area') },
        { key: 'centre', label: 'Centre', type: 'select', options: this.reportLookupOptionsFor('centre') },
        { key: 'sourceType', label: 'Source', type: 'select', options: this.reportLookupOptionsFor('sourceType') },
        { key: 'activityFrom', label: 'Activity from', type: 'date' },
        { key: 'activityTo', label: 'Activity to', type: 'date' }
      ];
    }

    return commonFilters;
  }

  private reportLookupOptionsFor(field: string): { value: string; label: string }[] {
    const values = this.jobReportLookupOptions[field] ?? [];
    return [
      { value: '', label: 'All' },
      ...values.map(option => ({
        value: this.normalizeEditValue(option.value),
        label: this.lookupOptionLabel(option)
      }))
    ];
  }

  private payrollViewForMenuNode(node: CoreMenuNode): string | null {
    const text = `${node.program} ${node.label} ${node.description} ${node.windowName}`.toLowerCase();

    if (text.includes('field')) {
      return 'field-timesheets';
    }

    if (text.includes('timesheet')) {
      return 'timesheets';
    }

    if (text.includes('cheque') || text.includes('check') || text.includes('pay run') || text.includes('payroll run')) {
      return 'cheques';
    }

    if (text.includes('setup') || text.includes('rate') || text.includes('union') || text.includes('occupation')) {
      return 'setup';
    }

    if (text.includes('employee')) {
      return 'employees';
    }

    return null;
  }

  modernShortcutLetter(label: string): string {
    return label.match(/[a-z0-9]/i)?.[0].toUpperCase() ?? '?';
  }

  legacyShortcutLetter(node: CoreMenuNode): string {
    const shortcut = this.menuVisibleShortcut(node).trim();
    return shortcut ? shortcut.slice(-1).toUpperCase() : this.modernShortcutLetter(node.label);
  }

  get selectedModernMenuGroup(): ModernMenuGroup | null {
    return this.modernMenuGroups.find(group => group.id === this.selectedModernMenuGroupId) ?? this.modernMenuGroups[0] ?? null;
  }

  get visibleModernMenuGroups(): ModernMenuGroup[] {
    const query = this.menuSearchText.trim().toLowerCase();
    if (!query) {
      return this.modernMenuGroups;
    }

    return this.modernMenuGroups
      .map(group => ({
        ...group,
        links: group.links
          .map(link => this.filterModernMenuLink(link, query))
          .filter((link): link is ModernMenuLink => link !== null),
        items: group.items.filter(item => this.matchesModernMenuItem(item, query))
      }))
      .filter(group => this.matchesModernGroup(group, query) || group.items.length > 0 || group.links.length > 0);
  }

  private filterModernMenuLink(link: ModernMenuLink, query: string): ModernMenuLink | null {
    const children = (link.children ?? [])
      .map(child => this.filterModernMenuLink(child, query))
      .filter((child): child is ModernMenuLink => child !== null);

    if (link.label.toLowerCase().includes(query) || children.length > 0) {
      return {
        ...link,
        children
      };
    }

    return null;
  }

  get selectedModernMenuItems(): CoreMenuNode[] {
    const group = this.selectedModernMenuGroup;
    const query = this.menuSearchText.trim().toLowerCase();
    if (!group) {
      return [];
    }

    if (!query) {
      return group.items.slice(0, 12);
    }

    return group.items.filter(item => this.matchesModernMenuItem(item, query)).slice(0, 20);
  }

  get modernLandingCards(): ModernLandingCard[] {
    const summary = this.summary;
    return [
      {
        label: 'Payroll approval pending',
        value: summary ? new Intl.NumberFormat('en-US').format(Math.min(12, Math.max(1, Math.round(summary.timesheets / 140)))) : '...',
        detail: 'Review now',
        iconClass: 'icon-payroll',
        tone: 'watch',
        dataset: 'timesheets'
      },
      {
        label: 'Jobs over budget',
        value: summary ? new Intl.NumberFormat('en-US').format(Math.min(7, Math.max(1, Math.round(summary.activeJobs / 3)))) : '...',
        detail: 'View jobs',
        iconClass: 'icon-job',
        tone: 'alert',
        dataset: 'jobs'
      },
      {
        label: 'AP invoices awaiting review',
        value: summary ? new Intl.NumberFormat('en-US').format(Math.min(23, Math.max(1, Math.round(summary.apInvoiceLines / 16)))) : '...',
        detail: 'Review invoices',
        iconClass: 'icon-payables',
        dataset: 'ap-invoices'
      },
      {
        label: 'Timesheets missing approval',
        value: summary ? new Intl.NumberFormat('en-US').format(Math.min(18, Math.max(1, Math.round(summary.timesheets / 95)))) : '...',
        detail: 'Review timesheets',
        iconClass: 'icon-work-queue',
        tone: 'good',
        dataset: 'timesheets'
      }
    ];
  }

  get modernSuggestedActions(): ModernActionCard[] {
    return [
      {
        label: 'Approve 12 payroll items',
        detail: 'Payroll items are waiting for your approval.',
        iconClass: 'icon-payroll',
        payroll: true
      },
      {
        label: 'Review 7 over-budget jobs',
        detail: 'Take action to avoid further cost overruns.',
        iconClass: 'icon-job',
        dataset: 'jobs'
      },
      {
        label: 'Review 23 AP invoices',
        detail: 'Invoices are ready for your review.',
        iconClass: 'icon-payables',
        dataset: 'ap-invoices'
      },
      {
        label: 'Approve 18 timesheets',
        detail: 'Timesheets are missing approval.',
        iconClass: 'icon-work-queue',
        dataset: 'timesheets'
      },
      {
        label: 'Reconcile bank accounts',
        detail: '2 bank accounts need reconciliation.',
        iconClass: 'icon-ledger',
        groupId: 'finance-compliance'
      }
    ];
  }

  get modernRecentRecords(): ModernRecentRecord[] {
    return [
      { type: 'Job', name: '3011 - Transmountain', detail: 'MEDCOR', updated: '2024-07-24 3:15 PM', iconClass: 'icon-job', dataset: 'jobs' },
      { type: 'AP Invoice', name: 'INV-5558', detail: 'Prairie North Ltd.', updated: '2024-07-24 2:47 PM', iconClass: 'icon-payables', dataset: 'ap-invoices' },
      { type: 'Timesheet', name: '1213-2024-07-24', detail: 'John Anderson', updated: '2024-07-24 1:32 PM', iconClass: 'icon-work-queue', dataset: 'timesheets' },
      { type: 'Employee', name: 'E-1024 - Sarah Johnson', detail: 'Carpenter', updated: '2024-07-24 11:05 AM', iconClass: 'icon-employee' },
      { type: 'Purchase Order', name: 'PO-4452', detail: 'ABC Supply Co.', updated: '2024-07-24 10:12 AM', iconClass: 'icon-payables' }
    ];
  }

  get modernKpis(): ModernKpi[] {
    return [
      { label: 'Revenue (Actual)', value: this.money(this.summary?.arNetPurchase ?? 2858331), delta: '+8.6% vs last month', direction: 'up' },
      { label: 'Job Cost (Actual)', value: this.money(this.summary?.jcTransactions ? this.summary.jcTransactions * 2865 : 2340000), delta: '+5.2% vs last month', direction: 'up' },
      { label: 'Gross Profit %', value: '18.7%', delta: '-1.3% vs last month', direction: 'down' },
      { label: 'A/R Outstanding', value: '$1.62M', delta: '-3.4% vs last month', direction: 'up' },
      { label: 'A/P Outstanding', value: '$1.08M', delta: '+4.1% vs last month', direction: 'down' }
    ];
  }

  get totalModernMenuItems(): number {
    return this.modernMenuGroups.reduce((total, group) => total + group.items.length, 0);
  }

  get modernMenuCoverageLabel(): string {
    return `${this.totalModernMenuItems} legacy functions mapped`;
  }

  updateListSearch(value: string): void {
    this.listSearchText = value;
  }

  clearListSearch(): void {
    this.listSearchText = '';
  }

  updateJobReportSearch(value: string): void {
    this.jobReportSearchText = value;
  }

  clearJobReportSearch(): void {
    this.jobReportSearchText = '';
  }

  get jobRecordActions(): RecordAction[] {
    if (this.isJobEditMode) {
      return [
        {
          id: 'save',
          label: this.isJobSaveRunning ? 'Saving...' : 'Save',
          enabled: this.hasJobEditChanges && !this.isJobSaveRunning,
          primary: true,
          title: 'Saving is blocked until the legacy PowerBuilder validation/update rules are mapped.'
        },
        { id: 'cancel', label: 'Cancel', enabled: !this.isJobSaveRunning },
        { id: 'delete', label: 'Delete', enabled: false, title: 'Delete is not enabled during edit mode.' }
      ];
    }

    return [
      { id: 'new', label: 'New', enabled: false, title: 'New job entry will be enabled after legacy defaults are mapped.' },
      { id: 'edit', label: 'Edit', enabled: this.recordView?.dataset === 'jobs', primary: true },
      { id: 'delete', label: 'Delete', enabled: false, title: 'Delete is blocked until legacy permission and referential checks are mapped.' }
    ];
  }

  get hasJobEditChanges(): boolean {
    return Object.keys(this.jobEditDraft).some(field => this.normalizeEditValue(this.jobEditDraft[field]) !== this.normalizeEditValue(this.jobEditOriginal[field]));
  }

  get clientRecordActions(): RecordAction[] {
    if (this.isClientEditMode) {
      return [
        {
          id: 'save',
          label: this.isClientSaveRunning ? 'Saving...' : 'Save',
          enabled: this.hasClientEditChanges && !this.isClientSaveRunning,
          primary: true,
          title: 'Saving is blocked until the legacy A/R Client Entry validation/update rules are mapped.'
        },
        { id: 'cancel', label: 'Cancel', enabled: !this.isClientSaveRunning },
        { id: 'delete', label: 'Delete', enabled: false, title: 'Delete is not enabled during edit mode.' }
      ];
    }

    return [
      { id: 'new', label: 'New', enabled: false, title: 'New client entry will be enabled after legacy defaults are mapped.' },
      { id: 'edit', label: 'Edit', enabled: this.recordView?.dataset === 'clients', primary: true },
      { id: 'delete', label: 'Delete', enabled: false, title: 'Delete is blocked until legacy permission and referential checks are mapped.' }
    ];
  }

  get hasClientEditChanges(): boolean {
    return Object.keys(this.clientEditDraft).some(field => this.normalizeEditValue(this.clientEditDraft[field]) !== this.normalizeEditValue(this.clientEditOriginal[field]));
  }

  get jobInsightMetrics(): JobInsightMetric[] {
    const overview = this.jobOverview;
    if (!overview) {
      return [];
    }

    const budgetUsedPercent = this.percentOf(overview.toDateCost, overview.currentBudget);
    const expectedMargin = overview.expectedRevenue - overview.expectedCost;
    const expectedMarginPercent = this.percentOf(expectedMargin, overview.expectedRevenue);

    return [
      {
        label: 'Budget used',
        value: budgetUsedPercent === null ? 'No budget' : `${budgetUsedPercent.toFixed(1)}%`,
        tone: budgetUsedPercent !== null && budgetUsedPercent >= 90 ? 'alert' : budgetUsedPercent !== null && budgetUsedPercent >= 75 ? 'watch' : 'good'
      },
      {
        label: 'Expected margin',
        value: `${this.money(expectedMargin)}${expectedMarginPercent === null ? '' : ` (${expectedMarginPercent.toFixed(1)}%)`}`,
        tone: expectedMargin < 0 ? 'alert' : expectedMarginPercent !== null && expectedMarginPercent < 10 ? 'watch' : 'good'
      },
      {
        label: 'AP net purchase',
        value: this.money(overview.apNetPurchase)
      },
      {
        label: 'AR net purchase',
        value: this.money(overview.arNetPurchase)
      },
      {
        label: 'Timesheet hours',
        value: new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 }).format(overview.timesheetHours ?? 0)
      },
      {
        label: 'JC cost amount',
        value: this.money(overview.jcCostAmount)
      }
    ];
  }

  get jobWatchlist(): string[] {
    const overview = this.jobOverview;
    if (!overview) {
      return [];
    }

    const items: string[] = [];
    const budgetUsedPercent = this.percentOf(overview.toDateCost, overview.currentBudget);

    if (overview.activeFlag === 'N') {
      items.push('Job is inactive. Confirm whether new time, AP, AR, or JC activity should still be allowed.');
    }

    if (!overview.client) {
      items.push('No client is assigned to this job, which can affect billing and client P/O workflows.');
    }

    if (budgetUsedPercent !== null && budgetUsedPercent >= 90) {
      items.push('To-date cost is at or above 90% of current budget. Review centre-level cost and commitment detail.');
    } else if (budgetUsedPercent !== null && budgetUsedPercent >= 75) {
      items.push('To-date cost is above 75% of current budget. This is a good point for a cost-control check.');
    }

    if (overview.expectedCost > overview.expectedRevenue && overview.expectedRevenue > 0) {
      items.push('Expected cost is greater than expected revenue. Review forecast, billing, and change-order assumptions.');
    }

    if (overview.timesheetLines === 0 && overview.apInvoiceLines === 0 && overview.arInvoiceLines === 0 && overview.jcTransactionLines === 0) {
      items.push('No related timesheet, AP, AR, or job-cost activity has been found yet.');
    }

    if (overview.apInvoiceLines > 0 && overview.jcTransactionLines === 0) {
      items.push('AP invoice rows exist, but no job-cost transaction rows were found. Confirm whether costs have been posted to J/C.');
    }

    if (overview.timesheetLines > 0 && overview.timesheetTotal === 0) {
      items.push('Timesheet rows exist with zero total. Review time entry status and costing.');
    }

    return items.length > 0 ? items : ['No immediate watchlist items from the current overview metrics.'];
  }

  get jobSuggestedActions(): JobInsightAction[] {
    const overview = this.jobOverview;
    if (!overview) {
      return [];
    }

    const actions: JobInsightAction[] = [
      {
        label: 'Review financial tab',
        detail: 'Check budget, cost, revenue, expected cost, and expected revenue together.',
        tab: 'financial'
      },
      {
        label: 'Open supporting documents',
        detail: 'Look for contracts, approvals, client P/Os, or backup attached to this job.',
        tab: 'documents'
      }
    ];

    if (overview.apInvoiceLines > 0) {
      actions.push({
        label: 'Review AP cost activity',
        detail: `${overview.apInvoiceLines} AP invoice line(s) found for this job. Use AP drill-down in the next slice.`,
        disabled: true
      });
    }

    if (overview.arInvoiceLines > 0) {
      actions.push({
        label: 'Review billing activity',
        detail: `${overview.arInvoiceLines} AR invoice line(s) found for this job. Compare billings against expected revenue.`,
        disabled: true
      });
    }

    if (overview.timesheetLines > 0) {
      actions.push({
        label: 'Review timesheet activity',
        detail: `${overview.timesheetLines} timesheet row(s) and ${new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 }).format(overview.timesheetHours)} hour(s) found.`,
        disabled: true
      });
    }

    return actions.slice(0, 5);
  }

  updateMenuSearch(value: string): void {
    this.menuSearchText = value;
  }

  clearMenuSearch(): void {
    this.menuSearchText = '';
  }

  get filteredLegacyMenuModules(): CoreMenuNode[] {
    const query = this.menuSearchText.trim().toLowerCase();
    if (!query) {
      return this.legacyMenuModules;
    }

    return this.legacyMenuModules
      .map(node => this.filterMenuNode(node, query))
      .filter((node): node is CoreMenuNode => node !== null);
  }

  get groupedReportMenuModules(): CoreMenuNode[] {
    return this.filteredLegacyMenuModules.map(module => this.groupReportsForModule(module));
  }

  startMenuQuickAccess(): void {
    this.menuQuickAccessActive = true;
    this.menuQuickAccessPath = [];
    this.menuStatusMessage = `Menu quick access: ${this.describeShortcutOptions(this.legacyMenuModules)}`;
  }

  stopMenuQuickAccess(message?: string): void {
    this.menuQuickAccessActive = false;
    this.menuQuickAccessPath = [];
    if (message) {
      this.menuStatusMessage = message;
    }
  }

  toggleLegacyNode(node: CoreMenuNode): void {
    const next = new Set(this.expandedMenuKeys);
    if (next.has(node.key)) {
      next.delete(node.key);
    } else {
      next.add(node.key);
    }

    this.expandedMenuKeys = next;
  }

  isLegacyNodeExpanded(node: CoreMenuNode): boolean {
    return this.expandedMenuKeys.has(node.key);
  }

  isLegacyNodeActive(node: CoreMenuNode): boolean {
    if (this.selectedMenuNode?.key === node.key) {
      return true;
    }

    const mappedDataset = this.datasetForMenuNode(node);
    return !!mappedDataset && mappedDataset === this.activeTab;
  }

  legacyKey(node: CoreMenuNode): string {
    return node.menu3 || node.menu2 || node.menu1 || ' ';
  }

  menuShortcutPath(node: CoreMenuNode): string {
    return [node.menu1, node.menu2, node.menu3]
      .map(value => value.trim().toLowerCase())
      .filter(Boolean)
      .join('');
  }

  menuVisibleShortcut(node: CoreMenuNode): string {
    return this.legacyKey(node).trim().toLowerCase();
  }

  menuIconClass(node: CoreMenuNode): string {
    const label = node.label.toLowerCase();
    const program = node.program.toUpperCase();
    const key = (node.menu1 || node.menu2 || node.menu3).toLowerCase();

    if (node.itemType === 'report' || label.includes('report')) {
      return 'icon-report';
    }

    if (key === 'a' || label.includes('payable') || program.startsWith('AP')) {
      return 'icon-payables';
    }

    if (key === 'b' || label.includes('receivable') || program.startsWith('AR')) {
      return 'icon-receivables';
    }

    if (key === 'c' || label.includes('payroll') || program.startsWith('PR')) {
      return label.includes('employee') ? 'icon-employee' : 'icon-payroll';
    }

    if (key === 'd' || label.includes('general ledger') || program.startsWith('GL')) {
      return 'icon-ledger';
    }

    if (key === 'e' || label.includes('job') || program.startsWith('JC')) {
      return 'icon-job';
    }

    if (key === 'f' || label.includes('human')) {
      return 'icon-employee';
    }

    if (key === 'g' || label.includes('equipment') || program.startsWith('EQ')) {
      return 'icon-equipment';
    }

    if (key === 'h' || label.includes('project')) {
      return 'icon-project';
    }

    if (key === 'i' || label.includes('inventory')) {
      return 'icon-inventory';
    }

    if (key === 'k' || label.includes('admin')) {
      return 'icon-admin';
    }

    if (key === 'x' || label.includes('exit')) {
      return 'icon-exit';
    }

    return node.children.length > 0 ? 'icon-folder' : 'icon-window';
  }

  private groupReportsForModule(module: CoreMenuNode): CoreMenuNode {
    const children: CoreMenuNode[] = [];
    const reportCategories: CoreMenuNode[] = [];
    const looseReports: CoreMenuNode[] = [];
    let reportMenuTemplate: CoreMenuNode | null = null;
    let reportInsertIndex: number | null = null;

    for (const child of module.children) {
      const grouped = this.extractReportsFromNode(child);
      if (grouped.categories.length > 0 || grouped.looseReports.length > 0) {
        reportInsertIndex ??= children.length;
        reportCategories.push(...grouped.categories);
        looseReports.push(...grouped.looseReports);
        reportMenuTemplate ??= grouped.reportMenuTemplate;
      }

      if (grouped.node) {
        children.push(grouped.node);
      }
    }

    if (reportCategories.length === 0 && looseReports.length === 0) {
      return module;
    }

    const reportsNode = this.createReportsMenuNode(module, reportMenuTemplate, reportCategories, looseReports);
    children.splice(reportInsertIndex ?? children.length, 0, reportsNode);

    return {
      ...module,
      children
    };
  }

  private extractReportsFromNode(node: CoreMenuNode): ReportGroupingResult {
    if (this.isReportMenuNode(node)) {
      return {
        node: null,
        categories: [this.createReportCategoryNode(node)],
        looseReports: [],
        reportMenuTemplate: node
      };
    }

    if (this.isReportLeafNode(node)) {
      return {
        node: null,
        categories: [],
        looseReports: [node],
        reportMenuTemplate: null
      };
    }

    const children: CoreMenuNode[] = [];
    const reportCategories: CoreMenuNode[] = [];
    const looseReports: CoreMenuNode[] = [];
    let reportMenuTemplate: CoreMenuNode | null = null;

    for (const child of node.children) {
      const grouped = this.extractReportsFromNode(child);
      if (grouped.categories.length > 0 || grouped.looseReports.length > 0) {
        reportCategories.push(...grouped.categories);
        looseReports.push(...grouped.looseReports);
        reportMenuTemplate ??= grouped.reportMenuTemplate;
      }

      if (grouped.node) {
        children.push(grouped.node);
      }
    }

    return {
      node: {
        ...node,
        children
      },
      categories: reportCategories,
      looseReports,
      reportMenuTemplate
    };
  }

  private createReportsMenuNode(
    module: CoreMenuNode,
    template: CoreMenuNode | null,
    categories: CoreMenuNode[],
    looseReports: CoreMenuNode[]
  ): CoreMenuNode {
    const base = template ?? module;
    const reportChildren = this.uniqueReportCategories(categories);
    if (looseReports.length > 0) {
      reportChildren.push(this.createLooseReportsCategoryNode(module, looseReports));
    }

    return {
      ...base,
      key: template?.key ? `${template.key}:grouped` : `${module.key}:reports`,
      program: template?.program ?? '',
      label: 'Reports',
      description: template?.description || `Reports for ${module.label}`,
      itemType: 'report menu',
      windowName: template?.windowName ?? '',
      menu1: module.menu1,
      menu2: 'r',
      menu3: '',
      children: reportChildren
    };
  }

  private createReportCategoryNode(node: CoreMenuNode): CoreMenuNode {
    return {
      ...node,
      key: `${node.key}:category`,
      label: this.reportCategoryLabel(node),
      children: this.uniqueReportNodes(node.children.flatMap(child => this.flattenReportNodes(child)))
    };
  }

  private createLooseReportsCategoryNode(module: CoreMenuNode, reports: CoreMenuNode[]): CoreMenuNode {
    return {
      ...module,
      key: `${module.key}:reports:other`,
      program: '',
      label: 'Other Reports',
      description: `Other reports for ${module.label}`,
      itemType: 'report menu',
      windowName: '',
      menu3: '',
      children: this.uniqueReportNodes(reports)
    };
  }

  private reportCategoryLabel(node: CoreMenuNode): string {
    const normalized = node.label.trim();
    return normalized.length > 0 ? normalized : 'Reports';
  }

  private flattenReportNodes(node: CoreMenuNode): CoreMenuNode[] {
    if (this.isReportLeafNode(node)) {
      return [node];
    }

    return node.children.flatMap(child => this.flattenReportNodes(child));
  }

  private uniqueReportCategories(categories: CoreMenuNode[]): CoreMenuNode[] {
    const seen = new Set<string>();
    return categories.filter(category => {
      if (seen.has(category.key)) {
        return false;
      }

      seen.add(category.key);
      return true;
    });
  }

  private uniqueReportNodes(reports: CoreMenuNode[]): CoreMenuNode[] {
    const seen = new Set<string>();
    return reports.filter(report => {
      if (seen.has(report.key)) {
        return false;
      }

      seen.add(report.key);
      return true;
    });
  }

  private isReportLeafNode(node: CoreMenuNode): boolean {
    return node.itemType.toLowerCase() === 'report';
  }

  private isReportMenuNode(node: CoreMenuNode): boolean {
    return node.itemType.toLowerCase() === 'report menu';
  }

  trackMenuNode(_index: number, node: CoreMenuNode): string {
    return node.key;
  }

  money(value: number | undefined): string {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(value ?? 0);
  }

  openJobInsightAction(action: JobInsightAction): void {
    if (action.disabled || !action.tab) {
      return;
    }

    this.selectJobRecordTab(action.tab);
  }

  private buildColumns(rows: CoreGridRow[], dataset: CoreDataset | null = this.activeTab): ColDef<CoreGridRow>[] {
    const first = rows[0];
    if (dataset) {
      const configuredColumns = this.legacyListColumnsFor(dataset);
      const configuredFields = new Set(configuredColumns.map(column => column.field));
      const rowFields = first ? new Set(Object.keys(first)) : new Set(configuredColumns.map(column => column.field));
      const columns = configuredColumns
        .filter(column => rowFields.has(column.field))
        .map(column => this.gridColumnFor(column));
      const extraColumns = first
        ? Object.keys(first)
            .filter(field => !configuredFields.has(field))
            .map(field => this.gridColumnFor({ field, headerName: this.toTitle(field) }))
        : [];

      return [...columns, ...extraColumns];
    }

    if (!first) {
      return [];
    }

    return Object.keys(first).map(field => this.gridColumnFor({ field, headerName: this.toTitle(field) }));
  }

  private buildJobReportColumns(columns: CoreJobReportColumn[]): ColDef<CoreGridRow>[] {
    return columns.map(column => ({
      field: column.field,
      headerName: column.headerName,
      width: column.width,
      minWidth: Math.min(column.width, 120),
      flex: ['description', 'jobDescription', 'clientName'].includes(column.field) ? 1 : undefined,
      type: column.numeric ? 'numericColumn' : undefined,
      valueFormatter: params => this.formatGridValue(column.field, params.value as CoreGridRow[string]),
      cellRenderer: this.isLinkField(column.field)
        ? (params: ICellRendererParams<CoreGridRow>) => this.renderLinkedCell(params)
        : undefined
    }));
  }

  private gridColumnFor(column: LegacyListColumn): ColDef<CoreGridRow> {
    const field = column.field;
    return {
      field,
      headerName: column.headerName,
      width: column.width,
      minWidth: column.minWidth ?? (this.isWideField(field) ? 220 : 125),
      flex: column.flex ?? (this.isWideField(field) ? 1 : undefined),
      type: this.isNumericField(field) ? 'numericColumn' : undefined,
      valueFormatter: params => this.formatGridValue(field, params.value as CoreGridRow[string]),
      cellRenderer: this.isLinkField(field)
        ? (params: ICellRendererParams<CoreGridRow>) => this.renderLinkedCell(params)
        : undefined
    };
  }

  private legacyListColumnsFor(dataset: CoreDataset): LegacyListColumn[] {
    switch (dataset) {
      case 'clients':
        return [
          { field: 'clientId', headerName: 'Client Id', width: 120 },
          { field: 'name', headerName: 'Name', minWidth: 240, flex: 1 },
          { field: 'city', headerName: 'City', width: 150 },
          { field: 'province', headerName: 'Province', width: 115 },
          { field: 'activeFlag', headerName: 'Active Flag', width: 120 },
          { field: 'netOut', headerName: 'Net Out', width: 130 },
          { field: 'purchase', headerName: 'Purchase', width: 130 },
          { field: 'payment', headerName: 'Payment', width: 130 },
          { field: 'lastUpdate', headerName: 'Last Update', width: 145 }
        ];
      case 'jobs':
        return [
          { field: 'jobId', headerName: 'Job Id', width: 110 },
          { field: 'description', headerName: 'Description', minWidth: 250, flex: 1 },
          { field: 'client', headerName: 'Client', width: 120 },
          { field: 'province', headerName: 'Province', width: 115 },
          { field: 'activeFlag', headerName: 'Active Flag', width: 120 },
          { field: 'jobType', headerName: 'Job Type', width: 150 },
          { field: 'currentBudget', headerName: 'Current Budget', width: 150 },
          { field: 'toDateCost', headerName: 'To Date Cost', width: 150 },
          { field: 'toDateRevenue', headerName: 'To Date Revenue', width: 160 },
          { field: 'timesheetLines', headerName: 'Timesheets', width: 125 },
          { field: 'apInvoiceLines', headerName: 'AP Items', width: 115 },
          { field: 'arInvoiceLines', headerName: 'AR Items', width: 115 },
          { field: 'jcTransactionLines', headerName: 'J/C Items', width: 115 },
          { field: 'lastUpdate', headerName: 'Last Update', width: 145 }
        ];
      case 'vendors':
        return [
          { field: 'vendorId', headerName: 'Vendor Id', width: 120 },
          { field: 'name', headerName: 'Name', minWidth: 240, flex: 1 },
          { field: 'city', headerName: 'City', width: 150 },
          { field: 'province', headerName: 'Province', width: 115 },
          { field: 'activeFlag', headerName: 'Active Flag', width: 120 },
          { field: 'costType', headerName: 'Cost Type', width: 120 },
          { field: 'netOut', headerName: 'Net Out', width: 130 },
          { field: 'purchase', headerName: 'Purchase', width: 130 },
          { field: 'payment', headerName: 'Payment', width: 130 },
          { field: 'lastUpdate', headerName: 'Last Update', width: 145 }
        ];
      case 'ap-invoices':
        return [
          { field: 'vendor', headerName: 'Vendor', width: 120 },
          { field: 'invoiceNo', headerName: 'Invoice No', width: 140 },
          { field: 'invoiceItem', headerName: 'Item', width: 90 },
          { field: 'invoiceDate', headerName: 'Invoice Date', width: 140 },
          { field: 'job', headerName: 'Job', width: 110 },
          { field: 'costType', headerName: 'Cost Type', width: 120 },
          { field: 'description', headerName: 'Description', minWidth: 240, flex: 1 },
          { field: 'netPurchase', headerName: 'Net Purchase', width: 150 },
          { field: 'netOut', headerName: 'Net Out', width: 130 },
          { field: 'approvalStatus', headerName: 'Approval Status', width: 150 },
          { field: 'transactFlag', headerName: 'Transact Flag', width: 130 }
        ];
      case 'ar-invoices':
        return [
          { field: 'client', headerName: 'Client', width: 120 },
          { field: 'invoiceNo', headerName: 'Invoice No', width: 140 },
          { field: 'invoiceItem', headerName: 'Item', width: 90 },
          { field: 'invoiceDate', headerName: 'Invoice Date', width: 140 },
          { field: 'job', headerName: 'Job', width: 110 },
          { field: 'description', headerName: 'Description', minWidth: 240, flex: 1 },
          { field: 'labAmount', headerName: 'Labour', width: 120 },
          { field: 'mtlAmount', headerName: 'Material', width: 120 },
          { field: 'equAmount', headerName: 'Equipment', width: 130 },
          { field: 'netPurchase', headerName: 'Net Purchase', width: 150 },
          { field: 'netOut', headerName: 'Net Out', width: 130 },
          { field: 'transactFlag', headerName: 'Transact Flag', width: 130 }
        ];
      case 'timesheets':
        return [
          { field: 'employee', headerName: 'Employee', width: 120 },
          { field: 'workDate', headerName: 'Work Date', width: 140 },
          { field: 'timesheetItem', headerName: 'Item', width: 90 },
          { field: 'job', headerName: 'Job', width: 110 },
          { field: 'area', headerName: 'Area', width: 100 },
          { field: 'centre', headerName: 'Centre', width: 110 },
          { field: 'tradeUnion', headerName: 'Union', width: 110 },
          { field: 'occupation', headerName: 'Occupation', width: 130 },
          { field: 'prPeriod', headerName: 'PR Period', width: 120 },
          { field: 'transactFlag', headerName: 'Transact Flag', width: 130 },
          { field: 'regHour', headerName: 'Reg', width: 95 },
          { field: 'tahHour', headerName: 'TAH', width: 95 },
          { field: 'ovrHour', headerName: 'OT', width: 95 },
          { field: 'total', headerName: 'Total', width: 120 }
        ];
    }
  }

  private formatGridValue(field: string, value: CoreGridRow[string]): string {
    if (value === null || value === undefined || value === '') {
      return '';
    }

    if (this.isDateField(field)) {
      return this.formatFieldValue(value);
    }

    if (typeof value === 'number' && this.isMoneyField(field)) {
      return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }).format(value);
    }

    return this.formatFieldValue(value);
  }

  private isDateField(field: string): boolean {
    return field.toLowerCase().includes('date') || field.toLowerCase().includes('update');
  }

  private isMoneyField(field: string): boolean {
    return ['amount', 'purchase', 'payment', 'cost', 'revenue', 'budget', 'total', 'out'].some(part =>
      field.toLowerCase().includes(part)
    );
  }

  private renderLinkedCell(params: ICellRendererParams<CoreGridRow>): HTMLElement | string {
    const value = params.value;
    const field = params.colDef?.field;
    if (!field || value === null || value === undefined || value === '') {
      return '';
    }

    const row = params.data ?? {};
    const reference = this.recordReferenceFor(field, row, String(value));
    if (!reference) {
      return String(value);
    }

    const link = document.createElement('a');
    link.href = '#';
    link.className = 'record-link';
    link.textContent = String(value);
    link.title = `Open ${this.labelFor(reference.dataset)} record`;
    link.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();
      this.zone.run(() => {
        this.openRecordReference(reference);
        this.changeDetector.detectChanges();
      });
    });

    return link;
  }

  private toTitle(field: string): string {
    return field
      .replace(/([A-Z])/g, ' $1')
      .replace(/^./, char => char.toUpperCase())
      .trim();
  }

  private isWideField(field: string): boolean {
    return ['description', 'name'].some(part => field.toLowerCase().includes(part));
  }

  private isNumericField(field: string): boolean {
    return ['amount', 'purchase', 'payment', 'cost', 'revenue', 'budget', 'hour', 'total', 'out'].some(part =>
      field.toLowerCase().includes(part)
    );
  }

  private isLinkField(field: string): boolean {
    return ['jobId', 'job', 'clientId', 'client', 'vendorId', 'vendor', 'invoiceNo', 'name', 'description'].includes(field);
  }

  private recordReferenceFor(field: string, row: CoreGridRow, value: string): RecordReference | null {
    if (field === 'jobId') {
      return {
        dataset: 'jobs',
        value,
        matchFields: ['jobId', 'job'],
        sourceRow: this.activeTab === 'jobs' ? row : undefined
      };
    }

    if (field === 'job' || field === 'parentJob') {
      return {
        dataset: 'jobs',
        value,
        matchFields: ['jobId', 'job']
      };
    }

    if (field === 'clientId') {
      return {
        dataset: 'clients',
        value,
        matchFields: ['clientId', 'client'],
        sourceRow: this.activeTab === 'clients' ? row : undefined
      };
    }

    if (field === 'client') {
      return {
        dataset: 'clients',
        value,
        matchFields: ['clientId', 'client']
      };
    }

    if (field === 'vendorId') {
      return {
        dataset: 'vendors',
        value,
        matchFields: ['vendorId', 'vendor'],
        sourceRow: this.activeTab === 'vendors' ? row : undefined
      };
    }

    if (field === 'vendor') {
      return {
        dataset: 'vendors',
        value,
        matchFields: ['vendorId', 'vendor']
      };
    }

    if (field === 'invoiceNo') {
      const dataset = this.invoiceDatasetFor(row);
      return dataset
        ? {
            dataset,
            value,
            matchFields: ['invoiceNo'],
            sourceRow: this.activeTab === dataset ? row : undefined
          }
        : null;
    }

    if (field === 'name' && this.activeTab === 'clients') {
      const clientId = row['clientId'];
      return typeof clientId === 'string' || typeof clientId === 'number'
        ? {
            dataset: 'clients',
            value: String(clientId),
            matchFields: ['clientId', 'client'],
            sourceRow: row
          }
        : null;
    }

    if (field === 'name' && this.activeTab === 'vendors') {
      const vendorId = row['vendorId'];
      return typeof vendorId === 'string' || typeof vendorId === 'number'
        ? {
            dataset: 'vendors',
            value: String(vendorId),
            matchFields: ['vendorId', 'vendor'],
            sourceRow: row
          }
        : null;
    }

    if (field === 'description' && this.activeTab === 'jobs') {
      const jobId = row['jobId'];
      return typeof jobId === 'string' || typeof jobId === 'number'
        ? {
            dataset: 'jobs',
            value: String(jobId),
            matchFields: ['jobId', 'job'],
            sourceRow: row
          }
        : null;
    }

    return null;
  }

  private invoiceDatasetFor(row: CoreGridRow): CoreDataset | null {
    if (this.activeTab === 'ap-invoices') {
      return 'ap-invoices';
    }

    if (this.activeTab === 'ar-invoices') {
      return 'ar-invoices';
    }

    if (row['vendor'] && !row['client']) {
      return 'ap-invoices';
    }

    if (row['client'] && !row['vendor']) {
      return 'ar-invoices';
    }

    return null;
  }

  private openRecordReference(reference: RecordReference): void {
    if (reference.dataset === 'jobs') {
      this.openJobRecord(reference.value);
      return;
    }

    if (reference.sourceRow) {
      this.activeTab = reference.dataset;
      this.openRecord(reference.dataset, reference.sourceRow);
      return;
    }

    const book = this.form.controls.book.value;
    if (!book) {
      return;
    }

    this.isLoading = true;
    this.statusMessage = `Opening ${this.labelFor(reference.dataset)} record ${reference.value}...`;
    this.api.getDataset(reference.dataset, book).subscribe({
      next: result => {
        this.activeTab = reference.dataset;
        this.rows = result.rows;
        this.columnDefs = this.buildColumns(result.rows, reference.dataset);
        const row = this.findRecordRow(result.rows, reference);
        if (row) {
          this.openRecord(reference.dataset, row);
        } else {
          this.statusMessage = `Could not find ${this.labelFor(reference.dataset)} record ${reference.value}.`;
        }
        this.isLoading = false;
      },
      error: () => {
        this.statusMessage = `Could not load ${this.labelFor(reference.dataset)} record ${reference.value}.`;
        this.isLoading = false;
      }
    });
  }

  private loadJobRelatedReference(tab: JobRelatedTab, reference: RecordReference): void {
    const book = this.form.controls.book.value;
    if (!book) {
      this.updateJobRelatedTab(tab.id, { status: 'No active book is selected.' });
      return;
    }

    if (reference.dataset === 'jobs') {
      this.api.getJobRecord(book, reference.value).subscribe({
        next: row => this.updateJobRelatedTab(tab.id, {
          subtitle: this.recordTitle('jobs', row),
          status: 'Related job loaded.',
          fields: this.recordFieldsFor(row)
        }),
        error: () => this.updateJobRelatedTab(tab.id, { status: `Could not load job ${reference.value}.` })
      });
      return;
    }

    if (reference.sourceRow) {
      this.updateJobRelatedTab(tab.id, {
        subtitle: this.recordTitle(reference.dataset, reference.sourceRow),
        status: `${this.labelFor(reference.dataset)} record loaded.`,
        fields: this.recordFieldsFor(reference.sourceRow)
      });
      return;
    }

    this.api.getDataset(reference.dataset, book).subscribe({
      next: result => {
        const row = this.findRecordRow(result.rows, reference);
        if (!row) {
          this.updateJobRelatedTab(tab.id, {
            status: `Could not find ${this.labelFor(reference.dataset)} record ${reference.value}.`
          });
          return;
        }

        this.updateJobRelatedTab(tab.id, {
          subtitle: this.recordTitle(reference.dataset, row),
          status: `${this.labelFor(reference.dataset)} record loaded.`,
          fields: this.recordFieldsFor(row)
        });
      },
      error: () => this.updateJobRelatedTab(tab.id, {
        status: `Could not load ${this.labelFor(reference.dataset)} record ${reference.value}.`
      })
    });
  }

  private openJobRelatedLookup(tab: JobRelatedTab): void {
    const option = this.lookupOptionForValue(tab.field, tab.value);
    if (!option) {
      this.updateJobRelatedTab(tab.id, { status: 'No related lookup record was found.' });
      return;
    }

    this.updateJobRelatedTab(tab.id, {
      subtitle: this.lookupOptionLabel(option),
      status: 'Legacy lookup reference loaded.',
      fields: [
        this.relatedField('field', 'Field', this.toTitle(tab.field)),
        this.relatedField('value', 'Value', option.value),
        this.relatedField('description', 'Description', option.label),
        this.relatedField('source', 'Source', 'Legacy lookup table')
      ].filter(field => field.displayValue)
    });
  }

  private updateJobRelatedTab(tabId: string, changes: Partial<JobRelatedTab>): void {
    this.jobRelatedTabs = this.jobRelatedTabs.map(tab =>
      tab.id === tabId ? { ...tab, ...changes } : tab
    );
    this.changeDetector.detectChanges();
  }

  private relatedField(field: string, label: string, value: CoreGridRow[string]): RecordField {
    return {
      field,
      label,
      value,
      displayValue: this.formatFieldValue(value)
    };
  }

  private recordFieldsFor(row: CoreGridRow): RecordField[] {
    return Object.keys(row).map(field => ({
      field,
      label: this.toTitle(field),
      value: row[field],
      displayValue: this.formatFieldValue(row[field])
    }));
  }

  private jobRelatedFieldValue(field: string): string {
    const value = this.isJobEditMode
      ? this.jobEditDraft[field] ?? this.recordView?.row[field]
      : this.recordView?.row[field];

    return this.normalizeEditValue(value ?? '');
  }

  private isJobLookupReferenceField(field: string): boolean {
    return [
      'province',
      'country',
      'wcbClass',
      'gstRule',
      'equipmentRate',
      'labourRate',
      'division',
      'region',
      'dashboardGroup',
      'jobType',
      'tradeUnionGroup',
      'equipmentRevenueArea',
      'equipmentRevenueCentre'
    ].includes(field);
  }

  private openJobRecord(jobId: string): void {
    const book = this.form.controls.book.value;
    if (!book) {
      return;
    }

    this.isLoading = true;
    this.statusMessage = `Opening job ${jobId}...`;
    this.jobLookupOptions = {};
    this.jobOverview = null;
    this.jobOverviewMessage = '';
    this.api.getJobRecord(book, jobId).subscribe({
      next: row => {
        this.activeTab = 'jobs';
        this.openRecord('jobs', row);
        this.exitJobEditMode();
        this.selectJobRecordTab('details');
        this.loadJobLookups(book, jobId);
        this.loadJobOverview(book, jobId);
        this.isLoading = false;
        this.changeDetector.detectChanges();
      },
      error: () => {
        this.statusMessage = `Could not load job ${jobId}.`;
        this.isLoading = false;
      }
    });
  }

  closeRecordForm(): void {
    if (this.activeRecordTabId) {
      this.closeRecordTab(this.activeRecordTabId);
      return;
    }

    this.closeAllRecordTabs();
  }

  selectRecordTab(tabId: string): void {
    const tab = this.recordTabs.find(item => item.id === tabId);
    if (!tab) {
      return;
    }

    this.exitJobEditMode();
    this.exitClientEditMode();
    this.activeRecordTabId = tab.id;
    this.recordView = tab.view;
    this.activeTab = tab.view.dataset;

    if (tab.view.dataset === 'jobs') {
      const book = this.form.controls.book.value;
      const jobId = this.formatFieldValue(tab.view.row['jobId']);
      if (book && jobId) {
        this.loadJobLookups(book, jobId);
        this.loadJobOverview(book, jobId);
      }
      this.selectJobRecordTab(this.activeJobRecordTab);
    }
  }

  closeRecordTab(tabId: string, event?: Event): void {
    event?.preventDefault();
    event?.stopPropagation();

    this.exitJobEditMode();
    this.exitClientEditMode();
    const closedIndex = this.recordTabs.findIndex(tab => tab.id === tabId);
    this.recordTabs = this.recordTabs.filter(tab => tab.id !== tabId);

    if (this.recordTabs.length === 0) {
      this.closeAllRecordTabs();
      this.statusMessage = `${this.labelFor(this.activeTab)} loaded from ABIO_DEMO`;
      return;
    }

    const next = this.recordTabs[Math.max(0, closedIndex - 1)] ?? this.recordTabs[0];
    this.selectRecordTab(next.id);
  }

  private closeAllRecordTabs(): void {
    this.exitJobEditMode();
    this.exitClientEditMode();
    this.recordTabs = [];
    this.activeRecordTabId = '';
    this.recordView = null;
    this.jobLookupOptions = {};
    this.jobOverview = null;
    this.jobOverviewMessage = '';
    this.clearJobRelatedTabs();
  }

  openRecordField(field: RecordField): void {
    if (!this.recordView || !field.displayValue) {
      return;
    }

    const reference = this.recordReferenceFor(field.field, this.recordView.row, field.displayValue);
    if (reference) {
      this.openRecordReference(reference);
    }
  }

  isRecordFieldLinked(field: RecordField): boolean {
    if (!this.recordView || !field.displayValue) {
      return false;
    }

    return this.recordReferenceFor(field.field, this.recordView.row, field.displayValue) !== null;
  }

  legacyFieldValue(field: LegacyFormField): string {
    const row = this.recordView?.row;
    if (!row) {
      return '';
    }

    return this.formatFieldValue(row[field.field]);
  }

  jobEditorValue(field: LegacyFormField): string {
    if (!this.isJobEditMode) {
      return this.legacyFieldValue(field);
    }

    return this.rawEditValue(this.jobEditDraft[field.field]);
  }

  jobHeadEditorValue(field: 'jobId' | 'activeFlag'): string {
    if (!this.isJobEditMode) {
      return this.formatFieldValue(this.recordView?.row[field] ?? null);
    }

    return this.rawEditValue(this.jobEditDraft[field]);
  }

  legacyFieldDescription(field: LegacyFormField): string {
    if (this.isJobEditMode && field.descriptionField) {
      const option = this.lookupOptionForValue(field.field, this.jobEditorValue(field));
      if (option) {
        return option.label;
      }
    }

    const row = this.recordView?.row;
    if (!row || !field.descriptionField) {
      return '';
    }

    return this.formatFieldValue(row[field.descriptionField]);
  }

  legacyFieldTooltip(field: LegacyFormField | 'jobId' | 'activeFlag'): string {
    const key = typeof field === 'string' ? field : field.field;
    return this.jobFieldTooltips[key] ?? '';
  }

  clientFieldValue(field: LegacyFormField): string {
    const row = this.recordView?.row;
    if (!row) {
      return '';
    }

    return this.formatFieldValue(row[field.field]);
  }

  clientEditorValue(field: LegacyFormField): string {
    if (!this.isClientEditMode) {
      return this.clientFieldValue(field);
    }

    return this.rawEditValue(this.clientEditDraft[field.field]);
  }

  isClientFieldEditable(field: LegacyFormField): boolean {
    return this.isClientEditMode && !field.protected && !field.editLocked && !this.isClientFieldLocked(field.field);
  }

  isClientFieldRequired(field: LegacyFormField): boolean {
    return this.isClientEditMode && !!field.required;
  }

  isClientBooleanField(field: string): boolean {
    return field === 'activeFlag';
  }

  isClientBooleanChecked(field: string): boolean {
    const value = this.rawEditValue(this.clientEditDraft[field] ?? this.recordView?.row[field] ?? null);
    return value.toUpperCase() === 'Y';
  }

  updateClientBooleanField(field: string, event: Event): void {
    const checked = event.target instanceof HTMLInputElement ? event.target.checked : false;
    this.clientEditDraft = {
      ...this.clientEditDraft,
      [field]: checked ? 'Y' : 'N'
    };
  }

  updateClientEditField(field: LegacyFormField, event: Event): void {
    if (!this.isClientFieldEditable(field)) {
      return;
    }

    this.clientEditDraft = {
      ...this.clientEditDraft,
      [field.field]: this.inputValue(event)
    };
  }

  get activeJobRelatedTab(): JobRelatedTab | null {
    return this.jobRelatedTabs.find(tab => tab.id === this.activeJobRelatedTabId) ?? this.jobRelatedTabs[0] ?? null;
  }

  canOpenJobRelatedField(field: LegacyFormField | 'jobId' | 'activeFlag'): boolean {
    const key = typeof field === 'string' ? field : field.field;
    const value = this.jobRelatedFieldValue(key);
    if (!value || key === 'activeFlag' || key === 'jobId') {
      return false;
    }

    return !!this.recordView && !!this.recordReferenceFor(key, this.recordView.row, value);
  }

  openJobRelatedField(field: LegacyFormField | 'jobId' | 'activeFlag', event?: Event): void {
    event?.preventDefault();
    event?.stopPropagation();

    if (!this.recordView) {
      return;
    }

    const key = typeof field === 'string' ? field : field.field;
    const value = this.jobRelatedFieldValue(key);
    if (!value || !this.canOpenJobRelatedField(field)) {
      return;
    }

    const reference = this.recordReferenceFor(key, this.recordView.row, value);
    if (reference) {
      this.openRecordReference(reference);
    }
  }

  selectJobRelatedTab(tabId: string): void {
    this.activeJobRelatedTabId = tabId;
  }

  clearJobRelatedTabs(): void {
    this.jobRelatedTabs = [];
    this.activeJobRelatedTabId = '';
  }

  isLegacyFieldLinked(field: LegacyFormField): boolean {
    const row = this.recordView?.row;
    const value = this.legacyFieldValue(field);
    if (!row || !value) {
      return false;
    }

    return this.recordReferenceFor(field.field, row, value) !== null;
  }

  openLegacyField(field: LegacyFormField): void {
    const row = this.recordView?.row;
    const value = this.legacyFieldValue(field);
    if (!row || !value) {
      return;
    }

    const reference = this.recordReferenceFor(field.field, row, value);
    if (reference) {
      this.openRecordReference(reference);
    }
  }

  isJobFieldEditable(field: LegacyFormField): boolean {
    return this.isJobEditMode && !this.isJobFieldLocked(field.field) && !this.isJobFieldProtectedByLegacy(field.field) && !field.protected && !field.editLocked;
  }

  isJobHeadFieldEditable(field: 'jobId' | 'activeFlag'): boolean {
    return this.isJobEditMode && field === 'activeFlag' && this.isCurrentJobRecord();
  }

  isJobHeadFieldRequired(field: 'jobId' | 'activeFlag'): boolean {
    return this.isJobEditMode && ['jobId', 'activeFlag'].includes(field);
  }

  isJobFieldRequired(field: LegacyFormField): boolean {
    if (!this.isJobEditMode || !field.required) {
      return false;
    }

    if (field.field === 'division') {
      return this.isCurrentJobRecord() && this.isJobBookStandard() && this.jobDivisionBookCount() > 0;
    }

    if (field.field === 'dashboardGroup') {
      return this.jobDashboardGroupCount() > 0;
    }

    return true;
  }

  private isCurrentJobRecord(): boolean {
    const fileType = this.normalizeEditValue(this.recordView?.row['fileType'] ?? 'C').toUpperCase();
    return fileType.length === 0 || fileType === 'C';
  }

  private isJobBookStandard(): boolean {
    return this.normalizeEditValue(this.recordView?.row['bookStandardFlag'] ?? '').toUpperCase() === 'Y';
  }

  private jobDivisionBookCount(): number {
    return Number(this.recordView?.row['divisionBookCount'] ?? 0) || 0;
  }

  private jobDashboardGroupCount(): number {
    return Number(this.recordView?.row['dashboardGroupCount'] ?? 0) || 0;
  }

  private isJobFieldProtectedByLegacy(field: string): boolean {
    const currentOnlyFields = [
      'description',
      'address1',
      'address2',
      'city',
      'phone',
      'fax',
      'postal',
      'client',
      'clientJob',
      'clientPo',
      'equipmentRevenueArea',
      'equipmentRate',
      'labourRate',
      'labourMarkupPercent',
      'materialMarkupPercent',
      'additionalHourlyAmounts',
      'regHoursPerDay',
      'timesheetSignLine',
      'lastTimesheet',
      'superintendent',
      'parentJob',
      'startDate',
      'completeDate',
      'shutdownStart'
    ];

    if (currentOnlyFields.includes(field) && !this.isCurrentJobRecord()) {
      return true;
    }

    if (['country', 'includeStaffHours', 'lastJobPo', 'snapshotDate', 'lastUpdate'].includes(field)) {
      return true;
    }

    if (['province', 'wcbClass', 'gstRule', 'poUseJobAddress', 'disperseLabourBillings', 'freezeBudget'].includes(field)) {
      return true;
    }

    if (field === 'item') {
      return this.normalizeEditValue(this.jobEditDraft['clientPo'] ?? this.recordView?.row['clientPo'] ?? '').length === 0;
    }

    if (field === 'equipmentRevenueCentre') {
      return !this.isCurrentJobRecord() ||
        this.normalizeEditValue(this.jobEditDraft['equipmentRevenueArea'] ?? this.recordView?.row['equipmentRevenueArea'] ?? '').length === 0;
    }

    if (field === 'shutdownEnd') {
      return !this.isCurrentJobRecord() ||
        this.normalizeEditValue(this.jobEditDraft['shutdownStart'] ?? this.recordView?.row['shutdownStart'] ?? '').length === 0;
    }

    if (field === 'division') {
      return !this.isCurrentJobRecord() || !this.isJobBookStandard();
    }

    if (field === 'dashboardGroup') {
      return !this.isCurrentJobRecord() || this.jobDashboardGroupCount() <= 0;
    }

    if (field === 'jobType') {
      return !this.isCurrentJobRecord();
    }

    return false;
  }

  hasJobLookupOptions(field: string): boolean {
    return (this.jobLookupOptions[field] ?? []).length > 0;
  }

  isJobBooleanField(field: string): boolean {
    return ['activeFlag', 'fixedPriceFlag', 'disperseLabourBillings', 'poUseJobAddress', 'includeStaffHours', 'concurrentCrews', 'freezeBudget', 'contractCompany'].includes(field);
  }

  isJobDateField(field: string): boolean {
    return ['startDate', 'shutdownStart', 'snapshotDate', 'completeDate', 'shutdownEnd', 'lastUpdate'].includes(field);
  }

  jobDateInputValue(field: LegacyFormField): string {
    return this.toDateInputValue(this.jobEditorValue(field));
  }

  isJobBooleanChecked(field: string): boolean {
    const value = this.rawEditValue(this.jobEditDraft[field] ?? this.recordView?.row[field] ?? null);
    return value.toUpperCase() === 'Y';
  }

  updateJobBooleanField(field: string, event: Event): void {
    const checked = event.target instanceof HTMLInputElement ? event.target.checked : false;
    this.jobEditDraft = {
      ...this.jobEditDraft,
      [field]: checked ? 'Y' : 'N'
    };
  }

  jobLookupOptionsFor(field: string): CoreLookupOption[] {
    const options = this.filteredLookupOptions(field, this.jobLookupOptions[field] ?? []);
    const optionMap = new Map<string, CoreLookupOption>();

    if (!['activeFlag', 'fixedPriceFlag', 'disperseLabourBillings', 'poUseJobAddress', 'includeStaffHours', 'concurrentCrews', 'freezeBudget', 'contractCompany'].includes(field)) {
      optionMap.set('', { value: '', label: '' });
    }

    for (const option of options) {
      optionMap.set(option.value, option);
    }

    return [...optionMap.values()];
  }

  filteredJobLookupOptionsFor(field: string): CoreLookupOption[] {
    const query = Object.prototype.hasOwnProperty.call(this.jobLookupSearchText, field)
      ? this.jobLookupSearchText[field].trim().toLowerCase()
      : '';
    const options = this.jobLookupOptionsFor(field);
    if (!query) {
      return options;
    }

    return options.filter(option =>
      option.value.toLowerCase().includes(query) ||
      option.label.toLowerCase().includes(query) ||
      this.lookupOptionLabel(option).toLowerCase().includes(query)
    );
  }

  private filteredLookupOptions(field: string, options: CoreLookupOption[]): CoreLookupOption[] {
    if (field !== 'equipmentRevenueCentre') {
      return options;
    }

    const selectedArea = this.normalizeEditValue(this.jobEditDraft['equipmentRevenueArea'] ?? this.recordView?.row['equipmentRevenueArea'] ?? '');
    if (!selectedArea) {
      return options;
    }

    return options.filter(option => option.label.startsWith(`${selectedArea} - `));
  }

  lookupOptionLabel(option: CoreLookupOption): string {
    if (!option.value && !option.label) {
      return '';
    }

    return option.label ? `${option.value} - ${option.label}` : option.value;
  }

  trackByLookupOption(_index: number, option: CoreLookupOption): string {
    return `${option.value}\u0000${option.label}`;
  }

  lookupListId(field: string): string {
    return `job-lookup-${field}`;
  }

  isJobLookupOpen(field: string): boolean {
    return this.activeJobLookupField === field;
  }

  openJobLookup(field: string, event?: Event): void {
    if (!this.hasJobLookupOptions(field)) {
      return;
    }

    this.activeJobLookupField = field;
    delete this.jobLookupSearchText[field];

    if (event?.target instanceof HTMLInputElement) {
      window.setTimeout(() => event.target instanceof HTMLInputElement && event.target.select());
    }
  }

  closeJobLookupSoon(field: string): void {
    if (this.activeJobLookupField !== field) {
      return;
    }

    window.setTimeout(() => {
      if (this.isFocusInsideJobLookup(field)) {
        return;
      }

      if (this.activeJobLookupField === field) {
        this.activeJobLookupField = '';
        this.commitExactLookupMatch(field);
        delete this.jobLookupSearchText[field];
        this.changeDetector.detectChanges();
      }
    }, 150);
  }

  toggleJobLookup(field: string, event: Event): void {
    event.preventDefault();
    event.stopPropagation();

    if (this.isJobLookupOpen(field)) {
      this.activeJobLookupField = '';
      delete this.jobLookupSearchText[field];
      return;
    }

    this.openJobLookup(field);
  }

  handleJobLookupKeydown(field: string, event: KeyboardEvent): void {
    if (event.key !== 'ArrowRight') {
      return;
    }

    this.focusJobLookupOptions(field, event);
  }

  focusJobLookupOptions(field: string, event: Event): void {
    event.preventDefault();
    event.stopPropagation();

    if (!this.hasJobLookupOptions(field)) {
      return;
    }

    this.activeJobLookupField = field;
    this.changeDetector.detectChanges();

    requestAnimationFrame(() => window.setTimeout(() => {
      const combobox = this.lookupComboboxForField(field);
      const options = Array.from(combobox?.querySelectorAll<HTMLButtonElement>('.legacy-lookup-option') ?? []);
      if (options.length === 0) {
        return;
      }

      const currentValue = this.normalizeEditValue(this.jobEditDraft[field] ?? this.recordView?.row[field] ?? null);
      const currentOption = currentValue
        ? options.find(option => this.normalizeEditValue(option.dataset['lookupValue'] ?? '') === currentValue)
        : null;
      const firstMeaningfulOption = options.find(option => this.normalizeEditValue(option.dataset['lookupValue'] ?? '').length > 0);
      const next = currentOption ?? firstMeaningfulOption ?? options[0];
      next.focus({ preventScroll: true });
      next.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    }, 0));
  }

  jobLookupInputValue(field: string, value: string): string {
    if (this.activeJobLookupField === field && Object.prototype.hasOwnProperty.call(this.jobLookupSearchText, field)) {
      return this.jobLookupSearchText[field];
    }

    return this.jobLookupDisplayValue(field, value);
  }

  jobLookupDisplayValue(field: string, value: string): string {
    const normalizedValue = this.normalizeEditValue(value);
    if (!normalizedValue) {
      return '';
    }

    const option = this.lookupOptionForValue(field, normalizedValue);
    return option ? this.lookupOptionLabel(option) : normalizedValue;
  }

  updateJobLookupField(field: string, event: Event): void {
    const typedValue = this.inputValue(event);
    this.activeJobLookupField = field;
    this.jobLookupSearchText = {
      ...this.jobLookupSearchText,
      [field]: typedValue
    };

    const option = this.matchLookupOption(field, typedValue);
    if (option) {
      this.jobEditDraft = {
        ...this.jobEditDraft,
        [field]: option.value
      };
    }
  }

  previewJobLookupOption(field: string, option: CoreLookupOption): void {
    if (!this.isJobLookupOpen(field)) {
      return;
    }

    this.jobEditDraft = {
      ...this.jobEditDraft,
      [field]: option.value
    };
  }

  selectJobLookupOption(field: string, option: CoreLookupOption, event?: Event): void {
    event?.preventDefault();
    event?.stopPropagation();

    const combobox = event?.target instanceof HTMLElement
      ? event.target.closest<HTMLElement>('.legacy-lookup-combobox')
      : null;

    this.jobEditDraft = {
      ...this.jobEditDraft,
      [field]: option.value
    };
    this.activeJobLookupField = '';
    delete this.jobLookupSearchText[field];
    this.changeDetector.detectChanges();
    this.focusNextJobFieldAfterLookup(combobox);
  }

  private isFocusInsideJobLookup(field: string): boolean {
    const active = document.activeElement;
    if (!(active instanceof HTMLElement)) {
      return false;
    }

    const combobox = active.closest<HTMLElement>('.legacy-lookup-combobox');
    return combobox?.dataset['lookupField'] === field;
  }

  private lookupComboboxForField(field: string): HTMLElement | null {
    return Array.from(this.elementRef.nativeElement.querySelectorAll<HTMLElement>('.legacy-lookup-combobox'))
      .find(combobox => combobox.dataset['lookupField'] === field) ?? null;
  }

  private focusNextJobFieldAfterLookup(combobox: HTMLElement | null): void {
    if (!combobox) {
      return;
    }

    window.setTimeout(() => {
      const currentInput = combobox.querySelector<HTMLInputElement>('input');
      if (!currentInput) {
        return;
      }

      const fields = Array.from(
        this.elementRef.nativeElement.querySelectorAll<HTMLElement>(
          '.legacy-record-body input, .legacy-record-body textarea, .legacy-record-body select'
        )
      ).filter(field => this.isFocusableRecordField(field));
      const currentIndex = fields.indexOf(currentInput);
      const next = currentIndex >= 0 ? fields[currentIndex + 1] : null;
      if (!next) {
        return;
      }

      next.focus({ preventScroll: true });
      next.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      if (next instanceof HTMLInputElement && !next.readOnly && ['text', 'number', 'email', 'tel', 'url', 'search', 'password'].includes(next.type)) {
        next.select();
      }
    });
  }

  private isFocusableRecordField(field: HTMLElement): boolean {
    if (field.hasAttribute('disabled') || field.getAttribute('tabindex') === '-1') {
      return false;
    }

    if (field instanceof HTMLInputElement && field.type === 'hidden') {
      return false;
    }

    if (field.closest('[hidden], [aria-hidden="true"], .legacy-lookup-panel')) {
      return false;
    }

    const style = window.getComputedStyle(field);
    return style.display !== 'none' && style.visibility !== 'hidden' && field.offsetParent !== null;
  }

  private focusFirstJobRecordField(): void {
    window.setTimeout(() => {
      const field = Array.from(
        this.elementRef.nativeElement.querySelectorAll<HTMLElement>(
          '.legacy-record-body input, .legacy-record-body textarea, .legacy-record-body select'
        )
      ).find(item => this.isFocusableRecordField(item));

      field?.focus({ preventScroll: true });
    });
  }

  private focusFirstJobEditableField(): void {
    window.setTimeout(() => {
      const field = Array.from(
        this.elementRef.nativeElement.querySelectorAll<HTMLElement>(
          '.legacy-record-body input.is-editable, .legacy-record-body textarea.is-editable, .legacy-record-body select.is-editable'
        )
      ).find(item => this.isFocusableRecordField(item));

      if (!field) {
        return;
      }

      field.focus({ preventScroll: true });
      field.scrollIntoView({ block: 'nearest', inline: 'nearest' });
      if (field instanceof HTMLInputElement && !field.readOnly && ['text', 'number', 'email', 'tel', 'url', 'search', 'password'].includes(field.type)) {
        field.select();
      }
    });
  }

  updateJobEditField(field: LegacyFormField, event: Event): void {
    if (!this.isJobFieldEditable(field)) {
      return;
    }

    this.jobEditDraft = {
      ...this.jobEditDraft,
      [field.field]: this.inputValue(event)
    };
  }

  updateJobDateField(field: LegacyFormField, event: Event): void {
    if (!this.isJobFieldEditable(field)) {
      return;
    }

    this.jobEditDraft = {
      ...this.jobEditDraft,
      [field.field]: this.toLegacyDateValue(this.inputValue(event))
    };
  }

  updateJobHeadEditField(field: 'jobId' | 'activeFlag', event: Event): void {
    if (!this.isJobHeadFieldEditable(field)) {
      return;
    }

    this.jobEditDraft = {
      ...this.jobEditDraft,
      [field]: this.inputValue(event).toUpperCase()
    };
  }

  handleJobRecordAction(actionId: RecordActionId): void {
    const action = this.jobRecordActions.find(item => item.id === actionId);
    if (!action || !action.enabled) {
      return;
    }

    this.zone.run(() => {
      switch (action.id) {
        case 'edit':
          this.enterJobEditMode();
          return;
        case 'cancel':
          this.cancelJobEdit();
          return;
        case 'save':
          this.submitJobSaveCommand();
          return;
        case 'new':
          this.setJobCommandMessage('New job entry is blocked until the legacy defaulting rules from w_jc_job are mapped.');
          this.changeDetector.detectChanges();
          return;
        case 'delete':
          this.setJobCommandMessage('Delete is blocked until the legacy permission and referential checks from w_jc_job are mapped.');
          this.changeDetector.detectChanges();
          return;
      }
    });
  }

  handleJobRecordPointerDown(actionId: RecordActionId, event: PointerEvent): void {
    if (actionId !== 'edit' && actionId !== 'cancel') {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    this.zone.run(() => {
      if (actionId === 'edit' && !this.isJobEditMode) {
        this.enterJobEditMode();
        return;
      }

      if (actionId === 'cancel' && this.isJobEditMode) {
        this.cancelJobEdit();
      }
    });
  }

  handleClientRecordAction(actionId: RecordActionId): void {
    const action = this.clientRecordActions.find(item => item.id === actionId);
    if (!action || !action.enabled) {
      return;
    }

    this.zone.run(() => {
      switch (action.id) {
        case 'edit':
          this.enterClientEditMode();
          return;
        case 'cancel':
          this.cancelClientEdit();
          return;
        case 'save':
          this.submitClientSaveCommand();
          return;
        case 'new':
          this.setClientCommandMessage('New client entry is blocked until the legacy defaults from w_ar_client are mapped.');
          this.changeDetector.detectChanges();
          return;
        case 'delete':
          this.setClientCommandMessage('Delete is blocked until the legacy permission and referential checks from w_ar_client are mapped.');
          this.changeDetector.detectChanges();
          return;
      }
    });
  }

  handleClientRecordPointerDown(actionId: RecordActionId, event: PointerEvent): void {
    if (actionId !== 'edit' && actionId !== 'cancel') {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    this.zone.run(() => {
      if (actionId === 'edit' && !this.isClientEditMode) {
        this.enterClientEditMode();
        return;
      }

      if (actionId === 'cancel' && this.isClientEditMode) {
        this.cancelClientEdit();
      }
    });
  }

  selectJobRecordTab(tab: CoreJobRecordTab): void {
    this.activeJobRecordTab = tab;
    this.jobRecordTabRows = [];
    this.jobRecordTabColumnDefs = [];
    this.jobRecordTabStatus = '';

    if (tab === 'details' || tab === 'financial') {
      this.changeDetector.detectChanges();
      return;
    }

    this.loadJobRecordTabRows(tab);
  }

  jobRecordTabLabel(tab: CoreJobRecordTab): string {
    return this.jobRecordTabs.find(item => item.id === tab)?.label ?? tab;
  }

  private loadJobRecordTabRows(tab: Exclude<CoreJobRecordTab, 'details' | 'financial'>): void {
    const book = this.form.controls.book.value;
    const jobId = this.recordView ? this.formatFieldValue(this.recordView.row['jobId']) : '';
    if (!book || !jobId) {
      return;
    }

    this.isJobRecordTabLoading = true;
    this.jobRecordTabStatus = `Loading ${this.jobRecordTabLabel(tab)}...`;
    this.api.getJobRecordTab(tab, book, jobId).subscribe({
      next: result => {
        this.jobRecordTabRows = result.rows;
        this.jobRecordTabColumnDefs = this.buildColumns(result.rows, null);
        this.jobRecordTabStatus =
          result.rows.length > 0
            ? `${this.jobRecordTabLabel(tab)} loaded.`
            : `No ${this.jobRecordTabLabel(tab).toLowerCase()} rows found for this job.`;
        this.isJobRecordTabLoading = false;
        this.changeDetector.detectChanges();
      },
      error: () => {
        this.jobRecordTabRows = [];
        this.jobRecordTabColumnDefs = [];
        this.jobRecordTabStatus = `Could not load ${this.jobRecordTabLabel(tab)}.`;
        this.isJobRecordTabLoading = false;
        this.changeDetector.detectChanges();
      }
    });
  }

  private loadJobLookups(book: string, job: string): void {
    this.api.getJobLookups(book, job).subscribe({
      next: result => {
        this.jobLookupOptions = result.fields;
        this.changeDetector.detectChanges();
      },
      error: () => {
        this.jobLookupOptions = {};
        this.setJobCommandMessage('Job lookup dropdowns could not be loaded; free-text entry is still available.');
        this.changeDetector.detectChanges();
      }
    });
  }

  private loadJobReportLookups(book: string): void {
    this.api.getJobReportLookups(book).subscribe({
      next: result => {
        this.jobReportLookupOptions = result.fields;
        const node = this.activeJobReport?.node ?? (this.activeWorkspace === 'job-report' ? this.selectedMenuNode : null);
        if (node) {
          this.jobReportFilters = this.jobReportFilterDefinitions(node);
        }
        this.changeDetector.detectChanges();
      },
      error: () => {
        this.jobReportLookupOptions = {};
        this.changeDetector.detectChanges();
      }
    });
  }

  private loadJobOverview(book: string, job: string): void {
    this.isJobOverviewLoading = true;
    this.jobOverviewMessage = 'Loading job facts...';

    this.api.getJobOverview(book, job).subscribe({
      next: overview => {
        this.jobOverview = overview;
        this.isJobOverviewLoading = false;
        this.jobOverviewMessage = '';
        this.changeDetector.detectChanges();
      },
      error: () => {
        this.jobOverview = null;
        this.isJobOverviewLoading = false;
        this.jobOverviewMessage = 'Could not load job facts.';
        this.changeDetector.detectChanges();
      }
    });
  }

  private openRecord(dataset: CoreDataset, row: CoreGridRow): void {
    this.exitJobEditMode();
    this.exitClientEditMode();
    this.jobCommandMessage = '';
    this.clientCommandMessage = '';
    const fields = this.recordFieldsFor(row);
    const view: RecordView = {
      dataset,
      title: this.recordTitle(dataset, row),
      subtitle: this.labelFor(dataset),
      row,
      fields
    };
    const tab = this.recordWorkspaceTabFor(view);
    const existingIndex = this.recordTabs.findIndex(item => item.id === tab.id);

    this.recordTabs = existingIndex >= 0
      ? this.recordTabs.map(item => item.id === tab.id ? tab : item)
      : [...this.recordTabs, tab];
    this.activeRecordTabId = tab.id;
    this.recordView = tab.view;
    this.activeTab = dataset;
    this.statusMessage = `Opened ${this.labelFor(dataset)} record.`;
    this.changeDetector.detectChanges();
  }

  private recordWorkspaceTabFor(view: RecordView): RecordWorkspaceTab {
    const primary = this.formatFieldValue(view.row[this.primaryFieldFor(view.dataset)]);
    const fallback = this.normalizeRecordValue(view.title);
    const key = primary || fallback || `${view.dataset}-${this.recordTabs.length + 1}`;
    return {
      id: `${view.dataset}:${key}`,
      label: this.recordTabLabel(view),
      subtitle: view.subtitle,
      view
    };
  }

  private recordTabLabel(view: RecordView): string {
    const primary = this.formatFieldValue(view.row[this.primaryFieldFor(view.dataset)]);
    const key = primary || view.title;

    switch (view.dataset) {
      case 'jobs':
        return `J/C Job: ${key}`;
      case 'clients':
        return `A/R Client: ${key}`;
      case 'vendors':
        return `A/P Vendor: ${key}`;
      case 'ap-invoices':
        return `A/P Invoice: ${key}`;
      case 'ar-invoices':
        return `A/R Invoice: ${key}`;
      case 'timesheets':
        return `P/R Timesheet: ${key}`;
    }
  }

  private syncActiveRecordTab(): void {
    if (!this.recordView || !this.activeRecordTabId) {
      return;
    }

    const tab = this.recordWorkspaceTabFor(this.recordView);
    this.recordTabs = this.recordTabs.map(item =>
      item.id === this.activeRecordTabId ? { ...tab, id: this.activeRecordTabId } : item
    );
  }

  private findRecordRow(rows: CoreGridRow[], reference: RecordReference): CoreGridRow | undefined {
    return rows.find(row =>
      reference.matchFields.some(field => this.normalizeRecordValue(row[field]) === this.normalizeRecordValue(reference.value))
    );
  }

  private recordTitle(dataset: CoreDataset, row: CoreGridRow): string {
    const primaryField = this.primaryFieldFor(dataset);
    const primary = this.formatFieldValue(row[primaryField]);
    const description = this.formatFieldValue(row['description'] ?? row['name']);

    if (primary && description && primary !== description) {
      return `${primary} - ${description}`;
    }

    return primary || description || `${this.labelFor(dataset)} record`;
  }

  private primaryFieldFor(dataset: CoreDataset): string {
    switch (dataset) {
      case 'clients':
        return 'clientId';
      case 'jobs':
        return 'jobId';
      case 'vendors':
        return 'vendorId';
      case 'ap-invoices':
      case 'ar-invoices':
        return 'invoiceNo';
      case 'timesheets':
        return 'timesheetItem';
    }
  }

  private formatFieldValue(value: CoreGridRow[string]): string {
    if (value === null || value === undefined || value === '') {
      return '';
    }

    if (typeof value === 'number') {
      return new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 }).format(value);
    }

    const text = String(value);
    const dateMatch = /^(\d{4})-(\d{2})-(\d{2})T/.exec(text);
    if (dateMatch) {
      return `${dateMatch[1]}.${dateMatch[2]}.${dateMatch[3]}`;
    }

    return text;
  }

  private enterJobEditMode(): void {
    if (!this.recordView || this.recordView.dataset !== 'jobs') {
      return;
    }

    this.jobEditOriginal = { ...this.recordView.row };
    this.jobEditDraft = { ...this.recordView.row };
    this.isJobEditMode = true;
    this.setJobCommandMessage(
      'Edit mode started. Save will run through the .NET program-layer command and is guarded until legacy Job Entry rules are mapped.'
    );
    this.changeDetector.detectChanges();
    this.focusFirstJobEditableField();
  }

  private cancelJobEdit(): void {
    this.activeJobLookupField = '';
    this.jobLookupSearchText = {};

    if (!this.recordView) {
      this.exitJobEditMode();
      return;
    }

    this.recordView = {
      ...this.recordView,
      row: { ...this.jobEditOriginal }
    };
    this.syncActiveRecordTab();
    this.exitJobEditMode();
    this.setJobCommandMessage('Job edit cancelled. Original values restored.');
    this.changeDetector.detectChanges();
    this.focusFirstJobRecordField();
  }

  private exitJobEditMode(): void {
    this.isJobEditMode = false;
    this.isJobSaveRunning = false;
    this.jobEditDraft = {};
    this.jobEditOriginal = {};
  }

  private enterClientEditMode(): void {
    if (!this.recordView || this.recordView.dataset !== 'clients') {
      return;
    }

    this.clientEditOriginal = { ...this.recordView.row };
    this.clientEditDraft = { ...this.recordView.row };
    this.isClientEditMode = true;
    this.setClientCommandMessage(
      'Client edit mode started. Save is guarded until the A/R Client Entry program-layer rules from w_ar_client are migrated.'
    );
    this.changeDetector.detectChanges();
    this.focusFirstJobEditableField();
  }

  private cancelClientEdit(): void {
    if (!this.recordView) {
      this.exitClientEditMode();
      return;
    }

    this.recordView = {
      ...this.recordView,
      row: { ...this.clientEditOriginal }
    };
    this.syncActiveRecordTab();
    this.exitClientEditMode();
    this.setClientCommandMessage('Client edit cancelled. Original values restored.');
    this.changeDetector.detectChanges();
    this.focusFirstJobRecordField();
  }

  private exitClientEditMode(): void {
    this.isClientEditMode = false;
    this.isClientSaveRunning = false;
    this.clientEditDraft = {};
    this.clientEditOriginal = {};
  }

  private submitClientSaveCommand(): void {
    if (!this.recordView || !this.hasClientEditChanges) {
      this.setClientCommandMessage('No changed fields to save.');
      return;
    }

    const changedFields = this.clientChangedFields();
    this.setClientCommandMessage(
      `A/R Client Save is a legacy program-layer command, not a direct field update. Changed fields: ${changedFields.join(', ')}. Required first: export/migrate accounts receivable client objects for w_ar_client and its detail DataWindows.`
    );
    this.changeDetector.detectChanges();
  }

  private submitJobSaveCommand(): void {
    if (!this.recordView || !this.hasJobEditChanges) {
      this.setJobCommandMessage('No changed fields to save.');
      return;
    }

    const book = this.form.controls.book.value;
    const job = this.formatFieldValue(this.recordView.row['jobId']);
    const changedFields = this.jobChangedFields();
    this.isJobSaveRunning = true;
    this.setJobCommandMessage('Running Job Entry save command through the .NET program layer...');

    this.api
      .saveJobRecord({
        book,
        job,
        original: this.jobEditOriginal,
        draft: this.jobEditDraft,
        changedFields,
        userId: 'SHYMKVIK'
      })
      .subscribe({
        next: () => {
          this.isJobSaveRunning = false;
          this.refreshJobRecordAfterSave(job, 'Job saved through the migrated Job Entry program layer.');
        },
        error: (error: HttpErrorResponse) => {
          this.isJobSaveRunning = false;
          const response = error.error as JobRecordSaveCommandResponse | undefined;
          if (response?.status === 'legacy-program-layer-not-mapped') {
            const references = response.requiredLegacyReferences
              .slice(0, 3)
              .map(item => `${item.library}/${item.objectName}`)
              .join(', ');
            this.setJobCommandMessage(
              `${response.message} Changed fields: ${response.changedFields.join(', ')}. Required first: ${references}.`
            );
            this.changeDetector.detectChanges();
            return;
          }

          this.setJobCommandMessage('Could not run the Job Entry save command.');
          this.changeDetector.detectChanges();
        }
      });
  }

  private setJobCommandMessage(message: string): void {
    this.jobCommandMessage = message;
    this.statusMessage = message;
  }

  private setClientCommandMessage(message: string): void {
    this.clientCommandMessage = message;
    this.statusMessage = message;
  }

  private lookupOptionForValue(field: string, value: string): CoreLookupOption | undefined {
    return (this.jobLookupOptions[field] ?? []).find(option => this.normalizeEditValue(option.value) === this.normalizeEditValue(value));
  }

  private refreshJobRecordAfterSave(job: string, message: string): void {
    const book = this.form.controls.book.value;
    if (!book) {
      this.setJobCommandMessage(message);
      this.changeDetector.detectChanges();
      return;
    }

    this.api.getJobRecord(book, job).subscribe({
      next: row => {
        this.openRecord('jobs', row);
        this.selectJobRecordTab(this.activeJobRecordTab);
        this.loadJobOverview(book, job);
        this.setJobCommandMessage(message);
        this.changeDetector.detectChanges();
      },
      error: () => {
        this.exitJobEditMode();
        this.setJobCommandMessage(`${message} Refresh failed, so please reopen the job to see server-side legacy defaults.`);
        this.changeDetector.detectChanges();
      }
    });
  }

  private jobChangedFields(): string[] {
    return Object.keys(this.jobEditDraft)
      .filter(field => this.normalizeEditValue(this.jobEditDraft[field]) !== this.normalizeEditValue(this.jobEditOriginal[field]))
      .sort((left, right) => left.localeCompare(right));
  }

  private clientChangedFields(): string[] {
    return Object.keys(this.clientEditDraft)
      .filter(field => this.normalizeEditValue(this.clientEditDraft[field]) !== this.normalizeEditValue(this.clientEditOriginal[field]))
      .sort((left, right) => left.localeCompare(right));
  }

  private isClientFieldLocked(field: string): boolean {
    return ['clientId', 'netOut', 'purchase', 'payment', 'lastUpdate'].includes(field);
  }

  private isJobFieldLocked(field: string): boolean {
    return [
      'jobId',
      'addedDateTime',
      'addedBy',
      'lastUpdate',
      'toDateCost',
      'toDateRevenue',
      'toDatePayment',
      'commitment',
      'yearOpenCost',
      'yearOpenRevenue',
      'period1Cost',
      'period2Cost',
      'period3Cost',
      'period4Cost',
      'period5Cost',
      'period6Cost',
      'period7Cost',
      'period8Cost',
      'period9Cost',
      'period10Cost',
      'period11Cost',
      'period12Cost',
      'period1Revenue',
      'period2Revenue',
      'period3Revenue',
      'period4Revenue',
      'period5Revenue',
      'period6Revenue',
      'period7Revenue',
      'period8Revenue',
      'period9Revenue',
      'period10Revenue',
      'period11Revenue',
      'period12Revenue'
    ].includes(field);
  }

  private inputValue(event: Event): string {
    return event.target instanceof HTMLInputElement ||
      event.target instanceof HTMLTextAreaElement ||
      event.target instanceof HTMLSelectElement
      ? event.target.value
      : '';
  }

  private commitExactLookupMatch(field: string): void {
    if (!Object.prototype.hasOwnProperty.call(this.jobLookupSearchText, field)) {
      return;
    }

    const option = this.matchLookupOption(field, this.jobLookupSearchText[field]);
    if (!option) {
      return;
    }

    this.jobEditDraft = {
      ...this.jobEditDraft,
      [field]: option.value
    };
  }

  private matchLookupOption(field: string, inputValue: string): CoreLookupOption | undefined {
    const value = inputValue.trim();
    if (!this.hasJobLookupOptions(field)) {
      return undefined;
    }

    if (!value) {
      return this.jobLookupOptionsFor(field).find(item => item.value === '');
    }

    const normalizedValue = value.toLowerCase();
    return this.jobLookupOptionsFor(field).find(item =>
      item.value.toLowerCase() === normalizedValue ||
      item.label.toLowerCase() === normalizedValue ||
      this.lookupOptionLabel(item).toLowerCase() === normalizedValue
    );
  }

  private rawEditValue(value: CoreGridRow[string]): string {
    if (value === null || value === undefined) {
      return '';
    }

    const text = String(value);
    const dateMatch = /^(\d{4})-(\d{2})-(\d{2})T/.exec(text);
    if (dateMatch) {
      return `${dateMatch[1]}.${dateMatch[2]}.${dateMatch[3]}`;
    }

    return text;
  }

  private toDateInputValue(value: string): string {
    const normalized = value.trim();
    if (!normalized || normalized.startsWith('1900.01.01') || normalized.startsWith('1900-01-01')) {
      return '';
    }

    const legacyDateMatch = /^(\d{4})\.(\d{2})\.(\d{2})/.exec(normalized);
    if (legacyDateMatch) {
      return `${legacyDateMatch[1]}-${legacyDateMatch[2]}-${legacyDateMatch[3]}`;
    }

    const isoDateMatch = /^(\d{4})-(\d{2})-(\d{2})/.exec(normalized);
    if (isoDateMatch) {
      return `${isoDateMatch[1]}-${isoDateMatch[2]}-${isoDateMatch[3]}`;
    }

    return '';
  }

  private toLegacyDateValue(value: string): string {
    const normalized = value.trim();
    const isoDateMatch = /^(\d{4})-(\d{2})-(\d{2})/.exec(normalized);
    return isoDateMatch ? `${isoDateMatch[1]}.${isoDateMatch[2]}.${isoDateMatch[3]}` : normalized;
  }

  private normalizeEditValue(value: CoreGridRow[string]): string {
    return this.rawEditValue(value).trim();
  }

  private normalizeRecordValue(value: CoreGridRow[string]): string {
    return String(value ?? '').trim().toLowerCase();
  }

  private percentOf(value: number, total: number): number | null {
    if (!Number.isFinite(value) || !Number.isFinite(total) || total === 0) {
      return null;
    }

    return (value / total) * 100;
  }

  private loadSummary(book: string): void {
    this.api.getSummary(book).subscribe({
      next: summary => {
        this.summary = summary;
      },
      error: () => {
        this.summary = null;
      }
    });
  }

  private buildModernMenuGroups(modules: CoreMenuNode[]): ModernMenuGroup[] {
    const definitions: Omit<ModernMenuGroup, 'items'>[] = [
      {
        id: 'home',
        label: 'Home & Work Queue',
        description: 'Tasks, approvals, alerts, recent records, and exception-driven work.',
        iconClass: 'icon-work-queue',
        actionLabel: 'Open work queue',
        links: [
          {
            label: 'Work Queue',
            iconClass: 'icon-task',
            children: [
              { label: 'My Tasks', iconClass: 'icon-task', groupId: 'home' },
              { label: 'Approvals', iconClass: 'icon-approval', groupId: 'home' },
              { label: 'Alerts', iconClass: 'icon-alert', groupId: 'home' }
            ]
          },
          {
            label: 'Workspace History',
            iconClass: 'icon-recent',
            children: [
              { label: 'Recent Records', iconClass: 'icon-recent', groupId: 'home' },
              { label: 'Recent Jobs', iconClass: 'icon-job', dataset: 'jobs' },
              { label: 'Recent Invoices', iconClass: 'icon-payables', dataset: 'ap-invoices' }
            ]
          }
        ]
      },
      {
        id: 'projects-jobs',
        label: 'Projects & Jobs',
        description: 'Jobs, cost codes, budgets, progress billing, and field documents.',
        iconClass: 'icon-job',
        actionLabel: 'Open project work',
        links: [
          {
            label: 'Jobs',
            iconClass: 'icon-job',
            children: [
              { label: 'Job List', iconClass: 'icon-job', dataset: 'jobs' },
              { label: 'Cost Codes', iconClass: 'icon-cost-code', dataset: 'jobs' },
              { label: 'Budgets', iconClass: 'icon-budget', dataset: 'jobs' }
            ]
          },
          {
            label: 'Billing',
            iconClass: 'icon-progress-billing',
            children: [
              { label: 'Progress Billing', iconClass: 'icon-progress-billing', dataset: 'ar-invoices' },
              { label: 'AR Invoices', iconClass: 'icon-receivables', dataset: 'ar-invoices' }
            ]
          },
          {
            label: 'Field Operations',
            iconClass: 'icon-document',
            children: [
              { label: 'Field Documents', iconClass: 'icon-document', groupId: 'projects-jobs' },
              { label: 'Timesheets', iconClass: 'icon-timesheet', payroll: true, payrollView: 'timesheets' }
            ]
          }
        ]
      },
      {
        id: 'people-payroll',
        label: 'People & Payroll',
        description: 'Employees, timesheets, field time, pay runs, cheques, and HR.',
        iconClass: 'icon-payroll',
        actionLabel: 'Open payroll',
        links: [
          {
            label: 'Employees',
            iconClass: 'icon-employee',
            children: [
              { label: 'Employee List', iconClass: 'icon-employee', payroll: true, payrollView: 'employees' },
              { label: 'Employee Setup', iconClass: 'icon-setup', payroll: true, payrollView: 'setup' }
            ]
          },
          {
            label: 'Time Entry',
            iconClass: 'icon-timesheet',
            children: [
              { label: 'Timesheets', iconClass: 'icon-timesheet', payroll: true, payrollView: 'timesheets' },
              { label: 'Field Timesheets', iconClass: 'icon-field-timesheet', payroll: true, payrollView: 'field-timesheets' }
            ]
          },
          {
            label: 'Pay Runs',
            iconClass: 'icon-payroll-run',
            children: [
              { label: 'Payroll Runs', iconClass: 'icon-payroll-run', payroll: true, payrollView: 'cheques' },
              { label: 'Cheques', iconClass: 'icon-cheque', payroll: true, payrollView: 'cheques' },
              { label: 'Payroll Setup', iconClass: 'icon-setup', payroll: true, payrollView: 'setup' }
            ]
          }
        ]
      },
      {
        id: 'purchasing-vendors',
        label: 'Purchasing & Vendors',
        description: 'Vendors, purchase orders, AP invoices, subcontracts, payments, and approvals.',
        iconClass: 'icon-payables',
        actionLabel: 'Open purchasing',
        links: [
          {
            label: 'Vendors',
            iconClass: 'icon-vendor',
            children: [
              { label: 'Vendor List', iconClass: 'icon-vendor', dataset: 'vendors' },
              { label: 'Subcontracts', iconClass: 'icon-subcontract', groupId: 'purchasing-vendors' }
            ]
          },
          {
            label: 'Procurement',
            iconClass: 'icon-purchase-order',
            children: [
              { label: 'Purchase Orders', iconClass: 'icon-purchase-order', groupId: 'purchasing-vendors' },
              { label: 'AP Invoices', iconClass: 'icon-payables', dataset: 'ap-invoices' }
            ]
          },
          {
            label: 'Payments',
            iconClass: 'icon-payment',
            children: [
              { label: 'Payment Review', iconClass: 'icon-payment', dataset: 'ap-invoices' },
              { label: 'AP Approvals', iconClass: 'icon-approval', dataset: 'ap-invoices' }
            ]
          }
        ]
      },
      {
        id: 'customers-revenue',
        label: 'Customers & Revenue',
        description: 'Clients, contracts, AR invoices, receipts, collections, and revenue workflows.',
        iconClass: 'icon-receivables',
        actionLabel: 'Open revenue',
        links: [
          {
            label: 'Customers',
            iconClass: 'icon-client',
            children: [
              { label: 'Client List', iconClass: 'icon-client', dataset: 'clients' },
              { label: 'Contracts', iconClass: 'icon-contract', dataset: 'jobs' }
            ]
          },
          {
            label: 'Accounts Receivable',
            iconClass: 'icon-receivables',
            children: [
              { label: 'AR Invoices', iconClass: 'icon-receivables', dataset: 'ar-invoices' },
              { label: 'Receipts', iconClass: 'icon-receipt', dataset: 'ar-invoices' },
              { label: 'Collections', iconClass: 'icon-collections', dataset: 'ar-invoices' }
            ]
          }
        ]
      },
      {
        id: 'finance-compliance',
        label: 'Finance & Compliance',
        description: 'General ledger, banking, tax, periods, audit trail, and cash forecasting.',
        iconClass: 'icon-ledger',
        actionLabel: 'Open finance',
        links: [
          {
            label: 'Accounting',
            iconClass: 'icon-ledger',
            children: [
              { label: 'General Ledger', iconClass: 'icon-ledger', groupId: 'finance-compliance' },
              { label: 'Periods', iconClass: 'icon-period', groupId: 'finance-compliance' },
              { label: 'Audit Trail', iconClass: 'icon-audit', groupId: 'finance-compliance' }
            ]
          },
          {
            label: 'Cash & Tax',
            iconClass: 'icon-bank',
            children: [
              { label: 'Banking', iconClass: 'icon-bank', groupId: 'finance-compliance' },
              { label: 'Tax', iconClass: 'icon-tax', groupId: 'finance-compliance' }
            ]
          }
        ]
      },
      {
        id: 'assets-inventory',
        label: 'Assets & Inventory',
        description: 'Equipment, inventory, maintenance, usage, rentals, and materials.',
        iconClass: 'icon-equipment',
        actionLabel: 'Open assets',
        links: [
          {
            label: 'Assets',
            iconClass: 'icon-equipment',
            children: [
              { label: 'Equipment', iconClass: 'icon-equipment', groupId: 'assets-inventory' },
              { label: 'Maintenance', iconClass: 'icon-maintenance', groupId: 'assets-inventory' },
              { label: 'Usage', iconClass: 'icon-usage', groupId: 'assets-inventory' }
            ]
          },
          {
            label: 'Inventory',
            iconClass: 'icon-inventory',
            children: [
              { label: 'Inventory List', iconClass: 'icon-inventory', groupId: 'assets-inventory' }
            ]
          }
        ]
      },
      {
        id: 'reports-insights',
        label: 'Reports & Insights',
        description: 'Dashboards, financial reports, job-cost reports, payroll reports, and exports.',
        iconClass: 'icon-report',
        actionLabel: 'Open insights',
        links: [
          {
            label: 'Dashboards',
            iconClass: 'icon-dashboard',
            children: [
              { label: 'Executive Dashboard', iconClass: 'icon-dashboard', groupId: 'reports-insights' },
              { label: 'Job Dashboard', iconClass: 'icon-job-report', dataset: 'jobs' }
            ]
          },
          {
            label: 'Reports',
            iconClass: 'icon-report',
            children: [
              { label: 'Financial Reports', iconClass: 'icon-report', groupId: 'reports-insights' },
              {
                label: 'Job Cost Reports',
                iconClass: 'icon-job-report',
                children: [
                  { label: 'Job List', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'a' },
                  { label: 'Job Status Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'b' },
                  { label: 'Job Cash Position Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'c' },
                  { label: 'Job Over/Under Billings Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'd' },
                  { label: 'Job First 6 Months Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'e' },
                  { label: 'Job Last 6 Months Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'f' },
                  { label: 'Job Profit Accrual Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'g' },
                  { label: 'Job Recent Activity Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'h' },
                  { label: 'Centre to Source Comparison', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'i' },
                  { label: 'Job Cost Transaction Comparison', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'j' },
                  { label: 'Job Costs and Revenue Report', iconClass: 'icon-job-report', legacyProgram: 'JCJREP', legacyReport: 'k' }
                ]
              },
              { label: 'Payroll Reports', iconClass: 'icon-payroll-report', payroll: true, payrollView: 'setup' }
            ]
          },
          {
            label: 'Exports',
            iconClass: 'icon-export',
            children: [
              { label: 'Exports', iconClass: 'icon-export', groupId: 'reports-insights' }
            ]
          }
        ]
      },
      {
        id: 'administration',
        label: 'Administration',
        description: 'Users, roles, company setup, lookups, integrations, DBA tools, and security.',
        iconClass: 'icon-admin',
        actionLabel: 'Open admin',
        links: [
          {
            label: 'Security',
            iconClass: 'icon-security',
            children: [
              { label: 'Users & Roles', iconClass: 'icon-users', groupId: 'administration' },
              { label: 'Security', iconClass: 'icon-security', groupId: 'administration' }
            ]
          },
          {
            label: 'System Setup',
            iconClass: 'icon-setup',
            children: [
              { label: 'Company Setup', iconClass: 'icon-setup', groupId: 'administration' },
              { label: 'Lookups', iconClass: 'icon-lookup', groupId: 'administration' },
              { label: 'Integrations', iconClass: 'icon-integration', groupId: 'administration' }
            ]
          }
        ]
      }
    ];

    const buckets = new Map(definitions.map(definition => [definition.id, [] as CoreMenuNode[]]));
    for (const node of this.flattenMenuNodes(modules)) {
      buckets.get(this.modernGroupIdForNode(node))?.push(node);
    }

    return definitions.map(definition => ({
      ...definition,
      items: (buckets.get(definition.id) ?? []).sort((a, b) => a.label.localeCompare(b.label))
    }));
  }

  private flattenMenuNodes(nodes: CoreMenuNode[]): CoreMenuNode[] {
    const flattened: CoreMenuNode[] = [];
    for (const node of nodes) {
      if (node.program || node.itemType === 'report' || node.children.length === 0) {
        flattened.push(node);
      }

      flattened.push(...this.flattenMenuNodes(node.children));
    }

    return flattened.filter(node => node.label.trim().length > 0);
  }

  private modernGroupIdForNode(node: CoreMenuNode): string {
    const text = `${node.program} ${node.label} ${node.description} ${node.itemType} ${node.windowName}`.toLowerCase();
    const program = node.program.toUpperCase();
    const top = node.menu1.toLowerCase();

    if (top === 'x' || program === 'EXIT') {
      return 'administration';
    }

    if (node.itemType.includes('report') || text.includes('report') || text.includes('dashboard') || text.includes('forecast')) {
      if (program.startsWith('AM') || text.includes('database') || text.includes('dba')) {
        return 'administration';
      }

      return 'reports-insights';
    }

    if (top === 'a' || program.startsWith('AP') || text.includes('vendor') || text.includes('payable') || text.includes('payment') || text.includes('subcontract')) {
      return 'purchasing-vendors';
    }

    if (top === 'b' || program.startsWith('AR') || text.includes('client') || text.includes('receivable') || text.includes('billing') || text.includes('receipt') || text.includes('customer')) {
      return 'customers-revenue';
    }

    if (top === 'c' || top === 'f' || program.startsWith('PR') || program.startsWith('HR') || text.includes('payroll') || text.includes('employee') || text.includes('timesheet') || text.includes('human resources')) {
      return 'people-payroll';
    }

    if (top === 'd' || program.startsWith('GL') || text.includes('general ledger') || text.includes('bank') || text.includes('tax') || text.includes('period') || text.includes('cash flow')) {
      return 'finance-compliance';
    }

    if (top === 'e' || top === 'h' || program.startsWith('JC') || program.startsWith('PM') || text.includes('job') || text.includes('project') || text.includes('cost code') || text.includes('document')) {
      return 'projects-jobs';
    }

    if (top === 'g' || top === 'i' || program.startsWith('EQ') || program.startsWith('INV') || text.includes('equipment') || text.includes('inventory') || text.includes('maintenance')) {
      return 'assets-inventory';
    }

    if (top === 'j') {
      return 'reports-insights';
    }

    if (top === 'k' || program.startsWith('AM') || text.includes('admin') || text.includes('setup') || text.includes('security') || text.includes('book') || text.includes('database') || text.includes('user')) {
      return 'administration';
    }

    return 'home';
  }

  private matchesModernGroup(group: ModernMenuGroup, query: string): boolean {
    return [group.label, group.description, group.actionLabel]
      .join(' ')
      .toLowerCase()
      .includes(query);
  }

  private matchesModernMenuItem(node: CoreMenuNode, query: string): boolean {
    return this.matchesMenuNode(node, query);
  }

  private filterMenuNode(node: CoreMenuNode, query: string): CoreMenuNode | null {
    const filteredChildren = node.children
      .map(child => this.filterMenuNode(child, query))
      .filter((child): child is CoreMenuNode => child !== null);

    if (this.matchesMenuNode(node, query) || filteredChildren.length > 0) {
      return {
        ...node,
        children: filteredChildren
      };
    }

    return null;
  }

  private matchesMenuNode(node: CoreMenuNode, query: string): boolean {
    if (query.startsWith('/')) {
      const shortcutQuery = query.slice(1).replace(/\s+/g, '');
      return shortcutQuery.length > 0 && this.menuShortcutPath(node).includes(shortcutQuery);
    }

    return [
      node.label,
      node.description,
      node.program,
      node.windowName,
      node.microhelp,
      this.menuShortcutPath(node)
    ]
      .join(' ')
      .toLowerCase()
      .includes(query);
  }

  isPayrollMenuNode(node: CoreMenuNode): boolean {
    const program = node.program.toUpperCase();
    return node.menu1.toLowerCase() === 'c'
      || program.startsWith('PR')
      || node.windowName.toLowerCase().startsWith('w_pr_');
  }

  isJobReportNode(node: CoreMenuNode): boolean {
    if (node.itemType.toLowerCase() !== 'report') {
      return false;
    }

    const supportedDatawindows = new Set([
      'd_report_job_list',
      'd_report_job_status',
      'd_report_job_cash_position',
      'd_report_job_over_under_billings',
      'd_report_job_first_6_months',
      'd_report_job_last_6_months',
      'd_report_job_profit_accrual',
      'd_report_job_recent_activity',
      'd_report_jc_centre_to_src_comp_revenue',
      'd_report_jc_centre_to_src_comp_cost',
      'd_report_jc_centre_to_transaction_comp',
      'd_report_jc_job_cost_and_revenue'
    ]);

    return node.program.toUpperCase() === 'JCJREP'
      || supportedDatawindows.has(node.windowName.toLowerCase());
  }

  datasetForMenuNode(node: CoreMenuNode): CoreDataset | null {
    const program = node.program.toUpperCase();
    const windowName = node.windowName.toLowerCase();

    if (['APVENT'].includes(program) || windowName.includes('w_ap_vendor')) {
      return 'vendors';
    }

    if (['APIENT'].includes(program) || windowName.includes('w_ap_ap_invoice')) {
      return 'ap-invoices';
    }

    if (['ARCENT'].includes(program) || windowName.includes('w_ar_client')) {
      return 'clients';
    }

    if (['ARIENT', 'ARINEW'].includes(program) || windowName.includes('w_ar_ar_invoice')) {
      return 'ar-invoices';
    }

    if (['PRTENT', 'PRFENT'].includes(program) || windowName.includes('w_pr_timesheet')) {
      return 'timesheets';
    }

    if (['JCJENT'].includes(program) || windowName.includes('w_jc_job')) {
      return 'jobs';
    }

    return null;
  }

  private activateMenuShortcut(key: string): void {
    const options = this.currentShortcutOptions();
    const match = options.find(node => this.legacyKey(node).toLowerCase() === key);
    if (!match) {
      this.menuStatusMessage = `No menu item [${key}] at this level. ${this.describeShortcutOptions(options)}`;
      return;
    }

    this.selectedMenuNode = match;
    if (match.children.length > 0) {
      this.expandMenuNode(match);
      this.menuQuickAccessPath = [...this.menuQuickAccessPath, match];
      this.menuStatusMessage = `${match.label}: ${this.describeShortcutOptions(match.children)}`;
      return;
    }

    this.stopMenuQuickAccess();
    this.selectLegacyNode(match);
  }

  private moveMenuQuickAccessUp(): void {
    if (this.menuQuickAccessPath.length === 0) {
      this.stopMenuQuickAccess('Menu quick access cancelled.');
      return;
    }

    this.menuQuickAccessPath = this.menuQuickAccessPath.slice(0, -1);
    const options = this.currentShortcutOptions();
    this.menuStatusMessage = `Menu quick access: ${this.describeShortcutOptions(options)}`;
  }

  private currentShortcutOptions(): CoreMenuNode[] {
    const parent = this.menuQuickAccessPath.at(-1);
    return parent?.children ?? this.legacyMenuModules;
  }

  private expandMenuNode(node: CoreMenuNode): void {
    this.expandedMenuKeys = new Set([...this.expandedMenuKeys, node.key]);
  }

  private describeShortcutOptions(nodes: CoreMenuNode[]): string {
    const visibleOptions = nodes
      .slice(0, 12)
      .map(node => `[${this.legacyKey(node)}] ${node.label}`)
      .join(', ');
    const extraCount = Math.max(nodes.length - 12, 0);
    return extraCount > 0 ? `${visibleOptions}, +${extraCount} more` : visibleOptions || 'no shortcuts available';
  }

  labelFor(tab: CoreDataset): string {
    return this.tabs.find(item => item.id === tab)?.label ?? tab;
  }
}
