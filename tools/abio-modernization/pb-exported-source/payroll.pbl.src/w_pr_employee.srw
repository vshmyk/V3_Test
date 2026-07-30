$PBExportHeader$w_pr_employee.srw
forward
global type w_pr_employee from w_m_filter_list
end type
type cb_cheque from commandbutton within w_pr_employee
end type
type cb_incentive from commandbutton within w_pr_employee
end type
type cb_1 from commandbutton within w_pr_employee
end type
end forward

global type w_pr_employee from w_m_filter_list
integer width = 3365
integer height = 2224
cb_cheque cb_cheque
cb_incentive cb_incentive
cb_1 cb_1
end type
global w_pr_employee w_pr_employee

type variables
String					is_restrict_flag

Long						il_tax_year, il_min_tax_year, il_max_tax_year, il_tab_3,  il_tab_4

n_bo_employee							ibo_employee
n_bo_user								ibo_user
n_bo_employee_earning				ibo_employee_earning


end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public function long of_find_employee (long al_employee)
public function integer of_focus_datapanel (string as_datapanel)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_pr_employee 
// Function :	of_get_retrieve_args
// Author   :	Lourdes Garcia
// Date     :	2009/04/21
// 	
// Arguments:	string as_datapanel
// 	
// Returns:		s_parm
// 	
// Desc:			Set Retrieval Arguments
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_name

Long		ll_employee, &
			ll_min_tax_year, &
			ll_max_tax_year
			
s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ll_employee = ibo_employee.of_getitemnumber(idw_list.GetRow(), 'employee')	// Employee id
	ls_name = ibo_employee.of_getitemstring(idw_list.GetRow(), 'name')
ELSE
	ll_employee = -1
	ls_name = 'NEW RECORD *'
END IF

lstr_parm.l_parm[1] = ll_employee
lstr_parm.s_parm[1] = ls_name
lstr_parm.s_parm[2] = gnv_app.is_book


// get min and max tax_year for employee
ibo_employee_earning.of_min("tax_year","book = '" +  trim(gnv_app.is_book) + "' and employee = " + string(ll_employee), ll_min_tax_year)
ibo_employee_earning.of_max("tax_year","book = '" +  trim(gnv_app.is_book) + "' and employee = " + string(ll_employee), ll_max_tax_year)

lstr_parm.l_parm[2] = ll_min_tax_year
lstr_parm.l_parm[3] = ll_max_tax_year


RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_pr_employee 
// Function :	of_getlistrecdescription
// Author   :	Lourdes Garcia
// Date     :	2009/04/27
// 	
// Arguments:	long al_row
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

String	ls_name
String	ls_title
Long		ll_number

ls_name = ''
IF al_row > 0 THEN
	ls_name = idw_list.GetItemString(al_row, 'name')
	ll_number = idw_list.GetItemNumber(al_row, 'employee')
	ls_title = string(ll_number) + '-' + ls_name
END IF

RETURN ls_title
end function

public function long of_find_employee (long al_employee);//************************************************************
// Object   :	w_pr_employee 
// Function :	of_find_employee
// Author   :	Lourdes Garcia
// Date     :	2009/05/29
// 	
// Arguments:	long al_employee
// 	
// Returns:		long
// 	
// Desc:			Searches for Employee
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long ll_row
Long ll_current_row
n_bo_employee	lbo_employee

IF NOT IsValid(lbo_employee) THEN
	lbo_employee = CREATE n_bo_employee
END IF	

ll_row = ibo_employee.of_find('employee = ' + string(al_employee))

IF ll_row = 0 THEN
	ll_row = lbo_employee.of_retrieve("employee = " + string(al_employee)  + " and book = '" + gnv_app.is_book + "'")
	
	IF ll_row > 0 THEN
		idw_filter.of_reset()
		idw_filter.SetItem(1, 'employee', string(al_employee))
		idw_filter.AcceptText()
		tab_container.tabpage_main.dw_list.EVENT ue_filter()
		ll_row = idw_list.Find("employee = " + string(al_employee) + " and book = '" + gnv_app.is_book + "'", 1, idw_list.RowCount())
	END IF	
	
