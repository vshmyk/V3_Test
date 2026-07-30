$PBExportHeader$n_bo_employee.sru
forward
global type n_bo_employee from n_cst_business_abio
end type
end forward

global type n_bo_employee from n_cst_business_abio
end type
global n_bo_employee n_bo_employee

type variables
String 		is_delta
n_bo_person	ibo_person
n_bo_employee_earning	ibo_employee_earning
n_bo_employee_wcb			ibo_employee_wcb

end variables

forward prototypes
public subroutine of_set_termination_delta (string as_delta)
public function string of_get_termination_delta ()
public function integer of_get_restrict_flag (string as_book, long al_employee, ref string as_restrict_flag)
public function integer of_get_termination_date (string as_book, long al_employee, ref date adt_termination_date)
end prototypes

public subroutine of_set_termination_delta (string as_delta);//************************************************************
// Object   :	n_bo_employee 
// Function :	of_set_termination_delta
// Author   :	Lourdes Garcia
// Date     :	2009/07/17
// 	
// Arguments:	string as_delta
// 	
// Returns:		(None)
// 	
// Desc:			Sets delta for Action 'T'
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



is_delta = as_delta

RETURN

end subroutine

public function string of_get_termination_delta ();//************************************************************
// Object   :	n_bo_employee 
// Function :	of_get_termination_delta
// Author   :	Lourdes Garcia
// Date     :	2009/07/17
// 	
// Arguments:	(None)
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


RETURN is_delta

end function

public function integer of_get_restrict_flag (string as_book, long al_employee, ref string as_restrict_flag);//************************************************************
// Object   :	n_bo_employee 
// Function :	of_get_restrict_flag
// Author   :	Lourdes Garcia
// Date     :	2009/08/25
// 	
// Arguments:	string as_book
// 				long al_employee
// 				string as_restrict_flag
// 	
// Returns:		integer
// 	
// Desc:			Returns Restrict Flag, 1 success, -1 error, 0 no data
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************




Integer	li_rc
Long		ll_rows
String	ls_where


ls_where = "book = '" + string(as_book) + "' and employee = " + string(al_employee)

IF IsNull(as_book) OR as_book = "" OR al_employee = 0 THEN
	gnv_error.of_add(90, gs_last_window, "R", "Error reading employee", -1, &
			ls_where, "employee")
	li_rc = -1
	SetNull(as_restrict_flag)
ELSE
	ll_rows = This.of_retrieve(ls_where)
	
	IF ll_rows > 0 THEN
		as_restrict_flag = This.of_GetItemString(ll_rows,"restrict_flag")

		
		li_rc = 1
	ELSE
		li_rc = 0
		SetNull(as_restrict_flag )
	END IF
END IF

RETURN li_rc

end function

public function integer of_get_termination_date (string as_book, long al_employee, ref date adt_termination_date);//************************************************************
// Object   :	n_bo_employee 
// Function :	of_get_termination_date
// Author   :	Lourdes Garcia
// Date     :	2009/08/25
// 	
// Arguments:	string as_book
// 				long al_employee
// 				date adt_termination_date
// 	
// Returns:		integer
// 	
// Desc:			Returns Termination date, 1 success, -1 error, 0 no data
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



Integer	li_rc
Long		ll_rows
String	ls_where
Datetime ldtm_termination_date


ls_where = "book = '" + string(as_book) + "' and employee = " + string(al_employee)

IF IsNull(as_book) OR as_book = "" OR al_employee = 0 THEN
	gnv_error.of_add(90, gs_last_window, "R", "Error reading employee", -1, &
			ls_where, "employee")
	li_rc = -1
	SetNull(adt_termination_date)
ELSE
	ll_rows = This.of_retrieve(ls_where)
	
	IF ll_rows > 0 THEN
		ldtm_termination_date = This.of_GetItemDateTime(ll_rows,"termination_date")
		adt_termination_Date = Date(ldtm_termination_date)
		
		li_rc = 1
	ELSE
		li_rc = 0
		SetNull(adt_termination_date)
	END IF
END IF

RETURN li_rc

end function

on n_bo_employee.create
call super::create
end on

on n_bo_employee.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_employee 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/20
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Initialize employee BO
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

//merge compares 119 fields against 119 fields = 14,161 loops, which takes 4 seconds,
//so try to avoid merging the business object with the detail datawindow
This.of_setdefaultmerge(FALSE)

// Set the object description to be seen in messages to user
This.of_SetDescription("P/R Employee")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_employee"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book','employee'})


// Set Validations

This.of_AddValidationRule({"employee","book"}, "UNIQUE", &
		"", "Employee Must be Unique within the Company", FALSE)
		
This.of_AddValidationRule({"employee"}, "REQUIRED", &
		"", "Employee is Required", FALSE)
		
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Company is Required", FALSE)		

This.of_AddValidationRule({"name"}, "REQUIRED", &
		"", "Name is Required", FALSE)		

This.of_AddValidationRule({"employment_type"}, "REQUIRED", &
		"", "Employment Type is Required", FALSE)		
		
This.of_AddValidationRule({"trade_union"}, "REQUIRED", &
		"", "Union is Required", FALSE)		
		
This.of_AddValidationRule({"occupation"}, "REQUIRED", &
		"", "Occupation is Required", FALSE)		

This.of_AddValidationRule({"shift"}, "REQUIRED", &
		"", "Shift is Required", FALSE)		

This.of_AddValidationRule({"federal_zone_deduction"}, "REQUIRED", &
		"", "Federal zone deduction is Required", FALSE)		

This.of_AddValidationRule({"federal_td1_claim"}, "REQUIRED", &
		"", "Federal TD1 claim is Required", FALSE)		

This.of_AddValidationRule({"provincial_td1_claim"}, "REQUIRED", &
		"", "Provincial TD1 claim is Required", FALSE)		

This.of_AddValidationRule({"add_income_tax_per_ck"}, "REQUIRED", &
		"", "Add Income tax per ck is Required", FALSE)		

This.of_AddValidationRule({"cpp_exempt_flag"}, "REQUIRED", &
		"", "CPP exempt flag is Required", FALSE)	

This.of_AddValidationRule({"ei_exempt_flag"}, "REQUIRED", &
		"",  "EI exempt flag is Required", FALSE)	
		
This.of_AddValidationRule({"income_tax_exempt_flag"}, "REQUIRED", &
		"", "Tax exempt flag is Required", FALSE)	
		
This.of_AddValidationRule({"hire_date"}, "REQUIRED", &
		"", "Hire Date is Required", FALSE)				
		
This.of_AddValidationRule({"garnishee_flag"}, "REQUIRED", &
		"", "Garnishee flag is Required", FALSE)				

This.of_AddValidationRule({"safety_to_rrsp_flag"}, "REQUIRED", &
		"", "Safety to RRSP is Required", FALSE)				
		
This.of_AddValidationRule({"other_incentive_to_rrsp_flag"}, "REQUIRED", &
		"", "Other incentive to RRSP flag is Required", FALSE)				
		
This.of_AddValidationRule({"vacation_percent"}, "REQUIRED", &
		"", "Vacation % is Required", FALSE)				

This.of_AddValidationRule({"statutory_percent"}, "REQUIRED", &
		"", "Statutory % is Required", FALSE)				
		
This.of_AddValidationRule({"employer_rrsp_percent"}, "REQUIRED", &
		"", "RRSP % earn is Required", FALSE)						

This.of_AddValidationRule({"staff_safety_percent"}, "REQUIRED", &
		"", "Staff % earn is Required", FALSE)				
		
This.of_AddValidationRule({"smtc_percent"}, "REQUIRED", &
		"", "Tool % earn is Required", FALSE)				
		
This.of_AddValidationRule({"incentive_percent"}, "REQUIRED", &
		"", "Incentive % earn is Required", FALSE)				
		
This.of_AddValidationRule({"training_percent"}, "REQUIRED", &
		"", "Training % earn is Required", FALSE)				
		
This.of_AddValidationRule({"loa_rate"}, "REQUIRED", &
		"", "LOA/hr is Required", FALSE)		

