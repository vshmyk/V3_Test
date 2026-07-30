$PBExportHeader$n_bo_trade_union.sru
forward
global type n_bo_trade_union from n_cst_business_abio
end type
end forward

global type n_bo_trade_union from n_cst_business_abio
end type
global n_bo_trade_union n_bo_trade_union

type variables

n_bo_trade_union_rate	ibo_trade_union_rate
end variables

forward prototypes
public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status, boolean ab_saveas)
public function string of_get_trade_union_description (string as_book, string as_trade_union)
public function integer of_get_pay_period_type (string as_book, string as_trade_union, ref string as_pay_period_type)
public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message)
public function string of_get_staff_flag (string as_book, string as_trade_union)
public function integer of_find_cheques_for_union_effective_on (string as_union, string as_pay_period, date adt_effective_date, date adt_expiry_date)
end prototypes

public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status, boolean ab_saveas);//************************************************************
// Object:	n_bo_trade_union
// Method:	of_Renumber
// Author:	Paul Bauermeister
// Date:		2009/09/03
//
// Arg:		as_book - Book for value being renumbered
//				as_from_value - Current value being renumbered
//				as_to_value - New value to renumber to
//				REF ' s, - Message to return for display
//
// Return:	Integer - 1=Success, -1=Failure
//
// Desc:		Renumbers the specified from value into the specified 
//				to value
//
//************************************************************
// Modifications:
// Date			Author					Comments
//------------------------------------------------------------
// 2011.01.10	MDP		jira 1697 - renumber premium tables
//************************************************************

Integer							li_rc 
Long								ll_row
Long								ll_rows
Long								ll_err
String								ls_save_just_the_active_ones
s_parm								lstr_parm
n_bo_trade_union_remit_layout	lbo_trade_union_remit_layout
n_bo_trade_union_rate			lbo_trade_union_rate
n_bo_trade_union_premium		lbo_trade_union_premium
n_bo_trade_union_benefit		lbo_trade_union_benefit
n_bo_tm_trade_union_premium	lbo_tm_trade_union_premium
n_bo_occupation					lbo_occupation
n_bo_occupation_rate				lbo_occupation_rate
n_bo_tm_occupation_rate			lbo_tm_occupation_rate
n_bo_trade_union_job				lbo_trade_union_job
n_bo_trade_union_trade_level_rrsp_pension  	lbo_trade_union_trade_level_rrsp_pension
n_bo_trade_union_trade_level_employee_rrsp  	lbo_trade_union_trade_level_employee_rrsp
n_bo_trade_union_trade_level_shift_premium  	lbo_trade_union_trade_level_shift_premium
s_validation_error				lstr_validation_error[]
 
// Retrieve the From trade union record
ll_row = This.of_Retrieve("book = '" + as_book + "' AND trade_union = '" + as_from_value + "'")