END IF

IF ll_row > 0 AND (ll_current_row <> ll_row)THEN
	idw_list.ScrollToRow(ll_row)
END IF

IF ll_row <=0 THEN
	Messagebox('Employee Search', 'Employee With Id ' + string(al_employee) + ' Does Not Exist.', Exclamation!)
END IF

IF IsValid(lbo_employee) THEN DESTROY lbo_employee

RETURN ll_row
end function

public function integer of_focus_datapanel (string as_datapanel);//************************************************************
// Object   :	w_pr_employee 
// Function :	of_focus_datapanel
// Author   :	Lourdes Garcia
// Date     :	2011/09/19
// 	
// Arguments:	userobject auo_datapanel
// 	
// Returns:		integer
// 	
// Desc:			Focus on datapanel
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

userobject		lou_datapanel

lou_datapanel = of_get_datapanel(as_datapanel)
IF IsValid(lou_datapanel)  THEN 
	tab_container.SelectTab(of_getdatapanelindex(lou_datapanel))
END IF


RETURN 1
end function

on w_pr_employee.create
int iCurrent
call super::create
this.cb_cheque=create cb_cheque
this.cb_incentive=create cb_incentive
this.cb_1=create cb_1
iCurrent=UpperBound(this.Control)
this.Control[iCurrent+1]=this.cb_cheque
this.Control[iCurrent+2]=this.cb_incentive
this.Control[iCurrent+3]=this.cb_1
end on

on w_pr_employee.destroy
call super::destroy
destroy(this.cb_cheque)
destroy(this.cb_incentive)
destroy(this.cb_1)
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_pr_employee 
// Event    :	pfc_preopen
// Author   :	Lourdes Garcia
// Date     :	2009/04/20
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			Initialize Datapanel, Business Objects and Window Preference
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

string	ls_support



// open user bo
IF NOT IsValid(ibo_user) THEN
	ibo_user = CREATE n_bo_user
END IF	
ibo_user.of_SetTransaction()
IF ibo_user.of_get_user_access(gnv_app.of_getuserid(),is_restrict_flag) = 0 THEN
	// default to restricted
	is_restrict_flag = 'N'
	
	
	ls_support = g_bo_application_properties.of_get_support_contact()
	MessageBox("Database Error", "Error reading abio_user" + '~n~r' + ls_support, Exclamation!)
END IF



is_program				= "PREENT"
is_module 				= "P/R Employee"
is_datapanel_detail 	= "u_cst_pr_employee_detail"

IF is_restrict_flag = 'N' THEN
	is_init_filter 		= "book = '" +  trim(gnv_app.is_book) + "' and restrict_flag = 'N'"
ELSE
	is_init_filter 		= "book = '" +  trim(gnv_app.is_book)  + "'"
END IF	


// first tab
of_add_datapanel(2, is_datapanel_detail, 'Details')

IF NOT IsValid(ibo_employee) THEN
	ibo_employee = CREATE n_bo_employee
	ibo_employee.of_registerdata(idw_list, FALSE)
END IF	


IF NOT IsValid(ibo_employee_earning) THEN
	ibo_employee_earning = CREATE n_bo_employee_earning
	ibo_employee_earning.of_SetTransaction()	
END IF	


of_add_datapanel(3, 'u_cst_pr_employee_cheque', 'Cheque & Dues')
of_add_datapanel(4, 'u_cst_pr_employee_incentive', 'Incentive & Accrual')
of_add_datapanel(5, 'u_cst_employee_premium', 'Premiums')
of_add_datapanel(6, 'u_cst_pr_employee_earning_taxyear', 'Earnings')
of_add_datapanel(7, 'u_cst_pr_employee_wcb', 'WCB')


gnv_synchronize.uf_register_interest("FIND_EMPLOYEE_BY_ID", iw_parent)	
gnv_synchronize.uf_register_interest("HIDE_EARNINGS_TAB", iw_parent)	
gnv_synchronize.uf_register_interest("SHOW_EARNINGS_TAB", iw_parent)	
gnv_synchronize.uf_register_interest("RETRIEVE_EARNINGS_TAB", iw_parent)	
gnv_synchronize.uf_register_interest("FOCUS_CHEQUE_TAB", iw_parent)	
gnv_synchronize.uf_register_interest("FOCUS_ACCRUALS_TAB", iw_parent)	








