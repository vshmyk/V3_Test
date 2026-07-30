$PBExportHeader$w_st_timesheet_status.srw
forward
global type w_st_timesheet_status from w_m_filter_list
end type
end forward

global type w_st_timesheet_status from w_m_filter_list
integer width = 3017
integer height = 2232
end type
global w_st_timesheet_status w_st_timesheet_status

type variables
n_bo_timesheet_status			ibo_timesheet_status

end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public subroutine of_set_book (string as_book)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_st_timesheet_status 
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

String	ls_timesheet_status, &
			ls_description

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ls_timesheet_status = ibo_timesheet_status.of_getitemstring(idw_list.GetRow(), 'timesheet_status')
	ls_description = ibo_timesheet_status.of_getitemstring(idw_list.GetRow(), 'description')
ELSE
	ls_timesheet_status = 'NEW RECORD *'
END IF



lstr_parm.s_parm[1] = ls_timesheet_status
lstr_parm.s_parm[2] = ls_description



RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_st_timesheet_status 
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
	ls_title = idw_list.GetItemString(al_row, 'timesheet_status') + '-' + idw_list.GetItemString(al_row, 'description')
END IF

RETURN ls_title
end function

public subroutine of_set_book (string as_book);
end subroutine

on w_st_timesheet_status.create
int iCurrent
call super::create
end on

on w_st_timesheet_status.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_st_timesheet_status 
// Event    :	pfc_preopen
// Author   :	Monica Petersen
// Date     :	2012/10/02
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


is_program				= "STEENT"
is_module 				= "S/T Timesheet Status"
is_datapanel_detail 	= "u_cst_st_timesheet_status"

// add tab
of_add_datapanel(2, is_datapanel_detail, 'Details')

IF NOT IsValid(ibo_timesheet_status) THEN
	ibo_timesheet_status = CREATE n_bo_timesheet_status
	ibo_timesheet_status.of_registerdata(idw_list, FALSE)
END IF	


end event

event close;call super::close;//************************************************************
// Object   :	w_st_timesheet_status 
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

IF IsValid(ibo_timesheet_status) THEN DESTROY ibo_timesheet_status

end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_st_timesheet_status 
// Event    :	pfc_postopen
// Author   :	Monica Petersen
// Date     :	2012/10/02
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

String ls_filter
s_parm lstr_parms

tab_container.SetRedraw(FALSE)	

ls_filter = is_init_filter


// Perform initial retrieve
IF ibo_timesheet_status.of_retrieve(ls_filter) > 0 THEN
	is_last_filter = ls_filter
END IF

idw_filter.inv_popup_data_list.of_register_column(	'active_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																
EVENT ue_redraw_buttons()
																
// Focus on first item on list
tab_container.SetRedraw(TRUE)	

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_st_timesheet_status
end type

type sle_message from w_m_filter_list`sle_message within w_st_timesheet_status
end type

type st_blank from w_m_filter_list`st_blank within w_st_timesheet_status
end type

type cb_back from w_m_filter_list`cb_back within w_st_timesheet_status
end type

type cb_save from w_m_filter_list`cb_save within w_st_timesheet_status
end type

type tab_container from w_m_filter_list`tab_container within w_st_timesheet_status
integer width = 3474
end type

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
integer width = 3401
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
integer y = 312
end type

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
string dataobject = "d_st_timesheet_status_filter"
boolean vscrollbar = false
boolean livescroll = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_st_timesheet_status 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2012/10/02
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

// initialize pop-up service
This.of_set_popup_data(TRUE)






end event

event dw_filter::destructor;call super::destructor;//************************************************************
// Object   :	w_st_timesheet_status 
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

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 420
integer width = 2949
integer height = 1540
string dataobject = "d_st_timesheet_status_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_st_timesheet_status 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2012/10/02
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

is_report_name = 'Timesheet Status'
is_program = 'STEENT'
end event

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_st_timesheet_status 
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
// Object   :	w_st_timesheet_status 
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

type uo_pin from w_m_filter_list`uo_pin within w_st_timesheet_status
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_st_timesheet_status
end type

type dw_print from w_m_filter_list`dw_print within w_st_timesheet_status
end type

type dw_buff from w_m_filter_list`dw_buff within w_st_timesheet_status
end type

type st_base from w_m_filter_list`st_base within w_st_timesheet_status
end type

