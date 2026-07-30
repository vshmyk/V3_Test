$PBExportHeader$n_bo_job.sru
forward
global type n_bo_job from n_cst_business_abio
end type
end forward

global type n_bo_job from n_cst_business_abio
event type integer bo_update_commitments_by_job ( string as_book,  string as_job,  decimal adc_value,  ref string as_message )
end type
global n_bo_job n_bo_job

type variables
n_bo_application_properties		ibo_application_properties
n_bo_company							ibo_company
n_bo_area								ibo_area
n_bo_book								ibo_book
n_bo_province_state					ibo_province_state
n_bo_division_book					ibo_division_book
n_bo_dashboard_group					ibo_dashboard_group

end variables

forward prototypes
public function integer of_get_province_of_job (string as_book, string as_job, ref string as_province)
public function integer of_get_active_indicator (string as_book, string as_job, ref string as_active)
public function integer of_get_job_description (string as_book, string as_job, ref string as_description)
public function integer of_get_division (string as_book, string as_job, ref string as_division)
public function integer of_get_snapshot_date (string as_book, string as_job, ref datetime adt_snapshot_date)
public function integer of_get_po_address_flag (string as_book, string as_job, ref string as_po_address_flag)
public function integer of_get_equipment_rate_type (string as_book, string as_job, ref string as_equipment_rate_type)
public function integer of_get_labour_rate_type (string as_book, string as_job, ref string as_labour_rate_type)
public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message)
public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status)
public function integer of_get_next_pm_document_no (string as_book, string as_job, ref long al_pm_document_no)
end prototypes

event type integer bo_update_commitments_by_job(string as_book, string as_job, decimal adc_value, ref string as_message);//************************************************************
// Object   :	n_bo_job 
// Function :	bo_update_commitments_by_job
// Author   :	Lourdes Garcia
// Date     :	2011/03/16
// 	
// Arguments:	string as_book
// 				string as_job
// 				decimal adc_value
// 				string as_message
// 	
// Returns:		integer
// 	
// Desc:			Update commitment
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



Decimal							ldc_cost, ldc_value
Long								ll_row
String							ls_find

as_message = ""

IF IsNull(adc_value) THEN adc_value = 0

ls_find = "book = '" + string(as_book) + "' and job = '" + string(as_job) + "'"
ll_row = This.of_find(ls_find)
CHOOSE CASE ll_row
	CASE -1
		this.of_msg_db_error("Error finding job " + ls_find, this.itr_trans)
		RETURN -1
	CASE 0
		this.of_Retrieve(ls_find, TRUE) //Append rows
		ll_row = This.of_find(ls_find)
END CHOOSE
		
IF ll_row > 0 THEN
	This.of_SetItem(ll_row,'commitment', this.of_GetItemDecimal(ll_row, 'commitment') + adc_value)
	This.of_SetItem(ll_row,'last_update',Today())
ELSE
	as_message = 'No Job retrieved, Error in updating commitments.'
	this.of_msg_db_error("No Job retrieved, error updating commit cost in centre " + ls_find, this.itr_trans)
	RETURN -1
END IF

RETURN 1

end event

public function integer of_get_province_of_job (string as_book, string as_job, ref string as_province);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_job_columns
// Author   :	Lourdes Garcia
// Date     :	2009/03/06
// 	
// Arguments:	string as_book
// 				string as_job
// 				s_parms astr_parm
// 	
// Returns:		integer
// 	
// Desc:			Returns Job columns given book and job
//						PROVINCE for now
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_where
String	ls_province
Long		ll_rc

IF IsNull(as_book) OR IsNull(as_job) THEN RETURN 0
	

ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	


ll_rc = This.of_Retrieve(ls_where)
IF ll_rc > 0  THEN
	as_province = This.of_getitemstring(ll_rc,"province")
END IF	


RETURN ll_rc
end function

public function integer of_get_active_indicator (string as_book, string as_job, ref string as_active);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_active_indicator
// Author   :	Lourdes Garcia
// Date     :	2009/03/09
// 	
// Arguments:	string as_book
// 				string as_job
// 				string as_active
// 	
// Returns:		integer
// 	
// Desc:			Returns Active Indicator
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String	ls_where
String	ls_province
Long		ll_rc

IF IsNull(as_book) OR IsNull(as_job) THEN RETURN 0
	

ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	


ll_rc = This.of_Retrieve(ls_where)
IF ll_rc > 0  THEN
	as_active = This.of_getitemstring(ll_rc,"active_flag")
END IF	


RETURN ll_rc
end function

public function integer of_get_job_description (string as_book, string as_job, ref string as_description);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_job_description
// Author   :	Lourdes Garcia
// Date     :	2009/06/10
// 	
// Arguments:	string as_book
// 				string as_job
// 				string as_active
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

String	ls_where
Int		li_return
Long		ll_rc

IF IsNull(as_book) OR IsNull(as_job)  THEN 
	as_description = ""
	li_return = -1 
ELSE
	ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	
	
	ll_rc = This.of_Retrieve(ls_where)
	IF ll_rc > 0  THEN
		as_description = This.of_getitemstring(ll_rc,"description")
		li_return = 1
	ELSE
		as_description = ""
		li_return = 0
	END IF	
END IF	


RETURN li_return


end function

public function integer of_get_division (string as_book, string as_job, ref string as_division);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_division
// Author   :	Monica Petersen
// Date     :	2009/08/31
// 	
// Arguments:	string as_book
// 				string as_job
// 				string as_division
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

String	ls_where
Long		ll_rc

IF IsNull(as_book) OR IsNull(as_job) THEN RETURN 0
	

ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	


ll_rc = This.of_Retrieve(ls_where)
IF ll_rc > 0  THEN
	as_division = This.of_getitemstring(ll_rc,"division")
END IF	


RETURN ll_rc
end function

public function integer of_get_snapshot_date (string as_book, string as_job, ref datetime adt_snapshot_date);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_snapshot_date
// Author   :	Lourdes Garcia
// Date     :	2011/03/09
// 	
// Arguments:	string as_book
// 				string as_job
// 				datetime adt_snapshot_date
// 	
// Returns:		integer
// 	
// Desc:			Returns snapshot date
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String	ls_where
String	ls_province
Long		ll_rc

IF IsNull(as_book) OR IsNull(as_job) THEN RETURN 0
	

ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	


ll_rc = This.of_Retrieve(ls_where)
IF ll_rc > 0  THEN
	adt_snapshot_date = This.of_GetitemDateTime(ll_rc,"snapshot_date")
END IF	


RETURN ll_rc
end function

public function integer of_get_po_address_flag (string as_book, string as_job, ref string as_po_address_flag);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_po_address_flag
// Author   :	Lourdes Garcia
// Date     :	2011/03/30
// 	
// Arguments:	string as_book
// 				string as_job
// 				string as_po_address_flag
// 	
// Returns:		integer
// 	
// Desc:			Returns po_address_flag
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String	ls_where
String	ls_province
Long		ll_rc




IF IsNull(as_book) OR IsNull(as_job) THEN RETURN 0
	

ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	


ll_rc = This.of_Retrieve(ls_where)
IF ll_rc > 0  THEN
	as_po_address_flag = This.of_GetitemString(ll_rc,"po_address_flag")
END IF	


RETURN ll_rc
end function

public function integer of_get_equipment_rate_type (string as_book, string as_job, ref string as_equipment_rate_type);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_equipment_rate_type
// Author   :	Lourdes Garcia
// Date     :	2012/01/18
// 	
// Arguments:	string as_book
// 				string as_job
// 				string as_equipment_rate_type
// 	
// Returns:		integer
// 	
// Desc:			Returns Equipment Rate type
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************






String	ls_where
String	ls_province
Long		ll_rc

IF IsNull(as_book) OR IsNull(as_job) THEN RETURN 0
	

ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	


ll_rc = This.of_Retrieve(ls_where)
IF ll_rc > 0  THEN
	as_equipment_rate_type = This.of_GetitemString(ll_rc,"equipment_rate_type")
END IF	


RETURN ll_rc
end function

public function integer of_get_labour_rate_type (string as_book, string as_job, ref string as_labour_rate_type);//************************************************************
// Object   :	n_bo_job 
// Function :	of_get_labour_rate_type
// Author   :	Lourdes Garcia
// Date     :	2012/07/31
// 	
// Arguments:	string as_book
// 				string as_job
// 				string as_labour_rate_type
// 	
// Returns:		integer
// 	
// Desc:			Returns as_labour_rate_type REF
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


String	ls_where
Long		ll_rc


	

ls_where = "job = '" + as_job + "' and book = '" + as_book + "'"	

IF NOT IsNull(ls_where) THEN
	ll_rc = This.of_Retrieve(ls_where)
	IF ll_rc > 0  THEN
		as_labour_rate_type = This.of_getitemstring(ll_rc,"labour_rate_type")
	ELSE
		ll_rc = -1
	END IF
ELSE
	ll_rc = -1
