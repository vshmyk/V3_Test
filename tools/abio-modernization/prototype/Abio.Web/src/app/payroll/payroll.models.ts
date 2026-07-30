export type PayrollGridRow = Record<string, string | number | boolean | null>;

export interface PayrollListResult {
  book: string;
  search: string;
  limit: number;
  rows: PayrollGridRow[];
  rowCount: number;
}

export interface PayrollRecordResult {
  recordType: string;
  status: string;
  message: string;
  header: PayrollGridRow | null;
  children: Record<string, PayrollGridRow[]>;
  tabs: string[];
}

export interface PayrollSetupResult {
  setupArea: string;
  status: string;
  rows: PayrollGridRow[];
  legacySourceOrMessage: string;
}

export interface PayrollLookupOption {
  value: string;
  label: string;
}

export interface PayrollLookupResult {
  book: string;
  fields: Record<string, PayrollLookupOption[]>;
}

export interface PayrollValidationCatalog {
  version: string;
  sourceObjects: LegacyProgramReference[];
  recordTypes: Record<string, PayrollValidationRule[]>;
}

export interface PayrollValidationRule {
  ruleId: string;
  field: string;
  ruleType: string;
  message: string;
  severity: string;
  allowedValues: string[];
  appliesOn: string[];
  legacySource: string;
  frontendHint: string;
}

export interface PayrollValidationError {
  field: string;
  message: string;
  ruleId: string;
  severity: string;
}

export interface PayrollCommandRequest {
  book: string;
  commandName: string;
  userId: string;
  payload: PayrollGridRow;
  changedFields: string[];
  dryRun: boolean;
}

export interface LegacyProgramReference {
  library: string;
  objectName: string;
  role: string;
}

export interface PayrollCommandResult {
  status: string;
  commandName: string;
  message: string;
  legacyProgram: string;
  requiredLegacyReferences: LegacyProgramReference[];
  requiredMigrationSteps: string[];
  changedFields: string[];
  validationErrors: PayrollValidationError[];
}

export interface PayrollCommandDefinition {
  name: string;
  displayName: string;
  description: string;
  legacyProgram: string;
  status: string;
  legacyReferences: LegacyProgramReference[];
}

export interface PayrollModuleInventory {
  module: string;
  status: string;
  sourceLibraries: string[];
  menuPrograms: string[];
  commands: PayrollCommandDefinition[];
  readModels: string[];
  safetyNotes: string[];
}

export type PayrollListKey = 'employees' | 'timesheets' | 'field-timesheets' | 'cheques';
export type PayrollSetupKey =
  | 'payPeriods'
  | 'tradeUnions'
  | 'occupation'
  | 'occupationRates'
  | 'premiumTypes'
  | 'timesheetStatuses'
  | 'wcbRates'
  | 'federalTax'
  | 'provinceIncomeTax';