end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_pr_employee 
// Event    :	pfc_postopen
// Author   :	Lourdes Garcia
// Date     :	2009/04/20
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			Perform Initial retrieve
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String ls_filter
string	ls_extra_values_display[]

tab_container.SetRedraw(FALSE)	

// Initial filtering criteria
idw_filter.SetItem(1, "file_type", "C")
This.is_init_filter = "file_type = 'C' AND " + &
		idw_filter.EVENT DYNAMIC ue_get_extra()

ls_filter = is_init_filter

// Perform initial retrieve
IF ibo_employee.of_retrieve(ls_filter) > 0 THEN
	is_last_filter = ls_filter
END IF

EVENT ue_redraw_buttons()



idw_filter.inv_popup_data_list.of_register_column(	'premium', &
																'd_popup_premium_type', &
																'premium_type', &
																'description', &
																TRUE, 400, TRUE, FALSE, FALSE, "employee_specific_flag = 'Y'")

idw_filter.inv_popup_data_list.of_register_column(	'occupation', &
																'd_popup_occupation_by_trade', &
																'occupation', &
																'occupation', &
																TRUE, 440, TRUE, TRUE, FALSE, "", &
																ls_extra_values_display,  &
																ls_extra_values_display, & 
																"trade_union","trade_union")

idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_blank', &
																'code', &
																'description', &
																TRUE, 640, TRUE, TRUE, TRUE, "", &
																{ 'C','H','P' },  &
																{ 'Current','History','Preliminary'}, & 
																"",	/* s_parent_column 		  - The optional name of another column in the registered source datawindow that acts as a filter (in conjunction with the s_filter expression) for this column's popup data based on its current value*/&
																"") 	/* s_parent_filter_column - The name of the column in the datawindow object that will be matched to the current value of the parent column*/	
																
idw_filter.inv_popup_data_list.of_register_column(	'employment_type', &
																'd_popup_employee_type', &
																'type', &
																'description', &
																TRUE, 1400, TRUE, TRUE, FALSE, "")															
																
idw_filter.inv_popup_data_list.of_register_column(	'wcb_class', &
																'd_popup_wcb_class', &
																'wcb_class', &
																'wcb_class', &
																TRUE, 1300,TRUE, TRUE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'region', &
																'd_popup_region', &
																'region', &
																'region', &
															  TRUE, 640, TRUE, TRUE, FALSE, "")																
																
//idw_filter.inv_popup_data_list.of_register_column(	'job', &
//																'd_popup_job_with_labour_centres', &
//																'job', &
//																'job', &
//															  TRUE, 640, TRUE, TRUE, FALSE, "")																
																
