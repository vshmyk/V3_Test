$PBExportHeader$n_bo_employee_wcb.sru
forward
global type n_bo_employee_wcb from n_cst_business_abio
end type
end forward

global type n_bo_employee_wcb from n_cst_business_abio
end type
global n_bo_employee_wcb n_bo_employee_wcb

on n_bo_employee_wcb.create
call super::create
end on

on n_bo_employee_wcb.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_employee_wcb 
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
This.of_SetDescription("Employee WCB")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_employee_wcb"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book','employee','wcb_class','tax_year'})


// Set Validations

This.of_AddValidationRule({'book','employee','wcb_class','tax_year'}, "UNIQUE", &
		"", "Employee Must be Unique within the Company, WCB Class and Tax Year", FALSE)

	
This.of_AddValidationRule({"employee"}, "REQUIRED", &
		"", "Employee is Required", FALSE)
		
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Company is Required", FALSE)		

This.of_AddValidationRule({"wcb_class"}, "REQUIRED", &
		"", "WCB Class is Required", FALSE)		
		
This.of_AddValidationRule({"tax_year"}, "REQUIRED", &
		"", "Tax Year is Required", FALSE)		
		
		
This.of_AddValidationRule({"wcb_assessable_earn"}, "REQUIRED", &
		"", "WCB Earning is Required", FALSE)		

This.of_AddValidationRule({"wcb_remittance"}, "REQUIRED", &
		"", "WCB Remittance is Required", FALSE)		

	

// Default Values
This.of_setcolumndefault('wcb_assessable_earn','0')
This.of_setcolumndefault('wcb_remittance','0')
This.of_setcolumndefault('book', trim(gnv_app.is_book))

// Add DB Constraints
This.of_AddDBConstraint("pk_employee_wcb", "employee_wcb", "Employee","")
This.of_AddDBConstraint("fk_employee_wcb__employee_earning", "employee_wcb", "Employee", "employee_earning")
This.of_AddDBConstraint("fk_employee_wcb__wcb_rate", "employee_wcb",  "WCB Rate", "wcb_rate")

end event

