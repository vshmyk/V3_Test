$PBExportHeader$n_bo_occupation_rate.sru
forward
global type n_bo_occupation_rate from n_cst_business_abio
end type
end forward

global type n_bo_occupation_rate from n_cst_business_abio
end type
global n_bo_occupation_rate n_bo_occupation_rate

forward prototypes
public function boolean of_current_occupation_rate (string as_book, string as_trade_union, string as_occupation, datetime adt_date)
public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status, boolean ab_saveas)
public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message)
end prototypes

public function boolean of_current_occupation_rate (string as_book, string as_trade_union, string as_occupation, datetime adt_date);//************************************************************
// Object   :	n_bo_occupation_rate 
// Function :	of_current_occupation_rate
// Author   :	Lourdes Garcia
// Date     :	2011/10/07
// 	
// Arguments:	string as_book
// 				string as_trade_union
// 				string as_occupation
// 				datetime adt_date
// 	
// Returns:		boolean
// 	
// Desc:			Returns TRUE if there is occupation rate within the given parameters
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Boolean 	lb_flag = FALSE
String	ls_filter

ls_filter =       "book = '" + as_book + "' and trade_union = '" + as_trade_union + &
						"' and occupation = '" + as_occupation + "'" + &
						"  and '" + string(adt_date, 'yyyymmdd') + "' BETWEEN CONVERT(varchar, effective_date, 112) AND CONVERT(varchar, expiry_date, 112) " 
						
IF NOT IsNull(ls_filter) THEN
	IF This.of_retrieve(ls_filter) > 0 THEN
				lb_flag = TRUE
	ELSE
				lb_flag = FALSE
	END IF			

END IF

RETURN lb_flag
end function

public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status, boolean ab_saveas);//************************************************************
// Object   :	n_bo_labour_rate_type 
// Function :	of_renumber
// Author   :	Monica Petersen
// Date     :	2015/04/29
// 	
// Arguments:	string as_book
// 				string as_from_value
// 				string as_to_value
// 				string as_message
// 				statictext as_status
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

Integer							li_rc 
Long								ll_row
Long								ll_rows
Long								ll_err
Integer							li_year, li_month, li_day
String							ls_trade_union
Date								ld_to_date, ld_next, ld_expiry

s_parm							lstr_parm

s_validation_error			lstr_validation_error[]

ls_trade_union = istr_renumber.s_other_key_value[1]

//to value comes in as yyyymmdd because of mask on edit field
li_year = Integer(left(as_to_value, 4))
li_month = Integer(Mid(as_to_value, 5,2))
li_day = Integer(Right(as_to_value, 2))
ld_to_date = Date(li_year , li_month, li_day)

SELECT min(effective_date)
  INTO :ld_next
  FROM occupation_rate
 WHERE book = :gnv_app.is_book
   AND trade_union = :ls_trade_union
   AND effective_date > :ld_to_date
USING sqlca;
IF sqlca.sqlcode = -1 THEN
	gnv_app.of_msg_db_error('occupation', 'error reading next effective date')
	RETURN -1
END IF

IF IsNull(ld_next) THEN
	ld_expiry = Date(2099, 12, 31)
ELSE
	ld_expiry = RelativeDate(ld_next, -1)
END IF
  
// Retrieve the From Occupation Rate record
ll_rows = this.of_Retrieve("book = '" + gnv_app.is_book &
									+ "' AND trade_union = '" + ls_trade_union &
									+ "' AND effective_date = Cast('" + as_from_value + "' AS DateTime)")	

IF ll_rows > 0 THEN

	as_status.text = "Renumbering Occupation Rates"
	Yield()
	
	//T/M Occupation Rates
	FOR ll_row = 1 TO ll_rows
		this.of_SetItem(ll_row, "effective_date", DateTime(ld_to_date, Time(0,0,0)))
		this.of_SetItem(ll_row, "expiry_date", ld_expiry)
		IF ab_saveas THEN this.of_SetItemStatus(ll_row, 0, Primary!, NewModified!)
	NEXT
	IF ll_rows > 0 THEN as_message += String(ll_rows, '#,##0') + ' Occupation Rates '	
		
	IF ab_saveas THEN
		as_status.text = "Occupation Rate " + as_from_value + " has been saved as " + as_to_value
	ELSE
		as_status.text = "Occupation Rate " + as_from_value + " has been renumbered to " + as_to_value
	END IF
	
	//Trigger code to fix up effective dates
	IF this.EVENT bo_preupdate() = 1 THEN
		// Update AND commit this business objects and all of its children (but don't validate)
		as_status.text = "Writing Updates... "
		li_rc = This.of_UpdateAll(FALSE, FALSE, lstr_validation_error)
		
		IF li_rc = 1 THEN	
			as_message += "have been saved from " + as_from_value + " as " + &
					String(ld_to_date, 'yyyy.mm.dd')
		ELSE
			
			ROLLBACK USING this.itr_trans;
			this.of_Rollback()
			
			as_message = "Error Saving Occupation Rate " + as_from_value + &
					" to " + as_to_value + ":"
			as_status.text = as_message
			
			FOR ll_err = 1 TO UpperBound(lstr_validation_error) 
				as_message += "~r~n~r~n" + gnv_app.of_format_validation_error(lstr_validation_error[ll_err])
			NEXT
		END IF
	ELSE
		
		this.of_rollback()
		as_message = "Unable to fix expiry dates for " + as_from_value + &
				" to " + as_to_value + ":"
		as_status.text = as_message
		
	END IF
