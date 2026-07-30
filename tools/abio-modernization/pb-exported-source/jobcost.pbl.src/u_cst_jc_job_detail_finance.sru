$PBExportHeader$u_cst_jc_job_detail_finance.sru
forward
global type u_cst_jc_job_detail_finance from u_cst_datapanel_detail
end type
end forward

global type u_cst_jc_job_detail_finance from u_cst_datapanel_detail
end type
global u_cst_jc_job_detail_finance u_cst_jc_job_detail_finance

type variables
String 			is_job_deleted
String			is_job
String			is_description
String			is_book
String			is_company_gl_year_begin
end variables

forward prototypes
public function string of_getcurrentfilter ()
public function long of_retrieve (s_parm astr_parm)
end prototypes

public function string of_getcurrentfilter ();//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Function :	of_getcurrentfilter
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
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

public function long of_retrieve (s_parm astr_parm);//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Function :	of_retrieve
// Author   :	Lourdes Garcia
// Date     :	2009/08/20
// 	
// Arguments:	s_parm astr_parm
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

Long 		ll_rc 
Decimal	ldec_cur_budget, ldec_forecast
String	ls_skin_type


IF IsValid(ibo_datapanel_business) THEN
	is_job = astr_parm.s_parm[1]
	is_description = astr_parm.s_parm[2]
	is_book = astr_parm.s_parm[3]
	ll_rc = ibo_datapanel_business.of_retrieve("book = '" + is_book + "' and job = '" + is_job + "'")
	IF ll_rc > 0 THEN ibo_datapanel_business.of_SetItem(1, 'company_gl_year_begin', is_company_gl_year_begin)
END IF

IF ll_rc > 1 THEN
	dw_main.Reset()
	RETURN 1
END IF


//ls_skin_type = g_bo_application_properties.of_GetItemString(1, 'skin_type')
ls_skin_type = 'J'

IF ll_rc > 0  AND ls_skin_type <> 'J' THEN
	SELECT SUM( "centre"."lab_cur_budget_amt" + "centre"."mtl_cur_budget_amt" + "centre"."equ_cur_budget_amt" + "centre"."sub_cur_budget_amt"),
			 SUM( "centre"."lab_forecast_amt" + "centre"."mtl_forecast_amt" + "centre"."equ_forecast_amt" + "centre"."sub_forecast_amt" )
	  INTO :ldec_cur_budget, :ldec_forecast
	  FROM "centre" 
	 WHERE "centre"."book" = :gnv_app.is_book
		AND "centre"."job"  = :is_job 
	 USING SQLCA;
	IF sqlca.sqlcode <> 0 THEN
		THIS.of_msg_db_error("Error reading budget")
		RETURN -1
	END IF
	
	
	dw_main.SetItem(1, 'cc_cur_budget_amt', ldec_cur_budget)
	dw_main.SetItem(1, 'cc_forecast_amt', ldec_forecast)
END IF

RETURN ll_rc
end function

on u_cst_jc_job_detail_finance.create
call super::create
end on

on u_cst_jc_job_detail_finance.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	constructor
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


is_program = 'JCJENT'
ib_endaction_message = TRUE
end event

event ue_endaction_message;call super::ue_endaction_message;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
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
	IF as_action = 'E' THEN
		as_message_entity = 'Job has been changed.'
	ELSE
		as_message_entity = 'Job '
	END IF	
ELSE
	as_message_entity = 'Job ' + is_job_deleted
END IF


end event

event ue_init;call super::ue_init;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_init
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

This.is_datapanel_name = "Job Financials"
This.ibo_datapanel_business.DYNAMIC of_SetLogEventName("JCJENT")

SELECT gl_year_begin
  INTO :is_company_gl_year_begin
  FROM company
 WHERE book = :gnv_app.is_book
 USING sqlca;
IF sqlca.sqlcode = -1 THEN
	this.of_msg_db_error("Error reading company")
	RETURN -1
END IF


RETURN 1
end event

event ue_process_delete;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_process_delete
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

Long 	ll_row, ll_rc

is_job_deleted = ''
ll_row = dw_main.GetRow()
IF ll_row > 0 THEN
	is_job_deleted = dw_main.GetItemString(ll_row, 'job') + '-' + dw_main.GetItemString(ll_row, 'description')
	
	ll_rc = EVENT ue_update()
 
END IF

RETURN ll_rc


end event

