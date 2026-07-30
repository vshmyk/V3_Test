$PBExportHeader$u_cst_pr_employee_detail.sru
forward
global type u_cst_pr_employee_detail from u_cst_datapanel_detail
end type
end forward

global type u_cst_pr_employee_detail from u_cst_datapanel_detail
borderstyle borderstyle = styleshadowbox!
event type integer ue_termination_file ( string as_temp_local_file )
event ue_person_update ( )
event type integer ue_process_print_supervisor ( )
end type
global u_cst_pr_employee_detail u_cst_pr_employee_detail

type prototypes

end prototypes

type variables
Long		il_employee
Long		ii_row
Long		il_history_flag, il_validate_error, il_employee_indicator
Datetime	idt_current_termination_date
String	is_book
String	is_colname
String	is_employment_type
String	is_name, is_name_deleted
String	is_restrict_flag
String	is_message
String	is_current_union_vacation_pay_flag
String	is_original_crew
String	is_current_book, is_current_book_terminated
Boolean  ib_warn_union_changed = FALSE

//Save these as instance variables so when the user comes back
//you don't prompt them again
String	is_ROE_path
Boolean	ib_ROE_exists


//Child tables that get updated in the same transaction set with parent employee
n_bo_person_diary			ibo_person_diary
n_bo_pr_cheque				ibo_pr_cheque
n_bo_timesheet				ibo_timesheet
n_bo_employee_premium 	ibo_employee_premium
n_bo_person					ibo_person
n_bo_crew_member		ibo_crew_member
n_bo_employee_earning ibo_employee_earning_new_emp
n_bo_employee_wcb ibo_employee_wcb_new_emp

n_bo_shift_pattern		ibo_shift_pattern
n_bo_occupation			ibo_occupation
n_bo_trade_union			ibo_trade_union
n_bo_timesheet_premium 	ibo_timesheet_premium
n_bo_crew				ibo_crew

n_bo_company			ibo_company
n_bo_employee_earning ibo_employee_earning
n_bo_roe_reason		 ibo_roe_reason
n_bo_gl_account		 ibo_gl_account
n_bo_area				 ibo_area
n_bo_centre				 ibo_centre
n_bo_job					 ibo_job
n_bo_user				 ibo_user
n_bo_employee			 ibo_employee2
n_bo_application_properties		ibo_application_properties
n_bo_trade_union_rate				ibo_trade_union_rate
n_bo_trade_union_premium			ibo_trade_union_premium
n_bo_federal_tax		ibo_federal_tax
n_bo_province_rate	ibo_province_rate
n_bo_premium_type		ibo_premium_type

end variables

forward prototypes
public function long of_retrieve (s_parm astr_parm)
public function string of_getcurrentfilter ()
public function integer of_set_cc_fields (long al_row)
public function integer of_update_td1_claim_amounts (string as_tax_province)
public function string of_getbokeywhereclause (s_parm astr_parm, ref s_parm astr_retargs, boolean ab_single_quote)
public function integer of_adjust_pay_periods (ref string astr_amounts[])
end prototypes

event type integer ue_termination_file(string as_temp_local_file);	
Integer 			li_fn, li_max_pp_hours, li_days_in_pay_period, li_max_pp_earnings_15b, li_max_pp_earnings_15c
Integer			li_x, li_rows, li_pp
Decimal			ldec_total_hours, ldec_total_earnings, ldec_eiearn, ldec_lieu[], ldec_lieu_total, ldec_carry_forward
String			ls_ccra_business_no, ls_pp[], ls_employment_type
String			ls_trade_union, ls_pay_period_type, ls_roe_name, ls_phone, ls_name
String			ls_address1, ls_address2, ls_support
Datetime			ldt_null, ldt_min_pay_period, ldt_max_pay_period, ldt_hire, ldt_termination, ldt_last_pay
Long				ll_rc, ll_row, ll_pr_rc
n_ds				lds_cheque

SetNull(ldt_null)


ll_row = dw_main.GetRow()

ls_employment_type = ibo_datapanel_business.of_GetItemString(ll_row,"employment_type") 
 

