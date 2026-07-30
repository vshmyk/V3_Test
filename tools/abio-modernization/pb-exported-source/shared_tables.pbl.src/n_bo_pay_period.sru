$PBExportHeader$n_bo_pay_period.sru
forward
global type n_bo_pay_period from n_cst_business_abio
end type
end forward

global type n_bo_pay_period from n_cst_business_abio
end type
global n_bo_pay_period n_bo_pay_period

forward prototypes
public function integer of_get_pay_period_start (string as_type, string as_year, ref date ad_start)
public function integer of_get_pay_period_start (ref date ad_start)
public function integer of_get_next_pay_period_start (string as_type, string as_year, ref date ad_start)
public function integer of_get_last_day_of_pay_period (string as_pay_period_type, date ad_pp_start, ref date ad_last_day_of_pp)
end prototypes

public function integer of_get_pay_period_start (string as_type, string as_year, ref date ad_start);//************************************************************
// Object   :	n_bo_pay_period 
// Function :	of_get_pay_period_start
// Author   :	Monica Petersen
// Date     :	2013/04/12
// 	
// Arguments:	string as_type
// 				datetime adt_start
// 	
// Returns:		integer
// 	
// Desc:			Default to Weekly
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long	ll_rows
Integer	li_pay_period_start
n_bo_company	lbo_company	

//get pay period start and end date
lbo_company = CREATE n_bo_company
lbo_company.of_SetTransaction(sqlca)
ll_rows = lbo_company.of_retrieve("book = '" + gnv_app.is_book + "'")
CHOOSE CASE ll_rows 
	CASE 1
		CHOOSE CASE as_type
			CASE 'B'
				li_pay_period_start = lbo_company.of_GetItemNumber(1, 'biweekly_pay_period_start')
			CASE 'W'
				li_pay_period_start = lbo_company.of_GetItemNumber(1, 'weekly_pay_period_start')
			CASE 'M'
				li_pay_period_start = lbo_company.of_GetItemNumber(1, 'monthly_pay_period_start')
			CASE 'S'
				li_pay_period_start = lbo_company.of_GetItemNumber(1, 'semi_monthly_pay_period_start')
		END CHOOSE
	CASE ELSE
		this.of_msg_db_error("Error reading company settings for " + gnv_app.is_book)
		RETURN -1
END CHOOSE

ll_rows = this.of_Retrieve("pay_period_type = '" + as_type + "' AND year = '" + as_year + "'")
IF ll_rows > 0 THEN
	IF li_pay_period_start = 0 THEN
		this.of_msg_db_error("Company is incorrectly setup - No " + as_type + " pay period start has been set")
		RETURN -1
	ELSE
		ad_start = Date(this.of_GetItemDateTime(1,'period_' + String(li_pay_period_start) + '_start'))
	END IF
ELSE
	this.of_msg_db_error("Can't read pay period start dates")
	RETURN -1
END IF

RETURN 1
end function

public function integer of_get_pay_period_start (ref date ad_start);//************************************************************
// Object   :	n_bo_pay_period 
// Function :	of_get_pay_period_start
// Author   :	Monica Petersen
// Date     :	2010/04/14
// 	
// Arguments:	datetime adt_start
// 	
// Returns:		integer
// 	
// Desc:			(assumes weekly pay period, even though that is union driven, everyone is off biweekly)
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_tax_year

SELECT TOP 1 dbo.uf_current_tax_year(:gnv_app.is_book)
  INTO :ls_tax_year
  FROM pay_period
 USING sqlca;
IF sqlca.sqlcode <> 0 THEN
	this.of_msg_db_error("Error reading tax year")
	RETURN -1
END IF

RETURN of_get_pay_period_start('W', ls_tax_year, ad_start)
end function

public function integer of_get_next_pay_period_start (string as_type, string as_year, ref date ad_start);
//************************************************************
// Object   :	n_bo_pay_period 
// Function :	of_get_next_pay_period_start
// Author   :	Monica Petersen
// Date     :	2013/04/12
// 	
// Arguments:	string as_type
// 				string as_year
// 				date ad_start
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

