$PBExportHeader$w_st_province_tax.srw
forward
global type w_st_province_tax from w_m_filter_list
end type
end forward

global type w_st_province_tax from w_m_filter_list
integer x = 214
integer y = 221
integer width = 3017
integer height = 2232
end type
global w_st_province_tax w_st_province_tax

type variables
n_bo_province_rate			ibo_province_rate

end variables

forward prototypes
public function s_parm of_get_retrieve_args (string as_datapanel)
public function string of_getlistrecdescription (long al_row)
public subroutine of_set_book (string as_book)
end prototypes

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_st_province_tax 
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

String	ls_province
DateTime	ldt_effective, ldt_expiry

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ls_province = ibo_province_rate.of_getitemstring(idw_list.GetRow(), 'province')
	ldt_effective = ibo_province_rate.of_GetItemDateTime(idw_list.GetRow(), 'effective_date')
	ldt_expiry = ibo_province_rate.of_GetItemDateTime(idw_list.GetRow(), 'expiry_date')
ELSE
	ls_province = 'NEW RECORD *'
END IF

lstr_parm.s_parm[1] = ls_province
lstr_parm.dt_parm[1] = ldt_effective
lstr_parm.dt_parm[2] = ldt_expiry

RETURN lstr_parm
end function

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_st_province_tax 
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
String	ls_name

IF al_row > 0 THEN
	ls_name = This.idw_list.GetItemString(al_row, "province")  &
			+ "-" + f_get_province_name(This.idw_list.GetItemString(al_row, "province")) &
			+ ', effective ' + String(This.idw_list.GetItemDateTime(al_row, "effective_date"), 'yyyy.mm.dd')
END IF

RETURN ls_name
end function

public subroutine of_set_book (string as_book);
end subroutine

on w_st_province_tax.create
int iCurrent
call super::create
end on

on w_st_province_tax.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_st_province_tax 
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

Integer	li_tab

is_program				= "STIENT"
is_module 				= "S/T Province Tax"
is_datapanel_detail 	= "u_cst_st_province_rate"

// add tab
of_add_datapanel(2, is_datapanel_detail, 'Details')

//each tab retrieves a different tax type
li_tab = of_add_datapanel(3, 'u_cst_st_province_income_tax', 'Basic Tax')
IF li_tab > 0 THEN tab_container.Control[li_tab].DYNAMIC of_set_calculation_type('B')
li_tab = of_add_datapanel(4, 'u_cst_st_province_income_tax', 'Tax Reduction (S)')
IF li_tab > 0 THEN tab_container.Control[li_tab].DYNAMIC of_set_calculation_type('S')
li_tab = of_add_datapanel(5, 'u_cst_st_province_income_tax', 'Prov Surtax V1')
IF li_tab > 0 THEN tab_container.Control[li_tab].DYNAMIC of_set_calculation_type('V1')
li_tab = of_add_datapanel(6, 'u_cst_st_province_income_tax', 'Prov Surtax V2')
IF li_tab > 0 THEN tab_container.Control[li_tab].DYNAMIC of_set_calculation_type('V2')
li_tab = of_add_datapanel(7, 'u_cst_st_province_income_tax', 'Basic Personal Amount')
IF li_tab > 0 THEN tab_container.Control[li_tab].DYNAMIC of_set_calculation_type('BP')

of_add_datapanel(8, 'u_cst_st_province_education_tax', 'Employer Payroll Tax')
of_add_datapanel(9, 'u_cst_st_province_payroll_tax', 'Employee Payroll Tax')

IF NOT IsValid(ibo_province_rate) THEN
	ibo_province_rate = CREATE n_bo_province_rate
	ibo_province_rate.of_registerdata(idw_list, FALSE)
END IF	

idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_file_type', &
																'type', &
																'description', &
																TRUE, 1000, TRUE, FALSE, FALSE, "")
																
idw_filter.inv_popup_data_list.of_register_column(	'province', &
																'd_popup_prov_and_states_with_tax_entries', &
																'province', &
																'province', &
																TRUE, 900, TRUE, FALSE, FALSE, '')
	
	