This.of_AddValidationRule({"mileage_rate"}, "REQUIRED", &
		"", "Mileage/hr is Required", FALSE)		

This.of_AddValidationRule({"mileage_taxable_flag"}, "REQUIRED", &
		"", "Mileage taxable flag is Required", FALSE)		

This.of_AddValidationRule({"site_allow_taxable_flag"}, "REQUIRED", &
		"", "Site allow taxable flag is Required", FALSE)		

This.of_AddValidationRule({"employee_rrsp_per_ck"}, "REQUIRED", &
		"", "Employee RRSP is Required", FALSE)	

This.of_AddValidationRule({"taxable_benefit_per_ck"}, "REQUIRED", &
		"", "Taxable benefit per cheque is Required", FALSE)	

This.of_AddValidationRule({"taxable_benefit_per_month"}, "REQUIRED", &
		"", "Taxable benefit per month is Required", FALSE)	

This.of_AddValidationRule({"charity_per_ck"}, "REQUIRED", &
		"", "Charity flag is Required", FALSE)	
		
This.of_AddValidationRule({"turnaround_cycle_days"}, "REQUIRED", &
		"", "Cycle days is Required", FALSE)	
		
This.of_AddValidationRule({"next_turnaround_amt"}, "REQUIRED", &
		"", "Turnaround amt is Required", FALSE)	
		
This.of_AddValidationRule({"dues_per_month"}, "REQUIRED", &
		"", "Dues per month is Required", FALSE)
		
This.of_AddValidationRule({"security_deposit"}, "REQUIRED", &
		"", "Security Deposit is Required", FALSE)

This.of_AddValidationRule({"advance_repay"}, "REQUIRED", &
		"", "Advance/repay is Required", FALSE)

This.of_AddValidationRule({"vacation_owed"}, "REQUIRED", &
		"", "Vacation owed is Required", FALSE)

This.of_AddValidationRule({"statutory_owed"}, "REQUIRED", &
		"", "Statutory owed is Required", FALSE)

This.of_AddValidationRule({"personal_safety_owed"}, "REQUIRED", &
		"", "Personal safety owed is Required", FALSE)

This.of_AddValidationRule({"group_safety_owed"}, "REQUIRED", &
		"", "Group safety owed is Required", FALSE)

This.of_AddValidationRule({"staff_safety_owed"}, "REQUIRED", &
		"", "Other safety owed is Required", FALSE)

This.of_AddValidationRule({"smtc_owed"}, "REQUIRED", &
		"", "Tools owed is Required", FALSE)

This.of_AddValidationRule({"training"}, "REQUIRED", &
		"", "Training earn is Required", FALSE)

This.of_AddValidationRule({"retention_owed"}, "REQUIRED", &
		"", "Retention Owed is Required", FALSE)

This.of_AddValidationRule({"incentive_owed"}, "REQUIRED", &
		"", "Incentive Owed is Required", FALSE)

This.of_AddValidationRule({"restrict_flag"}, "REQUIRED", &
		"", "Restrict Access flag is Required", FALSE)

This.of_AddValidationRule({"file_type"}, "REQUIRED", &
		"", "File Type is Required", FALSE)

This.of_AddValidationRule({"add_user_id"}, "REQUIRED", &
		"", "Add user id is Required", FALSE)

This.of_AddValidationRule({"add_datetime"}, "REQUIRED", &
		"", "Add date time is Required", FALSE)
		
This.of_AddValidationRule({"local_hire_flag"}, "REQUIRED", &
		"", "Local Hire Flag is Required", FALSE)
		
This.of_AddValidationRule({"daily_dues_flag"}, "REQUIRED", &
		"", "Daily Dues Flag is Required", FALSE)

This.of_AddValidationRule({"admin_fee_flag"}, "REQUIRED", &
		"", "Admin Fee Flag is Required", FALSE)

This.of_AddValidationRule({"loa_taxable_flag"}, "REQUIRED", &
		"", "LOA Taxable Flag is Required", FALSE)

This.of_AddValidationRule({"permit_fee_flag"}, "REQUIRED", &
		"", "Permit Fee Flag is Required", FALSE)
		
This.of_AddValidationRule({"employee_rrsp_percent"}, "REQUIRED", &
		"", "Employee RRSP percent is Required", FALSE)

This.of_AddValidationRule({"tax_province"}, "EXPRESSION", &
"(Trim(<<employment_type>>) = 'Y' AND  (Trim(<<tax_province>>) <> '')) OR (Trim(<<employment_type>>) = 'S' AND  (Trim(<<tax_province>>) <> '')) OR (Trim(<<employment_type>>) <> 'Y' AND  (Trim(<<tax_province>>) = ''))", "Tax Province is required if employment type = 'Y'", FALSE)

This.of_AddValidationRule({"pay_pension_to_cash_flag"}, "EXPRESSION", &
		"Trim(<<pay_pension_to_cash_flag>>) = 'Y' or Trim(<<pay_pension_to_cash_flag>>) = 'N'", "Pay pension to cash? should be Y or N", FALSE)																		

This.of_AddValidationRule({"admin_fee_flag"}, "EXPRESSION", &
		"Trim(<<admin_fee_flag>>) = 'Y' or Trim(<<admin_fee_flag>>) = 'N'", "Admin fee flag should be Y or N", FALSE)																		

This.of_AddValidationRule({"cpp_exempt_flag"}, "EXPRESSION", &
		"Trim(<<cpp_exempt_flag>>) = 'Y' or Trim(<<cpp_exempt_flag>>) = 'N'", "CPP exempt? should be Y or N", FALSE)	

This.of_AddValidationRule({"daily_dues_flag"}, "EXPRESSION", &
		"Trim(<<daily_dues_flag>>) = 'Y' or Trim(<<daily_dues_flag>>)= 'N'", "Daily dues? should be Y or N", FALSE)	
		
This.of_AddValidationRule({"ei_exempt_flag"}, "EXPRESSION", &
		"Trim(<<ei_exempt_flag>>) = 'Y' or Trim(<<ei_exempt_flag>>) = 'N'", "EI exempt? should be Y or N", FALSE)	

This.of_AddValidationRule({"employment_type"}, "EXPRESSION", &
		"Trim(<<employment_type>>) = 'U' or Trim(<<employment_type>>) = 'S' or Trim(<<employment_type>>) = 'N' or Trim(<<employment_type>>) = 'Y'", "Employment type should be Y, N, S or U", FALSE)	

This.of_AddValidationRule({"shift"}, "EXPRESSION", &
		"Trim(<<shift>>) = '1' or Trim(<<shift>>) = '2' or Trim(<<shift>>) = '3'" , "Shift should be 1, 2 or 3 only", FALSE)	

This.of_AddValidationRule({"file_type"}, "EXPRESSION", &
		"Trim(<<file_type>>) = 'H' or Trim(<<file_type>>) = 'C'", "File Type is Invalid", FALSE)	

This.of_AddValidationRule({"garnishee_flag"}, "EXPRESSION", &
		"Trim(<<garnishee_flag>>) = 'Y' or Trim(<<garnishee_flag>>) = 'N'", "Garnishee? should be Y or N", FALSE)	

This.of_AddValidationRule({"income_tax_exempt_flag"}, "EXPRESSION", &
		"Trim(<<income_tax_exempt_flag>>) = 'Y' or Trim(<<income_tax_exempt_flag>>) = 'N'", "Income tax exempt? should be Y or N", FALSE)	

This.of_AddValidationRule({"job"}, "EXPRESSION", &
		"(TRIM(<<gl_account>>) = '' and TRIM(<<job>>) = '') OR  (LEN(TRIM(<<gl_account>>)) = 0 and LEN(TRIM(<<job>>)) > 0) OR (LEN(TRIM(<<job>>)) = 0 and LEN(TRIM(<<gl_account>>)) > 0)" , "Employee has both gl account and job", FALSE)	

This.of_AddValidationRule({"centre"}, "EXPRESSION", &
		"(TRIM(<<area>>) = '' and TRIM(<<centre>>) = '') OR  (LEN(TRIM(<<area>>)) = 0 and LEN(TRIM(<<centre>>)) = 0) OR (LEN(TRIM(<<area>>)) > 0 and LEN(TRIM(<<centre>>)) > 0)" , "Area and Centre is Required", FALSE)	
		
