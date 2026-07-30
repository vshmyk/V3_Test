$PBExportHeader$u_cst_jc_job_detail.sru
forward
global type u_cst_jc_job_detail from u_cst_datapanel_detail
end type
end forward

global type u_cst_jc_job_detail from u_cst_datapanel_detail
end type
global u_cst_jc_job_detail u_cst_jc_job_detail

type variables
String 			is_job_deleted
String			is_job
String			is_description
String			is_book
Long				il_history_flag
Long				il_dashboard_group_count
Long				il_next_job


n_bo_client		ibo_client
n_bo_area		ibo_area
n_bo_centre		ibo_centre
n_bo_company	ibo_company
n_bo_user		ibo_user
n_bo_book		ibo_book
n_bo_division_book	ibo_division_book
n_bo_dashboard_group	ibo_dashboard_group

end variables

forward prototypes
public function long of_retrieve (s_parm astr_parm)
public function string of_getcurrentfilter ()
end prototypes

public function long of_retrieve (s_parm astr_parm);//************************************************************
// Object   :	u_cst_jc_job_detail 
// Function :	of_retrieve
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	s_parm astr_parm
// 	
// Returns:		long
// 	
// Desc:			Set instance variables
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long 		ll_rc 
String	ls_st_gl_flag

this.SetRedraw(FALSE)

IF IsValid(ibo_datapanel_business) THEN
	is_job = astr_parm.s_parm[1]
	is_description = astr_parm.s_parm[2]
	is_book = astr_parm.s_parm[3]
	ll_rc = ibo_datapanel_business.of_retrieve("book = '" + is_book + "' and job = '" + is_job + "'")
END IF

IF ll_rc > 1 THEN
	dw_main.Reset()
	RETURN 1
END IF

IF ll_rc > 0 THEN
	// set standard_gl_flag from book
	ibo_book.of_get_standard_gl_flag(gnv_app.is_book, ls_st_gl_flag)
	dw_main.SetItem(ll_rc,"cf_book_standard_flag", ls_st_gl_flag)	
	dw_main.SetItemStatus(ll_rc,"cf_book_standard_flag",Primary!,NotModified!)
	
	// set dashboard_group count
	dw_main.SetItem(ll_rc,"cf_dashboard_group_count", il_dashboard_group_count)	
	dw_main.SetItemStatus(ll_rc,"cf_dashboard_group_count",Primary!,NotModified!)

	IF dw_main.GetItemString(ll_rc, 'active_flag') = 'Y' THEN
		//jira 3216 - rate type must be active 
		dw_main.inv_popup_data_list.of_set_popup_filter("equipment_rate_type", "active_flag = 'Y'")
	ELSE
		dw_main.inv_popup_data_list.of_set_popup_filter("equipment_rate_type", "")
	END IF		

END IF

this.POST SetRedraw(TRUE)

RETURN ll_rc
end function

public function string of_getcurrentfilter ();//************************************************************
// Object   :	u_cst_jc_job_detail 
// Function :	of_getcurrentfilter
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		string
// 	
// Desc:			REturns current filter used
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String ls_filter
Long ll_row

ll_row = dw_main.GetRow()

IF ll_row > 0 THEN
	ls_filter = "job = '" + &
			string(ibo_datapanel_business.of_getitemstring(ll_row, 'job')) + &
			"'"
END IF 

RETURN ls_filter
end function

on u_cst_jc_job_detail.create
call super::create
end on

on u_cst_jc_job_detail.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Set Business Objects and other instance variables
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

is_program = 'JCJENT'
ib_endaction_message = TRUE

IF NOT IsValid(ibo_area) THEN
	ibo_area = CREATE n_bo_area
	ibo_area.of_SetTransaction()
END IF

IF NOT IsValid(ibo_centre) THEN
	ibo_centre = CREATE n_bo_centre
	ibo_centre.of_SetTransaction()
END IF

IF NOT IsValid(ibo_company) THEN
	ibo_company = CREATE n_bo_company
	ibo_company.of_SetTransaction()
END IF

IF NOT IsValid(ibo_user) THEN
	ibo_user = CREATE n_bo_user
	ibo_user.of_SetTransaction()
END IF

IF NOT IsValid(ibo_book) THEN
	ibo_book = CREATE n_bo_book
	ibo_book.of_SetTransaction()
END IF

IF NOT IsValid(ibo_division_book) THEN
	ibo_division_book = CREATE n_bo_division_book
	ibo_division_book.of_SetTransaction()
END IF

IF Not(IsValid(ibo_dashboard_group)) THEN
	ibo_dashboard_group = CREATE n_bo_dashboard_group
	ibo_dashboard_group.of_SetTransaction(sqlca)
END IF

il_dashboard_group_count = ibo_dashboard_group.of_Count('')




end event

event ue_endaction_message;call super::ue_endaction_message;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_endaction_message
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	string as_action
// 				string as_message_entity
// 				string as_message_action
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

IF as_action <> 'D' THEN
	as_message_entity = 'Job'
ELSE
	as_message_entity = 'Job ' + is_job_deleted
END IF
end event

event ue_process_delete;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_process_delete
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Set instance variable of row deleted, proceed with delete, override
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long 		ll_row, ll_rc
String	ls_job


is_job_deleted = ''
ll_row = dw_main.GetRow()
IF ll_row > 0 THEN
	is_job_deleted = dw_main.GetItemString(ll_row, 'job') + '-' + dw_main.GetItemString(ll_row, 'description')
	
	ll_rc = EVENT ue_update()
END IF
RETURN ll_rc



end event

event ue_init;call super::ue_init;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_init
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Initialize datapanel			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
UserObject		luo_object
string	ls_extra_values_display[]


luo_object = This

This.is_datapanel_name = "Job"
gnv_synchronize.uf_register_interest("LIST_ROW_CHANGED", luo_object)	
gnv_synchronize.uf_register_interest("REFRESH_JOB_LIST", luo_object)	
gnv_synchronize.uf_register_interest("REFRESH_CLIENT_LIST", luo_object)	
This.ibo_datapanel_business.DYNAMIC of_SetLogEventName("JCJENT")


IF g_bo_application_properties.of_GetItemString(1, "allow_mixed_case_flag") = 'Y' THEN 
	dw_main.of_set_field_case({"description", "superintendent", "city", "address_1", "address_2"}, "C")
	dw_main.of_set_field_case({"memo", "timesheet_sign_line", "project_control_email_address"}, "M")
