$PBExportHeader$n_bo_employee_premium.sru
forward
global type n_bo_employee_premium from n_cst_business_abio
end type
end forward

global type n_bo_employee_premium from n_cst_business_abio
end type
global n_bo_employee_premium n_bo_employee_premium

type variables

n_bo_trade_union_premium				ibo_trade_union_premium
n_bo_employee								ibo_employee
n_bo_timesheet_premium					ibo_timesheet_premium

end variables

on n_bo_employee_premium.create
call super::create
end on

on n_bo_employee_premium.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_employee_premium 
// Event    :	constructor
// Author   :	Viktar Shmyk
// Date     :	2010/09/28
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

ibo_trade_union_premium = CREATE n_bo_trade_union_premium
ibo_trade_union_premium.of_SetTransaction()

ibo_employee = CREATE n_bo_employee
ibo_employee.of_SetTransaction()


IF NOT IsValid(ibo_timesheet_premium) THEN
	ibo_timesheet_premium = CREATE n_bo_timesheet_premium
	ibo_timesheet_premium.of_SetTransaction()
END IF	

// Set the object description to be seen in messages to user
This.of_SetDescription("P/R Employee Premium")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_employee_premium"

// Force a new transaction for this business object
This.of_SetTransaction()

This.of_AddValidationRule({"effective_date"}, "REQUIRED", &
		"", "Effective Date is Required", FALSE)

This.of_AddValidationRule({"premium_type"}, "REQUIRED", &
		"", "Premium Type is Required", FALSE)

This.of_AddValidationRule({"book", "employee", "effective_date", "premium_type"}, "UNIQUE", &
		"", "Employee Premium Already Exists", FALSE)

//Set primary key column
of_setpkcolumns({"book", "employee", "effective_date", "premium_type"})


This.of_AddValidationRule({"effective_date", "expiry_date"}, "EXPRESSION", &
		"<<effective_date>> <= <<expiry_date>>", "Expiry date must be on or after Effective Date", FALSE)	

// Default values
This.of_SetColumnDefault("book", gnv_app.is_book)
This.of_SetColumnDefault("active_flag", "Y")
This.of_SetColumnDefault("effective_date", String(Today(), "yyyy.mm.dd"))
This.of_SetColumnDefault("expiry_date", '2099-12-31')
end event

event bo_preupdate;call super::bo_preupdate;//************************************************************
// Object   :	n_bo_employee_premium 
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
Long							ll_employee
Datetime						ldt_expiry
Datetime						ldt_effective
String						ls_book
String						ls_premium_type
String						ls_where
n_bo_employee_premium	lbo_employee_premium
s_validation_error		lstr_validation_error[]

