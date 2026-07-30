$PBExportHeader$n_bo_pr_cheque_premium.sru
forward
global type n_bo_pr_cheque_premium from n_cst_business_abio
end type
end forward

global type n_bo_pr_cheque_premium from n_cst_business_abio
end type
global n_bo_pr_cheque_premium n_bo_pr_cheque_premium

on n_bo_pr_cheque_premium.create
call super::create
end on

on n_bo_pr_cheque_premium.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_cheque_no_premium 
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
This.of_SetDescription("P/R Cheque premium")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_pr_cheque_premium"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book','cheque_no','premium_type'})


// Set Validations

This.of_AddValidationRule({'book','cheque_no','premium_type'}, "UNIQUE", &
		"", "Premium Type must be unique", FALSE)

	
This.of_AddValidationRule({"cheque_no"}, "REQUIRED", &
		"", "cheque_no is Required", FALSE)
		
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Company is Required", FALSE)		

This.of_AddValidationRule({"premium_type"}, "REQUIRED", &
		"", "Premium Type is Required", FALSE)		

// Default Values
This.of_setcolumndefault('reg_earn','0')
This.of_setcolumndefault('tah_earn','0')
This.of_setcolumndefault('ovr_earn','0')
This.of_setcolumndefault('book', trim(gnv_app.is_book))

// Add DB Constraints
//This.of_AddDBConstraint("pk_cheque_premium", "cheque_no_premium", "cheque_no","")
//This.of_AddDBConstraint("fk_cheque_no_premium__cheque_no_earning", "cheque_no_premium", &
//		"cheque_no", "cheque_no_earning")
//This.of_AddDBConstraint("fk_cheque_no_premium__premium_type", "cheque_no_premium", &
//		"premium Class", "premium_type")
//		
		


























end event

