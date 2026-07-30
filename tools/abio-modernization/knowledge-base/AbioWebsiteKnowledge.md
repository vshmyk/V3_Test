# Abio Website Knowledge Base

Captured from the public Abio Systems website on 2026-07-05 for use during the Abio NG replatforming effort.

This document is intentionally a paraphrased product/domain knowledge base, not a copy of the website. PowerBuilder source, DataWindow definitions, stored procedures, and the SQL Server database remain authoritative for exact application behavior.

## Source Inventory

The website is delivered as a JavaScript single-page app. The public routes and content were extracted from the deployed app bundle:

- `https://abiosystems.ca/`
- `https://abiosystems.ca/about-abio`
- `https://abiosystems.ca/canadian-payroll`
- `https://abiosystems.ca/construction-finance`
- `https://abiosystems.ca/construction-invoicing`
- `https://abiosystems.ca/construction-accounts-payable`
- `https://abiosystems.ca/job-costing`
- `https://abiosystems.ca/subcontractors-purchase-orders`
- `https://abiosystems.ca/mobile-timesheet-software`
- `https://abiosystems.ca/reporting-analytics`
- `https://abiosystems.ca/document-management-for-construction`
- `https://abiosystems.ca/cloud-based-accounting-software`
- `https://abiosystems.ca/privacy-policy`

## Product Positioning

Abio is positioned as construction-focused ERP/accounting software for contractors and industrial construction companies. The core message is integration: replacing spreadsheets, duplicate entry, disconnected accounting tools, paper documents, and delayed job-cost visibility with a single operational and financial platform.

Important themes for Abio NG:

- Construction-specific workflows should be first-class, not generic accounting screens with construction labels.
- Real-time job cost visibility is central to the value proposition.
- Users need drill-down paths from summaries to transactions, related documents, invoices, POs, requisitions, payments, timesheets, and job details.
- The platform should reduce double entry between field operations, payroll, AP, AR, job cost, and GL.
- Role-based security, audit trails, document access control, and approval flows are recurring product expectations.
- Cloud/mobile access matters because office staff, supervisors, and project teams work from different locations.

## Domain Modules

### Construction Finance / General Ledger

Primary user goals:

- Understand company and project financial position from one platform.
- Manage multiple companies, divisions, profit centers, and consolidation views.
- Set up and track monthly GL budgets.
- Use financial statements, dashboards, real-time enquiries, and drill-down to subledgers.
- Maintain auditability and control access to sensitive financial data.

Replatforming implications:

- Preserve book/company/division/profit-center concepts explicitly in APIs and routing.
- Financial screens should support drill-down to source transactions and attached documents.
- GL actions should remain server-side command flows with audit logging, not direct grid updates.

Likely Abio NG entities:

- Book
- Company
- Division
- Profit center
- General ledger account
- Budget
- Journal entry
- Subledger transaction
- Audit event

### Job Costing

Primary user goals:

- See the true cost picture for each job.
- Compare budget, actual cost, commitments, revenue, payment, expected cost, and variance.
- Use graphical and numerical views.
- Save customized views for different users and roles.
- Detect job risk early enough to react before cost overruns grow.

Replatforming implications:

- Job must remain a central navigation hub.
- Related record links should connect job screens to AP invoices, AR invoices, timesheets, purchase orders, commitments, documents, and transactions.
- AG Grid views should support filtering, grouping, saved layouts, and drill-down.
- Job record edit logic must continue to come from migrated PowerBuilder program-layer rules.

Likely Abio NG entities:

- Job
- Job cost transaction
- Area
- Cost centre
- Budget line
- Commitment
- Variance order
- Job analytics view

### Accounts Payable

Primary user goals:

- Organize construction expenses and supplier/subcontractor payments.
- Avoid missed payments and cost-budget surprises.
- Connect requisitions, purchase orders, invoices, payments, job cost, and documents.
- Track insurance certificates, licences, expiry dates, retention holdback, and creditor/subcontractor claims.
- Use invoice OCR/scanning and approval batches where appropriate.

