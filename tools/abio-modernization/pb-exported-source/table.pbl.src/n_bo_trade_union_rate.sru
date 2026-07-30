$PBExportHeader$n_bo_trade_union_rate.sru
forward
global type n_bo_trade_union_rate from n_cst_business_abio
end type
end forward

global type n_bo_trade_union_rate from n_cst_business_abio
end type
global n_bo_trade_union_rate n_bo_trade_union_rate

forward prototypes
protected function integer of_validate ()
public function integer of_find_cheques_for_union_effective_on (string as_union, string as_pay_period, date adt_effective_date, date adt_expiry_date, ref date adt_max_pay_period_start_date, ref integer ai_pay_interval)
end prototypes

protected function integer of_validate ();//************************************************************
// Object   :	n_bo_trade_union_rate 
// Function :	of_validate
// Author   :	Viktar Shmyk
// Date     :	2012/05/03
// 	
// Arguments:	(None)
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

Long		ll_row
String	ls_action
Integer	li_rc
Decimal 	ldec_base_employer_rrsp_percent, &
			ldec_matching_employer_rrsp_percent, &
			ldec_base_employer_pension_percent, &
			ldec_matching_employer_pension_percent, &
			ldec_remit_pen_reg_hr, &
			ldec_remit_pen_tah_hr, &
			ldec_remit_pen_ovr_hr
String	ls_message = ""
String	ls_errcol

li_rc = Super::of_Validate()


//IF li_rc = 1 THEN
//	
//	ll_row = This.ids_data.GetRow()
//	IF ll_row > 0 THEN
//		ls_action = of_GetItem(ll_row, 'action')
//		IF ls_action <> 'D' THEN 
//			ldec_base_employer_rrsp_percent		= of_GetItemDecimal(ll_row, "base_employer_rrsp_percent")
//			ldec_matching_employer_rrsp_percent	= of_GetItemDecimal(ll_row, "matching_employer_rrsp_percent")
//
//			ldec_base_employer_pension_percent	= of_GetItemDecimal(ll_row, "base_employer_pension_percent")
//			ldec_matching_employer_pension_percent	= of_GetItemDecimal(ll_row, "matching_employer_pension_percent")
//			
//			ldec_remit_pen_reg_hr	= of_GetItemDecimal(ll_row, "remit_pen_reg_hr")
//			ldec_remit_pen_tah_hr	= of_GetItemDecimal(ll_row, "remit_pen_tah_hr")
//			ldec_remit_pen_ovr_hr	= of_GetItemDecimal(ll_row, "remit_pen_ovr_hr")
//			
//			IF (ldec_base_employer_rrsp_percent <> 0 OR ldec_matching_employer_rrsp_percent <> 0) AND &
//				(ldec_base_employer_pension_percent <> 0 OR ldec_matching_employer_pension_percent <> 0) AND &
//				(ldec_remit_pen_reg_hr <> 0 OR ldec_remit_pen_tah_hr <> 0 OR ldec_remit_pen_ovr_hr <> 0) THEN
//				
//				ls_message = "Percents may not be specified for both RRSP and pension when hourly amounts are not zero."
//				ls_errcol = "base_employer_rrsp_percent"
//			ELSEIF (ldec_base_employer_rrsp_percent = 0 OR ldec_matching_employer_rrsp_percent = 0) AND &
//					 (ldec_base_employer_pension_percent = 0 OR ldec_matching_employer_pension_percent = 0) AND &
//					 (ldec_remit_pen_reg_hr <> 0 OR ldec_remit_pen_tah_hr <> 0 OR ldec_remit_pen_ovr_hr <> 0) THEN
//				ls_message = "Pension or RRSP percents have to be specified when hourly amounts are not zero."
//				ls_errcol = "base_employer_rrsp_percent"
//			END IF	
//			
//			IF ls_message <> "" THEN
//				li_rc = -1
//				This.of_AddValidationError(ll_row, ls_errcol, Primary!, ls_message)
//			END IF
//			
//		END IF
//	END IF	
//END IF

