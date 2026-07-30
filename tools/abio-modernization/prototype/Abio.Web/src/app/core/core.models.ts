export interface CoreBookRow {
  book: string;
  description: string;
}

export interface CoreConfigResponse {
  defaultBook: string;
  books: CoreBookRow[];
}

export interface CoreSummaryResponse {
  activeClients: number;
  activeJobs: number;
  activeVendors: number;
  activeEmployees: number;
  timesheets: number;
  apInvoiceLines: number;
  apNetPurchase: number;
  arInvoiceLines: number;
  arNetPurchase: number;
  glTransactions: number;
  glAmount: number;
  jcTransactions: number;
}

export interface CoreMenuResponse {
  modules: CoreMenuNode[];
  menuRowCount: number;
  reportRowCount: number;
}

export interface CoreLookupOption {
  value: string;
  label: string;
}

export interface CoreLookupResponse {
  fields: Record<string, CoreLookupOption[]>;
}

export interface CoreMenuNode {
  key: string;
  program: string;
  label: string;
  description: string;
  itemType: string;
  profile: string;
  entrySessionFlag: string;
  microhelp: string;
  helpUrl: string;
  windowName: string;
  menu1: string;
  menu2: string;
  menu3: string;
  children: CoreMenuNode[];
}

export interface GridQueryResponse<T> {
  rows: T[];
  rowCount: number;
}

export interface CoreJobReportResponse {
  title: string;
  reportKey: string;
  datawindowName: string;
  source: string;
  filters: string[];
  columns: CoreJobReportColumn[];
  rows: CoreGridRow[];
  rowCount: number;
}

export interface CoreJobReportColumn {
  field: string;
  headerName: string;
  width: number;
  numeric: boolean;
}

export interface CoreJobOverview {
  jobId: string;
  description: string | null;
  client: string | null;
  clientName: string | null;
  activeFlag: string | null;
  jobType: string | null;
  startDate: string | null;
  completeDate: string | null;
  currentBudget: number;
  toDateCost: number;
  toDateRevenue: number;
  expectedCost: number;
  expectedRevenue: number;
  timesheetLines: number;
  timesheetHours: number;
  timesheetTotal: number;
  apInvoiceLines: number;
  apNetPurchase: number;
  arInvoiceLines: number;
  arNetPurchase: number;
  jcTransactionLines: number;
  jcCostAmount: number;
}

export type CoreGridRow = Record<string, string | number | boolean | null>;

export interface LegacyProgramReference {
  library: string;
  objectName: string;
  role: string;
}

export interface JobRecordSaveCommandRequest {
  book: string;
  job: string;
  original: CoreGridRow;
  draft: CoreGridRow;
  changedFields: string[];
  userId: string;
}

export interface JobRecordSaveCommandResponse {
  status: string;
  message: string;
  changedFields: string[];
  requiredLegacyReferences: LegacyProgramReference[];
  requiredCommandPhases: string[];
}

export type CoreDataset = 'clients' | 'jobs' | 'vendors' | 'ap-invoices' | 'ar-invoices' | 'timesheets';
export type CoreJobDetailDataset = 'timesheets' | 'ap-invoices' | 'ar-invoices' | 'job-cost-transactions';
export type CoreJobRecordTab = 'details' | 'financial' | 'shipping' | 'checklist' | 'documents';
