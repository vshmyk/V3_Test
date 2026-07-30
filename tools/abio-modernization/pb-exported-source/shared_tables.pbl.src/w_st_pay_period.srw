$PBExportHeader$w_st_pay_period.srw
forward
global type w_st_pay_period from w_m_filter_list
end type
end forward

global type w_st_pay_period from w_m_filter_list
integer x = 214
integer y = 221
end type
global w_st_pay_period w_st_pay_period

type variables
n_bo_pay_period	ibo_pay_period
end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_st_pay_period 
// Function :	of_get_retrieve_args
// Author   :	Viktar Shmyk
// Date     :	2013/03/11
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


String	ls_pay_period_type, &
			ls_year
Long 		ll_row
s_parm	lstr_parm

ll_row = idw_list.GetRow()

IF ll_row > 0 THEN
	ls_pay_period_type = ibo_pay_period.of_getitemstring(ll_row , 'pay_period_type')
	ls_year = ibo_pay_period.of_getitemstring(ll_row , 'year')
ELSE
	ls_pay_period_type = 'NEW RECORD *'
END IF



lstr_parm.s_parm[1] = ls_pay_period_type
lstr_parm.s_parm[2] = ls_year



RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_st_pay_period 
// Function :	of_getlistrecdescription
// Author   :	Monica Petersen
// Date     :	2013/08/30
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


String	ls_pp_type, &
			ls_description, &
			ls_title

IF al_row > 0 THEN
	ls_pp_type = This.idw_list.GetItemString(al_row, "pay_period_type")
	CHOOSE CASE ls_pp_type
		CASE 'W'
			ls_description = 'weekly'
		CASE 'B'
			ls_description = 'bi-weekly'
		CASE 'M'
			ls_description = 'monthly'
		CASE 'S'
			ls_description = 'semi-monthly'
	END CHOOSE
	ls_title =  ls_description + ', year ' + This.idw_list.GetItemString(al_row, "year")
END IF

RETURN ls_title
end function

on w_st_pay_period.create
int iCurrent
call super::create
end on

on w_st_pay_period.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_st_pay_period 
// Event    :	pfc_preopen
// Author   :	Viktar Shmyk
// Date     :	2013/03/11
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


integer li_det_tab

ibo_pay_period = CREATE n_bo_pay_period
ibo_pay_period.of_SetTransaction()

is_module 					= "S/T Pay period Start"				// Window name

This.is_program 			= "STWENT"
idw_list.is_program 		= This.is_program					// Program for the list datawindow
idw_list.is_report_name = "PAY PERIOD START DATE"		// Report name for the list datawindow

is_datapanel_detail 	= "u_cst_st_pay_period_detail"  	// User Object for the Details tab
of_add_datapanel(2, is_datapanel_detail, 'Details')  	// Add details tab (user object, label)

ibo_pay_period.of_registerdata(idw_list, FALSE)		 	// Associate BO with the list

idw_filter.SetItem(1, "file_type", "C")

idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_file_type', &
																'type', &
																'description', &
																TRUE, 1000, TRUE, FALSE, FALSE, "")
																

end event

event close;call super::close;//************************************************************
// Object   :	w_st_pay_period 
// Event    :	close
// Author   :	Viktar Shmyk
// Date     :	2013/03/11
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

IF IsValid(ibo_pay_period) THEN Destroy ibo_pay_period
end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_st_pay_period 
// Event    :	pfc_postopen
// Author   :	Viktar Shmyk
// Date     :	2013/03/11
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

tab_container.tabpage_main.cb_filter.EVENT Clicked()

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_st_pay_period
end type

type sle_message from w_m_filter_list`sle_message within w_st_pay_period
end type

type st_blank from w_m_filter_list`st_blank within w_st_pay_period
end type

type cb_back from w_m_filter_list`cb_back within w_st_pay_period
end type

type cb_save from w_m_filter_list`cb_save within w_st_pay_period
end type

type tab_container from w_m_filter_list`tab_container within w_st_pay_period
end type

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
integer y = 192
end type

type cb_print from w_m_filter_list`cb_print within tabpage_main
integer y = 192
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer y = 192
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer height = 172
string dataobject = "d_st_pay_period_filter"
boolean vscrollbar = false
boolean livescroll = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_st_pay_period 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2013/08/30
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
// Object   :	w_st_pay_period 
// Event    :	destructor
// Author   :	Monica Petersen
// Date     :	2013/08/30
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

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 300
integer height = 1652
string dataobject = "d_st_pay_period_list"
end type

type uo_pin from w_m_filter_list`uo_pin within w_st_pay_period
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_st_pay_period
end type

type dw_print from w_m_filter_list`dw_print within w_st_pay_period
end type

type dw_buff from w_m_filter_list`dw_buff within w_st_pay_period
end type

type st_base from w_m_filter_list`st_base within w_st_pay_period
end type

