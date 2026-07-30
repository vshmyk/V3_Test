$PBExportHeader$n_bo_field_timesheet.sru
forward
global type n_bo_field_timesheet from n_cst_business_abio
end type
end forward

global type n_bo_field_timesheet from n_cst_business_abio
end type
global n_bo_field_timesheet n_bo_field_timesheet

on n_bo_field_timesheet.create
call super::create
end on

on n_bo_field_timesheet.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_field_timesheet 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2018/11/24
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
This.of_SetDescription("Field Timesheet")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_field_timesheet"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book', 'work_date','add_user_id','field_timesheet_item'})

//When filtering the list, only look to the WHERE clause to place the filter criteria
this.of_SetIgnoreGroupBy(TRUE)

//Validation rules
This.of_AddValidationRule({'book', 'work_date','add_user_id','field_timesheet_item'}, "UNIQUE", &
		"", "Field Timesheet must be unique", FALSE)

//This.of_AddValidationRule({"field_timesheet"}, "REQUIRED", &
//		"", "Field Timesheet is Required", TRUE)		
//		
//This.of_AddValidationRule({"description"}, "REQUIRED", &
//		"", "Description is Required", TRUE)
//		
//This.of_AddValidationRule({"gl_account"}, "REQUIRED", &
//		"", "G/L Account is Required", TRUE)	
//		
//This.of_AddValidationRule({"active_flag"}, "REQUIRED", &
//		"", "Active Flag is Required", FALSE)	
//This.of_setcolumndefault('active_flag','Y')
//
//This.of_AddValidationRule("active_flag", "EXPRESSION", &
//		"<<active_flag>> IN ('Y', 'N')", &
//		"Active Flag Must be Y or N", FALSE)		

This.of_setcolumndefault('add_user_id', 		gnv_app.of_getuserid())
This.of_setcolumndefault('add_datetime', 		"TODAY" )

//Add this as a child so that when the field timesheet parent updates, it can update the timesheets within the transaction set
this.of_AddChild("item", 		"n_bo_timesheet")

// Add DB Constraints
// Arg:		as_constraint 	- Constraint name
//				as_column 		- Column to receive focus if constraint fails
//				as_message 		- Message to display if constraint fails
//				as_ref_table 	- Table referenced by constraint if foreign key
//This.of_AddDBConstraint("fk_field_timesheet__standard_gl_account", "gl_account", "G/L Account not setup in Shared Account Entry", "standard_gl_account")	
//This.of_AddDBConstraint("fk_wcb_rate__field_timesheet", "wcb_rate", "Field Timesheet", "field_timesheet", 'Record cannot be deleted because there is an existing WCB Rate entry (which may be in another company)')
//This.of_AddDBConstraint("fk_pr_cheque_wcb__field_timesheet", "pr_cheque_wcb", "Field Timesheet", "field_timesheet", 'Record cannot be deleted because there is an existing P/R Cheque with WCB records(which may be in another company)')
//This.of_AddDBConstraint("fk_field_timesheet__standard_gl_account", "field_timesheet", "Field Timesheet", "field_timesheet", 'Record cannot be deleted because there is an existing P/R Cheque with WCB records(which may be in another company)')

end event

