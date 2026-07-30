$PBExportHeader$u_cst_pr_employee_cheque.sru
forward
global type u_cst_pr_employee_cheque from u_cst_datapanel_detail
end type
end forward

global type u_cst_pr_employee_cheque from u_cst_datapanel_detail
end type
global u_cst_pr_employee_cheque u_cst_pr_employee_cheque

type variables
Long		il_employee, il_tab_4 = 0
Int		ii_row
String	is_colname
String	is_book
String	is_name


n_bo_company  							ibo_company
n_bo_application_properties		ibo_application_properties
n_bo_trade_union_rate  				ibo_trade_union_rate
n_bo_trade_union  					ibo_trade_union


end variables

forward prototypes
public function long of_retrieve (s_parm astr_parm)
public function integer of_set_cc_fields (long al_row)
end prototypes

public function long of_retrieve (s_parm astr_parm);
//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Function :	of_retrieve
// Author   :	Lourdes Garcia
// Date     :	2009/04/25
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



IF IsValid(ibo_datapanel_business) THEN
	il_employee	= astr_parm.l_parm[1]
	is_book = astr_parm.s_parm[2]
	ll_rc = ibo_datapanel_business.of_retrieve("book = '" + is_book + "' and employee = " + string(il_employee))
	is_name = astr_parm.s_parm[1]
END IF

IF ll_rc > 1 THEN
	dw_main.Reset()
	RETURN 1
END IF

// set cc fields
IF ll_rc > 0 THEN
	of_set_cc_fields(ll_rc)
	
	ibo_trade_union_rate.of_Retrieve("book = '" + string(gnv_app.is_book) + &
											"' and trade_union = '" + ibo_datapanel_business.of_GetItemString(1, "trade_union") + &
											"' and CONVERT(varchar, effective_date, 112) <= '" + string(Today(), 'YYYYMMDD') +  "'" + &
											"  and CONVERT(varchar, expiry_date, 112) >= '" + string(Today(), 'YYYYMMDD') + "'" ) 
END IF

												
RETURN ll_rc
end function

public function integer of_set_cc_fields (long al_row);//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Function :	of_set_cc_fields
// Author   :	Lourdes Garcia
// Date     :	2009/04/27
// 	
// Arguments:	long al_row
// 	
// Returns:		integer
// 	
// Desc:			Set computed column fields
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String		ls_eft_type, ls_support

IF al_row > 0 THEN
	// set cc_eft_type
	IF ibo_company.of_get_eft_type(is_book, ls_eft_type) = 1 THEN
		dw_main.SetItem(al_row,"cc_eft_type",ls_eft_type)
		dw_main.SetItemStatus(al_row,"cc_eft_type",Primary!,NotModified!)
	ELSE
		//messagebox, error logging handled by bo
		ls_support = ibo_application_properties.of_get_support_contact()
		MessageBox("Database Error", "Error reading company.eft_type" + '~n~r' + ls_support, Exclamation!)
	END IF
END IF
	


RETURN 1
end function

on u_cst_pr_employee_cheque.create
call super::create
end on

on u_cst_pr_employee_cheque.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/25
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



is_program = 'PREENT'
ib_endaction_message = TRUE


IF NOT IsValid(ibo_company) THEN
	ibo_company = CREATE n_bo_company
	ibo_company.of_SetTransaction()
END IF


IF NOT IsValid(ibo_application_properties) THEN
	ibo_application_properties = CREATE n_bo_application_properties
	ibo_application_properties .of_SetTransaction()
END IF

IF NOT IsValid(ibo_trade_union_rate) THEN 
	ibo_trade_union_rate = CREATE n_bo_trade_union_rate
	ibo_trade_union_rate.of_SetTransaction()
END IF

IF NOT IsValid(ibo_trade_union) THEN 
	ibo_trade_union = CREATE n_bo_trade_union
	ibo_trade_union.of_SetTransaction()
END IF


end event

event ue_init;call super::ue_init;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	ue_init
// Author   :	Lourdes Garcia
// Date     :	2009/04/25
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

is_datapanel_name = 'Cheque & Dues'
luo_object = This

// set event logging
This.ibo_datapanel_business.DYNAMIC of_SetLogEventName("PREENT")

gnv_synchronize.uf_register_interest("FORCE_CHANGE_ACTION", luo_object)


dw_main.inv_popup_data_list.of_register_column(	'recruitment_vendor', &
																'd_popup_vendor_active', &
																'vendor', &
																'vendor', &
																TRUE, 550, 		 &
																TRUE,	/* empty allowed */ 				&
																TRUE, 	/* retrieve by company */		&
																FALSE, 	/* retrieve on register */ 	&
																"('" + is_user_access_restricted + "' = 'Y' OR restrict_flag = 'N')") 
