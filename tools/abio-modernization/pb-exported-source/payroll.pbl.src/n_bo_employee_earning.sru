$PBExportHeader$n_bo_employee_earning.sru
forward
global type n_bo_employee_earning from n_cst_business_abio
end type
end forward

global type n_bo_employee_earning from n_cst_business_abio
end type
global n_bo_employee_earning n_bo_employee_earning

type variables

n_bo_person		ibo_person
end variables

forward prototypes
public function integer of_check_ytd_amounts_zero (long al_employee, string as_book, long al_tax_year, ref boolean ab_zero_ytd)
public function integer of_fix_pension_plan (string as_trade_union, string as_pension_plan_no, string as_source, datetime adt_from, datetime adt_to, ref string as_message)
end prototypes

public function integer of_check_ytd_amounts_zero (long al_employee, string as_book, long al_tax_year, ref boolean ab_zero_ytd);//************************************************************
// Object   :	n_bo_employee_earning 
// Function :	of_check_ytd_amounts_zero
// Author   :	Lourdes Garcia
// Date     :	2009/05/01
// 	
// Arguments:	long al_employee
// 				string as_book
// 				long al_tax_year
// 				boolean ab_zero_ytd
// 	
// Returns:		integer, 1 Success, -1 Fail, 0 Nothing Retrieved
// 	
// Desc:			REF  ab_zero_ytd TRUE if ytd has zero amounts, FALSE otherwise
// 	
//************************************************************

Int	li_return = 1
Long	ll_rc

ab_zero_ytd = TRUE

IF IsNull(as_book) OR as_book = "" OR &
   IsNull(al_employee) OR al_employee = 0 OR & 
	IsNull(al_tax_year) OR al_tax_year = 0 THEN
	li_return = -1
