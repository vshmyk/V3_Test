$PBExportHeader$w_jc_job.srw
forward
global type w_jc_job from w_m_filter_list
end type
end forward

global type w_jc_job from w_m_filter_list
integer height = 2236
end type
global w_jc_job w_jc_job

type variables
n_bo_job			ibo_job

public:
	String		is_book = ''
end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public subroutine of_set_book (string as_book)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_jc_job 
// Function :	of_get_retrieve_args
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

String	ls_job, &
			ls_description

String	ls_book

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ls_job = ibo_job.of_getitemstring(idw_list.GetRow(), 'job')
	ls_description = ibo_job.of_getitemstring(idw_list.GetRow(), 'description')
ELSE
	ls_job = 'NEW RECORD *'
END IF


lstr_parm.s_parm[1] = ls_job
lstr_parm.s_parm[2] = ls_description

IF is_book <> '' THEN
	ls_book = is_book
ELSE
	ls_book = gnv_app.is_book
END IF

lstr_parm.s_parm[3] = ls_book 



RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_jc_job 
// Function :	of_getlistrecdescription
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

String	ls_description
String	ls_title
String	ls_job

ls_description = ''
IF al_row > 0 THEN
	ls_description = idw_list.GetItemString(al_row, 'description')	
	ls_job = idw_list.GetItemString(al_row, 'job')
	ls_title = ls_job + '-' + ls_description
END IF

RETURN ls_title
end function

public subroutine of_set_book (string as_book);is_book = as_book

end subroutine

on w_jc_job.create
int iCurrent
call super::create
end on

on w_jc_job.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_jc_job 
// Event    :	pfc_preopen
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			Initialize window
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
String		ls_book


is_program				= "JCJENT"
is_module 				= "J/C Job"
is_datapanel_detail 	= "u_cst_jc_job_detail"

IF is_book <> '' THEN
	ls_book = is_book
ELSE
	ls_book = gnv_app.is_book
END IF


is_init_filter 		= "book = '" + ls_book  + "'"

// add tab
of_add_datapanel(2, is_datapanel_detail, 'Details')
of_add_datapanel(3, 'u_cst_jc_job_detail_finance', 'Financial')
of_add_datapanel(4, 'u_cst_job_shipping_info', 'Shipping')
of_add_datapanel(5, 'u_cst_jc_job_checklist_item', 'Checklist')
of_add_datapanel(6, 'u_cst_jc_job_document', 'Supporting Documents')


IF NOT IsValid(ibo_job) THEN
	ibo_job = CREATE n_bo_job
	ibo_job.of_registerdata(idw_list, FALSE)
END IF	


end event

event close;call super::close;//************************************************************
// Object   :	w_jc_job 
// Event    :	close
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

IF IsValid(ibo_job) THEN DESTROY ibo_job
IF IsValid(w_popup_data_list) THEN Close(w_popup_data_list)


end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_jc_job 
// Event    :	pfc_postopen
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

String ls_filter, &
		 ls_job
s_parm lstr_parms

tab_container.SetRedraw(FALSE)	



// Initial filtering criteria
idw_filter.SetItem(1, "file_type", "C")
This.is_init_filter = "file_type = 'C' AND " + &
		idw_filter.EVENT DYNAMIC ue_get_extra()

ls_filter = is_init_filter


// Perform initial retrieve
IF ibo_job.of_retrieve(ls_filter) > 0 THEN
	is_last_filter = ls_filter
END IF

EVENT ue_redraw_buttons()

idw_filter.inv_popup_data_list.of_register_column(	'region', &
																'd_popup_region', &
																'region', &
																'region', &
																TRUE, 800, TRUE, TRUE, FALSE, "")


idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_blank', &
																'code', &
																'description', &
																TRUE, 640, TRUE, TRUE, FALSE, "", &
																{ 'C','H','P' },  &
																{ 'Current','History','Preliminary'}, & 
																"",	/* s_parent_column 		  - The optional name of another column in the registered source datawindow that acts as a filter (in conjunction with the s_filter expression) for this column's popup data based on its current value*/&
																"") 	/* s_parent_filter_column - The name of the column in the datawindow object that will be matched to the current value of the parent column*/	
																