dw_main.inv_popup_data_list.of_register_column(	'dues_vendor', &
																'd_popup_vendor_active', &
																'vendor', &
																'vendor', &
																TRUE, 550, 		 &
																TRUE,	/* empty allowed */ 				&
																TRUE, 	/* retrieve by company */		&
																FALSE, 	/* retrieve on register */ 	&
																"('" + is_user_access_restricted + "' = 'Y' OR restrict_flag = 'N')") 


RETURN 1
end event

event destructor;call super::destructor;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	destructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/25
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

IF IsValid(ibo_company) THEN DESTROY ibo_company
IF IsValid(ibo_application_properties) THEN DESTROY ibo_application_properties
IF IsValid(ibo_trade_union_rate) THEN DESTROY ibo_trade_union_rate
IF IsValid(ibo_trade_union) THEN DESTROY ibo_trade_union

gnv_synchronize.uf_remove_interest("FORCE_CHANGE_ACTION", luo_object)
end event

event ue_event_synchronize;call super::ue_event_synchronize;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	ue_event_synchronize
// Author   :	Lourdes Garcia
// Date     :	2009/06/11
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
	CASE "FORCE_CHANGE_ACTION"
		il_tab_4 = astr_parm.l_parm[2]
		dw_main.Modify("DataWindow.Header.Height=90")
		dw_main.POST EVENT ue_change()

END CHOOSE	

RETURN AncestorReturnValue
		
end event

event ue_process_change;call super::ue_process_change;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	ue_process_change
// Author   :	Lourdes Garcia
// Date     :	2009/06/11
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

s_parm		lstr_parm
Boolean		lb_flag = FALSE
Long			ll_row
IF AncestorReturnValue = 1 THEN
	
	ll_row = dw_main.GetRow()
	IF ll_row > 0 THEN
		IF ibo_datapanel_business.of_GetItemDecimal(ll_row,"employee_rrsp_per_ck") > 0 OR &
			ibo_datapanel_business.of_GetItemDecimal(ll_row,"employer_rrsp_percent") > 0 OR &
			ibo_datapanel_business.of_GetItemString(ll_row,"safety_to_rrsp_flag") =  'Y' OR &
			ibo_datapanel_business.of_GetItemString(ll_row,"other_incentive_to_rrsp_flag") =  'Y'  THEN
			lb_flag = TRUE
		END IF
	END IF	
	
	IF il_tab_4 = 1 OR lb_flag  THEN
		//message to  force saving of accruals and incentive tab
		POST Messagebox("P/R Employee","Ensure Incentive and Premium information are correct")
		
		// force to accruals tab
		gnv_synchronize.POST uf_event_trigger('FOCUS_ACCRUALS_TAB', lstr_parm)
	END IF
	
	il_tab_4 = 0
	// set Header back to 0
	dw_main.Modify("DataWindow.Header.Height=0")
END IF	


RETURN AncestorReturnValue


end event

event ue_endaction_message;call super::ue_endaction_message;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	ue_endaction_message
// Author   :	Lourdes Garcia
// Date     :	2009/07/30
// 	
// Arguments:	string as_action
// 				string as_message_entity
// 				string as_message_action
// 	
// Returns:		(None)
// 	
// Desc:			Set Message after Update
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


IF as_action <> 'D' THEN
	as_message_entity = 'Cheques & Dues '
ELSE
	as_message_entity = 'Cheques & Dues ' + is_name
END IF
end event

event ue_validate;call super::ue_validate;
//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	ue_validate
// Author   :	Lourdes Garcia
// Date     :	2009/07/19
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
DateTime ldt_recruitment_start_date
Int		li_proceed = 1

ll_row = dw_main.GetRow()

dw_main.AcceptText()

ls_action = dw_main.GetItemString(ll_row, 'action')