RETURN li_rc

end function

public function integer of_find_cheques_for_union_effective_on (string as_union, string as_pay_period, date adt_effective_date, date adt_expiry_date, ref date adt_max_pay_period_start_date, ref integer ai_pay_interval);//************************************************************
// Object   :	n_bo_trade_union_rate 
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

li_rc = 0

ai_pay_interval = 6

CHOOSE CASE as_pay_period
	CASE "B"
		ai_pay_interval = 13
	CASE "W"
		ai_pay_interval = 6
	CASE "S"
		ai_pay_interval = 14
	CASE "M"
		ai_pay_interval = 30
END CHOOSE


SELECT Max(pr_cheque.pay_period_start_date) INTO :adt_max_pay_period_start_date
FROM pr_cheque 
WHERE book = :gnv_app.is_book 
  AND trade_union = :as_union 
  AND DateAdd(day, :ai_pay_interval, pay_period_start_date) BETWEEN :adt_effective_date AND :adt_expiry_date
  AND IsNull(net_pay, 0) <> 0
USING SQLCA;

IF Year(adt_max_pay_period_start_date) = 1900 THEN
	SetNull(adt_max_pay_period_start_date)
END IF

IF SQLCA.SQLCODE <> 0 THEN
	li_rc = -1
ELSE
	IF Not(IsNull(adt_max_pay_period_start_date)) THEN
		li_rc = -2
	END IF
END IF

RETURN li_rc
end function

on n_bo_trade_union_rate.create
call super::create
end on

on n_bo_trade_union_rate.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object:	n_bo_trade_union_rate
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
// 
//************************************************************



// Set the object description to be seen in messages to user
This.of_SetDescription("Trade Union Rate")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_trade_union_rate"

// Set primary key columns
This.of_SetPKColumns({"book","trade_union","effective_date"})

// Validation Rules
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Book is Required", TRUE)
This.of_AddValidationRule({"trade_union"}, "REQUIRED", &
		"", "Trade Union is Required", TRUE)
This.of_AddValidationRule({"effective_date"}, "REQUIRED", &
		"", "Effective Date is Required", TRUE)
This.of_AddValidationRule({"book", "trade_union", "effective_date"}, "UNIQUE", &
		"", "Effective Date Must be Unique within Book and Trade Union", FALSE)
This.of_AddValidationRule("sub_hbk_percent", "EXPRESSION", &
		"<<sub_hbk_percent>> BETWEEN 0 AND 100", &
		"Subcontractor Holdback Percentage Must be Between 0 and 100", FALSE)
This.of_AddValidationRule("vacation_pay_type", "EXPRESSION", &
		"<<vacation_pay_type>> IN ('B', 'H', 'K', 'R', 'S')", &
		"Vacation Pay Type Must be B, H, K, R or S", FALSE)
This.of_AddValidationRule("statutory_pay_type", "EXPRESSION", &
		"<<statutory_pay_type>> IN ('B', 'H', 'R', 'S')", &
		"Statutory Pay Type Must be B, H, R or S", FALSE)
This.of_AddValidationRule("dues_on_holiday_pay_flag", "EXPRESSION", &
		"<<dues_on_holiday_pay_flag>> IN ('Y', 'N')", &
		"Dues On Holiday Pay Flag Must be Y or N", FALSE)
This.of_AddValidationRule("sick_pay_in_holiday_earning_flag", "EXPRESSION", &
		"<<sick_pay_in_holiday_earning_flag>> IN ('Y', 'N')", &
		"Include Sick Pay in Holiday Earning Flag Must be Y or N", FALSE)

This.of_AddValidationRule("paid_sick_type", "EXPRESSION", &
		"<<paid_sick_type>> IN ('B', 'R', 'E')", &
		"Paid Sick Type must be all hrs at 'B'ase rates, all hrs at 'R'egular rates, or 'E'arnings", TRUE)

This.of_AddValidationRule("paid_sick_reg_earn", "EXPRESSION", &
		"<<paid_sick_reg_earn>> BETWEEN 0 AND 10", &
		"Paid Sick Leave on Regular Earnings Must be Between 0 and 10", FALSE)

