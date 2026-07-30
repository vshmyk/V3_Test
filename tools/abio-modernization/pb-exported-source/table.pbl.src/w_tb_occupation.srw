$PBExportHeader$w_tb_occupation.srw
forward
global type w_tb_occupation from w_m_filter_list
end type
end forward

global type w_tb_occupation from w_m_filter_list
integer width = 2866
integer height = 2496
end type
global w_tb_occupation w_tb_occupation

type variables
n_bo_occupation		ibo_occupation
end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public function integer of_retrieve (s_parm astr_parm)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_tb_occupation 
// Function :	of_get_retrieve_args
// Author   :	Viktar Shmyk
// Date     :	2010/10/18
// 	
// Arguments:	string as_datapanel
// 	
// Returns:		s_parm
// 	
// Desc:			Get parameters that will be used as retrieval arguments
//					in other datapanels.
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_occupation_description
String	ls_book
String	ls_trade_union
String	ls_occupation
Long		ll_row
s_parm	lstr_parm


ls_book 	= gnv_app.is_book
ll_row 	= idw_list.GetRow()

IF idw_list.GetRow() > 0 THEN
	ls_trade_union = ibo_occupation.of_getitemstring(ll_row, 'trade_union')	
	ls_occupation = ibo_occupation.of_getitemstring(ll_row, 'occupation')	
	ls_occupation_description = ibo_occupation.of_getitemstring(ll_row, 'description')	
ELSE
	ls_occupation = '-1'
	ls_occupation_description = 'NEW RECORD *'
END IF

lstr_parm.s_parm[1] = ls_book
lstr_parm.s_parm[2] = ls_trade_union
lstr_parm.s_parm[3] = ls_occupation
lstr_parm.s_parm[4] = ls_occupation_description

RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_am_occupation 
// Function :	of_getlistrecdescription
// Author   :	V. Shmyk
// Date     :	2009/05/12
// 	
// Arguments:	long al_row
// 	
// Returns:		string
// 	
// Desc:			Return the record specific value that will be 
//					used as part of the window title
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_name

IF al_row > 0 THEN
	ls_name = This.idw_list.GetItemString(al_row, "trade_union") 		&
					+ '-' + f_get_trade_union_desc(idw_list.GetItemString(al_row, 'trade_union')) &
					+ ', occupation ' + This.idw_list.GetItemString(al_row, "occupation") 
END IF

RETURN ls_name

end function

public function integer of_retrieve (s_parm astr_parm);//************************************************************
// Object   :	w_tb_occupation 
// Function :	of_retrieve
// Author   :	Viktar Shmyk
// Date     :	2011/09/28
// 	
// Arguments:	s_parm astr_parm
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
String	ls_tab
String	ls_tab_filter
s_parm	lstr_parm

SUPER::of_retrieve(astr_parm)


IF UpperBound(astr_parm.po_parm) > 0 THEN
	lstr_parm = astr_parm.po_parm[1]
	
	IF UpperBound(lstr_parm.s_parm) > 1 THEN
		ls_tab = lstr_parm.s_parm[1]
		ls_tab_filter = lstr_parm.s_parm[2]
	END IF
	
END IF

IF Upper(ls_tab) = 'RATES' AND UpperBound(tab_container.Control) >= 3 THEN
	tab_container.SelectTab(3)
END IF

RETURN 1
end function

on w_tb_occupation.create
int iCurrent
call super::create
end on

on w_tb_occupation.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_tb_occupation 
// Event    :	pfc_preopen
// Author   :	Viktar Shmyk
// Date     :	2010/10/18
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

Integer	li_det_tab


This.is_program = "TBPENT"
This.is_module = "P/R Occupation"
This.is_datapanel_detail = "u_cst_tb_occupation_detail"
This.is_init_filter = ""
This.ib_iskeyautofill = FALSE

// Create data panels
This.of_add_datapanel(2, is_datapanel_detail, 'Details')
This.of_add_datapanel(3, 'u_cst_tb_occupation_rate', 'Rates')
This.of_add_datapanel(4, 'u_cst_tb_occupation_rate_list', 'List')


// Create business object
ibo_occupation = CREATE n_bo_occupation		
ibo_occupation.of_SetTransaction()
ibo_occupation.of_registerdata(idw_list, FALSE)


end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_tb_occupation 
// Event    :	pfc_postopen
// Author   :	Viktar Shmyk
// Date     :	2010/10/29
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
//
// Desc:			Initial retrieve of default datapanel
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

tab_container.SetRedraw(FALSE)	


// Initial filtering criteria
idw_filter.SetItem(1, "active_flag", "Y")
idw_filter.SetItem(1, "latest_rate_flag", "Y")
This.is_init_filter = "latest_rate_flag = 'Y' AND active_flag = 'Y' AND " + &
		idw_filter.EVENT DYNAMIC ue_get_extra()
IF ibo_occupation.of_retrieve(is_init_filter) > 0 THEN
	is_last_filter = is_init_filter
END IF

This.EVENT ue_redraw_buttons()

tab_container.tabpage_main.cb_filter.EVENT Clicked()

