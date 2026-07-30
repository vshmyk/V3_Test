import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import {
  PayrollCommandRequest,
  PayrollCommandResult,
  PayrollListKey,
  PayrollListResult,
  PayrollLookupResult,
  PayrollModuleInventory,
  PayrollRecordResult,
  PayrollSetupKey,
  PayrollSetupResult,
  PayrollValidationCatalog
} from './payroll.models';

@Injectable({ providedIn: 'root' })
export class PayrollApiService {
  private readonly baseUrl = 'http://localhost:5239/api/payroll';

  constructor(private readonly http: HttpClient) {}

  getInventory() {
    return this.http.get<PayrollModuleInventory>(`${this.baseUrl}/inventory`);
  }

  getList(list: PayrollListKey, book: string, search = '', limit = 250, includeHistory = false) {
    return this.http.get<PayrollListResult>(`${this.baseUrl}/${list}`, {
      params: this.listParams(book, search, limit, includeHistory)
    });
  }

  getEmployeeRecord(book: string, employee: number) {
    return this.http.get<PayrollRecordResult>(`${this.baseUrl}/employee-record`, {
      params: this.bookParams(book).set('employee', employee)
    });
  }

  getTimesheetRecord(book: string, employee: number, workDate: string, timesheetItem: number) {
    return this.http.get<PayrollRecordResult>(`${this.baseUrl}/timesheet-record`, {
      params: this.bookParams(book)
        .set('employee', employee)
        .set('workDate', workDate)
        .set('timesheetItem', timesheetItem)
    });
  }

  getFieldTimesheetRecord(book: string, workDate: string, addUserId: string, fieldTimesheetItem: number) {
    return this.http.get<PayrollRecordResult>(`${this.baseUrl}/field-timesheet-record`, {
      params: this.bookParams(book)
        .set('workDate', workDate)
        .set('addUserId', addUserId)
        .set('fieldTimesheetItem', fieldTimesheetItem)
    });
  }

  getChequeRecord(book: string, chequeNo: number) {
    return this.http.get<PayrollRecordResult>(`${this.baseUrl}/cheque-record`, {
      params: this.bookParams(book).set('chequeNo', chequeNo)
    });
  }

  getSetup(book: string, setupArea: PayrollSetupKey, limit = 250) {
    return this.http.get<PayrollSetupResult>(`${this.baseUrl}/setup`, {
      params: this.bookParams(book).set('setupArea', setupArea).set('limit', limit)
    });
  }

  getLookups(book: string) {
    return this.http.get<PayrollLookupResult>(`${this.baseUrl}/lookups`, {
      params: this.bookParams(book)
    });
  }

  getValidationRules() {
    return this.http.get<PayrollValidationCatalog>(`${this.baseUrl}/validation-rules`);
  }

  runCommand(request: PayrollCommandRequest) {
    return this.http.post<PayrollCommandResult>(`${this.baseUrl}/commands`, request);
  }

  private bookParams(book: string) {
    return new HttpParams().set('book', book);
  }

  private listParams(book: string, search: string, limit: number, includeHistory: boolean) {
    return this.bookParams(book)
      .set('search', search)
      .set('limit', limit)
      .set('includeHistory', includeHistory);
  }
}
