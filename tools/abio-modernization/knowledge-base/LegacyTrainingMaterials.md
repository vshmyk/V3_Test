# Legacy Training Materials Index

Generated from dbo.abio_menu and dbo.program_report in ABIO_DEMO.

This index is especially useful because it connects legacy menu programs, shortcuts, windows, help URLs, report DataWindows, and report-level training text. Use it as a practical knowledge source for Abio NG navigation, contextual help, and future AI assistant grounding.

Do not treat this as authoritative for posting, validation, payroll calculation, or save behavior. Those still come from migrated PowerBuilder and SQL logic.

## Module Summary

| Module | Menu Items | With Help URL | With Microhelp | Report Training Records |
| --- | ---: | ---: | ---: | ---: |
| Accounts Payable | 32 | 30 | 19 | 54 |
| Accounts Receivable | 34 | 33 | 25 | 36 |
| Administration | 14 | 14 | 5 | 15 |
| Equipment | 20 | 20 | 9 | 29 |
| General Ledger | 21 | 21 | 14 | 26 |
| Global | 3 | 3 | 1 | 0 |
| Human Resources | 9 | 9 | 5 | 4 |
| Inventory | 15 | 8 | 0 | 4 |
| Job Costing | 31 | 31 | 18 | 50 |
| Payroll | 31 | 29 | 25 | 61 |
| Project Management | 13 | 13 | 0 | 4 |
| Shared Reports | 19 | 18 | 8 | 71 |

## Course And Lesson Links

| Module | Help URL | Menu Items |
| --- | --- | ---: |
| Accounts Payable | http://abiosystems.ca/courses/purchasing-with-abio/ | 27 |
| Accounts Payable | https://abiosystems.ca/lessons/recording-invoices-for-purchases/ | 1 |
| Accounts Payable | https://abiosystems.ca/training | 2 |
| Accounts Receivable | http://abiosystems.ca/courses/bidding-on-new-work/ | 1 |
| Accounts Receivable | http://abiosystems.ca/courses/receiving-payments/ | 32 |
| Administration | http://abiosystems.ca/courses/users-and-security-for-abio/ | 13 |
| Administration | https://abiosystems.ca/training | 1 |
| Equipment | http://abiosystems.ca/courses/equipment-management-with-abio/ | 20 |
| General Ledger | http://abiosystems.ca/courses/corporate-oversight-with-abio/ | 21 |
| Global | http://abiosystems.ca/training/ | 3 |
| Human Resources | http://abiosystems.ca/courses/human-resources-with-abio/ | 9 |
| Inventory | https://abiosystems.ca/training | 8 |
| Job Costing | http://abiosystems.ca/courses/job-costing-with-abio/ | 27 |
| Job Costing | https://abiosystems.ca/lessons/areas/ | 1 |
| Job Costing | https://abiosystems.ca/lessons/cost_centres/ | 1 |
| Job Costing | https://abiosystems.ca/training | 2 |
| Payroll | http://abiosystems.ca/courses/collective-agreements-with-abio/ | 14 |
| Payroll | http://abiosystems.ca/courses/payroll-with-abio/ | 9 |
| Payroll | https://abiosystems.ca/lessons/costing-to-job-costing-and-general-ledger/ | 1 |
| Payroll | https://abiosystems.ca/lessons/creating-cheques/ | 2 |
| Payroll | https://abiosystems.ca/lessons/employee-details/ | 1 |
| Payroll | https://abiosystems.ca/lessons/entering-time/ | 1 |
| Payroll | https://abiosystems.ca/lessons/issuing-cheques-2/ | 1 |
| Project Management | https://abiosystems.ca/training | 13 |
| Shared Reports | http://abiosystems.ca/courses/managing-multiple-books-with-abio/ | 18 |

## Most Useful Report Training Records

These are the highest-value records for AI/contextual help because they include purpose, what users see, criteria, when to use the report, and practical interpretation notes.

### Accounts Payable

- `APCREP/a` - Cheques by Vendor
  Source DataWindow: `d_report_ap_cheques_by_vendor`
  Summary: Lists all cheques issued to vendors sorted by vendor code. Shows issue dates, cheque numbers,
amounts, and reconciliation status. Use for vendor payment history and cheque tracking.