IF ls_action = 'A' OR ls_action = 'C' OR ls_action = 'Z'  OR ls_action = 'Y' THEN
	IF ibo_datapanel_business.of_GetItemDecimal(ll_row,"employee_rrsp_percent") <> 0 &
	OR ibo_datapanel_business.of_GetItemDecimal(ll_row,"employee_rrsp_per_ck") <> 0 THEN
		
		IF ibo_trade_union_rate.of_Retrieve("book = '" + string(gnv_app.is_book) + &
												"' and trade_union = '" + ibo_datapanel_business.of_GetItemString(ll_row, "trade_union") + &
												"' and CONVERT(varchar, effective_date, 112) <= '" + string(Today(), 'YYYYMMDD') +  "'" + &
												"  and CONVERT(varchar, expiry_date, 112) >= '" + string(Today(), 'YYYYMMDD') + "'" ) = 1 THEN
												
			IF ibo_trade_union.of_Retrieve("book = '" + string(gnv_app.is_book) + &
											"' and trade_union = '" + ibo_datapanel_business.of_GetItemString(ll_row, "trade_union") + "'" ) = 1 THEN
													
				IF ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
		
					//Everything okay - RRSP goes to company plan (pr_cheque.employee_rrsp)
					
				ELSE
					IF ibo_trade_union_rate.of_GetItemString(1, 'employee_pension_or_rrsp') = 'R' &
					OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'B' &
					OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'R' THEN
					
						//Everything okay - RRSP goes to union plan (pr_cheque.incentive_paid_to_rrsp)
						
					ELSE
						IF ibo_datapanel_business.of_GetItemDecimal(ll_row, "employee_rrsp_per_ck") <> 0 THEN
							dw_main.POST SetColumn("employee_rrsp_per_ck")
						ELSE
							dw_main.POST SetColumn("employee_rrsp_percent")
						END IF
						dw_main.POST SetFocus()
						dw_main.POST EVENT ue_setmessage("Union '" + ibo_datapanel_business.of_GetItemString(ll_row, "trade_union") + "' isn't setup for RRSP contributions.","Red")
						li_proceed = 0			

					END IF
				END IF
				
			ELSE
				dw_main.POST SetColumn("employee_rrsp_percent")
				dw_main.POST SetFocus()
				dw_main.POST EVENT ue_setmessage("Cannot determine if trade union '" + ibo_datapanel_business.of_GetItemString(ll_row, "trade_union") + "' is staff or non-staff.","Red")
			END IF
			
		ELSE
			dw_main.POST SetColumn("employee_rrsp_percent")
			dw_main.POST SetFocus()
			dw_main.POST EVENT ue_setmessage("Cannot determine if trade union '" + ibo_datapanel_business.of_GetItemString(ll_row, "trade_union") + "' is setup for RRSP contributions.","Red")
		END IF
		
	END IF
END IF




ldt_recruitment_start_date = dw_main.GetItemDateTime(1, "recruitment_start_date")

IF (Date(ldt_recruitment_start_date) < RelativeDate(Today(), -120) OR Date(ldt_recruitment_start_date) > RelativeDate(Today(), 120)) AND &
		(dw_main.GetItemString(1, "recruitment_vendor", Primary!, TRUE) = '' OR IsNull(dw_main.GetItemString(1, "recruitment_vendor", Primary!, TRUE)) ) THEN
	
		MessageBox(iw_parent.Title, "Start Date must be within -120 and +120 days time range from today.", Exclamation!)
		li_proceed = 0			
END IF


IF (dw_main.GetItemString(1, "recruitment_vendor") <> "" AND NOT IsNull(dw_main.GetItemString(1, "recruitment_vendor"))) AND &
	(Year(Date(ldt_recruitment_start_date)) <= 1900 OR &
	 dw_main.GetItemNumber(1, "recruitment_hourly_fee") = 0 OR & 
	 dw_main.GetItemNumber(1, "recruitment_12_month_maximum") = 0) THEN 

	 MessageBox(iw_parent.Title, "Recruitment fields may not be blank if vendor specified.", Exclamation!)
	 dw_main.SetColumn("recruitment_vendor")
	 li_proceed = 0			
END IF

RETURN li_proceed

			
			

end event

event ue_process_print;call super::ue_process_print;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	ue_process_print
// Author   :	Monica Petersen
// Date     :	2016/07/21
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

type hpb_progress from u_cst_datapanel_detail`hpb_progress within u_cst_pr_employee_cheque
end type

type dw_main from u_cst_datapanel_detail`dw_main within u_cst_pr_employee_cheque
string dataobject = "d_pr_employee_cheque_dues"
boolean ib_iseventlog = true
end type

event dw_main::constructor;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/25
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
This.of_setdefaultactions('CIVPZ')
this.of_SetDropDownCalendar(TRUE)

this.iuo_calendar.of_Register("recruitment_start_date", this.iuo_calendar.NONE)

is_business_object = 'n_bo_employee'
ib_iseventlog = TRUE

is_report_name = "Employee Cheque && Dues"

This.of_register_entry_screen("dues_vendor", "w_ap_vendor", "APVENT", {"dues_vendor"})
This.of_register_entry_screen("recruitment_vendor", "w_ap_vendor", "APVENT", {"recruitment_vendor"})

CALL SUPER::Constructor
end event

