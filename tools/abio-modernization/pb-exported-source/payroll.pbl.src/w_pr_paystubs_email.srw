$PBExportHeader$w_pr_paystubs_email.srw
forward
global type w_pr_paystubs_email from w_m_filter_list
end type
end forward

global type w_pr_paystubs_email from w_m_filter_list
integer x = 214
integer y = 221
end type
global w_pr_paystubs_email w_pr_paystubs_email

type variables

n_bo_paystubs_email	ibo_paystubs_email
end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_paystubs_email 
// Function :	of_get_retrieve_args
// Author   :	Monica Petersen
// Date     :	2017/03/02
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

String	ls_attachment_type

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ls_attachment_type 	= ibo_paystubs_email.of_getitemstring(idw_list.GetRow(), 'attachment_type')
ELSE
	ls_attachment_type 	= '-1'
END IF

lstr_parm.s_parm[1] = gnv_app.is_book
lstr_parm.s_parm[2] = ls_attachment_type

RETURN lstr_parm
end function

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_paystubs_email 
// Event    :	pfc_preopen
// Author   :	Monica Petersen
// Date     :	2017/03/02
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

is_program				= "PRMAIL"
is_module 				= "P/R Paystubs Email"
is_datapanel_detail 	= "u_cst_pr_paystubs_email_detail"

// add tab
li_rc = of_add_datapanel(2, is_datapanel_detail, 'Details')

IF NOT IsValid(ibo_paystubs_email) THEN
	ibo_paystubs_email = CREATE n_bo_paystubs_email
	ibo_paystubs_email.of_registerdata(idw_list, FALSE)
END IF	

RETURN
end event

on w_pr_paystubs_email.create
int iCurrent
call super::create
end on

on w_pr_paystubs_email.destroy
call super::destroy
end on

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_paystubs_email 
// Event    :	pfc_postopen
// Author   :	Monica Petersen
// Date     :	2017/03/02
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

any 			la_extra[]
string		ls_filter

tab_container.SetRedraw(FALSE)

// Perform initial retrieve
tab_container.tabpage_main.cb_filter.EVENT Clicked()

// Focus on first item on list
idw_filter.POST SetFocus()
idw_filter.POST SetColumn("attachment_type")

tab_container.SetRedraw(TRUE)	

end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_paystubs_email 
// Event    :	ue_pre_retrieve
// Author   :	Monica Petersen
// Date     :	2017/03/02
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

IF UpperBound(astr_parm.s_parm) = 2 THEN
	This.idw_filter.SetItem(1, "attachment_type", String(astr_parm.s_parm[1]))
END IF

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_pr_paystubs_email
end type

type sle_message from w_m_filter_list`sle_message within w_pr_paystubs_email
end type

type st_blank from w_m_filter_list`st_blank within w_pr_paystubs_email
end type

type cb_back from w_m_filter_list`cb_back within w_pr_paystubs_email
end type

type cb_save from w_m_filter_list`cb_save within w_pr_paystubs_email
end type

type tab_container from w_m_filter_list`tab_container within w_pr_paystubs_email
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
integer y = 196
end type

type cb_print from w_m_filter_list`cb_print within tabpage_main
integer y = 196
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer y = 196
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer height = 172
string dataobject = "d_pr_paystubs_filter"
boolean vscrollbar = false
end type

event dw_filter::ue_get_extra;call super::ue_get_extra;//************************************************************
// Object   :	w_paystubs_email 
// Event    :	ue_get_extra
// Author   :	Monica Petersen
// Date     :	2017/03/02
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

is_extra_filter =  " paystubs_email.book = '" + trim(gnv_app.is_book) + "'"

RETURN is_extra_filter

end event

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_paystubs_email 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2017/06/13
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

RETURN 1

end event

event dw_filter::destructor;call super::destructor;//************************************************************
// Object   :	w_paystubs_email 
// Event    :	destructor
// Author   :	Monica Petersen
// Date     :	2017/06/13
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
This.of_set_popup_data(FALSE)

RETURN 1

end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 300
integer height = 1660
string dataobject = "d_pr_paystubs_email_list"
end type

type uo_pin from w_m_filter_list`uo_pin within w_pr_paystubs_email
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_pr_paystubs_email
end type

type dw_print from w_m_filter_list`dw_print within w_pr_paystubs_email
end type

type dw_buff from w_m_filter_list`dw_buff within w_pr_paystubs_email
end type

type p_progress_gif from w_m_filter_list`p_progress_gif within w_pr_paystubs_email
integer y = 792
integer width = 2062
integer height = 1168
end type

type st_base from w_m_filter_list`st_base within w_pr_paystubs_email
end type

