$PBExportHeader$w_st_federal_tax.srw
forward
global type w_st_federal_tax from w_m_filter_list
end type
end forward

global type w_st_federal_tax from w_m_filter_list
integer width = 3017
integer height = 2232
end type
global w_st_federal_tax w_st_federal_tax

type variables
n_bo_federal_tax			ibo_federal_tax

end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public subroutine of_set_book (string as_book)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_st_federal_tax 
// Function :	of_get_retrieve_args
// Author   :	Monica Petersen
// Date     :	2012/10/03
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

DateTime	ldt_effective

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ldt_effective = ibo_federal_tax.of_GetItemDateTime(idw_list.GetRow(), 'effective_date')
END IF

lstr_parm.dt_parm[1] = ldt_effective

RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_st_federal_tax 
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
	ls_title = String(idw_list.GetItemDateTime(al_row, 'effective_date'), 'yyyy.mm.dd')
END IF

RETURN ls_title
end function

public subroutine of_set_book (string as_book);
end subroutine

on w_st_federal_tax.create
int iCurrent
call super::create
end on

on w_st_federal_tax.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_st_federal_tax 
// Event    :	pfc_preopen
// Author   :	Monica Petersen
// Date     :	2012/10/03
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

is_program				= "STAENT"
is_module 				= "S/T Federal Tax"
is_datapanel_detail 	= "u_cst_st_federal_tax"

// add tab
li_rc = of_add_datapanel(2, is_datapanel_detail, 'Details')

IF NOT IsValid(ibo_federal_tax) THEN
	ibo_federal_tax = CREATE n_bo_federal_tax
	ibo_federal_tax.of_registerdata(idw_list, FALSE)
END IF	

idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_file_type', &
																'type', &
																'description', &
																TRUE, 1000, TRUE, FALSE, FALSE, "")
																	
RETURN
end event

event close;call super::close;//************************************************************
// Object   :	w_st_federal_tax 
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

IF IsValid(ibo_federal_tax) THEN DESTROY ibo_federal_tax

end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_st_federal_tax 
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

// Initial filtering criteria
idw_filter.SetItem(1, "file_type", "C")
This.is_init_filter = "file_type = 'C'"

ls_filter = is_init_filter

// Perform initial retrieve
IF ibo_federal_tax.of_retrieve(ls_filter) > 0 THEN
	is_last_filter = ls_filter
END IF

EVENT ue_redraw_buttons()
																
// Focus on first item on list
idw_filter.POST SetFocus()
idw_filter.POST SetColumn("effective_date")

//idw_list.EVENT ue_processenter()

tab_container.SetRedraw(TRUE)	

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_st_federal_tax
end type

type sle_message from w_m_filter_list`sle_message within w_st_federal_tax
end type

type st_blank from w_m_filter_list`st_blank within w_st_federal_tax
end type

type cb_back from w_m_filter_list`cb_back within w_st_federal_tax
end type

type cb_save from w_m_filter_list`cb_save within w_st_federal_tax
end type

type tab_container from w_m_filter_list`tab_container within w_st_federal_tax
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
string dataobject = "d_st_federal_tax_filter"
boolean vscrollbar = false
boolean livescroll = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_st_federal_tax 
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

This.of_SetDropDownCalendar(TRUE)
This.iuo_calendar.of_Register("effective_date", This.iuo_calendar.NONE)






end event

event dw_filter::destructor;call super::destructor;//************************************************************
// Object   :	w_st_federal_tax 
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

IF dwo.name = "b_calendar_effective_date" THEN
	IF This.SetColumn("effective_date") = 1 THEN
		This.EVENT pfc_DDCalendar()
	END IF
END IF



end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 420
integer width = 2949
integer height = 1540
string dataobject = "d_st_federal_tax_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_st_federal_tax 
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

is_report_name = 'FEDERAL TAX RATE'
is_program = 'STAENT'
end event

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_st_federal_tax 
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
// Object   :	w_st_federal_tax 
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

type uo_pin from w_m_filter_list`uo_pin within w_st_federal_tax
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_st_federal_tax
end type

type dw_print from w_m_filter_list`dw_print within w_st_federal_tax
end type

type dw_buff from w_m_filter_list`dw_buff within w_st_federal_tax
end type

type st_base from w_m_filter_list`st_base within w_st_federal_tax
end type