END IF

RETURN ll_rc
end function

public function integer of_checkrenumber (string as_book, string as_from_value, string as_to_value, ref string as_message);//************************************************************
// Object   :	n_bo_job 
// Function :	of_checkrenumber
// Author   :	Monica Petersen
// Date     :	2017/03/02
// 	
// Arguments:	string as_book
// 				string as_from_value
// 				string as_to_value
// 				string as_message
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

Integer	li_rc = -1
Long		ll_row

// Check that the from value exists
ll_row = This.of_Retrieve("book = '" + gnv_app.is_book + "' AND job = '" + as_from_value + "'")

IF ll_row > 0 THEN
	// Check that the to value does NOT exist (merges are not allowed 
	// for job records)
	ll_row = This.of_Retrieve("book = '" + gnv_app.is_book + "' AND job = '" + as_to_value + "'")
	
	IF ll_row = 0 THEN
		li_rc = 1
		as_message = "Job " + as_from_value + " will be renumbered to " + &
				as_to_value
	ELSE
		as_message = "Job " + as_to_value + " already exists"
	END IF
ELSE
	as_message = "Job " + as_from_value + " does not exist"
END IF

RETURN li_rc

end function

public function integer of_renumber (string as_book, string as_from_value, string as_to_value, ref string as_message, ref statictext as_status);//************************************************************
// Object   :	n_bo_job 
// Function :	of_renumber
// Author   :	Monica Petersen
// Date     :	2017/03/13
// 	
// Arguments:	string as_book
// 				string as_from_value
// 				string as_to_value
// 				string as_message
// 				statictext as_status
// 	
// Returns:		integer
// 	
// Desc:			
//					timesheet					job				* use embedded sql
//					centre_snapshot_history	job
//					area_group					job
//					area_group_client_approver	job
//					labour_dispersion			job				* 
//					labour_dispersion	timesheet_job			*
//					area_group_client_po		job
//					person_diary				job
//					po_root						job
//					equipment_activity		from_job
//					equipment_activity		to_job
//					journal_entry_item		job
//					gl_transaction				job				*
//					time_entry_spreadsheet_log	job
//					trade_union_job			job
//					area							job
//					centre						job
//					po_reserve					job
//					job_shipping_info			job
//					client_po					job
//					quantity						job
//					purchase_requisition_item	job
//					jc_transaction				job				*
//					equipment_usage			job
//					job							job
//					job							parent_job
//					job							client_job
//					employee						job
//					crew							job
//					budget_transfer			job
//					ar_invoice					job
//					equipment					job
//					journal_entry				job_1 - job_20
//					ap_invoice					job
//					crew_member					job
//					crew_supervisor			job
//					payment						job 	
//
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer									li_rc
Long										ll_row, ll_rows
n_bo_centre_snapshot_history		lbo_centre_snapshot_history
n_bo_area_group						lbo_area_group
n_bo_area_group_client_approver	lbo_area_group_client_approver
n_bo_area_group_client_po			lbo_area_group_client_po
n_bo_area_client_po			lbo_area_client_po
n_bo_person_diary						lbo_person_diary
n_bo_po_root							lbo_po_root
n_bo_equipment_activity				lbo_equipment_activity
n_bo_journal_entry_item				lbo_journal_entry_item
n_bo_time_entry_spreadsheet_log	lbo_time_entry_spreadsheet_log
n_bo_trade_union_job					lbo_trade_union_job
n_bo_area								lbo_area
n_bo_centre								lbo_centre
n_bo_po_reserve						lbo_po_reserve
n_bo_job_shipping_info				lbo_job_shipping_info
n_bo_client_po							lbo_client_po
n_bo_quantity							lbo_quantity
n_bo_purchase_requisition_item	lbo_purchase_requisition_item
n_bo_equipment_usage					lbo_equipment_usage
n_bo_job									lbo_job
n_bo_employee							lbo_employee
n_bo_crew								lbo_crew
n_bo_budget_transfer					lbo_budget_transfer
n_bo_ar_invoice						lbo_ar_invoice
n_bo_ar_invoice_root					lbo_ar_invoice_root
n_bo_equipment							lbo_equipment
n_bo_rental_agreement				lbo_rental_agreement
n_bo_ap_invoice						lbo_ap_invoice
n_bo_crew_member						lbo_crew_member
n_bo_payment							lbo_payment 	

s_validation_error					lstr_validation_error[]

SetPointer(Hourglass!)

// Modify the job record
as_status.text = "Renumbering job"
this.of_Retrieve("book = '" + as_book + &
		"' AND (job = '" + as_from_value &
			+ "' OR parent_job = '" + as_from_value + "')")
ll_rows = this.of_RowCount()
FOR ll_row = 1 TO ll_rows
	IF this.of_GetItemString(ll_row, 'job') = as_from_value THEN this.of_SetItem(ll_row, "job", as_to_value)
	IF this.of_GetItemString(ll_row, 'parent_job') = as_from_value THEN this.of_SetItem(ll_row, "parent_job", as_to_value)
NEXT

// Retrieve the child records and modify them
This.of_GetChild({"centre_snapshot_history"}, lbo_centre_snapshot_history)
as_status.text = "Renumbering centre snapshot"
ll_rows = lbo_centre_snapshot_history.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_centre_snapshot_history", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_centre_snapshot_history.of_SetItem(ll_row, "job", as_to_value)
NEXT

//area group
This.of_GetChild({"area_group"}, lbo_area_group)
as_status.text = "Renumbering area group"
ll_rows = lbo_area_group.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_area_group", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_area_group.of_SetItem(ll_row, "job", as_to_value)
NEXT

//lbo_area_group_client_approver
This.of_GetChild({"area_group_client_approver"}, lbo_area_group_client_approver)
as_status.text = "Renumbering area_group_client_approver"
ll_rows = lbo_area_group_client_approver.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_area_group_client_approver", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_area_group_client_approver.of_SetItem(ll_row, "job", as_to_value)
NEXT

//area_client_po
This.of_GetChild({"area_client_po"}, lbo_area_client_po)
as_status.text = "Renumbering area_client_po"
ll_rows = lbo_area_client_po.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_area_client_po", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_area_client_po.of_SetItem(ll_row, "job", as_to_value)
NEXT

//area_group_client_po
This.of_GetChild({"area_group_client_po"}, lbo_area_group_client_po)
as_status.text = "Renumbering area_group_client_po"
ll_rows = lbo_area_group_client_po.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_area_group_client_po", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_area_group_client_po.of_SetItem(ll_row, "job", as_to_value)
NEXT

//person_diary
This.of_GetChild({"person_diary"}, lbo_person_diary)
as_status.text = "Renumbering person_diary"
ll_rows = lbo_person_diary.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_person_diary", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_person_diary.of_SetItem(ll_row, "job", as_to_value)
NEXT

//po_root
This.of_GetChild({"po_root"}, lbo_po_root)
as_status.text = "Renumbering po_root"
ll_rows = lbo_po_root.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_po_root", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_po_root.of_SetItem(ll_row, "job", as_to_value)
NEXT

