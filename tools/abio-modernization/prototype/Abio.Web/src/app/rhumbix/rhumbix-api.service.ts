import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import {
  GridQueryResponse,
  RhumbixConfigResponse,
  RhumbixImportErrorRow,
  RhumbixImportTimesheetsRequest,
  RhumbixImportTimesheetsResponse,
  RhumbixPendingCountResponse,
  RhumbixSyncHistoryRow,
  RhumbixSyncProjectsRequest,
  RhumbixSyncProjectsResponse
} from './rhumbix.models';

@Injectable({ providedIn: 'root' })
export class RhumbixApiService {
  private readonly baseUrl = 'http://localhost:5239/api/rhumbix';

  constructor(private readonly http: HttpClient) {}

  getConfig() {
    return this.http.get<RhumbixConfigResponse>(`${this.baseUrl}/config`);
  }

  getPendingCount(book: string) {
    const params = new HttpParams().set('book', book);
    return this.http.get<RhumbixPendingCountResponse>(`${this.baseUrl}/pending-count`, { params });
  }

  getImportErrors() {
    return this.http.get<GridQueryResponse<RhumbixImportErrorRow>>(`${this.baseUrl}/import-errors`);
  }

  getSyncHistory(book: string) {
    const params = new HttpParams().set('book', book);
    return this.http.get<GridQueryResponse<RhumbixSyncHistoryRow>>(`${this.baseUrl}/sync-history`, { params });
  }

  importTimesheets(request: RhumbixImportTimesheetsRequest) {
    return this.http.post<RhumbixImportTimesheetsResponse>(`${this.baseUrl}/import-timesheets`, request);
  }

  syncProjects(request: RhumbixSyncProjectsRequest) {
    return this.http.post<RhumbixSyncProjectsResponse>(`${this.baseUrl}/sync-projects`, request);
  }
}