This.of_AddValidationRule({"gl_account"}, "EXPRESSION", &
		"(TRIM(<<gl_account>>) = '' and TRIM(<<job>>) = '') OR  (LEN(TRIM(<<gl_account>>)) = 0 and LEN(TRIM(<<job>>)) > 0) OR (LEN(TRIM(<<job>>)) = 0 and LEN(TRIM(<<gl_account>>)) > 0)" , "Employee has both gl account and job", FALSE)	

This.of_AddValidationRule({"loa_taxable_flag"}, "EXPRESSION", &
		"Trim(<<loa_taxable_flag>>) = 'Y' or Trim(<<loa_taxable_flag>>) = 'N'", "LOA taxable? should be Y or N", FALSE)	


This.of_AddValidationRule({"reduced_tax_earning_per_ck"}, "EXPRESSION", &
		"<<reduced_tax_earning_per_ck>> >= 0 AND <<reduced_tax_earning_per_ck>> <= 2000", "Reduce Tax Earnings Must be Between 0 AND 2,000", FALSE)	

This.of_AddValidationRule({"recruitment_12_month_maximum"}, "EXPRESSION", &
		"<<recruitment_12_month_maximum>> >= 0 AND <<recruitment_12_month_maximum>> <= 9999.99", "Recruitment 12 month maximum must be between 0 AND 9999.99", FALSE)	

This.of_AddValidationRule({"local_hire_flag"}, "EXPRESSION", &
		"Trim(<<local_hire_flag>>) = 'Y' or Trim(<<local_hire_flag>>) = 'N'", "Local hire? should be Y or N", FALSE)	

This.of_AddValidationRule({"mileage_taxable_flag"}, "EXPRESSION", &
		"Trim(<<mileage_taxable_flag>>) = 'Y' or Trim(<<mileage_taxable_flag>>) = 'N'", "Mileage taxable? should be Y or N", FALSE)	

This.of_AddValidationRule({"other_incentive_to_rrsp_flag"}, "EXPRESSION", &
		"Trim(<<other_incentive_to_rrsp_flag>>) = 'Y' or Trim(<<other_incentive_to_rrsp_flag>>) = 'N'", "Other incentive to RRSP? should be Y or N", FALSE)	

This.of_AddValidationRule({"permit_fee_flag"}, "EXPRESSION", &
		"Trim(<<permit_fee_flag>>) = 'Y' or Trim(<<permit_fee_flag>>) = 'N'", "Permit fee? should be Y or N", FALSE)	

This.of_AddValidationRule({"restrict_flag"}, "EXPRESSION", &
		"<<restrict_flag>> IN ('Y', 'N')", "Restrict? should be Y or N", FALSE)	

This.of_AddValidationRule({"safety_to_rrsp_flag"}, "EXPRESSION", &
		"Trim(<<safety_to_rrsp_flag>>) = 'Y' or Trim(<<safety_to_rrsp_flag>>) = 'N'", "Safety to RRSP? should be Y or N", FALSE)	

This.of_AddValidationRule({"site_allow_taxable_flag"}, "EXPRESSION", &
		"Trim(<<site_allow_taxable_flag>>) = 'Y' or Trim(<<site_allow_taxable_flag>>) = 'N'", "Site allow taxable? should be Y or N", FALSE)	

This.of_AddValidationRule({"federal_td1_claim"}, "EXPRESSION", &
		"<<federal_td1_claim>> >= 7000 OR <<federal_td1_claim>> = 0", "Federal TD1 should be 0 or greater than or equal to 7000", FALSE)	
		
This.of_AddValidationRule({"federal_zone_deduction"}, "EXPRESSION", &
		"<<federal_zone_deduction>> >= 0 and  <<federal_zone_deduction>> <= 8000", "Zone deduction must be between 0 to 8000", FALSE)	

This.of_AddValidationRule({"vacation_percent"}, "EXPRESSION", &
		"<<vacation_percent>> >= 0 and <<vacation_percent>> <= 30", "Vacation Percent should be between 0 to 30", FALSE)	

This.of_AddValidationRule({"statutory_percent"}, "EXPRESSION", &
		"<<statutory_percent>> >= 0 and <<statutory_percent>> <= 15", "Statutory Percent should be between 0 to 15", FALSE)	

This.of_AddValidationRule({"employer_rrsp_percent"}, "EXPRESSION", &
		"<<employer_rrsp_percent>> >= 0 and <<employer_rrsp_percent>> <= 10", "Employer RRSP Percent should be between 0 to 10", FALSE)	

This.of_AddValidationRule({"training_percent"}, "EXPRESSION", &
		"<<training_percent>> >= 0 and <<training_percent>> <= 10", "Training Percent should be between 0 to 10", FALSE)	

This.of_AddValidationRule({"staff_safety_percent"}, "EXPRESSION", &
		"<<staff_safety_percent>> >= 0 and <<staff_safety_percent>> <= 10", "Staff Safety Percent should be between 0 to 10", FALSE)	

This.of_AddValidationRule({"smtc_percent"}, "EXPRESSION", &
		"<<smtc_percent>> >= 0 and <<smtc_percent>> <= 10", "SMTC Percent should be between 0 to 10", FALSE)	

This.of_AddValidationRule({"employee_pension_percent"}, "EXPRESSION", &
		"<<employee_pension_percent>> >= 0 and <<employee_pension_percent>> <= 5", "Employee Pension Percent should be between 0 to 5", FALSE)	

This.of_AddValidationRule({"last_month_of_dues"}, "EXPRESSION", &
		"IF(<<last_month_of_dues>> = '',1,0) = 1 OR IsNumber(<<last_month_of_dues>>)", "Monthly Dues Paid should be Numeric", FALSE)	

This.of_AddValidationRule({"last_monthly_remit_month"}, "EXPRESSION", &
		"IF(<<last_monthly_remit_month>> = '',1,0) = 1 OR IsNumber(<<last_monthly_remit_month>>)", "Last Monthly Remittance should be Numeric", FALSE)	

This.of_AddValidationRule({"last_taxable_benefit_month"}, "EXPRESSION", &
		" (IF(<<last_taxable_benefit_month>> = '',1,0) = 1) OR  " + &
		" ( RIGHT(<<last_taxable_benefit_month>>,2) in ( '01','02','03','04','05','06','07','08','09','10','11','12') AND LONG(LEFT(<<last_taxable_benefit_month>>,4)) >= 1900)", "Last Taxable Benefit Month format should be YYYYMM", FALSE)	
		
This.of_AddValidationRule({"last_month_of_dues"}, "EXPRESSION", &
		" (IF(<<last_month_of_dues>> = '',1,0) = 1) OR  " + &
		" ( RIGHT(<<last_month_of_dues>>,2) in ( '01','02','03','04','05','06','07','08','09','10','11','12') AND LONG(LEFT(<<last_month_of_dues>>,4)) >= 1900)", "Monthly Dues Paid format should be YYYYMM", FALSE)	
		
This.of_AddValidationRule({"incentive_percent"}, "EXPRESSION", &
		"<<incentive_percent>> >= 0 and <<incentive_percent>> <= 25", "Incentive Percent should be between 0 to 10", FALSE)	

This.of_AddValidationRule({"loa_rate"}, "EXPRESSION", &
		"<<loa_rate>> >= 0 and <<loa_rate>> <= 50", "Loa Rate should be between 0 to $50 per LOA hour", FALSE)	

This.of_AddValidationRule({"mileage_rate"}, "EXPRESSION", &
		"<<mileage_rate>> >= 0 and <<mileage_rate>> <= 30", "Mileage rate should be between 0 to $30 per mileage hour", FALSE)	

This.of_AddValidationRule({"provincial_td1_claim"}, "EXPRESSION", &
		"<<provincial_td1_claim>> >= 7000 OR <<provincial_td1_claim>> = 0", "Provincial TD1 should be 0 or greater than or equal to 7000", FALSE)	

This.of_AddValidationRule({"termination_date"}, "EXPRESSION", &
		"<<hire_date>> <= <<termination_date>> OR (<<termination_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000')))", "Termination Date must be after Hire Date", FALSE)	
		