IF ls_employment_type = 'Y' THEN
	
	//Get info for creating ROE
	IF ibo_company.of_get_gst_roe_phone(gnv_app.is_book, ls_ccra_business_no,ls_roe_name, ls_phone) <> 1 THEN
		this.of_msg_db_error("Error reading company")
		RETURN -1
	END IF
	
	IF Len(ls_roe_name) > 0 THEN
	ELSE
		dw_main.POST EVENT ue_setmessage("ROE name not defined for company","Red")		
		MessageBox("Terminate Employee", "Unable to create ROE for this employee, as the ROE name is blank.  Please add it to the Company setup and retry.")
		RETURN -1
	END IF
	
	ls_trade_union = ibo_datapanel_business.of_GetItemString(ll_row,"trade_union") 	
	IF ibo_trade_union.of_get_pay_period_type(gnv_app.is_book, ls_trade_union, ls_pay_period_type) <> 1 THEN
		this.of_msg_db_error("Error reading trade union")
		RETURN -1
	END IF
	
	//Open the selected file
	li_fn = FileOpen(as_temp_local_file, StreamMode!, Write!, Shared!, Append!) //Move here to prevent empty files for subcontractors

	IF ib_ROE_exists THEN
		ll_rc = FileSeek(li_fn, -14, FromEnd!)
	ELSE
		ll_rc = FileSeek(li_fn, 0, FromEnd!)
		FileWrite(li_fn, '<?xml version="1.0" encoding="UTF-8" ?>' + char(13) + char(10))	//change encoding - was adding MIME Base64 Encoding artifacts '3D' in front of '=' MDP 2025.01.14
		FileWrite(li_fn, '<ROEHEADER FileVersion="W-2.0" SoftwareVendor="abio systems" ProductName="abio" ProductVersion="2.0">' + char(13) + char(10))
	END IF
	
	//Get pay period amounts
	lds_cheque = CREATE n_ds
	lds_cheque.DataObject = 'd_preent_roe_pp'
	lds_cheque.SetTransObject(sqlca)

	CHOOSE CASE ls_pay_period_type
		CASE 'W'
			li_max_pp_earnings_15b = 27
			li_max_pp_earnings_15c = 53
			li_max_pp_hours = 53
			li_days_in_pay_period = 7
		CASE 'B'
			li_max_pp_earnings_15b = 14
			li_max_pp_earnings_15c = 27
			li_max_pp_hours = 27
			li_days_in_pay_period = 14
		CASE 'S'
			li_max_pp_earnings_15b = 13
			li_max_pp_earnings_15c = 25
			li_max_pp_hours = 25
			li_days_in_pay_period = 15
		CASE 'M'
			li_max_pp_earnings_15b = 7
			li_max_pp_earnings_15c = 13
			li_max_pp_hours = 13
			li_days_in_pay_period = 30
	END CHOOSE
	
	FOR li_x = 1 TO li_max_pp_earnings_15c
		ls_pp[li_x] = '0.00'
		ldec_lieu[li_x] = 0
	NEXT

	ldt_hire = ibo_datapanel_business.of_GetItemDatetime(ll_row,"hire_date") 	
	ldt_min_pay_period = DateTime(RelativeDate(Date(ldt_hire), 1 - li_days_in_pay_period ), Time(0,0,0))
	
	ll_pr_rc =  ibo_pr_cheque.of_get_max_pay_period_start_date(gnv_app.is_book,il_employee, ldt_hire, ldt_max_pay_period) 
	CHOOSE CASE ll_pr_rc 
		CASE 1
			IF IsNull(ldt_max_pay_period) THEN
				ldt_max_pay_period = ldt_min_pay_period
			END IF
		CASE 0
			ldt_max_pay_period = ldt_min_pay_period
		CASE -1
			dw_main.EVENT ue_setmessage("Error reading company","Red")
			ls_support = ibo_application_properties.of_get_support_contact()
			MessageBox("Database Error", "Error reading pr_cheque" + '~n~r' + ls_support, Exclamation!)
			IF IsValid(lds_cheque) THEN DESTROY(lds_cheque)
			RETURN -1
	END CHOOSE

	li_max_pp_earnings_15b = Min(li_max_pp_earnings_15b, DaysAfter(Date(ldt_min_pay_period), Date(ldt_max_pay_period)) / li_days_in_pay_period + 1.5)
	li_max_pp_earnings_15c = Min(li_max_pp_earnings_15c, DaysAfter(Date(ldt_min_pay_period), Date(ldt_max_pay_period)) / li_days_in_pay_period + 1.5)
	
	ldt_termination 	= ibo_datapanel_business.of_GetItemDatetime(ll_row,"termination_date") 	
	ldt_last_pay 		= ibo_datapanel_business.of_GetItemDatetime(ll_row,"last_pay_date") 	
	
	//First plug into an array, so pay periods without hours are also reported
	li_rows = lds_cheque.Retrieve(gnv_app.is_book, il_employee, ldt_hire, ldt_max_pay_period, li_days_in_pay_period)
	ldec_carry_forward = 0
	FOR li_x = 1 TO li_rows
		
		ldec_eiearn = lds_cheque.GetItemDecimal(li_x, 'eiearn')
		li_pp = Integer(lds_cheque.GetItemDecimal(li_x, 'pp'))
		
		
		IF li_pp <= li_max_pp_earnings_15b THEN 
			ldec_total_earnings += ldec_eiearn
		END IF
		
		IF li_pp <= li_max_pp_earnings_15c THEN 
			IF li_pp <= Upperbound(ls_pp) and li_pp > 0 THEN
				ls_pp[li_pp] = String(ldec_eiearn, '#######.00') 
				ldec_lieu[li_pp] = lds_cheque.GetItemDecimal(li_x, 'lieu')
				ldec_lieu_total += ldec_lieu[li_pp]
			ELSE
				ldec_lieu_total += 0
			END IF	
		END IF
		
		IF li_pp <= li_max_pp_hours THEN 
			ldec_total_hours += lds_cheque.GetItemDecimal(li_x, 'regh') &
									+ lds_cheque.GetItemDecimal(li_x, 'tahh') &
									+ lds_cheque.GetItemDecimal(li_x, 'ovrh') &
									+ lds_cheque.GetItemDecimal(li_x, 'travh')
		END IF
	NEXT
	
	IF this.of_adjust_pay_periods(ls_pp) = -1 THEN
		RETURN -1
	END IF

	FileWrite(li_fn, '<ROE PrintingLanguage="E" Issue="D">' + char(13) + char(10))
	FileWrite(li_fn, '<B3>' + String(il_employee) + '</B3>' + char(13) + char(10))
	FileWrite(li_fn, '<B5>' + ls_ccra_business_no + '</B5>' + char(13) + char(10))
	FileWrite(li_fn, '<B6>' + ls_pay_period_type + '</B6>' + char(13) + char(10))
	FileWrite(li_fn, '<B8>' + 	dw_main.GetItemString(1, 'sin') + '</B8>' + char(13) + char(10))
	FileWrite(li_fn, '<B9>' + char(13) + char(10))
	ls_name = ibo_datapanel_business.of_GetItemString(ll_row,"name") 	
	FileWrite(li_fn, '<FN>' + Trim(right(ls_name, Len(ls_name) - Pos(ls_name, ","))) + '</FN>'+ char(13) + char(10))
	FileWrite(li_fn, '<LN>' + Trim(left(ls_name, Pos(ls_name, ",")-1)) + '</LN>'+ char(13) + char(10))
	
	ls_address1 = dw_main.GetItemString(1, 'mailing_address_1')
	IF IsNull(ls_address1) THEN ls_address1 = ""
	ls_address2 = dw_main.GetItemString(1, 'mailing_address_2')
	IF IsNull(ls_address2) THEN ls_address2 = ""
	
	FileWrite(li_fn, '<A1>' + left(Trim(ls_address1 + " " + ls_address2),35) + '</A1>'+ char(13) + char(10))
	FileWrite(li_fn, '<A2>' + Trim(dw_main.GetItemString(1, 'mailing_city')) + '</A2>'+ char(13) + char(10))
	FileWrite(li_fn, '<A3>' + Trim(dw_main.GetItemString(1, 'mailing_province')) + '</A3>'+ char(13) + char(10))
	FileWrite(li_fn, '<PC>' + Trim(dw_main.GetItemString(1, 'mailing_postal')) + '</PC>'+ char(13) + char(10))
	FileWrite(li_fn, '</B9>'+ char(13) + char(10))
	FileWrite(li_fn, '<B10>' + String(ibo_datapanel_business.of_GetItemDatetime(ll_row,"hire_date") , 'YYYY-MM-DD') + '</B10>'+ char(13) + char(10))
	IF DaysAfter(Date(ldt_termination), Date(ldt_last_pay)) > 0 THEN
		FileWrite(li_fn, '<B11>' + String(ldt_termination, 'YYYY-MM-DD') + '</B11>'+ char(13) + char(10))
	ELSE
		FileWrite(li_fn, '<B11>' + String(ldt_last_pay, 'YYYY-MM-DD') + '</B11>'+ char(13) + char(10))
	END IF
	FileWrite(li_fn, '<B12>' + String(ldt_last_pay, 'YYYY-MM-DD') + '</B12>'+ char(13) + char(10))
	FileWrite(li_fn, '<B13>' + Trim(dw_main.GetItemString(ll_row,"occupation_desc")) + '</B13>'+ char(13) + char(10))
	FileWrite(li_fn, '<B14><CD>U</CD></B14>'+ char(13) + char(10))
	FileWrite(li_fn, '<B15A>' + Trim(string(Round(ldec_total_hours,0), '#######')) + '</B15A>'+ char(13) + char(10))
	//FileWrite(li_fn, '<B15B>' + Trim(string(ldec_total_earnings, '#######.00')) + '</B15B>'+ char(13) + char(10))
	FileWrite(li_fn, '<B15C>'+ char(13) + char(10))
	
	FOR li_x = 1 TO li_max_pp_earnings_15c
		FileWrite(li_fn, '<PP nbr = "'+Trim(String(li_x))+'"><AMT>' + ls_pp[li_x] + "</AMT></PP>"+ char(13) + char(10))
	NEXT	
	FileWrite(li_fn, '</B15C>'+ char(13) + char(10))
	
	FileWrite(li_fn, '<B16>'+ char(13) + char(10))
	FileWrite(li_fn, '<CD>' + ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code")  + '</CD>'+ char(13) + char(10))
	
	FileWrite(li_fn, '<FN>' + Trim(Mid(ls_roe_name, 1, Pos(ls_roe_name, " "))) + '</FN>'+ char(13) + char(10))
	FileWrite(li_fn, '<LN>' + Trim(Mid(ls_roe_name, Pos(ls_roe_name, " ") + 1)) + '</LN>'+ char(13) + char(10))
	
	FileWrite(li_fn, '<AC>' + left(ls_phone, 3) + '</AC>'+ char(13) + char(10))
	FileWrite(li_fn, '<TEL>' + right(ls_phone, 7) + '</TEL>'+ char(13) + char(10))
	FileWrite(li_fn, '</B16>'+ char(13) + char(10))
	
	//Jira 2860 - ROEs should not report negative vacation pay owed
	IF ibo_datapanel_business.of_GetItemDecimal(ll_row,"vacation_owed") > 0 THEN
		FileWrite(li_fn, '<B17A><VP nbr="1"><CD>2</CD><AMT>' &
									+ String(ibo_datapanel_business.of_GetItemDecimal(ll_row,"vacation_owed"), '#######.00;-#######.00;#') &
									+ '</AMT></VP></B17A>'+ char(13) + char(10))
	ELSE
		FileWrite(li_fn, '<B17A><VP nbr="1"><CD>1</CD></VP></B17A>'+ char(13) + char(10))
	END IF
	
	//jira 5925 - Change ROE coding of payment in lieu when it's paid in a pay period other than the last period
	//Other Monies - Pay in lieu of notice block - CRA only accepts other monies paid in the final pay period, ignore the rest
	IF ldec_lieu[1] <> 0 THEN
		FileWrite(li_fn, '<B17C>'+ char(13) + char(10))
		FileWrite(li_fn, '  <OM nbr = "1">'+ char(13) + char(10)) 
		FileWrite(li_fn, '     <CD>Y00</CD>'+ char(13) + char(10)) 
		FileWrite(li_fn, '     <AMT>' + String(ldec_lieu[1], '#######.00;-#######.00;#') + '</AMT>'+ char(13) + char(10)) 
		FileWrite(li_fn, '  </OM>'+ char(13) + char(10)) 
		FileWrite(li_fn, '</B17C>'+ char(13) + char(10)) 
	END IF
	
	//Pay in lieu of notice block
//	IF ldec_lieu_total <> 0 THEN
//		FileWrite(li_fn, '<B17C>'+ char(13) + char(10))
//		FOR li_x = 1 TO li_max_pp_earnings_15c
//			IF ldec_lieu[li_x] <> 0 THEN
//				FileWrite(li_fn, '  <OM nbr = "'+Trim(String(li_x))+'">'+ char(13) + char(10)) 
//				FileWrite(li_fn, '     <CD>Y00</CD>'+ char(13) + char(10)) 
//				FileWrite(li_fn, '     <AMT>' + String(ldec_lieu[li_x], '#######.00;-#######.00;#') + '</AMT>'+ char(13) + char(10)) 
//				FileWrite(li_fn, '  </OM>'+ char(13) + char(10)) 
//			END IF
//		NEXT
//		FileWrite(li_fn, '</B17C>'+ char(13) + char(10)) 
//	END IF
	
	IF ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code") = "K" THEN
		FileWrite(li_fn, '<B18>' + ibo_datapanel_business.of_GetItemString(ll_row,"roe_note") + '</B18>'+ char(13) + char(10))
	END IF
	FileWrite(li_fn, '<B20>E</B20>'+ char(13) + char(10))
	FileWrite(li_fn, '</ROE>'+ char(13) + char(10))
	FileWrite(li_fn, '</ROEHEADER>'+ char(13) + char(10))
	FileClose(li_fn)
	
END IF

IF IsValid(lds_cheque) THEN DESTROY(lds_cheque)

RETURN 1

end event

event type integer ue_process_print_supervisor();//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_process_print_supervisor
// Author   :	Lourdes Garcia
// Date     :	2009/07/15
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Generates Print Preview for Supervisor Subordinate
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String		ls_subtitle
string		ls_select, ls_where
n_ds			lds_preview
s_preview	lstr_preview
window		lw_preview

ls_subtitle = is_name

IF dw_main.RowCount() > 0 THEN

	// set preview dataobject
	lds_preview = CREATE n_ds
	lds_preview.DataObject = 'd_pr_employee_terminated_supervisor_prn'

	// manipulate where clause
		ls_select = lds_preview.Describe("Datawindow.Table.Select")
		
		ls_where =  "  employee.book = '" + is_book + "' AND "  + &
			         "  employee.employee = " + string(il_employee) 
			
		IF LEN(ls_where ) > 0 THEN
			ls_select = ls_select + ' where  ' + ls_where
		END IF
		
		lds_preview.SetTransObject(SQLCA)
		lds_preview.Modify("Datawindow.Table.Select = ~"" + &
			ls_select + "~"")
		lds_preview.Retrieve()
	
		IF dw_main.RowCount() > 0 THEN
			//lstr_preview.dw_preview = dw_main
			lstr_preview.ds_preview = lds_preview
			lstr_preview.s_title = gnv_app.of_GetCompanyName()
			lstr_preview.s_sub_title = 'Supervisor Details for '  + string(il_employee) + '-' + is_name
			OpenSheetWithParm(lw_preview,lstr_preview,'w_preview',gnv_app.of_getframe(),0, Original!)
		END IF

END IF

RETURN 1

end event

public function long of_retrieve (s_parm astr_parm);//************************************************************
// Object   :	u_cst_employee_hire_detail 
// Function :	of_retrieve
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
// 	
// Arguments:	s_parm astr_parm
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

Long 		ll_rc 

dw_main.of_SetRedraw(FALSE)

IF IsValid(ibo_datapanel_business) THEN
	il_employee	= astr_parm.l_parm[1]
	is_book = astr_parm.s_parm[2]
	ll_rc = ibo_datapanel_business.of_retrieve("book = '" + is_book + "' and employee = " + string(il_employee))
	is_name = astr_parm.s_parm[1]
END IF

//IF ll_rc > 1 THEN
//	dw_main.Reset()
//	RETURN 1
//END IF
//
// set cc fields
IF ll_rc > 0 THEN
	of_set_cc_fields(ll_rc)
END IF

//Reset child business objects so we don't get a 'record has changed' message
ibo_employee_premium.of_reset()
ibo_person.of_reset()
ibo_person_diary.of_reset()
ibo_timesheet.of_reset()
ibo_pr_cheque.of_reset()

dw_main.of_SetRedraw(TRUE)

RETURN ll_rc
end function

public function string of_getcurrentfilter ();//************************************************************
// Object   :	u_cst_employee_detail 
// Function :	of_getcurrentfilter
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
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

String ls_filter
Long ll_row

ll_row = dw_main.GetRow()

IF ll_row > 0 THEN
	ls_filter =' employee = ' + string(ibo_datapanel_business.of_getitemnumber(ll_row, 'employee'))
END IF 

RETURN ls_filter
end function

public function integer of_set_cc_fields (long al_row);//************************************************************
// Object   :	u_cst_employee_detail 
// Function :	of_set_cc_fields
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	long al_row
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

String 					ls_union
String					ls_occupation
String					ls_trade_description
String					ls_occupation_description, &
							ls_job, &
							ls_name, &
							ls_area, &
							ls_roe, &
							ls_roe_desc, &
							ls_gl_desc, &
							ls_area_desc, &
							ls_centre_desc, &
							ls_gl_account, &
							ls_centre
							
							
Long						ll_supervisor, &
							ll_employee, &
							ll_tur_rows, &
							ll_find, ll_cm_row, ll_cm_rows, ll_crews
							
s_parm					lstr_parm							

//jira 2579 - use trade union vacation and statutory percents
ll_tur_rows = ibo_trade_union_rate.of_Retrieve("book = '" + string(gnv_app.is_book) + &
																		"' and trade_union = '" + ibo_datapanel_business.of_GetItemString(al_row,"trade_union") + &
																		"' and CONVERT(VARCHAR, effective_date, 112) <= '" + string(Today(), 'YYYYMMDD') +  "'" + &
																		"  and CONVERT(VARCHAR, expiry_date, 112) >= '" + string(Today(), 'YYYYMMDD') + "'" )
IF ll_tur_rows > 0 THEN
	is_current_union_vacation_pay_flag = ibo_trade_union_rate.of_GetItemString(1, 'union_vacation_pay_flag')
ELSE
	is_current_union_vacation_pay_flag = ''
END IF

// Get trade_union and occupaton
ls_union = ibo_datapanel_business.of_GetItemString(al_row,"trade_union")
ls_trade_description = ibo_trade_union.of_get_trade_union_description(is_book, ls_union)

ls_occupation = ibo_datapanel_business.of_GetItemString(al_row,"occupation")
ls_occupation_description = ibo_occupation.of_get_occupation_desciption(is_book, ls_union, ls_occupation)


// jira 3480 - allow user to change employee's crew membership
ls_job = ibo_datapanel_business.of_GetItemString(al_row,"job")
dw_main.SetItem(al_row,"cc_own_supervisor", 'N')
dw_main.SetItemStatus(al_row,"cc_own_supervisor",Primary!,NotModified!)

IF Len(ls_job) > 0 THEN
	ibo_datapanel_business.of_GetChild("crew_member", ibo_crew_member)
	IF Not IsValid(ibo_crew_member) THEN
		this.of_msg_db_error("Error reading crew members")
		RETURN -1
	END IF
	ll_cm_rows = ibo_crew_member.of_Retrieve("effective_date <= '" + String(Today(), 'yyyy.mm.dd')	&
											+ "' AND expiry_date >= '" + String(Today(), 'yyyy.mm.dd')		&
											+ "' AND employee = " + String(il_employee))
	IF ll_cm_rows > 0 THEN
		ibo_crew_member.of_SetSort("supervisor_flag ASC, alternate_supervisor_flag ASC, expiry_date DESC")
		ibo_crew_member.of_Sort()
		
		// if possible, show the crew associated with the employee's job, so the drilldowns work
		ll_find = ibo_crew_member.of_Find("job_or_region = '" + ls_job + "' AND crew = '" + dw_main.GetItemString(al_row, 'crew') + "'")
		IF ll_find > 1 AND  Len(dw_main.GetItemString(al_row, 'crew')) > 0 THEN
		   dw_main.SetItem(al_row,"crew_effective", String(ibo_crew_member.of_GetItemDateTime(ll_find, 'effective_date'), 'yyyy.mm.dd'))
			dw_main.SetItemStatus(al_row,"crew_effective",Primary!,NotModified!)
		ELSE
		   dw_main.SetItem(al_row,"crew_effective", '')
			dw_main.SetItemStatus(al_row,"crew_effective",Primary!,NotModified!)
		END IF
		
		ll_crews = 0
		FOR ll_cm_row = 1 TO ll_cm_rows
			IF ibo_crew.of_Count("job_or_region = '" + ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region') &
										+ "' AND crew = '" + ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') &
										+ "' AND active_flag = 'Y'") = 1 THEN
				IF ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region') = ls_job THEN
					//Better to get the active crew if possible
				END IF
				IF ibo_crew_member.of_GetItemString(ll_cm_row, 'supervisor_flag') = 'Y' THEN
					//to help decide if they can change the supervisor
					dw_main.SetItem(al_row,"cc_own_supervisor", 'Y')
					dw_main.SetItemStatus(al_row,"cc_own_supervisor",Primary!,NotModified!)
				END IF
				ll_crews ++
			END IF
		NEXT
		dw_main.SetItem(al_row,"crew_count", ll_crews)
		dw_main.SetItemStatus(al_row,"crew_count",Primary!,NotModified!)
	ELSE
		// employee not found on a crew
		dw_main.SetItem(al_row,"crew_count", 0)
		dw_main.SetItemStatus(al_row,"crew_count",Primary!,NotModified!)
	END IF
ELSE
	// no job, no crew
	dw_main.SetItem(al_row,"crew_count", 0)
	dw_main.SetItemStatus(al_row,"crew_count",Primary!,NotModified!)
END IF
is_original_crew = dw_main.GetItemString(al_row, 'crew')


// get supervisor_number
ll_supervisor = ibo_datapanel_business.of_GetItemNumber(al_row,"supervisor")
ibo_person.of_get_person_name(ll_supervisor, ls_name)

IF al_row > 0 THEN
	
	// set up description fields; trade_union and occupation
	dw_main.SetItem(al_row,"trade_union_desc",ls_trade_description)
	dw_main.SetItemStatus(al_row,"trade_union_desc",Primary!,NotModified!)
	
	dw_main.SetItem(al_row,"occupation_desc",ls_occupation_description)
	dw_main.SetItemStatus(al_row,"occupation_desc",Primary!,NotModified!)

	// set up crew desc
	//dw_main.SetItem(al_row,"crew_desc",ls_crew_description)
	//dw_main.SetItemStatus(al_row,"crew_desc",Primary!,NotModified!)
	
	// set up supervisor_name
//	dw_main.SetItem(al_row,"supervisor_name",ls_name)
//	dw_main.SetItemStatus(al_row,"supervisor_name",Primary!,NotModified!)
	
	// set person fields
	ll_employee = ibo_datapanel_business.of_GetItemNumber(al_row,"employee")
	ibo_person.of_get_person_fields_for_employee(ll_employee, lstr_parm)
	dw_main.SetItem(al_row,"sin", lstr_parm.s_parm[2])
	dw_main.SetItemStatus(al_row,"sin",Primary!,NotModified!)

	dw_main.SetItem(al_row,"gst", lstr_parm.s_parm[3])
	dw_main.SetItemStatus(al_row,"gst",Primary!,NotModified!)
	
	dw_main.SetItem(al_row,"birth_date", lstr_parm.dt_parm[1])
	dw_main.SetItemStatus(al_row,"birth_date",Primary!,NotModified!)

	dw_main.SetItem(al_row,"mailing_address_1", lstr_parm.s_parm[4])
	dw_main.SetItemStatus(al_row,"mailing_address_1",Primary!,NotModified!)

	dw_main.SetItem(al_row,"mailing_address_2", lstr_parm.s_parm[5])
	dw_main.SetItemStatus(al_row,"mailing_address_2",Primary!,NotModified!)	

	dw_main.SetItem(al_row,"mailing_city", lstr_parm.s_parm[6])
	dw_main.SetItemStatus(al_row,"mailing_city",Primary!,NotModified!)	

	dw_main.SetItem(al_row,"mailing_country", lstr_parm.s_parm[7])
	dw_main.SetItemStatus(al_row,"mailing_country",Primary!,NotModified!)	

	dw_main.SetItem(al_row,"mailing_province", lstr_parm.s_parm[8])
	dw_main.SetItemStatus(al_row,"mailing_province",Primary!,NotModified!)	

	dw_main.SetItem(al_row,"mailing_postal", lstr_parm.s_parm[9])	
	dw_main.SetItemStatus(al_row,"mailing_postal",Primary!,NotModified!)	
	
	dw_main.SetItem(al_row,"phone", lstr_parm.s_parm[10])	
	dw_main.SetItemStatus(al_row,"phone",Primary!,NotModified!)	

	dw_main.SetItem(al_row,"ssn", lstr_parm.s_parm[12])	
	dw_main.SetItemStatus(al_row,"ssn",Primary!,NotModified!)	

	// set roe_reason
	ls_roe = ibo_datapanel_business.of_GetItemString(al_row,"roe_reason_code")
 	ibo_roe_reason.of_get_roe_description(ls_roe,ls_roe_desc)
	dw_main.SetItem(al_row,"roe_desc",ls_roe_desc)
	dw_main.SetItemStatus(al_row,"roe_desc",Primary!,NotModified!)
	
	// set gl_account
	ls_gl_account = ibo_datapanel_business.of_GetItemString(al_row,"gl_account")
 	ibo_gl_account.of_get_gl_account_description(is_book,ls_gl_account,"",'C','Y',ls_gl_desc)
	dw_main.SetItem(al_row,"gl_desc",ls_gl_desc)
	dw_main.SetItemStatus(al_row,"gl_desc",Primary!,NotModified!)
	
	// set job
	ls_job = ibo_datapanel_business.of_GetItemString(al_row,"job")
	IF Len(ls_job) > 0 THEN
		IF ibo_job.of_Retrieve("book = '" + is_book + "' AND job = '" + ls_job + "'") > 0 THEN
			IF ibo_job.of_GetItemString(1, "concurrent_crew_memberships_flag") = 'Y' THEN
				dw_main.SetItem(al_row,"job_desc",ibo_job.of_GetItemString(1, "description") + " (MULTI-CREW)")
			ELSE
				dw_main.SetItem(al_row,"job_desc",ibo_job.of_GetItemString(1, "description"))
			END IF
		END IF
		dw_main.SetItemStatus(al_row,"job_desc",Primary!,NotModified!)
	END IF

	// set area
	ls_area = ibo_datapanel_business.of_GetItemString(al_row,"area")
 	ibo_area.of_get_area_description(is_book,ls_job,ls_area,ls_area_desc)
	dw_main.SetItem(al_row,"area_desc",ls_area_desc)
	dw_main.SetItemStatus(al_row,"area_desc",Primary!,NotModified!)

	// set centre
	ls_centre = ibo_datapanel_business.of_GetItemString(al_row,"centre")
 	ibo_centre.of_get_centre_description(is_book, ls_job, ls_area, ls_centre,ls_centre_desc)
	dw_main.SetItem(al_row,"centre_desc",ls_centre_desc)
	dw_main.SetItemStatus(al_row,"centre_desc",Primary!,NotModified!)
	

END IF

RETURN 1



end function

public function integer of_update_td1_claim_amounts (string as_tax_province);//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Function :	of_update_td1_claim_amounts
// Author   :	Monica Petersen
// Date     :	2012/01/16
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
// 2013.01.09		MDP	Jira 2590 - If the employee's current TD1 minimum matches the TD1 minimum for the previous year, 
//												then reset to the TD1 minimum for the current year.
//************************************************************

String	ls_msg, ls_where_fed, ls_where_prov
Datetime	ldt_hire_date
Date 		ld_prev_year
Decimal	ldec_current_federal_td1, ldec_prev_federal_td1
Decimal	ldec_current_prov_td1, ldec_prev_prov_td1

IF ibo_datapanel_business.of_GetItemString(1, 'employment_type') = 'Y' THEN
	
	ldt_hire_date = ibo_datapanel_business.of_GetItemDateTime(1, 'hire_date')
	
	//jira 2005 - reset TD1 amounts
	ls_where_fed = " CONVERT(varchar, effective_date, 112) <= '" + String(ldt_hire_date, 'YYYYMMDD') &
								  + "' AND CONVERT(varchar, expiry_date, 112) >= '" + String(ldt_hire_date, 'YYYYMMDD') + "'"
	IF NOT IsNull(ls_where_fed) THEN							  
		IF ibo_federal_tax.of_retrieve(ls_where_fed) >= 1 THEN
			
			//Save the current value
			ldec_current_federal_td1 = ibo_federal_tax.of_GetItemDecimal(1, 'federal_td1_claim')
			
			//And get the value from the previous year so we can tell if it's been overridden
			ld_prev_year = gnv_app.inv_datetime.of_RelativeYear(Today(), -1)
			ls_where_fed = " CONVERT(varchar, effective_date, 112) <= '" + String(ld_prev_year, 'YYYYMMDD') &
										  + "' AND CONVERT(varchar, expiry_date, 112) >= '" + String(ld_prev_year, 'YYYYMMDD') + "'"
			IF NOT IsNull(ls_where_fed) THEN							  
				IF ibo_federal_tax.of_retrieve(ls_where_fed) >= 1 THEN
					ldec_prev_federal_td1 = ibo_federal_tax.of_GetItemDecimal(1, 'federal_td1_claim')
			
					//Only update the federal TD1 if it was exactly last year's value
					IF ibo_datapanel_business.of_GetItemDecimal(1, 'federal_td1_claim') = ldec_prev_federal_td1 THEN
						ls_msg = "fed. TD1 from " + String(ibo_datapanel_business.of_GetItemDecimal(1, 'federal_td1_claim'), '$#,##0.00') &
															+ " to " + String(ldec_current_federal_td1, '$#,##0.00') 
						ibo_datapanel_business.of_SetItem(1, 'federal_td1_claim', ldec_current_federal_td1)
					END IF
				END IF
			END IF
		END IF	
	END IF

	//We also want to update employee.provincial_td1_claim with the minimum of 
	//employee.provincial_td1_claim and province_rate.provincial_td1_claim 
	ls_where_prov = "CONVERT(varchar, effective_date, 112) <= '" + String(ldt_hire_date, 'YYYYMMDD') &
								  + "' AND CONVERT(varchar, expiry_date, 112) >= '" + String(ldt_hire_date, 'YYYYMMDD') &
								  + "' AND province = '" + as_tax_province + "'"
	IF NOT IsNull(ls_where_prov) THEN							  
		IF ibo_province_rate.of_retrieve(ls_where_prov) >= 1 THEN

			//Save the current value
			ldec_current_prov_td1 = ibo_province_rate.of_GetItemDecimal(1, 'provincial_td1_claim')
			
			//And get the value from the previous year so we can tell if it's been overridden
			ld_prev_year = gnv_app.inv_datetime.of_RelativeYear(Today(), -1)
			ls_where_prov = "CONVERT(varchar, effective_date, 112) <= '" + String(ld_prev_year, 'YYYYMMDD') &
										  + "' AND CONVERT(varchar, expiry_date, 112) >= '" + String(ld_prev_year, 'YYYYMMDD') &
										  + "' AND province = '" + as_tax_province + "'"
			IF NOT IsNull(ls_where_prov) THEN							  
				IF ibo_province_rate.of_retrieve(ls_where_prov) >= 1 THEN
					ldec_prev_prov_td1 = ibo_province_rate.of_GetItemDecimal(1, 'provincial_td1_claim')
			
					//Only update the provincial TD1 if it was exactly last year's value
					IF ibo_datapanel_business.of_GetItemDecimal(1, 'provincial_td1_claim') = ldec_prev_prov_td1 THEN
						IF ls_msg <> '' THEN ls_msg += ", " 
						ls_msg += "prov. TD1 from " + String(ibo_datapanel_business.of_GetItemDecimal(1, 'provincial_td1_claim'), '$#,##0.00') &
																		+ " to " + String(ldec_current_prov_td1, '$#,##0.00')
						ibo_datapanel_business.of_SetItem(1, 'provincial_td1_claim', ldec_current_prov_td1)
					END IF
				END IF
			END IF
		END IF
	END IF
	
	IF ls_msg <> '' THEN dw_main.POST EVENT ue_setmessage("Updating " + ls_msg, 'blue')

END IF

RETURN 1
end function

public function string of_getbokeywhereclause (s_parm astr_parm, ref s_parm astr_retargs, boolean ab_single_quote);//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Function :	of_getbokeywhereclause
// Author   :	Monica Petersen
// Date     :	2015/02/04
// 	
// Arguments:	s_parm astr_parm
// 				s_parm astr_retargs
// 				boolean ab_single_quote
// 	
// Returns:		string
// 	
// Desc:			Don't allow restricted users to pick up an employee
//             record by keying the employee number directly
//             in the detail screen
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String	ls_where_clause

ls_where_clause = super::of_getbokeywhereclause(astr_parm, astr_retargs, ab_single_quote)

IF is_user_access_restricted = 'N' AND ab_single_quote THEN
	ls_where_clause +=  "  AND restrict_flag = 'N' "
END IF

RETURN ls_where_clause
end function

public function integer of_adjust_pay_periods (ref string astr_amounts[]);// Arguments: 
//   astr_amounts[]: Array of strings containing pay amounts
// Returns:
//   Integer: 1 for success, -1 for error
//   astr_amounts[] is modified in place with adjusted values

decimal{2} ldc_amounts[]
decimal{2} ldc_adjusted[]
decimal{2} ldc_clawback
integer li_size, li_i, li_j
string ls_error
decimal{2} ldc_original_total = 0
decimal{2} ldc_adjusted_total = 0

//Before adjustment
for li_i = 1 to UpperBound(astr_amounts)
    ldc_original_total += Dec(astr_amounts[li_i])
next

// Initialize arrays
li_size = UpperBound(astr_amounts)
if li_size <= 0 then
    return -1
end if

// Convert string amounts to decimals
for li_i = 1 to li_size
    if IsNumber(astr_amounts[li_i]) then
        ldc_amounts[li_i] = Dec(astr_amounts[li_i])
        ldc_adjusted[li_i] = ldc_amounts[li_i]
    else
        MessageBox("Error", "Invalid amount found: " + astr_amounts[li_i])
        return -1
    end if
next

// Process each negative amount
for li_i = 1 to li_size
    if ldc_adjusted[li_i] < 0 then
        ldc_clawback = Abs(ldc_adjusted[li_i])
        ldc_adjusted[li_i] = 0
        
        // First try to recover from previous periods
        for li_j = (li_i - 1) to 1 step -1
            if ldc_clawback <= 0 then exit
            if ldc_adjusted[li_j] > 0 then
                if ldc_adjusted[li_j] >= ldc_clawback then
                    // This period can absorb remaining clawback
                    ldc_adjusted[li_j] = ldc_adjusted[li_j] - ldc_clawback
                    ldc_clawback = 0
                else
                    // Take full amount and continue
                    ldc_clawback = ldc_clawback - ldc_adjusted[li_j]
                    ldc_adjusted[li_j] = 0
                end if
            end if
        next
        
        // If there's still remaining clawback, apply to future periods
        if ldc_clawback > 0 then
            for li_j = (li_i + 1) to li_size
                if ldc_clawback <= 0 then exit
                if ldc_adjusted[li_j] > 0 then
                    if ldc_adjusted[li_j] >= ldc_clawback then
                        // This period can absorb remaining clawback
                        ldc_adjusted[li_j] = ldc_adjusted[li_j] - ldc_clawback
                        ldc_clawback = 0
                    else
                        // Take full amount and continue
                        ldc_clawback = ldc_clawback - ldc_adjusted[li_j]
                        ldc_adjusted[li_j] = 0
                    end if
                end if
            next
            
            // Warning if clawback still couldn't be fully applied
            if ldc_clawback > 0 then
                ls_error = "Warning: Could not fully apply clawback of " + &
                          String(ldc_amounts[li_i], "#,##0.00") + &
                          ". Remaining: " + String(ldc_clawback, "#,##0.00")
                MessageBox("Warning", ls_error)
            end if
        end if
    end if
next

// Convert back to strings with 2 decimal places
for li_i = 1 to li_size
    astr_amounts[li_i] = String(ldc_adjusted[li_i], "######0.00")
next

// After adjustment
for li_i = 1 to UpperBound(astr_amounts)
    ldc_adjusted_total += Dec(astr_amounts[li_i])
next

IF ldc_adjusted_total <> ldc_original_total THEN
	ls_error = "Warning: Rebalancing is off: Adjusted: " + &
			  String(ldc_adjusted_total, "#,##0.00") + &
			  ". Original: " + String(ldc_original_total, "#,##0.00")
	MessageBox("Warning", ls_error)
	RETURN -1
END IF

return 1


end function

on u_cst_pr_employee_detail.create
call super::create
end on

on u_cst_pr_employee_detail.destroy
call super::destroy
end on

event destructor;call super::destructor;//************************************************************
// Object   :	u_cst_employee_hire_detail 
// Event    :	destructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
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

UserObject luo_object

luo_object = This


// destroy objects
IF IsValid(ibo_trade_union) 	THEN DESTROY ibo_trade_union
IF IsValid(ibo_occupation) 	THEN DESTROY ibo_occupation
IF IsValid(ibo_person) 			THEN DESTROY ibo_person
//IF IsValid(ibo_job_crew) 	THEN DESTROY ibo_job_crew
IF IsValid(ibo_person_diary) 	THEN DESTROY ibo_person_diary
If IsValid(ibo_company) 		THEN DESTROY ibo_company
IF IsValid(ibo_pr_cheque) 		THEN DESTROY ibo_pr_cheque
IF IsValid(ibo_timesheet) 		THEN DESTROY ibo_timesheet
IF IsValid(ibo_employee_earning) THEN DESTROY ibo_employee_earning
IF IsValid(ibo_employee_premium) THEN DESTROY ibo_employee_premium
IF IsValid(ibo_shift_pattern) THEN DESTROY ibo_shift_pattern
IF IsValid(ibo_roe_reason) 	THEN DESTROY ibo_roe_reason
IF IsValid(ibo_gl_account) 	THEN DESTROY ibo_gl_account
IF IsValid(ibo_area) 			THEN DESTROY ibo_area
IF IsValid(ibo_job) 				THEN DESTROY ibo_job
IF IsValid(ibo_centre) 			THEN DESTROY ibo_centre
IF IsValid(ibo_user) 			THEN DESTROY ibo_user
IF IsValid(ibo_employee2) 		THEN DESTROY ibo_employee2
IF IsValid(ibo_application_properties) THEN DESTROY ibo_application_properties
IF IsValid(ibo_trade_union_rate) THEN DESTROY ibo_trade_union_rate
IF IsValid(ibo_trade_union_premium) THEN DESTROY ibo_trade_union_premium
IF IsValid(ibo_timesheet_premium) THEN DESTROY ibo_timesheet_premium
IF IsValid(ibo_federal_tax) 	THEN DESTROY ibo_federal_tax
IF IsValid(ibo_province_rate) THEN DESTROY ibo_province_rate
IF IsValid(ibo_premium_type)	THEN DESTROY ibo_premium_type
IF IsValid(ibo_crew)				THEN DESTROY ibo_crew
IF IsValid(ibo_crew_member)	THEN DESTROY ibo_crew_member


// REMOVE INTEREST ON SYNCH OBJECTS
gnv_synchronize.uf_remove_interest("REFRESH_FROM_ADRS_PERSON", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_FROM_BDAY_PERSON", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_FROM_GST_PERSON", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_FROM_SIN_PERSON", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_FROM_PHONE_PERSON", luo_object)
gnv_synchronize.uf_remove_interest("RESET_OCCUPATION_RATES", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_EMPLOYEE_LIST", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_UNION_LIST", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_OCCUPATION_LIST", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_OCCUPATION_RATE", luo_object)

end event

event ue_init;call super::ue_init;//************************************************************
// Object   :	u_cst_employee_hire_detail 
// Event    :	ue_init
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
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

UserObject luo_object
string	ls_extra_values_display[], ls_empty[]
string	ls_filter
string	ls_support

IF g_bo_application_properties.of_GetItemString(1, "allow_mixed_case_flag") = 'Y' THEN 
	dw_main.of_set_field_case({"message", "eft_email_address", "memo"}, "M")
END IF


luo_object = This	  
ib_endaction_message = FALSE

is_datapanel_name = 'Employee'

IF Not(IsValid(ibo_federal_tax)) THEN 
	ibo_federal_tax = CREATE n_bo_federal_tax
	ibo_federal_tax.of_SetTransaction(SQLCA)
END IF

IF Not(IsValid(ibo_province_rate)) THEN 
	ibo_province_rate = CREATE n_bo_province_rate
	ibo_province_rate.of_SetTransaction(SQLCA)
END IF

//These business objects are defined as children so they are updated during of_Update()
//This happens after the of_validate.  
IF ibo_datapanel_business.of_GetChild("employee_premium", ibo_employee_premium) = -1 THEN
	this.of_msg_db_error("employee_premium is not defined as a child table")
	RETURN -1
END IF
ibo_employee_premium.of_SetLogAuditDetails(TRUE)
ibo_employee_premium.of_SetLogEventName('PREENT')
ibo_employee_premium.of_setlogactioncode('C')

IF ibo_datapanel_business.of_GetChild("person", ibo_person) = -1 THEN
	this.of_msg_db_error("person is not defined as a child table")
	RETURN -1
END IF
ibo_person.of_SetLogAuditDetails(TRUE)
ibo_person.of_SetLogEventName('PREENT')
ibo_person.of_setlogactioncode('C')

IF ibo_datapanel_business.of_GetChild("person_diary", ibo_person_diary) = -1 THEN
	this.of_msg_db_error("person_diary is not defined as a child table")
	RETURN -1
END IF
ibo_person_diary.of_SetLogAuditDetails(TRUE)
ibo_person_diary.of_SetLogEventName('PREENT')
ibo_person_diary.of_setlogactioncode('A')

IF ibo_datapanel_business.of_GetChild("timesheet", ibo_timesheet) = -1 THEN
	this.of_msg_db_error("timesheet is not defined as a child table")
	RETURN -1
END IF
ibo_timesheet.of_SetLogAuditDetails(FALSE)

IF ibo_datapanel_business.of_GetChild("pr_cheque", ibo_pr_cheque) = -1 THEN
	this.of_msg_db_error("pr_cheque is not defined as a child table")
	RETURN -1
END IF
ibo_pr_cheque.of_SetLogAuditDetails(FALSE)

IF ibo_datapanel_business.of_GetChild("crew_member", ibo_crew_member) = -1 THEN
	this.of_msg_db_error("crew_member is not defined as a child table")
	RETURN -1
END IF
ibo_crew_member.of_SetLogAuditDetails(TRUE)
ibo_crew_member.of_SetLogEventName('PREENT')
//ibo_crew_member.of_setlogactioncode('C')

IF ibo_datapanel_business.of_GetChild("earning", ibo_employee_earning_new_emp) = -1 THEN
	this.of_msg_db_error("earning is not defined as a child table")
	RETURN -1
END IF
ibo_employee_earning_new_emp.of_SetLogAuditDetails(TRUE)
ibo_employee_earning_new_emp.of_SetLogEventName('PREENT')

IF ibo_datapanel_business.of_GetChild("wcb", ibo_employee_wcb_new_emp) = -1 THEN
	this.of_msg_db_error("wcb is not defined as a child table")
	RETURN -1
END IF
ibo_employee_wcb_new_emp.of_SetLogAuditDetails(TRUE)
ibo_employee_wcb_new_emp.of_SetLogEventName('PREENT')
//ibo_crew_member.of_setlogactioncode('C')

// create business objects
IF NOT IsValid(ibo_crew) THEN
	ibo_crew  = CREATE n_bo_crew
	ibo_crew.of_SetTransaction()
END IF

IF NOT IsValid(ibo_trade_union) THEN
	ibo_trade_union  = CREATE n_bo_trade_union
	ibo_trade_union.of_SetTransaction()
END IF

IF NOT IsValid(ibo_occupation) THEN
	ibo_occupation  = CREATE n_bo_occupation
	ibo_occupation.of_SetTransaction()
END IF

IF NOT IsValid(ibo_company) THEN
	ibo_company = CREATE n_bo_company
	ibo_company.of_SetTransaction()
END IF	

IF NOT IsValid(ibo_employee_earning) THEN
	ibo_employee_earning = CREATE n_bo_employee_earning
	ibo_employee_earning.of_SetTransaction()
END IF

IF NOT IsValid(ibo_shift_pattern) THEN
	ibo_shift_pattern = CREATE n_bo_shift_pattern
	ibo_shift_pattern.of_SetTransaction()
END IF


IF NOT IsValid(ibo_roe_reason) THEN
	ibo_roe_reason = CREATE n_bo_roe_reason
	ibo_roe_reason.of_SetTransaction()
END IF

IF NOT IsValid(ibo_gl_account) THEN
	ibo_gl_account = CREATE n_bo_gl_account
	ibo_gl_account.of_SetTransaction()
END IF

IF NOT IsValid(ibo_job) THEN
	ibo_job = CREATE n_bo_job
	ibo_job.of_SetTransaction()
END IF

IF NOT IsValid(ibo_area) THEN
	ibo_area = CREATE n_bo_area
	ibo_area.of_SetTransaction()
END IF

IF NOT IsValid(ibo_centre) THEN
	ibo_centre = CREATE n_bo_centre
	ibo_centre.of_SetTransaction()
END IF

IF NOT IsValid(ibo_application_properties) THEN
	ibo_application_properties = CREATE n_bo_application_properties
	ibo_application_properties .of_SetTransaction()
END IF

IF NOT IsValid(ibo_employee2) THEN
	ibo_employee2 = CREATE n_bo_employee
	ibo_employee2.of_SetTransaction()
END IF

IF NOT IsValid(ibo_trade_union_rate) THEN 
	ibo_trade_union_rate = CREATE n_bo_trade_union_rate
	ibo_trade_union_rate.of_SetTransaction()
END IF
		
IF NOT IsValid(ibo_timesheet_premium) THEN 
	ibo_timesheet_premium = CREATE n_bo_timesheet_premium
	ibo_timesheet_premium.of_SetTransaction()
END IF
		
IF NOT IsValid(ibo_trade_union_premium) THEN 
	ibo_trade_union_premium = CREATE n_bo_trade_union_premium
	ibo_trade_union_premium.of_SetTransaction()
END IF
		
IF NOT IsValid(ibo_premium_type) THEN 
	ibo_premium_type = CREATE n_bo_premium_type
	ibo_premium_type.of_SetTransaction()
END IF
		
// set event logging
This.ibo_datapanel_business.DYNAMIC of_SetLogEventName("PREENT")

// get restriction access of user
// open user bo
IF NOT IsValid(ibo_user) THEN
	ibo_user = CREATE n_bo_user
END IF	
ibo_user.of_SetTransaction()
IF ibo_user.of_get_user_access(gnv_app.of_getuserid(),is_restrict_flag) = 0 THEN
	// default to restricted
	is_restrict_flag = 'N'
	ls_support = ibo_application_properties.of_get_support_contact()
	MessageBox("Database Error", "Error reading abio_user" + '~n~r' + ls_support, Exclamation!)
END IF



// set-up pop-ups

IF is_restrict_flag = 'Y' THEN
	ls_filter = "1=1"
ELSE
	ls_filter = "restrict_flag = 'N' OR IsNull(restrict_flag)"
END IF

dw_main.inv_popup_data_list.of_register_column(	'employment_type', &
																'd_popup_blank', &
																'code', &
																'description', &
																TRUE, 640, FALSE, TRUE, TRUE, "", &
																{ 'Y','S','N','U' },  &
																{ 'Yes','Subcontract','Not on payroll', 'US Payroll'}, & 
																"",	/* s_parent_column 		  - The optional name of another column in the registered source datawindow that acts as a filter (in conjunction with the s_filter expression) for this column's popup data based on its current value*/&
																"") 	/* s_parent_filter_column - The name of the column in the datawindow object that will be matched to the current value of the parent column*/	

dw_main.inv_popup_data_list.of_register_column(	'region', &
																'd_popup_region', &
																'region', &
																'description', &
																TRUE, 1600, 									&
																TRUE,		/* empty allowed */ 				&
																FALSE, 	/* retrieve by company */		&
																FALSE, 	/* retrieve on register */ 	&
																"")
IF f_get_job_based_crew_flag() = 'Y' THEN 
	dw_main.inv_popup_data_list.of_register_column(	'crew', &
																	'd_popup_crew', 	&
																	'crew', 				&
																	'description', 	&
																	TRUE, 720, &
																	TRUE, &
																	FALSE, &
																	FALSE, &
																	"active_flag = 'Y' AND count_supervisors > 0") 
ELSE
	dw_main.inv_popup_data_list.of_register_column(	'crew', &
																	'd_popup_crew', 	&
																	'crew', 				&
																	'description', 	&
																	TRUE, 720, &
																	TRUE, &
																	FALSE, &
																	FALSE, &
																	"active_flag = 'Y' AND count_supervisors > 0", & 
																	ls_extra_values_display,  &
																	ls_extra_values_display, & 
																	"region", "job_or_region") 
END IF

dw_main.inv_popup_data_list.of_register_column(	'employee', &
																	'd_popup_employee', &
																	'employee_long', &
																	'name', &
																	TRUE, 1600, 									&
																	TRUE,		/* empty allowed */ 				&
																	TRUE, 	/* retrieve by company */		&
																	FALSE, 	/* retrieve on register */ 	&
																	ls_filter)
																	
dw_main.inv_popup_data_list.of_set_itemchange(	'employee', FALSE)

dw_main.inv_popup_data_list.of_register_column(	'name_add', &
																	'd_popup_employee_name_add', &
																	'name_add', &
																	'name_add', &
																	400, TRUE, TRUE, FALSE, ls_filter,ls_empty, ls_empty, 400, 270  )	
dw_main.inv_popup_data_list.of_set_itemchange(	'name_add', FALSE)

																	
dw_main.inv_popup_data_list.of_register_column(	'area', &
																'd_popup_area_override_retrieval', &
																'area', &
																'description', &
																TRUE, 720, TRUE, TRUE, TRUE, "") 

																
																
dw_main.inv_popup_data_list.of_register_column(	'centre', &
																'd_popup_centre_override_retrieval', &
																'centre', &
																'description', &
																TRUE, 980, TRUE, TRUE, TRUE, "", &
																ls_extra_values_display,  &
																ls_extra_values_display, & 
																"","") 
		
																
dw_main.inv_popup_data_list.of_register_column(	'gl_account', &
																'd_popup_gl_account_no_control', &
																'gl_account', &
																'description', &
																TRUE, 450, TRUE, TRUE, FALSE)
																
																
dw_main.inv_popup_data_list.of_register_column(	'trade_union', &
																'd_popup_trade_union_active', &
																'trade_union', &
																'description', &
																TRUE, 450, FALSE, TRUE, FALSE)
																
																
dw_main.inv_popup_data_list.of_register_column(	'occupation', &
																'd_popup_occupation_by_trade', &
																'occupation', &
																'occupation', &
																TRUE, 440, FALSE, TRUE, FALSE, "", &
																ls_extra_values_display,  &
																ls_extra_values_display, & 
																"trade_union","trade_union")


dw_main.inv_popup_data_list.of_register_column(	'tax_province', &
																'd_popup_province', &
																'province', &
																'name', &
																TRUE, 1350, TRUE, FALSE, FALSE)
																
dw_main.inv_popup_data_list.of_register_column(	'wcb_class', &
																'd_popup_wcb_class', &
																'wcb_class', &
																'wcb_class', &
																TRUE, 1400, TRUE, TRUE, FALSE)
																

dw_main.inv_popup_data_list.of_register_column(	'job', &
																'd_popup_job_with_labour_centres', &
																'job', &
																'job', &
																TRUE, 805, TRUE, TRUE, TRUE)
																
dw_main.inv_popup_data_list.of_register_column(	'roe_reason_code', &
																'd_popup_roe_reason', &
																'reason', &
																'reason', &
																TRUE, 2000, TRUE, FALSE, FALSE)																


dw_main.inv_popup_data_list.of_register_column(	'shift_pattern_type', &
																'd_popup_shift_pattern', &
																'pattern_type', &
																'pattern', &
																TRUE, 800, TRUE, FALSE, FALSE)


dw_main.inv_popup_data_list.of_register_column(	'supervisor', 										&
																	'd_popup_employee_active', 				&
																	'employee_long', 								&
																	'employee_long', 								&
																	TRUE, 860, 												&
																	TRUE,		/* empty allowed */ 				&
																	FALSE, 	/* retrieve by company */		&
																	FALSE, 	/* retrieve on register */ 	&
																	"active = 'Y'") 	


gnv_synchronize.uf_register_interest("REFRESH_UNION_LIST", luo_object)
gnv_synchronize.uf_register_interest("REFRESH_OCCUPATION_LIST", luo_object)
gnv_synchronize.uf_register_interest("REFRESH_OCCUPATION_RATE", luo_object)
gnv_synchronize.uf_register_interest("REFRESH_FROM_ADRS_PERSON", luo_object)
gnv_synchronize.uf_register_interest("REFRESH_FROM_BDAY_PERSON", luo_object)
gnv_synchronize.uf_register_interest("REFRESH_FROM_GST_PERSON", luo_object)
gnv_synchronize.uf_register_interest("REFRESH_FROM_SIN_PERSON", luo_object)
gnv_synchronize.uf_register_interest("REFRESH_FROM_PHONE_PERSON", luo_object)

RETURN 1

end event

event ue_process_print;call super::ue_process_print;//************************************************************
// Object   :	u_cst_tb_labour_rate_type_detail 
// Event    :	ue_process_print
// Author   :	Monica Petersen
// Date     :	2010/10/04
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


dw_main.EVENT pfc_print()

RETURN 1
end event

event ue_process_add;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_process_add
// Author   :	Lourdes Garcia
// Date     :	2009/04/30
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			override, do not update if there are errors
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long			ll_row, &
				ll_employee, &
				ll_person_row
				
Integer		li_rc = -1
s_parm 		lstr_parm

Datetime		ldt_hire_date

String		ls_trade_union,&
				ls_occupation, &
				ls_job, 			&
				ls_roe, 			&
				ls_null, 		&
				ls_new_trade, 	& 
				ls_new_level, 	&
				ls_note, 		&
				ls_gl_account

//get trade and level
ll_row = dw_main.GetRow()

IF ll_row > 0 THEN
	
	//jira 3480 - allow user to change crew assignments through employee entry
	IF dw_main.GetItemNumber(1, 'crew_count') < 2 THEN
		
		ibo_crew_member.of_Reset()
		IF ibo_crew_member.of_update_crew_assignments(il_employee,	&
																	  '', &
																	  dw_main.GetItemString(1, 'job'), 		&
																	  is_original_crew, 							&
																	  dw_main.GetItemString(1, 'crew'), &
																	  Date(dw_main.GetItemDateTime(1, 'hire_date'))) = -1 THEN
			RETURN -1
		END IF
	END IF
	
	// update person table if any of the following are updated
	ll_employee = ibo_datapanel_business.of_GetItemNumber(ll_row,"employee")
	
	ll_person_row = ibo_person.of_retrieve("employee = " + string(ll_employee))
	IF ll_person_row > 0 THEN
		ibo_person.of_SetItem(ll_person_row,"ccra_business_no", dw_main.GetItemString(ll_row,"gst"))
		ibo_person.of_SetItem(ll_person_row,"birth_date", dw_main.GetItemDateTime(ll_row,"birth_date"))
		ibo_person.of_SetItem(ll_person_row,"sin", dw_main.GetItemString(ll_row,"sin"))
		ibo_person.of_SetItem(ll_person_row,"ssn", dw_main.GetItemString(ll_row,"ssn"))
	ELSE
		this.of_msg_db_error("Cannot Retrieve Person Information")
		RETURN -1
	END IF
	
	ls_trade_union = ibo_datapanel_business.of_GetItemString(ll_row,"trade_union")
	ls_occupation = ibo_datapanel_business.of_GetItemString(ll_row,"occupation")
	ibo_occupation.of_get_trade_level(is_book, ls_trade_union, ls_occupation, ls_new_trade, ls_new_level)
		
	// if above function fails, proceeding with insert with null trade and level
	ll_employee = ibo_datapanel_business.of_GetItemNumber(ll_row,"employee")
	ldt_hire_date = ibo_datapanel_business.of_GetItemDatetime(ll_row,"hire_date")
	ls_job = ibo_datapanel_business.of_GetItemString(ll_row,"job")
	ls_roe = ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code")
	ls_note = ibo_datapanel_business.of_GetItemString(ll_row,"roe_note")
	ls_gl_account = ibo_datapanel_business.of_GetItemString(ll_row,"gl_account")
	SetNull(ls_null)
	
	ibo_person_diary.of_reset()
	IF ibo_person_diary.of_insert_diary(ll_employee, ldt_hire_date,'H',is_book, ls_gl_account, ls_job,ls_null,ls_roe, & 
											  gnv_app.of_getuserid(), ls_new_trade, ls_new_level,ls_note) = -1 THEN
		dw_main. EVENT ue_setmessage("Error in Inserting Person Diary Information","Red")
		RETURN -1
	END IF
	
	IF EVENT ue_update() = 1 THEN
		
		dw_main. EVENT ue_setmessage("Employee has been added.","Blue")
																			
		//Refresh employee popups
		dw_main.inv_popup_data_list.of_retrieve_popup_data("employee")
		dw_main.inv_popup_data_list.of_retrieve_popup_data("name_add")
		
		// set Header back to 0
		dw_main.Modify("DataWindow.Header.Height=0")
		
		//gnv_synchronize.uf_event_trigger('SHOW_EARNINGS_TAB', lstr_parm)

		// warning message
//		Messagebox("P/R Employee","Ensure Cheque, Incentive and Premium information are correct")
//		
//		// focus on cheque tab
//		lstr_parm.l_parm[1] = 1  
//		lstr_parm.l_parm[2] = 1
//		gnv_synchronize.uf_event_trigger('FOCUS_CHEQUE_TAB', lstr_parm)
		
		li_rc = 1
	END IF	
END IF	
																		
RETURN li_rc																
end event

event ue_process_change;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_process_change
// Author   :	Lourdes Garcia
// Date     :	2009/04/30
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			- Update in SIN. GST, Birthdate should update person table
//					- Update in restrict_flag should update pr_cheque and timesheet restrict_flag
// 				- update in job, trade or occupation should insert new person_diary entry
//             OVERRIDE
//					- Validate GST on Vendor if employment_type = 'S'
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2011-09-12		MDP		jira 1869 - modify employee entry so that a change to the union does not create a Person Diary Log Entry (and a change to trade does)
// 2012-09-05		MDP		jira 2357 - move premiums to new union if they are valid there
//************************************************************

String					ls_sin, ls_ssn
s_validation_error 	lstr_error[]

Long		ll_row, &
			ll_employee, &
			ll_prc_row, &
			ll_timesheet_row, &
			ll_index, &
			li_row_diary, ll_diary_rowcount, &
			ll_ep_row, ll_ep_rows, &
			ll_tu_row, ll_tup_rows, ll_tup_row, ll_ep_row_new, ll_pt_row, ll_pt_rows
			
Decimal	ldec_tah_rate, ldec_ovr_rate

Int		li_errcount, &
			li_error, &
			ll_person_row, &
			li_ret, &
			li_rc = -1, &
			li_diary_item

String	ls_trade_union, &
			ls_occupation, &
			ls_new_trade, &
			ls_new_level, &
			ls_job, &
			ls_roe, &
			ls_null, &
			ls_error_message, &
			ls_trade_union_orig, &
			ls_occupation_orig, &
			ls_orig_trade, &
			ls_orig_level, &
			ls_roe_desc, &
			ls_note, &
			ls_gl_account

string 	ls_action, &
			ls_current_roe, &
			ls_current_file_type, &
			ls_message, &
			ls_premium_exp_msg, ls_premium_moved_msg, ls_premium_msg

Datetime ldt_hire_date_orig, & 
			ldt_terminate_date_orig, &
			ldt_current_termination, &
			ldt_current_loa_date, &
			ldt_current_next_turnaround, &
			ldt_current_next_travel, &
			ldt_null, &
			ldt_hire_date, &
			ldt_current_shift_start
			
Date		ld_pp_start
			
s_parm	lstr_parm			

ib_warn_union_changed = FALSE

ll_row = dw_main.GetRow()


ls_action = dw_main.GetItemString(ll_row,"action")

SetNull(ldt_null)
SetNull(ls_null)

ibo_person_diary.of_reset()

// update person table if any of the following are updated
ll_employee = ibo_datapanel_business.of_GetItemNumber(ll_row,"employee")

IF ll_row > 0  THEN
	
	//jira 3480 - allow user to change crew assignments through employee entry
	IF ls_action <> 'Y' AND dw_main.GetItemNumber(1, 'crew_count') < 2 THEN	//reemploy just re-activates previous crews
	
		IF ls_action = 'C' THEN
			//We might be here from re-emploY action, which would have reinstated the employee in crews
			//they were previously assigned to
			//if not, start with a fresh business object
			ibo_crew_member.of_Reset()
		END IF
		
		IF ibo_crew_member.of_update_crew_assignments(il_employee,	&
																	  dw_main.GetItemString(1, 'job', Primary!, TRUE), &
																	  dw_main.GetItemString(1, 'job'), &
																	  is_original_crew, &
																	  dw_main.GetItemString(1, 'crew'), &
																	  Today()) = -1 THEN
			RETURN -1
		END IF
	END IF
	
	IF ibo_datapanel_business.of_GetItemStatus(ll_row,'trade_union',Primary!) = DataModified! THEN
		
		ib_warn_union_changed = TRUE
		
		IF ibo_company.of_get_pp_start_date(ibo_datapanel_business.of_GetItemString(ll_row, 'trade_union'), ld_pp_start) < 0 THEN
			RETURN -1
		END IF
			
		//Clean up future dated premiums
		ll_ep_rows = ibo_employee_premium.of_Retrieve("book = '" + is_book + "' AND employee = " + String(il_employee) &
						+ " AND effective_date >= '" + String(ld_pp_start, 'yyyy.mm.dd') + "'")
		IF ll_ep_rows > 0 THEN
			FOR ll_ep_row = ll_ep_rows TO 1 STEP -1
				ibo_employee_premium.of_DeleteRow(ll_ep_row)
			NEXT
			
			//Update and start fresh
			ibo_employee_premium.of_setlogactioncode('D')
			li_ret = ibo_employee_premium.of_Update(TRUE,			/* Don't skip validation and bo_preupdate() logic */ 	&
																FALSE, 		/* don't commit */										&
																lstr_error	/* return errors */)	
			
			li_errcount = UpperBound(lstr_error)
			IF li_errcount > 0 THEN
				FOR li_error = 1 TO li_errcount
					 ls_error_message += gnv_app.of_format_validation_error(lstr_error[li_error]) + '~r'
				NEXT
				gnv_error.of_add(90,gs_last_window,"R", ls_error_message,-1,"","person")
				dw_main.EVENT ue_setmessage("Error updating employee premiums","Red")
				MessageBox("Employee Premiums", "Error removing future dated premiums: " + ls_error_message)				
				ibo_employee_premium.of_rollback()
			END IF
			
			//Don't want a second update to happen?
			ibo_employee_premium.of_reset()
		END IF
		
		//Changing the trade union means we need new premiums
		ll_pt_rows = ibo_premium_type.of_Retrieve('')
		ll_ep_rows = ibo_employee_premium.of_Retrieve("book = '" + is_book + "' AND employee = " + String(il_employee) &
						+ " AND effective_date <= '" + String(ld_pp_start, 'yyyy.mm.dd') &
						+ "' AND expiry_date > '" + String(ld_pp_start, 'yyyy.mm.dd') + "'")
		IF ll_ep_rows > 0 THEN
			ls_premium_exp_msg = ''
			ls_premium_moved_msg = ''

			FOR ll_ep_row = ll_ep_rows TO 1 STEP -1
				
				IF Len(ibo_datapanel_business.of_GetItemString(ll_row, 'trade_union')) > 0 THEN
					ll_tup_rows = ibo_trade_union_premium.of_Retrieve("book = '" + is_book &
									+ "' AND trade_union = '" + ibo_datapanel_business.of_GetItemString(ll_row, 'trade_union') &
									+ "' AND effective_date <= '" + String(ld_pp_start, 'yyyy.mm.dd') &
									+ "' AND expiry_date > '" + String(ld_pp_start, 'yyyy.mm.dd') + "'")
					ll_tu_row = ibo_trade_union.of_retrieve("book = '" + gnv_app.is_book &
									+ "' AND trade_union = '" + ibo_datapanel_business.of_GetItemString(ll_row, 'trade_union') + "'")
					//jira 2357 - move premiums to new union if they are valid there
					ll_tup_row = ibo_trade_union_premium.of_Find("premium_type = '" + ibo_employee_premium.of_GetItemString(ll_ep_row, 'premium_type') + "'", 1, ll_tup_rows)
					IF ll_tup_row > 0 AND ll_tu_row > 0 THEN

						ll_ep_row_new = ibo_employee_premium.of_InsertRow(0)
						IF ll_ep_row_new > 0 THEN
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'book', 						gnv_app.is_book)
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'employee', 					il_employee)
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'premium_type', 			ibo_employee_premium.of_GetItemString(ll_ep_row, 'premium_type'))
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'effective_date', 			ld_pp_start)
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'expiry_date', 				ibo_employee_premium.of_GetItemDateTime(ll_ep_row, 'expiry_date'))
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'add_user_id', 				gnv_app.of_getuserid())
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'add_datetime', 			DateTime(Today(), Now()))
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'reg_rate', 					ibo_trade_union_premium.of_GetItemDecimal(ll_tup_row, 'minimum_hour_rate'))
							
							//Determine overtime rates
							ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ibo_employee_premium.of_GetItemString(ll_ep_row, 'premium_type') + "'", 1, ll_pt_rows)
							IF ll_pt_row > 0 THEN
								IF ibo_premium_type.of_GetItemString(ll_pt_row, 'overtime_hour_flag') = 'Y' THEN
									IF ibo_premium_type.of_GetItemString(ll_pt_row, 'overtime_multiplier_flag') = 'Y' THEN
										ldec_tah_rate = ibo_employee_premium.of_GetItemDecimal(ll_ep_row_new, 'reg_rate') * ibo_trade_union.of_GetItemDecimal(ll_tu_row, "tah_multiplier")
										ldec_ovr_rate = ibo_employee_premium.of_GetItemDecimal(ll_ep_row_new, 'reg_rate') * ibo_trade_union.of_GetItemDecimal(ll_tu_row, "ovr_multiplier")
									ELSE
										ldec_tah_rate = ibo_employee_premium.of_GetItemDecimal(ll_ep_row_new, 'reg_rate')
										ldec_ovr_rate = ibo_employee_premium.of_GetItemDecimal(ll_ep_row_new, 'reg_rate')
									END IF
								ELSE
									ldec_tah_rate = 0
									ldec_ovr_rate = 0
								END IF
							ELSE
								ldec_tah_rate = 0
								ldec_ovr_rate = 0
							END IF
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'tah_rate', ldec_tah_rate)
							ibo_employee_premium.of_SetItem(ll_ep_row_new, 'ovr_rate', ldec_ovr_rate)
						END IF
						IF ls_premium_moved_msg <> '' THEN ls_premium_moved_msg += ', '
						ls_premium_moved_msg += ibo_employee_premium.of_GetItemString(ll_ep_row, 'premium_type')
					ELSE
						IF ls_premium_exp_msg <> '' THEN ls_premium_exp_msg += ', '
						ls_premium_exp_msg += ibo_employee_premium.of_GetItemString(ll_ep_row, 'premium_type')
					END IF
				END IF

				//Expire premium 
				ibo_employee_premium.of_SetItem(ll_ep_row, 'expiry_date', gnv_app.inv_datetime.of_RelativeDateTime(DateTime(ld_pp_start, Time(0,0,0)), -60*60*24))
				
			NEXT

			//Inform the user of the changes
			ls_premium_msg = ''
			IF ls_premium_exp_msg <> '' THEN
				ls_premium_msg = 	"Premium(s) " + ls_premium_exp_msg &
												+ " are not valid in trade union " + ibo_datapanel_business.of_GetItemString(ll_row, 'trade_union') &
												+ " and have been marked expired.~n~r~n~r"
			END IF
			IF ls_premium_moved_msg <> '' THEN
				ls_premium_msg += 	"Premium(s) " + ls_premium_moved_msg + " have been updated.  Current unpaid timesheets using these premiums may need to be recalculated."
			END IF

			ibo_employee_premium.of_setlogactioncode('C')
			li_ret = ibo_employee_premium.of_Update(TRUE,		/* Don't skip validation and bo_preupdate() logic */ 	&
																FALSE, 		/* don't commit */										&
																lstr_error	/* return errors */)	
			
			li_errcount = UpperBound(lstr_error)
			IF li_errcount > 0 THEN
				FOR li_error = 1 TO li_errcount
					 ls_error_message += gnv_app.of_format_validation_error(lstr_error[li_error]) + '~r'
				NEXT
				gnv_error.of_add(90,gs_last_window,"R", ls_error_message,-1,"","person")
				dw_main.EVENT ue_setmessage("Error updating employee premiums","Red")
				MessageBox("Employee Premiums", "Error updating premiums: " + ls_error_message)				
				ibo_employee_premium.of_rollback()
			END IF
			//Don't want a second update to happen?
			ibo_employee_premium.of_reset()
		END IF

		// set Header back to 0
		dw_main.Modify("DataWindow.Header.Height=0")
					
	END IF
			
	// update person table if any of the following are updated
	ll_person_row = ibo_person.of_retrieve("employee = " + string(il_employee))
	IF ll_person_row > 0 THEN
		ibo_person.of_SetItem(ll_person_row,"ccra_business_no", dw_main.GetItemString(ll_row,"gst"))
		ibo_person.of_SetItem(ll_person_row,"birth_date", dw_main.GetItemDateTime(ll_row,"birth_date"))
		ls_sin = dw_main.GetItemString(ll_row, "sin")
		IF Trim(ls_sin) = '' THEN SetNull(ls_sin)
		ibo_person.of_SetItem(ll_person_row,"sin", ls_sin)
		
		ls_ssn = dw_main.GetItemString(ll_row, "ssn")
		IF Trim(ls_ssn) = '' THEN SetNull(ls_ssn)
		ibo_person.of_SetItem(ll_person_row,"ssn", ls_ssn)
		
	ELSE
		this.of_msg_db_error("Cannot Retrieve Person Information")
		RETURN -1
	END IF

	// check if restrict_flag changed
	IF (ibo_datapanel_business.of_GetItemStatus(ll_row, 'restrict_flag', Primary!) = DataModified!) THEN
		dw_main.EVENT ue_setmessage("Updating restrictions on cheques and timesheets","Blue")
		
		// Timesheet Update
		ibo_timesheet.ib_centres_must_be_open = FALSE
		
		//Only look at timesheets that have been validated.  Ignore any preliminary
		//timesheets that may be in progress on a supervisors web app.
		ll_timesheet_row = ibo_timesheet.of_retrieve("employee = " + string(il_employee) &
																	+ " and book = '" + is_book &
																	+ "' AND file_type IN ('C','H')")
		IF ll_timesheet_row  >= 0 THEN
			FOR ll_index = 1 to ll_timesheet_row
				ibo_timesheet.of_SetItem(ll_index,"restrict_flag", ibo_datapanel_business.of_GetItemString(ll_row,"restrict_flag"))
			NEXT	
		ELSE
			this.of_msg_db_error("Cannot Retrieve Timesheet Information")
			RETURN -1
		END IF
		
		//pr_cheque update
		ll_prc_row = ibo_pr_cheque.of_retrieve("employee = " + string(il_employee) + " and book = '" + is_book + "'")
		IF ll_prc_row >= 0 THEN
			FOR ll_index = 1 TO ll_prc_row
				ibo_pr_cheque.of_SetItem(ll_index, "restrict_flag", ibo_datapanel_business.of_GetItemString(ll_row,"restrict_flag"))
			NEXT					
		ELSE
			this.of_msg_db_error("Cannot Retrieve PR Cheque Information")
			RETURN -1
		END IF
	END IF

	// update in trade or occupation --> another person_diary insert, comparing old trade and level before
	//  doing an insert
	// update in job and gl_account too
	IF (ibo_datapanel_business.of_GetItemStatus(ll_row, 'trade_union', Primary!) = DataModified! ) OR &
		(ibo_datapanel_business.of_GetItemStatus(ll_row, 'occupation', Primary!) = DataModified! ) OR &
		(ibo_datapanel_business.of_GetItemStatus(ll_row, 'job', Primary!) = DataModified!) OR &
		(ibo_datapanel_business.of_GetItemStatus(ll_row, 'gl_account', Primary!) = DataModified!) THEN
		
		//compare if old trade and level or not the same
		//get current trade and level
		ls_trade_union = ibo_datapanel_business.of_GetItemString(ll_row,"trade_union")
		ls_occupation = ibo_datapanel_business.of_GetItemString(ll_row,"occupation")
		ibo_occupation.of_get_trade_level(is_book, ls_trade_union, ls_occupation, ls_new_trade, ls_new_level)
	
		
		//get old trade and level
		ls_trade_union_orig = ibo_datapanel_business.of_GetItemString(ll_row,"trade_union",Primary!,TRUE)
		ls_occupation_orig = ibo_datapanel_business.of_GetItemString(ll_row,"occupation",Primary!, TRUE)
		ibo_occupation.of_get_trade_level(is_book, ls_trade_union, ls_occupation, ls_orig_trade, ls_orig_level)
		
		IF ls_action = 'C'  or ls_action = 'Z' THEN
	
			IF (ls_orig_trade <> ls_new_trade) OR (ls_occupation <> ls_occupation_orig)  &
			OR	(ibo_datapanel_business.of_GetItemStatus(ll_row, 'job', Primary!) = DataModified!)  &
			OR	(ibo_datapanel_business.of_GetItemStatus(ll_row,'gl_account',Primary!) = DataModified!) THEN

				dw_main.Modify("t_messagebox.Height.AutoSize=Yes")
				dw_main.EVENT ue_setmessage("Updating person diary  with Trade Union, Occupation, Job or GL Account update","Blue")
				// insert to person diary
				il_employee = ibo_datapanel_business.of_GetItemNumber(ll_row,"employee")
				ls_job = ibo_datapanel_business.of_GetItemString(ll_row,"job")
				ls_roe = ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code")
				ls_note = ibo_datapanel_business.of_GetItemString(ll_row,"roe_note")
				ls_gl_account = ibo_datapanel_business.of_GetItemString(ll_row,"gl_account")
				IF ibo_person_diary.of_insert_diary(il_employee, DateTime(Today(),Now()),'L',is_book, ls_gl_account, ls_job,ls_null,ls_roe, & 
													  gnv_app.of_getuserid(), ls_new_trade, ls_new_level,ls_note) = 1 THEN
				ELSE
					RETURN -1
				END IF
			END IF	
		END IF
	END IF	
	
	//update in hire_date should update T and H entries from person_diary
	// update in hire date --> update person_diary from the original hire date
	// with the latest item if action = 'C'
	IF (ibo_datapanel_business.of_GetItemStatus(ll_row, 'hire_date', Primary!) = DataModified! ) THEN
		IF ls_action = 'C' OR ls_action = 'Z' THEN
			
		
			// get original hire
			ldt_hire_date_orig = ibo_datapanel_business.of_getitemdatetime(ll_row,"hire_date",primary!,TRUE)
			
			ll_diary_rowcount = ibo_person_diary.of_retrieve("employee = " + string(il_employee) + & 
														" and book = '" + gnv_app.is_book + "'" + &
														" and CONVERT(varchar, diary_date, 112) = '" + string(ibo_datapanel_business.of_getitemdatetime(ll_row,"hire_date"), 'YYYYMMDD') + "'") 
														
			ibo_person_diary.of_setsort("diary_item desc")
			ibo_person_diary.of_sort()
			
			li_diary_item = 0
			IF ll_diary_rowcount > 0 THEN 
				li_diary_item = ibo_person_diary.of_GetItemNumber(1, "diary_item")
				li_diary_item = li_diary_item + 1
			END IF
			
			li_row_diary = ibo_person_diary.of_retrieve("employee = " + string(il_employee) + & 
														" and book = '" + gnv_app.is_book + "' and diary_type = 'H'" + &
														" and CONVERT(varchar, diary_date, 112) = '" + string(ldt_hire_date_orig, 'YYYYMMDD') + "'") 
			
			IF li_row_diary > 0 THEN																				
				// update person_diary entry
				ibo_person_diary.of_setitem(1,"diary_date", ibo_datapanel_business.of_getitemdatetime(ll_row,"hire_date"))
				IF li_diary_item > 0 THEN 
					ibo_person_diary.of_setitem(1, "diary_item", li_diary_item)
				END IF
			ELSE
				this.of_msg_db_error("Error in Updating Person Diary Information")
				RETURN -1
			END IF
		END IF	
	
		IF ls_action = 'Y' THEN
			ldt_hire_date_orig = ibo_datapanel_business.of_getitemdatetime(ll_row,"hire_date",primary!,TRUE)
			ldt_terminate_date_orig = ibo_datapanel_business.of_getitemdatetime(ll_row,"termination_date",primary!,TRUE)
			ldt_hire_date = ibo_datapanel_business.of_getitemdatetime(ll_row,"hire_date")
			
			// Jira#1282  : If there's no change in the hire date, do not create new H entry and delete current termination diary entry
			IF ldt_hire_date_orig = ldt_hire_date THEN
				// delete termination diary event		
				ibo_person_diary.of_delete_termination_entry(ldt_terminate_date_orig,il_employee, is_book)
			END IF
		END IF
	END IF
	
	IF ls_action = 'Y' THEN
			
		// update termination date and roe_code columns
		// get current values of termination, roe, file_type
		ldt_current_termination = ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date") 
		ls_current_roe = ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code") 
		ls_current_file_type = ibo_datapanel_business.of_GetItemString(ll_row,"file_type") 
		ldt_current_loa_date = ibo_datapanel_business.of_GetItemDatetime(ll_row,"loa_change_date") 
		ldt_current_next_turnaround =  ibo_datapanel_business.of_GetItemDatetime(ll_row,"next_turnaround_due_date") 
		ldt_current_next_travel = ibo_datapanel_business.of_GetItemDatetime(ll_row,"next_travel_due_date") 
		ldt_current_shift_start = ibo_datapanel_business.of_GetItemDatetime(ll_row,"shift_start_date") 
	
		ibo_datapanel_business.of_SetItem(ll_row,"termination_date",ldt_null) 
		ibo_datapanel_business.of_SetItem(ll_row,"roe_reason_code",ls_null) 
		ibo_datapanel_business.of_SetItem(ll_row,"roe_note",ls_null) 
		ibo_datapanel_business.of_SetItem(ll_row,"file_type",'C') 
		dw_main.SetItem(ll_row,"roe_desc",ls_null)
	
		// update columns that will create validation errors from itemchange of hire_date to NULL
		// these columns are shift_start_date, loa_change_date, next_turnaround_due_date, next_travel_due_date
		ibo_datapanel_business.of_SetItem(ll_row,"loa_change_date",ldt_null) 
		ibo_datapanel_business.of_SetItem(ll_row,"next_turnaround_due_date",ldt_null) 
		ibo_datapanel_business.of_SetItem(ll_row,"next_travel_due_date",ldt_null) 
		
		// update person_diary
		//get trade and level
		ls_trade_union = ibo_datapanel_business.of_GetItemString(ll_row,"trade_union")
		ls_occupation = ibo_datapanel_business.of_GetItemString(ll_row,"occupation")
		ibo_occupation.of_get_trade_level(is_book, ls_trade_union, ls_occupation, ls_new_trade, ls_new_level)

		// if above function fails, proceeding with insert with null trade and level
		ldt_hire_date = ibo_datapanel_business.of_GetItemDatetime(ll_row,"hire_date")
		ls_job = ibo_datapanel_business.of_GetItemString(ll_row,"job")
		IF ls_job = '' THEN SetNull(ls_job)
		ls_roe = ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code")
		ls_note = ibo_datapanel_business.of_GetItemString(ll_row,"roe_note")
		IF ls_roe = '' THEN SetNull(ls_roe)
		ls_gl_account = ibo_datapanel_business.of_GetItemString(ll_row,"gl_account")
		
		IF ldt_hire_date_orig <> ldt_hire_date THEN
			IF ibo_person_diary.of_insert_diary(il_employee, ldt_hire_date,'H',is_book, ls_gl_account, ls_job,ls_null,ls_roe, & 
											  gnv_app.of_getuserid(), ls_new_trade, ls_new_level,ls_note) = 1 THEN
			END IF								  
		END IF	
	END IF	
	
	
	//Preliminary employees become current
	IF dw_main.GetItemString(1, 'file_type') = 'P' THEN
		dw_main.SetItem(1, 'file_type', 'C')
	END IF
	
	// proceed with updating person table
	IF EVENT ue_update() = 1 THEN
		
		//successful updtae
		li_rc = 1
		
		CHOOSE CASE ls_action
		CASE 'C','Z'
			IF Len(is_message) > 0 THEN 
				ls_message = is_message + ". Employee has been changed" 
			ELSE
				ls_message =  "Employee Updated"
			END IF	
			
			//Trigger employee to use new rates
			of_event_synchronize('RESET_OCCUPATION_RATES', lstr_parm)

		CASE 'H'
			IF ibo_datapanel_business.of_GetItemString(ll_row, "file_type") = 'H' THEN
				ls_message =  "Employee moved to history"
			ELSE
				ls_message =  "Employee restored from history"
			END IF
		CASE ELSE
			IF Len(is_message) > 0 THEN 
				ls_message = is_message + ". Employee has been reemployed"
			ELSE
				ls_message = "Employee has been reemployed"
			END IF	
		END CHOOSE
	
		dw_main.EVENT POST ue_setmessage(ls_message,"Blue")
	
		IF ls_premium_msg <> '' THEN 
			MessageBox("Employee Premiums", ls_premium_msg)
		END IF

	ELSE

		//Don't leave message dangling if there might be validation errors
		CHOOSE CASE ls_action
		CASE 'C','Z'
			IF Len(is_message) > 0 THEN 
				ls_message = is_message + ". Employee change failed" 
			ELSE
				ls_message =  "Employee change failed"
			END IF	
		CASE 'H'
			IF ibo_datapanel_business.of_GetItemString(ll_row, "file_type") = 'H' THEN
				ls_message =  "Unable to move employee to history"
			ELSE
				ls_message =  "Unable to restore employee from history"
			END IF
		CASE ELSE
			IF Len(is_message) > 0 THEN 
				ls_message = is_message + ". Unable to re-employ employee."
			ELSE
				ls_message = "Unable to re-employ employee"
			END IF	
		END CHOOSE
	
		dw_main.EVENT POST ue_setmessage(ls_message,"Red")
	
		IF ls_action = 'Y' THEN
			// set columns back to orignal values
			ibo_datapanel_business.of_SetItem(ll_row,"termination_date",ldt_current_termination) 
			dw_main.SetItemStatus(ll_row,"termination_date",Primary!,NotModified!)
	
			ibo_datapanel_business.of_SetItem(ll_row,"roe_reason_code",ls_current_roe) 
			dw_main.SetItemStatus(ll_row,"roe_reason_code",Primary!,NotModified!)
	
			ibo_roe_reason.of_get_roe_description(ls_current_roe,ls_roe_desc)
			dw_main.SetItem(ll_row,"roe_desc",ls_roe_desc)
			dw_main.SetItemStatus(ll_row,"roe_desc",Primary!,NotModified!)
	
			ibo_datapanel_business.of_SetItem(ll_row,"file_type",ls_current_file_type) 
			dw_main.SetItemStatus(ll_row,"file_type",Primary!,NotModified!)
			
			ibo_datapanel_business.of_SetItem(ll_row,"loa_change_date",ldt_current_loa_date) 
			dw_main.SetItemStatus(ll_row,"loa_change_date",Primary!,NotModified!)
			
			ibo_datapanel_business.of_SetItem(ll_row,"next_turnaround_due_date",ldt_current_next_turnaround) 
			dw_main.SetItemStatus(ll_row,"next_turnaround_due_date",Primary!,NotModified!)
			
			ibo_datapanel_business.of_SetItem(ll_row,"next_travel_due_date",ldt_current_next_travel) 
			dw_main.SetItemStatus(ll_row,"next_travel_due_date",Primary!,NotModified!)
	
			ibo_datapanel_business.of_SetItem(ll_row,"shift_start_date",ldt_current_shift_start) 
			dw_main.SetItemStatus(ll_row,"shift_start_date",Primary!,NotModified!)
		END IF	
		
		RETURN -1
		
	END IF	
