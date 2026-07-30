export interface RhumbixConfigResponse {
  defaultBook: string;
  allowedBooks: string[];
  defaultStartDate: string;
  defaultEndDate: string;
  currentPrPeriod: number;
  canImportTimesheets: boolean;
  canSyncProjects: boolean;
}

export interface RhumbixPendingCountResponse {
  book: string;
  pendingProjectCount: number;
}

export interface RhumbixImportTimesheetsRequest {
  book: string;
  startDate: string;
  endDate: string;
  prPeriod: number;
}

export interface RhumbixImportTimesheetsResponse {
  runId: number;
  importedCount: number;
  errorCount: number;
  totalFromRhumbix: number;
  status: string;
  message: string;
}

export interface RhumbixSyncProjectsRequest {
  book: string;
  forceFullSync: boolean;
}

export interface RhumbixSyncProjectsResponse {
  runId: number;
  status: string;
  message: string;
}

export interface RhumbixImportErrorRow {
  errorId: number;
  employeeId: string | null;
  shiftDate: string | null;
  rhumbixProject: string | null;
  rhumbixCostCode: string | null;
  errorType: string | null;
  errorMessage: string | null;
  errorDateTime: string | null;
}

export interface RhumbixSyncHistoryRow {
  syncDateTime: string;
  syncType: string | null;
  recordsAttempted: number | null;
  recordsCreated: number | null;
  recordsUpdated: number | null;
  recordsFailed: number | null;
  statusDisplay: string;
}

export interface GridQueryResponse<T> {
  rows: T[];
  rowCount: number;
}