- `APCREP/b` - Cheques by G/L Period
  Source DataWindow: `d_report_ap_cheques_by_gl_period`
  Summary: Displays cheques organized by accounting period. Shows all payments made within selected G/L
periods with vendor, amount, and date details. Use for period-end reporting and cash flow analysis.

- `APCREP/c` - Subcontractor Payments
  Source DataWindow: `d_report_ap_cheques_subcontractor_pay`
  Summary: Summarizes payments to subcontractors for tax reporting purposes. Shows total amounts paid to
vendors flagged as subcontractors. Required for Canada Revenue Agency compliance.

- `APCREP/d` - Cheques by Form Number
  Source DataWindow: `d_report_ap_cheques_by_form_num`
  Summary: Lists cheques sorted by physical cheque number (form number). Useful for finding specific
cheques, identifying gaps in cheque sequences, and reconciling physical cheque stock.

- `APCREP/e` - Cheque Invoice Payments
  Source DataWindow: `d_report_ap_cheques_invoice`
  Summary: Shows which invoices were paid by each cheque. Details each cheque with the specific invoice
items it paid. Use to trace payments back to original invoices.

- `APCREP/f` - Cheques by EFT Batch
  Source DataWindow: `d_report_ap_cheques_by_eft_batch`
  Summary: Lists electronic fund transfer (EFT) payments grouped by batch number. Shows vendors paid via
direct deposit or wire transfer. Use for tracking electronic payment batches.

- `APCREP/g` - Payments by Job
  Source DataWindow: `d_report_ap_cheques_payments_by_job`
  Summary: Shows payments organized by job number. Displays what was paid for each project including
vendor, invoice, and cost details. Use for job cost analysis and project payment tracking.

- `APCREP/h` - Payments by G/L Account
  Source DataWindow: `d_report_ap_cheques_payments_by_gl`
  Summary: Displays payments grouped by general ledger account code. Shows spending by expense category.
Use for expense analysis and G/L account verification.

### Accounts Receivable

- `ARBREP/c` - LEMS Billings by Centre in Job
  Source DataWindow: `d_report_ar_daysheet_by_centre`
  Summary: Shows LEMS (Labour Equipment Materials Services) charges grouped by cost centre within jobs. Use this to prepare billings and track costs by work area.

- `ARBREP/d` - LEMS by Centre in Job
  Source DataWindow: `d_report_ar_daysheet_cost`
  Summary: Shows cost detail for LEMS charges by centre in job. Displays internal costs rather than billing amounts - use this for cost analysis and job costing.

- `ARBREP/e` - LEMS Progress Draw
  Source DataWindow: `d_report_ar_daysheet_progress_draw`
  Summary: Calculates progress billing amounts based on percentage complete and contract values. Use this for schedule of values billing and progress draw invoices.

- `ARBREP/g` - LEMS Summary
  Source DataWindow: `d_report_ar_daysheet_summary`
  Summary: High-level summary of all LEMS charges by category. Perfect for a quick overview of labour, equipment, materials, and subcontract totals.

- `ARBREP/h` - LEMS Accruals by Job
  Source DataWindow: `d_report_ar_lems_accruals_by_job`
  Summary: Shows unbilled LEMS work by job for month-end revenue accrual journal entries. Breaks down labour, equipment, materials, and subcontract that needs to be accrued.

- `ARCREP/a` - Client List
  Source DataWindow: `d_report_ar_client_list`
  Summary: Shows client contact information including names, addresses, phone numbers, and last update dates. Perfect for reviewing your client list or creating a contact directory.

- `ARCREP/b` - Client Status Report
  Source DataWindow: `d_report_ar_client_status`
  Summary: Displays current outstanding balances and year-to-date totals for each client. Taken directly from client master records for a snapshot of who owes you money.

- `ARCREP/c` - Client Aged Invoice Report
  Source DataWindow: `d_report_ar_client_aged_invoice`
  Summary: Shows how old each client's unpaid invoices are with aging buckets. Built from actual invoice transactions so you can see exactly which invoices are overdue.

### Administration

- `AMAREP/a` - Database Locks
  Source DataWindow: `d_report_am_dba_database_locks`
  Summary: Shows active database locks and blocking. Identify database performance issues caused by locking and contention.

- `AMAREP/b` - Database Logins
  Source DataWindow: `d_report_am_dba_database_logins`
  Summary: Shows active database connections and user sessions. Monitor who is connected to the database and their activity.