This.of_AddValidationRule("paid_sick_tah_earn", "EXPRESSION", &
		"<<paid_sick_tah_earn>> BETWEEN 0 AND 10", &
		"Paid Sick Leave on Time and a Half Earnings Must be Between 0 and 10", FALSE)

This.of_AddValidationRule("paid_sick_ovr_earn", "EXPRESSION", &
		"<<paid_sick_ovr_earn>> BETWEEN 0 AND 10", &
		"Paid Sick Leave on Overtime Earnings Must be Between 0 and 10", FALSE)

This.of_AddValidationRule("paid_sick_reg_hr", "EXPRESSION", &
		"<<paid_sick_reg_hr>> BETWEEN 0 AND 10", &
		"Paid Sick Leave on Regular Hours Must be Between 0 and 10", FALSE)

This.of_AddValidationRule("paid_sick_tah_hr", "EXPRESSION", &
		"<<paid_sick_tah_hr>> BETWEEN 0 AND 10", &
		"Paid Sick Leave on Time and a Half Hours Must be Between 0 and 10", FALSE)

This.of_AddValidationRule("paid_sick_ovr_hr", "EXPRESSION", &
		"<<paid_sick_ovr_hr>> BETWEEN 0 AND 10", &
		"Paid Sick Leave on Overtime Hours Must be Between 0 and 10", FALSE)

This.of_AddValidationRule("base_employer_rrsp_percent", "EXPRESSION", &
		"<<base_employer_rrsp_percent>> BETWEEN 0 AND 99.99", &
		"Employer RRSP Percent Must be Between 0 and 99.99", FALSE)

This.of_AddValidationRule("matching_employer_rrsp_percent", "EXPRESSION", &
		"<<matching_employer_rrsp_percent>> BETWEEN 0 AND 99.99", &
		"Matching Employer RRSP Percent Must be Between 0 and 99.99", FALSE)

This.of_AddValidationRule("base_employer_pension_percent", "EXPRESSION", &
		"<<base_employer_pension_percent>> BETWEEN 0 AND 99.99", &
		"Base Employer Pension Percent Must be Between 0 and 99.99", FALSE)
		
This.of_AddValidationRule("matching_employer_pension_percent", "EXPRESSION", &
		"<<matching_employer_pension_percent>> BETWEEN 0 AND 99.99", &
		"Matching Employer Pension Percent Must be Between 0 and 99.99", FALSE)
		
This.of_AddValidationRule("group_safety_rate", "EXPRESSION", &
		"<<group_safety_rate>> BETWEEN 0 AND 5", &
		"Group Safety Rate Must be Between 0 and 5", FALSE)
This.of_AddValidationRule("personal_safety_rate", "EXPRESSION", &
		"<<personal_safety_rate>> BETWEEN 0 AND 5", &
		"Personal Safety Rate Must be Between 0 and 5", FALSE)
This.of_AddValidationRule("production_bonus_rate", "EXPRESSION", &
		"<<production_bonus_rate>> BETWEEN 0 AND 5", &
		"Production Bonus Rate Must be Between 0 and 5", FALSE)
This.of_AddValidationRule("employer_pension_or_rrsp", "EXPRESSION", &
		"<<employer_pension_or_rrsp>> IN ('N', 'P', 'R', 'B')", &
		"Employer Pension or RRSP Must be N, P, R or B", FALSE)
This.of_AddValidationRule("employee_pension_or_rrsp", "EXPRESSION", &
		"<<employee_pension_or_rrsp>> IN ('N', 'P', 'R')", &
		"Employee Pension or RRSP Must be N, P or R", FALSE)
This.of_AddValidationRule("include_travel_flag", "EXPRESSION", &
		"<<include_travel_flag>> IN ('Y', 'N')", &
		"Include Travel Flag Must be Y or N", FALSE)