END IF


dw_main.inv_popup_data_list.of_register_column(	'region', &
																	'd_popup_region', &
																	'region', &
																	'region', &
																	TRUE, 1300, TRUE, TRUE, FALSE)	


dw_main.inv_popup_data_list.of_register_column(	'equ_ts_approver_style', &
																'd_dddw_ts_approver_style', &
																'equ_ts_approver_style', &
																'equ_ts_approver_style', &
																TRUE, 450, TRUE, TRUE, FALSE)		

dw_main.inv_popup_data_list.of_register_column(	'province', &
																	'd_popup_provstate', &
																	'province', &
																	'province', &
																	TRUE, 1300, TRUE, TRUE, FALSE)	
																	
dw_main.inv_popup_data_list.of_register_column(	'parent_job', &
																'd_popup_job_all', &
																'job', &
																'job', &
																TRUE, 805, TRUE, TRUE, FALSE)		
																
dw_main.inv_popup_data_list.of_register_column(	'client', &
																'd_popup_client', &
																'client', &
																'client', &
																TRUE, 450, TRUE, TRUE, FALSE)		
																
dw_main.inv_popup_data_list.of_register_column(	'dashboard_group', &
																'd_popup_dashboard_group', &
																'dashboard_group', &
																'dashboard_group', &
																TRUE, 720, 		 			&
																FALSE,	/* empty allowed */ 				&
																FALSE, 	/* retrieve by company */		&
																FALSE, 	/* retrieve on register */ 	&
																"active_flag = 'Y'")
																
dw_main.inv_popup_data_list.of_register_column(	'wcb_class', &
																'd_popup_wcb_class', &
																'wcb_class', &
																'wcb_class', &
																TRUE, 1100, TRUE, TRUE, FALSE)	
																
dw_main.inv_popup_data_list.of_register_column(	'gst_rule', &
																'd_popup_gst_rule', &
																'gst_rule', &
																'gst_rule', &
																TRUE, 2500, TRUE, FALSE, FALSE)	
																
dw_main.inv_popup_data_list.of_register_column(	'equipment_rate_type', &
																'd_popup_equipment_rate_type', &
																'equipment_rate_type', &
																'equipment_rate_type', &
																TRUE, 900, TRUE, TRUE, FALSE)		
																
dw_main.inv_popup_data_list.of_register_column(	'equipment_revenue_area', &
																'd_popup_area_revenue', &
																'area', &
																'description', &
																TRUE, 580, TRUE, TRUE, TRUE, "") 	
																
dw_main.inv_popup_data_list.of_register_column(	'equipment_revenue_centre', &
																'd_popup_centre_override_retrieval', &
																'centre', &
																'description', &
																TRUE, 780, FALSE, TRUE, TRUE, "") 	
																
dw_main.inv_popup_data_list.of_register_column(	'labour_rate_type', &
																'd_popup_labour_rate_type', &
																'labour_rate_type', &
																'labour_rate_type', &
																TRUE, 900, TRUE, TRUE, FALSE, "")																
																
dw_main.inv_popup_data_list.of_register_column(	'division', &
																'd_popup_division', &
																'division', &
																'division', &
																TRUE, 720, 		 			&
																FALSE,	/* empty allowed */ 				&
																TRUE, 	/* retrieve by company */		&
																FALSE, 	/* retrieve on register */ 	&
																"active_flag = 'Y'")

dw_main.inv_popup_data_list.of_register_column(	'contract_book', &
																'd_popup_company_all', &
																'book', &
																'description', &
																TRUE, 1500, TRUE, FALSE, TRUE, "")

dw_main.inv_popup_data_list.of_register_column(	'job_type', &
																'd_popup_standard_job', &
																'job_type', &
																'description', &
																TRUE, 450, TRUE, TRUE, FALSE)		
																
dw_main.inv_popup_data_list.of_register_column(	'trade_union_group', &
																'd_popup_trade_union_group', &
																'trade_union_group', &
																'description', &
																TRUE, 450, TRUE, TRUE, FALSE)		
																

gnv_synchronize.uf_register_interest("FORECAST_PROGRESS", luo_object)

RETURN 1
end event

event ue_process_print;call super::ue_process_print;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_process_print
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Create new print preview
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String		ls_subtitle
string		ls_select, ls_where
n_ds			lds_preview
s_preview	lstr_preview
window		lw_preview

ls_subtitle = is_description