ELSE
	as_message = "Occupation Rate effective " + as_from_value + " does not exist"
	as_status.text = as_message
END IF

RETURN 1

end function

public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message);Long		ll_rows
Integer	li_rc = -1
Long		ll_err
String	ls_trade_union

ls_trade_union = istr_renumber.s_other_key_value[1]

// Check that the from value exists
ll_rows = this.of_Retrieve("book = '" + gnv_app.is_book &
									+ "' AND trade_union = '" + ls_trade_union &
									+ "' AND effective_date = Cast('" + as_from_value + "' AS DateTime)")	

IF ll_rows > 0 THEN

	// Check that the to value does NOT exist (merges are not allowed 
	// for trade union records)
	ll_rows = this.of_Retrieve("book = '" + gnv_app.is_book &
										+ "' AND trade_union = '" + ls_trade_union &
										+ "' AND effective_date = Cast('" + as_to_value + "' AS DateTime)")	
	IF ll_rows = 0 THEN
		li_rc = 1
		as_message = ls_trade_union  + '/' + " Effective date " + as_from_value + " will be renumbered to " + &
				as_to_value
	ELSE
		as_message = ls_trade_union  + '/' + " Effective date " + as_to_value + " already exists"
	END IF
ELSE
	as_message = ls_trade_union  + '/' + " Effective date " + as_from_value + " does not exist"
END IF

RETURN li_rc	

end function

on n_bo_occupation_rate.create
call super::create
end on

on n_bo_occupation_rate.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_occupation_rate
// Event    :	constructor
// Author   :	Paul Bauermeister
// Date     :	2009/09/03
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
This.of_SetDescription("Occupation Rate")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_occupation_rate"

// Set primary key columns
This.of_SetPKColumns({"book", "trade_union", "occupation", "effective_date"})


This.of_AddValidationRule({"book", "trade_union", "occupation","effective_date"}, "UNIQUE", &
		"", "Combination Trade Union, Occupation & Effective Date Must be Unique", TRUE)


This.of_AddValidationRule({"base_rate"}, "EXPRESSION", &
		"<<base_rate>> BETWEEN 0.01 AND 999.99", &
		"Base Rate Must Be Greater Than 0 And Less Than 999.99", FALSE)

This.of_AddValidationRule({"reg_rate"}, "EXPRESSION", &
		"<<reg_rate>> BETWEEN 0.01 AND 999.99", &
		"Regular Rate Must Be Greater Than 0 And Less Than 999.99", FALSE)

This.of_AddValidationRule({"tah_rate"}, "EXPRESSION", &
		"<<tah_rate>> BETWEEN 0.01 AND 999.99", &
		"Time&Half Rate Must Be Greater Than 0 And Less Than 999.99", FALSE)

This.of_AddValidationRule({"ovr_rate"}, "EXPRESSION", &
		"<<ovr_rate>> BETWEEN 0.01 AND 999.99", &
		"Overtime Rate Must Be Greater Than 0 And Less Than 999.99", FALSE)


This.of_SetColumnDefault("book", gnv_app.is_book)
//This.of_SetColumnDefault("effective_date", String(Today(), "yyyy.mm.dd")) - need an itemchanged event to fire on the key
This.of_SetColumnDefault("expiry_date", "2099.12.31")
This.of_SetColumnDefault("file_type", "C")

end event

event bo_preupdate;call super::bo_preupdate;//************************************************************
// Object   :	n_bo_occupation_rate 
// Event    :	bo_preupdate
// Author   :	Viktar Shmyk
// Date     :	2009/04/18
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Handle insertion of new rate in between existing 
//					rates, and removal from existing rates
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer						li_rc = 1
Long							ll_rows
Long							ll_row
Long							ll_exist_row
Long							ll_deleted_row
Datetime						ldt_expiry
Datetime						ldt_effective
String						ls_book
String						ls_trade_union
String						ls_occupation
String						ls_where
n_bo_occupation_rate		lbo_occupation_rate
s_validation_error		lstr_validation_error[]