//Jira 3948 - Pension Plan number should not include blanks
This.of_AddValidationRule("pension_plan_no", "EXPRESSION", &
		"(<<employer_pension_or_rrsp>> IN ('P','B') AND Pos(<<pension_plan_no>>, ' ') = 0) OR <<employer_pension_or_rrsp>> NOT IN ('P','B')", &
		"Pension Plan No May Not Contain Spaces", FALSE)

//This.of_AddValidationRule("pension_plan_no", "EXPRESSION", &
//		"(<<employer_pension_or_rrsp>> IN ('P','B') AND Len(<<pension_plan_no>>) BETWEEN 1 AND 10) OR <<employer_pension_or_rrsp>> NOT IN ('P','B')", &
//		"Pension Plan No May Not Be Blank", FALSE)

This.of_AddValidationRule("max_monthly_dues", "EXPRESSION", &
		"<<max_monthly_dues>> BETWEEN 0 AND 20000", &
		"Employer Monthly Remittance Must be Between 0 and 20000", FALSE)
This.of_AddValidationRule("employer_monthly_remit", "EXPRESSION", &
		"<<employer_monthly_remit>> BETWEEN 0 AND 2000", &
		"Employer Monthly Remittance Must be Between 0 and 2000", FALSE)


//This.of_AddValidationRule({"base_employer_rrsp_percent", "matching_employer_rrsp_percent", "base_employer_pension_percent", "matching_employer_pension_percent", "remit_pen_reg_hr", "remit_pen_tah_hr", "remit_pen_ovr_hr"}, "EXPRESSION", &
//		"<<employer_pension_or_rrsp>> = 'B' AND ( (  ((<<base_employer_rrsp_percent>> <> 0 OR <<matching_employer_rrsp_percent>> <> 0) AND (<<base_employer_pension_percent>> = 0 AND <<matching_employer_pension_percent>> = 0)) OR ((<<base_employer_rrsp_percent>> = 0 AND <<matching_employer_rrsp_percent>> = 0) AND (<<base_employer_pension_percent>> <> 0 OR <<matching_employer_pension_percent>> <> 0))) AND (<<remit_pen_reg_hr>> <> 0 OR <<remit_pen_tah_hr>> <> 0 OR <<remit_pen_ovr_hr>> <> 0))", &
//		"Only one of RRSP or pension has to be percent while other has to be hourly amounts", FALSE)		
//

/*
This.of_AddValidationRule({"pension_plan_no", "dues_pen_reg_hr", "dues_pen_tah_hr", "dues_pen_ovr_hr", "employee_pension_percent", "base_employer_pension_percent", "matching_employer_pension_percent", "remit_pen_reg_hr", "remit_pen_tah_hr", "remit_pen_ovr_hr"}, "EXPRESSION", &
		"Len(<<pension_plan_no>>) > 0 OR ((Len(<<pension_plan_no>>) = 0 AND <<employee_pension_percent>> = 0 AND (<<employee_pension_or_rrsp>> <> 'P' OR (<<employee_pension_or_rrsp>> = 'P' AND <<dues_pen_reg_hr>> = 0 AND <<dues_pen_tah_hr>> = 0 AND  <<dues_pen_ovr_hr>> = 0)) AND <<base_employer_pension_percent>> = 0 AND <<matching_employer_pension_percent>> = 0 AND <<remit_pen_reg_hr>> = 0 AND <<remit_pen_tah_hr>> = 0 AND <<remit_pen_ovr_hr>> = 0) OR &
		 (Len(<<pension_plan_no>>) > 0 AND ( (<<employee_pension_or_rrsp>> = 'P' AND (<<dues_pen_reg_hr>> <> 0 OR <<dues_pen_tah_hr>> <> 0 OR <<dues_pen_ovr_hr>> <> 0)) OR <<employee_pension_percent>> <> 0 OR <<base_employer_pension_percent>> <> 0 OR <<matching_employer_pension_percent>> <> 0 OR <<remit_pen_reg_hr>> <> 0 OR <<remit_pen_tah_hr>> <> 0 OR <<remit_pen_ovr_hr>> <> 0)))", &
		"Pension Plan No May Not Be Blank", FALSE)
*/

