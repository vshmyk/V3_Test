$PBExportHeader$w_st_premium_type.srw
forward
global type w_st_premium_type from w_m_filter_list
end type
end forward

global type w_st_premium_type from w_m_filter_list
integer width = 3017
integer height = 2232
end type
global w_st_premium_type w_st_premium_type

type variables
n_bo_premium_type			ibo_premium_type

end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public subroutine of_set_book (string as_book)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_st_premium_type 
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

String	ls_premium_type, &
			ls_description

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ls_premium_type = ibo_premium_type.of_getitemstring(idw_list.GetRow(), 'premium_type')
	ls_description = ibo_premium_type.of_getitemstring(idw_list.GetRow(), 'description')
ELSE
	ls_premium_type = 'NEW RECORD *'
END IF



lstr_parm.s_parm[1] = ls_premium_type
lstr_parm.s_parm[2] = ls_description



RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_st_premium_type 
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
	ls_title = idw_list.GetItemString(al_row, 'premium_type') + '-' + idw_list.GetItemString(al_row, 'description')
END IF

RETURN ls_title
end function

public subroutine of_set_book (string as_book);
end subroutine

on w_st_premium_type.create
int iCurrent
call super::create
end on

on w_st_premium_type.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_st_premium_type 
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



is_program				= "STRENT"
is_module 				= "S/T Premium Type"
is_datapanel_detail 	= "u_cst_st_premium_type"

// add tab
of_add_datapanel(2, is_datapanel_detail, 'Details')
of_add_datapanel(3, 'u_cst_st_premium_type_book', 'Books')

IF NOT IsValid(ibo_premium_type) THEN
	ibo_premium_type = CREATE n_bo_premium_type
	ibo_premium_type.of_registerdata(idw_list, FALSE)
END IF	


end event

event close;call super::close;//************************************************************
// Object   :	w_st_premium_type 
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

IF IsValid(ibo_premium_type) THEN DESTROY ibo_premium_type

end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_st_premium_type 
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
s_parm lstr_parms

tab_container.SetRedraw(FALSE)	

// Initial filtering criteria
idw_filter.SetItem(1, "active_flag", "Y")
This.is_init_filter = "active_flag = 'Y'"

ls_filter = is_init_filter


// Perform initial retrieve
IF ibo_premium_type.of_retrieve(ls_filter) > 0 THEN
	is_last_filter = ls_filter
END IF

idw_filter.inv_popup_data_list.of_register_column(	'active_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																

idw_filter.inv_popup_data_list.of_register_column(	'employee_specific_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																

idw_filter.inv_popup_data_list.of_register_column(	'timesheet_override_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																

idw_filter.inv_popup_data_list.of_register_column(	'earning_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																

EVENT ue_redraw_buttons()
																
tab_container.SetRedraw(TRUE)	

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_st_premium_type
end type

type sle_message from w_m_filter_list`sle_message within w_st_premium_type
end type

type st_blank from w_m_filter_list`st_blank within w_st_premium_type
end type

type cb_back from w_m_filter_list`cb_back within w_st_premium_type
end type

type cb_save from w_m_filter_list`cb_save within w_st_premium_type
end type

type tab_container from w_m_filter_list`tab_container within w_st_premium_type
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
string dataobject = "d_st_premium_type_filter"
boolean vscrollbar = false
boolean livescroll = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_st_premium_type 
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






end event

event dw_filter::destructor;call super::destructor;//************************************************************
// Object   :	w_st_premium_type 
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
string dataobject = "d_st_premium_type_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_st_premium_type 
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

is_report_name = 'PREMIUM TYPE'
is_program = 'STRENT'
end event

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_st_premium_type 
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
// Object   :	w_st_premium_type 
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

event dw_list::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	w_st_premium_type 
// Event    :	ue_preprint
// Author   :	Lourdes Garcia
// Date     :	2011/12/21
// 	
// Arguments:	s_preview astr_preview
// 	
// Returns:		integer
// 	
// Desc:			Change export datawindow
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
s_parm lstr_parms
String	ls_whereclause
String	ls_sql
n_ds 		lds_export

lds_export = CREATE n_ds 
lds_export.DataObject = "d_st_premium_type_list_exp"
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

type uo_pin from w_m_filter_list`uo_pin within w_st_premium_type
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_st_premium_type
end type

type dw_print from w_m_filter_list`dw_print within w_st_premium_type
end type

type dw_buff from w_m_filter_list`dw_buff within w_st_premium_type
end type

type st_base from w_m_filter_list`st_base within w_st_premium_type
end type