Replatforming implications:

- AP screens need document-aware transaction navigation.
- Vendor default cost codes and streamlined invoice entry should be preserved from legacy logic.
- PO-to-invoice matching and committed cost updates need command-layer integrity.
- Batch approval and OCR/import workflows should be modeled as explicit queues.

Likely Abio NG entities:

- Vendor
- AP invoice
- AP invoice item
- Requisition
- Purchase order
- Payment
- Holdback
- Insurance certificate
- Document attachment

### Construction Invoicing / Accounts Receivable

Primary user goals:

- Produce invoices and claims efficiently.
- Track receivables, payments, retention, progress billing, and AR KPIs.
- Consolidate LEMS backup into invoices.
- Support Time & Materials billing, client approvals, and dispute-ready documentation.
- Post invoice effects to AR, GL, equipment, job, and customer records.

Replatforming implications:

- AR invoice workflows should connect to LEMS, timesheets, equipment charges, materials, subcontract costs, payments, and documents.
- Invoice generation should be a server-side command with posting rules and audit events.
- UI should make supporting evidence easy to inspect from the invoice record.

Likely Abio NG entities:

- Client
- AR invoice
- AR invoice item
- Claim
- Progress billing
- Retention
- Payment
- LEMS package
- Client approval

### Subcontractors And Purchase Orders

Primary user goals:

- Manage subcontractor contracts, requisitions, POs, invoices, insurance, and documents.
- Track subcontractor holdback, progress payments, taxes, variance orders, approvals, and payments.
- Keep committed costs current in real time.
- Search completed POs by PO number, inventory item, vendor, and other business keys.

Replatforming implications:

- PO screens should expose committed-cost impact clearly.
- Approval workflows must be preserved as stateful business processes.
- Subcontractor records should link to insurance/document expiry tracking.
- Search should cover identifiers and business terms, not only primary keys.

Likely Abio NG entities:

- Subcontractor
- Contract
- Purchase order
- Purchase order line
- Requisition
- Commitment
- Variance order
- Approval
- Insurance/expiry record

### Mobile Timesheets

Primary user goals:

- Capture field labour hours from phones/tablets.
- Reduce paper, handwriting issues, delays, and office double entry.
- Let supervisors enter, review, approve, or reject time.
- Surface rejected time for correction without email/phone reminders.
- Integrate time with payroll, job cost, billing, LEMS, and client sign-off.

Replatforming implications:

- Timesheet entry needs strong validation and offline/mobile-friendly UX consideration.
- Approval/rejection should be explicit state transitions, not just editable fields.
- Timesheet data must feed payroll, job cost, and invoice support packages consistently.
- Client sign-off and Adobe Sign-style approval integration should be represented as extension points.

Likely Abio NG entities:

- Timesheet
- Timesheet item
- Employee
- Crew
- Supervisor
- Labour type
- Approval status
- Rejected time
- LEMS approval

### Canadian Payroll

Primary user goals:

- Support unionized labour payroll.
- Handle complex earnings, overtime, bonuses, travel allowances, deductions, garnishments, and employee expenses.
- Produce CRA and union reporting/remittances.
- Generate year-end outputs such as T4s and ROEs.
- Integrate payroll with time tracking, AP, GL, and compliance.

Replatforming implications:

- Payroll is a high-risk domain; calculations must be migrated from authoritative PB/database logic.
- Union rules and remittance rules should be represented as versioned server-side policies.
- UI should avoid embedding payroll formulas in Angular.

Likely Abio NG entities:

- Employee
- Payroll run
- Earnings type
- Deduction
- Union
- Remittance
- Expense/garnishment payable
- T4
- ROE

### Reporting And Analytics

Primary user goals:

- Turn construction data into actionable views.
- Customize reports, dashboards, filters, and display order.
- Drill down from visual summaries to details.
- Track project and business performance with real-time updates.