Long	ll_rows
Integer	li_pay_period_start
n_bo_company	lbo_company	

//get pay period start and end date
lbo_company = CREATE n_bo_company
lbo_company.of_SetTransaction(sqlca)
ll_rows = lbo_company.of_retrieve("book = '" + gnv_app.is_book + "'")
IF ll_rows > 0 THEN
	CHOOSE CASE as_type
		CASE 'B'
			li_pay_period_start = lbo_company.of_GetItemNumber(1, 'biweekly_pay_period_start')
		CASE 'W'
			li_pay_period_start = lbo_company.of_GetItemNumber(1, 'weekly_pay_period_start')
		CASE 'M'
			li_pay_period_start = lbo_company.of_GetItemNumber(1, 'monthly_pay_period_start')
		CASE 'S'
			li_pay_period_start = lbo_company.of_GetItemNumber(1, 'semi_monthly_pay_period_start')
	END CHOOSE
END IF

ll_rows = this.of_Retrieve("pay_period_type = '" + as_type + "' AND year = '" + as_year + "'")
IF ll_rows > 0 THEN
	IF li_pay_period_start = 0 THEN
		this.of_msg_db_error("Company is incorrectly setup - No " + as_type + " pay period start has been set")
		RETURN -1
	ELSEIF (li_pay_period_start = 53 AND as_type = 'W') &
	OR (li_pay_period_start = 26 AND as_type = 'B') &
	OR (li_pay_period_start = 12 AND as_type = 'M') &
	OR (li_pay_period_start = 24 AND as_type = 'S') THEN
		SetNull(ad_start)
	ELSE
		ad_start = Date(this.of_GetItemDateTime(1,'period_' + String(li_pay_period_start + 1) + '_start'))
	END IF
ELSE
	this.of_msg_db_error("Can't read pay '" + as_type + "' period start dates for " + as_year)
	RETURN -1
END IF

RETURN 1
end function

public function integer of_get_last_day_of_pay_period (string as_pay_period_type, date ad_pp_start, ref date ad_last_day_of_pp);//************************************************************
// Object   :	n_bo_pay_period 
// Function :	of_get_last_day_of_pay_period
// Author   :	Monica Petersen
// Date     :	2015/12/31
// 	
// Arguments:	string as_pay_period_type
// 				date ad_pp_start
// 				date ad_last_day_of_pp
// 	
// Returns:		(None)
// 	
// Desc:			Find the date of the next pay period and subtract 1
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long	ll_pp_row, ll_pp_rows, ll_pp, ll_periods_per_year, ll_pp_record, ll_period, ll_year

ll_pp_rows = this.of_Retrieve("pay_period_type = '" + as_pay_period_type + "'")
this.of_SetSort("year ASC")
this.of_Sort()
			
