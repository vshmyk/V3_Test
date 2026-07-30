$PBExportHeader$w_pr_field_timesheet.srw
forward
global type w_pr_field_timesheet from w_m_filter_list
end type
type st_next from statictext within w_pr_field_timesheet
end type
end forward

global type w_pr_field_timesheet from w_m_filter_list
integer height = 2236
st_next st_next
end type
global w_pr_field_timesheet w_pr_field_timesheet

type variables
n_bo_field_timesheet			ibo_field_timesheet
String					is_last_apply_key

end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_pr_timesheet 
// Function :	of_get_retrieve_args
// Author   :	Monica Petersen
// Date     :	2016/04/21
// 	
// Arguments:	string as_datapanel
// 	
// Returns:		s_parm
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

lstr_parm.s_parm[1] = gnv_app.is_book

IF idw_list.GetRow() > 0 THEN
	lstr_parm.s_parm[2] = ibo_field_timesheet.of_GetItemString(idw_list.GetRow(), 'add_user_id')
	lstr_parm.dt_parm[1] = ibo_field_timesheet.of_GetItemDateTime(idw_list.GetRow(), 'work_date')
	lstr_parm.i_parm[1] = ibo_field_timesheet.of_GetItemNumber(idw_list.GetRow(), 'field_timesheet_item')
ELSE
	lstr_parm.l_parm[1] = -1
	lstr_parm.dt_parm[1] = Datetime(Today(), Time(0,0,0))
	lstr_parm.i_parm[1] = 1
END IF

RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_pr_timesheet 
// Function :	of_getlistrecdescription
// Author   :	Monica Petersen
// Date     :	2016/05/11
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
DateTime	ldt_work
Integer	li_item

ls_name = ''
IF al_row > 0 THEN
	ls_name = idw_list.GetItemString(al_row, 'name')
	//ll_number = idw_list.GetItemNumber(al_row, 'employee')
	ldt_work = idw_list.GetItemDateTime(al_row, 'work_date')
	li_item = idw_list.GetItemNumber(al_row, 'field_timesheet_item')
	ls_title = ls_name + ', ' + string(ldt_work, 'yyyy.mm.dd') + ', revision ' + String(li_item) 
END IF

RETURN ls_title
end function

on w_pr_field_timesheet.create
int iCurrent
call super::create
this.st_next=create st_next
iCurrent=UpperBound(this.Control)
this.Control[iCurrent+1]=this.st_next
end on

on w_pr_field_timesheet.destroy
call super::destroy
destroy(this.st_next)
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	pfc_preopen
// Author   :	Monica Petersen
// Date     :	2016/04/21
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

Integer	li_rc


is_program				= "PRFENT"
is_module 				= "P/R Field Timesheets"
is_datapanel_detail 	= "u_cst_pr_field_timesheet_detail"
//is_datapanel_detail 	= "u_cst_pr_timesheet_preliminary"

is_init_filter 		= "book = '" +  trim(gnv_app.is_book)  + "'"

// add tab
li_rc = of_add_datapanel(2, is_datapanel_detail, 'Details')
li_rc = of_add_datapanel(3, 'u_cst_pr_timesheet_preliminary_document', 'Document')

IF NOT IsValid(ibo_field_timesheet) THEN
	ibo_field_timesheet = CREATE n_bo_field_timesheet
	ibo_field_timesheet.of_registerdata(idw_list, FALSE)
END IF	

//gnv_synchronize.uf_register_interest("BO_POSTUPDATE", iw_parent)	
//gnv_synchronize.uf_register_interest("FOCUS_ON_APPLY", iw_parent)	
//gnv_synchronize.uf_register_interest("UPDATE_TIMESHEETS", iw_parent)	
//gnv_synchronize.uf_register_interest("REFRESH_TIMESHEET_LIST", iw_parent)	

end event

event close;call super::close;
//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	close
// Author   :	Monica Petersen
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

