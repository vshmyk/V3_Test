$PBExportHeader$w_tb_trade_union.srw
forward
global type w_tb_trade_union from w_m_filter_list
end type
end forward

global type w_tb_trade_union from w_m_filter_list
integer width = 2871
integer height = 2488
end type
global w_tb_trade_union w_tb_trade_union

type variables
n_bo_trade_union		ibo_trade_union
end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_tb_trade_union 
// Function :	of_get_retrieve_args
// Author   :	Viktar Shmyk
// Date     :	2009/04/18
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

String	ls_trade_union_description
String	ls_book
String	ls_trade_union
s_parm	lstr_parm

ls_book = gnv_app.is_book

IF idw_list.GetRow() > 0 THEN
	ls_trade_union = ibo_trade_union.of_getitemstring(idw_list.GetRow(), 'trade_union')	
	ls_trade_union_description = ibo_trade_union.of_getitemstring(idw_list.GetRow(), 'description')	
ELSE
	ls_trade_union = '-1'
	ls_trade_union_description = 'NEW RECORD *'
END IF

lstr_parm.s_parm[1] = ls_book
lstr_parm.s_parm[2] = ls_trade_union
lstr_parm.s_parm[3] = ls_trade_union_description

RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_am_trade_union 
// Function :	of_getlistrecdescription
// Author   :	Paul Bauermeister
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
	ls_name = This.idw_list.GetItemString(al_row, "trade_union") + &
			"-" + This.idw_list.GetItemString(al_row, "description")
END IF

RETURN ls_name

end function

on w_tb_trade_union.create
int iCurrent
call super::create
end on

on w_tb_trade_union.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_tb_trade_union 
// Event    :	pfc_preopen
// Author   :	Viktar Shmyk
// Date     :	2009/04/18
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


This.is_program = "TBEENT"
This.is_module = "P/R Union"
This.is_datapanel_detail = "u_cst_trade_union_detail"
This.is_init_filter = "active_flag = 'Y"
idw_filter.SetItem(1, "active_flag", 'Y')

// Create data panels
This.of_add_datapanel(2, is_datapanel_detail, 'Details')
This.of_add_datapanel(3, "u_cst_trade_union_rate_tab", "Rates")

// Create business object
ibo_trade_union = CREATE n_bo_trade_union		
ibo_trade_union.of_SetTransaction()
ibo_trade_union.of_registerdata(idw_list, FALSE)

