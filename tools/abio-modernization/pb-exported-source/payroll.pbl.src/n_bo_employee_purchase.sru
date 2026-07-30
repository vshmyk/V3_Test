$PBExportHeader$n_bo_employee_purchase.sru
forward
global type n_bo_employee_purchase from n_cst_business_abio
end type
end forward

global type n_bo_employee_purchase from n_cst_business_abio
end type
global n_bo_employee_purchase n_bo_employee_purchase

forward prototypes
public function integer of_repay (long al_cheque_no, decimal adec_misc_deduct, long al_employee, datetime adt_issue, string as_pr_yyyymm)
public function integer of_reset_fully_paid_invoices (long al_employee)
public function integer of_mark_orphans_paid (long al_cheque_no, decimal adec_misc_deduct, long al_employee, datetime adt_issue, string as_pr_yyyymm)
public function decimal of_get_outstanding ()
public function integer of_reset_employee_purchase_repayments (long al_cheque, long al_employee, ref decimal adec_total_unpaid_employee_purchases)
end prototypes

public function integer of_repay (long al_cheque_no, decimal adec_misc_deduct, long al_employee, datetime adt_issue, string as_pr_yyyymm);
//************************************************************
// Object   :	n_abio_appmanager 
// Function :	of_repay
// Author   :	Monica Petersen
// Date     :	June 25, 2007, MDP
// 	
// Arguments:	long al_cheque_no
// 				decimal adec_misc_deduct
// 				long al_employee
// 				datetime adt_issue
// 				string as_pr_yyyymm
// 	
// Returns:		integer
// 	
// Desc:			Mark employee purchases as having some payment made against them.
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2009.06.01		MDP		jira 502 - was resetting the amount
//                         deducted when spread over multiple invoices.           
//************************************************************

Long							ll_ep_rows, ll_ep_row
s_validation_error  		lstr_error[]
String						ls_error_message
Integer						li_errcount, li_error
Integer						li_x, li_y
Long							ll_rows_date, ll_rows
Decimal						ldec_repaid_with_this_cheque, ldec_amount, ldec_balance_owing_on_invoice
n_ds							lds_employee_purchase_invoices


//initially the business object contains all employee purchases for the current employee

lds_employee_purchase_invoices = CREATE n_ds
lds_employee_purchase_invoices.dataobject = 'd_prcent_repay'
lds_employee_purchase_invoices.of_SetTransObject(sqlca)


//This datastore gets all the distinct invoices for this employee
ll_rows = lds_employee_purchase_invoices.Retrieve(gnv_app.is_book, al_employee)
ldec_repaid_with_this_cheque = 0		
FOR li_x = 1 TO ll_rows

	// sum amount employee owes for a single invoice item
	ldec_balance_owing_on_invoice = 0
	this.of_SetFilter("vendor = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'vendor') &
							+ "' AND invoice_no = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'invoice_no') &
							+ "' AND invoice_item = " + String(lds_employee_purchase_invoices.GetItemNumber(li_x, 'invoice_item')))
	this.of_Filter()
	ll_ep_rows = this.of_RowCount()
	FOR ll_ep_row = 1 TO ll_ep_rows
		ldec_balance_owing_on_invoice += this.of_GetItemDecimal(ll_ep_row, 'amount')
	NEXT
	
	IF ldec_balance_owing_on_invoice <> 0 THEN

		//Is there still enough of the miscellaneous deduction to pay this invoice?
		IF ldec_balance_owing_on_invoice < 0 THEN
			ldec_amount = Max(ldec_balance_owing_on_invoice, adec_misc_deduct - ldec_repaid_with_this_cheque)
		ELSE
			ldec_amount = Min(ldec_balance_owing_on_invoice, adec_misc_deduct - ldec_repaid_with_this_cheque)
		END IF
		
		IF ldec_amount <> 0 THEN
			
			// Apply payment to the invoice
			// the records for this employee were retrieved previously in the of_reset_employee_purchase_repayments routine
			this.of_SetFilter('')
			this.of_Filter()
			ll_ep_row = this.of_Find("vendor = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'vendor') &
							+ "' AND invoice_no = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'invoice_no') &
							+ "' AND invoice_item = " + String(lds_employee_purchase_invoices.GetItemNumber(li_x, 'invoice_item'))  &
							+ "  AND cheque_no = " + String(al_cheque_no))
							
			IF ll_ep_row > 0 THEN
				
				// it may be the row has been inserted during a previous cheque approval, 
				// and its amount set to $0.00 to reinitialize processing for this cheque
				this.of_SetItem(ll_ep_row, 'activity_date', 	adt_issue)
				this.of_SetItem(ll_ep_row, 'gl_yyyymm', 		as_pr_yyyymm)
				this.of_SetItem(ll_ep_row, 'amount', 			this.of_GetItemDecimal(ll_ep_row, 'amount') + (ldec_amount * -1.0))
			ELSE
				
				// first time looking at this cheque, so it needs an entry inserted
				// to record it's payment against the invoice
				ll_ep_row = this.of_InsertRow(0)
				this.of_SetItem(ll_ep_row, 'book', 				gnv_app.is_book)
				this.of_SetItem(ll_ep_row, 'employee', 		al_employee)
				this.of_SetItem(ll_ep_row, 'vendor', 			lds_employee_purchase_invoices.GetItemString(li_x, 'vendor'))
				this.of_SetItem(ll_ep_row, 'invoice_no', lds_employee_purchase_invoices.GetItemString(li_x, 'invoice_no'))
				this.of_SetItem(ll_ep_row, 'invoice_item', 	lds_employee_purchase_invoices.GetItemNumber(li_x, 'invoice_item'))
				this.of_SetItem(ll_ep_row, 'cheque_no', 		al_cheque_no)
				this.of_SetItem(ll_ep_row, 'activity_date', 	adt_issue)
				this.of_SetItem(ll_ep_row, 'gl_yyyymm', 		as_pr_yyyymm)
				this.of_SetItem(ll_ep_row, 'amount', 			ldec_amount * -1.0)
				this.of_SetItem(ll_ep_row, 'file_type', 		'C')
			END IF

			// Keep track of how much we've paid with this cheque, as it may be
			// applied against several invoices
			ldec_repaid_with_this_cheque = ldec_repaid_with_this_cheque + ldec_amount
			IF ldec_repaid_with_this_cheque = adec_misc_deduct THEN 
				EXIT
			END IF
		END IF
	END IF
	
	//Need to get ALL the way out of the loop
	IF ldec_repaid_with_this_cheque = adec_misc_deduct THEN 
		EXIT
	END IF