IF IsValid(ibo_field_timesheet) THEN DESTROY ibo_field_timesheet
IF IsValid(w_popup_data_list) THEN Close(w_popup_data_list)
//gnv_synchronize.uf_remove_interest("BO_POSTUPDATE", iw_parent)	
//gnv_synchronize.uf_remove_interest("UPDATE_TIMESHEETS", iw_parent)	
//gnv_synchronize.uf_remove_interest("REFRESH_TIMESHEET_LIST", iw_parent)	
//gnv_synchronize.uf_remove_interest("RESET_APPLY_KEY", iw_parent)	
//gnv_synchronize.uf_remove_interest("REFRESH_IMPORTED_TIMESHEET_LIST", iw_parent)	

end event

event pfc_postopen;call super::pfc_postopen;
//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	pfc_postopen
// Author   :	Monica Petersen
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
		 ls_clien
string	ls_extra_values_data_date_type[] = { 'A','C','E' }
string	ls_extra_values_display_date_type[] = { 'Actual timesheet date','Cost date','Entry date'}
s_parm lstr_parms

tab_container.SetRedraw(FALSE)	

this.of_setaddnewkey(FALSE)	//Don't pop into add mode when the filtered list is empty

// Initial filtering criteria
idw_filter.SetItem(1, "file_type", "C")
idw_filter.SetItem(1, "status", "In Progress")
This.is_init_filter = "file_type IN ('C','P') AND " + &
		idw_filter.EVENT DYNAMIC ue_get_extra()

// Perform initial retrieve
tab_container.tabpage_main.cb_filter.EVENT Clicked()
This.is_last_filter = This.is_init_filter

idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_blank', &
																'code', &
																'description', &
																TRUE, 900, TRUE, TRUE, TRUE, "", &
																{ 'C','H','P' },  &
																{ 'Current & Preliminary','History','Preliminary'}, & 
																"",	/* s_parent_column 		  - The optional name of another column in the registered source datawindow that acts as a filter (in conjunction with the s_filter expression) for this column's popup data based on its current value*/&
																"") 	/* s_parent_filter_column - The name of the column in the datawindow object that will be matched to the current value of the parent column*/	
																
idw_filter.inv_popup_data_list.of_register_column(	'status', &
																'd_popup_blank_no_code', &
																'code', &
																'description', &
																TRUE, 900, FALSE, TRUE, TRUE, "", &
																{ 'In Progress','Completed', 'Has Rejections', 'All' },  &
																{ 'In Progress','Completed', 'Has Rejections', 'All'}, & 
																"",	/* s_parent_column 		  - The optional name of another column in the registered source datawindow that acts as a filter (in conjunction with the s_filter expression) for this column's popup data based on its current value*/&
																"") 	/* s_parent_filter_column - The name of the column in the datawindow object that will be matched to the current value of the parent column*/	
																
idw_filter.inv_popup_data_list.of_register_column(	'add_user_id', &
																'd_popup_user', &
																'user_id', &
																'name', &
																TRUE, 600, TRUE, TRUE, FALSE, "")															
																
idw_filter.of_registermessageboard(sle_message)

// Focus on first item on list
idw_filter.POST SetFocus()
idw_filter.POST SetColumn("add_user_id")

tab_container.SetRedraw(TRUE)	


end event

event ue_event_synchronize;call super::ue_event_synchronize;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	ue_event_synchronize
// Author   :	Monica Petersen
// Date     :	2016/04/28
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

Long	ll_list_row, ll_ts_row
s_parm	lstr_parm_details

CHOOSE CASE as_event_id
				
	CASE "FOCUS_ON_APPLY"
		cb_save.SetFocus()
		st_next.visible = TRUE
				
END CHOOSE
		
RETURN 1
end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	ue_pre_retrieve
// Author   :	Monica Petersen
// Date     :	2016/08/19
// 	
// Arguments:	s_parm astr_parm
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

This.idw_filter.SetItem(1, 'file_type', '')




end event

event ue_post_retrieve;call super::ue_post_retrieve;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	ue_post_retrieve
// Author   :	Viktar Shmyk
// Date     :	2016/08/24
// 	
// Arguments:	s_parm astr_parm
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