END IF

is_message = ""

RETURN li_rc
end event

event ue_process_delete;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_process_delete
// Author   :	Lourdes Garcia
// Date     :	2009/05/01
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Set Message if there are errors in deletion, override
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long		ll_row, &
			ll_employee

Int 		li_rc
			
DateTime	ldt_termination_date, ldt_hire_date

ll_row = dw_main.GetRow()

IF ll_row > 0 THEN
	ll_employee = ibo_datapanel_business.of_GetItemNumber(ll_row,"employee")
	is_name_deleted = dw_main.GetItemString(ll_row,"name")
	ldt_hire_date = ibo_datapanel_business.of_GetItemDateTime(ll_row,"hire_date")
	ldt_termination_date = ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date")	
	
	IF ibo_person_diary.of_delete_diary(ldt_hire_date, ldt_termination_date, il_employee, is_book) = -1 THEN
		RETURN -1
	END IF
	
	li_rc = EVENT ue_update()
	
	IF li_rc = 1  THEN
		dw_main. POST EVENT ue_setmessage('Employee ' + is_name_deleted + ' has been deleted.','Blue')
		
		// re-register pop-up to update list after deleting the new person entry to employee table
		dw_main.inv_popup_data_list.of_register_column(	'employee', &
																				'd_popup_employee_add', &
																				'employee', &
																				'employee', &
																				1600, FALSE, TRUE, TRUE, "")	
			
		dw_main.inv_popup_data_list.of_register_column(	'name_add', &
																				'd_popup_employee_name_add', &
																				'name_add', &
																				'name_add', &
																				400, FALSE, TRUE, TRUE, "")	
																				
	END IF
