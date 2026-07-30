import { CommonModule } from '@angular/common';
import { Component, OnInit, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { AgGridAngular } from 'ag-grid-angular';
import { AllCommunityModule, ColDef, ModuleRegistry } from 'ag-grid-community';
import { RhumbixApiService } from './rhumbix-api.service';
import {
  RhumbixImportErrorRow,
  RhumbixImportTimesheetsResponse,
  RhumbixSyncHistoryRow
} from './rhumbix.models';

ModuleRegistry.registerModules([AllCommunityModule]);

@Component({
  selector: 'app-rhumbix-integration',
  imports: [CommonModule, ReactiveFormsModule, AgGridAngular],
  templateUrl: './rhumbix-integration.component.html',
  styleUrl: './rhumbix-integration.component.scss'
})
export class RhumbixIntegrationComponent implements OnInit {
  private readonly api = inject(RhumbixApiService);
  private readonly fb = inject(FormBuilder);

  readonly form = this.fb.nonNullable.group({
    book: ['', Validators.required],
    startDate: ['', Validators.required],
    endDate: ['', Validators.required],
    prPeriod: [0, [Validators.required, Validators.min(190001), Validators.max(999912)]],
    forceFullSync: [false]
  });

  readonly defaultColDef: ColDef = {
    sortable: true,
    filter: true,
    resizable: true
  };

  readonly errorColumnDefs: ColDef<RhumbixImportErrorRow>[] = [
    { field: 'errorId', headerName: 'Error #', type: 'numericColumn', width: 110 },
    { field: 'employeeId', headerName: 'Employee', width: 130 },
    { field: 'shiftDate', headerName: 'Date', width: 130 },
    { field: 'rhumbixProject', headerName: 'Project', width: 140 },
    { field: 'rhumbixCostCode', headerName: 'Cost Code', width: 140 },
    { field: 'errorType', headerName: 'Error Type', width: 160 },
    { field: 'errorMessage', headerName: 'Error Message', flex: 1, minWidth: 280, wrapText: true, autoHeight: true },
    { field: 'errorDateTime', headerName: 'Time', width: 190 }
  ];

  readonly syncColumnDefs: ColDef<RhumbixSyncHistoryRow>[] = [
    { field: 'syncDateTime', headerName: 'Date/Time', width: 190 },
    { field: 'syncType', headerName: 'Type', width: 130 },
    { field: 'recordsAttempted', headerName: 'Attempted', type: 'numericColumn', width: 130 },
    { field: 'recordsCreated', headerName: 'Created', type: 'numericColumn', width: 120 },
    { field: 'recordsUpdated', headerName: 'Updated', type: 'numericColumn', width: 120 },
    { field: 'recordsFailed', headerName: 'Failed', type: 'numericColumn', width: 110 },
    { field: 'statusDisplay', headerName: 'Status', width: 130, cellClass: params => params.data?.recordsFailed ? 'status-failed' : 'status-success' }
  ];

  allowedBooks: string[] = [];
  pendingProjectCount = 0;
  importErrors: RhumbixImportErrorRow[] = [];
  syncHistory: RhumbixSyncHistoryRow[] = [];
  lastImportResult: RhumbixImportTimesheetsResponse | null = null;
  activeTab: 'errors' | 'history' = 'history';
  isLoading = false;
  statusMessage = 'Loading Rhumbix configuration...';

  ngOnInit(): void {
    this.api.getConfig().subscribe({
      next: config => {
        this.allowedBooks = config.allowedBooks;
        this.form.patchValue({
          book: config.defaultBook,
          startDate: config.defaultStartDate,
          endDate: config.defaultEndDate,
          prPeriod: config.currentPrPeriod
        });
        this.refreshReadModels();
      },
      error: () => {
        this.statusMessage = 'API is not reachable. Start Abio.Api on http://localhost:5239.';
      }
    });
  }

  setToday(): void {
    const today = this.toIsoDate(new Date());
    this.form.patchValue({ startDate: today, endDate: today });
  }

  setThisWeek(): void {
    const monday = this.getMonday(new Date());
    const friday = new Date(monday);
    friday.setDate(monday.getDate() + 4);
    this.form.patchValue({ startDate: this.toIsoDate(monday), endDate: this.toIsoDate(friday) });
  }

  setLastWeek(): void {
    const monday = this.getMonday(new Date());
    monday.setDate(monday.getDate() - 7);
    const friday = new Date(monday);
    friday.setDate(monday.getDate() + 4);
    this.form.patchValue({ startDate: this.toIsoDate(monday), endDate: this.toIsoDate(friday) });
  }

  refreshReadModels(): void {
    const book = this.form.controls.book.value;
    if (!book) {
      return;
    }

    this.api.getPendingCount(book).subscribe(result => {
      this.pendingProjectCount = result.pendingProjectCount;
    });

    this.api.getImportErrors().subscribe(result => {
      this.importErrors = result.rows;
    });

    this.api.getSyncHistory(book).subscribe(result => {
      this.syncHistory = result.rows;
      this.statusMessage = 'Ready';
    });
  }

  importTimesheets(): void {
    if (this.form.invalid || !this.dateRangeIsValid()) {
      this.form.markAllAsTouched();
      this.statusMessage = 'Please correct the import filters.';
      return;
    }

    this.isLoading = true;
    this.statusMessage = 'Importing timesheets...';
    const value = this.form.getRawValue();

    this.api.importTimesheets({
      book: value.book,
      startDate: value.startDate,
      endDate: value.endDate,
      prPeriod: value.prPeriod
    }).subscribe({
      next: result => {
        this.lastImportResult = result;
        this.statusMessage = result.message;
        this.activeTab = result.errorCount > 0 ? 'errors' : 'history';
        this.refreshReadModels();
        this.isLoading = false;
      },
      error: () => {
        this.statusMessage = 'Import failed. Check API logs for details.';
        this.isLoading = false;
      }
    });
  }

  syncProjects(): void {
    const book = this.form.controls.book.value;
    if (!book) {
      this.statusMessage = 'Book is required before sync.';
      return;
    }

    this.isLoading = true;
    this.statusMessage = 'Syncing projects...';
    this.api.syncProjects({ book, forceFullSync: this.form.controls.forceFullSync.value }).subscribe({
      next: result => {
        this.statusMessage = result.message;
        this.activeTab = 'history';
        this.refreshReadModels();
        this.isLoading = false;
      },
      error: () => {
        this.statusMessage = 'Project sync failed. Check API logs for details.';
        this.isLoading = false;
      }
    });
  }

  dateRangeIsValid(): boolean {
    return this.form.controls.endDate.value >= this.form.controls.startDate.value;
  }

  private getMonday(date: Date): Date {
    const result = new Date(date);
    const day = result.getDay();
    const diff = day === 0 ? -6 : 1 - day;
    result.setDate(result.getDate() + diff);
    return result;
  }

  private toIsoDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