event dw_main::itemchanged;call super::itemchanged;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	itemchanged
// Author   :	Lourdes Garcia
// Date     :	2009/04/27
// 	
// Arguments:	long row
// 				dwobject dwoins
// 				string data
// 	
// Return:	Integer - 0=Accept value and allow focus to change
//							 1=Reject value and do not allow focus to change
//							 2=Reject value but allow the focus to change
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
String				ls_curr_column, &
						ls_action, &
						ls_null
						
String 				ls_fill, & 
						ls_institution, &
						ls_branch, &
						ls_trade_union, &
						ls_book
						
INT 					li_length
Integer				li_rc = 0

Decimal				ldec_employee_rrsp

Date					ldt_effective_date, &
						ldt_null

ls_curr_column = lower(dwo.Name)

ls_action = This.GetItemString(1, 'action')
SetNull(ls_null)
SetNull(ldt_null)

IF AncestorReturnValue = 0 THEN
	CHOOSE CASE ls_curr_column 
		CASE 'eft_institution'
			IF Trim(data) = "" OR IsNull(data) THEN
				ibo_datapanel_business.of_SetItem(row,"eft_branch","")
				ibo_datapanel_business.of_SetItem(row,"eft_account","")
				ibo_datapanel_business.of_SetItem(row,"eft_email_address","")
			ELSE
				li_length = LEN(TRIM(data))
				ls_fill = FILL('0',4 - li_length)
				ls_institution = ls_fill + Trim(data)
				
				ibo_datapanel_business.POST of_SetItem(row, 'eft_institution', ls_institution)

			END IF
		CASE 'eft_us_routing'	
			IF NOT(Trim(data) = "" OR IsNull(data)) THEN
				ibo_datapanel_business.of_SetItem(row,"eft_institution","")
				ibo_datapanel_business.of_SetItem(row,"eft_branch","")
			END IF		
		CASE 'eft_branch'
				li_length = LEN(TRIM(data))
				ls_fill = FILL('0',5 - li_length)
				ls_branch = ls_fill + Trim(data)
				
				ibo_datapanel_business.POST of_SetItem(row, 'eft_branch', ls_branch)
		
		CASE 'employee_rrsp_percent', 'employee_rrsp_per_ck'	
			
			ldec_employee_rrsp = Dec(data)
			ldt_effective_date = Today()
			
			IF ldec_employee_rrsp <> 0 THEN
				ls_trade_union = ibo_datapanel_business.of_GetItemString(row,"trade_union")
				ls_book = ibo_datapanel_business.of_GetItemString(row,"book")
				
				IF ibo_trade_union_rate.of_Retrieve("book = '" + string(ls_book) + &
														"' and trade_union = '" + ls_trade_union + &
														"' and CONVERT(varchar, effective_date, 112) <= '" + string(ldt_effective_date, 'YYYYMMDD') +  "'" + &
														"  and CONVERT(varchar, expiry_date, 112) >= '" + string(ldt_effective_date, 'YYYYMMDD') + "'" ) = 1 THEN
														
					IF ibo_trade_union.of_Retrieve("book = '" + string(ls_book) + &
													"' and trade_union = '" + ls_trade_union + "'" ) = 1 THEN
															
						IF ibo_trade_union.of_GetItemString(1, 'staff_flag') = 'Y' THEN
				
							//Everything okay - RRSP goes to company plan (pr_cheque.employee_rrsp)
							
						ELSE
							IF ibo_trade_union_rate.of_GetItemString(1, 'employee_pension_or_rrsp') = 'R' &
							OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'B' &
							OR ibo_trade_union_rate.of_GetItemString(1, 'employer_pension_or_rrsp') = 'R' THEN
							
								//Everything okay - RRSP goes to union plan (pr_cheque.incentive_paid_to_rrsp)
								dw_main.POST EVENT  ue_setmessage("The RRSP will be payable to the union"	,"Blue")
								
							ELSE
								dw_main.POST SetColumn(ls_curr_column)
								dw_main.POST SetFocus()
								dw_main.POST EVENT ue_setmessage("Union '" + ls_trade_union + "' isn't setup for RRSP contributions.","Red")
								li_rc = 1	//1=Reject value and do not allow focus to change
							END IF
						END IF
						
					ELSE
						dw_main.POST SetColumn(ls_curr_column)
						dw_main.POST SetFocus()
						dw_main.POST EVENT ue_setmessage("Cannot determine if trade union '" + ls_trade_union + "' is staff or non-staff.","Red")
					END IF
					
				ELSE
					dw_main.POST SetColumn(ls_curr_column)
					dw_main.POST SetFocus()
					dw_main.POST EVENT ue_setmessage("Cannot determine if trade union '" + ls_trade_union + "' is setup for RRSP contributions.","Red")
				END IF
				
			END IF
		CASE "recruitment_vendor"
			IF data = '' OR IsNull(data) THEN
				This.SetItem(1, "recruitment_start_date", ldt_null)
				This.SetItem(1, "recruitment_hourly_fee", 0)
				This.SetItem(1, "recruitment_12_month_maximum", 0)
				This.SetItem(1, "recruitment_cost", 0)
				dw_main.POST SetColumn("recruitment_vendor")
			END IF
		CASE "recruitment_start_date"
			IF (Date(data) < RelativeDate(Today(), -120) OR Date(data) > RelativeDate(Today(), 120)) AND &
					(This.GetItemString(1, "recruitment_vendor", Primary!, TRUE) = '' OR IsNull(This.GetItemString(1, "recruitment_vendor", Primary!, TRUE)) ) THEN
				
				MessageBox(iw_parent.Title, "Start Date must be within -120 and +120 days time range from today.", Exclamation!)
				RETURN 1
			END IF
			
	END CHOOSE			