- `AMAREP/c` - Database Statements
  Source DataWindow: `d_report_am_dba_database_statements`
  Summary: Shows active SQL statements executing in database. Monitor query performance and identify long-running or problem queries.

- `AMAREP/d` - Update Statistics
  Source DataWindow: `d_report_am_dba_update_statistics`
  Summary: Shows database table statistics status and runs statistics updates. Maintain query optimizer performance through current statistics.

- `AMAREP/e` - List Foreign Keys
  Source DataWindow: `d_report_am_dba_foreign_keys_by_parent`
  Summary: Shows database foreign key relationships. Document database referential integrity constraints and table relationships.

- `AMAREP/f` - Foreign Key Violations
  Source DataWindow: `d_report_am_dba_fk_vio_abio_user_book`
  Summary: Shows foreign key violations in database (orphaned records). Identify and fix referential integrity problems and data quality issues.

- `AMAREP/g` - Columns
  Source DataWindow: `d_report_am_dba_columns`
  Summary: Shows database column definitions and metadata. Document database structure including data types, sizes, and constraints.

- `AMAREP/h` - Index Columns
  Source DataWindow: `d_report_am_dba_index_columns`
  Summary: Shows database indexes and their columns. Document index structure for performance tuning and query optimization.

### Equipment

- `EQAREP/a` - Rental Agreements by Job in Client
  Source DataWindow: `d_report_eq_rental_agreement_by_job`
  Summary: Shows rental agreements for equipment organized by job within client. Track rental commitments and agreements by project and client.

- `EQAREP/b` - Rental Agreements Coming Due
  Source DataWindow: `d_report_eq_rental_agreement_coming_due`
  Summary: Shows rental agreements expiring soon or coming due for renewal. Proactively manage agreement renewals, extensions, or returns.

- `EQEREP/a` - Equipment List
  Source DataWindow: `d_report_eq_equipment_list`
  Summary: Lists all equipment with descriptions and basic information. Simple equipment directory for reference and documentation.

- `EQEREP/b` - Equipment Activity
  Source DataWindow: `d_report_eq_equipment_activity`
  Summary: Lists equipment transfers and timesheets in chronological and logical order. Shows incoming, job/yard/exchange, timesheets, then outgoing in sequence.

- `EQEREP/c` - Equipment by Job
  Source DataWindow: `d_report_eq_equipment_by_job`
  Summary: Shows equipment currently assigned to or working on each job. Track equipment allocation and deployment by project.

- `EQEREP/d` - Equipment by Yard
  Source DataWindow: `d_report_eq_equipment_by_yard`
  Summary: Shows equipment currently at each yard or storage location. Track yard inventory and equipment availability.

- `EQEREP/e` - Equipment by Owner & Operator
  Source DataWindow: `d_report_eq_equipment_by_owning_company`
  Summary: Shows equipment organized by owning company and operating company. Track equipment ownership and cross-company usage.

- `EQEREP/f` - Equipment by Rate Group
  Source DataWindow: `d_report_eq_equipment_by_rate_group`
  Summary: Shows equipment organized by rate group. Track billing rates and organize equipment by rate categories.

### General Ledger

- `GLAREP/a` - Account List
  Source DataWindow: `d_report_gl_account_list`
  Summary: Lists all general ledger accounts with descriptions and types. Your master chart of accounts directory for reference.

- `GLAREP/b` - First 6 Months Report
  Source DataWindow: `d_report_gl_account_first_6_months`
  Summary: Shows account balances for fiscal year opening and the first 6 months. Essential for mid-year financial reporting and G/L reconciliation.

- `GLAREP/c` - Last 6 Months Report
  Source DataWindow: `d_report_gl_account_last_6_months`
  Summary: Shows account balances for last 6 months with opening balance from end of month 6. Completes the fiscal year when combined with First 6 Months report.

- `GLAREP/d` - Account Activity Report
  Source DataWindow: `d_report_gl_account_activity`
  Summary: Shows detailed transactions for accounts in a period with opening and closing balances. Your primary account detail and reconciliation report.

- `GLAREP/e` - Employee Activity Report
  Source DataWindow: `d_report_gl_account_employee_activity`
  Summary: Shows detailed transactions by employee for accounts in a period. Track employee-specific expenses and activity with opening and closing balances.