This.of_AddValidationRule({"loa_change_date"}, "EXPRESSION", &
		"<<file_type>> = 'H' OR <<hire_date>> <= <<loa_change_date>> OR (<<loa_change_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000')))", "LOA change date must be on or after Hire Date", FALSE)	

This.of_AddValidationRule({"termination_date"}, "EXPRESSION", &
		"(<<termination_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR DaysAfter(TODAY(),DATE(<<termination_date>>)) <= 0", "Termination Date cannot be in the future", FALSE)	

This.of_AddValidationRule({"termination_date"}, "EXPRESSION", &
		"(<<termination_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR  DaysAfter(Date(<<termination_date>>), Today()) <= 7300 OR <<file_type>> = 'H'", "Termination Date must be within the last 20 years", FALSE)	
		
This.of_AddValidationRule({"hire_date"}, "EXPRESSION", &
		"(<<hire_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR DaysAfter(TODAY(),DATE(<<hire_date>>)) <= 7", "Hire Date cannot be more than 7 days in the future", FALSE)	

This.of_AddValidationRule({"hire_date"}, "EXPRESSION", &
		"(<<hire_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR  DaysAfter(Date(<<hire_date>>), Today()) <= 14600", "Hire Date must be within the last 40 years", FALSE)	
		
This.of_AddValidationRule({"job_based_wcb_class"}, "EXPRESSION", &
		"Trim(<<job_based_wcb_class>>) <> ''", "WCB from job cannot be blank", FALSE)	

This.of_AddValidationRule({"wcb_class"}, "EXPRESSION", &
		"(<<job_based_wcb_class>> = 'N' AND Trim(<<wcb_class>>) <> '') OR <<job_based_wcb_class>> = 'Y'", '"WCB class" cannot be blank when "WCB from job" is N', FALSE)	

This.of_AddValidationRule({"employee_rrsp_percent"}, "EXPRESSION", &
		"<<employee_rrsp_percent>> >= 0 and <<employee_rrsp_percent>> <= 10", "Employee RRSP Percent should be between 0 to 10", FALSE)	
		
This.of_AddValidationRule({"eft_account"}, "EXPRESSION", &
		"      (TRIM(<<eft_institution>>) = '' AND TRIM(<<eft_us_routing>>) = '' and TRIM(<<eft_branch>>) = '' and TRIM(<<eft_account>>) = '') "						&
		+ " OR (LEN(TRIM(<<eft_institution>>)) = 0 AND LEN(TRIM(<<eft_us_routing>>)) = 0 AND LEN(TRIM(<<eft_branch>>)) = 0 AND LEN(TRIM(<<eft_account>>)) = 0) "	&
		+ " OR (LEN(TRIM(<<eft_institution>>)) > 0 AND LEN(TRIM(<<eft_branch>>)) > 0 AND LEN(TRIM(<<eft_account>>)) > 0)"  													&
		+ " OR (LEN(TRIM(<<eft_us_routing>>)) > 0 AND LEN(TRIM(<<eft_account>>)) > 0)" , &
		"Either Institution, Branch and Account, or US routing and Account, are Required", TRUE)	
		
This.of_AddValidationRule({"weekly_dues_flag"}, "EXPRESSION", &
		"Trim(<<weekly_dues_flag>>) = 'Y' or Trim(<<weekly_dues_flag>>) = 'N'", "Weekly Dues? should be Y or N", FALSE)	

This.of_AddValidationRule({"recruitment_hourly_fee"}, "EXPRESSION", &
		"(<<recruitment_hourly_fee>> >= 0.01 and <<recruitment_hourly_fee>> <= 9.99) or <<recruitment_hourly_fee>> = 0", "Recruitment fee must be between 0.01 to 9.99", FALSE)	

This.of_AddValidationRule({"recruitment_12_month_maximum"}, "EXPRESSION", &
		"<<recruitment_12_month_maximum>> >= 0 and <<recruitment_12_month_maximum>> <= 10000", "The 12 month maximum may not be greater than 10,000", FALSE)	

This.of_AddValidationRule({"eft_email_address"}, "EXPRESSION", &
		"Pos(<<eft_email_address>>, ',') = 0 and Pos(<<eft_email_address>>, ';') = 0", "Email addresses can't contain commas or semi-colons", TRUE)	

// Default Values
This.of_setcolumndefault('weekly_dues_flag', 'N')
This.of_setcolumndefault('tax_province', gnv_app.of_get_company_province())
This.of_setcolumndefault('hire_date', "TODAY")
This.of_setcolumndefault('vacation_percent', '0')
This.of_setcolumndefault('cpp_exempt_flag', 'N')
This.of_setcolumndefault('ei_exempt_flag', 'N')
This.of_setcolumndefault('qpip_exempt_flag', 'N')
This.of_setcolumndefault('loa_taxable_flag', 'N')
This.of_setcolumndefault('mileage_taxable_flag', 'Y')
This.of_setcolumndefault('admin_fee_flag', 'N')

This.of_setcolumndefault('shift', '1')
This.of_setcolumndefault('site_allow_taxable_flag', 'Y')
This.of_setcolumndefault('employment_type', 'Y')

This.of_setcolumndefault('admin_fee_flag', 'N')
This.of_setcolumndefault('garnishee_flag', 'N')
This.of_setcolumndefault('other_incentive_to_rrsp_flag', 'N')
This.of_setcolumndefault('daily_dues_flag', 'N')
This.of_setcolumndefault('pay_pension_to_cash_flag', 'N')

This.of_setcolumndefault('permit_fee_flag', 'N')
This.of_setcolumndefault('income_tax_exempt_flag', 'N')
This.of_setcolumndefault('local_hire_flag', 'N')

This.of_setcolumndefault('restrict_flag', 'N')
This.of_setcolumndefault('file_type', 'C')
This.of_setcolumndefault('safety_to_rrsp_flag', 'N')

This.of_setcolumndefault('federal_zone_deduction', '0')
This.of_setcolumndefault('federal_td1_claim', '0')
This.of_setcolumndefault('provincial_td1_claim', '0')
This.of_setcolumndefault('add_income_tax_per_ck', '0')
This.of_setcolumndefault('statutory_percent', '0')

This.of_setcolumndefault('employer_rrsp_percent', '0')
This.of_setcolumndefault('staff_safety_percent', '0')
This.of_setcolumndefault('smtc_percent', '0')
This.of_setcolumndefault('incentive_percent', '0')

This.of_setcolumndefault('training_percent', '0')

This.of_setcolumndefault('loa_rate', '0')
This.of_setcolumndefault('mileage_rate', '0')
This.of_setcolumndefault('employee_rrsp_per_ck', '0')
This.of_setcolumndefault('mileage_rate', 'N')
This.of_setcolumndefault('taxable_benefit_per_ck', '0')
This.of_setcolumndefault('taxable_benefit_per_month', '0')

This.of_setcolumndefault('charity_per_ck', '0')
This.of_setcolumndefault('next_travel_amt', '0')
This.of_setcolumndefault('turnaround_cycle_days', '0')
This.of_setcolumndefault('next_turnaround_amt', '0')


This.of_setcolumndefault('dues_per_month', '0')
This.of_setcolumndefault('admin_fee', '0')
This.of_setcolumndefault('security_deposit', '0')
This.of_setcolumndefault('training', '0')
This.of_setcolumndefault('advance_repay', '0')

This.of_setcolumndefault('vacation_owed', '0')
This.of_setcolumndefault('statutory_owed', '0')
This.of_setcolumndefault('personal_safety_owed', '0')
This.of_setcolumndefault('group_safety_owed', '0')
This.of_setcolumndefault('staff_safety_owed', '0')

This.of_setcolumndefault('smtc_owed', '0')
This.of_setcolumndefault('retention_owed', '0')
This.of_setcolumndefault('incentive_owed', '0')
This.of_setcolumndefault('smtc_owed', '0')

This.of_setcolumndefault('book', trim(gnv_app.is_book))
This.of_setcolumndefault('add_user_id', gnv_app.of_getuserid())
This.of_setcolumndefault('add_datetime', 	"TODAY" )
This.of_setcolumndefault('job_based_wcb_class', 	'N' )