CHOOSE CASE ll_pp_rows
	CASE IS < 0
		gnv_app.of_msg_db_error('PPEND', 'Error reading pay period for ' + as_pay_period_type + ', start date ' + String(ad_pp_start, 'yyyy.mm.dd'), this.itr_trans) 
		RETURN -1
	CASE 0
		gnv_app.of_msg_db_error('PPEND', 'Pay period not found for ' + as_pay_period_type + ', start date ' + String(ad_pp_start, 'yyyy.mm.dd'), this.itr_trans) 
		RETURN -1
	CASE ELSE
		
		//One or more pay period records found
		FOR ll_pp_row = 1 TO ll_pp_rows
			//Find the record that includes this start date
			ll_periods_per_year = this.of_GetItemNumber(ll_pp_row, 'pay_period_per_year')
			IF Date(this.of_GetItemDateTime(ll_pp_row, 'period_' + String(ll_periods_per_year) + '_start')) >= ad_pp_start THEN
				ll_pp_record = ll_pp_row
				FOR ll_pp = 1 TO ll_periods_per_year
					IF Date(this.of_GetItemDateTime(ll_pp_row, 'period_' + String(ll_pp) + '_start')) = ad_pp_start THEN
						ll_period = ll_pp
						EXIT	//Stop searching pay periods
					END IF
				NEXT
				EXIT	//Stop searching years
			END IF
		NEXT
		
		IF ll_pp_record = 0 THEN
			gnv_app.of_msg_db_error('PPEND', 'Cannot find pay period record for pay period type ' + as_pay_period_type + ', start date ' + String(ad_pp_start, 'yyyy.mm.dd'), this.itr_trans) 
			RETURN -1
		END IF
		
		IF ll_period = 0 THEN
			gnv_app.of_msg_db_error('PPEND', 'Cannot find start date for pay period type ' + as_pay_period_type + ', start date ' + String(ad_pp_start, 'yyyy.mm.dd'), this.itr_trans) 
			RETURN -1
		END IF
		
		IF ll_period = ll_periods_per_year THEN
			
			IF ll_pp_record = ll_pp_rows THEN
				ll_year = Long(this.of_GetItemString(ll_pp_record, 'year'))
				gnv_app.of_msg_db_error('PPEND', 'No pay periods defined for pay period type ' + as_pay_period_type + ', tax year ' + String(ll_year + 1), this.itr_trans) 
				RETURN -1
			ELSE
				//One day prior to the first pay period of the next year
				ad_last_day_of_pp = RelativeDate(Date(this.of_GetItemDateTime(ll_pp_record + 1, 'period_1_start')), -1)
			END IF
				
		ELSE
			//One day prior to the next pay period
			ad_last_day_of_pp = RelativeDate(Date(this.of_GetItemDateTime(ll_pp_record, 'period_' + String(ll_period + 1) + '_start')), -1)
			
		END IF
END CHOOSE


RETURN 1


end function

on n_bo_pay_period.create
call super::create
end on

on n_bo_pay_period.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object:	n_bo_pay_period
// Method:	Constructor
// Author:	Paul Bauermeister
// Date:		2009/04/14
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
// 
//************************************************************

// Set the object description to be seen in messages to user
This.of_SetDescription("Pay Period")

// Set the EVENT errors are logged under
This.of_SetEvent("PRPEND")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_pay_period"

// Set primary key columns
This.of_SetPKColumns({"pay_period_type", "year"})

This.of_AddValidationRule({"pay_period_type", "year"}, "UNIQUE", &
		"", "Pay Period Already Exists", FALSE)
	
This.of_AddValidationRule({"pay_period_type"}, "REQUIRED", &
		"", "Type is Required", FALSE)		

This.of_AddValidationRule({"period_1_start"}, "REQUIRED", &
		"", "First pay period is Required", FALSE)		

This.of_AddValidationRule({"year"}, "REQUIRED", &
		"", "Year is Required", FALSE)		

This.of_AddValidationRule({"pay_period_per_year"}, "REQUIRED", &
		"", "Pay periods per year cannot be blank", FALSE)		

This.of_AddValidationRule({"pay_period_type"}, "EXPRESSION", &
		" <<pay_period_type>> IN ('B', 'W', 'S', 'M')", "Type May Be 'B'iweekly, 'W'eekly, 'S'emi-monthly, or 'M'onthly", FALSE)

This.of_AddValidationRule({"pay_period_per_year"}, "EXPRESSION", &
		"(<<pay_period_per_year>> IN (26, 27) AND <<pay_period_type>> = 'B') " &
+ " OR (<<pay_period_per_year>> IN (52, 53) AND <<pay_period_type>> = 'W') "  &
+ " OR (<<pay_period_per_year>> IN (12)     AND <<pay_period_type>> = 'M') "  &
+ " OR (<<pay_period_per_year>> IN (24)     AND <<pay_period_type>> = 'S') " , &
		  "Incorrect Value For Pay Periods Per Year", FALSE)
		
// Set Default Values
This.of_setcolumndefault('add_user_id', gnv_app.of_getuserid())
This.of_setcolumndefault('add_datetime', 	"TODAY" )
This.of_setcolumndefault('active_flag', 	"Y" )
This.of_setcolumndefault('file_type', 		"C" )

end event