// For each new record, modify the expiry date of the preceding record 
// and set the expiry date of the new record
DO
	ll_row = This.ids_data.GetNextModified(ll_row, Primary!)
	
	IF ll_row > 0 THEN
		IF This.ids_data.GetItemStatus(ll_row, 0, Primary!) = NewModified! THEN
			IF NOT IsValid(lbo_occupation_rate) THEN
				lbo_occupation_rate = CREATE n_bo_occupation_rate
				lbo_occupation_rate.of_SetTransaction()
			END IF
			
			ldt_effective = This.of_GetItemDatetime(ll_row, "effective_date")
			
			// Retrieve rates before the current record so that the expiry 
			// date of the preceding record can be set to the day before 
			// the effective date of the current record
			
			ls_where = "book = '" + &
					This.of_GetItemString(ll_row, "book") + &
					"' AND trade_union = '" + &
					This.of_GetItemString(ll_row, "trade_union") + &
					"' AND occupation = '" + &
					This.of_GetItemString(ll_row, "occupation") + &
					"' AND effective_date < '" + &
					String(ldt_effective, "yyyy-mm-dd") + "'"
			
			ll_exist_row = lbo_occupation_rate.of_Retrieve(ls_where)
			
			IF ll_exist_row > 0 THEN
				lbo_occupation_rate.of_SetSort("effective_date")
				lbo_occupation_rate.of_Sort()
				
				ldt_expiry = lbo_occupation_rate.of_GetItemDatetime(ll_exist_row, &
						"expiry_date")
				
				lbo_occupation_rate.of_SetItem(ll_exist_row, "expiry_date", &
						Datetime(RelativeDate(Date(ldt_effective), -1)))
				
				li_rc = lbo_occupation_rate.of_Update(FALSE, &
						lstr_validation_error)
				
				IF UpperBound(lstr_validation_error) > 0 THEN
					This.of_AddValidationErrors(lstr_validation_error)
					RETURN -1
				END IF
				
				IF ldt_expiry > ldt_effective THEN
					// Set the current record's expiry date to what was the 
					// expiry date of the preceding record before the current 
					// record was created - this may get changed below
					This.of_SetItem(ll_row, "expiry_date", ldt_expiry)
				END IF
			END IF
			
			// Retrieve rates after the current record so that the expiry 
			// date of the current record can be set to the day before 
			// the effective date of the following record
			
			ls_where = "book = '" + &
					This.of_GetItemString(ll_row, "book") + &
					"' AND trade_union = '" + &
					This.of_GetItemString(ll_row, "trade_union") + &
					"' AND occupation = '" + &
					This.of_GetItemString(ll_row, "occupation") + &
					"' AND effective_date > '" + &
					String(This.of_GetItemDateTime(ll_row, "effective_date"), &
					"yyyy-mm-dd") + "'"
					
			ll_exist_row = lbo_occupation_rate.of_Retrieve(ls_where)
			
			IF ll_exist_row > 0 THEN
				lbo_occupation_rate.of_SetSort("effective_date")
				lbo_occupation_rate.of_Sort()
				
				ldt_effective = lbo_occupation_rate.of_GetItemDatetime(1, &
						"effective_date")
				
				This.of_SetItem(ll_row, "expiry_date", &
						Datetime(RelativeDate(Date(ldt_effective), -1)))
			END IF
		END IF
	END IF
LOOP UNTIL ll_row = 0

