$PBExportHeader$w_st_crew.srw
forward
global type w_st_crew from w_m_filter_list
end type
end forward

global type w_st_crew from w_m_filter_list
integer width = 3424
integer height = 2236
end type
global w_st_crew w_st_crew

type variables
Private:
  n_bo_crew  ibo_crew
end variables

forward prototypes
public function string of_getlistrecdescription (long al_row)
public function s_parm of_get_retrieve_args (string as_datapanel)
end prototypes

public function string of_getlistrecdescription (long al_row);//************************************************************
// Object   :	w_st_crew 
// Function :	of_getlistrecdescription
// Author   :	Viktar Shmyk
// Date     :	2009/11/10
// 	
// Arguments:	long al_row
// 	
// Returns:		string
// 	
// Desc:			Build a string describing specifying record in the list
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_title

ls_title = ''
IF al_row > 0 THEN
	ls_title = idw_list.GetItemString(al_row, 'job_or_region') &
					+ '-' + f_get_job_desc(gnv_app.is_book, idw_list.GetItemString(al_row, 'job_or_region')) &
					+ ', crew ' + idw_list.GetItemString(al_row, 'crew') 
END IF

RETURN ls_title
end function

public function s_parm of_get_retrieve_args (string as_datapanel);//************************************************************
// Object   :	w_st_crew 
// Function :	of_get_retrieve_args
// Author   :	Monica Petersen
// Date     :	2014/04/18
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

String	ls_job, &
			ls_crew

s_parm	lstr_parm

IF idw_list.GetRow() > 0 THEN
	ls_job = ibo_crew.of_getitemstring(idw_list.GetRow(), 'job_or_region')
	ls_crew = ibo_crew.of_getitemstring(idw_list.GetRow(), 'crew')
ELSE
	ls_job = 'NEW RECORD *'
END IF



lstr_parm.s_parm[1] = ls_job
lstr_parm.s_parm[2] = ls_crew
lstr_parm.s_parm[3] = idw_filter.GetItemString(1, 'current_members_flag')



RETURN lstr_parm
end function

on w_st_crew.create
int iCurrent
call super::create
end on

on w_st_crew.destroy
call super::destroy
end on

event pfc_preopen;call super::pfc_preopen;//************************************************************
// Object   :	w_st_crew 
// Event    :	pfc_preopen
// Author   :	Viktar Shmyk
// Date     :	2009/11/06
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			Populate tabs, set instance variables
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

integer li_det_tab

ibo_crew = CREATE n_bo_crew



is_module 					= "S/T Crew"	// Window name

This.is_program 			= "STJENT"
idw_list.is_program 		= This.is_program		// Program for the list datawindow
idw_list.is_report_name = "CREW"	// Report name for the list datawindow

ib_iskeyautofill 		= FALSE  				// If the key fields in the details tab need to be autofilled 

is_datapanel_detail 	= "u_cst_st_crew_detail"  // User Object for the Details tab
of_add_datapanel(2, is_datapanel_detail, 'Details')			 // Add details tab (user object, label)
of_add_datapanel(3, 'u_cst_st_crew_members', 'Members')			 // Add Crews tab	(user object, label)

ibo_crew.of_registerdata(idw_list, FALSE)		 // Associate BO with the list

ib_iskeyautofill = FALSE	// If the key fields need to be autopopulated in the details tab
									// when filtering list using ONLY key fields and no data found. 
									// It will open the details tab with corresponded key fields autopopulated

idw_filter.SetItem(1, "active_flag", "Y")

IF f_get_job_based_crew_flag() = 'N' THEN 
	idw_filter.Object.job_or_region.Tag = "<H>valid region<H><L>REGION<L>"
END IF

end event

event close;call super::close;//************************************************************
// Object   :	w_st_crew 
// Event    :	close
// Author   :	Viktar Shmyk
// Date     :	2009/11/06
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Destroy objects when closing the window
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF IsValid(ibo_crew) THEN DESTROY(ibo_crew)
end event

event pfc_postopen;call super::pfc_postopen;//************************************************************
// Object   :	w_st_crew 
// Event    :	pfc_postopen
// Author   :	Viktar Shmyk
// Date     :	2009/11/06
// 	
// Arguments:	(None)
// 	
// Returns:		(None)
// 	
// Desc:			Performing Initial retrieve
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

tab_container.tabpage_main.cb_filter.EVENT Clicked()


idw_filter.inv_popup_data_list.of_register_column(	'active_flag', &
																	'd_popup_yes_no', &
																	'status', &
																	'status', &
																	TRUE, 700, TRUE, TRUE, TRUE)
																
