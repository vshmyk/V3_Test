$PBExportHeader$n_bo_occupation.sru
forward
global type n_bo_occupation from n_cst_business_abio
end type
end forward

global type n_bo_occupation from n_cst_business_abio
end type
global n_bo_occupation n_bo_occupation

type variables

boolean	ib_validate_delete = TRUE
end variables

forward prototypes
public function string of_get_occupation_desciption (string as_book, string as_trade_union, string as_occupation)
public function string of_get_occupation_description_min (string as_book, string as_trade_union)
public function integer of_get_trade_level (string as_book, string as_trade_union, string as_occupation, ref string as_trade, ref string as_level)
public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message)
public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status)
end prototypes

public function string of_get_occupation_desciption (string as_book, string as_trade_union, string as_occupation);//************************************************************
// Object   :	n_bo_occupation 
// Function :	of_get_occupation_desciption
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	string as_book
// 				string as_trade_union
// 				string as_occupation
// 	
// Returns:		integer
// 	
// Desc:			Returns Occupation Description
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_description
Long		ll_rc

IF IsNull(as_book) OR &
   IsNull(as_trade_union) OR &
	IsNull(as_occupation) THEN
	ls_description = ""
ELSE
	ll_rc = of_retrieve("book = '" + as_book + "' and trade_union = '" + as_trade_union + &
					"' and occupation = '" + as_occupation + "'")
	IF ll_rc > 0 THEN
		ls_description = This.of_GetItemString(ll_rc,"description")
	ELSE
		ls_description = ""
	END IF
END IF

RETURN ls_description
end function

public function string of_get_occupation_description_min (string as_book, string as_trade_union);//************************************************************
// Object   :	n_bo_occupation 
// Function :	of_get_occupation_description_min
// Author   :	Lourdes Garcia
// Date     :	2009/04/23
// 	
// Arguments:	string as_book
// 				string as_trade_union
// 	
// Returns:		string
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



String	ls_description
Long		ll_rc

IF IsNull(as_book) OR &
   IsNull(as_trade_union) THEN
	ls_description = ""
ELSE
	ll_rc = of_retrieve("book = '" + as_book + "' and trade_union = '" + as_trade_union + "'")
	This.of_SetSort("occupation")
	This.of_Sort()
	IF ll_rc > 0 THEN
		ls_description = This.of_GetItemString(1,"description")
	ELSE
		ls_description = ""
	END IF
END IF

RETURN ls_description
end function

public function integer of_get_trade_level (string as_book, string as_trade_union, string as_occupation, ref string as_trade, ref string as_level);//************************************************************
// Object   :	n_bo_occupation 
// Function :	of_get_trade_level
// Author   :	Lourdes Garcia
// Date     :	2009/04/30
// 	
// Arguments:	string as_book
// 				string as_trade_union
// 				string as_occupation
// 				string as_trade
// 				string as_level
// 	
// Returns:		integer  1 Success, -1 Cannot Retrieve; 0 Nothing Retrieved
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String	ls_description, &
			ls_where
Long		ll_rc
Int		li_return


ls_where = "book = '" + as_book + "' and trade_union = '" + as_trade_union + &
					"' and occupation = '" + as_occupation + "'"
					
IF IsNull(as_book) OR &
   IsNull(as_trade_union) OR &
	IsNull(as_occupation) THEN
	//gnv_error.of_add(90,gs_last_window,"R","Error reading occupation",-1,ls_where,"occupation")
	li_return = -1
	SetNull(as_trade)
	SetNull(as_level)
ELSE
	ll_rc = of_retrieve(ls_where)
	IF ll_rc > 0 THEN
		li_return = 1
		as_trade = This.of_GetItemString(ll_rc,"trade")
		as_level = This.of_GetItemString(ll_rc,"level")
		IF as_trade = "" THEN SetNull(as_trade)
		IF as_level = "" THEN SetNull(as_level)
	ELSE
		gnv_error.of_add(90,gs_last_window,"R","Nothing retrieved from occupation",100,ls_where,"occupation")
		li_return = 0
		SetNull(as_trade)
		SetNull(as_trade)
	END IF
END IF

RETURN li_return
end function

public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message);//************************************************************
// Object   :	n_bo_occupation 
// Function :	of_checkrenumber
// Author   :	Viktar Shmyk
// Date     :	2010/11/01
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

as_message = 'You are about to renumber ' + as_from_value + " to " + as_to_value + ". Continue?"

RETURN 1

end function

public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status);//************************************************************
// Object   :	n_bo_occupation 
// Function :	of_renumber
// Author   :	Viktar Shmyk
// Date     :	2010/11/01
//
// Arg:		as_book - Book for value being renumbered
//				as_from_value - Current value being renumbered
//				as_to_value - New value to renumber to
//				REF as_message - Message to return for display
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
// 
//************************************************************

