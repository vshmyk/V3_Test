$PBExportHeader$w_pr_pr_cheque.srw
forward
global type w_pr_pr_cheque from w_m_filter_list
end type
end forward

global type w_pr_pr_cheque from w_m_filter_list
integer width = 3017
integer height = 2232
end type
global w_pr_pr_cheque w_pr_pr_cheque

type variables
n_bo_pr_cheque			ibo_pr_cheque
n_bo_user				ibo_user
n_bo_application_properties		ibo_application_properties
n_bo_pr_cheque_premium				ibo_pr_cheque_premium
n_bo_pr_cheque_trade_union			ibo_pr_cheque_trade_union
n_bo_pr_cheque_occupation			ibo_pr_cheque_occupation
String					is_restrict_flag
end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public subroutine of_set_book (string as_book)
public function integer of_protect_all (u_dw adw)
public function integer of_unprotect_all (u_dw adw)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_pr_pr_cheque 
// Function :	of_get_retrieve_args
// Author   :	V. Shmyk
// Date     :	2010/09/15
// 	
// Arguments:	string as_datapanel
// 	
// Returns:		s_parm
// 	
// Desc:			Get Retrieval Arguments
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_name
Long		ll_cheque_no

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ll_cheque_no = ibo_pr_cheque.of_GetItemNumber(idw_list.GetRow(), 'cheque_no')
	ls_name = idw_list.GetItemString(idw_list.GetRow(), 'name')
ELSE
	ll_cheque_no = -1
	ls_name = ''
END IF

lstr_parm.l_parm[1] = ll_cheque_no
lstr_parm.s_parm[1] = gnv_app.is_book
lstr_parm.s_parm[2] = ls_name
lstr_parm.po_parm[2] = idw_list



RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_pr_pr_cheque 
// Function :	of_getlistrecdescription
// Author   :	V. Shmyk
// Date     :	2010/09/15
// 	
// Arguments:	long al_row
// 	
// Returns:		string
// 	
// Desc:			Title of window
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_title

IF al_row > 0 THEN
	ls_title = 'cheque ' + String(idw_list.GetItemNumber(al_row, 'cheque_no')) + ' for ' + idw_list.GetItemString(al_row, 'name')
END IF

RETURN ls_title
end function

public subroutine of_set_book (string as_book);
end subroutine

public function integer of_protect_all (u_dw adw);/*
Protect all fields
*/

String	ls_column_name
String	ls_desc
String	ls_mod
String 	ls_rtn
Long	 	ll_cols
Integer	li_x


ll_cols = Long(adw.Object.DataWindow.Column.Count)
//ib_edit = FALSE
FOR li_x = 1 TO ll_cols
	ls_desc = "#" + string(li_x) + ".Name"
	ls_column_name = adw.Describe(ls_desc)
	ls_mod = ls_column_name + ".Background.Color=" + "'" + string(gnv_app.inv_color.BUTTONFACE) + "'"
	ls_rtn = adw.Modify(ls_mod)
	ls_mod = ls_column_name + ".protect=0"
	ls_rtn = adw.Modify(ls_mod)
NEXT
//ib_edit = TRUE

RETURN 1







end function

public function integer of_unprotect_all (u_dw adw);/*
Enable all fields
*/

String	ls_column_name
String	ls_desc
String	ls_mod
String 	ls_rtn
Long	 	ll_cols
Integer	li_x

ll_cols = Long(adw.Object.DataWindow.Column.Count)

FOR li_x = 1 TO ll_cols
	ls_desc = "#" + string(li_x) + ".Name"
	ls_column_name = adw.Describe(ls_desc)
	ls_mod = ls_column_name + ".Background.Color=" + "'" + string(gnv_app.inv_color.WHITE) + "'"
	ls_rtn = adw.Modify(ls_mod)
	//Set Tab sequence to 'tag' value (easiest way to do this)
	//ls_desc = ls_column_name + ".Tag"
	//ls_tag = adw.Describe(ls_desc)
	ls_mod = ls_column_name + ".Protect=1"
	ls_rtn = adw.Modify(ls_mod)
NEXT

RETURN 1
end function

