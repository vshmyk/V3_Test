$PBExportHeader$n_bo_premium_type.sru
forward
global type n_bo_premium_type from n_cst_business_abio
end type
end forward

global type n_bo_premium_type from n_cst_business_abio
end type
global n_bo_premium_type n_bo_premium_type

forward prototypes
public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message)
public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status)
end prototypes

public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message);//************************************************************
// Object   :	n_bo_premium_type 
// Function :	of_checkrenumber
// Author   :	Lourdes Garcia
// Date     :	2012/02/27
// 	
// Arguments:	string as_book
// 				string as_from_value
// 				string as_to_value
// 				string as_message
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

Integer	li_rc = -1
Long		ll_row

// Check that the from value exists
ll_row = This.of_Retrieve("premium_type = '" + as_from_value + "'")

IF ll_row > 0 THEN
	// Check that the to value does NOT exist (merges are not allowed 
	// for premium_type records)
	ll_row = This.of_Retrieve("premium_type = '" + as_to_value + "'")
	
	IF ll_row = 0 THEN
		li_rc = 1
		as_message = "Premium " + as_from_value + " will be renumbered to " + &
				as_to_value
	ELSE
		as_message = "Premium " + as_to_value + " already exists"
	END IF
ELSE
	as_message = "Premium " + as_from_value + " does not exist"
END IF

RETURN li_rc

end function

public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status);//************************************************************
// Object   :	n_bo_premium_type 
// Function :	of_renumber
// Author   :	Lourdes Garcia
// Date     :	2012/02/27
// 	
// Arguments:	string as_book
// 				string as_from_value
// 				string as_to_value
// 				string as_message
// 	
// Returns:		integer
// 	
// Desc:			Renumbers from a specied from value to a specified to_value
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String							ls_trade_union
Long								ll_row
Long								ll_rows
n_bo_trade_union_premium	lbo_trade_union_premium
n_bo_employee_premium		lbo_employee_premium
//n_bo_timesheet_premium		lbo_timesheet_premium
//n_bo_labour_dispersion_premium		lbo_labour_dispersion_premium
//n_bo_pr_cheque_premium					lbo_pr_cheque_premium
//n_bo_tm_employee_premium				lbo_tm_employee_premium

s_validation_error			lstr_validation_error[]

as_message = ''

// Retrieve the From premium_type record
ll_row = This.of_Retrieve("premium_type = '" + as_from_value + "'")

IF ll_row > 0 THEN
	
	// Modify the premium_type record
	This.of_SetItem(ll_row, "premium_type", as_to_value)
	
	
	// Retrieve the child records and modify them
	This.of_GetChild({"trade_union_premium"}, lbo_trade_union_premium)
	This.of_GetChild({"employee_premium"}, lbo_employee_premium)
//	This.of_GetChild({"timesheet_premium"}, lbo_timesheet_premium)
//	This.of_GetChild({"labour_dispersion_premium"},lbo_labour_dispersion_premium)
//	This.of_GetChild({"pr_cheque_premium"},lbo_pr_cheque_premium)
//	This.of_GetChild({"tm_employee_premium"},lbo_tm_employee_premium)

	
	
	ll_rows = lbo_trade_union_premium.of_Retrieve("premium_type = '" + as_from_value + "'")
	
	// Trade Unions
	as_status.text = 'Renumbering Trade Unions'
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_premium.of_SetItem(ll_row, "premium_type", as_to_value)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Unions, ~n~r'
	
	
	// Employee Premiums
	as_status.text = 'Renumbering Employee Premiums'
//	ll_rows = lbo_employee_premium.of_Retrieve("premium_type = '" + as_from_value + "'")
//	FOR ll_row = 1 TO ll_rows
//		lbo_employee_premium.of_SetItem(ll_row, "premium_type", as_to_value)
//	NEXT
	UPDATE employee_premium
		SET premium_type = :as_to_value
	 WHERE premium_type = :as_from_value
	 USING this.itr_trans;
	IF this.itr_trans.sqlcode <> 0 THEN
		this.of_msg_db_error("Error renumbering Employee Premiums")
		RETURN -1
	END IF
	IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' Employee Premiums, ~n~r'
	
	// Timesheet Premiums
	as_status.text = 'Renumbering Timesheet Premiums'