- `GLAREP/f` - Account Budget Variances Report
  Source DataWindow: `d_report_gl_budget_variances`
  Summary: Compares actual G/L account costs to budget. Shows budget, actual, variance amounts and percentages for performance analysis.

- `GLJREP/a` - J/Es by Entry Number
  Source DataWindow: `d_report_gl_je_by_entry_number`
  Summary: Lists journal entries in entry number sequence. Quick way to find specific entries or verify sequential numbering of journal entries.

- `GLJREP/b` - J/Es by G/L Period
  Source DataWindow: `d_report_gl_je_by_gl_period`
  Summary: Shows journal entries grouped by G/L period. Essential for month-end review and G/L period reconciliation of manual entries.

### Human Resources

- `HRPREP/b` - Person Diary
  Source DataWindow: `d_report_hr_person_diary`
  Summary: Shows diary entries and notes for selected people. Track conversations, incidents, performance issues, and important events by individual.

- `HRPREP/c` - Trade Tickets by Job
  Source DataWindow: `d_report_hr_trade_ticket_by_job`
  Summary: Shows employees with trade tickets (certifications, licenses, qualifications) organized by job. Verify required certifications are on site.

- `HRPREP/d` - Trade Tickets by Expiry Date
  Source DataWindow: `d_report_hr_trade_ticket_by_expiry_date`
  Summary: Shows trade tickets organized by expiry date. Identify certifications expiring soon so employees can renew before expiry.

- `HRPREP/e` - Temporary Foreign Worker List
  Source DataWindow: `d_report_hr_foreign_worker`
  Summary: Lists temporary foreign workers with work permit and visa information. Track permits, expiry dates, and compliance for foreign worker programs.

### Inventory

- `NVSREP/a` - SKU List
  Source DataWindow: `d_report_nv_sku_list`
  Summary: Shows inventory discrepancies where purchase quantities don't match sales. Displays current stock levels, cost analysis, and pricing history. Use for physical inventory reconciliation or identifying slow-moving items.

- `NVSREP/b` - SKU Transaction History
  Source DataWindow: `d_report_nv_sku_transaction_history`
  Summary: Detailed transaction history for a single SKU showing all receipts and transfers with running balance. Includes FIFO cost tracking and inventory valuation. Use to trace SKU movements and verify stock levels.

- `NVSUMR/a` - SKU Stock Counts
  Source DataWindow: `d_report_nv_stock_counts`
  Summary: Comprehensive inventory movement report showing all transfers in and out by SKU, type, and region. Displays source/destination details, quantities, rates, and extended amounts. Use for detailed inventory analysis and physical count preparation.

### Job Costing

- `JCAREP/a` - Area & Centre List
  Source DataWindow: `d_report_jc_area_centre_list_by_area`
  Summary: Lists areas with their cost centres showing budget, commitment, and cost summaries. Quick reference for area and centre organization with financial totals.

- `JCAREP/b` - Area Consolidated Cost Report
  Source DataWindow: `d_report_jc_area_consolidated_by_area`
  Summary: Shows complete cost picture by area: budgets, commitments, costs, and adaptive forecasts. Your primary area-level cost control report with all key metrics.

- `JCAREP/c` - Area Budget Report
  Source DataWindow: `d_report_jc_area_budget_by_area`
  Summary: Shows current or original budget amounts by area. Compare original budgets to current budgets after budget transfers and changes.

- `JCAREP/d` - Area Cost Report
  Source DataWindow: `d_report_jc_area_cost_by_area`
  Summary: Shows actual or forecast costs by area. Track area cost consumption and adaptive forecasts at completion without budget comparison detail.

- `JCAREP/e` - Area List
  Source DataWindow: `d_report_jc_area_list`
  Summary: Lists all areas with descriptions and basic information. Simple directory of work areas for reference and documentation.

- `JCAREP/f` - Area P/O Tracking
  Source DataWindow: `d_report_jc_area_outstanding_po`
  Summary: Compares A/R invoices posted to areas versus P/O amounts allocated to those areas. Track billing against client P/O authorizations by work area.

- `JCBREP/a` - Budget Transfers by Transfer No
  Source DataWindow: `d_report_jc_budget_transfers_by_trans_no`
  Summary: Lists budget transfers in transfer number sequence. Track budget reallocations between centres and areas with complete detail.