NEXT

//Make sure all the rows are available for the later manipulations
this.of_SetFilter('')
this.of_Filter()

DESTROY lds_employee_purchase_invoices

RETURN 1
end function

public function integer of_reset_fully_paid_invoices (long al_employee);
//************************************************************
// Object   :	n_bo_employee_purchase 
// Function :	of_reset_fully_paid_invoices
// Author   :	Monica Petersen
// Date     :	June 25, 2007, MDP
// 	
// Arguments:	long al_cheque
// 				long al_employee
// 				decimal adec_total_unpaid_employee_purchases
// 	
// Returns:		integer
// 	
// Desc:			Delete repayments associated with this cheque, in preparation for recalculating
//		         the appropriate deduction amount.
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long		ll_ep_rows, ll_ep_row, ll_rows
Integer	li_x
Decimal	ldec_balance_owing_on_invoice
n_ds		lds_employee_purchase_invoices



//Get everything for this employee and sort it out
ll_ep_rows = this.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
IF ll_ep_rows < 0 THEN
	this.of_msg_db_error("Error reading employee_purchase")
	RETURN -1
ELSE
	FOR ll_ep_row = 1 TO ll_ep_rows
		
		IF this.of_GetItemString(ll_ep_row, 'file_type') = 'H' THEN
			//Bring everything back off history
			this.of_SetItem(ll_ep_row, 'file_type', 'C')			
		END IF
		
	NEXT
END IF

//Now reselect fully paid invoices for this employee and mark them as history
lds_employee_purchase_invoices = CREATE n_ds
lds_employee_purchase_invoices.dataobject = 'd_prcent_repay'
lds_employee_purchase_invoices.of_SetTransObject(sqlca)
ll_rows = lds_employee_purchase_invoices.Retrieve(gnv_app.is_book, al_employee)
FOR li_x = 1 TO ll_rows

	//Isolate each invoice
	this.of_SetFilter("vendor = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'vendor') &
							+ "' AND invoice_no = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'invoice_no') &
							+ "' AND invoice_item = " + String(lds_employee_purchase_invoices.GetItemNumber(li_x, 'invoice_item')))
	this.of_Filter()
	
	//Sum the balance owing for the invoice
	ldec_balance_owing_on_invoice = 0
	ll_ep_rows = this.of_RowCount()
	FOR ll_ep_row = 1 TO ll_ep_rows
		ldec_balance_owing_on_invoice += this.of_GetItemDecimal(ll_ep_row, 'amount')
	NEXT
	
	//Move the set of records associated with the fully paid invoice to history
	IF ldec_balance_owing_on_invoice = 0 THEN
		FOR ll_ep_row = 1 TO ll_ep_rows
			this.of_SetItem(ll_ep_row, 'file_type', 'H')
		NEXT
	END IF