//	ll_rows = lbo_timesheet_premium.of_Retrieve("premium_type = '" + as_from_value + "'")	
//	FOR ll_row = 1 TO ll_rows
//		lbo_timesheet_premium.of_SetItem(ll_row, "premium_type", as_to_value)
//	NEXT
//	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Timesheet Premiums, ~n~r'
	UPDATE timesheet_premium
		SET premium_type = :as_to_value
	 WHERE premium_type = :as_from_value
	 USING this.itr_trans;
	IF this.itr_trans.sqlcode <> 0 THEN
		this.of_msg_db_error("Error renumbering timesheet")
		RETURN -1
	END IF
	IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' Timesheet Premiums, ~n~r'
	

	// Labour Dispersion Premiums
	as_status.text = 'Renumbering Labour Dispersion Premiums'
//	ll_rows = lbo_labour_dispersion_premium.of_Retrieve("premium_type = '" + as_from_value + "'")
//	FOR ll_row = 1 TO ll_rows
//		lbo_labour_dispersion_premium.of_SetItem(ll_row, "premium_type", as_to_value)
//	NEXT
//	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Labour Dispersion Premiums, ~n~r'
	UPDATE labour_dispersion_premium
		SET premium_type = :as_to_value
	 WHERE premium_type = :as_from_value
	 USING this.itr_trans;
	IF this.itr_trans.sqlcode <> 0 THEN
		this.of_msg_db_error("Error renumbering Labour Dispersion Premiums")
		RETURN -1
	END IF
	IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' Labour Dispersion Premiums, ~n~r'

	// P/R Cheque Premiums
	as_status.text = 'Renumbering P/R Cheque Premiums'
//	ll_rows = lbo_pr_cheque_premium.of_Retrieve("premium_type = '" + as_from_value + "'")	
//	FOR ll_row = 1 TO ll_rows
//		lbo_pr_cheque_premium.of_SetItem(ll_row, "premium_type", as_to_value)
//	NEXT
//	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' P/R Cheque Premiums, ~n~r'
	UPDATE pr_cheque_premium
		SET premium_type = :as_to_value
	 WHERE premium_type = :as_from_value
	 USING this.itr_trans;
	IF this.itr_trans.sqlcode <> 0 THEN
		this.of_msg_db_error("Error renumbering P/R Cheque Premiums")
		RETURN -1
	END IF
	IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' P/R Cheque Premiums, ~n~r'


	// T/M Employee Premiums
	as_status.text = 'Renumbering T/M Employee Premiums'
//	ll_rows = lbo_tm_employee_premium.of_Retrieve("premium_type = '" + as_from_value + "'")	
//	FOR ll_row = 1 TO ll_rows
//		lbo_tm_employee_premium.of_SetItem(ll_row, "premium_type", as_to_value)
//	NEXT
//	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Employee Premiums, ~n~r'
	UPDATE tm_employee_premium
		SET premium_type = :as_to_value
	 WHERE premium_type = :as_from_value
	 USING this.itr_trans;
	IF this.itr_trans.sqlcode <> 0 THEN
		this.of_msg_db_error("Error renumbering T/M Employee Premiums")
		RETURN -1
	END IF
	IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' T/M Employee Premiums, ~n~r'

	
	// Update but don't commit this business objects and all of its children
	//  *** commit handled in calling routine, after constraints are restored ***
	as_status.text = 'Writing Updates'
	
	IF This.of_UpdateAll(FALSE, FALSE, lstr_validation_error) = 1 THEN
		as_message += "have been renumbered from " + as_from_value + " to " + &
				as_to_value
	ELSE
		this.of_Rollback()
		as_message = "Error renumbering premium " + as_from_value + &
				" to " + as_to_value
		
		IF UpperBound(lstr_validation_error) > 0 THEN
			as_message += ":~r~n~r~n" + lstr_validation_error[1].s_message
		END IF
		RETURN -1
	END IF
ELSE
	as_message = "Premium " + as_from_value + " does not exist"
	RETURN -1
END IF

as_status.text = 'Premium ' + as_from_value + " renumbered."

RETURN 1
end function

on n_bo_premium_type.create
call super::create
end on

on n_bo_premium_type.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_premium_type 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2010/09/22
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
This.of_SetDescription("S/T Premium Type")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_premium_type"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({"premium_type"})

