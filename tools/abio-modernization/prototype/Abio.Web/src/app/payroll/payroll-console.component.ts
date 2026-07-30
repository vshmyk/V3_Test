import { CommonModule } from '@angular/common';
import { Component, ElementRef, HostBinding, HostListener, Input, OnChanges, OnInit, SimpleChanges, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AgGridAngular } from 'ag-grid-angular';
import { AllCommunityModule, ColDef, ICellRendererParams, ModuleRegistry } from 'ag-grid-community';
import { CoreApiService } from '../core/core-api.service';
import { CoreBookRow, CoreMenuNode } from '../core/core.models';
import { ArrowFieldNavigationDirective } from '../shared/arrow-field-navigation.directive';
import { PayrollApiService } from './payroll-api.service';
import {
  PayrollCommandDefinition,
  PayrollCommandResult,
  PayrollGridRow,
  PayrollListKey,
  PayrollLookupResult,
  PayrollModuleInventory,
  PayrollRecordResult,
  PayrollSetupKey,
  PayrollValidationCatalog,
  PayrollValidationError,
  PayrollValidationRule
} from './payroll.models';

ModuleRegistry.registerModules([AllCommunityModule]);

type PayrollViewKey = PayrollListKey | 'setup';

interface PayrollView {
  key: PayrollViewKey;
  label: string;
  description: string;
}

interface SetupView {
  key: PayrollSetupKey;
  label: string;
}

type PayrollRecordField = [string, string | number | boolean | null];