IF li_rc = 1 THEN
	// For each deleted record, modify the expiry date of the preceding record
	ll_rows = This.of_DeletedCount()
	
	FOR ll_row = 1 TO ll_rows
		IF NOT IsValid(lbo_occupation_rate) THEN
			lbo_occupation_rate = CREATE n_bo_occupation_rate
			lbo_occupation_rate.of_SetTransaction()
		END IF
		
		ls_book = This.of_GetItemString(ll_row, "book", Delete!, FALSE)
		ls_trade_union = This.of_GetItemString(ll_row, "trade_union", Delete!, FALSE)
		ls_occupation = This.of_GetItemString(ll_row, "occupation", Delete!, FALSE)
		
		ll_exist_row = lbo_occupation_rate.of_Retrieve("book = '" + &
				ls_book + "' AND trade_union = '" + &
				ls_trade_union + "' AND occupation = '" + ls_occupation + "' AND effective_date < '" + &
				String(This.of_GetItemDatetime(ll_row, "effective_date", &
				Delete!, FALSE), "yyyy-mm-dd") + "'")
		
		IF ll_exist_row > 0 THEN
			lbo_occupation_rate.of_SetSort("effective_date")
			lbo_occupation_rate.of_Sort()
			
			ldt_effective = lbo_occupation_rate.of_GetItemDatetime( &
					ll_exist_row, "effective_date")
			
			// If the existing row is also in the list of rate records to 
			// be deleted, don't waste time updating it (updating records 
			// that are about to be deleted also causes the overall update 
			// to potentially fail due to changing values in the WHERE 
			// clause of the DELETE statement)
			FOR ll_deleted_row = 1 TO ll_rows
				IF This.of_GetItemString(ll_deleted_row, "book", &
						Delete!, FALSE) = ls_book AND &
						This.of_GetItemString(ll_deleted_row, "trade_union", &
						Delete!, FALSE) = ls_trade_union AND &
						This.of_GetItemString(ll_deleted_row, "occupation", &
						Delete!, FALSE) = ls_occupation AND &
						This.of_GetItemDatetime(ll_deleted_row, "effective_date", &
						Delete!, FALSE) = ldt_effective THEN
					EXIT
				END IF
			NEXT
			
			IF ll_deleted_row > ll_rows THEN
				ldt_expiry = This.of_GetItemDatetime(ll_row, "expiry_date", &
						Delete!, FALSE)
				
				lbo_occupation_rate.of_SetItem(ll_exist_row, "expiry_date", &
						ldt_expiry)
				
				li_rc = lbo_occupation_rate.of_Update(FALSE, &
						lstr_validation_error)
				
				IF UpperBound(lstr_validation_error) > 0 THEN
					//This.of_AddValidationErrors(lstr_validation_error)
				END IF
			END IF
		END IF
	NEXT
END IF

RETURN li_rc

end event

event bo_prerowdelete;call super::bo_prerowdelete;//************************************************************
// Object   :	n_bo_occupation_rate 
// Event    :	bo_prerowdelete
// Author   :	Lourdes Garcia
// Date     :	2012/06/19
// 	
// Arguments:	long al_row
// 	
// Returns:		boolean
// 	
// Desc:			
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
Datetime				ldt_effective_date, ldt_expiry_date
n_bo_timesheet		lbo_timesheet


ls_trade_union = This.of_GetItemString(al_row,'trade_union')
ls_occupation = This.of_GetItemString(al_row,'occupation')
ls_book = This.of_GetItemString(al_row,'book')
ldt_effective_date = This.of_GetItemDateTime(al_row,"effective_date")
ldt_expiry_date = This.of_GetItemDateTime(al_row,"expiry_date")

// check if there are timesheet posted
IF lb_return THEN
	lbo_timesheet = CREATE n_bo_timesheet
	lbo_timesheet.of_SetTransaction()
	ll_count = lbo_timesheet.of_count("trade_union = '" + string(ls_trade_union) +  &
									"' and occupation = '" + string(ls_occupation) + &
									"' and file_type = 'C' and book = '" + string(ls_book) + &
									"' and CONVERT(varchar, work_date, 112) >= '" + string(ldt_effective_date, 'YYYYMMDD')  + &
						  			"' and CONVERT(varchar, work_date, 112) <= '" + string(ldt_expiry_date, 'YYYYMMDD') + "'" )
	IF ll_count > 0 THEN
		This.of_AddValidationError(al_row, "occupation", Primary!, "Deletion Disallowed. There are timesheet entries posted for this effective date")
		lb_return = FALSE
	ELSE
		lb_return = TRUE
	END IF
	
	DESTROY lbo_timesheet
END IF	

RETURN lb_return
end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_occupation_rate 
// Event    :	bo_validate
// Author   :	Lourdes Garcia
// Date     :	2012/07/03
// 	
// Arguments:	long al_row
// 				string as_column
// 				string as_value
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

Int	li_rc = 1
Decimal	ldc_base_rate, ldc_reg_rate

choose case as_column
	case "reg_rate"
		IF dec(as_value) > 0 THEN
			ldc_base_rate = This.of_GetItemDecimal(al_row,"base_rate")
			IF NOT(ldc_base_rate > 0) OR IsNull(ldc_base_rate) THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "A non-zero regular rate should also have a non-zero base rate")
			END IF
		END IF	
		
	case "base_rate"
		IF dec(as_value) = 0 OR IsNull(as_value) THEN
			ldc_reg_rate = This.of_GetItemDecimal(al_row,"reg_rate")
			IF ldc_reg_rate > 0  THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "A non-zero regular rate should also have a non-zero base rate")
			END IF
		END IF	
		
end choose


return li_rc
end event