// Add Validation Rules

//Premium Type
This.of_AddValidationRule({"premium_type"}, "UNIQUE", &
		"", "Premium Type must be Unique", FALSE)
	
//Description		
This.of_AddValidationRule({"description"}, "REQUIRED", &
		"", "Description is Required", FALSE)	

//Time and a Half Multiplier Flag
This.of_AddValidationRule({"overtime_hour_flag"}, "REQUIRED", &
		"", "Time and a Half Multiplier Flagg is Required", FALSE)	
This.of_AddValidationRule("overtime_hour_flag", "EXPRESSION", &
		"<<overtime_hour_flag>> IN ('Y', 'N')", &
		"Time and a Half Multiplier Flag Must be Y or N", FALSE)		
		
//Overtime Multiplier Flag
This.of_AddValidationRule({"overtime_multiplier_flag"}, "REQUIRED", &
		"", "Overtime Multiplier Flag is Required", FALSE)	
This.of_AddValidationRule("overtime_multiplier_flag", "EXPRESSION", &
		"<<overtime_multiplier_flag>> IN ('Y', 'N')", &
		"Overtime Multiplier Flag Must be Y or N", FALSE)		
		
//Vacation Earning Flag
This.of_AddValidationRule({"holiday_earn_flag"}, "REQUIRED", &
		"", "Holiday Earning Flag is Required", FALSE)	
This.of_AddValidationRule("holiday_earn_flag", "EXPRESSION", &
		"<<holiday_earn_flag>> IN ('Y', 'N')", &
		"Holiday Earning Flag Must be Y or N", FALSE)		
		
//Dues Earning Flag
This.of_AddValidationRule({"dues_earn_flag"}, "REQUIRED", &
		"", "Dues Earning Flag is Required", FALSE)	
This.of_AddValidationRule("dues_earn_flag", "EXPRESSION", &
		"<<dues_earn_flag>> IN ('Y', 'N')", &
		"Dues Earning Flag Must be Y or N", FALSE)		
		
//RRSP Earning Flag
This.of_AddValidationRule({"rrsp_earn_flag"}, "REQUIRED", &
		"", "RRSP Earning Flag is Required", FALSE)	
This.of_AddValidationRule("rrsp_earn_flag", "EXPRESSION", &
		"<<rrsp_earn_flag>> IN ('Y', 'N')", &
		"RRSP Earning Flag Must be Y or N", FALSE)		
		
//Pension Earning Flag
This.of_AddValidationRule({"pension_earn_flag"}, "REQUIRED", &
		"", "Pension Earning Flag is Required", FALSE)	
This.of_AddValidationRule("pension_earn_flag", "EXPRESSION", &
		"<<pension_earn_flag>> IN ('Y', 'N')", &
		"Pension Earning Flag Must be Y or N", FALSE)		
		
//Shift 2 Flag
This.of_AddValidationRule({"shift_2_flag"}, "REQUIRED", &
		"", "Shift 2 Only Flag is Required", FALSE)	
This.of_AddValidationRule("shift_3_flag", "EXPRESSION", &
		"<<shift_2_flag>> IN ('Y', 'N')", &
		"Shift 2 Only Flag Must be Y or N", FALSE)		
		
//Shift 3 Flag
This.of_AddValidationRule({"shift_3_flag"}, "REQUIRED", &
		"", "Shift 3 Only Flag is Required", FALSE)	
This.of_AddValidationRule("shift_3_flag", "EXPRESSION", &
		"<<shift_3_flag>> IN ('Y', 'N')", &
		"Shift 3 Only Flag Must be Y or N", FALSE)		
		
//Employee Specific Flag
This.of_AddValidationRule({"employee_specific_flag"}, "REQUIRED", &
		"", "Employee Specific Flag is Required", FALSE)	
This.of_AddValidationRule("employee_specific_flag", "EXPRESSION", &
		"<<employee_specific_flag>> IN ('Y', 'N')", &
		"Employee Specific Flag Must be Y or N", FALSE)		

//Timesheet Override Flag
This.of_AddValidationRule({"timesheet_override_flag"}, "REQUIRED", &
		"", "Timesheet Override Flag is Required", FALSE)	