//IF UpperBound(astr_parm.any_parm) = 1 THEN
//	IF astr_parm.s_parm[1] = "cheque_no" AND This.idw_list.RowCount() > 0 THEN
//		This.idw_list.EVENT ue_processenter()
//	END IF
//ELSEIF UpperBound(astr_parm.any_parm) = 2 THEN
//	IF astr_parm.s_parm[2] = "premium_type" AND This.idw_list.RowCount() > 0 THEN 
//		This.idw_list.EVENT ue_processenter()
//	END IF
//END IF

end event

event resize;call super::resize;
st_next.y = cb_save.y + 15
st_next.x = cb_save.x - 100 - st_next.width


end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_pr_field_timesheet
end type

type sle_message from w_m_filter_list`sle_message within w_pr_field_timesheet
end type

type st_blank from w_m_filter_list`st_blank within w_pr_field_timesheet
end type

type cb_back from w_m_filter_list`cb_back within w_pr_field_timesheet
end type

type cb_save from w_m_filter_list`cb_save within w_pr_field_timesheet
integer x = 2194
integer width = 343
end type

event cb_save::keydown;//************************************************************
// Object   :	w_m_multi_link 
// Event    :	keydown
// Author   :	Viktar Shmyk
// Date     :	2009/03/06
// 	
// Arguments:	keycode key
// 				unsignedlong keyflags
// 	
// Returns:		long
// 	
// Desc:		Processes the keystrokes when the button has focus
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

s_parm	lstr_parm

Parent.of_SetRedraw(FALSE)
CHOOSE CASE key
	
//	CASE KeyEnter! 
//		ib_keyenter = TRUE

	CASE KeyE! 
		
		of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_apply()
		is_last_apply_key = 'E'
		st_next.text = 'employee next'
		//Put focus on employee
		of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_set_next_field_same_action('employee')
		
	CASE KeyD!
		of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_apply()
		is_last_apply_key = 'D'
		st_next.text = 'date next'
		//Put focus on date
		of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_set_next_field_same_action('work_date_hold')
				
	CASE KeyY!
		of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_apply()
		is_last_apply_key = 'Y'
		st_next.text = 'item next'
		//Put focus on item
		of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_set_next_field_same_action('timesheet_item')
		
	
	CASE KeyUpArrow!, KeyDownArrow!
		//Don't do anything, handled in the ancestor, but definitely don't do the 'ELSE' case!
		gnv_synchronize.POST uf_event_trigger('RETURN_FOCUS', lstr_parm)
		
	CASE ELSE
		CHOOSE CASE is_last_apply_key
			CASE 'E'
				//Put focus on employee
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_apply()
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_set_next_field_same_action('employee')
			CASE 'D'
				//Put focus on date
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_apply()
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_set_next_field_same_action('work_date_hold')
			CASE 'Y'
				//Put focus on item
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_apply()
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_set_next_field_same_action('timesheet_item')
			CASE ELSE
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_apply()
				of_get_datapanel(of_get_current_datapanel()).EVENT DYNAMIC ue_set_next_field_same_action('timesheet_item')
		END CHOOSE
		
END CHOOSE

Parent.POST of_SetRedraw(TRUE)

end event

event cb_save::getfocus;call super::getfocus;
sle_message.text = "for next record’s key field use E for employee, D for date, or Y for item"
end event

event cb_save::losefocus;call super::losefocus;
st_next.visible = FALSE

end event

type tab_container from w_m_filter_list`tab_container within w_pr_field_timesheet
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

type cb_show_help from w_m_filter_list`cb_show_help within tabpage_main
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
integer y = 268
end type

event cb_clear::clicked;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	clicked
// Author   :	Monica Petersen
// Date     :	2016/05/05
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
integer y = 268
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer y = 268
end type

event cb_filter::clicked;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	clicked
// Author   :	Monica Petersen
// Date     :	2016/05/05
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Ensure one filter is provided
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String	ls_filter, ls_full_filter
String	ls_extra
s_parm	lstr_parm
Long		ll_rows

//OVERRIDE ANCESTOR
lstr_parm = dw_filter.of_get_filter_data()
ls_filter = lstr_parm.s_parm[1]
ls_extra = dw_filter.EVENT ue_get_extra()