idw_filter.inv_popup_data_list.of_register_column(	'current_members_flag', &
																	'd_popup_yes_no', &
																	'status', &
																	'status', &
																	TRUE, 700, TRUE, TRUE, TRUE)

IF f_get_job_based_crew_flag() = 'Y' THEN 
	idw_filter.inv_popup_data_list.of_register_column(	'job_or_region', &
																	'd_popup_job_all', &
																	'job', &
																	'job', &
																	TRUE, 400, TRUE, TRUE, FALSE, "")
ELSE
	idw_filter.inv_popup_data_list.of_register_column(	'job_or_region', &
																	'd_popup_region', &
																	'region', &
																	'region', &
																	TRUE, 400, TRUE, FALSE, TRUE)
END IF	
																	
idw_filter.inv_popup_data_list.of_register_column(	'alternate', &
																'd_popup_person', &
																'job', &
																'job', &
																TRUE, 400, TRUE, TRUE, FALSE, "")

idw_filter.inv_popup_data_list.of_register_column(	'alternate',								&
																'd_popup_person_active',					&
																'employee_long', 								&
																'employee_long', 								&
																TRUE, 550, 										&
																TRUE,		/* empty allowed */ 				&
																FALSE, 	/* retrieve by company */		&
																TRUE, 	/* retrieve on register */ 	&
																"") 																		

idw_filter.inv_popup_data_list.of_register_column(	'supervisor',								&
																'd_popup_person_active',					&
																'employee_long', 								&
																'employee_long', 								&
																TRUE, 550, 										&
																TRUE,		/* empty allowed */ 				&
																FALSE, 	/* retrieve by company */		&
																TRUE, 	/* retrieve on register */ 	&
																"") 																		


end event

event ue_pre_retrieve;call super::ue_pre_retrieve;//************************************************************
// Object   :	w_st_crew 
// Event    :	ue_pre_retrieve
// Author   :	Monica Petersen
// Date     :	2014/04/18
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

IF UpperBound(astr_parm.any_parm) > 0 THEN This.idw_filter.SetItem(1, "job_or_region", String(astr_parm.any_parm[1]))
IF UpperBound(astr_parm.any_parm) > 1 THEN This.idw_filter.SetItem(1, "crew", String(astr_parm.any_parm[2]))

end event

type st_dragpanel from w_m_filter_list`st_dragpanel within w_st_crew
end type

type sle_message from w_m_filter_list`sle_message within w_st_crew
end type

type st_blank from w_m_filter_list`st_blank within w_st_crew
end type

type cb_back from w_m_filter_list`cb_back within w_st_crew
integer taborder = 70
end type

type cb_save from w_m_filter_list`cb_save within w_st_crew
integer x = 2962
integer y = 2016
integer taborder = 40
end type

type tab_container from w_m_filter_list`tab_container within w_st_crew
integer width = 3346
end type

type tabpage_main from w_m_filter_list`tabpage_main within tab_container
integer width = 3273
end type

type cb_clear from w_m_filter_list`cb_clear within tabpage_main
end type

type cb_print from w_m_filter_list`cb_print within tabpage_main
end type

type cb_filter from w_m_filter_list`cb_filter within tabpage_main
end type