// For each new record, modify the expiry date of the preceding record 
// and set the expiry date of the new record
DO
	ll_row = This.ids_data.GetNextModified(ll_row, Primary!)
	
	IF ll_row > 0 THEN
		IF This.ids_data.GetItemStatus(ll_row, 0, Primary!) = NewModified! THEN
			IF NOT IsValid(lbo_employee_premium) THEN
				lbo_employee_premium = CREATE n_bo_employee_premium
				lbo_employee_premium.of_SetTransaction()
			END IF
			
			ldt_effective = This.of_GetItemDatetime(ll_row, "effective_date")
			
			// Retrieve rates before the current record so that the expiry 
			// date of the preceding record can be set to the day before 
			// the effective date of the current record
			ll_employee = This.of_GetItemNumber(ll_row, "employee")
			ls_premium_type = This.of_GetItemString(ll_row, "premium_type")
			
			ll_exist_row = 0 
			
			IF ll_employee >0 AND NOT IsNull(ls_premium_type) THEN
				ls_where = "book = '" + &
						This.of_GetItemString(ll_row, "book") + &
						"' AND employee = " + &
						String(ll_employee) + &
						" AND premium_type = '" + &
						This.of_GetItemString(ll_row, "premium_type") + &
						"' AND effective_date < '" + &
						String(ldt_effective, "yyyy-mm-dd") + "'"
				
				ll_exist_row = lbo_employee_premium.of_Retrieve(ls_where)
			END IF
			
			IF ll_exist_row > 0 THEN
				lbo_employee_premium.of_SetSort("effective_date")
				lbo_employee_premium.of_Sort()
				
				ldt_expiry = lbo_employee_premium.of_GetItemDatetime(ll_exist_row, &
						"expiry_date")
				
				IF ldt_expiry > ldt_effective THEN
					//Only expire records that overlap the new entry.
					//Otherwise they were intended to exist for only a finite period.
					lbo_employee_premium.of_SetItem(ll_exist_row, "expiry_date", &
							Datetime(RelativeDate(Date(ldt_effective), -1)))
					
					li_rc = lbo_employee_premium.of_Update(FALSE, &
							lstr_validation_error)
					
					IF UpperBound(lstr_validation_error) > 0 THEN
						//This.of_AddValidationErrors(lstr_validation_error)
						istr_validation_error = lstr_validation_error
					END IF
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
			
			ll_employee = This.of_GetItemNumber(ll_row, "employee")
			ls_premium_type = This.of_GetItemString(ll_row, "premium_type")
			
			ll_exist_row = 0
			
			IF ll_employee > 0 AND NOT IsNull(ls_premium_type) THEN 
				ls_where = "book = '" + &
						This.of_GetItemString(ll_row, "book") + &
						"' AND employee = " + &
						String(ll_employee) + &
						" AND premium_type = '" + &
						ls_premium_type + &
						"' AND effective_date > '" + &
						String(This.of_GetItemDateTime(ll_row, "effective_date"), &
						"yyyy-mm-dd") + "'"
						
				ll_exist_row = lbo_employee_premium.of_Retrieve(ls_where)
			END IF
			
			IF ll_exist_row > 0 THEN
				lbo_employee_premium.of_SetSort("effective_date")
				lbo_employee_premium.of_Sort()
				
				ldt_effective = lbo_employee_premium.of_GetItemDatetime(1, &
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
		IF NOT IsValid(lbo_employee_premium) THEN
			lbo_employee_premium = CREATE n_bo_employee_premium
			lbo_employee_premium.of_SetTransaction()
		END IF
		
		ls_book = This.of_GetItemString(ll_row, "book", Delete!, FALSE)
		ll_employee = This.of_GetItemNumber(ll_row, "employee", Delete!, FALSE)
		ls_premium_type = This.of_GetItemString(ll_row, "premium_type", Delete!, FALSE)
		
		ll_exist_row = 0
		
		IF ll_employee > 0 AND NOT IsNull(ls_premium_type) THEN 
			ll_exist_row = lbo_employee_premium.of_Retrieve("book = '" + &
					ls_book + "' AND employee = " + &
					String(ll_employee) + " AND premium_type = '" + ls_premium_type + "' AND effective_date < '" + &
					String(This.of_GetItemDatetime(ll_row, "effective_date", &
					Delete!, FALSE), "yyyy-mm-dd") + "'")
		END IF
			
		IF ll_exist_row > 0 THEN
			lbo_employee_premium.of_SetSort("effective_date")
			lbo_employee_premium.of_Sort()
			
			ldt_effective = lbo_employee_premium.of_GetItemDatetime( &
					ll_exist_row, "effective_date")
			
			// If the existing row is also in the list of rate records to 
			// be deleted, don't waste time updating it (updating records 
			// that are about to be deleted also causes the overall update 
			// to potentially fail due to changing values in the WHERE 
			// clause of the DELETE statement)
			FOR ll_deleted_row = 1 TO ll_rows
				IF This.of_GetItemString(ll_deleted_row, "book", &
						Delete!, FALSE) = ls_book AND &
						This.of_GetItemNumber(ll_deleted_row, "employee", &
						Delete!, FALSE) = ll_employee AND &
						This.of_GetItemString(ll_deleted_row, "premium_type", &
						Delete!, FALSE) = ls_premium_type AND &
						This.of_GetItemDatetime(ll_deleted_row, "effective_date", &
						Delete!, FALSE) = ldt_effective THEN
					EXIT
				END IF
			NEXT
			
			IF ll_deleted_row > ll_rows THEN
				ldt_expiry = This.of_GetItemDatetime(ll_row, "expiry_date", &
						Delete!, FALSE)
				
				lbo_employee_premium.of_SetItem(ll_exist_row, "expiry_date", &
						ldt_expiry)
				
				li_rc = lbo_employee_premium.of_Update(FALSE, &
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

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_ap_invoice 
// Event    :	bo_validate
// Author   :	Monica Petersen
// Date     :	2011/01/25
// 	
// Arg:		al_row - Row being validated
//				as_column - Column being validated
//				REF as_value - Initial value which can be changed
//
// Return:	Integer - 1=Success, -1=Failure
//
// Desc:		This event is triggered during the validation process for 
//				each column, and can be coded in a descendant script to 
//				allow custom validation which may not be possible using 
//				the standard validation rules - the value may also be 
//				changed and returned back to the calling process
//
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer	li_rc = 1
String	ls_where
Long		ll_tup_rows

CHOOSE CASE as_column
	
	CASE 'reg_rate'
		
		IF ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(this.of_GetItemNumber(al_row, 'employee'))) > 0 THEN
			ls_where = "book = '" + gnv_app.is_book &
												+ "' AND trade_union = '" + ibo_employee.of_GetItemString(1, 'trade_union') &
												+ "' AND premium_type = '" + this.of_GetItemString(al_row, 'premium_type') &
												+ "' AND effective_date <= '" + String(this.of_GetItemDateTime(al_row, 'effective_date'), 'yyyy.mm.dd') &
												+ "' AND expiry_date >= '" + String(this.of_GetItemDateTime(al_row, 'effective_date'), 'yyyy.mm.dd') + "'"
			ll_tup_rows = ibo_trade_union_premium.of_Retrieve(ls_where) 
			CHOOSE CASE ll_tup_rows
			CASE -1 
				gnv_app.of_msg_db_error("PREENT","Error retrieving " + this.of_GetItemString(al_row, 'premium_type') + " from trade union " + ibo_employee.of_GetItemString(1, 'trade_union') + " effective " + String(this.of_GetItemDateTime(al_row, 'effective_date'), 'yyyy.mm.dd'))
				li_rc = -1	
			CASE 0
//				gnv_app.of_msg_db_error("PREENT","Cannot find premium " + this.of_GetItemString(al_row, 'premium_type') + " in trade union " + ibo_employee.of_GetItemString(1, 'trade_union') + " effective " + String(this.of_GetItemDateTime(al_row, 'effective_date'), 'yyyy.mm.dd') + ". Cannot verify rates are within range.")
//				li_rc = -1	
			CASE ELSE
				IF Dec(as_value) < ibo_trade_union_premium.of_GetItemDecimal(1, 'minimum_hour_rate') THEN
					this.of_AddValidationError(al_row, as_column, Primary!, "Regular Rate cannot be less than " + String(ibo_trade_union_premium.of_GetItemDecimal(1, 'minimum_hour_rate'),'##,###,###.00'))
					li_rc = -1	
				ELSEIF Dec(as_value) > ibo_trade_union_premium.of_GetItemDecimal(1, 'maximum_hour_rate') THEN
					this.of_AddValidationError(al_row, as_column, Primary!, "Regular Rate cannot be more than " + String(ibo_trade_union_premium.of_GetItemDecimal(1, 'maximum_hour_rate'),'##,###,###.00'))
					li_rc = -1	
				END IF
			END CHOOSE
		ELSE
			gnv_app.of_msg_db_error("PREENT","Error reading employee " + String(this.of_GetItemNumber(al_row, 'employee')))
			li_rc = -1	
		END IF
					
END CHOOSE

RETURN li_rc
end event

event destructor;call super::destructor;
IF IsValid(ibo_trade_union_premium) THEN DESTROY(ibo_trade_union_premium)
IF IsValid(ibo_employee) THEN DESTROY(n_bo_employee)
IF IsValid(ibo_timesheet_premium) THEN DESTROY(n_bo_timesheet_premium)

end event

event bo_prerowdelete;call super::bo_prerowdelete;
//************************************************************
// Object   :	n_bo_employee_premium 
// Event    :	bo_prerowdelete
// Author   :	Lourdes Garcia
// Date     :	2011/09/19
// 	
// Arguments:	long al_row
// 	
// Returns:		boolean
// 	
// Desc:			Validate if deletion is allowed
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Boolean 			lb_return
String			ls_where, ls_book, ls_premium_type
Long				ll_employee, ll_cnt
DateTime			ldt_effective_date, ldt_expiry_date

lb_return = TRUE


ls_book = This.of_GetItemString(al_row,"book")
ll_employee = This.of_GetItemNumber(al_row,"employee")
ldt_effective_date = This.of_GetItemDateTime(al_row,"effective_date")
ldt_expiry_date = This.of_GetItemDateTime(al_row,"expiry_date")
ls_premium_type  = This.of_GetItemString(al_row,"premium_type")

//IF NOT IsNull(ldt_expiry_date) THEN
//	ls_where = "book = '" + ls_book + "' and employee = " + string(ll_employee) + &
//					 " and premium_type = '" + ls_premium_type + "'" + &
//					 " and work_date >= CAST('" + string(ldt_effective_date) +  "' as datetime) " + &
//					 " and work_date <= CAST('" + string(ldt_expiry_date) +  "' as datetime) " 
//ELSE					 
//	ls_where = "book = '" + ls_book + "' and employee = " + string(ll_employee) + &
//					 " and premium_type = '" + ls_premium_type + "'" + &
//					 " and work_date >= CAST('" + string(ldt_effective_date) +  "' as datetime) " 
//
//END IF
//
//ll_cnt = ibo_timesheet_premium.of_count(ls_where)

SELECT COUNT(*) 
  INTO :ll_cnt
  FROM timesheet, timesheet_premium
 WHERE timesheet.book 		= timesheet_premium.book
   AND timesheet.employee 	= timesheet_premium.employee
	AND timesheet.work_date = timesheet_premium.work_date
	AND timesheet.timesheet_item = timesheet_premium.timesheet_item
	AND timesheet.book 		= :ls_book
	AND timesheet.employee 	= :ll_employee
	AND timesheet.work_date >= :ldt_effective_date
	AND timesheet.work_date <= :ldt_expiry_date
	AND timesheet.cheque_no <> 0 
	AND timesheet_premium.premium_type = :ls_premium_type
 USING sqlca;
IF sqlca.sqlcode = -1 THEN
	This.of_AddValidationError(al_row, "premium_type", Primary!, "Error counting timesheets.")
	lb_return = FALSE
END IF

IF ll_cnt > 0 THEN
	This.of_AddValidationError(al_row, "premium_type", Primary!, "There are timesheets for this effective date and premium type.  Deletion of premium is disallowed.")
	lb_return = FALSE
END IF


RETURN lb_return

end event