idw_filter.inv_popup_data_list.of_register_column(	'wcb_class', &
																'd_popup_wcb_class', &
																'wcb_class', &
																'wcb_class', &
																TRUE, 800, TRUE, TRUE, FALSE, "")

idw_filter.inv_popup_data_list.of_register_column(	'labour_rate_type', &
																'd_popup_labour_rate_type', &
																'labour_rate_type', &
																'labour_rate_type', &
																TRUE, 1100, TRUE, TRUE, FALSE, "")

idw_filter.inv_popup_data_list.of_register_column(	'equipment_rate_type', &
																'd_popup_equipment_rate_type', &
																'equipment_rate_type', &
																'equipment_rate_type', &
																TRUE, 1000, TRUE, TRUE, FALSE, "active_flag = 'Y'")
																

idw_filter.inv_popup_data_list.of_register_column(	'division', &
																'd_popup_division', &
																'division', &
																'division', & 
																TRUE, 600, TRUE, FALSE, FALSE, "")	
																
idw_filter.inv_popup_data_list.of_register_column(	'dashboard_group', &
																'd_popup_dashboard_group', &
																'dashboard_group', &
																'dashboard_group', &
																TRUE, 750, TRUE, FALSE, FALSE, "")	
																
idw_filter.inv_popup_data_list.of_register_column(	'gst_rule', &
																'd_popup_gst_rule', &
																'gst_rule', &
																'gst_rule', &
																TRUE, 900, TRUE, FALSE, FALSE, "")																	