This.of_AddValidationRule("timesheet_override_flag", "EXPRESSION", &
		"<<timesheet_override_flag>> IN ('Y', 'N')", &
		"Timesheet Override Flag Must be Y or N", FALSE)		

//Active Flag
This.of_AddValidationRule({"active_flag"}, "REQUIRED", &
		"", "Active Flag is Required", FALSE)	
This.of_AddValidationRule("active_flag", "EXPRESSION", &
		"<<active_flag>> IN ('Y', 'N')", &
		"Active Flag Must be Y or N", FALSE)		
			
// Set Defaults
This.of_setcolumndefault('active_flag','Y')
This.of_setcolumndefault('overtime_hour_flag','N')
This.of_setcolumndefault('overtime_multiplier_flag','N')
This.of_setcolumndefault('dues_earn_flag','N')
This.of_setcolumndefault('holiday_earn_flag','N')
This.of_setcolumndefault('rrsp_earn_flag','N')
This.of_setcolumndefault('pension_earn_flag','N')
This.of_setcolumndefault('shift_2_flag','N')
This.of_setcolumndefault('shift_3_flag','N')
This.of_setcolumndefault('employee_specific_flag','N')
This.of_setcolumndefault('timesheet_override_flag','N')

// Add child objects
This.of_AddChild("trade_union_premium", "n_bo_trade_union_premium")
This.of_AddChild("employee_premium", "n_bo_employee_premium")
This.of_AddChild("pr_cheque_premium", "n_bo_pr_cheque_premium")
This.of_AddChild("labour_dispersion_premium", "n_bo_labour_dispersion_premium")
This.of_AddChild("timesheet_premium", "n_bo_timesheet_premium")
This.of_AddChild("tm_employee_premium", "n_bo_tm_employee_premium")


RETURN

		

end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_premium_type 
// Event    :	bo_validate
// Author   :	Lourdes Garcia
// Date     :	2011/09/27
// 	
// Arguments:	long al_row
// 				string as_column
// 				string as_value
// 	
// Returns:		integer
// 	
// Desc:			Other validations
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


n_bo_employee_premium			lbo_employee_premium
String								ls_premium_type
Integer								li_rc = 1



IF al_row > 0 THEN
	CHOOSE CASE as_column
		
		CASE "employee_specific_flag"
				IF NOT IsValid(lbo_employee_premium) THEN
					lbo_employee_premium = CREATE n_bo_employee_premium
					lbo_employee_premium.of_SetTransaction()
				END IF
				
				ls_premium_type  = This.of_GetItemString(al_row,"premium_type")
				
				IF lbo_employee_premium.of_count(" premium_type = '" + ls_premium_type + "'") > 0 AND (as_value = 'N') THEN
						li_rc = -1
						This.of_AddValidationError(al_row, as_column, Primary!, "There are employee premiums.  Applies to should be 'specific employees'")
				END IF
		END CHOOSE			
END IF
	
IF IsValid(lbo_employee_premium) THEN DESTROY lbo_employee_premium	

RETURN li_rc
end event

event bo_prerowdelete;call super::bo_prerowdelete;//************************************************************
// Object   :	n_bo_premium_type 
// Event    :	bo_prerowdelete
// Author   :	Lourdes Garcia
// Date     :	2011/09/28
// 	
// Arguments:	long al_row
// 	
// Returns:		boolean
// 	
// Desc:			Disallow Delete if premium is in any set of trade union books
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

n_bo_trade_union_premium 	lbo_trade_union_premium
Boolean							lb_flag = TRUE
String							ls_premium_type

IF NOT IsValid(lbo_trade_union_premium) THEN
	lbo_trade_union_premium = CREATE n_bo_trade_union_premium
	lbo_trade_union_premium.of_SetTransaction(SQLCA)
END IF	


IF al_row > 0 THEN
	 ls_premium_type = This.of_GetItemString(al_row, "premium_type")
	 IF lbo_trade_union_premium.of_count("premium_type = '" + ls_premium_type + "'") > 0 THEN
			This.of_AddValidationError(al_row, "premium_type", Primary!, "Record cannot be deleted. Premium is in Trade Union.")
			lb_flag = FALSE
	 END IF
END IF	 

IF IsValid(lbo_trade_union_premium) THEN DESTROY lbo_trade_union_premium

RETURN lb_flag
end event