on w_pr_pr_cheque.create
int iCurrent
call super::create
end on

on w_pr_pr_cheque.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	pfc_preopen
// Author   :	V. Shmyk
// Date     :	2010/05/06
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

Integer			li_rc2, li_rc3, li_rc4, li_rc5
String			ls_support


is_program				= "PRCENT"
is_module 				= "P/R Cheque"
is_datapanel_detail 	= "u_cst_pr_pr_cheque_pay"

// add tabs
li_rc2 = of_add_datapanel(2, is_datapanel_detail, 'Gross & Net')
li_rc3 = of_add_datapanel(3, "u_cst_pr_pr_cheque_earn", 'Earn & Loss')
li_rc4 = of_add_datapanel(4, "u_cst_pr_pr_cheque_premium", 'Premiums')
li_rc5 = of_add_datapanel(5, "u_cst_pr_pr_cheque_wcb", 'WCB')

IF g_bo_application_properties.of_GetItemString(1, 'multiple_unions_per_cheque_flag') = 'Y' THEN
	of_add_datapanel(6, "u_cst_pr_pr_cheque_trade_union", 'Union')
	of_add_datapanel(7, "u_cst_pr_pr_cheque_occupation", 'Occupation')
END IF

//Share tabs 2 and 3, because they both update fields on the same pr_cheque record
IF li_rc2 = 2 AND li_rc3 = 3 THEN
	This.of_share_datapanel("u_cst_pr_pr_cheque_pay", "u_cst_pr_pr_cheque_earn")
END IF

IF NOT IsValid(ibo_pr_cheque) THEN
	ibo_pr_cheque = CREATE n_bo_pr_cheque
	ibo_pr_cheque.of_registerdata(idw_list, FALSE)
END IF	


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

gnv_synchronize.uf_register_interest("REFRESH_APPROVED_CHEQUE_LIST", iw_parent)	
gnv_synchronize.uf_register_interest("REFRESH_CURRENT_CHEQUE_LIST", iw_parent)	
gnv_synchronize.uf_register_interest("REFRESH_CHEQUE_LIST", iw_parent)	
gnv_synchronize.uf_register_interest("FOCUS_PAY_TAB", iw_parent)	
gnv_synchronize.uf_register_interest("FOCUS_EARNINGS_TAB", iw_parent)	

end event

event close;call super::close;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	close
// Author   :	V. Shmyk
// Date     :	2010/09/15
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Destroy Objects and Remove Interest in Synch objects
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF IsValid(ibo_pr_cheque) THEN DESTROY ibo_pr_cheque
IF IsValid(ibo_pr_cheque_premium) THEN DESTROY ibo_pr_cheque_premium

gnv_synchronize.uf_remove_interest("REFRESH_CURRENT_CHEQUE_LIST", iw_parent)	
gnv_synchronize.uf_remove_interest("REFRESH_APPROVED_CHEQUE_LIST", iw_parent)	
gnv_synchronize.uf_remove_interest("FOCUS_PAY_TAB", iw_parent)	
gnv_synchronize.uf_remove_interest("FOCUS_EARNINGS_TAB", iw_parent)	

end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	pfc_postopen
// Author   :	V. Shmyk
// Date     :	2010/09/15
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			Initialize popups
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String ls_filter

ibo_pr_cheque_premium = CREATE n_bo_pr_cheque_premium
ibo_pr_cheque_premium.of_SetTransaction()

ibo_pr_cheque_trade_union = CREATE n_bo_pr_cheque_trade_union
ibo_pr_cheque_trade_union.of_SetTransaction()

ibo_pr_cheque_occupation = CREATE n_bo_pr_cheque_occupation
ibo_pr_cheque_occupation.of_SetTransaction()

//tab_container.SetRedraw(FALSE)	
this.of_setaddnewkey(FALSE)					//Don't pop into add mode when the filtered list is empty
this.is_other_change_actions = 'BFQRTUX'	//These actions only change the current record, so there's no need to retrieve the list (which is very time consuming)

// Initial filtering criteria
idw_filter.SetItem(1, "file_type", "C")
This.is_init_filter = "book = '" +  trim(gnv_app.is_book)  + "' AND file_type = 'C'"
IF is_restrict_flag = 'N' THEN this.is_init_filter += " AND restrict_flag = 'N'"