idw_filter.inv_popup_data_list.of_register_column(	'premium', &
																'd_popup_premium_type', &
																'premium_type', &
																'description', &
																400, TRUE, FALSE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'province', &
																'd_popup_province', &
																'province', &
																'description', &
																400, TRUE, FALSE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'active_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																
idw_filter.inv_popup_data_list.of_register_column(	'staff_flag', &
																'd_popup_yes_no', &
																'status', &
																'status', &
																TRUE, 700, TRUE, TRUE, TRUE)
																
gnv_synchronize.uf_register_interest("FOCUS_PREMIUM_RATES_TAB", iw_parent)																
gnv_synchronize.uf_register_interest("FOCUS_TRADE_BENEFITS_TAB", iw_parent)		

end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_hr_person 
// Event    :	pfc_postopen
// Author   :	Viktar Shmyk
// Date     :	2009/02/16
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

tab_container.tabpage_main.cb_filter.EVENT Clicked()

This.EVENT ue_redraw_buttons()

end event

event pfc_preclose;call super::pfc_preclose;//************************************************************
// Object   :	w_tb_trade_union 
// Event    :	pfc_preclose
// Author   :	Viktar Shmyk
// Date     :	2009/04/18
// 	
// Arguments:	(None)
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


this.inv_preference.of_SetPosSize( )
IF gnv_app.of_IsRegistryAvailable()  THEN
	this.inv_preference.of_Save("HKEY_CURRENT_USER\Software\abio\w_tb_trade_union")
ELSE
	this.inv_preference.of_Save(gnv_app.of_GetAppINIFile())
END IF

RETURN AncestorReturnValue
end event

event close;call super::close;//************************************************************
// Object   :	w_tb_trade_union 
// Event    :	close
// Author   :	Paul Bauermeister
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

IF IsValid(This.ibo_trade_union) THEN DESTROY This.ibo_trade_union

gnv_synchronize.uf_remove_interest("FOCUS_PREMIUM_RATES_TAB", iw_parent)	
gnv_synchronize.uf_remove_interest("FOCUS_TRADE_BENEFITS_TAB", iw_parent)	

end event

event ue_redraw_buttons;call super::ue_redraw_buttons;//************************************************************
// Object   :	w_am_trade_union
// Event    :	ue_redraw_buttons
// Author   :	Paul Bauermeister
// Date     :	2009/05/12
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			If there are no rows in the list, disable all 
//					tabs other than the detail tab
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

tab_container.Control[3].Enabled = (This.idw_list.RowCount() > 0)

end event

event ue_event_synchronize;call super::ue_event_synchronize;//************************************************************
// Object   :	w_tb_trade_union 
// Event    :	ue_event_synchronize
// Author   :	Lourdes Garcia
// Date     :	2011/09/29
// 	
// Arguments:	string as_event_id
// 				s_parm astr_parm
// 	
// Returns:		integer
// 	
// Desc:			Synchornize Events
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
Long  			ll_employee, & 
					ll_tax_year, &
					ll_count, &
					ll_row

s_parm 			lstr_parm
					
UserObject		lou_datapanel

CHOOSE CASE as_event_id
	CASE "FOCUS_PREMIUM_RATES_TAB"
		lou_datapanel = of_get_datapanel('u_cst_trade_union_rate_tab')
		IF IsValid(lou_datapanel) THEN 
			tab_container.SelectTab(of_getdatapanelindex(lou_datapanel))
			gnv_synchronize.POST uf_event_trigger('FOCUS_PREMIUM_TAB', lstr_parm)
		END IF

			
	CASE "FOCUS_TRADE_BENEFITS_TAB"
		lou_datapanel = of_get_datapanel('u_cst_trade_union_rate_tab')
		IF IsValid(lou_datapanel) THEN 
			tab_container.SelectTab(of_getdatapanelindex(lou_datapanel))
			gnv_synchronize.POST uf_event_trigger('FOCUS_BENEFIT_TAB', lstr_parm)
		END IF

		
		
END CHOOSE
		
RETURN 1

end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_tb_trade_union 
// Event    :	ue_pre_retrieve
// Author   :	Monica Petersen
// Date     :	2013/05/03
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

This.idw_filter.SetItem(1, "trade_union", String(astr_parm.any_parm[1]))
end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_tb_trade_union
integer y = 2276
end type

type sle_message from w_m_filter_list`sle_message within w_tb_trade_union
integer x = 855
integer y = 2268
end type

type st_blank from w_m_filter_list`st_blank within w_tb_trade_union
integer y = 2284
end type

type cb_back from w_m_filter_list`cb_back within w_tb_trade_union
integer y = 2272
end type

type cb_save from w_m_filter_list`cb_save within w_tb_trade_union
integer x = 2514
integer y = 2276
end type

type tab_container from w_m_filter_list`tab_container within w_tb_trade_union
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
integer y = 164
end type

type cb_print from w_m_filter_list`cb_print within tabpage_main
integer x = 338
integer y = 164
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer x = 9
integer y = 164
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer width = 2784
integer height = 140
string dataobject = "d_tb_trade_union_filter"
boolean vscrollbar = false
boolean ib_isentertab = false
end type

event dw_filter::ue_get_extra;call super::ue_get_extra;//************************************************************
// Object   :	w_tb_trade_union 
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

String	ls_premium_type

is_extra_filter =  " book = '" + gnv_app.is_book + "'"

//Allow the user to search the premium field in the trade_union_premium table
ls_premium_type = this.GetItemString(1, 'premium')
IF ls_premium_type <> '' THEN
	is_extra_filter += "  AND EXISTS (SELECT * " &
						 +  "                FROM trade_union_premium  " &
						 +  "               WHERE trade_union_premium.book 				= trade_union.book " &
						 +  "                 AND trade_union_premium.trade_union 		= trade_union.trade_union " &
						 +  "                 AND trade_union_premium.premium_type LIKE '%" + ls_premium_type + "%')"
END IF

RETURN is_extra_filter
end event

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_tb_trade_union 
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
idw_filter.of_set_popup_data(TRUE)

end event

event dw_filter::destructor;call super::destructor;idw_filter.of_set_popup_data(FALSE)

end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 272
integer width = 2793
integer height = 1948
string dataobject = "d_tb_trade_union_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_tb_trade_union 
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

This.is_report_name = "Trade Union List"
This.is_program = 'TBEENT'

end event

type uo_pin from w_m_filter_list`uo_pin within w_tb_trade_union
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_tb_trade_union
integer y = 2272
end type

type dw_print from w_m_filter_list`dw_print within w_tb_trade_union
end type

type dw_buff from w_m_filter_list`dw_buff within w_tb_trade_union
end type

type p_progress_gif from w_m_filter_list`p_progress_gif within w_tb_trade_union
end type

type st_base from w_m_filter_list`st_base within w_tb_trade_union
integer x = 2144
integer y = 52
end type