idw_filter.inv_popup_data_list.of_register_column(	'active_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)

																
idw_filter.inv_popup_data_list.of_register_column(	'operator', &
																'd_popup_operator', &
																'operator', &
																'operator', &
																TRUE, 100, TRUE, FALSE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'lu_operator', &
																'd_popup_operator', &
																'operator', &
																'operator', &
																TRUE, 100, TRUE, FALSE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'client', &
																'd_popup_client', &
																'client', &
																'client', &
																FALSE, 380, TRUE, TRUE, FALSE)		
																
idw_filter.of_registermessageboard(sle_message)


// Focus on first item on list
idw_filter.POST SetFocus()
idw_filter.POST SetColumn("job_from")



tab_container.SetRedraw(TRUE)	


end event

event ue_datapanelselected;call super::ue_datapanelselected;//************************************************************
// Object   :	w_jc_job 
// Event    :	ue_datapanelselected
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Display apply button
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

event ue_redraw_buttons;call super::ue_redraw_buttons;//************************************************************
// Object   :	w_jc_job 
// Event    :	ue_redraw_buttons
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			Enable/Disable other tabs
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

UserObject 		lou_datapanel

lou_datapanel = of_get_datapanel('u_cst_jc_job_detail_finance')

IF IsValid(lou_datapanel) THEN 
	lou_datapanel.Enabled = (idw_list.RowCount() > 0)
END IF
end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_jc_labour_dispersion 
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

Integer li_x

CHOOSE CASE UpperBound(astr_parm.s_parm) 
	CASE 1 	
		This.idw_filter.SetItem(1, "job_from", String(astr_parm.any_parm[1]))
	CASE 2 
		//Shipping info
		FOR li_x = 1 TO UpperBound(tab_container.Control) 
			IF tab_container.Control[li_x].ClassName() = 'u_cst_job_shipping_info' THEN
				tab_container.POST SelectTab(li_x)
				gnv_synchronize.POST uf_event_trigger('DRILL_DOWN_FROM_PO', astr_parm)
			END IF
		NEXT
	CASE ELSE
END CHOOSE
end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_jc_job
end type

type sle_message from w_m_filter_list`sle_message within w_jc_job
end type

type st_blank from w_m_filter_list`st_blank within w_jc_job
end type

type cb_back from w_m_filter_list`cb_back within w_jc_job
end type

type cb_save from w_m_filter_list`cb_save within w_jc_job
end type

type tab_container from w_m_filter_list`tab_container within w_jc_job
end type

on tab_container.create
call super::create
this.Control[]={this.tabpage_main}
end on

on tab_container.destroy
call super::destroy
end on

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
end type

type cb_print from w_m_filter_list`cb_print within tabpage_main
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
end type

event cb_filter::clicked;//************************************************************
// Object   :	w_jc_job 
// Event    :	clicked
// Author   :	Lourdes Garcia
// Date     :	2009/09/21
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			override, since filter has default values (file_type = 'C')
//     we do not want to force an Action 'A' if there are data in History,
//		 just display a warning message that the data is in history and do not force an Action 'A'
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Long 	ll_pk_row 
Long	ll_rc
Long	ll_row
Long 	ll_filter
Long		  ll_count
String	ls_extra
String	ls_filter
String	ls_book
s_parm lstr_parms
n_bo_job   lbo_job


ll_rc = dw_list.EVENT ue_filter()

// Get structure from the filter
lstr_parms = dw_filter.of_get_filter_data()

// Get filter criteria
ls_filter = lstr_parms.s_parm[1] 

//if there's just 1 returned row
// get primary keys
ll_pk_row = Upperbound(is_bo_pk)

IF ll_rc  = 1 THEN
	IF ll_pk_row  > 0 THEN
		ll_row = 0
		DO
			ll_row++	
			ll_filter = POS(ls_filter,is_bo_pk[ll_row]) 
		LOOP UNTIL ll_filter > 0 OR (ll_row = ll_pk_row)
		
		// key if part of the filter
		IF ll_filter > 0 AND tab_container.Control[tab_container.SelectedTab].ClassName() <> is_datapanel_detail THEN
			tab_container.SelectTab(is_datapanel_detail)
		END IF
	END IF
ELSE
	
	// check number of rows returned by the business object using key filter
	lbo_job = CREATE n_bo_job
	lbo_job.of_SetTransaction()
	
	IF of_isfilterkey() and ll_rc = 0 THEN
	
	
		IF is_book <> '' THEN
			ls_book = is_book
		ELSE
			ls_book = gnv_app.is_book
		END IF

	
		ll_count = lbo_job.of_count("book = '" + ls_book + "' and job ='" + dw_filter.GetItemString(1,"job_from") + "'" )
		IF ll_count = 1 THEN
			Messagebox(is_module,'Record already exists but it is excluded by the filter criteria ' + char(13) + &
									'(' + tab_container.tabpage_main.dw_filter.is_filter_criteria + ')')

		ELSE
			IF ll_rc = 0 AND of_isfilterkey() AND tab_container.Control[tab_container.SelectedTab].ClassName() <> is_datapanel_detail THEN
					tab_container.SelectTab(is_datapanel_detail)
			END IF
		END IF
	END IF
	
	DESTROY lbo_job
END IF 



dw_list.SetFocus()
end event

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
string dataobject = "d_jc_job_filter"
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_jc_job 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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
this.of_SetDropDownCalendar(TRUE)
this.iuo_calendar.of_Register("start_date", this.iuo_calendar.NONE)

end event

event dw_filter::ue_get_extra;call super::ue_get_extra;//************************************************************
// Object   :	w_jc_job 
// Event    :	ue_get_extra
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		string
// 	
// Desc:			Extra Filter
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_book, ls_from_job, ls_to_job
Integer	li_len_job
Date		ld_start_date, ld_last_update
String	ls_operator, ls_lu_operator
IF is_book <> '' THEN
	ls_book = is_book
ELSE
	ls_book = gnv_app.is_book
END IF

ld_start_date = dw_filter.GetItemDate(1, "start_date")
ld_last_update = dw_filter.GetItemDate(1, "last_update")

is_extra_filter = "book = '" + ls_book + "'"

IF Year(ld_start_date) > 1900 THEN
	ls_operator = dw_filter.GetItemString(1, "operator")
	IF ls_operator = '' OR IsNull(ls_operator) THEN 
		dw_filter.SetItem(1, "operator", "=")
		ls_operator = '='
	END IF
	is_extra_filter = is_extra_filter + " AND start_date " + ls_operator + "'" +  String(ld_start_date, "yyyy-mm-dd") + "'"
END IF

IF Year(ld_last_update) > 1900 THEN
	ls_lu_operator = dw_filter.GetItemString(1, "lu_operator")
	IF ls_lu_operator = '' OR IsNull(ls_lu_operator) THEN 
		dw_filter.SetItem(1, "ls_lu_operator", "=")
		ls_lu_operator = '='
	END IF
	is_extra_filter = is_extra_filter + " AND last_update " + ls_lu_operator + "'" +  String(ld_last_update, "yyyy-mm-dd") + "'"
END IF

//Allow users to select a job range
ls_from_job = This.GetItemString(1, "job_from")
ls_to_job = This.GetItemString(1, "job_to")
IF Len(ls_from_job) > 0 AND Len(ls_to_job) > 0 THEN
	//need a range
	li_len_job = Len(ls_from_job)
	IF Len(ls_to_job) > li_len_job THEN
		li_len_job = Len(ls_to_job)
	END IF
	is_extra_filter += " AND job BETWEEN '" + ls_from_job + "' AND '" + ls_to_job + "' AND Len(job) >= " + String(li_len_job)
ELSEIF Len(ls_from_job) > 0 THEN
	is_extra_filter += " AND job like '%" + ls_from_job + "%'" 
ELSEIF Len(ls_to_job) > 0 THEN
	is_extra_filter += " AND job like '%" + ls_to_job + "%'" 
END IF

RETURN is_extra_filter
end event

event dw_filter::destructor;call super::destructor;//************************************************************
// Object   :	w_jc_job 
// Event    :	destructor
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

event dw_filter::clicked;call super::clicked;//************************************************************
// Object   :	w_jc_job 
// Event    :	clicked
// Author   :	Viktar Shmyk
// Date     :	2017/03/21
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

IF dwo.name = 'b_start_date' THEN
	IF This.SetColumn("start_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF
END IF
IF dwo.name = 'b_last_update' THEN
	IF This.SetColumn("last_update") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF
END IF

end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
string dataobject = "d_jc_job_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_jc_job 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

is_report_name = 'JOB LIST'
is_program = 'JCJENT'
end event

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_jc_job 
// Event    :	getfocus
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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
// Object   :	w_jc_job 
// Event    :	ue_pbmkey
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

event dw_list::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	w_jc_job 
// Event    :	ue_preprint
// Author   :	Viktar Shmyk
// Date     :	2016/02/10
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

String  ls_subtitle
Integer li_pos
String  ls_operator, ls_lu_operator

li_pos = POS(UPPER(astr_preview.s_sub_title), "START DATE")
IF li_pos > 0 THEN 
	ls_operator = idw_filter.GetItemString(1, "operator")
	ls_subtitle = astr_preview.s_sub_title
	
	ls_subtitle = Replace(ls_subtitle, li_pos, 10, 'START DATE ' + ls_operator + " ")
	
	astr_preview.s_sub_title = ls_subtitle 
	
END IF

li_pos = POS(UPPER(astr_preview.s_sub_title), "LAST UPDATE")
IF li_pos > 0 THEN 
	ls_lu_operator = idw_filter.GetItemString(1, "lu_operator")
	ls_subtitle = astr_preview.s_sub_title
	
	ls_subtitle = Replace(ls_subtitle, li_pos, 10, 'LAST UPDATE ' + ls_lu_operator + " ")
	
	astr_preview.s_sub_title = ls_subtitle 
	
END IF

RETURN 1
end event

type uo_pin from w_m_filter_list`uo_pin within w_jc_job
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_jc_job
end type

type dw_print from w_m_filter_list`dw_print within w_jc_job
end type

type dw_buff from w_m_filter_list`dw_buff within w_jc_job
end type

type p_progress_gif from w_m_filter_list`p_progress_gif within w_jc_job
end type

type st_base from w_m_filter_list`st_base within w_jc_job
end type