IF ll_row > 0 THEN
	as_status.text = "Renumbering Trade Union"
	Yield()
	
	//Don't copy a bunch of stale dated effective rates
	//But anything from the current year might be useful for re-running old cheques
	IF ab_saveas THEN
		ls_save_just_the_active_ones = " AND expiry_date >= '" + String(Date(Year(Today()), 1, 1), 'yyyy.mm.dd') + "'"
	ELSE
		ls_save_just_the_active_ones = ''
	END IF
	
	// Modify the trade union record
	//Insert the new value
	This.of_SetItem(ll_row, "trade_union", as_to_value)
	IF ab_saveas THEN this.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	
	// Retrieve the child records and modify them
	// The child relationship must be defined in the constructor for this object
	IF This.of_GetChild("rate", lbo_trade_union_rate) = -1 THEN 
		as_message = "trade union rate is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild({"rate", "trade_union_premium"}, lbo_trade_union_premium)  = -1 THEN 
		as_message = "trade union premium is not defined as a child table"
		RETURN -1
	END IF 
	IF This.of_GetChild("tm_premium", lbo_tm_trade_union_premium)  = -1 THEN 
		as_message = "T/M trade union premium is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("remit_layout", lbo_trade_union_remit_layout)  = -1 THEN 
		as_message = "Trade Union Remit Layout is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("occupation", lbo_occupation)  = -1 THEN 
		as_message = "occupation is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("occupation_rate", lbo_occupation_rate)  = -1 THEN 
		as_message = "occupation_rate is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("tm_occupation_rate", lbo_tm_occupation_rate)  = -1 THEN 
		as_message = "tm_occupation_rate is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("benefit", lbo_trade_union_benefit)  = -1 THEN 
		as_message = "benefit is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("trade_union_job", lbo_trade_union_job)  = -1 THEN 
		as_message = "trade_union_job is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("trade_union_trade_level_rrsp_pension", lbo_trade_union_trade_level_rrsp_pension)  = -1 THEN 
		as_message = "trade_union_trade_level_rrsp_pension is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("trade_union_trade_level_employee_rrsp", lbo_trade_union_trade_level_employee_rrsp)  = -1 THEN 
		as_message = "trade_union_trade_level_employee_rrsp is not defined as a child table"
		RETURN -1
	END IF
	IF This.of_GetChild("trade_union_trade_level_shift_premium", lbo_trade_union_trade_level_shift_premium)  = -1 THEN 
		as_message = "trade_union_trade_level_shift_premium is not defined as a child table"
		RETURN -1
	END IF

	//References to the trade union will be renumbered, but not duplicated for the save as function
	IF Not ab_saveas THEN
		
		//Renumber billing items
		as_status.text = "Renumbering A/R daysheet billing items..."
		UPDATE ar_billing_item
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			of_msg_db_error('Error renumbering supervisor_job', this.itr_trans)
			RETURN -1
		END IF
		
		//employee
		as_status.text = "Renumbering Employee"
		UPDATE employee
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			this.of_msg_db_error('Error updating trade union on employee')
			RETURN -1
		END IF
		IF this.itr_trans.sqlnrows > 0 THEN  as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' Employees, ~n~r'
		
		UPDATE employee_time_summary
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			this.of_msg_db_error('Error updating trade union on employee')
			RETURN -1
		END IF
		IF this.itr_trans.sqlnrows > 0 THEN  as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' Employee time summary, ~n~r'
			
		//labour dispersion -- performance issues with business object
		as_status.text = "Renumbering Labour Dispersion"
		UPDATE labour_dispersion
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			this.of_msg_db_error('Error updating trade union on labour_dispersion')
			RETURN -1
		END IF
		IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' Labour Dispersions, ~n~r'
	
		//payroll cheque -- performance issues with business object
		as_status.text = "Renumbering P/R Cheque"
		UPDATE pr_cheque
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			this.of_msg_db_error('Error updating trade union on pr_cheque')
			RETURN -1
		END IF
		IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' P/R Cheques, ~n~r'
		UPDATE pr_cheque_occupation
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			this.of_msg_db_error('Error updating trade union on pr_cheque_occupation')
			RETURN -1
		END IF
		UPDATE pr_cheque_trade_union
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			this.of_msg_db_error('Error updating trade union on pr_cheque_trade_union')
			RETURN -1
		END IF
		
		//Renumber Web-Abio crew tables
		as_status.text = "Renumbering Web-Abio components..."
		UPDATE supervisor_job_employee
			SET trade_union = :as_to_value
		 WHERE trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			of_msg_db_error('Error renumbering supervisor_job_employee', this.itr_trans)
			RETURN -1
		END IF
		
		//timesheet -- large volume of timesheets precludes using business object for update
		as_status.text = "Renumbering Timesheet"
		UPDATE timesheet
			SET trade_union = :as_to_value
		 WHERE book 		 = :as_book
			AND trade_union = :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.sqlcode = -1 THEN
			this.of_msg_db_error('Error updating trade union on timesheet')
			RETURN -1
		END IF
		IF this.itr_trans.sqlnrows > 0 THEN as_message += String(this.itr_trans.sqlnrows, '#,##0') + ' Timesheets, ~n~r'

		//trade union remit layout
		as_status.text = "Renumbering Trade Union Remit Layout"
		ll_rows = lbo_trade_union_remit_layout.of_Retrieve("book = '" + as_book + &
				  "' AND (trade_union_1 = '" + as_from_value &
						  + "' OR trade_union_2 = '" + as_from_value &
						  + "' OR trade_union_3 = '" + as_from_value &
						  + "' OR trade_union_4 = '" + as_from_value &
						  + "' OR trade_union_5 = '" + as_from_value &
						  + "' OR trade_union_6 = '" + as_from_value &
						  + "' OR trade_union_7 = '" + as_from_value &
						  + "' OR trade_union_8 = '" + as_from_value &
						  + "' OR trade_union_9 = '" + as_from_value &
						  + "' OR trade_union_10 = '" + as_from_value &
						  + "')")
		
		FOR ll_row = 1 TO ll_rows
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_1') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_1", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_2') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_2", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_3') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_3", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_4') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_4", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_5') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_5", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_6') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_6", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_7') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_7", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_8') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_8", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_9') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_9", as_to_value)
			IF lbo_trade_union_remit_layout.of_GetItemString(ll_row, 'trade_union_10') = as_from_value THEN lbo_trade_union_remit_layout.of_SetItem(ll_row, "trade_union_1O", as_to_value)
		NEXT
		IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Remit Layouts, ~n~r'
		
	END IF
	
	//===================
	//  The remaining tables should be duplicated if the save as function is being invoked
	//===================
	
	//occupation
	as_status.text = "Renumbering Occupation"
	ll_rows = lbo_occupation.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'")
	
	FOR ll_row = 1 TO ll_rows
		lbo_occupation.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_occupation.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Occupations, ~n~r'
			
	//occupation rate
	as_status.text = "Renumbering Occupation Rate"
	ll_rows = lbo_occupation_rate.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)
	
	FOR ll_row = 1 TO ll_rows
		lbo_occupation_rate.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_occupation_rate.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Occupation Rates, ~n~r'
			
	//tm occupation rate
	as_status.text = "Renumbering T/M Occupation Rate"
	ll_rows = lbo_tm_occupation_rate.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)
	
	FOR ll_row = 1 TO ll_rows
		lbo_tm_occupation_rate.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_tm_occupation_rate.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' T/M Occupation Rates, ~n~r'
		
	//tm_trade_union_premium
	as_status.text = "Renumbering T/M Trade Union Premium"
	ll_rows = lbo_tm_trade_union_premium.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)
	
	FOR ll_row = 1 TO ll_rows
		lbo_tm_trade_union_premium.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_tm_trade_union_premium.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' T/M Trade Union Premiums, ~n~r'
	
	//trade union benefits
	as_status.text = "Renumbering Trade Union Benefit"
	ll_rows = lbo_trade_union_benefit.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)
	
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_benefit.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_trade_union_benefit.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Benefits, ~n~r'
	
	//trade union job
	as_status.text = "Renumbering Trade Union Jobs"
	ll_rows = lbo_trade_union_job.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)
	
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_job.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_trade_union_job.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Jobs, ~n~r'
		
	//trade union premiums
	as_status.text = "Renumbering Trade Union Premium"
	ll_rows = lbo_trade_union_premium.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)
	
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_premium.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_trade_union_premium.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Premiums, ~n~r'
	
	//trade_union_rate
	as_status.text = "Renumbering Trade Union Rate"
	ll_rows = lbo_trade_union_rate.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)	
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_rate.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_trade_union_rate.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Rates, ~n~r'	
	
	//trade_union_trade_level_employee_rrsp
	as_status.text = "Renumbering Trade Union Trade Rate Employee RRSP Rate"
	ll_rows = lbo_trade_union_trade_level_employee_rrsp.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)	
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_trade_level_employee_rrsp.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_trade_union_trade_level_employee_rrsp.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Trade Rate Employee RRSP Rates, ~n~r'	
	
	//trade_union_trade_level_rrsp_pension
	as_status.text = "Renumbering Trade Union Trade Level RRSP Pension"
	ll_rows = lbo_trade_union_trade_level_rrsp_pension.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)	
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_trade_level_rrsp_pension.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_trade_union_trade_level_rrsp_pension.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Trade Level RRSP Pension Rates, ~n~r'	
	
	//trade_union_trade_level_shift_premium
	as_status.text = "Renumbering Trade Union Trade Level Shift Premium"
	ll_rows = lbo_trade_union_trade_level_shift_premium.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_from_value + "'" + ls_save_just_the_active_ones)	
	FOR ll_row = 1 TO ll_rows
		lbo_trade_union_trade_level_shift_premium.of_SetItem(ll_row, "trade_union", as_to_value)
		IF ab_saveas THEN lbo_trade_union_trade_level_shift_premium.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Trade Union Trade Level Shift Premium, ~n~r'	
	
	as_status.text = "Trade union " + as_from_value + " has been renumbered to " + as_to_value
	
	// Update AND commit this business objects and all of its children (but don't validate)
	as_status.text = "Writing Updates... "
	li_rc = This.of_UpdateAll(FALSE, FALSE, lstr_validation_error)
	
	IF li_rc = 1 THEN
		
		//commit goes in the calling program, after the foreign keys have been reinstated
