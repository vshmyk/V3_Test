$PBExportHeader$n_bo_timesheet_status.sru
forward
global type n_bo_timesheet_status from n_cst_business_abio
end type
end forward

global type n_bo_timesheet_status from n_cst_business_abio
end type
global n_bo_timesheet_status n_bo_timesheet_status

on n_bo_timesheet_status.create
call super::create
end on

on n_bo_timesheet_status.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_timesheet_status 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2012/12/04
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
This.of_SetDescription("Timesheet Status")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_timesheet_status"

// Set primary key columns
This.of_SetPKColumns({"timesheet_status"})

// Force a new transaction for this business object
This.of_SetTransaction()

//GST Rule
This.of_AddValidationRule({"timesheet_status"}, "UNIQUE", &
		"", "Timesheet Status must be Unique", FALSE)
	
//Description		
This.of_AddValidationRule({"description"}, "REQUIRED", &
		"", "Description is Required", FALSE)	

//Active Flag
This.of_AddValidationRule({"active_flag"}, "REQUIRED", &
		"", "Active Flag is Required", FALSE)	
This.of_AddValidationRule("active_flag", "EXPRESSION", &
		"<<active_flag>> IN ('Y', 'N')", &
		"Active Flag Must be Y or N", FALSE)		
			
//Active Flag
This.of_AddValidationRule({"entry_default_flag"}, "REQUIRED", &
		"", "Entry Default Flag is Required", FALSE)	
This.of_AddValidationRule("active_flag", "EXPRESSION", &
		"<<entry_default_flag>> IN ('Y', 'N')", &
		"Entry Default Flag Must be Y or N", FALSE)		
			
// Set Defaults
This.of_setcolumndefault('active_flag','Y')
This.of_setcolumndefault('entry_default_flag','N')
This.of_setcolumndefault('add_user_id', gnv_app.of_getuserid())
This.of_setcolumndefault('add_datetime', 	"TODAY" )

end event

event bo_validate;call super::bo_validate;Integer	li_rc = 1
String	ls_desc

CHOOSE CASE as_column
	CASE 'entry_default_flag'
		IF as_value = 'Y' THEN
			SELECT TOP 1 description
			  INTO :ls_desc
			  FROM timesheet_status
			 WHERE timesheet_status <> :as_column
			   AND entry_default_flag = 'Y'
			 USING sqlca;
			CHOOSE CASE sqlca.sqlcode 
				CASE -1
					This.of_AddValidationError(al_row, as_column, Primary!, "Error counting timesheet status entries")
					RETURN -1
				CASE 0
					IF Not(IsNull(ls_desc)) THEN
						li_rc = -1
						This.of_AddValidationError(al_row, as_column, Primary!, ls_desc + " is already the default timesheet status.")
					END IF
			END CHOOSE
		END IF
END CHOOSE

RETURN 1
end event