//This.of_AddValidationRule("rrsp_if_employee_pays_flag", "EXPRESSION", &
//		"<<rrsp_if_employee_pays_flag>> IN ('Y', 'N')", &
//		"RRSP if employee pays Flag Must be Y or N", FALSE)		

/*This.of_AddValidationRule("rrsp_if_employee_pays_flag", "EXPRESSION", &
		"(<<rrsp_percent>> <> 0 AND <<rrsp_if_employee_pays_flag>> = 'Y' ) OR (<<rrsp_if_employee_pays_flag>> = 'N' AND <<rrsp_percent>> = 0)", &
		"RRSP if employee pays flag can only be 'Y' if employer RRSP percent is non-zero", FALSE)		*/


/*This.of_AddValidationRule("pension_if_employee_pays_flag", "EXPRESSION", &
		"(<<employer_pension_percent>> <> 0 AND <<pension_if_employee_pays_flag>> = 'Y' ) OR (<<pension_if_employee_pays_flag>> = 'N' AND <<employer_pension_percent>> = 0)", &
		"pension if employee pays flag can only be 'Y' if employer pension percent is non-zero", FALSE)		*/

/*
This.of_AddValidationRule("rrsp_if_employee_pays_flag", "EXPRESSION", &
		"(<<rrsp_percent>> = 0 AND <<rrsp_if_employee_pays_flag>> <> 'Y' )  or (<<rrsp_percent>> <> 0 AND <<rrsp_if_employee_pays_flag>> = 'Y') or  (<<rrsp_percent>> <> 0 AND <<rrsp_if_employee_pays_flag>> = 'N' )", &
		"RRSP if employee pays flag cannot be 'Y' if employer RRSP percent is zero", FALSE)		

This.of_AddValidationRule("pension_if_employee_pays_flag", "EXPRESSION", &
		"(<<employer_pension_percent>> = 0 AND <<pension_if_employee_pays_flag>> <> 'Y' ) OR (<<employer_pension_percent>> <> 0 AND <<pension_if_employee_pays_flag>> = 'Y' )  OR (<<employer_pension_percent>> <> 0 AND <<pension_if_employee_pays_flag>> = 'N' )", &
		"pension if employee pays flag cannot be 'Y' if employer pension percent is zero", FALSE)	
*/

This.of_AddValidationRule("union_vacation_pay_flag", "EXPRESSION", &
		"<<union_vacation_pay_flag>> IN ( 'Y', 'N' )  ", &
		"Union Vacation Pay Flag Must be Y or N", FALSE)	

This.of_AddValidationRule("union_statutory_pay_flag", "EXPRESSION", &
		"<<union_statutory_pay_flag>> IN ( 'Y', 'N' )  ", &
		"Union Statutory Pay Flag Must be Y or N", FALSE)	

This.of_AddValidationRule("vacation_percent", "EXPRESSION", &
		"(<<vacation_percent>> BETWEEN 4 AND 10 AND <<union_vacation_pay_flag>> = 'Y' ) OR (<<union_vacation_pay_flag>> = 'N' AND <<vacation_percent>> = 0)", &
		"Vacation percent must be between 4 and 10 if Vacation Pay Flag is 'Y', or zero if Vacation Pay Flag is 'N'", FALSE)		

This.of_AddValidationRule("statutory_percent", "EXPRESSION", &
		"(<<statutory_percent>> BETWEEN 2 AND 10 AND <<union_statutory_pay_flag>> = 'Y' ) OR (<<union_statutory_pay_flag>> = 'N' AND <<statutory_percent>> = 0)", &
		"Statutory percent must be between 2 and 10 if Statutory Pay Flag is 'Y', or zero if Statutory Pay Flag is 'N'", FALSE)		



This.of_AddValidationRule("remit_vacation_pay_flag", "EXPRESSION", &
		"<<remit_vacation_pay_flag>> IN ( 'Y', 'N' )  ", &
		"Remit Vacation Pay Flag Must be Y or N", FALSE)	