//		COMMIT USING this.itr_trans;
//		this.of_Commit()
		IF ab_saveas THEN
			as_message += "have been saved from " + as_from_value + " to " + &
					as_to_value
		ELSE
			as_message += "have been renumbered from " + as_from_value + " to " + &
					as_to_value
		END IF
	ELSE
		
		ROLLBACK USING this.itr_trans;
		this.of_Rollback()
		
		IF ab_saveas THEN
			as_message = "Error Saving trade union " + as_from_value + &
					" to " + as_to_value + ":"
		ELSE
			as_message = "Error Renumbering trade union " + as_from_value + &
					" to " + as_to_value + ":"
		END IF
		as_status.text = as_message
		
		FOR ll_err = 1 TO UpperBound(lstr_validation_error) 
			as_message += "~r~n~r~n" + gnv_app.of_format_validation_error(lstr_validation_error[ll_err])
		NEXT
	END IF
ELSE
	as_message = "Trade union " + as_from_value + " does not exist"
	as_status.text = as_message
END IF

RETURN 1

end function

public function string of_get_trade_union_description (string as_book, string as_trade_union);//************************************************************
// Object   :	n_bo_trade_union 
// Function :	of_trade_union_description
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	string as_book
// 				string as_trade_union
// 	
// Returns:		string
// 	
// Desc:			Retunrs Trade Union Description
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String 		ls_description
Long			ll_rc