ELSE
	ll_rc = This.of_retrieve("employee = " + string(al_employee) + &
						  " and book = '" + string(as_book) + "' and " + &
						  " tax_year = " + string(al_tax_year) )
	IF ll_rc > 0 THEN
		li_return = 1
		IF This.of_GetItemDecimal(ll_rc, 'reg_earn') <> 0 THEN 
			ab_zero_ytd = FALSE
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'tah_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'ovr_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'travel_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'turnaround') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'taxi') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'taxable_loa') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'taxable_mileage') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'vacation_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'other_taxable_pay') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'cpp_contribution') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'cpp2_contribution') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'ei_premium') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'union_dues') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'subcontractor_union_dues') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'income_tax') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'insurance') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'misc_deduction') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'net_pay') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'reg_hour') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'tah_hour') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'ovr_hour') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'travel_hour') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'meal') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'retro') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'nontaxable_loa') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'nontaxable_mileage') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'statutory_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'gross_pay') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'cpp_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'cpp2_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'ei_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'union_remittance') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'taxable_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'taxable_benefit') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'union_pension') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'wcb_remittance') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		IF This.of_GetItemDecimal(ll_rc, 'personal_safety_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'group_safety_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'production_bonus_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'employer_rrsp') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'employee_rrsp') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'staff_safety_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'smtc_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'retention_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'incentive_paid') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'vacation_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		IF This.of_GetItemDecimal(ll_rc, 'statutory_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		
		IF This.of_GetItemDecimal(ll_rc, 'personal_safety_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		IF This.of_GetItemDecimal(ll_rc, 'group_safety_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		IF This.of_GetItemDecimal(ll_rc, 'production_bonus_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		IF This.of_GetItemDecimal(ll_rc, 'staff_safety_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		IF This.of_GetItemDecimal(ll_rc, 'smtc_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		IF This.of_GetItemDecimal(ll_rc, 'retention_earn') <> 0 THEN 
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF
		
		IF This.of_GetItemDecimal(ll_rc, 'incentive_earn') <> 0 THEN	
			ab_zero_ytd = FALSE 
			RETURN li_return 
		END IF

	ELSE
		// nothing returned
		li_return = 0
	END IF
END IF

RETURN li_return



end function

public function integer of_fix_pension_plan (string as_trade_union, string as_pension_plan_no, string as_source, datetime adt_from, datetime adt_to, ref string as_message);//************************************************************
// Object   :	n_bo_employee_earning 
// Function :	of_fix_pension_plan
// Author   :	Monica Petersen
// Date     :	2012/12/12
// 	
// Arguments:	string as_trade_union
// 				string as_pension_plan_no
// 				string as_source
// 				datetime adt_from
// 				datetime adt_to
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


Long						ll_emp_rows, ll_row, ll_count
Integer					li_errcount, li_error
String					ls_where, ls_from_year, ls_to_year
s_validation_error	lstr_err[]

//Jira 3948 - Fix action doesn't work if payroll has been advanced into a new year and there are no cheques yet,
//so use the same date on the newest cheque to look for union pension amounts
ls_from_year = String(adt_from, 'yyyy')
ls_to_year = String(adt_to, 'yyyy')

/* LG: 2012/12/12 Jira 2564 */	
 ls_where = "book = '" + gnv_app.is_book + "' "																&
	+	" AND tax_year BETWEEN '" + ls_from_year + "' AND '" + ls_to_year + "'"						&
	+	" AND union_pension <> 0 " 																				&
	+	" AND employee IN (SELECT distinct dt.employee "													&
	+ "   						FROM (SELECT ROW_NUMBER() OVER ( PARTITION BY prc.employee ORDER BY  pay_period_start_date  DESC ) AS 'RowNumber', "	&
	+ "                						 prc.employee, prc.trade_union "								&
  	+ "          			 			  FROM dbo.pr_cheque prc  "											&
	+ "          						 WHERE prc.book = '" + gnv_app.is_book + "'  "					&
	+ "            						AND LEFT(prc.pr_yyyymm, 4) BETWEEN '" + ls_from_year + "' AND '" + ls_to_year + "'"	&
	+ " 			   						AND prc.union_pension <> 0  "										&
   + "         						) dt "																		&
	+ "  							WHERE RowNumber <= 1 and trade_union = '" + as_trade_union + "'"  + ") "													
	
ll_emp_rows = this.of_Retrieve(ls_where)
CHOOSE CASE ll_emp_rows 
	CASE -1
		gnv_error.of_add(90,gs_last_window,"R","Error reading employee_earning",-1,ls_where,"employee_earning")
		RETURN -1
	CASE 0
		as_message = "There are no employees in " + as_trade_union + " with union pension amounts in the period " + ls_from_year + " TO " + ls_to_year 
		RETURN 0
	CASE ELSE
		FOR ll_row = 1 TO ll_emp_rows
			IF (this.of_GetItemString(ll_row, 'pension_plan_no') <> as_pension_plan_no) OR IsNull(this.of_GetItemString(ll_row, 'pension_plan_no')) THEN
				this.of_SetItem(ll_row, 'pension_plan_no', as_pension_plan_no)
				ll_count ++
			END IF
		NEXT
		
		IF Trim(as_source) <> '' THEN
			gnv_event.of_add(as_source, 'F', as_trade_union, as_pension_plan_no + '/' + String(adt_from, 'yyyy.mm.dd')  + '/' + String(adt_to, 'yyyy.mm.dd') )
			//Log all updates to employee_earning
			this.of_SetLogEventName(as_source)
			this.of_SetLogActionCode("F")
		END IF
		
		this.of_Update(TRUE, lstr_err)
		li_errcount = UpperBound(lstr_err)
			
		IF li_errcount > 0 THEN
			FOR li_error = 1 TO li_errcount
				 as_message += lstr_err[li_error].s_message + '~r'
			NEXT
			gnv_error.of_add(90, gs_last_window, "R", "Error reading employee_earning", -1, as_message, "employee_earning")
			ROLLBACK USING SQLCA;
			RETURN -1
		ELSE
			as_message = "Pension plan updated to " + as_pension_plan_no + " for " + String(ll_count) + " employees in " + as_trade_union + "."
		END IF
END CHOOSE

RETURN 1



		
end function

on n_bo_employee_earning.create
call super::create
end on

on n_bo_employee_earning.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_employee_earning 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/05/01
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Initialize BO
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


// Set the object description to be seen in messages to user
This.of_SetDescription("Employee Earning")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_employee_earning"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book','employee','tax_year'})

of_addchild('EmployeeWCB','n_bo_employee_wcb')


// Add Validations and Default Values
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Company is Required", FALSE)
This.of_AddValidationRule({"employee"}, "REQUIRED", &
		"", "Employee is Required", FALSE)
This.of_AddValidationRule({"tax_year"}, "REQUIRED", &
		"", "Tax Year is Required", FALSE)
This.of_AddValidationRule({"vacation_earn"}, "REQUIRED", &
		"", "Vacation is Required", FALSE)
		
This.of_AddValidationRule({"statutory_earn"}, "REQUIRED", &
		"", "Statutory is Required", FALSE)
This.of_setcolumndefault('statutory_earn', '0')


This.of_AddValidationRule({"personal_safety_earn"}, "REQUIRED", &
		"", "Personal Safety Earn is Required", FALSE)
This.of_setcolumndefault('personal_safety_earn', '0')

This.of_AddValidationRule({"group_safety_earn"}, "REQUIRED", &
		"", "Group Safety Earn is Required", FALSE)
This.of_setcolumndefault('group_safety_earn', '0')


This.of_AddValidationRule({"production_bonus_earn"}, "REQUIRED", &
		"", "Production Bonus Earn is Required", FALSE)
This.of_setcolumndefault('production_bonus_earn', '0')


This.of_AddValidationRule({"staff_safety_earn"}, "REQUIRED", &
		"", "Staff Safety Earn is Required", FALSE)
This.of_setcolumndefault('staff_safety_earn', '0')

This.of_AddValidationRule({"smtc_earn"}, "REQUIRED", &
		"", "SMTC Earned is Required", FALSE)
This.of_setcolumndefault('smtc_earn', '0')

This.of_AddValidationRule({"retention_earn"}, "REQUIRED", &
		"", "Retention Earned is Required", FALSE)
This.of_setcolumndefault('retention_earn', '0')

This.of_AddValidationRule({"incentive_earn"}, "REQUIRED", &
		"", "Incentive Earned is Required", FALSE)
This.of_setcolumndefault('incentive_earn', '0')

This.of_AddValidationRule({"cpp_earn"}, "REQUIRED", &
		"", "CPP Earnings is Required", FALSE)
This.of_setcolumndefault('cpp_earn', '0')

This.of_AddValidationRule({"ei_earn"}, "REQUIRED", &
		"", "EI Earnings is Required", FALSE)
This.of_setcolumndefault('ei_earn', '0')

This.of_AddValidationRule({"taxable_earn"}, "REQUIRED", &
		"", "Taxable Earnings is Required", FALSE)
This.of_setcolumndefault('taxable_earn', '0')

This.of_AddValidationRule({"reg_hour"}, "REQUIRED", &
		"", "Regular Hours is Required", FALSE)
This.of_setcolumndefault('reg_hour', '0')

This.of_AddValidationRule({"tah_hour"}, "REQUIRED", &
		"", "1 & 1/2 hours is Required", FALSE)
This.of_setcolumndefault('tah_hour', '0')

This.of_AddValidationRule({"ovr_hour"}, "REQUIRED", &
		"", "Overtime hours is Required", FALSE)
This.of_setcolumndefault('ovr_hour', '0')

This.of_AddValidationRule({"travel_hour"}, "REQUIRED", &
		"", "Travel hours is Required", FALSE)
This.of_setcolumndefault('travel_hour', '0')

This.of_AddValidationRule({"reg_earn"}, "REQUIRED", &
		"", "Regular earnings is Required", FALSE)
This.of_setcolumndefault('reg_earn', '0')

This.of_AddValidationRule({"tah_earn"}, "REQUIRED", &
		"", "1 & 1/2 earnings is Required", FALSE)
This.of_setcolumndefault('tah_earn', '0')

This.of_AddValidationRule({"ovr_earn"}, "REQUIRED", &
		"", "Overtime earnings is Required", FALSE)
This.of_setcolumndefault('ovr_earn', '0')


This.of_AddValidationRule({"travel_earn"}, "REQUIRED", &
		"", "Travel earnings is Required", FALSE)
This.of_setcolumndefault('travel_earn', '0')

This.of_AddValidationRule({"taxable_loa"}, "REQUIRED", &
		"", "Taxable LOA is Required", FALSE)
This.of_setcolumndefault('taxable_loa', '0')

This.of_AddValidationRule({"nontaxable_loa"}, "REQUIRED", &
		"", "Non-taxable LOA is Required", FALSE)
This.of_setcolumndefault('nontaxable_loa', '0')

This.of_AddValidationRule({"taxable_mileage"}, "REQUIRED", &
		"", "Taxable Mileage is Required", FALSE)
This.of_setcolumndefault('taxable_mileage', '0')

This.of_AddValidationRule({"nontaxable_mileage"}, "REQUIRED", &
		"", "Non-taxable Mileage is Required", FALSE)
This.of_setcolumndefault('nontaxable_mileage', '0')

This.of_AddValidationRule({"turnaround"}, "REQUIRED", &
		"", "Turnaround is Required", FALSE)
This.of_setcolumndefault('turnaround', '0')

This.of_AddValidationRule({"taxable_site_allow"}, "REQUIRED", &
		"", "Taxable site allow is Required", FALSE)
This.of_setcolumndefault('taxable_site_allow', '0')

This.of_AddValidationRule({"nontaxable_site_allow"}, "REQUIRED", &
		"", "Non-taxable site allow is Required", FALSE)
This.of_setcolumndefault('nontaxable_site_allow', '0')

This.of_AddValidationRule({"taxi"}, "REQUIRED", &
		"", "Taxi & Bus is Required", FALSE)
This.of_setcolumndefault('taxi', '0')

This.of_AddValidationRule({"meal"}, "REQUIRED", &
		"", "Checkout & Meal is Required", FALSE)
This.of_setcolumndefault('meal', '0')

This.of_AddValidationRule({"retro"}, "REQUIRED", &
		"", "Retro active is Required", FALSE)
This.of_setcolumndefault('retro', '0')

This.of_AddValidationRule({"other_taxable_pay"}, "REQUIRED", &
		"", "Other taxable is Required", FALSE)
This.of_setcolumndefault('other_taxable_pay', '0')

This.of_AddValidationRule({"personal_safety_paid"}, "REQUIRED", &
		"", "Personal safety is Required", FALSE)
This.of_setcolumndefault('personal_safety_paid', '0')

This.of_AddValidationRule({"group_safety_paid"}, "REQUIRED", &
		"", "Group Safety Paid is Required", FALSE)
This.of_setcolumndefault('group_safety_paid', '0')

This.of_AddValidationRule({"production_bonus_paid"}, "REQUIRED", &
		"", "Production Bonus Paid is Required", FALSE)
This.of_setcolumndefault('production_bonus_paid', '0')

This.of_AddValidationRule({"staff_safety_paid"}, "REQUIRED", &
		"", "Staff Safety Paid is Required", FALSE)
This.of_setcolumndefault('staff_safety_paid', '0')

This.of_AddValidationRule({"smtc_paid"}, "REQUIRED", &
		"", "SMTC Paid is Required", FALSE)
This.of_setcolumndefault('smtc_paid', '0')

This.of_AddValidationRule({"retention_paid"}, "REQUIRED", &
		"", "Retention Paid is Required", FALSE)
This.of_setcolumndefault('retention_paid', '0')

This.of_AddValidationRule({"incentive_paid"}, "REQUIRED", &
		"", "Incentive Paid is Required", FALSE)
This.of_setcolumndefault('incentive_paid', '0')

This.of_AddValidationRule({"vacation_paid"}, "REQUIRED", &
		"", "Vacation Paid is Required", FALSE)
This.of_setcolumndefault('vacation_paid', '0')

This.of_AddValidationRule({"statutory_paid"}, "REQUIRED", &
		"", "Statutory Paid is Required", FALSE)
This.of_setcolumndefault('statutory_paid', '0')


This.of_AddValidationRule({"cpp_contribution"}, "REQUIRED", &
		"", "CPP Contribution is Required", FALSE)
This.of_setcolumndefault('cpp_contribution', '0')

This.of_AddValidationRule({"cpp2_contribution"}, "REQUIRED", &
		"", "CPP2 Contribution is Required", FALSE)
This.of_setcolumndefault('cpp2_contribution', '0')

This.of_AddValidationRule({"ei_premium"}, "REQUIRED", &
		"", "EI premium is Required", FALSE)
This.of_setcolumndefault('ei_premium', '0')

This.of_AddValidationRule({"income_tax"}, "REQUIRED", &
		"", "Income tax is Required", FALSE)
This.of_setcolumndefault('income_tax', '0')

This.of_AddValidationRule({"union_dues"}, "REQUIRED", &
		"", "Union dues is Required", FALSE)
This.of_setcolumndefault('union_dues', '0')

This.of_AddValidationRule({"back_dues"}, "REQUIRED", &
		"", "Back dues are Required", FALSE)
This.of_setcolumndefault('back_dues', '0')

This.of_AddValidationRule({"insurance"}, "REQUIRED", &
		"", "Insurance is Required", FALSE)
This.of_setcolumndefault('insurance', '0')

This.of_AddValidationRule({"misc_deduction"}, "REQUIRED", &
		"", "Misc Deduction is Required", FALSE)
This.of_setcolumndefault('misc_deduction', '0')

This.of_AddValidationRule({"charity"}, "REQUIRED", &
		"", "Charity is Required", FALSE)
This.of_setcolumndefault('charity', '0')

This.of_AddValidationRule({"incentive_paid_to_rrsp"}, "REQUIRED", &
		"", "Incentive paid to RRSP is Required", FALSE)
This.of_setcolumndefault('incentive_paid_to_rrsp', '0')

This.of_AddValidationRule({"employee_rrsp"}, "REQUIRED", &
		"", "Employee RRSP is Required", FALSE)
This.of_setcolumndefault('employee_rrsp', '0')

This.of_AddValidationRule({"employee_pension"}, "REQUIRED", &
		"", "Employee Pension is Required", FALSE)
This.of_setcolumndefault('employee_pension', '0')

This.of_AddValidationRule({"gross_pay"}, "REQUIRED", &
		"", "Gross Pay is Required", FALSE)
This.of_setcolumndefault('gross_pay', '0')

This.of_AddValidationRule({"net_pay"}, "REQUIRED", &
		"", "Net pay is Required", FALSE)
This.of_setcolumndefault('net_pay', '0')

This.of_AddValidationRule({"paid_in_ap_amt"}, "REQUIRED", &
		"", "Paid is Required", FALSE)
This.of_setcolumndefault('paid_in_ap_amt', '0')

This.of_AddValidationRule({"wcb_remittance"}, "REQUIRED", &
		"", "WCB Remittance is Required", FALSE)
This.of_setcolumndefault('wcb_remittance', '0')

This.of_AddValidationRule({"union_remittance"}, "REQUIRED", &
		"", "Union Remittance is Required", FALSE)
This.of_setcolumndefault('union_remittance', '0')

This.of_AddValidationRule({"employer_rrsp"}, "REQUIRED", &
		"", "Employer RRSP is Required", FALSE)
This.of_setcolumndefault('employer_rrsp', '0')

This.of_AddValidationRule({"union_rrsp"}, "REQUIRED", &
		"", "Union RRSP is Required", FALSE)
This.of_setcolumndefault('union_rrsp', '0')

This.of_AddValidationRule({"union_pension"}, "REQUIRED", &
		"", "Union Pension is Required", FALSE)
This.of_setcolumndefault('union_pension', '0')

This.of_AddValidationRule({"taxable_benefit"}, "REQUIRED", &
		"", "Taxable benefit is Required", FALSE)
This.of_setcolumndefault('taxable_benefit', '0')

This.of_AddValidationRule({"subcontractor_union_dues"}, "REQUIRED", &
		"", "Subcontractor union dues is Required", FALSE)
This.of_setcolumndefault('subcontractor_union_dues', '0')

This.of_AddValidationRule({"vehicle_allowance_paid"}, "REQUIRED", &
		"", "Vehicle Allowance Paid is Required", FALSE)
This.of_setcolumndefault('vehicle_allowance_paid', '0')


This.of_AddValidationRule({"taxable_benefit_gas"}, "REQUIRED", &
		"", "Taxable gas is Required", FALSE)
This.of_setcolumndefault('taxable_benefit_gas', '0')


This.of_AddValidationRule({"taxable_benefit_vehicle"}, "REQUIRED", &
		"", "Taxable benefit vehicle is Required", FALSE)
This.of_setcolumndefault('taxable_benefit_vehicle', '0')


This.of_AddValidationRule({"pay_in_lieu_of_notice"}, "REQUIRED", &
		"", "Pay in Lieu is Required", FALSE)
This.of_setcolumndefault('pay_in_lieu_of_notice', '0')

This.of_AddValidationRule({"daily_dues"}, "REQUIRED", &
		"", "Daily Dues are Required", FALSE)
This.of_setcolumndefault('daily_dues', '0')

This.of_AddValidationRule({"weekly_dues"}, "REQUIRED", &
		"", "Weekly Dues are Required", FALSE)
This.of_setcolumndefault('weekly_dues', '0')

This.of_AddValidationRule({"monthly_dues"}, "REQUIRED", &
		"", "Monthly Dues are Required", FALSE)
This.of_setcolumndefault('monthly_dues', '0')

This.of_AddValidationRule({"vacation_paid_to_union"}, "REQUIRED", &
		"", "Vacation Paid to Union is Required", FALSE)
This.of_setcolumndefault('vacation_paid_to_union', '0')

This.of_AddValidationRule({"statutory_paid_to_union"}, "REQUIRED", &
		"", "Statutory Paid to Union is Required", FALSE)
This.of_setcolumndefault('statutory_paid_to_union', '0')

This.of_AddValidationRule({"qpip_earn"}, "REQUIRED", &
		"", "QPIP Earned is Required", FALSE)
This.of_setcolumndefault('qpip_earn', '0')

This.of_AddValidationRule({"qpip_premium"}, "REQUIRED", &
		"", "QPIP Premium is Required", FALSE)
This.of_setcolumndefault('qpip_premium', '0')

This.of_AddValidationRule({"cpp_exempt_flag"}, "REQUIRED", &
		"", "CPP Exempt Flag is Required", FALSE)

This.of_AddValidationRule({"ei_exempt_flag"}, "REQUIRED", &
		"", "EI Exempt Flag is Required", FALSE)

This.of_setcolumndefault('cpp_exempt_flag', 'N')
This.of_setcolumndefault('ei_exempt_flag', 'N')
This.of_setcolumndefault('qpip_exempt_flag', 'N')

This.of_setcolumndefault('book', trim(gnv_app.is_book))
This.of_setcolumndefault('tax_year', string(YEAR(TODAY())))
This.of_setcolumndefault('vacation_earn', '0')

// Add Validation
This.of_AddValidationRule("cpp_exempt_flag", "EXPRESSION", &
		"<<cpp_exempt_flag>> IN ('Y', 'N')", &
		"CPP Exempt Flag Must be Y or N", FALSE)

This.of_AddValidationRule("ei_exempt_flag", "EXPRESSION", &
		"<<ei_exempt_flag>> IN ('Y', 'N')", &
		"EI Exempt Flag Must be Y or N", FALSE)
		
//jira 1383 - pay periods at year end straddle the calendar year, so they are actually for the upcoming year.
//This.of_AddValidationRule({"tax_year"}, "EXPRESSION", &
//		"Long(<<tax_year>>) <= YEAR(Today())", "Tax Year cannot be a future year", FALSE)	

// DB Constraint
This.of_AddDBConstraint("fk_employee_earning__employee", "employee_earning", &
		"Employee", "New Employee")
		
This.of_AddDBConstraint("fk_employee_earning__province_state", "employee_earning", &
		"Tax Province", "Province State")
		
//References
This.of_AddDBConstraint("fk_employee_wcb__employee_earning", "employee", &
		"Employee", "Employee WCB")	
		
		
		
		


end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_employee_earning 
// Event    :	bo_validate
// Author   :	Monica Petersen
// Date     :	2013/11/18
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

Int				li_rc = 1
Date				ld_65, ld_70
					


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



RETURN li_rc







end event

event destructor;call super::destructor;//************************************************************
// Object   :	n_bo_employee_earning 
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