Integer							li_rc = -1
String							ls_trade_union
Long								ll_row
Long								ll_rows
n_bo_tm_occupation_rate		lbo_tm_occupation_rate
n_bo_occupation_rate			lbo_occupation_rate
n_bo_employee					lbo_employee
n_bo_labour_dispersion		lbo_labour_dispersion

s_validation_error			lstr_validation_error[]

ls_trade_union = istr_renumber.s_other_key_value[2]

// Retrieve the From trade union record
ll_row = This.of_Retrieve("book = '" + as_book + &
		"' AND trade_union = '" + ls_trade_union + "' AND occupation = '" + as_from_value + "'")

IF ll_row > 0 THEN
	
	// Modify the occupation record
	This.of_SetItem(ll_row, "occupation", as_to_value)
	This.of_SetItem(ll_row, "billing_occupation", as_to_value)
	
	
	// Retrieve the child records and modify them
	This.of_GetChild({"tm_rate"}, lbo_tm_occupation_rate)
	This.of_GetChild({"occupation_rate"}, lbo_occupation_rate)
	This.of_GetChild({"employee"}, lbo_employee)
	This.of_GetChild({"labour_dispersion"},lbo_labour_dispersion)
	
	as_status.text = "Renumbering occupation rate"
	ll_rows = lbo_occupation_rate.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + ls_trade_union + "' AND occupation = '" + as_from_value + "'")
	
	FOR ll_row = 1 TO ll_rows
		lbo_occupation_rate.of_SetItem(ll_row, "occupation", as_to_value)
	NEXT
	
	ll_rows = lbo_tm_occupation_rate.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + ls_trade_union + "' AND occupation = '" + as_from_value + "'")
	
	FOR ll_row = 1 TO ll_rows
		lbo_tm_occupation_rate.of_SetItem(ll_row, "occupation", as_to_value)
	NEXT
	
	as_status.text = "Renumbering employee"
	ll_rows = lbo_employee.of_Retrieve("book = '" + as_book + &
			"' AND trade_union = '" + ls_trade_union + "' AND occupation = '" + as_from_value + "'")
	
	FOR ll_row = 1 TO ll_rows
		lbo_employee.of_SetItem(ll_row, "occupation", as_to_value)
	NEXT
	
	
	//Renumber Web-Abio crew tables
	as_status.text = "Renumbering Web-Abio components..."
	UPDATE supervisor_job_employee
		SET occupation = :as_to_value
	 WHERE trade_union = :ls_trade_union
		AND occupation 	= :as_from_value
	 USING this.itr_trans;
	IF this.itr_trans.sqlcode = -1 THEN
		of_msg_db_error('Error renumbering supervisor_job_employee', this.itr_trans)
		RETURN -1
	END IF
	
	as_status.text = "Renumbering timesheets"
	UPDATE timesheet
		SET occupation = :as_to_value
	 WHERE book = :as_book
		AND trade_union = :ls_trade_union
		AND occupation 	= :as_from_value
	 USING this.itr_trans;
	IF this.itr_trans.SQLCODE <> 0 THEN
		lstr_validation_error[1].s_message = "Error renumbering timesheets: " + this.itr_trans.SQLERRTEXT
		li_rc = -1
	ELSE
		li_rc = 1
	END IF
	
	
	IF li_rc = 1 THEN
		/*
		ll_rows = lbo_labour_dispersion.of_Retrieve("book = '" + as_book + &
				"' AND trade_union = '" + ls_trade_union + "' AND occupation = '" + as_from_value + "'")
		
		FOR ll_row = 1 TO ll_rows
			lbo_labour_dispersion.of_SetItem(ll_row, "occupation", as_to_value)
		NEXT
		*/
		
		as_status.text = "Renumbering timesheet dispersions"
		UPDATE labour_dispersion
			SET occupation = :as_to_value
		 WHERE book = :as_book
			AND trade_union = :ls_trade_union
			AND occupation 	= :as_from_value
		 USING this.itr_trans;
		IF this.itr_trans.SQLCODE <> 0 THEN
			lstr_validation_error[1].s_message = "Error renumbering timesheets: " + this.itr_trans.SQLERRTEXT
			li_rc = -1
		ELSE
			li_rc = 1
		END IF
		
		IF istr_renumber.b_allow_merge THEN
			IF This.of_count("book = '" + as_book + &
				"' AND trade_union = '" + ls_trade_union + "' AND occupation = '" + as_to_value + "'") > 0 THEN 
				
				ll_rows = lbo_occupation_rate.of_Retrieve("book = '" + as_book + &
						"' AND trade_union = '" + ls_trade_union + "' AND occupation = '" + as_from_value + "'")
				
				FOR ll_row = 1 TO ll_rows
					lbo_occupation_rate.of_DeleteRow(1)
				NEXT
	
				This.of_DeleteRow(ll_row)
	
			END IF
		END IF
		
		// Update but don't commit this business objects and all of its children
		//  *** commit handled in calling routine, after constraints are restored ***
		as_status.text = "Writing changes"
		li_rc = This.of_UpdateAll(FALSE, FALSE, lstr_validation_error)
	END IF
	
	IF li_rc = 1 THEN
