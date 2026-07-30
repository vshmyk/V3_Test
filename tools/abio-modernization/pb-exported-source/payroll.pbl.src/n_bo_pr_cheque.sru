$PBExportHeader$n_bo_pr_cheque.sru
forward
global type n_bo_pr_cheque from n_cst_business_abio
end type
end forward

global type n_bo_pr_cheque from n_cst_business_abio
end type
global n_bo_pr_cheque n_bo_pr_cheque

type variables
String 		is_delta
n_bo_pr_cheque_wcb	ibo_pr_cheque_wcb
n_bo_employee			ibo_employee
n_bo_company				ibo_company
n_bo_employee_earning	ibo_employee_earning
n_bo_federal_tax			ibo_federal_tax
n_bo_province_rate		ibo_province_rate
n_bo_province_income_tax		ibo_province_income_tax
n_bo_province_education_tax	ibo_province_education_tax 
n_bo_province_payroll_tax		ibo_province_payroll_tax 
n_bo_pay_period 			ibo_pay_period
n_bo_person 				ibo_person
n_bo_premium_type			ibo_premium_type
n_bo_pr_cheque_premium	ibo_pr_cheque_premium
n_bo_timesheet				ibo_timesheet
n_bo_timesheet				ibo_timesheet_this_tu
n_bo_timesheet_premium	ibo_timesheet_premium
n_bo_trade_union			ibo_trade_union
n_bo_trade_union			ibo_trade_union_this_tu
n_bo_trade_union_rate	ibo_trade_union_rate
n_bo_trade_union_rate	ibo_trade_union_rate_this_ts_or_tu
n_bo_occupation			ibo_occupation
n_bo_trade_union_trade_level_rrsp_pension			ibo_trade_union_trade_level_rrsp_pension
n_bo_trade_union_trade_level_employee_rrsp		ibo_trade_union_trade_level_employee_rrsp
n_bo_vendor					ibo_vendor
n_bo_gl_account			ibo_gl_account
end variables

forward prototypes
public function integer of_get_pay_period_start_date (string as_book, long al_employee, datetime adt_issue_date, ref datetime adt_pay_period_start_date)
public function integer of_get_max_pay_period_start_date (string as_book, long al_employee, datetime adt_issue_date, ref datetime adt_pay_period_start_date)
public function integer of_get_union_dues_paid (string as_book, long al_employee, string as_trade_union, datetime adt_issue_date, ref decimal adec_union_dues)
public function integer of_inc_tax_error (string as_msg)
public function integer of_get_provincial_tax_v1 (string as_prov, decimal adec_t4, datetime adt_issue, ref decimal adec_v1)
public function integer of_prstubs_total (string as_category, decimal adec_amount, n_ds ads_stub)
public function integer of_prstubs_add (n_ds ads_source, long al_x, string as_category, decimal adec_amount, ref n_ds adw_stub)
public function integer of_prstubs (n_ds ads_source, ref n_ds ads_stubs)
public function integer of_find_latest_monthly_dues (string as_book, long al_employee, ref string as_last_month_with_dues)
public function integer of_check_print_queue (long al_start_ck, long al_end_ck, ref boolean ab_found, ref long al_eft_file)
public function integer of_wcb_calc (decimal adec_cheque_taxable_earnings, ref decimal adec_remit, ref n_cst_business abo_pr_cheque, ref n_ds ads_msg)
public function integer of_delete_unprinted_cheque (long al_cheque_no, string as_mode, ref string as_msg)
public function integer of_prcent_err (string as_msg, long al_cheque_no, ref n_ds ads_msg)
protected function integer of_reverse_printed_cheque (long al_cheque_no, string as_mode, ref string as_msg, ref long al_next_cheque)
public function integer of_delete_cheque (long al_cheque_no, string as_mode, ref string as_msg, ref long al_next_cheque)
public function integer of_tax_calc (string as_release_vacation_pay, string as_release_statutory_pay, string as_release_personal_safety, string as_release_group_safety, string as_release_other_safety, string as_release_small_tools, string as_release_retention, string as_release_production_bonus, string as_release_incentive, ref n_cst_business abo_pr_ck, string as_mode, ref decimal adec_total_unpaid_employee_purchases, ref n_ds ads_msg, ref n_bo_employee_purchase abo_employee_purchase, ref n_bo_pr_cheque_trade_union abo_pr_cheque_trade_union, ref n_bo_pr_cheque_occupation abo_pr_cheque_occupation)
public function integer of_tax_calc_get_trade_level_rates (string as_pension_rrsp, ref decimal adec_reg_rate, ref decimal adec_tah_rate, ref decimal adec_ovr_rate, ref string as_msg, ref n_cst_business abo_trade_union_rate, ref n_cst_business abo_trade_union_trade_level_rrsp_pension, ref n_cst_business abo_trade_union, ref n_cst_business abo_occupation)
public subroutine of_tax_calc_create_business_objects ()
public function integer of_tax_calc_union_dues (ref n_cst_business abo_pr_ck_or_tu, ref n_cst_business abo_trade_union_rate_this_tu, integer ai_ck_row, decimal adec_dues_premium_earn, decimal adec_reg_earn)
public function integer of_get_union_benefit_invoice_amount (ref n_cst_business abo_pr_cheque, long al_c_row, ref n_cst_business abo_trade_union_benefit, long al_b_row, ref n_cst_business abo_trade_union_benefit_type, long al_bt_row, string as_include_travel_flag, ref decimal adec_invoice_amount, ref string as_err_msg, long al_employee, decimal adec_retro)
public function integer of_tax_calc_dues_premiums_for_timesheets (n_cst_business abo_timesheet, long ai_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_dues_premium_earn)
public function integer of_tax_calc_pension_premiums_for_ts (n_cst_business abo_timesheet, long ai_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_pension_premium_earn)
public function integer of_tax_calc_premiums_for_timesheets (n_cst_business abo_timesheet, long al_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_dues_premium_earn, ref decimal adec_rrsp_premium_earn, ref decimal adec_pension_premium_earn)
public function integer of_tax_calc_rrsp_premiums_for_timesheets (n_cst_business abo_timesheet, long al_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_rrsp_premium_earn)
public function integer of_tax_calc_roll_up (n_cst_business abo_pr_ck, ref n_cst_business abo_pr_ck_trade_union, ref n_cst_business abo_pr_ck_occupation)
public function integer of_tax_calc_rrsp_employer (ref n_cst_business abo_pr_ck, ref n_cst_business abo_pr_cheque_trade_union, ref n_cst_business abo_pr_cheque_occupation, ref n_ds ads_msg, decimal adec_rrsp_premium_earn, date ad_last_day_of_pp, string as_mode, boolean ab_over_71)
public function integer of_tax_calc_rrsp_employee (ref n_cst_business abo_pr_ck, n_cst_business abo_trade_union, n_cst_business abo_trade_union_rate, decimal adec_rrsp_premium_earn, n_ds ads_msg)
public function integer of_tax_calc_pension_employee (ref n_cst_business abo_pr_ck, n_cst_business abo_trade_union_rate, ref n_cst_business abo_pr_cheque_trade_union, n_cst_business abo_trade_union_rate_this_ts_or_tu, decimal adec_rrsp_premium, ref n_ds ads_msg)
public function integer of_tax_calc_pension_employee_by_union (ref n_cst_business abo_pr_ck_or_tu, long al_ck_row, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_rrsp_premium_earn, ref n_ds ads_msg)
public function integer of_tax_calc_pension_employer (ref n_cst_business abo_pr_ck, ref n_cst_business abo_pr_cheque_trade_union, ref n_cst_business abo_pr_cheque_occupation, decimal adec_pension_premium_earn, n_ds ads_msg, string as_mode, date ad_last_day_of_pp, boolean ab_over_71)
public function integer of_tax_calc_rrsp_employee_by_occupation (long al_cheque_no, string as_trade_union, string as_occupation, date adt_effective, decimal adec_total_hours, n_ds ads_msg, ref decimal adec_rrsp)
public function integer of_tax_calc_rrsp_employer_pct_by_union (ref n_cst_business abo_pr_ck_or_tu, integer ai_ck_row, ref n_cst_business abo_trade_union_this_tu, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_rrsp_premium_earn, decimal adec_all_hr_base_earn, n_ds ads_msg, string as_mode, date ad_rate_effective_date, boolean ab_over_71, decimal adec_retro, decimal adec_taxable_site_allow, decimal adec_nontaxable_site_allow)
public function integer of_tax_calc_rrsp_emplr_base_nd_match_pct (ref n_cst_business abo_pr_ck_or_tu, integer ai_ck_row, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_rrsp_premium_earn_this_tu, decimal adec_all_hr_base_earn, boolean ab_over_71)
protected function integer of_tax_calc_pension_employer_by_union (ref n_cst_business abo_pr_ck_or_tu, integer ai_ck_row, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_pension_premium_earn, n_ds ads_msg, string as_mode, date ad_effective_date, boolean ab_over_71, decimal adec_all_hr_base_earn, ref decimal adec_pension_source_earn, ref decimal adec_union_pension_paid_out)
public function integer of_get_provincial_tax_bp (string as_prov, decimal adec_net_income, datetime adt_issue, ref decimal adec_bpa)
public function integer of_get_provincial_constants (string as_province, string as_type, datetime adt_issue, long al_a_min, ref decimal adec_a_min_floor, ref decimal adec_a_min_ceiling, ref decimal adec_a_min_maximum, ref decimal adec_v_rate_minimum, ref decimal adec_v_rate, ref long al_kp_constant_floor, ref long al_kp_constant, ref decimal adec_add_on)
public function integer of_tax_calc_vacation_stat_sick (date ad_last_day_of_pp, ref n_cst_business abo_ck, ref n_ds ads_msg, ref decimal adec_latest_timesheet_reg_rate, ref n_cst_business abo_pr_cheque_trade_union)
public function integer of_inc_tax_eff_dated (decimal adec_a, decimal adec_k2, integer ai_pay_period_per_year, integer ai_cpp_months, ref decimal adec_t1, ref decimal adec_t2, long al_employee, datetime adt_max_date, decimal adec_cpp_contribution, decimal adec_ei_premium, decimal adec_qpip_premium, decimal adec_emp_cpp_contribution, decimal adec_emp_ei_premium, decimal adec_emp_qpip_premium, ref n_ds ads_msg)
public function integer of_get_employer_union_dues_paid (string as_book, long al_employee, string as_trade_union, datetime adt_issue_date, ref decimal adec_employer_union_dues)
public function integer of_tax_calc_union_remittance (long al_employee, datetime adt_issue, n_cst_business abo_trade_union_rate, ref n_cst_business abo_pr_ck_or_trade_union, integer ai_row, decimal adec_reg_earn, ref n_ds ads_msg)
public function integer of_tax_calc_vacation_stat_this_ts (long al_ts_row, n_cst_business abo_trade_union_rate, long al_tur_row, ref decimal adec_vacation_source_earn, ref decimal adec_statutory_source_earn, decimal adec_statutory_percent_for_this_ts)
public function integer of_tax_calc_rrsp_employer_hourly_by_occ (n_cst_business abo_pr_ck_occupation, integer ai_pco_row, n_cst_business abo_trade_union_this_tu, n_cst_business abo_trade_union_rate_this_occupation, date adt_effective, ref n_ds ads_msg, string as_trade_union, string as_occupation, long al_employee)
public function integer of_tax_calc_rrsp_employer_hourly_by_occ (n_cst_business abo_pr_ck_occupation, integer ai_pco_row, n_cst_business abo_trade_union_this_tu, n_cst_business abo_trade_union_rate_this_occupation, date adt_effective, ref n_ds ads_msg, string as_trade_union, string as_occupation)
public function integer of_tax_calc_pension_employer_by_occ (ref n_cst_business abo_pr_cheque_occupation, integer ai_ck_row, n_cst_business abo_trade_union_rate, date ad_effective_date, n_ds ads_msg, ref decimal adec_union_pension_paid_out, long al_employee)
public function integer of_tax_calc_pension_employer_by_occ (ref n_cst_business abo_pr_cheque_occupation, integer ai_ck_row, n_cst_business abo_trade_union_rate, date ad_effective_date, n_ds ads_msg, ref decimal adec_union_pension_paid_out)
end prototypes

public function integer of_get_pay_period_start_date (string as_book, long al_employee, datetime adt_issue_date, ref datetime adt_pay_period_start_date);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_get_pay_period_start_date
// Author   :	Lourdes Garcia
// Date     :	2009/05/05
// 	
// Arguments:	string as_book
// 				long al_employee
// 				datetime adt_issue_date
// 				datetime adt_pay_period_start_date REF
// 	
// Returns:		integer
// 	
// Desc:			0 Nothing retrieved; 1 success; -1 error
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Int		li_return
Long		ll_rc
String	ls_where



ls_where = "book = '" + as_book + "' and " + &
								" employee = " + string(al_employee) + " and cheque_status in ('P','R') and " + &
								" issue_date > CAST('" + string(adt_issue_date) +  "' as datetime) " 
								
IF IsNull(as_book) OR al_employee = 0 OR IsNull(adt_issue_date) THEN
	gnv_error.of_add(90,gs_last_window,"R","Error reading pr_cheque",-1,ls_where,"pr_cheque")
	li_return = -1
	SetNull(adt_pay_period_start_date)
ELSE
	ll_rc = This.of_retrieve(ls_where)
								
	IF ll_rc > 0 THEN
		adt_pay_period_start_date = This.of_GetItemDateTime(ll_rc, "pay_period_start_date")
		li_return = 1
	ELSE
		gnv_error.of_add(90,gs_last_window,"R","Nothing retrieved from pr_cheque",100,ls_where,"pr_cheque")
		SetNull(adt_pay_period_start_date)
		li_return = 0
	END IF
END IF

Return li_return
								
								
								
end function

public function integer of_get_max_pay_period_start_date (string as_book, long al_employee, datetime adt_issue_date, ref datetime adt_pay_period_start_date);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_get_max_pay_period_start_date
// Author   :	Lourdes Garcia
// Date     :	2009/06/12
// 	
// Arguments:	string as_book
// 				long al_employee
// 				datetime adt_issue_date
// 				datetime adt_pay_period_start_date REF
// 	
// Returns:		integer
// 	
// Desc:			0 Nothing retrieved; 1 success; -1 error
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2009/06/15		MDP			Modify where to only pick up non-zero cheques
//                            so that the ROE doesn't start with zeros
//                            in the odd circumstance where they continued
//                            to key 0 hour timesheets for employees after
//                            they were gone.
//************************************************************


Int		li_return, li_ret
Long		ll_rc
String	ls_where

ls_where = "book = '" + as_book + "' and " + &
								" employee = " + string(al_employee) + " and cheque_status in ('P','R') and ei_earn <> 0 and " + &
								" issue_date > CAST('" + string(adt_issue_date, "yyyy-mm-dd") +  "' as datetime) " 
								
IF IsNull(as_book) OR al_employee = 0 OR IsNull(adt_issue_date) THEN
	gnv_error.of_add(90,gs_last_window,"R","Error reading pr_cheque",-1,ls_where,"pr_cheque")
	li_return = -1
	SetNull(adt_pay_period_start_date)
ELSE
	ll_rc = This.of_retrieve(ls_where)
	
	IF ll_rc > 0 THEN
		This.of_setsort("pay_period_start_date DESC")
		li_ret = This.of_sort()
	
		IF li_ret > 0 THEN
			// returns max pay_period_start_date
			adt_pay_period_start_date = This.of_GetItemDateTime(1, "pay_period_start_date")
			li_return = 1
		END IF
	ELSE
		gnv_error.of_add(90,gs_last_window,"R","Nothing retrieved from pr_cheque",100,ls_where,"pr_cheque")
		SetNull(adt_pay_period_start_date)
		li_return = 0
	END IF
END IF

Return li_return
end function

public function integer of_get_union_dues_paid (string as_book, long al_employee, string as_trade_union, datetime adt_issue_date, ref decimal adec_union_dues);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_get_union_dues_paid
// Author   :	Monica Petersen
// Date     :	2010/02/17
// 	
// Arguments:	string as_book
// 				long al_employee
// 				string as_trade_union
// 				datetime adt_issue_date
// 				decimal adec_union_dues
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


Int		li_return, li_year, li_month
String	ls_where

li_year = Year(Date(adt_issue_date))
li_month = Month(Date(adt_issue_date))

//Look at the trade union child of the cheque so we don't
//include other union dues in the capping
SELECT sum(pr_cheque_trade_union.union_dues)
  INTO :adec_union_dues
  FROM pr_cheque LEFT OUTER JOIN pr_cheque_trade_union 
  						ON pr_cheque.book = pr_cheque_trade_union.book 
					  AND pr_cheque.cheque_no = pr_cheque_trade_union.cheque_no
 WHERE pr_cheque.book = :as_book
   AND pr_cheque.employee = :al_employee
   AND IsNull(pr_cheque_trade_union.trade_union, pr_cheque.trade_union) = :as_trade_union
	AND Year(pr_cheque.issue_date) = :li_year
	AND Month(pr_cheque.issue_date) = :li_month
	AND pr_cheque.cheque_status in ('P','R')
 USING sqlca;
IF sqlca.sqlcode = -1 THEN
	gnv_error.of_add(90,gs_last_window,"R","Error summing union dues from pr_cheque",-1,ls_where,"pr_cheque")
	SetNull(adec_union_dues)
	li_return = -1
ELSE 
	IF IsNull(adec_union_dues) THEN adec_union_dues = 0
	li_return = 1
END IF

RETURN li_return
								
								
								
end function

public function integer of_inc_tax_error (string as_msg);
gnv_error.of_add(80, 'INCTAX', 'A', as_msg, sqlca.sqlerrtext)
ROLLBACK USING SQLCA;
MessageBox('Error', as_msg)
RETURN -1

end function

public function integer of_get_provincial_tax_v1 (string as_prov, decimal adec_t4, datetime adt_issue, ref decimal adec_v1);/*
PURPOSE -  Read province_income_tax for type v1, province 'ON' to determine v1 value

CREATED -  2008.12.12 MDP
*/

Long		ll_rows, ll_x


//Get the constants for the latest date
IF Not(IsValid(ibo_province_income_tax)) THEN
	ibo_province_income_tax = CREATE n_bo_province_income_tax
	ibo_province_income_tax.of_SetTransaction()
END IF

ll_rows = ibo_province_income_tax.of_Retrieve("province = '" + as_prov &
												  + "' AND calculation_type = 'V1' AND effective_date <= '" + String(adt_issue, 'yyyy.mm.dd') &
												  + "' AND expiry_date >= '" + String(adt_issue, 'yyyy.mm.dd') + "'")

ibo_province_income_tax.of_SetSort('a_min asc')
ibo_province_income_tax.of_Sort()

CHOOSE CASE ll_rows
	CASE -1
		this.of_inc_tax_error("Error reading province_income_tax constants for " + as_prov + " on " + String(adt_issue, 'yyyy.mm.dd'))
		RETURN -1
	CASE ELSE
		FOR ll_x = 2 TO ll_rows
			//Provincial Surtax Payable
			IF adec_t4 > ibo_province_income_tax.of_GetItemDecimal(ll_x - 1, 'a_min') THEN
				adec_v1 = adec_v1 + ibo_province_income_tax.of_GetItemDecimal(ll_x, 'v_rate') * (adec_t4 - ibo_province_income_tax.of_GetItemDecimal(ll_x - 1, 'a_min'))
			END IF
		NEXT
END CHOOSE

RETURN 1
end function

public function integer of_prstubs_total (string as_category, decimal adec_amount, n_ds ads_stub);//************************************************************
// Object   :	n_abio_appmanager 
// Function :	of_prstubs_total
// Author   :	Monica Petersen
// Date     :	2011/04/18
// 	
// Arguments:	string as_category
// 				decimal adec_amount
// 				n_ds ads_stub
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


Long	ll_row

IF adec_amount <> 0 THEN
	ll_row = ads_stub.InsertRow(0)
	ads_stub.SetItem(ll_row, 'form_no', 		'')
	ads_stub.SetItem(ll_row, 'prcqno', 		'')
	ads_stub.SetItem(ll_row, 'name', 		'TOTAL')
	ads_stub.SetItem(ll_row, 'category', 	as_category)
	ads_stub.SetItem(ll_row, 'amount', 		adec_amount)
END IF

RETURN 1
end function

public function integer of_prstubs_add (n_ds ads_source, long al_x, string as_category, decimal adec_amount, ref n_ds adw_stub);//************************************************************
// Object   :	n_abio_appmanager 
// Function :	of_prstubs_add
// Author   :	Monica Petersen
// Date     :	2011/04/18
// 	
// Arguments:	n_ds ads_source
// 				long al_x
// 				string as_category
// 				decimal adec_amount
// 				n_ds adw_stub
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


Long	ll_row

IF adec_amount <> 0 THEN
	ll_row = adw_stub.InsertRow(0)
	adw_stub.SetItem(ll_row, 'form_no', 	ads_source.GetItemString(al_x, 'pr_cheque_queue_form_no'))
	adw_stub.SetItem(ll_row, 'employee', 	String(ads_source.GetItemNumber(al_x, 'employee_employee')))
	adw_stub.SetItem(ll_row, 'super', 		String(ads_source.GetItemNumber(al_x, 'employee_supervisor')))
	adw_stub.SetItem(ll_row, 'prcqno', 		String(ads_source.GetItemNumber(al_x, 'pr_cheque_queue_cheque_no')))
	adw_stub.SetItem(ll_row, 'name', 		ads_source.GetItemString(al_x, 'employee_name'))
	adw_stub.SetItem(ll_row, 'category', 	as_category)
	adw_stub.SetItem(ll_row, 'amount', 		adec_amount)
END IF

RETURN 1
end function

public function integer of_prstubs (n_ds ads_source, ref n_ds ads_stubs);//************************************************************
// Object   :	n_abio_appmanager 
// Function :	of_prstubs
// Author   :	Monica Petersen
// Date     :	2010/12/13
// 	
// Arguments:	n_ds ads_source
// 				n_ds ads_stubs
// 	
// Returns:		integer
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2010.12.13		MDP			jira 1687 On the P/R Cheque Stubs report please show them in FIELD DUES (union_dues),
//										DAILY DUES, WEEKLY DUES, MONTHLY DUES, VAC PAID TO UNION, and STAT PAID TO UNION order.
//************************************************************


Long			ll_rows, ll_x
Integer		li_rc

ads_stubs = CREATE n_ds
ads_stubs.DataObject = 'd_prstubs'
li_rc =ads_stubs.of_SetTransObject(sqlca)

ll_rows = ads_source.RowCount()
FOR ll_x = 1 TO ll_rows
	//Stuff that adds to Gross Pay
	this.of_prstubs_add(ads_source, ll_x, 'regular hours', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_reg_hour'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'time & 1/2 hours',	ads_source.GetItemDecimal(ll_x, 'pr_cheque_tah_hour'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'overtime hours', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_ovr_hour'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'travel hours', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_travel_hour'), 			ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'regular earnings', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_reg_earn'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'time & 1/2 earnings',ads_source.GetItemDecimal(ll_x, 'pr_cheque_tah_earn'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'overtime earnings', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_ovr_earn'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'travel earnings', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_travel_earn'), 			ads_stubs)
	//Other timesheet monies
	this.of_prstubs_add(ads_source, ll_x, 'living out', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_taxable_loa') &
																				 + ads_source.GetItemDecimal(ll_x, 'pr_cheque_nontaxable_loa'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'mileage', 				ads_source.GetItemDecimal(ll_x, 'pr_cheque_taxable_mileage') 		&
																				 + ads_source.GetItemDecimal(ll_x, 'pr_cheque_nontaxable_mileage'),	ads_stubs)																			 
	this.of_prstubs_add(ads_source, ll_x, 'site allowance', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_taxable_site_allow') 	&
																				 + ads_source.GetItemDecimal(ll_x, 'pr_cheque_nontaxable_site_allow'),ads_stubs)																				 
	this.of_prstubs_add(ads_source, ll_x, 'turnaround', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_turnaround'), 			ads_stubs)	
	this.of_prstubs_add(ads_source, ll_x, 'meal & checkout', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_meal'), 					ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'taxi & bus', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_taxi'), 					ads_stubs)	
	this.of_prstubs_add(ads_source, ll_x, 'retro pay', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_retro'), 					ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'vehicle allowance',	ads_source.GetItemDecimal(ll_x, 'pr_cheque_vehicle_allowance_paid'), 	ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'payment in lieu',		ads_source.GetItemDecimal(ll_x, 'pr_cheque_pay_in_lieu_of_notice'), 	ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'other taxable', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_other_taxable_pay'), 	ads_stubs)
	
	//Incentives paid
	this.of_prstubs_add(ads_source, ll_x, 'personal safety', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_personal_safety_paid'), ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'group safety', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_group_safety_paid'), 	ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'other safety', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_staff_safety_paid'), 	ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'small tools', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_smtc_paid'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'retention', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_retention_paid'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'production bonus', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_production_bonus_paid'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'incentive', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_incentive_paid'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'vacation pay', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_vacation_paid'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'statutory pay', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_statutory_paid'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'paid sick leave', 	ads_source.GetItemDecimal(ll_x, 'paid_sick_leave'), 					ads_stubs)
	
	this.of_prstubs_add(ads_source, ll_x, 'RRSP & pension paid out', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_employer_rrsp_paid_out') 	&
																				 + ads_source.GetItemDecimal(ll_x, 'pr_cheque_union_rrsp_paid_out'),ads_stubs)																				 
	//Gross Pay  - subtotal of above fields
	this.of_prstubs_add(ads_source, ll_x, 'gross pay', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_gross_pay'), 				ads_stubs)
	
	//Stuff subtracted from Gross Pay to make Net Pay
	this.of_prstubs_add(ads_source, ll_x, 'EI/QEI premium', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_ei_premium'), 			ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'CPP/QPP contribution', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_cpp_contribution'),		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'QPIP premium', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_qpip_premium'), 			ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'income tax', 				ads_source.GetItemDecimal(ll_x, 'pr_cheque_income_tax'), 			ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'province payroll tax', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_province_payroll_tax'), ads_stubs)
		
	this.of_prstubs_add(ads_source, ll_x, 'union fees', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_admin_fee'), 				ads_stubs)

	//On the P/R Cheque Stubs report please show them in FIELD DUES (union_dues), DAILY DUES, WEEKLY DUES, MONTHLY DUES, VAC PAID TO UNION, and STAT PAID TO UNION order.
	this.of_prstubs_add(ads_source, ll_x, 'field dues', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_union_dues'),				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'back dues', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_back_dues'),				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'daily dues', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_daily_dues'),				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'weekly dues', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_weekly_dues'),			ads_stubs)
	
	//Some unions are very specific how the monthly dues are labelled on the cheques.  This field
	//gives the opportunity to override the default label of 'monthly dues'
	IF ads_source.GetItemString(ll_x, 'report_monthly_dues_as') <> '' THEN 
		this.of_prstubs_add(ads_source, ll_x, Lower(ads_source.GetItemString(ll_x, 'report_monthly_dues_as')), 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_monthly_dues'),			ads_stubs)
	ELSE
		this.of_prstubs_add(ads_source, ll_x, 'monthly dues', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_monthly_dues'),			ads_stubs)
	END IF
	this.of_prstubs_add(ads_source, ll_x, 'vac paid to union', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_vacation_paid_to_union'),	ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'stat paid to union', ads_source.GetItemDecimal(ll_x, 'pr_cheque_statutory_paid_to_union'),	ads_stubs)

	this.of_prstubs_add(ads_source, ll_x, 'addn union RRSP', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_incentive_paid_to_rrsp'),ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'employee RRSP', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_employee_rrsp'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'dues pension', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_employee_pension'),		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'misc deduction', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_misc_deduction'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'insurance', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_insurance'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'security deposit', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_security_deposit'), 	ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'charity', 				ads_source.GetItemDecimal(ll_x, 'pr_cheque_charity'), 				ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'advance/repay', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_advance_repay'),			ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'taxable benefits', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_taxable_benefit'), 		ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'taxable gas', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_taxable_benefit_gas'), ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'taxable vehicle', 	ads_source.GetItemDecimal(ll_x, 'pr_cheque_taxable_benefit_vehicle'), 	ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'pension/RRSP', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_union_pension') 			&
	 																			 + ads_source.GetItemDecimal(ll_x, 'pr_cheque_union_rrsp'), 			ads_stubs)
	this.of_prstubs_add(ads_source, ll_x, 'employer RRSP', 		ads_source.GetItemDecimal(ll_x, 'pr_cheque_employer_rrsp'), 		ads_stubs)	
	this.of_prstubs_add(ads_source, ll_x, 'WCB remit', 			ads_source.GetItemDecimal(ll_x, 'pr_cheque_wcb_remittance'), 		ads_stubs)	

	//Net Pay (gross pay less the above)
	this.of_prstubs_add(ads_source, ll_x, 'net pay', 				ads_source.GetItemDecimal(ll_x, 'pr_cheque_net_pay'), 				ads_stubs)
NEXT

//Stuff that adds to Gross Pay
this.of_prstubs_total('regular hours', 		ads_source.GetItemDecimal(1, 'cc_reg_hour'), 					ads_stubs)
this.of_prstubs_total('time & 1/2 hours',		ads_source.GetItemDecimal(1, 'cc_tah_hour'), 					ads_stubs)
this.of_prstubs_total('overtime hours', 		ads_source.GetItemDecimal(1, 'cc_ovr_hour'), 					ads_stubs)
this.of_prstubs_total('travel hours', 			ads_source.GetItemDecimal(1, 'cc_travel_hour'), 				ads_stubs)
this.of_prstubs_total('regular earnings', 	ads_source.GetItemDecimal(1, 'cc_reg_earn'), 					ads_stubs)
this.of_prstubs_total('time & 1/2 earnings',	ads_source.GetItemDecimal(1, 'cc_tah_earn'), 					ads_stubs)
this.of_prstubs_total('overtime earnings', 	ads_source.GetItemDecimal(1, 'cc_ovr_earn'), 					ads_stubs)
this.of_prstubs_total('travel earnings', 		ads_source.GetItemDecimal(1, 'cc_travel_earn'), 				ads_stubs)

//Other timesheet monies
this.of_prstubs_total('living out',				ads_source.GetItemDecimal(1, 'cc_taxable_loa')					&
														 + ads_source.GetItemDecimal(1, 'cc_nontaxable_loa'),				ads_stubs)
this.of_prstubs_total('mileage', 				ads_source.GetItemDecimal(1, 'cc_taxable_mileage') 			&
														 + ads_source.GetItemDecimal(1, 'cc_nontaxable_mileage'), 		ads_stubs)
this.of_prstubs_total('site allow', 			ads_source.GetItemDecimal(1, 'cc_taxable_site_allow')  		&
														 + ads_source.GetItemDecimal(1, 'cc_nontaxable_site_allow'), 	ads_stubs)											 
this.of_prstubs_total('turnaround', 			ads_source.GetItemDecimal(1, 'cc_turnaround'), 					ads_stubs)
this.of_prstubs_total('meal & checkout', 		ads_source.GetItemDecimal(1, 'cc_meal'), 							ads_stubs)
this.of_prstubs_total('taxi & bus', 			ads_source.GetItemDecimal(1, 'cc_taxi'), 							ads_stubs)
this.of_prstubs_total('retroactive', 			ads_source.GetItemDecimal(1, 'cc_retro'), 						ads_stubs)
this.of_prstubs_total('vehicle allowance',	ads_source.GetItemDecimal(1, 'cc_vehicle_allowance_paid'), 	ads_stubs)
this.of_prstubs_total('payment in lieu',		ads_source.GetItemDecimal(1, 'cc_pay_in_lieu_of_notice'), 	ads_stubs)
this.of_prstubs_total('other', 					ads_source.GetItemDecimal(1, 'cc_other_taxable_pay'), 		ads_stubs)

//Incentives paid
this.of_prstubs_total('personal safety', 		ads_source.GetItemDecimal(1, 'cc_personal_safety_paid'), 	ads_stubs)
this.of_prstubs_total('group safety', 			ads_source.GetItemDecimal(1, 'cc_group_safety_paid'), 		ads_stubs)
this.of_prstubs_total('other safety', 			ads_source.GetItemDecimal(1, 'cc_staff_safety_paid'), 		ads_stubs)
this.of_prstubs_total('small tools', 			ads_source.GetItemDecimal(1, 'cc_smtc_paid'), 					ads_stubs)
this.of_prstubs_total('retention', 				ads_source.GetItemDecimal(1, 'cc_retention_paid'), 			ads_stubs)
this.of_prstubs_total('production_bonus', 	ads_source.GetItemDecimal(1, 'cc_production_bonus_paid'), 	ads_stubs)
this.of_prstubs_total('incentive', 				ads_source.GetItemDecimal(1, 'cc_incentive_paid'), 			ads_stubs)
this.of_prstubs_total('vacation pay', 			ads_source.GetItemDecimal(1, 'cc_vacation_paid'), 				ads_stubs)
this.of_prstubs_total('statutory pay', 		ads_source.GetItemDecimal(1, 'cc_statutory_paid'), 			ads_stubs)
this.of_prstubs_total('paid sick leave', 		ads_source.GetItemDecimal(1, 'cc_paid_sick_leave'), 			ads_stubs)

this.of_prstubs_total('RRSP & pension paid out', 		ads_source.GetItemDecimal(1, 'cc_employer_rrsp_paid_out') 	&
														 + ads_source.GetItemDecimal(1, 'cc_union_rrsp_paid_out'),		ads_stubs)																				 

//Gross Pay  - subtotal of above fields
this.of_prstubs_total('gross pay', 				ads_source.GetItemDecimal(1, 'cc_gross_pay'), 					ads_stubs)

//Stuff subtracted from Gross Pay to make Net Pay
this.of_prstubs_total('EI/QEI premium', 			ads_source.GetItemDecimal(1, 'cc_ei_premium'), 				ads_stubs)
this.of_prstubs_total('CPP/QPP contribution', 	ads_source.GetItemDecimal(1, 'cc_cpp_contribution'),		ads_stubs)
this.of_prstubs_total('QPIP premium', 				ads_source.GetItemDecimal(1, 'cc_qpip_premium'),			ads_stubs)
this.of_prstubs_total('income tax', 				ads_source.GetItemDecimal(1, 'cc_income_tax'), 				ads_stubs)
this.of_prstubs_total('province payroll tax', 	ads_source.GetItemDecimal(1, 'cc_province_payroll_tax'), ads_stubs)

this.of_prstubs_total('union fees', 			ads_source.GetItemDecimal(1, 'cc_admin_fee'), 					ads_stubs)
//On the P/R Cheque Stubs report please show them in FIELD DUES (union_dues), DAILY DUES, WEEKLY DUES, MONTHLY DUES, VAC PAID TO UNION, and STAT PAID TO UNION order.
this.of_prstubs_total('field dues', 			ads_source.GetItemDecimal(ll_x, 'cc_union_dues'),				ads_stubs)
this.of_prstubs_total('back dues', 				ads_source.GetItemDecimal(ll_x, 'cc_back_dues'),				ads_stubs)
this.of_prstubs_total('daily dues', 			ads_source.GetItemDecimal(ll_x, 'cc_daily_dues'),				ads_stubs)
this.of_prstubs_total('weekly dues', 			ads_source.GetItemDecimal(ll_x, 'cc_weekly_dues'),				ads_stubs)

//Some unions are very specific how the monthly dues are labelled on the cheques.  This field
//gives the opportunity to override the default label of 'monthly dues'
IF ads_source.GetItemString(ll_x, 'report_monthly_dues_as') <> '' THEN
	this.of_prstubs_total(Lower(ads_source.GetItemString(ll_x, 'report_monthly_dues_as')), ads_source.GetItemDecimal(ll_x, 'cc_monthly_dues'),			ads_stubs)
ELSE
	this.of_prstubs_total('monthly dues', 			ads_source.GetItemDecimal(ll_x, 'cc_monthly_dues'),			ads_stubs)
END IF

this.of_prstubs_total('vac paid to union', 	ads_source.GetItemDecimal(ll_x, 'cc_vacation_paid_to_union'),	ads_stubs)
this.of_prstubs_total('stat paid to union', 	ads_source.GetItemDecimal(ll_x, 'cc_statutory_paid_to_union'),	ads_stubs)

this.of_prstubs_total('addn union RRSP', 		ads_source.GetItemDecimal(1, 'cc_incentive_paid_to_rrsp'),	ads_stubs)
this.of_prstubs_total('employee RRSP', 		ads_source.GetItemDecimal(1, 'cc_employee_rrsp'), 				ads_stubs)
this.of_prstubs_total('dues pension', 			ads_source.GetItemDecimal(1, 'cc_employee_pension'), 			ads_stubs)
this.of_prstubs_total('misc deduction', 		ads_source.GetItemDecimal(1, 'cc_misc_deduction'), 			ads_stubs)
this.of_prstubs_total('insurance', 				ads_source.GetItemDecimal(1, 'cc_insurance'), 					ads_stubs)
this.of_prstubs_total('security deposit', 	ads_source.GetItemDecimal(1, 'cc_security_deposit'), 			ads_stubs)
this.of_prstubs_total('charity',			 		ads_source.GetItemDecimal(1, 'cc_charity'),		 				ads_stubs)
this.of_prstubs_total('advance/repay', 		ads_source.GetItemDecimal(1, 'cc_advance_repay'),				ads_stubs)
this.of_prstubs_total('taxable benefits', 	ads_source.GetItemDecimal(1, 'cc_taxable_benefit'),			ads_stubs)
this.of_prstubs_total('taxable gas', 			ads_source.GetItemDecimal(1, 'cc_taxable_benefit_gas'),		ads_stubs)
this.of_prstubs_total('taxable vehicle', 		ads_source.GetItemDecimal(1, 'cc_taxable_benefit_vehicle'),	ads_stubs)
this.of_prstubs_total('pension/RRSP', 			ads_source.GetItemDecimal(1, 'cc_union_pension')				&
														 + ads_source.GetItemDecimal(1, 'cc_union_rrsp'), 					ads_stubs)
this.of_prstubs_total('employer RRSP', 		ads_source.GetItemDecimal(1, 'cc_employer_rrsp'), 				ads_stubs)
this.of_prstubs_total('WCB remit', 				ads_source.GetItemDecimal(1, 'cc_wcb_remittance'), 			ads_stubs)

//Net Pay (gross pay less the above)
this.of_prstubs_total('net pay', 				ads_source.GetItemDecimal(1, 'cc_net_pay'), 						ads_stubs)

RETURN 1
end function

public function integer of_find_latest_monthly_dues (string as_book, long al_employee, ref string as_last_month_with_dues);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_find_latest_monthly_dues
// Author   :	Monica Petersen
// Date     :	2012/06/05
// 	
// Arguments:	string as_book
// 				long al_employee
// 	
// Returns:		integer, 1 Success, -1 Fail, 0 Nothing Retrieved
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Int	li_return = 1
Long	ll_rc
Datetime	ldt_issue_date

IF IsNull(as_book) OR as_book = "" OR &
   IsNull(al_employee) OR al_employee = 0 THEN
	li_return = -1
ELSE
	ll_rc = This.of_max("issue_date", "employee = " + string(al_employee) &
						  + "  AND book = '" + string(as_book) &
						  + "' AND monthly_dues > 0 AND void_cheque_no = 0", ldt_issue_date)
	IF ll_rc > 0 THEN
		as_last_month_with_dues = String(ldt_issue_date, 'yyyymm')
	ELSE
		SetNull(as_last_month_with_dues)
	END IF
END IF

RETURN li_return



end function

public function integer of_check_print_queue (long al_start_ck, long al_end_ck, ref boolean ab_found, ref long al_eft_file);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_check_print_queue
// Author   :	Monica Petersen
// Date     :	2014/02/06
// 	
// Arguments:	long al_start_ck
// 				long al_end_ck
// 				boolean ab_found
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

Long	ll_cheques

SELECT count(1), min(eft_file)
  INTO :ll_cheques, :al_eft_file
  FROM pr_cheque_queue
 WHERE book = :gnv_app.is_book
	AND cheque_no BETWEEN :al_start_ck AND :al_end_ck
 USING sqlca;
CHOOSE CASE sqlca.sqlcode 
	CASE 0
		IF IsNull(ll_cheques) THEN
			ab_found = FALSE
		ELSEIF ll_cheques > 0 THEN
			ab_found = TRUE
		ELSE
			ab_found = FALSE
		END IF
	CASE 100
		ab_found = FALSE
	CASE -1
		this.of_msg_db_error("Error reading P/R cheque queue")
		RETURN -1
END CHOOSE

RETURN 1

end function

public function integer of_wcb_calc (decimal adec_cheque_taxable_earnings, ref decimal adec_remit, ref n_cst_business abo_pr_cheque, ref n_ds ads_msg);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_wcb_calc
// Author   :	Monica Petersen
// Date     :	2014/02/17
// 	
// Arguments:	decimal adec_cheque_taxable_earnings
// 				decimal adec_remit
// 				n_cst_business abo_pr_cheque
// 				n_ds ads_msg
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

String	ls_tax_year, ls_wcb_class
integer	li_rc, li_wcb_rows, li_x
long		ll_rows, ll_employee, ll_rc
Decimal	ldec_wcb_rate
Decimal	ldec_cheque_timesheet_earnings
Decimal	ldec_highest_wcb_remittance
Decimal	ldec_ytd_wcb_for_this_emp
Decimal	ldec_remit_for_this_cks_wcb_class
Decimal	ldec_projected_ytd_earnings_for_wcb_class
Decimal	ldec_ck_wcb_earn_for_wcb_class
Decimal	ldec_wcb_class_annual_maximum_earnings
Decimal	ldec_ytd_wcb_remit_for_this_emp_and_wcb_class
Decimal	ldec_ytd_wcb_earn_for_this_emp_and_wcb_class
Decimal	ldec_yearly_wcb_remit_for_this_class_should_be
Decimal	ldec_yearly_max_remit
Decimal	ldec_wcb_over_remitted
n_ds		lds_max_prem
boolean	lb_over_remit_cleared = FALSE

ll_employee = abo_pr_cheque.of_GetItemNumber(1, 'employee')
ls_tax_year = Left(abo_pr_cheque.of_GetItemString(1, 'pr_yyyymm'), 4)

this.of_GetChild('pr_cheque_wcb', ibo_pr_cheque_wcb)

//Retrieve WCB classes for this cheque
ll_rc = ibo_pr_cheque_wcb.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(abo_pr_cheque.of_GetItemNumber(1, 'cheque_no')))
IF ll_rc < 0 THEN
	this.of_prcent_err("Error retrieving WCB", abo_pr_cheque.of_GetItemNumber(1, 'cheque_no'), ads_msg)
	RETURN 1
END IF

//Determine the highest WCB premium for all jurisdictions where the employee has worked
lds_max_prem = CREATE n_ds
lds_max_prem.DataObject = 'd_prcent_max_premium'
lds_max_prem.SetTransObject(sqlca)
ll_rows = lds_max_prem.Retrieve(gnv_app.is_book, ls_tax_year, abo_pr_cheque.of_GetItemNumber(1, 'cheque_no'), ll_employee)

IF ll_rows < 0 THEN
	this.of_prcent_err("Error retrieving WCB: " + sqlca.sqlerrtext, 0, ads_msg)
	RETURN -1
ELSEIF ll_rows = 0 THEN
	this.of_prcent_err("No WCB entries found for " + ls_tax_year + " for WCB classes on cheque " + String(abo_pr_cheque.of_GetItemNumber(1, 'cheque_no')) + ", employee " + String(ll_employee), abo_pr_cheque.of_GetItemNumber(1, 'cheque_no'), ads_msg)	
	RETURN -1
ELSE
	li_rc = lds_max_prem.SetSort('cc_max_premium desc')
	li_rc = lds_max_prem.Sort()
	ldec_highest_wcb_remittance = Round(lds_max_prem.GetItemDecimal(1, 'cc_max_premium'), 2)
END IF

//How much has the employee already remitted across all classes?
SELECT sum(wcb_remittance)
  INTO :ldec_ytd_wcb_for_this_emp
  FROM employee_wcb
 WHERE book = :gnv_app.is_book
   AND employee = :ll_employee
	AND tax_year = :ls_tax_year
 USING sqlca;
IF sqlca.sqlcode <> 0 THEN
	this.of_prcent_err("Error reading employee_wcb: " + sqlca.sqlerrtext, abo_pr_cheque.of_GetItemNumber(1, 'cheque_no'), ads_msg)
	RETURN -1
END IF
IF IsNull(ldec_ytd_wcb_for_this_emp) THEN ldec_ytd_wcb_for_this_emp = 0

//Total remit across all classes cannot exceed the highest remittance class
IF ldec_highest_wcb_remittance > ldec_ytd_wcb_for_this_emp THEN
	//Reduce the maximum premium by the amount previously remitted
	//this gives us an upper limit for any remittance
	ldec_highest_wcb_remittance -= ldec_ytd_wcb_for_this_emp
	ldec_wcb_over_remitted = 0
ELSE
	//If rates have changed, we may have overremitted WCB
	ldec_wcb_over_remitted = ldec_ytd_wcb_for_this_emp - ldec_highest_wcb_remittance
	ldec_highest_wcb_remittance = 0
END IF

//Initialize working variables
adec_remit = 0
ldec_projected_ytd_earnings_for_wcb_class = 0
ldec_cheque_timesheet_earnings =   abo_pr_cheque.of_GetItemDecimal(1, 'reg_earn') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'tah_earn') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'ovr_earn') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'travel_earn') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'turnaround') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'taxi') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'taxable_loa') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'taxable_mileage') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'taxable_site_allow') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'other_taxable_pay') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'vehicle_allowance_paid') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'pay_in_lieu_of_notice') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'meal') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'retro') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'nontaxable_loa') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'nontaxable_mileage') &
											+ abo_pr_cheque.of_GetItemDecimal(1, 'nontaxable_site_allow') &

li_wcb_rows = ibo_pr_cheque_wcb.of_RowCount()
FOR li_x = 1 TO li_wcb_rows
	
	//Look at each WCB class for this cheque
	ls_wcb_class = ibo_pr_cheque_wcb.of_GetItemString(li_x, 'wcb_class')
	SELECT wcb_rate,
	       wcb_annual_maximum
	  INTO :ldec_wcb_rate,
	       :ldec_wcb_class_annual_maximum_earnings
	  FROM wcb_rate
	 WHERE book 	  = :gnv_app.is_book
	   AND wcb_class = :ls_wcb_class
	   AND tax_year  = :ls_tax_year
	 USING sqlca;
	IF sqlca.sqlcode <> 0 THEN
		this.of_prcent_err("Error reading wcb_rate: " + sqlca.sqlerrtext, abo_pr_cheque.of_GetItemNumber(1, 'cheque_no'), ads_msg)
		RETURN -1
	END IF
	 
	//Determine portion earned in this jurisdiction
	IF ldec_cheque_timesheet_earnings = 0 THEN
		ldec_ck_wcb_earn_for_wcb_class = adec_cheque_taxable_earnings
	ELSE
		ldec_ck_wcb_earn_for_wcb_class = Round(adec_cheque_taxable_earnings  &
																			 * (  ibo_pr_cheque_wcb.of_GetItemDecimal(li_x, 'timesheet_earn') &
																		       / ldec_cheque_timesheet_earnings) , 2)
	END IF
	
	//How much has the employee earned for this class?
	SELECT sum(wcb_remittance),
	       sum(wcb_assessable_earn)
	  INTO :ldec_ytd_wcb_remit_for_this_emp_and_wcb_class,
	       :ldec_ytd_wcb_earn_for_this_emp_and_wcb_class
	  FROM employee_wcb
	 WHERE book 		= :gnv_app.is_book
	   AND employee 	= :ll_employee
	   AND wcb_class 	= :ls_wcb_class
		AND tax_year 	= :ls_tax_year
	 USING sqlca;
	IF sqlca.sqlcode <> 0 THEN
		this.of_prcent_err("Error reading employee_wcb", abo_pr_cheque.of_GetItemNumber(1, 'cheque_no'), ads_msg)
		RETURN -1
	END IF
	IF IsNull(ldec_ytd_wcb_remit_for_this_emp_and_wcb_class) THEN ldec_ytd_wcb_remit_for_this_emp_and_wcb_class = 0
	IF IsNull(ldec_ytd_wcb_earn_for_this_emp_and_wcb_class) THEN ldec_ytd_wcb_earn_for_this_emp_and_wcb_class = 0
	
	//-----------------
	// remittance
	//-----------------
	
	IF lb_over_remit_cleared THEN
		//In a situation where the remittance is over the highest amount,
		//and there's more than one class on the cheque, credit the first
		//class and set the remaining classes to zero remit
		ldec_remit_for_this_cks_wcb_class = 0
	ELSE		
		//Add this cheque to the YTD and determine what the yearly remit should be at the current rate.
		//this allows us to recalculate in the case where the rate has changed mid-year
		ldec_yearly_wcb_remit_for_this_class_should_be = Round((ldec_ytd_wcb_earn_for_this_emp_and_wcb_class + ldec_ck_wcb_earn_for_wcb_class) * ldec_wcb_rate * 0.01, 2)
		
		//Don't allow employee to remit more than the WCB class annual maximum
		ldec_yearly_max_remit = Round(ldec_wcb_class_annual_maximum_earnings * ldec_wcb_rate * 0.01, 2)
		IF ldec_yearly_wcb_remit_for_this_class_should_be > ldec_yearly_max_remit THEN
			ldec_yearly_wcb_remit_for_this_class_should_be = ldec_yearly_max_remit
		END IF
		
		//Remit the balance between what has been remitted and what should be remitted for the year
		ldec_remit_for_this_cks_wcb_class = ldec_yearly_wcb_remit_for_this_class_should_be - ldec_ytd_wcb_remit_for_this_emp_and_wcb_class
	
		IF ldec_wcb_over_remitted > 0 THEN
			//Give back over-remitted amounts.  May be due to a rate change.
			ldec_remit_for_this_cks_wcb_class = ldec_wcb_over_remitted * -1.0
			ldec_wcb_over_remitted = 0
			lb_over_remit_cleared = TRUE
		ELSE
			//Total remit across all classes cannot exceed the WCB class with the highest remittance amount
			// i.e. if max remit for AB is $100 and max remit for BC is $120, 
			//      then take no more than $120 in total across both AB and BC
			IF ldec_highest_wcb_remittance - adec_remit <= ldec_remit_for_this_cks_wcb_class THEN
				ldec_remit_for_this_cks_wcb_class = ldec_highest_wcb_remittance - adec_remit
			END IF
		END IF
	END IF
	
	//Populate cheque wcb database record
	ibo_pr_cheque_wcb.of_SetItem(li_x, 'wcb_remittance', 		 ldec_remit_for_this_cks_wcb_class)
	ibo_pr_cheque_wcb.of_SetItem(li_x, 'wcb_assessable_earn', ldec_ck_wcb_earn_for_wcb_class)

	//-----------------
	// return the total WCB remittance to the calling routine
	//-----------------
	
	adec_remit += ldec_remit_for_this_cks_wcb_class
	
	//We've populated at least one WCB row, if there's no earnings stop here
	IF ldec_cheque_timesheet_earnings = 0 THEN
		EXIT
	END IF
NEXT

DESTROY lds_max_prem

RETURN 1
end function

public function integer of_delete_unprinted_cheque (long al_cheque_no, string as_mode, ref string as_msg);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_delete_unprinted_cheque
// Author   :	Monica Petersen
// Date     :	2014/03/14
// 	
// Arguments:	long al_cheque_no
// 				string as_mode
// 				string as_msg
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

String	ls_warning_msg
Long		ll_ts_row, ll_ts_rows
Long		ll_WCB_row, ll_WCB_rows
Long		ll_cp_row, ll_cp_rows
Long		ll_err
String	ls_errors
Decimal	ldec_hold
s_validation_error  		lstr_error[]
String						ls_error_message
Integer						li_errcount, li_error

s_validation_error		lstr_err[]
n_bo_employee 				lbo_employee
n_bo_employee_purchase 	lbo_employee_purchase
n_bo_trade_union_rate	lbo_trade_union_rate
n_bo_pr_cheque_wcb		lbo_pr_cheque_wcb
n_bo_pr_cheque_premium	lbo_pr_cheque_premium
n_bo_pr_cheque_occupation	lbo_pr_cheque_occupation
n_bo_pr_cheque_union_remit	lbo_pr_cheque_union_remit
n_bo_pr_cheque_trade_union	lbo_pr_cheque_trade_union
n_bo_timesheet				lbo_timesheet
n_bo_timesheet_premium	lbo_timesheet_premium

//These business objects are defined as children so they are updated during of_Update()
IF this.of_GetChild("pr_cheque_wcb", lbo_pr_cheque_wcb) = -1 THEN
	this.of_msg_db_error("Cheque WCB is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_wcb.of_Reset()
END IF

IF this.of_GetChild("timesheet", lbo_timesheet) = -1 THEN
	this.of_msg_db_error("Timesheet is not defined as a child table")
	RETURN -1
ELSE
	lbo_timesheet.of_Reset()
END IF

IF this.of_GetChild("timesheet_premium", lbo_timesheet_premium) = -1 THEN
	this.of_msg_db_error("Timesheet Premium is not defined as a child table")
	RETURN -1
ELSE
	lbo_timesheet_premium.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_premium", lbo_pr_cheque_premium) = -1 THEN
	this.of_msg_db_error("Cheque Premium is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_premium.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_trade_union", lbo_pr_cheque_trade_union) = -1 THEN
	this.of_msg_db_error("Cheque Trade Union is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_trade_union.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_occupation", lbo_pr_cheque_occupation) = -1 THEN
	this.of_msg_db_error("Cheque Occupation is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_occupation.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_union_remit", lbo_pr_cheque_union_remit) = -1 THEN
	this.of_msg_db_error("Cheque Union Remit is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_union_remit.of_Reset()
END IF

IF this.of_GetChild("employee_purchase", lbo_employee_purchase) = -1 THEN
	this.of_msg_db_error("Employee Purchase is not defined as a child table")
	RETURN -1
ELSE
	lbo_employee_purchase.of_Reset()
END IF

this.of_SetLogAuditDetails(TRUE)
this.of_SetLogEventName('PRCENT')
this.of_setlogactioncode('D')

//We can just delete the employee purchase entries
IF lbo_employee_purchase.of_reset_employee_purchase_repayments(al_cheque_no, this.of_GetItemNumber(1, 'employee'), ldec_hold) = -1 THEN RETURN -1

//Update changes to the database
lbo_employee_purchase.of_Update(FALSE, lstr_error)
li_errcount = UpperBound(lstr_error)
	
IF li_errcount > 0 THEN
	FOR li_error = 1 TO li_errcount
		ls_error_message += gnv_app.of_format_validation_error(lstr_error[li_error])
	NEXT
	
	this.of_msg_db_error("Error deleting employee purchase: ~n~n" + ls_error_message)
ELSE
	
	//Now put everything back the way it was before this cheque
	lbo_employee_purchase.of_reset_fully_paid_invoices(this.of_GetItemNumber(1, 'employee'))
//	lbo_employee_purchase.of_update(FALSE, lstr_error)
//	IF UpperBound(lstr_error) > 0 THEN 
//		FOR li_error = 1 TO li_errcount
//			ls_error_message += gnv_app.of_format_validation_error(lstr_error[li_error])
//		NEXT
//		
//		this.of_msg_db_error("Error resetting employee purchase " + ls_error_message)
//	END IF
END IF				


//Delete this cheque
//for logging
IF This.ids_data.Describe("action.Name") = "action" THEN
	this.of_SetItem(1, 'action', 'D') //So logging is under Delete action
END IF

this.of_DeleteRow(1)

//Set timesheets to no cheque
ll_ts_rows = lbo_timesheet.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
IF ll_ts_rows = 0 THEN
	IF as_mode = 'delete' THEN
		MessageBox("Delete","Couldn't find timesheets, cheque already voided" )
	END IF	
	RETURN 0
ELSE
	FOR ll_ts_row = 1 TO ll_ts_rows 
		lbo_timesheet.of_SetItem(ll_ts_row, 'cheque_no', 0)
	NEXT
END IF

//Delete PR_CHEQUE WCB
ll_wcb_rows = lbo_pr_cheque_wcb.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_wcb_row = ll_wcb_rows TO 1 STEP -1
	lbo_pr_cheque_wcb.of_DeleteRow(ll_wcb_row)
NEXT
	
//Delete PR_cheque premiums
ll_cp_rows = lbo_pr_cheque_premium.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = ll_cp_rows TO 1 STEP -1
	lbo_pr_cheque_premium.of_DeleteRow(ll_cp_row)
NEXT
	
//Delete PR_cheque trade unions
ll_cp_rows = lbo_pr_cheque_trade_union.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = ll_cp_rows TO 1 STEP -1
	lbo_pr_cheque_trade_union.of_DeleteRow(ll_cp_row)
NEXT
	
//Delete PR_cheque occupations
ll_cp_rows = lbo_pr_cheque_occupation.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = ll_cp_rows TO 1 STEP -1
	lbo_pr_cheque_occupation.of_DeleteRow(ll_cp_row)
NEXT
	
//Delete PR_cheque union remittances
ll_cp_rows = lbo_pr_cheque_union_remit.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = ll_cp_rows TO 1 STEP -1
	lbo_pr_cheque_union_remit.of_DeleteRow(ll_cp_row)
NEXT
	
//This will update the cheque and all child business objects
IF this.of_UpdateAll(TRUE, lstr_err) = -1 THEN
	IF UpperBound(lstr_err) > 0 THEN 
		ls_warning_msg = String(al_cheque_no) + ': ' + lstr_err[1].s_message
		FOR ll_err = 1 TO UpperBound(lstr_err) 
			ls_errors += "~n" + gnv_app.of_format_validation_error( lstr_err[ll_err])
		NEXT
		MessageBox("Delete Unprinted Cheque",ls_errors)
	END IF
	gnv_app.of_msg_db_error("PRCENT","Error deleting unprinted cheque " + ls_warning_msg)
	RETURN -1
END IF 
  
IF IsValid(lbo_employee) 				THEN DESTROY lbo_employee
IF IsValid(lbo_employee_purchase) 	THEN DESTROY lbo_employee_purchase
IF IsValid(lbo_trade_union_rate) 	THEN DESTROY lbo_trade_union_rate
IF IsValid(lbo_pr_cheque_wcb) 		THEN DESTROY lbo_pr_cheque_wcb
IF IsValid(lbo_pr_cheque_premium)	THEN DESTROY lbo_pr_cheque_premium
IF IsValid(lbo_pr_cheque_trade_union)	THEN DESTROY lbo_pr_cheque_trade_union
IF IsValid(lbo_pr_cheque_occupation)	THEN DESTROY lbo_pr_cheque_occupation
IF IsValid(lbo_pr_cheque_union_remit)	THEN DESTROY lbo_pr_cheque_union_remit
IF IsValid(lbo_timesheet) 				THEN DESTROY lbo_timesheet
IF IsValid(lbo_timesheet_premium) 	THEN DESTROY lbo_timesheet_premium

RETURN 2

end function

public function integer of_prcent_err (string as_msg, long al_cheque_no, ref n_ds ads_msg);
Long	ll_row

gnv_error.of_add(80, 'PRCENT', 'A', as_msg, 0, sqlca.sqlerrtext, String(al_cheque_no))
ROLLBACK USING SQLCA;


ll_row = ads_msg.InsertRow(0)
ads_msg.SetItem(ll_row, 'cheque_no', al_cheque_no)
ads_msg.SetItem(ll_row, 'message', as_msg)

//Don't inundate the user with messages,they'll be getting a report
IF ll_row = 1 THEN
	MessageBox('Error', as_msg)
END IF

RETURN -1

end function

protected function integer of_reverse_printed_cheque (long al_cheque_no, string as_mode, ref string as_msg, ref long al_next_cheque);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_reverse_printed_cheque
// Author   :	Monica Petersen
// Date     :	2013/03/27
// 	
// Arguments:	long al_cheque_no
// 				string ls_pr_yyyymm
// 				string as_msg
// 				long al_next_cheque
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

String	ls_warning_msg
Integer	li_item
long		ll_hold, ll_new_row
Long		ll_ts_row, ll_ts_rows
Long		ll_tsp_row, ll_tsp_rows
Long		ll_WCB_row, ll_WCB_rows
Long		ll_cp_row, ll_cp_rows
Long		ll_ep_row, ll_ep_rows
Long		ll_err
Datetime	ldt_null, ldt_turndue
Integer 	li_col, li_cols
String	ls_column
String	ls_errors, ls_pr_yyyymm
String	ls_null
Integer	li_rc

s_validation_error		lstr_err[]
n_bo_employee 				lbo_employee
n_bo_employee_purchase 	lbo_employee_purchase
n_bo_trade_union_rate	lbo_trade_union_rate
n_bo_pr_cheque_wcb		lbo_pr_cheque_wcb
n_bo_pr_cheque_premium	lbo_pr_cheque_premium
n_bo_pr_cheque_trade_union	lbo_pr_cheque_trade_union
n_bo_pr_cheque_occupation	lbo_pr_cheque_occupation
n_bo_pr_cheque_union_remit	lbo_pr_cheque_union_remit
n_bo_timesheet				lbo_timesheet
n_bo_timesheet_premium	lbo_timesheet_premium

SetNull(ls_null)

//These business objects are defined as children so they are updated during of_Update()
IF this.of_GetChild("pr_cheque_wcb", lbo_pr_cheque_wcb) = -1 THEN
	this.of_msg_db_error("Cheque WCB is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_wcb.of_Reset()
END IF

IF this.of_GetChild("timesheet", lbo_timesheet) = -1 THEN
	this.of_msg_db_error("Timesheet is not defined as a child table")
	RETURN -1
ELSE
	lbo_timesheet.of_Reset()
	lbo_timesheet.ib_centres_must_be_open = FALSE
END IF

IF this.of_GetChild("timesheet_premium", lbo_timesheet_premium) = -1 THEN
	this.of_msg_db_error("Timesheet Premium is not defined as a child table")
	RETURN -1
ELSE
	lbo_timesheet_premium.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_premium", lbo_pr_cheque_premium) = -1 THEN
	this.of_msg_db_error("Cheque Premium is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_premium.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_trade_union", lbo_pr_cheque_trade_union) = -1 THEN
	this.of_msg_db_error("Cheque Trade Union is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_trade_union.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_occupation", lbo_pr_cheque_occupation) = -1 THEN
	this.of_msg_db_error("Cheque Occupation is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_occupation.of_Reset()
END IF

IF this.of_GetChild("pr_cheque_union_remit", lbo_pr_cheque_union_remit) = -1 THEN
	this.of_msg_db_error("Cheque Union Remit is not defined as a child table")
	RETURN -1
ELSE
	lbo_pr_cheque_union_remit.of_Reset()
END IF

IF this.of_GetChild("employee_purchase", lbo_employee_purchase) = -1 THEN
	this.of_msg_db_error("Employee Purchase is not defined as a child table")
	RETURN -1
ELSE
	lbo_employee_purchase.of_Reset()
//	lbo_employee_purchase.of_SetLogAuditDetails(TRUE)
//	lbo_employee_purchase.of_SetLogEventName('PREPCH')
//	lbo_employee_purchase.of_setlogactioncode('D')
END IF

this.of_SetLogAuditDetails(TRUE)
this.of_SetLogEventName('PRCENT')
//this.of_setlogactioncode('D')

//Retrieve the target cheque
this.of_SetTransaction(sqlca)
IF this.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no)) <> 1 THEN
	gnv_app.of_msg_db_error('PRCENT', 'No cheque record')
	RETURN -1
END IF

//cycle through check numbers to find one that isn't in use
SELECT pr_last_cheque_no, pr_yyyymm
  INTO :al_next_cheque,   :ls_pr_yyyymm
  FROM company
 WHERE book = :gnv_app.is_book
 USING sqlca;
IF sqlca.sqlcode <> 0 THEN
	gnv_app.of_msg_db_error("PRCENT","Error reading company: " + sqlca.sqlerrtext)
	RETURN -1
END IF
DO 
	al_next_cheque++
	SELECT cheque_no
	  INTO :ll_hold
	  FROM pr_cheque
	 WHERE book = :gnv_app.is_book
		AND cheque_no = :al_next_cheque
	 USING sqlca;
	IF sqlca.sqlcode < 0 THEN
		gnv_app.of_msg_db_error("PRCENT","Error reading pr_cheque ")
		RETURN -1
	END IF
LOOP WHILE sqlca.sqlcode = 0

//Jira 3957 - if cheque is deleted in previous year, new cheque should be left in previous year
IF Left(this.of_GetItemString(1, 'pr_yyyymm'), 4) <> Left(ls_pr_yyyymm, 4) THEN
	ls_pr_yyyymm = this.of_GetItemString(1, 'pr_yyyymm')
END IF

this.of_SetItem(1, 'void_cheque_no', al_next_cheque)

//jira 3901 - When we delete a cheque we do not want to override the original reconciled date. 
IF this.of_GetItemString(1, 'cheque_status') <> 'R' THEN
	// mark current cheque reconciled 
	this.of_SetItem(1, 'cheque_status', 'R')
	this.of_SetItem(1, 'reconcile_date', DateTime(Today(), Time(0,0,0)))
END IF

//Reverse timesheets
ll_ts_rows = lbo_timesheet.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
IF ll_ts_rows = 0 THEN
	IF as_mode = 'delete' THEN
		MessageBox("Delete","Couldn't find timesheets, cheque already voided" )
	END IF	
	RETURN 0
END IF

//Make sure the sequence is correct so we know when to query the db for another item.
lbo_timesheet.of_SetSort("employee ASC, work_date ASC")
lbo_timesheet.of_Sort()

//Reverse timesheets and their premiums
li_cols = lbo_timesheet.of_getcolumncount()
FOR ll_ts_row = 1 TO ll_ts_rows
	
	IF ll_ts_row > 1 THEN
		IF lbo_timesheet.of_GetItemNumber(ll_ts_row, 'employee') <> lbo_timesheet.of_GetItemNumber(ll_ts_row - 1, 'employee') &
		OR lbo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date') <> lbo_timesheet.of_GetItemDateTime(ll_ts_row - 1, 'work_date') THEN
			li_item = lbo_timesheet.of_get_next_ts_item(lbo_timesheet.of_GetItemNumber(ll_ts_row, 'employee'), lbo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date'))
		ELSE
			li_item++
		END IF
	ELSE
		li_item = lbo_timesheet.of_get_next_ts_item(lbo_timesheet.of_GetItemNumber(ll_ts_row, 'employee'), lbo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date'))
	END IF
	
	//Reverse Timesheet Premiums for this timesheet
	ll_tsp_rows = lbo_timesheet_premium.of_retrieve("book = '" + gnv_app.is_book 	&
			+ "' AND employee = " 			+ String(lbo_timesheet.of_GetItemNumber(ll_ts_row, 'employee')) 							&
			+ "  AND work_date = '" 		+ String(lbo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') 	&
			+ "' AND timesheet_item = " 	+ String(lbo_timesheet.of_GetItemNumber(ll_ts_row, 'timesheet_item')), TRUE)	//Append to existing rows
			
	FOR ll_tsp_row = 1 TO ll_tsp_rows
		//A little confusing because we are continually adding new rows to this business object,
		//so verify we're looking at one of the candidates for reversal, i.e. one of the premiums for the original timesheet items
		IF  lbo_timesheet_premium.of_GetItemDateTime(ll_tsp_row, 'work_date') = lbo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date') &
		AND lbo_timesheet_premium.of_GetItemNumber(ll_tsp_row, 'timesheet_item') = lbo_timesheet.of_GetItemNumber(ll_ts_row, 'timesheet_item') THEN
			ll_new_row = lbo_timesheet_premium.of_InsertRow(0)
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'book', 					lbo_timesheet_premium.of_GetItemString(ll_tsp_row, 'book'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'employee', 			lbo_timesheet_premium.of_GetItemNumber(ll_tsp_row, 'employee'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'work_date', 			lbo_timesheet_premium.of_GetItemDateTime(ll_tsp_row, 'work_date'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'timesheet_item',		li_item)
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'premium_type', 		lbo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'reg_rate', 			lbo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'tah_rate', 			lbo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'tah_rate'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'ovr_rate', 			lbo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'ovr_rate'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'reg_earn', 			-1.0 * lbo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'tah_earn', 			-1.0 * lbo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'tah_earn'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'ovr_earn', 			-1.0 * lbo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'ovr_earn'))
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'add_user_id',			gnv_app.of_getuserid())	
			lbo_timesheet_premium.of_SetItem(ll_new_row, 'add_datetime',		DateTime(Today(), Now()))
		END IF
	NEXT

	//Add a reversing timesheet
	ll_new_row = lbo_timesheet.of_InsertRow(0)
	li_cols = lbo_timesheet.of_GetColumnCount()
	FOR li_col = 1 TO li_cols
		ls_column = lbo_timesheet.of_GetColumnName(li_col)

		CHOOSE CASE Left(Upper(lbo_timesheet.of_GetColumnType(ls_column)), 5)
			CASE "DECIM"
				//Negate all dollar amounts
				lbo_timesheet.of_SetItem(ll_new_row, ls_column, -1.0 * lbo_timesheet.of_GetItemDecimal(ll_ts_row, ls_column))
			CASE ELSE
				//Duplicate everything else
				lbo_timesheet.of_SetItem(ll_new_row, ls_column, lbo_timesheet.of_GetItemAny(ll_ts_row, ls_column))
		END CHOOSE
	NEXT
	
	//Rates aren't negated
	lbo_timesheet.of_SetItem(ll_new_row, 'reg_rate',				lbo_timesheet.of_GetItemDecimal(ll_ts_row, 'reg_rate'))
	lbo_timesheet.of_SetItem(ll_new_row, 'tah_rate',				lbo_timesheet.of_GetItemDecimal(ll_ts_row, 'tah_rate'))
	lbo_timesheet.of_SetItem(ll_new_row, 'ovr_rate',				lbo_timesheet.of_GetItemDecimal(ll_ts_row, 'ovr_rate'))
	lbo_timesheet.of_SetItem(ll_new_row, 'travel_rate',			lbo_timesheet.of_GetItemDecimal(ll_ts_row, 'travel_rate'))
	lbo_timesheet.of_SetItem(ll_new_row, 'loa_rate',				lbo_timesheet.of_GetItemDecimal(ll_ts_row, 'loa_rate'))
	lbo_timesheet.of_SetItem(ll_new_row, 'mileage_rate',			lbo_timesheet.of_GetItemDecimal(ll_ts_row, 'mileage_rate'))
	lbo_timesheet.of_SetItem(ll_new_row, 'base_rate',				lbo_timesheet.of_GetItemDecimal(ll_ts_row, 'base_rate'))

	//Overwrite these values
	lbo_timesheet.of_SetItem(ll_new_row, 'timesheet_item',		li_item)
	lbo_timesheet.of_SetItem(ll_new_row, 'cheque_no',				al_next_cheque)
	lbo_timesheet.of_SetItem(ll_new_row, 'pr_yyyymm',				ls_pr_yyyymm)
	lbo_timesheet.of_SetItem(ll_new_row, 'transact_flag',			'N')
	lbo_timesheet.of_SetItem(ll_new_row, 'transact_datetime',	ldt_null)
	lbo_timesheet.of_SetItem(ll_new_row, 'file_type',				'C')
	lbo_timesheet.of_SetItem(ll_new_row, 'add_datetime',			DateTime(Today(), Now()))
	lbo_timesheet.of_SetItem(ll_new_row, 'fringe',					0)	//Don't want PRTRAN to think this is a payroll correction with fringe pre-populated
	
	IF lbo_timesheet.of_GetItemNumber(ll_ts_row, 'field_timesheet_item') > 0 THEN
		//preserve add user id for field generated timesheets
		lbo_timesheet.of_SetItem(ll_new_row, 'add_user_id', 		lbo_timesheet.of_GetItemString(ll_ts_row, 'add_user_id'))
	END IF
	lbo_timesheet.of_SetItem(ll_new_row, 'field_timesheet_item',	0)
	lbo_timesheet.of_SetItem(ll_new_row, 'billing_no',			ls_null)
	lbo_timesheet.of_SetItem(ll_new_row, 'billing_item',		0)

	li_item++
NEXT

//Reverse WCB
ll_wcb_rows = lbo_pr_cheque_wcb.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_wcb_row = 1 TO ll_wcb_rows

	ll_new_row = lbo_pr_cheque_wcb.of_InsertRow(0)
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'book', 						lbo_pr_cheque_wcb.of_GetItemString(ll_wcb_row, 'book'))
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'cheque_no', 				al_next_cheque)
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'wcb_class', 				lbo_pr_cheque_wcb.of_GetItemString(ll_wcb_row, 'wcb_class'))
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'employee', 					lbo_pr_cheque_wcb.of_GetItemNumber(ll_wcb_row, 'employee'))
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'timesheet_earn', 			-1.0 * lbo_pr_cheque_wcb.of_GetItemDecimal(ll_wcb_row, 'timesheet_earn'))
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'wcb_assessable_earn', 	-1.0 * lbo_pr_cheque_wcb.of_GetItemDecimal(ll_wcb_row, 'wcb_assessable_earn'))
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'wcb_remittance', 			-1.0 * lbo_pr_cheque_wcb.of_GetItemDecimal(ll_wcb_row, 'wcb_remittance'))
	lbo_pr_cheque_wcb.of_SetItem(ll_new_row, 'tax_year',			 		Left(ls_pr_yyyymm, 4))	
NEXT
	
//Reverse cheque premiums
ll_cp_rows = lbo_pr_cheque_premium.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = 1 TO ll_cp_rows

	ll_new_row = lbo_pr_cheque_premium.of_InsertRow(0)
	lbo_pr_cheque_premium.of_SetItem(ll_new_row, 'book', 				lbo_pr_cheque_premium.of_GetItemString(ll_cp_row, 'book'))
	lbo_pr_cheque_premium.of_SetItem(ll_new_row, 'cheque_no', 		al_next_cheque)
	lbo_pr_cheque_premium.of_SetItem(ll_new_row, 'premium_type', 	lbo_pr_cheque_premium.of_GetItemString(ll_cp_row, 'premium_type'))
	lbo_pr_cheque_premium.of_SetItem(ll_new_row, 'reg_earn', 		-1.0 * lbo_pr_cheque_premium.of_GetItemDecimal(ll_cp_row, 'reg_earn'))
	lbo_pr_cheque_premium.of_SetItem(ll_new_row, 'tah_earn', 		-1.0 * lbo_pr_cheque_premium.of_GetItemDecimal(ll_cp_row, 'tah_earn'))
	lbo_pr_cheque_premium.of_SetItem(ll_new_row, 'ovr_earn', 		-1.0 * lbo_pr_cheque_premium.of_GetItemDecimal(ll_cp_row, 'ovr_earn'))
NEXT
	
//Reverse cheque trade union
ll_cp_rows = lbo_pr_cheque_trade_union.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = 1 TO ll_cp_rows

	//Add a reversing timesheet
	ll_new_row = lbo_pr_cheque_trade_union.of_InsertRow(0)
	li_cols = lbo_pr_cheque_trade_union.of_GetColumnCount()
	FOR li_col = 1 TO li_cols
		ls_column = lbo_pr_cheque_trade_union.of_GetColumnName(li_col)

		CHOOSE CASE Left(Upper(lbo_pr_cheque_trade_union.of_GetColumnType(ls_column)), 5)
			CASE "DECIM"
				//Negate all dollar amounts
				lbo_pr_cheque_trade_union.of_SetItem(ll_new_row, ls_column, -1.0 * lbo_pr_cheque_trade_union.of_GetItemDecimal(ll_cp_row, ls_column))
			CASE ELSE
				//Duplicate everything else
				lbo_pr_cheque_trade_union.of_SetItem(ll_new_row, ls_column, lbo_pr_cheque_trade_union.of_GetItemAny(ll_cp_row, ls_column))
		END CHOOSE
	NEXT
	//Overwrite these values
	lbo_pr_cheque_trade_union.of_SetItem(ll_new_row, 'cheque_no',				al_next_cheque)
NEXT
	
//Reverse cheque occupation
ll_cp_rows = lbo_pr_cheque_occupation.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = 1 TO ll_cp_rows

	//Add a reversing timesheet
	ll_new_row = lbo_pr_cheque_occupation.of_InsertRow(0)
	li_cols = lbo_pr_cheque_occupation.of_GetColumnCount()
	FOR li_col = 1 TO li_cols
		ls_column = lbo_pr_cheque_occupation.of_GetColumnName(li_col)

		CHOOSE CASE Left(Upper(lbo_pr_cheque_occupation.of_GetColumnType(ls_column)), 5)
			CASE "DECIM"
				//Negate all dollar amounts
				lbo_pr_cheque_occupation.of_SetItem(ll_new_row, ls_column, -1.0 * lbo_pr_cheque_occupation.of_GetItemDecimal(ll_cp_row, ls_column))
			CASE ELSE
				//Duplicate everything else
				lbo_pr_cheque_occupation.of_SetItem(ll_new_row, ls_column, lbo_pr_cheque_occupation.of_GetItemAny(ll_cp_row, ls_column))
		END CHOOSE
	NEXT
	//Overwrite these values
	lbo_pr_cheque_occupation.of_SetItem(ll_new_row, 'cheque_no',				al_next_cheque)
NEXT
	
//Reverse cheque union remit
ll_cp_rows = lbo_pr_cheque_union_remit.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_cp_row = 1 TO ll_cp_rows

	//Add a reversing timesheet
	ll_new_row = lbo_pr_cheque_union_remit.of_InsertRow(0)
	li_cols = lbo_pr_cheque_union_remit.of_GetColumnCount()
	FOR li_col = 1 TO li_cols
		ls_column = lbo_pr_cheque_union_remit.of_GetColumnName(li_col)

		CHOOSE CASE Left(Upper(lbo_pr_cheque_union_remit.of_GetColumnType(ls_column)), 5)
			CASE "DECIM"
				//Negate all dollar amounts
				lbo_pr_cheque_union_remit.of_SetItem(ll_new_row, ls_column, -1.0 * lbo_pr_cheque_union_remit.of_GetItemDecimal(ll_cp_row, ls_column))
			CASE ELSE
				//Duplicate everything else
				lbo_pr_cheque_union_remit.of_SetItem(ll_new_row, ls_column, lbo_pr_cheque_union_remit.of_GetItemAny(ll_cp_row, ls_column))
		END CHOOSE
	NEXT
	//Overwrite these values
	lbo_pr_cheque_union_remit.of_SetItem(ll_new_row, 'cheque_no',				al_next_cheque)
NEXT
	
//Reversing employee purchase entries
ll_ep_rows = lbo_employee_purchase.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no))
FOR ll_ep_row = 1 TO ll_ep_rows

	ll_new_row = lbo_employee_purchase.of_InsertRow(0)
	lbo_employee_purchase.of_SetItem(ll_new_row, 'book', 				lbo_employee_purchase.of_GetItemString(ll_ep_row, 'book'))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'employee', 		lbo_employee_purchase.of_GetItemNumber(ll_ep_row, 'employee'))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'vendor', 			lbo_employee_purchase.of_GetItemString(ll_ep_row, 'vendor'))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'invoice_no', 		lbo_employee_purchase.of_GetItemString(ll_ep_row, 'invoice_no'))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'invoice_item', 	lbo_employee_purchase.of_GetItemNumber(ll_ep_row, 'invoice_item'))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'cheque_no', 		al_next_cheque)
	lbo_employee_purchase.of_SetItem(ll_new_row, 'activity_date', 	DateTime(Today(), Now()))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'gl_yyyymm', 		lbo_employee_purchase.of_GetItemString(ll_ep_row, 'gl_yyyymm'))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'amount', 			-1.0 * lbo_employee_purchase.of_GetItemDecimal(ll_ep_row, 'amount'))
	lbo_employee_purchase.of_SetItem(ll_new_row, 'file_type', 		'C')
NEXT

//Insert void cheque
ll_new_row = this.of_InsertRow(0)

//Copy original cheque
li_cols = Long(this.ids_data.Object.DataWindow.Column.Count)
FOR li_col = 1 TO li_cols
	ls_column = this.ids_data.Describe('#' + String(li_col) + ".Name")

	CHOOSE CASE Left(Upper(This.ids_data.Describe(ls_column + ".ColType")), 5)
		CASE "DECIM"
			//Negate all dollar amounts
			this.of_SetItem(ll_new_row, ls_column, -1.0 * this.of_GetItemDecimal(1, ls_column))
		CASE ELSE
			//Duplicate everything else
			this.of_SetItem(ll_new_row, ls_column, this.of_GetItemAny(1, ls_column))
	END CHOOSE
NEXT

//Use these values on the void cheque
this.of_SetItem(ll_new_row, 'cheque_no', 			al_next_cheque)
this.of_SetItem(ll_new_row, 'void_cheque_no', 	al_cheque_no)
this.of_SetItem(ll_new_row, 'issue_date', 		DateTime(Today(), Time(0,0,0)))
this.of_SetItem(ll_new_row, 'transact_flag', 	'N')
this.of_SetItem(ll_new_row, 'cheque_status', 	'A')
this.of_SetItem(ll_new_row, 'pr_yyyymm', 			ls_pr_yyyymm)
this.of_SetItem(ll_new_row, 'transact_datetime',ldt_null)
this.of_SetItem(ll_new_row, 'add_datetime', 		DateTime(Today(), Time(0,0,0)))
this.of_SetItem(ll_new_row, 'add_user_id', 		gnv_app.of_getuserid())
this.of_SetItem(ll_new_row, 'file_type', 			'C')

//for logging
IF This.ids_data.Describe("action.Name") = "action" THEN
	this.of_SetItem(1, 'action', 'C')
	this.of_SetItem(ll_new_row, 'action', 'D')
END IF

//This will update the cheque and all child business objects
IF this.of_UpdateAll(FALSE, lstr_err) = -1 THEN
	this.of_Rollback()
	IF UpperBound(lstr_err) > 0 THEN 
		ls_warning_msg = String(this.of_GetItemNumber(ll_new_row, 'cheque_no')) + ': ' + lstr_err[1].s_message
		FOR ll_err = 1 TO UpperBound(lstr_err) 
			ls_errors += "~n" + gnv_app.of_format_validation_error( lstr_err[ll_err])
		NEXT
		MessageBox("Reverse Printed Cheque",ls_errors)
	END IF
	//Errors may be that cheques are too old, so a legitimate validation error
	//gnv_app.of_msg_db_error("PRCENT","Error updating cheque " + ls_warning_msg)
	RETURN -1
ELSE
	this.of_Commit()
	IF lbo_employee_purchase.of_RowCount() > 0 THEN
		lbo_employee_purchase.of_reset_fully_paid_invoices(lbo_employee_purchase.of_GetItemNumber(ll_ep_row, 'employee'))
		lbo_employee_purchase.of_update(true, lstr_err)
		IF UpperBound(lstr_err) > 0 THEN 
			ls_warning_msg = String(this.of_GetItemNumber(ll_new_row, 'cheque_no')) + ': ' + lstr_err[1].s_message
			FOR ll_err = 1 TO UpperBound(lstr_err) 
				ls_errors += "~n" + gnv_app.of_format_validation_error( lstr_err[ll_err])
			NEXT
			MessageBox("Resetting employee purchase",ls_errors)
			gnv_app.of_msg_db_error("PRCENT","Error resetting employee purchase " + ls_warning_msg)
			RETURN -1
		END IF
	END IF
END IF 
  
//Record which cheque number we used
UPDATE company
	SET pr_last_cheque_no = :al_next_cheque
 WHERE book = :gnv_app.is_book
 USING sqlca;
IF sqlca.sqlcode <> 0 THEN
	gnv_app.of_msg_db_error("PRCENT","Error updating company ")
	RETURN -1
END IF

//Produce warnings

//Warn if monthly dues are going to need resetting
IF this.of_GetItemDecimal(1, 'union_dues') <> 0 					&
AND String(Year(Date(this.of_GetItemDateTime(1, 'issue_date')))) 	&
  + String(Month(Date(this.of_GetItemDateTime(1, 'issue_date')))) 	&
  < String(Year(Today())) + String(Month(Today())) THEN
  
	//Deleting a cheque in a past month
	lbo_trade_union_rate = CREATE n_bo_trade_union_rate
	lbo_trade_union_rate.of_SetTransaction()
	li_rc = lbo_trade_union_rate.of_Retrieve("book = '" + gnv_app.is_book + "' and trade_union = '" + this.of_GetItemString(1, 'trade_union') + "' AND effective_date < '" + String(this.of_GetItemDateTime(1, 'issue_date'), 'yyyy.mm.dd') + "'")
	IF li_rc < 0 OR lbo_trade_union_rate.of_RowCount() < 1 THEN
		gnv_app.of_msg_db_error("PRCENT","Error reading trade_union_rate")
		RETURN -1
	END IF
	
	//Make most recent record first
	lbo_trade_union_rate.of_SetSort("effective_date DESC")
	lbo_trade_union_rate.of_Sort()
	IF lbo_trade_union_rate.of_GetItemDecimal(1, "max_monthly_dues") > 0 THEN
		//Cheque was subject to monthly maximums, this deletion is going to throw it off.
		ls_warning_msg = "Deleting cheque from previous month where union limits monthly dues, monthly dues may need correction. "
	END IF	
END IF

//Warn about turnaround due date
lbo_employee = CREATE n_bo_employee
lbo_employee.of_SetTransaction()
li_rc = lbo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' and employee = " + String(this.of_GetItemNumber(1, 'employee')))
IF li_rc < 0 THEN
	gnv_app.of_msg_db_error("PRCENT","Error reading employee")
	RETURN -1
END IF
ldt_turndue	= lbo_employee.of_GetItemDateTime(1, "next_turnaround_due_date")

IF this.of_GetItemDecimal(1, 'turnaround') <> 0 &
AND Not(IsNull(ldt_turndue)) THEN
	ls_warning_msg = "Employee turnaround due date may need correction"
END IF	

IF as_mode = 'delete' THEN
	as_msg = "A void cheque has been created along with negative timesheets that may be deleted following the cheque and transaction runs."
END IF

//Override the default message with the warning message
IF ls_warning_msg <>  '' THEN as_msg = ls_warning_msg		

IF IsValid(lbo_employee) 				THEN DESTROY lbo_employee
IF IsValid(lbo_employee_purchase) 	THEN DESTROY lbo_employee_purchase
IF IsValid(lbo_trade_union_rate) 	THEN DESTROY lbo_trade_union_rate
IF IsValid(lbo_pr_cheque_wcb) 		THEN DESTROY lbo_pr_cheque_wcb
IF IsValid(lbo_pr_cheque_premium)	THEN DESTROY lbo_pr_cheque_premium
IF IsValid(lbo_pr_cheque_trade_union)	THEN DESTROY lbo_pr_cheque_trade_union
IF IsValid(lbo_pr_cheque_occupation)	THEN DESTROY lbo_pr_cheque_occupation
IF IsValid(lbo_pr_cheque_union_remit)	THEN DESTROY lbo_pr_cheque_union_remit
IF IsValid(lbo_timesheet) 				THEN DESTROY lbo_timesheet
IF IsValid(lbo_timesheet_premium) 	THEN DESTROY lbo_timesheet_premium

RETURN 2

end function

public function integer of_delete_cheque (long al_cheque_no, string as_mode, ref string as_msg, ref long al_next_cheque);//************************************************************
// Object   :	n_abio_appmanager 
// Function :	of_delete_cheque
// Author   :	Monica Petersen
// Date     :	2010/02/23
// 	
// Arguments:	n_ds ads_pr_cheque
// 				long al_cheque_no
// 				string as_pr_yyyymm
// 				string as_mode
// 				statictext ast_text
// 	
// Returns:		integer
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2010.02.23		MDP	jira 1447 - add warning for maximum monthly dues
// 2010.08.19		MDP	jira 1585 - When reversing a cheque, populate the form number with the form number of the original cheque
// 2010.02.13		MDP	jira 1685 - reverse premium types
//************************************************************


String	ls_status, ls_retrieve, ls_sql
long		ll_employee, ll_rows

this.of_SetTransaction(sqlca)
ls_retrieve = "book = '" + gnv_app.is_book + "' AND cheque_no = " + String(al_cheque_no)
ll_rows = this.of_Retrieve(ls_retrieve) 

IF ll_rows <> 1 THEN
	//ls_sql = this.ids_data.GetSQLSelect()
	//If there are overlapping trade unions, this will return 2 records
	gnv_app.of_msg_db_error('PRCENT', 'Error reading cheque  ' + String(al_cheque_no) + '. Possible causes are incorrectly set up trade union.')
	RETURN -1
END IF

ls_status 	= this.of_GetItemString(1, 'cheque_status')
ll_employee = this.of_GetItemNumber(1, 'employee')

IF ls_status = 'U' OR ls_status = 'A' THEN
	
	// cheque not printed so delete cheque and reset to timesheets to no cheque
	this.of_delete_unprinted_cheque(al_cheque_no, as_mode, as_msg)
	
	IF as_mode = 'delete' THEN as_msg = "Cheque has been deleted and timesheets reset to no cheque"
	
ELSE
	
	RETURN this.of_reverse_printed_cheque(al_cheque_no, as_mode, as_msg, al_next_cheque)
	
END IF

RETURN 1

end function

public function integer of_tax_calc (string as_release_vacation_pay, string as_release_statutory_pay, string as_release_personal_safety, string as_release_group_safety, string as_release_other_safety, string as_release_small_tools, string as_release_retention, string as_release_production_bonus, string as_release_incentive, ref n_cst_business abo_pr_ck, string as_mode, ref decimal adec_total_unpaid_employee_purchases, ref n_ds ads_msg, ref n_bo_employee_purchase abo_employee_purchase, ref n_bo_pr_cheque_trade_union abo_pr_cheque_trade_union, ref n_bo_pr_cheque_occupation abo_pr_cheque_occupation);// Object   :	n_abio_appmanager 
// Function :	of_tax_calc
// Object   :	n_bo_pr_cheque 
// Function :	of_reverse_printed_cheque
// Author   :	Monica Petersen
// Date     :	2009/04/25
// Date     :	2013/03/27
// 	
// Arguments:	string as_release_vacation_pay
// 				string as_release_statutory_pay
// 				string as_release_personal_safety
// 				string as_release_group_safety
// 				string as_release_other_safety
// 				string as_release_small_tools
// 				string as_release_retention
// 				string as_release_incentive
// 				n_ds abo_pr_ck
// 				n_ds abo_pr_ck_wcb
// 				string as_mode
// 				decimal adec_total_unpaid_employee_purchases
// Arguments:	long al_cheque_no
// 				string ls_pr_yyyymm
// 				string as_msg
// 				long al_next_cheque
// 	
// Returns:		integer
// 	
// Desc:			Calculate taxes, cpp, EI, vacation, stat.  
//					Called when approving cheques and when transitting
//		         fields on the PRCENT screen.
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2008.11.10		MDP		Break shift premium out from fringe amounts.
// 2009.04.24		MDP		jira 497 - Allow unions to have 'B'oth pension and RRSP amounts
// 2009.05.11		MDP		Read birth_date from person instead of employee
// 2009.05.12		MDP		jira 600 - add additional_rrsp amount to union_rrsp for non-staff
// 2009.05.13		MDP		jira 534 - Use the trade union on the cheque, not the employee,
//                                    in case the employee has recently changed unions
// 2009.05.15		MDP		jira 600 - record pension against union liability account for non-staff
// 2009.05.15		MDP		jira 603 - remove tax_holiday_as_pay_flag
// 2009.05.25		MDP		jira 623 - set pr_cheque_last_monthly_remit
//
// 2009.07.23		MDP		jira 943 - remove any references to company.tax_taxable_benefit_flag. In all cases this value is Yes. 
//                                  - employee.rrsp_percent has been changed to employee.employer_rrsp_percent and employee.employee_rrsp_percent has been added. 
//												  if trade_union_rate.rrsp_if_employee_pays_flag=N then 
//													  pr_cheque.union_rrsp continues to be calculated in the exsting fashion. 
//												  If this value is Y and employee.employee_rrsp_percent=0 then 
//													  union_rrsp amount is zero otherwise union_rrsp is calculated. 
//												  If the employee.employee_rrsp_percent is non-zero then 
//													  employee_rrsp calculated gets added to pr_cheque.incentive_paid_to_rrsp (additional union rrsp). 
//												- vehicle_allowance_paid adds to gross_pay and to taxable_earn but not ei_earn or cpp_earn.
// 2009.07.27		MDP		jira 958 - remove employee.rrsp_on_ot_earning_flag and tax_employee_rrsp_flag
// 2009.10.13		MDP		jira 1148 - payment in lieu of notice 
// 2009.10.16		MDP		jira 1142 - Split employee.vendor into subcontract_vendor and rrsp_vendor 
// 2009.10.20		MDP		jira 1136 - only allow incentives to be released to additional union rrsp if the union has RRSP values
// 2009.11.12		MDP		jira 1300 - union dues on all hours at regular rates
// 2009.12.11		MDP		jira 1331 - add statutory_lost and vacation_lost
// 2010.02.17		MDP		jira 1447 - max monthly dues
// 2010.11.05		MDP		jira 1652 - where travel_earning and travel_hour is included in a calculation for 
//													union dues, benefits, vacation, statutory, RRSP and pension, 
//													it needs to test the trade_union_rate.include_travel_flag.
// 2010.11.05		MDP		jira 1693 - The routine that calculates pr_cheque.net_pay must subtract both pr_cheque.vacation_paid_to_union 
//													and pr_cheque.statutory_paid_to_union as this money is being withheld. 
// 2011.02.10		MDP		jira 1715 - Incorporate the new premium flag values into cheque approval
//													- replace all_hr_base_earn, all_hr_reg_earn, all_hr_sched_earn
//
// 2011.10.05		MDP		jira 1899 - Please calculate an employee pension amount from employee.employee_pension_percent in the same fashion 
//													that an employee RRSP amount is calculated from employee.employee_rrsp_percent. This amount is added 
//													to pr_cheque.employee_pension. 
//
//													Once union_pension has been calculated, if trade_union_rate.pension_if_employee_pays_flag is Yes 
//													AND pr_cheque.employee_pension is zero, then pr_cheque.union_pension must be set to zero. 
//
// 2012.04.15		MDP		jira 2159 - implement back dues
//	2012.06.11		MDP		jira 2223 - change calculation of monthly dues to use the year-month of the cheque issue date
//	2021.04.23		MDP		add quebec taxes
//************************************************************

String						ls_pryyyymm
String						ls_null, ls_find, ls_occupation

Integer						li_current_pay_period, li_age, li_rc, li_cpp_months

Long							ll_msg_row, ll_find, ll_cheque

Decimal						ldec_cpp_annual_maximum, ldec_cpp_multiplier, ldec_cpp_annual_allowance
Decimal						ldec_cpp_base_rate, ldec_cpp_base_maximum, ldec_cpp_first_rate
Decimal						ldec_cpp_second_rate, ldec_cpp_second_max_earning, ldec_earnings_over_first_cpp_maximum, ldec_cpp_ytd_with_this_cheque, ldec_cpp2
Decimal   					ldec_cpp2_contribution, ldec_cpp2_earn
Decimal   					ldec_ytd_cpp2_contribution
Decimal   					ldec_cpp2_annual_maximum, ldec_cpp2_annual_remaining
Decimal						ldec_ei_annual_max_premium, ldec_ei_annual_max_earning, ldec_ei_employer_multiplier,ldec_ei_employee_rate

Decimal						ldec_cpp_max_contributions_based_on_age, ldec_cpp_contribution, ldec_ytd_cpp_earn, ldec_ytd_cpp2_earn, ldec_cpp_earn, ldec_cpp_prorated_allowance
Decimal						ldec_ytd_ei_premium, ldec_ytd_ei_earn
Decimal						ldec_ei_outstanding, ldec_ei_current
Decimal						ldec_ytd_qpip_premium, ldec_ytd_qpip_earn
Decimal						ldec_qpip_outstanding, ldec_qpip_current
Decimal						ldec_A, ldec_k2, ldec_t1, ldec_t2, ldec_income_tax_fed, ldec_income_tax_prov
Decimal						ldec_wcb_earn, ldec_work
Decimal						ldec_wcb_remittance
Decimal						ldec_cpp, ldec_ei, ldec_qpip, ldec_ytd_cpp_contribution, ldec_cpp_annual_remaining_contribution, ldec_ytd_taxable_earn, ldec_cpp_first_max_earning
Decimal						ldec_union_dues_for_month, ldec_daily_due
Decimal						ldec_hours, ldec_reg_earn
Decimal						ldec_pension_premium_earn
Decimal						ldec_dues_premium_earn, ldec_dues_premium_earn_this_tu
Decimal						ldec_rrsp_premium_earn
Decimal						ldec_latest_timesheet_reg_rate
Decimal						ldec_increase_income_tax_by
Decimal						ldec_cpp_portion_of_fringe, ldec_ei_portion_of_fringe, ldec_education_portion_of_fringe, ldec_wcb_portion_of_fringe, ldec_qpip_portion_of_fringe
Decimal						ldec_rrsp
Decimal						ldec_pet_portion, ldec_employer_tax
Decimal						ldec_annual_income, ldec_c, ldec_c2, ldec_i, ldec_ii, ldec_cpp2_max, ldec_w // for calculating 2nd tier CPP

Decimal						ldec_cpp_pp_exemption

Date							ld_last_day_of_pp
DateTime						ldt_work, ldt_last_month_of_dues, ldt_work_last, ldt_null, ldt_birth_date
DateTime						ldt_pr_yyyymm_01

Long							ll_emp_rows
Long							ll_ts_rows, 	ll_ts_row, ll_employee, ll_count_pp, ll_pet_row, ll_pet_rows, ll_ctu_row, ll_co_row, ll_co_rows

Boolean						lb_cpp_exempt, lb_over_71, lb_recalc_dues_on_parent_cheque = FALSE, lb_a_union_remits_vacation_pay, lb_a_union_remits_statutory_pay
SetNull(ldt_null)
SetNull(ls_null)

//---------------------------------
//Validate input
//---------------------------------

IF abo_pr_ck.of_RowCount() < 1 THEN
	this.of_prcent_err("Error calculating tax: " + sqlca.sqlerrtext, 0, ads_msg)
	RETURN -1
END IF

//---------------------------------
// Retrieve records used to calculate tax
//---------------------------------

//Retrieve the timesheets that contribute to this cheque, so we can determine base earning amounts for RRSP, pension, vacation and stat
// previously the all_hr_base_earn, all_hr_sched_earn, all_hr_reg_earn were used for this
ll_ts_rows = ibo_timesheet.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) )
abo_pr_cheque_trade_union.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')))
abo_pr_cheque_occupation.of_Retrieve("book = '" + gnv_app.is_book + "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')))

//Retrieve company default processing values
IF ibo_company.of_Retrieve("book = '" + gnv_app.is_book + "'") < 1 THEN
	this.of_prcent_err("ERROR retrieving company defaults: " + sqlca.sqlerrtext, 0, ads_msg)
	RETURN -1
END IF 

//Retrieve all premiums for efficiency, just use find to locate one being processed
ibo_pr_cheque_premium.of_Retrieve("book = '" + gnv_app.is_book + "' and cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')))

//Employee
IF ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' and employee = " + String(abo_pr_ck.of_GetItemNumber(1, 'employee'))) < 1 THEN
	this.of_prcent_err("Can't find employee ", abo_pr_ck.of_GetItemNumber(1, 'employee'), ads_msg)
	RETURN -1
END IF

//Employee earning record for current tax year (may not exist, gets created for the first time in cheque issuance (PRCHEQ))
ll_emp_rows = ibo_employee_earning.of_Retrieve("book = '" + gnv_app.is_book &
											+ "' and employee = " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')) &
											+ " and tax_year = '" + Left(abo_pr_ck.of_GetItemString(1, 'pr_yyyymm'), 4) + "'")
CHOOSE CASE ll_emp_rows 
	CASE IS < 0 
		this.of_prcent_err("Can't find employee earnings", abo_pr_ck.of_GetItemNumber(1, 'employee'), ads_msg)
		RETURN -1
	CASE 0
		ldec_ytd_taxable_earn		= 0
		ldec_ytd_cpp_contribution	= 0
		ldec_ytd_cpp2_contribution	= 0
		ldec_ytd_cpp_earn				= 0
		ldec_ytd_cpp2_earn			= 0
		ldec_ytd_ei_earn				= 0
		ldec_ytd_ei_premium			= 0
		ldec_ytd_qpip_earn			= 0
		ldec_ytd_qpip_premium		= 0
	CASE 1
		ldec_ytd_taxable_earn		= ibo_employee_earning.of_GetItemDecimal(1, "taxable_earn")
		ldec_ytd_cpp_contribution	= ibo_employee_earning.of_GetItemDecimal(1, "cpp_contribution")
		ldec_ytd_cpp2_contribution	= ibo_employee_earning.of_GetItemDecimal(1, "cpp2_contribution")
		ldec_ytd_cpp_earn				= ibo_employee_earning.of_GetItemDecimal(1, "cpp_earn")
		ldec_ytd_cpp2_earn			= ibo_employee_earning.of_GetItemDecimal(1, "cpp2_earn")
		ldec_ytd_ei_earn				= ibo_employee_earning.of_GetItemDecimal(1, "ei_earn")
		ldec_ytd_ei_premium			= ibo_employee_earning.of_GetItemDecimal(1, "ei_premium")
		ldec_ytd_qpip_earn			= ibo_employee_earning.of_GetItemDecimal(1, "qpip_earn")
		ldec_ytd_qpip_premium		= ibo_employee_earning.of_GetItemDecimal(1, "qpip_premium")
END CHOOSE

//Use business object to retrieve birth_date
ibo_person.of_Retrieve("employee = " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')))
ldt_birth_date = ibo_person.of_GetItemDatetime(1, "birth_date")
lb_over_71 = g_bo_application_properties.of_GetItemString(1, 'over_71_rrsp_to_cash_flag') = 'Y' &
				AND Year(Date(abo_pr_ck.of_GetItemDateTime(1, 'issue_date'))) - Year(Date(ldt_birth_date)) >= 71
				
// lookup trade union settings
IF ibo_trade_union.of_Retrieve("book = '" + gnv_app.is_book + "' AND trade_union = '" + abo_pr_ck.of_GetItemString(1, 'trade_union') + "'") < 1 THEN
	this.of_prcent_err("Can't find union " + abo_pr_ck.of_GetItemString(1, 'trade_union') + " for employee " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')), abo_pr_ck.of_GetItemNumber(1, 'employee'), ads_msg)
	RETURN -1
END IF

//pay period table for company and union pay period type
//Find last day of pay period - use pay period start date on cheque, because cheque may have been created and pay period advanced already - jira 2952
IF ibo_pay_period.of_get_last_day_of_pay_period(ibo_trade_union.of_GetItemString(1, 'pay_period_type'), Date(abo_pr_ck.of_GetItemDateTime(1, 'pay_period_start_date')), ld_last_day_of_pp) < 1 THEN
	RETURN -1
END IF

IF ibo_pay_period.of_Retrieve("pay_period_type = '" + ibo_trade_union.of_GetItemString(1, 'pay_period_type') + "' AND year = '" + Left(ibo_company.of_GetItemString(1, 'pr_yyyymm'), 4) + "'") < 1 THEN
	this.of_prcent_err("Can't find pay period " + ibo_trade_union.of_GetItemString(1, 'pay_period_type') + " for union " + abo_pr_ck.of_GetItemString(1, 'trade_union') + " in " + Left(ibo_company.of_GetItemString(1, 'pr_yyyymm'), 4), abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), ads_msg)
	RETURN -1
END IF

//Get rates for trade union at the time of cheque creation (governs pension, rrsp, union dues, vacation, stat etc.
IF ibo_trade_union_rate.of_Retrieve("book = '" + gnv_app.is_book &
															+ "' AND trade_union = '" + abo_pr_ck.of_GetItemString(1, 'trade_union') &
															+ "' AND effective_date <= '" + String(ld_last_day_of_pp, 'yyyy.mm.dd') &
															+ "' AND expiry_date >= '" + String(ld_last_day_of_pp, 'yyyy.mm.dd') + "'") < 1 THEN
	this.of_prcent_err("Cheque " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) + ": Remittance rates aren't set up for union '" + abo_pr_ck.of_GetItemString(1, 'trade_union') + "' effective on " + String(ld_last_day_of_pp, 'yyyy.mm.dd'), abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), ads_msg)
	RETURN -1
END IF

//Initialize these here, they may change if there are multiple unions on a cheque
//but if any of the union remits vac/stat to the union, then only vacation earned in the
//pay period, by the union, can be released to the union (i.e. they can't be paid vacation earned from another union)
lb_a_union_remits_vacation_pay = ibo_trade_union_rate.of_GetItemString(1, 'remit_vacation_pay_flag') = 'Y'
lb_a_union_remits_statutory_pay = ibo_trade_union_rate.of_GetItemString(1, 'remit_statutory_pay_flag') = 'Y'

//Get the most current federal tax rates based on G/L period
ldt_pr_yyyymm_01 = DateTime(Date(Long(Left(abo_pr_ck.of_GetItemString(1, 'pr_yyyymm'), 4)), Long(Right(abo_pr_ck.of_GetItemString(1, 'pr_yyyymm'), 2)), 1), Time(0,0,0))
IF ibo_federal_tax.of_Retrieve("effective_date <= '" + String(ldt_pr_yyyymm_01, 'yyyy.mm.dd') + "' AND expiry_date >= '" + String(ldt_pr_yyyymm_01, 'yyyy.mm.dd') + "'") <> 1 THEN
	this.of_prcent_err("Can't find federal tax entry for " + String(ldt_pr_yyyymm_01, 'yyyy.mm.dd'), abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), ads_msg)
	RETURN -1
END IF

//default EFT information to employee's account
IF as_mode = 'approve' AND ibo_company.of_GetItemString(1, 'eft_type') <> 'N' THEN
	IF IsNull(ibo_employee.of_GetItemString(1, "eft_us_routing")) THEN 
		abo_pr_ck.of_SetItem(1, "eft_us_routing", '')
	ELSE
		abo_pr_ck.of_SetItem(1, 'eft_us_routing', ibo_employee.of_GetItemString(1, "eft_us_routing"))
	END IF
	IF IsNull(ibo_employee.of_GetItemString(1, "eft_institution")) THEN 
		abo_pr_ck.of_SetItem(1, "eft_institution", '')
	ELSE
		abo_pr_ck.of_SetItem(1, 'eft_institution', ibo_employee.of_GetItemString(1, "eft_institution"))
	END IF
	IF IsNull(ibo_employee.of_GetItemString(1, "eft_branch")) THEN 
		abo_pr_ck.of_SetItem(1, "eft_branch", '')
	ELSE
		abo_pr_ck.of_SetItem(1, 'eft_branch', 		ibo_employee.of_GetItemString(1, "eft_branch"))
	END IF
	IF IsNull(ibo_employee.of_GetItemString(1, "eft_account")) THEN 
		abo_pr_ck.of_SetItem(1, "eft_account", '')
	ELSE
		abo_pr_ck.of_SetItem(1, 'eft_account', 		ibo_employee.of_GetItemString(1, "eft_account"))
	END IF
END IF

// in case re - approved
// fields that the user can change should only be reset when user re-approves
// a batch.  
IF as_mode = 'approve' THEN	
	abo_pr_ck.of_SetItem(1, 'employee_pension', 			0)
	abo_pr_ck.of_SetItem(1, 'employee_rrsp', 				0)		
	abo_pr_ck.of_SetItem(1, 'misc_deduction', 			0)		
	abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', 	0)
	abo_pr_ck.of_SetItem(1, 'employer_rrsp', 				0)
	abo_pr_ck.of_SetItem(1, 'union_rrsp', 					0)
	abo_pr_ck.of_SetItem(1, 'province_education_tax', 	0)
	abo_pr_ck.of_SetItem(1, 'province_payroll_tax', 	0)
END IF

IF as_mode <> 'recalc' THEN

	// Initialize values that are being calculated
	// These fields are based on fields that the user can't change after approval, so they should be recalculated
	// after each change
	abo_pr_ck.of_SetItem(1, 'vacation_earn', 				0)
	abo_pr_ck.of_SetItem(1, 'vacation_hours_earn',		0)
	abo_pr_ck.of_SetItem(1, 'statutory_earn', 			0)
	abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', 		0)
	abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', 		0)
	abo_pr_ck.of_SetItem(1, 'shift_premium_fringe',		0) 
	abo_pr_ck.of_SetItem(1, 'all_hr_reg_earn', 			0)
	abo_pr_ck.of_SetItem(1, 'all_hr_base_earn', 			0)
	abo_pr_ck.of_SetItem(1, 'union_pension',				0)
	abo_pr_ck.of_SetItem(1, 'union_rrsp', 					0)
	abo_pr_ck.of_SetItem(1, 'union_rrsp_paid_out', 		0)
	abo_pr_ck.of_SetItem(1, 'employer_rrsp_paid_out', 	0)
	abo_pr_ck.of_SetItem(1, 'employer_rrsp', 				0)
	abo_pr_ck.of_SetItem(1, 'add_to_union_remittance', 0)

	FOR ll_ctu_row = 1 TO abo_pr_cheque_trade_union.of_RowCount()
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'pension_source_earn', 	0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'rrsp_source_earn', 		0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'dues_source_earn', 		0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'vacation_source_earn', 	0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'statutory_source_earn', 	0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'employee_pension', 		0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'union_pension', 			0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'union_rrsp', 				0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'employee_rrsp',				0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'union_rrsp_paid_out', 	0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'employer_rrsp_paid_out',	0)
		IF as_mode = 'approve' THEN abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'union_dues', 				0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'union_remittance', 		0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'add_to_union_remittance', 		0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'vacation_earn', 			0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'vacation_paid_to_union', 0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'statutory_earn', 			0)
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'statutory_paid_to_union',0)
	NEXT
	
	FOR ll_ctu_row = 1 TO abo_pr_cheque_occupation.of_RowCount()
		abo_pr_cheque_occupation.of_SetItem(ll_ctu_row, 'union_rrsp', 			0)
		abo_pr_cheque_occupation.of_SetItem(ll_ctu_row, 'union_pension', 		0)
		abo_pr_cheque_occupation.of_SetItem(ll_ctu_row, 'employee_rrsp', 		0)
		abo_pr_cheque_occupation.of_SetItem(ll_ctu_row, 'add_to_union_remittance', 		0)
	NEXT

	//might as well zero the cheque fields too, so the cheque and the child records are synchronized
	of_tax_calc_roll_up(abo_pr_ck, abo_pr_cheque_trade_union, abo_pr_cheque_occupation)
				
	//---------------------
	// Read premiums for current timesheets
	//---------------------
	
	ldec_dues_premium_earn = 0
	ldec_rrsp_premium_earn = 0
	ldec_pension_premium_earn = 0
	FOR ll_ts_row = 1 TO ll_ts_rows
		
		//Read premiums for current timesheet	
		ibo_timesheet_premium.of_Retrieve("book = '" + gnv_app.is_book								&
						+ "' AND employee = " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'employee')) 	&
						+ "  AND work_date = '" + String(ibo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') &
						+ "' AND timesheet_item = " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'timesheet_item')))
		
		//accumulate premiums for this timesheet
		of_tax_calc_premiums_for_timesheets(ibo_timesheet, ll_ts_row, &
														ibo_timesheet_premium, 	&
														ibo_trade_union_rate, 	&
														ldec_dues_premium_earn, &
														ldec_rrsp_premium_earn, &
														ldec_pension_premium_earn)
	NEXT
		
	//---------------------
	// Vacation and Statutory and paid sick leave
	//---------------------

	//Scan timesheets for source earnings, determine vacation and stat earnings
	of_tax_calc_vacation_stat_sick(ld_last_day_of_pp, 					&
										 abo_pr_ck, 							&
										 ads_msg, 								&
										 ldec_latest_timesheet_reg_rate,	&
										 abo_pr_cheque_trade_union)
	
	//Put this in before rolling the amounts from the child tables up into the parent tables
	//   AFTER net pay is calculated at the end of this routine, the vacation pay will move from 
	//   vacation_paid to vacation_paid_to_union AND removed from net_pay
	FOR ll_ctu_row = 1 TO abo_pr_cheque_trade_union.of_RowCount()
		
		// lookup trade union settings FOR THIS TRADE UNION
		IF ibo_trade_union_rate_this_ts_or_tu.of_Retrieve("book = '" + gnv_app.is_book &
																+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
																+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN
																	
			IF as_release_vacation_pay = 'Y' &
			AND ibo_trade_union_rate_this_ts_or_tu.of_GetItemString(1, 'remit_vacation_pay_flag') = 'Y' THEN
				//we know that the vacation_paid is the same as the vacation_earn
				//because that's all we allow when vacation pay is remitted to the union
				//so use the vacation_earn field because it's stored on the 
				//multi-union child table, whereas vacation_paid is only on the cheque parent
				abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'vacation_paid_to_union', &
						abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row, 'vacation_earn'))
			END IF
			
			IF as_release_statutory_pay = 'Y' &
			AND ibo_trade_union_rate_this_ts_or_tu.of_GetItemString(1, 'remit_statutory_pay_flag') = 'Y' THEN
				//Likewise with statutory pay...
				abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'statutory_paid_to_union', &
						abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row, 'statutory_earn'))
			END IF
		END IF
	NEXT

	//---------------------
	// Union Remittance
	//---------------------
	
	//union remittances for the cheque
	IF of_tax_calc_union_remittance(	abo_pr_ck.of_GetItemNumber(1, 'employee'),		&
												abo_pr_ck.of_GetItemDateTime(1, 'issue_date'),	&
												ibo_trade_union_rate, 									&
												abo_pr_ck, &
												1, &
												abo_pr_ck.of_GetItemDecimal(1, 'reg_earn') 		&
											 + abo_pr_ck.of_GetItemDecimal(1, 'retro')			&
											 + abo_pr_ck.of_GetItemDecimal(1, 'pay_in_lieu_of_notice'), &
											 	ads_msg) = -1 THEN RETURN -1
	
	//union remittances for each trade union on the cheque
	FOR ll_ctu_row = 1 TO abo_pr_cheque_trade_union.of_RowCount()
		// lookup trade union settings FOR THIS TRADE UNION
		IF ibo_trade_union_rate_this_ts_or_tu.of_Retrieve("book = '" + gnv_app.is_book &
																	+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
																	+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN
			IF of_tax_calc_union_remittance(	abo_pr_ck.of_GetItemNumber(1, 'employee'),		&
														abo_pr_ck.of_GetItemDateTime(1, 'issue_date'),	&
														ibo_trade_union_rate_this_ts_or_tu, 				&
														abo_pr_cheque_trade_union, 							&
														ll_ctu_row, 												&
														abo_pr_ck.of_GetItemDecimal(1, 'reg_earn'), 		&
														ads_msg) = -1 THEN RETURN -1
													
			//If ANY union on this cheque remits vacation pay to the union, then
			//releasing vacation and/or stat pay only releases the currently earned 
			//vacation/stat, not banked hours.
			IF ibo_trade_union_rate_this_ts_or_tu.of_GetItemString(1, 'remit_vacation_pay_flag') = 'Y' THEN
				lb_a_union_remits_vacation_pay = TRUE
			END IF
			
			IF ibo_trade_union_rate_this_ts_or_tu.of_GetItemString(1, 'remit_statutory_pay_flag') = 'Y' THEN
				lb_a_union_remits_statutory_pay = TRUE
			END IF
		END IF
	NEXT
	
	//---------------------
	// Track monthly union remittances  *** These are always remitted to the employee's union, so no need to calculate them on other trade unions
	//---------------------
	
	//jira 623 - if the matching trade_union_rate to pr_cheque.trade_union has a non-zero employer_monthly_remit amount 
	//and the matching employee (new_employee).last_monthly_remit_month is less than pr_cheque.pr_yyyymm 
	//then pr_cheque.union_remittance should include trade_union_rate.employer_monthly_remit too. 
	//pr_cheque.last_monthly_remit_month should be set to pr_yyyymm otherwise it should be Null. 
	ldec_hours = abo_pr_ck.of_GetItemDecimal(1, 'reg_hour') & 
				+ abo_pr_ck.of_GetItemDecimal(1, 'tah_hour') &  
				+ abo_pr_ck.of_GetItemDecimal(1, 'ovr_hour') 
	IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours	+= abo_pr_ck.of_GetItemDecimal(1, 'travel_hour') //jira 1652
	
	IF ibo_trade_union_rate.of_GetItemDecimal(1, 'employer_monthly_remit') <> 0 															&
	AND ldec_hours > 0 &
	AND ((ibo_employee.of_GetItemString(1, "last_monthly_remit_month") < abo_pr_ck.of_GetItemString(1, 'pr_yyyymm')) 	&
			OR IsNull(ibo_employee.of_GetItemString(1, "last_monthly_remit_month"))) THEN
		abo_pr_ck.of_SetItem(1, 'add_to_union_remittance', abo_pr_ck.of_GetItemDecimal(1, 'add_to_union_remittance') + ibo_trade_union_rate.of_GetItemDecimal(1, 'employer_monthly_remit') )
		
		//If there are multiple trade unions, find the employee's union and apply monthly remittance to that trade union
		ll_find = abo_pr_cheque_trade_union.of_Find("trade_union = '" + ibo_trade_union_rate.of_GetItemString(1, 'trade_union') + "'")
		IF ll_find > 0 THEN
			abo_pr_cheque_trade_union.of_SetItem(ll_find, 'add_to_union_remittance', &
					abo_pr_cheque_trade_union.of_GetItemDecimal(ll_find, 'add_to_union_remittance') &
				 + ibo_trade_union_rate.of_GetItemDecimal(1, 'employer_monthly_remit') )
		END IF
		
		abo_pr_ck.of_SetItem(1, 'last_monthly_remit_month', abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') )
	ELSE
		abo_pr_ck.of_SetItem(1, 'last_monthly_remit_month', ls_null )
	END IF

	//---------------------
	// pension 
	//---------------------

	IF ibo_employee.of_GetItemString(1, 'pay_pension_to_cash_flag') = 'N' THEN
		//this calculates employee pension for the cheque and each trade union
		of_tax_calc_pension_employee(abo_pr_ck, &
											  ibo_trade_union_rate, &
											  abo_pr_cheque_trade_union, &
											  ibo_trade_union_rate_this_ts_or_tu, &
											  ldec_rrsp_premium_earn, &
											  ads_msg)
	END IF

	//calculate employer and union pension for the cheque and also
	//for multiple unions on the cheque
	of_tax_calc_pension_employer(abo_pr_ck, &
							  abo_pr_cheque_trade_union, &
							  abo_pr_cheque_occupation, &
							  ldec_rrsp_premium_earn, &
							  ads_msg, &
							  as_mode, &
							  ld_last_day_of_pp, &
							  lb_over_71)
						  
	//---------------------
	// RRSP 
	//---------------------

	//calculate employee's RRSP.  This doesn't remit to the union
	//so it's only stored on the cheque parent record
	IF as_mode = 'approve' AND Not(lb_over_71) THEN
		
		/* jira 3666 - no employee RRSP for those over 71 when application properties flag set */
		//user can override, so only recalculate when they run approvals
		of_tax_calc_rrsp_employee(abo_pr_ck, &
										  ibo_trade_union, &
										  ibo_trade_union_rate, &
										  ldec_rrsp_premium_earn, &
										  ads_msg)

		//Now add in the extra RRSP each employee is allowed to buy based on their trade level
		//and the setup of the trade union trade level employee rrsp tab
		ll_co_rows = abo_pr_cheque_occupation.of_RowCount()
		IF ll_co_rows = 0 THEN
			//Not setup for multi-unions, so just use the occupation on the last timesheet for this cheque
			IF ibo_timesheet.of_retrieve("book = '" + gnv_app.is_book &
											 		+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))) < 1 THEN
				of_msg_db_error("Error getting max occupation")
				RETURN -1
			ELSE
				ibo_timesheet.of_SetSort("occupation desc")
				ibo_timesheet.of_Sort()
				
				of_tax_calc_rrsp_employee_by_occupation(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), &
																	 abo_pr_ck.of_GetItemString(1, 'trade_union'), &
																	 ibo_timesheet.of_GetItemString(1, 'occupation'), &
																	 ld_last_day_of_pp, /* if not multi-union, then the calculation is based on the last day of pay period */&
																	 abo_pr_ck.of_GetItemDecimal(1, 'reg_hour') &
																		 + abo_pr_ck.of_GetItemDecimal(1, 'tah_hour') &
																		 + abo_pr_ck.of_GetItemDecimal(1, 'ovr_hour') &
																		 + abo_pr_ck.of_GetItemDecimal(1, 'travel_hour'), &
																	 ads_msg, &
																	 ldec_rrsp)
	
				IF ibo_trade_union_this_tu.of_GetItemString(1, 'staff_flag') = 'Y' THEN
					abo_pr_ck.of_SetItem(1, 'employee_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') + ldec_RRSP) 
				ELSE
					abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') + ldec_RRSP) 
				END IF	
			END IF
		ELSE
			
			//Calculate amount for each trade union/occupation on the cheque
			FOR ll_co_row = 1 to ll_co_rows
				of_tax_calc_rrsp_employee_by_occupation(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), &
																	 abo_pr_cheque_occupation.of_GetItemString(ll_co_row, 'trade_union'), &
																	 abo_pr_cheque_occupation.of_GetItemString(ll_co_row, 'occupation'), &
																	 Date(abo_pr_cheque_occupation.of_GetItemDateTime(ll_co_row, 'union_rate_effective_date')), /* for multi-union cheques, the calculation is based on the date work was done */ &
																	 abo_pr_cheque_occupation.of_GetItemDecimal(ll_co_row, 'reg_hour') &
																	 + abo_pr_cheque_occupation.of_GetItemDecimal(ll_co_row, 'tah_hour') &
																	 + abo_pr_cheque_occupation.of_GetItemDecimal(ll_co_row, 'ovr_hour') &
																	 + abo_pr_cheque_occupation.of_GetItemDecimal(ll_co_row, 'travel_hour'), &
																	 ads_msg, &
																	 ldec_rrsp)
	
				//Store amount on occupation child
				abo_pr_cheque_occupation.of_SetItem(ll_co_row, 'employee_rrsp', ldec_RRSP) 
				
//				IF ibo_trade_union_this_tu.of_Retrieve(&
//															  "book = '" + gnv_app.is_book &
//													+ "' AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ll_co_row, 'trade_union') + "'") = 1 THEN
//					IF ibo_trade_union_this_tu.of_GetItemString(1, 'staff_flag') = 'Y' THEN
//						abo_pr_ck.of_SetItem(1, 'employee_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') + ldec_RRSP) 
//					ELSE
//						abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') + ldec_RRSP) 
//					END IF	
//				END IF
				
			NEXT
		END IF
	END IF
	
	//calculate employer and union rrsp for the cheque and also
	//for multiple unions on the cheque
	IF of_tax_calc_rrsp_employer(abo_pr_ck, &
							  abo_pr_cheque_trade_union, &
							  abo_pr_cheque_occupation, &
							  ads_msg, &
							  ldec_rrsp_premium_earn, &
							  ld_last_day_of_pp, &
							  as_mode, &
							  lb_over_71) < 0 THEN RETURN -1

	//---------------------
	// Overtime premium finge amounts
	//		i.e. how much more it cost to work tah and over time 
	//         than if they were worked at regular rates
	//---------------------
	
	abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') &
													+ round(abo_pr_ck.of_GetItemDecimal(1, 'tah_hour') &
													* (ibo_trade_union_rate.of_GetItemDecimal(1, 'remit_tah_hr') &
													- ibo_trade_union_rate.of_GetItemDecimal(1, 'remit_Reg_hr')), 2) &
													+ round(abo_pr_ck.of_GetItemDecimal(1, 'tah_premium') &
													* ibo_trade_union_rate.of_GetItemDecimal(1, 'remit_tah_earn'), 2))
	
	abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') &
													+ round(abo_pr_ck.of_GetItemDecimal(1, 'ovr_hour') &
													* (ibo_trade_union_rate.of_GetItemDecimal(1, 'remit_ovr_hr') &
													- ibo_trade_union_rate.of_GetItemDecimal(1, 'remit_Reg_hr')), 2) &
													+ round(abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium') &
													* ibo_trade_union_rate.of_GetItemDecimal(1, 'remit_ovr_earn'), 2))
	
	//---------------------
	// union_dues calculation 
	//			- must follow remittance calculation because there may be dues charged on union remittances
	//---------------------
	
	IF as_mode = 'approve' THEN
	
		//union dues on parent cheque
		ldec_reg_earn = abo_pr_ck.of_GetItemDecimal(1,  'reg_earn') 														&
										+ abo_pr_ck.of_GetItemDecimal(1,  'retro')												&
										+ abo_pr_ck.of_GetItemDecimal(1,  'pay_in_lieu_of_notice')											
		IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_reg_earn += abo_pr_ck.of_GetItemDecimal(1,  'travel_earn') 
		of_tax_calc_union_dues(abo_pr_ck, &
									  ibo_trade_union_rate, &
									  1, &
									  ldec_dues_premium_earn, &
									  ldec_reg_earn)
										
		//and now run calculations for each trade union/occupation
		FOR ll_ctu_row = 1 TO abo_pr_cheque_trade_union.of_RowCount()
			// lookup trade union settings FOR THIS TRADE UNION
			IF ibo_trade_union_rate_this_ts_or_tu.of_Retrieve("book = '" + gnv_app.is_book &
																		+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
																		+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN
				
				ll_ts_rows = ibo_timesheet_this_tu.of_Retrieve("book = '" + gnv_app.is_book &
							+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) &
							+ "  AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') + "'")
				
				//also need to extract the dues premiums that apply to this trade union only
				ldec_dues_premium_earn_this_tu = 0
				
				FOR ll_ts_row = 1 TO ll_ts_rows
					
					//Read premiums for current timesheet	
					ibo_timesheet_premium.of_Retrieve("book = '" + gnv_app.is_book								&
									+ "' AND employee = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'employee')) 	&
									+ "  AND work_date = '" + String(ibo_timesheet_this_tu.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') &
									+ "' AND timesheet_item = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'timesheet_item')))
					
					//accumulate premiums for this timesheet
					of_tax_calc_dues_premiums_for_timesheets(ibo_timesheet_this_tu, ll_ts_row, &
																	ibo_timesheet_premium, 	&
																	ibo_trade_union_rate_this_ts_or_tu, 	&
																	ldec_dues_premium_earn_this_tu)
				NEXT

				//union dues on trade union child
				of_tax_calc_union_dues(abo_pr_cheque_trade_union, &
											  ibo_trade_union_rate_this_ts_or_tu, &
											  ll_ctu_row, &
											  ldec_dues_premium_earn_this_tu, &
											  abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row,  'reg_earn') &
											+ abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row,  'travel_earn'))
											  
				//jira 1447 - don't exceed the maximum field dues in a month.
				IF ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(1, 'max_monthly_dues') > 0 THEN
					IF this.of_get_union_dues_paid(gnv_app.is_book, 													&
																abo_pr_ck.of_GetItemNumber(1, 'employee'), 			&
																abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union'), 		&
																abo_pr_ck.of_GetItemDateTime(1, 'issue_date'), 	&
																ldec_union_dues_for_month) = -1 THEN
						ll_msg_row = ads_msg.InsertRow(0)
						ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
						ads_msg.SetItem(ll_msg_row, 'message', "Error calculating dues paid")
						RETURN -1
					END IF
					
					IF ldec_union_dues_for_month + abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_dues') &
					> ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(1, 'max_monthly_dues') THEN
						// Cap the dues taken on this cheque
						abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'union_dues', &
							Max(0, ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(1, 'max_monthly_dues') &
								- ldec_union_dues_for_month))
						lb_recalc_dues_on_parent_cheque = TRUE
					END IF
					
				END IF
		
			END IF
		NEXT
		
		//jira 2159 - check if the employee owes any back dues
		IF Not(IsNull(ibo_employee.of_GetItemDecimal(1, 'back_dues_owing'))) THEN
			abo_pr_ck.of_SetItem(1, 'back_dues', ibo_employee.of_GetItemDecimal(1, 'back_dues_owing'))
		END IF
		
	END IF
	
	//ensure the amounts on the cheques add up  ** EVEN IF IT IS VIA A CHANGE ACTION as opposed to an Approve **
	of_tax_calc_roll_up(abo_pr_ck, abo_pr_cheque_trade_union, abo_pr_cheque_occupation)
				
	//---------------------
	// Taxable vs Nontaxable amounts 
	//---------------------
	
	// recheck tax/notax loa
	IF ibo_employee.of_GetItemString(1, "loa_taxable_flag") = 'Y' THEN
		abo_pr_ck.of_SetItem(1, 'taxable_loa', abo_pr_ck.of_GetItemDecimal(1, 'taxable_loa') + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_loa'))
		abo_pr_ck.of_SetItem(1, 'nontaxable_loa', 0)
	ELSE
		abo_pr_ck.of_SetItem(1, 'taxable_loa', 0)
		abo_pr_ck.of_SetItem(1, 'nontaxable_loa', abo_pr_ck.of_GetItemDecimal(1, 'taxable_loa') + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_loa'))
	END IF	
	
	// recheck tax/notax mileage
	IF ibo_employee.of_GetItemString(1, "mileage_taxable_flag") = 'Y' THEN
		abo_pr_ck.of_SetItem(1, 'taxable_mileage', abo_pr_ck.of_GetItemDecimal(1, 'taxable_mileage') + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_mileage'))
		abo_pr_ck.of_SetItem(1, 'nontaxable_mileage', 0)
	ELSE
		abo_pr_ck.of_SetItem(1, 'taxable_mileage', 0)
		abo_pr_ck.of_SetItem(1, 'nontaxable_mileage', abo_pr_ck.of_GetItemDecimal(1, 'taxable_mileage') + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_mileage'))
	END IF	
	
	// recheck tax/notax site allowance
	IF ibo_employee.of_GetItemString(1, "site_allow_taxable_flag") = 'Y' THEN
		abo_pr_ck.of_SetItem(1, 'taxable_site_allow', abo_pr_ck.of_GetItemDecimal(1, 'taxable_site_allow') + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_site_allow'))
		abo_pr_ck.of_SetItem(1, 'nontaxable_site_allow', 0)
	ELSE
		abo_pr_ck.of_SetItem(1, 'taxable_site_allow', 0)
		abo_pr_ck.of_SetItem(1, 'nontaxable_site_allow', abo_pr_ck.of_GetItemDecimal(1, 'taxable_site_allow') + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_site_allow'))
	END IF	
	
	//---------------------
	// Fringe
	//---------------------

	abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') &
					 + round((ibo_employee.of_GetItemDecimal(1, "training_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "employer_rrsp_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "staff_safety_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "smtc_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "incentive_percent")) * .01 * abo_pr_ck.of_GetItemDecimal(1, 'tah_premium'), 2))
	
	abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') &
					 + round((ibo_employee.of_GetItemDecimal(1, "training_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "employer_rrsp_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "staff_safety_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "smtc_percent") &
					 + ibo_employee.of_GetItemDecimal(1, "incentive_percent")) * .01 * abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium'), 2))
	
	IF as_mode = 'approve' THEN
		abo_pr_ck.of_SetItem(1, 'monthly_dues',			0)
		abo_pr_ck.of_SetItem(1, 'retention_paid',			0)
		abo_pr_ck.of_SetItem(1, 'last_month_with_dues','')
		
		IF ibo_trade_union_rate.of_GetItemDecimal(1, 'admin_fee') <> 0 &
		AND ibo_employee.of_GetItemDecimal(1, "admin_fee") = 0 &
		AND ibo_employee.of_GetItemString(1, "admin_fee_flag") = 'Y' THEN
			abo_pr_ck.of_SetItem(1, 'admin_fee', ibo_trade_union_rate.of_GetItemDecimal(1, 'admin_fee'))
		ELSE
			abo_pr_ck.of_SetItem(1, 'admin_fee', 0)
		END IF
		
		IF ibo_trade_union_rate.of_GetItemDecimal(1, 'permit_fee') <> 0 &
		AND ibo_employee.of_GetItemDecimal(1, "admin_fee") = 0 &
		AND ibo_employee.of_GetItemString(1, "permit_fee_flag") = 'Y' THEN
			abo_pr_ck.of_SetItem(1, 'admin_fee', abo_pr_ck.of_GetItemDecimal(1, 'admin_fee') + ibo_trade_union_rate.of_GetItemDecimal(1, 'permit_fee'))
		END IF
	
		// training earned
		ldec_reg_earn = abo_pr_ck.of_GetItemDecimal(1, 'reg_earn') 														&
										+ abo_pr_ck.of_GetItemDecimal(1, 'tah_earn') 														&
										+ abo_pr_ck.of_GetItemDecimal(1, 'ovr_earn') 														&
										+ abo_pr_ck.of_GetItemDecimal(1, 'retro')
		IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_reg_earn += abo_pr_ck.of_GetItemDecimal(1, 'travel_earn') //jira 1652
		abo_pr_ck.of_SetItem(1, 'training', round(ibo_employee.of_GetItemDecimal(1, "training_percent") * .01 * ldec_reg_earn, 2))
	
		//Taxable Benefit can be by cheque
		abo_pr_ck.of_SetItem(1, 'taxable_benefit', ibo_employee.of_GetItemDecimal(1, "taxable_benefit_per_ck"))
		
		//Or, if it's set up on the employee's record that way, it can be taken once a month
		IF ibo_employee.of_GetItemDecimal(1, "taxable_benefit_per_month") <> 0 															&
		/*AND ldec_hours > 0*/ &
		AND ((ibo_employee.of_GetItemString(1, "last_taxable_benefit_month") < abo_pr_ck.of_GetItemString(1, 'pr_yyyymm')) 	&
				OR IsNull(ibo_employee.of_GetItemString(1, "last_taxable_benefit_month"))) THEN
			abo_pr_ck.of_SetItem(1, 'taxable_benefit', abo_pr_ck.of_GetItemDecimal(1, 'taxable_benefit') + ibo_employee.of_GetItemDecimal(1, "taxable_benefit_per_month"))
			abo_pr_ck.of_SetItem(1, 'last_taxable_benefit_month', abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') )
		ELSE
			abo_pr_ck.of_SetItem(1, 'last_taxable_benefit_month', ls_null )
		END IF
		
		//---------------------
		// Release amounts based on user's selection
		//---------------------

		// vacation pay (vacation earned is calculated earlier, not just for approvals)
		CHOOSE CASE as_release_vacation_pay
			CASE 'L'
				abo_pr_ck.of_SetItem(1, 'vacation_hours_paid', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_hours_lost', ibo_employee.of_GetItemDecimal(1, "vacation_hours_owed"))
				abo_pr_ck.of_SetItem(1, 'vacation_paid', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_lost', ibo_employee.of_GetItemDecimal(1, "vacation_owed"))
			CASE 'N'
				abo_pr_ck.of_SetItem(1, 'vacation_hours_paid', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_lost', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_hours_lost', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_paid', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_lost', 0)
			CASE 'Q'
				abo_pr_ck.of_SetItem(1, 'vacation_hours_paid', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_hours_lost', ibo_employee.of_GetItemDecimal(1, "vacation_hours_owed") + abo_pr_ck.of_GetItemDecimal(1, 'vacation_hours_earn'))
				abo_pr_ck.of_SetItem(1, 'vacation_paid', 0)
				abo_pr_ck.of_SetItem(1, 'vacation_lost', ibo_employee.of_GetItemDecimal(1, "vacation_owed") + abo_pr_ck.of_GetItemDecimal(1, 'vacation_earn'))
			CASE 'Y'
				IF lb_a_union_remits_vacation_pay THEN
					//Only remit to the union what was earned by the union
					abo_pr_ck.of_SetItem(1, 'vacation_hours_paid', abo_pr_ck.of_GetItemDecimal(1, 'vacation_hours_earn'))
					abo_pr_ck.of_SetItem(1, 'vacation_hours_lost', 0)
					abo_pr_ck.of_SetItem(1, 'vacation_paid', abo_pr_ck.of_GetItemDecimal(1, 'vacation_earn'))
					abo_pr_ck.of_SetItem(1, 'vacation_lost', 0)
				ELSE
					//pay the employee all their vacation
					abo_pr_ck.of_SetItem(1, 'vacation_hours_paid', abo_pr_ck.of_GetItemDecimal(1, 'vacation_hours_earn') + ibo_employee.of_GetItemDecimal(1, "vacation_hours_owed"))
					abo_pr_ck.of_SetItem(1, 'vacation_hours_lost', 0)
					abo_pr_ck.of_SetItem(1, 'vacation_paid', abo_pr_ck.of_GetItemDecimal(1, 'vacation_earn') + ibo_employee.of_GetItemDecimal(1, "vacation_owed"))
					abo_pr_ck.of_SetItem(1, 'vacation_lost', 0)
				END IF
		END CHOOSE
	
		// statutory pay (statuory earned is calculated earlier, not just for approvals)
		abo_pr_ck.of_SetItem(1, 'statutory_hours_paid', 0)
		CHOOSE CASE as_release_statutory_pay
			CASE 'L'
				abo_pr_ck.of_SetItem(1, 'statutory_paid', 0)
				abo_pr_ck.of_SetItem(1, 'statutory_lost', ibo_employee.of_GetItemDecimal(1, "statutory_owed"))
			CASE 'N'
				abo_pr_ck.of_SetItem(1, 'statutory_paid', 0)
				abo_pr_ck.of_SetItem(1, 'statutory_lost', 0)
			CASE 'Q'
				abo_pr_ck.of_SetItem(1, 'statutory_paid', 0)
				abo_pr_ck.of_SetItem(1, 'statutory_lost', ibo_employee.of_GetItemDecimal(1, "statutory_owed") + abo_pr_ck.of_GetItemDecimal(1, 'statutory_earn'))
			CASE 'Y'
				IF lb_a_union_remits_statutory_pay THEN
					//Only remit to the union what was earned by the union
					abo_pr_ck.of_SetItem(1, 'statutory_paid', abo_pr_ck.of_GetItemDecimal(1, 'statutory_earn'))
					abo_pr_ck.of_SetItem(1, 'statutory_lost', 0)
				ELSE
					//pay the employee all their stat
					abo_pr_ck.of_SetItem(1, 'statutory_paid', abo_pr_ck.of_GetItemDecimal(1, 'statutory_earn') + ibo_employee.of_GetItemDecimal(1, "statutory_owed"))
					abo_pr_ck.of_SetItem(1, 'statutory_lost', 0)
				END IF
		END CHOOSE
	
		//Personal Safety
		ldec_hours = abo_pr_ck.of_GetItemDecimal(1, 'reg_hour') & 
					+ abo_pr_ck.of_GetItemDecimal(1, 'tah_hour') &  
					+ abo_pr_ck.of_GetItemDecimal(1, 'ovr_hour') 
		IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours	+= abo_pr_ck.of_GetItemDecimal(1, 'travel_hour') //jira 1652
		
		abo_pr_ck.of_SetItem(1, 'personal_safety_earn', round(ibo_trade_union_rate.of_GetItemDecimal(1, 'personal_safety_rate') * ldec_hours, 2))         
		CHOOSE CASE as_release_personal_safety 
			CASE 'L'	/* lose accrued */
				abo_pr_ck.of_SetItem(1, 'personal_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'personal_safety_lost', ibo_employee.of_GetItemDecimal(1, "personal_safety_owed"))
			CASE 'N' /* don't release anything */
				abo_pr_ck.of_SetItem(1, 'personal_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'personal_safety_lost', 0)
			CASE 'Q' /* quit, lose accrued and current cheque amount */
				abo_pr_ck.of_SetItem(1, 'personal_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'personal_safety_lost', ibo_employee.of_GetItemDecimal(1, "personal_safety_owed") + abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_earn'))
			CASE 'Y' /* release 100% accrued */
				abo_pr_ck.of_SetItem(1, 'personal_safety_paid', Max(ibo_employee.of_GetItemDecimal(1, "personal_safety_owed"), 0))
				abo_pr_ck.of_SetItem(1, 'personal_safety_lost', 0)
		END CHOOSE
	
		//Group Safety
		abo_pr_ck.of_SetItem(1, 'group_safety_earn', round(ibo_trade_union_rate.of_GetItemDecimal(1, 'group_safety_rate') * ldec_hours, 2)) //jira 1652
		CHOOSE CASE as_release_group_safety 
			CASE 'L'	/* lose accrued */
				abo_pr_ck.of_SetItem(1, 'group_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'group_safety_lost', ibo_employee.of_GetItemDecimal(1, "group_safety_owed"))
			CASE 'N' /* don't release anything */
				abo_pr_ck.of_SetItem(1, 'group_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'group_safety_lost', 0)
			CASE 'Q' /* quit, lose accrued and current cheque amount */
				abo_pr_ck.of_SetItem(1, 'group_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'group_safety_lost', ibo_employee.of_GetItemDecimal(1, "group_safety_owed") + abo_pr_ck.of_GetItemDecimal(1, 'group_safety_earn'))
			CASE 'Y' /* release 100% accrued */
				abo_pr_ck.of_SetItem(1, 'group_safety_paid', Max(ibo_employee.of_GetItemDecimal(1, "group_safety_owed"), 0))
				abo_pr_ck.of_SetItem(1, 'group_safety_lost', 0)
		END CHOOSE
	
		//Production Bonus
		abo_pr_ck.of_SetItem(1, 'production_bonus_earn', round(ibo_trade_union_rate.of_GetItemDecimal(1, 'production_bonus_rate') * ldec_hours, 2)) //jira 1652
		CHOOSE CASE as_release_production_bonus 
			CASE 'L'
				abo_pr_ck.of_SetItem(1, 'production_bonus_paid', 0)
				abo_pr_ck.of_SetItem(1, 'production_bonus_lost', ibo_employee.of_GetItemDecimal(1, "production_bonus_owed"))
			CASE 'N'
				abo_pr_ck.of_SetItem(1, 'production_bonus_paid', 0)
				abo_pr_ck.of_SetItem(1, 'production_bonus_lost', 0)
			CASE 'Q'
				abo_pr_ck.of_SetItem(1, 'production_bonus_paid', 0)
				abo_pr_ck.of_SetItem(1, 'production_bonus_lost', ibo_employee.of_GetItemDecimal(1, "production_bonus_owed") + abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_earn'))
			CASE 'Y'
				abo_pr_ck.of_SetItem(1, 'production_bonus_paid', Max(ibo_employee.of_GetItemDecimal(1, "production_bonus_owed"), 0))
				abo_pr_ck.of_SetItem(1, 'production_bonus_lost', 0)
		END CHOOSE
	
		//Staff Safety
		ldec_reg_earn =  abo_pr_ck.of_GetItemDecimal(1, 'reg_earn') 		&  
						  + abo_pr_ck.of_GetItemDecimal(1, 'tah_earn') 		&  
						  + abo_pr_ck.of_GetItemDecimal(1, 'ovr_earn') 		&  
						  + abo_pr_ck.of_GetItemDecimal(1, 'retro')
		IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_reg_earn += abo_pr_ck.of_GetItemDecimal(1, 'travel_earn') 	// jira 1652
		
		abo_pr_ck.of_SetItem(1, 'staff_safety_earn', round(ibo_employee.of_GetItemDecimal(1, "staff_safety_percent") * .01 * ldec_reg_earn, 2))  
		CHOOSE CASE as_release_other_safety 
			CASE 'L'	/* lose accrued */
				abo_pr_ck.of_SetItem(1, 'staff_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'staff_safety_lost', ibo_employee.of_GetItemDecimal(1, "staff_safety_owed"))
			CASE 'N' /* don't release anything */
				abo_pr_ck.of_SetItem(1, 'staff_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'staff_safety_lost', 0)
			CASE 'Q' /* quit, lose accrued and current cheque amount */
				abo_pr_ck.of_SetItem(1, 'staff_safety_paid', 0)
				abo_pr_ck.of_SetItem(1, 'staff_safety_lost', ibo_employee.of_GetItemDecimal(1, "staff_safety_owed") + abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_earn'))
			CASE 'Y' /* release 100% accrued */
				abo_pr_ck.of_SetItem(1, 'staff_safety_paid', Max(ibo_employee.of_GetItemDecimal(1, "staff_safety_owed"), 0))
				abo_pr_ck.of_SetItem(1, 'staff_safety_lost', 0)
			CASE 'O' /* release 25% accrued (jira 3039) */
				abo_pr_ck.of_SetItem(1, 'staff_safety_paid', Max(Round(ibo_employee.of_GetItemDecimal(1, "staff_safety_owed") * 0.25, 2), 0))
				abo_pr_ck.of_SetItem(1, 'staff_safety_lost', 0)
			CASE 'H' /* release 50% accrued (jira 3039) */
				abo_pr_ck.of_SetItem(1, 'staff_safety_paid', Max(Round(ibo_employee.of_GetItemDecimal(1, "staff_safety_owed") * 0.50, 2), 0))
				abo_pr_ck.of_SetItem(1, 'staff_safety_lost', 0)
			CASE 'T' /* release 75% accrued (jira 3039) */
				abo_pr_ck.of_SetItem(1, 'staff_safety_paid', Max(Round(ibo_employee.of_GetItemDecimal(1, "staff_safety_owed") * 0.75, 2), 0))
				abo_pr_ck.of_SetItem(1, 'staff_safety_lost', 0)
		END CHOOSE
	
		//Small tools
		abo_pr_ck.of_SetItem(1, 'smtc_earn', round(ibo_employee.of_GetItemDecimal(1, "smtc_percent") * .01 * ldec_reg_earn, 2))  
		CHOOSE CASE as_release_small_tools 
			CASE 'L'
				abo_pr_ck.of_SetItem(1, 'smtc_paid', 0)
				abo_pr_ck.of_SetItem(1, 'smtc_lost', ibo_employee.of_GetItemDecimal(1, "smtc_owed"))
			CASE 'N'
				abo_pr_ck.of_SetItem(1, 'smtc_paid', 0)
				abo_pr_ck.of_SetItem(1, 'smtc_lost', 0)
			CASE 'Q'
				abo_pr_ck.of_SetItem(1, 'smtc_paid', 0)
				abo_pr_ck.of_SetItem(1, 'smtc_lost', ibo_employee.of_GetItemDecimal(1, "smtc_owed") + abo_pr_ck.of_GetItemDecimal(1, 'smtc_earn'))
			CASE 'Y'
				abo_pr_ck.of_SetItem(1, 'smtc_paid', Max(ibo_employee.of_GetItemDecimal(1, "smtc_owed"), 0))
				abo_pr_ck.of_SetItem(1, 'smtc_lost', 0)
		END CHOOSE
	
		//Incentive
		abo_pr_ck.of_SetItem(1, 'incentive_earn', round(ibo_employee.of_GetItemDecimal(1, "incentive_percent") * .01 * ldec_reg_earn, 2))  
		CHOOSE CASE as_release_incentive 
			CASE 'L'
				abo_pr_ck.of_SetItem(1, 'incentive_paid', 0)
				abo_pr_ck.of_SetItem(1, 'incentive_lost', ibo_employee.of_GetItemDecimal(1, "incentive_owed"))
			CASE 'N'
				abo_pr_ck.of_SetItem(1, 'incentive_paid', 0)
				abo_pr_ck.of_SetItem(1, 'incentive_lost', 0)
			CASE 'Q'
				abo_pr_ck.of_SetItem(1, 'incentive_paid', 0)
				abo_pr_ck.of_SetItem(1, 'incentive_lost', ibo_employee.of_GetItemDecimal(1, "incentive_owed") + abo_pr_ck.of_GetItemDecimal(1, 'incentive_earn'))
			CASE 'Y'
				abo_pr_ck.of_SetItem(1, 'incentive_paid', Max(ibo_employee.of_GetItemDecimal(1, "incentive_owed"), 0))
				abo_pr_ck.of_SetItem(1, 'incentive_lost', 0)
		END CHOOSE
	 
		//Retention
		CHOOSE CASE as_release_retention
			CASE 'A'
				// all accrued plus current released
				abo_pr_ck.of_SetItem(1, 'retention_paid', ibo_employee.of_GetItemDecimal(1, "retention_owed") + abo_pr_ck.of_GetItemDecimal(1, 'retention_earn'))
				abo_pr_ck.of_SetItem(1, 'retention_lost', 0)      
			CASE 'N'
				abo_pr_ck.of_SetItem(1, 'retention_paid', 0)      
				abo_pr_ck.of_SetItem(1, 'retention_lost', 0)      
			CASE 'Q'   
				// all lost
				abo_pr_ck.of_SetItem(1, 'retention_paid', 0)      
				abo_pr_ck.of_SetItem(1, 'retention_lost', ibo_employee.of_GetItemDecimal(1, "retention_owed") + abo_pr_ck.of_GetItemDecimal(1, 'retention_earn'))      
			CASE 'Y'
				// 30% of accrued retention
				abo_pr_ck.of_SetItem(1, 'retention_paid', round(ibo_employee.of_GetItemDecimal(1, "retention_owed") * .3, 2))
				abo_pr_ck.of_SetItem(1, 'retention_lost', 0)      
		END CHOOSE
		
		IF Abs(abo_pr_ck.of_GetItemDecimal(1, 'retention_paid')) > 99999.99 THEN
			ROLLBACK USING sqlca;
			MessageBox("Tax Calculation",'Retention paid is greater than $99,999.99')
			ll_msg_row = ads_msg.InsertRow(0)
			ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
			ads_msg.SetItem(ll_msg_row, 'message', "Error Retention paid is greater than $99,999.99")
			RETURN -1
		END IF
		
		//----------------------------
		// After amounts are released, decide if they should be paid into the employee's RRSP
		//----------------------------

		//jira 600 - add to incentive_paid_to_rrsp (which is labeled union_rrsp on the cheque screen)
		//for employees in non-staff unions
		IF lb_over_71 THEN
			//jira 3666 - no employee RRSP for those over 71 when ...flag set
		ELSE
			IF ibo_employee.of_GetItemDecimal(1, "employee_rrsp_per_ck") <> 0 THEN
				IF ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
					abo_pr_ck.of_SetItem(1, 'employee_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') + ibo_employee.of_GetItemDecimal(1, "employee_rrsp_per_ck") )
				ELSE
					//1136 Before moving money to incentive_paid_to_rrsp, make sure the union has a pension set up
					IF ibo_trade_union_rate.of_GetItemString(1, 'employee_pension_or_rrsp') = 'R' &
					OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'B' &
					OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'R' THEN
						abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') + ibo_employee.of_GetItemDecimal(1, "employee_rrsp_per_ck") )
					ELSE
						ll_msg_row = ads_msg.InsertRow(0)
						ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
						ads_msg.SetItem(ll_msg_row, 'message', "Employee: " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')) + ", cannot add " + String(ibo_employee.of_GetItemDecimal(1, "employee_rrsp_per_ck"), "$#,###.00") + " employee RRSP/cheque to RRSP, union " + abo_pr_ck.of_GetItemString(1, 'trade_union') + " isn't setup for RRSP.")
					END IF
				END IF	
			END IF
		
			IF Trim(ibo_employee.of_GetItemString(1, "rrsp_vendor")) <> '' &
			AND ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' &
			AND ibo_employee.of_GetItemString(1, "safety_to_rrsp_flag") = 'Y' THEN
				abo_pr_ck.of_SetItem(1, 'employee_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') &
																+ abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_paid') 		&	
																+ abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_paid') 	&	
																+ abo_pr_ck.of_GetItemDecimal(1, 'group_safety_paid'))			
			END IF   
			
			IF Trim(ibo_employee.of_GetItemString(1, "rrsp_vendor")) <> '' &
			AND ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' &
			AND ibo_employee.of_GetItemString(1, "other_incentive_to_rrsp_flag") = 'Y' THEN
				abo_pr_ck.of_SetItem(1, 'employee_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') &
																+ abo_pr_ck.of_GetItemDecimal(1, 'retention_paid') 	&	
																+ abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_paid') 	&	
																+ abo_pr_ck.of_GetItemDecimal(1, 'smtc_paid') 		&	
																+ abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid'))		
			END IF
		
		END IF
		
		//----------------------------
		// Monthly dues
		//----------------------------
	
		//Convert last month of dues to date
		IF IsNull(ibo_employee.of_GetItemString(1, "last_month_of_dues")) THEN
			ldt_last_month_of_dues = DateTime(Date(1900,01,01))
		ELSE
			ldt_last_month_of_dues = DateTime(gnv_app.inv_datetime.of_LastDayOfMonth(Date( Integer(String(Left(ibo_employee.of_GetItemString(1, "last_month_of_dues"), 4))), Integer(String(Right(ibo_employee.of_GetItemString(1, "last_month_of_dues"), 2))), 1)))
		END IF
	
		//Jira 2223 - change calculation of monthly dues to use the year-month of the cheque issue date
		IF ibo_employee.of_GetItemDecimal(1, "dues_per_month") <> 0 THEN
			IF String(abo_pr_ck.of_GetItemDateTime(1, 'issue_date'), 'YYYYMM') > String(ldt_last_month_of_dues, 'YYYYMM') THEN
				abo_pr_ck.of_SetItem(1, 'monthly_dues', abo_pr_ck.of_GetItemDecimal(1, 'monthly_dues') + ibo_employee.of_GetItemDecimal(1, "dues_per_month"))
				abo_pr_ck.of_SetItem(1, 'last_month_with_dues', String(abo_pr_ck.of_GetItemDateTime(1, 'issue_date'), 'YYYYMM'))
			END IF
		END IF
			
		//----------------------------
		// Daily dues
		// Charge the daily dues for each day worked, but not more than the maximum
		//----------------------------
	
		IF ibo_employee.of_GetItemString(1, "daily_dues_flag") = 'Y' &
		AND ibo_trade_union_rate.of_GetItemDecimal(1, 'daily_due') <> 0 &
		AND (IsNull(ibo_employee.of_GetItemDateTime(1, "last_daily_dues_date")) &
				OR abo_pr_ck.of_GetItemDateTime(1, 'pay_period_start_date') > ibo_employee.of_GetItemDateTime(1, "last_daily_dues_date")) THEN
			
			ls_find = "book = '" + gnv_app.is_book 																&
														+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) 	&
														+ "  AND work_date >= '" + String(abo_pr_ck.of_GetItemDateTime(1, 'pay_period_start_date'), 'yyyy.mm.dd')  &
														+ "' AND work_date <= '" + String(ld_last_day_of_pp, 'yyyy.mm.dd') + "'"
			ll_ts_rows = ibo_timesheet.of_Retrieve(ls_find)
			IF ll_ts_rows < 0 THEN
				this.of_prcent_err("Error reading timesheets for daily dues", abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), ads_msg)
				RETURN -1
			END IF
			 
			ibo_timesheet.of_SetSort("work_date ASC")
			ibo_timesheet.of_Sort()
			
			//Initialize
			ldec_daily_due = 0
			abo_pr_ck.of_SetItem(1, 'last_daily_dues_date',  ldt_null)
			ldt_work_last = DateTime(Date(1900,1,1), Time(0,0,0))
	
			IF ibo_pay_period.of_get_last_day_of_pay_period(ibo_trade_union.of_GetItemString(1, 'pay_period_type'), Date(abo_pr_ck.of_GetItemDateTime(1, 'pay_period_start_date')), ld_last_day_of_pp) < 1 THEN
				RETURN -1
			END IF
					
			FOR ll_ts_row = 1 TO ll_ts_rows
				
				//Does this represent a working day?
				ldec_hours = Abs(ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'reg_hour')) &
							  + Abs(ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'tah_hour')) &
							  + Abs(ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'ovr_hour')) 
				IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN 
					ldec_hours += Abs(ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'travel_hour')) 
				END IF
				
				IF ldec_hours > 0 THEN
					ldt_work = ibo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date')
					IF ldt_work <> ldt_work_last THEN
	
						//Increment dues for each distinct date
						ldec_daily_due += ibo_trade_union_rate.of_GetItemDecimal(1, 'daily_due')
						
						//Increment the date.  Employee record will be updated when cheques are issued
						abo_pr_ck.of_SetItem(1, 'last_daily_dues_date',  ld_last_day_of_pp)
						ldt_work_last = ldt_work
						
					END IF
				END IF
			NEXT
			abo_pr_ck.of_SetItem(1, 'daily_dues',  Min(ldec_daily_due, ibo_trade_union_rate.of_GetItemDecimal(1, 'max_daily_due')))
		END IF
		
		//----------------------------
		// Weekly dues
		// Charge the weekly dues once per pay period
		//----------------------------
	
		IF ibo_employee.of_GetItemString(1, "weekly_dues_flag") = 'Y' &
		AND ibo_trade_union_rate.of_GetItemDecimal(1, 'weekly_dues') <> 0 &
		AND (IsNull(ibo_employee.of_GetItemDateTime(1, "last_weekly_dues_paid_date")) &
				OR abo_pr_ck.of_GetItemDateTime(1, 'pay_period_start_date') > ibo_employee.of_GetItemDateTime(1, "last_weekly_dues_paid_date")) THEN
		
			ls_find = "book = '" + gnv_app.is_book 																&
														+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) 	&
														+ "  AND reg_hour + tah_hour + ovr_hour > 0 " 	&
														+ "  AND work_date >= '" + String(abo_pr_ck.of_GetItemDateTime(1, 'pay_period_start_date'), 'yyyy.mm.dd')  &
														+ "' AND work_date <= '" + String(ld_last_day_of_pp, 'yyyy.mm.dd') + "'"
			ll_ts_rows = ibo_timesheet.of_Retrieve(ls_find)
	
			IF ll_ts_rows < 0 THEN
				this.of_prcent_err("Error reading timesheets for weekly dues", 0, ads_msg)
				RETURN -1
			ELSEIF ll_ts_rows > 0 THEN
				abo_pr_ck.of_SetItem(1, 'weekly_dues',  ibo_trade_union_rate.of_GetItemDecimal(1, 'weekly_dues'))
				abo_pr_ck.of_SetItem(1, 'last_weekly_dues_paid_date',  ld_last_day_of_pp)
			ELSE
				abo_pr_ck.of_SetItem(1, 'weekly_dues',  0)
				abo_pr_ck.of_SetItem(1, 'last_weekly_dues_paid_date',  ldt_null)
			END IF
		END IF
		
	END IF
	
	//----------------------------
	// Recalculate amounts owing
	//----------------------------
	
	IF lb_a_union_remits_vacation_pay &
	AND as_release_vacation_pay = 'Y' THEN
	ELSE
		abo_pr_ck.of_SetItem(1, 'vacation_owed', 										&
							abo_pr_ck.of_GetItemDecimal(1, 'vacation_earn') 			&
						 - abo_pr_ck.of_GetItemDecimal(1, 'vacation_paid') 			&
						 - abo_pr_ck.of_GetItemDecimal(1, 'vacation_lost'))
		abo_pr_ck.of_SetItem(1, 'vacation_hours_owed', 								&
							abo_pr_ck.of_GetItemDecimal(1, 'vacation_hours_earn') 	&
						 - abo_pr_ck.of_GetItemDecimal(1, 'vacation_hours_paid') 	&
						 - abo_pr_ck.of_GetItemDecimal(1, 'vacation_hours_lost'))
	END IF
	
		
	IF lb_a_union_remits_statutory_pay &
	AND as_release_statutory_pay = 'Y' THEN
	ELSE
		abo_pr_ck.of_SetItem(1, 'statutory_owed', 										&
							abo_pr_ck.of_GetItemDecimal(1, 'statutory_earn') 			&
						 - abo_pr_ck.of_GetItemDecimal(1, 'statutory_paid') 			&
						 - abo_pr_ck.of_GetItemDecimal(1, 'statutory_lost'))
	END IF
					
	abo_pr_ck.of_SetItem(1, 'personal_safety_owed', 								&
					  abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_earn') 	&
					- abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_paid') 	&
					- abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_lost') )
																	
	abo_pr_ck.of_SetItem(1, 'group_safety_owed', 									&
					  abo_pr_ck.of_GetItemDecimal(1, 'group_safety_earn') 		&
					- abo_pr_ck.of_GetItemDecimal(1, 'group_safety_paid') 		&
					- abo_pr_ck.of_GetItemDecimal(1, 'group_safety_lost'))
																	
	abo_pr_ck.of_SetItem(1, 'production_bonus_owed', 								&
					  abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_earn') 	&
					- abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_paid') 	&
					- abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_lost'))
																	
	abo_pr_ck.of_SetItem(1, 'staff_safety_owed', 								&
					  abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_earn') 	&
					- abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_paid') 	&
					- abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_lost'))                                      
	
	abo_pr_ck.of_SetItem(1, 'smtc_owed', 											&
					  abo_pr_ck.of_GetItemDecimal(1, 'smtc_earn') 				&
					- abo_pr_ck.of_GetItemDecimal(1, 'smtc_paid') 				&
					- abo_pr_ck.of_GetItemDecimal(1, 'smtc_lost'))
																	
	abo_pr_ck.of_SetItem(1, 'retention_owed', 									&
					  abo_pr_ck.of_GetItemDecimal(1, 'retention_earn') 		&
					- abo_pr_ck.of_GetItemDecimal(1, 'retention_paid') 		&
					- abo_pr_ck.of_GetItemDecimal(1, 'retention_lost'))
																	
	abo_pr_ck.of_SetItem(1, 'incentive_owed', 									&
					  abo_pr_ck.of_GetItemDecimal(1, 'incentive_earn') 		&
					- abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid') 		&
					- abo_pr_ck.of_GetItemDecimal(1, 'incentive_lost'))
	
																  
	//Jira 3189 - adjust vacation owed so that accruals are at current rates
	//When trade_union.vacation_owed_at_current_rate_flag is Y, please calculate the vacation earned to be 
	//   (employee vacation hours owed plus the cheque vacation hours owed) times the most recent cheque’s timesheet’s regular rate 
	//       minus the employee vacation owed
	//  In the case of a rate increase this will create a lump sum that, when the cheques are issued, will be propagated to the employee vacation amounts.
	//  The increase to employee vacation earnings will cover any vacation payouts at the higher rate.
	IF ibo_trade_union.of_GetItemString(1, 'vacation_owed_at_current_rate_flag') = 'Y' AND ldec_latest_timesheet_reg_rate <> 0 THEN	
		IF as_release_vacation_pay = 'N' OR as_release_vacation_pay = 'Y' THEN	
			//apply current rate to accumulated vacation hours
			abo_pr_ck.of_SetItem(1, 'vacation_earn', &
				Round(((ibo_employee.of_GetItemDecimal(1, "vacation_hours_owed") + abo_pr_ck.of_GetItemDecimal(1, 'vacation_hours_earn')) * ldec_latest_timesheet_reg_rate), 4) &
						- ibo_employee.of_GetItemDecimal(1, "vacation_owed"))
		END IF
	END IF
	
																  
	IF lb_over_71 THEN
		//jira 3666 - no incentive to RRSP when employee over 71 and RRSP to cash flag is 'Y'
	ELSE
		// safety & other incentives paid into union RRSP  
		IF as_mode = 'approve' AND ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'N' THEN
			IF ibo_employee.of_GetItemString(1, "safety_to_rrsp_flag") = 'Y' 										&
			AND abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_paid') 			&
			  + abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_paid') 		&
			  + abo_pr_ck.of_GetItemDecimal(1, 'group_safety_paid') <> 0 THEN
				
				//jira 1136 - Before moving money to incentive_paid_to_rrsp, make sure the union is setup for RRSP's
				IF ibo_trade_union_rate.of_GetItemString(1, 'employee_pension_or_rrsp') = 'R' &
				OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'B' &
				OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'R' THEN
					abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp',  abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') 			&
																								+ abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_paid') 			&
																								+ abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_paid') 		&
																								+ abo_pr_ck.of_GetItemDecimal(1, 'group_safety_paid'))
				ELSE
					ll_msg_row = ads_msg.InsertRow(0)
					ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
					ads_msg.SetItem(ll_msg_row, 'message', "Employee: " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')) + ", cannot release safety to RRSP, union " + abo_pr_ck.of_GetItemString(1, 'trade_union') + " isn't setup for RRSP.")
				END IF
			END IF
			
			IF ibo_employee.of_GetItemString(1, "other_incentive_to_rrsp_flag") = 'Y' &
			AND abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_paid') 	&
			  + abo_pr_ck.of_GetItemDecimal(1, 'retention_paid') 			&
			  + abo_pr_ck.of_GetItemDecimal(1, 'smtc_paid') 					&
			  + abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid') <> 0 THEN
			  
				//jira 1136 - Before moving money to incentive_paid_to_rrsp, make sure the union is setup for RRSP's
				IF ibo_trade_union_rate.of_GetItemString(1, 'employee_pension_or_rrsp') = 'R' &
				OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'B' &
				OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'R' THEN
					abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp',  abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') 	&
																							+ abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_paid') 	&
																							+ abo_pr_ck.of_GetItemDecimal(1, 'retention_paid') 			&
																							+ abo_pr_ck.of_GetItemDecimal(1, 'smtc_paid') 					&
																							+ abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid'))
				ELSE
					ll_msg_row = ads_msg.InsertRow(0)
					ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
					ads_msg.SetItem(ll_msg_row, 'message', "Employee: " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')) + ", cannot release other incentive to RRSP, union " + abo_pr_ck.of_GetItemString(1, 'trade_union') + " isn't setup for RRSP.")
				END IF
			END IF
		END IF
	END IF           
END IF //recalc is just the tax table calculations

//---------------------
// Taxable Earnings
//---------------------



abo_pr_ck.of_SetItem(1, 'taxable_earn', abo_pr_ck.of_GetItemDecimal(1, 'reg_earn') 					& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'tah_earn') 					& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'ovr_earn') 					& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'travel_earn') 				& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'taxable_loa') 				& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'taxable_mileage') 		& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'other_taxable_pay') 		& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'vehicle_allowance_paid')& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'retro')						& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'pay_in_lieu_of_notice') & 
														 + abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_paid') 	& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'group_safety_paid') 		& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_paid') & 
														 + abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_paid') 		& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'smtc_paid') 				& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'retention_paid') 			& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid') 			& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp') 				& 
														 + abo_pr_ck.of_GetItemDecimal(1, 'employer_rrsp') 			&
														 + abo_pr_ck.of_GetItemDecimal(1, 'taxable_site_allow') 	&	     
														 + abo_pr_ck.of_GetItemDecimal(1, 'taxable_benefit')  		&     
														 + abo_pr_ck.of_GetItemDecimal(1, 'taxable_benefit_gas')  	&     
														 + abo_pr_ck.of_GetItemDecimal(1, 'taxable_benefit_vehicle') &
														 + abo_pr_ck.of_GetItemDecimal(1, 'vacation_paid') 			&
														 + abo_pr_ck.of_GetItemDecimal(1, 'statutory_paid')			&
														 + abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp_paid_out')	/* jira 3666 - Both of the new fields are considered taxable earnings */&
														 + abo_pr_ck.of_GetItemDecimal(1, 'employer_rrsp_paid_out')&
														 + abo_pr_ck.of_GetItemDecimal(1, 'paid_sick_leave'))
														 
//---------------------
// Calculate federal and provincial tax owing
//---------------------

//Calculate the CPP Contribution
abo_pr_ck.of_SetItem(1, 'cpp_contribution', 0)
abo_pr_ck.of_SetItem(1, 'cpp_earn', 0)
abo_pr_ck.of_SetItem(1, 'cpp2_contribution', 0)
abo_pr_ck.of_SetItem(1, 'cpp2_earn', 0)

//Get annual maximum for Quebec or ROC
IF ibo_employee.of_GetItemString(1, 'tax_province') = 'QC' THEN
	ldec_cpp_annual_maximum = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_annual_maximum')
	ldec_cpp_multiplier = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_multiplier')
	ldec_cpp_annual_allowance = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_annual_allowance')
	ldec_cpp_first_rate = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_first_rate')
	ldec_cpp_base_rate = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_base_rate')
	ldec_cpp_base_maximum = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_base_maximum')
	ldec_ei_annual_max_premium = ibo_federal_tax.of_GetItemDecimal(1, 'qei_annual_max_premium')
	ldec_ei_annual_max_earning = ibo_federal_tax.of_GetItemDecimal(1, 'qei_annual_max_earning')
	ldec_ei_employer_multiplier = ibo_federal_tax.of_GetItemDecimal(1, 'qei_employer_multiplier')
	ldec_ei_employee_rate = ibo_federal_tax.of_GetItemDecimal(1, 'qei_employee_rate')
	ldec_cpp_second_rate = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_second_rate')
	ldec_cpp_second_max_earning = ibo_federal_tax.of_GetItemDecimal(1, 'qpp_second_maximum')
ELSE
	ldec_cpp_annual_maximum = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_annual_maximum')
	ldec_cpp_multiplier = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_multiplier')
	ldec_cpp_annual_allowance = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_annual_allowance')
	ldec_cpp_first_rate = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_first_rate')
	ldec_cpp_base_rate = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_base_rate')
	ldec_cpp_base_maximum = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_base_maximum')
	ldec_ei_annual_max_premium = ibo_federal_tax.of_GetItemDecimal(1, 'ei_annual_max_premium')
	ldec_ei_annual_max_earning = ibo_federal_tax.of_GetItemDecimal(1, 'ei_annual_max_earning')
	ldec_ei_employer_multiplier = ibo_federal_tax.of_GetItemDecimal(1, 'ei_employer_multiplier')
	ldec_ei_employee_rate = ibo_federal_tax.of_GetItemDecimal(1, 'ei_employee_rate')
	ldec_cpp_second_rate = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_second_rate')
	ldec_cpp_second_max_earning = ibo_federal_tax.of_GetItemDecimal(1, 'cpp_second_maximum')
END IF
	
//Jira 3183 - change cheque approval to test employee.cpp_exempt_effective_date
IF ibo_employee.of_GetItemString(1, "cpp_exempt_flag") = 'Y' THEN
	lb_cpp_exempt = TRUE
ELSEIF IsNull(ibo_employee.of_GetItemDateTime(1, 'cpp_exempt_effective_date')) THEN
	lb_cpp_exempt = FALSE
ELSEIF ibo_employee.of_GetItemDateTime(1, 'cpp_exempt_effective_date') < abo_pr_ck.of_GetItemDateTime(1, 'issue_date') THEN
	lb_cpp_exempt = TRUE
ELSE
	lb_cpp_exempt = FALSE
END IF

IF ibo_employee.of_GetItemString(1, "employment_type") = 'Y' AND Not(lb_cpp_exempt) THEN

	IF ldec_cpp_annual_maximum = 0 THEN
		this.of_prcent_err("Federal Tax entries are missing or incorrectly set up.", 0, ads_msg)
		RETURN -1
	END IF
	
	//Pro-rated based on age
	li_age = Year(Date(abo_pr_ck.of_GetItemDateTime(1, 'issue_date'))) - Year(Date(ldt_birth_date))
	CHOOSE CASE li_age
		CASE 19 TO 69
			ldec_cpp_max_contributions_based_on_age = ldec_cpp_annual_maximum
			li_cpp_months = 12
		CASE 18
			IF Month(Date(abo_pr_ck.of_GetItemDateTime(1, 'issue_date'))) > Month(Date(ldt_birth_date)) THEN
				ldec_cpp_max_contributions_based_on_age = Round((12 - Month(Date(ldt_birth_date)))/12 * ldec_cpp_annual_maximum, 2)
			END IF
			li_cpp_months = 12 - Month(Date(ldt_birth_date))
		CASE 70
			IF Month(Date(abo_pr_ck.of_GetItemDateTime(1, 'issue_date'))) <= Month(Date(ldt_birth_date)) THEN
				ldec_cpp_max_contributions_based_on_age = Round(Month(Date(ldt_birth_date))/12 * ldec_cpp_annual_maximum, 2)
			END IF
			li_cpp_months = Month(Date(ldt_birth_date))
		CASE ELSE
			ldec_cpp_max_contributions_based_on_age = 0
			li_cpp_months = 0
	END CHOOSE

   //CPP Contribution

	ldec_cpp_contribution = 0
	ldec_cpp_earn         = 0
	ldec_cpp2_contribution = 0
	ldec_cpp2_earn         = 0
   ldec_cpp_annual_remaining_contribution = ldec_cpp_max_contributions_based_on_age - ldec_ytd_cpp_contribution
	ldec_cpp_first_max_earning = ldec_cpp_max_contributions_based_on_age / ldec_cpp_multiplier &
								+ ldec_cpp_annual_allowance
	ldec_cpp_pp_exemption = Truncate(ldec_cpp_annual_allowance/ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year'), 2)
	
	//2012.11.22
	IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') >= 0 THEN
		
		//Allocate the annual allowance over each pay period.
		ldec_cpp_contribution = Round(ldec_cpp_multiplier * (abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') - ldec_cpp_pp_exemption), 2)
		
		//Ensure we don't exceed maximum earnings
		ldec_cpp_earn = min(max(ldec_cpp_first_max_earning - ldec_ytd_cpp_earn - ldec_ytd_cpp2_earn, 0 ), abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn'))

		IF ldec_cpp_earn = 0 THEN 
			ldec_cpp_contribution = 0
		ELSE
			ldec_cpp_contribution = min(ldec_cpp_annual_remaining_contribution, ldec_cpp_contribution)
		END IF
		
		//2013.01.03 - Prevent negative cpp contribution with positive earnings
		IF ldec_cpp_earn >= 0 AND ldec_cpp_contribution < 0 THEN
			ldec_cpp_contribution = 0
		END IF
		
		//2023.12.06 - Now look at the newly introduced (2024) second additional CPP amounts
		
		//Determine if your employee exceeded the first maximum annual pensionable earnings ceiling
		ldec_cpp_ytd_with_this_cheque = ldec_ytd_cpp_earn + ldec_ytd_cpp2_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
		IF ldec_cpp_ytd_with_this_cheque > ldec_cpp_first_max_earning 		/* does this new amount take us over the first max? */&
		AND ldec_ytd_cpp_earn + ldec_ytd_cpp2_earn < ldec_cpp_second_max_earning THEN				/* and were we previously still under the second max? */
			
			//Determine what portion of the earnings are eligible
			IF ldec_ytd_cpp_earn + ldec_ytd_cpp2_earn <= ldec_cpp_first_max_earning &
			AND ldec_cpp_ytd_with_this_cheque >= ldec_cpp_second_max_earning THEN
				//starts below and also tips over the maximum
				ldec_earnings_over_first_cpp_maximum = ldec_cpp_second_max_earning - ldec_cpp_first_max_earning
			ELSEIF ldec_cpp_ytd_with_this_cheque > ldec_cpp_second_max_earning THEN
				//starts within and tips over the second maximum
				ldec_earnings_over_first_cpp_maximum = abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') - (ldec_cpp_ytd_with_this_cheque - ldec_cpp_second_max_earning)
			ELSEIF ldec_ytd_cpp_earn + ldec_ytd_cpp2_earn <= ldec_cpp_first_max_earning THEN
				//only a portion is into the second range
				ldec_earnings_over_first_cpp_maximum = ldec_cpp_ytd_with_this_cheque - ldec_cpp_first_max_earning
			ELSE
				//all earnings are within the second range
				ldec_earnings_over_first_cpp_maximum = abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
			END IF
						
			//Apply second rate (C2 = lesser of option i and option ii)
			//option (ii): rate * eligible earnings
			ldec_cpp2_contribution = Round(ldec_cpp_second_rate * ldec_earnings_over_first_cpp_maximum, 2)
			
			//option (i): annual max * (PM/12) - D2
			ldec_cpp2_annual_maximum   = (ldec_cpp_second_max_earning - ldec_cpp_first_max_earning) * ldec_cpp_second_rate
			ldec_cpp2_annual_remaining = Round(ldec_cpp2_annual_maximum * (li_cpp_months / 12) - ldec_ytd_cpp2_contribution, 2)
			
			//C2 = lesser of the two options, minimum $0
			ldec_cpp2_contribution = Max(0, Min(ldec_cpp2_annual_remaining, ldec_cpp2_contribution))
			
			//Track second tier earnings separately from first tier
			ldec_cpp2_earn = ldec_earnings_over_first_cpp_maximum
			
		END IF	
		
	ELSEIF ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') < ldec_cpp_first_max_earning THEN
		 
		
		// cheque is reducing the CPP earnings so a credit contribution will be issued based on the pro-rated allowance
		//count distinct of pay period start dates where pr_yyyymm >=  year + ‘01’ and tax_earn > 0 
		ls_pryyyymm = Left(ibo_company.of_GetItemString(1, 'pr_yyyymm'), 4) + '01'
		ll_employee = abo_pr_ck.of_GetItemNumber(1, 'employee')
		SELECT count(*)
		  INTO :ll_count_pp
		  FROM (SELECT DISTINCT pay_period_start_date 
		          FROM pr_cheque
					WHERE employee = :ll_employee
					  AND pr_yyyymm >= :ls_pryyyymm
					  AND taxable_earn > 0) pp
		 USING sqlca;
		IF sqlca.sqlcode <> 0 THEN
			this.of_prcent_err("Error counting pay periods", 0, ads_msg)
			RETURN -1
		END IF
		
		ldec_cpp_prorated_allowance = round(ldec_cpp_annual_allowance * ll_count_pp / ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year')  &
												* ((ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')) &
												/ ldec_cpp_first_max_earning ),2)
												
		ldec_cpp_contribution = round(ldec_cpp_multiplier &
				* (abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') + min(ldec_cpp_first_max_earning, ldec_ytd_taxable_earn) - ldec_cpp_prorated_allowance), 2)  &
				- ldec_ytd_cpp_contribution
			
	   ldec_cpp_earn = ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') - min(ldec_cpp_first_max_earning, ldec_ytd_taxable_earn)
	
		IF ldec_cpp_earn = 0 THEN 
			ldec_cpp_contribution = 0
		END IF
			
	END IF
	
	abo_pr_ck.of_SetItem(1, 'cpp_contribution', ldec_cpp_contribution)
   abo_pr_ck.of_SetItem(1, 'cpp_earn', ldec_cpp_earn )
	abo_pr_ck.of_SetItem(1, 'cpp2_contribution', ldec_cpp2_contribution)
   abo_pr_ck.of_SetItem(1, 'cpp2_earn', ldec_cpp2_earn )
	
   IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') <> 0 THEN
		ldec_cpp_portion_of_fringe = (abo_pr_ck.of_GetItemDecimal(1, 'cpp_contribution') &
                                + abo_pr_ck.of_GetItemDecimal(1, 'cpp2_contribution')) &
                                / abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
		
		abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') &
															+ round(abo_pr_ck.of_GetItemDecimal(1, 'tah_premium') * ldec_cpp_portion_of_fringe , 2))
															
		abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') &
															+ round(abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium') * ldec_cpp_portion_of_fringe , 2))
		// shift premium portion of CPP 
		abo_pr_ck.of_SetItem(1, 'shift_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'shift_premium_fringe') &
															+ round(abo_pr_ck.of_GetItemDecimal(1, 'shift_premium') * ldec_cpp_portion_of_fringe, 2))  
   END IF

END IF

//Calculate the EI premium
abo_pr_ck.of_SetItem(1, 'ei_premium', 0)
abo_pr_ck.of_SetItem(1, 'ei_earn', 0)

if ibo_employee.of_GetItemString(1, "ei_exempt_flag") = 'N' and ibo_employee.of_GetItemString(1, "employment_type") = 'Y' THEN
	abo_pr_ck.of_SetItem(1, 'ei_earn', 	 abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn'))
	
	//2012.11.22
	IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') >= 0 THEN  
		
		//How much EI is still to be paid to reach federal maximum?
		ldec_ei_outstanding = ldec_ei_annual_max_premium - ldec_ytd_ei_premium   
		
		//This calculation varies from the document.  I think we did it to catch people up if they were at a lower contribution
		ldec_ei_current = round(ldec_ei_employee_rate &
											* (ldec_ytd_ei_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')), 2) &
											- ldec_ytd_ei_premium
	
		abo_pr_ck.of_SetItem(1, 'ei_premium', min(ldec_ei_outstanding, ldec_ei_current))
		
	
	ELSEIF ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') < ldec_ei_annual_max_earning THEN
		
		// cheque is reducing the EI earnings so a credit premium will be issued
		ldec_ei_current = round(ldec_ei_employee_rate &
									* (ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') &
									- Min(ldec_ei_annual_max_earning, ldec_ytd_taxable_earn)), 2) 
							
		abo_pr_ck.of_SetItem(1, 'ei_premium', ldec_ei_current)
   END IF
	
	IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') <> 0 THEN
		ldec_ei_portion_of_fringe = abo_pr_ck.of_GetItemDecimal(1, 'ei_premium') / abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
		abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') &
						+ round(abo_pr_ck.of_GetItemDecimal(1, 'tah_premium') * ldec_ei_portion_of_fringe * ldec_ei_employer_multiplier, 2))  
						
		abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') &
						+ round(abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium') * ldec_ei_portion_of_fringe * ldec_ei_employer_multiplier, 2))  
						
		// shift premium portion of EI
		abo_pr_ck.of_SetItem(1, 'shift_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'shift_premium_fringe') &
						+ round(abo_pr_ck.of_GetItemDecimal(1, 'shift_premium') * ldec_ei_portion_of_fringe * ldec_ei_employer_multiplier, 2))  
	END IF
END IF

//Calculate the QPIP premium
abo_pr_ck.of_SetItem(1, 'qpip_premium', 0)
abo_pr_ck.of_SetItem(1, 'qpip_earn', 0)

IF ibo_employee.of_GetItemString(1, "qpip_exempt_flag") = 'N' &
AND ibo_employee.of_GetItemString(1, "employment_type") = 'Y' &
AND ibo_employee.of_GetItemString(1, "tax_province") = 'QC' THEN
	
	abo_pr_ck.of_SetItem(1, 'qpip_earn', 	 abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn'))
	
	//Calculate the QPIP
	IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') >= 0 THEN  
		
		//How much EI is still to be paid to reach federal maximum?
		ldec_qpip_outstanding = ibo_federal_tax.of_GetItemDecimal(1, 'qpip_annual_max_premium') - ldec_ytd_qpip_premium   
		
		//This calculation varies from the document.  I think we did it to catch people up if they were at a lower contribution
		ldec_qpip_current = round(ibo_federal_tax.of_GetItemDecimal(1, 'qpip_employee_rate') &
											* (ldec_ytd_qpip_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')), 2) &
											- ldec_ytd_qpip_premium
	
		abo_pr_ck.of_SetItem(1, 'qpip_premium', min(ldec_qpip_outstanding, ldec_qpip_current))
		
	
	ELSEIF ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') < ibo_federal_tax.of_GetItemDecimal(1, 'qpip_annual_max_earning') THEN
		
		// cheque is reducing the EI earnings so a credit premium will be issued
		ldec_qpip_current = round(ibo_federal_tax.of_GetItemDecimal(1, 'qpip_employee_rate') &
									* (ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') &
									- Min(ibo_federal_tax.of_GetItemDecimal(1, 'qpip_annual_max_earning'), ldec_ytd_taxable_earn)), 2) 
							
		abo_pr_ck.of_SetItem(1, 'qpip_premium', ldec_qpip_current)
   END IF
	
	//Apportion QPIP to Fringe
	IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') <> 0 THEN
		ldec_qpip_portion_of_fringe = abo_pr_ck.of_GetItemDecimal(1, 'qpip_premium') / abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
		abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') &
						+ round(abo_pr_ck.of_GetItemDecimal(1, 'tah_premium') * ldec_qpip_portion_of_fringe * ibo_federal_tax.of_GetItemDecimal(1, 'qpip_employer_multiplier'), 2))  
						
		abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') &
						+ round(abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium') * ldec_qpip_portion_of_fringe * ibo_federal_tax.of_GetItemDecimal(1, 'qpip_employer_multiplier'), 2))  
						
		// shift premium portion of EI
		abo_pr_ck.of_SetItem(1, 'shift_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'shift_premium_fringe') &
						+ round(abo_pr_ck.of_GetItemDecimal(1, 'shift_premium') * ldec_qpip_portion_of_fringe * ibo_federal_tax.of_GetItemDecimal(1, 'qpip_employer_multiplier'), 2))  
	END IF
END IF

IF ibo_employee.of_GetItemString(1, "employment_type") = 'Y' THEN

	// less union dues,  employee RRSP & annualized monthly dues
	ldec_cpp 			= abo_pr_ck.of_GetItemDecimal(1, 'cpp_contribution')
	ldec_ei 				= abo_pr_ck.of_GetItemDecimal(1, 'ei_premium')
	ldec_qpip 			= abo_pr_ck.of_GetItemDecimal(1, 'qpip_premium')
	
	decimal	ldec_F5, ldec_f5a, ldec_f5b, ldec_bonus, ldec_bonus_ytd, ldec_f5b_ytd, ldec_f5_ytd

	IF abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') >= '202301' AND Not(lb_cpp_exempt) THEN
	
		//B: Gross bonus, retroactive pay increase, vacation pay when vacation is not taken, accumulated overtime payment or other non-periodic payment
		ldec_bonus = abo_pr_ck.of_GetItemDecimal(1, 'other_taxable_pay') 		& 
					  + abo_pr_ck.of_GetItemDecimal(1, 'retro')
		IF ibo_employee_earning.of_RowCount() > 0 THEN
			ldec_bonus_ytd = ibo_employee_earning.of_GetItemDecimal(1, 'other_taxable_pay') 		& 
								+ ibo_employee_earning.of_GetItemDecimal(1, 'retro')
		ELSE
			ldec_bonus_ytd = 0
		END IF
					  
		// Use this for determining C and C2
		ldec_annual_income = abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') * ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year')
		
		//	Canada (or Quebec) Pension Plan contributions for the pay period
		//	To determine CPP contributions for employees receiving salary or wages 
		//	C = The lesser of: (i) $4,230.45* × (PM/12) – D*; 
		//	(ii) 0.0595* × [PI – ($3,500 / P)] If the result is negative, C = $0.
		IF abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') >= '202501' THEN
			ldec_i = ldec_cpp_annual_maximum * (li_cpp_months/12) - ldec_ytd_cpp_contribution - ldec_ytd_cpp2_contribution
			ldec_ii = ldec_cpp_multiplier * (abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') - (ldec_cpp_annual_allowance / ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year')))
			ldec_c = Min(ldec_i, ldec_ii)
			IF ldec_c < 0 THEN
				ldec_c = 0
			END IF
		ELSE
			ldec_c = ldec_cpp
		END IF

		//	Second additional Canada (or Quebec) Pension Plan contributions for the pay period
		//	To determine CPP2 contributions for employees receiving salary or wages
		//	C2 = The lesser of:
		//	(i) $416.00 × (PM/12) – D2*;
		//	 (ii) (PIYTD + PI – W) × 0.04
		//	If the result is negative, C2 = $0.
		IF abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') >= '202501' THEN
			// C2 = (Annualized Income - YMPE) * 0.04
			// 2026 YMPE = $74,600; 2026 YAMPE = $85,000
			ldec_cpp2_max = (ldec_cpp_second_max_earning - ldec_cpp_first_max_earning) * ldec_cpp_second_rate
			ldec_w = max(ldec_ytd_taxable_earn, ldec_cpp_first_max_earning)
			ldec_i = ldec_cpp2_max * (li_cpp_months/12) - ldec_ytd_cpp2_contribution
			ldec_ii = (ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') - ldec_w) * ldec_cpp_second_rate
			ldec_c2 = Min(ldec_i, ldec_ii)
			IF ldec_c2 < 0 THEN
				ldec_c2 = 0
			END IF
		ELSE
			ldec_c2 = 0
		END IF

		// F5          =      (C × (0.0100/0.0595)) + C2 -- C2 Added 2025
		//	Deductions for Canada Pension Plan additional contributions for the pay period
		ldec_f5 = Round((ldec_c * (ldec_cpp_first_rate/ldec_cpp_multiplier)) + ldec_c2, 2)
		IF ibo_employee_earning.of_RowCount() > 0 THEN
			ldec_f5_ytd = Round(ibo_employee_earning.of_GetItemDecimal(1, 'cpp_contribution') * (ldec_cpp_first_rate/ldec_cpp_multiplier), 2)
		ELSE
			ldec_f5_ytd = 0
		END IF

		IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') <> 0 THEN
			// F5A       =      F5 × ((PI – B)/PI)
			// Deductions for Canada (or Quebec) Pension Plan additional contributions for the pay period deducted from the periodic income
			// i.e. Portion of CPP that is for regular earnings, not including the bonus
			ldec_f5a = Round(ldec_f5 * ((abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') - ldec_bonus) &
										/ abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')), 2)
		
			// F5B       =      F5 × (B/PI)
			// Deductions for Canada (or Quebec) Pension Plan additional contributions for the pay period deducted from the non-periodic payment
			// i.e. Portion of CPP that is just for the bonus
			ldec_f5b = Round(ldec_f5 * (ldec_bonus / abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')), 2)
		ELSE
			ldec_f5a = 0
			ldec_f5b = 0
		END IF
		
		IF ibo_employee_earning.of_RowCount() > 0 THEN 
			IF ibo_employee_earning.of_GetItemDecimal(1, 'taxable_earn') <> 0 THEN
				ldec_f5b_ytd = Round(ldec_f5_ytd * (ldec_bonus_ytd / ibo_employee_earning.of_GetItemDecimal(1, 'taxable_earn')), 2)
			ELSE
				ldec_f5b_ytd = 0
			END IF
		ELSE
			ldec_f5b_ytd = 0
		END IF
	ELSE
		ldec_f5a = 0
		ldec_f5b = 0
		ldec_f5b_ytd = 0
		ldec_bonus_ytd = 0
	END IF
								
	// Option 1 – Tax Formulas 
	// https://www.canada.ca/en/revenue-agency/services/forms-publications/payroll/t4127-payroll-deductions-formulas/t4127-jan/t4127-jan-payroll-deductions-formulas-computer-programs.html#toc40
	// STEP 1
	// Determine the taxable income for the pay period (pay minus allowable deductions) 
	// and multiply it by the number of pay periods in the year to get an estimated annual 
	// taxable income amount. This annual taxable income amount is factor A.
	
	//annual taxable income
	//		A = [P × (I – F – F2 – F5A – U1)] – HD – F1 + (B – F3 – F5B)** + (B1 – F4 – F5BYTD)**
	//
	//		
	ldec_A = ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year') 							&
								* (Max( abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') 				&
								        - ibo_employee.of_GetItemDecimal(1, "reduced_tax_earning_per_ck"), 0)	/* jira 2823 */			&
										/*- ldec_bonus	*/										 					&
										- abo_pr_ck.of_GetItemDecimal(1, 'union_dues') 					&
										- abo_pr_ck.of_GetItemDecimal(1, 'employee_pension')			&
										- abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') 				&
										- abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') 	&
										- abo_pr_ck.of_GetItemDecimal(1, 'employer_rrsp')				&
										- abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp') 					&
										- ldec_f5a)	/* CPP for regular earnings, excluding the bonus */  		&
					- ibo_employee.of_GetItemDecimal(1, "federal_zone_deduction")					&
					- 12 * abo_pr_ck.of_GetItemDecimal(1, 'monthly_dues')  							&
					- 52 * abo_pr_ck.of_GetItemDecimal(1, 'weekly_dues') 								&
//this is too finicky, we can do it if someone asks us to:
//  there's more steps than this
//					+ (ldec_bonus &
//						- 0 			 	/* this is F3, which is the portion of the bonus allocated to pension, RRSP, or other tax deductible amounts */ &
//					   - ldec_f5b)   	/* portion of CPP for the bonus */ &
//					+ (ldec_bonus_ytd	/* year to date bonus payments */	&
//						- 0 			 	/* this is F4, which is the YTD portion of the bonus allocated to pension, RRSP, or other tax deductible amounts */ &
//						- ldec_f5b_ytd	/* portion of CPP for any bonuses paid out year to date */)
						
	//Get the pay period for the tax calculations
	CHOOSE CASE ibo_trade_union.of_GetItemString(1, 'pay_period_type')
		CASE 'W'
			li_current_pay_period = ibo_company.of_GetItemNumber(1, 'weekly_pay_period_start')
		CASE 'B'
			li_current_pay_period = ibo_company.of_GetItemNumber(1, 'biweekly_pay_period_start')
		CASE 'S'
			li_current_pay_period = ibo_company.of_GetItemNumber(1, 'semi_monthly_pay_period_start')
		CASE 'M'
			li_current_pay_period = ibo_company.of_GetItemNumber(1, 'monthly_pay_period_start')
	END CHOOSE

	//Canada Pension Plan contributions and employment insurance premiums federal tax credits for the year
	Decimal	ldec_annualized_cpp, ldec_annualized_ei, ldec_annualized_qpip
	
	//Annual CPP
	IF Not(lb_cpp_exempt) THEN
	 	IF abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') < '202301' THEN
			ldec_annualized_cpp = Min(ldec_cpp_annual_maximum,										&
									ldec_ytd_cpp_contribution 						/* employee contributions for the year */		&
									+ ldec_cpp 											/* this cheque */										&
									+ (ldec_cpp * (ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year')					&
														- li_current_pay_period))) 	/* remainder of the year */	
		ELSEIF abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') < '202401' THEN
			// New calculation for annualized CPP: P × C × (0.0495/0.0595), maximum $3,123.45 × (PM/12)
			ldec_annualized_cpp = ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year') * ldec_cpp * (ldec_cpp_base_rate/ldec_cpp_multiplier)
			IF ldec_annualized_cpp > ldec_cpp_base_maximum THEN
				ldec_annualized_cpp = ldec_cpp_base_maximum
			END IF
			ldec_annualized_cpp *= (li_cpp_months/12)	//Pro-rate based on age
		ELSEIF abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') < '202501' THEN
			// New calculation for annualized CPP: P × C × (0.0495/0.0595), maximum $3,217.50 × (PM/12)
			ldec_annualized_cpp = ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year') * ldec_cpp * (ldec_cpp_base_rate/ldec_cpp_multiplier)
			IF ldec_annualized_cpp > ldec_cpp_base_maximum THEN
				ldec_annualized_cpp = ldec_cpp_base_maximum
			END IF
			ldec_annualized_cpp *= (li_cpp_months/12)	//Pro-rate based on age
			
			//Now Determine if your employee exceeded the first maximum annual pensionable earnings ceiling
		END IF
		
	ELSE
		ldec_annualized_cpp = 0
	END IF
	
	//Annual EI
	IF abo_pr_ck.of_GetItemString(1, 'pr_yyyymm') < '202301' THEN
		ldec_annualized_ei = Min(ldec_ei_annual_max_premium,										&
								ldec_ytd_ei_premium 						/* employee contributions for the year */				&
								+ ldec_ei 											/* this cheque */										&
								+ (ldec_ei * (ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year')						&
													- li_current_pay_period))) 	/* remainder of the year */						
	ELSE														
		// (P × EI, maximum $1,002.45)
		ldec_annualized_ei = ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year') * ldec_ei 
		IF ldec_annualized_ei > ldec_ei_annual_max_premium THEN
			ldec_annualized_ei = ldec_ei_annual_max_premium
		END IF
	END IF												
							
	//No clients are in Quebec, if they do want to run a QC payroll, we'll need a big test cycle.  Address this then
	ldec_annualized_qpip = Min(ibo_federal_tax.of_GetItemDecimal(1, 'qpip_annual_max_premium'), 					&
							ldec_ytd_qpip_premium 								/* employee contributions for the year */	&
							+ ldec_qpip 					 						/* this cheque */									&
							+ (ldec_qpip * (ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year') 					&
												- li_current_pay_period))) 	/* remainder of the year */
												
	ldec_annualized_cpp = Round(ldec_annualized_cpp, 2)
	ldec_annualized_ei = Round(ldec_annualized_ei, 2)
	ldec_annualized_qpip = Round(ldec_annualized_qpip, 2)
	
	//K2 = [(0.14 × (P × C × (0.0495/0.0595), maximum $3,519.45 × (PM/12))) + (0.14 × (P × EI, maximum $1,123.07))]
	//ldec_k2 = Round(ibo_federal_tax.of_GetItemDecimal(1, 'r_1') * (ldec_annualized_cpp + ldec_annualized_ei + ldec_annualized_qpip), 2)	
	// --- 2026 K2 Calculation (Federal Tax Credits) ---
	Decimal ldec_annual_base_cpp, ldec_annual_ei_premium
	Decimal ldec_k2_cpp_credit, ldec_k2_ei_credit
	Decimal ldec_r1, ldec_cpp_ratio, ldec_maximum_cpp
	Integer li_pay_periods
	
	li_pay_periods = ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year')
	ldec_r1         = ibo_federal_tax.of_GetItemDecimal(1, 'r_1') // 0.14 for 2026
	ldec_cpp_ratio  = (ldec_cpp_base_rate / ldec_cpp_multiplier)  // (0.0495 / 0.0595)
	ldec_maximum_cpp = ldec_cpp_annual_maximum * ldec_cpp_ratio
	
	//(P × C × (0.0495/0.0595), maximum $3,519.45
	ldec_i = li_pay_periods * ldec_c * ldec_cpp_ratio
	IF ldec_i > ldec_maximum_cpp THEN
		ldec_i = ldec_maximum_cpp
	END IF
	ldec_i = ldec_r1 * ldec_i * li_cpp_months/12
	
	// 2. Calculate Annualized EI Premium
	// Use the annualized EI calculated from the current cheque (this takes into account the pay periods)
	ldec_annual_ei_premium = ldec_annualized_ei 
	
	// Apply the 2026 EI cap ($1,123.07)
	IF ldec_annual_ei_premium > ldec_ei_annual_max_premium THEN
		 ldec_annual_ei_premium = ldec_ei_annual_max_premium
	END IF
	
	// 3. Final K2 Calculation
	// Apply the lowest federal tax rate (R1) to the deductible base amounts
	ldec_ii  = ldec_r1 * ldec_annual_ei_premium
	
	ldec_k2 = ldec_i + ldec_ii
	
		
	//Steps 2 - 6 are in here:
	IF this.of_inc_tax_eff_dated(ldec_a, 	&
										  ldec_k2,  &
										  ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year'),  &
										  li_cpp_months, &
										  ldec_t1,  &
										  ldec_t2,  &
										  abo_pr_ck.of_GetItemNumber(1, 'employee'),  &
										  ldt_pr_yyyymm_01,  &
										  ldec_cpp, &
										  ldec_ei,	&
										  ldec_qpip,&
										  ldec_ytd_cpp_contribution, 	&
										  ldec_ytd_ei_premium, 			&
										  ldec_ytd_qpip_premium, 		&
										  ads_msg) = -1 THEN 
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "Error calculating income tax")
		RETURN -1
	END IF
	
	IF ibo_employee.of_GetItemString(1, "income_tax_exempt_flag") = 'Y' OR ldec_a < 0 THEN
		abo_pr_ck.of_SetItem(1, 'income_tax', 0)
		abo_pr_ck.of_SetItem(1, 'income_tax_fed', 0)
		abo_pr_ck.of_SetItem(1, 'income_tax_prov', 0)
	ELSE
		ldec_income_tax_fed = Round(ldec_t1/ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year'), 2)
		ldec_income_tax_prov = Round( ldec_t2/ibo_pay_period.of_GetItemNumber(1, 'pay_period_per_year'), 2)
		abo_pr_ck.of_SetItem(1, 'income_tax', ldec_income_tax_fed + ldec_income_tax_prov)
		abo_pr_ck.of_SetItem(1, 'income_tax_fed', ldec_income_tax_fed)
		abo_pr_ck.of_SetItem(1, 'income_tax_prov', ldec_income_tax_prov)
	END IF

   ldec_wcb_earn = abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
ELSEIF ibo_employee.of_GetItemString(1, "employment_type") = 'S' THEN
   abo_pr_ck.of_SetItem(1, 'income_tax', 0)
   abo_pr_ck.of_SetItem(1, 'taxable_earn', 0)
   abo_pr_ck.of_SetItem(1, 'wcb_remittance', 0)
   ldec_wcb_earn = 0
ELSEIF ibo_employee.of_GetItemString(1, "employment_type") = 'U' THEN
   abo_pr_ck.of_SetItem(1, 'income_tax', 0)
   abo_pr_ck.of_SetItem(1, 'wcb_remittance', 0)
   ldec_wcb_earn = 0
END IF

//---------------------
// WCB
//---------------------

li_rc = this.of_wcb_calc(ldec_wcb_earn, ldec_wcb_remittance, abo_pr_ck, ads_msg)
IF li_rc = -1 THEN 
	ll_msg_row = ads_msg.InsertRow(0)
	ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
	ads_msg.SetItem(ll_msg_row, 'message', "Error calculating wcb")
	RETURN -1
ELSEIF li_rc = 1 THEN
	abo_pr_ck.of_SetItem(1, 'wcb_remittance', ldec_wcb_remittance)
END IF

//Prorate WCB remittance to fringe amounts
IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') > 0 THEN
	ldec_wcb_portion_of_fringe = abo_pr_ck.of_GetItemDecimal(1, 'wcb_remittance') / abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
	abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') 		&
															+ round(abo_pr_ck.of_GetItemDecimal(1, 'tah_premium') * ldec_wcb_portion_of_fringe, 2))
	abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') 		& 
															+ round(abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium') * ldec_wcb_portion_of_fringe, 2))
	abo_pr_ck.of_SetItem(1, 'shift_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'shift_premium_fringe') 		& 
															+ round(abo_pr_ck.of_GetItemDecimal(1, 'shift_premium') * ldec_wcb_portion_of_fringe, 2))
END IF

//---------------------
//  Payroll taxes based on taxable earnings
//---------------------

IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') > 0 THEN 
	
	//Add in Education Tax======================================================
	IF Not(IsValid(ibo_province_education_tax)) THEN
		ibo_province_education_tax = CREATE n_bo_province_education_tax
		ibo_province_education_tax.of_SetTransaction()
	END IF
	
	ll_pet_rows = ibo_province_education_tax.of_Retrieve("province = '" + ibo_employee.of_GetItemString(1, "tax_province") &
 												 + "' AND effective_date <= '" + String(ldt_pr_yyyymm_01, 'yyyy.mm.dd') &
												 + "' AND expiry_date >= '" + String(ldt_pr_yyyymm_01, 'yyyy.mm.dd') + "'") 
	IF ll_pet_rows < 0 THEN
		this.of_msg_db_error("Error reading province employer tax")
	ELSE
		
		FOR ll_pet_row = 1 TO ll_pet_rows
		
			//Validate the vendor is setup in this set of books.  If not, it means
			//the employee's tax province is wrong or the employer tax isn't setup correctly
			IF Not(IsValid(ibo_vendor)) THEN
				ibo_vendor = CREATE n_bo_vendor
				ibo_vendor.of_SetTransaction()
			END IF
			IF ibo_vendor.of_Retrieve("book = '" + gnv_app.is_book + "' AND vendor = '" + ibo_province_education_tax.of_GetItemString(ll_pet_row, 'vendor') + "'") <> 1 THEN
				ll_msg_row = ads_msg.InsertRow(0)
				ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
				ads_msg.SetItem(ll_msg_row, 'message', "Employee is subject to Provincial Employer Tax, but vendor " &
																		+ ibo_province_education_tax.of_GetItemString(ll_pet_row, 'vendor') 	&
																		+ " is not valid in " + f_get_company_name(gnv_app.is_book))
				RETURN -1
			END IF
			
			//Validate the G/L account is setup in this set of books. 
			IF Not(IsValid(ibo_gl_account)) THEN
				ibo_gl_account = CREATE n_bo_gl_account
				ibo_gl_account.of_SetTransaction()
			END IF
			IF ibo_gl_account.of_Retrieve("book = '" + gnv_app.is_book + "' AND gl_account = '" + ibo_province_education_tax.of_GetItemString(ll_pet_row, 'gl_account') + "'") < 1 THEN
				ll_msg_row = ads_msg.InsertRow(0)
				ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
				ads_msg.SetItem(ll_msg_row, 'message', "Employee is subject to Provincial Employer Tax, but G/L account " &
																		+ ibo_province_education_tax.of_GetItemString(ll_pet_row, 'gl_account') 	&
																		+ " is not set up in " + f_get_company_name(gnv_app.is_book))
				RETURN -1
				
			END IF
					
			//Only apply against what remains of the max earnings to tax
			IF ldec_ytd_taxable_earn + abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') > ibo_province_education_tax.of_GetItemDecimal(ll_pet_row, 'max_earning') THEN
				//Just the remaining amount below the maximum earnings cutoff
				ldec_pet_portion = ibo_province_education_tax.of_GetItemDecimal(1, 'max_earning') - ldec_ytd_taxable_earn
			ELSE
				//Entire amount is taxable
				ldec_pet_portion = abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
			END IF

			//Add in provincial employer tax
			ldec_employer_tax = Round(ldec_pet_portion * ibo_Province_education_tax.of_GetItemDecimal(ll_pet_row, 'rate'), 2) 
			abo_pr_ck.of_SetItem(1, 'province_education_tax', abo_pr_ck.of_GetItemDecimal(1, 'province_education_tax') + ldec_employer_tax)
				
		NEXT
			
		//Prorate Employer Tax to fringe amounts
		ldec_education_portion_of_fringe = abo_pr_ck.of_GetItemDecimal(1, 'province_education_tax') / abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn')
		abo_pr_ck.of_SetItem(1, 'tah_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') 		&
											+ round(abo_pr_ck.of_GetItemDecimal(1, 'tah_premium') * ldec_education_portion_of_fringe, 2))
		abo_pr_ck.of_SetItem(1, 'ovr_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') 		& 
											+ round(abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium')  * ldec_education_portion_of_fringe, 2))
		abo_pr_ck.of_SetItem(1, 'shift_premium_fringe', abo_pr_ck.of_GetItemDecimal(1, 'shift_premium_fringe') 		& 
												+ round(abo_pr_ck.of_GetItemDecimal(1, 'shift_premium') * ldec_education_portion_of_fringe, 2))
	END IF
	//==========================================================================

	//Add in Payroll Tax========================================================
	IF Not(IsValid(ibo_province_payroll_tax)) THEN
		ibo_province_payroll_tax = CREATE n_bo_province_payroll_tax
		ibo_province_payroll_tax.of_SetTransaction()
	END IF
	
	ll_pet_rows = ibo_province_payroll_tax.of_Retrieve("province = '" + ibo_employee.of_GetItemString(1, "tax_province") &
												 + "' AND effective_date <= '" + String(ldt_pr_yyyymm_01, 'yyyy.mm.dd') &
												 + "' AND expiry_date >= '" + String(ldt_pr_yyyymm_01, 'yyyy.mm.dd') + "'") 
	IF ll_pet_rows < 0 THEN
		
		this.of_msg_db_error("Error reading province payroll tax")
		RETURN -1
		
	ELSEIF ll_pet_rows = 1 THEN
		
		//User can override this in the entry screen if the flag is set on the province_payroll_tax entry
		//So only recalculate when approving the cheque OR if the user isn't allowed to change the field (jira 5961)
		IF as_mode = 'approve'  &
		OR ibo_province_payroll_tax.of_GetItemString(1, 'change_allowed_on_ck_payroll_tax_flag') = 'N' THEN
			
			//Validate the vendor is setup in this set of books.  If not, it means
			//the employee's tax province is wrong or the payroll tax isn't setup correctly
			IF Not(IsValid(ibo_vendor)) THEN
				ibo_vendor = CREATE n_bo_vendor
				ibo_vendor.of_SetTransaction()
			END IF
			IF ibo_vendor.of_Retrieve("book = '" + gnv_app.is_book + "' AND vendor = '" + ibo_province_payroll_tax.of_GetItemString(1, 'vendor') + "'") <> 1 THEN
				ll_msg_row = ads_msg.InsertRow(0)
				ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
				ads_msg.SetItem(ll_msg_row, 'message', "Employee is subject to province P/R tax, but vendor " &
																		+ ibo_province_payroll_tax.of_GetItemString(1, 'vendor') 	&
																		+ " is not valid in " + f_get_company_name(gnv_app.is_book))
				RETURN -1
			ELSE
				//Validate the G/L account is setup in this set of books. 
				IF Not(IsValid(ibo_gl_account)) THEN
					ibo_gl_account = CREATE n_bo_gl_account
					ibo_gl_account.of_SetTransaction()
				END IF
				IF ibo_gl_account.of_Retrieve("book = '" + gnv_app.is_book + "' AND gl_account = '" + ibo_province_payroll_tax.of_GetItemString(1, 'gl_account') + "'") < 1 THEN
					ll_msg_row = ads_msg.InsertRow(0)
					ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
					ads_msg.SetItem(ll_msg_row, 'message', "Employee is subject to province P/R tax, but G/L account " &
																			+ ibo_province_payroll_tax.of_GetItemString(1, 'gl_account') 	&
																			+ " is not set up in " + f_get_company_name(gnv_app.is_book))
					RETURN -1
				ELSE
					//Calculate amount
					abo_pr_ck.of_SetItem(1, 'province_payroll_tax', Round(abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') * ibo_Province_payroll_tax.of_GetItemDecimal(1, 'rate'), 2))			
				END IF
			END IF
		END IF
	END IF
	//==========================================================================

END IF

//---------------------
// Totals
//---------------------

abo_pr_ck.of_SetItem(1, 'reg_fringe', &
                       abo_pr_ck.of_GetItemDecimal(1, 'cpp_contribution') 												&
                     + abo_pr_ck.of_GetItemDecimal(1, 'cpp2_contribution') 												&
                     + round(abo_pr_ck.of_GetItemDecimal(1, 'ei_premium') * ldec_ei_employer_multiplier, 2) 	&
                     + round(abo_pr_ck.of_GetItemDecimal(1, 'qpip_premium') * ibo_federal_tax.of_GetItemDecimal(1, 'qpip_employer_multiplier'), 2) 	&
                     + abo_pr_ck.of_GetItemDecimal(1, 'union_remittance') 												&
                     + abo_pr_ck.of_GetItemDecimal(1, 'wcb_remittance') 												&
                     + abo_pr_ck.of_GetItemDecimal(1, 'province_education_tax')										&
                     + abo_pr_ck.of_GetItemDecimal(1, 'vacation_earn') 													&
                     + abo_pr_ck.of_GetItemDecimal(1, 'statutory_earn' )												&
                     + abo_pr_ck.of_GetItemDecimal(1, 'paid_sick_leave' )												&
                     + abo_pr_ck.of_GetItemDecimal(1, 'training') 														&
                     + abo_pr_ck.of_GetItemDecimal(1, 'employer_rrsp') 													&
                     + abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_earn') 										&
                     + abo_pr_ck.of_GetItemDecimal(1, 'group_safety_earn') 											&
                     + abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_earn') 										&
                     + abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_earn') 											&
                     + abo_pr_ck.of_GetItemDecimal(1, 'smtc_earn') 														&
                     + abo_pr_ck.of_GetItemDecimal(1, 'incentive_earn')													&
						   + abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp_paid_out')		/* jira 3666 */				&
						   + abo_pr_ck.of_GetItemDecimal(1, 'employer_rrsp_paid_out') /* jira 3666 */					&
                     - abo_pr_ck.of_GetItemDecimal(1, 'tah_premium_fringe') 											&
                     - abo_pr_ck.of_GetItemDecimal(1, 'ovr_premium_fringe') 											&
                     - abo_pr_ck.of_GetItemDecimal(1, 'shift_premium_fringe') )

IF Abs(abo_pr_ck.of_GetItemDecimal(1, 'reg_fringe')) > 99999.99 THEN
	this.of_prcent_err('Regular fringe amount is greater than $99,999.99 (' + String(abo_pr_ck.of_GetItemDecimal(1, 'reg_fringe'), '$#,###.00') + ')', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), ads_msg)
	ll_msg_row = ads_msg.InsertRow(0)
	ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
	ads_msg.SetItem(ll_msg_row, 'message', "Error calculating fringe")
	RETURN -1
END IF
	
abo_pr_ck.of_SetItem(1, 'gross_pay', &
                       abo_pr_ck.of_GetItemDecimal(1, 'reg_earn') 						&
                     + abo_pr_ck.of_GetItemDecimal(1, 'tah_earn') 						&
                     + abo_pr_ck.of_GetItemDecimal(1, 'ovr_earn') 						&
                     + abo_pr_ck.of_GetItemDecimal(1, 'travel_earn') 					&
                     + abo_pr_ck.of_GetItemDecimal(1, 'turnaround') 					&
                     + abo_pr_ck.of_GetItemDecimal(1, 'taxi') 							&
                     + abo_pr_ck.of_GetItemDecimal(1, 'taxable_loa') 					&
                     + abo_pr_ck.of_GetItemDecimal(1, 'taxable_mileage') 				& 
                     + abo_pr_ck.of_GetItemDecimal(1, 'vacation_paid') 				&
                     + abo_pr_ck.of_GetItemDecimal(1, 'other_taxable_pay')			& 
                     + abo_pr_ck.of_GetItemDecimal(1, 'vehicle_allowance_paid')		& 
                     + abo_pr_ck.of_GetItemDecimal(1, 'meal') 							&
                     + abo_pr_ck.of_GetItemDecimal(1, 'retro')							&
                     + abo_pr_ck.of_GetItemDecimal(1, 'pay_in_lieu_of_notice') 		&
                     + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_loa') 				&
                     + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_mileage') 			& 
                     + abo_pr_ck.of_GetItemDecimal(1, 'statutory_paid') 				&
                     + abo_pr_ck.of_GetItemDecimal(1, 'personal_safety_paid')		&
                     + abo_pr_ck.of_GetItemDecimal(1, 'group_safety_paid') 			&
                     + abo_pr_ck.of_GetItemDecimal(1, 'production_bonus_paid') 		&
                     + abo_pr_ck.of_GetItemDecimal(1, 'staff_safety_paid') 			&
                     + abo_pr_ck.of_GetItemDecimal(1, 'smtc_paid') 						&
                     + abo_pr_ck.of_GetItemDecimal(1, 'retention_paid') 				&
                     + abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid') 				&
                     + abo_pr_ck.of_GetItemDecimal(1, 'taxable_site_allow') 			&
                     + abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_site_allow')		&
							+ abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp_paid_out')			/* jira 3666 - Both of the new fields are part of gross and net pay */&
							+ abo_pr_ck.of_GetItemDecimal(1, 'employer_rrsp_paid_out')		&
							+ abo_pr_ck.of_GetItemDecimal(1, 'paid_sick_leave'))				/* new field added March 2022 */

abo_pr_ck.of_SetItem(1, 'net_pay', &
                       abo_pr_ck.of_GetItemDecimal(1, 'gross_pay') 						&
																												&
					/* subtract off union deductions */												&
																												&
                     - abo_pr_ck.of_GetItemDecimal(1, 'admin_fee') 						&
                     - abo_pr_ck.of_GetItemDecimal(1, 'union_dues') 						&
                     - abo_pr_ck.of_GetItemDecimal(1, 'back_dues') 						&
                     - abo_pr_ck.of_GetItemDecimal(1, 'daily_dues') 						&
                     - abo_pr_ck.of_GetItemDecimal(1, 'weekly_dues') 					&
                     - abo_pr_ck.of_GetItemDecimal(1, 'monthly_dues')					&
                     - abo_pr_ck.of_GetItemDecimal(1, 'employee_pension')				&
 							/* vacation_paid_to_union handled below   */							&
 							/* statutory_paid_to_union handled below  */							&
                     - abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') 		&
																												&
					/* subtract off employee deductions */											&
																												&
                     - abo_pr_ck.of_GetItemDecimal(1, 'ei_premium') 						&
                     - abo_pr_ck.of_GetItemDecimal(1, 'qpip_premium') 					&
                     - abo_pr_ck.of_GetItemDecimal(1, 'cpp_contribution') 				&
                     - abo_pr_ck.of_GetItemDecimal(1, 'cpp2_contribution') 				&
                     - abo_pr_ck.of_GetItemDecimal(1, 'income_tax') 						&
                     - abo_pr_ck.of_GetItemDecimal(1, 'misc_deduction') 				&
                     - abo_pr_ck.of_GetItemDecimal(1, 'insurance') 						&
 							/* advance_repay handled below   */										&
                     - abo_pr_ck.of_GetItemDecimal(1, 'security_deposit') 				&
 							/* charity handled below   		*/										&
                     - abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') 					&
                     - abo_pr_ck.of_GetItemDecimal(1, 'province_payroll_tax') 		&
							)


//---------------------
// Vacation/Stat paid to union is deducted from net pay
//---------------------

IF as_mode <> 'recalc' THEN
	IF abo_pr_cheque_trade_union.of_RowCount() = 0 THEN
		//Vacation_paid_to_union 
		IF ibo_trade_union_rate.of_GetItemString(1, 'remit_vacation_pay_flag') = 'Y' AND abo_pr_ck.of_GetItemDecimal(1, 'vacation_paid') <> 0 THEN
			abo_pr_ck.of_SetItem(1, 'vacation_paid_to_union', abo_pr_ck.of_GetItemDecimal(1, 'vacation_paid'))
			
			//Deduct from net pay
			abo_pr_ck.of_SetItem(1, 'net_pay', &
									  abo_pr_ck.of_GetItemDecimal(1, 'net_pay')						&
									- abo_pr_ck.of_GetItemDecimal(1, 'vacation_paid_to_union'))
		ELSE
			abo_pr_ck.of_SetItem(1, 'vacation_paid_to_union', 0)
		END IF
		
		//Statutory_paid_to_union 
		IF ibo_trade_union_rate.of_GetItemString(1, 'remit_statutory_pay_flag') = 'Y' AND abo_pr_ck.of_GetItemDecimal(1, 'statutory_paid') <> 0 THEN
			abo_pr_ck.of_SetItem(1, 'statutory_paid_to_union', abo_pr_ck.of_GetItemDecimal(1, 'statutory_paid'))
			
			//Deduct from net pay
			abo_pr_ck.of_SetItem(1, 'net_pay', &
								  abo_pr_ck.of_GetItemDecimal(1, 'net_pay') &
								- abo_pr_ck.of_GetItemDecimal(1, 'statutory_paid_to_union'))
		ELSE
			abo_pr_ck.of_SetItem(1, 'statutory_paid_to_union', 0)
		END IF
	ELSE
		//Because there's trade union children that might have different values for remit_vacation_pay
		//we have to use their values
		FOR ll_ctu_row = 1 TO abo_pr_cheque_trade_union.of_RowCount()
			//just deduct from net pay because the 'paid to union' part was 
			abo_pr_ck.of_SetItem(1, 'net_pay', &
									  abo_pr_ck.of_GetItemDecimal(1, 'net_pay')						&
									- abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row, 'vacation_paid_to_union'))
			abo_pr_ck.of_SetItem(1, 'net_pay', &
									  abo_pr_ck.of_GetItemDecimal(1, 'net_pay')						&
									- abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row, 'statutory_paid_to_union'))
		NEXT
	END IF
	
END IF

//---------------------
// Employee Purchases
//---------------------

IF as_mode = 'approve' THEN
	
   // Retrieve all the employee purchase records for this employee, and 
	// if they were paid for by this cheque, mark them as $0.00 payments
	// (updates are applied to the business object, not updated)
	
	decimal ldec_cra_amount
	
	abo_employee_purchase.of_reset_employee_purchase_repayments(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), &
																					 abo_pr_ck.of_GetItemNumber(1, 'employee'), &
																					 adec_total_unpaid_employee_purchases	/* remaining outstanding amounts */ )
	
	
   IF abo_pr_ck.of_GetItemDecimal(1, 'net_pay') >= 0 THEN
      
		//don't take more than the cheque amount
		abo_pr_ck.of_SetItem(1, 'misc_deduction', Min(adec_total_unpaid_employee_purchases, abo_pr_ck.of_GetItemDecimal(1, 'net_pay')))
      
		//don't take more than the employee owes
		abo_pr_ck.of_SetItem(1, 'misc_deduction', Min(adec_total_unpaid_employee_purchases, abo_pr_ck.of_GetItemDecimal(1, 'misc_deduction')))
      
		//mark employee_purchase records as paid
		abo_employee_purchase.of_repay(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), &
												  abo_pr_ck.of_GetItemDecimal(1, 'misc_deduction'), &
												  abo_pr_ck.of_GetItemNumber(1, 'employee'), &
												  abo_pr_ck.of_GetItemDateTime(1, 'issue_date'), &
												  abo_pr_ck.of_GetItemString(1, 'pr_yyyymm'))

      //deduct from net_pay
		abo_pr_ck.of_SetItem(1, 'net_pay', abo_pr_ck.of_GetItemDecimal(1, 'net_pay') - abo_pr_ck.of_GetItemDecimal(1, 'misc_deduction'))
		
	ELSEIF adec_total_unpaid_employee_purchases < 0 THEN
		
		// Can reimburse employee even if net pay is negative
		abo_pr_ck.of_SetItem(1, 'misc_deduction', adec_total_unpaid_employee_purchases)
		
		//mark employee_purchase records as paid
		abo_employee_purchase.of_repay(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), &
												  abo_pr_ck.of_GetItemDecimal(1, 'misc_deduction'), &
												  abo_pr_ck.of_GetItemNumber(1, 'employee'), &
												  abo_pr_ck.of_GetItemDateTime(1, 'issue_date'), &
												  abo_pr_ck.of_GetItemString(1, 'pr_yyyymm'))

      //deduct from net_pay
		abo_pr_ck.of_SetItem(1, 'net_pay', abo_pr_ck.of_GetItemDecimal(1, 'net_pay') - abo_pr_ck.of_GetItemDecimal(1, 'misc_deduction'))
	END IF
	
	IF abo_employee_purchase.of_get_outstanding() = 0 THEN
		// outstanding amount is zero, so look for unpaid invoice items.
		// They will exist when invoice items reverse previously paid invoice items.
		// They should be marked as paid for by this cheque
		abo_employee_purchase.of_mark_orphans_paid(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), &
												  abo_pr_ck.of_GetItemDecimal(1, 'misc_deduction'), &
												  abo_pr_ck.of_GetItemNumber(1, 'employee'), &
												  abo_pr_ck.of_GetItemDateTime(1, 'issue_date'), &
												  abo_pr_ck.of_GetItemString(1, 'pr_yyyymm'))
	END IF

END IF
							
//---------------------
// Adjustments
//---------------------

IF as_mode = 'approve' OR as_mode = 'recalc' THEN

	//Make adjustments if net pay has dipped below 0.
   IF abo_pr_ck.of_GetItemDecimal(1, 'net_pay') < 0 AND abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') > 0 THEN
      ldec_work = -1.0 * abo_pr_ck.of_GetItemDecimal(1, 'net_pay') 
      IF abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') >= ldec_work THEN
         abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') - ldec_work)
         abo_pr_ck.of_SetItem(1, 'net_pay', 					abo_pr_ck.of_GetItemDecimal(1, 'net_pay') + ldec_work)
	
			IF abo_pr_ck.of_GetItemDecimal(1, 'gross_pay') > 0 THEN
				ll_msg_row = ads_msg.InsertRow(0)
				ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
				ads_msg.SetItem(ll_msg_row, 'message', "Incentive Paid to RRSP is reduced by " + String(ldec_work, '#,###.00') + " to " + String(abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') , '#,###.00'))
			END IF 
    ELSE
         ldec_work = abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') 
         abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', 0)
         abo_pr_ck.of_SetItem(1, 'net_pay', 					abo_pr_ck.of_GetItemDecimal(1, 'net_pay') + ldec_work)
      END IF
   END IF

   IF abo_pr_ck.of_GetItemDecimal(1, 'net_pay') < 0 AND abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') > 0 THEN
      ldec_work = -1.0 * abo_pr_ck.of_GetItemDecimal(1, 'net_pay') 
      IF abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp')  >= ldec_work THEN
         abo_pr_ck.of_SetItem(1, 'employee_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp')  - ldec_work)
         abo_pr_ck.of_SetItem(1, 'net_pay', 		abo_pr_ck.of_GetItemDecimal(1, 'net_pay')  + ldec_work)

			IF abo_pr_ck.of_GetItemDecimal(1, 'gross_pay') > 0 THEN
				ll_msg_row = ads_msg.InsertRow(0)
				ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
				ads_msg.SetItem(ll_msg_row, 'message', "Employee RRSP is reduced to " + String(abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') , '#,###.00'))
			END IF
    ELSE
         ldec_work = abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') 
         abo_pr_ck.of_SetItem(1, 'employee_rrsp', 0)
         abo_pr_ck.of_SetItem(1, 'net_pay', 		abo_pr_ck.of_GetItemDecimal(1, 'net_pay') + ldec_work)
      END IF
   END IF

	IF ibo_company.of_GetItemString(1, 'reclaim_advance_flag') = 'Y' AND ibo_employee.of_GetItemDecimal(1, "advance_repay") <> 0 THEN
   	abo_pr_ck.of_SetItem(1, 'advance_repay',  -1.0 * ibo_employee.of_GetItemDecimal(1, "advance_repay"))
	ELSE
   	abo_pr_ck.of_SetItem(1, 'advance_repay',  0)
	END IF
   
	// retake as much of advance as possible
	IF Round(abo_pr_ck.of_GetItemDecimal(1, 'net_pay') + abo_pr_ck.of_GetItemDecimal(1, 'advance_repay'), 2) < 0 THEN
	   abo_pr_ck.of_SetItem(1, 'advance_repay',  -1.0 * abo_pr_ck.of_GetItemDecimal(1, 'net_pay'))            
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "It was necessary to adjust the advance/repay to ensure the net pay was not negative. Advance/repay is: " + String(abo_pr_ck.of_GetItemDecimal(1, 'advance_repay') , '#,###.00'))
	END IF
END IF

abo_pr_ck.of_SetItem(1, 'net_pay', abo_pr_ck.of_GetItemDecimal(1, 'net_pay') + abo_pr_ck.of_GetItemDecimal(1, 'advance_repay'))

//Additional tax per cheque
IF (as_mode = 'approve' OR as_mode = 'change' OR as_mode = 'recalc') 						&
AND abo_pr_ck.of_GetItemDecimal(1, 'net_pay') > 0 			&
AND abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') > 0 		&
AND abo_pr_ck.of_GetItemDecimal(1, 'net_pay') >= ibo_employee.of_GetItemDecimal(1, "add_income_tax_per_ck") THEN

	// jira 2823 - It is possible to drive the cheque's income tax amount negative with a negative employee.additional_income_tax_per_ck. Please make the minimum income tax zero. 
	IF ibo_employee.of_GetItemDecimal(1, "add_income_tax_per_ck") < 0 &
	AND abo_pr_ck.of_GetItemDecimal(1, 'income_tax') + ibo_employee.of_GetItemDecimal(1, "add_income_tax_per_ck") < 0 THEN
		ldec_increase_income_tax_by = -1.0 * abo_pr_ck.of_GetItemDecimal(1, 'income_tax')
	ELSE
		ldec_increase_income_tax_by = ibo_employee.of_GetItemDecimal(1, "add_income_tax_per_ck")
	END IF
	
	//Reduce income tax
   abo_pr_ck.of_SetItem(1, 'income_tax', abo_pr_ck.of_GetItemDecimal(1, 'income_tax') 	+ ldec_increase_income_tax_by)
   abo_pr_ck.of_SetItem(1, 'net_pay', 	abo_pr_ck.of_GetItemDecimal(1, 'net_pay') 		- ldec_increase_income_tax_by)
END IF

//Miscellaneous deductions
IF as_mode = 'approve' THEN
   IF abo_pr_ck.of_GetItemDecimal(1, 'net_pay') > 0 AND abo_pr_ck.of_GetItemDecimal(1, 'net_pay') > ibo_employee.of_GetItemDecimal(1, "charity_per_ck") THEN
 		abo_pr_ck.of_SetItem(1, 'charity', ibo_employee.of_GetItemDecimal(1, "charity_per_ck"))
		abo_pr_ck.of_SetItem(1, 'net_pay', abo_pr_ck.of_GetItemDecimal(1, 'net_pay') - ibo_employee.of_GetItemDecimal(1, "charity_per_ck"))
	END IF
	IF ibo_employee.of_GetItemString(1, "garnishee_flag") = 'Y' THEN
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "Needs a deduction (garnishee) for employee " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')))
	END IF
	IF adec_total_unpaid_employee_purchases <> 0 THEN
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "Needs a deduction (" + String(adec_total_unpaid_employee_purchases, "#,###.00") + " employee purchase) for employee " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')))
	END IF
	
	// approved
	IF abo_pr_ck.of_GetItemDecimal(1, 'taxable_earn') < 0 THEN
		abo_pr_ck.of_SetItem(1, 'cheque_status', 'U')
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "Taxable Earnings are negative: " + String(abo_pr_ck.of_GetItemDecimal(1, "taxable_earn"), "#,###.00") + ", cheque not approved.")
	ELSE
		abo_pr_ck.of_SetItem(1, 'cheque_status', 'A')  
	END IF
END IF


RETURN 1
end function

public function integer of_tax_calc_get_trade_level_rates (string as_pension_rrsp, ref decimal adec_reg_rate, ref decimal adec_tah_rate, ref decimal adec_ovr_rate, ref string as_msg, ref n_cst_business abo_trade_union_rate, ref n_cst_business abo_trade_union_trade_level_rrsp_pension, ref n_cst_business abo_trade_union, ref n_cst_business abo_occupation);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_get_trade_level_rates
// Author   :	Monica Petersen
// Date     :	2017/05/09
// 	
// Arguments:	string as_pension_rrsp
// 				decimal adec_reg_rate
// 				decimal adec_tah_rate
// 				decimal adec_ovr_rate
// 				string as_msg
// 				n_cst_business abo_trade_union_rate
// 				n_cst_business abo_trade_union_trade_level_rrsp_pension
// 				n_cst_business abo_trade_union
// 				n_cst_business abo_occupation
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


Long	ll_find
String	ls_trade_level

ls_trade_level = abo_occupation.of_GetItemString(1, 'level')
IF IsNull(ls_trade_level) THEN ls_trade_level = ''

//Start by calculating the hourly amounts - use trade level rates if available
IF abo_occupation.of_GetItemString(1, 'trade') <> abo_trade_union.of_GetItemString(1, 'trade') &
AND abo_trade_union_trade_level_rrsp_pension.of_RowCount() > 0 THEN

	//Generate an error if trade levels are setup, but an employee has a trade different than the one setup for his union.
	//The trade levels are only meant for homogenous unions, i.e. all the same trade
	as_msg += "Employee " + String(ibo_employee.of_GetItemNumber(1, 'employee')) 	&
			 + " is trade " + abo_occupation.of_GetItemString(1, 'trade') 				&
			 + ", but trade union " + abo_occupation.of_GetItemString(1, 'trade_union')  	&
			 + " is associated with trade " + abo_trade_union.of_GetItemString(1, 'trade') &
			 + ". This isn't compatible for a union with trade level RRSP and pension amounts."
	RETURN -1 	

ELSEIF ls_trade_level = 'JM' &
OR abo_trade_union_trade_level_rrsp_pension.of_Find("rrsp_or_pension = '" + as_pension_rrsp + "'") = 0 THEN

	//Use trade union rates for journeymen, or if there are no trade level amounts defined
	IF as_pension_rrsp = 'P' THEN
		adec_reg_rate = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_pen_reg_hr')
		adec_tah_rate = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_pen_tah_hr')
		adec_ovr_rate = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_pen_ovr_hr')
	ELSE
		adec_reg_rate = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_rrsp_reg_hr')
		adec_tah_rate = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_rrsp_tah_hr')
		adec_ovr_rate = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_rrsp_ovr_hr')
	END IF
	
ELSEIF Len(ls_trade_level) > 0 THEN
	
	//There are trade level amounts defined, and this isn't a journeymen, so find the rate for this trade level
	ll_find = abo_trade_union_trade_level_rrsp_pension.of_Find("rrsp_or_pension = '" + as_pension_rrsp + "' AND trade_level = '" + ls_trade_level + "'")
	IF ll_find < 1 THEN
//		as_msg = "Error for employee " + String(ibo_employee.of_GetItemNumber(1, 'employee')) &
//				 + ", in union " + ibo_employee.of_GetItemString(1, 'trade_union') &
//				 + ", occupation " + ibo_employee.of_GetItemString(1, 'occupation') &
//		//incomplete set of rates
//		IF as_pension_rrsp = 'P' THEN
//			as_msg += '. Pension '
//		ELSE
//			as_msg += '. RRSP ' 
//		END IF
//		as_msg += "trade level rates not found for " + ls_trade_level
//		RETURN -1
		adec_reg_rate = 0
		adec_tah_rate = 0
		adec_ovr_rate = 0
	ELSE
		//Found the correct rates, return them
		adec_reg_rate = abo_trade_union_trade_level_rrsp_pension.of_GetItemDecimal(ll_find, 'regular_rate')
		adec_tah_rate = abo_trade_union_trade_level_rrsp_pension.of_GetItemDecimal(ll_find, 'time_and_half_rate')
		adec_ovr_rate = abo_trade_union_trade_level_rrsp_pension.of_GetItemDecimal(ll_find, 'overtime_rate')
	END IF

ELSE
	adec_reg_rate = 0
	adec_tah_rate = 0
	adec_ovr_rate = 0
	//Generate an error if trade levels are setup, but an employee has an occupation with no defined trade level
//	as_msg += "Error for employee " + String(ibo_employee.of_GetItemNumber(1, 'employee')) &
//			 + ". Trade level rates defined for trade union " + ibo_employee.of_GetItemString(1, 'trade_union') &
//			 + ", but no trade level defined for occupation "+ ibo_employee.of_GetItemString(1, 'occupation') + "."
//	RETURN -1 
END IF
		
RETURN 1
end function

public subroutine of_tax_calc_create_business_objects ();//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_create_business_objects
// Author   :	Monica Petersen
// Date     :	2017/05/09
// 	
// Arguments:	(None)
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

//---------------------------------
//Create business objects
//---------------------------------

IF Not(IsValid(ibo_pay_period)) THEN
	ibo_pay_period = CREATE n_bo_pay_period
	ibo_pay_period.of_SetTransaction()
END IF

IF Not(IsValid(ibo_company)) THEN
	ibo_company = CREATE n_bo_company
	ibo_company.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_employee)) THEN
	ibo_employee = CREATE n_bo_employee
	ibo_employee.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_employee_earning)) THEN
	ibo_employee_earning = CREATE n_bo_employee_earning
	ibo_employee_earning.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_federal_tax)) THEN
	ibo_federal_tax = CREATE n_bo_federal_tax
	ibo_federal_tax.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_person)) THEN
	ibo_person = CREATE n_bo_person
	ibo_person.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_premium_type)) THEN
	ibo_premium_type = CREATE n_bo_premium_type
	ibo_premium_type.of_SetTransaction()
	ibo_premium_type.of_Retrieve()
END IF
	
IF Not(IsValid(ibo_pr_cheque_premium)) THEN
	ibo_pr_cheque_premium = CREATE n_bo_pr_cheque_premium
	ibo_pr_cheque_premium.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_timesheet)) THEN
	ibo_timesheet = CREATE n_bo_timesheet
	ibo_timesheet.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_timesheet_this_tu)) THEN
	ibo_timesheet_this_tu = CREATE n_bo_timesheet
	ibo_timesheet_this_tu.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_timesheet_premium)) THEN
	ibo_timesheet_premium = CREATE n_bo_timesheet_premium
	ibo_timesheet_premium.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_trade_union)) THEN
	ibo_trade_union = CREATE n_bo_trade_union
	ibo_trade_union.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_trade_union_this_tu)) THEN
	ibo_trade_union_this_tu = CREATE n_bo_trade_union
	ibo_trade_union_this_tu.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_trade_union_rate)) THEN
	ibo_trade_union_rate = CREATE n_bo_trade_union_rate
	ibo_trade_union_rate.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_trade_union_rate_this_ts_or_tu)) THEN
	ibo_trade_union_rate_this_ts_or_tu = CREATE n_bo_trade_union_rate
	ibo_trade_union_rate_this_ts_or_tu.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_occupation)) THEN
	ibo_occupation = CREATE n_bo_occupation
	ibo_occupation.of_SetTransaction()
END IF
	
IF Not(IsValid(ibo_trade_union_trade_level_rrsp_pension)) THEN
	ibo_trade_union_trade_level_rrsp_pension = CREATE n_bo_trade_union_trade_level_rrsp_pension
	ibo_trade_union_trade_level_rrsp_pension.of_SetTransaction()
END IF

IF Not(IsValid(ibo_trade_union_trade_level_employee_rrsp)) THEN
	ibo_trade_union_trade_level_employee_rrsp = CREATE n_bo_trade_union_trade_level_employee_rrsp
	ibo_trade_union_trade_level_employee_rrsp.of_SetTransaction()
END IF

RETURN
end subroutine

public function integer of_tax_calc_union_dues (ref n_cst_business abo_pr_ck_or_tu, ref n_cst_business abo_trade_union_rate_this_tu, integer ai_ck_row, decimal adec_dues_premium_earn, decimal adec_reg_earn);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_union_dues
// Author   :	Monica Petersen
// Date     :	2017/05/09
// 	
// Arguments:	n_cst_business abo_pr_ck_or_tu
// 				n_cst_business abo_trade_union_rate_this_tu
// 				integer ai_ck_row
// 				decimal adec_dues_premium_earn
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

Decimal	ldec_hours, ldec_union_dues_per_hour, ldec_union_dues_per_earn

//Dues per hour amounts --  NOTE: this is included for all dues type for backward compatibility. It was only intended for 'C' and 'H' types 
ldec_hours = abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'reg_hour')
IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours += abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'travel_hour') //jira 1652

ldec_union_dues_per_hour = round(ldec_hours * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_reg_hr')															&
											+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'tah_hour') * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_tah_hr') 	&
											+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'ovr_hour') * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_ovr_hr'), 2)
		
CHOOSE CASE abo_trade_union_rate_this_tu.of_GetItemString(1, 'dues_type')

	// all hours at base rate
	CASE 'B'

		ldec_union_dues_per_earn = round ((abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'all_hr_base_earn') + adec_dues_premium_earn)  * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_reg_earn'), 2)
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'dues_source_earn', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'all_hr_base_earn') + adec_dues_premium_earn) 
		
	// on earnings by hour type
	CASE 'E'
	
		//Dues per earnings amounts		
		ldec_union_dues_per_earn = round(adec_reg_earn  * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_reg_earn') 												&
										+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'tah_earn') * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_tah_earn') 	&
										+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'ovr_earn') * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_ovr_earn'), 2)
										
		//Source earnings can't be used because the calculation has different rates for regular, time and a half and overtime earnings
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'dues_source_earn', 0 )	
		
	// on regular earnings ( SK Ironworkers) (jira 1300)
	CASE 'R'

		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'dues_source_earn', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'all_hr_reg_earn') ) 
		ldec_union_dues_per_earn = round (abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'all_hr_reg_earn')  * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_reg_earn'), 2)
		
END CHOOSE

abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_dues', ldec_union_dues_per_hour + ldec_union_dues_per_earn)
IF abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_reg_earn') + abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_tah_earn') + abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_ovr_earn') = 0 THEN
	//Dues source earnings are only relevant if there is a rate component
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'dues_source_earn', 0 ) 
END IF

// dues on vacation & statutory earnings
IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'dues_on_holiday_pay_flag') = 'Y' THEN
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_dues',  abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'union_dues') 					&
														+ Round((abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'vacation_earn') + abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'statutory_earn')) * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_reg_earn'), 2))
	
	IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'dues_type') <> 'E' THEN
		//only add in the vacation if the dues source earning is non-zero.
		//i.e. you can't show a source earnings for dues for tyep 'E' because it's got different rates for reg/tah/ovr.
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'dues_source_earn',  abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'dues_source_earn') 	&
															+ 	abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'vacation_earn') + abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row,  'statutory_earn') )
	END IF
	
END IF

RETURN 1
end function

public function integer of_get_union_benefit_invoice_amount (ref n_cst_business abo_pr_cheque, long al_c_row, ref n_cst_business abo_trade_union_benefit, long al_b_row, ref n_cst_business abo_trade_union_benefit_type, long al_bt_row, string as_include_travel_flag, ref decimal adec_invoice_amount, ref string as_err_msg, long al_employee, decimal adec_retro);
//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_get_union_benefit_invoice_amount
// Author   :	Monica Petersen
// Date     :	2012/08/27
// 	
// Arguments:	n_cst_business abo_pr_cheque
// 				long al_c_row
// 				n_cst_business abo_trade_union_benefit
// 				long al_b_row
// 				n_cst_business abo_trade_union_benefit_type
// 				long al_bt_row
// 				string as_include_travel_flag
// 				decimal adec_invoice_amount
// 				string as_err_msg
// 				long al_employee
// 				decimal adec_retro
// 	
// Returns:		integer
// 	
// Desc:			Called by PRTRAN to create union benefit invoices,
//  				and also by the union remit spreadsheet to itemize amounts per union
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long	ll_e_row

//This will be called in a loop, so only create the business object the first time
IF Not(IsValid(ibo_employee)) THEN
	ibo_employee = CREATE n_bo_employee
END IF

adec_invoice_amount = 0

CHOOSE CASE abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'benefit_source')
		
CASE 'H'
	
	// Pension and RRSP can be overridden by adding a trade level entry, so take the calculated amount
	// rather than re-doing the logic for trade level rates
	IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employer_pays_flag') = 'Y' &
	AND abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'P' THEN

		// Pension
		adec_invoice_amount = abo_pr_cheque.of_GetItemDecimal(al_c_row, 'union_pension')
		
	ELSEIF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employer_pays_flag') = 'Y' &
	AND abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'R' THEN

		// RRSP
		adec_invoice_amount = abo_pr_cheque.of_GetItemDecimal(al_c_row, 'union_rrsp')

	ELSE
		//Hourly amounts 
		adec_invoice_amount = (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'reg_hour') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'regular_rate')) 		&
							  + (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'tah_hour') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'time_and_half_rate')) 	&
							  + (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'ovr_hour') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'overtime_rate')) 
	
		IF as_include_travel_flag = 'Y' THEN
			adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'travel_hour') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'regular_rate')) 
		END IF
	END IF

CASE 'B'
	
	// all hours at 'B'ase rates 
	IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employer_pays_flag') = 'N' &
	AND abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'N' THEN

		// Dues are where the employer pays, and rrsp/pension/Neither is 'N'
		adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'dues_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'base_rate') ) 

	ELSEIF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'R' THEN
		
		//RRSP may require employees to match contributions	
		IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employee_must_contribute_flag') = 'Y' THEN
			ll_e_row = ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
			IF ll_e_row > 0 THEN
				IF ibo_employee.of_GetItemDecimal(ll_e_row, 'employee_rrsp_percent') <> 0 THEN
					adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'rrsp_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'base_rate') ) 
				END IF
			END IF
		ELSE
			adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'rrsp_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'base_rate') ) 
		END IF

	ELSEIF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'P' THEN

		//Pension may require employees to match contributions
		IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employee_must_contribute_flag') = 'Y' THEN
			ll_e_row = ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
			IF ll_e_row > 0 THEN
				IF ibo_employee.of_GetItemDecimal(ll_e_row, 'employee_pension_percent') <> 0 THEN
					adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'pension_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'base_rate') ) 
				END IF
			END IF
		ELSE
			adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'pension_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'base_rate') ) 
		END IF

	ELSE	
		
		// training, administration etc only use types 'E' and 'H'
		//this.of_msg_db_error("Benefit " + abo_trade_union_benefit.of_GetItemString(al_b_row, 'benefit_type') + " is coded incorrectly.  Source 'B' cannot be used for miscellaneous benefits.")
		adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'all_hr_base_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'base_rate') ) 

	END IF

CASE 'E'
	// hourly 'E'arnings by hour type 
	// -------------------------------------------------------------------------
	// This calculation has to go back to the separate earnings by hour types,
	// so, while the 'B','E', 'S' and 'R' types have had travel and vacation 
	// included in dues_source_earn, these ones have to calculate that now.
	// -------------------------------------------------------------------------
	adec_invoice_amount +=((abo_pr_cheque.of_GetItemDecimal(al_c_row, 'reg_earn') + adec_retro) * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'regular_rate') ) 		&
						  + (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'tah_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'time_and_half_rate') )  	&
						  + (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'ovr_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'overtime_rate') ) 

	//		+ if t_u_rate.include_travel_flag = Y then p_c.travel_earn * t_u_b.regular_rate 
	IF as_include_travel_flag = 'Y' THEN
		adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'travel_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'regular_rate') ) 
	END IF

	//		+ if t_u_b_t.include_holiday_earning_flag = Y then (p_c.vacation_earn + statutory_earn) * t_u_b.regular_rate. 
	IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'include_holiday_earning_flag') = 'Y' THEN
		adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'vacation_earn') + abo_pr_cheque.of_GetItemDecimal(al_c_row, 'statutory_earn')) &
									* abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'regular_rate')  
	END IF

CASE 'S'
	
	// 'S'cheduled base earnings	
	IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employer_pays_flag') = 'N' &
	AND abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'N' THEN

		// Dues are where the employer pays, and rrsp/pension/Neither is 'N'
		adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'dues_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'sched_base_rate') ) 

	ELSEIF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'R' THEN

		//RRSP may require employees to match contributions	
		IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employee_must_contribute_flag') = 'Y' THEN
			ll_e_row = ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
			IF ll_e_row > 0 THEN
				IF ibo_employee.of_GetItemDecimal(ll_e_row, 'employee_rrsp_percent') <> 0 THEN
					adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'rrsp_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'sched_base_rate') ) 
				END IF
			END IF
		ELSE
			adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'rrsp_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'sched_base_rate') ) 
		END IF

	ELSEIF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'P' THEN

		//Pension may require employees to match contributions
		IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employee_must_contribute_flag') = 'Y' THEN
			ll_e_row = ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
			IF ll_e_row > 0 THEN
				IF ibo_employee.of_GetItemDecimal(ll_e_row, 'employee_pension_percent') <> 0 THEN
					adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'pension_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'sched_base_rate') ) 
				END IF
			END IF
		ELSE
			adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'pension_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'sched_base_rate') ) 
		END IF


	ELSE	
		
		// training, administration etc only use types 'E' and 'H'
		as_err_msg = "Benefit " + abo_trade_union_benefit.of_GetItemString(al_b_row, 'benefit_type') + " is coded incorrectly.  Source 'S' cannot be used for miscellaneous benefits."
		RETURN -1

	END IF

CASE 'R'
	
	// all hours at 'R'egular rates
	IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employer_pays_flag') = 'N' &
	AND abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'N' THEN

		// Dues are where the employer pays, and rrsp/pension/Neither is 'N'
		adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'dues_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'all_hr_reg_rate') ) 

	ELSEIF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'R' THEN

		//RRSP may require employees to match contributions
		IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employee_must_contribute_flag') = 'Y' THEN
			ll_e_row = ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
			IF ll_e_row > 0 THEN
				IF ibo_employee.of_GetItemDecimal(ll_e_row, 'employee_rrsp_percent') <> 0 THEN
					adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'rrsp_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'all_hr_reg_rate') ) 
				END IF
			END IF
		ELSE
			adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'rrsp_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'all_hr_reg_rate') ) 
		END IF

	ELSEIF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'pension_or_rrsp') = 'P' THEN

		//Pension may require employees to match contributions
		IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'employee_must_contribute_flag') = 'Y' THEN
			ll_e_row = ibo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(al_employee))
			IF ll_e_row > 0 THEN
				IF ibo_employee.of_GetItemDecimal(ll_e_row, 'employee_pension_percent') <> 0 THEN
					adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'pension_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'all_hr_reg_rate') ) 
				END IF
			END IF
		ELSE
			adec_invoice_amount += (abo_pr_cheque.of_GetItemDecimal(al_c_row, 'pension_source_earn') * abo_trade_union_benefit.of_GetItemDecimal(al_b_row, 'all_hr_reg_rate') ) 
		END IF

	ELSE	
		
		// training, administration etc only use types 'E' and 'H'
		as_err_msg = "Benefit " + abo_trade_union_benefit.of_GetItemString(al_b_row, 'benefit_type') + " is coded incorrectly.  Source 'R' cannot be used for miscellaneous benefits."
		RETURN -1

	END IF


END CHOOSE 			//Process Benefit Source

//Rounding should only happen after all the items have been summed, to reduce rounding error. (jira 4875)
IF abo_trade_union_benefit_type.of_GetItemString(al_bt_row, 'benefit_source') <> 'H' THEN
	//changed 2016.09.30 - non hourly earnings need to be rounded so A/P matches P/R
	adec_invoice_amount = Round(adec_invoice_amount, 2)
END IF

RETURN 1

end function

public function integer of_tax_calc_dues_premiums_for_timesheets (n_cst_business abo_timesheet, long ai_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_dues_premium_earn);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_dues_premiums_for_timesheets
// Author   :	Monica Petersen
// Date     :	2017/05/15
// 	
// Arguments:	n_cst_business abo_timesheet
// 				n_cst_business abo_timesheet_premium
// 				n_cst_business abo_trade_union_rate
// 				decimal adec_dues_premium_earn
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

Long	ll_tsp_row, ll_tsp_rows, ll_pt_row

ll_tsp_rows = abo_timesheet_premium.of_RowCount()

FOR ll_tsp_row = 1 TO ll_tsp_rows
	ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + abo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
	IF ll_pt_row > 0 THEN
		//dues
		IF ibo_premium_type.of_GetItemString(ll_pt_row, 'dues_earn_flag') = 'Y' THEN
			adec_dues_premium_earn += abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
										  + (abo_timesheet.of_GetItemDecimal(ai_ts_row, 'tah_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
										  + (abo_timesheet.of_GetItemDecimal(ai_ts_row, 'ovr_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
		END IF
	END IF
NEXT

RETURN 1
end function

public function integer of_tax_calc_pension_premiums_for_ts (n_cst_business abo_timesheet, long ai_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_pension_premium_earn);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_pension_premiums_for_ts
// Author   :	Monica Petersen
// Date     :	2017/05/15
// 	
// Arguments:	n_cst_business abo_timesheet
// 				long ai_ts_row
// 				n_cst_business abo_timesheet_premium
// 				n_cst_business abo_trade_union_rate
// 				decimal adec_pension_premium_earn
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

Long	ll_tsp_row, ll_tsp_rows, ll_pt_row

ll_tsp_rows = abo_timesheet_premium.of_RowCount()

FOR ll_tsp_row = 1 TO ll_tsp_rows
	ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + abo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
	IF ll_pt_row > 0 THEN
		//Pension
		IF ibo_premium_type.of_GetItemString(ll_pt_row, 'pension_earn_flag') = 'Y' THEN
			adec_pension_premium_earn += abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
										  + (abo_timesheet.of_GetItemDecimal(ai_ts_row, 'tah_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
										  + (abo_timesheet.of_GetItemDecimal(ai_ts_row, 'ovr_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
		END IF
	END IF
NEXT

RETURN 1
end function

public function integer of_tax_calc_premiums_for_timesheets (n_cst_business abo_timesheet, long al_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_dues_premium_earn, ref decimal adec_rrsp_premium_earn, ref decimal adec_pension_premium_earn);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_premiums_for_timesheets
// Author   :	Monica Petersen
// Date     :	2017/05/15
// 	
// Arguments:	n_cst_business abo_timesheet
// 				long al_ts_row
// 				n_cst_business abo_timesheet_premium
// 				n_cst_business abo_trade_union_rate
// 				decimal adec_dues_premium_earn
// 				decimal adec_rrsp_premium_earn
// 				decimal adec_pension_premium_earn
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

Long	ll_tsp_row, ll_tsp_rows, ll_pt_row

ll_tsp_rows = abo_timesheet_premium.of_RowCount()

FOR ll_tsp_row = 1 TO ll_tsp_rows
	ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + abo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
	IF ll_pt_row > 0 THEN
		//dues
		IF ibo_premium_type.of_GetItemString(ll_pt_row, 'dues_earn_flag') = 'Y' THEN
			adec_dues_premium_earn += abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
		END IF
	
		//RRSP
		IF ibo_premium_type.of_GetItemString(ll_pt_row, 'rrsp_earn_flag') = 'Y' THEN
			adec_rrsp_premium_earn += abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
		END IF
		//Pension
		IF ibo_premium_type.of_GetItemString(ll_pt_row, 'pension_earn_flag') = 'Y' THEN
			adec_pension_premium_earn += abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
		END IF
	END IF
NEXT

RETURN 1
end function

public function integer of_tax_calc_rrsp_premiums_for_timesheets (n_cst_business abo_timesheet, long al_ts_row, n_cst_business abo_timesheet_premium, n_cst_business abo_trade_union_rate, ref decimal adec_rrsp_premium_earn);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_rrsp_premiums_for_timesheets
// Author   :	Monica Petersen
// Date     :	2017/05/15
// 	
// Arguments:	n_cst_business abo_timesheet
// 				long al_ts_row
// 				n_cst_business abo_timesheet_premium
// 				n_cst_business abo_trade_union_rate
// 				decimal adec_rrsp_premium_earn
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

Long	ll_tsp_row, ll_tsp_rows, ll_pt_row


ll_tsp_rows = abo_timesheet_premium.of_RowCount()

FOR ll_tsp_row = 1 TO ll_tsp_rows
	ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + abo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
	IF ll_pt_row > 0 THEN
		//RRSP
		IF ibo_premium_type.of_GetItemString(ll_pt_row, 'rrsp_earn_flag') = 'Y' THEN
			adec_rrsp_premium_earn += abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
										  + (abo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * abo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
		END IF
	END IF
NEXT

RETURN 1
end function

public function integer of_tax_calc_roll_up (n_cst_business abo_pr_ck, ref n_cst_business abo_pr_ck_trade_union, ref n_cst_business abo_pr_ck_occupation);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_roll_up
// Author   :	Monica Petersen
// Date     :	2017/05/16
// 	
// Arguments:	n_cst_business abo_pr_ck
// 				n_cst_business abo_pr_ck_trade_union
// 				n_cst_business abo_pr_ck_occupation
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

Long	ll_ctu_row, ll_cto_row

IF abo_pr_ck_trade_union.of_RowCount() > 0 THEN
	//Initialize the cheque amounts
	abo_pr_ck.of_SetItem(1, 'pension_source_earn', 	0)
	abo_pr_ck.of_SetItem(1, 'rrsp_source_earn', 		0)
	abo_pr_ck.of_SetItem(1, 'dues_source_earn', 		0)
	abo_pr_ck.of_SetItem(1, 'vacation_source_earn', 0)
	abo_pr_ck.of_SetItem(1, 'statutory_source_earn',0)
	abo_pr_ck.of_SetItem(1, 'employee_pension', 		0)
	abo_pr_ck.of_SetItem(1, 'union_pension', 			0)
	abo_pr_ck.of_SetItem(1, 'union_rrsp', 				0)
	abo_pr_ck.of_SetItem(1, 'union_rrsp_paid_out', 	0)
	abo_pr_ck.of_SetItem(1, 'employer_rrsp_paid_out',0)
	abo_pr_ck.of_SetItem(1, 'union_dues', 				0)
	abo_pr_ck.of_SetItem(1, 'union_remittance', 		0)
	abo_pr_ck.of_SetItem(1, 'add_to_union_remittance',0)
	abo_pr_ck.of_SetItem(1, 'vacation_earn', 			0)
	abo_pr_ck.of_SetItem(1, 'vacation_paid_to_union',0)
	abo_pr_ck.of_SetItem(1, 'statutory_earn', 		0)
	abo_pr_ck.of_SetItem(1, 'statutory_paid_to_union',0)
END IF

//Now sum up the occupation amounts into their parent trade union
FOR ll_ctu_row = 1 TO abo_pr_ck_trade_union.of_RowCount()
	
//	IF abo_pr_ck_occupation.of_RowCount() > 0 THEN
//		abo_pr_ck_trade_union.of_SetItem(ll_ctu_row, 'union_pension', 			0)
//		abo_pr_ck_trade_union.of_SetItem(ll_ctu_row, 'union_rrsp', 				0)
//	END IF
	
	//Roll up the occupations into the trade union
	FOR ll_cto_row = 1 TO abo_pr_ck_occupation.of_RowCount()
		IF  abo_pr_ck_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
		  = abo_pr_ck_occupation.of_GetItemString(ll_cto_row, 'trade_union') &
		AND abo_pr_ck_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date') &
		  = abo_pr_ck_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date') THEN
			 abo_pr_ck_trade_union.of_SetItem(ll_ctu_row, 'union_pension', &
															abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_pension') &
														+ 	abo_pr_ck_occupation.of_GetItemDecimal(ll_cto_row, 'union_pension') )
			 abo_pr_ck_trade_union.of_SetItem(ll_ctu_row, 'union_rrsp', &
															abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_rrsp') &
														+ 	abo_pr_ck_occupation.of_GetItemDecimal(ll_cto_row, 'union_rrsp') )
			 abo_pr_ck_trade_union.of_SetItem(ll_ctu_row, 'employee_rrsp', &
															abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'employee_rrsp') &
														+ 	abo_pr_ck_occupation.of_GetItemDecimal(ll_cto_row, 'employee_rrsp') )
			 
			 abo_pr_ck_trade_union.of_SetItem(ll_ctu_row, 'add_to_union_remittance', &
															abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'add_to_union_remittance') &
														+ 	abo_pr_ck_occupation.of_GetItemDecimal(ll_cto_row, 'add_to_union_remittance') )

		END IF
	NEXT
	

	//And roll up the trade union amounts into the parent cheque
			
	//employee RRSP is rolled up differently for staff
	IF ibo_trade_union_this_tu.of_Retrieve(&
						  "book = '" + gnv_app.is_book &
				+ "' AND trade_union = '" + abo_pr_ck_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') + "'") = 1 THEN
		IF ibo_trade_union_this_tu.of_GetItemString(1, 'staff_flag') = 'Y' THEN
			abo_pr_ck.of_SetItem(1, 'employee_rrsp', &
										abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') &
									+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'employee_rrsp')) 
		ELSE
			abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', &
										abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') &
									+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'employee_rrsp')) 
		END IF
	END IF
	
	//It was getting crazy tracking the different levels of rrsp and pension, so they've been separated out until now
	abo_pr_ck_trade_union.of_SetItem(ll_ctu_row, 'union_remittance', &
								abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_remittance') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'add_to_union_remittance') )
				
	abo_pr_ck.of_SetItem(1, 'pension_source_earn', &
								abo_pr_ck.of_GetItemDecimal(1, 'pension_source_earn') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'pension_source_earn') )
	abo_pr_ck.of_SetItem(1, 'rrsp_source_earn', &
								abo_pr_ck.of_GetItemDecimal(1, 'rrsp_source_earn') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'rrsp_source_earn') )
	abo_pr_ck.of_SetItem(1, 'dues_source_earn', &
								abo_pr_ck.of_GetItemDecimal(1, 'dues_source_earn') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'dues_source_earn') )
	abo_pr_ck.of_SetItem(1, 'vacation_source_earn', &
								abo_pr_ck.of_GetItemDecimal(1, 'vacation_source_earn') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'vacation_source_earn') )
	abo_pr_ck.of_SetItem(1, 'statutory_source_earn', &
								abo_pr_ck.of_GetItemDecimal(1, 'statutory_source_earn') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'statutory_source_earn') )
	abo_pr_ck.of_SetItem(1, 'employee_pension', &
								abo_pr_ck.of_GetItemDecimal(1, 'employee_pension') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'employee_pension') )
	abo_pr_ck.of_SetItem(1, 'union_pension', &
								abo_pr_ck.of_GetItemDecimal(1, 'union_pension') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_pension') )
	abo_pr_ck.of_SetItem(1, 'union_rrsp', &
								abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_rrsp') )
	abo_pr_ck.of_SetItem(1, 'union_rrsp_paid_out', &
								abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp_paid_out') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_rrsp_paid_out') )
	abo_pr_ck.of_SetItem(1, 'employer_rrsp_paid_out', &
								abo_pr_ck.of_GetItemDecimal(1, 'employer_rrsp_paid_out') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'employer_rrsp_paid_out') )
	abo_pr_ck.of_SetItem(1, 'union_remittance', &
								abo_pr_ck.of_GetItemDecimal(1, 'union_remittance') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_remittance') )
	abo_pr_ck.of_SetItem(1, 'add_to_union_remittance', &
								abo_pr_ck.of_GetItemDecimal(1, 'add_to_union_remittance') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'add_to_union_remittance') )
	abo_pr_ck.of_SetItem(1, 'union_dues', &
								abo_pr_ck.of_GetItemDecimal(1, 'union_dues') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_dues') )
	abo_pr_ck.of_SetItem(1, 'vacation_earn', &
								abo_pr_ck.of_GetItemDecimal(1, 'vacation_earn') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'vacation_earn') )
	abo_pr_ck.of_SetItem(1, 'vacation_paid_to_union', &
								abo_pr_ck.of_GetItemDecimal(1, 'vacation_paid_to_union') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'vacation_paid_to_union') )
	abo_pr_ck.of_SetItem(1, 'statutory_earn', &
								abo_pr_ck.of_GetItemDecimal(1, 'statutory_earn') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'statutory_earn') )
	abo_pr_ck.of_SetItem(1, 'statutory_paid_to_union', &
								abo_pr_ck.of_GetItemDecimal(1, 'statutory_paid_to_union') &
							+ 	abo_pr_ck_trade_union.of_GetItemDecimal(ll_ctu_row, 'statutory_paid_to_union') )
NEXT

	
RETURN 1
end function

public function integer of_tax_calc_rrsp_employer (ref n_cst_business abo_pr_ck, ref n_cst_business abo_pr_cheque_trade_union, ref n_cst_business abo_pr_cheque_occupation, ref n_ds ads_msg, decimal adec_rrsp_premium_earn, date ad_last_day_of_pp, string as_mode, boolean ab_over_71);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_rrsp_employer
// Author   :	Monica Petersen
// Date     :	2017/08/28
// 	
// Arguments:	n_cst_business abo_pr_ck
// 				n_cst_business abo_pr_cheque_trade_union
// 				n_cst_business abo_pr_cheque_occupation
// 				n_ds ads_msg
// 				decimal adec_rrsp_premium_earn
// 				date ad_last_day_of_pp
// 				string as_mode
// 				boolean ab_over_71
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

String	ls_retrieve, ls_trade_union, ls_occupation
Long		ll_ctu_row, ll_ctu_rows, ll_ts_row, ll_ts_rows, ll_cto_row, ll_cto_rows
Decimal ldec_rrsp_premium_earn_this_tu, ldec_all_hr_base_earn

//calculate employer and union rrsp for the cheque and also
//for multiple unions on the cheque
of_tax_calc_rrsp_employer_pct_by_union(abo_pr_ck, 1, &
						  ibo_trade_union, &
						  ibo_trade_union_rate, &
						  adec_rrsp_premium_earn, &
						  abo_pr_ck.of_GetItemDecimal(1, 'all_hr_base_earn'), &
						  ads_msg, &
						  as_mode, &
						  ad_last_day_of_pp, &
						  ab_over_71, &
						  abo_pr_ck.of_GetItemDecimal(1, 'retro'), &
						  abo_pr_ck.of_GetItemDecimal(1, 'taxable_site_allow'), &
						  abo_pr_ck.of_GetItemDecimal(1, 'nontaxable_site_allow'))

IF ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
	//jira 3307 - allow user to override employer RRSP, so only recalculate during approval process
	IF as_mode = 'approve' THEN
		abo_pr_ck.of_SetItem(1, 'employer_rrsp', 						&
					round(  ibo_employee.of_GetItemDecimal (1, "employer_rrsp_percent") * .01 &
							* abo_pr_ck.of_GetItemDecimal(1, 'rrsp_source_earn')  , 2)) 
		abo_pr_ck.of_SetItem(1, 'union_rrsp', 0)
	END IF
ELSE

	//Non staff get RRSPs from their union, so the value is stored in the union_rrsp field rather than the employer_rrsp field
	abo_pr_ck.of_SetItem(1, 'employer_rrsp', 0)

	//we need to find the occupation associated with the cheque face ****
	
	//Look up the apprenticeship rates for the trade union/occupation 
	ls_trade_union = abo_pr_ck.of_GetItemString(1, 'trade_union')
	ll_cto_row = abo_pr_cheque_occupation.of_Find("trade_union = '" + ls_trade_union + "'")
	IF ll_cto_row > 0 THEN
		ls_occupation = abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'occupation')
	ELSE
		IF ibo_timesheet.of_retrieve("book = '" + gnv_app.is_book &
												+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))) < 1 THEN
			of_msg_db_error("Error getting max occupation")
			RETURN -1
		ELSE
			ibo_timesheet.of_SetSort("occupation desc")
			ibo_timesheet.of_Sort()
			ls_occupation = ibo_timesheet.of_GetItemString(1, 'occupation')
		END IF
	END IF
	
	//on the cheque face, and set union_rrsp on the cheque
	of_tax_calc_rrsp_employer_hourly_by_occ(abo_pr_ck, &
						  1, &
						  ibo_trade_union, &
						  ibo_trade_union_rate, &
						  ad_last_day_of_pp, &
						  ads_msg,&
						  ls_trade_union,&
						  ls_occupation)

END IF

//get JUST the union RRSP hourly amounts by occupation
ll_cto_rows = abo_pr_cheque_occupation.of_RowCount()
IF ll_cto_rows > 0 THEN
	
	FOR ll_cto_row = 1 TO abo_pr_cheque_occupation.of_RowCount()

		IF ibo_trade_union_rate_this_ts_or_tu.of_Retrieve(&
													  "book = '" + gnv_app.is_book &
											+ "' AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') &
											+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN
			IF ibo_trade_union_this_tu.of_Retrieve(&
														  "book = '" + gnv_app.is_book &
												+ "' AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') + "'") = 1 THEN
				IF ibo_trade_union_this_tu.of_GetItemString(1, 'staff_flag') <> 'Y' THEN
					of_tax_calc_rrsp_employer_hourly_by_occ(abo_pr_cheque_occupation, &
										  ll_cto_row, &
										  ibo_trade_union_this_tu, &
										  ibo_trade_union_rate_this_ts_or_tu, &
										  Date(abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date')), &
										  ads_msg,&
										  abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union'),&
										  abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'occupation'))
										  
				END IF	
			END IF
		END IF							  
	NEXT
END IF
						
//Now calculate rrsp percents for each trade union
ll_ctu_rows = abo_pr_cheque_trade_union.of_RowCount()
IF ll_ctu_rows > 0 THEN

	//Sort by work date so we can select timesheets within
	//the union rate effective date range
	abo_pr_cheque_trade_union.of_SetSort("trade_union ASC, union_rate_effective_date ASC")
	abo_pr_cheque_trade_union.of_Sort()

	FOR ll_ctu_row = 1 TO ll_ctu_rows
		IF ibo_trade_union_this_tu.of_Retrieve(&
													  "book = '" + gnv_app.is_book &
											+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') + "'") = 1 THEN
			IF ibo_trade_union_rate_this_ts_or_tu.of_Retrieve(&
														  "book = '" + gnv_app.is_book &
												+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
												+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN

				//======================
				//also need to extract the rrsp premiums that apply to this trade union only
				ldec_rrsp_premium_earn_this_tu = 0
				ldec_all_hr_base_earn = 0
				
				//We need to get *ONLY* the timesheets for the union rate effective on the record
				ls_retrieve = "book = '" + gnv_app.is_book &
							+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) &
							+ "  AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') + "'"
				
				ls_retrieve += " AND Convert(Varchar, work_date, 112) >= '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'" 
	
				IF ll_ctu_rows > ll_ctu_row THEN
					IF abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
					= abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row + 1, 'trade_union') THEN
						IF abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date') &
						<> abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row + 1, 'union_rate_effective_date') THEN
							ls_retrieve += " AND Convert(Varchar, work_date, 112) < '"  + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row + 1, 'union_rate_effective_date'), 'YYYYMMDD') + "'"
						END IF
					END IF
				END IF
	
				ll_ts_rows = ibo_timesheet_this_tu.of_Retrieve(ls_retrieve)
						
				IF ll_ts_rows = 0 THEN
					this.of_prcent_err("RRSP: Can't find timesheets for trade union " + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
												+ " effective " 	+ String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') &
												+ " for cheque " 	+ String(abo_pr_cheque_trade_union.of_GetItemNumber(ll_ctu_row, 'cheque_no')), &
												abo_pr_cheque_trade_union.of_GetItemNumber(ll_ctu_row, 'cheque_no'), ads_msg)
					RETURN -1
				END IF

				FOR ll_ts_row = 1 TO ll_ts_rows
					
					//Read premiums for current timesheet	
					ibo_timesheet_premium.of_Retrieve("book = '" + gnv_app.is_book								&
									+ "' AND employee = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'employee')) 	&
									+ "  AND work_date = '" + String(ibo_timesheet_this_tu.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') &
									+ "' AND timesheet_item = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'timesheet_item')))
					
					//accumulate premiums for this timesheet
					of_tax_calc_rrsp_premiums_for_timesheets(ibo_timesheet_this_tu, ll_ts_row, &
																	ibo_timesheet_premium, 	&
																	ibo_trade_union_rate_this_ts_or_tu, 	&
																	ldec_rrsp_premium_earn_this_tu)
		
					//While we're in the timesheets, we need all hrs base earn for the set of timesheets with this occupation
					ldec_all_hr_base_earn += Round(&
									 (ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'reg_hour')  		&
									+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'tah_hour')  	&
									+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'ovr_hour')  	&
									+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'travel_hour')) 	&
								* ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'base_rate'), 2)
				NEXT
				//======================
	
				of_tax_calc_rrsp_employer_pct_by_union(abo_pr_cheque_trade_union, ll_ctu_row, &
										  ibo_trade_union_this_tu, &
										  ibo_trade_union_rate_this_ts_or_tu, &
										  ldec_rrsp_premium_earn_this_tu, &
										  ldec_all_hr_base_earn, &
										  ads_msg, &
										  as_mode, &
										  ad_last_day_of_pp, &
										  ab_over_71, &
										  0 /*no retro*/, &
										  0 /*no taxable site allowance*/, &
										  0 /*no nontaxable site allowance*/)
										  
			END IF
		END IF
			
	NEXT
END IF

RETURN 1
end function

public function integer of_tax_calc_rrsp_employee (ref n_cst_business abo_pr_ck, n_cst_business abo_trade_union, n_cst_business abo_trade_union_rate, decimal adec_rrsp_premium_earn, n_ds ads_msg);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_rrsp_employee
// Author   :	Monica Petersen
// Date     :	2017/05/18
// 	
// Arguments:	n_cst_business abo_pr_ck
// 				n_cst_business abo_trade_union
// 				n_cst_business abo_trade_union_rate
// 				decimal adec_rrsp_premium_earn
// 				n_ds ads_msg
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

Decimal	ldec_hours, ldec_rrsp
Long		ll_msg_row

//RRSP contributions stipulated by the union
IF abo_trade_union_rate.of_GetItemString(1, 'employee_pension_or_rrsp') = 'R' THEN 
	
	ldec_hours = abo_pr_ck.of_GetItemDecimal(1, 'reg_hour')
	IF abo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours += abo_pr_ck.of_GetItemDecimal(1, 'travel_hour') //jira 1652

	//RRSP based on hourly amounts set out in trade union rate
	ldec_RRSP = round(ldec_hours * abo_trade_union_rate.of_GetItemDecimal(1, 'dues_pen_reg_hr') &
								+ abo_pr_ck.of_GetItemDecimal(1, 'tah_hour') * abo_trade_union_rate.of_GetItemDecimal(1, 'dues_pen_tah_hr') 														&
								+ abo_pr_ck.of_GetItemDecimal(1, 'ovr_hour') * abo_trade_union_rate.of_GetItemDecimal(1, 'dues_pen_ovr_hr'), 2)
	
	//jira 600 - record pension against union liability account for non-staff
	IF abo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
		abo_pr_ck.of_SetItem(1, 'employee_rrsp', ldec_RRSP) 
	ELSE
		abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', ldec_RRSP) 
	END IF	
		
END IF

//RRSP the employee chooses to contribute to
IF ibo_employee.of_GetItemDecimal(1, "employee_rrsp_percent") <> 0 THEN 
	IF abo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
		
		//Staff can just have an RRSP amount, it will get paid to their RRSP vendor
		//on their behalf when the cheques are transacted (A/P invoice will be generated)
		abo_pr_ck.of_SetItem(1, 'employee_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'employee_rrsp') &
				+ Round((abo_pr_ck.of_GetItemDecimal(1, 'all_hr_base_earn') + adec_rrsp_premium_earn)   &
					* ibo_employee.of_GetItemDecimal(1, "employee_rrsp_percent") * 0.01, 2))
					
	ELSE
		//Non-staff employees can contribute to their RRSP via their union
		//When cheques are transacted, and A/P Invoice will be created for this employee and amount
		//for the union's RRSP vendor
		
		//1136 Before moving money to incentive_paid_to_rrsp, make sure the union has a RRSP set up
		IF abo_trade_union_rate.of_GetItemString(1, 'employee_pension_or_rrsp') = 'R' &
		OR abo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'B' &
		OR abo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'R' THEN

			abo_pr_ck.of_SetItem(1, 'incentive_paid_to_rrsp', abo_pr_ck.of_GetItemDecimal(1, 'incentive_paid_to_rrsp') &
					+ Round((abo_pr_ck.of_GetItemDecimal(1, 'all_hr_base_earn') + adec_rrsp_premium_earn) &
						* ibo_employee.of_GetItemDecimal(1, "employee_rrsp_percent") * 0.01, 2))
		ELSE
			ll_msg_row = ads_msg.InsertRow(0)
			ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))
			ads_msg.SetItem(ll_msg_row, 'message', "Employee: " + String(abo_pr_ck.of_GetItemNumber(1, 'employee')) &
				+ ", cannot add employee RRSP percentage to RRSP, union " &
				+ abo_pr_ck.of_GetItemString(1, 'trade_union') + " isn't setup for RRSP.")
		END IF
	END IF
END IF

RETURN 1
end function

public function integer of_tax_calc_pension_employee (ref n_cst_business abo_pr_ck, n_cst_business abo_trade_union_rate, ref n_cst_business abo_pr_cheque_trade_union, n_cst_business abo_trade_union_rate_this_ts_or_tu, decimal adec_rrsp_premium, ref n_ds ads_msg);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_employee_pension
// Author   :	Monica Petersen
// Date     :	2017/05/16
// 	
// Arguments:	n_cst_business abo_pr_ck
// 				n_cst_business abo_pr_cheque_trade_union
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

Long		ll_ctu_row, ll_ctu_rows
Decimal	ldec_rrsp_premium

//calculate employee pension for the cheque and also
//for multiple unions on the cheque

of_tax_calc_pension_employee_by_union(abo_pr_ck, &
											  1, &
											  abo_trade_union_rate, &
											  adec_rrsp_premium, &
											  ads_msg)

//and now run calculations for each trade union/occupation
ll_ctu_rows = abo_pr_cheque_trade_union.of_RowCount()
FOR ll_ctu_row = 1 TO ll_ctu_rows
	
	// lookup trade union settings FOR THIS TRADE UNION
	IF abo_trade_union_rate_this_ts_or_tu.of_Retrieve(&
												  "book = '" + gnv_app.is_book &
										+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
										+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN
		
		of_tax_calc_pension_employee_by_union(abo_pr_cheque_trade_union, &
													  ll_ctu_row, &
													  abo_trade_union_rate_this_ts_or_tu, &
													  ldec_rrsp_premium, &
													  ads_msg)
							  
	END IF
NEXT
	
RETURN 1
end function

public function integer of_tax_calc_pension_employee_by_union (ref n_cst_business abo_pr_ck_or_tu, long al_ck_row, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_rrsp_premium_earn, ref n_ds ads_msg);
//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_employee_pension_by_union
// Author   :	Monica Petersen
// Date     :	2017/05/18
// 	
// Arguments:	n_cst_business abo_pr_ck_or_tu
// 				long al_ck_row
// 				n_cst_business abo_trade_union_rate_this_tu
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

Long	ldec_hours, ll_msg_row

CHOOSE CASE abo_trade_union_rate_this_tu.of_GetItemString(1, 'employee_pension_or_rrsp')

	//employee pension 
	CASE 'P'
		ldec_hours = abo_pr_ck_or_tu.of_GetItemDecimal(1, 'reg_hour')
		IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours += abo_pr_ck_or_tu.of_GetItemDecimal(al_ck_row, 'travel_hour') //jira 1652
		
		//Pension based on hourly amounts set out in the trade union rates
		abo_pr_ck_or_tu.of_SetItem(al_ck_row, 'employee_pension',  &
					round(ldec_hours * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_pen_reg_hr') &
							+ abo_pr_ck_or_tu.of_GetItemDecimal(al_ck_row, 'tah_hour') * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_pen_tah_hr') &
							+ abo_pr_ck_or_tu.of_GetItemDecimal(al_ck_row, 'ovr_hour') * abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'dues_pen_ovr_hr'), 2))
																							
END CHOOSE

//jira 1899 employee pension percent
IF ibo_employee.of_GetItemDecimal(1, "employee_pension_percent") <> 0 THEN
	IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'P' &
	OR abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'B' THEN
		abo_pr_ck_or_tu.of_SetItem(al_ck_row, 'employee_pension', abo_pr_ck_or_tu.of_GetItemDecimal(al_ck_row, 'employee_pension') &
				+ Round((abo_pr_ck_or_tu.of_GetItemDecimal(al_ck_row, 'all_hr_base_earn') + adec_rrsp_premium_earn)   * ibo_employee.of_GetItemDecimal(1, "employee_pension_percent") * 0.01, 2))
	ELSE
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck_or_tu.of_GetItemNumber(1, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "Cannot add employee pension percentage to dues pension, union " &
			+ abo_pr_ck_or_tu.of_GetItemString(al_ck_row, 'trade_union') + " isn't setup for pension.")
	END IF
END IF

RETURN 1
end function

public function integer of_tax_calc_pension_employer (ref n_cst_business abo_pr_ck, ref n_cst_business abo_pr_cheque_trade_union, ref n_cst_business abo_pr_cheque_occupation, decimal adec_pension_premium_earn, n_ds ads_msg, string as_mode, date ad_last_day_of_pp, boolean ab_over_71);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_pension_employer
// Author   :	Monica Petersen
// Date     :	2017/05/15
// 	
// Arguments:	n_cst_business abo_pr_ck
// 				n_cst_business abo_pr_cheque_trade_union
// 				n_cst_business abo_pr_cheque_occupation
// 				decimal adec_pension_premium_earn
// 				n_ds ads_msg
// 				string as_mode
// 				date ad_last_day_of_pp
// 				boolean ab_over_71
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

String	ls_retrieve, ls_trade_union, ls_occupation
Long		ll_ctu_row, ll_ctu_rows, ll_ts_row, ll_ts_rows, ll_cto_row, ll_cto_rows, ll_tu_row
Decimal ldec_pension_premium_earn_this_tu, ldec_all_hr_base_earn
decimal ldec_pension_source_earn
decimal ldec_union_pension_paid_out

//For the cheque face, use the trade levels for the occupation worked for the cheque's trade union
ls_trade_union = abo_pr_ck.of_GetItemString(1, 'trade_union')
ll_cto_row = abo_pr_cheque_occupation.of_Find("trade_union = '" + ls_trade_union + "'")
IF ll_cto_row > 0 THEN
	ls_occupation = abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'occupation')
ELSE
	IF ibo_timesheet.of_retrieve("book = '" + gnv_app.is_book &
											+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no'))) < 1 THEN
		of_msg_db_error("Error getting max occupation")
		RETURN -1
	ELSE
		ibo_timesheet.of_SetSort("occupation desc")
		ibo_timesheet.of_Sort()
		ls_occupation = ibo_timesheet.of_GetItemString(1, 'occupation')
	END IF
				
END IF
	
IF ibo_occupation.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND trade_union = '" + ls_trade_union &
							 + "' AND occupation = '" + ls_occupation + "'") < 1 THEN
	this.of_prcent_err("Can't find union " + ls_trade_union + "/" + ls_occupation + " for cheque " &
								+ String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')), abo_pr_ck.of_GetItemNumber(1, 'cheque_no'), ads_msg)
	RETURN -1
END IF

//calculate employer and union pension for the cheque and also
//for multiple unions on the cheque
of_tax_calc_pension_employer_by_union(abo_pr_ck, &
						  1, &
						  ibo_trade_union_rate, &
						  adec_pension_premium_earn, &
						  ads_msg, &
						  as_mode, &
						  ad_last_day_of_pp, &
						  ab_over_71, &
						  abo_pr_ck.of_GetItemDecimal(1, 'all_hr_base_earn'), &
						  ldec_pension_source_earn, &
						  ldec_union_pension_paid_out)
abo_pr_ck.of_SetItem(1, 'pension_source_earn', ldec_pension_source_earn)
abo_pr_ck.of_SetItem(1, 'union_rrsp_paid_out', abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp_paid_out') + ldec_union_pension_paid_out)

//Do the occupation level amounts separately, because we won't be doing that for trade unions
//lest they be double counted
of_tax_calc_pension_employer_by_occ(abo_pr_ck, &
					  1, &
					  ibo_trade_union_rate, &
					  ad_last_day_of_pp, &
					  ads_msg, &
					  ldec_union_pension_paid_out)
abo_pr_ck.of_SetItem(1, 'union_rrsp_paid_out', abo_pr_ck.of_GetItemDecimal(1, 'union_rrsp_paid_out') + ldec_union_pension_paid_out)

//Sort by union rate date so we can select timesheets within
//the union rate effective date range
abo_pr_cheque_trade_union.of_SetSort("trade_union ASC, union_rate_effective_date ASC")
abo_pr_cheque_trade_union.of_Sort()

ll_ctu_rows = abo_pr_cheque_trade_union.of_RowCount()
FOR ll_ctu_row = 1 TO ll_ctu_rows
	
	// lookup trade union settings FOR THIS TRADE UNION
	IF ibo_trade_union_rate_this_ts_or_tu.of_Retrieve(&
												  "book = '" + gnv_app.is_book &
										+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
										+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN
		
		//also need to extract the pension premiums that apply to this trade union only
		ldec_pension_premium_earn_this_tu = 0
		
		//We need to get *ONLY* the timesheets for the union rate effective on the record
		ls_retrieve = "book = '" + gnv_app.is_book &
					+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) &
					+ "  AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') + "'" 
		
		ls_retrieve += " AND Convert(Varchar, work_date, 112) >= '" + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'" 

		IF ll_ctu_row < ll_ctu_rows THEN
			IF abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
			= abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row + 1, 'trade_union') THEN
				IF abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date') &
				<> abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row + 1, 'union_rate_effective_date') THEN
					ls_retrieve += " AND Convert(Varchar, work_date, 112) < '"  + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row + 1, 'union_rate_effective_date'), 'YYYYMMDD') + "'"
				END IF
			END IF
		END IF

		ll_ts_rows = ibo_timesheet_this_tu.of_Retrieve(ls_retrieve)
		
		IF ll_ts_rows = 0 THEN
			this.of_prcent_err("Pension: Can't find timesheets for trade union " + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
										+ " effective " 	+ String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date'), 'YYYYMMDD')&
										+ " for cheque " 	+ String(abo_pr_cheque_trade_union.of_GetItemNumber(ll_ctu_row, 'cheque_no')), &
										abo_pr_cheque_trade_union.of_GetItemNumber(ll_ctu_row, 'cheque_no'), ads_msg)
			RETURN -1
		END IF
				
		ldec_all_hr_base_earn = 0
		FOR ll_ts_row = 1 TO ll_ts_rows
			
			//Read premiums for current timesheet	
			ibo_timesheet_premium.of_Retrieve("book = '" + gnv_app.is_book								&
							+ "' AND employee = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'employee')) 	&
							+ "  AND work_date = '" + String(ibo_timesheet_this_tu.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') &
							+ "' AND timesheet_item = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'timesheet_item')))
			
			//accumulate premiums for this timesheet
			of_tax_calc_pension_premiums_for_ts(ibo_timesheet_this_tu, ll_ts_row, &
															ibo_timesheet_premium, 	&
															ibo_trade_union_rate_this_ts_or_tu, 	&
															ldec_pension_premium_earn_this_tu)

			//While we're in the timesheets, we need all hrs base earn for the set of timesheets with this trade_union
			ldec_all_hr_base_earn += Round(&
							 (ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'reg_hour')  		&
							+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'tah_hour')  	&
							+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'ovr_hour')  	&
							+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'travel_hour')) 	&
						* ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'base_rate'), 2)
		NEXT

		//At the trade union level, use the employee's trade union/occupation because we don't have occupation on this record.
		//We will have to roll the occupation level union_pension field into this field in order
		//to capture the granularity of occupation based trade levels.
		IF ibo_occupation.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND trade_union = '" + ibo_employee.of_GetItemString(1, 'trade_union') &
							 + "' AND occupation = '" + ibo_employee.of_GetItemString(1, 'occupation') + "'") < 1 THEN
			this.of_prcent_err("Can't find union " + abo_pr_cheque_trade_union.of_GetItemString(ll_ctu_row, 'trade_union') &
										+ " for cheque " 	+ String(abo_pr_cheque_trade_union.of_GetItemNumber(ll_ctu_row, 'cheque_no')), &
										abo_pr_cheque_trade_union.of_GetItemNumber(ll_ctu_row, 'cheque_no'), ads_msg)
			RETURN -1
		END IF

		//Initialize these because they're reference variables and they
		//were previously populated with the parent cheque's values		
		ldec_pension_source_earn = 0
		ldec_union_pension_paid_out = 0
		
		of_tax_calc_pension_employer_by_union(abo_pr_cheque_trade_union, &
							  ll_ctu_row, &
							  ibo_trade_union_rate_this_ts_or_tu, &
							  ldec_pension_premium_earn_this_tu, &
							  ads_msg, &
							  as_mode, &
							  Date(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_ctu_row, 'union_rate_effective_date')), &
							  ab_over_71, &
							  ldec_all_hr_base_earn, &
							  ldec_pension_source_earn, &
							  ldec_union_pension_paid_out)
							  
		//Record returned values to parent trade union record
		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'pension_source_earn', ldec_pension_source_earn)
		
		//pension and RRSP both go into this field when they are paid out, i.e.
		//RRSP is automatically paid out when the employee is over 71, 
		//and the employee can elect to have their pension paid out via the 'pay_pension_to_cash_flag'
//		abo_pr_cheque_trade_union.of_SetItem(ll_ctu_row, 'union_rrsp_paid_out', &
//					abo_pr_cheque_trade_union.of_GetItemDecimal(ll_ctu_row, 'union_rrsp_paid_out') + ldec_union_pension_paid_out)
		//========SET THIS VALUE FROM THE OCCUPATION PROCESSING BELOW================//
	END IF
NEXT
	

//and now run calculations for each trade union/occupation
ll_cto_rows = abo_pr_cheque_occupation.of_RowCount()
IF ll_cto_rows > 0 THEN
	
	//Sort by work date so we can select timesheets within
	//the union rate effective date range
	abo_pr_cheque_occupation.of_SetSort("trade_union ASC, occupation ASC, union_rate_effective_date ASC")
	abo_pr_cheque_occupation.of_Sort()

	FOR ll_cto_row = 1 TO abo_pr_cheque_occupation.of_RowCount()

		// lookup trade union settings FOR THIS TRADE UNION
		IF ibo_trade_union_rate_this_ts_or_tu.of_Retrieve(&
													  "book = '" + gnv_app.is_book &
											+ "' AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') &
											+ "' AND Convert(Varchar, effective_date, 112) = '" + String(abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'") = 1 THEN
			//also need to extract the pension premiums that apply to this trade union only
			ldec_pension_premium_earn_this_tu = 0
			
			//We need to get *ONLY* the timesheets for the union rate effective on the record
			ls_retrieve = "book = '" + gnv_app.is_book &
						+ "' AND cheque_no = " + String(abo_pr_ck.of_GetItemNumber(1, 'cheque_no')) &
						+ "  AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') + "'" &
						+ "  AND occupation = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'occupation') + "'"
			
			ls_retrieve += " AND Convert(Varchar, work_date, 112) >= '" + String(abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date'), 'YYYYMMDD') + "'" 

			IF ll_cto_rows > ll_cto_row THEN
				IF abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date') &
				<> abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row + 1, 'union_rate_effective_date') THEN
					ls_retrieve += " AND Convert(Varchar, work_date, 112) < '"  + String(abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row + 1, 'union_rate_effective_date'), 'YYYYMMDD') + "'"
				END IF
			END IF

			ll_ts_rows = ibo_timesheet_this_tu.of_Retrieve(ls_retrieve)
					
			ldec_all_hr_base_earn = 0
			FOR ll_ts_row = 1 TO ll_ts_rows
				
				//Read premiums for current timesheet	
				ibo_timesheet_premium.of_Retrieve("book = '" + gnv_app.is_book								&
								+ "' AND employee = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'employee')) 	&
								+ "  AND work_date = '" + String(ibo_timesheet_this_tu.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') &
								+ "' AND timesheet_item = " + String(ibo_timesheet_this_tu.of_GetItemNumber(ll_ts_row, 'timesheet_item')))
				
				//accumulate premiums for this timesheet
				of_tax_calc_pension_premiums_for_ts(ibo_timesheet_this_tu, ll_ts_row, &
																ibo_timesheet_premium, 	&
																ibo_trade_union_rate_this_ts_or_tu, 	&
																ldec_pension_premium_earn_this_tu)
	
				//While we're in the timesheets, we need all hrs base earn for the set of timesheets with this occupation
				ldec_all_hr_base_earn += Round(&
								 (ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'reg_hour')  		&
								+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'tah_hour')  	&
								+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'ovr_hour')  	&
								+ ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'travel_hour')) 	&
							* ibo_timesheet_this_tu.of_GetItemDecimal(ll_ts_row, 'base_rate'), 2)
			NEXT
	
			//Calculate pension for each occupation based on the trade level for the occupation
			IF ibo_occupation.of_Retrieve("book = '" + gnv_app.is_book &
										 + "' AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') &
										 + "' AND occupation = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'occupation') + "'") < 1 THEN
				this.of_prcent_err("Can't find union " + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') &
											+ " for cheque " 	+ String(abo_pr_cheque_occupation.of_GetItemNumber(ll_cto_row, 'cheque_no')), &
											abo_pr_cheque_occupation.of_GetItemNumber(ll_cto_row, 'cheque_no'), ads_msg)
				RETURN -1
			END IF

			//Initialize these because they're reference variables and they
			//were previously populated with the parent cheque's values
			ldec_union_pension_paid_out = 0
			
			of_tax_calc_pension_employer_by_occ(abo_pr_cheque_occupation, &
								  ll_cto_row, &
								  ibo_trade_union_rate_this_ts_or_tu, &
								  Date(abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date')), &
								  ads_msg, &
								  ldec_union_pension_paid_out)
								  
			//There's no place at the occupation level to record the union remittance etc.
			//write pension paid out to the parent trade union record
			ll_tu_row = abo_pr_cheque_trade_union.of_Find("trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') + "'" &
																	+ " AND union_rate_effective_date = Date('" &
																	+ String(abo_pr_cheque_occupation.of_GetItemDateTime(ll_cto_row, 'union_rate_effective_date'), 'yyyy.mm.dd') + "')")
			IF ll_tu_row < 0 THEN
				this.of_prcent_err("Cheque " + String(abo_pr_cheque_occupation.of_GetItemNumber(ll_cto_row, 'cheque_no')) &
									+ ": Can't find trade union " + abo_pr_cheque_occupation.of_GetItemString(ll_cto_row, 'trade_union') &
									+ " cheque record.", abo_pr_cheque_occupation.of_GetItemNumber(ll_ts_row, 'cheque_no'), ads_msg)
			ELSEIF ll_tu_row > 0 THEN
				abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'union_rrsp_paid_out', &
														abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'union_rrsp_paid_out') &
															+ ldec_union_pension_paid_out)
			END IF
		END IF
	NEXT
	
END IF

RETURN 1
end function

public function integer of_tax_calc_rrsp_employee_by_occupation (long al_cheque_no, string as_trade_union, string as_occupation, date adt_effective, decimal adec_total_hours, n_ds ads_msg, ref decimal adec_rrsp);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_rrsp_employee_by_occupation
// Author   :	Monica Petersen
// Date     :	2017/10/20
// 	
// Arguments:	long al_cheque_no
// 				string as_trade_union
// 				string as_occupation
// 				datetime adt_effective
// 				decimal adec_total_hours
// 				n_ds ads_msg
// 				decimal adec_rrsp
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

Long	ll_msg_row

//look the trade level up in the occupation table
IF ibo_occupation.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND trade_union = '" + as_trade_union &
							 + "' AND occupation = '"  + as_occupation + "'") < 1 THEN
	this.of_prcent_err("Can't find occupation " + as_trade_union + "/"+ as_occupation + " for cheque " &
								+ String(al_cheque_no), &
								al_cheque_no, ads_msg)
	RETURN -1
END IF

IF Len(ibo_occupation.of_GetItemString(1, 'level')) > 0 THEN
	//For this occupation, read the trade level
	IF ibo_trade_union_trade_level_employee_rrsp.of_Retrieve("book = '" + gnv_app.is_book + "'" &
																+ " AND trade_union = '" + as_trade_union + "'"&
																+ " AND trade_level = '" + ibo_occupation.of_GetItemString(1, 'level') + "'"&
																+ " AND Convert(varchar, effective_date, 112) <= '" + String(adt_effective, 'YYYYMMDD') + "'"&
																+ " AND Convert(varchar, expiry_date, 112) > '" + String(adt_effective, 'YYYYMMDD') + "'") < 0 THEN
		this.of_prcent_err("Cheque " + String(al_cheque_no) &
				+ ": Can't find trade union trade level rates for " + as_trade_union &
				+ " effective " + String(adt_effective, 'yyyy.mm.dd'), &
				al_cheque_no, ads_msg)
		RETURN -1
	END IF
	//Extend the amount from the trade union employee rrsp table by the total number of hours on the occupation child record
	IF ibo_trade_union_trade_level_employee_rrsp.of_RowCount() > 0 THEN
		adec_rrsp = ibo_trade_union_trade_level_employee_rrsp.of_GetItemDecimal(1, 'hourly_rate') * adec_total_hours
	ELSE
		adec_rrsp = 0
	END IF
ELSE
	adec_rrsp = 0
END IF

RETURN 1

end function

public function integer of_tax_calc_rrsp_employer_pct_by_union (ref n_cst_business abo_pr_ck_or_tu, integer ai_ck_row, ref n_cst_business abo_trade_union_this_tu, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_rrsp_premium_earn, decimal adec_all_hr_base_earn, n_ds ads_msg, string as_mode, date ad_rate_effective_date, boolean ab_over_71, decimal adec_retro, decimal adec_taxable_site_allow, decimal adec_nontaxable_site_allow);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_rrsp_employer_pct_by_union
// Author   :	Monica Petersen
// Date     :	2017/05/16
// 	
// Arguments:	n_cst_business abo_pr_ck_or_tu
// 				integer ai_ck_row
// 				n_cst_business abo_trade_union_this_tu
// 				n_cst_business abo_trade_union_rate_this_tu
// 				decimal adec_rrsp_premium_earn
// 				decimal adec_all_hr_base_earn
// 				n_ds ads_msg
// 				string as_mode
// 				date ad_rate_effective_date
// 				boolean ab_over_71
// 				decimal adec_retro
// 				decimal adec_taxable_site_allow
// 				decimal adec_nontaxable_site_allow
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

Decimal	ldec_hours

//---------------------
// RRSP source earnings
//		note - you get either a union rrsp, or an employer rrsp, or neither, but not both
//		jira 2117 - The base and matching amounts combine in the calculation of pension and RRSP. The base is always calculated. 
//						The matching is calculated only when the employee has made a contribution. 
//---------------------

//Staff get employer RRSPs
IF abo_trade_union_this_tu.of_GetItemString(1, 'staff_flag') = 'Y' THEN
	
	//Calculate employer_rrsp (vacation earned is based on cheque values and not on accumulation at current
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'rrsp_source_earn', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'reg_earn') 				&
																	+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'tah_earn') 					&
																	+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'ovr_earn') 					&
																	+ adec_retro																		&
																	+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'vacation_earn')			&
																	+ abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'statutory_earn')) 
																	
	//jira 3307 - optionally include site allowance in employer RRSP
	IF  abo_trade_union_this_tu.of_GetItemString(1, 'include_site_allow_in_empr_rrsp_flag') = 'Y' THEN
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'rrsp_source_earn', 							&
				  abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'rrsp_source_earn') 		&
				+ adec_taxable_site_allow	&
				+ adec_nontaxable_site_allow)
	END IF
	

ELSE	
	
	//regular hours
	ldec_hours = abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'reg_hour')
	IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours += abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'travel_hour') //jira 1652

	//Now calculate the percent amounts for RRSPs
	IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'N' &
		 OR abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'P' THEN
		
		//End of story -- no employer RRSP in this case, just 'P'ension or 'N'one.
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'rrsp_source_earn', 0) 
	
	ELSEIF abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'base_employer_rrsp_percent') = 0 &
	AND ibo_employee.of_GetItemDecimal(1, 'employee_rrsp_percent') = 0 THEN

 		//End of story -- no base RRSP amounts from the employer,
		// and if there were matching RRSP amounts, they wouldn't apply because
		// the employee hasn't contributed
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'rrsp_source_earn', 0) 
	
	ELSE
		
		//base employer RRSP percentages and employee matching RRSP percentages
		of_tax_calc_rrsp_emplr_base_nd_match_pct(abo_pr_ck_or_tu, &
															  ai_ck_row, &
															  abo_trade_union_rate_this_tu, &
															  adec_rrsp_premium_earn, &
															  adec_all_hr_base_earn, &
															  ab_over_71)
		
	END IF																 
END IF  /* end of non-staff union processing of union remittances */

IF ab_over_71 THEN
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_rrsp_paid_out', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'union_rrsp_paid_out') +  abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'union_rrsp'))
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_rrsp', 0)
END IF

//Jira 3666 - employees over 71 not eligible for RRSP  
IF ab_over_71 &	
AND as_mode = 'approve' 	/*jira 3307 - allow user to override employer RRSP, so only recalculate during approval process */ &
AND ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
	//set employer_rrsp_paid_out from variables we have, since we aren't storing employer_rrsp on the trade union child table
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'employer_rrsp_paid_out', &
				round(  ibo_employee.of_GetItemDecimal (1, "employer_rrsp_percent") * .01 &
								* abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'rrsp_source_earn')  , 2)) 
END IF

RETURN 1

end function

public function integer of_tax_calc_rrsp_emplr_base_nd_match_pct (ref n_cst_business abo_pr_ck_or_tu, integer ai_ck_row, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_rrsp_premium_earn_this_tu, decimal adec_all_hr_base_earn, boolean ab_over_71);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_rrsp_emplr_base_nd_match_pct
// Author   :	Monica Petersen
// Date     :	2017/05/08
// 	
// Arguments:	n_cst_business abo_pr_ck_or_tu
// 				n_cst_business abo_trade_union_rate
// 				decimal adec_rrsp_premium_earn_this_tu
// 				boolean ab_over_71
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

Long	ldec_hours
		
//regular hours
ldec_hours = abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'reg_hour')
IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours += abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'travel_hour') //jira 1652

//Now calculate the percent amounts for RRSPs
IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'N' &
	 OR abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'P' THEN
	
	//End of story -- no employer RRSP in this case, just 'P'ension or 'N'one.
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'rrsp_source_earn', 0) 

ELSEIF abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'base_employer_rrsp_percent') = 0 &
AND ibo_employee.of_GetItemDecimal(1, 'employee_rrsp_percent') = 0 THEN

	//End of story -- no employer RRSP in this case because the employee didn't chip in
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'rrsp_source_earn', 0) 

ELSE
	
	//( CLAC style which uses base earnings and may include premiums)
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'rrsp_source_earn', adec_all_hr_base_earn + adec_rrsp_premium_earn_this_tu ) 

	//Base percentage gets added regardless of whether or not the employee has contributed
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_rrsp', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'union_rrsp')	&
																	+ round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "base_employer_rrsp_percent") * .01 &
																		* abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'rrsp_source_earn') , 2)) 
																		
	IF ab_over_71 THEN
		//Jira 3666 - The union rrsp does not get added to union_remittance if its paid out to employees over 71
	ELSE
		//hourly remittance amounts will need RRSP amounts added back in															
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'add_to_union_remittance', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'add_to_union_remittance') &
																 + round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "base_employer_rrsp_percent") * .01 &
																			* abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'rrsp_source_earn') , 2))
	END IF
																		
	//jira 2117 - Add in matching amount if employee has contributed																	
	IF  abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'matching_employer_rrsp_percent') <> 0 &
	AND ibo_employee.of_GetItemDecimal(1, 'employee_rrsp_percent') <> 0 THEN
	
		abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_rrsp', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'union_rrsp')	&
																	+ round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "matching_employer_rrsp_percent") * .01 &
																			* abo_pr_ck_or_tu.of_GetItemDecimal(1, 'rrsp_source_earn') , 2)) 
																			
		IF ab_over_71 THEN
			//Jira 3666 - The union rrsp does not get added to union_remittance if its paid out to employees over 71
		ELSE
			//hourly remittance amounts will need RRSP amounts added back in															
			abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'add_to_union_remittance', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'add_to_union_remittance') &
																 + round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "matching_employer_rrsp_percent") * .01 &
																			* abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'rrsp_source_earn') , 2))
		END IF
	END IF
END IF																 

RETURN 1
end function

protected function integer of_tax_calc_pension_employer_by_union (ref n_cst_business abo_pr_ck_or_tu, integer ai_ck_row, ref n_cst_business abo_trade_union_rate_this_tu, decimal adec_pension_premium_earn, n_ds ads_msg, string as_mode, date ad_effective_date, boolean ab_over_71, decimal adec_all_hr_base_earn, ref decimal adec_pension_source_earn, ref decimal adec_union_pension_paid_out);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_pension_employer_by_union
// Author   :	Monica Petersen
// Date     :	2017/05/17
// 	
// Arguments:	n_cst_business abo_pr_ck_or_tu
// 				integer ai_ck_row
// 				n_cst_business abo_trade_union_rate_this_tu
// 				decimal adec_pension_premium_earn
// 				n_ds ads_msg
// 				string as_mode
// 				date ad_effective_date
// 				boolean ab_over_71
// 				decimal adec_all_hr_base_earn
//		These are returned to the calling routine
//		so they can either be recorded on the cheque
//		or added to the parent trade union for this
//		occupation.
// 				decimal adec_union_remittance
// 				decimal adec_pension_source_earn
// 				decimal adec_union_pension_paid_out
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

Decimal	ldec_hours, ldec_reg_rate, ldec_tah_rate, ldec_ovr_rate
Long		ll_msg_row
String	ls_msg

// Staff don't get an employer pension
IF ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
	
	adec_pension_source_earn = 0
	abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_pension', 0) 

// Union contributes a percentage amount
ELSE
	
	//Now calculate the percentages if they apply
	IF abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'N' &
	OR abo_trade_union_rate_this_tu.of_GetItemString(1, 'employer_pension_or_rrsp') = 'R' THEN
	
		//no pension in this case, neither or only RRSP
		adec_pension_source_earn = 0
	
	ELSEIF abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'base_employer_pension_percent') = 0 &
		AND ibo_employee.of_GetItemDecimal(1, 'employee_pension_percent') = 0 THEN
	
		//jira 1899 - no union pension unless employee pays
		//i.e. base doesn't apply because it's 0, and if there were matching amounts,
		//they wouldn't apply either because the employee isn't contributing
		adec_pension_source_earn = 0 
	
	ELSE		
		//base and matching percents apply to pension
		
		// CLAC style which uses base earnings and may include premiums
		adec_pension_source_earn = adec_all_hr_base_earn + adec_pension_premium_earn 
	
		//Base percentage gets added regardless of whether or not the employee has contributed
		IF ibo_employee.of_GetItemString(1, 'pay_pension_to_cash_flag') = 'Y' THEN
			adec_union_pension_paid_out += round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "base_employer_pension_percent") * .01 &
																			* adec_pension_source_earn , 2)
		ELSE
			abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_pension', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'union_pension')	&
																			+ round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "base_employer_pension_percent") * .01 &
																			* adec_pension_source_earn , 2)) 
			//all union RRSP and pension has been stripped out of the union remittances, to allow overrides from trade level tables																
			abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'add_to_union_remittance', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'add_to_union_remittance')	&
																			+ round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "base_employer_pension_percent") * .01 &
																			* adec_pension_source_earn , 2)) 
		END IF
																	 
		//jira 2117 - Add in matching amount if employee has contributed																	
		IF  abo_trade_union_rate_this_tu.of_GetItemDecimal(1, 'matching_employer_pension_percent') <> 0 &
		AND ibo_employee.of_GetItemDecimal(1, 'employee_pension_percent') <> 0 THEN
		
			IF ibo_employee.of_GetItemString(1, 'pay_pension_to_cash_flag') = 'Y' THEN
				adec_union_pension_paid_out += round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "matching_employer_pension_percent") * .01 &
																				* adec_pension_source_earn, 2)
			ELSE																		
				abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'union_pension', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'union_pension')	&
																		+ round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "matching_employer_pension_percent") * .01 &
																				* adec_pension_source_earn, 2)) 
			//all union RRSP and pension has been stripped out of the union remittances, to allow overrides from trade level tables																
				abo_pr_ck_or_tu.of_SetItem(ai_ck_row, 'add_to_union_remittance', abo_pr_ck_or_tu.of_GetItemDecimal(ai_ck_row, 'add_to_union_remittance')	&
																		+ round(abo_trade_union_rate_this_tu.of_GetItemDecimal(1, "matching_employer_pension_percent") * .01 &
																				* adec_pension_source_earn, 2)) 
			END IF																		
		END IF
	END IF
END IF

RETURN 1

end function

public function integer of_get_provincial_tax_bp (string as_prov, decimal adec_net_income, datetime adt_issue, ref decimal adec_bpa);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_get_provincial_tax_bp
// Author   :	Monica Petersen
// Date     :	2020/06/23
// 	
// Arguments:	string as_prov
// 				decimal adec_t4
// 				datetime adt_issue
// 				decimal adec_v1
// 	
// Returns:		integer
// 	
// Desc:			yukon territory has a new calculation for basic personal amount,
//					instead of the provincial TD1 claim
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long		ll_rows, ll_x

//Get the constants for the latest date
IF Not(IsValid(ibo_province_income_tax)) THEN
	ibo_province_income_tax = CREATE n_bo_province_income_tax
	ibo_province_income_tax.of_SetTransaction()
END IF

ll_rows = ibo_province_income_tax.of_Retrieve("province = '" + as_prov &
												  + "' AND calculation_type = 'BP' AND effective_date <= '" + String(adt_issue, 'yyyy.mm.dd') &
												  + "' AND expiry_date >= '" + String(adt_issue, 'yyyy.mm.dd') + "'")

ibo_province_income_tax.of_SetSort('a_min asc')
ibo_province_income_tax.of_Sort()

CHOOSE CASE ll_rows
	CASE 0
		RETURN 0
	CASE -1
		this.of_inc_tax_error("Error reading province_income_tax constants for " + as_prov + " on " + String(adt_issue, 'yyyy.mm.dd'))
		RETURN -1
	CASE ELSE
		FOR ll_x = 1 TO ll_rows
			//Basic Personal Amount
			IF adec_net_income <= ibo_province_income_tax.of_GetItemDecimal(ll_x, 'a_min') THEN
				IF ibo_province_income_tax.of_GetItemDecimal(ll_x, 'v_rate') = 0 THEN
					adec_bpa = ibo_province_income_tax.of_GetItemDecimal(ll_x, 'kp_constant') 
				ELSE
					//sliding scale between the previous value and the next
					adec_bpa = Round(ibo_province_income_tax.of_GetItemDecimal(ll_x - 1, 'kp_constant') &
											- (adec_net_income - ibo_province_income_tax.of_GetItemDecimal(ll_x - 1, 'a_min')) &
												 * ibo_province_income_tax.of_GetItemDecimal(ll_x, 'v_rate'), 2)
				END IF
				
				//If we're under the threshold, we don't have to check any more levels
				RETURN 1
				
			END IF
		NEXT
END CHOOSE

RETURN 1
end function

public function integer of_get_provincial_constants (string as_province, string as_type, datetime adt_issue, long al_a_min, ref decimal adec_a_min_floor, ref decimal adec_a_min_ceiling, ref decimal adec_a_min_maximum, ref decimal adec_v_rate_minimum, ref decimal adec_v_rate, ref long al_kp_constant_floor, ref long al_kp_constant, ref decimal adec_add_on);//************************************************************
// Object   :	n_bo_pr_cheque_save 
// Function :	of_get_provincial_constants
// Author   :	Monica Petersen
// Date     :	2017/04/26
// 	
// Arguments:	string as_province
// 				string as_type
// 				datetime adt_issue
// 				long al_a_min
// 				decimal adec_a_min_floor
// 				decimal adec_a_min_ceiling
// 				decimal adec_a_min_maximum
// 				decimal adec_v_rate_minimum
// 				decimal adec_v_rate_ceiling
// 				long al_kp_constant_floor
// 				long al_kp_constant_ceiling
// 				decimal adec_add_on_ceiling
// 	
// Returns:		integer
// 	
// Desc:			Read constants and rates for Provincial Income Tax calculations
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long	ll_pit_rows, ll_find

//Tax rates
IF Not(IsValid(ibo_province_income_tax)) THEN
	ibo_province_income_tax = CREATE n_bo_province_income_tax
	ibo_province_income_tax.of_SetTransaction(sqlca)
END IF

ll_pit_rows = ibo_province_income_tax.of_Retrieve("province = '" + as_province &
		+ "' AND calculation_type = '" + as_type &
		+ "' AND CONVERT(varchar, effective_date, 112) <= '" + String(adt_issue, "YYYYMMDD") + &
		+ "' AND CONVERT(varchar, expiry_date, 112) > '" + String(adt_issue, "YYYYMMDD") + "'")
IF ll_pit_rows = -1 THEN
	
	this.of_inc_tax_error("Error reading province income tax for type " + as_type + " from province_income_tax for " + as_province + " on " + String(adt_issue, 'yyyy.mm.dd'))
	RETURN -1
	
ELSEIF ll_pit_rows > 0 THEN
	
	ibo_province_income_tax.of_SetSort("a_min asc")
	ibo_province_income_tax.of_Sort()
	
	adec_v_rate_minimum = ibo_province_income_tax.of_GetItemDecimal(1, 'v_rate')
	adec_a_min_maximum = ibo_province_income_tax.of_GetItemDecimal(ll_pit_rows, 'a_min')


	//Find entry for this taxable earning
	ll_find = ibo_province_income_tax.of_Find("a_min > " + String(al_a_min))	
	IF ll_find > 1 THEN
		
		//We've found the first tax bracket that is above this earning level, so the
		//values on this row represent the ceiling amounts
		adec_a_min_ceiling = ibo_province_income_tax.of_GetItemDecimal(ll_find, 'a_min')
		
		//Go down one row to find the rates we'll be using as a base for calculations
		//in this tax bracket
		ll_find --
		IF ll_find > 0 THEN
			al_kp_constant = ibo_province_income_tax.of_GetItemDecimal(ll_find, 'kp_constant')
			adec_v_rate = ibo_province_income_tax.of_GetItemDecimal(ll_find, 'v_rate')
			adec_add_on = ibo_province_income_tax.of_GetItemDecimal(ll_find, 'add_on')
			adec_a_min_floor = ibo_province_income_tax.of_GetItemDecimal(ll_find, 'a_min')
			
			//The entry one down is the bottom range, or floor, for this earning level
			ll_find --
			IF ll_find > 0 THEN
				al_kp_constant_floor = ibo_province_income_tax.of_GetItemDecimal(ll_find, 'kp_constant')
			ELSE
				al_kp_constant_floor = ibo_province_income_tax.of_GetItemDecimal(1, 'kp_constant')
			END IF
		END IF

	ELSEIF ll_find = 0 THEN
		
		//We're at the top bracket, there's no entry above the current taxable income
		//ceiling values
		adec_a_min_ceiling = ibo_province_income_tax.of_GetItemDecimal(ll_pit_rows, 'a_min')
		adec_a_min_floor = ibo_province_income_tax.of_GetItemDecimal(ll_pit_rows, 'a_min')
		al_kp_constant = ibo_province_income_tax.of_GetItemDecimal(ll_pit_rows, 'kp_constant')
		adec_v_rate = ibo_province_income_tax.of_GetItemDecimal(ll_pit_rows, 'v_rate')
		adec_add_on = ibo_province_income_tax.of_GetItemDecimal(ll_pit_rows, 'add_on')
		al_kp_constant_floor = ibo_province_income_tax.of_GetItemDecimal(ll_pit_rows, 'kp_constant')
	END IF
ELSE
	RETURN 0
END IF

RETURN 1
end function

public function integer of_tax_calc_vacation_stat_sick (date ad_last_day_of_pp, ref n_cst_business abo_ck, ref n_ds ads_msg, ref decimal adec_latest_timesheet_reg_rate, ref n_cst_business abo_pr_cheque_trade_union);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_vacation_stat_sick
// Author   :	Monica Petersen
// Date     :	2015/12/09
// 	
// Arguments:	date ad_last_day_of_pp
// 				n_cst_business abo_ck
// 				n_ds ads_msg
// 				decimal adec_latest_timesheet_reg_rate
// 				n_cst_business abo_pr_cheque_trade_union
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


String	ls_date, ls_tur_find, ls_tur_retrieve
Long		ll_ts_row, ll_ts_rows, ll_msg_row, ll_tsp_rows, ll_pt_row, ll_cp_row, ll_cp_rows, ll_tu_row, ll_tur_row
Decimal	ldec_hours
Decimal	ldec_statutory_source_earn
Decimal	ldec_vacation_source_earn
Decimal	ldec_statutory_percent
Decimal	ldec_vacation_percent
Boolean	lb_shift_adds_to_vacation_fringe, lb_shift_adds_to_statutory_fringe

Decimal	ldec_statutory_percent_for_this_ts
Decimal	ldec_vacation_percent_for_this_ts
Decimal	ldec_vacation_source_earn_for_this_ts
Decimal	ldec_statutory_source_earn_for_this_ts

ll_ts_rows = ibo_timesheet.of_RowCount()

//sort this so we can use .of_find to position on the correct effective date
abo_pr_cheque_trade_union.of_SetSort("trade_union ASC, union_rate_effective_date DESC")
abo_pr_cheque_trade_union.of_Sort()

//Vacation percent is either from the union or the employee
CHOOSE CASE ibo_trade_union_rate.of_GetItemString(1, 'union_vacation_pay_flag')
	CASE 'Y'
		ldec_vacation_percent =  ibo_trade_union_rate.of_GetItemDecimal(1, "vacation_percent")
	CASE 'N'
		ldec_vacation_percent =  ibo_employee.of_GetItemDecimal(1, "vacation_percent")
END CHOOSE

//Statutory percent is either from the union or the employee
CHOOSE CASE ibo_trade_union_rate.of_GetItemString(1, 'union_statutory_pay_flag')
	CASE 'Y'
		ldec_statutory_percent =  ibo_trade_union_rate.of_GetItemDecimal(1, "statutory_percent")
	CASE 'N'
		ldec_statutory_percent =  ibo_employee.of_GetItemDecimal(1, "statutory_percent")
END CHOOSE

//------------------
// Scan timesheets for source earnings
//------------------

// Calculate fields originally added up in cheque creation based on timesheets associated with this cheque
ibo_timesheet.of_SetSort("work_date ASC, timesheet_item ASC")
ibo_timesheet.of_Sort()

FOR ll_tu_row = 1 TO abo_pr_cheque_trade_union.of_RowCount()
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'statutory_source_earn', 	0)
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'statutory_earn',  			0)
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'vacation_source_earn',  	0)
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'vacation_earn',   			0)
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'paid_sick_leave',  			0)
NEXT

adec_latest_timesheet_reg_rate = 0
//Process all timesheets for this cheque
FOR ll_ts_row = 1 TO ll_ts_rows
	
	//Get the regular rate on the latest timesheet to use in vacation earned calculations.
	// If the employee has had a rate change, the vacation earn will apply the new rate to past earnings.
	IF ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'reg_rate') > 0 THEN adec_latest_timesheet_reg_rate = ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'reg_rate')
		
	IF IsNull(ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'base_rate')) THEN
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_ck.of_GetItemNumber(1, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "Error, timesheet base rate is not set properly")
		RETURN -1
	END IF
	
	//Read premiums for current timesheet
	ll_tsp_rows = ibo_timesheet_premium.of_Retrieve("book = '" + gnv_app.is_book								&
					+ "' AND employee = " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'employee')) 	&
					+ "  AND work_date = '" + String(ibo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') &
					+ "' AND timesheet_item = " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'timesheet_item')))
	
	//Union dues use all hr base and all hr reg, so calculate them while we're scanning timesheets
	ldec_hours = ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'reg_hour') 	&
										+ ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'tah_hour') &
										+ ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'ovr_hour') 
	IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'travel_hour')
	
	abo_ck.of_SetItem(1, 'all_hr_reg_earn',  abo_ck.of_GetItemDecimal(1, 'all_hr_reg_earn')  + Round(ldec_hours * ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'reg_rate'), 2))
	abo_ck.of_SetItem(1, 'all_hr_base_earn', abo_ck.of_GetItemDecimal(1, 'all_hr_base_earn') + Round(ldec_hours * ibo_timesheet.of_GetItemDecimal(ll_ts_row, 'base_rate'), 2))
	
	// lookup trade union settings FOR THIS TIMESHEET
	ls_date = String(abo_ck.of_GetItemDateTime(1, 'issue_date'), 'yyyy.mm.dd')
	ls_tur_find = "book = '" + gnv_app.is_book &
										+ "' AND trade_union = '" + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') &
										+ "' AND effective_date <= Date('" + ls_date   &
										+ "') AND expiry_date >= Date('" + ls_date + "')"
	
	ll_tur_row = ibo_trade_union_rate.of_Find(ls_tur_find ) 
	IF ll_tur_row < 1 THEN
		ls_date = String(abo_ck.of_GetItemDateTime(1, 'issue_date'), 'YYYYMMDD')
		ls_tur_retrieve = "book = '" + gnv_app.is_book &
											+ "' AND trade_union = '" + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') &
											+ "' AND Convert(varchar, effective_date, 112) <= '" + ls_date    &
											+ "' AND Convert(varchar, expiry_date, 112) >= '" + ls_date + "'"
		ibo_trade_union_rate.of_Retrieve(ls_tur_retrieve, TRUE /* append rows */) 
		ll_tur_row = ibo_trade_union_rate.of_Find(ls_tur_find ) 
		IF ll_tur_row < 1 THEN
			this.of_prcent_err("Cheque " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'cheque_no')) &
								+ ": No union remittance rates were found for union '" + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') &
								+ "', effective for time worked on " + String(abo_ck.of_GetItemDateTime(1, 'issue_date'), 'yyyy.mm.dd'), ibo_timesheet.of_GetItemNumber(ll_ts_row, 'cheque_no'), ads_msg)
			RETURN -1
		END IF
	END IF

	//Statutory percent is either from the union or the employee
	//calculation needs percent for saskatchewan vacation that accrues on statutory
	CHOOSE CASE ibo_trade_union_rate.of_GetItemString(ll_tur_row, 'union_statutory_pay_flag')
		CASE 'Y'
			ldec_statutory_percent_for_this_ts =  ibo_trade_union_rate.of_GetItemDecimal(ll_tur_row, "statutory_percent")
		CASE 'N'
			ldec_statutory_percent_for_this_ts =  ibo_employee.of_GetItemDecimal(1, "statutory_percent")
	END CHOOSE

	of_tax_calc_vacation_stat_this_ts(ll_ts_row, &
													 ibo_trade_union_rate, &
													 ll_tur_row, &
													 ldec_vacation_source_earn, &
													 ldec_statutory_source_earn, &
													 ldec_statutory_percent_for_this_ts)

	// ================================================
	//	POPULATE P/R CHEQUE TRADE UNION RECORD FOR MULTI-UNION CHEQUES
	// ================================================
	IF g_bo_application_properties.of_GetItemString(1, 'multiple_unions_per_cheque_flag') = 'Y' THEN
		ll_tu_row = abo_pr_cheque_trade_union.of_Find("trade_union = '" + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') + "'" &
																+ " AND union_rate_effective_date <= Date('" + String(ibo_timesheet.of_GetItemDateTime(ll_ts_row, 'work_date'), 'yyyy.mm.dd') + "')")
		IF ll_tu_row < 0 THEN
			this.of_prcent_err("Cheque " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'cheque_no')) &
								+ ": Can't find trade union " + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') &
								+ " cheque record.", ibo_timesheet.of_GetItemNumber(ll_ts_row, 'cheque_no'), ads_msg)
		ELSEIF ll_tu_row > 0 THEN
			// lookup trade union settings FOR THIS TIMESHEET
			ls_date = String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_tu_row, 'union_rate_effective_date'), 'yyyy.mm.dd')
			ls_tur_find = "book = '" + gnv_app.is_book &
												+ "' AND trade_union = '" + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') &
												+ "' AND effective_date <= Date('" + ls_date   &
												+ "') AND expiry_date >= Date('" + ls_date + "')"
			
			ll_tur_row = ibo_trade_union_rate_this_ts_or_tu.of_Find(ls_tur_find ) 
			IF ll_tur_row < 1 THEN
				ls_date = String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_tu_row, 'union_rate_effective_date'), 'YYYYMMDD')
				ls_tur_retrieve = "book = '" + gnv_app.is_book &
													+ "' AND trade_union = '" + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') &
													+ "' AND Convert(varchar, effective_date, 112) <= '" + ls_date    &
													+ "' AND Convert(varchar, expiry_date, 112) >= '" + ls_date + "'"
				ibo_trade_union_rate_this_ts_or_tu.of_Retrieve(ls_tur_retrieve, TRUE /* append rows */) 
				ll_tur_row = ibo_trade_union_rate_this_ts_or_tu.of_Find(ls_tur_find ) 
				IF ll_tur_row < 1 THEN
					this.of_prcent_err("Cheque " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'cheque_no')) &
										+ ": No union remittance rates were found for union '" + ibo_timesheet.of_GetItemString(ll_ts_row, 'trade_union') &
										+ "', effective for time worked on " + String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_tu_row, 'union_rate_effective_date'), 'yyyy.mm.dd'), ibo_timesheet.of_GetItemNumber(ll_ts_row, 'cheque_no'), ads_msg)
					RETURN -1
				END IF
			END IF
		
			//Vacation percent is either from the union or the employee
			CHOOSE CASE ibo_trade_union_rate_this_ts_or_tu.of_GetItemString(ll_tur_row, 'union_vacation_pay_flag')
				CASE 'Y'
					ldec_vacation_percent_for_this_ts =  ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "vacation_percent")
				CASE 'N'
					ldec_vacation_percent_for_this_ts =  ibo_employee.of_GetItemDecimal(1, "vacation_percent")
			END CHOOSE
			
			//Statutory percent is either from the union or the employee
			CHOOSE CASE ibo_trade_union_rate_this_ts_or_tu.of_GetItemString(ll_tur_row, 'union_statutory_pay_flag')
				CASE 'Y'
					ldec_statutory_percent_for_this_ts =  ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "statutory_percent")
				CASE 'N'
					ldec_statutory_percent_for_this_ts =  ibo_employee.of_GetItemDecimal(1, "statutory_percent")
			END CHOOSE
		
			//Initialize variables because the subroutine accumulates them
			//for the whole cheque
			ldec_vacation_source_earn_for_this_ts = 0
			ldec_statutory_source_earn_for_this_ts = 0
			
			//calculation needs percent for saskatchewan vacation that accrues on statutory
			of_tax_calc_vacation_stat_this_ts(ll_ts_row, &
															 ibo_trade_union_rate_this_ts_or_tu, &
															 ll_tur_row, &
															 ldec_vacation_source_earn_for_this_ts, &
															 ldec_statutory_source_earn_for_this_ts, &
															 ldec_statutory_percent_for_this_ts)
															 
			//Source amounts are calculated, set earnings amount accordingly
			abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'statutory_source_earn',abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'statutory_source_earn')	+ ldec_statutory_source_earn_for_this_ts)
			abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'vacation_source_earn', abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'vacation_source_earn') 	+ ldec_vacation_source_earn_for_this_ts)
			
		END IF
	END IF
	// ================================================
	
NEXT	//Timesheet

//Initialize cheque's sick leave, it will be 
//the sum of each trade union's sick leave
abo_ck.of_SetItem(1, 'paid_sick_leave', 0)

FOR ll_tu_row = 1 TO abo_pr_cheque_trade_union.of_RowCount()
	//Calculate earnings after all timesheets are processed to reduce rounding errors
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'statutory_earn', round(abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'statutory_source_earn') * ldec_statutory_percent_for_this_ts * .01, 2))
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'vacation_earn',  round(abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'vacation_source_earn')  * ldec_vacation_percent_for_this_ts * .01, 2))
	
	//Calculate regular earnings plus vacation and stat.  This is what paid sick leave is based on in BC
	//  -- 2022.03.17 - changed this to just straight time, miscommunication with union ---
	//	 -- but leave it in a variable because we may have options to identify what kind of earnings it's based on --
//	ldec_sick_leave_earnings = abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'reg_earn') &
//										+ abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'tah_earn') &
//										+ abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'ovr_earn')
	
	// lookup trade union settings
	ls_date = String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_tu_row, 'union_rate_effective_date'), 'yyyy.mm.dd')
	ls_tur_find = "book = '" + gnv_app.is_book &
										+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_tu_row, 'trade_union') &
										+ "' AND effective_date <= Date('" + ls_date   &
										+ "') AND expiry_date >= Date('" + ls_date + "')"
	ll_tur_row = ibo_trade_union_rate_this_ts_or_tu.of_Find(ls_tur_find ) 
	IF ll_tur_row < 1 THEN
		ls_date = String(abo_pr_cheque_trade_union.of_GetItemDateTime(ll_tu_row, 'union_rate_effective_date'), 'YYYYMMDD')
		ls_tur_retrieve = "book = '" + gnv_app.is_book &
											+ "' AND trade_union = '" + abo_pr_cheque_trade_union.of_GetItemString(ll_tu_row, 'trade_union') &
											+ "' AND Convert(varchar, effective_date, 112) <= '" + ls_date    &
											+ "' AND Convert(varchar, expiry_date, 112) >= '" + ls_date + "'"
		ibo_trade_union_rate_this_ts_or_tu.of_Retrieve(ls_tur_retrieve, TRUE /* append rows */) 
		ll_tur_row = ibo_trade_union_rate_this_ts_or_tu.of_Find(ls_tur_find ) 
		IF ll_tur_row < 1 THEN
			this.of_prcent_err("Cheque " + String(ibo_timesheet.of_GetItemNumber(ll_ts_row, 'cheque_no')) &
								+ ": No union remittance rates were found for union '" + abo_pr_cheque_trade_union.of_GetItemString(ll_tu_row, 'trade_union') &
								+ "', effective for time worked on " + ls_date, abo_ck.of_GetItemNumber(1, 'cheque_no'), ads_msg)
			RETURN -1
		END IF
	END IF

	//Paid sick leave is a percent of hourly earnings and/or a per hour amount.  One or the other, but for flexibility we allow both
	
	//First, calculate the hourly amount
	abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'paid_sick_leave', &
				Round(  ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_reg_hr")  * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'reg_hour') &
						+ ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_tah_hr")  * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'tah_hour') &
						+ ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_ovr_hr")  * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'ovr_hour') &
						, 2))
	
	//Now, what kind of earnings are the rates applied towards?
	CHOOSE CASE ibo_trade_union_rate.of_GetItemString(1, 'paid_sick_type') 
		CASE 'B'
			//All hours at base rate
			abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'paid_sick_leave', &
						abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'paid_sick_leave') &
						+ Round(  ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_reg_earn") &
									 * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'all_hr_base_earn'), 2))
		CASE 'R'
			//All hours at base rate
			abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'paid_sick_leave', &
						abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'paid_sick_leave') &
						+ Round(  ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_reg_earn") &
									 * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'all_hr_reg_earn'), 2))
		CASE 'E'
			//Hourly earnings
			abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'paid_sick_leave', &
						abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'paid_sick_leave') &
						+ Round(  ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_reg_earn") &
									   * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'reg_earn') &
									 + ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_tah_earn") &
									   * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'tah_earn') &
									 + ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_ovr_earn") &
									   * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'ovr_earn'), 2))
	END CHOOSE
	
	//Do we apply the reg_earn rate towards holiday pay?  i.e. vacation and stat pay?
	IF ibo_trade_union_rate_this_ts_or_tu.of_GetItemString(ll_tur_row, "paid_sick_on_holiday_pay_flag") = 'Y' THEN
		abo_pr_cheque_trade_union.of_SetItem(ll_tu_row, 'paid_sick_leave', abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'paid_sick_leave') + &
					+ ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_reg_earn") * 0.01 * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'vacation_earn') &
					+ ibo_trade_union_rate_this_ts_or_tu.of_GetItemDecimal(ll_tur_row, "paid_sick_reg_earn") * 0.01 * abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'statutory_earn') )
	END IF
												
	//Now add the sick leave for each individual union to the cheque
	abo_ck.of_SetItem(1, 'paid_sick_leave', abo_ck.of_GetItemDecimal(1, 'paid_sick_leave') + abo_pr_cheque_trade_union.of_GetItemDecimal(ll_tu_row, 'paid_sick_leave'))
NEXT

//Does shift go into fringe?
IF ibo_trade_union_rate.of_GetItemString(1, 'vacation_pay_type') = 'H' THEN
	
	lb_shift_adds_to_vacation_fringe = FALSE
	FOR ll_cp_row = 1 TO ll_cp_rows
		ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_pr_cheque_premium.of_GetItemString(ll_cp_row, 'premium_type') + "'")
		IF ll_pt_row > 0 THEN
			IF ibo_premium_type.of_GetItemString(ll_pt_row, 'shift_2_flag') = 'Y' &
			OR ibo_premium_type.of_GetItemString(ll_pt_row, 'shift_3_flag') = 'Y' THEN
				IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'Y' THEN
					//Use this boolean to determine if vacation portion of shift goes into shift_premium_fringe
					lb_shift_adds_to_vacation_fringe = TRUE
				END IF
			END IF
		END IF
	NEXT
END IF

IF ibo_trade_union_rate.of_GetItemString(1, 'statutory_pay_type') = 'H' THEN
		
	lb_shift_adds_to_statutory_fringe = FALSE
	FOR ll_cp_row = 1 TO ll_cp_rows
		ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_pr_cheque_premium.of_GetItemString(ll_cp_row, 'premium_type') + "'")
		IF ll_pt_row > 0 THEN
			IF ibo_premium_type.of_GetItemString(ll_pt_row, 'shift_2_flag') = 'Y' &
			OR ibo_premium_type.of_GetItemString(ll_pt_row, 'shift_3_flag') = 'Y' THEN
				IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'Y' THEN
					//Use this boolean to determine if statutory portion of shift goes into shift_premium_fringe
					lb_shift_adds_to_statutory_fringe = TRUE
				END IF
			END IF
		END IF
	NEXT
	
END IF

//------------------
// Assign source earnings based on cheques 
//------------------

//Source amounts are calculated, set earnings amount accordingly
abo_ck.of_SetItem(1, 'statutory_source_earn', ldec_statutory_source_earn)
abo_ck.of_SetItem(1, 'statutory_earn', round(ldec_statutory_source_earn * ldec_statutory_percent * .01, 2))
abo_ck.of_SetItem(1, 'vacation_source_earn', ldec_vacation_source_earn)
abo_ck.of_SetItem(1, 'vacation_earn', round(ldec_vacation_source_earn * ldec_vacation_percent * .01, 2))

// Jira 3175 - Calculate vacation hours earned and owed
IF ibo_trade_union.of_GetItemString(1, 'track_vacation_hours_owed_flag') = 'Y' THEN

	//Only staff can track vacation hours owed, and staff can only accrue vacation based on Hourly earnings, 
	// so vacation hours are based on reg, tah, ovr, and travel, and accumulated at either the employee or trade union vacation percentage
	ldec_hours = abo_ck.of_GetItemDecimal(1, 'reg_hour') 	&
										+ abo_ck.of_GetItemDecimal(1, 'tah_hour') &
										+ abo_ck.of_GetItemDecimal(1, 'ovr_hour') 
	IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN 
		ldec_hours += abo_ck.of_GetItemDecimal(1, 'travel_hour')
	END IF
	
	IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN 
		ldec_hours += abo_ck.of_GetItemDecimal(1, 'travel_hour')
	END IF
	
	IF ibo_trade_union_rate.of_GetItemString(1, 'sick_pay_in_holiday_earning_flag') = 'Y' THEN 
		ldec_hours += ldec_hours * ibo_trade_union_rate.of_GetItemDecimal(1, 'paid_sick_reg_earn') * 0.01
	END IF
	
	abo_ck.of_SetItem(1, 'vacation_hours_earn', round(ldec_hours * ldec_vacation_percent * .01, 4))

	IF abo_ck.of_GetItemDecimal(1, 'vacation_lost') = 0 THEN
		abo_ck.of_SetItem(1, 'vacation_hours_lost',  0)
	ELSE
		// calculate what the result would be to the vacation owed and divide by their current regular rate which tells 
		// us what the resulting vacation hours owed have to be
		abo_ck.of_SetItem(1, 'vacation_hours_lost',  &
							 ibo_employee.of_GetItemDecimal(1, 'vacation_hours_owed')	&
							  			-  (ibo_employee.of_GetItemDecimal(1, 'vacation_owed') 	&
											 + abo_ck.of_GetItemDecimal(1, 'vacation_earn') 		&
											 - abo_ck.of_GetItemDecimal(1, 'vacation_paid') 		&
											 - abo_ck.of_GetItemDecimal(1, 'vacation_lost')) 		&
										   / adec_latest_timesheet_reg_rate)							
	END IF
END IF

//Overtime premium costs are stamped on the cheque during cheque creation
// (different use of the term premium, merely indicates the additional cost for not doing the work during a regular shift)
// Add stat and vacation amounts to fringe costs
IF ibo_trade_union_rate.of_GetItemString(1, 'statutory_pay_type') = 'H' THEN

	//Add portion accrued on statutory holidays to premium fringe costs
	abo_ck.of_SetItem(1, 'tah_premium_fringe', 	&
				round(ldec_statutory_percent * .01 * abo_ck.of_GetItemDecimal(1, 'tah_premium'), 2))    
	abo_ck.of_SetItem(1, 'ovr_premium_fringe', 	&
				round(ldec_statutory_percent * .01 * abo_ck.of_GetItemDecimal(1, 'ovr_premium'), 2))     
	IF lb_shift_adds_to_statutory_fringe THEN 
		abo_ck.of_SetItem(1, 'shift_premium_fringe',&
				round(ldec_statutory_percent * .01 * abo_ck.of_GetItemDecimal(1, 'shift_premium'), 2))     
	END IF
			
END IF

IF ibo_trade_union_rate.of_GetItemString(1, 'vacation_pay_type') = 'H' THEN
	//Add portion accrued on vacation to premium fringe costs
	abo_ck.of_SetItem(1, 'tah_premium_fringe', 	abo_ck.of_GetItemDecimal(1, 'tah_premium_fringe')  &
				+ round(ldec_vacation_percent * .01 * abo_ck.of_GetItemDecimal(1, 'tah_premium'), 2))    
	abo_ck.of_SetItem(1, 'ovr_premium_fringe', 	abo_ck.of_GetItemDecimal(1, 'ovr_premium_fringe')  &
				+ round(ldec_vacation_percent * .01 * abo_ck.of_GetItemDecimal(1, 'ovr_premium'), 2))     
	IF lb_shift_adds_to_vacation_fringe THEN 
		abo_ck.of_SetItem(1, 'shift_premium_fringe',abo_ck.of_GetItemDecimal(1, 'shift_premium_fringe')  &
				+ round(ldec_vacation_percent * .01 * abo_ck.of_GetItemDecimal(1, 'shift_premium'), 2))     
	END IF
			
END IF

			


end function

public function integer of_inc_tax_eff_dated (decimal adec_a, decimal adec_k2, integer ai_pay_period_per_year, integer ai_cpp_months, ref decimal adec_t1, ref decimal adec_t2, long al_employee, datetime adt_max_date, decimal adec_cpp_contribution, decimal adec_ei_premium, decimal adec_qpip_premium, decimal adec_emp_cpp_contribution, decimal adec_emp_ei_premium, decimal adec_emp_qpip_premium, ref n_ds ads_msg);//************************************************************
// Object   :	n_abio_appmanager 
// Function :	of_inc_tax_eff_dated
// Author   :	Monica Petersen
// Date     :	2009/03/06
// 	
// Arguments:	decimal adec_a - annual taxable income
// 				decimal adec_k2 - Canada Pension Plan contributions and employment insurance premiums federal tax credits for the year
// 				integer ai_pay_period_per_year
//    output:
// 				decimal adec_t1 - annual basic federal tax
// 				decimal adec_t2 - provincial tax
//    input:
// 				long al_employee
// 				datetime adt_max_date
// 				decimal adec_cpp_contribution
// 				decimal adec_ei_premium
// 	
// Returns:		integer
// 	
// Desc:			Calculate federal and provincial tax
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// Dec 28, 2007	MPetersen 		Updated with constants for 2008
// March 5, 2009  MPetersen		Change our tax calculation method so that we look 
//                               at the maximum value of the 'minimum' TD1 amounts 
//                               from both the system values and the employee ones. 
// April 1, 2009  LGARCIA        provincial td1 claim or employee td1 claim, select max
//************************************************************

String	ls_prov
Long		ll_kp_constant_ceiling, ll_kp_constant_floor
Integer	li_rc
Decimal	ldec_r_1, ldec_r_2, ldec_r_3, ldec_r_4, ldec_r_5, ldec_r
Decimal	ldec_v_rate_ceiling, ldec_v_rate_minimum, ldec_t4, ldec_s, ldec_v1, ldec_v2, ldec_a_min_ceiling, ldec_a_min_maximum, ldec_a_min_floor, ldec_add_on_ceiling
Decimal	ldec_bpaf_n1_1, ldec_bpaf_n1_2, ldec_bpaf_td_1, ldec_bpaf_td_2, ldec_NI, ldec_BPAF, ldec_BPAF_diff, ldec_BPAF_factor
Decimal	ldec_federal_td1_claim, ldec_emp_federal_td1_claim, ldec_fed_federal_td1_claim, ldec_provincial_td1_claim
Decimal	ldec_cpp_annual_maximum, ldec_ei_annual_max_premium, ldec_qpip_annual_max_premium
Decimal	ldec_k_1, ldec_k_2, ldec_k_3, ldec_k_4, ldec_k_5, ldec_k, ldec_k4, ldec_k1_prov, ldec_k2_prov, ldec_k4_prov
Decimal	ldec_a_min_1, ldec_a_min_2, ldec_a_min_3, ldec_a_min_4, ldec_a_min_5
Decimal  ldec_td1_claim_from_prov, ldec_provincial_claim, ldec_canada_employment_credit
Decimal	ldec_annualized_cpp, ldec_annualized_ei, ldec_annualized_qpip
Decimal	ldec_cpp_base_rate, ldec_cpp_multiplier, ldec_cpp_base_maximum
Decimal	ldec_t3

n_bo_employee	lbo_employee

//Get province for tax calcs
lbo_employee = CREATE n_bo_employee
lbo_employee.of_SetTransaction()
li_rc = lbo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' and employee = " + String(al_employee))
IF li_rc < 0 THEN
	this.of_prcent_err("Error reading employee", 0, ads_msg)
	RETURN -1
END IF
ldec_emp_federal_td1_claim	= lbo_employee.of_GetItemDecimal(1, "federal_td1_claim")
ldec_provincial_td1_claim	= lbo_employee.of_GetItemDecimal(1, "provincial_td1_claim")
ls_prov							= lbo_employee.of_GetItemString(1, "tax_province")
DESTROY lbo_employee


//federal tax table is in abio db
SELECT federal_td1_claim,
       (CASE :ls_prov WHEN 'QC' THEN qpp_annual_maximum ELSE cpp_annual_maximum END),
       (CASE :ls_prov WHEN 'QC' THEN qei_annual_max_premium ELSE ei_annual_max_premium END),
		 qpip_annual_max_premium,
		 a_min_1,
		 a_min_2,
		 a_min_3,
		 a_min_4,
		 a_min_5,
		 r_1,
		 r_2,
		 r_3,
		 r_4,
		 r_5,
		 k_1,
		 k_2,
		 k_3,
		 k_4,
		 k_5,   
		 federal_tax.bpaf_n1_1,   
		 federal_tax.bpaf_n1_2,   
		 federal_tax.bpaf_td_1,   
		 federal_tax.bpaf_td_2,  
		 canada_employment_credit,
		 cpp_base_rate, cpp_multiplier, cpp_base_maximum
  INTO :ldec_fed_federal_td1_claim,
       :ldec_cpp_annual_maximum,
       :ldec_ei_annual_max_premium,
       :ldec_qpip_annual_max_premium,
  		 :ldec_a_min_1, 
       :ldec_a_min_2, 
		 :ldec_a_min_3, 
		 :ldec_a_min_4, 
		 :ldec_a_min_5, 
		 :ldec_r_1, 
       :ldec_r_2, 
		 :ldec_r_3, 
		 :ldec_r_4, 
		 :ldec_r_5, 
		 :ldec_k_1, 
		 :ldec_k_2, 
		 :ldec_k_3, 
		 :ldec_k_4, 
		 :ldec_k_5, 
		 :ldec_bpaf_n1_1,   
		 :ldec_bpaf_n1_2,   
		 :ldec_bpaf_td_1,   
		 :ldec_bpaf_td_2,  
		 :ldec_canada_employment_credit,
		 :ldec_cpp_base_rate, :ldec_cpp_multiplier, :ldec_cpp_base_maximum
  FROM federal_tax
 WHERE federal_tax.effective_date = (SELECT MAX(effective_date) 
                                           FROM federal_tax
													   WHERE effective_date <= :adt_max_date)
 USING sqlca;
IF sqlca.sqlcode <> 0 THEN
	this.of_prcent_err("Can't find federal tax entry for " + String(adt_max_date, 'yyyy.mm.dd'), 0, ads_msg)
	RETURN -1
END IF

//Use the maximum value to accomodate a mid-year change from CRA
IF adt_max_date < DateTime(Date(2020,1,1), Time(0,0,0)) THEN
	ldec_federal_td1_claim = Max(ldec_emp_federal_td1_claim, ldec_fed_federal_td1_claim)
ELSE
	//The federal Basic Personal Amount (BPAF) has been changed from $12,298.00 to the following formula and  the new factors BPAF and NI have been created and added to the Chapter 4 — Glossary.  
	//
	//Where NI* <=  150473, BPAF = 13,229
	//
	//Where NI* > 150,473,
	//
	//BPAF** = 12,298 + [(13,229-12,298) - (13,229-12,298) × Lesser of (1, (NI - 150,473)/(214,368-150,473))***]
	//
	//* Variable NI represents Net Income = A + HD
	//
	//** If the BPAF has three or more digits after the decimal point, increase the second digit after the decimal point by one if the third digit is five or more, and drop the third digit. If the third digit after the decimal point is less than five, drop the third digit
	//
	//*** Note that there is no rounding on this division
	ldec_NI = adec_A + ibo_employee.of_GetItemDecimal(1, 'federal_zone_deduction')
	IF ldec_NI <= ldec_bpaf_n1_1 THEN
		ldec_BPAF = ldec_bpaf_td_1
	ELSE
		ldec_BPAF_diff = ldec_bpaf_td_1 - ldec_bpaf_td_2
		ldec_BPAF_factor = (ldec_NI - ldec_bpaf_n1_1)/(ldec_bpaf_n1_2 - ldec_bpaf_n1_1)
		IF ldec_BPAF_factor > 1 THEN ldec_BPAF_factor = 1
		ldec_BPAF = ldec_bpaf_td_2 + ldec_BPAF_diff - (ldec_BPAF_diff * ldec_BPAF_factor)
	END IF
	
	//employees still get to choose a higher federal deduction, 
	//based on having more tax writeoffs (i.e. children)
	ldec_federal_td1_claim = Max(ldec_emp_federal_td1_claim, ldec_BPAF)
	
	//Canada Employment Amount Credit (K4)
	//The federal K4 calculation has been simplified. Factor CEA has been created and added to the Glossary. It’s value can be found in Table 9.2 Other rates and amounts.
	//
	//K4 = The lesser of:
	//
	//(i) 0.15 × A; and
	//
	//(ii) 0.15 × CEA
	//
	//CEA is an indexed amount. See Table 9.2 Other rates and amounts in Chapter 9.
	//P is the number of pay periods in the year
	ldec_k4 = ldec_r_1 * Min(adec_a, ldec_canada_employment_credit)
	
END IF

//Get income bracket for federal taxes
ldec_r = ldec_r_1
ldec_k = ldec_k_1

IF adec_a > ldec_a_min_2 THEN
   ldec_r = ldec_r_2
   ldec_k = ldec_k_2
END IF

IF adec_a > ldec_a_min_3 THEN
   ldec_r = ldec_r_3
   ldec_k = ldec_k_3
END IF

IF adec_a > ldec_a_min_4 THEN
   ldec_r = ldec_r_4
   ldec_k = ldec_k_4
END IF

IF ldec_a_min_5 <> 0 THEN	//prior to 2016 there were only 4 rows, so those entries this is 0.
	IF adec_a > ldec_a_min_5 THEN
		ldec_r = ldec_r_5
		ldec_k = ldec_k_5
	END IF
END IF

// STEP 2:
// Calculate the basic federal tax on the estimated annual taxable income, 
// after allowable federal non-refundable tax credits. The basic federal tax is factor T3.

// annual basic federal tax
// T1 - Annual federal tax deduction
// Calculate the annual federal tax payable. This is factor T1.

//T3        =     Annual basic federal tax
//          =     (R × A) – K – K1 – K2* – K3 – K4
//                 If the result is negative, T3 = $0.
ldec_t3 = max(0, 																								&
				(ldec_r * adec_a) 								/* tax rate * annual income */	&
				- ldec_k 											/* federal constant */				&
				- (ldec_r_1 * ldec_federal_td1_claim) 		/* Federal non-refundable personal tax credit */	&
				- adec_k2											/* CPP and EI contributions */ 	&
				- ldec_k4 											/* ldec_r_1 * Min(adec_a, ldec_canada_employment_credit) */  )																					
	
//T1    =      Annual federal tax deduction, except for employees in Quebec, outside Canada, and in Canada beyond the limits
//                of any province or territory
//
//        =      T3 – (P × LCF)*
//                * If the result is negative, enter $0.
//adec_t1 = max(0, &
//				ldec_t3 -  (ai_pay_period_per_year * Min( ldec_lcf_percent * 
//							 amount deducted or withheld for the pay period for the acquisition, by the employee, of approved
//                      shares of the capital stock of a prescribed labour-sponsored venture capital corporation,
//							 ldec_lcf))	/* labour fund */

// STEP 3:
// Calculate the annual federal tax payable. This is factor T1.
//  -------ignore labour fund for now, we don't have a field to map labour fund deductions
adec_t1 = ldec_t3

// STEP 4:
// Calculate the basic provincial or territorial tax on the estimated annual taxable income, after allowable 
// provincial or territorial personal tax credits. The annual basic provincial or territorial tax is factor T4.

//Work out provincial taxes
ldec_v_rate_ceiling 	= 0
ldec_v1 	= 0
ldec_v2 	= 0
ldec_s 	= 0
ll_kp_constant_ceiling 	= 0
ldec_t4 	= 0
ldec_k4_prov = 0

//Provincial TD1 Claim
IF Not(IsValid(ibo_province_rate)) THEN
	ibo_province_rate = CREATE n_bo_province_rate
	ibo_province_rate.of_SetTransaction(sqlca)
END IF

IF ibo_province_rate.of_Retrieve("province = '" + ls_prov &
		+ "' AND CONVERT(varchar, effective_date, 112) <= '" + String(adt_max_date, "YYYYMMDD") + &
		+ "' AND CONVERT(varchar, expiry_date, 112) > '" + String(adt_max_date, "YYYYMMDD") + "'") = 1 THEN
	ldec_td1_claim_from_prov = ibo_province_rate.of_GetItemDecimal(1, 'provincial_td1_claim')
ELSE
	this.of_inc_tax_error("No Provincial tax rates have been entered for " + ls_prov + ", effective for " + String(adt_max_date, 'yyyy.mm.dd'))
	RETURN -1
END IF

//Get basic tax brackets
IF this.of_get_provincial_constants(ls_prov, 						&
												'B', 								&
												adt_max_date, 					&
												adec_a, 							&
												ldec_a_min_floor,  			&
												ldec_a_min_ceiling,  		&
												ldec_a_min_maximum,			&
												ldec_v_rate_minimum,  		&
												ldec_v_rate_ceiling, 		&
												ll_kp_constant_floor,  		&
												ll_kp_constant_ceiling,  	&
												ldec_add_on_ceiling) = -1 THEN
	RETURN -1
END IF

IF ls_prov = 'YT' OR ls_prov = 'NS' THEN
	//Basic Personal Amount -- overrides the provincial TD1 claim
	li_rc = this.of_get_provincial_tax_BP(ls_prov, adec_a, adt_max_date, ldec_provincial_claim)
	CHOOSE CASE li_rc
		CASE  -1 
			RETURN -1
		CASE 0
			//No rows found in the tax table, use the value from the provincial rate
			ldec_provincial_claim = MAX(ldec_provincial_td1_claim, ldec_td1_claim_from_prov)
	END CHOOSE
ELSE
	//This part of the  tax calculation is consistent across all provinces
	// LG: April 1, 2009:  Select MAX between employee provincial td1 claim and from
	//  province_rate table;
	// ldec_td1_claim_from_prov, added as ref variable from of_get_provincial_constants
	
	//well, it was.  Now yukon has a different calculation,
	//   https://www.canada.ca/en/revenue-agency/services/forms-publications/payroll/t4127-payroll-deductions-formulas/t4127-jul/t4127-jul-payroll-deductions-formulas.html#toc5
	//so we'll override the provincial clam
	//above
	ldec_provincial_claim = MAX(ldec_provincial_td1_claim, ldec_td1_claim_from_prov)
END IF
		
ldec_k1_prov = ldec_v_rate_minimum * ldec_provincial_claim

//Quebec Parental Insurance Premiums provincial tax credits for the year
IF ls_prov = 'QC' THEN
	IF adec_emp_qpip_premium >= ldec_qpip_annual_max_premium THEN
		ldec_annualized_qpip = ldec_qpip_annual_max_premium
	ELSE
		ldec_annualized_qpip = min(ai_pay_period_per_year * adec_qpip_premium, ldec_qpip_annual_max_premium)
	END IF
ELSE
	ldec_annualized_qpip = 0
END IF

IF Date(adt_max_date) < Date(2023,01,01) THEN
	//Canada Pension Plan contributions provincial tax credits for the year 
	IF adec_emp_cpp_contribution >= ldec_cpp_annual_maximum THEN
		ldec_annualized_cpp = ldec_cpp_annual_maximum
	ELSE
		ldec_annualized_cpp = min(ai_pay_period_per_year * adec_cpp_contribution, ldec_cpp_annual_maximum)
	END IF
	
	//employment insurance premiums provincial tax credits for the year  
	IF adec_emp_ei_premium >= ldec_ei_annual_max_premium THEN
		ldec_annualized_ei = ldec_ei_annual_max_premium
	ELSE
		ldec_annualized_ei = min(ai_pay_period_per_year * adec_ei_premium, ldec_ei_annual_max_premium)
	END IF
	
ELSE
	//New calculations for 2023
	//K2P     =     [(Lowest provincial tax rate × (P × C × (0.0495/0.0595), maximum $3,123.45 × (PM/12))) + 
	//               (Lowest provincial tax rate × (P × EI, maximum $1,002.45))]
	
	// P × C × (0.0495/0.0595), maximum $3,123.45
	ldec_annualized_cpp =  ai_pay_period_per_year * adec_cpp_contribution * (ldec_cpp_base_rate/ldec_cpp_multiplier)
	IF ldec_annualized_cpp > ldec_cpp_annual_maximum * (ldec_cpp_base_rate/ldec_cpp_multiplier) THEN
		ldec_annualized_cpp = ldec_cpp_annual_maximum * (ldec_cpp_base_rate/ldec_cpp_multiplier)
	END IF
	ldec_annualized_cpp *= ai_cpp_months/12
	
	// P × EI, maximum $1,002.45
	ldec_annualized_ei =  ai_pay_period_per_year * adec_ei_premium
	IF ldec_annualized_ei > ldec_ei_annual_max_premium THEN
		ldec_annualized_ei = ldec_ei_annual_max_premium
	END IF
	
END IF

//apply lowest provincial tax rate to cpp/ei/qpip to get K2 provincial factor
ldec_k2_prov = ldec_v_rate_minimum * Round(ldec_annualized_cpp + ldec_annualized_ei + ldec_annualized_qpip, 2)

ldec_t4 = (ldec_v_rate_ceiling * adec_a) 	&
			- ll_kp_constant_ceiling 					&
			- ldec_k1_prov 		&
			- ldec_k2_prov			

//Special taxes for special provinces
CHOOSE CASE ls_prov
   CASE "BC"                                        
		//Provincial tax reduction
		IF this.of_get_provincial_constants(ls_prov, 					&
														'S', 							&
														adt_max_date, 				&
														adec_a, 						&
														ldec_a_min_floor, 		&
														ldec_a_min_ceiling, 		&
														ldec_a_min_maximum, 		&
														ldec_v_rate_minimum, 	&
														ldec_v_rate_ceiling, 	&
														ll_kp_constant_floor, 	&
														ll_kp_constant_ceiling, &
														ldec_add_on_ceiling) = -1 THEN RETURN -1
		IF adec_a > ldec_a_min_maximum THEN
			ldec_s = 0
		ELSE
			ldec_s = Max(0, Min(ldec_t4, ll_kp_constant_floor - (adec_a - ldec_a_min_floor) * ldec_v_rate_ceiling * 0.01))
		END IF
		
	CASE "NS", 'PE'
		//Provincial Surtax Payable
		IF this.of_get_provincial_tax_v1(ls_prov, ldec_t4, adt_max_date, ldec_v1) = -1 THEN
			RETURN -1
		END IF
		
	CASE 'YT'
		//Provincial Surtax Payable
		IF this.of_get_provincial_tax_v1(ls_prov, ldec_t4, adt_max_date, ldec_v1) = -1 THEN
			RETURN -1
		END IF
		
		//Also , the K4P
		//K4P = The lesser of:
		//
		//(i) 0.064 × A*; and
		//(ii) 0.064 × CEA
		IF adec_a * ldec_r_1 < ldec_canada_employment_credit THEN
			ldec_k4_prov = ldec_v_rate_minimum * adec_a 
		ELSE
			ldec_k4_prov = ldec_v_rate_minimum * ldec_canada_employment_credit
		END IF
		
		ldec_t4 -= ldec_k4_prov
		
   CASE "ON"                                        
		//Provincial Surtax Payable
		IF this.of_get_provincial_tax_v1(ls_prov, ldec_t4, adt_max_date, ldec_v1) = -1 THEN
			RETURN -1
		END IF

		//Provincial tax reduction
		IF this.of_get_provincial_constants(ls_prov, 						&
														'S', 								&
														adt_max_date, 					&
														adec_a,							&
														ldec_a_min_floor,				&
														ldec_a_min_ceiling, 			&
														ldec_a_min_maximum, 			&
														ldec_v_rate_minimum, 		&
														ldec_v_rate_ceiling, 		&
														ll_kp_constant_floor, 		&
														ll_kp_constant_ceiling, 	&
														ldec_add_on_ceiling) = -1 THEN RETURN -1
		
		ldec_s = Min(0, Max(0, Min(ldec_t4, ll_kp_constant_ceiling - (adec_a - ldec_a_min_floor) * ldec_v_rate_ceiling)))

		//Ontario Health Premium 
		li_rc = this.of_get_provincial_constants(ls_prov, 							&
																'V2', 							&
																adt_max_date, 					&
																adec_a, 							&
																ldec_a_min_floor, 			&
																ldec_a_min_ceiling, 			&
																ldec_a_min_maximum, 			&
																ldec_v_rate_minimum, 		&
																ldec_v_rate_ceiling, 		&
																ll_kp_constant_floor, 		&
																ll_kp_constant_ceiling, 	&
																ldec_add_on_ceiling) 
		CHOOSE CASE li_rc 
			CASE -1 
				RETURN -1
			CASE 1
				ldec_v2 = Min(ll_kp_constant_ceiling, ll_kp_constant_floor + ldec_v_rate_ceiling * (adec_a - ldec_a_min_floor)) 
		END CHOOSE
				
   CASE "NL"  
		//Temporary Deficit Reduction Levy
		li_rc = this.of_get_provincial_constants(ls_prov, 							&
															  'V2', 								&
															  adt_max_date, 					&
															  adec_a, 							&
															  ldec_a_min_floor,				&
															  ldec_a_min_ceiling, 			&
															  ldec_a_min_maximum, 			&
															  ldec_v_rate_minimum, 			&
															  ldec_v_rate_ceiling, 			&
															  ll_kp_constant_floor, 		&
															  ll_kp_constant_ceiling, 		&
															  ldec_add_on_ceiling) 
		CHOOSE CASE li_rc 
			CASE -1 
				RETURN -1
			CASE 1
				ldec_v2 = ldec_add_on_ceiling + ldec_v_rate_ceiling * Min(ll_kp_constant_ceiling, (adec_a - ldec_a_min_floor)) 
		END CHOOSE
				
END CHOOSE


//provincial tax
//T2 = T4 + V1 + V2 – S – (P × LCP)
//        If the result is negative, T2 = $0.
//				** currently don't have an option to record investments in labour sponsored funds, so ignore P x LCP **
adec_t2 = max(0, ldec_t4 + ldec_v1 + ldec_v2 - ldec_s)

RETURN 1
end function

public function integer of_get_employer_union_dues_paid (string as_book, long al_employee, string as_trade_union, datetime adt_issue_date, ref decimal adec_employer_union_dues);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_get_employer_union_dues_paid
// Author   :	Monica Petersen
// Date     :	2023/02/10
// 	
// Arguments:	string as_book
// 				long al_employee
// 				string as_trade_union
// 				datetime adt_issue_date
// 				decimal adec_union_dues
// 	
// Returns:		integer
// 	
// Desc:			ISSL has requested a cap on the dues paid by
//					the employer, so this mimics the cap on dues
//					paid by the employee
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Int		li_return, li_year, li_month
String	ls_where

li_year = Year(Date(adt_issue_date))
li_month = Month(Date(adt_issue_date))

//The union remittance is dues, pension and RRSP all folded up
//It also includes a monthly remittance.  So, if the user is
//saying there's a cap on union dues, they should include the 
//monthly remittance in the cap amount

//Note: we'll read this off the trade union child so we don't
//include other union's dues in this calculation
SELECT sum(pr_cheque_trade_union.union_remittance - pr_cheque_trade_union.union_pension - pr_cheque_trade_union.union_rrsp)
  INTO :adec_employer_union_dues
  FROM pr_cheque LEFT OUTER JOIN pr_cheque_trade_union 
  						ON pr_cheque.book = pr_cheque_trade_union.book 
					  AND pr_cheque.cheque_no = pr_cheque_trade_union.cheque_no
 WHERE pr_cheque.book = :as_book
   AND pr_cheque.employee = :al_employee
   AND IsNull(pr_cheque_trade_union.trade_union, pr_cheque.trade_union) = :as_trade_union
	AND Year(pr_cheque.issue_date) = :li_year
	AND Month(pr_cheque.issue_date) = :li_month
	AND pr_cheque.cheque_status in ('P','R')
 USING sqlca;
IF sqlca.sqlcode = -1 THEN
	gnv_error.of_add(90,gs_last_window,"R","Error summing employer union dues from pr_cheque",-1,ls_where,"pr_cheque")
	SetNull(adec_employer_union_dues)
	li_return = -1
ELSE 
	IF IsNull(adec_employer_union_dues) THEN adec_employer_union_dues = 0
	li_return = 1
END IF

Return li_return
								
								
								
end function

public function integer of_tax_calc_union_remittance (long al_employee, datetime adt_issue, n_cst_business abo_trade_union_rate, ref n_cst_business abo_pr_ck_or_trade_union, integer ai_row, decimal adec_reg_earn, ref n_ds ads_msg);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_union_remittance
// Author   :	Monica Petersen
// Date     :	2017/05/08
// 	
// Arguments:	n_cst_business abo_trade_union_rate
// 				n_cst_business abo_pr_ck
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

Long		ll_msg_row
Decimal	ldec_remit_reg, ldec_remit_tah, ldec_remit_ovr, ldec_hours
Decimal	ldec_employer_union_dues_for_month, ldec_union_dues_only_remittance

// employer portion that is based on hourly amounts

//1. Remittance rates include pension and RRSP, but with the new trade_union_trade_level_rrsp_pension table,
//   you can specify different pension and RRSP.  So first subtract out the default hourly rates	
ldec_remit_reg = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_reg_hr') 		&
					- abo_trade_union_rate.of_GetItemDecimal(1, 'remit_rrsp_reg_hr') 	&
					- abo_trade_union_rate.of_GetItemDecimal(1, 'remit_pen_reg_hr')
ldec_remit_tah = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_tah_hr') 		&
					- abo_trade_union_rate.of_GetItemDecimal(1, 'remit_rrsp_tah_hr') 	&
					- abo_trade_union_rate.of_GetItemDecimal(1, 'remit_pen_tah_hr')
ldec_remit_ovr = abo_trade_union_rate.of_GetItemDecimal(1, 'remit_ovr_hr') 		&
					- abo_trade_union_rate.of_GetItemDecimal(1, 'remit_rrsp_ovr_hr') 	&
					- abo_trade_union_rate.of_GetItemDecimal(1, 'remit_pen_ovr_hr')

//2. Calculate the portion of the union remittance exclusive of the pension and RRSP
//    Note: the pension and rrsp will be recorded in the 'add_to_union_remittance' field, 
//          leaving the union_remittance field holding only the employer union dues
ldec_hours = abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'reg_hour') 
IF ibo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN 
	ldec_hours += abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'travel_hour')	//jira 1652
END IF

ldec_union_dues_only_remittance = round(ldec_hours * ldec_remit_reg &
															+ abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'tah_hour') * ldec_remit_tah &
															+ abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'ovr_hour') * ldec_remit_ovr, 2)
				
//don't exceed the maximum field dues in a month.
IF abo_trade_union_rate.of_GetItemDecimal(1, 'max_monthly_employer_dues') > 0 THEN
	IF this.of_get_employer_union_dues_paid(gnv_app.is_book, 													&
												al_employee, 			&
												abo_trade_union_rate.of_GetItemString(1, 'trade_union'), 		&
												adt_issue, 	&
												ldec_employer_union_dues_for_month) = -1 THEN
		ll_msg_row = ads_msg.InsertRow(0)
		ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck_or_trade_union.of_GetItemNumber(ai_row, 'cheque_no'))
		ads_msg.SetItem(ll_msg_row, 'message', "Error calculating dues paid")
		RETURN -1
	END IF
	
	IF ldec_employer_union_dues_for_month + ldec_union_dues_only_remittance > abo_trade_union_rate.of_GetItemDecimal(1, 'max_monthly_employer_dues') THEN
		// Cap the dues taken on this cheque, but not a negative amount
		abo_pr_ck_or_trade_union.of_SetItem(ai_row, 'union_remittance', &
			Max(0, abo_trade_union_rate.of_GetItemDecimal(1, 'max_monthly_employer_dues') - ldec_employer_union_dues_for_month))
	ELSE
		//Still room under the cap for the full amount of union dues
		abo_pr_ck_or_trade_union.of_SetItem(ai_row, 'union_remittance', ldec_union_dues_only_remittance)                
	END IF
ELSE
	//No cap, take the full amount of union dues
	abo_pr_ck_or_trade_union.of_SetItem(ai_row, 'union_remittance', ldec_union_dues_only_remittance)                
END IF
		
//Remittances not based on hours
CHOOSE CASE abo_trade_union_rate.of_GetItemString(1, 'remit_earning_type')
	CASE 'B'
		abo_pr_ck_or_trade_union.of_SetItem(ai_row, 'union_remittance', abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'union_remittance') 	&
											 + round(abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'all_hr_base_earn') * abo_trade_union_rate.of_GetItemDecimal(1, 'remit_reg_earn'), 2))  
	CASE 'E'
		// add in employer portion that is based on earnings
		IF abo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN adec_reg_earn += abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'travel_earn') 	//jira 1652

		abo_pr_ck_or_trade_union.of_SetItem(ai_row, 'union_remittance', abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'union_remittance') 	&
											 + round(adec_reg_earn * abo_trade_union_rate.of_GetItemDecimal(1, 'remit_reg_earn') &
														 + abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'tah_earn') * abo_trade_union_rate.of_GetItemDecimal(1, 'remit_tah_earn') &
														 + abo_pr_ck_or_trade_union.of_GetItemDecimal(ai_row, 'ovr_earn') * abo_trade_union_rate.of_GetItemDecimal(1, 'remit_ovr_earn'), 2))  
END CHOOSE

RETURN 1
end function

public function integer of_tax_calc_vacation_stat_this_ts (long al_ts_row, n_cst_business abo_trade_union_rate, long al_tur_row, ref decimal adec_vacation_source_earn, ref decimal adec_statutory_source_earn, decimal adec_statutory_percent_for_this_ts);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_source_earnings_vac_stat
// Author   :	Monica Petersen
// Date     :	2017/05/05
// 	
// Arguments:	long al_ts_row
// 				n_cst_business abo_trade_union_rate
// 				n_cst_business abo_premium_type
// 				decimal adec_vacation_source_earn
// 				decimal adec_vacation_premium_earn
// 				decimal adec_statutory_source_earn
// 				decimal adec_statutory_premium_earn
// 				decimal adec_dues_premium_earn
// 				decimal adec_rrsp_premium_earn
// 				decimal adec_pension_premium_earn
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

Decimal	ldec_hours, ldec_vacation_premium_earn, ldec_statutory_premium_earn, ldec_all_hrs_at_base_earn, ldec_all_hrs_at_reg_earn
Decimal	ldec_paid_sick_leave, ldec_hourly_earnings
Long	ll_tsp_row, ll_tsp_rows, ll_pt_row

ll_tsp_rows = ibo_timesheet_premium.of_RowCount()

//================================
//Calculate all hours at base rate
ldec_hours = ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_hour') 	&
									+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') &
									+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') 
									
IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'include_travel_flag') = 'Y' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'travel_hour')
ldec_all_hrs_at_base_earn = Round(ldec_hours * ibo_timesheet.of_GetItemDecimal(al_ts_row, 'base_rate'), 2) 
ldec_all_hrs_at_reg_earn = Round(ldec_hours * ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_rate'), 2) 
//================================

	//First, calculate the hourly amount
ldec_paid_sick_leave = &
				Round(  abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_reg_hr")  * ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_hour') &
						+ abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_tah_hr")  * ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') &
						+ abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_ovr_hr")  * ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') &
						, 2)
	
//Now, what kind of earnings are the rates applied towards?
CHOOSE CASE ibo_trade_union_rate.of_GetItemString(1, 'paid_sick_type') 
	CASE 'B'
		//All hours at base rate
		ldec_paid_sick_leave += Round(  abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_reg_earn") &
										 * ldec_all_hrs_at_base_earn, 2)
	CASE 'R'
		//All hours at base rate
		ldec_paid_sick_leave += Round(  abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_reg_earn") &
										 * ldec_all_hrs_at_reg_earn, 2)
	CASE 'E'
		//Hourly earnings
		ldec_paid_sick_leave += Round(  abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_reg_earn") &
										* ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_earn') &
									 + abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_tah_earn") &
										* ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_earn') &
									 + abo_trade_union_rate.of_GetItemDecimal(al_tur_row, "paid_sick_ovr_earn") &
										* ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_earn'), 2)
END CHOOSE

//---------------------------
//For vacation and stat pay type 'scheduled', we have to go back to the timesheet to check the spot flags
//because that tells us whether the tah/ovr was scheduled or not
//---------------------------
IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'statutory_pay_type') = 'B' 	&
OR abo_trade_union_rate.of_GetItemString(al_tur_row, 'vacation_pay_type') = 'B' 		&
OR abo_trade_union_rate.of_GetItemString(al_tur_row, 'statutory_pay_type') = 'S' 	&
OR abo_trade_union_rate.of_GetItemString(al_tur_row, 'vacation_pay_type') = 'S' THEN

	//Timesheet premiums to be included in Statutory earnings
	CHOOSE CASE abo_trade_union_rate.of_GetItemString(al_tur_row, 'statutory_pay_type') 
		CASE 'B'	

			FOR ll_tsp_row = 1 TO ll_tsp_rows
				ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
				IF ll_pt_row > 0 THEN
					IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'Y' THEN
						ldec_statutory_premium_earn += ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
												 + (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
												 + (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
					END IF
				END IF
			NEXT

		CASE 'S' 
			FOR ll_tsp_row = 1 TO ll_tsp_rows
				ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
				IF ll_pt_row > 0 THEN
					IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'Y' THEN
						ldec_statutory_premium_earn += ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') 
						//Overtime premiums accumulate at regular rates
						IF ibo_timesheet.of_GetItemString(al_ts_row, 'tah_spot_flag') = 'N' THEN ldec_statutory_premium_earn += (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
						IF ibo_timesheet.of_GetItemString(al_ts_row, 'ovr_spot_flag') = 'N' THEN ldec_statutory_premium_earn += (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
					END IF
				END IF
			NEXT
	END CHOOSE
	
	//Timesheet premiums to be included in Vacation earnings
	CHOOSE CASE abo_trade_union_rate.of_GetItemString(al_tur_row, 'vacation_pay_type') 
		CASE 'B'	

			FOR ll_tsp_row = 1 TO ll_tsp_rows
				ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
				IF ll_pt_row > 0 THEN
					IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'Y' THEN
						ldec_vacation_premium_earn += ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') &
												 + (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate')) &
												 + (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
					END IF
				END IF
			NEXT
			
		CASE 'S' 
			FOR ll_tsp_row = 1 TO ll_tsp_rows
				ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
				IF ll_pt_row > 0 THEN
					IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'Y' THEN
						ldec_vacation_premium_earn += ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn') 
						//Overtime premiums accumulate at regular rates
						IF ibo_timesheet.of_GetItemString(al_ts_row, 'tah_spot_flag') = 'N' THEN ldec_vacation_premium_earn += (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
						IF ibo_timesheet.of_GetItemString(al_ts_row, 'ovr_spot_flag') = 'N' THEN ldec_vacation_premium_earn += (ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour') * ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'))
					END IF
				END IF
			NEXT
	END CHOOSE
END IF

//---------------------------
//Accumulate timesheet amounts into STATUTORY_SOURCE_EARN
//---------------------------
//Non staff, base on pay type
CHOOSE CASE abo_trade_union_rate.of_GetItemString(al_tur_row, 'statutory_pay_type')
	CASE 'B' //Base - includes overtime, hours are calculated at the base occupation rate, plus premiums as indicated by holiday_earn_flag = 'Y'
		adec_statutory_source_earn += ldec_all_hrs_at_base_earn
		
	CASE 'H' //Hourly earnings - All hours at the rates they were paid at, less the premium amounts that don't earn holiday pay (we'll take that off last, based on the pr_cheque_premium records)
		ldec_hourly_earnings = ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_earn') 	&
											+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_earn') 	&
											+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_earn') 	
		
		adec_statutory_source_earn	+= ldec_hourly_earnings	

		IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'include_travel_flag') = 'Y' THEN 
			adec_statutory_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'travel_earn') //jira 1652
		END IF
		
	CASE 'R' //Regular earnings - regular earnings only, no overtime, etc.  Includes all premiums
		adec_statutory_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_earn')
		
	CASE 'S'// Scheduled base - EXCLUDES overtime, hours are calculated at the base occupation rate, plus premiums as indicated by holiday_earn_flag = 'Y'
		ldec_hours = ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_hour') 

		// Only add overtime if it was scheduled
		IF ibo_timesheet.of_GetItemString(al_ts_row, 'tah_spot_flag') = 'N' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour')
		IF ibo_timesheet.of_GetItemString(al_ts_row, 'ovr_spot_flag') = 'N' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour')
					  
		IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'include_travel_flag') = 'Y' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'travel_hour')
		adec_statutory_source_earn += Round(ldec_hours * ibo_timesheet.of_GetItemDecimal(al_ts_row, 'base_rate'), 2) 
		
END CHOOSE

//=====================
//These amounts are included regardless of the statutory pay type
adec_statutory_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'retro') 

IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'sick_pay_in_holiday_earning_flag') = 'Y' THEN 
	adec_statutory_source_earn += ldec_paid_sick_leave
END IF
//=====================
		
//---------------------------
//Accumulate timesheet amounts into VACATION_SOURCE_EARN
//---------------------------
CHOOSE CASE abo_trade_union_rate.of_GetItemString(al_tur_row, 'vacation_pay_type')
	CASE 'B' //Base - includes overtime, hours are calculated at the base occupation rate, plus premiums as indicated by holiday_earn_flag = 'Y'
		adec_vacation_source_earn += ldec_all_hrs_at_base_earn
		
	CASE 'H' //Hourly earnings - includes all premiums, and overtime at the rates they were paid at
		ldec_hourly_earnings = ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_earn') 	&
											+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_earn') 	&
											+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_earn') 
											
		adec_vacation_source_earn += ldec_hourly_earnings
											
		IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'include_travel_flag') = 'Y' THEN 
			adec_vacation_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'travel_earn') //jira 1652
		END IF
		
	CASE 'R' //Regular earnings - regular earnings only, no overtime, etc.  Includes all premiums
		adec_vacation_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_earn')
		
	CASE 'K' //Saskatchewan labour code -  vacation compounds on statutory
		adec_vacation_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_earn')	&
											+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_earn') &
											+ ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_earn') 
											
		IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'include_travel_flag') = 'Y' THEN adec_vacation_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'travel_earn')
			
	CASE 'S'// Scheduled base - EXCLUDES overtime, hours are calculated at the base occupation rate, plus premiums as indicated by holiday_earn_flag = 'Y'
		ldec_hours = ibo_timesheet.of_GetItemDecimal(al_ts_row, 'reg_hour')
		
		// Only add overtime if it was scheduled
		IF ibo_timesheet.of_GetItemString(al_ts_row, 'tah_spot_flag') = 'N' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'tah_hour')
		IF ibo_timesheet.of_GetItemString(al_ts_row, 'ovr_spot_flag') = 'N' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'ovr_hour')
					  
		IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'include_travel_flag') = 'Y' THEN ldec_hours += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'travel_hour')
		
		//recalculate earnings at base rate
		adec_vacation_source_earn += Round(ldec_hours * ibo_timesheet.of_GetItemDecimal(al_ts_row, 'base_rate'), 2) 
		
END CHOOSE

//add statutory earnings in because Saskatchewan earns vacation on their statutory ho
CHOOSE CASE abo_trade_union_rate.of_GetItemString(al_tur_row, 'vacation_pay_type')
	CASE 'K' //Saskatchewan labour code -  vacation compounds on statutory
		adec_vacation_source_earn += Round(adec_statutory_source_earn * adec_statutory_percent_for_this_ts * 0.01, 2)
END CHOOSE
	
//=====================
//These amounts are included regardless of the vacation pay type
adec_vacation_source_earn += ibo_timesheet.of_GetItemDecimal(al_ts_row, 'retro') 

IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'sick_pay_in_holiday_earning_flag') = 'Y' THEN 
	adec_vacation_source_earn += ldec_paid_sick_leave
END IF
//=====================

CHOOSE CASE abo_trade_union_rate.of_GetItemString(al_tur_row, 'vacation_pay_type')
	CASE 'B', 'S'
		//Add in premiums that qualify
		adec_vacation_source_earn += ldec_vacation_premium_earn
END CHOOSE		

CHOOSE CASE abo_trade_union_rate.of_GetItemString(al_tur_row, 'statutory_pay_type')
	CASE 'B', 'S'
		//Add in premiums that qualify
		adec_statutory_source_earn += ldec_statutory_premium_earn
END CHOOSE		

//---------------------------
// Add or subtract premium earnings to source earnings according to pay type
//---------------------------
IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'vacation_pay_type') = 'H' THEN
	
	//Premiums are already included in hourly earnings, but we want to eliminate premiums that don't qualify
	FOR ll_tsp_row = 1 TO ll_tsp_rows
		ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
		IF ll_pt_row > 0 THEN
			IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'N' THEN
				adec_vacation_source_earn -= (ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn')		&
														+ ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'tah_earn')	&
														+ ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'ovr_earn'))
			END IF
		END IF
	NEXT
END IF

IF abo_trade_union_rate.of_GetItemString(al_tur_row, 'statutory_pay_type') = 'H' THEN
		
	//Premiums are already included in hourly earnings, but we want to eliminate premiums that don't qualify
	FOR ll_tsp_row = 1 TO ll_tsp_rows
		ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type') + "'")
		IF ll_pt_row > 0 THEN
			IF ibo_premium_type.of_GetItemString(ll_pt_row, 'holiday_earn_flag') = 'N' THEN
				adec_statutory_source_earn -= (ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_earn')		&
														+ ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'tah_earn')	&
														+ ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'ovr_earn'))
			END IF
		END IF
	NEXT
	
END IF

RETURN 1
end function

public function integer of_tax_calc_rrsp_employer_hourly_by_occ (n_cst_business abo_pr_ck_occupation, integer ai_pco_row, n_cst_business abo_trade_union_this_tu, n_cst_business abo_trade_union_rate_this_occupation, date adt_effective, ref n_ds ads_msg, string as_trade_union, string as_occupation, long al_employee);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_rrsp_employer_hourly_by_occ
// Author   :	Monica Petersen
// Date     :	2017/05/16
// 	
// Arguments:	n_cst_business abo_pr_ck_occupation
// 				integer ai_pco_row
// 				n_cst_business abo_trade_union_this_tu
// 				n_cst_business abo_trade_union_rate_this_occupation
// 				date adt_effective
// 				n_ds ads_msg
// 				string as_trade_union
// 				string as_occupation
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

Long		ll_msg_row
Decimal	ldec_hours
Decimal	ldec_reg_rate, ldec_tah_rate, ldec_ovr_rate
String	ls_msg

//=====================
//Let PRCQCR use this routine to get the trade level pension before cheque is approved/transacted
IF Not(IsValid(ibo_trade_union_trade_level_rrsp_pension)) THEN
	ibo_trade_union_trade_level_rrsp_pension = CREATE n_bo_trade_union_trade_level_rrsp_pension
	ibo_trade_union_trade_level_rrsp_pension.of_SetTransaction()
END IF
IF Not(IsValid(ibo_occupation)) THEN
	ibo_occupation = CREATE n_bo_occupation
	ibo_occupation.of_SetTransaction()
END IF
IF Not(IsValid(ibo_employee)) THEN
	ibo_employee = CREATE n_bo_employee
	ibo_employee.of_SetTransaction()
END IF

IF ibo_employee.of_RowCount() = 0 THEN
	IF ibo_employee.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND employee = " + String(al_employee) ) < 1 THEN
		this.of_prcent_err("Can't find employee " + String(al_employee), &
									 abo_pr_ck_occupation.of_GetItemNumber(ai_pco_row, 'cheque_no'), ads_msg)
		RETURN 0
	END IF
END IF
//=====================

//regular hours
ldec_hours = abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'reg_hour')
IF abo_trade_union_rate_this_occupation.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN 
	ldec_hours += abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'travel_hour') //jira 1652
END IF

//Start by calculating the hourly amounts - use trade_level amounts if available
IF ibo_trade_union_trade_level_rrsp_pension.of_Retrieve("book = '" + gnv_app.is_book + "'" &
															+ " AND trade_union = '" + as_trade_union + "'"&
															+ " AND Convert(varchar, effective_date, 112) <= '" + String(adt_effective, 'YYYYMMDD') + "'"&
															+ " AND Convert(varchar, expiry_date, 112) > '" + String(adt_effective, 'YYYYMMDD') + "'") < 0 THEN
	this.of_prcent_err("Cheque " + String(abo_pr_ck_occupation.of_GetItemNumber(ai_pco_row, 'cheque_no')) &
			+ ": Can't find trade union trade level rates for " + abo_pr_ck_occupation.of_GetItemString(ai_pco_row, 'trade_union') &
			+ " effective " + String(adt_effective, 'yyyy.mm.dd'), &
			abo_pr_ck_occupation.of_GetItemNumber(ai_pco_row, 'cheque_no'), ads_msg)
	RETURN -1
END IF

//Get occupation to compare trade levels
IF ibo_occupation.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND trade_union = '" + as_trade_union &
							 + "' AND occupation = '"  + as_occupation + "'") < 1 THEN
	this.of_prcent_err("Can't find occupation " + as_trade_union + "/"+ as_occupation + " for cheque " &
								+ String(abo_pr_ck_occupation.of_GetItemNumber(ai_pco_row, 'cheque_no')), &
								abo_pr_ck_occupation.of_GetItemNumber(ai_pco_row, 'cheque_no'), ads_msg)
	RETURN -1
END IF

IF of_tax_calc_get_trade_level_rates('R', 						&
												 ldec_reg_rate, 			&
												 ldec_tah_rate, 			&
												 ldec_ovr_rate, 			&
												 ls_msg, 					&
												 abo_trade_union_rate_this_occupation, 	&
												 ibo_trade_union_trade_level_rrsp_pension, &
												 abo_trade_union_this_tu, 		&
												 ibo_occupation) < 0 THEN
	ll_msg_row = ads_msg.InsertRow(0)
	ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_ck_occupation.of_GetItemNumber(ai_pco_row, 'cheque_no'))
	ads_msg.SetItem(ll_msg_row, 'message', ls_msg)
	RETURN -1
ELSE
	//Add in the occupation amounts because there may already be base and matching percents
	abo_pr_ck_occupation.of_SetItem(ai_pco_row, 'union_rrsp', &
															abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'union_rrsp') &
															+ round(ldec_hours * ldec_reg_rate &
															+ abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'tah_hour') * ldec_tah_rate &
															+ abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'ovr_hour') * ldec_ovr_rate, 2))
															
	//And add this to the union remit because hourly amounts have previously been removed
	abo_pr_ck_occupation.of_SetItem(ai_pco_row, 'add_to_union_remittance', abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'add_to_union_remittance') &
															+ round(ldec_hours * ldec_reg_rate &
															+ abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'tah_hour') * ldec_tah_rate &
															+ abo_pr_ck_occupation.of_GetItemDecimal(ai_pco_row, 'ovr_hour') * ldec_ovr_rate, 2))

END IF
	


end function

public function integer of_tax_calc_rrsp_employer_hourly_by_occ (n_cst_business abo_pr_ck_occupation, integer ai_pco_row, n_cst_business abo_trade_union_this_tu, n_cst_business abo_trade_union_rate_this_occupation, date adt_effective, ref n_ds ads_msg, string as_trade_union, string as_occupation);
RETURN this.of_tax_calc_rrsp_employer_hourly_by_occ(abo_pr_ck_occupation, ai_pco_row, abo_trade_union_this_tu, abo_trade_union_rate_this_occupation, adt_effective, &
ads_msg, as_trade_union, as_occupation, 0)
end function

public function integer of_tax_calc_pension_employer_by_occ (ref n_cst_business abo_pr_cheque_occupation, integer ai_ck_row, n_cst_business abo_trade_union_rate, date ad_effective_date, n_ds ads_msg, ref decimal adec_union_pension_paid_out, long al_employee);//************************************************************
// Object   :	n_bo_pr_cheque 
// Function :	of_tax_calc_pension_employer_by_occ
// Author   :	Monica Petersen
// Date     :	2017/05/31
// 	
// Arguments:	n_cst_business abo_pr_cheque_occupation
// 				integer ai_ck_row
// 				n_cst_business abo_trade_union_rate
// 				date ad_effective_date
// 				n_ds ads_msg
// 				decimal adec_union_pension_paid_out
// 				decimal adec_union_remittance
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

//regular hours
Decimal	ldec_hours, ldec_reg_rate, ldec_tah_rate, ldec_ovr_rate
Long		ll_msg_row
String	ls_msg

ldec_hours = abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'reg_hour')
IF abo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN ldec_hours += abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'travel_hour') //jira 1652

//=====================
//Let PRCQCR use this routine to get the trade level pension before cheque is approved/transacted
IF Not(IsValid(ibo_trade_union_this_tu)) THEN
	ibo_trade_union_this_tu = CREATE n_bo_trade_union
	ibo_trade_union_this_tu.of_SetTransaction()
END IF
IF Not(IsValid(ibo_trade_union_trade_level_rrsp_pension)) THEN
	ibo_trade_union_trade_level_rrsp_pension = CREATE n_bo_trade_union_trade_level_rrsp_pension
	ibo_trade_union_trade_level_rrsp_pension.of_SetTransaction()
END IF
IF Not(IsValid(ibo_occupation)) THEN
	ibo_occupation = CREATE n_bo_occupation
	ibo_occupation.of_SetTransaction()
END IF

//ensure this occupation is present
IF ClassName(abo_pr_cheque_occupation) = 'n_bo_pr_cheque_occupation' THEN
	string ls_find
	ls_find = "book = '" + gnv_app.is_book &
										 + "' AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ai_ck_row, 'trade_union')  &
										 + "' AND occupation = '" + abo_pr_cheque_occupation.of_GetItemString(ai_ck_row, 'occupation') + "'"
	IF ibo_occupation.of_Find(ls_find) < 1 THEN
		IF ibo_occupation.of_Retrieve(ls_find, FALSE) < 1 THEN /* replace rows */
			this.of_prcent_err("Can't find occupation " + ls_find, &
												0, ads_msg)
			RETURN -1
		END IF
	END IF
END IF

IF Not(IsValid(ibo_employee)) THEN
	ibo_employee = CREATE n_bo_employee
	ibo_employee.of_SetTransaction()
END IF
IF ibo_employee.of_RowCount() = 0 THEN
	IF ibo_employee.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND employee = " + String(al_employee) ) < 1 THEN
		this.of_prcent_err("Can't find employee " + String(al_employee), &
									 abo_pr_cheque_occupation.of_GetItemNumber(ai_ck_row, 'cheque_no'), ads_msg)
		RETURN -1
	END IF
END IF
//=====================

// lookup trade union to get the default trade - used for error flagging if the
// trade union has a trade and the employee doesn't
IF ibo_trade_union_this_tu.of_Retrieve("book = '" + gnv_app.is_book &
										 + "' AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ai_ck_row, 'trade_union') + "'") < 1 THEN
	this.of_prcent_err("Can't find union " + abo_pr_cheque_occupation.of_GetItemString(ai_ck_row, 'trade_union'), &
										0, ads_msg)
	RETURN -1
END IF

//Start by calculating the hourly amounts - use trade_level amounts if available
IF ibo_trade_union_trade_level_rrsp_pension.of_Retrieve("book = '" + gnv_app.is_book + "'" &
															+ " AND trade_union = '" + abo_pr_cheque_occupation.of_GetItemString(ai_ck_row, 'trade_union') + "'"&
															+ " AND Convert(varchar, effective_date, 112) <= '" + String(ad_effective_date, 'YYYYMMDD') + "'"&
															+ " AND Convert(varchar, expiry_date, 112) > '" + String(ad_effective_date, 'YYYYMMDD') + "'") < 0 THEN
	this.of_prcent_err("Cheque " + String(abo_pr_cheque_occupation.of_GetItemNumber(ai_ck_row, 'cheque_no')) &
			+ ": Can't find trade union trade level rates for " + abo_pr_cheque_occupation.of_GetItemString(ai_ck_row, 'trade_union') &
			+ " effective " + String(ad_effective_date, 'yyyy.mm.dd'), &
			abo_pr_cheque_occupation.of_GetItemNumber(ai_ck_row, 'cheque_no'), ads_msg)
	RETURN -1
END IF

//Start by calculating the hourly amounts - use trade_level rates if available
IF of_tax_calc_get_trade_level_rates('P', &
												 ldec_reg_rate, &
												 ldec_tah_rate, &
												 ldec_ovr_rate, &
												 ls_msg, &
												 abo_trade_union_rate, &
												 ibo_trade_union_trade_level_rrsp_pension, &
												 ibo_trade_union_this_tu, &
												 ibo_occupation) < 0 THEN
	ll_msg_row = ads_msg.InsertRow(0)
	//ads_msg.SetItem(ll_msg_row, 'cheque_no', abo_pr_cheque_occupation.of_GetItemNumber(1, 'cheque_no'))
	ads_msg.SetItem(ll_msg_row, 'message', ls_msg)
	RETURN -1
ELSE
	IF ibo_employee.of_GetItemString(1, 'pay_pension_to_cash_flag') = 'Y' THEN
		adec_union_pension_paid_out += round(ldec_hours * ldec_reg_rate &
																+ abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'tah_hour') * ldec_tah_rate &
																+ abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'ovr_hour') * ldec_ovr_rate, 2)
	ELSE
		abo_pr_cheque_occupation.of_SetItem(ai_ck_row, 'union_pension', round(ldec_hours * ldec_reg_rate &
																+ abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'tah_hour') * ldec_tah_rate &
																+ abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'ovr_hour') * ldec_ovr_rate, 2))
																
		//3. Now add in the union_pension, which was calculated using the trade_union_trade_level_pension_pension rate levels, if found.
		abo_pr_cheque_occupation.of_SetItem(ai_ck_row, 'add_to_union_remittance', abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'add_to_union_remittance') &
																+ abo_pr_cheque_occupation.of_GetItemDecimal(ai_ck_row, 'union_pension'))
		
	END IF
END IF

RETURN 1
end function

public function integer of_tax_calc_pension_employer_by_occ (ref n_cst_business abo_pr_cheque_occupation, integer ai_ck_row, n_cst_business abo_trade_union_rate, date ad_effective_date, n_ds ads_msg, ref decimal adec_union_pension_paid_out);
RETURN this.of_tax_calc_pension_employer_by_occ(abo_pr_cheque_occupation, ai_ck_row, abo_trade_union_rate, ad_effective_date, ads_msg, adec_union_pension_paid_out, 0)
end function

on n_bo_pr_cheque.create
call super::create
end on

on n_bo_pr_cheque.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_pr_cheque 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/05/05
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

String			ls_pr_yyyymm
n_bo_company	lbo_company


//merge compares 100+ fields against 100+ fields = 10,000+ loops, which takes 4 seconds,
//so try to avoid merging the business object with the detail datawindow
This.of_setdefaultmerge(FALSE)

// Set the object description to be seen in messages to user
This.of_SetDescription("PR Cheque")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_pr_cheque"

// Set primary key columns
This.of_SetPKColumns({"book","cheque_no"})

// Force a new transaction for this business object
This.of_SetTransaction()

// restrict flag
of_AddValidationRule({"transact_flag"}, "EXPRESSION", &
		"<<transact_flag>> IN ('Y', 'N')", "Costed must be 'Y'es or 'N'o", FALSE)	

of_AddValidationRule({"restrict_flag"}, "EXPRESSION", &
		"<<restrict_flag>> IN ('Y', 'N')", "Restrict? must be 'Y'es or 'N'o", FALSE)	

of_AddValidationRule({"cheque_status"}, "EXPRESSION", &
		"<<cheque_status>> IN ('A', 'P', 'R', 'U')", "Status must be Unapproved, Approved, Printed or Reconciled", FALSE)	

of_AddValidationRule({"reconcile_date"}, "EXPRESSION", &
		" (Today() >= reconcile_date) OR IsNull(reconcile_date) " ,  &
		 "Reconcile Date cannot be in the future", FALSE)			
		  
of_AddValidationRule({"pr_yyyymm"}, "EXPRESSION", &
		"IsNumber(<<pr_yyyymm>>) AND Len(<<pr_yyyymm>>) = 6", &
		"G/L YYYYMM Must be 6 Digits", FALSE)
		
of_AddValidationRule({"pr_yyyymm"}, "EXPRESSION", &
		"(LEFT(<<pr_yyyymm>>,4)  >= '1990' AND LEFT(<<pr_yyyymm>>,4)  <= '2089') AND " + &  
		" (MID(<<pr_yyyymm>>,5,2)  >= '01' AND MID(<<pr_yyyymm>>,5,2)  <= '12')", &
		"Invalid G/L YYYYMM ", FALSE)
		
of_AddValidationRule({"last_taxable_benefit_month"}, "EXPRESSION", &
		"(IsNumber(<<last_taxable_benefit_month>>) AND Len(<<last_taxable_benefit_month>>) = 6) OR <<last_taxable_benefit_month>> = ''", &
		"'taxable benefit to' Must be 6 Digits in the form YYYYMM", FALSE)
		
of_AddValidationRule({"last_taxable_benefit_month"}, "EXPRESSION", &
		"(LEFT(<<last_taxable_benefit_month>>,4)  >= '1990' AND LEFT(<<last_taxable_benefit_month>>,4)  <= '2089') AND " + &  
		" (MID(<<last_taxable_benefit_month>>,5,2)  >= '01' AND MID(<<last_taxable_benefit_month>>,5,2)  <= '12') OR <<last_taxable_benefit_month>> = ''", &
		"Invalid 'taxable benefit to' ", FALSE)
		
of_AddValidationRule({"last_monthly_remit_month"}, "EXPRESSION", &
		"(IsNumber(<<last_monthly_remit_month>>) AND Len(<<last_monthly_remit_month>>) = 6) OR <<last_monthly_remit_month>> = ''", &
		"'monthly remit to' Must be 6 Digits in the form YYYYMM", FALSE)
		
of_AddValidationRule({"last_monthly_remit_month"}, "EXPRESSION", &
		"(LEFT(<<last_monthly_remit_month>>,4)  >= '1990' AND LEFT(<<last_monthly_remit_month>>,4)  <= '2089') AND " + &  
		" (MID(<<last_monthly_remit_month>>,5,2)  >= '01' AND MID(<<last_monthly_remit_month>>,5,2)  <= '12') OR <<last_monthly_remit_month>> = ''", &
		"Invalid 'monthly remit to' ", FALSE)
		
of_AddValidationRule({"last_month_with_dues"}, "EXPRESSION", &
		"(IsNumber(<<last_month_with_dues>>) AND Len(<<last_month_with_dues>>) = 6) OR <<last_month_with_dues>> = ''", &
		"'monthly dues to' Must be 6 Digits in the form YYYYMM", FALSE)
		
of_AddValidationRule({"last_month_with_dues"}, "EXPRESSION", &
		"(LEFT(<<last_month_with_dues>>,4)  >= '1990' AND LEFT(<<last_month_with_dues>>,4)  <= '2089') AND " + &  
		" (MID(<<last_month_with_dues>>,5,2)  >= '01' AND MID(<<last_month_with_dues>>,5,2)  <= '12') OR <<last_month_with_dues>> = ''", &
		"Invalid 'monthly dues to' ", FALSE)

of_AddValidationRule({"eft_date"}, "EXPRESSION", &
		"(<<eft_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR  (<<eft_date>> > Datetime(Date('1990/01/01'),Time('00:00:00.000000')) AND <<eft_date>> < Datetime(Date('2090/01/01'),Time('00:00:00.000000'))) ", "Invalid EFT date", FALSE)	
		
of_AddValidationRule({"last_daily_dues_date"}, "EXPRESSION", &
		"(<<last_daily_dues_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR  (<<last_daily_dues_date>> > Datetime(Date('1990/01/01'),Time('00:00:00.000000')) AND <<last_daily_dues_date>> < Datetime(Date('2090/01/01'),Time('00:00:00.000000'))) ", "Invalid Last Daily Dues date", FALSE)	
		
This.of_AddValidationRule({"eft_account"}, "EXPRESSION", &
		"      (TRIM(<<eft_institution>>) = '' AND TRIM(<<eft_us_routing>>) = '' and TRIM(<<eft_branch>>) = '' and TRIM(<<eft_account>>) = '') "						&
		+ " OR (LEN(TRIM(<<eft_institution>>)) = 0 AND LEN(TRIM(<<eft_us_routing>>)) = 0 AND LEN(TRIM(<<eft_branch>>)) = 0 AND LEN(TRIM(<<eft_account>>)) = 0) "	&
		+ " OR (LEN(TRIM(<<eft_institution>>)) > 0 AND LEN(TRIM(<<eft_branch>>)) > 0 AND LEN(TRIM(<<eft_account>>)) > 0)"  													&
		+ " OR (LEN(TRIM(<<eft_us_routing>>)) > 0 AND LEN(TRIM(<<eft_account>>)) > 0)" , &
		"Either Institution, Branch and Account, or US routing and Account, are Required", TRUE)				
		
// Determine the current company's P/R YYYYMM
lbo_company = CREATE n_bo_company
lbo_company.of_SetTransaction()

IF lbo_company.of_Retrieve("book = '" + gnv_app.is_book + "'") > 0 THEN
	ls_pr_yyyymm = lbo_company.of_GetItemString(1, "pr_yyyymm")
	This.of_AddValidationRule({"pr_yyyymm"}, "EXPRESSION", 	&
			"<<pr_yyyymm>> <= '" + ls_pr_yyyymm + "'", 			&
			"P/R YYYYMM Must be " + ls_pr_yyyymm + ' or earlier', FALSE)
END IF

this.of_setcolumndefault('eft_us_routing', '')
this.of_setcolumndefault('eft_branch', '')
this.of_setcolumndefault('eft_institution', '')
this.of_setcolumndefault('eft_account', '')
this.of_setcolumndefault('last_month_with_dues', '')
this.of_setcolumndefault('admin_fee', '0')
this.of_setcolumndefault('security_deposit', '0')
this.of_setcolumndefault('training', '0')
this.of_setcolumndefault('advance_repay', '0')
this.of_setcolumndefault('vacation_owed', '0')
this.of_setcolumndefault('statutory_owed', '0')
this.of_setcolumndefault('personal_safety_owed', '0')
this.of_setcolumndefault('group_safety_owed', '0')
this.of_setcolumndefault('staff_safety_owed', '0')
this.of_setcolumndefault('smtc_owed', '0')
this.of_setcolumndefault('retention_owed', '0')
this.of_setcolumndefault('incentive_owed', '0')
this.of_setcolumndefault('vacation_earn', '0')
this.of_setcolumndefault('statutory_earn', '0')
this.of_setcolumndefault('personal_safety_earn', '0')
this.of_setcolumndefault('group_safety_earn', '0')
this.of_setcolumndefault('staff_safety_earn', '0')
this.of_setcolumndefault('smtc_earn', '0')
this.of_setcolumndefault('retention_earn', '0')
this.of_setcolumndefault('recruitment_cost', '0')
this.of_setcolumndefault('incentive_earn', '0')
this.of_setcolumndefault('cpp_earn', '0')
this.of_setcolumndefault('ei_earn', '0')
this.of_setcolumndefault('taxable_earn', '0')
this.of_setcolumndefault('reg_hour', '0')
this.of_setcolumndefault('tah_hour', '0')
this.of_setcolumndefault('ovr_hour', '0')
this.of_setcolumndefault('travel_hour', '0')
this.of_setcolumndefault('reg_earn', '0')
this.of_setcolumndefault('tah_earn', '0')
this.of_setcolumndefault('ovr_earn', '0')
this.of_setcolumndefault('travel_earn', '0')
this.of_setcolumndefault('taxable_loa', '0')
this.of_setcolumndefault('nontaxable_loa', '0')
this.of_setcolumndefault('taxable_mileage', '0')
this.of_setcolumndefault('nontaxable_mileage', '0')
this.of_setcolumndefault('turnaround', '0')
this.of_setcolumndefault('taxable_site_allow', '0')
this.of_setcolumndefault('nontaxable_site_allow', '0')
this.of_setcolumndefault('taxi', '0')
this.of_setcolumndefault('meal', '0')
this.of_setcolumndefault('retro', '0')
this.of_setcolumndefault('other_taxable_pay', '0')
this.of_setcolumndefault('personal_safety_paid', '0')
this.of_setcolumndefault('group_safety_paid', '0')
this.of_setcolumndefault('staff_safety_paid', '0')
this.of_setcolumndefault('smtc_paid', '0')
this.of_setcolumndefault('retention_paid', '0')
this.of_setcolumndefault('incentive_paid', '0')
this.of_setcolumndefault('vacation_paid', '0')
this.of_setcolumndefault('statutory_paid', '0')
this.of_setcolumndefault('vacation_hours_paid', '0')
this.of_setcolumndefault('vacation_hours_earn', '0')
this.of_setcolumndefault('vacation_hours_owed', '0')
this.of_setcolumndefault('statutory_hours_paid', '0')
this.of_setcolumndefault('cpp_contribution', '0')
this.of_setcolumndefault('ei_premium', '0')
this.of_setcolumndefault('income_tax', '0')
this.of_setcolumndefault('union_dues', '0')
this.of_setcolumndefault('insurance', '0')
this.of_setcolumndefault('misc_deduction', '0')
this.of_setcolumndefault('charity', '0')
this.of_setcolumndefault('incentive_paid_to_rrsp', '0')
this.of_setcolumndefault('employee_rrsp', '0')
this.of_setcolumndefault('employee_pension', '0')
this.of_setcolumndefault('gross_pay', '0')
this.of_setcolumndefault('net_pay', '0')
this.of_setcolumndefault('wcb_remittance', '0')
this.of_setcolumndefault('union_remittance', '0')
this.of_setcolumndefault('add_to_union_remittance', '0')
this.of_setcolumndefault('employer_rrsp', '0')
this.of_setcolumndefault('union_rrsp', '0')
this.of_setcolumndefault('union_pension', '0')
this.of_setcolumndefault('taxable_benefit', '0')
this.of_setcolumndefault('personal_safety_lost', '0')
this.of_setcolumndefault('group_safety_lost', '0')
this.of_setcolumndefault('staff_safety_lost', '0')
this.of_setcolumndefault('smtc_lost', '0')
this.of_setcolumndefault('retention_lost', '0')
this.of_setcolumndefault('incentive_lost', '0')
this.of_setcolumndefault('all_hr_reg_earn', '0')
this.of_setcolumndefault('all_hr_base_earn', '0')
this.of_setcolumndefault('paid_sick_leave', '0')
this.of_setcolumndefault('reg_fringe', '0')
this.of_setcolumndefault('tah_premium', '0')
this.of_setcolumndefault('ovr_premium', '0')
this.of_setcolumndefault('tah_premium_fringe', '0')
this.of_setcolumndefault('ovr_premium_fringe', '0')
this.of_setcolumndefault('gst_amount', '0')
this.of_setcolumndefault('monthly_dues', '')
this.of_setcolumndefault('shift_premium', '0')
this.of_setcolumndefault('shift_premium_fringe', '0')
this.of_setcolumndefault('vehicle_allowance_paid', '0')
this.of_setcolumndefault('taxable_benefit_gas', '0')
this.of_setcolumndefault('taxable_benefit_vehicle', '0')
this.of_setcolumndefault('pay_in_lieu_of_notice', '0')
this.of_setcolumndefault('vacation_lost', '0')
this.of_setcolumndefault('vacation_hours_lost', '0')
this.of_setcolumndefault('statutory_lost', '0')
this.of_setcolumndefault('production_bonus_earn', '0')
this.of_setcolumndefault('production_bonus_paid', '0')
this.of_setcolumndefault('production_bonus_lost', '0')
this.of_setcolumndefault('production_bonus_lost', '0')
this.of_setcolumndefault('back_dues', '0')
this.of_setcolumndefault('daily_dues', '0')
this.of_setcolumndefault('weekly_dues', '0')
this.of_setcolumndefault('vacation_paid_to_union', '0')
this.of_setcolumndefault('statutory_paid_to_union', '0')
this.of_setcolumndefault('last_weekly_dues_paid_date', '0')
this.of_setcolumndefault('vacation_source_earn', '0')
this.of_setcolumndefault('statutory_source_earn', '0')
this.of_setcolumndefault('rrsp_source_earn', '0')
this.of_setcolumndefault('pension_source_earn', '0')
this.of_setcolumndefault('dues_source_earn', '0')

//Add these as child records so that when a printed cheque is reversed, the related tables are updated as a set
this.of_AddChild("pr_cheque_wcb", 		"n_bo_pr_cheque_wcb")
this.of_AddChild("timesheet", 			"n_bo_timesheet")
this.of_AddChild("timesheet_premium",	"n_bo_timesheet_premium")
this.of_AddChild("pr_cheque_premium", 	"n_bo_pr_cheque_premium")
this.of_AddChild("employee_purchase", 	"n_bo_employee_purchase")

//Add these as child records so that when cheques are issued, the related tables are updated as a set
this.of_AddChild("employee", 				"n_bo_employee")
this.of_AddChild("employee_earning",	"n_bo_employee_earning")
this.of_AddChild("employee_wcb", 		"n_bo_employee_wcb")
this.of_AddChild("pr_cheque_queue", 	"n_bo_pr_cheque_queue")

//Add these as child records so that when cheques are created, the related tables are updated as a set
this.of_AddChild("company",					"n_bo_company")
this.of_AddChild("pr_cheque_trade_union", "n_bo_pr_cheque_trade_union")
this.of_AddChild("pr_cheque_occupation", 	"n_bo_pr_cheque_occupation")
this.of_AddChild("pr_cheque_union_remit",	"n_bo_pr_cheque_union_remit")

RETURN


end event

event bo_overridelogkeycolumns;call super::bo_overridelogkeycolumns;//************************************************************
// Object   :	n_bo_pr_cheque 
// Event    :	bo_overridelogkeycolumns
// Author   :	Monica Petersen
// Date     :	2014/03/20
// 	
// Arguments:	string as_key_column[]
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

as_key_column[1] = "book"
as_key_column[2] = "cheque_no"
as_key_column[3] = "employee"

RETURN
end event

event destructor;call super::destructor;IF IsValid(ibo_company) 				THEN DESTROY ibo_company
IF IsValid(ibo_employee) 				THEN DESTROY ibo_employee
IF IsValid(ibo_employee_earning) 	THEN DESTROY ibo_employee_earning
IF IsValid(ibo_federal_tax) 			THEN DESTROY ibo_federal_tax
IF IsValid(ibo_pay_period) 			THEN DESTROY ibo_pay_period
IF IsValid(ibo_person) 					THEN DESTROY ibo_person
IF IsValid(ibo_pr_cheque_premium) 	THEN DESTROY ibo_pr_cheque_premium
IF IsValid(ibo_premium_type)		 	THEN DESTROY ibo_premium_type
IF IsValid(ibo_timesheet) 				THEN DESTROY ibo_timesheet
IF IsValid(ibo_timesheet_premium) 	THEN DESTROY ibo_timesheet_premium
IF IsValid(ibo_trade_union) 			THEN DESTROY ibo_trade_union
IF IsValid(ibo_trade_union_this_tu) 			THEN DESTROY ibo_trade_union_this_tu
IF IsValid(ibo_trade_union_rate) 	THEN DESTROY ibo_trade_union_rate
IF IsValid(ibo_trade_union_rate_this_ts_or_tu) 	THEN DESTROY ibo_trade_union_rate_this_ts_or_tu
IF IsValid(ibo_trade_union_trade_level_rrsp_pension) 	THEN DESTROY ibo_trade_union_trade_level_rrsp_pension
IF IsValid(ibo_trade_union_trade_level_employee_rrsp) 	THEN DESTROY ibo_trade_union_trade_level_employee_rrsp
IF IsValid(ibo_province_rate) 		THEN DESTROY ibo_province_rate
IF IsValid(ibo_province_income_tax) 		THEN DESTROY ibo_province_income_tax
IF IsValid(ibo_province_education_tax) 	THEN DESTROY ibo_province_education_tax
IF IsValid(ibo_province_payroll_tax) 	THEN DESTROY ibo_province_payroll_tax

end event