IF dw_main.RowCount() > 0 THEN

	// set preview dataobject
	lds_preview = CREATE n_ds
	lds_preview.DataObject = 'd_jc_job_detail_prn'

	// manipulate where clause
	ls_select = lds_preview.Describe("Datawindow.Table.Select")
	
	ls_where =  "  job.book = '" + is_book + "' AND "  + &
					"  job.job = '" + string(is_job) + "'"
		
	IF LEN(ls_where ) > 0 THEN
		ls_select = ls_select + ' where  ' + ls_where
	END IF
	
	lds_preview.SetTransObject(SQLCA)
	lds_preview.Modify("Datawindow.Table.Select = ~"" + &
		ls_select + "~"")
	lds_preview.Retrieve()

	IF dw_main.RowCount() > 0 THEN
		lstr_preview.b_retrieve = TRUE
		lstr_preview.ds_preview = lds_preview
		lstr_preview.s_title = gnv_app.of_GetCompanyName()
		lstr_preview.s_sub_title = 'Job Record'
		lstr_preview.s_menu_1    = gnv_app.of_get_module_menu(This.is_program, 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2    = gnv_app.of_get_module_menu(This.is_program, 'menu_2')		// Menu item from program	

		OpenSheetWithParm(lw_preview,lstr_preview,'w_preview',gnv_app.of_getframe(),0, Original!)
	END IF
END IF

RETURN 1

end event

event destructor;call super::destructor;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	destructor
// Author   :	Lourdes Garcia
// Date     :	2009/08/24
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

UserObject		luo_object

luo_object = THIS

IF IsValid(ibo_centre) THEN DESTROY ibo_centre
IF IsValid(ibo_area) THEN DESTROY ibo_area
IF IsValid(ibo_user) THEN DESTROY ibo_user
IF IsValid(ibo_company) THEN DESTROY ibo_company
IF IsValid(ibo_book) THEN DESTROY ibo_book
IF IsValid(ibo_division_book) THEN DESTROY ibo_division_book
IF IsValid(ibo_dashboard_group) THEN DESTROY ibo_dashboard_group

// REMOVE INTEREST ON SYNCH OBJECTS
gnv_synchronize.uf_remove_interest("FORECAST_PROGRESS", luo_object)
gnv_synchronize.uf_remove_interest("LIST_ROW_CHANGED", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_JOB_LIST", luo_object)
gnv_synchronize.uf_remove_interest("REFRESH_CLIENT_LIST", luo_object)	

end event

event ue_process_other;call super::ue_process_other;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_process_other
// Author   :	Lourdes Garcia
// Date     :	2009/08/26
// 	
// Arguments:	string as_action_id
// 	
// Returns:		integer
// 	
// Desc:			Process other customized actions
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
Int		li_rc, li_rtn
Long		ll_row
string	ls_message, ls_job, ls_ok, ls_new_job
s_parm	lstr_parm


ll_row = dw_main.GetRow()

CHOOSE CASE as_action_id
		
	CASE 'H'
		ls_job = ibo_datapanel_business.of_GetItemString(ll_row,"job") 
		// save history
		li_rc = EVENT ue_update()
		IF li_rc = 1 THEN
			CHOOSE CASE il_history_flag
				CASE 0
					dw_main.POST EVENT ue_setmessage("Job restored from history","Blue")
				CASE 1
					dw_main.POST EVENT ue_setmessage("Job moved to history","Blue")	
				CASE -1 
					dw_main.POST EVENT ue_setmessage("ERROR - History change failed","Red")
			END CHOOSE		
		ELSE	
			dw_main.POST EVENT ue_setmessage("ERROR - History change failed","Red")
		END IF
			
		lstr_parm.s_parm[1] = ls_job 
		lstr_parm.s_parm[2] = ibo_datapanel_business.of_GetItemString(ll_row,"description")  
		lstr_parm.s_parm[3] = gnv_app.is_book
		this.of_retrieve(lstr_parm)
		
	// forecast
	CASE 'F'
	
		dw_main. EVENT ue_setmessage("forecasting in progress...","Blue")
		ls_job = ibo_datapanel_business.of_GetItemString(ll_row,"job")  
		
		li_rtn = ibo_centre.EVENT ue_process_forecast(gnv_app.is_book, ls_job, ls_message)
		
		IF li_rtn = 1 THEN
			dw_main. POST EVENT ue_setmessage(ls_message,"Blue")
		ELSE
			dw_main. POST EVENT ue_setmessage(ls_message,"Red")
		END IF
		
		lstr_parm.s_parm[1] = ls_job 
		lstr_parm.s_parm[2] = ibo_datapanel_business.of_GetItemString(ll_row,"description")  
		lstr_parm.s_parm[3] = gnv_app.is_book
		this.of_retrieve(lstr_parm)
		
		// log event
		gnv_event.of_add(is_program, as_action_id, ls_job)
		
	// snapshot	
	CASE 'T'
		ls_job = ibo_datapanel_business.of_GetItemString(ll_row,"job")  
		OpenWithParm(w_jcjent_snapshot, ls_job)
		ls_ok = Message.StringParm
		
		IF ls_ok = 'Y' THEN
			dw_main. POST EVENT ue_setmessage(ls_job + " - snapshot refreshed","Blue")
		ELSEIF ls_ok = 'N' THEN
			dw_main. POST EVENT ue_setmessage(ls_job + " - snapshot logging stopped","Blue")
		ELSE
			dw_main. POST EVENT ue_setmessage("","Blue")
		END IF
		
		lstr_parm.s_parm[1] = ls_job 
		lstr_parm.s_parm[2] = ibo_datapanel_business.of_GetItemString(ll_row,"description")  
		lstr_parm.s_parm[3] = gnv_app.is_book
		this.of_retrieve(lstr_parm)
		
END CHOOSE

RETURN li_rc
end event

event ue_event_synchronize;call super::ue_event_synchronize;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_event_synchronize
// Author   :	Lourdes Garcia
// Date     :	2009/08/31
// 	
// Arguments:	string as_event_id
// 				s_parm astr_parm
// 	
// Returns:		integer
// 	
// Desc:		  synchronize message
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

CHOOSE CASE as_event_id
	CASE "FORECAST_PROGRESS"	
		// set forecast progress
		dw_main. EVENT ue_setmessage(astr_parm.s_parm[1],"Blue")
				
	CASE "REFRESH_CLIENT_LIST"
		dw_main.inv_popup_data_list.of_retrieve_popup_data("client")
END CHOOSE	

RETURN AncestorReturnValue
		
end event

event ue_process_add;call super::ue_process_add;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_process_add
// Author   :	Monica Petersen
// Date     :	2013/09/10
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

Integer					li_errcount, li_error
String					ls_message
s_validation_error	lstr_err[]

n_bo_standard_job		lbo_standard_job

IF AncestorReturnValue = 1 THEN
	IF il_next_job <> 0 AND dw_main.GetItemString(1, 'job') = String(il_next_job) THEN
		
		//Track autonumbering of jobs
		g_bo_application_properties.of_Retrieve('')
		g_bo_application_properties.of_SetItem(1, 'last_job_used', il_next_job)
		g_bo_application_properties.of_Update(TRUE, lstr_err)
		
		//Write out errors
		li_errcount = UpperBound(lstr_err)
		IF li_errcount > 0 THEN
			FOR li_error = 1 TO li_errcount
				 ls_message += lstr_err[li_error].s_message + '~r'
			NEXT
			this.of_msg_db_error(ls_message)
	
			RETURN -1
		END IF 
					
	END IF
	
	//Create area and standard centres based on job_type
	IF Len(dw_main.GetItemString(1, 'job_type')) > 0 THEN
		SetRedraw(TRUE)
		dw_main.EVENT ue_SetMessage("Creating centres for " + dw_main.GetItemString(1, 'job_type') + " job type.", "blue")
		lbo_standard_job = CREATE n_bo_standard_job
		lbo_standard_job.of_SetTransaction()
		lbo_standard_job.of_add_standard_centres(dw_main.GetItemString(1, 'job'), &
															  dw_main.GetItemString(1, 'description'), &
															  dw_main.GetItemString(1, 'job_type'), &
															  dw_main.GetItemString(1, 'parent_job'), &
															  TRUE /* create area */, '', '')
		DESTROY lbo_standard_job
	END IF
END IF

RETURN AncestorReturnValue
end event

event ue_update;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_update
// Author   :	Monica Petersen
// Date     :	2015/08/14
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			OVERRIDE ANCESTOR
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

n_bo_crew_member	lbo_crew_member

s_parm	lstr_parm

//Capture this change to jobs on the A/R Invoice screen
gnv_synchronize.uf_event_trigger('REFRESH_JOB_LIST', lstr_parm)

//Instantiate crew_member so it gets updated as a set
// deleting a crew will delete all it's members
IF ibo_datapanel_business.of_GetChild("crew_member", lbo_crew_member) = -1 THEN
	this.of_msg_db_error("Crew member is not defined as a child table")
	RETURN -1
END IF

call super::ue_update;

		
RETURN AncestorReturnValue

end event

type hpb_progress from u_cst_datapanel_detail`hpb_progress within u_cst_jc_job_detail
end type

type dw_main from u_cst_datapanel_detail`dw_main within u_cst_jc_job_detail
event type integer ue_batch ( )
string dataobject = "d_jc_job_detail"
boolean ib_iseventlog = true
end type

event type integer dw_main::ue_batch();//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_batch
// Author   :	Monica Petersen
// Date     :	2017/10/27
// 	
// Arguments:	integer 
// 	
// Returns:		Integer
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer				li_rc
String 				ls_new_area
s_jccent_renumber	lstr_jccent_renumber
s_parm	lstr_parms
u_dw_business	ldw_shared[]

IF dw_main.RowCount() = 0 THEN
	this.EVENT ue_SetMessage("Record not found", "red")
	RETURN -1
END IF
dw_main.SetItem(1,'action','B')
dw_main.AcceptText()

lstr_jccent_renumber.s_job 	= parent.is_job
lstr_jccent_renumber.s_profile = is_profile

dw_main.SetRedraw(TRUE)
//OpenWithParm(w_jc_job_batch, lstr_jccent_renumber)
OpenSheetWithParm(w_jc_job_batch, lstr_jccent_renumber,'w_jc_job_batch', gnv_app.of_getframe(), 0, Original!)

//lstr_jccent_renumber = Message.PowerObjectParm
//
//IF IsValid(lstr_jccent_renumber) THEN
//	IF lstr_jccent_renumber.s_centre <> '1' AND lstr_jccent_renumber.s_centre <> '-1' THEN
//
//		li_rc = ibo_datapanel_business.of_SetItemStatus(1,0,Primary!,NotModified!)
//		dw_main.EVENT ue_inquire()
//		
//		ibo_datapanel_business.of_SetItem(1,'job',lstr_jccent_renumber.s_job)
//		ibo_datapanel_business.of_SetItem(1,'area',lstr_jccent_renumber.s_area)
//		ibo_datapanel_business.of_SetItem(1,'centre',lstr_jccent_renumber.s_centre)
//		ibo_datapanel_business.of_SetItemStatus(1,0,Primary!,NotModified!)
//		
//		dw_main.POST EVENT itemchanged(1, dw_main.object.centre, lstr_jccent_renumber.s_centre)
//		dw_main.POST EVENT ue_SetMessage('Centre renumbered', "blue")
//			
//	END IF
//END IF
//
//dw_main.SetColumn(1)
//dw_main.SelectText(1,1)
//
//IF dw_main.ibo_business.of_count("book = '" + gnv_app.is_book + "' AND job = '" + is_job + "'") = 0 THEN
//	//dw_main.EVENT POST ue_setmessage("Current centre has been renumbered. Please refresh the main list.", "RED")
//	//Refresh list so it includes the newly created reversing payments
//	lstr_parms.s_parm[1] = ""
//	lstr_parms.s_parm[2] = "B"
//	dw_main.ibo_business.of_getshared(ldw_shared)
//	lstr_parms.po_parm = ldw_shared
//	gnv_synchronize.uf_event_trigger('BO_POSTUPDATE', lstr_parms)
//ELSE
//	li_rc = ibo_datapanel_business.of_SetItemStatus(1,0,Primary!,NotModified!)
//	dw_main.EVENT ue_inquire()
//	dw_main.ReselectRow(1)
//END IF


RETURN 1



end event

event dw_main::constructor;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Set default action, business object OVERRIDE
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



This.of_setdefaultactions('ABCDFIVPRTZ')

This.of_set_popup_data(TRUE)

is_business_object = 'n_bo_job'
is_report_name     = 'Job Record' 
ib_endaction_message = TRUE
ib_iseventlog = TRUE

this.of_SetDropDownCalendar(TRUE)
this.iuo_calendar.of_Register("start_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("complete_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("shutdown_start_date", this.iuo_calendar.NONE)
this.iuo_calendar.of_Register("shutdown_end_date", this.iuo_calendar.NONE)

This.of_register_entry_screen("equipment_rate_type", "w_eq_equipment_rate_type", "EQETYP", {"equipment_rate_type"})
This.of_register_entry_screen("labour_rate_type", "w_tb_labour_rate_type", "TBLTYP", {"labour_rate_type"})
This.of_register_entry_screen("client", "w_ar_client", "ARCENT", {"client"})
This.of_register_entry_screen("parent_job", "w_jc_job", "JCJENT", {"parent_job"})
This.of_register_entry_screen("wcb_class", "w_tb_wcb_class", "TBWENT", {"wcb_class"})
This.of_register_entry_screen("gst_rule", "w_st_gst_rule", "STKENT", {"gst_rule"})
This.of_register_entry_screen("division", "w_st_division", "STOENT", {"division"})
This.of_register_entry_screen("equipment_revenue_area", "w_jc_area", "JCAENT", {"job", "equipment_revenue_area"})
This.of_register_entry_screen("equipment_revenue_centre", "w_jc_centre", "JCCENT", {"job", "equipment_revenue_area", "equipment_revenue_centre"})
This.of_register_entry_screen("dashboard_group", "w_am_dashboard_group", "AMDENT", {"dashboard_group"})
This.of_register_entry_screen("province", "w_st_province_tax", "STIENT", {"province"})
This.of_register_entry_screen("region", "w_st_region", "STNENT", {"region"})
this.of_register_entry_screen("job_type", "w_st_standard_job", "STFENT", {"job_type"})

This.of_register_report("add_datetime")

ib_add_reset = TRUE

CALL SUPER::constructor
end event

event dw_main::destructor;call super::destructor;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	destructor
// Author   :	Lourdes Garcia
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

event dw_main::ue_add;call super::ue_add;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_add
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

iw_parent.title = 'J/C Job: NEW RECORD*'

RETURN 1

end event

event dw_main::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_preprint
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

astr_preview.s_sub_title = is_job + '-' + is_description

RETURN 1
end event

event dw_main::bo_postupdate;call super::bo_postupdate;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	bo_postupdate
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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


Long		ll_row
s_parm	lstr_parm,lstr_parm2

// Determine whether there is a current row - if not, the assumption 
// is that the row was deleted
ll_row = This.GetRow()

IF ll_row > 0 THEN
	lstr_parm.s_parm[1] = This.GetItemString(ll_row, "job")
	lstr_parm.s_parm[2] = ibo_datapanel_business.of_GetItemString(ll_row,"description")  
ELSE
	lstr_parm.s_parm[1] = ""
	lstr_parm.s_parm[2] = ""
END IF

lstr_parm.s_parm[3] = gnv_app.is_book

parent.of_retrieve(lstr_parm)


end event

event dw_main::pfc_print;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	pfc_print
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			override
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Event ue_process_print()

RETURN 1
end event

event dw_main::itemchanged;call super::itemchanged;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	itemchanged
// Author   :	Lourdes Garcia
// Date     :	2009/08/21
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

String		ls_curr_column, &
				ls_action, &
				ls_country, &
				ls_seq, &
				ls_fill
				
Integer		li_rc, &
				li_length

String		ls_client_po_item, ls_before, ls_after

Boolean		lb_change
				
ls_curr_column = lower(dwo.Name)

ls_action = This.GetItemString(1, 'action')

CHOOSE CASE ls_curr_column 
//	CASE 'upload_sequence'
//		li_length = LEN(TRIM(data))
//		IF li_length > 0 THEN
//			ls_fill = FILL('0',8 - li_length)
//			ls_seq = ls_fill + Trim(data)
//				
//			ibo_datapanel_business.POST of_SetItem(row, 'upload_sequence', ls_seq)
//		END IF			
				
	CASE 'client_po'
		IF data = '' THEN 
			SetNull(ls_client_po_item)
			This.SetItem(1, "client_po_item", ls_client_po_item)
		ELSE
			This.POST SetColumn("client_po_item")
		END IF
	CASE 'job'
		IF ls_action = 'A' THEN
			
			data = of_trim_space(data)
			data = of_remove_char(data, "'")
			data = of_remove_char(data, '"')

			ibo_datapanel_business.of_SetItem(row,'parent_job',data)
			
			// close to re-register
			IF IsValid(w_popup_data_list) THEN Close(w_popup_data_list)
			
			// re-register to add data
			any la_extra[]
			la_extra[1] = data
			
			dw_main.inv_popup_data_list.of_register_column(	'parent_job', &
																'd_popup_job_all', &
																'job', &
																'job', &
																TRUE, 805, TRUE, TRUE, TRUE,'',la_extra, la_extra)	
		END IF
		
	CASE 'client'
		IF Len(data) > 0 THEN
			
			//Pick up the default rates for this client
			IF Not(IsValid(ibo_client)) THEN
				ibo_client = CREATE n_bo_client
				ibo_client.of_SetTransaction()
			END IF
			
			IF ibo_client.of_Retrieve("book = '" + gnv_app.is_book + "' AND client = '" + data + "'") > 0 THEN
				
				//Labour 
				lb_change = TRUE
				IF Len(this.GetItemString(1, 'labour_rate_type')) > 0 THEN
					IF Len(ibo_client.of_GetItemString(1, 'labour_rate_type')) > 0 THEN
						IF MessageBox(this.title, 'Okay to change labour rate type to client default (' + ibo_client.of_GetItemString(1, 'labour_rate_type') + ')?', Question!, YesNo!, 1) = 2 THEN
							lb_change = FALSE
						END IF
					END IF
				END IF
				
				IF lb_change THEN
					this.SetItem(1, 'labour_rate_type', ibo_client.of_GetItemString(1, 'labour_rate_type'))
					this.SetItem(1, 'smtc_per_hour', ibo_client.of_GetItemDecimal(1, 'smtc_per_hour'))
					this.SetItem(1, 'material_markup_percent', ibo_client.of_GetItemDecimal(1, 'material_markup_percent'))
					this.SetItem(1, 'labour_markup_percent', ibo_client.of_GetItemDecimal(1, 'labour_markup_percent'))
				END IF
				
				//Equipment
				lb_change = TRUE
				IF Len(this.GetItemString(1, 'equipment_rate_type')) > 0 THEN
					IF Len(ibo_client.of_GetItemString(1, 'equipment_rate_type')) > 0 THEN
						IF MessageBox(this.title, 'Okay to change equipment rate type to client default (' + ibo_client.of_GetItemString(1, 'equipment_rate_type') + ')?', Question!, YesNo!, 1) = 2 THEN
							lb_change = FALSE
						END IF
					END IF
				END IF
				
				IF lb_change THEN
					this.SetItem(1, 'equipment_rate_type', ibo_client.of_GetItemString(1, 'equipment_rate_type'))
				END IF
			END IF
		END IF

	CASE 'province'
			IF len(TRIM(data)) > 0 OR NOT(IsNull(data)) THEN 
				IF IsValid(This.inv_popup_data_list) THEN
					ls_country = string(This.inv_popup_data_list.of_get_popup_item( 'province', 'country') )
					This.SetItem(row, 'country',ls_country)
				END IF
			END IF	
			
	CASE 'parent_job'		
			IF TRIM(Data) = ibo_datapanel_business.of_GetItemstring(row,'job') THEN
				dw_main.POST EVENT ue_setmessage(TRIM(Data) + " is the PARENT job", "Blue")
			ELSE
				dw_main.POST EVENT ue_setmessage(TRIM(Data) + " is the OFFSET job", "Blue")
			END IF
		
	CASE 'equipment_revenue_area'
		IF IsNull(data) OR LEN(data) = 0 THEN
			This.SetItem(row,"equipment_revenue_centre","")
		END IF
		
	CASE 'active_flag'
		IF data = 'Y' THEN
			//jira 3216 - rate type must be active 
			dw_main.inv_popup_data_list.of_set_popup_filter("equipment_rate_type", "active_flag = 'Y'")
		ELSE
			dw_main.inv_popup_data_list.of_set_popup_filter("equipment_rate_type", "")
		END IF		

	CASE 'admin_fee_flag'
		IF data = 'Y' THEN
			//ISSL wants a flag, not a number, but a number allows for automating A/R billing
			dw_main.SetItem(row, 'admin_fee_percent', 1.0)
		ELSE
			dw_main.SetItem(row, 'admin_fee_percent', 0)
		END IF		

	CASE 'concurrent_crew_memberships_flag'
		IF data = 'N' THEN
			// If the flag value is already Y and they want to make it N, please warn that active memberships 
			// in other job crews for members of this job’s crews will be expired.
			MessageBox("Multiple Crews", "Members active in other job crews will be expired from crews for this job.")
		END IF		
		
	CASE 'equipment_rate_type', 'labour_rate_type'
		
		IF This.inv_popup_data_list.of_is_valid_value( ls_curr_column, data) &
		OR IsNull(data) OR Trim(data) = '' THEN
			
			IF IsValid(w_popup_data_list) THEN
				Close(w_popup_data_list)
			END IF
			
			ls_before = this.GetItemString(1, ls_curr_column, Primary!, TRUE)
			IF IsNull(ls_before) THEN ls_before = ''
			
			ls_after = data
			IF IsNull(ls_after) THEN ls_after = ''
			
			IF ls_before <> ls_after THEN
				IF Len(ls_before) > 0 THEN
					IF MessageBox(this.title, 'These rates may have already been used in billings, Okay to change?', Question!, YesNo!, 2) = 2 THEN
						
						//Don't bother with using the 1 return code, just put the value back and accept it
						This.SetText(ls_before)
						This.AcceptText()
						This.POST SetItem(1, ls_curr_column, this.GetItemString(1, ls_curr_column, Primary!, TRUE))
						
					END IF
				END IF
			END IF
		END IF
		
END CHOOSE
end event

event dw_main::ue_validateaction;call super::ue_validateaction;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_validateaction
// Author   :	Lourdes Garcia
// Date     :	2009/08/24
// 	
// Arguments:	string as_action
// 	
// Returns:		integer
// 	
// Desc:			IF action is not I or P then only proceed if file_type = 'C'
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
Int		li_return = 1
Long		ll_row
String	ls_snapshot_flag

IF AncestorReturnValue > 0 THEN

	ll_row = This.GetRow()
	dw_main.AcceptText()
	
	
	IF ll_row > 0 THEN
		IF as_action = 'I' OR as_action = 'V' or as_action = 'P' or as_action = 'A' or as_action = 'H' THEN
			li_return = 1
		ELSE
			IF ibo_datapanel_business.of_GetItemString(ll_row,"file_type") = 'H' AND as_action <> 'B' THEN
				dw_main.POST EVENT ue_setmessage("Use J/C Retrieval utility to restore job to current file for changes and deletion","RED")		
				li_return = -1
			ELSE
				// snapshots
				IF as_action = 'T' THEN
					// further check if we can proceed with 'T'
					ibo_user.of_get_update_snapshot_flag(gnv_app.of_getuserid(),ls_snapshot_flag)
					IF ls_snapshot_flag <> 'Y' THEN
						dw_main.POST EVENT ue_setmessage("User profile does not allow snapshots","RED")
						li_return = -1
					END IF
					
					
					// check profile
					IF li_return = 1 THEN
						IF  g_bo_application_properties.of_GetItemString(1, 'job_cost_month_variance_flag') = 'Y' THEN
							dw_main.POST EVENT ue_setmessage("Application is setup to support current month costs and not snapshots","RED")
							li_return = -1
						END IF
						
					END IF
				END IF
			END IF	
		END IF
	END IF
ELSE
	li_return = -1
END IF		


Return li_return


end event

event dw_main::bo_preupdate;call super::bo_preupdate;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	bo_preupdate
// Author   :	Lourdes Garcia
// Date     :	2009/08/24
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Set Address fields and last_update
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Long		ll_row
string	ls_address_1, ls_address_2


ll_row = this.GetRow()

IF ibo_datapanel_business.of_GetItemStatus(ll_row, 0, Primary!) = DataModified! or &
	ibo_datapanel_business.of_GetItemStatus(ll_row, 0, Primary!) = NewModified! THEN

	IF ll_row > 0 THEN
	
		// set last_update
		ibo_datapanel_business.of_SetItem(ll_row,'last_update',DateTime(Today(),Time(0,0,0)))
		
		
		//Shift Address line 1 down
	
		ls_address_1 = Trim(ibo_datapanel_business.of_GetItemString(ll_row,'address_1'))
		ls_address_2 = Trim(ibo_datapanel_business.of_GetItemString(ll_row,'address_2'))
		
		IF ls_address_2 = '' THEN
			ibo_datapanel_business.of_SetItem(ll_row,'address_1','')
			ibo_datapanel_business.of_SetItem(ll_row,'address_2',ls_address_1)
		END IF
		
		
	END IF
END IF

RETURN AncestorReturnValue
end event

event dw_main::clicked;call super::clicked;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	clicked
// Author   :	Lourdes Garcia
// Date     :	2009/08/26
// 	
// Arguments:	integer xpos
// 				integer ypos
// 				long row
// 				dwobject dwo
// 	
// Returns:		long
// 	
// Desc:			Open Calendar Controls
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF dwo.name = 'b_start_date' THEN
	IF This.SetColumn("start_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF
END IF

IF dwo.name = 'b_end_date' THEN
	IF This.SetColumn("complete_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF
END IF

IF dwo.name = 'b_shutdown_start' THEN
	IF This.SetColumn("shutdown_start_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF
END IF

IF dwo.name = 'b_shutdown_end' THEN
	IF This.SetColumn("shutdown_end_date") = 1 THEN
		This.Event pfc_DDCalendar( )
	END IF
END IF

end event

event dw_main::ue_history;call super::ue_history;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_history
// Author   :	Lourdes Garcia
// Date     :	2009/08/26
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Return ancestorReturnValue
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


il_history_flag = AncestorReturnValue

RETURN il_history_flag
end event

event dw_main::ue_other;call super::ue_other;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_other
// Author   :	Lourdes Garcia
// Date     :	2009/08/26
// 	
// Arguments:	string as_action_id
// 				boolean ab_changefocus
// 	
// Returns:		integer
// 	
// Desc:			Process Forecast, Snapshot
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer	li_rc
String	ls_action

li_rc = 1 

ls_action = This.GetItemString(1, 'action')

CHOOSE CASE as_action_id
		
	//forecast
	CASE 'F'
		This.of_setaction(1, 'F')
		This.of_disable()
		This.of_enable_column('action')
		This.of_enable_column('job')	
		
	// SnapShot	
	CASE 'T'	
		This.of_setaction(1, 'T')
		This.of_disable()
		This.of_enable_column('action')
		This.of_enable_column('job')
		

END CHOOSE

RETURN li_rc

end event

event dw_main::ue_renumber;call super::ue_renumber;//************************************************************
// Object   :	u_cst_eq_equipment_rate_group_detail 
// Event    :	ue_renumber
// Author   :	Viktar Shmyk
// Date     :	2011/09/15
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

Integer li_rc
s_parm	lstr_parm

s_renumber	lstr_renumber

// See the s_renumber object for a description of each property in 
// the structure
lstr_renumber.s_title = "Renumber Job"
lstr_renumber.s_business_object_class = "n_bo_job"
lstr_renumber.s_from_label = "from job"
lstr_renumber.s_to_label = "to job"
lstr_renumber.s_from_microhelp = "existing job"
lstr_renumber.s_to_microhelp = "new  job"
lstr_renumber.i_max_characters = 6
lstr_renumber.s_from_initial_value = This.GetItemString(1, "job")
lstr_renumber.s_renumber_column = "job"
lstr_renumber.s_description_column = "description"
lstr_renumber.i_label_width = 300
lstr_renumber.i_value_width = 400
lstr_renumber.i_description_width = 1500
lstr_renumber.b_allow_merge = FALSE
lstr_renumber.s_program = Parent.is_program
lstr_renumber.s_popup_dataobject = "d_popup_job_all"
lstr_renumber.s_popup_data_column = "job"
lstr_renumber.s_popup_display_column = "name"
lstr_renumber.i_popup_width = 1390
lstr_renumber.b_popup_retrieve_by_company = TRUE
lstr_renumber.s_popup_filter = ""

li_rc = Parent.of_renumber(lstr_renumber, This.Object.job)


RETURN li_rc




end event

event dw_main::ue_change;call super::ue_change;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_change
// Author   :	Lourdes Garcia
// Date     :	2009/09/08
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
Long	ll_row

// set computed column
ll_row = This.GetRow()

IF ll_row > 0 THEN
	
// disable if there's no div-book
	IF ibo_division_book.of_count("book = '" + gnv_app.is_book + "'") = 0 THEN
		dw_main.of_disable_column('division')
	END IF

END IF	

//Preliminary jobs become current
IF dw_main.GetItemString(1, 'file_type') = 'P' THEN
	dw_main.SetItem(1, 'file_type', 'C')
END IF
	
RETURN 1
end event

event dw_main::ue_z;call super::ue_z;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_z
// Author   :	Lourdes Garcia
// Date     :	2009/09/08
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

Long	ll_row

// set computed column
ll_row = This.GetRow()

IF ll_row > 0 THEN
	
// disable if there's no div-book
	IF ibo_division_book.of_count("book = '" + gnv_app.is_book + "'") = 0 THEN
		dw_main.of_disable_column('division')
	END IF

END IF	

RETURN 1
end event

event dw_main::ue_pbmkey;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_pbmkey
// Author   :	Viktar Shmyk
// Date     :	2009/09/30
// 	
// Arguments:	keycode key
// 				unsignedlong keyflags
// 	
// Returns:		long
// 	
// Desc:			(WINABIO-1186) when attaching division to a job, allow any active division to be chosen.
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String ls_popup_div
String ls_division
String ls_column
Long	 ll_popup_row
Integer li_rc

IF key = KeyEnter! THEN
	ls_column = This.GetColumnName()
	IF ls_column = 'division' AND IsValid(This.inv_popup_data_list) THEN
		ls_division = This.GetText()
		IF ls_division <> '' THEN 
			ll_popup_row = This.inv_popup_data_list.of_get_popup_current_row()
				IF String(This.inv_popup_data_list.of_get_popup_item('division', 'division')) <> '' OR &
					(ll_popup_row  > 0 AND String(This.inv_popup_data_list.of_get_popup_item(ll_popup_row, 'division')) <> '') THEN 
					IF ll_popup_row > 0 THEN
						ls_division = String(This.inv_popup_data_list.of_get_popup_item(ll_popup_row, 'division'))
					END IF
					
					IF ibo_division_book.of_count("book = '" + gnv_app.is_book + "' AND division = '" + ls_division + "'") = 0 THEN
						This.SetItem(1, 'division', ls_division)
						li_rc = Messagebox('Populate Job Division','Division is not associated with this company. Ok?', Exclamation!, YesNo!, 2)
						
						IF li_rc <> 1 THEN 
							This.SetItem(1, 'division', "")
							RETURN 1
						END IF
					END IF
			END IF
		END IF
	END IF
END IF

CALL SUPER::ue_pbmkey
end event

event dw_main::ue_open_report;call super::ue_open_report;

s_preview			lstr_preview
w_report_preview	lw_report_preview

CHOOSE CASE as_column
						
	CASE 'add_datetime'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('UTEVNT', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('UTEVNT', 'menu_2')		// Menu item from program	
		lstr_preview.s_report = "U/T Event Log Report Drill Down"
		lstr_preview.s_parm[5] = gnv_app.is_book	/*	company */
		lstr_preview.s_parm[7] = 'ALL'				/*	user ID */							
		lstr_preview.s_parm[9] = 'JCJENT'			/* event */							
		lstr_preview.s_parm[11] = 'ALL'				/* action */
		lstr_preview.s_parm[13] = this.GetItemString(al_row, 'job') 		/*	key */
		lstr_preview.s_parm[15] = 'ALL'				/*	delta */
		
		lstr_preview.s_parm[12] = 'JCBENT'			/* event2 */
		lstr_preview.s_parm[14] = this.GetItemString(al_row, 'job')			/*	key2 */
		lstr_preview.s_parm[16] = 'ALL'				/*	delta2 */
		
		lstr_preview.s_parm[18] = '1990101'			/* from date */
		lstr_preview.s_parm[19] = String(today(), 'yyyymmdd')					/* to date */

		lstr_preview.s_parm[20] = 'JCARCH'			/* event3 */
		lstr_preview.s_parm[21] = this.GetItemString(al_row, 'job') 		/*	key3 */
		lstr_preview.s_parm[22] = 'ALL'				/*	delta3 */

		lstr_preview.s_parm[24] = ''					//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_ut", gnv_app.of_getframe(), 0, Original!)

END CHOOSE

RETURN
end event

event dw_main::itemfocuschanging;call super::itemfocuschanging;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	itemfocuschanging
// Author   :	Monica Petersen
// Date     :	2014/04/01
// 	
// Arguments:	long al_row
// 				string as_column
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


CHOOSE CASE as_column
	CASE 'description'
		IF this.GetText() = '' THEN
			this.EVENT POST ue_setmessage("Please enter a description", "red")
			RETURN -1
		END IF
END CHOOSE

RETURN 1
end event

event dw_main::bo_overridepopupdataretrieval;call super::bo_overridepopupdataretrieval;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	bo_overridepopupdataretrieval
// Author   :	Monica Petersen
// Date     :	2015/02/23
// 	
// Arguments:	string as_column
// 				n_ds ads_popup
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

Integer	li_row
String	ls_job, ls_area, ls_description

CHOOSE CASE as_column	
	CASE 'equipment_revenue_centre'
		
		RETURN ibo_centre.of_populate_centre_popup(ads_popup, 							&
																 gnv_app.is_book, 					&
																 this.GetItemString(1, 'job'),	&
																 this.GetItemString(1, 'equipment_revenue_area'),	&
																 'R','','','','','',			&
																 dw_main.GetItemString(1, 'action'))
	CASE 'equipment_revenue_area'
		ads_popup.Reset()
		
		//Find all areas with revenue for current job
		ls_job = this.GetItemString(1, 'job')
		DECLARE C3 CURSOR FOR
			SELECT DISTINCT
						area.area,   
						area.description
				 FROM area,
						centre  
				WHERE area.job = centre.job    
				  AND area.area = centre.area 
				  AND area.book = centre.book
				  AND centre.cost_type like '%R%' 
				  AND centre.active_flag = 'Y'   
				  AND area.active_flag = 'Y'
				  AND area.book = :gnv_app.is_book
				  AND area.job = :ls_job
				USING sqlca;
			 
		OPEN C3;
		FETCH C3 
		 INTO :ls_area, :ls_description;
		
		DO WHILE sqlca.sqlcode = 0
			
			li_row = ads_popup.InsertRow(0)
			ads_popup.SetItem(li_row,'area',	ls_area)
			ads_popup.SetItem(li_row,'description',	ls_description)
	
			FETCH C3 
			 INTO :ls_area, :ls_description;
		LOOP
		
		CLOSE C3;
		RETURN 1
END CHOOSE

RETURN 0


end event

event dw_main::ue_add_setup;call super::ue_add_setup;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_add_setup
// Author   :	Monica Petersen
// Date     :	2016/03/15
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

String	ls_st_gl_flag, ls_division, ls_job_type
String	ls_concurrent_crew_memberships_flag
String	ls_null
Long	ll_row

// set computed column
ll_row = This.GetRow()

IF ll_row > 0 THEN
	SetNull(ls_null)
	
	ls_concurrent_crew_memberships_flag = g_bo_application_properties.of_GetItemString(1, "allow_concurrent_crew_membership_flag")
	dw_main.SetItem(ll_row, "concurrent_crew_memberships_flag", ls_concurrent_crew_memberships_flag)	
	
	// set standard_gl_flag from book
	ibo_book.of_get_standard_gl_flag(gnv_app.is_book, ls_st_gl_flag)
	dw_main.SetItem(ll_row,"cf_book_standard_flag", ls_st_gl_flag)	
	dw_main.SetItemStatus(ll_row,"cf_book_standard_flag",Primary!,NotModified!)
	
	// set dashboard_group count
	dw_main.SetItem(ll_row,"cf_dashboard_group_count", il_dashboard_group_count)	
	dw_main.SetItemStatus(ll_row,"cf_dashboard_group_count",Primary!,NotModified!)

	// default div to item on list if there's only one record on div_book
	IF ibo_division_book.of_count("book = '" + gnv_app.is_book + "'") = 1 THEN
		ls_division = ibo_division_book.of_get_division(gnv_app.is_book)
		ibo_datapanel_business.of_SetItem(ll_row,"division",ls_division)
	END IF
	
	//Find if there's a default job type
	SELECT TOP 1 job_type
	  INTO :ls_job_type
	  FROM standard_job
	 WHERE "default_flag" = 'Y'
	 USING sqlca;
	IF Len(ls_job_type) > 0 THEN
		dw_main.SetItem(ll_row,"job_type", ls_job_type)	
		dw_main.SetItemStatus(ll_row,"job_type",Primary!,NotModified!)
	END IF
	
END IF

RETURN 1
end event

event dw_main::ue_action_key;call super::ue_action_key;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_action_key
// Author   :	Monica Petersen
// Date     :	2017/10/27
// 	
// Arguments:	string as_key
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

Integer li_rc
String ls_cost_type 

li_rc = AncestorReturnValue

IF as_key = "B" AND li_rc > 0 THEN
	li_rc = EVENT ue_batch()
END IF


RETURN li_rc
end event

event dw_main::ue_get_action_desc;call super::ue_get_action_desc;//************************************************************
// Object   :	u_cst_jc_job_detail 
// Event    :	ue_get_action_desc
// Author   :	Monica Petersen
// Date     :	2017/10/27
// 	
// Arguments:	string as_action
// 				string as_description
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

CHOOSE CASE as_action
	CASE 'B'
		as_description =  "Batch, "
		as_microhelp =  "This action allows users to Activate, Deactivate, or Move to History a range of jobs.~nIt also allows the option of removing unused centres for a range of jobs.~nThis will remove visual clutter from Centre based reports."
END CHOOSE


end event