This.of_setcolumndefault('employee_rrsp_percent', '0')


// Add DB Constraints
This.of_AddDBConstraint("pk_employee", "employee", "Employee", "")
This.of_AddDBConstraint("fk_employee__book", "employee", &
		"Book", "Book")
This.of_AddDBConstraint("fk_employee__centre", "employee", &
		"Centre", "Centre")
This.of_AddDBConstraint("fk_employee__job", "employee", &
		"Job", "Job")
		
This.of_AddDBConstraint("fk_employee__crew", /* Constraint name */ 					&
		"job", 						/* Column to receive focus if constraint fails */ 	&
		"Job/Crew not found", 	/* Message to display if constraint fails */			&
		"Crew") 						/* Table referenced by constraint if foreign key */
		
This.of_AddDBConstraint("cc_employee__gl_account", "gl_account", &
		"Account not setup for the current fiscal year in the G/L account table", "Employee")


This.of_AddDBConstraint("fk_employee__occupation", /* Constraint name */ 									&
		"occupation", 									/* Column to receive focus if constraint fails */ 		&
		"Trade Union/Occupation not found", 	/* Message to display if constraint fails */				&
		"Occupation") 									/* Table referenced by constraint if foreign key */
		
This.of_AddDBConstraint("fk_employee__dues_vendor", /* Constraint name */ 									&
		"dues_vendor", 								/* Column to receive focus if constraint fails */ 		&
		"Dues vendor not found", 					/* Message to display if constraint fails */				&
		"vendor") 										/* Table referenced by constraint if foreign key */
		
This.of_AddDBConstraint("fk_employee__person__supervisor", "employee", &
		"Supervisor", "Supervisor")
		
This.of_AddDBConstraint("fk_employee__person", "employee", &
		"Person", "Person")		
This.of_AddDBConstraint("fk_employee__province_state", "employee", &
		"Province_State", "Province_State")
This.of_AddDBConstraint("fk_employee__roe_reason", "employee", &
		"ROE Reason", "ROE Reason")
This.of_AddDBConstraint("fk_employee__shift_pattern", "employee", &
		"Shift Pattern", "Shift Pattern")
This.of_AddDBConstraint("fk_employee__rrsp_vendor", "employee", &
		"Vendor", "Vendor")
This.of_AddDBConstraint("fk_employee__subcontractor_vendor", "employee", &
		"Vendor", "Vendor")
This.of_AddDBConstraint("fk_employee__wcb_class", "employee", &
		"WCB Class", "WCB Class")

//References employee
This.of_AddDBConstraint("fk_employee_earning__employee", "employee", &
		"Employee", "Employee Earning")	
This.of_AddDBConstraint("fk_timesheet__employee", "employee", &
		"Employee", "Timesheet")	
This.of_AddDBConstraint("fk_tm_employee_rate__employee", "employee", &
		"Employee", "T&M Employee Rate")	
This.of_AddDBConstraint("fk_tm_employee_rate__employee", "employee", &
		"Employee", "T&M Employee Rate")	
		
	
//Add related tables so that when employee updates, it can update related tables within the transaction set
this.of_AddChild("employee_premium", 	"n_bo_employee_premium")
this.of_AddChild("person", 				"n_bo_person")
this.of_AddChild("person_diary", 		"n_bo_person_diary")
this.of_AddChild("timesheet", 			"n_bo_timesheet")
this.of_AddChild("pr_cheque", 			"n_bo_pr_cheque")
this.of_AddChild("crew_member", 			"n_bo_crew_member")
this.of_AddChild("earning", 				"n_bo_employee_earning")
this.of_AddChild("wcb", 					"n_bo_employee_wcb")



end event

event bo_rowinserted;call super::bo_rowinserted;//************************************************************
// Object   :	n_bo_employee 
// Event    :	bo_rowinserted
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	long al_row
// 	
// Returns:		(None)
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
Decimal						ldec_federal_td1_claim
Decimal						ldec_provincial_td1_claim
Long							ll_rc
String						ls_province
String						ls_null
String						ls_pr_yyyymm
DateTime						ldt_pr_yyyymm
n_bo_federal_tax			lbo_federal_tax
n_bo_province_rate		lbo_provincial_tax
n_bo_company				lbo_company


SetNull(ls_null)

IF al_row > 0 THEN

	// if employment_type = 'Y' THEN set provincial and federal tax
	IF This.of_GetItemString(al_row,"employment_type") = 'Y' THEN
			
		// get the current payroll G/L period
		// -- it may be December, but if you've already rolled payroll into January,
		//    then all the TD1's have been set to the minimum for the new year
		//    and if you use last year's it will have to be manually fixed,
		//    so use the next year's minimum TD1 claims
		lbo_company = CREATE n_bo_company
		lbo_company.of_SetTransaction()
		IF lbo_company.of_Retrieve("book = '" + gnv_app.is_book + "'") = 1 THEN
			ls_pr_yyyymm = lbo_company.of_GetItemString(1, 'pr_yyyymm')
			ldt_pr_yyyymm = DateTime(Date(Integer(Left(ls_pr_yyyymm, 4)), Integer(Right(ls_pr_yyyymm, 2)), 1), Time(0,0,0))
		ELSE
			ldt_pr_yyyymm = Datetime(Today(),Now())
		END IF
		DESTROY lbo_company

		// set federal td1 claim
		lbo_federal_tax = CREATE n_bo_federal_tax
		lbo_federal_tax.of_SetTransaction()
		ll_rc = lbo_federal_tax.of_get_federal_td1_claim(ldt_pr_yyyymm, &
																		 ldt_pr_yyyymm, &
																		 'C', &
																		 ldec_federal_td1_claim)
		IF ll_rc = 1 THEN
		  // success,
		  This.of_SetItem(al_row,"federal_td1_claim",ldec_federal_td1_claim)
		END IF
		
		
		// set provincial tax
		ls_province = This.of_GetItemString(al_row,"tax_province")
		lbo_provincial_tax = CREATE n_bo_province_rate
		lbo_provincial_tax.of_SetTransaction()
		ll_rc = lbo_provincial_tax.of_get_provincial_td1_claim(ls_province, &
																				 ldt_pr_yyyymm, &
																				 ldt_pr_yyyymm, &
																				 'C', &
																				 ldec_provincial_td1_claim)
		IF ll_rc = 1 THEN
		  // success,
		  This.of_SetItem(al_row,"provincial_td1_claim",ldec_provincial_td1_claim)
		END IF 
		
	ELSE
		This.of_SetItem(al_row,"federal_td1_claim",0)
		This.of_SetItem(al_row,"provincial_td1_claim",0)
		This.of_SetItem(al_row,"tax_province",ls_null)
		
	END IF		
END IF	

DESTROY lbo_federal_tax
DESTROY lbo_provincial_tax
end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_employee 
// Event    :	bo_validate
// Author   :	Lourdes Garcia
// Date     :	2009/04/23
// 	
// Arguments:	long al_row
// 				string as_column
// 				string as_value
// 	
// Return:	Integer - 1=Success, -1=Failure
// 	
// Desc:			Advanced Validation
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
Int				li_rc = 1
Long				ll_employee, &
			      ll_row, &
					ll_column, ll_column_count, ll_count
					
String			ls_vendor, &
				   ls_employment_type, &
					ls_vendor_gst, &
					ls_gst, &
					ls_trade_union, &
					ls_book, &
					ls_other_incentive_flag, &
					ls_safety_rrsp_flag, &
					ls_staff_flag, &
					ls_action

DateTime			ldt_hire_date

Date				ldt_turnaround_date, &
					ldt_travel_date, &
					ld_pp_start, ld_65, ld_70
					
Decimal			ldc_employee_rrsp, &
					ldc_employer_rrsp_pct

DwItemStatus	ldwis_status

n_bo_vendor		lbo_vendor
n_bo_trade_union			lbo_trade_union
n_bo_occupation_rate		lbo_occupation_rate
n_bo_company				lbo_company

ldwis_status = This.of_GetItemStatus(al_row, 0, Primary!)