ls_filter = is_init_filter


// Perform initial retrieve
IF ibo_pr_cheque.of_retrieve(ls_filter) > 0 THEN
	is_last_filter = ls_filter
END IF

EVENT ue_redraw_buttons()
																
idw_filter.inv_popup_data_list.of_register_column(	'premium', &
																'd_popup_premium_type', &
																'premium_type', &
																'description', &
																TRUE, 400, TRUE, FALSE, FALSE, "")

idw_filter.inv_popup_data_list.of_register_column(	'cheque_status', &
																'd_popup_cheque_status', &
																'status', &
																'description', &
																TRUE, 770, TRUE, TRUE, FALSE, "")
	
idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_file_type', &
																'type', &
																'description', &
																TRUE, 770, TRUE, TRUE, FALSE, "")
	
idw_filter.inv_popup_data_list.of_register_column(	'trade_union', &
																'd_popup_trade_union', &
																'trade_union', &
																'description', &
																TRUE, 600, TRUE, TRUE, FALSE, "")															
																
idw_filter.inv_popup_data_list.of_register_column(	'tax_province', &
																'd_popup_province', &
																'province', &
																'name', &
																TRUE, 1000, TRUE, FALSE, FALSE)
																
idw_filter.inv_popup_data_list.of_register_column(	'employee', 									&
																	'd_popup_employee', 							&
																	'employee', 			/* data column */					&
																	'employee', 			/* display column */				&
																	TRUE, 640, 												&
																	TRUE,		/* empty allowed */ 				&
																	TRUE, 	/* retrieve by company */		&
																	TRUE, 	/* retrieve on register */ 	&
																	"") 																		

// Focus on first item on list
idw_filter.POST SetFocus()
idw_filter.POST SetColumn("cheque_no")

//idw_list.EVENT ue_processenter()

tab_container.SetRedraw(TRUE)	


end event

event ue_event_synchronize;call super::ue_event_synchronize;//************************************************************
// Object   :	u_cst_pr_pr_cheque_pay 
// Event    :	ue_event_synchronize
// Author   :	Monica Petersen
// Date     :	2010/10/27
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

UserObject		lou_datapanel

CHOOSE CASE as_event_id
		
	CASE "REFRESH_CHEQUE_LIST"
		This.idw_list.DYNAMIC EVENT ue_filter()

	CASE "REFRESH_APPROVED_CHEQUE_LIST"
		this.idw_filter.of_reset()
		idw_filter.SetItem(1, 'cheque_status', 'A')
		idw_filter.SetItem(1, 'file_type', 'C')
		idw_filter.AcceptText()
		tab_container.tabpage_main.dw_list.EVENT ue_filter()

	CASE "REFRESH_CURRENT_CHEQUE_LIST"
		this.idw_filter.of_reset()
		idw_filter.SetItem(1, 'file_type', 'C')
		idw_filter.AcceptText()
		tab_container.tabpage_main.dw_list.EVENT ue_filter()

	CASE "FOCUS_PAY_TAB"
		lou_datapanel = of_get_datapanel('u_cst_pr_pr_cheque_pay')
		IF IsValid(lou_datapanel) THEN 
			tab_container.SelectTab(2)
		END IF
					
	CASE "FOCUS_EARNINGS_TAB"
		lou_datapanel = of_get_datapanel('u_cst_pr_pr_cheque_earn')
		IF IsValid(lou_datapanel) THEN 
			tab_container.POST SelectTab(3)
		END IF
		
END CHOOSE
		
RETURN 1
end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	ue_pre_retrieve
// Author   :	Monica Petersen
// Date     :	2010/10/22
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

This.idw_filter.SetItem(1, "cheque_no", String(astr_parm.any_parm[1]))

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_pr_pr_cheque
end type

type sle_message from w_m_filter_list`sle_message within w_pr_pr_cheque
end type

type st_blank from w_m_filter_list`st_blank within w_pr_pr_cheque
end type