END IF	

RETURN li_rc

end event

event ue_process_other;call super::ue_process_other;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_process_other
// Author   :	Lourdes Garcia
// Date     :	2009/05/01
// 	
// Arguments:	string as_action_id
// 	
// Returns:		integer
// 	
// Desc:			'T'erminate and Reemplo'Y', 'H'istory
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2010.01.05		MDP		jira 1387 - ROE's not produced at start of year, 
//                         use cheques rather than employee_earning records
//                         to decide to produce the ROE.
// 2012.01.16		MDP		jira 2005 - reset td 1 minimums
// 2021.04.05		MDP		write ROE locally before copying over cloud
//************************************************************

s_validation_error lstr_error[]
s_parm				 lstr_parm
DateTime				 ldt_expiry
	
String				ls_crew
//String				ls_temp_local_file_path 

n_bo_employee		lbo_employee

INTEGER 				li_FileNum, li_count
STRING				ls_file_lines, ls_file, ls_new_file 
LONG					ll_BytesRead, ll_FileLength, ll_employee_pos, ll_employee_pos_end


Int		li_rc, &
			li_errcount, &
			li_error

Integer	li_rc_u

			
Long		ll_row, &
			ll_earnings, &
			ll_drow, &
			ll_cm_row, ll_cm_rows
			
String	ls_note, &
			ls_null, &
			ls_trade_union, &
			ls_occupation, &
			ls_new_trade, &
			ls_new_level, &
			ls_job, &
			ls_roe, &
			ls_error_message, &
			ls_delta, &
			ls_where, &
			ls_gl_account, &
			ls_msg
String 	ls_temp_dir, ls_temp_local_file

DateTime	ldt_termination_date, &
			ldt_null, &
			ldt_hire
			

//Variables for reinstating premiums
Integer			li_pt_row, li_pt_rows, li_tu_row, li_tup_row, li_tup_rows
Integer			li_ep_row, li_ep_rows, li_ep_new
Decimal			ldec_tah_rate, ldec_ovr_rate

DWItemStatus	ldws_termination_date

ll_row = dw_main.GetRow()

SetNull(ls_null)
SetNull(ldt_null)

CHOOSE CASE as_action_id
CASE 'Y'	//Re-employ
	
	//Check the trade union is populated
	ls_trade_union = ibo_datapanel_business.of_GetItemString(ll_row,"trade_union")
	
	IF Trim(ls_trade_union) = '' THEN
		dw_main.EVENT ue_setmessage("Trade union not populated","Red")
		RETURN -1
	END IF 
				
	//Get overtime multipliers for this trade union
	li_tu_row = ibo_trade_union.of_retrieve("book = '" + gnv_app.is_book + "' AND trade_union = '" + ls_trade_union + "'")
	IF li_tu_row < 1 THEN 
		this.of_msg_db_error("Error reading trade union")
		RETURN -1
	END IF
	
	IF ibo_trade_union.of_getitemString(li_tu_row, "active_flag") = 'N' THEN
		dw_main.EVENT ue_setmessage("Trade Union " + ls_trade_union + " is not active","Red")
		RETURN -1
	END IF
	
	//Get the date the previous premiums would have expired on
	ldt_hire = ibo_datapanel_business.of_GetItemDatetime(1, "hire_date")
	ldt_termination_date = ibo_datapanel_business.of_GetItemDatetime(1, "termination_date")

	//Get all current trade_union_premiums
	ls_where = "book = '" + gnv_app.is_book &
					+ "' AND trade_union = '" + ls_trade_union &
					+ "' AND '"  + String(ldt_hire, 'yyyymmdd')  + "' BETWEEN CONVERT(varchar, effective_date, 112) AND CONVERT(varchar, expiry_date, 112)"
	IF IsNull(ls_where) THEN
		this.of_msg_db_error("Error formatting where clause for trade union")
		RETURN -1
	END IF

	//Only initiate reinstatement if there are active premiums for this union
	li_tup_rows = ibo_trade_union_premium.of_retrieve(ls_where) 
	IF li_tup_rows < 0 THEN
		this.of_msg_db_error("Error reading trade union")
		RETURN -1
	END IF
		
	IF li_tup_rows > 0 THEN
		
		// warning message
		IF Messagebox("P/R Employee","Ensure Cheque, Incentive and Premium information are correct." &
						+ "~n~nReset premiums active at time of termination?", Question!, YesNo!, 1) = 1 THEN
						
			//Get all premium types and find rows of interest later
			li_pt_rows = ibo_premium_type.of_retrieve()
			
			//Reactivate employee premiums
			li_ep_rows = ibo_employee_premium.of_Retrieve("book = '" + gnv_app.is_book &
															  + "' AND employee = " + String(il_employee) &
															  + "  AND expiry_date = '" + String(ldt_termination_date, 'yyyy.mm.dd') + "'")
			IF li_ep_rows < 0 THEN
				this.of_msg_db_error("Error reading employee premiums")
				RETURN -1
			END IF 
			
			//Reinstate each employee premium
			FOR li_ep_row = 1 TO li_ep_rows
				
				//Get overtime settings for this premium type
				li_pt_row = ibo_premium_type.of_find("premium_type = '" + ibo_employee_premium.of_getitemString(li_ep_row, "premium_type") + "'", 1, li_pt_rows)		
				IF li_pt_row < 1 THEN
					this.of_msg_db_error("Premium type not found")
					RETURN -1
				END IF
				
				IF ibo_premium_type.of_GetItemString(li_pt_row, 'active_flag') = 'Y' THEN 

					//Verify the employee premium is still valid in the trade union
					li_tup_row = ibo_trade_union_premium.of_Find("premium_type = '" &
											+ ibo_employee_premium.of_getitemString(li_ep_row, "premium_type") + "'", 1, li_tup_rows)
				
					IF li_tup_row > 0 THEN
						
						//Determine overtime rates based on premium type settings and trade union multipliers
						IF ibo_premium_type.of_GetItemString(li_pt_row, 'overtime_hour_flag') = 'Y' THEN
							IF ibo_premium_type.of_GetItemString(li_pt_row, 'overtime_multiplier_flag') = 'Y' THEN
								ldec_tah_rate = (ibo_employee_premium.of_GetitemDecimal(li_ep_row, "reg_rate") * ibo_trade_union.of_getitemDecimal(li_tu_row, "tah_multiplier"))
								ldec_ovr_rate = (ibo_employee_premium.of_GetitemDecimal(li_ep_row, "reg_rate") * ibo_trade_union.of_getitemDecimal(li_tu_row, "ovr_multiplier"))
							ELSE
								ldec_tah_rate = ibo_employee_premium.of_GetitemDecimal(li_ep_row, "reg_rate") 
								ldec_ovr_rate = ibo_employee_premium.of_GetitemDecimal(li_ep_row, "reg_rate") 
							END IF
						ELSE
							ldec_tah_rate = 0
							ldec_ovr_rate = 0
						END IF
							
						//If this is a same day rehire, just extend the expiry date
						IF ibo_employee_premium.of_GetItemDateTime(li_ep_row, 'effective_date') = ldt_hire THEN
							ibo_employee_premium.of_SetItem(li_ep_row, 'expiry_date', 		DateTime(Date(2099,12,31), Time(0,0,0)))
							ibo_employee_premium.of_SetItem(li_ep_row, "tah_rate", Round(ldec_tah_rate, 2))
							ibo_employee_premium.of_SetItem(li_ep_row, "ovr_rate", Round(ldec_ovr_rate, 2))
						ELSE	
					
							li_ep_new = ibo_employee_premium.of_InsertRow(0)
							IF li_ep_new < 1 THEN
								this.of_msg_db_error("Unable to insert premium")
								RETURN -1
							END IF							
								
							//Reactivate premium
							ibo_employee_premium.of_SetItem(li_ep_new, "book", 				gnv_app.is_book)
							ibo_employee_premium.of_SetItem(li_ep_new, "employee", 			il_employee)
							ibo_employee_premium.of_SetItem(li_ep_new, "premium_type", 		ibo_employee_premium.of_getitemString(li_ep_row, "premium_type"))
							ibo_employee_premium.of_SetItem(li_ep_new, 'effective_date',	ldt_hire)
							ibo_employee_premium.of_SetItem(li_ep_new, 'expiry_date', 		DateTime(Date(2099,12,31), Time(0,0,0)))
							ibo_employee_premium.of_SetItem(li_ep_new, "reg_rate", 			ibo_employee_premium.of_GetitemDecimal(li_ep_row, "reg_rate"))
	
							ibo_employee_premium.of_SetItem(li_ep_new, "tah_rate", Round(ldec_tah_rate, 2))
							ibo_employee_premium.of_SetItem(li_ep_new, "ovr_rate", Round(ldec_ovr_rate, 2))
						END IF
					END IF
				END IF
			NEXT		
		END IF
	END IF
	
	// jira 4378 - when rehiring employees, don't try to reattach them to their previous crew
	// Jira 3461 - reinstate employee to any crews they were on
//	li_rc = ibo_datapanel_business.of_GetChild("crew_member", ibo_crew_member)
//	IF Not IsValid(ibo_crew_member) THEN
//		this.of_msg_db_error("Error updating crew members")
//		RETURN -1
//	ELSE
//		ibo_crew_member.of_Reset()
//	END IF
//	li_rc = ibo_datapanel_business.of_GetChild("crew", ibo_crew)
//	IF Not IsValid(ibo_crew) THEN
//		this.of_msg_db_error("Error reading crew")
//		RETURN -1
//	ELSE
//		ibo_crew.of_Reset()
//	END IF
//	ll_cm_rows = ibo_crew_member.of_Retrieve("employee = " + String(il_employee))
//	FOR ll_cm_row = 1 TO ll_cm_rows
//		
//		//Check crew active flag
//		ll_c_rows = ibo_crew.of_Retrieve("job = '" + ibo_crew_member.of_GetItemString(ll_cm_row, 'job') &
//										+ "' AND crew = '" + ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') + "'")
//		IF ll_c_rows < 0 THEN 
//			this.of_msg_db_error("Error retrieving crew")
//			RETURN -1
//		END IF
//		IF ibo_crew.of_GetItemString(1, 'active_flag') = 'Y' THEN
//			//give user option to reinstate
//			IF MessageBox("Crew Assignment",f_get_person_name(il_employee) + " was previously assigned to crew " &
//										+ ibo_crew_member.of_GetItemString(ll_cm_row, 'job') &
//										+ "/" + ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') &
//										+ ". Reinstate to this crew?", Question!, YesNo!, 1) = 1 THEN
//				IF ibo_crew_member.of_GetItemDateTime(ll_cm_row, 'effective_date') = ldt_hire_date THEN
//					//unexpire matching record
//					ibo_crew_member.of_SetItem(ll_cm_row, 'expiry_date', 						Date(2099,12,31))
//				ELSE
//					//reinstate in crew
//					ll_new_row = ibo_crew_member.of_InsertRow(0)
//					ibo_crew_member.of_SetItem(ll_new_row, 'job_or_region',					ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region'))
//					ibo_crew_member.of_SetItem(ll_new_row, 'crew', 								ibo_crew_member.of_GetItemString(ll_cm_row, 'crew'))
//					ibo_crew_member.of_SetItem(ll_new_row, 'employee', 						il_employee)
//					ibo_crew_member.of_SetItem(ll_new_row, 'supervisor_flag', 				'N')
//					ibo_crew_member.of_SetItem(ll_new_row, 'alternate_supervisor_flag', 	'N')
//					ibo_crew_member.of_SetItem(ll_new_row, 'effective_date', 				ldt_hire_date)
//					ibo_crew_member.of_SetItem(ll_new_row, 'expiry_date', 					Date(2099,12,31))
//				END IF
//			END IF
//		END IF
//		
//	NEXT
	
	IF EVENT ue_process_change() = 1 THEN
		// set Header back to 0
		dw_main.Modify("DataWindow.Header.Height=0")
					
		// focus on cheque tab
//		lstr_parm.l_parm[1] = 1  
//		lstr_parm.l_parm[2] = 1
//		gnv_synchronize.uf_event_trigger('FOCUS_CHEQUE_TAB', lstr_parm)
//	ELSE
//		ibo_datapanel_business.of_Rollback()
//		RETURN -1
	END IF	