/*
This.of_AddValidationRule({"cpp_exempt_effective_date"}, "EXPRESSION", &
		"(<<cpp_exempt_effective_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) " &
		+ " OR (DaysAfter(DATE(<<birth_date>>),DATE(<<cpp_exempt_effective_date>>)) >= 23725)", "CPP Exemption must begin after employee turns 65", FALSE)	

This.of_AddValidationRule({"cpp_exempt_effective_date"}, "EXPRESSION", &
		"(<<cpp_exempt_effective_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) " &
		+ " OR (DaysAfter(DATE(<<birth_date>>),DATE(<<cpp_exempt_effective_date>>)) <= 25550 )", "CPP Exemption must begin before employee turns 70", FALSE)	

*/

IF as_column = 'cpp_exempt_effective_date' THEN
	
	IF Len(as_value) > 0 AND Left(as_value, 4) <> '1900' THEN
		IF Not(IsValid(ibo_person)) THEN
			ibo_person = CREATE n_bo_person
			ibo_person.of_SetTransaction()
		END IF
		
		IF ibo_person.of_Retrieve("employee = " + String(this.of_GetItemNumber(al_row, 'employee'))) = 1 THEN
			
			//Employee must be older than 65
			ld_65 = gnv_app.inv_datetime.of_RelativeYear(Date(ibo_person.of_GetItemDateTime(1, 'birth_date')), 65)
			IF Date(as_value) <= ld_65 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "CPP Exemption must begin after employee turns 65 on " + String(ld_65, 'yyyy.mm.dd'))
			END IF
			
			//Employee must be younger than 70
			ld_70 = gnv_app.inv_datetime.of_RelativeYear(Date(ibo_person.of_GetItemDateTime(1, 'birth_date')), 70)
			IF Date(as_value) >= ld_70 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "CPP Exemption must begin before employee turns 70 on " + String(ld_70, 'yyyy.mm.dd'))
			END IF
		END IF
	END IF
	
END IF

//Jira 1658:  Check if there are current occupation_rates
IF as_column = "occupation" AND (ldwis_status = New! OR ldwis_status = NewModified!) THEN 
	
		IF NOT IsValid(lbo_occupation_rate) THEN 
			lbo_occupation_rate = CREATE n_bo_occupation_rate
			lbo_occupation_rate.of_SetTransaction()
		END IF

		ls_trade_union = This.of_GetItemString(al_row,"trade_union")
		ls_book = This.of_GetItemString(al_row,"book")
		
		IF lbo_occupation_rate.of_current_occupation_rate(ls_book, ls_trade_union,string(as_value),DateTime(TODAY(),Now())) = FALSE THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Occupation " + as_value + " does not have an occupation rate effective " + String(Today(), 'yyyy.mm.dd') + ".")
		END IF			
END IF

/*IF as_column = 'roe_note' THEN
	ls_roe = this.of_GetItemString(al_row,"roe_reason_code")
	IF TRIM(as_value) = "" and ls_roe = 'K' THEN
		li_rc = -1
		This.of_AddValidationError(al_row, as_column, Primary!, "'' (space) is an Invalid Roe Notes value.")
	END IF
END IF*/
		

// if employment type = 'S', person.ccra_business_no = vendor.ccra_business_no
IF as_column = "employment_type"  THEN
	
	IF this.of_GetItemStatus(al_row,"employment_type",Primary!) = DataModified! THEN
		ll_employee = this.of_GetItemNumber(al_row,"employee")
		ls_employment_type = as_value
		ls_vendor = this.of_GetItemString(al_row,"subcontractor_vendor")
		//ls_gst = ids_data.GetItemString(al_row,"gst")
		
		IF ls_employment_type = 'S' THEN

			// get GST# from vendor
			lbo_vendor = CREATE n_bo_vendor
			lbo_vendor.of_SetTransaction()
			IF NOT IsNull(ls_vendor) AND ls_vendor <> "" AND ll_employee <> 0 THEN
				ll_row = lbo_vendor.of_Retrieve("book = '" + gnv_app.of_get_book() + "' and vendor = '" + ls_vendor + "'")
				IF ll_row > 0 THEN
					ls_vendor_gst = LEFT(lbo_vendor.of_GetItemString(ll_row,"ccra_business_no"),9)
				ELSE
					li_rc = -1
					This.of_AddValidationError(al_row, as_column, Primary!, ls_vendor + " Not in Vendor table")
				END IF
				
			END IF	
		END IF		
	END IF	
END IF	

IF as_column = "rrsp_vendor" THEN
	IF this.of_GetItemStatus(al_row,"rrsp_vendor",Primary!) = DataModified! THEN
		ls_vendor = as_value
		
		ls_employment_type = This.of_GetItemString(al_row,"employment_type")
		ldc_employee_rrsp = This.of_GetItemDecimal(al_row,"employee_rrsp_per_ck")
		ldc_employer_rrsp_pct = This.of_GetItemDecimal(al_row,"employer_rrsp_percent")
		ls_safety_rrsp_flag = This.of_GetItemString(al_row,"safety_to_rrsp_flag")
		ls_other_incentive_flag = This.of_GetItemString(al_row,"other_incentive_to_rrsp_flag")
		ls_trade_union = This.of_GetItemString(al_row,"trade_union")
		ls_book = This.of_GetItemString(al_row,"book")
		
		IF NOT IsValid(lbo_trade_union) THEN 
			lbo_trade_union = CREATE n_bo_trade_union
			lbo_trade_union.of_SetTransaction()
		END IF
		
		ls_staff_flag = lbo_trade_union.of_get_staff_flag(ls_book,ls_trade_union)
		
		
		IF (ls_employment_type = 'Y' AND &
			 (ls_safety_rrsp_flag = 'Y' OR  ls_other_incentive_flag = 'Y' OR ldc_employee_rrsp <> 0 OR ldc_employer_rrsp_pct <> 0) and  &
			 ls_staff_flag = 'Y') THEN
				IF LEN(ls_vendor) = 0 THEN
					// subcontractor vendor is required
					li_rc = -1
					This.of_AddValidationError(al_row, as_column, Primary!, "RRSP Vendor is Required")
				END IF
			END IF
		
	END IF	
END IF


IF as_column = "subcontractor_vendor"  THEN
	
	//Bypass editting this column in 'z' mode, but be careful when it's being updated from someplace other than the data entry screen
	ls_action = ''
	ll_column_count = Long(ids_data.Object.DataWindow.Column.Count)
	FOR ll_column = 1 TO ll_column_count
		IF Upper(ids_data.Describe("#" + String(ll_column) + ".Name")) = 'ACTION' THEN
			ls_action = this.of_GetItemString(1, 'action')
			EXIT
		END IF
	NEXT
	
	IF this.of_GetItemStatus(al_row,"subcontractor_vendor",Primary!) = DataModified! AND ls_action <> 'Z' THEN
		ll_employee = this.of_GetItemNumber(al_row,"employee")
	
		ls_vendor = as_value
		
		
		
		ls_employment_type = this.of_GetItemString(al_row,"employment_type")

		IF ls_employment_type = 'S' THEN
			
			IF LEN(ls_vendor) = 0 THEN
				// subcontractor vendor is required
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Subcontractor Vendor is Required")
			END IF


			// get employee# from vendor - moved to entry screen so it doesn't prevent person renumber
//			lbo_vendor = CREATE n_bo_vendor
//			lbo_vendor.of_SetTransaction()
//			IF NOT IsNull(ls_vendor) AND ls_vendor <> "" AND ll_employee <> 0 THEN
//				ll_row = lbo_vendor.of_Retrieve("book = '" + gnv_app.of_get_book() + "' and vendor = '" + ls_vendor + "'")
//				IF ll_row > 0 THEN
//					ll_vendor_employee =  lbo_vendor.of_GetItemNumber(ll_row,"employee")
//				ELSE
//					li_rc = -1
//					This.of_AddValidationError(al_row, as_column, Primary!, ls_vendor + " Not in Vendor table")
//				END IF
//				
//				
//				// compare the employee -- Take out for now because it causes issues with person renumber.
//				IF ll_vendor_employee <> ll_employee THEN
//					li_rc = -1
//					This.of_AddValidationError(al_row, as_column, Primary!, "Employee does not agree with the associated vendor's employee")
//				END IF
//			END IF	
		END IF		
	END IF