This.of_AddValidationRule("remit_statutory_pay_flag", "EXPRESSION", &
		"<<remit_statutory_pay_flag>> IN ( 'Y', 'N' )  ", &
		"Remit Statutory Pay Flag Must be Y or N", FALSE)	

This.of_AddValidationRule("vacation_pay_vendor", "EXPRESSION", &
		"(<<remit_vacation_pay_flag>> = 'Y' AND Len(<<vacation_pay_vendor>>) > 0) OR <<remit_vacation_pay_flag>> = 'N' ", &
		"Vendor for vacation pay cannot be blank when Remit Vacation Pay to Union is 'Y'", FALSE)	

This.of_AddValidationRule("statutory_pay_vendor", "EXPRESSION", &
		"(<<remit_statutory_pay_flag>> = 'Y' AND Len(<<statutory_pay_vendor>>) > 0) OR <<remit_statutory_pay_flag>> = 'N' ", &
		"Vendor for statutory pay cannot be blank when Remit Statutory Pay to Union is 'Y'", FALSE)	

This.of_AddValidationRule("dues_type", "EXPRESSION", &
		"<<dues_type>> IN ('B', 'E', 'R')", &
		"Dues Type Must be B, E or R", FALSE)

This.of_AddValidationRule("remit_earning_type", "EXPRESSION", &
		"<<remit_earning_type>> IN ('E', 'B')", &
		"Earning Type Must be E or B", FALSE)		



// Default values
This.of_SetColumnDefault("base_employer_rrsp_percent", "0")
This.of_SetColumnDefault("matching_employer_rrsp_percent",  "0")
This.of_SetColumnDefault("base_employer_pension_percent", "0")
This.of_SetColumnDefault("matching_employer_pension_percent",  "0")
This.of_SetColumnDefault('remit_pen_reg_hr',  "0")
This.of_SetColumnDefault('remit_pen_tah_hr',  "0")
This.of_SetColumnDefault('remit_pen_ovr_hr',  "0")
This.of_SetColumnDefault("remit_earning_type", "E")
This.of_SetColumnDefault("admin_fee", "0")
This.of_SetColumnDefault("permit_fee", "0")
This.of_SetColumnDefault("daily_due", "0")
This.of_SetColumnDefault("max_daily_due", "0")
This.of_SetColumnDefault("max_monthly_dues", "0")
This.of_SetColumnDefault("sub_hbk_percent", "0")
This.of_SetColumnDefault("dues_reg_hr", "0")
This.of_SetColumnDefault("dues_tah_hr", "0")
This.of_SetColumnDefault("dues_ovr_hr", "0")
This.of_SetColumnDefault("dues_reg_earn", "0")
This.of_SetColumnDefault("dues_tah_earn", "0")
This.of_SetColumnDefault("dues_ovr_earn", "0")
This.of_SetColumnDefault("dues_pen_reg_hr", "0")
This.of_SetColumnDefault("dues_pen_tah_hr", "0")
This.of_SetColumnDefault("dues_pen_ovr_hr", "0")
This.of_SetColumnDefault("remit_reg_hr", "0")
This.of_SetColumnDefault("remit_tah_hr", "0")
This.of_SetColumnDefault("remit_ovr_hr", "0")
This.of_SetColumnDefault("remit_reg_earn", "0")
This.of_SetColumnDefault("remit_tah_earn", "0")
This.of_SetColumnDefault("remit_ovr_earn", "0")
This.of_SetColumnDefault("remit_pen_reg_hr", "0")
This.of_SetColumnDefault("remit_pen_tah_hr", "0")
This.of_SetColumnDefault("remit_pen_ovr_hr", "0")
This.of_SetColumnDefault("remit_rrsp_reg_hr", "0")
This.of_SetColumnDefault("remit_rrsp_tah_hr", "0")
This.of_SetColumnDefault("remit_rrsp_ovr_hr", "0")
This.of_SetColumnDefault("employer_pension_percent", "0")
This.of_SetColumnDefault("personal_safety_rate", "0")
This.of_SetColumnDefault("group_safety_rate", "0")
This.of_SetColumnDefault("employee_pension_or_rrsp", "N")
This.of_SetColumnDefault("employer_pension_or_rrsp", "N")
This.of_SetColumnDefault("employer_pension_percent", "0")
This.of_SetColumnDefault("rrsp_percent", "0")
This.of_SetColumnDefault("employer_monthly_remit", "0")
This.of_SetColumnDefault("vacation_pay_type", "H")
This.of_SetColumnDefault("statutory_pay_type", "H")
This.of_SetColumnDefault("dues_on_holiday_pay_flag", "N")
This.of_SetColumnDefault("file_type", "C")
This.of_SetColumnDefault("expiry_date", "2099/12/31")
This.of_SetColumnDefault("rrsp_if_employee_pays_flag", "N")
This.of_setcolumndefault('add_user_id', gnv_app.of_getuserid())
This.of_setcolumndefault('add_datetime', 	"TODAY" )
This.of_SetColumnDefault("dues_type", "E")
This.of_SetColumnDefault("include_travel_flag", "Y")
This.of_SetColumnDefault("dues_on_travel_earning_flag", "Y")