- `JCBREP/b` - Budget Transfers by Centre
  Source DataWindow: `d_report_jc_budget_transfers_by_centre`
  Summary: Shows budget transfers organized by cost centre. See all budget changes affecting specific centres for detailed centre-level analysis.

### Payroll

- `PRCREP/a` - Cheques by Employee
  Source DataWindow: `d_report_pr_cheques_by_employee`
  Summary: Lists all payroll cheques organized by employee. Shows earnings, deductions, and net pay for each cheque. Perfect for reviewing an employee's complete pay history.

- `PRCREP/b` - Cheques by G/L Period
  Source DataWindow: `d_report_pr_cheques_by_gl_period`
  Summary: Shows all payroll cheques grouped by accounting period. Essential for month-end payroll reconciliation and G/L verification.

- `PRCREP/c` - Cheques by Union
  Source DataWindow: `d_report_pr_cheques_by_trade_union`
  Summary: Lists payroll cheques organized by union or trade. Track union payroll, verify union dues deductions, and prepare union remittance reports.

- `PRCREP/d` - Cheque Record
  Source DataWindow: `d_pr_pr_cheque_prn`
  Summary: Prints the actual payroll cheque format with stub detail. Use this to reprint lost cheques or create manual cheques.

- `PRCREP/e` - Cheques by Form Number
  Source DataWindow: `d_report_pr_cheques_by_form_number`
  Summary: Lists cheques in cheque number sequence. Quick way to find specific cheque numbers or verify sequential numbering.

- `PRCREP/f` - Reprint Cheque Attachments
  Source DataWindow: `d_report_pr_cheques_cheque_register`
  Summary: Reprints the detailed cheque stub/advice slip without the actual cheque. Provide employees with earnings detail when they need a replacement stub.

- `PRCREP/g` - Cheque Incentive Accruals
  Source DataWindow: `d_report_pr_cheques_incentive_accruals`
  Summary: Shows incentive pay accruals by employee and cheque. Track safety bonuses, production incentives, and other accrued incentive payments.

- `PRCREP/h` - Cheque WCB Assessments
  Source DataWindow: `d_report_pr_cheques_wcb_assessments`
  Summary: Shows WCB (Workers Compensation Board) assessments by cheque. Calculate employer WCB costs for remittance to provincial WCB offices.

### Shared Reports

- `DRFREP/a` - Financial Dashboard
  Source DataWindow: `d_report_df_dashboard`
  Summary: Executive financial dashboard showing key financial metrics and KPIs at a glance. Visual snapshot of financial health and performance.

- `DRFREP/b` - Unextracted A/P Report
  Source DataWindow: `d_report_df_unextracted_ap`
  Summary: Shows A/P invoices and labour not yet extracted to G/L. Identify pending transactions affecting financial accuracy and completeness.

- `DRFREP/c` - Unextracted Labour Report
  Source DataWindow: `d_report_df_unextracted_labour`
  Summary: Shows labour/timesheets not yet extracted to G/L. Identify pending payroll transactions affecting job costs and G/L accuracy.

- `DRFREP/d` - Unextracted Ageing Schedule
  Source DataWindow: `d_report_df_unextracted_ageing_ap`
  Summary: Shows aging of unextracted A/P transactions. Track how long transactions have been pending extraction to prioritize processing.

- `DRFREP/e` - A/R Ageing By Company
  Source DataWindow: `d_report_df_ar_ageing_by_book`
  Summary: Shows A/R aging by company. Analyze receivables aging and collection status by company for multi-company management.

- `DRFREP/f` - A/R Ageing By Client
  Source DataWindow: `d_report_df_ar_ageing_by_client`
  Summary: Shows A/R aging by client. Identify clients with aging receivables requiring collection action.

- `DRFREP/g` - A/R Ageing By Job
  Source DataWindow: `d_report_df_ar_ageing_by_job`
  Summary: Shows A/R aging by job. Analyze receivables aging by project for job-level collections management.

- `DRFREP/h` - A/P Committed Cost Schedule
  Source DataWindow: `d_report_df_comm_cost_schedule`
  Summary: Shows A/P committed costs (P/O commitments not yet invoiced). Track future payment obligations and cash flow exposure.