END IF		


IF as_column = 'gst' THEN					
	ll_employee = this.of_GetItemNumber(al_row,"employee")
	ls_vendor = this.of_GetItemString(al_row,"subcontractor_vendor")
	ls_employment_type = this.of_GetItemString(al_row,"employment_type")
	ls_gst = as_value
	IF ls_employment_type = 'S' THEN

			// get GST# from vendor
			lbo_vendor = CREATE n_bo_vendor
			lbo_vendor.of_SetTransaction()
			IF NOT IsNull(ls_vendor) AND ls_vendor <> "" AND ll_employee <> 0 THEN
				ll_row = lbo_vendor.of_Retrieve("book = '" + gnv_app.of_get_book() + "' and vendor = '" + ls_vendor + "'")
				IF ll_row > 0 THEN
					ls_vendor_gst = LEFT(lbo_vendor.of_GetItemString(ll_row,"ccra_business_no"),9)
				ELSE
					li_rc = -1
					This.of_AddValidationError(al_row, as_column, Primary!, ls_vendor + " Not in Vendor table")
				END IF
				
			END IF	
		END IF		
	END IF


/* remove from BO validation---> should only be part of employee entry screen on ADD and CHANGE */

/*IF as_column = "shift_start_date" THEN
		// get pattern and hire_date
		ls_shift_pattern = This.of_GetItemString(al_row,"shift_pattern_type")
		ldt_hire_date = This.of_GetItemDateTime(al_row,"hire_date")

		lbo_shift_pattern = CREATE n_bo_shift_pattern
		lbo_shift_pattern.of_SetTransaction()
		
		ldt_shift_start = lbo_shift_pattern.of_get_shift_start(ls_shift_pattern, ldt_hire_date)
		IF NOT IsNull(ldt_shift_start) THEN
			IF Date(Left(as_value, 10)) < DATE(ldt_shift_start) OR Date(Left(as_value, 10)) > TODAY() THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Shift Start Date must be between " + String(ldt_shift_start, 'yyyy.mm.dd')  + " and " + string(TODAY(), 'yyyy.mm.dd'))
			END IF	
		END IF	
	
END IF*/

/* Moved to Entry Screen */
/*IF as_column = "roe_reason_code" THEN
	// get termination_date
	ldt_termination_date = Date(This.of_GetItemDateTime(al_row,"termination_date"))
	ls_roe_code = as_value
	
	IF IsNull(ldt_termination_date) OR LEFT(STRING(ldt_termination_date,'yyyy.mm.dd'),10) = '1900.01.01' THEN
		IF NOT(IsNull(ls_roe_code) OR ls_roe_code = "")  THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Termination Date cannot be empty if there is a ROE Code")
		END IF
	ELSE
		IF IsNull(ls_roe_code) OR ls_roe_code = "" THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "ROE code is required if terminating an employee")
		END IF
	END IF
END IF	*/


	
IF as_column = "next_turnaround_due_date" THEN
	ldt_turnaround_date = Date(Left(as_value, 10))
		
	IF ldt_turnaround_date  <> DATE("1900.01.01") THEN
		// should be >= hire_date but less then 90 days for today
		ldt_hire_date = This.of_GetItemDateTime(al_row,"hire_date")
		IF NOT IsNull(ldt_hire_date) THEN
			IF ldt_turnaround_date < DATE(ldt_hire_date) OR  DaysAfter(Today(), ldt_turnaround_date) > 90 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Turnaround due must be between " + String(ldt_hire_date, 'yyyy.mm.dd')  + " and next 90 days")
			END IF
		END IF
	END IF
END IF



IF as_column = "next_travel_due_date" THEN
	ldt_travel_date = Date(Left(as_value, 10))
		
	IF ldt_travel_date  <> DATE("1900.01.01") THEN
		// should be >= hire_date but less then 90 days for today
		ldt_hire_date = This.of_GetItemDateTime(al_row,"hire_date")
		IF NOT IsNull(ldt_hire_date) THEN
			IF ldt_travel_date < DATE(ldt_hire_date) OR  DaysAfter(Today(), ldt_travel_date) > 90 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Travel due must be between " + String(ldt_hire_date, 'yyyy.mm.dd')  + " and next 90 days")
			END IF
		END IF
	END IF
END IF

//Not sure why we are so strict, but it is causing Kim at ISSL grief so we'll remove this
// jira 4923
//IF as_column = 'trade_union' THEN
//	IF as_value <> this.of_GetItemString(al_row, 'trade_union', Primary!, TRUE) THEN
//		
//		ll_employee = this.of_GetItemNumber(al_row,"employee")
//
//		IF NOT IsValid(lbo_company) THEN 
//			lbo_company = CREATE n_bo_company
//			lbo_company.of_SetTransaction()
//		END IF
//		
//		IF lbo_company.of_get_pp_start_date(as_value, ld_pp_start) <> 1 THEN
//			This.of_AddValidationError(al_row, as_column, Primary!, "Trade Union " + as_value + " is not valid.")
//			RETURN -1
//		END IF		
//		
//		//Are there any premiums on cheques for this pay period?
//		SELECT count(1)
//		  INTO :ll_count
//		  FROM pr_cheque, pr_cheque_premium
//		 WHERE pr_cheque.book = pr_cheque_premium.book
//		   AND pr_cheque.cheque_no = pr_cheque_premium.cheque_no
//			AND pr_cheque.pay_period_start_date >= :ld_pp_start
//			AND pr_cheque.employee = :ll_employee
//			AND pr_cheque.book = :gnv_app.is_book
//		 USING sqlca;
//		IF sqlca.sqlcode = -1 THEN
//			this.of_msg_db_error("Error counting cheque premiums")
//			RETURN -1
//		END IF
//		
//		IF ll_count > 0 THEN
//			This.of_AddValidationError(al_row, as_column, Primary!, "Trade Union can not change when cheques have been issued for the current pay period.")
//			RETURN -1
//		END IF		
//		
//	END IF
//END IF

IF IsValid(lbo_vendor) THEN DESTROY lbo_vendor
IF IsValid(lbo_trade_union) THEN DESTROY lbo_trade_union
IF IsValid(lbo_occupation_rate) THEN DESTROY lbo_occupation_rate

RETURN li_rc







end event

event bo_prerowdelete;call super::bo_prerowdelete;//************************************************************
// Object   :	n_bo_employee 
// Event    :	bo_prerowdelete
// Author   :	Lourdes Garcia
// Date     :	2009/05/01
// 	
// Arguments:	long al_row
// 	
// Returns:		boolean
// 	
// Desc:			Determine if Row can be deleted
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

n_bo_employee_earning		lbo_employee_earning
n_bo_timesheet					lbo_timesheet
n_bo_ap_invoice				lbo_ap_invoice
n_bo_employee_premium		lbo_employee_premium

Boolean							lb_return = TRUE
Long								ll_tax_year, &
									ll_employee, &
									ll_count
									
String							ls_book									