//		COMMIT USING this.itr_trans;
		as_message = "Occupation " + as_from_value + " has been renumbered to " + &
				as_to_value
	ELSE
		ROLLBACK USING this.itr_trans;
		as_message = "Error renumbering occupation " + as_from_value + &
				" to " + as_to_value
		
		IF UpperBound(lstr_validation_error) > 0 THEN
			as_message += ":~r~n~r~n" + lstr_validation_error[1].s_message
		END IF
	END IF
ELSE
	as_message = "Occupation " + as_from_value + " does not exist"
END IF

as_status.text = "Renumbering complete"

RETURN li_rc


end function

on n_bo_occupation.create
call super::create
end on

on n_bo_occupation.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_occupation 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
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
This.of_SetDescription("Occupation")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_occupation"

// Set primary key columns
This.of_SetPKColumns({"book","trade_union","occupation"})

//Validation rules
This.of_AddValidationRule({"book", "trade_union", "occupation"}, "UNIQUE", &
		"", "Combination Trade Union & Occupation Must be Unique", TRUE)


This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Book is Required", TRUE)
This.of_AddValidationRule({"trade_union"}, "REQUIRED", &
		"", "Trade Union is Required", TRUE)
This.of_AddValidationRule({"occupation"}, "REQUIRED", &
		"", "Occupation is Required", TRUE)

This.of_AddValidationRule({"billing_occupation"}, "REQUIRED", &
		"", "Billing Occupation is Required", TRUE)


This.of_AddValidationRule({"description"}, "REQUIRED", &
		"", "Description is Required", TRUE)

This.of_AddValidationRule("active_flag", "EXPRESSION", &
		"<<active_flag>> IN ('Y', 'N')", &
		"Active Flag Must be Y or N", FALSE)

This.of_AddValidationRule({"level"}, "EXPRESSION", &
		"(<<level>> = '' AND <<trade>> = '') OR (<<level>> <> '' AND <<trade>> <> '')", "Trade must be blank or have a valid Level", FALSE)

This.of_AddValidationRule({"level"}, "EXPRESSION", &
		"<<level>> ='' OR (<<level>> <> '' AND <<trade>> <> '')", "Trade is required for the Trade Level", FALSE)



// Add child objects
This.of_AddChild("tm_rate", "n_bo_tm_occupation_rate")
This.of_AddChild("occupation_rate", "n_bo_occupation_rate")
This.of_AddChild("employee", "n_bo_employee")
This.of_AddChild("timesheet", "n_bo_timesheet")
This.of_AddChild("pr_cheque", "n_bo_pr_cheque")
This.of_AddChild("labour_dispersion", "n_bo_labour_dispersion")


This.of_SetColumnDefault("book", gnv_app.is_book)
This.of_SetColumnDefault("active_flag", 'Y')
This.of_SetColumnDefault("billing_occupation", '')

This.of_AddDBConstraint("fk_occupation__trade_description", 	/* Constraint name */ 					&
		"trade", 																/* Column to receive focus if constraint fails */ 	&
		"Trade not found", 													/* Message to display if constraint fails */			&
		"trade_description") 												/* Table referenced by constraint if foreign key */
This.of_AddDBConstraint("fk_occupation_rate__occupation", "occupation", &
		"Occupation", "Occupation Rate")

end event

event bo_prerowdelete;call super::bo_prerowdelete;//************************************************************
// Object   :	n_bo_occupation 
// Event    :	bo_prerowdelete
// Author   :	Lourdes Garcia
// Date     :	2012/06/19
// 	
// Arguments:	long al_row
// 	
// Returns:		boolean
// 	
// Desc:			Disallow deletion if there are timesheets for this occupation
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long					ll_count
Boolean 				lb_return = TRUE
String				ls_book, ls_occupation, ls_trade_union
n_bo_timesheet		lbo_timesheet

IF ib_validate_delete THEN
	ls_trade_union = This.of_GetItemString(al_row,'trade_union')
	ls_occupation = This.of_GetItemString(al_row,'occupation')
	ls_book = This.of_GetItemString(al_row,'book')
	
	// check if there are timesheet posted
	IF lb_return THEN
		lbo_timesheet = CREATE n_bo_timesheet
		lbo_timesheet.of_SetTransaction()
		ll_count = lbo_timesheet.of_count("trade_union = '" + string(ls_trade_union) +  &
										"' and occupation = '" + string(ls_occupation) + &
										"' and file_type = 'C' and book = '" + string(ls_book) + "'")
		IF ll_count > 0 THEN
			This.of_AddValidationError(al_row, "occupation", Primary!, "Deletion Disallowed. There are timesheet entries posted")
			lb_return = FALSE
		ELSE
			lb_return = TRUE
		END IF
		
		DESTROY lbo_timesheet
	END IF
END IF

RETURN lb_return
end event