END IF	

RETURN li_rc
end event

event dw_main::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	ue_preprint
// Author   :	Lourdes Garcia
// Date     :	2009/05/11
// 	
// Arguments:	s_preview astr_preview
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

String ls_select, ls_where, ls_tax_year
astr_preview.s_sub_title = string(il_employee) + '-' + is_name 



DataStore	lds_print
DataWindow	ldw_print

astr_preview.dw_preview  = ldw_print
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
IF g_bo_application_properties.of_GetItemString(1, "allow_mixed_case_flag") = 'Y' THEN 
	astr_preview.s_report = 'P/R Employee Record'
ELSE
	astr_preview.s_report = 'P/R EMPLOYEE RECORD'
END IF

RETURN 1
end event

event dw_main::destructor;call super::destructor;This.of_set_popup_data(FALSE)

end event

event dw_main::itemfocuschanging;call super::itemfocuschanging;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	itemfocuschanging
// Author   :	Monica Petersen
// Date     :	2013/11/15
// 	
// Arguments:	long al_row
// 				string as_column
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
	
	//Jira 3181
	CASE 'employee_rrsp_percent'
		IF this.GetItemDecimal(al_row, 'employee_rrsp_percent') = 0 &
		AND ibo_trade_union_rate.of_GetItemDecimal(1, 'matching_employer_rrsp_percent') <> 0 THEN
			this.POST EVENT ue_setmessage(ibo_trade_union_rate.of_GetItemString(1, 'trade_union') + " has " &
										+ String(ibo_trade_union_rate.of_GetItemDecimal(1, 'matching_employer_rrsp_percent')) &
										+ "% matching RRSP", "red")
		END IF
		
		IF this.GetItemDecimal(al_row, 'employee_rrsp_percent') <> 0 &
		AND ibo_trade_union_rate.of_GetItemDecimal(1, 'matching_employer_rrsp_percent') = 0 THEN
			this.POST EVENT ue_setmessage(ibo_trade_union_rate.of_GetItemString(1, 'trade_union') + " has no matching RRSP", "red")
		END IF
		
	CASE 'employee_pension_percent'
		IF this.GetItemDecimal(al_row, 'employee_pension_percent') = 0 &
		AND ibo_trade_union_rate.of_GetItemDecimal(1, 'matching_employer_pension_percent') <> 0 THEN
			this.POST EVENT ue_setmessage(ibo_trade_union_rate.of_GetItemString(1, 'trade_union') + " has " &
										+ String(ibo_trade_union_rate.of_GetItemDecimal(1, 'matching_employer_pension_percent')) &
										+ "% matching pension", "red")
		END IF
		
		IF this.GetItemDecimal(al_row, 'employee_pension_percent') <> 0 &
		AND ibo_trade_union_rate.of_GetItemDecimal(1, 'matching_employer_pension_percent') = 0 THEN
			this.POST EVENT ue_setmessage(ibo_trade_union_rate.of_GetItemString(1, 'trade_union') + " has no matching pension", "red")
		END IF
		
END CHOOSE

RETURN 1
end event

event dw_main::clicked;call super::clicked;//************************************************************
// Object   :	u_cst_pr_employee_cheque 
// Event    :	clicked
// Author   :	Monica Petersen
// Date     :	2016/07/12
// 	
// Arguments:	integer xpos
// 				integer ypos
// 				long row
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

IF dwo.name = 'b_calendar_recruitment' THEN
	
	IF This.SetColumn("recruitment_start_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF

END IF


end event