type dw_filter from w_m_filter_list`dw_filter within tabpage_main
integer width = 3241
string dataobject = "d_st_crew_filter"
boolean vscrollbar = false
end type

event dw_filter::pfc_print;//************************************************************
// Object   :	w_st_crew 
// Event    :	pfc_print
// Author   :	Viktar Shmyk
// Date     :	2011/07/14
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

dw_list.EVENT pfc_print()

RETURN 1
end event

event dw_filter::constructor;call super::constructor;//************************************************************
// Object   :	w_st_crew 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2013/11/18
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
This.iuo_calendar.of_Register("from_membership_date", This.iuo_calendar.NONE)
This.iuo_calendar.of_Register("to_membership_date", This.iuo_calendar.NONE)



end event

event dw_filter::ue_get_extra;call super::ue_get_extra;//************************************************************
// Object   :	w_st_crew 
// Event    :	ue_get_extra
// Author   :	Monica Petersen
// Date     :	2014/04/16
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

String	ls_member
Date	ld_from_date, ld_to_date


ld_from_date = This.GetItemDate(1, "from_membership_date")
ld_to_date = This.GetItemDate(1, "to_membership_date")

IF f_get_job_based_crew_flag() = 'Y' THEN 
	is_extra_filter = "book = '" + gnv_app.is_book + "'"
END IF

IF this.GetItemString(1, 'current_members_flag') = 'Y' THEN
	is_extra_filter = " current_members_count > 0 "
END IF


//Allow the user to search the employee field in the crew_member table
ls_member = this.GetItemString(1, 'member_name')
IF ls_member <> '' THEN
	IF is_extra_filter <> '' THEN is_extra_filter += ' AND '
	IF IsNumber(ls_member) THEN
		is_extra_filter +=  " EXISTS (SELECT 1 " 										&
							 +  "           FROM crew_member cm  " 					&
							 +  "          WHERE cm.job 		= crew_member.job " 	&
							 +  "            AND cm.crew 		= crew_member.crew " &
							 +  "            AND cm.employee = " + ls_member 
	ELSE		
		is_extra_filter +=  " EXISTS (SELECT 1 " 										&
							 +  "           FROM crew_member cm,  " 					&
							 +  "           		person  " 								&
							 +  "          WHERE cm.job 		= crew_member.job " 	&
							 +  "            AND cm.crew 		= crew_member.crew " &
							 +  "            AND cm.employee = person.employee  " &
							 +  "            AND person.name LIKE '%" + gnv_app.inv_string.of_GlobalReplace(ls_member, "'", "''") + "%'"
	END IF

END IF

IF NOT IsNull(ld_from_date) OR NOT IsNull(ld_to_date) THEN 
		
	IF ls_member = '' OR IsNull(ls_member) THEN
		IF is_extra_filter <> '' THEN is_extra_filter += ' AND '	

		is_extra_filter +=  " EXISTS (SELECT 1 " 										&
							 +  "           FROM crew_member cm  " 					&
							 +  "          WHERE cm.job 		= crew_member.job " 	&
							 +  "            AND cm.crew 		= crew_member.crew " &

	END IF	
	
	IF NOT IsNull(ld_from_date) AND NOT IsNull(ld_to_date) THEN 
		is_extra_filter += " AND ('" + String(ld_from_date, "yyyy-mm-dd") + "' BETWEEN effective_date AND expiry_date OR '" + String(ld_to_date, "yyyy-mm-dd") + "' BETWEEN effective_date AND expiry_date) "
	ELSEIF NOT IsNull(ld_from_date) AND IsNull(ld_to_date) THEN 
		is_extra_filter += " AND '" + String(ld_from_date, "yyyy-mm-dd") + "' BETWEEN effective_date AND expiry_date "
	ELSEIF IsNull(ld_from_date) AND NOT IsNull(ld_to_date) THEN 
		is_extra_filter += " AND '" + String(ld_to_date, "yyyy-mm-dd") + "' BETWEEN effective_date AND expiry_date "
	END IF
	
END IF

IF ls_member <> '' OR NOT IsNull(ld_from_date) OR NOT IsNull(ld_to_date) THEN 
	is_extra_filter += ")"
END IF
	
RETURN is_extra_filter
end event

event dw_filter::buttonclicked;call super::buttonclicked;//************************************************************
// Object   :	w_st_crew 
// Event    :	buttonclicked
// Author   :	Viktar Shmyk
// Date     :	2017/03/30
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

IF dwo.name = "b_calendar_from_membership_date" THEN
	IF This.SetColumn("from_membership_date") = 1 THEN
		This.EVENT pfc_DDCalendar()
	END IF
END IF

IF dwo.name = "b_calendar_to_membership_date" THEN
	IF This.SetColumn("to_membership_date") = 1 THEN
		This.EVENT pfc_DDCalendar()
	END IF
END IF

end event

type dw_list from w_m_filter_list`dw_list within tabpage_main
integer width = 3241
string dataobject = "d_st_crew_list"
end type

event dw_list::constructor;//************************************************************
// Object   :	w_st_crew 
// Event    :	constructor
// Author   :	Viktar Shmyk
// Date     :	2017/04/10
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


IF f_get_job_based_crew_flag() = 'N' THEN 
	This.Dataobject = 'd_st_crew_list_region'
END IF

CALL SUPER::constructor


RETURN AncestorReturnValue
end event

type uo_pin from w_m_filter_list`uo_pin within w_st_crew
integer taborder = 60
end type

type sle_focus_redirect from w_m_filter_list`sle_focus_redirect within w_st_crew
integer taborder = 50
end type

type dw_print from w_m_filter_list`dw_print within w_st_crew
integer taborder = 20
end type

type dw_buff from w_m_filter_list`dw_buff within w_st_crew
integer taborder = 30
end type

type st_base from w_m_filter_list`st_base within w_st_crew
end type