IF This.of_GetItemDecimal(al_row, 'vacation_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero vacation owed amount")
	lb_return = FALSE
END IF	

IF This.of_GetItemDecimal(al_row, 'advance_repay') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero advance repay amount")
	lb_return = FALSE
END IF

IF This.of_GetItemDecimal(al_row, 'statutory_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero statutory owed amount")
	lb_return = FALSE
END IF	

IF This.of_GetItemDecimal(al_row, 'personal_safety_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero personal safety owed amount")
	lb_return = FALSE
END IF	

IF This.of_GetItemDecimal(al_row, 'group_safety_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero group safety owed amount")
	lb_return = FALSE
END IF

IF This.of_GetItemDecimal(al_row, 'staff_safety_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero staff safety owed amount")
	lb_return = FALSE
END IF


IF This.of_GetItemDecimal(al_row, 'smtc_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero small tools owed amount")
	lb_return = FALSE
END IF

IF This.of_GetItemDecimal(al_row, 'retention_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero retention owed amount")
	lb_return = FALSE
END IF	

IF This.of_GetItemDecimal(al_row, 'incentive_owed') <> 0 THEN 
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero incentive owed amount")
	lb_return = FALSE
END IF

// further check employee_earning values
lbo_employee_earning = CREATE n_bo_employee_earning
lbo_employee_earning.of_SetTransaction()

ll_tax_year = Year(Today())
ll_employee = This.of_GetItemNumber(al_row,'employee')
ls_book = This.of_GetItemString(al_row,'book')

lbo_employee_earning.of_check_ytd_amounts_zero(ll_employee, ls_book, ll_tax_year, lb_return)
IF IsNull(lb_return) THEN lb_return = FALSE
IF lb_return = FALSE THEN
	This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. Non-zero year-to-date amounts")
END IF	
DESTROY lbo_employee_earning


// check if there are timesheet posted
IF lb_return THEN
	lbo_timesheet = CREATE n_bo_timesheet
	lbo_timesheet.of_SetTransaction()
	ll_count = lbo_timesheet.of_count("employee = " + string(ll_employee) +  &
									" and file_type = 'C' and book = '" + string(ls_book) + "'")
	IF ll_count > 0 THEN
		This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed. There are timesheet entries posted")
		lb_return = FALSE
	ELSE
		lb_return = TRUE
	END IF
	
	DESTROY lbo_timesheet
END IF	

// check if there are ap_invoice for the employee
IF lb_return THEN
	lbo_ap_invoice = CREATE n_bo_ap_invoice
	lbo_ap_invoice.of_SetTransaction()
	ll_count = lbo_ap_invoice.of_count("employee = " + string(ll_employee) +  &
									" and book = '" + string(ls_book) + "'")
	IF ll_count > 0 THEN
		This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed.There are accounts payable invoice entries posted")
		lb_return = FALSE
	ELSE
		lb_return = TRUE
	END IF
	
	DESTROY lbo_ap_invoice
END IF


// check if there are employee premiums
IF lb_return THEN
	lbo_employee_premium = CREATE n_bo_employee_premium
	lbo_employee_premium.of_SetTransaction()
	ll_count = lbo_employee_premium.of_count("employee = " + string(ll_employee) +  &
									" and book = '" + string(ls_book) + "'")
	IF ll_count > 0 THEN
		This.of_AddValidationError(al_row, "employee", Primary!, "Deletion Disallowed.There are employee premium records.")
		lb_return = FALSE
	ELSE
		lb_return = TRUE
	END IF
	
	DESTROY lbo_employee_premium
END IF


RETURN lb_return
end event

event bo_logauditdelta;//************************************************************
// Object   :	n_cst_business_abio 
// Event    :	bo_LogAuditDelta
// Author   :	Paul Bauermeister
// Date     :	2009/04/20
// 	
// Arguments:	dwbuffer ae_buffer
// 				long al_row
// 				REF string as_action_code
// 				REF string as_delta
// 	
// Returns:		boolean (override)
// 	
// Desc:			Determine whether the event is to be logged, and 
//					generate the delta values that need to be recorded
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
// May 25, 2009   L Garcia
// 		Extend to include computed columns and reemploY and Terminate actions
// July 17, 2009  L Garcia
//  		Add is_delta from generating supervisor affected employees
//------------------------------------------------------------
//
//************************************************************

String	ls_termination_delta

CHOOSE CASE as_action_code
	CASE "T"
		ls_termination_delta = of_get_termination_delta()
		IF LEN(TRIM(ls_termination_delta)) > 0 THEN as_delta = as_delta + " " + ls_termination_delta
	CASE "D"
		as_delta = ""
	CASE ELSE
		as_delta = This.of_GenerateDelta(ae_buffer, al_row)
END CHOOSE
		
RETURN TRUE

end event

event destructor;call super::destructor;//************************************************************
// Object   :	n_bo_employee 
// Event    :	destructor
// Author   :	Monica Petersen
// Date     :	2013/11/19
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

IF IsValid(ibo_person) THEN DESTROY ibo_person

		

end event

event bo_childcreated;call super::bo_childcreated;
IF Lower(as_child_id) = "earning" THEN
	This.ibo_employee_earning = abo_child_object
ELSEIF Lower(as_child_id) = "wcb" THEN
	This.ibo_employee_wcb = abo_child_object
END IF

end event

event bo_preupdate;call super::bo_preupdate;Long							ll_e_row, ll_w_row
Long							ll_row
String						ls_find, ls_wcb_class
String						ls_null

SetNull(ls_null)

DO
	ll_row = This.ids_data.GetNextModified(ll_row, Primary!)
	
	IF ll_row > 0 THEN
		
		//Make sure there's an earning entry for adding the YTD amounts (with the Z action)
		IF IsValid(ibo_employee_earning) THEN
			ls_find = "book = '" + gnv_app.is_book + "' AND employee = " + String(this.of_GetItemNumber(ll_row, "employee")) + " AND tax_year = '" + String(Year(Today())) + "'"
			ll_e_row =  ibo_employee_earning.of_Find(ls_find)
			IF ll_e_row < 1 THEN
				ibo_employee_earning.of_Retrieve(ls_find, TRUE /* append records */) 
				ll_e_row =  ibo_employee_earning.of_Find(ls_find)
			END IF
			
			IF ll_e_row = 0 THEN
				ll_e_row = ibo_employee_earning.of_InsertRow(0)
				ibo_employee_earning.of_SetItem(ll_e_row, 'book', gnv_app.is_book)
				ibo_employee_earning.of_SetItem(ll_e_row, 'employee', this.of_GetItemNumber(ll_row, "employee"))
				ibo_employee_earning.of_SetItem(ll_e_row, 'tax_year', String(Year(Today())))
				ibo_employee_earning.of_SetItem(ll_e_row, 'ei_exempt_flag', 	this.of_GetItemString(ll_row, 'ei_exempt_flag'))
				ibo_employee_earning.of_SetItem(ll_e_row, 'qpip_exempt_flag', 	this.of_GetItemString(ll_row, 'qpip_exempt_flag'))
				ibo_employee_earning.of_SetItem(ll_e_row, 'cpp_exempt_flag', 	this.of_GetItemString(ll_row, 'cpp_exempt_flag'))
				ibo_employee_earning.of_SetItem(ll_e_row, 'cpp_exempt_effective_date', this.of_GetItemDateTime(ll_row, 'cpp_exempt_effective_date'))
				ibo_employee_earning.of_SetItem(ll_e_row, 'tax_province', 	ls_null)	//May get employee value later
			END IF
		END IF

		//Make sure there's a WCB record for adding WCB to date
		ls_wcb_class = this.of_GetItemString(ll_row, "wcb_class")
		IF IsValid(ibo_employee_wcb) AND Len(ls_wcb_class) > 0 THEN
			ls_find = "book = '" + gnv_app.is_book &
						+ "' AND employee = " + String(this.of_GetItemNumber(ll_row, "employee")) &
						+ "  AND wcb_class = '" + ls_wcb_class &
						+ "' AND tax_year = '" + String(Year(Today())) + "'"
			ll_w_row =  ibo_employee_wcb.of_Find(ls_find)
			IF ll_w_row < 1 THEN
				ibo_employee_wcb.of_Retrieve(ls_find, TRUE /* append records */) 
				ll_w_row =  ibo_employee_wcb.of_Find(ls_find)
			END IF
			
			IF ll_w_row = 0 THEN
				ll_w_row = ibo_employee_wcb.of_InsertRow(0)
				ibo_employee_wcb.of_SetItem(ll_w_row, 'book', gnv_app.is_book)
				ibo_employee_wcb.of_SetItem(ll_w_row, 'employee', this.of_GetItemNumber(ll_row, "employee"))
				ibo_employee_wcb.of_SetItem(ll_w_row, 'wcb_class', ls_wcb_class)
				ibo_employee_wcb.of_SetItem(ll_w_row, 'tax_year', String(Year(Today())))
			END IF
		END IF

	END IF
LOOP UNTIL ll_row = 0

		
RETURN AncestorReturnValue
end event