NEXT

//jira 2938 - we may also have invoices that were reversed, and they should also be placed on history if they balance off to zero for the vendor
FOR li_x = 1 TO ll_rows

	//Isolate each vendor
	this.of_SetFilter("vendor = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'vendor') + "' AND file_type = 'C'")
	this.of_Filter()
	
	//Sum the balance owing for the invoice
	ldec_balance_owing_on_invoice = 0
	ll_ep_rows = this.of_RowCount()
	FOR ll_ep_row = 1 TO ll_ep_rows
		ldec_balance_owing_on_invoice += this.of_GetItemDecimal(ll_ep_row, 'amount')
	NEXT
	
	//Move the set of records associated with the fully paid invoice to history
	IF ldec_balance_owing_on_invoice = 0 THEN
		FOR ll_ep_row = 1 TO ll_ep_rows
			this.of_SetItem(ll_ep_row, 'file_type', 'H')
		NEXT
	END IF

NEXT

//Now delete any zero value payments
this.of_SetFilter('')
this.of_Filter()
ll_ep_rows = this.of_RowCount()
FOR ll_ep_row = ll_ep_rows TO 1 STEP -1
	IF this.of_GetItemDecimal(ll_ep_row, 'amount') = 0 THEN
		this.of_DeleteRow(ll_ep_row)
	END IF
NEXT

RETURN 1
end function

public function integer of_mark_orphans_paid (long al_cheque_no, decimal adec_misc_deduct, long al_employee, datetime adt_issue, string as_pr_yyyymm);
//************************************************************
// Object   :	n_bo_employee_purchase 
// Function :	of_mark_orphans_paid
// Author   :	Monica Petersen
// Date     :	2013/10/29
// 	
// Arguments:	long al_cheque_no
// 				decimal adec_misc_deduct
// 				long al_employee
// 				datetime adt_issue
// 				string as_pr_yyyymm
// 	
// Returns:		integer
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long							ll_ep_rows, ll_ep_row
Integer						li_x
Long							ll_rows
Decimal						ldec_amount
n_ds							lds_employee_purchase_invoices


lds_employee_purchase_invoices = CREATE n_ds
lds_employee_purchase_invoices.dataobject = 'd_prcent_repay'
lds_employee_purchase_invoices.of_SetTransObject(sqlca)

this.of_SetFilter('')
this.of_Filter()
		
//This datastore gets all the distinct invoices for this employee
ll_rows = lds_employee_purchase_invoices.Retrieve(gnv_app.is_book, al_employee)

FOR li_x = 1 TO ll_rows
	
	// This routine is only invoked when the outstanding balance for an employee is $0.00
	// It's purpose is to search out invoices that have been reversed by other invoices, 
	// and mark them as fully paid by the current cheque
	// Either there's already an entry in the table for the current cheque, or it will need to be inserted

	ldec_amount = 0
	FOR ll_ep_row = 1 TO this.of_RowCount()
		IF this.of_GetItemString(ll_ep_row, 'vendor') = lds_employee_purchase_invoices.GetItemString(li_x, 'vendor') &
		AND this.of_GetItemString(ll_ep_row, 'invoice_no') = lds_employee_purchase_invoices.GetItemString(li_x, 'invoice_no') &
		AND this.of_GetItemNumber(ll_ep_row, 'invoice_item') = lds_employee_purchase_invoices.GetItemNumber(li_x, 'invoice_item') THEN 
			ldec_amount += this.of_GetItemDecimal(ll_ep_row, 'amount')
		END IF
	NEXT
	
	// None of the individual invoice items should have outstanding amounts, so add a reversing entry for this item so it sums to zero
	IF ldec_amount <> 0 THEN			
		ll_ep_row = this.of_Find("vendor = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'vendor') &
						+ "' AND invoice_no = '" + lds_employee_purchase_invoices.GetItemString(li_x, 'invoice_no') &
						+ "' AND invoice_item = " + String(lds_employee_purchase_invoices.GetItemNumber(li_x, 'invoice_item'))  &
						+ "  AND cheque_no = " + String(al_cheque_no))
						
		IF ll_ep_row = 0 THEN
			ll_ep_row = this.of_InsertRow(0)
			this.of_SetItem(ll_ep_row, 'book', 				gnv_app.is_book)
			this.of_SetItem(ll_ep_row, 'employee', 		al_employee)
			this.of_SetItem(ll_ep_row, 'vendor', 			lds_employee_purchase_invoices.GetItemString(li_x, 'vendor'))
			this.of_SetItem(ll_ep_row, 'invoice_no', lds_employee_purchase_invoices.GetItemString(li_x, 'invoice_no'))
			this.of_SetItem(ll_ep_row, 'invoice_item', 	lds_employee_purchase_invoices.GetItemNumber(li_x, 'invoice_item'))
			this.of_SetItem(ll_ep_row, 'cheque_no', 		al_cheque_no)
			this.of_SetItem(ll_ep_row, 'activity_date', 	adt_issue)
			this.of_SetItem(ll_ep_row, 'gl_yyyymm', 		as_pr_yyyymm)
			this.of_SetItem(ll_ep_row, 'amount', 			ldec_amount * -1.0)
			this.of_SetItem(ll_ep_row, 'file_type', 		'C')
		ELSE
			this.of_SetItem(ll_ep_row, 'amount', 			this.of_GetItemDecimal(ll_ep_row, 'amount') - ldec_amount)
		END IF
	END IF

NEXT

DESTROY lds_employee_purchase_invoices

RETURN 1
end function

public function decimal of_get_outstanding ();
//************************************************************
// Object   :	n_bo_employee_purchase 
// Function :	of_get_outstanding
// Author   :	Monica Petersen
// Date     :	2013/10/29
// 	
// Arguments:	integer 
// 	
// Returns:		decimal
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer	li_x
Decimal	ldec_outstanding

FOR li_x = 1 TO this.of_RowCount()
	ldec_outstanding += this.of_GetItemDecimal(li_x, 'amount')
NEXT 

RETURN ldec_outstanding
end function

public function integer of_reset_employee_purchase_repayments (long al_cheque, long al_employee, ref decimal adec_total_unpaid_employee_purchases);
//************************************************************
// Object   :	n_bo_employee_purchase 
// Function :	of_reset_employee_purchase_repayments
// Author   :	Monica Petersen
// Date     :	June 25, 2007, MDP
// 	
// Arguments:	long al_cheque
// 				long al_employee
// 				decimal adec_total_unpaid_employee_purchases
// 	
// Returns:		integer
// 	
// Desc:			Delete repayments associated with this cheque, in preparation for recalculating
//		         the appropriate deduction amount.
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long		ll_ep_rows, ll_ep_row
Decimal	ldec_this_cheque
s_validation_error  		lstr_error[]
String						ls_error_message
Integer						li_errcount, li_error

//Initialize amount returned because this will be called in a loop.
adec_total_unpaid_employee_purchases = 0

//Get everything for this employee and sort it out
ll_ep_rows = this.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
IF ll_ep_rows < 0 THEN
	this.of_msg_db_error("Error reading employee_purchase")
	RETURN -1
ELSE
	FOR ll_ep_row = 1 TO ll_ep_rows
		
		IF this.of_GetItemNumber(ll_ep_row, 'cheque_no') = al_cheque THEN
			//If it was paid for by this cheque, it's not any more
			this.of_SetItem(ll_ep_row, 'amount', 0)
		END IF
		
		//Calculate total amount owing
		adec_total_unpaid_employee_purchases += this.of_GetItemDecimal(ll_ep_row, 'amount')
	NEXT
END IF

RETURN 1
end function

on n_bo_employee_purchase.create
call super::create
end on

on n_bo_employee_purchase.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_employee_purchase 
// Event    :	constructor
// Author   :	Viktar Shmyk
// Date     :	2010/09/28
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



// Set the object description to be seen in messages to user
This.of_SetDescription("P/R Employee Purchase")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_employee_purchase"

// Force a new transaction for this business object
This.of_SetTransaction()

This.of_AddValidationRule({"book", "employee", "vendor", "invoice_no", "invoice_item", "cheque_no"}, "UNIQUE", &
		"", "Employee purchase Already Exists", FALSE)

//Set primary key column
of_setpkcolumns({"book", "employee", "vendor", "invoice_no", "invoice_item", "cheque_no"})


// Default values
This.of_SetColumnDefault("file_type", "C")

// Arg:		as_constraint - Constraint name
//				as_column - Columen to receive focus if constraint fails
//				as_message - Message to display if constraint fails
//				as_ref_table - Table referenced by constraint if foreign key
This.of_AddDBConstraint("fk_employee_purchase__ap_invoice", 	"invoice_no", "Invoice not found in the A/P invoice table", 	"ap_invoice", '')
This.of_AddDBConstraint("fk_employee_purchase__pr_cheque", 		"cheque_no", 		"Cheque not found in the P/R cheque table", 		"pr_cheque", '')


end event