IF IsNull(as_book) OR IsNull(as_trade_union) THEN
	ls_description = ""
ELSE
	ll_rc = This.of_retrieve("book = '" + as_book + "' and trade_union = '" + as_trade_union + "'")
	IF ll_rc > 0 THEN
		ls_description = This.of_GetItemString(ll_rc,"description")
	ELSE
		ls_description = ""
	END IF
END IF

RETURN ls_description
	
end function

public function integer of_get_pay_period_type (string as_book, string as_trade_union, ref string as_pay_period_type);//************************************************************
// Object   :	n_bo_trade_union 
// Function :	of_get_pay_period_type
// Author   :	Lourdes Garcia
// Date     :	2009/05/05
// 	
// Arguments:	string as_book
// 				string as_trade_union
// 				string as_pay_period_type REF
// 	
// Returns:		integer
// 	
// Desc:			-1 Error in retrieval; 0 Noting Retrieved; 1 Success;  Returns Pay Period Type as REF
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String 		ls_description
Long			ll_rc

IF IsNull(as_book) OR IsNull(as_trade_union) THEN
	SetNull(as_pay_period_type)
	RETURN -1
ELSE
	ll_rc = This.of_retrieve("book = '" + as_book + "' and trade_union = '" + as_trade_union + "'")
	IF ll_rc > 0 THEN
		as_pay_period_type = This.of_GetItemString(ll_rc,"pay_period_type")
		RETURN 1
	ELSE
		SetNull(as_pay_period_type)
		RETURN 0
	END IF
END IF


	
end function

public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message);//************************************************************
// Object:	n_bo_trade_union
// Method:	of_CheckRenumber
// Author:	Paul Bauermeister
// Date:		2009/09/03
//
// Arg:		as_book - Book for value being renumbered
//				as_from_value - Current value being renumbered
//				as_to_value - New value to renumber to
//				REF as_message - Message to return for display
//
// Return:	Integer - 1=Renumber Allowed, -1=Renumber Not Allowed
//
// Desc:		Determines whether the specified from value is allowed 
//				to be renumbered (or merged) into the specified to 
//				value
//
//************************************************************
// Modifications:
// Date			Author					Comments
//------------------------------------------------------------
// 
//************************************************************

Integer	li_rc = -1
Long		ll_row

// Check that the from value exists
ll_row = This.of_Retrieve("book = '" + as_book + &
		"' AND trade_union = '" + as_from_value + "'")

IF ll_row > 0 THEN
	// Check that the to value does NOT exist (merges are not allowed 
	// for trade union records)
	ll_row = This.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + as_to_value + "'")
	
	IF ll_row = 0 THEN
		li_rc = 1
		as_message = "Trade union " + as_from_value + " will be renumbered to " + &
				as_to_value
	ELSE
		as_message = "Trade union " + as_to_value + " already exists"
	END IF
