$PBExportHeader$n_bo_pr_cheque_queue.sru
forward
global type n_bo_pr_cheque_queue from n_cst_business_abio
end type
end forward

global type n_bo_pr_cheque_queue from n_cst_business_abio
end type
global n_bo_pr_cheque_queue n_bo_pr_cheque_queue

on n_bo_pr_cheque_queue.create
call super::create
end on

on n_bo_pr_cheque_queue.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_pr_cheque_queue 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2016/04/01
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
This.of_SetDescription("P/R Cheque Queue")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_pr_cheque_queue"

//Set primary key column
of_setpkcolumns({'book','queue_key'})

// Set Validations
This.of_AddValidationRule({'book','queue_key'}, "UNIQUE", &
		"", "Cheque Queue must be unique", FALSE)

This.of_AddValidationRule({"queue_key"}, "REQUIRED", &
		"", "Queue Key is Required", FALSE)
		
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Company is Required", FALSE)		

// Default Values
This.of_setcolumndefault('book', trim(gnv_app.is_book))

end event