Replatforming implications:

- AG Grid saved layouts and server-backed report definitions are important.
- Dashboards should link to operational records, not dead-end charts.
- Filters should map to API contracts that can be reused by AI-assisted search.

Likely Abio NG entities:

- Report definition
- Dashboard
- Dashboard widget
- Saved view
- Filter
- Drill-down action

### Document Management

Primary user goals:

- Store, index, tag, view, and retrieve construction documents.
- Protect documents with permissions and backups.
- Connect documents to invoices, POs, requisitions, photos, cheques, jobs, and project records.
- Track revisions and audit history.
- Route documents for approval.

Replatforming implications:

- Document attachments should be a platform service used by AP, AR, Job Cost, Payroll, and Projects.
- Related-record navigation must include document links.
- Permissions and audit trail need server enforcement.
- AI assistant can be useful for document discovery if metadata is indexed.

Likely Abio NG entities:

- Document
- Document version
- Document tag
- Attachment link
- Approval route
- Permission
- Audit trail

### Cloud Platform

Primary user goals:

- Access the system from the office, job site, or remote locations.
- Avoid local infrastructure and manual upgrades.
- Scale data usage over time.
- Support secure authorized access from browser/tablet devices.

Replatforming implications:

- Abio NG should assume browser-first delivery and centralized service hosting.
- Authentication, authorization, tenant/book scoping, backups, and uptime should be designed as platform concerns.
- Mobile-responsive layouts matter for field use cases such as timesheets and approvals.

## Cross-Module Business Flows

### Field Time To Payroll, Job Cost, And Billing

1. Supervisor or field user enters labour time.
2. Time is reviewed, approved, or rejected.
3. Approved time updates job cost and feeds payroll.
4. Time and LEMS evidence can support AR invoicing.
5. Client approval/sign-off may be attached to billing support.

### Purchase Order To AP And Committed Cost

1. Requisition or PO is created for materials/services/subcontract work.
2. Approval workflow controls purchasing.
3. PO lines increase committed costs on the job.
4. Vendor invoices are posted against open PO lines.
5. AP, job cost, documents, and committed cost balances update together.

### Job Financial Visibility

1. Job record defines core job attributes and accounting classifications.
2. AP, AR, timesheets, JC transactions, and commitments accumulate against the job.
3. Dashboards and enquiries summarize current performance.
4. Users drill down to transactions, source documents, and related records.

### Document-Backed Transaction Review

1. Transaction is entered or imported.
2. Supporting documents are uploaded, emailed, scanned, or system-generated.
3. Documents are indexed/tagged to the related business records.
4. Users open documents from AP, AR, PO, job, or report drill-downs.
5. Audit trail and revisions preserve evidence for disputes and controls.

## AI Assistant Use Cases

The future Abio NG AI component can use this KB to:

- Explain module purpose in business language.
- Map user phrases to Abio modules and screens.
- Suggest likely navigation paths.
- Expand acronyms and construction accounting terms.
- Help users understand how records relate across AP, AR, job cost, payroll, documents, and reporting.
- Provide onboarding help without requiring users to know legacy menu paths.

The AI component must not use this website KB as the source for:

- Posting rules.
- Payroll calculations.
- Security permissions.
- Save/update validation.
- Financial statement calculations.
- Legal/compliance assertions.

Those must come from migrated PB source, SQL schema/procedures, verified product documentation, and customer-approved requirements.

## Replatforming Guidance

Use this KB as a product-context overlay while migrating:

- When designing navigation, prefer workflows and related-record links that match construction ERP tasks.
- When naming UI elements, prefer Abio/customer language over generic software labels.
- When building APIs, keep business commands explicit: approve, post, reverse, generate invoice, attach document, reject time, etc.
- When modernizing DataWindow screens into AG Grid, preserve drill-down, saved views, filtering, and transaction context.
- When adding AI features, index by module, entity, workflow, source record, and permission scope.