ELSE
	as_message = "Trade union " + as_from_value + " does not exist"
END IF

RETURN li_rc

end function

public function string of_get_staff_flag (string as_book, string as_trade_union);//************************************************************
// Object   :	n_bo_trade_union 
// Function :	of_get_staff_flag
// Author   :	Lourdes Garcia
// Date     :	2009/10/16
// 	
// Arguments:	string as_book
// 				string as_trade_union
// 	
// Returns:		string
// 	
// Desc:			Returns staff flag
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String 		ls_staff
Long			ll_rc

IF IsNull(as_book) OR IsNull(as_trade_union) THEN
	ls_staff = ""
ELSE
	ll_rc = This.of_retrieve("book = '" + as_book + "' and trade_union = '" + as_trade_union + "'")
	IF ll_rc > 0 THEN
		ls_staff = This.of_GetItemString(ll_rc,"staff_flag")
	ELSE
		ls_staff = ""
	END IF
END IF

RETURN ls_staff
	
end function

public function integer of_find_cheques_for_union_effective_on (string as_union, string as_pay_period, date adt_effective_date, date adt_expiry_date);//************************************************************
// Object   :	n_bo_trade_union 
// Function :	of_find_cheques_for_union_effective_on
// Author   :	Monica Petersen
// Date     :	2017/10/21
// 	
// Arguments:	string as_union
// 				string as_pay_period
// 				date adt_effective_date
// 				date adt_expiry_date
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

Integer 	li_rc
Decimal	ldec_net_pay
String	ls_union
Integer	li_pay_interval

li_rc = 0

li_pay_interval = 6

CHOOSE CASE as_pay_period
	CASE "B"
		li_pay_interval = 13
	CASE "W"
		li_pay_interval = 6
	CASE "S"
		li_pay_interval = 14
	CASE "M"
		li_pay_interval = 30
END CHOOSE


SELECT IsNull(SUM(net_pay), 0) INTO :ldec_net_pay
FROM pr_cheque 
WHERE book = :gnv_app.is_book AND 
		trade_union = :as_union AND DateAdd(day, :li_pay_interval, pay_period_start_date) BETWEEN :adt_effective_date AND :adt_expiry_date
USING SQLCA;

IF SQLCA.SQLCODE <> 0 THEN
	li_rc = -1
ELSE
	IF ldec_net_pay <> 0 THEN
		li_rc = -2
	END IF
END IF

RETURN li_rc
end function

on n_bo_trade_union.create
call super::create
end on

on n_bo_trade_union.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object:	n_bo_trade_union
// Method:	Constructor
// Author:	Dean Schindell
// Date:		2009/04/17
//
// Arg:		None
//
// Return:	Long
//
// Desc:		Initialises the business object
//
//************************************************************
// Modifications:
// Date			Author					Comments
//------------------------------------------------------------
// 2011.01.10	MDP		jira 1697 - add renumbering for premiums
//************************************************************

// Set the object description to be seen in messages to user
This.of_SetDescription("Trade Union")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_trade_union"

// Set primary key columns
This.of_SetPKColumns({"book","trade_union"})

// Validation Rules
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Book is Required", TRUE)
This.of_AddValidationRule({"trade_union"}, "REQUIRED", &
		"", "Trade Union is Required", TRUE)
This.of_AddValidationRule({"description"}, "REQUIRED", &
		"", "Description is Required", TRUE)
This.of_AddValidationRule({"book", "trade_union"}, "UNIQUE", &
		"", "Trade Union Must be Unique within Book", FALSE)
This.of_AddValidationRule("pay_period_type", "EXPRESSION", &
		"<<pay_period_type>> IN ('B','M','S','W')", &
		"Pay Period Type Must be B, M, S or W", FALSE)
This.of_AddValidationRule({"gl_account"}, "REQUIRED", &
		"", "G/L Account is Required", TRUE)
This.of_AddValidationRule("staff_flag", "EXPRESSION", &
		"<<staff_flag>> IN ('Y', 'N')", &
		"Staff Flag Must be Y or N", FALSE)
This.of_AddValidationRule("dues_on_t4_flag", "EXPRESSION", &
		"<<dues_on_t4_flag>> IN ('Y', 'N')", &
		"Dues On T4 Flag Must be Y or N", FALSE)