idw_filter.inv_popup_data_list.of_register_column(	'latest_rate_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)

idw_filter.inv_popup_data_list.of_register_column(	'active_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)

tab_container.SetRedraw(TRUE)	

RETURN
end event

event close;call super::close;//************************************************************
// Object   :	w_tb_occupation 
// Event    :	close
// Author   :	V. Shmyk
// Date     :	2009/05/12
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Destroy objects
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF IsValid(This.ibo_occupation) THEN DESTROY This.ibo_occupation



end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_tb_occupation 
// Event    :	ue_pre_retrieve
// Author   :	Monica Petersen
// Date     :	2011/12/06
// 	
// Arguments:	s_parm astr_parm
// 	
// Returns:		(None)
// 	
// Desc:			Set the trade union and occupation filter value from the specified 
//					parameter
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

This.idw_filter.SetItem(1, "trade_union", String(astr_parm.any_parm[1]))
This.idw_filter.SetItem(1, 'occupation', String(astr_parm.any_parm[2]))



end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_tb_occupation
integer y = 2276
end type

type sle_message from w_m_filter_list`sle_message within w_tb_occupation
integer x = 910
integer y = 2280
end type

type st_blank from w_m_filter_list`st_blank within w_tb_occupation
integer y = 2284
end type

type cb_back from w_m_filter_list`cb_back within w_tb_occupation
integer y = 2272
end type

type cb_save from w_m_filter_list`cb_save within w_tb_occupation
integer y = 2272
end type

type tab_container from w_m_filter_list`tab_container within w_tb_occupation
integer width = 2885
integer height = 2256
end type

on tab_container.create
call super::create
this.Control[]={this.tabpage_main}
end on

on tab_container.destroy
call super::destroy
end on

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
integer width = 2811
integer height = 2224
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
integer y = 240
end type

type cb_print from w_m_filter_list`cb_print within tabpage_main
integer x = 338
integer y = 240
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer x = 9
integer y = 240
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer width = 2784
integer height = 220
string dataobject = "d_tb_occupation_filter"
boolean vscrollbar = false
boolean livescroll = false
boolean ib_isentertab = false
end type

event dw_filter::ue_get_extra;call super::ue_get_extra;//************************************************************
// Object   :	w_tb_occupation 
// Event    :	ue_get_extra
// Author   :	Viktar Shmyk
// Date     :	2009/09/07
// 	
// Arguments:	(None)
// 	
// Returns:		string
// 	
// Desc:			Default filter
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
String ls_extra
Date ld_from, ld_to

ls_extra = " book = '" + gnv_app.is_book + "'"
ld_from = GetItemDate(1, "effective_date_from")
ld_to = GetItemDate(1, "effective_date_to")

IF Year(ld_from) > 1900 THEN
	ls_extra = ls_extra + " AND effective_date >= '" + String(ld_from, "yyyy-mm-dd") + "'"
ELSE
	IF Year(ld_to) > 1900 THEN
		ls_extra = ls_extra + " AND effective_date <= '" + String(ld_to, "yyyy-mm-dd") + "'"
	END IF
END IF

IF Year(ld_to) > 1900 THEN
	ls_extra = ls_extra + " AND expiry_date <= '" + String(ld_to, "yyyy-mm-dd") + "'"
ELSE
	IF Year(ld_from) > 1900 THEN
		ls_extra = ls_extra + " AND expiry_date >= '" + String(ld_from, "yyyy-mm-dd") + "'"
	END IF
END IF


RETURN ls_extra 
end event

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_tb_occupation 
// Event    :	constructor
// Author   :	Viktar Shmyk
// Date     :	2009/09/07
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

This.ib_isentertab = TRUE
this.of_set_popup_data(TRUE)

RETURN
end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 348
integer width = 2793
integer height = 1868
string dataobject = "d_tb_occupation_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_tb_occupation 
// Event    :	constructor
// Author   :	Viktar Shmyk
// Date     :	2009/09/07
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Set program 
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

This.is_report_name = "P/R Occupation List"
This.is_program = 'TBPENT'

end event

event dw_list::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	w_tb_occupation 
// Function :	ue_preprint
// Author   :	Viktar Shmyk
// Date     :	2010/12/09
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

Datawindow ldw_null
n_ds lds_print
s_parm lstr_parms
String	ls_whereclause
String	ls_sql
String	ls_subtitle
n_ds 		lds_export
lds_export = CREATE n_ds 

lds_export.DataObject = "d_tb_occupation_rate_exp"

ls_whereclause = idw_list.ibo_business.of_getlastwhereclause()

ls_sql = lds_export.GetSQLSelect()

ls_sql = ls_sql + " AND " + ls_whereclause + " ORDER BY occupation.occupation, effective_date, occupation.trade "

lds_export.SetSQLSelect(ls_sql)

lds_export.SetTransObject(SQLCA)

lds_export.Retrieve()

astr_preview.ds_export[1] = lds_export


// customize print
SetNull(ldw_null)

lstr_parms = dw_filter.of_get_filter_data()

lds_print = CREATE n_ds 

lds_print.DataObject = 'd_tb_occupation_list'
lds_print.SetTransObject(SQLCA)



idw_list.RowsCopy(1, idw_list.RowCount(), Primary!, lds_print, 1, Primary!)

ls_subtitle = Upper(lstr_parms.s_parm[2])


SELECT Replace(:ls_subtitle, '"', '') INTO :ls_subtitle 
FROM (SELECT 1 as a) book USING SQLCA;

astr_preview.dw_preview	= ldw_null
astr_preview.ds_preview = lds_print
astr_preview.s_parm[1] = 'LIST'
astr_preview.s_sub_title = lstr_parms.s_parm[2]

	

RETURN 1

end event

type uo_pin from w_m_filter_list`uo_pin within w_tb_occupation
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_tb_occupation
integer y = 2272
end type

type dw_print from w_m_filter_list`dw_print within w_tb_occupation
end type

type dw_buff from w_m_filter_list`dw_buff within w_tb_occupation
end type

type p_progress_gif from w_m_filter_list`p_progress_gif within w_tb_occupation
end type

type st_base from w_m_filter_list`st_base within w_tb_occupation
integer x = 955
integer y = 2292
end type

