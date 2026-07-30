import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import {
  CoreConfigResponse,
  CoreDataset,
  CoreGridRow,
  CoreJobDetailDataset,
  CoreJobReportResponse,
  CoreJobRecordTab,
  CoreLookupResponse,
  CoreJobOverview,
  CoreMenuResponse,
  CoreSummaryResponse,
  GridQueryResponse,
  JobRecordSaveCommandRequest,
  JobRecordSaveCommandResponse
} from './core.models';

@Injectable({ providedIn: 'root' })
export class CoreApiService {
  private readonly baseUrl = 'http://localhost:5239/api/core';

  constructor(private readonly http: HttpClient) {}

  getConfig() {
    return this.http.get<CoreConfigResponse>(`${this.baseUrl}/config`);
  }

  getSummary(book: string) {
    return this.http.get<CoreSummaryResponse>(`${this.baseUrl}/summary`, { params: this.bookParams(book) });
  }

  getMenu(userId = 'SHYMKVIK') {
    return this.http.get<CoreMenuResponse>(`${this.baseUrl}/menu`, { params: new HttpParams().set('userId', userId) });
  }

  getDataset(dataset: CoreDataset, book: string) {
    return this.http.get<GridQueryResponse<CoreGridRow>>(`${this.baseUrl}/${dataset}`, { params: this.bookParams(book) });
  }

  getJobOverview(book: string, job: string) {
    return this.http.get<CoreJobOverview>(`${this.baseUrl}/job-overview`, { params: this.jobParams(book, job) });
  }

  getJobRecord(book: string, job: string) {
    return this.http.get<CoreGridRow>(`${this.baseUrl}/job-record`, { params: this.jobParams(book, job) });
  }

  getJobLookups(book: string, job: string) {
    return this.http.get<CoreLookupResponse>(`${this.baseUrl}/job-lookups`, { params: this.jobParams(book, job) });
  }

  getJobReportLookups(book: string) {
    return this.http.get<CoreLookupResponse>(`${this.baseUrl}/job-report-lookups`, { params: this.bookParams(book) });
  }

  saveJobRecord(command: JobRecordSaveCommandRequest) {
    return this.http.put<JobRecordSaveCommandResponse>(`${this.baseUrl}/job-record`, command);
  }

  getJobDataset(dataset: CoreJobDetailDataset, book: string, job: string) {
    return this.http.get<GridQueryResponse<CoreGridRow>>(`${this.baseUrl}/job-${dataset}`, {
      params: this.jobParams(book, job)
    });
  }

  getJobRecordTab(tab: Exclude<CoreJobRecordTab, 'details' | 'financial'>, book: string, job: string) {
    return this.http.get<GridQueryResponse<CoreGridRow>>(`${this.baseUrl}/job-${tab}`, {
      params: this.jobParams(book, job)
    });
  }

  getJobReport(book: string, report: string, label: string, datawindowName: string, filters: Record<string, string> = {}) {
    let params = this.bookParams(book)
      .set('report', report)
      .set('label', label)
      .set('datawindowName', datawindowName);
    for (const [key, value] of Object.entries(filters)) {
      const normalizedValue = String(value ?? '').trim();
      if (normalizedValue) {
        params = params.set(key, normalizedValue);
      }
    }

    return this.http.get<CoreJobReportResponse>(`${this.baseUrl}/job-report`, {
      params
    });
  }

  private bookParams(book: string) {
    return new HttpParams().set('book', book);
  }

  private jobParams(book: string, job: string) {
    return this.bookParams(book).set('job', job);
  }
}