This.of_AddValidationRule("hours_on_ck_flag", "EXPRESSION", &
		"<<hours_on_ck_flag>> IN ('Y', 'N')", &
		"Hours On CK Flag Must be Y or N", FALSE)
This.of_AddValidationRule("active_flag", "EXPRESSION", &
		"<<active_flag>> IN ('Y', 'N')", &
		"Active Flag Must be Y or N", FALSE)
This.of_AddValidationRule("vacation_owed_at_current_rate_flag", "EXPRESSION", &
		"<<vacation_owed_at_current_rate_flag>> IN ('Y', 'N')", &
		"Staff Vacation $ Owed at Current Rate Flag Must be Y or N", FALSE)

This.of_AddValidationRule("include_site_allow_in_empr_rrsp_flag", "EXPRESSION", &
		"<<include_site_allow_in_empr_rrsp_flag>> IN ('Y', 'N')", &
		"include site allowance in calculation? Must be Y or N", FALSE)

This.of_AddValidationRule("change_allowed_on_ck_empr_rrsp_flag", "EXPRESSION", &
		"<<change_allowed_on_ck_empr_rrsp_flag>> IN ('Y', 'N')", &
		"allow Change action? Must be Y or N", FALSE)

This.of_AddValidationRule("standard_email_flag", "EXPRESSION", &
		"<<standard_email_flag>> IN ('Y', 'N')", &
		"Standard email? Must be Y or N", FALSE)

/*
This.of_AddValidationRule("occupation_weekly_dues_flag", "EXPRESSION", &
		"<<occupation_weekly_dues_flag>> IN ('Y', 'N')", &
		"Occupation Weekly Dues Flag Must be Y or N", FALSE)
This.of_AddValidationRule("occupation_rrsp_pension_flag", "EXPRESSION", &
		"<<occupation_rrsp_pension_flag>> IN ('Y', 'N')", &
		"Occupation RRSP/Pension Flag Must be Y or N", FALSE)
*/


// Default values
//This.of_SetColumnDefault("occupation_weekly_dues_flag", "N")
//This.of_SetColumnDefault("occupation_rrsp_pension_flag", "N")
This.of_SetColumnDefault("book", gnv_app.is_book)
This.of_SetColumnDefault("show_premiums_on_ck_flag", "N")

This.of_SetColumnDefault("staff_flag", "N")
This.of_SetColumnDefault("dues_on_t4_flag", "Y")
This.of_SetColumnDefault("hours_on_ck_flag", "N")
This.of_SetColumnDefault("active_flag", "Y")
This.of_SetColumnDefault("track_vacation_hours_owed_flag", "N")
This.of_SetColumnDefault("vacation_owed_at_current_rate_flag", "N")
This.of_SetColumnDefault("include_site_allow_in_empr_rrsp_flag", "N")
This.of_SetColumnDefault("change_allowed_on_ck_empr_rrsp_flag", "N")
This.of_SetColumnDefault("tah_multiplier", "1")
This.of_SetColumnDefault("ovr_multiplier", "1")

// Add child object
This.of_AddChild("tm_premium", 			"n_bo_tm_trade_union_premium") 		//jira 1697
This.of_AddChild("rate", 					"n_bo_trade_union_rate")
This.of_AddChild("occupation", 			"n_bo_occupation")
This.of_AddChild("benefit",	 			"n_bo_trade_union_benefit")
This.of_AddChild("trade_union_job",		"n_bo_trade_union_job")
This.of_AddChild("trade_union_trade_level_rrsp_pension",		"n_bo_trade_union_trade_level_rrsp_pension")
This.of_AddChild("trade_union_trade_level_employee_rrsp",	"n_bo_trade_union_trade_level_employee_rrsp")
This.of_AddChild("trade_union_trade_level_shift_premium",	"n_bo_trade_union_trade_level_shift_premium")
This.of_AddChild("remit_layout",			"n_bo_trade_union_remit_layout")
This.of_AddChild("occupation_rate",		"n_bo_occupation_rate")
This.of_AddChild("tm_occupation_rate",	"n_bo_tm_occupation_rate")

//Don't need to define these because they are determined by looking at the children for 
//the occupation business object:
//This.of_AddChild("employee", 			"n_bo_employee")
//This.of_AddChild("occupation_rate", 	"n_bo_occupation_rate")
//This.of_AddChild("tm_rate", 			"n_bo_tm_occupation_rate")