CASE 'T'
	
	// Terminate Process
	ldt_termination_date = ibo_datapanel_business.of_GetItemDatetime(ll_row,"termination_date")
	ls_roe = ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code")
	IF IsNull(ldt_termination_date) THEN
		MessageBox('Terminate', 'Please supply the termination date')
		dw_main.EVENT ue_setmessage('Please supply the termination date',"Red")
		dw_main.POST SetColumn('termination_date')
		dw_main.POST SetFocus()
		RETURN 0
	END IF
	
	IF Len(ls_roe) > 0 THEN
	ELSE
		MessageBox('Terminate', 'Please supply the ROE reason code')
		dw_main.EVENT ue_setmessage('Please supply the ROE reason code',"Red")
		dw_main.POST SetColumn('roe_reason_code')
		dw_main.POST SetFocus()
		RETURN 0
	END IF
	
	
	// jira 4040 - remove crew reference on employee
	ibo_datapanel_business.of_SetItem(ll_row, 'crew', ls_null)
	
	// update subordinates if employee is a supervisor
	IF NOT IsValid(lbo_employee) THEN
		lbo_employee = CREATE n_bo_employee
		lbo_employee.of_SetTransaction()
	END IF
	
	// Jira 3461 - expire employee from any crews they are on
	li_rc = ibo_datapanel_business.of_GetChild("crew_member", ibo_crew_member)
	IF Not IsValid(ibo_crew_member) THEN
		this.of_msg_db_error("Error updating crew members")
		RETURN -1
	END IF
	
	li_rc = ibo_datapanel_business.of_GetChild("crew", ibo_crew)
	IF Not IsValid(ibo_crew) THEN
		this.of_msg_db_error("Error reading crew")
		RETURN -1
	END IF
	ls_msg = ''
	
	// jira 4040 - fix bug where retroactive terminations mean future dated crew members don't get expired
	
	//Retrieve all the active crew memberships for this employee
	ll_cm_rows = ibo_crew_member.of_Retrieve("employee = " + String(il_employee)										&
															+ " AND expiry_date >= '" + String(ldt_termination_date, 'yyyy.mm.dd') + "'")

	IF ll_cm_rows = -1 THEN
		this.of_msg_db_error("Error reading crew members")
		RETURN -1
	END IF
	
	FOR ll_cm_row = ll_cm_rows TO 1 STEP -1
		
		IF ibo_crew_member.of_GetItemString(ll_cm_row, 'supervisor_flag') = 'Y' THEN
			
			//For each active crew where the employee is a supervisor, inactivate the crew
			ls_job = ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region') 
			ls_crew = ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') 
			ldt_expiry = ibo_crew_member.of_GetItemDateTime(ll_cm_row, 'expiry_date') 
			
			//Check the crew is active
			IF ibo_crew.of_Count("job_or_region = '" + ls_job + "' AND crew = '" + ls_crew + "' AND active_flag = 'Y'") > 0 THEN 
				
				IF ibo_crew.of_Retrieve("job_or_region = '" + ls_job + "' AND crew = '" + ls_crew + "' AND active_flag = 'Y'") > 0 AND /* active crew */&
					ibo_crew_member.of_count("job_or_region = '" + ls_job &
										  + "' AND crew = '" + ls_crew &
										  + "' AND supervisor_flag = 'Y' AND employee <> " + String(il_employee) &
										  + "  AND expiry_date > '" + String(Date(ldt_expiry), "YYYY-MM-DD") + "'") = 0 /* no future supervisors are setup */ THEN
												
					//Inactivate this crew
					ibo_crew.of_setItem(1, "active_flag", "N")															
					ibo_crew.of_update(FALSE, lstr_error)
	
					li_errcount = UpperBound(lstr_error)
					IF li_errcount > 0 THEN
						FOR li_error = 1 TO li_errcount
							 ls_error_message += lstr_error[li_error].s_message + '~r'
						NEXT
						MessageBox('Inactivating Crews', ls_error_message )
						dw_main. EVENT ue_setmessage("Error inactivating crews","Red")
						RETURN -1
					END IF
				END IF
				
				//=== at this point, ibo_crew_member ONLY contains the records for the supervisor ===
				//=== so use SQL to apply changes to ALL crew members ===

				//Set all crew members to expire from the crew on the same day the supervisor expires
				//Don't know what to do about crew members assigned to this crew after the supervisor's
				//termination date.  The user should sort their crews out such that they have a future supervisor.
				UPDATE crew_member 
					SET expiry_date = :ldt_termination_date
				WHERE job_or_region = :ls_job AND 
						crew = :ls_crew AND 
						supervisor_flag <> 'Y' AND 
						effective_date <= :ldt_termination_date AND 
						expiry_date > :ldt_termination_date
				USING SQLCA;
				IF sqlca.sqlcode <> 0 THEN
					dw_main. EVENT ue_setmessage("Error expiring crew members in " + ls_job + "/" + ls_crew + ".","Red")
					this.of_msg_db_error("Error expiring crew members in " + ls_job + "/" + ls_crew )
					ROLLBACK USING SQLCA;
					RETURN -1
				END IF
						
				IF ibo_crew_member.of_GetItemDateTime(ll_cm_row, 'effective_date') > ldt_termination_date THEN
					//Delete if designated to supervise in the future
					ibo_crew_member.of_DeleteRow(ll_cm_row)
				ELSE
					//expire if currently supervising
					ibo_crew_member.of_SetItem(ll_cm_row, 'expiry_date', ldt_termination_date)
					ibo_crew_member.of_SetItem(ll_cm_row, 'alternate_supervisor_flag', 'N')
				END IF
			END IF
		END IF
	NEXT

	
	This.ibo_datapanel_business.DYNAMIC of_set_termination_delta(ls_delta)
	
	ldt_hire = ibo_datapanel_business.of_GetItemDatetime(ll_row,"hire_date")
	SetNull(ldt_null)

	//jira 1387 - look at cheques rather than earnings record.  Terminations done early january weren't producing ROE's
	ll_earnings = ibo_pr_cheque.of_retrieve("employee = " + string(il_employee)  					&
								+ " AND book = '" + is_book + "'"  												&
								+ " AND issue_date >= '" + string(ldt_hire, 'yyyy.mm.dd')  + "'"		&
								+ " AND cheque_status in ('P','R') " 											&
								+ " AND ei_earn <> 0 " )

	// if there are current employment earnings proceed with creating ROE file
	IF ll_earnings <= 0 THEN	
		//jira 3735
		MessageBox("P/R Employee Entry", ibo_datapanel_business.of_GetItemString(ll_row, 'name') + " has no EI earnings.  No Record of Employment will be produced.")
	ELSE
		IF dw_main.GetItemString(ll_row,"employment_type") = 'Y' THEN
			
			//Get a file to write to, but avoid asking for a file name each time by using previously selected file
			DO WHILE TRUE
				IF is_ROE_path = '' THEN 
					is_ROE_path = gnv_app.of_get_save_location('Employee ROE', gnv_app.is_book + '_' +  string(TODAY(),'yyyymmdd') + '.BLK', "blk", "BLK (*.blk),*.blk", FALSE, FALSE)
			
					//If they don't select a file, they can't terminate the employee
					IF is_ROE_path = '' THEN
						dw_main.POST EVENT ue_setmessage("Employee not terminated, please select an ROE file","Red")
						ROLLBACK USING SQLCA;
						RETURN 0
					END IF
					
					//Cleanup file if they want to start fresh
					IF FileExists(is_ROE_path) AND FileLength(is_ROE_path) > 0 THEN
						li_rc = MessageBox("P/R Employee Entry", is_ROE_path + ' already exists.  Ok to purge prior web ROEs?', Question!, YesNoCancel!) 
						CHOOSE CASE li_rc
							CASE 1
								IF Not(FileDelete(is_ROE_path)) THEN
									MessageBox("P/R Employee Entry", "Delete failed for " + is_ROE_path + ", unable to terminate employee")
									ROLLBACK USING SQLCA;
									RETURN 0
								END IF
									
							CASE 3
								is_ROE_path = ''
						END CHOOSE
					END IF
				END IF
				
				//If we have a filename we can exit the loop
				IF is_ROE_path <> '' THEN
					IF FileExists(is_ROE_path) AND FileLength(is_ROE_path) > 0 THEN
						ib_ROE_exists = TRUE
						EXIT
					ELSE
						ib_ROE_exists = FALSE
						EXIT
					END IF
				END IF
			LOOP
		END IF
	END IF	

	// update person_diary
	//get trade and level
	ls_trade_union = ibo_datapanel_business.of_GetItemString(ll_row,"trade_union")
	ls_occupation = ibo_datapanel_business.of_GetItemString(ll_row,"occupation")
	IF ibo_occupation.of_get_trade_level(is_book, ls_trade_union, ls_occupation, ls_new_trade, ls_new_level) < 1 THEN
		// error logging handled in the business object function above
	END IF

	// if above function fails, proceeding with insert with null trade and level
	ls_job = ibo_datapanel_business.of_GetItemString(ll_row,"job")
	ls_roe = ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code")
	ls_note = ibo_datapanel_business.of_GetItemString(ll_row,"roe_note")
	ls_gl_account = ibo_datapanel_business.of_GetItemString(ll_row,"gl_account")
	
	// check if it is only a change in the termination column information
	IF ldws_termination_date  = NotModified! THEN
		ls_where = "employee = " + string(il_employee) + " and book = '" + is_book + "' and " + &
					 "  CONVERT(varchar, diary_date, 112) = '" + string(ldt_termination_date, 'YYYYMMDD') + "' and diary_type = 'T' " 
	ELSE
		IF NOT IsNull(idt_current_termination_date) THEN
			ls_where = "employee = " + string(il_employee) + " and book = '" + is_book + "' and " + &
						 "  CONVERT(varchar, diary_date, 112) = '" + string(idt_current_termination_date, 'YYYYMMDD') + "' and diary_type = 'T' "
		ELSE
			// new entry
			ls_where = "employee = " + string(il_employee) + " and book = '" + is_book + "' and " + &
					 "  CONVERT(VARCHAR, diary_date, 112) = '" + string(ldt_termination_date, 'YYYYMMDD') + "' and diary_type = 'T' " 
		END IF
	END IF

	ibo_person_diary.of_reset()
	ll_drow = ibo_person_diary.of_retrieve( ls_where )

	IF ll_drow > 0 THEN
		// change current termination entry
		ibo_person_diary.of_SetItem(ll_drow,'diary_date', ldt_termination_date)
		ibo_person_diary.of_SetItem(ll_drow,'roe_reason_code', ls_roe)
		ibo_person_diary.of_SetItem(ll_drow,'note', ls_note )
	ELSE
		IF ibo_person_diary.of_insert_diary(il_employee, ldt_termination_date,'T',is_book, ls_gl_account, ls_job,ls_null,ls_roe, & 
										  gnv_app.of_getuserid(), ls_new_trade, ls_new_level,ls_note) < 0 THEN
			ROLLBACK USING SQLCA;							  
	  		RETURN -1
		END IF
	END IF
	 
	//Expire the premiums
	IF Not(IsNull(ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date") )) THEN
		li_ep_rows = ibo_employee_premium.of_Retrieve("book = '" + is_book + "' AND employee = " + String(il_employee) &
						+ " AND effective_date <= '" + String(ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date"), 'yyyy.mm.dd') &
						+ "' AND expiry_date > '" + String(ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date"), 'yyyy.mm.dd') + "'")
		IF li_ep_rows > 0 THEN
			MessageBox("Employee Premiums", "Employee " + String(il_employee) + " has " + String(li_ep_rows) + " active premium(s).  They will now expire as of " + String(ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date"), 'yyyy.mm.dd')  + ".~nIf the employee is reemployed in the future, the premiums will have to be reinstated.")
			FOR li_ep_row = 1 TO li_ep_rows
				ibo_employee_premium.of_SetItem(li_ep_row, 'expiry_date', ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date"))
			NEXT
		END IF
	END IF
	
	IF EVENT ue_update() = 1 THEN
		IF ll_earnings > 0 THEN
			
			//If possible, save the file locally, format it, and then copy it to it's requested location.
			//Otherwise excel has trouble formatting the remote file
			ls_temp_dir = gs_curr_dir
			IF Right(ls_temp_dir, 1) = '\' THEN 
				ls_temp_dir = ls_temp_dir + 'Temp'
			ELSE
				ls_temp_dir = ls_temp_dir + '\Temp'
			END IF
			
			IF Not(DirectoryExists(ls_temp_dir)) THEN
				CreateDirectory(ls_temp_dir)
			END IF
			
			IF DirectoryExists(ls_temp_dir) THEN
				ls_temp_local_file = ls_temp_dir + '\' + gnv_app.of_getuserid() + String(Now(), 'mmssfff') 
			END IF
			
			//Copy existing ROE to temporary file
			IF ib_ROE_exists THEN
				li_rc = FileCopy(is_ROE_path, ls_temp_local_file, TRUE /* overwrite - but shouldn't be a problem */)
				CHOOSE CASE li_rc 
					CASE -1 
						MessageBox('ROE', 'Error opening ' + is_ROE_path)
						RETURN -1
					CASE -2
						//Log this one, it indicates a bigger problem
						gnv_app.of_msg_db_error('ROE', 'Error opening ' + ls_temp_local_file)
						RETURN -1
				END CHOOSE
			END IF
		
			//Write ROE
			li_FileNum = FileOpen(ls_temp_local_file, LineMode!)
			IF li_FileNum > 0 THEN
				
				//Append to existing file
				DO
					ll_BytesRead = FileRead( li_FileNum , ls_file_lines ) 
					IF ll_BytesRead <> -100 and ASC(ls_file_lines) <> 26 THEN
					  ll_FileLength += ll_BytesRead 
					  li_count ++ 
					  IF LEN(ls_file) > 0 THEN
						  ls_file = ls_file + char(13) + char(10) + ls_file_lines 
					  ELSE  
						  ls_file = ls_file_lines
					  END IF	 
					ELSE 
					  ll_FileLength += Len( ls_file_lines ) 
					END IF
				LOOP UNTIL ll_BytesRead <= 0 or Asc(ls_file_lines) = 26
				
				// find position on employee
				ll_employee_pos = POS(ls_file,'<Roe PrintingLanguage="E" Issue="D">' + char(13) + char(10) + '<B3>' + string(il_employee) + '</B3>')
				IF ll_employee_pos > 0 THEN
					ll_employee_pos_end = POS(ls_file,'</B20>' + char(13) + char(10) + '</Roe>', ll_employee_pos)
					ls_new_file = MID(ls_file,1,(ll_employee_pos - 1)) + MID(ls_file, ll_employee_pos_end + 14, len(ls_file))
					
					// remove entire block of employee, write back to termination file and append new employee
					FileClose(li_FileNum )
					li_FileNum = FileOpen(ls_temp_local_file, StreamMode!, Write!, Shared!, Replace!)
					FileWrite(li_FileNum , ls_new_file)
					FileClose(li_FileNum)
					
					//Now write the ROE
					IF this.EVENT ue_termination_file(ls_temp_local_file) = -1 THEN
						ROLLBACK USING SQLCA;
						RETURN -1
					END IF
				ELSE
					FileClose(li_FileNum )
					IF this.EVENT ue_termination_file(ls_temp_local_file) = -1 THEN
						ROLLBACK USING SQLCA;
						RETURN -1
					END IF
				END IF	
				
			ELSE
				// write  new termination file
				IF this.EVENT ue_termination_file(ls_temp_local_file) = -1 THEN
					ROLLBACK USING SQLCA;
					RETURN -1
				END IF
			END IF
			
			//Copy temporary file to ROE
			li_rc = FileCopy(ls_temp_local_file, is_ROE_path, TRUE /* overwrite - but shouldn't be a problem */)
			CHOOSE CASE li_rc 
				CASE -1 
					gnv_app.of_msg_db_error('ROE', 'Error opening ' + ls_temp_local_file)
					RETURN -1
				CASE -2
					gnv_app.of_msg_db_error('ROE', 'Error opening ' + is_ROE_path)
					RETURN -1
				CASE ELSE
					FileDelete(ls_temp_local_file)
			END CHOOSE
			
			//New standard to open the file just created
			ShellExecute(handle(this), 'open', is_ROE_path, ls_null, ls_null, 0)

		END IF
				
		dw_main.POST EVENT ue_setmessage("Employee has been terminated.","Blue")
		

	END IF
	
	IF IsValid(lbo_employee) THEN DESTROY lbo_employee		

CASE 'H'
	// save history
	li_rc = EVENT ue_update()
	IF li_rc = 1 THEN
		CHOOSE CASE il_history_flag
			CASE 0
				dw_main.EVENT ue_setmessage("Employee restored from history","Blue")
			CASE 1
				dw_main.EVENT ue_setmessage("Employee moved to history","Blue")	
			CASE -1 
				dw_main.EVENT ue_setmessage("ERROR - History change failed","Red")
		END CHOOSE		
	ELSE	
		dw_main.EVENT ue_setmessage("ERROR - History change failed","Red")
	END IF

END CHOOSE

IF li_rc < 0 THEN 
	ROLLBACK USING SQLCA;
END IF

RETURN li_rc
end event

event ue_validate;call super::ue_validate;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_validate
// Author   :	Lourdes Garcia
// Date     :	2009/05/06
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

String				ls_action, &
						ls_rehire_flag, &
						ls_note, &
						ls_employment_type, &
						ls_sina, &
						ls_sinb, &
						ls_chk, &
						ls_gst, &
						ls_sin, & 
						ls_shift_pattern, &
						ls_roe_code, &
						ls_work_permit_book, &
						ls_tax_province
						
Int					li_proceed = 1, &
						li_n1, &
						li_row

Long					ll_employee, &
						ll_row, &
						ll_rows
						
DateTime				ldt_shift_start_date, ldt_hire_date, ldt_termination_date
Date					ldt_shift_start

DateTime				ldt_birth

n_ds	lds_crew_crew_member
lds_crew_crew_member = CREATE n_ds	

n_bo_work_permit				lbo_work_permit

lds_crew_crew_member.DataObject = 'd_ds_crew_crew_member'
lds_crew_crew_member.SetTransObject(SQLCA)

ll_row = dw_main.GetRow()

dw_main.AcceptText()

ls_action = dw_main.GetItemString(ll_row, 'action')



IF ls_action = 'Y' THEN
	// check if termination_date is empty, only rehire employees that were terminated
	ldt_termination_date = ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date") 		
	IF IsNull(ldt_termination_date) THEN
		dw_main.POST SetColumn("hire_date")
		dw_main.POST SetFocus()
		dw_main.POST EVENT ue_setmessage("Employee is not Terminated","Red")
		RETURN -1
	END IF
END IF

IF ls_action = 'A' or ls_action = 'Y' THEN
	// check for rehire flag
	ll_employee = dw_main.GetItemNumber(ll_row,"employee")
	IF ibo_person.of_get_person_rehire_fields(ll_employee,ls_rehire_flag, ls_note) = 1 THEN
		IF ls_rehire_flag = 'N' THEN
			IF IsNull(ls_note) THEN ls_note = ""
			dw_main.POST SetColumn("employee")
			dw_main.POST SetFocus()

			dw_main.POST EVENT ue_setmessage("DO NOT REHIRE: " + ls_note,"Red")
			MessageBox(iw_parent.title,"The H/R record for this employee indicates they should not be rehired.  Please review.")
			RETURN 0
		END IF
	ELSE
		dw_main.POST SetColumn("employee")
		dw_main.POST SetFocus()
		dw_main.POST EVENT ue_setmessage("Cannot determine rehire fields from person table.","Red")
		RETURN 0
	END IF
	
	// check for mailing address
	IF (IsNull(dw_main.GetItemString(ll_row,'mailing_address_1')) AND &
		IsNull(dw_main.GetItemString(ll_row,'mailing_address_2')))  OR &
		IsNull(dw_main.GetItemString(ll_row,'mailing_city'))  OR &
		IsNull(dw_main.GetItemString(ll_row,'mailing_country')) THEN
		dw_main.POST SetColumn("mailing_address_1")
		dw_main.POST SetFocus()
		dw_main.POST EVENT ue_setmessage("Missing address fields. Please complete from Person Entry Screen","Red")
		RETURN 0
	END IF
	
	//check the set of books for temporary foreign workers 
	IF ibo_person.of_count("employee = " + string(ll_employee) + " AND temporary_foreign_worker = 'Y'") > 0 THEN
		lbo_work_permit = CREATE n_bo_work_permit
		li_row = lbo_work_permit.of_retrieve("employee = " + string(ll_employee) + " AND permit_expiry_date > '" + String(Today(), 'YYYY-MM-DD') + "'")
		IF li_row > 0 THEN
			lbo_work_permit.of_setsort("permit_issue_date DESC")
			lbo_work_permit.of_sort()
			ls_work_permit_book = lbo_work_permit.of_GetItemString(1, "book") 
			
			IF ls_work_permit_book <> gnv_app.is_book THEN
				DESTROY lbo_work_permit
				dw_main.POST EVENT ue_setmessage("Employee's work permit is for company " + ls_work_permit_book + ".","Red")
				RETURN 0
			END IF
		ELSE
			MessageBox(iw_parent.Title, "Temporary foreign worker with no work permit recorded.")
		END IF
		DESTROY lbo_work_permit
	END IF
END IF

IF ls_action = 'A' OR ls_action = 'C' OR ls_action = 'Z' OR ls_action = 'Y' THEN
	
	//Validate birth date
	ldt_birth = dw_main.GetItemDateTime(ll_row,"birth_date")
	IF IsNull(ldt_birth) THEN
		dw_main.POST SetColumn("birth_date")
		dw_main.POST SetFocus()
		dw_main.POST EVENT ue_setmessage("Birth Date is Required","Red")
		RETURN 0
	END IF
	
	CHOOSE  CASE YEAR(TODAY()) - YEAR(Date(ldt_birth)) 
		CASE IS < 10 
			dw_main.POST SetColumn("birth_date")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("Employee Must Be At Least 10 Years Old","Red")
			li_proceed = 0
		CASE IS > 85	
			dw_main.POST SetColumn("birth_date")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("Employee Must Be At Most 85 Years Old","Red")
			RETURN 0
	END CHOOSE

	//Validate CCRA number
	ls_employment_type = ibo_datapanel_business.of_GetItemString(ll_row,"employment_type")
	ls_gst = dw_main.GetItemString(ll_row,"gst")
	IF ls_employment_type = 'S' THEN
		
		//check for null GST
		IF ls_gst = "" OR IsNull(ls_gst) THEN
			dw_main.POST SetColumn("gst")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("GST is Required","Red")
			RETURN 0
		END IF
		
		IF LEN(ls_gst) <> 9 THEN
			dw_main.POST SetColumn("gst")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("GST should be 9 Digits","Red")
			RETURN 0
		END IF
		
		// check if numeric and non-zero
		IF NOT IsNumber(ls_gst) THEN
			dw_main.POST SetColumn("gst")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("GST should be Numeric","Red")
			RETURN 0
		END IF
		
		IF ls_gst = '000000000' THEN
			dw_main.POST SetColumn("gst")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("GST cannot be all Zeroes","Red")
			RETURN 0
		END IF	
	
	ELSEIF ls_employment_type = 'Y' THEN
		ls_tax_province = dw_main.GetItemString(1, "tax_province")
		
		IF IsNull(ls_tax_province) THEN 
			ls_tax_province = ""
		END IF
		
		If  ls_tax_province = "" THEN
			dw_main.POST SetColumn("tax_province")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("Tax Province is Required","Red")
			RETURN 0
		END IF
	END IF
  
	//Validate SIN
	ls_sin = dw_main.GetItemString(ll_row,"sin")
	IF ls_employment_type = 'Y' THEN
		// check for null SIN
		IF ls_sin= "" OR IsNull(ls_sin) THEN
			dw_main.POST SetColumn("sin")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("SIN is Required","Red")
			RETURN 0
		END IF

		// check for valid SIN
		ls_sina="0246813579135792468024680357913579146802468025791357913680246802479135791358024680246913579135702468"
		ls_sinb="0987654321098765432109876543210987654"
		
		li_n1 = Integer(Mid(ls_sina, Integer(Mid(ls_sin, 1, 2)) + 1, 1)) &
				+ Integer(Mid(ls_sina, Integer(Mid(ls_sin, 3, 2)) + 1, 1)) &
				+ Integer(Mid(ls_sina, Integer(Mid(ls_sin, 5, 2)) + 1, 1)) &
				+ Integer(Mid(ls_sina, Integer(Mid(ls_sin, 7, 2)) + 1, 1))
		ls_chk = Mid(ls_sinb, li_n1 + 1, 1)
		IF Mid(ls_sin, 9, 1) <> ls_chk THEN
			dw_main.POST SetColumn("sin")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("Social Insurance Number check digit should be " + ls_chk,"Red")
			RETURN 0
		END IF
	END IF 

	// check for shift_start_date

	// check start_date validation
	ls_shift_pattern = ibo_datapanel_business.of_GetItemString(ll_row,"shift_pattern_type")
	ldt_hire_date = ibo_datapanel_business.of_GetItemDateTime(ll_row,"hire_date")
	ldt_shift_start_date = ibo_datapanel_business.of_GetItemDateTime(ll_row,"shift_start_date")

	ldt_shift_start = ibo_shift_pattern.of_get_shift_start(ls_shift_pattern, ldt_hire_date)
	IF NOT IsNull(ldt_shift_start) THEN
		IF DATE(ldt_shift_start_date) < DATE(ldt_shift_start) OR DATE(ldt_shift_start_date) > TODAY() THEN
			dw_main.POST SetColumn("shift_start_date")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("Shift Start Date must be between " + String(ldt_shift_start, 'yyyy.mm.dd')  + " and " + string(TODAY(), 'yyyy.mm.dd'),"Red")
			RETURN 0
		END IF	
	END IF	
END IF	


// check termination and ROE must not be blank when terminating employees
IF ls_action = 'T' THEN
	
	// validate if termination date and roe are present
	ls_roe_code = ibo_datapanel_business.of_GetItemString(ll_row,"roe_reason_code")
	ldt_termination_date = ibo_datapanel_business.of_GetItemDateTime(ll_row,"termination_date")
	
	IF IsNull(ldt_termination_date) THEN
		dw_main.POST SetColumn("termination_date")
		dw_main.POST SetFocus()
		dw_main.POST EVENT ue_setmessage("Termination Date is Required","Red")
		RETURN 0
	END IF
	
	IF IsNull(ls_roe_code) THEN
		dw_main.POST SetColumn("roe_reason_code")
		dw_main.POST SetFocus()
		dw_main.POST EVENT ue_setmessage("ROE Reason is required","Red")
		RETURN 0
	END IF
	
	ll_employee = dw_main.GetItemNumber(ll_row,"employee")
	
	ll_rows = lds_crew_crew_member.Retrieve(ll_employee, 'Y', 'Y')
	
	IF ll_rows > 0 THEN 
		IF MessageBox(iw_parent.Title, "This employee is a supervisor to active crew(s).~rDo you want to inactivate crew(s) and expire active memberships?", Exclamation!, YesNo!, 1) = 2 THEN
			RETURN 0
		END IF
	END IF
	
	
//	//Jira#836:  check if employee is not a supervisor, give warning message only
//	
//	// count subordinate count from employee table
//	IF ibo_datapanel_business.of_count("termination_date IS NULL and employee <> " + string(il_employee) + " and supervisor = " + string(il_employee)) > 0 THEN
//		li_return = Messagebox("P/R Employee Entry","Employee is a supervisor. Please update employee records affected. List can only be generated at this time.")
//		IF li_return = 1 THEN
//			// open report
//			EVENT ue_process_print_supervisor()
//		END IF		
//	END IF			
		
END IF

RETURN 1
end event

event ue_process_z;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_process_z
// Author   :	Lourdes Garcia
// Date     :	2009/10/19
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Process change, override
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



EVENT ue_process_change()

RETURN 1
end event

event constructor;call super::constructor;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2013/01/14
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

UserObject luo_this

luo_this = This
gnv_synchronize.uf_register_interest("RESET_OCCUPATION_RATES", luo_this)	
gnv_synchronize.uf_register_interest("REFRESH_BRANCH_LIST", luo_this)	
is_program = 'PREENT'

end event

event ue_post_apply;call super::ue_post_apply;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_post_apply
// Author   :	Monica Petersen
// Date     :	2016/05/24
// 	
// Arguments:	string as_action
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

s_parm	lstr_parm

IF as_action = 'A' &
OR as_action = 'Y' &
OR (as_action = 'C' AND ib_warn_union_changed) THEN

	Messagebox("P/R Employee","Ensure Cheque, Incentive and Premium information are correct")

	lstr_parm.l_parm[1] = 1  
	lstr_parm.l_parm[2] = 1
	gnv_synchronize.uf_event_trigger('FOCUS_CHEQUE_TAB', lstr_parm)

END IF

RETURN AncestorReturnValue
end event

event ue_event_synchronize;call super::ue_event_synchronize;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_event_synchronize
// Author   :	Monica Petersen
// Date     :	2020/01/20
// 	
// Arguments:	string as_event_id
// 				s_parm astr_parm
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

CHOOSE CASE as_event_id
		
	CASE "REFRESH_EMPLOYEE_LIST"
		dw_main.inv_popup_data_list.of_retrieve_popup_data("employee")
		dw_main.inv_popup_data_list.of_retrieve_popup_data("name_add")
	CASE "REFRESH_OCCUPATION_LIST"
		dw_main.inv_popup_data_list.of_retrieve_popup_data("occupation")
	CASE "REFRESH_UNION_LIST"
		dw_main.inv_popup_data_list.of_retrieve_popup_data("trade_union")
	CASE "REFRESH_OCCUPATION_RATE"
		dw_main.inv_popup_data_list.of_retrieve_popup_data("occupation")
		
END CHOOSE

RETURN 1

end event

event ue_update;call super::ue_update;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_update
// Author   :	Monica Petersen
// Date     :	2020/03/07
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

s_parm	lstr_parm

of_event_synchronize('REFRESH_EMPLOYEE_LIST', lstr_parm)

RETURN AncestorReturnValue
end event

type hpb_progress from u_cst_datapanel_detail`hpb_progress within u_cst_pr_employee_detail
end type

type dw_main from u_cst_datapanel_detail`dw_main within u_cst_pr_employee_detail
string dataobject = "d_pr_employee_hire_term_assign"
boolean ib_iseventlog = true
end type

event dw_main::constructor;call super::constructor;//************************************************************
// Object   :	u_cst_employee_detail 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
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

This.of_set_popup_data(TRUE)

This.of_setdefaultactions('ACDIVPHYTZ')

This.of_register_entry_screen("employee", "w_hr_person", "HRPENT", {"employee"})
This.of_register_entry_screen("supervisor", "w_pr_employee", "PREENT", {"supervisor"})
This.of_register_entry_screen("trade_union", "w_tb_trade_union", "TBEENT", {"trade_union"})
This.of_register_entry_screen("occupation", "w_tb_occupation", "TBPENT", {"trade_union", "occupation"})
This.of_register_entry_screen("job", "w_jc_job", "JCJENT", {"job"})
This.of_register_entry_screen("area", "w_jc_area", "JCAENT", {"job", "area"})
This.of_register_entry_screen("centre", "w_jc_centre", "JCCENT", {"job", "area", "centre"})
This.of_register_entry_screen("shift_pattern_type", "w_st_shift_pattern", "STHENT", {"shift_pattern_type"})
This.of_register_entry_screen("gl_account", "w_gl_gl_account", "GLAENT", {"gl_account"})
This.of_register_entry_screen("tax_province", "w_st_province_tax", "STIENT", {"tax_province"})
This.of_register_entry_screen("federal_td1_claim", "w_staent", "STAENT", {"tax_province"})
This.of_register_entry_screen("provincial_td1_claim", "w_stient", "STIENT", {"tax_province"})
This.of_register_entry_screen("region", "w_st_region", "STNENT", {"region"})

IF f_get_job_based_crew_flag() = 'Y' THEN  
	This.of_register_entry_screen("crew", "w_st_crew", "STJENT", {"job","crew"})
ELSE
	This.of_register_entry_screen("crew", "w_st_crew", "STJENT", {"region","crew"})
END IF


This.of_register_report("add_datetime")

is_business_object = 'n_bo_employee'
ib_iseventlog = TRUE
this.ib_message_clears = FALSE //Change behaviour to clear message on <enter> instead of every keystroke

is_report_name = "Employee Hire Detail"

this.of_SetDropDownCalendar(TRUE)
this.iuo_calendar.of_Register("hire_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("termination_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("reminder_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("shift_start_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("birth_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("cpp_exempt_effective_date", this.iuo_calendar.NONE)

end event

event dw_main::clicked;//************************************************************
// Object   :	u_cst_employee_detail 
// Event    :	clicked
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
// 	
// Arguments:	integer xpos
// 				integer ypos
// 				long row
// 				dwobject dwo
// 	
// Returns:		long
// 	
// Desc:			Open calendar controls
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF dwo.name = 'b_calendar_hire' THEN
	
	IF This.SetColumn("hire_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF

END IF



IF dwo.name = 'b_calendar_birth' THEN
	
	IF This.SetColumn("birth_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF

END IF


IF dwo.name = 'b_calendar_term' THEN
	
	IF This.SetColumn("termination_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF

END IF

IF dwo.name = 'b_calendar_remind' THEN
	
	IF This.SetColumn("reminder_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF

END IF


IF dwo.name = 'b_calendar_shift' THEN
	
	IF This.SetColumn("shift_start_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF

END IF

IF dwo.name = 'b_cpp_exempt' THEN
	
	IF This.SetColumn("cpp_exempt_effective_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF

END IF

IF dwo.name = "supervisor_t" THEN 
	IF Len(This.of_GetItem(row, 'supervisor')) > 0 THEN
		//Only open entry screen if key is populated
		IF ibo_employee2.of_Retrieve("book = '" + gnv_app.is_book + "' AND employee = " + String(this.GetItemNumber(row, 'supervisor'))) = 1 THEN
			call super::clicked
		ELSE	
			this.EVENT ue_open_report(row,  'supervisor')
			RETURN 1
		END IF
	ELSE
		MessageBox("Open Entry Screen", "Supervisor is not populated.")
	END IF
ELSE
	call super::clicked
END IF 

RETURN AncestorReturnValue

end event

event dw_main::ue_fieldmicrohelp;call super::ue_fieldmicrohelp;//************************************************************
// Object   :	u_cst_employee_detail 
// Event    :	ue_fieldmicrohelp
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
// 	
// Arguments:	string as_column
// 				string as_microhelptext
// 	
// Returns:		(None)
// 	
// Desc:			Microhelp for 
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
Date							ldt_shift_start
DateTime						ldt_hire_date
Long							ll_row
String						ls_shift_pattern
n_bo_shift_pattern		lbo_shift_pattern

ll_row = dw_main.GetRow()

CHOOSE CASE as_column
	CASE 'shift_start_date'
		lbo_shift_pattern = CREATE n_bo_shift_pattern
		lbo_shift_pattern.of_SetTransaction()
		
		// get pattern and hire_date
		ls_shift_pattern = ibo_datapanel_business.of_GetItemString(ll_row,"shift_pattern_type")
		ldt_hire_date = ibo_datapanel_business.of_GetItemDateTime(ll_row,"hire_date")
		
		ldt_shift_start = lbo_shift_pattern.of_get_shift_start(ls_shift_pattern, ldt_hire_date)
		
		as_microhelptext = "Shift pattern start between " + String(ldt_shift_start, 'yyyy.mm.dd') + " and " + String(Today(), 'yyyy.mm.dd')
		
		
		DESTROY lbo_shift_pattern
		
	CASE 'supervisor'
		as_microhelptext = "valid employee " 
		
END CHOOSE		



		

end event

event dw_main::destructor;call super::destructor;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	destructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/27
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


This.of_set_popup_data(FALSE)
end event

event dw_main::itemchanged;//************************************************************
// Object   :	u_cst_employee_detail 
// Event    :	itemchanged
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	long row
// 				dwobject dwo
// 				string data
// 	
// Return:	Integer - 0=Accept value and allow focus to change
//							 1=Reject value and do not allow focus to change
//							 2=Reject value but allow the focus to change
// 	
// Desc:		OVERRIDE ANCESTOR so the employee can be validated before the ue_add_setup is invoked.
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
String				ls_curr_column, & 
						ls_action, & 
						ls_trade_union, &
						ls_occupation, &
						ls_province, &
						ls_null, &
						ls_old_job, ls_job, &
						ls_employment_type, &
						ls_field, &
						ls_sina, &
						ls_sinb, &
						ls_chk, &
						ls_shift_pattern, & 
						ls_roe, &
						ls_roe_desc, &
						ls_gl_account, &
						ls_gl_account_desc, &
						ls_area, &
						ls_area_desc, &
						ls_centre, &
						ls_centre_desc, &
						ls_area_data, &
						ls_current_book, &
						ls_current_book_terminated, &
						ls_prev_data, &
						ls_msg
						
Decimal				ldec_federal_td1_claim, &
						ldec_provincial_td1_claim
Long					ll_rc, &
						ll_employee, ll_null, ll_tur_rows, ll_tu_rows, ll_count, ll_timesheet_row, &
						ll_cm_rows, ll_cm_row, ll_c_rows
						
Int					li_n1, li_days, li_turnaround_cycle_days,  li_new_cycle_days, 	li_rc

DateTime			   ldt_null, ldt_hire_date, ldt_shift_start_date, ldt_turnaround, ldt_new_turnaround, ldt_term_date
Date					ldt_shift_start	

Boolean				lb_turnaround = FALSE, lb_cycle = FALSE
String				ls_pr_yyyymm
DateTime				ldt_pr_yyyymm

n_bo_province_income_tax			lbo_province_income_tax

ls_curr_column = lower(dwo.Name)

ls_action = This.GetItemString(1, 'action')
SetNull(ls_null)
SetNull(ll_null)

IF NOT IsValid(ibo_province_rate) THEN
	ibo_province_rate = CREATE n_bo_province_rate
	ibo_province_rate.of_SetTransaction()
END IF		

CHOOSE CASE ls_curr_column 
		
	CASE 'region'
		This.SetItem(1, "crew", ls_null)
	CASE 'employee'
		IF this.inv_popup_data_list.of_is_valid_value('employee', data) THEN
			il_employee = Long(data)
			IF ls_action = 'A' THEN 
				il_employee_indicator  = long(This.inv_popup_data_list.of_get_popup_item( 'employee', 'employed_indicator') )  
				is_current_book = string(This.inv_popup_data_list.of_get_popup_item( 'employee', 'current_book') )   
				is_current_book_terminated = string(This.inv_popup_data_list.of_get_popup_item( 'employee', 'latest_book_terminated') )
				
				//disable name_add because the user can put in a name that doesn't correspond with this employee, and it's confusing
				this.SetItem(1, 'name_add', '')
				this.POST of_disable_column('name_add')
			END IF
		ELSEIF data <> '0' AND data <> '' THEN
			RETURN 0
		ELSE
			IF ls_action = 'A' THEN
				//They haven't used the number field, so let them search in the name field
				this.POST of_enable_column('name_add')
				this.POST SetColumn('name_add')
			END IF
		END IF
		
	CASE 'name_add'
		IF this.inv_popup_data_list.of_is_valid_value('name_add', data) THEN
			il_employee = long(This.inv_popup_data_list.of_get_popup_item( 'name_add', 'employee_add') ) 
			this.SetItem(1, 'employee', il_employee)
			
			il_employee_indicator  = long(This.inv_popup_data_list.of_get_popup_item( 'name_add', 'employed_indicator') )  
			is_current_book = string(This.inv_popup_data_list.of_get_popup_item( 'name_add', 'current_book') )   
			is_current_book_terminated = string(This.inv_popup_data_list.of_get_popup_item( 'name_add', 'latest_book_terminated') )  
			EVENT itemchanged(1, this.object.employee, String(il_employee))
			//May be protected so everything gets skipped
			this.POST SetColumn('employment_type')
		END IF
		
	CASE 'employment_type'
		ls_prev_data = This.GetItemString(row,"employment_type", Primary!,TRUE)
		
		// Jira 1734:  If changed from S to Y, force the EI exempt, CPP exempt and Tax exempt flags to 'N'o
		IF string(data) = 'Y' and ls_prev_data = 'S' THEN
			This.SetItem(row,	"ei_exempt_flag","N")
			This.SetItem(row,	"cpp_exempt_flag","N")
			This.SetItem(row,	"income_tax_exempt_flag","N")
		END IF
		
	CASE 'trade_union'
		
		IF len(TRIM(data)) = 0 OR IsNull(data) THEN 
			ls_trade_union = ''
		ELSEIF IsValid(This.inv_popup_data_list) THEN
			ls_trade_union = string(This.inv_popup_data_list.of_get_popup_item( 'trade_union', 'trade_union') )
			This.SetItem(row, 'trade_union_desc', dw_main.inv_popup_data_list.of_get_popup_item('trade_union','description'))
			This.SetItemStatus(row,"trade_union_desc",Primary!,NotModified!)
		END IF
		
		IF len(TRIM(ls_trade_union)) = 0 OR IsNull(ls_trade_union) THEN 
			
			//No trade union defined
			This.SetItem(row, 'trade_union_desc', "")
			This.SetItemStatus(row,"trade_union_desc",Primary!,NotModified!)
			This.SetItem(row,'occupation',"")
			This.SetItem(row, 'occupation_desc', "")
			This.SetItemStatus(row,"occupation_desc",Primary!,NotModified!)

		ELSE
			
			//Occupation dependent on trade union
			This.POST SetItem(row,'occupation',ls_null)
			This.POST SetItem(row, 'occupation_desc', ls_null)
					
			//Trade union specified, use it to set defaults
			ll_tu_rows = ibo_trade_union.of_retrieve("book = '" + gnv_app.is_book + "' and trade_union = '"  + ls_trade_union + "'")
	
			ll_tur_rows = ibo_trade_union_rate.of_Retrieve("book = '" + gnv_app.is_book + &
																					"' and trade_union = '" + ls_trade_union + &
																					"' and CONVERT(VARCHAR, effective_date, 112) <= '" + string(Today(), 'YYYYMMDD') +  "'" + &
																					"  and CONVERT(VARCHAR, expiry_date, 112) >= '" + string(Today(), 'YYYYMMDD') + "'" )
	
			IF ibo_datapanel_business.of_GetItemDecimal(row, "employee_pension_percent") <> 0 THEN
				
				// set employee_pension_percent to 0 if the new union isn't setup for an employer pension
				IF ll_tur_rows > 0 THEN
					IF ibo_trade_union_rate.of_GetItemString(ll_tur_rows, 'pension_plan_no') > '' THEN
					
						//Everything okay - pension goes to 
						
					ELSE
						ibo_datapanel_business.of_SetItem(row, "employee_pension_percent", 0)
						dw_main.POST EVENT ue_setmessage("Union " + ls_trade_union + " is not setup for pensions: Employee pension % is set to 0.", "Blue")
					END IF
				END IF
			END IF	
			
			IF ibo_datapanel_business.of_GetItemDecimal(row, "employee_rrsp_percent") <> 0 &
			OR	ibo_datapanel_business.of_GetItemDecimal(row, "employee_rrsp_per_ck") <> 0 THEN
				// set employee_rrsp_percent to 0 if data is 'N'
				IF ll_tur_rows > 0 THEN
					IF ibo_trade_union_rate.of_GetItemString(ll_tur_rows, 'employee_pension_or_rrsp') = 'R' &
					OR ibo_trade_union_rate.of_GetItemString(ll_tur_rows, 'employer_pension_or_rrsp') = 'B' &
					OR ibo_trade_union_rate.of_GetItemString(ll_tur_rows, 'employer_pension_or_rrsp') = 'R' THEN
					
						//Everything okay - RRSP goes to union plan (pr_cheque.incentive_paid_to_rrsp)
						
					ELSE
						ibo_datapanel_business.of_SetItem(row, "employee_rrsp_percent", 0)
						ibo_datapanel_business.of_SetItem(row, "employee_rrsp_per_ck",  0)
						dw_main.POST EVENT ue_setmessage("Union " + ls_trade_union + " is not setup for RRSPs: Employee RRSP % and amount are set to 0.", "Blue")
					END IF
				END IF
			END IF	
			
			// jira 2579 - set vacation rate to match trade union's - 2013.01.12
			IF ll_tur_rows > 0 THEN
				IF ibo_trade_union_rate.of_GetItemString(ll_tur_rows, 'union_vacation_pay_flag') = 'Y' THEN
//					ibo_datapanel_business.of_SetItem(row, "vacation_percent", ibo_trade_union_rate.of_GetItemDecimal(ll_tur_rows, 'vacation_percent'))
//					ibo_datapanel_business.of_SetItem(row, "statutory_percent", ibo_trade_union_rate.of_GetItemDecimal(ll_tur_rows, 'statutory_percent'))
//					ls_msg = "Vacation % set to " + String(ibo_trade_union_rate.of_GetItemDecimal(ll_tur_rows, 'vacation_percent'), '0.##')
//					ls_msg += ".~n~nStatutory % set to " + String(ibo_trade_union_rate.of_GetItemDecimal(ll_tur_rows, 'statutory_percent'), '0.##') + "."
					ls_msg = "Employee vacation and statutory percent will be controlled by union " + ls_trade_union
					dw_main.POST EVENT ue_setmessage(ls_msg, "Blue")
					MessageBox("Union Vacation Pay", ls_msg)
				ELSEIF is_current_union_vacation_pay_flag = 'Y' THEN
					ls_msg = "Please check employee vacation and statutory percent (no longer tied to union)."
					dw_main.POST EVENT ue_setmessage(ls_msg, "Blue")
					MessageBox("Union Vacation Pay", ls_msg)
				END IF
				
				IF ibo_trade_union.of_getitemstring(ll_tu_rows,"staff_flag") = 'N' THEN
					ibo_datapanel_business.of_SetItem(row, "job_based_wcb_class", "Y")
				ELSE
					ibo_datapanel_business.of_SetItem(row, "job_based_wcb_class", "N")
				END IF
				
			END IF
			
			
			// trade_union.staff_flag = 'N', set employer rrsp % to 0
			IF ibo_datapanel_business.of_GetItemDecimal(row, "employer_rrsp_percent") <> 0 THEN
				IF ll_tu_rows > 0  THEN
					IF ibo_trade_union.of_getitemstring(ll_tu_rows,"staff_flag") = 'N' THEN
						ibo_datapanel_business.of_SetItem(row, "employer_rrsp_percent", 0)
						dw_main.POST EVENT ue_setmessage("Union " + ls_trade_union + " is non-staff: Employer RRSP % earn is set to 0.", "Blue")
					END IF
				END IF
			END IF
		END IF
				
	CASE 'occupation'
		IF len(TRIM(data)) = 0 OR IsNull(data) THEN 
			ls_occupation = ''
			This.SetItem(row, 'occupation_desc',"")
			This.SetItemStatus(row,"occupation_desc",Primary!,NotModified!)
		ELSE
			
			IF IsValid(This.inv_popup_data_list) THEN
				
				ls_occupation = string(This.inv_popup_data_list.of_get_popup_item( 'occupation', 'occupation') )
				// set occupation
				This.SetItem(row, 'occupation_desc', dw_main.inv_popup_data_list.of_get_popup_item('occupation','description'))
				This.SetItemStatus(row,"occupation_desc",Primary!,NotModified!)
		   END IF
		END IF
					
	CASE 'tax_province'
		IF len(TRIM(data)) = 0  OR IsNull(data) THEN 
			ls_province = ''
		ELSE
			IF IsValid(This.inv_popup_data_list) THEN
				ls_province = string(This.inv_popup_data_list.of_get_popup_item( 'tax_province', 'province') )
		   END IF
		END IF
		
		IF len(ls_province) > 0 THEN
			
			// get the current payroll G/L period
			// -- it may be December, but if you've already rolled payroll into January,
			//    then all the TD1's have been set to the minimum for the new year
			//    and if you use last year's it will have to be manually fixed,
			//    so use the next year's minimum TD1 claims
			IF ibo_company.of_Retrieve("book = '" + gnv_app.is_book + "'") = 1 THEN
				ls_pr_yyyymm = ibo_company.of_GetItemString(1, 'pr_yyyymm')
				ldt_pr_yyyymm = DateTime(Date(Integer(Left(ls_pr_yyyymm, 4)), Integer(Right(ls_pr_yyyymm, 2)), 1), Time(0,0,0))
			ELSE
				ldt_pr_yyyymm = Datetime(Today(),Now())
			END IF

			ll_rc = ibo_province_rate.of_get_provincial_td1_claim(ls_province, &
																		 ldt_pr_yyyymm, &
																		 ldt_pr_yyyymm, &
																		 'C', &
																		 ldec_provincial_td1_claim)
			IF ll_rc = 1 THEN
				// success,
				ibo_datapanel_business.of_SetItem(row,"provincial_td1_claim", ldec_provincial_td1_claim)
			END IF
			
			// get the current payroll G/L period
			// -- it may be December, but if you've already rolled payroll into January,
			//    then all the TD1's have been set to the minimum for the new year
			//    and if you use last year's it will have to be manually fixed,
			//    so use the next year's minimum TD1 claims
			IF ibo_company.of_Retrieve("book = '" + gnv_app.is_book + "'") = 1 THEN
				ls_pr_yyyymm = ibo_company.of_GetItemString(1, 'pr_yyyymm')
				ldt_pr_yyyymm = DateTime(Date(Integer(Left(ls_pr_yyyymm, 4)), Integer(Right(ls_pr_yyyymm, 2)), 1), Time(0,0,0))
			ELSE
				ldt_pr_yyyymm = Datetime(Today(),Now())
			END IF

			// set federal td1 claim
			IF NOT IsValid(ibo_federal_tax) THEN
				ibo_federal_tax = CREATE n_bo_federal_tax
				ibo_federal_tax.of_SetTransaction()
			END IF						
			ll_rc = ibo_federal_tax.of_get_federal_td1_claim(ldt_pr_yyyymm, &
																			 ldt_pr_yyyymm, &
																			 'C', &
																			 ldec_federal_td1_claim)
			IF ll_rc = 1 THEN
			  // success,
			  ibo_datapanel_business.of_SetItem(row,"federal_td1_claim",ldec_federal_td1_claim)
			ELSE						  
				// display error to user; error handling is done in business object too
				of_msg_db_error("Error reading federal_tax.federal_td1_claim")
				RETURN -1
			END IF
	
			//check entries are present for tax province
			IF NOT IsValid(lbo_province_income_tax) THEN
				lbo_province_income_tax = CREATE n_bo_province_income_tax
				lbo_province_income_tax.of_SetTransaction()
			END IF						
			ll_rc = lbo_province_income_tax.of_get_entry_count(ls_province, Datetime(Today(),Now()), ll_count)
			IF ll_rc < 1 OR ll_count < 1 THEN
				dw_main.POST EVENT ue_setmessage("Tax province " + ls_province + " isn't set up for tax calculations.","Red")
				RETURN 1	
			END IF
		END IF		
					
	CASE 'job'
				
		// set area and centre to NULL			
		ibo_datapanel_business.of_SetItem(row,"area",	ls_null)
		ibo_datapanel_business.of_SetItem(row,"centre",	ls_null)
		ibo_datapanel_business.of_SetItem(row,"crew",	ls_null)
		dw_main.SetItem(row,"area_desc",		ls_null)
		dw_main.SetItem(row,"centre_desc",	ls_null)
		
		IF len(TRIM(data)) = 0 OR IsNull(data) THEN 
			
			dw_main.SetItem(row,"job_desc",ls_null)
			This.SetItemStatus(row,"job_desc",Primary!,NotModified!)
			
		ELSEIF This.inv_popup_data_list.of_is_valid_value('job', data) THEN
				
			ls_job = data
			
			// set job description
			//ibo_datapanel_business.POST of_SetItem(row,"job",ls_job)
			//ibo_job.of_get_job_description(is_book,Trim(data),ls_job_desc)
			//dw_main.SetItem(row,"job_desc",ls_job_desc)
			IF ibo_job.of_Retrieve("book = '" + is_book + "' AND job = '" + Trim(data) + "'") > 0 THEN
				IF ibo_job.of_GetItemString(1, "concurrent_crew_memberships_flag") = 'Y' THEN
					dw_main.SetItem(row,"job_desc",ibo_job.of_GetItemString(1, "description") + " (MULTI-CREW)")
				ELSE
					dw_main.SetItem(row,"job_desc",ibo_job.of_GetItemString(1, "description"))
				END IF
			END IF
			This.SetItemStatus(row,"job_desc",Primary!,NotModified!)
			
			// jira 3461 - When they try to change a job for an employee who is active in a crew tied to that job, 
			// we should warn them that the employee will be expired from that crew. 
			IF dw_main.GetItemNumber(1, 'crew_count') < 2 THEN
				ls_old_job = this.GetItemString(row, 'job', Primary!, TRUE)
				IF Not(IsNull(ls_old_job)) THEN
					li_rc = ibo_datapanel_business.of_GetChild("crew_member", ibo_crew_member)
					IF Not IsValid(ibo_crew_member) THEN
						parent.of_msg_db_error("Error reading crew members")
						RETURN -1
					END IF
					li_rc = ibo_datapanel_business.of_GetChild("crew", ibo_crew)
					IF Not IsValid(ibo_crew) THEN
						parent.of_msg_db_error("Error reading crew")
						RETURN -1
					END IF
					ls_msg = ''
					ll_cm_rows = ibo_crew_member.of_Retrieve("job_or_region = '" + ls_old_job &
																			+ "' AND effective_date <= '" + String(Today(), 'yyyy.mm.dd')	&
																			+ "' AND expiry_date >= '" + String(Today(), 'yyyy.mm.dd')		&
																			+ "' AND employee = " + String(il_employee))
					FOR ll_cm_row = 1 TO ll_cm_rows
						
						//Check crew active flag
						ll_c_rows = ibo_crew.of_Retrieve("job_or_region = '" + ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region') + "' AND crew = '" + ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') + "'")
						IF ll_c_rows < 0 THEN 
							parent.of_msg_db_error("Error retrieving crew")
							RETURN -1
						END IF
						IF ibo_crew_member.of_GetItemString(ll_cm_row, 'supervisor_flag') = 'Y' THEN
							
							//Can't leave crew without a supervisor
							dw_main.POST EVENT ue_setmessage("Can't change job assignment for supervisor of crew " + ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region') + "/" + ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') , "red")
							RETURN 1	//=Reject value and do not allow focus to change
							
						ELSEIF ibo_crew.of_GetItemString(1, 'active_flag') = 'Y' THEN

							//crew is active, warn the crew member will be expired
							IF ls_msg = '' THEN ls_msg = f_get_person_name(il_employee) + " is active on crew~n~n"
							ls_msg += " " + ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region') &
										+ "/" + ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') &
										+ '-' + f_get_crew_code_desc(ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region'), ibo_crew_member.of_GetItemString(ll_cm_row, 'crew')) + '~n'

						END IF
					NEXT
					
					IF ibo_job.of_GetItemString(1, "concurrent_crew_memberships_flag") = 'N' AND ls_msg <> '' THEN
						IF MessageBox("Job Crews", ls_msg &
									+ "~nOkay to expire from crew?", Question!, YesNo!, 2) = 2 THEN
							dw_main.POST EVENT ue_setmessage("Active on crew " + ibo_crew_member.of_GetItemString(ll_cm_row, 'job_or_region') + "/" + ibo_crew_member.of_GetItemString(ll_cm_row, 'crew') , "red")
							RETURN 1	//=Reject value and do not allow focus to change
						END IF						
					END IF
				END IF
			END IF
		END IF 
				
	CASE "area"
		
		IF len(TRIM(data)) = 0 OR IsNull(data) THEN 
			This.SetItem(row,"centre",ls_null)
			This.SetItem(row,"area",ls_null)
			dw_main.SetItem(row,"centre_desc","")
			dw_main.SetItem(row,"area_desc","")
			dw_main.SetItemStatus(row,"area_desc",Primary!,NotModified!)
		ELSE
				
			IF IsValid(This.inv_popup_data_list) THEN
				ls_area_data = string(This.inv_popup_data_list.of_get_popup_item( 'area', 'area') )
			END IF	
			
			// set area description
			ls_area = TRIM(data)
			ls_job = ibo_datapanel_business.of_GetItem(row,"job")
			
			IF IsValid(This.inv_popup_data_list) THEN
				ls_area = string(This.inv_popup_data_list.of_get_popup_item( 'area', 'area') )
			END IF	

			IF TRIM(ls_area) = "" THEN SetNull(ls_area)
			//ibo_datapanel_business.POST of_SetItem(row,"area",ls_area)
			ibo_area.of_get_area_description(is_book,ls_job,Trim(data),ls_area_desc)
			dw_main.SetItem(row,"area_desc",ls_area_desc)
			This.SetItemStatus(row,"area_desc",Primary!,NotModified!)
			dw_main.SetItem(row,"centre_desc","")
		END IF
		
		
	CASE "centre"
		IF len(TRIM(data)) = 0 OR IsNull(data) THEN 
			dw_main.SetItem(row,"centre_desc","")
			dw_main.SetItemStatus(row,"centre_desc",Primary!,NotModified!)
		ELSE
			// set centre description
			ls_job = ibo_datapanel_business.of_GetItem(row,"job")
			ls_area = ibo_datapanel_business.of_GetItem(row,"area")
			SetNull(ls_centre)
			IF IsValid(This.inv_popup_data_list) THEN
				ls_centre = string(This.inv_popup_data_list.of_get_popup_item( 'centre', 'centre') )
			END IF	

			
			//ibo_datapanel_business.POST of_SetItem(row,"centre",ls_centre)
			ibo_centre.of_get_centre_description(is_book, ls_job, ls_area, ls_centre,ls_centre_desc)
			dw_main.SetItem(row,"centre_desc",ls_centre_desc)
			This.SetItemStatus(row,"centre_desc",Primary!,NotModified!)
		END IF
		
	CASE 'termination_date'		
		dw_main.EVENT ue_setmessage("","Blue")
		IF IsNull(data) THEN
			IF ls_action = 'T' THEN
				dw_main.POST EVENT ue_setmessage("Termination Date is required","Red")
				RETURN 1	
			END IF
		END IF
		ll_employee = ibo_datapanel_business.of_GetItemNumber(row,"employee")
		idt_current_termination_date = ibo_datapanel_business.of_GetItemDateTime(row,"termination_date")
		ldt_term_date = DateTime(data)
		
		//Jira 2064
		ll_timesheet_row = ibo_timesheet.of_retrieve("book = '" + is_book + "' AND employee = " + String(ll_employee) + " AND work_date >= '" + String(ldt_term_date, 'yyyy.mm.dd') + "'")
		IF ll_timesheet_row > 0 THEN
			dw_main.POST SetColumn("termination_date")
			dw_main.POST SetFocus()
			dw_main. POST EVENT ue_setmessage("There are timesheets after the termination date","Blue")
		END IF
			
	CASE 'roe_reason_code'
		ls_roe = TRIM(data)	

			
		IF IsValid(This.inv_popup_data_list) THEN
			ls_roe = string(This.inv_popup_data_list.of_get_popup_item( 'roe_reason_code', 'reason') )
		END IF
		IF Not (IsNull(ls_roe) OR ls_roe = '') THEN
			//ibo_datapanel_business.POST of_SetItem(row,"roe_reason_code",ls_roe)
			ibo_roe_reason.of_get_roe_description(ls_roe,ls_roe_desc)
			dw_main.SetItem(row,"roe_desc",ls_roe_desc)
			This.SetItemStatus(row,"roe_desc",Primary!,NotModified!)
		ELSE
			dw_main.SetItem(row,"roe_desc",ls_null)
			This.SetItemStatus(row,"roe_desc",Primary!,NotModified!)
			
			IF ls_action = 'T' THEN
				dw_main.EVENT ue_setmessage("ROE Reason Code is required","Red")
				RETURN 1	
			END IF
		END IF	
			
	CASE 'gl_account'

		ls_gl_account = Trim(data)
			
		IF IsValid(This.inv_popup_data_list) THEN
			ls_gl_account  = string(This.inv_popup_data_list.of_get_popup_item( 'gl_account', 'gl_account') )
		END IF
		IF NOT IsNull(ls_gl_account) THEN
			//ibo_datapanel_business.POST of_SetItem(row,"gl_account",ls_gl_account)
			ibo_gl_account.of_get_gl_account_description(is_book,ls_gl_account,"",'C','Y',ls_gl_account_desc)
			dw_main.SetItem(row,"gl_desc",ls_gl_account_desc)
			This.SetItemStatus(row,"gl_desc",Primary!,NotModified!)
		ELSE
			dw_main.SetItem(row,"gl_desc",ls_null)
			This.SetItemStatus(row,"gl_desc",Primary!,NotModified!)
		END IF	
END CHOOSE

AcceptText()
	
	
CHOOSE CASE ls_curr_column
	CASE 'wcb_class'
		IF TRIM(data) = '' OR IsNull(data) THEN
			ibo_datapanel_business.of_SetItem(row,"job_based_wcb_class","Y") 
		ELSE
			ibo_datapanel_business.of_SetItem(row,"job_based_wcb_class","N") 
		END IF
		
	CASE 'job_based_wcb_class'
		IF TRIM(data) = 'Y' THEN
			ibo_datapanel_business.of_SetItem(row,"wcb_class",ls_null) 
		END IF	
		
		
	CASE 'employment_type'
		// set-up federal td1 claim
		IF ls_action  = 'A' or ls_action = 'C' or ls_action = 'Z' or ls_action = 'Y' THEN
			IF TRIM(data) = 'Y' THEN
				
				// get the current payroll G/L period
				// -- it may be December, but if you've already rolled payroll into January,
				//    then all the TD1's have been set to the minimum for the new year
				//    and if you use last year's it will have to be manually fixed,
				//    so use the next year's minimum TD1 claims
				IF ibo_company.of_Retrieve("book = '" + gnv_app.is_book + "'") = 1 THEN
					ls_pr_yyyymm = ibo_company.of_GetItemString(1, 'pr_yyyymm')
					ldt_pr_yyyymm = DateTime(Date(Integer(Left(ls_pr_yyyymm, 4)), Integer(Right(ls_pr_yyyymm, 2)), 1), Time(0,0,0))
				ELSE
					ldt_pr_yyyymm = Datetime(Today(),Now())
				END IF
	
				// set federal td1 claim
				IF NOT IsValid(ibo_federal_tax) THEN
					ibo_federal_tax = CREATE n_bo_federal_tax
					ibo_federal_tax.of_SetTransaction()
				END IF						
				ll_rc = ibo_federal_tax.of_get_federal_td1_claim(ldt_pr_yyyymm, &
																				 ldt_pr_yyyymm, &
																				 'C', &
																				 ldec_federal_td1_claim)
				IF ll_rc = 1 THEN
				  // success,
				  ibo_datapanel_business.of_SetItem(row,"federal_td1_claim",ldec_federal_td1_claim)
				ELSE						  
					// display error to user; error handling is done in business object too
					of_msg_db_error("Error reading federal_tax.federal_td1_claim")
					RETURN -1
				END IF
				
				// set provincial td1 claim
				// get province
				ls_province =  ibo_datapanel_business.of_GetItemString(row,"tax_province")
				IF Trim(ls_province) <> '' THEN
					ll_rc = ibo_province_rate.of_get_provincial_td1_claim(ls_province, &
																				 ldt_pr_yyyymm, &
																				 ldt_pr_yyyymm, &
																				 'C', &
																				 ldec_provincial_td1_claim)
					IF ll_rc = 1 THEN
					  // success,
					  ibo_datapanel_business.of_SetItem(row,"provincial_td1_claim",ldec_provincial_td1_claim)
					ELSE						  
						// display error to user; error handling is done in business object too
						of_msg_db_error("Error reading province_rate.provincial_td1_claim")
						RETURN -1
					END IF
				ELSE
				END IF
				
				// set vacation_percent
				ibo_datapanel_business.of_SetItem(row,"vacation_percent",4)
				
			END IF	
		END IF
		
		// set tax_province, wcb_class
		IF Trim(data) = 'N' THEN
			ibo_datapanel_business.of_SetItem(row,"tax_province",ls_null)
			ibo_datapanel_business.of_SetItem(row,"wcb_class",ls_null)
			ibo_datapanel_business.of_SetItem(row,"federal_td1_claim",0)
			ibo_datapanel_business.of_SetItem(row,"provincial_td1_claim",0)
			ibo_datapanel_business.of_SetItem(row,"ei_exempt_flag","Y")
			ibo_datapanel_business.of_SetItem(row,"cpp_exempt_flag","Y")
			ibo_datapanel_business.of_SetItem(row,"add_income_tax_per_ck",0)
			ibo_datapanel_business.of_SetItem(row,"taxable_benefit_per_ck",0)
			ibo_datapanel_business.of_SetItem(row,"vacation_percent",0)
			ibo_datapanel_business.of_SetItem(row,"statutory_percent",0)
		
			ibo_datapanel_business.of_SetItem(row,"training_percent",0)
			ibo_datapanel_business.of_SetItem(row,"staff_safety_percent",0)
			ibo_datapanel_business.of_SetItem(row,"smtc_percent",0)
			
			ibo_datapanel_business.of_SetItem(row,"employer_rrsp_percent",0)
			ibo_datapanel_business.of_SetItem(row,"employee_rrsp_percent",0)
			ibo_datapanel_business.of_SetItem(row,"incentive_percent",0)
			
			ibo_datapanel_business.of_SetItem(row,"loa_taxable_flag",'N')
			ibo_datapanel_business.of_SetItem(row,"mileage_taxable_flag",'N')
			ibo_datapanel_business.of_SetItem(row,"site_allow_taxable_flag",'N')
			
		ELSEIF Trim(data) = 'S' OR Trim(data) = 'U' THEN
			
			ibo_datapanel_business.of_SetItem(row,"eft_institution",ls_null)
			ibo_datapanel_business.of_SetItem(row,"eft_branch",ls_null)
			ibo_datapanel_business.of_SetItem(row,"eft_account",ls_null)
			ibo_datapanel_business.of_SetItem(row,"tax_province",ls_null)
			ibo_datapanel_business.of_SetItem(row,"federal_td1_claim",0)
			ibo_datapanel_business.of_SetItem(row,"provincial_td1_claim",0)				
			ibo_datapanel_business.of_SetItem(row,"ei_exempt_flag","Y")
			ibo_datapanel_business.of_SetItem(row,"cpp_exempt_flag","Y")
			ibo_datapanel_business.of_SetItem(row,"add_income_tax_per_ck",0)
			ibo_datapanel_business.of_SetItem(row,"vacation_percent",0)
			ibo_datapanel_business.of_SetItem(row,"statutory_percent",0)
			ibo_datapanel_business.of_SetItem(row,"employer_rrsp_percent",0)
			ibo_datapanel_business.of_SetItem(row,"employee_rrsp_percent",0)
			ibo_datapanel_business.of_SetItem(row,"job_based_wcb_class",'Y')
			ibo_datapanel_business.of_SetItem(row,"safety_to_rrsp_flag",'N')
			ibo_datapanel_business.of_SetItem(row,"other_incentive_to_rrsp_flag",'N')
			ibo_datapanel_business.of_SetItem(row,"employee_rrsp_per_ck",0)
			ibo_datapanel_business.of_SetItem(row,"employee_rrsp_percent",0)
		END IF
	
	CASE 'shift_pattern_type'
		IF len(TRIM(data)) = 0 OR IsNull(data) THEN 
			SetNull(ldt_null)
			ibo_datapanel_business.of_SetItem(row,"shift_start_date",ldt_null)
		ELSE
			IF ibo_shift_pattern.of_get_no_days(TRIM(data),li_days) > 0 THEN
				// set turnaround due date and cycle days
				ldt_turnaround = ibo_datapanel_business.of_GetItemDateTime(row,"next_turnaround_due_date")
				ldt_shift_start_date = ibo_datapanel_business.of_GetItemDateTime(row,"shift_start_date")
				IF NOT IsNull(ldt_turnaround) THEN
					// add li_days to ldt_shift_start_date and set at turnaround_due_date
					IF NOT IsNull(ldt_shift_start_date) THEN
						ldt_new_turnaround = DateTime(RelativeDate(Date(ldt_shift_start_date), li_days),Now())
						ibo_datapanel_business.of_Setitem(row,"next_turnaround_due_date", ldt_new_turnaround)
						lb_turnaround = TRUE
					END IF	
				END IF
				
				li_turnaround_cycle_days = ibo_datapanel_business.of_GetItemNumber(row,"turnaround_cycle_days")
				IF li_turnaround_cycle_days > 0 THEN
					li_new_cycle_days = li_days
					ibo_datapanel_business.of_Setitem(row,"turnaround_cycle_days",  li_new_cycle_days )	
					lb_cycle = TRUE
				END IF	
	
				// set warning message
				IF lb_cycle AND lb_turnaround THEN
					is_message = "Turnaround due is " + string(ldt_new_turnaround,"yyyy.mm.dd") + " and cycle days are " + string( li_new_cycle_days)
					dw_main.POST EVENT ue_setmessage(is_message, "Blue")
				ELSE
					IF lb_cycle THEN 
						is_message = "Cycle days are " + string( li_new_cycle_days)
						dw_main.POST EVENT ue_setmessage(is_message, "Blue")
					END IF
					
					IF lb_turnaround THEN 
						is_message = "Turnaround due is " + string(ldt_new_turnaround,"yyyy.mm.dd")
						dw_main.POST EVENT ue_setmessage(is_message, "Blue")
					END IF	
				END IF
			END IF
		END IF	
	
	CASE 'shift_start_date'	
		// check start_date validation
		ls_shift_pattern = ibo_datapanel_business.of_GetItemString(row,"shift_pattern_type")
		ldt_hire_date = ibo_datapanel_business.of_GetItemDateTime(row,"hire_date")
		ldt_shift_start_date = DateTime(data)

		ldt_shift_start = ibo_shift_pattern.of_get_shift_start(ls_shift_pattern, ldt_hire_date)
		IF NOT IsNull(ldt_shift_start) THEN
			IF DATE(ldt_shift_start_date) < DATE(ldt_shift_start) OR DATE(ldt_shift_start_date) > TODAY() THEN
				dw_main.EVENT ue_setmessage("Shift Start Date must be between " + String(ldt_shift_start, 'yyyy.mm.dd')  + " and " + string(TODAY(), 'yyyy.mm.dd'),"Red")
				RETURN 1	
			END IF	
			
			// set turnaround due and cycle days
			IF ibo_shift_pattern.of_get_no_days(ls_shift_pattern, li_days) > 0 THEN
				// set turnaround due date and cycle days
				ldt_turnaround = ibo_datapanel_business.of_GetItemDateTime(row,"next_turnaround_due_date")
				IF NOT IsNull(ldt_turnaround) THEN
					// add li_days to ldt_shift_start_date and set at turnaround_due_date
					ldt_new_turnaround = DateTime(RelativeDate(Date(ldt_shift_start_date), li_days),Now())
					ibo_datapanel_business.of_Setitem(row,"next_turnaround_due_date", ldt_new_turnaround)
					lb_turnaround = TRUE
				END IF
				

				// set warning message
				IF lb_cycle AND lb_turnaround THEN
					is_message = "Turnaround due is " + string(ldt_new_turnaround,"yyyy.mm.dd") + " and cycle days are " + string( li_new_cycle_days)
					dw_main.POST EVENT ue_setmessage(is_message, "Blue")
				ELSE
					IF lb_cycle THEN 
						is_message = "Cycle days are " + string( li_new_cycle_days)
						dw_main.POST EVENT ue_setmessage(is_message, "Blue")
					END IF
					
					IF lb_turnaround THEN 
						is_message = "Turnaround due is " + string(ldt_new_turnaround,"yyyy.mm.dd")
						dw_main.POST EVENT ue_setmessage(is_message, "Blue")
					END IF	
				END IF
			END IF
		END IF	
					
	CASE "birth_date"
	
		IF ls_action = 'A' OR ls_action = 'C' OR ls_action = 'Z' OR ls_action = 'Y'  THEN
			ls_field = TRIM(data)
			IF ls_field = "" OR IsNull(ls_field) THEN
				dw_main.EVENT ue_setmessage("Birth Date is Required","Red")
				RETURN 1
			ELSE
				IF YEAR(TODAY()) - YEAR(Date(ls_field)) < 10 THEN
					dw_main.EVENT ue_setmessage("Employee Must Be At Least 10 Years Old","Red")
					RETURN 1
				END IF	
				
				IF YEAR(TODAY()) - YEAR(Date(ls_field)) > 85 THEN
					dw_main.EVENT ue_setmessage("Employee Must Be At Most 85 Years Old","Red")
					RETURN 1
				END IF
				
			END IF	
		END IF	
		
	CASE "hire_date"
		ibo_datapanel_business.of_SetItemStatus(row, 'hire_date', Primary!,DataModified!)
		IF ls_action = 'Y' THEN
			//ls_current_book = This.GetItemString(row,"latest_book_active")
			ls_current_book = gnv_app.of_person_current_books(il_employee, DATETIME(TODAY(),NOW()))
			//ls_current_book_terminated = This.GetItemString(row,"latest_book_terminated")
			SELECT TOP 1  a.book
			  INTO :ls_current_book_terminated
				FROM employee a, book b
				WHERE a.employee =:il_employee AND
						a.book = b.book AND
						b.active_flag = 'Y' AND
						a.termination_date IS NOT NULL
				ORDER BY a.termination_date DESC
				USING sqlca;
				
				
			// set warning message if current_book or latest_book_terminated is not the same as gnv_app.is_book
			IF NOT IsNull(ls_current_book) THEN
				IF is_book <> ls_current_book THEN 
					is_message = "Employee currently employed in " + ls_current_book
					dw_main.POST EVENT ue_setmessage(is_message ,"Blue")
				END IF	
			ELSE
				// use latest_book since employee is now terminated
				IF is_book <> ls_current_book_terminated THEN 
					is_message = "Employee last worked in " + ls_current_book_terminated
					dw_main.POST EVENT ue_setmessage(is_message,"Blue")					
				END IF	
			END IF	
		
			//Jira 2005 - update TD1 claims on reemploy action	
			IF ibo_datapanel_business.of_GetItemString(1, 'employment_type') = 'Y' THEN
				of_update_td1_claim_amounts(this.GetItemString(1, 'tax_province'))
			END IF
			
		END IF
		
	CASE	"gst"
		IF ls_action = 'A' OR ls_action = 'C' OR ls_action = 'Z'  OR ls_action = 'Y' THEN
			ls_employment_type = ibo_datapanel_business.of_GetItemString(row,"employment_type")
			ls_field = TRIM(data)
			IF ls_employment_type = 'S' THEN
				//check for null GST
				IF ls_field = "" OR IsNull(ls_field) THEN
					dw_main.EVENT ue_setmessage("GST is Required","Red")
					RETURN 1
				ELSE
					IF LEN(ls_field) <> 9 THEN
						dw_main.EVENT ue_setmessage("GST should be 9 Digits","Red")
						RETURN 1
					ELSE
						// check if numeric and non-zero
						IF NOT IsNumber(ls_field) THEN
							dw_main.EVENT ue_setmessage("GST should be Numeric","Red")
							RETURN 1
						ELSE
							IF ls_field = '000000000' THEN
								dw_main.EVENT ue_setmessage("GST cannot be all Zeroes","Red")
								RETURN 1
							END IF	
						END IF
					END IF
				END IF
			END IF
		END IF	 
	
		
	CASE "sin"
		IF ls_action = 'A' OR ls_action = 'C' OR ls_action = 'Z' OR ls_action = 'Y' THEN
			ls_employment_type = ibo_datapanel_business.of_GetItemString(row,"employment_type")
			ls_field = TRIM(data)
			IF ls_employment_type = 'Y' THEN
				// check for null SIN
				IF ls_field = "" OR IsNull(ls_field) THEN
					dw_main.Modify("t_messagebox.Height.AutoSize=Yes")
					dw_main.EVENT ue_setmessage("SIN is Required","Red")
					RETURN 1
				ELSE
					// check for valid SIN
					ls_sina="0246813579135792468024680357913579146802468025791357913680246802479135791358024680246913579135702468"
					ls_sinb="0987654321098765432109876543210987654"
					
					li_n1 = Integer(Mid(ls_sina, Integer(Mid(ls_field, 1, 2)) + 1, 1)) &
							+ Integer(Mid(ls_sina, Integer(Mid(ls_field, 3, 2)) + 1, 1)) &
							+ Integer(Mid(ls_sina, Integer(Mid(ls_field, 5, 2)) + 1, 1)) &
							+ Integer(Mid(ls_sina, Integer(Mid(ls_field, 7, 2)) + 1, 1))
					ls_chk = Mid(ls_sinb, li_n1 + 1, 1)
					IF Mid(ls_field, 9, 1) <> ls_chk THEN
						dw_main.EVENT ue_setmessage("Social Insurance Number check digit should be " + ls_chk,"Red")
						RETURN 1
					END IF
				END IF	
			END IF	
		END IF 

	CASE 'supervisor'
		IF data = '0' OR IsNull(data) THEN
			This.SetItem(1, 'supervisor', ll_null)
		END IF
		
END CHOOSE			

dw_main.of_SetRedraw(FALSE, TRUE /* with override */)

CALL SUPER::itemchanged;

dw_main.of_SetRedraw(TRUE, TRUE /* release override */)


RETURN AncestorReturnValue

end event

event dw_main::itemfocuschanged;call super::itemfocuschanged;//************************************************************
// Object   :	u_cst_employee_detail 
// Event    :	itemfocuschanged
// Author   :	Lourdes Garcia
// Date     :	2009/04/23
// 	
// Arguments:	long row
// 				dwobject dwo
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

DateTime			ld_birthdate 

IF ii_row > 0 THEN
	IF GetItemString(1,'action') <> 'I' THEN
		CHOOSE CASE is_colname 
			CASE "ei_exempt_flag"
				IF ibo_datapanel_business.of_GetItemString(row,"ei_exempt_flag") = 'Y' THEN 
					EVENT ue_setmessage("Confirm employee is EI exempt","Blue")
				END IF	
			 CASE "income_tax_exempt_flag"	
				IF ibo_datapanel_business.of_GetItemString(row,"income_tax_exempt_flag") = 'Y' THEN
					EVENT ue_setmessage("Confirm employee is Tax exempt","Blue")
				END IF		 
			CASE "birth_date"
				ld_birthdate = dw_main.GetitemDateTime(row,"birth_date")
				IF DaysAfter(Date(ld_birthdate), Today()) <= 6570 THEN
					EVENT ue_setmessage("Under 18 so will be CPP exempt.","Blue")
				END IF
				
				IF DaysAfter(Date(ld_birthdate), Today()) > 25550 THEN
					EVENT ue_setmessage("Over 70 so will be CPP exempt.","Blue")
				END IF 
				
		END CHOOSE	
	END IF		

END IF

// store old values, to know when to trigger above
ii_row = row
is_colname = dwo.Name


RETURN AncestorReturnValue






end event

event dw_main::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_preprint
// Author   :	Lourdes Garcia
// Date     :	2009/05/11
// 	
// Arguments:	s_preview astr_preview
// 	
// Returns:		integer
// 	
// Desc:			Set Sub title...
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String 	ls_select, ls_where, ls_tax_year, ls_syntax
Integer	li_rc
Long		ll_rows
DataStore	lds_print, lds_export1, lds_export2, lds_export3
DataWindow	ldw_print

astr_preview.dw_preview  = ldw_print
astr_preview.s_sub_title = string(il_employee) + '-' + is_name 
astr_preview.b_retrieve = TRUE

lds_print = CREATE DataStore

lds_print.DataObject = 'd_pr_employee_prn'
lds_print.SetTransObject(SQLCA)

ls_select = lds_print.Describe("Datawindow.Table.Select")

ls_select = gnv_app.inv_string.of_GlobalReplace(ls_select, '}', "   AND earning.tax_year = '" + String(Today(), 'yyyy') + "'}")
ls_select += " WHERE employee.book = '" + gnv_app.is_book &
			 + "'  AND employee.employee = " + String(this.GetItemNumber(1, 'employee')) 

lds_print.Modify("Datawindow.Table.Select = ~"" + &
	ls_select + "~"")

astr_preview.ds_preview = lds_print
astr_preview.s_report = 'P/R Employee Record'

//premium
lds_export1 = CREATE n_ds		
lds_export1.DataObject = 'd_pr_employee_premium_prn'
lds_export1.SetTrans(sqlca)
lds_export1.Retrieve( gnv_app.is_book, this.GetItemNumber(1, 'employee'))
astr_preview.ds_export[1] = lds_export1
astr_preview.s_tab_label[1] = 'Premiums'

//WCB
lds_export2 = CREATE n_ds		
lds_export2.DataObject = 'd_pr_employee_prn_wcb'
lds_export2.SetTrans(sqlca)
lds_export2.Retrieve( gnv_app.is_book, this.GetItemNumber(1, 'employee'))
astr_preview.ds_export[2] = lds_export2
astr_preview.s_tab_label[2] = 'WCB'

//Details
lds_export3 = CREATE n_ds		
ls_syntax = This.Object.DataWindow.Syntax
lds_export3.Create(ls_syntax)
li_rc = This.RowsCopy(1, 1, Primary!, lds_export3, 1, Primary!)
astr_preview.ds_export[3] = lds_export3
astr_preview.s_tab_label[3] = 'Details'

RETURN 1
end event

event dw_main::ue_history;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_history
// Author   :	Lourdes Garcia
// Date     :	2009/05/12
// 	
// Arguments:	(None)
// 	
// Returns:		integer (override)
// 	
// Desc:			Move to History or restore from History
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String		ls_file_type, &
				ls_employment_type
Long			ll_row
Boolean		lb_return
Int			li_proceed = 1, &
				li_return = -1
n_bo_employee_earning lbo_employee_earning

ll_row = This.GetRow()

// get current file_type and employment_type
ls_file_type = ibo_datapanel_business.of_GetItemString(ll_row,"file_type")
ls_employment_type = ibo_datapanel_business.of_GetItemString(ll_row,"employment_type")
IF ls_file_type = 'C' and ls_employment_type <> 'N' THEN
//	 check for ytd values
	IF NOT IsValid(lbo_employee_earning) THEN
		lbo_employee_earning = CREATE n_bo_employee_earning
		lbo_employee_earning.of_SetTransaction()
	END IF
	lbo_employee_earning.of_check_ytd_amounts_zero(il_employee, is_book, Year(Today()), lb_return)
	IF IsNull(lb_return) THEN lb_return = FALSE
	IF lb_return THEN
		li_proceed = 1
	ELSE
		EVENT POST ue_setmessage("Non-zero year-to-date amounts","Red")
		li_proceed = 0
		li_return = -1
	END IF	
END IF


IF li_proceed = 1 THEN
	li_return = SUPER::EVENT ue_history()
END IF	

IF IsValid(lbo_employee_earning) THEN DESTROY lbo_employee_earning

il_history_flag = li_return
RETURN li_return



end event

event dw_main::bo_overridelogactioncode;call super::bo_overridelogactioncode;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	bo_overridelogactioncode
// Author   :	Lourdes Garcia
// Date     :	2009/05/25
// 	
// Arguments:	string as_action_code
// 	
// Returns:		(None)
// 	
// Desc:			Add reemploY and Terminate actions in event log
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



String		ls_action

IF This.GetRow() > 0 THEN
	ls_action = This.GetItemString(1, 'action')
	
	IF ls_action = 'Y' or ls_action = 'T'  THEN
		as_action_code = ls_action
	END IF
END IF
end event

event dw_main::ue_add;call super::ue_add;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_add
// Author   :	Lourdes Garcia
// Date     :	2009/05/29
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Change title bar
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
s_parm lstr_parm

this.of_enable_column('name_add')
this.of_enable_column('employee')

iw_parent.title = 'P/R Employee: NEW RECORD*'

//HIDE_EARNINGS_TAB
gnv_synchronize.uf_event_trigger('HIDE_EARNINGS_TAB', lstr_parm)

//Reset child business objects so we don't get a 'record has changed' message
ibo_employee_premium.of_reset()
ibo_person.of_reset()
ibo_person_diary.of_reset()
ibo_timesheet.of_reset()
ibo_pr_cheque.of_reset()
ibo_crew.of_reset()
ibo_crew_member.of_reset()

is_original_crew = ''

this.inv_popup_data_list.of_set_popup_filter("job", "active_flag = 'Y'")	

RETURN 1

end event

event dw_main::ue_z;call super::ue_z;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_z
// Author   :	Lourdes Garcia
// Date     :	2009/06/05
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

Long		ll_row, ll_employee
Int		li_errcount, li_error, li_proceed
String	ls_error_message, ls_null
s_validation_error	lstr_error[]
s_parm					lstr_parm


SetNull(ls_null)

// check if there is already an employee_earning record
IF ibo_employee_earning.of_retrieve("employee = " + string(il_employee) + &
											" and book = '"  + gnv_app.is_book + "'" + &
											" and tax_year = " + string(YEAR(TODAY())) ) = 0 THEN
	ll_row = ibo_employee_earning.of_insertrow(0)	
	
	ll_employee = ibo_datapanel_business.of_GetItemNumber(dw_main.GetRow(),"employee")
	
	// set primary keys
	IF ll_row > 0 THEN
		ibo_employee_earning.of_setitem(ll_row,"book",	gnv_app.is_book)
		ibo_employee_earning.of_setitem(ll_row,"employee",	ll_employee)
		ibo_employee_earning.of_setitem(ll_row,"tax_year",	YEAR(TODAY()))
		IF ibo_datapanel_business.of_GetItemString(dw_main.GetRow(),"employment_type") = 'Y' THEN		
			ibo_employee_earning.of_setitem(ll_row,"tax_province", ibo_datapanel_business.of_GetItemString(dw_main.GetRow(),"tax_province")	)
		ELSE
			ibo_employee_earning.of_setitem(ll_row,"tax_province", ls_null	)
		END IF			
	END IF
	
	//commit change
	ibo_employee_earning.of_update(TRUE,lstr_error)
	li_errcount = UpperBound(lstr_error)
	IF li_errcount > 0 THEN
		FOR li_error = 1 TO li_errcount
			 ls_error_message += lstr_error[li_error].s_message + '~r'
		NEXT
		MessageBox('Employee Earning Insert', ls_error_message )
		dw_main. EVENT ue_setmessage("Error in Inserting Employee Earning","Red")
		li_proceed = -1
	ELSE
		li_proceed = 1
	END IF
			
	
	IF li_proceed = 1 THEN
		//trigger retrieval of employee_earning tab
		lstr_parm.l_parm[1] = ll_employee
		gnv_synchronize.uf_event_trigger('RETRIEVE_EARNINGS_TAB', lstr_parm)
		
	END IF	

	// set back to employee
	This.of_enable()
	This.of_setaction(1, 'Z')
	This.SetColumn("employee")
	This.SetFocus()
END IF				

RETURN AncestorReturnValue
end event

event dw_main::ue_other;call super::ue_other;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_other
// Author   :	Lourdes Garcia
// Date     :	2009/06/17
// 	
// Arguments:	string as_action_id
// 				boolean ab_changefocus
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

this.of_enable_column('employee')

CHOOSE CASE as_action_id
	CASE 'Y'	
		This.of_setaction(1, 'Y')
		dw_main.of_enable()
		
	CASE 'T'
		This.of_setaction(1, 'T')
		dw_main.of_disable()
		dw_main.of_enable_column("action")
		dw_main.of_enable_column("employee")
		dw_main.of_enable_column("roe_reason_code")
		dw_main.of_enable_column("termination_date")
		dw_main.of_enable_column("roe_note")
END CHOOSE		

RETURN 1
end event

event dw_main::losefocus;call super::losefocus;this.Object.roe_note.Height = '64'
end event

event dw_main::ue_open_report;call super::ue_open_report;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_open_report
// Author   :	Monica Petersen
// Date     :	2013/01/31
// 	
// Arguments:	long al_row
// 				string as_column
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

String					ls_book, ls_select, ls_userid
Long						ll_employee
s_preview				lstr_preview
n_ds						lds_preview
w_print_preview		lw_print_preview
w_report_preview		lw_report_preview
DataStore	lds_print
DataWindow	ldw_print

CHOOSE CASE as_column

	CASE 'supervisor'
		ll_employee = this.GetItemNumber(al_row, 'supervisor')
		ls_userid = gnv_app.of_getuserid()
		SELECT Min(abio_user_book.book)
		  INTO :ls_book
		  FROM employee,
		       abio_user_book
		 WHERE employee = :ll_employee
		   AND employee.book = abio_user_book.book
			AND abio_user_book.user_id = :ls_userid
		 USING sqlca;
		IF Not(IsNull(ls_book)) THEN
			lstr_preview.dw_preview  = CREATE u_dw	//need this because otherwise it can't get the sql from the describe statement
			lstr_preview.s_book = ls_book
			lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
			lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('PREREP', 'menu_1')		// Menu item from program
			lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('PREREP', 'menu_2')		// Menu item from program	
			lstr_preview.s_menu_3 = 'c'		// Menu item from program	
			lstr_preview.s_report = "P/R Employee Record"
			lstr_preview.s_parm[1] = 'C'
			lstr_preview.s_parm[2] = 'H'
			lstr_preview.s_parm[5] = String(Today(), 'yyyy')				/*	tax year */
			lstr_preview.s_parm[6] = String(this.GetItemNumber(1, 'supervisor'))					
			lstr_preview.s_parm[7] = String(this.GetItemNumber(1, 'supervisor'))						
			lstr_preview.s_parm[36] = ''					//prevent array overflow
			
			OpenSheetWithParm(lw_report_preview, lstr_preview, &
							"w_report_preview_pr", gnv_app.of_getframe(), 0, Original!)
		ELSE
			MessageBox('View Supervisor',"You do not have access to employee " + String(this.GetItemNumber(al_row, 'supervisor')) + "'s record")
		END IF
							
	CASE 'add_datetime'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('UTEVNT', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('UTEVNT', 'menu_2')		// Menu item from program	
		lstr_preview.s_report = "U/T Event Log Report Drill Down"
		lstr_preview.s_parm[5] = 'ALL'				/*	company */
		lstr_preview.s_parm[7] = 'ALL'				/*	user ID */							
		lstr_preview.s_parm[9] = 'PREENT'			/* event */							
		lstr_preview.s_parm[11] = 'ALL'				/* action */
		lstr_preview.s_parm[13] = String(this.GetItemNumber(al_row, 'employee')) 					/*	key  - pick up employee changes */
		lstr_preview.s_parm[15] = 'ALL'				/*	delta */
		lstr_preview.s_parm[12] = 'STJENT'			/* event2 */
		lstr_preview.s_parm[14] = '%/' + String(this.GetItemNumber(al_row, 'employee')) + '/%'	/*	key2 - where employee is added to a crew*/
		lstr_preview.s_parm[16] = 'ALL'				/*	delta2 */
		lstr_preview.s_parm[18] = '1990101'			/* from date */
		lstr_preview.s_parm[19] = '20991231'		/* to date */
		lstr_preview.s_parm[20] = 'HRPENT'			/* event3 */
		lstr_preview.s_parm[21] = String(this.GetItemNumber(al_row, 'employee'))					/*	delta3  - person changes but not diary events*/
		lstr_preview.s_parm[22] = 'ALL'				/*	key3 */
		lstr_preview.s_parm[23] = 'PREENT'			/* event4 */							
		lstr_preview.s_parm[24] = '%/' + String(this.GetItemNumber(al_row, 'employee')) + '/%'	/*	key4 - employee child tables */
		lstr_preview.s_parm[25] = 'ALL'				/* delta4 */
		lstr_preview.s_parm[26] = 'STJENT'			/* event5 */							
		lstr_preview.s_parm[27] = String(this.GetItemNumber(al_row, 'employee'))					/*	key5 - employee updates from crew entry */
		lstr_preview.s_parm[28] = 'ALL'				/* delta5 */
		lstr_preview.s_parm[36] = ''					//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_ut", gnv_app.of_getframe(), 0, Original!)
						
END CHOOSE

RETURN
end event

event dw_main::ue_get_action_desc;call super::ue_get_action_desc;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_get_action_desc
// Author   :	Monica Petersen
// Date     :	2013/05/28
// 	
// Arguments:	string as_action
// 				string as_description
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

CHOOSE CASE as_action
	CASE 'T'
		as_microhelp = 'Terminate employee.  Sets the termination date and reason code for termination.'
		as_description = 'Terminate, '
	CASE 'Y'
		as_microhelp = 'Re-employ employee (action Y).  Removes termination date and allows other updates.'
		as_description = 're-emploY, '
END CHOOSE

RETURN
end event

event dw_main::ue_validateaction;//DISABLE ANCESTOR CODE

IF as_action = 'A' THEN
	this.of_enable_column('employee')
	this.of_enable_column('name_add')
	This.Modify("DataWindow.Header.Height=90")
ELSE
	This.Modify("DataWindow.Header.Height=0")
END IF

RETURN 1
end event

event dw_main::itemfocuschanging;call super::itemfocuschanging;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	itemfocuschanging
// Author   :	Monica Petersen
// Date     :	2014/04/19
// 	
// Arguments:	long al_row
// 				string as_column
// 	
// Returns:		integer  1 - Success; -1 - Error
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_crew

CHOOSE CASE as_column
	CASE 'crew'
		
		IF dw_main.GetItemNumber(1, 'crew_count') < 2 THEN
			ls_crew = this.GetText()
	
			//if no job/crew on this employee, the supervisor can be maintained manually
			ibo_datapanel_business.of_GetChild("crew_member", ibo_crew_member)
			IF Not IsValid(ibo_crew_member) THEN
				parent.of_msg_db_error("Error reading crew members")
				RETURN -1
			END IF
			
			IF ls_crew <> is_original_crew OR IsNull(is_original_crew) THEN
				IF ibo_crew_member.of_Retrieve("supervisor_flag = 'Y' AND job_or_region = '" + this.GetItemString(al_row, 'job') + "' AND crew = '" + ls_crew + "'") > 0 THEN
					ibo_crew_member.of_SetSort("expiry_date DESC")
					ibo_crew_member.of_Sort()
					
					IF MessageBox("Change Crew", "Change to crew supervised by " + String(ibo_crew_member.of_GetItemNumber(1, 'employee')) &
											+ " - " + f_get_person_name(ibo_crew_member.of_GetItemNumber(1, 'employee')) + "?", Question!, YesNo!, 2) = 2 THEN
						
						dw_main.SetItem(1, "crew", is_original_crew)
						RETURN -1
					ELSE
						dw_main.SetItem(1, "supervisor", ibo_crew_member.of_GetItemNumber(1, 'employee'))
					END IF
					dw_main.POST AcceptText()
				END IF
			END IF
		END IF
END CHOOSE

RETURN AncestorReturnValue

end event

event dw_main::bo_overridepopupdataretrieval;call super::bo_overridepopupdataretrieval;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	bo_overridepopupdataretrieval
// Author   :	Monica Petersen
// Date     :	2015/02/19
// 	
// Arguments:	string as_column
// 				n_ds ads_popup
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

CHOOSE CASE as_column	
	CASE 'area'
		
		RETURN ibo_area.of_populate_area_popup(ads_popup, 								&
																 gnv_app.is_book, 					&
																 this.GetItemString(1, 'job'),	&
																 'L','A','','','','',				&
																 dw_main.GetItemString(1, 'action'))
																
			
	CASE 'centre'
		
		RETURN ibo_centre.of_populate_centre_popup(ads_popup, 							&
																 gnv_app.is_book, 					&
																 this.GetItemString(1, 'job'),	&
																 this.GetItemString(1, 'area'),	&
																 'L','A','','','','',				&
																 dw_main.GetItemString(1, 'action'))
																
			
END CHOOSE

RETURN 0



end event

event dw_main::ue_add_setup;call super::ue_add_setup;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_add_setup
// Author   :	Monica Petersen
// Date     :	2016/03/15
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

String	is_middle
Boolean	lb_message = FALSE, lb_similar_name = FALSE
s_parm	lstr_parm

This.SetRedraw(FALSE)
il_employee = ibo_datapanel_business.of_GetItemNumber(1, 'employee')

//Allow users to assign new employee to crew
dw_main.SetItem(1, "crew_count", 0)
dw_main.SetItem(1, "cc_own_supervisor", 'N')

IF il_employee_indicator = 0 THEN
	IF ibo_person.of_get_person_fields_for_employee(il_employee, lstr_parm) = 1 THEN
		// get person data if retrieved successfully
		is_middle = lstr_parm.s_parm[11]
		If IsNull(is_middle) THEN is_middle = ''
		//dw_main.SetItem(1,"name", LEFT(lstr_parm.s_parm[1] + ' ' + is_middle,25))
		
		dw_main.SetItem(1,"name", LEFT(lstr_parm.s_parm[1],25))
		
		//Jira 2325: check if there's a similar name and warn message
		IF ibo_datapanel_business.of_count("book = '" + gnv_app.is_book + "' and name like '" + lstr_parm.s_parm[1] + "%'") > 0 THEN
			lb_similar_name = TRUE
		ELSE
			lb_similar_name = FALSE
		END IF
		
		dw_main.SetItem(1,"sin", lstr_parm.s_parm[2])
		dw_main.SetItem(1,"gst", lstr_parm.s_parm[3])
		dw_main.SetItem(1,"birth_date", lstr_parm.dt_parm[1])
		dw_main.SetItem(1,"mailing_address_1", lstr_parm.s_parm[4])
		dw_main.SetItem(1,"mailing_address_2", lstr_parm.s_parm[5])
		dw_main.SetItem(1,"mailing_city", lstr_parm.s_parm[6])
		dw_main.SetItem(1,"mailing_country", lstr_parm.s_parm[7])
		dw_main.SetItem(1,"mailing_province", lstr_parm.s_parm[8])
		dw_main.SetItem(1,"mailing_postal", lstr_parm.s_parm[9])	
		dw_main.SetItem(1,"phone", lstr_parm.s_parm[10])	
		dw_main.SetItem(1,"ssn", lstr_parm.s_parm[12])	
		
		// if address fields are NULL, flag as error
		IF (IsNull(lstr_parm.s_parm[4]) AND IsNull(lstr_parm.s_parm[5])) OR &
			IsNull(lstr_parm.s_parm[6]) OR IsNull(lstr_parm.s_parm[7]) THEN
			dw_main.POST EVENT ue_setmessage("Missing address fields. Please complete from Person Entry Screen","Red")
			lb_message = TRUE
		END IF
		
		// set employment type
		IF LEN(lstr_parm.s_parm[3]) > 0 THEN
			ibo_datapanel_business.of_SetItem(1,"employment_type","S")
			ibo_datapanel_business.of_SetItem(1,"vacation_percent",0)
			ibo_datapanel_business.of_SetItem(1,"federal_td1_claim",0)
			ibo_datapanel_business.of_SetItem(1,"provincial_td1_claim",0)
		ELSE
			ibo_datapanel_business.of_SetItem(1,"employment_type","Y")
			ibo_datapanel_business.of_SetItem(1,"vacation_percent",4)
		END IF
		
		ibo_datapanel_business.of_SetItem(1,"federal_zone_deduction",0)
		
		iw_parent.of_enable_apply(TRUE)
		
	END IF
	
	// set warning message if current_book or latest_book_terminated is not the same as gnv_app.is_book
	IF Not(lb_message) THEN	//Don't override missing address message
		IF NOT IsNull(is_current_book) THEN
			IF is_book <> is_current_book THEN dw_main.POST EVENT ue_setmessage("Employee currently employed in " + is_current_book ,"Blue")
		ELSE
			// use latest_book since employee is now terminated
			IF is_book <> is_current_book_terminated THEN 
				dw_main.POST EVENT ue_setmessage("Employee last worked in " + is_current_book_terminated ,"Blue")					
			ELSE
				dw_main.POST EVENT ue_setmessage("" ,"Blue")		
			END IF	
		END IF
	END IF
END IF

IF Not(lb_message) THEN	//Don't override missing address message
	IF lb_similar_name THEN
		dw_main.POST EVENT ue_setmessage("Employee with similar name already exists in " + string(gnv_app.is_book) ,"Blue")					
	ELSE
		dw_main.POST EVENT ue_setmessage("" ,"Blue")		
	END IF	
END IF	
		

This.SetRedraw(TRUE)

//This has to be posted because it gets overwritten when the popups refresh?
ibo_datapanel_business.POST of_SetItem(1, "employee", il_employee)
		
RETURN 1
end event

event dw_main::ue_inquire;call super::ue_inquire;this.of_enable_column('employee')

RETURN 1

end event

event dw_main::ue_change;call super::ue_change;
this.of_enable_column('name_add')
this.of_enable_column('employee')
this.inv_popup_data_list.of_set_popup_filter("job", "")	

RETURN 1

end event

event dw_main::ue_action_key;call super::ue_action_key;//************************************************************
// Object   :	u_cst_pr_employee_detail 
// Event    :	ue_action_changed
// Author   :	Monica Petersen
// Date     :	2016/05/17
// 	
// Arguments:	long al_row
// 				string as_value
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

String	ls_filter
n_ds	lds_temp

IF is_restrict_flag = 'Y' THEN
	ls_filter = "1=1"
ELSE
	ls_filter = "restrict_flag = 'N' OR IsNull(restrict_flag)"
END IF

//Don't bother re-registering if it's already the correct pop up
lds_temp = This.inv_popup_data_list.of_get_popup_datastore('employee')

CHOOSE CASE as_key	
CASE 'A'
	IF lds_temp.dataobject = 'd_popup_employee' THEN
		//on Add, pop up a list of all employees ever (from the person table)
		dw_main.inv_popup_data_list.of_unregister_column( "employee") 	
		dw_main.inv_popup_data_list.of_register_column(	'employee', &
																			'd_popup_employee_add', &
																			'employee', &
																			'employee', &
																			TRUE, 1600, 									&
																			TRUE,	/* empty allowed (user can use the name_add field instead */ 				&
																			TRUE, 	/* retrieve by company */		&
																			TRUE, 	/* retrieve on register */ 	&
																			ls_filter)
	END IF
CASE ELSE
	IF lds_temp.dataobject = 'd_popup_employee_add' THEN
		//Otherwise, just pop up employees in the current set of books
		dw_main.inv_popup_data_list.of_unregister_column( "employee") 	
		dw_main.inv_popup_data_list.of_register_column(	'employee', &
																			'd_popup_employee', &
																			'employee_long', &
																			'name', &
																			TRUE, 1600, 									&
																			TRUE,	/* empty allowed */ 				&
																			TRUE, 	/* retrieve by company */		&
																			TRUE, 	/* retrieve on register */ 	&
																			ls_filter)
	END IF
END CHOOSE
dw_main.inv_popup_data_list.of_set_itemchange(	'employee', FALSE)

RETURN AncestorReturnValue
end event

event dw_main::ue_action_changed;call super::ue_action_changed;String	ls_filter
n_ds	lds_temp

IF is_restrict_flag = 'Y' THEN
	ls_filter = "1=1"
ELSE
	ls_filter = "restrict_flag = 'N' OR IsNull(restrict_flag)"
END IF

lds_temp = This.inv_popup_data_list.of_get_popup_datastore('employee')

IF as_value = 'A' THEN
	IF lds_temp.dataobject = 'd_popup_employee' THEN
		//on Add, pop up a list of all employees ever (from the person table)
		dw_main.inv_popup_data_list.of_unregister_column( "employee") 	
		dw_main.inv_popup_data_list.of_register_column(	'employee', &
																			'd_popup_employee_add', &
																			'employee', &
																			'employee', &
																			TRUE, 1600, 									&
																			TRUE,	/* empty allowed */ 				&
																			TRUE, 	/* retrieve by company */		&
																			TRUE, 	/* retrieve on register */ 	&
																			ls_filter)
	END IF
ELSE
	IF lds_temp.dataobject = 'd_popup_employee_add' THEN
		//Otherwise, just pop up employees in the current set of books
		dw_main.inv_popup_data_list.of_unregister_column( "employee") 	
		dw_main.inv_popup_data_list.of_register_column(	'employee', &
																			'd_popup_employee', &
																			'employee_long', &
																			'name', &
																			TRUE, 1600, 									&
																			TRUE,	/* empty allowed */ 				&
																			TRUE, 	/* retrieve by company */		&
																			TRUE, 	/* retrieve on register */ 	&
																			ls_filter)
	END IF
END IF
end event