//equipment_activity
This.of_GetChild({"equipment_activity"}, lbo_equipment_activity)
as_status.text = "Renumbering equipment_activity"
ll_rows = lbo_equipment_activity.of_Retrieve("to_job = '" + as_from_value + "' OR from_job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_equipment_activity", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	IF lbo_equipment_activity.of_GetItemString(ll_row, 'from_job') = as_from_value THEN lbo_equipment_activity.of_SetItem(ll_row, "from_job", as_to_value)
	IF lbo_equipment_activity.of_GetItemString(ll_row, 'to_job') = as_from_value THEN lbo_equipment_activity.of_SetItem(ll_row, "to_job", as_to_value)
NEXT

//journal_entry_item
This.of_GetChild({"journal_entry_item"}, lbo_journal_entry_item)
as_status.text = "Renumbering journal_entry_item"
ll_rows = lbo_journal_entry_item.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_journal_entry_item", this.itr_trans)
	RETURN -1
END IF
FOR ll_row = 1 TO ll_rows
	lbo_journal_entry_item.of_SetItem(ll_row, "job", as_to_value)
NEXT

//time_entry_spreadsheet_log
li_Rc = This.of_GetChild({"time_entry_spreadsheet_log"}, lbo_time_entry_spreadsheet_log)
as_status.text = "Renumbering time_entry_spreadsheet_log"
ll_rows = lbo_time_entry_spreadsheet_log.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_time_entry_spreadsheet_log", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_time_entry_spreadsheet_log.of_SetItem(ll_row, "job", as_to_value)
NEXT

//trade_union_job
This.of_GetChild({"trade_union_job"}, lbo_trade_union_job)
as_status.text = "Renumbering trade_union_job"
ll_rows = lbo_trade_union_job.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_trade_union_job", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_trade_union_job.of_SetItem(ll_row, "job", as_to_value)
NEXT

//area
This.of_GetChild({"area"}, lbo_area)
as_status.text = "Renumbering area"
ll_rows = lbo_area.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_area", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_area.of_SetItem(ll_row, "job", as_to_value)
NEXT

//centre
This.of_GetChild({"centre"}, lbo_centre)
as_status.text = "Renumbering centre"
ll_rows = lbo_centre.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_centre", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_centre.of_SetItem(ll_row, "job", as_to_value)
NEXT

//po_reserve
This.of_GetChild({"po_reserve"}, lbo_po_reserve)
as_status.text = "Renumbering po_reserve"
ll_rows = lbo_po_reserve.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_po_reserve", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_po_reserve.of_SetItem(ll_row, "job", as_to_value)
NEXT

//job_shipping_info
This.of_GetChild({"job_shipping_info"}, lbo_job_shipping_info)
as_status.text = "Renumbering job_shipping_info"
ll_rows = lbo_job_shipping_info.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_job_shipping_info", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_job_shipping_info.of_SetItem(ll_row, "job", as_to_value)
NEXT

//client_po
This.of_GetChild({"client_po"}, lbo_client_po)
as_status.text = "Renumbering client_po"
ll_rows = lbo_client_po.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_client_po", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_client_po.of_SetItem(ll_row, "job", as_to_value)
NEXT

//quantity
This.of_GetChild({"quantity"}, lbo_quantity)
as_status.text = "Renumbering quantity"
ll_rows = lbo_quantity.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_quantity", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_quantity.of_SetItem(ll_row, "job", as_to_value)
NEXT

//purchase_requisition_item
This.of_GetChild({"purchase_requisition_item"}, lbo_purchase_requisition_item)
as_status.text = "Renumbering purchase_requisition_item"
ll_rows = lbo_purchase_requisition_item.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_purchase_requisition_item", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_purchase_requisition_item.of_SetItem(ll_row, "job", as_to_value)
NEXT

//equipment_usage
This.of_GetChild({"equipment_usage"}, lbo_equipment_usage)
as_status.text = "Renumbering area group"
ll_rows = lbo_equipment_usage.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_equipment_usage", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_equipment_usage.of_SetItem(ll_row, "job", as_to_value)
NEXT

//employee
This.of_GetChild({"employee"}, lbo_employee)
as_status.text = "Renumbering employee"
ll_rows = lbo_employee.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_employee", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_employee.of_SetItem(ll_row, "job", as_to_value)
NEXT

//crew_member
This.of_GetChild({"crew"}, lbo_crew)
This.of_GetChild({"crew_member"}, lbo_crew_member)
as_status.text = "Renumbering crew_member"
ll_rows = lbo_crew_member.of_Retrieve("job_or_region = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_crew_member", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	IF lbo_crew.of_Retrieve("job = '" + as_from_value + "' AND job_or_region = 'J'") = 1 THEN
		lbo_crew_member.of_SetItem(ll_row, "job_or_region", as_to_value)
	END IF
NEXT

//crew
as_status.text = "Renumbering crew"
ll_rows = lbo_crew.of_Retrieve("job = '" + as_from_value + "' AND job_or_region = 'J'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_crew", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_crew.of_SetItem(ll_row, "job", as_to_value)
NEXT

//budget_transfer
This.of_GetChild({"budget_transfer"}, lbo_budget_transfer)
as_status.text = "Renumbering budget_transfer"
ll_rows = lbo_budget_transfer.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_budget_transfer", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_budget_transfer.of_SetItem(ll_row, "job", as_to_value)
NEXT

//ar_invoice
This.of_GetChild({"ar_invoice"}, lbo_ar_invoice)
as_status.text = "Renumbering ar_invoice"
ll_rows = lbo_ar_invoice.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_ar_invoice", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_ar_invoice.of_SetItem(ll_row, "job", as_to_value)
NEXT

//ar_invoice_root
This.of_GetChild({"ar_invoice_root"}, lbo_ar_invoice_root)
as_status.text = "Renumbering ar_invoice_root"
ll_rows = lbo_ar_invoice_root.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_ar_invoice_root", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_ar_invoice_root.of_SetItem(ll_row, "job", as_to_value)
NEXT

//equipment
This.of_GetChild({"equipment"}, lbo_equipment)
as_status.text = "Renumbering equipment"
ll_rows = lbo_equipment.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_equipment", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_equipment.of_SetItem(ll_row, "job", as_to_value)
NEXT

//equipment rental
This.of_GetChild({"rental_agreement"}, lbo_rental_agreement)
as_status.text = "Renumbering equipment rental"
ll_rows = lbo_rental_agreement.of_Retrieve("job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_rental_agreement", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_rental_agreement.of_SetItem(ll_row, "job", as_to_value)
NEXT

//ap_invoice
This.of_GetChild({"ap_invoice"}, lbo_ap_invoice)
as_status.text = "Renumbering ap_invoice"
ll_rows = lbo_ap_invoice.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_ap_invoice", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_ap_invoice.of_SetItem(ll_row, "job", as_to_value)
NEXT

//payment
This.of_GetChild({"payment"}, lbo_payment)
as_status.text = "Renumbering payment"
ll_rows = lbo_payment.of_Retrieve("book = '" + as_book + &
		"' AND job = '" + as_from_value + "'")
IF ll_rows = -1 THEN 
	of_msg_db_error("Error retrieving lbo_payment", this.itr_trans)
	RETURN -1
END IF

FOR ll_row = 1 TO ll_rows
	lbo_payment.of_SetItem(ll_row, "job", as_to_value)
NEXT

//timesheet						job						* use embedded sql
as_status.text = "Renumbering timesheets"
UPDATE timesheet
	SET job = :as_to_value
 WHERE book = :as_book
	AND job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.SQLCODE <> 0 THEN
	of_msg_db_error("Error renumbering timesheets: ", this.itr_trans)
	RETURN -1
END IF

//labour_dispersion			job						* 
//labour_dispersion			timesheet_job			*
as_status.text = "Renumbering labour_dispersions"
UPDATE labour_dispersion
	SET job = :as_to_value
 WHERE book = :as_book
	AND job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.SQLCODE <> 0 THEN
	of_msg_db_error("Error renumbering labour_dispersion: ", this.itr_trans)
	RETURN -1
END IF
UPDATE labour_dispersion
	SET timesheet_job = :as_to_value
 WHERE book = :as_book
	AND timesheet_job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.SQLCODE <> 0 THEN
	of_msg_db_error("Error renumbering labour_dispersion: ", this.itr_trans)
	RETURN -1
END IF

//gl_transaction				job						*
as_status.text = "Renumbering gl_transaction"
UPDATE gl_transaction
	SET job = :as_to_value
 WHERE book = :as_book
	AND job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.SQLCODE <> 0 THEN
	of_msg_db_error("Error renumbering gl_transaction: ", this.itr_trans)
	RETURN -1
END IF

//jc_transaction				job						*
as_status.text = "Renumbering jc_transaction"
UPDATE jc_transaction
	SET job = :as_to_value
 WHERE book = :as_book
	AND job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.SQLCODE <> 0 THEN
	of_msg_db_error("Error renumbering jc_transaction: ", this.itr_trans)
	RETURN -1
END IF

//Renumber Web-Abio crew tables
as_status.text = "Renumbering Web-Abio components..."
UPDATE supervisor_job
	SET job = :as_to_value
 WHERE book = :as_book
	AND job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.sqlcode = -1 THEN
	of_msg_db_error('Error renumbering supervisor_job', this.itr_trans)
	RETURN -1
END IF

UPDATE area_document
	SET job = :as_to_value
 WHERE book = :as_book
	AND job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.sqlcode = -1 THEN
	of_msg_db_error('Error renumbering area_document', this.itr_trans)
	RETURN -1
END IF

UPDATE client_wo_document
	SET job = :as_to_value
 WHERE book = :as_book
	AND job 	= :as_from_value
 USING this.itr_trans;
IF this.itr_trans.sqlcode = -1 THEN
	of_msg_db_error('Error renumbering client_wo_document', this.itr_trans)
	RETURN -1
END IF

// Update but don't commit this business objects and all of its children
//  *** commit handled in calling routine, after constraints are restored ***
as_status.text = "Writing changes"
li_rc = This.of_UpdateAll(FALSE, FALSE, lstr_validation_error)

IF li_rc = 1 THEN
	as_message = "job " + as_from_value + " has been renumbered to " + &
			as_to_value
ELSE
	ROLLBACK USING this.itr_trans;
	as_message = "Error renumbering job " + as_from_value + &
			" to " + as_to_value
	
	IF UpperBound(lstr_validation_error) > 0 THEN
		as_message += ":~r~n~r~n" + lstr_validation_error[1].s_message
	END IF
END IF

as_status.text = "Renumbering complete"

RETURN li_rc


end function

public function integer of_get_next_pm_document_no (string as_book, string as_job, ref long al_pm_document_no);//************************************************************
// Object   :	n_bo_job
// Function :	of_get_next_pm_document_no
// Author   :	Dean Schindell
// Date     :	2021/04/23
// 	
// Arguments:	string as_book
// 				string as_job
// 				long (returned) al_pm_document_no
// 	
// Return   : integer:  1 if successful, -1 if an error occurred
// 	
// Desc:			Returns the next available PM Document num ber for the book/job
//					Returns -1 for error, 0 for no data or 1 for success
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Integer	li_rc
Long		ll_rows, ll_pm_document_no
String	ls_where


IF IsNull(as_book) OR as_book = "" OR IsNull(as_job) OR as_job = "" THEN
	gnv_error.of_add(90, gs_last_window, "R", "Error reading job", -1, ls_where, "job")
	li_rc = -1
	SetNull( al_pm_document_no )
ELSE
	ls_where = "book = '" + String( as_book ) + "' AND job = '" + as_job + "'"

	ll_rows = this.of_Retrieve( ls_where )
	
	IF ll_rows > 0 THEN
		//	Get the last entry number for Project Management Documents for the book and increment it within the 
		//	business object - the business object can now be saved as part of another process once all objects
		//	are ready to be saved.
		ll_pm_document_no = this.of_GetItemNumber( ll_rows, "last_pm_document_no" )
		al_pm_document_no = ll_pm_document_no + 1
		
		li_rc = this.of_SetItem( ll_rows, "last_pm_document_no", al_pm_document_no )
	ELSE
		gnv_error.of_add(90, gs_last_window, "R", "Unable to read next PM Document Number from job", 100, ls_where, "job" )
		li_rc = 0
		SetNull( al_pm_document_no )
	END IF
END IF

RETURN li_rc

end function

on n_bo_job.create
call super::create
end on

on n_bo_job.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_job 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/03/06
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Define Business Object
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
String	ls_null
SetNull(ls_null)

is_log_event_name = 'JCJENT'

// Set the object description to be seen in messages to user
This.of_SetDescription("J/C Job")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_job"


// Force a new transaction for this business object
This.of_SetTransaction()


//Set primary key column
of_setpkcolumns({'book','job'})

This.of_AddValidationRule({"job", "book"}, "UNIQUE", &
		"", "Job Must be Unique", FALSE)

This.of_AddValidationRule({"job"}, "REQUIRED", &
		"", "Job is Required", FALSE)
				
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Book is Required", FALSE)
	

This.of_AddValidationRule({"description"}, "REQUIRED", &
		"", "Description is Required", FALSE)
This.of_setcolumndefault('description', '')		
					 
//This.of_AddValidationRule({"superintendent"}, "REQUIRED", &
//		"", "Superintendent is Required", FALSE)	
This.of_setcolumndefault('superintendent', '')	

//This.of_AddValidationRule({"address_1"}, "REQUIRED", &
//		"", "Address_1 is Required", FALSE)	
This.of_setcolumndefault('address_1', '')	

//This.of_AddValidationRule({"address_2"}, "REQUIRED", &
//		"", "Address_2 is Required", FALSE)	
This.of_setcolumndefault('address_2', '')	

//This.of_AddValidationRule({"city"}, "REQUIRED", &
//		"", "City is Required", FALSE)	
This.of_setcolumndefault('city', '')

This.of_AddValidationRule({"province"}, "REQUIRED", &
		"", "Province is Required", FALSE)	
This.of_setcolumndefault('province', '')

This.of_AddValidationRule({"country"}, "REQUIRED", &
		"", "Country is Required", FALSE)	
This.of_setcolumndefault('country', 'CAN')

//This.of_AddValidationRule({"postal"}, "REQUIRED", &
//		"", "Postal is Required", FALSE)	
This.of_setcolumndefault('postal', '')

/*This.of_AddValidationRule({"phone"}, "REQUIRED", &
		"", "Phone is Required", FALSE)	*/
This.of_setcolumndefault('phone', '')

/*This.of_AddValidationRule({"fax"}, "REQUIRED", &
		"", "Fax is Required", FALSE)	*/
This.of_setcolumndefault('fax', '')

This.of_AddValidationRule({"parent_job"}, "REQUIRED", &
		"", "Parent_job is Required", FALSE)	
This.of_setcolumndefault('parent_job', '')


//This.of_AddValidationRule({"client"}, "REQUIRED", &
//		"", "Client is Required", FALSE)	
This.of_setcolumndefault('client', '')

	
//This.of_AddValidationRule({"client_job"}, "REQUIRED", &
//		"", "Client Job is Required", FALSE)	
This.of_setcolumndefault('client_job', '')

//This.of_AddValidationRule({"client_po"}, "REQUIRED", &
//		"", "Client_po is Required", FALSE)	
This.of_setcolumndefault('client_po', '')

This.of_AddValidationRule({"po_address_flag"}, "REQUIRED", &
		"", "P/O Job Address is Required", FALSE)	
This.of_setcolumndefault('po_address_flag', 'N')

This.of_AddValidationRule({"equ_ts_approver_style"}, "REQUIRED", &
		"", "Time entry sheet approver is Required", FALSE)	
This.of_setcolumndefault('equ_ts_approver_style', 'P')

This.of_AddValidationRule({"shipping_msg_type"}, "REQUIRED", &
		"", "Shipping message is Required", FALSE)	
This.of_setcolumndefault('shipping_msg_type', 'Y')


This.of_AddValidationRule({"wcb_class"}, "REQUIRED", &
		"", "WCB Class is Required", FALSE)	
This.of_setcolumndefault('wcb_class', '')

This.of_AddValidationRule({"gst_rule"}, "REQUIRED", &
		"", "GST Rule is Required", FALSE)	
This.of_setcolumndefault('gst_rule', '')


This.of_AddValidationRule({"fixed_price_flag"}, "REQUIRED", &
		"", "Fixed Price Flag is Required", FALSE)	
This.of_setcolumndefault('fixed_price_flag', 'N')

This.of_AddValidationRule({"invoice_dispersion_flag"}, "REQUIRED", &
		"", "A/R Dispersion Flag is Required", FALSE)	
This.of_setcolumndefault('invoice_dispersion_flag', 'Y')

This.of_AddValidationRule({"freeze_budget_flag"}, "REQUIRED", &
		"", "Freeze Budget Flag is Required", FALSE)	
This.of_setcolumndefault('freeze_budget_flag', 'N')

This.of_AddValidationRule({"include_staff_hrs_flag"}, "REQUIRED", &
		"", "Include Staff Hours Flag is Required", FALSE)	
This.of_setcolumndefault('include_staff_hrs_flag', 'Y')	
	
This.of_AddValidationRule({"reg_hours_per_day"}, "REQUIRED", &
		"", "Reg hours/day is Required", FALSE)	
This.of_setcolumndefault('reg_hours_per_day', '0')

This.of_AddValidationRule({"smtc_per_hour"}, "REQUIRED", &
		"", "SMTC per hour is Required", FALSE)	
This.of_setcolumndefault('smtc_per_hour', '0')

This.of_setcolumndefault('smtc_per_hour_label', '')
This.of_setcolumndefault('labour_surcharge_label', '')
This.of_setcolumndefault('labour_surcharge_percent', '0')

This.of_AddValidationRule({"active_flag"}, "REQUIRED", &
		"", "active? is Required", FALSE)	
This.of_setcolumndefault('active_flag','Y')

This.of_AddValidationRule({"concurrent_crew_memberships_flag"}, "REQUIRED", &
		"", "multi-job crew membership? is Required", FALSE)	
This.of_setcolumndefault('concurrent_crew_memberships_flag','N')

//This.of_AddValidationRule({"add_user_id"}, "REQUIRED", &
//		"", "Add User ID is Required", FALSE)	
This.of_setcolumndefault('add_user_id',gnv_app.of_getuserid())

This.of_AddValidationRule({"add_datetime"}, "REQUIRED", &
		"", "Add User Date is Required", FALSE)	
This.of_setcolumndefault('add_datetime',	"TODAY" )

This.of_AddValidationRule({"file_type"}, "REQUIRED", &
		"", "File Type is Required", FALSE)	
This.of_setcolumndefault('file_type','C')
	
This.of_AddValidationRule({"labour_markup_percent"}, "REQUIRED", &
		"", "Labour markup % is Required", FALSE)	
This.of_setcolumndefault('labour_markup_percent', '0')

This.of_AddValidationRule({"material_markup_percent"}, "REQUIRED", &
		"", "Material markup % is Required", FALSE)	
This.of_setcolumndefault('material_markup_percent', '0')

This.of_AddValidationRule({"contract_amount"}, "REQUIRED", &
		"", "Contract Amount is Required", FALSE)	
This.of_setcolumndefault('contract_amount', '0')

This.of_AddValidationRule({"original_budget"}, "REQUIRED", &
		"", "Original Budget is Required", FALSE)	
This.of_setcolumndefault('original_budget', '0')

This.of_AddValidationRule({"current_budget"}, "REQUIRED", &
		"", "Current Budget is Required", FALSE)	
This.of_setcolumndefault('current_budget', '0')

This.of_AddValidationRule({"to_date_cost"}, "REQUIRED", &
		"", "Todate Cost is Required", FALSE)	
This.of_setcolumndefault('to_date_cost', '0')

This.of_AddValidationRule({"to_date_revenue"}, "REQUIRED", &
		"", "Todate Revenue is Required", FALSE)	
This.of_setcolumndefault('to_date_revenue', '0')

This.of_AddValidationRule({"to_date_payment"}, "REQUIRED", &
		"", "Todate Payment is Required", FALSE)	
This.of_setcolumndefault('to_date_payment', '0')

This.of_AddValidationRule({"commitment"}, "REQUIRED", &
		"", "Commitment is Required", FALSE)	
This.of_setcolumndefault('commitment', '0')

This.of_AddValidationRule({"expected_cost"}, "REQUIRED", &
		"", "Expected Cost is Required", FALSE)	
This.of_setcolumndefault('expected_cost', '0')

This.of_AddValidationRule({"year_open_cost"}, "REQUIRED", &
		"", "Year Opening is Required", FALSE)	
This.of_setcolumndefault('year_open_cost', '0')

This.of_AddValidationRule({"period_1_cost"}, "REQUIRED", &
		"", f_get_month_name('','',1) + " is Required", FALSE)	
This.of_setcolumndefault('period_1_cost', '0')

This.of_AddValidationRule({"period_2_cost"}, "REQUIRED", &
		"", f_get_month_name('','',2) + " is Required", FALSE)	
This.of_setcolumndefault('period_2_cost', '0')

This.of_AddValidationRule({"period_3_cost"}, "REQUIRED", &
		"", f_get_month_name('','',3) + " is Required", FALSE)	
This.of_setcolumndefault('period_3_cost', '0')

This.of_AddValidationRule({"period_4_cost"}, "REQUIRED", &
		"", f_get_month_name('','',4) + " is Required", FALSE)	
This.of_setcolumndefault('period_4_cost', '0')

This.of_AddValidationRule({"period_5_cost"}, "REQUIRED", &
		"", f_get_month_name('','',5) + " is Required", FALSE)	
This.of_setcolumndefault('period_5_cost', '0')
	
This.of_AddValidationRule({"period_6_cost"}, "REQUIRED", &
		"", f_get_month_name('','',6) + " is Required", FALSE)	
This.of_setcolumndefault('period_6_cost', '0')

This.of_AddValidationRule({"period_7_cost"}, "REQUIRED", &
		"", f_get_month_name('','',7) + " is Required", FALSE)	
This.of_setcolumndefault('period_7_cost', '0')	
	
This.of_AddValidationRule({"period_8_cost"}, "REQUIRED", &
		"", f_get_month_name('','',8) + " is Required", FALSE)	
This.of_setcolumndefault('period_8_cost', '0')

This.of_AddValidationRule({"period_9_cost"}, "REQUIRED", &
		"", f_get_month_name('','',9) + " is Required", FALSE)	
This.of_setcolumndefault('period_9_cost', '0')		

This.of_AddValidationRule({"period_10_cost"}, "REQUIRED", &
		"", f_get_month_name('','',10) + " is Required", FALSE)	
This.of_setcolumndefault('period_10_cost', '0')	
	
This.of_AddValidationRule({"period_11_cost"}, "REQUIRED", &
		"", f_get_month_name('','',11) + " is Required", FALSE)	
This.of_setcolumndefault('period_11_cost', '0')

This.of_AddValidationRule({"period_12_cost"}, "REQUIRED", &
		"", f_get_month_name('','',12) + " is Required", FALSE)	
This.of_setcolumndefault('period_12_cost', '0')	

This.of_AddValidationRule({"year_open_revenue"}, "REQUIRED", &
		"", "Year Opening Revenue is Required", FALSE)	
This.of_setcolumndefault('year_open_revenue', '0')

This.of_AddValidationRule({"period_1_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',1) + " is Required", FALSE)	
This.of_setcolumndefault('period_1_revenue', '0')

This.of_AddValidationRule({"period_2_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',2) + " is Required", FALSE)	
This.of_setcolumndefault('period_2_revenue', '0')

This.of_AddValidationRule({"period_3_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',3) + " is Required", FALSE)	
This.of_setcolumndefault('period_3_revenue', '0')

This.of_AddValidationRule({"period_4_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',4) + " is Required", FALSE)	
This.of_setcolumndefault('period_4_revenue', '0')

This.of_AddValidationRule({"period_5_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',5) + " is Required", FALSE)	
This.of_setcolumndefault('period_5_revenue', '0')
	
This.of_AddValidationRule({"period_6_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',6) + " is Required", FALSE)	
This.of_setcolumndefault('period_6_revenue', '0')	

This.of_AddValidationRule({"period_7_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',7) + " is Required", FALSE)	
This.of_setcolumndefault('period_7_revenue', '0')

This.of_AddValidationRule({"period_8_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',8) + " is Required", FALSE)	
This.of_setcolumndefault('period_8_revenue', '0')

This.of_AddValidationRule({"period_9_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',9) + " is Required", FALSE)	
This.of_setcolumndefault('period_9_revenue', '0')

This.of_AddValidationRule({"period_10_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',10) + " is Required", FALSE)	
This.of_setcolumndefault('period_10_revenue', '0')	

This.of_AddValidationRule({"period_11_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',11) + " is Required", FALSE)	
This.of_setcolumndefault('period_11_revenue', '0')

This.of_AddValidationRule({"period_12_revenue"}, "REQUIRED", &
		"", f_get_month_name('','',12) + " is Required", FALSE)	
This.of_setcolumndefault('period_12_revenue', '0')
		
		
This.of_AddValidationRule("active_flag", "EXPRESSION", &
		"<<active_flag>> IN ('Y', 'N')", &
		"Active Flag Must be Y or N", FALSE)		
		
This.of_AddValidationRule("fixed_price_flag", "EXPRESSION", &
		"<<fixed_price_flag>> IN ('Y', 'N')", &
		"Fixed Price Flag Must be Y or N", FALSE)		
		
This.of_AddValidationRule("file_type", "EXPRESSION", &
		"<<file_type>> IN ('H', 'C')", &
		"File Type Must be H or C", FALSE)		
		
		
This.of_AddValidationRule("freeze_budget_flag", "EXPRESSION", &
		"<<freeze_budget_flag>> IN ('Y', 'N')", &
		"Freeze Budget Flag Must be Y or N", FALSE)	

This.of_AddValidationRule("include_staff_hrs_flag", "EXPRESSION", &
		"<<include_staff_hrs_flag>> IN ('Y', 'N')", &
		"Include Staff Hours Flag Must be Y or N", FALSE)	
		
This.of_AddValidationRule("invoice_dispersion_flag", "EXPRESSION", &
		"<<invoice_dispersion_flag>> IN ('Y', 'N')", &
		"Invoice Dispersion Flag Must be Y or N", FALSE)	
		
This.of_AddValidationRule("po_address_flag", "EXPRESSION", &
		"<<po_address_flag>> IN ('Y', 'N')", &
		"P/O Job Address Flag Must be Y or N", FALSE)		
		
This.of_AddValidationRule("shipping_msg_type", "EXPRESSION", &
		"<<shipping_msg_type>> IN ('Y', 'N', 'F')", &
		"Shipping message Must be Y, N or F", FALSE)		
		
This.of_AddValidationRule("equ_ts_approver_style", "EXPRESSION", &
		"<<equ_ts_approver_style>> IN ('P', 'E', 'D')", &
		"Time entry sheet approver Must be P, E or D", FALSE)		
		
		
This.of_AddValidationRule({"postal"}, "EXPRESSION", &
" Len(Trim(<<postal>>)) = 0 OR (<<country>> = 'USA' AND (Len(Trim(<<postal>>)) = 5 OR Len(Trim(<<postal>>)) = 9) AND " + &
" IsNumber(<<postal>>)) OR " + &
" (Len(Trim(<<postal>>)) = 6 " + & 
" AND (IsNumber(Mid(<<postal>>, 2, 1)))" + &
" AND (IsNumber(Mid(<<postal>>, 4, 1)))" + &
" AND (IsNumber(Mid(<<postal>>, 6, 1)))" + &
" AND (Not IsNumber(Mid(<<postal>>, 1, 1)))" + &
" AND (Not IsNumber(Mid(<<postal>>, 3, 1)))" + &
" AND (Not IsNumber(Mid(<<postal>>, 5, 1))))", " Postal Code Format Must be A9A9A9 For Canada Or 99999, 99999-9999 For US", FALSE)

This.of_AddValidationRule({"phone"}, "EXPRESSION", &
		"Len(Trim(<<phone>>)) = 0 OR (IsNumber(<<phone>>) AND ((Len(Trim(<<phone>>)) = 10 OR Len(Trim(<<phone>>)) = 7)))", "Phone Must Be 7 or 10 Digits Number", FALSE)

This.of_AddValidationRule({"fax"}, "EXPRESSION", &
		"Len(Trim(<<fax>>)) = 0 OR (IsNumber(<<fax>>) AND ((Len(Trim(<<fax>>)) = 10 OR Len(Trim(<<fax>>)) = 7)))", "Fax Must Be 7 or 10 Digits Number", FALSE)
		
This.of_AddValidationRule({"reg_hours_per_day"}, "EXPRESSION", &
		"<<reg_hours_per_day>> >= 7 and  <<reg_hours_per_day>> <= 12", "Reg hours/day must be between 7 to 12", FALSE)	

This.of_AddValidationRule({"material_markup_percent"}, "EXPRESSION", &
		"<<material_markup_percent>> >= 0 and  <<material_markup_percent>> <= 100", "Material markup % must be between 0 to 100", FALSE)	

This.of_AddValidationRule({"labour_markup_percent"}, "EXPRESSION", &
		"<<labour_markup_percent>> >= 0 and  <<labour_markup_percent>> <= 100", "Labour markup % must be between 0 to 100", FALSE)		
		
This.of_AddValidationRule({"shutdown_start_date"}, "EXPRESSION", &
		"<<start_date>> <= <<shutdown_start_date>> OR (<<shutdown_start_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000')))", "Shutdown start date must be after Start Date", FALSE)	
		
This.of_AddValidationRule({"shutdown_start_date"}, "EXPRESSION", &
		"(<<shutdown_start_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR DaysAfter(TODAY(),DATE(<<shutdown_start_date>>)) <= 365", "Shutdown start date should be within next year", FALSE)	
		
This.of_AddValidationRule({"shutdown_end_date"}, "EXPRESSION", &
		"<<shutdown_start_date>> <= <<shutdown_end_date>> OR (<<shutdown_end_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000')))", "Shutdown end date must be after Shutdown start Date", FALSE)	
		
This.of_AddValidationRule({"shutdown_end_date"}, "EXPRESSION", &
		"(<<shutdown_end_date>> = Datetime(Date('1900/01/01'),Time('00:00:00.000000'))) OR DaysAfter(TODAY(),DATE(<<shutdown_end_date>>)) <= 365", "Shutdown end date should be within next year", FALSE)	

This.of_AddValidationRule("active_flag", "EXPRESSION", &
		"(<<active_flag>> = 'N' AND <<commitment>> = 0) OR <<active_flag>> = 'Y'", &
		"Job cannot be inactivated if committed costs are non-zero", TRUE)		

This.of_AddValidationRule("file_type", "EXPRESSION", &
		"(<<file_type>> = 'H' AND <<commitment>> = 0) OR <<file_type>> = 'C'", &
		"Job cannot be archived if committed costs are non-zero", TRUE)		

This.of_setcolumndefault('book', gnv_app.is_book)	
This.of_setcolumndefault('start_date', "TODAY")	
This.of_setcolumndefault('ap_last_job_po_no', '0')		
This.of_setcolumndefault('include_staff_hrs_flag', 'Y')		
		
// Add DB Constraints
This.of_AddDBConstraint("pk_job", "job", "Job", "")

This.of_AddDBConstraint("fk_job__book", "book", &
		"Book", "Book")
		
This.of_AddDBConstraint("fk_job__client", "book", &
		"Client", "Client")
		
This.of_AddDBConstraint("fk_job__client_po", "book", &
		"client_po", "Client_po")
		
		
This.of_AddDBConstraint("fk_job__country", "job", &
		"country", "country")
		
This.of_AddDBConstraint("fk_job__dashboard_group", "job", &
		"Dashboard_group", "Dashboard_group")

	
This.of_AddDBConstraint("fk_job__division", "job", &
		"Division", "Division")
		
		
This.of_AddDBConstraint("fk_job__equipment_rate_type", "job", &
		"equipment_rate_type", "equipment_rate_type")
		
This.of_AddDBConstraint("fk_job__gst_rule", "job", &
		"gst_rule", "gst_rule")
				
This.of_AddDBConstraint("fk_job__labour_rate_type", "book", &
		"labour_rate_type", "labour_rate_type")		
		
This.of_AddDBConstraint("fk_job__province_gl", "book", &
		"province_gl", "province_gl")
		
This.of_AddDBConstraint("fk_job__province_state", "job", &
		"province_state", "province_state")		

This.of_AddDBConstraint("fk_job__wcb_class", "job", &
		"wcb_class", "wcb_class")			

This.of_AddDBConstraint("fk_journal_entry_item__job", 		/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"journal entry", 							/* reference table */	&
								"There are journal entries posted to this job.  Please delete them first.")	/* delete message */
		
This.of_AddDBConstraint("fk_area__job", 							/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"area", 										/* reference table */	&
								"There are areas set up for this job.  Please delete them first.")	/* delete message */
		
This.of_AddDBConstraint("fk_employee__job", 						/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Employee", 								/* reference table */	&
								"There are employees posted to this job.  Please update their employee record first.")	/* delete message */
		
This.of_AddDBConstraint("fk_equipment__job", 					/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Equipment", 								/* reference table */	&
								"There is equipment assigned to this job.  Please reassign the equipment units first.")	/* delete message */
		
This.of_AddDBConstraint("fk_equipment_activity__from_job", 	/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Equipment Transfer", 					/* reference table */	&
								"There are equipment transfers from this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_equipment_activity__to_job", 	/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Equipment Transfer", 					/* reference table */	&
								"There are equipment transfers to this job.")	/* delete message */
				
This.of_AddDBConstraint("fk_equipment_activity__to_job", 	/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Equipment Transfer", 					/* reference table */	&
								"There are equipment transfers to this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_equipment_usage__job", 			/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Equipment Timesheet", 					/* reference table */	&
								"There are equipment timesheets for this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_gl_transaction__job", 				/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"G/L Transaction", 						/* reference table */	&
								"There are G/L transaction records for this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_gl_transaction__job", 				/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"G/L Transaction", 						/* reference table */	&
								"There are G/L transaction records for this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_payment__job", 						/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Payments", 								/* reference table */	&
								"There are A/R payments for this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_person_diary__job", 						/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Person Diary", 								/* reference table */	&
								"There are H/R Diary entries posting employees to this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_po_log__job", 						/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Reserved Purchase Orders", 			/* reference table */	&
								"There are Purchase Order numbers reserved for this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_po_root__job", 						/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"Purchase Orders", 						/* reference table */	&
								"There are Purchase Order for this job.")	/* delete message */
		
This.of_AddDBConstraint("fk_pm_document_root__job", 			/* constraint */ 			&
                        "job", 										/* column */ 				&
		                  "job is not valid", 						/* add message (only relevant on journal entry) */ 		&
								"P/M Document",							/* reference table */	&
								"There are P/M Document records for this job.")	/* delete message */
		
		
IF NOT IsValid(ibo_company) THEN
	ibo_company = CREATE n_bo_company
	ibo_company.of_SetTransaction()
END IF

IF NOT IsValid(ibo_province_state) THEN
	ibo_province_state = CREATE n_bo_province_state
	ibo_province_state.of_SetTransaction()
END IF


IF NOT IsValid(ibo_application_properties) THEN
	ibo_application_properties = CREATE n_bo_application_properties
	ibo_application_properties.of_SetTransaction()
END IF


IF NOT IsValid(ibo_area) THEN
	ibo_area = CREATE n_bo_area
	ibo_area.of_SetTransaction()
END IF


IF NOT IsValid(ibo_book) THEN
	ibo_book = CREATE n_bo_book
	ibo_book.of_SetTransaction()
END IF
	
IF NOT IsValid(ibo_division_book) THEN
	ibo_division_book = CREATE n_bo_division_book
	ibo_division_book.of_SetTransaction()
END IF
		
// Add child object
This.of_AddChild("area", 					"n_bo_area")
This.of_AddChild("area_client_po",		"n_bo_area_client_po")
This.of_AddChild("centre", 				"n_bo_centre")
This.of_AddChild("area_group", 			"n_bo_area_group")	
This.of_AddChild("client_po", 			"n_bo_client_po")	
This.of_AddChild("quantity", 				"n_bo_quantity")	
This.of_AddChild("labour_dispersion", 	"n_bo_labour_dispersion")	
This.of_AddChild("budget_transfer", 	"n_bo_budget_transfer")	
This.of_AddChild("centre_snapshot_history", 		"n_bo_centre_snapshot_history")	
This.of_AddChild("area_group_client_approver", 	"n_bo_area_group_client_approver")	
This.of_AddChild("area_group_client_po", 			"n_bo_area_group_client_po")	
This.of_AddChild("person_diary", 					"n_bo_person_diary")	
This.of_AddChild("po_root", 							"n_bo_po_root")	
This.of_AddChild("equipment_activity", 			"n_bo_equipment_activity")	
This.of_AddChild("journal_entry_item", 			"n_bo_journal_entry_item")	
This.of_AddChild("time_entry_spreadsheet_log", 	"n_bo_time_entry_spreadsheet_log")	
This.of_AddChild("trade_union_job", 				"n_bo_trade_union_job")	
This.of_AddChild("po_reserve", 						"n_bo_po_reserve")	
This.of_AddChild("job_shipping_info", 				"n_bo_job_shipping_info")	
This.of_AddChild("purchase_requisition_item", 	"n_bo_purchase_requisition_item")	
This.of_AddChild("equipment_usage", 				"n_bo_equipment_usage")	
This.of_AddChild("job", 								"n_bo_job")	
This.of_AddChild("employee", 							"n_bo_employee")	
This.of_AddChild("crew", 								"n_bo_crew")	
This.of_AddChild("crew_member",						"n_bo_crew_member")	
This.of_AddChild("ar_invoice", 						"n_bo_ar_invoice")	
This.of_AddChild("ar_invoice_root",					"n_bo_ar_invoice_root")	
This.of_AddChild("equipment", 						"n_bo_equipment")	
This.of_AddChild("ap_invoice", 						"n_bo_ap_invoice")	
This.of_AddChild("payment", 							"n_bo_payment")	
This.of_AddChild("rental_agreement",				"n_bo_rental_agreement")	

end event

event bo_prerowdelete;call super::bo_prerowdelete;//************************************************************
// Object   :	n_bo_job 
// Event    :	bo_prerowdelete
// Author   :	Lourdes Garcia
// Date     :	2009/08/21
// 	
// Arguments:	long al_row
// 	
// Returns:		boolean
// 	
// Desc:			Prevent Deletion if file = 'H'
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String		ls_file, ls_job
Boolean		lb_return = TRUE

// check if data is in history
ls_file = This.of_GetItemString(al_row, "file_type")
		
IF ls_file = 'H' THEN
	This.of_AddValidationError(al_row, "job", Primary!, "Can’t delete job that is on History")
	lb_return = FALSE
END IF

// check if job has associated areas
ls_job = This.of_GetItemString(al_row,"job")
IF ibo_area.of_count("active_flag = 'Y' and book = '" + gnv_app.is_book + "' and job = '" + ls_job + "'") > 0 THEN
	This.of_AddValidationError(al_row, "job", Primary!, "Can’t delete job with areas")
	
	lb_return = FALSE
END IF

// if there are non-zero amounts then deletion is not permitted
IF (This.of_GetItemNumber(al_row,"year_open_cost") + &
		This.of_GetItemNumber(al_row,"period_1_cost") + & 
		This.of_GetItemNumber(al_row,"period_2_cost") + & 
		This.of_GetItemNumber(al_row,"period_3_cost") + & 
		This.of_GetItemNumber(al_row,"period_4_cost") + & 
		This.of_GetItemNumber(al_row,"period_5_cost") + & 
		This.of_GetItemNumber(al_row,"period_6_cost") + & 
		This.of_GetItemNumber(al_row,"period_7_cost") + & 
		This.of_GetItemNumber(al_row,"period_8_cost") + & 
		This.of_GetItemNumber(al_row,"period_9_cost") + & 
		This.of_GetItemNumber(al_row,"period_10_cost") + & 
		This.of_GetItemNumber(al_row,"period_11_cost") + & 
		This.of_GetItemNumber(al_row,"period_12_cost") + & 
		This.of_GetItemNumber(al_row,"year_open_revenue") + &
		This.of_GetItemNumber(al_row,"period_1_revenue") + &
		This.of_GetItemNumber(al_row,"period_2_revenue") + &
		This.of_GetItemNumber(al_row,"period_3_revenue") + &
		This.of_GetItemNumber(al_row,"period_4_revenue") + &
		This.of_GetItemNumber(al_row,"period_5_revenue") + &
		This.of_GetItemNumber(al_row,"period_6_revenue") + &
		This.of_GetItemNumber(al_row,"period_7_revenue") + &
		This.of_GetItemNumber(al_row,"period_8_revenue") + &
		This.of_GetItemNumber(al_row,"period_9_revenue") + &
		This.of_GetItemNumber(al_row,"period_10_revenue") + &
		This.of_GetItemNumber(al_row,"period_11_revenue") + &
		This.of_GetItemNumber(al_row,"period_12_revenue") + &
		This.of_GetItemNumber(al_row,"contract_amount") + &
		This.of_GetItemNumber(al_row,"original_budget") + &
		This.of_GetItemNumber(al_row,"current_budget") + &
		This.of_GetItemNumber(al_row,"to_date_cost") + &
		This.of_GetItemNumber(al_row,"to_date_revenue") + &
		This.of_GetItemNumber(al_row,"to_date_payment") + &
		This.of_GetItemNumber(al_row,"commitment") + &
		This.of_GetItemNumber(al_row,"expected_cost") + &
		This.of_GetItemNumber(al_row,"expected_revenue")) <> 0 THEN
		This.of_AddValidationError(al_row, "job", Primary!, "Deletion Disallowed. Job has non-zero amounts")
		lb_return = FALSE
END IF

RETURN lb_return

end event

event destructor;call super::destructor;//************************************************************
// Object   :	n_bo_job 
// Event    :	destructor
// Author   :	Lourdes Garcia
// Date     :	2009/08/21
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

IF IsValid(ibo_application_properties) THEN DESTROY ibo_application_properties

IF IsValid(ibo_company) THEN DESTROY ibo_company

IF IsValid(ibo_area) THEN DESTROY ibo_area

IF IsValid(ibo_book) THEN DESTROY ibo_book

IF IsValid(ibo_province_state) THEN DESTROY ibo_province_state

IF IsValid(ibo_division_book) THEN DESTROY ibo_division_book
end event

event bo_rowinserted;call super::bo_rowinserted;//************************************************************
// Object   :	n_bo_job 
// Event    :	bo_rowinserted
// Author   :	Lourdes Garcia
// Date     :	2009/08/21
// 	
// Arguments:	long al_row
// 	
// Returns:		(None)
// 	
// Desc:			Set up Defaults
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String		ls_gst_rule, ls_province, ls_wcb
Long			ll_regular_hrs

ibo_application_properties.of_get_gst_rule(ls_gst_rule)
This.of_SetItem(al_row,"gst_rule",ls_gst_rule)

ibo_company.of_get_province(gnv_app.is_book, ls_province)
This.of_SetItem(al_row,'province', ls_province)

//jira 2397 - handle american jobs
IF ibo_province_state.of_Retrieve("province = '" + ls_province + "'") > 0 THEN
	this.of_SetItem(al_row, 'country', ibo_province_state.of_GetItemString(1, 'country'))
END IF

ibo_company.of_get_wcb_class(gnv_app.is_book, ls_wcb)
This.of_SetItem(al_row,'wcb_class', ls_wcb)


ibo_company.of_get_regular_hrs(gnv_app.is_book, ll_regular_hrs)
This.of_SetItem(al_row,'reg_hours_per_day', ll_regular_hrs)
end event

event bo_preupdate;call super::bo_preupdate;//************************************************************
// Object   :	n_bo_job 
// Event    :	bo_preupdate
// Author   :	Monica Petersen
// Date     :	2015/05/15
// 	
// Arguments:	(None)
// 	
// Return:	Integer - 1=Success, -1=Failure
//
// Desc:		This event is triggered before an update and can 
//				generate unique keys as well as apply validation 
//				rules to determine whether the update can proceed
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer	li_row
String	ls_null
Integer				li_rc, li_x
Long					ll_c_rows, ll_c_row, ll_cm_rows, ll_cm_row, ll_row_rpt
n_bo_crew_member	lbo_crew_member
s_preview			lstr_preview
w_preview  			lw_preview
n_ds					lds_rpt

li_rc = AncestorReturnValue

IF li_rc = -1 THEN RETURN li_rc

SetNull(ls_null)

FOR li_row = 1 TO this.of_RowCount()
	IF Trim(this.of_GetItemString(li_row, 'labour_rate_type')) = '' THEN
		this.of_SetItem(li_row, 'labour_rate_type', ls_null)
	END IF
	IF Trim(this.of_GetItemString(li_row, 'equipment_rate_type')) = '' THEN
		this.of_SetItem(li_row, 'equipment_rate_type', ls_null)
	END IF
NEXT

//This child record is originally instantiated in the calling screen ue_update
//and this is a reference to that business object.
//These changes will get written as part of the transaction set that updates the job recrd
this.of_GetChild("crew_member", lbo_crew_member)
lbo_crew_member.of_Reset()	//remove any trace of previous attempted updates
lbo_crew_member.of_SetLogAuditDetails(TRUE)
lbo_crew_member.of_SetLogEventName('JCJENT')
lbo_crew_member.of_SetLogActionCode('C')

//Inactivate crew members when multiple crew assignment flag changes from 'Y' to 'N'
ll_c_rows = This.of_RowCount()
FOR ll_c_row = 1 TO ll_c_rows
	
	IF this.of_GetItemString(ll_c_row, 'concurrent_crew_memberships_flag',  Primary!, TRUE) = 'Y' 	&
	AND this.of_GetItemString(ll_c_row, 'concurrent_crew_memberships_flag',  Primary!, FALSE) = 'N' THEN
	
		// The job is no longer shares membership.  All employees that are future dated must be deleted
		// and all currently effective members must be expired.
		ll_cm_rows = lbo_crew_member.of_Retrieve("crew_member.job_or_region = '" + this.of_GetItemString(ll_c_row, 'job') + "'  " &
												+ "        AND (SELECT crew.active_flag " &
												+ "             FROM   dbo.crew  " &
												+ "             WHERE  crew.job_or_region = crew_member.job_or_region  " &
												+ "                    AND crew.crew = crew_member.crew) = 'Y'  " &
												+ "        AND (    (effective_date <= Getdate() AND expiry_date >= Getdate())  " &
												+ "              OR  effective_date > Getdate())  " &
												+ "        AND supervisor_flag = 'N'  " &
												+ "        AND alternate_supervisor_flag = 'N'  " &
												+ "        AND EXISTS (SELECT 1  " &
												+ "                    FROM   dbo.crew  " &
												+ "                           INNER JOIN crew_member CM2  " &
												+ "                                   ON crew.crew = CM2.crew  " &
												+ "                                      AND crew.job_or_region = CM2.job_or_region  " &
												+ "                    WHERE  crew.job <> '" + this.of_GetItemString(ll_c_row, 'job') + "'  " &
												+ "                           AND crew_member.employee = CM2.employee  " &
												+ "                           AND CM2.effective_date <= Getdate()  " &
												+ "                           AND CM2.expiry_date >= Getdate()  " &
												+ "                           AND crew.active_flag = 'Y'  " &
												+ "                           AND CM2.supervisor_flag = 'N'  " &
												+ "                           AND CM2.alternate_supervisor_flag = 'N')   		 ")
												
		FOR ll_cm_row = ll_cm_rows TO 1 STEP -1
			IF lbo_crew_member.of_GetItemDateTime(ll_cm_row, 'effective_date') >= DateTime(Today(), Time(0,0,0)) THEN
				lbo_crew_member.of_DeleteRow(ll_cm_row)
			ELSE
				lbo_crew_member.of_SetItem(ll_cm_row, 'expiry_date', Today())
			END IF
		NEXT
		
		
	END IF
NEXT

//We could at this point display the updates that were made to crews, based on the changes to lbo_crew_member
//Datastore for showing affected records
lds_rpt = CREATE n_ds
lds_rpt.dataobject = 'd_jc_job_detail_affected_crew_members'
lds_rpt.SetTransObject(sqlca)

//Report the changes to crew members
FOR li_x = 1 TO lbo_crew_member.of_RowCount() 
		
	IF Isvalid(lds_rpt) THEN
		//Report Original entry
		ll_row_rpt = lds_rpt.InsertRow(0)
		lds_rpt.SetItem(ll_row_rpt, 'job', 					lbo_crew_member.of_GetItemString(li_x, 'job_or_region'))
		lds_rpt.SetItem(ll_row_rpt, 'crew', 				lbo_crew_member.of_GetItemString(li_x, 'crew'))
		lds_rpt.SetItem(ll_row_rpt, 'employee', 			lbo_crew_member.of_GetItemNumber(li_x, 'employee'))
		lds_rpt.SetItem(ll_row_rpt, 'name',	 				f_get_person_name(lbo_crew_member.of_GetItemNumber(li_x, 'employee')))
		lds_rpt.SetItem(ll_row_rpt, 'effective_date',	lbo_crew_member.of_GetItemDateTime(li_x, 'effective_date'))
		lds_rpt.SetItem(ll_row_rpt, 'expiry_date',		lbo_crew_member.of_GetItemDateTime(li_x, 'expiry_date'))
		lds_rpt.SetItem(ll_row_rpt, 'status',				'expired')
	END IF

NEXT

//have to do this before the update - no way to get rows that were deleted
FOR li_x = 1 TO lbo_crew_member.of_DeletedCount() 
		
	IF Isvalid(lds_rpt) THEN
		//Report Original entry
		ll_row_rpt = lds_rpt.InsertRow(0)
		lds_rpt.SetItem(ll_row_rpt, 'job', 					lbo_crew_member.of_GetItemString(li_x, 'job', Delete!, FALSE))
		lds_rpt.SetItem(ll_row_rpt, 'crew', 				lbo_crew_member.of_GetItemString(li_x, 'crew', Delete!, FALSE))
		lds_rpt.SetItem(ll_row_rpt, 'employee', 			lbo_crew_member.of_GetItemNumber(li_x, 'employee', Delete!, FALSE))
		lds_rpt.SetItem(ll_row_rpt, 'name',	 				f_get_person_name(lbo_crew_member.of_GetItemNumber(li_x, 'employee', Delete!, FALSE)))
		lds_rpt.SetItem(ll_row_rpt, 'effective_date',	lbo_crew_member.of_GetItemDateTime(li_x, 'effective_date', Delete!, FALSE))
		lds_rpt.SetItem(ll_row_rpt, 'expiry_date',		lbo_crew_member.of_GetItemDateTime(li_x, 'expiry_date', Delete!, FALSE))
		lds_rpt.SetItem(ll_row_rpt, 'status',				'deleted')
	END IF

NEXT

//Output report showing what would be moved
IF IsValid(lds_rpt) THEN
	IF lds_rpt.RowCount() > 0 THEN
		lds_rpt.Sort()
		lds_rpt.GroupCalc()
		SetNull(lstr_preview.dw_preview)
		lstr_preview.ds_preview = lds_rpt
		lstr_preview.s_title = Trim(gnv_app.of_GetCompanyName())
		lstr_preview.s_sub_title = 'CREW MEMBERS AFFECTED'
		lstr_preview.s_report = "J/C Job Crew Members Affected"
		OpenSheetWithParm(w_preview, lstr_preview, 'w_preview',gnv_app.of_getframe(),0, Original!)
		
		//Ask user if they want to save
		IF Messagebox("Job Crew Expirations", String(lds_rpt.RowCount()) + " Crew members will be affected.  Do you want to continue?", Question!, YesNo!, 1) = 2 THEN
			RETURN -1
		END IF
		
	END IF
END IF

RETURN li_rc

end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_job 
// Event    :	bo_validate
// Author   :	Lourdes Garcia
// Date     :	2009/08/31
// 	
// Arguments:	long al_row
// 				string as_column
// 				string as_value
// 	
// Returns:		integer
// 	
// Desc:			Advanced Validation
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String		ls_st_gl_flag
Int			li_rc = 1
Long			ll_count

CHOOSE CASE as_column 
CASE "division" 
	IF al_row > 0 THEN
		// If book.standard_gl_flag is Y and division_book has any rows for this set of books, then ‘Division’ is mandatory.
		ibo_book.of_get_standard_gl_flag(gnv_app.is_book, ls_st_gl_flag)
		IF ls_st_gl_flag = 'Y'  and (IsNull(as_value) OR as_value = "") THEN
			
			ll_count = ibo_division_book.of_count("book = '" + gnv_app.is_book + "'")
			IF ll_count > 0 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Please add a division for job " + this.ids_data.GetItemString(al_row, 'job') + ".")
			END IF	
		END IF
	END IF
	
CASE "dashboard_group" 
	IF al_row > 0 AND (IsNull(as_value) OR as_value = "") &
	AND This.ids_data.Describe("action.Name") = "action" THEN
		
		IF Not(IsValid(ibo_dashboard_group)) THEN
			ibo_dashboard_group = CREATE n_bo_dashboard_group
			ibo_dashboard_group.of_SetTransaction(sqlca)
		END IF
		
		ll_count = ibo_dashboard_group.of_count("")
		IF ll_count > 0 THEN
			// dashboard group is mandatory if there are any entries in the dashboard_group table
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Dashboard Group is a required field")
		END IF
		
	END IF
END CHOOSE

RETURN li_rc
end event

event bo_logauditdelta;call super::bo_logauditdelta;//************************************************************
// Object   :	n_bo_job 
// Event    :	bo_logauditdelta
// Author   :	Monica Petersen
// Date     :	2014/10/07
// 	
// Arguments:	dwbuffer ae_buffer
// 				long al_row
// 				string as_action_code
// 				string as_delta
// 	
// Returns:		boolean
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

IF as_action_code = "M" THEN
	as_delta = This.of_GenerateDelta(ae_buffer, al_row)
ELSEIF as_action_code = "U" THEN
	as_delta = This.of_GenerateDelta(ae_buffer, al_row)
END IF 		

RETURN TRUE
end event