// Add DB Constraints
// Arg:		as_constraint 	- Constraint name
//				as_column 		- Column to receive focus if constraint fails
//				as_message 		- Message to display if constraint fails
//				as_ref_table 	- Table referenced by constraint if foreign key
This.of_AddDBConstraint("pk_trade_union", "trade_union", "Trade Union", "")
This.of_AddDBConstraint("fk_trade_union__trade_description", 	/* Constraint name */ 					&
		"trade", 																/* Column to receive focus if constraint fails */ 	&
		"Trade not found", 													/* Message to display if constraint fails */			&
		"trade_description") 												/* Table referenced by constraint if foreign key */
This.of_AddDBConstraint("fk_trade_union__trade", "trade_union", &
		"Trade Union", "Book")
This.of_AddDBConstraint("fk_trade_union_rate__trade_union", "trade_union", &
		"Trade Union", "Trade Union Rate")
This.of_AddDBConstraint("fk_trade_union_premium__trade_union", "trade_union", &
		"Trade Union", "Trade Union Premium")	//jira 1697
This.of_AddDBConstraint("fk_occupation__trade_union", "trade_union", &
		"Trade Union", "Occupation")
This.of_AddDBConstraint("fk_pr_cheque__trade_union", "trade_union", &
		"Trade Union", "P/R Cheque")
This.of_AddDBConstraint("fk_gl_account__book_gl_account", "gl_account", &
		"G/L Account not found in Book-G/L Account", "Book-G/L Account")	

// This covers 10 F/K constraints
This.of_AddDBConstraint("fk_trade_union_remit_layout__trade_union", "trade_union", &
		"Trade Union", "Trade Union Remit Layout")

This.of_AddDBConstraint("cc_trade_union__gl_account", "gl_account", &
"Account not setup for the current fiscal year in the G/L account table", "Union")

end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_trade_union 
// Event    :	bo_validate
// Author   :	Dean Schindell
// Date     :	2009/04/18
// 	
// Arguments:	long al_row
// 				string as_column
// 				string as_value
// 	
// Returns:		integer
// 	
// Desc:			Advanced Validation
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer				li_rc = 1
Long					ll_row, ll_tur_row, ll_tur_rows
String				ls_pr_year
n_bo_company		lbo_company
n_bo_pay_period	lbo_pay_period

IF as_column = "pay_period_type" THEN
	// Ensure that the pay period exists for the current company's payroll year
	lbo_company = CREATE n_bo_company
	lbo_company.of_SetTransaction()
	
	ll_row = lbo_company.of_Retrieve("book = '" + gnv_app.of_get_book() + "'")
	
	IF ll_row > 0 THEN
		ls_pr_year = Left(lbo_company.of_GetItemString(1, "pr_yyyymm"), 4)
		
		lbo_pay_period = CREATE n_bo_pay_period
		lbo_pay_period.of_SetTransaction()
		
		ll_row = lbo_pay_period.of_Retrieve("year = '" + ls_pr_year + "'")
		
		IF ll_row < 1 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Pay Period Type " + as_value + " is not set up for " + ls_pr_year)
		END IF
	ELSE
		li_rc = -1
		This.of_AddValidationError(al_row, as_column, Primary!, "Missing Company Record for " + gnv_app.of_get_book())
	END IF
END IF

IF as_column = "staff_flag" AND as_value = 'Y' THEN
	// Ensure that vacation pay type is 'H'ourly earnings for staff unions
	
	IF Not(IsValid(ibo_trade_union_rate)) THEN
		ibo_trade_union_rate = CREATE n_bo_trade_union_rate
		ibo_trade_union_rate.of_SetTransaction()
	END IF
	
	ll_tur_rows = ibo_trade_union_rate.of_Retrieve("book = '" + gnv_app.of_get_book() + "' AND trade_union = '" + this.of_GetItemString(al_row, 'trade_union') + "'")
	
	FOR ll_tur_row = 1 TO ll_tur_rows 
		IF ibo_trade_union_rate.of_GetItemString(ll_tur_row, "vacation_pay_type") <> 'H' THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Rates effective on " &
							+ String(ibo_trade_union_rate.of_GetItemDateTime(ll_tur_row, 'effective_date'), 'yyyy.mm.dd') &
							+ " use vacation pay type " + ibo_trade_union_rate.of_GetItemString(ll_tur_row, "vacation_pay_type") &
							+ ". This is not valid for staff unions.  Staff? must be N")
		END IF
		
		IF ibo_trade_union_rate.of_GetItemString(ll_tur_row, "statutory_pay_type") <> 'H' THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Rates effective on " &
							+ String(ibo_trade_union_rate.of_GetItemDateTime(ll_tur_row, 'effective_date'), 'yyyy.mm.dd') &
							+ " use statutory pay type " + ibo_trade_union_rate.of_GetItemString(ll_tur_row, "statutory_pay_type") &
							+ ". This is not valid for staff unions.  Staff? must be N")
		END IF
	NEXT
	