This.of_SetColumnDefault("remit_vacation_pay_flag", "N")
This.of_SetColumnDefault("remit_statutory_pay_flag", "N")
This.of_SetColumnDefault("union_vacation_pay_flag", "N")
This.of_SetColumnDefault("union_statutory_pay_flag", "N")
This.of_SetColumnDefault("sick_pay_in_holiday_earning_flag", "N")
This.of_SetColumnDefault("paid_sick_type", "B")

This.of_SetColumnDefault("pension_if_employee_pays_flag", "N")

// Add DB Constraints
This.of_AddDBConstraint("pk_trade_union_rate", "effective_date", "Trade Union Rate", "")
This.of_AddDBConstraint("fk_trade_union_rate__trade_union", "effective_date", &
		"Trade Union Rate", "Trade Union")

// Add child tables.  This will assist renumbering

This.of_AddChild("trade_union_premium", "n_bo_trade_union_premium")
This.of_AddChild("trade_union_benefit", "n_bo_trade_union_benefit")
This.of_AddChild("trade_union_job", 	 "n_bo_trade_union_job")
This.of_AddChild("trade_union_trade_level_rrsp_pension",		"n_bo_trade_union_trade_level_rrsp_pension")
This.of_AddChild("trade_union_trade_level_shift_premium",	"n_bo_trade_union_trade_level_shift_premium")
This.of_AddChild("trade_union_trade_level_employee_rrsp",	"n_bo_trade_union_trade_level_employee_rrsp")
This.of_AddChild("employee", 	 			 "n_bo_employee")

end event

event bo_preupdate;call super::bo_preupdate;//************************************************************
// Object   :	n_bo_trade_union_rate 
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
String						ls_where
n_bo_trade_union_rate	lbo_trade_union_rate
s_validation_error		lstr_validation_error[]