type cb_back from w_m_filter_list`cb_back within w_pr_pr_cheque
end type

type cb_save from w_m_filter_list`cb_save within w_pr_pr_cheque
end type

type tab_container from w_m_filter_list`tab_container within w_pr_pr_cheque
integer width = 3474
end type

on tab_container.create
call super::create
this.Control[]={this.tabpage_main}
end on

on tab_container.destroy
call super::destroy
end on

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
integer width = 3401
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
integer y = 312
end type

event cb_clear::clicked;
//************************************************************
// Object   :	w_jc_labour_dispersion 
// Event    :	clicked
// Author   :	Monica Petersen
// Date     :	2010/10/22
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Users must have one filter criteria.
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

//OVERRIDE ANCESTOR
idw_filter.of_reset()
idw_filter.SetItem(1, 'file_type', 'C')
idw_filter.SetColumn(1)

idw_list.ibo_business.of_reset()
idw_list.ibo_business.of_SetItem(1, 'file_type', 'C')

cb_filter.EVENT clicked()

EVENT ue_redraw_buttons()
idw_filter.POST SetFocus()

of_displayliststat()

RETURN 1
end event

type cb_print from w_m_filter_list`cb_print within tabpage_main
integer y = 312
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer y = 312
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer x = 5
integer width = 2939
integer height = 272
string dataobject = "d_pr_pr_cheque_filter"
boolean vscrollbar = false
boolean livescroll = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	constructor
// Author   :	V. Shmyk
// Date     :	2010/09/15
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Initialize pop-up service
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

// initialize pop-up service
This.of_set_popup_data(TRUE)

This.of_SetDropDownCalendar(TRUE)
This.iuo_calendar.of_Register("from_issue_date", This.iuo_calendar.NONE)
This.iuo_calendar.of_Register("to_issue_date", This.iuo_calendar.NONE)



end event

event dw_filter::destructor;call super::destructor;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	destructor
// Author   :	V. Shmyk
// Date     :	2010/09/15
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


//This.of_set_popup_data(FALSE)
end event

event dw_filter::ue_get_extra;call super::ue_get_extra;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	ue_get_extra
// Author   :	Monica Petersen
// Date     :	2010/10/07
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

String ls_from_issue_date, ls_to_issue_date

ls_from_issue_date = Trim(String(This.GetItemDate(1, "from_issue_date"), "yyyy.mm.dd"))
ls_to_issue_date	 = Trim(String(This.GetItemDate(1, "to_issue_date"), "yyyy.mm.dd"))

// retrieve only unrestricted data, depending on user_access
IF is_restrict_flag = 'N' THEN
//	is_extra_filter += + " restrict_flag = 'N'"
	is_extra_filter = " book = '" + gnv_app.is_book + "' AND restrict_flag = 'N'"
ELSE
	is_extra_filter = " book = '" + gnv_app.is_book + "'"
END IF


IF ls_from_issue_date <> "" THEN 
	IF is_extra_filter <> '' THEN is_extra_filter += ' AND '
	is_extra_filter += " issue_date >= '" + ls_from_issue_date + "'"
END IF

IF ls_to_issue_date <> "" THEN 
	IF is_extra_filter <> '' THEN is_extra_filter += ' AND '
	is_extra_filter += " issue_date <= '" + ls_to_issue_date + "'"
END IF


RETURN is_extra_filter
end event

event dw_filter::buttonclicked;call super::buttonclicked;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	buttonclicked
// Author   :	Monica Petersen
// Date     :	2010/11/08
// 	
// Arguments:	long row
// 				long actionreturncode
// 				dwobject dwo
// 	
// Returns:		long
// 	
// Desc:			Process calendar dropdowns
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF dwo.name = "b_calendar_issue_date_from" THEN
	IF This.SetColumn("from_issue_date") = 1 THEN
		This.EVENT pfc_DDCalendar()
	END IF
END IF

IF dwo.name = "b_calendar_issue_date_to" THEN
	IF This.SetColumn("to_issue_date") = 1 THEN
		This.EVENT pfc_DDCalendar()
	END IF
END IF

end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 420
integer width = 2949
integer height = 1540
string dataobject = "d_pr_pr_cheque_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	constructor
// Author   :	V. Shmyk
// Date     :	2010/09/15
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