event ue_process_print;call super::ue_process_print;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_process_print
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
			//lstr_preview.dw_preview = dw_main
			lstr_preview.ds_preview = lds_preview
			lstr_preview.s_title = gnv_app.of_GetCompanyName()
			lstr_preview.s_sub_title = 'J/C JOB'
			lstr_preview.s_menu_1      = gnv_app.of_get_module_menu(This.is_program, 'menu_1')		// Menu item from program
			lstr_preview.s_menu_2      = gnv_app.of_get_module_menu(This.is_program, 'menu_2')		// Menu item from program	

			OpenSheetWithParm(lw_preview,lstr_preview,'w_preview',gnv_app.of_getframe(),0, Original!)
		END IF

END IF

RETURN 1

end event

event ue_process_other;call super::ue_process_other;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_process_other
// Author   :	Lourdes Garcia
// Date     :	2009/08/26
// 	
// Arguments:	string as_action_id
// 	
// Returns:		integer
// 	
// Desc:		   Process other Action
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer li_rc

CHOOSE CASE as_action_id
	CASE 'E'		
		li_rc = EVENT ue_update()
		IF li_rc = 1 THEN
			dw_main.POST EVENT ue_setmessage("Job " + is_job + " updated", "blue")
		END IF
END CHOOSE		


RETURN li_rc 
end event

event ue_post_apply;call super::ue_post_apply;
boolean lb_change_focus = TRUE

IF dw_main.GetRow() > 0 THEN
	CHOOSE CASE as_action
		CASE 'E'
			dw_main.SetItem(1, 'action', as_action)
			dw_main.SetItemStatus(1, 'action', Primary!, NotModified!)
			dw_main.SetColumn('expected_cost')
			dw_main.EVENT ue_other(as_action, lb_change_focus)	//Same action, with a <tab>
	END CHOOSE
	
END IF

RETURN 1
end event

type hpb_progress from u_cst_datapanel_detail`hpb_progress within u_cst_jc_job_detail_finance
end type

type dw_main from u_cst_datapanel_detail`dw_main within u_cst_jc_job_detail_finance
string dataobject = "d_jc_job_detail_finance"
end type

event dw_main::constructor;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	constructor
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



This.of_setdefaultactions('EIPVZ')

is_business_object = 'n_bo_job'
is_report_name     = 'Job ' + is_job
ib_endaction_message = TRUE
ib_iseventlog = TRUE

This.of_register_report("original_budget")
This.of_register_report("current_budget")
This.of_register_report("to_date_cost")
This.of_register_report("to_date_revenue")
This.of_register_report("to_date_payment")
This.of_register_report("commitment")
This.of_register_report("period_1_revenue")
This.of_register_report("period_2_revenue")
This.of_register_report("period_3_revenue")
This.of_register_report("period_4_revenue")
This.of_register_report("period_5_revenue")
This.of_register_report("period_6_revenue")
This.of_register_report("period_7_revenue")
This.of_register_report("period_8_revenue")
This.of_register_report("period_9_revenue")
This.of_register_report("period_10_revenue")
This.of_register_report("period_11_revenue")
This.of_register_report("period_12_revenue")

This.of_register_report("period_1_cost")
This.of_register_report("period_2_cost")
This.of_register_report("period_3_cost")
This.of_register_report("period_4_cost")
This.of_register_report("period_5_cost")
This.of_register_report("period_6_cost")
This.of_register_report("period_7_cost")
This.of_register_report("period_8_cost")
This.of_register_report("period_9_cost")
This.of_register_report("period_10_cost")
This.of_register_report("period_11_cost")
This.of_register_report("period_12_cost")

CALL SUPER::constructor
end event

event dw_main::destructor;call super::destructor;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
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

event dw_main::ue_preprint;call super::ue_preprint;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
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
// Object   :	u_cst_jc_job_detail_finance 
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
ELSE
	lstr_parm.s_parm[1] = ""
END IF

gnv_synchronize.uf_event_trigger("RETRIEVE_JOB_LIST", lstr_parm)


end event

event dw_main::pfc_print;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
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

event dw_main::ue_other;call super::ue_other;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_other
// Author   :	Lourdes Garcia
// Date     :	2009/08/26
// 	
// Arguments:	string as_action_id
// 				boolean ab_changefocus
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
Integer	li_rc
String	ls_action

li_rc = 1 

ls_action = This.GetItemString(1, 'action')

CHOOSE CASE as_action_id
	CASE 'E'
		This.of_setaction(1, 'E')
		This.of_disable()
		This.of_enable_column('expected_cost')
		This.of_enable_column('expected_revenue')
		this.POST SetColumn('expected_cost')
		this.POST SetFocus()
END CHOOSE

RETURN li_rc

end event

event dw_main::ue_fieldmicrohelp;call super::ue_fieldmicrohelp;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_fieldmicrohelp
// Author   :	Lourdes Garcia
// Date     :	2009/08/26
// 	
// Arguments:	string as_column
// 				string as_microhelptext
// 	
// Returns:		(None)
// 	
// Desc:			Update Fieldmicrohelp
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