// For each new record, modify the expiry date of the preceding record 
// and set the expiry date of the new record
DO
	ll_row = This.ids_data.GetNextModified(ll_row, Primary!)
	
	IF ll_row > 0 THEN
		IF This.ids_data.GetItemStatus(ll_row, 0, Primary!) = NewModified! THEN
			IF NOT IsValid(lbo_trade_union_rate) THEN
				lbo_trade_union_rate = CREATE n_bo_trade_union_rate
				lbo_trade_union_rate.of_SetTransaction()
			END IF
			
			ldt_effective = This.of_GetItemDatetime(ll_row, "effective_date")
			
			// Retrieve rates before the current record so that the expiry 
			// date of the preceding record can be set to the day before 
			// the effective date of the current record
			
			ls_where = "book = '" + &
					This.of_GetItemString(ll_row, "book") + &
					"' AND trade_union = '" + &
					This.of_GetItemString(ll_row, "trade_union") + &
					"' AND effective_date < '" + &
					String(ldt_effective, "yyyy-mm-dd") + "'"
			
			ll_exist_row = lbo_trade_union_rate.of_Retrieve(ls_where)
			
			IF ll_exist_row > 0 THEN
				lbo_trade_union_rate.of_SetSort("effective_date")
				lbo_trade_union_rate.of_Sort()
				
				ldt_expiry = lbo_trade_union_rate.of_GetItemDatetime(ll_exist_row, &
						"expiry_date")
				
				lbo_trade_union_rate.of_SetItem(ll_exist_row, "expiry_date", &
						Datetime(RelativeDate(Date(ldt_effective), -1)))
				
				li_rc = lbo_trade_union_rate.of_Update(FALSE, &
						lstr_validation_error)
				
				IF UpperBound(lstr_validation_error) > 0 THEN
					This.of_AddValidationErrors(lstr_validation_error)
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
					"' AND effective_date > '" + &
					String(This.of_GetItemDateTime(ll_row, "effective_date"), &
					"yyyy-mm-dd") + "'"
					
			ll_exist_row = lbo_trade_union_rate.of_Retrieve(ls_where)
			
			IF ll_exist_row > 0 THEN
				lbo_trade_union_rate.of_SetSort("effective_date")
				lbo_trade_union_rate.of_Sort()
				
				ldt_effective = lbo_trade_union_rate.of_GetItemDatetime(1, &
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
		IF NOT IsValid(lbo_trade_union_rate) THEN
			lbo_trade_union_rate = CREATE n_bo_trade_union_rate
			lbo_trade_union_rate.of_SetTransaction()
		END IF
		
		ls_book = This.of_GetItemString(ll_row, "book", Delete!, FALSE)
		ls_trade_union = This.of_GetItemString(ll_row, "trade_union", Delete!, FALSE)
		
		//Retrieve all rates records prior to the record being deleted
		ll_exist_row = lbo_trade_union_rate.of_Retrieve("book = '" + ls_book &
				+ "' AND trade_union = '" + ls_trade_union &
				+ "' AND effective_date < '" + String(This.of_GetItemDatetime(ll_row, "effective_date", Delete!, FALSE), "yyyy-mm-dd") + "'")
		
		IF ll_exist_row > 0 THEN
			lbo_trade_union_rate.of_SetSort("effective_date")
			lbo_trade_union_rate.of_Sort()
			
			//after sorting, last row is the most recent
			ldt_effective = lbo_trade_union_rate.of_GetItemDatetime(ll_exist_row, "effective_date")
			
			// If the existing row is also in the list of rate records to 
			// be deleted, don't waste time updating it (updating records 
			// that are about to be deleted also causes the overall update 
			// to potentially fail due to changing values in the WHERE 
			// clause of the DELETE statement)
			FOR ll_deleted_row = 1 TO ll_rows
				IF  This.of_GetItemString(ll_deleted_row, "book", Delete!, FALSE) = ls_book &
				AND This.of_GetItemString(ll_deleted_row, "trade_union", Delete!, FALSE) = ls_trade_union &
				AND This.of_GetItemDatetime(ll_deleted_row, "effective_date", Delete!, FALSE) = ldt_effective THEN
					EXIT
				END IF
			NEXT
			
			// we got through the above rows, and the prior rate record is not one of the rows being deleted
			IF ll_deleted_row > ll_rows THEN
				
				// Get the expiry date from the row being deleted...
				ldt_expiry = This.of_GetItemDatetime(ll_row, "expiry_date", Delete!, FALSE)
				
				// And put it on the most recent previous record
				lbo_trade_union_rate.of_SetItem(ll_exist_row, "expiry_date", ldt_expiry)
				
				// Write updates without committing?
				li_rc = lbo_trade_union_rate.of_Update(TRUE, lstr_validation_error)
				
				IF UpperBound(lstr_validation_error) > 0 THEN
					This.of_AddValidationErrors(lstr_validation_error)
				END IF
				
			END IF
		END IF
	NEXT
END IF

RETURN li_rc

end event