is_report_name = 'P/R CHEQUE'
is_program = 'PRCENT'
end event

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	getfocus
// Author   :	V. Shmyk
// Date     :	2010/09/15
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


IF IsValid(w_popup_data_list) THEN
	Close(w_popup_data_list)
END IF
end event

event dw_list::ue_pbmkey;call super::ue_pbmkey;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	ue_pbmkey
// Author   :	V. Shmyk
// Date     :	2010/09/15
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

event dw_list::rowfocuschanged;call super::rowfocuschanged;
UserObject	luo_datapanel, luo_datapanel_trade_union, luo_datapanel_occupation
luo_datapanel = iw_parent.DYNAMIC of_get_datapanel('u_cst_pr_pr_cheque_premium')

//Add code here to disable/enable premium tab
IF IsValid(luo_datapanel)  AND currentrow > 0 THEN
	IF ibo_pr_cheque_premium.of_retrieve("book = '" + gnv_app.is_book 											&
		+ "' AND cheque_no = " + String(this.GetItemNumber(currentrow, 'cheque_no'))	) > 0 THEN
		luo_datapanel.Enabled = TRUE
	ELSE
		luo_datapanel.Enabled = FALSE
	END IF
END IF

luo_datapanel_trade_union = iw_parent.DYNAMIC of_get_datapanel('u_cst_pr_pr_cheque_trade_union')

//Add code here to disable/enable trade union tab
IF IsValid(luo_datapanel_trade_union)  AND currentrow > 0 THEN
	IF ibo_pr_cheque_trade_union.of_retrieve("book = '" + gnv_app.is_book 											&
		+ "' AND cheque_no = " + String(this.GetItemNumber(currentrow, 'cheque_no'))	) > 1 THEN
		luo_datapanel_trade_union.Enabled = TRUE
	ELSE
		luo_datapanel_trade_union.Enabled = FALSE
	END IF
END IF

luo_datapanel_occupation = iw_parent.DYNAMIC of_get_datapanel('u_cst_pr_pr_cheque_occupation')

//Add code here to disable/enable trade union tab
IF IsValid(luo_datapanel_occupation)  AND currentrow > 0 THEN
	IF ibo_pr_cheque_occupation.of_retrieve("book = '" + gnv_app.is_book 											&
		+ "' AND cheque_no = " + String(this.GetItemNumber(currentrow, 'cheque_no'))) > 1 THEN
		luo_datapanel_occupation.Enabled = TRUE
	ELSE
		luo_datapanel_occupation.Enabled = FALSE
	END IF
END IF

RETURN
end event

event dw_list::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	w_pr_pr_cheque 
// Event    :	ue_preprint
// Author   :	Viktar Shmyk
// Date     :	2011/03/04
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

Date	ld_from_date, ld_to_date
String	ls_date_range

ld_from_date = dw_filter.GetItemDate(1, "from_issue_date")
ld_to_date = dw_filter.GetItemDate(1, "to_issue_date")


ls_date_range = ""

IF NOT IsNull(ld_from_date) THEN
	ls_date_range += " from " + String(ld_from_date, "yyyy.mm.dd")
END IF

IF NOT IsNull(ld_to_date) THEN
	ls_date_range += " to " + String(ld_to_date, "yyyy.mm.dd")
END IF

IF NOT IsNull(ld_from_date) OR NOT IsNull(ld_to_date) THEN
	ls_date_range = " and ISSUE DATE" + ls_date_range
END IF
 


astr_preview.s_sub_title = astr_preview.s_sub_title + ls_date_range

RETURN 1


end event

type uo_pin from w_m_filter_list`uo_pin within w_pr_pr_cheque
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_pr_pr_cheque
end type

type dw_print from w_m_filter_list`dw_print within w_pr_pr_cheque
end type

type dw_buff from w_m_filter_list`dw_buff within w_pr_pr_cheque
end type

type p_progress_gif from w_m_filter_list`p_progress_gif within w_pr_pr_cheque
end type

type st_base from w_m_filter_list`st_base within w_pr_pr_cheque
end type