//Count rows and ask user to refine filter
ls_full_filter = ls_extra
IF ls_filter <> '' THEN ls_full_filter += " AND " + lstr_parm.s_parm[1]
//ll_rows = tab_container.tabpage_main.dw_list.ibo_business.of_count(ls_full_filter)
ll_rows = ibo_business_temp.of_count(ls_full_filter)

IF ll_rows < 0 THEN
	of_msg_db_error("Error filtering rows: " + ls_full_filter)
	RETURN -1
END IF

IF ll_rows > 100000 THEN
	//Too many records in the list to allow a full retrieval
	MessageBox('P/R Timesheet Filter', String(ll_rows, '#,###') + ' timesheets match your criteria. Please specify another filter parameter.')
	RETURN 1	
ELSE
	call super::clicked
END IF

RETURN 1
end event

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer height = 252
string dataobject = "d_pr_field_timesheet_filter"
boolean vscrollbar = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	constructor
// Author   :	Monica Petersen
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

This.of_SetDropDownCalendar(TRUE)
This.iuo_calendar.of_Register("from_work_date", This.iuo_calendar.NONE)
This.iuo_calendar.of_Register("to_work_date", This.iuo_calendar.NONE)

end event

event dw_filter::ue_get_extra;call super::ue_get_extra;//************************************************************
// Object   :	w_ap_ap_work 
// Event    :	ue_get_extra
// Author   :	Monica Petersen
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

String ls_book, ls_from_work_date, ls_to_work_date, ls_status, ls_name

ls_from_work_date = Trim(String(This.GetItemDate(1, "from_work_date"), "yyyy.mm.dd"))

is_extra_filter = " field_timesheet.book = '" + gnv_app.is_book + "'"

ls_to_work_date	= Trim(String(This.GetItemDate(1, "to_work_date"), "yyyy.mm.dd"))
IF ls_from_work_date <> "" THEN 
	IF is_extra_filter <> '' THEN is_extra_filter += ' AND '
	is_extra_filter += " field_timesheet.work_date >= '" + ls_from_work_date + "'"
END IF

IF ls_to_work_date <> "" THEN 
	IF is_extra_filter <> '' THEN is_extra_filter += ' AND '
	is_extra_filter += " field_timesheet.work_date <= '" + ls_to_work_date + "'"
END IF

//Allow the user to search for completed/in progress field timesheets
ls_status = this.GetItemString(1, 'status')
IF ls_status = 'In Progress' THEN
	is_extra_filter += "  AND EXISTS (SELECT 1 " &
						 +  "                FROM timesheet  " &
						 +  "               WHERE timesheet.book 		= field_timesheet.book " &
						 +  "                 AND timesheet.add_user_id= field_timesheet.add_user_id " &
						 +  "                 AND timesheet.work_date 	= field_timesheet.work_date  " &
						 +  "                 AND timesheet.field_timesheet_item 	= field_timesheet.field_timesheet_item  " &
						 +  "                 AND timesheet.file_type = 'P')"
ELSEIF ls_status = 'Completed' THEN
	is_extra_filter += "  AND Not EXISTS (SELECT 1 " &
						 +  "                FROM timesheet  " &
						 +  "               WHERE timesheet.book 		= field_timesheet.book " &
						 +  "                 AND timesheet.add_user_id= field_timesheet.add_user_id " &
						 +  "                 AND timesheet.work_date 	= field_timesheet.work_date  " &
						 +  "                 AND timesheet.field_timesheet_item 	= field_timesheet.field_timesheet_item  " &
						 +  "                 AND timesheet.file_type = 'P')"
ELSEIF ls_status = 'Has Rejections' THEN
	is_extra_filter += "  AND EXISTS (SELECT 1 " &
						 +  "                FROM timesheet  " &
						 +  "               WHERE timesheet.book 		= field_timesheet.book " &
						 +  "                 AND timesheet.add_user_id= field_timesheet.add_user_id " &
						 +  "                 AND timesheet.work_date 	= field_timesheet.work_date  " &
						 +  "                 AND timesheet.field_timesheet_item 	= field_timesheet.field_timesheet_item  " &
						 +  "                 AND timesheet.file_type = 'R')"
END IF