CHOOSE CASE as_column
	CASE 'action'
		as_microhelptext =  "Expect, Z"
END CHOOSE
end event

event dw_main::ue_open_report;call super::ue_open_report;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_open_report
// Author   :	Monica Petersen
// Date     :	2012/02/13
// 	
// Arguments:	long al_row
// 				string as_column
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


String				ls_period, ls_source, ls_fiscal_year_begin
Date					ldt_gl_year_begin, ldt_offset
s_preview			lstr_preview
w_report_preview	lw_report_preview

CHOOSE CASE as_column
	CASE 'to_date_cost'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('JCXREP', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('JCXREP', 'menu_2')		// Menu item from program	
		lstr_preview.s_report = "J/C Transaction Report"
		lstr_preview.s_parm[1] = 'H'
		lstr_preview.s_parm[4] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[5] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[6] = '0'									
		lstr_preview.s_parm[7] = 'ZZZZZ'								
		lstr_preview.s_parm[8] = '0'									
		lstr_preview.s_parm[9] = 'ZZZZZ'
		lstr_preview.s_parm[10] = '19900101'	
		lstr_preview.s_parm[11] = '20991231'	
		lstr_preview.s_parm[24] = ''										//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_jc", gnv_app.of_getframe(), 0, Original!)
						
	CASE 'to_date_revenue'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('ARIREP', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('ARIREP', 'menu_2')		// Menu item from program	
		lstr_preview.s_menu_3 = 'd'
		lstr_preview.s_report = "A/R Invoices by Job in Client"
		lstr_preview.s_parm[1] = 'C'
		lstr_preview.s_parm[2] = 'H'
		lstr_preview.s_parm[4] = '0'									
		lstr_preview.s_parm[5] = 'ZZZZZZ'								
		lstr_preview.s_parm[6] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[7] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[8] = ''									
		lstr_preview.s_parm[9] = 'ZZZZZZZZZZZZ'								
		lstr_preview.s_parm[10] = '199001'	
		lstr_preview.s_parm[11] = '209912'	
		lstr_preview.s_parm[12] = '19900101'	
		lstr_preview.s_parm[13] = '20991231'	
		lstr_preview.s_parm[14] = 'I'	
		lstr_preview.s_parm[15] = 'ALL'	
		lstr_preview.s_parm[17] = 'A'	
		lstr_preview.s_parm[24] = ''										//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_ar", gnv_app.of_getframe(), 0, Original!)

	CASE 'commitment'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('ARPREP', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('ARPREP', 'menu_2')		// Menu item from program	
		lstr_preview.s_menu_3 = 'c'
		lstr_preview.s_report = "A/P P/Os by Centre in Job"
		lstr_preview.s_parm[1] = 'C'
		lstr_preview.s_parm[2] = 'H'
		lstr_preview.s_parm[4] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[5] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[6] = '0'									
		lstr_preview.s_parm[7] = 'ZZZZZ'								
		lstr_preview.s_parm[8] = '0'									
		lstr_preview.s_parm[9] = 'ZZZZZ'
		lstr_preview.s_parm[10] = '19900101'	
		lstr_preview.s_parm[11] = '20991231'	
		lstr_preview.s_parm[12] = 'A'	
		lstr_preview.s_parm[13] = 'A'	
		lstr_preview.s_parm[14] = 'Y'	
		lstr_preview.s_parm[15] = 'A'	
		lstr_preview.s_parm[24] = ''										//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_ap", gnv_app.of_getframe(), 0, Original!)
						
	CASE 'to_date_payment'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('ARPREP', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('ARPREP', 'menu_2')		// Menu item from program	
		lstr_preview.s_menu_3 = 'c'
		lstr_preview.s_report = "A/R Payments by Job"
		lstr_preview.s_parm[1] = 'C'
		lstr_preview.s_parm[2] = 'H' 
		lstr_preview.s_parm[4] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[5] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[6] = '199001'	
		lstr_preview.s_parm[7] = '209912'	
		lstr_preview.s_parm[8] = '19900101'	
		lstr_preview.s_parm[9] = '20991231'	
		lstr_preview.s_parm[11] = 'P'	
		lstr_preview.s_parm[24] = ''										//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_ar", gnv_app.of_getframe(), 0, Original!)
						
	CASE 'original_budget'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('JCCREP', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('JCCREP', 'menu_2')		// Menu item from program	
		lstr_preview.s_menu_3 = 'f'
		lstr_preview.s_report = "J/C Centre Budget Report"
		lstr_preview.s_parm[1] = 'C'
		lstr_preview.s_parm[2] = 'H' 
		lstr_preview.s_parm[4] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[5] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[6] = '0'
		lstr_preview.s_parm[7] = 'ZZZZZ'
		lstr_preview.s_parm[8] = '0'
		lstr_preview.s_parm[9] = 'ZZZZZ'
		lstr_preview.s_parm[11] = 'O'
		lstr_preview.s_parm[13] = 'ALL'
		lstr_preview.s_parm[15] = 'A'
		lstr_preview.s_parm[24] = ''										//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_jc", gnv_app.of_getframe(), 0, Original!)

	CASE 'current_budget'
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('JCCREP', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('JCCREP', 'menu_2')		// Menu item from program	
		lstr_preview.s_menu_3 = 'f'
		lstr_preview.s_report = "J/C Centre Budget Report"
		lstr_preview.s_parm[1] = 'C'
		lstr_preview.s_parm[2] = 'H' 
		lstr_preview.s_parm[4] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[5] = this.GetItemString(1, 'job')
		lstr_preview.s_parm[6] = '0'
		lstr_preview.s_parm[7] = 'ZZZZZ'
		lstr_preview.s_parm[8] = '0'
		lstr_preview.s_parm[9] = 'ZZZZZ'
		lstr_preview.s_parm[11] = 'C'
		lstr_preview.s_parm[13] = 'ALL'
		lstr_preview.s_parm[15] = 'A'
		lstr_preview.s_parm[24] = ''										//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_jc", gnv_app.of_getframe(), 0, Original!)

	CASE ELSE
		IF Right(as_column, 4) = 'cost' THEN
			ls_source = 'COST'
		ELSE
			ls_source = 'REVENUE'
		END IF
		ls_period = Mid(as_column, 8, 2)
		IF Right(ls_period, 1) = '_' THEN
			ls_period = Left(ls_period, 1)
		END IF
		ls_fiscal_year_begin = this.GetItemString(1, 'company_gl_year_begin')
		ldt_gl_year_begin = Date(Left(ls_fiscal_year_begin,4) + '.' + Right(ls_fiscal_year_begin,2) + '.01')
		ldt_offset = gnv_app.inv_datetime.of_RelativeMonth(ldt_gl_year_begin, Integer(ls_period) - 1)
		
		lstr_preview.s_book = gnv_app.is_book
		lstr_preview.s_title = f_get_book_desc(lstr_preview.s_book)
		lstr_preview.s_menu_1 = gnv_app.of_get_module_menu('GLXREP', 'menu_1')		// Menu item from program
		lstr_preview.s_menu_2 = gnv_app.of_get_module_menu('GLXREP', 'menu_2')		// Menu item from program	
		lstr_preview.s_menu_3 = 'a'
		lstr_preview.s_report = "G/L Account Transactions"
		lstr_preview.s_parm[1] = 'C'
		lstr_preview.s_parm[2] = 'H' 
		lstr_preview.s_parm[4] = '000000'
		lstr_preview.s_parm[5] = '999999'
		lstr_preview.s_parm[6] = String(ldt_offset, 'YYYYMM')
		lstr_preview.s_parm[7] = String(ldt_offset, 'YYYYMM')
		lstr_preview.s_parm[8] = '19900101'	
		lstr_preview.s_parm[9] = '20991231'	
		lstr_preview.s_parm[10] = this.GetItemString(1, 'job')							/* from job 		*/
		lstr_preview.s_parm[11] = this.GetItemString(1, 'job')							/* to job 			*/
		lstr_preview.s_parm[12] = ''																/* from equipment */
		lstr_preview.s_parm[13] = 'ZZZZZZ'														/* to equipment 	*/
		lstr_preview.s_parm[15] = 'A'																/* job type			*/
		lstr_preview.s_parm[17] = ls_source														/* source 			*/
		lstr_preview.s_parm[19] = 'ALL'															/* description		*/
		lstr_preview.s_parm[22] = 'ALL'															/* department 		*/
		lstr_preview.s_parm[24] = 'ALL'															/* division 		*/
		lstr_preview.s_parm[36] = ''																//prevent array overflow
		
		OpenSheetWithParm(lw_report_preview, lstr_preview, &
						"w_report_preview_gl", gnv_app.of_getframe(), 0, Original!)

END CHOOSE

RETURN
end event

event dw_main::ue_endaction_message;call super::ue_endaction_message;//************************************************************
// Object   :	u_cst_jc_job_detail_finance 
// Event    :	ue_endaction_message
// Author   :	Monica Petersen
// Date     :	2014/09/03
// 	
// Arguments:	string as_action_id
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


as_message_entity = "Job Financial Details"
end event

event dw_main::ue_get_action_desc;call super::ue_get_action_desc;
IF as_action = 'E' THEN
	as_description = 'Expect'
	as_microhelp = 'Enter the expected costs and revenue for this job'
END IF

end event