idw_filter.inv_popup_data_list.of_register_column(	'trade', &
																'd_popup_trade_description', &
																'trade', &
																'description', &
																TRUE, 420, TRUE, FALSE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'trade_union', &
																'd_popup_trade_union', &
																'trade_union', &
																'description', &
																TRUE, 500, TRUE, TRUE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'active', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																
idw_filter.inv_popup_data_list.of_register_column(	'owing', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																
idw_filter.inv_popup_data_list.of_register_column(	'exempt', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																
idw_filter.inv_popup_data_list.of_register_column(	'garnishee_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																
//idw_filter.inv_popup_data_list.of_register_column(	'occupation', &
//																'd_popup_occupation', &
//																'occupation', &
//																'description', &
//																550, TRUE, TRUE, FALSE, "")			


idw_filter.of_registermessageboard(sle_message)


// Focus on first item on list
idw_filter.POST SetFocus()
idw_filter.POST SetColumn("employee")




tab_container.SetRedraw(TRUE)	


end event

event ue_redraw_buttons;call super::ue_redraw_buttons;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_redraw_buttons
// Author   :	Lourdes Garcia
// Date     :	2009/04/20
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

UserObject 		lou_datapanel

lou_datapanel = of_get_datapanel('u_cst_pr_employee_cheque')

IF IsValid(lou_datapanel) THEN 
	lou_datapanel.Enabled = (idw_list.RowCount() > 0)
END IF


lou_datapanel = of_get_datapanel('u_cst_pr_employee_incentive')

IF IsValid(lou_datapanel) THEN 
	lou_datapanel.Enabled = (idw_list.RowCount() > 0)
END IF


lou_datapanel = of_get_datapanel('u_cst_employee_premium')

IF IsValid(lou_datapanel) THEN 
	lou_datapanel.Enabled = (idw_list.RowCount() > 0)
END IF


lou_datapanel = of_get_datapanel('u_cst_pr_employee_earning_taxyear')

IF IsValid(lou_datapanel) THEN 
	lou_datapanel.Enabled = (idw_list.RowCount() > 0)
END IF

lou_datapanel = of_get_datapanel('u_cst_pr_employee_wcb')

IF IsValid(lou_datapanel) THEN 
	lou_datapanel.Enabled = (idw_list.RowCount() > 0)
END IF


end event

event close;call super::close;//************************************************************
// Object   :	w_pr_employee 
// Event    :	close
// Author   :	Lourdes Garcia
// Date     :	2009/04/20
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Destroy BO
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF IsValid(ibo_employee) THEN DESTROY ibo_employee
IF IsValid(ibo_employee_earning) THEN DESTROY ibo_employee_earning
IF IsValid(ibo_user) THEN DESTROY ibo_user
IF IsValid(w_popup_data_list) THEN Close(w_popup_data_list)

gnv_synchronize.uf_remove_interest("FIND_EMPLOYEE_BY_ID", iw_parent)	
gnv_synchronize.uf_remove_interest("HIDE_EARNINGS_TAB", iw_parent)	
gnv_synchronize.uf_remove_interest("SHOW_EARNINGS_TAB", iw_parent)	
gnv_synchronize.uf_remove_interest("RETRIEVE_EARNINGS_TAB", iw_parent)	
gnv_synchronize.uf_remove_interest("FOCUS_CHEQUE_TAB", iw_parent)	
gnv_synchronize.uf_remove_interest("FOCUS_ACCRUALS_TAB", iw_parent)	



	




end event

event ue_datapanelselected;call super::ue_datapanelselected;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_datapanelselected
// Author   :	Lourdes Garcia
// Date     :	2009/05/04
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Disable Apply button
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
IF IsValid(tab_container.Control[tab_container.SelectedTab]) THEN 
	CHOOSE CASE tab_container.Control[tab_container.SelectedTab].ClassName()
		CASE 'tabpage_main'
			cb_save.Enabled = FALSE
		CASE ELSE
			cb_save.Enabled = TRUE
	END CHOOSE
END IF

RETURN 1

end event

event ue_event_synchronize;call super::ue_event_synchronize;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_event_synchronize
// Author   :	Lourdes Garcia
// Date     :	2009/05/29
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

Long  			ll_employee, & 
					ll_row
					
String			ls_panels[] = {"u_cst_pr_employee_cheque","u_cst_pr_employee_incentive","u_cst_employee_premium","u_cst_pr_employee_earning_taxyear","u_cst_pr_employee_wcb"}

s_parm 			lstr_parm
					
UserObject		lou_datapanel

CHOOSE CASE as_event_id
	CASE 'FIND_EMPLOYEE_BY_ID'
		ll_employee = astr_parm.l_parm[1]
		of_find_employee(ll_employee)
		
	CASE 'HIDE_EARNINGS_TAB'
		FOR ll_row = 1 TO UpperBound(ls_panels)
			lou_datapanel = of_get_datapanel(ls_panels[ll_row])
			
			IF IsValid(lou_datapanel) THEN 
				lou_datapanel.Enabled = FALSE
			END IF
		NEXT
				
	CASE 'SHOW_EARNINGS_TAB'	
		FOR ll_row = 1 TO UpperBound(ls_panels)
			lou_datapanel = of_get_datapanel(ls_panels[ll_row])
			
			IF IsValid(lou_datapanel) THEN 
				lou_datapanel.Enabled = TRUE
			END IF
		NEXT
				
	CASE "RETRIEVE_EARNINGS_TAB"	
		ll_employee = astr_parm.l_parm[1]
		ll_row  = ibo_employee.of_find('employee = ' + string(ll_employee))
		IF ll_row > 0 THEN
			idw_list.EVENT rowfocuschanged(ll_row)
		END IF	
		
	CASE "FOCUS_CHEQUE_TAB"
		FOR ll_row = 1 TO UpperBound(ls_panels)
			lou_datapanel = of_get_datapanel(ls_panels[ll_row])
			
			IF IsValid(lou_datapanel) THEN 
				lou_datapanel.Enabled = TRUE
			END IF
		NEXT

		il_tab_3 = astr_parm.l_parm[1]
		il_tab_4 = astr_parm.l_parm[2]
		lou_datapanel = of_get_datapanel('u_cst_pr_employee_cheque')
		IF IsValid(lou_datapanel) THEN 

			//tab_container.SelectTab(of_getdatapanelindex(lou_datapanel))
			lstr_parm = of_get_retrieve_args('u_cst_pr_employee_cheque')
			of_show_datapanel('u_cst_pr_employee_cheque', lstr_parm)


			lstr_parm.l_parm[1] = il_tab_3
			lstr_parm.l_parm[2] = il_tab_4
			gnv_synchronize.uf_event_trigger('FORCE_CHANGE_ACTION', lstr_parm)
		END IF
					
	CASE "FOCUS_ACCRUALS_TAB"
		lou_datapanel = of_get_datapanel('u_cst_pr_employee_incentive')
		IF IsValid(lou_datapanel) THEN 
			
			//tab_container.SelectTab(of_getdatapanelindex(lou_datapanel))
			lstr_parm = of_get_retrieve_args('u_cst_pr_employee_incentive')
			of_show_datapanel('u_cst_pr_employee_incentive', lstr_parm)

			gnv_synchronize.uf_event_trigger('FORCE_CHANGE_ACCRUALS', lstr_parm)
		END IF

END CHOOSE
		
RETURN 1
end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_pre_retrieve
// Author   :	Paul Bauermeister
// Date     :	2009/10/17
// 	
// Arguments:	s_parm astr_parm
// 	
// Returns:		(None)
// 	
// Desc:			Set the employee filter value from the specified 
//					parameter
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

This.idw_filter.SetItem(1, "employee", String(astr_parm.any_parm[1]))

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_pr_employee
end type

type sle_message from w_m_filter_list`sle_message within w_pr_employee
end type

type st_blank from w_m_filter_list`st_blank within w_pr_employee
end type

type cb_back from w_m_filter_list`cb_back within w_pr_employee
integer taborder = 60
end type

type cb_save from w_m_filter_list`cb_save within w_pr_employee
end type

type tab_container from w_m_filter_list`tab_container within w_pr_employee
integer width = 3328
end type

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
integer width = 3255
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
integer x = 663
integer y = 328
end type

event cb_clear::clicked;//************************************************************
// Object   :	w_hr_person 
// Event    :	clicked
// Author   :	Viktar Shmyk
// Date     :	2009/03/24
// 	
// Arguments:	(None) 
// 	
// Returns:		long
// 	
// Desc:			Reset Filter
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

idw_filter.of_reset()
idw_filter.SetItem(1, "file_type", 'C')
idw_filter.SetColumn(1)
idw_list.ibo_business.of_reset()

cb_filter.EVENT clicked()

EVENT ue_redraw_buttons()
idw_filter.POST SetFocus()

of_displayliststat()

end event

type cb_print from w_m_filter_list`cb_print within tabpage_main
integer x = 329
integer y = 328
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer y = 328
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer width = 3223
integer height = 312
string dataobject = "d_pr_employee_filter"
boolean vscrollbar = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_pr_employee 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/20
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Initialize				
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

// initialize pop-up service
This.of_set_popup_data(TRUE)



end event

event dw_filter::ue_get_extra;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_get_extra
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	(None)
// 	
// Returns:		string
// 	
// Desc:			Add Extra filter depending on abio_user access
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


// retrieve only unrestricted data, depending on user_access
IF is_restrict_flag = 'N' THEN
	is_extra_filter = "book = '" + gnv_app.is_book + "' AND restrict_flag = 'N'"
ELSE
	is_extra_filter = "book = '" + gnv_app.is_book + "'"
END IF

RETURN is_extra_filter
end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 432
integer width = 3223
integer height = 1532
string dataobject = "d_pr_employee_list"
boolean hsplitscroll = true
end type

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_pr_employee 
// Event    :	getfocus
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


/*IF IsValid(w_popup_data_list) THEN
	Close(w_popup_data_list)
END IF*/
end event

event dw_list::constructor;call super::constructor;
is_report_name = 'EMPLOYEE LIST'
is_program = 'PREENT'

end event

event dw_list::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_preprint
// Author   :	Lourdes Garcia
// Date     :	2009/04/28
// 	
// Arguments:	s_preview astr_preview
// 	
// Returns:		integer
// 	
// Desc:			Print Preview
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
// 2011.07.04		MDP		Jira 1834 - add union, occupation, occupation description, and employee address to export of list tab in Employee Entry
//************************************************************

// filter for subtitle

s_parm lstr_parms
String	ls_whereclause
String	ls_sql
n_ds 		lds_export

lds_export = CREATE n_ds 
lds_export.DataObject = "d_pr_employee_list_export"
lds_export.SetTransObject(SQLCA)


lstr_parms = dw_filter.of_get_filter_data()
astr_preview.s_sub_title = lstr_parms.s_parm[2]


ls_whereclause = idw_list.ibo_business.of_getlastwhereclause()
ls_sql = lds_export.GetSQLSelect()
ls_sql = ls_sql + " WHERE " + ls_whereclause 
lds_export.SetSQLSelect(ls_sql)

lds_export.Retrieve()

astr_preview.ds_export[1] = lds_export

RETURN 1

end event

event dw_list::ue_pbmkey;call super::ue_pbmkey;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_pbmkey
// Author   :	Lourdes Garcia
// Date     :	2009/04/28
// 	
// Arguments:	keycode key
// 				unsignedlong keyflags
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

IF key = KeyEnter! THEN
	This.TriggerEvent('doubleclicked')
END IF
end event

event dw_list::ue_recordadded;//************************************************************
// Object   :	w_pr_employee 
// Event    :	ue_recordadded
// Author   :	Monica Petersen
// Date     :	2015/02/02
// 	
// Arguments:	string as_keywhereclause_db
// 				string as_keywhereclause_dw
// 				boolean ab_reselect
// 	
// Returns:		integer
// 	
// Desc:			OVERRIDE ANCESTOR
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF is_user_access_restricted = 'N' THEN
	as_keywhereclause_db +=  "  AND restrict_flag = 'N' "
END IF

call super::ue_recordadded;

RETURN 1	//AncestorReturnValue
end event

type uo_pin from w_m_filter_list`uo_pin within w_pr_employee
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_pr_employee
end type

type dw_print from w_m_filter_list`dw_print within w_pr_employee
end type

type dw_buff from w_m_filter_list`dw_buff within w_pr_employee
end type

type st_base from w_m_filter_list`st_base within w_pr_employee
end type

type cb_cheque from commandbutton within w_pr_employee
boolean visible = false
integer x = 809
integer y = 2016
integer width = 343
integer height = 100
integer taborder = 40
boolean bringtotop = true
integer textsize = -8
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Arial"
boolean enabled = false
string text = "Cheque"
end type

type cb_incentive from commandbutton within w_pr_employee
boolean visible = false
integer x = 1440
integer y = 2016
integer width = 343
integer height = 100
integer taborder = 50
boolean bringtotop = true
integer textsize = -8
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Arial"
boolean enabled = false
string text = "Incentive"
end type

type cb_1 from commandbutton within w_pr_employee
boolean visible = false
integer x = 1851
integer y = 2024
integer width = 343
integer height = 100
integer taborder = 70
boolean bringtotop = true
integer textsize = -8
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Arial"
boolean enabled = false
string text = "Cheque"
end type