RETURN
end event

event close;call super::close;//************************************************************
// Object   :	w_st_province_tax 
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

IF IsValid(ibo_province_rate) THEN DESTROY ibo_province_rate

end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_st_province_tax 
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
IF ibo_province_rate.of_retrieve(ls_filter) > 0 THEN
	is_last_filter = ls_filter
END IF

idw_filter.inv_popup_data_list.of_register_column(	'file_type', &
																'd_popup_file_type', &
																'type', &
																'description', &
																TRUE, 800, TRUE, FALSE, FALSE, "")
	
															
EVENT ue_redraw_buttons()
																
// Focus on first item on list
tab_container.SetRedraw(TRUE)	


end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_st_province_tax 
// Event    :	ue_pre_retrieve
// Author   :	Monica Petersen
// Date     :	2016/06/24
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


//When the user is coming via hot link, set file type so the detail is displayed
tab_container.tabpage_main.dw_filter.SetItem(1, 'file_type', 'C')
IF UpperBound(astr_parm.any_parm) > 0 THEN This.idw_filter.SetItem(1, "province", String(astr_parm.any_parm[1]))

RETURN
end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_st_province_tax
end type

type sle_message from w_m_filter_list`sle_message within w_st_province_tax
end type

type st_blank from w_m_filter_list`st_blank within w_st_province_tax
end type

type cb_back from w_m_filter_list`cb_back within w_st_province_tax
end type

type cb_save from w_m_filter_list`cb_save within w_st_province_tax
end type

type tab_container from w_m_filter_list`tab_container within w_st_province_tax
integer width = 3474
end type

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
integer width = 3401
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
integer y = 212
end type

type cb_print from w_m_filter_list`cb_print within tabpage_main
integer y = 212
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
integer y = 212
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer x = 5
integer width = 2939
integer height = 196
string dataobject = "d_st_province_tax_filter"
boolean vscrollbar = false
boolean livescroll = false
end type

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_st_province_tax 
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
// Object   :	w_st_province_tax 
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

event dw_filter::itemchanged;call super::itemchanged;//************************************************************
// Object   :	w_st_province_tax 
// Event    :	itemchanged
// Author   :	Monica Petersen
// Date     :	2019/12/17
// 	
// Arguments:	long row
// 				dwobject dwo
// 				string data
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


CHOOSE CASE dwo.name
	CASE 'effective_date'
		IF data < '1990-01-01' THEN
			data = '1990-01-01'
			SetText(data)
			RETURN 1
		END IF
END CHOOSE
end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer y = 316
integer width = 2949
integer height = 1644
string dataobject = "d_st_province_tax_list"
end type

event dw_list::constructor;call super::constructor;//************************************************************
// Object   :	w_st_province_tax 
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

is_report_name = 'PROVINCE TAX RATE'
is_program = 'STIENT'
end event

event dw_list::getfocus;call super::getfocus;//************************************************************
// Object   :	w_st_province_tax 
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
// Object   :	w_st_province_tax 
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

event dw_list::ue_record_deleted;//************************************************************
// Object   :	w_st_province_tax 
// Event    :	ue_record_deleted
// Author   :	Monica Petersen
// Date     :	2016/03/08
// 	
// Arguments:	long al_row
// 	
// Returns:		integer
// 	
// Desc:			Override the logic to delete the current row from the list
//             because we might just have deleted the Education child record
//					and that means we should stay on the same parent record
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF tab_container.SelectedTab < 7 THEN
	CALL super::ue_record_deleted
END IF

RETURN 1
end event

type uo_pin from w_m_filter_list`uo_pin within w_st_province_tax
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_st_province_tax
end type

type dw_print from w_m_filter_list`dw_print within w_st_province_tax
end type

type dw_buff from w_m_filter_list`dw_buff within w_st_province_tax
end type

type st_base from w_m_filter_list`st_base within w_st_province_tax
end type