END IF

IF IsValid(lbo_company) THEN DESTROY lbo_company
IF IsValid(lbo_pay_period) THEN DESTROY lbo_pay_period

RETURN li_rc


end event

event bo_rowinserted;call super::bo_rowinserted;//************************************************************
// Object   :	n_bo_trade_union 
// Event    :	bo_rowinserted
// Author   :	Dean Schindell
// Date     :	2009/04/18
// 	
// Arguments:	long al_row
// 	
// Returns:		(None)
// 	
// Desc:			Set default values
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long				ll_row
Integer			li_weekly_pay_period_start
n_bo_company	lbo_company

lbo_company = CREATE n_bo_company
lbo_company.of_SetTransaction()

ll_row = lbo_company.of_Retrieve("book = '" + gnv_app.of_get_book() + "'")

IF ll_row > 0 THEN
	li_weekly_pay_period_start = lbo_company.of_GetItemNumber(1, "weekly_pay_period_start")
	
	IF li_weekly_pay_period_start <> 0 THEN
		This.of_SetItem(al_row, "pay_period_type", "W")
	ELSE
		This.of_SetItem(al_row, "pay_period_type", "B")
	END IF
END IF

end event

event bo_postupdate;call super::bo_postupdate;//************************************************************
// Object   :	n_bo_trade_union 
// Event    :	bo_postupdate
// Author   :	Paul Bauermeister
// Date     :	2009/09/09
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Check everywhere an account can be used as a control 
//					account
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer					li_rc
Integer					li_items
Integer					li_index
Integer					li_forms
String					ls_action
Long						ll_row
u_dw_business			ldw_business[]
u_dw_business_form	ldw_form
u_dw_business_form	ldw_forms[]
DWItemstatus			dis_status
n_bo_standard_gl_account	lbo_standard_gl_account

dis_status = of_GetItemStatus(1, 'gl_account', Primary!)
ll_row = This.of_rowcount()

ls_action = '?'



li_rc = 1 

This.of_GetShared(ldw_business)

li_items = UpperBound(ldw_business)

FOR li_index = 1 TO li_items
	// Cast the datawindow to a form datawindow type, if this works 
	// then we have a valid type to send a message to
	TRY
		ldw_form = ldw_business[li_index]
		li_forms ++
		ldw_forms[li_forms] = ldw_form
	CATCH (Throwable lth_exception)
	END TRY
NEXT
	
IF li_forms > 0 THEN
	//Data entry form will have an action field
	IF ll_row  > 0 THEN
		ls_action = This.of_getitemstring(1, "action") 
	END IF
ELSEIF this.of_DeletedCount() > 0 THEN
	//business object is being updated directly
	ls_action = 'D'
END IF

IF dis_status = DataModified! OR ls_action = 'D' THEN
	lbo_standard_gl_account = CREATE n_bo_standard_gl_account
	lbo_standard_gl_account.of_SetTransaction(sqlca)
	IF li_forms > 0 THEN
		li_rc = lbo_standard_gl_account.of_reset_gl_control_accounts(ldw_forms, "BLUE")
//	ELSE	/* best just to do this from the screen.  It was being triggered on renumbering, and causing locking errors
//		li_rc = lbo_standard_gl_account.of_reset_gl_control_accounts()
	END IF
	DESTROY lbo_standard_gl_account
END IF

RETURN li_rc

end event

event destructor;call super::destructor;//************************************************************
// Object   :	n_bo_trade_union 
// Event    :	destructor
// Author   :	Monica Petersen
// Date     :	2013/11/27
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

IF IsValid(ibo_trade_union_rate) THEN DESTROY ibo_trade_union_rate

RETURN 1

end event