ls_name = this.GetItemString(1, 'name')
IF ls_name <> "" THEN 
	IF is_extra_filter <> '' THEN is_extra_filter += ' AND '
	is_extra_filter += " Isnull(abio_user.NAME, field_timesheet.add_user_id) like '%" + ls_name + "%'"
END IF

RETURN is_extra_filter



end event

event dw_filter::destructor;call super::destructor;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	destructor
// Author   :	Monica Petersen
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

event dw_filter::buttonclicked;call super::buttonclicked;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	buttonclicked
// Author   :	Monica Petersen
// Date     :	2016/05/05
// 	
// Arguments:	long row
// 				long actionreturncode
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

IF dwo.name = "b_calendar_work_date_from" THEN
	IF This.SetColumn("from_work_date") = 1 THEN
		This.EVENT pfc_DDCalendar()
	END IF
END IF

IF dwo.name = "b_calendar_work_date_to" THEN
	IF This.SetColumn("to_work_date") = 1 THEN
		This.EVENT pfc_DDCalendar()
	END IF
END IF


end event

event dw_filter::itemchanged;call super::itemchanged;
CHOOSE CASE dwo.name
	CASE 'status'
		cb_filter.EVENT clicked()
END CHOOSE

RETURN 0
end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer x = 5
integer y = 380
integer width = 2501
integer height = 1588
string dataobject = "d_pr_field_timesheet_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2016/04/21
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

is_report_name = 'Field Timesheets List'
is_program = 'PRFENT'
end event

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_pr_timesheet 
// Event    :	getfocus
// Author   :	Monica Petersen
// Date     :	2016/04/21
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
// Object   :	w_pr_timesheet 
// Event    :	ue_pbmkey
// Author   :	Monica Petersen
// Date     :	2016/04/21
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

event dw_list::ue_filter;String ls_filter, ls_filter_no_extra
String ls_descr
String ls_extra	
Long	 ll_rc = 1, ll_pk_row, ll_filter, ll_row

s_parm lstr_parms

SetPointer(HourGlass!)

// Get structure from the filter
lstr_parms = dw_filter.of_get_filter_data()
// Get filter criteria
ls_filter = lstr_parms.s_parm[1] 

ls_filter_no_extra = ls_filter

dw_list.of_SetRedraw(FALSE)

ls_extra = dw_filter.EVENT ue_get_extra()

IF is_external_filter <> "" THEN
	ls_extra  = ls_extra + " AND " + is_external_filter
END IF 

IF ls_filter = '' THEN 
	ls_filter = "1 = 1"
END IF

IF ls_extra <> '' THEN 
	ls_filter += " AND " + ls_extra
END IF

//This was a dry run in the ancestor, but we override it and run it for real here
ll_rc = This.ibo_business.of_retrieve(ls_filter) 
IF ll_rc < 0 THEN 
	dw_list.Reset()
END IF

IF ll_rc > 0 THEN
	is_last_filter = ls_filter
END IF

EVENT ue_redraw_buttons()

IF NOT ib_asynchronous_retrieval THEN 
	dw_list.of_SetRedraw(TRUE)
END IF


RETURN ll_rc 


end event

type uo_pin from w_m_filter_list`uo_pin within w_pr_field_timesheet
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_pr_field_timesheet
end type

type dw_print from w_m_filter_list`dw_print within w_pr_field_timesheet
end type

type dw_buff from w_m_filter_list`dw_buff within w_pr_field_timesheet
end type

type p_progress_gif from w_m_filter_list`p_progress_gif within w_pr_field_timesheet
end type

type st_base from w_m_filter_list`st_base within w_pr_field_timesheet
end type

type st_next from statictext within w_pr_field_timesheet
boolean visible = false
integer x = 1563
integer y = 2036
integer width = 599
integer height = 84
boolean bringtotop = true
integer textsize = -10
integer weight = 400
fontcharset fontcharset = ansi!
fontpitch fontpitch = variable!
fontfamily fontfamily = swiss!
string facename = "Arial"
long textcolor = 8388608
long backcolor = 67108864
alignment alignment = right!
boolean focusrectangle = false
end type