@Component({
  selector: 'app-payroll-console',
  imports: [CommonModule, FormsModule, AgGridAngular, ArrowFieldNavigationDirective],
  templateUrl: './payroll-console.component.html',
  styleUrl: './payroll-console.component.scss'
})
export class PayrollConsoleComponent implements OnChanges, OnInit {
  private readonly api = inject(PayrollApiService);
  private readonly coreApi = inject(CoreApiService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly elementRef = inject<ElementRef<HTMLElement>>(ElementRef);

  readonly views: PayrollView[] = [
    { key: 'employees', label: 'Employees', description: 'Employee Entry read model' },
    { key: 'timesheets', label: 'Timesheets', description: 'Timesheet Entry read model' },
    { key: 'field-timesheets', label: 'Field Timesheets', description: 'Field review batches' },
    { key: 'cheques', label: 'Cheques', description: 'Cheque Entry read model' },
    { key: 'setup', label: 'Setup', description: 'Payroll reference/setup tables' }
  ];

  readonly setupViews: SetupView[] = [
    { key: 'payPeriods', label: 'Pay Periods' },
    { key: 'tradeUnions', label: 'Trade Unions' },
    { key: 'occupation', label: 'Occupations' },
    { key: 'occupationRates', label: 'Occupation Rates' },
    { key: 'premiumTypes', label: 'Premium Types' },
    { key: 'timesheetStatuses', label: 'Timesheet Statuses' },
    { key: 'wcbRates', label: 'WCB Rates' },
    { key: 'federalTax', label: 'Federal Tax' },
    { key: 'provinceIncomeTax', label: 'Province Tax' }
  ];

  @Input() embedded = false;
  @Input() requestedView: string | null = null;

  @HostBinding('class.embedded-host')
  get embeddedHost(): boolean {
    return this.embedded;
  }

  readonly defaultColDef: ColDef = {
    sortable: true,
    filter: true,
    resizable: true,
    minWidth: 120
  };

  readonly idLinkRenderer = (params: ICellRendererParams<PayrollGridRow>) => {
    const value = params.valueFormatted ?? params.value ?? '';
    return `<button class="payroll-link-cell" type="button">${value}</button>`;
  };

  books: CoreBookRow[] = [];
  selectedBook = 'ABIODEMO';
  activeView: PayrollViewKey = 'employees';
  activeSetup: PayrollSetupKey = 'timesheetStatuses';
  searchText = '';
  includeHistory = false;
  rowLimit = 250;

  inventory: PayrollModuleInventory | null = null;
  lookupResult: PayrollLookupResult | null = null;
  validationCatalog: PayrollValidationCatalog | null = null;
  rows: PayrollGridRow[] = [];
  selectedRecord: PayrollRecordResult | null = null;
  selectedRecordTab = 'Details';
  commandResult: PayrollCommandResult | null = null;
  isPayrollRecordEditMode = false;
  payrollRecordEditOriginal: PayrollGridRow = {};
  payrollRecordEditDraft: PayrollGridRow = {};
  isLoading = false;
  statusMessage = 'Loading Payroll middle tier...';
  legacyMenuModules: CoreMenuNode[] = [];
  expandedMenuKeys = new Set<string>();
  selectedMenuNode: CoreMenuNode | null = null;
  menuSearchText = '';
  menuStatusMessage = 'Loading legacy menu from ABIO_DEMO...';

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['requestedView']) {
      this.applyRequestedView(this.requestedView, this.books.length > 0);
    }
  }

  ngOnInit(): void {
    const initialRouteView = this.payrollViewFromRoute(this.route.snapshot.queryParamMap.get('view'));
    if (initialRouteView) {
      this.activeView = initialRouteView;
    }

    this.applyRequestedView(this.requestedView, false);

    this.route.queryParamMap.subscribe(params => {
      if (this.embedded) {
        return;
      }

      const routeView = this.payrollViewFromRoute(params.get('view'));
      if (routeView && routeView !== this.activeView && this.books.length > 0) {
        this.selectView(routeView);
      }
    });

    this.coreApi.getConfig().subscribe({
      next: config => {
        this.books = config.books;
        this.selectedBook = config.defaultBook || 'ABIODEMO';
        this.loadInventory();
        this.loadLookups();
        this.loadValidationRules();
        this.loadActiveView();
        this.loadLegacyMenu();
      },
      error: () => {
        this.statusMessage = 'Could not load books from the API. Is Abio.Api running?';
      }
    });
  }

  private applyRequestedView(value: string | null, reload: boolean): void {
    const requested = this.payrollViewFromRoute(value);
    if (!requested || requested === this.activeView) {
      return;
    }

    this.activeView = requested;
    this.selectedRecord = null;
    this.commandResult = null;

    if (reload) {
      this.loadActiveView();
    }
  }

  private payrollViewFromRoute(value: string | null): PayrollViewKey | null {
    if (!value) {
      return null;
    }

    return this.views.some(view => view.key === value) ? (value as PayrollViewKey) : null;
  }

  selectView(view: PayrollViewKey): void {
    this.activeView = view;
    this.selectedRecord = null;
    this.commandResult = null;
    this.exitPayrollRecordEditMode();
    this.loadActiveView();
  }

  refresh(): void {
    this.loadLookups();
    this.loadActiveView();
  }

  refreshAll(): void {
    this.refresh();
  }

  loadActiveView(): void {
    this.isLoading = true;
    this.commandResult = null;

    if (this.activeView === 'setup') {
      this.api.getSetup(this.selectedBook, this.activeSetup, this.rowLimit).subscribe({
        next: result => {
          this.rows = result.rows;
          this.statusMessage = `${this.setupLabel(this.activeSetup)} loaded from ${result.legacySourceOrMessage}.`;
          this.isLoading = false;
        },
        error: () => this.handleLoadError(`Could not load ${this.setupLabel(this.activeSetup)}.`)
      });
      return;
    }

    this.api.getList(this.activeView, this.selectedBook, this.searchText, this.rowLimit, this.includeHistory).subscribe({
      next: result => {
        this.rows = result.rows;
        this.statusMessage = `${this.viewLabel(this.activeView)} loaded: ${result.rowCount} rows.`;
        this.isLoading = false;
      },
      error: () => this.handleLoadError(`Could not load ${this.viewLabel(this.activeView)}.`)
    });
  }

  selectSetup(setup: PayrollSetupKey): void {
    this.activeSetup = setup;
    this.selectedRecord = null;
    this.commandResult = null;
    this.exitPayrollRecordEditMode();
    this.loadActiveView();
  }

  onCellClicked(event: { data?: PayrollGridRow; colDef?: ColDef }): void {
    if (!event.data || this.activeView === 'setup') {
      return;
    }

    const field = event.colDef?.field ?? '';
    if (!this.isRecordLinkField(field)) {
      return;
    }

    this.openRecord(event.data);
  }

  openRecord(row: PayrollGridRow): void {
    this.commandResult = null;
    this.selectedRecord = null;
    this.selectedRecordTab = 'Details';
    this.exitPayrollRecordEditMode();

    if (this.activeView === 'employees') {
      const employee = Number(row['employee']);
      if (Number.isFinite(employee)) {
        this.loadRecord(this.api.getEmployeeRecord(this.selectedBook, employee));
      }
      return;
    }

    if (this.activeView === 'timesheets') {
      const employee = Number(row['employee']);
      const timesheetItem = Number(row['timesheetItem']);
      const workDate = this.toDateParameter(row['workDate']);
      if (Number.isFinite(employee) && Number.isFinite(timesheetItem) && workDate) {
        this.loadRecord(this.api.getTimesheetRecord(this.selectedBook, employee, workDate, timesheetItem));
      }
      return;
    }

    if (this.activeView === 'field-timesheets') {
      const fieldTimesheetItem = Number(row['fieldTimesheetItem']);
      const workDate = this.toDateParameter(row['workDate']);
      const addUserId = String(row['addUserId'] ?? '');
      if (Number.isFinite(fieldTimesheetItem) && workDate && addUserId) {
        this.loadRecord(this.api.getFieldTimesheetRecord(this.selectedBook, workDate, addUserId, fieldTimesheetItem));
      }
      return;
    }

    if (this.activeView === 'cheques') {
      const chequeNo = Number(row['chequeNo']);
      if (Number.isFinite(chequeNo)) {
        this.loadRecord(this.api.getChequeRecord(this.selectedBook, chequeNo));
      }
    }
  }

  closeRecord(): void {
    this.selectedRecord = null;
    this.commandResult = null;
    this.exitPayrollRecordEditMode();
  }

  @HostListener('document:keydown.escape', ['$event'])
  closeRecordWithEscape(event: KeyboardEvent): void {
    if (!this.selectedRecord) {
      return;
    }

    event.preventDefault();
    this.closeRecord();
  }

  setRecordTab(tab: string): void {
    this.selectedRecordTab = tab;
  }

  runGuardedCommand(commandName: string, payload: PayrollGridRow = this.selectedRecord?.header ?? {}, changedFields: string[] = []): void {
    this.api.runCommand({
      book: this.selectedBook,
      commandName,
      userId: 'SHYMKVIK',
      payload,
      changedFields,
      dryRun: true
    }).subscribe({
      next: result => {
        this.commandResult = result;
        this.statusMessage = result.message;
      },
      error: () => {
        this.statusMessage = 'Could not run the guarded Payroll command.';
      }
    });
  }

  get columnDefs(): ColDef<PayrollGridRow>[] {
    if (this.activeView === 'setup') {
      return this.autoColumns(this.rows);
    }

    if (this.activeView === 'employees') {
      return [
        this.linkColumn('employee', 'Employee', 120),
        { field: 'name', headerName: 'Name', flex: 1, minWidth: 220 },
        { field: 'employmentType', headerName: 'Type', width: 100 },
        { field: 'tradeUnion', headerName: 'Union', width: 110 },
        { field: 'occupation', headerName: 'Occupation', width: 130 },
        { field: 'job', headerName: 'Job', width: 110 },
        { field: 'centre', headerName: 'Centre', width: 110 },
        { field: 'taxProvince', headerName: 'Tax Prov', width: 110 },
        { field: 'wcbClass', headerName: 'WCB', width: 100 },
        { field: 'hireDate', headerName: 'Hire Date', width: 140 },
        { field: 'terminationDate', headerName: 'Terminated', width: 140 },
        { field: 'restrictFlag', headerName: 'Restrict', width: 100 },
        { field: 'fileType', headerName: 'File', width: 90 }
      ];
    }

    if (this.activeView === 'timesheets') {
      return [
        this.linkColumn('employee', 'Employee', 120),
        { field: 'employeeName', headerName: 'Name', flex: 1, minWidth: 200 },
        this.linkColumn('workDate', 'Work Date', 140),
        this.linkColumn('timesheetItem', 'Item', 90),
        { field: 'job', headerName: 'Job', width: 110 },
        { field: 'area', headerName: 'Area', width: 100 },
        { field: 'centre', headerName: 'Centre', width: 110 },
        { field: 'tradeUnion', headerName: 'Union', width: 110 },
        { field: 'occupation', headerName: 'Occupation', width: 130 },
        { field: 'prPeriod', headerName: 'PR Period', width: 120 },
        { field: 'timesheetStatus', headerName: 'Status', width: 100 },
        { field: 'chequeNo', headerName: 'Cheque', width: 110 },
        { field: 'regHour', headerName: 'Reg', type: 'numericColumn', width: 95 },
        { field: 'tahHour', headerName: 'TAH', type: 'numericColumn', width: 95 },
        { field: 'ovrHour', headerName: 'OT', type: 'numericColumn', width: 95 },
        { field: 'total', headerName: 'Total', type: 'numericColumn', width: 120 }
      ];
    }

    if (this.activeView === 'field-timesheets') {
      return [
        this.linkColumn('fieldTimesheetItem', 'Item', 110),
        this.linkColumn('workDate', 'Work Date', 150),
        { field: 'addUserId', headerName: 'Added By', width: 130 },
        { field: 'fileType', headerName: 'File', width: 90 },
        { field: 'addDateTime', headerName: 'Added', width: 180 },
        { field: 'timesheetRows', headerName: 'Timesheets', type: 'numericColumn', width: 130 },
        { field: 'notePreview', headerName: 'Note', flex: 1, minWidth: 280 }
      ];
    }

    return [
      this.linkColumn('chequeNo', 'Cheque', 120),
      this.linkColumn('employee', 'Employee', 120),
      { field: 'employeeName', headerName: 'Name', flex: 1, minWidth: 200 },
      { field: 'prPeriod', headerName: 'PR Period', width: 120 },
      { field: 'chequeStatus', headerName: 'Status', width: 110 },
      { field: 'issueDate', headerName: 'Issue Date', width: 140 },
      { field: 'tradeUnion', headerName: 'Union', width: 110 },
      { field: 'regHour', headerName: 'Reg', type: 'numericColumn', width: 95 },
      { field: 'grossPay', headerName: 'Gross', type: 'numericColumn', width: 120 },
      { field: 'netPay', headerName: 'Net', type: 'numericColumn', width: 120 },
      { field: 'incomeTax', headerName: 'Tax', type: 'numericColumn', width: 120 }
    ];
  }

  get recordTitle(): string {
    if (!this.selectedRecord?.header) {
      return 'Payroll record';
    }

    const header = this.selectedRecord.header;
    if (this.selectedRecord.recordType === 'employee') {
      return `P/R Employee: ${header['employee'] ?? ''}-${header['name'] ?? ''}`;
    }

    if (this.selectedRecord.recordType === 'timesheet') {
      return `P/R Timesheet: ${header['employee'] ?? ''}-${header['workDate'] ?? ''}-${header['timesheetItem'] ?? ''}`;
    }

    if (this.selectedRecord.recordType === 'fieldTimesheet') {
      return `P/R Field Timesheet: ${header['workDate'] ?? ''}-${header['fieldTimesheetItem'] ?? ''}`;
    }

    if (this.selectedRecord.recordType === 'cheque') {
      return `P/R Cheque: ${header['chequeNo'] ?? ''}-${header['employee'] ?? ''}`;
    }

    return `${this.selectedRecord.recordType} record`;
  }

  get activeRecordRows(): PayrollGridRow[] {
    if (!this.selectedRecord) {
      return [];
    }

    const key = this.activeRecordChildKey;
    return key ? this.selectedRecord.children[key] ?? [] : [];
  }

  get activeRecordChildKey(): string | null {
    if (!this.selectedRecord) {
      return null;
    }

    return this.childKeyForTab(this.selectedRecord.recordType, this.selectedRecordTab);
  }

  get activeRecordColumnDefs(): ColDef<PayrollGridRow>[] {
    return this.autoColumns(this.activeRecordRows);
  }

  get activeRecordFields(): PayrollRecordField[] {
    const record = this.selectedRecord;
    const header = this.isPayrollRecordEditMode ? this.payrollRecordEditDraft : record?.header;
    if (!record || !header) {
      return [];
    }

    const fieldNames = this.fieldNamesForRecordTab(record.recordType, this.selectedRecordTab);
    if (fieldNames.length === 0) {
      return this.activeRecordChildKey ? [] : Object.entries(header).slice(0, 18);
    }

    return fieldNames
      .filter(field => Object.prototype.hasOwnProperty.call(header, field))
      .map(field => [field, header[field]]);
  }

  get activeRecordLeftFields(): PayrollRecordField[] {
    return this.activeRecordFields.slice(0, Math.ceil(this.activeRecordFields.length / 2));
  }

  get activeRecordRightFields(): PayrollRecordField[] {
    return this.activeRecordFields.slice(Math.ceil(this.activeRecordFields.length / 2));
  }

  get activeRecordFieldsetTitle(): string {
    return `${this.selectedRecordTab} ${this.selectedRecord?.recordType ?? 'record'} fields`;
  }

  get activeValidationRules(): PayrollValidationRule[] {
    const recordType = this.selectedRecord?.recordType;
    if (!recordType || !this.validationCatalog) {
      return [];
    }

    return this.validationCatalog.recordTypes[recordType] ?? [];
  }

  get activeFrontendValidationErrors(): PayrollValidationError[] {
    const header = this.selectedRecord?.header;
    if (!header) {
      return [];
    }

    return this.activeValidationRules
      .filter(rule => rule.severity === 'error')
      .filter(rule => this.failsFrontendValidation(header, rule))
      .map(rule => ({
        field: rule.field,
        message: rule.message,
        ruleId: rule.ruleId,
        severity: rule.severity
      }));
  }

  get backendOnlyValidationRules(): PayrollValidationRule[] {
    return this.activeValidationRules.filter(rule => rule.severity === 'backend-required');
  }

  get currentCommands(): PayrollCommandDefinition[] {
    const commands = this.inventory?.commands ?? [];
    if (this.activeView === 'employees') {
      return commands.filter(command => command.name.startsWith('employee.'));
    }

    if (this.activeView === 'timesheets') {
      return commands.filter(command => command.name.startsWith('timesheet.'));
    }

    if (this.activeView === 'field-timesheets') {
      return commands.filter(command => command.name.startsWith('fieldTimesheet.'));
    }

    if (this.activeView === 'cheques') {
      return commands.filter(command => command.name.startsWith('cheque.'));
    }

    return commands.filter(command => command.name.startsWith('payroll.'));
  }

  get hasPayrollRecordEditChanges(): boolean {
    return this.payrollRecordChangedFields().length > 0;
  }

  isPayrollChangeCommand(commandName: string): boolean {
    return commandName.endsWith('.change');
  }

  payrollCommandLabel(command: PayrollCommandDefinition): string {
    return this.isPayrollChangeCommand(command.name) ? 'Edit' : command.displayName;
  }

  handlePayrollCommandPointerDown(commandName: string, event: PointerEvent): void {
    if (!this.isPayrollChangeCommand(commandName) || this.isPayrollRecordEditMode) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    this.enterPayrollRecordEditMode();
  }

  handlePayrollCommand(commandName: string): void {
    if (this.isPayrollChangeCommand(commandName)) {
      this.enterPayrollRecordEditMode();
      return;
    }

    this.runGuardedCommand(commandName);
  }

  handlePayrollEditActionPointerDown(action: 'save' | 'cancel', event: PointerEvent): void {
    if (!this.isPayrollRecordEditMode) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    if (action === 'save') {
      if (this.hasPayrollRecordEditChanges) {
        this.savePayrollRecordEdit();
      }
      return;
    }

    this.cancelPayrollRecordEdit();
  }

  isPayrollRecordFieldEditable(field: string): boolean {
    if (!this.isPayrollRecordEditMode || this.activeRecordChildKey) {
      return false;
    }

    return ![
      'book',
      'employee',
      'workDate',
      'timesheetItem',
      'fieldTimesheetItem',
      'chequeNo',
      'addUserId',
      'addDatetime',
      'addDateTime',
      'lastPayDate',
      'fileType'
    ].includes(field);
  }

  updatePayrollRecordEditField(field: string, event: Event): void {
    if (!this.isPayrollRecordFieldEditable(field)) {
      return;
    }

    const target = event.target;
    this.payrollRecordEditDraft = {
      ...this.payrollRecordEditDraft,
      [field]: target instanceof HTMLInputElement ? target.value : ''
    };
  }

  savePayrollRecordEdit(): void {
    const changeCommand = this.currentCommands.find(command => this.isPayrollChangeCommand(command.name));
    const changedFields = this.payrollRecordChangedFields();
    if (!changeCommand || changedFields.length === 0) {
      return;
    }

    this.runGuardedCommand(changeCommand.name, this.payrollRecordEditDraft, changedFields);
  }

  cancelPayrollRecordEdit(): void {
    this.payrollRecordEditDraft = { ...this.payrollRecordEditOriginal };
    this.exitPayrollRecordEditMode();
    this.statusMessage = `${this.selectedRecord?.recordType ?? 'Payroll'} edit cancelled. Original values restored.`;
  }

  lookupCount(): number {
    return this.lookupResult ? Object.keys(this.lookupResult.fields).length : 0;
  }

  viewLabel(view: PayrollViewKey): string {
    return this.views.find(item => item.key === view)?.label ?? view;
  }

  setupLabel(setup: PayrollSetupKey): string {
    return this.setupViews.find(item => item.key === setup)?.label ?? setup;
  }

  formatFieldLabel(field: string): string {
    return field.replace(/([A-Z])/g, ' $1').replace(/^./, value => value.toUpperCase());
  }

  isRequiredField(field: string): boolean {
    return this.activeValidationRules.some(rule =>
      rule.field.toLowerCase() === field.toLowerCase()
      && rule.ruleType === 'required'
      && rule.severity === 'error');
  }

  validationHintForField(field: string): string {
    return this.activeValidationRules
      .filter(rule => rule.field.toLowerCase() === field.toLowerCase())
      .map(rule => rule.message)
      .join(' ');
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

  trackMenuNode(_: number, node: CoreMenuNode): string {
    return node.key;
  }

  selectLegacyNode(node: CoreMenuNode): void {
    this.selectedMenuNode = node;
    if (node.children.length > 0) {
      this.toggleLegacyNode(node);
      return;
    }

    if (!this.isPayrollMenuNode(node)) {
      this.router.navigate(['/']);
      return;
    }

    const payrollView = this.payrollViewForMenuNode(node);
    if (payrollView) {
      this.activeView = payrollView;
      this.selectedRecord = null;
      this.commandResult = null;
      this.loadActiveView();
      return;
    }

    this.menuStatusMessage = `${node.label} is in Payroll but is not migrated yet.`;
  }

  updateMenuSearch(value: string): void {
    this.menuSearchText = value;
  }

  clearMenuSearch(): void {
    this.menuSearchText = '';
  }

  isLegacyNodeExpanded(node: CoreMenuNode): boolean {
    return this.expandedMenuKeys.has(node.key);
  }

  isLegacyNodeActive(node: CoreMenuNode): boolean {
    return this.selectedMenuNode?.key === node.key;
  }

  menuVisibleShortcut(node: CoreMenuNode): string {
    return node.menu3 || node.menu2 || node.menu1 || ' ';
  }

  menuIconClass(node: CoreMenuNode): string {
    const label = `${node.label} ${node.description}`.toLowerCase();
    const program = node.program.toUpperCase();
    if (node.itemType === 'report') {
      return 'icon-report';
    }
    if (program.startsWith('PR') || label.includes('payroll')) {
      return label.includes('employee') ? 'icon-employee' : 'icon-payroll';
    }
    if (label.includes('payable')) {
      return 'icon-payables';
    }
    if (label.includes('receivable')) {
      return 'icon-receivables';
    }
    if (label.includes('job')) {
      return 'icon-job';
    }
    if (label.includes('equipment')) {
      return 'icon-equipment';
    }
    if (label.includes('inventory')) {
      return 'icon-inventory';
    }
    if (label.includes('administration')) {
      return 'icon-admin';
    }
    if (node.children.length > 0) {
      return 'icon-folder';
    }
    return 'icon-window';
  }

  private loadInventory(): void {
    this.api.getInventory().subscribe({
      next: inventory => {
        this.inventory = inventory;
      },
      error: () => {
        this.statusMessage = 'Could not load Payroll inventory.';
      }
    });
  }

  private loadLookups(): void {
    this.api.getLookups(this.selectedBook).subscribe({
      next: lookups => {
        this.lookupResult = lookups;
      }
    });
  }

  private loadValidationRules(): void {
    this.api.getValidationRules().subscribe({
      next: catalog => {
        this.validationCatalog = catalog;
      },
      error: () => {
        this.statusMessage = 'Could not load Payroll validation rules.';
      }
    });
  }

  private loadLegacyMenu(): void {
    this.coreApi.getMenu().subscribe({
      next: menu => {
        this.legacyMenuModules = menu.modules;
        this.expandedMenuKeys = new Set(menu.modules.filter(module => module.menu1.toLowerCase() === 'c').map(module => module.key));
        this.menuStatusMessage = `${menu.menuRowCount} menu rows and ${menu.reportRowCount} reports loaded.`;
      },
      error: () => {
        this.menuStatusMessage = 'Could not load legacy menu.';
      }
    });
  }

  private loadRecord(request: ReturnType<PayrollApiService['getEmployeeRecord']>): void {
    request.subscribe({
      next: record => {
        this.selectedRecord = record;
        this.selectedRecordTab = record.tabs[0] ?? 'Details';
        this.statusMessage = `${record.recordType} record loaded.`;
        this.exitPayrollRecordEditMode();
      },
      error: () => {
        this.statusMessage = 'Could not load the selected Payroll record.';
      }
    });
  }

  private handleLoadError(message: string): void {
    this.rows = [];
    this.isLoading = false;
    this.statusMessage = message;
  }

  private enterPayrollRecordEditMode(): void {
    const header = this.selectedRecord?.header;
    if (!this.selectedRecord || !header) {
      return;
    }

    this.commandResult = null;
    this.payrollRecordEditOriginal = { ...header };
    this.payrollRecordEditDraft = { ...header };
    this.isPayrollRecordEditMode = true;
    this.statusMessage = `${this.selectedRecord.recordType} edit mode started. Save will run through the guarded Payroll program-layer command.`;
    this.focusFirstPayrollEditableField();
  }

  private exitPayrollRecordEditMode(): void {
    this.isPayrollRecordEditMode = false;
    this.payrollRecordEditOriginal = {};
    this.payrollRecordEditDraft = {};
  }

  private payrollRecordChangedFields(): string[] {
    return Object.keys(this.payrollRecordEditDraft)
      .filter(field => this.valueAsString(this.payrollRecordEditDraft[field]) !== this.valueAsString(this.payrollRecordEditOriginal[field]));
  }

  private focusFirstPayrollEditableField(): void {
    window.setTimeout(() => {
      const field = Array.from(
        this.elementRef.nativeElement.querySelectorAll<HTMLElement>(
          '.legacy-record-body input.is-editable, .legacy-record-body textarea.is-editable, .legacy-record-body select.is-editable'
        )
      ).find(item => this.isFocusablePayrollRecordField(item));

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

  private isFocusablePayrollRecordField(field: HTMLElement): boolean {
    if (field.hasAttribute('disabled') || field.getAttribute('tabindex') === '-1') {
      return false;
    }

    if (field instanceof HTMLInputElement && field.type === 'hidden') {
      return false;
    }

    const style = window.getComputedStyle(field);
    return style.display !== 'none' && style.visibility !== 'hidden' && field.offsetParent !== null;
  }

  private toggleLegacyNode(node: CoreMenuNode): void {
    if (this.expandedMenuKeys.has(node.key)) {
      this.expandedMenuKeys.delete(node.key);
    } else {
      this.expandedMenuKeys.add(node.key);
    }
  }

  private isPayrollMenuNode(node: CoreMenuNode): boolean {
    return node.menu1.toLowerCase() === 'c'
      || node.program.toUpperCase().startsWith('PR')
      || node.windowName.toLowerCase().startsWith('w_pr_');
  }

  private payrollViewForMenuNode(node: CoreMenuNode): PayrollViewKey | null {
    const program = node.program.toUpperCase();
    const windowName = node.windowName.toLowerCase();
    const label = `${node.label} ${node.description}`.toLowerCase();

    if (program === 'PREENT' || windowName.includes('w_pr_employee') || label.includes('employee')) {
      return 'employees';
    }
    if (program === 'PRTENT' || windowName.includes('w_pr_timesheet') || label.includes('timesheet entry')) {
      return 'timesheets';
    }
    if (program === 'PRFENT' || windowName.includes('w_pr_field_timesheet') || label.includes('field timesheet')) {
      return 'field-timesheets';
    }
    if (program.startsWith('PRC') || program === 'PRCHEQ' || windowName.includes('w_pr_pr_cheque') || label.includes('cheque')) {
      return 'cheques';
    }
    if (program === 'PRSETU' || label.includes('setup') || windowName.startsWith('w_st_') || windowName.startsWith('w_tb_')) {
      return 'setup';
    }

    return null;
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
      return this.menuShortcutPath(node).includes(query.slice(1).replace(/\s+/g, ''));
    }

    return [
      node.label,
      node.description,
      node.program,
      node.windowName,
      this.menuShortcutPath(node)
    ].join(' ').toLowerCase().includes(query);
  }

  private menuShortcutPath(node: CoreMenuNode): string {
    return [node.menu1, node.menu2, node.menu3]
      .filter(value => value.length > 0)
      .join('')
      .toLowerCase();
  }

  private isRecordLinkField(field: string): boolean {
    return ['employee', 'workDate', 'timesheetItem', 'fieldTimesheetItem', 'chequeNo'].includes(field);
  }

  private linkColumn(field: string, headerName: string, width: number): ColDef<PayrollGridRow> {
    return { field, headerName, width, cellRenderer: this.idLinkRenderer, cellClass: 'payroll-link-cell-wrap' };
  }

  private autoColumns(rows: PayrollGridRow[]): ColDef<PayrollGridRow>[] {
    const first = rows[0];
    if (!first) {
      return [];
    }

    return Object.keys(first).slice(0, 24).map(field => ({
      field,
      headerName: this.formatFieldLabel(field),
      minWidth: field.length > 18 ? 190 : 130,
      flex: ['description', 'note', 'notePreview', 'name'].includes(field) ? 1 : undefined
    }));
  }

  private childKeyForTab(recordType: string, tab: string): string | null {
    const normalized = tab.toLowerCase();
    if (recordType === 'employee' && normalized.includes('cheque')) {
      return 'purchases';
    }
    if (normalized.includes('premium')) {
      return 'premiums';
    }
    if (normalized.includes('earning')) {
      return 'earnings';
    }
    if (normalized.includes('wcb')) {
      return 'wcb';
    }
    if (normalized.includes('union')) {
      return 'tradeUnions';
    }
    if (normalized.includes('occupation')) {
      return 'occupations';
    }
    if (normalized.includes('document')) {
      return 'timesheets';
    }
    return null;
  }

  private fieldNamesForRecordTab(recordType: string, tab: string): string[] {
    const normalized = tab.toLowerCase();

    if (recordType === 'employee') {
      if (normalized.includes('cheque')) {
        return [
          'eftInstitution',
          'eftBranch',
          'eftAccount',
          'eftUsRouting',
          'duesPerMonth',
          'lastMonthOfDues',
          'lastDailyDuesDate',
          'dailyDuesFlag',
          'permitFeeFlag',
          'adminFeeFlag',
          'adminFee',
          'garnisheeFlag',
          'miscDeductPerCk',
          'charityPerCk'
        ];
      }

      if (normalized.includes('incentive') || normalized.includes('accrual')) {
        return [
          'vacationPercent',
          'statutoryPercent',
          'employerRrspPercent',
          'staffSafetyPercent',
          'smtcPercent',
          'incentivePercent',
          'trainingPercent',
          'safetyToRrspFlag',
          'otherIncentiveToRrspFlag',
          'employeeRrspPerCk',
          'taxableBenefitPerCk',
          'nextTravelDueDate',
          'nextTravelAmt',
          'nextTurnaroundDueDate',
          'turnaroundCycleDays',
          'nextTurnaroundAmt'
        ];
      }

      if (normalized.includes('detail')) {
        return [
          'book',
          'employee',
          'name',
          'employmentType',
          'tradeUnion',
          'occupation',
          'shift',
          'shiftCycle',
          'shiftPatternType',
          'shiftStartDate',
          'job',
          'area',
          'centre',
          'supervisor',
          'localHireFlag',
          'taxProvince',
          'wcbClass',
          'federalZoneDeduction',
          'federalTd1Claim',
          'provincialTd1Claim',
          'addIncomeTaxPerCk',
          'cppExemptFlag',
          'eiExemptFlag',
          'incomeTaxExemptFlag',
          'hireDate',
          'lastPayDate',
          'terminationDate',
          'loaChangeDate',
          'roeReasonCode',
          'message',
          'fileType'
        ];
      }
    }

    if (recordType === 'timesheet' && normalized.includes('detail')) {
      return [
        'book',
        'employee',
        'workDate',
        'timesheetItem',
        'job',
        'area',
        'centre',
        'equipment',
        'glAccount',
        'tradeUnion',
        'occupation',
        'wcbClass',
        'gstRule',
        'shift',
        'memo',
        'prYyyymm',
        'timesheetStatus',
        'transactFlag',
        'regHour',
        'tahHour',
        'ovrHour',
        'travelHour',
        'loaHour',
        'mileageHour',
        'regRate',
        'tahRate',
        'ovrRate',
        'travelRate',
        'loaRate',
        'mileageRate',
        'baseRate',
        'regEarn',
        'tahEarn',
        'ovrEarn',
        'travelEarn',
        'loa',
        'mileage',
        'turnaround',
        'siteAllowance',
        'taxi',
        'meal',
        'retro',
        'otherTaxablePay',
        'retentionEarn',
        'fringe',
        'gstAmount',
        'total',
        'chequeNo',
        'fileType'
      ];
    }

    if (recordType === 'fieldTimesheet') {
      if (normalized.includes('document')) {
        return [
          'book',
          'workDate',
          'fieldTimesheetItem',
          'addUserId',
          'addDatetime',
          'fileType',
          'note'
        ];
      }

      if (normalized.includes('detail')) {
        return [
          'book',
          'workDate',
          'fieldTimesheetItem',
          'fileType',
          'addUserId',
          'addDatetime',
          'note'
        ];
      }
    }

    if (recordType === 'cheque') {
      if (normalized.includes('gross') || normalized.includes('net')) {
        return [
          'book',
          'chequeNo',
          'employee',
          'chequeStatus',
          'formNo',
          'prYyyymm',
          'payPeriodStartDate',
          'issueDate',
          'reconcileDate',
          'eftDate',
          'eftBatch',
          'transactFlag',
          'tradeUnion',
          'taxProvince',
          'employmentType',
          'restrictFlag',
          'fileType',
          'grossPay',
          'netPay',
          'cppContribution',
          'cpp2Contribution',
          'eiPremium',
          'qpipPremium',
          'incomeTax',
          'incomeTaxProv',
          'incomeTaxFed',
          'unionDues',
          'insurance',
          'miscDeduction',
          'charity',
          'employeeRrsp',
          'employeePension',
          'taxableBenefit',
          'memo'
        ];
      }

      if (normalized.includes('earn') || normalized.includes('loss')) {
        return [
          'regHour',
          'tahHour',
          'ovrHour',
          'travelHour',
          'regEarn',
          'tahEarn',
          'ovrEarn',
          'travelEarn',
          'taxableLoa',
          'nontaxableLoa',
          'taxableMileage',
          'nontaxableMileage',
          'turnaround',
          'taxableSiteAllow',
          'nontaxableSiteAllow',
          'taxi',
          'meal',
          'retro',
          'otherTaxablePay',
          'vacationEarn',
          'vacationPaid',
          'vacationOwed',
          'vacationLost',
          'statutoryEarn',
          'statutoryPaid',
          'statutoryOwed',
          'statutoryLost',
          'personalSafetyEarn',
          'personalSafetyPaid',
          'personalSafetyOwed',
          'personalSafetyLost',
          'groupSafetyEarn',
          'groupSafetyPaid',
          'groupSafetyOwed',
          'groupSafetyLost',
          'staffSafetyEarn',
          'staffSafetyPaid',
          'staffSafetyOwed',
          'staffSafetyLost',
          'retentionEarn',
          'retentionPaid',
          'retentionOwed',
          'retentionLost',
          'incentiveEarn',
          'incentivePaid',
          'incentiveOwed',
          'incentiveLost',
          'productionBonusEarn',
          'productionBonusPaid',
          'productionBonusOwed',
          'productionBonusLost'
        ];
      }
    }

    return [];
  }

  private failsFrontendValidation(row: PayrollGridRow, rule: PayrollValidationRule): boolean {
    const value = this.valueAsString(row[rule.field]);
    if (rule.ruleType === 'required') {
      return value.length === 0;
    }

    if (rule.ruleType === 'enum' && value.length > 0) {
      return !rule.allowedValues.some(option => option.toLowerCase() === value.toLowerCase());
    }

    return false;
  }

  private valueAsString(value: PayrollGridRow[string]): string {
    if (value === null || value === undefined) {
      return '';
    }

    return String(value).trim();
  }

  private toDateParameter(value: PayrollGridRow[string]): string {
    if (!value) {
      return '';
    }

    const date = new Date(String(value));
    if (Number.isNaN(date.getTime())) {
      return String(value);
    }

    return date.toISOString();
  }
}
