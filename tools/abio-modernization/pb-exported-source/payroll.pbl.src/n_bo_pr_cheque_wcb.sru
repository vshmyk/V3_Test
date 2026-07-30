$PBExportHeader$n_bo_pr_cheque_wcb.sru
forward
global type n_bo_pr_cheque_wcb from n_cst_business_abio
end type
end forward

global type n_bo_pr_cheque_wcb from n_cst_business_abio
end type
global n_bo_pr_cheque_wcb n_bo_pr_cheque_wcb

on n_bo_pr_cheque_wcb.create
call super::create
end on

on n_bo_pr_cheque_wcb.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_cheque_no_wcb 
// Function :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/05/05
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Initialize Business Object
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

// Set the object description to be seen in messages to user
This.of_SetDescription("P/R Cheque WCB")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_pr_cheque_wcb"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book','cheque_no','wcb_class'})


// Set Validations

This.of_AddValidationRule({'book','cheque_no','wcb_class'}, "UNIQUE", &
		"", "WCB Class must be unique", FALSE)

This.of_AddValidationRule({"cheque_no"}, "REQUIRED", &
		"", "cheque_no is Required", FALSE)
		
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Company is Required", FALSE)		

This.of_AddValidationRule({"wcb_class"}, "REQUIRED", &
		"", "WCB Class is Required", FALSE)		
		
This.of_AddValidationRule({"wcb_assessable_earn"}, "REQUIRED", &
		"", "WCB Earning is Required", FALSE)		

This.of_AddValidationRule({"wcb_remittance"}, "REQUIRED", &
		"", "WCB Remittance is Required", FALSE)		

// Default Values
This.of_setcolumndefault('wcb_assessable_earn','0')
This.of_setcolumndefault('wcb_remittance','0')
This.of_setcolumndefault('book', trim(gnv_app.is_book))

// Add DB Constraints
//This.of_AddDBConstraint("pk_cheque_wcb", "cheque_no_wcb", "cheque_no","")
//This.of_AddDBConstraint("fk_cheque_no_wcb__cheque_no_earning", "cheque_no_wcb", &
//		"cheque_no", "cheque_no_earning")
//This.of_AddDBConstraint("fk_cheque_no_wcb__wcb_class", "cheque_no_wcb", &
//		"WCB Class", "wcb_class")
//		
This.of_AddDBConstraint("fk_pr_cheque_wcb__wcb_rate", 	/* constraint */ 			&
                        "wcb_class", 							/* column */ 				&
		                  "No rates setup for WCB class", 	/* message */ 				&
								"wcb_rate") 							/* reference table */

		


























end event

